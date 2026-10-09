--!strict
--[[
	TrophyPendingStore — durable outbox for accepted trophy grants that could not be applied to
	a loaded save on this server (the player's data is not loaded here).

	A DurableOutbox (see that module for the exactly-once protocol): settlement writes the intent
	before reporting PendingRejoin; the player's next load on ANY server applies it, saves, and
	only then acknowledges it.

	Storage: DataStore STORE_NAME, key "Pending_<UserId>", value { Grants = { [receiptId] =
	{ TrophyId, Source, RegionId, At } } }.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rules = require(ReplicatedStorage.Shared.Trophies.Rules)
local DurableOutbox = require(script.Parent.DurableOutbox)

export type PendingGrant = {
	TrophyId: string,
	Source: string,
	RegionId: string,
	At: number,
}

local outbox = DurableOutbox.new("TrophyPendingGrants_v1", 8, Rules.IsPendingGrant)

local Pending = {}

Pending.STORE_NAME = outbox.StoreName
Pending.MAX_PER_USER = outbox.MaxPerUser

Pending.Init = outbox.Init
Pending.IsAvailable = outbox.IsAvailable
Pending.Ack = outbox.Ack

-- Durably records one grant. Yields. Returns (true) or (false, "PendingFull" | "PendingWriteFailed").
function Pending.Add(userId: number, receiptId: string, grant: PendingGrant): (boolean, string?)
	return outbox.Add(userId, receiptId, {
		TrophyId = grant.TrophyId,
		Source = grant.Source,
		RegionId = grant.RegionId,
		At = grant.At,
	})
end

-- Latest pending grants for a user (validated), or nil if the read failed. Yields.
function Pending.Read(userId: number): { [string]: PendingGrant }?
	return outbox.Read(userId) :: any
end

return Pending
