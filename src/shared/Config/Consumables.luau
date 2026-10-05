--!strict
--[[
	Consumables — drinks & snacks (owner: Survival). Bought with coins into
	PlayerData.Consumables[id] (count), used from the HUD quick-slots (keys 1/2/3).

	Cooling      = heat removed instantly (Config.Heat.Max = 100).
	Boost        = Config.Boosts id granted on use for BoostSeconds (snack boosts stack time up to
	               Config.Heat.ConsumableBoostCapSeconds).
	Price 0      = not sold: water is free and unlimited, but only at the hub fountain
	               (DrinkFountain).
	Look.Style picks the model builder in Models/Consumables.luau.
]]
local Types = require(script.Parent.Parent.Types)
local Boosts = require(script.Parent.Boosts)

local rgb = Color3.fromRGB

local Consumables: { Types.ConsumableDef } = {
	{
		Id = "water",
		Name = "Fountain Water",
		Price = 0,
		Cooling = 70,
		Icon = "💧",
		Description = "Free at the fountain! Cools you right down.",
		Look = { Style = "Bottle", Color = rgb(120, 200, 255) },
	},
	{
		Id = "lemonade",
		Name = "Lemonade",
		Price = 40,
		Cooling = 35,
		Icon = "🍋",
		Description = "Fresh and fizzy. A quick cool-down.",
		Look = { Style = "Cup", Color = rgb(255, 235, 90) },
	},
	{
		Id = "coconut_water",
		Name = "Coconut Water",
		Price = 250,
		Cooling = 60,
		Icon = "🥥",
		Description = "Straight from the palm tree. Big cool-down.",
		Look = { Style = "Coconut", Color = rgb(130, 85, 50) },
	},
	{
		Id = "popsicle",
		Name = "Popsicle",
		Price = 1200,
		Cooling = 50,
		Boost = "SugarRush",
		BoostSeconds = 30,
		Icon = "🍭",
		Description = "Brain freeze! Dig 25% faster for 30s.",
		Look = { Style = "Popsicle", Color = rgb(255, 90, 140) },
	},
	{
		Id = "shaved_ice",
		Name = "Shaved Ice",
		Price = 6000,
		Cooling = 80,
		Boost = "SugarRush",
		BoostSeconds = 60,
		Icon = "🍧",
		Description = "Rainbow syrup! Dig 25% faster for 60s.",
		Look = { Style = "ShavedIce", Color = rgb(90, 180, 255) },
	},
	{
		Id = "watermelon_slice",
		Name = "Watermelon Slice",
		Price = 25000,
		Cooling = 100,
		Boost = "MelonPower",
		BoostSeconds = 45,
		Icon = "🍉",
		Description = "Fully cooled AND +50% sand for 45s.",
		Look = { Style = "Slice", Color = rgb(255, 80, 90) },
	},
	{
		Id = "giant_watermelon",
		Name = "Giant Watermelon",
		Price = 250000,
		Cooling = 100,
		Boost = "MelonPower",
		BoostSeconds = 150,
		Icon = "🍈",
		Description = "A whole melon! Fully cooled AND +50% sand for 2.5 min.",
		Look = { Style = "Melon", Color = rgb(70, 170, 80) },
	},
}

-- Sanity: boost ids must exist.
do
	local boostIds: { [string]: boolean } = {}
	for _, boost in Boosts do
		boostIds[boost.Id] = true
	end
	for _, def in Consumables do
		if def.Boost then
			assert(boostIds[def.Boost], "Consumables: unknown boost " .. def.Boost .. " on " .. def.Id)
		end
	end
end

return Consumables
