--!strict
--[[
	Util — small builders shared by the World modules: anchored parts, signs with SurfaceGuis,
	proximity prompts, tags and Models.Prop placement (pcall-guarded so a broken/missing model
	never stops the map from building).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Models = require(ReplicatedStorage.Shared.Models)

local Theme = Config.Theme

local Util = {}

export type PartProps = {
	Name: string?,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3?,
	Material: Enum.Material?,
	Shape: Enum.PartType?,
	Transparency: number?,
	Reflectance: number?,
	-- Collision: default true. Decorative = no collide, no query, no touch, no shadow.
	CanCollide: boolean?,
	Decor: boolean?,
	CastShadow: boolean?,
	Parent: Instance?,
}

local function apply(p: BasePart, props: PartProps)
	p.Name = props.Name or p.ClassName
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = props.Size
	p.CFrame = props.CFrame
	p.Color = props.Color or Color3.new(1, 1, 1)
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Transparency = props.Transparency or 0
	p.Reflectance = props.Reflectance or 0
	if props.Decor then
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
	else
		p.CanCollide = props.CanCollide ~= false
		p.CanTouch = false
	end
	if props.CastShadow ~= nil then
		p.CastShadow = props.CastShadow
	end
	p.Parent = props.Parent
end

function Util.Part(props: PartProps): Part
	local p = Instance.new("Part")
	if props.Shape then
		p.Shape = props.Shape
	end
	apply(p, props)
	return p
end

function Util.Wedge(props: PartProps): WedgePart
	local p = Instance.new("WedgePart")
	apply(p, props)
	return p
end

-- Vertical cylinder (Roblox cylinders run along X; rotate so the axis is world-up).
function Util.Cylinder(
	parent: Instance,
	name: string,
	center: Vector3,
	height: number,
	diameter: number,
	color: Color3,
	material: Enum.Material?,
	decor: boolean?
): Part
	return Util.Part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material,
		Decor = decor,
		Parent = parent,
	})
end

function Util.Ball(
	parent: Instance,
	name: string,
	center: Vector3,
	diameter: number,
	color: Color3,
	material: Enum.Material?
): Part
	return Util.Part({
		Name = name,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(diameter, diameter, diameter),
		CFrame = CFrame.new(center),
		Color = color,
		Material = material,
		Decor = true,
		Parent = parent,
	})
end

-- pcall for functions without return values (keeps the strict checker happy). Returns the
-- error message, or nil on success.
function Util.Try(fn: () -> ()): any
	local ok, err = pcall(function(): boolean
		fn()
		return true
	end)
	return if ok then nil else err
end

function Util.Folder(name: string, parent: Instance): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function Util.Model(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

function Util.Tag(inst: Instance, tag: string)
	CollectionService:AddTag(inst, tag)
end

-- Text label filling a SurfaceGui/Frame. Chunky cartoon style: FredokaOne + dark stroke.
function Util.Label(parent: Instance, text: string, color: Color3, pos: UDim2, size: UDim2, font: Enum.Font?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Position = pos
	label.Size = size
	label.Font = font or Theme.Fonts.Title
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Stroke
	stroke.Thickness = 4
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = label
	label.Parent = parent
	return label
end

function Util.SurfaceGui(part: BasePart, face: Enum.NormalId?): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.MaxDistance = 250
	gui.Parent = part
	return gui
end

export type SignOptions = {
	Name: string?,
	BoardColor: Color3?,
	TextColor: Color3?,
	Material: Enum.Material?,
	SubText: string?,
	Decor: boolean?,
}

-- A board Part whose Front face (-Z of `cf`) shows `text`. Returns board and main label.
function Util.Sign(parent: Instance, text: string, size: Vector3, cf: CFrame, opts: SignOptions?): (Part, TextLabel)
	local o: SignOptions = opts or {}
	local board = Util.Part({
		Name = o.Name or "Sign",
		Size = size,
		CFrame = cf,
		Color = o.BoardColor or Theme.Colors.Panel,
		Material = o.Material or Enum.Material.SmoothPlastic,
		Decor = o.Decor,
		CastShadow = true,
		Parent = parent,
	})
	local gui = Util.SurfaceGui(board)
	local mainSize = if o.SubText then UDim2.fromScale(0.9, 0.62) else UDim2.fromScale(0.92, 0.84)
	local label = Util.Label(gui, text, o.TextColor or Theme.Colors.Text, UDim2.fromScale(0.05, 0.06), mainSize)
	if o.SubText then
		local sub = Util.Label(
			gui,
			o.SubText,
			Theme.Colors.Gold,
			UDim2.fromScale(0.08, 0.66),
			UDim2.fromScale(0.84, 0.28),
			Theme.Fonts.Number
		)
		sub.Name = "SubLabel"
	end
	return board, label
end

function Util.Prompt(part: BasePart, actionText: string, objectText: string, distance: number?): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = distance or 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = part
	return prompt
end

-- Make every part in a model anchored; optionally non-colliding & shadowless (small decor).
function Util.Finish(model: Instance, small: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			if small then
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.CastShadow = false
			end
		end
	end
end

-- Put a model so the bottom of its bounding box rests at the Y of `cf`.
-- Height of the visible ground (smooth terrain or a map part) at `pos`. Smooth terrain's
-- visible surface sits ~2 studs above the 4-stud voxel grid that layout heights are built on,
-- so things placed at the grid height looked sunk (playtest: fountain, towels, egg labels).
-- Only accepts a hit within 4 studs of `pos.Y`; otherwise keeps `pos.Y`.
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater = true

function Util.SurfaceY(pos: Vector3, ignore: { Instance }?): number
	groundParams.FilterDescendantsInstances = ignore or {}
	local hit = workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -8, 0), groundParams)
	if hit and math.abs(hit.Position.Y - pos.Y) <= 4 then
		return hit.Position.Y
	end
	return pos.Y
end

function Util.Ground(model: Model, cf: CFrame)
	local groundY = Util.SurfaceY(cf.Position, { model :: Instance })
	cf = cf + Vector3.new(0, groundY - cf.Position.Y, 0)
	model:PivotTo(cf)
	local bbCF, bbSize = model:GetBoundingBox()
	local bottom = bbCF.Position.Y - bbSize.Y / 2
	model:PivotTo(cf + Vector3.new(0, cf.Position.Y - bottom, 0))
end

local SMALL_PROPS: { [string]: boolean } = {
	Crab = true,
	Shell = true,
	BeachBall = true,
	BeachTowel = true,
	Surfboard = true,
}

-- Models.Prop(name) placed on the ground at `pos` (Y = ground height), rotated `yawDeg`.
function Util.Prop(name: string, parent: Instance, pos: Vector3, yawDeg: number, scale: number?): Model?
	local ok, result = pcall(Models.Prop, name)
	if not ok or typeof(result) ~= "Instance" or not result:IsA("Model") then
		warn("[World] Models.Prop failed for", name, result)
		return nil
	end
	local model = result :: Model
	if scale and scale ~= 1 then
		pcall(function()
			model:ScaleTo(scale)
		end)
	end
	Util.Finish(model, SMALL_PROPS[name] == true)
	Util.Ground(model, CFrame.new(pos) * CFrame.Angles(0, math.rad(yawDeg), 0))
	model.Parent = parent
	return model
end

-- Yaw (degrees) that makes a model's -Z (LookVector) face from `from` towards `to`.
function Util.YawTowards(from: Vector3, to: Vector3): number
	local d = to - from
	return math.deg(math.atan2(-d.X, -d.Z))
end

-- Horizontal look CFrame (front = -Z) at `pos` facing `target`.
function Util.Facing(pos: Vector3, target: Vector3): CFrame
	return CFrame.lookAt(pos, Vector3.new(target.X, pos.Y, target.Z))
end

return Util
