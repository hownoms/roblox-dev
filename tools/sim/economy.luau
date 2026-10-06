--!nocheck
--[[
	Economy simulation: time to first new layer, first purchases and the first rebirths.
	Reads the REAL Config (src/shared/Config) through the headless Roblox mock, so it always
	simulates the numbers in the repo. Run from the repo root:

		python3 tests/tools/bundle.py && luau tools/sim/economy.luau
		luau tools/sim/economy.luau -a verbose     (also print every purchase)

	Player model (same assumptions as docs/GDD.md §4 "Economy sanity check"):
	  - digs non-stop at the shovel cooldown, half of the digs go downward (depth progress =
	    dig edge x 0.5), sand per dig comes from the layer at the current depth,
	  - a full backpack costs a sell trip of SELL_TRIP seconds (SELL_TRIP_ANYWHERE with Sell
	    Anywhere), treasures add +25% income,
	  - "cheapest useful upgrade first": next shovel / next backpack / 3 hatches of each newly
	    unlocked coin egg, skipping upgrades that cost more than SAVE_FOR_REBIRTH x the rebirth
	    cost (a player saving up for the rebirth),
	  - pets: equip the best `slots` by expected multiplier (weighted egg average),
	  - real time = simulated time / EFFICIENCY (walking, menus, chatting).
	Scenarios: "before" = old rebirth curve (4M x 3.3^n, 1 + n/3 tokens, no perks);
	"after" = current Config.Rebirths + a typical perk plan.
]]

local Mock = require("../../tests/mock/Roblox")
local Generated = require("../../build/test/generated")
Mock.Init(Generated)
local VERBOSE = table.find({ ... }, "verbose") ~= nil

local Config = Mock.Require(Mock.ByPath["ReplicatedStorage/Shared/Config"])
local Perks = Config.RebirthPerks

local SELL_TRIP = 14
local SELL_TRIP_ANYWHERE = 3
local TREASURE_BONUS = 1.25
local EFFICIENCY = 0.6
local SAVE_FOR_REBIRTH = 0.5
local DOWN_SHARE = 0.5
local MAX_REBIRTHS = 5
-- This model is stricter than the spreadsheet behind docs/GDD.md (it digs dig-by-dig and pays the
-- sell trip every backpack): the old config's first rebirth is 73 min here vs 56 min in the GDD.
-- "GDD min" columns rescale by GDD_SCALE so numbers can be compared with the GDD's targets.
local GDD_SCALE = 56 / 73.1

local function digEdge(radius)
	if radius <= 2.2 then
		return 2.5 -- DigService dent (ball)
	end
	return math.max(1, math.floor(radius * 2 / 4 + 0.5)) * 4
end

local function expectedEggMult(egg)
	local total, weighted = 0, 0
	for _, e in egg.Pets do
		local pet = Config.GetPet(e.PetId)
		total += e.Weight
		weighted += e.Weight * pet.Multiplier
	end
	return weighted / total
end

local function fmt(n)
	if n >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(math.floor(n))
end

-- One full run. scenario = { Cost(n), Tokens(n), PerkPlan = { perkId, ... } (bought in order when affordable) }
local function run(scenario)
	local s = {
		t = 0,
		coins = 0,
		shovel = 1,
		backpack = 1,
		depth = 0,
		maxDepth = 0,
		rebirths = 0,
		tokens = 0,
		perks = {},
		pets = {}, -- multipliers
		hatched = {}, -- egg id -> count
		sand = 0,
		planIndex = 1,
	}
	local log = {}
	local events = { layer = {}, rebirth = {} }
	local function note(text)
		table.insert(log, string.format("%6.1f min  %s", s.t / EFFICIENCY / 60, text))
	end
	local function petMult()
		table.sort(s.pets, function(a, b)
			return a > b
		end)
		local slots = Config.MAX_EQUIPPED_PETS + Perks.ExtraPetSlots(s.perks)
		local total = 1
		for i = 1, math.min(slots, #s.pets) do
			total += s.pets[i] - 1
		end
		return total
	end
	local function capacity()
		return math.floor(
			Config.Backpacks[s.backpack].Capacity * Config.RebirthMultiplier(s.rebirths) * Perks.CapacityFactor(s.perks)
		)
	end
	local function maxDepthForShovel()
		local idx = Config.GetMaxLayerIndexForPower(Config.Shovels[s.shovel].Power)
		return Config.Layers[idx].DepthEnd - 0.01
	end
	local function candidates()
		local list = {}
		local cost = scenario.Cost(s.rebirths)
		local limit = cost * SAVE_FOR_REBIRTH
		local nextShovel = Config.Shovels[s.shovel + 1]
		if nextShovel and nextShovel.RebirthsRequired <= s.rebirths and nextShovel.Price <= limit then
			table.insert(list, { Kind = "shovel", Price = nextShovel.Price, Name = nextShovel.Name })
		end
		local nextPack = Config.Backpacks[s.backpack + 1]
		if nextPack and nextPack.RebirthsRequired <= s.rebirths and nextPack.Price <= limit then
			table.insert(list, { Kind = "backpack", Price = nextPack.Price, Name = nextPack.Name })
		end
		for _, egg in Config.Eggs do
			if
				egg.Currency == "Coins"
				and egg.Kind ~= "Crate"
				and Config.IsEggUnlocked(egg.Id, s.maxDepth)
				and (s.hatched[egg.Id] or 0) < 3
				and egg.Price <= limit
			then
				table.insert(list, { Kind = "egg", Price = egg.Price, Name = egg.Name, Egg = egg })
			end
		end
		table.sort(list, function(a, b)
			return a.Price < b.Price
		end)
		return list
	end
	local function shop()
		while true do
			local best = candidates()[1]
			if not best or s.coins < best.Price then
				return
			end
			s.coins -= best.Price
			if best.Kind == "shovel" then
				s.shovel += 1
			elseif best.Kind == "backpack" then
				s.backpack += 1
			else
				s.hatched[best.Egg.Id] = (s.hatched[best.Egg.Id] or 0) + 1
				table.insert(s.pets, expectedEggMult(best.Egg))
			end
			if VERBOSE then
				note("buy " .. best.Name .. " (" .. fmt(best.Price) .. ")")
			end
		end
	end
	local function buyPerks()
		local plan = scenario.PerkPlan or {}
		while s.planIndex <= #plan do
			local id = plan[s.planIndex]
			local cost = Perks.NextCost(s.perks, id)
			if cost and s.tokens < cost then
				return -- save up for the next perk in the plan
			end
			if cost then
				s.tokens -= cost
				s.perks[id] = Perks.Level(s.perks, id) + 1
				note(string.format("perk %s -> L%d (%d tokens)", id, s.perks[id], cost))
			end
			s.planIndex += 1
		end
	end
	local function rebirth()
		local cost = scenario.Cost(s.rebirths)
		s.coins -= cost
		s.tokens += scenario.Tokens(s.rebirths)
		s.rebirths += 1
		table.insert(events.rebirth, s.t / EFFICIENCY / 60)
		note(string.format("REBIRTH %d (cost %s)", s.rebirths, fmt(cost)))
		s.coins = 0
		s.sand = 0
		s.depth = 0
		buyPerks()
		local head = Perks.Effect(s.perks, "HeadStart")
		s.shovel = head.ShovelIndex or 1
		s.coins = head.Coins or 0
		local keep = Perks.Effect(s.perks, "KeepBackpack").KeepIndex or 0
		s.backpack = math.max(1, math.min(s.backpack, keep))
	end

	local guard = 0
	while s.rebirths < MAX_REBIRTHS and s.t < 30 * 3600 do
		guard += 1
		-- fill the backpack, dig by dig
		local shovel = Config.Shovels[s.shovel]
		local cap = capacity()
		local mult = shovel.SandMultiplier * Config.RebirthMultiplier(s.rebirths) * petMult()
		local edge = digEdge(shovel.Radius)
		local bottom = maxDepthForShovel()
		while s.sand < cap do
			s.depth = math.min(s.depth + edge * DOWN_SHARE, bottom)
			if s.depth > s.maxDepth then
				local before = Config.GetLayerIndexAtDepth(s.maxDepth)
				s.maxDepth = s.depth
				local after = Config.GetLayerIndexAtDepth(s.maxDepth)
				if after > before and s.rebirths == 0 then
					events.layer[after] = s.t / EFFICIENCY / 60
					if VERBOSE then
						note("reached layer " .. after .. " " .. Config.Layers[after].Name)
					end
				end
			end
			local layer = Config.GetLayerAtDepth(s.depth)
			s.sand = math.min(cap, s.sand + layer.SandValue * mult)
			s.t += shovel.Cooldown
		end
		s.t += if scenario.SellAnywherePass or Perks.HasSellAnywhere(s.perks) then SELL_TRIP_ANYWHERE else SELL_TRIP
		s.coins += s.sand * TREASURE_BONUS * Perks.CoinFactor(s.perks)
		s.sand = 0
		if s.coins >= scenario.Cost(s.rebirths) then
			rebirth()
		end
		shop()
		if guard > 2e6 then
			break
		end
	end
	return events, log, s
end

local scenarios = {
	{
		Name = "before (4M x 3.3^n, tokens 1 + n/3, no perks)",
		Cost = function(n)
			return 4_000_000 * 3.3 ^ n
		end,
		Tokens = function(n)
			return 1 + math.floor(n / 3)
		end,
	},
	{
		Name = "before, with the Sell Anywhere game pass (reference)",
		SellAnywherePass = true,
		Cost = function(n)
			return 4_000_000 * 3.3 ^ n
		end,
		Tokens = function(n)
			return 1 + math.floor(n / 3)
		end,
	},
	{
		Name = "after, no perks bought",
		Cost = Config.RebirthCost,
		Tokens = Config.RebirthTokens,
	},
	{
		Name = "after, typical perk plan",
		Cost = Config.RebirthCost,
		Tokens = Config.RebirthTokens,
		-- R1: Head Start + Golden Touch, R2: Sell Anywhere, R3: Keep Backpack + Deep Pockets x2 ...
		PerkPlan = {
			"HeadStart",
			"GoldenTouch",
			"SellAnywhere",
			"KeepBackpack",
			"DeepPockets",
			"DeepPockets",
			"HeadStart",
			"GoldenTouch",
			"KeepBackpack",
			"HeadStart",
		},
	},
}

for i, scenario in scenarios do
	local events, log = run(scenario)
	print(string.rep("=", 78))
	print(scenario.Name)
	if i == 1 or i == 3 or VERBOSE then
		print(
			string.format(
				"  first new layer: Wet Sand %.1f min, Shell Bed %.1f min (first one a purchase unlocks), Pirate Cove %.1f min",
				events.layer[2] or -1,
				events.layer[3] or -1,
				events.layer[5] or -1
			)
		)
	end
	local prev = 0
	for n, minutes in events.rebirth do
		print(
			string.format(
				"  Rebirth %d: cost %-7s at %6.1f min (+%5.1f)   GDD scale: %6.1f min (+%5.1f)",
				n,
				fmt(scenario.Cost(n - 1)),
				minutes,
				minutes - prev,
				minutes * GDD_SCALE,
				(minutes - prev) * GDD_SCALE
			)
		)
		prev = minutes
	end
	if VERBOSE then
		for _, line in log do
			print("   " .. line)
		end
	else
		for _, line in log do
			if string.find(line, "perk") then
				print("   " .. line)
			end
		end
	end
end
