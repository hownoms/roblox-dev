--!strict
--[[
	AdventureInviteController — the Spring Vault invitation's waypoint (docs/integration/
	adventure-entry.md, "Invitation").

	  * Server-gated: does nothing until the server sets the LocalPlayer attribute
	    SpringVaultInvited (AdventureEntry, only with AdventureFlags.SpringVault on, only for a
	    loaded save that passes AdventureEligibility.CanEnter after the tutorial). With the flag
	    off the attribute never appears: nothing is built, bound or polled. The attribute is a
	    presentation hint only; the hatch prompt re-checks eligibility on the server.
	  * Once per session: a low-priority GuideController beam + marker to the hatch (tag
	    SpringVaultHatch, resolved through the always-replicated world anchor). It never
	    outranks the tutorial or the sell / too-hard hints, and waits while the tutorial runs.
	  * Cleared on arrival at the hatch, on going below the surface, after GUIDE_SECONDS, or when
	    the server clears the attribute (kill switch).
]]
local Players = game:GetService("Players")

local GuideController = require(script.Parent.GuideController)
local TutorialController = require(script.Parent.TutorialController)
local Character = require(script.Parent.Parent.Util.Character)

local AdventureInviteController = {}

AdventureInviteController.ATTRIBUTE = "SpringVaultInvited"
AdventureInviteController.TAG = "SpringVaultHatch"
AdventureInviteController.GUIDE_KEY = "SpringVaultInvite"
AdventureInviteController.PRIORITY = 1 -- below the tutorial (10), TooHard (5) and SellHint (4)
AdventureInviteController.GUIDE_SECONDS = 120
AdventureInviteController.ARRIVE_DISTANCE = 12
AdventureInviteController.POLL = 0.5

local shown = false
local active = false

local function invited(): boolean
	return Players.LocalPlayer:GetAttribute(AdventureInviteController.ATTRIBUTE) == true
end

local function run()
	if shown or active then
		return
	end
	active = true
	-- Onboarding first: the server already waits for the saved tutorial count; this also covers
	-- a tutorial that is still on screen this session.
	while invited() and TutorialController.IsActive() do
		task.wait(1)
	end
	-- The hatch anchor normally exists long before the invitation; allow a few seconds anyway.
	local target: GuideController.Target? = nil
	for _ = 1, 10 do
		local root = Character.GetRoot()
		target = GuideController.FindTagged(AdventureInviteController.TAG, if root then root.Position else nil)
		if target or not invited() then
			break
		end
		task.wait(1)
	end
	if not invited() or not target then
		active = false
		return
	end
	shown = true
	GuideController.Set(
		AdventureInviteController.GUIDE_KEY,
		target,
		AdventureInviteController.PRIORITY,
		"Arrow",
		AdventureInviteController.GUIDE_SECONDS
	)
	local deadline = os.clock() + AdventureInviteController.GUIDE_SECONDS
	while invited() and os.clock() < deadline do
		local current = Character.GetRoot()
		local hatch = if current
			then GuideController.Resolve(target :: GuideController.Target, current.Position)
			else nil
		if current and hatch then
			local offset = current.Position - hatch
			-- At the hatch, or already down in the pocket (well below the surface deck).
			if offset.Magnitude <= AdventureInviteController.ARRIVE_DISTANCE or offset.Y < -20 then
				break
			end
		end
		task.wait(AdventureInviteController.POLL)
	end
	GuideController.Clear(AdventureInviteController.GUIDE_KEY)
	active = false
end

function AdventureInviteController.IsShown(): boolean
	return shown
end

function AdventureInviteController.IsGuiding(): boolean
	return active and shown
end

function AdventureInviteController.Init()
	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal(AdventureInviteController.ATTRIBUTE):Connect(function()
		if invited() then
			task.spawn(run)
		end
	end)
	if invited() then
		task.spawn(run)
	end
end

return AdventureInviteController
