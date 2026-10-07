--!strict
-- One selected asset at a time: full collection remains native-size in the world.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
-- Chat overlays the review controls in narrow Studio windows; isolated diagnostic only.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
end)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("GalleryCatalog"))
-- StarterPlayerScripts siblings can arrive after this LocalScript starts.
-- Viewport requires Controllers.State synchronously, so wait for that dependency too.
local scripts = script.Parent
scripts:WaitForChild("Controllers"):WaitForChild("State")
local components = scripts:WaitForChild("UI"):WaitForChild("Components")
local Viewport = require(components:WaitForChild("Viewport"))
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "GalleryReview"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local root = Instance.new("Frame")
root.Size = UDim2.fromOffset(1074, 580)
root.AnchorPoint = Vector2.new(1, 0)
root.Position = UDim2.new(1, -12, 0, 12)
root.BackgroundTransparency = 1
root.Parent = gui
local scale = Instance.new("UIScale")
scale.Parent = root
local function resize()
	local camera = workspace.CurrentCamera
	if camera then
		local available = camera.ViewportSize
		scale.Scale = math.min(1, (available.X - 24) / 1074, (available.Y - 60) / 580)
	end
end
local camera = workspace.CurrentCamera
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
end
resize()
local savedCameraType: Enum.CameraType? = nil
local savedCameraFrame: CFrame? = nil
local nativeReturn = Instance.new("TextButton")
nativeReturn.Text = "Return to previews"
nativeReturn.Size = UDim2.fromOffset(180, 36)
nativeReturn.Position = UDim2.new(0, 12, 1, -44)
nativeReturn.Font = Enum.Font.GothamBold
nativeReturn.TextSize = 14
nativeReturn.Visible = false
nativeReturn.Parent = gui
local function restoreCamera()
	local current = workspace.CurrentCamera
	if current and savedCameraType then
		current.CameraType = savedCameraType
		if savedCameraFrame then
			current.CFrame = savedCameraFrame
		end
	end
	savedCameraType, savedCameraFrame = nil, nil
	nativeReturn.Visible = false
	root.Visible = true
end
nativeReturn.Activated:Connect(restoreCamera)
local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(450, 434)
panel.Position = UDim2.fromOffset(624, 0)
panel.BackgroundColor3 = Color3.fromRGB(25, 42, 63)
panel.Parent = root

local function text(value: string, position: UDim2, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Text = value
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(255, 239, 201)
	label.BackgroundTransparency = 1
	label.TextWrapped = true
	label.Parent = panel
	return label
end

local title = text("", UDim2.fromOffset(8, 4), UDim2.fromOffset(434, 42))
local previews: { Viewport.Viewport } = {}
local x = 12
for _, pixels in { 48, 120, 240 } do
	text(tostring(pixels) .. " px", UDim2.fromOffset(x, 48), UDim2.fromOffset(pixels, 24))
	local preview = Viewport.new({
		Parent = panel,
		Position = UDim2.fromOffset(x, 76),
		Size = UDim2.fromOffset(pixels, pixels),
		Spin = false,
	})
	table.insert(previews, preview)
	x += pixels + 8
end

local index = 1
local showContact: () -> ()
local clearContact: () -> ()
local function selectEntry(nextIndex: number)
	index = (nextIndex - 1) % #Catalog + 1
	local entry = Catalog[index]
	title.Text = string.format("%d / %d · %s / %s\n%s", index, #Catalog, entry.Category, entry.Name, entry.Id)
	for _, preview in previews do
		preview:SetModel(entry.Build(entry.Id))
	end
end

local function button(label: string, offset: number, action: () -> ())
	local control = Instance.new("TextButton")
	control.Text = label
	control.Font = Enum.Font.GothamBold
	control.TextSize = 14
	control.TextColor3 = Color3.fromRGB(25, 42, 63)
	control.BackgroundColor3 = Color3.fromRGB(255, 239, 201)
	control.Position = UDim2.fromOffset(offset, 334)
	control.Size = UDim2.fromOffset(116, 32)
	control.Parent = panel
	control.Activated:Connect(action)
end

button("Previous", 12, function()
	selectEntry(index - 1)
end)
button("Next", 140, function()
	selectEntry(index + 1)
end)
button("Visit native", 268, function()
	local gallery = workspace:FindFirstChild("AssetGallery")
	local character = player.Character
	if not gallery or not character then
		return
	end
	for _, pad in gallery:GetChildren() do
		if pad:IsA("BasePart") and pad:GetAttribute("GalleryIndex") == index then
			character:PivotTo(pad.CFrame * CFrame.new(0, 4, -12))
			local current = workspace.CurrentCamera
			if current then
				for _, model in gallery:GetChildren() do
					if model:IsA("Model") and model:GetAttribute("GalleryIndex") == index then
						local bounds, size = model:GetBoundingBox()
						local aspect = current.ViewportSize.X / math.max(1, current.ViewportSize.Y)
						local vertical = math.rad(current.FieldOfView / 2)
						local halfFov = math.min(vertical, math.atan(math.tan(vertical) * aspect))
						local distance = math.max(3, size.Magnitude / 2 / math.sin(halfFov) / 0.75)
						savedCameraType, savedCameraFrame = current.CameraType, current.CFrame
						current.CameraType = Enum.CameraType.Scriptable
						current.CFrame =
							CFrame.lookAt(bounds.Position + Vector3.new(0.5, 0.35, -1).Unit * distance, bounds.Position)
						root.Visible = false
						nativeReturn.Visible = true
						break
					end
				end
			end
			return
		end
	end
end)
text(
	"Static production Viewport · no player data / gameplay services",
	UDim2.fromOffset(8, 368),
	UDim2.fromOffset(434, 24)
)

local contact = Instance.new("Frame")
contact.Size = UDim2.fromOffset(610, 580)
contact.BackgroundColor3 = panel.BackgroundColor3
contact.Parent = root
local contactTitle = text("", UDim2.fromOffset(8, 4), UDim2.fromOffset(594, 38))
contactTitle.Parent = contact
local cells = Instance.new("Frame")
cells.Position = UDim2.fromOffset(12, 96)
cells.Size = UDim2.fromOffset(586, 474)
cells.BackgroundTransparency = 1
cells.Parent = contact
local categories: { string } = {}
local byCategory: { { number } } = {}
for entryIndex, entry in Catalog do
	if categories[#categories] ~= entry.Category then
		table.insert(categories, entry.Category)
		table.insert(byCategory, {})
	end
	table.insert(byCategory[#byCategory], entryIndex)
end
local categoryIndex, page = 1, 1
local pagePreviews: { Viewport.Viewport } = {}
clearContact = function()
	for _, preview in pagePreviews do
		preview:SetModel(nil)
	end
	table.clear(pagePreviews)
	cells:ClearAllChildren()
end

showContact = function()
	clearContact()
	panel.Visible = false
	for _, preview in previews do
		preview:SetModel(nil)
	end
	contact.Visible = true
	local entries = byCategory[categoryIndex]
	local pages = math.ceil(#entries / 12)
	page = math.clamp(page, 1, pages)
	contactTitle.Text = string.format(
		"%s · category %d / %d · page %d / %d\n%d assets in category · %d total · click an asset for native / 48 / 120 / 240 px",
		categories[categoryIndex],
		categoryIndex,
		#categories,
		page,
		pages,
		#entries,
		#Catalog
	)
	for slot = 1, 12 do
		local entryIndex = entries[(page - 1) * 12 + slot]
		if not entryIndex then
			break
		end
		local entry = Catalog[entryIndex]
		local card = Instance.new("TextButton")
		card.Text = ""
		card.Size = UDim2.fromOffset(140, 150)
		card.Position = UDim2.fromOffset((slot - 1) % 4 * 148, math.floor((slot - 1) / 4) * 158)
		card.BackgroundColor3 = Color3.fromRGB(40, 59, 79)
		card.Parent = cells
		local preview = Viewport.new({
			Parent = card,
			Size = UDim2.fromOffset(96, 96),
			Position = UDim2.fromOffset(22, 2),
			Spin = false,
		})
		preview:SetModel(entry.Build(entry.Id))
		table.insert(pagePreviews, preview)
		local name = text(entry.Name .. "\n" .. entry.Id, UDim2.fromOffset(3, 100), UDim2.fromOffset(134, 46))
		name.TextSize = 12
		name.Parent = card
		card.Activated:Connect(function()
			clearContact()
			contact.Visible = false
			panel.Visible = true
			selectEntry(entryIndex)
		end)
	end
end

local function contactButton(label: string, offset: number, action: () -> ())
	local control = Instance.new("TextButton")
	control.Text = label
	control.TextSize = 13
	control.Font = Enum.Font.GothamBold
	control.Size = UDim2.fromOffset(140, 32)
	control.Position = UDim2.fromOffset(offset, 52)
	control.BackgroundColor3 = Color3.fromRGB(255, 239, 201)
	control.TextColor3 = panel.BackgroundColor3
	control.Parent = contact
	control.Activated:Connect(action)
end
contactButton("Previous category", 12, function()
	categoryIndex = (categoryIndex - 2) % #categories + 1
	page = 1
	showContact()
end)
contactButton("Next category", 160, function()
	categoryIndex = categoryIndex % #categories + 1
	page = 1
	showContact()
end)
contactButton("Previous page", 308, function()
	local pages = math.ceil(#byCategory[categoryIndex] / 12)
	page = (page - 2) % pages + 1
	showContact()
end)
contactButton("Next page", 456, function()
	page = page % math.ceil(#byCategory[categoryIndex] / 12) + 1
	showContact()
end)
local back = Instance.new("TextButton")
back.Text = "Contact sheet"
back.Position = UDim2.fromOffset(12, 398)
back.Size = UDim2.fromOffset(426, 28)
back.Font = Enum.Font.GothamBold
back.TextSize = 14
back.Parent = panel
back.Activated:Connect(showContact)
showContact()
