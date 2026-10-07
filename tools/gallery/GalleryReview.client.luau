--!strict
-- One selected asset at a time: full collection remains native-size in the world.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
-- Chat overlays the review controls in narrow Studio windows; isolated diagnostic only.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
end)
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Captures, false)
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
		scale.Scale = math.min(1, (available.X - 24) / 1074, (available.Y - 60) / 628)
	end
end
local camera = workspace.CurrentCamera
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
end
resize()
local index = 1
local previews: { Viewport.Viewport } = {}
local selectEntry: (number) -> ()
local jumpInput: TextBox
local panel: Frame
local nativeDetails = false
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
local hiddenBillboards: { [BillboardGui]: boolean } = {}
local hiddenParts: { [BasePart]: number } = {}
local hideCharacterConnection: RBXScriptConnection? = nil
local function hideNativeObstructions(gallery: Instance, character: Model)
	for _, descendant in gallery:GetDescendants() do
		if descendant:IsA("BillboardGui") then
			hiddenBillboards[descendant] = descendant.Enabled
			descendant.Enabled = false
		end
	end
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			hiddenParts[descendant] = descendant.LocalTransparencyModifier
			descendant.LocalTransparencyModifier = 1
		end
	end
	hideCharacterConnection = RunService.RenderStepped:Connect(function()
		for part in hiddenParts do
			if part.Parent then
				part.LocalTransparencyModifier = 1
			end
		end
	end)
end
local nativeModel: Model? = nil
local nativeYaw = 25
local nativeLabel = Instance.new("TextLabel")
nativeLabel.Size = UDim2.fromOffset(420, 36)
nativeLabel.Position = UDim2.new(0, 202, 1, -44)
nativeLabel.Font = Enum.Font.GothamBold
nativeLabel.TextSize = 14
nativeLabel.TextColor3 = Color3.fromRGB(255, 239, 201)
nativeLabel.BackgroundColor3 = Color3.fromRGB(25, 42, 63)
nativeLabel.TextWrapped = true
nativeLabel.Visible = false
nativeLabel.Parent = gui
local nativeControls: { TextButton } = {}
local function frameNative()
	local current = workspace.CurrentCamera
	local model = nativeModel
	if not current or not model or not model.Parent then
		return
	end
	local bounds, size = model:GetBoundingBox()
	local blockedWidth = if nativeDetails then 450 * scale.Scale + 24 else 0
	local usableWidth = math.max(1, current.ViewportSize.X - blockedWidth)
	local aspect = usableWidth / math.max(1, current.ViewportSize.Y)
	local vertical = math.rad(current.FieldOfView / 2)
	local halfFov = math.min(vertical, math.atan(math.tan(vertical) * aspect))
	local distance = math.max(3, size.Magnitude / 2 / math.sin(halfFov) / 0.75)
	local yaw = math.rad(nativeYaw)
	local direction = Vector3.new(math.sin(yaw), 0.35, -math.cos(yaw)).Unit
	local fitted = CFrame.lookAt(bounds.Position + direction * distance, bounds.Position)
	local shift = blockedWidth / math.max(1, current.ViewportSize.Y) * distance * math.tan(vertical)
	current.CFrame = fitted + fitted.RightVector * shift
end
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if nativeModel then
			frameNative()
		end
	end)
end
for i, action in { { Label = "Left 90 deg", Yaw = -90 }, { Label = "Right 90 deg", Yaw = 90 } } do
	local control = Instance.new("TextButton")
	control.Text = action.Label
	control.Size = UDim2.fromOffset(110, 36)
	control.Position = UDim2.new(0, 12 + (i - 1) * 118, 1, -84)
	control.Font = Enum.Font.GothamBold
	control.TextSize = 14
	control.Visible = false
	control.Parent = gui
	control.Activated:Connect(function()
		nativeYaw = (nativeYaw + action.Yaw) % 360
		frameNative()
	end)
	table.insert(nativeControls, control)
end
local function restoreCamera()
	local wasNative = nativeModel ~= nil
	if hideCharacterConnection then
		hideCharacterConnection:Disconnect()
		hideCharacterConnection = nil
	end
	for part, transparency in hiddenParts do
		if part.Parent then
			part.LocalTransparencyModifier = transparency
		end
	end
	table.clear(hiddenParts)
	for billboard, enabled in hiddenBillboards do
		if billboard.Parent then
			billboard.Enabled = enabled
		end
	end
	table.clear(hiddenBillboards)
	local current = workspace.CurrentCamera
	if current and savedCameraType then
		current.CameraType = savedCameraType
		if savedCameraFrame then
			current.CFrame = savedCameraFrame
		end
	end
	savedCameraType, savedCameraFrame = nil, nil
	nativeReturn.Visible = false
	nativeLabel.Visible = false
	nativeModel = nil
	nativeDetails = false
	jumpInput.Visible = true
	for _, child in panel:GetChildren() do
		if child:IsA("GuiButton") then
			child.Visible = true
		end
	end
	for _, control in nativeControls do
		control.Visible = false
	end
	root.Visible = true
	if wasNative then
		selectEntry(index)
	end
end
nativeReturn.Activated:Connect(restoreCamera)
panel = Instance.new("Frame")
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
local x = 12
for _, pixels in { 48, 120, 240 } do
	local sizeLabel = text("", UDim2.fromOffset(x, 48), UDim2.fromOffset(pixels, 24))
	sizeLabel.TextSize = 11
	local preview = Viewport.new({
		Parent = panel,
		Position = UDim2.fromOffset(x, 76),
		Size = UDim2.fromOffset(pixels, pixels),
		Spin = false,
	})
	local function updateSizeLabel()
		sizeLabel.Text = string.format("%d px\n%.0f actual", pixels, preview.Frame.AbsoluteSize.X)
	end
	preview.Frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateSizeLabel)
	updateSizeLabel()
	table.insert(previews, preview)
	x += pixels + 8
end

local showContact: () -> ()
local clearContact: () -> ()
selectEntry = function(nextIndex: number)
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
local function visitNative(nextIndex: number)
	local gallery = workspace:FindFirstChild("AssetGallery")
	local character = player.Character
	local current = workspace.CurrentCamera
	if not gallery or not character or not current then
		return
	end
	local targetIndex = (nextIndex - 1) % #Catalog + 1
	local targetModel: Model? = nil
	local targetPad: BasePart? = nil
	for _, descendant in gallery:GetChildren() do
		if descendant:GetAttribute("GalleryIndex") == targetIndex then
			if descendant:IsA("Model") then
				targetModel = descendant
			elseif descendant:IsA("BasePart") then
				targetPad = descendant
			end
		end
	end
	if not targetModel or not targetPad then
		return
	end
	if not nativeModel then
		savedCameraType, savedCameraFrame = current.CameraType, current.CFrame
		hideNativeObstructions(gallery, character)
		for _, preview in previews do
			preview:SetModel(nil)
		end
	end
	character:PivotTo(targetPad.CFrame * CFrame.new(0, 4, -12))
	index = targetIndex
	if nativeDetails then
		selectEntry(index)
	end
	nativeModel, nativeYaw = targetModel, 25
	current.CameraType = Enum.CameraType.Scriptable
	frameNative()
	local entry = Catalog[index]
	nativeLabel.Text = string.format("%d / %d: %s / %s\n%s", index, #Catalog, entry.Category, entry.Name, entry.Id)
	nativeLabel.Visible = true
	for _, control in nativeControls do
		control.Visible = true
	end
	root.Visible = nativeDetails
	jumpInput.Visible = false
	nativeReturn.Visible = true
end
button("Visit native", 268, function()
	visitNative(index)
end)
for i, action in { { Label = "Previous asset", Offset = -1 }, { Label = "Next asset", Offset = 1 } } do
	local control = Instance.new("TextButton")
	control.Text = action.Label
	control.Size = UDim2.fromOffset(132, 36)
	control.Position = UDim2.new(0, 248 + (i - 1) * 140, 1, -84)
	control.Font = Enum.Font.GothamBold
	control.TextSize = 14
	control.Visible = false
	control.Parent = gui
	control.Activated:Connect(function()
		visitNative(index + action.Offset)
	end)
	table.insert(nativeControls, control)
end
text(
	"Static production Viewport · no player data / gameplay services",
	UDim2.fromOffset(8, 368),
	UDim2.fromOffset(434, 24)
)

local contact = Instance.new("Frame")
contact.Size = UDim2.fromOffset(610, 580)
contact.BackgroundColor3 = panel.BackgroundColor3
contact.Parent = root
jumpInput = Instance.new("TextBox")
jumpInput.PlaceholderText = "Jump: asset ID, name or catalog number; Enter"
jumpInput.Text = ""
jumpInput.ClearTextOnFocus = false
jumpInput.Size = UDim2.fromOffset(610, 32)
jumpInput.Position = UDim2.fromOffset(0, 588)
jumpInput.Font = Enum.Font.Gotham
jumpInput.TextSize = 14
jumpInput.Parent = root
jumpInput.FocusLost:Connect(function(enterPressed)
	if not enterPressed then
		return
	end
	local query = string.lower(jumpInput.Text):match("^%s*(.-)%s*$") or ""
	local number = tonumber(query)
	for entryIndex, entry in Catalog do
		if entryIndex == number or string.lower(entry.Id) == query or string.lower(entry.Name) == query then
			clearContact()
			contact.Visible = false
			panel.Visible = true
			selectEntry(entryIndex)
			jumpInput.Text = ""
			return
		end
	end
	jumpInput.Text = "No exact match: " .. query
end)
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

local detailsToggle = Instance.new("TextButton")
detailsToggle.Text = "Show details"
detailsToggle.Size = UDim2.fromOffset(132, 36)
detailsToggle.Position = UDim2.new(0, 528, 1, -84)
detailsToggle.Font = Enum.Font.GothamBold
detailsToggle.TextSize = 14
detailsToggle.Visible = false
detailsToggle.Parent = gui
detailsToggle.Activated:Connect(function()
	nativeDetails = not nativeDetails
	detailsToggle.Text = if nativeDetails then "Hide details" else "Show details"
	root.Visible = nativeDetails
	jumpInput.Visible = false
	for _, child in panel:GetChildren() do
		if child:IsA("GuiButton") then
			child.Visible = not nativeDetails
		end
	end
	if nativeDetails then
		selectEntry(index)
	else
		for _, preview in previews do
			preview:SetModel(nil)
		end
	end
	frameNative()
end)
nativeReturn.Activated:Connect(function()
	detailsToggle.Text = "Show details"
end)
table.insert(nativeControls, detailsToggle)
