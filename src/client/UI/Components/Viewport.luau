--!strict
--[[
	Viewport — ViewportFrame that frames a Model nicely (auto camera distance from its bounding
	box), optional slow spin, optional silhouette (undiscovered index entries).
	The spin connection is cleaned up automatically when the frame is destroyed or hidden.
]]
local RunService = game:GetService("RunService")

local Viewport = {}

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
	Distance: number?, -- camera distance multiplier (1 = snug fit)
	Pitch: number?, -- degrees the camera looks down
}

export type Viewport = {
	Frame: ViewportFrame,
	Model: Model?,
	SetModel: (self: Viewport, model: Model?) -> (),
	SetSilhouette: (self: Viewport, on: boolean) -> (),
	SetSpin: (self: Viewport, on: boolean) -> (),
}

function Viewport.new(props: ViewportProps): Viewport
	local frame = Instance.new("ViewportFrame")
	frame.Name = props.Name or "Viewport"
	frame.BackgroundTransparency = 1
	frame.Size = props.Size or UDim2.fromOffset(120, 120)
	frame.Position = props.Position or UDim2.new()
	frame.AnchorPoint = props.AnchorPoint or Vector2.zero
	frame.LayoutOrder = props.LayoutOrder or 0
	frame.ZIndex = props.ZIndex or 1
	frame.Ambient = Color3.fromRGB(190, 190, 200)
	frame.LightColor = Color3.fromRGB(255, 250, 235)
	frame.LightDirection = Vector3.new(-1, -1.4, -0.8)

	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	camera.Parent = frame
	frame.CurrentCamera = camera

	local spinOn = props.Spin == true
	local angle = 0
	local center = CFrame.new()
	local spinConnection: RBXScriptConnection? = nil

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
				if frame.Visible then
					angle += dt * (props.SpinSpeed or 1.2)
					model:PivotTo(CFrame.Angles(0, angle, 0) * center)
				end
			else
				stopSpin()
			end
		end)
	end

	vp = {
		Frame = frame,
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
			model:PivotTo(CFrame.new())
			local boxCFrame, size = model:GetBoundingBox()
			-- recentre so the bounding box middle sits at the origin
			local offset = boxCFrame.Position
			center = CFrame.new(-offset)
			model:PivotTo(center)
			angle = 0
			model.Parent = frame
			local radius = math.max(size.Magnitude / 2, 0.5)
			local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * (props.Distance or 1.05)
			local pitch = math.rad(props.Pitch or 15)
			local eye = Vector3.new(0, math.sin(pitch), math.cos(pitch)) * distance
			camera.CFrame = CFrame.lookAt(eye, Vector3.zero)
			startSpin()
		end,
		SetSilhouette = function(_: Viewport, on: boolean)
			frame.ImageColor3 = if on then Color3.new(0, 0, 0) else Color3.new(1, 1, 1)
			frame.ImageTransparency = if on then 0.35 else 0
		end,
		SetSpin = function(_: Viewport, on: boolean)
			spinOn = on
			if on then
				startSpin()
			else
				stopSpin()
			end
		end,
	}

	if props.Silhouette then
		vp:SetSilhouette(true)
	end
	frame.Destroying:Connect(stopSpin)
	if props.Parent then
		frame.Parent = props.Parent
	end
	return vp
end

return Viewport
