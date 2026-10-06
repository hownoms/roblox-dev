--!strict
--[[
	StreamingService (v2.3, Platform agent): server half of Workspace.StreamingEnabled.

	With streaming on, a client only has the parts near its character (StreamingTargetRadius 320,
	at least StreamingMinRadius 64; see default.project.json and docs/PERFORMANCE.md). A player at
	the bottom of a 1000-stud hole, or at the far end of the 768-stud beach, does NOT have the
	hub stations. So:

	1. World anchors. For every station tag (ANCHOR_TAGS) the server publishes the world
	   positions of all tagged instances as attributes on a non-spatial folder that always
	   replicates:
	     ReplicatedStorage.WorldAnchors.<Tag>   attributes  Count = n, P1..Pn = Vector3
	   (BasePart: top-centre, the same point GuideController aims at; Model: its pivot.)
	   Clients read them through Client/Util/Anchors, for example to aim a guide beam at a
	   station that has streamed out. They are rebuilt when tagged instances are added or removed.
	   StreamingService.Track(tag) adds another tag (e.g. a new v3 station).

	2. Station models stream atomically. The closest ancestor Model of every tagged station
	   gets ModelStreamingMode = Atomic (only when still Default), so a station's part, its
	   ProximityPrompt, its billboard and attributes like EggId arrive and leave together.
	   Nothing is Persistent: no client system needs a far station anymore (guides use anchors,
	   the sell pad is detected on the server, leaderboards are server-rendered SurfaceGuis).

	Other streaming modes are set where the models are created: ride vehicles
	(RideService) and placed shades (SurvivalShades) are PersistentPerPlayer, kept for their
	owner and Atomic for everyone else.

	API: StreamingService.Init(), StreamingService.Track(tag), StreamingService.GetAnchors(tag)
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local StreamingService = {}

StreamingService.FOLDER = "WorldAnchors"
StreamingService.ANCHOR_TAGS = {
	"SellZone",
	"ShovelShop",
	"BackpackShop",
	"EggShop",
	"CrateShop",
	"RebirthStatue",
	"WaterFountain",
	"BeachShop",
	"LeaderboardCoins",
	"LeaderboardDepth",
	"SpawnLocation",
}
-- Tags whose ancestor Model must not be made Atomic (spawns are loose parts in the Hub folder).
local NO_ATOMIC: { [string]: boolean } = { SpawnLocation = true }

local folder: Folder? = nil
local tracked: { [string]: boolean } = {}
local pending: { [string]: boolean } = {}

local function getFolder(): Folder
	local current = folder
	if current and current.Parent then
		return current
	end
	local existing = ReplicatedStorage:FindFirstChild(StreamingService.FOLDER)
	if existing and existing:IsA("Folder") then
		folder = existing
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = StreamingService.FOLDER
	f.Parent = ReplicatedStorage
	folder = f
	return f
end

local function anchorOf(inst: Instance): Vector3?
	if inst:IsA("BasePart") then
		return inst.Position + Vector3.new(0, inst.Size.Y / 2, 0)
	elseif inst:IsA("Model") then
		return inst:GetPivot().Position
	end
	return nil
end

local function makeAtomic(tag: string, inst: Instance)
	if NO_ATOMIC[tag] or not inst:IsDescendantOf(Workspace) then
		return
	end
	local model = if inst:IsA("Model") then inst else inst:FindFirstAncestorWhichIsA("Model")
	if model and model.ModelStreamingMode == Enum.ModelStreamingMode.Default then
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end
end

function StreamingService.GetAnchors(tag: string): { Vector3 }
	local list: { Vector3 } = {}
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsDescendantOf(Workspace) then
			local position = anchorOf(inst)
			if position then
				table.insert(list, position)
			end
		end
	end
	return list
end

local function rebuild(tag: string)
	pending[tag] = nil
	local root = getFolder()
	local holder = root:FindFirstChild(tag)
	if not holder then
		local f = Instance.new("Folder")
		f.Name = tag
		f.Parent = root
		holder = f
	end
	local target = holder :: Instance
	local old = target:GetAttribute("Count")
	local list = StreamingService.GetAnchors(tag)
	for i, position in list do
		target:SetAttribute("P" .. i, position)
	end
	if typeof(old) == "number" then
		for i = #list + 1, old do
			target:SetAttribute("P" .. i, nil)
		end
	end
	target:SetAttribute("Count", #list)
end

-- Tests only: the headless client mock shares ONE instance tree between "server" and client, so a
-- simulated client stream-out looks like a server removal. Frozen = keep the published anchors.
local frozen = false
function StreamingService._Freeze(value: boolean)
	frozen = value
end

local function schedule(tag: string)
	if pending[tag] or frozen then
		return
	end
	pending[tag] = true
	task.defer(rebuild, tag)
end

function StreamingService.Track(tag: string)
	if tracked[tag] then
		return
	end
	tracked[tag] = true
	for _, inst in CollectionService:GetTagged(tag) do
		makeAtomic(tag, inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst: Instance)
		makeAtomic(tag, inst)
		schedule(tag)
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function()
		schedule(tag)
	end)
	rebuild(tag)
end

function StreamingService.Init()
	getFolder()
	for _, tag in StreamingService.ANCHOR_TAGS do
		StreamingService.Track(tag)
	end
end

return StreamingService
