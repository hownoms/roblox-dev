--!strict
--[[
	AdventureBoot — the one production entry point for the expansion adventure. Main lists it as
	a service; with every AdventureFlags flag OFF (the shipped default) Start() returns at once:
	no adventure module is even required, nothing is built, no remote or tool exists.

	SpringVault ON:
	  * Places the arena in POCKET_ORIGIN: an empty void under the 16-stud land slab, inland of the
	    dig strip and outside every dig/protected footprint (validated here; refuses to start
	    otherwise). No terrain is written.
	  * Removes the review scene's Neutral SpawnLocation (otherwise Roblox would spawn ~1 in 4
	    players inside the arena; review H1), including in every scene rebuilt after a run.
	  * AdventureEntry: surface hatch in, return pad out, safe returns, pocket lighting rig.
	  * SpringVaultService.Start({ Origin, CanEnter, CanTrial, OnStage, OnCompletion,
	    OnOrdinaryBroadwave }) with the AdventureEligibility callbacks.
	AdventureRewards ON: OnStage/OnCompletion = AdventureSettlement's durable bridge (enabled).
	  OFF: settlement is disabled and the completion callback refuses truthfully.
	BroadwaveOrdinary ON: OnOrdinaryBroadwave = BroadwaveDigBridge.Create({ CanUse =
	  AdventureEligibility.CanUseBroadwave, Dig = DigService.DigBroadwave }) and licensed tools are
	  issued (BroadwaveLicense). OFF: no ordinary adapter is passed at all, so the runtime keeps its
	  event/trial-only Broadwave gating.

	Disable() is the in-server kill switch (docs/integration/production-wiring.md).
]]

local Workspace = game:GetService("Workspace")

local Flags = require(script.Parent.AdventureFlags)
local Eligibility = require(script.Parent.AdventureEligibility)
local BroadwaveLicense = require(script.Parent.BroadwaveLicense)
local AdventureSettlement = require(script.Parent.AdventureSettlement)
local AdventureEntry = require(script.Parent.AdventureEntry)
local DigService = require(script.Parent.DigService)
local World = require(script.Parent.Parent.World)
local Layout = require(script.Parent.Parent.World.Layout)

local AdventureBoot = {}

--[[
	The arena (SpringVaultScene) spans Origin + X[-50, 50], Y[-2, +11], Z[-106, +34]. With this
	origin that is X[-250, -150], Y[968, 981], Z[0, 140]:
	  * under the land slab (terrain Y 1008..1024) and its dune balls (lowest ~Y 990);
	  * inland of the underground strip (terrain/walls only at Z <= 0) and the dig zone (Z -8..-64);
	  * south of the backdrop hills (Z >= 140) and below the north boundary wall (Y >= 994);
	  * far from the trophy camp pad (World.IsProtected).
	production-wiring.spec checks the box is free of map parts and terrain voxels.
]]
AdventureBoot.POCKET_ORIGIN = Vector3.new(-200, Layout.SURFACE_Y - 54, 106)
AdventureBoot.POCKET_MIN = Vector3.new(-50, -2, -106)
AdventureBoot.POCKET_MAX = Vector3.new(50, 11, 34)

local runtime: any = nil
local guards: { RBXScriptConnection } = {}

local function pocketCorners(origin: Vector3): { Vector3 }
	local a, b = origin + AdventureBoot.POCKET_MIN, origin + AdventureBoot.POCKET_MAX
	local out = {}
	for _, x in { a.X, b.X } do
		for _, y in { a.Y, b.Y } do
			for _, z in { a.Z, b.Z } do
				table.insert(out, Vector3.new(x, y, z))
			end
		end
	end
	return out
end

-- The pocket must never overlap ordinary digging or a protected footprint.
function AdventureBoot.PocketIsSafe(origin: Vector3): boolean
	for _, corner in pocketCorners(origin) do
		if World.IsInDigZone(corner) or World.IsProtected(corner, 8) then
			return false
		end
	end
	local a, b = origin + AdventureBoot.POCKET_MIN, origin + AdventureBoot.POCKET_MAX
	local zone = Layout.DIG_CENTER
	-- Box-vs-box against the dig zone (corners alone miss a zone crossing the middle).
	local overlapX = a.X <= zone.X + Layout.DIG_HALF_X and b.X >= zone.X - Layout.DIG_HALF_X
	local overlapZ = a.Z <= Layout.DIG_Z_INLAND and b.Z >= Layout.DIG_Z_SEA
	return not (overlapX and overlapZ)
end

-- The review scene's SpawnLocation (nothing in the runtime references it) must never be a
-- spawn in production: neutralised at once, destroyed on the next resumption point (a Destroy
-- inside DescendantAdded would re-parent mid parent-change).
local function removeSpawn(d: Instance)
	if d:IsA("SpawnLocation") then
		d.Enabled = false
		d.Neutral = false
		d.AllowTeamChangeOnTouch = false
		task.defer(function()
			d:Destroy()
		end)
	end
end

local function guardScene()
	local function hook(child: Instance)
		if child.Name == "SpringVaultAdventure" and child:IsA("Model") then
			for _, d in child:GetDescendants() do
				removeSpawn(d)
			end
			table.insert(guards, child.DescendantAdded:Connect(removeSpawn))
		end
	end
	table.insert(guards, Workspace.ChildAdded:Connect(hook))
	for _, child in Workspace:GetChildren() do
		hook(child)
	end
end

local function refuseCompletion(_context: any): (boolean, string)
	return false, "Adventure complete. Rewards are not enabled on this server."
end

-- Builds the SpringVaultService options. Exposed for the wiring spec.
function AdventureBoot.Options(flags: any): any
	local options: any = {
		Origin = AdventureBoot.POCKET_ORIGIN,
		CanEnter = Eligibility.CanEnter,
		CanTrial = Eligibility.CanTrial,
		-- Runtime restores (Leave, reset, disconnect, Destroy) land on the fixed surface point
		-- beside the hatch, never the recorded in-arena join frame or a client position.
		ReturnFrame = function(_player: Player): CFrame?
			return AdventureEntry.SURFACE_RETURN
		end,
	}
	if flags.AdventureRewards then
		options.OnStage = AdventureSettlement.OnStage
		options.OnCompletion = AdventureSettlement.OnCompletion
		-- Each player's reward result is the AdventureOutcome card (settlement-outcomes.md).
		-- Requested runtime option (blocker B1 there): with it, the runtime drops its own
		-- "Review only / no permanent rewards" copy. Inert until the runtime reads it.
		options.OutcomeOwner = "External"
	else
		options.OnCompletion = refuseCompletion
	end
	if flags.BroadwaveOrdinary then
		local Adventure = script.Parent.Parent:FindFirstChild("Adventure")
		local bridgeModule = Adventure and Adventure:FindFirstChild("BroadwaveDigBridge")
		local dig = (DigService :: any).DigBroadwave
		if bridgeModule and type(dig) == "function" then
			local Bridge = (require :: any)(bridgeModule)
			options.OnOrdinaryBroadwave = Bridge.Create({
				CanUse = Eligibility.CanUseBroadwave,
				Dig = dig,
			})
			-- Licensed-tool charges (docs/integration/licensed-broadwave.md): the equipped tool this
			-- server issued, re-checked against CanUseBroadwave, or nil. Only such a tool may reach
			-- OnOrdinaryBroadwave; the runtime's own loans stay event/trial only.
			options.ResolveTool = BroadwaveLicense.ResolveTool
		else
			warn("[AdventureBoot] BroadwaveOrdinary is on but BroadwaveDigBridge/DigBroadwave is missing")
		end
	end
	return options
end

function AdventureBoot.Start()
	Eligibility.SetOrdinaryEnabled(false)
	if not Flags.SpringVault then
		return
	end
	if runtime then
		return
	end
	if not AdventureBoot.PocketIsSafe(AdventureBoot.POCKET_ORIGIN) then
		warn("[AdventureBoot] adventure pocket overlaps digging or a protected footprint; not started")
		return
	end
	local Adventure = script.Parent.Parent:FindFirstChild("Adventure")
	local serviceModule = Adventure and Adventure:FindFirstChild("SpringVaultService")
	if not serviceModule then
		warn("[AdventureBoot] SpringVaultService missing; not started")
		return
	end
	AdventureSettlement.SetEnabled(Flags.AdventureRewards == true)
	local options = AdventureBoot.Options(Flags)
	if options.OnOrdinaryBroadwave then
		Eligibility.SetOrdinaryEnabled(true)
		BroadwaveLicense.Start()
	end
	guardScene()
	local SpringVaultService = (require :: any)(serviceModule)
	local ok, result = pcall(SpringVaultService.Start, options)
	if ok then
		runtime = result
		AdventureEntry.Start(result, AdventureBoot.POCKET_ORIGIN)
	else
		warn("[AdventureBoot] SpringVaultService.Start failed: " .. tostring(result))
		AdventureBoot.Disable()
	end
end

-- In-server kill switch: stops the runtime (restores loans/positions/speeds), returns everyone in
-- the pocket to the surface, refuses new
-- settlements, removes licensed tools. Accepted grants stay owned; outbox drains continue.
function AdventureBoot.Disable()
	Eligibility.SetOrdinaryEnabled(false)
	BroadwaveLicense.Stop()
	if runtime then
		local r = runtime
		runtime = nil
		pcall(r.Destroy)
		AdventureSettlement.SetEnabled(false)
	end
	-- After Destroy (which restores joined players into the arena, then removes it): lift
	-- everyone still under the slab to the beach in the same frame.
	AdventureEntry.Stop()
	for _, c in guards do
		c:Disconnect()
	end
	table.clear(guards)
end

function AdventureBoot.Runtime(): any
	return runtime
end

return AdventureBoot
