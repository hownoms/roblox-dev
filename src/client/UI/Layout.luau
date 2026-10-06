--!strict
--[[
	Layout — the one place that decides where every always-on HUD region goes (design px, see
	Root: a landscape phone is ~1190-1330 x 500-540, a 1080p PC ~1420 x 760-800, a tablet
	~1000 x 750). Pure math (Layout.Compute) so tests can check any screen size; HUD, the
	objective banner, Toasts, SurvivalHUD and RideButton all position themselves from it and
	follow Layout.Changed.

	Regions (x, y = top-left; W, H = canvas design size):
	  TopRight  currency cluster: Coins pill + Daily/Settings round buttons, Tokens and the
	            multiplier pill under them          x W-400..W-12, y 8..108
	  Menu      2-column square menu, left-centre   x 14..168, 4 rows of 74 (y 4.. on short
	            screens so the bottom row clears the phone thumbstick)
	  Depth     depth meter 200 x 118:
	              wide screens (W >= 1184): top-centre-right, left of the TopRight cluster
	              narrow screens: right edge under the TopRight cluster (y 116)
	  Centre    top-centre column between the menu and the Depth/TopRight block (<= 380 wide):
	            objective banner y 8..54, boost/event chips y 60..96, toasts from y 102
	  Survival  SurvivalHUD (heat meter + snack slots) on the right edge under Depth/TopRight
	  Bottom    backpack bar + Surface/Sell/Auto, 420 x 180 centred on the bottom edge
	  Ride      Ride button beside the bottom bar (right side; left side only when that would
	            meet the SurvivalHUD, i.e. short narrow PC windows); RideDig = touch dig button
	Phones keep the thumbstick (bottom-left) and jump button (bottom-right) zones clear:
	nothing but the bottom bar/Ride reaches below y H-183 near those corners (tests check this).
]]
local Root = require(script.Parent.Root)
local Signal = require(script.Parent.Parent.Util.Signal)

local Layout = {}

export type Rect = { X: number, Y: number, W: number, H: number }

export type Regions = {
	Size: Vector2,
	Wide: boolean,
	TopRight: Rect,
	Menu: Rect,
	Depth: Rect,
	Centre: Rect, -- the whole top-centre column (banner + chips + toasts)
	Banner: Rect,
	Timers: Rect,
	Toasts: Rect,
	Survival: Rect,
	Bottom: Rect,
	Ride: Rect,
	RideDig: Rect,
}

Layout.MENU_CELL = 74 -- >= Theme.MinTouchSize
Layout.MENU_GAP_X = 6
Layout.MENU_GAP_Y = 4
Layout.MENU_COLUMNS = 2
Layout.MENU_ROWS = 4
Layout.TOP_RIGHT = Vector2.new(388, 100)
Layout.DEPTH = Vector2.new(200, 118)
Layout.SURVIVAL = Vector2.new(218, 184)
Layout.BOTTOM = Vector2.new(420, 180)
Layout.RIDE = Vector2.new(80, 86)
Layout.RIDE_DIG = 96
Layout.CENTRE_WIDTH = 380
Layout.WIDE_AT = 1184

local MARGIN = 12

local function rect(x: number, y: number, w: number, h: number): Rect
	return { X = x, Y = y, W = w, H = h }
end

function Layout.Overlaps(a: Rect, b: Rect): boolean
	return a.X < b.X + b.W and b.X < a.X + a.W and a.Y < b.Y + b.H and b.Y < a.Y + a.H
end

function Layout.Compute(size: Vector2): Regions
	local W, H = size.X, size.Y
	local menuW = Layout.MENU_COLUMNS * Layout.MENU_CELL + (Layout.MENU_COLUMNS - 1) * Layout.MENU_GAP_X
	local menuH = Layout.MENU_ROWS * Layout.MENU_CELL + (Layout.MENU_ROWS - 1) * Layout.MENU_GAP_Y
	local menuY = math.max(4, math.floor((H - menuH) / 2 - 96))
	local menu = rect(14, menuY, menuW, menuH)

	local topRight = rect(W - MARGIN - Layout.TOP_RIGHT.X, 8, Layout.TOP_RIGHT.X, Layout.TOP_RIGHT.Y)
	local wide = W >= Layout.WIDE_AT
	local depth = if wide
		then rect(topRight.X - 10 - Layout.DEPTH.X, 8, Layout.DEPTH.X, Layout.DEPTH.Y)
		else rect(W - MARGIN - Layout.DEPTH.X, topRight.Y + topRight.H + 8, Layout.DEPTH.X, Layout.DEPTH.Y)

	-- top-centre column: between the menu and whatever sits at the top right
	local bandLeft = menu.X + menu.W + MARGIN
	local bandRight = (if wide then depth.X else topRight.X) - MARGIN
	local width = math.min(Layout.CENTRE_WIDTH, bandRight - bandLeft)
	local cx = math.clamp(W / 2, bandLeft + width / 2, bandRight - width / 2)
	local left = math.floor(cx - width / 2)
	local centre = rect(left, 8, width, 94 + 3 * 46)
	local banner = rect(left, 8, width, 46)
	local timers = rect(left, 60, width, 36)
	local toasts = rect(left, 102, width, 3 * 46)

	local survivalTop = if wide then topRight.Y + topRight.H + 8 else depth.Y + depth.H + 6
	local survival = rect(W - 8 - Layout.SURVIVAL.X, survivalTop, Layout.SURVIVAL.X, Layout.SURVIVAL.Y)

	local bottom =
		rect(math.floor(W / 2 - Layout.BOTTOM.X / 2), H - 10 - Layout.BOTTOM.Y, Layout.BOTTOM.X, Layout.BOTTOM.Y)
	local ride = rect(bottom.X + bottom.W + 4, H - 116 - Layout.RIDE.Y, Layout.RIDE.X, Layout.RIDE.Y)
	if Layout.Overlaps(ride, survival) then
		-- short narrow screens (PC windows): the left side of the bottom bar instead
		ride.X = bottom.X - 4 - Layout.RIDE.X
	end
	local rideDig = rect(W - 170 - Layout.RIDE_DIG, H - 16 - Layout.RIDE_DIG, Layout.RIDE_DIG, Layout.RIDE_DIG)

	return {
		Size = size,
		Wide = wide,
		TopRight = topRight,
		Menu = menu,
		Depth = depth,
		Centre = centre,
		Banner = banner,
		Timers = timers,
		Toasts = toasts,
		Survival = survival,
		Bottom = bottom,
		Ride = ride,
		RideDig = rideDig,
	}
end

function Layout.Position(r: Rect): UDim2
	return UDim2.fromOffset(r.X, r.Y)
end

function Layout.SizeOf(r: Rect): UDim2
	return UDim2.fromOffset(r.W, r.H)
end

Layout.Changed = Signal.new() -- (regions)
local current: Regions = Layout.Compute(Root.DesignSize)
local hooked = false

function Layout.Current(): Regions
	return current
end

local function designSize(): Vector2?
	local size = Root.GetDesignSize()
	if size.X <= 0 or size.Y <= 0 then
		return nil
	end
	return Vector2.new(math.floor(size.X), math.floor(size.Y))
end

function Layout.Refresh()
	local size = designSize()
	if size == nil or size == current.Size then
		return
	end
	current = Layout.Compute(size :: Vector2)
	Layout.Changed:Fire(current)
end

-- Calls fn(regions) now and whenever the screen layout changes.
function Layout.Observe(fn: (Regions) -> ())
	if not hooked and Root.Layers.HUD then
		hooked = true
		Root.ScaleChanged:Connect(Layout.Refresh)
		Root.Layers.HUD.Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(Layout.Refresh)
		local size = designSize()
		if size then
			current = Layout.Compute(size)
		end
	end
	Layout.Changed:Connect(fn)
	fn(current)
end

return Layout
