--!strict
--[[
	Client bootstrap (StarterPlayerScripts.Client.Main).
	Order: data store -> services/controllers without UI -> UI root & components -> HUD/panels
	-> world controllers -> tutorial. Every step is isolated with xpcall so one failing module
	never takes the whole client down, and nothing blocks on PlayerData: UI renders defaults
	and fills in when DataChanged / GetData arrives (State.Observe).
]]
local Client = script.Parent
local Controllers = Client:WaitForChild("Controllers")
local UI = Client:WaitForChild("UI")
local Panels = UI:WaitForChild("Panels")

local State = require(Controllers:WaitForChild("State"))
local SoundController = require(Controllers:WaitForChild("SoundController"))
local EffectsController = require(Controllers:WaitForChild("EffectsController"))
local PurchaseController = require(Controllers:WaitForChild("PurchaseController"))
local GuideController = require(Controllers:WaitForChild("GuideController"))
local LayerController = require(Controllers:WaitForChild("LayerController"))
local DigController = require(Controllers:WaitForChild("DigController"))
local PetFollowController = require(Controllers:WaitForChild("PetFollowController"))
local WorldPromptController = require(Controllers:WaitForChild("WorldPromptController"))
local InputController = require(Controllers:WaitForChild("InputController"))
local TutorialController = require(Controllers:WaitForChild("TutorialController"))

local Root = require(UI:WaitForChild("Root"))
local Toasts = require(UI:WaitForChild("Toasts"))
local Banner = require(UI:WaitForChild("Banner"))
local HUD = require(UI:WaitForChild("HUD"))
local HatchAnimation = require(UI:WaitForChild("HatchAnimation"))
local TreasurePopup = require(UI:WaitForChild("TreasurePopup"))

local ShopPanel = require(Panels:WaitForChild("ShopPanel"))
local EggPanel = require(Panels:WaitForChild("EggPanel"))
local PetsPanel = require(Panels:WaitForChild("PetsPanel"))
local IndexPanel = require(Panels:WaitForChild("IndexPanel"))
local QuestsPanel = require(Panels:WaitForChild("QuestsPanel"))
local DailyPanel = require(Panels:WaitForChild("DailyPanel"))
local RebirthPanel = require(Panels:WaitForChild("RebirthPanel"))
local StorePanel = require(Panels:WaitForChild("StorePanel"))
local SettingsPanel = require(Panels:WaitForChild("SettingsPanel"))

local function start(name: string, fn: () -> ())
	local ok, err = xpcall(function(): any
		fn()
		return nil
	end, function(message: any): string
		return debug.traceback(tostring(message))
	end)
	if not ok then
		warn("[Client] " .. name .. " failed to start:\n" .. tostring(err))
	end
end

-- 1. Data + non-visual services
start("State", State.Init)
start("Sound", SoundController.Init)
start("Effects", EffectsController.Init)
start("Purchase", PurchaseController.Init)
start("Guide", GuideController.Init)

-- 2. UI
start("UIRoot", Root.Init)
start("Toasts", Toasts.Init)
start("HUD", HUD.Init)
start("ShopPanel", ShopPanel.Init)
start("EggPanel", EggPanel.Init)
start("PetsPanel", PetsPanel.Init)
start("IndexPanel", IndexPanel.Init)
start("QuestsPanel", QuestsPanel.Init)
start("DailyPanel", DailyPanel.Init)
start("RebirthPanel", RebirthPanel.Init)
start("StorePanel", StorePanel.Init)
start("SettingsPanel", SettingsPanel.Init)
start("HatchAnimation", HatchAnimation.Init)
start("TreasurePopup", TreasurePopup.Init)

-- 3. Wiring between controllers and UI (controllers stay UI-agnostic)
DigController.SetHintCallback(function(text: string, kind: string)
	Toasts.Show(text, kind)
end)
LayerController.SetBannerCallback(function(index: number, isNew: boolean)
	Banner.ShowLayer(index, isNew)
end)

-- 4. World controllers
start("Layer", LayerController.Init)
start("Dig", DigController.Init)
start("PetFollow", PetFollowController.Init)
start("WorldPrompts", WorldPromptController.Init)
start("Input", InputController.Init)
start("Tutorial", TutorialController.Init)
