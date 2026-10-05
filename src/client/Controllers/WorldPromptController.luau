--!strict
--[[
	WorldPromptController — map stations open UI. Parts tagged ShovelShop / BackpackShop /
	EggShop / RebirthStatue carry a ProximityPrompt; Triggered opens the matching panel.
	EggShop pedestals (and their prompt) carry attribute "EggId" -> egg panel focuses that egg.
	Tagged parts may stream in late, so we use GetTagged + GetInstanceAddedSignal and also
	watch for prompts added under a tagged part later.
]]
local CollectionService = game:GetService("CollectionService")

local Panel = require(script.Parent.Parent.UI.Components.Panel)

local WorldPromptController = {}

type Opener = (inst: Instance, prompt: ProximityPrompt) -> ()

local function eggIdOf(inst: Instance, prompt: ProximityPrompt): string?
	local id = prompt:GetAttribute("EggId") or inst:GetAttribute("EggId")
	return if typeof(id) == "string" then id else nil
end

local OPENERS: { [string]: Opener } = {
	ShovelShop = function()
		Panel.Open("Shop", { Tab = "Shovels" })
	end,
	BackpackShop = function()
		Panel.Open("Shop", { Tab = "Backpacks" })
	end,
	EggShop = function(inst, prompt)
		Panel.Open("Eggs", { EggId = eggIdOf(inst, prompt) })
	end,
	RebirthStatue = function()
		Panel.Open("Rebirth")
	end,
}

local hooked: { [ProximityPrompt]: boolean } = {}

local function hookPrompt(tag: string, inst: Instance, prompt: ProximityPrompt)
	if hooked[prompt] then
		return
	end
	hooked[prompt] = true
	prompt.Triggered:Connect(function()
		OPENERS[tag](inst, prompt)
	end)
	prompt.Destroying:Connect(function()
		hooked[prompt] = nil
	end)
end

local function hookTagged(tag: string, inst: Instance)
	if inst:IsA("ProximityPrompt") then
		hookPrompt(tag, inst, inst)
		return
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			hookPrompt(tag, inst, d)
		end
	end
	inst.DescendantAdded:Connect(function(d: Instance)
		if d:IsA("ProximityPrompt") then
			hookPrompt(tag, inst, d)
		end
	end)
end

function WorldPromptController.Init()
	for tag in OPENERS do
		for _, inst in CollectionService:GetTagged(tag) do
			task.spawn(hookTagged, tag, inst)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst: Instance)
			hookTagged(tag, inst)
		end)
	end
end

return WorldPromptController
