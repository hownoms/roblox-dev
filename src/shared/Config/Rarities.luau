--!strict
--[[
	Rarities — display data for treasure & pet rarities. Ordered array (Order 1..7; 7 = Relic, v3 finds only) plus the
	lookup helper Config.GetRarity(name). Gradient is meant for a UIGradient on rarity cards.
	Announce = broadcast a server-wide toast/chat message when anyone finds or hatches one.
]]

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Rarities: { Types.RarityDef } = {
	{
		Name = "Common",
		Order = 1,
		Color = rgb(200, 205, 215),
		Gradient = { rgb(230, 232, 238), rgb(170, 176, 190) },
		Announce = false,
	},
	{
		Name = "Uncommon",
		Order = 2,
		Color = rgb(90, 220, 100),
		Gradient = { rgb(150, 255, 150), rgb(40, 180, 80) },
		Announce = false,
	},
	{
		Name = "Rare",
		Order = 3,
		Color = rgb(60, 160, 255),
		Gradient = { rgb(120, 210, 255), rgb(30, 100, 240) },
		Announce = false,
	},
	{
		Name = "Epic",
		Order = 4,
		Color = rgb(180, 90, 255),
		Gradient = { rgb(220, 150, 255), rgb(130, 50, 230) },
		Announce = false,
	},
	{
		Name = "Legendary",
		Order = 5,
		Color = rgb(255, 190, 30),
		Gradient = { rgb(255, 235, 100), rgb(255, 130, 20) },
		Announce = true,
	},
	{
		Name = "Mythic",
		Order = 6,
		Color = rgb(255, 70, 140),
		Gradient = { rgb(255, 90, 90), rgb(255, 210, 60), rgb(90, 220, 255), rgb(200, 90, 255) },
		Announce = true,
	},
	-- v3 discovery slice: above Mythic, only from buried finds (Config.Discovery.RELIC_CHANCE).
	{
		Name = "Relic",
		Order = 7,
		Color = rgb(120, 255, 230),
		Gradient = { rgb(255, 255, 255), rgb(120, 255, 230), rgb(255, 120, 230), rgb(255, 230, 120) },
		Announce = true,
	},
}

return Rarities
