--!strict
--[[
	Plots — 12 dig plots: PlotInfo data, surface markers (colourful wooden frame, corner posts,
	"Plot N" sign with owner label, rope ladder) and terrain refills.

	Sign part ("PlotSign") carries attribute OwnerName (string, "" = free); its SurfaceGui label
	follows the attribute, so the server may either call World.SetPlotOwner or set it directly.
	Each plot Model ("Plot_N") carries attributes PlotId and OwnerUserId (0 = free).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Layout = require(script.Parent.Layout)
local Util = require(script.Parent.Util)
local TerrainBuilder = require(script.Parent.Terrain)

local Theme = Config.Theme
local rgb = Color3.fromRGB
local S = Layout.SURFACE_Y
local FOOT = Config.PLOT_FOOTPRINT

local Plots = {}

local FRAME_COLORS = {
	rgb(255, 95, 125),
	rgb(40, 190, 245),
	rgb(255, 205, 40),
	rgb(80, 215, 100),
	rgb(170, 100, 255),
	rgb(255, 140, 60),
	rgb(60, 220, 210),
	rgb(255, 120, 200),
	rgb(120, 160, 255),
	rgb(180, 230, 60),
	rgb(255, 170, 90),
	rgb(230, 90, 230),
}
local WOOD = rgb(160, 110, 70)
local WOOD_DARK = rgb(120, 80, 50)

local infos: { Types.PlotInfo } = {}
local signs: { [number]: Part } = {}
local models: { [number]: Model } = {}
local resetting: { [number]: boolean } = {}

local function buildMarker(id: number, info: Types.PlotInfo, parent: Instance)
	local model = Util.Model("Plot_" .. id, parent)
	model:SetAttribute("PlotId", id)
	model:SetAttribute("OwnerUserId", 0)
	models[id] = model

	local c = info.Origin.Position
	local front = Layout.PlotFront(id) -- towards the central path
	local color = FRAME_COLORS[(id - 1) % #FRAME_COLORS + 1]
	local h = FOOT / 2
	local beam = 1.5

	-- Frame beams (just outside the footprint so they never cover diggable sand)
	for _, sx in { -1, 1 } do
		Util.Part({
			Name = "FrameZ",
			Size = Vector3.new(beam, 1, FOOT + beam * 2),
			CFrame = CFrame.new(c.X + sx * (h + beam / 2), S + 0.5, c.Z),
			Color = color,
			Material = Enum.Material.WoodPlanks,
			Decor = true,
			Parent = model,
		})
	end
	for _, sz in { -1, 1 } do
		Util.Part({
			Name = "FrameX",
			Size = Vector3.new(FOOT, 1, beam),
			CFrame = CFrame.new(c.X, S + 0.5, c.Z + sz * (h + beam / 2)),
			Color = color,
			Material = Enum.Material.WoodPlanks,
			Decor = true,
			Parent = model,
		})
	end
	-- Corner posts with white caps
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local p = Vector3.new(c.X + sx * (h + beam / 2), S, c.Z + sz * (h + beam / 2))
			Util.Part({
				Name = "Post",
				Size = Vector3.new(1.8, 3, 1.8),
				CFrame = CFrame.new(p + Vector3.new(0, 1.5, 0)),
				Color = color,
				Material = Enum.Material.WoodPlanks,
				Parent = model,
			})
			Util.Part({
				Name = "PostCap",
				Size = Vector3.new(2.2, 0.5, 2.2),
				CFrame = CFrame.new(p + Vector3.new(0, 3.25, 0)),
				Color = Color3.new(1, 1, 1),
				Decor = true,
				Parent = model,
			})
		end
	end

	-- Sign on the path side, offset to the hub side of the plot, facing the path.
	local towardHub = if c.X > 0 then -1 else 1
	local signBase = Vector3.new(c.X + towardHub * (h - 4), S, c.Z + front.Z * (h + 3))
	Util.Part({
		Name = "SignPost",
		Size = Vector3.new(0.8, 7, 0.8),
		CFrame = CFrame.new(signBase + Vector3.new(0, 3.5, 0)),
		Color = WOOD_DARK,
		Material = Enum.Material.Wood,
		Parent = model,
	})
	local signCF = CFrame.lookAt(signBase + Vector3.new(0, 6.2, 0), signBase + Vector3.new(0, 6.2, 0) + front)
	local board = Util.Part({
		Name = "PlotSign",
		Size = Vector3.new(8, 4.2, 0.5),
		CFrame = signCF,
		Color = Theme.Colors.Panel,
		Parent = model,
	})
	board:SetAttribute("OwnerName", "")
	board:SetAttribute("PlotId", id)
	local border = Util.Part({
		Name = "SignBorder",
		Size = Vector3.new(8.6, 4.8, 0.4),
		CFrame = signCF * CFrame.new(0, 0, 0.4),
		Color = color,
		Decor = true,
		Parent = model,
	})
	border.CastShadow = true
	local gui = Util.SurfaceGui(board)
	Util.Label(gui, "Plot " .. id, color, UDim2.fromScale(0.05, 0.04), UDim2.fromScale(0.9, 0.5))
	local owner = Util.Label(
		gui,
		"Free plot!",
		Theme.Colors.Text,
		UDim2.fromScale(0.05, 0.56),
		UDim2.fromScale(0.9, 0.38),
		Theme.Fonts.Body
	)
	owner.Name = "OwnerLabel"
	board:GetAttributeChangedSignal("OwnerName"):Connect(function()
		local name = board:GetAttribute("OwnerName")
		if typeof(name) == "string" and name ~= "" then
			owner.Text = name .. "'s Plot"
			owner.TextColor3 = Theme.Colors.Gold
		else
			owner.Text = "Free plot!"
			owner.TextColor3 = Theme.Colors.Text
		end
	end)
	signs[id] = board

	-- Rope ladder hanging into the hole at the near corner on the outer side.
	local corner = Vector3.new(c.X - towardHub * (h - 1.2), S, c.Z + front.Z * (h - 1.2))
	local ladder = Util.Model("Ladder", model)
	local railH = 14
	for _, ox in { -0.9, 0.9 } do
		Util.Part({
			Name = "Rope",
			Size = Vector3.new(0.3, railH, 0.3),
			CFrame = CFrame.new(corner + Vector3.new(ox, 2 - railH / 2, 0)),
			Color = rgb(222, 190, 130),
			Material = Enum.Material.Fabric,
			Decor = true,
			Parent = ladder,
		})
	end
	for i = 0, 5 do
		Util.Part({
			Name = "Rung",
			Size = Vector3.new(2.1, 0.3, 0.45),
			CFrame = CFrame.new(corner + Vector3.new(0, 0.5 - i * 2.2, 0)),
			Color = WOOD,
			Material = Enum.Material.Wood,
			Decor = true,
			Parent = ladder,
		})
	end
	-- Stake the rope is tied to
	Util.Part({
		Name = "Stake",
		Size = Vector3.new(0.6, 2.4, 0.6),
		CFrame = CFrame.new(corner + front * 3.2 + Vector3.new(0, 1.2, 0)),
		Color = WOOD_DARK,
		Material = Enum.Material.Wood,
		Decor = true,
		Parent = ladder,
	})
end

function Plots.Build(parent: Instance)
	table.clear(infos)
	for id = 1, Config.PLOT_COUNT do
		local c = Layout.PlotCenter(id)
		local front = Layout.PlotFront(id)
		local spawnPos = Vector3.new(c.X, S + 3, c.Z + front.Z * (FOOT / 2 + 4))
		local info: Types.PlotInfo = {
			Id = id,
			Origin = CFrame.new(c),
			Size = Config.PLOT_SIZE,
			SpawnCFrame = CFrame.lookAt(spawnPos, spawnPos - front),
		}
		infos[id] = info
		buildMarker(id, info, parent)
	end
end

function Plots.GetPlots(): { Types.PlotInfo }
	return table.clone(infos)
end

function Plots.SetOwner(id: number, player: Player?)
	local sign = signs[id]
	local model = models[id]
	if sign then
		sign:SetAttribute("OwnerName", if player then player.DisplayName else "")
	end
	if model then
		model:SetAttribute("OwnerUserId", if player then player.UserId else 0)
	end
end

-- Refill the plot column. Margin stays below half the plot spacing so a reset never touches
-- the neighbouring plot; it also restores wall voxels a big FillBall may have nicked.
function Plots.Reset(id: number)
	local info = infos[id]
	if not info or resetting[id] then
		return
	end
	resetting[id] = true
	local margin = math.max(0, math.min(4, Config.PLOT_SPACING / 2 - 1))
	local err = Util.Try(function()
		TerrainBuilder.RefillColumn(info.Origin.Position, FOOT, margin, 3)
	end)
	resetting[id] = nil
	if err ~= nil then
		warn("[World] ResetPlot failed", id, err)
	end
end

return Plots
