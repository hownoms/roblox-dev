--!strict
--[[
	Discovery (v3 slice) — buried finds, the detector, the excavation minigame and rarity
	presentation. Read-only balance data; the logic lives in Shared/Util/Finds.luau (pure, used by
	server and client) and Services/DiscoveryService.luau. Design + odds tables:
	docs/design/Discovery.md.

	Deposits are pure server data in "chunks" (CHUNK x CHUNK_Y x CHUNK studs of the dig zone,
	seeded lazily the first time anything looks at them). A digging carve that comes within
	UncoverRadius studs of a deposit uncovers it; the first player to uncover it owns the
	excavation. Variants (size + material) are rolled when the deposit is uncovered, so the
	uncoverer's luck applies (true odds shown in the Index); the treasure itself is rolled at
	seeding so the detector can hint its tier.
]]

local Types = require(script.Parent.Parent.Types)

export type VariantDef = {
	Id: string,
	Name: string, -- shown before the item name ("Giant", "Golden"); "" for the default
	Short: string, -- 1-4 letter Index pill label (no emoji: TextScaled labels)
	Weight: number, -- base odds weight (all weights of a group sum to 100 = percent)
	ValueMultiplier: number,
	Lucky: boolean, -- luck multiplies this weight (rarer-than-default variants)
	Scale: number?, -- size variants: model scale
	Color: Color3, -- Index pill / reveal row colour
}

export type QualityDef = {
	Id: Types.FindQuality,
	Name: string,
	MinScore: number, -- excavation score (Perfect = 2, Good = 1 per ring) needed
	ValueMultiplier: number,
	Color: Color3,
}

local rgb = Color3.fromRGB

local Discovery = {
	-- Seeding ---------------------------------------------------------------------------------
	CHUNK = 32, -- chunk size in X and Z (studs)
	CHUNK_Y = 16, -- chunk height (studs): the top band (depth 3-16) is what a new player reaches first
	MIN_DEPTH = 3, -- deposits sit at least this far below the surface (visible surface ~2 above grid)
	EDGE_MARGIN = 1.5, -- studs kept clear of the zone walls / floor
	MIN_SPACING = 5, -- studs between two deposits of the same chunk
	CHUNK_CAP = 16, -- never more deposits than this in one chunk
	SERVER_CAP = 4000, -- never more deposits than this on the server (oldest chunks evicted)
	RESPAWN_SECONDS = 90, -- a chunk below its target regrows one deposit this often
	EVICT_SECONDS = 300, -- chunks nobody touched for this long are forgotten (re-seeded fresh)
	-- Deposits per chunk (32 x 16 x 32 studs) by layer index (fraction = chance of one more).
	-- Layer 1 is calibrated in tests (starter Hand Spade standing still: ~1 find / 30-60 s);
	-- deeper layers scale by 1 / sweep of that layer's typical shovel, sweep = (edge + 5)^2 x
	-- edge / cooldown (edge = carved cube, + 2 x UNCOVER_RADIUS margin), so finds per SECOND
	-- stay about the same while finds per stud get rarer (docs/design/Discovery.md).
	DENSITY = { 10, 10, 9, 10, 10, 3, 2.7, 2.5, 2.2, 0.8, 0.7, 0.6, 0.55, 0.25, 0.2 } :: { number },

	-- Uncovering -------------------------------------------------------------------------------
	UNCOVER_RADIUS = 3, -- a carve within this many studs of a deposit uncovers it
	-- Ambient junk: a tiny per-dig chance of a Common treasure straight into the backpack (no
	-- minigame), = layer.TreasureChance x luck x this. Keeps a little popcorn between deposits.
	AMBIENT_FACTOR = 0.1,
	-- FTUE: a brand-new player's Nth successful dig always uncovers a Common find right there.
	FTUE_FIND_DIG = 6,

	-- Relics (rarity "Relic"): any deposit has this chance to hold a Relic whose Layer <= the
	-- deposit's layer. Relic value = TreasureDef.ScaledValue seconds of income (RewardScale of the
	-- player's deepest layer), so a Relic is a jackpot at every stage of the game.
	RELIC_CHANCE = 1 / 400,

	-- Detector -----------------------------------------------------------------------------------
	DETECTOR_RANGE = 24, -- studs (upgradeable later)
	SCAN_SECONDS = 6, -- one Scan pings for this long...
	SCAN_COOLDOWN = 8, -- ...and can be started again this long after the previous start
	PING_INTERVAL = 0.5, -- seconds between DetectorPing updates during a scan
	-- Distance bands (studs): band 1 = hot (< 6), 2 (< 12), 3 (< 18), 4 (< range), 0 = nothing.
	BANDS = { 6, 12, 18 } :: { number },
	SECTORS = 8, -- horizontal direction is quantised to this many compass sectors
	VERTICAL_LEVEL = 4, -- |dy| under this many studs reads "Level"
	-- "Dig straight down here": the find is below (or above) and its horizontal offset is under
	-- max(OVERHEAD_MIN, |dy| x OVERHEAD_SLOPE). Walking would not help, so the detector says so
	-- instead of showing a wobbling compass sector.
	OVERHEAD_MIN = 3,
	OVERHEAD_SLOPE = 0.5,
	-- Detector signal colour by rarity (hints the tier, never the item).
	SIGNAL_BY_RARITY = {
		Common = "White",
		Uncommon = "White",
		Rare = "Gold",
		Epic = "Gold",
		Legendary = "Gold",
		Mythic = "Purple",
		Relic = "Purple",
	} :: { [string]: Types.DetectorSignal },
	SIGNAL_COLORS = {
		White = rgb(235, 240, 255),
		Gold = rgb(255, 200, 40),
		Purple = rgb(190, 90, 255),
	} :: { [string]: Color3 },

	-- Excavation minigame -------------------------------------------------------------------------
	RINGS = 3, -- timed taps
	RING_SECONDS = 0.9, -- a ring shrinks onto the target in this long
	RING_GAP = 0.25, -- pause between rings
	PERFECT_WINDOW = 0.09, -- |tap - target| <= this: Perfect (2 points)
	GOOD_WINDOW = 0.22, -- <= this: Good (1 point); later / earlier / no tap: Miss (0)
	-- Server checks (anti-cheat; quality only changes value, so cheating gains at most x1.5/x1):
	MIN_EXCAVATION_SECONDS = 1.6, -- answered faster than this -> quality capped at Good
	EXCAVATION_TIMEOUT = 9, -- no answer by then -> resolved with no hits (Damaged, never lost)
	REVEAL_SECONDS = 5, -- the dug-up model stays in the world this long after the reveal
	SPECTACLE_SECONDS = 12, -- Mythic / Relic models (with their sky beam) stay this long

	-- Variants -------------------------------------------------------------------------------------
	SIZES = {
		{
			Id = "Tiny",
			Name = "Tiny",
			Short = "XS",
			Weight = 20,
			ValueMultiplier = 0.5,
			Lucky = false,
			Scale = 0.6,
			Color = rgb(170, 210, 255),
		},
		{
			Id = "Normal",
			Name = "",
			Short = "M",
			Weight = 62,
			ValueMultiplier = 1,
			Lucky = false,
			Scale = 1,
			Color = rgb(235, 235, 235),
		},
		{
			Id = "Large",
			Name = "Large",
			Short = "L",
			Weight = 14,
			ValueMultiplier = 2,
			Lucky = true,
			Scale = 1.5,
			Color = rgb(120, 230, 120),
		},
		{
			Id = "Giant",
			Name = "Giant",
			Short = "XL",
			Weight = 4,
			ValueMultiplier = 5,
			Lucky = true,
			Scale = 2.4,
			Color = rgb(255, 140, 60),
		},
	} :: { VariantDef },
	MATERIALS = {
		{
			Id = "None",
			Name = "",
			Short = "-",
			Weight = 88,
			ValueMultiplier = 1,
			Lucky = false,
			Color = rgb(235, 235, 235),
		},
		{
			Id = "Golden",
			Name = "Golden",
			Short = "Gold",
			Weight = 7,
			ValueMultiplier = 3,
			Lucky = true,
			Color = rgb(255, 205, 40),
		},
		{
			Id = "Fossilized",
			Name = "Fossilized",
			Short = "Fos",
			Weight = 3.5,
			ValueMultiplier = 5,
			Lucky = true,
			Color = rgb(170, 140, 110),
		},
		{
			Id = "Crystal",
			Name = "Crystal",
			Short = "Cry",
			Weight = 1.5,
			ValueMultiplier = 10,
			Lucky = true,
			Color = rgb(120, 230, 255),
		},
	} :: { VariantDef },
	QUALITIES = {
		{ Id = "Damaged", Name = "Damaged", MinScore = 0, ValueMultiplier = 0.6, Color = rgb(200, 150, 120) },
		{ Id = "Good", Name = "Good", MinScore = 2, ValueMultiplier = 1, Color = rgb(235, 235, 235) },
		{ Id = "Pristine", Name = "Pristine", MinScore = 5, ValueMultiplier = 1.5, Color = rgb(120, 255, 200) },
	} :: { QualityDef },

	-- Presentation tier by rarity (Finds.Tier also bumps a Pop to a Beam for Giant / material finds).
	TIER_BY_RARITY = {
		Common = "Pop",
		Uncommon = "Pop",
		Rare = "Beam",
		Epic = "Card",
		Legendary = "Card",
		Mythic = "Server",
		Relic = "Spectacle",
	} :: { [string]: Types.FindTier },
}

return Discovery
