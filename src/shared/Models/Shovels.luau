--!strict
--[[
	Shovels — held tools. Built in "tool space": origin at the top end of the shaft (the end
	away from the head), shaft along +Y towards the head, blade plane = XY. The blade's cupped
	(scooping) face is +Z, its "dig" edge/back is -Z.

	Two sizes (Look.Size, Types.ShovelSize):
	  "Hand"  small one-handed hand spade / trowel (~1.9 studs): short grip, scaled-down head.
	  "Full"  (default) full-size shovel held with BOTH hands: D-grip (Spade/Scoop/Trowel heads)
	          or T-grip (Pick/Claw/Trident/Drill) on top, a foam sleeve on the shaft for the
	          left hand, head at the far end.

	PrimaryPart = Part "Handle" (the top grip section). Every other part is welded to it with a
	WeldConstraint, Massless, CanCollide false, and still Anchored (the server unanchors).

	Handle attributes (all vectors / points in HANDLE space):
	  GripOffset  CFrame   -> Tool.Grip (the right palm frame, see below)
	  TwoHanded   boolean  full-size tool (ShopService copies it onto the Tool)
	  ShaftAxis   Vector3  tool +Y (top grip -> head)
	  CupAxis     Vector3  tool +Z (the blade's cupped face)
	  LeftHand    Vector3  where the left palm grips the shaft (two-handed tools only)
	  BladePoint  Vector3  centre of the blade's cupped face (the client rides a sand clump here)
	The client ShovelPoseController reads these to pose both arms and play the scoop.

	Grip math (verified against the engine's tool weld):
	  When a Tool is equipped the engine makes Weld "RightGrip": Part0 = RightHand (R15) /
	  Right Arm (R6), C0 = RightGripAttachment.CFrame (R15: CFrame.new(0, -0.15, 0) *
	  Angles(-90deg, 0, 0); R6: CFrame.new(0, -1, 0) * the same rotation), Part1 = Handle,
	  C1 = Tool.Grip. Weld rule: Hand * C0 == Handle * Grip, so
	      Handle = (Hand * C0) * Grip:Inverse()          -- call Hand * C0 the palm frame G.
	  G's axes, read on the R15 hand: G.Y = hand -Z (the fist axis, out of the thumb side),
	  G.Z = hand +Y (from the palm back towards the wrist / forearm), G.X = hand +X (the back of
	  the right hand). In the default "toolnone" hold animation (forearm pointing forward)
	  G's axes are the CHARACTER's axes (X right, Y up, Z back). Grip = G expressed in Handle
	  space = Handle:ToObjectSpace(T), with T = the palm frame written in tool space:
	  * Hand tools: T = CFrame.new(0, HAND_PALM_Y, 0) * HoldRotation:Inverse(), HoldRotation =
	    Ry(+INWARD) * Rx(-(90deg + DOWN)): in the plain hold pose the shaft runs down and forward
	    from the fist (DOWN = 55deg below horizontal, yawed INWARD 10deg), cup face up/forward.
	    The pose controller only takes over during a scoop, so this is also the idle look.
	  * Full tools: the right palm wraps the grip crossbar: fist axis G.Y = tool -X (along the
	    crossbar), forearm G.Z = tool -Y (straight in line with the shaft, so the wrist stays
	    straight), back of the hand G.X = tool +Z (overhand grip, knuckles on the cup side).
	    T = CFrame.fromMatrix((0, palmY, 0), +Z, -X, -Y). Without the pose controller (R6
	    avatars) the shovel simply points forward from the fist.
]]

local Types = require(script.Parent.Parent.Types)
local Config = require(script.Parent.Parent.Config)
local Build = require(script.Parent.Build)

local Shovels = {}

-- Hand tools ------------------------------------------------------------------------------------
local HAND_PALM_Y = 0.38 -- palm on the middle of the short grip
local HAND_GRIP_LEN = 0.75
local HAND_HB = 1.05 -- head base
local HAND_HEAD_SCALE = 0.55 -- head builders are full size; hand tools shrink them
local HOLD_DOWN = math.rad(55) -- shaft angle below horizontal in the plain hold pose
local HOLD_INWARD = math.rad(10) -- yaw towards the body centre
local HOLD_ROTATION = CFrame.Angles(0, HOLD_INWARD, 0) * CFrame.Angles(-(math.pi / 2 + HOLD_DOWN), 0, 0)

-- Full (two-handed) tools -----------------------------------------------------------------------
local FULL_HANDLE_LEN = 1.0 -- Handle part: the shaft's top section
local FULL_SHAFT_TOP = 2.15
local FULL_HB = 2.4 -- head base (top of collar)
local FULL_LEFT_Y = 0.75 -- left hand on the foam sleeve, ~1.2 studs below the right palm
local D_GRIP_Y = -0.42 -- D-grip crossbar (right palm) above the shaft top
local T_GRIP_Y = -0.16 -- T-grip crossbar sits right on the shaft top
local D_GRIP_SHAPES = { Spade = true, Scoop = true, Trowel = true }

local FALLBACK: Types.ShovelLook = {
	HeadColor = Color3.fromRGB(255, 140, 40),
	HandleColor = Color3.fromRGB(255, 220, 80),
	HeadShape = "Spade",
	Material = Enum.Material.SmoothPlastic,
	Glow = false,
}

local V = Vector3.new
local X = Vector3.xAxis

type HeadBuilder = (m: Model, c: Color3, mat: Enum.Material, look: Types.ShovelLook, hb: number) -> BasePart

local function accent(look: Types.ShovelLook): (Color3, Enum.Material)
	if look.Glow then
		-- Saturated accent (not lightened): pale Neon blooms to white. Build clamps it further.
		return Build.lighten(look.HeadColor, 0.1), Enum.Material.Neon
	end
	return Build.darken(look.HeadColor, 0.25), look.Material
end

local heads: { [string]: HeadBuilder } = {}

heads.Scoop = function(m, c, mat, look, hb)
	Build.part(m, "Neck", V(0.42, 0.45, 0.22), CFrame.new(0, hb, 0), c, mat)
	local blade = Build.part(m, "Blade", V(1.3, 1.25, 0.14), CFrame.new(0, hb + 0.72, 0), c, mat)
	Build.ellipsoid(m, "BladeTip", V(1.3, 0.9, 0.14), CFrame.new(0, hb + 1.34, 0), c, mat)
	local rim = Build.darken(c, 0.12)
	for side = -1, 1, 2 do
		Build.part(
			m,
			"Rim",
			V(0.14, 1.35, 0.34),
			CFrame.new(side * 0.6, hb + 0.78, 0.12) * CFrame.Angles(0, 0, side * 0.05),
			rim,
			mat
		)
	end
	Build.part(m, "BackRim", V(1.3, 0.14, 0.34), CFrame.new(0, hb + 0.1, 0.12), rim, mat)
	if look.Glow then
		local ac, am = accent(look)
		Build.part(m, "GlowStrip", V(0.9, 0.12, 0.17), CFrame.new(0, hb + 0.9, 0), ac, am)
	end
	return blade
end

heads.Trowel = function(m, c, mat, look, hb)
	Build.cyl(m, "Neck", 0.5, 0.26, CFrame.new(0, hb, 0), c, mat)
	local blade = Build.part(m, "Blade", V(0.95, 0.8, 0.1), CFrame.new(0, hb + 0.6, 0), c, mat)
	Build.tri(m, "BladeTip", CFrame.new(0, hb + 1.45, 0), 0.95, 0.9, 0.1, c, mat)
	local ac, am = accent(look)
	Build.part(m, "Ridge", V(0.14, 1.45, 0.16), CFrame.new(0, hb + 0.85, 0), ac, am)
	return blade
end

heads.Spade = function(m, c, mat, look, hb)
	Build.cyl(m, "Socket", 0.7, 0.36, CFrame.new(0, hb + 0.2, 0.02), c, mat)
	local blade = Build.part(m, "Blade", V(1.2, 1.2, 0.14), CFrame.new(0, hb + 0.7, 0), c, mat)
	Build.tri(m, "BladeTip", CFrame.new(0, hb + 1.52, 0), 1.2, 0.45, 0.14, c, mat)
	local ac, am = accent(look)
	Build.part(m, "Tread", V(1.28, 0.14, 0.32), CFrame.new(0, hb + 0.13, 0.04), ac, am)
	if look.Glow then
		Build.part(m, "GlowStrip", V(0.14, 1.0, 0.17), CFrame.new(0, hb + 0.85, 0), ac, am)
	end
	return blade
end

heads.Pick = function(m, c, mat, look, hb)
	Build.cyl(m, "ShaftTop", 0.4, 0.3, CFrame.new(0, hb + 0.1, 0), look.HandleColor)
	local socket = Build.part(m, "Socket", V(0.5, 0.55, 0.6), CFrame.new(0, hb + 0.35, 0), c, mat)
	local mid = V(0, hb + 0.35, 0)
	-- Pointed arm towards -Z (down when held), chisel arm towards +Z; both curve back to the grip.
	local frontElbow = V(0, hb + 0.25, -0.9)
	local backElbow = V(0, hb + 0.25, 0.8)
	Build.beam(m, "Arm", mid, frontElbow, 0.34, 0.34, c, mat, X)
	Build.beam(m, "Arm", mid, backElbow, 0.34, 0.34, c, mat, X)
	Build.spike(m, "Point", frontElbow, V(0, hb - 0.15, -1.55), 0.38, c, mat)
	Build.triPts(m, "Chisel", backElbow, V(0, hb, 1.3), X, 0.5, 0.18, c, mat)
	local ac, am = accent(look)
	Build.part(m, "Band", V(0.56, 0.18, 0.66), CFrame.new(0, hb + 0.35, 0), ac, am)
	return socket
end

heads.Claw = function(m, c, mat, look, hb)
	local palm = Build.ellipsoid(m, "Palm", V(1.05, 0.6, 0.6), CFrame.new(0, hb + 0.2, 0), c, mat)
	local ac, am = accent(look)
	for i = -1, 1 do
		local x = i * 0.36
		local len = if i == 0 then 1.15 else 0.95
		local knuckle = V(x, hb + 0.25, 0)
		local bend = V(x * 1.1, hb + len, -0.12)
		Build.cylBetween(m, "Finger", knuckle, bend, 0.26, c, mat)
		Build.triPts(m, "Talon", bend - V(0, 0.05, 0), V(x * 1.15, hb + len + 0.55, -0.6), X, 0.3, 0.2, ac, am)
	end
	return palm
end

heads.Trident = function(m, c, mat, look, hb)
	Build.cyl(m, "Socket", 0.5, 0.3, CFrame.new(0, hb + 0.05, 0), c, mat)
	local bar = Build.beam(m, "Crossbar", V(-0.68, hb + 0.35, 0), V(0.68, hb + 0.35, 0), 0.24, 0.22, c, mat)
	local ac, am = accent(look)
	Build.cylBetween(m, "Tine", V(0, hb + 0.2, 0), V(0, hb + 1.35, 0), 0.2, c, mat)
	Build.tri(m, "Barb", CFrame.new(0, hb + 1.55, 0), 0.46, 0.5, 0.14, ac, am)
	for side = -1, 1, 2 do
		local x = side * 0.6
		Build.cylBetween(m, "Tine", V(x, hb + 0.3, 0), V(x * 1.05, hb + 1.05, 0), 0.18, c, mat)
		Build.triPts(m, "Barb", V(x * 1.05, hb + 1.0, 0), V(x * 1.1, hb + 1.42, 0), X, 0.36, 0.12, ac, am)
	end
	return bar
end

heads.Drill = function(m, c, mat, look, hb)
	local housing = Build.cyl(m, "Housing", 0.8, 0.9, CFrame.new(0, hb + 0.35, 0), look.HandleColor)
	local ac, am = accent(look)
	local tiers = { 1.0, 0.8, 0.6, 0.4 }
	for i, d in tiers do
		local col = if i % 2 == 1 then c else Build.lighten(c, 0.2)
		Build.cyl(m, "Bit", 0.36, d, CFrame.new(0, hb + 0.45 + i * 0.33, 0) * CFrame.Angles(0, i * 0.4, 0), col, mat)
	end
	Build.spike(m, "Tip", V(0, hb + 1.95, 0), V(0, hb + 2.4, 0), 0.32, ac, am)
	Build.cyl(m, "Band", 0.12, 0.94, CFrame.new(0, hb + 0.35, 0), ac, am)
	return housing
end

-- Builds the head at base height `hb`, scaled by `s` about the head base. Returns the main part.
local function addHead(m: Model, look: Types.ShovelLook, hb: number, s: number): BasePart
	local builder = heads[look.HeadShape] or heads.Spade
	local temp = Build.model("Head")
	local main = builder(temp, look.HeadColor, look.Material, look, hb)
	Build.scale(temp, CFrame.new(0, hb, 0), s)
	for _, child in temp:GetChildren() do
		child.Parent = m
	end
	temp:Destroy()
	if look.Glow then
		Build.glow(main, look.HeadColor, 1.2 * s, 8 * s)
	end
	return main
end

-- Shared finish: attributes, PrimaryPart, massless, welds.
local function finish(
	m: Model,
	handle: BasePart,
	palm: CFrame,
	twoHanded: boolean,
	leftHand: Vector3?,
	bladePoint: Vector3
): Model
	local hcf = handle.CFrame
	handle.CanTouch = true
	handle:SetAttribute("GripOffset", hcf:ToObjectSpace(palm))
	handle:SetAttribute("TwoHanded", twoHanded)
	handle:SetAttribute("ShaftAxis", hcf:VectorToObjectSpace(Vector3.yAxis))
	handle:SetAttribute("CupAxis", hcf:VectorToObjectSpace(Vector3.zAxis))
	if leftHand then
		handle:SetAttribute("LeftHand", hcf:PointToObjectSpace(leftHand))
	end
	handle:SetAttribute("BladePoint", hcf:PointToObjectSpace(bladePoint))
	m.PrimaryPart = handle
	Build.massless(m, handle)
	Build.weldAll(m, handle)
	return m
end

local function buildHand(id: string, look: Types.ShovelLook): Model
	local m = Build.model(id)
	local hc = look.HandleColor
	local trim = Build.darken(hc, 0.25)
	local handle = Build.cyl(m, "Handle", HAND_GRIP_LEN, 0.34, CFrame.new(0, HAND_GRIP_LEN / 2, 0), hc)
	Build.ellipsoid(m, "GripKnob", V(0.42, 0.24, 0.42), CFrame.new(0, 0, 0), trim)
	Build.cyl(m, "GripRing", 0.1, 0.38, CFrame.new(0, HAND_GRIP_LEN, 0), trim)
	Build.cyl(m, "Shaft", HAND_HB - HAND_GRIP_LEN, 0.22, CFrame.new(0, (HAND_HB + HAND_GRIP_LEN) / 2, 0), hc)
	local ac, am = accent(look)
	Build.cyl(m, "Collar", 0.16, 0.28, CFrame.new(0, HAND_HB - 0.06, 0), ac, am)
	addHead(m, look, HAND_HB, HAND_HEAD_SCALE)
	local palm = CFrame.new(0, HAND_PALM_Y, 0) * HOLD_ROTATION:Inverse()
	return finish(m, handle, palm, false, nil, V(0, HAND_HB + 0.75 * HAND_HEAD_SCALE, 0.1))
end

local function buildFull(id: string, look: Types.ShovelLook): Model
	local m = Build.model(id)
	local hc = look.HandleColor
	local trim = Build.darken(hc, 0.25)
	local ac, am = accent(look)

	local handle = Build.cyl(m, "Handle", FULL_HANDLE_LEN, 0.3, CFrame.new(0, FULL_HANDLE_LEN / 2, 0), hc)
	Build.cyl(
		m,
		"Shaft",
		FULL_SHAFT_TOP - FULL_HANDLE_LEN,
		0.27,
		CFrame.new(0, (FULL_SHAFT_TOP + FULL_HANDLE_LEN) / 2, 0),
		hc
	)
	-- Foam sleeve where the left hand grips.
	Build.cyl(m, "LeftGrip", 0.55, 0.36, CFrame.new(0, FULL_LEFT_Y, 0), trim)
	Build.cyl(m, "Collar", 0.3, 0.4, CFrame.new(0, FULL_SHAFT_TOP + 0.12, 0), ac, am)

	-- Top grip: crossbar along X (the right fist wraps it).
	local palmY = T_GRIP_Y
	if D_GRIP_SHAPES[look.HeadShape] then
		palmY = D_GRIP_Y
		for side = -1, 1, 2 do
			Build.beam(
				m,
				"GripCheek",
				V(side * 0.36, palmY, 0),
				V(side * 0.08, 0.08, 0),
				0.14,
				0.16,
				hc,
				nil,
				Vector3.zAxis
			)
		end
		Build.cyl(m, "GripCap", 0.12, 0.34, CFrame.new(0, 0.02, 0), trim)
	else
		for side = -1, 1, 2 do
			Build.ellipsoid(m, "GripKnob", V(0.26, 0.26, 0.26), CFrame.new(side * 0.47, palmY, 0), trim)
		end
	end
	Build.cylBetween(m, "GripBar", V(-0.45, palmY, 0), V(0.45, palmY, 0), 0.22, trim)

	addHead(m, look, FULL_HB, 1)
	local palm = CFrame.fromMatrix(V(0, palmY, 0), Vector3.zAxis, -Vector3.xAxis, -Vector3.yAxis)
	return finish(m, handle, palm, true, V(0, FULL_LEFT_Y, 0), V(0, FULL_HB + 0.75, 0.12))
end

local function build(id: string, look: Types.ShovelLook): Model
	if look.Size == "Hand" then
		return buildHand(id, look)
	end
	return buildFull(id, look)
end

function Shovels.Build(shovelId: string): Model
	local def = Config.GetShovel(shovelId)
	return build(shovelId, if def then def.Look else FALLBACK)
end

function Shovels.FromLook(name: string, look: Types.ShovelLook): Model
	return build(name, look)
end

return Shovels
