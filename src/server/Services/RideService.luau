--!strict
--[[
	RideService — ride-on vehicles for rideable pets (v2.1, docs/V2.md "ride-on excavator").

	A player who owns any pet with PetDef.Rideable = true (Config.FindRideablePet over
	data.Pets; the best one by Dig.Power) fires "ToggleRide" to spawn its full-size vehicle
	(Models.RideVehicle, see Models/Rides.luau) on the sand next to them and get seated in it
	(Seat:Sit). "ToggleRide" again, jumping out of the seat, dying, respawning or leaving
	despawns it. One vehicle per player, in Workspace.Rides, named "Ride_<UserId>", with
	attributes OwnerUserId, PetId, DigInterval. Player attribute "Riding" = pet id while riding.

	Physics (chosen for robustness):
	- The vehicle is an UNANCHORED assembly (statics welded to Root, digging arm on Motor6Ds)
	  whose network owner is the rider, so driving has no input latency. Only the invisible hull
	  "Chassis" collides and has mass; every visible part is Massless and non-colliding, so the
	  arm / bucket can never bury, trap or fling a player.
	- It is driven by constraints, not BodyMovers: AlignPosition + AlignOrientation
	  (OneAttachment). The rider's RideController integrates throttle / steering into a target
	  pivot (yaw only, always level), clamps it to the ride area (RideMath.Bounds: dig zone +
	  boardwalk) and puts it on the ground (RideMath.GroundY). The server only sets the spawn
	  target and the force limit (assembly weight x Config.Ride.ForceGravities).
	- Holes: the vehicle stays at SURFACE level. Ground samples under the tracks never go below
	  Config.SURFACE_Y, so it drives OVER dug holes and trenches (bridging them) instead of
	  falling in. The bucket digs ahead and down (up to Config.Ride.MaxDigDepth below the
	  surface); deeper than that the player has to drive on.

	Digging: "RideDig" (no arguments; the client only says "scoop now"). Rate-limited to the
	pet's Dig.Interval (x IntervalLeniency). The server picks the point itself: DigAhead studs
	in front of the vehicle's SERVER-side pivot, on the terrain surface found by a downward
	raycast, then DigService.DigAt(player, point, { Source = "Ride", Power, Radius =
	max(Dig.Radius, Ride.MinRadius), SandMultiplier, Origin = vehicle position }). Sand goes to
	the backpack (capacity respected); failures are silent in DigService, so this service sends
	gentle throttled Notifies (backpack full / too hard / out of the zone / can't reach).
	Every scoop is broadcast with "RideDug"(player, position, success, layerIndex) so every
	client animates the bucket and bursts sand.

	Anti-cheat: every ValidateInterval the server samples the pivot. Faster than
	MaxSpeed x SpeedTolerance (+ SpeedSlack), outside the ride area (+ slack) or outside
	[SURFACE_Y + MinY, SURFACE_Y + MaxY] -> the vehicle is put back at the last valid pivot;
	MaxStrikes such resets in a row despawn it. Never seated within SeatTimeout -> despawn.

	Public API:
		RideService.IsRiding(player): boolean
		RideService.GetVehicle(player): Model?
		RideService.Despawn(player)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local Models = require(Shared.Models)
local RideMath = require(Shared.Util.RideMath)

local DataService = require(script.Parent.DataService)
local DigService = require(script.Parent.DigService)
local Net = require(script.Parent.Net)
local World = require(script.Parent.Parent.World)

local R = Config.Ride
local S = Config.SURFACE_Y
local TOGGLE_DEBOUNCE = 0.75
local BOUNDS_SLACK = 4

type Ride = {
	Player: Player,
	Def: Types.PetDef,
	Model: Model,
	Root: BasePart,
	Seat: Seat,
	Humanoid: Humanoid,
	AlignPosition: AlignPosition,
	AlignOrientation: AlignOrientation,
	Seated: boolean,
	SpawnedAt: number,
	LastDig: number,
	LastValid: CFrame,
	LastCheck: number,
	Strikes: number,
	Connections: { RBXScriptConnection },
}

local RideService = {}

local rides: { [Player]: Ride } = {}
local lastToggle: { [Player]: number } = {}
local folder: Folder? = nil
local zone = World.GetDigZone()
local bounds = RideMath.Bounds(zone.CFrame, zone.Size)

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { Workspace.Terrain }
terrainOnly.IgnoreWater = true

local function getFolder(): Folder
	local existing = folder
	if existing and existing.Parent then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = "Rides"
	f.Parent = Workspace
	folder = f
	return f
end

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

-- Level pivot (yaw only) at `position`, facing `look` flattened.
local function levelPivot(position: Vector3, look: Vector3): CFrame
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.05 then
		flat = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(position, position + flat.Unit)
end

function RideService.IsRiding(player: Player): boolean
	return rides[player] ~= nil
end

function RideService.GetVehicle(player: Player): Model?
	local ride = rides[player]
	return if ride then ride.Model else nil
end

function RideService.Despawn(player: Player)
	local ride = rides[player]
	if not ride then
		return
	end
	rides[player] = nil
	for _, connection in ride.Connections do
		connection:Disconnect()
	end
	-- Leave the seat first so the rider lands on their feet next to the vehicle.
	local humanoid = ride.Humanoid
	if ride.Seat.Occupant == humanoid and humanoid.Parent then
		humanoid.Sit = false
	end
	ride.Model:Destroy()
	player:SetAttribute("Riding", nil)
end

local function setTarget(ride: Ride, pivot: CFrame)
	ride.AlignPosition.Position = pivot.Position
	ride.AlignOrientation.CFrame = pivot.Rotation
end

local function spawnRide(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	assert(data) -- refine for the type checker (guarded above)
	local def = Config.FindRideablePet(data.Pets)
	if not def then
		Net.NotifyThrottled(player, "Error", "You need a rideable pet to ride! 🚜", "RideNoPet", 3)
		return
	end
	assert(def) -- refine for the type checker (guarded above)
	local humanoid = getHumanoid(player)
	local root = Net.GetRoot(player)
	if not humanoid or not root then
		return
	end
	assert(humanoid and root) -- refine for the type checker (guarded above)
	local spot = RideMath.Clamp(root.Position, bounds)
	local offset = Vector3.new(spot.X - root.Position.X, 0, spot.Z - root.Position.Z)
	if offset.Magnitude > R.SpawnMaxDistance then
		Net.NotifyThrottled(
			player,
			"Info",
			"Head down to the beach to ride your " .. def.Name .. "! 🏖️",
			"RideFar",
			3
		)
		return
	end

	local model = Models.RideVehicle(def.Id)
	model.Name = "Ride_" .. player.UserId
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("DigInterval", if def.Dig then def.Dig.Interval else 1)
	local vehicleRoot = model.PrimaryPart
	local seat = model:FindFirstChild("RideSeat")
	local chassis = model:FindFirstChild("Chassis")
	local alignPosition = vehicleRoot and vehicleRoot:FindFirstChild("RideAlignPosition")
	local alignOrientation = vehicleRoot and vehicleRoot:FindFirstChild("RideAlignOrientation")
	if
		not vehicleRoot
		or not seat
		or not seat:IsA("Seat")
		or not chassis
		or not chassis:IsA("BasePart")
		or not alignPosition
		or not alignPosition:IsA("AlignPosition")
		or not alignOrientation
		or not alignOrientation:IsA("AlignOrientation")
	then
		warn("[RideService] ride model is missing parts for " .. def.Id)
		model:Destroy()
		return
	end
	assert(vehicleRoot) -- refine for the type checker (guarded above)
	local rideSeat = seat :: Seat
	local hull = chassis :: BasePart
	local align = alignPosition :: AlignPosition

	local pivot = levelPivot(spot, root.CFrame.LookVector)
	pivot = pivot + Vector3.new(0, RideMath.GroundY(pivot) - pivot.Position.Y, 0)
	model:PivotTo(pivot)
	-- v2.3 streaming: the rider always has the whole vehicle (it owns its physics); everyone else
	-- streams it in and out as one unit.
	model.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer
	model:AddPersistentPlayer(player)
	model.Parent = getFolder()

	local ride: Ride = {
		Player = player,
		Def = def,
		Model = model,
		Root = vehicleRoot,
		Seat = rideSeat,
		Humanoid = humanoid,
		AlignPosition = align,
		AlignOrientation = alignOrientation :: AlignOrientation,
		Seated = false,
		SpawnedAt = os.clock(),
		LastDig = 0,
		LastValid = pivot,
		LastCheck = os.clock(),
		Strikes = 0,
		Connections = {},
	}
	setTarget(ride, pivot)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
		end
	end
	align.MaxForce = math.max(hull.AssemblyMass, hull:GetMass()) * Workspace.Gravity * R.ForceGravities
	pcall(function()
		hull:SetNetworkOwner(player)
	end)
	rides[player] = ride
	player:SetAttribute("Riding", def.Id)

	table.insert(
		ride.Connections,
		rideSeat:GetPropertyChangedSignal("Occupant"):Connect(function()
			if rideSeat.Occupant == humanoid then
				ride.Seated = true
			elseif ride.Seated and rides[player] == ride then
				RideService.Despawn(player) -- jumped out
			end
		end)
	)
	table.insert(
		ride.Connections,
		humanoid.Died:Connect(function()
			if rides[player] == ride then
				RideService.Despawn(player)
			end
		end)
	)
	table.insert(
		ride.Connections,
		player.CharacterRemoving:Connect(function()
			if rides[player] == ride then
				RideService.Despawn(player)
			end
		end)
	)

	humanoid:UnequipTools()
	rideSeat:Sit(humanoid)
	if rideSeat.Occupant == humanoid then
		ride.Seated = true
	end
end

local function onToggle(player: Player)
	local now = os.clock()
	if lastToggle[player] and now - lastToggle[player] < TOGGLE_DEBOUNCE then
		return
	end
	lastToggle[player] = now
	if rides[player] then
		RideService.Despawn(player)
	else
		spawnRide(player)
	end
end

local FAIL_TEXT: { [string]: { Kind: Net.NotifyKind, Text: string, Every: number } } = {
	BackpackFull = { Kind = "Info", Text = "Backpack full! Sell your sand, then scoop on 🚜", Every = 6 },
	TooHard = { Kind = "Error", Text = "Too hard for this bucket here! 🪨", Every = 5 },
	OutOfZone = { Kind = "Info", Text = "Scoop the sand by the water! 🏖️", Every = 4 },
	Bottom = { Kind = "Info", Text = "You reached the bottom of the world! 🌟", Every = 10 },
}

local function onRideDig(player: Player)
	local ride = rides[player]
	if not ride or not ride.Seated or ride.Model.Parent == nil then
		return
	end
	local dig = ride.Def.Dig
	if not dig then
		Net.NotifyThrottled(player, "Info", ride.Def.Name .. " can't dig.", "RideNoDig", 10)
		return
	end
	assert(dig) -- refine for the type checker (guarded above)
	local now = os.clock()
	if now - ride.LastDig < dig.Interval * R.IntervalLeniency then
		return
	end
	ride.LastDig = now

	-- The server decides where the bucket lands: in front of the vehicle, on the terrain.
	local pivot = ride.Root.CFrame
	local look = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z)
	look = if look.Magnitude > 0.05 then look.Unit else Vector3.new(0, 0, -1)
	local ahead = Vector3.new(pivot.Position.X, S, pivot.Position.Z) + look * R.DigAhead
	local hit = Workspace:Raycast(
		Vector3.new(ahead.X, S + 8, ahead.Z),
		Vector3.new(0, -(8 + R.MaxDigDepth + 4), 0),
		terrainOnly
	)
	if not hit or hit.Position.Y < S - R.MaxDigDepth then
		Net.NotifyThrottled(player, "Info", "The bucket can't reach deeper here, drive on! 🚜", "RideReach", 4)
		return
	end
	local point = hit.Position
	local result = DigService.DigAt(player, point, {
		Power = dig.Power,
		Radius = math.max(dig.Radius, R.MinRadius),
		SandMultiplier = dig.SandMultiplier,
		Source = "Ride",
		Origin = pivot.Position,
	})
	if not result then
		return
	end
	assert(result) -- refine for the type checker (guarded above)
	Net.FireAll("RideDug", player, point, result.Success, result.LayerIndex)
	local reason: string? = result.Reason
	if not result.Success and reason then
		local text = FAIL_TEXT[reason]
		if text then
			Net.NotifyThrottled(player, text.Kind, text.Text, "Ride" .. reason, text.Every)
		end
	end
end

-- Anti-cheat ------------------------------------------------------------------------------------

local function validate(ride: Ride, now: number)
	local player = ride.Player
	if ride.Model.Parent == nil or ride.Root.Parent == nil then
		RideService.Despawn(player)
		return
	end
	if not ride.Seated and now - ride.SpawnedAt > R.SeatTimeout then
		RideService.Despawn(player)
		return
	end
	local pivot = ride.Root.CFrame
	local pos = pivot.Position
	local dt = math.max(now - ride.LastCheck, 1e-3)
	ride.LastCheck = now
	local last = ride.LastValid.Position
	local moved = Vector3.new(pos.X - last.X, 0, pos.Z - last.Z).Magnitude
	local allowed = R.MaxSpeed * R.SpeedTolerance * dt + R.SpeedSlack
	local ok = moved <= allowed
		and RideMath.Inside(pos, bounds, BOUNDS_SLACK)
		and pos.Y >= S + R.MinY
		and pos.Y <= S + R.MaxY
	if ok then
		ride.Strikes = 0
		ride.LastValid = levelPivot(pos, pivot.LookVector)
		return
	end
	ride.Strikes += 1
	if ride.Strikes >= R.MaxStrikes then
		Net.NotifyThrottled(player, "Error", "Your ride went off the beach and was parked.", "RideReset", 5)
		RideService.Despawn(player)
		return
	end
	ride.Model:PivotTo(ride.LastValid)
	ride.Root.AssemblyLinearVelocity = Vector3.zero
	setTarget(ride, ride.LastValid)
end

-- Lifecycle -------------------------------------------------------------------------------------

function RideService.Init()
	Net.On("ToggleRide", function(player: Player)
		onToggle(player)
	end, { Rate = 4, Window = 2 })
	Net.On("RideDig", function(player: Player)
		onRideDig(player)
	end, { Rate = 12, Window = 1 })
end

function RideService.Start()
	task.spawn(function()
		while true do
			task.wait(R.ValidateInterval)
			local now = os.clock()
			for _, ride in rides do
				local ok, err = pcall(function(): any
					validate(ride, now)
					return nil
				end)
				if not ok then
					warn("[RideService] validate error: " .. tostring(err))
				end
			end
		end
	end)
end

function RideService.OnPlayerRemoving(player: Player)
	RideService.Despawn(player)
	lastToggle[player] = nil
end

return RideService
