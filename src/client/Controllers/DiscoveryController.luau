--!strict
--[[
	DiscoveryController (v3 discovery slice) — the client half of buried finds. UI-agnostic: the
	detector HUD, the excavation minigame and the reveal presentation subscribe to its signals
	(wired in Main.client). Design: docs/design/Discovery.md.

	Detector
	  DiscoveryController.Scan()           ask the server for a scan (key T / gamepad L2 / HUD button)
	  DiscoveryController.Ping             last Types.DetectorPing (coarse: band / sector / up-down /
	                                       signal colour; the client never learns deposit positions)
	  DiscoveryController.PingChanged      (ping)
	  DiscoveryController.CooldownLeft()   seconds until Scan works again (client mirror)
	  Beeps faster as the band gets hotter (Finds.BeepInterval) while a scan runs, and a
	  world-space arrow (shaft "DetectorArrow" + chevron head) by the character's feet points at
	  the sector in the signal colour; it pulses when the find is in the hot band (not with
	  Reduced Motion).

	Excavation
	  ExcavationStarted (Types.ExcavationInfo) -> UI/ExcavationGame plays the rings
	  DiscoveryController.Excavate(id, errors) answers the server
	  DiscoveryController.FindRevealed (Types.FindInfo) -> UI/FindReveal presents it

	World FX (every client, streaming-safe): models tagged "DiscoveryFind" are watched with
	Util/Tagged (existing + added + removed / streamed out). While Stage = "Excavating" the find
	sits half-buried (the owner's taps nudge it up locally); when Stage turns "Revealed" it rises
	out of the ground with a dust burst, and Beam+ tiers get a coloured light beam (Server and
	Spectacle tiers: a tall sky beam everyone on the server sees). A model that streams in already
	revealed is shown risen, without replaying the animation.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Finds = require(Shared:WaitForChild("Util"):WaitForChild("Finds"))

local State = require(script.Parent.State)
local SoundController = require(script.Parent.SoundController)
local EffectsController = require(script.Parent.EffectsController)
local Signal = require(script.Parent.Parent.Util.Signal)
local Character = require(script.Parent.Parent.Util.Character)
local Tagged = require(script.Parent.Parent.Util.Tagged)

local D = Config.Discovery
local TAG = "DiscoveryFind"

local DiscoveryController = {}

local EMPTY_PING: Types.DetectorPing = { Band = 0, Sector = -1, Vertical = "", Signal = "", Remaining = 0 }

DiscoveryController.Ping = EMPTY_PING
DiscoveryController.PingAt = 0 -- os.clock() when Ping arrived
DiscoveryController.PingChanged = Signal.new() -- (ping)
DiscoveryController.ExcavationStarted = Signal.new() -- (info: Types.ExcavationInfo)
DiscoveryController.FindRevealed = Signal.new() -- (info: Types.FindInfo)
DiscoveryController.Active = nil :: Types.ExcavationInfo?
DiscoveryController.Models = {} :: { [string]: Model } -- FindId -> streamed-in model

local lastScan = -math.huge
local lastBeep = 0
local arrow: Part? = nil
local initialized = false

-- Signal colour of a ping ("" -> white).
function DiscoveryController.SignalColor(signal: string): Color3
	return D.SIGNAL_COLORS[signal] or D.SIGNAL_COLORS.White
end

function DiscoveryController.CooldownLeft(): number
	return math.max(0, D.SCAN_COOLDOWN - (os.clock() - lastScan))
end

-- Seconds of scan left on the latest ping (counts down locally between pings).
function DiscoveryController.ScanLeft(): number
	local ping = DiscoveryController.Ping
	return math.max(0, ping.Remaining - (os.clock() - DiscoveryController.PingAt))
end

function DiscoveryController.IsScanning(): boolean
	return DiscoveryController.ScanLeft() > 0
end

-- Returns true when a scan request was sent.
function DiscoveryController.Scan(): boolean
	if DiscoveryController.CooldownLeft() > 0 then
		return false
	end
	lastScan = os.clock()
	SoundController.Play("DetectorBeep", 0.8)
	Remotes.Get("Scan"):FireServer()
	return true
end

function DiscoveryController.Excavate(id: string, errors: { number })
	if DiscoveryController.Active and DiscoveryController.Active.Id == id then
		DiscoveryController.Active = nil
	end
	Remotes.Get("Excavate"):FireServer(id, errors)
end

-- Direction (world, horizontal unit) of the latest ping, or nil.
function DiscoveryController.PingDirection(): Vector3?
	local ping = DiscoveryController.Ping
	if ping.Band <= 0 or ping.Sector < 0 then
		return nil
	end
	return Finds.SectorDirection(ping.Sector)
end

-- Screen-relative arrow angle in degrees (0 = straight ahead / up on screen, clockwise), or nil.
function DiscoveryController.ArrowAngle(cameraLook: Vector3?): number?
	local dir = DiscoveryController.PingDirection()
	if not dir then
		return nil
	end
	local look = cameraLook or (Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame.LookVector) or Vector3.zAxis
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.zAxis
	end
	flat = flat.Unit
	local d = dir :: Vector3
	local right = Vector3.new(-flat.Z, 0, flat.X) -- camera right on the ground plane
	return math.deg(math.atan2(d:Dot(right), d:Dot(flat)))
end

-- Pings -------------------------------------------------------------------------------------------

local function sanitizePing(raw: any): Types.DetectorPing?
	if type(raw) ~= "table" then
		return nil
	end
	local band = if type(raw.Band) == "number" then math.clamp(math.floor(raw.Band), 0, #D.BANDS + 1) else 0
	return {
		Band = band,
		Sector = if type(raw.Sector) == "number" then math.floor(raw.Sector) else -1,
		Vertical = if type(raw.Vertical) == "string" then raw.Vertical else "",
		Signal = if type(raw.Signal) == "string" then raw.Signal else "",
		Remaining = if type(raw.Remaining) == "number" then math.max(raw.Remaining, 0) else 0,
	}
end

function DiscoveryController.ApplyPing(raw: any)
	local maybe = sanitizePing(raw)
	if not maybe then
		return
	end
	local ping = maybe :: Types.DetectorPing
	DiscoveryController.Ping = ping
	DiscoveryController.PingAt = os.clock()
	DiscoveryController.PingChanged:Fire(ping)
end

local arrowHead: { Part } = {}

local function arrowPart(name: string, size: Vector3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Block
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Transparency = 1
	part.Parent = parent
	return part
end

-- Shaft part (its Color/Transparency are the arrow's) plus two chevron arms as its children.
local function getArrow(): Part
	local current = arrow
	if current and current.Parent then
		return current
	end
	local part = arrowPart("DetectorArrow", Vector3.new(0.5, 0.15, 2.4), Workspace)
	arrowHead = {
		arrowPart("HeadLeft", Vector3.new(0.5, 0.15, 1.5), part),
		arrowPart("HeadRight", Vector3.new(0.5, 0.15, 1.5), part),
	}
	arrow = part
	return part
end

local function hideArrow()
	if arrow then
		arrow.Transparency = 1
	end
	for _, arm in arrowHead do
		arm.Transparency = 1
	end
end

local function updateWorld()
	local ping = DiscoveryController.Ping
	local scanning = DiscoveryController.IsScanning()
	local dir = DiscoveryController.PingDirection()
	local root = Character.GetRoot()
	-- beeps
	if scanning and ping.Band > 0 then
		local interval = Finds.BeepInterval(ping.Band)
		local now = os.clock()
		if interval > 0 and now - lastBeep >= interval then
			lastBeep = now
			SoundController.Play("DetectorBeep", 1 + (4 - ping.Band) * 0.12, 0.6)
		end
	end
	-- ground arrow
	if not scanning or not dir or not root then
		hideArrow()
		return
	end
	local part = getArrow()
	local base = (root :: BasePart).Position - Vector3.new(0, 2.6, 0)
	local d = dir :: Vector3
	local hot = ping.Band == 1
	local pulse = if hot and State.GetSetting("ReducedMotion", false) ~= true
		then 1 + 0.15 * math.sin(os.clock() * 8)
		else 1
	local color = DiscoveryController.SignalColor(ping.Signal)
	local transparency = 0.2 + (ping.Band - 1) * 0.12
	part.CFrame = CFrame.lookAt(base + d * 3.2 * pulse, base + d * 6 * pulse)
	part.Color = color
	part.Transparency = transparency
	-- chevron: two arms meeting at the tip, swept back 40 degrees either side
	local tip = base + d * 4.6 * pulse
	for i, arm in arrowHead do
		local sweep = CFrame.Angles(0, math.rad(if i == 1 then 40 else -40), 0):VectorToWorldSpace(-d)
		local centre = tip + sweep * 0.7
		arm.CFrame = CFrame.lookAt(centre, centre + sweep)
		arm.Color = color
		arm.Transparency = transparency
	end
end

-- World FX for tagged find models ---------------------------------------------------------------

local function modelColor(model: Model): Color3
	local rarity = Config.GetRarity(tostring(model:GetAttribute("Rarity") or ""))
	return if rarity then rarity.Color else Color3.new(1, 1, 1)
end

-- Vertical light beam (two attachments + Beam) from the find up into the sky.
local function makeBeam(model: Model, color: Color3, height: number, width: number): Instance?
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not root then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "FindBeam"
	local a0 = Instance.new("Attachment")
	a0.Name = "BeamBottom"
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "BeamTop"
	a1.Position = Vector3.new(0, height, 0)
	a1.Parent = root
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(color, Color3.new(1, 1, 1):Lerp(color, 0.5))
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	beam.Width0 = width
	beam.Width1 = width * 0.4
	beam.LightEmission = 0.8
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Parent = root
	return beam
end

local function settle(model: Model, base: CFrame, rise: number, animate: boolean)
	local target = base + Vector3.new(0, rise, 0)
	if not animate then
		model:PivotTo(target)
		return
	end
	local start = model:GetPivot()
	local value = Instance.new("NumberValue")
	value.Value = 0
	value.Changed:Connect(function()
		local alpha = value.Value
		if model.Parent then
			model:PivotTo(start:Lerp(target, alpha) * CFrame.Angles(0, alpha * math.pi * 2, 0))
		end
	end)
	local tween = TweenService:Create(value, TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Value = 1,
	})
	tween.Completed:Once(function()
		value:Destroy()
	end)
	tween:Play()
end

local function onRevealed(model: Model, base: CFrame, animate: boolean)
	local tier = tostring(model:GetAttribute("Tier") or "Pop")
	local order = Finds.TierOrder(tier)
	local color = modelColor(model)
	local rise = model:GetAttribute("Rise")
	local riseBy = if type(rise) == "number" then rise else 1.5
	local pos = base.Position + Vector3.new(0, riseBy, 0)
	settle(model, base, riseBy, animate)
	if animate then
		EffectsController.Burst(pos, Color3.fromRGB(230, 200, 150), 18 + order * 6, 1 + order * 0.2)
		EffectsController.Chunks(pos, Color3.fromRGB(220, 190, 140), 4 + order)
		SoundController.Play("FindEmerge", 1)
	end
	if order >= Finds.TierOrder("Beam") then
		local server = order >= Finds.TierOrder("Server")
		makeBeam(model, color, if server then 400 else 18, if server then 6 else 2.5)
	end
end

local function watchModel(inst: Instance): Tagged.Cleanup?
	if not inst:IsA("Model") then
		return nil
	end
	local model = inst :: Model
	local id = tostring(model:GetAttribute("FindId") or "")
	if id ~= "" then
		DiscoveryController.Models[id] = model
	end
	local base = model:GetPivot() -- the server's half-buried pivot (owner nudges are local)
	local revealed = false
	local connection: RBXScriptConnection? = nil
	if model:GetAttribute("Stage") == "Revealed" then
		revealed = true
		onRevealed(model, base, false)
	else
		connection = model:GetAttributeChangedSignal("Stage"):Connect(function()
			if not revealed and model:GetAttribute("Stage") == "Revealed" then
				revealed = true
				onRevealed(model, base, true)
			end
		end)
	end
	return function()
		if connection then
			connection:Disconnect()
		end
		if id ~= "" and DiscoveryController.Models[id] == model then
			DiscoveryController.Models[id] = nil
		end
	end
end

-- Owner feedback during the minigame: nudge the (local copy of the) model up a little per hit.
function DiscoveryController.Nudge(id: string, amount: number)
	local model = DiscoveryController.Models[id]
	if model and model.Parent and model:GetAttribute("Stage") ~= "Revealed" then
		model:PivotTo(model:GetPivot() + Vector3.new(0, math.clamp(amount, 0, 0.5), 0))
		EffectsController.Burst(model:GetPivot().Position, Color3.fromRGB(230, 200, 150), 6, 0.7)
	end
end

-- Lifecycle ----------------------------------------------------------------------------------------

local function onExcavationStart(raw: any)
	if type(raw) ~= "table" or type(raw.Id) ~= "string" then
		return
	end
	local info = raw :: Types.ExcavationInfo
	DiscoveryController.Active = info
	if typeof(info.Position) == "Vector3" then
		EffectsController.Burst(info.Position, Color3.fromRGB(230, 200, 150), 14, 1)
		EffectsController.Shake(0.3, 0.2)
	end
	SoundController.Play("RareTreasure", 1.4, 0.7)
	DiscoveryController.ExcavationStarted:Fire(info)
end

local function onFindRevealed(raw: any)
	if type(raw) ~= "table" or type(raw.TreasureId) ~= "string" then
		return
	end
	local info = raw :: Types.FindInfo
	if DiscoveryController.Active and DiscoveryController.Active.Id == info.Id then
		DiscoveryController.Active = nil
	end
	DiscoveryController.FindRevealed:Fire(info)
end

function DiscoveryController.Init()
	if initialized then
		return
	end
	initialized = true
	task.spawn(function()
		Remotes.Get("DetectorPing").OnClientEvent:Connect(DiscoveryController.ApplyPing)
		Remotes.Get("ExcavationStart").OnClientEvent:Connect(onExcavationStart)
		Remotes.Get("FindRevealed").OnClientEvent:Connect(onFindRevealed)
	end)
	Tagged.Watch(TAG, watchModel)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or DiscoveryController.Active then
			return
		end
		if input.KeyCode == Enum.KeyCode.T or input.KeyCode == Enum.KeyCode.ButtonL2 then -- F = place shade, Y = menu focus
			DiscoveryController.Scan()
		end
	end)
	RunService.Heartbeat:Connect(function()
		if State.Loaded then
			updateWorld()
		end
	end)
	Players.LocalPlayer.CharacterRemoving:Connect(hideArrow)
end

return DiscoveryController
