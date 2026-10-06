--!strict
--[[
	StatusService — what other players can SEE about you (v2.2 B6a / B6b, Status & Social agent).

	Nameplates are rendered on every CLIENT (NameplateController) from replicated Player
	attributes, so each viewer can turn them off ("ShowNameplates" setting) and the server sends
	no GUI. This service keeps the attributes current:
		"TitleLayer"    number  layer index of the deepest layer ever reached (PlayerData.MaxDepth,
		                        kept through rebirths) -> Config.GetTitle(index)
		"RebirthCount"  number  PlayerData.Rebirths (overhead stars)
		"BackpackFill"  number  Sand / Capacity, 0..1 in steps of 0.1 (worn pack's sand level)
	"VIP" / "Premium" are set by MonetizationService.

	Worn backpack: the equipped backpack model (Models.Backpack(id)) is welded to every
	character's UpperTorso (R15) or Torso (R6) at torso * CFrame.new(0, 0, torso.Size.Z / 2)
	(the model's Root sits on the torso's back face, see Models/Backpacks). Every part is
	unanchored, Massless, CanCollide/CanQuery/CanTouch false (never blocks digs, clicks or
	physics). Rebuilt on equip (DataService.Changed "Backpack") and on every respawn. The model is
	named "WornBackpack" and carries attribute "BackpackId".

	Public API:
		StatusService.AttachBackpack(player): Model?   (re)build the worn pack now
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Models = require(Shared.Models)
local Types = require(Shared.Types)

local DataService = require(script.Parent.DataService)

local StatusService = {}

local WORN_NAME = "WornBackpack"
local TORSO_NAMES = { "UpperTorso", "Torso" }

local function findTorso(character: Model): BasePart?
	for _, name in TORSO_NAMES do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

local function setIfChanged(player: Player, name: string, value: any)
	if player:GetAttribute(name) ~= value then
		player:SetAttribute(name, value)
	end
end

local function refreshAttributes(player: Player)
	local data = DataService.Get(player)
	if not data or player.Parent == nil then
		return
	end
	local loaded = data :: Types.PlayerData
	setIfChanged(player, "TitleLayer", Config.GetLayerIndexAtDepth(loaded.MaxDepth))
	setIfChanged(player, "RebirthCount", loaded.Rebirths)
	local capacity = player:GetAttribute("Capacity")
	local cap = if type(capacity) == "number" and capacity > 0
		then capacity
		else (Config.GetBackpack(loaded.Backpack) or Config.Backpacks[1]).Capacity
	local fill = math.clamp(math.floor(loaded.Sand / cap * 10 + 0.5) / 10, 0, 1)
	setIfChanged(player, "BackpackFill", fill)
end

function StatusService.AttachBackpack(player: Player): Model?
	local maybeCharacter = player.Character
	local data = DataService.Get(player)
	if maybeCharacter == nil or data == nil then
		return nil
	end
	local character = maybeCharacter :: Model
	local maybeTorso = findTorso(character)
	if maybeTorso == nil then
		return nil
	end
	local torso = maybeTorso :: BasePart
	local backpackId = (data :: Types.PlayerData).Backpack
	local existing = character:FindFirstChild(WORN_NAME)
	if existing and existing:GetAttribute("BackpackId") == backpackId then
		return existing :: Model
	end
	if existing then
		existing:Destroy()
	end
	local model = Models.Backpack(backpackId)
	model.Name = WORN_NAME
	model:SetAttribute("BackpackId", backpackId)
	local root = model.PrimaryPart
	if not root then
		model:Destroy()
		return nil
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.Massless = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	local offset = CFrame.new(0, 0, torso.Size.Z / 2)
	model:PivotTo(torso.CFrame * offset)
	local weld = Instance.new("Weld")
	weld.Name = "BackpackWeld"
	weld.Part0 = torso
	weld.Part1 = root
	weld.C0 = offset
	weld.C1 = CFrame.identity
	weld.Parent = root
	model.Parent = character
	return model
end

local function onCharacter(player: Player, character: Model)
	if StatusService.AttachBackpack(player) then
		return
	end
	-- the torso (or the data) may arrive after the character: retry when a torso shows up
	local connection: RBXScriptConnection? = nil
	connection = character.ChildAdded:Connect(function(child: Instance)
		if table.find(TORSO_NAMES, child.Name) and child:IsA("BasePart") then
			-- deferred: the rig may still be sizing / jointing the new part this frame
			task.defer(function()
				if StatusService.AttachBackpack(player) and connection then
					connection:Disconnect()
				end
			end)
		end
	end)
	character.Destroying:Once(function()
		if connection then
			connection:Disconnect()
		end
	end)
end

function StatusService.Init() end

function StatusService.Start()
	DataService.PlayerLoaded:Connect(function(player: Player)
		refreshAttributes(player)
		StatusService.AttachBackpack(player)
	end)
	DataService.Changed:Connect(function(player: Player, keys: { string })
		local attrs, pack = false, false
		for _, key in keys do
			if key == "MaxDepth" or key == "Rebirths" or key == "Sand" then
				attrs = true
			elseif key == "Backpack" then
				attrs = true
				pack = true
			end
		end
		if attrs then
			refreshAttributes(player)
		end
		if pack then
			StatusService.AttachBackpack(player)
		end
	end)
end

function StatusService.OnPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		onCharacter(player, character)
	end)
	if player.Character then
		onCharacter(player, player.Character)
	end
	player:GetAttributeChangedSignal("Capacity"):Connect(function()
		refreshAttributes(player)
	end)
end

return StatusService
