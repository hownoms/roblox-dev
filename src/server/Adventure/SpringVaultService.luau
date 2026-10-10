--!strict
-- Explicit opt-in runtime. Production boot never requires this module automatically.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Adventure.SpringVaultConfig)
local Kit = require(Shared.Models.Expansion1)
local RateLimiter = require(Shared.Util.RateLimiter)
local State = require(script.Parent.SpringVaultState)
local Scene = require(script.Parent.SpringVaultScene)
local Rules = require(script.Parent.SpringVaultRules)
local HaulBudget = require(script.Parent.HaulMovementBudget)
local ReviewAdapter = require(script.Parent.TemporaryReviewCompletionAdapter)
local Service = {}
export type Options = {
	Origin: Vector3?,
	ReviewSpawn: boolean?,
	OutcomeOwner: string?,
	-- Production supplies a trusted destination; only characters still in the pocket are returned.
	-- Missing/invalid/error results fall back to the recorded join frame. Review defaults are unchanged.
	ReturnFrame: ((Player) -> CFrame?)?,
	-- Admission reads authoritative loaded data/certification contracts; review explicitly injects a loan.
	CanEnter: ((Player) -> boolean)?,
	CanTrial: ((Player) -> boolean)?,
	-- Must return an equipped, server-issued licensed tool using authoritative loaded eligibility.
	-- Called again at release; nil/errors refuse external tools. Review loans stay runtime-owned.
	ResolveTool: ((Player) -> Tool?)?,
	-- Optional DigService adapter; validates ordinary geometry/yield/license independently.
	OnOrdinaryBroadwave: ((Player, CFrame, number) -> (boolean, string?))?,
	OnCompletion: ((any) -> (boolean, string))?,
	-- Validated, immutable observations only. Settlement remains the receiving service's responsibility.
	OnStage: ((any) -> ())?,
	OnFailure: ((any) -> ())?,
}
local function immutable(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[key] = immutable(child)
	end
	return table.freeze(copy)
end
local function root(player: Player): BasePart?
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local part = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if humanoid and humanoid.Health > 0 and part and part:IsA("BasePart") then part else nil
end
function Service.Start(options: Options?)
	local opts: Options = options or {}
	assert(not ReplicatedStorage:FindFirstChild("SpringVaultAdventure"), "Adventure already started")
	local remotes = Instance.new("Folder")
	remotes.Name = "SpringVaultAdventure"
	remotes.Parent = ReplicatedStorage
	local intent = Instance.new("RemoteEvent")
	intent.Name = "Intent"
	intent.Parent = remotes
	local snapshot = Instance.new("RemoteEvent")
	snapshot.Name = "Snapshot"
	snapshot.Parent = remotes
	local effect = Instance.new("RemoteEvent")
	effect.Name = "Effect"
	effect.Parent = remotes
	local scene: any = Scene.Build(workspace, opts.Origin, opts.ReviewSpawn)
	local limiter = RateLimiter.new(12, 1)
	local connections: { RBXScriptConnection } = {}
	local trial: { [Player]: any } = {}
	local returns: { [Player]: CFrame } = {}
	local charges: { [Player]: { At: number, Character: Model, Tool: Tool, Unequipped: RBXScriptConnection? } } = {}
	local nextWave: { [Player]: number } = {}
	local tools: { [Player]: Tool? } = {}
	local entryEquipment: { [Player]: { Character: Model, Tool: Tool? } } = {}
	local loanConnections: { [Player]: RBXScriptConnection? } = {}

	local lastPositions: { [Player]: Vector3 } = {}
	local lastMovementAt: { [Player]: number } = {}
	local movementBanks: HaulBudget.Banks = {}
	local walkSpeeds: { [Player]: { Humanoid: Humanoid, Speed: number } } = {}
	local function releaseSpeed(player: Player)
		local previous = walkSpeeds[player]
		if previous and previous.Humanoid.Parent then
			previous.Humanoid.WalkSpeed = previous.Speed
		end
		walkSpeeds[player] = nil
	end
	local recovery: { [Player]: number } = {}
	local session = HttpService:GenerateGUID(false)
	local sequence = 0
	local event: any = nil
	local ballPosition = scene.BallStart
	local checkpoint = ballPosition
	local waypoint = 2
	local checkpointWaypoint = 2
	local haulWork: { [number]: number } = {}
	local route = "Left"
	local ballResetAt: number? = nil
	local completionSent = false
	local completionPending = false
	local stagesSent: { [string]: boolean } = {}

	local stopped = false
	local lastBroadcast = 0
	local lastBounce = 0
	local adapter = ReviewAdapter.new()
	local submit: any = opts.OnCompletion or adapter.Submit
	-- Production settlement owns individual results; only the dedicated adapter is review-only.
	local externalOutcome = opts.OutcomeOwner == "External" or opts.OnCompletion ~= nil
	local self: any = { Scene = scene, ReviewAdapter = adapter }
	local function near(player: Player, target: Vector3, range: number): boolean
		local part = root(player)
		return part ~= nil and Rules.Within((part :: BasePart).Position, target, range)
	end
	local function participant(player: Player): any
		return if event then event.Participants[player.UserId] else nil
	end
	local function cancel(player: Player)
		if charges[player] then
			local charge = charges[player]
			if charge.Unequipped then
				charge.Unequipped:Disconnect()
			end
			charges[player] = nil
			effect:FireAllClients({ kind = "CancelCharge", playerUserId = player.UserId })
		end
	end
	local function loan(player: Player)
		local existingTool = tools[player]
		if existingTool and existingTool.Parent then
			return
		end
		if loanConnections[player] then
			(loanConnections[player] :: RBXScriptConnection):Disconnect()
			loanConnections[player] = nil
		end
		local backpack = player:FindFirstChildOfClass("Backpack")
		if not backpack then
			return
		end
		local character = player.Character
		if character and not entryEquipment[player] then
			entryEquipment[player] = { Character = character, Tool = character:FindFirstChildOfClass("Tool") :: Tool? }
		end
		local model = Kit.Broadwave()
		local handle = model.PrimaryPart :: BasePart
		local tool = Instance.new("Tool")
		tool.Name = "Broadwave (Adventure Loan)"
		tool.CanBeDropped = false
		tool:SetAttribute("AdventureLoan", true)
		tool.Grip = handle:GetAttribute("GripOffset") :: CFrame
		for _, item in model:GetChildren() do
			item.Parent = tool
		end
		for _, item in tool:GetDescendants() do
			if item:IsA("BasePart") then
				item.Anchored = false
				item.CanCollide = false
			end
		end
		model:Destroy()
		tool.Parent = backpack
		tools[player] = tool
		loanConnections[player] = tool.Unequipped:Connect(function()
			cancel(player)
		end)
	end
	local function restore(player: Player)
		releaseSpeed(player)
		cancel(player)
		local connection = loanConnections[player]
		if connection then
			connection:Disconnect()
			loanConnections[player] = nil
		end
		local tool = tools[player]
		if tool then
			tool:Destroy()
			tools[player] = nil
		end
		local character = player.Character
		local equipment = entryEquipment[player]
		entryEquipment[player] = nil
		local backpack = player:FindFirstChildOfClass("Backpack")
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		-- Restore the same possession, never recreate a tool or override a later equipment choice.
		if
			equipment
			and equipment.Character == character
			and equipment.Tool
			and backpack
			and equipment.Tool.Parent == backpack
			and character
			and not character:FindFirstChildOfClass("Tool")
			and humanoid
			and humanoid.Health > 0
		then
			humanoid:EquipTool(equipment.Tool)
		end
		local target = returns[player]
		local function inPocket(): boolean
			local part = root(player)
			return part ~= nil
				and math.abs((part :: BasePart).Position.X - scene.Origin.X) <= 48
				and math.abs((part :: BasePart).Position.Z - (scene.Origin.Z - 36)) <= 69
				and (part :: BasePart).Position.Y <= scene.Origin.Y + 20
		end
		-- Surface/respawned characters must never be pulled back down during production cleanup.
		if character and target and (not opts.ReturnFrame or inPocket()) then
			if opts.ReturnFrame then
				local ok, frame = pcall(opts.ReturnFrame, player)
				if ok and typeof(frame) == "CFrame" then
					target = frame
				end
			end
			-- A callback may yield or change the character. Recheck before moving it.
			if player.Character == character and character.Parent and (not opts.ReturnFrame or inPocket()) then
				character:PivotTo(target)
			end
		end
		returns[player] = nil
		lastPositions[player] = nil
		lastMovementAt[player] = nil
		movementBanks[player.UserId] = nil
		recovery[player] = nil
	end
	local function equippedAbilityTool(player: Player): Tool?
		local character = player.Character
		local ownLoan = tools[player]
		if ownLoan and ownLoan.Parent == character then
			return ownLoan
		end
		if not character or not opts.ResolveTool then
			return nil
		end
		local ok, tool = pcall(opts.ResolveTool, player)
		if
			ok
			and typeof(tool) == "Instance"
			and tool:IsA("Tool")
			and tool.Parent == character
			and tool:GetAttribute("ToolId") == Config.ToolId
			and tool:GetAttribute("AdventureLoan") ~= true
		then
			return tool
		end
		return nil
	end
	local function usableAbility(player: Player): boolean
		local tool = equippedAbilityTool(player)
		local character = player.Character
		if not tool or not character or tool.Parent ~= character or not root(player) then
			return false
		end
		local p = participant(player)
		if p and p.Attached then
			return false
		end
		if opts.OnOrdinaryBroadwave and tool ~= tools[player] and tool:GetAttribute("AdventureLoan") ~= true then
			return true
		end
		if
			trial[player]
			and opts.CanTrial
			and opts.CanTrial(player)
			and near(player, scene.Targets.trial_patch, Config.BroadwaveRange)
		then
			return true
		end
		return event ~= nil
			and event.Phase == "Active"
			and event.Stage == "anchors"
			and p ~= nil
			and p.Ready
			and p.Present
			and p.Connected
			and not p.Left
	end
	local function observations(stageId: string?, failureReason: string?): any
		local participants = {}
		for userId, p in event.Participants do
			table.insert(participants, {
				UserId = userId,
				Points = p.Points,
				ObjectiveIds = table.clone(p.Objectives),
				Connected = p.Connected,
				Left = p.Left,
			})
		end
		return immutable({
			BoundaryVersion = Config.CompletionBoundaryVersion,
			EventInstanceId = event.EventInstanceId,
			EventId = Config.EventId,
			LandmarkId = Config.LandmarkId,
			RegionId = Config.RegionId,
			StageId = stageId,
			FailureReason = failureReason,
			ObjectiveIds = table.clone(event.CompletedObjectives),
			CompletedStages = table.clone(event.CompletedStages),
			Participants = participants,
		})
	end
	local function reportStages()
		if not event then
			return
		end
		for _, stageId in event.CompletedStages do
			if not stagesSent[stageId] then
				stagesSent[stageId] = true
				if opts.OnStage then
					local context = observations(stageId, nil)
					local ok, err = pcall(function()
						(opts.OnStage :: (any) -> ())(context)
						return true
					end)
					if not ok then
						warn("[SpringVault] stage boundary failed", err)
					end
				end
			end
		end
	end
	local function send(player: Player, message: string?)
		local data: any = if event then event:snapshot(os.clock()) else {}
		data.eventInstanceId = if event then event.EventInstanceId else ""
		data.stage = if event then event.Stage else "Optional"
		data.phase = if event then event.Phase else "Dormant"
		data.joined = participant(player) ~= nil
			and not participant(player).Left
			and participant(player).Connected == true
		data.ready = participant(player) ~= nil and participant(player).Ready == true
		data.hauling = participant(player) ~= nil and participant(player).Attached == true
		data.trialComplete = trial[player] ~= nil and trial[player].Wave and trial[player].Cleared == 3
		data.loanAvailable = tools[player] ~= nil
		local equipped = equippedAbilityTool(player)
		data.licensedEquipped = equipped ~= nil and equipped ~= tools[player]
		data.message = message
		data.outcomeOwner = if externalOutcome then "External" else "Review"
		data.route = route
		data.routeSelectable = data.joined
			and event ~= nil
			and event.Phase == "Active"
			and data.ready
			and (event.Stage == "vault" or event.Stage == "ball")
			and waypoint == 2
		data.startWaitSeconds = if event and event.Phase == "Inviting"
			then math.max(0, math.ceil(Config.EarliestStartSeconds - (os.clock() - event.CreatedAt)))
			else 0
		data.canStart = data.joined
			and event ~= nil
			and event.Phase == "Inviting"
			and event.StarterUserId == player.UserId
			and data.startWaitSeconds == 0
		data.isStarter = event ~= nil and event.StarterUserId == player.UserId
		data.canReady = data.joined
			and not data.ready
			and event ~= nil
			and (event.Phase == "Preparing" or event.Phase == "Active")
		data.trialActive = trial[player] ~= nil
		data.trialWave = trial[player] ~= nil and trial[player].Wave == true
		data.trialTargets = if trial[player] then table.clone(trial[player].Targets) else {}
		data.objective = "Talk to Mara to join, or Pip to try Broadwave."
		if event and data.joined then
			if event.Phase == "Inviting" then
				data.objective = if event.StarterUserId ~= player.UserId
					then "Waiting for the host to start."
					elseif data.startWaitSeconds > 0 then "Begin available in " .. data.startWaitSeconds .. "s."
					else "Press Begin when you are ready to rescue the ball."
			elseif data.canReady then
				data.objective = "Press Begin helping to join the rescue."
			elseif event.Stage == "anchors" then
				for index, shape in { "Triangle", "Square", "Circle" } do
					local anchor = event.Anchors[Config.AnchorIds[index]]
					if not anchor.Completed then
						data.objective = shape .. " anchor: " .. anchor.Work .. "/" .. anchor.Required .. " scoops."
						break
					end
				end
			elseif event.Stage == "vault" then
				data.objective = "Anchors clear. Open the vault latch."
			elseif event.Stage == "ball" then
				data.objective = route
					.. " route • "
					.. (if data.hauling then "Walk along the channel" else "Attach near the ball")
					.. " • gate "
					.. math.min(event.GateIndex + 1, 3)
					.. "/3."
			else
				data.objective = "Ball rescued · 3/3 gates. Leave when you are ready."
			end
		end
		data.objectives = {
			"Optional: talk to Mara to join Spring Surprise (about 4 minutes).",
			"Pip lends Broadwave: hold Ability for 0.8 seconds, release toward the marked patch; clear 3 practice targets.",
			"Clear three shaped anchors, open the latch, then guide the ball through three gates.",
			if externalOutcome
				then "Rewards and save status are handled separately."
				else "REVIEW ONLY  -  no coins, certifications or permanent trophies are granted.",
		}
		if not data.joined then
			data.objective = if trial[player]
				then (if not trial[player].Wave
					then "Equip Broadwave. Face the marked patch; hold Ability 0.8s, then release."
					elseif trial[player].Cleared < 3 then "Wave landed. Scoop practice targets: "
						.. trial[player].Cleared
						.. "/3."
					else "Trial complete. Talk to Mara to join the rescue.")
				else "Optional: talk to Mara to join, or Pip to try Broadwave."
		end
		snapshot:FireClient(player, data)
	end
	local function broadcast()
		for _, player in Players:GetPlayers() do
			send(player)
		end
	end
	local function resetEvent()
		for player in returns do
			trial[player] = nil
			restore(player)
		end
		scene.Destroy()
		scene = Scene.Build(workspace, opts.Origin, opts.ReviewSpawn)
		self.Scene = scene
		event = nil
		waypoint = 2
		checkpointWaypoint = 2
		haulWork = {}
		movementBanks = {}
		stagesSent = {}
		checkpoint = scene.BallStart
		ballPosition = checkpoint
		ballResetAt = nil
		completionSent = false
		route = "Left"
		lastBounce = 0
		broadcast()
	end
	local function newEvent(player: Player)
		sequence += 1
		event = State.new(Config, session .. ":" .. sequence, player.UserId, os.clock())
		completionSent = false
	end
	local function handle(player: Player, payload: any)
		if stopped or not limiter:Check(player) then
			return
		end
		if type(payload) ~= "table" or type(payload.action) ~= "string" or #payload.action > 32 then
			return
		end
		local action = payload.action
		local targetId = payload.targetId
		if targetId ~= nil and (type(targetId) ~= "string" or #targetId > 64) then
			return
		end
		if action == "Sync" then
			send(player)
			return
		end
		if action == "Ignore" then
			send(player, "Invitation dismissed. Ordinary digging stays available.")
			return
		end
		if action == "Talk" then
			if (targetId ~= "npc_mara" and targetId ~= "npc_pip") or not near(player, scene.Targets[targetId], 10) then
				return
			end
			if targetId == "npc_pip" then
				if not opts.CanTrial or not opts.CanTrial(player) then
					send(player, "Pip's trial unlocks after the first shovel purchase.")
					return
				end
				trial[player] = trial[player] or { Wave = false, Cleared = 0, Targets = {} }
				if not returns[player] and player.Character then
					returns[player] = player.Character:GetPivot()
				end
				loan(player)
				send(player, "Pip: Try a Broadwave on the dark patch, then scoop three targets.")
			else
				send(player, "Mara: Help uncover the giant chest? Join for a four-minute rescue.")
			end
			return
		end
		if action == "Join" then
			if not opts.CanEnter or not opts.CanEnter(player) or not near(player, scene.Targets.npc_mara, 10) then
				send(
					player,
					if opts.ReviewSpawn == true
						then "Mara's adventure unlocks after a sale and scanner deposit. Review uses an explicit starter loan."
						else "Spring Vault opens after your Rookie certificate, or once you have sold sand and dug up a deposit."
				)
				return
			end
			local created = not event
			if not event then
				newEvent(player)
			end
			if
				payload.eventInstanceId ~= ""
				and payload.eventInstanceId ~= nil
				and payload.eventInstanceId ~= event.EventInstanceId
			then
				return
			end
			local ok, reason = true, "joined"
			if not created then
				ok, reason = event:join(player.UserId, os.clock())
			end
			if ok then
				-- The optional practice session ends when the main rescue accepts the player.
				trial[player] = nil
				cancel(player)
				local part = root(player)
				if part and not returns[player] then
					returns[player] = (player.Character :: Model):GetPivot()
				end
				loan(player)
				send(
					player,
					if reason == "rejoined"
						then "Rejoined. Your contribution is preserved; attach to the ball again when ready."
						elseif
							event.Phase == "Active"
						then "Joined. Press Begin helping to help with the current objective."
						else "Invitation accepted. Press Begin when you are ready."
				)
			else
				send(player, reason)
			end
			broadcast()
			return
		end
		local isTrial = trial[player] ~= nil
		local member = participant(player)
		if action == "Leave" and isTrial and (not member or member.Left or not member.Connected) then
			trial[player] = nil
			restore(player)
			send(player, "Practice finished. Talk to Mara when you want to join the rescue.")
			return
		end
		if action == "ChargeCancel" then
			cancel(player)
			return
		end
		if action == "ChargeBegin" then
			if not usableAbility(player) or os.clock() < (nextWave[player] or 0) then
				return
			end
			if not isTrial and not opts.OnOrdinaryBroadwave and (not member or not member.Present) then
				return
			end
			if charges[player] then
				return
			end
			local tool = equippedAbilityTool(player)
			if not tool then
				return
			end
			charges[player] = {
				At = os.clock(),
				Character = player.Character :: Model,
				Tool = tool,
				Unequipped = tool.Unequipped:Connect(function()
					cancel(player)
				end),
			}
			effect:FireAllClients({
				kind = "Charge",
				playerUserId = player.UserId,
				frame = (root(player) :: BasePart).CFrame,
			})
			return
		end
		if action == "ChargeRelease" then
			local began = charges[player]
			cancel(player)
			local part = root(player)
			if
				not began
				or not part
				or not usableAbility(player)
				or began.Character ~= player.Character
				or began.Tool ~= equippedAbilityTool(player)
				or os.clock() - began.At < Config.BroadwaveChargeSeconds
				or os.clock() - began.At > 10
				or os.clock() < (nextWave[player] or 0)
			then
				return
			end
			local direction = Vector3.new(part.CFrame.LookVector.X, 0, part.CFrame.LookVector.Z)
			if direction.Magnitude < 0.01 then
				return
			end
			local frame = CFrame.lookAt(part.Position, part.Position + direction.Unit)
			local changed = false
			local ordinaryReason: string? = nil
			-- Only whitelisted mutable targets; no Terrain writes or generic object deletion.
			if
				isTrial
				and opts.CanTrial ~= nil
				and opts.CanTrial(player)
				and not trial[player].Wave
				and near(player, scene.Targets.trial_patch, Config.BroadwaveRange)
				and Rules.InCorridor(
					frame,
					scene.Targets.trial_patch,
					Vector3.new(Config.BroadwaveWidth, Config.BroadwaveHeight, 8)
				)
			then
				trial[player].Wave = true
				changed = true
			elseif event and member and member.Present and event.Phase == "Active" then
				for _, id in { "vault_anchor_1", "vault_anchor_2", "vault_anchor_3" } do
					if
						near(player, scene.Targets[id], Config.BroadwaveRange)
						and Rules.InCorridor(
							frame,
							scene.Targets[id],
							Vector3.new(Config.BroadwaveWidth, Config.BroadwaveHeight, 8)
						)
					then
						-- 0.8/.5 equivalent work, capped by actual remaining work in core.
						local ok = event:hitAnchor(
							player.UserId,
							id,
							os.clock(),
							Rules.OrdinaryEquivalent(
								Config.BroadwaveChargeSeconds,
								Config.HitCooldownSeconds,
								Config.BroadwaveWork
							)
						)
						if ok then
							changed = true
							break
						end
					end
				end
			end
			if
				not changed
				and opts.OnOrdinaryBroadwave
				and began.Tool ~= tools[player]
				and began.Tool:GetAttribute("AdventureLoan") ~= true
			then
				local called, accepted, reason = pcall(opts.OnOrdinaryBroadwave, player, frame, os.clock() - began.At)
				changed = called and accepted == true
				ordinaryReason = if called then reason else "Ordinary Broadwave is unavailable."
				if not called then
					warn("[SpringVault] ordinary dig boundary failed")
				end
			end
			if changed then
				nextWave[player] = os.clock() + Config.BroadwaveCooldownSeconds
				effect:FireAllClients({ kind = "Wave", frame = frame, playerUserId = player.UserId })
				send(player, "Broadwave released.")
			else
				send(
					player,
					ordinaryReason
						or "Point toward a filled marked target within 12 studs. Protected and empty targets give no progress."
				)
			end
			broadcast()
			return
		end
		if
			action == "Excavate"
			and isTrial
			and type(targetId) == "string"
			and string.match(targetId, "^trial_target_[123]$")
		then
			if
				not trial[player].Wave
				or not near(player, scene.Targets[targetId], 12)
				or trial[player].Targets[targetId]
			then
				return
			end
			if os.clock() - (trial[player].LastHit or -math.huge) < Config.HitCooldownSeconds then
				return
			end
			trial[player].LastHit = os.clock()
			trial[player].Targets[targetId] = true
			trial[player].Cleared += 1
			send(
				player,
				if trial[player].Cleared == 3
					then "Pip: Excellent! Broadwave trial complete. No permanent license or trial coins awarded in review."
					else "Practice target cleared."
			)
			return
		end
		if
			not event
			or payload.eventInstanceId ~= event.EventInstanceId
			or not member
			or member.Left
			or not member.Connected
		then
			return
		end
		-- Leaving stays available after walking out of the bounded arena or dying.
		if action == "Leave" then
			event:leave(player.UserId, os.clock(), false)
			trial[player] = nil
			restore(player)
			broadcast()
			return
		end
		if not member.Present then
			return
		end
		local now = os.clock()
		local ok, reason = false, "Unavailable"
		local feedback: string? = nil
		if action == "Start" then
			ok, reason = event:start(player.UserId, now)
		elseif action == "Ready" then
			ok, reason = event:ready(player.UserId, now)
		elseif action == "Excavate" then
			if
				type(targetId) ~= "string"
				or not scene.Anchors[targetId]
				or not near(player, scene.Targets[targetId], 12)
			then
				return
			end
			ok, reason = event:hitAnchor(player.UserId, targetId, now, 1)
		elseif action == "OpenVault" then
			if not near(player, scene.Targets.vault_latch, 10) then
				return
			end
			ok, reason = event:openVault(player.UserId, now)
			if ok then
				scene.OpenVault()
				scene.SpawnBall()
				ballPosition = scene.BallStart
				checkpoint = ballPosition
				feedback = "Vault open. " .. route .. " route selected; attach near the ball."
			end
		elseif action == "PushBall" then
			if not near(player, ballPosition, 8) then
				return
			end
			ok, reason = event:latch(player.UserId, not member.Attached, now)
			if ok then
				lastPositions[player] = (root(player) :: BasePart).Position
				lastMovementAt[player] = now
				movementBanks[player.UserId] = nil
				feedback = if member.Attached
					then "Attached. Walk along the " .. string.lower(route) .. " channel."
					else "Detached from the ball."
			end
		elseif action == "ResetBall" then
			if not near(player, scene.Targets.ball_reset, 10) then
				return
			end
			if event.Phase ~= "Active" or event.Stage ~= "ball" or not member.Ready then
				return
			end
			-- Repeated requests cannot postpone recovery indefinitely.
			ballResetAt = ballResetAt or now + 3
			feedback = "Ball recovery requested. Returning to the last gate in three seconds."
			ok = true
		elseif action == "RouteLeft" or action == "RouteRight" then
			if
				waypoint ~= 2
				or event.Phase ~= "Active"
				or not member.Ready
				or (event.Stage ~= "vault" and event.Stage ~= "ball")
				or not near(player, scene.Targets.vault_latch, 12)
			then
				return
			end
			route = if action == "RouteLeft" then "Left" else "Right"
			feedback = route .. " route selected. Attach to the ball, then walk along that channel."
			ok = true
		else
			return
		end
		if not ok then
			feedback = reason
		end
		for id, anchor in event.Anchors do
			scene.SetAnchorProgress(id, anchor.Work / anchor.Required)
		end
		broadcast()
		if feedback then
			send(player, feedback)
		end
	end
	table.insert(
		connections,
		intent.OnServerEvent:Connect(function(player: Player, payload: any)
			local ok, err = pcall(function()
				handle(player, payload)
				return true
			end)
			if not ok then
				warn("[SpringVault] rejected failed intent", err)
			end
		end)
	)
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(player)
			if event then
				event:leave(player.UserId, os.clock(), true)
			end
			restore(player)
			trial[player] = nil
			nextWave[player] = nil
			limiter:Remove(player)
		end)
	)
	table.insert(
		connections,
		RunService.Heartbeat:Connect(function(delta: number)
			if stopped then
				return
			end
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				local p = participant(player)
				if root(player) and ((p and not p.Left and p.Connected) or trial[player]) then
					loan(player)
				end
			end
			for player in walkSpeeds do
				local p = participant(player)
				if not p or not p.Attached then
					releaseSpeed(player)
				end
			end
			for player, charge in charges do
				if now - charge.At > 10 or not usableAbility(player) or charge.Character ~= player.Character then
					cancel(player)
				end
			end
			if event then
				for _, player in Players:GetPlayers() do
					local p = event.Participants[player.UserId]
					local part = root(player)
					if p then
						event:setPresence(
							player.UserId,
							part ~= nil
								and math.abs((part :: BasePart).Position.X - scene.Origin.X) <= 48
								and math.abs((part :: BasePart).Position.Z - (scene.Origin.Z - 36)) <= 69
								-- Surface players directly above the pocket are absent; falling players
								-- stay present so the existing checkpoint recovery can still rescue them.
								and (part :: BasePart).Position.Y <= scene.Origin.Y + 20,
							now
						)
						if p.Left and returns[player] then
							restore(player)
						end
					end
				end
				event:tick(now)
				reportStages()
				if event.Phase == "Active" and event.Stage == "ball" then
					local moving: { number } = {}
					local attachedCount = 0
					for _, p in event.Participants do
						if p.Attached and p.Present and not p.Left then
							attachedCount += 1
						end
					end
					local path = scene.Routes[route]
					local goal = path[waypoint]
					for _, player in Players:GetPlayers() do
						local member = participant(player)
						local part = root(player)
						if member and member.Present and member.Attached then
							if not part or not near(player, ballPosition, 8) then
								event:latch(player.UserId, false, now)
								movementBanks[player.UserId] = nil
							else
								local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
								if h then
									if walkSpeeds[player] and walkSpeeds[player].Humanoid ~= h then
										releaseSpeed(player)
									end
									walkSpeeds[player] = walkSpeeds[player] or { Humanoid = h, Speed = h.WalkSpeed }
									h.WalkSpeed = if attachedCount >= 2 then Config.CrewSpeed else Config.SoloSpeed
								end
								local previous = lastPositions[player] or part.Position
								local displacement = part.Position - previous
								lastPositions[player] = part.Position
								if displacement.Magnitude > 0.005 then
									local elapsed = now - (lastMovementAt[player] or now - delta)
									lastMovementAt[player] = now
									if goal and (goal - ballPosition).Magnitude > 0.01 then
										HaulBudget.Record(
											movementBanks,
											player.UserId,
											displacement:Dot((goal - ballPosition).Unit),
											displacement.Magnitude,
											elapsed
										)
									end
								end
								table.insert(moving, player.UserId)
							end
						else
							movementBanks[player.UserId] = nil
						end
						if member and member.Present and part then
							if part.Position.Y < scene.Origin.Y - 10 then
								recovery[player] = recovery[player] or now + 2
								if now >= recovery[player] then
									(player.Character :: Model):PivotTo(CFrame.new(checkpoint + Vector3.new(0, 2, 6)))
									recovery[player] = nil
								end
							else
								recovery[player] = nil
							end
						end
					end
					if ballResetAt and now >= ballResetAt then
						scene.ResetBall(checkpoint)
						ballPosition = checkpoint
						waypoint = checkpointWaypoint
						haulWork = {}
						movementBanks = {}
						moving = {}
						for _, player in Players:GetPlayers() do
							local member = participant(player)
							if member then
								member.Attached = false
							end
							releaseSpeed(player)
							lastPositions[player] = nil
						end
						ballResetAt = nil
					end
					if not ballResetAt and #moving > 0 and goal then
						local difference = goal - ballPosition
						local distance, shares = HaulBudget.Consume(
							movementBanks,
							moving,
							math.min(
								difference.Magnitude,
								(if attachedCount >= 2 then Config.CrewSpeed else Config.SoloSpeed)
									* math.min(delta, 0.1)
							)
						)
						for userId, used in shares do
							haulWork[userId] = (haulWork[userId] or 0) + used
						end
						if difference.Magnitude > 0.01 then
							ballPosition += difference.Unit * distance
							scene.MoveBall(ballPosition)
						end
						if distance > 0 and (goal - ballPosition).Magnitude < 0.15 then
							ballPosition = goal
							waypoint += 1
							movementBanks = {}
							for _, gate in scene.Gates do
								if
									waypoint - 1 == gate.WaypointIndex
									and (ballPosition - gate.Position).Magnitude <= gate.Radius
								then
									local accepted = event:advanceBallGate(gate.Id, now, haulWork)
									if accepted then
										checkpoint = ballPosition
										checkpointWaypoint = waypoint
										haulWork = {}
										effect:FireAllClients({
											kind = "Gate",
											frame = CFrame.new(ballPosition),
											targetId = gate.Id,
										})
									end
								end
							end
							if now - lastBounce >= 0.6 then
								lastBounce = now
								effect:FireAllClients({
									kind = "Bounce",
									frame = CFrame.new(ballPosition - Vector3.new(0, 3.8, 0)),
								})
							end
						end
					end
					if ballPosition.Y < scene.Origin.Y - 6 or (ballPosition - scene.Origin).Magnitude > 180 then
						ballResetAt = ballResetAt or now + 3
					end
				end
				if event.Phase == "Resolving" and not completionSent then
					completionSent = true
					completionPending = true
					local context = event:completionContext(now)
					if context then
						context.ContentVersion = Config.ContentVersion
						context.CompletedAtUnix = os.time()
						context = immutable(context)
						local called, accepted, message = pcall(submit, context)
						if not called then
							accepted = false
							message = "Completion handoff failed; no rewards confirmed."
							warn("[SpringVault] completion boundary failed")
						end
						-- A callback summary cannot describe each player's settlement result.
						-- Ordinary world snapshots still broadcast, but completion feedback is participant-only.
						for _, result in context.Participants do
							local player = Players:GetPlayerByUserId(result.UserId)
							if player then
								send(player, if externalOutcome and called then "Ball rescued." else message)
							end
						end
						-- Review context is captured, never represented as Rewarded/settled.
						self.LastCompletion = context
						self.Settled = accepted
					end
					completionPending = false
				end
				if
					event.Phase == "Resolving"
					and event.CompletedAt
					and now - event.CompletedAt >= 12
					and not completionPending
				then
					event:cleanup(now)
				end
				if event.Phase == "Cleanup" then
					self.LastFailure = if event.FailureReason then observations(nil, event.FailureReason) else nil
					if self.LastFailure and opts.OnFailure then
						local ok, err = pcall(function()
							(opts.OnFailure :: (any) -> ())(self.LastFailure)
							return true
						end)
						if not ok then
							warn("[SpringVault] failure boundary failed", err)
						end
					end
					resetEvent()
				end
			end
			if now - lastBroadcast >= 1 then
				lastBroadcast = now
				broadcast()
			end
		end)
	)
	function self.Handle(player: Player, payload: any)
		handle(player, payload)
	end
	function self.ReviewPlayer(player: Player): any
		return {
			Trial = trial[player] and immutable(trial[player]) or nil,
			Loan = tools[player] ~= nil,
			Charging = charges[player] ~= nil,
			CooldownUntil = nextWave[player],
		}
	end
	function self.Event(): any
		return event
	end
	function self.Destroy()
		if stopped then
			return
		end
		stopped = true
		for _, connection in connections do
			connection:Disconnect()
		end
		for _, player in Players:GetPlayers() do
			restore(player)
		end
		scene.Destroy()
		remotes:Destroy()
	end
	return self
end
return Service
