--!strict
--[[
	EffectsController — world-space juice: layer-coloured sand bursts, flying sand chunks,
	floating "+12 Sand" billboards and a small camera shake. All instances are client-only
	and cleaned up with Debris. LowGraphics setting trims particle counts and skips chunks.
]]
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local State = require(script.Parent.State)

local EffectsController = {}

local PARTICLE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local shakeIntensity = 0
local shakeUntil = 0
local shakeDuration = 0.001
local effectsFolder: Folder? = nil

local function lowGraphics(): boolean
	return State.GetSetting("LowGraphics", false) == true
end

local function getFolder(): Folder
	if not effectsFolder or not effectsFolder.Parent then
		local folder = Instance.new("Folder")
		folder.Name = "ClientEffects"
		folder.Parent = Workspace
		effectsFolder = folder
	end
	return effectsFolder :: Folder
end

local function anchorAttachment(position: Vector3, lifetime: number): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = "FX"
	attachment.WorldPosition = position
	attachment.Parent = Workspace.Terrain
	attachment.WorldPosition = position
	Debris:AddItem(attachment, lifetime)
	return attachment
end

-- Sand puff in the colour of the layer that was dug.
function EffectsController.Burst(position: Vector3, color: Color3, count: number?, size: number?)
	local amount = count or 14
	if lowGraphics() then
		amount = math.max(3, math.floor(amount / 3))
	end
	local attachment = anchorAttachment(position, 2)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = PARTICLE_TEXTURE
	emitter.Color = ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.25))
	local s = size or 1
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9 * s),
		NumberSequenceKeypoint.new(0.4, 1.3 * s),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.7, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.45, 0.85)
	emitter.Speed = NumberRange.new(9, 16)
	emitter.SpreadAngle = Vector2.new(55, 55)
	emitter.Acceleration = Vector3.new(0, -35, 0)
	emitter.Drag = 2.5
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.RotSpeed = NumberRange.new(-120, 120)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.LightEmission = 0.1
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(amount)
end

-- Little cubes of sand flung out of the hole (pure client physics, no collisions with players).
function EffectsController.Chunks(position: Vector3, color: Color3, count: number?)
	if lowGraphics() then
		return
	end
	local folder = getFolder()
	for _ = 1, count or 4 do
		local part = Instance.new("Part")
		part.Name = "SandChunk"
		local size = 0.35 + math.random() * 0.4
		part.Size = Vector3.new(size, size, size)
		part.Color = color:Lerp(Color3.new(0, 0, 0), math.random() * 0.15)
		part.Material = Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0))
			* CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		part.Parent = folder
		local angle = math.random() * math.pi * 2
		part.AssemblyLinearVelocity = Vector3.new(math.cos(angle) * 9, 18 + math.random() * 10, math.sin(angle) * 9)
		part.AssemblyAngularVelocity = Vector3.new(math.random() * 10, math.random() * 10, math.random() * 10)
		TweenService:Create(part, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.2), {
			Size = Vector3.new(0.05, 0.05, 0.05),
		}):Play()
		Debris:AddItem(part, 1)
	end
end

-- Floating billboard text that rises and fades ("+12 Sand", "Too hard!").
function EffectsController.FloatText(position: Vector3, text: string, color: Color3, scale: number?)
	local attachment = anchorAttachment(position, 2)
	local s = scale or 1
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(5 * s, 1.6 * s)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 1.5, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 120
	billboard.Adornee = attachment
	billboard.Parent = attachment

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.fromRGB(35, 30, 60)
	label.TextStrokeTransparency = 0
	label.Parent = billboard
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(35, 30, 60)
	stroke.Parent = label

	local pop = Instance.new("UIScale")
	pop.Scale = 0.3
	pop.Parent = label
	TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local drift = Vector3.new((math.random() - 0.5) * 1.5, 4.5, 0)
	TweenService:Create(
		billboard,
		TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffsetWorldSpace = billboard.StudsOffsetWorldSpace + drift }
	):Play()
	TweenService:Create(
		label,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.75),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	):Play()
	TweenService:Create(stroke, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.75), {
		Transparency = 1,
	}):Play()
end

-- Small, decaying camera shake (stacks by taking the max intensity).
function EffectsController.Shake(intensity: number, duration: number)
	if State.GetSetting("ReducedMotion", false) == true then
		return
	end
	local now = os.clock()
	if now > shakeUntil then
		shakeIntensity = 0
	end
	shakeIntensity = math.max(shakeIntensity, intensity)
	shakeDuration = math.max(duration, 0.001)
	shakeUntil = math.max(shakeUntil, now + duration)
end

function EffectsController.Init()
	RunService:BindToRenderStep("DigCameraShake", Enum.RenderPriority.Camera.Value + 1, function()
		if State.GetSetting("ReducedMotion", false) == true then
			shakeIntensity = 0
			return
		end
		local now = os.clock()
		if now >= shakeUntil or shakeIntensity <= 0 then
			return
		end
		local camera = Workspace.CurrentCamera
		if camera then
			local fade = math.clamp((shakeUntil - now) / shakeDuration, 0, 1)
			local mag = shakeIntensity * fade
			local offset = Vector3.new((math.random() - 0.5) * mag, (math.random() - 0.5) * mag, 0)
			camera.CFrame = camera.CFrame
				* CFrame.new(offset)
				* CFrame.Angles(0, 0, math.rad((math.random() - 0.5) * mag * 4))
		end
	end)
end

return EffectsController
