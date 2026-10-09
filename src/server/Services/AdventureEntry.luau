--!strict
--[[
	AdventureEntry — the production way into and out of the Spring Vault pocket arena
	(docs/integration/adventure-entry.md). Started only by AdventureBoot, only when
	AdventureFlags.SpringVault is on and the runtime started; with the flag off nothing here is
	built or connected.

	Owns Workspace.AdventureEntry:
	  Entrance  surface hatch west of the crate yard (ENTRANCE). Server ProximityPrompt
	            "Go down" / "Spring Vault": AdventureEligibility.CanEnter players are moved to
	            ARRIVAL in the arena (near Mara, inside the runtime's presence box); everyone else
	            gets a truthful toast and stays put.
	  Pocket    a "Back to the beach" pad beside the arena exit, plus the lighting rig: a dark
	            non-colliding backdrop box (hides the sky under the slab) and a few shadowless
	            PointLights. Nothing in the rig collides, queries or touches.

	Return paths (all land on SURFACE_RETURN beside the hatch, never a client-sent position):
	  * the return pad (an active participant is first Left through runtime.Handle, so the
	    runtime's own restore cannot pull them back down later);
	  * the runtime's Leave or the end of a run: a player who stops being an active participant
	    while still in the pocket is sent up once the runtime has restored them;
	  * falling: anyone below the arena floor in the pocket column, except a present ball-stage
	    participant, whom the runtime's own checkpoint recovery gets FALL_GRACE seconds first;
	  * Stop() (AdventureBoot.Disable, after the runtime's Destroy): everyone in the pocket.
	Respawns use the boardwalk spawns (BeachService pivots every new character there).
	Q / ReturnToSurface from the pocket lands on the boardwalk deck at the pocket's X
	(World.GetSurfacePoint), which is a valid deck point.

	Invitation (docs/integration/adventure-entry.md, "Invitation"): once per server session, a
	player whose loaded save passes AdventureEligibility.CanEnter and who has finished the
	tutorial (data.Settings.Tutorial, the TutorialController step count) gets one Info toast
	(INVITE_TEXT) and the player attribute INVITE_ATTRIBUTE = true. It is checked on load and
	again whenever DataService.Changed reports a key eligibility or the tutorial reads
	(Certifications, Quests, FindVariants, Settings), so a cert or catch-up evidence earned
	mid-session invites too. Nothing is written to the save. The attribute only drives the
	client's guide beam to the hatch (tag HATCH_TAG, published as a world anchor); the server
	never reads it back. Stop() clears it.

	The scene itself (SpringVaultScene) is Codex's and is never edited here.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DataService = require(script.Parent.DataService)
local Eligibility = require(script.Parent.AdventureEligibility)
local Net = require(script.Parent.Net)
local StreamingService = require(script.Parent.StreamingService)
local Config = require(ReplicatedStorage.Shared.Config)
local World = require(script.Parent.Parent.World)
local Layout = require(script.Parent.Parent.World.Layout)
local Util = require(script.Parent.Parent.World.Util)

local V = Vector3.new
local rgb = Color3.fromRGB
local S = Layout.SURFACE_Y
local STAND = 3.5 -- HumanoidRootPart above the floor (World.STAND_HEIGHT)

local AdventureEntry = {}

AdventureEntry.FOLDER = "AdventureEntry"

-- Surface entrance: open sand west of the crate yard fence (x ~ -101) and east of the
-- Sandcastle Contest (-150, 40); 14+ studs clear of every map part, far from the dig zone,
-- spawns, the plaza paths and the camp pad; ~26 studs east of the pocket's X range.
AdventureEntry.ENTRANCE = V(-124, S, 76)
AdventureEntry.PAD_SIZE = 10
-- Where players come back up: on the sand 12 studs east of the hatch, facing the plaza.
local returnPos = V(-112, Layout.DECK_TOP + STAND, 76)
AdventureEntry.SURFACE_RETURN = CFrame.lookAt(returnPos, returnPos + V(1, 0, 0))

-- Pocket offsets from the arena origin (SpringVaultScene: floor top = origin.Y, Mara at
-- (-20, 0, 15), Pip (20, 0, 15), exit pad (0, 0, 29), vault (0, 0, -4)).
AdventureEntry.ARRIVAL_OFFSET = V(-10, STAND, 24)
AdventureEntry.RETURN_PAD_OFFSET = V(10, 0.15, 29)

AdventureEntry.PROMPT_COOLDOWN = 1.5
AdventureEntry.FALL_DEPTH = 20 -- below the floor top
AdventureEntry.FALL_GRACE = 3
AdventureEntry.LEAVE_DELAY = 0.6 -- lets the runtime's own restore finish first
AdventureEntry.CHECK_INTERVAL = 0.2

-- Invitation (one per player per server session).
AdventureEntry.INVITE_ATTRIBUTE = "SpringVaultInvited"
AdventureEntry.INVITE_TEXT = "Mara needs diggers: the hatch west of the crate yard."
AdventureEntry.INVITE_DELAY = 6 -- after load: lets the join popups (offline, daily) settle first
AdventureEntry.HATCH_TAG = "SpringVaultHatch"
-- Save keys that can change CanEnter (cert, sale quests, deposit variants) or the tutorial step.
local INVITE_KEYS: { [string]: boolean } =
	{ Certifications = true, Quests = true, FindVariants = true, Settings = true }

-- Lighting rig (values to tune in Studio; see the handoff doc).
AdventureEntry.LIGHTING = {
	BackdropColor = rgb(58, 50, 46),
	BackdropMaterial = Enum.Material.Slate,
	CeilingY = 17, -- above the floor top; gate tops are at +10.4, lowest slab terrain ~ +20
	FloorY = -31, -- underside plane
	HalfX = 70, -- arena walls at +-49
	ZMin = -106, -- the strip's terrain face is at the arena's far edge
	ZMax = 60, -- arena near edge is +34; terrain clear to +62 (spec-checked), hills beyond
	LightY = 14,
	LightColor = rgb(255, 236, 210),
	LightBrightness = 1.6,
	LightRange = 48,
	Lights = {
		V(-24, 0, 20),
		V(24, 0, 20),
		V(-24, 0, -30),
		V(24, 0, -30),
		V(-24, 0, -80),
		V(24, 0, -80),
	},
}

local started = false
local origin: Vector3 = Vector3.zero
local runtime: any = nil
local folder: Folder? = nil
local connections: { RBXScriptConnection } = {}
local lastPrompt: { [Player]: number } = {}
local busy: { [Player]: boolean } = {}
local returnFrame: { [Player]: CFrame } = {}
local wasActive: { [Player]: boolean } = {}
local pendingReturn: { [Player]: number } = {}
local fallingSince: { [Player]: number } = {}
local invited: { [Player]: boolean } = {}
local signals: { any } = {} -- DataService Signal connections
local accumulator = 0

local function protect(part: BasePart)
	part:SetAttribute("ProtectedGeometry", true)
	CollectionService:AddTag(part, "ProtectedGeometry")
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- The runtime's presence box (SpringVaultService): |X - o.X| <= 48, |Z - (o.Z - 36)| <= 69.
function AdventureEntry.InArena(position: Vector3): boolean
	return math.abs(position.X - origin.X) <= 48
		and math.abs(position.Z - (origin.Z - 36)) <= 69
		and position.Y >= origin.Y - AdventureEntry.FALL_DEPTH
		and position.Y <= origin.Y + 20
end

-- Anywhere under the slab around the arena, including falling below it. Z >= arena far edge
-- (world z 0) keeps every dig-zone hole (z <= -8) out.
function AdventureEntry.InPocket(position: Vector3): boolean
	return math.abs(position.X - origin.X) <= 100
		and position.Z >= origin.Z - 106
		and position.Z <= origin.Z + 94
		and position.Y <= origin.Y + 20
end

function AdventureEntry.ArrivalFrame(): CFrame
	local p = origin + AdventureEntry.ARRIVAL_OFFSET
	return CFrame.lookAt(p, p + V(0, 0, -1))
end

function AdventureEntry.EntranceIsSafe(): boolean
	local c = AdventureEntry.ENTRANCE
	local half = AdventureEntry.PAD_SIZE / 2
	for _, dx in { -half, half } do
		for _, dz in { -half, half } do
			local corner = c + V(dx, 0, dz)
			if World.IsInDigZone(corner) or World.IsProtected(corner, 8) then
				return false
			end
		end
	end
	return true
end

local function activeParticipant(player: Player): (any, any)
	local event = runtime and runtime.Event and runtime.Event()
	local p = event and event.Participants[player.UserId]
	if p and not p.Left and p.Connected then
		return p, event
	end
	return nil, event
end

local function cooled(player: Player): boolean
	local now = os.clock()
	local last = lastPrompt[player]
	if last and now - last < AdventureEntry.PROMPT_COOLDOWN then
		return false
	end
	lastPrompt[player] = now
	return true
end

local function pivot(player: Player, frame: CFrame)
	local character = player.Character
	if not character then
		return
	end
	character:PivotTo(frame)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

function AdventureEntry.ReturnToSurface(player: Player)
	local frame = returnFrame[player] or AdventureEntry.SURFACE_RETURN
	returnFrame[player] = nil
	pendingReturn[player] = nil
	fallingSince[player] = nil
	pivot(player, frame)
end

local function refusal(player: Player): string?
	if not DataService.IsLoaded(player) then
		return "Your save is still loading. Try the Spring Vault again in a moment."
	end
	if Eligibility.CanEnter(player) then
		return nil
	end
	return "Spring Vault opens after your Rookie certificate, or once you have sold sand and dug up a deposit."
end

local function onEnter(player: Player, hatch: BasePart)
	if not started or busy[player] or not cooled(player) then
		return
	end
	local root = rootOf(player)
	if not root or (root.Position - hatch.Position).Magnitude > 16 then
		return
	end
	local humanoid = (player.Character :: Model):FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.SeatPart then
		Net.Notify(player, "Error", "Hop off your ride first.")
		return
	end
	local why = refusal(player)
	if why then
		Net.Notify(player, "Error", why)
		return
	end
	busy[player] = true
	local character = player.Character
	local target = AdventureEntry.ArrivalFrame()
	pcall(function()
		player:RequestStreamAroundAsync(target.Position, 2)
	end)
	busy[player] = nil
	if not started or player.Parent ~= Players or player.Character ~= character or not rootOf(player) then
		return
	end
	-- Fixed server point by the hatch: the character position is client-owned, never trusted.
	returnFrame[player] = AdventureEntry.SURFACE_RETURN
	pivot(player, target)
	Net.Notify(player, "Info", "Spring Vault: talk to Mara to join, or Pip for a Broadwave trial.")
end

local function onReturn(player: Player)
	if not started or not cooled(player) then
		return
	end
	local root = rootOf(player)
	if not root or not AdventureEntry.InArena(root.Position) then
		return
	end
	local member, event = activeParticipant(player)
	if member and event then
		-- Leave first, so the runtime's restore (which pivots to the arena join point) runs now
		-- and never later pulls this player back down from the beach.
		pcall(runtime.Handle, player, { action = "Leave", eventInstanceId = event.EventInstanceId })
	end
	AdventureEntry.ReturnToSurface(player)
	Net.Notify(player, "Info", "Back on the beach.")
end

local function prompt(part: BasePart, action: string, object: string, hold: number, distance: number): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = "AdventureEntryPrompt"
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = hold
	p.MaxActivationDistance = distance
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.Parent = part
	return p
end

local function rigPart(parent: Instance, name: string, size: Vector3, position: Vector3, transparency: number): Part
	local L = AdventureEntry.LIGHTING
	local part = Util.Part({
		Name = name,
		Size = size,
		CFrame = CFrame.new(position),
		Color = L.BackdropColor,
		Material = L.BackdropMaterial,
		Transparency = transparency,
		Decor = true, -- CanCollide / CanQuery / CanTouch / CastShadow all false
		Parent = parent,
	})
	protect(part)
	return part
end

local function buildEntrance(parent: Instance): BasePart
	local c = AdventureEntry.ENTRANCE
	local top = Layout.DECK_TOP
	local model = Util.Model("Entrance", parent)
	local deck = Util.Part({
		Name = "Deck",
		Size = V(AdventureEntry.PAD_SIZE, 1, AdventureEntry.PAD_SIZE),
		CFrame = CFrame.new(c.X, top - 0.5, c.Z),
		Color = rgb(196, 150, 98),
		Material = Enum.Material.WoodPlanks,
		CastShadow = false,
		Parent = model,
	})
	protect(deck)
	local hatch = Util.Part({
		Name = "Hatch",
		Size = V(6, 0.4, 6),
		CFrame = CFrame.new(c.X, top + 0.2, c.Z),
		Color = rgb(29, 42, 68),
		Material = Enum.Material.Metal,
		CanCollide = false,
		CastShadow = false,
		Parent = model,
	})
	protect(hatch)
	local board = Util.Sign(
		model,
		"SPRING VAULT",
		V(8, 2.6, 0.4),
		CFrame.lookAt(V(c.X + 6, top + 4.5, c.Z), V(c.X + 7, top + 4.5, c.Z)),
		{ Name = "Sign", SubText = "Adventure below the sand", Decor = true }
	)
	protect(board)
	local post = Util.Part({
		Name = "SignPost",
		Size = V(0.6, 3.4, 0.6),
		CFrame = CFrame.new(c.X + 6, top + 1.5, c.Z),
		Color = rgb(150, 110, 70),
		Material = Enum.Material.Wood,
		Decor = true,
		Parent = model,
	})
	protect(post)
	return hatch
end

local function buildPocket(parent: Instance): BasePart
	local L = AdventureEntry.LIGHTING
	local o = origin
	local model = Util.Model("Pocket", parent)
	local backdrop = Util.Folder("Backdrop", model)
	local lenZ = L.ZMax - L.ZMin
	local midZ = (L.ZMax + L.ZMin) / 2
	local height = L.CeilingY - L.FloorY
	local midY = (L.CeilingY + L.FloorY) / 2
	rigPart(backdrop, "Ceiling", V(L.HalfX * 2, 1, lenZ), o + V(0, L.CeilingY, midZ), 0)
	rigPart(backdrop, "Underside", V(L.HalfX * 2, 1, lenZ), o + V(0, L.FloorY, midZ), 0)
	rigPart(backdrop, "WestWall", V(1, height, lenZ), o + V(-L.HalfX, midY, midZ), 0)
	rigPart(backdrop, "EastWall", V(1, height, lenZ), o + V(L.HalfX, midY, midZ), 0)
	rigPart(backdrop, "NearWall", V(L.HalfX * 2, height, 1), o + V(0, midY, L.ZMax), 0)
	local lights = Util.Folder("Lights", model)
	for i, offset in L.Lights do
		local anchor = rigPart(lights, "LightAnchor" .. i, V(1, 1, 1), o + offset + V(0, L.LightY, 0), 1)
		local light = Instance.new("PointLight")
		light.Color = L.LightColor
		light.Brightness = L.LightBrightness
		light.Range = L.LightRange
		light.Shadows = false
		light.Parent = anchor
	end
	local pad = Util.Part({
		Name = "ReturnPad",
		Size = V(4, 0.3, 4),
		CFrame = CFrame.new(o + AdventureEntry.RETURN_PAD_OFFSET),
		Color = rgb(40, 190, 245),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		CastShadow = false,
		Parent = model,
	})
	protect(pad)
	return pad
end

local function check()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		local active, event = activeParticipant(player)
		if wasActive[player] and not active then
			pendingReturn[player] = now + AdventureEntry.LEAVE_DELAY
		end
		wasActive[player] = active ~= nil
		if not root then
			fallingSince[player] = nil
			continue
		end
		local pos = root.Position
		local due = pendingReturn[player]
		if due and now >= due then
			pendingReturn[player] = nil
			if AdventureEntry.InPocket(pos) and not active then
				AdventureEntry.ReturnToSurface(player)
				continue
			end
		end
		if AdventureEntry.InPocket(pos) and pos.Y < origin.Y - AdventureEntry.FALL_DEPTH then
			local runtimeRecovers = active ~= nil
				and active.Present
				and event ~= nil
				and event.Phase == "Active"
				and event.Stage == "ball"
			fallingSince[player] = fallingSince[player] or now
			if not runtimeRecovers or now - (fallingSince[player] :: number) >= AdventureEntry.FALL_GRACE then
				AdventureEntry.ReturnToSurface(player)
			end
		else
			fallingSince[player] = nil
		end
	end
end

-- Finished onboarding: TutorialController saves its completed-step count in Settings.Tutorial
-- (veterans get the full count on their first join). Missing or short = still in the tutorial.
local function tutorialDone(player: Player): boolean
	local data = DataService.Get(player) :: any
	local saved = data and type(data.Settings) == "table" and data.Settings.Tutorial
	return type(saved) == "number" and saved >= #Config.TUTORIAL_STEPS
end

-- Invites `player` once per session when the loaded save is eligible and onboarding is over.
function AdventureEntry.ConsiderInvite(player: Player)
	if not started or invited[player] or not DataService.IsLoaded(player) then
		return
	end
	if not Eligibility.CanEnter(player) or not tutorialDone(player) then
		return
	end
	invited[player] = true
	task.delay(AdventureEntry.INVITE_DELAY, function()
		if not started or not invited[player] or player.Parent ~= Players then
			return
		end
		player:SetAttribute(AdventureEntry.INVITE_ATTRIBUTE, true)
		local root = rootOf(player)
		if not (root and AdventureEntry.InPocket(root.Position)) then
			Net.Notify(player, "Info", AdventureEntry.INVITE_TEXT)
		end
	end)
end

function AdventureEntry.WasInvited(player: Player): boolean
	return invited[player] == true
end

local function forget(player: Player)
	lastPrompt[player] = nil
	busy[player] = nil
	returnFrame[player] = nil
	wasActive[player] = nil
	pendingReturn[player] = nil
	fallingSince[player] = nil
	invited[player] = nil
end

-- AdventureBoot only, after SpringVaultService.Start succeeded. `pocketOrigin` = the arena origin.
function AdventureEntry.Start(runtimeHandle: any, pocketOrigin: Vector3): boolean
	if started then
		return true
	end
	if not AdventureEntry.EntranceIsSafe() then
		warn("[AdventureEntry] entrance overlaps digging or a protected footprint; not started")
		return false
	end
	started = true
	runtime = runtimeHandle
	origin = pocketOrigin
	local root = Instance.new("Folder")
	root.Name = AdventureEntry.FOLDER
	folder = root
	local hatch = buildEntrance(root)
	CollectionService:AddTag(hatch, AdventureEntry.HATCH_TAG)
	local pad = buildPocket(root)
	root.Parent = Workspace
	-- Always-replicated anchor, so the invitation's guide beam finds the hatch from anywhere.
	StreamingService.Track(AdventureEntry.HATCH_TAG)
	local enter = prompt(hatch, "Go down", "Spring Vault", 0.5, 10)
	local back = prompt(pad, "Back to the beach", "Surface", 0.3, 8)
	table.insert(
		connections,
		enter.Triggered:Connect(function(player: Player)
			onEnter(player, hatch)
		end)
	)
	table.insert(connections, back.Triggered:Connect(onReturn))
	table.insert(connections, Players.PlayerRemoving:Connect(forget))
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(dt: number)
			accumulator += dt
			if accumulator < AdventureEntry.CHECK_INTERVAL then
				return
			end
			accumulator = 0
			local ok, err = pcall(function(): boolean
				check()
				return true
			end)
			if not ok then
				warn("[AdventureEntry] check failed: " .. tostring(err))
			end
		end)
	)
	table.insert(signals, DataService.PlayerLoaded:Connect(AdventureEntry.ConsiderInvite))
	table.insert(
		signals,
		DataService.Changed:Connect(function(player: Player, keys: { string })
			for _, key in keys do
				if INVITE_KEYS[key] then
					AdventureEntry.ConsiderInvite(player)
					return
				end
			end
		end)
	)
	for _, player in DataService.GetLoadedPlayers() do
		AdventureEntry.ConsiderInvite(player)
	end
	return true
end

-- Kill switch (AdventureBoot.Disable), called AFTER the runtime's Destroy: the runtime restores
-- joined players to their arena join point and then removes the floor, so everyone still under
-- the slab is lifted to the beach in the same frame, before physics can drop them.
function AdventureEntry.Stop()
	if not started then
		return
	end
	started = false
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	for _, c in signals do
		c:Disconnect()
	end
	table.clear(signals)
	for _, player in Players:GetPlayers() do
		if player:GetAttribute(AdventureEntry.INVITE_ATTRIBUTE) ~= nil then
			player:SetAttribute(AdventureEntry.INVITE_ATTRIBUTE, nil)
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and AdventureEntry.InPocket(root.Position) then
			AdventureEntry.ReturnToSurface(player)
		end
	end
	if folder then
		folder:Destroy()
		folder = nil
	end
	for _, t in { lastPrompt, busy, returnFrame, wasActive, pendingReturn, fallingSince, invited } :: { any } do
		table.clear(t)
	end
	runtime = nil
	accumulator = 0
end

function AdventureEntry.IsStarted(): boolean
	return started
end

return AdventureEntry
