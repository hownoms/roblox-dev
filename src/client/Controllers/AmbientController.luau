--!strict
--[[
	AmbientController — client-side ambient motion for tagged decor (docs/MAP_ART_DIRECTION.md,
	"Ambient motion contract"). The server builds anchored, non-colliding models and tags them;
	this controller makes them move. Nothing that is not tagged is ever moved.

	Tags (attributes live on the tagged instance; defaults in DEFAULTS below)
	  AmbientSpin         SpinRPM, SpinAxis (pivot-local)          rotate about the pivot
	  AmbientFerrisWheel  SpinRPM; child Model "Wheel" (rotates about its pivot's local Z) and
	                      direct-child Models "Gondola" with HangOffset (Vector3, Wheel-local)
	  AmbientBob          BobHeight, BobPeriod, BobRoll (deg)       bob + gentle roll
	  AmbientSway         SwayDegrees, SwayPeriod                   rock about pivot X and Z
	  AmbientDrift        DriftFrom, DriftTo, DriftSeconds          from -> to facing travel, loops
	  AmbientOrbit        OrbitCenter, OrbitRadius, OrbitSeconds, OrbitBob   circle facing travel
	  AmbientPulse        PulseMin, PulseMax, PulsePeriod           Transparency sine (part/model)
	  AmbientNightLight   —                                         lights / Neon on only at night

	Motion tags can be combined on one instance (e.g. Bob + Sway on a boat); the pose is
	  travel(t) [Drift/Orbit, else the base pivot] -> + bob -> * sway -> * spin.
	Every pose is computed from the BASE pivot captured at registration, never from the current
	pose, so nothing drifts. Time is Workspace:GetServerTimeNow() so all clients roughly agree;
	each instance gets a phase from a hash of its base position so neighbours are not in lockstep.

	Performance: one RenderStepped connection; instances farther than CULL_DISTANCE from the
	camera are skipped (Drift/Orbit and the Ferris wheel have their own, larger radius), those past
	NEAR_DISTANCE update every 3rd frame (staggered). Every moved part goes through one
	Workspace:BulkMoveTo per frame (reused arrays): a Model's parts are placed at
	pose * offset-from-base, captured once, which is cheaper than PivotTo and cannot accumulate
	floating-point error over a long session.

	Settings: ReducedMotion (or graphics quality < 3) stops all motion and puts everything back on
	its base pose; LowGraphics keeps only the few landmark movers (Ferris wheel, Drift, Orbit).
	Night lights are not motion and always follow Lighting.ClockTime.

	Streaming: instances come and go (Util/Tagged handles added / removed / destroyed). A Model
	with no parts yet waits for its first BasePart; parts that stream into an already-animated
	Model are re-aligned to its current pose. Tagged models should still be ModelStreamingMode
	Atomic so they arrive whole.
]]
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Controllers = script.Parent
local State = require(Controllers:WaitForChild("State"))
local Tagged = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("Tagged"))

local AmbientController = {}

local TAU = math.pi * 2
local CULL_DISTANCE = 450
local NEAR_DISTANCE = 200
local TRAVEL_CULL = 2500 -- Drift / Orbit: few, mostly on the horizon
local FERRIS_CULL = 700 -- one landmark, visible from the boardwalk
local QUALITY_POLL = 2 -- seconds between graphics-quality checks
local LIGHT_FADE = 1.5 -- seconds for night lights to fade in / out
local NIGHT_START, NIGHT_END = 17.3, 6.5
local OFF_GLASS = Color3.fromRGB(226, 232, 230) -- an unlit bulb: pale glass
local OFF_BLEND = 0.65

AmbientController.DEFAULTS = {
	SpinRPM = 2,
	SpinAxis = Vector3.new(0, 1, 0),
	BobHeight = 0.6,
	BobPeriod = 4,
	BobRoll = 3,
	SwayDegrees = 5,
	SwayPeriod = 3.5,
	DriftSeconds = 120,
	DriftDistance = 300, -- DriftTo default: this far along the base pivot's LookVector
	OrbitRadius = 25,
	OrbitSeconds = 18,
	OrbitBob = 1.5,
	OrbitBank = 14, -- degrees, gulls lean into the circle
	PulseMin = 0.2,
	PulseMax = 0.8,
	PulsePeriod = 3,
}
local D = AmbientController.DEFAULTS

-- Types -------------------------------------------------------------------------------------------

-- A moved thing: one BasePart, or a Model whose parts are placed as pose * Rel[i]. Rel is each
-- part's offset from the base pivot, captured once, so poses never accumulate float error.
type Body = {
	Inst: Instance, -- Model or BasePart
	Model: Model?,
	Base: CFrame?, -- nil until a Model has parts
	Last: CFrame?, -- last pose we applied (nil = at base)
	Parts: { BasePart },
	Rel: { CFrame },
	Connections: { RBXScriptConnection },
}

type Mover = {
	Body: Body,
	Tags: { [string]: boolean },
	Spin: boolean,
	Bob: boolean,
	Sway: boolean,
	Drift: boolean,
	Orbit: boolean,
	Phase: number, -- 0..1
	Slot: number, -- 0..2 stagger for reduced-rate frames
	-- params
	SpinRate: number, -- rad/s
	SpinAxis: Vector3,
	BobHeight: number,
	BobW: number,
	BobRoll: number, -- rad
	SwayAngle: number, -- rad
	SwayW: number,
	DriftFrom: Vector3,
	DriftDir: Vector3,
	DriftRot: CFrame,
	DriftSeconds: number,
	OrbitCenter: Vector3,
	OrbitRadius: number,
	OrbitSeconds: number, -- signed: negative = reverse
	OrbitBob: number,
	Connections: { RBXScriptConnection },
}

type Gondola = { Body: Body, Hang: Vector3?, Index: number }

type Ferris = {
	Inst: Instance,
	Rpm: number,
	Slot: number,
	Wheel: Body?,
	Gondolas: { [Instance]: Gondola },
	Connections: { RBXScriptConnection },
}

type Pulse = {
	Inst: Instance,
	Parts: { BasePart },
	Original: { [BasePart]: number },
	Min: number,
	Max: number,
	W: number,
	Phase: number,
	Slot: number,
	Center: Vector3,
	Connections: { RBXScriptConnection },
}

type NightPart = { Material: Enum.Material, Color: Color3 }
type NightLight = {
	Lights: { [Light]: number }, -- original Brightness
	Parts: { [BasePart]: NightPart },
	Connections: { RBXScriptConnection },
}

-- State -------------------------------------------------------------------------------------------

local movers: { [Instance]: Mover } = {}
local moverList: { Mover } = {}
local ferrisList: { Ferris } = {}
local pulseList: { Pulse } = {}
local nightList: { NightLight } = {}
local started = false
local frame = 0
local motionOn = true -- false while everything is parked on its base pose
local quality = 10
local nextQualityCheck = 0
local nightTarget = 0 -- 0 day, 1 night
local nightAlpha = 0
local lowOn = false

-- reused every frame (no per-frame table allocations)
local bulkParts: { BasePart } = {}
local bulkCFrames: { CFrame } = {}

-- Helpers -----------------------------------------------------------------------------------------

local function hash(p: Vector3): number
	local s = math.sin(p.X * 12.9898 + p.Y * 37.719 + p.Z * 78.233) * 43758.5453
	return s - math.floor(s)
end

local function num(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then
		return v
	end
	return default
end

local function vec(inst: Instance, name: string, default: Vector3): Vector3
	local v = inst:GetAttribute(name)
	if typeof(v) == "Vector3" then
		return v :: Vector3
	end
	return default
end

local function warnStudio(message: string)
	local ok, studio = pcall(function()
		return RunService:IsStudio()
	end)
	if ok and studio then
		warn("[Ambient] " .. message)
	end
end

local function hasCollidable(inst: Instance): boolean
	if inst:IsA("BasePart") and inst.CanCollide then
		return true
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide then
			return true
		end
	end
	return false
end

local function inGame(inst: Instance): boolean
	return inst.Parent ~= nil and inst:IsDescendantOf(game)
end

local function bodyAdd(body: Body, part: BasePart)
	local base = body.Base
	if not base or part.CanCollide or table.find(body.Parts, part) then
		return -- never move collidable parts
	end
	local rel = base:ToObjectSpace(part.CFrame) -- arrives at its server (base) pose
	table.insert(body.Parts, part)
	table.insert(body.Rel, rel)
	local last = body.Last
	if last then
		part.CFrame = last * rel -- streamed into an already-moved model: carry it along
	end
end

local function bodyRemove(body: Body, part: BasePart)
	local i = table.find(body.Parts, part)
	if i then
		local n = #body.Parts
		body.Parts[i], body.Rel[i] = body.Parts[n], body.Rel[n]
		body.Parts[n], body.Rel[n] = nil, nil
	end
end

-- Captures the base pivot once the body has something to pivot. Returns true when ready.
local function captureBase(body: Body): boolean
	if body.Base then
		return true
	end
	local model = body.Model
	if model and (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)) then
		body.Base = model:GetPivot()
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				bodyAdd(body, d)
			end
		end
		return true
	end
	return false
end

local function newBody(inst: Instance): Body
	local body: Body = { Inst = inst, Model = nil, Base = nil, Last = nil, Parts = {}, Rel = {}, Connections = {} }
	if inst:IsA("Model") then
		body.Model = inst
		table.insert(
			body.Connections,
			inst.DescendantAdded:Connect(function(d: Instance)
				if d:IsA("BasePart") and body.Base then
					bodyAdd(body, d)
				end
			end)
		)
		table.insert(
			body.Connections,
			inst.DescendantRemoving:Connect(function(d: Instance)
				if d:IsA("BasePart") then
					bodyRemove(body, d)
				end
			end)
		)
		captureBase(body)
	elseif inst:IsA("BasePart") then
		body.Base = inst.CFrame
		table.insert(body.Parts, inst)
		table.insert(body.Rel, CFrame.new())
	end
	return body
end

local function apply(body: Body, cf: CFrame)
	body.Last = cf
	local rel = body.Rel
	for i, part in body.Parts do
		table.insert(bulkParts, part)
		table.insert(bulkCFrames, cf * rel[i])
	end
end

local function restore(body: Body)
	local base = body.Base
	if base and body.Last and inGame(body.Inst) then
		for i, part in body.Parts do
			part.CFrame = base * body.Rel[i]
		end
	end
	body.Last = nil
end

local function dropBody(body: Body)
	for _, c in body.Connections do
		c:Disconnect()
	end
	table.clear(body.Connections)
	restore(body)
end

local function flushBulk()
	local n = #bulkParts
	if n == 0 then
		return
	end
	if n == 1 then
		bulkParts[1].CFrame = bulkCFrames[1]
	else
		Workspace:BulkMoveTo(bulkParts, bulkCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	table.clear(bulkParts)
	table.clear(bulkCFrames)
end

local function disconnectAll(list: { RBXScriptConnection })
	for _, c in list do
		c:Disconnect()
	end
	table.clear(list)
end

local function removeFrom<T>(list: { T }, item: T)
	local i = table.find(list, item)
	if i then
		list[i] = list[#list]
		list[#list] = nil
	end
end

-- Pivot movers (Spin / Bob / Sway / Drift / Orbit) ------------------------------------------------

local function readMover(m: Mover)
	local inst = m.Body.Inst
	local base = m.Body.Base or CFrame.new()
	m.Phase = hash(base.Position)
	m.SpinRate = num(inst, "SpinRPM", D.SpinRPM) * TAU / 60
	local axis = vec(inst, "SpinAxis", D.SpinAxis)
	m.SpinAxis = if axis.Magnitude > 1e-4 then axis.Unit else D.SpinAxis
	m.BobHeight = num(inst, "BobHeight", D.BobHeight)
	m.BobW = TAU / math.max(num(inst, "BobPeriod", D.BobPeriod), 0.1)
	m.BobRoll = math.rad(num(inst, "BobRoll", D.BobRoll))
	m.SwayAngle = math.rad(num(inst, "SwayDegrees", D.SwayDegrees))
	m.SwayW = TAU / math.max(num(inst, "SwayPeriod", D.SwayPeriod), 0.1)
	local from = vec(inst, "DriftFrom", base.Position)
	local to = vec(inst, "DriftTo", base.Position + base.LookVector * D.DriftDistance)
	m.DriftFrom = from
	m.DriftDir = to - from
	m.DriftRot = if m.DriftDir.Magnitude > 1e-3 then CFrame.lookAt(Vector3.zero, m.DriftDir.Unit) else base.Rotation
	m.DriftSeconds = math.max(num(inst, "DriftSeconds", D.DriftSeconds), 0.1)
	m.OrbitCenter = vec(inst, "OrbitCenter", base.Position)
	m.OrbitRadius = num(inst, "OrbitRadius", D.OrbitRadius)
	local seconds = num(inst, "OrbitSeconds", D.OrbitSeconds)
	m.OrbitSeconds = if math.abs(seconds) < 0.1 then D.OrbitSeconds else seconds
	m.OrbitBob = num(inst, "OrbitBob", D.OrbitBob)
	m.Spin = m.Tags.AmbientSpin == true
	m.Bob = m.Tags.AmbientBob == true
	m.Sway = m.Tags.AmbientSway == true
	m.Drift = m.Tags.AmbientDrift == true
	m.Orbit = m.Tags.AmbientOrbit == true and not m.Drift
end

local function ready(m: Mover): boolean
	if m.Body.Base then
		return true
	end
	if captureBase(m.Body) then
		readMover(m)
		return true
	end
	return false
end

local function dropMover(m: Mover)
	disconnectAll(m.Connections)
	dropBody(m.Body)
	movers[m.Body.Inst] = nil
	removeFrom(moverList, m)
end

local function addMoverTag(inst: Instance, tag: string): () -> ()
	local m = movers[inst]
	if not m then
		if hasCollidable(inst) then
			warnStudio(tag .. " skipped on collidable " .. inst:GetFullName())
			return function() end
		end
		if not inst:IsA("Model") and not inst:IsA("BasePart") then
			return function() end
		end
		local body = newBody(inst)
		local created: Mover = {
			Body = body,
			Tags = {},
			Spin = false,
			Bob = false,
			Sway = false,
			Drift = false,
			Orbit = false,
			Phase = 0,
			Slot = #moverList % 3,
			SpinRate = 0,
			SpinAxis = D.SpinAxis,
			BobHeight = 0,
			BobW = 1,
			BobRoll = 0,
			SwayAngle = 0,
			SwayW = 1,
			DriftFrom = Vector3.zero,
			DriftDir = Vector3.zero,
			DriftRot = CFrame.new(),
			DriftSeconds = 1,
			OrbitCenter = Vector3.zero,
			OrbitRadius = 0,
			OrbitSeconds = 1,
			OrbitBob = 0,
			Connections = {},
		}
		m = created
		movers[inst] = created
		table.insert(moverList, created)
		table.insert(
			created.Connections,
			inst.AttributeChanged:Connect(function()
				if created.Body.Base then
					readMover(created)
				end
			end)
		)
	end
	local mover = m :: Mover
	mover.Tags[tag] = true
	if mover.Body.Base then
		readMover(mover)
	else
		ready(mover)
	end
	return function()
		mover.Tags[tag] = nil
		if next(mover.Tags) == nil then
			dropMover(mover)
		elseif mover.Body.Base then
			readMover(mover)
		end
	end
end

local function poseMover(m: Mover, t: number): CFrame
	local base = m.Body.Base :: CFrame
	local phase = m.Phase
	local cf = base
	if m.Drift then
		local u = (t / m.DriftSeconds + phase) % 1
		cf = m.DriftRot + (m.DriftFrom + m.DriftDir * u)
	elseif m.Orbit then
		local dir = if m.OrbitSeconds < 0 then -1 else 1
		local theta = TAU * ((t / math.abs(m.OrbitSeconds) + phase) % 1) * dir
		local c, s = math.cos(theta), math.sin(theta)
		local r = m.OrbitRadius
		local pos = m.OrbitCenter + Vector3.new(c * r, m.OrbitBob * math.sin(theta * 2 + phase * TAU), s * r)
		local tangent = Vector3.new(-s * dir, 0, c * dir)
		cf = CFrame.lookAt(pos, pos + tangent) * CFrame.Angles(0, 0, -math.rad(D.OrbitBank) * dir)
	end
	if m.Bob then
		local a = t * m.BobW + phase * TAU
		cf = (cf + Vector3.new(0, math.sin(a) * m.BobHeight, 0))
			* CFrame.Angles(math.sin(a + 1.3) * m.BobRoll, 0, math.sin(a * 0.8 + 2.1) * m.BobRoll * 0.6)
	end
	if m.Sway then
		local a = t * m.SwayW + phase * TAU
		cf = cf * CFrame.Angles(math.sin(a) * m.SwayAngle, 0, math.sin(a * 0.83 + 1.7) * m.SwayAngle * 0.7)
	end
	if m.Spin and m.SpinRate ~= 0 then
		local period = TAU / math.abs(m.SpinRate)
		local angle = ((t % period) / period + phase) * TAU * math.sign(m.SpinRate)
		cf = cf * CFrame.fromAxisAngle(m.SpinAxis, angle)
	end
	return cf
end

-- Ferris wheel ------------------------------------------------------------------------------------

local function ferrisChild(f: Ferris, child: Instance)
	if not child:IsA("Model") then
		return
	end
	if child.Name == "Wheel" and f.Wheel == nil then
		if hasCollidable(child) then
			warnStudio("Ferris Wheel skipped (collidable parts) " .. child:GetFullName())
			return
		end
		f.Wheel = newBody(child)
	elseif child.Name == "Gondola" and f.Gondolas[child] == nil then
		if hasCollidable(child) then
			warnStudio("Ferris Gondola skipped (collidable parts) " .. child:GetFullName())
			return
		end
		local hang = child:GetAttribute("HangOffset")
		local index = 0
		for _ in f.Gondolas do
			index += 1
		end
		f.Gondolas[child] = {
			Body = newBody(child),
			Hang = if typeof(hang) == "Vector3" then hang :: Vector3 else nil,
			Index = index,
		}
	end
end

local function ferrisRemoved(f: Ferris, child: Instance)
	local wheel = f.Wheel
	if wheel and wheel.Inst == child then
		dropBody(wheel)
		f.Wheel = nil
	end
	local gondola = f.Gondolas[child]
	if gondola then
		dropBody(gondola.Body)
		f.Gondolas[child] = nil
	end
end

local function addFerris(inst: Instance): () -> ()
	if not inst:IsA("Model") then
		return function() end
	end
	local f: Ferris = {
		Inst = inst,
		Rpm = num(inst, "SpinRPM", 1),
		Slot = #ferrisList % 3,
		Wheel = nil,
		Gondolas = {},
		Connections = {},
	}
	for _, child in inst:GetChildren() do
		ferrisChild(f, child)
	end
	table.insert(
		f.Connections,
		inst.ChildAdded:Connect(function(child: Instance)
			ferrisChild(f, child)
		end)
	)
	table.insert(
		f.Connections,
		inst.ChildRemoved:Connect(function(child: Instance)
			ferrisRemoved(f, child)
		end)
	)
	table.insert(
		f.Connections,
		inst:GetAttributeChangedSignal("SpinRPM"):Connect(function()
			f.Rpm = num(inst, "SpinRPM", 1)
		end)
	)
	table.insert(ferrisList, f)
	return function()
		disconnectAll(f.Connections)
		if f.Wheel then
			dropBody(f.Wheel)
		end
		for _, g in f.Gondolas do
			dropBody(g.Body)
		end
		removeFrom(ferrisList, f)
	end
end

local function poseFerris(f: Ferris, t: number)
	local wheel = f.Wheel
	if not wheel or not captureBase(wheel) then
		return
	end
	local wheelBase = wheel.Base :: CFrame
	local angle = 0
	if f.Rpm ~= 0 then
		local period = 60 / math.abs(f.Rpm)
		angle = ((t % period) / period) * TAU * math.sign(f.Rpm)
	end
	local rotated = wheelBase * CFrame.Angles(0, 0, angle)
	apply(wheel, rotated)
	local axis = wheelBase.ZVector
	for _, g in f.Gondolas do
		local body = g.Body
		if not captureBase(body) then
			continue
		end
		local base = body.Base :: CFrame
		local hang = g.Hang
		if not hang then
			hang = wheelBase:PointToObjectSpace(base.Position)
			g.Hang = hang
		end
		local h = hang :: Vector3
		local hangNow = rotated:PointToWorldSpace(h)
		local moved = base + (hangNow - wheelBase:PointToWorldSpace(h))
		local swing = math.sin(t * 1.9 + g.Index * 1.7) * math.rad(2.5)
		apply(body, CFrame.new(hangNow) * CFrame.fromAxisAngle(axis, swing) * CFrame.new(-hangNow) * moved)
	end
end

-- Pulse -------------------------------------------------------------------------------------------

local function pulseAddPart(p: Pulse, part: BasePart)
	if p.Original[part] == nil then
		p.Original[part] = part.Transparency
		table.insert(p.Parts, part)
	end
end

local function pulseRemovePart(p: Pulse, part: BasePart)
	local original = p.Original[part]
	if original ~= nil then
		p.Original[part] = nil
		removeFrom(p.Parts, part)
		if inGame(part) then
			part.Transparency = original
		end
	end
end

local function readPulse(p: Pulse)
	p.Min = num(p.Inst, "PulseMin", D.PulseMin)
	p.Max = num(p.Inst, "PulseMax", D.PulseMax)
	p.W = TAU / math.max(num(p.Inst, "PulsePeriod", D.PulsePeriod), 0.1)
end

local function resetPulse(p: Pulse)
	for _, part in p.Parts do
		part.Transparency = p.Original[part]
	end
end

local function addPulse(inst: Instance): () -> ()
	local p: Pulse = {
		Inst = inst,
		Parts = {},
		Original = {},
		Min = 0,
		Max = 0,
		W = 1,
		Phase = 0,
		Slot = #pulseList % 3,
		Center = Vector3.zero,
		Connections = {},
	}
	readPulse(p)
	if inst:IsA("BasePart") then
		pulseAddPart(p, inst)
		p.Center = inst.Position
	else
		for _, d in inst:GetDescendants() do
			if d:IsA("BasePart") then
				pulseAddPart(p, d)
			end
		end
		if inst:IsA("Model") then
			local first = p.Parts[1]
			p.Center = if first then first.Position else Vector3.zero
		end
		table.insert(
			p.Connections,
			inst.DescendantAdded:Connect(function(d: Instance)
				if d:IsA("BasePart") then
					if #p.Parts == 0 then
						p.Center = d.Position
						p.Phase = hash(d.Position)
					end
					pulseAddPart(p, d)
				end
			end)
		)
		table.insert(
			p.Connections,
			inst.DescendantRemoving:Connect(function(d: Instance)
				if d:IsA("BasePart") then
					pulseRemovePart(p, d)
				end
			end)
		)
	end
	p.Phase = hash(p.Center)
	table.insert(
		p.Connections,
		inst.AttributeChanged:Connect(function()
			readPulse(p)
		end)
	)
	table.insert(pulseList, p)
	return function()
		disconnectAll(p.Connections)
		if inGame(inst) then
			resetPulse(p)
		end
		removeFrom(pulseList, p)
	end
end

-- Night lights ------------------------------------------------------------------------------------

local function isNight(clock: number): boolean
	return clock >= NIGHT_START or clock < NIGHT_END
end

local function nightApplyPart(part: BasePart, original: NightPart, alpha: number)
	if alpha >= 0.5 then
		part.Material = original.Material
		part.Color = original.Color
	else
		part.Material = Enum.Material.SmoothPlastic
		part.Color = original.Color:Lerp(OFF_GLASS, OFF_BLEND)
	end
end

local function nightApply(n: NightLight, alpha: number)
	for light, brightness in n.Lights do
		light.Enabled = alpha > 0.001
		light.Brightness = brightness * alpha
	end
	for part, original in n.Parts do
		nightApplyPart(part, original, alpha)
	end
end

local function nightAdd(n: NightLight, inst: Instance)
	if inst:IsA("Light") then
		if n.Lights[inst] == nil then
			n.Lights[inst] = inst.Brightness
			inst.Enabled = nightAlpha > 0.001
			inst.Brightness = n.Lights[inst] * nightAlpha
		end
	elseif inst:IsA("BasePart") and inst.Material == Enum.Material.Neon then
		if n.Parts[inst] == nil then
			local original = { Material = inst.Material, Color = inst.Color }
			n.Parts[inst] = original
			nightApplyPart(inst, original, nightAlpha)
		end
	end
end

local function nightRestore(n: NightLight, inst: Instance)
	if inst:IsA("Light") then
		local brightness = n.Lights[inst]
		if brightness ~= nil then
			n.Lights[inst] = nil
			if inGame(inst) then
				inst.Brightness = brightness
				inst.Enabled = true
			end
		end
	elseif inst:IsA("BasePart") then
		local original = n.Parts[inst]
		if original then
			n.Parts[inst] = nil
			if inGame(inst) then
				inst.Material = original.Material
				inst.Color = original.Color
			end
		end
	end
end

local function addNightLight(inst: Instance): () -> ()
	local n: NightLight = { Lights = {}, Parts = {}, Connections = {} }
	nightAdd(n, inst)
	for _, d in inst:GetDescendants() do
		nightAdd(n, d)
	end
	table.insert(
		n.Connections,
		inst.DescendantAdded:Connect(function(d: Instance)
			nightAdd(n, d)
		end)
	)
	table.insert(
		n.Connections,
		inst.DescendantRemoving:Connect(function(d: Instance)
			nightRestore(n, d)
		end)
	)
	table.insert(nightList, n)
	return function()
		disconnectAll(n.Connections)
		local lights, parts = {}, {}
		for light in n.Lights do
			table.insert(lights, light)
		end
		for part in n.Parts do
			table.insert(parts, part)
		end
		for _, light in lights do
			nightRestore(n, light)
		end
		for _, part in parts do
			nightRestore(n, part)
		end
		removeFrom(nightList, n)
	end
end

local function updateNightTarget()
	nightTarget = if isNight(Lighting.ClockTime) then 1 else 0
end

-- Settings ----------------------------------------------------------------------------------------

local function readQuality(): number
	local ok, level = pcall(function(): any
		return (UserSettings():GetService("UserGameSettings") :: any).SavedQualityLevel
	end)
	if ok and typeof(level) == "EnumItem" then
		local value = (level :: EnumItem).Value
		if value > 0 then -- 0 = Automatic
			return value
		end
	end
	return 10
end

local function parkAll()
	for _, m in moverList do
		restore(m.Body)
	end
	for _, f in ferrisList do
		if f.Wheel then
			restore(f.Wheel)
		end
		for _, g in f.Gondolas do
			restore(g.Body)
		end
	end
	for _, p in pulseList do
		resetPulse(p)
	end
end

-- Frame -------------------------------------------------------------------------------------------

-- Due this frame? Near: always; mid-range: every 3rd frame (staggered); beyond cull: never.
local function due(distance: number, cull: number, slot: number): boolean
	if distance > cull then
		return false
	elseif distance > NEAR_DISTANCE then
		return (frame + slot) % 3 == 0
	end
	return true
end

function AmbientController.Step(dt: number)
	frame += 1
	local clock = os.clock()

	-- night lights fade (not motion: always on)
	if nightAlpha ~= nightTarget then
		local stepAlpha = dt / LIGHT_FADE
		nightAlpha = if nightTarget > nightAlpha
			then math.min(nightTarget, nightAlpha + stepAlpha)
			else math.max(nightTarget, nightAlpha - stepAlpha)
		for _, n in nightList do
			nightApply(n, nightAlpha)
		end
	end

	if clock >= nextQualityCheck then
		nextQualityCheck = clock + QUALITY_POLL
		quality = readQuality()
	end
	local reduced = State.GetSetting("ReducedMotion", false) == true or quality < 3
	if reduced then
		if motionOn then
			motionOn = false
			parkAll()
		end
		return
	end
	motionOn = true
	local low = State.GetSetting("LowGraphics", false) == true

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local camPos = camera.CFrame.Position
	local t = Workspace:GetServerTimeNow()

	for _, m in moverList do
		if not ready(m) then
			continue
		end
		local travel = m.Drift or m.Orbit
		if low and not travel then
			if m.Body.Last then
				restore(m.Body)
			end
			continue
		end
		local at = if travel and m.Body.Last then (m.Body.Last :: CFrame).Position else (m.Body.Base :: CFrame).Position
		if due((at - camPos).Magnitude, if travel then TRAVEL_CULL else CULL_DISTANCE, m.Slot) then
			apply(m.Body, poseMover(m, t))
		end
	end
	for _, f in ferrisList do
		local wheel = f.Wheel
		local base = wheel and wheel.Base
		if not base or due(((base :: CFrame).Position - camPos).Magnitude, FERRIS_CULL, f.Slot) then
			poseFerris(f, t)
		end
	end
	flushBulk()

	if low then
		if not lowOn then
			lowOn = true
			for _, p in pulseList do
				resetPulse(p)
			end
		end
		return
	end
	lowOn = false
	for _, p in pulseList do
		if #p.Parts > 0 and due((p.Center - camPos).Magnitude, CULL_DISTANCE, p.Slot) then
			local alpha = 0.5 + 0.5 * math.sin(t * p.W + p.Phase * TAU)
			local value = p.Min + (p.Max - p.Min) * alpha
			for _, part in p.Parts do
				part.Transparency = value
			end
		end
	end
end

-- Test / debug helpers
function AmbientController.Counts(): { Movers: number, Ferris: number, Pulse: number, Night: number }
	return { Movers = #moverList, Ferris = #ferrisList, Pulse = #pulseList, Night = #nightList }
end

function AmbientController.NightAlpha(): number
	return nightAlpha
end

function AmbientController.Init()
	if started then
		return
	end
	started = true
	updateNightTarget()
	nightAlpha = nightTarget
	Lighting:GetPropertyChangedSignal("ClockTime"):Connect(updateNightTarget)

	for _, tag in { "AmbientSpin", "AmbientBob", "AmbientSway", "AmbientDrift", "AmbientOrbit" } do
		Tagged.Watch(tag, function(inst: Instance): Tagged.Cleanup?
			return addMoverTag(inst, tag)
		end)
	end
	Tagged.Watch("AmbientFerrisWheel", addFerris)
	Tagged.Watch("AmbientPulse", addPulse)
	Tagged.Watch("AmbientNightLight", addNightLight)

	RunService.RenderStepped:Connect(function(dt: number)
		AmbientController.Step(math.min(dt, 0.25))
	end)
end

return AmbientController
