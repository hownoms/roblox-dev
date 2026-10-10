--!nocheck
--[[
	Spring Vault catch-up evidence and kill-switch regressions found by the 10 October 2026 audit
	(docs/integration/launch-readiness.md).
	  luau tests/adventure-evidence.spec.luau               flags OFF: what counts as deposit evidence
	  luau tests/adventure-evidence.spec.luau -a failstart  SpringVault + rewards ON, runtime Start throws

	Default: a brand-new player's guaranteed tutorial find is not an excavated deposit, so it must
	never make catch-up entry true (it used to roll a Size/Material variant, which read as deposit
	evidence: 24 of 40 fresh saves entered after the tutorial find and one sale). A real excavated
	deposit with a rolled variant plus a real sale still qualifies.
	failstart: the kill switch refuses settlements even when Start failed before a runtime existed.
	MOCK COVERAGE ONLY: headless mock, in-memory DataStore, real Main and services.
]]

local Mock = require("./mock/Roblox")
local mode = ({ ... })[1] or "evidence"
Mock.Init(require("../build/test/generated"))
local passes, failures = 0, 0
local function check(cond, message)
	if cond then
		passes += 1
	else
		failures += 1
		print("FAIL: " .. message)
	end
end
local function finish()
	check(#Mock.Errors == 0, "no uncaught errors")
	for _, e in Mock.Errors do
		print("  error: " .. tostring(e))
	end
	print(string.format("ADVENTURE EVIDENCE (%s): %d passed, %d failed", mode, passes, failures))
	if failures > 0 then
		error("ADVENTURE EVIDENCE SPEC FAILED")
	end
end

local byPath = Mock.ByPath
local function load(path)
	return Mock.Require(byPath[path])
end
local V = Mock.Vector3
local Config = load("ReplicatedStorage/Shared/Config")
for _, category in { Config.Monetization.GamePasses, Config.Monetization.Products, Config.Badges } do
	for _, item in category do
		item.Id = 0
	end
end
local S = Config.SURFACE_Y
local function save(userId)
	local data = Config.NewPlayerData()
	data.Version = Config.DATA_VERSION
	Mock.DataStores[Config.DATASTORE_NAME] = Mock.DataStores[Config.DATASTORE_NAME] or {}
	Mock.DataStores[Config.DATASTORE_NAME]["Player_" .. userId] = { Data = data, SavedAt = 1 }
end
local function variants(d)
	local keys = {}
	for key, owned in d.FindVariants or {} do
		if owned == true then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	return keys
end
local P = "ServerScriptService/Server/Services/"
local Flags = load(P .. "AdventureFlags")
check(
	Flags.SpringVault == false and Flags.AdventureRewards == false and Flags.BroadwaveOrdinary == false,
	"every adventure flag ships off"
)

if mode == "evidence" then
	local N = 24
	for i = 1, N + 2 do
		save(7400 + i)
	end
	Mock.RunScript(byPath["ServerScriptService/Server/Main"])
	Mock.Advance(20)
	local Data = load(P .. "DataService")
	local Elig = load(P .. "AdventureEligibility")
	local Signals = load(P .. "ServerSignals")
	local Disc = load(P .. "DiscoveryService")
	local Econ = load(P .. "EconomyService")
	local function join(userId, name)
		local p = Mock.AddPlayer(userId, name)
		Mock.Advance(0.5)
		Mock.SpawnCharacter(p, V.new(0, S + 3, 40))
		Mock.Advance(2)
		return p
	end
	local function sell(p)
		local d = Data.Get(p)
		d.Sand = 5
		Econ.Sell(p, "EvidenceSpec")
		Mock.Advance(0.2)
		return d
	end

	-- 1. Tutorial find (no deposit anywhere: the carves are above the surface) + one real sale.
	local ftue, admitted, plain = 0, 0, 0
	for i = 1, N do
		local p = join(7400 + i, "Fresh" .. i)
		for _ = 1, Config.Discovery.FTUE_FIND_DIG do
			Signals.Carved:Fire(p, V.new(0, S + 30, 0), V.new(2, S + 32, 2), "Shovel", 1)
		end
		local ex = Disc.GetExcavation(p)
		if ex then
			ftue += 1
			if ex.Size == "Normal" and ex.Material == "None" then
				plain += 1
			end
			Disc.Resolve(p, ex.Id, nil)
		end
		local d = sell(p)
		check(Elig.Rules.HasSaleEvidence(d), "fresh " .. i .. ": the real sale is recorded")
		local ok, why = Elig.Rules.CanEnter(d)
		if ok then
			admitted += 1
			print(string.format("  admitted %d by %s: {%s}", p.UserId, why, table.concat(variants(d), ",")))
		end
	end
	check(ftue >= N - 2, string.format("the guaranteed tutorial find happened (%d/%d)", ftue, N))
	check(plain == ftue, string.format("every tutorial find is plain Normal/None (%d/%d)", plain, ftue))
	check(admitted == 0, string.format("tutorial find + one sale never grants catch-up entry (%d/%d)", admitted, N))

	-- 2. A real excavated deposit with a rolled variant + a real sale still qualifies.
	local vet = join(7400 + N + 1, "Digger")
	local d = Data.Get(vet)
	d.Index = { bottle_cap = true } -- has found before: no tutorial find
	local zone = load("ServerScriptService/Server/World").GetDigZone()
	local deposit = Disc.AddDeposit(zone.CFrame.Position - V.new(0, 6, 0), "bottle_cap")
	check(deposit ~= nil, "a deposit was placed")
	local id = deposit and Disc.Uncover(vet, deposit, nil, nil, "Tiny", "None")
	check(id ~= nil, "the deposit was uncovered")
	if id then
		Disc.Resolve(vet, id, nil)
	end
	check(Elig.Rules.HasDepositEvidence(d), "a real deposit with a rolled variant is deposit evidence")
	check(not (Elig.Rules.CanEnter(d)), "deposit alone is not enough")
	sell(vet)
	local ok, why = Elig.Rules.CanEnter(d)
	check(ok and why == "CatchUp", "real deposit + real sale: catch-up entry (" .. tostring(why) .. ")")

	-- 3. Documented limit (owner decision: a permanent deposit record): a real deposit that rolls
	-- the plain Normal/None variants leaves no evidence, so that player is not admitted yet.
	local plainDigger = join(7400 + N + 2, "PlainDigger")
	local pd = Data.Get(plainDigger)
	pd.Index = { bottle_cap = true }
	local deposit2 = Disc.AddDeposit(zone.CFrame.Position - V.new(6, 6, 0), "bottle_cap")
	local id2 = deposit2 and Disc.Uncover(plainDigger, deposit2, nil, nil, "Normal", "None")
	if id2 then
		Disc.Resolve(plainDigger, id2, nil)
	end
	sell(plainDigger)
	check(
		id2 ~= nil and not Elig.Rules.HasDepositEvidence(pd) and not (Elig.Rules.CanEnter(pd)),
		"known limit kept explicit: a plain Normal/None deposit is not evidence"
	)
	finish()
	return
end

if mode == "failstart" then
	local service = byPath["ServerScriptService/Server/Adventure/SpringVaultService"]
	if not service then
		print("SKIPPED (Spring Vault runtime files absent)")
		finish()
		return
	end
	Flags.SpringVault, Flags.AdventureRewards, Flags.BroadwaveOrdinary = true, true, false -- this process only
	local SVS = Mock.Require(service)
	local realStart = SVS.Start
	SVS.Start = function()
		error("simulated runtime start failure")
	end
	Mock.RunScript(byPath["ServerScriptService/Server/Main"])
	Mock.Advance(10)
	local Boot = load(P .. "AdventureBoot")
	local Settlement = load(P .. "AdventureSettlement")
	local Entry = load(P .. "AdventureEntry")
	check(Boot.Runtime() == nil and not Entry.IsStarted(), "failed Start leaves no runtime and no entrance")
	local r = Settlement.SettleStage({})
	check(
		r and r.Error == "Disabled",
		"failed Start: settlement refuses as Disabled (" .. tostring(r and r.Error) .. ")"
	)
	Boot.Disable()
	r = Settlement.SettleStage({})
	check(r and r.Error == "Disabled", "an explicit kill switch keeps it Disabled")
	-- Re-enable in the same server once the runtime can start.
	SVS.Start = realStart
	Boot.Start()
	Mock.Advance(2)
	check(Boot.Runtime() ~= nil and Entry.IsStarted(), "Start after the fix brings the runtime and entrance back")
	r = Settlement.SettleStage({})
	check(r and r.Error ~= "Disabled", "settlement re-enabled with rewards on (" .. tostring(r and r.Error) .. ")")
	Boot.Disable()
	r = Settlement.SettleStage({})
	check(Boot.Runtime() == nil and r and r.Error == "Disabled", "kill switch after a running runtime: Disabled")
	Mock.Advance(2)
	finish()
	return
end

error("unknown mode " .. tostring(mode))
