--!strict
-- Dedicated review only. No production services, player saves or reward grants are loaded.
local RunService = game:GetService("RunService")
assert(RunService:IsStudio(), "Adventure review is local Studio only")
local Service = require(script.Parent.Adventure.SpringVaultService)
local runtime = Service.Start({
	Origin = Vector3.new(700, 20, 0),
	CanEnter = function(_player: Player): boolean
		return true
	end,
	CanTrial = function(_player: Player): boolean
		return true
	end,
})
-- Review inspection handle is never installed in production boot.
_G.SpringVaultReview = runtime
script.Destroying:Connect(function()
	runtime.Destroy()
end)
print("[SpringVault REVIEW] starter/prerequisite loans enabled; permanent rewards DISABLED")
