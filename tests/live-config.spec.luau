--!nocheck
--[[
	LiveConfig (owner switches from Experience configs, docs/LIVE_CONFIG.md).
	  luau tests/live-config.spec.luau          pure parsing + real Main with configs set
	  luau tests/live-config.spec.luau -a fail  real Main while ConfigService throws (defaults)
	MOCK COVERAGE ONLY: headless mock ConfigService, in-memory DataStore.
]]

local Mock = require("./mock/Roblox")
local mode = ({ ... })[1] or "live"
Mock.Init(require("../build/test/generated"))
local passes, failures = 0, 0
local function check(cond, message)
	if cond then
		passes += 1
	else
		failures += 1
		print("FAIL: " .. message)
	end
	return cond
end

local byPath = Mock.ByPath
local function load(path)
	return Mock.Require(byPath[path])
end
local Config = load("ReplicatedStorage/Shared/Config")
for _, category in { Config.Monetization.GamePasses, Config.Monetization.Products, Config.Badges } do
	for _, item in category do
		item.Id = 0
	end
end
local Services = "ServerScriptService/Server/Services/"
local LiveConfig = load(Services .. "LiveConfig")

local function hasWarning(warnings, needle)
	for _, w in warnings do
		if string.find(w, needle, 1, true) then
			return true
		end
	end
	return false
end
local function parse(values, now)
	return LiveConfig.Parse(function(key)
		return values[key]
	end, now or 1_790_000_000)
end

-- "YYYY-MM-DD HH:MM" for a unix time (UTC), inverse of LiveConfig.ParseUtc
local function utc(t)
	local days = t // 86400
	local secs = t % 86400
	local z = days + 719468
	local era = z // 146097
	local doe = z - era * 146097
	local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
	local y = yoe + era * 400
	local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
	local mp = (5 * doy + 2) // 153
	local d = doy - (153 * mp + 2) // 5 + 1
	local m = if mp < 10 then mp + 3 else mp - 9
	if m <= 2 then
		y += 1
	end
	return string.format("%04d-%02d-%02d %02d:%02d", y, m, d, secs // 3600, (secs % 3600) // 60)
end

if mode == "live" then
	-- Dates ---------------------------------------------------------------------------------------
	check(LiveConfig.ParseUtc("2026-11-02") == 1793663999, "bare date = end of that day UTC")
	check(LiveConfig.ParseUtc("2026-11-02 14:30") == 1793629800, "date + time UTC")
	check(LiveConfig.ParseUtc("2026-11-02T14:30Z") == 1793629800, "ISO-style T/Z accepted")
	check(LiveConfig.ParseUtc("2024-02-29 00:00") == 1709164800, "leap day")
	check(LiveConfig.ParseUtc("2026-02-29") == nil, "29 Feb in a non-leap year rejected")
	check(LiveConfig.ParseUtc("2026-04-31") == nil, "31 Apr rejected")
	check(LiveConfig.ParseUtc("2026-13-01") == nil, "month 13 rejected")
	check(LiveConfig.ParseUtc("2026-11-02 24:00") == nil, "hour 24 rejected")
	check(LiveConfig.ParseUtc("next friday") == nil, "free text rejected")
	check(utc(1793629800) == "2026-11-02 14:30", "test helper inverts ParseUtc")

	-- Defaults --------------------------------------------------------------------------------------
	local snap, warnings = parse({})
	check(#warnings == 0, "nothing set: no warnings")
	check(next(snap.CodesOn) == nil and next(snap.ExtraCodes) == nil and next(snap.EventsOff) == nil, "nothing set: empty")
	check(snap.BonusEvent == nil and snap.Announcement == nil and next(snap.Paused) == nil, "nothing set: no bonus/pause/banner")

	-- Codes -----------------------------------------------------------------------------------------
	snap, warnings = parse({ codes_on = " 1klikes , NOPE", codes_off = "release" })
	check(snap.CodesOn["1KLIKES"] == true, "codes_on: shipped code, case/space-insensitive")
	check(snap.CodesOff.RELEASE == true, "codes_off: shipped code")
	check(hasWarning(warnings, "codes_on: unknown \"NOPE\""), "codes_on: unknown code warned")
	snap, warnings = parse({ codes_on = "SANDY", codes_off = "SANDY" })
	check(snap.CodesOn.SANDY == nil and snap.CodesOff.SANDY == true, "a code in both lists stays off")
	check(hasWarning(warnings, "also in codes_off"), "both lists warned")
	snap, warnings = parse({ codes_on = 5 })
	check(hasWarning(warnings, "codes_on: expected text"), "codes_on: wrong type warned")

	snap, warnings = parse({
		extra_codes = {
			halloween = { reward = "luck_boost", expires = "2026-11-02" },
			BIGWIN = { reward = "a_million_coins" },
			SANDY = { reward = "coins" },
			["no!"] = { reward = "coins" },
			LATE = { reward = "coins", expires = "soon" },
		},
	})
	local h = snap.ExtraCodes.HALLOWEEN
	check(h ~= nil and h.Reward.Boost == "LuckBoost" and h.Expires == 1793663999, "extra code: menu reward + expiry")
	check(h ~= nil and h.Reward ~= LiveConfig.REWARD_MENU.luck_boost, "extra code: reward is a copy of the menu row")
	check(snap.ExtraCodes.BIGWIN == nil and hasWarning(warnings, "BIGWIN needs a reward"), "extra code: off-menu reward rejected")
	check(snap.ExtraCodes.SANDY == nil and hasWarning(warnings, "SANDY is a shipped code"), "extra code: can't shadow a shipped code")
	check(hasWarning(warnings, "\"no!\" must be 2-20"), "extra code: bad name rejected")
	check(snap.ExtraCodes.LATE == nil and hasWarning(warnings, "LATE has a bad expires"), "extra code: bad date rejected")
	-- (a JSON *string* goes through HttpService:JSONDecode, which the mock doesn't implement)
	snap, warnings = parse({ extra_codes = "{not json" })
	check(hasWarning(warnings, "extra_codes: expected a JSON object"), "extra_codes: bad JSON warned")
	local many = {}
	for i = 1, LiveConfig.MAX_EXTRA_CODES + 3 do
		many[string.format("CODE%02d", i)] = { reward = "coins" }
	end
	snap, warnings = parse({ extra_codes = many })
	local n = 0
	for _ in snap.ExtraCodes do
		n += 1
	end
	check(n == LiveConfig.MAX_EXTRA_CODES and hasWarning(warnings, "more than"), "extra codes capped")

	-- Events ----------------------------------------------------------------------------------------
	local now = 1_790_000_000
	snap, warnings = parse({ events_off = "HighTide,Typhoon" }, now)
	check(snap.EventsOff.HighTide == true and hasWarning(warnings, "unknown \"Typhoon\""), "events_off")
	snap = parse({ bonus_event = "GoldenHour", bonus_event_ends = utc(now + 3600) }, now)
	check(snap.BonusEvent == "GoldenHour" and snap.BonusEventEnds == now + 3600 - (now % 60), "bonus event")
	snap, warnings = parse({ bonus_event = "GoldenHour", bonus_event_ends = utc(now + 8 * 86400) }, now)
	check(snap.BonusEvent == nil and hasWarning(warnings, "days away"), "bonus event: too far ahead rejected")
	snap, warnings = parse({ bonus_event = "GoldenHour", bonus_event_ends = utc(now - 3600) }, now)
	check(snap.BonusEvent == nil and #warnings == 0, "bonus event: already over = quietly nothing")
	snap, warnings = parse({ bonus_event = "Party", bonus_event_ends = utc(now + 60) }, now)
	check(snap.BonusEvent == nil and hasWarning(warnings, "unknown event"), "bonus event: unknown id")
	snap, warnings = parse({ bonus_event = "HighTide", bonus_event_ends = utc(now + 600), events_off = "HighTide" }, now)
	check(snap.BonusEvent == nil and hasWarning(warnings, "is in events_off"), "bonus event: off wins")

	-- Pauses and announcement -----------------------------------------------------------------------
	snap, warnings = parse({ pause_hatching = true, pause_autodig = "yes", pause_leaderboards = false })
	check(snap.Paused.Hatching == true and snap.Paused.AutoDig == nil and snap.Paused.Leaderboards == nil, "pauses")
	check(hasWarning(warnings, "pause_autodig: expected true or false"), "pause: wrong type warned")
	snap = parse({ announcement = "  Double luck this weekend!  " })
	check(snap.Announcement == "Double luck this weekend!", "announcement trimmed")
	snap, warnings = parse({ announcement = string.rep("x", LiveConfig.MAX_ANNOUNCEMENT + 1) })
	check(snap.Announcement == nil and hasWarning(warnings, "longer than"), "announcement too long rejected")
	snap, warnings = LiveConfig.Parse(function(key)
		if key == "announcement" then
			error("boom")
		end
		return nil
	end, now)
	check(hasWarning(warnings, "announcement: could not be read"), "a throwing read is a warning, not an error")

	Mock.ConfigValues = {
		codes_on = "1KLIKES",
		extra_codes = { TESTCODE = { reward = "coins" } },
		pause_hatching = true,
		events_off = "HighTide",
		announcement = "Welcome, testers!",
	}
else
	Mock.ConfigFail = true
end

-- Real Main -------------------------------------------------------------------------------------------
Mock.RunScript(byPath["ServerScriptService/Server/Main"])
Mock.Advance(1)
check(#Mock.Errors == 0, "boot: no errors")
local workspace = Mock.Service("Workspace")
for _ = 1, 40 do
	if workspace:GetAttribute("WorldReady") then
		break
	end
	Mock.Advance(0.5)
end
local Data = load(Services .. "DataService")
local Events = load(Services .. "EventService")

local function notifies(player, since)
	local list = {}
	for i = (since or 0) + 1, #Mock.Remote.ToClient do
		local e = Mock.Remote.ToClient[i]
		if e.Player == player and e.Name == "Notify" then
			table.insert(list, tostring(e.Args[1]) .. ": " .. tostring(e.Args[2]))
		end
	end
	return list
end
local function anyNotify(player, since, needle)
	for _, line in notifies(player, since) do
		if string.find(line, needle, 1, true) then
			return true
		end
	end
	return false
end

local player = Mock.AddPlayer(2001, "LiveTester")
Mock.Advance(2)
local data = Data.Get(player)
check(data ~= nil, "player data loaded")
local function redeem(code)
	Mock.FireServer("RedeemCode", player, code)
	Mock.Advance(2) -- RedeemCode is rate-limited to 3 per 5 s
	return data.RedeemedCodes[string.upper(code)] == true
end

if mode == "live" then
	local mark = #Mock.Remote.ToClient
	Mock.Advance(LiveConfig.ANNOUNCE_DELAY + 1)
	check(anyNotify(player, mark, "Event: Welcome, testers!"), "announcement shown after joining")

	check(redeem("1klikes"), "codes_on turns a shipped off code on")
	check(redeem("testcode"), "extra code redeems")
	local coinsBefore = data.Coins
	redeem("TESTCODE")
	check(data.Coins == coinsBefore, "extra code only once")
	check(redeem("SANDY"), "untouched shipped code still works")
	check(not redeem("DIGDEEP"), "shipped off code stays off")

	-- live change: turn RELEASE off, add a new code, stop the pause, change the banner
	mark = #Mock.Remote.ToClient
	local egg = Config.Eggs[1]
	data.Coins = math.max(data.Coins, 1e6)
	Mock.FireServer("HatchEgg", player, egg.Id, 1)
	Mock.Advance(0.5)
	check(anyNotify(player, mark, "Egg hatching is paused"), "pause_hatching refuses with a message")
	local pets = 0
	for _ in data.Pets do
		pets += 1
	end
	check(pets == 0, "paused: no pet granted")

	mark = #Mock.Remote.ToClient
	Mock.SetConfig({
		codes_on = "1KLIKES",
		codes_off = "RELEASE",
		extra_codes = { TESTCODE = { reward = "coins" }, NEWCODE = { reward = "sand_boost" } },
		events_off = "HighTide",
		announcement = "Bonus weekend!",
	})
	Mock.Advance(1)
	check(anyNotify(player, mark, "Event: Bonus weekend!"), "changed announcement goes out at once")
	check(not redeem("RELEASE"), "codes_off turns a shipped code off live")
	check(redeem("NEWCODE"), "a code added live redeems")
	Mock.FireServer("HatchEgg", player, egg.Id, 1)
	Mock.Advance(0.5)
	pets = 0
	for _ in data.Pets do
		pets += 1
	end
	check(pets == 1, "pause lifted live: hatching works again")

	-- events_off hides even an early start; a bonus event runs and ends with the config
	check(workspace:GetAttribute("EventsOff") == "HighTide", "EventsOff attribute for the HUD")
	Events.StartEarly("HighTide", 120)
	Mock.Advance(1.5)
	check(not Events.IsActive("HighTide"), "events_off: an early start doesn't run either")
	local now = 1_790_000_000 + Mock.Now() - 1000 -- the mock's os.time() (EPOCH at clock 1000)
	local scheduledGolden = Config.GetSecondsUntilEvent("GoldenHour", now) == 0
	Mock.SetConfig({ events_off = "HighTide", bonus_event = "GoldenHour", bonus_event_ends = utc(now + 7200) })
	Mock.Advance(1.5)
	check(Events.IsActive("GoldenHour"), "bonus event runs on this server")
	check(type(workspace:GetAttribute("EventEnds_GoldenHour")) == "number", "bonus event end time for the HUD")
	Mock.SetConfig({ events_off = "HighTide" })
	Mock.Advance(1.5)
	if not scheduledGolden then
		check(not Events.IsActive("GoldenHour"), "removing the bonus ends it")
	end
	check(workspace:GetAttribute("EventEnds_GoldenHour") == nil, "bonus end time cleared")
	Mock.SetConfig({})
	Mock.Advance(1.5)
	check(workspace:GetAttribute("EventsOff") == "", "events back on")
	check(LiveConfig.FindCode("RELEASE") ~= nil and LiveConfig.FindCode("1KLIKES") == nil, "empty config = as published")
else
	check(redeem("SANDY"), "ConfigService down: shipped codes work")
	check(not redeem("1KLIKES"), "ConfigService down: off codes stay off")
	local egg = Config.Eggs[1]
	data.Coins = math.max(data.Coins, 1e6)
	Mock.FireServer("HatchEgg", player, egg.Id, 1)
	Mock.Advance(0.5)
	local pets = 0
	for _ in data.Pets do
		pets += 1
	end
	check(pets == 1, "ConfigService down: hatching works")
end

check(#Mock.Errors == 0, "no uncaught errors")
for _, e in Mock.Errors do
	print("  error: " .. tostring(e))
end
print(string.format("LIVE CONFIG (%s): %d passed, %d failed", mode, passes, failures))
if failures > 0 then
	error("LIVE CONFIG SPEC FAILED")
end
