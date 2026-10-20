--!strict
--[[
	LiveConfig — owner switches read from Roblox Experience configs (ConfigService), so they can
	be changed in the Creator Hub (Configs) without republishing. Live servers pick a change up
	within about a minute. Owner guide: docs/LIVE_CONFIG.md.

	Every value is validated. A missing, malformed or out-of-range value falls back to its default,
	and the defaults are the game exactly as published. If ConfigService fails, everything stays at
	the defaults. Ignored values are warned once per change ("[LiveConfig] ignored <key>: ...").

	Keys (all optional):
		codes_on            string   comma list of shipped codes to turn ON  (e.g. "1KLIKES")
		codes_off           string   comma list of shipped codes to turn OFF (e.g. "RELEASE")
		extra_codes         JSON     { "CODE": { "reward": <menu id>, "expires": "YYYY-MM-DD[ HH:MM]" } }
		                             reward menu: LiveConfig.REWARD_MENU; max MAX_EXTRA_CODES codes;
		                             a shipped code with the same name always wins
		events_off          string   comma list of event ids that never run (e.g. "HighTide")
		bonus_event         string   an event id to run on every server until bonus_event_ends
		bonus_event_ends    string   "YYYY-MM-DD HH:MM" (UTC), at most MAX_BONUS_DAYS ahead
		pause_hatching      boolean  egg hatching (the HatchEgg remote) refuses with a message
		pause_autodig       boolean  the AutoDig pass stops digging
		pause_leaderboards  boolean  no leaderboard DataStore reads or writes
		pause_fusing        boolean  pet fusion (Golden and Rainbow, the FusePets remote) refuses
		pause_milestones    boolean  rebirth milestone rewards are not granted (granted on a later
		                             join / rebirth once the pause is lifted)
		pause_index_rewards boolean  no NEW Index mastery is recorded (recorded bonuses stay)
		announcement        string   banner text shown to everyone (max MAX_ANNOUNCEMENT chars)

	API:
		LiveConfig.Init()                     load (waits up to INIT_TIMEOUT s; defaults on failure)
		LiveConfig.Get(): Snapshot            the validated values
		LiveConfig.Changed: Signal<Snapshot>  after every applied change
		LiveConfig.Parse(read, now)           pure: (key -> raw value) -> (Snapshot, warnings)
		LiveConfig.FindCode(code, now?)       a redeemable CodeDef (shipped + overrides + extras) or nil
		LiveConfig.IsPaused(feature)          "Hatching" | "AutoDig" | "Leaderboards" | "Fusing"
		                                      | "Milestones" | "IndexRewards"
		LiveConfig.ParseUtc(text)             "YYYY-MM-DD" (end of day) / "YYYY-MM-DD HH:MM" -> unix
		LiveConfig.OnPlayerAdded(player)      shows the announcement ANNOUNCE_DELAY s after joining

	The announcement goes out to everyone when its text changes, and to each player who joins.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)

local Net = require(script.Parent.Net)

export type Feature = "Hatching" | "AutoDig" | "Leaderboards" | "Fusing" | "Milestones" | "IndexRewards"

export type Snapshot = {
	CodesOn: { [string]: boolean },
	CodesOff: { [string]: boolean },
	ExtraCodes: { [string]: Types.CodeDef },
	EventsOff: { [string]: boolean },
	BonusEvent: string?,
	BonusEventEnds: number?,
	Paused: { [string]: boolean },
	Announcement: string?,
}

local LiveConfig = {}

LiveConfig.MAX_EXTRA_CODES = 20
LiveConfig.MAX_BONUS_DAYS = 7
LiveConfig.MAX_ANNOUNCEMENT = 140
LiveConfig.ANNOUNCE_DELAY = 12 -- seconds after joining, so it doesn't land on the loading screen

-- The only rewards an extra code can give. Fixed here so a typo in the Creator Hub can't
-- hand out something huge.
LiveConfig.REWARD_MENU = {
	sand_boost = { Boost = "SandBoost", BoostSeconds = 900 },
	luck_boost = { Boost = "LuckBoost", BoostSeconds = 900 },
	coin_boost = { Boost = "CoinBoost", BoostSeconds = 900 },
	coins = { ScaledCoins = 300 },
	big_coins = { ScaledCoins = 600 },
	beach_egg = { Egg = "beach_egg", EggCount = 1 },
} :: { [string]: Types.Reward }

local PAUSE_KEYS: { [string]: Feature } = {
	pause_hatching = "Hatching",
	pause_autodig = "AutoDig",
	pause_leaderboards = "Leaderboards",
	pause_fusing = "Fusing", -- endgame C2 (and the v2.2 Golden fusion)
	pause_milestones = "Milestones", -- endgame C1
	pause_index_rewards = "IndexRewards", -- endgame C3
}

LiveConfig.Changed = Signal.new() :: Signal.Signal<Snapshot>

local function defaults(): Snapshot
	return {
		CodesOn = {},
		CodesOff = {},
		ExtraCodes = {},
		EventsOff = {},
		BonusEvent = nil,
		BonusEventEnds = nil,
		Paused = {},
		Announcement = nil,
	}
end

local current: Snapshot = defaults()
local lastWarnings = ""

local function normalizeCode(text: string): string
	return string.upper((string.gsub(text, "%s", "")))
end

-- Days since 1970-01-01 for a proleptic Gregorian date (Howard Hinnant's days_from_civil).
local function daysFromCivil(y: number, m: number, d: number): number
	y = if m <= 2 then y - 1 else y
	local era = (if y >= 0 then y else y - 399) // 400
	local yoe = y - era * 400
	local mp = (m + 9) % 12
	local doy = (153 * mp + 2) // 5 + d - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return era * 146097 + doe - 719468
end

function LiveConfig.ParseUtc(text: string): number?
	local y, mo, d, rest = string.match(text, "^%s*(%d%d%d%d)%-(%d%d?)%-(%d%d?)(.-)%s*$")
	if not y or not mo or not d then
		return nil
	end
	local year, month, day = tonumber(y) :: number, tonumber(mo) :: number, tonumber(d) :: number
	if month < 1 or month > 12 or day < 1 or day > 31 then
		return nil
	end
	local days = daysFromCivil(year, month, day)
	-- reject impossible days such as 31 Feb (they would roll into the next month)
	if
		daysFromCivil(year, month, 1) + day - 1
		>= daysFromCivil(year + (if month == 12 then 1 else 0), month % 12 + 1, 1)
	then
		return nil
	end
	local r = rest :: string
	if r == "" then
		return days * 86400 + 86399 -- a bare date means the end of that day (UTC)
	end
	local h, mi = string.match(r, "^[%sT]+(%d%d?):(%d%d)%s*[Zz]?$")
	if not h or not mi then
		return nil
	end
	local hour, minute = tonumber(h) :: number, tonumber(mi) :: number
	if hour > 23 or minute > 59 then
		return nil
	end
	return days * 86400 + hour * 3600 + minute * 60
end

local function commaSet(
	value: any,
	key: string,
	warnings: { string },
	check: (string) -> boolean
): { [string]: boolean }
	local set = {}
	if value == nil or value == "" then
		return set
	end
	if type(value) ~= "string" then
		table.insert(warnings, key .. ': expected text like "A,B"')
		return set
	end
	for part in string.gmatch(value, "[^,]+") do
		local item = string.gsub(part, "^%s*(.-)%s*$", "%1")
		if item ~= "" then
			if check(item) then
				set[item] = true
			else
				table.insert(warnings, key .. ': unknown "' .. item .. '"')
			end
		end
	end
	return set
end

local function asTable(value: any): any
	if type(value) == "string" then
		local ok, decoded = pcall(function(): any
			return HttpService:JSONDecode(value)
		end)
		return if ok then decoded else nil
	end
	return value
end

-- `read(key)` returns the raw config value (nil when unset). Never errors; bad values are dropped
-- with a warning and the default is kept.
function LiveConfig.Parse(read: (string) -> any, now: number): (Snapshot, { string })
	local snap = defaults()
	local warnings: { string } = {}

	local function safeRead(key: string): any
		local ok, value = pcall(read, key)
		if not ok then
			table.insert(warnings, key .. ": could not be read")
			return nil
		end
		return value
	end

	-- shipped codes on/off
	local function isShippedCode(item: string): boolean
		return Config.GetCode(item) ~= nil
	end
	for code in commaSet(safeRead("codes_on"), "codes_on", warnings, isShippedCode) do
		snap.CodesOn[normalizeCode(code)] = true
	end
	for code in commaSet(safeRead("codes_off"), "codes_off", warnings, isShippedCode) do
		snap.CodesOff[normalizeCode(code)] = true
	end
	for code in snap.CodesOn do
		if snap.CodesOff[code] then
			snap.CodesOn[code] = nil -- off wins when a code is in both lists
			table.insert(warnings, "codes_on: " .. code .. " is also in codes_off, so it stays off")
		end
	end

	-- extra codes
	local extraRaw = safeRead("extra_codes")
	if extraRaw ~= nil and extraRaw ~= "" then
		local extra = asTable(extraRaw)
		if type(extra) ~= "table" then
			table.insert(warnings, "extra_codes: expected a JSON object")
		else
			local names = {}
			for name in extra do
				if type(name) == "string" then
					table.insert(names, name)
				end
			end
			table.sort(names)
			local count = 0
			for _, name in names do
				local entry = extra[name]
				local code = normalizeCode(name)
				local reward = if type(entry) == "table" and type(entry.reward) == "string"
					then LiveConfig.REWARD_MENU[entry.reward]
					else nil
				local expires: number? = nil
				local expiresOk = true
				if type(entry) == "table" and entry.expires ~= nil then
					expires = if type(entry.expires) == "string" then LiveConfig.ParseUtc(entry.expires) else nil
					expiresOk = expires ~= nil
				end
				if not string.match(code, "^[%w]+$") or #code < 2 or #code > 20 then
					table.insert(warnings, 'extra_codes: "' .. name .. '" must be 2-20 letters or digits')
				elseif Config.GetCode(code) then
					table.insert(warnings, "extra_codes: " .. code .. " is a shipped code (use codes_on)")
				elseif not reward then
					table.insert(warnings, "extra_codes: " .. code .. " needs a reward from the menu")
				elseif not expiresOk then
					table.insert(warnings, "extra_codes: " .. code .. " has a bad expires date")
				elseif count >= LiveConfig.MAX_EXTRA_CODES then
					table.insert(
						warnings,
						"extra_codes: more than " .. LiveConfig.MAX_EXTRA_CODES .. " codes, " .. code .. " ignored"
					)
				else
					count += 1
					snap.ExtraCodes[code] = {
						Code = code,
						Reward = table.clone(reward),
						Enabled = true,
						Expires = expires,
						Note = "Live config code",
					}
				end
			end
		end
	end

	-- events
	local function isEvent(item: string): boolean
		return Config.GetEvent(item) ~= nil
	end
	snap.EventsOff = commaSet(safeRead("events_off"), "events_off", warnings, isEvent)

	local bonus = safeRead("bonus_event")
	if bonus ~= nil and bonus ~= "" then
		local endsRaw = safeRead("bonus_event_ends")
		local ends = if type(endsRaw) == "string" then LiveConfig.ParseUtc(endsRaw) else nil
		if type(bonus) ~= "string" or not Config.GetEvent(bonus) then
			table.insert(warnings, "bonus_event: unknown event")
		elseif ends == nil then
			table.insert(warnings, 'bonus_event_ends: expected "YYYY-MM-DD HH:MM" (UTC)')
		elseif ends > now + LiveConfig.MAX_BONUS_DAYS * 86400 then
			table.insert(warnings, "bonus_event_ends: more than " .. LiveConfig.MAX_BONUS_DAYS .. " days away")
		elseif snap.EventsOff[bonus] then
			table.insert(warnings, "bonus_event: " .. bonus .. " is in events_off")
		elseif ends > now then
			snap.BonusEvent = bonus
			snap.BonusEventEnds = ends
		end
	end

	-- pauses
	for key, feature in PAUSE_KEYS do
		local value = safeRead(key)
		if value == true then
			snap.Paused[feature] = true
		elseif value ~= nil and value ~= false then
			table.insert(warnings, key .. ": expected true or false")
		end
	end

	-- announcement
	local text = safeRead("announcement")
	if text ~= nil and text ~= "" then
		if type(text) ~= "string" then
			table.insert(warnings, "announcement: expected text")
		else
			local trimmed = string.gsub(text, "^%s*(.-)%s*$", "%1")
			if #trimmed > LiveConfig.MAX_ANNOUNCEMENT then
				table.insert(warnings, "announcement: longer than " .. LiveConfig.MAX_ANNOUNCEMENT .. " characters")
			elseif trimmed ~= "" then
				snap.Announcement = trimmed
			end
		end
	end

	table.sort(warnings)
	return snap, warnings
end

function LiveConfig.Get(): Snapshot
	return current
end

function LiveConfig.IsPaused(feature: Feature): boolean
	return current.Paused[feature] == true
end

-- A redeemable code right now, or nil (unknown, off, or expired). Group-only is left to the caller.
function LiveConfig.FindCode(code: string, now: number?): Types.CodeDef?
	local t = now or os.time()
	local key = normalizeCode(code)
	local def = Config.GetCode(key) or current.ExtraCodes[key]
	if not def then
		return nil
	end
	local shippedKey = normalizeCode(def.Code)
	local enabled = def.Enabled
	if current.CodesOn[shippedKey] then
		enabled = true
	end
	if current.CodesOff[shippedKey] then
		enabled = false
	end
	if not enabled or (def.Expires ~= nil and t > def.Expires) then
		return nil
	end
	return def
end

local function apply(snap: Snapshot, warnings: { string })
	local joined = table.concat(warnings, "; ")
	if joined ~= lastWarnings then
		lastWarnings = joined
		for _, w in warnings do
			warn("[LiveConfig] ignored " .. w)
		end
	end
	local previous = current.Announcement
	current = snap
	if snap.Announcement and snap.Announcement ~= previous then
		Net.NotifyAll("Event", snap.Announcement)
	end
	LiveConfig.Changed:Fire(snap)
end

function LiveConfig.OnPlayerAdded(player: Player)
	task.delay(LiveConfig.ANNOUNCE_DELAY, function()
		local text = current.Announcement
		if text and player.Parent then
			Net.Notify(player, "Event", text)
		end
	end)
end

-- Test hook and Studio helper: apply raw values as if they came from ConfigService.
function LiveConfig.ApplyRaw(values: { [string]: any })
	local snap, warnings = LiveConfig.Parse(function(key: string): any
		return values[key]
	end, os.time())
	apply(snap, warnings)
end

-- Boot waits at most this long for ConfigService; a slower answer is applied when it arrives.
LiveConfig.INIT_TIMEOUT = 5

local function connect()
	local ok, snapshotOrErr = pcall(function(): any
		local service = game:GetService("ConfigService") :: any
		return service:GetConfigAsync()
	end)
	if not ok or snapshotOrErr == nil then
		-- Studio without configs, an outage, or an engine without ConfigService: run as published.
		return
	end
	local snapshot = snapshotOrErr :: any
	local function reload()
		local snap, warnings = LiveConfig.Parse(function(key: string): any
			return snapshot:GetValue(key)
		end, os.time())
		apply(snap, warnings)
	end
	reload()
	pcall(function(): any
		snapshot.UpdateAvailable:Connect(function()
			local refreshed = pcall(function(): any
				snapshot:Refresh()
				return nil
			end)
			if refreshed then
				reload()
			end
		end)
		return nil
	end)
end

function LiveConfig.Init()
	local done = false
	task.spawn(function()
		connect()
		done = true
	end)
	local waited = 0
	while not done and waited < LiveConfig.INIT_TIMEOUT do
		waited += task.wait(0.1)
	end
end

return LiveConfig
