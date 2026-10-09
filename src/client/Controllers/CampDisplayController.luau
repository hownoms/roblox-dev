--!strict
--[[
	CampDisplayController — the small trophy camp action on the camp pad (docs/integration/
	camp-display-action.md). Presentation only: the server owns every decision.

	The server hangs two ProximityPrompts on each camp pad deck (tag "TrophyCampPad"):
	CampDisplayPrompt ("Display trophy") and CampRemovePrompt ("Put trophy away"), and publishes
	this player's camp status as read-only Player attributes CampStatus / CampQueue
	(Trophies/CampAction). This controller, for the local player only:
	  - shows just the prompt that applies (display when Ready, put away when something of
	    theirs is saved), and hides both when the feature is off or data has not loaded;
	  - draws a small card above the pad with the truthful status line (no trophy, no stand,
	    pad busy / place in line, on display, no pad);
	  - while the display prompt is on screen and the pad is free (or theirs), draws a local
	    see-through, non-colliding preview of the stand + replica on the exact cell the server
	    will use (CampAction.FirstFreeCell + CellCFrame). The preview never touches the server.
	Nothing is sent to the server from here; triggering a prompt is handled server-side.
	Streaming-safe: decks are watched with Util/Tagged and prompts may arrive after the deck.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local CampAction = require(Shared:WaitForChild("Trophies"):WaitForChild("CampAction"))
local Kit = require(Shared:WaitForChild("Models"):WaitForChild("Expansion1"))
local Tagged = require(script.Parent.Parent.Util.Tagged)
local ModelFactory = require(script.Parent.Parent.Util.ModelFactory)
local State = require(script.Parent.State)

local Theme = Config.Theme

local CampDisplayController = {}

CampDisplayController.PAD_TAG = "TrophyCampPad"
CampDisplayController.GHOST_TRANSPARENCY = 0.55

type Entry = {
	Deck: BasePart,
	Card: BillboardGui,
	Body: TextLabel,
	Show: ProximityPrompt?,
	Put: ProximityPrompt?,
	Near: boolean, -- the display prompt is on this player's screen
	Ghost: Model?,
	GhostKey: string?,
}

local entries: { [BasePart]: Entry } = {}
local initialized = false

local function localPlayer(): Player
	return Players.LocalPlayer
end

function CampDisplayController.Status(): (string?, number)
	local player = localPlayer()
	local status = player:GetAttribute(CampAction.STATUS_ATTR)
	local queue = player:GetAttribute(CampAction.QUEUE_ATTR)
	return if type(status) == "string" then status else nil, if type(queue) == "number" then queue else 0
end

-- Display name of whoever holds this pad when it is not the local player, else nil.
local function busyBy(deck: BasePart): string?
	local owner = deck:GetAttribute("OwnerUserId")
	if type(owner) ~= "number" or owner == 0 or owner == localPlayer().UserId then
		return nil
	end
	local name = deck:GetAttribute("OwnerName")
	return if type(name) == "string" and name ~= "" then name else "Another player"
end

local function layout(): any
	local l = State.Data and (State.Data :: any).CampLayout
	if type(l) == "table" and type(l.Placements) == "table" then
		return l
	end
	return { Placements = {}, NextId = 1 }
end

local function destroyGhost(entry: Entry)
	if entry.Ghost then
		entry.Ghost:Destroy()
		entry.Ghost = nil
		entry.GhostKey = nil
	end
end

local function buildGhost(entry: Entry, x: number, z: number)
	local deck = entry.Deck
	local top = deck.CFrame * CFrame.new(0, deck.Size.Y / 2, 0)
	local at = CampAction.CellCFrame(top, x, z, CampAction.ROT)
	local ghost = Instance.new("Model")
	ghost.Name = "CampPreview"
	ghost:SetAttribute("Cell", x .. "," .. z)
	local stand = Kit.TrophyStand()
	stand:PivotTo(at)
	stand.Parent = ghost
	local slotOffset = Vector3.new(0, 1.75, 0)
	local root = stand.PrimaryPart
	local slot = root and root:FindFirstChild("TrophySlot")
	if slot and slot:IsA("Attachment") then
		slotOffset = slot.Position
	end
	local replica = Kit.TrophyReplica()
	replica:PivotTo(at * CFrame.new(slotOffset))
	replica.Parent = ghost
	ModelFactory.MakeVisualOnly(ghost, false)
	for _, d in ghost:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = math.max(d.Transparency, CampDisplayController.GHOST_TRANSPARENCY)
		end
	end
	ghost.Parent = Workspace
	entry.Ghost = ghost
	entry.GhostKey = x .. "," .. z
end

local function render(entry: Entry)
	local status, queue = CampDisplayController.Status()
	local active = status ~= nil and status ~= "Off"
	local busy = busyBy(entry.Deck)
	local show, put = entry.Show, entry.Put
	-- Local-only Enabled: hides the prompt for this player; the server still validates.
	if show then
		show.Enabled = active and status == "Ready"
		show.ActionText = if busy then "Save & join line" else "Display trophy"
	end
	if put then
		put.Enabled = active and CampAction.HasLayout[status :: string] == true
	end
	entry.Card.Enabled = active
	entry.Body.Text = if active then CampAction.Text(status, queue, if status == "Ready" then busy else nil) else ""

	local x, z = nil, nil
	if active and status == "Ready" and busy == nil and entry.Near then
		x, z = CampAction.FirstFreeCell(layout())
	end
	if x == nil then
		destroyGhost(entry)
	elseif entry.GhostKey ~= (x :: number) .. "," .. (z :: number) then
		destroyGhost(entry)
		buildGhost(entry, x :: number, z :: number)
	end
end

function CampDisplayController.Refresh()
	for _, entry in entries do
		render(entry)
	end
end

local function buildCard(deck: BasePart): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = "CampCard"
	gui.Adornee = deck
	gui.Size = UDim2.fromScale(11, 2.8) -- studs
	gui.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
	gui.MaxDistance = 60
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Enabled = false

	local frame = Instance.new("Frame")
	frame.Name = "Frame"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Theme.Colors.Navy
	frame.BackgroundTransparency = 0.15
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.18, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Gold
	stroke.Thickness = 2
	stroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.05, 0.06)
	title.Size = UDim2.fromScale(0.9, 0.34)
	title.Font = Theme.Fonts.Title
	title.TextColor3 = Theme.Colors.Gold
	title.TextScaled = true
	title.Text = "TROPHY CAMP"
	title.Parent = frame

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromScale(0.05, 0.42)
	body.Size = UDim2.fromScale(0.9, 0.5)
	body.Font = Theme.Fonts.Body
	body.TextColor3 = Theme.Colors.Text
	body.TextScaled = true
	body.TextWrapped = true
	body.Text = ""
	body.Parent = frame

	gui.Parent = localPlayer():WaitForChild("PlayerGui")
	return gui, body
end

local function watchDeck(inst: Instance): (() -> ())?
	if not inst:IsA("BasePart") then
		return nil
	end
	local deck = inst :: BasePart
	local card, body = buildCard(deck)
	local entry: Entry = { Deck = deck, Card = card, Body = body, Near = false }
	entries[deck] = entry
	local connections: { RBXScriptConnection } = {}

	local function hook(child: Instance)
		if not child:IsA("ProximityPrompt") then
			return
		end
		local prompt = child :: ProximityPrompt
		if prompt.Name == CampAction.DISPLAY_PROMPT then
			entry.Show = prompt
			table.insert(
				connections,
				prompt.PromptShown:Connect(function()
					entry.Near = true
					render(entry)
				end)
			)
			table.insert(
				connections,
				prompt.PromptHidden:Connect(function()
					entry.Near = false
					render(entry)
				end)
			)
		elseif prompt.Name == CampAction.REMOVE_PROMPT then
			entry.Put = prompt
		else
			return
		end
		render(entry)
	end
	for _, child in deck:GetChildren() do
		hook(child)
	end
	table.insert(connections, deck.ChildAdded:Connect(hook))
	table.insert(
		connections,
		deck.ChildRemoved:Connect(function(child: Instance)
			if child == entry.Show then
				entry.Show = nil
				entry.Near = false
			elseif child == entry.Put then
				entry.Put = nil
			end
			render(entry)
		end)
	)
	table.insert(
		connections,
		deck:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
			render(entry)
		end)
	)
	render(entry)

	return function()
		for _, c in connections do
			c:Disconnect()
		end
		destroyGhost(entry)
		card:Destroy()
		if entries[deck] == entry then
			entries[deck] = nil
		end
	end
end

-- Test / review hooks (read-only).
function CampDisplayController.GetEntry(deck: BasePart): any
	return entries[deck]
end

function CampDisplayController.Init()
	if initialized then
		return
	end
	initialized = true
	local player = localPlayer()
	player:GetAttributeChangedSignal(CampAction.STATUS_ATTR):Connect(CampDisplayController.Refresh)
	player:GetAttributeChangedSignal(CampAction.QUEUE_ATTR):Connect(CampDisplayController.Refresh)
	State.Changed("CampLayout"):Connect(CampDisplayController.Refresh)
	Tagged.Watch(CampDisplayController.PAD_TAG, watchDeck)
end

return CampDisplayController
