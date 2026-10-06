--!strict
--[[
	PurchaseController — Robux prompts straight from the client via MarketplaceService.
	Ids of 0 mean "not configured" (Config.Monetization): never prompt, callers disable the UI.
	On a completed pass purchase we mark it owned locally and re-sync with GetOwnedPasses.
	v2.2: never prompts a PaidRandom item while the player is policy-restricted (State.CanBuy);
	the server's MonetizationService refuses those prompts too.
	v2.3: GetPrice(kind, key) returns the live Robux price from MarketplaceService:GetProductInfo
	(fetched once per configured Id, in the background) and falls back to the config suggestion
	(Config.Monetization *.Price) while the Id is 0, the lookup is pending or failed, or the item
	is off sale. PriceChanged fires when a live price arrives so the store can re-render.
]]
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local State = require(script.Parent.State)
local Signal = require(script.Parent.Parent.Util.Signal)
local Track = require(script.Parent.Parent.Util.Track)

local PurchaseController = {}

PurchaseController.PassPurchased = Signal.new() -- (key)
PurchaseController.PriceChanged = Signal.new() -- (kind, key)

local livePrices: { [string]: number } = {} -- "GamePass:VIP" -> Robux
local priceRequested: { [string]: boolean } = {}

local function fetchPrice(kind: string, key: string, id: number)
	local ok, info = pcall(function(): any
		local infoType = if kind == "GamePass" then Enum.InfoType.GamePass else Enum.InfoType.Product
		return MarketplaceService:GetProductInfo(id, infoType)
	end)
	local price = if ok and type(info) == "table" then (info :: any).PriceInRobux else nil
	if type(price) == "number" and price > 0 then
		livePrices[kind .. ":" .. key] = price
		PurchaseController.PriceChanged:Fire(kind, key)
	end
end

-- Robux price to show: live Creator Hub price when known, else the config suggestion.
function PurchaseController.GetPrice(kind: string, key: string): number
	local id, price
	if kind == "GamePass" then
		local pass = Config.Monetization.GamePasses[key]
		if not pass then
			return 0
		end
		id, price = pass.Id, pass.Price
	else
		local product = Config.Monetization.Products[key]
		if not product then
			return 0
		end
		id, price = product.Id, product.Price
	end
	local cacheKey = kind .. ":" .. key
	local live = livePrices[cacheKey]
	if live then
		return live
	end
	if id ~= 0 and not priceRequested[cacheKey] then
		priceRequested[cacheKey] = true
		task.spawn(fetchPrice, kind, key, id)
	end
	return price
end

-- "Configured" = has a real id AND may be offered to this player (v2.2 policy: PaidRandom items
-- are unavailable while State.IsPaidRandomRestricted()), so UI that hides unconfigured items
-- (Rebirth panel's Skip button, Golden Egg buttons) also hides restricted ones.
function PurchaseController.IsPassConfigured(key: string): boolean
	local pass = Config.Monetization.GamePasses[key]
	return pass ~= nil and pass.Id ~= 0 and State.CanBuy("GamePass", key)
end

function PurchaseController.IsProductConfigured(key: string): boolean
	local product = Config.Monetization.Products[key]
	return product ~= nil and product.Id ~= 0 and State.CanBuy("Product", key)
end

-- Returns false (and does nothing) when the pass id is 0 or it is already owned.
function PurchaseController.PromptPass(key: string): boolean
	local pass = Config.Monetization.GamePasses[key]
	if not pass or pass.Id == 0 or State.OwnsPass(key) then
		return false
	end
	if not State.CanBuy("GamePass", key) then
		return false -- v2.2 policy: paid random items are hidden for this player
	end
	local ok, err = pcall(function()
		MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, pass.Id)
	end)
	if ok then
		Track.Send("purchase_prompted", "GamePass", key)
	end
	if not ok then
		warn("[Purchase] pass prompt failed", key, err)
	end
	return ok
end

function PurchaseController.PromptProduct(key: string): boolean
	local product = Config.Monetization.Products[key]
	if not product or product.Id == 0 then
		return false
	end
	if not State.CanBuy("Product", key) then
		return false -- v2.2 policy: paid random items are hidden for this player
	end
	local ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(Players.LocalPlayer, product.Id)
	end)
	if ok then
		Track.Send("purchase_prompted", "Product", key)
	end
	if not ok then
		warn("[Purchase] product prompt failed", key, err)
	end
	return ok
end

function PurchaseController.Init()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			if player ~= Players.LocalPlayer or not purchased then
				return
			end
			local key = Config.GetGamePassKeyById(passId)
			if key then
				State.SetPassOwned(key, true)
				PurchaseController.PassPurchased:Fire(key)
			end
			task.delay(2, State.RefreshPasses)
		end
	)
end

return PurchaseController
