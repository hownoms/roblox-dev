--!strict
--[[
	ReviewBoot — PRODUCTION-INTEGRATION REVIEW ONLY (docs/integration/production-review.md).

	Mapped only by expansion1-production-review.project.json (and the localhost injector,
	tools/expansion1/inject-production-review.py). default.project.json never maps it;
	tests/production-review.spec.luau checks that.

	What it does, in order:
	  1. Gate: refuses (and starts NOTHING, not even production Main) unless
	       RunService:IsStudio(), game.PlaceId == 0, the review marker attribute
	       (ServerScriptService.ProductionReview.ProductionIntegrationReview == true, created only
	       by the review project / injector), production Main present and still disabled and not
	       booted, and DataStores unreachable (the same probe DataService runs in Studio, so
	       DataService will take its in-memory path).
	  2. Sets AdventureFlags (the shipped module table, defaults untouched in source) from the
	     marker's Flag_<Name> attributes (all on unless an attribute is false), then enables the
	     real ServerScriptService.Server.Main. The production boot is exactly the shipped one.
	  3. After boot: verifies DataService.IsMock() (otherwise disables the adventure and kicks
	     everyone), and self-checks that the running adventure was built from
	     AdventureBoot.Options(AdventureFlags) with the production callbacks (no resolver shim).
	  4. Review helpers (labelled, grant no progress): /reviewseed (explicit, per-player review
	     prerequisite: cert_rookie + a priced shovel in the IN-MEMORY save, marked Review = true and
	     the ReviewPrerequisite player attribute), /reviewstatus, /reviewhatch, and the
	     ProductionReviewProbe BindableFunction for the Studio command bar (server context).

	Nothing here is a production runtime seam: shipped code never requires or reads this module.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")

local ReviewBoot = {}

ReviewBoot.BANNER =
	"PRODUCTION-INTEGRATION REVIEW: in-memory saves, review prerequisites; not production eligibility or persistence evidence"
ReviewBoot.MARKER = "ProductionIntegrationReview" -- attribute on ServerScriptService.ProductionReview
ReviewBoot.STATUS_ATTRIBUTE = "ProductionIntegrationReview" -- on ReplicatedStorage, for the review client
ReviewBoot.PREREQ_ATTRIBUTE = "ReviewPrerequisite" -- on the Player, set only by SeedPrerequisites
ReviewBoot.PREREQ_SOURCE = "ProductionReview"
ReviewBoot.FLAGS = { "SpringVault", "AdventureRewards", "BroadwaveOrdinary" }
ReviewBoot.BOOT_TIMEOUT = 60 -- seconds to wait for production Main to finish booting
ReviewBoot.COMMANDS = { "/reviewseed", "/reviewstatus", "/reviewhatch" }

local TAG = "[ProductionReview]"

type Check = { Name: string, Ok: boolean }

local state: any = {
	Report = nil,
	Server = nil,
	Modules = nil,
}

local function setStatus(text: string)
	ReplicatedStorage:SetAttribute(ReviewBoot.STATUS_ATTRIBUTE, text)
end

-- 1. Gate --------------------------------------------------------------------------------------

function ReviewBoot.Gate(marker: Instance?, server: Instance?): (boolean, string)
	if not RunService:IsStudio() then
		return false, "not running in Roblox Studio"
	end
	if game.PlaceId ~= 0 then
		return false,
			"PlaceId is " .. tostring(game.PlaceId) .. "; the review only runs in an unpublished place (PlaceId 0)"
	end
	if marker == nil or marker:GetAttribute(ReviewBoot.MARKER) ~= true then
		return false, "review marker attribute " .. ReviewBoot.MARKER .. " missing"
	end
	if (shared :: any).DigToTheCoreServer then
		return false,
			"production Main already booted ("
				.. tostring((shared :: any).DigToTheCoreServer)
				.. "); review flags must be set before it runs"
	end
	local main = server and server:FindFirstChild("Main")
	if main == nil or not main:IsA("Script") then
		return false, "ServerScriptService.Server.Main missing"
	end
	if (main :: Script).Enabled then
		return false, "ServerScriptService.Server.Main is enabled; the review ships it disabled and enables it itself"
	end
	local shared_ = ReplicatedStorage:FindFirstChild("Shared")
	local configModule = shared_ and shared_:FindFirstChild("Config")
	if configModule == nil or not configModule:IsA("ModuleScript") then
		return false, "ReplicatedStorage.Shared.Config missing"
	end
	local Config = (require :: any)(configModule)
	-- Same probe as DataService.detectStore in Studio: if it succeeds, saves would be durable.
	local reachable = pcall(function(): any
		return DataStoreService:GetDataStore(Config.DATASTORE_NAME):GetAsync("__probe")
	end)
	if reachable then
		return false, "DataStores are reachable; the review requires DataService's in-memory store"
	end
	return true, "ok"
end

-- 3. Self-check --------------------------------------------------------------------------------

local function count(t: any): number
	local n = 0
	if type(t) == "table" then
		for _ in t do
			n += 1
		end
	end
	return n
end

-- The adventure must be the one AdventureBoot.Start built from AdventureBoot.Options(Flags), with
-- the production callbacks, and nothing from Codex's dedicated review may be present.
function ReviewBoot.SelfCheck(): { Check }
	local m = state.Modules
	local Flags, Boot = m.Flags, m.AdventureBoot
	local checks: { Check } = {}
	local function check(name: string, ok: boolean)
		table.insert(checks, { Name = name, Ok = ok == true })
	end
	local runtime = Boot.Runtime()
	check("AdventureBoot.Runtime() exists", (runtime ~= nil) == (Flags.SpringVault == true))
	local okOptions, options = pcall(Boot.Options, Flags)
	check("AdventureBoot.Options(AdventureFlags) builds", okOptions and type(options) == "table")
	options = if okOptions and type(options) == "table" then options else {}
	check("CanEnter is AdventureEligibility.CanEnter", rawequal(options.CanEnter, m.Eligibility.CanEnter))
	check("CanTrial is AdventureEligibility.CanTrial", rawequal(options.CanTrial, m.Eligibility.CanTrial))
	local okFrame, frame = pcall(function(): any
		return options.ReturnFrame and options.ReturnFrame(nil)
	end)
	check("ReturnFrame lands on AdventureEntry.SURFACE_RETURN", okFrame and frame == m.AdventureEntry.SURFACE_RETURN)
	if Flags.AdventureRewards then
		check(
			"OnCompletion is AdventureSettlement.OnCompletion",
			rawequal(options.OnCompletion, m.AdventureSettlement.OnCompletion)
		)
		check("OnStage is AdventureSettlement.OnStage", rawequal(options.OnStage, m.AdventureSettlement.OnStage))
	else
		check(
			"OnCompletion is AdventureBoot's refusal (rewards flag off)",
			type(options.OnCompletion) == "function"
				and not rawequal(options.OnCompletion, m.AdventureSettlement.OnCompletion)
		)
		check("no OnStage (rewards flag off)", options.OnStage == nil)
	end
	if Flags.BroadwaveOrdinary then
		check(
			"ResolveTool is BroadwaveLicense.ResolveTool",
			rawequal(options.ResolveTool, m.BroadwaveLicense.ResolveTool)
		)
		check("OnOrdinaryBroadwave is the BroadwaveDigBridge adapter", type(options.OnOrdinaryBroadwave) == "function")
	else
		check(
			"no ResolveTool / OnOrdinaryBroadwave (ordinary flag off)",
			options.ResolveTool == nil and options.OnOrdinaryBroadwave == nil
		)
	end
	check("no ReviewSpawn option", options.ReviewSpawn == nil)
	check(
		"Codex's dedicated review is not loaded",
		ServerScriptService:FindFirstChild("AdventureReview") == nil
			and ServerScriptService:FindFirstChild("AdventureReviewProbe", true) == nil
	)
	if Flags.SpringVault then
		local adapter = runtime and runtime.ReviewAdapter
		check("Codex review completion adapter has no submissions", adapter == nil or count(adapter.Contexts()) == 0)
		check(
			"surface hatch built (Workspace.AdventureEntry)",
			Workspace:FindFirstChild(m.AdventureEntry.FOLDER) ~= nil
		)
		local remotes = 0
		for _, child in ReplicatedStorage:GetChildren() do
			if child.Name == "SpringVaultAdventure" then
				remotes += 1
			end
		end
		check("exactly one SpringVaultAdventure remotes folder", remotes == 1)
	end
	return checks
end

-- 4. Review prerequisites (explicit, per player, in-memory only) ------------------------------

local function pricedShovel(Config: any): string?
	local best: any = nil
	for _, def in Config.Shovels do
		if def.Price > 0 and (best == nil or def.Price < best.Price) then
			best = def
		end
	end
	return best and best.Id
end

local function notify(player: Player, text: string)
	pcall(state.Modules.Net.Notify, player, "Info", text)
end

-- Seeds cert_rookie and a priced owned shovel into the player's LOADED in-memory save, only where
-- the real rules say the player lacks them. Returns (ok, detail).
function ReviewBoot.SeedPrerequisites(player: Player): (boolean, string)
	local report = state.Report
	if not report or not report.Started then
		return false, "review is not running"
	end
	local m = state.Modules
	if not m.DataService.IsMock() then
		return false, "refused: saves are not in-memory"
	end
	if typeof(player) ~= "Instance" or not player:IsA("Player") or not m.DataService.IsLoaded(player) then
		return false, "refused: player save not loaded yet"
	end
	local Rules = m.Eligibility.Rules
	local data = m.DataService.Get(player) :: any
	local seeded: { string } = {}
	local needEnter = not (Rules.CanEnter(data))
	local needTrial = not (Rules.CanTrial(data))
	local shovel = if needTrial then pricedShovel(m.Config) else nil
	m.DataService.Mutate(player, { "Certifications", "OwnedShovels" }, function(d: any)
		if needEnter then
			d.Certifications = if type(d.Certifications) == "table" then d.Certifications else {}
			d.Certifications.cert_rookie = {
				At = os.time(),
				Source = ReviewBoot.PREREQ_SOURCE,
				ReceiptId = "review:prerequisite",
				Review = true,
			}
			table.insert(seeded, "cert_rookie")
		end
		if shovel then
			d.OwnedShovels[shovel] = true
			table.insert(seeded, "shovel:" .. shovel)
		end
	end)
	local label = if #seeded > 0 then table.concat(seeded, ",") else "none-needed"
	-- Keeps an earlier seed's label: the record stays review-seeded even when nothing new is added.
	if #seeded > 0 or player:GetAttribute(ReviewBoot.PREREQ_ATTRIBUTE) == nil then
		player:SetAttribute(ReviewBoot.PREREQ_ATTRIBUTE, label)
	end
	print(
		string.format(
			"%s REVIEW PREREQUISITE (in-memory save only; not production eligibility): %s (%d) <- %s",
			TAG,
			player.Name,
			player.UserId,
			label
		)
	)
	notify(player, "Review prerequisite (in-memory only): " .. label)
	return true, label
end

function ReviewBoot.Status(): { any }
	local m = state.Modules
	local rows = {}
	if not m then
		return rows
	end
	for _, player in Players:GetPlayers() do
		local data = m.DataService.Get(player)
		local row = {
			Name = player.Name,
			UserId = player.UserId,
			Loaded = m.DataService.IsLoaded(player),
			CanEnter = m.Eligibility.CanEnter(player),
			CanTrial = m.Eligibility.CanTrial(player),
			BroadwaveLicense = m.Eligibility.Rules.HasBroadwaveLicense(data),
			ReviewPrerequisite = player:GetAttribute(ReviewBoot.PREREQ_ATTRIBUTE) or "off",
		}
		table.insert(rows, row)
		print(
			string.format(
				"%s status %s: loaded=%s CanEnter=%s CanTrial=%s license=%s ReviewPrerequisite=%s inMemory=%s",
				TAG,
				row.Name,
				tostring(row.Loaded),
				tostring(row.CanEnter),
				tostring(row.CanTrial),
				tostring(row.BroadwaveLicense),
				tostring(row.ReviewPrerequisite),
				tostring(m.DataService.IsMock())
			)
		)
	end
	local runtime = m.AdventureBoot.Runtime()
	local adapter = runtime and runtime.ReviewAdapter
	print(
		string.format(
			"%s runtime=%s CodexReviewAdapterSubmissions=%d (must stay 0: completion goes to production OnCompletion)",
			TAG,
			tostring(runtime ~= nil),
			if adapter then count(adapter.Contexts()) else 0
		)
	)
	return rows
end

-- Review helper: stand beside the hatch. Moves the character only; grants nothing.
function ReviewBoot.MoveToHatch(player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end
	character:PivotTo(state.Modules.AdventureEntry.SURFACE_RETURN)
	print(TAG .. " [review helper] moved " .. player.Name .. " beside the surface hatch (no progress granted)")
	return true
end

local function resolvePlayer(who: any): Player?
	if typeof(who) == "Instance" and who:IsA("Player") then
		return who
	end
	if type(who) == "number" then
		return Players:GetPlayerByUserId(who)
	end
	if type(who) == "string" then
		local found = Players:FindFirstChild(who)
		return if found and found:IsA("Player") then found else nil
	end
	return Players:GetPlayers()[1]
end

-- ProductionReviewProbe:Invoke(command, player?) from the Studio command bar (server context).
function ReviewBoot.Command(command: string, who: any?): any
	if command == "Report" then
		return state.Report
	end
	if command == "Status" then
		return ReviewBoot.Status()
	end
	local player = resolvePlayer(who)
	if not player then
		return "no such player"
	end
	if command == "Seed" then
		local ok, detail = ReviewBoot.SeedPrerequisites(player)
		return (if ok then "seeded: " else "") .. detail
	end
	if command == "Hatch" then
		return ReviewBoot.MoveToHatch(player)
	end
	return "unknown command (Report, Status, Seed, Hatch)"
end

local function installHelpers(marker: Instance)
	local probe = Instance.new("BindableFunction")
	probe.Name = "ProductionReviewProbe"
	probe.OnInvoke = ReviewBoot.Command
	probe.Parent = marker

	local folder = Instance.new("Folder")
	folder.Name = "ProductionReviewCommands"
	local handlers: { [string]: (Player) -> () } = {
		["/reviewseed"] = function(player)
			local _, detail = ReviewBoot.SeedPrerequisites(player)
			if detail ~= "" then
				print(TAG .. " /reviewseed " .. player.Name .. ": " .. detail)
			end
		end,
		["/reviewstatus"] = function(_player)
			ReviewBoot.Status()
		end,
		["/reviewhatch"] = function(player)
			ReviewBoot.MoveToHatch(player)
		end,
	}
	for _, name in ReviewBoot.COMMANDS do
		local command = Instance.new("TextChatCommand")
		command.Name = name
		command.PrimaryAlias = name
		command.Parent = folder
		command.Triggered:Connect(function(source: TextSource, _text: string)
			local player = Players:GetPlayerByUserId(source.UserId)
			if player then
				task.spawn(handlers[name], player)
			end
		end)
	end
	folder.Parent = TextChatService

	-- The Expansion1Review place's own review SpawnLocation sits at the origin far below the
	-- production map; never spawn players there (production spawns are untouched).
	local visual = Workspace:FindFirstChild("Expansion1Review")
	if visual then
		for _, d in visual:GetDescendants() do
			if d:IsA("SpawnLocation") then
				d.Enabled = false
				print(TAG .. " [review helper] disabled Expansion1Review spawn " .. d:GetFullName())
			end
		end
	end

	local function joined(player: Player)
		print(
			TAG
				.. " "
				.. player.Name
				.. " joined: review prerequisite OFF (real eligibility applies; /reviewseed to seed in-memory)"
		)
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		joined(player)
	end
end

-- 2. Run ---------------------------------------------------------------------------------------

export type RunOptions = {
	Marker: Instance,
	Server: Instance?,
	-- Starts production Main. Default: Main.Enabled = true (the real engine runs it).
	StartMain: ((Script) -> ())?,
}

function ReviewBoot.Run(opts: RunOptions): any
	local ok, why = ReviewBoot.Gate(opts.Marker, opts.Server)
	if not ok then
		local refusal = { Started = false, Reason = why }
		if state.Report and state.Report.Started then
			-- A second boot attempt never touches the review already running.
			warn(TAG .. " REFUSED a second review boot: " .. why)
			return refusal
		end
		warn(TAG .. " REFUSED: " .. why .. ". Nothing was started (production Main stays disabled).")
		setStatus("refused: " .. why)
		state.Report = refusal
		return refusal
	end
	local server = opts.Server :: Instance
	local services = server:FindFirstChild("Services") :: Instance
	print(TAG .. " " .. ReviewBoot.BANNER)
	setStatus("booting")

	local Flags = (require :: any)(services:FindFirstChild("AdventureFlags"))
	local flagText = {}
	for _, name in ReviewBoot.FLAGS do
		Flags[name] = opts.Marker:GetAttribute("Flag_" .. name) ~= false
		table.insert(flagText, name .. "=" .. tostring(Flags[name]))
	end
	print(TAG .. " review-only AdventureFlags (shipped source stays all false): " .. table.concat(flagText, " "))

	local main = server:FindFirstChild("Main") :: Script
	if opts.StartMain then
		opts.StartMain(main)
	else
		main.Enabled = true
	end

	local deadline = ReviewBoot.BOOT_TIMEOUT * 10
	local Boot: any = nil
	for _ = 1, deadline do
		if (shared :: any).DigToTheCoreServer then
			Boot = Boot or (require :: any)(services:FindFirstChild("AdventureBoot"))
			if not Flags.SpringVault or Boot.Runtime() ~= nil then
				break
			end
		end
		task.wait(0.1)
	end
	local function load(name: string): any
		return (require :: any)(services:FindFirstChild(name))
	end
	state.Server = server
	state.Modules = {
		Flags = Flags,
		AdventureBoot = load("AdventureBoot"),
		Eligibility = load("AdventureEligibility"),
		AdventureEntry = load("AdventureEntry"),
		AdventureSettlement = load("AdventureSettlement"),
		BroadwaveLicense = load("BroadwaveLicense"),
		DataService = load("DataService"),
		Net = load("Net"),
		Config = (require :: any)((ReplicatedStorage :: any).Shared.Config),
	}
	local m = state.Modules

	if not m.DataService.IsMock() then
		warn(TAG .. " FAILED: DataService is not using its in-memory store. Adventure disabled; kicking players.")
		pcall(m.AdventureBoot.Disable)
		local function kick(player: Player)
			player:Kick("Production-integration review refused: saves would not be in-memory.")
		end
		Players.PlayerAdded:Connect(kick)
		for _, player in Players:GetPlayers() do
			kick(player)
		end
		setStatus("refused: saves not in-memory")
		state.Report = { Started = false, Reason = "saves not in-memory" }
		return state.Report
	end
	print(TAG .. " saves: DataService in-memory store (DataService.IsMock() == true); no DataStore is written")

	local checks = ReviewBoot.SelfCheck()
	local failed = {}
	for _, c in checks do
		print(string.format("%s self-check %s: %s", TAG, if c.Ok then "PASS" else "FAIL", c.Name))
		if not c.Ok then
			table.insert(failed, c.Name)
		end
	end
	if #failed > 0 then
		warn(
			TAG .. " SELF-CHECK FAILED (" .. table.concat(failed, "; ") .. "). Adventure disabled; not review evidence."
		)
		pcall(m.AdventureBoot.Disable)
		setStatus("self-check failed")
		state.Report = { Started = false, Reason = "self-check failed", Checks = checks }
		return state.Report
	end
	print(
		string.format(
			"%s self-check PASS %d/%d: production AdventureBoot.Options, no resolver shim",
			TAG,
			#checks,
			#checks
		)
	)

	state.Report = { Started = true, Checks = checks, Flags = table.clone(Flags) }
	installHelpers(opts.Marker)
	setStatus("running")
	print(TAG .. " ready. Chat: /reviewseed /reviewstatus /reviewhatch. " .. ReviewBoot.BANNER)
	return state.Report
end

function ReviewBoot.Report(): any
	return state.Report
end

return ReviewBoot
