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
	copy.TrophyRecords, copy.CampLayout, copy.RewardReceipts, copy.Cosmetics = nil, nil, nil, nil
	copy.LastOnline, copy.PlayTime = nil, nil -- other services' bookkeeping, not ours
	return copy
end
-- Settlement may yield (durable outbox writes), so run it in a mock thread and advance the
-- virtual clock until it returns.
local function inThread(fn, ...)
	local args = table.pack(...)
	local out = nil
	local done = false
	Mock.Env.task.spawn(function()
		out = table.pack(fn(table.unpack(args, 1, args.n)))
		done = true
	end)
	for _ = 1, 120 do
		if done then
			break
		end
		Mock.Advance(0.25)
	end
	assert(done, "settlement did not finish")
	return table.unpack(out, 1, out.n)
end
local function settle(r)
	return inThread(TrophyService.SettleAdventureCompletion, r)
end
local function settleContext(c)
	return inThread(TrophyService.SettleCompletionContext, c)
end
local function onCompletion(c)
	return inThread(TrophyService.OnCompletion, c)
end
local PENDING = "TrophyPendingGrants_v1"
local function pendingCount(userId)
	local store = Mock.DataStores[PENDING]
	local record = store and store["Pending_" .. userId]
	return if record then count(record.Grants) else 0
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
	check(type(save.Cosmetics) == "table" and next(save.Cosmetics) == nil, "no stand invented")
	local after = deepCopy(save)
	after.TrophyRecords, after.CampLayout, after.RewardReceipts, after.Cosmetics = nil, nil, nil, nil
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
	local report = settle(result("srv-1:1", { participant(A, 0, 40, 1, true) }))
	check(report.Ok == true and report.Error == nil, "accepted")
	check(report.ByUserId[A].Status == "Granted", "solo player granted")
	check(report.ByUserId[A].StandGranted == true, "first completion grants Mara's stand too")
	check(TrophyService.OwnsStand(alice) == true, "stand owned")
	local stand = DataService.Get(alice).Cosmetics.camp_trophy_stand
	check(stand.ReceiptId == Rules.ReceiptId("srv-1:1", A, 1), "stand carries the same receipt")
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
	check(saved and saved.Cosmetics.camp_trophy_stand ~= nil, "stand persisted with the record")
end)

step("repeat / retry / second run never grants twice", function()
	local first = TrophyService.GetTrophies(alice)[TROPHY]
	local again = settle(result("srv-1:1", { participant(A, 0, 40, 1, true) }))
	check(again.Ok and again.ByUserId[A].Status == "Duplicate", "same instance retry -> Duplicate")
	local other = settle(result("srv-1:2", { participant(A, 0, 40, 1, true) }))
	check(other.Ok and other.ByUserId[A].Status == "AlreadyOwned", "later run -> AlreadyOwned")
	local v2 = settle(result("srv-1:1", { participant(A, 0, 40, 1, true) }, { RewardVersion = 2 }))
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
	local report = settle(result("srv-1:3", {
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
		local report = settle(case[2])
		check(
			report.Ok == false and report.Error == case[1],
			"rejected as " .. case[1] .. " (got " .. tostring(report.Error) .. ")"
		)
		check(#report.Results == 0, case[1] .. ": no per-player results")
	end
	check(deepEqual(DataService.Get(cara), snapshot), "rejected settlements changed nothing")
	check(pendingCount(20001) == 0, "rejected settlement queued nothing")
end)

step("feature flag off blocks new grants only", function()
	TrophyService.SetEnabled(false)
	local report = settle(result("srv-1:4", { participant(C, 50, 100, 2, true) }))
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
	local report = settleContext(context("ctx:1", {
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
	local ok, message = onCompletion(context("ctx:1", { ctxP(9107, 14, true, 120, all) }))
	check(ok == true and type(message) == "string", "OnCompletion drop-in returns (true, message)")
	check(
		settleContext(context("ctx:1", { ctxP(9107, 14, true, 120, all) })).ByUserId[9107].Status == "Duplicate",
		"runtime retry is a Duplicate"
	)
end)
step("context: solo, failure and malformed", function()
	local solo = settleContext(context("ctx:2", { ctxP(9108, 3, true, 20, { "vault_anchor_1" }) }))
	check(solo.ByUserId[9108].Status == "Granted", "solo with an objective and points granted")
	local failed = settleContext(context("ctx:3", { ctxP(9107, 14, true, 120, { "x" }) }, { Success = false }))
	check(failed.Ok == false and failed.Error == "NotCompleted", "unsuccessful context refused")
	local ok, message =
		onCompletion(context("ctx:4", { ctxP(9107, 14, true, 120, { "x" }) }, { LandmarkId = "landmark_other" }))
	check(ok == false and type(message) == "string", "OnCompletion reports refusal as (false, message)")
	check(settleContext({ Participants = "no" }).Error == "Malformed", "malformed context refused")
	check(
		settleContext(context("ctx:5", { { UserId = 1, Points = 9, Eligible = true, ActiveSeconds = 50 } })).Error
			== "BadParticipants",
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
	local report = settle(result("srv-1:3", { participant(B, 12, 90, 1, true) }))
	check(report.ByUserId[B].Status == "Duplicate", "post-rejoin retry of the same instance is a Duplicate")
end)

step("accepted grant for a player not loaded here is durable before it is reported", function()
	leave(cara)
	local report = settle(result("srv-1:5", { participant(C, 9, 60, 1, true) }))
	check(report.ByUserId[C].Status == "PendingRejoin", "not loaded -> PendingRejoin")
	check(pendingCount(C) == 1, "intent is in the durable outbox store")
	local retry = settle(result("srv-1:5", { participant(C, 9, 60, 1, true) }))
	check(retry.ByUserId[C].Status == "PendingRejoin" and pendingCount(C) == 1, "retry does not double-queue")
	check(stored(C).TrophyRecords == nil or stored(C).TrophyRecords[TROPHY] == nil, "save untouched while offline")
	cara = join(C, "Cara")
	Mock.Advance(1)
	check(TrophyService.Owns(cara, TROPHY) == true and TrophyService.OwnsStand(cara) == true, "applied on load")
	check(stored(C).TrophyRecords[TROPHY] ~= nil, "applied grant saved")
	check(pendingCount(C) == 0, "outbox acknowledged only after the save")
	local dup = settle(result("srv-1:5", { participant(C, 9, 60, 1, true) }))
	check(dup.ByUserId[C].Status == "Duplicate", "retry after rejoin is a Duplicate")
end)

step("outbox write failure is reported, never claimed as pending", function()
	Mock.DataStoreFail = true
	local report = settle(result("srv-1:8", { participant(9301, 9, 60, 1, true) }))
	Mock.DataStoreFail = false
	check(report.Ok and report.ByUserId[9301].Status == "Refused", "refused while the store is down")
	check(report.ByUserId[9301].Reason == "PendingWriteFailed", "reason given")
	check(pendingCount(9301) == 0, "nothing queued")
	local retry = settle(result("srv-1:8", { participant(9301, 9, 60, 1, true) }))
	check(retry.ByUserId[9301].Status == "PendingRejoin" and pendingCount(9301) == 1, "caller retry succeeds")
end)

step("outbox is bounded per player", function()
	local statuses = {}
	for i = 1, 9 do
		local r = settle(result("bound:" .. i, { participant(9303, 9, 60, 1, true) }))
		table.insert(statuses, r.ByUserId[9303].Status .. "/" .. tostring(r.ByUserId[9303].Reason))
	end
	check(pendingCount(9303) == 8, "8 intents kept")
	check(statuses[9] == "Refused/PendingFull", "9th refused (got " .. statuses[9] .. ")")
end)

step("crash after save but before acknowledge re-applies as a Duplicate", function()
	local ivy = join(9302, "Ivy")
	settle(result("srv-2:1", { participant(9302, 9, 60, 1, true) }))
	local first = TrophyService.GetTrophies(ivy)[TROPHY]
	leave(ivy)
	-- the state a crash leaves behind: grant already saved, outbox entry still present
	Mock.DataStores[PENDING]["Pending_9302"] = {
		Grants = {
			[Rules.ReceiptId("srv-2:1", 9302, 1)] = {
				TrophyId = TROPHY,
				Source = "event_vault",
				RegionId = "sunshine_shore",
				At = 5,
			},
			["trophy:junk"] = "corrupt",
		},
	}
	ivy = join(9302, "Ivy")
	Mock.Advance(1)
	check(deepEqual(TrophyService.GetTrophies(ivy)[TROPHY], first), "no second grant, record unchanged")
	check(pendingCount(9302) == 0, "stale and corrupt entries acknowledged")
	leave(ivy)
end)

step("ineligible offline player is never queued", function()
	local report = settle(result("srv-1:6", { participant(31337, 1, 1, 0, false), participant(A, 9, 60, 1, true) }))
	check(report.ByUserId[31337].Status == "Ineligible" and pendingCount(31337) == 0, "not queued")
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
		check(
			key ~= "TrophyRecords" and key ~= "CampLayout" and key ~= "RewardReceipts" and key ~= "Cosmetics",
			"rebirth keeps " .. key
		)
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
	local report = settle(result("srv-1:7", { participant(9106, 9, 60, 1, true) }))
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

-- Mara's trophy stand ------------------------------------------------------------------------
section("trophy stand requirement")
TrophyService.SetCampPads({
	pads[1],
	pads[2],
	CFrame.new(1080, Config.SURFACE_Y, 1000),
	CFrame.new(1120, Config.SURFACE_Y, 1000),
})
local function seedTrophyWithoutStand(userId)
	local save = legacySave()
	save.TrophyRecords = {
		[TROPHY] = {
			Kind = "Landmark",
			Source = "event_vault",
			RegionId = "sunshine_shore",
			AcquiredAt = 1,
			ReceiptId = "trophy:old:" .. userId .. ":final:v1",
			Legacy = false,
			ContentVersion = 1,
		},
	}
	save.CampLayout = { NextId = 2, Placements = { { Id = 1, TrophyId = TROPHY, X = 2, Z = 2, Rot = 0 } } }
	Mock.DataStores[STORE]["Player_" .. userId] = { Data = save, SavedAt = NOW }
end
step("no stand: layout kept but not displayed, no new placements", function()
	seedTrophyWithoutStand(9304)
	local jo = join(9304, "Jo")
	check(TrophyService.OwnsStand(jo) == false, "no stand")
	check(Display.GetPad(jo) == nil, "camp not displayed without the stand")
	check(#TrophyService.GetCampLayout(jo).Placements == 1, "saved layout kept")
	TrophyService.RemovePlacement(jo, 1)
	local ok, why = TrophyService.PlaceTrophy(jo, { TrophyId = TROPHY, X = 3, Z = 3, Rot = 0 })
	check(not ok and why == "NoStand", "placement refused without the stand")
	local report = settle(result("srv-3:1", { participant(9304, 9, 60, 1, true) }))
	check(
		report.ByUserId[9304].Status == "AlreadyOwned" and report.ByUserId[9304].StandGranted == true,
		"next completion adds the missing stand"
	)
	local ok2 = TrophyService.PlaceTrophy(jo, { TrophyId = TROPHY, X = 3, Z = 3, Rot = 0 })
	check(ok2 == true and Display.GetPad(jo) ~= nil, "displayed once the stand is owned")
	leave(jo)
end)
step("review preview bypass is Studio-only", function()
	seedTrophyWithoutStand(9305)
	local kim = join(9305, "Kim")
	check(TrophyService.SetReviewPreview(true) == false, "refused on a live server")
	check(Display.GetPad(kim) == nil, "still hidden")
	Mock.IsStudio = true
	check(TrophyService.SetReviewPreview(true) == true, "allowed in Studio")
	check(Display.GetPad(kim) ~= nil, "preview shows the camp without a stand")
	TrophyService.RemovePlacement(kim, 1)
	local placed = TrophyService.PlaceTrophy(kim, { TrophyId = TROPHY, X = 5, Z = 5, Rot = 90 })
	check(placed == true, "preview allows placement")
	TrophyService.SetReviewPreview(false)
	Mock.IsStudio = false
	check(Display.GetPad(kim) == nil, "preview off hides it again")
	check(
		#TrophyService.GetCampLayout(kim).Placements == 1 and TrophyService.OwnsStand(kim) == false,
		"preview granted nothing"
	)
	leave(kim)
end)

-- Authored camp pad and pad ownership -----------------------------------------------------
section("authored camp pad: one pad, one owner, hand-over")
-- Clear the explicit test pads and everyone still shown on them, then use the world's pad.
for _, p in { alice, bob, cara, dan } do
	if p and p.Parent ~= nil then
		leave(p)
	end
end
TrophyService.SetCampPads(nil)
local CampPad = Mock.Require(byPath["ServerScriptService/Server/World/CampPad"])
local WorldLayout = Mock.Require(byPath["ServerScriptService/Server/World/Layout"])
local World = Mock.Require(byPath["ServerScriptService/Server/World"])
local padFolder = Mock.Env.Instance.new("Folder")
padFolder.Name = "PadTest"
padFolder.Parent = workspace
local decks = CampPad.Build(padFolder)
local deck = decks[1]
local function owner()
	return TrophyService.GetCampPadOwner(1)
end
local function signText()
	local sign = deck.Parent:FindFirstChild("CampSign")
	local sub = sign and sign:FindFirstChild("SignGui") and sign.SignGui:FindFirstChild("SubLabel")
	return sub and sub.Text
end
local function campModel(userId)
	return workspace:FindFirstChild("TrophyCamps") and workspace.TrophyCamps:FindFirstChild("Camp_" .. userId)
end
local M1, M2, NS = 9401, 9402, 9403
local m1, m2, ns

step("the authored pad", function()
	check(#decks == 1 and #WorldLayout.CAMP_PADS == 1, "one authored pad")
	check(TrophyService.GetCampPadCount() == 1 and Display.GetPadCount() == 1, "display sees exactly one tagged pad")
	check(deck.Anchored and deck.Size.X == 24 and deck.Size.Z == 24, "anchored 24x24 deck")
	check(math.abs(deck.Position.Y + deck.Size.Y / 2 - WorldLayout.DECK_TOP) < 1e-3, "deck top at DECK_TOP")
	for _, d in deck.Parent:GetDescendants() do
		if d:IsA("BasePart") and d ~= deck then
			check(not d.CanCollide and not d.CanTouch, "pad decor does not collide: " .. d.Name)
		end
	end
	check(owner() == nil and deck:GetAttribute("OwnerUserId") == 0, "pad starts free")
	local c = WorldLayout.CAMP_PADS[1]
	check(not World.IsInDigZone(Vector3.new(c.X, Config.SURFACE_Y - 10, c.Z)), "pad is outside the dig zone")
	check(World.IsProtected(Vector3.new(c.X + 12.5, 0, c.Z - 12.5)), "pad footprint protected at any depth")
	check(not World.IsProtected(Vector3.new(c.X + 30, 0, c.Z)), "protection ends past the pad")
	check(World.IsProtected(Vector3.new(c.X + 20, 0, c.Z), 8), "carve margin grows the protected area")
	local zone = World.GetDigZone()
	check(
		c.Z - 12 - WorldLayout.CAMP_PAD_RIM > zone.CFrame.Position.Z + zone.Size.Z / 2 + 8,
		"no dig in the zone can reach under the pad"
	)
end)

step("first eligible player claims the single pad", function()
	m1 = join(M1, "Mo")
	m2 = join(M2, "Nia")
	local report = settle(result("srv-pad:1", { participant(M1, 9, 60, 1, true), participant(M2, 9, 60, 1, true) }))
	check(
		report.ByUserId[M1].Status == "Granted" and report.ByUserId[M2].Status == "Granted",
		"both own trophy + stand"
	)
	check(owner() == nil, "owning a stand alone claims nothing (empty layout)")
	local ok = TrophyService.PlaceTrophy(m1, { TrophyId = TROPHY, X = 5, Z = 5, Rot = 0 })
	check(ok == true and TrophyService.GetCampPad(m1) == 1, "first placer claims pad 1")
	check(owner() == M1, "GetCampPadOwner reports the claimer")
	check(
		deck:GetAttribute("OwnerUserId") == M1 and deck:GetAttribute("OwnerName") == "Mo",
		"pad attributes show the owner"
	)
	check(signText() == "Mo's camp", "pad sign names the owner")
end)

step("no stand never claims, even when the pad is free later", function()
	seedTrophyWithoutStand(NS)
	ns = join(NS, "Ned")
	check(#TrophyService.GetCampLayout(ns).Placements == 1, "no-stand player has a saved layout")
	check(TrophyService.GetCampPad(ns) == nil and owner() == M1, "no-stand player does not take the pad")
end)

step("a second player cannot claim or alter the occupied pad", function()
	local campBefore = campModel(M1)
	local layoutBefore = TrophyService.GetCampLayout(m1)
	local ok, id = TrophyService.PlaceTrophy(m2, { TrophyId = TROPHY, X = 5, Z = 5, Rot = 0 })
	check(ok == true and id == 1, "second player's placement is saved")
	check(#TrophyService.GetCampLayout(m2).Placements == 1, "second player's layout recorded")
	check(TrophyService.GetCampPad(m2) == nil, "second player gets no pad while it is busy")
	check(owner() == M1 and deck:GetAttribute("OwnerUserId") == M1, "owner unchanged")
	check(campModel(M2) == nil, "only the owner's camp is shown")
	-- placement ids are per player: m2 removing "1" removes m2's own display, never m1's
	local okRm = TrophyService.RemovePlacement(m2, 1)
	check(okRm == true and #TrophyService.GetCampLayout(m2).Placements == 0, "removal edits the caller's layout")
	check(deepEqual(TrophyService.GetCampLayout(m1), layoutBefore), "owner's layout untouched")
	check(campModel(M1) == campBefore and campBefore:FindFirstChild("Placement_1") ~= nil, "owner's camp untouched")
	local okBad, why = TrophyService.RemovePlacement(m2, 1)
	check(not okBad and why == "NoSuchPlacement", "cannot reach another player's placement id")
	check(owner() == M1, "still the first owner")
	local okAgain = TrophyService.PlaceTrophy(m2, { TrophyId = TROPHY, X = 0, Z = 0, Rot = 90 })
	check(okAgain == true and TrophyService.GetCampPad(m2) == nil, "waiting player keeps a saved layout")
end)

step("owner leaving hands the pad to the waiting eligible player", function()
	leave(m1)
	check(campModel(M1) == nil, "leaver's camp unloaded")
	check(owner() == M2 and TrophyService.GetCampPad(m2) == 1, "pad handed over automatically")
	check(TrophyService.GetCampPad(ns) == nil, "no-stand player skipped by the hand-over")
	check(deck:GetAttribute("OwnerUserId") == M2 and signText() == "Nia's camp", "pad attributes follow the owner")
	local camp = campModel(M2)
	check(camp ~= nil and camp:GetAttribute("PadIndex") == 1, "new owner's camp built on the pad")
end)

step("rejoining owner waits; emptying a camp releases the pad to them", function()
	m1 = join(M1, "Mo")
	check(#TrophyService.GetCampLayout(m1).Placements == 1, "layout kept across leave/rejoin")
	check(TrophyService.GetCampPad(m1) == nil and owner() == M2, "pad not taken back from its current owner")
	local placed = TrophyService.GetCampLayout(m2).Placements[1]
	TrophyService.RemovePlacement(m2, placed.Id)
	check(owner() == M1 and TrophyService.GetCampPad(m1) == 1, "empty camp releases the pad to the waiting player")
	check(TrophyService.GetCampPad(m2) == nil, "empty layout holds no pad and does not wait")
	TrophyService.PlaceTrophy(m2, { TrophyId = TROPHY, X = 1, Z = 1, Rot = 0 })
	check(owner() == M1, "re-placing does not steal the pad")
end)

step("everyone leaving frees the pad", function()
	leave(m1)
	check(owner() == M2, "handed to the remaining eligible player")
	leave(m2)
	leave(ns)
	check(owner() == nil and deck:GetAttribute("OwnerUserId") == 0, "pad free when nobody is left")
	check(deck:GetAttribute("OwnerName") == "" and signText() == "Free pad", "sign shows a free pad")
	check(campModel(M1) == nil and campModel(M2) == nil, "no camps left")
end)

-- Camp display action (docs/integration/camp-display-action.md) ----------------------------
section("camp display action: prompts, preview cell, status, queue, no pad")
local CampAction = Mock.Require(byPath["ReplicatedStorage/Shared/Trophies/CampAction"])
local actionNotes = {}
local actionNet = {
	Notify = function(player, kind, text)
		table.insert(actionNotes, { Player = player, Kind = kind, Text = text })
	end,
}
local function lastNote(player)
	for i = #actionNotes, 1, -1 do
		if actionNotes[i].Player == player then
			return actionNotes[i]
		end
	end
	return nil
end
local function status(player)
	return player:GetAttribute(CampAction.STATUS_ATTR), player:GetAttribute(CampAction.QUEUE_ATTR)
end
local showPrompt, putPrompt
local function trigger(prompt, player)
	Mock.FireEvent(prompt, "Triggered", player)
	Mock.Advance(0.1)
end
local function grantBoth(player, tag)
	local report = settle(result("srv-act:" .. tag, { participant(player.UserId, 9, 60, 1, true) }))
	return report.ByUserId[player.UserId].Status == "Granted"
end
local function seedTrophyOnly(userId)
	seedTrophyWithoutStand(userId)
	Mock.DataStores[STORE]["Player_" .. userId].Data.CampLayout = { NextId = 1, Placements = {} }
end
local A1, A2, A3, A4, A5 = 9501, 9502, 9503, 9504, 9505
local a1, a2, a3

step("pure: first free cell, request, preview CFrame matches the display", function()
	local empty = { Placements = {}, NextId = 1 }
	local x, z = CampAction.FirstFreeCell(empty)
	check(
		x == 5 and z == 5,
		"first free cell is the plaza-side centre cell (" .. tostring(x) .. "," .. tostring(z) .. ")"
	)
	local taken = { Placements = { { Id = 1, TrophyId = TROPHY, X = 5, Z = 5, Rot = 0 } }, NextId = 2 }
	local x2, z2 = CampAction.FirstFreeCell(taken)
	check(not (x2 == 5 and z2 == 5) and x2 ~= nil, "occupied cell skipped")
	local full = { Placements = {}, NextId = 1 }
	for cx = 0, Rules.CELLS - 1 do
		for cz = 0, Rules.CELLS - 1 do
			table.insert(full.Placements, { Id = #full.Placements + 1, TrophyId = "t", X = cx, Z = cz, Rot = 0 })
		end
	end
	check(CampAction.FirstFreeCell(full) == nil, "full grid: no cell")
	check(CampAction.Request({}, empty) == nil, "no trophy: no request")
	local req = CampAction.Request({ [TROPHY] = {} }, empty)
	check(
		req and req.TrophyId == TROPHY and req.X == 5 and req.Z == 5 and req.Rot == 90,
		"request: trophy, centre, faces plaza"
	)
	local okV = Rules.ValidatePlacement({ [TROPHY] = {} }, empty, req, Rules.TROPHY_SLOTS, true)
	check(okV == true, "the request passes the normal server validation")
	check(CampAction.NextTrophy({ [TROPHY] = {} }, taken) == nil, "already displayed trophy is not offered again")
	local pad = CFrame.new(80, 1027, 76) * CFrame.Angles(0, math.rad(30), 0)
	local a = CampAction.CellCFrame(pad, 5, 5, 90)
	local b = Display.PlacementCFrame(pad, { Id = 1, TrophyId = TROPHY, X = 5, Z = 5, Rot = 90 })
	check(
		(a.Position - b.Position).Magnitude < 1e-6 and a.LookVector:Dot(b.LookVector) > 0.9999,
		"preview CFrame == display CFrame"
	)
	check(a.LookVector:Dot(pad.RightVector * -1) > 0.999, "the stand front faces the plaza (-X of the pad)")
	for _, s in { "NoTrophy", "NoStand", "Ready", "Displayed", "Queued", "NoPad" } do
		check(CampAction.Text(s, 1) ~= "", "text for " .. s)
	end
	check(CampAction.Text("NoTrophy") == "Finish the Spring Vault to earn a trophy.", "no-trophy wording")
	check(CampAction.Text("NoStand") == "You need Mara's trophy stand first.", "no-stand wording")
	check(string.find(CampAction.Text("Queued", 2), "#2", 1, true) ~= nil, "queue position in the wording")
	check(CampAction.Text("Off") == "", "off: no text")
end)

step("server prompts on the authored deck", function()
	TrophyService.ConnectCampPrompts(actionNet)
	TrophyService.ConnectCampPrompts(actionNet) -- idempotent
	showPrompt = deck:FindFirstChild(CampAction.DISPLAY_PROMPT)
	putPrompt = deck:FindFirstChild(CampAction.REMOVE_PROMPT)
	check(showPrompt and showPrompt:IsA("ProximityPrompt"), "display prompt on the deck")
	check(putPrompt and putPrompt:IsA("ProximityPrompt"), "put-away prompt on the deck")
	local n = 0
	for _, c in deck:GetChildren() do
		if c:IsA("ProximityPrompt") then
			n += 1
		end
	end
	check(n == 2, "exactly two prompts after connecting twice")
	check(owner() == nil, "pad free")
end)

step("no trophy: honest status, action refused, nothing saved", function()
	a1 = join(A1, "Ada")
	local s = status(a1)
	check(s == "NoTrophy", "status NoTrophy (" .. tostring(s) .. ")")
	trigger(showPrompt, a1)
	check(#TrophyService.GetCampLayout(a1).Placements == 0, "nothing placed")
	local note = lastNote(a1)
	check(
		note and note.Text == "Finish the Spring Vault to earn a trophy." and note.Kind == "Error",
		"told to finish the vault"
	)
	check(TrophyService.Owns(a1, TROPHY) == false, "the prompt grants nothing")
end)

step("trophy without stand: refused with the stand message", function()
	seedTrophyOnly(A4)
	local d = join(A4, "Dee")
	check(status(d) == "NoStand", "status NoStand")
	local ok, why, text = TrophyService.DisplayAction(d)
	check(not ok and why == "NoStand" and text == "You need Mara's trophy stand first.", "action refused: NoStand")
	check(#TrophyService.GetCampLayout(d).Placements == 0 and owner() == nil, "nothing saved or shown")
	leave(d)
end)

step("trophy + stand: the action places on the first free cell and shows it", function()
	check(grantBoth(a1, "1"), "Ada earns trophy + stand")
	check(status(a1) == "Ready", "status Ready after the grant")
	trigger(showPrompt, a1)
	local layout = TrophyService.GetCampLayout(a1)
	local p = layout.Placements[1]
	check(
		#layout.Placements == 1 and p.TrophyId == TROPHY and p.X == 5 and p.Z == 5 and p.Rot == 90,
		"placed at the first free cell"
	)
	check(owner() == A1 and TrophyService.GetCampPad(a1) == 1, "shown on the pad")
	check(status(a1) == "Displayed", "status Displayed")
	local note = lastNote(a1)
	check(note and note.Kind == "Success" and note.Text == "Trophy on display!", "success toast")
	local camp = campModel(A1)
	local holder = camp and camp:FindFirstChild("Placement_" .. p.Id)
	local stand = holder and holder:FindFirstChild("camp_trophy_stand")
	if check(stand ~= nil, "stand built") then
		local top = deck.CFrame * CFrame.new(0, deck.Size.Y / 2, 0)
		local want = CampAction.CellCFrame(top, 5, 5, 90)
		check(
			(stand:GetPivot().Position - want.Position).Magnitude < 1e-4,
			"display sits exactly on the previewed cell"
		)
	end
	local again, why = TrophyService.DisplayAction(a1)
	check(not again and why == "Displayed", "a second press does not place again")
	check(#TrophyService.GetCampLayout(a1).Placements == 1, "still one placement")
end)

step("pad busy: layout saves, player queued in order, nothing shown", function()
	a2 = join(A2, "Bea")
	a3 = join(A3, "Cy")
	check(grantBoth(a2, "2") and grantBoth(a3, "3"), "both earn trophy + stand")
	check(status(a2) == "Ready", "Ready while the pad is busy (client shows 'next in line')")
	trigger(showPrompt, a2)
	local s2, q2 = status(a2)
	check(s2 == "Queued" and q2 == 1, "Bea queued #1 (" .. tostring(s2) .. "," .. tostring(q2) .. ")")
	check(#TrophyService.GetCampLayout(a2).Placements == 1, "Bea's layout saved")
	check(campModel(A2) == nil and owner() == A1, "nothing of Bea's shown; owner unchanged")
	local note = lastNote(a2)
	check(note and note.Kind == "Info" and string.find(note.Text, "#1", 1, true) ~= nil, "told the place in line")
	local ok3, st3, text3 = TrophyService.DisplayAction(a3)
	local _, q3 = status(a3)
	check(ok3 and st3 == "Queued" and q3 == 2 and string.find(text3, "#2", 1, true) ~= nil, "Cy queued #2")
end)

step("other players' actions never change someone else's camp", function()
	local before = TrophyService.GetCampLayout(a1)
	local campBefore = campModel(A1)
	-- Bea puts hers away: only her saved layout changes; Cy moves up
	trigger(putPrompt, a2)
	check(#TrophyService.GetCampLayout(a2).Placements == 0, "Bea's layout emptied")
	check(
		TrophyService.Owns(a2, TROPHY) == true and TrophyService.OwnsStand(a2) == true,
		"Bea still owns trophy + stand"
	)
	check(status(a2) == "Ready", "Bea back to Ready")
	local s3, q3 = status(a3)
	check(s3 == "Queued" and q3 == 1, "Cy moved up to #1")
	check(deepEqual(TrophyService.GetCampLayout(a1), before), "Ada's layout untouched")
	check(campModel(A1) == campBefore and owner() == A1, "Ada's camp untouched")
	local okNone, why = TrophyService.RemoveAction(a2)
	check(not okNone and why == "NothingDisplayed", "nothing to put away")
	check(deepEqual(TrophyService.GetCampLayout(a1), before) and owner() == A1, "Ada still untouched")
end)

step("put away keeps ownership and hands the pad to the next in line", function()
	trigger(putPrompt, a1)
	check(#TrophyService.GetCampLayout(a1).Placements == 0, "Ada's display removed")
	check(TrophyService.Owns(a1, TROPHY) == true and TrophyService.OwnsStand(a1) == true, "Ada keeps trophy + stand")
	local note = lastNote(a1)
	check(note and note.Text == "Trophy put away. You still own it.", "put-away toast")
	check(status(a1) == "Ready", "Ada can display again")
	check(owner() == A3 and status(a3) == "Displayed", "pad handed to Cy, status follows")
	check(campModel(A1) == nil and campModel(A3) ~= nil, "only Cy's camp shown")
	local saved = DataService.Get(a1)
	check(saved.TrophyRecords[TROPHY] ~= nil and saved.Cosmetics.camp_trophy_stand ~= nil, "save still holds ownership")
end)

step("leaving updates everyone's place in line", function()
	TrophyService.DisplayAction(a1) -- Ada #1 behind Cy
	TrophyService.DisplayAction(a2) -- Bea #2
	check(select(2, status(a1)) == 1 and select(2, status(a2)) == 2, "Ada #1, Bea #2")
	leave(a1)
	check(status(a2) == "Queued" and select(2, status(a2)) == 1, "Bea moves up to #1 when Ada leaves")
	leave(a3)
	check(owner() == A2 and status(a2) == "Displayed", "Cy leaving hands the pad to Bea")
	leave(a2)
	check(owner() == nil, "pad free")
end)

step("no pad at all: layout saves, honest message, nothing shown", function()
	TrophyService.SetCampPads({}) -- an explicit empty list: this server has no camp pad
	check(TrophyService.GetCampPadCount() == 0, "pad count 0")
	local e = join(A5, "Eli")
	check(grantBoth(e, "5"), "Eli earns trophy + stand")
	local ok, st, text = TrophyService.DisplayAction(e)
	check(ok and st == "NoPad", "action saves the layout and reports NoPad (" .. tostring(st) .. ")")
	check(
		text == CampAction.Text("NoPad") and string.find(text, "nothing is shown", 1, true) ~= nil,
		"honest no-pad text"
	)
	check(#TrophyService.GetCampLayout(e).Placements == 1 and TrophyService.GetCampPad(e) == nil, "saved, not shown")
	check(status(e) == "NoPad", "status attribute NoPad")
	check(campModel(A5) == nil, "no camp model")
	TrophyService.SetCampPads(nil)
	TrophyService.SetReviewPreview(false) -- any refresh: the authored pad is back
	check(owner() == A5 and status(e) == "Displayed", "with the pad back, the saved layout shows")
	trigger(putPrompt, e)
	check(owner() == nil and status(e) == "Ready", "put away")
	leave(e)
end)

step("feature disabled: action hidden and refused", function()
	local f = join(A5, "Eli")
	TrophyService.SetEnabled(false)
	check(status(f) == "Off", "status Off")
	check(showPrompt.Enabled == false and putPrompt.Enabled == false, "prompts disabled for everyone")
	local ok, st = TrophyService.DisplayAction(f)
	check(not ok and st == "Off", "action refused while off")
	check(#TrophyService.GetCampLayout(f).Placements == 0, "nothing placed")
	TrophyService.SetEnabled(true)
	check(status(f) == "Ready" and showPrompt.Enabled == true, "back on")
	leave(f)
end)

step("Studio review preview: displays without a stand, grants nothing", function()
	seedTrophyOnly(A4)
	local d = join(A4, "Dee")
	Mock.IsStudio = true
	TrophyService.SetReviewPreview(true)
	check(status(d) == "Ready", "preview: Ready without a stand")
	trigger(showPrompt, d)
	check(owner() == A4 and status(d) == "Displayed", "preview shows it on the pad")
	TrophyService.SetReviewPreview(false)
	Mock.IsStudio = false
	check(owner() == nil and status(d) == "NoStand", "preview off: hidden again, honest NoStand")
	check(TrophyService.OwnsStand(d) == false, "preview granted no stand")
	check(#TrophyService.GetCampLayout(d).Placements == 1, "the reviewed layout stays saved")
	leave(d)
end)

check(#Mock.Errors == 0, "no uncaught errors (" .. #Mock.Errors .. ")")
for _, e in Mock.Errors do
	print("  error: " .. tostring(e))
end

-- Server B ------------------------------------------------------------------------------------
-- A fresh mock game with fresh module instances, sharing only Mock.DataStores: the player
-- was never on server A, whose in-memory state plays no part in the recovery.
section("cross-server recovery (second mock server)")
step("pending grant from server A is applied when the player loads on server B", function()
	local report = settle(result("srv-A:9", { participant(9310, 9, 60, 1, true) }))
	check(report.ByUserId[9310].Status == "PendingRejoin", "queued on server A")
	Mock.Init(Generated)
	local byB = Mock.ByPath
	local DataB = Mock.Require(byB[P .. "DataService"])
	local TrophyB = Mock.Require(byB[P .. "TrophyService"])
	check(TrophyB ~= TrophyService, "server B has its own module instances")
	DataB.Init()
	TrophyB.Init()
	local lee = Mock.AddPlayer(9310, "Lee")
	DataB.OnPlayerAdded(lee)
	TrophyB.OnPlayerAdded(lee)
	Mock.Advance(2)
	check(TrophyB.Owns(lee, TROPHY) == true and TrophyB.OwnsStand(lee) == true, "granted on server B")
	check(pendingCount(9310) == 0, "outbox acknowledged on server B")
	check(stored(9310).TrophyRecords[TROPHY] ~= nil, "saved by server B")
	check(#Mock.Errors == 0, "server B: no uncaught errors")
end)

print(string.format("TROPHY SPEC: %d passed, %d failed", passes, failures))
if failures > 0 then
	error("TROPHY SPEC FAILED")
end
