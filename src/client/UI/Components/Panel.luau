--!strict
--[[
	Panel — centred modal window (header with emoji + title, big red close button, cream body)
	plus the panel registry: only one panel is open at a time.

		local panel = Panel.new({ Name = "Shop", Title = "Shop", Icon = "🛒", Color = ... })
		panel.Opened:Connect(function(args) ... end)
		Panel.Open("Shop", { Tab = "Backpacks" })  -- from anywhere (HUD, prompts, tutorial)

	Opening pops the window in with Back easing, dims the world, and on gamepad selects the
	first button. ButtonB / clicking the dim background closes it.
]]
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Style = require(script.Parent.Style)
local Signal = require(script.Parent.Parent.Parent.Util.Signal)
local Root = require(script.Parent.Parent.Root)
local SoundController = require(script.Parent.Parent.Parent.Controllers.SoundController)

local Panel = {}

local HEADER = 58

export type PanelProps = {
	Name: string,
	Title: string,
	Icon: string?,
	Color: Color3?,
	Size: Vector2?, -- design px
}

export type Panel = {
	Name: string,
	Window: Frame,
	Body: Frame,
	Header: Frame,
	Title: TextLabel,
	IsOpen: boolean,
	Opened: Signal.Signal, -- (args)
	Closed: Signal.Signal,
	Open: (self: Panel, args: any?) -> (),
	Close: (self: Panel) -> (),
	SetTitle: (self: Panel, text: string) -> (),
}

local registry: { [string]: Panel } = {}
local current: Panel? = nil
local dim: TextButton? = nil

Panel.Changed = Signal.new() -- (openPanelName or nil)

local function getDim(): TextButton
	if dim then
		return dim
	end
	local d = Instance.new("TextButton")
	d.Name = "Dim"
	d.Text = ""
	d.AutoButtonColor = false
	d.Selectable = false
	d.BackgroundColor3 = Color3.new(0, 0, 0)
	d.BackgroundTransparency = 1
	d.Size = UDim2.fromScale(4, 4)
	d.Position = UDim2.fromScale(0.5, 0.5)
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Visible = false
	d.ZIndex = 0
	d.Parent = Root.Get("Panels")
	d.Activated:Connect(function()
		Panel.CloseAll()
	end)
	dim = d
	return d
end

local function setDim(visible: boolean)
	local d = getDim()
	if visible then
		d.Visible = true
		Style.Tween(d, 0.2, { BackgroundTransparency = 0.6 })
	else
		local tween = Style.Tween(d, 0.2, { BackgroundTransparency = 1 })
		tween.Completed:Once(function()
			if not current then
				d.Visible = false
			end
		end)
	end
end

local function firstSelectable(root: Instance): GuiObject?
	for _, d in root:GetDescendants() do
		if d:IsA("GuiButton") and d.Visible and d.Selectable and d.Name == "Face" then
			return d
		end
	end
	return nil
end

local function bindBack(panel: Panel)
	ContextActionService:BindActionAtPriority("DigClosePanel", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			panel:Close()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonB)
end

function Panel.new(props: PanelProps): Panel
	local size = props.Size or Vector2.new(760, 470)
	local color = props.Color or Style.Colors.Ocean

	local window = Instance.new("Frame")
	window.Name = props.Name
	window.BackgroundTransparency = 1
	window.Size = UDim2.fromOffset(size.X, size.Y)
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.new(0.5, 0, 0.5, 6)
	window.Visible = false
	window.ZIndex = 2
	window.Parent = Root.Get("Panels")

	local openScale = Instance.new("UIScale")
	openScale.Name = "Open"
	openScale.Parent = window

	-- Shrink the whole window when the screen is smaller than the panel (short phones):
	-- leave room for the close button (sticks out ~27px) and a small margin.
	local function fit(): number
		local design = Root.GetDesignSize()
		if design.X <= 0 or design.Y <= 0 then
			return 1
		end
		return math.min(1, (design.Y - 36) / (size.Y + 12), (design.X - 40) / (size.X + 30))
	end
	Root.ScaleChanged:Connect(function()
		if window.Visible then
			openScale.Scale = fit()
		end
	end)

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 0, 1, -6)
	shadow.Position = UDim2.fromOffset(0, 8)
	shadow.BackgroundColor3 = Style.Colors.Stroke
	shadow.BackgroundTransparency = 0.35
	shadow.ZIndex = 2
	shadow.Parent = window
	Style.Corner(shadow, Style.Theme.CornerLarge)

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.new(1, 0, 1, -6)
	face.BackgroundColor3 = Style.Colors.Panel
	face.ZIndex = 3
	face.Parent = window
	Style.Corner(face, Style.Theme.CornerLarge)
	Style.Stroke(face, Style.Colors.Stroke, 4)

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, HEADER)
	header.BackgroundColor3 = color
	header.ZIndex = 4
	header.Parent = face
	Style.Corner(header, Style.Theme.CornerLarge)
	Style.Gradient(header, { Style.Lighten(color, 0.25), color }, 90)
	-- square off the header's bottom corners
	local headerFill = Instance.new("Frame")
	headerFill.Name = "Square"
	headerFill.Size = UDim2.new(1, 0, 0, 22)
	headerFill.Position = UDim2.new(0, 0, 1, -22)
	headerFill.BackgroundColor3 = color
	headerFill.BorderSizePixel = 0
	headerFill.ZIndex = 4
	headerFill.Parent = header
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Size = UDim2.new(1, 0, 0, 4)
	divider.Position = UDim2.new(0, 0, 1, -2)
	divider.BackgroundColor3 = Style.Colors.Stroke
	divider.BorderSizePixel = 0
	divider.ZIndex = 5
	divider.Parent = header

	local title = Style.Label({
		Name = "Title",
		Text = (if props.Icon then props.Icon .. "  " else "") .. props.Title,
		Size = UDim2.new(1, -140, 0, 40),
		Position = UDim2.new(0, 20, 0, 9),
		MaxTextSize = 34,
		XAlign = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
		ZIndex = 6,
		Parent = header,
	})

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, -28, 1, -HEADER - 22)
	body.Position = UDim2.fromOffset(14, HEADER + 10)
	body.ZIndex = 4
	body.Parent = face

	-- Close button (built inline to avoid a Button <-> Panel dependency loop)
	local close = Instance.new("TextButton")
	close.Name = "Face"
	close.Text = "✖"
	close.Font = Style.Fonts.Title
	close.TextScaled = true
	close.TextColor3 = Style.Colors.Text
	close.AutoButtonColor = true
	close.BackgroundColor3 = Style.Colors.Danger
	close.Size = UDim2.fromOffset(60, 60)
	close.AnchorPoint = Vector2.new(0.5, 0.5)
	close.Position = UDim2.new(1, -14, 0, 10)
	close.ZIndex = 8
	close.Parent = window
	Style.Corner(close, Style.Theme.CornerPill)
	Style.Stroke(close, Style.Colors.Stroke, 4)
	Style.Shine(close)
	Style.Padding(close, 11)
	-- Invisible, larger touch target (>= 44 real px on a phone at UI scale 0.6).
	local closeHit = Instance.new("TextButton")
	closeHit.Name = "HitArea"
	closeHit.Text = ""
	closeHit.BackgroundTransparency = 1
	closeHit.Selectable = false
	closeHit.Size = UDim2.fromOffset(80, 80)
	closeHit.AnchorPoint = Vector2.new(0.5, 0.5)
	closeHit.Position = UDim2.new(1, -14, 0, 10)
	closeHit.ZIndex = 7
	closeHit.Parent = window

	local opened = Signal.new()
	local closed = Signal.new()

	local panel: Panel
	panel = {
		Name = props.Name,
		Window = window,
		Body = body,
		Header = header,
		Title = title,
		IsOpen = false,
		Opened = opened,
		Closed = closed,
		Open = function(self: Panel, args: any?)
			if current and current ~= self then
				(current :: Panel):Close()
			end
			current = self
			local wasOpen = self.IsOpen
			self.IsOpen = true
			if not wasOpen then
				window.Visible = true
				local target = fit()
				openScale.Scale = 0.55 * target
				Style.Tween(openScale, 0.32, { Scale = target }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
				setDim(true)
				SoundController.Play("Whoosh", 1.2, 0.6)
				bindBack(self)
				Panel.Changed:Fire(self.Name)
			end
			opened:Fire(args)
			if UserInputService.GamepadEnabled then
				task.defer(function()
					GuiService.SelectedObject = firstSelectable(body) or close
				end)
			end
		end,
		Close = function(self: Panel)
			if not self.IsOpen then
				return
			end
			self.IsOpen = false
			if current == self then
				current = nil
				setDim(false)
				ContextActionService:UnbindAction("DigClosePanel")
				Panel.Changed:Fire(nil)
			end
			local tween =
				Style.Tween(openScale, 0.14, { Scale = 0.6 * fit() }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			tween.Completed:Once(function()
				if not self.IsOpen then
					window.Visible = false
				end
			end)
			local selected = GuiService.SelectedObject
			if selected and selected:IsDescendantOf(window) then
				GuiService.SelectedObject = nil
			end
			closed:Fire()
		end,
		SetTitle = function(_: Panel, text: string)
			title.Text = (if props.Icon then props.Icon .. "  " else "") .. text
		end,
	}

	close.Activated:Connect(function()
		SoundController.Play("Click")
		panel:Close()
	end)
	closeHit.Activated:Connect(function()
		SoundController.Play("Click")
		panel:Close()
	end)

	registry[props.Name] = panel
	return panel
end

function Panel.Get(name: string): Panel?
	return registry[name]
end

function Panel.Open(name: string, args: any?)
	local panel = registry[name]
	if panel then
		panel:Open(args)
	else
		warn("[Panel] unknown panel", name)
	end
end

function Panel.Toggle(name: string, args: any?)
	local panel = registry[name]
	if not panel then
		return
	end
	if panel.IsOpen then
		panel:Close()
	else
		panel:Open(args)
	end
end

function Panel.CloseAll()
	if current then
		(current :: Panel):Close()
	end
end

function Panel.Current(): string?
	return if current then (current :: Panel).Name else nil
end

-- Helper: a vertical scrolling list/grid area that auto-sizes its canvas.
function Panel.Scroller(parent: Instance, size: UDim2?, position: UDim2?): ScrollingFrame
	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "Scroller"
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.Size = size or UDim2.fromScale(1, 1)
	scroller.Position = position or UDim2.new()
	scroller.CanvasSize = UDim2.new()
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollingDirection = Enum.ScrollingDirection.Y
	scroller.ScrollBarThickness = 10
	scroller.ScrollBarImageColor3 = Style.Colors.SandDark
	scroller.ScrollBarImageTransparency = 0.1
	scroller.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	scroller.ElasticBehavior = Enum.ElasticBehavior.Always
	scroller.Selectable = false
	scroller.ZIndex = 5
	scroller.Parent = parent
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingRight = UDim.new(0, 4)
	padding.Parent = scroller
	return scroller
end

return Panel
