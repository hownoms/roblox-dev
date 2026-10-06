--!strict
--[[
	DevCommands — chat commands for playtesting. Only active in Roblox Studio; does nothing in
	live servers.

		/coins <n>     add coins
		/max           own and equip the best shovel and backpack, plus lots of coins
		/dig <depth>   carve a shaft at your position (inside the dig zone) down to <depth> studs
		               and drop you at the bottom
		/rebirths <n>  set your rebirth count
		/wipe          reset your save to a brand-new player (replays the tutorial)
		/surface       return to the surface (boardwalk)
		/tide          run the tide now: refill every dug column (like High Tide)
		/stress [n] [fx] | /stress stop   v2.3 load test: n digging bots + pets (docs/PERFORMANCE.md)
]]

local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)
local BeachService = require(script.Parent.BeachService)
local PetService = require(script.Parent.PetService)
local ShopService = require(script.Parent.ShopService)
local World = require(script.Parent.Parent.World)
-- v2.3 /stress
local Types = require(ReplicatedStorage.Shared.Types)
local Stats = require(ReplicatedStorage.Shared.Util.Stats)
local Models = require(ReplicatedStorage.Shared.Models)
local DigService = require(script.Parent.DigService)
local MultiplierService = require(script.Parent.MultiplierService)

local DevCommands = {}

local SHAFT_WIDTH = 12

local function number(arg: string?): number?
	local n = tonumber(arg or "")
	if n and n == n and math.abs(n) ~= math.huge then
		return n
	end
	return nil
end

local handlers: { [string]: (Player, { string }) -> () } = {}

handlers["/coins"] = function(player, args)
	local amount = number(args[1]) or 1e6
	DataService.Increment(player, "Coins", amount)
	Net.Notify(player, "Success", "[Dev] +" .. tostring(amount) .. " coins")
end

handlers["/max"] = function(player)
	local bestShovel = Config.Shovels[#Config.Shovels].Id
	local bestBackpack = Config.Backpacks[#Config.Backpacks].Id
	DataService.Mutate(player, { "OwnedShovels", "OwnedBackpacks", "Coins" }, function(data)
		for _, def in Config.Shovels do
			data.OwnedShovels[def.Id] = true
		end
		for _, def in Config.Backpacks do
			data.OwnedBackpacks[def.Id] = true
		end
		data.Coins = math.max(data.Coins, 1e15)
	end)
	ShopService.Equip(player, "Shovel", bestShovel)
	ShopService.Equip(player, "Backpack", bestBackpack)
	Net.Notify(player, "Success", "[Dev] Best gear unlocked")
end

handlers["/dig"] = function(player, args)
	local character = player.Character
	if not character then
		Net.Notify(player, "Error", "[Dev] No character yet")
		return
	end
	assert(character) -- refine for the type checker (guarded above)
	local zone = World.GetDigZone()
	local depth = math.clamp(number(args[1]) or 100, 8, zone.Size.Y - 4)
	-- Shaft at the player's XZ, snapped to the voxel grid and kept inside the dig zone.
	local here = World.ClampToDigZone(character:GetPivot().Position, SHAFT_WIDTH / 2)
	local x = math.floor(here.X / 4 + 0.5) * 4
	local z = math.floor(here.Z / 4 + 0.5) * 4
	local top = Config.SURFACE_Y
	local bottom = math.floor((top - depth) / 4) * 4
	local minV = Vector3.new(x - SHAFT_WIDTH / 2, bottom, z - SHAFT_WIDTH / 2)
	local maxV = Vector3.new(x + SHAFT_WIDTH / 2, top, z + SHAFT_WIDTH / 2)
	local size = maxV - minV + Vector3.new(0, 4, 0)
	Workspace.Terrain:FillBlock(CFrame.new(minV + size / 2), size, Enum.Material.Air)
	BeachService.RecordCarve(minV, maxV)
	BeachService.ReportDig(player, depth)
	character:PivotTo(CFrame.new(x, bottom + 4, z))
	Net.Notify(player, "Success", "[Dev] Dropped to " .. Config.GetLayerAtDepth(depth).Name)
end

handlers["/tide"] = function(player)
	BeachService.TideStep(true)
	Net.Notify(player, "Success", "[Dev] Tide refilled every hole")
end

handlers["/rebirths"] = function(player, args)
	DataService.Set(player, "Rebirths", math.max(0, math.floor(number(args[1]) or 1)))
	Net.Notify(player, "Success", "[Dev] Rebirths set")
end

handlers["/wipe"] = function(player)
	local fresh = Config.NewPlayerData() :: any
	local keys = {}
	for key in fresh do
		table.insert(keys, key)
	end
	DataService.Mutate(player, keys, function(data)
		for key, value in fresh do
			(data :: any)[key] = value
		end
	end)
	ShopService.GiveShovelTool(player)
	BeachService.TeleportToSurface(player)
	Net.Notify(player, "Success", "[Dev] Save wiped. Rejoin to replay the tutorial.")
end

handlers["/pet"] = function(player, args)
	local id = args[1] or "mega_excavator"
	if not Config.GetPet(id) then
		Net.Notify(player, "Error", "[Dev] Unknown pet id: " .. id)
		return
	end
	PetService.GrantPet(player, id, true)
	Net.Notify(player, "Success", "[Dev] Gave pet " .. id)
end

handlers["/surface"] = function(player)
	BeachService.TeleportToSurface(player)
end

function DevCommands.Start()
	if not RunService:IsStudio() then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "DevCommands"
	folder.Parent = TextChatService
	for name, handler in handlers do
		local command = Instance.new("TextChatCommand")
		command.Name = name
		command.PrimaryAlias = name
		command.Parent = folder
		command.Triggered:Connect(function(source: TextSource, text: string)
			local player = game:GetService("Players"):GetPlayerByUserId(source.UserId)
			if not player or not DataService.Get(player) then
				return
			end
			local args = string.split(text, " ")
			table.remove(args, 1)
			task.spawn(handler, player, args) -- errors print to Output with a stack trace
		end)
	end
	print("[DevCommands] Studio dev commands ready: /coins /max /dig /rebirths /wipe /surface /tide /pet /stress")
end

-- v3 discovery slice (Discovery agent) ---------------------------------------------------------
--   /find [treasureId] [size] [material]  uncover a find at your feet right now (excavation)
--   /deposits                             how many buried deposits are near you / on the server
-- (registered before Start runs; Start only runs in Studio)
handlers["/find"] = function(player, args)
	local Discovery = require(script.Parent.DiscoveryService) :: any
	local maybeRoot = Net.GetRoot(player)
	if not maybeRoot then
		return
	end
	local root = maybeRoot :: BasePart
	local depth = math.max(Config.SURFACE_Y - root.Position.Y, 0)
	local layer = Config.Layers[Config.GetLayerIndexAtDepth(depth)]
	local id = args[1] or layer.LootTable[#layer.LootTable].TreasureId
	if not Config.GetTreasure(id) then
		Net.Notify(player, "Error", "[Dev] Unknown treasure id: " .. id)
		return
	end
	local pos = World.ClampToDigZone(root.Position - Vector3.new(0, 5, 0), 2)
	local deposit = Discovery.AddDeposit(pos, id)
	if deposit then
		Discovery.Uncover(player, deposit, nil, nil, args[2], args[3])
	end
end

handlers["/deposits"] = function(player)
	local Discovery = require(script.Parent.DiscoveryService) :: any
	local root = Net.GetRoot(player)
	local near = if root
		then #Discovery.DepositsNear((root :: BasePart).Position, Config.Discovery.DETECTOR_RANGE)
		else 0
	Net.Notify(
		player,
		"Info",
		string.format("[Dev] %d deposits within range, %d on the server", near, Discovery.CountDeposits())
	)
end

-- v2.3 /stress (Platform agent) ------------------------------------------------------------------
--   /stress [n] [fx]  spawn n (default 15) digging bots "StressBot_i" across the dig zone. Each
--                     digs with the top shovel at its real rate and has 3 top digging pets that
--                     dig like PetDigService. "fx" adds a particle stream per bot.
--   /stress stop      remove the bots, print the final summary and refill every hole (tide)
-- Every 10 s it prints: digs/s (bot + pet), terrain edits/s, server Heartbeat ms (avg / max),
-- memory (Stats:GetTotalMemoryUsageMb) and data send kbps. docs/PERFORMANCE.md explains how to
-- use it with the MicroProfiler.
-- How it digs: bots are not Players, and DigAt needs a real player's data, so every bot dig is a
-- real DigService.DigAt for the player who ran /stress, with Source "Ride" (companion rules: no
-- shovel cooldown, range measured from opts.Origin = the bot) and Silent = true. Validation,
-- voxel reads, carving, tide bookkeeping, sand, MaxDepth, quests and treasure rolls all run as
-- for a real digger. Side effects land on the dev's save (Studio only): sand is emptied whenever
-- the backpack is 90% full, MaxDepth / quests advance, and treasure finds still pop up for you.

local STRESS_FOLDER = "StressBots"
local STRESS_REPORT_SECONDS = 10
local STRESS_PET_RING = { 6, 12 } -- studs from the bot, like PetDigService
local STRESS_RELOCATE_AFTER = 6 -- consecutive failed digs before the bot moves to a new column

type StressPet = { Id: string, Model: Model, Dig: any, Next: number }
type StressBot = {
	Model: Model,
	Root: BasePart,
	Column: Vector3, -- surface point of its column
	FeetY: number,
	NextDig: number,
	Fails: number,
	Pets: { StressPet },
}
type StressCounters = { Digs: number, Edits: number, Attempts: number, Beats: number, BeatSum: number, BeatMax: number }

local stress: {
	Player: Player?,
	Bots: { StressBot },
	Folder: Folder?,
	Connection: RBXScriptConnection?,
	Window: StressCounters,
	Total: StressCounters,
	Started: number,
	WindowStart: number,
	Rng: Random,
} =
	{
		Player = nil,
		Bots = {},
		Folder = nil,
		Connection = nil,
		Window = { Digs = 0, Edits = 0, Attempts = 0, Beats = 0, BeatSum = 0, BeatMax = 0 },
		Total = { Digs = 0, Edits = 0, Attempts = 0, Beats = 0, BeatSum = 0, BeatMax = 0 },
		Started = 0,
		WindowStart = 0,
		Rng = Random.new(20261006),
	}

local function newCounters(): StressCounters
	return { Digs = 0, Edits = 0, Attempts = 0, Beats = 0, BeatSum = 0, BeatMax = 0 }
end

local function stressPart(model: Model, name: string, size: Vector3, offset: Vector3, color: Color3): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Color = color
	part.CFrame = CFrame.new(offset)
	part.Parent = model
	return part
end

local function anchorAll(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
end

-- The 3 strongest digging pets (Dig.Power, then the shortest Interval).
local function topDiggingPets(): { Types.PetDef }
	local list: { Types.PetDef } = {}
	for _, def in Config.Pets do
		if def.Dig and not def.Rideable then
			table.insert(list, def)
		end
	end
	table.sort(list, function(a: Types.PetDef, b: Types.PetDef): boolean
		local da, db = a.Dig :: Types.PetDigDef, b.Dig :: Types.PetDigDef
		if da.Power ~= db.Power then
			return da.Power > db.Power
		end
		return da.Interval < db.Interval
	end)
	return { list[1], list[2] or list[1], list[3] or list[1] }
end

local function randomColumn(): Vector3
	local zone = World.GetDigZone()
	local c = zone.CFrame.Position
	local hx, hz = zone.Size.X / 2 - 8, zone.Size.Z / 2 - 8
	return Vector3.new(c.X + stress.Rng:NextNumber(-hx, hx), Config.SURFACE_Y, c.Z + stress.Rng:NextNumber(-hz, hz))
end

local function placeBot(bot: StressBot)
	bot.Model:PivotTo(CFrame.new(bot.Column.X, bot.FeetY + 3, bot.Column.Z))
end

local function newBot(index: number, folder: Folder, pets: { Types.PetDef }, fx: boolean): StressBot
	local model = Instance.new("Model")
	model.Name = "StressBot_" .. index
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local skin = Color3.fromRGB(255, 205, 160)
	local shirt = Color3.fromHSV((index * 0.13) % 1, 0.6, 0.9)
	local root = stressPart(model, "HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.zero, shirt)
	stressPart(model, "Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 1.6, 0), skin)
	stressPart(model, "LeftArm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0), skin)
	stressPart(model, "RightArm", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0), skin)
	stressPart(model, "LeftLeg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0), Color3.fromRGB(40, 60, 140))
	stressPart(model, "RightLeg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0), Color3.fromRGB(40, 60, 140))
	model.PrimaryPart = root
	local okShovel, shovel = pcall(Models.Shovel, Config.Shovels[#Config.Shovels].Id)
	if okShovel and shovel then
		anchorAll(shovel)
		shovel:PivotTo(root.CFrame * CFrame.new(1.8, 0, -1))
		shovel.Parent = model
	end
	if fx then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "DigBurst"
		emitter.Rate = 30
		emitter.Lifetime = NumberRange.new(0.4, 0.8)
		emitter.Speed = NumberRange.new(6, 12)
		emitter.SpreadAngle = Vector2.new(40, 40)
		emitter.Color = ColorSequence.new(Color3.fromRGB(230, 200, 140))
		emitter.Parent = root
	end
	local bot: StressBot = {
		Model = model,
		Root = root,
		Column = randomColumn(),
		FeetY = Config.SURFACE_Y,
		NextDig = os.clock() + stress.Rng:NextNumber(0, 0.5),
		Fails = 0,
		Pets = {},
	}
	for i, def in pets do
		local okPet, petModel = pcall(Models.Pet, def.Id)
		local pm: Model = if okPet and petModel then petModel else Instance.new("Model")
		anchorAll(pm)
		pm.Name = "Pet" .. i .. "_" .. def.Id
		pm.Parent = model
		table.insert(bot.Pets, {
			Id = def.Id,
			Model = pm,
			Dig = def.Dig,
			Next = os.clock() + stress.Rng:NextNumber(0, (def.Dig :: Types.PetDigDef).Interval),
		})
	end
	placeBot(bot)
	model.Parent = folder
	return bot
end

local function relocate(bot: StressBot)
	bot.Column = randomColumn()
	bot.FeetY = Config.SURFACE_Y
	bot.Fails = 0
	placeBot(bot)
end

local function keepBackpackRoom(player: Player)
	local data = DataService.Get(player)
	local ctx = MultiplierService.GetContext(player)
	if data and ctx and data.Sand >= Stats.GetCapacity(ctx) * 0.9 then
		DataService.Set(player, "Sand", 0) -- stands in for selling
	end
end

local function stressDig(player: Player, bot: StressBot, at: Vector3, opts: Types.DigOptions): Types.DigResult?
	keepBackpackRoom(player)
	stress.Window.Attempts += 1
	stress.Total.Attempts += 1
	local ok, result = pcall(DigService.DigAt, player, at, opts)
	if ok and result and result.Success then
		stress.Window.Digs += 1
		stress.Total.Digs += 1
		stress.Window.Edits += 1
		stress.Total.Edits += 1
		return result
	end
	return nil
end

local function stressStep(dt: number)
	local ms = dt * 1000
	for _, c in { stress.Window, stress.Total } do
		c.Beats += 1
		c.BeatSum += ms
		c.BeatMax = math.max(c.BeatMax, ms)
	end
	local maybePlayer = stress.Player
	if not maybePlayer or maybePlayer.Parent == nil or not Net.GetRoot(maybePlayer) then
		return
	end
	local player = maybePlayer :: Player
	local now = os.clock()
	local top = Config.Shovels[#Config.Shovels]
	for _, bot in stress.Bots do
		if now >= bot.NextDig then
			bot.NextDig = now + top.Cooldown
			local offset = Vector3.new(stress.Rng:NextNumber(-3, 3), 0, stress.Rng:NextNumber(-3, 3))
			local at = Vector3.new(bot.Column.X, bot.FeetY, bot.Column.Z) + offset
			local result = stressDig(player, bot, at, {
				Power = top.Power,
				Radius = top.Radius,
				SandMultiplier = top.SandMultiplier,
				Source = "Ride",
				Origin = bot.Root.Position,
				Silent = true,
			})
			if result then
				bot.Fails = 0
				-- stand on the floor of the cube just carved (16-stud cube for the top shovel)
				bot.FeetY = math.max(
					Config.SURFACE_Y - result.Depth - top.Radius * 2 + 4,
					Config.SURFACE_Y - Config.TOTAL_DEPTH + 8
				)
				placeBot(bot)
			else
				bot.Fails += 1
				if bot.Fails >= STRESS_RELOCATE_AFTER then
					relocate(bot)
				end
			end
		end
		for _, pet in bot.Pets do
			if now >= pet.Next then
				local dig = pet.Dig :: Types.PetDigDef
				pet.Next = now + dig.Interval
				local angle = stress.Rng:NextNumber(0, math.pi * 2)
				local r = stress.Rng:NextNumber(STRESS_PET_RING[1], STRESS_PET_RING[2])
				local spot =
					Vector3.new(bot.Column.X + math.cos(angle) * r, bot.FeetY, bot.Column.Z + math.sin(angle) * r)
				pet.Model:PivotTo(CFrame.new(spot + Vector3.new(0, 1, 0)))
				stressDig(player, bot, spot, {
					Power = dig.Power,
					Radius = dig.Radius,
					SandMultiplier = dig.SandMultiplier,
					Source = "Ride",
					Origin = spot,
					Silent = true,
				})
			end
		end
	end
end

local function stressSummary(c: StressCounters, seconds: number): string
	local statsService = game:GetService("Stats")
	local memory = 0
	pcall(function()
		memory = statsService:GetTotalMemoryUsageMb()
	end)
	local sendKbps = 0
	pcall(function()
		sendKbps = statsService.DataSendKbps
	end)
	local s = math.max(seconds, 1e-3)
	return string.format(
		"[Stress] %d bots | %.1f digs/s (%.0f%% ok) | %.1f terrain edits/s | heartbeat %.1f ms avg / %.1f ms max | memory %.0f MB | send %.0f kbps",
		#stress.Bots,
		c.Digs / s,
		if c.Attempts > 0 then c.Digs / c.Attempts * 100 else 0,
		c.Edits / s,
		if c.Beats > 0 then c.BeatSum / c.Beats else 0,
		c.BeatMax,
		memory,
		sendKbps
	)
end

function DevCommands.StopStress(): string?
	if stress.Connection then
		(stress.Connection :: RBXScriptConnection):Disconnect()
		stress.Connection = nil
	end
	if not stress.Folder then
		return nil
	end
	local summary = stressSummary(stress.Total, os.clock() - stress.Started) .. " (whole run)"
	print(summary)
	local folder = stress.Folder :: Folder
	folder:Destroy()
	stress.Folder = nil
	stress.Bots = {}
	stress.Player = nil
	BeachService.TideStep(true)
	return summary
end

function DevCommands.StartStress(player: Player, count: number?, fx: boolean?): number
	DevCommands.StopStress()
	local n = math.clamp(math.floor(count or 15), 1, 64)
	local folder = Instance.new("Folder")
	folder.Name = STRESS_FOLDER
	folder.Parent = Workspace
	stress.Folder = folder
	stress.Player = player
	stress.Bots = {}
	stress.Window = newCounters()
	stress.Total = newCounters()
	stress.Started = os.clock()
	stress.WindowStart = os.clock()
	local pets = topDiggingPets()
	for i = 1, n do
		table.insert(stress.Bots, newBot(i, folder, pets, fx == true))
	end
	stress.Connection = RunService.Heartbeat:Connect(stressStep)
	local runFolder = folder
	task.spawn(function()
		while stress.Folder == runFolder do
			task.wait(STRESS_REPORT_SECONDS)
			if stress.Folder ~= runFolder then
				break
			end
			local now = os.clock()
			local line = stressSummary(stress.Window, now - stress.WindowStart)
			print(line)
			stress.Window = newCounters()
			stress.WindowStart = now
		end
	end)
	return n
end

-- Tests: totals of the current / last run.
function DevCommands.GetStressStats(): { Bots: number, Digs: number, Attempts: number }
	return { Bots = #stress.Bots, Digs = stress.Total.Digs, Attempts = stress.Total.Attempts }
end

handlers["/stress"] = function(player, args)
	if args[1] == "stop" then
		local summary = DevCommands.StopStress()
		Net.Notify(
			player,
			"Success",
			if summary then "[Dev] Stress bots removed, holes refilled" else "[Dev] No stress run"
		)
		return
	end
	local n = number(args[1]) or 15
	local fx = table.find(args, "fx") ~= nil
	local started = DevCommands.StartStress(player, n, fx)
	Net.Notify(
		player,
		"Success",
		string.format("[Dev] %d stress bots digging. Summary every 10 s in Output. /stress stop", started)
	)
end

return DevCommands
