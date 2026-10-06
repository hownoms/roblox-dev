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

function ItemStats.SandMult(multiplier: number): string
	return "x" .. Format.Abbreviate(multiplier)
end

return ItemStats
