--!nocheck
-- Real production DigService against the API-aware headless mock; no Studio or live saves.
local Mock = require("./mock/Roblox")
Mock.Init(require("../build/test/generated"))
local function load(path)
	return Mock.Require(Mock.ByPath[path])
end
local Config = load("ReplicatedStorage/Shared/Config")
for _, category in { Config.Monetization.GamePasses, Config.Monetization.Products, Config.Badges } do
	for _, item in category do
		item.Id = 0
	end
end
Mock.RunScript(Mock.ByPath["ServerScriptService/Server/Main"])
Mock.Advance(25)
local Dig = load("ServerScriptService/Server/Services/DigService")
local Data = load("ServerScriptService/Server/Services/DataService")
local World = load("ServerScriptService/Server/World")
local Bridge = load("ServerScriptService/Server/Adventure/BroadwaveDigBridge")
local V, CF = Mock.Vector3, Mock.CFrame
local workspace = Mock.Service("Workspace")
local p = Mock.AddPlayer(9801, "BroadwaveCheck")
Mock.Advance(2)
local data = Data.Get(p)
assert(data, "loaded data")
local zone = World.GetDigZone()
local point = V.new(300, Config.SURFACE_Y, zone.CFrame.Position.Z)
Mock.SpawnCharacter(p, point + V.new(0, 3, 4))
local passed = 0
local function check(ok, name)
	assert(ok, name)
	passed += 1
end
local function advance()
	Mock.Advance(2)
	data.Sand = 0
	p.Character:PivotTo(CF.new(point + V.new(0, 3, 4)))
end
local possession = data.Shovel
local coins = data.Coins
advance()
local result = Dig.DigBroadwave(p, point)
check(result and result.Success, "ordinary broadwave uses successful shovel validation")
local gained = result.SandGained
check(gained > 0 and data.TotalSandDug >= gained, "sand accounting uses existing data mutations")
local repeated = Dig.DigBroadwave(p, point + V.new(4, 0, 0))
check(repeated and repeated.Reason == "Cooldown", "ordinary shovel cooldown shared")
check(data.Coins == coins and data.Shovel == possession, "coins and possessions preserved")
advance()
local far = Dig.DigBroadwave(p, point + V.new(50, 0, 0))
check(far and far.Reason == "TooFar", "existing reach rejects distant terrain")
local outside = Dig.DigBroadwave(p, V.new(99999, Config.SURFACE_Y, 0))
check(outside and outside.Reason == "OutOfZone", "existing region bounds enforced")
check(Dig.DigBroadwave(p, V.new(0 / 0, 0, 0)) == nil, "nonfinite position refused")
advance()
data.Sand = 1e12
local full = Dig.DigBroadwave(p, point + V.new(4, 0, 0))
check(full and full.Reason == "BackpackFull", "ordinary capacity rejection preserved")
advance()
local deep = point - V.new(0, 400, 0)
p.Character:PivotTo(CF.new(deep + V.new(0, 3, 4)))
local hard = Dig.DigBroadwave(p, deep)
check(hard and hard.Reason == "TooHard", "ordinary hardness rejection preserved")
advance()
local protected = Mock.Env.Instance.new("Part")
protected.Size = V.new(4, 4, 4)
protected.CFrame = CF.new(point + V.new(4, -2, 0)) * CF.Angles(0, 0.5, 0)
protected:SetAttribute("ProtectedGeometry", true)
protected.Parent = workspace
check(
	Dig.IsProtectedVolume(point + V.new(2, -4, -2), point + V.new(6, 0, 2)),
	"rotated attribute-only protected geometry honored"
)
advance()
local sand = data.Sand
local voxelBefore = Mock.GetVoxel(point + V.new(4, -3, 0)).Occupancy
local blocked = Dig.DigBroadwave(p, point + V.new(4, 0, 0))
check(blocked and blocked.Reason == "OutOfZone" and data.Sand == sand, "protected scoop rejected before sand mutation")
check(Mock.GetVoxel(point + V.new(4, -3, 0)).Occupancy == voxelBefore, "protected rejection does not carve terrain")
protected:Destroy()
local following = Dig.DigBroadwave(p, point + V.new(4, 0, 0))
check(
	following and following.Success and following.SandGained == gained,
	"rejected protection consumes no cooldown and unchanged ordinary yield"
)
local model = Mock.Env.Instance.new("Model")
model:SetAttribute("ProtectedGeometry", true)
model.Parent = workspace
local child = Mock.Env.Instance.new("Part")
child.CFrame = CF.new(point)
child.Parent = model
check(Dig.IsProtectedVolume(point - V.new(1, 1, 1), point + V.new(1, 1, 1)), "protected parent covers descendant")
model:Destroy()
local callback = Bridge.Create({
	CanUse = function()
		return false
	end,
	Dig = Dig.DigBroadwave,
})
check(callback(p, p.Character.HumanoidRootPart.CFrame, 0.1) == false, "short charge refused")
check(callback(p, p.Character.HumanoidRootPart.CFrame, 0 / 0) == false, "nonfinite charge refused")
check(callback(p, p.Character.HumanoidRootPart.CFrame, 0.8) == false, "license absent or wrong equipped tool refused")
local tool = Mock.Env.Instance.new("Tool")
tool.Name = "Broadwave (Adventure Loan)"
tool:SetAttribute("AdventureLoan", true)
for _, old in p.Character:GetChildren() do
	if old:IsA("Tool") then
		old.Parent = p.Backpack
	end
end
tool.Parent = p.Character
check(
	callback(p, p.Character.HumanoidRootPart.CFrame, 0.8) == false,
	"equipped review loan does not imply ordinary license"
)
local calls = 0
local ordinary = Bridge.Create({
	CanUse = function()
		return true
	end,
	Dig = function(_, target)
		check(
			(target - p.Character.HumanoidRootPart.Position).Magnitude < 12,
			"adapter computes bounded server terrain target"
		)
		calls += 1
		return { Success = true }
	end,
})
p.Character:PivotTo(CF.new(V.new(320, Config.SURFACE_Y + 3, point.Z + 4)))
Mock.ServerTerrainRaycast = true
check(
	ordinary(p, p.Character.HumanoidRootPart.CFrame, 0.8) == false and calls == 0,
	"review loan refused even with permissive license callback"
)
tool:SetAttribute("AdventureLoan", false)
tool:SetAttribute("ToolId", "tool_broadwave")
check(
	ordinary(p, p.Character.HumanoidRootPart.CFrame, 0.8) == true and calls == 1,
	"licensed release calls injected DigService path once"
)
check(
	ordinary(p, p.Character.HumanoidRootPart.CFrame, 0.8) == false and calls == 1,
	"ability cooldown refuses duplicate callback"
)
Mock.Advance(9)
check(ordinary(p, CF.new(V.new(99999, 0, 0)), 0.8) == false and calls == 1, "spoofed release frame refused")
check(#Mock.Errors == 0, "no production runtime errors")
print("Broadwave DigService integration: " .. passed .. " checks passed")
