--!strict
--[[
	Tagged (v2.3): streaming-safe CollectionService watchers for the client.

	With Workspace.StreamingEnabled a tagged part may not exist when a controller starts, may
	stream in later, may stream OUT (the client's copy is removed) and come back as a NEW instance.
	Rules this module enforces:
	  - never assume a tagged instance exists at start: existing + InstanceAdded are both handled;
	  - InstanceRemoved (and Destroying / leaving the DataModel) runs the cleanup, so connections
	    made for a streamed-out instance are disconnected and nothing keeps a dead reference;
	  - lookups (Nearest) only return instances that are currently in the Workspace.

	API
	  Tagged.Watch(tag, onAdded) -> stop()
	      onAdded(inst) may return a cleanup function, called once when inst goes away.
	  Tagged.WatchPrompts(tag, onTriggered) -> stop()
	      onTriggered(inst, prompt) for every ProximityPrompt in or under a tagged instance,
	      including prompts that arrive after the part (streaming order is not guaranteed).
	  Tagged.Nearest(tag, from?) -> BasePart?
	      nearest streamed-in BasePart with the tag (or the PrimaryPart / first part of a tagged
	      Model). For something far away use Util/Anchors, whose positions are always present.
]]
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Tagged = {}

export type Cleanup = () -> ()

function Tagged.Watch(tag: string, onAdded: (inst: Instance) -> Cleanup?): () -> ()
	local cleanups: { [Instance]: Cleanup | boolean } = {}
	local connections: { RBXScriptConnection } = {}

	local function remove(inst: Instance)
		local cleanup = cleanups[inst]
		if cleanup == nil then
			return
		end
		cleanups[inst] = nil
		if type(cleanup) == "function" then
			local fn = cleanup :: Cleanup
			local ok, err = pcall(function()
				fn()
			end)
			if not ok then
				warn("[Tagged] cleanup failed for " .. tag .. ": " .. tostring(err))
			end
		end
	end

	local function add(inst: Instance)
		if cleanups[inst] ~= nil then
			return
		end
		cleanups[inst] = true -- reserve: onAdded may yield
		local ok, result = pcall(onAdded, inst)
		if not ok then
			warn("[Tagged] " .. tag .. " handler failed: " .. tostring(result))
		end
		if cleanups[inst] == nil then
			-- removed while the handler ran
			if ok and type(result) == "function" then
				pcall(result)
			end
			return
		end
		cleanups[inst] = if ok and type(result) == "function" then result else true
	end

	table.insert(connections, CollectionService:GetInstanceAddedSignal(tag):Connect(add))
	table.insert(connections, CollectionService:GetInstanceRemovedSignal(tag):Connect(remove))
	for _, inst in CollectionService:GetTagged(tag) do
		task.spawn(add, inst)
	end

	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		local list = {}
		for inst in cleanups do
			table.insert(list, inst)
		end
		for _, inst in list do
			remove(inst)
		end
	end
end

function Tagged.WatchPrompts(tag: string, onTriggered: (inst: Instance, prompt: ProximityPrompt) -> ()): () -> ()
	return Tagged.Watch(tag, function(inst: Instance): Cleanup?
		local connections: { RBXScriptConnection } = {}
		local hooked: { [ProximityPrompt]: boolean } = {}
		local function hook(prompt: ProximityPrompt)
			if hooked[prompt] then
				return
			end
			hooked[prompt] = true
			table.insert(
				connections,
				prompt.Triggered:Connect(function()
					onTriggered(inst, prompt)
				end)
			)
		end
		if inst:IsA("ProximityPrompt") then
			hook(inst)
		else
			for _, d in inst:GetDescendants() do
				if d:IsA("ProximityPrompt") then
					hook(d)
				end
			end
			table.insert(
				connections,
				inst.DescendantAdded:Connect(function(d: Instance)
					if d:IsA("ProximityPrompt") then
						hook(d)
					end
				end)
			)
		end
		return function()
			for _, connection in connections do
				connection:Disconnect()
			end
			table.clear(connections)
			table.clear(hooked)
		end
	end)
end

-- The part to aim at for a tagged instance (BasePart, or a tagged Model's PrimaryPart / first part).
function Tagged.PartOf(inst: Instance): BasePart?
	if inst:IsA("BasePart") then
		return inst
	elseif inst:IsA("Model") then
		return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

function Tagged.Nearest(tag: string, from: Vector3?): BasePart?
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, inst in CollectionService:GetTagged(tag) do
		if not inst:IsDescendantOf(Workspace) then
			continue
		end
		local part = Tagged.PartOf(inst)
		if part then
			local distance = if from then (part.Position - from).Magnitude else 0
			if distance < bestDistance then
				best = part
				bestDistance = distance
			end
		end
	end
	return best
end

return Tagged
