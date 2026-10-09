--!strict
--[[
	Trophies.CampAction — the small camp display action shared by the server (TrophyService) and
	the client preview (CampDisplayController). Pure: no services, no yields.

	The action is "put my trophy on the camp pad" / "put it away". The server owns everything:
	it computes the player's camp status, publishes it as read-only Player attributes, and
	places on the first free cell through the normal TrophyService.PlaceTrophy validation. The
	client only uses this module to draw the same cell as a local ghost and to show the same
	words the server would say.

	Status (Player attribute "CampStatus", set by the server only):
		Off        feature disabled: the action is hidden
		NoTrophy   no displayable trophy owned
		NoStand    trophy owned, Mara's trophy stand missing (layout, if any, is kept hidden)
		Ready      may display; nothing on display yet
		Displayed  the camp is on a pad
		Queued     layout saved, every pad busy; "CampQueue" = 1-based place in line
		NoPad      layout saved, this server has no camp pad at all; nothing is shown
	A missing attribute means "not loaded yet": show nothing.
]]

local Catalog = require(script.Parent.Catalog)
local Rules = require(script.Parent.Rules)

local CampAction = {}

CampAction.STATUS_ATTR = "CampStatus"
CampAction.QUEUE_ATTR = "CampQueue"
CampAction.DISPLAY_PROMPT = "CampDisplayPrompt"
CampAction.REMOVE_PROMPT = "CampRemovePrompt"
-- Stands face -Z; Rot 90 turns that to -X, toward the plaza (the pad sign is on the west edge).
CampAction.ROT = 90

export type Status = "Off" | "NoTrophy" | "NoStand" | "Ready" | "Displayed" | "Queued" | "NoPad"

-- Statuses where the remove action applies (the layout holds something).
CampAction.HasLayout = table.freeze({ Displayed = true, Queued = true, NoPad = true }) :: { [string]: boolean }

-- The first owned, displayable trophy not already in the layout (sorted by id), or nil.
function CampAction.NextTrophy(records: { [string]: any }, layout: Rules.CampLayout): string?
	local placed: { [string]: boolean } = {}
	for _, p in layout.Placements do
		placed[p.TrophyId] = true
	end
	local ids: { string } = {}
	for id in records do
		if type(id) == "string" and not placed[id] and Catalog.IsDisplayable(id) then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids[1]
end

-- Cells in the order the action tries them: nearest the pad centre first, ties toward the plaza
-- side (low X), then low Z. Computed once.
local ORDER: { { number } } = {}
do
	local mid = (Rules.CELLS - 1) / 2
	for x = 0, Rules.CELLS - 1 do
		for z = 0, Rules.CELLS - 1 do
			table.insert(ORDER, { x, z, (x - mid) ^ 2 + (z - mid) ^ 2 })
		end
	end
	table.sort(ORDER, function(a, b)
		if a[3] ~= b[3] then
			return a[3] < b[3]
		end
		if a[1] ~= b[1] then
			return a[1] < b[1]
		end
		return a[2] < b[2]
	end)
end

-- First cell no placement uses, or nil when the pad grid is full.
function CampAction.FirstFreeCell(layout: Rules.CampLayout): (number?, number?)
	local used: { [number]: boolean } = {}
	for _, p in layout.Placements do
		used[p.X * Rules.CELLS + p.Z] = true
	end
	for _, cell in ORDER do
		if not used[cell[1] * Rules.CELLS + cell[2]] then
			return cell[1], cell[2]
		end
	end
	return nil, nil
end

-- The placement request the action sends to TrophyService.PlaceTrophy, or nil + reason.
function CampAction.Request(records: { [string]: any }, layout: Rules.CampLayout): ({ [string]: any }?, string?)
	local trophyId = CampAction.NextTrophy(records, layout)
	if not trophyId then
		return nil, "NoTrophy"
	end
	local x, z = CampAction.FirstFreeCell(layout)
	if not x then
		return nil, "LayoutFull"
	end
	return { TrophyId = trophyId, X = x, Z = z, Rot = CampAction.ROT }, nil
end

-- Bottom-centre CFrame of a placement on a pad whose top-centre is `pad` (same math as
-- TrophyCampDisplay.PlacementCFrame, so the preview lands exactly where the display will).
function CampAction.CellCFrame(pad: CFrame, x: number, z: number, rot: number): CFrame
	local ox, oz = Rules.CellOffset(x, z)
	return pad * CFrame.new(ox, 0, oz) * CFrame.Angles(0, math.rad(rot), 0)
end

-- Player-facing words for a status. `busyBy` = display name of whoever holds the pad when it
-- is not this player's (client card only).
function CampAction.Text(status: string?, queue: number?, busyBy: string?): string
	if status == "NoTrophy" then
		return "Finish the Spring Vault to earn a trophy."
	elseif status == "NoStand" then
		return "You need Mara's trophy stand first."
	elseif status == "Ready" then
		if busyBy and busyBy ~= "" then
			return busyBy .. "'s camp is up. Display yours and you'll be next in line."
		end
		return "Your Spring Vault trophy can go here."
	elseif status == "Displayed" then
		return "Your trophy is on display."
	elseif status == "Queued" then
		if queue and queue > 0 then
			return "Camp pad busy. Your display is saved; you're #" .. queue .. " in line."
		end
		return "Camp pad busy. Your display is saved; you're in line."
	elseif status == "NoPad" then
		return "Saved to your camp, but this server has no camp pad, so nothing is shown."
	end
	return ""
end

-- Toast after the action ran on the server.
function CampAction.ResultText(placed: boolean, status: string?, queue: number?): string
	if not placed then
		return "Trophy put away. You still own it."
	elseif status == "Displayed" then
		return "Trophy on display!"
	end
	return CampAction.Text(status, queue)
end

return table.freeze(CampAction)
