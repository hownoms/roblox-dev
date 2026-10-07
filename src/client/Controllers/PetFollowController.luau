--!strict
--[[
	PetFollowController — renders equipped pets for ALL players, client-side only, and plays the
	dig animation of digging pets (v2.1 companions: vehicle pets from Construction Crates and a few
	creatures; docs/design/Companions.md).

	Source of truth per player: Player attribute "EquippedPets" (comma-separated PetDef ids, sorted),
	set by PetService. For the local player we fall back to PlayerData.Pets (Equipped = true)
	whenever the attribute is missing, so our own pets show even if the server never sets it.

	Following:
	  - Creature pets trail behind the character in a little arc, bob up and down (flyers float
	    higher), smoothly lerp toward their slot and face where the owner is heading.
	  - Vehicle pets (PetDef.VehicleKind, Models/Diggers at pet scale) drive in a row behind the
	    creatures, snapped to the ground under them, with a little engine bob. Behind the owner
	    is solid wall (deep hole) or a big drop: they tuck in close at the owner's level.
	Digging (PetDug(player, slot, petId, position, sandGained) from PetDigService):
	  - The pet DRIVES / WALKS smoothly to its spot (never teleports): it parks PARK_DISTANCE
	    beyond the dig point on the side away from the owner, faces the hole and plays the dig
	    animation (vehicles: their "Motion" sub-Models — arm swing, bed tip, drill spin/plunge, see
	    Models/Diggers; creatures: a scooping hop). A layer-coloured burst pops at the point; the
	    owner also sees "+N", sand chunks and a soft dig sound.
	  - Between digs it stays parked at its spot while the owner stays put (PARK_HOLD seconds after
	    the last dig, cancelled as soon as the owner walks OWNER_LEAVE studs away), then follows.
	Far-away players' pets are hidden; LowGraphics hides other players' pets entirely.
	v2.2: Player attribute "EquippedGolden" (comma-separated 1-based slots in "EquippedPets") marks
	Golden pets; they render gold-tinted with sparkles (ModelFactory.MakeGolden).

	Public (tests): PetFollowController.GetVisuals(player)
	  -> { { Id, Golden, Slot, Model, Vehicle: boolean, Digging: boolean, Parked: boolean } }
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Stats = require(Shared:WaitForChild("Util"):WaitForChild("Stats"))

local State = require(script.Parent.State)
local EffectsController = require(script.Parent.EffectsController)
local SoundController = require(script.Parent.SoundController)
local ModelFactory = require(script.Parent.Parent.Util.ModelFactory)
local Character = require(script.Parent.Parent.Util.Character)

local PetFollowController = {}

local ATTRIBUTE = "EquippedPets"
local GOLDEN_ATTRIBUTE = "EquippedGolden" -- v2.2: slots (1-based) of Golden pets in ATTRIBUTE
local RENDER_DISTANCE = 220
local FLYING_SHAPES = { Bird = true, Dragon = true, Star = true, Squid = true, Fish = true }

local VEHICLE_ROW = 8.5 -- studs behind the owner (creature pets use ~4.5-8)
local VEHICLE_SPACING = 4.5
local NEAR_HEIGHT = 6 -- ground this far above / below the feet counts as "not reachable"
local NEAR_SCALE = 0.4 -- vehicle slot offset scale when tucked in close
local GROUND_REFRESH = 0.2
local SNAP_DISTANCE = 60 -- further than this from its target: snap (respawn / long teleport)
local MAX_SPEED = 28 -- studs / second: pets drive / walk, they never jump across the beach

local PARK_DISTANCE = 2.4 -- the pet parks this far beyond its dig point (away from the owner)
local APPROACH_MAX = 1.6 -- seconds to drive to the spot before digging anyway
local ARRIVE_DISTANCE = 1.2
local DIG_DURATION = 0.8 -- seconds of one dig animation
local PARK_HOLD = 4 -- stay at the spot this long after the last dig...
local OWNER_LEAVE = 6 -- ...unless the owner walks this far away

type Joint = {
	Model: Model,
	Rest: CFrame, -- hinge pivot relative to the model pivot
	Motion: string,
	Amount: number,
	Plunge: number,
	Spin: number,
	Posed: boolean,
}

type Action = {
	Target: Vector3, -- dig point
	Park: Vector3?, -- ground position to stand on (resolved on first frame)
	Start: number,
	DigStart: number?,
	Sand: number,
	Burst: boolean,
}

type Park = {
	Position: Vector3,
	Face: Vector3,
	OwnerPos: Vector3,
	Until: number,
}

type PetVisual = {
	Id: string,
	Golden: boolean,
	Slot: number, -- 1-based index in the owner's equipped list (= PetDug slot)
	Model: Model,
	Offset: Vector3, -- pivot -> bottom correction
	Current: CFrame?,
	Flying: boolean,
	Vehicle: boolean,
	Phase: number,
	Joints: { Joint },
	GroundY: number?,
	NextGround: number,
	Near: boolean,
	Action: Action?,
	Park: Park?,
}

type Entry = {
	Key: string,
	Pets: { PetVisual },
}

local entries: { [Player]: Entry } = {}
local folder: Folder? = nil
local localUsesAttribute = false

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater = false
local nextFilterRefresh = 0

local function getFolder(): Folder
	if not folder or not folder.Parent then
		local f = Instance.new("Folder")
		f.Name = "ClientPets"
		f.Parent = Workspace
		folder = f
	end
	return folder :: Folder
end

local function refreshFilter(now: number)
	if now < nextFilterRefresh then
		return
	end
	nextFilterRefresh = now + 1
	local list: { Instance } = { getFolder() }
	local effects = Workspace:FindFirstChild("ClientEffects")
	if effects then
		table.insert(list, effects)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	groundParams.FilterDescendantsInstances = list
end

local function groundBelow(position: Vector3): number?
	local hit = Workspace:Raycast(position + Vector3.new(0, 8, 0), Vector3.new(0, -40, 0), groundParams)
	return if hit then hit.Position.Y else nil
end

local function parse(value: any): { string }
	local ids = {}
	if typeof(value) == "string" then
		for id in string.gmatch(value, "[^,%s]+") do
			if Config.GetPet(id) then
				table.insert(ids, id)
			end
		end
	end
	return ids
end

local function collectJoints(model: Model): { Joint }
	local joints = {}
	local pivot = model:GetPivot()
	for _, d in model:GetDescendants() do
		if d:IsA("Model") and typeof(d:GetAttribute("Motion")) == "string" then
			local amount = d:GetAttribute("Amount")
			local plunge = d:GetAttribute("Plunge")
			table.insert(joints, {
				Model = d,
				Rest = pivot:ToObjectSpace(d:GetPivot()),
				Motion = d:GetAttribute("Motion") :: string,
				Amount = if typeof(amount) == "number" then amount else 0.4,
				Plunge = if typeof(plunge) == "number" then plunge else 0,
				Spin = 0,
				Posed = false,
			})
		end
	end
	return joints
end

local function clear(entry: Entry)
	for _, pet in entry.Pets do
		pet.Model:Destroy()
	end
	table.clear(entry.Pets)
end

-- "2,3" -> { [2] = true, [3] = true }
local function parseGolden(value: any): { [number]: boolean }
	local slots: { [number]: boolean } = {}
	if typeof(value) == "string" then
		for n in string.gmatch(value, "%d+") do
			slots[tonumber(n) :: number] = true
		end
	end
	return slots
end

-- ids in "EquippedPets" order (Stats.SortEquipped: by id, normal before Golden); golden[slot].
local function setPets(player: Player, ids: { string }, golden: { [number]: boolean }?)
	local goldenSlots: { [number]: boolean } = golden or {}
	local keyParts: { string } = {}
	for i, id in ids do
		keyParts[i] = id .. (if goldenSlots[i] then "*" else "")
	end
	local key = table.concat(keyParts, ",")
	local entry = entries[player]
	if not entry then
		entry = { Key = "", Pets = {} }
		entries[player] = entry
	end
	local e = entry :: Entry
	if e.Key == key then
		return
	end
	e.Key = key
	-- keep models (and their position) for pets that stay equipped
	local old: { [string]: { PetVisual } } = {}
	for _, pet in e.Pets do
		local oldKey = pet.Id .. (if pet.Golden then "*" else "")
		old[oldKey] = old[oldKey] or {}
		table.insert(old[oldKey], pet)
	end
	local fresh: { PetVisual } = {}
	for i, id in ids do
		local isGolden = goldenSlots[i] == true
		local reuseKey = id .. (if isGolden then "*" else "")
		local reuse = old[reuseKey] and table.remove(old[reuseKey], 1)
		if reuse then
			reuse.Slot = i
			table.insert(fresh, reuse)
			continue
		end
		local def = Config.GetPet(id)
		local model = ModelFactory.Pet(id)
		if isGolden then
			ModelFactory.MakeGolden(model)
		end
		ModelFactory.MakeVisualOnly(model, false)
		model.Name = player.Name .. "_" .. id
		local boxCFrame, size = model:GetBoundingBox()
		local pivot = model:GetPivot()
		local offset = Vector3.new(0, pivot.Position.Y - (boxCFrame.Position.Y - size.Y / 2), 0)
		model.Parent = getFolder()
		local vehicle = def ~= nil and def.VehicleKind ~= nil
		table.insert(fresh, {
			Id = id,
			Golden = isGolden,
			Slot = i,
			Model = model,
			Offset = offset,
			Current = nil,
			Flying = def ~= nil and not vehicle and FLYING_SHAPES[def.Look.Shape] == true,
			Vehicle = vehicle,
			Phase = i * 1.7,
			Joints = if vehicle then collectJoints(model) else {},
			GroundY = nil,
			NextGround = 0,
			Near = false,
			Action = nil,
			Park = nil,
		})
	end
	for _, list in old do
		for _, pet in list do
			pet.Model:Destroy()
		end
	end
	e.Pets = fresh
end

local function refresh(player: Player)
	local value = player:GetAttribute(ATTRIBUTE)
	if player == Players.LocalPlayer then
		localUsesAttribute = typeof(value) == "string"
		if not localUsesAttribute then
			local ids: { string } = {}
			local golden: { [number]: boolean } = {}
			for i, pet in Stats.SortEquipped(State.Data.Pets or {}) do
				ids[i] = pet.Id
				golden[i] = pet.Golden == true
			end
			setPets(player, ids, golden)
			return
		end
	end
	setPets(player, parse(value), parseGolden(player:GetAttribute(GOLDEN_ATTRIBUTE)))
end

local function track(player: Player)
	player:GetAttributeChangedSignal(ATTRIBUTE):Connect(function()
		refresh(player)
	end)
	player:GetAttributeChangedSignal(GOLDEN_ATTRIBUTE):Connect(function()
		refresh(player)
	end)
	refresh(player)
end

-- Slot positions behind the owner: up to 3 creatures in the first row, the rest in a second row.
local function slotOffset(index: number, count: number): Vector3
	local perRow = 3
	local row = math.floor((index - 1) / perRow)
	local inRow = math.min(perRow, count - row * perRow)
	local col = (index - 1) % perRow
	local x = (col - (inRow - 1) / 2) * 3.2
	local z = 4.5 + row * 3.2 + math.abs(x) * 0.25
	return Vector3.new(x, 0, z)
end

-- Vehicles drive in their own row behind the creatures.
local function vehicleOffset(index: number, count: number, creatureRows: number): Vector3
	local x = (index - (count + 1) / 2) * VEHICLE_SPACING
	return Vector3.new(x, 0, VEHICLE_ROW + math.max(creatureRows - 1, 0) * 3.2 + math.abs(x) * 0.15)
end

-- Animation ----------------------------------------------------------------------------------

local function poseJoints(pet: PetVisual, pivot: CFrame, digAlpha: number, dt: number, reducedMotion: boolean)
	for _, j in pet.Joints do
		local active = digAlpha > 0 or j.Motion == "Spin" or j.Motion == "Drill"
		if not active and not j.Posed then
			continue
		end
		local base = pivot * j.Rest
		local wave = math.sin(math.pi * digAlpha)
		local pose = base
		if j.Motion == "Swing" then
			pose = base * CFrame.Angles(j.Amount * wave, 0, 0)
		elseif j.Motion == "Tip" then
			pose = base * CFrame.Angles(j.Amount * wave * wave, 0, 0)
		elseif j.Motion == "Spin" or j.Motion == "Drill" then
			-- idle drills turn slowly, digging drills spin fast
			if digAlpha > 0 or not reducedMotion then
				j.Spin = (j.Spin + dt * j.Amount * (if digAlpha > 0 then 1 else 0.06)) % (math.pi * 2)
			end
			pose = base * CFrame.new(0, j.Plunge * wave, 0) * CFrame.Angles(0, j.Spin, 0)
		end
		j.Model:PivotTo(pose)
		j.Posed = active
	end
end

local function layerColor(position: Vector3): Color3
	return Config.GetLayerAtDepth(Config.SURFACE_Y - position.Y).Color
end

local function onDug(owner: Player, action: Action)
	local color = layerColor(action.Target)
	local mine = owner == Players.LocalPlayer
	EffectsController.Burst(action.Target, color, if mine then 12 else 6, 0.8)
	if mine then
		EffectsController.Chunks(action.Target, color, 4)
		if action.Sand > 0 then
			EffectsController.FloatText(
				action.Target + Vector3.new(0, 2, 0),
				"+" .. Format.Abbreviate(action.Sand),
				Color3.fromRGB(255, 225, 140),
				0.75
			)
		end
		SoundController.Play("Dig", 0.7 + math.random() * 0.15, 0.35)
	end
end

local function flatUnit(v: Vector3, fallback: Vector3): Vector3
	local f = v * Vector3.new(1, 0, 1)
	return if f.Magnitude > 0.01 then f.Unit else fallback
end

-- Where the pet wants to be this frame. Returns target position (bottom of the pet), the direction
-- to face (nil = face where it moves), the dig animation alpha (0 = not digging) and the follow
-- speed.
local function digTarget(
	owner: Player,
	pet: PetVisual,
	ownerPos: Vector3,
	now: number
): (Vector3?, Vector3?, number, number)
	local action = pet.Action
	if action then
		local a = action :: Action
		if not a.Park then
			local away = flatUnit(a.Target - ownerPos, Vector3.new(0, 0, 1))
			local spot = a.Target + away * PARK_DISTANCE
			local y = groundBelow(Vector3.new(spot.X, a.Target.Y + 2, spot.Z)) or a.Target.Y
			a.Park = Vector3.new(spot.X, y, spot.Z)
		end
		local park = a.Park :: Vector3
		local face = flatUnit(a.Target - park, Vector3.new(0, 0, -1))
		if not a.DigStart then
			local here = if pet.Current then (pet.Current :: CFrame).Position - pet.Offset else park
			local arrived = ((here - park) * Vector3.new(1, 0, 1)).Magnitude < ARRIVE_DISTANCE
			if arrived or now - a.Start > APPROACH_MAX then
				a.DigStart = now
			end
		end
		local digAlpha = 0
		if a.DigStart then
			local t = (now - (a.DigStart :: number)) / DIG_DURATION
			if t >= 1 then
				pet.Action = nil
				pet.Park = { Position = park, Face = face, OwnerPos = ownerPos, Until = now + PARK_HOLD }
				return park, face, 0, 6
			end
			digAlpha = math.max(t, 0.001)
			if not a.Burst and t >= 0.45 then
				a.Burst = true
				onDug(owner, a)
			end
		end
		return park, face, digAlpha, 6
	end
	local parked = pet.Park
	if parked then
		local p = parked :: Park
		local left = ((ownerPos - p.OwnerPos) * Vector3.new(1, 0, 1)).Magnitude > OWNER_LEAVE
		if left or now > p.Until then
			pet.Park = nil
		else
			return p.Position, p.Face, 0, 6
		end
	end
	return nil, nil, 0, 0
end

local function update(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPos = camera.CFrame.Position
	local low = State.GetSetting("LowGraphics", false) == true
	local reducedMotion = State.GetSetting("ReducedMotion", false) == true
	local now = os.clock()
	refreshFilter(now)
	for player, entry in entries do
		local root = Character.GetRoot(player)
		local visible = root ~= nil
			and (root :: BasePart).Position.Y > -400
			and ((root :: BasePart).Position - cameraPos).Magnitude < RENDER_DISTANCE
			and not (low and player ~= Players.LocalPlayer)
		local creatures, vehicles = 0, 0
		for _, pet in entry.Pets do
			if pet.Vehicle then
				vehicles += 1
			else
				creatures += 1
			end
		end
		local creatureRows = math.ceil(creatures / 3)
		local creatureIndex, vehicleIndex = 0, 0
		for _, pet in entry.Pets do
			if pet.Vehicle then
				vehicleIndex += 1
			else
				creatureIndex += 1
			end
			if not visible or not root then
				if pet.Model.Parent then
					pet.Model.Parent = nil
				end
				pet.Current = nil
				pet.Action = nil
				pet.Park = nil
				continue
			end
			if not pet.Model.Parent then
				pet.Model.Parent = getFolder()
			end
			local rootCFrame = (root :: BasePart).CFrame
			local flatLook = flatUnit(rootCFrame.LookVector, Vector3.new(0, 0, -1))
			local flat = CFrame.lookAt(rootCFrame.Position, rootCFrame.Position + flatLook)
			local feetY = rootCFrame.Position.Y - 3
			local ownerPos = Vector3.new(rootCFrame.Position.X, feetY, rootCFrame.Position.Z)

			local digPos, face, digAlpha, digSpeed = digTarget(player, pet, ownerPos, now)
			local target: Vector3
			local speed = 9
			if digPos then
				target = (digPos :: Vector3) + Vector3.new(0, if pet.Flying then 2.2 else 0, 0)
				speed = digSpeed
			elseif pet.Vehicle then
				local offset = vehicleOffset(vehicleIndex, vehicles, creatureRows)
				if pet.Near then
					offset *= NEAR_SCALE
				end
				local slot = flat:PointToWorldSpace(offset)
				if now >= pet.NextGround or pet.GroundY == nil then
					pet.NextGround = now + GROUND_REFRESH + math.random() * 0.05
					-- Behind the owner is solid wall (deep in a hole) or a big drop: tuck in close
					-- at the owner's level instead of vanishing into the terrain.
					local far = groundBelow(flat:PointToWorldSpace(vehicleOffset(vehicleIndex, vehicles, creatureRows)))
					pet.Near = far == nil or math.abs((far :: number) - feetY) > NEAR_HEIGHT
					if pet.Near then
						local nearOffset = vehicleOffset(vehicleIndex, vehicles, creatureRows) * NEAR_SCALE
						pet.GroundY = groundBelow(flat:PointToWorldSpace(nearOffset)) or feetY
					else
						pet.GroundY = far
					end
				end
				target = Vector3.new(slot.X, pet.GroundY or feetY, slot.Z)
				speed = 5
			else
				local slot = flat:PointToWorldSpace(slotOffset(creatureIndex, creatures))
				local bob = if reducedMotion then 0 else math.sin(now * 3 + pet.Phase) * 0.35
				local height = if pet.Flying then 2.2 + bob * 1.4 else -2.6 + math.max(bob, 0) * 1.2
				target = slot + Vector3.new(0, height, 0)
			end
			target += pet.Offset

			local current = pet.Current
			local position: Vector3
			if not current or ((current :: CFrame).Position - target).Magnitude > SNAP_DISTANCE then
				position = target
			else
				local from = (current :: CFrame).Position
				position = from:Lerp(target, 1 - math.exp(-dt * speed))
				local stepVec = position - from
				local maxStep = MAX_SPEED * dt
				if stepVec.Magnitude > maxStep then
					position = from + stepVec.Unit * maxStep
				end
			end
			local moved = if current
				then (position - (current :: CFrame).Position) * Vector3.new(1, 0, 1)
				else Vector3.zero
			local look = flatLook
			if face then
				look = face :: Vector3
			elseif pet.Vehicle then
				-- vehicles keep their heading until they drive somewhere
				if moved.Magnitude > dt * 1.5 then
					look = moved.Unit
				elseif current then
					look = flatUnit((current :: CFrame).LookVector, flatLook)
				end
			elseif current then
				-- creatures face where they are going, else where the owner is heading
				local toTarget = (target - (current :: CFrame).Position) * Vector3.new(1, 0, 1)
				if toTarget.Magnitude > 0.4 then
					look = toTarget.Unit
				end
			end
			-- turn smoothly instead of snapping
			if current then
				local prev = flatUnit((current :: CFrame).LookVector, look)
				look = flatUnit(prev:Lerp(look, 1 - math.exp(-dt * 8)), look)
			end

			local pivot = CFrame.lookAt(position, position + look)
			pet.Current = pivot
			local shown = pivot
			if pet.Vehicle and not reducedMotion then
				local driving = math.clamp(moved.Magnitude / math.max(dt, 1e-3) / 16, 0, 1)
				local bob = math.abs(math.sin(now * 9 + pet.Phase)) * (0.04 + 0.12 * driving)
				local rumble = if digAlpha > 0 then math.sin(now * 40) * 0.03 else 0
				shown = pivot * CFrame.new(0, bob + rumble, 0) * CFrame.Angles(-driving * 0.04, 0, 0)
			elseif not pet.Vehicle and digAlpha > 0 then
				-- creatures: two quick scooping hops toward the hole
				local wave = math.abs(math.sin(math.pi * 2 * digAlpha))
				shown = pivot * CFrame.new(0, wave * 0.5, -wave * 0.2) * CFrame.Angles(-wave * 0.45, 0, 0)
			elseif pet.Flying and not reducedMotion then
				shown = pivot * CFrame.Angles(0, 0, math.sin(now * 2 + pet.Phase) * 0.12)
			end
			pet.Model:PivotTo(shown)
			if pet.Vehicle then
				poseJoints(pet, shown, digAlpha, dt, reducedMotion)
			end
		end
	end
end

local function onPetDug(player: any, slot: any, petId: any, position: any, sand: any)
	if
		typeof(player) ~= "Instance"
		or not (player :: Instance):IsA("Player")
		or typeof(petId) ~= "string"
		or typeof(position) ~= "Vector3"
	then
		return
	end
	local entry = entries[player :: Player]
	if not entry then
		return
	end
	local target: PetVisual? = nil
	if typeof(slot) == "number" then
		local candidate = (entry :: Entry).Pets[slot]
		if candidate and candidate.Id == petId then
			target = candidate
		end
	end
	if not target then
		for _, pet in (entry :: Entry).Pets do
			if pet.Id == petId then
				target = pet
				break
			end
		end
	end
	if not target then
		return
	end
	local pet = target :: PetVisual
	if not pet.Model.Parent or not pet.Current then
		return -- not rendered (far away / hidden): skip the animation entirely
	end
	pet.Action = {
		Target = position,
		Park = nil,
		Start = os.clock(),
		DigStart = nil,
		Sand = if typeof(sand) == "number" then sand else 0,
		Burst = false,
	}
	pet.Park = nil
end

-- Public ------------------------------------------------------------------------------------------

export type VisualInfo = {
	Id: string,
	Golden: boolean,
	Slot: number,
	Model: Model,
	Vehicle: boolean,
	Digging: boolean,
	Parked: boolean,
}

function PetFollowController.GetVisuals(player: Player): { VisualInfo }
	local list: { VisualInfo } = {}
	local entry = entries[player]
	if entry then
		for _, pet in (entry :: Entry).Pets do
			table.insert(list, {
				Id = pet.Id,
				Golden = pet.Golden,
				Slot = pet.Slot,
				Model = pet.Model,
				Vehicle = pet.Vehicle,
				Digging = pet.Action ~= nil,
				Parked = pet.Park ~= nil,
			})
		end
	end
	return list
end

function PetFollowController.Init()
	for _, player in Players:GetPlayers() do
		task.spawn(track, player)
	end
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(function(player: Player)
		local entry = entries[player]
		if entry then
			clear(entry)
			entries[player] = nil
		end
	end)
	State.Changed("Pets"):Connect(function()
		if not localUsesAttribute then
			refresh(Players.LocalPlayer)
		end
	end)
	task.spawn(function()
		Remotes.Get("PetDug").OnClientEvent:Connect(onPetDug)
	end)
	RunService.RenderStepped:Connect(update)
end

return PetFollowController
