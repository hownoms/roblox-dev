--!strict
--[[
	World — procedural beach map (owner: Map). Everything is built in code at server start,
	deterministically (fixed Random seed). See docs/MAP.md for the layout and coordinates.

	API (docs/ARCHITECTURE.md "Map interface"):
	  World.Build()                          -- build once (idempotent)
	  World.GetPlots(): { Types.PlotInfo }   -- after Build; ids 1..12, nearest-to-hub first
	  World.ResetPlot(id)                    -- refill the plot column (yields ~5 frames)
	Extras:
	  World.SetPlotOwner(id, player?)        -- updates the plot sign (attribute OwnerName) and
	                                         -- Plot_N.OwnerUserId; nil = free
	  World.ApplyEvent(eventIds)             -- HighTide / GoldenHour visuals (also driven by the
	                                         -- workspace attribute "ActiveEvents")
	  World.IsReady(): boolean               -- true once the deep layers finished filling
	                                         -- (workspace attribute "WorldReady" mirrors it)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage.Shared.Types)
local Layout = require(script.Layout)
local Util = require(script.Util)
local TerrainBuilder = require(script.Terrain)
local Plots = require(script.Plots)
local Hub = require(script.Hub)
local Boardwalk = require(script.Boardwalk)
local Decor = require(script.Decor)
local LightingBuilder = require(script.Lighting)

local World = {}

local built = false
local ready = false

local function step(name: string, fn: () -> ())
	local err = Util.Try(fn)
	if err ~= nil then
		warn("[World] build step failed:", name, err)
	end
end

function World.Build()
	if built then
		return
	end
	built = true
	local started = os.clock()
	local rng = Random.new(Layout.SEED)
	Workspace:SetAttribute("WorldReady", false)

	local map = Util.Folder("Map", Workspace)
	local plotsFolder = Util.Folder("Plots", map)
	local hubFolder = Util.Folder("Hub", map)
	local boardwalkFolder = Util.Folder("Boardwalk", map)
	local decorFolder = Util.Folder("Decor", map)
	local fxFolder = Util.Folder("Effects", map)

	-- Terrain first so nothing spawns over the void: layered strip tops, then the surface paint.
	step("terrain colours", TerrainBuilder.ApplyColors)
	step("strip tops", TerrainBuilder.BuildStripTops)
	step("surface", function()
		TerrainBuilder.BuildSurface(rng)
	end)
	-- Core floor under both plot rows: nothing can fall out of the bottom of a hole.
	for _, sign in { 1, -1 } do
		local zc = sign * (Layout.STRIP_INNER_Z + Layout.STRIP_OUTER_Z) / 2
		Util.Part({
			Name = "CoreFloor",
			Size = Vector3.new(Layout.STRIP_HALF_X * 2, 4, Layout.STRIP_OUTER_Z - Layout.STRIP_INNER_Z),
			CFrame = CFrame.new(0, Layout.BOTTOM_Y - 2, zc),
			Color = Color3.fromRGB(255, 200, 60),
			Material = Enum.Material.Neon,
			CastShadow = false,
			Parent = map,
		})
	end

	step("plots", function()
		Plots.Build(plotsFolder)
	end)
	step("hub", function()
		Hub.Build(hubFolder)
	end)
	step("boardwalk", function()
		Boardwalk.Build(boardwalkFolder)
	end)
	step("decor", function()
		Decor.Build(decorFolder, rng)
	end)
	step("lighting", function()
		LightingBuilder.Build(fxFolder)
	end)

	-- Deep layers fill in the background (a few frames) so Build returns quickly.
	task.spawn(function()
		local err = Util.Try(TerrainBuilder.BuildStripsDeep)
		if err ~= nil then
			warn("[World] deep terrain fill failed:", err)
		end
		ready = true
		Workspace:SetAttribute("WorldReady", true)
		print(string.format("[World] map ready in %.2fs", os.clock() - started))
	end)
end

function World.GetPlots(): { Types.PlotInfo }
	return Plots.GetPlots()
end

-- Lift anyone standing inside the plot's hole back to its spawn so the refill can't bury them.
local function evacuatePlot(id: number)
	for _, plot in Plots.GetPlots() do
		if plot.Id == id then
			local half = plot.Size / 2 + Vector3.new(2, 0, 2)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if character and root and root:IsA("BasePart") then
					local rel = plot.Origin:PointToObjectSpace(root.Position)
					if math.abs(rel.X) <= half.X and math.abs(rel.Z) <= half.Z and rel.Y < -2 then
						character:PivotTo(plot.SpawnCFrame + Vector3.new(0, 3, 0))
					end
				end
			end
			return
		end
	end
end

function World.ResetPlot(id: number)
	evacuatePlot(id)
	Plots.Reset(id)
end

function World.SetPlotOwner(id: number, player: Player?)
	Plots.SetOwner(id, player)
end

function World.ApplyEvent(eventIds: { string })
	LightingBuilder.ApplyEvent(eventIds)
end

function World.IsReady(): boolean
	return ready
end

return World
