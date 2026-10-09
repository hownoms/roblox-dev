--!strict
-- Dedicated review only. No production services, player saves or reward grants are loaded.
local RunService = game:GetService("RunService")
assert(RunService:IsStudio(), "Adventure review is local Studio only")
local Service = require(script.Parent.Adventure.SpringVaultService)
local Players = game:GetService("Players")
local runtime = Service.Start({
	Origin = Vector3.new(700, 20, 0),
	ReviewSpawn = true,
	CanEnter = function(_player: Player): boolean
		return true
	end,
	CanTrial = function(_player: Player): boolean
		return true
	end,
})
-- Review inspection handle is never installed in production boot.
local probe = Instance.new("BindableFunction")
probe.Name = "AdventureReviewProbe"
local networkTrace: { any } = {}
local networkConnection = game.ReplicatedStorage.SpringVaultAdventure.Intent.OnServerEvent:Connect(
	function(player: Player, payload: any)
		table.insert(networkTrace, {
			UserId = player.UserId,
			At = os.clock(),
			Action = if type(payload) == "table" then payload.action else "InvalidPayload",
		})
		if #networkTrace > 200 then
			table.remove(networkTrace, 1)
		end
	end
)
probe.OnInvoke = function(command: string, payload: any, userId: number?): any
	local player = if userId then Players:GetPlayerByUserId(userId) else Players:GetPlayers()[1]
	if command == "NetworkTrace" then
		return table.clone(networkTrace)
	end
	if command == "Players" then
		local result = {}
		for _, current in Players:GetPlayers() do
			table.insert(
				result,
				{ UserId = current.UserId, Name = current.Name, State = runtime.ReviewPlayer(current) }
			)
		end
		return result
	end
	if command == "Player" and player then
		return runtime.ReviewPlayer(player)
	end
	if command == "Intent" and player then
		runtime.Handle(player, payload)
	end
	if command == "Destroy" then
		runtime.Destroy()
		return "Destroyed"
	end
	if command == "Completion" then
		return runtime.LastCompletion
	end
	if command == "Capture" then
		return runtime.ReviewAdapter.Contexts()
	end
	if command == "Scene" then
		return { Targets = runtime.Scene.Targets, Routes = runtime.Scene.Routes, Gates = runtime.Scene.Gates }
	end
	local event = runtime.Event()
	return if event then event:snapshot(os.clock()) else { Phase = "Dormant" }
end
probe.Parent = script.Parent
script.Destroying:Connect(function()
	networkConnection:Disconnect()
	runtime.Destroy()
end)
print("[SpringVault REVIEW] starter/prerequisite loans enabled; permanent rewards DISABLED")
