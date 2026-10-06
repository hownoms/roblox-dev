--!strict
--[[
	Titles — overhead nameplate title earned by the deepest layer a player has ever reached
	(PlayerData.MaxDepth, kept through rebirths). Index i = Config.Layers[i]; one title per layer.
	Color: the layer colour, except where that is too dark to read over the world with a dark
	outline (then a lighter tint of the same hue). Status & Social agent (v2.2 B6a).
]]

local rgb = Color3.fromRGB

export type TitleDef = {
	LayerId: string, -- must match Config.Layers[i].Id (checked in Config/init)
	Title: string,
	Color: Color3?, -- nil: use the layer colour
}

local Titles: { TitleDef } = {
	{ LayerId = "dry_sand", Title = "Sandcastle Rookie" },
	{ LayerId = "wet_sand", Title = "Bucket Brigade" },
	{ LayerId = "shell_bed", Title = "Shell Seeker" },
	{ LayerId = "tidal_clay", Title = "Clay Crawler", Color = rgb(214, 160, 126) },
	{ LayerId = "pirate_cove", Title = "Pirate Plunderer", Color = rgb(222, 168, 110) },
	{ LayerId = "shipwreck", Title = "Wreck Diver", Color = rgb(214, 156, 104) },
	{ LayerId = "fossil_bed", Title = "Fossil Hunter" },
	{ LayerId = "bedrock", Title = "Rock Breaker", Color = rgb(184, 188, 204) },
	{ LayerId = "crystal_caverns", Title = "Crystal Miner" },
	{ LayerId = "frozen_abyss", Title = "Ice Tunneler" },
	{ LayerId = "ancient_ruins", Title = "Ruin Raider" },
	{ LayerId = "magma_chamber", Title = "Magma Diver" },
	{ LayerId = "obsidian_depths", Title = "Obsidian Delver", Color = rgb(170, 130, 240) },
	{ LayerId = "alien_hive", Title = "Hive Invader" },
	{ LayerId = "the_core", Title = "Core Breaker" },
}

return Titles
