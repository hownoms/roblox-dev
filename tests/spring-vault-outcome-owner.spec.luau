--!nocheck
-- Actual runtime under headless API-aware mocks. Completion state is driven explicitly:
-- this checks delivery/ownership boundaries, not gameplay input acceptance or persistence.
local Mock = require("./mock/Roblox")
local Generated = require("../build/test/generated")
Mock.Init(Generated)
local Service = Mock.Require(Mock.ByPath["ServerScriptService/Server/Adventure/SpringVaultService"])
local passed = 0
local function check(value, message)
	assert(value, message)
	passed += 1
end
local function player(id)
	local p = Mock.AddPlayer(id, "Outcome" .. id)
	p:LoadCharacter()
	return p
end
local member, refused, bystander = player(9601), player(9602), player(9603)
local function deliveries(p)
	local result = {}
	for _, delivery in Mock.Remote.ToClient do
		if delivery.Player == p and delivery.Name == "Snapshot" then
			table.insert(result, delivery.Args[1])
		end
	end
	return result
end
for _, mode in { "external", "refused", "implicit", "error", "review" } do
	local calls = 0
	local options = {
		CanEnter = function()
			return true
		end,
		ReviewSpawn = mode == "review",
	}
	if mode ~= "review" then
		if mode ~= "implicit" then
			options.OutcomeOwner = "External"
		end
		options.OnCompletion = function(context)
			calls += 1
			check(#context.Participants == 2, "completion retains eligible and refused participants")
			if mode == "error" then
				error("mock handoff failure")
			end
			return mode ~= "refused", "EVERYONE GOT PERMANENT REWARDS"
		end
	end
	local runtime = Service.Start(options)
	for _, p in { member, refused } do
		p.Character:PivotTo(Mock.CFrame.new(runtime.Scene.Targets.npc_mara))
		runtime.Handle(p, { action = "Join" })
	end
	local event = runtime.Event()
	-- A non-contributing participant remains in the context and needs a truthful result.
	event.Participants[refused.UserId].Points = 0
	event.Stage, event.Phase, event.CompletedAt = "complete", "Resolving", Mock.Now()
	Mock.Remote.ToClient = {}
	Mock.Advance(0.1)
	local memberMessages, refusedMessages, bystanderMessages = 0, 0, 0
	for _, p in { member, refused, bystander } do
		for _, snapshot in deliveries(p) do
			if snapshot.message then
				check(
					snapshot.message ~= "EVERYONE GOT PERMANENT REWARDS",
					"external callback cannot claim generic grants"
				)
				if p == member then
					memberMessages += 1
				elseif p == refused then
					refusedMessages += 1
				else
					bystanderMessages += 1
				end
				if mode == "error" then
					check(string.find(snapshot.message, "handoff failed", 1, true), "failure remains truthful")
				end
			end
			local copy = table.concat(snapshot.objectives or {}, " ")
			if mode == "review" then
				check(string.find(copy, "REVIEW ONLY", 1, true), "dedicated review keeps its no-reward label")
			else
				check(not string.find(copy, "REVIEW ONLY", 1, true), "external production drops review-only objective")
				check(snapshot.outcomeOwner == "External", "snapshot conveys external presentation ownership")
			end
		end
	end
	check(memberMessages > 0, "member receives completion message")
	check(refusedMessages > 0, "non-contributor participant receives completion message")
	check(bystanderMessages == 0, "bystander receives no participant completion message")
	if mode ~= "review" then
		check(calls == 1, "external completion called once")
	end
	Mock.Advance(0.2)
	if mode ~= "review" then
		check(calls == 1, "later heartbeat does not redeliver handoff")
	end
	runtime.Destroy()
end
check(#Mock.Errors == 0, "no asynchronous runtime error")
print("Spring Vault outcome ownership mock: " .. passed .. " checks passed")
