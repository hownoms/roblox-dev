--!strict
--[[
	PetFollowController — renders equipped pets for ALL players, client-side only.

	Source of truth per player: Player attribute "EquippedPets" (comma-separated PetDef ids),
	set by the server (requested in the client report). For the local player we fall back to
	PlayerData.Pets (Equipped = true) whenever the attribute is missing, so our own pets show
	even if the server never sets it.

	Pets trail behind the character in a little arc, bob up and down (flyers float higher),
	smoothly lerp toward their slot and face where the owner is heading. Far-away players'
	pets are hidden; LowGraphics hides other players' pets entirely.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local State = require(script.Parent.State)
local ModelFactory = require(script.Parent.Parent.Util.ModelFactory)
local Character = require(script.Parent.Parent.Util.Character)

local PetFollowController = {}

local ATTRIBUTE = "EquippedPets"
local RENDER_DISTANCE = 220
local FLYING_SHAPES = { Bird = true, Dragon = true, Star = true, Squid = true, Fish = true }

type PetVisual = {
	Id: string,
	Model: Model,
	Offset: Vector3, -- pivot -> bottom correction
	Current: CFrame?,
	Flying: boolean,
	Phase: number,
}

type Entry = {
	Key: string,
	Pets: { PetVisual },
}

local entries: { [Player]: Entry } = {}
local folder: Folder? = nil
local localUsesAttribute = false

local function getFolder(): Folder
	if not folder or not folder.Parent then
		local f = Instance.new("Folder")
		f.Name = "ClientPets"
		f.Parent = Workspace
		folder = f
	end
	return folder :: Folder
end

local function parse(value: any): { string }
	local ids = {}
	if typeof(value) == "string" then
		for id in string.gmatch(value, "[^,%s]+") do
			if Config.GetPet(id) then
				table.insert(ids, id)
			end
		end
	end
	return ids
end

local function clear(entry: Entry)
	for _, pet in entry.Pets do
		pet.Model:Destroy()
	end
	table.clear(entry.Pets)
end

local function setPets(player: Player, ids: { string })
	table.sort(ids)
	local key = table.concat(ids, ",")
	local entry = entries[player]
	if not entry then
		entry = { Key = "", Pets = {} }
		entries[player] = entry
	end
	local e = entry :: Entry
	if e.Key == key then
		return
	end
	e.Key = key
	clear(e)
	for i, id in ids do
		local def = Config.GetPet(id)
		local model = ModelFactory.Pet(id)
		ModelFactory.MakeVisualOnly(model, false)
		model.Name = player.Name .. "_" .. id
		local boxCFrame, size = model:GetBoundingBox()
		local pivot = model:GetPivot()
		local offset = Vector3.new(0, pivot.Position.Y - (boxCFrame.Position.Y - size.Y / 2), 0)
		model.Parent = getFolder()
		table.insert(e.Pets, {
			Id = id,
			Model = model,
			Offset = offset,
			Current = nil,
			Flying = def ~= nil and FLYING_SHAPES[def.Look.Shape] == true,
			Phase = i * 1.7,
		})
	end
end

local function refresh(player: Player)
	local value = player:GetAttribute(ATTRIBUTE)
	if player == Players.LocalPlayer then
		localUsesAttribute = typeof(value) == "string"
		if not localUsesAttribute then
			setPets(player, State.GetEquippedPetIds())
			return
		end
	end
	setPets(player, parse(value))
end

local function track(player: Player)
	player:GetAttributeChangedSignal(ATTRIBUTE):Connect(function()
		refresh(player)
	end)
	refresh(player)
end

-- Slot positions behind the owner: up to 3 in the first row, the rest in a second row.
local function slotOffset(index: number, count: number): Vector3
	local perRow = 3
	local row = math.floor((index - 1) / perRow)
	local inRow = math.min(perRow, count - row * perRow)
	local col = (index - 1) % perRow
	local x = (col - (inRow - 1) / 2) * 3.2
	local z = 4.5 + row * 3.2 + math.abs(x) * 0.25
	return Vector3.new(x, 0, z)
end

local function update(dt: number)
	local camera = Workspace.CurrentCamera
	local cameraPos = camera.CFrame.Position
	local low = State.GetSetting("LowGraphics", false) == true
	local now = os.clock()
	local alpha = 1 - math.exp(-dt * 9)
	for player, entry in entries do
		local root = Character.GetRoot(player)
		local visible = root ~= nil
			and (root :: BasePart).Position.Y > -400
			and ((root :: BasePart).Position - cameraPos).Magnitude < RENDER_DISTANCE
			and not (low and player ~= Players.LocalPlayer)
		for i, pet in entry.Pets do
			if not visible or not root then
				if pet.Model.Parent then
					pet.Model.Parent = nil
					pet.Current = nil
				end
				continue
			end
			if not pet.Model.Parent then
				pet.Model.Parent = getFolder()
			end
			local rootCFrame = (root :: BasePart).CFrame
			local flat =
				CFrame.lookAt(rootCFrame.Position, rootCFrame.Position + rootCFrame.LookVector * Vector3.new(1, 0, 1))
			local slot = flat:PointToWorldSpace(slotOffset(i, #entry.Pets))
			local bob = math.sin(now * 3 + pet.Phase) * 0.35
			local height = if pet.Flying then 2.2 + bob * 1.4 else -2.6 + math.max(bob, 0) * 1.2
			local target = slot + Vector3.new(0, height, 0) + pet.Offset
			local current = pet.Current or CFrame.new(target)
			local position = current.Position:Lerp(target, alpha)
			local look = flat.LookVector
			local moveDir = (target - current.Position) * Vector3.new(1, 0, 1)
			if moveDir.Magnitude > 0.4 then
				look = moveDir.Unit
			end
			local tilt = if pet.Flying then math.sin(now * 2 + pet.Phase) * 0.12 else 0
			local cf = CFrame.lookAt(position, position + look) * CFrame.Angles(0, 0, tilt)
			pet.Current = cf
			pet.Model:PivotTo(cf)
		end
	end
end

function PetFollowController.Init()
	for _, player in Players:GetPlayers() do
		task.spawn(track, player)
	end
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(function(player: Player)
		local entry = entries[player]
		if entry then
			clear(entry)
			entries[player] = nil
		end
	end)
	State.Changed("Pets"):Connect(function()
		if not localUsesAttribute then
			refresh(Players.LocalPlayer)
		end
	end)
	RunService.RenderStepped:Connect(update)
end

return PetFollowController
