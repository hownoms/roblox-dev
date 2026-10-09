--!strict
local Config = require("../src/shared/Adventure/SpringVaultConfig")
local State = require("../src/server/Adventure/SpringVaultState")
local HaulBudget = require("../src/server/Adventure/HaulMovementBudget")
local passed = 0
local function eq(actual: any, expected: any)
	assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function test(name: string, body: () -> ())
	local ok, err = pcall(body)
	assert(ok, name .. ": " .. tostring(err))
	passed += 1
end
local function active(crew: number?): State.State
	local s = State.new(Config, "server-guid-test", 1, 0)
	for id = 2, crew or 1 do
		eq(s:join(id, 1), true)
	end
	eq(s:start(1, 5), true)
	for id = 1, crew or 1 do
		eq(s:ready(id, 5), true)
	end
	s:tick(5)
	eq(s.Phase, "Active")
	return s
end
local function excavate(s: State.State, userId: number, at: number): number
	for _, id in Config.AnchorIds do
		for _ = 1, s.Anchors[id].Required do
			eq(s:hitAnchor(userId, id, at), true)
			at += Config.HitCooldownSeconds
		end
	end
	return at
end

test("solo complete sequence and immutable completion snapshot", function()
	local s = active()
	eq(s:openVault(1, 5), false)
	local now = excavate(s, 1, 6)
	eq(s:openVault(1, now), true)
	eq(s:latch(1, true, now), true)
	for _, id in Config.GateIds do
		eq(s:advanceBallGate(id, now), true)
		now += 1
	end
	local context = s:completionContext(now) :: State.CompletionContext
	eq(context.Success, true)
	eq(context.Participants[1].Eligible, true)
	eq(context.Participants[1].Points, 65)
	eq(#context.CompletedStages, 3)
	context.ObjectiveIds[1] = "spoof"
	eq((s:completionContext(now) :: State.CompletionContext).ObjectiveIds[1], Config.AnchorIds[1])
	eq(s:advanceBallGate(Config.GateIds[3], now), false)
	eq(s:hitAnchor(1, Config.AnchorIds[1], now), false)
end)

test("invitation and bounded readiness do not start active timer early", function()
	local s = State.new(Config, "g", 1, 0)
	eq(s:start(1, 4.99), false)
	eq(s:start(2, 5), false)
	eq(s:join(2, 1), true)
	s:tick(30)
	eq(s.Phase, "Preparing")
	eq(s.ActiveAt, nil)
	s:ready(1, 31)
	s:tick(39.99)
	eq(s.Phase, "Preparing")
	s:tick(40)
	eq(s.Phase, "Active")
	eq(s.Deadline, 280)
	eq(s.Participants[2].Left, true)
	eq(s.Anchors[Config.AnchorIds[1]].Required, 6)
end)

test("all unready returns cleanup with no false completion", function()
	local s = State.new(Config, "g", 1, 0)
	s:start(1, 5)
	s:tick(15)
	eq(s.Phase, "Cleanup")
	eq(s:completionContext(15), nil)
end)

test("capacity, duplicate joins and departed identity", function()
	local s = active(4)
	eq(s:join(5, 6), false)
	eq(s:join(1, 6), false)
	s:leave(4, 6)
	eq(s:join(4, 7), false)
	eq(s:join(5, 7), true)
	eq(s.Anchors[Config.AnchorIds[1]].Required, 8)
end)

test("late useful helper qualifies without inflating frozen solo work", function()
	local s = active()
	local now = excavate(s, 1, 6)
	eq(s:join(2, now), true)
	eq(s:ready(2, now), true)
	eq(s.Anchors[Config.AnchorIds[1]].Required, 6)
	s:openVault(1, now)
	s:latch(2, true, now)
	for _, id in Config.GateIds do
		s:advanceBallGate(id, now)
		now += 1
	end
	local c = s:completionContext(now) :: State.CompletionContext
	eq(c.Participants[2].Points, 30)
	eq(c.Participants[2].Eligible, true)
end)

test("actual workers and haulers split fixed points; spectators get zero", function()
	local s = active(3)
	local now = 6
	for _, id in Config.AnchorIds do
		for i = 1, 8 do
			s:hitAnchor(if i <= 4 then 1 else 2, id, now)
			now += 0.5
		end
	end
	eq(s.Participants[1].Points, 15)
	eq(s.Participants[2].Points, 15)
	eq(s.Participants[3].Points, 0)
	s:openVault(1, now)
	s:latch(1, true, now)
	s:latch(2, true, now)
	for _, id in Config.GateIds do
		s:advanceBallGate(id, now)
		now += 1
	end
	local c = s:completionContext(now) :: State.CompletionContext
	eq(c.Participants[1].Points, 35)
	eq(c.Participants[2].Points, 30)
	eq(c.Participants[3].Eligible, false)
end)

test("cooldowns, unknown IDs, invalid work and repeated anchors", function()
	local s = active()
	local id = Config.AnchorIds[1]
	eq(s:hitAnchor(2, id, 6), false)
	eq(s:hitAnchor(1, "unknown", 6), false)
	eq(s:hitAnchor(1, id, 6, 0 / 0), false)
	eq(s:hitAnchor(1, id, 6, math.huge), false)
	eq(s:hitAnchor(1, id, 6, 2), false)
	eq(s:hitAnchor(1, id, 6), true)
	eq(s:hitAnchor(1, Config.AnchorIds[2], 6.49), false)
	eq(s:hitAnchor(1, id, 6.5), true)
	for i = 3, 6 do
		s:hitAnchor(1, id, 5.5 + i * 0.5)
	end
	eq(s.Anchors[id].Completed, true)
	eq(s:hitAnchor(1, id, 10), false)
	eq(s.Participants[1].Points, 10)
end)

test("gate order, attachment and penultimate admission lock", function()
	local s = active()
	local now = excavate(s, 1, 6)
	s:openVault(1, now)
	eq(s:advanceBallGate(Config.GateIds[1], now), false)
	s:latch(1, true, now)
	eq(s:advanceBallGate(Config.GateIds[2], now), false)
	eq(s:advanceBallGate(Config.GateIds[1], now), true)
	eq(s:advanceBallGate(Config.GateIds[1], now), false)
	eq(s:join(2, now), true)
	eq(s:advanceBallGate(Config.GateIds[2], now), true)
	eq(s:join(3, now), false)
end)

test("deadline locks admission and rejects late completion even before watchdog", function()
	local s = active()
	eq(s:join(2, 185), false)
	eq(s:hitAnchor(1, Config.AnchorIds[1], 245), false)
	s:tick(245)
	eq(s.Phase, "Cleanup")
	eq(s.FailureReason, "timeout")
	eq(s:completionContext(245), nil)
end)

test("disconnect slot hold, release cargo and empty watchdog", function()
	local s = active(2)
	local now = excavate(s, 1, 6)
	s:openVault(1, now)
	s:latch(2, true, now)
	s:leave(2, 25, true)
	eq(s.Participants[2].Attached, false)
	s:tick(114.99)
	eq(s.Participants[2].Left, false)
	s:tick(115)
	eq(s.Participants[2].Left, true)
	s:leave(1, 116)
	s:tick(116)
	s:tick(145.99)
	eq(s.Phase, "Active")
	s:tick(146)
	eq(s.Phase, "Cleanup")
	eq(s.FailureReason, "abandoned")
end)

test("leaving arena detaches and does not retain event via presence", function()
	local s = active()
	s:setPresence(1, false)
	eq(s:hitAnchor(1, Config.AnchorIds[1], 6), false)
	s:tick(6)
	s:setPresence(1, true)
	s:tick(20)
	eq(s.EmptySince, nil)
	s:setPresence(1, false)
	s:tick(21)
	s:tick(51)
	eq(s.FailureReason, "abandoned")
end)

test("late unready helper is returned after bounded readiness", function()
	local s = active()
	s:join(2, 6)
	s:tick(15.99)
	eq(s.Participants[2].Left, false)
	s:tick(16)
	eq(s.Participants[2].Left, true)
	eq(s:ready(2, 16), false)
end)

test("cleanup never claims reward settlement and drops attachments", function()
	local s = active()
	local now = excavate(s, 1, 6)
	s:openVault(1, now)
	s:latch(1, true, now)
	s:cleanup(now)
	eq(s.Participants[1].Attached, false)
	eq(s.Phase, "Cleanup")
	eq(s:completionContext(now), nil)
end)

test("active presence duration excludes voluntary arena absence", function()
	local s = active()
	s:setPresence(1, false, 10)
	s:setPresence(1, true, 40)
	local now = excavate(s, 1, 41)
	s:openVault(1, now)
	s:latch(1, true, now)
	for _, id in Config.GateIds do
		s:advanceBallGate(id, now)
		now += 1
	end
	local c = s:completionContext(now) :: State.CompletionContext
	eq(c.Participants[1].ActiveSeconds, 17)
end)

test("validated hauling excludes idle attached members", function()
	local s = active(2)
	local now = excavate(s, 1, 6)
	eq(s:openVault(1, now), true)
	eq(s:latch(1, true, now), true)
	eq(s:latch(2, true, now), true)
	eq(s:advanceBallGate(Config.GateIds[1], now, { [2] = 10 }), true)
	eq(s.Participants[1].Points, 35)
	eq(s.Participants[2].Points, 10)
	eq(s:advanceBallGate(Config.GateIds[2], now, {}), false)
	eq(s.GateIndex, 1)
end)
test("one hundred progression lifecycles remain isolated", function()
	for index = 1, 100 do
		local s = active()
		local now = excavate(s, 1, 6)
		eq(s:openVault(1, now), true)
		eq(s:latch(1, true, now), true)
		for _, gate in Config.GateIds do
			eq(s:advanceBallGate(gate, now, { [1] = 1 }), true)
		end
		eq((s:completionContext(now) :: State.CompletionContext).Participants[1].Points, 65)
		s:cleanup(now)
		eq(s.Phase, "Cleanup")
	end
end)
test("held reconnect preserves work cooldown and excludes offline presence", function()
	local s = active(2)
	eq(s:hitAnchor(2, Config.AnchorIds[1], 6), true)
	s:leave(2, 6.1, true)
	eq(s:join(2, 6.2), true)
	eq(s.Participants[2].Ready, true)
	eq(s.Participants[2].Attached, false)
	eq(s.Participants[2].LastHitAt, 6)
	eq(s:hitAnchor(2, Config.AnchorIds[1], 6.49), false)
	eq(s:hitAnchor(2, Config.AnchorIds[1], 6.5), true)
	eq(s.Anchors[Config.AnchorIds[1]].Work, 2)
	eq(s:join(2, 7), false)
	s:cleanup(10)
	assert(math.abs(s.Participants[2].ActiveSeconds - 4.9) < 0.00001)
end)

test("held reconnect remains available after new admission locks", function()
	local s = active(2)
	s:leave(2, 170, true)
	s:tick(185)
	eq(s.AdmissionLocked, true)
	eq(s:join(3, 186), false)
	eq(s:join(2, 186), true)
	eq(s.Participants[2].Connected, true)
end)

test("hold expiry cannot be bypassed before watchdog tick", function()
	local s = active(2)
	s:leave(2, 6, true)
	eq(s:join(2, 96), false)
	s:tick(96)
	eq(s.Participants[2].Left, true)
	eq(s:join(2, 97), false)
end)

test("repeated ready and latch requests do not change contribution", function()
	local s = active()
	eq(s:ready(1, 6), false)
	local now = excavate(s, 1, 6)
	s:openVault(1, now)
	eq(s:openVault(1, now), false)
	eq(s:latch(1, true, now), true)
	eq(s:latch(1, true, now), false)
	eq(s.Participants[1].Points, 35)
	s:leave(1, now, true)
	eq(s:join(1, now + 1), true)
	eq(s.Participants[1].Attached, false)
	eq(s.Participants[1].Points, 35)
	eq(s:advanceBallGate(Config.GateIds[1], now + 1), false)
end)

test("sparse replicated hauling samples fund smooth movement without idle credit", function()
	local banks: HaulBudget.Banks = {}
	local moved = 0
	local credit = 0
	for frame = 1, 600 do
		if frame % 6 == 1 then
			eq(HaulBudget.Record(banks, 1, 1.2, 1.2, 0.1), true)
		end
		local distance, shares = HaulBudget.Consume(banks, { 1, 2 }, 12 / 60)
		moved += distance
		credit += shares[1] or 0
		eq(shares[2], nil)
	end
	assert(math.abs(moved - 120) < 0.00001)
	assert(math.abs(credit - moved) < 0.00001)
	local idle = HaulBudget.Consume(banks, { 1, 2 }, 1)
	assert(idle < 0.00001)
end)

test("hauling rejects teleports reverse movement and bounds delayed travel", function()
	local banks: HaulBudget.Banks = {}
	eq(HaulBudget.Record(banks, 1, 20, 20, 1 / 60), false)
	eq(HaulBudget.Record(banks, 1, -1, 1, 0.1), false)
	eq(HaulBudget.Record(banks, 1, 0 / 0, 1, 0.1), false)
	eq(HaulBudget.Record(banks, 1, 4, 4, 10), true)
	eq(HaulBudget.Record(banks, 1, 4, 4, 10), true)
	eq(banks[1], 4)
	local distance = HaulBudget.Consume(banks, { 1 }, 0.2)
	eq(distance, 0.2)
	eq(HaulBudget.Consume(banks, { 2 }, 1), 0)
end)

print("Spring Vault: " .. tostring(passed) .. " tests passed")
