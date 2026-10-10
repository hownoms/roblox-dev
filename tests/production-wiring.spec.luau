--!nocheck
--[[
	Production wiring for the expansion adventure (docs/integration/production-wiring.md).
	  luau tests/production-wiring.spec.luau            eligibility rules + Main booted, flags OFF
	  luau tests/production-wiring.spec.luau -a on      Main booted with every flag ON
	  luau tests/production-wiring.spec.luau -a rejoin  held-rejoin settlement contract
	  luau tests/production-wiring.spec.luau -a client  client arbitration (AdventureController)
	  luau tests/production-wiring.spec.luau -a client-stream  runtime from the remotes before the arena
	"on" and "rejoin" need Codex's Spring Vault gameplay files (BroadwaveDigBridge, DigBroadwave,
	held rejoin); without them they print SKIPPED and pass.
	MOCK COVERAGE ONLY: headless mock, in-memory DataStore, no real clients or devices.
]]

local Mock = require("./mock/Roblox")
local mode = ({ ... })[1] or "off"
Mock.Init(
	require("../build/test/generated"),
	if mode == "client" or mode == "client-stream" then { Client = true } else nil
)
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
	local BEACH = V.new(0, S + 3, 4)
	local ARENA = CF.new(-200, 973, 70)
	Mock.SpawnCharacter(player, BEACH)
	local Controllers = "StarterPlayer/StarterPlayerScripts/Client/Controllers/"
	local UI = "StarterPlayer/StarterPlayerScripts/Client/UI/"
	local Arbiter = load(Controllers .. "InputArbiter")
	local InputController = load(Controllers .. "InputController")
	local DigController = load(Controllers .. "DigController")
	local AdventureController = load(Controllers .. "AdventureController")
	local Equip = load(UI .. "BroadwaveEquip")
	local Layout = load(UI .. "Layout")
	local AdventureHUD = load(UI .. "AdventureHUD")
	local Root = load(UI .. "Root")
	local Toasts = load(UI .. "Toasts")
	local ObjectiveBanner = load(UI .. "ObjectiveBanner")
	local RS = Mock.Service("ReplicatedStorage")
	local Workspace = Mock.Service("Workspace")
	-- The mock defaults ScreenGui.Enabled to false; Roblox defaults it to true and neither the
	-- runtime nor production ever changes it.
	player.PlayerGui.ChildAdded:Connect(function(child)
		if child:IsA("ScreenGui") then
			Mock.Internal(child).props.Enabled = true
		end
	end)
	Root.Init()
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
	local function sentSince(before, name)
		local n = 0
		for i = before + 1, #Mock.Remote.ToServer do
			if name == nil or Mock.Remote.ToServer[i].Name == name then
				n += 1
			end
		end
		return n
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
	local function reasons()
		return table.concat(Arbiter.Reasons(), ",")
	end
	local function toBeach()
		player.Character:PivotTo(CF.new(0, S + 3, 4))
	end

	-- Q: surfaces unless a Broadwave is in hand AND the runtime's charge is bound.
	local r, fired = press(Enum.KeyCode.Q)
	check(r == Enum.ContextActionResult.Sink and fired, "Q surfaces without a Broadwave tool")
	local loan = newTool("Broadwave (Adventure Loan)", { AdventureLoan = true }, player.Character)
	check(Arbiter.BroadwaveEquipped(), "loan counts as Broadwave equipped")
	r, fired = press(Enum.KeyCode.Q)
	check(r == Enum.ContextActionResult.Sink and fired, "Q still surfaces with a Broadwave in hand but no charge bound")
	Arbiter.SetChargeAvailable(true)
	r, fired = press(Enum.KeyCode.Q)
	check(r == Enum.ContextActionResult.Pass and not fired, "Q passes to the Broadwave charge while equipped and bound")
	r, fired = press(Enum.KeyCode.ButtonX)
	check(r == Enum.ContextActionResult.Sink and fired, "ButtonX always surfaces")
	loan:Destroy()
	r, fired = press(Enum.KeyCode.Q)
	check(r == Enum.ContextActionResult.Sink and fired, "Q surfaces again once the Broadwave is gone")
	Arbiter.SetChargeAvailable(false)
	local licensed = newTool("Broadwave", { ToolId = "tool_broadwave" }, player.Character)
	check(Arbiter.BroadwaveEquipped(), "licensed tool counts as Broadwave equipped")
	licensed:Destroy()
	check(not Arbiter.BroadwaveEquipped(), "nothing equipped")
	-- Named dig pauses never clobber each other.
	check(not Arbiter.DigBlocked(), "digging open by default")
	Arbiter.Suppress("AdventureHauling", true)
	Arbiter.Suppress("AdventureArena", true)
	Arbiter.Suppress("AdventureHauling", false)
	check(Arbiter.DigBlocked() and Arbiter.Has("AdventureArena"), "one remaining reason still blocks")
	check(DigController.TryDigAt(V.new(0, S, -30)) == false, "DigController refuses while blocked")
	Arbiter.Suppress("AdventureArena", false)
	check(not Arbiter.DigBlocked(), "released when every reason is released")

	-- Flag off: no remotes folder, nothing binds or builds. -----------------------------------
	AdventureController.Init()
	Mock.Advance(1)
	check(not AdventureController.IsActive() and not AdventureController.IsStarted(), "off: adapter idle")
	check(Mock.Actions.SpringVaultBroadwave == nil, "off: no Broadwave charge binding")
	check(Mock.Actions.BroadwaveEquip == nil and Equip.Gui == nil, "off: no equip control")
	check(player.PlayerGui:FindFirstChild("SpringVaultAdventureReview") == nil, "off: no runtime GUI")
	check(reasons() == "", "off: no dig pause")

	-- Flag on: the server builds the arena and the remotes. -----------------------------------
	local function buildScene()
		local model = Mock.Env.Instance.new("Model")
		model.Name = "SpringVaultAdventure"
		local floor = Mock.Env.Instance.new("Part")
		floor.Name = "ProtectedArenaFloor"
		floor.Size = V.new(100, 2, 140)
		floor.Position = V.new(-200, 969, 70)
		floor.Parent = model
		model.Parent = Workspace
		return model
	end
	local function buildRemotes()
		local remotesFolder = Mock.Env.Instance.new("Folder")
		remotesFolder.Name = "SpringVaultAdventure"
		local snapRemote
		for _, name in { "Intent", "Snapshot", "Effect" } do
			local remote = Mock.Env.Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = remotesFolder
			if name == "Snapshot" then
				snapRemote = remote
			end
		end
		remotesFolder.Parent = RS
		return remotesFolder, snapRemote
	end
	local scene = buildScene()
	local folder, snapshot = buildRemotes()
	Mock.Advance(1)
	local function runtimeGui()
		return player.PlayerGui:FindFirstChild("SpringVaultAdventureReview")
	end
	local function snap(data)
		Mock.FireEvent(snapshot, "OnClientEvent", data)
		Mock.Advance(0.05)
	end
	local HAULING = { hauling = true, joined = true, stage = "ball", phase = "Active" }
	check(AdventureController.IsActive(), "on: adapter active once the server remotes exist")
	check(not AdventureController.IsStarted() and runtimeGui() == nil, "on: no adventure panel on the beach")
	check(Mock.Actions.SpringVaultBroadwave == nil, "on: no charge binding on the beach without a Broadwave")
	r, fired = press(Enum.KeyCode.Q)
	check(fired, "on: Q surfaces on the beach")
	snap(HAULING)
	check(not Arbiter.DigBlocked(), "a stale hauling snapshot outside the arena never pauses digging")
	-- Into the arena: dialogue / objectives pause digging; the runtime starts.
	player.Character:PivotTo(ARENA)
	Mock.Advance(0.3)
	check(AdventureController.IsStarted() and runtimeGui() ~= nil, "arena: SpringVaultClient running")
	check(Mock.Actions.SpringVaultBroadwave ~= nil, "arena: Broadwave charge bound (Q / L1)")
	check(Arbiter.ChargeAvailable(), "arena: InputArbiter knows the charge is bound")
	check(reasons() == "AdventureArena", "arena: AdventureArena pauses digging (Mara / Pip / prompts)")
	check(DigController.TryDigAt(V.new(-200, 970, 70)) == false, "arena: dig refused client-side")
	r, fired = press(Enum.KeyCode.Q)
	check(fired, "arena: Q still surfaces without a Broadwave in hand")
	snap(HAULING)
	check(reasons() == "AdventureArena,AdventureHauling", "hauling: AdventureHauling on")
	snap({ hauling = false, joined = true, stage = "ball", phase = "Active" })
	check(reasons() == "AdventureArena", "hauling: detaching releases AdventureHauling")
	-- Leave: the runtime returns the player to the beach; everything resumes.
	snap(HAULING)
	snap({ hauling = false, joined = false, stage = "Optional", phase = "Dormant" })
	toBeach()
	Mock.Advance(0.3)
	check(reasons() == "" and not Arbiter.DigBlocked(), "leave: every reason released")
	check(AdventureController.IsStarted(), "leave: runtime kept for the grace period")
	Mock.Advance(AdventureController.STOP_GRACE + 0.5)
	check(not AdventureController.IsStarted() and runtimeGui() == nil, "leave: runtime stopped after the grace")
	check(Mock.Actions.SpringVaultBroadwave == nil and not Arbiter.ChargeAvailable(), "leave: charge unbound")
	-- Lifted out while still attached (no detaching snapshot ever arrives).
	player.Character:PivotTo(ARENA)
	Mock.Advance(0.3)
	snap(HAULING)
	toBeach()
	Mock.Advance(0.3)
	check(reasons() == "", "lifted out while hauling: no reason left on")
	player.Character:PivotTo(ARENA)
	Mock.Advance(0.3)
	check(reasons() == "AdventureArena", "back in the arena: the old hauling flag is not resurrected")
	-- Respawn while hauling.
	snap(HAULING)
	check(Arbiter.Has("AdventureHauling"), "respawn: hauling before death")
	Mock.SpawnCharacter(player, BEACH)
	Mock.Advance(0.05)
	check(reasons() == "" and not Arbiter.DigBlocked(), "respawn while hauling: digging resumes")
	snap(HAULING)
	check(reasons() == "", "respawn: a late hauling snapshot on the beach changes nothing")
	-- Scene rebuild (end of a run) while hauling in the arena.
	player.Character:PivotTo(ARENA)
	Mock.Advance(0.3)
	snap(HAULING)
	scene:Destroy()
	Mock.Advance(0.05)
	check(reasons() == "", "scene removed: arena and hauling released")
	scene = buildScene()
	Mock.Advance(0.3)
	check(reasons() == "AdventureArena", "scene rebuilt: arena again, hauling not carried over")
	check(AdventureController.IsStarted(), "scene rebuilt: runtime running")
	-- Kill switch: the remotes folder goes while hauling with a Broadwave in hand.
	snap(HAULING)
	local held = newTool("Broadwave (Adventure Loan)", { AdventureLoan = true }, player.Character)
	Mock.Advance(0.05)
	r, fired = press(Enum.KeyCode.Q)
	check(r == Enum.ContextActionResult.Pass and not fired, "Q goes to the charge with the loan in hand")
	local oldSnapshot = snapshot
	folder:Destroy()
	Mock.Advance(0.05)
	check(not AdventureController.IsActive() and not AdventureController.IsStarted(), "kill switch: runtime stopped")
	check(runtimeGui() == nil and Mock.Actions.SpringVaultBroadwave == nil, "kill switch: runtime GUI and charge gone")
	check(reasons() == "", "kill switch: no reason left on")
	r, fired = press(Enum.KeyCode.Q)
	check(r == Enum.ContextActionResult.Sink and fired, "kill switch: Q surfaces even with a Broadwave in hand")
	check(#AdventureHUD.Hidden() == 0, "kill switch: HUD restored")
	held:Destroy()
	Mock.FireEvent(oldSnapshot, "OnClientEvent", HAULING)
	Mock.Advance(0.3)
	check(reasons() == "", "kill switch: the old snapshot remote no longer drives anything")
	-- A rebuilt folder (new boot) is picked up again.
	folder, snapshot = buildRemotes()
	Mock.Advance(0.3)
	check(AdventureController.IsActive() and AdventureController.IsStarted(), "remotes rebuilt: runtime restarted")
	snap(HAULING)
	check(reasons() == "AdventureArena,AdventureHauling", "remotes rebuilt: new snapshots drive the reasons")
	snap({ hauling = false, joined = false, stage = "Optional", phase = "Dormant" })

	-- Screen layout (UI/AdventureHUD): only Claude HUD pieces move, only in the arena. -------
	local function abs(object, x, y, w, h)
		local p = Mock.Internal(object).props
		p.AbsolutePosition = Mock.Vector2.new(x, y)
		p.AbsoluteSize = Mock.Vector2.new(w, h)
	end
	local panel = runtimeGui():FindFirstChildOfClass("ScrollingFrame")
	check(panel ~= nil and panel.Visible, "layout: runtime panel found (read-only)")
	abs(panel, 475, 12, 330, 246)
	local canvas = Root.Get("HUD") -- the real Dig_HUD canvas (HUD.Init is not run here)
	local pieces = {}
	for name, rect in
		{
			Depth = { 900, 8, 200, 118 },
			Timers = { 450, 60, 380, 36 },
			Bottom = { 430, 500, 420, 180 },
			Menu = { 0, 0, 1280, 720 },
		}
	do
		local frame = Mock.Env.Instance.new("Frame")
		frame.Name = name
		frame.Parent = canvas
		abs(frame, table.unpack(rect))
		pieces[name] = frame
	end
	-- RideButton toggles its own Visible, so the arena rule hides its ScreenGui instead.
	local rideGui = Mock.Env.Instance.new("ScreenGui")
	rideGui.Name = "Dig_Ride"
	local rideCanvas = Mock.Env.Instance.new("Frame")
	rideCanvas.Name = "Canvas"
	rideCanvas.Parent = rideGui
	local rideHolder = Mock.Env.Instance.new("Frame")
	rideHolder.Name = "RideButton"
	rideHolder.Visible = false -- owner state: not ridable right now
	rideHolder.Parent = rideCanvas
	abs(rideHolder, 700, 200, 80, 86)
	rideGui.Parent = player.PlayerGui
	Mock.Advance(0.3)
	check(not pieces.Depth.Visible, "layout: depth meter hidden in the arena")
	check(not pieces.Timers.Visible, "layout: boost chips under the runtime panel hidden")
	check(pieces.Bottom.Visible, "layout: bottom bar clear of the runtime stays")
	check(pieces.Menu.Visible, "layout: unlisted pieces (menu) are never touched")
	check(panel.Visible and panel.Parent ~= nil, "layout: the runtime panel itself is untouched")
	check(rideGui.Enabled == false and rideHolder.Visible == false, "layout: Ride hidden via its ScreenGui")
	rideHolder.Visible = true -- RideButton changes its own state meanwhile
	Mock.Advance(0.3)
	check(rideGui.Enabled == false, "layout: owner changes do not undo the arena rule")
	-- The tutorial objective pill under the runtime panel (seen in the Studio production review).
	ObjectiveBanner.Show("Follow the arrow to the sand", nil, { Step = "1/7" })
	local pill = ObjectiveBanner.Get() :: any
	abs(pill, 240, 64, 500, 64)
	Mock.Advance(0.3)
	check(ObjectiveBanner.IsSuppressed() and not pill.Visible, "layout: objective pill under the panel suppressed")
	ObjectiveBanner.Show("Sell your sand", nil, { Step = "2/7" })
	Mock.Advance(0.3)
	check(not pill.Visible and ObjectiveBanner.Visible, "layout: a new objective stays off screen but is kept")
	toBeach()
	Mock.Advance(0.3)
	check(not ObjectiveBanner.IsSuppressed() and pill.Visible, "layout: objective pill back on leaving the arena")
	ObjectiveBanner.Hide()
	Mock.Advance(1)
	check(pieces.Depth.Visible and pieces.Timers.Visible, "layout: restored on leaving the arena")
	check(rideGui.Enabled == true and rideHolder.Visible == true, "layout: Ride restored, owner state kept")
	rideGui:Destroy()
	check(#AdventureHUD.Hidden() == 0, "layout: nothing left hidden")
	Mock.Advance(AdventureController.STOP_GRACE + 0.5)
	check(not AdventureController.IsStarted(), "layout: runtime stopped on the beach")
	for _, frame in pieces do
		frame:Destroy()
	end
	-- Toasts move below the panel instead of being hidden.
	Toasts.Show("Hello", "Info")
	Mock.Advance(0.1)
	player.Character:PivotTo(ARENA)
	Mock.Advance(0.3)
	panel = runtimeGui():FindFirstChildOfClass("ScrollingFrame")
	local toastCanvas = Root.Get("Toasts")
	local column = toastCanvas:FindFirstChild("Toasts")
	check(column ~= nil, "toasts: column exists")
	abs(toastCanvas, 0, 0, 1280, 662)
	abs(column, 450, 102, 380, 138)
	abs(panel, 475, 12, 330, 246)
	Mock.Advance(0.3)
	local top = Toasts.GetClearance()
	check(top ~= nil and top >= 258 / Root.Scale, "toasts: column starts below the runtime panel")
	check(column.Position.Y.Offset >= 258 / Root.Scale - 1, "toasts: container moved")
	toBeach()
	Mock.Advance(0.3)
	check(Toasts.GetClearance() == nil, "toasts: back in place on the beach")
	check(column.Position.Y.Offset == Layout.Current().Toasts.Y, "toasts: container restored")
	Mock.Advance(AdventureController.STOP_GRACE + 0.5)

	-- One visible equip control (UI/BroadwaveEquip vs the runtime's own button) -----------------
	local function controls()
		local n = 0
		if Equip.State().Visible then
			n += 1
		end
		if Equip.RuntimeButtonVisible() then
			n += 1
		end
		return n
	end
	check(Equip.State().Visible == false and Mock.Actions.BroadwaveEquip == nil, "equip: nothing without a tool")
	local shovel = newTool("Shovel", { ShovelId = "starter" }, player.Backpack)
	Mock.Advance(0.2)
	check(Equip.State().Visible == false, "equip: a shovel alone shows nothing")
	local loanTool = newTool("Broadwave (Adventure Loan)", { AdventureLoan = true }, player.Backpack)
	Mock.Advance(0.3)
	check(Equip.State().Label == nil and controls() == 0, "equip: a stowed loan on the beach offers no control")
	check(Mock.Actions.BroadwaveEquip == nil, "equip: Z does nothing for a stowed loan on the beach")
	check(not AdventureController.IsStarted(), "equip: a stowed loan does not start the runtime")
	-- In the arena the runtime's button is the control; ours steps aside, keys stay.
	player.Character:PivotTo(ARENA)
	Mock.Advance(0.3)
	local state = Equip.State()
	check(Equip.Gui ~= nil and state.Visible, "equip: shows once the loan is in the Backpack")
	local runtimeEquip = player.PlayerGui.SpringVaultAdventureReview:FindFirstChild("BroadwaveEquip", true)
	check(runtimeEquip and not runtimeEquip.Visible, "equip: actual shared HUD hides runtime review duplicate")
	Mock.FireEvent(runtimeEquip, "Activated")
	check(loanTool.Parent == player.Backpack, "equip: runtime fallback cannot compete with production tool selection")
	check(controls() == 1 and not Equip.RuntimeButtonVisible(), "equip: exactly one control in the arena (ours)")
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
	local before = #Mock.Remote.ToServer
	local key = Mock.Actions.BroadwaveEquip
	local result =
		key.Fn("BroadwaveEquip", Enum.UserInputState.Begin, Mock.Input(Enum.UserInputType.Keyboard, Enum.KeyCode.Z))
	Mock.Advance(0.1)
	check(result == Enum.ContextActionResult.Sink, "equip: Z sinks")
	check(loanTool.Parent == player.Character, "equip: Z equips the loan")
	check(sentSince(before, "Dig") == 0 and sentSince(before, "ReturnToSurface") == 0, "equip: no game remote")
	check(Equip.State().Equipped and Arbiter.QToCharge(), "equip: in hand, Q goes to the charge")
	check(controls() == 1, "equip: still one control with the loan in hand")
	-- A loan carried out of the arena: digging stays paused client-side, it can still be put away.
	toBeach()
	Mock.Advance(0.3)
	check(reasons() == "", "loan outside: no arena reason")
	before = #Mock.Remote.ToServer
	check(DigController.TryDigAt(V.new(0, S, -30)) == false, "loan outside: ordinary dig refused client-side")
	check(sentSince(before, "Dig") == 0, "loan outside: no dig request sent")
	Mock.Advance(AdventureController.STOP_GRACE + 0.5)
	check(AdventureController.IsStarted(), "loan outside: runtime kept while a Broadwave is in hand")
	check(Equip.State().Label == "Broadwave (loan)" and controls() == 1, "loan outside: one control to put it away")
	-- Gamepad R1 puts it away and re-equips the shovel.
	key = Mock.Actions.BroadwaveEquip
	key.Fn("BroadwaveEquip", Enum.UserInputState.Begin, Mock.Input(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR1))
	Mock.Advance(0.1)
	check(loanTool.Parent == player.Backpack and shovel.Parent == player.Character, "equip: R1 puts it away")
	check(not Arbiter.BroadwaveEquipped(), "equip: stowed again")
	Mock.Advance(AdventureController.STOP_GRACE + 0.5)
	check(not AdventureController.IsStarted() and controls() == 0, "loan outside: stowed, runtime stops, no control")
	check(Mock.Actions.BroadwaveEquip == nil, "loan outside: keys unbound again")
	-- No shovel Tool in the Backpack (the usual production case): an ordinary dig must not pull
	-- the stowed loan into the hand (Studio production review finding).
	player.Character:FindFirstChildOfClass("Humanoid"):UnequipTools()
	shovel.Parent = nil
	player.Character:PivotTo(CF.new(0, S + 3, -26))
	Mock.Advance(1)
	before = #Mock.Remote.ToServer
	local sentDig = DigController.TryDigAt(V.new(0, S, -30))
	Mock.Advance(0.1)
	check(sentDig == true, "no shovel tool: ordinary dig still sent")
	check(
		loanTool.Parent == player.Backpack and not Arbiter.BroadwaveEquipped(),
		"no shovel tool: loan not auto-equipped"
	)
	shovel.Parent = player.Backpack
	player.Character:FindFirstChildOfClass("Humanoid"):EquipTool(shovel)
	toBeach()
	Mock.Advance(0.1)
	-- Licensed tool on the beach: only ours, with its own label and Layout region.
	local licensedTool = newTool("Broadwave", { ToolId = "tool_broadwave", LicensedBroadwave = true }, player.Backpack)
	Mock.Advance(0.3)
	state = Equip.State()
	check(state.Label == "Broadwave" and state.Visible and not state.RuntimeOwns, "licensed: ours on the beach")
	check(Equip.Button.Label.Text == "Broadwave", "licensed: caption has no loan marker")
	check(controls() == 1, "licensed: exactly one control on the beach")
	local holder = Equip.Button.Holder
	local region = Layout.Current().Broadwave
	check(
		holder.Position.X.Offset == region.X
			and holder.Position.Y.Offset == region.Y
			and holder.Size.Y.Offset == region.H,
		"licensed: placed by the Layout Broadwave region"
	)
	check(Mock.Actions.BroadwaveEquip ~= nil, "licensed: Z bound")
	-- Tap ours: equips, the runtime starts in the same frame and its button takes over.
	Mock.FireEvent(Equip.Button.Face, "Activated")
	Mock.Advance(0.05)
	check(licensedTool.Parent == player.Character, "licensed: tapping equips")
	check(AdventureController.IsStarted() and Arbiter.QToCharge(), "licensed: charge bound once in hand")
	check(controls() == 1 and Equip.State().Visible, "licensed: one control (ours; the runtime defers) while in hand")
	Mock.Advance(0.3)
	Equip.Toggle()
	Mock.Advance(0.1)
	check(shovel.Parent == player.Character, "licensed: put away, shovel back")
	check(Equip.Toggle() == false, "equip: debounced double press")
	Mock.Advance(AdventureController.STOP_GRACE + 0.5)
	check(not AdventureController.IsStarted() and Equip.State().Visible, "licensed: runtime stops, ours stays")
	check(controls() == 1, "licensed: still exactly one control")
	-- In the arena with both tools the loan is preferred; the runtime owns the control.
	player.Character:PivotTo(ARENA)
	Mock.Advance(0.3)
	check(Equip.State().Label == "Broadwave (loan)" and controls() == 1, "both tools in the arena: loan, one control")
	toBeach()
	Mock.Advance(AdventureController.STOP_GRACE + 0.5)
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
	Mock.SpawnCharacter(player, BEACH)
	Mock.Advance(0.5)
	check(Equip.State().Visible == false, "equip: hidden after respawn without tools")
	local relent = newTool("Broadwave", { ToolId = "tool_broadwave", LicensedBroadwave = true }, player.Backpack)
	Mock.Advance(0.2)
	check(Equip.State().Visible and Mock.Actions.BroadwaveEquip ~= nil, "equip: shows for a tool in the new Backpack")
	Mock.SpawnCharacter(player, BEACH)
	Mock.Advance(0.5)
	check(relent.Parent == nil, "respawn destroyed the old Backpack's tool")
	check(Equip.State().Visible == false and Mock.Actions.BroadwaveEquip == nil, "equip: cleaned up on respawn")
	check(reasons() == "", "end: no dig pause left on")
	finish()
	return
end

-- Client streaming: remotes before the arena (SpringVaultClient.Start(remotes, nil)) ---------------
-- A licensed player far from the pocket never has Workspace.SpringVaultAdventure streamed in.
-- The adapter must start the REAL runtime from the remotes alone, never fake a scene, keep loans
-- scene-gated (the runtime's own rule) and keep every arena reason scene-bound.
if mode == "client-stream" then
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
	local BEACH = V.new(0, S + 3, 4)
	Mock.SpawnCharacter(player, BEACH)
	local Controllers = "StarterPlayer/StarterPlayerScripts/Client/Controllers/"
	local UI = "StarterPlayer/StarterPlayerScripts/Client/UI/"
	local Arbiter = load(Controllers .. "InputArbiter")
	local InputController = load(Controllers .. "InputController")
	local AdventureController = load(Controllers .. "AdventureController")
	local AdventureHUD = load(UI .. "AdventureHUD")
	local Root = load(UI .. "Root")
	local RS = Mock.Service("ReplicatedStorage")
	local Workspace = Mock.Service("Workspace")
	player.PlayerGui.ChildAdded:Connect(function(child)
		if child:IsA("ScreenGui") then
			Mock.Internal(child).props.Enabled = true
		end
	end)
	Root.Init()
	InputController.Init()
	-- Every SpringVaultAdventure child Workspace ever receives (only this spec may add one).
	local sceneAdds = 0
	Workspace.ChildAdded:Connect(function(child)
		if child.Name == "SpringVaultAdventure" then
			sceneAdds += 1
		end
	end)
	local function newTool(name, attrs, parent)
		local t = Mock.Env.Instance.new("Tool")
		t.Name = name
		for k, v in attrs do
			t:SetAttribute(k, v)
		end
		t.Parent = parent
		return t
	end
	local function reasons()
		return table.concat(Arbiter.Reasons(), ",")
	end
	local function runtimeGui()
		return player.PlayerGui:FindFirstChild("SpringVaultAdventureReview")
	end
	local function intents(action)
		local n = 0
		for _, request in Mock.Remote.ToServer do
			if request.Name == "Intent" and type(request.Args[1]) == "table" and request.Args[1].action == action then
				n += 1
			end
		end
		return n
	end
	local function noFakeScene()
		if Workspace:FindFirstChild("SpringVaultAdventure") ~= nil then
			return false
		end
		for _, item in Workspace:GetDescendants() do
			if item.Name == "ProtectedArenaFloor" or item.Name == "landmark_spring_vault_ball" then
				return false
			end
		end
		return true
	end
	local Q = Mock.Input(Enum.UserInputType.Keyboard, Enum.KeyCode.Q)
	local function charge(state)
		local binding = Mock.Actions.SpringVaultBroadwave
		return binding and binding.Fn("SpringVaultBroadwave", state, Q)
	end
	local function surfaceQ()
		local before = #Mock.Remote.ToServer
		local result = Mock.Actions.DigSurface.Fn("DigSurface", Enum.UserInputState.Begin, Q)
		local fired = false
		for i = before + 1, #Mock.Remote.ToServer do
			if Mock.Remote.ToServer[i].Name == "ReturnToSurface" then
				fired = true
			end
		end
		return result, fired
	end
	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")

	-- Remotes exist, the arena never streamed in.
	AdventureController.Init()
	local folder = Mock.Env.Instance.new("Folder")
	folder.Name = "SpringVaultAdventure"
	for _, name in { "Intent", "Snapshot", "Effect" } do
		local remote = Mock.Env.Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = RS
	Mock.Advance(1)

	-- 4. Nothing in hand, no scene, not in the arena: nothing runs (the beach shows no panel).
	check(AdventureController.IsActive(), "stream: adapter active from the remotes alone")
	check(not AdventureController.IsStarted() and runtimeGui() == nil, "empty hand: runtime not started, no panel")
	check(Mock.Actions.SpringVaultBroadwave == nil and not Arbiter.ChargeAvailable(), "empty hand: no charge")
	local r, fired = surfaceQ()
	check(r == Enum.ContextActionResult.Sink and fired, "empty hand: Q surfaces")
	check(reasons() == "", "empty hand: no dig pause")

	-- 1. Licensed Broadwave in hand, no scene: the real runtime starts and can charge.
	local licensed = newTool("Broadwave", { ToolId = "tool_broadwave", LicensedBroadwave = true }, player.Backpack)
	Mock.Advance(0.3)
	check(not AdventureController.IsStarted(), "licensed stowed: runtime not started")
	humanoid:EquipTool(licensed)
	Mock.Advance(0.05)
	check(licensed.Parent == player.Character, "licensed: in hand")
	check(AdventureController.IsStarted() and runtimeGui() ~= nil, "licensed, no scene: runtime started")
	check(Mock.Actions.SpringVaultBroadwave ~= nil and Arbiter.ChargeAvailable(), "licensed, no scene: charge bound")
	check(Arbiter.QToCharge(), "licensed, no scene: Q goes to the charge")
	check(noFakeScene() and sceneAdds == 0, "licensed, no scene: the client created no scene")
	check(not Arbiter.Has("AdventureArena") and reasons() == "", "licensed, no scene: AdventureArena not suppressed")
	check(#AdventureHUD.Hidden() == 0, "licensed, no scene: HUD untouched (not in the arena)")
	local begins, releases = intents("ChargeBegin"), intents("ChargeRelease")
	r = charge(Enum.UserInputState.Begin)
	check(
		r == Enum.ContextActionResult.Sink and intents("ChargeBegin") == begins + 1,
		"licensed, no scene: Q begins a charge"
	)
	charge(Enum.UserInputState.End)
	check(intents("ChargeRelease") == releases + 1, "licensed, no scene: release sent")
	Mock.Advance(AdventureController.STOP_GRACE + 0.5)
	check(AdventureController.IsStarted(), "licensed, no scene: runtime kept while in hand")

	-- 2. A loan in hand with no scene: the runtime runs, but the loan stays scene-gated.
	humanoid:UnequipTools()
	Mock.Advance(AdventureController.STOP_GRACE + 0.5)
	check(not AdventureController.IsStarted() and not Arbiter.ChargeAvailable(), "licensed stowed: runtime stopped")
	local loan = newTool("Broadwave (Adventure Loan)", { AdventureLoan = true }, player.Character)
	Mock.Advance(0.05)
	check(AdventureController.IsStarted(), "loan, no scene: runtime started (Broadwave in hand)")
	check(Arbiter.ChargeAvailable(), "loan, no scene: charge availability follows the handle")
	begins = intents("ChargeBegin")
	r = charge(Enum.UserInputState.Begin)
	charge(Enum.UserInputState.End)
	check(r == Enum.ContextActionResult.Pass, "loan, no scene: the runtime passes Q")
	check(intents("ChargeBegin") == begins, "loan, no scene: no ChargeBegin for a loan without the arena")
	check(noFakeScene() and sceneAdds == 0 and reasons() == "", "loan, no scene: no scene, no arena reason")
	loan:Destroy()
	Mock.Advance(AdventureController.STOP_GRACE + 0.5)
	check(not AdventureController.IsStarted(), "loan gone: runtime stopped")

	-- 3. Stream-in, then stream-out, with the licensed tool in hand.
	humanoid:EquipTool(licensed)
	Mock.Advance(0.05)
	local gui = runtimeGui()
	local binding = Mock.Actions.SpringVaultBroadwave
	check(AdventureController.IsStarted() and gui ~= nil, "stream: runtime started before the arena")
	local scene = Mock.Env.Instance.new("Model")
	scene.Name = "SpringVaultAdventure"
	local floor = Mock.Env.Instance.new("Part")
	floor.Name = "ProtectedArenaFloor"
	floor.Size = V.new(100, 2, 140)
	floor.Position = V.new(-200, 969, 70)
	floor.Parent = scene
	scene.Parent = Workspace
	Mock.Advance(0.3)
	check(sceneAdds == 1, "stream-in: the only scene is the streamed one")
	check(runtimeGui() == gui and Mock.Actions.SpringVaultBroadwave == binding, "stream-in: same runtime handle")
	check(reasons() == "", "stream-in: on the beach, still no arena reason")
	-- Bound by the runtime itself: a loan can now charge (scene-gated) without a restart.
	local loan2 = newTool("Broadwave (Adventure Loan)", { AdventureLoan = true }, player.Character)
	licensed.Parent = player.Backpack
	Mock.Advance(0.05)
	begins = intents("ChargeBegin")
	charge(Enum.UserInputState.Begin)
	charge(Enum.UserInputState.End)
	check(intents("ChargeBegin") == begins + 1, "stream-in: the runtime bound the real scene (loan charges)")
	check(runtimeGui() == gui, "stream-in: still the same runtime handle")
	loan2:Destroy()
	humanoid:EquipTool(licensed)
	Mock.Advance(0.05)
	-- Stream-out with the licensed tool still in hand.
	scene.Parent = nil
	Mock.Advance(0.05)
	check(AdventureController.IsStarted() and runtimeGui() == gui, "stream-out: runtime kept, same handle")
	check(Arbiter.ChargeAvailable() and Arbiter.QToCharge(), "stream-out: charge still available")
	Mock.Advance(AdventureController.STOP_GRACE + 0.5)
	check(AdventureController.IsStarted(), "stream-out: kept past the grace while the tool is in hand")
	begins = intents("ChargeBegin")
	charge(Enum.UserInputState.Begin)
	charge(Enum.UserInputState.End)
	check(intents("ChargeBegin") == begins + 1, "stream-out: licensed charge still begins")
	check(reasons() == "" and noFakeScene(), "stream-out: no arena reason, no scene left behind")
	-- Stow and stay away: stopped after STOP_GRACE.
	humanoid:UnequipTools()
	Mock.Advance(0.3)
	check(AdventureController.IsStarted(), "stowed: runtime kept for the grace period")
	Mock.Advance(AdventureController.STOP_GRACE + 0.5)
	check(not AdventureController.IsStarted() and runtimeGui() == nil, "stowed: runtime stopped after the grace")
	check(Mock.Actions.SpringVaultBroadwave == nil and not Arbiter.ChargeAvailable(), "stowed: charge unbound")
	r, fired = surfaceQ()
	check(r == Enum.ContextActionResult.Sink and fired, "stowed: Q surfaces again")
	check(reasons() == "", "end: no dig pause left on")
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
	check(Workspace:FindFirstChild("AdventureEntry") == nil, "off: no entrance or pocket rig")
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
check(Workspace:FindFirstChild("AdventureEntry") ~= nil, "on: surface entrance + pocket rig built")
check(Eligibility.IsOrdinaryEnabled() == true, "on: ordinary Broadwave enabled")
local opts = Boot.Options(Flags)
check(opts.OnStage == Settlement.OnStage and opts.OnCompletion == Settlement.OnCompletion, "rewards wired")
local Entry = Mock.Require(byPath["ServerScriptService/Server/Services/AdventureEntry"])
check(
	type(opts.ReturnFrame) == "function" and opts.ReturnFrame(nil :: any) == Entry.SURFACE_RETURN,
	"runtime ReturnFrame is the fixed surface point"
)
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
check(Workspace:FindFirstChild("AdventureEntry") == nil, "kill switch: entrance and pocket rig removed")
check(lic.Backpack:FindFirstChild("Broadwave") == nil, "kill switch: licensed tool removed")
check(Eligibility.IsOrdinaryEnabled() == false, "kill switch: ordinary Broadwave disabled")
check(Settlement.SettleStage({}).Error == "Disabled", "kill switch: settlement refuses new grants")
check(Data.Get(lic).ToolLicenses.tool_broadwave ~= nil, "kill switch never touches saved licenses")
finish()
