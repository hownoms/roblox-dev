--!strict
--[[
	OfflinePopup — "Welcome back!" card for offline pet earnings (server OfflineService, v2.2).

	OfflineEarnings({ Seconds, Away, Sand, Coins, CapSeconds, Capped, PetId }) arrives a few
	seconds after joining. The coins are already granted by the server; the shared Reveal popup
	shows what the pets dug ("While you were away your pets dug 12K sand -> +12K coins!") and,
	when it closes, coins fly into the coins counter. If the cap was hit it says so and points at
	the Long Nap rebirth perk. No Robux upsell, on purpose.

	Public API:
		OfflinePopup.Show(info)   (also used by tests)
		OfflinePopup.LastText: string   (the summary line of the last popup; tests)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))

local Style = require(script.Parent.Components.Style)
local Reveal = require(script.Parent.Reveal)
local UIEffects = require(script.Parent.UIEffects)
local Icons = require(script.Parent.Icons)
local HUD = require(script.Parent.HUD)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local ModelFactory = require(script.Parent.Parent.Util.ModelFactory)

local OfflinePopup = {}

OfflinePopup.LastText = ""

local C = Style.Colors

local function num(value: any): number
	return if typeof(value) == "number" and value == value then value else 0
end

function OfflinePopup.Show(info: any)
	if typeof(info) ~= "table" then
		return
	end
	local coins = num(info.Coins)
	if coins <= 0 then
		return
	end
	local sand = num(info.Sand)
	local seconds = num(info.Seconds)
	local away = math.max(num(info.Away), seconds)
	local capped = info.Capped == true
	local petId = if typeof(info.PetId) == "string" and Config.GetPet(info.PetId) then info.PetId else nil

	OfflinePopup.LastText = string.format(
		"While you were away your pets dug %s sand → +%s coins!",
		Format.Abbreviate(sand),
		Format.Abbreviate(coins)
	)
	local rows = {
		{ Label = "AWAY", Value = Format.Time(away), Color = C.Time },
		{ Label = "PETS DUG", Value = Format.Abbreviate(sand) .. " sand", Color = C.Highlight },
		{ Label = "COINS", Value = "+" .. Format.Abbreviate(coins), Color = C.Money },
	}
	if capped then
		table.insert(rows, {
			Label = "LIMIT",
			Value = Format.Time(num(info.CapSeconds)) .. " (Long Nap perk)",
			Color = C.Coral,
		})
	end
	local model: Model? = nil
	if petId then
		local ok, result = pcall(ModelFactory.Pet, petId)
		if ok then
			model = result
		end
	end
	Reveal.Show({
		Headline = "WELCOME BACK!",
		Caption = OfflinePopup.LastText,
		Color = C.Money,
		Items = {
			{
				Name = "Tap to collect!",
				NameColor = C.Money,
				Model = model,
				Rows = rows,
			},
		},
		Sound = "Purchase",
		Confetti = true,
		Hold = 8,
		OnClosed = function()
			SoundController.Play("Coin")
			local counter = HUD.Coins
			if counter then
				UIEffects.FlyTo(Icons.Coins, counter.Badge, 12, nil, function()
					SoundController.Play("Coin")
				end)
			end
		end,
	})
end

function OfflinePopup.Init()
	Remotes.Get("OfflineEarnings").OnClientEvent:Connect(OfflinePopup.Show)
end

return OfflinePopup
