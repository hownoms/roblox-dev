--!strict
--[[
	Root — creates the ScreenGuis (one per layer so DisplayOrder keeps popups above panels)
	and a single responsive scale shared by all of them.

	Each layer has a full-screen "Canvas" Frame with a UIScale. The canvas is sized 1/scale so
	after scaling it covers the safe area exactly; children are laid out in "design pixels"
	(reference height ~540, so a 76px button is ~46px on a landscape phone and ~90px on 1080p).
	ScreenInsets = CoreUISafeInsets keeps everything clear of the notch and the Roblox top bar.
]]
local Players = game:GetService("Players")

local Signal = require(script.Parent.Parent.Util.Signal)

local Root = {}

local REFERENCE_WIDTH = 1000
local REFERENCE_HEIGHT = 540
local MIN_SCALE = 0.6
local MAX_SCALE = 1.35

export type Layer = {
	Gui: ScreenGui,
	Canvas: Frame,
	Scale: UIScale,
}

Root.Scale = 1
Root.ScaleChanged = Signal.new()
Root.Layers = {} :: { [string]: Layer }
Root.DesignSize = Vector2.new(REFERENCE_WIDTH, REFERENCE_HEIGHT)

local playerGui: PlayerGui? = nil

local function computeScale(size: Vector2): number
	if size.X <= 0 or size.Y <= 0 then
		return 1
	end
	return math.clamp(math.min(size.X / REFERENCE_WIDTH, size.Y / REFERENCE_HEIGHT), MIN_SCALE, MAX_SCALE)
end

local function applyScale(layer: Layer, scale: number)
	layer.Scale.Scale = scale
	layer.Canvas.Size = UDim2.fromScale(1 / scale, 1 / scale)
end

local function makeLayer(name: string, displayOrder: number): Layer
	local gui = Instance.new("ScreenGui")
	gui.Name = "Dig_" .. name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = displayOrder

	local canvas = Instance.new("Frame")
	canvas.Name = "Canvas"
	canvas.BackgroundTransparency = 1
	-- Centered so the result is correct whether UIScale pivots on the anchor or the centre.
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.fromScale(0.5, 0.5)
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.Parent = gui

	local scale = Instance.new("UIScale")
	scale.Parent = canvas

	gui.Parent = playerGui
	return { Gui = gui, Canvas = canvas, Scale = scale }
end

function Root.Get(name: string): Frame
	local layer = Root.Layers[name]
	assert(layer, "UI Root: unknown layer " .. name)
	return layer.Canvas
end

function Root.GetGui(name: string): ScreenGui
	return Root.Layers[name].Gui
end

-- Size of the scaled canvas in design pixels.
function Root.GetDesignSize(): Vector2
	local layer = Root.Layers.HUD
	if not layer then
		return Root.DesignSize
	end
	return layer.Gui.AbsoluteSize / Root.Scale
end

function Root.Init()
	local player = Players.LocalPlayer
	playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

	Root.Layers.World = makeLayer("World", 0) -- tutorial hints anchored to screen positions
	Root.Layers.HUD = makeLayer("HUD", 1)
	Root.Layers.Panels = makeLayer("Panels", 5)
	Root.Layers.Popups = makeLayer("Popups", 8)
	Root.Layers.Toasts = makeLayer("Toasts", 10)

	local reference = Root.Layers.HUD.Gui
	local function update()
		local scale = computeScale(reference.AbsoluteSize)
		Root.Scale = scale
		for _, layer in Root.Layers do
			applyScale(layer, scale)
		end
		Root.ScaleChanged:Fire(scale)
	end
	reference:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	update()
end

return Root
