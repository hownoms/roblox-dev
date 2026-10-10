--!strict
--[[
	BroadwaveLicense — gives a LICENSED player a real (non-loan) Broadwave Tool. Default-off:
	does nothing until AdventureBoot calls Start() under AdventureFlags.BroadwaveOrdinary.

	  * Evidence: the saved ToolLicenses.tool_broadwave record (AdventureEligibility.Rules). This
	    module never grants or writes a license; PipQuest (q_pip trial completion) writes it and
	    then calls BroadwaveLicense.Sync(player), so the tool is issued at once.
	  * Not a shovel: the tool is not in Config.Shovels / OwnedShovels / ShopService. It carries
	    ToolId = "tool_broadwave" (set here, on the server) and no ShovelId, so ShopService's
	    shovel refresh never touches it, and selling / rebirth never remove it.
	  * Each tool built here is registered with AdventureEligibility, so CanUseBroadwave accepts
	    only tools this server issued to that player (never the adventure loan, never a
	    client-made or renamed tool).
	  * Re-issued on every respawn (Roblox clears the Backpack) and removed when the license is
	    missing or the feature is stopped.

	Runtime contract (docs/integration/licensed-broadwave.md): AdventureBoot passes ResolveTool
	below to SpringVaultService (Codex's PR #33 option name). A runtime that implements it accepts
	charges from this tool, and only such a charge may reach OnOrdinaryBroadwave; its own loans
	stay event/trial only. The runtime in this tree ignores the option until PR #33 lands.
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

--[[
	SpringVaultService ResolveTool option (docs/integration/licensed-broadwave.md): the
	licensed tool this server issued to `player`, only while it is equipped and every
	AdventureEligibility.CanUseBroadwave condition holds (feature running and enabled, issued to
	this player, ToolId, not a loan, equipped, saved license record). Otherwise nil. Never the
	adventure loan, a client-made or renamed copy, or a tool issued to someone else. Read-only.
]]
function BroadwaveLicense.ResolveTool(player: Player): Tool?
	if not running or typeof(player) ~= "Instance" or not player:IsA("Player") then
		return nil
	end
	local tool = tools[player]
	if not tool or tool.Parent == nil or not Eligibility.CanUseBroadwave(player, tool) then
		return nil
	end
	return tool
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
