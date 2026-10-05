--!strict
--[[
	DiggerController — renders every player's equipped diggers (client-side only) and plays their
	dig animations. Also hooks the map's Garage station (tag "Garage" + ProximityPrompt) to open
	the "Garage" panel.

	Source of truth per player: Player attribute "EquippedDiggers" = "id:level,id:level" (a bare
	"id" means level 1), set by DiggerService. Each digger is a Models.Digger(id) that drives along
	behind its owner (a row behind the pets), snapped to the ground under it, facing where it is
	going, with a little engine bob. On DiggerDug(player, diggerId, position, sandGained) it drives
	to the dig point, faces it and animates its moving parts (sub-Models with a "Motion" attribute,
	see Models/Diggers.luau), then a layer-coloured sand burst pops at the point. The local
	player's diggers also show a small "+N" and a soft dig sound.

	Far-away players' diggers are hidden; LowGraphics hides other players' diggers entirely.

	Public (tests): DiggerController.GetVisuals(player): { { Id: string, Level: number, Model: Model } }
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Models = require(Shared:WaitForChild("Models"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))

local State = require(script.Parent.State)
local EffectsController = require(script.Parent.EffectsController)
local SoundController = require(script.Parent.SoundController)
local Character = require(script.Parent.Parent.Util.Character)
local Panel = require(script.Parent.Parent.UI.Components.Panel)

local DiggerController = {}

local ATTRIBUTE = "EquippedDiggers"
local RENDER_DISTANCE = 220
local ROW_BEHIND = 9.5 -- studs behind the owner (pets use ~4.5-8)
local SPACING = 5 -- sideways spacing between diggers
local DIG_DURATION = 1.1 -- seconds of one dig animation
local DIG_APPROACH = 0.35 -- share of the animation spent driving to the hole
local PARK_DISTANCE = 2.6 -- digger parks this far from the dig point
local GROUND_REFRESH = 0.2
local SNAP_DISTANCE = 60
local NEAR_HEIGHT = 6 -- ground this far above / below the feet counts as "not reachable"
local NEAR_SCALE = 0.35 -- slot offset scale when tucked in close

type Joint = {
	Model: Model,
	Rest: CFrame, -- hinge pivot relative to the digger pivot
	Motion: string,
	Amount: number,
	Plunge: number,
	Spin: number,
	Posed: boolean,
}

type Action = {
	Target: Vector3,
	Start: number,
	Sand: number,
	Burst: boolean,
}

type Visual = {
	Id: string,
	Level: number,
	Model: Model,
	Joints: { Joint },
	Current: CFrame?,
	GroundY: number?,
	NextGround: number,
	Near: boolean, -- tucked in close to the owner (deep hole / steep drop)
	Phase: number,
	Action: Action?,
}

type Entry = {
	Key: string,
	Diggers: { Visual },
}

local entries: { [Player]: Entry } = {}
local folder: Folder? = nil
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater = false
local nextFilterRefresh = 0

local function getFolder(): Folder
	if not folder or not folder.Parent then
		local f = Instance.new("Folder")
		f.Name = "ClientDiggers"
		f.Parent = Workspace
		folder = f
	end
	return folder :: Folder
end

local function refreshFilter(now: number)
	if now < nextFilterRefresh then
		return
	end
	nextFilterRefresh = now + 1
	local list: { Instance } = { getFolder() }
	for _, name in { "ClientPets", "ClientEffects" } do
		local f = Workspace:FindFirstChild(name)
		if f then
			table.insert(list, f)
		end
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	groundParams.FilterDescendantsInstances = list
end

-- "id:level,id" -> { {Id, Level} } (unknown ids dropped)
local function parse(value: any): { { Id: string, Level: number } }
	local list = {}
	if typeof(value) == "string" then
		for token in string.gmatch(value, "[^,%s]+") do
			local id, level = string.match(token, "^([^:]+):?(%d*)$")
			if id and Config.GetDigger(id) then
				table.insert(list, { Id = id, Level = tonumber(level) or 1 })
			end
		end
	end
	return list
end

local function buildModel(id: string): Model
	local ok, result = pcall(Models.Digger, id)
	local model: Model
	if ok and typeof(result) == "Instance" and result:IsA("Model") then
		model = result
	else
		warn("[DiggerController] Models.Digger failed for", id, result)
		model = Instance.new("Model")
		local part = Instance.new("Part")
		part.Name = "Root"
		part.Size = Vector3.new(2, 1.5, 3)
		part.CFrame = CFrame.new(0, 0.75, 0)
		part.Color = Color3.fromRGB(255, 200, 40)
		part.Parent = model
		model.PrimaryPart = part
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	return model
end

local function collectJoints(model: Model): { Joint }
	local joints = {}
	local pivot = model:GetPivot()
	for _, d in model:GetDescendants() do
		if d:IsA("Model") and typeof(d:GetAttribute("Motion")) == "string" then
			local amount = d:GetAttribute("Amount")
			local plunge = d:GetAttribute("Plunge")
			table.insert(joints, {
				Model = d,
				Rest = pivot:ToObjectSpace(d:GetPivot()),
				Motion = d:GetAttribute("Motion") :: string,
				Amount = if typeof(amount) == "number" then amount else 0.4,
				Plunge = if typeof(plunge) == "number" then plunge else 0,
				Spin = 0,
				Posed = false,
			})
		end
	end
	return joints
end

local function clear(entry: Entry)
	for _, v in entry.Diggers do
		v.Model:Destroy()
	end
	table.clear(entry.Diggers)
end

local function setDiggers(player: Player, list: { { Id: string, Level: number } })
	local parts = {}
	for _, item in list do
		table.insert(parts, item.Id .. ":" .. item.Level)
	end
	local key = table.concat(parts, ",")
	local entry = entries[player]
	if not entry then
		entry = { Key = "", Diggers = {} }
		entries[player] = entry
	end
	local e = entry :: Entry
	if e.Key == key then
		return
	end
	e.Key = key
	-- keep existing models (and their position) for ids that stay equipped
	local old: { [string]: Visual } = {}
	for _, v in e.Diggers do
		old[v.Id] = v
	end
	local fresh: { Visual } = {}
	for i, item in list do
		local v = old[item.Id]
		if v then
			old[item.Id] = nil
			v.Level = item.Level
		else
			local model = buildModel(item.Id)
			model.Name = player.Name .. "_" .. item.Id
			v = {
				Id = item.Id,
				Level = item.Level,
				Model = model,
				Joints = collectJoints(model),
				Current = nil,
				GroundY = nil,
				NextGround = 0,
				Near = false,
				Phase = i * 2.1,
				Action = nil,
			}
		end
		table.insert(fresh, v :: Visual)
	end
	for _, v in old do
		v.Model:Destroy()
	end
	e.Diggers = fresh
end

local function refresh(player: Player)
	setDiggers(player, parse(player:GetAttribute(ATTRIBUTE)))
end

local function track(player: Player)
	player:GetAttributeChangedSignal(ATTRIBUTE):Connect(function()
		refresh(player)
	end)
	refresh(player)
end

-- Animation ----------------------------------------------------------------------------------

local function slotOffset(index: number, count: number): Vector3
	local x = (index - (count + 1) / 2) * SPACING
	return Vector3.new(x, 0, ROW_BEHIND + math.abs(x) * 0.15)
end

local function groundBelow(position: Vector3): number?
	local hit = Workspace:Raycast(position + Vector3.new(0, 8, 0), Vector3.new(0, -40, 0), groundParams)
	return if hit then hit.Position.Y else nil
end

local function layerColor(position: Vector3): Color3
	return Config.GetLayerAtDepth(Config.SURFACE_Y - position.Y).Color
end

local function poseJoints(v: Visual, pivot: CFrame, digAlpha: number, dt: number)
	for _, j in v.Joints do
		local active = digAlpha > 0 or j.Motion == "Spin" or j.Motion == "Drill"
		if not active and not j.Posed then
			continue
		end
		local base = pivot * j.Rest
		local wave = math.sin(math.pi * digAlpha)
		local pose = base
		if j.Motion == "Swing" then
			pose = base * CFrame.Angles(j.Amount * wave, 0, 0)
		elseif j.Motion == "Tip" then
			pose = base * CFrame.Angles(j.Amount * wave * wave, 0, 0)
		elseif j.Motion == "Spin" or j.Motion == "Drill" then
			-- idle drills turn slowly, digging drills spin fast
			j.Spin = (j.Spin + dt * j.Amount * (if digAlpha > 0 then 1 else 0.06)) % (math.pi * 2)
			pose = base * CFrame.new(0, j.Plunge * wave, 0) * CFrame.Angles(0, j.Spin, 0)
		end
		j.Model:PivotTo(pose)
		j.Posed = active
	end
end

local function onDug(owner: Player, action: Action)
	local color = layerColor(action.Target)
	local mine = owner == Players.LocalPlayer
	EffectsController.Burst(action.Target, color, if mine then 12 else 6, 0.8)
	if mine then
		EffectsController.Chunks(action.Target, color, 4)
		if action.Sand > 0 then
			EffectsController.FloatText(
				action.Target + Vector3.new(0, 2, 0),
				"+" .. Format.Abbreviate(action.Sand),
				Color3.fromRGB(255, 225, 140),
				0.75
			)
		end
		SoundController.Play("Dig", 0.7 + math.random() * 0.15, 0.35)
	end
end

local function update(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPos = camera.CFrame.Position
	local low = State.GetSetting("LowGraphics", false) == true
	local now = os.clock()
	refreshFilter(now)
	for player, entry in entries do
		local root = Character.GetRoot(player)
		local visible = root ~= nil
			and (root :: BasePart).Position.Y > -400
			and ((root :: BasePart).Position - cameraPos).Magnitude < RENDER_DISTANCE
			and not (low and player ~= Players.LocalPlayer)
		for i, v in entry.Diggers do
			if not visible or not root then
				if v.Model.Parent then
					v.Model.Parent = nil
				end
				v.Current = nil
				v.Action = nil
				continue
			end
			if not v.Model.Parent then
				v.Model.Parent = getFolder()
			end
			local rootCFrame = (root :: BasePart).CFrame
			local flatLook = rootCFrame.LookVector * Vector3.new(1, 0, 1)
			if flatLook.Magnitude < 0.01 then
				flatLook = Vector3.new(0, 0, -1)
			end
			local flat = CFrame.lookAt(rootCFrame.Position, rootCFrame.Position + flatLook)
			local feetY = rootCFrame.Position.Y - 3

			local current = v.Current
			local target: Vector3
			local facing: Vector3? = nil
			local digAlpha = 0
			local speed = 5
			local action = v.Action
			if action then
				local t = (now - action.Start) / DIG_DURATION
				if t >= 1 then
					v.Action = nil
					action = nil
				else
					local from = if current then current.Position else action.Target
					local away = (from - action.Target) * Vector3.new(1, 0, 1)
					if away.Magnitude < 0.1 then
						away = -flatLook
					end
					target = action.Target + away.Unit * PARK_DISTANCE
					target = Vector3.new(target.X, action.Target.Y, target.Z)
					facing = (action.Target - target) * Vector3.new(1, 0, 1)
					speed = 10
					if t > DIG_APPROACH then
						digAlpha = (t - DIG_APPROACH) / (1 - DIG_APPROACH)
						if not action.Burst and digAlpha >= 0.45 then
							action.Burst = true
							onDug(player, action)
						end
					end
				end
			end
			if not action then
				local offset = slotOffset(i, #entry.Diggers)
				if v.Near then
					offset *= NEAR_SCALE
				end
				local slot = flat:PointToWorldSpace(offset)
				if now >= v.NextGround or v.GroundY == nil then
					v.NextGround = now + GROUND_REFRESH + math.random() * 0.05
					-- Behind the owner is solid wall (deep in a hole) or a big drop: tuck in close
					-- at the owner's level instead of vanishing into the terrain.
					local far = groundBelow(flat:PointToWorldSpace(slotOffset(i, #entry.Diggers)))
					v.Near = far == nil or math.abs((far :: number) - feetY) > NEAR_HEIGHT
					if v.Near then
						v.GroundY = groundBelow(flat:PointToWorldSpace(offset * NEAR_SCALE)) or feetY
					else
						v.GroundY = far
					end
				end
				target = Vector3.new(slot.X, v.GroundY or feetY, slot.Z)
			end

			local position: Vector3
			if not current or (current.Position - target).Magnitude > SNAP_DISTANCE then
				position = target
			else
				local alpha = 1 - math.exp(-dt * speed)
				position = current.Position:Lerp(target, alpha)
			end
			local look = if current then current.LookVector else flatLook
			local moved = if current then (position - current.Position) * Vector3.new(1, 0, 1) else Vector3.zero
			if facing and facing.Magnitude > 0.05 then
				look = facing.Unit
			elseif moved.Magnitude > dt * 1.5 then
				look = moved.Unit
			end
			-- turn smoothly instead of snapping
			local flatCurrent = look * Vector3.new(1, 0, 1)
			if current then
				local prev = current.LookVector * Vector3.new(1, 0, 1)
				if prev.Magnitude > 0.01 and flatCurrent.Magnitude > 0.01 then
					flatCurrent = prev.Unit:Lerp(flatCurrent.Unit, 1 - math.exp(-dt * 8))
				end
			end
			if flatCurrent.Magnitude < 0.01 then
				flatCurrent = flatLook
			end
			local driving = math.clamp(moved.Magnitude / math.max(dt, 1e-3) / 16, 0, 1)
			local bob = math.abs(math.sin(now * 9 + v.Phase)) * (0.04 + 0.12 * driving)
			local rumble = if digAlpha > 0 then math.sin(now * 40) * 0.03 else 0
			local pivot = CFrame.lookAt(position, position + flatCurrent.Unit)
			v.Current = pivot
			local shown = pivot * CFrame.new(0, bob + rumble, 0) * CFrame.Angles(-driving * 0.04, 0, 0)
			v.Model:PivotTo(shown)
			poseJoints(v, shown, digAlpha, dt)
		end
	end
end

-- Garage station -------------------------------------------------------------------------------

local hooked: { [ProximityPrompt]: boolean } = {}

local function hookPrompt(prompt: ProximityPrompt)
	if hooked[prompt] then
		return
	end
	hooked[prompt] = true
	prompt.Triggered:Connect(function()
		Panel.Open("Garage")
	end)
	prompt.Destroying:Connect(function()
		hooked[prompt] = nil
	end)
end

local function hookGarage(inst: Instance)
	if inst:IsA("ProximityPrompt") then
		hookPrompt(inst)
		return
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			hookPrompt(d)
		end
	end
	inst.DescendantAdded:Connect(function(d: Instance)
		if d:IsA("ProximityPrompt") then
			hookPrompt(d)
		end
	end)
end

-- Public ------------------------------------------------------------------------------------------

function DiggerController.GetVisuals(player: Player): { { Id: string, Level: number, Model: Model } }
	local list = {}
	local entry = entries[player]
	if entry then
		for _, v in entry.Diggers do
			table.insert(list, { Id = v.Id, Level = v.Level, Model = v.Model })
		end
	end
	return list
end

function DiggerController.Init()
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

	task.spawn(function()
		Remotes.Get("DiggerDug").OnClientEvent:Connect(function(player: any, diggerId: any, position: any, sand: any)
			if
				typeof(player) ~= "Instance"
				or not (player :: Instance):IsA("Player")
				or typeof(diggerId) ~= "string"
				or typeof(position) ~= "Vector3"
			then
				return
			end
			local entry = entries[player :: Player]
			if not entry then
				return
			end
			for _, v in (entry :: Entry).Diggers do
				if v.Id == diggerId then
					v.Action = {
						Target = position,
						Start = os.clock(),
						Sand = if typeof(sand) == "number" then sand else 0,
						Burst = false,
					}
					-- not rendered (far away / hidden): skip the animation entirely
					if not v.Model.Parent then
						v.Action = nil
					end
					break
				end
			end
		end)
	end)

	for _, inst in CollectionService:GetTagged("Garage") do
		task.spawn(hookGarage, inst)
	end
	CollectionService:GetInstanceAddedSignal("Garage"):Connect(hookGarage)

	RunService.RenderStepped:Connect(update)
end

return DiggerController
