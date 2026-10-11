--!nocheck
-- Receipt delivery must remain pending until the player grant is durable.
local Mock = require("./mock/Roblox")
local Generated = require("../build/test/generated")
Mock.Init(Generated)
local function load(name)
	return Mock.Require(Mock.ByPath["ServerScriptService/Server/Services/" .. name])
end
local Config = Mock.Require(Mock.ByPath["ReplicatedStorage/Shared/Config"])
local Data = load("DataService")
Data.Init()
local player = Mock.AddPlayer(7201, "ReceiptBuyer")
Data.OnPlayerAdded(player)
Mock.Advance(1)
assert(Data.IsLoaded(player))
local Monetization = load("MonetizationService")
Monetization.Init()
local grants = 0
Monetization.SetGrantHandler(function(p)
	grants += 1
	Data.Increment(p, "Coins", 500)
	return true
end)
local receipt =
	{ PlayerId = player.UserId, ProductId = Config.Monetization.Products.CoinsSmall.Id, PurchaseId = "save-failure" }
local function deliver()
	local decision
	Mock.Env.task.spawn(function()
		decision = Mock.Service("MarketplaceService").ProcessReceipt(receipt)
	end)
	Mock.Advance(12)
	return decision
end
local save = Data.SaveAsync
Data.SaveAsync = function()
	return false
end
assert(
	deliver() == Mock.Enum.ProductPurchaseDecision.NotProcessedYet,
	"failed player save must not acknowledge paid delivery"
)
assert(grants == 1)
assert(deliver() == Mock.Enum.ProductPurchaseDecision.NotProcessedYet, "pending grant must retry its save")
assert(grants == 1, "save retry must not grant twice")
Data.SaveAsync = save
assert(deliver() == Mock.Enum.ProductPurchaseDecision.PurchaseGranted)
assert(grants == 1)
assert(Mock.DataStores[Config.DATASTORE_NAME]["Player_7201"].Data.Coins == 500)

-- Crash boundary: the player save succeeds but the separate history write fails.
receipt.PurchaseId = "history-failure"
Data.SaveAsync = function(p)
	local saved = save(p)
	Mock.DataStoreFail = true
	return saved
end
assert(deliver() == Mock.Enum.ProductPurchaseDecision.NotProcessedYet)
assert(grants == 2)
Mock.DataStoreFail = false
Data.SaveAsync = save
Data.OnPlayerRemoving(player)
Mock.Advance(1)
Mock.RemovePlayer(player)
player = Mock.AddPlayer(7201, "ReceiptBuyer")
Data.OnPlayerAdded(player)
Mock.Advance(1)
assert(Data.Get(player).Coins == 1000)
-- Fresh receipt processor: no old process-local duplicate cache can mask the bug.
local original = Mock.ByPath["ServerScriptService/Server/Services/MonetizationService"]
local fresh = Mock.Env.Instance.new("ModuleScript")
fresh.Name = "FreshReceiptProcessor"
fresh.Parent = original.Parent
for _, entry in Generated.Sources do
	if table.concat(entry.Path, "/") == "ServerScriptService/Server/Services/MonetizationService" then
		Mock.SetSource(fresh, entry.Source)
	end
end
Monetization = Mock.Require(fresh)
Monetization.Init()
Monetization.SetGrantHandler(function(p)
	grants += 1
	Data.Increment(p, "Coins", 500)
	return true
end)
assert(deliver() == Mock.Enum.ProductPurchaseDecision.PurchaseGranted)
assert(grants == 2, "durable marker must prevent regrant after rejoin and history failure")
assert(Data.Get(player).Coins == 1000)
receipt.PurchaseId = "legacy-history"
Mock.DataStores.PurchaseHistory_v1[receipt.PurchaseId] = { UserId = player.UserId }
assert(deliver() == Mock.Enum.ProductPurchaseDecision.PurchaseGranted)
assert(grants == 2, "old purchase history must continue to suppress duplicate grants")
assert(#Mock.Errors == 0)
print("PURCHASE DURABILITY: PASSED")
