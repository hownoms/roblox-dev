--!strict
--[[
	CampPad — the authored trophy camp pad(s) at Layout.CAMP_PADS (docs/TROPHY_INTEGRATION.md
	"Camp display").

	Each pad is a Model "TrophyCampPad<i>" holding:
	  Deck  24 x 1 x 24 anchored plank deck, top at Layout.DECK_TOP, tagged "TrophyCampPad".
	        TrophyCampDisplay centres the 24x24 camp grid on its top surface and writes the
	        read-only attributes OwnerUserId (0 = free) and OwnerName on it.
	  Rim   low non-colliding border strips just outside the footprint, gold corner posts.
	  Sign  "TROPHY CAMP" board outside the west edge (facing the plaza); its sub-line shows
	        the current owner from the Deck's OwnerName attribute.
	Only the Deck collides (players can walk on it); everything else is decor. Nothing is placed
	inside the footprint except the owner's camp models (anchored, non-colliding).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(script.Parent.Layout)
local Util = require(script.Parent.Util)
local Kit = require(script.Parent.HubKit)

local C = Config.Theme.Colors
local V = Vector3.new

local CampPad = {}

CampPad.TAG = "TrophyCampPad"
local FREE_TEXT = "Free pad"

local function buildPad(parent: Instance, index: number, centre: Vector3): BasePart
	local size = Layout.CAMP_PAD_SIZE
	local rim = Layout.CAMP_PAD_RIM
	local top = Layout.DECK_TOP
	local m = Util.Model("TrophyCampPad" .. index, parent)

	local deck = Util.Part({
		Name = "Deck",
		Size = V(size, 1, size),
		CFrame = CFrame.new(centre.X, top - 0.5, centre.Z),
		Color = Kit.WOOD,
		Material = Enum.Material.WoodPlanks,
		CastShadow = false,
		Parent = m,
	})
	deck:SetAttribute("OwnerUserId", 0)
	deck:SetAttribute("OwnerName", "")
	deck:SetAttribute("PadIndex", index)
	Util.Tag(deck, CampPad.TAG)

	-- Border strips outside the footprint (N/S full length incl. corners, E/W between them).
	local outer = size + rim * 2
	local y = top - 0.5 + 0.2
	for _, s in { -1, 1 } do
		Util.Part({
			Name = "Rim",
			Size = V(outer, 1.4, rim),
			CFrame = CFrame.new(centre.X, y, centre.Z + s * (size + rim) / 2),
			Color = Kit.WOOD_DEEP,
			Material = Enum.Material.Wood,
			Decor = true,
			Parent = m,
		})
		Util.Part({
			Name = "Rim",
			Size = V(rim, 1.4, size),
			CFrame = CFrame.new(centre.X + s * (size + rim) / 2, y, centre.Z),
			Color = Kit.WOOD_DEEP,
			Material = Enum.Material.Wood,
			Decor = true,
			Parent = m,
		})
	end
	local corner = (size + rim) / 2
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Util.Part({
				Name = "CornerPost",
				Size = V(1.4, 2.4, 1.4),
				CFrame = CFrame.new(centre.X + sx * corner, top + 0.2, centre.Z + sz * corner),
				Color = C.Gold,
				Material = Enum.Material.SmoothPlastic,
				Decor = true,
				Parent = m,
			})
		end
	end

	-- Sign outside the west edge, facing the plaza (-X).
	local signPos = V(centre.X - size / 2 - rim - 1.5, top + 3, centre.Z)
	Util.Sign(m, "TROPHY CAMP", V(8, 3, 0.4), CFrame.lookAt(signPos, signPos + V(-1, 0, 0)), {
		Name = "CampSign",
		BoardColor = C.Panel,
		SubText = FREE_TEXT,
		Decor = true,
	})
	Util.Part({
		Name = "SignPost",
		-- from the visible sand (DECK_TOP - 1) up to the board's bottom edge (DECK_TOP + 1.5)
		Size = V(0.6, 2.5, 0.6),
		CFrame = CFrame.new(signPos.X, top + 0.25, signPos.Z),
		Color = Kit.WOOD_DARK,
		Material = Enum.Material.Wood,
		Decor = true,
		Parent = m,
	})
	local board = m:FindFirstChild("CampSign")
	local gui = board and board:FindFirstChild("SignGui")
	local sub = gui and gui:FindFirstChild("SubLabel")
	if sub and sub:IsA("TextLabel") then
		local label = sub :: TextLabel
		local function showOwner()
			local name = deck:GetAttribute("OwnerName")
			label.Text = if type(name) == "string" and name ~= "" then name .. "'s camp" else FREE_TEXT
		end
		deck:GetAttributeChangedSignal("OwnerName"):Connect(showOwner)
		-- the deck is tagged above, so a waiting camp can claim it (and set OwnerName) before
		-- this listener exists: read the current owner once now
		showOwner()
	end
	return deck
end

-- Builds every pad in Layout.CAMP_PADS under `parent`. Returns the tagged decks.
function CampPad.Build(parent: Instance): { BasePart }
	local decks = {}
	for i, centre in Layout.CAMP_PADS do
		table.insert(decks, buildPad(parent, i, centre))
	end
	return decks
end

return CampPad
