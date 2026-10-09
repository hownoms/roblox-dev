--!strict
--[[
	BroadwaveEquip — equip / put away toggle for the expansion's Broadwave tools
	(docs/integration/licensed-broadwave.md). Production hides the Backpack CoreGui (Main), so
	without this control neither the adventure loan nor a licensed Broadwave can be equipped.

	  * Inert by default: AdventureController starts it only after the server created the
	    adventure remotes (AdventureFlags.SpringVault). Until the local player actually holds a
	    Broadwave tool nothing is built or bound; when the last one goes away (loan returned,
	    license removed, respawn, kill switch) the button hides and the key binding is removed.
	  * Tools: the runtime's loan (AdventureLoan) and the server-issued licensed tool
	    (LicensedBroadwave / ToolId "tool_broadwave"), in the Backpack or the character. Labels
	    differ: "Broadwave (loan)" vs "Broadwave". With both, the arena prefers the loan (event and
	    Pip trial work) and everywhere else the licensed tool (ordinary sand); an equipped one wins.
	  * Equip is local (Humanoid:EquipTool replicates for the player's own tools); no remote is
	    fired. Putting it away re-equips the shovel (the ShovelId tool), so ordinary digging keeps
	    working. While a Broadwave is in hand DigController pauses ordinary digging (hint toast)
	    rather than digging with the stowed shovel or swapping tools under the player.
	  * Inputs: the button (touch / mouse / gamepad selection), keyboard Z, gamepad ButtonR1.
	    Q / L1 / the runtime touch button stay the Broadwave charge (SpringVaultClient).
	  * One visible equip control (production-wiring.md 4, "One equip control"). The runtime
	    (SpringVaultClient) builds its own "BroadwaveEquip" button whenever it runs. Until Codex
	    ships the requested ExternalEquip start option, ours steps aside: it hides while
	    AdventureController reports the runtime client running (SetRuntimeOwner) or while the
	    runtime's button is effectively visible in PlayerGui (read-only lookup, never mutated).
	    Z / ButtonR1 stay bound either way (keys are not a second visible control).
	  * Loans stay in the arena: outside it an unequipped loan is never a target (no button, Z
	    does nothing), so the loan cannot be taken out onto the sand. A loan already in hand
	    outside the arena stays a target so it can be put away.
	  * Layout: UI/Layout "Broadwave" region (clear of every HUD region, the Scan pill and the phone
	    thumbstick / jump zones), own ScreenGui with the shared responsive scale.
]]
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local Components = script.Parent.Components
local Style = require(Components.Style)
local Button = require(Components.Button)
local Root = require(script.Parent.Root)
local Layout = require(script.Parent.Layout)
local InputArbiter = require(script.Parent.Parent.Controllers.InputArbiter)
local Character = require(script.Parent.Parent.Util.Character)

local BroadwaveEquip = {}

BroadwaveEquip.ACTION = "BroadwaveEquip"
BroadwaveEquip.KEYS = { Enum.KeyCode.Z, Enum.KeyCode.ButtonR1 }
BroadwaveEquip.LOAN_LABEL = "Broadwave (loan)"
BroadwaveEquip.LICENSED_LABEL = "Broadwave"
BroadwaveEquip.STOWED_COLOR = Style.Colors.Ocean
BroadwaveEquip.IN_HAND_COLOR = Style.Colors.Palm
BroadwaveEquip.Gui = nil :: ScreenGui?
BroadwaveEquip.Button = nil :: Button.Button?
BroadwaveEquip.RUNTIME_GUI = "SpringVaultAdventureReview" -- SpringVaultClient's ScreenGui
BroadwaveEquip.RUNTIME_BUTTON = "BroadwaveEquip" -- its equip / stow TextButton

local TOGGLE_DEBOUNCE = 0.2

local player = Players.LocalPlayer
local started = false
local bound = false
local pending = false
local lastToggle = -math.huge
local watched: { [Instance]: { RBXScriptConnection } } = {}
local runtimeOwner: () -> boolean = function()
	return false
end

local function inArena(): boolean
	return InputArbiter.Has("AdventureArena")
end

-- AdventureController: true while the runtime client (and so its own equip button) is running.
function BroadwaveEquip.SetRuntimeOwner(fn: () -> boolean)
	runtimeOwner = fn
end

-- Read-only: is the runtime's own equip button on screen (it and every ancestor visible)?
function BroadwaveEquip.RuntimeButtonVisible(): boolean
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local gui = playerGui and playerGui:FindFirstChild(BroadwaveEquip.RUNTIME_GUI)
	local button = gui and gui:FindFirstChild(BroadwaveEquip.RUNTIME_BUTTON, true)
	if not button or not button:IsA("GuiObject") then
		return false
	end
	local node: Instance? = button
	while node and node ~= gui do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		node = node.Parent
	end
	return node == gui and (gui :: ScreenGui).Enabled ~= false
end

-- The runtime's control owns equip / stow right now, so ours must not show.
function BroadwaveEquip.RuntimeOwnsControl(): boolean
	return runtimeOwner() or BroadwaveEquip.RuntimeButtonVisible()
end

-- Every Broadwave tool the local player holds, and the equipped one (if any).
local function collect(): ({ Tool }, Tool?)
	local list: { Tool } = {}
	local equipped: Tool? = nil
	local character = player.Character
	if character then
		for _, child in character:GetChildren() do
			if InputArbiter.IsBroadwaveTool(child) then
				table.insert(list, child :: Tool)
				equipped = equipped or child :: Tool
			end
		end
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in backpack:GetChildren() do
			if InputArbiter.IsBroadwaveTool(child) then
				table.insert(list, child :: Tool)
			end
		end
	end
	return list, equipped
end

-- The tool the control acts on, and whether it is in hand.
function BroadwaveEquip.Target(): (Tool?, boolean)
	local list, equipped = collect()
	if equipped then
		return equipped, true
	end
	local preferLoan = inArena()
	local fallback: Tool? = nil
	for _, tool in list do
		local loan = InputArbiter.IsBroadwaveLoan(tool)
		if loan == preferLoan then
			return tool, false
		end
		-- Outside the arena a stowed loan is never offered (it cannot be used on the sand).
		if preferLoan or not loan then
			fallback = fallback or tool
		end
	end
	return fallback, false
end

function BroadwaveEquip.Label(tool: Tool?): string
	return if InputArbiter.IsBroadwaveLoan(tool) then BroadwaveEquip.LOAN_LABEL else BroadwaveEquip.LICENSED_LABEL
end

local function caption(tool: Tool): string
	-- Two short lines so the words stay readable on a 120 px phone button.
	return if InputArbiter.IsBroadwaveLoan(tool) then "Broadwave\n(loan)" else "Broadwave"
end

local function shovel(): Tool?
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, child in if backpack then backpack:GetChildren() else {} do
		if child:IsA("Tool") and child:GetAttribute("ShovelId") ~= nil then
			return child
		end
	end
	return nil
end

local refresh: () -> ()

-- Equips the target Broadwave, or puts the equipped one away (re-equipping the shovel).
function BroadwaveEquip.Toggle(): boolean
	local now = os.clock()
	if now - lastToggle < TOGGLE_DEBOUNCE then
		return false
	end
	local humanoid = Character.GetHumanoid()
	local tool, equipped = BroadwaveEquip.Target()
	if not humanoid or not tool then
		return false
	end
	lastToggle = now
	if equipped then
		local spade = shovel()
		if spade then
			humanoid:EquipTool(spade)
		else
			humanoid:UnequipTools()
		end
	else
		humanoid:EquipTool(tool)
	end
	refresh()
	return true
end

local function onAction(_: string, state: Enum.UserInputState, _: InputObject): Enum.ContextActionResult
	if not BroadwaveEquip.Target() then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin then
		BroadwaveEquip.Toggle()
	end
	return Enum.ContextActionResult.Sink
end

local function bind(on: boolean)
	if on == bound then
		return
	end
	bound = on
	if on then
		ContextActionService:BindAction(BroadwaveEquip.ACTION, onAction, false, table.unpack(BroadwaveEquip.KEYS))
	else
		ContextActionService:UnbindAction(BroadwaveEquip.ACTION)
	end
end

local function build(): Button.Button
	local gui = Instance.new("ScreenGui")
	gui.Name = "Dig_Broadwave"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 2
	BroadwaveEquip.Gui = gui

	local canvas = Instance.new("Frame")
	canvas.Name = "Canvas"
	canvas.BackgroundTransparency = 1
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.fromScale(0.5, 0.5)
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = canvas
	local function applyScale(s: number)
		scale.Scale = s
		canvas.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	applyScale(Root.Scale)
	Root.ScaleChanged:Connect(applyScale)

	local button = Button.new({
		Name = "BroadwaveEquip",
		Parent = canvas,
		Text = "Broadwave",
		Color = BroadwaveEquip.STOWED_COLOR,
		Size = Layout.SizeOf(Layout.Current().Broadwave),
		Position = Layout.Position(Layout.Current().Broadwave),
		MaxTextSize = 22,
		OnClick = function()
			BroadwaveEquip.Toggle()
		end,
	})
	BroadwaveEquip.Button = button
	Layout.Observe(function(regions: Layout.Regions)
		button.Holder.Position = Layout.Position(regions.Broadwave)
		button.Holder.Size = Layout.SizeOf(regions.Broadwave)
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
	return button
end

local function watch(container: Instance?)
	if not container or watched[container] then
		return
	end
	local function soon()
		BroadwaveEquip.Refresh()
	end
	watched[container] = { container.ChildAdded:Connect(soon), container.ChildRemoved:Connect(soon) }
end

refresh = function()
	pending = false
	-- Drop containers from earlier lives (old Backpack / character after a respawn).
	for container, list in watched do
		if container.Parent == nil then
			for _, c in list do
				c:Disconnect()
			end
			watched[container] = nil
		end
	end
	watch(player:FindFirstChildOfClass("Backpack"))
	watch(player.Character)
	local tool, equipped = BroadwaveEquip.Target()
	local button = BroadwaveEquip.Button
	if not tool then
		if button then
			button:SetVisible(false)
		end
		bind(false)
		return
	end
	bind(true)
	if BroadwaveEquip.RuntimeOwnsControl() then
		-- One visible control: the runtime's button is up (see the header). Built lazily later.
		if button then
			button:SetVisible(false)
		end
		return
	end
	button = button or build()
	assert(button)
	button:SetText(caption(tool))
	button:SetColor(if equipped then BroadwaveEquip.IN_HAND_COLOR else BroadwaveEquip.STOWED_COLOR)
	button:SetVisible(true)
end

-- Coalesces bursts (a respawn moves several children) into one refresh on the next resumption.
function BroadwaveEquip.Refresh()
	if not started or pending then
		return
	end
	pending = true
	task.defer(refresh)
end

function BroadwaveEquip.State(): {
	Visible: boolean,
	Label: string?,
	Equipped: boolean,
	Bound: boolean,
	RuntimeOwns: boolean,
}
	local tool, equipped = BroadwaveEquip.Target()
	local button = BroadwaveEquip.Button
	return {
		Visible = button ~= nil and button.Holder.Visible,
		Label = if tool then BroadwaveEquip.Label(tool) else nil,
		Equipped = equipped,
		Bound = bound,
		RuntimeOwns = BroadwaveEquip.RuntimeOwnsControl(),
	}
end

function BroadwaveEquip.Start()
	if started then
		return
	end
	started = true
	player.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Backpack") then
			BroadwaveEquip.Refresh()
		end
	end)
	player.CharacterAdded:Connect(BroadwaveEquip.Refresh)
	player.CharacterRemoving:Connect(BroadwaveEquip.Refresh)
	refresh()
end

return BroadwaveEquip
