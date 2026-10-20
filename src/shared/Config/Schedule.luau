--!strict
--[[
	Schedule — pure UTC date math for timed events and the content calendar. No Roblox APIs and
	no os.date, so the server, the client and the headless tests all get the same answer from
	the same unix time (every server agrees without messaging).

	An event schedule (Types.EventDef) combines optional parts, ALL of which must hold:
	  Starts / Ends           unix window, Starts inclusive, Ends exclusive
	  Weekend                 Saturday 00:00 .. Monday 00:00 UTC
	  WeekCycle / WeekSlot    only weeks where WeekIndex(t) % WeekCycle == WeekSlot
	  Interval/Duration/Offset periodic: (t + Offset) % Interval < Duration
	An event with none of them is always on.

	API:
		Schedule.Utc(y, m, d, h?, min?): number        unix time of a UTC date
		Schedule.Day(t): number                        whole days since 1970-01-01 (UTC)
		Schedule.Weekday(t): number                    1 = Monday .. 7 = Sunday
		Schedule.WeekIndex(t): number                  weeks since Monday 1969-12-29 (Monday-based)
		Schedule.NextMonday(t) / NextSaturday(t)       next Monday / Saturday 00:00 strictly after t
		Schedule.IsActive(def, t): boolean
		Schedule.SecondsLeft(def, t): number           while active: seconds until it stops (math.huge = never)
		Schedule.SecondsUntil(def, t): number          0 if active, else seconds until it next starts (math.huge = never)
]]

local Schedule = {}

local DAY = 86400
local WEEK = 7 * DAY

export type Def = {
	IntervalSeconds: number?,
	DurationSeconds: number?,
	OffsetSeconds: number?,
	Starts: number?,
	Ends: number?,
	Weekend: boolean?,
	WeekCycle: number?,
	WeekSlot: number?,
}

-- Days since 1970-01-01 for a proleptic Gregorian date (Howard Hinnant's days_from_civil).
local function daysFromCivil(y: number, m: number, d: number): number
	y = if m <= 2 then y - 1 else y
	local era = (if y >= 0 then y else y - 399) // 400
	local yoe = y - era * 400
	local mp = (m + 9) % 12
	local doy = (153 * mp + 2) // 5 + d - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return era * 146097 + doe - 719468
end

function Schedule.Utc(y: number, m: number, d: number, h: number?, min: number?): number
	return daysFromCivil(y, m, d) * DAY + (h or 0) * 3600 + (min or 0) * 60
end

function Schedule.Day(t: number): number
	return t // DAY
end

function Schedule.Weekday(t: number): number
	return (t // DAY + 3) % 7 + 1 -- 1970-01-01 was a Thursday
end

function Schedule.WeekIndex(t: number): number
	return (t // DAY + 3) // 7
end

local function mondayOf(t: number): number
	return Schedule.WeekIndex(t) * WEEK - 3 * DAY
end

function Schedule.NextMonday(t: number): number
	return mondayOf(t) + WEEK
end

function Schedule.NextSaturday(t: number): number
	local saturday = mondayOf(t) + 5 * DAY
	return if t < saturday then saturday else saturday + WEEK
end

function Schedule.IsWeekend(t: number): boolean
	return Schedule.Weekday(t) >= 6
end

local function phaseOf(def: Def, t: number): number?
	local interval = def.IntervalSeconds
	if interval == nil or interval <= 0 then
		return nil
	end
	return (t + (def.OffsetSeconds or 0)) % interval
end

local function inRotation(def: Def, t: number): boolean
	local cycle = def.WeekCycle
	if cycle == nil or cycle <= 0 then
		return true
	end
	return Schedule.WeekIndex(t) % cycle == (def.WeekSlot or 0) % cycle
end

function Schedule.IsActive(def: Def, t: number): boolean
	if def.Starts and t < def.Starts then
		return false
	end
	if def.Ends and t >= def.Ends then
		return false
	end
	if def.Weekend and not Schedule.IsWeekend(t) then
		return false
	end
	if not inRotation(def, t) then
		return false
	end
	local phase = phaseOf(def, t)
	if phase and phase >= (def.DurationSeconds or 0) then
		return false
	end
	return true
end

function Schedule.SecondsLeft(def: Def, t: number): number
	if not Schedule.IsActive(def, t) then
		return 0
	end
	local left = math.huge
	if def.Ends then
		left = math.min(left, def.Ends - t)
	end
	if def.Weekend or (def.WeekCycle and def.WeekCycle > 1) then
		left = math.min(left, Schedule.NextMonday(t) - t)
	end
	local phase = phaseOf(def, t)
	if phase then
		left = math.min(left, (def.DurationSeconds or 0) - phase)
	end
	return left
end

-- Walks forward constraint by constraint: each failing part moves the candidate to the earliest
-- moment it could hold again, until every part holds (or the window has closed for good).
function Schedule.SecondsUntil(def: Def, t: number): number
	local x = t
	for _ = 1, 64 do
		if def.Ends and x >= def.Ends then
			return math.huge
		end
		if def.Starts and x < def.Starts then
			x = def.Starts
		elseif def.Weekend and not Schedule.IsWeekend(x) then
			x = Schedule.NextSaturday(x)
		elseif not inRotation(def, x) then
			x = Schedule.NextMonday(x)
		else
			local phase = phaseOf(def, x)
			if phase and phase >= (def.DurationSeconds or 0) then
				x += (def.IntervalSeconds :: number) - phase
			else
				return x - t
			end
		end
	end
	return math.huge
end

return Schedule
