--!strict
-- SettingsPanel — Music / SFX / Low graphics / Auto Dig toggles (SetSetting) and the Codes box
-- (RedeemCode). Toggles update locally at once; the server persists them in Settings.
-- v2.2 (Status & Social): "Nameplates" toggle (ShowNameplates, StatusController) and an
-- "Invite friends" card (SocialHUD.PromptInvite: Roblox invite dialog, no reward).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Components = script.Parent.Parent.Components
local Style = require(Components.Style)
local Panel = require(Components.Panel)
local Button = require(Components.Button)
local Card = require(Components.Card)
local AtlasIcon = require(Components.AtlasIcon)
local Icons = require(script.Parent.Parent.Icons)
local Toasts = require(script.Parent.Parent.Toasts)
local SocialHUD = require(script.Parent.Parent.SocialHUD)
local State = require(script.Parent.Parent.Parent.Controllers.State)

local SettingsPanel = {}

local C = Style.Colors

type Toggle = { Key: string, Default: boolean, Button: Button.Button, Row: Frame, NeedsPass: string? }

local TOGGLES = {
	{ Key = "Music", Label = "Music", Icon = "music", Default = true },
	{ Key = "SFX", Label = "Sound Effects", Icon = "sfx", Default = true },
	{ Key = "LowGraphics", Label = "Low Graphics", Icon = "settings|📱", Default = false },
	{ Key = "ShowNameplates", Label = "Nameplates", Icon = "star", Default = true },
	{ Key = "AutoDig", Label = "Auto Dig", Icon = "AutoDig", Default = false, NeedsPass = "AutoDig" },
}

local panel: Panel.Panel
local built = false
local toggles: { Toggle } = {}
local codeBox: TextBox

local function refresh()
	if not built then
		return
	end
	for _, toggle in toggles do
		local on = State.GetSetting(toggle.Key, toggle.Default) == true
		toggle.Button:SetColor(if on then C.Success else C.Danger)
		toggle.Button:SetText(if on then "ON" else "OFF")
		if toggle.NeedsPass then
			local owns = State.OwnsPass(toggle.NeedsPass :: string)
			toggle.Row.Visible = owns
		end
	end
end

local function redeem()
	local code = string.gsub(codeBox.Text, "^%s+", "")
	code = string.gsub(code, "%s+$", "")
	if code == "" then
		Toasts.Show("Type a code first! 🎟️", "Info")
		return
	end
	Remotes.Get("RedeemCode"):FireServer(code)
	codeBox.Text = ""
end

local function build()
	if built then
		return
	end
	built = true
	local body = panel.Body
	local list = Panel.Scroller(body)
	Style.List(list, Enum.FillDirection.Vertical, 8)
	for i, def in TOGGLES do
		local card =
			Card.new({ Name = def.Key, Size = UDim2.new(1, -16, 0, 84), LayoutOrder = i, ZIndex = 6, Parent = list })
		AtlasIcon.new({
			Icon = def.Icon,
			Size = UDim2.fromOffset(52, 52),
			Position = UDim2.new(0, 10, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			ZIndex = 8,
			Parent = card.Face,
		})
		Style.Label({
			Text = def.Label,
			Size = UDim2.new(1, -230, 0.6, 0),
			Position = UDim2.new(0, 70, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			StrokeThickness = 2,
			MaxTextSize = 24,
			XAlign = Enum.TextXAlignment.Left,
			ZIndex = 8,
			Parent = card.Face,
		})
		local button = Button.new({
			Text = "ON",
			Size = UDim2.fromOffset(140, 74),
			Position = UDim2.new(1, -10, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Color = C.Success,
			ZIndex = 8,
			Parent = card.Face,
			OnClick = function()
				local on = State.GetSetting(def.Key, def.Default) == true
				State.SetSetting(def.Key, not on)
			end,
		})
		table.insert(
			toggles,
			{ Key = def.Key, Default = def.Default, Button = button, Row = card.Holder, NeedsPass = def.NeedsPass }
		)
	end

	local invite = Card.new({
		Name = "Invite",
		Size = UDim2.new(1, -16, 0, 84),
		LayoutOrder = 90,
		Color = C.NavyCardDark,
		ZIndex = 6,
		Parent = list,
	})
	AtlasIcon.new({
		Icon = "👫",
		Size = UDim2.fromOffset(52, 52),
		Position = UDim2.new(0, 10, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		ZIndex = 8,
		Parent = invite.Face,
	})
	Style.Label({
		Text = string.format(
			"Dig with friends: +%d%% sand each (up to +%d%%)!",
			math.floor(Config.FRIEND_BONUS_PER_FRIEND * 100 + 0.5),
			math.floor(Config.FRIEND_BONUS_MAX * 100 + 0.5)
		),
		Size = UDim2.new(1, -250, 0.7, 0),
		Position = UDim2.new(0, 70, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		StrokeThickness = 2,
		MaxTextSize = 22,
		Wrapped = true,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 8,
		Parent = invite.Face,
	})
	Button.new({
		Name = "InviteButton",
		Text = "Invite",
		Size = UDim2.fromOffset(160, 74),
		Position = UDim2.new(1, -10, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Color = C.Coral,
		ZIndex = 8,
		Parent = invite.Face,
		OnClick = function()
			SocialHUD.PromptInvite()
		end,
	})

	local codes = Card.new({
		Name = "Codes",
		Size = UDim2.new(1, -16, 0, 136),
		LayoutOrder = 100,
		Color = C.NavyCardDark,
		ZIndex = 6,
		Parent = list,
	})
	Style.Label({
		Text = "Codes",
		Size = UDim2.new(1, -70, 0, 30),
		Position = UDim2.fromOffset(56, 8),
		StrokeThickness = 2,
		MaxTextSize = 24,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 8,
		Parent = codes.Face,
	})
	AtlasIcon.new({
		Icon = "codes",
		Size = UDim2.fromOffset(38, 38),
		Position = UDim2.fromOffset(12, 4),
		AnchorPoint = Vector2.zero,
		ZIndex = 8,
		Parent = codes.Face,
	})
	codeBox = Instance.new("TextBox")
	codeBox.Name = "CodeBox"
	codeBox.PlaceholderText = "Enter code (try SANDY!)"
	codeBox.Text = ""
	codeBox.ClearTextOnFocus = false
	codeBox.Font = Style.Fonts.Title
	codeBox.TextScaled = true
	codeBox.TextColor3 = C.Text
	codeBox.PlaceholderColor3 = C.Disabled
	codeBox.BackgroundColor3 = C.NavyDark
	codeBox.Size = UDim2.new(1, -190, 0, 62)
	codeBox.Position = UDim2.fromOffset(14, 50)
	codeBox.ZIndex = 8
	codeBox.Parent = codes.Face
	Style.Corner(codeBox, Style.Theme.CornerMedium)
	Style.Stroke(codeBox, C.Stroke, 3)
	Style.Padding(codeBox, 8, 12)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 26
	constraint.Parent = codeBox
	codeBox.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then
			redeem()
		end
	end)
	Button.new({
		Text = "Redeem",
		Size = UDim2.fromOffset(150, 76),
		Position = UDim2.new(1, -12, 0, 44),
		AnchorPoint = Vector2.new(1, 0),
		Color = C.Palm,
		ZIndex = 8,
		Parent = codes.Face,
		OnClick = redeem,
	})
end

function SettingsPanel.Init()
	panel = Panel.new({
		Name = "Settings",
		Title = "Settings",
		Icon = Icons.Settings,
		Color = C.OceanDark,
		Size = Vector2.new(620, 470),
	})
	panel.Opened:Connect(function()
		build()
		refresh()
	end)
	State.ObserveMany({ "Settings", "Passes" }, refresh)
end

return SettingsPanel
