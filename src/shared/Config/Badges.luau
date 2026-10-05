--!strict
-- Roblox badges. Create each badge in Creator Hub (art in marketing/badges/) and paste its id.
-- Id 0 = not configured; the server skips it.
export type BadgeKind = "FirstDig" | "FirstPet" | "ReachLayer" | "Rebirth"

export type BadgeDef = {
	Key: string,
	Id: number,
	Name: string,
	Kind: BadgeKind,
	Layer: string?, -- ReachLayer: Config.Layers[].Name; depth comes from that layer's DepthStart
	Count: number?, -- Rebirth: rebirths required
}

local Badges: { BadgeDef } = {
	{ Key = "Welcome", Id = 0, Name = "Welcome to the Beach!", Kind = "FirstDig" },
	{ Key = "FirstPet", Id = 0, Name = "New Best Friend", Kind = "FirstPet" },
	{ Key = "PirateCove", Id = 0, Name = "Arrr, Pirate Cove!", Kind = "ReachLayer", Layer = "Pirate Cove" },
	{ Key = "FossilBed", Id = 0, Name = "Dino Digger", Kind = "ReachLayer", Layer = "Fossil Bed" },
	{ Key = "CrystalCaverns", Id = 0, Name = "Crystal Clear", Kind = "ReachLayer", Layer = "Crystal Caverns" },
	{ Key = "FrozenAbyss", Id = 0, Name = "Underground Ice Age", Kind = "ReachLayer", Layer = "Frozen Abyss" },
	{ Key = "MagmaChamber", Id = 0, Name = "Too Hot to Handle", Kind = "ReachLayer", Layer = "Magma Chamber" },
	{ Key = "AlienHive", Id = 0, Name = "Close Encounter", Kind = "ReachLayer", Layer = "Alien Hive" },
	{ Key = "TheCore", Id = 0, Name = "I Reached the Core!", Kind = "ReachLayer", Layer = "The Core" },
	{ Key = "FirstRebirth", Id = 0, Name = "Born Again", Kind = "Rebirth", Count = 1 },
}

return Badges
