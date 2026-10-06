--!strict
--[[
	StatusController — overhead nameplates and worn-backpack sand level for EVERY player
	(v2.2 B6a / B6b, Status & Social agent).

	Nameplates are client-rendered (decision: no server GUI traffic, and each viewer can hide them
	with the "ShowNameplates" setting). Built from replicated Player attributes set by the
	server's StatusService / MonetizationService:
		TitleLayer   -> title + colour (Config.GetTitle; deepest layer ever reached)
		RebirthCount -> gold stars: "★★★" up to Config.Social.Nameplate.StarsInline, then "★x12"
		VIP / Premium -> small tag pill before the name (VIP wins)
	One BillboardGui "Nameplate" per character (kept in PlayerGui.Nameplates, Adornee = Head):
	MaxDistance 60, AlwaysOnTop false, sized in studs so it shrinks with distance, every text
	outlined (UI_STYLE), no emoji (★ is a plain text glyph). While nameplates are shown the
	default Roblox name above heads is hidden locally (Humanoid.DisplayDistanceType = None).

	Worn backpack (welded by the server, model "WornBackpack"): the "SandFill" part(s) scale with
	the owner's "BackpackFill" attribute (0..1) and turn gold when full. Local-only visual.

	v2.3 streaming: other players' characters stream out (far away) and back in as NEW parts.
	A 0.5 s reconcile re-adorns each plate to the current Head (plates whose Head is gone are just
	hidden by the engine) and re-applies the backpack fill when a new WornBackpack shows up, so
	no state depends on CharacterAdded firing again.

	API (tests): StatusController.StarsText(n), StatusController.Describe(player),
	             StatusController.GetPlate(player): BillboardGui?, StatusController.Refresh()
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local State = require(script.Parent.State)

local StatusController = {}

export type Description = {
	Name: string,
	Title: string,
	TitleColor: Color3,
	Stars: string, -- "" when no rebirths
	Tag: string?, -- "VIP" | "PREMIUM"
}

local NAMEPLATE = Config.Social.Nameplate
local Theme = Config.Theme
local STAR = "★"
local SETTING = "ShowNameplates"

type Plate = {
	Gui: BillboardGui,
	Stars: TextLabel,
	Name: TextLabel,
	Tag: TextLabel,
	Title: TextLabel,
}

local plates: { [Player]: Plate } = {}
local folder: Folder? = nil
local fillOriginals: { [BasePart]: { Size: Vector3, Color: Color3, Transparency: number } } = setmetatable(
	{},
	{ __mode = "k" }
) :: any

function StatusController.StarsText(rebirths: number): string
	local n = math.max(0, math.floor(rebirths))
	if n == 0 then
		return ""
	elseif n <= NAMEPLATE.StarsInline then
		return string.rep(STAR, n)
	end
	return STAR .. "x" .. n
end

local function numberAttr(player: Player, name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

function StatusController.Describe(player: Player): Description
	local layer = math.max(numberAttr(player, "TitleLayer"), 1)
	local title, color = Config.GetTitle(layer)
	local tag: string? = nil
	if player:GetAttribute("VIP") == true then
		tag = "VIP"
	elseif player:GetAttribute("Premium") == true then
		tag = "PREMIUM"
	end
	return {
		Name = player.DisplayName,
		Title = title,
		TitleColor = color,
		Stars = StatusController.StarsText(numberAttr(player, "RebirthCount")),
		Tag = tag,
	}
end

function StatusController.GetPlate(player: Player): BillboardGui?
	local plate = plates[player]
	return if plate then plate.Gui else nil
end

local function enabled(): boolean
	return State.GetSetting(SETTING, true) ~= false
end

local function getFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "Nameplates"
	f.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	folder = f
	return f
end

local function text(parent: Instance, name: string, font: Enum.Font, color: Color3, stroke: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextColor3 = color
	label.TextScaled = true
	label.Text = ""
	label.Parent = parent
	local s = Instance.new("UIStroke")
	s.Color = Theme.Colors.Stroke
	s.Thickness = stroke
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = label
	return label
end

local function render(player: Player)
	local plate = plates[player]
	if not plate then
		return
	end
	local info = StatusController.Describe(player)
	plate.Stars.Text = info.Stars
	plate.Stars.Visible = info.Stars ~= ""
	plate.Name.Text = info.Name
	plate.Title.Text = info.Title
	plate.Title.TextColor3 = info.TitleColor
	local tag = info.Tag
	plate.Tag.Visible = tag ~= nil
	if tag then
		plate.Tag.Text = tag
		plate.Tag.BackgroundColor3 = if tag == "VIP" then Theme.Colors.Gold else Theme.Colors.Ocean
	end
	-- name shifts right to make room for the tag pill
	plate.Name.Position = if tag then UDim2.fromScale(0.29, 0.3) else UDim2.fromScale(0.02, 0.3)
	plate.Name.Size = if tag then UDim2.fromScale(0.69, 0.36) else UDim2.fromScale(0.96, 0.36)
	plate.Gui.Enabled = enabled()
end

local function setDefaultName(character: Model?, hidden: boolean)
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		humanoid.DisplayDistanceType = if hidden
			then Enum.HumanoidDisplayDistanceType.None
			else Enum.HumanoidDisplayDistanceType.Viewer
	end
end

local function removePlate(player: Player)
	local plate = plates[player]
	if plate then
		plate.Gui:Destroy()
		plates[player] = nil
	end
end

local function buildPlate(player: Player, head: BasePart)
	removePlate(player)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate_" .. player.UserId
	gui.Adornee = head
	gui.Size = UDim2.fromScale(6, 1.9) -- studs: shrinks with distance like the world
	gui.StudsOffset = Vector3.new(0, 2.7, 0)
	gui.MaxDistance = NAMEPLATE.MaxDistance
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Parent = getFolder()

	local stars = text(gui, "Stars", Theme.Fonts.Title, Theme.Colors.Gold, 2)
	stars.Size = UDim2.fromScale(1, 0.28)
	stars.Position = UDim2.fromScale(0, 0)

	local tag = text(gui, "Tag", Theme.Fonts.Title, Theme.Colors.Text, 1.5)
	tag.Size = UDim2.fromScale(0.25, 0.3)
	tag.Position = UDim2.fromScale(0.02, 0.33)
	tag.BackgroundTransparency = 0
	tag.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = tag
	local ring = Instance.new("UIStroke")
	ring.Color = Theme.Colors.Stroke
	ring.Thickness = 2
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Parent = tag

	local name = text(gui, "PlayerName", Theme.Fonts.Title, Theme.Colors.Text, 2)
	local title = text(gui, "Title", Theme.Fonts.Title, Theme.Colors.Text, 2)
	title.Size = UDim2.fromScale(1, 0.3)
	title.Position = UDim2.fromScale(0, 0.68)

	plates[player] = { Gui = gui, Stars = stars, Name = name, Tag = tag, Title = title }
	render(player)
	setDefaultName(player.Character, enabled())
end

-- Worn backpack sand level -------------------------------------------------------------------------

local function applyFill(player: Player)
	local character = player.Character
	local found = if character then character:FindFirstChild("WornBackpack") else nil
	if found == nil then
		return
	end
	local pack = found :: Instance
	local fill = math.clamp(numberAttr(player, "BackpackFill"), 0, 1)
	for _, d in pack:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "SandFill" then
			local original = fillOriginals[d]
			if not original then
				original = { Size = d.Size, Color = d.Color, Transparency = d.Transparency }
				fillOriginals[d] = original
			end
			assert(original) -- refine for the type checker (set above)
			d.Size = Vector3.new(original.Size.X, original.Size.Y * (0.25 + 0.75 * fill), original.Size.Z)
			d.Transparency = if fill <= 0 then 1 else original.Transparency
			d.Color = if fill >= 1 then Theme.Colors.Gold else original.Color
		end
	end
end

-- Characters ----------------------------------------------------------------------------------------

local function onCharacter(player: Player, character: Model)
	local function tryHead(): boolean
		local head = character:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			buildPlate(player, head)
			return true
		end
		return false
	end
	if not tryHead() then
		local connection: RBXScriptConnection? = nil
		connection = character.ChildAdded:Connect(function(child: Instance)
			if child.Name == "Head" and tryHead() and connection then
				connection:Disconnect()
			end
		end)
	end
	character.ChildAdded:Connect(function(child: Instance)
		if child.Name == "WornBackpack" then
			task.defer(applyFill, player)
		elseif child:IsA("Humanoid") then
			setDefaultName(character, enabled())
		end
	end)
	applyFill(player)
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		onCharacter(player, character)
	end)
	player.CharacterRemoving:Connect(function()
		removePlate(player)
	end)
	player.AttributeChanged:Connect(function(name: string)
		if name == "BackpackFill" then
			applyFill(player)
		elseif name == "TitleLayer" or name == "RebirthCount" or name == "VIP" or name == "Premium" then
			render(player)
		end
	end)
	if player.Character then
		onCharacter(player, player.Character)
	end
end

function StatusController.Refresh()
	local on = enabled()
	for player, plate in plates do
		plate.Gui.Enabled = on
		setDefaultName(player.Character, on)
	end
end

-- v2.3 streaming: keep plates and backpack fills attached to the parts that exist right now.
local lastPack: { [Player]: Instance? } = setmetatable({}, { __mode = "k" }) :: any
local RECONCILE_INTERVAL = 0.5

function StatusController.Reconcile()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local head = if character then character:FindFirstChild("Head") else nil
		if head and head:IsA("BasePart") then
			local plate = plates[player]
			if not plate then
				buildPlate(player, head)
			elseif plate.Gui.Adornee ~= head then
				plate.Gui.Adornee = head
				setDefaultName(character, enabled())
			end
		end
		local pack = if character then character:FindFirstChild("WornBackpack") else nil
		if pack ~= lastPack[player] then
			lastPack[player] = pack
			if pack then
				applyFill(player)
			end
		end
	end
end

function StatusController.Init()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= RECONCILE_INTERVAL then
			elapsed = 0
			StatusController.Reconcile()
		end
	end)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(removePlate)
	State.Changed("Settings"):Connect(StatusController.Refresh)
end

return StatusController
