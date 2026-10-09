--!nocheck
--[[
	Client card for adventure settlement outcomes (src/client/UI/AdventureOutcome.luau) in the
	client-mode mock. Checks the wording is truthful per State (only Accepted reads as saved,
	Pending never does, Refused always says why), replacement of a pending card by its resolved
	follow-up, the on-screen bound, and - when docs/integration/settlement-outcomes.patch is
	applied - the remote wiring. MOCK COVERAGE ONLY.
]]

local Mock = require("./mock/Roblox")
local Generated = require("../build/test/generated")
Mock.Init(Generated, { Client = true })

local failures, passes = 0, 0
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
	return string.find(text, needle, 1, true) ~= nil
end

local byPath = Mock.ByPath
local Remotes = Mock.Require(byPath["ReplicatedStorage/Shared/Remotes"])
local wired = table.find(Remotes.Events, "AdventureOutcome") ~= nil
do
	local net = Mock.Env.Instance.new("Folder")
	net.Name = "Net"
	for _, name in Remotes.Events do
		local r = Mock.Env.Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = net
	end
	net.Parent = byPath["ReplicatedStorage/Shared/Remotes"]
end
Mock.AddLocalPlayer(1001, "Tester")
local UI = "StarterPlayer/StarterPlayerScripts/Client/UI/"
local Root = Mock.Require(byPath[UI .. "Root"])
Root.Init()
local Outcome = Mock.Require(byPath[UI .. "AdventureOutcome"])

local function text(o)
	local d = Outcome.Describe(o)
	return if d then d.Title .. "\n" .. table.concat(d.Lines, "\n") else nil
end
local function final(fields)
	local o = {
		InstanceId = "guid:1",
		Kind = "Final",
		State = "Accepted",
		Status = "Saved",
		Coins = 42,
		Trophy = true,
		Stand = true,
		Certification = "cert_crew",
	}
	for k, v in fields or {} do
		o[k] = v
	end
	return o
end

-- Wording -------------------------------------------------------------------------------------
local accepted = text(final())
check(
	has(accepted, "SAVED")
		and has(accepted, "+42 Coins")
		and has(accepted, "Spring Vault trophy")
		and has(accepted, "Mara's trophy stand")
		and has(accepted, "Crew certification"),
	"accepted final lists everything"
)
local stage = text({
	InstanceId = "guid:1",
	Kind = "Stage",
	StageId = "excavation",
	State = "Accepted",
	Status = "Saved",
	Coins = 6,
})
check(has(stage, "+6 Coins for clearing the vault anchors"), "stage reward names the stage")
local pending = text(final({ State = "Pending", Status = "Unconfirmed" }))
check(has(pending, "SAVING") and has(pending, "not saved yet"), "unconfirmed says it is not saved yet")
check(not has(pending, "SAVED") and not has(pending, "trophy"), "pending never reads as saved or earned")
local rejoin = text(final({
	State = "Pending",
	Status = "PendingRejoin",
	Coins = 0,
	Trophy = false,
	Stand = false,
	Certification = false,
}))
check(has(rejoin, "next time you join"), "pending rejoin explains when")
check(not has(rejoin, "SAVED") and has(rejoin, "Not added yet"), "pending rejoin is queued, never worded as saved")

-- Truth table sweep: whatever the payload carries, a Pending or Refused card never reads as a
-- grant (no "SAVED", no unlock line, no bare "+N Coins", no reward sound), and an "Accepted"
-- payload whose Status is not durable (Saved / Queued / Duplicate) is worded as Pending.
local GRANT_WORDS = { "SAVED", "REWARDS FROM", "Spring Vault trophy", "Mara's trophy stand", "Crew certification" }
local function readsAsGrant(t)
	for _, word in GRANT_WORDS do
		if has(t, word) then
			return true
		end
	end
	for amount in string.gmatch(t, "%+%d+ Coins[^\n]*") do
		if not has(amount, "not saved yet") then
			return true
		end
	end
	return false
end
local sweep = {
	{ State = "Pending", Status = "Unconfirmed" },
	{ State = "Pending", Status = "PendingRejoin" },
	{ State = "Pending", Status = "Applied" },
	{ State = "Pending", Status = "Unconfirmed", Reason = "TrophyPendingWriteFailed" },
	{ State = "Refused", Status = "Ineligible", Reason = "NoContribution" },
	{ State = "Refused", Status = "Ineligible", Reason = "Disconnected" },
	{ State = "Refused", Status = "Refused", Reason = "PendingFull" },
	{ State = "Refused", Status = "Refused", Reason = "SettlementError" },
	-- defensive: "Accepted" with a status the server never maps to Accepted
	{ State = "Accepted", Status = "Applied" },
	{ State = "Accepted", Status = "Unconfirmed" },
	{ State = "Accepted", Status = "PendingRejoin" },
	{ State = "Accepted", Status = "" },
}
for _, case in sweep do
	for _, kind in { "Final", "Stage" } do
		for _, resolved in { false, true } do
			local o = final({
				Kind = kind,
				StageId = if kind == "Stage" then "vault_open" else nil,
				State = case.State,
				Status = case.Status,
				Reason = case.Reason,
				Resolved = resolved or nil,
			})
			local d = Outcome.Describe(o)
			local label =
				string.format("%s/%s %s%s", case.State, case.Status, kind, if resolved then " resolved" else "")
			check(d ~= nil and d.State ~= "Accepted", label .. ": not presented as Accepted")
			local t = text(o) or ""
			check(not readsAsGrant(t), label .. ": never reads as a grant (" .. string.gsub(t, "\n", " | ") .. ")")
		end
	end
end
for _, status in { "Saved", "Queued" } do
	local t = text(final({ Status = status }))
	check(has(t, "SAVED") and has(t, "Spring Vault trophy"), "Accepted/" .. status .. " (durable) reads as saved")
end
local low = text(final({ State = "Refused", Status = "Ineligible", Reason = "LowContribution", Coins = 0 }))
check(has(low, "No reward") and has(low, "didn't contribute"), "ineligible watcher told why")
local veto = text(final({ State = "Refused", Status = "Ineligible", Reason = "EventIneligible", Coins = 0 }))
check(has(veto, "No reward") and not has(veto, "+"), "runtime veto told, no coins")
local disc = text({
	InstanceId = "guid:1",
	Kind = "Stage",
	StageId = "vault_open",
	State = "Refused",
	Status = "Ineligible",
	Reason = "Disconnected",
	Coins = 0,
})
check(has(disc, "disconnected"), "disconnected told")
local stored = text(final({ State = "Refused", Status = "Refused", Reason = "PendingWriteFailed", Coins = 0 }))
check(has(stored, "couldn't be stored"), "storage refusal told")
local unknown = text(final({ State = "Refused", Status = "Ineligible", Reason = "Whatever", Coins = 0 }))
check(has(unknown, "No reward"), "unknown reason still says no reward")
local dup = text(final({ Status = "Duplicate", Coins = 0, Trophy = false, Stand = false, Certification = false }))
check(has(dup, "ALREADY COLLECTED"), "duplicate is not a new reward")
local noTrophy = text(final({ Coins = 60, Trophy = false, Stand = false, Reason = "TrophyUnavailable" }))
check(
	has(noTrophy, "+60 Coins") and has(noTrophy, "no trophy") and not has(noTrophy, "Spring Vault trophy"),
	"missing trophy said"
)
local resolved = text(final({ Resolved = true, Coins = 60 }))
check(has(resolved, "LAST ADVENTURE"), "resolved follow-up titled")
check(Outcome.Describe(nil) == nil, "nil rejected")
check(Outcome.Describe(final({ State = "Granted" })) == nil, "unknown state rejected")
check(Outcome.Describe(final({ Kind = "Bonus" })) == nil, "unknown kind rejected")

-- Cards -----------------------------------------------------------------------------------------
Outcome.Show(final({ State = "Pending", Status = "Unconfirmed" }))
Mock.Advance(0.5)
check(Outcome.VisibleCount() == 1, "one card")
Outcome.Show(final({ Resolved = true, Coins = 42 }))
Mock.Advance(0.5)
check(Outcome.VisibleCount() == 1 and has(Outcome.LastText, "LAST ADVENTURE"), "resolved replaces the pending card")
Outcome.Show(final({ InstanceId = "guid:2" }))
Outcome.Show(final({ InstanceId = "guid:3" }))
Mock.Advance(0.5)
check(Outcome.VisibleCount() == 2, "at most two cards on screen")
Mock.Advance(30)
check(Outcome.VisibleCount() == 0, "cards expire (queued one shown, then gone)")
Outcome.Show({ State = "Accepted" })
check(Outcome.VisibleCount() == 0, "malformed payload shows nothing")

-- Remote wiring ---------------------------------------------------------------------------------
if wired then
	Outcome.Init()
	Mock.Advance(0.5)
	Mock.FireClientEvent("AdventureOutcome", final({ InstanceId = "guid:9", Coins = 54 }))
	Mock.Advance(0.5)
	check(has(Outcome.LastText, "+54 Coins"), "remote outcome shown")
else
	print("(settlement-outcomes patch not applied: remote wiring not exercised)")
end

check(#Mock.Errors == 0, "no uncaught errors (" .. #Mock.Errors .. ")")
for _, e in Mock.Errors do
	print("  error: " .. tostring(e))
end
print(string.format("ADVENTURE OUTCOME CLIENT: %d passed, %d failed", passes, failures))
if failures > 0 then
	error("ADVENTURE OUTCOME CLIENT SPEC FAILED")
end
