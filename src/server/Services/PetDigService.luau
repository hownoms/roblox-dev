--!strict
--[[
	PetDigService — digging pets (docs/V2.md "v2.1", docs/design/Companions.md).

	Every equipped pet with a Dig ability (vehicle pets from Construction Crates, a few creatures)
	digs ITS OWN spot on a ring around its owner, every Dig.Interval seconds:
	  - Ring: RING_MIN..RING_MAX studs (horizontal) from the owner's feet, wider for pets whose dig
	    carves a bigger cube. Pet k of n sits at angle k * 2pi / n plus a slow drift, so pets spread
	    around the owner instead of piling up.
	  - The spot is STABLE: a pet keeps digging the same spot (its own little pit) until the spot
	    gets too deep (more than MAX_BELOW studs under the owner's feet), too hard (TooHard), leaves
	    the ring (the owner walked off), leaves the dig zone, or comes near another player. Then it
	    re-picks (Shift += golden angle).
	  - NEVER under the owner: the dig point is >= RING_MIN (6) studs from the owner's feet, and the
	    voxel cube DigService would carve there (predicted with the same grid maths) must stay
	    OWNER_CLEARANCE studs away from the owner and from every other player. Points are also
	    >= OTHER_PLAYER_CLEARANCE (5) studs from other players.
	  - Deep in a hole the ring sits inside the hole wall: the pet digs the wall at the owner's foot
	    level (widens the hole around them at the owner's layer).
	  DigService.DigAt(player, point, { Power, Radius, SandMultiplier, Source = "Pet", Silent = true })
	Pets idle while the owner has no character, stands outside the dig zone (hub / boardwalk), or
	the backpack is full (one gentle Info notify per full backpack). Pet digs add no heat.
	Success -> PetDug(player, slot, petId, position, sandGained) to all clients, where slot is the
	pet's 1-based index in the owner's "EquippedPets" attribute (PetService: sorted equipped ids).

	Public API:
		PetDigService.GetDiggers(player): { { Slot: number, Id: string } }   active digging pets
		PetDigService.GetSpot(player, slot): Vector3?    current spot of that pet (tests / debug)
		PetDigService.Step(player)                        one dig-loop tick for a player (tests)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Stats = require(Shared.Util.Stats)
local Types = require(Shared.Types)

local DataService = require(script.Parent.DataService)
local DigService = require(script.Parent.DigService)
local MultiplierService = require(script.Parent.MultiplierService)
local Net = require(script.Parent.Net)
local PetService = require(script.Parent.PetService)
local World = require(script.Parent.Parent.World)

export type ActiveDigger = { Slot: number, Id: string }

local TICK = 0.1
local VOXEL = 4 -- DigService carves whole 4-stud voxels
local DENT_MAX_RADIUS = 2.2 -- DigService: radius <= this carves a ball instead of voxels
local DENT_BALL_RADIUS = 2.6
local RING_MIN = 6 -- studs from the owner's feet (horizontal): never closer
local RING_WIDTH = 5 -- ring = RING_MIN .. RING_MIN + RING_WIDTH (+ extra for big cubes)
local OWNER_CLEARANCE = 1.5 -- the carved cube keeps this far from the owner / other players
local OTHER_PLAYER_CLEARANCE = 5 -- dig points stay this far (horizontal) from other players
local MAX_BELOW = 6 -- a spot deeper than this below the owner's feet is "too deep"
local ABOVE_CHECK = 8 -- the down-ray starts this far above the owner's feet
local WALL_ABOVE = 3 -- ground higher than this above the feet = we are inside the hole wall
local DRIFT = 0.02 -- radians / second: the ring turns slowly so spots wander over time
local GOLDEN = 2.39996
local ATTEMPTS = 6
local TOO_HARD_NOTIFY_SECONDS = 60

local PetDigService = {}

type PetState = {
	NextDig: number?,
	Spot: Vector3?, -- XZ of the spot (Y ignored)
	Shift: number,
}

type PlayerState = {
	Pets: { [string]: PetState },
	FullNotified: boolean,
	LastTooHard: number,
}

local states: { [Player]: PlayerState } = {}
local rng = Random.new()
local loopStarted = false
local lastLoopWarn = -math.huge

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { Workspace.Terrain }

local function getState(player: Player): PlayerState
	local state = states[player]
	if not state then
		state = { Pets = {}, FullNotified = false, LastTooHard = -math.huge }
		states[player] = state
	end
	return state :: PlayerState
end

-- Active digging pets -------------------------------------------------------------------------------

-- Equipped pet ids in the same order as the "EquippedPets" attribute (PetService: sorted ids).
local function equippedIds(data: Types.PlayerData): { string }
	local ids = {}
	for _, pet in data.Pets do
		if pet.Equipped and Config.GetPet(pet.Id) then
			table.insert(ids, pet.Id)
		end
	end
	table.sort(ids)
	return ids
end

function PetDigService.GetDiggers(player: Player): { ActiveDigger }
	local data = DataService.Get(player)
	if not data then
		return {}
	end
	assert(data) -- refine for the type checker (guarded above)
	local ids = equippedIds(data)
	local slots = PetService.GetSlots(player)
	local list: { ActiveDigger } = {}
	for i, id in ids do
		if i > slots then
			break -- more equipped than slots (pass refund pending): only the first `slots` dig
		end
		if Config.GetPetDig(id) then
			table.insert(list, { Slot = i, Id = id })
		end
	end
	return list
end

function PetDigService.GetSpot(player: Player, slot: number): Vector3?
	local state = states[player]
	if not state then
		return nil
	end
	for key, pet in (state :: PlayerState).Pets do
		if string.match(key, "^(%d+):") == tostring(slot) then
			return pet.Spot
		end
	end
	return nil
end

-- Geometry ------------------------------------------------------------------------------------------

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function cellsFor(radius: number): number
	return math.max(1, math.floor(radius * 2 / VOXEL + 0.5))
end

-- Ring bounds for a dig radius: bigger cubes reach further, so they stay further out.
local function ringFor(radius: number): (number, number)
	local extra = if radius <= DENT_MAX_RADIUS then 0 else (cellsFor(radius) - 1) * VOXEL * 0.75
	local lo = RING_MIN + extra
	return lo, lo + RING_WIDTH
end

-- Horizontal box (min X, max X, min Z, max Z) DigService would carve for a dig at `point`
-- (same grid maths as DigService.carve, ignoring the zone-edge clamp which only moves it inward).
local function carveBox(point: Vector3, radius: number): (number, number, number, number)
	if radius <= DENT_MAX_RADIUS then
		local r = DENT_BALL_RADIUS
		return point.X - r, point.X + r, point.Z - r, point.Z + r
	end
	local cells = cellsFor(radius)
	local back = math.floor((cells - 1) / 2)
	local sx = (math.floor(point.X / VOXEL) - back) * VOXEL
	local sz = (math.floor(point.Z / VOXEL) - back) * VOXEL
	return sx, sx + cells * VOXEL, sz, sz + cells * VOXEL
end

local function boxNear(point: Vector3, radius: number, other: Vector3): boolean
	local x0, x1, z0, z1 = carveBox(point, radius)
	local c = OWNER_CLEARANCE
	return other.X > x0 - c and other.X < x1 + c and other.Z > z0 - c and other.Z < z1 + c
end

local function feetOf(root: BasePart): Vector3
	local humanoid = (root.Parent :: Instance):FindFirstChildOfClass("Humanoid")
	local hip = if humanoid then humanoid.HipHeight else 2
	return root.Position - Vector3.new(0, root.Size.Y / 2 + hip, 0)
end

-- True if the spot is fine for this owner right now (ring, zone, clearances).
local function spotOk(owner: Player, feet: Vector3, spot: Vector3, radius: number): boolean
	local lo, hi = ringFor(radius)
	local d = flat(spot - feet).Magnitude
	if d < lo - 0.01 or d > hi + 1.5 then
		return false
	end
	if not World.IsInDigZone(Vector3.new(spot.X, feet.Y, spot.Z)) then
		return false
	end
	if boxNear(spot, radius, feet) then
		return false
	end
	for _, other in Players:GetPlayers() do
		if other ~= owner then
			local root = Net.GetRoot(other)
			if root then
				local p = (root :: BasePart).Position
				if flat(p - spot).Magnitude < OTHER_PLAYER_CLEARANCE or boxNear(spot, radius, p) then
					return false
				end
			end
		end
	end
	return true
end

local function newSpot(
	owner: Player,
	feet: Vector3,
	slot: number,
	count: number,
	pet: PetState,
	radius: number
): Vector3?
	local lo, hi = ringFor(radius)
	local base = (slot - 1) * (2 * math.pi / math.max(count, 1)) + os.clock() * DRIFT + pet.Shift
	for attempt = 0, ATTEMPTS - 1 do
		local angle = base + attempt * 0.9
		local t = ((slot * 0.37) + pet.Shift * 0.13 + attempt * 0.29) % 1
		local r = lo + t * (hi - lo)
		local spot = feet + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
		if spotOk(owner, feet, spot, radius) then
			return spot
		end
	end
	return nil
end

-- True if the 4-stud terrain voxel containing `pos` holds solid ground (not air / water).
local function solidAt(pos: Vector3): boolean
	local cell = Vector3.new(math.floor(pos.X / VOXEL), math.floor(pos.Y / VOXEL), math.floor(pos.Z / VOXEL)) * VOXEL
	local ok, materials, occupancies = pcall(function()
		return Workspace.Terrain:ReadVoxels(Region3.new(cell, cell + Vector3.new(VOXEL, VOXEL, VOXEL)), VOXEL)
	end)
	if not ok then
		return false
	end
	assert(ok) -- refine for the type checker (guarded above)
	local material = materials[1][1][1]
	return material ~= Enum.Material.Air and material ~= Enum.Material.Water and occupancies[1][1][1] > 0
end

-- The point to dig at the pet's spot, or nil when the spot is used up (its pit is too deep).
-- DigService digs ~3 studs below the point it gets (non-shovel sources).
local function digPointAt(spot: Vector3, feet: Vector3): Vector3?
	local origin = Vector3.new(spot.X, feet.Y + ABOVE_CHECK, spot.Z)
	local hit = Workspace:Raycast(origin, Vector3.new(0, -(ABOVE_CHECK + MAX_BELOW), 0), terrainOnly)
	if hit and hit.Position.Y <= feet.Y + WALL_ABOVE then
		return hit.Position -- open ground (or the floor of the pet's own pit) near the owner's level
	end
	-- Ground far above the feet (the ring is inside the owner's hole wall) or no hit (the ray began
	-- inside solid wall, or the pit is deeper than MAX_BELOW): dig the wall at the owner's foot
	-- level, then one voxel lower; nothing solid there means the spot is used up.
	for _, dy in { 1, 1 - VOXEL } do
		local point = Vector3.new(spot.X, feet.Y + dy, spot.Z)
		if solidAt(point - Vector3.new(0, 3, 0)) then
			return point
		end
	end
	return nil
end

-- Dig loop ------------------------------------------------------------------------------------------

local function repick(pet: PetState)
	pet.Spot = nil
	pet.Shift += GOLDEN
end

function PetDigService.Step(player: Player)
	local data = DataService.Get(player)
	local root = Net.GetRoot(player)
	if not data or not root then
		return
	end
	assert(data) -- refine for the type checker (guarded above)
	assert(root) -- refine for the type checker (guarded above)
	local diggers = PetDigService.GetDiggers(player)
	local state = getState(player)
	if #diggers == 0 then
		table.clear(state.Pets)
		return
	end
	local now = os.clock()
	local feet = feetOf(root)

	-- forget pets that are no longer equipped in that slot
	local live: { [string]: boolean } = {}
	for _, a in diggers do
		live[a.Slot .. ":" .. a.Id] = true
	end
	for key in state.Pets do
		if not live[key] then
			state.Pets[key] = nil
		end
	end

	if not World.IsInDigZone(feet) then
		-- idle in the hub / on the boardwalk; start digging soon after stepping onto the sand
		for _, pet in state.Pets do
			pet.NextDig = math.max(pet.NextDig or 0, now + 0.5)
			pet.Spot = nil
		end
		return
	end
	local ctx = MultiplierService.GetContext(player)
	if not ctx then
		return
	end
	assert(ctx) -- refine for the type checker (guarded above)
	if data.Sand >= Stats.GetCapacity(ctx) then
		if not state.FullNotified then
			state.FullNotified = true
			Net.Notify(player, "Info", "Your pets stopped digging: backpack full! Sell to wake them up.")
		end
		return
	end
	state.FullNotified = false

	for _, a in diggers do
		local def = Config.GetPet(a.Id)
		local dig = Config.GetPetDig(a.Id)
		if not def or not dig then
			continue
		end
		assert(def) -- refine for the type checker (guarded above)
		assert(dig) -- refine for the type checker (guarded above)
		local key = a.Slot .. ":" .. a.Id
		local pet = state.Pets[key]
		if not pet then
			-- stagger freshly equipped pets so several never fire on the same frame
			state.Pets[key] = {
				NextDig = now + dig.Interval * (0.3 + 0.7 * rng:NextNumber()),
				Spot = nil,
				Shift = 0,
			}
			continue
		end
		local p = pet :: PetState
		if p.NextDig and now < (p.NextDig :: number) then
			continue
		end
		p.NextDig = now + dig.Interval

		local spot = p.Spot
		if spot and not spotOk(player, feet, spot :: Vector3, dig.Radius) then
			repick(p)
			spot = nil
		end
		if not spot then
			spot = newSpot(player, feet, a.Slot, #diggers, p, dig.Radius)
			if not spot then
				p.Shift += GOLDEN
				continue
			end
			p.Spot = spot
		end
		local point = digPointAt(spot :: Vector3, feet)
		if not point then
			repick(p)
			continue
		end
		local result = DigService.DigAt(player, point :: Vector3, {
			Power = dig.Power,
			Radius = dig.Radius,
			SandMultiplier = dig.SandMultiplier,
			Source = "Pet",
			Silent = true,
		})
		if result == nil then
			repick(p) -- no terrain there any more: the pit is too deep
			p.NextDig = now + 0.3
		elseif result.Success then
			Net.FireAll("PetDug", player, a.Slot, a.Id, result.Position, result.SandGained)
		elseif result.Reason == "TooHard" then
			repick(p)
			p.NextDig = now + dig.Interval * 3
			if now - state.LastTooHard > TOO_HARD_NOTIFY_SECONDS then
				state.LastTooHard = now
				Net.Notify(player, "Info", def.Name .. " can't dig this layer. Hatch a stronger digging pet!")
			end
		elseif result.Reason == "BackpackFull" then
			break
		else
			repick(p) -- OutOfZone / TooFar / Bottom
		end
	end
end

-- Lifecycle -----------------------------------------------------------------------------------------

function PetDigService.Start()
	if loopStarted then
		return
	end
	loopStarted = true
	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, player in DataService.GetLoadedPlayers() do
				local ok, err = pcall(function(): any
					PetDigService.Step(player)
					return nil
				end)
				if not ok and os.clock() - lastLoopWarn > 10 then
					lastLoopWarn = os.clock()
					warn("[PetDigService] dig loop error: " .. tostring(err))
				end
			end
		end
	end)
end

function PetDigService.OnPlayerRemoving(player: Player)
	states[player] = nil
end

return PetDigService
