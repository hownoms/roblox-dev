--!strict
-- Optional review presentation. All progress and interaction acceptance belong to the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Kit = require(ReplicatedStorage.Shared.Models.Expansion1)

local Client = {}
function Client.Start(remotes: Folder, scene: Instance)
	local player = Players.LocalPlayer
	local connections: { RBXScriptConnection } = {}
	local instances: { Instance } = {}
	local effects: { [Model]: boolean } = {}
	local sceneConnections: { RBXScriptConnection } = {}
	local ownedPrompts: { ProximityPrompt } = {}
	local dead = false
	local eventId: string? = nil
	local reducedMotion = false
	local reducedParticles = false
	local charging = false
	local chargeStart = 0
	local chargeVisual: Model? = nil
	local cooldownUntil = 0
	local waves = 0
	local puffActive = false
	local lastPuff = -math.huge
	local messageUntil = 0
	local bounceSizes: { [BasePart]: Vector3 } = {}
	local bounceToken = 0
	local function restorePanels()
		bounceToken += 1
		for panel, size in bounceSizes do
			if panel.Parent then
				panel.Size = size
			end
		end
		bounceSizes = {}
	end
	local function decorativeBounce()
		if reducedMotion then
			return
		end
		restorePanels()
		local token = bounceToken
		local ball = scene:FindFirstChild("landmark_spring_vault_ball")
		if not ball then
			return
		end
		for _, panel in ball:GetDescendants() do
			if panel:IsA("BasePart") and panel.Name == "ColorPanel" then
				bounceSizes[panel] = panel.Size
			end
		end
		task.spawn(function()
			local started = os.clock()
			while not dead and token == bounceToken and os.clock() - started < 0.25 do
				local t = (os.clock() - started) / 0.25
				-- Keep colored panels inside the cream gutters even at peak squash.
				local amount = math.sin(t * math.pi) * 0.01
				for panel, size in bounceSizes do
					if panel.Parent then
						panel.Size = Vector3.new(size.X * (1 + amount), size.Y * (1 - amount), size.Z * (1 + amount))
					end
				end
				RunService.RenderStepped:Wait()
			end
			if token == bounceToken then
				restorePanels()
			end
		end)
	end
	local snapshot: any = {}
	local intent = remotes:WaitForChild("Intent") :: RemoteEvent
	local function send(action: string, targetId: string?)
		if not dead then
			intent:FireServer({ action = action, targetId = targetId, eventInstanceId = eventId })
		end
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpringVaultAdventureReview"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	table.insert(instances, gui)
	local card = Instance.new("ScrollingFrame")
	card.Size = UDim2.new(0, 330, 0, 330)
	card.AnchorPoint = Vector2.new(0, 0.5)
	card.Position = UDim2.new(0, 12, 0.5, 0)
	card.BackgroundColor3 = Color3.fromRGB(24, 47, 66)
	card.BorderSizePixel = 0
	card.ScrollBarThickness = 6
	card.ScrollingDirection = Enum.ScrollingDirection.Y
	card.CanvasSize = UDim2.fromOffset(0, 330)
	card.Parent = gui
	local cardContentHeight = 330
	local function fitCard()
		local viewport = gui.AbsoluteSize
		-- Keep the review card between the touch movement and jump zones.
		card.AnchorPoint = Vector2.new(if UserInputService.TouchEnabled then 0.5 else 0, 0.5)
		card.Position = if UserInputService.TouchEnabled then UDim2.new(0.5, 0, 0.5, 0) else UDim2.new(0, 12, 0.5, 0)
		-- Scroll short viewports instead of shrinking the 48px interaction targets.
		card.Size = UDim2.fromOffset(
			math.min(330, math.max(0, viewport.X - 24)),
			math.min(cardContentHeight, math.max(0, viewport.Y - 24))
		)
		card.CanvasSize = UDim2.fromOffset(0, cardContentHeight)
		card.CanvasPosition =
			Vector2.new(0, math.min(card.CanvasPosition.Y, math.max(0, cardContentHeight - card.AbsoluteSize.Y)))
	end
	fitCard()
	table.insert(connections, gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitCard))
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card
	local function label(text: string, y: number, height: number): TextLabel
		local item = Instance.new("TextLabel")
		item.Size = UDim2.new(1, -24, 0, height)
		item.Position = UDim2.fromOffset(12, y)
		item.BackgroundTransparency = 1
		item.Text = text
		item.TextWrapped = true
		item.TextColor3 = Color3.fromRGB(255, 244, 216)
		item.TextSize = 16
		item.Font = Enum.Font.Gotham
		item.TextXAlignment = Enum.TextXAlignment.Left
		item.Parent = card
		return item
	end
	label("SPRING VAULT · Optional adventure", 10, 28)
	local status = label(
		"Help uncover a springy surprise · about 5 minutes. Review build: permanent rewards are unavailable.",
		42,
		62
	)
	local objective = label("Talk to Mara, then try Pip's Broadwave.", 106, 54)
	local function button(text: string, x: number, y: number, callback: () -> ()): TextButton
		local item = Instance.new("TextButton")
		item.Name = string.gsub(text, "[^%w]", "")
		local column = (x - 12) / 104
		item.Size = UDim2.new(1 / 3, -12, 0, 48)
		item.Position = UDim2.new(column / 3, 12 - column * 6, 0, y)
		item.BackgroundColor3 = Color3.fromRGB(255, 244, 216)
		item.TextColor3 = Color3.fromRGB(24, 47, 66)
		item.TextSize = 14
		item.Font = Enum.Font.GothamMedium
		item.Text = text
		item.Parent = card
		table.insert(connections, item.Activated:Connect(callback))
		return item
	end
	button("Join", 12, 170, function()
		send("Join")
	end)
	button("Ignore", 116, 170, function()
		send("Ignore")
		card.Visible = false
	end)
	button("Leave", 220, 170, function()
		send("Leave")
	end)
	button("Start", 12, 224, function()
		send("Start")
	end)
	button("Ready", 116, 224, function()
		send("Ready")
	end)
	local haul = button("Guide ball", 220, 224, function()
		send("PushBall")
	end)
	local motion: TextButton
	motion = button("Motion: on", 12, 278, function()
		reducedMotion = not reducedMotion
		if reducedMotion then
			restorePanels()
		end
		motion.Text = if reducedMotion then "Motion: low" else "Motion: on"
	end)
	local particles: TextButton
	particles = button("Puffs: on", 116, 278, function()
		reducedParticles = not reducedParticles
		particles.Text = if reducedParticles then "Puffs: off" else "Puffs: on"
	end)
	button("Reset ball", 220, 278, function()
		send("ResetBall")
	end)
	local routeLeft = button("Left route", 12, 332, function()
		send("RouteLeft")
	end)
	local routeRight = button("Right route", 116, 332, function()
		send("RouteRight")
	end)
	routeLeft.Visible = false
	routeRight.Visible = false
	local function root(): BasePart?
		local character = player.Character
		return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	end
	local function visible(frame: CFrame): boolean
		local part = root()
		return part ~= nil and (part.Position - frame.Position).Magnitude <= 80
	end
	local function localEffect(model: Model, frame: CFrame)
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
			end
		end
		model:PivotTo(frame)
		model.Parent = workspace
		effects[model] = true
	end
	local function clearCharge()
		charging = false
		if chargeVisual then
			chargeVisual:Destroy()
			chargeVisual = nil
		end
	end
	local function clearEffects()
		for model in effects do
			model:Destroy()
		end
		table.clear(effects)
	end
	local function ability(_: string, state: Enum.UserInputState)
		if dead or (state ~= Enum.UserInputState.Begin and not charging) then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then
			if not (snapshot.joined or snapshot.loanAvailable) or os.clock() < cooldownUntil or charging then
				return Enum.ContextActionResult.Pass
			end
			charging = true
			chargeStart = os.clock()
			send("ChargeBegin", "trial_patch")
		elseif state == Enum.UserInputState.End and charging then
			clearCharge()
			send("ChargeRelease", "trial_patch")
		elseif state == Enum.UserInputState.Cancel and charging then
			clearCharge()
			send("ChargeCancel", "trial_patch")
		end
		return Enum.ContextActionResult.Sink
	end
	ContextActionService:BindAction("SpringVaultBroadwave", ability, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonL1)
	ContextActionService:SetTitle("SpringVaultBroadwave", "Hold / release")
	ContextActionService:SetPosition("SpringVaultBroadwave", UDim2.new(1, -160, 1, -170))
	local touch = ContextActionService:GetButton("SpringVaultBroadwave")
	if touch then
		touch.Size = UDim2.fromOffset(64, 64)
	end
	table.insert(
		connections,
		RunService.RenderStepped:Connect(function()
			if charging then
				local part = root()
				if part then
					local model: Model = chargeVisual or Kit.ChargeEffect(0)
					if not chargeVisual then
						chargeVisual = model
					end
					local progress = math.clamp((os.clock() - chargeStart) / 0.8, 0, 1)
					local dotIndex = 0
					for _, dot in model:GetChildren() do
						if dot:IsA("BasePart") and dot.Name == "ChargeDot" then
							dotIndex += 1
							dot.Transparency = if progress >= dotIndex / 3 then 0 else 0.7
						end
					end
					model:PivotTo(part.CFrame)
					model.Parent = workspace
				end
			end
		end)
	)
	table.insert(
		connections,
		player.CharacterRemoving:Connect(function()
			if charging then
				send("ChargeCancel", "trial_patch")
			end
			clearCharge()
		end)
	)
	table.insert(
		connections,
		(remotes:WaitForChild("Snapshot") :: RemoteEvent).OnClientEvent:Connect(function(data: any)
			snapshot = data
			eventId = data.eventInstanceId
			if data.message then
				status.Text = data.message
				messageUntil = os.clock() + 4
			elseif os.clock() >= messageUntil then
				status.Text = "Stage: "
					.. tostring(data.stage or "Optional")
					.. (
						if data.joined
								and data.RemainingSeconds
								and data.RemainingSeconds > 0
							then " · " .. math.ceil(data.RemainingSeconds) .. "s"
							else ""
					)
			end
			if charging and not (data.joined or data.loanAvailable) then
				send("ChargeCancel", "trial_patch")
				clearCharge()
			end
			objective.Text = data.objective
				or (
					if type(data.objectives) == "table"
						then table.concat(data.objectives, "\n")
						else "Follow the marked objectives."
				)
			haul.Text = if data.hauling then "Release ball" else "Guide ball"
			local choosingRoute = data.joined and data.stage == "vault"
			routeLeft.Visible = choosingRoute
			routeRight.Visible = choosingRoute
			cardContentHeight = if choosingRoute then 390 else 330
			fitCard()
			if data.joined then
				card.Visible = true
			end
		end)
	)
	table.insert(
		connections,
		(remotes:WaitForChild("Effect") :: RemoteEvent).OnClientEvent:Connect(function(data: any)
			if data.kind == "CancelCharge" then
				if data.playerUserId == player.UserId then
					clearCharge()
				end
				return
			end
			if data.kind == "Wave" and data.playerUserId == player.UserId then
				cooldownUntil = os.clock() + 8
			end
			if data.kind == "Gate" then
				objective.Text = "✓ Gate validated. " .. (data.message or "Keep guiding the ball.")
			end
			local frame = data.frame
			if typeof(frame) ~= "CFrame" or not visible(frame) then
				return
			end
			if data.kind == "Wave" and waves < 2 then
				waves += 1
				task.spawn(function()
					local model = Kit.AbilityEffect(0, reducedMotion)
					localEffect(model, frame)
					local started = os.clock()
					while not dead and effects[model] and os.clock() - started < 0.35 do
						local progress = math.clamp((os.clock() - started) / 0.35, 0, 1)
						if not reducedMotion then
							model:PivotTo(frame * CFrame.new(0, 0, -progress * 8))
						end
						for _, part in model:GetDescendants() do
							if part:IsA("BasePart") then
								part.Transparency = 0.3 + progress * 0.7
							end
						end
						RunService.RenderStepped:Wait()
					end
					model:Destroy()
					effects[model] = nil
					waves -= 1
				end)
			elseif
				(data.kind == "Bounce" or data.kind == "Gate")
				and not reducedParticles
				and not puffActive
				and os.clock() - lastPuff >= 0.6
			then
				puffActive = true
				if data.kind == "Bounce" then
					decorativeBounce()
				end
				lastPuff = os.clock()
				task.spawn(function()
					local model = Kit.BallEffect(reducedMotion)
					localEffect(model, frame)
					local started = os.clock()
					while not dead and effects[model] and os.clock() - started < 0.25 do
						for _, part in model:GetDescendants() do
							if part:IsA("BasePart") then
								part.Transparency = (os.clock() - started) / 0.25
							end
						end
						RunService.RenderStepped:Wait()
					end
					model:Destroy()
					effects[model] = nil
					puffActive = false
				end)
			end
		end)
	)
	-- Prompts are presentation only; forged targets still pass through server validation.
	local function installPrompt(item: Instance)
		local action = item:GetAttribute("AdventureAction")
		local targetId = item:GetAttribute("TargetId") or item:GetAttribute("EntityId")
		if type(action) ~= "string" or type(targetId) ~= "string" then
			return
		end
		local part = if item:IsA("BasePart") then item else if item:IsA("Model") then item.PrimaryPart else nil
		if not part then
			return
		end
		local existing = part:FindFirstChildWhichIsA("ProximityPrompt")
		local prompt: ProximityPrompt = existing or Instance.new("ProximityPrompt")
		if not existing then
			prompt.Name = "SpringVaultLocalPrompt"
			table.insert(ownedPrompts, prompt)
		end
		local actionText = item:GetAttribute("ActionText")
		local displayName = item:GetAttribute("DisplayName")
		if not existing then
			prompt.ActionText = if type(actionText) == "string" then actionText else action
			prompt.ObjectText = if type(displayName) == "string" then displayName else targetId
			prompt.MaxActivationDistance = if action == "Talk" then 10 else 12
			prompt.RequiresLineOfSight = true
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.Parent = part
		end
		table.insert(
			sceneConnections,
			prompt.Triggered:Connect(function()
				if action == "Talk" then
					card.Visible = true
				end
				send(action, targetId)
			end)
		)
	end
	local function clearScene()
		if charging then
			send("ChargeCancel", "trial_patch")
		end
		clearCharge()
		clearEffects()
		restorePanels()
		for _, connection in sceneConnections do
			connection:Disconnect()
		end
		for _, prompt in ownedPrompts do
			prompt:Destroy()
		end
		table.clear(sceneConnections)
		table.clear(ownedPrompts)
	end
	local function bindScene(newScene: Instance)
		clearScene()
		restorePanels()
		scene = newScene
		for _, item in newScene:GetDescendants() do
			installPrompt(item)
		end
		table.insert(sceneConnections, newScene.DescendantAdded:Connect(installPrompt))
		table.insert(sceneConnections, newScene.Destroying:Connect(clearScene))
	end
	bindScene(scene)
	table.insert(
		connections,
		workspace.ChildAdded:Connect(function(child)
			if child.Name == "SpringVaultAdventure" then
				bindScene(child)
			end
		end)
	)
	send("Sync")
	local handle = {}
	function handle.Destroy()
		restorePanels()
		if dead then
			return
		end
		if charging then
			send("ChargeCancel", "trial_patch")
		end
		dead = true
		clearCharge()
		clearScene()
		ContextActionService:UnbindAction("SpringVaultBroadwave")
		for _, connection in connections do
			connection:Disconnect()
		end
		for _, item in instances do
			item:Destroy()
		end
		for model in effects do
			model:Destroy()
		end
		table.clear(connections)
		table.clear(instances)
		table.clear(effects)
	end
	return handle
end
return Client
