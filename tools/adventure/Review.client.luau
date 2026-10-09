--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Client = require(ReplicatedStorage:WaitForChild("SpringVaultClient"))
local handle =
	Client.Start(ReplicatedStorage:WaitForChild("SpringVaultAdventure"), workspace:WaitForChild("SpringVaultAdventure"))
script.Destroying:Connect(function()
	handle.Destroy()
end)
