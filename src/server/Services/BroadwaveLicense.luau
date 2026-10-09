--!strict
--[[
	BroadwaveLicense — gives a LICENSED player a real (non-loan) Broadwave Tool. Default-off:
	does nothing until AdventureBoot calls Start() under AdventureFlags.BroadwaveOrdinary.

	  * Evidence: the saved ToolLicenses.tool_broadwave record (AdventureEligibility.Rules). This
	    module never grants or writes a license; the future q_pip / cert_explorer quest grant owns
	    that and should call BroadwaveLicense.Sync(player) after writing it.
	  * Not a shovel: the tool is not in Config.Shovels / OwnedShovels / ShopService. It carries
	    ToolId = "tool_broadwave" (set here, on the server) and no ShovelId, so ShopService's
	    shovel refresh never touches it, and selling / rebirth never remove it.
	  * Each tool built here is registered with AdventureEligibility, so CanUseBroadwave accepts
	    only tools this server issued to that player (never the adventure loan, never a
	    client-made or renamed tool).
	  * Re-issued on every respawn (Roblox clears the Backpack) and removed when the license is
	    missing or the feature is stopped.

	Known gap (docs/integration/production-wiring.md, open decision 3): SpringVaultService's charge
	input accepts only its own adventure loan, so ordinary Broadwave with this tool needs the
	runtime to recognise it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(ReplicatedStorage.Shared.Models.Expansion1)
local DataService = require(script.Parent.DataService)
local Eligibility = require(script.Parent.AdventureEligibility)

local BroadwaveLicense = {}

BroadwaveLicense.TOOL_NAME = "Broadwave"
BroadwaveLicense.LICENSED_ATTRIBUTE = "LicensedBroadwave"

local running = false
local tools: { [Player]: Tool? } = {}
local connections: { { Disconnect: (any) -> () } } = {}
local characterConnections: { [Player]: RBXScriptConnection } = {}

local function build(player: Player): Tool
	local model = Kit.Broadwave()
	local handle = model.PrimaryPart :: BasePart
	local tool = Instance.new("Tool")
	tool.Name = BroadwaveLicense.TOOL_NAME
	tool.CanBeDropped = false
	tool.Grip = handle:GetAttribute("GripOffset") :: CFrame
	tool:SetAttribute("ToolId", Eligibility.TOOL_ID)
	tool:SetAttribute(BroadwaveLicense.LICENSED_ATTRIBUTE, true)
	for _, item in model:GetChildren() do
		item.Parent = tool
	end
	for _, item in tool:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = false
			item.CanCollide = false
		end
	end
	model:Destroy()
	Eligibility.RegisterIssuedTool(tool, player)
	return tool
end

local function remove(player: Player)
	local tool = tools[player]
	tools[player] = nil
	if tool then
		tool:Destroy()
	end
end

-- Ensures the player holds exactly one licensed tool when (and only when) licensed.
function BroadwaveLicense.Sync(player: Player)
	if not running or player.Parent == nil then
		remove(player)
		return
	end
	local licensed = DataService.IsLoaded(player) and Eligibility.Rules.HasBroadwaveLicense(DataService.Get(player))
	if not licensed then
		remove(player)
		return
	end
	local existing = tools[player]
	if existing and existing.Parent ~= nil then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	local tool = build(player)
	tool.Parent = backpack
	tools[player] = tool
end

function BroadwaveLicense.Has(player: Player): boolean
	local tool = tools[player]
	return tool ~= nil and tool.Parent ~= nil
end

local function watch(player: Player)
	if characterConnections[player] then
		return
	end
	characterConnections[player] = player.CharacterAdded:Connect(function()
		-- The new Backpack is filled after CharacterAdded; issue on the next resumption.
		task.defer(BroadwaveLicense.Sync, player)
	end)
	BroadwaveLicense.Sync(player)
end

function BroadwaveLicense.Start()
	if running then
		return
	end
	running = true
	table.insert(
		connections,
		DataService.PlayerLoaded:Connect(function(player: Player)
			watch(player)
		end)
	)
	table.insert(connections, Players.PlayerAdded:Connect(watch))
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(player: Player)
			remove(player)
			local c = characterConnections[player]
			if c then
				c:Disconnect()
				characterConnections[player] = nil
			end
		end)
	)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

function BroadwaveLicense.Stop()
	running = false
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	for player, c in characterConnections do
		c:Disconnect()
		characterConnections[player] = nil
	end
	for player in tools do
		remove(player)
	end
end

return BroadwaveLicense
