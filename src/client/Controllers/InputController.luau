--!strict
-- InputController — console/PC shortcuts. Gamepad: R2 dig (DigController), X = Surface,
-- Y = jump into the HUD menu with selection (B closes panels, see Panel). Keyboard: Q = Surface,
-- G = Shop, P = Pets.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local SoundController = require(script.Parent.SoundController)
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
	ContextActionService:BindAction(
		"DigSurface",
		onBegin(function()
			SoundController.Play("Teleport")
			Remotes.Get("ReturnToSurface"):FireServer()
		end),
		false,
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
