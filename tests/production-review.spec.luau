--!nocheck
--[[
	Production-integration review boot (docs/integration/production-review.md).
	  luau tests/production-review.spec.luau
	Runs tools/expansion1/production-review/ReviewBoot under the mock with the REAL production
	Main: refuses (and starts nothing) outside Studio, with PlaceId ~= 0, without the review
	marker, with reachable DataStores or an enabled Main; with Studio + PlaceId 0 it boots Main with
	the review flags, self-checks the production AdventureBoot.Options, and seeds review
	prerequisites only on request, labelled. Also checks default.project.json maps no review path
	and the shipped AdventureFlags are all false.
	MOCK COVERAGE ONLY: headless mock, in-memory DataStore, no real clients or devices.
]]

local Mock = require("./mock/Roblox")
local Generated = require("../build/test/generated")
local Review = require("../build/test/production-review")
for _, entry in Review.Sources do
	table.insert(Generated.Sources, entry)
end
Mock.Init(Generated)

local passes, failures = 0, 0
local function check(cond, message)
	if cond then
		passes += 1
	else
		failures += 1
		print("FAIL: " .. message)
	end
	return cond
end
local function finish()
	check(#Mock.Errors == 0, "no uncaught errors")
	for _, e in Mock.Errors do
		print("  error: " .. tostring(e))
	end
	print(string.format("PRODUCTION REVIEW: %d passed, %d failed", passes, failures))
	if failures > 0 then
		error("PRODUCTION REVIEW SPEC FAILED")
	end
end

local byPath = Mock.ByPath
local function load(path)
	return Mock.Require(byPath[path])
end
local V, CF = Mock.Vector3, Mock.CFrame
local function has(text, needle)
	return string.find(text, needle, 1, true) ~= nil
end

-- Static: default.project.json maps no review path; shipped flags all false; review project maps
-- the real production sources with Main disabled. ---------------------------------------------
do
	local default = Review.DefaultProject
	check(not has(default, "tools/"), "default.project.json maps nothing under tools/")
	check(not has(default, "ProductionReview"), "default.project.json has no ProductionReview node")
	check(not has(default, "production-review"), "default.project.json has no production-review path")
	check(not has(default, "Disabled"), "default.project.json disables no script")

	local flagsSource
	for _, entry in Generated.Sources do
		if table.concat(entry.Path, "/") == "ServerScriptService/Server/Services/AdventureFlags" then
			flagsSource = entry.Source
		end
	end
	check(flagsSource ~= nil, "AdventureFlags source bundled")
	flagsSource = flagsSource or ""
	local body = string.match(flagsSource, "local AdventureFlags = (%b{})") or ""
	for _, name in { "SpringVault", "AdventureRewards", "BroadwaveOrdinary" } do
		check(string.find(body, name .. "%s*=%s*false") ~= nil, "shipped AdventureFlags." .. name .. " = false")
	end
	check(not string.find(body, "=%s*true"), "no shipped AdventureFlags field is true")

	local project = Review.ReviewProject
	for _, child in Review.ServerChildren do
		check(has(project, '"src/server/' .. child .. '"'), "review project maps src/server/" .. child)
	end
	check(
		has(project, '"src/shared"') and has(project, '"src/client"'),
		"review project maps src/shared and src/client"
	)
	check(
		string.find(project, '"src/server/Main%.server%.luau",%s*"%$properties":%s*{%s*"Disabled":%s*true') ~= nil,
		"review project ships production Main disabled"
	)
	check(not has(project, "tools/adventure"), "review project maps none of Codex's adventure review")
	check(has(project, '"ProductionIntegrationReview": true'), "review project creates the review marker")
end

local Config = load("ReplicatedStorage/Shared/Config")
for _, category in { Config.Monetization.GamePasses, Config.Monetization.Products, Config.Badges } do
	for _, item in category do
		item.Id = 0
	end
end
local S = Config.SURFACE_Y
local env = Mock.Env
local RS = Mock.Service("ReplicatedStorage")
local Workspace = Mock.Service("Workspace")
local marker = byPath["ServerScriptService/ProductionReview"]
local server = byPath["ServerScriptService/Server"]
local main = byPath["ServerScriptService/Server/Main"]
local ReviewBoot = load("ServerScriptService/ProductionReview/ReviewBoot")
local Flags = load("ServerScriptService/Server/Services/AdventureFlags")
check(
	Flags.SpringVault == false and Flags.AdventureRewards == false and Flags.BroadwaveOrdinary == false,
	"flags are off before the review boot"
)

local function run()
	local result
	env.task.spawn(function()
		result = ReviewBoot.Run({
			Marker = marker,
			Server = server,
			StartMain = function(m)
				Mock.RunScript(m)
			end,
		})
	end)
	Mock.Advance(25)
	return result
end
local function nothingStarted(label)
	check(env.shared.DigToTheCoreServer == nil, label .. ": production Main did not run")
	check(RS:FindFirstChild("SpringVaultAdventure") == nil, label .. ": no adventure remotes")
	check(Workspace:FindFirstChild("AdventureEntry") == nil, label .. ": no hatch")
	check(
		Flags.SpringVault == false and Flags.AdventureRewards == false and Flags.BroadwaveOrdinary == false,
		label .. ": flags untouched"
	)
	check(has(tostring(RS:GetAttribute(ReviewBoot.STATUS_ATTRIBUTE)), "refused"), label .. ": status says refused")
end

-- Refusals: nothing starts ---------------------------------------------------------------------
Mock.IsStudio = false
Mock.DataStoreFail = true
marker:SetAttribute(ReviewBoot.MARKER, true)
local r = run()
check(r and r.Started == false and has(r.Reason, "Studio"), "refuses outside Studio")
nothingStarted("not Studio")

Mock.IsStudio = true
Mock.Internal(Mock.Game).props.PlaceId = 4242
r = run()
check(r and r.Started == false and has(r.Reason, "PlaceId"), "refuses with PlaceId ~= 0")
nothingStarted("PlaceId 4242")
Mock.Internal(Mock.Game).props.PlaceId = 0

marker:SetAttribute(ReviewBoot.MARKER, nil)
r = run()
check(r and r.Started == false and has(r.Reason, "marker"), "refuses without the review marker")
nothingStarted("no marker")
marker:SetAttribute(ReviewBoot.MARKER, true)

Mock.DataStoreFail = false
r = run()
check(r and r.Started == false and has(r.Reason, "in-memory"), "refuses when DataStores are reachable")
nothingStarted("reachable DataStores")
Mock.DataStoreFail = true

main.Enabled = true
r = run()
check(r and r.Started == false and has(r.Reason, "enabled"), "refuses when production Main is enabled")
nothingStarted("Main enabled")
main.Enabled = false
check(#Mock.Errors == 0, "refusals raise no errors")

-- Studio + PlaceId 0 + marker: the real production boot --------------------------------------
local printsBefore = #Mock.Prints
r = run()
check(r and r.Started == true, "boots with Studio + PlaceId 0 + marker (" .. tostring(r and r.Reason) .. ")")
local function printed(needle, from)
	for i = (from or printsBefore) + 1, #Mock.Prints do
		if has(Mock.Prints[i], needle) then
			return true
		end
	end
	return false
end
check(printed(ReviewBoot.BANNER), "prints the review banner")
check(
	ReviewBoot.BANNER
		== "PRODUCTION-INTEGRATION REVIEW: in-memory saves, review prerequisites; not production eligibility or persistence evidence",
	"banner text"
)
check(printed("DataService in-memory store"), "prints the in-memory save path")
check(printed("self-check PASS"), "prints the self-check result")
check(env.shared.DigToTheCoreServer == main:GetFullName(), "the real production Main booted")
check(Flags.SpringVault and Flags.AdventureRewards and Flags.BroadwaveOrdinary, "review flags on (runtime table only)")
check(RS:GetAttribute(ReviewBoot.STATUS_ATTRIBUTE) == "running", "status attribute running")

local Boot = load("ServerScriptService/Server/Services/AdventureBoot")
local Eligibility = load("ServerScriptService/Server/Services/AdventureEligibility")
local Settlement = load("ServerScriptService/Server/Services/AdventureSettlement")
local License = load("ServerScriptService/Server/Services/BroadwaveLicense")
local Entry = load("ServerScriptService/Server/Services/AdventureEntry")
local DataService = load("ServerScriptService/Server/Services/DataService")
local runtime = Boot.Runtime()
check(runtime ~= nil, "AdventureBoot.Runtime() exists")
check(DataService.IsMock(), "DataService in-memory")
local failedChecks = 0
for _, c in r and r.Checks or {} do
	if not c.Ok then
		failedChecks += 1
		print("  self-check failed: " .. c.Name)
	end
end
check(r and #r.Checks >= 10 and failedChecks == 0, "every self-check passes")
local options = Boot.Options(Flags)
check(rawequal(options.CanEnter, Eligibility.CanEnter), "CanEnter is production")
check(rawequal(options.CanTrial, Eligibility.CanTrial), "CanTrial is production")
check(rawequal(options.OnCompletion, Settlement.OnCompletion), "OnCompletion is production")
check(rawequal(options.ResolveTool, License.ResolveTool), "ResolveTool is production")
check(options.ReturnFrame(nil) == Entry.SURFACE_RETURN, "ReturnFrame is production")
check(marker:FindFirstChild("ProductionReviewProbe") ~= nil, "review probe installed")
local commands = Mock.Service("TextChatService"):FindFirstChild("ProductionReviewCommands")
check(commands ~= nil and commands:FindFirstChild("/reviewseed") ~= nil, "review chat commands installed")

local again = run()
check(again and again.Started == false and has(again.Reason, "already booted"), "a second review boot refuses")
check(Boot.Runtime() == runtime, "the running adventure is untouched by a refused boot")

-- Players: real refusal, explicit labelled seeding ---------------------------------------------
local hatch = Workspace:FindFirstChild(Entry.FOLDER).Entrance.Hatch
local enter = hatch:FindFirstChild("AdventureEntryPrompt")
check(enter ~= nil, "surface hatch prompt exists")
local function add(userId, name)
	local p = Mock.AddPlayer(userId, name)
	Mock.Advance(2)
	Mock.SpawnCharacter(p, V.new(0, S + 3, 4))
	Mock.Advance(1)
	return p
end
local function pos(p)
	return p.Character.HumanoidRootPart.Position
end
local function goDown(p)
	Mock.Advance(Entry.PROMPT_COOLDOWN + 0.1)
	p.Character:PivotTo(CF.new(hatch.Position + V.new(3, 3, 0)))
	local before = pos(p)
	Mock.FireEvent(enter, "Triggered", p)
	Mock.Advance(0.5)
	return (pos(p) - before).Magnitude > 1
end

local USER_A, USER_B = 9701, 9702
local a = add(USER_A, "Reviewer")
local b = add(USER_B, "Other")
check(DataService.IsLoaded(a) and DataService.IsLoaded(b), "players loaded (in-memory)")
check(a:GetAttribute(ReviewBoot.PREREQ_ATTRIBUTE) == nil, "prerequisite off by default")
check(not Eligibility.CanEnter(a) and not Eligibility.CanTrial(a), "fresh player is ineligible")
check(not goDown(a), "real refusal: ineligible player is not taken down the hatch")
check(not Entry.InPocket(pos(a)), "refused player stays on the surface")

local seedMark = #Mock.Prints
Mock.FireEvent(commands:FindFirstChild("/reviewseed"), "Triggered", { UserId = USER_A }, "/reviewseed")
Mock.Advance(0.5)
local data = DataService.Get(a)
local certRecord = data.Certifications and data.Certifications.cert_rookie
check(certRecord ~= nil and certRecord.Review == true, "seeded cert_rookie is marked Review = true")
check(certRecord ~= nil and certRecord.Source == ReviewBoot.PREREQ_SOURCE, "seeded cert source is ProductionReview")
local priced
for id, owned in data.OwnedShovels do
	local def = Config.GetShovel(id)
	if owned and def and def.Price > 0 then
		priced = id
	end
end
check(priced ~= nil, "seeded a priced owned shovel")
check(data.Shovel ~= priced, "seeded shovel is not equipped")
local label = a:GetAttribute(ReviewBoot.PREREQ_ATTRIBUTE)
check(
	label == "cert_rookie,shovel:" .. tostring(priced),
	"ReviewPrerequisite attribute labels the seed (" .. tostring(label) .. ")"
)
check(printed("REVIEW PREREQUISITE", seedMark), "seeding is logged")
check(Eligibility.CanEnter(a) and Eligibility.CanTrial(a), "seeded player passes the real rules")
check(b:GetAttribute(ReviewBoot.PREREQ_ATTRIBUTE) == nil and not Eligibility.CanEnter(b), "other player stays unseeded")
local store = Mock.DataStores[Config.DATASTORE_NAME]
check(store == nil or store["Player_" .. USER_A] == nil, "no DataStore record written for the seeded player")
check(ReviewBoot.Command("Seed", USER_A) == "seeded: none-needed", "re-seeding an eligible player adds nothing")
check(a:GetAttribute(ReviewBoot.PREREQ_ATTRIBUTE) == label, "re-seeding keeps the original review label")

check(goDown(a), "seeded player goes down the hatch")
check(Entry.InPocket(pos(a)), "seeded player arrives in the pocket")
check(not goDown(b), "unseeded player is still refused")
check(#runtime.ReviewAdapter.Contexts() == 0, "Codex review completion adapter unused")

local rows = ReviewBoot.Command("Status")
check(type(rows) == "table" and #rows == 2, "status lists both players")

finish()
