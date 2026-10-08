--!strict
--[[
	RideController — drives the ride-on vehicle (v2.1; server: Services/RideService).

	- Toggle (V / gamepad DPadUp / UI/RideButton): fires "ToggleRide" when the player owns a
	  rideable pet (Config.FindRideablePet over State.Data.Pets).
	- Riding = the local Humanoid sits in a "RideSeat" whose vehicle has OwnerUserId == us.
	  While riding:
	    * Input: the PlayerModule's GetControls():GetMoveVector() (WASD / arrows / thumbstick /
	      gamepad stick), else the keyboard, else Humanoid.MoveDirection. Forward/back = throttle,
	      left/right = steer (tank-style turn, also on the spot).
	    * The rider owns the assembly's physics: every frame a target pivot is integrated (speed
	      with acceleration, yaw rate), clamped to the ride area (RideMath.Bounds), put on the
	      ground (RideMath.GroundY: never below the surface, so holes are bridged) and written to
	      AlignPosition.Position / AlignOrientation.CFrame. If the real vehicle lags far behind
	      the target (blocked, or reset by the server) the target re-syncs to it.
	    * Dig: hold left mouse / R2 / the on-screen Dig button -> "RideDig" every DigInterval.
	      Shovel digging (DigController) is paused while riding.
	    * Camera: zoomed out (min zoom 18) and eased behind the vehicle while driving, unless the
	      player is dragging the camera.
	    * Engine: looped built-in sound (Config.Sounds.Dig id, slowed down; pitch follows speed).
	    * Jump leaves the seat (the server despawns the vehicle).
	- "RideDug"(player, position, success, layerIndex) from the server: every client plays the
	  bucket scoop (Motor6D.Transform on BoomMotor / StickMotor / BucketMotor) and a sand burst.

	API: RideController.CanRide(), .Toggle(), .SetDigHeld(held), .Riding, .RidingChanged (Signal),
	.CanRideChanged (Signal), .GetVehicle().
]]
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local RideMath = require(Shared:WaitForChild("Util"):WaitForChild("RideMath"))

local State = require(script.Parent.State)
local SoundController = require(script.Parent.SoundController)
local EffectsController = require(script.Parent.EffectsController)
local DigController = require(script.Parent.DigController)
local Signal = require(script.Parent.Parent.Util.Signal)
local Character = require(script.Parent.Parent.Util.Character)

local RideController = {}

RideController.Riding = false
RideController.RidingChanged = Signal.new() -- (riding: boolean)
RideController.CanRideChanged = Signal.new() -- (canRide: boolean)

local R = Config.Ride
local SCOOP_TIME = 0.9
local RESYNC_DISTANCE = 6
local MIN_ZOOM = 18
local CAMERA_FOLLOW_RATE = 2.2 -- 1/s
local CAMERA_IDLE_AFTER_DRAG = 1.2 -- seconds of no camera drag before auto-follow resumes

type Ride = {
	Model: Model,
	Root: BasePart,
	Seat: Seat,
	AlignPosition: AlignPosition,
	AlignOrientation: AlignOrientation,
	Position: Vector3,
	Yaw: number,
	Speed: number,
	LastDig: number,
	Engine: Sound?,
	DigWasEnabled: boolean,
	MinZoom: number,
}

type Scoop = { Start: number, Success: boolean }

local player = Players.LocalPlayer
local current: Ride? = nil
local canRide = false
local digButtonHeld = false
local mouseHeld = false
local padHeld = false
local lastCameraDrag = -math.huge
local cameraDragging = false
local controls: any = nil
local controlsTried = false
local bounds: RideMath.Bounds? = nil
local scoops: { [Model]: Scoop } = {}
local initialized = false

local function getBounds(): RideMath.Bounds?
	if bounds then
		return bounds
	end
	local zoneCFrame, zoneSize = State.GetDigZone()
	if zoneCFrame and zoneSize then
		bounds = RideMath.Bounds(zoneCFrame, zoneSize)
	end
	return bounds
end

local function getControls(): any
	if controlsTried then
		return controls
	end
	controlsTried = true
	local ok, result = pcall(function(): any
		local scripts = player:FindFirstChild("PlayerScripts")
		local module = if scripts then scripts:FindFirstChild("PlayerModule") else nil
		if module and module:IsA("ModuleScript") then
			return (require :: any)(module):GetControls()
		end
		return nil
	end)
	controls = if ok then result else nil
	return controls
end

function RideController.CanRide(): boolean
	return Config.FindRideablePet(State.Data.Pets) ~= nil
end

function RideController.GetVehicle(): Model?
	local ride = current
	return if ride then ride.Model else nil
end

function RideController.Toggle()
	if not RideController.Riding and not RideController.CanRide() then
		return
	end
	SoundController.Play("Click")
	Remotes.Get("ToggleRide"):FireServer()
end

function RideController.SetDigHeld(held: boolean)
	digButtonHeld = held
end

-- The ride model the local humanoid currently sits in, or nil.
local function seatedVehicle(): (Model?, Seat?)
	local humanoid = Character.GetHumanoid()
	local part: Instance? = if humanoid then humanoid.SeatPart else nil
	if not part then
		return nil, nil
	end
	assert(part) -- refine for the type checker (guarded above)
	if not part:IsA("Seat") or part.Name ~= "RideSeat" or part.Parent == nil then
		return nil, nil
	end
	local model = part.Parent
	if model and model:IsA("Model") and model:GetAttribute("OwnerUserId") == player.UserId then
		return model, part :: Seat
	end
	return nil, nil
end

local function yawOf(cf: CFrame): number
	local look = cf.LookVector
	return math.atan2(-look.X, -look.Z)
end

local function startRiding(model: Model, seat: Seat)
	local root = model.PrimaryPart
	local alignPosition = root and root:FindFirstChild("RideAlignPosition")
	local alignOrientation = root and root:FindFirstChild("RideAlignOrientation")
	if
		not root
		or not alignPosition
		or not alignPosition:IsA("AlignPosition")
		or not alignOrientation
		or not alignOrientation:IsA("AlignOrientation")
	then
		return
	end
	assert(root) -- refine for the type checker (guarded above)
	local pivot = root.CFrame
	local engine: Sound? = nil
	local def = Config.Sounds.Dig
	if def and def.Id ~= "" then
		local sound = Instance.new("Sound")
		sound.Name = "RideEngine"
		sound.SoundId = def.Id
		sound.Looped = true
		sound.Volume = if State.GetSetting("SFX", true) == false then 0 else def.Volume * 0.45
		sound.PlaybackSpeed = 0.35
		sound.RollOffMaxDistance = 80
		sound.Parent = root
		sound:Play()
		engine = sound
	end
	current = {
		Model = model,
		Root = root,
		Seat = seat,
		AlignPosition = alignPosition :: AlignPosition,
		AlignOrientation = alignOrientation :: AlignOrientation,
		Position = pivot.Position,
		Yaw = yawOf(pivot),
		Speed = 0,
		LastDig = 0,
		Engine = engine,
		DigWasEnabled = DigController.Enabled,
		MinZoom = player.CameraMinZoomDistance,
	}
	DigController.Enabled = false
	player.CameraMinZoomDistance = math.max(player.CameraMinZoomDistance, MIN_ZOOM)
	RideController.Riding = true
	RideController.RidingChanged:Fire(true)
end

local function stopRiding()
	local ride = current
	if not ride then
		return
	end
	assert(ride) -- refine for the type checker (guarded above)
	current = nil
	local engine = ride.Engine
	if engine then
		engine:Destroy()
	end
	DigController.Enabled = ride.DigWasEnabled
	player.CameraMinZoomDistance = ride.MinZoom
	mouseHeld = false
	padHeld = false
	digButtonHeld = false
	RideController.Riding = false
	RideController.RidingChanged:Fire(false)
end

-- Throttle (-1..1, + = forward) and steer (-1..1, + = turn left).
local function readInput(ride: Ride): (number, number)
	local c = getControls()
	if c then
		local ok, move = pcall(function(): any
			return c:GetMoveVector()
		end)
		if ok and typeof(move) == "Vector3" and move.Magnitude > 0.05 then
			return math.clamp(-move.Z, -1, 1), math.clamp(-move.X, -1, 1)
		end
	end
	local throttle, steer = 0, 0
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
		throttle += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
		throttle -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		steer += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
		steer -= 1
	end
	if throttle ~= 0 or steer ~= 0 then
		return throttle, steer
	end
	-- Last resort: the humanoid's world move direction relative to the vehicle.
	local humanoid = Character.GetHumanoid()
	local dir = if humanoid then humanoid.MoveDirection else Vector3.zero
	if dir.Magnitude > 0.05 then
		local look = Vector3.new(-math.sin(ride.Yaw), 0, -math.cos(ride.Yaw))
		local right = Vector3.new(-look.Z, 0, look.X)
		return math.clamp(dir:Dot(look), -1, 1), math.clamp(-dir:Dot(right), -1, 1)
	end
	return 0, 0
end

local function approach(value: number, target: number, step: number): number
	if value < target then
		return math.min(value + step, target)
	end
	return math.max(value - step, target)
end

local function drive(ride: Ride, dt: number)
	local b = getBounds()
	if not b then
		return
	end
	assert(b) -- refine for the type checker (guarded above)
	local throttle, steer = readInput(ride)
	local top = if throttle >= 0 then R.MaxSpeed else R.MaxSpeed * R.ReverseFactor
	ride.Speed = approach(ride.Speed, throttle * top, R.Acceleration * dt)
	ride.Yaw += steer * R.TurnRate * dt

	-- Re-sync when the real vehicle is far from the target (blocked by a prop, server reset).
	local actual = ride.Root.Position
	local gap = Vector3.new(actual.X - ride.Position.X, 0, actual.Z - ride.Position.Z)
	if gap.Magnitude > RESYNC_DISTANCE then
		ride.Position = actual
		ride.Speed *= 0.5
	end

	local look = Vector3.new(-math.sin(ride.Yaw), 0, -math.cos(ride.Yaw))
	local nextPos = RideMath.Clamp(ride.Position + look * ride.Speed * dt, b)
	local pivot = CFrame.new(nextPos.X, 0, nextPos.Z) * CFrame.Angles(0, ride.Yaw, 0)
	local y = RideMath.GroundY(pivot)
	pivot += Vector3.new(0, y, 0)
	ride.Position = pivot.Position
	ride.AlignPosition.Position = pivot.Position
	ride.AlignOrientation.CFrame = pivot.Rotation

	local engine = ride.Engine
	if engine then
		-- This spatial loop bypasses SoundController, so honour changes while seated too.
		engine.Volume = if State.GetSetting("SFX", true) == false then 0 else Config.Sounds.Dig.Volume * 0.45
		engine.PlaybackSpeed = 0.35 + 0.3 * math.abs(ride.Speed) / R.MaxSpeed
	end
end

local function followCamera(ride: Ride, dt: number)
	if cameraDragging or os.clock() - lastCameraDrag < CAMERA_IDLE_AFTER_DRAG or math.abs(ride.Speed) < 2 then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local focus = camera.Focus.Position
	local offset = camera.CFrame.Position - focus
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude < 1 then
		return
	end
	-- Behind the vehicle = opposite its heading (drive in reverse: keep the current side).
	local behindYaw = ride.Yaw
	local currentYaw = math.atan2(flat.X, flat.Z)
	local delta = (behindYaw - currentYaw + math.pi) % (2 * math.pi) - math.pi
	local turn = delta * math.min(1, CAMERA_FOLLOW_RATE * dt)
	local rotated = CFrame.Angles(0, turn, 0) * offset
	camera.CFrame = CFrame.lookAt(focus + rotated, focus)
end

local function tryDig(ride: Ride)
	if not (digButtonHeld or mouseHeld or padHeld) then
		return
	end
	local interval = ride.Model:GetAttribute("DigInterval")
	local wait = if typeof(interval) == "number" then interval else 1
	local now = os.clock()
	if now - ride.LastDig < wait then
		return
	end
	ride.LastDig = now
	Remotes.Get("RideDig"):FireServer()
end

-- Scoop animation -------------------------------------------------------------------------------

local function motors(model: Model): (Motor6D?, Motor6D?, Motor6D?)
	local boom = model:FindFirstChild("BoomMotor", true)
	local stick = model:FindFirstChild("StickMotor", true)
	local bucket = model:FindFirstChild("BucketMotor", true)
	return if boom and boom:IsA("Motor6D") then boom else nil,
		if stick and stick:IsA("Motor6D") then stick else nil,
		if bucket and bucket:IsA("Motor6D") then bucket else nil
end

local function poseScoop(model: Model, t: number, success: boolean)
	local boom, stick, bucket = motors(model)
	local dip = math.sin(math.pi * math.clamp(t, 0, 1)) -- 0 -> 1 -> 0
	local curl = math.clamp((t - 0.35) / 0.3, 0, 1) * (1 - math.clamp((t - 0.85) / 0.15, 0, 1))
	if boom then
		boom.Transform = CFrame.Angles(-0.32 * dip, 0, 0)
	end
	if stick then
		stick.Transform = CFrame.Angles(0.45 * dip - 0.25 * curl, 0, 0)
	end
	if bucket then
		bucket.Transform = CFrame.Angles(0.9 * curl, 0, 0)
	end
	local load = model:FindFirstChild("BucketSand", true)
	if load and load:IsA("BasePart") then
		load.Transparency = if success and t > 0.45 and t < 1 then 0 else 1
	end
end

local function updateScoops()
	local now = os.clock()
	for model, scoop in scoops do
		local t = (now - scoop.Start) / SCOOP_TIME
		if model.Parent == nil then
			scoops[model] = nil
		elseif t >= 1 then
			poseScoop(model, 1, false)
			scoops[model] = nil
		else
			poseScoop(model, t, scoop.Success)
		end
	end
end

local function findVehicle(owner: Player): Model?
	local folder = Workspace:FindFirstChild("Rides")
	local model = if folder then folder:FindFirstChild("Ride_" .. owner.UserId) else nil
	return if model and model:IsA("Model") then model else nil
end

local function onRideDug(owner: any, position: any, success: any, layerIndex: any)
	if typeof(owner) ~= "Instance" or not owner:IsA("Player") or typeof(position) ~= "Vector3" then
		return
	end
	local ok = success == true
	local model = findVehicle(owner)
	if model then
		scoops[model] = { Start = os.clock(), Success = ok }
	end
	local layer = Config.Layers[if typeof(layerIndex) == "number" then layerIndex else 1] or Config.Layers[1]
	-- the bucket bites a moment after the boom starts dropping
	task.delay(SCOOP_TIME * 0.35, function()
		if ok then
			EffectsController.Burst(position, layer.Color, 22, 1.4)
			EffectsController.Chunks(position, layer.Color, 6)
		else
			EffectsController.Burst(position, Color3.fromRGB(200, 200, 200), 6, 0.8)
		end
		if owner == player then
			SoundController.Play(if ok then "Dig" else "DigBlocked", 0.6 + math.random() * 0.1)
			EffectsController.Shake(if ok then 0.22 else 0.12, 0.15)
		end
	end)
end

-- Lifecycle -------------------------------------------------------------------------------------

local function refreshCanRide()
	local value = RideController.CanRide()
	if value ~= canRide then
		canRide = value
		RideController.CanRideChanged:Fire(value)
	end
end

local function step(dt: number)
	local model, seat = seatedVehicle()
	local ride = current
	if ride and (model ~= ride.Model or ride.Model.Parent == nil) then
		stopRiding()
		ride = nil
	end
	if not ride and model and seat then
		startRiding(model, seat)
		ride = current
	end
	if ride then
		drive(ride, dt)
		followCamera(ride, dt)
		tryDig(ride)
	end
	updateScoops()
end

function RideController.Init()
	if initialized then
		return
	end
	initialized = true

	State.Observe("Pets", function()
		refreshCanRide()
	end)

	ContextActionService:BindAction(
		"RideToggle",
		function(_, inputState: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
			if input.KeyCode == Enum.KeyCode.DPadUp and GuiService.SelectedObject ~= nil then
				return Enum.ContextActionResult.Pass -- gamepad UI navigation
			end
			if not RideController.Riding and not RideController.CanRide() then
				return Enum.ContextActionResult.Pass
			end
			if inputState == Enum.UserInputState.Begin then
				RideController.Toggle()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.KeyCode.V,
		Enum.KeyCode.DPadUp
	)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			cameraDragging = true
			lastCameraDrag = os.clock()
		elseif input.UserInputType == Enum.UserInputType.Touch then
			lastCameraDrag = os.clock()
		end
		if processed or not RideController.Riding then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			mouseHeld = true
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			padHeld = true
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.Thumbstick2 and input.Position.Magnitude > 0.2 then
			lastCameraDrag = os.clock()
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			cameraDragging = false
			lastCameraDrag = os.clock()
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			mouseHeld = false
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			padHeld = false
		end
	end)
	UserInputService.JumpRequest:Connect(function()
		if RideController.Riding then
			local humanoid = Character.GetHumanoid()
			if humanoid then
				humanoid.Sit = false
			end
		end
	end)

	task.spawn(function()
		Remotes.Get("RideDug").OnClientEvent:Connect(onRideDug)
	end)
	RunService.Heartbeat:Connect(step)
end

return RideController
