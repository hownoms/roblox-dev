--!strict
--[[
	DevCommands — chat commands for playtesting. Only active in Roblox Studio; does nothing in
	live servers.

		/coins <n>     add coins
		/max           own and equip the best shovel and backpack, plus lots of coins
		/dig <depth>   carve a shaft in your plot down to <depth> studs and drop you at the bottom
		/rebirths <n>  set your rebirth count
		/wipe          reset your save to a brand-new player (replays the tutorial)
		/surface       return to the top of your plot
]]

local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)
local PlotService = require(script.Parent.PlotService)
local ShopService = require(script.Parent.ShopService)

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
	local plot = PlotService.GetPlot(player)
	local character = player.Character
	if not plot or not character then
		Net.Notify(player, "Error", "[Dev] No plot or character yet")
		return
	end
	assert(plot and character) -- refine for the type checker (guarded above)
	local depth = math.clamp(number(args[1]) or 100, 8, plot.Size.Y - 4)
	local centre = plot.Origin.Position - Vector3.new(0, depth / 2, 0)
	Workspace.Terrain:FillBlock(CFrame.new(centre), Vector3.new(SHAFT_WIDTH, depth + 8, SHAFT_WIDTH), Enum.Material.Air)
	PlotService.ReportDig(player, depth, depth)
	character:PivotTo(CFrame.new(plot.Origin.Position - Vector3.new(0, depth - 4, 0)))
	Net.Notify(player, "Success", "[Dev] Dropped to " .. Config.GetLayerAtDepth(depth).Name)
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
	PlotService.ResetPlayerPlot(player)
	Net.Notify(player, "Success", "[Dev] Save wiped. Rejoin to replay the tutorial.")
end

handlers["/surface"] = function(player)
	PlotService.TeleportToSurface(player)
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
	print("[DevCommands] Studio dev commands ready: /coins /max /dig /rebirths /wipe /surface")
end

return DevCommands
