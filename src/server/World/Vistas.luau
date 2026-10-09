--!strict
--[[
	Vistas — everything outside the playable beach (Stream A "Skyline"), one Persistent model
	"CoastalVistas" so it shows from every spot regardless of terrain streaming:
	  * part stand-ins for the terrain headlands, west sea arch and sea stacks (World/Headlands);
	  * the hero lighthouse on the east tip (tapered striped tower, gallery, glass lantern with a
	    Neon core, rotating beam head tagged AmbientSpin) and the keeper's cottage;
	  * the far backdrop and sky life (World/Skyline).
	No collision / query / touch anywhere. Own Random (never the shared World rng).
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(ReplicatedStorage.Shared.Models.Build)
local Headlands = require(script.Parent.Headlands)
local Skyline = require(script.Parent.Skyline)
local Util = require(script.Parent.Util)

local Vistas = {}
local V, CF = Vector3.new, CFrame.new
local rgb = Color3.fromRGB
local CREAM = rgb(246, 236, 214)
local CORAL = rgb(214, 72, 66)
local NAVY = rgb(31, 55, 73)
local WHITE = rgb(250, 246, 236)
local STONE = rgb(190, 180, 164)
local LAMP = rgb(255, 200, 90)

local MATERIAL_LOOK: { [Enum.Material]: Color3 } = {
	[Enum.Material.Rock] = rgb(108, 110, 122),
	[Enum.Material.Limestone] = rgb(228, 212, 176),
	[Enum.Material.Grass] = rgb(110, 214, 92),
	[Enum.Material.LeafyGrass] = rgb(86, 196, 88),
}

local function tag(inst: Instance, name: string)
	CollectionService:AddTag(inst, name)
end

local function p(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Build.part(parent, name, size, cf, color, material)
	part.CastShadow = false
	return part
end

local function cyl(
	parent: Instance,
	name: string,
	y0: number,
	y1: number,
	d: number,
	at: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Build.cyl(parent, name, y1 - y0, d, CF(at.X, (y0 + y1) / 2, at.Z), color, material)
	part.CastShadow = false
	return part
end

-- Part stand-ins for the terrain blobs, slightly smaller so loaded terrain covers them.
local function buildHeadlandParts(parent: Instance)
	local m = Util.Model("Headlands", parent)
	local rng = Random.new(31337)
	for _, b in Headlands.Get().Blobs do
		local r = b.Radius * 0.94
		local look = MATERIAL_LOOK[b.Material] or MATERIAL_LOOK[Enum.Material.Rock]
		local part = Build.ellipsoid(
			m,
			if b.Layer == 3 then "Cap" elseif b.Layer == 2 then "Cliff" else "Rock",
			V(r * 2, r * 1.94, r * 2),
			CF(b.Center) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			look:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.06)),
			b.Material
		)
		part.CastShadow = b.Radius > 20
	end
	for _, spot in Headlands.Get().PalmSpots do
		Skyline.Palm(m, spot, rng:NextNumber(24, 34), rng:NextNumber(0, math.pi * 2), rng)
	end
end

local function buildLighthouse(parent: Instance)
	local d = Headlands.Get()
	local base = d.LighthouseBase
	local m = Util.Model("Lighthouse", parent)
	local toBeach = (V(0, base.Y, 4) - base) * V(1, 0, 1)
	local face = toBeach.Unit
	-- Plinth and steps (reach down into the rock so it never floats).
	cyl(m, "Plinth", base.Y - 14, base.Y + 2, 30, base, STONE, Enum.Material.Cobblestone)
	cyl(m, "PlinthStep", base.Y - 6, base.Y + 0.6, 36, base, STONE:Lerp(NAVY, 0.15), Enum.Material.Cobblestone)
	-- Tapered tower: 8 bands, white trim rings at the joints.
	local y = base.Y + 2
	local bandH = 8.4
	for k = 0, 7 do
		local dia = 21 - k * 0.9
		local band = cyl(m, "TowerBand", y, y + bandH, dia, base, if k % 2 == 0 then CREAM else CORAL)
		band.CastShadow = true
		if k > 0 then
			cyl(m, "Trim", y - 0.4, y + 0.4, dia + 1.4, base, WHITE)
		end
		if k % 2 == 1 and k < 7 then
			local wp = base + face * (dia / 2) + V(0, y + bandH / 2 - base.Y, 0)
			p(m, "Window", V(1.8, 3, 0.6), CFrame.lookAt(wp, wp + face), NAVY)
		end
		y += bandH
	end
	local door = base + face:Cross(Vector3.yAxis) * 10.4 + V(0, 5.5, 0)
	p(m, "Door", V(4, 7, 0.8), CFrame.lookAt(door, door + face:Cross(Vector3.yAxis)), NAVY)
	-- Gallery deck, corbel and railing.
	cyl(m, "Corbel", y - 1, y + 1, 17, base, CREAM)
	cyl(m, "Gallery", y + 1, y + 2.6, 25, base, NAVY)
	local railY = y + 2.6
	local posts = 12
	for k = 0, posts - 1 do
		local a = k * math.pi * 2 / posts
		local a2 = (k + 1) * math.pi * 2 / posts
		local q = base + V(math.cos(a) * 11.8, railY + 1.7 - base.Y, math.sin(a) * 11.8)
		local q2 = base + V(math.cos(a2) * 11.8, railY + 1.7 - base.Y, math.sin(a2) * 11.8)
		p(m, "RailPost", V(0.4, 3.4, 0.4), CF(q), WHITE)
		Build.cylBetween(m, "Rail", q + V(0, 1.6, 0), q2 + V(0, 1.6, 0), 0.35, WHITE).CastShadow = false
	end
	-- Lantern room: navy sill, glass drum, mullions, Neon core + light (AmbientNightLight).
	cyl(m, "LanternSill", railY, railY + 2, 14, base, NAVY)
	local g0, g1 = railY + 2, railY + 11
	local glass = cyl(m, "LanternGlass", g0, g1, 12, base, rgb(190, 232, 240), Enum.Material.Glass)
	glass.Transparency = 0.55
	for k = 0, 7 do
		local a = k * math.pi / 4
		p(m, "Mullion", V(0.5, 9, 0.5), CF(base.X + math.cos(a) * 6, (g0 + g1) / 2, base.Z + math.sin(a) * 6), NAVY)
	end
	local lampY = (g0 + g1) / 2
	local core = Util.Model("LanternCore", m)
	local ball = Build.ball(core, "Core", 4.6, CF(base.X, lampY, base.Z), LAMP, Enum.Material.Neon)
	ball.CastShadow = false
	local light = Build.glow(ball, LAMP, 4, 16)
	light.Name = "LanternLight"
	tag(core, "AmbientNightLight")
	-- Roof: navy band, coral dome, finial and lightning rod.
	cyl(m, "RoofBand", g1, g1 + 1.2, 15, base, NAVY)
	local dome = Build.ellipsoid(m, "Roof", V(15, 11, 15), CF(base.X, g1 + 1.2, base.Z), CORAL)
	dome.CastShadow = false
	Build.ball(m, "Finial", 2.4, CF(base.X, g1 + 7.4, base.Z), NAVY).CastShadow = false
	cyl(m, "Rod", g1 + 7.4, g1 + 13, 0.4, base, NAVY)

	-- Rotating beam head: its own tagged model (not inside another motion model).
	local head = Util.Model("LighthouseBeam", parent)
	local pivot = p(head, "Pivot", V(1, 1, 1), CF(base.X, lampY, base.Z), WHITE)
	pivot.Transparency = 1
	head.PrimaryPart = pivot
	p(head, "LensHousing", V(2.2, 3, 5.4), CF(base.X, lampY, base.Z), NAVY)
	for _, dir in { 1, -1 } do
		local lens = p(head, "Lens", V(2.4, 2.4, 0.4), CF(base.X, lampY, base.Z + dir * 2.9), LAMP, Enum.Material.Neon)
		lens.CastShadow = false
		local far = V(base.X, lampY - 8, base.Z + dir * 150)
		local before = #head:GetChildren()
		Build.spike(head, "BeamCone", far, V(base.X, lampY, base.Z + dir * 3), 26, LAMP, Enum.Material.Neon)
		for i, c in head:GetChildren() do
			if i > before and c:IsA("BasePart") then
				c.Transparency = 0.86
				c.CastShadow = false
			end
		end
	end
	head:SetAttribute("SpinRPM", 4)
	head:SetAttribute("SpinAxis", V(0, 1, 0))
	tag(head, "AmbientSpin")

	-- Keeper's cottage beside the tower, door facing it.
	local cb = d.CottageBase
	local look = CFrame.lookAt(cb, V(base.X, cb.Y, base.Z))
	local cm = Util.Model("KeepersCottage", parent)
	local function at(x: number, yy: number, z: number): CFrame
		return look * CF(x, yy, z)
	end
	p(cm, "Foundation", V(18, 12, 14), at(0, -5, 0), STONE, Enum.Material.Cobblestone)
	local walls = p(cm, "Walls", V(16, 8, 12), at(0, 5, 0), WHITE)
	walls.CastShadow = true
	for _, cx in { -8, 8 } do
		for _, cz in { -6, 6 } do
			p(cm, "CornerTrim", V(0.8, 8.2, 0.8), at(cx, 5, cz), rgb(124, 84, 52))
		end
	end
	Build.tri(cm, "Roof", look * CF(0, 12, 0) * CFrame.Angles(0, math.pi / 2, 0), 15, 6, 19, CORAL)
	p(cm, "Chimney", V(2, 6, 2), at(4.5, 14, 2.5), rgb(160, 92, 70), Enum.Material.Brick)
	local chimneyCap = p(cm, "ChimneyCap", V(2.6, 0.6, 2.6), at(4.5, 17.2, 2.5), NAVY)
	p(cm, "Door", V(3, 6, 0.4), at(0, 4, -6.1), NAVY)
	for _, wx in { -4.8, 4.8 } do
		p(cm, "Window", V(2.6, 2.6, 0.3), at(wx, 5.5, -6.05), rgb(150, 210, 230))
		p(cm, "Shutter", V(0.8, 2.8, 0.3), at(wx - 1.8, 5.5, -6.1), CORAL)
	end
	local glowModel = Util.Model("CottageGlow", cm)
	for _, wx in { -4.8, 4.8 } do
		p(glowModel, "WindowGlow", V(2.2, 2.2, 0.2), at(wx, 5.5, -6.25), LAMP, Enum.Material.Neon)
	end
	Build.glow(walls, LAMP, 2, 14).Name = "CottageLight"
	tag(glowModel, "AmbientNightLight")
	-- Chimney smoke (thin, slow).
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "ChimneySmoke"
	smoke.Color = ColorSequence.new(rgb(235, 235, 235))
	smoke.Rate = 1.5
	smoke.Lifetime = NumberRange.new(5, 8)
	smoke.Speed = NumberRange.new(2, 3)
	smoke.SpreadAngle = Vector2.new(10, 10)
	smoke.Acceleration = V(0.6, 0.3, 0)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 5) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	smoke.Parent = chimneyCap
	-- Stepping stones between the cottage and the tower.
	for k = 1, 4 do
		local sp = cb:Lerp(V(base.X, cb.Y, base.Z), 0.2 + k * 0.13)
		cyl(cm, "SteppingStone", cb.Y - 1.5, cb.Y + 0.4, 3.2, sp, STONE)
	end
	-- Flag on a pole by the cottage (AmbientSway).
	local flag = Util.Model("CottageFlag", parent)
	local poleBase = at(-11, 0, -4).Position
	cyl(flag, "FlagPole", poleBase.Y - 2, poleBase.Y + 18, 0.5, poleBase, WHITE)
	local flagPivot = p(flag, "Pivot", V(0.5, 0.5, 0.5), CF(poleBase), WHITE)
	flagPivot.Transparency = 1
	flag.PrimaryPart = flagPivot
	p(flag, "Flag", V(0.2, 3.4, 5.4), CF(poleBase + V(0, 16, 2.8)), CORAL, Enum.Material.Fabric)
	flag:SetAttribute("SwayDegrees", 6)
	flag:SetAttribute("SwayPeriod", 3.2)
	tag(flag, "AmbientSway")
end

function Vistas.Build(parent: Instance)
	local m = Instance.new("Model")
	m.Name = "CoastalVistas"
	-- The whole backdrop stays loaded on every client (terrain beyond ~320 studs does not).
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	m.Parent = parent
	buildHeadlandParts(m)
	buildLighthouse(m)
	Skyline.Build(m)
end

return Vistas
