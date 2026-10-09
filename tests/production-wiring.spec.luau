--!nocheck
--[[
	Production wiring for the expansion adventure (docs/integration/production-wiring.md).
	  luau tests/production-wiring.spec.luau            eligibility rules + Main booted, flags OFF
	  luau tests/production-wiring.spec.luau -a on      Main booted with every flag ON
	  luau tests/production-wiring.spec.luau -a rejoin  held-rejoin settlement contract
	"on" and "rejoin" need Codex's Spring Vault gameplay files (BroadwaveDigBridge, DigBroadwave,
	held rejoin); without them they print SKIPPED and pass.
	MOCK COVERAGE ONLY: headless mock, in-memory DataStore, no real clients or devices.
]]

local Mock = require("./mock/Roblox")
local mode = ({ ... })[1] or "off"
Mock.Init(require("../build/test/generated"), if mode == "client" then { Client = true } else nil)
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
	print(string.format("PRODUCTION WIRING (%s): %d passed, %d failed", mode, passes, failures))
	if failures > 0 then
		error("PRODUCTION WIRING SPEC FAILED")
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
local hasOverlay = byPath["ServerScriptService/Server/Adventure/BroadwaveDigBridge"] ~= nil

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

-- Client arbitration -----------------------------------------------------------------------------
if mode == "client" then
	local Enum = Mock.Enum
	local Remotes = load("ReplicatedStorage/Shared/Remotes")
	local net = Mock.Env.Instance.new("Folder")
	net.Name = "Net"
	for _, name in Remotes.Events do
		local r = Mock.Env.Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = net
	end
	net.Parent = byPath["ReplicatedStorage/Shared/Remotes"]
	local player = Mock.AddLocalPlayer(1001, "Tester")
	Mock.SpawnCharacter(player, V.new(0, S + 3, 4))
	local Controllers = "StarterPlayer/StarterPlayerScripts/Client/Controllers/"
	local Arbiter = load(Controllers .. "InputArbiter")
	local InputController = load(Controllers .. "InputController")
	local DigController = load(Controllers .. "DigController")
	local AdventureController = load(Controllers .. "AdventureController")
	InputController.Init()
	local action = Mock.Actions.DigSurface
	check(action ~= nil, "DigSurface bound")
	local function press(key)
		local before = #Mock.Remote.ToServer
		local result = action.Fn("DigSurface", Enum.UserInputState.Begin, Mock.Input(Enum.UserInputType.Keyboard, key))
		local fired = false
		for i = before + 1, #Mock.Remote.ToServer do
			if Mock.Remote.ToServer[i].Name == "ReturnToSurface" then
				fired = true
			end
		end
		return result, fired
	end
	local r, fired = press(Enum.KeyCode.Q)
	check(r == Enum.ContextActionResult.Sink and fired, "Q surfaces without a Broadwave tool")
	local loan = Mock.Env.Instance.new("Tool")
	loan.Name = "Broadwave (Adventure Loan)"
	loan:SetAttribute("AdventureLoan", true)
	loan.Parent = player.Character
	check(Arbiter.BroadwaveEquipped(), "loan counts as Broadwave equipped")
	r, fired = press(Enum.KeyCode.Q)
	check(r == Enum.ContextActionResult.Pass and not fired, "Q passes to the Broadwave charge while equipped")
	r, fired = press(Enum.KeyCode.ButtonX)
	check(r == Enum.ContextActionResult.Sink and fired, "ButtonX always surfaces")
	loan:Destroy()
	local licensed = Mock.Env.Instance.new("Tool")
	licensed:SetAttribute("ToolId", "tool_broadwave")
	licensed.Parent = player.Character
	check(Arbiter.BroadwaveEquipped(), "licensed tool counts as Broadwave equipped")
	licensed:Destroy()
	check(not Arbiter.BroadwaveEquipped(), "nothing equipped")
	-- Named dig pauses never clobber each other.
	check(not Arbiter.DigBlocked(), "digging open by default")
	Arbiter.Suppress("AdventureHauling", true)
	Arbiter.Suppress("AdventureArena", true)
	Arbiter.Suppress("AdventureHauling", false)
	check(Arbiter.DigBlocked(), "one remaining reason still blocks")
	check(DigController.TryDigAt(V.new(0, S, -30)) == false, "DigController refuses while blocked")
	Arbiter.Suppress("AdventureArena", false)
	check(not Arbiter.DigBlocked(), "released when every reason is released")
	-- Start gate: nothing until the server creates the remotes folder.
	local RS = Mock.Service("ReplicatedStorage")
	AdventureController.Init()
	Mock.Advance(1)
	check(not AdventureController.IsStarted(), "client adapter idle without server remotes (flag off)")
	check(Mock.Actions.SpringVaultBroadwave == nil, "no Broadwave binding while off")
	-- The server (flag on) creates the remotes and the arena: the adapter starts the runtime UI.
	local scene = Mock.Env.Instance.new("Model")
	scene.Name = "SpringVaultAdventure"
	local floor = Mock.Env.Instance.new("Part")
	floor.Name = "ProtectedArenaFloor"
	floor.Size = V.new(100, 2, 140)
	floor.Position = V.new(-200, 969, 70)
	floor.Parent = scene
	scene.Parent = Mock.Service("Workspace")
	local folder = Mock.Env.Instance.new("Folder")
	folder.Name = "SpringVaultAdventure"
	local snapshot
	for _, name in { "Intent", "Snapshot", "Effect" } do
		local r = Mock.Env.Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = folder
		if name == "Snapshot" then
			snapshot = r
		end
	end
	folder.Parent = RS
	Mock.Advance(1)
	check(AdventureController.IsStarted(), "adapter starts SpringVaultClient once the server remotes exist")
	check(Mock.Actions.SpringVaultBroadwave ~= nil, "Broadwave charge bound (Q / L1)")
	Mock.FireEvent(snapshot, "OnClientEvent", { hauling = true, joined = true, stage = "ball", phase = "Active" })
	Mock.Advance(0.1)
	check(Arbiter.DigBlocked(), "hauling snapshot pauses ordinary digging")
	Mock.FireEvent(snapshot, "OnClientEvent", { hauling = false, joined = true, stage = "ball", phase = "Active" })
	Mock.Advance(0.1)
	check(not Arbiter.DigBlocked(), "detaching resumes digging")
	player.Character:PivotTo(CF.new(-200, 973, 70))
	Mock.Advance(0.5)
	check(Arbiter.DigBlocked(), "standing in the arena (dialogue/objectives) pauses digging")
	player.Character:PivotTo(CF.new(0, S + 3, 4))
	Mock.Advance(0.5)
	check(not Arbiter.DigBlocked(), "leaving the arena resumes digging")

	-- Broadwave equip toggle (UI/BroadwaveEquip; docs/integration/licensed-broadwave.md) -------
	local Equip = load("StarterPlayer/StarterPlayerScripts/Client/UI/BroadwaveEquip")
	local Layout = load("StarterPlayer/StarterPlayerScripts/Client/UI/Layout")
	local function sentSince(before)
		return #Mock.Remote.ToServer - before
	end
	local function newTool(name, attrs, parent)
		local t = Mock.Env.Instance.new("Tool")
		t.Name = name
		for k, v in attrs do
			t:SetAttribute(k, v)
		end
		t.Parent = parent
		return t
	end
	Mock.Advance(0.5)
	check(Equip.Gui == nil and Equip.Button == nil, "equip: nothing built without a Broadwave tool")
	check(Mock.Actions.BroadwaveEquip == nil, "equip: no key binding without a Broadwave tool")
	check(Equip.State().Visible == false, "equip: hidden without a Broadwave tool")
	local shovel = newTool("Shovel", { ShovelId = "starter" }, player.Backpack)
	Mock.Advance(0.2)
	check(Equip.Gui == nil, "equip: a shovel alone builds nothing")
	local loanTool = newTool("Broadwave (Adventure Loan)", { AdventureLoan = true }, player.Backpack)
	Mock.Advance(0.2)
	local state = Equip.State()
	check(Equip.Gui ~= nil and state.Visible, "equip: shows once the loan is in the Backpack")
	check(state.Label == "Broadwave (loan)", "equip: loan label is 'Broadwave (loan)'")
	check(Equip.Button.Label.Text == "Broadwave\n(loan)", "equip: loan caption")
	check(not state.Equipped and Equip.Button.Face.BackgroundColor3 == Equip.STOWED_COLOR, "equip: stowed colour")
	local bindingKeys = Mock.Actions.BroadwaveEquip and Mock.Actions.BroadwaveEquip.Keys or {}
	check(
		table.find(bindingKeys, Enum.KeyCode.Z) ~= nil and table.find(bindingKeys, Enum.KeyCode.ButtonR1) ~= nil,
		"equip: bound to Z and ButtonR1"
	)
	check(
		table.find(bindingKeys, Enum.KeyCode.Q) == nil and table.find(bindingKeys, Enum.KeyCode.ButtonL1) == nil,
		"equip: never takes the Q / L1 charge keys"
	)
	local holder = Equip.Button.Holder
	local region = Layout.Current().Broadwave
	check(
		holder.Position.X.Offset == region.X
			and holder.Position.Y.Offset == region.Y
			and holder.Size.Y.Offset == region.H,
		"equip: placed by the Layout Broadwave region"
	)
	-- Keyboard Z equips the loan locally; no remote is fired.
	local before = #Mock.Remote.ToServer
	local key = Mock.Actions.BroadwaveEquip
	local result =
		key.Fn("BroadwaveEquip", Enum.UserInputState.Begin, Mock.Input(Enum.UserInputType.Keyboard, Enum.KeyCode.Z))
	Mock.Advance(0.1)
	check(result == Enum.ContextActionResult.Sink, "equip: Z sinks")
	check(loanTool.Parent == player.Character, "equip: Z equips the loan")
	check(sentSince(before) == 0, "equip: equipping fires no remote")
	check(Equip.State().Equipped and Equip.Button.Face.BackgroundColor3 == Equip.IN_HAND_COLOR, "equip: in-hand colour")
	check(Arbiter.BroadwaveEquipped(), "equip: InputArbiter sees the Broadwave in hand (Q goes to the charge)")
	check(DigController.TryDigAt(V.new(0, S, -30)) == false, "equip: ordinary digging pauses with a Broadwave in hand")
	check(sentSince(before) == 0, "equip: paused dig sends nothing")
	-- Gamepad R1 puts it away and re-equips the shovel.
	Mock.Advance(0.3)
	key.Fn("BroadwaveEquip", Enum.UserInputState.Begin, Mock.Input(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR1))
	Mock.Advance(0.1)
	check(
		loanTool.Parent == player.Backpack and shovel.Parent == player.Character,
		"equip: R1 puts it away, shovel back"
	)
	check(not Arbiter.BroadwaveEquipped() and not Equip.State().Equipped, "equip: stowed again")
	check(sentSince(before) == 0, "equip: unequipping fires no remote")
	-- Debounce: a double press within 0.2 s is one toggle.
	Mock.Advance(0.3)
	check(Equip.Toggle() == true and Equip.Toggle() == false, "equip: debounced double press")
	Mock.Advance(0.3)
	Equip.Toggle()
	Mock.Advance(0.1)
	check(shovel.Parent == player.Character, "equip: back to the shovel")
	-- Touch / mouse: the button itself.
	Mock.Advance(0.3)
	Mock.FireEvent(Equip.Button.Face, "Activated")
	Mock.Advance(0.1)
	check(loanTool.Parent == player.Character, "equip: tapping the button equips")
	Mock.Advance(0.3)
	Mock.FireEvent(Equip.Button.Face, "Activated")
	Mock.Advance(0.1)
	check(loanTool.Parent == player.Backpack, "equip: tapping again puts it away")
	-- Licensed tool: different label; with both, the arena prefers the loan, elsewhere the license.
	local licensedTool = newTool("Broadwave", { ToolId = "tool_broadwave", LicensedBroadwave = true }, player.Backpack)
	Mock.Advance(0.2)
	check(Equip.State().Label == "Broadwave", "equip: outside the arena targets the licensed tool")
	check(Equip.Button.Label.Text == "Broadwave", "equip: licensed caption has no loan marker")
	player.Character:PivotTo(CF.new(-200, 973, 70))
	Mock.Advance(0.5)
	check(Equip.State().Label == "Broadwave (loan)", "equip: in the arena targets the loan")
	check(Equip.Button.Label.Text == "Broadwave\n(loan)", "equip: arena caption follows the target")
	player.Character:PivotTo(CF.new(0, S + 3, 4))
	Mock.Advance(0.5)
	Equip.Toggle()
	Mock.Advance(0.1)
	check(licensedTool.Parent == player.Character, "equip: equips the licensed tool")
	check(Equip.State().Label == "Broadwave", "equip: an equipped tool wins over the arena preference")
	-- Removal: loan returned, license removed -> hidden and unbound.
	loanTool:Destroy()
	Mock.Advance(0.2)
	check(Equip.State().Visible, "equip: still shown while the licensed tool remains")
	licensedTool:Destroy()
	Mock.Advance(0.2)
	check(Equip.State().Visible == false, "equip: hidden when the last Broadwave goes")
	check(Mock.Actions.BroadwaveEquip == nil, "equip: key binding removed with the last Broadwave")
	check(Mock.Actions.DigSurface ~= nil, "equip: DigSurface (Q / ButtonX) untouched")
	-- Respawn: a fresh Backpack; the control follows the new one.
	Mock.SpawnCharacter(player, V.new(0, S + 3, 4))
	Mock.Advance(0.5)
	check(Equip.State().Visible == false, "equip: hidden after respawn without tools")
	local relent = newTool("Broadwave (Adventure Loan)", { AdventureLoan = true }, player.Backpack)
	Mock.Advance(0.2)
	check(Equip.State().Visible and Mock.Actions.BroadwaveEquip ~= nil, "equip: shows for a tool in the new Backpack")
	Mock.SpawnCharacter(player, V.new(0, S + 3, 4))
	Mock.Advance(0.5)
	check(relent.Parent == nil, "respawn destroyed the old Backpack's tool")
	check(Equip.State().Visible == false and Mock.Actions.BroadwaveEquip == nil, "equip: cleaned up on respawn")
	finish()
	return
end

-- Rejoin contract (Codex's SpringVaultState + our AdventureRewards) ----------------------------
if mode == "rejoin" then
	local stateModule = byPath["ServerScriptService/Server/Adventure/SpringVaultState"]
	local SVConfig = load("ReplicatedStorage/Shared/Adventure/SpringVaultConfig")
	local State = Mock.Require(stateModule)
	local Rewards = load("ReplicatedStorage/Shared/Rewards/AdventureRewards")
	local s = State.new(SVConfig, "guid:1", 1, 0)
	s:join(2, 0)
	if not hasOverlay then
		print("SKIPPED (Spring Vault gameplay files absent)")
		finish()
		return
	end
	s:start(1, 5)
	s:ready(1, 5)
	s:ready(2, 5)
	s:tick(5)
	check(s.Phase == "Active", "crew active")
	-- Both dig; user 2 disconnects after the excavation stage, then rejoins inside the hold.
	local now = 6
	for _, id in SVConfig.AnchorIds do
		for _ = 1, s.Anchors[id].Required do
			s:hitAnchor(1, id, now)
			s:hitAnchor(2, id, now)
			now += SVConfig.HitCooldownSeconds
		end
	end
	check(table.find(s.CompletedStages, "excavation") ~= nil, "excavation done")
	local function observation(stageId)
		local list = {}
		for userId, p in s.Participants do
			table.insert(list, {
				UserId = userId,
				Points = p.Points,
				ObjectiveIds = table.clone(p.Objectives),
				Connected = p.Connected,
				Left = p.Left,
			})
		end
		return {
			BoundaryVersion = 1,
			EventInstanceId = s.EventInstanceId,
			EventId = "event_vault",
			LandmarkId = "landmark_spring_vault",
			RegionId = "sunshine_shore",
			StageId = stageId,
			CompletedStages = table.clone(s.CompletedStages),
			Participants = list,
		}
	end
	local function paid(decisions, userId)
		for _, d in decisions or {} do
			if d.UserId == userId and d.Intent ~= nil then
				return true
			end
		end
		return false
	end
	local excav = Rewards.StageDecisions(observation("excavation"), 1000)
	check(paid(excav, 2), "user 2 paid for excavation while connected")
	s:leave(2, now, true)
	check(s.Participants[2].Connected == false and not s.Participants[2].Left, "held after disconnect")
	s:openVault(1, now + 1)
	local vault = Rewards.StageDecisions(observation("vault_open"), 1000)
	check(not paid(vault, 2), "held (disconnected) user 2 gets no vault_open stage pay")
	local ok, why = s:join(2, now + 30)
	check(ok and why == "rejoined", "rejoin within hold: " .. tostring(why))
	check(s.Participants[2].Points > 0, "contribution preserved")
	local again = s:join(2, now + 31)
	check(again == false, "second join is not a second admission")
	s:latch(1, true, now + 32)
	s:latch(2, true, now + 32)
	local t = now + 33
	for _, gate in SVConfig.GateIds do
		s:advanceBallGate(gate, t, { [1] = 5, [2] = 5 })
		t += 1
	end
	local context = s:completionContext(t)
	local p2
	for _, p in context.Participants do
		if p.UserId == 2 then
			p2 = p
		end
	end
	check(p2 and p2.Eligible == true, "rejoined contributor is Eligible at completion")
	context.ContentVersion = 1
	local final = Rewards.FinalDecisions(context, 1000)
	check(paid(final, 2), "rejoined contributor gets the final")
	-- Receipts are per (instance, user, stage): a replayed stage observation is a Duplicate.
	local r1 = Rewards.StageReceiptId(s.EventInstanceId, 2, "excavation", 1)
	local r2 = Rewards.StageReceiptId(s.EventInstanceId, 2, "excavation", 1)
	check(r1 == r2, "stage receipt id is stable across rejoin (dedupe key)")
	-- An expired hold cannot be recovered.
	local s2 = State.new(SVConfig, "guid:2", 1, 0)
	s2:join(2, 0)
	s2:leave(2, 1, true)
	check(s2:join(2, 1 + SVConfig.DisconnectHoldSeconds) == false, "expired hold refused")
	finish()
	return
end

-- Pure eligibility rules ------------------------------------------------------------------------
local Eligibility = load("ServerScriptService/Server/Services/AdventureEligibility")
local Rules = Eligibility.Rules
if mode == "off" then
	local fresh = Config.NewPlayerData()
	check(Rules.CanEnter(nil) == false, "nil save cannot enter")
	check(Rules.CanEnter(fresh) == false, "fresh save cannot enter")
	local rich = Config.NewPlayerData()
	rich.Coins, rich.MaxDepth, rich.TotalSandDug, rich.Rebirths = 1e12, 880, 1e9, 5
	check(Rules.CanEnter(rich) == false, "money/depth/rebirths alone never admit")
	local cert = Config.NewPlayerData()
	cert.Certifications = { cert_rookie = { At = 1, Source = "q_mara" } }
	check(select(2, Rules.CanEnter(cert)) == "Certified", "cert_rookie admits")
	local badCert = Config.NewPlayerData()
	badCert.Certifications = { cert_rookie = true }
	check(Rules.CanEnter(badCert) == false, "malformed cert record does not admit")
	local sold = Config.NewPlayerData()
	sold.Quests = { daily_sell_10 = { Progress = 2, Claimed = false, Day = 1 } }
	check(Rules.HasSaleEvidence(sold) and not Rules.CanEnter(sold), "sale alone is not enough")
	local found = Config.NewPlayerData()
	found.FindVariants = { ["gold_coin/Large"] = true }
	check(Rules.HasDepositEvidence(found) and not Rules.CanEnter(found), "deposit alone is not enough")
	local ambient = Config.NewPlayerData()
	ambient.Quests = { daily_sell_10 = { Progress = 2 } }
	ambient.FindVariants = { ["gold_coin/Normal"] = true, ["gold_coin/None"] = true }
	check(Rules.CanEnter(ambient) == false, "ambient-only finds are not deposit evidence")
	local veteran = Config.NewPlayerData()
	veteran.Quests = { daily_sell_10 = { Progress = 0, Claimed = true } }
	veteran.FindVariants = { ["gold_coin/Normal"] = true, ["gold_coin/Gold"] = true }
	check(select(2, Rules.CanEnter(veteran)) == "CatchUp", "veteran catch-up from recorded sale + deposit")
	local zeroSale = Config.NewPlayerData()
	zeroSale.Quests = { daily_sell_10 = { Progress = 0, Claimed = false } }
	zeroSale.FindVariants = { ["gold_coin/Gold"] = true }
	check(Rules.CanEnter(zeroSale) == false, "a reset (0) quest entry is not sale evidence")
	check(Rules.CanTrial(nil) == false and Rules.CanTrial(fresh) == false, "starter shovel only: no trial")
	local bought = Config.NewPlayerData()
	bought.OwnedShovels[pricedShovel()] = true
	check(Rules.CanTrial(bought) == true, "first priced shovel unlocks Pip's trial")
	local fakeShovel = Config.NewPlayerData()
	fakeShovel.OwnedShovels.not_a_shovel = true
	check(Rules.CanTrial(fakeShovel) == false, "unknown shovel id ignored")
	check(Rules.HasBroadwaveLicense(fresh) == false, "no license by default")
	local licensed = Config.NewPlayerData()
	licensed.ToolLicenses = { tool_broadwave = { At = 1 } }
	check(Rules.HasBroadwaveLicense(licensed) == true, "saved license record recognised")
	local boolLicense = Config.NewPlayerData()
	boolLicense.ToolLicenses = { tool_broadwave = true }
	check(Rules.HasBroadwaveLicense(boolLicense) == false, "malformed license not recognised")
	local otherLicense = Config.NewPlayerData()
	otherLicense.Licenses = { tool_broadwave = { At = 1 } }
	check(Rules.HasBroadwaveLicense(otherLicense) == false, "only ToolLicenses counts")
end

-- Boot Main -------------------------------------------------------------------------------------
local Flags = load("ServerScriptService/Server/Services/AdventureFlags")
check(
	Flags.SpringVault == false and Flags.AdventureRewards == false and Flags.BroadwaveOrdinary == false,
	"every adventure flag ships off"
)
if mode == "on" then
	if not hasOverlay then
		print("SKIPPED (Spring Vault gameplay files absent)")
		finish()
		return
	end
	Flags.SpringVault, Flags.AdventureRewards, Flags.BroadwaveOrdinary = true, true, true
end

local USER_FRESH, USER_CERT, USER_VET, USER_RICH, USER_LIC = 9301, 9302, 9303, 9304, 9305
save(USER_FRESH)
save(USER_CERT, function(d)
	d.Certifications = { cert_rookie = { At = 1, Source = "test" } }
end)
save(USER_VET, function(d)
	d.Quests = { daily_sell_10 = { Progress = 3, Claimed = false, Day = 1 } }
	d.FindVariants = { ["gold_coin/Gold"] = true }
end)
save(USER_RICH, function(d)
	d.Coins, d.MaxDepth, d.Rebirths = 1e12, 880, 3
end)
save(USER_LIC, function(d)
	d.ToolLicenses = { tool_broadwave = { At = 1, Source = "test" } }
	d.OwnedShovels[pricedShovel()] = true
end)

Mock.RunScript(byPath["ServerScriptService/Server/Main"])
Mock.Advance(25)
check(#Mock.Errors == 0, "Main boots")

local ReplicatedStorage = Mock.Service("ReplicatedStorage")
local Workspace = Mock.Service("Workspace")
local Boot = load("ServerScriptService/Server/Services/AdventureBoot")
local Settlement = load("ServerScriptService/Server/Services/AdventureSettlement")
local Data = load("ServerScriptService/Server/Services/DataService")
local World = load("ServerScriptService/Server/World")

-- The pocket: outside digging, protected footprints, map parts and terrain (either mode).
check(Boot.PocketIsSafe(Boot.POCKET_ORIGIN), "pocket clear of dig zone and protected footprints")
check(not Boot.PocketIsSafe(V.new(0, S - 20, -36)), "a pocket over the dig zone is refused")
do
	local a, b = Boot.POCKET_ORIGIN + Boot.POCKET_MIN, Boot.POCKET_ORIGIN + Boot.POCKET_MAX
	local hits = {}
	local map = Workspace:FindFirstChild("Map")
	for _, d in (map and map:GetDescendants() or {}) do
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
	check(#hits == 0, "no map part inside the pocket (" .. tostring(hits[1]) .. ")")
	local solid = 0
	for x = a.X + 2, b.X - 2, 4 do
		for y = a.Y + 2, b.Y + 8, 4 do
			for z = a.Z + 2, b.Z - 2, 4 do
				local voxel = Mock.GetVoxel(V.new(x, y, z))
				if voxel and voxel.Material and tostring(voxel.Material) ~= "Enum.Material.Air" then
					solid += 1
				end
			end
		end
	end
	check(solid == 0, "no terrain inside the pocket (" .. solid .. " voxels)")
end

local function add(userId, name)
	local p = Mock.AddPlayer(userId, name)
	Mock.Advance(2)
	Mock.SpawnCharacter(p, V.new(0, S + 3, 4))
	Mock.Advance(1)
	return p
end

if mode == "off" then
	check(ReplicatedStorage:FindFirstChild("SpringVaultAdventure") == nil, "off: no adventure remotes")
	check(Workspace:FindFirstChild("SpringVaultAdventure") == nil, "off: no arena")
	check(Boot.Runtime() == nil, "off: runtime not started")
	check(Eligibility.IsOrdinaryEnabled() == false, "off: ordinary Broadwave disabled")
	local lic = add(USER_LIC, "Licensed")
	check(lic.Backpack:FindFirstChild("Broadwave") == nil, "off: licensed player gets no tool")
	local fake = Mock.Env.Instance.new("Tool")
	fake.Name = "Broadwave"
	fake:SetAttribute("ToolId", "tool_broadwave")
	fake.Parent = lic.Character
	Eligibility.RegisterIssuedTool(fake, lic)
	check(Eligibility.CanUseBroadwave(lic, fake) == false, "off: even an issued tool with a license is refused")
	check(Eligibility.CanEnter(lic) == false, "licensed-only save cannot enter (no cert)")
	local cert = add(USER_CERT, "Cert")
	check(Eligibility.CanEnter(cert) == true, "player wrapper reads the loaded save")
	Mock.RemovePlayer(cert)
	Mock.Advance(1)
	check(Eligibility.CanEnter(cert) == false, "not loaded -> false")
	local opts = Boot.Options({ AdventureRewards = false, BroadwaveOrdinary = false })
	check(opts.OnStage == nil and opts.OnOrdinaryBroadwave == nil, "rewards/ordinary off: no callbacks")
	local accepted = opts.OnCompletion({})
	check(accepted == false, "rewards off: completion refused truthfully")
	check(opts.Origin == Boot.POCKET_ORIGIN and opts.CanEnter and opts.CanTrial, "admission callbacks wired")
	finish()
	return
end

-- Flags ON -------------------------------------------------------------------------------------
local runtime = Boot.Runtime()
check(runtime ~= nil, "on: runtime started")
check(ReplicatedStorage:FindFirstChild("SpringVaultAdventure") ~= nil, "on: adventure remotes exist")
local scene = Workspace:FindFirstChild("SpringVaultAdventure")
check(scene ~= nil, "on: arena built")
local spawns, enabledSpawns = 0, 0
for _, d in scene:GetDescendants() do
	if d:IsA("SpawnLocation") then
		spawns += 1
		if d.Enabled ~= false then
			enabledSpawns += 1
		end
	end
end
-- Either the scene has no spawn (PR #33: ReviewSpawn defaults false) or AdventureBoot disabled it.
check(enabledSpawns == 0, "no enabled arena spawn (players never spawn in the pocket; " .. spawns .. " found)")
check(Eligibility.IsOrdinaryEnabled() == true, "on: ordinary Broadwave enabled")
local opts = Boot.Options(Flags)
check(opts.OnStage == Settlement.OnStage and opts.OnCompletion == Settlement.OnCompletion, "rewards wired")
check(type(opts.OnOrdinaryBroadwave) == "function", "bridge wired")
check(opts.ResolveTool ~= nil, "licensed-tool resolver wired (licensed-broadwave.md)")

local targets = runtime.Scene.Targets
local function at(p, pos)
	p.Character:PivotTo(CF.new(pos + V.new(0, 3, 2)))
end
local function joined(p)
	local e = runtime.Event()
	return e ~= nil and e.Participants[p.UserId] ~= nil
end
local fresh = add(USER_FRESH, "Fresh")
local cert = add(USER_CERT, "Cert")
local vet = add(USER_VET, "Vet")
local rich = add(USER_RICH, "Rich")
local lic = add(USER_LIC, "Licensed")
for _, p in { fresh, rich, cert, vet } do
	at(p, targets.npc_mara)
	runtime.Handle(p, { action = "Join", eventInstanceId = "" })
	Mock.Advance(0.2)
end
check(not joined(fresh), "fresh player refused at Mara")
check(not joined(rich), "rich/deep player without evidence refused")
check(joined(cert), "cert_rookie player admitted")
check(joined(vet), "veteran catch-up player admitted")

at(fresh, targets.npc_pip)
runtime.Handle(fresh, { action = "Talk", targetId = "npc_pip" })
check(runtime.ReviewPlayer(fresh).Trial == nil, "no shovel purchase: no Pip trial")
at(lic, targets.npc_pip)
runtime.Handle(lic, { action = "Talk", targetId = "npc_pip" })
check(runtime.ReviewPlayer(lic).Trial ~= nil, "first shovel purchase: Pip trial starts")

-- Licensed tool + bridge
Mock.Advance(1)
local licensedTool = lic.Backpack:FindFirstChild("Broadwave")
check(
	licensedTool ~= nil and licensedTool:GetAttribute("ToolId") == "tool_broadwave",
	"licensed tool issued with ToolId"
)
check(licensedTool and licensedTool:GetAttribute("ShovelId") == nil, "licensed tool is not a shovel")
check(Data.Get(lic).OwnedShovels.tool_broadwave == nil, "not added to shovel ownership")
check(fresh.Backpack:FindFirstChild("Broadwave") == nil, "unlicensed player gets no tool")
local zone = World.GetDigZone()
local point = V.new(300, S, zone.CFrame.Position.Z)
local function stand(p)
	for _, old in p.Character:GetChildren() do
		if old:IsA("Tool") then
			old.Parent = p.Backpack
		end
	end
	p.Character:PivotTo(CF.lookAt(point + V.new(0, 3, 4), point + V.new(0, 3, -4)))
end
stand(lic)
licensedTool.Parent = lic.Character
check(Eligibility.CanUseBroadwave(lic, licensedTool) == true, "licensed, issued, equipped -> CanUse")
local root = lic.Character.HumanoidRootPart
local look = V.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
Mock.ServerTerrainRaycast = true
local dug0 = Data.Get(lic).TotalSandDug
local ok = opts.OnOrdinaryBroadwave(lic, CF.lookAt(root.Position, root.Position + look), 1)
check(ok == true and Data.Get(lic).TotalSandDug > dug0, "licensed ordinary Broadwave scoops sand via DigBroadwave")
-- Loan equipped instead: refused even for a licensed player.
local loan = lic.Backpack:FindFirstChild("Broadwave (Adventure Loan)")
check(loan ~= nil, "trial loan exists")
stand(lic)
loan.Parent = lic.Character
check(Eligibility.CanUseBroadwave(lic, loan) == false, "adventure loan never satisfies CanUse")
local fake = Mock.Env.Instance.new("Tool")
fake.Name = "Broadwave"
fake:SetAttribute("ToolId", "tool_broadwave")
stand(lic)
fake.Parent = lic.Character
check(Eligibility.CanUseBroadwave(lic, fake) == false, "a tool with the right name/attribute but not issued is refused")
-- Unlicensed player holding a (mis)issued tool still fails on the license record.
local stray = Mock.Env.Instance.new("Tool")
stray:SetAttribute("ToolId", "tool_broadwave")
stray.Parent = fresh.Character
Eligibility.RegisterIssuedTool(stray, fresh)
check(Eligibility.CanUseBroadwave(fresh, stray) == false, "no license record -> refused")
-- Respawn re-issues the licensed tool.
Mock.SpawnCharacter(lic, V.new(0, S + 3, 4))
Mock.Advance(1)
check(lic.Backpack:FindFirstChild("Broadwave") ~= nil, "licensed tool re-issued after respawn")

-- Kill switch
Boot.Disable()
Mock.Advance(1)
check(Boot.Runtime() == nil, "kill switch: runtime stopped")
check(ReplicatedStorage:FindFirstChild("SpringVaultAdventure") == nil, "kill switch: remotes removed")
check(Workspace:FindFirstChild("SpringVaultAdventure") == nil, "kill switch: arena removed")
check(lic.Backpack:FindFirstChild("Broadwave") == nil, "kill switch: licensed tool removed")
check(Eligibility.IsOrdinaryEnabled() == false, "kill switch: ordinary Broadwave disabled")
check(Settlement.SettleStage({}).Error == "Disabled", "kill switch: settlement refuses new grants")
check(Data.Get(lic).ToolLicenses.tool_broadwave ~= nil, "kill switch never touches saved licenses")
finish()
