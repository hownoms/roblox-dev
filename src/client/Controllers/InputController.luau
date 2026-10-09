--!strict
-- InputController — console/PC shortcuts. Gamepad: R2 dig (DigController), X = Surface,
-- (Q yields to the adventure's Broadwave charge only while a Broadwave tool is equipped and the
-- charge is bound),
-- Y = jump into the HUD menu with selection (B closes panels, see Panel). Keyboard: Q = Surface,
-- G = Shop, P = Pets.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local SoundController = require(script.Parent.SoundController)
local InputArbiter = require(script.Parent.InputArbiter)
local HUD = require(script.Parent.Parent.UI.HUD)
local Panel = require(script.Parent.Parent.UI.Components.Panel)

local InputController = {}

local function onBegin(fn: () -> ()): (string, Enum.UserInputState, InputObject) -> Enum.ContextActionResult
	return function(_, state: Enum.UserInputState, _): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin then
			fn()
		end
		return Enum.ContextActionResult.Sink
	end
end

function InputController.Init()
	-- Q is shared with the adventure's Broadwave charge (Q / L1). Bound one step above default
	-- priority so Q surfaces as before unless a Broadwave tool is equipped and the runtime's charge
	-- action is bound, in which case Q passes to it (InputArbiter.QToCharge). ButtonX always
	-- surfaces.
	ContextActionService:BindActionAtPriority(
		"DigSurface",
		function(_, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
			if input.KeyCode == Enum.KeyCode.Q and InputArbiter.QToCharge() then
				return Enum.ContextActionResult.Pass
			end
			if state == Enum.UserInputState.Begin then
				SoundController.Play("Teleport")
				Remotes.Get("ReturnToSurface"):FireServer()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.Medium.Value + 1,
		Enum.KeyCode.ButtonX,
		Enum.KeyCode.Q
	)
	ContextActionService:BindAction(
		"DigMenu",
		onBegin(function()
			if GuiService.SelectedObject then
				GuiService.SelectedObject = nil
				return
			end
			local first = HUD.FirstMenuButton() -- the menu unlocks progressively
			if first then
				GuiService.SelectedObject = first.Face
			end
		end),
		false,
		Enum.KeyCode.ButtonY
	)
	ContextActionService:BindAction(
		"DigShortcutShop",
		onBegin(function()
			Panel.Toggle("Shop")
		end),
		false,
		Enum.KeyCode.G
	)
	ContextActionService:BindAction(
		"DigShortcutPets",
		onBegin(function()
			Panel.Toggle("Pets")
		end),
		false,
		Enum.KeyCode.P
	)
end

return InputController
