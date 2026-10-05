--!strict
--[[
	Diggers — companion vehicles that follow the player and auto-dig next to them (v2).
	Ordered by price. Bought / upgraded in the Garage, independent of pets (pets keep the sand
	multipliers). Balance sheet: docs/design/Diggers.md.

	- Power matches the best shovel a player can afford at the same price point, so a new digger
	  can keep up in the layer the player is digging when they buy it.
	- Interval = seconds between digs, SandMultiplier replaces the shovel factor in the sand stack
	  for the digger's digs (all other multipliers still apply), Radius uses the shovel scale.
	- Level 1 digs at ~15% of the equivalent shovel's active sand/second; max level (5) doubles that
	  (~30%). Several slots stack, but one digger never beats active digging.
	- Level scaling and slot rules live in Config (GetDiggerStats / GetDiggerSlots).
	- UpgradeCosts[L] = coins from level L to L + 1 (0.4x, 0.7x, 1.2x, 2x the price).
	- Diggers are KEPT on rebirth (like pets); late ones need rebirths to buy.

	Look.Kind selects the model builder in Models/Diggers.luau.
]]

local Types = require(script.Parent.Parent.Types)

local rgb = Color3.fromRGB

local MAX_LEVEL = 5
local UPGRADE_FACTORS = { 0.4, 0.7, 1.2, 2.0 }

local function roundSig(x: number, digits: number): number
	if x <= 0 then
		return 0
	end
	local magnitude = 10 ^ (math.floor(math.log10(x)) - digits + 1)
	return math.floor(x / magnitude + 0.5) * magnitude
end

type Spec = {
	Id: string,
	Name: string,
	Price: number,
	RebirthsRequired: number?,
	Power: number,
	Interval: number,
	Radius: number,
	SandMultiplier: number,
	Description: string,
	Look: { [string]: any },
}

local function digger(spec: Spec): Types.DiggerDef
	local costs = {}
	for i, factor in UPGRADE_FACTORS do
		costs[i] = roundSig(spec.Price * factor, 2)
	end
	return {
		Id = spec.Id,
		Name = spec.Name,
		Price = spec.Price,
		RebirthsRequired = spec.RebirthsRequired or 0,
		Power = spec.Power,
		Interval = spec.Interval,
		Radius = spec.Radius,
		SandMultiplier = spec.SandMultiplier,
		MaxLevel = MAX_LEVEL,
		UpgradeCosts = costs,
		Description = spec.Description,
		Look = spec.Look,
	}
end

local Diggers: { Types.DiggerDef } = {
	digger({
		Id = "toy_truck",
		Name = "Toy Sand Truck",
		Price = 800,
		Power = 15,
		Interval = 3,
		Radius = 2.4,
		SandMultiplier = 3,
		Description = "A plastic truck that really works! Digs down to Pirate Cove.",
		Look = { Kind = "ToyTruck", Body = rgb(255, 210, 50), Accent = rgb(240, 70, 70), Glow = false },
	}),
	digger({
		Id = "dump_truck",
		Name = "Little Dump Truck",
		Price = 4000,
		Power = 25,
		Interval = 2.8,
		Radius = 2.6,
		SandMultiplier = 4.5,
		Description = "Tips its bed and scoops sand all day. Reaches the Shipwreck.",
		Look = { Kind = "DumpTruck", Body = rgb(255, 150, 40), Accent = rgb(70, 80, 95), Glow = false },
	}),
	digger({
		Id = "mini_excavator",
		Name = "Mini Excavator",
		Price = 15000,
		Power = 45,
		Interval = 2.6,
		Radius = 2.8,
		SandMultiplier = 7,
		Description = "A tiny arm with a big bucket. Digs up Fossil Bed bones.",
		Look = { Kind = "Excavator", Body = rgb(255, 200, 30), Accent = rgb(55, 55, 65), Glow = false },
	}),
	digger({
		Id = "skid_steer",
		Name = "Skid Steer",
		Price = 50000,
		Power = 80,
		Interval = 2.4,
		Radius = 3,
		SandMultiplier = 9.5,
		Description = "Spins on the spot and shovels fast. Strong enough for Bedrock.",
		Look = { Kind = "SkidSteer", Body = rgb(80, 200, 90), Accent = rgb(45, 50, 60), Glow = false },
	}),
	digger({
		Id = "bulldozer",
		Name = "Bulldozer",
		Price = 200000,
		Power = 140,
		Interval = 2.3,
		Radius = 3.2,
		SandMultiplier = 14,
		Description = "Pushes through anything with its giant blade. Opens Crystal Caverns.",
		Look = { Kind = "Bulldozer", Body = rgb(255, 185, 20), Accent = rgb(60, 60, 70), Glow = false },
	}),
	digger({
		Id = "backhoe",
		Name = "Backhoe Loader",
		Price = 800000,
		Power = 250,
		Interval = 2.2,
		Radius = 3.4,
		SandMultiplier = 20,
		Description = "Loader in front, digger arm in back. Chips the Frozen Abyss.",
		Look = { Kind = "Backhoe", Body = rgb(90, 170, 255), Accent = rgb(40, 60, 110), Glow = false },
	}),
	digger({
		Id = "drill_rig",
		Name = "Drill Rig",
		Price = 3500000,
		RebirthsRequired = 1,
		Power = 450,
		Interval = 2,
		Radius = 3.6,
		SandMultiplier = 27,
		Description = "A tall spinning drill tower. Finds the Ancient Ruins. Requires 1 Rebirth.",
		Look = { Kind = "DrillRig", Body = rgb(230, 60, 60), Accent = rgb(200, 205, 215), Glow = false },
	}),
	digger({
		Id = "mining_drill",
		Name = "Mining Cart Drill",
		Price = 15000000,
		RebirthsRequired = 2,
		Power = 800,
		Interval = 1.9,
		Radius = 3.8,
		SandMultiplier = 40,
		Description = "A mine cart with a drill nose. Rolls into the Magma Chamber. Requires 2 Rebirths.",
		Look = { Kind = "MiningDrill", Body = rgb(150, 100, 60), Accent = rgb(255, 120, 30), Glow = false },
	}),
	digger({
		Id = "tunnel_borer",
		Name = "Tunnel Borer",
		Price = 80000000,
		RebirthsRequired = 4,
		Power = 1400,
		Interval = 1.8,
		Radius = 4,
		SandMultiplier = 60,
		Description = "A giant round cutter face. Bores through Obsidian. Requires 4 Rebirths.",
		Look = { Kind = "TunnelBorer", Body = rgb(120, 70, 200), Accent = rgb(60, 40, 90), Glow = true },
	}),
	digger({
		Id = "mole_machine",
		Name = "Mole Machine",
		Price = 450000000,
		RebirthsRequired = 6,
		Power = 2500,
		Interval = 1.7,
		Radius = 4.3,
		SandMultiplier = 95,
		Description = "A robot mole with twin drill claws. Burrows into the Alien Hive. Requires 6 Rebirths.",
		Look = { Kind = "Mole", Body = rgb(140, 110, 95), Accent = rgb(90, 255, 140), Glow = true },
	}),
	digger({
		Id = "lava_drill",
		Name = "Lava Drill",
		Price = 1500000000,
		RebirthsRequired = 8,
		Power = 2500,
		Interval = 1.6,
		Radius = 4.6,
		SandMultiplier = 120,
		Description = "Glowing hot drill that melts rock into sand. Requires 8 Rebirths.",
		Look = { Kind = "LavaDrill", Body = rgb(50, 35, 35), Accent = rgb(255, 100, 20), Glow = true },
	}),
	digger({
		Id = "core_driller",
		Name = "Core Driller",
		Price = 3500000000,
		RebirthsRequired = 10,
		Power = 4500,
		Interval = 1.5,
		Radius = 5,
		SandMultiplier = 140,
		Description = "The golden machine built to reach the Core. Requires 10 Rebirths.",
		Look = { Kind = "CoreDriller", Body = rgb(255, 210, 60), Accent = rgb(255, 120, 40), Glow = true },
	}),
}

return Diggers
