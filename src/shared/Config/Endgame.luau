--!strict
--[[
	Endgame (docs/SIX_MONTH_PLAN.md part C1–C3) — balance data + pure helpers shared by the server
	(authoritative) and the client (UI). Read-only.

	C1 Rebirth milestones: reaching Rebirths >= Milestone.Rebirths grants its reward ONCE
	   (RebirthService, recorded in PlayerData.Milestones[id] = true, never reset). Rewards:
	     Title  nameplate title that replaces the layer title (derived from the replicated
	            "RebirthCount" attribute, so it needs no grant; still recorded for the toast)
	     Pet    an Exclusive pet (Config.Pets), granted through PetService.GrantPet
	     Skin   a shovel skin (Endgame.Skins): recolours whatever shovel is equipped; the player
	            turns it on / off (PlayerData.ShovelSkin, remote SetShovelSkin)
	   Players who were already past a milestone get it on their next join.

	C2 Rainbow pets: RAINBOW_FUSE_COUNT Golden copies of one pet (not Rainbow) fuse into ONE Rainbow
	   pet (PetInstance.Rainbow = true; it keeps Golden = true so old code paths still treat it at
	   least as Golden). Sand bonus x RAINBOW_SAND_BONUS (instead of Golden's x1.5), digs
	   RAINBOW_DIG_SPEED x as often (instead of Golden's 1.25x). Rainbow pets can't be fused again.

	C3 Index mastery: a layer is MASTERED when every treasure in its LootTable has every Index pill
	   lit (MASTERY_VARIANTS: all sizes + the three rare materials, PlayerData.FindVariants). The
	   server records it once (PlayerData.IndexMastered[layerId] = true, DiscoveryService) and each
	   recorded layer gives +INDEX_MASTER_BONUS sand forever (Stats "Mastery" factor). This stacks
	   with the older "completed layer" bonus (Config.INDEX_LAYER_BONUS, every treasure found once).

	Every grant can be paused live (docs/LIVE_CONFIG.md): pause_milestones, pause_fusing,
	pause_index_rewards. A pause stops NEW grants / fusions; what players already have stays.
]]

local Types = require(script.Parent.Parent.Types)
local Layers = require(script.Parent.Layers)
local Pets = require(script.Parent.Pets)

local rgb = Color3.fromRGB

export type MilestoneKind = "Title" | "Pet" | "Skin"

export type MilestoneDef = {
	Id: string, -- PlayerData.Milestones key (never rename: saves keep it)
	Rebirths: number,
	Kind: MilestoneKind,
	Name: string, -- shown in the Rebirth panel / toast
	Title: string?, -- Kind "Title"
	TitleColor: Color3?,
	PetId: string?, -- Kind "Pet": an Exclusive Config.Pets id
	SkinId: string?, -- Kind "Skin": an Endgame.Skins id
}

export type SkinDef = {
	Id: string,
	Name: string,
	HeadColor: Color3,
	HandleColor: Color3,
	Material: Enum.Material,
	Glow: boolean,
}

local Endgame = {
	-- C2 Rainbow pets (Golden: x1.5 sand bonus, 1.25x dig speed, Config.GOLDEN_*)
	RAINBOW_FUSE_COUNT = 5, -- Golden copies fused into one Rainbow pet (= 25 plain copies)
	RAINBOW_SAND_BONUS = 2.25, -- a Rainbow pet's sand bonus (Multiplier - 1) is x2.25
	RAINBOW_DIG_SPEED = 1.5, -- a Rainbow digging pet digs 1.5x as often (Interval / 1.5)

	-- C3 Index mastery
	INDEX_MASTER_BONUS = 0.03, -- +3% sand per mastered layer (15 layers = +45%)
	MASTERY_VARIANTS = { "Tiny", "Normal", "Large", "Giant", "Golden", "Fossilized", "Crystal" },

	-- C4 placeholder: the Index Master badge lives in Config/Badges.luau (Id 0 until the owner
	-- creates it).
}

local Skins: { SkinDef } = {
	{
		Id = "starforged",
		Name = "Starforged",
		HeadColor = rgb(150, 225, 255),
		HandleColor = rgb(48, 30, 96),
		Material = Enum.Material.Neon,
		Glow = true,
	},
}

local Milestones: { MilestoneDef } = {
	{
		Id = "r12",
		Rebirths = 12,
		Kind = "Title",
		Name = "Title: Reborn Veteran",
		Title = "Reborn Veteran",
		TitleColor = rgb(200, 150, 255),
	},
	{ Id = "r15", Rebirths = 15, Kind = "Pet", Name = "Pet: Reborn Phoenix", PetId = "reborn_phoenix" },
	{ Id = "r20", Rebirths = 20, Kind = "Skin", Name = "Shovel skin: Starforged", SkinId = "starforged" },
	{
		Id = "r25",
		Rebirths = 25,
		Kind = "Title",
		Name = "Title: Eternal Digger",
		Title = "Eternal Digger",
		TitleColor = rgb(255, 215, 90),
	},
	{ Id = "r30", Rebirths = 30, Kind = "Pet", Name = "Pet: Eternal Wyrm", PetId = "eternal_wyrm" },
}
table.sort(Milestones, function(a: MilestoneDef, b: MilestoneDef): boolean
	return a.Rebirths < b.Rebirths
end)

Endgame.Milestones = Milestones
Endgame.Skins = Skins

local milestoneById: { [string]: MilestoneDef } = {}
local skinById: { [string]: SkinDef } = {}
local petIds: { [string]: Types.PetDef } = {}
for _, pet in Pets do
	petIds[pet.Id] = pet
end
for _, skin in Skins do
	assert(skinById[skin.Id] == nil, "Endgame: duplicate skin " .. skin.Id)
	skinById[skin.Id] = skin
end
for _, m in Milestones do
	assert(milestoneById[m.Id] == nil, "Endgame: duplicate milestone " .. m.Id)
	milestoneById[m.Id] = m
	if m.Kind == "Title" then
		assert(m.Title, "Endgame: title milestone without Title " .. m.Id)
	elseif m.Kind == "Pet" then
		local pet = m.PetId and petIds[m.PetId]
		assert(pet and pet.Exclusive, "Endgame: milestone pet must be an Exclusive pet " .. m.Id)
	else
		assert(m.SkinId and skinById[m.SkinId], "Endgame: unknown skin on milestone " .. m.Id)
	end
end

function Endgame.GetMilestone(id: string): MilestoneDef?
	return milestoneById[id]
end

function Endgame.GetSkin(id: string): SkinDef?
	return skinById[id]
end

-- The milestone that unlocks a skin (nil for an unknown skin).
function Endgame.SkinMilestone(skinId: string): MilestoneDef?
	for _, m in Milestones do
		if m.SkinId == skinId then
			return m
		end
	end
	return nil
end

-- Milestones reached at `rebirths` (in order).
function Endgame.Reached(rebirths: number): { MilestoneDef }
	local list = {}
	for _, m in Milestones do
		if rebirths >= m.Rebirths then
			table.insert(list, m)
		end
	end
	return list
end

-- The next milestone above `rebirths`, or nil when all are reached.
function Endgame.NextMilestone(rebirths: number): MilestoneDef?
	for _, m in Milestones do
		if rebirths < m.Rebirths then
			return m
		end
	end
	return nil
end

-- Nameplate title from the highest Title milestone reached, or nil (then the layer title shows).
function Endgame.TitleFor(rebirths: number): (string?, Color3?)
	local title: string?, color: Color3? = nil, nil
	for _, m in Milestones do
		if m.Kind == "Title" and rebirths >= m.Rebirths then
			title, color = m.Title, m.TitleColor
		end
	end
	return title, color
end

-- A shovel look with a skin applied (shape and size stay the shovel's). Unknown skin: unchanged.
function Endgame.ApplySkin(look: Types.ShovelLook, skinId: string?): Types.ShovelLook
	local skin = if skinId then skinById[skinId] else nil
	if not skin then
		return look
	end
	local skinned = table.clone(look)
	skinned.HeadColor = skin.HeadColor
	skinned.HandleColor = skin.HandleColor
	skinned.Material = skin.Material
	skinned.Glow = skin.Glow
	return skinned
end

-- C3 ----------------------------------------------------------------------------------------------

-- Same key format as Util/Finds.VariantKey ("treasureId/VariantId"); Finds requires Config, so it
-- can't be used from here.
local function variantKey(treasureId: string, variant: string): string
	return treasureId .. "/" .. variant
end

-- Is every treasure of layer `layerIndex` found in every MASTERY_VARIANTS variant?
function Endgame.IsLayerMastered(layerIndex: number, variants: { [string]: boolean }?): boolean
	local layer = Layers[layerIndex]
	if not layer or type(variants) ~= "table" or #layer.LootTable == 0 then
		return false
	end
	local seen = variants :: { [string]: boolean }
	for _, entry in layer.LootTable do
		for _, variant in Endgame.MASTERY_VARIANTS do
			if seen[variantKey(entry.TreasureId, variant)] ~= true then
				return false
			end
		end
	end
	return true
end

-- (variants found, variants needed) for a layer's mastery progress bar.
function Endgame.MasteryProgress(layerIndex: number, variants: { [string]: boolean }?): (number, number)
	local layer = Layers[layerIndex]
	if not layer then
		return 0, 0
	end
	local seen: { [string]: boolean } = if type(variants) == "table" then variants else {}
	local have, total = 0, 0
	for _, entry in layer.LootTable do
		for _, variant in Endgame.MASTERY_VARIANTS do
			total += 1
			if seen[variantKey(entry.TreasureId, variant)] == true then
				have += 1
			end
		end
	end
	return have, total
end

-- Recorded mastered layers that still exist (tolerates junk / removed layers in old saves).
function Endgame.CountMastered(mastered: { [string]: boolean }?): number
	if type(mastered) ~= "table" then
		return 0
	end
	local n = 0
	for _, layer in Layers do
		if (mastered :: any)[layer.Id] == true then
			n += 1
		end
	end
	return n
end

return Endgame
