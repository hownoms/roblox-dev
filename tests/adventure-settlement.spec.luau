--!nocheck
--[[
	Headless tests for the adventure completion bridge (Rewards.AdventureRewards pure rules and
	AdventureSettlement against the real DataService / TrophyService) on tests/mock/Roblox.luau.
	Run by tests/run.sh after bundle.py.

	Contexts below have exactly the shape codex/spring-vault-adventure hands over:
	SpringVaultService's OnStage observation and SpringVaultState.completionContext().

	MOCK COVERAGE ONLY. "DataStore" is the mock's in-memory UpdateAsync store driven through the
	real DataService code; "crash" means discarding a mock server without its leave/close saves;
	"another server" is a fresh mock game sharing only Mock.DataStores. None of this proves live
	Roblox persistence.
]]

local Mock = require("./mock/Roblox")
local Generated = require("../build/test/generated")
Mock.Init(Generated)

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
local function deepEqual(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
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
local function count(t)
	local n = 0
	for _ in t or {} do
		n += 1
	end
	return n
end

local P = "ServerScriptService/Server/Services/"
local Config, Rewards, TrophyRules, DataService, TrophyService, Settlement
local function loadServer()
	local byPath = Mock.ByPath
	Config = Mock.Require(byPath["ReplicatedStorage/Shared/Config"])
	Rewards = Mock.Require(byPath["ReplicatedStorage/Shared/Rewards/AdventureRewards"])
	TrophyRules = Mock.Require(byPath["ReplicatedStorage/Shared/Trophies/Rules"])
	DataService = Mock.Require(byPath[P .. "DataService"])
	TrophyService = Mock.Require(byPath[P .. "TrophyService"])
	Settlement = Mock.Require(byPath[P .. "AdventureSettlement"])
	DataService.Init()
	TrophyService.Init()
	Settlement.Init()
	DataService.Start()
	Settlement.Start()
end
loadServer()

local TROPHY = "landmark_spring_vault"
local STAND = "camp_trophy_stand"
local STORE = Config.DATASTORE_NAME
local OUTBOX = "AdventureRewardIntents_v1"
local STAGES = { "excavation", "vault_open", "ball_return" }

-- Codex shapes ------------------------------------------------------------------------------
local function obs(userId, points, connected, left, objectives)
	return {
		UserId = userId,
		Points = points,
		ObjectiveIds = objectives or {},
		Connected = connected ~= false,
		Left = left == true,
	}
end
local function stage(instanceId, stageId, participants, overrides)
	local completed = {}
	for _, id in STAGES do
		table.insert(completed, id)
		if id == stageId then
			break
		end
	end
	local o = {
		BoundaryVersion = 1,
		EventInstanceId = instanceId,
		EventId = "event_vault",
		LandmarkId = TROPHY,
		RegionId = "sunshine_shore",
		StageId = stageId,
		ObjectiveIds = {},
		CompletedStages = completed,
		Participants = participants,
	}
	for k, v in overrides or {} do
		o[k] = v
	end
	return table.freeze(o)
end
local function cp(userId, points, eligible, active, objectives)
	return {
		UserId = userId,
		Points = points,
		Eligible = eligible,
		ActiveSeconds = active,
		ObjectiveIds = objectives or {},
	}
end
local function completion(instanceId, participants, overrides)
	local c = {
		BoundaryVersion = 1,
		EventInstanceId = instanceId,
		EventId = "event_vault",
		LandmarkId = TROPHY,
		RegionId = "sunshine_shore",
		StartedAt = 10,
		CompletedAt = 200,
		Success = true,
		ObjectiveIds = { "vault_anchor_1", "vault_anchor_2", "vault_anchor_3", "ball_gate_1" },
		CompletedStages = table.clone(STAGES),
		Participants = participants,
		ContentVersion = 1,
		CompletedAtUnix = 1_800_000_000,
	}
	for k, v in overrides or {} do
		c[k] = v
	end
	return c
end

-- Harness -----------------------------------------------------------------------------------
local function join(userId, name)
	local player = Mock.AddPlayer(userId, name)
	DataService.OnPlayerAdded(player)
	TrophyService.OnPlayerAdded(player)
	Settlement.OnPlayerAdded(player)
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
local function outboxCount(userId)
	local store = Mock.DataStores[OUTBOX]
	local record = store and store["Pending_" .. userId]
	return if record then count(record.Grants) else 0
end
local function waitDone(report)
	for _ = 1, 200 do
		if report.Done then
			break
		end
		Mock.Advance(0.1)
	end
	return report.Done
end
-- Settlement must never yield (it runs inside the runtime's Heartbeat loop).
local function noYield(fn, ...)
	local args = table.pack(...)
	local out
	local co = coroutine.create(function()
		out = table.pack(fn(table.unpack(args, 1, args.n)))
	end)
	local ok, err = coroutine.resume(co)
	assert(ok, tostring(err))
	assert(coroutine.status(co) == "dead", "settlement yielded")
	return table.unpack(out, 1, out.n)
end
local function settleStage(o)
	local report = noYield(Settlement.SettleStage, o)
	waitDone(report)
	return report
end
local function settleFinal(c)
	local report = noYield(Settlement.SettleCompletion, c)
	waitDone(report)
	return report
end
-- Runs a yielding call in a mock thread and advances the clock until it returns.
local function inThread(fn, ...)
	local args = table.pack(...)
	local out, done = nil, false
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
	assert(done, "call did not finish")
	return table.unpack(out, 1, out.n)
end
local function queue(userId, intent)
	return inThread(Settlement.Outbox.Add, userId, Rewards.ReceiptFor(intent), intent)
end
-- Fail only one DataStore (by name) while set.
local function failStore(name)
	Mock.BeforeDataStoreUpdate = if name
		then function(storeName)
			if storeName == name then
				error("502: mock " .. name .. " outage")
			end
		end
		else nil
end

local NOW = os.time()
check(#Mock.Errors == 0, "boot without errors")

-- Pure rules ----------------------------------------------------------------------------------
section("pure rules: validation")
step("stage observation validation", function()
	local good = { obs(1, 5) }
	local cases = {
		{ "Malformed", nil },
		{ "UnknownEvent", stage("i:1", "excavation", good, { EventId = "event_nope" }) },
		{ "BoundaryVersion", stage("i:1", "excavation", good, { BoundaryVersion = 2 }) },
		{ "LandmarkMismatch", stage("i:1", "excavation", good, { LandmarkId = "landmark_other" }) },
		{ "LandmarkMismatch", stage("i:1", "excavation", good, { RegionId = "bloomwild" }) },
		{ "BadInstanceId", stage("", "excavation", good) },
		{ "BadInstanceId", stage(string.rep("x", 81), "excavation", good) },
		{ "BadParticipants", stage("i:1", "excavation", {}) },
		{ "BadParticipants", stage("i:1", "excavation", { obs(1, 5), obs(1, 5) }) },
		{ "BadParticipants", stage("i:1", "excavation", { obs(1, 0 / 0) }) },
		{ "BadParticipants", stage("i:1", "excavation", { obs(1.5, 5) }) },
		{ "UnknownStage", stage("i:1", "lunch", good) },
		{ "StageNotCompleted", stage("i:1", "ball_return", good, { CompletedStages = { "excavation" } }) },
	}
	for _, case in cases do
		local decisions, err = Rewards.StageDecisions(case[2], NOW)
		check(decisions == nil and err == case[1], "stage rejects " .. case[1] .. " (got " .. tostring(err) .. ")")
	end
	local tooMany = {}
	for i = 1, 17 do
		tooMany[i] = obs(i, 1)
	end
	check(
		select(2, Rewards.StageDecisions(stage("i:1", "excavation", tooMany), NOW)) == "BadParticipants",
		"17 participants"
	)
end)
step("completion context validation", function()
	local good = { cp(1, 20, true, 60, { "a" }) }
	check(
		select(2, Rewards.FinalDecisions(completion("i:1", good, { Success = false }), NOW)) == "NotCompleted",
		"failure"
	)
	check(
		select(2, Rewards.FinalDecisions(completion("i:1", { cp(1, 20, "yes", 60) }), NOW)) == "BadParticipants",
		"non-boolean Eligible"
	)
	check(
		select(2, Rewards.FinalDecisions(completion("i:1", { cp(1, 20, true, math.huge) }), NOW)) == "BadParticipants",
		"infinite ActiveSeconds"
	)
	check(
		select(2, Rewards.FinalDecisions(completion("i:1", good, { BoundaryVersion = 0 }), NOW)) == "BoundaryVersion",
		"version"
	)
end)

section("pure rules: eligibility")
step("stage credit needs connected, present contribution", function()
	local decisions = Rewards.StageDecisions(
		stage("i:2", "vault_open", { obs(1, 12), obs(2, 0), obs(3, 8, false), obs(4, 8, true, true) }),
		NOW
	)
	local by = {}
	for _, d in decisions do
		by[d.UserId] = d
	end
	check(by[1].Intent and by[1].Intent.Coins == 6 and by[1].Intent.StageId == "vault_open", "contributor gets 6")
	check(by[2].Intent == nil and by[2].Reason == "NoContribution", "presence alone earns nothing")
	check(by[3].Intent == nil and by[3].Reason == "Disconnected", "disconnected gets nothing")
	check(by[4].Intent == nil and by[4].Reason == "Left", "departed gets nothing")
end)
step("final eligibility: runtime veto AND contribution rule", function()
	local decisions = Rewards.FinalDecisions(
		completion("i:3", {
			cp(1, 20, true, 100, { "vault_anchor_1" }),
			cp(2, 6, true, 40, {}), -- active participant
			cp(3, 3, true, 200, { "ball_gate_1" }), -- low points
			cp(4, 30, false, 200, { "vault_anchor_2" }), -- runtime veto (disconnected at completion)
			cp(5, 0, false, 0, {}), -- spectator
		}),
		NOW
	)
	local by = {}
	for _, d in decisions do
		by[d.UserId] = d
	end
	check(by[1].Intent and by[1].Intent.Kind == "Final" and by[1].Intent.Coins == 60, "contributor eligible")
	check(by[2].Intent ~= nil, "active participant with points eligible")
	check(by[3].Intent == nil and by[3].Reason == "LowContribution", "low points ineligible")
	check(by[4].Intent == nil and by[4].Reason == "EventIneligible", "runtime veto honoured")
	check(by[5].Intent == nil and by[5].Reason == "EventIneligible", "spectator ineligible")
	local solo = Rewards.FinalDecisions(completion("i:4", { cp(9, 3, true, 10, { "vault_anchor_1" }) }), NOW)
	check(solo[1].Intent ~= nil, "solo objective completion qualifies")
end)

section("pure rules: application")
local function freshSave()
	local d = Config.NewPlayerData()
	d.Coins = 100
	TrophyRules.Migrate(d, NOW)
	Rewards.Migrate(d, NOW)
	return d
end
local function intentsFor(instanceId, userId)
	local s = {}
	for _, id in STAGES do
		local decisions = Rewards.StageDecisions(stage(instanceId, id, { obs(userId, 10) }), NOW)
		s[id] = decisions[1].Intent
	end
	local final =
		Rewards.FinalDecisions(completion(instanceId, { cp(userId, 30, true, 90, { "vault_anchor_1" }) }), NOW)
	return s, final[1].Intent
end
step("full run totals the base reward; first clear grants everything together", function()
	local d = freshSave()
	local s, final = intentsFor("i:5", 7)
	for _, id in STAGES do
		local a = Rewards.Apply(d, s[id], NOW)
		check(a.Status == "Applied" and a.Coins == 6, "stage " .. id .. " +6")
	end
	local a = Rewards.Apply(d, final, NOW)
	check(a.Status == "Applied" and a.Coins == 42, "final pays the remaining 42")
	check(d.Coins == 160, "total +60")
	check(a.FirstClear == true, "first clear")
	check(a.Trophy and a.Trophy.Status == "Granted" and a.Trophy.StandGranted == true, "trophy + stand")
	check(a.Certification == "cert_crew" and d.Certifications.cert_crew ~= nil, "cert_crew")
	check(a.QuestCredit == true and d.AdventureProgress.QuestCredit.q_mara.finish_event_vault ~= nil, "q_mara credit")
	check(d.TrophyRecords[TROPHY] ~= nil and d.Cosmetics[STAND] ~= nil, "records written")
	check(d.RewardReceipts[Rewards.FinalReceiptId("i:5", 7, 1)] ~= nil, "final receipt")
	check(d.RewardReceipts[TrophyRules.ReceiptId("i:5", 7, 1)] ~= nil, "trophy receipt in the same mutation")
	check(d.AdventureProgress.Events.event_vault.Clears == 1, "one clear")
	local dup = Rewards.Apply(d, final, NOW)
	check(dup.Status == "Duplicate" and d.Coins == 160, "final replay is a duplicate")
	check(Rewards.Apply(d, s.excavation, NOW).Status == "Duplicate", "stage replay is a duplicate")
end)
step("late helper reconciles to the base total; stage after final pays nothing", function()
	local d = freshSave()
	local s, final = intentsFor("i:6", 8)
	Rewards.Apply(d, s.ball_return, NOW) -- joined late: only the last stage
	local a = Rewards.Apply(d, final, NOW)
	check(a.Coins == 54 and d.Coins == 160, "6 + 54 = 60")
	local late = Rewards.Apply(d, s.excavation, NOW)
	check(late.Status == "Applied" and late.Coins == 0 and d.Coins == 160, "stage replayed after final adds nothing")
	local d2 = freshSave()
	local _, final2 = intentsFor("i:7", 8)
	check(Rewards.Apply(d2, final2, NOW).Coins == 60, "final alone pays the full 60")
end)
step("repeat clear: base coins again, no second first-clear grant", function()
	local d = freshSave()
	local _, first = intentsFor("i:8", 9)
	Rewards.Apply(d, first, NOW)
	local cert = deepCopy(d.Certifications)
	local trophy = deepCopy(d.TrophyRecords)
	local _, again = intentsFor("i:9", 9)
	local a = Rewards.Apply(d, again, NOW)
	check(a.Status == "Applied" and a.Coins == 60 and a.FirstClear == false, "repeat pays base, not first clear")
	check(a.Certification == nil and a.QuestCredit == false, "no repeat cert/quest")
	check(a.Trophy.Status == "AlreadyOwned" and a.Trophy.StandGranted == false, "trophy already owned")
	check(deepEqual(cert, d.Certifications) and deepEqual(trophy, d.TrophyRecords), "permanent records unchanged")
	check(d.AdventureProgress.Events.event_vault.Clears == 2, "two clears")
end)
step("first-clear flags survive receipt pruning", function()
	local d = freshSave()
	local _, first = intentsFor("i:10", 10)
	Rewards.Apply(d, first, NOW)
	Rewards.PruneReceipts(d.RewardReceipts, NOW + Rewards.RECEIPT_TTL + 1)
	TrophyRules.PruneReceipts(d.RewardReceipts, NOW + Rewards.RECEIPT_TTL + 1)
	check(count(d.RewardReceipts) == 0, "receipts pruned")
	local a = Rewards.Apply(d, first, NOW + Rewards.RECEIPT_TTL + 2)
	check(
		a.FirstClear == false and a.Certification == nil and a.Trophy.Status == "AlreadyOwned",
		"no second first clear"
	)
end)
step("migration: adds fields, keeps everything else, invents nothing, idempotent", function()
	local d = Config.NewPlayerData()
	d.Coins = 999
	d.Certifications = { cert_rookie = "garbage", [5] = true }
	d.RewardReceipts = { ["other:x"] = 1, ["adv:old"] = 1 }
	local before = deepCopy(d)
	check(Rewards.Migrate(d, NOW) == true, "changed")
	check(d.Certifications.cert_rookie.Repaired == true and d.Certifications[5] == nil, "repaired, kept owned id")
	check(d.Certifications.cert_crew == nil, "invents nothing")
	check(d.RewardReceipts["other:x"] == 1 and d.RewardReceipts["adv:old"] == nil, "prunes only its namespace")
	check(type(d.AdventureProgress.Events) == "table" and type(d.AdventureProgress.QuestCredit) == "table", "progress")
	local copy = deepCopy(d)
	check(Rewards.Migrate(d, NOW) == false and deepEqual(copy, d), "idempotent")
	for k, v in before do
		if k ~= "Certifications" and k ~= "RewardReceipts" then
			check(deepEqual(v, d[k]), "untouched " .. k)
		end
	end
end)
step("outbox intents are re-validated", function()
	local s, final = intentsFor("i:11", 11)
	check(Rewards.IsIntent(Rewards.ReceiptFor(final), final), "valid final")
	check(Rewards.IsIntent(Rewards.ReceiptFor(s.vault_open), s.vault_open), "valid stage")
	check(not Rewards.IsIntent("adv:i:11:12:final:v1", final), "receipt must match the intent's user")
	local rich = table.clone(final)
	rich.Coins = 1_000_000
	check(not Rewards.IsIntent(Rewards.ReceiptFor(rich), rich), "coins above base rejected")
	local bad = table.clone(s.vault_open)
	bad.StageId = "bonus"
	check(not Rewards.IsIntent(Rewards.ReceiptFor(bad), bad), "unknown stage rejected")
	check(not Rewards.IsIntent("x", "y"), "garbage rejected")
end)

-- Service -----------------------------------------------------------------------------------
section("service: solo first clear")
local notes = {}
Settlement.SetNotifier(function(player, text)
	table.insert(notes, { UserId = player.UserId, Text = text })
end)
step("stages then completion grant 60 coins, trophy, stand, cert and quest credit", function()
	local ann = join(5001, "Ann")
	local coins0 = DataService.Get(ann).Coins
	local p = { obs(5001, 10, true, false, { "vault_anchor_1" }) }
	for _, id in STAGES do
		local r = settleStage(stage("srv:1", id, p))
		check(r.Ok and r.ByUserId[5001].Status == "Saved" and r.ByUserId[5001].Coins == 6, "stage " .. id .. " saved")
	end
	local report = settleFinal(completion("srv:1", { cp(5001, 30, true, 120, { "vault_anchor_1" }) }))
	local r = report.ByUserId[5001]
	check(report.Ok and r.Status == "Saved", "final saved")
	check(
		r.Coins == 42 and r.FirstClear and r.TrophyGranted and r.StandGranted and r.Certification == "cert_crew",
		"everything granted"
	)
	check(DataService.Get(ann).Coins == coins0 + 60, "+60 coins live")
	check(TrophyService.Owns(ann, TROPHY) == true and TrophyService.OwnsStand(ann) == true, "trophy service sees it")
	check(Settlement.HasCertification(ann, "cert_crew") == true, "cert query")
	local saved = stored(5001)
	check(
		saved.Coins == coins0 + 60
			and saved.TrophyRecords[TROPHY] ~= nil
			and saved.Cosmetics[STAND] ~= nil
			and saved.Certifications.cert_crew ~= nil
			and saved.AdventureProgress.QuestCredit.q_mara.finish_event_vault ~= nil
			and saved.RewardReceipts[Rewards.FinalReceiptId("srv:1", 5001, 1)] ~= nil,
		"the written save holds the whole first clear"
	)
	local last = notes[#notes]
	check(last and last.UserId == 5001 and string.find(last.Text, "trophy", 1, true) ~= nil, "player notified")
	check(outboxCount(5001) == 0, "nothing left in the outbox")
	leave(ann)
end)
step("drop-in runtime callbacks never yield", function()
	local bo = join(5002, "Bo")
	noYield(Settlement.OnStage, stage("srv:2", "excavation", { obs(5002, 10) }))
	local accepted, message = noYield(Settlement.OnCompletion, completion("srv:2", { cp(5002, 10, true, 60, { "a" }) }))
	check(accepted == true and type(message) == "string", "accepted")
	local refused, why =
		noYield(Settlement.OnCompletion, completion("srv:2b", { cp(5002, 10, true, 60) }, { Success = false }))
	check(refused == false and string.find(why, "unavailable", 1, true) ~= nil, "refusal message")
	Mock.Advance(2)
	check(DataService.Get(bo).AdventureProgress.Events.event_vault.Clears == 1, "applied")
	leave(bo)
end)

section("service: crew, late helper, disconnects")
step("late helper gets only what they qualify for", function()
	local cal, dee, eve, fay = join(5101, "Cal"), join(5102, "Dee"), join(5103, "Eve"), join(5104, "Fay")
	local base = {}
	for _, pl in { cal, dee, eve, fay } do
		base[pl.UserId] = DataService.Get(pl).Coins
	end
	-- Dee joins after the anchors and only helps with the ball; Eve only watches; Fay disconnects.
	settleStage(stage("srv:3", "excavation", { obs(5101, 10), obs(5104, 4) }))
	settleStage(stage("srv:3", "vault_open", { obs(5101, 10), obs(5102, 0), obs(5103, 0), obs(5104, 4, false) }))
	settleStage(stage("srv:3", "ball_return", { obs(5101, 20), obs(5102, 10), obs(5103, 0), obs(5104, 4, false) }))
	local report = settleFinal(completion("srv:3", {
		cp(5101, 20, true, 200, { "vault_anchor_1", "ball_gate_1" }),
		cp(5102, 10, true, 70, { "ball_gate_2" }),
		cp(5103, 0, true, 150, {}),
		cp(5104, 4, false, 60, { "vault_anchor_1" }),
	}))
	check(DataService.Get(cal).Coins - base[5101] == 60, "full crew member +60")
	check(DataService.Get(dee).Coins - base[5102] == 60, "late helper +6 stage +54 final")
	check(report.ByUserId[5102].Coins == 54 and report.ByUserId[5102].FirstClear, "late helper's first clear")
	check(TrophyService.Owns(dee, TROPHY) == true, "late helper trophy")
	check(DataService.Get(eve).Coins == base[5103] and report.ByUserId[5103].Status == "Ineligible", "watcher nothing")
	check(TrophyService.Owns(eve, TROPHY) == false, "watcher no trophy")
	check(report.ByUserId[5104].Reason == "EventIneligible", "disconnected at completion: no final")
	check(DataService.Get(fay).Coins - base[5104] == 6, "disconnected keeps the stage grant earned before")
	check(Settlement.HasCertification(fay, "cert_crew") == false, "no cert without the final")
	for _, pl in { cal, dee, eve, fay } do
		leave(pl)
	end
end)
step("replays and retries are idempotent", function()
	local gus = join(5201, "Gus")
	local p = { obs(5201, 10) }
	settleStage(stage("srv:4", "excavation", p))
	local again = settleStage(stage("srv:4", "excavation", p))
	check(again.ByUserId[5201].Status == "Duplicate", "stage replay duplicate")
	local c = completion("srv:4", { cp(5201, 10, true, 60, { "a" }) })
	settleFinal(c)
	local coins = DataService.Get(gus).Coins
	local retry = settleFinal(c)
	check(retry.ByUserId[5201].Status == "Duplicate" and DataService.Get(gus).Coins == coins, "final retry duplicate")
	-- The old trophy-only path shares the trophy receipt, so wiring both cannot double-grant.
	local old = TrophyService.SettleCompletionContext(c)
	check(old.ByUserId[5201].Status == "Duplicate", "trophy path sees the same receipt")
	leave(gus)
end)
step("feature flag refuses new settlements only", function()
	local hal = join(5202, "Hal")
	Settlement.SetEnabled(false)
	local r = settleStage(stage("srv:5", "excavation", { obs(5202, 10) }))
	check(r.Ok == false and r.Error == "Disabled" and r.Done, "disabled")
	Settlement.SetEnabled(true)
	leave(hal)
end)

section("durability")
step("save outage: outbox holds the grant, next load on another path dedupes", function()
	local ida = join(5301, "Ida")
	failStore(STORE)
	local report = settleFinal(completion("srv:6", { cp(5301, 10, true, 60, { "a" }) }))
	failStore(nil)
	check(report.ByUserId[5301].Status == "Queued", "queued in the outbox when the save write fails")
	check(outboxCount(5301) == 1, "intent stored")
	leave(ida)
	check(stored(5301).Certifications.cert_crew ~= nil, "leave save carried it")
	ida = join(5301, "Ida")
	Mock.Advance(1)
	check(outboxCount(5301) == 0, "re-applied as a duplicate and acknowledged")
	check(DataService.Get(ida).AdventureProgress.Events.event_vault.Clears == 1, "not applied twice")
	leave(ida)
end)
step("both stores down: Unconfirmed, and the leave save still carries it", function()
	local jay = join(5302, "Jay")
	Mock.DataStoreFail = true
	local report = settleFinal(completion("srv:7", { cp(5302, 10, true, 60, { "a" }) }))
	check(report.ByUserId[5302].Status == "Unconfirmed", "honestly unconfirmed")
	Mock.DataStoreFail = false
	leave(jay)
	check(stored(5302) and stored(5302).TrophyRecords[TROPHY] ~= nil, "written by the leave save")
end)
step("eligible but not loaded here: durable outbox, applied on next load", function()
	local report = settleFinal(completion("srv:8", { cp(5303, 10, true, 60, { "a" }) }))
	check(report.ByUserId[5303].Status == "PendingRejoin" and outboxCount(5303) == 1, "pending rejoin")
	failStore(OUTBOX)
	local r2 = settleFinal(completion("srv:9", { cp(5304, 10, true, 60, { "a" }) }))
	failStore(nil)
	check(
		r2.ByUserId[5304].Status == "Refused" and r2.ByUserId[5304].Reason == "PendingWriteFailed",
		"write failure reported"
	)
	local retry = settleFinal(completion("srv:9", { cp(5304, 10, true, 60, { "a" }) }))
	check(retry.ByUserId[5304].Status == "PendingRejoin", "retry succeeds")
end)
step("outbox drain applies stages before the final", function()
	local s, final = intentsFor("srv:10", 5305)
	queue(5305, final)
	queue(5305, s.excavation)
	Mock.DataStores[STORE]["Player_5305"] = { Data = Config.NewPlayerData(), SavedAt = NOW }
	local start = Config.NewPlayerData().Coins
	local kit = join(5305, "Kit")
	Mock.Advance(1)
	check(DataService.Get(kit).Coins == start + 60, "6 + 54, never 66")
	check(outboxCount(5305) == 0 and stored(5305).Coins == start + 60, "saved and acknowledged")
	leave(kit)
end)
step("shutdown right after completion keeps the grant", function()
	join(5306, "Lou")
	noYield(Settlement.SettleCompletion, completion("srv:11", { cp(5306, 10, true, 60, { "a" }) }))
	Mock.RunBindToClose() -- before the immediate save had a chance to run
	Mock.Advance(5)
	local saved = stored(5306)
	check(saved and saved.TrophyRecords[TROPHY] ~= nil and saved.Cosmetics[STAND] ~= nil, "close save holds it")
	check(saved and saved.Certifications.cert_crew ~= nil, "cert too")
	check(Settlement.InFlight() == 0, "no writes left in flight")
end)
check(#Mock.Errors == 0, "server A: no uncaught errors (" .. #Mock.Errors .. ")")
for _, e in Mock.Errors do
	print("  error: " .. tostring(e))
end

-- Another server --------------------------------------------------------------------------------
section("another server (fresh mock game, shared DataStores)")
step("saved grants survive the old server and rejoin elsewhere", function()
	-- Server A settles, the save is written, then A dies without leave/close saves.
	local mia = join(5401, "Mia")
	local report = settleFinal(completion("srv:12", { cp(5401, 10, true, 60, { "a" }) }))
	check(report.ByUserId[5401].Status == "Saved", "saved on A")
	local coinsA = DataService.Get(mia).Coins
	DataService.Get(mia).Coins += 1 -- an unsaved later change dies with the crash
	Mock.Init(Generated) -- crash: no OnPlayerRemoving, no BindToClose
	-- The mock keeps one Players service across games; detach the dead server's player object
	-- silently (no PlayerRemoving, so nothing on A gets to save).
	mia.Parent = nil
	loadServer()
	-- The dead server's session lock is still in the record; mimic its expiry.
	Mock.DataStores[STORE]["Player_5401"].Lock = nil
	mia = join(5401, "Mia")
	check(DataService.Get(mia) ~= nil, "loaded on B")
	check(TrophyService.Owns(mia, TROPHY) == true and TrophyService.OwnsStand(mia) == true, "trophy + stand on B")
	check(Settlement.HasCertification(mia, "cert_crew") == true, "cert on B")
	check(DataService.Get(mia).Coins == coinsA, "exactly the saved coins")
	local again = settleFinal(completion("srv:12", { cp(5401, 10, true, 60, { "a" }) }))
	check(again.ByUserId[5401].Status == "Duplicate", "a replay on B is a duplicate")
end)
step("pending intents from server A are applied on server B", function()
	check(outboxCount(5303) == 1, "still queued from A")
	Mock.DataStores[STORE]["Player_5303"] = nil
	local ned = join(5303, "Ned")
	Mock.Advance(1)
	check(
		TrophyService.Owns(ned, TROPHY) == true and Settlement.HasCertification(ned, "cert_crew") == true,
		"applied on B"
	)
	check(outboxCount(5303) == 0 and stored(5303).Certifications.cert_crew ~= nil, "saved and acknowledged on B")
	leave(ned)
end)
step("crash between save and acknowledgement re-applies once", function()
	local _, final = intentsFor("srv:13", 5402)
	queue(5402, final)
	local d = Config.NewPlayerData()
	TrophyRules.Migrate(d, NOW)
	Rewards.Migrate(d, NOW)
	Rewards.Apply(d, final, NOW) -- the save was written, the ack never happened
	Mock.DataStores[STORE]["Player_5402"] = { Data = d, SavedAt = NOW }
	local coins = d.Coins
	local ola = join(5402, "Ola")
	Mock.Advance(1)
	check(DataService.Get(ola).Coins == coins, "not paid twice")
	check(DataService.Get(ola).AdventureProgress.Events.event_vault.Clears == 1, "one clear")
	check(outboxCount(5402) == 0, "acknowledged now")
	leave(ola)
end)
check(#Mock.Errors == 0, "server B: no uncaught errors (" .. #Mock.Errors .. ")")
for _, e in Mock.Errors do
	print("  error: " .. tostring(e))
end

print(string.format("ADVENTURE SETTLEMENT SPEC: %d passed, %d failed", passes, failures))
if failures > 0 then
	error("ADVENTURE SETTLEMENT SPEC FAILED")
end
