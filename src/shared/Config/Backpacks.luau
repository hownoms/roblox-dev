--!strict
--[[
	Backpacks — ordered by price. Capacity is sand carried before you must sell.
	Effective capacity = Capacity x Config.RebirthMultiplier(rebirths) x (Mega Backpack pass ? 2 : 1).
	Sized so a matched backpack fills in ~20-40 digs: long enough to feel productive, short enough
	that selling (the coin dopamine hit) happens every 30-60 seconds.
]]

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local Backpacks: { Types.BackpackDef } = {
	{
		Id = "bucket",
		Name = "Beach Bucket",
		Price = 0,
		Capacity = 20,
		RebirthsRequired = 0,
		Description = "A trusty plastic bucket. Holds a little sand.",
		Look = {
			Color = rgb(60, 170, 255),
			AccentColor = rgb(255, 230, 60),
			Shape = "Bucket",
			Material = Enum.Material.SmoothPlastic,
			Glow = false,
		},
	},
	{
		Id = "sand_pail",
		Name = "Sand Pail",
		Price = 50,
		Capacity = 60,
		RebirthsRequired = 0,
		Description = "Bigger bucket, bigger trips.",
		Look = {
			Color = rgb(255, 120, 60),
			AccentColor = rgb(255, 255, 255),
			Shape = "Bucket",
			Material = Enum.Material.SmoothPlastic,
			Glow = false,
		},
	},
	{
		Id = "beach_bag",
		Name = "Beach Bag",
		Price = 300,
		Capacity = 200,
		RebirthsRequired = 0,
		Description = "Towel, sunscreen... and LOTS of sand.",
		Look = {
			Color = rgb(255, 90, 160),
			AccentColor = rgb(255, 240, 120),
			Shape = "Bag",
			Material = Enum.Material.Fabric,
			Glow = false,
		},
	},
	{
		Id = "cooler",
		Name = "Cooler",
		Price = 1500,
		Capacity = 700,
		RebirthsRequired = 0,
		Description = "Keeps your sand nice and cool.",
		Look = {
			Color = rgb(40, 200, 230),
			AccentColor = rgb(255, 255, 255),
			Shape = "Box",
			Material = Enum.Material.SmoothPlastic,
			Glow = false,
		},
	},
	{
		Id = "treasure_sack",
		Name = "Treasure Sack",
		Price = 7000,
		Capacity = 2500,
		RebirthsRequired = 0,
		Description = "A pirate's loot bag, patched with gold thread.",
		Look = {
			Color = rgb(170, 120, 70),
			AccentColor = rgb(255, 210, 60),
			Shape = "Bag",
			Material = Enum.Material.Fabric,
			Glow = false,
		},
	},
	{
		Id = "barrel",
		Name = "Pirate Barrel",
		Price = 30000,
		Capacity = 9000,
		RebirthsRequired = 0,
		Description = "Rum not included. Sand very included.",
		Look = {
			Color = rgb(140, 90, 50),
			AccentColor = rgb(80, 80, 90),
			Shape = "Barrel",
			Material = Enum.Material.Wood,
			Glow = false,
		},
	},
	{
		Id = "mine_cart",
		Name = "Mine Cart",
		Price = 130000,
		Capacity = 30000,
		RebirthsRequired = 0,
		Description = "Rolls on tiny rails strapped to your back.",
		Look = {
			Color = rgb(110, 110, 125),
			AccentColor = rgb(200, 60, 50),
			Shape = "Cart",
			Material = Enum.Material.Metal,
			Glow = false,
		},
	},
	{
		Id = "wheelbarrow",
		Name = "Wheelbarrow",
		Price = 600000,
		Capacity = 100000,
		RebirthsRequired = 0,
		Description = "Somehow fits on your back. Don't ask.",
		Look = {
			Color = rgb(60, 180, 90),
			AccentColor = rgb(60, 60, 60),
			Shape = "Cart",
			Material = Enum.Material.Metal,
			Glow = false,
		},
	},
	{
		Id = "dump_truck",
		Name = "Dump Truck",
		Price = 3000000,
		Capacity = 400000,
		RebirthsRequired = 0,
		Description = "A whole toy dump truck... that isn't a toy.",
		Look = {
			Color = rgb(255, 200, 30),
			AccentColor = rgb(50, 50, 60),
			Shape = "Vehicle",
			Material = Enum.Material.SmoothPlastic,
			Glow = false,
		},
	},
	{
		Id = "sand_truck",
		Name = "Sand Truck",
		Price = 18000000,
		Capacity = 1600000,
		RebirthsRequired = 1,
		Description = "The biggest truck on the beach. Requires 1 Rebirth.",
		Look = {
			Color = rgb(255, 130, 30),
			AccentColor = rgb(240, 240, 240),
			Shape = "Vehicle",
			Material = Enum.Material.Metal,
			Glow = false,
		},
	},
	{
		Id = "cargo_ship",
		Name = "Cargo Ship",
		Price = 120000000,
		Capacity = 8000000,
		RebirthsRequired = 3,
		Description = "Carry a shipyard of sand. Requires 3 Rebirths.",
		Look = {
			Color = rgb(40, 90, 200),
			AccentColor = rgb(230, 60, 60),
			Shape = "Vehicle",
			Material = Enum.Material.Metal,
			Glow = true,
		},
	},
	{
		Id = "black_hole_bag",
		Name = "Black Hole Bag",
		Price = 900000000,
		Capacity = 50000000,
		RebirthsRequired = 6,
		Description = "Bigger on the inside. Requires 6 Rebirths.",
		Look = {
			Color = rgb(80, 20, 140),
			AccentColor = rgb(255, 120, 255),
			Shape = "Orb",
			Material = Enum.Material.Neon,
			Glow = true,
		},
	},
	{
		Id = "pocket_dimension",
		Name = "Pocket Dimension",
		Price = 6000000000,
		Capacity = 400000000,
		RebirthsRequired = 9,
		Description = "An entire beach folded into a marble. Requires 9 Rebirths.",
		Look = {
			Color = rgb(255, 215, 90),
			AccentColor = rgb(120, 255, 255),
			Shape = "Orb",
			Material = Enum.Material.Neon,
			Glow = true,
		},
	},
}

return Backpacks
