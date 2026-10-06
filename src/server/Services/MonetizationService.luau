--!strict
--[[
	MonetizationService — game passes, developer products, Premium.

	- Pass ownership is cached per player (UserOwnsGamePassAsync with retries on join, updated by
	  PromptGamePassPurchaseFinished). Never persisted in PlayerData. Passes with Id 0 are
	  "not configured" and always read as not owned; we never prompt id 0.
	- Replicated to the client via GetOwnedPasses() and Player attributes "Pass_<Key>" (bool),
	  plus "Premium" (bool) and "VIP" (bool, for chat tags / name colour).
	- ProcessReceipt: idempotent via the PurchaseHistory DataStore (key = PurchaseId) plus an
	  in-server guard; grants Config.Monetization.Products[key].Grant through the grant handler
	  (RewardsService.Grant, wired by Main) and saves the player's data before acknowledging.
	- v2.2 policy: PromptPass / PromptProduct refuse PaidRandom items (Config.IsPaidRandom) for
	  players PolicyService marks ArePaidRandomItemsRestricted. ProcessReceipt never checks the
	  policy: a purchase that already completed is always granted.

	Public API:
		MonetizationService.OwnsPass(player, key): boolean
		MonetizationService.GetOwnedPasses(player): { [key]: boolean }
		MonetizationService.IsPremium(player): boolean
		MonetizationService.PromptPass(player, key) / PromptProduct(player, key)
		MonetizationService.SetGrantHandler(fn)
		MonetizationService.PassesChanged: Signal<Player, string?>  (key, or nil for "all refreshed")
		MonetizationService.STUDIO_GRANT_ALL_PASSES (dev toggle, Studio only)
]]

local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local Signal = require(Shared.Util.Signal)

local DataService = require(script.Parent.DataService)
local Analytics = require(script.Parent.Analytics)
local Net = require(script.Parent.Net)
local PolicyService = require(script.Parent.PolicyService)

export type GrantHandler = (player: Player, reward: Types.Reward, source: string) -> boolean

local PURCHASE_HISTORY_STORE = "PurchaseHistory_v1"

local MonetizationService = {}

-- Studio-only convenience for testing pass features. Never affects live servers.
MonetizationService.STUDIO_GRANT_ALL_PASSES = false

MonetizationService.PassesChanged = Signal.new() :: Signal.Signal<Player, string?>

local owned: { [Player]: { [string]: boolean } } = {}
local grantHandler: GrantHandler? = nil
local historyStore: DataStore? = nil
local mockHistory: { [string]: boolean } = {}
local grantedThisServer: { [string]: boolean } = {}
local processing: { [string]: boolean } = {}

local function passKeys(): { string }
	local keys = {}
	for key in Config.Monetization.GamePasses do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

local PASS_KEYS = passKeys()

local function withRetries<T>(attempts: number, fn: () -> T): (boolean, T?)
	for attempt = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		if attempt < attempts then
			task.wait(attempt)
		else
			warn("[MonetizationService] " .. tostring(result))
		end
	end
	return false, nil
end

local function publish(player: Player)
	local map = owned[player]
	if not map or player.Parent == nil then
		return
	end
	for _, key in PASS_KEYS do
		player:SetAttribute("Pass_" .. key, map[key] == true)
	end
	player:SetAttribute("VIP", map.VIP == true)
end

local function refreshPremium(player: Player)
	player:SetAttribute("Premium", player.MembershipType == Enum.MembershipType.Premium)
end

local function loadPasses(player: Player)
	local map: { [string]: boolean } = {}
	owned[player] = map
	local grantAll = MonetizationService.STUDIO_GRANT_ALL_PASSES and RunService:IsStudio()
	for _, key in PASS_KEYS do
		local pass = Config.Monetization.GamePasses[key]
		if grantAll then
			map[key] = true
		elseif pass.Id ~= 0 then
			local ok, result = withRetries(3, function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok and result == true and owned[player] == map then
				map[key] = true
			end
		end
	end
	publish(player)
	MonetizationService.PassesChanged:Fire(player, nil)
end

-- Public API ------------------------------------------------------------------------------------

function MonetizationService.OwnsPass(player: Player, key: string): boolean
	local map = owned[player]
	return map ~= nil and map[key] == true
end

function MonetizationService.GetOwnedPasses(player: Player): { [string]: boolean }
	local map: { [string]: boolean } = owned[player] or {}
	local result: { [string]: boolean } = {}
	for _, key in PASS_KEYS do
		result[key] = map[key] == true
	end
	return result
end

function MonetizationService.IsPremium(player: Player): boolean
	return player.MembershipType == Enum.MembershipType.Premium
end

function MonetizationService.SetGrantHandler(handler: GrantHandler)
	grantHandler = handler
end

function MonetizationService.PromptPass(player: Player, key: string): boolean
	local pass = Config.Monetization.GamePasses[key]
	if not pass then
		return false
	end
	if pass.Id == 0 then
		Net.Notify(player, "Info", pass.Name .. " is coming soon!")
		return false
	end
	if not PolicyService.CanBuy(player, "GamePass", key) then
		Net.Notify(player, "Info", pass.Name .. " isn't available for your account.")
		return false
	end
	if MonetizationService.OwnsPass(player, key) then
		Net.Notify(player, "Info", "You already own " .. pass.Name .. "!")
		return false
	end
	local ok = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, pass.Id)
	end)
	if ok then
		Analytics.PurchasePrompted(player, "Pass:" .. key)
	end
	return ok
end

function MonetizationService.PromptProduct(player: Player, key: string): boolean
	local product = Config.Monetization.Products[key]
	if not product then
		return false
	end
	if product.Id == 0 then
		Net.Notify(player, "Info", product.Name .. " is coming soon!")
		return false
	end
	if not PolicyService.CanBuy(player, "Product", key) then
		Net.Notify(player, "Info", product.Name .. " isn't available for your account.")
		return false
	end
	local ok = pcall(function()
		MarketplaceService:PromptProductPurchase(player, product.Id)
	end)
	if ok then
		Analytics.PurchasePrompted(player, "Product:" .. key)
	end
	return ok
end

-- Receipts --------------------------------------------------------------------------------------

local function isRecorded(purchaseId: string): (boolean, boolean)
	-- returns (lookupOk, alreadyGranted)
	if grantedThisServer[purchaseId] then
		return true, true
	end
	if not historyStore then
		return true, mockHistory[purchaseId] == true
	end
	local store = historyStore :: DataStore
	local ok, value = withRetries(3, function()
		return store:GetAsync(purchaseId)
	end)
	return ok, ok and value ~= nil
end

local function record(purchaseId: string, info: { [any]: any }, key: string): boolean
	if not historyStore then
		mockHistory[purchaseId] = true
		return true
	end
	local store = historyStore :: DataStore
	local ok = withRetries(4, function()
		store:SetAsync(purchaseId, {
			UserId = info.PlayerId,
			ProductId = info.ProductId,
			Key = key,
			Time = os.time(),
		}, { info.PlayerId })
		return true
	end)
	return ok
end

local function processReceipt(info: { [any]: any }): Enum.ProductPurchaseDecision
	local userId = info.PlayerId
	local productId = info.ProductId
	local purchaseId = tostring(info.PurchaseId)
	if type(userId) ~= "number" or type(productId) ~= "number" then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local key = Config.GetProductKeyById(productId)
	local product = if key then Config.Monetization.Products[key] else nil
	if not key or not product then
		warn("[MonetizationService] receipt for unknown product id " .. tostring(productId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local productKey = key :: string
	local grant = (product :: Types.ProductDef).Grant

	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox retries when they rejoin
	end
	if not DataService.WaitForData(player, 20) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if processing[purchaseId] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	processing[purchaseId] = true

	local decision = Enum.ProductPurchaseDecision.NotProcessedYet
	local lookupOk, already = isRecorded(purchaseId)
	if lookupOk and already then
		decision = Enum.ProductPurchaseDecision.PurchaseGranted
	elseif lookupOk then
		local granted = false
		if grantHandler then
			local ok, result = pcall(grantHandler :: GrantHandler, player, grant, "Product:" .. productKey)
			granted = ok and result == true
			if not ok then
				warn("[MonetizationService] grant failed: " .. tostring(result))
			end
		else
			warn("[MonetizationService] no grant handler registered")
		end
		if granted then
			grantedThisServer[purchaseId] = true
			Analytics.PurchaseCompleted(player, "Product:" .. productKey)
			DataService.SaveAsync(player)
			if record(purchaseId, info, productKey) then
				decision = Enum.ProductPurchaseDecision.PurchaseGranted
			end
			-- If recording failed we answer NotProcessedYet; grantedThisServer prevents a second
			-- grant when Roblox retries on this server.
		end
	end

	processing[purchaseId] = nil
	return decision
end

-- Lifecycle -------------------------------------------------------------------------------------

function MonetizationService.Init()
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(PURCHASE_HISTORY_STORE)
	end)
	if ok and not DataService.IsMock() then
		historyStore = store
	end

	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			if not purchased then
				return
			end
			local key = Config.GetGamePassKeyById(passId)
			if not key then
				return
			end
			local passKey = key :: string
			local map = owned[player]
			if not map then
				map = {}
				owned[player] = map
			end
			map[passKey] = true
			publish(player)
			Net.Notify(player, "Success", "Thanks! " .. Config.Monetization.GamePasses[passKey].Name .. " unlocked!")
			Analytics.PurchaseCompleted(player, "Pass:" .. passKey)
			MonetizationService.PassesChanged:Fire(player, passKey)
		end
	)

	Players.PlayerMembershipChanged:Connect(function(player: Player)
		refreshPremium(player)
		MonetizationService.PassesChanged:Fire(player, nil)
	end)

	Net.OnInvoke("GetOwnedPasses", function(player: Player)
		return MonetizationService.GetOwnedPasses(player)
	end, {}, { Rate = 5, Window = 1 })

	Net.On("PromptPurchase", function(player: Player, kind: any, key: any)
		if not Net.IsString(key, 40) then
			return
		end
		if kind == "GamePass" then
			MonetizationService.PromptPass(player, key)
		elseif kind == "Product" then
			MonetizationService.PromptProduct(player, key)
		end
	end, { Rate = 3, Window = 2, RequireData = false })
end

function MonetizationService.Start() end

function MonetizationService.OnPlayerAdded(player: Player)
	refreshPremium(player)
	task.spawn(loadPasses, player)
end

function MonetizationService.OnPlayerRemoving(player: Player)
	owned[player] = nil
end

return MonetizationService
