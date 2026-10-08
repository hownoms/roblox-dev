--!strict
-- Roblox badges. Create each badge in Creator Hub (art in marketing/badges/) and paste its id.
-- Id 0 = not configured; the server skips it.
export type BadgeKind = "FirstDig" | "FirstPet" | "ReachLayer" | "Rebirth" | "FindRarity" | "CompleteLayer" | "DailyStreak"

export type BadgeDef = {
	Key: string,
	Id: number,
	Name: string,
	Kind: BadgeKind,
	Layer: string?, -- ReachLayer: Config.Layers[].Name; depth comes from that layer's DepthStart
	Count: number?, -- Rebirth: rebirths required; DailyStreak: days in a row
	Rarity: string?, -- FindRarity: Config.Rarities name; any treasure of this Order or higher in the Index counts
}

local Badges: { BadgeDef } = {
	{ Key = "Welcome", Id = 305615989875213, Name = "Welcome to the Beach!", Kind = "FirstDig" },
	{ Key = "FirstPet", Id = 1399687731914868, Name = "New Best Friend", Kind = "FirstPet" },
	{ Key = "PirateCove", Id = 3721202346547107, Name = "Arrr, Pirate Cove!", Kind = "ReachLayer", Layer = "Pirate Cove" },
	{ Key = "FossilBed", Id = 1841450014262918, Name = "Dino Digger", Kind = "ReachLayer", Layer = "Fossil Bed" },
	{ Key = "CrystalCaverns", Id = 3808710393122420, Name = "Crystal Clear", Kind = "ReachLayer", Layer = "Crystal Caverns" },
	{ Key = "FrozenAbyss", Id = 0, Name = "Underground Ice Age", Kind = "ReachLayer", Layer = "Frozen Abyss" },
	{ Key = "MagmaChamber", Id = 0, Name = "Too Hot to Handle", Kind = "ReachLayer", Layer = "Magma Chamber" },
	{ Key = "AlienHive", Id = 0, Name = "Close Encounter", Kind = "ReachLayer", Layer = "Alien Hive" },
	{ Key = "TheCore", Id = 0, Name = "I Reached the Core!", Kind = "ReachLayer", Layer = "The Core" },
	{ Key = "FirstRebirth", Id = 0, Name = "Born Again", Kind = "Rebirth", Count = 1 },
	-- Wave 2 (art: marketing/badges/11..15)
	{ Key = "MythicLuck", Id = 0, Name = "Mythic Luck", Kind = "FindRarity", Rarity = "Mythic" },
	{ Key = "Collector", Id = 0, Name = "Collector", Kind = "CompleteLayer" },
	{ Key = "AncientRuins", Id = 0, Name = "Lost Civilization", Kind = "ReachLayer", Layer = "Ancient Ruins" },
	{ Key = "BeachRegular", Id = 0, Name = "Beach Regular", Kind = "DailyStreak", Count = 7 },
	{ Key = "CoreBreaker", Id = 0, Name = "Core Breaker", Kind = "Rebirth", Count = 10 },
}

return Badges
