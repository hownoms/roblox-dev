--!strict
--[[
	Theme — bright low-poly cartoon beach UI palette. Mobile-first: big chunky buttons
	(>= MinTouchSize px), thick dark strokes on text, rounded corners everywhere.
	Fonts: FredokaOne for titles/buttons, GothamBlack for numbers (reads well tiny), Gotham body.
]]

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Theme: Types.ThemeDef = {
	Colors = {
		Sand = rgb(255, 222, 140),
		SandDark = rgb(222, 176, 92),
		Ocean = rgb(40, 190, 245),
		OceanDark = rgb(20, 110, 200),
		Sky = rgb(150, 225, 255),
		Sunset = rgb(255, 140, 60),
		Coral = rgb(255, 95, 125),
		Palm = rgb(70, 210, 120),
		Gold = rgb(255, 205, 40),
		Purple = rgb(170, 100, 255),
		Panel = rgb(255, 248, 230),
		PanelAlt = rgb(255, 236, 196),
		Text = rgb(255, 255, 255),
		TextDark = rgb(45, 40, 70),
		Stroke = rgb(35, 30, 60),
		Success = rgb(80, 215, 100),
		Danger = rgb(245, 70, 80),
		Warning = rgb(255, 190, 40),
		Disabled = rgb(160, 160, 170),
		Coins = rgb(255, 205, 40),
		Tokens = rgb(120, 255, 200),
		Robux = rgb(100, 220, 120),
	},
	Fonts = {
		Title = Enum.Font.FredokaOne,
		Body = Enum.Font.GothamBold,
		Number = Enum.Font.GothamBlack,
	},
	CornerSmall = UDim.new(0, 8),
	CornerMedium = UDim.new(0, 14),
	CornerLarge = UDim.new(0, 22),
	CornerPill = UDim.new(1, 0),
	StrokeThickness = 3,
	MinTouchSize = 48,
	TweenTime = 0.18,
}

return Theme
