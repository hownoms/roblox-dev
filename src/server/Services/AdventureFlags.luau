--!strict
--[[
	AdventureFlags — server-owned enablement for the expansion adventure (docs/integration/
	production-wiring.md). Lives in ServerScriptService, so clients can neither read nor change it.
	Read once, by AdventureBoot.Init, at server boot. Every flag ships OFF.

	LocalOnly candidate: when (and only when) CandidateProfile resolves LocalOnly (a validated
	Studio-only review marker, PlaceId/GameId 0, no DataStore at all), the candidate config's
	Flags overlay these values at first require. The shipped values below stay false; Production
	and Refused servers never overlay anything (and a Refused server starts nothing).

	  SpringVault        start SpringVaultService (Mara/Pip arena, remotes, scene). Off: no runtime,
	                     no ReplicatedStorage.SpringVaultAdventure folder, no scene, no loans; the
	                     client adapter never starts because that folder never appears.
	  AdventureRewards   pass AdventureSettlement.OnStage/OnCompletion to the runtime and enable new
	                     settlements. Off (with SpringVault on): the runtime still runs, settlement is
	                     disabled and refuses every new stage/final (no coins, trophy, stand or cert).
	                     Outbox drains of already-accepted grants continue either way.
	  BroadwaveOrdinary  ordinary (sand-yielding) Broadwave: wire BroadwaveDigBridge as
	                     OnOrdinaryBroadwave and issue licensed Broadwave tools. Needs SpringVault
	                     (the runtime owns the charge input). Even when on, a player needs the saved
	                     ToolLicenses.tool_broadwave license, which nothing in this slice grants.

	Kill switch: set the flag to false and publish; new servers boot without the feature. Running
	servers keep their boot-time value; AdventureBoot.Disable() is the in-server kill switch
	(stops the runtime, disables settlement, removes licensed tools).
	Tests may assign fields before Main runs; production code never writes them.
]]

local AdventureFlags = {
	SpringVault = false,
	AdventureRewards = false,
	BroadwaveOrdinary = false,
}

local candidateFlags = require(script.Parent.CandidateProfile).Flags()
if candidateFlags then
	for name, value in candidateFlags do
		(AdventureFlags :: any)[name] = value
	end
end

return AdventureFlags
