--!strict
--[[
	Ride — tuning for the ride-on excavator (v2.1, Ride agent). A player who owns a pet with
	PetDef.Rideable = true can press Ride (V / DPadUp / the Ride button) to spawn a full-size
	vehicle (Models/Rides.luau), sit in it, drive it around the beach and dig big chunks in front
	of it. Server: Services/RideService.luau. Client: Controllers/RideController.luau,
	UI/RideButton.luau. Physics and hole handling: see the RideService header.

	All distances in studs, speeds in studs/s, angles in radians. Expect to tune in Studio.
]]

local Ride = {
	-- Driving (client, applied through AlignPosition / AlignOrientation on the rider's machine)
	MaxSpeed = 18, -- forward top speed
	ReverseFactor = 0.6, -- reverse top speed = MaxSpeed * this
	Acceleration = 26, -- studs/s^2 towards the target speed (also braking)
	TurnRate = 1.6, -- yaw rate at full stick (~92 degrees/s)
	HoverHeight = 0.15, -- pivot (bottom of the tracks) above the ground under the tracks
	Responsiveness = 35, -- AlignPosition / AlignOrientation responsiveness
	ForceGravities = 6, -- AlignPosition MaxForce = assembly weight x this (enough to climb the deck)

	-- Area: the dig zone plus the boardwalk. The vehicle centre is clamped to
	-- x in [zone min + EdgeMargin, zone max - EdgeMargin], z in [zone sea edge + EdgeMargin, InlandMaxZ].
	EdgeMargin = 7,
	InlandMaxZ = 4, -- boardwalk deck is z -4..12; the vehicle's back stays on the deck
	SpawnMaxDistance = 40, -- the player must be this close to the ride area to call the vehicle
	-- Ground (mirrors World/Layout: BOARDWALK_Z0 = -4, DECK_TOP = SURFACE_Y + 1). On the sand the
	-- tracks follow the terrain (raycast) but never sink below SURFACE_Y: holes are bridged.
	DeckSeaEdgeZ = -4,
	DeckTop = 1, -- above Config.SURFACE_Y
	TrackSamples = { -- model-space (x, z) points under the tracks sampled for the ground height
		Vector2.new(-3.5, -5.5),
		Vector2.new(3.5, -5.5),
		Vector2.new(-3.5, 5.5),
		Vector2.new(3.5, 5.5),
		Vector2.new(0, 0),
	},

	-- Digging
	DigAhead = 11, -- studs in front of the vehicle pivot where the bucket scoops
	MaxDigDepth = 40, -- the bucket only reaches this far below the surface (drive on to dig more)
	MinRadius = 6, -- dig radius at least this (12-stud cube, like a top shovel)
	IntervalLeniency = 0.85, -- server accepts RideDig after Dig.Interval * this (latency slack)

	-- Server anti-cheat (position checks every ValidateInterval seconds)
	ValidateInterval = 0.5,
	SpeedTolerance = 1.6, -- allowed horizontal speed = MaxSpeed * this + SpeedSlack
	SpeedSlack = 8,
	MinY = -6, -- relative to Config.SURFACE_Y (the vehicle never drives into holes)
	MaxY = 14,
	MaxStrikes = 3, -- resets in a row before the vehicle is despawned
	SeatTimeout = 3, -- despawn when the rider was never seated after this many seconds
}

return Ride
