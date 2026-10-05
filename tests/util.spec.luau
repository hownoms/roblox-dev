--!strict
-- Pure-Luau unit tests for server-scripting Util modules (no Roblox APIs needed).
-- Run from the repo root:  ~/bin/luau tests/util.spec.luau
local Weighted = require("../src/shared/Util/Weighted")
local RateLimiter = require("../src/shared/Util/RateLimiter")
local TableUtil = require("../src/shared/Util/TableUtil")

local passed, failed = 0, 0
local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name .. ": " .. tostring(err))
	end
end
local function eq(a: any, b: any, msg: string?)
	if a ~= b then
		error(string.format("%s: expected %s, got %s", msg or "eq", tostring(b), tostring(a)), 2)
	end
end
local function near(a: number, b: number, eps: number, msg: string?)
	if math.abs(a - b) > eps then
		error(string.format("%s: expected ~%s, got %s", msg or "near", tostring(b), tostring(a)), 2)
	end
end

type E = { Id: string, W: number }
local entries: { E } = { { Id = "a", W = 70 }, { Id = "b", W = 20 }, { Id = "c", W = 10 } }
local function w(e: E): number
	return e.W
end

test("Weighted.Pick boundaries", function()
	eq((Weighted.Pick(entries, w, 0) :: E).Id, "a")
	eq((Weighted.Pick(entries, w, 0.699) :: E).Id, "a")
	eq((Weighted.Pick(entries, w, 0.7) :: E).Id, "b")
	eq((Weighted.Pick(entries, w, 0.899) :: E).Id, "b")
	eq((Weighted.Pick(entries, w, 0.95) :: E).Id, "c")
	eq((Weighted.Pick(entries, w, 1) :: E).Id, "c", "roll 1 clamps to last")
end)

test("Weighted skips invalid weights", function()
	local bad: { E } =
		{ { Id = "nan", W = 0 / 0 }, { Id = "neg", W = -5 }, { Id = "ok", W = 1 }, { Id = "inf", W = math.huge } }
	eq((Weighted.Pick(bad, w, 0.5) :: E).Id, "ok")
	eq(Weighted.Pick({} :: { E }, w, 0.5), nil)
	eq(Weighted.Pick({ { Id = "z", W = 0 } } :: { E }, w, 0.5), nil)
end)

test("Weighted luck boosts rare share", function()
	local luck = 2
	local function lucky(e: E): number
		return if e.Id == "a" then e.W else e.W * luck
	end
	local odds = Weighted.Odds(entries, lucky)
	near(odds[1], 70 / 130, 1e-9)
	near(odds[3], 20 / 130, 1e-9)
end)

test("Weighted distribution", function()
	math.randomseed(42)
	local counts = { a = 0, b = 0, c = 0 }
	for _ = 1, 20000 do
		local e = Weighted.Pick(entries, w, math.random()) :: E
		counts[e.Id] += 1
	end
	near(counts.a / 20000, 0.7, 0.02)
	near(counts.c / 20000, 0.1, 0.02)
end)

test("RateLimiter token bucket", function()
	local t = 0
	local limiter = RateLimiter.new(3, 1, function()
		return t
	end)
	eq(limiter:Check("p"), true)
	eq(limiter:Check("p"), true)
	eq(limiter:Check("p"), true)
	eq(limiter:Check("p"), false, "burst exhausted")
	eq(limiter:Check("q"), true, "keys independent")
	t = 0.34
	eq(limiter:Check("p"), true, "refilled one token")
	eq(limiter:Check("p"), false)
	t = 100
	eq(limiter:Check("p"), true)
	limiter:Remove("p")
	eq(limiter:Check("p"), true)
end)

test("TableUtil.Reconcile fills and repairs", function()
	local template = { Coins = 0, Owned = { toy = true }, Settings = {}, Name = "x" }
	local saved: any = { Coins = 0 / 0, Owned = { spade = true }, Name = 5, Extra = 1 }
	TableUtil.Reconcile(saved, template)
	eq(saved.Coins, 0, "NaN repaired")
	eq(saved.Owned.toy, true, "nested default added")
	eq(saved.Owned.spade, true, "existing kept")
	eq(saved.Name, "x", "wrong type replaced")
	eq(saved.Extra, 1, "unknown keys kept")
	eq(type(saved.Settings), "table")
	saved.Settings.a = 1
	eq(next(template.Settings), nil, "defaults are copied, not shared")
end)

test("TableUtil.DeepCopy / Count", function()
	local src = { a = { b = { c = 1 } } }
	local copy = TableUtil.DeepCopy(src)
	copy.a.b.c = 2
	eq(src.a.b.c, 1)
	eq(TableUtil.Count({ x = 1, y = 2, z = 3 }), 3)
end)

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	error("tests failed")
end
