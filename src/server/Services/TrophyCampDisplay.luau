--!strict
--[[
	TrophyCampDisplay — builds a loaded player's camp trophies on a reserved camp pad.

	Pads are not owned or saved (bible ch.02 "Camps and trophies": camp templates persist, pad
	location does not). A pad is any anchored BasePart tagged "TrophyCampPad" (the camp area
	is the 24x24 square centred on the part, on its top surface), or a CFrame passed to
	SetPads(). Each loaded player with a layout borrows the lowest free pad; leaving frees it.
	No pads = nothing is shown (the persisted layout is unaffected). The world builds one
	authored pad (World/CampPad.luau, Layout.CAMP_PADS).

	Ownership: a pad has at most one owner at a time and is never taken from its owner; Show
	only ever claims a pad that is free or already the caller's. The owner is mirrored onto a
	tagged pad part as read-only attributes OwnerUserId (0 = free) and OwnerName (""), which
	replicate to clients. Who waits for a busy pad and who gets it next is TrophyService's job.

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

type Pad = { CFrame: CFrame, Part: BasePart? }

local explicitPads: { CFrame }? = nil
local assigned: { [number]: Player } = {} -- pad index -> player
local camps: { [Player]: { Pad: number, Model: Model, Part: BasePart? } } = {}

-- `gone`: a pad part leaving right now (CollectionService may still list it while it leaves).
local function padList(gone: Instance?): { Pad }
	local list: { Pad } = {}
	if explicitPads then
		for _, cf in explicitPads :: { CFrame } do
			table.insert(list, { CFrame = cf })
		end
		return list
	end
	local parts = CollectionService:GetTagged(Display.PAD_TAG)
	-- stable order so pad indices do not reshuffle between calls
	table.sort(parts, function(a: Instance, b: Instance): boolean
		return a:GetFullName() < b:GetFullName()
	end)
	for _, inst in parts do
		if inst ~= gone and inst:IsA("BasePart") then
			local part = inst :: BasePart
			table.insert(list, { CFrame = part.CFrame * CFrame.new(0, part.Size.Y / 2, 0), Part = part })
		end
	end
	return list
end

-- Mirrors the owner onto the pad part (server-written; client writes never replicate back).
local function markOwner(part: BasePart?, player: Player?)
	if not part then
		return
	end
	part:SetAttribute("OwnerUserId", if player then player.UserId else 0)
	part:SetAttribute("OwnerName", if player then player.DisplayName else "")
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
	return #padList()
end

-- The player whose camp is shown on pad `index`, or nil when the pad is free.
function Display.GetPadOwner(index: number): Player?
	local owner = assigned[index]
	return if owner and camps[owner] and camps[owner].Pad == index then owner else nil
end

-- Number of pads with no camp on them.
function Display.FreePadCount(): number
	local free = 0
	for i = 1, #padList() do
		if not assigned[i] then
			free += 1
		end
	end
	return free
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
	if assigned[camp.Pad] == player then
		assigned[camp.Pad] = nil
		markOwner(camp.Part, nil)
	end
	camp.Model:Destroy()
end

-- (Re)builds the player's camp from their layout. Returns the pad index used, or nil.
function Display.Show(player: Player, layout: Rules.CampLayout): number?
	local pads = padList()
	local previous = camps[player]
	-- keep the previous pad only if that index still means the same pad part
	local padIndex: number? = if previous
			and pads[previous.Pad]
			and pads[previous.Pad].Part == previous.Part
		then previous.Pad
		else nil
	if previous then
		previous.Model:Destroy()
		camps[player] = nil
		if assigned[previous.Pad] == player then
			assigned[previous.Pad] = nil
		end
	end
	if #layout.Placements == 0 then
		if previous then
			markOwner(previous.Part, nil)
		end
		return nil -- an empty camp does not hold a pad
	end
	if padIndex and assigned[padIndex :: number] then
		padIndex = nil -- never take a pad someone else holds
	end
	if previous and not padIndex and previous.Part and previous.Part.Parent ~= nil then
		markOwner(previous.Part, nil)
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
	local pad = pads[index].CFrame
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
	camps[player] = { Pad = index, Model = camp, Part = pads[index].Part }
	markOwner(pads[index].Part, player)
	return index
end

--[[
	Re-keys shown camps after the tagged pad set changed (a deck destroyed, untagged, rebuilt or
	added: pad indices are positions in the sorted tag list, so they shift). `gone` is a pad part
	leaving right now. A camp whose pad part is no longer a pad is torn down (its model would
	otherwise float where the deck was, and its stale index would block or alias another pad);
	those players are returned in their old pad order so the caller can re-show or queue them.
	No-op with explicit SetPads() pads, which are plain CFrames.
]]
function Display.Reconcile(gone: Instance?): { Player }
	local displaced: { Player } = {}
	if explicitPads then
		return displaced
	end
	local indexOf: { [BasePart]: number } = {}
	for i, pad in padList(gone) do
		if pad.Part then
			indexOf[pad.Part :: BasePart] = i
		end
	end
	table.clear(assigned)
	for player, camp in camps do
		local i = if camp.Part then indexOf[camp.Part :: BasePart] else nil
		if i then
			camp.Pad = i
			camp.Model:SetAttribute("PadIndex", i)
			assigned[i] = player
		else
			table.insert(displaced, player)
		end
	end
	table.sort(displaced, function(a: Player, b: Player): boolean
		return camps[a].Pad < camps[b].Pad
	end)
	for _, player in displaced do
		local camp = camps[player]
		camps[player] = nil
		camp.Model:Destroy()
		if camp.Part and camp.Part.Parent ~= nil then
			markOwner(camp.Part, nil) -- untagged but still in the world: show it free
		end
	end
	return displaced
end

return Display
