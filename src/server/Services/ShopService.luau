--!strict
--[[
	ShopService — shovels & backpacks.

	Rules (GDD §4): any shovel/backpack can be bought once the player has the coins and
	RebirthsRequired; tiers may be skipped (no "must own previous" rule — after a rebirth coins
	reset anyway, so skipping only matters for rich players and costs them more). Buying equips.
	Equipping requires ownership.

	The equipped shovel is given as a Tool built from Models.Shovel(id): the model's PrimaryPart
	becomes "Handle", every part is unanchored, non-colliding, massless and welded to the handle.
	If the model carries a CFrame attribute "Grip" it is used as Tool.Grip. The tool is re-given on
	every respawn (no StarterGear needed) and the old one is removed on equip. Tools carry the
	attributes "ShovelId" and "TwoHanded" (full-size shovel, posed with both hands on clients).
	Every successful Shovel/Auto dig fires "Scoop"(player) to the other clients (animation only).

	Public API:
		ShopService.GiveShovelTool(player)
		ShopService.Buy(player, kind, id) / ShopService.Equip(player, kind, id)  (kind = "Shovel" | "Backpack")
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Format = require(Shared.Util.Format)
local Models = require(Shared.Models)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)
local ServerSignals = require(script.Parent.ServerSignals)

export type ItemKind = "Shovel" | "Backpack"

type ItemDef = {
	Id: string,
	Name: string,
	Price: number,
	RebirthsRequired: number,
}

local ShopService = {}

local function getDef(kind: ItemKind, id: string): ItemDef?
	if kind == "Shovel" then
		return Config.GetShovel(id)
	end
	return Config.GetBackpack(id)
end

local function ownedKey(kind: ItemKind): string
	return if kind == "Shovel" then "OwnedShovels" else "OwnedBackpacks"
end

-- Tool ------------------------------------------------------------------------------------------

local function buildTool(shovelId: string): Tool?
	local def = Config.GetShovel(shovelId)
	if not def then
		return nil
	end
	assert(def) -- refine for the type checker (guarded above)
	local ok, model = pcall(Models.Shovel, shovelId)
	if not ok or typeof(model) ~= "Instance" or not (model :: Instance):IsA("Model") then
		warn("[ShopService] Models.Shovel failed for " .. shovelId .. ": " .. tostring(model))
		return nil
	end
	assert(ok) -- refine for the type checker (guarded above)
	local shovelModel = model :: Model

	local tool = Instance.new("Tool")
	tool.Name = def.Name
	tool.ToolTip = def.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("ShovelId", shovelId)

	local handle = shovelModel.PrimaryPart or shovelModel:FindFirstChildWhichIsA("BasePart", true)
	if not handle then
		local part = Instance.new("Part")
		part.Size = Vector3.new(0.4, 4, 0.4)
		part.Color = def.Look.HandleColor
		handle = part
	end
	local handlePart = handle :: BasePart

	for _, descendant in shovelModel:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			if descendant ~= handlePart then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = handlePart
				weld.Part1 = descendant
				weld.Parent = handlePart
			end
		end
	end
	handlePart.Anchored = false
	handlePart.CanCollide = false
	handlePart.Massless = true

	-- Models.Shovel stores the grip on the Handle as "GripOffset"; "Grip" on the model also works.
	local grip = handlePart:GetAttribute("GripOffset") or shovelModel:GetAttribute("Grip")
	if typeof(grip) == "CFrame" then
		tool.Grip = grip
	end
	-- Full-size shovels are posed with both hands by the client ShovelPoseController.
	tool:SetAttribute("TwoHanded", handlePart:GetAttribute("TwoHanded") == true)

	handlePart.Name = "Handle"
	handlePart.Parent = tool
	shovelModel.PrimaryPart = nil
	shovelModel.Name = "Look"
	shovelModel.Parent = tool
	return tool
end

local function removeShovelTools(container: Instance?)
	if not container then
		return
	end
	assert(container) -- refine for the type checker (guarded above)
	for _, child in container:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("ShovelId") ~= nil then
			child:Destroy()
		end
	end
end

function ShopService.GiveShovelTool(player: Player)
	local data = DataService.Get(player)
	if not data or player.Parent == nil then
		return
	end
	assert(data) -- refine for the type checker (guarded above)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	local wasEquipped = false
	if character then
		for _, child in character:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("ShovelId") ~= nil then
				wasEquipped = true
			end
		end
	end
	removeShovelTools(backpack)
	removeShovelTools(character)

	local tool = buildTool(data.Shovel)
	if not tool or not backpack then
		if tool then
			tool:Destroy()
		end
		return
	end
	assert(tool) -- refine for the type checker (guarded above)
	assert(backpack) -- refine for the type checker (guarded above)
	tool.Parent = backpack

	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and (wasEquipped or humanoid:GetAttribute("ShovelAutoEquipped") ~= true) then
		humanoid:SetAttribute("ShovelAutoEquipped", true)
		humanoid:EquipTool(tool)
	end
end

-- Purchases -------------------------------------------------------------------------------------

function ShopService.Equip(player: Player, kind: ItemKind, id: string): boolean
	local data = DataService.Get(player)
	local def = getDef(kind, id)
	if not data or not def then
		return false
	end
	assert(data) -- refine for the type checker (guarded above)
	assert(def) -- refine for the type checker (guarded above)
	local owned = (data :: any)[ownedKey(kind)] :: { [string]: boolean }
	if not owned[id] then
		Net.Notify(player, "Error", "You don't own that yet!")
		return false
	end
	local current = if kind == "Shovel" then data.Shovel else data.Backpack
	if current == id then
		return true
	end
	DataService.Set(player, kind, id)
	if kind == "Shovel" then
		ShopService.GiveShovelTool(player)
	end
	Net.Notify(player, "Success", def.Name .. " equipped!")
	return true
end

function ShopService.Buy(player: Player, kind: ItemKind, id: string): boolean
	local data = DataService.Get(player)
	local def = getDef(kind, id)
	if not data or not def then
		return false
	end
	assert(data) -- refine for the type checker (guarded above)
	assert(def) -- refine for the type checker (guarded above)
	local key = ownedKey(kind)
	local owned = (data :: any)[key] :: { [string]: boolean }
	if owned[id] then
		return ShopService.Equip(player, kind, id)
	end
	if data.Rebirths < def.RebirthsRequired then
		Net.Notify(player, "Error", string.format("Needs %d rebirths!", def.RebirthsRequired))
		return false
	end
	if data.Coins < def.Price then
		Net.Notify(player, "Error", "Not enough coins! Need " .. Format.Abbreviate(def.Price - data.Coins) .. " more.")
		return false
	end

	DataService.Mutate(player, { "Coins", key, kind }, function(d)
		d.Coins -= def.Price
		owned[id] = true
		if kind == "Shovel" then
			d.Shovel = id
		else
			d.Backpack = id
		end
	end)
	if kind == "Shovel" then
		ShopService.GiveShovelTool(player)
		Analytics.Funnel(player, Analytics.Steps.FirstShovel)
	end
	if def.Price > 0 then
		Analytics.Sink(
			player,
			"Coins",
			def.Price,
			data.Coins,
			Enum.AnalyticsEconomyTransactionType.Shop,
			kind .. ":" .. id
		)
	end
	Net.Notify(player, "Success", "You got the " .. def.Name .. "!")
	ServerSignals.UpgradeBought:Fire(player, kind, id)
	return true
end

-- Lifecycle -------------------------------------------------------------------------------------

local function idHandler(kind: ItemKind, buy: boolean): (Player, any) -> ()
	return function(player: Player, id: any)
		if not Net.IsString(id, 64) then
			return
		end
		if buy then
			ShopService.Buy(player, kind, id)
		else
			ShopService.Equip(player, kind, id)
		end
	end
end

function ShopService.Init()
	Net.On("BuyShovel", idHandler("Shovel", true), { Rate = 4, Window = 1 })
	Net.On("EquipShovel", idHandler("Shovel", false), { Rate = 4, Window = 1 })
	Net.On("BuyBackpack", idHandler("Backpack", true), { Rate = 4, Window = 1 })
	Net.On("EquipBackpack", idHandler("Backpack", false), { Rate = 4, Window = 1 })
end

function ShopService.Start()
	DataService.PlayerLoaded:Connect(function(player: Player)
		if player.Character then
			ShopService.GiveShovelTool(player)
		end
	end)
	-- Scoop broadcast: every successful shovel dig plays the scoop animation on that character
	-- for everyone else (the digger's own client already played it on click). Server AutoDig
	-- digs have no click, so those go to the digger too. Pet/digger/ride digs never scoop.
	ServerSignals.Dug:Connect(function(player: Player, _depth: number, _gained: number, source: string)
		if source ~= "Shovel" and source ~= "Auto" then
			return
		end
		for _, other in Players:GetPlayers() do
			if other ~= player or source == "Auto" then
				Net.FireClient("Scoop", other, player)
			end
		end
	end)
end

function ShopService.OnPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		-- Wait for the Backpack/Humanoid of the new character before giving the tool.
		character:WaitForChild("Humanoid", 5)
		player:WaitForChild("Backpack", 5)
		if character.Parent and DataService.IsLoaded(player) then
			ShopService.GiveShovelTool(player)
		end
	end)
end

return ShopService
