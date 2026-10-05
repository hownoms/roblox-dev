--!strict
--[[
	DevCommands — chat commands for playtesting. Only active in Roblox Studio; does nothing in
	live servers.

		/coins <n>     add coins
		/max           own and equip the best shovel and backpack, plus lots of coins
		/dig <depth>   carve a shaft at your position (inside the dig zone) down to <depth> studs
		               and drop you at the bottom
		/rebirths <n>  set your rebirth count
		/wipe          reset your save to a brand-new player (replays the tutorial)
		/surface       return to the surface (boardwalk)
		/tide          run the tide now: refill every dug column (like High Tide)
]]

local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)
local BeachService = require(script.Parent.BeachService)
local ShopService = require(script.Parent.ShopService)
local World = require(script.Parent.Parent.World)

local DevCommands = {}

local SHAFT_WIDTH = 12

local function number(arg: string?): number?
	local n = tonumber(arg or "")
	if n and n == n and math.abs(n) ~= math.huge then
		return n
	end
	return nil
end

local handlers: { [string]: (Player, { string }) -> () } = {}

handlers["/coins"] = function(player, args)
	local amount = number(args[1]) or 1e6
	DataService.Increment(player, "Coins", amount)
	Net.Notify(player, "Success", "[Dev] +" .. tostring(amount) .. " coins")
end

handlers["/max"] = function(player)
	local bestShovel = Config.Shovels[#Config.Shovels].Id
	local bestBackpack = Config.Backpacks[#Config.Backpacks].Id
	DataService.Mutate(player, { "OwnedShovels", "OwnedBackpacks", "Coins" }, function(data)
		for _, def in Config.Shovels do
			data.OwnedShovels[def.Id] = true
		end
		for _, def in Config.Backpacks do
			data.OwnedBackpacks[def.Id] = true
		end
		data.Coins = math.max(data.Coins, 1e15)
	end)
	ShopService.Equip(player, "Shovel", bestShovel)
	ShopService.Equip(player, "Backpack", bestBackpack)
	Net.Notify(player, "Success", "[Dev] Best gear unlocked")
end

handlers["/dig"] = function(player, args)
	local character = player.Character
	if not character then
		Net.Notify(player, "Error", "[Dev] No character yet")
		return
	end
	assert(character) -- refine for the type checker (guarded above)
	local zone = World.GetDigZone()
	local depth = math.clamp(number(args[1]) or 100, 8, zone.Size.Y - 4)
	-- Shaft at the player's XZ, snapped to the voxel grid and kept inside the dig zone.
	local here = World.ClampToDigZone(character:GetPivot().Position, SHAFT_WIDTH / 2)
	local x = math.floor(here.X / 4 + 0.5) * 4
	local z = math.floor(here.Z / 4 + 0.5) * 4
	local top = Config.SURFACE_Y
	local bottom = math.floor((top - depth) / 4) * 4
	local minV = Vector3.new(x - SHAFT_WIDTH / 2, bottom, z - SHAFT_WIDTH / 2)
	local maxV = Vector3.new(x + SHAFT_WIDTH / 2, top, z + SHAFT_WIDTH / 2)
	local size = maxV - minV + Vector3.new(0, 4, 0)
	Workspace.Terrain:FillBlock(CFrame.new(minV + size / 2), size, Enum.Material.Air)
	BeachService.RecordCarve(minV, maxV)
	BeachService.ReportDig(player, depth)
	character:PivotTo(CFrame.new(x, bottom + 4, z))
	Net.Notify(player, "Success", "[Dev] Dropped to " .. Config.GetLayerAtDepth(depth).Name)
end

handlers["/tide"] = function(player)
	BeachService.TideStep(true)
	Net.Notify(player, "Success", "[Dev] Tide refilled every hole")
end

handlers["/rebirths"] = function(player, args)
	DataService.Set(player, "Rebirths", math.max(0, math.floor(number(args[1]) or 1)))
	Net.Notify(player, "Success", "[Dev] Rebirths set")
end

handlers["/wipe"] = function(player)
	local fresh = Config.NewPlayerData() :: any
	local keys = {}
	for key in fresh do
		table.insert(keys, key)
	end
	DataService.Mutate(player, keys, function(data)
		for key, value in fresh do
			(data :: any)[key] = value
		end
	end)
	ShopService.GiveShovelTool(player)
	BeachService.TeleportToSurface(player)
	Net.Notify(player, "Success", "[Dev] Save wiped. Rejoin to replay the tutorial.")
end

handlers["/surface"] = function(player)
	BeachService.TeleportToSurface(player)
end

function DevCommands.Start()
	if not RunService:IsStudio() then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "DevCommands"
	folder.Parent = TextChatService
	for name, handler in handlers do
		local command = Instance.new("TextChatCommand")
		command.Name = name
		command.PrimaryAlias = name
		command.Parent = folder
		command.Triggered:Connect(function(source: TextSource, text: string)
			local player = game:GetService("Players"):GetPlayerByUserId(source.UserId)
			if not player or not DataService.Get(player) then
				return
			end
			local args = string.split(text, " ")
			table.remove(args, 1)
			task.spawn(handler, player, args) -- errors print to Output with a stack trace
		end)
	end
	print("[DevCommands] Studio dev commands ready: /coins /max /dig /rebirths /wipe /surface /tide")
end

return DevCommands
