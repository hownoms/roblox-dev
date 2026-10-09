--!strict
-- Shared predicates only. No terrain edits, client position authority or inventory grants.
local Rules = {}
function Rules.Finite(n: any): boolean
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end
function Rules.InCorridor(frame: CFrame, position: Vector3, size: Vector3): boolean
	local localPoint = frame:PointToObjectSpace(position)
	return math.abs(localPoint.X) <= size.X / 2
		and math.abs(localPoint.Y) <= size.Y / 2
		and localPoint.Z <= 0
		and localPoint.Z >= -size.Z
end
function Rules.OrdinaryEquivalent(chargeSeconds: number, matchedCooldown: number, filledWork: number): number
	if chargeSeconds <= 0 or matchedCooldown <= 0 or filledWork <= 0 then
		return 0
	end
	return math.min(filledWork, math.max(1, chargeSeconds / matchedCooldown))
end
function Rules.Within(position: Vector3, target: Vector3, range: number): boolean
	return (position - target).Magnitude <= range
end
return Rules
