--!strict
--[[
	InputArbiter — one place that decides which feature owns a shared input
	(docs/integration/production-wiring.md, "Input arbitration").

	  Suppress(reason, on)   named, independent reasons that pause ordinary digging (adventure
	                         hauling, arena dialogue, ...). Unlike DigController.Enabled's
	                         save/restore pattern (Placement, Ride), reasons never clobber each
	                         other: digging resumes only when every reason is released.
	  DigBlocked()           DigController refuses digs / hides its cursor while true.
	  BroadwaveEquipped()    the local character holds a Broadwave tool (the adventure loan or a
	                         licensed tool). Derived live from the character, so it can never get
	                         stuck; DigController pauses digging on it separately (with its own
	                         "put it away" hint) and hides the dig cursor.
	  SetChargeAvailable()   AdventureController reports whether the runtime's charge action
	                         (SpringVaultClient, Q / L1) is actually bound right now.
	  QToCharge()            InputController's Q "Return to surface" passes Q on only while a
	                         Broadwave is in hand AND the charge action exists; otherwise Q keeps
	                         surfacing (kill switch, runtime failed to start, no tool).

	Reasons in use (AdventureController owns and recomputes both; see production-wiring.md 4):
	  "AdventureArena"    standing in the Spring Vault arena (every Mara / Pip dialogue, prompt
	                      and objective is inside it).
	  "AdventureHauling"  the latest snapshot says this player is attached to the ball, and they
	                      are still in the arena (cleared on respawn, Leave, scene or remotes loss).

	No dependencies on other controllers, so DigController / InputController can require it.
]]
local Players = game:GetService("Players")

local InputArbiter = {}

InputArbiter.BROADWAVE_TOOL_ID = "tool_broadwave"

local reasons: { [string]: boolean? } = {}
local chargeAvailable = false

function InputArbiter.Suppress(reason: string, on: boolean)
	reasons[reason] = if on then true else nil
end

function InputArbiter.DigBlocked(): boolean
	return next(reasons) ~= nil
end

function InputArbiter.Has(reason: string): boolean
	return reasons[reason] == true
end

function InputArbiter.Reasons(): { string }
	local out = {}
	for reason in reasons do
		table.insert(out, reason)
	end
	table.sort(out)
	return out
end

function InputArbiter.IsBroadwaveTool(tool: Instance?): boolean
	return tool ~= nil
		and tool:IsA("Tool")
		and (
			tool:GetAttribute("ToolId") == InputArbiter.BROADWAVE_TOOL_ID
			or tool:GetAttribute("LicensedBroadwave") == true
			or tool:GetAttribute("AdventureLoan") == true
		)
end

-- The runtime's adventure loan (event/trial only) as opposed to a licensed tool (ordinary only).
function InputArbiter.IsBroadwaveLoan(tool: Instance?): boolean
	return InputArbiter.IsBroadwaveTool(tool) and (tool :: Instance):GetAttribute("AdventureLoan") == true
end

function InputArbiter.BroadwaveEquipped(): boolean
	local player = Players.LocalPlayer
	local character = player and player.Character
	return character ~= nil and InputArbiter.IsBroadwaveTool(character:FindFirstChildOfClass("Tool"))
end

function InputArbiter.SetChargeAvailable(on: boolean)
	chargeAvailable = on
end

function InputArbiter.ChargeAvailable(): boolean
	return chargeAvailable
end

-- Q belongs to the Broadwave charge only while a Broadwave is in hand and the charge is bound.
function InputArbiter.QToCharge(): boolean
	return chargeAvailable and InputArbiter.BroadwaveEquipped()
end

return InputArbiter
