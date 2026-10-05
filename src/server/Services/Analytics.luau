--!strict
--[[
	Analytics — thin, safe wrappers around AnalyticsService.
	- Funnel(player, step): onboarding funnel (docs/ARCHITECTURE.md "Analytics"), logged at most
	  once per player ever. Completion flags persist in PlayerData.Settings["FTUE_<StepName>"]
	  (the client may read them, e.g. to skip tutorial steps; SetSetting can't write FTUE_ keys).
	- Economy(...): LogEconomyEvent for coin / token sources and sinks.
	Every call is pcall'd and runs in its own thread; analytics must never break gameplay.
]]

local AnalyticsService = game:GetService("AnalyticsService")

local DataService = require(script.Parent.DataService)

local Analytics = {}

Analytics.Steps = table.freeze({
	Joined = 1,
	FirstDig = 2,
	FirstSell = 3,
	FirstShovel = 4,
	FirstEgg = 5,
	FirstRebirth = 6,
})

local STEP_NAMES: { [number]: string } = {
	[1] = "Joined",
	[2] = "FirstDig",
	[3] = "FirstSell",
	[4] = "FirstShovel",
	[5] = "FirstEgg",
	[6] = "FirstRebirth",
}

local function safeCall(fn: () -> ())
	task.spawn(function()
		for attempt = 1, 2 do
			local ok, err = pcall(fn)
			if ok then
				return
			end
			if attempt == 2 then
				warn("[Analytics] " .. tostring(err))
			else
				task.wait(1)
			end
		end
	end)
end

function Analytics.Funnel(player: Player, step: number)
	local name = STEP_NAMES[step]
	local data = DataService.Get(player)
	if not name or not data then
		return
	end
	local flag = "FTUE_" .. name
	if data.Settings[flag] then
		return
	end
	data.Settings[flag] = true
	DataService.MarkDirty(player, "Settings")
	safeCall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
end

function Analytics.HasStep(player: Player, step: number): boolean
	local data = DataService.Get(player)
	local name = STEP_NAMES[step]
	return data ~= nil and name ~= nil and data.Settings["FTUE_" .. name] == true
end

-- currency: "Coins" | "Tokens". amount > 0. sku: what was bought / why it was earned.
function Analytics.Economy(
	player: Player,
	flow: Enum.AnalyticsEconomyFlowType,
	currency: string,
	amount: number,
	endingBalance: number,
	transaction: Enum.AnalyticsEconomyTransactionType,
	sku: string?
)
	if amount ~= amount or amount <= 0 or math.abs(amount) == math.huge then
		return
	end
	safeCall(function()
		AnalyticsService:LogEconomyEvent(
			player,
			flow,
			currency,
			math.floor(amount),
			math.floor(endingBalance),
			transaction.Name,
			sku
		)
	end)
end

function Analytics.Source(
	player: Player,
	currency: string,
	amount: number,
	endingBalance: number,
	transaction: Enum.AnalyticsEconomyTransactionType,
	sku: string?
)
	Analytics.Economy(player, Enum.AnalyticsEconomyFlowType.Source, currency, amount, endingBalance, transaction, sku)
end

function Analytics.Sink(
	player: Player,
	currency: string,
	amount: number,
	endingBalance: number,
	transaction: Enum.AnalyticsEconomyTransactionType,
	sku: string?
)
	Analytics.Economy(player, Enum.AnalyticsEconomyFlowType.Sink, currency, amount, endingBalance, transaction, sku)
end

return Analytics
