--!strict
--[[
	RideButton — "Ride" toggle + mobile "Dig" button for the ride-on vehicle (v2.1, Ride agent).
	Own ScreenGui "Dig_Ride" with the shared responsive scale (Root.Scale), DisplayOrder 2.

	- Ride (Ride / Exit toy button): only shown while the player owns a rideable pet (or is
	  riding). Sits beside the bottom-centre bar (UI/Layout "Ride" region: right of it on wide
	  screens, left of it on narrow ones so it never meets the SurvivalHUD), level with the
	  Surface/Sell/Auto row. Same action as key V / gamepad DPadUp (RideController).
	- Dig (touch devices only, only while riding): hold to scoop. Layout "RideDig": right side,
	  left of the phone jump button and clear of the bottom-centre backpack bar.
]]
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Components = script.Parent.Components
local Style = require(Components.Style)
local Button = require(Components.Button)
local Root = require(script.Parent.Root)
local Layout = require(script.Parent.Layout)
local RideController = require(script.Parent.Parent.Controllers.RideController)

local RideButton = {}

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
		Icon = "Ride",
		Text = "Ride",
		Vertical = true,
		Color = Style.Colors.Sunset,
		Size = Layout.SizeOf(Layout.Current().Ride),
		MaxTextSize = 18,
		Sound = "",
		OnClick = function()
			RideController.Toggle()
		end,
	})
	RideButton.Ride = ride

	local dig = Button.new({
		Name = "RideDigButton",
		Parent = canvas,
		Icon = "Dig",
		Text = "Dig",
		Vertical = true,
		Color = Style.Colors.Gold,
		Size = Layout.SizeOf(Layout.Current().RideDig),
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

	Layout.Observe(function(regions: Layout.Regions)
		ride.Holder.Position = Layout.Position(regions.Ride)
		ride.Holder.Size = Layout.SizeOf(regions.Ride)
		dig.Holder.Position = Layout.Position(regions.RideDig)
		dig.Holder.Size = Layout.SizeOf(regions.RideDig)
	end)

	local function refresh()
		local riding = RideController.Riding
		ride:SetVisible(riding or RideController.CanRide())
		ride:SetIcon(if riding then "🚶" else "Ride")
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
