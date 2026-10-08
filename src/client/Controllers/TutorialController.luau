--!strict
--[[
	TutorialController — first-time user experience driven by Config.TUTORIAL_STEPS.

	Progress = number of completed steps, persisted with SetSetting("Tutorial", n) and read
	back from data.Settings.Tutorial (veterans without the key skip it). Each step shows the
	slim top-centre objective pill (UI/ObjectiveBanner: icon, short line, step n/6, arrow),
	a guide Beam + bouncing marker to its Target
	("Sand" = the nearest point of the shared dig zone, otherwise the nearest part with that
	CollectionService tag), and completes on its Complete event:
	  AtSand        standing on the dig-zone sand   Dig        first successful dig
	  BackpackFull  sand >= capacity               Sell       sand emptied after filling
	  BuyShovel     own a 2nd shovel               HatchEgg   hatched / own a pet
	  NewLayer      reached the first layer the starter shovel cannot dig (the upgrade's payoff)
	The checks are state-based (polled), so the tutorial resumes correctly after rejoining.
	While the "shop" step's shovel is unaffordable, the banner shows coins/price and the guide
	points back to the sand (or the sell stand when the bucket is full) instead of the shop.
	On join, steps that are already satisfied are skipped silently, so inserting a step never
	re-runs the tutorial (or its completion fanfare) for players who had finished it.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local State = require(script.Parent.State)
local GuideController = require(script.Parent.GuideController)
local DigController = require(script.Parent.DigController)
local DiscoveryController = require(script.Parent.DiscoveryController)
local SoundController = require(script.Parent.SoundController)
local Character = require(script.Parent.Parent.Util.Character)
local ObjectiveBanner = require(script.Parent.Parent.UI.ObjectiveBanner)
local HUD = require(script.Parent.Parent.UI.HUD)
local Toasts = require(script.Parent.Parent.UI.Toasts)
local UIEffects = require(script.Parent.Parent.UI.UIEffects)
local HatchAnimation = require(script.Parent.Parent.UI.HatchAnimation)

local TutorialController = {}

local GUIDE_KEY = "Tutorial"
local SCAN_SETTING = "TutorialScanUsed"
local SCAN_TEXT = "Tap SCAN; follow the arrow to buried treasure!"
local STEPS = Config.TUTORIAL_STEPS

local completed = 0
local running = false
local dugFlag = false
local fullFlag = false
local soldFlag = false
local hatchedFlag = false

local built = false
local showingScanTip = false
local shortText: string? = nil -- "shop" step banner while the next shovel is unaffordable
local cameraTurnKey: string? = nil -- the selling moment the camera already turned for

-- Banner icon per step (atlas key, emoji fallback).
local STEP_ICONS: { [string]: string } = {
	AtSand = "sand",
	Dig = "Hand",
	BackpackFull = "Backpack",
	Sell = "Sell",
	BuyShovel = "Shop",
	NewLayer = "layer",
	HatchEgg = "Eggs",
}

-- Depth of the first layer the starter shovel cannot dig: reaching it proves the upgrade works.
local function firstLockedLayerDepth(): number
	local index = Config.GetMaxLayerIndexForPower(Config.Shovels[1].Power) + 1
	local layer = Config.Layers[index] or Config.Layers[#Config.Layers]
	return layer.DepthStart
end

local function count(t: { [string]: any }?): number
	local n = 0
	if t then
		for _ in t do
			n += 1
		end
	end
	return n
end

local function buildBar()
	built = true
end

local function bucketFull(): boolean
	return (State.Data.Sand or 0) >= State.GetCapacity()
end

-- The shovel the "shop" step is asking for: the cheapest coin shovel not owned yet.
local function nextShovel(): Types.ShovelDef?
	local owned = State.Data.OwnedShovels or {}
	local best: Types.ShovelDef? = nil
	for _, def in Config.Shovels do
		if def.Price > 0 and not owned[def.Id] and (best == nil or def.Price < (best :: Types.ShovelDef).Price) then
			best = def
		end
	end
	return best
end

-- A first bucket without passes can sell for a few coins less than the first upgrade (missed
-- excavations lower find value). Sending that player to a shop they cannot use stalls the
-- second minute, so until they can afford it the step sends them back to the sand instead.
-- Returns the banner text while short of coins, else nil.
function TutorialController.ShortOfShovelText(step: Types.TutorialStep): string?
	if step.Complete ~= "BuyShovel" then
		return nil
	end
	local def = nextShovel()
	local coins = State.Data.Coins or 0
	if not def or coins >= def.Price then
		return nil
	end
	local verb = if bucketFull() then "Bucket full! Sell it" else "Dig & sell more"
	return string.format("%s for the %s! (%d/%d)", verb, def.Name, math.floor(coins), def.Price)
end

local function currentStep(): Types.TutorialStep?
	return STEPS[completed + 1]
end

-- Nearest sand a few studs inside the dig zone (straight ahead from the boardwalk).
local function sandTarget(): Vector3?
	local root = Character.GetRoot()
	if not root then
		return nil
	end
	local point = State.NearestSand((root :: BasePart).Position, 8)
	return if point then point + Vector3.new(0, 1, 0) else nil
end

local function onSand(): boolean
	local root = Character.GetRoot()
	local cf = State.GetDigZone()
	return root ~= nil and cf ~= nil and State.InDigZone(root.Position, 0)
end

local function isSatisfied(step: Types.TutorialStep): boolean
	local data = State.Data
	local event = step.Complete
	if event == "AtSand" then
		-- Sand is reachable from the boardwalk. A confirmed dig already proves the
		-- player found it, even if their feet have not crossed the zone boundary.
		return onSand() or dugFlag or data.TotalSandDug > 0
	elseif event == "Dig" then
		return dugFlag or data.TotalSandDug > 0
	elseif event == "BackpackFull" then
		return fullFlag or data.Sand >= State.GetCapacity()
	elseif event == "Sell" then
		-- A saved fill-up step proves the bucket was full before this session. If it
		-- is already empty, the sale finished before tutorial progress was saved.
		return soldFlag or (completed >= 3 and data.Sand == 0)
	elseif event == "BuyShovel" then
		return count(data.OwnedShovels) > 1
	elseif event == "HatchEgg" then
		return hatchedFlag or count(data.Pets) > 0
	elseif event == "NewLayer" then
		return (data.MaxDepth or 0) >= firstLockedLayerDepth()
	end
	return false
end

local function updateGuide(step: Types.TutorialStep)
	if showingScanTip then
		GuideController.Clear(GUIDE_KEY)
		return
	end
	local target = step.Target
	if TutorialController.ShortOfShovelText(step) then
		-- not enough coins yet: back to digging (or selling a full bucket), not to the shop
		target = if bucketFull() then "SellZone" else "Sand"
	end
	if not target then
		GuideController.Clear(GUIDE_KEY)
		return
	end
	if target == "Sand" then
		local position = sandTarget()
		if position then
			GuideController.Set(GUIDE_KEY, position, 10, if step.Complete == "Dig" then "Hand" else "Arrow")
		end
		return
	end
	local root = Character.GetRoot()
	local part = GuideController.FindTagged(target :: string, if root then root.Position else nil)
	if part then
		GuideController.Set(GUIDE_KEY, part, 10, "Arrow")
	else
		GuideController.Clear(GUIDE_KEY)
	end
end

local function showStep()
	local step = currentStep()
	if not step or not built then
		return
	end
	local s = step :: Types.TutorialStep
	-- Keep the saved numeric steps intact. Introduce intentional treasure hunting in the
	-- existing objective once the first find has demonstrated the reward. Selling/upgrading
	-- still takes priority, and a scan is optional rather than a new progression gate.
	showingScanTip = (s.Complete == "BackpackFull" or s.Complete == "NewLayer")
		and count(State.Data.Index) > 0
		and State.GetSetting(SCAN_SETTING, false) ~= true
	shortText = TutorialController.ShortOfShovelText(s)
	local text = if showingScanTip then SCAN_TEXT else shortText or s.Text
	ObjectiveBanner.Show(text, STEP_ICONS[s.Complete] or "Star", {
		Step = (completed + 1) .. "/" .. #STEPS,
		Arrow = not showingScanTip and s.Target ~= nil,
	})
	HUD.SetBackpackHighlight(s.Complete == "BackpackFull")
	if s.Complete == "BuyShovel" and not shortText then
		HUD.Flash("Shop", 6)
	elseif s.Complete == "HatchEgg" then
		HUD.Flash("Eggs", 6)
	end
	updateGuide(s)
	-- A full bucket usually leaves the camera facing the sea with the stand behind: swing it
	-- round once per selling moment (never repeatedly, so it cannot fight the player).
	if s.Complete == "Sell" or (shortText ~= nil and bucketFull()) then
		local key = completed .. ":" .. tostring(shortText ~= nil) .. ":" .. tostring(bucketFull())
		if key ~= cameraTurnKey then
			cameraTurnKey = key
			local root = Character.GetRoot()
			local sell = GuideController.FindTagged("SellZone", if root then root.Position else nil)
			if sell then
				GuideController.TurnCameraToward(sell)
			end
		end
	end
end

local function finish()
	running = false
	GuideController.Clear(GUIDE_KEY)
	HUD.SetBackpackHighlight(false)
	ObjectiveBanner.Hide()
	Toasts.Show("Tutorial complete! Now dig to the CORE! 🌟", "Success", 5)
	UIEffects.Confetti(50)
end

local function advance()
	completed += 1
	State.SetSetting("Tutorial", completed)
	SoundController.Play("Purchase", 1.1)
	if completed >= #STEPS then
		finish()
	else
		showStep()
	end
end

local function loop()
	while running do
		local step = currentStep()
		if not step then
			finish()
			break
		end
		if isSatisfied(step :: Types.TutorialStep) then
			advance()
		else
			local wantsScanTip = (step.Complete == "BackpackFull" or step.Complete == "NewLayer")
				and count(State.Data.Index) > 0
				and State.GetSetting(SCAN_SETTING, false) ~= true
			if
				wantsScanTip ~= showingScanTip
				or TutorialController.ShortOfShovelText(step :: Types.TutorialStep) ~= shortText
			then
				showStep()
			end
			updateGuide(step :: Types.TutorialStep)
		end
		task.wait(0.4)
	end
end

function TutorialController.IsActive(): boolean
	return running
end

function TutorialController.Init()
	DiscoveryController.PingChanged:Connect(function(ping: Types.DetectorPing)
		-- A server response confirms the player used Scan; an empty signal still counts.
		if running and ping.Remaining > 0 and State.GetSetting(SCAN_SETTING, false) ~= true then
			State.SetSetting(SCAN_SETTING, true)
		end
	end)
	DigController.Dug:Connect(function(result: Types.DigResult)
		dugFlag = true
		if result.Capacity and result.Sand >= result.Capacity then
			fullFlag = true
		end
	end)
	DigController.Feedback:Connect(function(reason: string)
		if reason == "BackpackFull" then
			fullFlag = true
		end
	end)
	State.Changed("Sand"):Connect(function(new: any, old: any)
		if typeof(new) == "number" and typeof(old) == "number" and old > 0 and new == 0 and fullFlag then
			soldFlag = true
		end
	end)
	HatchAnimation.Hatched:Connect(function()
		hatchedFlag = true
	end)

	task.spawn(function()
		local data = State.WaitForData()
		local saved = data.Settings and data.Settings.Tutorial
		if typeof(saved) == "number" then
			completed = math.clamp(math.floor(saved), 0, #STEPS)
		else
			local veteran = data.Rebirths > 0 or count(data.OwnedShovels) > 1 or count(data.Pets) > 0
			if veteran then
				completed = #STEPS
				State.SetSetting("Tutorial", completed)
			end
		end
		-- skip (silently) steps this player has already done, e.g. a step added after they
		-- passed that point
		local resumed = completed
		while completed < #STEPS and isSatisfied(STEPS[completed + 1]) do
			completed += 1
		end
		if completed ~= resumed then
			State.SetSetting("Tutorial", completed)
		end
		if completed >= #STEPS then
			return
		end
		-- Steps past "fill up" assume the bucket was filled in a previous session.
		if completed >= 3 then
			fullFlag = true
		end
		buildBar()
		running = true
		showStep()
		loop()
	end)
end

return TutorialController
