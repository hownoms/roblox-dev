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

-- v2 (Survival agent: Shade, Consumable; Diggers agent: Digger)
function Models.Shade(shadeId: string): Model
	return Shades.Build(shadeId)
end

function Models.Consumable(consumableId: string): Model
	return Consumables.Build(consumableId)
end

function Models.Digger(diggerId: string): Model
	return Diggers.Build(diggerId)
end

return Models
