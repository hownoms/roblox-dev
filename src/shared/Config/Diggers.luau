--!strict
-- STUB (coordinator). Diggers agent owns this file. Ordered by price.
local Types = require(script.Parent.Parent.Types)

local Diggers: { Types.DiggerDef } = {
	{
		Id = "toy_truck",
		Name = "Toy Sand Truck",
		Price = 500,
		Power = 1,
		Interval = 3,
		Radius = 2,
		SandMultiplier = 1,
		MaxLevel = 5,
		Look = {},
	},
}

return Diggers
