--!strict
--[[
	MenuGate — progressive menu disclosure rules (docs/design/Onboarding.md). Pure functions of
	the player's data so tests can check every rule; HUD applies the result (visibility, 2-column
	re-flow, pop-in, "NEW!" tag, unlock toast).

	A button is shown when its rule holds now OR it was ever unlocked before (persisted in
	data.Settings.MenuUnlocked, a comma list), so nothing ever disappears again even when the
	trigger was transient (coins spent, heat cooled off, rebirth reset the shovels).
	"NEW!" shows until the matching panel is first opened (data.Settings.MenuSeen).
	Returning players (PlayTime > RETURNING_PLAYTIME or Rebirths > 0) see everything.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))

local MenuGate = {}

-- Menu grid order (HUD) + the top-right Daily button. Settings is always visible.
MenuGate.MENU = table.freeze({ "Shop", "Beach", "Eggs", "Pets", "Index", "Quests", "Rebirth", "Store" })
MenuGate.ALL = table.freeze({ "Shop", "Beach", "Eggs", "Pets", "Index", "Quests", "Rebirth", "Store", "Daily" })

-- Panel name -> gated button name (opening the panel clears that button's NEW tag).
MenuGate.PANEL_TO_BUTTON = table.freeze({
	Shop = "Shop",
	BeachShop = "Beach",
	Eggs = "Eggs",
	Pets = "Pets",
	Index = "Index",
	Quests = "Quests",
	Rebirth = "Rebirth",
	Store = "Store",
	Daily = "Daily",
})

MenuGate.UNLOCK_KEY = "MenuUnlocked"
MenuGate.SEEN_KEY = "MenuSeen"

-- Tuning (seconds of total PlayTime / fractions).
MenuGate.RETURNING_PLAYTIME = 20 * 60
MenuGate.BEACH_HEAT = 50
MenuGate.BEACH_PLAYTIME = 4 * 60
MenuGate.STORE_PLAYTIME = 8 * 60
MenuGate.DAILY_PLAYTIME = 60
MenuGate.REBIRTH_FRACTION = 0.6
-- Tutorial (Config.TUTORIAL_STEPS) completed-step counts that reveal a button: reaching the
-- "shop" step shows Shop, reaching the "egg" step shows Eggs. Derived from the step ids so
-- inserting a step never shifts which button unlocks when.
local function stepsBefore(id: string): number
	for i, step in Config.TUTORIAL_STEPS do
		if step.Id == id then
			return i - 1
		end
	end
	error("MenuGate: no tutorial step " .. id)
end
MenuGate.TUTORIAL_SHOP = stepsBefore("shop")
MenuGate.TUTORIAL_EGGS = stepsBefore("egg")

-- Unlock lines (short, no emoji: toasts use TextScaled labels).
MenuGate.MESSAGES = table.freeze({
	Shop = "Shop unlocked! Buy a better shovel",
	Beach = "Beach shop unlocked! Shade and snacks cool you",
	Eggs = "Eggs unlocked! Hatch a pet helper",
	Pets = "Pets unlocked! Equip pets for more sand",
	Index = "Index unlocked! Collect every treasure",
	Quests = "Quests unlocked! Finish them for rewards",
	Rebirth = "Rebirth unlocked! Restart stronger",
	Store = "Store unlocked! Boosts and passes",
	Daily = "Daily rewards unlocked! Claim one every day",
})

export type Context = {
	Data: Types.PlayerData,
	Heat: number?, -- current Heat attribute (transient: the unlock is persisted when it fires)
}

local function count(t: { [any]: any }?): number
	local n = 0
	if t then
		for _ in t do
			n += 1
		end
	end
	return n
end

function MenuGate.IsReturning(data: Types.PlayerData): boolean
	return (data.PlayTime or 0) > MenuGate.RETURNING_PLAYTIME or (data.Rebirths or 0) > 0
end

local function tutorialDone(data: Types.PlayerData): number
	local saved = data.Settings and data.Settings.Tutorial
	return if type(saved) == "number" then saved else 0
end

local function flag(data: Types.PlayerData, name: string): boolean
	return data.Settings ~= nil and data.Settings["FTUE_" .. name] == true
end

-- The rule for each button right now (ignores what was persisted).
function MenuGate.Rules(ctx: Context): { [string]: boolean }
	local data = ctx.Data
	local playTime = data.PlayTime or 0
	local shovels = count(data.OwnedShovels)
	local pets = count(data.Pets)
	local tutorial = tutorialDone(data)
	local anyClaimed = false
	local quests: { [string]: Types.QuestProgress } = data.Quests or {}
	for _, quest in quests do
		if quest.Claimed then
			anyClaimed = true
			break
		end
	end
	return {
		Shop = flag(data, "FirstSell") or tutorial >= MenuGate.TUTORIAL_SHOP or shovels > 1,
		Beach = (ctx.Heat or 0) >= MenuGate.BEACH_HEAT or playTime >= MenuGate.BEACH_PLAYTIME or count(
			data.OwnedShades
		) > 0,
		Eggs = tutorial >= MenuGate.TUTORIAL_EGGS or shovels >= 3 or pets > 0,
		Pets = pets > 0,
		Index = data.Index ~= nil and next(data.Index) ~= nil,
		Quests = shovels > 1 or flag(data, "FirstShovel") or anyClaimed,
		Rebirth = (data.Rebirths or 0) > 0
			or (data.Coins or 0) >= MenuGate.REBIRTH_FRACTION * Config.RebirthCost(data.Rebirths or 0),
		Store = playTime >= MenuGate.STORE_PLAYTIME,
		Daily = playTime >= MenuGate.DAILY_PLAYTIME or (data.LastDailyClaim or 0) > 0,
	}
end

function MenuGate.ParseList(value: any): { [string]: boolean }
	local set: { [string]: boolean } = {}
	if type(value) == "string" then
		for name in string.gmatch(value, "[^,]+") do
			if MenuGate.MESSAGES[name] then
				set[name] = true
			end
		end
	end
	return set
end

-- Canonical (MenuGate.ALL order) comma list; at most 53 chars (SetSetting allows 64).
function MenuGate.FormatList(set: { [string]: boolean }): string
	local names = {}
	for _, name in MenuGate.ALL do
		if set[name] then
			table.insert(names, name)
		end
	end
	return table.concat(names, ",")
end

-- Which buttons are visible: returning players see all, otherwise persisted OR rule.
function MenuGate.Evaluate(ctx: Context): { [string]: boolean }
	local data = ctx.Data
	local visible: { [string]: boolean } = {}
	if MenuGate.IsReturning(data) then
		for _, name in MenuGate.ALL do
			visible[name] = true
		end
		return visible
	end
	local persisted = MenuGate.ParseList(data.Settings and data.Settings[MenuGate.UNLOCK_KEY])
	local rules = MenuGate.Rules(ctx)
	for _, name in MenuGate.ALL do
		visible[name] = persisted[name] == true or rules[name] == true
	end
	return visible
end

-- Design-px top-left of the k-th visible menu cell (2 columns, no gaps between visible ones).
function MenuGate.CellPosition(k: number, cell: number, gapX: number, gapY: number, columns: number): Vector2
	local col = (k - 1) % columns
	local row = (k - 1) // columns
	return Vector2.new(col * (cell + gapX), row * (cell + gapY))
end

return MenuGate
