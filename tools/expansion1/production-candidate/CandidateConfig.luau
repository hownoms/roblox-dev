--!strict
--[[
	Owner-reviewed server-only configuration for the local Spring Vault production candidate
	(docs/integration/production-candidate.md). Mapped only by
	expansion1-production-candidate.project.json as ServerScriptService.ProductionCandidate.
	CandidateConfig; never by default.project.json.

	CandidateProfile (src/server/Services) reads this before Main creates remotes or initializes a
	single service. It is honoured only in Studio, in an unpublished place (PlaceId 0, GameId 0)
	whose folder was stamped by the installer as the authorized Expansion1Review file. Anywhere
	else the server refuses to start at all.

	Storage = "LocalOnly": saves, both reward outboxes, purchase history and leaderboards stay in
	memory and no DataStore is acquired. Every reward in a candidate session is local simulation.
	Flags: the shipped AdventureFlags stay false in source; these values apply to this candidate
	server only.
]]

return {
	Authorization = "Expansion1Review",
	Storage = "LocalOnly",
	Flags = {
		SpringVault = true,
		AdventureRewards = true,
		BroadwaveOrdinary = true,
	},
}
