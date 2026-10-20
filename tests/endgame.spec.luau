--!nocheck
--[[
	Endgame (docs/SIX_MONTH_PLAN.md C1-C3): rebirth milestones, Rainbow pets, Index mastery.
	  luau tests/endgame.spec.luau
	Pure checks on Config.Endgame / Stats, then the real Main with the in-memory DataStore:
	  - C2 fusion: not enough copies, duplicate / repeated requests, equipped copies used last,
	    Rainbow can't fuse, Rainbow copies don't count as Golden, multiplier, attributes,
	    pause_fusing.
	  - C1 milestones: an old save at rebirth 15 gets r12 + r15 on join, exactly once (rejoin,
	    more rebirths), the skin at 16, the title at 17, the Wyrm at 18, SetShovelSkin validation,
	    pause_milestones holds grants
	    back until it is lifted.
	  - C3 mastery: recorded once, bonus applied once (re-trigger, rejoin), pause_index_rewards.
	MOCK COVERAGE ONLY: headless mock, in-memory DataStore, mock ConfigService.
]]

local Mock = require("./mock/Roblox")
Mock.Init(require("../build/test/generated"))
local passes, failures = 0, 0
local function check(cond, message)
	if cond then
		passes += 1
	else
		failures += 1
		print("FAIL: " .. message)
	end
	return cond
end

local byPath = Mock.ByPath
local function load(path)
	return Mock.Require(byPath[path])
end
local Config = load("ReplicatedStorage/Shared/Config")
for _, category in { Config.Monetization.GamePasses, Config.Monetization.Products, Config.Badges } do
	for _, item in category do
		item.Id = 0
	end
end
local Stats = load("ReplicatedStorage/Shared/Util/Stats")
local Models = load("ReplicatedStorage/Shared/Models")
local Endgame = Config.Endgame
local Enum = Mock.Env.Enum

-- Pure -----------------------------------------------------------------------------------------------
do
	check(Endgame.TitleFor(11) == nil, "no milestone title below 12 rebirths")
	check(Endgame.TitleFor(12) == "Reborn Veteran", "12: Reborn Veteran")
	check(Endgame.TitleFor(16) == "Reborn Veteran" and Endgame.TitleFor(17) == "Eternal Digger", "17: Eternal Digger")
	check(#Endgame.Reached(14) == 1 and #Endgame.Reached(18) == #Endgame.Milestones, "Reached")
	check(Endgame.NextMilestone(15).Rebirths == 16 and Endgame.NextMilestone(18) == nil, "NextMilestone")
	local rebirthsSeen = {}
	for _, m in Endgame.Milestones do
		rebirthsSeen[m.Rebirths] = m.Kind
	end
	check(
		rebirthsSeen[12] == "Title" and rebirthsSeen[15] == "Pet" and rebirthsSeen[16] == "Skin" and rebirthsSeen[17] == "Title" and rebirthsSeen[18] == "Pet",
		"milestones: 12 title, 15 pet, 16 skin, 17 title, 18 pet"
	)
	for _, m in Endgame.Milestones do
		if m.PetId then
			local pet = Config.GetPet(m.PetId)
			check(pet ~= nil and pet.Exclusive, "milestone pet is exclusive: " .. m.PetId)
			local inEgg = false
			for _, egg in Config.Eggs do
				for _, entry in egg.Pets do
					inEgg = inEgg or entry.PetId == m.PetId
				end
			end
			check(not inEgg, "milestone pet is in no egg: " .. m.PetId)
		end
	end

	-- Rainbow multiplier / dig speed
	local crab = Config.GetPet("sandy_crab")
	local bonus = crab.Multiplier - 1
	check(math.abs(Config.PetEffectiveMultiplier("sandy_crab", true, true) - (1 + bonus * Endgame.RAINBOW_SAND_BONUS)) < 1e-9, "Rainbow sand bonus x2.25")
	check(math.abs(Config.PetEffectiveMultiplier("sandy_crab", true) - (1 + bonus * Config.GOLDEN_SAND_BONUS)) < 1e-9, "Golden unchanged x1.5")
	check(Endgame.RAINBOW_SAND_BONUS > Config.GOLDEN_SAND_BONUS, "Rainbow is a tier above Golden")
	local dig = Config.GetPetDig("toy_truck")
	check(math.abs(Config.GetPetDigInterval("toy_truck", true, true) - dig.Interval / Endgame.RAINBOW_DIG_SPEED) < 1e-9, "Rainbow digger: interval / 1.5")
	local sorted = Stats.SortEquipped({
		a = { Id = "sandy_crab", Equipped = true, Golden = true, Rainbow = true },
		b = { Id = "sandy_crab", Equipped = true },
		c = { Id = "sandy_crab", Equipped = true, Golden = true },
	})
	check(Stats.PetTier(sorted[1]) == 0 and Stats.PetTier(sorted[2]) == 1 and Stats.PetTier(sorted[3]) == 2, "SortEquipped: normal, Golden, Rainbow")

	-- mastery
	local layer1 = Config.Layers[1]
	local variants = {}
	check(not Endgame.IsLayerMastered(1, variants), "empty: not mastered")
	for _, entry in layer1.LootTable do
		for _, v in Endgame.MASTERY_VARIANTS do
			variants[entry.TreasureId .. "/" .. v] = true
		end
	end
	local have, total = Endgame.MasteryProgress(1, variants)
	check(have == total and total == #layer1.LootTable * #Endgame.MASTERY_VARIANTS, "progress counts every variant")
	check(Endgame.IsLayerMastered(1, variants), "all variants: mastered")
	variants[layer1.LootTable[1].TreasureId .. "/Crystal"] = nil
	check(not Endgame.IsLayerMastered(1, variants), "one missing variant: not mastered")
	check(not Endgame.IsLayerMastered(2, variants) and not Endgame.IsLayerMastered(99, variants), "other / unknown layers")
	check(Endgame.CountMastered({ [layer1.Id] = true, junk = true, [Config.Layers[2].Id] = false }) == 1, "CountMastered ignores junk")
	check(Endgame.CountMastered(nil) == 0, "CountMastered(nil)")

	-- Seasonal (content calendar) finds never count toward mastery
	local seasonalIds = {}
	for _, t in Config.Treasures do
		if t.Seasonal == true then
			table.insert(seasonalIds, t.Id)
			check(Endgame.IsSeasonal(t.Id), "seasonal treasure left out of mastery: " .. t.Id)
		end
	end
	check(#seasonalIds > 0, "there are seasonal treasures to test with")
	for _, layer in Config.Layers do
		for _, entry in layer.LootTable do
			check(not Endgame.IsSeasonal(entry.TreasureId), "LootTable treasure counts for mastery: " .. entry.TreasureId)
		end
	end
	local fakeLayer = { Id = "seasonal_test", LootTable = table.clone(layer1.LootTable) }
	table.insert(fakeLayer.LootTable, { TreasureId = seasonalIds[1], Weight = 1 })
	local realLayer1 = Config.Layers[1]
	Config.Layers[1] = setmetatable(fakeLayer, { __index = realLayer1 })
	variants[layer1.LootTable[1].TreasureId .. "/Crystal"] = true
	local h2, t2 = Endgame.MasteryProgress(1, variants)
	check(Endgame.IsLayerMastered(1, variants), "seasonal entry in a LootTable does not block mastery")
	check(h2 == t2 and t2 == #layer1.LootTable * #Endgame.MASTERY_VARIANTS, "seasonal entry not in mastery total")
	Config.Layers[1] = realLayer1

	-- skin keeps the shovel's shape
	local shovel = Config.Shovels[5]
	local look = Endgame.ApplySkin(shovel.Look, "starforged")
	check(look.HeadShape == shovel.Look.HeadShape and look.HeadColor == Endgame.GetSkin("starforged").HeadColor, "skin recolours, keeps shape")
	check(Endgame.ApplySkin(shovel.Look, "nope") == shovel.Look and shovel.Look.HeadColor ~= look.HeadColor, "unknown skin: unchanged, def not mutated")
	local skinned = Models.Shovel(shovel.Id, "starforged")
	local neon = false
	for _, d in skinned:GetDescendants() do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			neon = true
		end
	end
	check(neon, "Models.Shovel(id, skin) builds the skinned look")

	-- defaults for new saves
	local fresh = Config.NewPlayerData()
	check(type(fresh.Milestones) == "table" and fresh.ShovelSkin == "" and type(fresh.IndexMastered) == "table", "new saves get the endgame fields")
end

-- Real Main ------------------------------------------------------------------------------------------
local mastered1 = {}
for _, entry in Config.Layers[1].LootTable do
	for _, v in Endgame.MASTERY_VARIANTS do
		mastered1[entry.TreasureId .. "/" .. v] = true
	end
end
-- a pre-endgame save (current version, no endgame keys) past rebirth 15 with layer 1 mastered
Mock.DataStores[Config.DATASTORE_NAME] = Mock.DataStores[Config.DATASTORE_NAME] or {}
Mock.DataStores[Config.DATASTORE_NAME]["Player_6001"] = {
	Data = {
		Version = Config.DATA_VERSION,
		Coins = 123,
		Rebirths = 15,
		Pets = {},
		PetSlots = 3,
		Index = {},
		FindVariants = table.clone(mastered1),
	},
	SavedAt = 0,
}
Mock.DataStores[Config.DATASTORE_NAME]["Player_6003"] = {
	Data = { Version = Config.DATA_VERSION, Rebirths = 13, Pets = {}, PetSlots = 3 },
	SavedAt = 0,
}

Mock.RunScript(byPath["ServerScriptService/Server/Main"])
Mock.Advance(1)
check(#Mock.Errors == 0, "boot: no errors")
local workspace = Mock.Service("Workspace")
for _ = 1, 40 do
	if workspace:GetAttribute("WorldReady") then
		break
	end
	Mock.Advance(0.5)
end
local Services = "ServerScriptService/Server/Services/"
local DataService = load(Services .. "DataService")
local PetService = load(Services .. "PetService")
local RebirthService = load(Services .. "RebirthService")
local DiscoveryService = load(Services .. "DiscoveryService")
local MultiplierService = load(Services .. "MultiplierService")

local function notifies(player, since, needle)
	local n = 0
	for i = (since or 0) + 1, #Mock.Remote.ToClient do
		local e = Mock.Remote.ToClient[i]
		if e.Player == player and e.Name == "Notify" and string.find(tostring(e.Args[2]), needle, 1, true) then
			n += 1
		end
	end
	return n
end
local function count(data, id, golden, rainbow)
	local n = 0
	for _, pet in data.Pets do
		if pet.Id == id and (pet.Golden == true) == (golden == true) and (pet.Rainbow == true) == (rainbow == true) then
			n += 1
		end
	end
	return n
end
local function factor(player, name)
	for _, f in Stats.GetSandFactors(MultiplierService.GetContext(player)) do
		if f.Name == name then
			return f.Value
		end
	end
	return nil
end

-- C2 Rainbow fusion -----------------------------------------------------------------------------------
do
	local p = Mock.AddPlayer(6002, "Fuser")
	Mock.Advance(2)
	local d = DataService.Get(p)
	check(d ~= nil, "fuser loaded")
	for uid in d.Pets do
		d.Pets[uid] = nil
	end
	local function golden(equipped)
		local uid = PetService.GrantPet(p, "sandy_crab", false)
		d.Pets[uid].Golden = true
		d.Pets[uid].Equipped = equipped == true
		return uid
	end
	local g = {}
	for i = 1, 4 do
		g[i] = golden(false)
	end
	PetService.GrantPet(p, "sandy_crab", false) -- a plain copy: doesn't count towards Rainbow
	DataService.MarkDirty(p, "Pets")
	Mock.Advance(0.3)
	local mark = #Mock.Remote.ToClient
	Mock.FireServer("FusePets", p, g[1])
	Mock.Advance(0.4)
	check(count(d, "sandy_crab", true, false) == 4 and count(d, "sandy_crab", true, true) == 0, "4 Golden (+1 plain): Rainbow refused")
	check(notifies(p, mark, "You need 5 Golden Sandy Crab") == 1, "not-enough message names Golden copies")

	-- 6 Golden copies: one equipped (not selected), the selected one unequipped
	g[5] = golden(false)
	local keeper = golden(true)
	DataService.MarkDirty(p, "Pets")
	Mock.Advance(0.3)
	mark = #Mock.Remote.ToClient
	Mock.FireServer("FusePets", p, g[2])
	Mock.FireServer("FusePets", p, g[2]) -- a duplicate request of the same uid
	Mock.Advance(0.5)
	check(count(d, "sandy_crab", true, true) == 1, "Fuse 5 Golden -> exactly 1 Rainbow (duplicate request ignored)")
	check(count(d, "sandy_crab", true, false) == 1 and d.Pets[keeper] ~= nil, "the equipped Golden copy is used last: kept")
	check(count(d, "sandy_crab", false, false) == 1, "plain copies untouched")
	check(notifies(p, mark, "into a RAINBOW Sandy Crab") == 1, "one success message")
	local rainbowUid
	for uid, pet in d.Pets do
		if pet.Rainbow then
			rainbowUid = uid
		end
	end
	check(rainbowUid and d.Pets[rainbowUid].Golden == true and d.Pets[rainbowUid].Equipped == false, "Rainbow keeps Golden = true; unequipped (no equipped copy fused)")

	-- equipped copies get consumed when needed; the result stays equipped
	for uid, pet in d.Pets do
		if uid ~= rainbowUid then
			d.Pets[uid] = nil
		end
	end
	local e = {}
	for i = 1, 5 do
		e[i] = golden(i <= 2)
	end
	DataService.MarkDirty(p, "Pets")
	Mock.Advance(1.1)
	Mock.FireServer("FusePets", p, e[5])
	Mock.Advance(0.5)
	check(count(d, "sandy_crab", true, true) == 2 and count(d, "sandy_crab", true, false) == 0, "5 Golden incl. 2 equipped -> Rainbow")
	local equippedRainbow = 0
	local equippedTotal = 0
	for _, pet in d.Pets do
		if pet.Equipped then
			equippedTotal += 1
			if pet.Rainbow then
				equippedRainbow += 1
			end
		end
	end
	check(equippedRainbow == 1 and equippedTotal == 1, "Rainbow stays equipped when a fused copy was (slots freed, never more equipped)")
	check(p:GetAttribute("EquippedPets") == "sandy_crab" and p:GetAttribute("EquippedRainbow") == "1" and p:GetAttribute("EquippedGolden") == "1", "EquippedRainbow attribute marks the slot")
	local crab = Config.GetPet("sandy_crab")
	local expected = 1 + (crab.Multiplier - 1) * Endgame.RAINBOW_SAND_BONUS
	check(math.abs(Stats.GetPetMultiplier(MultiplierService.GetContext(p)) - expected) < 1e-9, "server pet multiplier uses the Rainbow bonus")

	-- Rainbow can't fuse; Rainbow copies don't count as Golden
	mark = #Mock.Remote.ToClient
	Mock.FireServer("FusePets", p, rainbowUid)
	Mock.Advance(1.1)
	check(d.Pets[rainbowUid] ~= nil and count(d, "sandy_crab", true, true) == 2, "Rainbow pets can't be fused")
	check(notifies(p, mark, "Rainbow pets can't be fused again") == 1, "Rainbow refusal message")
	local lone = golden(false)
	for _ = 1, 3 do
		golden(false)
	end
	DataService.MarkDirty(p, "Pets")
	Mock.Advance(0.3)
	Mock.FireServer("FusePets", p, lone) -- 4 Golden + 2 Rainbow copies
	Mock.Advance(1.1)
	check(count(d, "sandy_crab", true, false) == 4 and count(d, "sandy_crab", true, true) == 2, "Rainbow copies don't count as Golden")

	-- junk
	Mock.FireServer("FusePets", p, "nope")
	Mock.FireServer("FusePets", p, 42)
	Mock.FireServer("FusePets", p, nil)
	Mock.Advance(1.1)
	check(#Mock.Errors == 0, "junk FusePets: no errors")

	-- pause_fusing (Golden and Rainbow)
	golden(false)
	local plain = {}
	for i = 1, 5 do
		plain[i] = PetService.GrantPet(p, "seagull", false)
	end
	DataService.MarkDirty(p, "Pets")
	Mock.SetConfig({ pause_fusing = true })
	Mock.Advance(1.5)
	mark = #Mock.Remote.ToClient
	Mock.FireServer("FusePets", p, lone)
	Mock.FireServer("FusePets", p, plain[1])
	Mock.Advance(1.1)
	check(count(d, "sandy_crab", true, false) == 5 and count(d, "seagull", false, false) == 5, "pause_fusing: nothing fused")
	check(notifies(p, mark, "Pet fusing is paused") == 2, "pause_fusing: message for both tiers")
	Mock.SetConfig({})
	Mock.Advance(1.5)
	Mock.FireServer("FusePets", p, lone)
	Mock.FireServer("FusePets", p, plain[1])
	Mock.Advance(1.1)
	check(count(d, "sandy_crab", true, true) == 3 and count(d, "seagull", true, false) == 1, "pause lifted: Rainbow + Golden fusion work again")
	Mock.RemovePlayer(p)
	Mock.Advance(2)
end

-- C1 milestones + C3 mastery on an old save ------------------------------------------------------------
do
	local p = Mock.AddPlayer(6001, "Veteran")
	Mock.Advance(2)
	local d = DataService.Get(p)
	check(d ~= nil and d.Coins == 123 and d.Rebirths == 15, "old save loads")
	check(d.Milestones.r12 == true and d.Milestones.r15 == true and d.Milestones.r16 == nil, "r12 + r15 granted on join")
	check(count(d, "reborn_phoenix") == 1, "Reborn Phoenix granted once")
	check(d.ShovelSkin == "", "no skin before rebirth 16")
	check(d.IndexMastered[Config.Layers[1].Id] == true and Endgame.CountMastered(d.IndexMastered) == 1, "layer 1 mastery recorded on join")
	check(math.abs((factor(p, "Mastery") or 0) - (1 + Endgame.INDEX_MASTER_BONUS)) < 1e-9, "Mastery sand factor +3%")
	local mult = p:GetAttribute("SandMultiplier")
	local mark = #Mock.Remote.ToClient
	-- re-trigger: no second record, no second toast, same multiplier
	DataService.MarkDirty(p, "FindVariants", "Rebirths")
	Mock.Advance(0.5)
	check(#DiscoveryService.CheckMastery(p) == 0 and #RebirthService.GrantMilestones(p) == 0, "nothing granted twice")
	check(notifies(p, mark, "MASTERED") == 0 and notifies(p, mark, "MILESTONE") == 0, "no repeated toasts")
	check(p:GetAttribute("SandMultiplier") == mult, "bonus applied once")

	-- rebirth 16: skin; 17: title; 18: Eternal Wyrm; no duplicates
	RebirthService.DoRebirth(p, true)
	Mock.Advance(0.5)
	check(d.Rebirths == 16 and d.Milestones.r16 == true and d.ShovelSkin == "starforged", "rebirth 16: skin granted and worn")
	check(d.Milestones.r17 == nil and count(d, "eternal_wyrm") == 0, "nothing past 16 yet")
	for _ = 1, 2 do
		RebirthService.DoRebirth(p, true)
		Mock.Advance(0.5)
	end
	check(d.Rebirths == 18 and d.Milestones.r17 == true and d.Milestones.r18 == true, "rebirth 17 + 18 granted")
	check(count(d, "eternal_wyrm") == 1, "rebirth 18: Eternal Wyrm granted once")
	check(count(d, "reborn_phoenix") == 1, "still one Reborn Phoenix after more rebirths")
	check(d.IndexMastered[Config.Layers[1].Id] == true and d.Milestones.r12 == true, "endgame fields survive rebirth")

	-- SetShovelSkin
	Mock.FireServer("SetShovelSkin", p, "")
	Mock.Advance(2.1)
	check(d.ShovelSkin == "", "skin off")
	Mock.FireServer("SetShovelSkin", p, "bogus")
	Mock.Advance(2.1)
	check(d.ShovelSkin == "", "unknown skin refused")
	Mock.FireServer("SetShovelSkin", p, 7)
	Mock.Advance(2.1)
	Mock.FireServer("SetShovelSkin", p, "starforged")
	Mock.Advance(2.1)
	check(d.ShovelSkin == "starforged", "unlocked skin back on")

	-- rejoin: everything once
	Mock.RemovePlayer(p)
	Mock.Advance(3)
	p = Mock.AddPlayer(6001, "Veteran")
	Mock.Advance(2)
	d = DataService.Get(p)
	check(d ~= nil and d.Rebirths == 18, "rejoin loads")
	check(count(d, "reborn_phoenix") == 1 and count(d, "eternal_wyrm") == 1 and d.ShovelSkin == "starforged", "rejoin: no duplicate pets, skin kept")
	check(Endgame.CountMastered(d.IndexMastered) == 1 and math.abs((factor(p, "Mastery") or 0) - 1.03) < 1e-9, "rejoin: mastery once")
	Mock.RemovePlayer(p)
	Mock.Advance(3)
end

-- a fresh player can't wear a skin
do
	local p = Mock.AddPlayer(6004, "Newbie")
	Mock.Advance(2)
	local d = DataService.Get(p)
	Mock.FireServer("SetShovelSkin", p, "starforged")
	Mock.Advance(2.1)
	check(d.ShovelSkin == "" and next(d.Milestones) == nil, "locked skin refused")
	check(factor(p, "Mastery") == nil, "no mastery factor without a mastered layer")
	Mock.RemovePlayer(p)
	Mock.Advance(2)
end

-- pauses: milestones and Index rewards held back, granted once lifted
do
	Mock.SetConfig({ pause_milestones = true, pause_index_rewards = true })
	Mock.Advance(1.5)
	local p = Mock.AddPlayer(6003, "Paused")
	Mock.Advance(2)
	local d = DataService.Get(p)
	check(d ~= nil and d.Rebirths == 13 and next(d.Milestones) == nil, "pause_milestones: nothing granted on join")
	for k, v in mastered1 do
		d.FindVariants[k] = v
	end
	DataService.MarkDirty(p, "FindVariants")
	Mock.Advance(0.5)
	check(next(d.IndexMastered) == nil and factor(p, "Mastery") == nil, "pause_index_rewards: mastery not recorded")
	Mock.SetConfig({})
	Mock.Advance(1.5)
	check(d.Milestones.r12 == true and d.Milestones.r15 == nil, "pause lifted: reached milestone granted")
	check(Endgame.CountMastered(d.IndexMastered) == 1, "pause lifted: mastery recorded")
	-- already-recorded bonuses stay while paused
	Mock.SetConfig({ pause_index_rewards = true })
	Mock.Advance(1.5)
	check(math.abs((factor(p, "Mastery") or 0) - 1.03) < 1e-9, "paused again: recorded bonus stays")
	Mock.SetConfig({})
	Mock.Advance(1.5)
	Mock.RemovePlayer(p)
	Mock.Advance(2)
end

check(#Mock.Errors == 0, "no uncaught errors")
for _, e in Mock.Errors do
	print("  error: " .. tostring(e))
end
print(string.format("ENDGAME: %d passed, %d failed", passes, failures))
if failures > 0 then
	error("ENDGAME SPEC FAILED")
end
