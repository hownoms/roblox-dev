--!nocheck
-- Prints the launch checklist report (src/server/Services/LaunchCheck.luau) headlessly.
-- Run with tools/preflight.sh. Exit code 1 when something is blocking (or, with -a strict,
-- when anything at all is still unconfigured).
local Mock = require("./mock/Roblox")
local Generated = require("../build/test/generated")

local ARGS = { ... }
local STRICT = table.find(ARGS, "strict") ~= nil
Mock.Init(Generated)
local LaunchCheck = Mock.Require(Mock.ByPath["ServerScriptService/Server/Services/LaunchCheck"])
local report = LaunchCheck.Report()
print("Launch preflight (docs/LAUNCH.md)")
print(LaunchCheck.Format(report))
print(string.format("\n%d blocking, %d placeholders to fill in", #report.Blocking, #report.Missing))
if #report.Blocking > 0 or (STRICT and #report.Missing > 0) then
	error("PREFLIGHT FAILED", 0)
end
