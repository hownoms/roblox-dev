--!strict
--[[
	Button — chunky "toy" button (docs/UI_STYLE.md): a darker base lip under a bright face with
	a soft gloss strip along its top third, a thick dark outline on both, rounded corners, an
	atlas icon (AtlasIcon, emoji fallback) and outlined text. Pressing sinks the face onto the
	lip, hover grows it slightly, clicks play the Click sound. Gamepad-selectable (TextButton
	face named "Face").

	Layouts:
	  Vertical = true   oversized icon (~70% of the face, may poke over the top edge) with the
	                    outlined caption across the bottom edge (HUD menu style)
	  Icon only/inline  icon on the left, text on the right (prices: Icon = "Coins")
	  text only         centred caption
	Never make one smaller than Theme.MinTouchSize design px (44 real px at UI scale 0.6); a
	small visual can keep a bigger touch area with HitPadding (invisible "HitArea" button).
]]
local Style = require(script.Parent.Style)
local AtlasIcon = require(script.Parent.AtlasIcon)
local Signal = require(script.Parent.Parent.Parent.Util.Signal)
local SoundController = require(script.Parent.Parent.Parent.Controllers.SoundController)

local Button = {}

local LIP = 6

export type ButtonProps = {
	Name: string?,
	Parent: Instance?,
	Text: string?,
	Icon: string?, -- AtlasIcon key: atlas name, Icons.luau key, "Group.key" or emoji
	Color: Color3?,
	TextColor: Color3?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	MaxTextSize: number?,
	Vertical: boolean?, -- big icon above an outlined caption (HUD menu style)
	Round: boolean?, -- pill/circle corners (top-right round buttons)
	Corner: UDim?,
	ZIndex: number?,
	HitPadding: number?, -- extra invisible touch area around the button (design px)
	Sound: string?, -- default "Click"; "" for silent
	OnClick: (() -> ())?,
}

export type Button = {
	Holder: Frame,
	Face: TextButton,
	Shadow: Frame,
	Label: TextLabel,
	Icon: AtlasIcon.AtlasIcon?,
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
	local corner = props.Corner or (if props.Round then Style.Theme.CornerPill else UDim.new(0, 10))
	local z = props.ZIndex or 1

	local holder = Instance.new("Frame")
	holder.Name = props.Name or "Button"
	holder.BackgroundTransparency = 1
	holder.Size = props.Size or UDim2.fromOffset(160, 56)
	holder.Position = props.Position or UDim2.new()
	holder.AnchorPoint = props.AnchorPoint or Vector2.zero
	holder.LayoutOrder = props.LayoutOrder or 0
	holder.ZIndex = z

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 0, 1, -LIP)
	shadow.Position = UDim2.fromOffset(0, LIP)
	shadow.BackgroundColor3 = Style.Darken(color, 0.45)
	shadow.BorderSizePixel = 0
	shadow.ZIndex = z
	shadow.Parent = holder
	Style.Corner(shadow, corner)
	Style.Stroke(shadow, Style.Colors.Stroke, 3)

	local face = Instance.new("TextButton")
	face.Name = "Face"
	face.Text = ""
	face.AutoButtonColor = false
	face.Size = UDim2.new(1, 0, 1, -LIP)
	face.Position = UDim2.fromOffset(0, 0)
	face.BackgroundColor3 = color
	face.BorderSizePixel = 0
	face.ZIndex = z + 1
	face.Parent = holder
	Style.Corner(face, corner)
	local faceStroke = Style.Stroke(face, Style.Colors.Stroke, 3)
	local gloss = Style.Gloss(face, if props.Round then Style.Theme.CornerPill else UDim.new(0, 7), z + 1)

	local icon: AtlasIcon.AtlasIcon? = nil
	local label: TextLabel
	local text = props.Text or ""
	local maxText = props.MaxTextSize or 26
	local function caption(size: UDim2, position: UDim2, anchor: Vector2, max: number, min: number?): TextLabel
		return Style.Label({
			Name = "Label",
			Text = text,
			Size = size,
			Position = position,
			AnchorPoint = anchor,
			MaxTextSize = max,
			MinTextSize = min,
			TextColor = props.TextColor,
			StrokeThickness = if max >= 22 then 3 else 2,
			ZIndex = z + 3,
			Parent = face,
		})
	end
	if props.Icon and props.Vertical then
		-- Oversized icon (pokes a little over the top edge) + caption on the bottom edge.
		local hasText = text ~= ""
		icon = AtlasIcon.new({
			Icon = props.Icon,
			Size = UDim2.fromScale(if hasText then 0.86 else 0.9, if hasText then 0.74 else 0.9),
			Position = UDim2.fromScale(0.5, if hasText then 0.34 else 0.47),
			ZIndex = z + 2,
			Parent = face,
		})
		label = caption(
			UDim2.new(1, -4, 0.32, 0),
			UDim2.new(0.5, 0, 1, -2),
			Vector2.new(0.5, 1),
			props.MaxTextSize or 20,
			10
		)
	elseif props.Icon then
		icon = AtlasIcon.new({
			Icon = props.Icon,
			Size = UDim2.fromScale(0.5, 0.86),
			Position = UDim2.new(0, 6, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			ZIndex = z + 2,
			Parent = face,
		})
		label = caption(
			UDim2.new(1, if text ~= "" then -56 else -12, 0.7, 0),
			UDim2.new(1, -8, 0.5, 0),
			Vector2.new(1, 0.5),
			maxText
		)
	else
		label = caption(UDim2.new(1, -14, 0.7, 0), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), maxText)
	end

	local badge = Style.Label({
		Name = "Badge",
		Text = "!",
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(1, 8, 0, -8),
		AnchorPoint = Vector2.new(1, 0),
		MaxTextSize = 20,
		StrokeThickness = 2,
		ZIndex = z + 5,
		Parent = holder,
	})
	badge.BackgroundTransparency = 0
	badge.BackgroundColor3 = Style.Colors.Danger
	badge.Visible = false
	Style.Corner(badge, Style.Theme.CornerPill)
	local badgeRing = Instance.new("UIStroke")
	badgeRing.Color = Style.Colors.Stroke
	badgeRing.Thickness = 2.5
	badgeRing.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	badgeRing.Parent = badge

	local hoverScale = Instance.new("UIScale")
	hoverScale.Name = "Hover"
	hoverScale.Parent = face -- separate from the "Pop" scale on the holder

	local button: Button
	local pressed = false
	local focused = false

	local function press(down: boolean)
		if down == pressed then
			return
		end
		pressed = down
		local offset = if down then LIP - 1 else 0
		Style.Tween(face, if down then 0.05 else 0.12, { Position = UDim2.fromOffset(0, offset) })
	end

	local activated = Signal.new()
	local function activate()
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
		focused = true
		faceStroke.Color = Style.Colors.Gold
		faceStroke.Thickness = 4
		Style.Tween(hoverScale, 0.15, { Scale = 1.06 }, Enum.EasingStyle.Back)
	end)
	face.SelectionLost:Connect(function()
		focused = false
		faceStroke.Color = Style.Colors.Stroke
		faceStroke.Thickness = 3
		Style.Tween(hoverScale, 0.12, { Scale = 1 })
	end)
	face.Activated:Connect(activate)

	if props.HitPadding and props.HitPadding > 0 then
		-- Bigger invisible touch target behind the face (small round HUD buttons).
		local pad = props.HitPadding :: number
		local hit = Instance.new("TextButton")
		hit.Name = "HitArea"
		hit.Text = ""
		hit.BackgroundTransparency = 1
		hit.Selectable = false
		hit.AutoButtonColor = false
		hit.Size = UDim2.new(1, pad * 2, 1, pad * 2)
		hit.Position = UDim2.fromScale(0.5, 0.5)
		hit.AnchorPoint = Vector2.new(0.5, 0.5)
		hit.ZIndex = z
		hit.Parent = holder
		hit.Activated:Connect(activate)
	end

	local function paint(c: Color3, enabled: boolean)
		face.BackgroundColor3 = c
		shadow.BackgroundColor3 = Style.Darken(c, 0.45)
		faceStroke.Transparency = if enabled then 0 else 0.25
		faceStroke.Color = if focused then Style.Colors.Gold else Style.Colors.Stroke
		gloss.Visible = enabled
	end

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
			local current = self.Icon
			if current and current.Key ~= newIcon then
				current:Set(newIcon)
			end
		end,
		SetColor = function(self: Button, newColor: Color3)
			self.Color = newColor
			if self.Enabled then
				paint(newColor, true)
			end
		end,
		SetEnabled = function(self: Button, enabled: boolean)
			self.Enabled = enabled
			paint(if enabled then self.Color else Style.Colors.Disabled, enabled)
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
