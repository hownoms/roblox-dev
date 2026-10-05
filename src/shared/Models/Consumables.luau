--!strict
--[[
	Consumables — drinks & snacks (Config.Consumables), ~1.5 studs tall, chunky cartoon style.
	PrimaryPart = invisible "Root" at the VISUAL CENTRE (like treasures) so ViewportFrames and
	hand-held / pop-up effects frame them without offsets. Front is -Z. Everything anchored,
	nothing collides.
]]

local Types = require(script.Parent.Parent.Types)
local Config = require(script.Parent.Parent.Config)
local Build = require(script.Parent.Build)

local ConsumableModels = {}

local V = Vector3.new
local CF = CFrame.new
local rgb = Color3.fromRGB
local PI = math.pi
local M = Enum.Material

local WHITE = rgb(255, 255, 255)
local RIND = rgb(60, 160, 70)
local RIND_DARK = rgb(35, 110, 50)
local SEED = rgb(35, 25, 30)

type Builder = (m: Model, color: Color3) -> ()

local builders: { [string]: Builder } = {}

-- All builders work in a box roughly 1.0 x 1.5 x 1.0 centred on the origin.

local function straw(m: Model, from: Vector3, to: Vector3, color: Color3)
	local n = 4
	for i = 0, n - 1 do
		local a = from:Lerp(to, i / n)
		local b = from:Lerp(to, (i + 1) / n)
		Build.cylBetween(m, "Straw", a, b, 0.09, if i % 2 == 0 then WHITE else color)
	end
end

builders.Bottle = function(m, color)
	Build.cyl(m, "Body", 1.0, 0.75, CF(0, -0.2, 0), color, M.Glass)
	Build.cyl(m, "Water", 0.8, 0.62, CF(0, -0.28, 0), Build.lighten(color, 0.3))
	Build.cyl(m, "Label", 0.34, 0.77, CF(0, -0.2, 0), WHITE)
	Build.label(Build.part(m, "LabelFace", V(0.4, 0.3, 0.02), CF(0, -0.2, -0.39), WHITE), Enum.NormalId.Front, "💧")
	Build.cyl(m, "Shoulder", 0.25, 0.55, CF(0, 0.42, 0), color, M.Glass)
	Build.cyl(m, "Neck", 0.2, 0.3, CF(0, 0.6, 0), color, M.Glass)
	Build.cyl(m, "Cap", 0.16, 0.36, CF(0, 0.74, 0), rgb(40, 120, 255))
end

builders.Cup = function(m, color)
	Build.cyl(m, "Cup", 1.1, 0.8, CF(0, -0.2, 0), WHITE)
	Build.cyl(m, "Band", 0.3, 0.82, CF(0, -0.2, 0), color)
	Build.cyl(m, "Drink", 0.06, 0.7, CF(0, 0.33, 0), color)
	-- lemon wheel on the rim
	local wheel = CF(0.32, 0.38, -0.2) * CFrame.Angles(PI / 2, 0, 0.3)
	Build.cyl(m, "Lemon", 0.1, 0.5, wheel, rgb(255, 220, 40))
	Build.cyl(m, "LemonPith", 0.11, 0.38, wheel, rgb(255, 250, 200))
	straw(m, V(-0.12, 0.0, 0.05), V(-0.3, 0.78, 0.15), rgb(255, 90, 120))
end

builders.Coconut = function(m, color)
	Build.ball(m, "Shell", 1.1, CF(0, -0.15, 0), color)
	Build.cyl(m, "Cut", 0.06, 0.62, CF(0, 0.37, 0), rgb(250, 245, 230))
	Build.cyl(m, "Milk", 0.07, 0.5, CF(0, 0.38, 0), WHITE)
	straw(m, V(0.05, 0.2, 0), V(0.3, 0.75, 0.05), rgb(60, 200, 255))
	-- tiny cocktail umbrella
	Build.cylBetween(m, "UmbrellaStick", V(-0.15, 0.3, 0.05), V(-0.35, 0.78, 0.1), 0.05, rgb(230, 200, 140))
	Build.spike(m, "Umbrella", V(-0.37, 0.72, 0.1), V(-0.4, 0.92, 0.11), 0.55, rgb(255, 110, 170))
	-- coconut "eyes"
	for side = -1, 1, 2 do
		Build.ball(m, "Dot", 0.14, CF(side * 0.16, 0.05, -0.5), Build.darken(color, 0.4))
	end
end

builders.Popsicle = function(m, color)
	local top = Build.lighten(color, 0.25)
	Build.part(m, "Pop", V(0.65, 0.85, 0.3), CF(0, 0.05, 0), color)
	Build.cyl(m, "PopTop", 0.3, 0.65, CF(0, 0.475, 0) * CFrame.Angles(PI / 2, 0, 0), color)
	Build.part(m, "Stripe", V(0.67, 0.18, 0.32), CF(0, 0.2, 0), top)
	Build.part(m, "Stripe", V(0.67, 0.18, 0.32), CF(0, -0.15, 0), rgb(255, 230, 90))
	Build.part(m, "Stick", V(0.16, 0.55, 0.08), CF(0, -0.6, 0), rgb(230, 200, 140), M.Wood)
	Build.ball(m, "Drip", 0.14, CF(0.2, -0.38, -0.1), color)
end

builders.ShavedIce = function(m, color)
	-- paper cone (point down)
	Build.spike(m, "Cone", V(0, 0.05, 0), V(0, -0.75, 0), 0.85, WHITE)
	Build.cyl(m, "Rim", 0.12, 0.8, CF(0, 0.08, 0), rgb(255, 120, 160))
	-- rainbow ice dome
	Build.ball(m, "Ice", 0.9, CF(0, 0.38, 0), WHITE, M.Ice)
	Build.ball(m, "Syrup", 0.62, CF(-0.18, 0.5, -0.12), color)
	Build.ball(m, "Syrup", 0.58, CF(0.2, 0.48, 0.1), rgb(255, 90, 140))
	Build.ball(m, "Syrup", 0.5, CF(0.02, 0.66, 0.12), rgb(255, 230, 80))
	Build.cylBetween(m, "Spoon", V(0.15, 0.4, -0.2), V(0.35, 0.9, -0.3), 0.08, rgb(255, 140, 40))
end

builders.Slice = function(m, color)
	local t = 0.45
	-- triangle wedge, apex down
	local flesh = CF(0, 0.05, 0) * CFrame.Angles(0, 0, PI)
	Build.tri(m, "Flesh", flesh, 1.5, 1.2, t, color)
	Build.part(m, "Pith", V(1.55, 0.1, t + 0.02), CF(0, 0.66, 0), rgb(240, 250, 220))
	Build.part(m, "Rind", V(1.6, 0.18, t + 0.04), CF(0, 0.78, 0), RIND)
	for _, p in { V(-0.35, 0.35, 0), V(0.35, 0.35, 0), V(0, 0.1, 0), V(-0.15, -0.2, 0), V(0.15, -0.2, 0) } do
		Build.ellipsoid(m, "Seed", V(0.09, 0.15, t + 0.06), CF(p), SEED)
	end
end

builders.Melon = function(m, color)
	local size = V(1.4, 1.2, 1.6)
	Build.ellipsoid(m, "Melon", size, CF(0, -0.05, 0), color)
	for k = 0, 4 do
		local a = k / 5 * PI
		Build.ellipsoid(
			m,
			"Stripe",
			V(0.16, size.Y * 1.02, size.Z * 1.02),
			CF(0, -0.05, 0) * CFrame.Angles(0, a, 0),
			RIND_DARK
		)
	end
	Build.cylBetween(m, "Stem", V(0, 0.5, 0), V(0.08, 0.72, 0.02), 0.12, rgb(120, 85, 50))
	Build.triPts(m, "Leaf", V(0.05, 0.62, 0), V(0.42, 0.7, -0.1), V(0, 0, 1), 0.3, 0.05, rgb(90, 200, 100))
end

-- Public --------------------------------------------------------------------------------------------

function ConsumableModels.Build(id: string): Model
	local def: Types.ConsumableDef? = Config.GetConsumable(id)
	local m = Build.model(id)
	Build.root(m, CFrame.identity, V(0.2, 0.2, 0.2))
	local look: { [string]: any } = if def then def.Look else {}
	local color: Color3 = if typeof(look.Color) == "Color3" then look.Color else rgb(255, 235, 90)
	local style = if type(look.Style) == "string" then look.Style else "Cup"
	local builder = builders[style] or builders.Cup
	builder(m, color)
	m:SetAttribute("ConsumableId", id)
	return m
end

return ConsumableModels
