--!strict
--[[
	Weighted — pure weighted random selection (loot tables, eggs).
	`roll` is a number in [0, 1) supplied by the caller (Random:NextNumber()), which keeps this
	module deterministic and unit-testable. Entries with a non-positive or non-finite weight are
	skipped. Returns nil when no entry has weight.
]]

local Weighted = {}

local function validWeight(w: number): boolean
	return w == w and w > 0 and w ~= math.huge
end

function Weighted.Total<T>(entries: { T }, weightOf: (T) -> number): number
	local total = 0
	for _, entry in entries do
		local w = weightOf(entry)
		if validWeight(w) then
			total += w
		end
	end
	return total
end

function Weighted.Pick<T>(entries: { T }, weightOf: (T) -> number, roll: number): T?
	local total = Weighted.Total(entries, weightOf)
	if total <= 0 then
		return nil
	end
	local target = math.clamp(roll, 0, 1) * total
	local last: T? = nil
	for _, entry in entries do
		local w = weightOf(entry)
		if validWeight(w) then
			last = entry
			if target < w then
				return entry
			end
			target -= w
		end
	end
	-- Floating point slack (roll ~= 1): return the last valid entry.
	return last
end

-- Probability (0..1) of each entry, in input order (UI odds display).
function Weighted.Odds<T>(entries: { T }, weightOf: (T) -> number): { number }
	local total = Weighted.Total(entries, weightOf)
	local odds = {}
	for i, entry in entries do
		local w = weightOf(entry)
		odds[i] = if total > 0 and validWeight(w) then w / total else 0
	end
	return odds
end

return Weighted
