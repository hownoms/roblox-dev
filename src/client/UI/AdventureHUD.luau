--!strict
--[[
	AdventureHUD — keeps the production HUD out of the Spring Vault runtime's way while the player
	stands in the arena (docs/integration/production-wiring.md 4, "Screen layout").

	The runtime (Codex's SpringVaultClient) owns its own ScreenGui "SpringVaultAdventureReview":
	the panel at the top centre (330 x 192..300 px, scrolls on short screens), the aim hint while
	charging, the desktop equip / stow button at the bottom right (176 x 48, 12 px in, 76 px up)
	and the 64 px touch charge button (ContextActionService "SpringVaultBroadwave"). Those are
	only READ here (absolute rects of the visible ones); nothing of Codex's is ever changed.

	AdventureController calls Update(inArena) every tick. In the arena:
	  * Depth meter: always hidden (the reading is meaningless in the pocket under the sand).
	  * Timers, TopRight, Social, Bottom (Dig_HUD), the SurvivalHUD holder (Dig_Survival) and
	    the Ride buttons (Dig_Ride): hidden only while they actually overlap a visible runtime
	    element, so a wide desktop keeps its bottom bar and a short phone gets the room it needs.
	  * Objective banner (tutorial / guide pill): suppressed through ObjectiveBanner.SetSuppressed
	    while it overlaps a runtime element (it toggles its own Visible, so it is not in PIECES);
	    its objective is kept and it comes back on leaving.
	  * Toasts: moved below the runtime panel (Toasts.SetClearance) instead of hidden, so
	    messages are never lost.
	Restoring is exact: the listed frames are ones whose Visible their owners never toggle, and
	the Ride buttons (whose Visible RideButton does toggle) are hidden through their own
	ScreenGui's Enabled, which nothing else touches. Leaving the arena (or the kill switch)
	restores everything.
]]
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local ObjectiveBanner = require(script.Parent.ObjectiveBanner)
local Root = require(script.Parent.Root)
local Toasts = require(script.Parent.Toasts)

local AdventureHUD = {}

AdventureHUD.RUNTIME_GUI = "SpringVaultAdventureReview"
AdventureHUD.CHARGE_ACTION = "SpringVaultBroadwave"
AdventureHUD.TOAST_GAP = 6 -- design px between the runtime panel and the first toast

-- Name: the canvas child whose rect is tested. WholeGui: hide the ScreenGui (Enabled) instead.
export type Piece = { Gui: string, Name: string, Always: boolean?, WholeGui: boolean? }
export type Rect = { X: number, Y: number, W: number, H: number }

AdventureHUD.PIECES = table.freeze({
	{ Gui = "Dig_HUD", Name = "Depth", Always = true },
	{ Gui = "Dig_HUD", Name = "Timers" },
	{ Gui = "Dig_HUD", Name = "TopRight" },
	{ Gui = "Dig_HUD", Name = "Social" },
	{ Gui = "Dig_HUD", Name = "Bottom" },
	{ Gui = "Dig_Survival", Name = "SurvivalHUD" },
	{ Gui = "Dig_Ride", Name = "RideButton", WholeGui = true },
} :: { Piece })

local player = Players.LocalPlayer
local hidden: { [Instance]: boolean } = {} -- frame or ScreenGui -> its value before hiding

local function rectOf(object: GuiObject): Rect
	local position, size = object.AbsolutePosition, object.AbsoluteSize
	return { X = position.X, Y = position.Y, W = size.X, H = size.Y }
end

local function overlaps(a: Rect, b: Rect): boolean
	return a.W > 0
		and a.H > 0
		and b.W > 0
		and b.H > 0
		and a.X < b.X + b.W
		and b.X < a.X + a.W
		and a.Y < b.Y + b.H
		and b.Y < a.Y + a.H
end

local function shown(object: GuiObject, stop: Instance): boolean
	local node: Instance? = object
	while node and node ~= stop do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		node = node.Parent
	end
	return true
end

local function playerGui(): Instance?
	return player:FindFirstChildOfClass("PlayerGui")
end

-- The runtime's panel (its ScrollingFrame), if it is on screen. Read-only.
function AdventureHUD.Panel(): GuiObject?
	local gui = playerGui()
	local runtime = gui and gui:FindFirstChild(AdventureHUD.RUNTIME_GUI)
	if not runtime or not runtime:IsA("ScreenGui") or runtime.Enabled == false then
		return nil
	end
	local panel = runtime:FindFirstChildOfClass("ScrollingFrame")
	return if panel and panel.Visible then panel else nil
end

-- Absolute rects of every visible runtime element (panel, aim hint, equip, touch charge). Read-only.
function AdventureHUD.Obstacles(): { Rect }
	local out: { Rect } = {}
	local gui = playerGui()
	local runtime = gui and gui:FindFirstChild(AdventureHUD.RUNTIME_GUI)
	if runtime and runtime:IsA("ScreenGui") and runtime.Enabled ~= false then
		for _, child in runtime:GetDescendants() do
			if
				child:IsA("GuiObject")
				and (child:IsA("ScrollingFrame") or child.Name == "BroadwaveAimHint" or child.Name == "BroadwaveEquip")
				and shown(child, runtime)
			then
				table.insert(out, rectOf(child))
			end
		end
	end
	local touch = ContextActionService:GetButton(AdventureHUD.CHARGE_ACTION)
	if touch and touch.Visible then
		table.insert(out, rectOf(touch))
	end
	return out
end

-- The canvas child to test, and the instance to hide (the child, or its ScreenGui).
local function find(piece: Piece): (GuiObject?, Instance?)
	local gui = playerGui()
	local screen = gui and gui:FindFirstChild(piece.Gui)
	local canvas = screen and screen:FindFirstChild("Canvas")
	local object = canvas and canvas:FindFirstChild(piece.Name)
	if not object or not object:IsA("GuiObject") then
		return nil, nil
	end
	return object, if piece.WholeGui then screen else object
end

local function setHidden(target: Instance, hide: boolean)
	local before = hidden[target]
	if hide and before == nil then
		if target:IsA("ScreenGui") then
			hidden[target] = target.Enabled
			target.Enabled = false
		elseif target:IsA("GuiObject") then
			hidden[target] = target.Visible
			target.Visible = false
		end
	elseif not hide and before ~= nil then
		hidden[target] = nil
		if target:IsA("ScreenGui") then
			target.Enabled = before
		elseif target:IsA("GuiObject") then
			target.Visible = before
		end
	end
end

-- Toasts start below the runtime panel while it covers their column (design px).
local function clearance(inArena: boolean): number?
	local panel = if inArena then AdventureHUD.Panel() else nil
	local layer = Root.Layers.Toasts
	if not panel or not layer then
		return nil
	end
	local canvas = layer.Canvas
	local toasts = canvas:FindFirstChild("Toasts")
	local bottom = panel.AbsolutePosition.Y + panel.AbsoluteSize.Y
	if toasts and toasts:IsA("GuiObject") then
		local column = rectOf(toasts)
		local panelRect = rectOf(panel)
		local horizontal = panelRect.X < column.X + column.W and column.X < panelRect.X + panelRect.W
		if not horizontal then
			return nil
		end
	end
	local scale = if Root.Scale > 0 then Root.Scale else 1
	return (bottom - canvas.AbsolutePosition.Y) / scale + AdventureHUD.TOAST_GAP
end

function AdventureHUD.Update(inArena: boolean)
	local obstacles: { Rect } = if inArena then AdventureHUD.Obstacles() else {}
	for _, piece in AdventureHUD.PIECES do
		local object, target = find(piece)
		if object and target then
			local hide = false
			if inArena then
				hide = piece.Always == true
				local rect = rectOf(object)
				for _, other in obstacles do
					if hide then
						break
					end
					hide = overlaps(rect, other)
				end
			end
			setHidden(target, hide)
		end
	end
	local pill = ObjectiveBanner.Get()
	local coverPill = false
	if inArena and pill then
		local rect = rectOf(pill)
		for _, other in obstacles do
			if overlaps(rect, other) then
				coverPill = true
				break
			end
		end
	end
	ObjectiveBanner.SetSuppressed(coverPill)
	-- Pieces destroyed or rebuilt meanwhile: forget them.
	for object in hidden do
		if object.Parent == nil then
			hidden[object] = nil
		end
	end
	Toasts.SetClearance(clearance(inArena))
end

-- Names of the pieces currently hidden by the arena rule (tests and diagnostics).
function AdventureHUD.Hidden(): { string }
	local out = {}
	for object in hidden do
		table.insert(out, object.Name)
	end
	table.sort(out)
	return out
end

return AdventureHUD
