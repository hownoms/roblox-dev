--!strict
-- STUB (coordinator). Map agent replaces the implementation; keep these signatures.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)

local World = {}

function World.Build() end

function World.GetPlots(): { Types.PlotInfo }
	return {}
end

function World.ResetPlot(_id: number) end

return World
