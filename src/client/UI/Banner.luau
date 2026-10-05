--!strict
--[[
	Banner — big centre-screen announcements, queued one at a time:
	- ShowLayer(index, isNew): "Welcome to the Pirate Cove! 🏴‍☠️" + layer FlavorText, ribbon in
	  the layer colour (isNew adds "NEW LAYER!" + confetti).
	- Show({ Title, Subtitle, Color, Icon }) for rebirths, milestones, events.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Root = require(script.Parent.Root)
local Style = require(script.Parent.Components.Style)
local Icons = require(script.Parent.Icons)
local UIEffects = require(script.Parent.UIEffects)
local State = require(script.Parent.Parent.Controllers.State)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local Banner = {}

export type BannerSpec = {
	Title: string,
	Subtitle: string?,
	Tag: string?, -- small pill above the title ("NEW LAYER!")
	Color: Color3?,
	Duration: number?,
	Sound: string?,
	Confetti: boolean?,
}

local queue: { BannerSpec } = {}
local showing = false

local function build(spec: BannerSpec): Frame
	local color = spec.Color or Style.Colors.Ocean
	local holder = Instance.new("Frame")
	holder.Name = "Banner"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(620, 150)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.3)
	holder.ZIndex = 20
	holder.Parent = Root.Get("Popups")

	local ribbon = Instance.new("Frame")
	ribbon.Name = "Ribbon"
	ribbon.Size = UDim2.new(1, 0, 0, 74)
	ribbon.Position = UDim2.fromOffset(0, 26)
	ribbon.BackgroundColor3 = Color3.new(1, 1, 1)
	ribbon.ZIndex = 21
	ribbon.Parent = holder
	Style.Corner(ribbon, Style.Theme.CornerLarge)
	Style.Stroke(ribbon, Style.Colors.Stroke, 4)
	Style.Gradient(ribbon, { Style.Lighten(color, 0.35), color, Style.Darken(color, 0.25) }, 90)

	Style.Label({
		Name = "Title",
		Text = spec.Title,
		Size = UDim2.new(1, -30, 0.8, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		MaxTextSize = 44,
		StrokeThickness = 3,
		ZIndex = 22,
		Parent = ribbon,
	})

	if spec.Tag then
		local tag = Style.Label({
			Name = "Tag",
			Text = spec.Tag,
			Size = UDim2.fromOffset(200, 34),
			Position = UDim2.new(0.5, 0, 0, 10),
			AnchorPoint = Vector2.new(0.5, 0),
			MaxTextSize = 22,
			ZIndex = 24,
			Parent = holder,
		})
		tag.BackgroundTransparency = 0
		tag.BackgroundColor3 = Style.Colors.Coral
		Style.Corner(tag, Style.Theme.CornerPill)
		Style.Stroke(tag, Style.Colors.Stroke, 3)
	end

	if spec.Subtitle and spec.Subtitle ~= "" then
		local sub = Style.Label({
			Name = "Subtitle",
			Text = spec.Subtitle,
			Size = UDim2.new(0.92, 0, 0, 46),
			Position = UDim2.new(0.5, 0, 0, 104),
			AnchorPoint = Vector2.new(0.5, 0),
			MaxTextSize = 20,
			Font = Style.Fonts.Body,
			Wrapped = true,
			ZIndex = 22,
			Parent = holder,
		})
		sub.BackgroundTransparency = 0.25
		sub.BackgroundColor3 = Style.Colors.Stroke
		Style.Corner(sub, Style.Theme.CornerMedium)
		Style.Padding(sub, 4, 12)
	end
	return holder
end

local function pump()
	if showing or #queue == 0 then
		return
	end
	showing = true
	local spec = table.remove(queue, 1) :: BannerSpec
	local holder = build(spec)
	if spec.Sound ~= "" then
		SoundController.Play(spec.Sound or "NewLayer")
	end
	if spec.Confetti then
		UIEffects.Confetti(36)
	end
	local scale = Style.GetPopScale(holder)
	scale.Scale = 0.2
	Style.Tween(scale, 0.5, { Scale = 1 }, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
	task.delay(spec.Duration or 3.4, function()
		Style.Tween(
			holder,
			0.35,
			{ Position = UDim2.fromScale(0.5, 0.12) },
			Enum.EasingStyle.Back,
			Enum.EasingDirection.In
		)
		local out = Style.Tween(scale, 0.35, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		out.Completed:Once(function()
			holder:Destroy()
			showing = false
			pump()
		end)
	end)
end

function Banner.Show(spec: BannerSpec)
	-- drop stale duplicates
	for i = #queue, 1, -1 do
		if queue[i].Title == spec.Title then
			table.remove(queue, i)
		end
	end
	table.insert(queue, spec)
	if #queue > 3 then
		table.remove(queue, 1)
	end
	pump()
end

function Banner.ShowLayer(index: number, isNew: boolean?)
	local layer = Config.Layers[index]
	if not layer then
		return
	end
	local article = if string.sub(layer.Name, 1, 4) == "The " then "" else "the "
	local subtitle = layer.FlavorText
	if State.GetShovel().Power < layer.Hardness then
		subtitle = "Too hard for your shovel! Needs 💪 " .. layer.Hardness .. " power."
	end
	Banner.Show({
		Title = "Welcome to " .. article .. layer.Name .. "! " .. Icons.Layer(layer.Id),
		Subtitle = subtitle,
		Tag = if isNew then "NEW LAYER!" else Config.DepthToMeters(layer.DepthStart) .. "m deep",
		Color = layer.Color,
		Sound = "NewLayer",
		Confetti = isNew == true,
		Duration = if isNew then 4 else 3,
	})
end

return Banner
