--!strict
--[[
	Button — chunky cartoon button: dark "shadow" slab underneath, coloured face with shine
	gradient and thick stroke, emoji icon + label. Presses sink the face into the shadow,
	hover grows it slightly, clicks play the Click sound. Gamepad-selectable (TextButton face).
	Never create one smaller than Theme.MinTouchSize on a phone (design px * UI scale).
]]
local Style = require(script.Parent.Style)
local Signal = require(script.Parent.Parent.Parent.Util.Signal)
local SoundController = require(script.Parent.Parent.Parent.Controllers.SoundController)

local Button = {}

local SHADOW = 5

export type ButtonProps = {
	Name: string?,
	Parent: Instance?,
	Text: string?,
	Icon: string?,
	Color: Color3?,
	TextColor: Color3?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	MaxTextSize: number?,
	Vertical: boolean?, -- icon above a small caption (HUD style)
	Corner: UDim?,
	ZIndex: number?,
	Sound: string?, -- default "Click"; "" for silent
	OnClick: (() -> ())?,
}

export type Button = {
	Holder: Frame,
	Face: TextButton,
	Shadow: Frame,
	Label: TextLabel,
	Icon: TextLabel?,
	Badge: TextLabel,
	Enabled: boolean,
	Color: Color3,
	Activated: Signal.Signal,
	SetText: (self: Button, text: string) -> (),
	SetIcon: (self: Button, icon: string) -> (),
	SetColor: (self: Button, color: Color3) -> (),
	SetEnabled: (self: Button, enabled: boolean) -> (),
	SetBadge: (self: Button, text: string?) -> (),
	SetVisible: (self: Button, visible: boolean) -> (),
	Destroy: (self: Button) -> (),
}

function Button.new(props: ButtonProps): Button
	local color = props.Color or Style.Colors.Ocean
	local corner = props.Corner or Style.Theme.CornerMedium

	local holder = Instance.new("Frame")
	holder.Name = props.Name or "Button"
	holder.BackgroundTransparency = 1
	holder.Size = props.Size or UDim2.fromOffset(160, 56)
	holder.Position = props.Position or UDim2.new()
	holder.AnchorPoint = props.AnchorPoint or Vector2.zero
	holder.LayoutOrder = props.LayoutOrder or 0
	holder.ZIndex = props.ZIndex or 1

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 0, 1, -SHADOW)
	shadow.Position = UDim2.fromOffset(0, SHADOW)
	shadow.BackgroundColor3 = Style.Darken(color, 0.4)
	shadow.BorderSizePixel = 0
	shadow.ZIndex = holder.ZIndex
	shadow.Parent = holder
	Style.Corner(shadow, corner)

	local face = Instance.new("TextButton")
	face.Name = "Face"
	face.Text = ""
	face.AutoButtonColor = false
	face.Size = UDim2.new(1, 0, 1, -SHADOW)
	face.Position = UDim2.fromOffset(0, 0)
	face.BackgroundColor3 = color
	face.BorderSizePixel = 0
	face.ZIndex = holder.ZIndex + 1
	face.Parent = holder
	Style.Corner(face, corner)
	local faceStroke = Style.Stroke(face, Style.Colors.Stroke, 3)
	Style.Shine(face)

	local icon: TextLabel? = nil
	local label: TextLabel
	local text = props.Text or ""
	if props.Icon and props.Vertical then
		-- Icon fills the top ~60% of the face, caption the bottom ~30% (playtest: icons and
		-- captions looked tiny in big buttons).
		icon = Style.Icon({
			Text = props.Icon,
			Size = UDim2.new(1, -10, if text ~= "" then 0.6 else 0.84, 0),
			Position = UDim2.new(0.5, 0, if text ~= "" then 0.05 else 0.08, 0),
			AnchorPoint = Vector2.new(0.5, 0),
			ZIndex = face.ZIndex + 1,
			Parent = face,
		})
		label = Style.Label({
			Name = "Label",
			Text = text,
			Size = UDim2.new(1, -8, 0.3, 0),
			Position = UDim2.new(0.5, 0, 1, -3),
			AnchorPoint = Vector2.new(0.5, 1),
			MaxTextSize = props.MaxTextSize or 20,
			MinTextSize = 10,
			TextColor = props.TextColor,
			ZIndex = face.ZIndex + 1,
			Parent = face,
		})
	elseif props.Icon then
		icon = Style.Icon({
			Text = props.Icon,
			Size = UDim2.fromScale(0.5, 0.8),
			Position = UDim2.new(0, 8, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			ZIndex = face.ZIndex + 1,
			Parent = face,
		})
		label = Style.Label({
			Name = "Label",
			Text = text,
			Size = UDim2.new(1, if text ~= "" then -54 else -12, 0.72, 0),
			Position = UDim2.new(1, -8, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			MaxTextSize = props.MaxTextSize or 26,
			TextColor = props.TextColor,
			ZIndex = face.ZIndex + 1,
			Parent = face,
		})
	else
		label = Style.Label({
			Name = "Label",
			Text = text,
			Size = UDim2.new(1, -14, 0.72, 0),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			MaxTextSize = props.MaxTextSize or 26,
			TextColor = props.TextColor,
			ZIndex = face.ZIndex + 1,
			Parent = face,
		})
	end

	local badge = Style.Label({
		Name = "Badge",
		Text = "!",
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.new(1, 6, 0, -6),
		AnchorPoint = Vector2.new(1, 0),
		MaxTextSize = 18,
		ZIndex = face.ZIndex + 3,
		Parent = holder,
	})
	badge.BackgroundTransparency = 0
	badge.BackgroundColor3 = Style.Colors.Danger
	badge.Visible = false
	Style.Corner(badge, Style.Theme.CornerPill)
	Style.Stroke(badge, Style.Colors.Text, 2)

	local hoverScale = Instance.new("UIScale")
	hoverScale.Name = "Hover"
	hoverScale.Parent = face -- separate from the "Pop" scale on the holder

	local button: Button
	local pressed = false

	local function press(down: boolean)
		if down == pressed then
			return
		end
		pressed = down
		local offset = if down then SHADOW - 1 else 0
		Style.Tween(face, if down then 0.05 else 0.12, { Position = UDim2.fromOffset(0, offset) })
	end

	face.MouseButton1Down:Connect(function()
		if button.Enabled then
			press(true)
		end
	end)
	face.MouseButton1Up:Connect(function()
		press(false)
	end)
	face.MouseLeave:Connect(function()
		press(false)
		Style.Tween(hoverScale, 0.12, { Scale = 1 })
	end)
	face.MouseEnter:Connect(function()
		if button.Enabled then
			Style.Tween(hoverScale, 0.15, { Scale = 1.05 }, Enum.EasingStyle.Back)
		end
	end)
	face.SelectionGained:Connect(function()
		Style.Tween(hoverScale, 0.15, { Scale = 1.06 }, Enum.EasingStyle.Back)
	end)
	face.SelectionLost:Connect(function()
		Style.Tween(hoverScale, 0.12, { Scale = 1 })
	end)

	local activated = Signal.new()
	face.Activated:Connect(function()
		press(false)
		if not button.Enabled then
			SoundController.Play("Error", 1, 0.6)
			Style.Pop(holder, -0.06)
			return
		end
		if props.Sound ~= "" then
			SoundController.Play(props.Sound or "Click", 0.95 + math.random() * 0.1)
		end
		Style.Pop(holder, 0.1)
		activated:Fire()
		if props.OnClick then
			task.spawn(props.OnClick)
		end
	end)

	button = {
		Holder = holder,
		Face = face,
		Shadow = shadow,
		Label = label,
		Icon = icon,
		Badge = badge,
		Enabled = true,
		Color = color,
		Activated = activated,
		SetText = function(self: Button, newText: string)
			self.Label.Text = newText
		end,
		SetIcon = function(self: Button, newIcon: string)
			if self.Icon then
				self.Icon.Text = newIcon
			end
		end,
		SetColor = function(self: Button, newColor: Color3)
			self.Color = newColor
			if self.Enabled then
				face.BackgroundColor3 = newColor
				shadow.BackgroundColor3 = Style.Darken(newColor, 0.4)
			end
		end,
		SetEnabled = function(self: Button, enabled: boolean)
			self.Enabled = enabled
			local c = if enabled then self.Color else Style.Colors.Disabled
			face.BackgroundColor3 = c
			shadow.BackgroundColor3 = Style.Darken(c, 0.4)
			faceStroke.Transparency = if enabled then 0 else 0.3
		end,
		SetBadge = function(self: Button, badgeText: string?)
			local wasVisible = self.Badge.Visible
			self.Badge.Visible = badgeText ~= nil
			if badgeText then
				self.Badge.Text = badgeText
				if not wasVisible then
					Style.PopIn(self.Badge)
				end
			end
		end,
		SetVisible = function(self: Button, visible: boolean)
			self.Holder.Visible = visible
		end,
		Destroy = function(self: Button)
			activated:DisconnectAll()
			self.Holder:Destroy()
		end,
	}

	if props.Parent then
		holder.Parent = props.Parent
	end
	return button
end

return Button
