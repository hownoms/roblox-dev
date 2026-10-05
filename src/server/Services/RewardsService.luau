--!strict
--[[
	RewardsService — rewards, daily streak, quests, codes and social bonuses.

	Grant(player, reward, source, coinMultiplier?) applies a Types.Reward (coins via
	Config.ResolveCoins, tokens, boosts that stack duration, pets, free egg hatches, free
	rebirth). Used by daily rewards, quests, codes and developer products (wired by Main).

	Daily: claimable Config.DAILY_COOLDOWN_SECONDS after the last claim; the streak resets to 1
	if more than Config.DAILY_STREAK_GRACE_SECONDS passed. Premium x DailyRewardMultiplier coins.
	Quests: progress hooks from ServerSignals; Daily quests reset per UTC day (QuestProgress.Day).
	Codes: RedeemCode(code) — case-insensitive, Enabled / Expires checked, once per player.
	Group bonus: Player attribute "InGroup" (re-checked every GROUP_RECHECK seconds; GROUP_ID 0
	disables). Friends bonus: Player attribute "FriendsInServer".
	PlayTime: +60 every minute online (also drives PlayMinutes quests).

	Public API:
		RewardsService.Grant(player, reward, source, coinMultiplier?): boolean
		RewardsService.AddQuestProgress(player, kind, amount, rarity?)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local Format = require(Shared.Util.Format)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local Net = require(script.Parent.Net)
local PetService = require(script.Parent.PetService)
local RebirthService = require(script.Parent.RebirthService)
local ServerSignals = require(script.Parent.ServerSignals)

local GROUP_RECHECK = 300
local CODE_MAX_LENGTH = 32

local RewardsService = {}

local friendCache: { [Player]: { [number]: boolean } } = {}

local function today(): number
	return os.time() // 86400
end

local function transactionFor(source: string): Enum.AnalyticsEconomyTransactionType
	if string.sub(source, 1, 8) == "Product:" then
		return Enum.AnalyticsEconomyTransactionType.IAP
	elseif source == "Daily" then
		return Enum.AnalyticsEconomyTransactionType.TimedReward
	end
	return Enum.AnalyticsEconomyTransactionType.Gameplay
end

-- Grant -----------------------------------------------------------------------------------------

function RewardsService.Grant(player: Player, reward: Types.Reward, source: string, coinMultiplier: number?): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	assert(data) -- refine for the type checker (guarded above)
	local parts: { string } = {}

	local coins = math.floor(Config.ResolveCoins(reward, data.MaxDepth) * (coinMultiplier or 1))
	if coins > 0 then
		DataService.Increment(player, "Coins", coins)
		table.insert(parts, "+" .. Format.Abbreviate(coins) .. " Coins")
		Analytics.Source(player, "Coins", coins, data.Coins, transactionFor(source), source)
	end

	local tokens = reward.RebirthTokens or 0
	if tokens > 0 then
		DataService.Increment(player, "RebirthTokens", tokens)
		table.insert(parts, "+" .. tostring(tokens) .. " Rebirth Token" .. (if tokens == 1 then "" else "s"))
		Analytics.Source(player, "Tokens", tokens, data.RebirthTokens, transactionFor(source), source)
	end

	if reward.Boost then
		local def = Config.GetBoost(reward.Boost)
		local seconds = reward.BoostSeconds or 0
		if def and seconds > 0 then
			local now = os.time()
			data.Boosts[def.Id] = math.max(data.Boosts[def.Id] or 0, now) + seconds
			DataService.MarkDirty(player, "Boosts")
			table.insert(parts, def.Name .. " (" .. Format.Time(seconds) .. ")")
		end
	end

	if reward.Pet then
		local pet = Config.GetPet(reward.Pet)
		if pet and PetService.GrantPet(player, pet.Id) then
			table.insert(parts, pet.Name .. " pet")
		end
	end

	if reward.Egg then
		local hatched = PetService.HatchFree(player, reward.Egg, reward.EggCount or 1)
		if #hatched > 0 then
			table.insert(parts, tostring(#hatched) .. " egg" .. (if #hatched == 1 then "" else "s") .. " hatched")
		end
	end

	if reward.Rebirth then
		if not RebirthService.DoRebirth(player, true) then
			-- Only a concurrent rebirth can fail here; still report the grant failed.
			return false
		end
	end

	if #parts > 0 then
		Net.Notify(player, "Reward", table.concat(parts, ", ") .. "!")
	end
	return true
end

-- Daily -----------------------------------------------------------------------------------------

local function dailyReady(data: Types.PlayerData, now: number): boolean
	return now - data.LastDailyClaim >= Config.DAILY_COOLDOWN_SECONDS
end

local function onClaimDaily(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	assert(data) -- refine for the type checker (guarded above)
	local now = os.time()
	if not dailyReady(data, now) then
		Net.Notify(
			player,
			"Error",
			"Next reward in " .. Format.Time(Config.DAILY_COOLDOWN_SECONDS - (now - data.LastDailyClaim)) .. "!"
		)
		return
	end
	local streak = data.DailyStreak + 1
	if data.LastDailyClaim > 0 and now - data.LastDailyClaim > Config.DAILY_STREAK_GRACE_SECONDS then
		streak = 1
	end
	DataService.Mutate(player, { "DailyStreak", "LastDailyClaim" }, function(d)
		d.DailyStreak = streak
		d.LastDailyClaim = now
	end)
	local def = Config.GetDailyReward(streak)
	local multiplier = if MonetizationService.IsPremium(player)
		then Config.Monetization.Premium.DailyRewardMultiplier
		else 1
	RewardsService.Grant(player, def.Reward, "Daily", multiplier)
end

-- Quests ----------------------------------------------------------------------------------------

local function questState(data: Types.PlayerData, def: Types.QuestDef, day: number): Types.QuestProgress
	local existing = data.Quests[def.Id]
	local fresh = existing == nil or (def.Reset == "Daily" and existing.Day ~= day)
	if existing and not fresh then
		return existing
	end
	local state: Types.QuestProgress = {
		Progress = 0,
		Claimed = false,
		Day = if def.Reset == "Daily" then day else nil,
	}
	data.Quests[def.Id] = state
	return state
end

local function rarityOrder(rarity: string?): number
	local def = if rarity then Config.GetRarity(rarity) else nil
	return if def then def.Order else 0
end

-- kind: Types.QuestKind. For "ReachDepth" amount is the new MaxDepth (absolute, not added).
function RewardsService.AddQuestProgress(player: Player, kind: Types.QuestKind, amount: number, rarity: string?)
	local data = DataService.Get(player)
	if not data then
		return
	end
	assert(data) -- refine for the type checker (guarded above)
	local day = today()
	local changed = false
	for _, def in Config.Quests do
		if def.Kind == kind then
			if kind == "FindRarity" and rarityOrder(rarity) < rarityOrder(def.Rarity) then
				continue
			end
			local state = questState(data, def, day)
			if state.Claimed then
				continue
			end
			local before = state.Progress
			if kind == "ReachDepth" then
				state.Progress = math.max(state.Progress, amount)
			else
				state.Progress += amount
			end
			state.Progress = math.min(state.Progress, def.Target)
			if state.Progress ~= before then
				changed = true
				if before < def.Target and state.Progress >= def.Target then
					Net.Notify(player, "Info", "Quest complete: " .. def.Name .. "! Claim your reward.")
				end
			end
		end
	end
	if changed then
		DataService.MarkDirty(player, "Quests")
	end
end

local function onClaimQuest(player: Player, questId: any)
	if not Net.IsString(questId, 64) then
		return
	end
	local data = DataService.Get(player)
	local def = Config.GetQuest(questId)
	if not data or not def then
		return
	end
	assert(data) -- refine for the type checker (guarded above)
	assert(def) -- refine for the type checker (guarded above)
	local state = questState(data, def, today())
	if state.Claimed then
		Net.Notify(player, "Error", "Already claimed!")
		return
	end
	if state.Progress < def.Target then
		Net.Notify(player, "Error", "Not finished yet!")
		return
	end
	state.Claimed = true
	DataService.MarkDirty(player, "Quests")
	RewardsService.Grant(player, def.Reward, "Quest:" .. def.Id)
end

-- Codes -----------------------------------------------------------------------------------------

local function onRedeemCode(player: Player, code: any)
	if not Net.IsString(code, CODE_MAX_LENGTH) then
		return
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	assert(data) -- refine for the type checker (guarded above)
	local def = Config.GetCode(code)
	if not def or not def.Enabled or (def.Expires ~= nil and os.time() > def.Expires) then
		Net.Notify(player, "Error", "That code doesn't work.")
		return
	end
	assert(def) -- refine for the type checker (guarded above)
	if def.GroupOnly and player:GetAttribute("InGroup") ~= true then
		Net.Notify(player, "Error", "Join our Roblox group to use this code!")
		return
	end
	local key = string.upper(def.Code)
	if data.RedeemedCodes[key] then
		Net.Notify(player, "Error", "You already used that code!")
		return
	end
	data.RedeemedCodes[key] = true
	DataService.MarkDirty(player, "RedeemedCodes")
	RewardsService.Grant(player, def.Reward, "Code:" .. key)
end

-- Social ----------------------------------------------------------------------------------------

local function checkGroup(player: Player)
	if Config.GROUP_ID == 0 then
		player:SetAttribute("InGroup", false)
		return
	end
	local ok, inGroup = pcall(function()
		return player:IsInGroup(Config.GROUP_ID)
	end)
	if ok and player.Parent then
		player:SetAttribute("InGroup", inGroup == true)
	end
end

local function recountFriends(player: Player)
	local cache = friendCache[player]
	if not cache or player.Parent == nil then
		return
	end
	assert(cache) -- refine for the type checker (guarded above)
	local count = 0
	for _, other in Players:GetPlayers() do
		if other ~= player and cache[other.UserId] then
			count += 1
		end
	end
	player:SetAttribute("FriendsInServer", count)
end

local function onSocialJoin(player: Player)
	friendCache[player] = {}
	player:SetAttribute("FriendsInServer", 0)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local ok, isFriend = pcall(function()
				return player:IsFriendsWith(other.UserId)
			end)
			if ok and isFriend then
				local mine = friendCache[player]
				local theirs = friendCache[other]
				if mine then
					mine[other.UserId] = true
				end
				if theirs then
					theirs[player.UserId] = true
				end
				recountFriends(other)
				if other.Parent then
					Net.Notify(other, "Info", "Your friend " .. player.DisplayName .. " joined! Friend sand bonus up!")
				end
			end
		end
	end
	recountFriends(player)
end

-- Lifecycle -------------------------------------------------------------------------------------

function RewardsService.Init()
	Net.On("ClaimDailyReward", onClaimDaily, { Rate = 2, Window = 2 })
	Net.On("ClaimQuest", onClaimQuest, { Rate = 5, Window = 1 })
	Net.On("RedeemCode", onRedeemCode, { Rate = 3, Window = 5 })
end

function RewardsService.Start()
	ServerSignals.Dug:Connect(function(player: Player)
		RewardsService.AddQuestProgress(player, "DigTimes", 1)
	end)
	ServerSignals.Sold:Connect(function(player: Player)
		RewardsService.AddQuestProgress(player, "SellTimes", 1)
	end)
	ServerSignals.TreasureFound:Connect(function(player: Player, treasureId: string)
		RewardsService.AddQuestProgress(player, "FindTreasures", 1)
		local def = Config.GetTreasure(treasureId)
		RewardsService.AddQuestProgress(player, "FindRarity", 1, if def then def.Rarity else nil)
	end)
	ServerSignals.Hatched:Connect(function(player: Player, count: number)
		RewardsService.AddQuestProgress(player, "HatchEggs", count)
	end)
	ServerSignals.UpgradeBought:Connect(function(player: Player)
		RewardsService.AddQuestProgress(player, "BuyUpgrade", 1)
	end)
	ServerSignals.DepthReached:Connect(function(player: Player, maxDepth: number)
		RewardsService.AddQuestProgress(player, "ReachDepth", maxDepth)
	end)
	ServerSignals.Rebirthed:Connect(function(player: Player)
		RewardsService.AddQuestProgress(player, "Rebirth", 1)
	end)

	DataService.PlayerLoaded:Connect(function(player: Player, data: Types.PlayerData)
		-- Milestones already reached before (e.g. quests added in an update) catch up.
		RewardsService.AddQuestProgress(player, "ReachDepth", data.MaxDepth)
		if data.Rebirths > 0 then
			for _, def in Config.Quests do
				if def.Kind == "Rebirth" then
					local state = questState(data, def, today())
					if not state.Claimed and state.Progress < math.min(data.Rebirths, def.Target) then
						state.Progress = math.min(data.Rebirths, def.Target)
						DataService.MarkDirty(player, "Quests")
					end
				end
			end
		end
		if dailyReady(data, os.time()) then
			task.delay(5, function()
				if player.Parent then
					Net.Notify(player, "Info", "Your daily reward is ready!")
				end
			end)
		end
	end)

	-- Play time + PlayMinutes quests.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in DataService.GetLoadedPlayers() do
				DataService.Increment(player, "PlayTime", 60)
				RewardsService.AddQuestProgress(player, "PlayMinutes", 1)
			end
		end
	end)

	-- Group membership is "checked live".
	task.spawn(function()
		while true do
			task.wait(GROUP_RECHECK)
			for _, player in Players:GetPlayers() do
				task.spawn(checkGroup, player)
			end
		end
	end)
end

function RewardsService.OnPlayerAdded(player: Player)
	task.spawn(checkGroup, player)
	task.spawn(onSocialJoin, player)
end

function RewardsService.OnPlayerRemoving(player: Player)
	friendCache[player] = nil
	for other, cache in friendCache do
		if cache[player.UserId] then
			cache[player.UserId] = nil
			task.defer(recountFriends, other)
		end
	end
end

return RewardsService
