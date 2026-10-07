--!strict
-- ItemStats — short stat strings shared by the shop upgrade rows and the Reveal popup
-- ("Dig 4x4", "Holds 120", "Digs Pirate Cove"). Keep the numbers in sync with the server:
-- dig cube edge = Radius * 2 rounded to whole 4-stud voxels (DigService), min one voxel.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))

local ItemStats = {}

local VOXEL = 4

-- Edge (studs) of the cube one dig removes.
function ItemStats.DigEdge(radius: number): number
	return math.max(1, math.floor(radius * 2 / VOXEL + 0.5)) * VOXEL
end

function ItemStats.DigSize(radius: number): string
	local edge = ItemStats.DigEdge(radius)
	return edge .. "×" .. edge
end

-- Deepest layer name a dig power reaches.
function ItemStats.DigsTo(power: number): string
	return Config.Layers[Config.GetMaxLayerIndexForPower(power)].Name
end

function ItemStats.Rate(shovel: Types.ShovelDef): string
	return string.format("%.1f/s", 1 / shovel.Cooldown)
end

-- 1-based position of a shovel in the price ladder (Config.Shovels), 1 when unknown.
function ItemStats.ShovelTier(id: string?): number
	for i, def in Config.Shovels do
		if def.Id == id then
			return i
		end
	end
	return 1
end

--[[
	How "heavy" a shovel feels, 1 (starter) .. 2: scales the dig burst, flying chunks, shake,
	the scooped sand clump and the dig sound, so every upgrade is visible and audible even when
	its dig cube stays the same size (Hand Spade and Garden Trowel both dig 4x4).
]]
function ItemStats.Heft(id: string?): number
	return math.min(2, 1 + 0.2 * (ItemStats.ShovelTier(id) - 1))
end

-- One line saying what a new shovel improves over the old one ("+50% SAND · NOW DIGS SHELL BED").
function ItemStats.UpgradeSummary(old: Types.ShovelDef?, new: Types.ShovelDef): string?
	if not old then
		return nil
	end
	local parts = {}
	local newLayer = Config.GetMaxLayerIndexForPower(new.Power)
	if newLayer > Config.GetMaxLayerIndexForPower(old.Power) then
		table.insert(parts, "NOW DIGS " .. string.upper(Config.Layers[newLayer].Name))
	end
	if new.SandMultiplier > old.SandMultiplier then
		table.insert(parts, "+" .. math.floor((new.SandMultiplier / old.SandMultiplier - 1) * 100 + 0.5) .. "% SAND")
	end
	if ItemStats.DigEdge(new.Radius) > ItemStats.DigEdge(old.Radius) then
		table.insert(parts, "BIGGER DIGS")
	end
	if new.Cooldown < old.Cooldown * 0.97 then
		table.insert(parts, "+" .. math.floor((old.Cooldown / new.Cooldown - 1) * 100 + 0.5) .. "% SPEED")
	end
	return if #parts > 0 then table.concat(parts, " · ") else nil
end

function ItemStats.SandMult(multiplier: number): string
	-- Currency formatting floors small numbers, which hides fractional shovel upgrades.
	return "x" .. (if multiplier < 1000 then tostring(multiplier) else Format.Abbreviate(multiplier))
end

return ItemStats
