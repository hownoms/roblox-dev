--!strict
--[[
	ShopPanel — Shovels & Backpacks tabs as UPGRADE ROWS (docs/UI_STYLE.md, UpgradeRow):
	  [3D model] name / tag  [ equipped stat ] ➜ [ this item's stat (orange) ]  [ price button ]
	e.g. "Dig 4×4 ➜ Dig 8×8" (+ the deepest layer it digs), "Holds 50 ➜ Holds 120".
	Button states: Equipped (grey) / Equip (blue) / <coins price> (green, affordable) /
	<coins price> (grey, can't afford) / Rebirth N (locked, row dimmed with a lock icon).
	The cheapest useful upgrade gets a "NEXT" tag (also used by the tutorial's shop step and the
	HUD Shop "!" badge via ShopPanel.NextUpgrade). Buying auto-equips the new item once the
	server confirms ownership; a new shovel gets the Reveal popup.
	Open with Panel.Open("Shop", { Tab = "Shovels" | "Backpacks" }).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))

local Components = script.Parent.Parent.Components
local Style = require(Components.Style)
local Panel = require(Components.Panel)
local Button = require(Components.Button)
local UpgradeRow = require(Components.UpgradeRow)
local Icons = require(script.Parent.Parent.Icons)
local ItemStats = require(script.Parent.Parent.ItemStats)
local Reveal = require(script.Parent.Parent.Reveal)
local UIEffects = require(script.Parent.Parent.UIEffects)
local State = require(script.Parent.Parent.Parent.Controllers.State)
local SoundController = require(script.Parent.Parent.Parent.Controllers.SoundController)
local ModelFactory = require(script.Parent.Parent.Parent.Util.ModelFactory)

local ShopPanel = {}

local C = Style.Colors

type Kind = string -- "Shovels" | "Backpacks"

type ItemCard = {
	Id: string,
	Kind: Kind,
	Row: UpgradeRow.UpgradeRow,
	Update: () -> (),
}

local panel: Panel.Panel
local tabs: { [Kind]: Button.Button } = {}
local scrollers: { [Kind]: ScrollingFrame } = {}
local cards: { ItemCard } = {}
local built = false
local currentTab: Kind = "Shovels"
local pendingEquip: { [string]: Kind } = {}
local revealShovel: (id: string, previous: string?) -> ()

local function shovelStat(def: Types.ShovelDef): UpgradeRow.Stat
	return {
		Main = "Dig " .. ItemStats.DigSize(def.Radius),
		Sub = ItemStats.DigsTo(def.Power) .. " · " .. ItemStats.SandMult(def.SandMultiplier) .. " sand",
	}
end

local function capacityOf(def: Types.BackpackDef): number
	local mega = if State.OwnsPass("MegaBackpack") then 2 else 1
	local pockets = Config.RebirthPerks.CapacityFactor(State.Data.RebirthPerks) -- v2.2 Deep Pockets
	return def.Capacity * Config.RebirthMultiplier(State.Data.Rebirths) * mega * pockets
end

local function backpackStat(def: Types.BackpackDef): UpgradeRow.Stat
	return { Main = "Holds " .. Format.Abbreviate(capacityOf(def)), Sub = "sand" }
end

-- Cheapest item (of a kind) that is not owned and not locked: the "next upgrade".
local function nextUpgrade(kind: Kind): string?
	local data = State.Data
	if kind == "Shovels" then
		local equipped = State.GetShovel()
		for _, def in Config.Shovels do
			if
				not data.OwnedShovels[def.Id]
				and def.RebirthsRequired <= data.Rebirths
				and def.Power >= equipped.Power
			then
				return def.Id
			end
		end
	else
		local equipped = State.GetBackpack()
		for _, def in Config.Backpacks do
			if
				not data.OwnedBackpacks[def.Id]
				and def.RebirthsRequired <= data.Rebirths
				and def.Capacity > equipped.Capacity
			then
				return def.Id
			end
		end
	end
	return nil
end

local function makeCard(kind: Kind, id: string, order: number, parent: Instance): ItemCard
	local isShovel = kind == "Shovels"
	local shovel = if isShovel then Config.GetShovel(id) else nil
	local backpack = if not isShovel then Config.GetBackpack(id) else nil
	local name = if shovel then shovel.Name elseif backpack then backpack.Name else id
	local price = if shovel then shovel.Price elseif backpack then backpack.Price else 0
	local rebirths = if shovel then shovel.RebirthsRequired elseif backpack then backpack.RebirthsRequired else 0

	local row = UpgradeRow.new({
		Name = id,
		Title = name,
		LayoutOrder = order,
		Parent = parent,
		-- shovels tilted diagonally so the long tool fills the square; packs from behind-right
		Model = if shovel then ModelFactory.Shovel(id) else ModelFactory.Backpack(id),
		Pitch = if shovel then 10 else 18,
		Yaw = if shovel then 15 else 205,
		Rotation = if shovel then CFrame.Angles(0, 0, math.rad(-50)) else nil,
		OnClick = function()
			local data = State.Data
			local owned = if isShovel then data.OwnedShovels[id] else data.OwnedBackpacks[id]
			if owned then
				Remotes.Get(if isShovel then "EquipShovel" else "EquipBackpack"):FireServer(id)
			else
				pendingEquip[id] = kind
				Remotes.Get(if isShovel then "BuyShovel" else "BuyBackpack"):FireServer(id)
			end
		end,
	})
	local button = row.Button

	return {
		Id = id,
		Kind = kind,
		Row = row,
		Update = function()
			local data = State.Data
			local owned = if isShovel then data.OwnedShovels[id] == true else data.OwnedBackpacks[id] == true
			local equipped = if isShovel then data.Shovel == id else data.Backpack == id
			local current: UpgradeRow.Stat?
			local mine: UpgradeRow.Stat
			if shovel then
				mine = shovelStat(shovel)
				current = if equipped then nil else shovelStat(State.GetShovel())
			elseif backpack then
				mine = backpackStat(backpack)
				current = if equipped then nil else backpackStat(State.GetBackpack())
			else
				mine = { Main = name }
			end
			row:SetStats(current, mine)
			local locked = not owned and data.Rebirths < rebirths
			row:SetLocked(locked)
			if equipped then
				button:SetEnabled(true)
				button:SetColor(C.Disabled)
				button:SetIcon("Check")
				button:SetText("Equipped")
			elseif owned then
				button:SetEnabled(true)
				button:SetColor(C.Ocean)
				button:SetIcon(if isShovel then "shovel" else "Backpack")
				button:SetText("Equip")
			elseif locked then
				button:SetEnabled(false)
				button:SetIcon("Lock")
				button:SetText("Rebirth " .. rebirths)
			else
				button:SetIcon("Coins")
				button:SetText(Format.Abbreviate(price))
				button:SetEnabled(data.Coins >= price)
				button:SetColor(C.Success)
			end
			row.Card:SetHighlight(if equipped then C.Gold else nil)
		end,
	}
end

local function refresh()
	if not built then
		return
	end
	local nextIds = { Shovels = nextUpgrade("Shovels"), Backpacks = nextUpgrade("Backpacks") }
	for _, item in cards do
		item.Update()
		local data = State.Data
		local equipped = if item.Kind == "Shovels" then data.Shovel == item.Id else data.Backpack == item.Id
		if nextIds[item.Kind] == item.Id then
			item.Row:SetTag("NEXT!", C.Coral)
		elseif equipped then
			item.Row:SetTag("EQUIPPED", C.Palm)
		else
			item.Row:SetTag(nil)
		end
	end
end

local function selectTab(kind: Kind)
	currentTab = kind
	for k, button in tabs do
		button:SetColor(if k == kind then C.Sunset else C.NavyCard)
		scrollers[k].Visible = k == kind
	end
end

local function build()
	if built then
		return
	end
	built = true
	local body = panel.Body
	local tabRow = Instance.new("Frame")
	tabRow.Name = "Tabs"
	tabRow.BackgroundTransparency = 1
	tabRow.Size = UDim2.new(1, 0, 0, 58)
	tabRow.ZIndex = 5
	tabRow.Parent = body
	Style.List(tabRow, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left)
	for i, kind in { "Shovels", "Backpacks" } do
		tabs[kind] = Button.new({
			Text = kind,
			Icon = if kind == "Shovels" then "shovel" else "Backpack",
			Size = UDim2.fromOffset(200, 56),
			Color = C.NavyCard,
			LayoutOrder = i,
			ZIndex = 5,
			Parent = tabRow,
			OnClick = function()
				selectTab(kind)
			end,
		})
		local scroller = Panel.Scroller(body, UDim2.new(1, 0, 1, -64), UDim2.fromOffset(0, 64))
		scroller.Name = kind
		Style.List(scroller, Enum.FillDirection.Vertical, 10)
		scrollers[kind] = scroller
		local list = if kind == "Shovels" then Config.Shovels else Config.Backpacks
		for order, def in list :: { any } do
			table.insert(cards, makeCard(kind, def.Id, order, scroller))
		end
	end
	selectTab(currentTab)
	refresh()
end

-- Scroll the active tab so the "next upgrade" card is visible.
local function scrollToNext()
	local id = nextUpgrade(currentTab)
	local scroller = scrollers[currentTab]
	if not id or not scroller then
		return
	end
	for _, item in cards do
		if item.Id == id and item.Kind == currentTab then
			task.defer(function()
				local offset = item.Row.Card.Holder.AbsolutePosition.Y
					- scroller.AbsolutePosition.Y
					+ scroller.CanvasPosition.Y
				scroller.CanvasPosition = Vector2.new(0, math.max(0, offset - 20))
				Style.Pop(item.Row.Card.Holder, 0.08)
			end)
		end
	end
end

-- New shovel: the shared Reveal popup with its dig stats and what it improves over `previous`.
revealShovel = function(id: string, previous: string?)
	local found = Config.GetShovel(id)
	if not found then
		return
	end
	local def = found :: Types.ShovelDef
	Reveal.Show({
		Headline = "NEW SHOVEL!",
		Caption = ItemStats.UpgradeSummary(if previous then Config.GetShovel(previous) else nil, def),
		Color = C.Gold,
		Items = {
			{
				Name = def.Name,
				NameColor = C.Gold,
				Model = ModelFactory.Shovel(id),
				Pitch = 10,
				Yaw = 15,
				Rotation = CFrame.Angles(0, 0, math.rad(-50)),
				Rows = {
					{ Label = "DIG SIZE", Value = ItemStats.DigSize(def.Radius), Color = C.Highlight },
					{ Label = "DIGS", Value = ItemStats.DigsTo(def.Power), Color = C.Time },
					{ Label = "SAND BONUS", Value = ItemStats.SandMult(def.SandMultiplier), Color = C.Money },
					{ Label = "SPEED", Value = ItemStats.Rate(def), Color = C.Time },
				},
			},
		},
		Sound = "",
		Confetti = true,
		Hold = 3.5,
	})
end

function ShopPanel.Init()
	panel = Panel.new({
		Name = "Shop",
		Title = "Shovel Shop",
		Icon = Icons.Shop,
		Color = C.Palm,
		Size = Vector2.new(800, 490),
	})
	panel.Opened:Connect(function(args: any)
		build()
		if typeof(args) == "table" and (args.Tab == "Shovels" or args.Tab == "Backpacks") then
			selectTab(args.Tab)
		end
		refresh()
		scrollToNext()
	end)
	State.ObserveMany(
		{ "Coins", "OwnedShovels", "OwnedBackpacks", "Shovel", "Backpack", "Rebirths", "Passes" },
		refresh
	)
	local function onOwned(kind: Kind)
		return function(owned: any, old: any)
			if typeof(owned) ~= "table" then
				return
			end
			for id, k in pendingEquip do
				if k == kind and owned[id] and not (typeof(old) == "table" and old[id]) then
					pendingEquip[id] = nil
					SoundController.Play("Purchase")
					if kind == "Shovels" then
						-- compare against the best shovel owned before this purchase (the server may
						-- already have auto-equipped the new one)
						local previous: string? = nil
						if typeof(old) == "table" then
							for ownedId in old do
								if
									previous == nil
									or ItemStats.ShovelTier(ownedId) > ItemStats.ShovelTier(previous)
								then
									previous = ownedId
								end
							end
						end
						revealShovel(id, previous)
					else
						UIEffects.Confetti(30)
					end
					local equipped = if kind == "Shovels" then State.Data.Shovel else State.Data.Backpack
					if equipped ~= id then
						Remotes.Get(if kind == "Shovels" then "EquipShovel" else "EquipBackpack"):FireServer(id)
					end
				end
			end
		end
	end
	State.Changed("OwnedShovels"):Connect(onOwned("Shovels"))
	State.Changed("OwnedBackpacks"):Connect(onOwned("Backpacks"))
end

ShopPanel.NextUpgrade = nextUpgrade

return ShopPanel
