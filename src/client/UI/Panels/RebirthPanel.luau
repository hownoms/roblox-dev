--!strict
--[[
	RebirthPanel — two tabs (docs/design/Rebirth.md):
	  Rebirth: multiplier now -> after, tokens gained, cost progress bar, the RECOVERY PREVIEW
	           ("With x1.5 you'll reach Crystal Caverns about 1.5x faster" + what your perks give
	           you at the start of the next run), what resets / what you keep, a Rebirth button
	           with a second-tap confirm, and the Skip Rebirth product.
	  Perks:   one UpgradeRow per Config.RebirthPerks entry: current level -> next level, and a
	           token price button (green affordable / grey not / MAX). Fires BuyRebirthPerk(id).
	Open with Panel.Open("Rebirth", { Tab = "Rebirth" | "Perks" }).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))

local Components = script.Parent.Parent.Components
local Style = require(Components.Style)
local Panel = require(Components.Panel)
local Button = require(Components.Button)
local Card = require(Components.Card)
local ProgressBar = require(Components.ProgressBar)
local UpgradeRow = require(Components.UpgradeRow)
local AtlasIcon = require(Components.AtlasIcon)
local Icons = require(script.Parent.Parent.Icons)
local Banner = require(script.Parent.Parent.Banner)
local State = require(script.Parent.Parent.Parent.Controllers.State)
local PurchaseController = require(script.Parent.Parent.Parent.Controllers.PurchaseController)

local RebirthPerksConfig = require(Shared:WaitForChild("Config"):WaitForChild("RebirthPerks"))
local Perks = Config.RebirthPerks

local RebirthPanel = {}

local C = Style.Colors
local TAB_H = 58

type Tab = string -- "Rebirth" | "Perks"

local panel: Panel.Panel
local built = false
local confirm = false
local currentTab: Tab = "Rebirth"
local tabs: { [Tab]: Button.Button } = {}
local pages: { [Tab]: GuiObject } = {}
local multLabel: TextLabel
local tokensLabel: TextLabel
local recoveryLabel: TextLabel
local perkNoteLabel: TextLabel
local bar: ProgressBar.ProgressBar
local rebirthButton: Button.Button
local skipButton: Button.Button
local walletLabel: TextLabel
local perkRows: { [string]: UpgradeRow.UpgradeRow } = {}

-- Pure helpers (also used by tests) ---------------------------------------------------------------

-- "With x1.5 you'll reach Crystal Caverns about 1.5x faster": income scales with the rebirth
-- multiplier (sand per dig; capacity grows with it too, so trips stay the same length).
function RebirthPanel.RecoveryText(rebirths: number, maxDepth: number): (string, number)
	local now = Config.RebirthMultiplier(rebirths)
	local after = Config.RebirthMultiplier(rebirths + 1)
	local ratio = after / now
	local layer = Config.GetLayerAtDepth(maxDepth)
	return string.format("With x%.1f you'll reach %s about %.1f× faster!", after, layer.Name, ratio), ratio
end

-- What the next run starts with, from the perks owned.
function RebirthPanel.PerkStartText(perks: { [string]: number }?): string
	local parts = {}
	local head = Perks.Effect(perks, "HeadStart")
	if head.ShovelIndex then
		local shovel = Config.Shovels[head.ShovelIndex]
		table.insert(parts, "start with a " .. shovel.Name .. " + " .. Format.Abbreviate(head.Coins or 0) .. " coins")
	end
	local keep = Perks.Effect(perks, "KeepBackpack").KeepIndex
	if keep then
		local last = Config.Backpacks[math.min(keep, #Config.Backpacks)]
		table.insert(
			parts,
			if keep >= #Config.Backpacks then "keep your backpack" else "keep backpacks up to " .. last.Name
		)
	end
	if #parts == 0 then
		return "Spend Rebirth Tokens on Perks to start every run stronger!"
	end
	return "Your perks: " .. table.concat(parts, ", ") .. "."
end

local function pct(factor: number): string
	return "+" .. math.floor((factor - 1) * 100 + 0.5) .. "%"
end

-- The stat box text for a perk at `level` (0 = not bought).
function RebirthPanel.PerkStat(id: string, level: number): UpgradeRow.Stat
	local def = Perks.Get(id)
	local none: RebirthPerksConfig.PerkLevel = {}
	local fx: RebirthPerksConfig.PerkLevel = if def and level > 0 then def.Levels[level] else none
	if id == "SellAnywhere" then
		return if fx.Unlocked
			then { Main = "Sell anywhere", Sub = "one tap" }
			else { Main = "Walk to sell", Sub = "sell stand" }
	elseif id == "HeadStart" then
		local shovel = Config.Shovels[fx.ShovelIndex or 1]
		return { Main = shovel.Name, Sub = "+" .. Format.Abbreviate(fx.Coins or 0) .. " coins" }
	elseif id == "KeepBackpack" then
		local keep = fx.KeepIndex or 0
		if keep <= 0 then
			return { Main = "Keep none", Sub = "back to Bucket" }
		elseif keep >= #Config.Backpacks then
			return { Main = "Keep any", Sub = "every backpack" }
		end
		return { Main = "Keep up to", Sub = Config.Backpacks[keep].Name }
	elseif id == "DeepPockets" then
		return { Main = "Holds " .. pct(fx.Capacity or 1), Sub = "backpack space" }
	elseif id == "LuckyDigger" then
		return { Main = "Treasure " .. pct(fx.TreasureChance or 1), Sub = "find chance" }
	elseif id == "LongNap" then
		local hours = Perks.OFFLINE_CAP_HOURS + (fx.OfflineHours or 0)
		local eff = Perks.OFFLINE_EFFICIENCY + (fx.OfflineEfficiency or 0)
		return { Main = hours .. "h away", Sub = math.floor(eff * 100 + 0.5) .. "% pet digging" }
	elseif id == "PetDen" then
		return { Main = "+" .. (fx.PetSlots or 0) .. " pet slots", Sub = "equip more pets" }
	elseif id == "GoldenTouch" then
		return { Main = "Coins " .. pct(fx.Coin or 1), Sub = "when you sell" }
	end
	return { Main = "Level " .. level }
end

-- Refresh -----------------------------------------------------------------------------------------

local function refreshPerks()
	local data = State.Data
	local tokens = data.RebirthTokens or 0
	walletLabel.Text = "Rebirth Tokens: " .. tokens .. "   ·   Perks last forever!"
	for _, def in Perks.List do
		local row = perkRows[def.Id]
		if row then
			local level = Perks.Level(data.RebirthPerks, def.Id)
			local maxLevel = #def.Costs
			local cost = Perks.NextCost(data.RebirthPerks, def.Id)
			local button = row.Button
			if cost then
				row:SetStats(RebirthPanel.PerkStat(def.Id, level), RebirthPanel.PerkStat(def.Id, level + 1))
				button:SetIcon("Tokens")
				button:SetText(tostring(cost))
				button:SetColor(C.Success)
				button:SetEnabled(tokens >= cost)
				row:SetTag(if maxLevel > 1 then "LV " .. level .. "/" .. maxLevel else nil, C.Purple)
				row.Card:SetHighlight(nil)
			else
				row:SetStats(nil, RebirthPanel.PerkStat(def.Id, level))
				button:SetIcon("Check")
				button:SetText("MAX")
				button:SetColor(C.Disabled)
				button:SetEnabled(false)
				row:SetTag("MAX", C.Gold)
				row.Card:SetHighlight(C.Gold)
			end
		end
	end
end

local function refresh()
	if not built then
		return
	end
	local data = State.Data
	local n = data.Rebirths
	local cost = Config.RebirthCost(n)
	multLabel.Text = string.format("x%.1f  ➜  x%.1f", Config.RebirthMultiplier(n), Config.RebirthMultiplier(n + 1))
	local tokens = Config.RebirthTokens(n)
	tokensLabel.Text =
		string.format("+%d Rebirth Token%s   ·   Rebirths: %d", tokens, if tokens == 1 then "" else "s", n)
	bar:Set(data.Coins / cost, Format.Abbreviate(data.Coins) .. " / " .. Format.Abbreviate(cost) .. " coins")
	bar:SetColor(if data.Coins >= cost then C.Success else C.Gold)
	recoveryLabel.Text = (RebirthPanel.RecoveryText(n, data.MaxDepth or 0))
	perkNoteLabel.Text = RebirthPanel.PerkStartText(data.RebirthPerks)
	local can = data.Coins >= cost
	rebirthButton:SetEnabled(can)
	rebirthButton:SetText(
		if not can
			then "Need " .. Format.Abbreviate(cost - data.Coins) .. " more"
			elseif confirm then "Tap again to REBIRTH!"
			else "Rebirth!"
	)
	skipButton:SetVisible(PurchaseController.IsProductConfigured("SkipRebirth"))
	skipButton:SetText("Skip R$ " .. PurchaseController.GetPrice("Product", "SkipRebirth"))
	refreshPerks()
	local perkBadge = false
	for _, def in Perks.List do
		local nextCost = Perks.NextCost(data.RebirthPerks, def.Id)
		if nextCost and (data.RebirthTokens or 0) >= nextCost then
			perkBadge = true
		end
	end
	tabs.Perks:SetBadge(if perkBadge then "!" else nil)
end

local function selectTab(tab: Tab)
	currentTab = tab
	for name, button in tabs do
		button:SetColor(if name == tab then C.Purple else C.NavyCard)
		pages[name].Visible = name == tab
	end
end

-- Build -------------------------------------------------------------------------------------------

local function listCard(parent: Instance, title: string, lines: string, color: Color3, x: number, y: number)
	local card = Card.new({
		Name = title,
		Size = UDim2.new(0.5, -8, 0, 96),
		Position = UDim2.new(x, if x > 0 then 8 else 0, 0, y),
		Color = Style.Darken(color, 0.35),
		ZIndex = 6,
		Parent = parent,
	})
	Style.Label({
		Text = title,
		Size = UDim2.new(1, -16, 0, 24),
		Position = UDim2.fromOffset(8, 4),
		MaxTextSize = 20,
		ZIndex = 8,
		Parent = card.Face,
	})
	Style.Label({
		Text = lines,
		Size = UDim2.new(1, -16, 1, -34),
		Position = UDim2.fromOffset(8, 30),
		Font = Style.Fonts.Body,
		Wrapped = true,
		MaxTextSize = 15,
		YAlign = Enum.TextYAlignment.Top,
		ZIndex = 8,
		Parent = card.Face,
	})
end

local function buildRebirthPage(page: Frame)
	multLabel = Style.Label({
		Name = "Multiplier",
		Text = "",
		Size = UDim2.new(1, 0, 0, 44),
		TextColor = C.Time,
		StrokeThickness = 3,
		MaxTextSize = 40,
		ZIndex = 6,
		Parent = page,
	})
	tokensLabel = Style.Label({
		Name = "Tokens",
		Text = "",
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 44),
		Font = Style.Fonts.Body,
		StrokeThickness = 2,
		MaxTextSize = 17,
		ZIndex = 6,
		Parent = page,
	})
	bar = ProgressBar.new({
		Size = UDim2.new(1, -40, 0, 30),
		Position = UDim2.new(0.5, 0, 0, 68),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = C.Gold,
		ZIndex = 6,
		Parent = page,
	})
	recoveryLabel = Style.Label({
		Name = "Recovery",
		Text = "",
		Size = UDim2.new(1, -20, 0, 26),
		Position = UDim2.new(0.5, 0, 0, 102),
		AnchorPoint = Vector2.new(0.5, 0),
		TextColor = C.Money,
		StrokeThickness = 2.5,
		MaxTextSize = 22,
		ZIndex = 6,
		Parent = page,
	})
	perkNoteLabel = Style.Label({
		Name = "PerkNote",
		Text = "",
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.new(0.5, 0, 0, 128),
		AnchorPoint = Vector2.new(0.5, 0),
		Font = Style.Fonts.Body,
		TextColor = C.Highlight,
		MaxTextSize = 16,
		ZIndex = 6,
		Parent = page,
	})
	listCard(
		page,
		"Resets",
		"Coins, sand, shovels, backpacks and unsold treasures. Your hole is refilled.",
		C.Coral,
		0,
		154
	)
	listCard(
		page,
		"You keep",
		"Pets, Index, depth record, quests, boosts, tokens, perks — and +"
			.. Config.Rebirths.MultiplierPerRebirth
			.. "x sand & backpack space FOREVER!",
		C.Palm,
		0.5,
		154
	)
	rebirthButton = Button.new({
		Name = "RebirthButton",
		Text = "Rebirth!",
		Icon = Icons.Rebirth,
		Size = UDim2.fromOffset(330, 74),
		Position = UDim2.new(0.5, -90, 1, -4),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = C.Purple,
		MaxTextSize = 24,
		ZIndex = 6,
		Parent = page,
		OnClick = function()
			if not confirm then
				confirm = true
				refresh()
				task.delay(3, function()
					confirm = false
					refresh()
				end)
				return
			end
			confirm = false
			Remotes.Get("Rebirth"):FireServer()
		end,
	})
	skipButton = Button.new({
		Name = "Skip",
		Text = "Skip R$ " .. PurchaseController.GetPrice("Product", "SkipRebirth"),
		Size = UDim2.fromOffset(170, 74),
		Position = UDim2.new(1, -10, 1, -4),
		AnchorPoint = Vector2.new(1, 1),
		Color = C.Robux,
		MaxTextSize = 20,
		ZIndex = 6,
		Parent = page,
		OnClick = function()
			PurchaseController.PromptProduct("SkipRebirth")
		end,
	})
end

local function buildPerksPage(page: Frame)
	walletLabel = Style.Label({
		Name = "Wallet",
		Text = "",
		Size = UDim2.new(1, 0, 0, 26),
		TextColor = C.Tokens,
		StrokeThickness = 2.5,
		MaxTextSize = 22,
		ZIndex = 6,
		Parent = page,
	})
	local scroller = Panel.Scroller(page, UDim2.new(1, 0, 1, -32), UDim2.fromOffset(0, 32))
	scroller.Name = "PerkList"
	Style.List(scroller, Enum.FillDirection.Vertical, 10)
	for order, def in Perks.List do
		local id = def.Id
		local row = UpgradeRow.new({
			Name = id,
			Title = def.Name,
			LayoutOrder = order,
			Parent = scroller,
			StageColors = { C.Purple, Style.Darken(C.Purple, 0.4) },
			ActionWidth = 150,
			OnClick = function()
				Remotes.Get("BuyRebirthPerk"):FireServer(id)
			end,
		})
		local stage = row.Card.Face:FindFirstChild("Preview")
		if stage then
			AtlasIcon.new({
				Name = "PerkIcon",
				Icon = def.Icon,
				Size = UDim2.fromScale(0.78, 0.78),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				ZIndex = 5,
				Parent = stage,
			})
		end
		perkRows[id] = row
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
	tabRow.Size = UDim2.new(1, 0, 0, TAB_H)
	tabRow.ZIndex = 5
	tabRow.Parent = body
	Style.List(tabRow, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left)
	for i, tab in { "Rebirth", "Perks" } do
		tabs[tab] = Button.new({
			Name = tab .. "Tab",
			Text = tab,
			Icon = if tab == "Rebirth" then "Rebirth" else "Tokens",
			Size = UDim2.fromOffset(200, 54),
			Color = C.NavyCard,
			LayoutOrder = i,
			ZIndex = 5,
			Parent = tabRow,
			OnClick = function()
				selectTab(tab)
			end,
		})
		local page = Instance.new("Frame")
		page.Name = tab .. "Page"
		page.BackgroundTransparency = 1
		page.Size = UDim2.new(1, 0, 1, -(TAB_H + 6))
		page.Position = UDim2.fromOffset(0, TAB_H + 6)
		page.ZIndex = 5
		page.Parent = body
		pages[tab] = page
		if tab == "Rebirth" then
			buildRebirthPage(page)
		else
			buildPerksPage(page)
		end
	end
	selectTab(currentTab)
end

function RebirthPanel.Init()
	panel = Panel.new({
		Name = "Rebirth",
		Title = "Rebirth",
		Icon = Icons.Rebirth,
		Color = C.Purple,
		Size = Vector2.new(780, 500),
	})
	panel.Opened:Connect(function(args: any)
		build()
		confirm = false
		if typeof(args) == "table" and (args.Tab == "Rebirth" or args.Tab == "Perks") then
			selectTab(args.Tab)
		end
		refresh()
	end)
	State.ObserveMany({ "Coins", "Rebirths", "RebirthTokens", "RebirthPerks", "MaxDepth" }, refresh)
	State.Changed("Rebirths"):Connect(function(new: any, old: any)
		if typeof(new) == "number" and typeof(old) == "number" and new > old then
			panel:Close()
			Banner.Show({
				Title = "REBIRTH " .. new .. "!",
				Icon = "Rebirth",
				Subtitle = string.format(
					"Everything is now x%.1f — spend your tokens on Perks!",
					Config.RebirthMultiplier(new)
				),
				Tag = "NEW MULTIPLIER",
				Color = C.Purple,
				Sound = "Rebirth",
				Confetti = true,
				Duration = 4,
			})
		end
	end)
	-- a perk level bought: little celebration
	State.Changed("RebirthPerks"):Connect(function(new: any, old: any)
		if typeof(new) ~= "table" or typeof(old) ~= "table" or not panel.IsOpen then
			return
		end
		for id, level in new do
			local row = perkRows[id]
			if row and typeof(level) == "number" and level > Perks.Level(old, id) then
				Style.Pop(row.Card.Holder, 0.08)
			end
		end
	end)
end

-- Tests / other panels.
function RebirthPanel.SelectTab(tab: Tab)
	if built and pages[tab] then
		selectTab(tab)
	end
end

function RebirthPanel.CurrentTab(): Tab
	return currentTab
end

return RebirthPanel
