--!strict
--[[
	RideButton — "Ride" toggle + mobile "Dig" button for the ride-on vehicle (v2.1, Ride agent).
	Own ScreenGui "Dig_Ride" with the shared responsive scale (Root.Scale), DisplayOrder 2.

	- Ride (🚜 Ride / 🚶 Exit): only shown while the player owns a rideable pet (or is riding).
	  Bottom-left, above the mobile thumbstick area: x 14 when the screen is tall enough to clear
	  the HUD menu (which ends at y ~414), otherwise just right of the menu column (x 340), so it
	  never overlaps the HUD. Bottom edge 196 design px above the screen bottom.
	  Same action as key V / gamepad DPadUp (RideController).
	- Dig (⛏️, touch devices only, only while riding): hold to scoop. Right side, left of the
	  phone jump button and clear of the bottom-centre backpack bar.
]]
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Components = script.Parent.Components
local Style = require(Components.Style)
local Button = require(Components.Button)
local Root = require(script.Parent.Root)
local RideController = require(script.Parent.Parent.Controllers.RideController)

local RideButton = {}

local RIDE_SIZE = Vector2.new(84, 88)
local DIG_SIZE = 100
local BOTTOM_GAP = 196 -- above the thumbstick
local MENU_BOTTOM = 420 -- HUD menu ends at y ~414
local MENU_RIGHT = 340 -- HUD menu ends at x ~328

RideButton.Gui = nil :: ScreenGui?
RideButton.Ride = nil :: Button.Button?
RideButton.Dig = nil :: Button.Button?

local initialized = false

function RideButton.Init()
	if initialized then
		return
	end
	initialized = true

	local gui = Instance.new("ScreenGui")
	gui.Name = "Dig_Ride"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 2
	RideButton.Gui = gui

	local canvas = Instance.new("Frame")
	canvas.Name = "Canvas"
	canvas.BackgroundTransparency = 1
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.fromScale(0.5, 0.5)
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = canvas
	local function applyScale(s: number)
		scale.Scale = s
		canvas.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	applyScale(Root.Scale)
	Root.ScaleChanged:Connect(applyScale)

	local ride = Button.new({
		Name = "RideButton",
		Parent = canvas,
		Icon = "🚜",
		Text = "Ride",
		Vertical = true,
		Color = Style.Colors.Sunset,
		Size = UDim2.fromOffset(RIDE_SIZE.X, RIDE_SIZE.Y),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, MENU_RIGHT, 1, -BOTTOM_GAP),
		Sound = "",
		OnClick = function()
			RideController.Toggle()
		end,
	})
	RideButton.Ride = ride

	local dig = Button.new({
		Name = "RideDigButton",
		Parent = canvas,
		Icon = "⛏️",
		Text = "Dig",
		Vertical = true,
		Color = Style.Colors.Gold,
		Size = UDim2.fromOffset(DIG_SIZE, DIG_SIZE),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -170, 1, -20),
		Sound = "",
	})
	RideButton.Dig = dig
	local face = dig.Face
	local function isPress(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
	end
	face.InputBegan:Connect(function(input: InputObject)
		if isPress(input) then
			RideController.SetDigHeld(true)
		end
	end)
	face.InputEnded:Connect(function(input: InputObject)
		if isPress(input) then
			RideController.SetDigHeld(false)
		end
	end)
	face.MouseLeave:Connect(function()
		RideController.SetDigHeld(false)
	end)

	-- Bottom-left: tuck under the HUD menu when the screen is tall enough, else beside it.
	local function place()
		local height = canvas.AbsoluteSize.Y / math.max(scale.Scale, 0.01)
		local x = if height - BOTTOM_GAP - RIDE_SIZE.Y >= MENU_BOTTOM then 14 else MENU_RIGHT
		ride.Holder.Position = UDim2.new(0, x, 1, -BOTTOM_GAP)
	end
	canvas:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	place()

	local function refresh()
		local riding = RideController.Riding
		ride:SetVisible(riding or RideController.CanRide())
		ride:SetIcon(if riding then "🚶" else "🚜")
		ride:SetText(if riding then "Exit" else "Ride")
		dig:SetVisible(riding and UserInputService.TouchEnabled)
		if not riding then
			RideController.SetDigHeld(false)
		end
	end
	RideController.RidingChanged:Connect(refresh)
	RideController.CanRideChanged:Connect(refresh)
	refresh()

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

return RideButton
