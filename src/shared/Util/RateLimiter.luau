--!strict
--[[
	RateLimiter — token bucket per key (usually a Player). Pure: the clock is injectable so it
	can be unit-tested outside Roblox.

		local limiter = RateLimiter.new(10, 1) -- burst of 10, refills 10 per second
		if not limiter:Check(player) then return end
]]

export type RateLimiter = {
	Check: (self: RateLimiter, key: any, cost: number?) -> boolean,
	Remove: (self: RateLimiter, key: any) -> (),
}

type Bucket = { Tokens: number, Last: number }

local RateLimiter = {}

function RateLimiter.new(capacity: number, windowSeconds: number, clock: (() -> number)?): RateLimiter
	assert(capacity > 0 and windowSeconds > 0, "RateLimiter: capacity and window must be > 0")
	local now: () -> number = clock or os.clock
	local refillPerSecond = capacity / windowSeconds
	local buckets: { [any]: Bucket } = {}

	local self = {} :: RateLimiter

	function self.Check(_: RateLimiter, key: any, cost: number?): boolean
		local price = cost or 1
		local t = now()
		local bucket = buckets[key]
		if not bucket then
			bucket = { Tokens = capacity, Last = t }
			buckets[key] = bucket
		end
		bucket.Tokens = math.min(capacity, bucket.Tokens + (t - bucket.Last) * refillPerSecond)
		bucket.Last = t
		if bucket.Tokens >= price then
			bucket.Tokens -= price
			return true
		end
		return false
	end

	function self.Remove(_: RateLimiter, key: any)
		buckets[key] = nil
	end

	return self
end

return RateLimiter
