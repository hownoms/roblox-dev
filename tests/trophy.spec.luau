--!nocheck
--[[
	Headless trophy tests (TrophyService, TrophyData adapter, TrophyCampDisplay, Trophies.Rules)
	against tests/mock/Roblox.luau. Run by tests/run.sh after bundle.py.

	MOCK COVERAGE ONLY. "DataStore" below is the mock's in-memory UpdateAsync store driven
	through the real DataService code (session lock, sanitize, save on leave). It proves the
	trophy code's save/rejoin logic against DataService, not live Roblox persistence.
]]

local Mock = require("./mock/Roblox")
local Generated = require("../build/test/generated")
Mock.Init(Generated)

local Vector3 = Mock.Vector3
local CFrame = Mock.CFrame

local failures, passes = 0, 0
local function check(cond, message)
	if cond then
		passes += 1
	else
		failures += 1
		print("FAIL: " .. message)
	end
	return cond
end
local function section(name)
	print("== " .. name)
end
local function step(name, fn)
	local ok, err = pcall(fn)
	if not ok then
		failures += 1
		print("FAIL (error) in " .. name .. ": " .. tostring(err))
	end
end

local function deepEqual(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b or (a ~= a and b ~= b)
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end
local function deepCopy(v)
	if type(v) ~= "table" then
		return v
	end
	local c = {}
	for k, x in v do
		c[k] = deepCopy(x)
	end
	return c
end
local function count(t)
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local byPath = Mock.ByPath
local P = "ServerScriptService/Server/Services/"
local Config = Mock.Require(byPath["ReplicatedStorage/Shared/Config"])
local Rules = Mock.Require(byPath["ReplicatedStorage/Shared/Trophies/Rules"])
local Catalog = Mock.Require(byPath["ReplicatedStorage/Shared/Trophies/Catalog"])
local Remotes = Mock.Require(byPath["ReplicatedStorage/Shared/Remotes"])
local DataService = Mock.Require(byPath[P .. "DataService"])
local TrophyService = Mock.Require(byPath[P .. "TrophyService"])
local Display = Mock.Require(byPath[P .. "TrophyCampDisplay"])
local workspace = Mock.Service("Workspace")

local TROPHY = "landmark_spring_vault"
local STORE = Config.DATASTORE_NAME
local NOW = 1_800_000_000

-- A representative v3 (current live schema) save with purchases and permanent possessions.
local function legacySave()
	local d = Config.NewPlayerData()
	d.Coins = 123456
	d.Rebirths = 3
	d.RebirthTokens = 7
	d.MaxDepth = 512
	d.OwnedShovels = { [d.Shovel] = true, golden_spade = true }
	d.Pets = { ["uid-1"] = { Id = Config.Pets[1].Id, Equipped = true } }
	d.Index = { [Config.Treasures[1].Id] = true, [Config.Treasures[2].Id] = true }
	d.Finds = { [Config.Treasures[1].Id .. "|Normal|None|Good"] = 2 }
	d.FindVariants = { [Config.Treasures[1].Id .. "/Normal"] = true }
	d.RedeemedCodes = { DIGDEEP = true }
	d.RebirthPerks = { head_start = 2 }
	d.FirstJoin = 1_700_000_000
	d.Version = 3
	return d
end

local function participant(userId, points, active, objectives, present)
	return {
		UserId = userId,
		Points = points,
		ActiveSeconds = active,
		ObjectiveCompletions = objectives,
		PresentForObjective = present,
	}
end
local function result(instanceId, participants, overrides)
	local r = {
		EventId = "event_vault",
		LandmarkId = TROPHY,
		InstanceId = instanceId,
		Outcome = "Completed",
		RewardVersion = 1,
		Participants = participants,
	}
	for k, v in overrides or {} do
		r[k] = v
	end
	return r
end

local function join(userId, name)
	local player = Mock.AddPlayer(userId, name)
	DataService.OnPlayerAdded(player)
	TrophyService.OnPlayerAdded(player)
	Mock.Advance(0.5)
	return player
end
local function leave(player)
	TrophyService.OnPlayerRemoving(player)
	DataService.OnPlayerRemoving(player)
	Mock.RemovePlayer(player)
	Mock.Advance(0.5)
end
local function stored(userId)
	local record = Mock.DataStores[STORE] and Mock.DataStores[STORE]["Player_" .. userId]
	return record and record.Data
end
local function nonTrophyFields(data)
	local copy = deepCopy(data)
	copy.TrophyRecords, copy.CampLayout, copy.RewardReceipts = nil, nil, nil
	copy.LastOnline, copy.PlayTime = nil, nil -- other services' bookkeeping, not ours
	return copy
end

DataService.Init()
TrophyService.Init()
check(#Mock.Errors == 0, "boot without errors")

-- Pure migration -----------------------------------------------------------------------------
section("migration (pure)")
step("legacy save gains fields, keeps everything else, invents nothing", function()
	local save = legacySave()
	local before = deepCopy(save)
	check(Rules.Migrate(save, NOW) == true, "first migration reports a change")
	check(
		type(save.TrophyRecords) == "table" and next(save.TrophyRecords) == nil,
		"no trophy invented from Index/Finds"
	)
	check(deepEqual(save.CampLayout, { Placements = {}, NextId = 1 }), "empty camp layout")
	check(type(save.RewardReceipts) == "table" and next(save.RewardReceipts) == nil, "empty receipts")
	local after = deepCopy(save)
	after.TrophyRecords, after.CampLayout, after.RewardReceipts = nil, nil, nil
	check(deepEqual(after, before), "every pre-existing field is byte-for-byte unchanged")
	local once = deepCopy(save)
	check(Rules.Migrate(save, NOW) == false, "second migration reports no change")
	check(deepEqual(save, once), "migration is idempotent")
end)

step("malformed trophy fields are repaired without losing ownership", function()
	local save = legacySave()
	save.TrophyRecords = { [TROPHY] = true, future_trophy = { Kind = "Landmark", Extra = 1 }, [5] = {} }
	save.CampLayout = {
		NextId = 2,
		Placements = {
			{ Id = 1, TrophyId = TROPHY, X = 0, Z = 0, Rot = 0 },
			{ Id = 1, TrophyId = "future_trophy", X = 1, Z = 0, Rot = 0 }, -- duplicate id
			{ Id = 3, TrophyId = "future_trophy", X = 0, Z = 0, Rot = 0 }, -- occupied cell
			{ Id = 4, TrophyId = "future_trophy", X = 12, Z = 0, Rot = 0 }, -- out of bounds
			{ Id = 5, TrophyId = "future_trophy", X = 2, Z = 2, Rot = 45 }, -- bad rotation
			{ Id = 6, TrophyId = "not_owned", X = 3, Z = 3, Rot = 0 }, -- unowned
			{ Id = 7, TrophyId = "future_trophy", X = 1.5, Z = 3, Rot = 0 }, -- fractional cell
			{ Id = 9, TrophyId = "future_trophy", X = 4, Z = 4, Rot = 90, Spoof = "rbxassetid://1" },
			"garbage",
		},
	}
	save.RewardReceipts = {
		["trophy:old:1:final:v1"] = NOW - Rules.RECEIPT_TTL - 1,
		["trophy:bad:1:final:v1"] = "nope",
		["trophy:fresh:1:final:v1"] = NOW - 10,
		["stage:other-owner"] = { anything = true }, -- another namespace: untouched
	}
	check(Rules.Migrate(save, NOW) == true, "repair reported")
	check(
		save.TrophyRecords[TROPHY] ~= nil and save.TrophyRecords[TROPHY].Repaired == true,
		"non-table record kept as owned"
	)
	check(save.TrophyRecords.future_trophy.Extra == 1, "unknown (newer) trophy record kept as-is")
	check(save.TrophyRecords[5] == nil, "non-string trophy key dropped")
	local placements = save.CampLayout.Placements
	check(#placements == 2, "only the two valid placements survive (got " .. #placements .. ")")
	check(
		placements[1].Id == 1 and placements[2].Id == 9 and placements[2].Spoof == nil,
		"valid placements kept, extra fields stripped"
	)
	check(save.CampLayout.NextId == 10, "NextId repaired above the highest id")
	check(save.RewardReceipts["trophy:old:1:final:v1"] == nil, "expired receipt pruned")
	check(save.RewardReceipts["trophy:bad:1:final:v1"] == nil, "invalid receipt pruned")
	check(save.RewardReceipts["trophy:fresh:1:final:v1"] == NOW - 10, "fresh receipt kept")
	check(save.RewardReceipts["stage:other-owner"] ~= nil, "foreign receipt namespace untouched")
	local once = deepCopy(save)
	check(Rules.Migrate(save, NOW) == false and deepEqual(save, once), "repair is idempotent")
end)

step("receipt window is bounded", function()
	local receipts = { ["foreign"] = 1 }
	for i = 1, Rules.RECEIPT_LIMIT + 40 do
		receipts[Rules.ReceiptId("inst-" .. i, 1, 1)] = NOW - 1000 + i
	end
	Rules.PruneReceipts(receipts, NOW)
	check(count(receipts) == Rules.RECEIPT_LIMIT + 1, "pruned to the limit plus foreign keys")
	check(receipts[Rules.ReceiptId("inst-1", 1, 1)] == nil, "oldest dropped first")
	check(receipts[Rules.ReceiptId("inst-" .. (Rules.RECEIPT_LIMIT + 40), 1, 1)] ~= nil, "newest kept")
	check(receipts.foreign == 1, "foreign receipt kept")
end)

-- Eligibility -------------------------------------------------------------------------------
section("eligibility rule")
step("bible ch.04 contribution rule", function()
	check(Rules.IsEligible(participant(1, 0, 5, 1, true), 1) == true, "solo: one objective qualifies")
	check(Rules.IsEligible(participant(1, 0, 600, 0, true), 1) == false, "solo: presence alone does not")
	check(Rules.IsEligible(participant(1, 10, 0, 1, true), 3) == true, "crew: 5+ points and present for an objective")
	check(Rules.IsEligible(participant(1, 5, 30, 0, false), 3) == true, "late helper: 5 points and 30 s active")
	check(Rules.IsEligible(participant(1, 4.9, 600, 3, true), 3) == false, "crew: under 5 points never qualifies")
	check(Rules.IsEligible(participant(1, 6, 29, 0, false), 3) == false, "crew: points without presence or 30 s")
	check(Rules.IsEligible(participant(1, 0, 0, 0, true), 4) == false, "spectator cannot farm")
end)

-- Load path through the real DataService ----------------------------------------------------
section("existing save loads through DataService")
local A, B, C, D = 9101, 9102, 9103, 9104
Mock.DataStores[STORE] = Mock.DataStores[STORE] or {}
for _, id in { A, B, C, D } do
	Mock.DataStores[STORE]["Player_" .. id] = { Data = legacySave(), SavedAt = NOW }
end
local alice
step("legacy v3 save migrates on load", function()
	alice = join(A, "Alice")
	local data = DataService.Get(alice)
	check(data ~= nil, "loaded")
	check(TrophyService.Owns(alice, TROPHY) == false, "legacy player owns no adventure trophy")
	check(deepEqual(TrophyService.GetCampLayout(alice), { Placements = {}, NextId = 1 }), "empty layout")
	local expected = legacySave()
	check(
		data.Coins == expected.Coins and data.Rebirths == 3 and data.OwnedShovels.golden_spade,
		"purchases/progress intact"
	)
	check(
		deepEqual(data.Index, expected.Index) and deepEqual(data.Finds, expected.Finds),
		"Index and unsold finds intact"
	)
	check(count(data.Pets) == 1, "pets intact")
end)

-- Settlement --------------------------------------------------------------------------------
section("completion settlement")
local before
step("solo completion grants once and saves", function()
	before = nonTrophyFields(DataService.Get(alice))
	local report = TrophyService.SettleAdventureCompletion(result("srv-1:1", { participant(A, 0, 40, 1, true) }))
	check(report.Ok == true and report.Error == nil, "accepted")
	check(report.ByUserId[A].Status == "Granted", "solo player granted")
	check(TrophyService.Owns(alice, TROPHY) == true, "now owned")
	local rec = TrophyService.GetTrophies(alice)[TROPHY]
	check(rec.Source == "event_vault" and rec.Kind == "Landmark" and rec.Legacy == false, "record context")
	check(rec.ReceiptId == Rules.ReceiptId("srv-1:1", A, 1), "record carries its receipt")
	check(rec.SaleValue == nil and rec.Value == nil, "no sale value on a trophy")
	Mock.Advance(1)
	local saved = stored(A)
	check(
		saved and saved.TrophyRecords[TROPHY] ~= nil,
		"settlement written to the store promptly (not waiting for autosave)"
	)
	check(saved and saved.RewardReceipts[rec.ReceiptId] ~= nil, "receipt persisted with the record")
end)

step("repeat / retry / second run never grants twice", function()
	local first = TrophyService.GetTrophies(alice)[TROPHY]
	local again = TrophyService.SettleAdventureCompletion(result("srv-1:1", { participant(A, 0, 40, 1, true) }))
	check(again.Ok and again.ByUserId[A].Status == "Duplicate", "same instance retry -> Duplicate")
	local other = TrophyService.SettleAdventureCompletion(result("srv-1:2", { participant(A, 0, 40, 1, true) }))
	check(other.Ok and other.ByUserId[A].Status == "AlreadyOwned", "later run -> AlreadyOwned")
	local v2 = TrophyService.SettleAdventureCompletion(
		result("srv-1:1", { participant(A, 0, 40, 1, true) }, { RewardVersion = 2 })
	)
	check(v2.ByUserId[A].Status == "AlreadyOwned", "new reward version still cannot regrant")
	check(deepEqual(TrophyService.GetTrophies(alice)[TROPHY], first), "original record untouched")
	check(count(TrophyService.GetTrophies(alice)) == 1, "exactly one record")
	check(deepEqual(nonTrophyFields(DataService.Get(alice)), before), "no non-trophy field changed by settlements")
end)

local bob, cara, dan
step("crew: only eligible contributors are granted", function()
	bob = join(B, "Bob")
	cara = join(C, "Cara")
	dan = join(D, "Dan")
	local report = TrophyService.SettleAdventureCompletion(result("srv-1:3", {
		participant(B, 12, 90, 1, true), -- contributor
		participant(C, 2, 200, 0, true), -- spectator-ish: too few points
		participant(D, 5, 35, 0, false), -- late helper, active 35 s
	}))
	check(report.Ok, "accepted")
	check(report.ByUserId[B].Status == "Granted", "contributor granted")
	check(
		report.ByUserId[C].Status == "Ineligible" and report.ByUserId[C].Reason == "LowContribution",
		"low contribution refused"
	)
	check(report.ByUserId[D].Status == "Granted", "useful late helper granted")
	check(TrophyService.Owns(cara, TROPHY) == false, "ineligible player owns nothing")
	check(#report.Results == 3, "one result per participant, in order")
end)

step("invalid results change nothing", function()
	local snapshot = deepCopy(DataService.Get(cara))
	local p = { participant(C, 50, 100, 2, true) }
	local cases = {
		{ "UnknownEvent", result("x:1", p, { EventId = "event_salvage" }) },
		{ "LandmarkMismatch", result("x:1", p, { LandmarkId = "landmark_other" }) },
		{ "NotCompleted", result("x:1", p, { Outcome = "Failed" }) },
		{ "NotCompleted", result("x:1", p, { Outcome = "Abandoned" }) },
		{ "BadInstanceId", result("", p) },
		{ "BadInstanceId", result(string.rep("a", 81), p) },
		{ "BadRewardVersion", result("x:1", p, { RewardVersion = 0.5 }) },
		{ "BadParticipants", result("x:1", {}) },
		{ "BadParticipants", result("x:1", { participant(C, 0 / 0, 100, 2, true) }) },
		{ "BadParticipants", result("x:1", { participant(C, 50, 100, 2, true), participant(C, 50, 100, 2, true) }) },
		{ "BadParticipants", result("x:1", { participant(C, 50, 100, 2, "yes") }) },
		{ "Malformed", "event_vault" },
	}
	local many = {}
	for i = 1, 17 do
		table.insert(many, participant(20000 + i, 10, 60, 1, true))
	end
	table.insert(cases, { "BadParticipants", result("x:1", many) })
	for _, case in cases do
		local report = TrophyService.SettleAdventureCompletion(case[2])
		check(
			report.Ok == false and report.Error == case[1],
			"rejected as " .. case[1] .. " (got " .. tostring(report.Error) .. ")"
		)
		check(#report.Results == 0, case[1] .. ": no per-player results")
	end
	check(deepEqual(DataService.Get(cara), snapshot), "rejected settlements changed nothing")
	check(not TrophyService.HasPendingGrant(20001), "rejected settlement queued nothing")
end)

step("feature flag off blocks new grants only", function()
	TrophyService.SetEnabled(false)
	local report = TrophyService.SettleAdventureCompletion(result("srv-1:4", { participant(C, 50, 100, 2, true) }))
	check(report.Ok == false and report.Error == "Disabled", "disabled settlement refused")
	check(TrophyService.Owns(alice, TROPHY) == true, "earned trophy still owned while disabled")
	TrophyService.SetEnabled(true)
	check(TrophyService.Owns(cara, TROPHY) == false, "nothing granted while disabled")
end)

-- Adventure runtime context (shape of SpringVaultState.completionContext) --------------------
section("adventure CompletionContext adapter")
local function context(instanceId, participants, overrides)
	local c = {
		BoundaryVersion = 1,
		EventInstanceId = instanceId,
		EventId = "event_vault",
		LandmarkId = TROPHY,
		RegionId = "sunshine_shore",
		StartedAt = 100,
		CompletedAt = 300,
		Success = true,
		ObjectiveIds = { "vault_anchor_1", "vault_anchor_2", "vault_anchor_3", "latch", "gate_1", "gate_2", "gate_3" },
		CompletedStages = { "excavation", "vault_open", "ball_return" },
		Participants = participants,
	}
	for k, v in overrides or {} do
		c[k] = v
	end
	return table.freeze(c)
end
local function ctxP(userId, points, eligible, active, objectives)
	return table.freeze({
		UserId = userId,
		Points = points,
		Eligible = eligible,
		ActiveSeconds = active,
		ObjectiveIds = table.freeze(table.clone(objectives)),
	})
end
local gus, hal
step("maps the runtime context and honours its Eligible veto", function()
	gus = join(9107, "Gus")
	hal = join(9108, "Hal")
	local all = { "vault_anchor_1", "latch", "gate_1" }
	local report = TrophyService.SettleCompletionContext(context("ctx:1", {
		ctxP(9107, 14, true, 120, all),
		ctxP(9108, 14, false, 120, all), -- the runtime vetoed (e.g. disconnected at completion)
	}))
	check(report.Ok and report.InstanceId == "ctx:1", "accepted frozen runtime context")
	check(report.ByUserId[9107].Status == "Granted", "eligible runtime participant granted")
	check(
		report.ByUserId[9108].Status == "Ineligible" and report.ByUserId[9108].Reason == "EventIneligible",
		"runtime veto respected"
	)
	check(TrophyService.Owns(hal, TROPHY) == false, "vetoed player owns nothing")
	local ok, message = TrophyService.OnCompletion(context("ctx:1", { ctxP(9107, 14, true, 120, all) }))
	check(ok == true and type(message) == "string", "OnCompletion drop-in returns (true, message)")
	check(
		TrophyService.SettleCompletionContext(context("ctx:1", { ctxP(9107, 14, true, 120, all) })).ByUserId[9107].Status
			== "Duplicate",
		"runtime retry is a Duplicate"
	)
end)
step("context: solo, failure and malformed", function()
	local solo =
		TrophyService.SettleCompletionContext(context("ctx:2", { ctxP(9108, 3, true, 20, { "vault_anchor_1" }) }))
	check(solo.ByUserId[9108].Status == "Granted", "solo with an objective and points granted")
	local failed = TrophyService.SettleCompletionContext(
		context("ctx:3", { ctxP(9107, 14, true, 120, { "x" }) }, { Success = false })
	)
	check(failed.Ok == false and failed.Error == "NotCompleted", "unsuccessful context refused")
	local ok, message = TrophyService.OnCompletion(
		context("ctx:4", { ctxP(9107, 14, true, 120, { "x" }) }, { LandmarkId = "landmark_other" })
	)
	check(ok == false and type(message) == "string", "OnCompletion reports refusal as (false, message)")
	check(
		TrophyService.SettleCompletionContext({ Participants = "no" }).Error == "Malformed",
		"malformed context refused"
	)
	check(
		TrophyService.SettleCompletionContext(
			context("ctx:5", { { UserId = 1, Points = 9, Eligible = true, ActiveSeconds = 50 } })
		).Error == "BadParticipants",
		"participant without ObjectiveIds refused"
	)
	leave(gus)
	leave(hal)
end)

-- Disconnect / reconnect --------------------------------------------------------------------
section("disconnect, rejoin, reconnect")
step("granted trophy survives leave and rejoin (mock store)", function()
	leave(bob)
	check(stored(B).TrophyRecords[TROPHY] ~= nil, "saved on leave")
	bob = join(B, "Bob")
	check(TrophyService.Owns(bob, TROPHY) == true, "owned after rejoin")
	local report = TrophyService.SettleAdventureCompletion(result("srv-1:3", { participant(B, 12, 90, 1, true) }))
	check(report.ByUserId[B].Status == "Duplicate", "post-rejoin retry of the same instance is a Duplicate")
end)

step("eligible player who disconnected before settlement gets it on rejoin here", function()
	leave(cara)
	local report = TrophyService.SettleAdventureCompletion(result("srv-1:5", { participant(C, 9, 60, 1, true) }))
	check(report.ByUserId[C].Status == "PendingRejoin", "offline eligible -> PendingRejoin")
	check(TrophyService.HasPendingGrant(C), "pending queued")
	local retry = TrophyService.SettleAdventureCompletion(result("srv-1:5", { participant(C, 9, 60, 1, true) }))
	check(
		retry.ByUserId[C].Status == "PendingRejoin" and TrophyService.HasPendingGrant(C),
		"retry does not double-queue"
	)
	check(stored(C).TrophyRecords == nil or stored(C).TrophyRecords[TROPHY] == nil, "nothing written while offline")
	cara = join(C, "Cara")
	check(TrophyService.Owns(cara, TROPHY) == true, "pending grant applied on load")
	check(not TrophyService.HasPendingGrant(C), "pending cleared")
	local dup = TrophyService.SettleAdventureCompletion(result("srv-1:5", { participant(C, 9, 60, 1, true) }))
	check(dup.ByUserId[C].Status == "Duplicate", "retry after rejoin is a Duplicate")
	Mock.Advance(1)
	check(stored(C).TrophyRecords[TROPHY] ~= nil, "applied pending grant saved")
end)

step("ineligible offline player is never queued", function()
	local report = TrophyService.SettleAdventureCompletion(
		result("srv-1:6", { participant(31337, 1, 1, 0, false), participant(A, 9, 60, 1, true) })
	)
	check(report.ByUserId[31337].Status == "Ineligible" and not TrophyService.HasPendingGrant(31337), "not queued")
end)

-- Client cannot grant -----------------------------------------------------------------------
section("client cannot grant")
step("no remote grants trophies; camp remotes reject spoofed ids", function()
	for _, name in Remotes.Events do
		check(not string.find(string.lower(name), "trophy", 1, true), "no trophy-granting remote: " .. name)
	end
	local handlers = {}
	local notes = {}
	local fakeNet = {
		On = function(name, fn)
			handlers[name] = fn
		end,
		IsString = function(v, max)
			return type(v) == "string" and #v > 0 and #v <= (max or 64)
		end,
		IsInteger = function(v, min, max)
			return type(v) == "number" and v == v and v % 1 == 0 and v >= min and v <= max
		end,
		Notify = function(player, kind, text)
			table.insert(notes, { player, kind, text })
		end,
	}
	TrophyService.ConnectRemotes(fakeNet)
	check(handlers.PlaceCampItem and handlers.RemoveCampItem and count(handlers) == 2, "exactly the two camp remotes")
	local eve = join(9105, "Eve")
	Mock.DataStores[STORE]["Player_9105"] = nil
	handlers.PlaceCampItem(eve, TROPHY, 0, 0, 0)
	check(TrophyService.Owns(eve, TROPHY) == false, "placing an unowned trophy does not grant it")
	check(#TrophyService.GetCampLayout(eve).Placements == 0, "and places nothing")
	check(#notes == 1 and notes[1][2] == "Error", "player told why")
	handlers.PlaceCampItem(eve, { TrophyId = TROPHY }, 0, 0, 0)
	handlers.PlaceCampItem(eve, "rbxassetid://123", 0, 0, 0)
	handlers.RemoveCampItem(eve, "1")
	check(TrophyService.Owns(eve, TROPHY) == false and #Mock.Errors == 0, "garbage payloads ignored safely")
	leave(eve)
end)

-- Camp placement ----------------------------------------------------------------------------
section("camp placement")
local pads = {
	CFrame.new(1000, Config.SURFACE_Y, 1000),
	CFrame.new(1040, Config.SURFACE_Y, 1000) * CFrame.Angles(0, math.rad(90), 0),
}
TrophyService.SetCampPads(pads)

step("bounds and request validation", function()
	local bad = {
		{ "OutOfBounds", { TrophyId = TROPHY, X = -1, Z = 0, Rot = 0 } },
		{ "OutOfBounds", { TrophyId = TROPHY, X = 12, Z = 0, Rot = 0 } },
		{ "OutOfBounds", { TrophyId = TROPHY, X = 0, Z = 12, Rot = 0 } },
		{ "Malformed", { TrophyId = TROPHY, X = 1.5, Z = 0, Rot = 0 } },
		{ "Malformed", { TrophyId = TROPHY, X = 0 / 0, Z = 0, Rot = 0 } },
		{ "Malformed", { TrophyId = TROPHY, X = math.huge, Z = 0, Rot = 0 } },
		{ "Malformed", { TrophyId = TROPHY, X = "0", Z = 0, Rot = 0 } },
		{ "BadRotation", { TrophyId = TROPHY, X = 0, Z = 0, Rot = 45 } },
		{ "BadRotation", { TrophyId = TROPHY, X = 0, Z = 0, Rot = 360 } },
		{ "Malformed", { TrophyId = string.rep("x", 65), X = 0, Z = 0, Rot = 0 } },
		{ "Malformed", "not a table" },
	}
	for _, case in bad do
		local ok, reason = TrophyService.PlaceTrophy(alice, case[2])
		check(ok == false and reason == case[1], "rejected " .. case[1] .. " (got " .. tostring(reason) .. ")")
	end
	check(#TrophyService.GetCampLayout(alice).Placements == 0, "nothing placed by bad requests")
	-- slot / overlap rules need several displayable trophies; only one exists in this slice,
	-- so exercise them on the pure validator with a stand-in layout
	local owned = { [TROPHY] = {}, a = {}, b = {}, c = {} }
	local layout = {
		NextId = 4,
		Placements = {
			{ Id = 1, TrophyId = "a", X = 0, Z = 0, Rot = 0 },
			{ Id = 2, TrophyId = "b", X = 1, Z = 0, Rot = 0 },
		},
	}
	local ok1, why1 = Rules.ValidatePlacement(owned, layout, { TrophyId = TROPHY, X = 0, Z = 0, Rot = 0 })
	check(not ok1 and why1 == "Occupied", "occupied cell rejected")
	table.insert(layout.Placements, { Id = 3, TrophyId = "c", X = 2, Z = 0, Rot = 0 })
	local ok2, why2 = Rules.ValidatePlacement(owned, layout, { TrophyId = TROPHY, X = 5, Z = 5, Rot = 0 })
	check(not ok2 and why2 == "NoSlots", "fourth trophy rejected with 3 slots")
	local ok3 = Rules.ValidatePlacement(owned, layout, { TrophyId = TROPHY, X = 5, Z = 5, Rot = 0 }, 6)
	check(ok3 == true, "allowed when slots are raised")
	local ok4, why4 = Rules.ValidatePlacement(
		{ [TROPHY] = {}, future = {} },
		{ NextId = 1, Placements = {} },
		{ TrophyId = "future", X = 0, Z = 0, Rot = 0 }
	)
	check(not ok4 and why4 == "NotDisplayable", "owned but undisplayable id rejected")
end)

local placementId
step("valid placement persists and builds the kit display", function()
	local ok, id = TrophyService.PlaceTrophy(alice, { TrophyId = TROPHY, X = 11, Z = 0, Rot = 90 })
	check(ok == true and id == 1, "placed with id 1")
	placementId = id
	local okDup, whyDup = TrophyService.PlaceTrophy(alice, { TrophyId = TROPHY, X = 3, Z = 3, Rot = 0 })
	check(not okDup and whyDup == "AlreadyDisplayed", "one display per owned trophy")
	local layout = TrophyService.GetCampLayout(alice)
	check(#layout.Placements == 1 and layout.NextId == 2, "layout recorded")
	local camp = workspace:FindFirstChild("TrophyCamps") and workspace.TrophyCamps:FindFirstChild("Camp_" .. A)
	check(camp ~= nil, "camp model built")
	if camp then
		check(camp:GetAttribute("OwnerUserId") == A, "camp tagged with owner")
		local holder = camp:FindFirstChild("Placement_1")
		check(holder ~= nil, "placement model built")
		local stand = holder and holder:FindFirstChild("camp_trophy_stand")
		local replica = holder and holder:FindFirstChild("landmark_spring_vault_trophy")
		check(stand ~= nil and replica ~= nil, "TrophyStand + TrophyReplica factories used")
		if stand and replica then
			local pad = pads[camp:GetAttribute("PadIndex")]
			local standLocal = pad:PointToObjectSpace(stand:GetPivot().Position)
			check(
				math.abs(standLocal.X - 11) < 1e-3 and math.abs(standLocal.Z + 11) < 1e-3,
				"stand at cell (11,0) centre"
			)
			check(
				math.abs(standLocal.X) + 1 <= 12 and math.abs(standLocal.Z) + 1 <= 12,
				"2x2 footprint inside the 24x24 pad"
			)
			local rel = stand:GetPivot():ToObjectSpace(replica:GetPivot())
			check(math.abs(rel.Position.Y - 1.75) < 1e-3, "replica sits on TrophySlot")
			for _, d in replica:GetDescendants() do
				if d:IsA("BasePart") then
					check(
						d.Anchored and not d.CanCollide and not d.CanQuery and not d.CanTouch,
						"replica part is display-only: " .. d.Name
					)
				end
			end
			for _, d in stand:GetDescendants() do
				if d:IsA("BasePart") then
					check(d.Anchored and not d.CanCollide, "stand part does not block movement: " .. d.Name)
				end
			end
		end
	end
end)

step("second player gets a different pad; leaving frees it", function()
	local ok = TrophyService.PlaceTrophy(bob, { TrophyId = TROPHY, X = 0, Z = 0, Rot = 0 })
	check(ok == true, "bob placed")
	local padA, padB = Display.GetPad(alice), Display.GetPad(bob)
	check(padA ~= nil and padB ~= nil and padA ~= padB, "distinct pads")
	check(Display.GetPad(dan) == nil, "player with an empty layout holds no pad")
	leave(bob)
	check(Display.GetPad(bob) == nil, "pad released on leave")
	check(workspace.TrophyCamps:FindFirstChild("Camp_" .. B) == nil, "offline camp unloaded")
	TrophyService.SetCampPads({})
	local okNoPad = TrophyService.PlaceTrophy(dan, { TrophyId = TROPHY, X = 4, Z = 4, Rot = 180 })
	check(okNoPad == true and Display.GetPad(dan) == nil, "no free pad: placement still saved, nothing shown")
	TrophyService.SetCampPads(pads)
	bob = join(B, "Bob")
	check(Display.GetPad(bob) ~= nil, "rejoin rebuilds the saved camp")
	check(#TrophyService.GetCampLayout(bob).Placements == 1, "bob's layout survived leave/rejoin")
end)

step("removing a display keeps ownership, also across save/rejoin", function()
	local ok, why = TrophyService.RemovePlacement(alice, 999)
	check(not ok and why == "NoSuchPlacement", "unknown placement id")
	local okBad, whyBad = TrophyService.RemovePlacement(alice, 0 / 0)
	check(not okBad and whyBad == "Malformed", "NaN id rejected")
	local okRemove = TrophyService.RemovePlacement(alice, placementId)
	check(okRemove == true, "removed")
	check(TrophyService.Owns(alice, TROPHY) == true, "still owned after removal")
	check(#TrophyService.GetCampLayout(alice).Placements == 0, "layout empty")
	check(Display.GetPad(alice) == nil, "display torn down and pad freed")
	leave(alice)
	local saved = stored(A)
	check(saved.TrophyRecords[TROPHY] ~= nil and #saved.CampLayout.Placements == 0, "saved: owned, not displayed")
	alice = join(A, "Alice")
	check(TrophyService.Owns(alice, TROPHY) == true, "owned after rejoin")
	local okAgain, newId = TrophyService.PlaceTrophy(alice, { TrophyId = TROPHY, X = 6, Z = 6, Rot = 270 })
	check(okAgain == true and newId == 2, "can display again; ids never reused")
	check(deepEqual(nonTrophyFields(DataService.Get(alice)), before), "camp edits never touched non-trophy fields")
end)

-- Interaction with existing systems ---------------------------------------------------------
section("existing systems")
step("rebirth reset list does not include trophy fields", function()
	for _, key in Config.Rebirths.Resets do
		check(key ~= "TrophyRecords" and key ~= "CampLayout" and key ~= "RewardReceipts", "rebirth keeps " .. key)
	end
end)
step("catalog: trophy has no sale value and one source", function()
	local def = Catalog.Get(TROPHY)
	check(def ~= nil and def.Sources.event_vault == true and count(def.Sources) == 1, "event_vault is the only source")
	check(def.SellValue == nil and def.Value == nil, "no payout field")
end)
step("save interrupted mid-settlement does not half-apply", function()
	-- A failing store must not lose the in-session grant, and the next save must carry it.
	local frank = join(9106, "Frank")
	Mock.DataStoreFail = true
	local report = TrophyService.SettleAdventureCompletion(result("srv-1:7", { participant(9106, 9, 60, 1, true) }))
	check(report.ByUserId[9106].Status == "Granted", "granted in session")
	Mock.Advance(40) -- immediate save retries fail
	check(
		stored(9106) == nil or stored(9106).TrophyRecords == nil or stored(9106).TrophyRecords[TROPHY] == nil,
		"nothing written while the store is down"
	)
	Mock.DataStoreFail = false
	leave(frank)
	local saved = stored(9106)
	check(
		saved
			and saved.TrophyRecords[TROPHY] ~= nil
			and saved.RewardReceipts[Rules.ReceiptId("srv-1:7", 9106, 1)] ~= nil,
		"record and receipt land together on the next save"
	)
end)

check(#Mock.Errors == 0, "no uncaught errors (" .. #Mock.Errors .. ")")
for _, e in Mock.Errors do
	print("  error: " .. tostring(e))
end

print(string.format("TROPHY SPEC: %d passed, %d failed", passes, failures))
if failures > 0 then
	error("TROPHY SPEC FAILED")
end
