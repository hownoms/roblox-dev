--!strict
--[[
	Week — ISO-8601 week numbers (UTC) for weekly leaderboards. Weeks start on Monday; week 1 is
	the week holding the year's first Thursday, so 29 Dec .. 3 Jan can belong to either year.

		Week.Iso(unix): (isoYear, isoWeek)
		Week.Key(unix): "W2026_41"   (week zero-padded; used in OrderedDataStore names)
		Week.SecondsLeft(unix): seconds until the next Monday 00:00 UTC
]]

local Week = {}

local DAY = 86400

function Week.Iso(unix: number): (number, number)
	local days = math.floor(unix / DAY)
	local weekday = (days + 3) % 7 + 1 -- 1970-01-01 was a Thursday; Monday = 1 .. Sunday = 7
	local thursday = days - weekday + 4 -- the Thursday of this ISO week decides the year
	local t = os.date("!*t", thursday * DAY) :: any
	local year: number = t.year
	local yday: number = t.yday
	return year, math.floor((yday - 1) / 7) + 1
end

function Week.Key(unix: number): string
	local year, week = Week.Iso(unix)
	return string.format("W%d_%02d", year, week)
end

function Week.SecondsLeft(unix: number): number
	local days = math.floor(unix / DAY)
	local weekday = (days + 3) % 7 + 1
	return (days - weekday + 8) * DAY - unix
end

return Week
