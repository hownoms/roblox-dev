--!strict
--[[
	DiscoveryService (v3 discovery slice) — buried finds, the detector and the excavation moment.
	Design + numbers: docs/design/Discovery.md. Balance: Config.Discovery. Pure math: Util/Finds.

	DEPOSITS are pure server data (no parts): the dig zone is split into chunks of
	CHUNK x CHUNK_Y x CHUNK studs, keyed in a hash. A chunk is seeded lazily the first time a dig,
	a scan or a test looks at it: Finds.Density(layer) deposits (fraction = chance of one more,
	never more than CHUNK_CAP), each at a random point in solid, undug sand at least MIN_DEPTH
	below the surface, holding a treasure rolled from the layer's LootTable (or a Relic). Chunks
	below their target regrow one deposit every RESPAWN_SECONDS; chunks nobody touched for
	EVICT_SECONDS (and no player near) are forgotten and re-seeded fresh later (the tide refilled
	them anyway). The whole server never holds more than SERVER_CAP deposits (oldest chunks go).

	UNCOVERING: DigService fires ServerSignals.Carved(player, min, max, source, layer) after every
	successful non-Silent carve; only Shovel / Auto digs (the player's own) uncover anything, so
	pets, the ride-on excavator and /stress bots never trigger finds or popups. The deposit nearest to the carve within UNCOVER_RADIUS of the carved box is
	uncovered and removed from the hash: the digging player OWNS its excavation (others only see
	it). One excavation per player at a time (more deposits wait for the next dig). The variant
	(size + material) is rolled now, with the owner's luck (Finds.VariantOdds = true odds shown
	in the Index). A brand-new player's FTUE_FIND_DIG-th dig always uncovers a Common find, and
	when nothing was uncovered a tiny AMBIENT chance gives a plain Common find with no minigame.

	EXCAVATION: the server spawns the find model half-buried at the dug floor (tag "DiscoveryFind",
	attributes FindId / TreasureId / Rarity / Size / Material / OwnerId / Stage / Rise / Tier) and
	sends the owner ExcavationStart(Types.ExcavationInfo). The client plays RINGS timed taps and
	answers Excavate(id, errors) with each ring's timing error. The server grades the errors itself
	(Finds.Score), caps the quality at Good when the answer came faster than
	MIN_EXCAVATION_SECONDS, ignores answers for anything but the owner's current excavation, and
	resolves on its own after EXCAVATION_TIMEOUT (no hits = Damaged; a find is never lost).
	Quality only changes value (x0.6 / x1 / x1.5), so a cheating client gains at most +50% on a
	find it would have got anyway.

	REVEAL: the find goes to PlayerData.Finds (sold with sand) + Index + FindVariants, the owner
	gets FindRevealed(Types.FindInfo), the model's Stage becomes "Revealed" (every client animates
	it rising with effects by Tier; Mythic / Relic models are ModelStreamingMode Persistent so
	their sky beam is visible to the whole server) and is removed after REVEAL_SECONDS
	(SPECTACLE_SECONDS for Server / Spectacle tiers). Rarities with Announce brag to the server.

	DETECTOR: Scan() starts a SCAN_SECONDS scan (SCAN_COOLDOWN between starts). Every
	PING_INTERVAL the owner gets DetectorPing(Types.DetectorPing) for the nearest deposit within
	DETECTOR_RANGE: a distance band, a compass sector, Down/Level/Up and the signal colour only.
	Positions and the deposit list never leave the server.

	Public API (tests / dev):
		DiscoveryService.Seed(position): number          -- seed / touch the chunk there, deposit count
		DiscoveryService.DepositsNear(position, radius): { Deposit }
		DiscoveryService.CountDeposits(): number
		DiscoveryService.ChunkCount(): number
		DiscoveryService.AddDeposit(position, treasureId): Deposit?
		DiscoveryService.Uncover(player, deposit, near?): string?   -- starts an excavation (id)
		DiscoveryService.GetExcavation(player): Excavation?
		DiscoveryService.Resolve(player, id, errors?): Types.FindInfo?
		DiscoveryService.Maintain(now?)                  -- respawn / evict pass
		DiscoveryService.PingFor(player): Types.DetectorPing
		DiscoveryService.SetSeed(seed)                   -- deterministic rolls (tests)
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local Models = require(Shared.Models)
local Stats = require(Shared.Util.Stats)
local Finds = require(Shared.Util.Finds)

local Analytics = require(script.Parent.Analytics)
local BeachService = require(script.Parent.BeachService)
local DataService = require(script.Parent.DataService)
local MultiplierService = require(script.Parent.MultiplierService)
local Net = require(script.Parent.Net)
local ServerSignals = require(script.Parent.ServerSignals)
local World = require(script.Parent.Parent.World)

local D = Config.Discovery

export type Deposit = {
	Id: number,
	Position: Vector3,
	TreasureId: string,
	Rarity: string,
	ChunkKey: number,
}

type Chunk = {
	Key: number,
	CX: number,
	CY: number,
	CZ: number,
	Min: Vector3,
	Max: Vector3,
	Target: number,
	Deposits: { Deposit },
	LastTouched: number,
	LastRespawn: number,
}

export type Excavation = {
	Id: string,
	Player: Player,
	TreasureId: string,
	Rarity: string,
	Size: string,
	Material: string,
	Position: Vector3,
	Started: number,
	Model: Model?,
	Resolved: boolean,
}

local TAG = "DiscoveryFind"
local MAINTAIN_INTERVAL = 5
local BOTTOM_FLOOR = 4 -- studs above the bottom of the world kept clear of deposits
local SEED_TRIES = 6

local S = Config.SURFACE_Y
local ZONE = World.GetDigZone()
local ZONE_MIN = ZONE.CFrame.Position - Vector3.new(ZONE.Size.X / 2, 0, ZONE.Size.Z / 2)
local ZONE_MAX = ZONE.CFrame.Position + Vector3.new(ZONE.Size.X / 2, 0, ZONE.Size.Z / 2)
local TOTAL_DEPTH = ZONE.Size.Y
local NX = math.ceil(ZONE.Size.X / D.CHUNK)
local NZ = math.ceil(ZONE.Size.Z / D.CHUNK)
local NY = math.ceil(TOTAL_DEPTH / D.CHUNK_Y)

local DiscoveryService = {}

local rng = Random.new()
local chunks: { [number]: Chunk } = {}
local chunkCount = 0
local depositTotal = 0
local nextDepositId = 0
local nextExcavationId = 0
local excavations: { [Player]: Excavation } = {}
local scans: { [Player]: { Started: number, Until: number } } = {}
local sessionDigs: { [Player]: number } = {}
local folder: Folder? = nil

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { Workspace.Terrain }

-- Chunks ---------------------------------------------------------------------------------------

local function chunkKey(cx: number, cy: number, cz: number): number
	return (cy * 64 + cz) * 4096 + cx
end

local function chunkCoords(position: Vector3): (number, number, number)
	return math.floor((position.X - ZONE_MIN.X) / D.CHUNK),
		math.floor((S - position.Y) / D.CHUNK_Y),
		math.floor((position.Z - ZONE_MIN.Z) / D.CHUNK)
end

local function validCoords(cx: number, cy: number, cz: number): boolean
	return cx >= 0 and cx < NX and cz >= 0 and cz < NZ and cy >= 0 and cy < NY
end

local function depthOf(position: Vector3): number
	return S - position.Y
end

local function randomIn(lo: number, hi: number): number
	return if hi <= lo then lo else lo + rng:NextNumber() * (hi - lo)
end

-- A random deposit spot in the chunk: solid, undug sand, spaced from the others.
local function pickSpot(chunk: Chunk): Vector3?
	for _ = 1, SEED_TRIES do
		local m = D.EDGE_MARGIN
		local pos = Vector3.new(
			randomIn(chunk.Min.X + m, chunk.Max.X - m),
			randomIn(chunk.Min.Y + m, chunk.Max.Y - m),
			randomIn(chunk.Min.Z + m, chunk.Max.Z - m)
		)
		local ok = BeachService.GetDugDepthAt(pos) < depthOf(pos) - 1
		if ok then
			for _, other in chunk.Deposits do
				if (other.Position - pos).Magnitude < D.MIN_SPACING then
					ok = false
					break
				end
			end
		end
		if ok then
			return pos
		end
	end
	return nil
end

local function addTo(chunk: Chunk, pos: Vector3, treasureId: string): Deposit?
	local found = Config.GetTreasure(treasureId)
	if not found then
		return nil
	end
	local def = found :: Types.TreasureDef
	nextDepositId += 1
	local deposit: Deposit = {
		Id = nextDepositId,
		Position = pos,
		TreasureId = treasureId,
		Rarity = def.Rarity,
		ChunkKey = chunk.Key,
	}
	table.insert(chunk.Deposits, deposit)
	depositTotal += 1
	return deposit
end

local function growOne(chunk: Chunk): Deposit?
	if #chunk.Deposits >= D.CHUNK_CAP or depositTotal >= D.SERVER_CAP then
		return nil
	end
	local pos = pickSpot(chunk)
	if not pos then
		return nil
	end
	local layerIndex = Config.GetLayerIndexAtDepth(depthOf(pos :: Vector3))
	local treasureId = Finds.RollTreasure(layerIndex, rng:NextNumber(), rng:NextNumber())
	return if treasureId then addTo(chunk, pos :: Vector3, treasureId) else nil
end

local function forget(chunk: Chunk)
	if chunks[chunk.Key] == chunk then
		chunks[chunk.Key] = nil
		chunkCount -= 1
		depositTotal -= #chunk.Deposits
	end
end

-- Frees room for `needed` deposits by forgetting the least recently touched chunks.
local function makeRoom(needed: number, keep: Chunk?)
	while depositTotal + needed > D.SERVER_CAP do
		local oldest: Chunk? = nil
		for _, chunk in chunks do
			if chunk ~= keep and #chunk.Deposits > 0 and (oldest == nil or chunk.LastTouched < oldest.LastTouched) then
				oldest = chunk
			end
		end
		if not oldest then
			return
		end
		forget(oldest :: Chunk)
	end
end

local function getChunk(cx: number, cy: number, cz: number): Chunk?
	if not validCoords(cx, cy, cz) then
		return nil
	end
	local key = chunkKey(cx, cy, cz)
	local now = os.clock()
	local existing = chunks[key]
	if existing then
		existing.LastTouched = now
		return existing
	end
	local min = Vector3.new(
		ZONE_MIN.X + cx * D.CHUNK,
		S - math.min((cy + 1) * D.CHUNK_Y, TOTAL_DEPTH - BOTTOM_FLOOR),
		ZONE_MIN.Z + cz * D.CHUNK
	)
	local max = Vector3.new(
		math.min(ZONE_MIN.X + (cx + 1) * D.CHUNK, ZONE_MAX.X),
		S - math.max(cy * D.CHUNK_Y, D.MIN_DEPTH),
		math.min(ZONE_MIN.Z + (cz + 1) * D.CHUNK, ZONE_MAX.Z)
	)
	local centreDepth = S - (min.Y + max.Y) / 2
	local density = Finds.Density(Config.GetLayerIndexAtDepth(centreDepth))
	-- scale by the chunk's real volume (edge chunks are thinner)
	local volume = (max.X - min.X) * (max.Y - min.Y) * (max.Z - min.Z)
	density *= math.clamp(volume / (D.CHUNK * D.CHUNK * D.CHUNK_Y), 0, 1)
	local target = math.floor(density) + (if rng:NextNumber() < density % 1 then 1 else 0)
	local chunk: Chunk = {
		Key = key,
		CX = cx,
		CY = cy,
		CZ = cz,
		Min = min,
		Max = max,
		Target = math.min(target, D.CHUNK_CAP),
		Deposits = {},
		LastTouched = now,
		LastRespawn = now,
	}
	chunks[key] = chunk
	chunkCount += 1
	makeRoom(chunk.Target, chunk)
	for _ = 1, chunk.Target do
		growOne(chunk)
	end
	return chunk
end

-- Every chunk overlapping the box [min, max] (seeded on first touch).
local function chunksIn(minV: Vector3, maxV: Vector3): { Chunk }
	local ax, ay, az = chunkCoords(Vector3.new(minV.X, maxV.Y, minV.Z))
	local bx, by, bz = chunkCoords(Vector3.new(maxV.X, minV.Y, maxV.Z))
	local list = {}
	for cy = math.max(ay, 0), math.min(by, NY - 1) do
		for cz = math.max(az, 0), math.min(bz, NZ - 1) do
			for cx = math.max(ax, 0), math.min(bx, NX - 1) do
				local chunk = getChunk(cx, cy, cz)
				if chunk then
					table.insert(list, chunk)
				end
			end
		end
	end
	return list
end

local function boxDistance(p: Vector3, minV: Vector3, maxV: Vector3): number
	local dx = math.max(minV.X - p.X, 0, p.X - maxV.X)
	local dy = math.max(minV.Y - p.Y, 0, p.Y - maxV.Y)
	local dz = math.max(minV.Z - p.Z, 0, p.Z - maxV.Z)
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function removeDeposit(deposit: Deposit): boolean
	local chunk = chunks[deposit.ChunkKey]
	if not chunk then
		return false
	end
	local index = table.find(chunk.Deposits, deposit)
	if not index then
		return false
	end
	table.remove(chunk.Deposits, index)
	depositTotal -= 1
	chunk.LastRespawn = os.clock()
	return true
end

-- Deposits ----------------------------------------------------------------------------------------

function DiscoveryService.Seed(position: Vector3): number
	local chunk = getChunk(chunkCoords(position))
	return if chunk then #chunk.Deposits else 0
end

function DiscoveryService.DepositsNear(position: Vector3, radius: number): { Deposit }
	local r = Vector3.new(radius, radius, radius)
	local list = {}
	for _, chunk in chunksIn(position - r, position + r) do
		for _, deposit in chunk.Deposits do
			if (deposit.Position - position).Magnitude <= radius then
				table.insert(list, deposit)
			end
		end
	end
	return list
end

function DiscoveryService.CountDeposits(): number
	return depositTotal
end

function DiscoveryService.ChunkCount(): number
	return chunkCount
end

function DiscoveryService.ChunkCap(position: Vector3): (number, number)
	local chunk = getChunk(chunkCoords(position))
	return if chunk then #chunk.Deposits else 0, if chunk then chunk.Target else 0
end

-- Tests / dev: put a deposit with this treasure at `position` (in its chunk, ignoring the cap).
function DiscoveryService.AddDeposit(position: Vector3, treasureId: string): Deposit?
	local chunk = getChunk(chunkCoords(position))
	if not chunk then
		return nil
	end
	return addTo(chunk :: Chunk, position, treasureId)
end

function DiscoveryService.SetSeed(seed: number)
	rng = Random.new(seed)
end

-- Respawn + eviction pass (every MAINTAIN_INTERVAL seconds).
function DiscoveryService.Maintain(nowArg: number?)
	local now = nowArg or os.clock()
	local roots: { Vector3 } = {}
	for _, player in Players:GetPlayers() do
		local root = Net.GetRoot(player)
		if root then
			table.insert(roots, root.Position)
		end
	end
	local evict: { Chunk } = {}
	for _, chunk in chunks do
		local near = false
		for _, pos in roots do
			if boxDistance(pos, chunk.Min, chunk.Max) <= D.DETECTOR_RANGE then
				near = true
				chunk.LastTouched = now
				break
			end
		end
		if not near and now - chunk.LastTouched >= D.EVICT_SECONDS then
			table.insert(evict, chunk)
		elseif #chunk.Deposits < chunk.Target and now - chunk.LastRespawn >= D.RESPAWN_SECONDS then
			chunk.LastRespawn = now
			growOne(chunk)
		end
	end
	for _, chunk in evict do
		forget(chunk)
	end
end

-- Find models -----------------------------------------------------------------------------------

local function getFolder(): Folder
	local current = folder
	if current and current.Parent then
		return current
	end
	local f = Instance.new("Folder")
	f.Name = "DiscoveryFinds"
	f.Parent = Workspace
	folder = f
	return f
end

-- Where a find emerges: the dug floor inside the carved box, nearest the deposit (raycast for the
-- VISIBLE terrain surface, standing rule 1). Falls back to the carve floor.
local function emergePoint(deposit: Vector3, minV: Vector3?, maxV: Vector3?): Vector3
	if not minV or not maxV then
		local hit = Workspace:Raycast(deposit + Vector3.new(0, 6, 0), Vector3.new(0, -12, 0), terrainOnly)
		return if hit then hit.Position else deposit
	end
	local lo, hi = minV :: Vector3, maxV :: Vector3
	local x = math.clamp(deposit.X, lo.X + 1, math.max(lo.X + 1, hi.X - 1))
	local z = math.clamp(deposit.Z, lo.Z + 1, math.max(lo.Z + 1, hi.Z - 1))
	local top = hi.Y + 2
	local hit = Workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -(top - lo.Y) - 6, 0), terrainOnly)
	return if hit then hit.Position else Vector3.new(x, lo.Y + 1, z)
end

local function spawnModel(ex: Excavation, tier: Types.FindTier): Model?
	local ok, result = pcall(function(): Model
		return Models.Find(ex.TreasureId, ex.Size, ex.Material)
	end)
	if not ok then
		warn("[DiscoveryService] find model failed: " .. tostring(result))
		return nil
	end
	local model = result :: Model
	local size = Finds.GetSize(ex.Size)
	local scale = if size and size.Scale then size.Scale else 1
	local rise = 1.2 * scale + 0.4
	model.Name = "Find_" .. ex.Id
	model:PivotTo(CFrame.new(ex.Position + Vector3.new(0, 0.75 * scale - rise, 0)))
	model:SetAttribute("FindId", ex.Id)
	model:SetAttribute("TreasureId", ex.TreasureId)
	model:SetAttribute("Rarity", ex.Rarity)
	model:SetAttribute("Size", ex.Size)
	model:SetAttribute("Material", ex.Material)
	model:SetAttribute("OwnerId", ex.Player.UserId)
	model:SetAttribute("Stage", "Excavating")
	model:SetAttribute("Rise", rise)
	model:SetAttribute("Tier", tier)
	-- Mythic / Relic: the sky beam is for the whole server, so never stream the model out.
	model.ModelStreamingMode = if Finds.TierOrder(tier) >= Finds.TierOrder("Server")
		then Enum.ModelStreamingMode.Persistent
		else Enum.ModelStreamingMode.Atomic
	model.Parent = getFolder()
	CollectionService:AddTag(model, TAG)
	return model
end

-- Excavation ---------------------------------------------------------------------------------------

local function luckOf(player: Player): number
	local ctx = MultiplierService.GetContext(player)
	return if ctx then Stats.GetLuck(ctx :: Stats.Context) else 1
end

local function startExcavation(
	player: Player,
	treasureId: string,
	position: Vector3,
	forceSize: string?,
	forceMaterial: string?
): string?
	if excavations[player] then
		return nil
	end
	local found = Config.GetTreasure(treasureId)
	if not found then
		return nil
	end
	local def = found :: Types.TreasureDef
	local luck = luckOf(player)
	nextExcavationId += 1
	local ex: Excavation = {
		Id = "x" .. nextExcavationId,
		Player = player,
		TreasureId = treasureId,
		Rarity = def.Rarity,
		Size = if forceSize and Finds.IsSize(forceSize)
			then forceSize :: string
			else Finds.RollVariant("Size", luck, rng:NextNumber()),
		Material = if forceMaterial and Finds.IsMaterial(forceMaterial)
			then forceMaterial :: string
			else Finds.RollVariant("Material", luck, rng:NextNumber()),
		Position = position,
		Started = os.clock(),
		Model = nil,
		Resolved = false,
	}
	excavations[player] = ex
	ex.Model = spawnModel(ex, Finds.Tier(ex.Rarity, ex.Size, ex.Material))
	local info: Types.ExcavationInfo = {
		Id = ex.Id,
		Position = position,
		Signal = Finds.Signal(ex.Rarity),
		Rings = D.RINGS,
		RingSeconds = D.RING_SECONDS,
		RingGap = D.RING_GAP,
		PerfectWindow = D.PERFECT_WINDOW,
		GoodWindow = D.GOOD_WINDOW,
		Timeout = D.EXCAVATION_TIMEOUT,
	}
	Net.FireClient("ExcavationStart", player, info)
	task.delay(D.EXCAVATION_TIMEOUT, function()
		if excavations[player] == ex and not ex.Resolved then
			DiscoveryService.Resolve(player, ex.Id, nil)
		end
	end)
	return ex.Id
end

-- Award a find to the player's data. Returns (isNew, newVariants, value).
local function award(
	player: Player,
	treasureId: string,
	size: string,
	material: string,
	quality: string
): (boolean, { string }, number)
	local data = DataService.Get(player)
	if not data then
		return false, {}, 0
	end
	local d0 = data :: Types.PlayerData
	local isNew = d0.Index[treasureId] ~= true
	local newVariants: { string } = {}
	for _, variant in { size, material } do
		if d0.FindVariants[Finds.VariantKey(treasureId, variant)] ~= true then
			table.insert(newVariants, variant)
		end
	end
	local value = Finds.Value(treasureId, size, material, quality, d0.MaxDepth)
	DataService.Mutate(player, { "Finds", "Index", "FindVariants" }, function(d)
		local key = Finds.Key(treasureId, size, material, quality)
		d.Finds[key] = (d.Finds[key] or 0) + 1
		d.Index[treasureId] = true
		d.FindVariants[Finds.VariantKey(treasureId, size)] = true
		d.FindVariants[Finds.VariantKey(treasureId, material)] = true
	end)
	return isNew, newVariants, value
end

local function afterFind(player: Player, info: Types.FindInfo)
	local rarity = Config.GetRarity(info.Rarity)
	Analytics.Funnel(player, Analytics.Steps.FirstFind)
	if rarity and rarity.Order >= 3 then
		Analytics.Funnel(player, Analytics.Steps.FirstRareFind)
	end
	if info.Perfect then
		Analytics.Funnel(player, Analytics.Steps.FirstPerfectExcavation)
	end
	Analytics.Custom(player, "Find", info.Rarity, info.Size .. "/" .. info.Material, info.Quality)
	if rarity and rarity.Announce then
		Net.NotifyAll(
			"Announce",
			string.format(
				"%s found a %s %s!",
				player.DisplayName,
				string.upper(info.Rarity),
				Finds.DisplayName(info.TreasureId, info.Size, info.Material)
			)
		)
	end
	ServerSignals.TreasureFound:Fire(player, info.TreasureId)
end

function DiscoveryService.GetExcavation(player: Player): Excavation?
	return excavations[player]
end

-- Resolve the player's excavation `id` with the client's ring timing errors (nil = no answer).
function DiscoveryService.Resolve(player: Player, id: string, errors: any): Types.FindInfo?
	local ex = excavations[player]
	if not ex or ex.Id ~= id or ex.Resolved then
		return nil
	end
	ex.Resolved = true
	excavations[player] = nil
	local score, perfects = Finds.Score(errors)
	local quality = Finds.QualityForScore(score)
	if os.clock() - ex.Started < D.MIN_EXCAVATION_SECONDS and quality == "Pristine" then
		quality = "Good" -- impossibly fast answer: no Pristine
	end
	local perfect = perfects >= D.RINGS and quality == "Pristine"
	local isNew, newVariants, value = award(player, ex.TreasureId, ex.Size, ex.Material, quality)
	local tier = Finds.Tier(ex.Rarity, ex.Size, ex.Material)
	local info: Types.FindInfo = {
		Id = ex.Id,
		TreasureId = ex.TreasureId,
		Rarity = ex.Rarity,
		Size = ex.Size,
		Material = ex.Material,
		Quality = quality,
		Value = value,
		Tier = tier,
		IsNew = isNew,
		NewVariants = newVariants,
		Perfect = perfect,
		Ambient = false,
		Position = ex.Position,
	}
	Net.FireClient("FindRevealed", player, info)
	local model = ex.Model
	if model and model.Parent then
		model:SetAttribute("Quality", quality)
		model:SetAttribute("Stage", "Revealed")
		local hold = if Finds.TierOrder(tier) >= Finds.TierOrder("Server")
			then D.SPECTACLE_SECONDS
			else D.REVEAL_SECONDS
		task.delay(hold, function()
			if model.Parent then
				model:Destroy()
			end
		end)
	end
	afterFind(player, info)
	return info
end

-- Uncover `deposit` for `player` (removes it from the hash). Returns the excavation id.
-- forceSize / forceMaterial: dev command / tests only.
function DiscoveryService.Uncover(
	player: Player,
	deposit: Deposit,
	carvedMin: Vector3?,
	carvedMax: Vector3?,
	forceSize: string?,
	forceMaterial: string?
): string?
	if excavations[player] then
		return nil
	end
	if not removeDeposit(deposit) then
		return nil
	end
	local at = emergePoint(deposit.Position, carvedMin, carvedMax)
	return startExcavation(player, deposit.TreasureId, at, forceSize, forceMaterial)
end

-- Ambient popcorn: a plain Common find from the layer, straight into Finds (no excavation).
local function ambientFind(player: Player, layerIndex: number, position: Vector3)
	local layer = Config.Layers[layerIndex]
	local commons = {}
	for _, entry in layer.LootTable do
		local def = Config.GetTreasure(entry.TreasureId)
		if def and def.Rarity == "Common" then
			table.insert(commons, def.Id)
		end
	end
	if #commons == 0 then
		return
	end
	local id = commons[rng:NextInteger(1, #commons)]
	local isNew, newVariants, value = award(player, id, "Normal", "None", "Good")
	local info: Types.FindInfo = {
		Id = "",
		TreasureId = id,
		Rarity = "Common",
		Size = "Normal",
		Material = "None",
		Quality = "Good",
		Value = value,
		Tier = "Pop",
		IsNew = isNew,
		NewVariants = newVariants,
		Perfect = false,
		Ambient = true,
		Position = position,
	}
	Net.FireClient("FindRevealed", player, info)
	afterFind(player, info)
end

local function hasEverFound(data: Types.PlayerData): boolean
	return next(data.Index) ~= nil or next(data.FindVariants) ~= nil
end

-- Only the player's own digging finds things: companion / bot digs (Pet, Digger, Ride, and any
-- Silent dig, which DigService does not even report) never uncover, roll ambient finds or pop UI.
local FINDING_SOURCES: { [string]: boolean } = { Shovel = true, Auto = true }

local function onCarved(player: Player, minV: Vector3, maxV: Vector3, source: string, layerIndex: number)
	if not FINDING_SOURCES[source] then
		return
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	sessionDigs[player] = (sessionDigs[player] or 0) + 1
	if excavations[player] then
		return -- one excavation at a time; deposits wait for the next dig
	end
	local centre = (minV + maxV) / 2
	-- nearest deposit within UNCOVER_RADIUS of the carved box
	local r = Vector3.new(D.UNCOVER_RADIUS, D.UNCOVER_RADIUS, D.UNCOVER_RADIUS)
	local best: Deposit? = nil
	local bestDistance = math.huge
	for _, chunk in chunksIn(minV - r, maxV + r) do
		for _, deposit in chunk.Deposits do
			if boxDistance(deposit.Position, minV, maxV) <= D.UNCOVER_RADIUS then
				local dist = (deposit.Position - centre).Magnitude
				if dist < bestDistance then
					best = deposit
					bestDistance = dist
				end
			end
		end
	end
	if best then
		DiscoveryService.Uncover(player, best :: Deposit, minV, maxV)
		return
	end
	-- FTUE: the first find is guaranteed early (a Common from this layer, right here). It is not
	-- an excavated deposit, so like an ambient find it records the plain Normal/None variants:
	-- a rolled variant here would read as deposit evidence for Spring Vault catch-up entry
	-- (AdventureEligibility.Rules.HasDepositEvidence) with no deposit ever dug.
	if sessionDigs[player] == D.FTUE_FIND_DIG and not hasEverFound(data :: Types.PlayerData) then
		for _, entry in Config.Layers[layerIndex].LootTable do
			local def = Config.GetTreasure(entry.TreasureId)
			if def and def.Rarity == "Common" then
				startExcavation(player, def.Id, emergePoint(centre, minV, maxV), "Normal", "None")
				return
			end
		end
	end
	local ctx = MultiplierService.GetContext(player)
	if ctx and rng:NextNumber() < Stats.GetTreasureChance(ctx :: Stats.Context, layerIndex) * D.AMBIENT_FACTOR then
		ambientFind(player, layerIndex, centre)
	end
end

-- Detector -------------------------------------------------------------------------------------------

function DiscoveryService.PingFor(player: Player): Types.DetectorPing
	local scan = scans[player]
	local remaining = if scan then math.max(0, scan.Until - os.clock()) else 0
	local root = Net.GetRoot(player)
	if not root then
		return Finds.Ping(nil, nil, remaining)
	end
	local pos = (root :: BasePart).Position
	local best: Deposit? = nil
	local bestDistance = math.huge
	if World.IsInDigZone(pos) or (pos.Y > S - 2 and World.IsInDigZone(World.ClampToDigZone(pos))) then
		local range = D.DETECTOR_RANGE
		local r = Vector3.new(range, range, range)
		for _, chunk in chunksIn(pos - r, pos + r) do
			for _, deposit in chunk.Deposits do
				local dist = (deposit.Position - pos).Magnitude
				if dist < bestDistance then
					best = deposit
					bestDistance = dist
				end
			end
		end
	end
	if not best then
		return Finds.Ping(nil, nil, remaining)
	end
	local b = best :: Deposit
	return Finds.Ping(b.Position - pos, b.Rarity, remaining)
end

local function onScan(player: Player)
	local now = os.clock()
	local scan = scans[player]
	if scan and now - scan.Started < D.SCAN_COOLDOWN then
		return
	end
	scans[player] = { Started = now, Until = now + D.SCAN_SECONDS }
	Net.FireClient("DetectorPing", player, DiscoveryService.PingFor(player))
end

local function pingTick()
	local now = os.clock()
	for player, scan in scans do
		if now >= scan.Until + D.PING_INTERVAL then
			continue
		end
		Net.FireClient("DetectorPing", player, DiscoveryService.PingFor(player))
	end
end

-- Lifecycle ------------------------------------------------------------------------------------------

function DiscoveryService.Init()
	ServerSignals.Carved:Connect(function(player: Player, minV: Vector3, maxV: Vector3, source: string, layer: number)
		local ok, err = pcall(function(): any
			onCarved(player, minV, maxV, source, layer)
			return nil
		end)
		if not ok then
			warn("[DiscoveryService] carve error: " .. tostring(err))
		end
	end)
	Net.On("Scan", onScan, { Rate = 3, Window = 1 })
	Net.On("Excavate", function(player: Player, id: any, errors: any)
		if not Net.IsString(id, 16) then
			return
		end
		if errors ~= nil and type(errors) ~= "table" then
			return
		end
		DiscoveryService.Resolve(player, id :: string, errors)
	end, { Rate = 4, Window = 1 })
end

function DiscoveryService.Start()
	task.spawn(function()
		while true do
			task.wait(D.PING_INTERVAL)
			local ok, err = pcall(function(): any
				pingTick()
				return nil
			end)
			if not ok then
				warn("[DiscoveryService] ping error: " .. tostring(err))
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(MAINTAIN_INTERVAL)
			local ok, err = pcall(function(): any
				DiscoveryService.Maintain(nil)
				return nil
			end)
			if not ok then
				warn("[DiscoveryService] maintain error: " .. tostring(err))
			end
		end
	end)
end

function DiscoveryService.OnPlayerRemoving(player: Player)
	local ex = excavations[player]
	if ex and not ex.Resolved then
		DiscoveryService.Resolve(player, ex.Id, nil) -- a find is never lost (saved as Damaged)
	end
	excavations[player] = nil
	scans[player] = nil
	sessionDigs[player] = nil
end

return DiscoveryService
