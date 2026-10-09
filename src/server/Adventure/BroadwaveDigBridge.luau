--!strict
-- Optional server adapter. Requiring this module never boots production services or changes saves.
-- CanUse must read server-owned Broadwave license/prerequisite evidence; loans alone grant nothing.
local Bridge = {}
export type Options = {
	CanUse: (Player, Tool) -> boolean,
	Dig: (Player, Vector3) -> { Success: boolean, Reason: string? }?,
}
function Bridge.Create(options: Options): (Player, CFrame, number) -> (boolean, string?)
	assert(type(options.CanUse) == "function", "Broadwave requires authoritative eligibility")
	assert(type(options.Dig) == "function", "Broadwave requires DigService.DigBroadwave")
	local Config = require(game:GetService("ReplicatedStorage").Shared.Adventure.SpringVaultConfig)
	local workspace = game:GetService("Workspace")
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = true
	local nextRelease = setmetatable({} :: { [Player]: number }, { __mode = "k" })
	return function(player: Player, frame: CFrame, chargedSeconds: number): (boolean, string?)
		if
			typeof(frame) ~= "CFrame"
			or type(chargedSeconds) ~= "number"
			or chargedSeconds ~= chargedSeconds
			or chargedSeconds < Config.BroadwaveChargeSeconds
			or chargedSeconds > 10
		then
			return false, "Hold Broadwave for 0.8 seconds before releasing."
		end
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local tool = if character then character:FindFirstChildOfClass("Tool") else nil
		if
			not humanoid
			or humanoid.Health <= 0
			or not root
			or not root:IsA("BasePart")
			or not tool
			or tool:GetAttribute("AdventureLoan") == true
			or tool:GetAttribute("ToolId") ~= Config.ToolId
			or not options.CanUse(player, tool)
		then
			return false, "Equip Broadwave with an unlocked ordinary digging license."
		end
		local direction = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if
			direction.Magnitude < 0.01
			or (frame.Position - root.Position).Magnitude > 0.1
			or frame.LookVector:Dot(direction.Unit) < 0.999
		then
			return false, "Face the sand before releasing Broadwave."
		end
		local now = os.clock()
		if now < (nextRelease[player] or 0) then
			return false, "Broadwave is recovering."
		end
		-- One bounded scoop, never a loop of duplicate payouts or arbitrary client positions.
		local aim = root.Position + direction.Unit * 6
		local hit = workspace:Raycast(aim + Vector3.new(0, 2, 0), Vector3.new(0, -12, 0), params)
		if not hit then
			return false, "Face ordinary beach sand within shovel reach."
		end
		local result = options.Dig(player, hit.Position)
		if not result or not result.Success then
			return false, if result and result.Reason then result.Reason else "No filled ordinary sand in reach."
		end
		nextRelease[player] = now + Config.BroadwaveCooldownSeconds
		return true, "Broadwave scooped ordinary sand."
	end
end
return Bridge
