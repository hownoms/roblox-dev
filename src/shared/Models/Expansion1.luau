--!strict
-- First-slice visual factories. No services, rewards, terrain edits or external asset IDs.
-- Bottom pivots for scenery; -Z front. Tools retain the existing Handle-space contract.
local Build = require(script.Parent.Build)
local Kit = {}
local V, CF = Vector3.new, CFrame.new
local rgb = Color3.fromRGB
local C = {
	Navy = rgb(29, 42, 68),
	Ink = rgb(27, 27, 36),
	Cream = rgb(255, 250, 232),
	Coral = rgb(255, 95, 125),
	Blue = rgb(40, 190, 245),
	Gold = rgb(255, 205, 40),
	Sand = rgb(255, 222, 140),
	Skin = rgb(222, 168, 118),
	Hair = rgb(80, 48, 35),
}
Kit.Palette = C
Kit.Spec = {
	Ability = { Charge = 0.8, Cooldown = 8, Range = 12, Corridor = V(12, 8, 8) },
	Vault = { Envelope = V(12, 10, 8), Anchors = 3, Gates = 3 },
	BallDiameter = 7.6, -- routine art choice, fits inside the vault; not the Core finale ball
	StandFootprint = V(2, 0, 2),
}

local function part(m: Instance, name: string, size: Vector3, pos: Vector3, color: Color3): Part
	return Build.part(m, name, size, CF(pos), color)
end

local function model(id: string): Model
	local m = Build.model(id)
	Build.root(m, CF())
	m:SetAttribute("EntityId", id)
	m:SetAttribute("VisualKitVersion", 1)
	return m
end

-- Kinematic block actors, deliberately separate from player avatars. Static dialogue poses
-- are factories; animation controller may interpolate limb groups later.
function Kit.NPC(id: string, pose: string?): Model
	assert(id == "npc_mara" or id == "npc_pip", "Unknown first-slice NPC")
	local m = model(id)
	local mara = id == "npc_mara"
	local outfit = if mara then C.Coral else C.Blue
	local p = pose or "Idle"
	assert(p == "Idle" or p == "Point" or p == "Celebrate", "Unknown dialogue pose")
	m:SetAttribute("Pose", p)
	m:SetAttribute("InteractionRange", 10)
	part(m, "Torso", V(2, 2, 1), V(0, 3, 0), if mara then outfit else C.Cream)
	for side = -1, 1, 2 do
		part(m, "Leg", V(0.9, 1.65, 0.9), V(side * 0.52, 1.075, 0), C.Navy)
		part(m, "Shoe", V(0.94, 0.35, 1.15), V(side * 0.52, 0.175, -0.08), C.Cream)
		local arm = Instance.new("Model")
		arm.Name = if side == -1 then "LeftArmPose" else "RightArmPose"
		arm.Parent = m
		local shoulder = V(side * 1.5, 3.75, 0)
		local sleeve =
			part(arm, "Sleeve", V(0.85, 1.2, 0.95), shoulder + V(0, -0.5, 0), if mara then outfit else C.Cream)
		part(arm, "Cuff", V(0.87, 0.16, 0.97), shoulder + V(0, -1.05, 0), C.Cream)
		part(arm, "Hand", V(0.8, 0.65, 0.9), shoulder + V(0, -1.43, 0), C.Skin)
		arm.PrimaryPart = sleeve
		local angle = if p == "Celebrate"
			then side * math.rad(140)
			else if p == "Point" and side == 1 then math.rad(90) else 0
		Build.transform(arm, CF(shoulder) * CFrame.Angles(0, 0, angle) * CF(-shoulder))
	end
	Build.cyl(m, "Head", 1.1, 1.45, CF(0, 4.55, 0), C.Skin)
	Build.face(m, CF(0, 4.6, -0.73), 1, { cheeks = false, eye = 0.2, spacing = 0.3 })
	part(m, "HairCap", V(1.5, 0.35, 1.45), V(0, 5.05, 0), C.Hair)
	if mara then
		Build.ball(m, "HairBun", 0.72, CF(0, 5.05, 0.75), C.Hair)
		for side = -1, 1, 2 do
			Build.beam(m, "Collar", V(side * 0.65, 3.9, -0.56), V(0, 3.45, -0.56), 0.18, 0.1, C.Cream)
			Build.cylBetween(m, "WhistleCord", V(side * 0.25, 3.9, -0.62), V(0, 3.2, -0.64), 0.045, C.Navy)
		end
		part(m, "Whistle", V(0.32, 0.16, 0.22), V(0, 3.16, -0.72), C.Gold)
	else
		part(m, "Apron", V(1.6, 2, 0.08), V(0, 2.85, -0.56), C.Blue)
		part(m, "ApronPocket", V(1.1, 0.55, 0.1), V(0, 2.55, -0.64), C.Navy)
		part(m, "ApronStrap", V(0.22, 0.45, 0.09), V(0, 3.95, -0.59), C.Cream)
		Build.cyl(m, "HugePencil", 1.6, 0.22, CF(0.47, 3.18, -0.74), C.Gold)
		part(m, "PencilEraser", V(0.24, 0.23, 0.24), V(0.47, 4.08, -0.74), C.Coral)
		Build.spike(m, "PencilTip", V(0.47, 2.38, -0.74), V(0.47, 2.08, -0.74), 0.22, C.Ink)
		part(m, "HairSweep", V(0.95, 0.3, 0.65), V(-0.3, 4.88, -0.52), C.Hair)
	end
	return m
end

function Kit.Broadwave(): Model
	local m = Build.model("tool_broadwave")
	m:SetAttribute("EntityId", "tool_broadwave")
	local handle = Build.cyl(m, "Handle", 1, 0.3, CF(0, 0.5, 0), C.Navy)
	Build.cyl(m, "Shaft", 1.15, 0.27, CF(0, 1.575, 0), C.Cream)
	Build.cyl(m, "LeftGrip", 0.55, 0.36, CF(0, 0.75, 0), C.Blue)
	for side = -1, 1, 2 do
		Build.beam(
			m,
			"GripCheek",
			V(side * 0.36, -0.42, 0),
			V(side * 0.08, 0.08, 0),
			0.14,
			0.16,
			C.Navy,
			nil,
			Vector3.zAxis
		)
	end
	Build.cylBetween(m, "GripBar", V(-0.45, -0.42, 0), V(0.45, -0.42, 0), 0.22, C.Navy)
	Build.cyl(m, "Collar", 0.3, 0.42, CF(0, 2.27, 0), C.Gold)
	part(m, "Blade", V(2.25, 1.1, 0.16), V(0, 2.95, 0), C.Blue)
	Build.ellipsoid(m, "BladeTip", V(2.25, 0.75, 0.16), CF(0, 3.46, 0), C.Blue)
	for side = -1, 1, 2 do
		part(m, "CupRim", V(0.14, 1.2, 0.3), V(side * 1.055, 2.99, 0.12), C.Navy)
	end
	-- Three cream crest dots: recognizable at inventory scale without tiny decal art.
	for i = -1, 1 do
		Build.ball(m, "FoamEmblem", 0.21, CF(i * 0.34, 3.12 + i * 0.06, 0.14), C.Cream)
	end
	local hcf = handle.CFrame
	local palm = CFrame.fromMatrix(V(0, -0.42, 0), Vector3.zAxis, -Vector3.xAxis, -Vector3.yAxis)
	handle:SetAttribute("GripOffset", hcf:ToObjectSpace(palm))
	handle:SetAttribute("TwoHanded", true)
	handle:SetAttribute("ShaftAxis", hcf:VectorToObjectSpace(Vector3.yAxis))
	handle:SetAttribute("CupAxis", hcf:VectorToObjectSpace(Vector3.zAxis))
	handle:SetAttribute("LeftHand", hcf:PointToObjectSpace(V(0, 0.75, 0)))
	handle:SetAttribute("BladePoint", hcf:PointToObjectSpace(V(0, 3.15, 0.2)))
	m.PrimaryPart = handle
	Build.massless(m, handle)
	Build.weldAll(m, handle)
	return m
end

-- The lid swings INSIDE the 12x10x8 envelope. Anchor shapes complement color.
function Kit.SpringVault(state: string?): Model
	local stage = state or "Covered"
	assert(stage == "Covered" or stage == "Partial" or stage == "Opened", "Unknown vault state")
	local m = model("landmark_spring_vault")
	m.Name ..= "_" .. stage
	m:SetAttribute("VisualState", stage)
	Build.solid(part(m, "Floor", V(12, 0.5, 8), V(0, 0.25, 0), C.Navy))
	for side = -1, 1, 2 do
		Build.solid(part(m, "SideWall", V(0.4, 4.5, 8), V(side * 5.8, 2.75, 0), C.Blue))
	end
	Build.solid(part(m, "BackWall", V(12, 4.5, 0.4), V(0, 2.75, 3.8), C.Blue))
	Build.solid(
		part(
			m,
			"FrontWall",
			V(12, if stage == "Opened" then 0.5 else 4.5, 0.4),
			V(0, if stage == "Opened" then 0.25 else 2.75, -3.8),
			C.Blue
		)
	)
	part(m, "AnchorRail", V(11.6, 0.3, 1.5), V(0, 5.25, -2.55), C.Navy)
	local lid = Instance.new("Model")
	lid.Name = "Lid"
	lid.Parent = m
	local plate = part(lid, "LidPlate", V(11.6, 0.45, 7.6), V(0, 5.15, 0), C.Coral)
	lid.PrimaryPart = plate
	for side = -1, 1, 2 do
		part(lid, "StripedHandle", V(1.9, 0.4, 0.5), V(side * 3.8, 5.57, -0.6), C.Navy)
		for i = -1, 1 do
			part(lid, "HandleStripe", V(0.3, 0.42, 0.52), V(side * 3.8 + i * 0.48, 5.57, -0.6), C.Cream)
		end
	end
	if stage == "Opened" then
		local hinge = V(0, 5.15, 3.7)
		Build.transform(lid, CF(hinge) * CFrame.Angles(math.rad(35), 0, 0) * CF(-hinge))
	end
	local latch = part(
		m,
		"Latch",
		V(1.3, if stage == "Opened" then 0.3 else 1.2, 0.35),
		V(0, if stage == "Opened" then 0.65 else 4.1, -3.8),
		C.Gold
	)
	latch:SetAttribute("ObjectiveId", "vault_latch")
	local hinge = Instance.new("Attachment")
	hinge.Name = "LidHinge"
	hinge.Position = V(0, 5.15, 3.7)
	hinge.Parent = m.PrimaryPart
	for i, x in { -3.7, 0, 3.7 } do
		local a = model("vault_anchor_" .. i)
		a.Parent = m
		a:SetAttribute("ObjectiveId", "vault_anchor_" .. i)
		a:SetAttribute("WorkRequiredSolo", 6)
		a:SetAttribute("WorkRequiredCrew", 8)
		a:SetAttribute("WorkRange", 12)
		a:SetAttribute("WorkCooldown", 0.5)
		local exposed = stage == "Opened" or (stage == "Partial" and i == 1)
		local base = part(a, "AnchorBase", V(2.5, 0.2, 1.5), V(x, 5.45, -2.55), C.Navy)
		base:SetAttribute("ProtectedGeometry", true)
		if i == 1 then
			Build.tri(
				a,
				"TriangleMarker",
				CF(x, 5.57, -2.55) * CFrame.Angles(-math.pi / 2, 0, 0),
				0.8,
				0.75,
				0.1,
				C.Cream
			)
		elseif i == 2 then
			part(a, "SquareMarker", V(0.65, 0.12, 0.65), V(x, 5.57, -2.55), C.Cream)
		else
			Build.cyl(a, "CircleMarker", 0.12, 0.7, CF(x, 5.57, -2.55), C.Cream)
		end
		if not exposed then
			local sand = part(
				a,
				"SandCover",
				V(2.3, if stage == "Covered" then 1.8 else 0.9, 1.4),
				V(x, if stage == "Covered" then 6.45 else 6, -2.55),
				C.Sand
			)
			sand:SetAttribute("RemovableVisual", true)
			-- Duplicate the marker above sand: players can read their target before uncovering.
			for _, d in a:GetChildren() do
				if d:IsA("BasePart") and string.find(d.Name, "Marker") then
					local top = d:Clone()
					top.Name = "Covered" .. d.Name
					top.CFrame += V(0, if stage == "Covered" then 1.9 else 1, 0)
					top.Parent = a
				end
			end
		end
		a:SetAttribute("VisualProgress", if exposed then 1 else if stage == "Partial" then 0.5 else 0)
	end
	if stage == "Covered" then
		part(m, "BurialSkirt", V(11.4, 3.4, 7.4), V(0, 2.4, 0), C.Sand)
	elseif stage == "Opened" then
		-- A visible toy spring explains the improbable compressed payload.
		for i = 0, 23 do
			local function coil(t: number): Vector3
				local angle = t * math.pi * 6
				return V(math.cos(angle) * 1.1, 0.65 + t * 1.9, math.sin(angle) * 1.1)
			end
			Build.cylBetween(m, "ToySpring", coil(i / 24), coil((i + 1) / 24), 0.16, C.Gold)
		end
	end
	return m
end

-- Anchored kinematic cargo: controller owns route, gate checks and safe resets.
function Kit.BeachBall(): Model
	local m = model("landmark_spring_vault_ball")
	m:SetAttribute("ParentEntityId", "landmark_spring_vault")
	m:SetAttribute("EventId", "event_vault")
	local d = Kit.Spec.BallDiameter
	local center = V(0, d / 2, 0)
	local sphere = Build.ball(m, "ContactSphere", d, CF(center), C.Cream)
	Build.solid(sphere)
	-- Same intersecting ellipsoid panel construction as the existing Props.BeachBall.
	for stripe, color in { C.Blue, C.Coral, C.Gold } do
		Build.ellipsoid(
			m,
			"ColorPanel",
			V(d + 0.06, d + 0.06, d * 0.65),
			CF(center) * CFrame.Angles(0, (stripe - 1) * math.pi / 3, 0),
			color
		)
	end
	Build.ball(m, "Cap", 0.6, CF(0, d - 0.18, 0), C.Cream)
	local a = Instance.new("Attachment")
	a.Name = "RollEffectOrigin"
	a.Parent = sphere
	m:SetAttribute("MovementMode", "ServerKinematic")
	return m
end

function Kit.TrophyStand(): Model
	local m = model("camp_trophy_stand")
	part(m, "Base", V(2, 0.25, 2), V(0, 0.125, 0), C.Navy)
	part(m, "Pedestal", V(1.6, 1.25, 1.6), V(0, 0.875, 0), C.Cream)
	part(m, "Top", V(2, 0.25, 2), V(0, 1.625, 0), C.Cream)
	part(m, "Plaque", V(0.8, 0.35, 0.06), V(0, 0.95, -0.83), C.Gold)
	local slot = Instance.new("Attachment")
	slot.Name = "TrophySlot"
	slot.Position = V(0, 1.75, 0)
	slot.Parent = m.PrimaryPart
	return m
end

-- Presentation-only quarter stages; authoritative work stays with the event service.
function Kit.SetAnchorProgress(anchor: Model, progress: number)
	local t = math.floor(math.clamp(progress, 0, 1) * 4) / 4
	anchor:SetAttribute("VisualProgress", t)
	local cover = anchor:FindFirstChild("SandCover")
	if cover and cover:IsA("BasePart") then
		local pivot = anchor:GetPivot()
		local localPos = pivot:PointToObjectSpace(cover.Position)
		local height = math.max(0.05, 1.8 * (1 - t))
		cover.Size = V(cover.Size.X, height, cover.Size.Z)
		cover.Position = pivot:PointToWorldSpace(V(localPos.X, 5.55 + height / 2, localPos.Z))
		cover.Transparency = if t == 1 then 1 else 0
		for _, d in anchor:GetChildren() do
			if d:IsA("BasePart") and string.sub(d.Name, 1, 7) == "Covered" then
				local markerPos = pivot:PointToObjectSpace(d.Position)
				d.Position = pivot:PointToWorldSpace(V(markerPos.X, 5.67 + height, markerPos.Z))
				d.Transparency = if t == 1 then 1 else 0
			end
		end
	end
end

function Kit.ChargeEffect(progress: number): Model
	local m = model("tool_broadwave_charge")
	local t = math.clamp(progress, 0, 1)
	for i = 1, 3 do
		local dot = Build.ball(m, "ChargeDot", 0.2, CF((i - 2) * 0.34, 3.12, 0.3), C.Cream)
		dot.Transparency = if t >= i / 3 then 0 else 0.7
	end
	return m
end

function Kit.TrophyReplica(): Model
	local m = Kit.BeachBall()
	Build.scale(m, CF(), 0.18)
	m.Name = "landmark_spring_vault_trophy"
	m:SetAttribute("EntityId", "landmark_spring_vault")
	m:SetAttribute("AssetVariant", "trophy_replica")
	m:SetAttribute("DisplayOnly", true)
	m:SetAttribute("MovementMode", "DisplayOnly")
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		end
	end
	return m
end

-- Local presentation geometry only; caller animates normalized progress and destroys it.
-- Does not carve, award progress, grant sand or push players.
function Kit.AbilityEffect(progress: number, reducedMotion: boolean?): Model
	local m = model("tool_broadwave_effect")
	local t = math.clamp(progress, 0, 1)
	local z = -t * 8
	part(m, "Wave", V(12, if reducedMotion then 0.35 else 1.4, 0.25), V(0, 0.8, z), C.Blue).Transparency = 0.3
	for i = -3, 3 do
		Build.ellipsoid(m, "FoamCrest", V(1.4, 0.35, 0.4), CF(i * 1.65, 1.55, z), C.Cream)
	end
	return m
end

function Kit.BallEffect(reducedMotion: boolean?): Model
	local m = model("landmark_spring_vault_ball_effect")
	for i = 1, if reducedMotion then 4 else 8 do
		local count = if reducedMotion then 4 else 8
		local a = i / count * math.pi * 2
		Build.ellipsoid(m, "BouncePuff", V(0.9, 0.15, 0.5), CF(math.cos(a) * 4.2, 0.1, math.sin(a) * 4.2), C.Cream)
	end
	return m
end

return Kit
