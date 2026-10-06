--!strict
--[[
	SocialHUD — co-play reasons on screen (v2.2 SOCIAL, Status & Social agent). Lives in the HUD
	canvas at the UI/Layout "Social" region (wide screens: under the depth meter; narrow: under
	the SurvivalHUD), 200 x 80 design px:
	  GoalBar      "Server goal 12.4K / 50K" progress pill from Workspace attributes
	               ServerGoalProgress / ServerGoalTarget (server: ServerGoalService). While the
	               reward event runs / cools down (ServerGoalResumeAt in the future) it reads
	               "Goal reached! Next in 4:12".
	  FriendsChip  "Friends +10%" when the local player has friends in this server (Player
	               attribute FriendsInServer, same bonus maths as Util/Stats). Hidden otherwise.
	Invite: SocialHUD.PromptInvite() opens Roblox's invite dialog (SocialService, every call
	pcall'd; CanSendGameInviteAsync first). No reward for invites (they can't be verified).
	The Settings panel has the "Invite friends" button.

	API: SocialHUD.PromptInvite(): (boolean, string), SocialHUD.FriendBonusText(n): string?,
	     SocialHUD.GoalText(progress, target, resumeIn): string, SocialHUD.Holder
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))

local Root = require(script.Parent.Root)
local Style = require(script.Parent.Components.Style)
local AtlasIcon = require(script.Parent.Components.AtlasIcon)
local ProgressBar = require(script.Parent.Components.ProgressBar)
local Layout = require(script.Parent.Layout)
local Toasts = require(script.Parent.Toasts)

local SocialHUD = {}

SocialHUD.Holder = nil :: Frame?

local C = Style.Colors
local FRIENDS_ICON = "👫"

-- "Friends +10%" for n friends in the server (nil when none).
function SocialHUD.FriendBonusText(friends: number): string?
	local n = math.max(0, math.floor(friends))
	if n <= 0 then
		return nil
	end
	local bonus = math.min(n * Config.FRIEND_BONUS_PER_FRIEND, Config.FRIEND_BONUS_MAX)
	return string.format("Friends +%d%%", math.floor(bonus * 100 + 0.5))
end

function SocialHUD.GoalText(progress: number, target: number, resumeIn: number): string
	if resumeIn > 0 then
		return "Goal reached! Next in " .. Format.Time(resumeIn)
	end
	return "Server goal " .. Format.Abbreviate(math.floor(progress)) .. " / " .. Format.Abbreviate(target)
end

-- Opens the Roblox invite dialog. Returns (opened, reason).
function SocialHUD.PromptInvite(): (boolean, string)
	local player = Players.LocalPlayer
	local okCan, can = pcall(function(): boolean
		return SocialService:CanSendGameInviteAsync(player)
	end)
	if not okCan or can ~= true then
		Toasts.Show("Invites aren't available right now.", "Info")
		return false, if okCan then "NotAllowed" else "Error"
	end
	local okPrompt = pcall(function()
		SocialService:PromptGameInvite(player)
	end)
	if not okPrompt then
		Toasts.Show("Couldn't open the invite window. Try again!", "Info")
		return false, "Error"
	end
	return true, "Opened"
end

local function numberAttr(instance: Instance, name: string): number
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

function SocialHUD.Init()
	local holder = Instance.new("Frame")
	holder.Name = "Social"
	holder.BackgroundTransparency = 1
	holder.Parent = Root.Get("HUD")
	SocialHUD.Holder = holder
	Layout.Observe(function(regions: Layout.Regions)
		holder.Position = Layout.Position(regions.Social)
		holder.Size = Layout.SizeOf(regions.Social)
	end)
	Style.List(holder, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Right)

	local goal = ProgressBar.new({
		Name = "GoalBar",
		Size = UDim2.new(1, -14, 0, 36),
		Color = C.Gold,
		MaxTextSize = 16,
		LayoutOrder = 1,
		ZIndex = 2,
		Parent = holder,
	})
	AtlasIcon.new({
		Name = "GoalIcon",
		Icon = "trophy",
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.new(0, -18, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		ZIndex = 5,
		Parent = goal.Frame,
	})

	local chip = Instance.new("Frame")
	chip.Name = "FriendsChip"
	chip.Size = UDim2.new(1, -14, 0, 32)
	chip.LayoutOrder = 2
	chip.Visible = false
	chip.Parent = holder
	Style.Pill(chip, 0.08)
	local ring = chip:FindFirstChildOfClass("UIStroke")
	if ring then
		ring.Color = Style.Darken(C.Coral, 0.2)
	end
	AtlasIcon.new({
		Icon = FRIENDS_ICON,
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.new(0, -8, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		ZIndex = 3,
		Parent = chip,
	})
	local chipLabel = Style.Label({
		Name = "Text",
		Size = UDim2.new(1, -40, 0.78, 0),
		Position = UDim2.new(0, 32, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		TextColor = C.Money,
		MaxTextSize = 18,
		XAlign = Enum.TextXAlignment.Left,
		ZIndex = 2,
		Parent = chip,
	})

	local function updateGoal()
		local progress = numberAttr(Workspace, "ServerGoalProgress")
		local target = numberAttr(Workspace, "ServerGoalTarget")
		local resumeIn = math.max(0, numberAttr(Workspace, "ServerGoalResumeAt") - Workspace:GetServerTimeNow())
		goal.Frame.Visible = target > 0
		if target > 0 then
			local alpha = if resumeIn > 0 then 1 else math.clamp(progress / target, 0, 1)
			goal:Set(alpha, SocialHUD.GoalText(progress, target, resumeIn))
		end
	end
	local function updateFriends()
		local text = SocialHUD.FriendBonusText(numberAttr(Players.LocalPlayer, "FriendsInServer"))
		local was = chip.Visible
		chip.Visible = text ~= nil
		if text then
			chipLabel.Text = text
			if not was then
				Style.PopIn(chip)
			end
		end
	end
	for _, name in { "ServerGoalProgress", "ServerGoalTarget", "ServerGoalResumeAt" } do
		Workspace:GetAttributeChangedSignal(name):Connect(updateGoal)
	end
	Players.LocalPlayer:GetAttributeChangedSignal("FriendsInServer"):Connect(updateFriends)
	updateGoal()
	updateFriends()
	task.spawn(function()
		while holder.Parent do
			task.wait(1)
			if numberAttr(Workspace, "ServerGoalResumeAt") > 0 then
				updateGoal() -- countdown
			end
		end
	end)
end

return SocialHUD
