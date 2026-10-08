--!nocheck
-- Isolated DataService boot: injected handle-acquisition failure, fresh process per mode.
local Mock = require("./mock/Roblox")
local Generated = require("../build/test/generated")
local args = { ... }
local studio = table.find(args, "studio") ~= nil
Mock.Init(Generated)
Mock.IsStudio = studio
Mock.DataStoreAcquireFail = true
local DataService = Mock.Require(Mock.ByPath["ServerScriptService/Server/Services/DataService"])
DataService.Init()
local player = Mock.AddPlayer(6021, "AcquireFailure")
DataService.OnPlayerAdded(player)
Mock.Advance(0.5)
assert(#Mock.Errors == 0, "acquisition failure must not cause uncaught errors")
assert(DataService.IsMock() == studio, "in-memory fallback must be Studio only")
assert(next(Mock.DataStores) == nil, "failed handle acquisition creates no persistent store")
if studio then
	assert(DataService.IsLoaded(player), "Studio must retain intentional in-memory testing")
	assert(#Mock.Kicked == 0, "Studio fallback must not kick")
	DataService.Set(player, "Coins", 621)
	DataService.OnPlayerRemoving(player)
	Mock.Advance(0.5)
	local rejoined = Mock.AddPlayer(6021, "AcquireFailure")
	DataService.OnPlayerAdded(rejoined)
	Mock.Advance(0.5)
	assert(DataService.Get(rejoined).Coins == 621, "Studio fallback survives same-process rejoin")
else
	assert(not DataService.IsLoaded(player), "live acquisition failure must not mint default progression")
	assert(DataService.Get(player) == nil, "live failure has no mutable save")
	assert(DataService.SaveAsync(player) == false, "live failure cannot report a successful save")
	assert(#Mock.Kicked == 1 and Mock.Kicked[1].Player == player, "live failure rejects the player")
	assert(Mock.Kicked[1].Message == "We couldn't load your save (Roblox data servers are busy). Please rejoin!", "live rejection explains load failure")
end
local warned = false
for _, warning in Mock.Warnings do
	if string.find(warning, "mock DataStore acquisition failure", 1, true) then
		warned = true
		assert(string.find(warning, if studio then "using in-memory data" else "refusing player loads", 1, true), "warning must identify persistence mode")
	end
end
assert(warned, "acquisition failure must be visible in server logs")
print("PERSISTENCE BOOT " .. (if studio then "Studio" else "live") .. ": PASSED")
