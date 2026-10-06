--!strict
--[[
	TreasurePopup — TreasureFound(treasureId, rarity) through the shared Reveal popup
	(UI/Reveal): rarity word, card with the spinning treasure (Models.Treasure), RARITY / VALUE /
	FOUND IN rows and a "NEW!" tag on first discovery. Common..Epic finds use the compact,
	non-blocking reveal (keeps digging smooth); Legendary/Mythic get the full popup with a
	flash + confetti. Reveals queue so rapid finds never overlap.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))

local Style = require(script.Parent.Components.Style)
local Reveal = require(script.Parent.Reveal)
local State = require(script.Parent.Parent.Controllers.State)
local ModelFactory = require(script.Parent.Parent.Util.ModelFactory)

local TreasurePopup = {}

type Entry = { Id: string, Rarity: string, IsNew: boolean }

local seen: { [string]: boolean } = {}
local seeded = false

local function seed()
	if seeded or not State.Loaded then
		return
	end
	seeded = true
	for id in State.Data.Index or {} :: { [string]: boolean } do
		seen[id] = true
	end
end

local C = Style.Colors

local function show(entry: Entry)
	local def = Config.GetTreasure(entry.Id)
	local rarity = Config.GetRarity(entry.Rarity) or (if def then Config.GetRarity(def.Rarity) else nil)
	local order = if rarity then rarity.Order else 1
	local color = if rarity then rarity.Color else C.Text
	local rows: { Reveal.Row } = { { Label = "RARITY", Value = entry.Rarity, Color = color } }
	if def then
		table.insert(rows, { Label = "VALUE", Value = Format.Abbreviate(def.SellValue) .. " coins", Color = C.Money })
		local layer = Config.Layers[def.Layer]
		if layer then
			table.insert(rows, { Label = "FOUND IN", Value = layer.Name, Color = C.Time })
		end
	end
	local big = order >= 5
	Reveal.Show({
		Headline = string.upper(entry.Rarity) .. "!",
		Color = color,
		Gradient = if rarity then rarity.Gradient else nil,
		Caption = if entry.IsNew then "NEW TREASURE!" else "TREASURE!",
		Items = {
			{
				Name = if def then def.Name else entry.Id,
				NameColor = color,
				Model = ModelFactory.Treasure(entry.Id),
				Pitch = 20,
				Rows = rows,
				Tag = if entry.IsNew then "NEW!" else nil,
			},
		},
		Compact = not big,
		Hold = if big then 4 elseif entry.IsNew then 3 else 2.2,
		Sound = if big then "RareTreasure" elseif order >= 4 then "RareTreasure" else "Treasure",
		Flash = big,
		Confetti = big,
	})
end

function TreasurePopup.Show(treasureId: string, rarity: string?)
	seed()
	local def = Config.GetTreasure(treasureId)
	local isNew = not seen[treasureId]
	seen[treasureId] = true
	local rarityName: string = rarity or (if def then def.Rarity :: string else "Common")
	show({ Id = treasureId, Rarity = rarityName, IsNew = isNew })
end

function TreasurePopup.Init()
	State.LoadedSignal:Connect(seed)
	task.spawn(function()
		Remotes.Get("TreasureFound").OnClientEvent:Connect(function(treasureId: any, rarity: any)
			if typeof(treasureId) == "string" then
				TreasurePopup.Show(treasureId, if typeof(rarity) == "string" then rarity else nil)
			end
		end)
	end)
end

return TreasurePopup
