--!strict
--[[
	Viewport — ViewportFrame that frames any Model so it fills ~75% of the frame, from a nice
	three-quarter angle in FRONT of the model (models face -Z, see Shared.Models), optional slow
	spin, optional silhouette (undiscovered index entries).
	The spin connection is cleaned up automatically when the frame is destroyed.

	Framing (Viewport.Fit): only VISIBLE parts count (invisible "Root"/hitbox parts are ignored).
	The model is recentred so its visible bounding-box centre sits at the origin, then every
	corner of every visible part is projected into camera space and the camera distance is the
	smallest D for which all corners fit inside `Fill` of both the vertical and the horizontal
	field of view:  D >= depth + |x| / (tan(hfov/2) * Fill)  and  D >= depth + |y| / (tan(vfov/2) * Fill).
	(For a sphere this is the classic distance = radius / sin(fov/2) with a margin; corner
	projection is tighter for long or flat models such as shovels, coins and backpacks.)
	When spinning, corners are tested at 8 yaw angles so the model never clips mid-turn.

	API (other agents: use this for shop / garage cards):
	  local vp = Viewport.new({ Size = UDim2.fromScale(1, 1), Parent = cardPreview,
	                            Spin = false, Fill = 0.75, Yaw = 25, Pitch = 15, ZIndex = 4 })
	  vp:SetModel(Models.Digger(id))   -- takes ownership; the previous model is destroyed
	  vp:SetSpin(true) / vp:SetSilhouette(true) / vp:Refit()
	  Viewport.Fit(camera, model, { Fill?, Yaw?, Pitch?, Spin?, Aspect?, Rotation? }) -- low-level
	    for your own ViewportFrame: recentres `model` at the origin and points `camera` at it.
	  The frame refits itself when its AbsoluteSize (aspect ratio) changes.
]]
local RunService = game:GetService("RunService")
local State = require(script.Parent.Parent.Parent.Controllers.State)

local Viewport = {}

local DEFAULT_FILL = 0.75
local DEFAULT_YAW = 25 -- degrees: camera swings to the model's front-right
local DEFAULT_PITCH = 15 -- degrees the camera looks down
local FOV = 30

export type FitOptions = {
	Fill: number?, -- fraction of the frame the model should cover (0..1)
	Yaw: number?, -- degrees
	Pitch: number?, -- degrees
	Spin: boolean?, -- fit for every yaw (model spins about Y)
	Aspect: number?, -- frame width / height (default 1)
	Rotation: CFrame?, -- extra model rotation before framing (e.g. tilt a shovel diagonally)
}

export type ViewportProps = {
	Name: string?,
	Parent: Instance?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	ZIndex: number?,
	Spin: boolean?,
	SpinSpeed: number?, -- radians/sec
	Silhouette: boolean?,
	Fill: number?, -- default 0.75
	Distance: number?, -- legacy: extra camera distance multiplier (1 = exact fit)
	Yaw: number?, -- degrees, default 25
	Pitch: number?, -- degrees the camera looks down, default 15
	Rotation: CFrame?, -- extra model rotation (e.g. CFrame.Angles(0, 0, math.rad(-40)))
}

export type Viewport = {
	Frame: ViewportFrame,
	Camera: Camera,
	Model: Model?,
	SetModel: (self: Viewport, model: Model?) -> (),
	SetSilhouette: (self: Viewport, on: boolean) -> (),
	SetSpin: (self: Viewport, on: boolean) -> (),
	Refit: (self: Viewport) -> (),
}

local function visibleCorners(model: Model): { Vector3 }
	local points = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.98 then
			local cf = d.CFrame
			local h = d.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						table.insert(points, cf:PointToWorldSpace(Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)))
					end
				end
			end
		end
	end
	return points
end

-- Recentres `model` (pivoted upright at the origin) on its visible bounds and frames it.
-- Returns the CFrame the model was pivoted to (the spin centre).
function Viewport.Fit(camera: Camera, model: Model, options: FitOptions?): CFrame
	local opts: FitOptions = options or {}
	local rotation = if opts.Rotation then opts.Rotation.Rotation else CFrame.identity
	model:PivotTo(rotation)
	local points = visibleCorners(model)
	if #points == 0 then
		local boxCf, size = model:GetBoundingBox()
		local h = size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					table.insert(points, boxCf:PointToWorldSpace(Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)))
				end
			end
		end
	end
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = -minV
	for _, p in points do
		minV = minV:Min(p)
		maxV = maxV:Max(p)
	end
	local centre = (minV + maxV) / 2
	local pivot = CFrame.new(-centre) * rotation
	model:PivotTo(pivot)

	local fill = math.clamp(opts.Fill or DEFAULT_FILL, 0.2, 1)
	local yaw = math.rad(opts.Yaw or DEFAULT_YAW)
	local pitch = math.rad(opts.Pitch or DEFAULT_PITCH)
	local aspect = math.max(opts.Aspect or 1, 0.1)
	-- Camera sits in front of the model (models face -Z), swung by yaw, raised by pitch.
	local dir = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch))
	local look = CFrame.lookAt(dir, Vector3.zero) -- rotation only matters
	local right, up, back = look.RightVector, look.UpVector, -look.LookVector

	camera.FieldOfView = FOV
	local tanV = math.tan(math.rad(FOV / 2)) * fill
	local tanH = tanV * aspect

	local angles = if opts.Spin then 8 else 1
	local distance = 0.5
	for i = 0, angles - 1 do
		local spin = CFrame.Angles(0, i * 2 * math.pi / angles, 0)
		for _, p in points do
			local q = spin * (p - centre)
			local x, y, z = q:Dot(right), q:Dot(up), q:Dot(back)
			distance = math.max(distance, z + math.abs(x) / tanH, z + math.abs(y) / tanV, z + 0.5)
		end
	end
	camera.CFrame = CFrame.lookAt(back * distance, Vector3.zero)
	return pivot
end

function Viewport.new(props: ViewportProps): Viewport
	local frame = Instance.new("ViewportFrame")
	frame.Name = props.Name or "Viewport"
	frame.BackgroundTransparency = 1
	frame.Size = props.Size or UDim2.fromOffset(120, 120)
	frame.Position = props.Position or UDim2.new()
	frame.AnchorPoint = props.AnchorPoint or Vector2.zero
	frame.LayoutOrder = props.LayoutOrder or 0
	frame.ZIndex = props.ZIndex or 1
	-- Soft, even lighting: bright enough to read colours, no blown-out highlights.
	frame.Ambient = Color3.fromRGB(165, 165, 175)
	frame.LightColor = Color3.fromRGB(235, 230, 220)
	frame.LightDirection = Vector3.new(-0.6, -1, 0.8) -- from the camera side (front, -Z)

	local camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	camera.Parent = frame
	frame.CurrentCamera = camera

	local spinOn = props.Spin == true
	local angle = 0
	local center = CFrame.new()
	local spinConnection: RBXScriptConnection? = nil
	local lastAspect = 1

	local vp: Viewport

	local function stopSpin()
		if spinConnection then
			spinConnection:Disconnect()
			spinConnection = nil
		end
	end

	local function startSpin()
		stopSpin()
		if not spinOn or not vp.Model then
			return
		end
		spinConnection = RunService.RenderStepped:Connect(function(dt: number)
			local model = vp.Model
			if model and frame.Parent then
				local visible = frame.Visible and State.GetSetting("ReducedMotion", false) ~= true
				local ancestor: Instance? = frame.Parent
				while visible and ancestor do
					if ancestor:IsA("GuiObject") and not ancestor.Visible then
						visible = false
					elseif ancestor:IsA("ScreenGui") and not ancestor.Enabled then
						visible = false
					end
					ancestor = ancestor.Parent
				end
				if visible then
					angle += dt * (props.SpinSpeed or 1.2)
					model:PivotTo(CFrame.Angles(0, angle, 0) * center)
				end
			else
				stopSpin()
			end
		end)
	end

	local function aspectOf(): number
		local size = frame.AbsoluteSize
		if size.X > 1 and size.Y > 1 then
			return size.X / size.Y
		end
		return 1
	end

	local function fit()
		local current = vp.Model
		if not current then
			return
		end
		local model = current :: Model
		lastAspect = aspectOf()
		center = Viewport.Fit(camera, model, {
			Fill = (props.Fill or DEFAULT_FILL) / (props.Distance or 1),
			Yaw = props.Yaw,
			Pitch = props.Pitch,
			Spin = spinOn,
			Aspect = lastAspect,
			Rotation = props.Rotation,
		})
		if spinOn then
			model:PivotTo(CFrame.Angles(0, angle, 0) * center)
		end
	end

	vp = {
		Frame = frame,
		Camera = camera,
		Model = nil,
		SetModel = function(self: Viewport, newModel: Model?)
			if self.Model then
				(self.Model :: Model):Destroy()
			end
			self.Model = newModel
			if not newModel then
				stopSpin()
				return
			end
			local model = newModel :: Model
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
				elseif d:IsA("Script") or d:IsA("LocalScript") then
					d:Destroy()
				end
			end
			angle = 0
			fit()
			model.Parent = frame
			startSpin()
		end,
		SetSilhouette = function(_: Viewport, on: boolean)
			frame.ImageColor3 = if on then Color3.new(0, 0, 0) else Color3.new(1, 1, 1)
			frame.ImageTransparency = if on then 0.35 else 0
		end,
		SetSpin = function(_: Viewport, on: boolean)
			if on ~= spinOn then
				spinOn = on
				fit() -- spinning needs room for every yaw
			end
			if on then
				startSpin()
			else
				stopSpin()
			end
		end,
		Refit = function(_: Viewport)
			fit()
		end,
	}

	if props.Silhouette then
		vp:SetSilhouette(true)
	end
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if vp.Model and math.abs(aspectOf() - lastAspect) > 0.05 then
			fit()
		end
	end)
	frame.Destroying:Connect(stopSpin)
	if props.Parent then
		frame.Parent = props.Parent
	end
	return vp
end

return Viewport
