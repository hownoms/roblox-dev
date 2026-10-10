--!nocheck
--[[
	q_pip license grant + rides vs the Spring Vault pocket (docs/integration/pip-quest-license.md).
	  luau tests/pip-quest.spec.luau           real Main, SpringVault + BroadwaveOrdinary ON
	  luau tests/pip-quest.spec.luau -a off    real Main, SpringVault ON, BroadwaveOrdinary OFF
	The trial is driven through the runtime's own Intent remote (and runtime.Handle for the
	poll path) with mock players standing at the scene targets.
	MOCK COVERAGE ONLY: headless mock, in-memory DataStore, no real clients or devices.
]]

local Mock = require("./mock/Roblox")
local mode = ({ ... })[1] or "on"
Mock.Init(require("../build/test/generated"))
local passes, failures, notes = 0, 0, {}
local function check(cond, message)
	if cond then
		passes += 1
	else
		failures += 1
		print("FAIL: " .. message)
	end
	return cond
end
local function finish()
	check(#Mock.Errors == 0, "no uncaught errors")
	for _, e in Mock.Errors do
		print("  error: " .. tostring(e))
	end
	for _, n in notes do
		print(n)
	end
	print(string.format("PIP QUEST (%s): %d passed, %d failed", mode, passes, failures))
	if failures > 0 then
		error("PIP QUEST SPEC FAILED")
	end
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
local Services = "ServerScriptService/Server/Services/"
local Flags = load(Services .. "AdventureFlags")
local Boot = load(Services .. "AdventureBoot")
local Pip = load(Services .. "PipQuest")
local Eligibility = load(Services .. "AdventureEligibility")
local Data = load(Services .. "DataService")
local Ride = load(Services .. "RideService")
local Entry = load(Services .. "AdventureEntry")

-- Pure rules ------------------------------------------------------------------------------------
do
	local Rules = Pip.Rules
	local d = { Coins = 5, OwnedShovels = { a = true }, Shovel = "a", Quests = {}, Certifications = {} }
	local ok, why = Rules.Grant(d, 100)
	check(ok == true and why == "Granted", "Rules.Grant: first grant")
	local rec = d.ToolLicenses and d.ToolLicenses.tool_broadwave
	check(
		rec ~= nil and rec.Source == "q_pip" and rec.ReceiptId == "quest:q_pip" and rec.At == 100,
		"Rules.Grant: record shape { Source, ReceiptId, At }"
	)
	check(d.Coins == 5 and d.Shovel == "a" and d.OwnedShovels.a == true, "Rules.Grant: other fields untouched")
	ok, why = Rules.Grant(d, 200)
	check(ok == false and why == "Duplicate", "Rules.Grant: second grant is Duplicate")
	check(d.ToolLicenses.tool_broadwave == rec and rec.At == 100, "Rules.Grant: duplicate leaves the record untouched")
	local pre = { ToolLicenses = { tool_broadwave = { Source = "other", At = 1 } } }
	ok, why = Rules.Grant(pre, 5)
	check(
		ok == false and why == "Duplicate" and pre.ToolLicenses.tool_broadwave.Source == "other",
		"existing record kept"
	)
	ok, why = Rules.Grant(nil, 5)
	check(ok == false and why == "NotLoaded", "Rules.Grant(nil): NotLoaded")
	local keyed = { ToolLicenses = { other_tool = { At = 1 } } }
	check((Rules.Grant(keyed, 3)) and keyed.ToolLicenses.other_tool.At == 1, "other licenses kept")
	local count = 0
	for _ in d do
		count += 1
	end
	check(count == 6, "Rules.Grant adds only ToolLicenses")
	local full =
		{ Wave = true, Cleared = 3, Targets = { trial_target_1 = true, trial_target_2 = true, trial_target_3 = true } }
	check(Rules.TrialComplete(full), "TrialComplete: wave + three targets")
	check(not Rules.TrialComplete(nil), "TrialComplete: no trial")
	check(not Rules.TrialComplete({ Wave = false, Cleared = 3, Targets = full.Targets }), "TrialComplete: no wave")
	check(
		not Rules.TrialComplete({ Wave = true, Cleared = 3, Targets = { trial_target_1 = true, trial_target_2 = true } }),
		"TrialComplete: a missing target"
	)
	check(not Rules.TrialComplete({ Wave = true, Cleared = 2, Targets = full.Targets }), "TrialComplete: Cleared < 3")
end

-- Fixtures --------------------------------------------------------------------------------------
local rideDef
for _, p in Config.Pets do
	if p.Rideable == true and p.Dig then
		rideDef = p
		break
	end
end
if not rideDef then
	rideDef = {
		Id = "test_ride_excavator",
		Name = "Test Excavator",
		Rarity = "Mythic",
		Multiplier = 1,
		Exclusive = true,
		VehicleKind = "Excavator",
		Rideable = true,
		Dig = { Power = 1e6, Interval = 0.8, Radius = 6, SandMultiplier = 50 },
		Look = {
			BodyColor = Mock.Color3.fromRGB(255, 190, 20),
			AccentColor = Mock.Color3.fromRGB(255, 90, 160),
			Shape = "Blob",
			Size = 1,
			Glow = false,
		},
	}
	table.insert(Config.Pets, rideDef)
end

local function save(userId, mutate)
	local data = Config.NewPlayerData()
	data.Version = Config.DATA_VERSION
	if mutate then
		mutate(data)
	end
	Mock.DataStores[Config.DATASTORE_NAME] = Mock.DataStores[Config.DATASTORE_NAME] or {}
	Mock.DataStores[Config.DATASTORE_NAME]["Player_" .. userId] = { Data = data, SavedAt = 1 }
end
local function pricedShovel()
	for _, def in Config.Shovels do
		if def.Price > 0 then
			return def.Id
		end
	end
end
local PRICED = pricedShovel()
local U_TRIAL, U_NOSHOVEL, U_SPOOF, U_PARTIAL, U_LATE, U_DISABLE, U_RIDER = 9501, 9502, 9503, 9504, 9505, 9506, 9507
for _, id in { U_TRIAL, U_SPOOF, U_PARTIAL, U_LATE, U_DISABLE } do
	save(id, function(d)
		d.OwnedShovels[PRICED] = true
	end)
end
save(U_NOSHOVEL)
save(U_RIDER, function(d)
	d.Pets["ride_uid"] = { Id = rideDef.Id, Equipped = false }
end)

-- Capture the guard AdventureEntry installs, and every Mutate's key list.
local installedGuard, guardCleared = nil, false
local setGuard = Ride.SetSpawnGuard
Ride.SetSpawnGuard = function(fn)
	if fn then
		installedGuard = fn
	else
		guardCleared = true
	end
	setGuard(fn)
end
local mutations = {}
local mutate = Data.Mutate
Data.Mutate = function(player, keys, fn)
	table.insert(mutations, { Player = player, Keys = table.clone(keys) })
	return mutate(player, keys, fn)
end

Flags.SpringVault, Flags.AdventureRewards, Flags.BroadwaveOrdinary = true, false, mode ~= "off"
Mock.RunScript(byPath["ServerScriptService/Server/Main"])
Mock.Advance(25)
check(#Mock.Errors == 0, "Main boots")
local runtime = Boot.Runtime()
if not check(runtime ~= nil, "runtime started") then
	finish()
	return
end
local targets = runtime.Scene.Targets
local intent = Mock.Service("ReplicatedStorage").SpringVaultAdventure.Intent

local function add(userId, name)
	local p = Mock.AddPlayer(userId, name)
	Mock.Advance(2)
	Mock.SpawnCharacter(p, V.new(0, S + 3, 4))
	Mock.Advance(1)
	return p
end
local function toasts(p, since, needle)
	local n = 0
	for i = since + 1, #Mock.Remote.ToClient do
		local e = Mock.Remote.ToClient[i]
		if e.Player == p and e.Name == "Notify" and string.find(tostring(e.Args[2]), needle, 1, true) then
			n += 1
		end
	end
	return n
end
local function issued(p)
	for _, container in { p.Backpack, p.Character } do
		for _, child in container:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("LicensedBroadwave") == true then
				return child
			end
		end
	end
	return nil
end
local function loanOf(p)
	for _, container in { p.Backpack, p.Character } do
		local t = container:FindFirstChild("Broadwave (Adventure Loan)")
		if t then
			return t
		end
	end
	return nil
end
local function hold(p, tool)
	for _, child in p.Character:GetChildren() do
		if child:IsA("Tool") then
			child.Parent = p.Backpack
		end
	end
	tool.Parent = p.Character
end
local function licensed(p)
	local d = Data.Get(p)
	return d and d.ToolLicenses and d.ToolLicenses.tool_broadwave
end
-- `via` = "intent" (the client remote, as a real client) or "handle" (no remote: poll path).
local function send(p, payload, via)
	if via == "handle" then
		runtime.Handle(p, payload)
	else
		Mock.FireEvent(intent, "OnServerEvent", p, payload)
	end
end
local function talk(p, via)
	p.Character:PivotTo(CF.new(targets.npc_pip + V.new(0, 3, 2)))
	send(p, { action = "Talk", targetId = "npc_pip" }, via)
	Mock.Advance(0.2)
end
local function wave(p, via)
	local loan = loanOf(p)
	if not loan then
		return false
	end
	hold(p, loan)
	p.Character:PivotTo(CF.lookAt(targets.trial_patch + V.new(0, 3, 5), targets.trial_patch + V.new(0, 3, 0)))
	send(p, { action = "ChargeBegin", targetId = "trial_patch" }, via)
	Mock.Advance(1)
	send(p, { action = "ChargeRelease", targetId = "trial_patch" }, via)
	Mock.Advance(0.1)
	local t = runtime.ReviewPlayer(p).Trial
	return t ~= nil and t.Wave == true
end
local function excavate(p, i, via, settle)
	local id = "trial_target_" .. i
	p.Character:PivotTo(CF.new(targets[id] + V.new(0, 3, 4)))
	Mock.Advance(0.6) -- HitCooldownSeconds 0.5
	send(p, { action = "Excavate", targetId = id }, via)
	if settle ~= false then
		Mock.Advance(0.05)
	end
end

-- BroadwaveOrdinary OFF: Pip stays a demo ------------------------------------------------------
if mode == "off" then
	check(not Pip.IsRunning(), "off: PipQuest not started")
	local p = add(U_TRIAL, "Trial")
	local mark = #Mock.Remote.ToClient
	talk(p)
	check(runtime.ReviewPlayer(p).Trial ~= nil, "off: Pip trial still runs (demo)")
	check(wave(p), "off: trial wave lands")
	for i = 1, 3 do
		excavate(p, i)
	end
	local t = runtime.ReviewPlayer(p).Trial
	check(Pip.Rules.TrialComplete(t), "off: trial complete in the runtime")
	Mock.Advance(3)
	check(licensed(p) == nil, "off: no license granted")
	check(issued(p) == nil, "off: no licensed tool")
	check(toasts(p, mark, "license earned") == 0, "off: no grant toast")
	local ok, why = Pip.Check(p)
	check(ok == false and why == "NotRunning", "off: Check refuses (NotRunning)")
	finish()
	return
end

-- BroadwaveOrdinary ON --------------------------------------------------------------------------
check(Pip.IsRunning(), "on: PipQuest started")

-- 1. No bought shovel: Pip refuses the trial; nothing can grant.
local noShovel = add(U_NOSHOVEL, "NoShovel")
talk(noShovel)
check(runtime.ReviewPlayer(noShovel).Trial == nil, "no bought shovel: no trial")
for i = 1, 3 do
	excavate(noShovel, i)
end
Mock.Advance(2)
check(licensed(noShovel) == nil and issued(noShovel) == nil, "no bought shovel: never granted")

-- 2. Spoofed payloads with no server trial state.
local spoof = add(U_SPOOF, "Spoof")
local spoofs = {
	{ action = "Excavate", targetId = "trial_target_1" },
	{ action = "Excavate", targetId = "trial_target_3" },
	{ action = "TrialComplete" },
	{ action = "Talk", targetId = "npc_pip", trialComplete = true, Wave = true, Cleared = 3 },
	{
		trial = {
			Wave = true,
			Cleared = 3,
			Targets = { trial_target_1 = true, trial_target_2 = true, trial_target_3 = true },
		},
	},
	"q_pip",
}
for _, payload in spoofs do
	Mock.FireEvent(intent, "OnServerEvent", spoof, payload)
end
Mock.Advance(2)
check(licensed(spoof) == nil and issued(spoof) == nil, "spoofed client payloads alone never grant")
local ok, why = Pip.Check(spoof)
check(ok == false and why == "Incomplete", "spoof: Check reports Incomplete (reads server trial only)")

-- 3. Partial trial: wave + two targets.
local partial = add(U_PARTIAL, "Partial")
talk(partial)
check(wave(partial), "partial: wave lands")
excavate(partial, 1)
excavate(partial, 2)
Mock.Advance(3)
local pt = runtime.ReviewPlayer(partial).Trial
check(pt ~= nil and pt.Wave == true and pt.Cleared == 2, "partial: runtime has wave + 2 targets")
check(licensed(partial) == nil and issued(partial) == nil, "partial trial: no grant")

-- 4. Full trial through the Intent remote: granted exactly once.
local trialist = add(U_TRIAL, "Trial")
talk(trialist)
check(runtime.ReviewPlayer(trialist).Trial ~= nil, "trial started (bought shovel)")
local loan = loanOf(trialist)
check(loan ~= nil, "trial loan lent")
hold(trialist, loan)
check(Eligibility.CanUseBroadwave(trialist, loan) == false, "before grant: loan refused by CanUseBroadwave")
check(wave(trialist), "trial wave lands")
excavate(trialist, 1)
excavate(trialist, 2)
check(licensed(trialist) == nil, "two targets: not yet")
local function snapshot(d)
	local copy = {}
	for k, v in d do
		if k ~= "ToolLicenses" then
			copy[k] = v
		end
	end
	return copy
end
local function deepEqual(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
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
local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in t do
		c[k] = deepCopy(v)
	end
	return c
end
local before = deepCopy(snapshot(Data.Get(trialist)))
local mutationMark = #mutations
local mark = #Mock.Remote.ToClient
excavate(trialist, 3, "intent", false)
check(licensed(trialist) == nil, "grant is deferred (not inside the remote handler)")
Mock.Advance(0) -- one resumption: the deferred check runs
Mock.Advance(0.05)
local rec = licensed(trialist)
check(rec ~= nil, "full trial via Intent: license granted")
check(
	rec ~= nil and rec.Source == "q_pip" and rec.ReceiptId == "quest:q_pip" and type(rec.At) == "number",
	"granted record { Source = q_pip, ReceiptId = quest:q_pip, At }"
)
local grantMutations = {}
for i = mutationMark + 1, #mutations do
	if mutations[i].Player == trialist then
		table.insert(grantMutations, mutations[i])
	end
end
check(
	#grantMutations == 1 and #grantMutations[1].Keys == 1 and grantMutations[1].Keys[1] == "ToolLicenses",
	"grant mutates only the ToolLicenses key"
)
local after = snapshot(Data.Get(trialist))
local diffs = {}
for _, key in { "OwnedShovels", "Shovel", "Coins", "Quests", "Certifications", "Pets", "Sand", "Rebirths" } do
	if not deepEqual(before[key], after[key]) then
		table.insert(diffs, key)
	end
end
check(#diffs == 0, "grant never touches shovels, coins, quests, certifications: " .. table.concat(diffs, ","))
check(toasts(trialist, mark, "Broadwave license earned") == 1, "grant toast sent once")
local licTool = issued(trialist)
check(licTool ~= nil, "licensed tool issued immediately after the grant")
Mock.Advance(1)
local stored = Mock.DataStores[Config.DATASTORE_NAME]["Player_" .. U_TRIAL]
local savedRecord = stored and stored.Data and stored.Data.ToolLicenses and stored.Data.ToolLicenses.tool_broadwave
local mockSaved = savedRecord ~= nil
if not mockSaved and Data.IsMock() then
	table.insert(notes, "NOTE: DataService runs on its in-process mock store; SaveAsync wrote there")
	mockSaved = true
end
check(mockSaved, "grant saved (SaveAsync)")

-- Loans never confer ordinary rights, even after the grant.
loan = loanOf(trialist)
check(loan ~= nil, "trial loan still present after completion")
hold(trialist, loan)
check(Eligibility.CanUseBroadwave(trialist, loan) == false, "after grant: loan still refused")
hold(trialist, licTool)
check(Eligibility.CanUseBroadwave(trialist, licTool) == true, "after grant: licensed tool accepted")
local License = load(Services .. "BroadwaveLicense")
check(License.ResolveTool(trialist) == licTool, "after grant: ResolveTool returns the licensed tool")
hold(trialist, loan)
check(License.ResolveTool(trialist) == nil, "after grant: ResolveTool never returns the loan")

-- End to end on ordinary sand when the runtime accepts licensed charges.
do
	local World = load("ServerScriptService/Server/World")
	Mock.ServerTerrainRaycast = true
	local zone = World.GetDigZone()
	local point = V.new(300, S, zone.CFrame.Position.Z)
	local function onSand(tool)
		hold(trialist, tool)
		trialist.Character:PivotTo(CF.lookAt(point + V.new(0, 3, 4), point + V.new(0, 3, -4)))
	end
	Mock.Advance(9) -- Broadwave cooldown from the trial wave
	local d = Data.Get(trialist)
	onSand(loan)
	d.Sand = 0
	local dug = d.TotalSandDug
	runtime.Handle(trialist, { action = "ChargeBegin" })
	local loanCharging = runtime.ReviewPlayer(trialist).Charging
	Mock.Advance(1)
	runtime.Handle(trialist, { action = "ChargeRelease" })
	check(loanCharging == false and d.TotalSandDug == dug, "after grant: loan on sand never charges or digs")
	onSand(licTool)
	runtime.Handle(trialist, { action = "ChargeBegin" })
	local licCharging = runtime.ReviewPlayer(trialist).Charging
	Mock.Advance(1)
	runtime.Handle(trialist, { action = "ChargeRelease" })
	if licCharging then
		check(d.TotalSandDug > dug, "after grant: licensed tool digs ordinary sand")
	else
		table.insert(notes, "SKIPPED end-to-end licensed dig (runtime lacks ResolveTool)")
	end
	Mock.ServerTerrainRaycast = false
end

-- Duplicate: the complete trial persists (poll keeps seeing it); a second completion changes nothing.
local stamp = rec.At
Mock.Advance(3)
check(licensed(trialist) == rec and rec.At == stamp, "poll over a complete trial: record unchanged")
ok, why = Pip.Check(trialist)
check(ok == false and why == "Duplicate", "Check after grant: Duplicate")
mark = #Mock.Remote.ToClient
send(trialist, { action = "Leave" })
Mock.Advance(0.3)
check(runtime.ReviewPlayer(trialist).Trial == nil, "trial left")
Mock.Advance(9)
talk(trialist)
check(wave(trialist), "second trial: wave lands")
for i = 1, 3 do
	excavate(trialist, i)
end
check(Pip.Rules.TrialComplete(runtime.ReviewPlayer(trialist).Trial), "second trial complete")
Mock.Advance(2)
check(
	licensed(trialist) == rec and rec.At == stamp and rec.ReceiptId == "quest:q_pip",
	"second completion: receipt stable"
)
check(toasts(trialist, mark, "Broadwave license earned") == 0, "second completion: no second toast")
local tools = 0
for _, container in { trialist.Backpack, trialist.Character } do
	for _, child in container:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("LicensedBroadwave") == true then
			tools += 1
		end
	end
end
check(tools == 1, "still exactly one licensed tool")

-- 5. Poll path (runtime.Handle, no remote) + CanTrial re-checked at grant time.
local late = add(U_LATE, "Late")
talk(late, "handle")
check(wave(late, "handle"), "late: wave lands")
excavate(late, 1, "handle")
excavate(late, 2, "handle")
local ld = Data.Get(late)
ld.OwnedShovels[PRICED] = nil -- e.g. a rebirth reset between trial start and completion
excavate(late, 3, "handle")
check(Pip.Rules.TrialComplete(runtime.ReviewPlayer(late).Trial), "late: runtime trial complete")
Mock.Advance(2.5)
check(licensed(late) == nil, "no bought shovel at completion: no grant")
ok, why = Pip.Check(late)
check(ok == false and why == "NoShovelPurchase", "Check reports NoShovelPurchase")
ld.OwnedShovels[PRICED] = true
Mock.Advance(1.5)
check(licensed(late) ~= nil and issued(late) ~= nil, "poll grants once eligible again (no remote needed)")

-- 6. Rides vs the pocket --------------------------------------------------------------------------
local RideMath = load("ReplicatedStorage/Shared/Util/RideMath")
local World = load("ServerScriptService/Server/World")
local zone = World.GetDigZone()
local bounds = RideMath.Bounds(zone.CFrame, zone.Size)
local function rideDistance(pos)
	local spot = RideMath.Clamp(pos, bounds)
	return V.new(spot.X - pos.X, 0, spot.Z - pos.Z).Magnitude
end
local arrival = Entry.ArrivalFrame().Position
local origin = Boot.POCKET_ORIGIN
local minD, worst = math.huge, nil
local arenaD, arenaWorst = math.huge, nil
for x = -100, 100, 2 do
	for z = -106, 94, 2 do
		local p = origin + V.new(x, 3.5, z)
		if Entry.InPocket(p) then
			local d = rideDistance(p)
			if d < minD then
				minD, worst = d, p
			end
			if Entry.InArena(p) and d < arenaD then
				arenaD, arenaWorst = d, p
			end
		end
	end
end
local arrivalD = rideDistance(arrival)
local maxD = Config.Ride.SpawnMaxDistance
table.insert(
	notes,
	string.format(
		"MEASURED: ride-area distance from pocket arrival %.1f studs; nearest arena (presence box) point %.1f studs at (%.0f, %.0f); nearest InPocket point %.1f studs at (%.0f, %.0f); SpawnMaxDistance %d; ride bounds X[%.1f, %.1f] Z[%.1f, %.1f]",
		arrivalD,
		arenaD,
		arenaWorst.X,
		arenaWorst.Z,
		minD,
		worst.X,
		worst.Z,
		maxD,
		bounds.MinX,
		bounds.MaxX,
		bounds.MinZ,
		bounds.MaxZ
	)
)
check(installedGuard ~= nil, "AdventureEntry installed a ride spawn guard")

local rider = add(U_RIDER, "Rider")
local hum = rider.Character:FindFirstChildOfClass("Humanoid")
local function toggle()
	Mock.Advance(1)
	Mock.FireServer("ToggleRide", rider)
	Mock.Advance(0.5)
end
-- Old check alone: would the nearest pocket point pass the horizontal distance check?
local passesOld = arenaD <= maxD
-- With the guard: refused from the pocket.
rider.Character:PivotTo(CF.new(arenaWorst))
mark = #Mock.Remote.ToClient
toggle()
check(not Ride.IsRiding(rider), "ToggleRide from the arena edge nearest the beach: refused")
check(toasts(rider, mark, "Rides stay on the beach.") == 1, "pocket refusal toast")
rider.Character:PivotTo(CF.new(arrival))
toggle()
check(not Ride.IsRiding(rider), "ToggleRide at the arrival point: refused")
if passesOld then
	-- Without the guard the old distance check alone lets the ride spawn from the pocket, and
	-- AdventureEntry's defensive check despawns it.
	Ride.SetSpawnGuard(nil)
	guardCleared = false
	rider.Character:PivotTo(CF.new(arenaWorst))
	Mock.Advance(1)
	Mock.FireServer("ToggleRide", rider)
	local bypass = Ride.IsRiding(rider)
	check(bypass, "control: without the guard the old distance check lets a ride spawn from the pocket")
	table.insert(notes, "MEASURED: without the guard, ToggleRide from the pocket spawned a ride: " .. tostring(bypass))
	Mock.Advance(0.5)
	check(not Ride.IsRiding(rider), "a ride found with its rider in the pocket is despawned")
	Ride.SetSpawnGuard(installedGuard)
end
-- On the beach: works.
rider.Character:PivotTo(CF.new(100, S + 3, zone.CFrame.Position.Z))
toggle()
check(Ride.IsRiding(rider), "ToggleRide on the beach: spawns")
check(hum.SeatPart ~= nil, "rider seated")
-- Hatch refuses seated players.
local hatch = Mock.Service("Workspace")[Entry.FOLDER].Entrance.Hatch
local enter = hatch:FindFirstChild("AdventureEntryPrompt")
rider.Character:PivotTo(CF.new(hatch.Position + V.new(3, 3, 0)))
mark = #Mock.Remote.ToClient
Mock.Advance(Entry.PROMPT_COOLDOWN + 0.1)
Mock.FireEvent(enter, "Triggered", rider)
Mock.Advance(0.3)
check(not Entry.InPocket(rider.Character.HumanoidRootPart.Position), "seated player stays on the surface")
check(toasts(rider, mark, "Hop off your ride first.") == 1, "hatch tells the seated player to hop off")
-- A rider who ends up in the pocket anyway loses the ride.
rider.Character:PivotTo(CF.new(arrival))
Mock.Advance(0.5)
check(not Ride.IsRiding(rider), "rider moved into the pocket: ride despawned")

-- 7. Kill switch: no grant after Disable --------------------------------------------------------
local dis = add(U_DISABLE, "Disable")
talk(dis, "handle")
check(wave(dis, "handle"), "disable: wave lands")
excavate(dis, 1, "handle")
excavate(dis, 2, "handle")
excavate(dis, 3, "handle", false)
Boot.Disable()
Mock.Advance(3)
check(not Pip.IsRunning(), "Disable stops PipQuest")
check(licensed(dis) == nil, "completion right before Disable: never granted")
ok, why = Pip.Check(dis)
check(ok == false and why == "NotRunning", "after Disable: Check refuses")
check(licensed(trialist) == rec, "Disable never removes a granted license")
check(guardCleared, "Disable (AdventureEntry.Stop) clears the ride spawn guard")
finish()
