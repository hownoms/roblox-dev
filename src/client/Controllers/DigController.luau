--!strict
--[[
	DigController — click / tap / hold (or gamepad R2) on terrain to dig.

	- Raycasts from the camera through the pointer, filtered to Workspace.Terrain only.
	- Local pre-checks (reach, inside the dig zone, cooldown, full backpack) avoid pointless
	  remote spam; the server stays authoritative and answers with DigResult.
	- Instant predicted feedback: scoop animation (ShovelPoseController.PlayScoop), layer-coloured
	  sand burst + chunks, dig sound, tiny camera shake.
	- DigResult: "+12 Sand" float text, new-layer banner, contextual hints for failures
	  ("Too hard! Get a better shovel" + guide beam to the ShovelShop, "Backpack full" + beam to
	  the SellZone). The server sends no Notify for dig failures, so each hint shows once.
	- PC/gamepad get a translucent dig cursor ball (green in reach, red out of reach).
	- Auto Dig (pass + "AutoDig" setting) digs straight down under the character.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))

local State = require(script.Parent.State)
local SoundController = require(script.Parent.SoundController)
local EffectsController = require(script.Parent.EffectsController)
local ShovelPoseController = require(script.Parent.ShovelPoseController)
local LayerController = require(script.Parent.LayerController)
local GuideController = require(script.Parent.GuideController)
local Signal = require(script.Parent.Parent.Util.Signal)
local Character = require(script.Parent.Parent.Util.Character)
local ItemStats = require(script.Parent.Parent.UI.ItemStats)

local DigController = {}

DigController.Dug = Signal.new() -- (DigResult) successful digs
DigController.Feedback = Signal.new() -- (reason: string) "TooHard" | "BackpackFull" | "OutOfZone" | "TooFar" | ...
DigController.Enabled = true -- UI can pause digging (e.g. while a modal is open)

type HoldKind = "Mouse" | "Touch" | "Gamepad"

local player = Players.LocalPlayer
local digRemote: RemoteEvent? = nil
local lastDig = 0
local holdKind: HoldKind? = nil
local holdInput: InputObject? = nil
local touchStart = Vector2.zero
local hintTimes: { [string]: number } = {}
local hintCallback: ((string, string) -> ())? = nil
local cursor: Part? = nil

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { Workspace.Terrain }
rayParams.IgnoreWater = true

-- UI provides the toast function (keeps this controller free of UI requires).
function DigController.SetHintCallback(fn: (string, string) -> ())
	hintCallback = fn
end

local function hint(key: string, text: string, kind: string, cooldown: number?)
	local now = os.clock()
	if hintTimes[key] and now - hintTimes[key] < (cooldown or 2.5) then
		return
	end
	hintTimes[key] = now
	if hintCallback then
		hintCallback(text, kind)
	end
end

local function insideDigZone(position: Vector3): boolean
	return State.InDigZone(position, 1.5)
end

-- Edge (studs) of the voxel cube the server carves for this shovel radius.
local function digEdge(radius: number): number
	return math.max(1, math.floor(radius / 2 + 0.5)) * 4
end

local function layerAt(position: Vector3): (Types.LayerDef, number)
	local depth = State.SurfaceY() - position.Y
	local index = Config.GetLayerIndexAtDepth(depth)
	return Config.Layers[index], index
end

local function ensureToolEquipped()
	local character = player.Character
	if not character or character:FindFirstChildOfClass("Tool") then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	local tool = if backpack then backpack:FindFirstChildOfClass("Tool") else nil
	local humanoid = Character.GetHumanoid()
	if tool and humanoid then
		humanoid:EquipTool(tool)
	end
end

-- Scoop animation (ShovelPoseController): plays immediately on the click, no server round trip.
local function swing(color: Color3?)
	ShovelPoseController.PlayScoop(nil, State.GetCooldown(), color)
end

local function getPointer(): (Vector2?, boolean)
	local camera = Workspace.CurrentCamera
	if holdKind == "Touch" then
		local input = holdInput
		if input then
			return Vector2.new(input.Position.X, input.Position.Y), false
		end
		return nil, false
	elseif holdKind == "Gamepad" then
		return camera.ViewportSize / 2, true
	end
	if UserInputService.GamepadEnabled and not UserInputService.MouseEnabled then
		return camera.ViewportSize / 2, true
	end
	return UserInputService:GetMouseLocation(), true
end

local function raycastPointer(pointer: Vector2, viewportSpace: boolean): RaycastResult?
	local camera = Workspace.CurrentCamera
	local ray = if viewportSpace
		then camera:ViewportPointToRay(pointer.X, pointer.Y)
		else camera:ScreenPointToRay(pointer.X, pointer.Y)
	return Workspace:Raycast(ray.Origin, ray.Direction * 300, rayParams)
end

-- Returns true if a dig request was sent.
function DigController.TryDigAt(position: Vector3): boolean
	if not DigController.Enabled then
		return false
	end
	local root = Character.GetRoot()
	if not root or not Character.GetHumanoid() then
		return false
	end
	local now = os.clock()
	if now - lastDig < State.GetCooldown() then
		return false
	end
	if (position - (root :: BasePart).Position).Magnitude > Config.REACH + 1 then
		lastDig = now
		hint("far", "Get closer to dig! 👣", "Info", 3)
		DigController.Feedback:Fire("TooFar")
		return false
	end
	if not insideDigZone(position) then
		lastDig = now
		hint("zone", "Dig on the sand by the water! 🏖️", "Warning", 3)
		DigController.Feedback:Fire("OutOfZone")
		return false
	end
	if State.Loaded and State.Data.Sand >= State.GetCapacity() then
		lastDig = now
		SoundController.Play("DigBlocked", 1.2, 0.6)
		hint("full", "Backpack full! Go SELL your sand 💰", "Warning", 4)
		DigController.Feedback:Fire("BackpackFull")
		return false
	end

	lastDig = now
	ensureToolEquipped()
	local layer = layerAt(position)
	swing(layer.Color)
	if State.GetShovel().Power < layer.Hardness then
		SoundController.Play("DigBlocked", 0.9 + math.random() * 0.2)
		EffectsController.FloatText(position, "Clank! 💢", Config.Theme.Colors.Danger, 0.9)
		EffectsController.Shake(0.25, 0.15)
		EffectsController.Burst(position, Color3.fromRGB(200, 200, 200), 4, 0.6)
	else
		-- better shovels hit harder: deeper thud, more sand and chunks, a touch more shake
		local heft = ItemStats.Heft(State.GetShovel().Id)
		SoundController.Play("Dig", (0.88 + math.random() * 0.24) / heft ^ 0.3, math.min(1.3, heft ^ 0.5))
		EffectsController.Burst(position, layer.Color, math.floor(12 * heft + 0.5))
		EffectsController.Chunks(position, layer.Color, math.floor(3 * heft + 0.5))
		EffectsController.Shake(0.12 * heft ^ 0.5, 0.1)
	end

	local remote = digRemote
	if remote then
		remote:FireServer(position)
	end
	return true
end

local function digAtPointer()
	local pointer, viewportSpace = getPointer()
	if not pointer then
		return
	end
	local result = raycastPointer(pointer :: Vector2, viewportSpace)
	if result then
		DigController.TryDigAt(result.Position)
	end
end

local function onDigResult(result: Types.DigResult)
	if typeof(result) ~= "table" then
		return
	end
	if typeof(result.Capacity) == "number" and result.Capacity > 0 then
		State.ServerCapacity = result.Capacity
	end
	if result.Success then
		local layer = Config.Layers[result.LayerIndex] or layerAt(result.Position)
		local color = Color3.new(1, 1, 1):Lerp(layer.Color, 0.35)
		EffectsController.FloatText(
			result.Position,
			"+" .. Format.Abbreviate(result.SandGained) .. " Sand",
			Config.Theme.Colors.Gold:Lerp(color, 0.2)
		)
		if typeof(result.Sand) == "number" then
			State.Apply({ Sand = result.Sand })
		end
		if result.NewLayer then
			LayerController.AnnounceNewLayer(result.LayerIndex)
			EffectsController.Shake(0.5, 0.35)
		end
		DigController.Dug:Fire(result)
		if result.Capacity and result.Sand >= result.Capacity then
			hint("full", "Backpack full! Go SELL your sand 💰", "Warning", 4)
			DigController.Feedback:Fire("BackpackFull")
		end
		return
	end
	local reason = result.Reason
	if reason == "TooHard" then
		hint("hard", "Too hard! Get a better shovel 🛠️", "Warning", 4)
	elseif reason == "BackpackFull" then
		hint("full", "Backpack full! Go SELL your sand 💰", "Warning", 4)
	elseif reason == "OutOfZone" then
		hint("zone", "Dig on the sand by the water! 🏖️", "Warning", 3)
	elseif reason == "TooFar" then
		hint("far", "Get closer to dig! 👣", "Info", 3)
	elseif reason == "Bottom" then
		hint("bottom", "You reached the bottom of the world! 🌟", "Success", 10)
	end
	if reason then
		DigController.Feedback:Fire(reason)
	end
end

-- Contextual guide beams: full backpack -> sell stand, too hard -> shovel shop.
local function setupGuides()
	DigController.Feedback:Connect(function(reason: string)
		local root = Character.GetRoot()
		local from = if root then root.Position else nil
		if reason == "TooHard" then
			local shop = GuideController.FindTagged("ShovelShop", from)
			if shop then
				GuideController.Set("TooHard", shop, 5, "pickaxe|🛠️", 8)
			end
		elseif reason == "BackpackFull" and not State.CanSellAnywhere() then
			local sell = GuideController.FindTagged("SellZone", from)
			if sell then
				GuideController.Set("SellHint", sell, 4, "Coins")
			end
		end
	end)
	State.Changed("Sand"):Connect(function(sand: number)
		if typeof(sand) == "number" and sand < State.GetCapacity() then
			GuideController.Clear("SellHint")
		end
	end)
	State.Changed("Shovel"):Connect(function()
		GuideController.Clear("TooHard")
	end)
end

local function getCursor(): Part
	if cursor and cursor.Parent then
		return cursor :: Part
	end
	local part = Instance.new("Part")
	part.Name = "DigCursor"
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Transparency = 0.75
	part.Parent = Workspace
	cursor = part
	return part
end

local function updateCursor()
	local show = DigController.Enabled and (UserInputService.MouseEnabled or UserInputService.GamepadEnabled)
	local root = Character.GetRoot()
	local result: RaycastResult? = nil
	if show and root then
		local pointer, viewportSpace = getPointer()
		if pointer and holdKind ~= "Touch" then
			result = raycastPointer(pointer :: Vector2, viewportSpace)
		end
	end
	if not result or not root then
		if cursor then
			cursor.Transparency = 1
		end
		return
	end
	local hit = result :: RaycastResult
	local part = getCursor()
	local edge = digEdge(State.GetShovel().Radius)
	part.Size = Vector3.new(edge, edge, edge)
	part.Position = hit.Position
	local inReach = ((root :: BasePart).Position - hit.Position).Magnitude <= Config.REACH
		and insideDigZone(hit.Position)
	part.Color = if inReach then Color3.fromRGB(120, 255, 140) else Color3.fromRGB(255, 90, 90)
	part.Transparency = if inReach then 0.78 else 0.88
end

local function autoDig()
	if not (State.OwnsPass("AutoDig") and State.GetSetting("AutoDig", false) == true) then
		return
	end
	local root = Character.GetRoot()
	if not root then
		return
	end
	local origin = (root :: BasePart).Position
	local result = Workspace:Raycast(origin, Vector3.new(0, -14, 0), rayParams)
	if result then
		DigController.TryDigAt(result.Position)
	end
end

function DigController.Init()
	task.spawn(function()
		digRemote = Remotes.Get("Dig")
		Remotes.Get("DigResult").OnClientEvent:Connect(onDigResult)
	end)
	setupGuides()

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			holdKind = "Mouse"
			digAtPointer()
		elseif input.UserInputType == Enum.UserInputType.Touch then
			holdKind = "Touch"
			holdInput = input
			touchStart = Vector2.new(input.Position.X, input.Position.Y)
			digAtPointer()
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			holdKind = "Gamepad"
			digAtPointer()
		end
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject)
		if holdKind == "Touch" and input == holdInput then
			local moved = (Vector2.new(input.Position.X, input.Position.Y) - touchStart).Magnitude
			if moved > 45 then
				-- the finger is dragging the camera, stop digging
				holdKind = nil
				holdInput = nil
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if
			(holdKind == "Mouse" and input.UserInputType == Enum.UserInputType.MouseButton1)
			or (holdKind == "Touch" and input == holdInput)
			or (holdKind == "Gamepad" and input.KeyCode == Enum.KeyCode.ButtonR2)
		then
			holdKind = nil
			holdInput = nil
		end
	end)

	local autoAcc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		if holdKind then
			digAtPointer()
		end
		autoAcc += dt
		if autoAcc >= 0.1 then
			autoAcc = 0
			if not holdKind then
				autoDig()
			end
		end
	end)

	RunService.RenderStepped:Connect(updateCursor)
end

return DigController
