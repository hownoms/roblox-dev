--!nocheck
--[[
	Adversarial settlement audit through the REAL Main wiring (docs/integration/
	settlement-durability.md). Main.server.luau boots DataService, TrophyService,
	AdventureSettlement and AdventureBoot exactly as production does.

	  luau tests/settlement-durability.spec.luau          runtime ON (test-only, in memory)
	  luau tests/settlement-durability.spec.luau -a off   every flag OFF (the shipped default)

	Default mode flips AdventureFlags.SpringVault / AdventureRewards to true IN THIS TEST PROCESS
	ONLY, before Main runs (like production-wiring.spec -a on), so the real SpringVaultService
	drives the stage / completion boundary. Production supplies OnCompletion, so the runtime owns
	no reward copy ("External" outcome contract, docs/integration/runtime-input-handoff.md): it
	sends the neutral "Ball rescued." only to connected participants of the captured completion
	context, and each player's AdventureOutcome card is the only reward statement. The shipped
	flags stay false (checked first). Without Codex's runtime files the runtime part prints
	SKIPPED and only the direct-call durability checks run.

	MOCK COVERAGE ONLY. "DataStore" is the mock's in-memory UpdateAsync store driven through the
	real DataService / DurableOutbox code; "another server" is a session that stole a stale lock,
	simulated on the shared mock record. None of this proves live Roblox persistence, live
	throttling, a real BindToClose or real cross-server rejoin (see the live test plan).
]]

local Mock = require("./mock/Roblox")
local Generated = require("../build/test/generated")
local mode = ({ ... })[1] or "on"
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

local byPath = Mock.ByPath
local function load(path)
	return Mock.Require(byPath[path])
end
local V, CF = Mock.Vector3, Mock.CFrame
local Config = load("ReplicatedStorage/Shared/Config")
for _, category in { Config.Monetization.GamePasses, Config.Monetization.Products, Config.Badges } do
	for _, item in category do
		item.Id = 0
	end
end
local S = Config.SURFACE_Y
local STORE = Config.DATASTORE_NAME
local OUTBOX, TROPHY_OUTBOX = "AdventureRewardIntents_v1", "TrophyPendingGrants_v1"
local TROPHY, STAND = "landmark_spring_vault", "camp_trophy_stand"
local hasRuntime = byPath["ServerScriptService/Server/Adventure/SpringVaultService"] ~= nil
	and byPath["ServerScriptService/Server/Adventure/SpringVaultState"] ~= nil

local function seed(userId, mutate)
	local data = Config.NewPlayerData()
	data.Version = Config.DATA_VERSION
	data.Certifications = { cert_rookie = { At = 1, Source = "test" } } -- admitted by Mara
	if mutate then
		mutate(data)
	end
	Mock.DataStores[STORE] = Mock.DataStores[STORE] or {}
	Mock.DataStores[STORE]["Player_" .. userId] = { Data = data, SavedAt = 1 }
end
local function stored(userId)
	local record = Mock.DataStores[STORE] and Mock.DataStores[STORE]["Player_" .. userId]
	return record and record.Data
end
local function outboxOf(name, userId)
	local store = Mock.DataStores[name]
	local record = store and store["Pending_" .. userId]
	return if record then record.Grants else {}
end
local function seedOutbox(name, userId, receiptId, entry)
	Mock.DataStores[name] = Mock.DataStores[name] or {}
	local record = Mock.DataStores[name]["Pending_" .. userId] or { Grants = {} }
	record.Grants[receiptId] = entry
	Mock.DataStores[name]["Pending_" .. userId] = record
end

-- Fault injection: faults[storeName] or faults[storeName .. "/" .. key] = true (always) or a
-- number (fail that many more calls). Applies to UpdateAsync, which every path here uses.
local faults = {}
Mock.BeforeDataStoreUpdate = function(storeName, key)
	for _, id in { storeName .. "/" .. key, storeName } do
		local f = faults[id]
		if f == true then
			error("502: mock " .. id .. " outage")
		elseif type(f) == "number" and f > 0 then
			faults[id] = f - 1
			error("502: mock " .. id .. " transient failure")
		end
	end
end

-- Boot -------------------------------------------------------------------------------------------
local Flags = load("ServerScriptService/Server/Services/AdventureFlags")
check(
	Flags.SpringVault == false and Flags.AdventureRewards == false and Flags.BroadwaveOrdinary == false,
	"every adventure flag ships OFF"
)
local runtimeOn = mode ~= "off" and hasRuntime
if runtimeOn then
	-- test process only (see header); BroadwaveOrdinary stays off
	Flags.SpringVault, Flags.AdventureRewards = true, true
end

-- Crew for the runtime-driven run, with possessions that settlement must never touch.
local A, B, C, D, E, F = 9501, 9502, 9503, 9504, 9505, 9506
local petId = Config.Pets[1].Id
local shovelId
for _, def in Config.Shovels do
	if def.Price > 0 then
		shovelId = def.Id
		break
	end
end
seed(A, function(d)
	d.Coins = 1000 -- coins from elsewhere
	d.OwnedShovels[shovelId] = true
	d.Pets = { ["pet-uid-a"] = { Id = petId, Equipped = false } }
	d.Cosmetics = { hat_sunhat = { Kind = "Hat", Source = "shop", AcquiredAt = 5 } }
	d.ToolLicenses = { tool_broadwave = { At = 7, Source = "owner" } }
	d.Quests = { daily_sell_10 = { Progress = 3, Claimed = false, Day = 1 } }
	d.RewardReceipts = { ["quest:other:1"] = 123, ["trophy:old-run:9501:final:v1"] = os.time() }
end)
for _, id in { B, C, D, E, F } do
	seed(id)
end

Mock.RunScript(byPath["ServerScriptService/Server/Main"])
Mock.Advance(1)
check(#Mock.Errors == 0, "Main boots")
local P = "ServerScriptService/Server/Services/"
local DataService = load(P .. "DataService")
local TrophyService = load(P .. "TrophyService")
local Settlement = load(P .. "AdventureSettlement")
local Boot = load(P .. "AdventureBoot")
local Display = load(P .. "TrophyCampDisplay")
local Rewards = load("ReplicatedStorage/Shared/Rewards/AdventureRewards")
Settlement.RetryDelays = { 1, 1, 1 } -- shortened so retries happen inside the test

-- Invariant monitor (whole spec, every mode): at the moment an outcome reaches a player, an
-- "Accepted" one must already be durable (its adv:/trophy: part in the written save or in its
-- outbox), and a Pending/Refused one carries a non-durable status. Pending/Refused are never
-- presented as a grant (the client card, adventure-outcome.spec, enforces the wording).
local DURABLE = { Saved = true, Queued = true, Duplicate = true }
local NOT_DURABLE =
	{ Pending = { Unconfirmed = true, PendingRejoin = true }, Refused = { Ineligible = true, Refused = true } }
local monitored = { Accepted = 0, Pending = 0, Refused = 0 }
local function hasPrefix(t, prefix)
	for key in t or {} do
		if type(key) == "string" and string.sub(key, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end
Settlement.OutcomeSent:Connect(function(player, outcome)
	local uid = player.UserId
	monitored[outcome.State] = (monitored[outcome.State] or 0) + 1
	local tag = string.format("%d %s %s/%s", uid, tostring(outcome.InstanceId), outcome.Kind, outcome.Status)
	if outcome.State ~= "Accepted" then
		check(
			NOT_DURABLE[outcome.State] ~= nil and NOT_DURABLE[outcome.State][outcome.Status] == true,
			"monitor: " .. outcome.State .. " carries a non-durable status (" .. tag .. ")"
		)
		return
	end
	check(DURABLE[outcome.Status] == true, "monitor: Accepted only for a durable status (" .. tag .. ")")
	if outcome.Status == "Duplicate" then
		return -- already settled earlier; nothing new is claimed
	end
	local saved = stored(uid)
	if outcome.Coins > 0 or outcome.Certification then
		local prefix = "adv:" .. outcome.InstanceId .. ":" .. uid .. ":"
		check(
			hasPrefix(saved and saved.RewardReceipts, prefix) or hasPrefix(outboxOf(OUTBOX, uid), prefix),
			"monitor: Accepted coins/cert are durable when told (" .. tag .. ")"
		)
	end
	if outcome.Trophy or outcome.Stand then
		local prefix = "trophy:" .. outcome.InstanceId .. ":" .. uid .. ":"
		check(
			hasPrefix(saved and saved.RewardReceipts, prefix) or hasPrefix(outboxOf(TROPHY_OUTBOX, uid), prefix),
			"monitor: Accepted trophy/stand is durable when told (" .. tag .. ")"
		)
	end
end)

-- Boundary contract capture: what the REAL runtime hands the adapter (OnStage / OnCompletion
-- call SettleStage / SettleCompletion through the module table, so wrapping them sees every
-- context unchanged).
local capturedStages, capturedFinals = {}, {}
do
	local realStage, realFinal = Settlement.SettleStage, Settlement.SettleCompletion
	Settlement.SettleStage = function(observation)
		table.insert(capturedStages, observation)
		return realStage(observation)
	end
	Settlement.SettleCompletion = function(context)
		table.insert(capturedFinals, context)
		return realFinal(context)
	end
end
local settledReports = {}
Settlement.Settled:Connect(function(report)
	table.insert(settledReports, report)
end)

local function add(userId, name, position)
	local p = Mock.AddPlayer(userId, name)
	Mock.Advance(2)
	Mock.SpawnCharacter(p, position or V.new(0, S + 3, 4))
	Mock.Advance(0.5)
	return p
end
local function outcomesFor(userId, since)
	local list = {}
	for i = (since or 0) + 1, #Mock.Remote.ToClient do
		local e = Mock.Remote.ToClient[i]
		if e.Name == "AdventureOutcome" and e.Player.UserId == userId then
			table.insert(list, e.Args[1])
		end
	end
	return list
end
local function lastSnapshot(player, since)
	local found
	for i = (since or 0) + 1, #Mock.Remote.ToClient do
		local e = Mock.Remote.ToClient[i]
		if e.Name == "Snapshot" and e.Player == player and type(e.Args[1]) == "table" and e.Args[1].message then
			found = e.Args[1]
		end
	end
	return found
end
local function inThread(fn, ...)
	local args = table.pack(...)
	local out, done = nil, false
	Mock.Env.task.spawn(function()
		out = table.pack(fn(table.unpack(args, 1, args.n)))
		done = true
	end)
	for _ = 1, 400 do
		if done then
			break
		end
		Mock.Advance(0.25)
	end
	assert(done, "call did not finish")
	return table.unpack(out, 1, out.n)
end
-- The runtime's neutral completion line under the External outcome contract, and every line
-- the runtime or a completion callback could send as completion feedback.
local RUNTIME_COMPLETION = "Ball rescued."
local function isCompletionLine(text)
	return text == RUNTIME_COMPLETION
		or text == "Completion handoff failed; no rewards confirmed."
		or text == "Adventure complete. Rewards are not enabled on this server."
		or (type(text) == "string" and string.find(text, "Adventure complete", 1, true) ~= nil)
end
-- Completion lines a player received since `since`, in order.
local function completionMessages(player, since)
	local out = {}
	for i = (since or 0) + 1, #Mock.Remote.ToClient do
		local e = Mock.Remote.ToClient[i]
		local data = e.Args and e.Args[1]
		if e.Name == "Snapshot" and e.Player == player and type(data) == "table" and isCompletionLine(data.message) then
			table.insert(out, data.message)
		end
	end
	return out
end
-- A broadcast is true for every recipient only if it claims nothing about anyone's reward.
local function claimsReward(text)
	local t = string.lower(text or "")
	return string.find(t, "on their way", 1, true) ~= nil
		or string.find(t, "saved", 1, true) ~= nil
		or string.find(t, "granted", 1, true) ~= nil
		or string.find(t, "collection", 1, true) ~= nil
end

local function stageContext(instanceId, stageId, participants)
	local completed = {}
	for _, id in { "excavation", "vault_open", "ball_return" } do
		table.insert(completed, id)
		if id == stageId then
			break
		end
	end
	return table.freeze({
		BoundaryVersion = 1,
		EventInstanceId = instanceId,
		EventId = "event_vault",
		LandmarkId = TROPHY,
		RegionId = "sunshine_shore",
		StageId = stageId,
		ObjectiveIds = {},
		CompletedStages = completed,
		Participants = participants,
	})
end
local function finalContext(instanceId, participants)
	return table.freeze({
		BoundaryVersion = 1,
		EventInstanceId = instanceId,
		EventId = "event_vault",
		LandmarkId = TROPHY,
		RegionId = "sunshine_shore",
		Success = true,
		ObjectiveIds = { "vault_anchor_1" },
		CompletedStages = { "excavation", "vault_open", "ball_return" },
		Participants = participants,
	})
end
local function obs(userId, points)
	return { UserId = userId, Points = points, ObjectiveIds = {}, Connected = true, Left = false }
end
local function cp(userId, points, eligible)
	return {
		UserId = userId,
		Points = points,
		Eligible = eligible ~= false,
		ActiveSeconds = 90,
		ObjectiveIds = { "vault_anchor_1" },
	}
end

-- 1. Truthful outcomes through the real runtime ---------------------------------------------
if runtimeOn then
	section("real runtime: crew run with watcher, late helper, disconnect and bystander")
	step("crew run", function()
		local runtime = Boot.Runtime()
		check(runtime ~= nil, "runtime started by Main (flags on in this process)")
		local scene = runtime.Scene
		local mara = scene.Targets.npc_mara
		local inArena = scene.Origin + V.new(0, 3, -36)
		local function place(p, pos)
			p.Character:PivotTo(CF.new(pos + V.new(0, 3, 2)))
		end
		local pa = add(A, "Ana", mara)
		local pb = add(B, "Ben", mara)
		local pd = add(D, "Dee", mara)
		local pe = add(E, "Eli") -- bystander: loaded, never joins
		local before = {}
		for _, key in { "OwnedShovels", "Pets", "ToolLicenses", "Settings", "Quests", "FindVariants" } do
			before[key] = deepCopy(DataService.Get(pa)[key])
		end
		local coins0 = DataService.Get(pa).Coins
		check(coins0 == 1000, "A's coins from elsewhere loaded (" .. tostring(coins0) .. ")")
		for _, p in { pa, pb, pd } do
			place(p, mara)
			runtime.Handle(p, { action = "Join", eventInstanceId = "" })
			Mock.Advance(0.2)
		end
		local e = runtime.Event()
		check(e ~= nil and count(e.Participants) == 3, "A, B and D joined through Mara")
		for _, p in { pa, pb, pd } do
			place(p, inArena)
		end
		Mock.Advance(6)
		check(e:start(A, Mock.Now()) == true, "starter starts")
		for _, id in { A, B, D } do
			e:ready(id, Mock.Now())
		end
		Mock.Advance(0.5)
		check(e.Phase == "Active", "crew active (" .. tostring(e.Phase) .. ")")
		local mark = #Mock.Remote.ToClient
		for _, anchorId in { "vault_anchor_1", "vault_anchor_2", "vault_anchor_3" } do
			local guard = 0
			while not e.Anchors[anchorId].Completed and guard < 40 do
				guard += 1
				e:hitAnchor(A, anchorId, Mock.Now())
				if anchorId == "vault_anchor_1" then
					e:hitAnchor(D, anchorId, Mock.Now())
				end
				Mock.Advance(0.5)
			end
		end
		Mock.Advance(2)
		check(table.find(e.CompletedStages, "excavation") ~= nil, "excavation done")
		local a1, b1, d1 = outcomesFor(A, mark), outcomesFor(B, mark), outcomesFor(D, mark)
		check(#a1 == 1 and a1[1].State == "Accepted" and a1[1].Coins == 6, "A: excavation +6 accepted")
		check(
			#b1 == 1 and b1[1].State == "Refused" and b1[1].Reason == "NoContribution",
			"watcher B: excavation refused, no contribution"
		)
		check(#d1 == 1 and d1[1].State == "Accepted" and d1[1].Coins == 6, "D: excavation +6 accepted")
		check(#outcomesFor(E, mark) == 0, "bystander gets no outcome")

		-- D disconnects (held by the runtime, never returns); C joins late and helps.
		Mock.RemovePlayer(pd)
		Mock.Advance(1)
		local pc = add(C, "Cal", mara)
		place(pc, mara)
		runtime.Handle(pc, { action = "Join", eventInstanceId = "" })
		Mock.Advance(0.2)
		e:ready(C, Mock.Now())
		place(pc, inArena)
		Mock.Advance(0.5)
		check(e.Participants[C] ~= nil, "late helper C joined")
		local mark2 = #Mock.Remote.ToClient
		-- vault + all three gates in one frame: the next Heartbeat reports both stages and the
		-- completion through Main's wiring.
		check(e:openVault(C, Mock.Now()) == true, "C opens the vault")
		for _, gate in { "ball_gate_1", "ball_gate_2", "ball_gate_3" } do
			e:advanceBallGate(gate, Mock.Now(), { [A] = 1, [C] = 1 })
		end
		check(e.Phase == "Resolving", "run resolving")
		Mock.Advance(3)
		check(runtime.Settled == true, "runtime recorded the completion as accepted")

		-- Per-player truth table
		local a2 = outcomesFor(A, mark2)
		local final = a2[#a2]
		check(#a2 == 3, "A: vault, ball and final outcomes (" .. #a2 .. ")")
		check(
			final
				and final.Kind == "Final"
				and final.State == "Accepted"
				and final.Status == "Saved"
				and final.Coins == 42
				and final.Trophy
				and final.Stand
				and final.Certification == "cert_crew",
			"A: final +42 (60 - 3 stages), trophy, stand, cert, saved"
		)
		check(
			DataService.StorageMode() == "DataStore" and final and final.Storage == nil,
			"durable store: the card carries no local-storage label (" .. tostring(final and final.Storage) .. ")"
		)
		check(DataService.Get(pa).Coins == coins0 + 60, "A: exactly 60 for the run, coins from elsewhere kept")
		check(stored(A).Coins == coins0 + 60, "A: the store holds the same total")
		local c2 = outcomesFor(C, mark2)
		check(#c2 == 3, "late helper: vault, ball, final (" .. #c2 .. ")")
		check(
			c2[3] and c2[3].Kind == "Final" and c2[3].State == "Accepted" and c2[3].Coins == 48,
			"late helper: final +48 so the run totals 60"
		)
		check(DataService.Get(pc).Coins == 60, "late helper: 60 in total")
		local b2 = outcomesFor(B, mark2)
		check(#b2 == 3, "watcher: vault, ball, final outcomes (" .. #b2 .. ")")
		check(
			b2[3] and b2[3].Kind == "Final" and b2[3].State == "Refused" and b2[3].Reason == "LowContribution",
			"watcher who stayed to the finish is told they didn't contribute ("
				.. tostring(b2[3] and b2[3].Reason)
				.. ")"
		)
		check(DataService.Get(pb).Coins == 0 and TrophyService.Owns(pb, TROPHY) == false, "watcher: nothing granted")
		check(#outcomesFor(E, mark2) == 0, "bystander: no outcome")
		check(stored(D).Coins == 6, "disconnected D: the stage coins they earned are saved, no final")
		check(stored(D).TrophyRecords == nil or stored(D).TrophyRecords[TROPHY] == nil, "disconnected D: no trophy")

		-- External outcome contract: completion feedback goes only to connected participants of
		-- the captured context (A, the watcher B and the late helper C; D left), and it is the
		-- neutral "Ball rescued.". OnCompletion's own summary is never shown as anyone's result:
		-- B was refused while A and C were paid, so one shared line cannot be true for all three.
		for _, p in { pa, pb, pc } do
			local said = completionMessages(p, mark2)
			check(
				#said == 1 and said[1] == RUNTIME_COMPLETION,
				p.Name .. ": one neutral completion message (" .. table.concat(said, " | ") .. ")"
			)
			check(#said > 0 and not claimsReward(said[1]), p.Name .. ": the completion message claims no reward")
		end
		check(#completionMessages(pe, mark2) == 0, "never-joined bystander Eli: no completion message")
		for _, p in { pa, pb, pc, pe } do
			for _, line in completionMessages(p, mark2) do
				check(
					line ~= Settlement.COMPLETION_MESSAGE and line ~= Settlement.REFUSED_MESSAGE,
					p.Name .. ": the settlement summary is not presented as their result"
				)
			end
		end
		-- What each client sees from the RUNTIME after the completion (status message, objective
		-- line, objectives list) next to its own final card. The card is the only per-player
		-- reward statement, so no runtime line may say the run grants nothing (old blocker B1).
		local finals = { [A] = final, [B] = b2[3], [C] = c2[3] }
		local reviewCopy = {}
		for _, p in { pa, pb, pc, pe } do
			for i = mark2 + 1, #Mock.Remote.ToClient do
				local ev = Mock.Remote.ToClient[i]
				local snap = ev.Args and ev.Args[1]
				if ev.Name == "Snapshot" and ev.Player == p and type(snap) == "table" and snap.phase == "Resolving" then
					local texts = { snap.message, snap.objective }
					for _, line in (if type(snap.objectives) == "table" then snap.objectives else {}) do
						table.insert(texts, line)
					end
					for _, line in texts do
						local lower = string.lower(tostring(line))
						if
							string.find(lower, "review only", 1, true)
							or string.find(lower, "no permanent", 1, true)
							or string.find(lower, "no coins", 1, true)
						then
							reviewCopy[p.Name .. "|" .. tostring(line)] = { Player = p, Line = line }
						end
					end
				end
			end
		end
		local contradictions = 0
		local copyKeys = {}
		for key in reviewCopy do
			table.insert(copyKeys, key)
		end
		table.sort(copyKeys)
		for _, key in copyKeys do
			local item = reviewCopy[key]
			local card = finals[item.Player.UserId]
			local cardText = if card then card.State .. "/" .. card.Status else "no card"
			if card and card.State == "Accepted" then
				contradictions += 1
				print(
					string.format(
						"BLOCKER B1 (runtime copy): %s card %s, runtime shows %q",
						item.Player.Name,
						cardText,
						item.Line
					)
				)
			end
		end
		print(string.format("  runtime review copy contradicting an Accepted card: %d line(s)", contradictions))
		check(contradictions == 0, "production shows no review-only copy next to an Accepted card")
		check(count(reviewCopy) == 0, "production shows no review-only copy to anyone after completion")
		check(
			Boot.Options(Flags).OutcomeOwner == "External",
			"rewards on: the runtime is told an external outcome card owns reward copy"
		)

		-- Boundary contract against the real runtime (fields AdventureSettlement and
		-- TrophyService.PrepareCompletionContext read; PR #35 must not have drifted them).
		local def = Rewards.Events.event_vault
		local function fieldsOk(t, spec)
			for key, kind in spec do
				if type(t[key]) ~= kind then
					return false, key
				end
			end
			return true, nil
		end
		local HEAD = {
			BoundaryVersion = "number",
			EventInstanceId = "string",
			EventId = "string",
			LandmarkId = "string",
			RegionId = "string",
			CompletedStages = "table",
			Participants = "table",
		}
		local STAGE_P =
			{ UserId = "number", Points = "number", ObjectiveIds = "table", Connected = "boolean", Left = "boolean" }
		local FINAL_P = {
			UserId = "number",
			Points = "number",
			ObjectiveIds = "table",
			Eligible = "boolean",
			ActiveSeconds = "number",
		}
		local function contract(context, kind)
			local ok, missing = fieldsOk(context, HEAD)
			check(ok, kind .. " context carries every field the adapter reads (missing " .. tostring(missing) .. ")")
			check(
				context.BoundaryVersion == def.BoundaryVersion
					and context.EventId == def.EventId
					and context.LandmarkId == def.LandmarkId
					and context.RegionId == def.RegionId,
				kind .. " context matches the reward table's boundary version, event, landmark and region"
			)
			check(table.isfrozen(context) and table.isfrozen(context.Participants), kind .. " context is frozen")
			for _, participant in context.Participants do
				local pOk, pMissing = fieldsOk(participant, if kind == "Stage" then STAGE_P else FINAL_P)
				check(pOk, kind .. " participant " .. tostring(participant.UserId) .. " field " .. tostring(pMissing))
			end
		end
		local stageIds = {}
		for _, observation in capturedStages do
			if observation.EventInstanceId == e.EventInstanceId then
				contract(observation, "Stage")
				check(type(observation.StageId) == "string", "stage observation names its stage")
				table.insert(stageIds, observation.StageId)
			end
		end
		table.sort(stageIds)
		check(
			table.concat(stageIds, ",") == "ball_return,excavation,vault_open",
			"the runtime reported each stage exactly once (" .. table.concat(stageIds, ",") .. ")"
		)
		local runFinals = {}
		for _, context in capturedFinals do
			if context.EventInstanceId == e.EventInstanceId then
				table.insert(runFinals, context)
			end
		end
		check(#runFinals == 1, "the runtime handed over exactly one completion context")
		if runFinals[1] then
			contract(runFinals[1], "Final")
			check(runFinals[1].Success == true, "completion context says Success")
			check(runFinals[1] == runtime.LastCompletion, "the adapter saw the runtime's own frozen context")
		end
		local finalReport
		for _, report in settledReports do
			if report.InstanceId == e.EventInstanceId then
				check(
					report.Ok,
					report.Kind .. " " .. tostring(report.StageId) .. " settled Ok (" .. tostring(report.Error) .. ")"
				)
				if report.Kind == "Final" then
					finalReport = report
				end
			end
		end
		check(
			finalReport ~= nil
				and finalReport.Trophy ~= nil
				and finalReport.Trophy.Ok
				and finalReport.Trophy.ByUserId[A].Status == "Granted"
				and finalReport.Trophy.ByUserId[C].Status == "Granted"
				and finalReport.Trophy.ByUserId[B].Status == "Ineligible",
			"TrophyService.PrepareCompletionContext accepts the real context: A and C granted, watcher ineligible"
		)

		-- Possessions and unrelated fields
		local data = DataService.Get(pa)
		for key, value in before do
			check(deepEqual(data[key], value), "A's " .. key .. " untouched by settlement")
		end
		check(
			data.Cosmetics.hat_sunhat ~= nil and data.Cosmetics[STAND] ~= nil,
			"A's other cosmetic kept beside the stand"
		)
		check(data.RewardReceipts["quest:other:1"] == 123, "unrelated receipt namespace untouched")
		check(data.RewardReceipts["trophy:old-run:9501:final:v1"] ~= nil, "older trophy receipt kept")
		check(data.Certifications.cert_rookie ~= nil, "existing certification kept")
		Mock.Advance(13) -- the runtime cleans up and resets
	end)

	section("real runtime: failed run keeps stage coins, grants no final")
	step("abandoned run", function()
		local runtime = Boot.Runtime()
		local scene = runtime.Scene
		local mara = scene.Targets.npc_mara
		check(runtime.Event() == nil, "previous run reset")
		local pf = add(F, "Fin", mara)
		pf.Character:PivotTo(CF.new(mara + V.new(0, 3, 2)))
		runtime.Handle(pf, { action = "Join", eventInstanceId = "" })
		Mock.Advance(6)
		local e = runtime.Event()
		e:start(F, Mock.Now())
		e:ready(F, Mock.Now())
		Mock.Advance(0.5)
		local mark = #Mock.Remote.ToClient
		for _, anchorId in { "vault_anchor_1", "vault_anchor_2", "vault_anchor_3" } do
			local guard = 0
			while not e.Anchors[anchorId].Completed and guard < 40 do
				guard += 1
				e:hitAnchor(F, anchorId, Mock.Now())
				Mock.Advance(0.5)
			end
		end
		Mock.Advance(1)
		pf.Character:PivotTo(CF.new(0, S + 3, 4)) -- walks away: the run is abandoned
		Mock.Advance(35)
		check(runtime.LastFailure ~= nil and runtime.LastFailure.FailureReason == "abandoned", "run failed (abandoned)")
		local list = outcomesFor(F, mark)
		check(#list == 1 and list[1].Kind == "Stage" and list[1].State == "Accepted", "only the stage outcome")
		check(DataService.Get(pf).Coins == 6 and stored(F).Coins == 6, "stage coins kept and saved")
		check(TrophyService.Owns(pf, TROPHY) == false, "no trophy on failure")
		check(Settlement.HasCertification(pf, "cert_crew") == false, "no cert on failure")
		local progress = Settlement.GetProgress(pf, "event_vault")
		check(progress == nil or (progress.Clears or 0) == 0, "no clear recorded on failure")
	end)

	section("real runtime with AdventureRewards OFF (SpringVault on): production run, nothing granted")
	step("rewards-off run", function()
		Mock.Advance(2)
		Boot.Disable()
		Flags.AdventureRewards = false -- test process only; restored below
		Boot.Start()
		local runtime = Boot.Runtime()
		check(runtime ~= nil, "runtime restarted with rewards off")
		-- Boot sets no explicit OutcomeOwner with rewards off, but it still supplies its refusal
		-- OnCompletion, so the runtime infers external ownership: this is a production run with
		-- rewards disabled, not Codex's dedicated review adapter.
		local offOptions = Boot.Options(Flags)
		check(offOptions.OutcomeOwner == nil, "rewards off: boot sets no explicit OutcomeOwner")
		check(type(offOptions.OnCompletion) == "function", "rewards off: boot supplies the refusal OnCompletion")
		check(offOptions.OnStage == nil, "rewards off: no stage settlement callback")
		local G = 9507
		seed(G)
		local scene = runtime.Scene
		local mara = scene.Targets.npc_mara
		local pg = add(G, "Gus", mara)
		pg.Character:PivotTo(CF.new(mara + V.new(0, 3, 2)))
		runtime.Handle(pg, { action = "Join", eventInstanceId = "" })
		Mock.Advance(0.2)
		pg.Character:PivotTo(CF.new(scene.Origin + V.new(0, 6, -34)))
		Mock.Advance(6)
		local e = runtime.Event()
		check(e ~= nil and e:start(G, Mock.Now()) == true, "solo start")
		e:ready(G, Mock.Now())
		Mock.Advance(0.5)
		local mark = #Mock.Remote.ToClient
		local reports = #settledReports
		for _, anchorId in { "vault_anchor_1", "vault_anchor_2", "vault_anchor_3" } do
			local guard = 0
			while not e.Anchors[anchorId].Completed and guard < 40 do
				guard += 1
				e:hitAnchor(G, anchorId, Mock.Now())
				Mock.Advance(0.5)
			end
		end
		check(e:openVault(G, Mock.Now()) == true, "vault opened")
		for _, gate in { "ball_gate_1", "ball_gate_2", "ball_gate_3" } do
			e:advanceBallGate(gate, Mock.Now(), { [G] = 1 })
		end
		Mock.Advance(3)
		check(e.Phase == "Resolving" and runtime.Settled == false, "completion handed over and refused")
		check(#settledReports == reports, "no settlement ran (stage or final)")
		local cards = 0
		for i = mark + 1, #Mock.Remote.ToClient do
			if Mock.Remote.ToClient[i].Name == "AdventureOutcome" then
				cards += 1
			end
		end
		check(cards == 0, "no outcome card for anyone (" .. cards .. ")")
		-- Only Gus took part: he gets the neutral completion line and nothing that claims a
		-- reward; every other connected player (none joined this run) gets no completion line.
		local said = completionMessages(pg, mark)
		check(
			#said == 1 and said[1] == RUNTIME_COMPLETION and not claimsReward(said[1]),
			"Gus (the only participant): neutral completion, nothing claimed (" .. table.concat(said, " | ") .. ")"
		)
		local others = 0
		for _, p in Mock.Env.game:GetService("Players"):GetPlayers() do
			if p ~= pg then
				others += 1
				check(#completionMessages(p, mark) == 0, p.Name .. " (not in this run): no completion message")
			end
		end
		check(others >= 5, "the other connected players were checked (" .. others .. ")")
		local offCopy = 0
		for i = mark + 1, #Mock.Remote.ToClient do
			local ev = Mock.Remote.ToClient[i]
			local data = ev.Args and ev.Args[1]
			if ev.Name == "Snapshot" and type(data) == "table" then
				for _, line in (if type(data.objectives) == "table" then data.objectives else {}) do
					if string.find(string.lower(tostring(line)), "review only", 1, true) then
						offCopy += 1
					end
				end
			end
		end
		check(offCopy == 0, "rewards off: no dedicated-review copy in production snapshots (" .. offCopy .. ")")
		local snap = lastSnapshot(pg, mark)
		print("  rewards off, runtime objective after completion: " .. tostring(snap and snap.objective))
		check(DataService.Get(pg).Coins == 0 and stored(G).Coins == 0, "no coins granted")
		check(TrophyService.Owns(pg, TROPHY) == false, "no trophy granted")
		check(Settlement.HasCertification(pg, "cert_crew") == false, "no certification granted")
		Mock.Advance(13)
		Boot.Disable()
		Flags.AdventureRewards = true
		Boot.Start()
		check(Boot.Runtime() ~= nil, "runtime restored with rewards on for the rest of the spec")
	end)
elseif mode ~= "off" then
	print("SKIPPED runtime part (Spring Vault gameplay files absent)")
end

-- 2. Durability through Main's services (direct boundary calls) -----------------------------
section("trophy display failure cannot abort a settlement")
step("display throws during the grant", function()
	local id = 9511
	seed(id)
	local p = add(id, "Gil")
	local realShow = Display.Show
	Display.Show = function()
		error("camp display exploded")
	end
	local ok, accepted, message = pcall(Settlement.OnCompletion, finalContext("dur:1", { cp(id, 20) }))
	Display.Show = realShow
	check(ok, "OnCompletion does not throw into the runtime (" .. tostring(accepted) .. ")")
	check(accepted == true and message == Settlement.COMPLETION_MESSAGE, "completion accepted")
	Mock.Advance(2)
	local list = outcomesFor(id)
	local final = list[#list]
	check(
		final and final.State == "Accepted" and final.Status == "Saved" and final.Coins == 60 and final.Trophy,
		"player told +60 and the trophy, saved"
	)
	check(stored(id).TrophyRecords[TROPHY] ~= nil and stored(id).Coins == 60, "trophy and coins in the store")
	-- the trophy drain is not wedged by the earlier throw
	seedOutbox(TROPHY_OUTBOX, id, "trophy:dur:1b:" .. id .. ":final:v1", {
		TrophyId = TROPHY,
		Source = "event_vault",
		RegionId = "sunshine_shore",
		At = os.time(),
	})
	Mock.Env.task.spawn(Settlement.Drain, p)
	Mock.Advance(2)
	check(count(outboxOf(TROPHY_OUTBOX, id)) == 0, "a later trophy drain still runs and acknowledges")
end)
step("a throw in the whole trophy part still settles coins and cert truthfully", function()
	local id = 9518
	seed(id)
	local p = add(id, "Quin")
	local realPrepare = TrophyService.PrepareCompletionContext
	TrophyService.PrepareCompletionContext = function()
		error("trophy settlement exploded")
	end
	local ok, accepted = pcall(Settlement.OnCompletion, finalContext("dur:1d", { cp(id, 20) }))
	TrophyService.PrepareCompletionContext = realPrepare
	Mock.Advance(2)
	check(ok and accepted == true, "completion still accepted for the coins and cert")
	local list = outcomesFor(id)
	local final = list[#list]
	check(
		final
			and final.State == "Accepted"
			and final.Coins == 60
			and final.Trophy == false
			and final.Reason == "TrophyUnavailable",
		"told +60 and cert, and that the trophy is unavailable (" .. tostring(final and final.Reason) .. ")"
	)
	check(TrophyService.Owns(p, TROPHY) == false and stored(id).Coins == 60, "no phantom trophy; coins saved")
end)
step("a throw inside the trophy drain does not wedge later drains", function()
	local id = 9517
	seed(id)
	local p = add(id, "Pia")
	local Pending = load(P .. "TrophyPendingStore")
	local realRead = Pending.Read
	Pending.Read = function()
		error("outbox decode exploded")
	end
	seedOutbox(TROPHY_OUTBOX, id, "trophy:dur:1c:" .. id .. ":final:v1", {
		TrophyId = TROPHY,
		Source = "event_vault",
		RegionId = "sunshine_shore",
		At = os.time(),
	})
	Mock.Env.task.spawn(Settlement.Drain, p)
	Mock.Advance(0.5)
	Pending.Read = realRead
	Mock.Advance(4) -- the in-session retry runs the drain again
	check(TrophyService.Owns(p, TROPHY) == true, "the grant is applied by the next drain")
	check(count(outboxOf(TROPHY_OUTBOX, id)) == 0, "and acknowledged")
end)

section("drain retries: unreadable outbox and failed drain save")
step("outbox unreadable at load, retried in-session", function()
	local id = 9512
	seed(id)
	local intent = {
		Kind = "Stage",
		UserId = id,
		EventId = "event_vault",
		InstanceId = "dur:2",
		StageId = "excavation",
		RewardVersion = 1,
		Coins = 6,
		StageCoins = 6,
		At = os.time(),
	}
	seedOutbox(OUTBOX, id, Rewards.ReceiptFor(intent), intent)
	faults[OUTBOX .. "/Pending_" .. id] = 3 -- every attempt of the read at load fails
	local p = add(id, "Hal")
	check(DataService.Get(p).Coins == 0, "nothing applied while the outbox is unreadable")
	Mock.Advance(4)
	check(DataService.Get(p).Coins == 6, "the retry applies the queued stage coins this session")
	check(count(outboxOf(OUTBOX, id)) == 0, "and acknowledges them")
	local list = outcomesFor(id)
	check(#list == 1 and list[1].Resolved == true and list[1].Coins == 6, "one Resolved outcome, +6")
end)
step("drain save fails, retry acknowledges and still tells the player", function()
	local id = 9513
	seed(id)
	local intent = {
		Kind = "Final",
		UserId = id,
		EventId = "event_vault",
		InstanceId = "dur:3",
		RewardVersion = 1,
		Coins = 60,
		StageCoins = 6,
		At = os.time(),
	}
	seedOutbox(OUTBOX, id, Rewards.ReceiptFor(intent), intent)
	local key = STORE .. "/Player_" .. id
	local loads = 0
	local realHook = Mock.BeforeDataStoreUpdate
	Mock.BeforeDataStoreUpdate = function(storeName, k)
		if storeName .. "/" .. k == key then
			loads += 1
			if loads >= 2 and loads <= 5 then -- the load passes, the drain's save (4 attempts) fails
				error("502: mock save failure")
			end
		end
		realHook(storeName, k)
	end
	local p = add(id, "Ida")
	Mock.Advance(25)
	Mock.BeforeDataStoreUpdate = realHook
	Mock.Advance(5)
	check(DataService.Get(p).Coins == 60, "applied once")
	check(count(outboxOf(OUTBOX, id)) == 0, "acknowledged after the retry's save")
	local resolved = 0
	for _, o in outcomesFor(id) do
		if o.Resolved and o.Kind == "Final" and o.Coins == 60 and o.Certification == "cert_crew" then
			resolved += 1
		end
	end
	check(resolved == 1, "exactly one Resolved outcome with the coins and cert (" .. resolved .. ")")
end)

section("outbox acknowledgement keeps intents from a newer server version")
step("unknown-but-live entries survive, dead ones go", function()
	local id = 9514
	seed(id)
	local intent = {
		Kind = "Stage",
		UserId = id,
		EventId = "event_vault",
		InstanceId = "dur:4",
		StageId = "vault_open",
		RewardVersion = 1,
		Coins = 6,
		StageCoins = 6,
		At = os.time(),
	}
	seedOutbox(OUTBOX, id, Rewards.ReceiptFor(intent), intent)
	local future = "adv:dur:5:" .. id .. ":final:v1"
	seedOutbox(OUTBOX, id, future, {
		Kind = "Final",
		UserId = id,
		EventId = "event_future", -- an event only a newer server knows
		InstanceId = "dur:5",
		RewardVersion = 1,
		Coins = 80,
		StageCoins = 8,
		At = os.time(),
	})
	seedOutbox(OUTBOX, id, "adv:junk", "not an intent")
	local futureTrophy = "trophy:dur:5:" .. id .. ":final:v1"
	seedOutbox(TROPHY_OUTBOX, id, futureTrophy, {
		TrophyId = "landmark_future",
		Source = "event_future",
		RegionId = "future_region",
		At = os.time(),
	})
	seedOutbox(TROPHY_OUTBOX, id, "trophy:dur:4:" .. id .. ":final:v1", {
		TrophyId = TROPHY,
		Source = "event_vault",
		RegionId = "sunshine_shore",
		At = os.time(),
	})
	local p = add(id, "Jo")
	Mock.Advance(2)
	check(DataService.Get(p).Coins == 6 and TrophyService.Owns(p, TROPHY) == true, "known intents applied")
	local adv, trophy = outboxOf(OUTBOX, id), outboxOf(TROPHY_OUTBOX, id)
	check(adv[Rewards.ReceiptFor(intent)] == nil, "applied intent acknowledged")
	check(adv[future] ~= nil, "a newer version's intent is kept for a server that understands it")
	check(adv["adv:junk"] == nil, "a malformed entry is dropped")
	check(trophy[futureTrophy] ~= nil, "a newer version's trophy grant is kept")
	check(count(trophy) == 1, "the applied trophy grant is acknowledged")
end)

section("a stale cached profile never overwrites a newer save")
step("another server took the lock over and released it", function()
	local id = 9515
	seed(id, function(d)
		d.Coins = 50
	end)
	local p = add(id, "Kit")
	check(DataService.Get(p).Coins == 50, "loaded here")
	-- Elsewhere: this server's lock looked stale, server B took the save, the player earned
	-- coins there, B saved and released the lock.
	local record = Mock.DataStores[STORE]["Player_" .. id]
	record.Data = deepCopy(record.Data)
	record.Data.Coins = 777
	record.Lock = nil
	record.SavedAt = os.time() + 60
	DataService.Get(p).Coins = 51 -- this server's stale copy keeps changing
	local kicked = #Mock.Kicked
	local saved = inThread(DataService.SaveAsync, p)
	check(saved == false, "the stale session's save is refused")
	check(stored(id).Coins == 777, "the newer save is intact")
	check(#Mock.Kicked == kicked + 1, "the stale session's player is told to rejoin")
	Mock.RemovePlayer(p)
	Mock.Advance(3)
	check(stored(id).Coins == 777, "the stale session's leave save does not clobber it either")
	-- a settlement into the stale session cannot claim it was saved
	local p2 = add(id, "Kit") -- clean rejoin loads the newer save
	check(DataService.Get(p2).Coins == 777, "rejoin loads the newer save")
end)

section("Unconfirmed grant whose player leaves before it was durable")
step("last outbox attempt after the leave", function()
	local id = 9516
	seed(id)
	local p = add(id, "Lou")
	local delays = Settlement.RetryDelays
	Settlement.RetryDelays = { 30 } -- the leave happens while the retry waits
	faults[STORE .. "/Player_" .. id] = true
	faults[OUTBOX] = true
	local report = Settlement.SettleStage(stageContext("dur:6", "excavation", { obs(id, 10) }))
	Mock.Advance(25)
	local entry = report.ByUserId[id]
	check(entry.Status == "Unconfirmed", "save and outbox down: Unconfirmed (" .. tostring(entry.Status) .. ")")
	local list = outcomesFor(id)
	check(#list == 1 and list[1].State == "Pending", "told Pending, never Accepted")
	Mock.RemovePlayer(p) -- the leave save fails too (store still down)
	faults[OUTBOX] = nil
	Mock.Advance(40)
	Settlement.RetryDelays = delays
	check(stored(id).Coins == 0, "the leave save did not land")
	local queued = outboxOf(OUTBOX, id)
	check(
		queued[Rewards.StageReceiptId("dur:6", id, "excavation", 1)] ~= nil,
		"the grant reached the durable outbox after the leave"
	)
	faults[STORE .. "/Player_" .. id] = nil
	local back = add(id, "Lou")
	Mock.Advance(2)
	check(DataService.Get(back).Coins == 6, "applied on the next load")
	check(count(outboxOf(OUTBOX, id)) == 0, "and acknowledged")
end)

section("offline final and BindToClose budget (mock clock)")
step("worst case: every outbox write retries during shutdown", function()
	-- Live-path worst case for one player: both outboxes fail every attempt.
	local users = { 9521, 9522, 9523, 9524 }
	local list = {}
	for _, id in users do
		table.insert(list, cp(id, 20))
	end
	local id = 9525
	seed(id)
	local p = add(id, "Max")
	table.insert(list, cp(id, 20))
	faults[OUTBOX] = true
	faults[TROPHY_OUTBOX] = true
	faults[STORE .. "/Player_" .. id] = true
	local report = Settlement.SettleCompletion(finalContext("dur:7", list))
	local start = Mock.Now()
	Mock.RunBindToClose()
	local elapsed = nil
	for _ = 1, 400 do
		if Settlement.InFlight() == 0 then
			elapsed = Mock.Now() - start
			break
		end
		Mock.Advance(0.1)
	end
	faults[OUTBOX], faults[TROPHY_OUTBOX], faults[STORE .. "/Player_" .. id] = nil, nil, nil
	print(string.format("  worst-case settlement writes resolved after %.1f s of mock time", elapsed or -1))
	check(elapsed ~= nil and elapsed < 20, "every in-flight write resolves inside the 20 s shutdown wait")
	for _, uid in users do
		local entry = report.ByUserId[uid]
		check(
			entry.Status == "Refused" and entry.Reason == "PendingWriteFailed",
			uid .. ": not loaded and not stored -> Refused, never claimed"
		)
	end
	check(report.ByUserId[id].Status == "Unconfirmed", "live player whose writes all failed: Unconfirmed")
	check(Mock.DataStores[OUTBOX]["Pending_9521"] == nil, "nothing half-written for an offline user")
	local _ = p
end)

-- 3. Flags and the kill switch ---------------------------------------------------------------
section("rewards flag off and kill switch")
step("rewards off: completion refused truthfully", function()
	local opts = Boot.Options({ AdventureRewards = false, BroadwaveOrdinary = false })
	local accepted, message = opts.OnCompletion(finalContext("dur:8", { cp(9501, 20) }))
	check(accepted == false and not claimsReward(message), "refused, and the broadcast claims nothing")
	check(opts.OnStage == nil, "no stage settlement is wired")
end)
step("kill switch mid-settlement: accepted grants still land", function()
	local id = 9531
	seed(id)
	local p = add(id, "Ned")
	faults[STORE .. "/Player_" .. id] = 1 -- first save attempt fails: the write is in flight
	local mark = #Mock.Remote.ToClient
	local report = Settlement.SettleStage(stageContext("dur:9", "excavation", { obs(id, 10) }))
	check(report.Ok, "stage accepted before the switch")
	Boot.Disable() -- the in-server kill switch, mid-settlement
	Settlement.SetEnabled(false) -- what Disable does when a runtime is running (flags-off boot has none)
	Mock.Advance(8)
	check(report.ByUserId[id].Status == "Saved", "the in-flight write still completes")
	local list = outcomesFor(id, mark)
	check(#list == 1 and list[1].State == "Accepted", "and the player is told once")
	check(
		Settlement.SettleStage(stageContext("dur:9", "vault_open", { obs(id, 10) })).Error == "Disabled",
		"new settlements refused"
	)
	local accepted, message = Settlement.OnCompletion(finalContext("dur:9", { cp(id, 20) }))
	check(
		accepted == false and message == Settlement.REFUSED_MESSAGE and not claimsReward(message),
		"completion refused truthfully"
	)
	-- drains continue under the kill switch
	local q = 9532
	seed(q)
	local intent = {
		Kind = "Stage",
		UserId = q,
		EventId = "event_vault",
		InstanceId = "dur:10",
		StageId = "excavation",
		RewardVersion = 1,
		Coins = 6,
		StageCoins = 6,
		At = os.time(),
	}
	seedOutbox(OUTBOX, q, Rewards.ReceiptFor(intent), intent)
	local pq = add(q, "Oda")
	Mock.Advance(2)
	check(DataService.Get(pq).Coins == 6 and count(outboxOf(OUTBOX, q)) == 0, "accepted intents still drain")
	local _ = p
end)

print(
	string.format(
		"  outcome monitor: %d Accepted (each durable when told), %d Pending, %d Refused",
		monitored.Accepted,
		monitored.Pending,
		monitored.Refused
	)
)
check(monitored.Accepted > 0 and monitored.Pending > 0, "the monitor saw Accepted and Pending outcomes")
check(#Mock.Errors == 0, "no uncaught errors")
for _, e in Mock.Errors do
	print("  error: " .. tostring(e))
end
print(string.format("SETTLEMENT DURABILITY (%s): %d passed, %d failed", mode, passes, failures))
if failures > 0 then
	error("SETTLEMENT DURABILITY SPEC FAILED")
end
