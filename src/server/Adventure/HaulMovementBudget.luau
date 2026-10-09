--!strict
-- Replicated positions arrive less often than Heartbeat. Bank bounded validated
-- forward travel, then consume it smoothly; attachment alone never funds movement.
local Budget = {}
export type Banks = { [number]: number }
function Budget.Record(banks: Banks, userId: number, forward: number, magnitude: number, elapsed: number): boolean
	if
		forward ~= forward
		or magnitude ~= magnitude
		or elapsed ~= elapsed
		or forward <= 0.005
		or magnitude > math.max(4, math.min(elapsed, 0.35) * 24)
		or magnitude < forward
		or elapsed <= 0
	then
		return false
	end
	banks[userId] = math.min(4, (banks[userId] or 0) + math.min(forward, math.min(elapsed, 0.35) * 16))
	return true
end
function Budget.Consume(banks: Banks, userIds: { number }, limit: number): (number, Banks)
	local distance = 0
	for _, id in userIds do
		distance = math.max(distance, math.min(banks[id] or 0, limit))
	end
	local shares: Banks = {}
	for _, id in userIds do
		local used = math.min(banks[id] or 0, distance)
		if used > 0 then
			banks[id] = (banks[id] or 0) - used
			shares[id] = used
		end
	end
	return distance, shares
end
return Budget
