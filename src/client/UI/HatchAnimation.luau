--!strict
--[[
	HatchAnimation — EggHatched({petIds}) reveal: dim overlay, 1-3 eggs side by side wobble
	harder and harder (EggShake sounds), flash, egg pops, a spinning star-burst in the
	pet's rarity colour, pet springs out (ViewportFrame + Models.Pet) with name, rarity and
	bonus. Legendary/Mythic add confetti + a big flash. Tap to skip; hatches are queued.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Root = require(script.Parent.Root)
local Style = require(script.Parent.Components.Style)
local Viewport = require(script.Parent.Components.Viewport)
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
local queue: { { string } } = {}
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

local function starburst(parent: Instance, color: Color3, z: number): Frame
	local burst = Instance.new("Frame")
	burst.Name = "Burst"
	burst.BackgroundTransparency = 1
	burst.AnchorPoint = Vector2.new(0.5, 0.5)
	burst.Position = UDim2.fromScale(0.5, 0.42)
	burst.Size = UDim2.fromOffset(0, 0)
	burst.ZIndex = z
	burst.Parent = parent
	for i = 0, 7 do
		local ray = Instance.new("Frame")
		ray.Name = "Ray"
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.new(1, 0, 0.12, 0)
		ray.Rotation = i * 22.5
		ray.BackgroundColor3 = color
		ray.BorderSizePixel = 0
		ray.ZIndex = z
		ray.Parent = burst
		local gradient = Instance.new("UIGradient")
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.05),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = ray
	end
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(0.5, 0.5)
	glow.BackgroundColor3 = Style.Lighten(color, 0.4)
	glow.BackgroundTransparency = 0.3
	glow.ZIndex = z
	glow.Parent = burst
	Style.Corner(glow, Style.Theme.CornerPill)
	Style.Tween(burst, 6, { Rotation = 360 }, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
	return burst
end

local function play(petIds: { string })
	playing = true
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
		egg:SetModel(ModelFactory.Egg(eggFor(petId)))
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
	for i, petId in petIds do
		local slot = slots[i]
		local egg = eggViews[i]
		egg.Frame.Rotation = 0
		Style.Tween(egg.Frame, 0.2, { Size = UDim2.fromOffset(240, 240), ImageTransparency = 1 })
		task.delay(0.2, function()
			egg.Frame.Visible = false
		end)

		local def = Config.GetPet(petId)
		local rarity = if def then Config.GetRarity(def.Rarity) else nil
		local color = if rarity then rarity.Color else C.Text
		local burst = starburst(slot, color, 32)
		Style.Tween(burst, 0.5, { Size = UDim2.fromOffset(300, 300) }, Enum.EasingStyle.Back)

		local pet = Viewport.new({
			Name = "Pet",
			Size = UDim2.fromOffset(190, 190),
			Position = UDim2.fromScale(0.5, 0.42),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 35,
			Spin = true,
			SpinSpeed = 1.5,
			Pitch = 12,
			Parent = slot,
		})
		pet:SetModel(ModelFactory.Pet(petId))
		local scale = Style.GetPopScale(pet.Frame)
		scale.Scale = 0
		Style.Tween(scale, 0.7, { Scale = 1 }, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)

		local name = Style.Label({
			Text = if def then def.Name else petId,
			Size = UDim2.new(1, 0, 0, 36),
			Position = UDim2.new(0.5, 0, 1, -64),
			AnchorPoint = Vector2.new(0.5, 0),
			TextColor = color,
			StrokeThickness = 3,
			MaxTextSize = 32,
			ZIndex = 36,
			Parent = slot,
		})
		local info = Style.Label({
			Text = (if def then def.Rarity .. "  ·  x" .. string.format("%.2f", def.Multiplier) .. " sand" else ""),
			Size = UDim2.new(1, 0, 0, 24),
			Position = UDim2.new(0.5, 0, 1, -28),
			AnchorPoint = Vector2.new(0.5, 0),
			Font = Style.Fonts.Body,
			MaxTextSize = 20,
			ZIndex = 36,
			Parent = slot,
		})
		Style.PopIn(name, 0.4)
		Style.PopIn(info, 0.5)
	end
	if best >= 5 then
		SoundController.Play("RareTreasure")
		UIEffects.Confetti(60)
	elseif best >= 4 then
		UIEffects.Confetti(30)
	end

	local start = os.clock()
	skip = false
	while os.clock() - start < 2.6 and not skip do
		task.wait(0.05)
	end
	Style.Tween(overlay, 0.25, { BackgroundTransparency = 1 })
	for _, slot in slots do
		local s = Style.GetPopScale(slot)
		Style.Tween(s, 0.22, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	end
	task.wait(0.25)
	overlay:Destroy()
	HatchAnimation.Finished:Fire(petIds)
	playing = false
	local nextBatch = table.remove(queue, 1)
	if nextBatch then
		play(nextBatch)
	end
end

function HatchAnimation.Play(results: { any })
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
		table.insert(queue, ids)
	else
		task.spawn(play, ids)
	end
end

function HatchAnimation.Init()
	task.spawn(function()
		Remotes.Get("EggHatched").OnClientEvent:Connect(function(results: any)
			if typeof(results) == "table" then
				-- accept {petIds} or {Pets = {...}}
				local list = if typeof(results.Pets) == "table" then results.Pets else results
				HatchAnimation.Play(list)
			elseif typeof(results) == "string" then
				HatchAnimation.Play({ results })
			end
		end)
	end)
end

return HatchAnimation
