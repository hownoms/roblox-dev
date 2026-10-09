--!strict
--[[
	AdventureController — starts Codex's SpringVaultClient in production, through the existing
	controller arbitration (docs/integration/production-wiring.md).

	  * Server-gated: starts only once the server has created ReplicatedStorage.SpringVaultAdventure
	    (AdventureBoot, AdventureFlags.SpringVault). The client never reads a flag; with the flag
	    off that folder never exists and nothing here binds, builds or yields.
	  * Digging pause (InputArbiter): "AdventureHauling" while the snapshot says this player is
	    attached to the ball; "AdventureArena" while standing in the arena, where every adventure
	    dialogue (Mara, Pip) and objective lives.
	  * Mobile: the runtime's Broadwave touch button is shown only while a Broadwave tool is
	    equipped (the runtime binds it for everyone).
]]
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local InputArbiter = require(script.Parent.InputArbiter)

local AdventureController = {}

AdventureController.REMOTES = "SpringVaultAdventure"
AdventureController.SCENE = "SpringVaultAdventure"
AdventureController.ACTION = "SpringVaultBroadwave"

local started = false
local handle: any = nil

local function inArena(): boolean
	local scene = Workspace:FindFirstChild(AdventureController.SCENE)
	local floor = scene and scene:FindFirstChild("ProtectedArenaFloor")
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not floor or not floor:IsA("BasePart") or not root or not root:IsA("BasePart") then
		return false
	end
	local rel = root.Position - floor.Position
	return math.abs(rel.X) <= floor.Size.X / 2 and math.abs(rel.Z) <= floor.Size.Z / 2 and rel.Y > -4 and rel.Y < 24
end

local function begin(remotes: Instance, scene: Instance)
	local Adventure = script.Parent.Parent:FindFirstChild("Adventure")
	local module = Adventure and Adventure:FindFirstChild("SpringVaultClient")
	if not module or not module:IsA("ModuleScript") then
		warn("[AdventureController] SpringVaultClient missing")
		return
	end
	local Client = (require :: any)(module)
	local ok, result = pcall(Client.Start, remotes, scene)
	if not ok then
		warn("[AdventureController] SpringVaultClient failed to start: " .. tostring(result))
		return
	end
	handle = result
	local snapshot = remotes:FindFirstChild("Snapshot")
	if snapshot and snapshot:IsA("RemoteEvent") then
		snapshot.OnClientEvent:Connect(function(data: any)
			InputArbiter.Suppress("AdventureHauling", type(data) == "table" and data.hauling == true)
		end)
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		InputArbiter.Suppress("AdventureArena", inArena())
		local button = ContextActionService:GetButton(AdventureController.ACTION)
		if button then
			button.Visible = InputArbiter.BroadwaveEquipped()
		end
	end)
end

local function withScene(remotes: Instance)
	local scene = Workspace:FindFirstChild(AdventureController.SCENE)
	if scene then
		begin(remotes, scene)
		return
	end
	local connection: RBXScriptConnection? = nil
	connection = Workspace.ChildAdded:Connect(function(child: Instance)
		if child.Name == AdventureController.SCENE and not handle then
			if connection then
				connection:Disconnect()
			end
			begin(remotes, child)
		end
	end)
end

local function onRemotes(folder: Instance)
	if started or folder.Name ~= AdventureController.REMOTES or not folder:IsA("Folder") then
		return
	end
	started = true
	withScene(folder)
end

function AdventureController.Init()
	local existing = ReplicatedStorage:FindFirstChild(AdventureController.REMOTES)
	if existing then
		onRemotes(existing)
		return
	end
	local connection: RBXScriptConnection? = nil
	connection = ReplicatedStorage.ChildAdded:Connect(function(child: Instance)
		onRemotes(child)
		if started and connection then
			connection:Disconnect()
		end
	end)
end

function AdventureController.IsStarted(): boolean
	return handle ~= nil
end

return AdventureController
