--!nocheck
-- Every configured core product/pass, durable rejoin, and final shutdown save.
local Mock = require("./mock/Roblox")
local Generated = require("../build/test/generated")
Mock.Init(Generated)
local function load(name)
	return Mock.Require(Mock.ByPath["ServerScriptService/Server/Services/" .. name])
end
local Config = Mock.Require(Mock.ByPath["ReplicatedStorage/Shared/Config"])
local Data = load("DataService")
local Monetization = load("MonetizationService")
local Rewards = load("RewardsService")
Data.Init()
Monetization.Init()
Monetization.SetGrantHandler(Rewards.Grant)
local market = Mock.Service("MarketplaceService")
local entitlementIds = {}
Mock.OwnedGamePasses = { [7301] = entitlementIds }
local player
local function join()
	player = Mock.AddPlayer(7301, "CoreBuyer")
	Data.OnPlayerAdded(player)
	Monetization.OnPlayerAdded(player)
	Mock.Advance(1)
	assert(Data.IsLoaded(player))
end
local function rejoin()
	Data.OnPlayerRemoving(player)
	Monetization.OnPlayerRemoving(player)
	Mock.Advance(1)
	Mock.RemovePlayer(player)
	join()
end
local function deliver(receipt)
	local decision
	Mock.Env.task.spawn(function()
		decision = market.ProcessReceipt(receipt)
	end)
	Mock.Advance(1)
	assert(decision == Mock.Enum.ProductPurchaseDecision.PurchaseGranted)
end
join()
local passCount, productCount = 0, 0
for key, pass in Config.Monetization.GamePasses do
	assert(pass.Id > 0)
	entitlementIds[pass.Id] = true
	Mock.FireEvent(market, "PromptGamePassPurchaseFinished", player, pass.Id, true)
	Mock.FireEvent(market, "PromptGamePassPurchaseFinished", player, pass.Id, true)
	assert(Monetization.OwnsPass(player, key))
	assert(player:GetAttribute("Pass_" .. key) == true)
	rejoin()
	assert(Monetization.GetOwnedPasses(player)[key] == true, key .. " lost on rejoin")
	passCount += 1
end
for key, product in Config.Monetization.Products do
	assert(product.Id > 0)
	local data = Data.Get(player)
	local coins, rebirths = data.Coins, data.Rebirths
	local boost = product.Grant.Boost
	local expiry = if boost then data.Boosts[boost] or 0 else nil
	local expectedCoins = Config.ResolveCoins(product.Grant, data.MaxDepth)
	local startedAt = Mock.Env.os.time()
	local receipt = { PlayerId = player.UserId, ProductId = product.Id, PurchaseId = "sweep-" .. key }
	deliver(receipt)
	if product.Grant.Rebirth then
		assert(data.Rebirths == rebirths + 1, key .. " must grant one rebirth")
	elseif boost then
		assert(data.Boosts[boost] >= math.max(expiry, startedAt) + product.Grant.BoostSeconds)
		assert(data.Boosts[boost] <= math.max(expiry, Mock.Env.os.time()) + product.Grant.BoostSeconds)
	else
		assert(data.Coins == coins + expectedCoins, key .. " wrong coin grant")
	end
	local afterCoins, afterRebirths = data.Coins, data.Rebirths
	local afterBoost = if boost then data.Boosts[boost] else nil
	deliver(receipt)
	assert(data.Coins == afterCoins and data.Rebirths == afterRebirths)
	if boost then
		assert(data.Boosts[boost] == afterBoost)
	end
	rejoin()
	deliver(receipt)
	data = Data.Get(player)
	assert(data.Coins == afterCoins and data.Rebirths == afterRebirths, key .. " changed after rejoin/replay")
	if boost then
		assert(data.Boosts[boost] == afterBoost)
	end
	assert(data.PurchaseReceipts[receipt.PurchaseId] == true)
	productCount += 1
end
Data.Start()
Data.Set(player, "Coins", 4321)
Data.Set(player, "Sand", 7)
Data.Set(player, "Finds", { [Config.Treasures[1].Id .. "|Normal|None|Good"] = 1 })
Mock.RunBindToClose()
Mock.Advance(2)
local saved = Mock.DataStores[Config.DATASTORE_NAME].Player_7301
assert(saved.Lock == nil, "shutdown must release session lock")
assert(saved.Data.Coins == 4321 and saved.Data.Sand == 7)
assert(next(saved.Data.Finds) ~= nil)
assert(saved.Data.PurchaseReceipts["sweep-SkipRebirth"] == true)
assert(#Mock.Errors == 0)
print("CORE PURCHASE SWEEP: " .. passCount .. " passes, " .. productCount .. " products, rejoin and shutdown PASSED")
