--!strict
-- Number/time formatting shared by UI, leaderboards and notifications.
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 1234 -> "1.23K", 15 -> "15", 1e15 -> "1Qa"
function Format.Abbreviate(n: number): string
	if n ~= n then
		return "0"
	end
	local sign = if n < 0 then "-" else ""
	n = math.abs(n)
	if n < 1000 then
		return sign .. tostring(math.floor(n))
	end
	local tier = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
	local scaled = n / 10 ^ (tier * 3)
	local text = if scaled >= 100
		then string.format("%d", math.floor(scaled))
		elseif scaled >= 10 then string.format("%.1f", math.floor(scaled * 10) / 10)
		else string.format("%.2f", math.floor(scaled * 100) / 100)
	text = (text:gsub("%.?0+$", ""))
	return sign .. text .. SUFFIXES[tier + 1]
end

-- v2.2 odds display: probability (0..1) -> "60%", "12.5%", "1.9%", "0.5%", "0.05%", "0.012%".
-- >= 10%: one decimal; >= 1%: two; below that two significant digits. Trailing zeros dropped.
function Format.Chance(probability: number): string
	if probability ~= probability or probability <= 0 then
		return "0%"
	end
	local pct = math.min(probability, 1) * 100
	local decimals = if pct >= 10 then 1 elseif pct >= 1 then 2 else math.ceil(-math.log10(pct)) + 1
	local text = string.format("%." .. math.clamp(decimals, 0, 8) .. "f", pct)
	if string.find(text, ".", 1, true) then
		text = (text:gsub("0+$", ""):gsub("%.$", ""))
	end
	return text .. "%"
end

-- 1234567 -> "1,234,567"
function Format.Commas(n: number): string
	local s = tostring(math.floor(math.abs(n)))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return (if n < 0 then "-" else "") .. out
end

-- 125 -> "2:05", 3725 -> "1:02:05"
function Format.Time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

function Format.Depth(studs: number): string
	return Format.Commas(math.floor(studs)) .. "m"
end

return Format
