--!strict
--[[
	Shades — placeable shade items (owner: Survival), ordered by price. Bought once with coins
	(PlayerData.OwnedShades), placed on the beach sand, cools ANYONE standing under it.

	Radius  = horizontal studs of shade around the pole.
	Cooling = multiplier on Config.Heat.ShadeFallPerSecond (3/s): 1 -> 100..40 heat in 20 s.
	Height  = studs from the ground to the underside of the canopy (models are built to match).
	Prices sit next to the shovel ladder (GDD §4): the umbrella is the first "extra" purchase
	(~3-5 min, after the trowel / pail / spade); each tier costs ~7-10x the last.
	Look.Style picks the model builder in Models/Shades.luau.
]]
local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Shades: { Types.ShadeDef } = {
	{
		Id = "beach_umbrella",
		Name = "Beach Umbrella",
		Price = 120,
		Radius = 6,
		Cooling = 1,
		Height = 7.5,
		Description = "A trusty umbrella. Shade for you and a friend.",
		Look = { Style = "Umbrella", Color = rgb(255, 80, 90), Accent = rgb(255, 255, 255) },
	},
	{
		Id = "striped_umbrella",
		Name = "Striped Umbrella",
		Price = 1200,
		Radius = 8,
		Cooling = 1.4,
		Height = 8,
		Description = "Extra-wide rainbow stripes. Cools faster!",
		Look = { Style = "Striped", Color = rgb(40, 170, 255), Accent = rgb(255, 225, 60) },
	},
	{
		Id = "palm_tarp",
		Name = "Palm Tarp",
		Price = 12000,
		Radius = 10,
		Cooling = 1.8,
		Height = 8.5,
		Description = "A big tarp tied between palm-wood poles. Room for the squad.",
		Look = { Style = "Tarp", Color = rgb(255, 150, 40), Accent = rgb(176, 120, 72) },
	},
	{
		Id = "party_canopy",
		Name = "Party Canopy",
		Price = 100000,
		Radius = 12,
		Cooling = 2.3,
		Height = 9,
		Description = "A pop-up party tent with bunting. Very cool. Literally.",
		Look = { Style = "Canopy", Color = rgb(90, 210, 120), Accent = rgb(255, 255, 255) },
	},
	{
		Id = "tiki_cabana",
		Name = "Tiki Cabana",
		Price = 750000,
		Radius = 14,
		Cooling = 2.8,
		Height = 9,
		Description = "A thatched tiki hut with curtains. Island vibes.",
		Look = { Style = "Cabana", Color = rgb(225, 190, 110), Accent = rgb(255, 120, 150) },
	},
	{
		Id = "luxury_tent",
		Name = "Luxury Beach Tent",
		Price = 6000000,
		RebirthsRequired = 1,
		Radius = 17,
		Cooling = 3.5,
		Height = 9.5,
		Description = "Silk walls and gold poles. Requires 1 Rebirth.",
		Look = { Style = "Tent", Color = rgb(250, 245, 235), Accent = rgb(255, 200, 40) },
	},
	{
		Id = "royal_pavilion",
		Name = "Royal Sand Pavilion",
		Price = 80000000,
		RebirthsRequired = 3,
		Radius = 21,
		Cooling = 4.5,
		Height = 10,
		Description = "Fit for the King of Sandlantis. Shade for the whole beach! Requires 3 Rebirths.",
		Look = { Style = "Pavilion", Color = rgb(150, 90, 255), Accent = rgb(255, 205, 40) },
	},
}

return Shades
