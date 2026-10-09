--!strict
--[[
	Trophies.Catalog — permanent adventure trophy records (first expansion slice).

	A trophy is a display entitlement, never a sellable item: it has no payout/sale value and is
	never converted into finds or coins. The trophy id is the landmark object id (the entitlement
	source); the adventure event id is only completion context (game bible ch.03 "Shared giant
	objects": object id and event/quest identity are separate; ch.04 "TrophyDef references a
	discovery record; no payout field").

	Only landmark_spring_vault exists in this slice. Its replica is
	Models.Expansion1.TrophyReplica() on a Models.Expansion1.TrophyStand() (assets/expansion1).
]]

export type TrophyDef = {
	Id: string,
	Kind: "Landmark",
	DisplayName: string,
	RegionId: string,
	-- events whose validated completion may grant this trophy
	Sources: { [string]: boolean },
	-- Models.Expansion1 factory that builds the display replica; nil = not displayable yet
	Replica: string?,
}

local Catalog = {}

local springVault: TrophyDef = {
	Id = "landmark_spring_vault",
	Kind = "Landmark",
	DisplayName = "Spring Vault Ball",
	RegionId = "sunshine_shore",
	Sources = table.freeze({ event_vault = true }),
	Replica = "TrophyReplica",
}

local trophies: { [string]: TrophyDef } = {
	landmark_spring_vault = table.freeze(springVault),
}
Catalog.Trophies = table.freeze(trophies)

-- Completion context -> the one landmark trophy it can settle.
Catalog.EventLandmarks = table.freeze({
	event_vault = "landmark_spring_vault",
}) :: { [string]: string }

function Catalog.Get(trophyId: any): TrophyDef?
	if type(trophyId) ~= "string" then
		return nil
	end
	return Catalog.Trophies[trophyId]
end

function Catalog.IsDisplayable(trophyId: any): boolean
	local def = Catalog.Get(trophyId)
	return def ~= nil and def.Replica ~= nil
end

return table.freeze(Catalog)
