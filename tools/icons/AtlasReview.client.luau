--!strict
-- Isolated review only: no production services, remotes or player data.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local Atlas = require(ReplicatedStorage.Shared.Config.IconAtlas)
local ui = script.Parent:WaitForChild("UI")
script.Parent:WaitForChild("Util"):WaitForChild("Signal")
local AtlasIcon = require(ui:WaitForChild("Components"):WaitForChild("AtlasIcon"))

local gui = Instance.new("ScreenGui")
gui.Name = "AtlasReview"
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
local root = Instance.new("Frame")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = Color3.fromRGB(15, 29, 49)
root.Parent = gui
local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, 0, 0, 48)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(255, 236, 206)
status.TextSize = 18
status.Text = "Atlas delivery pending — emoji indicates fallback, not a passed crop"
status.Parent = root
local scroll = Instance.new("ScrollingFrame")
scroll.Position = UDim2.fromOffset(0, 48)
scroll.Size = UDim2.new(1, 0, 1, -48)
scroll.BackgroundTransparency = 1
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new()
scroll.ScrollBarThickness = 8
scroll.Parent = root
local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.fromOffset(148, 108)
grid.CellPadding = UDim2.fromOffset(8, 8)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = scroll
local images: { ImageLabel } = {}
local keys = {}
for key in Atlas.Icons do
	table.insert(keys, key)
end
table.sort(keys, function(a, b)
	local x, y = Atlas.Icons[a], Atlas.Icons[b]
	return x.Y * 1024 + x.X < y.Y * 1024 + y.X
end)
for order, key in keys do
	local card = Instance.new("Frame")
	card.Name = key
	card.LayoutOrder = order
	card.BackgroundColor3 = Color3.fromRGB(36, 54, 74)
	card.Parent = scroll
	for index, size in { 24, 32, 48 } do
		local icon = AtlasIcon.new({
			Icon = key,
			Size = UDim2.fromOffset(size, size),
			Position = UDim2.fromOffset(({ 20, 62, 116 })[index], 34),
			Parent = card,
		})
		local image = icon.Frame:FindFirstChild("Image")
		if image and image:IsA("ImageLabel") then
			table.insert(images, image)
		end
	end
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 36)
	label.Position = UDim2.fromOffset(0, 66)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 236, 206)
	label.TextSize = 13
	label.Text = key .. "\n24 / 32 / 48 px"
	label.Parent = card
end
task.spawn(function()
	local ok, err = pcall(function()
		ContentProvider:PreloadAsync(images, function(id, result)
			print("[AtlasReview]", id, result.Name)
		end)
	end)
	if not ok then
		warn("[AtlasReview] preload failed:", err)
	end
end)
task.spawn(function()
	while gui.Parent do
		local loaded = 0
		for _, image in images do
			if image.IsLoaded then
				loaded += 1
			end
		end
		status.Text = string.format(
			"%s — %d/%d loaded slots | 64 crops, each at 24 / 32 / 48 px",
			Atlas.AssetId,
			loaded,
			#images
		)
		gui:SetAttribute("LoadedSlots", loaded)
		gui:SetAttribute("TotalSlots", #images)
		task.wait(1)
	end
end)
