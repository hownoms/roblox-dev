--!strict
-- Isolated art-review place: uses the real builders, never loads economy/datastores/remotes.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("GalleryCatalog"))
local workspace = game:GetService("Workspace")
local group = Instance.new("Folder")
group.Name = "AssetGallery"
group.Parent = workspace

local function label(parent: BasePart, text: string)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 60)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.MaxDistance = 100
	gui.Parent = parent
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(25, 42, 63)
	t.BackgroundTransparency = 0.15
	t.TextColor3 = Color3.fromRGB(255, 239, 201)
	t.Font = Enum.Font.GothamBold
	t.TextSize = 16
	t.TextWrapped = true
	t.Text = text
	t.Parent = gui
end

local function row(title: string, items: { any }, z: number): number
	for i, item in items do
		local id = if type(item) == "string" then item else item.Id
		local model = item.Build(id)
		model:SetAttribute("GalleryIndex", item.Index)
		local _, size = model:GetBoundingBox()
		local target = CFrame.new((i - 1) % 8 * 24, 0, z + math.floor((i - 1) / 8) * 26)
		model:PivotTo(target)
		local bounds = model:GetBoundingBox()
		model:PivotTo(model:GetPivot() + Vector3.new(0, 2 - (bounds.Position.Y - size.Y / 2), 0))
		model.Parent = group
		local pad = Instance.new("Part")
		pad.Name = title .. "_" .. id
		pad:SetAttribute("GalleryIndex", item.Index)
		pad.Anchored = true
		pad.Size = Vector3.new(20, 1, 20)
		pad.Position = target.Position + Vector3.new(0, 0.5, 0)
		pad.Color = Color3.fromRGB(216, 202, 167)
		pad.Material = Enum.Material.SmoothPlastic
		pad.Parent = group
		label(pad, title .. " / " .. (if type(item) == "string" then id else item.Name) .. "\n" .. id)
	end
	return z + math.ceil(#items / 8) * 26 + 24
end

local z = 24
local category = ""
local items = {}
for index, entry in Catalog do
	if entry.Category ~= category then
		if #items > 0 then
			z = row(category, items, z)
		end
		category = entry.Category
		items = {}
	end
	table.insert(items, { Id = entry.Id, Name = entry.Name, Build = entry.Build, Index = index })
end
z = row(category, items, z)
local floor = Instance.new("Part")
floor.Name = "GalleryFloor"
floor.Anchored = true
floor.Size = Vector3.new(230, 1, z + 50)
floor.Position = Vector3.new(84, -0.5, z / 2)
floor.Color = Color3.fromRGB(237, 228, 203)
floor.Material = Enum.Material.SmoothPlastic
floor.Parent = workspace
local spawn = Instance.new("SpawnLocation")
spawn.Anchored = true
spawn.Position = Vector3.new(0, 1, 0)
spawn.Neutral = true
spawn.Duration = 0
spawn.Parent = workspace
print("Asset gallery ready; all models are native-size and use production builders.")
