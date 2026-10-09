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
	                         licensed tool). InputController's Q "Return to surface" passes Q to
	                         the Broadwave charge only then; otherwise Q keeps surfacing.

	No dependencies on other controllers, so DigController / InputController can require it.
]]
local Players = game:GetService("Players")

local InputArbiter = {}

InputArbiter.BROADWAVE_TOOL_ID = "tool_broadwave"

local reasons: { [string]: boolean? } = {}

function InputArbiter.Suppress(reason: string, on: boolean)
	reasons[reason] = if on then true else nil
end

function InputArbiter.DigBlocked(): boolean
	return next(reasons) ~= nil
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

return InputArbiter
