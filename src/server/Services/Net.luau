--!strict
--[[
	Net — server-side remote plumbing shared by every service.
	- Net.On(name, handler, opts): connects a client -> server RemoteEvent with a per-player rate
	  limit, an optional "data must be loaded" gate and error isolation (pcall + warn).
	- Argument validators (exploiters send garbage: wrong types, NaN, huge strings).
	- Notify helpers (RemoteEvent Notify(kind, text)), with optional per-key throttling.

	Notify kinds (client contract):
		"Info"     neutral hint / tip
		"Success"  something worked (purchase, equip)
		"Error"    action refused ("Need a better shovel!", "Not enough coins!")
		"Reward"   rewards granted (daily, quest, code, product)
		"Sell"     sand sold ("+1.2K Coins!") — client plays coin rain
		"Announce" server-wide brag (Legendary/Mythic find or hatch)
		"Event"    a timed server event started (High Tide / Golden Hour)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)
local RateLimiter = require(Shared.Util.RateLimiter)

local DataService = require(script.Parent.DataService)

export type NotifyKind = "Info" | "Success" | "Error" | "Reward" | "Sell" | "Announce" | "Event"

export type HandlerOptions = {
	Rate: number?, -- max calls per Window (burst); default 10
	Window: number?, -- seconds; default 1
	RequireData: boolean?, -- default true: ignore calls until the player's data is loaded
}

local Net = {}

local limiters: { RateLimiter.RateLimiter } = {}
local notifyThrottle: { [Player]: { [string]: number } } = {}

-- Validators ------------------------------------------------------------------------------------

function Net.IsString(value: any, maxLength: number?): boolean
	return type(value) == "string" and #value > 0 and #value <= (maxLength or 64)
end

function Net.IsNumber(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) ~= math.huge
end

function Net.IsInteger(value: any, min: number?, max: number?): boolean
	if not Net.IsNumber(value) or value % 1 ~= 0 then
		return false
	end
	return (min == nil or value >= min) and (max == nil or value <= max)
end

function Net.IsVector3(value: any): boolean
	if typeof(value) ~= "Vector3" then
		return false
	end
	local v = value :: Vector3
	return Net.IsNumber(v.X) and Net.IsNumber(v.Y) and Net.IsNumber(v.Z)
end

-- Handlers --------------------------------------------------------------------------------------

function Net.On(name: string, handler: (Player, ...any) -> ...any, options: HandlerOptions?)
	local opts: HandlerOptions = options or {}
	local limiter = RateLimiter.new(opts.Rate or 10, opts.Window or 1)
	table.insert(limiters, limiter)
	local requireData = opts.RequireData ~= false
	Remotes.Get(name).OnServerEvent:Connect(function(player: Player, ...: any)
		if not limiter:Check(player) then
			return
		end
		if requireData and not DataService.IsLoaded(player) then
			return
		end
		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn(string.format("[Net] %s handler error for %s: %s", name, player.Name, tostring(err)))
		end
	end)
end

-- Remote function with the same protections. Returns `fallback` when throttled / failing.
function Net.OnInvoke(name: string, handler: (Player, ...any) -> any, fallback: any, options: HandlerOptions?)
	local opts: HandlerOptions = options or {}
	local limiter = RateLimiter.new(opts.Rate or 10, opts.Window or 1)
	table.insert(limiters, limiter)
	Remotes.GetFunction(name).OnServerInvoke = function(player: Player, ...: any): any
		if not limiter:Check(player) then
			return fallback
		end
		local ok, result = pcall(handler, player, ...)
		if not ok then
			warn(string.format("[Net] %s invoke error for %s: %s", name, player.Name, tostring(result)))
			return fallback
		end
		return result
	end
end

-- Notify ----------------------------------------------------------------------------------------

function Net.Notify(player: Player, kind: NotifyKind, text: string)
	if player.Parent then
		Remotes.Get("Notify"):FireClient(player, kind, text)
	end
end

-- Same as Notify, but at most once per `interval` seconds for a given throttle key.
function Net.NotifyThrottled(player: Player, kind: NotifyKind, text: string, throttleKey: string, interval: number)
	local perPlayer = notifyThrottle[player]
	if not perPlayer then
		perPlayer = {}
		notifyThrottle[player] = perPlayer
	end
	local now = os.clock()
	local last = perPlayer[throttleKey]
	if last and now - last < interval then
		return
	end
	perPlayer[throttleKey] = now
	Net.Notify(player, kind, text)
end

function Net.NotifyAll(kind: NotifyKind, text: string)
	Remotes.Get("Notify"):FireAllClients(kind, text)
end

function Net.FireClient(name: string, player: Player, ...: any)
	if player.Parent then
		Remotes.Get(name):FireClient(player, ...)
	end
end

function Net.FireAll(name: string, ...: any)
	Remotes.Get(name):FireAllClients(...)
end

function Net.OnPlayerRemoving(player: Player)
	notifyThrottle[player] = nil
	for _, limiter in limiters do
		limiter:Remove(player)
	end
end

-- Character helpers -----------------------------------------------------------------------------

function Net.GetRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not character or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local root = (character :: Model):FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

function Net.GetPlayerFromPart(part: BasePart): Player?
	local current: Instance? = part:FindFirstAncestorOfClass("Model")
	while current do
		local model = current :: Instance
		if model:IsA("Model") then
			local player = Players:GetPlayerFromCharacter(model)
			if player then
				return player
			end
		end
		current = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

return Net
