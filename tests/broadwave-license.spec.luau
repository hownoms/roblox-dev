--!nocheck
--[[
	Licensed Broadwave contract (docs/integration/licensed-broadwave.md).
	  luau tests/broadwave-license.spec.luau

	Part 1 (always): our side. AdventureBoot.Options wires ResolveTool only with
	BroadwaveOrdinary; BroadwaveLicense.ResolveTool returns the equipped tool this server
	issued to that player and nothing else (loan, renamed / forged copy, foreign-issued, unequipped,
	license missing, ordinary disabled, after Disable).
	Part 2 (end to end through SpringVaultService.Handle): only when the runtime supports the
	ResolveTool option (declared Service.Contract.ResolveTool, or an accepted licensed charge);
	otherwise prints SKIPPED. Only a resolved licensed tool reaches ordinary digging; the
	runtime's loans stay event/trial only.
	MOCK COVERAGE ONLY: headless mock, in-memory DataStore, no real clients or devices.
]]

local Mock = require("./mock/Roblox")
Mock.Init(require("../build/test/generated"))
local passes, failures, skipped = 0, 0, {}
local function check(cond, message)
	if cond then
		passes += 1
	else
		failures += 1
		print("FAIL: " .. message)
	end
end
local function finish()
	check(#Mock.Errors == 0, "no uncaught errors")
	for _, e in Mock.Errors do
		print("  error: " .. tostring(e))
	end
	for _, s in skipped do
		print(s)
	end
	print(string.format("BROADWAVE LICENSE: %d passed, %d failed", passes, failures))
	if failures > 0 then
		error("BROADWAVE LICENSE SPEC FAILED")
	end
end

local byPath = Mock.ByPath
local function load(path)
	return Mock.Require(byPath[path])
end
local V, CF = Mock.Vector3, Mock.CFrame
local Config = load("ReplicatedStorage/Shared/Config")
for _, category in { Config.Monetization.GamePasses, Config.Monetization.Products, Config.Badges } do
	for _, item in category do
		item.Id = 0
	end
end
local S = Config.SURFACE_Y
local hasOverlay = byPath["ServerScriptService/Server/Adventure/BroadwaveDigBridge"] ~= nil
local Services = "ServerScriptService/Server/Services/"
local Flags = load(Services .. "AdventureFlags")
local Boot = load(Services .. "AdventureBoot")
local License = load(Services .. "BroadwaveLicense")
local Eligibility = load(Services .. "AdventureEligibility")

-- Options contract (no boot) -------------------------------------------------------------------
check(
	Flags.SpringVault == false and Flags.AdventureRewards == false and Flags.BroadwaveOrdinary == false,
	"every adventure flag ships off"
)
local offOptions = Boot.Options({ SpringVault = true, AdventureRewards = false, BroadwaveOrdinary = false })
check(offOptions.ResolveTool == nil, "BroadwaveOrdinary off: no ResolveTool passed")
check(offOptions.OnOrdinaryBroadwave == nil, "BroadwaveOrdinary off: no ordinary adapter passed")
if not hasOverlay then
	table.insert(skipped, "SKIPPED (Spring Vault gameplay files absent)")
	finish()
	return
end
local onOptions = Boot.Options({ SpringVault = true, AdventureRewards = false, BroadwaveOrdinary = true })
check(onOptions.ResolveTool == License.ResolveTool, "BroadwaveOrdinary on: resolver wired")
check(type(onOptions.OnOrdinaryBroadwave) == "function", "BroadwaveOrdinary on: ordinary adapter wired")

local function save(userId, mutate)
	local data = Config.NewPlayerData()
	data.Version = Config.DATA_VERSION
	if mutate then
		mutate(data)
	end
	Mock.DataStores[Config.DATASTORE_NAME] = Mock.DataStores[Config.DATASTORE_NAME] or {}
	Mock.DataStores[Config.DATASTORE_NAME]["Player_" .. userId] = { Data = data, SavedAt = 1 }
end
local function pricedShovel()
	for _, def in Config.Shovels do
		if def.Price > 0 then
			return def.Id
		end
	end
end
local USER_LIC, USER_OTHER, USER_FRESH, USER_TRIAL = 9401, 9402, 9403, 9404
save(USER_LIC, function(d)
	d.ToolLicenses = { tool_broadwave = { At = 1, Source = "test" } }
	d.OwnedShovels[pricedShovel()] = true
end)
save(USER_OTHER, function(d)
	d.ToolLicenses = { tool_broadwave = { At = 1, Source = "test" } }
end)
save(USER_FRESH)
save(USER_TRIAL, function(d)
	d.OwnedShovels[pricedShovel()] = true
end)

Flags.SpringVault, Flags.AdventureRewards, Flags.BroadwaveOrdinary = true, false, true
Mock.RunScript(byPath["ServerScriptService/Server/Main"])
Mock.Advance(25)
check(#Mock.Errors == 0, "Main boots with SpringVault + BroadwaveOrdinary")
local runtime = Boot.Runtime()
check(runtime ~= nil, "runtime started")
local Data = load(Services .. "DataService")
local World = load("ServerScriptService/Server/World")

local function add(userId, name)
	local p = Mock.AddPlayer(userId, name)
	Mock.Advance(2)
	Mock.SpawnCharacter(p, V.new(0, S + 3, 4))
	Mock.Advance(1)
	return p
end
local lic = add(USER_LIC, "Licensed")
local other = add(USER_OTHER, "Other")
local fresh = add(USER_FRESH, "Fresh")
local function issued(p)
	for _, container in { p.Backpack, p.Character } do
		for _, child in container:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("LicensedBroadwave") == true then
				return child
			end
		end
	end
	return nil
end
local function stow(p)
	for _, child in p.Character:GetChildren() do
		if child:IsA("Tool") then
			child.Parent = p.Backpack
		end
	end
end
local function hold(p, tool)
	stow(p)
	tool.Parent = p.Character
end

-- Part 1: resolver / eligibility ----------------------------------------------------------------
local licTool = issued(lic)
check(licTool ~= nil and licTool.Parent == lic.Backpack, "licensed tool issued into the Backpack")
check(issued(fresh) == nil, "no license record: no tool")
check(License.ResolveTool(lic) == nil, "unequipped licensed tool: nil")
hold(lic, licTool)
check(License.ResolveTool(lic) == licTool, "equipped licensed tool: resolved")
check(License.ResolveTool(fresh) == nil, "unlicensed player: nil")
check(License.ResolveTool(nil) == nil and License.ResolveTool({}) == nil, "non-Player input: nil")

-- Renaming the issued tool changes nothing (the name is never evidence).
licTool.Name = "Broadwave (Adventure Loan)"
check(License.ResolveTool(lic) == licTool, "renamed issued tool still resolves (name is not evidence)")
licTool.Name = "Broadwave"
-- A forged copy (same name and attributes, not issued by this server) never resolves.
local forged = Mock.Env.Instance.new("Tool")
forged.Name = "Broadwave"
forged:SetAttribute("ToolId", "tool_broadwave")
forged:SetAttribute("LicensedBroadwave", true)
forged.Parent = lic.Backpack
hold(lic, forged)
check(License.ResolveTool(lic) == nil, "forged licensed copy equipped: nil")
check(Eligibility.CanUseBroadwave(lic, forged) == false, "forged licensed copy fails CanUseBroadwave")
forged:Destroy()

-- A tool issued to another player, equipped by this one.
local otherTool = issued(other)
check(otherTool ~= nil, "second licensed player issued a tool")
hold(lic, otherTool)
check(License.ResolveTool(lic) == nil, "another player's licensed tool: nil for the holder")
check(Eligibility.CanUseBroadwave(lic, otherTool) == false, "foreign-issued tool fails CanUseBroadwave")
check(License.ResolveTool(other) == nil, "owner whose tool is not in their character: nil")
otherTool.Parent = other.Backpack

-- The adventure loan (Pip trial) never resolves, even for a licensed player.
local targets = runtime.Scene.Targets
lic.Character:PivotTo(CF.new(targets.npc_pip + V.new(0, 3, 2)))
runtime.Handle(lic, { action = "Talk", targetId = "npc_pip" })
Mock.Advance(0.2)
check(runtime.ReviewPlayer(lic).Trial ~= nil, "Pip trial started (loan issued)")
local loan = lic.Backpack:FindFirstChild("Broadwave (Adventure Loan)")
check(loan ~= nil and loan:GetAttribute("AdventureLoan") == true, "trial loan in the Backpack")
hold(lic, loan)
check(License.ResolveTool(lic) == nil, "loan equipped: nil")
check(Eligibility.CanUseBroadwave(lic, loan) == false, "loan fails CanUseBroadwave")
-- Even a loan dressed up as a licensed tool.
loan:SetAttribute("ToolId", "tool_broadwave")
loan:SetAttribute("LicensedBroadwave", true)
check(Eligibility.CanUseBroadwave(lic, loan) == false, "loan with licensed attributes still refused")
loan:SetAttribute("ToolId", nil)
loan:SetAttribute("LicensedBroadwave", nil)

-- License record missing (e.g. a future revoke): nil, and Sync removes the tool.
hold(lic, licTool)
local record = Data.Get(lic).ToolLicenses.tool_broadwave
Data.Get(lic).ToolLicenses.tool_broadwave = nil
check(License.ResolveTool(lic) == nil, "license record missing: nil")
License.Sync(lic)
check(licTool.Parent == nil and issued(lic) == nil, "Sync removes the tool without a license")
Data.Get(lic).ToolLicenses.tool_broadwave = record
License.Sync(lic)
licTool = issued(lic)
check(licTool ~= nil, "Sync re-issues once the record is back (no save written by BroadwaveLicense)")

-- Ordinary disabled (the BroadwaveOrdinary gate inside CanUseBroadwave).
hold(lic, licTool)
Eligibility.SetOrdinaryEnabled(false)
check(License.ResolveTool(lic) == nil, "ordinary Broadwave disabled: nil")
Eligibility.SetOrdinaryEnabled(true)
check(License.ResolveTool(lic) == licTool, "re-enabled: resolved again")

-- Respawn: the old tool dies with the Backpack; the new one resolves once equipped.
Mock.SpawnCharacter(lic, V.new(0, S + 3, 4))
Mock.Advance(1)
local respawned = issued(lic)
check(respawned ~= nil and respawned ~= licTool, "respawn re-issues a fresh licensed tool")
check(License.ResolveTool(lic) == nil, "after respawn, unequipped: nil")
licTool = respawned
loan = lic.Backpack:FindFirstChild("Broadwave (Adventure Loan)")
check(loan ~= nil, "the runtime re-lends the trial loan after respawn")

-- Part 2: end to end through the runtime -------------------------------------------------------
local Service = load("ServerScriptService/Server/Adventure/SpringVaultService")
Mock.ServerTerrainRaycast = true
local zone = World.GetDigZone()
local point = V.new(300, S, zone.CFrame.Position.Z)
local function onSand(p, tool)
	hold(p, tool)
	p.Character:PivotTo(CF.lookAt(point + V.new(0, 3, 4), point + V.new(0, 3, -4)))
end
local function facing(p, tool, target)
	hold(p, tool)
	p.Character:PivotTo(CF.lookAt(target + V.new(0, 3, 5), target + V.new(0, 3, 0)))
end
local function charge(p)
	runtime.Handle(p, { action = "ChargeBegin", targetId = "trial_patch" })
	local began = runtime.ReviewPlayer(p).Charging
	Mock.Advance(1)
	runtime.Handle(p, { action = "ChargeRelease", targetId = "trial_patch" })
	return began
end
-- Support: the runtime's declared marker (requested), or an accepted licensed-tool charge.
onSand(lic, licTool)
runtime.Handle(lic, { action = "ChargeBegin" })
local probe = runtime.ReviewPlayer(lic).Charging == true
runtime.Handle(lic, { action = "ChargeCancel" })
local marker = type(Service.Contract) == "table" and Service.Contract.ResolveTool ~= nil
if marker then
	check(probe, "runtime declares Contract.ResolveTool and accepts the licensed charge")
end
if not (probe or marker) then
	table.insert(skipped, "SKIPPED (runtime lacks ResolveTool — see request)")
else
	if not marker then
		table.insert(skipped, "NOTE: runtime accepts ResolveTool but declares no Service.Contract marker")
	end
	Mock.Advance(1)
	local data = Data.Get(lic)

	-- Licensed tool on ordinary sand: charge accepted, scoop goes through DigBroadwave.
	onSand(lic, licTool)
	data.Sand = 0
	local dug = data.TotalSandDug
	check(charge(lic) == true, "licensed tool: ChargeBegin accepted")
	check(data.TotalSandDug > dug, "licensed release scoops ordinary sand")
	check((runtime.ReviewPlayer(lic).CooldownUntil or 0) > Mock.Now(), "licensed release starts the cooldown")
	Mock.Advance(9)
	dug = data.TotalSandDug
	data.Sand = 0
	check(charge(lic) == true and data.TotalSandDug > dug, "second licensed release after the cooldown scoops again")
	Mock.Advance(9)

	-- Loan on the same sand: event/trial gating applies, never ordinary digging.
	onSand(lic, loan)
	data.Sand = 0
	dug = data.TotalSandDug
	check(charge(lic) == false, "loan away from trial/event targets: ChargeBegin refused")
	check(data.TotalSandDug == dug, "loan never reaches ordinary digging")

	-- Unequipping mid-charge cancels it.
	onSand(lic, licTool)
	data.Sand = 0
	dug = data.TotalSandDug
	runtime.Handle(lic, { action = "ChargeBegin" })
	check(runtime.ReviewPlayer(lic).Charging == true, "licensed charge started")
	stow(lic)
	Mock.Advance(1)
	check(runtime.ReviewPlayer(lic).Charging == false, "unequip cancels the licensed charge")
	runtime.Handle(lic, { action = "ChargeRelease" })
	check(data.TotalSandDug == dug, "cancelled charge pays nothing")

	-- Swapping licensed -> loan mid-charge is not a carry-over.
	onSand(lic, licTool)
	runtime.Handle(lic, { action = "ChargeBegin" })
	check(runtime.ReviewPlayer(lic).Charging == true, "licensed charge started again")
	onSand(lic, loan)
	Mock.Advance(1)
	runtime.Handle(lic, { action = "ChargeRelease" })
	check(runtime.ReviewPlayer(lic).Charging == false, "switching tool mid-charge cancels it")
	check(data.TotalSandDug == dug, "switched charge pays nothing")

	-- Licensed tool at Pip's trial patch (contract: a licensed tool may also do event/trial work;
	-- only the loan is restricted). The trial grants nothing permanent either way.
	facing(lic, licTool, targets.trial_patch)
	dug = data.TotalSandDug
	check(charge(lic) == true, "licensed charge accepted at the trial patch")
	check(runtime.ReviewPlayer(lic).Trial.Wave == true, "licensed release may clear the trial patch")
	check(data.TotalSandDug == dug, "trial release pays no ordinary sand")
	Mock.Advance(9)

	-- An unlicensed trial player: the loan does trial work and never ordinary digging.
	local trialist = add(USER_TRIAL, "Trialist")
	trialist.Character:PivotTo(CF.new(targets.npc_pip + V.new(0, 3, 2)))
	runtime.Handle(trialist, { action = "Talk", targetId = "npc_pip" })
	Mock.Advance(0.2)
	local trialLoan = trialist.Backpack:FindFirstChild("Broadwave (Adventure Loan)")
	check(trialLoan ~= nil and issued(trialist) == nil, "trial player: loan only, no licensed tool")
	local tdata = Data.Get(trialist)
	onSand(trialist, trialLoan)
	tdata.Sand = 0
	local tdug = tdata.TotalSandDug
	check(charge(trialist) == false and tdata.TotalSandDug == tdug, "unlicensed loan on sand: no charge, no sand")
	facing(trialist, trialLoan, targets.trial_patch)
	check(charge(trialist) == true, "loan at the trial patch: ChargeBegin accepted")
	check(runtime.ReviewPlayer(trialist).Trial.Wave == true, "loan release clears the trial patch")
	check(tdata.TotalSandDug == tdug, "loan trial release pays no ordinary sand")

	-- Forged and foreign tools cannot start a charge.
	local fake = Mock.Env.Instance.new("Tool")
	fake.Name = "Broadwave"
	fake:SetAttribute("ToolId", "tool_broadwave")
	fake:SetAttribute("LicensedBroadwave", true)
	fake.Parent = lic.Backpack
	onSand(lic, fake)
	check(charge(lic) == false, "forged licensed copy: ChargeBegin refused")
	fake:Destroy()
	local foreign = issued(other)
	onSand(lic, foreign)
	check(charge(lic) == false, "another player's licensed tool: ChargeBegin refused")
	foreign.Parent = other.Backpack
	-- License removed while equipped: the resolver refuses the next charge.
	onSand(lic, licTool)
	local saved = data.ToolLicenses.tool_broadwave
	data.ToolLicenses.tool_broadwave = nil
	check(charge(lic) == false, "license record gone: ChargeBegin refused")
	data.ToolLicenses.tool_broadwave = saved
end

-- Kill switch -----------------------------------------------------------------------------------
hold(lic, licTool)
Boot.Disable()
Mock.Advance(1)
check(Boot.Runtime() == nil, "Disable stops the runtime")
check(License.ResolveTool(lic) == nil, "after Disable: nil")
check(issued(lic) == nil, "after Disable: licensed tool removed")
check(Data.Get(lic).ToolLicenses.tool_broadwave ~= nil, "Disable never touches the saved license")
finish()
