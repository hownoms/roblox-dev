--!nocheck
--[[
	Production entry/exit for the Spring Vault pocket (docs/integration/adventure-entry.md).
	  luau tests/adventure-entry.spec.luau          Main booted, flags OFF: nothing built
	  luau tests/adventure-entry.spec.luau -a on    Main booted with SpringVault ON
	"on" needs Codex's Spring Vault runtime files; without them it prints SKIPPED and passes.
	MOCK COVERAGE ONLY: headless mock, in-memory DataStore, no real clients, physics or lighting.
]]

local Mock = require("./mock/Roblox")
local mode = ({ ... })[1] or "off"
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
	print(string.format("ADVENTURE ENTRY (%s): %d passed, %d failed", mode, passes, failures))
	if failures > 0 then
		error("ADVENTURE ENTRY SPEC FAILED")
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
local hasRuntime = byPath["ServerScriptService/Server/Adventure/SpringVaultService"] ~= nil

local function save(userId, mutate)
	local data = Config.NewPlayerData()
	data.Version = Config.DATA_VERSION
	if mutate then
		mutate(data)
	end
	Mock.DataStores[Config.DATASTORE_NAME] = Mock.DataStores[Config.DATASTORE_NAME] or {}
	Mock.DataStores[Config.DATASTORE_NAME]["Player_" .. userId] = { Data = data, SavedAt = 1 }
end
local function certified(d)
	d.Certifications = { cert_rookie = { At = 1, Source = "test" } }
end

local Flags = load("ServerScriptService/Server/Services/AdventureFlags")
check(
	Flags.SpringVault == false and Flags.AdventureRewards == false and Flags.BroadwaveOrdinary == false,
	"every adventure flag ships off"
)
if mode == "on" then
	if not hasRuntime then
		print("SKIPPED (Spring Vault runtime files absent)")
		finish()
		return
	end
	Flags.SpringVault = true
end

local USER_FRESH, USER_CERT, USER_VET, USER_CERT2, USER_CERT3 = 9401, 9402, 9403, 9404, 9405
save(USER_FRESH)
save(USER_CERT, certified)
save(USER_VET, function(d)
	d.Quests = { daily_sell_10 = { Progress = 3, Claimed = false, Day = 1 } }
	d.FindVariants = { ["gold_coin/Gold"] = true }
end)
save(USER_CERT2, certified)
save(USER_CERT3, certified)

Mock.RunScript(byPath["ServerScriptService/Server/Main"])
Mock.Advance(25)
check(#Mock.Errors == 0, "Main boots")

local Workspace = Mock.Service("Workspace")
local Boot = load("ServerScriptService/Server/Services/AdventureBoot")
local Entry = load("ServerScriptService/Server/Services/AdventureEntry")
local Layout = load("ServerScriptService/Server/World/Layout")
local World = load("ServerScriptService/Server/World")

local function entryPrompts()
	local list = {}
	for _, d in Workspace:GetDescendants() do
		if d:IsA("ProximityPrompt") and d.Name == "AdventureEntryPrompt" then
			table.insert(list, d)
		end
	end
	return list
end
local function lightsOutsideMap()
	local n = 0
	local map = Workspace:FindFirstChild("Map")
	for _, d in Workspace:GetDescendants() do
		if
			(d:IsA("PointLight") or d:IsA("SurfaceLight") or d:IsA("SpotLight")) and not (map and d:IsDescendantOf(map))
		then
			n += 1
		end
	end
	return n
end

-- The entrance location is valid in either mode (pure geometry).
check(Entry.EntranceIsSafe(), "entrance outside the dig zone and protected footprints")
check(not World.IsInDigZone(Entry.ENTRANCE), "entrance not in the dig zone")
check(not World.IsProtected(Entry.ENTRANCE, 12), "entrance not on/near the camp pad")
do
	local c, r = Entry.ENTRANCE, Entry.PAD_SIZE / 2 + 4
	local hits = {}
	for _, d in Workspace:FindFirstChild("Map"):GetDescendants() do
		if d:IsA("BasePart") then
			local p, h = d.Position, d.Size / 2
			if
				math.abs(p.X - c.X) < r + h.X
				and math.abs(p.Z - c.Z) < r + h.Z
				and p.Y + h.Y > S - 2
				and p.Y - h.Y < S + 14
			then
				table.insert(hits, d:GetFullName())
			end
		end
	end
	check(#hits == 0, "no map part within 4 studs of the entrance pad (" .. tostring(hits[1]) .. ")")
	for _, spawn in Mock.Tagged("SpawnLocation") do
		check((spawn.Position - c).Magnitude > 60, "entrance far from the boardwalk spawns")
	end
end

if mode == "off" then
	check(Workspace:FindFirstChild(Entry.FOLDER) == nil, "off: no entrance/pocket folder")
	check(#entryPrompts() == 0, "off: no entry prompts")
	check(lightsOutsideMap() == 0, "off: no pocket lights")
	check(not Entry.IsStarted(), "off: entry not started")
	check(Boot.Runtime() == nil, "off: runtime not started")
	Boot.Disable()
	Mock.Advance(1)
	check(#Mock.Errors == 0, "off: kill switch is harmless")
	finish()
	return
end

-- Flags ON ---------------------------------------------------------------------------------------
local runtime = Boot.Runtime()
check(runtime ~= nil, "on: runtime started")
check(Entry.IsStarted(), "on: entry started")
local folder = Workspace:FindFirstChild(Entry.FOLDER)
check(folder ~= nil, "on: entry folder built")
local origin = Boot.POCKET_ORIGIN

local function sceneSpawns()
	local scene = Workspace:FindFirstChild("SpringVaultAdventure")
	local n = 0
	for _, d in (scene and scene:GetDescendants() or {}) do
		if d:IsA("SpawnLocation") then
			n += 1
		end
	end
	return n, scene
end
local n0, scene0 = sceneSpawns()
check(scene0 ~= nil and n0 == 0, "no SpawnLocation under the arena scene")
local allSpawnsOk = true
for _, d in Workspace:GetDescendants() do
	if d:IsA("SpawnLocation") and d.Enabled and d.Position.Y < S - 10 then
		allSpawnsOk = false
	end
end
check(allSpawnsOk, "no enabled SpawnLocation anywhere under the slab")

-- Entrance prompt at the surface.
local hatch = folder.Entrance.Hatch
local enter = hatch:FindFirstChild("AdventureEntryPrompt")
check(enter ~= nil and enter.ActionText == "Go down" and enter.ObjectText == "Spring Vault", "entrance prompt")
check(math.abs(hatch.Position.Y - Layout.DECK_TOP) < 1, "hatch sits on the surface deck")
check(enter.HoldDuration > 0 and enter.MaxActivationDistance <= 12, "entrance prompt hold + short range")
check(folder.Entrance.Deck.CanCollide == true, "entrance deck is walkable")
local returnPad = folder.Pocket.ReturnPad
local back = returnPad:FindFirstChild("AdventureEntryPrompt")
check(back ~= nil and back.ActionText == "Back to the beach", "return prompt in the pocket")
check(Entry.InArena(returnPad.Position), "return pad inside the arena presence box")
check((returnPad.Position - runtime.Scene.Targets.adventure_exit).Magnitude <= 12, "return pad beside the arena exit")

-- Lighting rig: nothing collides/queries/touches; few shadowless lights; all protected.
local rigParts, collidable, queryable, unprotected, lights, shadowed = 0, 0, 0, 0, 0, 0
for _, d in folder.Pocket:GetDescendants() do
	if d:IsA("BasePart") then
		rigParts += 1
		if d.CanCollide then
			collidable += 1
		end
		if d.Name ~= "ReturnPad" and (d.CanQuery or d.CanTouch) then
			queryable += 1
		end
		if d:GetAttribute("ProtectedGeometry") ~= true then
			unprotected += 1
		end
	elseif d:IsA("PointLight") then
		lights += 1
		if d.Shadows then
			shadowed += 1
		end
	end
end
check(rigParts >= 6 and collidable == 0, "pocket rig has no collidable parts (" .. collidable .. "/" .. rigParts .. ")")
check(queryable == 0, "backdrop/light anchors are CanQuery/CanTouch false")
check(unprotected == 0, "every rig part tagged ProtectedGeometry")
check(lights >= 4 and lights <= 8 and shadowed == 0, "4-8 shadowless lights (" .. lights .. ")")
check(lightsOutsideMap() == lights, "no other lights added")
do
	-- The rig box (backdrop + lights) is clear of map parts and terrain.
	local L = Entry.LIGHTING
	local a = origin + V.new(-L.HalfX, L.FloorY, L.ZMin)
	local b = origin + V.new(L.HalfX, L.CeilingY, L.ZMax)
	local hits = {}
	for _, d in Workspace:FindFirstChild("Map"):GetDescendants() do
		if d:IsA("BasePart") then
			local p, h = d.Position, d.Size / 2
			if
				p.X + h.X > a.X
				and p.X - h.X < b.X
				and p.Y + h.Y > a.Y
				and p.Y - h.Y < b.Y
				and p.Z + h.Z > a.Z
				and p.Z - h.Z < b.Z
			then
				table.insert(hits, d:GetFullName())
			end
		end
	end
	check(#hits == 0, "no map part inside the rig box (" .. tostring(hits[1]) .. ")")
	local solid = 0
	for x = a.X + 2, b.X - 2, 4 do
		for y = a.Y + 2, b.Y + 2, 4 do
			for z = a.Z + 2, b.Z + 2, 4 do
				local voxel = Mock.GetVoxel(V.new(x, y, z))
				if voxel and voxel.Material and tostring(voxel.Material) ~= "Enum.Material.Air" then
					solid += 1
				end
			end
		end
	end
	check(solid == 0, "no terrain inside the rig box (" .. solid .. " voxels)")
end

-- Players -----------------------------------------------------------------------------------------
local function add(userId, name)
	local p = Mock.AddPlayer(userId, name)
	Mock.Advance(2)
	Mock.SpawnCharacter(p, V.new(0, S + 3, 4))
	Mock.Advance(1)
	return p
end
local function pos(p)
	return p.Character.HumanoidRootPart.Position
end
local function atHatch(p)
	p.Character:PivotTo(CF.new(hatch.Position + V.new(3, 3, 0)))
end
local function onSurface(p)
	local y = pos(p).Y
	return y > S and y < S + 12 and not Entry.InPocket(pos(p))
end
local function nearReturn(p)
	return (pos(p) - Entry.SURFACE_RETURN.Position).Magnitude < 1
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
local function trigger(prompt, p)
	Mock.FireEvent(prompt, "Triggered", p)
	Mock.Advance(0.3)
end
local function goDown(p)
	Mock.Advance(Entry.PROMPT_COOLDOWN + 0.1)
	atHatch(p)
	trigger(enter, p)
end
local function participant(p)
	local e = runtime.Event()
	return e and e.Participants[p.UserId]
end
local function join(p)
	local mara = runtime.Scene.Targets.npc_mara
	p.Character:PivotTo(CF.new(mara + V.new(0, 3, 4)))
	runtime.Handle(p, { action = "Join", eventInstanceId = "" })
	Mock.Advance(0.3)
	local m = participant(p)
	return m ~= nil and not m.Left
end

local fresh = add(USER_FRESH, "Fresh")
local cert = add(USER_CERT, "Cert")
local vet = add(USER_VET, "Vet")

-- Ineligible: truthful toast, no teleport; debounced.
atHatch(fresh)
local before, mark = pos(fresh), #Mock.Remote.ToClient
trigger(enter, fresh)
trigger(enter, fresh)
check((pos(fresh) - before).Magnitude < 0.01, "ineligible player is not moved")
check(toasts(fresh, mark, "Rookie certificate") == 1, "ineligible player told how it unlocks (once: debounced)")

-- Too far from the hatch: the server ignores the trigger.
Mock.Advance(2)
fresh.Character:PivotTo(CF.new(hatch.Position + V.new(40, 3, 0)))
mark = #Mock.Remote.ToClient
trigger(enter, cert)
check(onSurface(cert), "trigger from far away (cert at the boardwalk) ignored")

-- Eligible: lands inside the presence box near Mara, clear of NPCs and targets.
goDown(cert)
local p = pos(cert)
check(Entry.InArena(p), "eligible player lands in the arena")
check(
	math.abs(p.X - origin.X) <= 48 and math.abs(p.Z - (origin.Z - 36)) <= 69,
	"arrival inside the runtime presence box"
)
check(math.abs(p.Y - (origin.Y + 3.5)) < 0.5, "arrival stands on the arena floor")
local mara = runtime.Scene.Targets.npc_mara
check((p - mara).Magnitude > 8 and (p - mara).Magnitude < 20, "arrival near Mara, not on her")
local minTarget = math.huge
for _, t in runtime.Scene.Targets do
	minTarget = math.min(minTarget, (V.new(t.X, 0, t.Z) - V.new(p.X, 0, p.Z)).Magnitude)
end
check(minTarget >= 5, "arrival clear of every scene target (" .. string.format("%.1f", minTarget) .. ")")
goDown(vet)
check(Entry.InArena(pos(vet)), "veteran catch-up player can enter too")

-- Return pad (not a participant): back to the beach.
Mock.Advance(2)
cert.Character:PivotTo(CF.new(returnPad.Position + V.new(0, 3, 2)))
trigger(back, cert)
check(onSurface(cert) and nearReturn(cert), "return pad -> beach beside the hatch")
-- The return prompt does nothing from the surface.
Mock.Advance(2)
local here = pos(cert)
trigger(back, cert)
check((pos(cert) - here).Magnitude < 0.01, "return prompt ignored outside the arena")

-- Runtime Leave: the runtime restores to the arena join point; entry lifts to the beach.
goDown(cert)
check(join(cert), "cert joins at Mara")
runtime.Handle(cert, { action = "Leave", eventInstanceId = runtime.Event().EventInstanceId })
check(Entry.InArena(pos(cert)), "runtime Leave restores into the arena (its own return point)")
Mock.Advance(1.5)
check(onSurface(cert) and nearReturn(cert), "after Leave the player is lifted to the beach")

-- Return pad as an active participant: Left first, so nothing pulls them back down later.
check(join(vet), "vet joins")
Mock.Advance(2)
vet.Character:PivotTo(CF.new(returnPad.Position + V.new(0, 3, 2)))
trigger(back, vet)
check(onSurface(vet), "participant return pad -> beach")
check(participant(vet) and participant(vet).Left == true, "participant left the event on the way out")
Mock.Advance(2)
check(onSurface(vet), "still on the beach afterwards (no runtime yank)")

-- Falling below the floor (not a ball-stage participant): lifted at once.
goDown(fresh) -- refused (ineligible): stays
check(onSurface(fresh) or not Entry.InPocket(pos(fresh)), "ineligible still not in the pocket")
goDown(cert)
cert.Character:PivotTo(CF.new(origin + V.new(0, -40, 0)))
Mock.Advance(0.5)
check(onSurface(cert), "fall below the arena floor -> beach")
goDown(cert)
cert.Character:PivotTo(CF.new(origin + V.new(0, -25, 50))) -- off the open near edge
Mock.Advance(0.5)
check(onSurface(cert), "fall off the open near edge -> beach")

-- Q / ReturnToSurface from the pocket: lands on the boardwalk deck at the pocket's X.
Mock.Advance(3)
goDown(cert)
Mock.FireServer("ReturnToSurface", cert)
Mock.Advance(0.5)
local q = pos(cert)
check(math.abs(q.Y - (Layout.DECK_TOP + 3.5)) < 0.5 and math.abs(q.Z - 4) < 0.5, "Q from the pocket -> boardwalk deck")
check(math.abs(q.X - origin.X) < 60, "Q keeps the pocket's X (" .. q.X .. ")")
local deckUnder = false
for _, d in Workspace:FindFirstChild("Map"):GetDescendants() do
	if d:IsA("BasePart") and d.CanCollide then
		local rel, h = d.Position - q, d.Size / 2
		if
			math.abs(rel.X) <= h.X
			and math.abs(rel.Z) <= h.Z
			and math.abs(d.Position.Y + h.Y - Layout.DECK_TOP) < 0.6
		then
			deckUnder = true
		end
	end
end
check(deckUnder, "a collidable deck part is under the Q landing point")

-- Respawn while in the pocket: BeachService puts the new character on a boardwalk spawn.
goDown(cert)
check(Entry.InArena(pos(cert)), "cert back in the arena")
Mock.SpawnCharacter(cert, V.new(0, S + 3, 4))
Mock.Advance(1)
check(onSurface(cert) and math.abs(pos(cert).Z - 4) < 1, "respawn lands on a boardwalk spawn")

-- End of a run: the scene is rebuilt (spawn removed again) and the crew is lifted to the beach.
local cert2 = add(USER_CERT2, "Cert2")
goDown(cert2)
check(join(cert2), "cert2 joins")
local sceneBefore = runtime.Scene.Model
Mock.Advance(45) -- invitation 30 s, ready timeout 10 s, nobody ready: cleanup + rebuild
local n1, scene1 = sceneSpawns()
check(runtime.Scene.Model ~= sceneBefore and scene1 == runtime.Scene.Model, "scene rebuilt after the run")
check(n1 == 0, "no SpawnLocation under the rebuilt scene")
check(onSurface(cert2), "crew lifted to the beach when the run ends")

-- Ball-stage participant below the floor: the runtime's checkpoint recovery goes first.
local cert3 = add(USER_CERT3, "Cert3")
goDown(cert3)
check(join(cert3), "cert3 joins")
local e = runtime.Event()
local m3 = participant(cert3)
e.Phase, e.Stage, e.Deadline = "Active", "ball", math.huge
m3.Ready, m3.Present = true, true
cert3.Character:PivotTo(CF.new(origin + V.new(0, -24, -20)))
Mock.Advance(1)
check(Entry.InPocket(pos(cert3)) and pos(cert3).Y < origin.Y, "grace: entry leaves the runtime recovery alone")
Mock.Advance(1.5)
check(Entry.InArena(pos(cert3)) and pos(cert3).Y > origin.Y, "runtime recovered the hauler to its checkpoint")

-- Kill switch: everyone in the pocket ends on the beach in the same frame.
goDown(cert)
check(Entry.InArena(pos(cert)), "visitor in the arena")
check(Entry.InArena(pos(cert3)) and participant(cert3) and not participant(cert3).Left, "participant in the arena")
Boot.Disable()
check(onSurface(cert) and onSurface(cert3), "kill switch: visitor and participant lifted before any physics step")
check(
	Workspace:FindFirstChild(Entry.FOLDER) == nil and #entryPrompts() == 0,
	"kill switch: entrance, pad and rig removed"
)
check(lightsOutsideMap() == 0, "kill switch: lights removed")
check(not Entry.IsStarted() and Boot.Runtime() == nil, "kill switch: stopped")
Mock.Advance(2)
check(onSurface(cert) and onSurface(cert3), "still on the beach after the kill switch")
finish()
