--!strict
--[[
	GuideController — one glowing Beam from the character to a world target plus a bouncing
	billboard marker over it. Several systems can request a guide (tutorial, "backpack full",
	"too hard"); the highest priority request wins.

		Guide.Set("Tutorial", target, 10, "⬇️")   -- target: BasePart | Vector3 | nil
		Guide.Clear("Tutorial")
]]
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Character = require(script.Parent.Parent.Util.Character)

local GuideController = {}

export type Target = BasePart | Vector3

type Request = { Target: Target, Priority: number, Marker: string, Expires: number? }

local requests: { [string]: Request } = {}
local beam: Beam? = nil
local fromAttachment: Attachment? = nil
local toAttachment: Attachment? = nil
local marker: BillboardGui? = nil
local markerLabel: TextLabel? = nil
local activeKey: string? = nil

local function targetPosition(target: Target): Vector3?
	if typeof(target) == "Vector3" then
		return target
	end
	local part = target :: BasePart
	if part.Parent then
		return part.Position + Vector3.new(0, part.Size.Y / 2, 0)
	end
	return nil
end

-- Nearest BasePart carrying `tag` (or inside a tagged Model) to `from`.
function GuideController.FindTagged(tag: string, from: Vector3?): BasePart?
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, inst in CollectionService:GetTagged(tag) do
		local part: BasePart? = nil
		if inst:IsA("BasePart") then
			part = inst
		elseif inst:IsA("Model") then
			part = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
		end
		if part then
			local distance = if from then (part.Position - from).Magnitude else 0
			if distance < bestDistance then
				best = part
				bestDistance = distance
			end
		end
	end
	return best
end

local function ensureVisuals()
	if beam and beam.Parent then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "GuideFrom"
	local a1 = Instance.new("Attachment")
	a1.Name = "GuideTo"
	a1.Parent = Workspace.Terrain
	local b = Instance.new("Beam")
	b.Name = "GuideBeam"
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.FaceCamera = true
	b.Width0 = 1.2
	b.Width1 = 1.2
	b.LightEmission = 0.6
	b.LightInfluence = 0
	b.Segments = 20
	b.CurveSize0 = 0
	b.CurveSize1 = 0
	b.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	b.TextureMode = Enum.TextureMode.Wrap
	b.TextureLength = 3
	b.TextureSpeed = 2
	b.Color = ColorSequence.new(Color3.fromRGB(255, 225, 60), Color3.fromRGB(255, 95, 125))
	b.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.15, 0.1),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	b.Parent = Workspace.Terrain

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "GuideMarker"
	billboard.Size = UDim2.fromOffset(90, 90)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	billboard.Adornee = a1
	billboard.Parent = a1
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Text = "⬇️"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = billboard

	beam = b
	fromAttachment = a0
	toAttachment = a1
	marker = billboard
	markerLabel = label
end

local function setVisible(visible: boolean)
	if beam then
		beam.Enabled = visible
	end
	if marker then
		marker.Enabled = visible
	end
end

local function pickActive(): (string?, Request?)
	local bestKey: string? = nil
	local best: Request? = nil
	local now = os.clock()
	for key, request in requests do
		if request.Expires and now > request.Expires then
			requests[key] = nil
		elseif not best or request.Priority > (best :: Request).Priority then
			best = request
			bestKey = key
		end
	end
	return bestKey, best
end

function GuideController.Set(key: string, target: Target?, priority: number?, markerText: string?, seconds: number?)
	if target == nil then
		requests[key] = nil
		return
	end
	requests[key] = {
		Target = target :: Target,
		Priority = priority or 0,
		Marker = markerText or "⬇️",
		Expires = if seconds then os.clock() + seconds else nil,
	}
end

function GuideController.Clear(key: string)
	requests[key] = nil
end

function GuideController.Init()
	local t = 0
	RunService.Heartbeat:Connect(function(dt: number)
		t += dt
		local key, found = pickActive()
		local maybeRoot = Character.GetRoot()
		local maybePosition = if found then targetPosition(found.Target) else nil
		if not (found and maybeRoot and maybePosition) then
			setVisible(false)
			activeKey = nil
			return
		end
		local request = found :: Request
		local root = maybeRoot :: BasePart
		local position = maybePosition :: Vector3
		ensureVisuals()
		setVisible(true)
		local current = fromAttachment
		if current and current.Parent ~= root then
			-- The old one was destroyed with the previous character (its Parent is locked):
			-- give the beam a fresh attachment on the new root.
			current:Destroy()
			local a0 = Instance.new("Attachment")
			a0.Name = "GuideFrom"
			a0.Position = Vector3.new(0, -1.5, 0)
			a0.Parent = root
			fromAttachment = a0
			if beam then
				beam.Attachment0 = a0
			end
		end
		if toAttachment then
			toAttachment.WorldPosition = position
		end
		if markerLabel and key ~= activeKey then
			markerLabel.Text = request.Marker
		end
		activeKey = key
		if marker then
			marker.StudsOffsetWorldSpace = Vector3.new(0, 4 + math.abs(math.sin(t * 4)) * 1.5, 0)
		end
		-- hide the beam when standing on the target (marker stays)
		if beam then
			beam.Enabled = (root.Position - position).Magnitude > 8
		end
	end)
end

return GuideController
