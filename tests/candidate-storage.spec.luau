--!nocheck
--[[
	LocalOnly candidate storage (CandidateProfile + StorageGate) through the REAL Main.
	  luau tests/candidate-storage.spec.luau -a localonly            valid Studio candidate
	  luau tests/candidate-storage.spec.luau -a refusals             every refusal + static checks
	  luau tests/candidate-storage.spec.luau -a production           no marker, live server
	  luau tests/candidate-storage.spec.luau -a production studio    no marker, Studio with access

	The mock counts every DataStoreService touch (Mock.DataStoreCalls: GetService, every service
	method, every store request). LocalOnly must make ZERO of them across boot, two players,
	mutations, reward outboxes, a product receipt, a leaderboard refresh, autosave, removal and
	BindToClose. Every refusal must start nothing. Production must acquire exactly as before.
	MOCK COVERAGE ONLY: headless mock, no Studio, no real DataStore.
]]

local Mock = require("./mock/Roblox")
local Generated = require("../build/test/generated")
local args = { ... }
local mode = args[1] or "localonly"
local studioProduction = table.find(args, "studio") ~= nil
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
local function has(text, needle)
	return string.find(tostring(text), needle, 1, true) ~= nil
end
local function count(t)
	local n = 0
	for _ in t or {} do
		n += 1
	end
	return n
end
local function finish(label)
	check(#Mock.Errors == 0, label .. ": no uncaught errors")
	for _, e in Mock.Errors do
		print("  error: " .. tostring(e))
	end
	print(string.format("CANDIDATE STORAGE %s: %d passed, %d failed", label, passes, failures))
	if failures > 0 then
		error("CANDIDATE STORAGE SPEC FAILED")
	end
end

local byPath = Mock.ByPath
local function load(path)
	return Mock.Require(byPath[path])
end
local env = Mock.Env
local P = "ServerScriptService/Server/Services/"
local SSS = Mock.Service("ServerScriptService")
local RS = Mock.Service("ReplicatedStorage")
local Workspace = Mock.Service("Workspace")
local Players = Mock.Service("Players")
local main = byPath["ServerScriptService/Server/Main"]
local Config = load("ReplicatedStorage/Shared/Config")
for _, category in { Config.Monetization.GamePasses, Config.Monetization.Products, Config.Badges } do
	for _, item in category do
		item.Id = 0
	end
end

local VALID_CONFIG = [[
return {
	Authorization = "Expansion1Review",
	Storage = "LocalOnly",
	Flags = { SpringVault = true, AdventureRewards = true, BroadwaveOrdinary = true },
}
]]

-- Installs ServerScriptService.ProductionCandidate (replacing any previous one).
local function install(opts)
	opts = opts or {}
	local old = SSS:FindFirstChild("ProductionCandidate")
	if old then
		old:Destroy()
	end
	local folder = env.Instance.new(opts.Class or "Folder")
	folder.Name = "ProductionCandidate"
	if opts.Marker ~= false then
		folder:SetAttribute("ProductionCandidate", true)
	end
	if opts.Place ~= false then
		folder:SetAttribute("AuthorizedPlace", opts.Place or "Expansion1Review.rbxlx")
	end
	local module = env.Instance.new("ModuleScript")
	module.Name = "CandidateConfig"
	Mock.SetSource(module, opts.Source or VALID_CONFIG)
	module.Parent = folder
	folder.Parent = SSS
	return folder
end

local function storeCalls()
	return table.concat(Mock.DataStoreCalls, ", ")
end
local function called(prefix)
	for _, c in Mock.DataStoreCalls do
		if string.sub(c, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end
local function printed(needle)
	for _, line in Mock.Prints do
		if has(line, needle) then
			return true
		end
	end
	return false
end
local function warned(needle)
	for _, line in Mock.Warnings do
		if has(line, needle) then
			return true
		end
	end
	return false
end
local BANNER = "[CandidateProfile] LOCAL-ONLY CANDIDATE: in-memory saves, outboxes, purchase history and"
	.. " leaderboards; no DataStore is acquired. Rewards are local simulation."

local function children(inst)
	local names = {}
	for _, c in inst:GetChildren() do
		names[c] = true
	end
	return names
end
local function sameChildren(inst, before)
	local now = children(inst)
	return count(now) == count(before)
end

-- LocalOnly ---------------------------------------------------------------------------------------
if mode == "localonly" then
	Mock.IsStudio = true
	install()
	local Profile = load(P .. "CandidateProfile")
	local Gate = load(P .. "StorageGate")
	check(
		Profile.Mode() == "LocalOnly",
		"valid Studio candidate resolves LocalOnly (" .. tostring(Profile.Refusal()) .. ")"
	)
	check(Profile.IsLocalOnly() and Profile.Refusal() == nil, "IsLocalOnly, no refusal")
	local flags = Profile.Flags()
	check(flags and flags.SpringVault and flags.AdventureRewards and flags.BroadwaveOrdinary, "candidate flags read")
	check(flags and table.isfrozen(flags), "Flags() is a frozen copy")
	check(not pcall(function()
		flags.SpringVault = false
	end), "Flags() cannot be written")
	local Flags = load(P .. "AdventureFlags")
	check(
		Flags.SpringVault == true and Flags.AdventureRewards == true and Flags.BroadwaveOrdinary == true,
		"candidate flags overlay AdventureFlags"
	)

	Mock.RunScript(main)
	Mock.Advance(2)
	check(#Mock.Errors == 0, "Main boots")
	check(printed(BANNER), "prints the LocalOnly banner")
	check(RS:GetAttribute("CandidateProfile") == "LocalOnly", "CandidateProfile attribute LocalOnly")
	check(RS:GetAttribute("CandidateStorage") == "LocalOnly", "CandidateStorage attribute LocalOnly")

	local DataService = load(P .. "DataService")
	local Monetization = load(P .. "MonetizationService")
	local Leaderboard = load(P .. "LeaderboardService")
	local Settlement = load(P .. "AdventureSettlement")
	local Pending = load(P .. "TrophyPendingStore")
	local Boot = load(P .. "AdventureBoot")
	check(DataService.StorageMode() == "LocalOnly", "DataService.StorageMode() == LocalOnly")
	check(DataService.IsMock(), "DataService in memory")
	check(not warned("Studio has no DataStore access"), "no probe-then-fallback warning")
	check(Pending.IsAvailable(), "trophy outbox available (memory)")
	check(Settlement.Outbox.IsAvailable(), "adventure outbox available (memory)")
	check(Boot.Runtime() ~= nil, "AdventureBoot runtime started from candidate flags")
	check(RS:FindFirstChild("SpringVaultAdventure") ~= nil, "adventure remotes exist")

	-- two players, mutations, outbox writes
	local a = Mock.AddPlayer(7101, "CandA")
	local b = Mock.AddPlayer(7102, "CandB")
	Mock.Advance(3)
	check(DataService.IsLoaded(a) and DataService.IsLoaded(b), "both players load in memory")
	DataService.Set(a, "Coins", 1234)
	DataService.Increment(b, "Coins", 55)
	DataService.Set(a, "MaxDepth", 40)
	local added, read
	env.task.spawn(function()
		added = Pending.Add(7101, "trophy:cand:7101:final:v1", {
			TrophyId = "landmark_spring_vault",
			Source = "adventure",
			RegionId = "spring_vault",
			At = os.time(),
		})
		read = Settlement.Outbox.Read(7102)
	end)
	Mock.Advance(1)
	check(added ~= nil, "trophy outbox write completes in memory")
	check(type(read) == "table", "adventure outbox read completes in memory")

	-- purchase-history path (receipt + idempotent retry)
	Config.Monetization.Products.CoinsSmall.Id = 9001
	local marketplace = Mock.Service("MarketplaceService")
	local receipt = { PlayerId = 7101, ProductId = 9001, PurchaseId = "cand-purchase-1", CurrencySpent = 25 }
	local d1, d2
	env.task.spawn(function()
		d1 = marketplace.ProcessReceipt(receipt)
	end)
	Mock.Advance(1)
	local coinsAfter = DataService.Get(a).Coins
	env.task.spawn(function()
		d2 = marketplace.ProcessReceipt(receipt)
	end)
	Mock.Advance(1)
	check(d1 == Mock.Enum.ProductPurchaseDecision.PurchaseGranted, "receipt granted (in-memory history)")
	check(
		d2 == Mock.Enum.ProductPurchaseDecision.PurchaseGranted and DataService.Get(a).Coins == coinsAfter,
		"receipt idempotent in memory"
	)
	check(Monetization ~= nil, "MonetizationService loaded")

	-- leaderboard refresh (explicit + the Start loop) and an autosave tick
	local refreshed = false
	env.task.spawn(function()
		Leaderboard.Refresh()
		refreshed = true
	end)
	Mock.Advance(2)
	check(refreshed, "leaderboard refresh completes")
	check(#Leaderboard.GetEntries("LeaderboardCoins", "AllTime") >= 1, "all-time board falls back to this server")
	Mock.Advance(Config.AUTOSAVE_SECONDS + Config.LEADERBOARD_REFRESH_SECONDS + 5)

	-- removal, rejoin from memory, BindToClose
	Mock.RemovePlayer(a)
	Mock.Advance(3)
	local again = Mock.AddPlayer(7101, "CandA")
	Mock.Advance(3)
	check(
		DataService.IsLoaded(again) and DataService.Get(again).Coins == coinsAfter,
		"rejoin restores the in-memory save"
	)
	Mock.RunBindToClose()
	Mock.Advance(30)

	check(#Mock.DataStoreCalls == 0, "ZERO DataStoreService calls (got: " .. storeCalls() .. ")")
	check(next(Mock.DataStores) == nil, "no store created")
	local counters = Gate.Counters()
	check(count(counters.Acquired) == 0, "StorageGate acquired nothing")
	check(count(counters.Refused) == 0, "nothing even asked the StorageGate")
	local manifest = Profile.Manifest()
	check(manifest.Mode == "LocalOnly" and manifest.Reason == nil, "manifest mode")
	check(manifest.PlaceId == 0 and manifest.GameId == 0 and manifest.IsStudio == true, "manifest environment")
	check(manifest.AuthorizedPlace == "Expansion1Review.rbxlx", "manifest authorized place")
	check(manifest.Flags and manifest.Flags.SpringVault == true, "manifest flags")
	check(manifest.Storage and count(manifest.Storage.Acquired) == 0, "manifest storage counters")

	-- the gate itself refuses without touching the engine
	local ok, err = pcall(Gate.GetDataStore, "PlayerData_v1")
	check(not ok and has(err, "StorageGate: LocalOnly"), "gate refuses GetDataStore: " .. tostring(err))
	local okO = pcall(Gate.GetOrderedDataStore, "Leaderboard_Coins")
	local okB = pcall(Gate.GetRequestBudget, Mock.Enum.DataStoreRequestType.SetIncrementSortedAsync)
	check(not okO and not okB, "gate refuses ordered stores and budget queries")
	check(#Mock.DataStoreCalls == 0, "refused gate calls never reach the engine")
	check(Gate.Counters().Refused["DataStore:PlayerData_v1"] == 1, "refused attempt recorded")
	finish("LocalOnly")

-- Refusals + static ------------------------------------------------------------------------------
elseif mode == "refusals" then
	do
		local srcFiles = 0
		local storageGateSeen = false
		for _, entry in Generated.Sources do
			if
				entry.Source
				and (
					entry.Path[1] == "ServerScriptService"
					or entry.Path[1] == "ReplicatedStorage"
					or entry.Path[1] == "StarterPlayer"
				)
			then
				srcFiles += 1
				local path = table.concat(entry.Path, "/")
				if has(entry.Source, "DataStoreService") then
					if path == "ServerScriptService/Server/Services/StorageGate" then
						storageGateSeen = true
					else
						check(false, "only StorageGate names DataStoreService (found in " .. path .. ")")
					end
				end
			end
		end
		check(srcFiles > 50 and storageGateSeen, "static scan covered src/ and found StorageGate")
		local Review = require("../build/test/production-review")
		check(not has(Review.DefaultProject, "ProductionCandidate"), "default.project.json maps no ProductionCandidate")
		check(not has(Review.DefaultProject, "CandidateConfig"), "default.project.json maps no CandidateConfig")
		local flagsSource
		for _, entry in Generated.Sources do
			if table.concat(entry.Path, "/") == P .. "AdventureFlags" then
				flagsSource = entry.Source
			end
		end
		local body = string.match(flagsSource or "", "local AdventureFlags = (%b{})") or ""
		for _, name in { "SpringVault", "AdventureRewards", "BroadwaveOrdinary" } do
			check(string.find(body, name .. "%s*=%s*false") ~= nil, "shipped AdventureFlags." .. name .. " = false")
		end
		check(not string.find(body, "=%s*true"), "no shipped flag is true")
	end

	local Profile = load(P .. "CandidateProfile")
	local rsBefore = children(RS)
	local wsBefore = children(Workspace)
	local cases = {
		{
			"not Studio",
			"not running in Studio",
			function()
				Mock.IsStudio = false
				install()
			end,
		},
		{
			"not a server",
			"not a server",
			function()
				Mock.ClientMode = true
				install()
			end,
		},
		{
			"PlaceId",
			"PlaceId",
			function()
				Mock.Internal(Mock.Game).props.PlaceId = 4242
				install()
			end,
		},
		{
			"GameId",
			"GameId",
			function()
				Mock.Internal(Mock.Game).props.GameId = 99
				install()
			end,
		},
		{
			"not a Folder",
			"expected a Folder",
			function()
				install({ Class = "Model" })
			end,
		},
		{
			"marker attribute missing",
			"ProductionCandidate attribute",
			function()
				install({ Marker = false })
			end,
		},
		{
			"AuthorizedPlace missing",
			"AuthorizedPlace attribute is missing",
			function()
				install({ Place = false })
			end,
		},
		{
			"AuthorizedPlace wrong",
			"is not an Expansion1Review place",
			function()
				install({ Place = "OtherPlace.rbxlx" })
			end,
		},
		{
			"Authorization wrong",
			"Authorization",
			function()
				install({
					Source = 'return { Authorization = "Other", Storage = "LocalOnly", Flags = { SpringVault = true, AdventureRewards = true, BroadwaveOrdinary = true } }',
				})
			end,
		},
		{
			"Storage not LocalOnly",
			"Storage",
			function()
				install({
					Source = 'return { Authorization = "Expansion1Review", Storage = "DataStore", Flags = { SpringVault = true, AdventureRewards = true, BroadwaveOrdinary = true } }',
				})
			end,
		},
		{
			"unknown flag key",
			"unknown key Extra",
			function()
				install({
					Source = 'return { Authorization = "Expansion1Review", Storage = "LocalOnly", Flags = { SpringVault = true, AdventureRewards = true, BroadwaveOrdinary = true, Extra = true } }',
				})
			end,
		},
		{
			"non-boolean flag",
			"is not a boolean",
			function()
				install({
					Source = 'return { Authorization = "Expansion1Review", Storage = "LocalOnly", Flags = { SpringVault = "yes", AdventureRewards = true, BroadwaveOrdinary = true } }',
				})
			end,
		},
		{
			"unknown config key",
			"unknown key Persist",
			function()
				install({
					Source = 'return { Authorization = "Expansion1Review", Storage = "LocalOnly", Persist = true, Flags = { SpringVault = true, AdventureRewards = true, BroadwaveOrdinary = true } }',
				})
			end,
		},
		{
			"config errors on require",
			"failed to load",
			function()
				install({ Source = 'error("installer bug")' })
			end,
		},
		{
			"config not a table",
			"did not return a table",
			function()
				install({ Source = "return 5" })
			end,
		},
	}
	for _, case in cases do
		local label, expect, setup = case[1], case[2], case[3]
		-- clean environment, then the one fault
		Mock.IsStudio = true
		Mock.ClientMode = false
		Mock.Internal(Mock.Game).props.PlaceId = 0
		Mock.Internal(Mock.Game).props.GameId = 0
		env.shared.DigToTheCoreServer = nil
		RS:SetAttribute("CandidateProfile", nil)
		Profile._Reset()
		setup()
		local warnsBefore = #Mock.Warnings
		Mock.RunScript(main)
		Mock.Advance(2)
		Mock.ClientMode = false
		check(Profile.Mode() == "Refused", label .. ": Refused (" .. tostring(Profile.Mode()) .. ")")
		local reason = Profile.Refusal()
		check(has(reason, expect), label .. ": reason mentions '" .. expect .. "' (" .. tostring(reason) .. ")")
		check(Profile.Flags() == nil and not Profile.IsLocalOnly(), label .. ": no candidate flags")
		check(
			RS:GetAttribute("CandidateProfile") == "refused: " .. tostring(reason),
			label .. ": attribute says refused"
		)
		local w = false
		for j = warnsBefore + 1, #Mock.Warnings do
			if has(Mock.Warnings[j], "[CandidateProfile] REFUSED: " .. tostring(reason) .. ". Nothing was started") then
				w = true
			end
		end
		check(w, label .. ": REFUSED warning")
		check(RS:GetAttribute("CandidateStorage") == nil, label .. ": no CandidateStorage attribute")
		check(sameChildren(RS, rsBefore) and RS:FindFirstChild("SpringVaultAdventure") == nil, label .. ": no remotes")
		check(sameChildren(Workspace, wsBefore), label .. ": no world built")
		check(#Mock.BindToClose == 0, label .. ": no service started (no BindToClose)")
		check(#Mock.DataStoreCalls == 0, label .. ": zero DataStore calls (" .. storeCalls() .. ")")
		check(not printed(BANNER), label .. ": no LocalOnly banner")
	end
	-- a player joining a refused server gets nothing
	local p = Mock.AddPlayer(7201, "Refused")
	Mock.Advance(3)
	check(p:FindFirstChild("leaderstats") == nil, "refused server: player gets no save/leaderstats")
	local Flags = load(P .. "AdventureFlags")
	check(
		Flags.SpringVault == false and Flags.AdventureRewards == false and Flags.BroadwaveOrdinary == false,
		"refused: AdventureFlags untouched"
	)
	check(#Mock.DataStoreCalls == 0, "refusals: zero DataStore calls overall")
	local Gate = load(P .. "StorageGate")
	local ok, err = pcall(Gate.GetDataStore, "PlayerData_v1")
	check(not ok and has(err, "StorageGate: Refused"), "gate refuses in Refused mode: " .. tostring(err))
	check(#Mock.DataStoreCalls == 0, "refused gate never reaches the engine")
	check(Profile.Manifest().Mode == "Refused", "manifest says Refused")
	finish("Refusals (" .. #cases .. " cases)")

-- Production (no marker) --------------------------------------------------------------------------
elseif mode == "production" then
	Mock.IsStudio = studioProduction
	local Flags = load(P .. "AdventureFlags")
	check(
		Flags.SpringVault == false and Flags.AdventureRewards == false and Flags.BroadwaveOrdinary == false,
		"production flags all false"
	)
	Mock.RunScript(main)
	Mock.Advance(2)
	local Profile = load(P .. "CandidateProfile")
	local Gate = load(P .. "StorageGate")
	local DataService = load(P .. "DataService")
	local Boot = load(P .. "AdventureBoot")
	check(Profile.Mode() == "Production" and Profile.Refusal() == nil and Profile.Flags() == nil, "Production mode")
	check(RS:GetAttribute("CandidateProfile") == nil and RS:GetAttribute("CandidateStorage") == nil, "no attributes")
	check(not printed("[CandidateProfile]") and not warned("[CandidateProfile]"), "no CandidateProfile output")
	check(DataService.StorageMode() == "DataStore" and not DataService.IsMock(), "DataService uses the DataStore")
	check(Boot.Runtime() == nil, "adventure runtime off")
	for _, name in { "PlayerData_v1", "PurchaseHistory_v1", "TrophyPendingGrants_v1", "AdventureRewardIntents_v1" } do
		check(called("GetDataStore " .. name), "acquires " .. name)
		check(Gate.Counters().Acquired["DataStore:" .. name] == 1, "gate counted " .. name)
	end
	for _, name in { Config.LEADERBOARD_COINS_STORE, Config.LEADERBOARD_DEPTH_STORE } do
		check(called("GetOrderedDataStore " .. name), "acquires ordered " .. name)
	end
	check(
		called("PlayerData_v1.GetAsync __probe") == studioProduction,
		"Studio probe exactly as before (" .. tostring(studioProduction) .. ")"
	)
	local p = Mock.AddPlayer(7301, "Prod")
	Mock.Advance(3)
	check(DataService.IsLoaded(p), "player loads from the DataStore")
	check(called("PlayerData_v1.UpdateAsync Player_7301"), "load takes the session lock with UpdateAsync")
	DataService.Set(p, "Coins", 77)
	Mock.Advance(Config.LEADERBOARD_REFRESH_SECONDS + 5)
	check(called("GetRequestBudgetForRequestType"), "leaderboard checks the write budget")
	check(Gate.Counters().Acquired["RequestBudget:SetIncrementSortedAsync"] ~= nil, "gate counted budget query")
	Mock.RemovePlayer(p)
	Mock.Advance(3)
	local record = Mock.DataStores.PlayerData_v1 and Mock.DataStores.PlayerData_v1.Player_7301
	check(record and record.Data.Coins == 77 and record.Lock == nil, "removal saves and releases the lock")
	check(count(Gate.Counters().Refused) == 0, "production refuses nothing")
	finish("Production" .. (if studioProduction then " (Studio)" else ""))
else
	error("unknown mode " .. tostring(mode))
end
