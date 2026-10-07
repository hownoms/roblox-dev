--!strict
--[[
	LaunchCheck — lists what still needs the owner's Creator Hub ids or assets before launch
	(docs/LAUNCH.md). Pure read of Config, so tools/preflight.sh prints the same report.

	Blocking: things that would be wrong in a live server (a Studio-only switch left on).
	Missing:  placeholders the game tolerates (id 0 = hidden/skipped, "" = silent), listed so
	          nothing is forgotten.
	Live servers warn once at boot with a one-line summary (visible in the Developer Console);
	Studio prints it as info. Nothing here changes gameplay.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local IconAtlas = require(ReplicatedStorage.Shared.Config.IconAtlas) :: any
local MonetizationService = require(script.Parent.MonetizationService)

local LaunchCheck = {}

export type Report = { Blocking: { string }, Missing: { string } }

local function sortedKeys(t: { [string]: any }): { string }
	local keys = {}
	for key in t do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

function LaunchCheck.Report(): Report
	local blocking: { string } = {}
	local missing: { string } = {}

	if MonetizationService.STUDIO_GRANT_ALL_PASSES then
		table.insert(blocking, "MonetizationService.STUDIO_GRANT_ALL_PASSES is true (set it back to false)")
	end

	local monetization = Config.Monetization :: any
	for _, group in { "GamePasses", "Products" } do
		local unset = {}
		for _, key in sortedKeys(monetization[group]) do
			if monetization[group][key].Id == 0 then
				table.insert(unset, key)
			end
		end
		if #unset > 0 then
			table.insert(missing, ("%s ids (%d): %s"):format(group, #unset, table.concat(unset, ", ")))
		end
	end

	local badges = {}
	for _, badge in Config.Badges do
		if badge.Id == 0 then
			table.insert(badges, badge.Key)
		end
	end
	if #badges > 0 then
		table.insert(missing, ("Badge ids (%d): %s"):format(#badges, table.concat(badges, ", ")))
	end

	if Config.GROUP_ID == 0 then
		local groupCodes = {}
		for _, code in Config.Codes do
			if code.Enabled and code.GroupOnly then
				table.insert(groupCodes, code.Code)
			end
		end
		table.insert(
			missing,
			"GROUP_ID (group sand bonus off"
				.. (if #groupCodes > 0 then "; group-only codes unusable: " .. table.concat(groupCodes, ", ") else "")
				.. ")"
		)
	end

	local sounds = {}
	for _, key in sortedKeys(Config.Sounds :: any) do
		if (Config.Sounds :: any)[key].Id == "" then
			table.insert(sounds, key)
		end
	end
	if #sounds > 0 then
		table.insert(missing, ("Owned audio ids: %s"):format(table.concat(sounds, ", ")))
	end

	if IconAtlas.AssetId == "" then
		table.insert(missing, "IconAtlas.AssetId (UI falls back to emoji icons)")
	end

	return { Blocking = blocking, Missing = missing }
end

function LaunchCheck.Format(report: Report): string
	local lines = {}
	for _, line in report.Blocking do
		table.insert(lines, "BLOCKING  " .. line)
	end
	for _, line in report.Missing do
		table.insert(lines, "missing   " .. line)
	end
	if #lines == 0 then
		return "everything configured"
	end
	return table.concat(lines, "\n")
end

function LaunchCheck.Run()
	local report = LaunchCheck.Report()
	if #report.Blocking == 0 and #report.Missing == 0 then
		return
	end
	if RunService:IsStudio() then
		print("[LaunchCheck] not configured yet (docs/LAUNCH.md):\n" .. LaunchCheck.Format(report))
	else
		warn(
			("[LaunchCheck] %d blocking, %d placeholders not configured (docs/LAUNCH.md): %s"):format(
				#report.Blocking,
				#report.Missing,
				table.concat(report.Blocking, "; ")
			)
		)
	end
end

return LaunchCheck
