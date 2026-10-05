--!strict
--[[
	PurchaseController — Robux prompts straight from the client via MarketplaceService.
	Ids of 0 mean "not configured" (Config.Monetization): never prompt, callers disable the UI.
	On a completed pass purchase we mark it owned locally and re-sync with GetOwnedPasses.
]]
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local State = require(script.Parent.State)
local Signal = require(script.Parent.Parent.Util.Signal)

local PurchaseController = {}

PurchaseController.PassPurchased = Signal.new() -- (key)

function PurchaseController.IsPassConfigured(key: string): boolean
	local pass = Config.Monetization.GamePasses[key]
	return pass ~= nil and pass.Id ~= 0
end

function PurchaseController.IsProductConfigured(key: string): boolean
	local product = Config.Monetization.Products[key]
	return product ~= nil and product.Id ~= 0
end

-- Returns false (and does nothing) when the pass id is 0 or it is already owned.
function PurchaseController.PromptPass(key: string): boolean
	local pass = Config.Monetization.GamePasses[key]
	if not pass or pass.Id == 0 or State.OwnsPass(key) then
		return false
	end
	local ok, err = pcall(function()
		MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, pass.Id)
	end)
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
	local ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(Players.LocalPlayer, product.Id)
	end)
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
