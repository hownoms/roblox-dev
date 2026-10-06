--!strict
--[[
	ShovelPoseController — procedural arm pose + scoop animation for held shovels.

	Runs on every client for EVERY character (Motor6D.Transform is local-only, so each client
	poses everybody, and other players' shovels look right too):
	  * Full-size shovels (Tool attribute "TwoHanded" = true, set by ShopService from the model):
	    both arms are solved with 2-bone IK every frame so the right fist holds the top grip and
	    the left fist holds the shaft lower down; the upper body twists and leans a little like
	    a real digger. Arms ignore the walk animation while the shovel is out (legs still walk).
	  * Hand tools (one-handed spade / trowel): the right arm hangs at the side with the spade
	    pointing forward/down (ONE_HAND_REST, solved with IK like the two-handed hold). v2.2
	    playtest: with the default "toolnone" hold (arm out in front) every scoop first had to
	    drop the arm, so the scoop read as digging DOWN. Now a scoop swings the blade forward
	    into the sand and lifts it UP, then the arm goes back to the side.
	  * Scoop (both): wind-up (blade lifts back) -> thrust down/forward into the sand -> LIFT the
	    blade up with a sand clump on it -> toss forward -> back to rest. The length follows the
	    shovel cooldown (SCOOP_*); a scoop that starts while another runs continues from the
	    current pose, so very fast shovels chop continuously instead of snapping.
	  * Local player: DigController calls PlayScoop on every dig click (no server round trip).
	    Others: the server fires "Scoop"(player) for each successful shovel dig (ShopService).
	  * R6 avatars, hand tools (v2.2 playtest 2: the spade still stuck out on blocky R6 avatars):
	    the one-piece right arm swings about the shoulder only (pitch from the same Pose keys),
	    and because a lowered arm would point the spade backwards with the fixed Tool.Grip, the
	    RightGrip weld's C1 is re-aimed locally so the shaft follows the pose (restored on
	    release). R6 + full-size shovels keep the plain grip; a local scoop there falls back to
	    the default Animate "Slash" tool animation.

	Joints: classic Motor6Ds, or AnimationConstraints when Roblox's Avatar Joint Upgrade
	(StarterPlayer.AvatarJointUpgrade) builds the character. v2.2 playtest: the owner's Studio
	used the upgrade, every Motor6D was "missing" and the spade kept the default hold. Both are
	wrapped as a Joint (C0/C1 = Attachment0/1.CFrame for a constraint; same Transform rule).

	R15 joint math (all in UPPERTORSO space, U = identity):
	  A Motor6D places Part1 = Part0 * C0 * Transform * C1:Inverse(). C0.Position is the joint in
	  Part0 space, C1.Position is the same joint in Part1 space. So to put a limb at a wanted
	  CFrame A (U space) under a parent at P:  Transform = C0:Inverse() * P:Inverse() * A * C1.
	  The chain is UpperTorso -RightShoulder-> RightUpperArm -RightElbow-> RightLowerArm
	  -RightWrist-> RightHand (same on the left). Axes: +X right, +Y up, -Z forward.
	  1. Shoulder S = RightShoulder.C0.Position. Bone lengths come from the rig at runtime
	     (upper arm = |RightElbow.C0 - RightShoulder.C1| in UpperArm space, forearm =
	     |RightWrist.C0 - RightElbow.C1|), so any body scale / proportions work.
	  2. The pose gives the right palm point (S + Hand * armLength) and the shaft direction.
	     The wanted Handle CFrame H is the rotation that maps the tool's ShaftAxis/CupAxis
	     (Handle attributes) onto that shaft direction / "cup up" vector, translated so the
	     palm point H * Grip.Position lands on the target. The tool hangs off the hand through
	     the RightGrip weld (Hand * GripC0 == Handle * Grip), so the hand must be
	     Hand = H * Grip * GripC0:Inverse(), and the wrist target is Hand * RightWrist.C1.Position.
	  3. Arm IK, exact for the R15 hinge elbow: the shoulder joint sits at the torso edge, ~0.5
	     stud off the arm's own axis, so a plain shoulder-elbow-wrist triangle is NOT the elbow's
	     bend plane. Instead (solveArm): the elbow flexes about its joint X axis, so the end
	     point is J * Rx(theta) * u (J = RightElbow.C0); the shoulder->end distance depends on
	     theta only and gives theta in closed form (law of cosines in J's YZ plane, see
	     armGeometry). Then the whole arm rotates about the shoulder joint so shoulder->end
	     points at the target, twisted so the back of the upper arm (+Z, the elbow tip) faces
	     the POLE direction. The elbow Transform is then exactly Rx(theta). Out of reach: the
	     arm straightens and the hand (and shovel) slide back to the reachable wrist point.
	  4. Left hand: the target is H * LeftHand (on the shaft). If the left arm can't reach it,
	     the grip slides along the shaft towards the right hand (sphere/line intersection), so
	     the fist never floats off the shaft on short-armed avatars. The forearm and hand are
	     solved as one straight bone (wrist straight); the hand then twists about its own axis
	     so the fist axis (hand -Z) follows the shaft.
	  5. Waist.Transform = Rx(-Lean) * Ry(-Yaw): lean forward, twist the chest to the right (the
	     left shoulder comes forward, which is what lets the short R15 arms reach the shaft).
	     Neck.Transform undoes the twist and part of the lean so the head keeps looking ahead.
	  All writes happen in RunService.Stepped (after the Animator has written this frame's
	  animation Transforms, before physics/render). When a character stops holding a shovel
	  every joint we touched is reset to identity once, and the Animator takes over again.

	Public API:
		ShovelPoseController.Init()
		ShovelPoseController.PlayScoop(character: Model?, cooldown: number?, color: Color3?): boolean
		ShovelPoseController.IsScooping(character: Model?): boolean
		ShovelPoseController.GetDebug(character: Model?): { Posed, TwoHanded, Weight, Scooping }?
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local State = require(script.Parent.State)

local ShovelPoseController = {}

-- =============================================================================================
-- Tuning (UpperTorso axes: +X right, +Y up, -Z forward; Hand offsets are in ARM LENGTHS from the
-- right shoulder joint; Shaft = direction from the top grip to the head; angles in radians).
-- =============================================================================================
type Pose = {
	Hand: Vector3, -- right palm: shoulder + Hand * armLength
	Shaft: Vector3, -- shaft direction (normalised at use)
	Roll: number, -- blade roll about the shaft (0 = cupped face up; negative tips it to the left)
	Yaw: number, -- chest twist at the waist (positive = turn right, left shoulder forward)
	Lean: number, -- forward lean at the waist
}
type Key = { T: number, Pose: Pose }

local rad = math.rad
local V3 = Vector3.new

-- Two-handed rest: right fist at the front of the right hip, shaft crossing down/forward/left,
-- blade ~0.5 stud above the sand ~4 studs ahead (default R15 proportions).
local TWO_HAND_REST: Pose = {
	Hand = V3(-0.6, -0.38, -0.45),
	Shaft = V3(-0.75, -0.42, -0.5),
	Roll = 0,
	Yaw = rad(40),
	Lean = rad(12),
}
-- Scoop keyframes (T = fraction of the scoop). Key 1 is replaced by the current pose.
local TWO_HAND_SCOOP: { Key } = {
	{ T = 0, Pose = TWO_HAND_REST },
	-- wind-up: hands draw back, blade lifts
	{
		T = 0.2,
		Pose = {
			Hand = V3(-0.55, -0.22, -0.36),
			Shaft = V3(-0.78, -0.18, -0.6),
			Roll = 0,
			Yaw = rad(46),
			Lean = rad(4),
		},
	},
	-- thrust: drive the blade down/forward into the sand, lean in
	{
		T = 0.42,
		Pose = {
			Hand = V3(-0.68, -0.46, -0.58),
			Shaft = V3(-0.74, -0.54, -0.42),
			Roll = 0,
			Yaw = rad(38),
			Lean = rad(26),
		},
	},
	-- lift: pull the hands up and level the blade, sand rides on the cupped face
	{
		T = 0.7,
		Pose = {
			Hand = V3(-0.62, -0.28, -0.38),
			Shaft = V3(-0.78, -0.06, -0.62),
			Roll = 0,
			Yaw = rad(42),
			Lean = rad(8),
		},
	},
	-- toss: flick the blade up and roll it over to throw the sand forward
	{
		T = 0.84,
		Pose = {
			Hand = V3(-0.55, -0.2, -0.5),
			Shaft = V3(-0.7, 0.15, -0.7),
			Roll = rad(-70),
			Yaw = rad(30),
			Lean = rad(4),
		},
	},
	{ T = 1, Pose = TWO_HAND_REST },
}
-- Short scoops (fast shovels): no wind-up, straight into the thrust.
local TWO_HAND_FAST: { Key } = {
	{ T = 0, Pose = TWO_HAND_REST },
	{ T = 0.32, Pose = TWO_HAND_SCOOP[3].Pose },
	{ T = 0.66, Pose = TWO_HAND_SCOOP[4].Pose },
	{ T = 0.82, Pose = TWO_HAND_SCOOP[5].Pose },
	{ T = 1, Pose = TWO_HAND_REST },
}

-- One-handed rest: arm hanging at the side, hand by the hip just in front of the thigh, spade
-- pointing forward and down (blade clear of the leg).
local ONE_HAND_REST: Pose = {
	Hand = V3(0.1, -0.9, -0.2),
	Shaft = V3(0.05, -0.5, -0.86),
	Roll = 0,
	Yaw = 0,
	Lean = 0,
}
-- From the side: swing the blade forward and down into the sand (lean in), then lift it UP with
-- the sand on it and flick it forward, then let the arm fall back to the side.
local ONE_HAND_SCOOP: { Key } = {
	{ T = 0, Pose = ONE_HAND_REST },
	{
		T = 0.38,
		Pose = { Hand = V3(0.06, -0.72, -0.5), Shaft = V3(-0.12, -0.85, -0.5), Roll = 0, Yaw = rad(-6), Lean = rad(34) },
	},
	{
		T = 0.72,
		Pose = { Hand = V3(0.18, -0.2, -0.62), Shaft = V3(-0.1, 0.35, -0.93), Roll = rad(-45), Yaw = 0, Lean = rad(4) },
	},
	{ T = 1, Pose = ONE_HAND_REST },
}
local ONE_HAND_FAST: { Key } = ONE_HAND_SCOOP -- no wind-up to skip any more

-- Elbow pole directions (where the elbow points): out to the side, down and a little back.
local RIGHT_POLE = V3(0.8, -0.6, 0.6)
local LEFT_POLE = V3(-0.9, -0.7, 0.2)
local ONE_HAND_POLE = V3(0.6, -0.8, 0.5)

local ELBOW_MAX = rad(150) -- elbow flexion limit
local LEFT_REACH = 0.97 -- left grip slides up the shaft beyond this fraction of a straight arm
local LEFT_MIN_SPACING = 0.45 -- studs: the left fist never slides closer than this to the right
local HEAD_LEAN_FOLLOW = 0.4 -- how much of the waist lean the head keeps (0 = level gaze)
local TWO_HAND_BLEND_TIME = 0.15 -- seconds to blend from the animation into either shovel hold

local SCOOP_COOLDOWN_FRACTION = 0.95 -- scoop length = cooldown * this ...
local SCOOP_MIN_TIME = 0.2 -- ... clamped to [min, max] seconds
local SCOOP_MAX_TIME = 0.45
local SCOOP_FAST_BELOW = 0.3 -- shorter scoops skip the wind-up

local CLUMP_PICKUP_T = { Two = 0.44, One = 0.4 } -- scoop fraction where sand appears on the blade
local CLUMP_TOSS_T = { Two = 0.84, One = 0.72 } -- ... and where it is thrown
local CLUMP_SIZE = { Two = 0.6, One = 0.36 }
local CLUMP_TOSS_VELOCITY = V3(-4, 16, -14) -- character space (forward = -Z), studs/s
local CLUMP_LIFETIME = 1

-- =============================================================================================

-- A Motor6D or an AnimationConstraint, read and written through the same fields:
-- Part1 = Part0 * C0 * Transform * C1:Inverse() for both.
type Joint = {
	Inst: Instance,
	C0: CFrame,
	C1: CFrame,
	Part0: BasePart?,
	Part1: BasePart?,
	Transform: CFrame,
	Parent: Instance?,
}

type Rig = {
	Humanoid: Humanoid,
	UpperTorso: BasePart,
	RightShoulder: Joint,
	RightElbow: Joint,
	RightWrist: Joint,
	LeftShoulder: Joint,
	LeftElbow: Joint,
	LeftWrist: Joint,
	Waist: Joint,
	Neck: Joint?,
	RightHand: BasePart,
	LeftHand: BasePart,
}

type R6Rig = {
	Humanoid: Humanoid,
	Torso: BasePart,
	RightShoulder: Joint,
	RightArm: BasePart,
}

type ToolInfo = {
	Tool: Tool,
	Handle: BasePart,
	TwoHanded: boolean,
	Shaft: Vector3, -- Handle space
	Cup: Vector3,
	Left: Vector3?,
	Blade: Vector3,
}

type Scoop = {
	Start: number,
	Duration: number,
	Keys: { Key },
	BlendIn: boolean,
	Color: Color3?,
	ClumpDone: boolean,
}

type CharState = {
	Rig: Rig?,
	R6: R6Rig?,
	Grips: { [Weld]: CFrame }, -- R6: RightGrip welds whose C1 we re-aimed -> original C1
	RigCheckedAt: number,
	Info: ToolInfo?,
	Weight: number,
	Touched: { Joint },
	Pose: Pose?,
	Scoop: Scoop?,
	Clump: BasePart?,
	Posed: boolean,
}

local states: { [Model]: CharState } = setmetatable({}, { __mode = "k" }) :: any
local toolInfos: { [Tool]: ToolInfo | false } = setmetatable({}, { __mode = "k" }) :: any
local effectsFolder: Folder? = nil

-- Math helpers ----------------------------------------------------------------------------------

local function isFinite(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6
end

-- Rotation whose Y axis is `primary` and whose X axis is `secondary` made perpendicular to it.
local function frameFrom(primary: Vector3, secondary: Vector3): CFrame
	local y = primary.Unit
	local x = secondary - y * secondary:Dot(y)
	if x.Magnitude < 1e-4 then
		local alt = if math.abs(y.X) < 0.9 then Vector3.xAxis else Vector3.zAxis
		x = alt - y * alt:Dot(y)
	end
	x = x.Unit
	return CFrame.fromMatrix(Vector3.zero, x, y, x:Cross(y))
end

-- Rotation mapping fromPrimary -> toPrimary exactly and fromSecondary -> toSecondary as well as
-- possible (both secondaries taken perpendicular to their primaries).
local function align(fromPrimary: Vector3, fromSecondary: Vector3, toPrimary: Vector3, toSecondary: Vector3): CFrame
	return frameFrom(toPrimary, toSecondary) * frameFrom(fromPrimary, fromSecondary):Inverse()
end

local function smooth(x: number): number
	local u = math.clamp(x, 0, 1)
	return u * u * (3 - 2 * u)
end

local function lerpPose(a: Pose, b: Pose, t: number): Pose
	return {
		Hand = a.Hand:Lerp(b.Hand, t),
		Shaft = a.Shaft.Unit:Lerp(b.Shaft.Unit, t),
		Roll = a.Roll + (b.Roll - a.Roll) * t,
		Yaw = a.Yaw + (b.Yaw - a.Yaw) * t,
		Lean = a.Lean + (b.Lean - a.Lean) * t,
	}
end

local function sample(keys: { Key }, alpha: number): Pose
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if alpha <= b.T then
			return lerpPose(a.Pose, b.Pose, smooth((alpha - a.T) / math.max(b.T - a.T, 1e-3)))
		end
	end
	return keys[#keys].Pose
end

-- Rig / tool lookup -------------------------------------------------------------------------------

local jointProxies: { [Instance]: Joint } = setmetatable({}, { __mode = "k" }) :: any

local function attachmentParent(a: any): BasePart?
	local p = if a then a.Parent else nil
	return if p and p:IsA("BasePart") then p else nil
end

-- One stable proxy per joint instance (state.Touched compares them by identity).
local function wrapJoint(inst: Instance): Joint
	local cached = jointProxies[inst]
	if cached then
		return cached
	end
	local raw = inst :: any
	local isMotor = inst:IsA("Motor6D")
	local proxy = setmetatable({ Inst = inst }, {
		__index = function(_, key: string): any
			if isMotor then
				return raw[key]
			elseif key == "C0" then
				local a = raw.Attachment0
				return if a then a.CFrame else CFrame.identity
			elseif key == "C1" then
				local a = raw.Attachment1
				return if a then a.CFrame else CFrame.identity
			elseif key == "Part0" then
				return attachmentParent(raw.Attachment0)
			elseif key == "Part1" then
				return attachmentParent(raw.Attachment1)
			end
			return raw[key] -- Transform, Parent
		end,
		__newindex = function(_, key: string, value: any)
			raw[key] = value -- only Transform is ever written
		end,
	})
	local joint = proxy :: any
	jointProxies[inst] = joint
	return joint
end

local function isJoint(inst: Instance?): boolean
	return inst ~= nil and (inst:IsA("Motor6D") or inst:IsA("AnimationConstraint"))
end

-- The joint called `name` between parts `part0` and `part1`: first by name anywhere in the
-- character, then any Motor6D / AnimationConstraint that connects those two parts.
local function findJoint(character: Model, name: string, part0: string, part1: string): Joint?
	local named = character:FindFirstChild(name, true)
	if named and isJoint(named) then
		local j = wrapJoint(named)
		if j.Part0 and j.Part1 then
			return j
		end
	end
	for _, d in character:GetDescendants() do
		if isJoint(d) then
			local j = wrapJoint(d)
			local p0, p1 = j.Part0, j.Part1
			if p0 and p1 and p0.Name == part0 and p1.Name == part1 then
				return j
			end
		end
	end
	return nil
end

local function part(character: Model, name: string): BasePart?
	local p = character:FindFirstChild(name)
	return if p and p:IsA("BasePart") then p else nil
end

-- The character's R15 rig, or nil plus what is missing (Studio diagnostics).
local function resolveRig(character: Model): (Rig?, string?)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil, "no Humanoid"
	elseif humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return nil, "rig is " .. humanoid.RigType.Name
	end
	local upper = part(character, "UpperTorso")
	local rightHand = part(character, "RightHand")
	local leftHand = part(character, "LeftHand")
	local rs = findJoint(character, "RightShoulder", "UpperTorso", "RightUpperArm")
	local re = findJoint(character, "RightElbow", "RightUpperArm", "RightLowerArm")
	local rw = findJoint(character, "RightWrist", "RightLowerArm", "RightHand")
	local ls = findJoint(character, "LeftShoulder", "UpperTorso", "LeftUpperArm")
	local le = findJoint(character, "LeftElbow", "LeftUpperArm", "LeftLowerArm")
	local lw = findJoint(character, "LeftWrist", "LeftLowerArm", "LeftHand")
	local waist = findJoint(character, "Waist", "LowerTorso", "UpperTorso")
	if not (upper and rightHand and leftHand and rs and re and rw and ls and le and lw and waist) then
		local missing = {}
		local function need(name: string, found: any)
			if found == nil then
				table.insert(missing, name)
			end
		end
		need("UpperTorso", upper)
		need("RightHand", rightHand)
		need("LeftHand", leftHand)
		need("RightShoulder", rs)
		need("RightElbow", re)
		need("RightWrist", rw)
		need("LeftShoulder", ls)
		need("LeftElbow", le)
		need("LeftWrist", lw)
		need("Waist", waist)
		table.sort(missing)
		return nil, "R15 rig is missing " .. table.concat(missing, ", ")
	end
	-- refine for the type checker (guarded above)
	assert(upper and rightHand and leftHand and rs and re and rw and ls and le and lw and waist)
	if rs.Part0 ~= upper or ls.Part0 ~= upper then
		return nil,
			"shoulders are not attached to UpperTorso (RightShoulder.Part0 = " .. (if rs.Part0
				then rs.Part0.Name
				else "nil") .. ")"
	end
	return {
		Humanoid = humanoid :: Humanoid,
		UpperTorso = upper :: BasePart,
		RightShoulder = rs :: Joint,
		RightElbow = re :: Joint,
		RightWrist = rw :: Joint,
		LeftShoulder = ls :: Joint,
		LeftElbow = le :: Joint,
		LeftWrist = lw :: Joint,
		Waist = waist :: Joint,
		Neck = findJoint(character, "Neck", "UpperTorso", "Head"),
		RightHand = rightHand :: BasePart,
		LeftHand = leftHand :: BasePart,
	}
end

local function resolveR6(character: Model): R6Rig?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R6 then
		return nil
	end
	local torso = part(character, "Torso")
	local arm = part(character, "Right Arm")
	local rs = findJoint(character, "Right Shoulder", "Torso", "Right Arm")
	if not (torso and arm and rs) or rs.Part0 ~= torso or rs.Part1 ~= arm then
		return nil
	end
	return {
		Humanoid = humanoid :: Humanoid,
		Torso = torso :: BasePart,
		RightShoulder = rs :: Joint,
		RightArm = arm :: BasePart,
	}
end

-- Every joint still in the character and connected. Avatar appearance loading can replace
-- limbs/joints after spawn; a stale joint must trigger a re-resolve, not silent writes to it.
local function jointAlive(m: Joint?): boolean
	return m ~= nil and m.Parent ~= nil and m.Part0 ~= nil and m.Part1 ~= nil
end

local function rigAlive(rig: Rig): boolean
	return rig.Humanoid.Parent ~= nil
		and jointAlive(rig.RightShoulder)
		and jointAlive(rig.RightElbow)
		and jointAlive(rig.RightWrist)
		and jointAlive(rig.LeftShoulder)
		and jointAlive(rig.LeftElbow)
		and jointAlive(rig.LeftWrist)
		and jointAlive(rig.Waist)
end

local function vecAttr(inst: Instance, name: string): Vector3?
	local v = inst:GetAttribute(name)
	return if typeof(v) == "Vector3" then v else nil
end

local function getToolInfo(tool: Tool): ToolInfo?
	local cached = toolInfos[tool]
	if cached == false then
		return nil
	elseif cached then
		return cached :: ToolInfo
	end
	local found = tool:FindFirstChild("Handle")
	if tool:GetAttribute("ShovelId") == nil or not found or not found:IsA("BasePart") then
		return nil -- not ready yet (or not a shovel); try again next frame
	end
	local handle = found :: BasePart
	local shaft = vecAttr(handle, "ShaftAxis")
	local cup = vecAttr(handle, "CupAxis")
	if not shaft or not cup then
		toolInfos[tool] = false
		return nil
	end
	local shaftAxis = (shaft :: Vector3).Unit
	local left = vecAttr(handle, "LeftHand")
	local twoHanded = (tool:GetAttribute("TwoHanded") == true or handle:GetAttribute("TwoHanded") == true)
		and left ~= nil
	local info: ToolInfo = {
		Tool = tool,
		Handle = handle,
		TwoHanded = twoHanded,
		Shaft = shaftAxis,
		Cup = (cup :: Vector3).Unit,
		Left = left,
		Blade = vecAttr(handle, "BladePoint") or shaftAxis * 3,
	}
	toolInfos[tool] = info
	return info
end

local function heldShovel(character: Model): Tool?
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("ShovelId") ~= nil then
			return child
		end
	end
	return nil
end

-- Palm frame of the right hand (RightGrip weld C0) and the tool grip (C1).
local function gripFrames(rig: Rig, info: ToolInfo): (CFrame, CFrame)
	local weld = rig.RightHand:FindFirstChild("RightGrip")
	if weld and weld:IsA("Weld") and weld.Part1 == info.Handle then
		return weld.C0, weld.C1
	end
	local attachment = rig.RightHand:FindFirstChild("RightGripAttachment")
	local c0 = if attachment and attachment:IsA("Attachment")
		then attachment.CFrame
		else CFrame.new(0, -rig.RightHand.Size.Y / 2, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
	return c0, info.Tool.Grip
end

local function palmPoint(hand: BasePart, attachmentName: string): Vector3
	local attachment = hand:FindFirstChild(attachmentName)
	if attachment and attachment:IsA("Attachment") then
		return attachment.Position
	end
	return V3(0, -hand.Size.Y / 2, 0)
end

-- Writing Transforms --------------------------------------------------------------------------

local function write(state: CharState, m: Joint, target: CFrame, weight: number)
	if not table.find(state.Touched, m) then
		table.insert(state.Touched, m)
	end
	m.Transform = if weight >= 0.999 then target else m.Transform:Lerp(target, weight)
end

local function release(state: CharState)
	for _, m in state.Touched do
		if m.Parent then
			m.Transform = CFrame.identity
		end
	end
	table.clear(state.Touched)
	for weld, original in state.Grips do
		if weld.Parent then
			weld.C1 = original
		end
	end
	table.clear(state.Grips)
	state.Weight = 0
	state.Posed = false
end

type ArmSolve = { Upper: CFrame, Lower: CFrame, Wrist: Vector3 }

-- Arm geometry, all from the rig: shoulder joint point in UpperArm space (sh.C1), elbow joint
-- frame J = el.C0 (UpperArm space; the R15 elbow is a hinge about J's X axis), and the arm's end
-- point u relative to J (el.C1:Inverse() * endLocal, endLocal in LowerArm space). With the elbow
-- bent by theta the end sits at J * Rx(theta) * u, so its distance from the shoulder joint is
--   |Rx(theta) u - a|^2 = |u|^2 + |a|^2 - 2 a.X u.X - 2 |a_yz| |u_yz| cos(theta + delta)
-- with a = shoulder point in J space and delta = angle(u_yz) - angle(a_yz) (angles measured in
-- J's YZ plane, the plane Rx rotates). That gives theta in closed form for a wanted distance.
type ArmGeometry = { A: Vector3, U: Vector3, Ryz: number, Delta: number }

local function armGeometry(sh: Joint, el: Joint, endLocal: Vector3): ArmGeometry
	local u = el.C1:Inverse() * endLocal
	local a = el.C0:PointToObjectSpace(sh.C1.Position)
	return {
		A = a,
		U = u,
		Ryz = math.sqrt(a.Y * a.Y + a.Z * a.Z) * math.sqrt(u.Y * u.Y + u.Z * u.Z),
		Delta = math.atan2(u.Z, u.Y) - math.atan2(a.Z, a.Y),
	}
end

-- Longest shoulder -> end distance (elbow as straight as the rig allows).
local function maxReach(geo: ArmGeometry): number
	local u, a = geo.U, geo.A
	return math.sqrt(math.max(0, u:Dot(u) + a:Dot(a) - 2 * a.X * u.X + 2 * geo.Ryz))
end

local function wrapAngle(x: number): number
	return (x + math.pi) % (2 * math.pi) - math.pi
end

-- Elbow flexion (radians about the hinge X; positive swings the forearm forward) for a wanted
-- shoulder -> end distance. Of the two mirror solutions, the one that bends the elbow forward.
local function elbowAngle(geo: ArmGeometry, dist: number): number
	if geo.Ryz < 1e-6 then
		return 0
	end
	local u, a = geo.U, geo.A
	local k = (u:Dot(u) + a:Dot(a) - dist * dist - 2 * a.X * u.X) / (2 * geo.Ryz)
	local base = math.acos(math.clamp(k, -1, 1))
	local c1 = wrapAngle(base - geo.Delta)
	local c2 = wrapAngle(-base - geo.Delta)
	local function cost(x: number): number
		return if x < -0.05 then -0.05 - x elseif x > ELBOW_MAX then x - ELBOW_MAX else 0
	end
	local k1, k2 = cost(c1), cost(c2)
	if k1 == k2 then
		return math.min(c1, c2)
	end
	return if k1 < k2 then c1 else c2
end

-- Solves an arm so its end point (endLocal, LowerArm space) reaches `target` (U space):
-- 1. elbow angle from the distance, 2. rotate the whole arm about the shoulder joint so the
-- shoulder->end vector points at the target, choosing the twist that turns the back of the
-- upper arm (+Z, where the elbow tip points) towards `pole`. Out of reach: the arm straightens
-- and the reached end point is returned.
local function solveArm(sh: Joint, el: Joint, endLocal: Vector3, target: Vector3, pole: Vector3): ArmSolve
	local geo = armGeometry(sh, el, endLocal)
	local s = sh.C0.Position -- shoulder joint, U space
	local sUpper = sh.C1.Position -- shoulder joint, UpperArm space
	local d = target - s
	local dist = d.Magnitude
	local dir = if dist > 1e-4 then d / dist else V3(0, -1, 0)
	local theta = elbowAngle(geo, dist)
	local bent = el.C0 * CFrame.Angles(theta, 0, 0) -- elbow joint frame after flexion (UpperArm space)
	local v = bent * geo.U - sUpper -- shoulder -> end, UpperArm space
	local r1 = align(v, Vector3.zAxis, dir, pole)
	local upper = CFrame.new(s - r1 * sUpper) * r1
	local lower = upper * bent * el.C1:Inverse()
	return { Upper = upper, Lower = lower, Wrist = s + dir * v.Magnitude }
end

local function applyArm(state: CharState, sh: Joint, el: Joint, wr: Joint, arm: ArmSolve, hand: CFrame, w: number)
	write(state, sh, sh.C0:Inverse() * arm.Upper * sh.C1, w)
	write(state, el, el.C0:Inverse() * arm.Upper:Inverse() * arm.Lower * el.C1, w)
	write(state, wr, wr.C0:Inverse() * arm.Lower:Inverse() * hand * wr.C1, w)
end

local function armLength(sh: Joint, el: Joint, wr: Joint, palm: Vector3): number
	return (el.C0.Position - sh.C1.Position).Magnitude
		+ (wr.C0.Position - el.C1.Position).Magnitude
		+ (palm - wr.C1.Position).Magnitude
end

-- Tool rotation (torso space) for a pose: shaft along pose.Shaft, cupped face up, rolled.
local function toolRotation(info: ToolInfo, pose: Pose): CFrame
	local shaft = pose.Shaft.Unit
	local up = Vector3.yAxis - shaft * shaft.Y
	if up.Magnitude < 0.2 then
		up = -Vector3.zAxis - shaft * -shaft.Z
	end
	local cup = CFrame.fromAxisAngle(shaft, pose.Roll) * up.Unit
	return align(info.Shaft, info.Cup, shaft, cup)
end

-- R6, hand tools: swing the one-piece arm forward about the shoulder by the pose's pitch (the
-- angle of pose.Hand in front of straight down), then re-aim the grip weld so the shaft points
-- along pose.Shaft from the palm. All in Torso space.
local function applyPoseR6(state: CharState, rig: R6Rig, info: ToolInfo, pose: Pose, weight: number): boolean
	local weld = rig.RightArm:FindFirstChild("RightGrip")
	if not (weld and weld:IsA("Weld") and weld.Part1 == info.Handle) then
		return false
	end
	local rs = rig.RightShoulder
	local pitch = math.atan2(-pose.Hand.Z, math.max(-pose.Hand.Y, 0.05))
	local pivot = rs.C0.Position
	local arm = CFrame.new(pivot) * CFrame.Angles(pitch, 0, 0) * CFrame.new(-pivot) * rs.C0 * rs.C1:Inverse()
	write(state, rs, rs.C0:Inverse() * arm * rs.C1, weight)

	local original = state.Grips[weld] or weld.C1
	state.Grips[weld] = original
	local palm = arm * weld.C0
	local rot = toolRotation(info, pose)
	local handle = CFrame.new(palm.Position - rot * original.Position) * rot
	local c1 = handle:Inverse() * palm -- weld rule: Arm * C0 == Handle * C1
	weld.C1 = if weight >= 0.999 then c1 else original:Lerp(c1, weight)
	return true
end

-- Poses one character. Returns false if the pose could not be solved (nothing written).
local function applyPose(state: CharState, rig: Rig, info: ToolInfo, pose: Pose, weight: number): boolean
	local rs, re, rw = rig.RightShoulder, rig.RightElbow, rig.RightWrist
	local gripC0, grip = gripFrames(rig, info)
	local rightPalm = gripC0.Position
	local shoulder = rs.C0.Position
	local reach = armLength(rs, re, rw, rightPalm)

	-- 2. Wanted tool CFrame (U space): shaft along pose.Shaft, cupped face up, rolled.
	local rot = toolRotation(info, pose)
	local palmTarget = shoulder + pose.Hand * reach
	if not isFinite(palmTarget) then
		return false
	end
	local handle = CFrame.new(palmTarget - rot * grip.Position) * rot
	local hand = handle * grip * gripC0:Inverse()

	-- 3. Right arm IK to the wrist point of that hand.
	local wristTarget = hand * rw.C1.Position
	local right = solveArm(rs, re, rw.C0.Position, wristTarget, if info.TwoHanded then RIGHT_POLE else ONE_HAND_POLE)
	local slip = right.Wrist - wristTarget -- non-zero only when out of reach
	hand += slip
	handle += slip
	if not isFinite(right.Wrist) then
		return false
	end
	applyArm(state, rs, re, rw, right, hand, weight)

	-- 4. Left hand on the shaft.
	local left = info.Left
	if info.TwoHanded and left then
		local ls, le, lw = rig.LeftShoulder, rig.LeftElbow, rig.LeftWrist
		local lPalmHand = palmPoint(rig.LeftHand, "LeftGripAttachment")
		local lShoulder = ls.C0.Position
		-- Forearm + hand as one straight bone: the palm in LowerArm space with the wrist at rest.
		local wristRest = lw.C0 * lw.C1:Inverse()
		local lEnd = wristRest * lPalmHand
		local lReach = maxReach(armGeometry(ls, le, lEnd)) * LEFT_REACH
		local gripPoint = handle * grip.Position
		local axis = handle:VectorToWorldSpace(info.Shaft)
		local want = (handle * left - gripPoint):Dot(axis)
		-- Sphere (left reach) / shaft line intersection: |q + axis * t| = lReach.
		local q = gripPoint - lShoulder
		local b = q:Dot(axis)
		local disc = b * b - (q:Dot(q) - lReach * lReach)
		local t = want
		if disc >= 0 then
			local far = -b + math.sqrt(disc)
			if t > far then
				t = math.max(far, LEFT_MIN_SPACING)
			end
		else
			t = math.min(want, LEFT_MIN_SPACING)
		end
		local leftTarget = gripPoint + axis * t
		local leftArm = solveArm(ls, le, lEnd, leftTarget, LEFT_POLE)
		local leftHand = leftArm.Lower * wristRest
		-- Twist the hand about its own axis so the fist axis (hand -Z) runs along the shaft.
		local localAxis = leftHand:VectorToObjectSpace(axis)
		if localAxis.X * localAxis.X + localAxis.Z * localAxis.Z > 0.05 then
			local twist = math.atan2(-localAxis.X, -localAxis.Z)
			if twist > math.pi / 2 then
				twist -= math.pi
			elseif twist < -math.pi / 2 then
				twist += math.pi
			end
			local pivot = lw.C1.Position
			leftHand = leftHand * CFrame.new(pivot) * CFrame.Angles(0, twist, 0) * CFrame.new(-pivot)
		end
		applyArm(state, ls, le, lw, leftArm, leftHand, weight)
	end

	-- 5. Waist twist / lean, head counter-rotation.
	local waist = CFrame.Angles(-pose.Lean, 0, 0) * CFrame.Angles(0, -pose.Yaw, 0)
	write(state, rig.Waist, waist, weight)
	local neck = rig.Neck
	if neck then
		write(
			state,
			neck,
			CFrame.Angles(0, pose.Yaw, 0) * CFrame.Angles(pose.Lean * (1 - HEAD_LEAN_FOLLOW), 0, 0),
			weight
		)
	end
	return true
end

-- Sand clump --------------------------------------------------------------------------------------

local function lowGraphics(): boolean
	return State.GetSetting("LowGraphics", false) == true
end

local function getFolder(): Folder
	local folder = effectsFolder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "ShovelEffects"
	f.Parent = Workspace
	effectsFolder = f
	return f
end

local function layerColorAt(character: Model): Color3
	local root = character:FindFirstChild("HumanoidRootPart")
	local depth = 0
	if root and root:IsA("BasePart") then
		depth = math.max(0, Config.SURFACE_Y - (root.Position.Y - 3))
	end
	local layer = Config.Layers[Config.GetLayerIndexAtDepth(depth)] or Config.Layers[1]
	return layer.Color
end

local function bladeCFrame(info: ToolInfo): CFrame
	return info.Handle.CFrame * CFrame.new(info.Blade)
end

local function spawnClump(state: CharState, info: ToolInfo, color: Color3)
	if lowGraphics() then
		return
	end
	local size = if info.TwoHanded then CLUMP_SIZE.Two else CLUMP_SIZE.One
	local clump = Instance.new("Part")
	clump.Name = "SandClump"
	clump.Shape = Enum.PartType.Ball
	clump.Size = V3(size, size * 0.8, size)
	clump.Color = color
	clump.Material = Enum.Material.Sand
	clump.Anchored = true
	clump.CanCollide = false
	clump.CanQuery = false
	clump.CanTouch = false
	clump.CastShadow = false
	clump.CFrame = bladeCFrame(info)
	clump.Parent = getFolder()
	state.Clump = clump
end

local function tossClump(state: CharState, character: Model)
	if not state.Clump then
		return
	end
	local clump = state.Clump :: BasePart
	state.Clump = nil
	local root = character:FindFirstChild("HumanoidRootPart")
	local velocity = if root and root:IsA("BasePart")
		then root.CFrame:VectorToWorldSpace(CLUMP_TOSS_VELOCITY)
		else V3(0, CLUMP_TOSS_VELOCITY.Y, 0)
	clump.Anchored = false
	clump.AssemblyLinearVelocity = velocity
	clump.AssemblyAngularVelocity = V3(math.random() * 8, math.random() * 8, math.random() * 8)
	Debris:AddItem(clump, CLUMP_LIFETIME)
end

-- Per-frame update -------------------------------------------------------------------------------

local function getState(character: Model): CharState
	local state = states[character]
	if not state then
		local s: CharState = {
			Rig = nil,
			R6 = nil,
			Grips = {},
			RigCheckedAt = -math.huge,
			Info = nil,
			Weight = 0,
			Touched = {},
			Pose = nil,
			Scoop = nil,
			Clump = nil,
			Posed = false,
		}
		states[character] = s
		state = s
	end
	return state :: CharState
end

-- Studio only: one Output line per character whenever its pose status changes, so a playtest
-- shows whether the shovel pose runs and, if not, why (v2.2 playtest: the spade kept the
-- default hold on the owner's avatar and nothing said why).
local lastStatus: { [Model]: string } = setmetatable({}, { __mode = "k" }) :: any
local function report(character: Model, status: string, isProblem: boolean)
	if not RunService:IsStudio() or lastStatus[character] == status then
		return
	end
	lastStatus[character] = status
	local line = "[ShovelPose] " .. character.Name .. ": " .. status
	if isProblem then
		warn(line)
	else
		print(line)
	end
end

-- The character's R15 rig, or (when it has none) its R6 rig.
local function getRig(state: CharState, character: Model, now: number): (Rig?, R6Rig?)
	local rig = state.Rig
	if rig and rigAlive(rig) then
		return rig, nil
	end
	local r6 = state.R6
	if r6 and r6.RightShoulder.Parent ~= nil and r6.Humanoid.Parent ~= nil then
		return nil, r6
	end
	state.Rig = nil
	state.R6 = nil
	if now - state.RigCheckedAt < 1 then
		return nil, nil
	end
	state.RigCheckedAt = now
	local rig15, why = resolveRig(character)
	state.Rig = rig15
	state.R6 = if rig15 then nil else resolveR6(character)
	if not rig15 and not state.R6 then
		report(character, "can't pose the shovel: " .. (why or "unknown rig"), true)
	end
	return state.Rig, state.R6
end

local function updateCharacter(character: Model, now: number, dt: number)
	local state = getState(character)
	local tool = heldShovel(character)
	local found = if tool then getToolInfo(tool) else nil
	local foundRig, foundR6 = nil, nil
	if found then
		foundRig, foundR6 = getRig(state, character, now)
	end
	if found and found.TwoHanded then
		foundR6 = nil -- R6 + full-size shovel: plain grip
	end
	if found ~= state.Info then
		if state.Clump then
			tossClump(state, character)
		end
		state.Info = found
		state.Scoop = nil
		release(state)
	end
	if not found or not (foundRig or foundR6) then
		if state.Posed then
			release(state)
		end
		return
	end
	local info = found :: ToolInfo
	local humanoid = if foundRig then foundRig.Humanoid else (foundR6 :: R6Rig).Humanoid
	if humanoid.Health <= 0 or humanoid.Sit then
		if state.Posed then
			release(state)
		end
		return
	end

	local scoop = state.Scoop
	local alpha = 1
	if scoop then
		alpha = (now - scoop.Start) / scoop.Duration
		if alpha >= 1 then
			state.Scoop = nil
			if state.Clump then
				tossClump(state, character)
			end
			scoop = nil
		end
	end

	-- Both holds are posed all the time while the shovel is out (blended in on equip).
	state.Weight = math.min(1, state.Weight + dt / TWO_HAND_BLEND_TIME)
	local weight = state.Weight
	local rest = if info.TwoHanded then TWO_HAND_REST else ONE_HAND_REST
	local pose: Pose = if scoop then sample(scoop.Keys, alpha) else rest

	state.Pose = pose
	local posed = if foundRig
		then applyPose(state, foundRig, info, pose, weight)
		else applyPoseR6(state, foundR6 :: R6Rig, info, pose, weight)
	if posed then
		state.Posed = true
		report(
			character,
			"posing "
				.. (if info.TwoHanded then "two-handed" else "one-handed")
				.. (if foundRig then " (R15)" else " (R6)"),
			false
		)
	else
		report(character, "pose could not be solved for this avatar", true)
	end

	-- sand clump rides the blade between the thrust and the toss
	if scoop and not scoop.ClumpDone then
		local pickup = if info.TwoHanded then CLUMP_PICKUP_T.Two else CLUMP_PICKUP_T.One
		if alpha >= pickup then
			scoop.ClumpDone = true
			if state.Clump then
				tossClump(state, character)
			end
			spawnClump(state, info, scoop.Color or layerColorAt(character))
		end
	end
	if state.Clump and scoop then
		local toss = if info.TwoHanded then CLUMP_TOSS_T.Two else CLUMP_TOSS_T.One
		if alpha >= toss then
			tossClump(state, character)
		end
	end
end

local function onStepped(_time: number, dt: number)
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			local ok, err = pcall(function(): any
				updateCharacter(character, now, dt)
				return nil
			end)
			if not ok then
				warn("[ShovelPose] " .. tostring(err))
				local state = states[character]
				if state then
					state.Scoop = nil
					release(state)
				end
			end
		end
	end
end

-- Riding clumps follow the blade after physics has moved the arms this frame.
local function onHeartbeat()
	for character, state in states do
		local clump = state.Clump
		local info = state.Info
		if clump and info then
			if info.Handle.Parent and character.Parent then
				clump.CFrame = bladeCFrame(info)
			else
				tossClump(state, character)
			end
		end
	end
end

-- Public API --------------------------------------------------------------------------------------

local function scoopDuration(cooldown: number): number
	return math.clamp(cooldown * SCOOP_COOLDOWN_FRACTION, SCOOP_MIN_TIME, SCOOP_MAX_TIME)
end

local function legacySwing(character: Model)
	-- R6 / unposable rigs: the default Animate script plays its slash when it sees this value.
	local tool = heldShovel(character)
	if tool and character == (Players.LocalPlayer and Players.LocalPlayer.Character) then
		local anim = Instance.new("StringValue")
		anim.Name = "toolanim"
		anim.Value = "Slash"
		anim.Parent = tool
	end
end

-- Plays one scoop on `character` (default: the local player's). `cooldown` = the shovel's dig
-- cooldown (sets the scoop length); `color` = sand colour of the clump (default: the layer
-- under the character).
function ShovelPoseController.PlayScoop(character: Model?, cooldown: number?, color: Color3?): boolean
	local localPlayer = Players.LocalPlayer
	local target = character or (localPlayer and localPlayer.Character)
	if not target then
		return false
	end
	local char = target :: Model
	local tool = heldShovel(char)
	local found = if tool then getToolInfo(tool) else nil
	local now = os.clock()
	local state = getState(char)
	local rig, r6 = nil, nil
	if found then
		rig, r6 = getRig(state, char, now)
	end
	if not found or not (rig or (r6 and not found.TwoHanded)) then
		legacySwing(char)
		return false
	end
	local info = found :: ToolInfo
	local cd = cooldown
	if cd == nil then
		local def = Config.GetShovel(tostring((tool :: Tool):GetAttribute("ShovelId")))
		cd = if def then def.Cooldown else 0.4
	end
	local duration = scoopDuration(cd :: number)
	local template = if info.TwoHanded
		then (if duration < SCOOP_FAST_BELOW then TWO_HAND_FAST else TWO_HAND_SCOOP)
		else (if duration < SCOOP_FAST_BELOW then ONE_HAND_FAST else ONE_HAND_SCOOP)
	local keys = table.clone(template)
	local running = state.Scoop ~= nil
	local current = state.Pose
	if running and current then
		keys[1] = { T = 0, Pose = current } -- continue from where the arms are now
	end
	if state.Clump then
		tossClump(state, char)
	end
	state.Info = info
	state.Scoop = {
		Start = now,
		Duration = duration,
		Keys = keys,
		BlendIn = not (running and current ~= nil),
		Color = color,
		ClumpDone = false,
	}
	return true
end

function ShovelPoseController.IsScooping(character: Model?): boolean
	local localPlayer = Players.LocalPlayer
	local target = character or (localPlayer and localPlayer.Character)
	local state = if target then states[target] else nil
	return state ~= nil and state.Scoop ~= nil
end

-- For tests / debugging.
function ShovelPoseController.GetDebug(
	character: Model?
): { Posed: boolean, TwoHanded: boolean, Weight: number, Scooping: boolean }?
	local localPlayer = Players.LocalPlayer
	local target = character or (localPlayer and localPlayer.Character)
	local found = if target then states[target] else nil
	if not found then
		return nil
	end
	local state = found :: CharState
	local info = state.Info
	return {
		Posed = state.Posed,
		TwoHanded = info ~= nil and info.TwoHanded,
		Weight = state.Weight,
		Scooping = state.Scoop ~= nil,
	}
end

function ShovelPoseController.Init()
	RunService.Stepped:Connect(onStepped)
	RunService.Heartbeat:Connect(onHeartbeat)
	task.spawn(function()
		Remotes.Get("Scoop").OnClientEvent:Connect(function(player: any)
			if typeof(player) ~= "Instance" or not (player :: Instance):IsA("Player") then
				return
			end
			local character = (player :: Player).Character
			if character then
				ShovelPoseController.PlayScoop(character)
			end
		end)
	end)
end

return ShovelPoseController
