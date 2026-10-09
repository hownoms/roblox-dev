--!strict
--[[
	AdventureEligibility — server-owned admission callbacks for SpringVaultService and the
	ordinary Broadwave bridge (docs/integration/production-wiring.md, "Eligibility").

	Every answer comes from the player's LOADED save (DataService), never from the client, money,
	depth, a tool name/attribute or an adventure loan. Not loaded (or no save) is always false.
	Nothing here writes to the save.

	  Rules.CanEnter(data)            cert_rookie, or veteran catch-up from server-written history:
	                                  a recorded sale (SellTimes quest progress) AND a recorded
	                                  excavated-deposit variant (FindVariants beyond Normal/None)
	  Rules.CanTrial(data)            q_pip's prerequisite: owns a priced (bought) shovel
	  Rules.HasBroadwaveLicense(data) saved ToolLicenses.tool_broadwave record (bible ch.04
	                                  DataVersion 4 name); only a future q_pip/cert_explorer quest
	                                  grant writes it. Nothing in this slice does.

	  CanEnter(player) / CanTrial(player)    SpringVaultService.Start options
	  CanUseBroadwave(player, tool)          BroadwaveDigBridge CanUse: ordinary Broadwave enabled
	                                         by AdventureBoot (flag) AND license record AND `tool` is
	                                         a licensed tool this server issued (BroadwaveLicense),
	                                         equipped by that player. The adventure loan never counts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local AdventureEligibility = {}

AdventureEligibility.TOOL_ID = "tool_broadwave"
AdventureEligibility.ROOKIE_CERT = "cert_rookie"

-- Variants the ambient (non-deposit) find path records (DiscoveryService: "Normal" / "None").
-- Any other recorded variant can only come from an excavated deposit.
local AMBIENT_VARIANTS: { [string]: boolean } = { Normal = true, None = true }

local Rules = {}
AdventureEligibility.Rules = Rules

local function isTable(value: any): boolean
	return type(value) == "table"
end

-- A sale recorded by the server: RewardsService adds SellTimes quest progress on every Sold.
-- Progress can be reset by a later day's quest refresh, so absence is not proof of no sale.
function Rules.HasSaleEvidence(data: any): boolean
	if not isTable(data) or not isTable(data.Quests) then
		return false
	end
	for _, def in Config.Quests do
		if def.Kind == "SellTimes" then
			local state = data.Quests[def.Id]
			if
				isTable(state)
				and (state.Claimed == true or (type(state.Progress) == "number" and state.Progress >= 1))
			then
				return true
			end
		end
	end
	return false
end

-- An excavated deposit recorded by the server (DiscoveryService.award -> FindVariants).
function Rules.HasDepositEvidence(data: any): boolean
	if not isTable(data) or not isTable(data.FindVariants) then
		return false
	end
	for key, owned in data.FindVariants do
		if owned == true and type(key) == "string" then
			local variant = string.match(key, "/([^/]+)$")
			if variant and not AMBIENT_VARIANTS[variant] then
				return true
			end
		end
	end
	return false
end

function Rules.CanEnter(data: any): (boolean, string)
	if not isTable(data) then
		return false, "NotLoaded"
	end
	if isTable(data.Certifications) and isTable(data.Certifications[AdventureEligibility.ROOKIE_CERT]) then
		return true, "Certified"
	end
	-- Returning players: catch-up from history the server wrote, never from Coins/MaxDepth.
	if Rules.HasSaleEvidence(data) and Rules.HasDepositEvidence(data) then
		return true, "CatchUp"
	end
	return false, "NoEvidence"
end

-- q_pip: "Buy first shovel". A priced shovel in OwnedShovels (ShopService.Buy, or the rebirth
-- Head Start perk's shovel). The free starter shovel never counts. Rebirth resets OwnedShovels.
function Rules.CanTrial(data: any): (boolean, string)
	if not isTable(data) or not isTable(data.OwnedShovels) then
		return false, "NotLoaded"
	end
	for id, owned in data.OwnedShovels do
		if owned == true and type(id) == "string" then
			local def = Config.GetShovel(id)
			if def and def.Price > 0 then
				return true, "FirstShovel"
			end
		end
	end
	return false, "NoShovelPurchase"
end

function Rules.HasBroadwaveLicense(data: any): boolean
	return isTable(data) and isTable(data.ToolLicenses) and isTable(data.ToolLicenses[AdventureEligibility.TOOL_ID])
end

-- Runtime -------------------------------------------------------------------------------------

local ordinaryEnabled = false
-- Licensed tools this server built (BroadwaveLicense). Weak keys: destroyed tools drop out.
local issued: { [Tool]: Player } = setmetatable({} :: any, { __mode = "k" })

local function loadedData(player: Player): any
	if typeof(player) ~= "Instance" or not player:IsA("Player") or not DataService.IsLoaded(player) then
		return nil
	end
	return DataService.Get(player)
end

function AdventureEligibility.CanEnter(player: Player): boolean
	return (Rules.CanEnter(loadedData(player)))
end

function AdventureEligibility.CanTrial(player: Player): boolean
	return (Rules.CanTrial(loadedData(player)))
end

function AdventureEligibility.CanUseBroadwave(player: Player, tool: Tool): boolean
	if not ordinaryEnabled then
		return false
	end
	if typeof(tool) ~= "Instance" or not tool:IsA("Tool") or issued[tool] ~= player then
		return false
	end
	if tool:GetAttribute("AdventureLoan") == true or tool:GetAttribute("ToolId") ~= AdventureEligibility.TOOL_ID then
		return false
	end
	local character = player.Character
	if not character or tool.Parent ~= character then
		return false
	end
	return Rules.HasBroadwaveLicense(loadedData(player))
end

-- Boot (AdventureBoot) only. Off by default; a disabled bridge refuses every release.
function AdventureEligibility.SetOrdinaryEnabled(on: boolean)
	ordinaryEnabled = on == true
end

function AdventureEligibility.IsOrdinaryEnabled(): boolean
	return ordinaryEnabled
end

function AdventureEligibility.RegisterIssuedTool(tool: Tool, player: Player)
	issued[tool] = player
end

function AdventureEligibility.IsIssuedTool(tool: Tool, player: Player): boolean
	return issued[tool] == player
end

return AdventureEligibility
