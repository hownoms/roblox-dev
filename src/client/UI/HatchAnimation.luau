--!strict
--[[
	HatchAnimation — EggHatched({petIds}): dim overlay, 1-3 eggs side by side wobble harder and
	harder (EggShake sounds), flash, eggs pop — then the shared Reveal popup (UI/Reveal: huge
	outlined rarity word, card per pet with its spinning model and RARITY / SAND BONUS / DIGS /
	RIDEABLE rows, sparkles, tap to close). Legendary/Mythic add confetti + a big flash. Tap
	skips the wobble; hatches are queued.
	v2.1: Construction Crates (EggDef.Kind == "Crate") don't crack: their lid (sub-Model "Lid" of
	Models.Egg) pops off and flips away before the vehicle springs out. Digging pets show a ⛏ line.
	v2.2: EggHatched's optional second argument { EggId, Chances, Pity } adds a CHANCE row to each
	card: the true chance (luck and pity included) that pet had on the server's roll, e.g. "0.5%"
	or "100% (pity)". EggId picks the right shell even for hatches the panel didn't start.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))

local Root = require(script.Parent.Root)
local Style = require(script.Parent.Components.Style)
local Viewport = require(script.Parent.Components.Viewport)
local Reveal = require(script.Parent.Reveal)
local ItemStats = require(script.Parent.ItemStats)
local UIEffects = require(script.Parent.UIEffects)
local State = require(script.Parent.Parent.Controllers.State)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local ModelFactory = require(script.Parent.Parent.Util.ModelFactory)
local Signal = require(script.Parent.Parent.Util.Signal)

local HatchAnimation = {}

HatchAnimation.Finished = Signal.new() -- (petIds)
HatchAnimation.Hatched = Signal.new() -- (petIds) fired as soon as results arrive

local C = Style.Colors
local pendingEgg: string? = nil
export type HatchInfo = { EggId: string?, Chances: { number }?, Pity: { boolean }? }
type Batch = { Ids: { string }, Info: HatchInfo? }
local queue: { Batch } = {}
local playing = false

-- The egg panel tells us which egg was just requested so we show the right shell.
function HatchAnimation.SetPendingEgg(eggId: string)
	pendingEgg = eggId
end

local function eggFor(petId: string): string
	if pendingEgg then
		return pendingEgg :: string
	end
	for _, egg in Config.Eggs do
		for _, entry in egg.Pets do
			if entry.PetId == petId then
				return egg.Id
			end
		end
	end
	return Config.Eggs[1].Id
end

local function resolvePetId(value: any): string?
	if typeof(value) ~= "string" then
		return nil
	end
	if Config.GetPet(value) then
		return value
	end
	-- tolerate the server sending pet uids instead of ids
	local instance = State.Data.Pets and State.Data.Pets[value]
	if instance then
		return instance.Id
	end
	return nil
end

-- Crate reveal: the lid flies up and tumbles off (runs in its own thread).
local function popLid(view: Viewport.Viewport)
	local model = view.Model
	local lid = if model then model:FindFirstChild("Lid") else nil
	if not lid or not lid:IsA("Model") then
		return
	end
	local lidModel = lid :: Model
	local start = lidModel:GetPivot()
	task.spawn(function()
		local t0 = os.clock()
		while lidModel.Parent do
			local t = math.min((os.clock() - t0) / 0.45, 1)
			local up = 3.2 * t - 1.2 * t * t
			lidModel:PivotTo(start * CFrame.new(0.8 * t, up, 0) * CFrame.Angles(0, 0, -1.6 * t))
			if t >= 1 then
				break
			end
			task.wait(1 / 30)
		end
	end)
end

-- Reveal card for one hatched pet (chance = the true probability the server rolled it with).
local function revealItem(petId: string, chance: number?, pity: boolean?): Reveal.Item
	local def = Config.GetPet(petId)
	local rarity = if def then Config.GetRarity(def.Rarity) else nil
	local color = if rarity then rarity.Color else C.Text
	local rows: { Reveal.Row } = {}
	if def then
		local dig = def.Dig
		table.insert(rows, { Label = "RARITY", Value = def.Rarity :: string, Color = color })
		table.insert(
			rows,
			{ Label = "SAND BONUS", Value = "x" .. string.format("%.2f", def.Multiplier), Color = C.Money }
		)
		table.insert(rows, {
			Label = "DIGS",
			Value = if dig then ItemStats.DigsTo(dig.Power) else "No",
			Color = if dig then C.Time else C.Disabled,
		})
		table.insert(rows, {
			Label = "RIDEABLE",
			Value = if def.Rideable then "YES!" else "No",
			Color = if def.Rideable then C.Gold else C.Disabled,
		})
		if chance then
			table.insert(rows, {
				Label = "CHANCE",
				Value = Format.Chance(chance) .. (if pity then " (pity)" else ""),
				Color = if pity then C.Gold else C.Time,
			})
		end
	end
	return {
		Name = if def then def.Name else petId,
		NameColor = color,
		Model = ModelFactory.Pet(petId),
		Rows = rows,
	}
end

local function play(petIds: { string }, info: HatchInfo?)
	playing = true
	if info and typeof(info.EggId) == "string" and Config.GetEgg(info.EggId :: string) then
		pendingEgg = info.EggId
	end
	local canvas = Root.Get("Popups")
	local overlay = Instance.new("TextButton")
	overlay.Name = "Hatch"
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.Selectable = false
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 30
	overlay.Parent = canvas
	Style.Tween(overlay, 0.25, { BackgroundTransparency = 0.45 })

	local skip = false
	overlay.Activated:Connect(function()
		skip = true
	end)

	local n = #petIds
	local slotWidth = 230
	local slots: { Frame } = {}
	local eggViews: { Viewport.Viewport } = {}
	local eggIds: { string } = {}
	for i, petId in petIds do
		local slot = Instance.new("Frame")
		slot.Name = "Slot" .. i
		slot.BackgroundTransparency = 1
		slot.AnchorPoint = Vector2.new(0.5, 0.5)
		slot.Size = UDim2.fromOffset(slotWidth, 300)
		slot.Position = UDim2.new(0.5, (i - (n + 1) / 2) * (slotWidth + 20), 0.5, 0)
		slot.ZIndex = 31
		slot.Parent = overlay
		local egg = Viewport.new({
			Name = "Egg",
			Size = UDim2.fromOffset(180, 180),
			Position = UDim2.fromScale(0.5, 0.42),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 34,
			Pitch = 8,
			Parent = slot,
		})
		local eggId = eggFor(petId)
		eggIds[i] = eggId
		egg:SetModel(ModelFactory.Egg(eggId))
		Style.PopIn(egg.Frame, 0.4)
		table.insert(slots, slot)
		table.insert(eggViews, egg)
	end
	pendingEgg = nil

	-- wobble, building up
	local wobbles = { 8, 10, 14, 18, 24, 30 }
	for step, angle in wobbles do
		if skip then
			break
		end
		SoundController.Play("EggShake", 0.9 + step * 0.08)
		local t = math.max(0.06, 0.16 - step * 0.015)
		for _, egg in eggViews do
			Style.Tween(egg.Frame, t, { Rotation = angle }, Enum.EasingStyle.Sine)
		end
		task.wait(t)
		for _, egg in eggViews do
			Style.Tween(egg.Frame, t, { Rotation = -angle }, Enum.EasingStyle.Sine)
		end
		task.wait(t)
		if step % 2 == 0 then
			task.wait(0.12)
		end
	end

	-- crack!
	SoundController.Play("Hatch")
	local best = 0
	for _, petId in petIds do
		local def = Config.GetPet(petId)
		local rarity = if def then Config.GetRarity(def.Rarity) else nil
		best = math.max(best, if rarity then rarity.Order else 1)
	end
	UIEffects.Flash(Color3.new(1, 1, 1), if best >= 5 then 0.95 else 0.7)
	for i in petIds do
		local egg = eggViews[i]
		egg.Frame.Rotation = 0
		if Config.IsCrate(eggIds[i]) then
			-- crates open: the lid pops off, then the crate fades
			popLid(egg)
			task.delay(0.25, function()
				Style.Tween(egg.Frame, 0.25, { ImageTransparency = 1 })
			end)
			task.delay(0.5, function()
				egg.Frame.Visible = false
			end)
		else
			Style.Tween(egg.Frame, 0.2, { Size = UDim2.fromOffset(240, 240), ImageTransparency = 1 })
			task.delay(0.2, function()
				egg.Frame.Visible = false
			end)
		end
	end

	-- hand over to the shared Reveal popup (it has its own dim + tap to close)
	task.wait(0.4)
	Style.Tween(overlay, 0.2, { BackgroundTransparency = 1 })
	task.wait(0.2)
	overlay:Destroy()
	local bestRarity: Types.RarityDef? = nil
	local items: { Reveal.Item } = {}
	local chances = if info then info.Chances else nil
	local pities = if info then info.Pity else nil
	for i, petId in petIds do
		local chance = if chances and typeof(chances[i]) == "number" then chances[i] else nil
		local pity = if pities then pities[i] == true else false
		table.insert(items, revealItem(petId, chance, pity))
		local def = Config.GetPet(petId)
		local rarity = if def then Config.GetRarity(def.Rarity) else nil
		if rarity and (not bestRarity or rarity.Order > (bestRarity :: Types.RarityDef).Order) then
			bestRarity = rarity
		end
	end
	local top = bestRarity
	local done = false
	Reveal.Show({
		Headline = if top then string.upper(top.Name) .. "!" else "HATCHED!",
		Color = if top then top.Color else C.Gold,
		Gradient = if top then top.Gradient else nil,
		Caption = if #petIds > 1 then "You hatched " .. #petIds .. " pets!" else nil,
		Items = items,
		Sound = if best >= 5 then "RareTreasure" else "",
		Confetti = best >= 4,
		Hold = 4,
		OnClosed = function()
			done = true
		end,
	})
	while not done do
		task.wait(0.1)
	end
	HatchAnimation.Finished:Fire(petIds)
	playing = false
	local nextBatch = table.remove(queue, 1)
	if nextBatch then
		play(nextBatch.Ids, nextBatch.Info)
	end
end

function HatchAnimation.Play(results: { any }, info: HatchInfo?)
	local ids = {}
	for _, value in results do
		local id = resolvePetId(value)
		if id then
			table.insert(ids, id)
		end
		if #ids >= 5 then
			break
		end
	end
	if #ids == 0 then
		return
	end
	HatchAnimation.Hatched:Fire(ids)
	if playing then
		table.insert(queue, { Ids = ids, Info = info })
	else
		task.spawn(play, ids, info)
	end
end

function HatchAnimation.Init()
	task.spawn(function()
		Remotes.Get("EggHatched").OnClientEvent:Connect(function(results: any, rawInfo: any)
			local info: HatchInfo? = nil
			if typeof(rawInfo) == "table" then
				info = {
					EggId = if typeof(rawInfo.EggId) == "string" then rawInfo.EggId else nil,
					Chances = if typeof(rawInfo.Chances) == "table" then rawInfo.Chances else nil,
					Pity = if typeof(rawInfo.Pity) == "table" then rawInfo.Pity else nil,
				}
			end
			if typeof(results) == "table" then
				-- accept {petIds} or {Pets = {...}}
				local list = if typeof(results.Pets) == "table" then results.Pets else results
				HatchAnimation.Play(list, info)
			elseif typeof(results) == "string" then
				HatchAnimation.Play({ results })
			end
		end)
	end)
end

return HatchAnimation
