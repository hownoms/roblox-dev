--!strict
--[[
	SurvivalController — client side of heat / shade / snacks (owner: Survival). UI-agnostic:
	SurvivalHUD and BeachShopPanel call into it.

	- Map prompts: parts tagged "WaterFountain" -> DrinkFountain remote, "BeachShop" -> opens
	  Panel "BeachShop" (prompts may stream in late; GetTagged + added signals).
	- Keybinds: 1 / 2 / 3 use the consumable quick-slots, F starts / stops shade placement.
	- Quick-slots: the (up to) 3 best owned consumables, cheapest first.
	- Reads the server's player attributes: Heat, Sunburnt, InShade, HeatZone, HeatGrace.

	API:
		SurvivalController.GetHeat(): number                 (0..Config.Heat.Max)
		SurvivalController.IsSunburnt(): boolean
		SurvivalController.GetZone(): string                 ("Sun" | "Shade" | "Underground" | "Cool")
		SurvivalController.GetQuickSlots(): { string }       consumable ids
		SurvivalController.UseSlot(index) / UseConsumable(id) / DrinkFountain()
		SurvivalController.GetMyShades(): { Model }          my placed shades (tag "PlacedShade")
		SurvivalController.Changed: Signal                   heat attributes changed
]]
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))
local Signal = require(script.Parent.Parent.Util.Signal)
local State = require(script.Parent.State)
local SoundController = require(script.Parent.SoundController)
local PlacementController = require(script.Parent.PlacementController)
local Panel = require(script.Parent.Parent.UI.Components.Panel)

local SurvivalController = {}

SurvivalController.Changed = Signal.new()
SurvivalController.SLOT_COUNT = 3

local HEAT_ATTRIBUTES = { Heat = true, Sunburnt = true, InShade = true, HeatZone = true, HeatGrace = true }
local SLOT_KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }

local localPlayer = Players.LocalPlayer
local initialized = false

function SurvivalController.GetHeat(): number
	local heat = localPlayer:GetAttribute("Heat")
	return if type(heat) == "number" then heat else 0
end

function SurvivalController.IsSunburnt(): boolean
	return localPlayer:GetAttribute("Sunburnt") == true
end

function SurvivalController.IsInShade(): boolean
	return localPlayer:GetAttribute("InShade") == true
end

function SurvivalController.InGrace(): boolean
	return localPlayer:GetAttribute("HeatGrace") == true
end

function SurvivalController.GetZone(): string
	local zone = localPlayer:GetAttribute("HeatZone")
	return if type(zone) == "string" then zone else "Cool"
end

-- Up to SLOT_COUNT owned consumables: the most valuable ones, shown cheapest first.
function SurvivalController.GetQuickSlots(): { string }
	local owned: { Types.ConsumableDef } = {}
	local counts = State.Data.Consumables or ({} :: { [string]: number })
	for _, def in Config.Consumables do
		if def.Price > 0 and (counts[def.Id] or 0) > 0 then
			table.insert(owned, def)
		end
	end
	table.sort(owned, function(a, b)
		return a.Price > b.Price
	end)
	local best: { Types.ConsumableDef } = {}
	for i = 1, math.min(#owned, SurvivalController.SLOT_COUNT) do
		table.insert(best, owned[i])
	end
	table.sort(best, function(a, b)
		return a.Price < b.Price
	end)
	local ids = {}
	for _, def in best do
		table.insert(ids, def.Id)
	end
	return ids
end

function SurvivalController.UseConsumable(id: string): boolean
	local count = (State.Data.Consumables or ({} :: { [string]: number }))[id] or 0
	if count <= 0 then
		SoundController.Play("Error")
		return false
	end
	SoundController.Play("Splash", 1.4, 0.5)
	Remotes.Get("UseConsumable"):FireServer(id)
	return true
end

function SurvivalController.UseSlot(index: number): boolean
	local id = SurvivalController.GetQuickSlots()[index]
	if not id then
		Panel.Open("BeachShop", { Tab = "Snacks" })
		return false
	end
	return SurvivalController.UseConsumable(id)
end

function SurvivalController.DrinkFountain()
	SoundController.Play("Splash")
	Remotes.Get("DrinkFountain"):FireServer()
end

function SurvivalController.GetMyShades(): { Model }
	local list = {}
	for _, inst in CollectionService:GetTagged("PlacedShade") do
		if inst:IsA("Model") and inst:GetAttribute("OwnerUserId") == localPlayer.UserId and inst.Parent then
			table.insert(list, inst)
		end
	end
	return list
end

function SurvivalController.IsShadePlaced(shadeId: string): boolean
	for _, model in SurvivalController.GetMyShades() do
		if model:GetAttribute("ShadeId") == shadeId then
			return true
		end
	end
	return false
end

-- Prompts -----------------------------------------------------------------------------------------

local OPENERS: { [string]: () -> () } = {
	WaterFountain = function()
		SurvivalController.DrinkFountain()
	end,
	BeachShop = function()
		Panel.Open("BeachShop", { Tab = "Shade" })
	end,
}

local hooked: { [ProximityPrompt]: boolean } = {}

local function hookPrompt(tag: string, prompt: ProximityPrompt)
	if hooked[prompt] then
		return
	end
	hooked[prompt] = true
	prompt.Triggered:Connect(function()
		OPENERS[tag]()
	end)
	prompt.Destroying:Connect(function()
		hooked[prompt] = nil
	end)
end

local function hookTagged(tag: string, inst: Instance)
	if inst:IsA("ProximityPrompt") then
		hookPrompt(tag, inst)
		return
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			hookPrompt(tag, d)
		end
	end
	inst.DescendantAdded:Connect(function(d: Instance)
		if d:IsA("ProximityPrompt") then
			hookPrompt(tag, d)
		end
	end)
end

-- Init ----------------------------------------------------------------------------------------------

function SurvivalController.Init()
	if initialized then
		return
	end
	initialized = true

	for tag in OPENERS do
		for _, inst in CollectionService:GetTagged(tag) do
			task.spawn(hookTagged, tag, inst)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst: Instance)
			hookTagged(tag, inst)
		end)
	end

	localPlayer.AttributeChanged:Connect(function(name: string)
		if HEAT_ATTRIBUTES[name] then
			SurvivalController.Changed:Fire(name)
		end
	end)

	for i, key in SLOT_KEYS do
		ContextActionService:BindAction("SurvivalSlot" .. i, function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				SurvivalController.UseSlot(i)
			end
			return Enum.ContextActionResult.Sink
		end, false, key)
	end
	ContextActionService:BindAction("SurvivalPlaceShade", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			PlacementController.Toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.F)
end

return SurvivalController
