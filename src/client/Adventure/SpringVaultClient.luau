--!strict
-- Optional review presentation. All progress and interaction acceptance belong to the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Kit = require(ReplicatedStorage.Shared.Models.Expansion1)
local Config = require(ReplicatedStorage.Shared.Adventure.SpringVaultConfig)
local BallVisual = require(ReplicatedStorage.Shared.Adventure.BeachBallVisual)

local Client = {}
function Client.Start(remotes: Folder, scene: Instance)
	local player = Players.LocalPlayer
	local connections: { RBXScriptConnection } = {}
	local instances: { Instance } = {}
	local effects: { [Model]: boolean } = {}
	local sceneConnections: { RBXScriptConnection } = {}
	local promptCleanups: { [Instance]: () -> () } = {}
	local visualJobs: { [Model]: boolean } = {}
	local visualCleanups: { [Model]: () -> () } = {}
	local visualConnections: { [Model]: RBXScriptConnection } = {}
	local sceneGeneration = 0
	local sceneAvailable = true
	local latestSnapshot: any = {}
	local promptEntries: { [Instance]: any } = {}
	local expanded = false
	local nearMara = false
	local beginRequested: string? = nil
	local rescueComplete = false
	local dead = false
	local eventId: string? = nil
	local reducedMotion = false
	local reducedParticles = false
	local charging = false
	local chargeCardVisible = false
	local chargeInput: InputObject? = nil
	local chargeTool: Tool? = nil
	local chargeStart = 0
	local chargeVisual: Model? = nil
	local aimPreview: Part? = nil
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
	local aimHint = Instance.new("TextLabel")
	aimHint.Name = "BroadwaveAimHint"
	aimHint.AnchorPoint = Vector2.new(0.5, 0)
	aimHint.Position = UDim2.new(0.5, 0, 0, 12)
	aimHint.Size = UDim2.new(0.7, 0, 0, 48)
	aimHint.BackgroundColor3 = Color3.fromRGB(24, 47, 66)
	aimHint.TextColor3 = Color3.fromRGB(255, 244, 216)
	aimHint.TextSize = 16
	aimHint.TextWrapped = true
	aimHint.Font = Enum.Font.GothamMedium
	aimHint.Visible = false
	aimHint.Parent = gui
	local card = Instance.new("ScrollingFrame")
	card.Size = UDim2.new(0, 330, 0, 330)
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, 12)
	card.BackgroundColor3 = Color3.fromRGB(24, 47, 66)
	card.BorderSizePixel = 0
	card.ScrollBarThickness = 6
	card.ScrollingDirection = Enum.ScrollingDirection.Y
	card.CanvasSize = UDim2.fromOffset(0, 330)
	card.Parent = gui
	local cardContentHeight = 330
	local function fitCard()
		local viewport = gui.AbsoluteSize
		-- Stay clear of chat and between the touch movement and jump zones.
		card.AnchorPoint = Vector2.new(0.5, 0)
		card.Position = UDim2.new(0.5, 0, 0, 12)
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
	label("SPRING VAULT", 8, 24)
	local status = label("Help Mara rescue the ball. Pip's trial is optional.", 32, 42)
	local objective = label("Talk to Mara, then try Pip's Broadwave.", 76, 48)
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
	local join = button("Join", 12, 170, function()
		send("Join")
	end)
	local ignore = button("Ignore", 116, 170, function()
		send("Ignore")
		card.Visible = false
	end)
	local leave = button("Leave", 220, 170, function()
		send("Leave")
	end)
	local start = button("Start", 12, 224, function()
		if latestSnapshot.canStart then
			beginRequested = eventId
			send("Start")
		end
	end)
	local ready = button("Ready", 116, 224, function()
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
	local resetBall = button("Reset ball", 220, 278, function()
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
	local options = button("Options", 220, 332, function()
		expanded = not expanded
	end)
	local function layoutControls()
		local data = latestSnapshot
		join.Visible = not data.joined and (not data.trialActive or nearMara)
		ignore.Visible = not data.joined
		leave.Visible = data.joined == true or data.trialActive == true
		leave.Text = if data.joined then "Leave" else "End trial"
		start.Visible = data.joined == true and data.phase == "Inviting" and data.isStarter == true
		start.Text = if (data.startWaitSeconds or 0) > 0 then "Begin in " .. data.startWaitSeconds .. "s" else "Begin"
		ready.Text = "Begin helping"
		ready.Visible = data.canReady == true
		haul.Visible = data.joined == true and data.stage == "ball"
		resetBall.Visible = expanded and data.joined == true and data.stage == "ball"
		routeLeft.Visible = data.routeSelectable == true
		routeRight.Visible = data.routeSelectable == true
		routeLeft.Text = if data.route == "Left" then "Selected: Left" else "Left route"
		routeRight.Text = if data.route == "Right" then "Selected: Right" else "Right route"
		motion.Visible = expanded
		particles.Visible = expanded
		options.Text = if expanded then "Less" else "Options"
		local index = 0
		for _, control in
			{ join, ignore, start, ready, haul, routeLeft, routeRight, leave, options, motion, particles, resetBall }
		do
			if control.Visible then
				local column = index % 3
				control.Position = UDim2.new(column / 3, 12 - column * 6, 0, 132 + math.floor(index / 3) * 54)
				index += 1
			end
		end
		cardContentHeight = 138 + math.ceil(index / 3) * 54
		fitCard()
	end
	layoutControls()
	-- These markers only select presentation controls. The server resolves issued tools
	-- and the loaded license separately; a client marker never grants ordinary digging.
	local function broadwave(container: Instance?): Tool?
		if container then
			for _, item in container:GetChildren() do
				if
					item:IsA("Tool")
					and (item:GetAttribute("AdventureLoan") == true or item:GetAttribute("ToolId") == "tool_broadwave")
				then
					return item
				end
			end
		end
		return nil
	end
	local function equipped(): Tool?
		return broadwave(player.Character)
	end
	local function chargeAvailable(tool: Tool?): boolean
		-- Permanent production tools also charge on ordinary sand outside the streamed
		-- arena. These markers only choose input; ResolveTool still validates ownership.
		return tool ~= nil
			and (
				sceneAvailable
				or tool:GetAttribute("AdventureLoan") ~= true
					and tool:GetAttribute("ToolId") == "tool_broadwave"
					and tool:GetAttribute("LicensedBroadwave") == true
			)
	end
	local equip = Instance.new("TextButton")
	equip.Name = "BroadwaveEquip"
	equip.AnchorPoint = Vector2.new(0.5, 0)
	equip.Position = UDim2.new(1, -12, 1, -76)
	equip.Size = UDim2.fromOffset(176, 48)
	equip.Text = "Equip Broadwave"
	equip.TextSize = 16
	equip.Font = Enum.Font.GothamMedium
	equip.BackgroundColor3 = Color3.fromRGB(255, 244, 216)
	equip.TextColor3 = Color3.fromRGB(24, 47, 66)
	equip.Visible = false
	equip.Parent = gui
	local function sharedEquipPresent(): boolean
		-- Production already owns equip/stow, tool preference and shovel restoration.
		-- The dedicated review scene has no shared HUD and keeps this fallback control.
		return player.PlayerGui:FindFirstChild("Dig_Broadwave") ~= nil
	end
	table.insert(
		connections,
		equip.Activated:Connect(function()
			if sharedEquipPresent() then
				return
			end
			local character = player.Character
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			if not humanoid then
				return
			end
			if equipped() then
				humanoid:UnequipTools()
			else
				local tool = broadwave(player:FindFirstChildOfClass("Backpack"))
				if tool then
					humanoid:EquipTool(tool)
				end
			end
		end)
	)
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
		if charging then
			card.Visible = chargeCardVisible
		end
		charging = false
		chargeInput = nil
		chargeTool = nil
		aimHint.Visible = false
		if aimPreview then
			aimPreview:Destroy()
			aimPreview = nil
		end
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
	local function cancelCharge()
		if charging then
			send("ChargeCancel", "trial_patch")
		end
		clearCharge()
	end
	local function ability(_: string, state: Enum.UserInputState, input: InputObject)
		if charging and equipped() ~= chargeTool then
			cancelCharge()
		end
		if dead or (state ~= Enum.UserInputState.Begin and not charging) then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then
			if
				UserInputService:GetFocusedTextBox()
				or not chargeAvailable(equipped())
				or os.clock() < cooldownUntil
				or charging
			then
				return Enum.ContextActionResult.Pass
			end
			charging = true
			chargeCardVisible = card.Visible
			card.Visible = false
			chargeInput = input
			chargeTool = equipped()
			chargeStart = os.clock()
			aimHint.Visible = true
			send("ChargeBegin", "trial_patch")
		elseif
			state ~= Enum.UserInputState.Cancel
			and chargeInput
			and (
				chargeInput.UserInputType ~= input.UserInputType
				or chargeInput.KeyCode ~= input.KeyCode
				or (input.UserInputType == Enum.UserInputType.Touch and chargeInput ~= input)
			)
		then
			-- Q, L1 and touch may overlap; only the input that began this charge releases it.
			return Enum.ContextActionResult.Pass
		elseif state == Enum.UserInputState.End and charging then
			clearCharge()
			send("ChargeRelease", "trial_patch")
		elseif state == Enum.UserInputState.Cancel and charging then
			cancelCharge()
		end
		return Enum.ContextActionResult.Sink
	end
	table.insert(connections, UserInputService.WindowFocusReleased:Connect(cancelCharge))
	table.insert(connections, UserInputService.TextBoxFocused:Connect(cancelCharge))
	ContextActionService:BindAction("SpringVaultBroadwave", ability, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonL1)
	ContextActionService:SetTitle("SpringVaultBroadwave", "Hold / release")
	ContextActionService:SetPosition("SpringVaultBroadwave", UDim2.new(1, -160, 1, -170))
	local touch = ContextActionService:GetButton("SpringVaultBroadwave")
	if touch then
		touch.Size = UDim2.fromOffset(64, 64)
		local function fitTouch()
			local camera = workspace.CurrentCamera
			local parent = touch.Parent
			if camera and parent and parent:IsA("GuiObject") then
				local viewport = camera.ViewportSize
				local position = UDim2.fromOffset(
					viewport.X - 88 - parent.AbsolutePosition.X,
					math.max(76, viewport.Y / 2 - 66) - parent.AbsolutePosition.Y
				)
				if touch.Position ~= position then
					touch.Position = position
				end
			end
		end
		fitTouch()
		table.insert(connections, touch:GetPropertyChangedSignal("Position"):Connect(fitTouch))
		if touch.Parent and touch.Parent:IsA("GuiObject") then
			table.insert(connections, touch.Parent:GetPropertyChangedSignal("AbsolutePosition"):Connect(fitTouch))
		end
		if workspace.CurrentCamera then
			table.insert(
				connections,
				workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitTouch)
			)
		end
	end
	table.insert(
		connections,
		RunService.RenderStepped:Connect(function()
			local nearest: any = nil
			local distance = math.huge
			local characterRoot = root()
			local data = latestSnapshot
			nearMara = false
			for _, entry in promptEntries do
				if entry.Target == "npc_mara" and characterRoot then
					nearMara = (characterRoot.Position - entry.Part.Position).Magnitude <= 10
				end
				local allowed = entry.Action == "Talk" and not data.joined
					or entry.Action == "Leave" and data.joined
					or entry.Action == "OpenVault" and data.joined and data.ready and data.stage == "vault"
					or (entry.Action == "RouteLeft" or entry.Action == "RouteRight") and data.routeSelectable
					or entry.Action == "PushBall" and data.joined and data.stage == "ball"
					or entry.Action == "ResetBall" and data.joined and data.stage == "ball"
					or entry.Action == "Excavate"
						and (data.joined and data.ready and data.stage == "anchors" and string.find(
							entry.Target,
							"vault_anchor_"
						) ~= nil or data.trialActive and data.trialWave and not data.trialComplete and string.find(
							entry.Target,
							"trial_target_"
						) ~= nil)
				if allowed and data.Anchors and data.Anchors[entry.Target] then
					local anchor = data.Anchors[entry.Target]
					allowed = not anchor.Completed
					entry.Prompt.ActionText = string.format("Scoop · %d/%d", anchor.Work, anchor.Required)
				end
				if data.trialTargets and data.trialTargets[entry.Target] then
					allowed = false
				end
				entry.Prompt.Enabled = false
				if allowed and characterRoot and sceneAvailable and not charging then
					local range = (characterRoot.Position - entry.Part.Position).Magnitude
					if range <= entry.Prompt.MaxActivationDistance and range < distance then
						nearest = entry
						distance = range
					end
				end
			end
			if nearest then
				nearest.Prompt.Enabled = true
				if nearest.Action == "PushBall" then
					nearest.Prompt.ActionText = if data.hauling then "Release ball" else "Attach and guide"
				end
			end
			local tool = equipped()
			equip.Visible = sceneAvailable
				and not sharedEquipPresent()
				and (tool ~= nil or broadwave(player:FindFirstChildOfClass("Backpack")) ~= nil)
			-- Keep touch controls in the scrollable panel; desktop equip stays clear of the objective.
			-- While aiming, neither the card nor the equip button should cover the footprint.
			equip.Visible = equip.Visible and not charging
			if card.Visible and UserInputService.TouchEnabled then
				equip.Parent = card
				equip.AnchorPoint = Vector2.zero
				equip.Size = UDim2.new(1 / 3, -12, 0, 48)
				equip.Position = UDim2.new(2 / 3, 0, 0, 332)
			else
				equip.Parent = gui
				equip.AnchorPoint = Vector2.new(1, 1)
				equip.Size = UDim2.fromOffset(176, 48)
				equip.Position = UDim2.new(1, -12, 1, -76)
			end
			layoutControls()
			if equip.Visible and card.Visible and UserInputService.TouchEnabled then
				equip.Position = UDim2.new(0, 12, 0, cardContentHeight - 6)
				equip.Size = UDim2.new(1, -24, 0, 48)
				cardContentHeight += 54
				fitCard()
			end
			equip.Text = if tool then "Stow Broadwave" else "Equip Broadwave"
			if touch then
				touch.Visible = chargeAvailable(tool)
			end
			if charging and tool ~= chargeTool then
				cancelCharge()
			end
			if charging then
				if os.clock() - chargeStart > 10 then
					cancelCharge()
					return
				end
				local part = root()
				if part then
					local model: Model = chargeVisual or Kit.ChargeEffect(0)
					if not chargeVisual then
						chargeVisual = model
					end
					local progress = math.clamp((os.clock() - chargeStart) / Config.BroadwaveChargeSeconds, 0, 1)
					aimHint.Text = if progress < 1
						then "Charging · turn your avatar toward the marked target"
						else "Ready · release toward the marked target (avatar facing)"
					-- Advisory local footprint follows the same flat avatar direction as server validation.
					-- It changes neither character rotation nor the requested/accepted target.
					local direction = Vector3.new(part.CFrame.LookVector.X, 0, part.CFrame.LookVector.Z)
					if direction.Magnitude >= 0.01 then
						local preview = aimPreview or Instance.new("Part")
						if not aimPreview then
							aimPreview = preview
							preview.Name = "SpringVaultLocalAim"
							preview.Anchored = true
							preview.CanCollide = false
							preview.CanTouch = false
							preview.CanQuery = false
							preview.Size = Vector3.new(Config.BroadwaveWidth, 0.06, 8)
							preview.Transparency = 0.75
							preview.Material = Enum.Material.Neon
							preview.Parent = workspace
						end
						preview.Color = if progress < 1
							then Color3.fromRGB(255, 224, 128)
							else Color3.fromRGB(122, 236, 190)
						preview.CFrame = CFrame.lookAt(part.Position, part.Position + direction.Unit)
							* CFrame.new(0, -2.5, -4)
					end
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
			latestSnapshot = data
			eventId = data.eventInstanceId
			if data.joined and data.stage == "complete" then
				rescueComplete = true
			elseif data.joined or data.trialActive then
				rescueComplete = false
			end
			-- Begin is the player's readiness confirmation. Wait for the server's
			-- preparation snapshot and the real scene before acknowledging it.
			if beginRequested == eventId and beginRequested ~= nil and data.canReady and sceneAvailable then
				beginRequested = nil
				send("Ready")
			elseif
				beginRequested ~= eventId
				or not data.joined
				or data.phase ~= "Inviting" and data.phase ~= "Preparing"
			then
				beginRequested = nil
			end
			if data.message then
				status.Text = data.message
				messageUntil = os.clock() + 4
			elseif os.clock() >= messageUntil then
				status.Text = if rescueComplete
					then "✓ Ball rescued · 3/3 gates"
					else "Stage: " .. tostring(data.stage or "Optional") .. (if data.joined
							and data.RemainingSeconds
							and data.RemainingSeconds > 0
						then " · " .. math.ceil(data.RemainingSeconds) .. "s"
						else "")
			end
			if charging and not (data.joined or data.loanAvailable or data.licensedEquipped) then
				send("ChargeCancel", "trial_patch")
				clearCharge()
			end
			objective.Text = if type(data.objective) == "string"
				then string.gsub(data.objective, "Ability", "Q / L1 / Ability")
				else data.objective or (if type(data.objectives) == "table"
					then table.concat(data.objectives, "\n")
					else "Follow the marked objectives.")
			if rescueComplete and not data.joined then
				objective.Text = "Rescue complete. Talk to Mara for another run, or leave the arena."
			end
			haul.Text = if data.hauling then "Release ball" else "Guide ball"
			layoutControls()
			if sceneAvailable then
				for _, item in scene:GetDescendants() do
					if item:IsA("BasePart") then
						local gate = tonumber(string.match(item.Name, "^GateMarker(%d+)$"))
						if gate then
							local passed = gate <= (data.GateIndex or 0)
							item.Color = if passed
								then Kit.Palette.Cream
								else if gate == (data.GateIndex or 0) + 1
									then Kit.Palette.Gold
									else Kit.Palette.Blue
							local gateLabel = item:FindFirstChildWhichIsA("BillboardGui")
							if gateLabel then
								gateLabel.Enabled = data.joined == true
									and data.stage == "ball"
									and gate == (data.GateIndex or 0) + 1
							end
						elseif
							string.find(item.Name, "RouteDash", 1, true)
							or string.find(item.Name, "RouteArrow", 1, true)
						then
							item.Transparency = if data.joined
									and (data.stage == "vault" or data.stage == "ball")
									and string.find(item.Name, data.route or "Left", 1, true)
								then 0
								else 0.7
						end
					end
				end
			end
			if data.joined then
				if charging then
					chargeCardVisible = true
				else
					card.Visible = true
				end
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
				status.Text = "✓ Gate reached · checkpoint saved"
				messageUntil = os.clock() + 4
			end
			if dead or not sceneAvailable then
				return
			end
			local generation = sceneGeneration
			local frame = data.frame
			if typeof(frame) ~= "CFrame" or not visible(frame) then
				return
			end
			if data.kind == "Wave" and waves < 2 then
				waves += 1
				task.spawn(function()
					if dead or not sceneAvailable or generation ~= sceneGeneration then
						return
					end
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
					if generation == sceneGeneration then
						waves -= 1
					end
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
					if dead or not sceneAvailable or generation ~= sceneGeneration then
						return
					end
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
					if generation == sceneGeneration then
						puffActive = false
					end
				end)
			end
		end)
	)
	-- Prompts are presentation only; forged targets still pass through server validation.
	local function installPrompt(item: Instance)
		if item:IsA("ProximityPrompt") then
			for _, entry in promptEntries do
				if entry.Part == item.Parent and entry.Prompt ~= item then
					item.Enabled = false
					return
				end
			end
		end
		local ball = if item:IsA("Model") and item.Name == "landmark_spring_vault_ball"
			then item
			else item:FindFirstAncestor("landmark_spring_vault_ball")
		if ball and ball:IsA("Model") and ball:FindFirstChild("ContactSphere") and not visualJobs[ball] then
			visualJobs[ball] = true
			local generation = sceneGeneration
			visualConnections[ball] = ball.AncestryChanged:Connect(function()
				if not ball:IsDescendantOf(workspace) then
					local cleanup = visualCleanups[ball]
					if cleanup then
						cleanup()
					end
					visualCleanups[ball] = nil
					visualJobs[ball] = nil
					local connection = visualConnections[ball]
					if connection then
						connection:Disconnect()
						visualConnections[ball] = nil
					end
				end
			end)
			task.spawn(function()
				local cleanup = BallVisual.DecorateLocal(ball, function()
					return dead
						or generation ~= sceneGeneration
						or not ball:IsDescendantOf(workspace)
						or visualJobs[ball] ~= true
				end)
				if cleanup then
					if dead or generation ~= sceneGeneration or not ball:IsDescendantOf(workspace) then
						cleanup()
					else
						visualCleanups[ball] = cleanup
					end
				end
			end)
		end
		local action = item:GetAttribute("AdventureAction")
		local targetId = item:GetAttribute("TargetId") or item:GetAttribute("EntityId")
		if type(action) ~= "string" or type(targetId) ~= "string" then
			return
		end
		if promptCleanups[item] then
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
		local triggerConnection = prompt.Triggered:Connect(function()
			if action == "Talk" then
				card.Visible = true
			end
			send(action, targetId)
		end)
		local ancestryConnection: RBXScriptConnection? = nil
		local function cleanupPrompt()
			prompt.Enabled = false
			triggerConnection:Disconnect()
			if ancestryConnection then
				ancestryConnection:Disconnect()
			end
			if not existing then
				prompt:Destroy()
			end
			promptCleanups[item] = nil
			promptEntries[item] = nil
		end
		promptEntries[item] = { Prompt = prompt, Part = part, Action = action, Target = targetId }
		promptCleanups[item] = cleanupPrompt
		ancestryConnection = item.AncestryChanged:Connect(function()
			if not item:IsDescendantOf(scene) then
				cleanupPrompt()
			end
		end)
	end
	local function clearScene()
		sceneAvailable = false
		sceneGeneration += 1
		if charging then
			send("ChargeCancel", "trial_patch")
		end
		clearCharge()
		clearEffects()
		waves = 0
		puffActive = false
		lastPuff = -math.huge
		restorePanels()
		for _, cleanup in visualCleanups do
			cleanup()
		end
		for _, connection in visualConnections do
			connection:Disconnect()
		end
		table.clear(visualCleanups)
		table.clear(visualConnections)
		table.clear(visualJobs)
		for _, connection in sceneConnections do
			connection:Disconnect()
		end
		for _, cleanup in promptCleanups do
			cleanup()
		end
		table.clear(sceneConnections)
		table.clear(promptCleanups)
	end
	local function bindScene(newScene: Instance)
		clearScene()
		restorePanels()
		scene = newScene
		sceneAvailable = true
		for _, item in newScene:GetDescendants() do
			installPrompt(item)
		end
		table.insert(sceneConnections, newScene.DescendantAdded:Connect(installPrompt))
		table.insert(
			sceneConnections,
			newScene.DescendantRemoving:Connect(function(item)
				local cleanup = promptCleanups[item]
				if cleanup then
					cleanup()
				end
			end)
		)
		table.insert(sceneConnections, newScene.Destroying:Connect(clearScene))
		table.insert(
			sceneConnections,
			newScene.AncestryChanged:Connect(function()
				if not newScene:IsDescendantOf(workspace) then
					clearScene()
				end
			end)
		)
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
