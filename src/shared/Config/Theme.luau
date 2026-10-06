--!strict
--[[
	Theme — v3 "chunky simulator" palette in beach colours (docs/UI_STYLE.md, binding).
	- Outlines everywhere: Stroke (#1b1b24) 3-4 px on panels/buttons, 2-3 px on text.
	- Panels: ocean-navy body (Navy -> NavyDark) with one saturated header bar; inner cards are
	  NavyCard with a dark outline. Cream Panel/PanelAlt stay for world boards (server) only.
	- Text colour carries meaning: Money green for coins, Time sky-blue for boosts/timers, Gold
	  for rare, white for neutral.
	World boards (server) share Sand..Gold/Purple/Panel/Text/Stroke, so keep those stable.
	Mobile-first: every tappable button >= MinTouchSize design px (44 real px at UI scale 0.6).
	Fonts: FredokaOne for titles/buttons/big numbers, GothamBlack for small numbers, Gotham body.
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
		Stroke = rgb(27, 27, 36),
		Success = rgb(70, 210, 90),
		Danger = rgb(235, 60, 70),
		Warning = rgb(255, 190, 40),
		Disabled = rgb(140, 145, 160),
		Coins = rgb(255, 205, 40),
		Tokens = rgb(120, 255, 200),
		Robux = rgb(80, 205, 110),
		Navy = rgb(29, 42, 68),
		NavyDark = rgb(22, 32, 58),
		NavyCard = rgb(44, 62, 100),
		NavyCardDark = rgb(34, 49, 82),
		Money = rgb(92, 230, 92),
		Time = rgb(110, 205, 255),
		Highlight = rgb(255, 150, 40),
	},
	Fonts = {
		Title = Enum.Font.FredokaOne,
		Body = Enum.Font.GothamBold,
		Number = Enum.Font.GothamBlack,
	},
	CornerSmall = UDim.new(0, 8),
	CornerMedium = UDim.new(0, 12),
	CornerLarge = UDim.new(0, 18),
	CornerPill = UDim.new(1, 0),
	StrokeThickness = 3,
	MinTouchSize = 74, -- design px: 74 x UI scale 0.6 = 44 real px
	TweenTime = 0.18,
}

return Theme
