--!strict
--[[
	GuideController — one glowing Beam from the character to a world target plus a bouncing
	billboard marker over it. Several systems can request a guide (tutorial, "backpack full",
	"too hard"); the highest priority request wins.

		Guide.Set("Tutorial", target, 10, "Arrow")   -- target: BasePart | Vector3 | TagTarget | nil
		Guide.Clear("Tutorial")

	v2.3 streaming: stations far away are not on the client. FindTagged(tag) returns a TagTarget
	({ Tag = tag }) that is resolved EVERY FRAME: the nearest streamed-in part with the tag if
	there is one, else the nearest server-published anchor position (Util/Anchors). So a beam
	from the bottom of a hole to the sell stand still points the right way, and it locks onto the
	real part as soon as it streams in (a new instance after every stream-out). A BasePart target
	that streams out falls back to its last known position.

	Off-screen: when the target is outside the camera view (or behind it) an arrow badge pinned
	to the screen edge points the way, carrying the same marker icon. Markers are icon keys for
	AtlasIcon ("Coins", "Arrow", "pickaxe|🛠️"), never emoji in a TextScaled label.
	TurnCameraToward(target) is an onboarding-only nudge (the tutorial calls it): one smooth
	camera swing around the character when the target is far off-screen.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Character = require(script.Parent.Parent.Util.Character)
local Tagged = require(script.Parent.Parent.Util.Tagged)
local Anchors = require(script.Parent.Parent.Util.Anchors)
local State = require(script.Parent.State)
local AtlasIcon = require(script.Parent.Parent.UI.Components.AtlasIcon)
local Root = require(script.Parent.Parent.UI.Root)

local GuideController = {}

export type TagTarget = { Tag: string }
export type Target = BasePart | Vector3 | TagTarget

type Request = { Target: Target, Priority: number, Marker: string, Expires: number?, LastPosition: Vector3? }

local requests: { [string]: Request } = {}
local beam: Beam? = nil
local fromAttachment: Attachment? = nil
local toAttachment: Attachment? = nil
local marker: BillboardGui? = nil
local markerIcon: AtlasIcon.AtlasIcon? = nil
local activeKey: string? = nil

-- Screen-edge indicator (own ScreenGui: IgnoreGuiInset so it shares the camera's viewport space).
local EDGE_SIZE = 64 -- design px, scaled with the HUD
local EDGE_MARGIN = 56 -- design px kept clear of the screen edge
local edgeGui: ScreenGui? = nil
local edgeFrame: Frame? = nil
local edgeArrow: Frame? = nil
local edgeIcon: AtlasIcon.AtlasIcon? = nil

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
	local icon = AtlasIcon.new({ Icon = "Arrow", Name = "MarkerIcon", Parent = billboard })

	beam = b
	fromAttachment = a0
	toAttachment = a1
	marker = billboard
	markerIcon = icon
end

local function ensureEdge(): Frame?
	if edgeFrame and edgeGui and edgeGui.Parent then
		return edgeFrame
	end
	local playerGui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return nil
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "Dig_GuideEdge"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 2 -- above the HUD, below panels and popups

	local frame = Instance.new("Frame")
	frame.Name = "EdgeArrow"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = Color3.fromRGB(29, 42, 68)
	frame.BackgroundTransparency = 0.15
	frame.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 205, 40)
	stroke.Thickness = 3
	stroke.Parent = frame
	frame.Parent = gui

	edgeIcon =
		AtlasIcon.new({ Icon = "Arrow", Name = "MarkerIcon", Size = UDim2.fromScale(0.62, 0.62), Parent = frame })
	-- The pointer sits outside the badge on the side of the target; Rotation 0 = pointing down.
	edgeArrow = AtlasIcon.new({
		Icon = "Arrow",
		Name = "Pointer",
		Size = UDim2.fromScale(0.55, 0.55),
		ZIndex = 2,
		Parent = frame,
	}).Frame

	gui.Parent = playerGui
	edgeGui = gui
	edgeFrame = frame
	return frame
end

--[[
	Where the edge indicator goes. `rel` is the target in camera space (camera looks down -Z),
	`point` its WorldToViewportPoint result and `size` the viewport. Returns onScreen, the
	indicator centre (viewport px, inset by `margin` from every edge) and its rotation in degrees
	(0 = pointing down the screen). Behind the camera the projected point is meaningless, so the
	camera-space direction is used instead (behind and to the right -> arrow on the right).
]]
function GuideController.EdgePlacement(
	rel: Vector3,
	point: Vector3,
	size: Vector2,
	margin: number
): (boolean, Vector2, number)
	local inFront = rel.Z < 0
	if inFront and point.X >= 0 and point.X <= size.X and point.Y >= 0 and point.Y <= size.Y then
		return true, Vector2.new(point.X, point.Y), 0
	end
	local centre = size / 2
	local direction = if inFront then Vector2.new(point.X, point.Y) - centre else Vector2.new(rel.X, -rel.Y)
	if direction.Magnitude < 1e-3 then
		direction = Vector2.new(0, 1) -- straight behind: point down, "turn around"
	end
	local halfX = math.max(centre.X - margin, 1)
	local halfY = math.max(centre.Y - margin, 1)
	local scaleX = if math.abs(direction.X) > 1e-6 then halfX / math.abs(direction.X) else math.huge
	local scaleY = if math.abs(direction.Y) > 1e-6 then halfY / math.abs(direction.Y) else math.huge
	local position = centre + direction * math.min(scaleX, scaleY)
	local rotation = math.deg(math.atan2(direction.Y, direction.X)) - 90
	return false, position, rotation
end

--[[
	Signed horizontal angle (degrees) from the camera's flat look direction to `target` seen
	from `focus`; positive turns right (clockwise from above). nil when either is degenerate.
]]
function GuideController.YawToward(look: Vector3, focus: Vector3, target: Vector3): number?
	local flatLook = Vector3.new(look.X, 0, look.Z)
	local flatTarget = Vector3.new(target.X - focus.X, 0, target.Z - focus.Z)
	if flatLook.Magnitude < 1e-3 or flatTarget.Magnitude < 1 then
		return nil
	end
	local a, b = flatLook.Unit, flatTarget.Unit
	local cross = a.X * b.Z - a.Z * b.X -- > 0: target is to the right (camera right = look x up)
	return math.deg(math.atan2(cross, a:Dot(b)))
end

local TURN_MIN_DEGREES = 60 -- roughly on screen already: leave the camera alone
local TURN_SECONDS = 0.7
local turning = false

--[[
	Onboarding helper: when `target` is well off-screen, swing the default (Custom) camera around
	the character to face it once, so a full bucket does not leave a newcomer looking at the sea
	with the sell stand behind them. Composes with the player's own camera input (small per-frame
	yaw steps) and is instant with Reduced Motion. Returns true when a turn started.
]]
function GuideController.TurnCameraToward(target: Target): boolean
	local camera = Workspace.CurrentCamera
	local root = Character.GetRoot()
	if turning or not camera or not root or camera.CameraType ~= Enum.CameraType.Custom then
		return false
	end
	local position = GuideController.Resolve(target, root.Position)
	if not position then
		return false
	end
	local focus = root.Position
	local maybeYaw = GuideController.YawToward(camera.CFrame.LookVector, focus, position)
	if not maybeYaw or math.abs(maybeYaw) < TURN_MIN_DEGREES then
		return false
	end
	local yaw = maybeYaw :: number
	local function rotate(degrees: number)
		local cam = Workspace.CurrentCamera
		local maybeRoot = Character.GetRoot()
		if not cam or not maybeRoot then
			return
		end
		local pivot = maybeRoot.Position
		-- a positive yaw turns right = clockwise from above = negative rotation about +Y
		cam.CFrame = CFrame.new(pivot) * CFrame.Angles(0, -math.rad(degrees), 0) * CFrame.new(-pivot) * cam.CFrame
	end
	if State.GetSetting("ReducedMotion", false) == true then
		rotate(yaw)
		return true
	end
	turning = true
	local total = yaw
	local progress = 0
	local applied = 0
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function(dt: number)
		progress = math.min(progress + dt / TURN_SECONDS, 1)
		local eased = 1 - (1 - progress) ^ 2 -- ease out
		rotate(total * eased - applied)
		applied = total * eased
		if progress >= 1 then
			turning = false
			if connection then
				connection:Disconnect()
			end
		end
	end)
	return true
end

local function hideEdge()
	if edgeFrame then
		edgeFrame.Visible = false
	end
end

local function updateEdge(position: Vector3, request: Request, t: number, reducedMotion: boolean)
	local camera = Workspace.CurrentCamera
	if not camera then
		hideEdge()
		return
	end
	local frame = ensureEdge()
	if not frame then
		return
	end
	local size = camera.ViewportSize
	local scale = if Root.Scale and Root.Scale > 0 then Root.Scale else 1
	local rel = camera.CFrame:PointToObjectSpace(position)
	local point = camera:WorldToViewportPoint(position)
	local onScreen, at, rotation = GuideController.EdgePlacement(rel, point, size, EDGE_MARGIN * scale)
	if onScreen then
		frame.Visible = false
		return
	end
	local pulse = if reducedMotion then 1 else 1 + 0.08 * math.sin(t * 5)
	local px = EDGE_SIZE * scale * pulse
	frame.Size = UDim2.fromOffset(px, px)
	frame.Position = UDim2.fromOffset(at.X, at.Y)
	frame.Visible = true
	if edgeIcon and edgeIcon.Key ~= request.Marker then
		edgeIcon:Set(request.Marker)
	end
	if edgeArrow then
		local angle = math.rad(rotation + 90)
		local offset = Vector2.new(math.cos(angle), math.sin(angle)) * 0.62
		edgeArrow.Position = UDim2.fromScale(0.5 + offset.X, 0.5 + offset.Y)
		edgeArrow.Rotation = rotation
	end
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
		Marker = markerText or "Arrow",
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
			hideEdge()
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
		if markerIcon and key ~= activeKey then
			markerIcon:Set(request.Marker)
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
		if away then
			updateEdge(position, request, t, reducedMotion)
		else
			hideEdge()
		end
	end)
end

return GuideController
