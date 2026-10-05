--!strict
-- STUB (coordinator). Survival agent owns this file.
local Types = require(script.Parent.Parent.Types)

local Consumables: { Types.ConsumableDef } = {
	{ Id = "water", Name = "Water Bottle", Price = 0, Cooling = 40, Icon = "💧", Look = {} },
}

return Consumables
