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
	The checks are state-based (polled), so the tutorial resumes correctly after rejoining.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Types = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Types"))
local State = require(script.Parent.State)
local GuideController = require(script.Parent.GuideController)
local DigController = require(script.Parent.DigController)
local SoundController = require(script.Parent.SoundController)
local Character = require(script.Parent.Parent.Util.Character)
local ObjectiveBanner = require(script.Parent.Parent.UI.ObjectiveBanner)
local HUD = require(script.Parent.Parent.UI.HUD)
local Toasts = require(script.Parent.Parent.UI.Toasts)
local UIEffects = require(script.Parent.Parent.UI.UIEffects)
local HatchAnimation = require(script.Parent.Parent.UI.HatchAnimation)

local TutorialController = {}

local GUIDE_KEY = "Tutorial"
local STEPS = Config.TUTORIAL_STEPS

local completed = 0
local running = false
local dugFlag = false
local fullFlag = false
local soldFlag = false
local hatchedFlag = false

local built = false

-- Banner icon per step (atlas key, emoji fallback).
local STEP_ICONS: { [string]: string } = {
	AtSand = "sand",
	Dig = "Hand",
	BackpackFull = "Backpack",
	Sell = "Sell",
	BuyShovel = "Shop",
	HatchEgg = "Eggs",
}

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
		return soldFlag
	elseif event == "BuyShovel" then
		return count(data.OwnedShovels) > 1
	elseif event == "HatchEgg" then
		return hatchedFlag or count(data.Pets) > 0
	end
	return false
end

local function updateGuide(step: Types.TutorialStep)
	local target = step.Target
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
	ObjectiveBanner.Show(s.Text, STEP_ICONS[s.Complete] or "Star", {
		Step = (completed + 1) .. "/" .. #STEPS,
		Arrow = s.Target ~= nil,
	})
	HUD.SetBackpackHighlight(s.Complete == "BackpackFull")
	if s.Complete == "BuyShovel" then
		HUD.Flash("Shop", 6)
	elseif s.Complete == "HatchEgg" then
		HUD.Flash("Eggs", 6)
	end
	updateGuide(s)
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
			updateGuide(step :: Types.TutorialStep)
		end
		task.wait(0.4)
	end
end

function TutorialController.IsActive(): boolean
	return running
end

function TutorialController.Init()
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
