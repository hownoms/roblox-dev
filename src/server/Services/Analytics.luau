--!strict
--[[
	Analytics — thin, safe wrappers around AnalyticsService (docs/ANALYTICS.md lists every event,
	when it fires and which Creator Analytics dashboard shows it).

	Only the AnalyticsService methods in our typed API (luau-lsp defs) are used:
	  LogOnboardingFunnelStepEvent  the onboarding funnel (Analytics.Funnel)
	  LogFunnelStepEvent            recurring funnels: the "Shop" purchase funnel and our
	                                single-step "custom events" (Analytics.Custom)
	  LogProgressionStart/CompleteEvent  layers reached, rebirths (Analytics.Progression)
	  LogEconomyEvent               coin / token sources and sinks (Analytics.Source / Sink)
	(LogCustomEvent is not in the typed API we build against; Analytics.Custom is the one place
	to switch over when it is.)

	- Funnel(player, step): onboarding funnel, logged at most once per player ever, in the order
	  of Analytics.Steps. Completion flags persist in PlayerData.Settings["FTUE_<StepName>"]
	  (reserved prefix: SetSetting can't write FTUE_ keys).
	  Most steps are detected here from ServerSignals / player attributes / a light per-player
	  state poll, so gameplay services need at most a one-line call.
	- Economy(...): LogEconomyEvent. SKU convention "<Kind>:<id>" (Shovel:, Backpack:, Egg:,
	  Shade:, Consumable:, Sell:, Quest:, Code:, Product:) or a bare word (Daily, Rebirth).
	- Custom(player, name, fields): single-step recurring funnel named after the event.
	- Track remote (client -> server): a strict whitelist of UI events (panel opens, purchase
	  prompts, menu unlocks) with argument validation and a per-player rate limit.
	Every AnalyticsService call is pcall'd and runs in its own thread; analytics never breaks
	gameplay.
]]

local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Types = require(Shared.Types)

local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)
local ServerSignals = require(script.Parent.ServerSignals)
local World = require(script.Parent.Parent.World)

local Analytics = {}

-- Onboarding funnel, in order. Numbers must only ever grow; never renumber a shipped step
-- (append new ones or retire old ones instead). See docs/ANALYTICS.md.
Analytics.Steps = table.freeze({
	Joined = 1,
	AtSand = 2,
	FirstDig = 3,
	BackpackFull = 4,
	FirstSell = 5,
	FirstShovel = 6,
	SecondShovel = 7,
	FirstBackpack = 8,
	Layer2 = 9,
	FirstEgg = 10,
	FirstPet = 11,
	Layer3 = 12,
	FirstShadeOrSnack = 13,
	FirstQuestClaim = 14,
	FirstCrate = 15,
	FirstPetDig = 16,
	Layer5 = 17,
	FirstRebirth = 18,
	-- v3 discovery slice (DiscoveryService)
	FirstFind = 19,
	FirstRareFind = 20, -- Rare or better
	FirstPerfectExcavation = 21,
})

local STEP_NAMES: { [number]: string } = {}
for name: string, number: number in Analytics.Steps :: { [string]: number } do
	STEP_NAMES[number] = name
end
Analytics.StepCount = #STEP_NAMES

-- Layer index -> funnel step (layers 2, 3 and 5 are onboarding milestones).
local LAYER_STEPS: { [number]: number } = {
	[2] = Analytics.Steps.Layer2,
	[3] = Analytics.Steps.Layer3,
	[5] = Analytics.Steps.Layer5,
}

-- Track remote whitelist ---------------------------------------------------------------------

Analytics.TRACK_RATE = 8 -- events per TRACK_WINDOW seconds per player (burst)
Analytics.TRACK_WINDOW = 5

-- Panels the client may report as opened (Panel.new names).
Analytics.TRACK_PANELS = table.freeze({
	Shop = true,
	BeachShop = true,
	Eggs = true,
	Pets = true,
	Index = true,
	Quests = true,
	Rebirth = true,
	Store = true,
	Daily = true,
	Settings = true,
})
-- Panels that sell something: opening one starts a "Shop" funnel session.
local SHOP_PANELS: { [string]: boolean } = { Shop = true, BeachShop = true, Eggs = true, Store = true, Rebirth = true }
-- HUD menu buttons the client may report as unlocked (progressive disclosure).
Analytics.TRACK_MENU = table.freeze({
	Shop = true,
	Beach = true,
	Eggs = true,
	Pets = true,
	Index = true,
	Quests = true,
	Rebirth = true,
	Store = true,
	Daily = true,
})

-- Custom field keys (Enum.AnalyticsCustomFieldKeys.CustomField01..03 by name).
local F1 = "CustomField01"
local F2 = "CustomField02"
local F3 = "CustomField03"
local function fields(a: string?, b: string?, c: string?): { [string]: string }
	local t: { [string]: string } = {}
	if a then
		t[F1] = string.sub(a, 1, 50)
	end
	if b then
		t[F2] = string.sub(b, 1, 50)
	end
	if c then
		t[F3] = string.sub(c, 1, 50)
	end
	return t
end

local function safeCall(fn: () -> ...any)
	task.spawn(function()
		for attempt = 1, 2 do
			local ok, err = pcall(fn)
			if ok then
				return
			end
			if attempt == 2 then
				warn("[Analytics] " .. tostring(err))
			else
				task.wait(1)
			end
		end
	end)
end

-- Onboarding funnel ----------------------------------------------------------------------------

function Analytics.Funnel(player: Player, step: number)
	local name = STEP_NAMES[step]
	local maybeData = DataService.Get(player)
	if not name or not maybeData then
		return
	end
	local data = maybeData :: Types.PlayerData
	local flag = "FTUE_" .. name
	if data.Settings[flag] then
		return
	end
	data.Settings[flag] = true
	DataService.MarkDirty(player, "Settings")
	safeCall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
end

function Analytics.HasStep(player: Player, step: number): boolean
	local data = DataService.Get(player)
	local name = STEP_NAMES[step]
	return data ~= nil and name ~= nil and data.Settings["FTUE_" .. name] == true
end

-- Progression ---------------------------------------------------------------------------------

-- status "Start" | "Complete". level >= 1.
function Analytics.Progression(
	player: Player,
	path: string,
	status: "Start" | "Complete",
	level: number,
	levelName: string?,
	custom: { [string]: string }?
)
	if level ~= level or level < 1 then
		return
	end
	local lvl = math.floor(level)
	safeCall(function()
		if status == "Start" then
			AnalyticsService:LogProgressionStartEvent(player, path, lvl, levelName, custom)
		else
			AnalyticsService:LogProgressionCompleteEvent(player, path, lvl, levelName, custom)
		end
	end)
end

-- Custom events + the Shop funnel ----------------------------------------------------------------

-- A one-step recurring funnel named after the event (each call = one occurrence).
function Analytics.Custom(player: Player, name: string, a: string?, b: string?, c: string?)
	local custom = fields(a, b, c)
	local session = HttpService:GenerateGUID(false)
	safeCall(function()
		AnalyticsService:LogFunnelStepEvent(player, name, session, 1, name, custom)
	end)
end

-- "Shop" funnel: 1 Opened (a selling panel) -> 2 Prompted (Robux prompt) -> 3 Purchased.
local SHOP_SESSION_SECONDS = 600
local shopSessions: { [Player]: { Id: string, Panel: string, At: number } } = {}

type ShopSession = { Id: string, Panel: string, At: number }

local function shopSession(player: Player, panel: string?): ShopSession
	local existing = shopSessions[player]
	local now = os.clock()
	if existing and now - existing.At <= SHOP_SESSION_SECONDS then
		return existing
	end
	local session: ShopSession = { Id = HttpService:GenerateGUID(false), Panel = panel or "None", At = now }
	shopSessions[player] = session
	return session
end

local function shopStep(
	player: Player,
	step: number,
	stepName: string,
	session: { Id: string, Panel: string },
	key: string?
)
	local custom = fields(session.Panel, key)
	safeCall(function()
		AnalyticsService:LogFunnelStepEvent(player, "Shop", session.Id, step, stepName, custom)
	end)
end

function Analytics.PanelOpened(player: Player, panel: string)
	Analytics.Custom(player, "PanelOpened", panel)
	if SHOP_PANELS[panel] then
		shopSessions[player] = nil
		shopStep(player, 1, "Opened", shopSession(player, panel))
	end
end

-- key: "Pass:<key>" | "Product:<key>"
function Analytics.PurchasePrompted(player: Player, key: string)
	local session = shopSession(player)
	session.At = os.clock()
	shopStep(player, 2, "Prompted", session, key)
end

-- Server-confirmed (receipt granted / pass purchase finished).
function Analytics.PurchaseCompleted(player: Player, key: string)
	local session = shopSession(player)
	shopStep(player, 3, "Purchased", session, key)
	Analytics.Custom(player, "PurchaseCompleted", key)
	shopSessions[player] = nil
end

-- Economy ----------------------------------------------------------------------------------------

-- currency: "Coins" | "Tokens". amount > 0. sku: what was bought / why it was earned.
function Analytics.Economy(
	player: Player,
	flow: Enum.AnalyticsEconomyFlowType,
	currency: string,
	amount: number,
	endingBalance: number,
	transaction: Enum.AnalyticsEconomyTransactionType,
	sku: string?
)
	if amount ~= amount or amount <= 0 or math.abs(amount) == math.huge then
		return
	end
	safeCall(function()
		AnalyticsService:LogEconomyEvent(
			player,
			flow,
			currency,
			math.floor(amount),
			math.floor(endingBalance),
			transaction.Name,
			sku
		)
	end)
end

function Analytics.Source(
	player: Player,
	currency: string,
	amount: number,
	endingBalance: number,
	transaction: Enum.AnalyticsEconomyTransactionType,
	sku: string?
)
	Analytics.Economy(player, Enum.AnalyticsEconomyFlowType.Source, currency, amount, endingBalance, transaction, sku)
	if sku and string.sub(sku, 1, 6) == "Quest:" then
		Analytics.Funnel(player, Analytics.Steps.FirstQuestClaim)
	end
end

function Analytics.Sink(
	player: Player,
	currency: string,
	amount: number,
	endingBalance: number,
	transaction: Enum.AnalyticsEconomyTransactionType,
	sku: string?
)
	Analytics.Economy(player, Enum.AnalyticsEconomyFlowType.Sink, currency, amount, endingBalance, transaction, sku)
	if sku and (string.sub(sku, 1, 6) == "Shade:" or string.sub(sku, 1, 11) == "Consumable:") then
		Analytics.Funnel(player, Analytics.Steps.FirstShadeOrSnack)
	end
end

-- Gameplay hooks ---------------------------------------------------------------------------------

-- PetService.hatch: one call per hatch (eggId, the pet ids rolled).
function Analytics.Hatched(player: Player, eggId: string, petIds: { string })
	local egg = Config.GetEgg(eggId)
	local isCrate = egg ~= nil and egg.Kind == "Crate"
	Analytics.Funnel(player, if isCrate then Analytics.Steps.FirstCrate else Analytics.Steps.FirstEgg)
	for _, petId in petIds do
		local pet = Config.GetPet(petId)
		Analytics.Custom(player, "Hatch", eggId, if pet then pet.Rarity else "Unknown", petId)
	end
end

local function count(t: { [any]: any }?): number
	local n = 0
	if t then
		for _ in t do
			n += 1
		end
	end
	return n
end

local lastLayer: { [Player]: number } = {}

local function onDepthReached(player: Player, maxDepth: number)
	local index = Config.GetLayerIndexAtDepth(maxDepth)
	local previous = lastLayer[player]
	if previous == nil then
		previous = 1
	end
	if index <= previous then
		return
	end
	lastLayer[player] = index
	local data = DataService.Get(player)
	local rebirths = if data then tostring(data.Rebirths) else "0"
	for i = previous + 1, index do
		local layer = Config.Layers[i]
		local prior = Config.Layers[i - 1]
		if prior then
			Analytics.Progression(player, "Layers", "Complete", i - 1, prior.Name, fields(rebirths))
		end
		if layer then
			Analytics.Progression(player, "Layers", "Start", i, layer.Name, fields(rebirths))
		end
		local step = LAYER_STEPS[i]
		if step then
			Analytics.Funnel(player, step)
		end
	end
end

-- Cheap state checks for steps without a dedicated signal (every POLL_SECONDS per player).
local POLL_SECONDS = 3

local function poll(player: Player)
	local maybeData = DataService.Get(player)
	if not maybeData then
		return
	end
	local data = maybeData :: Types.PlayerData
	local steps = Analytics.Steps
	if not Analytics.HasStep(player, steps.AtSand) then
		local root = Net.GetRoot(player)
		if root and World.IsInDigZone(root.Position) then
			Analytics.Funnel(player, steps.AtSand)
		end
	end
	if not Analytics.HasStep(player, steps.FirstPet) then
		for _, pet in data.Pets do
			if pet.Equipped then
				Analytics.Funnel(player, steps.FirstPet)
				break
			end
		end
	end
	if not Analytics.HasStep(player, steps.FirstQuestClaim) then
		for _, quest in data.Quests do
			if quest.Claimed then
				Analytics.Funnel(player, steps.FirstQuestClaim)
				break
			end
		end
	end
	if not Analytics.HasStep(player, steps.FirstShadeOrSnack) and count(data.OwnedShades) > 0 then
		Analytics.Funnel(player, steps.FirstShadeOrSnack)
	end
end

-- Track remote (client -> server UI events) --------------------------------------------------------

-- Returns true when the event was accepted (tests use this).
function Analytics.OnTrack(player: Player, name: any, a: any, b: any): boolean
	if not Net.IsString(name, 32) then
		return false
	end
	if name == "panel_opened" then
		if not Net.IsString(a, 32) or not Analytics.TRACK_PANELS[a] then
			return false
		end
		Analytics.PanelOpened(player, a)
		return true
	elseif name == "purchase_prompted" then
		if not Net.IsString(b, 40) then
			return false
		end
		if a == "GamePass" and Config.Monetization.GamePasses[b] then
			Analytics.PurchasePrompted(player, "Pass:" .. b)
			return true
		elseif a == "Product" and Config.Monetization.Products[b] then
			Analytics.PurchasePrompted(player, "Product:" .. b)
			return true
		end
		return false
	elseif name == "menu_unlocked" then
		if not Net.IsString(a, 16) or not Analytics.TRACK_MENU[a] then
			return false
		end
		Analytics.Custom(player, "MenuUnlocked", a)
		return true
	end
	return false
end

-- Lifecycle ----------------------------------------------------------------------------------------

function Analytics.Init()
	Net.On("Track", function(player: Player, name: any, a: any, b: any)
		Analytics.OnTrack(player, name, a, b)
	end, { Rate = Analytics.TRACK_RATE, Window = Analytics.TRACK_WINDOW })

	ServerSignals.Dug:Connect(function(player: Player, _depth: number, _gained: number, source: string)
		Analytics.Funnel(player, Analytics.Steps.AtSand) -- digging implies standing on the sand
		Analytics.Funnel(player, Analytics.Steps.FirstDig)
		if source == "Pet" then
			Analytics.Funnel(player, Analytics.Steps.FirstPetDig)
		end
	end)
	ServerSignals.BackpackFull:Connect(function(player: Player)
		Analytics.Funnel(player, Analytics.Steps.BackpackFull)
	end)
	ServerSignals.Sold:Connect(function(player: Player)
		Analytics.Funnel(player, Analytics.Steps.FirstSell)
	end)
	ServerSignals.UpgradeBought:Connect(function(player: Player, kind: string)
		local maybeData = DataService.Get(player)
		if not maybeData then
			return
		end
		local data = maybeData :: Types.PlayerData
		if kind == "Shovel" then
			Analytics.Funnel(player, Analytics.Steps.FirstShovel)
			if count(data.OwnedShovels) >= 3 then
				Analytics.Funnel(player, Analytics.Steps.SecondShovel)
			end
		elseif kind == "Backpack" then
			Analytics.Funnel(player, Analytics.Steps.FirstBackpack)
		end
	end)
	ServerSignals.DepthReached:Connect(onDepthReached)
	ServerSignals.Rebirthed:Connect(function(player: Player, rebirths: number)
		Analytics.Funnel(player, Analytics.Steps.FirstRebirth)
		Analytics.Progression(player, "Rebirth", "Complete", rebirths, "Rebirth " .. rebirths)
	end)
end

function Analytics.Start()
	task.spawn(function()
		while true do
			task.wait(POLL_SECONDS)
			for _, player in DataService.GetLoadedPlayers() do
				local ok, err = pcall(function()
					poll(player)
				end)
				if not ok then
					warn("[Analytics] poll: " .. tostring(err))
				end
			end
		end
	end)
end

function Analytics.OnPlayerAdded(player: Player)
	-- Sunburnt / ride starts come from player attributes (SurvivalService / RideService).
	player:GetAttributeChangedSignal("Sunburnt"):Connect(function()
		if player:GetAttribute("Sunburnt") == true then
			local depth = player:GetAttribute("Depth")
			local layer = Config.GetLayerIndexAtDepth(if type(depth) == "number" then depth else 0)
			Analytics.Custom(player, "Sunburnt", tostring(layer))
		end
	end)
	player:GetAttributeChangedSignal("Riding"):Connect(function()
		local riding = player:GetAttribute("Riding")
		if type(riding) == "string" and riding ~= "" then
			Analytics.Custom(player, "RideStarted", riding)
		end
	end)
	task.spawn(function()
		local data = DataService.WaitForData(player, 60)
		if data and player.Parent then
			lastLayer[player] = Config.GetLayerIndexAtDepth(data.MaxDepth)
		end
	end)
end

function Analytics.OnPlayerRemoving(player: Player)
	lastLayer[player] = nil
	shopSessions[player] = nil
end

return Analytics
