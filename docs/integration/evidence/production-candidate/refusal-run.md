# Fail-closed refusal in Studio (10 October 2026, candidate 470465f)

Edit DataModel: `ServerScriptService.ProductionCandidate.AuthorizedPlace` set to
`SomeOtherPlace.rbxlx` (everything else as installed), then Play. Restored to
`Expansion1Review.rbxlx` afterwards.

Server output, first line:

    [CandidateProfile] REFUSED: AuthorizedPlace SomeOtherPlace.rbxlx is not an Expansion1Review place. Nothing was started

Server state 3 s into Play:

    ReplicatedStorage attributes: { CandidateProfile = "refused: AuthorizedPlace SomeOtherPlace.rbxlx is not an Expansion1Review place" }
    ReplicatedStorage children:   Shared, DefaultChatSystemChatEvents   (no Remotes.Net, no SpringVaultAdventure)
    Workspace children:           Camera, Terrain, the avatar           (World.Build never ran)
    player leaderstats:           none                                   (DataService never initialised)

The client prints "Infinite yield possible on Remotes:WaitForChild("Net")": the expected
fail-closed symptom, since no remote exists. No DataStore was touched: the refusal happens
before any service module is required.
