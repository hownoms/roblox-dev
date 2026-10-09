--!strict
-- Isolated protected review arena. Geometry describes objectives; service validates every action.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Kit = require(ReplicatedStorage.Shared.Models.Expansion1)
local Build = require(ReplicatedStorage.Shared.Models.Build)
local BallVisual = require(ReplicatedStorage.Shared.Adventure.BeachBallVisual)
local Scene = {}
local V = Vector3.new

local function protect(instance: Instance)
	instance:SetAttribute("ProtectedGeometry", true)
	instance:SetAttribute("RegionId", "sunshine_shore")
	CollectionService:AddTag(instance, "ProtectedGeometry")
	for _, child in instance:GetDescendants() do
		if child:IsA("BasePart") then
			child.Anchored = true
			if not child.CanCollide and child.Name ~= "ContactSphere" then
				child.CanQuery = false
			end
			child:SetAttribute("ProtectedGeometry", true)
			CollectionService:AddTag(child, "ProtectedGeometry")
		end
	end
end

local function prompt(part: BasePart, action: string, id: string, label: string)
	part:SetAttribute("AdventureAction", action)
	part:SetAttribute("TargetId", id)
	local p = Instance.new("ProximityPrompt")
	p.Name = "AdventurePrompt"
	p.Enabled = false
	p.ActionText = label
	local names: { [string]: string } = {
		npc_mara = "Mara",
		npc_pip = "Pip",
		vault_latch = "Spring Vault",
		ball = "Spring Ball",
		ball_reset = "Safe Checkpoint",
		route_left = "Left Channel",
		route_right = "Right Channel",
		adventure_exit = "Return",
	}
	p.ObjectText = names[id]
		or (
			if string.find(id, "vault_anchor_")
				then ({ "Triangle Anchor", "Square Anchor", "Circle Anchor" })[tonumber(string.sub(id, -1)) or 1]
				else "Practice Target"
		)
	p.MaxActivationDistance = if action == "Talk" then 10 else 12
	p.RequiresLineOfSight = false
	p.HoldDuration = 0
	p.Parent = part
end

function Scene.Build(parent: Instance, origin: Vector3?, reviewSpawn: boolean?)
	local base = origin or V(700, 20, 0)
	local model = Instance.new("Model")
	model.Name = "SpringVaultAdventure"
	-- Stream the protected pocket and its objective prompts together. Clients
	-- must not bind an incomplete set of anchors/routes during streaming.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("EventId", "event_vault")
	model.Parent = parent
	local function point(x: number, y: number, z: number): Vector3
		return base + V(x, y, z)
	end
	local function part(name: string, size: Vector3, position: Vector3, color: Color3, solid: boolean?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Position = position
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = solid == true
		p.CanTouch = false
		p.CanQuery = solid == true
		p.Parent = model
		protect(p)
		return p
	end
	part("ProtectedArenaFloor", V(100, 2, 140), point(0, -1, -36), Kit.Palette.Sand, true)
	-- Production never creates a neutral spawn; only dedicated review opts in.
	if reviewSpawn == true then
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "AdventureReviewSpawn"
		spawn.Size = V(6, 1, 6)
		-- Arrive within Mara's talking range and face into the adventure.
		spawn.CFrame = CFrame.lookAt(point(-12, 0.5, 19), point(0, 0.5, -4))
		spawn.Anchored = true
		spawn.CanCollide = true
		spawn.CanTouch = false
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Color = Kit.Palette.Cream
		spawn.Parent = model
		protect(spawn)
	end
	part("LeftBoundary", V(2, 8, 140), point(-49, 4, -36), Kit.Palette.Navy, true)
	part("RightBoundary", V(2, 8, 140), point(49, 4, -36), Kit.Palette.Navy, true)
	part("FarBoundary", V(100, 8, 2), point(0, 4, -105), Kit.Palette.Navy, true)
	part("NearBoundary", V(100, 8, 2), point(0, 4, 33), Kit.Palette.Navy, true)
	-- Low channel curbs leave wide avatar walkways; no enclosed or mutable tunnel supports.
	for _, x in { -18, 18 } do
		part("ChannelCurb", V(1, 1.5, 75), point(x, 0.75, -54), Kit.Palette.Blue, true)
	end
	local targets: { [string]: Vector3 } = {}
	local exit = part("AdventureExit", V(4, 0.3, 4), point(0, 0.15, 29), Kit.Palette.Cream)
	targets.adventure_exit = exit.Position
	prompt(exit, "Leave", "adventure_exit", "Leave adventure")
	local npcs: { [string]: Model } = {}
	local npcOffsets: { [string]: Vector3 } = { npc_mara = V(-20, 0, 15), npc_pip = V(20, 0, 15) }
	for id, offset in npcOffsets do
		local npc = Kit.NPC(id, "Point")
		npc:PivotTo(CFrame.new(base + offset) * CFrame.Angles(0, math.pi, 0))
		npc.Parent = model
		protect(npc)
		local nameplate = Instance.new("BillboardGui")
		nameplate.Name = "AdventureHostLabel"
		nameplate.Size = UDim2.fromOffset(140, 44)
		nameplate.StudsOffset = V(0, 6.5, 0)
		nameplate.MaxDistance = 35
		nameplate.AlwaysOnTop = false
		nameplate.Parent = npc.PrimaryPart
		local title = Instance.new("TextLabel")
		title.Size = UDim2.fromScale(1, 1)
		title.BackgroundColor3 = Kit.Palette.Navy
		title.BackgroundTransparency = 0.15
		title.TextColor3 = Kit.Palette.Cream
		title.TextSize = 14
		title.Text = if id == "npc_mara" then "Mara · Join rescue" else "Pip · Try Broadwave"
		title.Parent = nameplate
		npcs[id] = npc
		targets[id] = base + offset
		prompt(
			npc.PrimaryPart :: BasePart,
			"Talk",
			id,
			if id == "npc_mara" then "Join / adventure" else "Broadwave trial"
		)
	end
	local displayTool = Kit.Broadwave()
	displayTool:PivotTo(CFrame.new(point(24, 3, 15)) * CFrame.Angles(0, 0, math.pi))
	displayTool.Parent = model
	protect(displayTool)
	local trialFrame = CFrame.new(point(20, 0, 2))
	targets.trial_patch = point(20, 0, -2)
	part("MarkedTrialPatch", V(12, 0.15, 8), point(20, 0.08, -2), Kit.Palette.Navy)
	local trialTargets: { Vector3 } = {}
	for i = 1, 3 do
		local id = "trial_target_" .. i
		local pos = point(20 + (i - 2) * 3, 1, -2)
		trialTargets[i] = pos
		targets[id] = pos
		local p = part(id, V(2, 2, 2), pos, Kit.Palette.Cream)
		prompt(p, "Excavate", id, "Practice scoop")
	end
	local vaultPosition = point(0, 0, -4)
	-- The kit's front is -Z; face its latch and shapes toward lobby arrivals.
	local vaultFrame = CFrame.new(vaultPosition) * CFrame.Angles(0, math.pi, 0)
	local vault = Kit.SpringVault("Covered")
	vault:PivotTo(vaultFrame)
	vault.Parent = model
	protect(vault)
	local anchors: { [string]: Model } = {}
	for i = 1, 3 do
		local id = "vault_anchor_" .. i
		local anchor = vault:FindFirstChild(id) :: Model
		anchors[id] = anchor
		local anchorBase = anchor:FindFirstChild("AnchorBase") :: BasePart
		targets[id] = anchorBase.Position
		prompt(anchorBase, "Excavate", id, "Clear anchor " .. i)
	end
	local latch = vault:FindFirstChild("Latch") :: BasePart
	targets.vault_latch = latch.Position
	prompt(latch, "OpenVault", "vault_latch", "Open Spring Vault")
	for _, side in { "Left", "Right" } do
		local id = "route_" .. string.lower(side)
		local direction = if side == "Left" then -1 else 1
		local color = if side == "Left" then Kit.Palette.Blue else Kit.Palette.Coral
		local choice = part(id, V(3, 0.15, 3), point(direction * 10, 0.08, -10), color)
		targets[id] = choice.Position
		prompt(choice, "Route" .. side, id, "Choose " .. string.lower(side) .. " channel")
		-- A flat chevron and sparse lane dashes show where each choice leads.
		-- These are presentation only: no collider or change to validated routes.
		for _, arm in { -1, 1 } do
			local arrow = part(
				"RouteArrow" .. side,
				V(0.2, 0.05, 1.2),
				point(direction * 10 + arm * 0.38, 0.18, -10),
				Kit.Palette.Navy
			)
			arrow.CFrame *= CFrame.Angles(0, arm * math.pi / 4, 0)
		end
		for _, z in { -23, -29, -42, -48, -54, -66, -72, -78, -90 } do
			part("RouteDash" .. side, V(0.3, 0.05, 2), point(direction * 8, 0.04, z), color)
		end
	end
	local ballStart = point(0, 3.8, -17)
	local gates = {}
	for i, z in { -36, -60, -84 } do
		local position = point(0, 3.8, z)
		gates[i] = { Id = "ball_gate_" .. i, Position = position, Radius = 13, WaypointIndex = i + 2 }
		for _, x in { -15, 15 } do
			part("GatePost" .. i, V(0.8, 10, 0.8), point(x, 5, z), Kit.Palette.Navy, true)
		end
		part("GateTop" .. i, V(31, 0.8, 0.8), point(0, 10, z), Kit.Palette.Cream)
		local marker = part("GateMarker" .. i, V(3, 2, 0.2), point(0, 10, z + 0.5), Kit.Palette.Blue)
		-- Shape matches the corresponding vault anchor; number/color are supplementary cues.
		local shapeFrame = CFrame.new(point(0, 10, z + 0.65))
		if i == 1 then
			Build.tri(model, "GateTriangle", shapeFrame, 1.35, 1.35, 0.1, Kit.Palette.Cream)
		elseif i == 2 then
			part("GateSquare", V(1.35, 1.35, 0.1), point(0, 10, z + 0.65), Kit.Palette.Cream)
		else
			Build.ellipsoid(model, "GateCircle", V(1.4, 1.4, 0.1), shapeFrame, Kit.Palette.Cream)
		end
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(100, 45)
		gui.AlwaysOnTop = false
		gui.MaxDistance = 40
		gui.Parent = marker
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		gui.StudsOffset = V(0, 2, 0)
		label.Text = "GATE " .. i
		label.TextColor3 = Kit.Palette.Navy
		label.TextScaled = true
		label.Parent = gui
	end
	local routes: { [string]: { Vector3 } } = {}
	for _, route in { "Left", "Right" } do
		local side = if route == "Left" then -1 else 1
		routes[route] = {
			ballStart,
			point(side * 8, 3.8, -25),
			point(side * 8, 3.8, -36),
			point(side * 8, 3.8, -60),
			point(side * 8, 3.8, -84),
			point(0, 3.8, -94),
		}
	end
	local reset = part("BallReset", V(3, 1, 3), point(-23, 0.5, -19), Kit.Palette.Coral)
	targets.ball_reset = reset.Position
	prompt(reset, "ResetBall", "ball_reset", "Return ball to checkpoint")
	local ball: Model? = nil
	local api = {
		Model = model,
		Origin = base,
		NPCs = npcs,
		Targets = targets,
		TrialTargets = trialTargets,
		TrialFrame = trialFrame,
		Anchors = anchors,
		Vault = vault,
		Gates = gates,
		Routes = routes,
		BallStart = ballStart,
		Checkpoints = { ballStart, gates[1].Position, gates[2].Position, gates[3].Position },
		Lobby = point(0, 3, 20),
		Exit = point(0, 3, 29),
	}
	function api.SetAnchorProgress(id: string, progress: number)
		local anchor = anchors[id]
		if anchor then
			Kit.SetAnchorProgress(anchor, progress)
		end
	end
	function api.OpenVault()
		local replacement = Kit.SpringVault("Opened")
		replacement:PivotTo(vaultFrame)
		replacement.Parent = model
		protect(replacement)
		vault:Destroy()
		vault = replacement
		api.Vault = replacement
		for id in anchors do
			anchors[id] = replacement:FindFirstChild(id) :: Model
		end
	end
	function api.MoveBall(position: Vector3, rotation: CFrame?)
		local current = ball
		if current then
			current:PivotTo(CFrame.new(position) * (rotation or CFrame.new()) * CFrame.new(0, -3.8, 0))
			targets.ball = position
		end
	end
	function api.SpawnBall(position: Vector3?): Model
		if ball then
			ball:Destroy()
		end
		ball = BallVisual.Create()
		local current = ball :: Model
		current.Parent = model
		protect(current)
		prompt(current:FindFirstChild("ContactSphere") :: BasePart, "PushBall", "ball", "Guide ball")
		api.MoveBall(position or ballStart)
		return current
	end
	function api.ResetBall(position: Vector3?)
		api.MoveBall(position or ballStart)
	end
	function api.Destroy()
		ball = nil
		model:Destroy()
	end
	protect(model)
	return api
end

return Scene
