--!nocheck
--[[
	Content calendar (Config/Calendar.luau, docs/CALENDAR.md).
	  luau tests/calendar.spec.luau           pure: walks the calendar across dates (boundaries,
	                                          overlaps, weekend rotation, monthly mythic, codes)
	  luau tests/calendar.spec.luau -a main   real Main booted on calendar dates (mock clock):
	                                          egg stand, decor swap, advent, fireworks, live overrides
	MOCK COVERAGE ONLY: headless mock, in-memory DataStore.
]]

local Mock = require("./mock/Roblox")
local mode = ({ ... })[1] or "pure"
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
local Schedule = Config.Schedule
local Enum = Mock.Enum
local Calendar = Config.Calendar
local utc = Schedule.Utc
local DAY = 86400
local Services = "ServerScriptService/Server/Services/"

local function activeSet(t, off)
	local set = {}
	for _, event in Config.GetActiveEvents(t) do
		if not (off and Config.IsEventOff(event, off)) then
			set[event.Id] = true
		end
	end
	return set
end
local function isActiveAt(t, off)
	local set = activeSet(t, off)
	return function(id)
		return set[id] == true
	end
end
local function fmt(t)
	local d = t // DAY
	local z = d + 719468
	local era = z // 146097
	local doe = z - era * 146097
	local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
	local y = yoe + era * 400
	local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
	local mp = (5 * doy + 2) // 153
	local dd = doy - (153 * mp + 2) // 5 + 1
	local m = if mp < 10 then mp + 3 else mp - 9
	if m <= 2 then
		y += 1
	end
	local s = t % DAY
	return string.format("%04d-%02d-%02d %02d:%02d", y, m, dd, s // 3600, (s % 3600) // 60)
end

if mode == "pure" then
	-- Date math ----------------------------------------------------------------------------------
	check(utc(2026, 11, 2) == 1793577600, "Utc: 2 Nov 2026 00:00 (matches LiveConfig.ParseUtc)")
	check(utc(2024, 2, 29, 12, 30) == 1709209800, "Utc: leap day with time")
	check(fmt(utc(2027, 3, 1)) == "2027-03-01 00:00", "Utc / helper round trip")
	check(Schedule.Weekday(utc(2026, 10, 19)) == 1, "19 Oct 2026 is a Monday")
	check(Schedule.Weekday(utc(2026, 10, 24)) == 6 and Schedule.Weekday(utc(2026, 10, 25, 23, 59)) == 7, "Sat / Sun")
	check(Schedule.NextSaturday(utc(2026, 10, 21)) == utc(2026, 10, 24), "next Saturday from a Wednesday")
	check(Schedule.NextSaturday(utc(2026, 10, 24, 5)) == utc(2026, 10, 31), "next Saturday from a Saturday")
	check(Schedule.NextMonday(utc(2026, 10, 25, 23, 59)) == utc(2026, 10, 26), "next Monday from Sunday night")
	check(
		Schedule.WeekIndex(utc(2026, 10, 24)) == Schedule.WeekIndex(utc(2026, 10, 25, 23, 59, 0))
			and Schedule.WeekIndex(utc(2026, 10, 26)) == Schedule.WeekIndex(utc(2026, 10, 24)) + 1,
		"a weekend belongs to one week; Monday starts the next"
	)

	-- The plan's drop table, written out independently of Config: id -> first day .. last day
	local PLAN = {
		HarvestDig = { utc(2026, 11, 26), utc(2026, 12, 6) },
		WinterBeach = { utc(2026, 12, 12), utc(2027, 1, 4) },
		NewYear = { utc(2026, 12, 31), utc(2027, 1, 3) },
		LunarLove = { utc(2027, 2, 6), utc(2027, 2, 20) },
		LuckyDig = { utc(2027, 3, 12), utc(2027, 3, 22) },
		SpringHatch = { utc(2027, 3, 26), utc(2027, 4, 12) },
	}
	local planCount = 0
	for _ in PLAN do
		planCount += 1
	end
	check(#Calendar.Drops == planCount, "one drop per row of the plan")

	-- Boundaries: first second on, last second of the last day on, one second either side off
	for id, range in PLAN do
		local first, lastDay = range[1], range[2]
		local endsAt = lastDay + DAY
		check(not activeSet(first - 1)[id], id .. ": off one second before")
		check(activeSet(first)[id], id .. ": on at 00:00 UTC of the first day")
		check(activeSet(endsAt - 1)[id], id .. ": on at 23:59:59 of the last day")
		check(not activeSet(endsAt)[id], id .. ": off at 00:00 the day after")
		check(Config.GetSecondsUntilEvent(id, first - 3600) == 3600, id .. ": starts in an hour")
		check(Config.GetEventSecondsLeft(id, first) == endsAt - first, id .. ": countdown = whole window")
		check(Config.GetSecondsUntilEvent(id, endsAt) == math.huge, id .. ": never again after it ends")
	end

	-- Walk every day (noon and 23:30 UTC) from now to May: active drops == the plan table exactly
	local walkOk = true
	local t = utc(2026, 10, 20, 12)
	while t < utc(2027, 5, 1) do
		for _, at in { t, t + 11 * 3600 + 1800 } do
			local set = activeSet(at)
			for id, range in PLAN do
				local want = at >= range[1] and at < range[2] + DAY
				if (set[id] == true) ~= want then
					walkOk = false
					print("  walk mismatch " .. id .. " at " .. fmt(at))
				end
			end
		end
		t += DAY
	end
	check(walkOk, "day-by-day walk Oct 2026 .. Apr 2027 matches the plan table")

	-- Overlap: New Year runs inside Winter Beach
	local ny = activeSet(utc(2027, 1, 1, 12))
	check(ny.WinterBeach and ny.NewYear, "1 Jan: Winter Beach and New Year together")
	local afterNy = activeSet(utc(2027, 1, 4, 0))
	check(afterNy.WinterBeach and not afterNy.NewYear, "4 Jan: New Year over, Winter Beach still on")
	local luck = 1
	for _, event in Config.GetActiveEvents(utc(2027, 1, 1, 12)) do
		if event.Kind == "Luck" then
			luck *= event.Multiplier
		end
	end
	check(luck >= 2, "New Year: 2x Luck")

	-- Fireworks: 00:00 .. 00:15 UTC each night of New Year only
	check(activeSet(utc(2027, 1, 1, 0, 0)).Fireworks, "fireworks at midnight on 1 Jan")
	check(activeSet(utc(2027, 1, 1, 0, 14) + 59).Fireworks, "fireworks still at 00:14:59")
	check(not activeSet(utc(2027, 1, 1, 0, 15)).Fireworks, "fireworks over at 00:15")
	check(not activeSet(utc(2026, 12, 30, 0, 5)).Fireworks, "no fireworks before New Year")
	check(not activeSet(utc(2027, 1, 4, 0, 5)).Fireworks, "no fireworks after New Year")
	check(Config.GetSecondsUntilEvent("Fireworks", utc(2026, 12, 31, 23, 50)) == 600, "teaser: fireworks in 10 min")

	-- Frozen Tide: :05-:09 and :35-:39 inside Winter Beach, never on top of High Tide
	check(activeSet(utc(2026, 12, 20, 15, 5)).FrozenTide, "Frozen Tide at :05")
	check(not activeSet(utc(2026, 12, 20, 15, 9)).FrozenTide, "Frozen Tide over at :09")
	check(activeSet(utc(2026, 12, 20, 15, 35)).FrozenTide, "Frozen Tide at :35")
	check(not activeSet(utc(2026, 11, 20, 15, 5)).FrozenTide, "no Frozen Tide outside Winter Beach")
	local clash = false
	for m = 0, 24 * 60 - 1 do
		local s = activeSet(utc(2026, 12, 20) + m * 60)
		clash = clash or (s.FrozenTide and s.HighTide)
	end
	check(not clash, "Frozen Tide never overlaps High Tide")

	-- Harvest: 1.5x sand weekends only, inside the drop
	check(activeSet(utc(2026, 11, 28, 10)).HarvestWeekend, "Harvest Weekend on Saturday 28 Nov")
	check(not activeSet(utc(2026, 11, 27, 10)).HarvestWeekend, "not on Friday 27 Nov")
	check(activeSet(utc(2026, 12, 6, 23)).HarvestWeekend, "on the last Sunday (6 Dec)")
	check(not activeSet(utc(2026, 11, 21, 10)).HarvestWeekend, "not on a weekend before the drop")

	-- Weekend Dig Fest: exactly one fest every weekend, none on weekdays, rotating through all 4
	local FESTS = { "FestSand", "FestLuck", "FestCoins", "FestHatch" }
	local function festAt(at)
		local found = {}
		local s = activeSet(at)
		for _, id in FESTS do
			if s[id] then
				table.insert(found, id)
			end
		end
		return found
	end
	local rotationOk, weekdayOk = true, true
	local seen = {}
	local block = {}
	for w = 0, 15 do
		local sat = utc(2026, 10, 24) + w * 7 * DAY
		local a, b, c = festAt(sat), festAt(sat + DAY + 23 * 3600 + 3599), festAt(sat + 2 * DAY)
		if #a ~= 1 or #b ~= 1 or a[1] ~= b[1] or #c ~= 0 then
			rotationOk = false
			print("  fest mismatch weekend of " .. fmt(sat))
		end
		for d = 1, 5 do
			if #festAt(sat - d * DAY + 43200) ~= 0 then
				weekdayOk = false
			end
		end
		if a[1] then
			seen[a[1]] = true
			block[w % 4 + 1] = a[1]
			local slot = Schedule.WeekIndex(sat) % 4
			if a[1] ~= FESTS[slot + 1] then
				rotationOk = false
			end
			if w % 4 == 3 then
				local distinct = {}
				for _, id in block do
					distinct[id] = true
				end
				local n = 0
				for _ in distinct do
					n += 1
				end
				rotationOk = rotationOk and n == 4
			end
		end
	end
	check(rotationOk, "one fest per weekend (Sat 00:00 .. Mon 00:00), picked by week number")
	check(weekdayOk, "no fest on weekdays")
	check(seen.FestSand and seen.FestLuck and seen.FestCoins and seen.FestHatch, "all four fests come round")
	local friday = utc(2026, 10, 23, 23)
	local nextFest = festAt(utc(2026, 10, 24))[1]
	check(Config.GetSecondsUntilEvent(nextFest, friday) == 3600, "fest teaser: Friday 23:00 -> starts in an hour")
	check(Config.GetEventSecondsLeft(nextFest, utc(2026, 10, 24)) == 2 * DAY, "fest runs 48 h")
	check(Config.GetSecondsUntilEvent(nextFest, utc(2026, 10, 26)) == 4 * 7 * DAY - 2 * DAY, "same fest again in 4 weeks")
	local hatchFest = activeSet(utc(2026, 10, 24))
	check(hatchFest[nextFest], "the fest is in GetActiveEvents")

	-- SecondsUntil agrees with a brute-force minute scan
	local scanOk = true
	for _, sample in {
		{ "FestCoins", utc(2026, 10, 21, 9, 13) },
		{ "FrozenTide", utc(2026, 12, 11, 23, 0) },
		{ "HarvestWeekend", utc(2026, 11, 20, 4, 0) },
		{ "Fireworks", utc(2026, 12, 29, 18, 0) },
		{ "HighTide", utc(2026, 12, 1, 0, 4) },
	} do
		local id, from = sample[1], sample[2]
		local def = Config.GetEvent(id)
		local brute = math.huge
		for m = 0, 6 * 7 * 24 * 60 do
			if Schedule.IsActive(def, from + m * 60) then
				brute = m * 60
				break
			end
		end
		if Config.GetSecondsUntilEvent(id, from) ~= brute then
			scanOk = false
			print("  until mismatch " .. id .. ": " .. Config.GetSecondsUntilEvent(id, from) .. " vs " .. brute)
		end
	end
	check(scanOk, "SecondsUntil = brute-force scan")

	-- Monthly mythic -------------------------------------------------------------------------------
	local mm = Calendar.MonthlyMythic
	check(Config.GetMonthlyMythic(mm.Epoch - 1) == nil, "no mythic before the epoch")
	local first, rotates = Config.GetMonthlyMythic(mm.Epoch)
	check(first == mm.Treasures[1] and rotates == mm.Epoch + 28 * DAY, "first mythic at the epoch, 28 days")
	check(Config.GetMonthlyMythic(mm.Epoch + 28 * DAY - 1) == mm.Treasures[1], "same mythic until the last second")
	check(Config.GetMonthlyMythic(mm.Epoch + 28 * DAY) == mm.Treasures[2], "a new mythic every 4 weeks")
	check(Config.GetMonthlyMythic(mm.Epoch + 8 * 28 * DAY) == mm.Treasures[1], "wraps after the list")
	local distinct, count = {}, 0
	local at = utc(2026, 11, 2)
	while at < utc(2027, 5, 2) do
		local id = Config.GetMonthlyMythic(at)
		if id and not distinct[id] then
			distinct[id] = true
			count += 1
		end
		at += DAY
	end
	check(count == 7, "Nov .. Apr: a different mythic each period, no repeats in six months")
	for _, id in mm.Treasures do
		local def = Config.GetTreasure(id)
		check(def and def.Rarity == "Mythic" and def.Seasonal, "mythic " .. id .. " is a seasonal Mythic")
	end
	check(Schedule.Weekday(mm.Epoch) == 1, "mythics rotate on a Monday")

	-- Seasonal finds -------------------------------------------------------------------------------
	local spring = utc(2027, 4, 1, 12)
	local function ids(list)
		local set = {}
		for _, f in list do
			set[f.TreasureId] = true
		end
		return set
	end
	local s3 = ids(Config.GetSeasonalFinds(3, spring, isActiveAt(spring)))
	local s6 = ids(Config.GetSeasonalFinds(6, spring, isActiveAt(spring)))
	check(s3.painted_egg and s3.jeweled_egg, "egg hunt finds in layer 3 during Spring Hatch")
	check(not s6.painted_egg, "no egg hunt finds below layer 5")
	check(s3[Config.GetMonthlyMythic(spring)] and s6[Config.GetMonthlyMythic(spring)], "monthly mythic in every layer")
	local offSpring = { SpringHatch = true }
	check(
		not ids(Config.GetSeasonalFinds(3, spring, isActiveAt(spring, offSpring), offSpring)).painted_egg,
		"events_off SpringHatch stops its finds"
	)
	local noMythic = ids(Config.GetSeasonalFinds(3, spring, isActiveAt(spring), { MonthlyMythic = true }))
	check(noMythic[Config.GetMonthlyMythic(spring)] == nil, "events_off MonthlyMythic stops the mythic")
	check(#Config.GetSeasonalFinds(3, utc(2026, 10, 21), isActiveAt(utc(2026, 10, 21))) == 0, "nothing before Nov")
	check(
		Config.RollSeasonalFind(3, spring, isActiveAt(spring), nil, 0) == "painted_egg",
		"roll 0 = the first limited find"
	)
	check(Config.RollSeasonalFind(3, spring, isActiveAt(spring), nil, 0.99) == nil, "a high roll = ordinary deposit")
	local valentines = utc(2027, 2, 14, 12)
	check(ids(Config.GetSeasonalFinds(9, valentines, isActiveAt(valentines))).ruby_heart, "heart treasures on 14 Feb")
	for _, layer in Config.Layers do
		for _, entry in layer.LootTable do
			check(not Config.GetTreasure(entry.TreasureId).Seasonal, "no seasonal find in a LootTable")
		end
	end

	-- Limited eggs -----------------------------------------------------------------------------------
	local petEggs = {}
	for _, egg in Config.Eggs do
		for _, entry in egg.Pets do
			petEggs[entry.PetId] = (petEggs[entry.PetId] or 0) + 1
		end
	end
	for _, drop in Calendar.Drops do
		if drop.Egg then
			local egg = Config.GetEgg(drop.Egg)
			check(egg and egg.Drop == drop.Id and #egg.Pets == 4, drop.Id .. ": limited egg with 4 pets")
			local legendaries = 0
			for _, entry in egg.Pets do
				local pet = Config.GetPet(entry.PetId)
				check(petEggs[entry.PetId] == 1, entry.PetId .. " is only in its limited egg")
				if pet.Rarity == "Legendary" then
					legendaries += 1
				end
			end
			check(legendaries == 1, drop.Id .. ": one rare (Legendary) pet")
			local mid = (drop.Starts + drop.Ends) // 2
			check(Config.IsEggOnSale(egg.Id, isActiveAt(mid)), drop.Id .. ": egg on sale mid-drop")
			check(not Config.IsEggOnSale(egg.Id, isActiveAt(drop.Ends)), drop.Id .. ": egg gone after the drop")
			check(
				not Config.IsEggOnSale(egg.Id, isActiveAt(mid, { [drop.Id] = true })),
				drop.Id .. ": events_off takes the egg off sale"
			)
		end
	end
	check(Config.IsEggOnSale("beach_egg", isActiveAt(utc(2026, 10, 21))), "ordinary eggs always on sale")
	check(not Config.IsEggOnSale("gift_egg", isActiveAt(utc(2027, 12, 20))), "the Gift Egg doesn't come back next year")

	-- Codes and live config ----------------------------------------------------------------------------
	local LiveConfig = load(Services .. "LiveConfig")
	for _, drop in Calendar.Drops do
		local code = drop.Code
		if code then
			check(LiveConfig.FindCode(code, drop.Starts - 1) == nil, code .. ": not before the drop")
			check(LiveConfig.FindCode(code, drop.Starts) ~= nil, code .. ": live on the first day")
			check(LiveConfig.FindCode(code, drop.Ends - 1) ~= nil, code .. ": live on the last day")
			check(LiveConfig.FindCode(code, drop.Ends) == nil, code .. ": expired the day after")
		end
	end
	local snap, warnings = LiveConfig.Parse(function(key)
		return ({
			events_off = "WinterBeach, FrozenTide, WeekendFest, MonthlyMythic, Wintr",
			codes_off = "SNOWDAY",
			bonus_event = "HarvestDig",
			bonus_event_ends = "2026-11-03 12:00",
		})[key]
	end, utc(2026, 11, 1))
	check(snap.EventsOff.WinterBeach and snap.EventsOff.WeekendFest and snap.EventsOff.MonthlyMythic, "events_off groups")
	check(snap.EventsOff.FrozenTide and not snap.EventsOff.Wintr, "events_off: a modifier on its own, typo dropped")
	check(#warnings == 1 and string.find(warnings[1], "Wintr", 1, true), "events_off: only the typo warns")
	check(snap.CodesOff.SNOWDAY, "codes_off a calendar code")
	check(snap.BonusEvent == "HarvestDig", "bonus_event can run a drop early")
	local offWinter = activeSet(utc(2026, 12, 20, 15, 5), { WinterBeach = true })
	check(not offWinter.WinterBeach and not offWinter.FrozenTide, "events_off WinterBeach stops Frozen Tide too")
	local offFest = activeSet(utc(2026, 10, 24), { WeekendFest = true })
	for _, id in FESTS do
		check(not offFest[id], "events_off WeekendFest stops " .. id)
	end

	-- Advent --------------------------------------------------------------------------------------------
	local r0, d0 = Config.GetAdventReward(utc(2026, 12, 12, 8))
	check(d0 == 0 and r0 == Calendar.Advent.Cycle[1], "advent day 1 = first gift")
	local rx, dx = Config.GetAdventReward(utc(2026, 12, 25, 20))
	check(dx == 13 and rx.Egg == "gift_egg" and rx.EggCount == 3, "Christmas: 3 Gift Eggs")
	local rn, dn = Config.GetAdventReward(utc(2027, 1, 1))
	check(dn == 20 and rn.RebirthTokens == 1, "1 Jan: a Rebirth Token")
	check(Config.GetAdventReward(utc(2026, 12, 18)) == Calendar.Advent.Cycle[1], "the cycle repeats every 6 days")
else
	-- Real Main on 24 Dec 2026 15:00 UTC (Winter Beach, a Thursday) ----------------------------------
	Mock.SetUnixTime(utc(2026, 12, 24, 15, 0))
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
	Mock.Advance(2)
	local Data = load(Services .. "DataService")
	local Events = load(Services .. "EventService")
	local LiveConfig = load(Services .. "LiveConfig")
	local Signals = load(Services .. "ServerSignals")
	local function attr()
		return "," .. tostring(workspace:GetAttribute("ActiveEvents")) .. ","
	end
	local function stand()
		local map = workspace:FindFirstChild("Map")
		return map and map:FindFirstChild("SeasonEggStand")
	end
	local function decks()
		local list = {}
		for _, d in workspace.Map:GetDescendants() do
			if d.Name == "Deck" and d:IsA("BasePart") then
				table.insert(list, d)
			end
		end
		return list
	end
	check(Events.IsActive("WinterBeach") and string.find(attr(), ",WinterBeach,", 1, true), "Winter Beach is on")
	check(not Events.IsActive("NewYear"), "New Year not yet")
	check(workspace:GetAttribute("SeasonTheme") == "Winter", "decor theme Winter")
	local s = stand()
	local pedestal = s and s:FindFirstChild("EggPedestal_gift_egg")
	check(pedestal ~= nil and pedestal:GetAttribute("EggId") == "gift_egg", "pop-up stand holds the Gift Egg")
	local tagged = false
	for _, inst in Mock.Tagged("EggShop") do
		tagged = tagged or inst == pedestal
	end
	check(tagged, "stand pedestal tagged EggShop (opens the egg panel)")
	local deckList = decks()
	check(#deckList > 0 and deckList[1].Material == Enum.Material.Snow, "snow on the boardwalk")

	local player = Mock.AddPlayer(3001, "SnowTester")
	Mock.Advance(2)
	local data = Data.Get(player)
	check(data ~= nil and type(data.Calendar) == "table", "player data has a Calendar table")
	data.Coins = 1e7
	data.MaxDepth = 5
	local function petCount()
		local n = 0
		for _ in data.Pets do
			n += 1
		end
		return n
	end
	local function notified(since, needle)
		for i = since + 1, #Mock.Remote.ToClient do
			local e = Mock.Remote.ToClient[i]
			if e.Player == player and e.Name == "Notify" and string.find(tostring(e.Args[2]), needle, 1, true) then
				return true
			end
		end
		return false
	end
	local before = petCount()
	Mock.FireServer("HatchEgg", player, "gift_egg", 1)
	Mock.Advance(0.5)
	check(petCount() == before + 1, "Gift Egg hatches during Winter Beach")
	local mark = #Mock.Remote.ToClient
	Mock.FireServer("HatchEgg", player, "cornucopia_egg", 1)
	Mock.Advance(0.5)
	check(petCount() == before + 1 and notified(mark, "limited egg"), "an out-of-season egg is refused")

	-- advent: first dig of the day gives a present, the second doesn't
	mark = #Mock.Remote.ToClient
	Signals.Dug:Fire(player, 5, 10, "Shovel")
	Mock.Advance(0.2)
	check(notified(mark, "ADVENT GIFT! Day 13"), "advent gift on the first dig (24 Dec = day 13)")
	check(data.Calendar.AdventDay == Schedule.Day(Mock.UnixTime()), "advent day saved")
	mark = #Mock.Remote.ToClient
	Signals.Dug:Fire(player, 5, 10, "Shovel")
	Signals.Dug:Fire(player, 5, 10, "Pet")
	Mock.Advance(0.2)
	check(not notified(mark, "ADVENT GIFT"), "one advent gift per day")

	-- live override: the whole drop off
	Mock.SetConfig({ events_off = "WinterBeach" })
	Mock.Advance(2)
	check(not Events.IsActive("WinterBeach") and not Events.IsActive("FrozenTide"), "events_off stops the drop")
	check(stand() == nil, "stand removed")
	check(decks()[1].Material ~= Enum.Material.Snow, "boardwalk restored")
	check(workspace:GetAttribute("SeasonTheme") == "", "no theme")
	before = petCount()
	Mock.FireServer("HatchEgg", player, "gift_egg", 1)
	Mock.Advance(0.5)
	check(petCount() == before, "Gift Egg off sale while the drop is off")

	-- bonus_event runs another drop now (owner override)
	Mock.SetConfig({ events_off = "WinterBeach", bonus_event = "HarvestDig", bonus_event_ends = "2026-12-26 12:00" })
	Mock.Advance(2)
	check(Events.IsActive("HarvestDig"), "bonus_event runs Harvest Dig out of season")
	check(workspace:GetAttribute("SeasonTheme") == "Harvest", "theme follows the bonus drop")
	local hs = stand()
	check(hs and hs:FindFirstChild("EggPedestal_cornucopia_egg"), "stand swaps to the Cornucopia Egg")
	Mock.SetConfig({})
	Mock.Advance(2)
	check(Events.IsActive("WinterBeach") and workspace:GetAttribute("SeasonTheme") == "Winter", "back to Winter")

	-- jump to New Year's midnight: New Year inside Winter Beach, fireworks
	Mock.SetUnixTime(utc(2027, 1, 1, 0, 1))
	Mock.Advance(3)
	check(Events.IsActive("WinterBeach") and Events.IsActive("NewYear"), "1 Jan: both drops")
	check(Events.IsActive("Fireworks"), "fireworks event at midnight")
	check(workspace:GetAttribute("SeasonTheme") == "NewYear", "New Year palette over Winter")
	check(decks()[1].Material == Enum.Material.Snow, "snow stays during New Year")
	check(stand() and stand():FindFirstChild("EggPedestal_gift_egg"), "Gift Egg stand stays during New Year")
	local fireworks = 0
	for _, d in workspace.Map:GetChildren() do
		if d.Name == "Firework" then
			fireworks += 1
		end
	end
	check(fireworks > 0, "firework bursts over the sea")
	mark = #Mock.Remote.ToClient
	Signals.Dug:Fire(player, 5, 10, "Auto")
	Mock.Advance(0.2)
	check(notified(mark, "ADVENT GIFT! Day 21"), "a new day: a new advent gift")
	check(LiveConfig.FindCode("HAPPY2027") ~= nil, "New Year code live")

	-- after everything: plain beach
	Mock.SetUnixTime(utc(2027, 1, 5, 12))
	Mock.Advance(3)
	check(not Events.IsActive("WinterBeach") and stand() == nil, "after 4 Jan: drop over, stand gone")
	check(decks()[1].Material ~= Enum.Material.Snow, "after 4 Jan: snow gone")
	check(#Mock.Errors == 0, "no uncaught errors")
	for _, e in Mock.Errors do
		print("  error: " .. tostring(e))
	end
end

print(string.format("CALENDAR (%s): %d passed, %d failed", mode, passes, failures))
if failures > 0 then
	error("CALENDAR SPEC FAILED")
end
