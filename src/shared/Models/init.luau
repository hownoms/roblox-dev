--!strict
--[[
	Models — procedural low-poly model builders (no mesh / texture asset ids).
	Safe to require on server and client (no services). Every call returns a FRESH, unparented
	Model with all parts Anchored and a PrimaryPart. Unknown ids return a pleasant fallback.

	Conventions (see each module header for details):
	- Front is -Z, up is +Y.
	- Shovel: PrimaryPart = Part "Handle" (grip). Other parts WeldConstraint'ed to Handle and
	  Massless. Handle attribute "GripOffset" (CFrame) -> assign to Tool.Grip.
	- Pet / Egg / Prop: PrimaryPart = invisible "Root" at the bottom-centre.
	- Treasure: PrimaryPart = invisible "Root" at the visual centre (for ViewportFrames).
	- Backpack: PrimaryPart = invisible "Root" at the centre of the face touching the torso's
	  back; pack extends to +Z. Weld at torso.CFrame * CFrame.new(0, 0, torso.Size.Z / 2)
	  (Root attribute "AttachOffset" = CFrame.new(0, 0, 0.5)). All parts Massless.
	- Pets, eggs, treasures, backpacks are welded to Root too (inert while anchored).
]]

local Shovels = require(script.Shovels)
local Pets = require(script.Pets)
local Eggs = require(script.Eggs)
local Treasures = require(script.Treasures)
local Backpacks = require(script.Backpacks)
local Props = require(script.Props)
local Shades = require(script.Shades)
local Consumables = require(script.Consumables)
local Diggers = require(script.Diggers)
local Rides = require(script.Rides)

local Models = {}

function Models.Shovel(shovelId: string): Model
	return Shovels.Build(shovelId)
end

function Models.Pet(petId: string): Model
	return Pets.Build(petId)
end

function Models.Egg(eggId: string): Model
	return Eggs.Build(eggId)
end

function Models.Treasure(treasureId: string): Model
	return Treasures.Build(treasureId)
end

-- v3 discovery: a treasure with its size + material variant (Config.Discovery) applied.
function Models.Find(treasureId: string, size: string?, material: string?): Model
	return Treasures.ApplyVariant(Treasures.Build(treasureId), size, material)
end

function Models.Backpack(backpackId: string): Model
	return Backpacks.Build(backpackId)
end

-- `variant` (optional, default 1) deterministically varies colours / shape.
function Models.Prop(name: string, variant: number?): Model
	return Props.Build(name, variant)
end

function Models.ListProps(): { string }
	return Props.List()
end

-- v2 (Survival agent: Shade, Consumable). Models.Digger(id): a vehicle pet id (or vehicle Kind)
-- at full vehicle size (scale 1); Models.Pet(id) draws the same vehicle at pet scale.
function Models.Shade(shadeId: string): Model
	return Shades.Build(shadeId)
end

function Models.Consumable(consumableId: string): Model
	return Consumables.Build(consumableId)
end

function Models.Digger(id: string, scale: number?): Model
	return Diggers.Build(id, scale)
end

-- v2.1 (Ride agent): full-size ride-on vehicle for a rideable pet (unanchor-ready, see Rides.luau)
function Models.RideVehicle(petId: string): Model
	return Rides.Build(petId)
end

return Models
