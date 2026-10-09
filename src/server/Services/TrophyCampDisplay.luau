--!strict
--[[
	TrophyCampDisplay — builds a loaded player's camp trophies on a reserved camp pad.

	Pads are not owned or saved (bible ch.02 "Camps and trophies": camp templates persist, pad
	location does not). A pad is any anchored BasePart tagged "TrophyCampPad" (the camp area
	is the 24x24 square centred on the part, on its top surface), or a CFrame passed to
	SetPads(). Each loaded player with a layout borrows the lowest free pad; leaving frees it.
	No pads = nothing is shown (the persisted layout is unaffected).

	Built from the visual kit only: Models.Expansion1.TrophyStand() with
	Models.Expansion1.TrophyReplica() on its TrophySlot. Every part from Models.Build is
	anchored and non-colliding/non-querying/non-touching, and the replica sets the same flags,
	so a display never blocks movement or digging. Rendering reads only validated save data;
	there is no client input here.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Trophies.Catalog)
local Rules = require(ReplicatedStorage.Shared.Trophies.Rules)
local Kit = require(ReplicatedStorage.Shared.Models.Expansion1)

local Display = {}

Display.PAD_TAG = "TrophyCampPad"
Display.FOLDER_NAME = "TrophyCamps"

local explicitPads: { CFrame }? = nil
local assigned: { [number]: Player } = {} -- pad index -> player
local camps: { [Player]: { Pad: number, Model: Model } } = {}

local function padCFrames(): { CFrame }
	if explicitPads then
		return explicitPads :: { CFrame }
	end
	local list = {}
	local parts = CollectionService:GetTagged(Display.PAD_TAG)
	-- stable order so pad indices do not reshuffle between calls
	table.sort(parts, function(a: Instance, b: Instance): boolean
		return a:GetFullName() < b:GetFullName()
	end)
	for _, inst in parts do
		if inst:IsA("BasePart") then
			local part = inst :: BasePart
			table.insert(list, part.CFrame * CFrame.new(0, part.Size.Y / 2, 0))
		end
	end
	return list
end

local function folder(): Folder
	local existing = Workspace:FindFirstChild(Display.FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = Display.FOLDER_NAME
	f.Parent = Workspace
	return f
end

-- Pad-local CFrame of a placement (bottom centre of the stand).
function Display.PlacementCFrame(pad: CFrame, placement: Rules.Placement): CFrame
	local x, z = Rules.CellOffset(placement.X, placement.Z)
	return pad * CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(placement.Rot), 0)
end

local function buildPlacement(pad: CFrame, placement: Rules.Placement): Model?
	local def = Catalog.Get(placement.TrophyId)
	if not def or def.Replica ~= "TrophyReplica" then
		return nil -- known to a newer server only, or not displayable: keep the record, skip
	end
	local holder = Instance.new("Model")
	holder.Name = "Placement_" .. tostring(placement.Id)
	holder:SetAttribute("PlacementId", placement.Id)
	holder:SetAttribute("TrophyId", placement.TrophyId)

	local at = Display.PlacementCFrame(pad, placement)
	local stand = Kit.TrophyStand()
	stand:PivotTo(at)
	stand.Parent = holder

	local slotOffset = Vector3.new(0, 1.75, 0)
	local root = stand.PrimaryPart
	local slot = root and root:FindFirstChild("TrophySlot")
	if slot and slot:IsA("Attachment") then
		slotOffset = slot.Position
	end
	local replica = Kit.TrophyReplica()
	replica:PivotTo(at * CFrame.new(slotOffset))
	replica.Parent = holder
	return holder
end

function Display.SetPads(pads: { CFrame }?)
	explicitPads = pads
end

function Display.GetPadCount(): number
	return #padCFrames()
end

-- Pad index currently shown for this player, or nil.
function Display.GetPad(player: Player): number?
	local camp = camps[player]
	return if camp then camp.Pad else nil
end

function Display.GetModel(player: Player): Model?
	local camp = camps[player]
	return if camp then camp.Model else nil
end

function Display.Hide(player: Player)
	local camp = camps[player]
	if not camp then
		return
	end
	camps[player] = nil
	assigned[camp.Pad] = nil
	camp.Model:Destroy()
end

-- (Re)builds the player's camp from their layout. Returns the pad index used, or nil.
function Display.Show(player: Player, layout: Rules.CampLayout): number?
	local pads = padCFrames()
	local previous = camps[player]
	local padIndex: number? = if previous and pads[previous.Pad] then previous.Pad else nil
	if previous then
		previous.Model:Destroy()
		camps[player] = nil
		assigned[previous.Pad] = nil
	end
	if #layout.Placements == 0 then
		return nil -- an empty camp does not hold a pad
	end
	if not padIndex then
		for i = 1, #pads do
			if not assigned[i] then
				padIndex = i
				break
			end
		end
	end
	if not padIndex then
		return nil
	end
	local index = padIndex :: number
	local pad = pads[index]
	local camp = Instance.new("Model")
	camp.Name = "Camp_" .. tostring(player.UserId)
	camp:SetAttribute("OwnerUserId", player.UserId)
	camp:SetAttribute("OwnerName", player.DisplayName)
	camp:SetAttribute("PadIndex", index)
	for _, placement in layout.Placements do
		local built = buildPlacement(pad, placement)
		if built then
			built.Parent = camp
		end
	end
	camp.Parent = folder()
	assigned[index] = player
	camps[player] = { Pad = index, Model = camp }
	return index
end

return Display
