--!strict
--[[
	GuideController — one glowing Beam from the character to a world target plus a bouncing
	billboard marker over it. Several systems can request a guide (tutorial, "backpack full",
	"too hard"); the highest priority request wins.

		Guide.Set("Tutorial", target, 10, "⬇️")   -- target: BasePart | Vector3 | TagTarget | nil
		Guide.Clear("Tutorial")

	v2.3 streaming: stations far away are not on the client. FindTagged(tag) returns a TagTarget
	({ Tag = tag }) that is resolved EVERY FRAME: the nearest streamed-in part with the tag if
	there is one, else the nearest server-published anchor position (Util/Anchors). So a beam
	from the bottom of a hole to the sell stand still points the right way, and it locks onto the
	real part as soon as it streams in (a new instance after every stream-out). A BasePart target
	that streams out falls back to its last known position.
]]
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Character = require(script.Parent.Parent.Util.Character)
local Tagged = require(script.Parent.Parent.Util.Tagged)
local Anchors = require(script.Parent.Parent.Util.Anchors)
local State = require(script.Parent.State)

local GuideController = {}

export type TagTarget = { Tag: string }
export type Target = BasePart | Vector3 | TagTarget

type Request = { Target: Target, Priority: number, Marker: string, Expires: number?, LastPosition: Vector3? }

local requests: { [string]: Request } = {}
local beam: Beam? = nil
local fromAttachment: Attachment? = nil
local toAttachment: Attachment? = nil
local marker: BillboardGui? = nil
local markerLabel: TextLabel? = nil
local activeKey: string? = nil

local function partTop(part: BasePart): Vector3
	return part.Position + Vector3.new(0, part.Size.Y / 2, 0)
end

-- World position of a target right now (nil = nothing known). `from` picks the nearest of many.
function GuideController.Resolve(target: Target, from: Vector3?): Vector3?
	if typeof(target) == "Vector3" then
		return target
	end
	if typeof(target) == "Instance" then
		local part = target :: BasePart
		return if part:IsDescendantOf(Workspace) then partTop(part) else nil
	end
	local tag = (target :: TagTarget).Tag
	local part = Tagged.Nearest(tag, from)
	local anchor = Anchors.Nearest(tag, from)
	if part and anchor and from then
		-- a nearer station may exist that has not streamed in: prefer the nearer of the two
		local top = partTop(part)
		return if (anchor - from).Magnitude + 1 < (top - from).Magnitude then anchor else top
	end
	return if part then partTop(part) else anchor
end

-- A guide target for the nearest station carrying `tag` (streamed in or not), or nil when the
-- tag exists nowhere (no streamed part and no published anchor).
function GuideController.FindTagged(tag: string, from: Vector3?): Target?
	if Tagged.Nearest(tag, from) or Anchors.Nearest(tag, from) then
		return { Tag = tag } :: TagTarget
	end
	return nil
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
		local maybePosition: Vector3? = nil
		if found then
			maybePosition = GuideController.Resolve(found.Target, if maybeRoot then maybeRoot.Position else nil)
				or found.LastPosition -- a part target streamed out: keep its last known spot
			found.LastPosition = maybePosition
		end
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
		local reducedMotion = State.GetSetting("ReducedMotion", false) == true
		if marker then
			local bounce = if reducedMotion then 0 else math.abs(math.sin(t * 4)) * 1.5
			marker.StudsOffsetWorldSpace = Vector3.new(0, 4 + bounce, 0)
		end
		-- At the target the objective is enough; the billboard otherwise covers
		-- the player's head/tool in the normal over-the-shoulder spawn camera.
		local away = (root.Position - position).Magnitude > 8
		if marker then
			marker.Enabled = away
		end
		if beam then
			beam.TextureSpeed = if reducedMotion then 0 else 2
			beam.Enabled = away
		end
	end)
end

return GuideController
