--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Models = require(Shared:WaitForChild("Models"))

export type Entry = { Category: string, Id: string, Name: string, Build: (string) -> Model }
local entries: { Entry } = {}

local function add(category: string, items: { any }, build: (string) -> Model)
	for _, item in items do
		local id = if type(item) == "string" then item else item.Id
		table.insert(entries, {
			Category = category,
			Id = id,
			Name = if type(item) == "string" then id else item.Name,
			Build = build,
		})
	end
end

add("Tools", Config.Shovels, Models.Shovel)
add("Backpacks", Config.Backpacks, Models.Backpack)
add("Pets", Config.Pets, Models.Pet)
local vehicles, rides = {}, {}
for _, pet in Config.Pets do
	if pet.VehicleKind then
		table.insert(vehicles, pet)
	end
	if pet.Rideable then
		table.insert(rides, pet)
	end
end
add("Vehicles", vehicles, Models.Digger)
add("Rides", rides, Models.RideVehicle)
add("Eggs", Config.Eggs, Models.Egg)
add("Treasures", Config.Treasures, Models.Treasure)
add("Shade", Config.Shades, Models.Shade)
add("Consumables", Config.Consumables, Models.Consumable)
add("Props", Models.ListProps(), Models.Prop)

return entries
