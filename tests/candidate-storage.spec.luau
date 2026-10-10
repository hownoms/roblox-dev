--!nocheck
--[[
	LocalOnly candidate storage (CandidateProfile + StorageGate) through the REAL Main.
	  luau tests/candidate-storage.spec.luau -a localonly            valid Studio candidate
	  luau tests/candidate-storage.spec.luau -a refusals             every refusal + static checks
	  luau tests/candidate-storage.spec.luau -a production           no marker, live server
	  luau tests/candidate-storage.spec.luau -a production studio    no marker, Studio with access
	  luau tests/candidate-storage.spec.luau -a localids             Studio test ids (-1, -2) settle in LocalOnly
	  luau tests/candidate-storage.spec.luau -a localids mock        ... refused: Studio in-memory fallback
	  luau tests/candidate-storage.spec.luau -a localids production  ... refused: live DataStore server
	  luau tests/candidate-storage.spec.luau -a localids notstudio   ... refused: LocalOnly, not Studio at use time

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
-- The committed read-only acceptance observer (tools/expansion1/production-candidate), run as
-- the candidate installs it: a Script whose parent is its host folder.
local CandidateTools = require("../build/test/production-candidate")
local function runObserver(parent)
	local observer = env.Instance.new("Script")
	observer.Name = "CandidateObserver"
	Mock.SetSource(observer, CandidateTools.Observer)
	observer.Parent = parent
	Mock.RunScript(observer)
	return observer
end
local function observerLine(needle)
	for _, line in Mock.Prints do
		if has(line, "[CandidateObserver]") and has(line, needle) then
			return line
		end
	end
	return nil
end
local function printedCount(needle)
	local n = 0
	for _, line in Mock.Prints do
		if has(line, needle) then
			n += 1
		end
	end
	return n
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
	local candidateFolder = SSS:FindFirstChild("ProductionCandidate")
	local remotesBefore = #RS:GetDescendants()
	runObserver(candidateFolder)
	Mock.Advance(1.5)
	check(printed("[CandidateObserver]") and printed("active (LocalOnly; read-only)"), "observer active in LocalOnly")

	-- two players, mutations, outbox writes
	local a = Mock.AddPlayer(7101, "CandA")
	local b = Mock.AddPlayer(7102, "CandB")
	Mock.Advance(3)
	check(DataService.IsLoaded(a) and DataService.IsLoaded(b), "both players load in memory")

	-- a real final settlement in memory: the card payload says the store is not durable
	do
		local sent = {}
		local conn = Settlement.OutcomeSent:Connect(function(player, outcome)
			sent[player.UserId] = outcome
		end)
		local participant = {
			UserId = 7102,
			Points = 20,
			Eligible = true,
			ActiveSeconds = 90,
			ObjectiveIds = { "vault_anchor_1" },
		}
		local context = table.freeze({
			BoundaryVersion = 1,
			EventInstanceId = "cand:local:1",
			EventId = "event_vault",
			LandmarkId = "landmark_spring_vault",
			RegionId = "sunshine_shore",
			Success = true,
			ObjectiveIds = { "vault_anchor_1" },
			CompletedStages = { "excavation", "vault_open", "ball_return" },
			Participants = { participant },
		})
		local accepted
		env.task.spawn(function()
			accepted = Settlement.OnCompletion(context)
		end)
		Mock.Advance(3)
		conn:Disconnect()
		local card = sent[7102]
		check(accepted == true, "LocalOnly settlement accepted in memory")
		check(
			card ~= nil and card.State == "Accepted" and card.Status == "Saved" and card.Storage == "LocalOnly",
			"LocalOnly outcome keeps its state and says Storage = LocalOnly ("
				.. tostring(card and card.Status)
				.. "/"
				.. tostring(card and card.Storage)
				.. ")"
		)
		check(sent[7101] == nil, "non-participant gets no outcome")
		check(#Mock.DataStoreCalls == 0, "settlement made no DataStore call")
		check(
			printed("outcome CandB: Final") and printed("storage=LocalOnly"),
			"observer logged the participant's outcome with its storage label"
		)
		check(not printed("outcome CandA:"), "observer: no outcome logged for the non-participant")
	end
	check(printed("loaded CandA #1") and printed("canEnter=false/NoEvidence"), "observer logs load + real eligibility")
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
	check(printed("leave CandA (7101)") and printed("join CandA (7101) #2 REJOIN"), "observer logs leave + rejoin")
	check(
		printed("rejoin check CandA: coins " .. coinsAfter .. " -> " .. coinsAfter),
		"observer compares the save across the same-server rejoin (" .. tostring(observerLine("rejoin check")) .. ")"
	)
	local seq = candidateFolder:GetAttribute("ObservationSeq")
	check(type(seq) == "number" and seq >= 5, "observer snapshots keep publishing (" .. tostring(seq) .. ")")
	check(type(candidateFolder:GetAttribute("Observation")) == "string", "snapshot published on its own folder")
	check(not printed("snapshot failed"), "every snapshot encoded (serializable, no errors)")
	check(#RS:GetDescendants() == remotesBefore, "observer created nothing replicated")
	for _, p in Players:GetPlayers() do
		check(
			p:GetAttribute("Observation") == nil and p:GetAttribute("ObservationSeq") == nil,
			"observer writes nothing on players"
		)
	end
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
	end
	do
		-- The acceptance observer and client label are read-only: no save writes, grants,
		-- settlement, entry/boot control, storage, remotes or replicated attributes.
		local observer, client = CandidateTools.Observer, CandidateTools.Client
		for _, token in
			{
				"DataService.Set",
				"DataService.Mutate",
				"DataService.Increment",
				"DataService.Save",
				"SaveAsync",
				"UpdateAsync",
				"DataStoreService",
				"StorageGate.Get",
				"OnCompletion(",
				"OnStage(",
				"SettleStage",
				"SetEnabled",
				"Grant",
				"Boot.Start",
				"Boot.Disable",
				"Entry.Start",
				"Entry.Stop",
				"ReturnToSurface",
				"ConsiderInvite",
				"PipQuest",
				'"BroadwaveLicense"',
				"RegisterIssuedTool",
				"Fire(",
				"FireClient",
				"FireAllClients",
				"FireServer",
				"InvokeServer",
				"Instance.new",
				":Destroy(",
				".Parent =",
				"Handle(",
			}
		do
			check(not has(observer, token), "observer source has no " .. token)
		end
		local setters = 0
		for line in string.gmatch(observer, "[^\n]*SetAttribute[^\n]*") do
			setters += 1
			check(has(line, "folder:SetAttribute("), "observer only sets attributes on its own folder: " .. line)
		end
		check(setters == 2, "observer sets exactly Observation and ObservationSeq (" .. setters .. ")")
		check(
			has(observer, 'ReplicatedStorage:GetAttribute("CandidateProfile") ~= "LocalOnly"'),
			"observer gates on LocalOnly"
		)
		check(has(observer, 'DataService.StorageMode() ~= "LocalOnly"'), "observer re-checks StorageMode")
		for _, token in { "FireServer", "InvokeServer", "SetAttribute", "DataService" } do
			check(not has(client, token), "candidate client label has no " .. token)
		end
		check(
			has(CandidateTools.Project, "CandidateObserver.server.luau")
				and not has(CandidateTools.DefaultProject, "CandidateObserver")
				and not has(CandidateTools.DefaultProject, "production-candidate"),
			"observer mapped only by the candidate project"
		)
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
	do
		local host = env.Instance.new("Folder")
		host.Name = "ObserverHost"
		host.Parent = Mock.Service("ServerStorage")
		runObserver(host)
		Mock.Advance(62)
		check(printed("[CandidateObserver] inert"), "observer is inert outside a LocalOnly candidate")
		check(host:GetAttribute("Observation") == nil, "inert observer publishes nothing")
	end
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

-- Local simulation ids (LocalSimulationPolicy) -----------------------------------------------------
elseif mode == "localids" then
	local variant = args[2] or "localonly"
	local function finalContext(instanceId, participants)
		return table.freeze({
			BoundaryVersion = 1,
			EventInstanceId = instanceId,
			EventId = "event_vault",
			LandmarkId = "landmark_spring_vault",
			RegionId = "sunshine_shore",
			Success = true,
			ObjectiveIds = { "vault_anchor_1" },
			CompletedStages = { "excavation", "vault_open", "ball_return" },
			Participants = participants,
		})
	end
	local function stageObservation(instanceId, participants)
		return table.freeze({
			BoundaryVersion = 1,
			EventInstanceId = instanceId,
			EventId = "event_vault",
			LandmarkId = "landmark_spring_vault",
			RegionId = "sunshine_shore",
			StageId = "excavation",
			CompletedStages = { "excavation" },
			Participants = participants,
		})
	end
	-- contributor: earns everything; watcher: stayed to the end but earned 0 points (runtime vetoes)
	local function contributor(id)
		return { UserId = id, Points = 20, Eligible = true, ActiveSeconds = 90, ObjectiveIds = { "vault_anchor_1" } }
	end
	local function watcher(id)
		return { UserId = id, Points = 0, Eligible = false, ActiveSeconds = 90, ObjectiveIds = {} }
	end
	local function stageP(id, points)
		return { UserId = id, Points = points, ObjectiveIds = {}, Connected = true, Left = false }
	end

	-- 1. Pure validation (shared modules, no services) -------------------------------------
	do
		local Rules = load("ReplicatedStorage/Shared/Trophies/Rules")
		local Rewards = load("ReplicatedStorage/Shared/Rewards/AdventureRewards")
		local function yes()
			return true
		end
		local function no()
			return false
		end
		for _, v in { -1, -2, 0, -1.5, -65, 0 / 0, math.huge, -math.huge, "1", 2 ^ 53 + 2 } do
			check(not Rules.IsUserId(v), "default IsUserId rejects " .. tostring(v))
		end
		check(Rules.IsUserId(1) and Rules.IsUserId(7101) and Rules.IsUserId(2 ^ 53), "default accepts real ids")
		check(
			Rules.IsUserId(-1, yes) and Rules.IsUserId(-2, yes) and Rules.IsUserId(-64, yes),
			"policy accepts -1/-2/-64"
		)
		for _, v in { 0, -65, -1.5, -1000, 0 / 0, -math.huge, "-1" } do
			check(not Rules.IsUserId(v, yes), "policy still rejects " .. tostring(v))
		end
		check(not Rules.IsUserId(-1, no), "a predicate that refuses keeps -1 rejected")
		check(Rules.IsUserId(7101, no), "real ids never depend on the predicate")
		local asked = false
		Rules.IsUserId(-65, function()
			asked = true
			return true
		end)
		check(not asked, "the predicate is never asked about an out-of-range id")
		check(Rules.LOCAL_SIM_MIN_USER_ID == -64, "range floor is -64")

		local function tp(id)
			return { UserId = id, Points = 20, ActiveSeconds = 90, ObjectiveCompletions = 1, PresentForObjective = true }
		end
		check(not Rules.IsParticipant(tp(-1)), "IsParticipant default rejects -1")
		check(Rules.IsParticipant(tp(-1), yes), "IsParticipant with policy accepts -1")
		check(Rules.IsParticipant(tp(7101)), "IsParticipant accepts a real id")

		local ctx = finalContext("pure:1", { contributor(-1), watcher(-2) })
		local d, e = Rewards.FinalDecisions(ctx, 1000)
		check(
			d == nil and e == "BadParticipants",
			"FinalDecisions default: -1/-2 -> BadParticipants (" .. tostring(e) .. ")"
		)
		d, e = Rewards.FinalDecisions(ctx, 1000, {})
		check(d == nil and e == "BadParticipants", "FinalDecisions empty options: BadParticipants")
		d, e = Rewards.FinalDecisions(ctx, 1000, { AcceptLocalUserId = yes })
		check(d ~= nil and #d == 2, "FinalDecisions with policy decides both (" .. tostring(e) .. ")")
		if d then
			check(d[1].Intent ~= nil and d[1].Intent.UserId == -1, "contributor -1 gets an intent")
			check(
				d[2].Intent == nil and d[2].Reason == "LowContribution",
				"0-point watcher -2 still refused by the normal rules (" .. tostring(d[2].Reason) .. ")"
			)
			local receipt = Rewards.ReceiptFor(d[1].Intent)
			check(receipt == "adv:pure:1:-1:final:v1", "receipt keeps the real negative id: " .. receipt)
			check(not Rewards.IsIntent(receipt, d[1].Intent), "outbox read-back still rejects simulated ids")
		end
		d, e = Rewards.FinalDecisions(
			finalContext("pure:2", { contributor(-1), watcher(-1) }),
			1000,
			{ AcceptLocalUserId = yes }
		)
		check(d == nil and e == "BadParticipants", "duplicate -1 still BadParticipants with policy")
		d, e = Rewards.FinalDecisions(finalContext("pure:3", { contributor(-65) }), 1000, { AcceptLocalUserId = yes })
		check(d == nil and e == "BadParticipants", "-65 still BadParticipants with policy")
		d, e = Rewards.FinalDecisions(finalContext("pure:4", { contributor(-1) }), 1000, { AcceptLocalUserId = no })
		check(d == nil and e == "BadParticipants", "refusing predicate: BadParticipants")
		for _, bad in { 0, -1.5 } do
			d, e =
				Rewards.FinalDecisions(finalContext("pure:5", { contributor(bad) }), 1000, { AcceptLocalUserId = yes })
			check(d == nil and e == "BadParticipants", tostring(bad) .. " still BadParticipants with policy")
		end
		local obs = stageObservation("pure:6", { stageP(-1, 10), stageP(-2, 0) })
		d, e = Rewards.StageDecisions(obs, 1000)
		check(d == nil and e == "BadParticipants", "StageDecisions default: BadParticipants")
		d, e = Rewards.StageDecisions(obs, 1000, { AcceptLocalUserId = yes })
		check(
			d ~= nil and d[1].Intent ~= nil and d[2].Reason == "NoContribution",
			"StageDecisions with policy: contributor granted, 0 points refused"
		)
		d, e = Rewards.FinalDecisions(finalContext("pure:7", { contributor(7101), watcher(7102) }), 1000)
		check(
			d ~= nil and d[1].Intent ~= nil and d[2].Reason == "LowContribution",
			"real ids unchanged without options"
		)
	end

	-- 2. Real Main, one storage mode per variant -------------------------------------------
	if variant == "localonly" or variant == "notstudio" then
		Mock.IsStudio = true
		install()
	elseif variant == "mock" then
		Mock.IsStudio = true
		Mock.DataStoreFail = true
	elseif variant == "production" then
		Mock.IsStudio = false
	else
		error("unknown localids variant " .. tostring(variant))
	end
	Mock.RunScript(main)
	Mock.Advance(2)
	check(#Mock.Errors == 0, "Main boots")
	local Profile = load(P .. "CandidateProfile")
	local DataService = load(P .. "DataService")
	local Settlement = load(P .. "AdventureSettlement")
	local Policy = load(P .. "LocalSimulationPolicy")
	local Pending = load(P .. "TrophyPendingStore")
	local expectStorage = ({
		localonly = "LocalOnly",
		notstudio = "LocalOnly",
		mock = "Mock",
		production = "DataStore",
	})[variant]
	check(
		DataService.StorageMode() == expectStorage,
		variant .. ": storage " .. tostring(DataService.StorageMode()) .. " == " .. expectStorage
	)
	check(Profile.IsLocalOnly() == (expectStorage == "LocalOnly"), variant .. ": candidate profile")

	local sent = {}
	Settlement.OutcomeSent:Connect(function(player, outcome)
		sent[player.UserId] = sent[player.UserId] or {}
		table.insert(sent[player.UserId], outcome)
	end)
	local function lastCard(id)
		local list = sent[id]
		return list and list[#list]
	end
	local function settleFinal(ctx)
		local report
		env.task.spawn(function()
			report = Settlement.SettleCompletion(ctx)
		end)
		Mock.Advance(3)
		return report
	end
	local function settleStage(obs)
		local report
		env.task.spawn(function()
			report = Settlement.SettleStage(obs)
		end)
		Mock.Advance(3)
		return report
	end

	local a = Mock.AddPlayer(-1, "Player1")
	local b = Mock.AddPlayer(-2, "Player2")
	local c = Mock.AddPlayer(-3, "Player3") -- bystander, never joins an adventure
	Mock.Advance(3)
	check(DataService.IsLoaded(a) and DataService.IsLoaded(b) and DataService.IsLoaded(c), "negative-id players load")
	local coinsA0 = DataService.Get(a).Coins
	local coinsB0 = DataService.Get(b).Coins

	if variant == "notstudio" then
		Mock.IsStudio = false -- after a valid LocalOnly resolution: the guard is evaluated at use time
	end

	if variant == "localonly" then
		check(Policy.IsEnabled(), "policy enabled: Studio + LocalOnly profile + LocalOnly storage")
		check(Policy.Predicate() ~= nil, "predicate handed out")
		check(Policy.AcceptsUserId(-1) and Policy.AcceptsUserId(-3), "joined Studio ids accepted")
		check(not Policy.AcceptsUserId(-9), "an id no Player joined with is not accepted")
		check(not Policy.AcceptsUserId(-65) and not Policy.AcceptsUserId(0), "out-of-range ids not accepted")
		check(not Policy.AcceptsUserId(7101), "the policy never vouches for real ids")
		check(table.isfrozen(Policy), "policy module is frozen")
		check(not pcall(function()
			Policy.IsEnabled = function()
				return true
			end
		end), "policy guard cannot be replaced")

		-- stage: contributor granted, 0-point player refused, bystander nothing
		local sr = settleStage(stageObservation("studio:local:1", { stageP(-1, 10), stageP(-2, 0) }))
		check(sr and sr.Ok, "stage settles in LocalOnly (" .. tostring(sr and sr.Error) .. ")")
		local sa, sb = lastCard(-1), lastCard(-2)
		check(
			sa and sa.Kind == "Stage" and sa.State == "Accepted" and sa.Storage == "LocalOnly" and sa.Coins > 0,
			"stage: -1 Accepted card, Storage LocalOnly"
		)
		check(sb and sb.State == "Refused" and sb.Reason == "NoContribution", "stage: -2 Refused NoContribution")
		check(sent[-3] == nil, "stage: bystander gets nothing")

		-- final run 1
		local r1 = settleFinal(finalContext("studio:local:1", { contributor(-1), watcher(-2) }))
		check(r1 and r1.Ok and r1.Done, "final run 1 settles (" .. tostring(r1 and r1.Error) .. ")")
		local ca, cb = lastCard(-1), lastCard(-2)
		check(
			ca
				and ca.Kind == "Final"
				and ca.InstanceId == "studio:local:1"
				and ca.State == "Accepted"
				and ca.Status == "Saved"
				and ca.Storage == "LocalOnly"
				and ca.Trophy == true
				and ca.Stand == true
				and ca.Certification ~= nil,
			"run 1: -1 Accepted card with trophy/stand/cert, Storage LocalOnly ("
				.. tostring(ca and ca.State)
				.. "/"
				.. tostring(ca and ca.Status)
				.. "/"
				.. tostring(ca and ca.Reason)
				.. ")"
		)
		check(
			cb and cb.Kind == "Final" and cb.State == "Refused" and cb.Coins == 0 and cb.Trophy == false,
			"run 1: -2 Refused (" .. tostring(cb and cb.Reason) .. ")"
		)
		check(sent[-3] == nil, "run 1: bystander gets nothing")
		check(DataService.Get(a).Coins > coinsA0, "run 1: coins in -1's in-memory save")
		check(DataService.Get(b).Coins == coinsB0, "run 1: -2's save unchanged")
		check(r1 and r1.Trophy and r1.Trophy.Ok, "run 1: TrophyService settled the same context")

		-- final run 2: distinct instance, -2 contributes this time, plus a real-id player
		local d = Mock.AddPlayer(7101, "RealId")
		Mock.Advance(3)
		local before = #sent[-1]
		local r2 = settleFinal(finalContext("studio:local:2", { contributor(-1), contributor(-2), contributor(7101) }))
		check(r2 and r2.Ok, "final run 2 settles (" .. tostring(r2 and r2.Error) .. ")")
		local ca2, cb2, cd2 = lastCard(-1), lastCard(-2), lastCard(7101)
		check(#sent[-1] == before + 1 and ca2.InstanceId == "studio:local:2", "run 2: -1 gets a new card")
		check(ca2 and ca2.State == "Accepted" and ca2.Trophy == false, "run 2: -1 Accepted, trophy already owned")
		check(
			cb2 and cb2.State == "Accepted" and cb2.Trophy == true and cb2.Storage == "LocalOnly",
			"run 2: -2 now Accepted with trophy"
		)
		check(cd2 and cd2.State == "Accepted" and cd2.Storage == "LocalOnly", "run 2: real id unchanged")
		check(sent[-3] == nil, "run 2: bystander gets nothing")
		check(DataService.Get(d) ~= nil, "real-id player loaded")

		-- replaying run 1 is a Duplicate, never a second grant
		local coinsA1 = DataService.Get(a).Coins
		local r1b = settleFinal(finalContext("studio:local:1", { contributor(-1), watcher(-2) }))
		check(r1b and r1b.Ok and lastCard(-1).Status == "Duplicate", "replayed run 1: Duplicate")
		check(DataService.Get(a).Coins == coinsA1, "replayed run 1: no extra coins")

		-- an id no Player joined with is never vouched for: the whole context is refused
		local r3 = settleFinal(finalContext("studio:local:3", { contributor(-1), contributor(-9) }))
		check(r3 and not r3.Ok and r3.Error == "BadParticipants", "unknown -9 -> BadParticipants")

		-- a failed in-memory save for loaded -1: Unconfirmed (truthfully not durable), never
		-- Queued, and nothing goes to an outbox; the retry then resolves it
		do
			local realSave = DataService.SaveAsync
			local failures = 0
			DataService.SaveAsync = function(player)
				if player == a and failures == 0 then
					failures += 1
					return false
				end
				return realSave(player)
			end
			local before6 = #sent[-1]
			local r6 = settleFinal(finalContext("studio:local:6", { contributor(-1) }))
			DataService.SaveAsync = realSave
			local e6 = r6 and r6.ByUserId[-1]
			local c6 = lastCard(-1)
			check(failures == 1, "save failure injected once")
			check(
				e6 and e6.Status == "Unconfirmed",
				"failed save: entry Unconfirmed, not Queued (" .. tostring(e6 and e6.Status) .. ")"
			)
			check(
				#sent[-1] == before6 + 1
					and c6.InstanceId == "studio:local:6"
					and c6.Status == "Unconfirmed"
					and c6.State == "Pending"
					and c6.Storage == "LocalOnly",
				"failed save: card Unconfirmed/Pending (" .. tostring(c6.Status) .. "/" .. tostring(c6.State) .. ")"
			)
			local q6, t6
			env.task.spawn(function()
				q6, t6 = Settlement.Outbox.Read(-1), Pending.Read(-1)
			end)
			Mock.Advance(1)
			check(q6 and t6 and count(q6) + count(t6) == 0, "failed save: nothing queued in either outbox for -1")
			Mock.Advance(Settlement.RetryDelays[1] + 1)
			local resolved = lastCard(-1)
			check(
				resolved.InstanceId == "studio:local:6"
					and resolved.Resolved == true
					and resolved.State == "Accepted"
					and resolved.Status == "Saved",
				"retry resolves the Unconfirmed grant in memory (" .. tostring(resolved.Status) .. ")"
			)
		end

		-- the same failed save for a simulated id on its FIRST eligible final (trophy + stand newly
		-- granted): the trophy part is Unconfirmed too, never Queued or left Applied
		do
			local e = Mock.AddPlayer(-4, "Player4")
			Mock.Advance(3)
			check(DataService.IsLoaded(e), "-4 loads")
			local realSave = DataService.SaveAsync
			local failures = 0
			DataService.SaveAsync = function(player)
				if player == e and failures == 0 then
					failures += 1
					return false
				end
				return realSave(player)
			end
			local r7 = settleFinal(finalContext("studio:local:7", { contributor(-4) }))
			DataService.SaveAsync = realSave
			local e7 = r7 and r7.ByUserId[-4]
			local c7 = lastCard(-4)
			check(failures == 1, "-4: save failure injected once")
			check(
				e7 and e7.TrophyStatus == "Granted" and e7.TrophyGranted == true and e7.StandGranted == true,
				"-4: trophy and stand newly granted in the live save (" .. tostring(e7 and e7.TrophyStatus) .. ")"
			)
			check(
				e7 and e7.Status == "Unconfirmed" and e7.TrophyDurable == "Unconfirmed",
				"-4: coins and trophy parts Unconfirmed, not Queued/Applied ("
					.. tostring(e7 and e7.Status)
					.. "/"
					.. tostring(e7 and e7.TrophyDurable)
					.. ")"
			)
			check(
				c7 and c7.InstanceId == "studio:local:7" and c7.Status == "Unconfirmed" and c7.State == "Pending",
				"-4: card Unconfirmed/Pending"
			)
			local q7, t7
			env.task.spawn(function()
				q7, t7 = Settlement.Outbox.Read(-4), Pending.Read(-4)
			end)
			Mock.Advance(1)
			check(q7 and t7 and count(q7) + count(t7) == 0, "-4: nothing queued in either outbox")
			Mock.Advance(Settlement.RetryDelays[1] + 1)
			local resolved = lastCard(-4)
			check(
				resolved.InstanceId == "studio:local:7"
					and resolved.Resolved == true
					and resolved.State == "Accepted"
					and resolved.Status == "Saved"
					and resolved.Trophy == true
					and resolved.Stand == true,
				"-4: retry resolves both parts with the trophy (" .. tostring(resolved.Status) .. ")"
			)
			check(e7.Status == "Saved" and e7.TrophyDurable == "Saved", "-4: both parts Saved after the retry")
		end

		-- a participant who left is still a known id, judged by the normal rules
		Mock.RemovePlayer(b)
		Mock.Advance(3)
		local r4 = settleFinal(finalContext("studio:local:4", { contributor(-1), watcher(-2) }))
		check(r4 and r4.Ok, "context with a departed Studio player settles (" .. tostring(r4 and r4.Error) .. ")")
		check(r4 and r4.ByUserId[-2] and r4.ByUserId[-2].Status == "Ineligible", "departed -2 Ineligible")
		-- an eligible-but-not-loaded simulated id is refused, never queued in an outbox
		local r5 = settleFinal(finalContext("studio:local:5", { contributor(-2) }))
		local e5 = r5 and r5.ByUserId[-2]
		check(
			e5 and e5.Status == "Refused" and e5.Reason == "LocalSimulationNotLoaded",
			"not-loaded simulated id refused truthfully ("
				.. tostring(e5 and e5.Status)
				.. "/"
				.. tostring(e5 and e5.Reason)
				.. ")"
		)
		local t5 = r5 and r5.Trophy and r5.Trophy.ByUserId[-2]
		check(
			t5 and t5.Status == "Refused" and t5.Reason == "LocalSimulationNotLoaded",
			"trophy part names the real reason, not a stale PendingWriteFailed ("
				.. tostring(t5 and t5.Status)
				.. "/"
				.. tostring(t5 and t5.Reason)
				.. ")"
		)
		check(
			e5 and e5.TrophyStatus == "Refused" and e5.TrophyReason == "LocalSimulationNotLoaded",
			"entry TrophyReason LocalSimulationNotLoaded (" .. tostring(e5 and e5.TrophyReason) .. ")"
		)
		local card5 = lastCard(-2)
		check(card5 and card5.InstanceId ~= "studio:local:5", "departed -2 gets no card")
		local qa, qb, ta, tb
		env.task.spawn(function()
			qa, qb = Settlement.Outbox.Read(-1), Settlement.Outbox.Read(-2)
			ta, tb = Pending.Read(-1), Pending.Read(-2)
		end)
		Mock.Advance(1)
		check(
			qa and qb and ta and tb and count(qa) + count(qb) + count(ta) + count(tb) == 0,
			"nothing queued for simulated ids"
		)
		Mock.RunBindToClose()
		Mock.Advance(30)
		check(#Mock.DataStoreCalls == 0, "ZERO DataStoreService calls (got: " .. storeCalls() .. ")")
	else
		-- Guard negatives: settlement itself is on, but -1/-2 are still BadParticipants.
		Settlement.SetEnabled(true)
		check(not Policy.IsEnabled() and Policy.Predicate() == nil, variant .. ": policy off")
		check(not Policy.AcceptsUserId(-1), variant .. ": -1 not accepted")

		local sr = settleStage(stageObservation("guard:1", { stageP(-1, 10), stageP(-2, 0) }))
		check(
			sr and not sr.Ok and sr.Error == "BadParticipants",
			variant .. ": stage BadParticipants (" .. tostring(sr and sr.Error) .. ")"
		)
		local r1 = settleFinal(finalContext("guard:1", { contributor(-1), watcher(-2) }))
		check(
			r1 and not r1.Ok and r1.Error == "BadParticipants",
			variant .. ": final BadParticipants (" .. tostring(r1 and r1.Error) .. ")"
		)
		check(sent[-1] == nil and sent[-2] == nil and sent[-3] == nil, variant .. ": no outcome cards")
		check(DataService.Get(a).Coins == coinsA0 and DataService.Get(b).Coins == coinsB0, variant .. ": no grants")
		local qa, ta
		env.task.spawn(function()
			qa, ta = Settlement.Outbox.Read(-1), Pending.Read(-1)
		end)
		Mock.Advance(1)
		check(count(qa) == 0 and count(ta) == 0, variant .. ": nothing queued for -1")
		-- control: the same settlement with a real id is accepted, so the refusal is the id rule
		local d = Mock.AddPlayer(8101, "Real")
		Mock.Advance(3)
		local r2 = settleFinal(finalContext("guard:2", { contributor(8101) }))
		check(
			r2 and r2.Ok and lastCard(8101) and lastCard(8101).State == "Accepted",
			variant .. ": real id control settles (" .. tostring(r2 and r2.Error) .. ")"
		)
		check(DataService.Get(d) ~= nil, variant .. ": real id loaded")
		if variant == "notstudio" then
			-- same server back in Studio: the use-time guard holds again
			Mock.IsStudio = true
			check(Policy.IsEnabled(), "notstudio: guard re-evaluated at use time")
			local r3 = settleFinal(finalContext("guard:3", { contributor(-1) }))
			check(
				r3 and r3.Ok and lastCard(-1) and lastCard(-1).State == "Accepted",
				"notstudio: settles once Studio again"
			)
			Mock.IsStudio = false
		end
	end
	finish("Local ids (" .. variant .. ")")
else
	error("unknown mode " .. tostring(mode))
end
