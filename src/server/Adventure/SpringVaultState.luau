--!strict
-- Pure server progression. Runtime validates geometry, identity, requests and authoritative time.
-- No Instances, client effects, player save mutation, currency or reward settlement belong here.
export type Config = {
	EventId: string,
	LandmarkId: string,
	RegionId: string,
	AnchorIds: { string },
	GateIds: { string },
	MinPlayers: number,
	MaxPlayers: number,
	EarliestStartSeconds: number,
	InvitationSeconds: number,
	ReadyTimeoutSeconds: number,
	ActiveSeconds: number,
	AdmissionLockSeconds: number,
	AbandonSeconds: number,
	DisconnectHoldSeconds: number,
	SoloAnchorWork: number,
	CrewAnchorWork: number,
	HitCooldownSeconds: number,
	AnchorPoints: number,
	GatePoints: number,
	MinimumPoints: number,
	MinimumActiveSeconds: number,
	CompletionBoundaryVersion: number,
}
export type Participant = {
	UserId: number,
	JoinedAt: number,
	ActiveJoinedAt: number?,
	ActiveSeconds: number,
	PresenceSince: number?,
	Ready: boolean,
	Connected: boolean,
	Present: boolean,
	Left: boolean,
	DisconnectedAt: number?,
	Points: number,
	Objectives: { string },
	LastHitAt: number,
	Attached: boolean,
}
export type Anchor = { Work: number, Required: number, Completed: boolean, Workers: { [number]: number } }
export type CompletionParticipant = {
	UserId: number,
	Points: number,
	Eligible: boolean,
	ActiveSeconds: number,
	ObjectiveIds: { string },
}
export type CompletionContext = {
	BoundaryVersion: number,
	EventInstanceId: string,
	EventId: string,
	LandmarkId: string,
	RegionId: string,
	StartedAt: number?,
	CompletedAt: number?,
	Success: boolean,
	ObjectiveIds: { string },
	CompletedStages: { string },
	Participants: { CompletionParticipant },
}
export type ParticipantSnapshot = {
	UserId: number,
	Ready: boolean,
	Connected: boolean,
	Present: boolean,
	Points: number,
	Attached: boolean,
}
export type Snapshot = {
	EventInstanceId: string,
	Phase: string,
	Stage: string,
	GateIndex: number,
	Anchors: { [string]: { Work: number, Required: number, Completed: boolean } },
	Participants: { ParticipantSnapshot },
	RemainingSeconds: number,
	AdmissionLocked: boolean,
	FailureReason: string?,
}
export type Data = {
	Config: Config,
	EventInstanceId: string,
	StarterUserId: number,
	CreatedAt: number,
	Phase: string,
	Stage: string,
	PreparingAt: number?,
	ActiveAt: number?,
	Deadline: number?,
	CompletedAt: number?,
	FailureReason: string?,
	EmptySince: number?,
	AdmissionLocked: boolean,
	Participants: { [number]: Participant },
	Anchors: { [string]: Anchor },
	GateIndex: number,
	CompletedObjectives: { string },
	CompletedStages: { string },
	InitialCrewSize: number,
	LastTickAt: number,
}
local State = {}
State.__index = State
export type State = typeof(setmetatable({} :: Data, State))

local function participant(self: State, userId: number): Participant?
	local p = self.Participants[userId]
	if p and not p.Left and p.Connected and p.Present and p.Ready then
		return p
	end
	return nil
end

local function closePresence(p: Participant, now: number)
	if p.PresenceSince then
		p.ActiveSeconds += math.max(0, now - p.PresenceSince)
		p.PresenceSince = nil
	end
end

local function credit(self: State, id: string, shares: { [number]: number }, total: number, points: number)
	table.insert(self.CompletedObjectives, id)
	for userId, work in shares do
		local p = self.Participants[userId]
		if p and total > 0 then
			p.Points += points * work / total
		end
	end
	-- Presence alone earns no points, but records witnessing a validated objective.
	for _, p in self.Participants do
		if participant(self, p.UserId) then
			table.insert(p.Objectives, id)
		end
	end
end

function State.new(config: Config, eventInstanceId: string, starterUserId: number, now: number): State
	assert(eventInstanceId ~= "", "A server-created EventInstanceId is required")
	local self: State = setmetatable({
		Config = config,
		EventInstanceId = eventInstanceId,
		StarterUserId = starterUserId,
		CreatedAt = now,
		Phase = "Inviting",
		Stage = "anchors",
		AdmissionLocked = false,
		Participants = {},
		Anchors = {},
		GateIndex = 0,
		CompletedObjectives = {},
		CompletedStages = {},
		InitialCrewSize = 0,
		LastTickAt = now,
	}, State)
	for _, id in config.AnchorIds do
		self.Anchors[id] = { Work = 0, Required = config.SoloAnchorWork, Completed = false, Workers = {} }
	end
	self:join(starterUserId, now)
	return self
end

function State.join(self: State, userId: number, now: number): (boolean, string)
	if self.Phase ~= "Inviting" and self.Phase ~= "Preparing" and self.Phase ~= "Active" then
		return false, "closed"
	end
	if self.AdmissionLocked or (self.Deadline and now >= self.Deadline - self.Config.AdmissionLockSeconds) then
		return false, "admission_locked"
	end
	local existing = self.Participants[userId]
	if existing and not existing.Left then
		return false, "already_joined"
	end
	-- A departed identity cannot erase its contribution/cooldown or collect twice by rejoining.
	if existing then
		return false, "departed"
	end
	local count = 0
	for _, p in self.Participants do
		if not p.Left then
			count += 1
		end
	end
	if count >= self.Config.MaxPlayers then
		return false, "full"
	end
	self.Participants[userId] = {
		UserId = userId,
		JoinedAt = now,
		ActiveJoinedAt = if self.Phase == "Active" then now else nil,
		ActiveSeconds = 0,
		Ready = false,
		Connected = true,
		Present = true,
		Left = false,
		Points = 0,
		Objectives = {},
		LastHitAt = -math.huge,
		Attached = false,
	}
	return true, "joined"
end

function State.start(self: State, userId: number, now: number): (boolean, string)
	if self.Phase ~= "Inviting" then
		return false, "wrong_phase"
	end
	if userId ~= self.StarterUserId then
		return false, "starter_only"
	end
	if not self.Participants[userId] or self.Participants[userId].Left then
		return false, "not_member"
	end
	if now - self.CreatedAt < self.Config.EarliestStartSeconds then
		return false, "too_early"
	end
	self.Phase = "Preparing"
	self.PreparingAt = now
	return true, "preparing"
end

function State.ready(self: State, userId: number, now: number): (boolean, string)
	if self.Phase ~= "Preparing" and self.Phase ~= "Active" then
		return false, "wrong_phase"
	end
	local p = self.Participants[userId]
	if not p or p.Left or not p.Connected then
		return false, "not_member"
	end
	if p.Ready then
		return false, "already_ready"
	end
	p.Ready = true
	if self.Phase == "Active" then
		p.ActiveJoinedAt = now
		if p.Present then
			p.PresenceSince = now
		end
	end
	return true, "ready"
end

function State.hitAnchor(self: State, userId: number, anchorId: string, now: number, work: number?): (boolean, string)
	if self.Phase ~= "Active" or self.Stage ~= "anchors" then
		return false, "wrong_stage"
	end
	if self.Deadline and now >= self.Deadline then
		return false, "expired"
	end
	local p = participant(self, userId)
	local anchor = self.Anchors[anchorId]
	if not p then
		return false, "not_ready_member"
	end
	if not anchor then
		return false, "unknown_anchor"
	end
	if anchor.Completed then
		return false, "completed"
	end
	if now - p.LastHitAt < self.Config.HitCooldownSeconds then
		return false, "cooldown"
	end
	local amount = work or 1
	if amount ~= amount or amount <= 0 or amount > 1 then
		return false, "invalid_work"
	end
	p.LastHitAt = now
	amount = math.min(amount, anchor.Required - anchor.Work)
	anchor.Work += amount
	anchor.Workers[userId] = (anchor.Workers[userId] or 0) + amount
	if anchor.Work >= anchor.Required then
		anchor.Completed = true
		credit(self, anchorId, anchor.Workers, anchor.Required, self.Config.AnchorPoints)
		local all = true
		for _, other in self.Anchors do
			if not other.Completed then
				all = false
			end
		end
		if all then
			self.Stage = "vault"
			table.insert(self.CompletedStages, "excavation")
		end
		return true, "anchor_completed"
	end
	return true, "worked"
end

function State.openVault(self: State, userId: number, now: number): (boolean, string)
	if self.Phase ~= "Active" or self.Stage ~= "vault" then
		return false, "wrong_stage"
	end
	if self.Deadline and now >= self.Deadline then
		return false, "expired"
	end
	if not participant(self, userId) then
		return false, "not_ready_member"
	end
	self.Stage = "ball"
	credit(self, "spring_vault_open", { [userId] = 1 }, 1, 5)
	table.insert(self.CompletedStages, "vault_open")
	return true, "vault_open"
end

function State.latch(self: State, userId: number, attached: boolean, now: number): (boolean, string)
	if self.Phase ~= "Active" or self.Stage ~= "ball" then
		return false, "wrong_stage"
	end
	if self.Deadline and now >= self.Deadline then
		return false, "expired"
	end
	local p = participant(self, userId)
	if not p then
		return false, "not_ready_member"
	end
	if p.Attached == attached then
		return false, "unchanged"
	end
	p.Attached = attached
	return true, if attached then "attached" else "detached"
end

function State.advanceBallGate(
	self: State,
	gateId: string,
	now: number,
	haulWork: { [number]: number }?
): (boolean, string)
	if self.Phase ~= "Active" or self.Stage ~= "ball" then
		return false, "wrong_stage"
	end
	if self.Deadline and now >= self.Deadline then
		return false, "expired"
	end
	if gateId ~= self.Config.GateIds[self.GateIndex + 1] then
		return false, "gate_sequence"
	end
	local shares: { [number]: number } = {}
	local count = 0
	if haulWork then
		-- Values are runtime-validated movement shares, never payload/client scores.
		for userId, work in haulWork do
			if work == work and work > 0 and work < math.huge and participant(self, userId) then
				shares[userId] = work
				count += work
			end
		end
	else
		for userId, p in self.Participants do
			if p.Attached and participant(self, userId) then
				shares[userId] = 1
				count += 1
			end
		end
	end
	if count == 0 then
		return false, "no_haulers"
	end
	self.GateIndex += 1
	credit(self, gateId, shares, count, self.Config.GatePoints)
	if self.GateIndex >= #self.Config.GateIds - 1 then
		self.AdmissionLocked = true
	end
	if self.GateIndex == #self.Config.GateIds then
		self.Phase = "Resolving"
		self.Stage = "complete"
		self.CompletedAt = now
		table.insert(self.CompletedStages, "ball_return")
		for _, p in self.Participants do
			p.Attached = false
			closePresence(p, now)
		end
		return true, "completed"
	end
	return true, "gate_completed"
end

function State.leave(self: State, userId: number, now: number, disconnected: boolean?): (boolean, string)
	local p = self.Participants[userId]
	if not p or p.Left or not p.Connected then
		return false, "not_member"
	end
	p.Attached = false
	closePresence(p, now)
	p.Present = false
	if disconnected then
		p.Connected = false
		p.DisconnectedAt = now
	else
		p.Left = true
	end
	return true, "left"
end

-- Runtime samples bounded arena presence; world spectators do not keep an empty event alive.
function State.setPresence(self: State, userId: number, present: boolean, now: number?): ()
	local p = self.Participants[userId]
	if p and not p.Left and p.Connected then
		local at = now or self.LastTickAt
		if not present then
			closePresence(p, at)
		elseif not p.Present and p.Ready and self.Phase == "Active" then
			p.PresenceSince = at
		end
		p.Present = present
		if not present then
			p.Attached = false
		end
	end
end

function State.tick(self: State, now: number): ()
	self.LastTickAt = now
	for _, p in self.Participants do
		if p.DisconnectedAt and now - p.DisconnectedAt >= self.Config.DisconnectHoldSeconds then
			p.Left = true
		end
		if self.Phase == "Active" and not p.Ready and now - p.JoinedAt >= self.Config.ReadyTimeoutSeconds then
			p.Left = true
		end
	end
	if self.Phase == "Inviting" and now - self.CreatedAt >= self.Config.InvitationSeconds then
		self.Phase = "Preparing"
		self.PreparingAt = now
	end
	if self.Phase == "Preparing" then
		local allReady = true
		local count = 0
		local timedOut = now - (self.PreparingAt or now) >= self.Config.ReadyTimeoutSeconds
		for _, p in self.Participants do
			if not p.Left then
				if not p.Ready or not p.Connected then
					if timedOut then
						p.Left = true
					else
						allReady = false
					end
				else
					count += 1
				end
			end
		end
		if allReady or timedOut then
			if count < self.Config.MinPlayers then
				self.Phase = "Cleanup"
				self.FailureReason = "no_ready_players"
				return
			end
			self.InitialCrewSize = count
			local required = if count == 1 then self.Config.SoloAnchorWork else self.Config.CrewAnchorWork
			for _, anchor in self.Anchors do
				anchor.Required = required
			end
			self.Phase = "Active"
			self.ActiveAt = now
			self.Deadline = now + self.Config.ActiveSeconds
			for _, p in self.Participants do
				if not p.Left then
					p.ActiveJoinedAt = now
					if p.Present then
						p.PresenceSince = now
					end
				end
			end
		end
	end
	if self.Phase == "Active" then
		local deadline = self.Deadline or now
		if now >= deadline - self.Config.AdmissionLockSeconds then
			self.AdmissionLocked = true
		end
		local count = 0
		for _, p in self.Participants do
			if participant(self, p.UserId) then
				count += 1
			end
		end
		if count == 0 then
			self.EmptySince = self.EmptySince or now
		else
			self.EmptySince = nil
		end
		if now >= deadline or (self.EmptySince and now - self.EmptySince >= self.Config.AbandonSeconds) then
			self.FailureReason = if now >= deadline then "timeout" else "abandoned"
			self.Phase = "Cleanup"
			self.AdmissionLocked = true
			for _, p in self.Participants do
				p.Attached = false
				closePresence(p, now)
			end
		end
	end
end

function State.completionContext(self: State, _now: number): CompletionContext?
	if self.Phase ~= "Resolving" or self.Stage ~= "complete" then
		return nil
	end
	local participants: { CompletionParticipant } = {}
	for userId, p in self.Participants do
		local duration = p.ActiveSeconds
		local eligible = not p.Left
			and p.Connected
			and p.Present
			and p.Points >= self.Config.MinimumPoints
			and (#p.Objectives > 0 or duration >= self.Config.MinimumActiveSeconds)
		table.insert(participants, {
			UserId = userId,
			Points = p.Points,
			Eligible = eligible,
			ActiveSeconds = duration,
			ObjectiveIds = table.clone(p.Objectives),
		})
	end
	table.sort(participants, function(a: CompletionParticipant, b: CompletionParticipant)
		return a.UserId < b.UserId
	end)
	return {
		BoundaryVersion = self.Config.CompletionBoundaryVersion,
		EventInstanceId = self.EventInstanceId,
		EventId = self.Config.EventId,
		LandmarkId = self.Config.LandmarkId,
		RegionId = self.Config.RegionId,
		StartedAt = self.ActiveAt,
		CompletedAt = self.CompletedAt,
		Success = true,
		ObjectiveIds = table.clone(self.CompletedObjectives),
		CompletedStages = table.clone(self.CompletedStages),
		Participants = participants,
	}
end

-- Called only after the runtime consumes completion context and displays review results.
-- This is cleanup, never a claim that permanent reward settlement was accepted.
function State.cleanup(self: State, now: number): ()
	for _, p in self.Participants do
		p.Attached = false
		closePresence(p, now)
	end
	self.Phase = "Cleanup"
	self.AdmissionLocked = true
end

function State.snapshot(self: State, now: number): Snapshot
	local anchors: { [string]: { Work: number, Required: number, Completed: boolean } } = {}
	for id, a in self.Anchors do
		anchors[id] = { Work = a.Work, Required = a.Required, Completed = a.Completed }
	end
	local participants: { ParticipantSnapshot } = {}
	for _, p in self.Participants do
		if not p.Left then
			table.insert(participants, {
				UserId = p.UserId,
				Ready = p.Ready,
				Connected = p.Connected,
				Present = p.Present,
				Points = p.Points,
				Attached = p.Attached,
			})
		end
	end
	table.sort(participants, function(a: ParticipantSnapshot, b: ParticipantSnapshot)
		return a.UserId < b.UserId
	end)
	return {
		EventInstanceId = self.EventInstanceId,
		Phase = self.Phase,
		Stage = self.Stage,
		GateIndex = self.GateIndex,
		Anchors = anchors,
		Participants = participants,
		RemainingSeconds = if self.Deadline then math.max(0, self.Deadline - now) else 0,
		AdmissionLocked = self.AdmissionLocked,
		FailureReason = self.FailureReason,
	}
end

return State
