--!strict
--[[
	Announcements — server-wide brags as a big gold banner across the top of the screen (v2.2
	B6c, Status & Social agent). The server's Notify("Announce", text) is routed here by Toasts
	(Toasts.SetRoute), e.g.
		"Sandy found a LEGENDARY Golden Idol!"   (DigService)
		"Sandy hatched a MYTHIC Mega Excavator!" (PetService)
		"SERVER GOAL REACHED! ..."               (ServerGoalService)
	Find / hatch texts are parsed so the rarity word gets its own pill in the rarity colour and
	the banner's outline glows in it; anything else shows as a plain gold banner.

	Rate limit: one banner at a time for Config.Social.Announce.Duration seconds, a short gap
	between them, at most MaxQueued waiting (the oldest are dropped, duplicates are merged).
	A soft chime (RareTreasure, quieter and higher) plays with each banner.

	API: Announcements.Show(text), Announcements.Parse(text), Announcements.QueueLength(),
	     Announcements.IsShowing()
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Root = require(script.Parent.Root)
local Style = require(script.Parent.Components.Style)
local AtlasIcon = require(script.Parent.Components.AtlasIcon)
local Layout = require(script.Parent.Layout)
local Toasts = require(script.Parent.Toasts)
local UIEffects = require(script.Parent.UIEffects)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local Announcements = {}

export type Parsed = {
	Player: string,
	Verb: string, -- "found" | "hatched"
	Rarity: string, -- "Legendary"
	Item: string,
}

local SETTINGS = Config.Social.Announce
local WIDTH, HEIGHT = 560, 92

local queue: { string } = {}
local showing = false

-- "Sandy found a LEGENDARY Golden Idol!" -> { Player, Verb, Rarity = "Legendary", Item }.
function Announcements.Parse(text: string): Parsed?
	local who, verb, rarity, item = string.match(text, "^(.-) (%a+) an? (%u+) (.-)!$")
	if who == nil or verb == nil or rarity == nil or item == nil then
		return nil
	end
	local w, v, r, i = who :: string, verb :: string, rarity :: string, item :: string
	if w == "" or i == "" or (v ~= "found" and v ~= "hatched") then
		return nil
	end
	local name = string.upper(string.sub(r, 1, 1)) .. string.lower(string.sub(r, 2))
	if not Config.GetRarity(name) then
		return nil
	end
	local parsed: Parsed = { Player = w, Verb = v, Rarity = name, Item = i }
	return parsed
end

local function build(text: string): Frame
	local parsed = Announcements.Parse(text)
	local rarity = if parsed then Config.GetRarity(parsed.Rarity) else nil
	local accent = if rarity then rarity.Color else Style.Colors.Sunset
	local gold = Style.Colors.Gold

	local holder = Instance.new("Frame")
	holder.Name = "Announcement"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Size = UDim2.fromOffset(WIDTH, HEIGHT + 22)
	-- over the toast column, under the objective pill + event chips
	holder.Position = UDim2.new(0.5, 0, 0, Layout.Current().Toasts.Y - 4)
	holder.ZIndex = 30
	holder.Parent = Root.Get("Popups")

	local ribbon = Instance.new("Frame")
	ribbon.Name = "Ribbon"
	ribbon.Size = UDim2.new(1, 0, 0, HEIGHT - 20)
	ribbon.Position = UDim2.fromOffset(0, 22)
	ribbon.BackgroundColor3 = Color3.new(1, 1, 1)
	ribbon.ZIndex = 31
	ribbon.Parent = holder
	Style.Corner(ribbon, Style.Theme.CornerLarge)
	Style.Stroke(ribbon, Style.Colors.Stroke, 4)
	Style.Gradient(ribbon, { Style.Lighten(gold, 0.35), gold, Style.Darken(gold, 0.2) }, 90)
	Style.Gloss(ribbon, Style.Theme.CornerMedium, 31)
	-- inner glow ring in the rarity colour
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.BackgroundTransparency = 1
	glow.Size = UDim2.new(1, -8, 1, -8)
	glow.Position = UDim2.fromOffset(4, 4)
	glow.ZIndex = 32
	glow.Parent = ribbon
	Style.Corner(glow, Style.Theme.CornerMedium)
	Style.Stroke(glow, accent, 3)

	local icon = if parsed and parsed.Verb == "hatched" then "egg_hatch" elseif parsed then "treasure" else "trophy"
	AtlasIcon.new({
		Name = "AnnounceIcon",
		Icon = icon,
		Size = UDim2.fromOffset(84, 84),
		Position = UDim2.new(0, -18, 0.5, -2),
		AnchorPoint = Vector2.new(0, 0.5),
		Rotation = -8,
		ZIndex = 34,
		Parent = ribbon,
	})

	local body = text
	if parsed then
		local hex = "#" .. Style.Lighten(accent, 0.15):ToHex()
		local article = if string.find(string.lower(string.sub(parsed.Rarity, 1, 1)), "[aeiou]") then "an" else "a"
		body = string.format(
			'%s %s %s <font color="%s">%s %s</font>!',
			parsed.Player,
			parsed.Verb,
			article,
			hex,
			parsed.Rarity,
			parsed.Item
		)
	end
	Style.Label({
		Name = "Text",
		Text = body,
		RichText = parsed ~= nil,
		Size = UDim2.new(1, -96, 0.84, 0),
		Position = UDim2.new(0, 72, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		MaxTextSize = 28,
		StrokeThickness = 3,
		Wrapped = true,
		ZIndex = 33,
		Parent = ribbon,
	})

	local tagText = if parsed then string.upper(parsed.Rarity) .. "!" else "SERVER"
	local tag = Style.Label({
		Name = "Tag",
		Text = tagText,
		Size = UDim2.fromOffset(170, 32),
		Position = UDim2.new(0.5, 0, 0, 4),
		AnchorPoint = Vector2.new(0.5, 0),
		MaxTextSize = 22,
		ZIndex = 35,
		Parent = holder,
	})
	tag.BackgroundTransparency = 0
	tag.BackgroundColor3 = accent
	Style.Corner(tag, Style.Theme.CornerPill)
	Style.Stroke(tag, Style.Colors.Stroke, 3)
	return holder
end

local function pump()
	if showing or #queue == 0 then
		return
	end
	showing = true
	local text = table.remove(queue, 1) :: string
	local holder = build(text)
	SoundController.Play("RareTreasure", 1.3, 0.45) -- soft chime, not the full "you found it" sting
	local scale = Style.GetPopScale(holder)
	scale.Scale = 0.3
	Style.Tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local parsed = Announcements.Parse(text)
	if parsed and parsed.Rarity == "Mythic" then
		UIEffects.Confetti(24)
	end
	task.delay(SETTINGS.Duration, function()
		local out = Style.Tween(scale, 0.3, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		out.Completed:Once(function()
			holder:Destroy()
			task.delay(SETTINGS.Gap, function()
				showing = false
				pump()
			end)
		end)
	end)
end

function Announcements.Show(text: string)
	if text == "" then
		return
	end
	for _, queued in queue do
		if queued == text then
			return -- same brag twice (e.g. a retry): show it once
		end
	end
	table.insert(queue, text)
	while #queue > SETTINGS.MaxQueued do
		table.remove(queue, 1)
	end
	pump()
end

function Announcements.QueueLength(): number
	return #queue
end

function Announcements.IsShowing(): boolean
	return showing
end

function Announcements.Init()
	Toasts.SetRoute("Announce", Announcements.Show)
end

return Announcements
