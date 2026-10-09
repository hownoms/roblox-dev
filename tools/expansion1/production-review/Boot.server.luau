--!strict
-- PRODUCTION-INTEGRATION REVIEW ONLY (docs/integration/production-review.md). Mapped by
-- expansion1-production-review.project.json, never by default.project.json. Refuses unless Studio,
-- PlaceId 0 and the review marker; then sets the review flags and enables the real, disabled
-- ServerScriptService.Server.Main.
local ServerScriptService = game:GetService("ServerScriptService")
local ReviewBoot = require(script.Parent.ReviewBoot)

ReviewBoot.Run({
	Marker = script.Parent,
	Server = ServerScriptService:WaitForChild("Server", 10),
})
