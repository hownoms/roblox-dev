--!strict
--[[
	PlacementController — place a shade on the beach (owner: Survival). UI-agnostic: SurvivalHUD
	draws the Rotate / Place / Cancel bar from PlacementController.Changed.

	Flow: Begin(shadeId?) -> a see-through ghost (Models.Shade) plus a disc showing the shaded
	circle follows the pointer: the mouse on desktop, the last tap on touch screens (tap the sand
	to move it), the screen centre on gamepad. The ghost sits on the raycast hit point of the
	terrain (the VISIBLE smooth-terrain surface). Green = OK, red = can't place there (too far,
	in the sea, down a hole). R / L1 rotates, click / Place button / R2 places, B / Backspace /
	Cancel button cancels. Digging is paused while placing (DigController.Enabled).
	The server re-validates everything (SurvivalShades) and answers with a toast.

	API:
		PlacementController.Begin(shadeId?) / Cancel() / Toggle() / Rotate() / Confirm(): boolean
		PlacementController.Active: boolean, ShadeId: string?, Valid: boolean, Reason: string?
		PlacementController.Changed: Signal (active: boolean)
		PlacementController.BestOwnedShade(): string?
		PlacementController.SetPointer(screenPosition: Vector2)   -- touch: aim at a screen point
]]
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Signal = require(script.Parent.Parent.Util.Signal)
local Character = require(script.Parent.Parent.Util.Character)
local ModelFactory = require(script.Parent.Parent.Util.ModelFactory)
local State = require(script.Parent.State)
local SoundController = require(script.Parent.SoundController)
local DigController = require(script.Parent.DigController)
local Models = require(Shared:WaitForChild("Models"))

local PlacementController = {}

PlacementController.Active = false
PlacementController.ShadeId = nil :: string?
PlacementController.Valid = false
PlacementController.Reason = nil :: string?
PlacementController.Position = nil :: Vector3?
PlacementController.Yaw = 0
PlacementController.Changed = Signal.new()
-- Optional UI hook for local hints (SurvivalHUD sets it to Toasts.Show).
PlacementController.Hint = nil :: ((text: string, kind: string) -> ())?

local RENDER_NAME = "SurvivalShadePlacement"
local RAY_LENGTH = 400
local OK_COLOR = Color3.fromRGB(90, 230, 120)
local BAD_COLOR = Color3.fromRGB(255, 80, 80)
local SURFACE_BELOW = 6

local ghost: Model? = nil
local disc: Part? = nil
local pointer: Vector2? = nil -- screen (GUI inset excluded) position of the last tap
local digWasEnabled = true
local initialized = false

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { Workspace.Terrain }
rayParams.IgnoreWater = false

local function hint(text: string, kind: string)
	local fn = PlacementController.Hint
	if fn then
		fn(text, kind)
	end
end

function PlacementController.BestOwnedShade(): string?
	local owned = State.Data.OwnedShades or ({} :: { [string]: boolean })
	local best: string? = nil
	for _, def in Config.Shades do
		if owned[def.Id] then
			best = def.Id -- Config.Shades is ordered by price
		end
	end
	return best
end

local function destroyGhost()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	if disc then
		disc:Destroy()
		disc = nil
	end
end

local function buildGhost(shadeId: string)
	destroyGhost()
	local ok, result = pcall(Models.Shade, shadeId)
	local model: Model
	if ok and typeof(result) == "Instance" and result:IsA("Model") then
		model = result
	else
		model = Instance.new("Model")
		local p = Instance.new("Part")
		p.Name = "Root"
		p.Size = Vector3.new(1, 8, 1)
		p.Parent = model
		model.PrimaryPart = p
	end
	ModelFactory.MakeVisualOnly(model, false)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = math.max(d.Transparency, 0.45)
		elseif d:IsA("BillboardGui") or d:IsA("PointLight") then
			d:Destroy()
		end
	end
	model.Name = "ShadeGhost"
	model.Parent = Workspace.CurrentCamera or Workspace
	ghost = model

	local def = Config.GetShade(shadeId)
	local radius = if def then def.Radius else 6
	local d = Instance.new("Part")
	d.Name = "ShadeGhostDisc"
	d.Shape = Enum.PartType.Cylinder
	d.Anchored = true
	d.CanCollide = false
	d.CanQuery = false
	d.CanTouch = false
	d.CastShadow = false
	d.Material = Enum.Material.SmoothPlastic
	d.Transparency = 0.65
	d.Size = Vector3.new(0.3, radius * 2, radius * 2)
	d.Color = OK_COLOR
	d.Parent = Workspace.CurrentCamera or Workspace
	disc = d
end

-- Camera ray for the current pointer (mouse / last tap / screen centre).
local function aimRay(): (Vector3?, Vector3?)
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil, nil
	end
	local ray: Ray
	local tapped = pointer
	if tapped then
		ray = camera:ScreenPointToRay(tapped.X, tapped.Y)
	elseif UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
		local mouse = UserInputService:GetMouseLocation()
		ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	else
		local size = camera.ViewportSize
		ray = camera:ViewportPointToRay(size.X / 2, size.Y * 0.6)
	end
	return ray.Origin, ray.Direction
end

local function horizontal(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

-- Recomputes the aim point, validity and ghost pose.
function PlacementController.Update()
	if not PlacementController.Active then
		return
	end
	local origin, direction = aimRay()
	local hit = if origin and direction then Workspace:Raycast(origin, direction.Unit * RAY_LENGTH, rayParams) else nil
	local valid = false
	local reason: string? = "Point at the sand"
	local position: Vector3? = nil
	if hit then
		position = hit.Position
		local root = Character.GetRoot()
		if hit.Material == Enum.Material.Water then
			reason = "Not in the water!"
		elseif hit.Position.Y < Config.SURFACE_Y - SURFACE_BELOW then
			reason = "Put it on the surface, not in a hole!"
		elseif root and horizontal(root.Position, hit.Position) > Config.Heat.ShadePlaceRange then
			reason = "Too far away!"
		else
			valid = true
			reason = nil
		end
	end
	PlacementController.Valid = valid
	PlacementController.Reason = reason
	PlacementController.Position = position
	local model = ghost
	local ring = disc
	if model and ring then
		if position then
			local pose = CFrame.new(position) * CFrame.Angles(0, PlacementController.Yaw, 0)
			model:PivotTo(pose)
			ring.CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
			ring.Color = if valid then OK_COLOR else BAD_COLOR
			ring.Transparency = 0.65
		else
			ring.Transparency = 1
		end
	end
end

local function bindInputs()
	ContextActionService:BindActionAtPriority("SurvivalPlaceRotate", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			PlacementController.Rotate()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.R, Enum.KeyCode.ButtonL1)
	ContextActionService:BindActionAtPriority("SurvivalPlaceCancel", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			PlacementController.Cancel()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.B, Enum.KeyCode.Backspace, Enum.KeyCode.ButtonB)
	ContextActionService:BindActionAtPriority("SurvivalPlaceConfirm", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			PlacementController.Confirm()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonR2, Enum.KeyCode.Return)
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, function()
		PlacementController.Update()
	end)
end

local function unbindInputs()
	ContextActionService:UnbindAction("SurvivalPlaceRotate")
	ContextActionService:UnbindAction("SurvivalPlaceCancel")
	ContextActionService:UnbindAction("SurvivalPlaceConfirm")
	RunService:UnbindFromRenderStep(RENDER_NAME)
end

function PlacementController.Begin(shadeId: string?)
	local id = shadeId or PlacementController.BestOwnedShade()
	if not id then
		hint("Buy a shade at the Beach Shop first! ⛱️", "Info")
		return
	end
	local owned = State.Data.OwnedShades or ({} :: { [string]: boolean })
	if not owned[id :: string] then
		hint("You don't own that shade yet!", "Error")
		return
	end
	local wasActive = PlacementController.Active
	PlacementController.Active = true
	PlacementController.ShadeId = id
	pointer = nil
	buildGhost(id :: string)
	if not wasActive then
		digWasEnabled = DigController.Enabled
		DigController.Enabled = false
		bindInputs()
	end
	PlacementController.Update()
	SoundController.Play("Whoosh", 1.3, 0.5)
	PlacementController.Changed:Fire(true)
end

function PlacementController.Cancel()
	if not PlacementController.Active then
		return
	end
	PlacementController.Active = false
	PlacementController.ShadeId = nil
	PlacementController.Position = nil
	pointer = nil
	destroyGhost()
	unbindInputs()
	DigController.Enabled = digWasEnabled
	PlacementController.Changed:Fire(false)
end

function PlacementController.Toggle()
	if PlacementController.Active then
		PlacementController.Cancel()
	else
		PlacementController.Begin(nil)
	end
end

function PlacementController.Rotate()
	if not PlacementController.Active then
		return
	end
	PlacementController.Yaw = (PlacementController.Yaw + math.pi / 4) % (math.pi * 2)
	SoundController.Play("Click")
	PlacementController.Update()
end

-- Touch: aim at a screen point (GUI coordinates, inset excluded).
function PlacementController.SetPointer(position: Vector2)
	pointer = position
	PlacementController.Update()
end

function PlacementController.Confirm(): boolean
	if not PlacementController.Active then
		return false
	end
	PlacementController.Update()
	local position = PlacementController.Position
	local id = PlacementController.ShadeId
	if not PlacementController.Valid or not position or not id then
		SoundController.Play("Error")
		hint(PlacementController.Reason or "Can't place it there!", "Error")
		return false
	end
	Remotes.Get("PlaceShade"):FireServer(id, position, PlacementController.Yaw)
	SoundController.Play("Purchase", 1.1, 0.6)
	PlacementController.Cancel()
	return true
end

function PlacementController.Init()
	if initialized then
		return
	end
	initialized = true
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or not PlacementController.Active then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			PlacementController.Confirm()
		elseif input.UserInputType == Enum.UserInputType.Touch then
			PlacementController.SetPointer(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)
	-- Respawn / leaving: never leave a ghost or a paused DigController behind.
	Players.LocalPlayer.CharacterAdded:Connect(function()
		PlacementController.Cancel()
	end)
	-- Losing the shade (rebirth won't, but be safe) cancels too.
	State.Changed("OwnedShades"):Connect(function(owned: any)
		local id = PlacementController.ShadeId
		if PlacementController.Active and id and not (typeof(owned) == "table" and owned[id]) then
			PlacementController.Cancel()
		end
	end)
end

return PlacementController
