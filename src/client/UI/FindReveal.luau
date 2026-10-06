--!strict
--[[
	FindReveal (v3 discovery slice) — "rarity you feel": presents a FindRevealed by its Tier
	(Util/Finds.Tier; the world-side beam / rise is DiscoveryController's job, for every player):

	  Pop        Common / Uncommon: float text over the find ("Bottle Cap! +8"), soft sting.
	             The compact (non-blocking) card only the first time you find that item.
	  Beam       Rare, or any Giant / Golden / Fossilized / Crystal variant: coloured beam in
	             the world, distinct sting, compact card.
	  Card       Epic / Legendary: the full Reveal card + a camera moment (shake + FOV punch).
	  Server     Mythic: full card + flash + confetti; the server announces it (UI/Announcements)
	             and the sky beam is visible to everyone for ~12 s.
	  Spectacle  Relic: everything above, bigger.

	The card lists RARITY, SIZE, MATERIAL, QUALITY and VALUE, with NEW! / NEW VARIANT! tags.
	FindReveal.Presentation(info) is the pure tier -> presentation table (tests).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Finds = require(Shared:WaitForChild("Util"):WaitForChild("Finds"))
local Models = require(Shared:WaitForChild("Models"))

local Style = require(script.Parent.Components.Style)
local Reveal = require(script.Parent.Reveal)
local EffectsController = require(script.Parent.Parent.Controllers.EffectsController)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local DiscoveryController = require(script.Parent.Parent.Controllers.DiscoveryController)
local ModelFactory = require(script.Parent.Parent.Util.ModelFactory)

local FindReveal = {}

export type Presentation = {
	Tier: string,
	Float: boolean, -- world float text over the find
	Card: string, -- "None" | "Compact" | "Full"
	Sound: string,
	Camera: boolean, -- shake + FOV punch
	Flash: boolean,
	Confetti: boolean,
}

local C = Style.Colors

function FindReveal.Presentation(info: Types.FindInfo): Presentation
	local tier = if table.find(Finds.TIERS, info.Tier)
		then info.Tier
		else Finds.Tier(info.Rarity, info.Size, info.Material)
	local order = Finds.TierOrder(tier)
	local fresh = info.IsNew or #info.NewVariants > 0
	return {
		Tier = tier,
		Float = true,
		Card = if order >= Finds.TierOrder("Card")
			then "Full"
			elseif order == Finds.TierOrder("Beam") or fresh then "Compact"
			else "None",
		Sound = if order >= Finds.TierOrder("Beam") then "RareTreasure" else "Treasure",
		Camera = order >= Finds.TierOrder("Card"),
		Flash = order >= Finds.TierOrder("Server"),
		Confetti = order >= Finds.TierOrder("Server"),
	}
end

local function cameraMoment(strength: number)
	EffectsController.Shake(0.35 * strength, 0.35)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local fov = camera.FieldOfView
	local punch = TweenService:Create(
		camera,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true),
		{ FieldOfView = fov - 8 * strength }
	)
	punch:Play()
end

local function rows(info: Types.FindInfo, color: Color3): { Reveal.Row }
	local list: { Reveal.Row } = { { Label = "RARITY", Value = info.Rarity, Color = color } }
	local size = Finds.GetSize(info.Size)
	local material = Finds.GetMaterial(info.Material)
	local quality = Finds.GetQuality(info.Quality)
	if size then
		table.insert(list, { Label = "SIZE", Value = info.Size, Color = size.Color })
	end
	if material and info.Material ~= "None" then
		table.insert(list, { Label = "MATERIAL", Value = info.Material, Color = material.Color })
	end
	if quality and not info.Ambient then
		table.insert(list, { Label = "QUALITY", Value = quality.Name, Color = quality.Color })
	end
	table.insert(list, { Label = "VALUE", Value = Format.Abbreviate(info.Value) .. " coins", Color = C.Money })
	return list
end

function FindReveal.Show(info: Types.FindInfo)
	local p = FindReveal.Presentation(info)
	local rarity = Config.GetRarity(info.Rarity)
	local color = if rarity then rarity.Color else C.Text
	local name = Finds.DisplayName(info.TreasureId, info.Size, info.Material)
	if p.Float and typeof(info.Position) == "Vector3" then
		local scale = 0.9 + Finds.TierOrder(p.Tier) * 0.15
		EffectsController.FloatText(info.Position + Vector3.new(0, 2, 0), name .. "!", color, scale)
		task.delay(0.35, function()
			EffectsController.FloatText(info.Position, "+" .. Format.Abbreviate(info.Value), C.Money, 0.8)
		end)
	end
	if p.Camera then
		cameraMoment(if p.Flash then 1.6 else 1)
	end
	if p.Card == "None" then
		SoundController.Play(p.Sound)
		return
	end
	local model: Model? = nil
	local ok, built = pcall(function(): Model
		return Models.Find(info.TreasureId, info.Size, info.Material)
	end)
	if ok then
		model = built
		ModelFactory.MakeVisualOnly(built)
	else
		model = ModelFactory.Treasure(info.TreasureId)
	end
	local tag = if info.IsNew then "NEW!" elseif #info.NewVariants > 0 then "NEW VARIANT!" else nil
	Reveal.Show({
		Headline = string.upper(info.Rarity) .. "!",
		Color = color,
		Gradient = if rarity then rarity.Gradient else nil,
		Caption = if info.Perfect then "PERFECT DIG!" elseif info.Ambient then "LUCKY FIND!" else "YOU DUG UP",
		Items = {
			{
				Name = name,
				NameColor = color,
				Model = model,
				Pitch = 20,
				Rows = rows(info, color),
				Tag = tag,
			},
		},
		Compact = p.Card == "Compact",
		Hold = if p.Card == "Full" then 4.5 else 2.6,
		Sound = p.Sound,
		Flash = p.Flash,
		Confetti = p.Confetti,
	})
end

function FindReveal.Init()
	DiscoveryController.FindRevealed:Connect(function(info: Types.FindInfo)
		FindReveal.Show(info)
	end)
end

return FindReveal
