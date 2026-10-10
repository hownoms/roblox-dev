# Loaded Studio before any change (10 October 2026)

Studio MCP `list_roblox_studios`: two Studios, `DigTheBeach.rbxlx` (production place; never
touched by this work) and `Expansion1Review.rbxlx` (the only authorized target).

Expansion1Review, Edit DataModel, inspected read-only before anything was installed:

- `game.Name` = `Expansion1Review.rbxlx`, PlaceId 0, GameId 0, CreatorId 0.
- HttpEnabled false, Workspace.StreamingEnabled false. Workspace held only Camera and Terrain.
- No production `ServerScriptService.Server` (no production Main) and an empty ServerStorage.
- Codex's dedicated review boot: `ServerScriptService.AdventureReview` (enabled),
  `ServerScriptService.Adventure` (7 modules, including `TemporaryReviewCompletionAdapter`),
  `ReplicatedStorage.SpringVaultClient`, `StarterPlayerScripts.AdventureReview` (enabled), and the
  expansion visual kit script `ServerScriptService.ExpansionReview` (disabled). Its
  `ReplicatedStorage.Shared` was an older copy (no Rewards/Trophies folders).

Shortly after this inspection the place entered Play, and not from this session. The Server
DataModel ran Codex's dedicated review (`AdventureReview`, `AdventureReviewProbe`) with one
player. In a Play server `game.Name` reads `Game`, so the candidate authorization is stamped on
the `ProductionCandidate` folder at install time (checked against the Edit place name) instead of
being read from `game.Name` at runtime. This session waited and did not stop or alter that Play
session.
