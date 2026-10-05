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
	-- v2 diggers
	"BuyDigger",
	"EquipDigger",
	"UnequipDigger",
	"UpgradeDigger",
	-- server -> client
	"DataChanged",
	"Notify",
	"DigResult",
	"TreasureFound",
	"EggHatched",
	"PlotAssigned",
	"EventChanged",
	"DiggerDug", -- server -> all clients: (player: Player, diggerId: string, position: Vector3)
})

Remotes.Functions = table.freeze({
	"GetData",
	"GetPlot",
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
