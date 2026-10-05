--!strict
--[[
	TableUtil — pure table helpers used by persistence.
]]

local TableUtil = {}

function TableUtil.DeepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value :: any do
		copy[TableUtil.DeepCopy(k)] = TableUtil.DeepCopy(v)
	end
	return (copy :: any) :: T
end

--[[
	Fill every key that exists in `template` but is missing (or has the wrong type) in `target`,
	recursing into nested tables. Keys that only exist in `target` are kept. Mutates and
	returns `target`. NaN / infinite numbers are treated as corrupt and replaced.
]]
function TableUtil.Reconcile(target: { [any]: any }, template: { [any]: any }): { [any]: any }
	for key, default in template do
		local current = target[key]
		if current == nil or type(current) ~= type(default) then
			target[key] = TableUtil.DeepCopy(default)
		elseif type(current) == "number" and (current ~= current or math.abs(current) == math.huge) then
			target[key] = default
		elseif type(default) == "table" then
			TableUtil.Reconcile(current, default)
		end
	end
	return target
end

function TableUtil.Count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

return TableUtil
