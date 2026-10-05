--!strict
--[[
	Shovels — held tools. Built in "tool space": origin at the bottom of the grip, shaft along
	+Y, blade plane = XY, the blade's "dig" side faces -Z.

	PrimaryPart = Part "Handle" (the grip cylinder). Every other part is welded to it with a
	WeldConstraint, Massless, CanCollide false, and still Anchored (the server unanchors).
	Handle attribute "GripOffset" (CFrame) is the value to assign to Tool.Grip: the shovel is held
	like a real shovel, shaft running diagonally down and forward from the hand, blade near the
	sand in front of the feet, the hand on the top grip (see the grip math below).

	Grip math (verified against the engine's tool weld):
	  When a Tool is equipped the engine makes Weld "RightGrip": Part0 = RightHand (R15) /
	  Right Arm (R6), C0 = RightGripAttachment.CFrame (R15: CFrame.new(0, -0.15, 0) *
	  Angles(-90deg, 0, 0); R6: CFrame.new(0, -1, 0) * the same rotation), Part1 = Handle,
	  C1 = Tool.Grip. Weld rule: Hand * C0 == Handle * Grip, so
	      Handle = (Hand * C0) * Grip:Inverse()          -- call Hand * C0 the grip frame G.
	  The default "toolnone" hold animation raises the forearm to point straight forward, i.e.
	  Hand = Rx(+90deg) relative to the character, so G = Rx(+90) * Rx(-90) = identity:
	  in the hold pose G's axes are the CHARACTER's axes (X right, Y up, Z back, -Z forward),
	  centred in the palm. (That is why the classic sword, Grip = (0, -1.5, 0), points straight
	  up.) Therefore:
	      Grip = (hand frame expressed in Handle space) = Handle:ToObjectSpace(T), where
	      T = CFrame.new(handPointInToolSpace) * HoldRotation:Inverse()
	  and HoldRotation is how the tool should be oriented relative to the character.
	  HoldRotation = Ry(+INWARD) * Rx(-(90deg + DOWN)): Rx(-(90+DOWN)) turns the shaft (+Y) to
	  (0, -sin DOWN, -cos DOWN) = down-and-forward, and the dig side (-Z) to down-and-back
	  (the direction the blade moves on a downward stab). Ry(+INWARD) yaws the shaft a little
	  towards the body centre so the blade sits in front of the feet, not beside the right leg.
	  Hand ~3.3 studs above the ground and ~1.8 in front of the root; with DOWN = 55deg the blade
	  tip (about 4.2 studs past the hand) ends ~0.3 studs above the sand, ~4 studs ahead.
	Swing: DigController tweens Tool.Grip = base * R. Since Handle = G * R:Inverse() * base^-1,
	R rotates the shovel about the HAND's axes: R = Rx(+a) stabs the blade down/back (deeper),
	R = Rx(-a) lifts it up/forward.
]]

local Types = require(script.Parent.Parent.Types)
local Config = require(script.Parent.Parent.Config)
local Build = require(script.Parent.Build)

local Shovels = {}

local GRIP_Y = 0.6 -- hand position along the grip (top of the tool; the knob pokes out above)
local HOLD_DOWN = math.rad(55) -- shaft angle below horizontal
local HOLD_INWARD = math.rad(10) -- yaw towards the body centre
local HOLD_ROTATION = CFrame.Angles(0, HOLD_INWARD, 0) * CFrame.Angles(-(math.pi / 2 + HOLD_DOWN), 0, 0)
local SHAFT_TOP = 3.0
local HB = 3.25 -- head base (top of collar)

local FALLBACK: Types.ShovelLook = {
	HeadColor = Color3.fromRGB(255, 140, 40),
	HandleColor = Color3.fromRGB(255, 220, 80),
	HeadShape = "Spade",
	Material = Enum.Material.SmoothPlastic,
	Glow = false,
}

local V = Vector3.new
local X = Vector3.xAxis

type HeadBuilder = (m: Model, c: Color3, mat: Enum.Material, look: Types.ShovelLook) -> BasePart

local function accent(look: Types.ShovelLook): (Color3, Enum.Material)
	if look.Glow then
		-- Saturated accent (not lightened): pale Neon blooms to white. Build clamps it further.
		return Build.lighten(look.HeadColor, 0.1), Enum.Material.Neon
	end
	return Build.darken(look.HeadColor, 0.25), look.Material
end

local heads: { [string]: HeadBuilder } = {}

heads.Scoop = function(m, c, mat, look)
	Build.part(m, "Neck", V(0.42, 0.45, 0.22), CFrame.new(0, HB, 0), c, mat)
	local blade = Build.part(m, "Blade", V(1.3, 1.25, 0.14), CFrame.new(0, HB + 0.72, 0), c, mat)
	Build.ellipsoid(m, "BladeTip", V(1.3, 0.9, 0.14), CFrame.new(0, HB + 1.34, 0), c, mat)
	local rim = Build.darken(c, 0.12)
	for side = -1, 1, 2 do
		Build.part(
			m,
			"Rim",
			V(0.14, 1.35, 0.34),
			CFrame.new(side * 0.6, HB + 0.78, 0.12) * CFrame.Angles(0, 0, side * 0.05),
			rim,
			mat
		)
	end
	Build.part(m, "BackRim", V(1.3, 0.14, 0.34), CFrame.new(0, HB + 0.1, 0.12), rim, mat)
	if look.Glow then
		local ac, am = accent(look)
		Build.part(m, "GlowStrip", V(0.9, 0.12, 0.17), CFrame.new(0, HB + 0.9, 0), ac, am)
	end
	return blade
end

heads.Trowel = function(m, c, mat, look)
	Build.cyl(m, "Neck", 0.5, 0.26, CFrame.new(0, HB, 0), c, mat)
	local blade = Build.part(m, "Blade", V(0.95, 0.8, 0.1), CFrame.new(0, HB + 0.6, 0), c, mat)
	Build.tri(m, "BladeTip", CFrame.new(0, HB + 1.45, 0), 0.95, 0.9, 0.1, c, mat)
	local ac, am = accent(look)
	Build.part(m, "Ridge", V(0.14, 1.45, 0.16), CFrame.new(0, HB + 0.85, 0), ac, am)
	return blade
end

heads.Spade = function(m, c, mat, look)
	Build.cyl(m, "Socket", 0.7, 0.36, CFrame.new(0, HB + 0.2, 0.02), c, mat)
	local blade = Build.part(m, "Blade", V(1.2, 1.2, 0.14), CFrame.new(0, HB + 0.7, 0), c, mat)
	Build.tri(m, "BladeTip", CFrame.new(0, HB + 1.52, 0), 1.2, 0.45, 0.14, c, mat)
	local ac, am = accent(look)
	Build.part(m, "Tread", V(1.28, 0.14, 0.32), CFrame.new(0, HB + 0.13, 0.04), ac, am)
	if look.Glow then
		Build.part(m, "GlowStrip", V(0.14, 1.0, 0.17), CFrame.new(0, HB + 0.85, 0), ac, am)
	end
	return blade
end

heads.Pick = function(m, c, mat, look)
	Build.cyl(m, "ShaftTop", 0.4, 0.3, CFrame.new(0, HB + 0.1, 0), look.HandleColor)
	local socket = Build.part(m, "Socket", V(0.5, 0.55, 0.6), CFrame.new(0, HB + 0.35, 0), c, mat)
	local mid = V(0, HB + 0.35, 0)
	-- Pointed arm towards -Z (down when held), chisel arm towards +Z; both curve back to the grip.
	local frontElbow = V(0, HB + 0.25, -0.9)
	local backElbow = V(0, HB + 0.25, 0.8)
	Build.beam(m, "Arm", mid, frontElbow, 0.34, 0.34, c, mat, X)
	Build.beam(m, "Arm", mid, backElbow, 0.34, 0.34, c, mat, X)
	Build.spike(m, "Point", frontElbow, V(0, HB - 0.15, -1.55), 0.38, c, mat)
	Build.triPts(m, "Chisel", backElbow, V(0, HB, 1.3), X, 0.5, 0.18, c, mat)
	local ac, am = accent(look)
	Build.part(m, "Band", V(0.56, 0.18, 0.66), CFrame.new(0, HB + 0.35, 0), ac, am)
	return socket
end

heads.Claw = function(m, c, mat, look)
	local palm = Build.ellipsoid(m, "Palm", V(1.05, 0.6, 0.6), CFrame.new(0, HB + 0.2, 0), c, mat)
	local ac, am = accent(look)
	for i = -1, 1 do
		local x = i * 0.36
		local len = if i == 0 then 1.15 else 0.95
		local knuckle = V(x, HB + 0.25, 0)
		local bend = V(x * 1.1, HB + len, -0.12)
		Build.cylBetween(m, "Finger", knuckle, bend, 0.26, c, mat)
		Build.triPts(m, "Talon", bend - V(0, 0.05, 0), V(x * 1.15, HB + len + 0.55, -0.6), X, 0.3, 0.2, ac, am)
	end
	return palm
end

heads.Trident = function(m, c, mat, look)
	Build.cyl(m, "Socket", 0.5, 0.3, CFrame.new(0, HB + 0.05, 0), c, mat)
	local bar = Build.beam(m, "Crossbar", V(-0.68, HB + 0.35, 0), V(0.68, HB + 0.35, 0), 0.24, 0.22, c, mat)
	local ac, am = accent(look)
	Build.cylBetween(m, "Tine", V(0, HB + 0.2, 0), V(0, HB + 1.35, 0), 0.2, c, mat)
	Build.tri(m, "Barb", CFrame.new(0, HB + 1.55, 0), 0.46, 0.5, 0.14, ac, am)
	for side = -1, 1, 2 do
		local x = side * 0.6
		Build.cylBetween(m, "Tine", V(x, HB + 0.3, 0), V(x * 1.05, HB + 1.05, 0), 0.18, c, mat)
		Build.triPts(m, "Barb", V(x * 1.05, HB + 1.0, 0), V(x * 1.1, HB + 1.42, 0), X, 0.36, 0.12, ac, am)
	end
	return bar
end

heads.Drill = function(m, c, mat, look)
	local housing = Build.cyl(m, "Housing", 0.5, 0.9, CFrame.new(0, HB + 0.2, 0), look.HandleColor)
	local ac, am = accent(look)
	local tiers = { 1.0, 0.8, 0.6, 0.4 }
	for i, d in tiers do
		local col = if i % 2 == 1 then c else Build.lighten(c, 0.2)
		Build.cyl(m, "Bit", 0.36, d, CFrame.new(0, HB + 0.45 + i * 0.33, 0) * CFrame.Angles(0, i * 0.4, 0), col, mat)
	end
	Build.spike(m, "Tip", V(0, HB + 1.95, 0), V(0, HB + 2.4, 0), 0.32, ac, am)
	Build.cyl(m, "Band", 0.12, 0.94, CFrame.new(0, HB + 0.35, 0), ac, am)
	return housing
end

local function build(id: string, look: Types.ShovelLook): Model
	local m = Build.model(id)
	local hc = look.HandleColor
	local trim = Build.darken(hc, 0.25)

	local handle = Build.cyl(m, "Handle", 1.1, 0.42, CFrame.new(0, 0.55, 0), hc)
	Build.cyl(m, "GripCap", 0.2, 0.52, CFrame.new(0, 0.02, 0), trim)
	Build.cyl(m, "GripRing", 0.14, 0.48, CFrame.new(0, 1.1, 0), trim)
	Build.cyl(m, "Shaft", SHAFT_TOP - 1.1, 0.3, CFrame.new(0, (SHAFT_TOP + 1.1) / 2, 0), hc)

	local headColor = look.HeadColor
	local mat = look.Material
	local ac, am = accent(look)
	Build.cyl(m, "Collar", 0.3, 0.44, CFrame.new(0, SHAFT_TOP + 0.12, 0), ac, am)

	local builder = heads[look.HeadShape] or heads.Spade
	local main = builder(m, headColor, mat, look)
	if look.Glow then
		Build.glow(main, headColor, 1.2, 8)
	end

	handle.CanTouch = true
	handle:SetAttribute("GripOffset", handle.CFrame:ToObjectSpace(CFrame.new(0, GRIP_Y, 0) * HOLD_ROTATION:Inverse()))
	m.PrimaryPart = handle
	Build.massless(m, handle)
	Build.weldAll(m, handle)
	return m
end

function Shovels.Build(shovelId: string): Model
	local def = Config.GetShovel(shovelId)
	return build(shovelId, if def then def.Look else FALLBACK)
end

function Shovels.FromLook(name: string, look: Types.ShovelLook): Model
	return build(name, look)
end

return Shovels
