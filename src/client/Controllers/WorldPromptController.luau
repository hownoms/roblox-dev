--!strict
--[[
	WorldPromptController — map stations open UI. Parts tagged ShovelShop / BackpackShop /
	EggShop / RebirthStatue carry a ProximityPrompt; Triggered opens the matching panel.
	EggShop pedestals (and their prompt) carry attribute "EggId" -> egg panel focuses that egg.
	v2.3 streaming: Util/Tagged.WatchPrompts handles parts that stream in late, prompts that
	arrive after their part, and stream-outs (connections are dropped with the instance).
]]
local Panel = require(script.Parent.Parent.UI.Components.Panel)
local Tagged = require(script.Parent.Parent.Util.Tagged)

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

function WorldPromptController.Init()
	for tag, opener in OPENERS do
		-- v2.3 streaming: stations stream in late, out, and back in as new instances; Tagged
		-- hooks every arrival and disconnects on InstanceRemoved.
		Tagged.WatchPrompts(tag, opener)
	end
end

return WorldPromptController
