--!strict
--[[
	ChatLayoutController — keeps Roblox's chat window off the HUD menu.

	The default TextChatService window opens in the top-left corner, exactly where the menu's
	first row (Shop, Beach) sits (UI/Layout "Menu"), so an expanded chat covered Shop in
	playtests. On mouse/keyboard screens the bottom-left corner is free (the bottom bar is
	centred and nothing else lives there), so the window is docked there. Touch screens keep
	Roblox's default: the bottom-left is the thumbstick, and mobile chat stays collapsed
	until the player opens it.
]]
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")

local ChatLayoutController = {}

export type Dock = { Horizontal: Enum.HorizontalAlignment, Vertical: Enum.VerticalAlignment }

-- Where the chat window goes for this device, or nil to keep Roblox's default.
function ChatLayoutController.DockFor(touchEnabled: boolean, keyboardEnabled: boolean): Dock?
	if touchEnabled and not keyboardEnabled then
		return nil
	end
	return { Horizontal = Enum.HorizontalAlignment.Left, Vertical = Enum.VerticalAlignment.Bottom }
end

local function apply(window: ChatWindowConfiguration)
	local dock = ChatLayoutController.DockFor(UserInputService.TouchEnabled, UserInputService.KeyboardEnabled)
	if dock then
		window.HorizontalAlignment = dock.Horizontal
		window.VerticalAlignment = dock.Vertical
	end
end

function ChatLayoutController.Init()
	local window = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	if window then
		apply(window)
		return
	end
	-- legacy chat or not created yet: pick it up if it appears
	local connection: RBXScriptConnection? = nil
	connection = TextChatService.ChildAdded:Connect(function(child: Instance)
		if child:IsA("ChatWindowConfiguration") then
			apply(child)
			if connection then
				connection:Disconnect()
			end
		end
	end)
end

return ChatLayoutController
