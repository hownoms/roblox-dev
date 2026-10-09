--!strict
-- Single source of truth for network endpoints. The server creates them on first access;
-- clients wait for them. Names must match docs/ARCHITECTURE.md.
local RunService = game:GetService("RunService")

local Remotes = {}

Remotes.Events = table.freeze({
	-- client -> server
	"Dig",
	"ReturnToSurface",
	"BuyShovel",
	"EquipShovel",
	"BuyBackpack",
	"EquipBackpack",
	"HatchEgg",
	"EquipPet",
	"UnequipPet",
	"DeletePet",
	"Rebirth",
	"ClaimDailyReward",
	"ClaimQuest",
	"RedeemCode",
	"SetSetting",
	"PromptPurchase",
	-- v2 survival
	"BuyShade",
	"PlaceShade", -- (shadeId: string, position: Vector3, yaw: number)
	"PickUpShade",
	"BuyConsumable", -- (id: string, count: number)
	"UseConsumable", -- (id: string)
	"DrinkFountain",
	-- v2.1 ride-on excavator (RideService)
	"ToggleRide", -- () spawn + sit in your rideable pet, or get out
	"RideDig", -- () scoop in front of your vehicle (server picks the point)
	-- v2.2 duplicate fusion: (uid: string) fuse Config.GOLDEN_FUSE_COUNT copies into a Golden pet
	"FusePets",
	-- v2.2 analytics: (name: string, a: any?, b: any?) whitelisted UI events (Analytics.OnTrack)
	"Track",
	-- v2.2 rebirth perks: (perkId: string) buy the next level with Rebirth Tokens (RebirthService)
	"BuyRebirthPerk",
	-- v3 discovery (DiscoveryService): () start a detector scan; (id: string, errors: {number})
	-- answer an excavation with per-ring timing errors in seconds (-1 = no tap)
	"Scan",
	"Excavate",
	-- expansion trophies (TrophyService): (trophyId: string, x: number, z: number, rot: number)
	-- place an owned trophy on a camp grid cell; (placementId: number) remove that display
	"PlaceCampItem",
	"RemoveCampItem",
	-- server -> client
	"DataChanged",
	"Notify",
	"DigResult",
	"TreasureFound",
	"EggHatched", -- (petIds: {string}, info: { EggId, Chances: {number}, Pity: {boolean} }?) v2.2 info
	"EventChanged",
	-- v2.2 offline earnings (OfflineService): (info: { Seconds, Sand, Coins, CapSeconds, Capped, PetId })
	"OfflineEarnings",
	-- v2.1 companions: a digging pet dug. server -> all clients:
	-- (player: Player, slot: number, petId: string, position: Vector3, sandGained: number)
	-- slot = 1-based index into the owner's "EquippedPets" attribute list.
	"PetDug",
	"Scoop", -- server -> other clients: (player: Player) a successful shovel dig (scoop animation)
	"RideDug", -- server -> all clients: (player: Player, position: Vector3, success: boolean, layerIndex: number)
	-- v3 discovery, server -> owner: Types.DetectorPing / Types.ExcavationInfo / Types.FindInfo
	"DetectorPing",
	"ExcavationStart",
	"FindRevealed",
	-- expansion adventure settlement (AdventureSettlement), server -> owner: (outcome:
	-- { InstanceId, Kind, StageId?, State = "Accepted" | "Pending" | "Refused", Status, Coins,
	-- Trophy, Stand, Certification?, Reason?, Resolved? }) one per stage/final, plus a Resolved
	-- follow-up when a Pending outcome later becomes Accepted
	"AdventureOutcome",
})

Remotes.Functions = table.freeze({
	"GetData",
	"GetOwnedPasses",
})

local FOLDER_NAME = "Net"
local isServer = RunService:IsServer()

local function getFolder(): Folder
	local existing = script:FindFirstChild(FOLDER_NAME)
	if existing then
		return existing :: Folder
	end
	if isServer then
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = script
		return folder
	end
	return script:WaitForChild(FOLDER_NAME) :: Folder
end

local function getOrCreate(name: string, className: string): Instance
	local folder = getFolder()
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing
	end
	if isServer then
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name)
end

function Remotes.Get(name: string): RemoteEvent
	assert(table.find(Remotes.Events, name), "Unknown RemoteEvent: " .. name)
	return getOrCreate(name, "RemoteEvent") :: RemoteEvent
end

function Remotes.GetFunction(name: string): RemoteFunction
	assert(table.find(Remotes.Functions, name), "Unknown RemoteFunction: " .. name)
	return getOrCreate(name, "RemoteFunction") :: RemoteFunction
end

-- Server calls this once at boot so every remote exists before clients look for them.
function Remotes.CreateAll()
	assert(isServer, "Remotes.CreateAll is server-only")
	for _, name in Remotes.Events do
		Remotes.Get(name)
	end
	for _, name in Remotes.Functions do
		Remotes.GetFunction(name)
	end
end

return Remotes
