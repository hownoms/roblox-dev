--!strict
--[[
	OfflineService — digging pets keep digging while you are away (v2.2, docs/design/Rebirth.md).

	LastOnline: PlayerData.LastOnline is stamped with the server's os.time() every STAMP_SECONDS
	while the player is in the game and once more when they leave (OnPlayerRemoving runs before
	DataService's final save), so every save carries it. The client never sends a time.

	On join (DataService.PlayerLoaded), with away = os.time() - LastOnline:
	  - ignored when LastOnline is 0 (new save), away < OFFLINE_MIN_SECONDS (5 min), away < 0
	    (clock went backwards / another server's clock ahead), away > OFFLINE_MAX_GAP_SECONDS
	    (broken stamp), or LastOnline is older than FirstJoin,
	  - seconds = min(away, cap), cap = (OFFLINE_CAP_HOURS 2 + Long Nap hours) h,
	  - sand/s  = sum over the equipped digging pets (same slots and order rule as live digging) of
	              layer.SandValue x (sand multiplier / shovel factor x Dig.SandMultiplier) / Dig.Interval
	              — exactly DigService's pet-dig formula — where layer = the deepest layer the pet can
	              dig that the player has reached (MaxDepth). The sand multiplier is the permanent part
	              of the stack: no boosts, events or friends (they were not there while you slept),
	  - sand    = sand/s x efficiency (40% + Long Nap) x seconds,
	  - coins   = floor(sand x SELL_RATE x permanent coin factors (Golden Touch)).
	Coins go straight to the wallet (never the backpack). The client gets
	OfflineEarnings({ Seconds, Sand, Coins, CapSeconds, Capped, PetId }) for the welcome-back popup.
	No digging pets equipped -> one hint toast instead.

	Public API:
		OfflineService.Estimate(ctx, awaySeconds): Estimate     (pure; tests)
		OfflineService.TakeAway(player, now?): number?           (join: seconds away, stamps LastOnline)
		OfflineService.Pay(player, away): Estimate?              (grant coins + popup)
		OfflineService.Grant(player, now?): Estimate?            (TakeAway + Pay; tests)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Stats = require(Shared.Util.Stats)
local Types = require(Shared.Types)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local MultiplierService = require(script.Parent.MultiplierService)
local Net = require(script.Parent.Net)

local Perks = Config.RebirthPerks

local STAMP_SECONDS = 15
local PAY_DELAY = 3 -- pass ownership + client UI settle first

export type Estimate = {
	Seconds: number, -- counted (capped) offline seconds
	Away: number, -- real seconds away
	CapSeconds: number,
	Capped: boolean,
	SandPerSecond: number, -- live rate of the digging pets (before efficiency)
	Efficiency: number,
	Sand: number,
	Coins: number,
	PetId: string?, -- the best digging pet (popup picture)
}

local OfflineService = {}

-- Pure: what `awaySeconds` of offline digging is worth for this context.
function OfflineService.Estimate(ctx: Stats.Context, awaySeconds: number): Estimate
	local data = ctx.Data
	-- the permanent part of the multiplier stack only
	local calm: Stats.Context = {
		Data = table.clone(data),
		Passes = ctx.Passes,
		IsPremium = ctx.IsPremium,
		InGroup = ctx.InGroup,
		FriendsInServer = 0,
		ActiveEvents = {},
		Now = ctx.Now,
	}
	calm.Data.Boosts = {}
	local shovelFactor = Stats.GetShovel(calm.Data).SandMultiplier
	local sandMultiplier = Stats.GetSandMultiplier(calm)
	local reached = Config.GetLayerIndexAtDepth(data.MaxDepth)

	local rate = 0
	local bestId: string? = nil
	local bestRate = -1
	local ids, golden = Stats.GetEquippedPetIds(data, Stats.GetPetSlots(calm))
	for i, id in ids do
		local dig = Config.GetPetDig(id)
		if dig then
			local interval = Config.GetPetDigInterval(id, golden[i]) or dig.Interval
			local layerIndex = math.min(Config.GetMaxLayerIndexForPower(dig.Power), reached)
			local layer = Config.Layers[layerIndex]
			local perDig = layer.SandValue * sandMultiplier / shovelFactor * dig.SandMultiplier
			local perSecond = perDig / interval
			rate += perSecond
			if perSecond > bestRate then
				bestRate = perSecond
				bestId = id
			end
		end
	end

	local cap = Perks.OfflineCapSeconds(data.RebirthPerks)
	local away = math.max(0, awaySeconds)
	local seconds = math.min(away, cap)
	local efficiency = Perks.OfflineEfficiency(data.RebirthPerks)
	local sand = rate * efficiency * seconds
	local coins = math.floor(sand * Config.SELL_RATE * Stats.GetCoinMultiplier(calm))
	return {
		Seconds = seconds,
		Away = away,
		CapSeconds = cap,
		Capped = away > cap,
		SandPerSecond = rate,
		Efficiency = efficiency,
		Sand = math.floor(sand),
		Coins = coins,
		PetId = bestId,
	}
end

-- Is this LastOnline stamp usable at `now`? Returns the seconds away, or nil.
local function awayFrom(data: Types.PlayerData, now: number): number?
	local last = data.LastOnline
	if type(last) ~= "number" or last ~= last or last <= 0 then
		return nil
	end
	if type(data.FirstJoin) == "number" and last < data.FirstJoin - 60 then
		return nil -- stamped before the save existed: corrupt
	end
	local away = now - last
	if away < Perks.OFFLINE_MIN_SECONDS or away > Perks.OFFLINE_MAX_GAP_SECONDS then
		return nil -- too short, clock went backwards, or absurd
	end
	return away
end

-- Ends the absence: returns the usable seconds away (or nil) and stamps LastOnline = now.
function OfflineService.TakeAway(player: Player, now: number?): number?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	assert(data) -- refine for the type checker (guarded above)
	local t = now or os.time()
	local away = awayFrom(data, t)
	data.LastOnline = t
	return away
end

-- Pays `away` seconds of offline digging (coins) and tells the client. nil = nothing to pay.
function OfflineService.Pay(player: Player, away: number?): Estimate?
	local data = DataService.Get(player)
	local ctx = MultiplierService.GetContext(player)
	if not data or not ctx or not away or player.Parent == nil then
		return nil
	end
	assert(data) -- refine for the type checker (guarded above)
	assert(ctx) -- refine for the type checker (guarded above)
	local estimate = OfflineService.Estimate(ctx, away :: number)
	if estimate.Coins <= 0 then
		if estimate.SandPerSecond <= 0 then
			Net.Notify(player, "Info", "Equip a digging pet and it will earn coins while you're away!")
		end
		return estimate
	end
	DataService.Mutate(player, { "Coins" }, function(d)
		d.Coins += estimate.Coins
	end)
	Analytics.Source(
		player,
		"Coins",
		estimate.Coins,
		data.Coins,
		Enum.AnalyticsEconomyTransactionType.TimedReward,
		"Offline"
	)
	Net.FireClient("OfflineEarnings", player, {
		Seconds = estimate.Seconds,
		Away = estimate.Away,
		Sand = estimate.Sand,
		Coins = estimate.Coins,
		CapSeconds = estimate.CapSeconds,
		Capped = estimate.Capped,
		PetId = estimate.PetId,
	})
	return estimate
end

-- TakeAway + Pay in one go (tests / tools).
function OfflineService.Grant(player: Player, now: number?): Estimate?
	return OfflineService.Pay(player, OfflineService.TakeAway(player, now))
end

local function stamp(player: Player)
	local data = DataService.Get(player)
	if data then
		-- No MarkDirty: the client does not need it; every save copies the whole PlayerData.
		(data :: Types.PlayerData).LastOnline = os.time()
	end
end

function OfflineService.Init() end

function OfflineService.Start()
	DataService.PlayerLoaded:Connect(function(player: Player)
		-- stamp now (before the stamp loop can), pay a moment later: game passes are checked
		-- asynchronously after join and the client needs a moment to build its UI
		local away = OfflineService.TakeAway(player)
		if away then
			task.delay(PAY_DELAY, OfflineService.Pay, player, away)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(STAMP_SECONDS)
			for _, player in DataService.GetLoadedPlayers() do
				stamp(player)
			end
		end
	end)
	game:BindToClose(function()
		for _, player in DataService.GetLoadedPlayers() do
			stamp(player)
		end
	end)
end

-- Runs before DataService.OnPlayerRemoving (reverse service order), so the final save has it.
function OfflineService.OnPlayerRemoving(player: Player)
	stamp(player)
end

return OfflineService
