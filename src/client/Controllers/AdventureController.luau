--!strict
--[[
	AdventureController — runs Codex's SpringVaultClient in production and arbitrates input and
	screen space around it (docs/integration/production-wiring.md, section 4).

	  * Server-gated: nothing binds, builds or yields until the server has created
	    ReplicatedStorage.SpringVaultAdventure (AdventureBoot, AdventureFlags.SpringVault). The
	    client never reads a flag; with the flag off that folder never exists.
	  * Runtime lifetime: the runtime client runs only while it is needed: standing in the arena,
	    or holding a Broadwave in hand (its Q / L1 / touch charge, anywhere). It is stopped
	    (handle.Destroy) STOP_GRACE seconds after neither holds, and at once when the remotes
	    folder goes (kill switch). So the beach never shows the adventure panel, a stowed loan
	    outside the arena binds nothing, and a rebuilt folder starts a fresh client.
	  * Streaming: the runtime starts from the remotes alone. The arena
	    (Workspace.SpringVaultAdventure) is passed when it is already there and nil otherwise;
	    this adapter never creates, clones or fakes it. SpringVaultClient binds the real scene
	    itself when it streams in and clears it on stream-out, so a licensed Broadwave charges
	    on ordinary sand far from the pocket while loans stay scene-gated inside the runtime.
	    A stream-out never stops the runtime while a Broadwave stays in hand. The arena reasons
	    below stay scene-bound: no scene, never "in the arena".
	  * Digging pause (InputArbiter, named reasons, recomputed every tick and on every character,
	    snapshot, scene and remotes change, so none can stay on):
	      "AdventureArena"    standing in the arena (every Mara / Pip dialogue and prompt, the
	                          anchors, the haul) — the server refuses digs there anyway.
	      "AdventureHauling"  the snapshot says this player is attached AND they are still in the
	                          arena. The latched flag is dropped on respawn, on leaving the arena,
	                          when the scene is removed and when the remotes go.
	    A Broadwave in hand (loan or licensed, charging or not) pauses digging through the live
	    InputArbiter.BroadwaveEquipped() check in DigController, which cannot get stuck either.
	  * Q: InputArbiter.SetChargeAvailable follows the runtime handle, so Q only passes to the
	    charge when the charge action really exists.
	  * Equip: production BroadwaveEquip always owns equip / stow (started with the loops,
	    independent of the scene and the runtime); the runtime hides its review-only fallback
	    button whenever the shared HUD control exists.
	  * Screen: AdventureHUD hides / moves only Claude HUD pieces that collide with the runtime's
	    visible elements while in the arena.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local InputArbiter = require(script.Parent.InputArbiter)
local BroadwaveEquip = require(script.Parent.Parent.UI.BroadwaveEquip)
local AdventureHUD = require(script.Parent.Parent.UI.AdventureHUD)

local AdventureController = {}

AdventureController.REMOTES = "SpringVaultAdventure"
AdventureController.SCENE = "SpringVaultAdventure"
AdventureController.ACTION = "SpringVaultBroadwave"
AdventureController.REASONS = table.freeze({ "AdventureArena", "AdventureHauling" })
AdventureController.TICK = 0.25
AdventureController.STOP_GRACE = 2 -- seconds out of the arena with no Broadwave in hand

local player = Players.LocalPlayer
local remotes: Instance? = nil
local remoteConnections: { RBXScriptConnection } = {}
local handle: any = nil
local starting = false
local failedFor: Instance? = nil -- a folder whose runtime failed to start (no retry spam)
local hauling = false -- latest snapshot: attached to the ball
local idle = 0
local loops = false
local characterConnections: { RBXScriptConnection } = {}

local function sceneNow(): Instance?
	return Workspace:FindFirstChild(AdventureController.SCENE)
end

local function inArena(): boolean
	local scene = sceneNow()
	local floor = scene and scene:FindFirstChild("ProtectedArenaFloor")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not floor or not floor:IsA("BasePart") or not root or not root:IsA("BasePart") then
		return false
	end
	local rel = floor.CFrame:PointToObjectSpace(root.Position)
	return math.abs(rel.X) <= floor.Size.X / 2 and math.abs(rel.Z) <= floor.Size.Z / 2 and rel.Y > -4 and rel.Y < 24
end

local function remotesAlive(): boolean
	local folder = remotes
	return folder ~= nil and folder.Parent == ReplicatedStorage
end

local function stopClient()
	local current = handle
	handle = nil
	InputArbiter.SetChargeAvailable(false)
	if current then
		local ok, err = pcall(current.Destroy)
		if not ok then
			warn("[AdventureController] SpringVaultClient failed to stop: " .. tostring(err))
		end
	end
end

local function startClient(folder: Instance, scene: Instance?)
	local Adventure = script.Parent.Parent:FindFirstChild("Adventure")
	local module = Adventure and Adventure:FindFirstChild("SpringVaultClient")
	if not module or not module:IsA("ModuleScript") then
		warn("[AdventureController] SpringVaultClient missing")
		failedFor = folder
		return
	end
	starting = true
	local Client = (require :: any)(module)
	local ok, result = pcall(Client.Start, folder, scene)
	starting = false
	if not ok then
		warn("[AdventureController] SpringVaultClient failed to start: " .. tostring(result))
		failedFor = folder
		return
	end
	if remotes ~= folder or not remotesAlive() then
		-- The kill switch ran while Start was yielding.
		pcall(result.Destroy)
		return
	end
	handle = result
	InputArbiter.SetChargeAvailable(true)
end

local function releaseAll()
	for _, reason in AdventureController.REASONS do
		InputArbiter.Suppress(reason, false)
	end
end

local function update()
	local active = remotesAlive()
	local arena = active and inArena()
	if not arena then
		hauling = false
	end
	InputArbiter.Suppress("AdventureArena", arena)
	InputArbiter.Suppress("AdventureHauling", arena and hauling)
	local wanted = active and (arena or InputArbiter.BroadwaveEquipped())
	if wanted then
		idle = 0
		local folder = remotes
		if not handle and not starting and folder and failedFor ~= folder then
			-- nil before the arena streams in: the runtime binds the real scene on its own.
			startClient(folder, sceneNow())
		end
	elseif handle and (not active or idle >= AdventureController.STOP_GRACE) then
		stopClient()
	end
	AdventureHUD.Update(arena)
	BroadwaveEquip.Refresh()
end

local function detach()
	for _, connection in remoteConnections do
		connection:Disconnect()
	end
	table.clear(remoteConnections)
	remotes = nil
	hauling = false
	stopClient()
	releaseAll()
	AdventureHUD.Update(false)
	BroadwaveEquip.Refresh()
end

local function watchCharacter(character: Model?)
	for _, connection in characterConnections do
		connection:Disconnect()
	end
	table.clear(characterConnections)
	if character then
		-- Equip / stow reacts in the same frame (start the charge, hand the control over).
		table.insert(characterConnections, character.ChildAdded:Connect(update))
		table.insert(characterConnections, character.ChildRemoved:Connect(update))
	end
end

local function startLoops()
	if loops then
		return
	end
	loops = true
	BroadwaveEquip.Start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < AdventureController.TICK then
			return
		end
		idle += acc
		acc = 0
		update()
	end)
	player.CharacterRemoving:Connect(function()
		hauling = false -- respawn while hauling: never carried into the next life
		InputArbiter.Suppress("AdventureHauling", false)
		watchCharacter(nil)
	end)
	player.CharacterAdded:Connect(function(character: Model)
		watchCharacter(character)
		update()
	end)
	watchCharacter(player.Character)
	Workspace.ChildRemoved:Connect(function(child: Instance)
		if child.Name == AdventureController.SCENE then
			hauling = false -- scene destroyed or rebuilt: the old attachment is gone
			update()
		end
	end)
end

local function attach(folder: Instance)
	if folder.Name ~= AdventureController.REMOTES or not folder:IsA("Folder") or remotes == folder then
		return
	end
	if remotes then
		detach()
	end
	remotes = folder
	failedFor = nil
	local function hookSnapshot(child: Instance)
		if child.Name == "Snapshot" and child:IsA("RemoteEvent") then
			table.insert(
				remoteConnections,
				child.OnClientEvent:Connect(function(data: any)
					hauling = type(data) == "table" and data.hauling == true
					update()
				end)
			)
		end
	end
	for _, child in folder:GetChildren() do
		hookSnapshot(child)
	end
	table.insert(remoteConnections, folder.ChildAdded:Connect(hookSnapshot))
	table.insert(
		remoteConnections,
		folder.AncestryChanged:Connect(function()
			if folder.Parent ~= ReplicatedStorage and remotes == folder then
				detach()
			end
		end)
	)
	startLoops()
	update()
end

function AdventureController.Init()
	ReplicatedStorage.ChildAdded:Connect(attach)
	local existing = ReplicatedStorage:FindFirstChild(AdventureController.REMOTES)
	if existing then
		attach(existing)
	end
end

function AdventureController.IsStarted(): boolean
	return handle ~= nil
end

function AdventureController.IsActive(): boolean
	return remotesAlive()
end

return AdventureController
