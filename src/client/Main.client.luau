--!strict
--[[
	Client bootstrap (StarterPlayerScripts.Client.Main).
	Order: data store -> services/controllers without UI -> UI root & components -> HUD/panels
	-> world controllers -> tutorial. Every step is isolated with xpcall so one failing module
	never takes the whole client down, and nothing blocks on PlayerData: UI renders defaults
	and fills in when DataChanged / GetData arrives (State.Observe).
]]
-- Guard against a second copy of the client (e.g. a stale "Client" folder left in the place
-- next to the Rojo-synced one), which would double every popup and remote call.
local sharedState = shared :: any
if sharedState.DigToTheCoreClient then
	warn(
		"[Client] Duplicate client script ignored: "
			.. script:GetFullName()
			.. " (already running: "
			.. tostring(sharedState.DigToTheCoreClient)
			.. "). Delete the extra copy from StarterPlayerScripts."
	)
	return
end
sharedState.DigToTheCoreClient = script:GetFullName()

-- The shovel is auto-equipped, so hide Roblox's tool hotbar (it covers the backpack bar).
pcall(function()
	game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

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
local ShovelPoseController = require(Controllers:WaitForChild("ShovelPoseController"))
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
local OfflinePopup = require(UI:WaitForChild("OfflinePopup")) -- v2.2 offline pet earnings

local ShopPanel = require(Panels:WaitForChild("ShopPanel"))
local EggPanel = require(Panels:WaitForChild("EggPanel"))
local PetsPanel = require(Panels:WaitForChild("PetsPanel"))
local IndexPanel = require(Panels:WaitForChild("IndexPanel"))
local QuestsPanel = require(Panels:WaitForChild("QuestsPanel"))
local DailyPanel = require(Panels:WaitForChild("DailyPanel"))
local RebirthPanel = require(Panels:WaitForChild("RebirthPanel"))
local StorePanel = require(Panels:WaitForChild("StorePanel"))
local SettingsPanel = require(Panels:WaitForChild("SettingsPanel"))
local BeachShopPanel = require(Panels:WaitForChild("BeachShopPanel"))
local SurvivalHUD = require(UI:WaitForChild("SurvivalHUD"))
local SurvivalController = require(Controllers:WaitForChild("SurvivalController"))
local PlacementController = require(Controllers:WaitForChild("PlacementController"))
local RideController = require(Controllers:WaitForChild("RideController"))
local RideButton = require(UI:WaitForChild("RideButton"))
-- v2.2 status & social: nameplates + worn pack fill, rare-find banners, server goal / friends
local StatusController = require(Controllers:WaitForChild("StatusController"))
local Announcements = require(UI:WaitForChild("Announcements"))
local SocialHUD = require(UI:WaitForChild("SocialHUD"))
-- v3 discovery slice: detector, excavation minigame, tiered find reveals
local DiscoveryController = require(Controllers:WaitForChild("DiscoveryController"))
local DetectorHUD = require(UI:WaitForChild("DetectorHUD"))
local ExcavationGame = require(UI:WaitForChild("ExcavationGame"))
local FindReveal = require(UI:WaitForChild("FindReveal"))
local Reveal = require(UI:WaitForChild("Reveal"))
local ChatLayoutController = require(Controllers:WaitForChild("ChatLayoutController"))

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
start("ChatLayout", ChatLayoutController.Init)

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
start("BeachShopPanel", BeachShopPanel.Init)
start("SurvivalHUD", SurvivalHUD.Init)
start("HatchAnimation", HatchAnimation.Init)
start("TreasurePopup", TreasurePopup.Init)
start("OfflinePopup", OfflinePopup.Init)
start("Announcements", Announcements.Init)
start("SocialHUD", SocialHUD.Init)
start("DetectorHUD", DetectorHUD.Init)
start("ExcavationGame", ExcavationGame.Init)
start("FindReveal", FindReveal.Init)

-- 3. Wiring between controllers and UI (controllers stay UI-agnostic)
DigController.SetHintCallback(function(text: string, kind: string)
	Toasts.Show(text, kind)
end)
LayerController.SetBannerCallback(function(index: number, isNew: boolean)
	Banner.ShowLayer(index, isNew)
end)
-- Reveal headlines sit where your own nameplate floats: hide it while one is up.
Reveal.Opened:Connect(function()
	StatusController.SetOwnHidden(true)
end)
Reveal.Closed:Connect(function()
	task.defer(function()
		StatusController.SetOwnHidden(Reveal.IsShowing())
	end)
end)

-- 4. World controllers
start("Layer", LayerController.Init)
start("Dig", DigController.Init)
start("ShovelPose", ShovelPoseController.Init)
start("PetFollow", PetFollowController.Init)
start("WorldPrompts", WorldPromptController.Init)
start("Input", InputController.Init)
start("Tutorial", TutorialController.Init)
start("Survival", SurvivalController.Init)
start("Placement", PlacementController.Init)
start("Ride", RideController.Init)
start("RideButton", RideButton.Init)
start("Status", StatusController.Init)
start("Discovery", DiscoveryController.Init)
