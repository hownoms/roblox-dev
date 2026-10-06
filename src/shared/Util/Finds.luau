--!strict
--[[
	Finds (v3 discovery slice) — pure functions shared by the server (authoritative) and the client
	(Index odds, reveal presentation, detector UI). Numbers live in Config.Discovery; the design
	is docs/design/Discovery.md.

	Value of a find = base x size x material x quality, where base = TreasureDef.SellValue, or for
	Relics ScaledValue x RewardScale of the player's deepest layer (seconds of income).

	Odds: Finds.VariantOdds(group, luck) is the ONE odds function. The server rolls with
	Finds.RollVariant (= Weighted.Pick over the same list) and the Index shows the same list with
	the player's current luck (Stats.GetLuck), so displayed odds are the true odds.

	Unsold finds are stored in PlayerData.Finds as "treasureId|Size|Material|Quality" -> count.
	Variants seen are in PlayerData.FindVariants as "treasureId/VariantId" -> true.
]]

local Shared = script.Parent.Parent
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local Weighted = require(script.Parent.Weighted)

local D = Config.Discovery

export type VariantOdd = { Id: string, Chance: number }
export type Grade = "Perfect" | "Good" | "Miss"
export type VariantDef = typeof(Config.Discovery.SIZES[1])
export type QualityDef = typeof(Config.Discovery.QUALITIES[1])

local Finds = {}

Finds.TIERS = table.freeze({ "Pop", "Beam", "Card", "Server", "Spectacle" })

local sizeById: { [string]: VariantDef } = {}
for _, v in D.SIZES do
	sizeById[v.Id] = v
end
local materialById: { [string]: VariantDef } = {}
for _, v in D.MATERIALS do
	materialById[v.Id] = v
end
local qualityById: { [string]: QualityDef } = {}
for _, q in D.QUALITIES do
	qualityById[q.Id] = q
end
local tierOrder: { [string]: number } = {}
for i, t in Finds.TIERS do
	tierOrder[t] = i
end

-- Relics by unlock layer (any deposit of layer >= def.Layer may hold one).
local relics: { Types.TreasureDef } = {}
for _, def in Config.Treasures do
	if def.Rarity == "Relic" then
		table.insert(relics, def)
	end
end

function Finds.GetSize(id: string): VariantDef?
	return sizeById[id]
end

function Finds.GetMaterial(id: string): VariantDef?
	return materialById[id]
end

function Finds.GetQuality(id: string): QualityDef?
	return qualityById[id]
end

function Finds.IsSize(id: any): boolean
	return type(id) == "string" and sizeById[id] ~= nil
end

function Finds.IsMaterial(id: any): boolean
	return type(id) == "string" and materialById[id] ~= nil
end

-- Keys ------------------------------------------------------------------------------------------

function Finds.Key(treasureId: string, size: string, material: string, quality: string): string
	return treasureId .. "|" .. size .. "|" .. material .. "|" .. quality
end

-- (treasureId, size, material, quality) or nil for a malformed / unknown key.
function Finds.ParseKey(key: string): (string?, string?, string?, string?)
	local id, size, material, quality = string.match(key, "^([^|]+)|([^|]+)|([^|]+)|([^|]+)$")
	if not id or not size or not material or not quality then
		return nil, nil, nil, nil
	end
	local i, sz, m, q = id :: string, size :: string, material :: string, quality :: string
	if not Config.GetTreasure(i) or not sizeById[sz] or not materialById[m] or not qualityById[q] then
		return nil, nil, nil, nil
	end
	return i, sz, m, q
end

function Finds.VariantKey(treasureId: string, variantId: string): string
	return treasureId .. "/" .. variantId
end

-- Odds -------------------------------------------------------------------------------------------

local function sanitizeLuck(luck: number?): number
	local l = luck or 1
	if l ~= l or l == math.huge or l < 1 then
		return 1
	end
	return l
end

-- True odds of a variant group ("Size" | "Material") at this luck: luck multiplies the weight of
-- every Lucky (rarer-than-default) variant. Returns { {Id, Chance} } in config order, sums to 1.
function Finds.VariantOdds(group: string, luck: number?): { VariantOdd }
	local list: { VariantDef } = if group == "Size" then D.SIZES else D.MATERIALS
	local l = sanitizeLuck(luck)
	local total = 0
	for _, v in list do
		total += v.Weight * (if v.Lucky then l else 1)
	end
	local out: { VariantOdd } = {}
	for _, v in list do
		table.insert(out, { Id = v.Id, Chance = v.Weight * (if v.Lucky then l else 1) / total })
	end
	return out
end

function Finds.RollVariant(group: string, luck: number?, roll: number): string
	local odds = Finds.VariantOdds(group, luck)
	local picked = Weighted.Pick(odds, function(o: VariantOdd): number
		return o.Chance
	end, roll)
	return if picked then picked.Id else (if group == "Size" then "Normal" else "None")
end

-- Deposit contents: a Relic with D.RELIC_CHANCE (when one is unlocked at this layer), else the
-- layer's LootTable at base weights. relicRoll / lootRoll in [0, 1).
function Finds.RollTreasure(layerIndex: number, relicRoll: number, lootRoll: number): string?
	local index = math.clamp(math.floor(layerIndex), 1, #Config.Layers)
	if relicRoll < D.RELIC_CHANCE then
		local eligible: { Types.TreasureDef } = {}
		for _, def in relics do
			if def.Layer <= index then
				table.insert(eligible, def)
			end
		end
		if #eligible > 0 then
			return eligible[math.clamp(math.floor(lootRoll * #eligible) + 1, 1, #eligible)].Id
		end
	end
	local entry = Weighted.Pick(Config.Layers[index].LootTable, function(e: Types.LootEntry): number
		return e.Weight
	end, lootRoll)
	return if entry then entry.TreasureId else nil
end

function Finds.Relics(): { Types.TreasureDef }
	return relics
end

-- Expected deposits per chunk at a layer (fraction = chance of one more).
function Finds.Density(layerIndex: number): number
	return D.DENSITY[math.clamp(math.floor(layerIndex), 1, #D.DENSITY)]
end

-- Excavation scoring ---------------------------------------------------------------------------------

-- One ring: absolute timing error in seconds (negative / NaN / non-number = no tap).
function Finds.Grade(err: any): Grade
	if type(err) ~= "number" or err ~= err or err < 0 then
		return "Miss"
	end
	if err <= D.PERFECT_WINDOW then
		return "Perfect"
	elseif err <= D.GOOD_WINDOW then
		return "Good"
	end
	return "Miss"
end

-- Scores a client report (clamped: at most D.RINGS entries count). Returns (score, perfects).
function Finds.Score(errors: any): (number, number)
	if type(errors) ~= "table" then
		return 0, 0
	end
	local score, perfects = 0, 0
	for i = 1, D.RINGS do
		local grade = Finds.Grade((errors :: { any })[i])
		if grade == "Perfect" then
			score += 2
			perfects += 1
		elseif grade == "Good" then
			score += 1
		end
	end
	return score, perfects
end

function Finds.QualityForScore(score: number): Types.FindQuality
	local best: Types.FindQuality = "Damaged"
	for _, q in D.QUALITIES do
		if score >= q.MinScore then
			best = q.Id
		end
	end
	return best
end

-- Value -----------------------------------------------------------------------------------------

function Finds.BaseValue(def: Types.TreasureDef, maxDepth: number): number
	if def.ScaledValue then
		return def.ScaledValue * Config.GetLayerAtDepth(maxDepth).RewardScale
	end
	return def.SellValue
end

-- Coins for one find (before coin boosts / events), rounded down, at least 1.
function Finds.Value(treasureId: string, size: string, material: string, quality: string, maxDepth: number): number
	local found = Config.GetTreasure(treasureId)
	if not found then
		return 0
	end
	local def = found :: Types.TreasureDef
	local s = sizeById[size]
	local m = materialById[material]
	local q = qualityById[quality]
	local mult = (if s then s.ValueMultiplier else 1)
		* (if m then m.ValueMultiplier else 1)
		* (if q then q.ValueMultiplier else 1)
	return math.max(1, math.floor(Finds.BaseValue(def, maxDepth) * mult))
end

-- Total coins of a PlayerData.Finds table (unknown keys ignored).
function Finds.TotalValue(finds: { [string]: number }?, maxDepth: number): number
	local total = 0
	local list: { [string]: number } = finds or {}
	for key, count in list do
		if type(key) == "string" and type(count) == "number" and count > 0 then
			local id, size, material, quality = Finds.ParseKey(key)
			if id and size and material and quality then
				total += Finds.Value(id, size, material, quality, maxDepth) * count
			end
		end
	end
	return total
end

function Finds.Count(finds: { [string]: number }?): number
	local n = 0
	local list: { [string]: number } = finds or {}
	for _, count in list do
		if type(count) == "number" and count > 0 then
			n += count
		end
	end
	return n
end

-- Presentation --------------------------------------------------------------------------------------

function Finds.TierOrder(tier: string): number
	return tierOrder[tier] or 1
end

-- Tier by rarity; a Giant or any material variant lifts a Pop to a Beam (variants feel special).
function Finds.Tier(rarity: string, size: string?, material: string?): Types.FindTier
	local tier: Types.FindTier = D.TIER_BY_RARITY[rarity] or "Pop"
	if tier == "Pop" and (size == "Giant" or (material ~= nil and material ~= "None")) then
		tier = "Beam"
	end
	return tier
end

function Finds.Signal(rarity: string): Types.DetectorSignal
	return D.SIGNAL_BY_RARITY[rarity] or "White"
end

-- "Giant Golden Bottle Cap" (default variants add nothing).
function Finds.DisplayName(treasureId: string, size: string?, material: string?): string
	local def = Config.GetTreasure(treasureId)
	local parts = {}
	local s = if size then sizeById[size] else nil
	local m = if material then materialById[material] else nil
	if s and s.Name ~= "" then
		table.insert(parts, s.Name)
	end
	if m and m.Name ~= "" then
		table.insert(parts, m.Name)
	end
	table.insert(parts, if def then def.Name else treasureId)
	return table.concat(parts, " ")
end

-- Detector --------------------------------------------------------------------------------------------

-- 1 (hot) .. #BANDS + 1 (edge of range), 0 = out of range.
function Finds.Band(distance: number, range: number?): number
	if distance ~= distance or distance > (range or D.DETECTOR_RANGE) then
		return 0
	end
	for i, limit in D.BANDS do
		if distance < limit then
			return i
		end
	end
	return #D.BANDS + 1
end

-- Compass sector of a horizontal offset: 0 = +Z, increasing towards +X. -1 for ~zero offset.
function Finds.Sector(dx: number, dz: number): number
	if math.abs(dx) < 0.5 and math.abs(dz) < 0.5 then
		return -1
	end
	local angle = math.atan2(dx, dz) -- 0 at +Z, +pi/2 at +X
	return math.floor(angle / (2 * math.pi) * D.SECTORS + 0.5) % D.SECTORS
end

-- Unit horizontal world direction of a sector (inverse of Finds.Sector).
function Finds.SectorDirection(sector: number): Vector3
	local angle = sector / D.SECTORS * 2 * math.pi
	return Vector3.new(math.sin(angle), 0, math.cos(angle))
end

function Finds.Vertical(dy: number): string
	if dy <= -D.VERTICAL_LEVEL then
		return "Down"
	elseif dy >= D.VERTICAL_LEVEL then
		return "Up"
	end
	return "Level"
end

-- The coarse ping for a deposit at `offset` (deposit - player) of this rarity.
function Finds.Ping(offset: Vector3?, rarity: string?, remaining: number, range: number?): Types.DetectorPing
	if not offset or not rarity then
		return { Band = 0, Sector = -1, Vertical = "", Signal = "", Remaining = remaining }
	end
	local o = offset :: Vector3
	local band = Finds.Band(o.Magnitude, range)
	if band == 0 then
		return { Band = 0, Sector = -1, Vertical = "", Signal = "", Remaining = remaining }
	end
	return {
		Band = band,
		Sector = Finds.Sector(o.X, o.Z),
		Vertical = Finds.Vertical(o.Y),
		Signal = Finds.Signal(rarity :: string),
		Remaining = remaining,
	}
end

-- Seconds between detector beeps for a band (client sound pacing).
function Finds.BeepInterval(band: number): number
	if band <= 0 then
		return 0
	end
	return ({ 0.12, 0.25, 0.45, 0.8 })[math.clamp(band, 1, 4)]
end

return Finds
