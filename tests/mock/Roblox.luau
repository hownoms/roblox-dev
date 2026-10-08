--!nocheck
--[[
	Headless Roblox engine mock for the smoke test. Good enough to boot the real server code
	(Main.server.luau + Services + World + Shared) under the plain `luau` CLI.

	Fidelity goals (things that only fail at runtime in a live server):
	  * Instance.new rejects unknown classes; reads/writes of unknown members error like the
	    engine ("X is not a valid member of Y"); writes to NotScriptable/ReadOnly/secured
	    properties error (tests/mock/ApiRestrictions.luau); primitive property types are checked.
	  * Enum.<Type>.<Item> is validated against the API definitions.
	  * Attributes only accept attribute-able types (no tables / Instances).
	  * Remote arguments are checked for what the network layer can't send (mixed tables,
	    non-string dictionary keys, sparse arrays, functions, NaN keys...).
	  * DataStore values must be JSON-able (no Vector3/CFrame/Color3/Instances, no NaN/inf,
	    no mixed tables) and keys/values sized within limits.
	  * Terrain: real 4-stud voxel grid (material + occupancy) so digging, ReadVoxels and
	    refills are observable; SetMaterialColor only for terrain materials; FillBlock region
	    size limit.
	  * Cooperative scheduler with a virtual clock (task.*, os.clock, os.time, Heartbeat).
	Everything else is a permissive stand-in.
]]

local Mock = {}

local G -- generated data (classes, enums, sources)
local Restrictions = require("./ApiRestrictions")

-- Diagnostics -------------------------------------------------------------------------------

Mock.Errors = {} -- uncaught errors in threads
Mock.Warnings = {} -- warn() output
Mock.Prints = {}
Mock.Verbose = false

local function record(list, text)
	table.insert(list, text)
end

local realPrint = print
local function mockWarn(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	local text = table.concat(parts, " ")
	record(Mock.Warnings, text)
	if Mock.Verbose then
		realPrint("  [warn] " .. text)
	end
end
local function mockPrint(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	local text = table.concat(parts, " ")
	record(Mock.Prints, text)
	if Mock.Verbose then
		realPrint("  [print] " .. text)
	end
end

-- Scheduler (virtual clock) -----------------------------------------------------------------

local FRAME = 1 / 30
local clock = 1000 -- os.clock()
local EPOCH = 1_790_000_000 -- os.time() at clock 1000
local queue = {} -- { At, Seq, Thread, Args }
local seq = 0

local function resume(thread, ...)
	if coroutine.status(thread) == "dead" then
		return
	end
	local ok, err = coroutine.resume(thread, ...)
	if not ok then
		local trace = debug.traceback(thread, tostring(err))
		record(Mock.Errors, trace)
		realPrint("  [ERROR] " .. trace)
	end
end

local function schedule(at, thread, ...)
	seq += 1
	table.insert(queue, { At = at, Seq = seq, Thread = thread, Args = table.pack(...) })
end

local task = {}
function task.spawn(fn, ...)
	local thread = if type(fn) == "thread" then fn else coroutine.create(fn)
	resume(thread, ...)
	return thread
end
function task.defer(fn, ...)
	local thread = if type(fn) == "thread" then fn else coroutine.create(fn)
	schedule(clock, thread, ...)
	return thread
end
function task.delay(t, fn, ...)
	local thread = if type(fn) == "thread" then fn else coroutine.create(fn)
	schedule(clock + (t or 0), thread, ...)
	return thread
end
function task.wait(t)
	local start = clock
	assert(coroutine.isyieldable(), "task.wait called from a non-yieldable context")
	schedule(clock + math.max(t or 0, FRAME), coroutine.running())
	coroutine.yield()
	return clock - start
end
function task.cancel(thread)
	for i = #queue, 1, -1 do
		if queue[i].Thread == thread then
			table.remove(queue, i)
		end
	end
	pcall(coroutine.close, thread)
end
function task.synchronize() end
function task.desynchronize() end

local heartbeatFire -- set below

-- Runs everything due within `seconds` of virtual time, frame by frame.
function Mock.Advance(seconds)
	local target = clock + seconds
	repeat
		local frameEnd = math.min(clock + FRAME, target)
		-- run due threads (including ones scheduled while running, if due)
		while true do
			local bestIndex = nil
			for i, item in queue do
				if item.At <= frameEnd + 1e-9 then
					if
						bestIndex == nil
						or item.At < queue[bestIndex].At
						or (item.At == queue[bestIndex].At and item.Seq < queue[bestIndex].Seq)
					then
						bestIndex = i
					end
				end
			end
			if not bestIndex then
				break
			end
			local item = table.remove(queue, bestIndex)
			if item.At > clock then
				clock = item.At
			end
			resume(item.Thread, table.unpack(item.Args, 1, item.Args.n))
		end
		clock = frameEnd
		if heartbeatFire then
			heartbeatFire(FRAME)
		end
	until clock >= target - 1e-9
end

function Mock.Now()
	return clock
end

local mockOs = setmetatable({
	clock = function()
		return clock
	end,
	time = function(t)
		if t then
			return os.time(t)
		end
		return math.floor(EPOCH + clock - 1000)
	end,
}, { __index = os })

-- Datatypes ---------------------------------------------------------------------------------

local typeTags = setmetatable({}, { __mode = "k" }) -- value -> typeof name

local function tag(v, name)
	typeTags[v] = name
	return v
end

local V3 = {}
local Vector3 = {}
local function v3(x, y, z)
	return tag(setmetatable({ X = x, Y = y, Z = z }, V3), "Vector3")
end
local function isV3(v)
	return getmetatable(v) == V3
end
V3.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		if m == 0 then
			return v3(0 / 0, 0 / 0, 0 / 0)
		end
		return v3(v.X / m, v.Y / m, v.Z / m)
	end
	local method = V3[k]
	if method == nil then
		error(tostring(k) .. " is not a valid member of Vector3", 2)
	end
	return method
end
V3.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return v3(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__idiv = function(a, b)
	if type(b) == "number" then
		return v3(a.X // b, a.Y // b, a.Z // b)
	end
	return v3(a.X // b.X, a.Y // b.Y, a.Z // b.Z)
end
V3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3.__tostring = function(v)
	return string.format("%g, %g, %g", v.X, v.Y, v.Z)
end
function V3.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
function V3.Cross(a, b)
	return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function V3.Lerp(a, b, t)
	return v3(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t)
end
function V3.Abs(a)
	return v3(math.abs(a.X), math.abs(a.Y), math.abs(a.Z))
end
function V3.Floor(a)
	return v3(math.floor(a.X), math.floor(a.Y), math.floor(a.Z))
end
function V3.Ceil(a)
	return v3(math.ceil(a.X), math.ceil(a.Y), math.ceil(a.Z))
end
function V3.Min(a, b)
	return v3(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
end
function V3.Max(a, b)
	return v3(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
end
function V3.FuzzyEq(a, b, eps)
	return (a - b).Magnitude <= (eps or 1e-5)
end
function V3.Angle(a, b)
	return math.acos(math.clamp(a.Unit:Dot(b.Unit), -1, 1))
end
function Vector3.new(x, y, z)
	return v3(x or 0, y or 0, z or 0)
end
function Vector3.FromNormalId()
	return v3(0, 1, 0)
end
Vector3.zero = v3(0, 0, 0)
Vector3.one = v3(1, 1, 1)
Vector3.xAxis = v3(1, 0, 0)
Vector3.yAxis = v3(0, 1, 0)
Vector3.zAxis = v3(0, 0, 1)

local V2 = {}
local Vector2 = {}
local function v2(x, y)
	return tag(setmetatable({ X = x, Y = y }, V2), "Vector2")
end
V2.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y)
		return v2(v.X / m, v.Y / m)
	end
	return V2[k]
end
V2.__add = function(a, b)
	return v2(a.X + b.X, a.Y + b.Y)
end
V2.__sub = function(a, b)
	return v2(a.X - b.X, a.Y - b.Y)
end
V2.__mul = function(a, b)
	if type(a) == "number" then
		return v2(a * b.X, a * b.Y)
	elseif type(b) == "number" then
		return v2(a.X * b, a.Y * b)
	end
	return v2(a.X * b.X, a.Y * b.Y)
end
V2.__div = function(a, b)
	if type(b) == "number" then
		return v2(a.X / b, a.Y / b)
	end
	return v2(a.X / b.X, a.Y / b.Y)
end
V2.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
function V2.Lerp(a, b, t)
	return a + (b - a) * t
end
function V2.Dot(a, b)
	return a.X * b.X + a.Y * b.Y
end
function Vector2.new(x, y)
	return v2(x or 0, y or 0)
end
Vector2.zero = v2(0, 0)
Vector2.one = v2(1, 1)

-- CFrame: position + 3x3 rotation (row-major r[1..9]); columns = Right, Up, Back.
local CF = {}
local CFrame = {}
local function cf(px, py, pz, r)
	return tag(setmetatable({ px, py, pz, r }, CF), "CFrame")
end
local IDENT = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function isCF(v)
	return getmetatable(v) == CF
end
local function rotMul(a, b)
	return {
		a[1] * b[1] + a[2] * b[4] + a[3] * b[7],
		a[1] * b[2] + a[2] * b[5] + a[3] * b[8],
		a[1] * b[3] + a[2] * b[6] + a[3] * b[9],
		a[4] * b[1] + a[5] * b[4] + a[6] * b[7],
		a[4] * b[2] + a[5] * b[5] + a[6] * b[8],
		a[4] * b[3] + a[5] * b[6] + a[6] * b[9],
		a[7] * b[1] + a[8] * b[4] + a[9] * b[7],
		a[7] * b[2] + a[8] * b[5] + a[9] * b[8],
		a[7] * b[3] + a[8] * b[6] + a[9] * b[9],
	}
end
local function rotVec(r, x, y, z)
	return r[1] * x + r[2] * y + r[3] * z, r[4] * x + r[5] * y + r[6] * z, r[7] * x + r[8] * y + r[9] * z
end
local function transpose(r)
	return { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] }
end
CF.__index = function(c, k)
	local r = c[4]
	if k == "Position" or k == "p" then
		return v3(c[1], c[2], c[3])
	elseif k == "X" then
		return c[1]
	elseif k == "Y" then
		return c[2]
	elseif k == "Z" then
		return c[3]
	elseif k == "Rotation" then
		return cf(0, 0, 0, r)
	elseif k == "LookVector" then
		return v3(-r[3], -r[6], -r[9])
	elseif k == "RightVector" or k == "XVector" then
		return v3(r[1], r[4], r[7])
	elseif k == "UpVector" or k == "YVector" then
		return v3(r[2], r[5], r[8])
	elseif k == "ZVector" then
		return v3(r[3], r[6], r[9])
	end
	local method = CF[k]
	if method == nil then
		error(tostring(k) .. " is not a valid member of CFrame", 2)
	end
	return method
end
CF.__mul = function(a, b)
	if isV3(b) then
		local x, y, z = rotVec(a[4], b.X, b.Y, b.Z)
		return v3(a[1] + x, a[2] + y, a[3] + z)
	end
	assert(isCF(b), "CFrame * expects CFrame or Vector3")
	local x, y, z = rotVec(a[4], b[1], b[2], b[3])
	return cf(a[1] + x, a[2] + y, a[3] + z, rotMul(a[4], b[4]))
end
CF.__add = function(a, v)
	assert(isV3(v), "CFrame + expects Vector3")
	return cf(a[1] + v.X, a[2] + v.Y, a[3] + v.Z, a[4])
end
CF.__sub = function(a, v)
	assert(isV3(v), "CFrame - expects Vector3")
	return cf(a[1] - v.X, a[2] - v.Y, a[3] - v.Z, a[4])
end
CF.__eq = function(a, b)
	if a[1] ~= b[1] or a[2] ~= b[2] or a[3] ~= b[3] then
		return false
	end
	for i = 1, 9 do
		if a[4][i] ~= b[4][i] then
			return false
		end
	end
	return true
end
CF.__tostring = function(c)
	return string.format("CFrame(%g, %g, %g)", c[1], c[2], c[3])
end
function CF.Inverse(c)
	local t = transpose(c[4])
	local x, y, z = rotVec(t, c[1], c[2], c[3])
	return cf(-x, -y, -z, t)
end
function CF.ToObjectSpace(a, b)
	return a:Inverse() * b
end
function CF.ToWorldSpace(a, b)
	return a * b
end
function CF.PointToObjectSpace(a, v)
	return a:Inverse() * v
end
function CF.PointToWorldSpace(a, v)
	return a * v
end
function CF.VectorToWorldSpace(a, v)
	local x, y, z = rotVec(a[4], v.X, v.Y, v.Z)
	return v3(x, y, z)
end
function CF.VectorToObjectSpace(a, v)
	local x, y, z = rotVec(transpose(a[4]), v.X, v.Y, v.Z)
	return v3(x, y, z)
end
function CF.Lerp(a, b, t)
	local r = if t < 0.5 then a[4] else b[4]
	return cf(a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, r)
end
function CF.GetComponents(c)
	local r = c[4]
	return c[1], c[2], c[3], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9]
end
CF.components = CF.GetComponents
function CF.ToEulerAnglesXYZ(c)
	local r = c[4]
	local y = math.asin(math.clamp(r[3], -1, 1))
	local x = math.atan2(-r[6], r[9])
	local z = math.atan2(-r[2], r[1])
	return x, y, z
end
function CF.ToOrientation(c)
	local r = c[4]
	local x = math.asin(math.clamp(-r[6], -1, 1))
	local y = math.atan2(r[3], r[9])
	local z = math.atan2(r[4], r[5])
	return x, y, z
end
function CF.ToAxisAngle(_c)
	return v3(0, 1, 0), 0
end
function CF.Orthonormalize(c)
	return c
end
function CF.FuzzyEq(a, b, eps)
	return (a.Position - b.Position).Magnitude <= (eps or 1e-5)
end

local function rx(t)
	local c, s = math.cos(t), math.sin(t)
	return { 1, 0, 0, 0, c, -s, 0, s, c }
end
local function ry(t)
	local c, s = math.cos(t), math.sin(t)
	return { c, 0, s, 0, 1, 0, -s, 0, c }
end
local function rz(t)
	local c, s = math.cos(t), math.sin(t)
	return { c, -s, 0, s, c, 0, 0, 0, 1 }
end
local function fromColumns(px, py, pz, x, y, z)
	return cf(px, py, pz, { x.X, y.X, z.X, x.Y, y.Y, z.Y, x.Z, y.Z, z.Z })
end
local function lookAt(at, target, up)
	up = up or Vector3.yAxis
	local diff = target - at
	if diff.Magnitude < 1e-9 then
		return cf(at.X, at.Y, at.Z, IDENT)
	end
	local zAxis = -diff.Unit
	local xAxis = up:Cross(zAxis)
	if xAxis.Magnitude < 1e-6 then
		xAxis = Vector3.new(0, 0, 1):Cross(zAxis)
	end
	xAxis = xAxis.Unit
	local yAxis = zAxis:Cross(xAxis).Unit
	return fromColumns(at.X, at.Y, at.Z, xAxis, yAxis, zAxis)
end
function CFrame.new(a, b, c, ...)
	if a == nil then
		return cf(0, 0, 0, IDENT)
	elseif isV3(a) then
		if b ~= nil then
			return lookAt(a, b)
		end
		return cf(a.X, a.Y, a.Z, IDENT)
	end
	local n = select("#", ...)
	if n == 9 then
		local r = { ... }
		return cf(a, b, c, r)
	elseif n == 4 then
		local qx, qy, qz, qw = ...
		local m = math.sqrt(qx * qx + qy * qy + qz * qz + qw * qw)
		qx, qy, qz, qw = qx / m, qy / m, qz / m, qw / m
		return cf(a, b, c, {
			1 - 2 * (qy * qy + qz * qz),
			2 * (qx * qy - qz * qw),
			2 * (qx * qz + qy * qw),
			2 * (qx * qy + qz * qw),
			1 - 2 * (qx * qx + qz * qz),
			2 * (qy * qz - qx * qw),
			2 * (qx * qz - qy * qw),
			2 * (qy * qz + qx * qw),
			1 - 2 * (qx * qx + qy * qy),
		})
	end
	assert(type(a) == "number" and type(b) == "number" and type(c) == "number", "CFrame.new: bad arguments")
	return cf(a, b, c, IDENT)
end
function CFrame.Angles(x, y, z)
	return cf(0, 0, 0, rotMul(rotMul(rx(x or 0), ry(y or 0)), rz(z or 0)))
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.fromEulerAnglesYXZ(x, y, z)
	return cf(0, 0, 0, rotMul(rotMul(ry(y or 0), rx(x or 0)), rz(z or 0)))
end
CFrame.fromOrientation = CFrame.fromEulerAnglesYXZ
function CFrame.fromAxisAngle(axis, angle)
	local u = axis.Unit
	local c, s = math.cos(angle), math.sin(angle)
	local t = 1 - c
	local x, y, z = u.X, u.Y, u.Z
	return cf(0, 0, 0, {
		t * x * x + c,
		t * x * y - s * z,
		t * x * z + s * y,
		t * x * y + s * z,
		t * y * y + c,
		t * y * z - s * x,
		t * x * z - s * y,
		t * y * z + s * x,
		t * z * z + c,
	})
end
function CFrame.lookAt(at, target, up)
	return lookAt(at, target, up)
end
function CFrame.lookAlong(at, dir, up)
	return lookAt(at, at + dir, up)
end
function CFrame.fromMatrix(pos, x, y, z)
	z = z or x:Cross(y).Unit
	return fromColumns(pos.X, pos.Y, pos.Z, x, y, z)
end
CFrame.identity = cf(0, 0, 0, IDENT)

local C3 = {}
C3.__index = C3
C3.__eq = function(a, b)
	return a.R == b.R and a.G == b.G and a.B == b.B
end
C3.__tostring = function(c)
	return string.format("%g, %g, %g", c.R, c.G, c.B)
end
local Color3 = {}
local function c3(r, g, b)
	return tag(setmetatable({ R = r, G = g, B = b }, C3), "Color3")
end
function Color3.new(r, g, b)
	return c3(r or 0, g or 0, b or 0)
end
function Color3.fromRGB(r, g, b)
	return c3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end
function Color3.fromHSV(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	local m = i % 6
	if m == 0 then
		return c3(v, t, p)
	elseif m == 1 then
		return c3(q, v, p)
	elseif m == 2 then
		return c3(p, v, t)
	elseif m == 3 then
		return c3(p, q, v)
	elseif m == 4 then
		return c3(t, p, v)
	end
	return c3(v, p, q)
end
function Color3.fromHex(hex)
	hex = string.gsub(hex, "#", "")
	return Color3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
end
function C3.Lerp(a, b, t)
	return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
function C3.ToHSV(c)
	local max, min = math.max(c.R, c.G, c.B), math.min(c.R, c.G, c.B)
	local d = max - min
	local h = 0
	if d > 0 then
		if max == c.R then
			h = ((c.G - c.B) / d) % 6
		elseif max == c.G then
			h = (c.B - c.R) / d + 2
		else
			h = (c.R - c.G) / d + 4
		end
		h /= 6
	end
	return h, if max == 0 then 0 else d / max, max
end
function C3.ToHex(c)
	return string.format("%02X%02X%02X", c.R * 255, c.G * 255, c.B * 255)
end

local function simpleType(name, fields)
	local T = {}
	function T.new(...)
		local v = { ... }
		for i, f in fields do
			v[f] = v[i]
		end
		return tag(v, name)
	end
	return T
end

local UDim = simpleType("UDim", { "Scale", "Offset" })
local UDim2 = {}
function UDim2.new(xs, xo, ys, yo)
	return tag({ X = UDim.new(xs or 0, xo or 0), Y = UDim.new(ys or 0, yo or 0) }, "UDim2")
end
function UDim2.fromScale(x, y)
	return UDim2.new(x, 0, y, 0)
end
function UDim2.fromOffset(x, y)
	return UDim2.new(0, x, 0, y)
end
local Rect = simpleType("Rect", { "MinX", "MinY", "MaxX", "MaxY" })
local NumberRange = simpleType("NumberRange", { "Min", "Max" })
local NumberSequenceKeypoint = simpleType("NumberSequenceKeypoint", { "Time", "Value", "Envelope" })
local ColorSequenceKeypoint = simpleType("ColorSequenceKeypoint", { "Time", "Value" })
local NumberSequence = simpleType("NumberSequence", { "Keypoints" })
local ColorSequence = simpleType("ColorSequence", { "Keypoints" })
local PhysicalProperties = simpleType("PhysicalProperties", { "Density", "Friction", "Elasticity" })
local Font = simpleType("Font", { "Family", "Weight", "Style" })
function Font.fromEnum(e)
	return Font.new(tostring(e))
end
local BrickColor = simpleType("BrickColor", { "Name" })
local TweenInfo =
	simpleType("TweenInfo", { "Time", "EasingStyle", "EasingDirection", "RepeatCount", "Reverses", "DelayTime" })

local Region3 = {}
local R3 = {}
R3.__index = R3
function Region3.new(min, max)
	local r = setmetatable({ Min = min, Max = max }, R3)
	r.CFrame = CFrame.new((min + max) / 2)
	r.Size = max - min
	return tag(r, "Region3")
end
function R3.ExpandToGrid(r, res)
	local function lo(v)
		return math.floor(v / res) * res
	end
	local function hi(v)
		return math.ceil(v / res) * res
	end
	return Region3.new(v3(lo(r.Min.X), lo(r.Min.Y), lo(r.Min.Z)), v3(hi(r.Max.X), hi(r.Max.Y), hi(r.Max.Z)))
end

local RaycastParams = {}
function RaycastParams.new()
	return tag({ FilterType = nil, FilterDescendantsInstances = {}, IgnoreWater = false }, "RaycastParams")
end
local OverlapParams = RaycastParams

local Random = {}
local RandomMT = {}
RandomMT.__index = RandomMT
function Random.new(seed)
	local s = math.floor(seed or (clock * 1000)) % 2147483647
	if s <= 0 then
		s += 2147483646
	end
	return tag(setmetatable({ s = s }, RandomMT), "Random")
end
function RandomMT:_next()
	self.s = (self.s * 16807) % 2147483647
	return self.s / 2147483647
end
function RandomMT:NextNumber(a, b)
	a = a or 0
	b = b or 1
	return a + (b - a) * self:_next()
end
function RandomMT:NextInteger(a, b)
	return a + math.floor(self:_next() * (b - a + 1))
end
function RandomMT:NextUnitVector()
	return v3(self:_next() - 0.5, self:_next() - 0.5, self:_next() - 0.5).Unit
end
function RandomMT:Shuffle(t)
	for i = #t, 2, -1 do
		local j = self:NextInteger(1, i)
		t[i], t[j] = t[j], t[i]
	end
end
function RandomMT:Clone()
	return setmetatable({ s = self.s }, RandomMT)
end

-- Enums -------------------------------------------------------------------------------------

local enumItems = {}
local Enum
local function buildEnums()
	local enumTypes = {}
	for enumName, items in G.Enums do
		local et = { _name = enumName, _items = {}, _list = {} }
		for i, itemName in items do
			local item = tag({ Name = itemName, Value = i - 1, EnumType = et }, "EnumItem")
			setmetatable(item, {
				__tostring = function()
					return "Enum." .. enumName .. "." .. itemName
				end,
				__index = function(_, k)
					if k == "IsA" then
						return function(_, n)
							return n == enumName
						end
					end
					error(tostring(k) .. " is not a valid member of EnumItem", 2)
				end,
			})
			et._items[itemName] = item
			table.insert(et._list, item)
			enumItems[item] = enumName
		end
		setmetatable(et, {
			__index = function(_, k)
				if k == "GetEnumItems" then
					return function()
						return table.clone(et._list)
					end
				end
				local item = et._items[k]
				if item == nil then
					error(tostring(k) .. " is not a valid EnumItem of Enum." .. enumName, 2)
				end
				return item
			end,
			__tostring = function()
				return "Enum." .. enumName
			end,
		})
		tag(et, "Enum")
		enumTypes[enumName] = et
	end
	Enum = tag(
		setmetatable({}, {
			__index = function(_, k)
				local et = enumTypes[k]
				if et == nil then
					error(tostring(k) .. " is not a valid member of Enums", 2)
				end
				return et
			end,
		}),
		"Enums"
	)
end

-- Signals -----------------------------------------------------------------------------------

local SignalMT = {}
SignalMT.__index = SignalMT
local function newSignal(name)
	return tag(setmetatable({ _name = name, _conns = {} }, SignalMT), "RBXScriptSignal")
end
function SignalMT:Connect(fn)
	assert(type(fn) == "function", "Attempt to connect failed: Passed value is not a function")
	local conn = tag({ Connected = true }, "RBXScriptConnection")
	local signal = self
	function conn:Disconnect()
		if conn.Connected then
			conn.Connected = false
			local i = table.find(signal._conns, conn)
			if i then
				table.remove(signal._conns, i)
			end
		end
	end
	conn._fn = fn
	table.insert(self._conns, conn)
	return conn
end
function SignalMT:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end
function SignalMT:Wait()
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end
function SignalMT:_fire(...)
	for _, conn in table.clone(self._conns) do
		if conn.Connected then
			task.spawn(conn._fn, ...)
		end
	end
end
Mock.NewSignal = newSignal

-- Value validation --------------------------------------------------------------------------

local function mockTypeof(v)
	local t = typeTags[v]
	if t then
		return t
	end
	return type(v)
end
Mock.typeof = mockTypeof

local ATTRIBUTE_TYPES = {
	["nil"] = true,
	boolean = true,
	number = true,
	string = true,
	Vector3 = true,
	Vector2 = true,
	CFrame = true,
	Color3 = true,
	UDim = true,
	UDim2 = true,
	BrickColor = true,
	NumberRange = true,
	NumberSequence = true,
	ColorSequence = true,
	Rect = true,
	Font = true,
	EnumItem = true,
}

-- Problems the network layer has with `value` (nil = fine). Mirrors Roblox's rules for
-- RemoteEvent/RemoteFunction arguments.
local function remoteProblem(value, path, seen)
	local t = mockTypeof(value)
	if t == "function" or t == "thread" or t == "userdata" or t == "RBXScriptSignal" then
		return path .. ": cannot send " .. t
	end
	if t ~= "table" then
		return nil
	end
	seen = seen or {}
	if seen[value] then
		return path .. ": cyclic table"
	end
	seen[value] = true
	if getmetatable(value) ~= nil then
		return path .. ": table with metatable (metatables are dropped)"
	end
	local n = 0
	local numeric, stringKeys = 0, 0
	for k, v in value do
		n += 1
		local kt = mockTypeof(k)
		if kt == "number" then
			numeric += 1
		elseif kt == "string" then
			stringKeys += 1
		else
			return path .. ": non-string/number key of type " .. kt
		end
		local p = remoteProblem(v, path .. "." .. tostring(k), seen)
		if p then
			return p
		end
	end
	if numeric > 0 and stringKeys > 0 then
		return path .. ": mixed array/dictionary table (string keys get dropped)"
	end
	if numeric > 0 and numeric ~= #value then
		return path .. ": sparse or non-1-based numeric keys (data after a nil is lost)"
	end
	seen[value] = nil
	return nil
end
Mock.RemoteProblem = remoteProblem

-- Problems DataStore JSON encoding has with `value` (nil = fine).
local function dataStoreProblem(value, path, seen)
	local t = mockTypeof(value)
	if t == "nil" or t == "boolean" or t == "string" then
		return nil
	elseif t == "number" then
		if value ~= value or math.abs(value) == math.huge then
			return path .. ": NaN/inf number"
		end
		return nil
	elseif t ~= "table" then
		return path .. ": not JSON-able (" .. t .. ")"
	end
	seen = seen or {}
	if seen[value] then
		return path .. ": cyclic table"
	end
	seen[value] = true
	local numeric, stringKeys = 0, 0
	for k, v in value do
		local kt = mockTypeof(k)
		if kt == "number" then
			numeric += 1
		elseif kt == "string" then
			stringKeys += 1
		else
			return path .. ": key of type " .. kt
		end
		local p = dataStoreProblem(v, path .. "." .. tostring(k), seen)
		if p then
			return p
		end
	end
	if numeric > 0 and stringKeys > 0 then
		return path .. ": mixed array/dictionary"
	end
	if numeric > 0 and numeric ~= #value then
		return path .. ": sparse array"
	end
	seen[value] = nil
	return nil
end
Mock.DataStoreProblem = dataStoreProblem

local function deepCopy(v)
	if type(v) ~= "table" then
		return v
	end
	local c = {}
	for k, x in v do
		c[deepCopy(k)] = deepCopy(x)
	end
	return c
end

-- Instances ---------------------------------------------------------------------------------

local Instance = {}
local instances = setmetatable({}, { __mode = "k" }) -- proxy -> internal
local InstMT = {}
local game -- DataModel
local tagged = {} -- tag -> { [inst] = true }
local tagAdded = {} -- tag -> signal
local tagRemoved = {}
local services = {}

local function classInfo(name)
	return G.Classes[name]
end

local function isA(className, target)
	if target == "Instance" then
		return true
	end
	local n = className
	while n do
		if n == target then
			return true
		end
		local info = classInfo(n)
		n = info and info.Super
	end
	return false
end

local function memberKind(className, member)
	local n = className
	while n do
		local info = classInfo(n)
		if not info then
			return nil
		end
		local kind = info.Members[member]
		if kind then
			return kind, n
		end
		n = info.Super
	end
	return nil
end

local function restriction(className, member)
	local n = className
	while n do
		local r = Restrictions[n]
		if r and r[member] then
			return r[member]
		end
		local info = classInfo(n)
		n = info and info.Super
	end
	return nil
end

local PRIMITIVE = {
	number = "number",
	boolean = "boolean",
	string = "string",
	Vector3 = "Vector3",
	Vector2 = "Vector2",
	CFrame = "CFrame",
	Color3 = "Color3",
	UDim = "UDim",
	UDim2 = "UDim2",
}

local function checkType(className, member, kind, value)
	if value == nil then
		return
	end
	local want = PRIMITIVE[kind]
	local got = mockTypeof(value)
	if want then
		if got ~= want then
			error(
				string.format("Unable to assign property %s. %s expected, got %s (%s)", member, want, got, className),
				4
			)
		end
		if want == "number" and value ~= value then
			error(string.format("Unable to assign property %s: NaN (%s)", member, className), 4)
		end
	elseif type(kind) == "string" and string.sub(kind, 1, 4) == "Enum" and not string.find(kind, "|") then
		local enumName = string.gsub(string.sub(kind, 5), "%?$", "")
		if got ~= "EnumItem" or enumItems[value] ~= enumName then
			error(
				string.format(
					"Unable to assign property %s. Enum.%s expected, got %s (%s)",
					member,
					enumName,
					tostring(value),
					className
				),
				4
			)
		end
	end
end

function Mock.DefaultFor(kind)
	if kind == "number" then
		return 0
	elseif kind == "boolean" then
		return false
	elseif kind == "string" or kind == "Content" or kind == "ContentId" then
		return ""
	elseif kind == "Vector3" then
		return Vector3.zero
	elseif kind == "Vector2" then
		return Vector2.zero
	elseif kind == "CFrame" then
		return CFrame.identity
	elseif kind == "Color3" then
		return Color3.new(1, 1, 1)
	elseif kind == "UDim2" then
		return UDim2.new(0, 0, 0, 0)
	elseif kind == "UDim" then
		return UDim.new(0, 0)
	elseif kind == "Rect" then
		return Rect.new(0, 0, 0, 0)
	elseif kind == "NumberRange" then
		return NumberRange.new(0, 0)
	elseif kind == "Font" then
		return Font.new("rbxasset://fonts/families/SourceSansPro.json")
	elseif type(kind) == "string" and string.sub(kind, 1, 4) == "Enum" and not string.find(kind, "[|?]") then
		local ok, et = pcall(function()
			return Enum[string.sub(kind, 5)]
		end)
		if ok then
			return et:GetEnumItems()[1]
		end
	end
	return nil
end

local function getProxy(internal)
	return internal.proxy
end

local function fireChanged(self, prop)
	local s = self.propSignals[prop]
	if s then
		s:_fire()
	end
	if self.changed then
		self.changed:_fire(prop)
	end
end

local function isInGame(self)
	local n = self
	while n do
		if n.proxy == game then
			return true
		end
		n = n.parent
	end
	return false
end

local function forEachSubtree(self, fn)
	fn(self)
	for _, child in self.children do
		forEachSubtree(instances[child], fn)
	end
end

local function onEnterGame(self)
	forEachSubtree(self, function(node)
		for t in node.tags do
			local s = tagAdded[t]
			if s then
				s:_fire(node.proxy)
			end
		end
	end)
end

-- v2.3: like the engine, CollectionService's InstanceRemoved fires when a tagged instance leaves
-- the DataModel (destroyed, reparented out, or streamed out on a client).
local function onLeaveGame(self)
	forEachSubtree(self, function(node)
		for t in node.tags do
			local s = tagRemoved[t]
			if s then
				s:_fire(node.proxy)
			end
		end
	end)
end

local function getEventSignal(self, name)
	local s = self.events[name]
	if not s then
		s = newSignal(name)
		self.events[name] = s
	end
	return s
end

local function setParent(self, newParent)
	if self.destroyed then
		error(
			"The Parent property of "
				.. self.props.Name
				.. " is locked, current parent: NULL, new parent "
				.. (newParent and instances[newParent].props.Name or "NULL"),
			4
		)
	end
	local old = self.parent
	if old and old.proxy == newParent then
		return
	end
	if newParent ~= nil then
		local p = instances[newParent]
		assert(p, "Parent must be an Instance")
		local n = p
		while n do
			if n == self then
				error("Attempt to set " .. self.props.Name .. " as its own ancestor", 4)
			end
			n = n.parent
		end
	end
	local wasInGame = isInGame(self)
	if old then
		local i = table.find(old.children, self.proxy)
		if i then
			table.remove(old.children, i)
		end
		if old.events.ChildRemoved then
			old.events.ChildRemoved:_fire(self.proxy)
		end
	end
	self.parent = if newParent then instances[newParent] else nil
	if self.parent then
		table.insert(self.parent.children, self.proxy)
		if self.parent.events.ChildAdded then
			self.parent.events.ChildAdded:_fire(self.proxy)
		end
		local n = self.parent
		while n do
			if n.events.DescendantAdded then
				forEachSubtree(self, function(node)
					n.events.DescendantAdded:_fire(node.proxy)
				end)
			end
			n = n.parent
		end
	end
	if self.events.AncestryChanged then
		self.events.AncestryChanged:_fire(self.proxy, newParent)
	end
	fireChanged(self, "Parent")
	if not wasInGame and isInGame(self) then
		onEnterGame(self)
	elseif wasInGame and not isInGame(self) then
		onLeaveGame(self)
	end
end

local CLASS_DEFAULTS = {
	BasePart = function(p)
		p.Anchored = false
		p.CanCollide = true
		p.CanTouch = true
		p.CanQuery = true
		p.Massless = false
		p.Transparency = 0
		p.Reflectance = 0
		p.CastShadow = true
		p.Size = v3(4, 1.2, 2)
		p.CFrame = CFrame.identity
		p.Color = Color3.fromRGB(163, 162, 165)
		p.Locked = false
	end,
	Humanoid = function(p)
		p.Health = 100
		p.MaxHealth = 100
		p.HipHeight = 2
		p.WalkSpeed = 16
		p.JumpPower = 50
	end,
	Tool = function(p)
		p.Grip = CFrame.identity
		p.RequiresHandle = true
		p.CanBeDropped = true
		p.Enabled = true
		p.ToolTip = ""
	end,
	Model = function(p)
		p.WorldPivot = CFrame.identity
	end,
	Player = function(p)
		p.UserId = 0
		p.DisplayName = "Player"
	end,
	GuiBase2d = function(p)
		p.AbsoluteSize = v2(200, 100)
		p.AbsolutePosition = v2(0, 0)
	end,
	GuiObject = function(p)
		p.Visible = true
		p.Size = UDim2.new(0, 0, 0, 0)
		p.Position = UDim2.new(0, 0, 0, 0)
	end,
	SurfaceGuiBase = function(p)
		p.Enabled = true
	end,
	ProximityPrompt = function(p)
		p.Enabled = true
		p.MaxActivationDistance = 10
		p.HoldDuration = 0
	end,
}

local methods = {} -- generic Instance methods (proxy, ...)
local classMethods = {} -- className -> { name = fn }

local function internalOf(v)
	return instances[v]
end

local function newInstance(className, isService)
	local info = classInfo(className)
	if not info then
		error('Unable to create an Instance of type "' .. tostring(className) .. '"', 3)
	end
	local proxy = newproxy(true)
	local mt = getmetatable(proxy)
	local self = {
		proxy = proxy,
		className = className,
		props = { Name = className },
		attrs = {},
		children = {},
		events = {},
		propSignals = {},
		attrSignals = {},
		tags = {},
		parent = nil,
		destroyed = false,
	}
	for base, fn in CLASS_DEFAULTS do
		if isA(className, base) then
			fn(self.props)
		end
	end
	if isA(className, "LayerCollector") then
		self.props.AbsoluteSize = v2(1280, 662)
	end
	instances[proxy] = self
	typeTags[proxy] = "Instance"
	mt.__index = function(_, k)
		return InstMT.__index(self, k)
	end
	mt.__newindex = function(_, k, v)
		InstMT.__newindex(self, k, v)
	end
	mt.__tostring = function()
		return self.props.Name
	end
	return proxy
end

InstMT.__index = function(self, k)
	if k == "Parent" then
		return if self.parent then self.parent.proxy else nil
	elseif k == "ClassName" then
		return self.className
	end
	local custom = classMethods[self.className]
	local n = self.className
	while n do
		local cm = classMethods[n]
		if cm and cm[k] then
			return cm[k]
		end
		local info = classInfo(n)
		n = info and info.Super
	end
	local _ = custom
	local value = self.props[k]
	if value ~= nil then
		return value
	end
	if k == "Position" and isA(self.className, "BasePart") then
		return self.props.CFrame.Position
	elseif k == "Orientation" and isA(self.className, "BasePart") then
		local x, y, z = self.props.CFrame:ToOrientation()
		return v3(math.deg(x), math.deg(y), math.deg(z))
	end
	if methods[k] then
		return methods[k]
	end
	local kind = memberKind(self.className, k)
	if kind == "e" then
		if k == "Changed" then
			self.changed = self.changed or newSignal("Changed")
			return self.changed
		end
		return getEventSignal(self, k)
	elseif kind == "m" then
		return function()
			error(self.className .. ":" .. k .. " is not implemented in the mock", 2)
		end
	end
	-- child lookup
	for _, child in self.children do
		if instances[child].props.Name == k then
			return child
		end
	end
	if kind ~= nil then
		local r = restriction(self.className, k)
		if r == "NotScriptable" or r == "RobloxScriptSecurity" or r == "RobloxSecurity" then
			error(k .. " is not a valid member of " .. self.className .. " (" .. r .. ")", 3)
		end
		return Mock.DefaultFor(kind) -- valid property the mock never set: engine-like default
	end
	error(tostring(k) .. " is not a valid member of " .. self.className .. ' "' .. tostring(self.props.Name) .. '"', 3)
end

InstMT.__newindex = function(self, k, v)
	if k == "Parent" then
		setParent(self, v)
		return
	end
	local kind = memberKind(self.className, k)
	if kind == nil then
		error(
			tostring(k) .. " is not a valid member of " .. self.className .. ' "' .. tostring(self.props.Name) .. '"',
			3
		)
	end
	if kind == "e" or kind == "m" then
		error("Unable to assign " .. k .. " on " .. self.className, 3)
	end
	local r = restriction(self.className, k)
	if r and not (Mock.AllowRestricted and Mock.AllowRestricted[k]) then
		error(string.format("Unable to assign property %s. Property is %s (%s)", k, r, self.className), 3)
	end
	checkType(self.className, k, kind, v)
	if k == "Position" and isA(self.className, "BasePart") then
		local old = self.props.CFrame
		self.props.CFrame = cf(v.X, v.Y, v.Z, old[4])
		fireChanged(self, "CFrame")
		fireChanged(self, "Position")
		return
	end
	if k == "Name" then
		v = tostring(v)
	end
	local old = self.props[k]
	self.props[k] = v
	if old ~= v then
		fireChanged(self, k)
	end
end

local function find(list, pred)
	for _, child in list do
		if pred(instances[child]) then
			return child
		end
	end
	return nil
end

function methods.IsA(p, cls)
	return isA(instances[p].className, cls)
end
function methods.GetChildren(p)
	return table.clone(instances[p].children)
end
function methods.GetDescendants(p)
	local out = {}
	local function walk(node)
		for _, c in node.children do
			table.insert(out, c)
			walk(instances[c])
		end
	end
	walk(instances[p])
	return out
end
function methods.FindFirstChild(p, name, recursive)
	local self = instances[p]
	local hit = find(self.children, function(c)
		return c.props.Name == name
	end)
	if hit or not recursive then
		return hit
	end
	for _, d in methods.GetDescendants(p) do
		if instances[d].props.Name == name then
			return d
		end
	end
	return nil
end
function methods.FindFirstChildOfClass(p, cls)
	return find(instances[p].children, function(c)
		return c.className == cls
	end)
end
function methods.FindFirstChildWhichIsA(p, cls, recursive)
	local list = if recursive then methods.GetDescendants(p) else instances[p].children
	return find(list, function(c)
		return isA(c.className, cls)
	end)
end
function methods.FindFirstDescendant(p, name)
	return methods.FindFirstChild(p, name, true)
end
function methods.FindFirstAncestor(p, name)
	local n = instances[p].parent
	while n do
		if n.props.Name == name then
			return n.proxy
		end
		n = n.parent
	end
	return nil
end
function methods.FindFirstAncestorOfClass(p, cls)
	local n = instances[p].parent
	while n do
		if n.className == cls then
			return n.proxy
		end
		n = n.parent
	end
	return nil
end
function methods.FindFirstAncestorWhichIsA(p, cls)
	local n = instances[p].parent
	while n do
		if isA(n.className, cls) then
			return n.proxy
		end
		n = n.parent
	end
	return nil
end
function methods.IsDescendantOf(p, ancestor)
	local n = instances[p].parent
	while n do
		if n.proxy == ancestor then
			return true
		end
		n = n.parent
	end
	return false
end
function methods.IsAncestorOf(p, d)
	return methods.IsDescendantOf(d, p)
end
function methods.GetFullName(p)
	local names = {}
	local n = instances[p]
	while n and n.proxy ~= game do
		table.insert(names, 1, n.props.Name)
		n = n.parent
	end
	return table.concat(names, ".")
end
function methods.WaitForChild(p, name, timeout)
	local self = instances[p]
	local deadline = if timeout then clock + timeout else nil
	local warned = false
	local start = clock
	while true do
		local child = methods.FindFirstChild(p, name)
		if child then
			return child
		end
		if not coroutine.isyieldable() then
			error("WaitForChild(" .. name .. ") would yield in a non-yieldable context", 2)
		end
		if deadline and clock >= deadline then
			return nil
		end
		if not warned and not timeout and clock - start >= 5 then
			warned = true
			mockWarn("Infinite yield possible on '" .. methods.GetFullName(p) .. ':WaitForChild("' .. name .. "\")'")
		end
		task.wait()
		local _ = self
	end
end
function methods.ClearAllChildren(p)
	for _, c in methods.GetChildren(p) do
		methods.Destroy(c)
	end
end
function methods.Destroy(p)
	local self = instances[p]
	if self.destroyed then
		return
	end
	if self.events.Destroying then
		self.events.Destroying:_fire()
	end
	for _, c in table.clone(self.children) do
		methods.Destroy(c)
	end
	if self.parent then
		setParent(self, nil)
	end
	self.destroyed = true
	for t in self.tags do
		if tagged[t] then
			tagged[t][p] = nil
		end
	end
	for _, s in self.events do
		table.clear(s._conns)
	end
end
function methods.Remove(p)
	setParent(instances[p], nil)
end
function methods.Clone(p)
	local self = instances[p]
	local copy = newInstance(self.className)
	local ci = instances[copy]
	for k, v in self.props do
		ci.props[k] = v
	end
	for k, v in self.attrs do
		ci.attrs[k] = v
	end
	for t in self.tags do
		ci.tags[t] = true
		tagged[t] = tagged[t] or {}
		tagged[t][copy] = true
	end
	for _, c in self.children do
		methods.Clone(c).Parent = copy
	end
	return copy
end
function methods.SetAttribute(p, name, value)
	local self = instances[p]
	assert(type(name) == "string", "SetAttribute: name must be a string")
	if #name > 100 or not string.match(name, "^[%w_]+$") then
		error("SetAttribute: invalid attribute name '" .. name .. "'", 2)
	end
	local t = mockTypeof(value)
	if not ATTRIBUTE_TYPES[t] then
		error("SetAttribute(" .. name .. "): " .. t .. " is not a supported attribute type", 2)
	end
	local old = self.attrs[name]
	self.attrs[name] = value
	if old ~= value then
		local s = self.attrSignals[name]
		if s then
			s:_fire()
		end
		if self.events.AttributeChanged then
			self.events.AttributeChanged:_fire(name)
		end
	end
end
function methods.GetAttribute(p, name)
	return instances[p].attrs[name]
end
function methods.GetAttributes(p)
	return table.clone(instances[p].attrs)
end
function methods.GetAttributeChangedSignal(p, name)
	local self = instances[p]
	local s = self.attrSignals[name]
	if not s then
		s = newSignal("AttributeChanged:" .. name)
		self.attrSignals[name] = s
	end
	return s
end
function methods.GetPropertyChangedSignal(p, prop)
	local self = instances[p]
	if memberKind(self.className, prop) == nil then
		error(prop .. " is not a valid property name.", 2)
	end
	local s = self.propSignals[prop]
	if not s then
		s = newSignal("Changed:" .. prop)
		self.propSignals[prop] = s
	end
	return s
end
function methods.AddTag(p, t)
	local self = instances[p]
	if self.tags[t] then
		return
	end
	self.tags[t] = true
	tagged[t] = tagged[t] or {}
	tagged[t][p] = true
	if isInGame(self) and tagAdded[t] then
		tagAdded[t]:_fire(p)
	end
end
function methods.RemoveTag(p, t)
	local self = instances[p]
	self.tags[t] = nil
	if tagged[t] then
		tagged[t][p] = nil
	end
end
function methods.HasTag(p, t)
	return instances[p].tags[t] == true
end
function methods.GetTags(p)
	local list = {}
	for t in instances[p].tags do
		table.insert(list, t)
	end
	return list
end

-- PVInstance / Model / BasePart ---------------------------------------------------------------

local function partCorners(part)
	local s = part.props.Size / 2
	local c = part.props.CFrame
	local out = {}
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				table.insert(out, c * v3(s.X * sx, s.Y * sy, s.Z * sz))
			end
		end
	end
	return out
end

local function modelParts(p)
	local list = {}
	for _, d in methods.GetDescendants(p) do
		if isA(instances[d].className, "BasePart") then
			table.insert(list, instances[d])
		end
	end
	return list
end

local function boundingBox(p)
	local parts = modelParts(p)
	if #parts == 0 then
		return CFrame.identity, Vector3.zero
	end
	local minV = v3(math.huge, math.huge, math.huge)
	local maxV = v3(-math.huge, -math.huge, -math.huge)
	for _, part in parts do
		for _, corner in partCorners(part) do
			minV = minV:Min(corner)
			maxV = maxV:Max(corner)
		end
	end
	return CFrame.new((minV + maxV) / 2), maxV - minV
end

classMethods.BasePart = {
	GetPivot = function(p)
		return instances[p].props.CFrame
	end,
	PivotTo = function(p, target)
		assert(isCF(target), "PivotTo expects a CFrame")
		local self = instances[p]
		self.props.CFrame = target
		fireChanged(self, "CFrame")
	end,
	GetMass = function(p)
		local s = instances[p].props.Size
		return s.X * s.Y * s.Z * 0.7
	end,
	GetTouchingParts = function()
		return {}
	end,
	GetConnectedParts = function()
		return {}
	end,
	BreakJoints = function() end,
	SetNetworkOwner = function() end,
	ApplyImpulse = function() end,
}

classMethods.Model = {
	GetPivot = function(p)
		local self = instances[p]
		local pp = self.props.PrimaryPart
		if pp and instances[pp] and not instances[pp].destroyed then
			return instances[pp].props.CFrame
		end
		if self.pivotSet then
			return self.props.WorldPivot
		end
		local bb = boundingBox(p)
		return bb
	end,
	PivotTo = function(p, target)
		assert(isCF(target), "PivotTo expects a CFrame")
		local self = instances[p]
		local pivot = classMethods.Model.GetPivot(p)
		local delta = target * pivot:Inverse()
		for _, part in modelParts(p) do
			part.props.CFrame = delta * part.props.CFrame
			fireChanged(part, "CFrame")
		end
		self.props.WorldPivot = target
		self.pivotSet = true
	end,
	GetBoundingBox = function(p)
		return boundingBox(p)
	end,
	GetExtentsSize = function(p)
		local _, size = boundingBox(p)
		return size
	end,
	ScaleTo = function(p, s)
		assert(type(s) == "number" and s > 0, "ScaleTo: bad scale")
		local pivot = classMethods.Model.GetPivot(p)
		local scale = s / (instances[p].scale or 1)
		instances[p].scale = s
		for _, part in modelParts(p) do
			local rel = pivot:ToObjectSpace(part.props.CFrame)
			local pos = rel.Position * scale
			part.props.CFrame = pivot * cf(pos.X, pos.Y, pos.Z, rel[4])
			part.props.Size = part.props.Size * scale
		end
	end,
	GetScale = function(p)
		return instances[p].scale or 1
	end,
	MoveTo = function(p, pos)
		local _, size = boundingBox(p)
		classMethods.Model.PivotTo(p, CFrame.new(pos + v3(0, size.Y / 2, 0)))
	end,
	SetPrimaryPartCFrame = function(p, target)
		classMethods.Model.PivotTo(p, target)
	end,
	GetPrimaryPartCFrame = function(p)
		return classMethods.Model.GetPivot(p)
	end,
	-- v2.3 streaming (PersistentPerPlayer models)
	AddPersistentPlayer = function(p, player)
		local self = instances[p]
		self.persistentPlayers = self.persistentPlayers or {}
		self.persistentPlayers[player] = true
	end,
	RemovePersistentPlayer = function(p, player)
		local self = instances[p]
		if self.persistentPlayers then
			self.persistentPlayers[player] = nil
		end
	end,
	GetPersistentPlayers = function(p)
		local list = {}
		for player in instances[p].persistentPlayers or {} do
			table.insert(list, player)
		end
		return list
	end,
}

classMethods.Humanoid = {
	EquipTool = function(h, tool)
		local self = instances[h]
		local character = self.parent and self.parent.proxy
		assert(character, "EquipTool: humanoid has no character")
		assert(isA(instances[tool].className, "Tool"), "EquipTool expects a Tool")
		for _, c in methods.GetChildren(character) do
			if isA(instances[c].className, "Tool") and c ~= tool then
				local player = Mock.PlayerFromCharacter and Mock.PlayerFromCharacter(character)
				local backpack = player and methods.FindFirstChildOfClass(player, "Backpack")
				c.Parent = backpack
			end
		end
		tool.Parent = character
		Mock.OnToolEquipped(tool, character)
	end,
	UnequipTools = function(h)
		local character = instances[h].parent.proxy
		local player = Mock.PlayerFromCharacter(character)
		for _, c in methods.GetChildren(character) do
			if isA(instances[c].className, "Tool") then
				c.Parent = methods.FindFirstChildOfClass(player, "Backpack")
			end
		end
	end,
	TakeDamage = function(h, amount)
		local self = instances[h]
		self.props.Health = math.max(0, self.props.Health - amount)
	end,
	ChangeState = function() end,
	GetState = function()
		return Enum.HumanoidStateType.Running
	end,
	LoadAnimation = function()
		return { Play = function() end, Stop = function() end }
	end,
	MoveTo = function() end,
	ApplyDescription = function() end,
}

-- Seats (RideService): Seat:Sit(humanoid) sets Seat.Occupant + Humanoid.Sit/SeatPart (ReadOnly
-- props written internally). Mock.LeaveSeat(humanoid) is the jump-out.
local function setSeat(seatNode, humanoidNode, sitting)
	if seatNode then
		seatNode.props.Occupant = if sitting and humanoidNode then humanoidNode.proxy else nil
		fireChanged(seatNode, "Occupant")
	end
	if humanoidNode then
		humanoidNode.props.Sit = sitting
		fireChanged(humanoidNode, "Sit")
		humanoidNode.props.SeatPart = if sitting and seatNode then seatNode.proxy else nil
		fireChanged(humanoidNode, "SeatPart")
	end
end
classMethods.Seat = {
	Sit = function(seat, humanoid)
		local h = instances[humanoid]
		assert(h and isA(h.className, "Humanoid"), "Seat:Sit expects a Humanoid")
		local previous = h.props.SeatPart
		if previous and previous ~= seat and instances[previous] then
			setSeat(instances[previous], nil, false)
		end
		setSeat(instances[seat], h, true)
	end,
}
function Mock.LeaveSeat(humanoid)
	local h = instances[humanoid]
	local seat = h.props.SeatPart
	setSeat(seat and instances[seat], h, false)
end

-- Tool equip: Roblox builds the RightGrip weld from Handle + Grip; validate the tool shape.
Mock.ToolProblems = {}
function Mock.OnToolEquipped(tool, _character)
	local handle = methods.FindFirstChild(tool, "Handle")
	local problems = {}
	if instances[tool].props.RequiresHandle ~= false then
		if not handle or not isA(instances[handle].className, "BasePart") then
			table.insert(problems, "RequiresHandle but no BasePart child named Handle")
		end
	end
	for _, d in methods.GetDescendants(tool) do
		local node = instances[d]
		if isA(node.className, "BasePart") and node.props.Anchored then
			table.insert(problems, "anchored part " .. node.props.Name .. " in tool (character would freeze)")
		end
	end
	-- every BasePart must be connected to the handle through welds
	if handle then
		local connected = { [handle] = true }
		local changed = true
		local welds = {}
		for _, d in methods.GetDescendants(tool) do
			local cls = instances[d].className
			if cls == "WeldConstraint" or cls == "Weld" or cls == "Motor6D" or cls == "ManualWeld" then
				table.insert(welds, instances[d].props)
			end
		end
		while changed do
			changed = false
			for _, w in welds do
				local a, b = w.Part0, w.Part1
				if a and b and connected[a] ~= connected[b] then
					connected[a] = true
					connected[b] = true
					changed = true
				end
			end
		end
		for _, d in methods.GetDescendants(tool) do
			if isA(instances[d].className, "BasePart") and not connected[d] then
				table.insert(problems, "part " .. instances[d].props.Name .. " is not welded to the Handle (falls off)")
			end
		end
	end
	Mock.ToolProblems[tool] = problems
end

-- Terrain voxels ------------------------------------------------------------------------------

local VOXEL = 4
local voxels = {} -- key -> { Material, Occupancy }
local materialColors = {}
Mock.Voxels = voxels
local MAX_REGION_VOXELS = 4 * 1024 * 1024 -- WriteVoxels / ReadVoxels region cap (4M)
Mock.TerrainCalls = {}
Mock.TerrainFailure = nil -- one-shot { Kind, Error } fault injection
Mock.ProfileStack = {}
Mock.ProfileEvents = {}
local function failTerrainIfRequested(kind)
	local failure = Mock.TerrainFailure
	if failure and failure.Kind == kind then
		Mock.TerrainFailure = nil
		error(failure.Error, 0)
	end
end

local TERRAIN_MATERIALS = {}
for _, n in
	{
		"Air",
		"Asphalt",
		"Basalt",
		"Brick",
		"Cobblestone",
		"Concrete",
		"CrackedLava",
		"Glacier",
		"Grass",
		"Ground",
		"Ice",
		"LeafyGrass",
		"Limestone",
		"Mud",
		"Pavement",
		"Rock",
		"Salt",
		"Sand",
		"Sandstone",
		"Slate",
		"Snow",
		"Water",
		"WoodPlanks",
	}
do
	TERRAIN_MATERIALS[n] = true
end

local function vkey(ix, iy, iz)
	assert(iy >= -64 and iy < 960 and ix > -1024 and ix < 1024 and iz > -1024 and iz < 1024, "voxel out of mock range")
	return (ix + 1024) + (iy + 64) * 2048 + (iz + 1024) * 2048 * 1024
end
Mock.VoxelKey = vkey

local function checkTerrainMaterial(material, what)
	if mockTypeof(material) ~= "EnumItem" or enumItems[material] ~= "Material" then
		error(what .. ": expected Enum.Material, got " .. tostring(material), 3)
	end
	if not TERRAIN_MATERIALS[material.Name] then
		error(what .. ": " .. tostring(material) .. " is not a terrain material", 3)
	end
end

local function setVoxel(ix, iy, iz, material, occ)
	local k = vkey(ix, iy, iz)
	if material.Name == "Air" or occ <= 0 then
		voxels[k] = nil
	else
		voxels[k] = { Material = material, Occupancy = math.min(occ, 1) }
	end
end

function Mock.GetVoxel(pos)
	local v = voxels[vkey(math.floor(pos.X / VOXEL), math.floor(pos.Y / VOXEL), math.floor(pos.Z / VOXEL))]
	return v
end

classMethods.Terrain = {
	FillBlock = function(_t, cframe, size, material)
		failTerrainIfRequested("FillBlock")
		checkTerrainMaterial(material, "FillBlock")
		assert(isCF(cframe) and isV3(size), "FillBlock(CFrame, Vector3, Material)")
		local r = cframe[4]
		assert(r[1] == 1 and r[5] == 1 and r[9] == 1, "mock FillBlock supports axis-aligned blocks only")
		local minV = cframe.Position - size / 2
		local maxV = cframe.Position + size / 2
		local x0, x1 = math.floor(minV.X / VOXEL + 0.5), math.floor(maxV.X / VOXEL - 0.5)
		local y0, y1 = math.floor(minV.Y / VOXEL + 0.5), math.floor(maxV.Y / VOXEL - 0.5)
		local z0, z1 = math.floor(minV.Z / VOXEL + 0.5), math.floor(maxV.Z / VOXEL - 0.5)
		local count = math.max(0, x1 - x0 + 1) * math.max(0, y1 - y0 + 1) * math.max(0, z1 - z0 + 1)
		table.insert(Mock.TerrainCalls, { Kind = "FillBlock", Voxels = count, Material = material.Name })
		if count > MAX_REGION_VOXELS then
			error(string.format("FillBlock region too large (%d voxels > %d)", count, MAX_REGION_VOXELS), 2)
		end
		if minV.Y < 0 then
			error("terrain generated below Y=0 (contract: never)", 2)
		end
		for ix = x0, x1 do
			for iy = y0, y1 do
				for iz = z0, z1 do
					setVoxel(ix, iy, iz, material, 1)
				end
			end
		end
	end,
	FillBall = function(_t, center, radius, material)
		failTerrainIfRequested("FillBall")
		checkTerrainMaterial(material, "FillBall")
		assert(isV3(center) and type(radius) == "number", "FillBall(Vector3, number, Material)")
		table.insert(
			Mock.TerrainCalls,
			{ Kind = "FillBall", Center = center, Radius = radius, Material = material.Name }
		)
		local reach = radius + VOXEL / 2
		local x0, x1 = math.floor((center.X - reach) / VOXEL), math.floor((center.X + reach) / VOXEL)
		local y0, y1 = math.floor((center.Y - reach) / VOXEL), math.floor((center.Y + reach) / VOXEL)
		local z0, z1 = math.floor((center.Z - reach) / VOXEL), math.floor((center.Z + reach) / VOXEL)
		for ix = x0, x1 do
			for iy = y0, y1 do
				for iz = z0, z1 do
					local c = v3((ix + 0.5) * VOXEL, (iy + 0.5) * VOXEL, (iz + 0.5) * VOXEL)
					local d = (c - center).Magnitude
					local coverage = math.clamp((radius - d) / VOXEL + 0.5, 0, 1)
					if coverage > 0 then
						local k = vkey(ix, iy, iz)
						local cur = voxels[k]
						if material.Name == "Air" then
							if cur then
								setVoxel(ix, iy, iz, cur.Material, math.min(cur.Occupancy, 1 - coverage))
							end
						else
							setVoxel(ix, iy, iz, material, math.max(cur and cur.Occupancy or 0, coverage))
						end
					end
				end
			end
		end
	end,
	FillCylinder = function(t, cframe, height, radius, material)
		checkTerrainMaterial(material, "FillCylinder")
		-- approximate with a block of the same footprint
		classMethods.Terrain.FillBlock(t, CFrame.new(cframe.Position), v3(radius * 2, height, radius * 2), material)
	end,
	FillWedge = function(t, cframe, size, material)
		classMethods.Terrain.FillBlock(t, CFrame.new(cframe.Position), size, material)
	end,
	FillRegion = function() end,
	ReadVoxels = function(_t, region, resolution)
		assert(resolution == 4, "ReadVoxels resolution must be 4")
		assert(mockTypeof(region) == "Region3", "ReadVoxels expects a Region3")
		local minV, maxV = region.Min, region.Max
		for _, c in { minV.X, minV.Y, minV.Z, maxV.X, maxV.Y, maxV.Z } do
			if c % 4 ~= 0 then
				error("Region has to be aligned to the grid (use Region3:ExpandToGrid)", 2)
			end
		end
		local nx, ny, nz = (maxV.X - minV.X) / 4, (maxV.Y - minV.Y) / 4, (maxV.Z - minV.Z) / 4
		if nx * ny * nz > MAX_REGION_VOXELS then
			error("ReadVoxels region too large", 2)
		end
		local mats, occs = { Size = v3(nx, ny, nz) }, { Size = v3(nx, ny, nz) }
		for x = 1, nx do
			mats[x], occs[x] = {}, {}
			for y = 1, ny do
				mats[x][y], occs[x][y] = {}, {}
				for z = 1, nz do
					local v = voxels[vkey(minV.X / 4 + x - 1, minV.Y / 4 + y - 1, minV.Z / 4 + z - 1)]
					mats[x][y][z] = if v then v.Material else Enum.Material.Air
					occs[x][y][z] = if v then v.Occupancy else 0
				end
			end
		end
		return mats, occs
	end,
	SetMaterialColor = function(_t, material, color)
		checkTerrainMaterial(material, "SetMaterialColor")
		if material.Name == "Air" or material.Name == "Water" then
			error("SetMaterialColor: " .. material.Name .. " has no material colour", 2)
		end
		assert(mockTypeof(color) == "Color3", "SetMaterialColor expects a Color3")
		materialColors[material.Name] = color
	end,
	GetMaterialColor = function(_t, material)
		return materialColors[material.Name] or Color3.new(1, 1, 1)
	end,
	Clear = function()
		table.clear(voxels)
	end,
}
Mock.MaterialColors = materialColors

-- Downward "raycast" through the voxel grid (what a click on the terrain would hit).
function Mock.TerrainSurfaceBelow(x, z, fromY)
	local ix, iz = math.floor(x / VOXEL), math.floor(z / VOXEL)
	local iy = math.floor(fromY / VOXEL)
	while iy >= 0 do
		local v = voxels[vkey(ix, iy, iz)]
		if v and v.Material.Name ~= "Water" then
			return (iy * VOXEL) + v.Occupancy * VOXEL, v.Material
		end
		iy -= 1
	end
	return nil
end

-- Services ------------------------------------------------------------------------------------

local function getService(name)
	local s = services[name]
	if s then
		return s
	end
	s = newInstance(name, true)
	instances[s].props.Name = name
	services[name] = s
	setParent(instances[s], game)
	return s
end

Mock.Remote = {
	ToClient = {}, -- { Player, Name, Args }
	Problems = {},
}

classMethods.RemoteEvent = {
	FireClient = function(r, player, ...)
		assert(instances[player] and instances[player].className == "Player", "FireClient: argument 1 must be a Player")
		local args = table.pack(...)
		for i = 1, args.n do
			local problem = remoteProblem(args[i], instances[r].props.Name .. "[" .. i .. "]")
			if problem then
				table.insert(Mock.Remote.Problems, problem)
				mockWarn("[mock] remote payload problem: " .. problem)
			end
		end
		table.insert(Mock.Remote.ToClient, { Player = player, Name = instances[r].props.Name, Args = args })
	end,
	FireAllClients = function(r, ...)
		for _, player in methods.GetChildren(services.Players) do
			classMethods.RemoteEvent.FireClient(r, player, ...)
		end
	end,
	FireServer = function(r, ...)
		if not Mock.ClientMode then
			error("FireServer can only be called from the client", 2)
		end
		local args = table.pack(...)
		for i = 1, args.n do
			local problem = remoteProblem(args[i], instances[r].props.Name .. "[" .. i .. "]")
			if problem then
				table.insert(Mock.Remote.Problems, problem)
				mockWarn("[mock] remote payload problem: " .. problem)
			end
		end
		table.insert(Mock.Remote.ToServer, { Name = instances[r].props.Name, Args = args })
	end,
}
Mock.Remote.ToServer = {}
Mock.ServerFunctions = {}
classMethods.RemoteFunction = {
	InvokeClient = function()
		error("InvokeClient not mocked", 2)
	end,
	InvokeServer = function(r, ...)
		assert(Mock.ClientMode, "InvokeServer can only be called from the client")
		local name = instances[r].props.Name
		if coroutine.isyieldable() then
			task.wait()
		end
		local fn = Mock.ServerFunctions[name]
		if not fn then
			return nil
		end
		return fn(...)
	end,
}

-- Server -> client helper for the client test.
function Mock.FireClientEvent(name, ...)
	local remote = Mock.FindRemote(name)
	local args = table.pack(...)
	for i = 1, args.n do
		local problem = remoteProblem(args[i], name .. "[" .. i .. "]")
		assert(problem == nil, problem)
	end
	local node = instances[remote]
	node.events.OnClientEvent = node.events.OnClientEvent or newSignal("OnClientEvent")
	node.events.OnClientEvent:_fire(...)
end

-- Client -> server helpers for the driver.
function Mock.FireServer(name, player, ...)
	local remote = Mock.FindRemote(name)
	local args = table.pack(...)
	for i = 1, args.n do
		local problem = remoteProblem(args[i], name .. "[" .. i .. "]")
		assert(problem == nil, problem)
	end
	instances[remote].events.OnServerEvent = instances[remote].events.OnServerEvent or newSignal("OnServerEvent")
	instances[remote].events.OnServerEvent:_fire(player, ...)
end
function Mock.InvokeServer(name, player, ...)
	local remote = Mock.FindRemote(name)
	local fn = instances[remote].props.OnServerInvoke
	assert(fn, "no OnServerInvoke for " .. name)
	local result = table.pack(pcall(fn, player, ...))
	assert(result[1], tostring(result[2]))
	for i = 2, result.n do
		local problem = remoteProblem(result[i], name .. " return")
		if problem then
			table.insert(Mock.Remote.Problems, problem)
		end
	end
	return table.unpack(result, 2, result.n)
end

classMethods.Players = {
	GetPlayers = function(p)
		local list = {}
		for _, c in instances[p].children do
			if instances[c].className == "Player" then
				table.insert(list, c)
			end
		end
		return list
	end,
	GetPlayerByUserId = function(p, id)
		for _, c in classMethods.Players.GetPlayers(p) do
			if instances[c].props.UserId == id then
				return c
			end
		end
		return nil
	end,
	GetPlayerFromCharacter = function(p, character)
		for _, c in classMethods.Players.GetPlayers(p) do
			if instances[c].props.Character == character and character ~= nil then
				return c
			end
		end
		return nil
	end,
	GetNameFromUserIdAsync = function(_p, id)
		return "User" .. tostring(id)
	end,
	GetUserIdFromNameAsync = function()
		return 1
	end,
}
function Mock.PlayerFromCharacter(character)
	return classMethods.Players.GetPlayerFromCharacter(services.Players, character)
end

Mock.Kicked = {}
local function asyncYieldStream()
	if coroutine.isyieldable() then
		task.wait()
	end
end

classMethods.Player = {
	Kick = function(p, message)
		table.insert(Mock.Kicked, { Player = p, Message = message })
		mockWarn("[mock] kicked " .. instances[p].props.Name .. ": " .. tostring(message))
	end,
	IsInGroup = function()
		return false
	end,
	GetRankInGroup = function()
		return 0
	end,
	IsFriendsWith = function()
		return false
	end,
	LoadCharacter = function(p)
		Mock.SpawnCharacter(p)
	end,
	GetMouse = function()
		error("GetMouse is client-only")
	end,
	RequestStreamAroundAsync = function()
		asyncYieldStream()
	end,
}

-- DataStores (in memory, JSON-ability enforced) ------------------------------------------------

Mock.DataStores = {} -- name -> { [key] = value }
Mock.ProductPrices = {} -- v2.3: MarketplaceService:GetProductInfo(id).PriceInRobux
Mock.DataStoreFail = false

local function asyncYield()
	if coroutine.isyieldable() then
		task.wait()
	end
end

local function dsCheckValue(storeName, key, value)
	local problem = dataStoreProblem(value, storeName .. "/" .. key)
	if problem then
		error("DataStore value is not JSON-able: " .. problem, 3)
	end
	if #key > 50 then
		error("DataStore key too long", 3)
	end
end

local function newDataStore(name, ordered)
	local data = Mock.DataStores[name] or {}
	Mock.DataStores[name] = data
	local store = {}
	function store:GetAsync(key)
		asyncYield()
		if Mock.DataStoreFail then
			error("502: mock DataStore failure")
		end
		return deepCopy(data[key])
	end
	function store:SetAsync(key, value, _userIds)
		asyncYield()
		if Mock.DataStoreFail then
			error("502: mock DataStore failure")
		end
		if ordered then
			assert(type(value) == "number" and value % 1 == 0, "OrderedDataStore values must be integers")
		end
		dsCheckValue(name, key, value)
		data[key] = deepCopy(value)
	end
	function store:UpdateAsync(key, fn)
		if Mock.BeforeDataStoreUpdate then
			Mock.BeforeDataStoreUpdate(name, key)
		end
		asyncYield()
		if Mock.DataStoreFail then
			error("502: mock DataStore failure")
		end
		local result, userIds = fn(deepCopy(data[key]))
		if result == nil then
			return nil
		end
		dsCheckValue(name, key, result)
		if userIds ~= nil then
			assert(type(userIds) == "table", "UpdateAsync userIds must be a table")
		end
		data[key] = deepCopy(result)
		return deepCopy(result)
	end
	function store:RemoveAsync(key)
		local old = data[key]
		data[key] = nil
		return old
	end
	function store:IncrementAsync(key, delta)
		data[key] = (data[key] or 0) + (delta or 1)
		return data[key]
	end
	if ordered then
		function store:GetSortedAsync(ascending, pageSize)
			asyncYield()
			local entries = {}
			for k, v in data do
				table.insert(entries, { key = k, value = v })
			end
			table.sort(entries, function(a, b)
				if ascending then
					return a.value < b.value
				end
				return a.value > b.value
			end)
			local page = {}
			for i = 1, math.min(pageSize, #entries) do
				page[i] = entries[i]
			end
			return {
				GetCurrentPage = function()
					return page
				end,
				IsFinished = true,
			}
		end
	end
	return store
end

local dataStoreService = {
	GetDataStore = function(_s, name)
		if Mock.DataStoreAcquireFail then
			error("mock DataStore acquisition failure")
		end
		return newDataStore(name, false)
	end,
	GetOrderedDataStore = function(_s, name)
		return newDataStore("ordered:" .. name, true)
	end,
	-- Mock.DataStoreBudget: number of requests left (default plenty)
	GetRequestBudgetForRequestType = function(_s, requestType)
		assert(mockTypeof(requestType) == "EnumItem", "GetRequestBudgetForRequestType expects an Enum.DataStoreRequestType")
		return Mock.DataStoreBudget or 100
	end,
	GetGlobalDataStore = function()
		return newDataStore("global", false)
	end,
}

-- Marketplace / badges / analytics -------------------------------------------------------------

Mock.Prompts = {} -- { Kind, Player, Id }
Mock.BadgeAwards = {} -- { UserId, Id }
Mock.BadgeFailures = 0 -- the next N AwardBadge calls throw (throttling / outage)
Mock.Analytics = {}
-- AnalyticsService customFields: nil or { CustomField01..03 = string }.
function Mock.CheckAnalyticsFields(fields)
	if fields == nil then
		return
	end
	assert(type(fields) == "table", "analytics customFields must be a table")
	for k, v in fields do
		assert(k == "CustomField01" or k == "CustomField02" or k == "CustomField03", "analytics custom field key " .. tostring(k))
		assert(type(v) == "string" and #v <= 50, "analytics custom field value must be a short string")
	end
end
local marketplace = {
	PromptGamePassPurchase = function(_s, player, id)
		assert(type(id) == "number" and id > 0, "PromptGamePassPurchase with invalid id " .. tostring(id))
		table.insert(Mock.Prompts, { Kind = "GamePass", Player = player, Id = id })
	end,
	PromptProductPurchase = function(_s, player, id)
		assert(type(id) == "number" and id > 0, "PromptProductPurchase with invalid id " .. tostring(id))
		table.insert(Mock.Prompts, { Kind = "Product", Player = player, Id = id })
	end,
	UserOwnsGamePassAsync = function(_s, _userId, id)
		assert(type(id) == "number" and id > 0, "UserOwnsGamePassAsync with invalid id " .. tostring(id))
		asyncYield()
		return false
	end,
	GetProductInfo = function(_s, id, _infoType)
		asyncYield()
		-- v2.3: tests set Mock.ProductPrices[id] to simulate the Creator Hub price
		local price = Mock.ProductPrices and Mock.ProductPrices[id]
		return { PriceInRobux = price or 0, Name = "x" }
	end,
}

-- Global env ------------------------------------------------------------------------------------

local function buildGame()
	game = newInstance("DataModel")
	instances[game].props.Name = "Game"
	instances[game].props.JobId = ""
	instances[game].props.PlaceId = 0
	instances[game].props.GameId = 0
	instances[game].props.PlaceVersion = 0
	instances[game].props.CreatorId = 0
	Mock.BindToClose = {}
	classMethods.DataModel = {
		GetService = function(_g, name)
			if not classInfo(name) then
				error("'" .. tostring(name) .. "' is not a valid Service name", 2)
			end
			return getService(name)
		end,
		FindService = function(_g, name)
			return services[name]
		end,
		BindToClose = function(_g, fn)
			table.insert(Mock.BindToClose, fn)
		end,
		IsLoaded = function()
			return true
		end,
	}
	local workspace = getService("Workspace")
	local terrain = newInstance("Terrain")
	instances[terrain].props.Name = "Terrain"
	instances[terrain].props.Anchored = true
	setParent(instances[terrain], workspace)
	instances[workspace].props.Terrain = terrain
	instances[workspace].props.Gravity = 196.2
	instances[workspace].props.FallenPartsDestroyHeight = -500
	classMethods.Workspace = {
		GetServerTimeNow = function()
			return EPOCH + clock - 1000
		end,
		-- Server raycasts miss by default; tests opt in to terrain hits (e.g. digger point picking).
		Raycast = function(_w, origin, direction, params)
			if Mock.ServerTerrainRaycast and Mock.RaycastTerrain then
				return Mock.RaycastTerrain(origin, direction, params)
			end
			return nil
		end,
		GetPartBoundsInBox = function()
			return {}
		end,
		GetPartsInPart = function()
			return {}
		end,
	}
	classMethods.RunService = {
		IsServer = function()
			return not Mock.ClientMode
		end,
		IsClient = function()
			return Mock.ClientMode == true
		end,
		BindToRenderStep = function(_s, name, _priority, fn)
			Mock.RenderSteps[name] = fn
		end,
		UnbindFromRenderStep = function(_s, name)
			Mock.RenderSteps[name] = nil
		end,
		IsStudio = function()
			return Mock.IsStudio == true
		end,
		IsRunning = function()
			return true
		end,
	}
	classMethods.Stats = {
		GetTotalMemoryUsageMb = function()
			return Mock.MemoryMb or 512
		end,
	}
	classMethods.CollectionService = {
		AddTag = function(_s, inst, t)
			methods.AddTag(inst, t)
		end,
		RemoveTag = function(_s, inst, t)
			methods.RemoveTag(inst, t)
		end,
		HasTag = function(_s, inst, t)
			return methods.HasTag(inst, t)
		end,
		GetTagged = function(_s, t)
			local list = {}
			for inst in tagged[t] or {} do
				if not instances[inst].destroyed and isInGame(instances[inst]) then
					table.insert(list, inst)
				end
			end
			return list
		end,
		GetInstanceAddedSignal = function(_s, t)
			tagAdded[t] = tagAdded[t] or newSignal("TagAdded:" .. t)
			return tagAdded[t]
		end,
		GetInstanceRemovedSignal = function(_s, t)
			tagRemoved[t] = tagRemoved[t] or newSignal("TagRemoved:" .. t)
			return tagRemoved[t]
		end,
		GetTags = function(_s, inst)
			return methods.GetTags(inst)
		end,
	}
	local guid = 0
	classMethods.HttpService = {
		GenerateGUID = function(_s, braces)
			guid += 1
			local s = string.format("%08X-0000-4000-8000-%012X", guid, guid * 7919)
			return if braces == false then s else "{" .. s .. "}"
		end,
		JSONEncode = function(_s, v)
			local p = dataStoreProblem(v, "JSONEncode")
			assert(p == nil, p)
			return "<json>"
		end,
	}
	classMethods.DataStoreService = dataStoreService
	classMethods.MarketplaceService = marketplace
	-- PolicyService: Mock.Policy[userId] overrides the answer; Mock.PolicyFail = true makes the
	-- lookup throw (exercises PolicyService's retry + fallback default).
	Mock.Policy = Mock.Policy or {}
	Mock.PolicyFail = false
	Mock.PolicyCalls = 0
	classMethods.PolicyService = {
		GetPolicyInfoForPlayerAsync = function(_s, player)
			assert(instances[player] and instances[player].className == "Player", "policy: Player expected")
			Mock.PolicyCalls += 1
			if Mock.PolicyFail then
				error("HTTP 500 (mock policy failure)", 2)
			end
			local custom = Mock.Policy[player.UserId]
			if custom then
				return table.clone(custom)
			end
			return {
				ArePaidRandomItemsRestricted = false,
				IsPaidItemTradingAllowed = true,
				AllowedExternalLinkReferences = { "Discord", "Facebook", "Twitch", "YouTube" },
				IsEligibleToPurchaseSubscription = true,
				AreAdsAllowed = true,
				IsSubjectToChinaPolicies = false,
			}
		end,
	}
	classMethods.BadgeService = {
		UserHasBadgeAsync = function(_s, _u, id)
			assert(id ~= 0, "badge id 0")
			return false
		end,
		AwardBadge = function(_s, userId, id)
			assert(id ~= 0, "badge id 0")
			if Mock.BadgeFailures > 0 then
				Mock.BadgeFailures -= 1
				error("mock badge throttled")
			end
			table.insert(Mock.BadgeAwards, { UserId = userId, Id = id })
			return true
		end,
		GetBadgeInfoAsync = function()
			return { IsEnabled = true }
		end,
	}
	classMethods.AnalyticsService = {
		LogOnboardingFunnelStepEvent = function(_s, player, step, name)
			assert(instances[player] and instances[player].className == "Player", "funnel: player")
			assert(type(step) == "number" and step >= 1 and step % 1 == 0, "funnel step must be an integer >= 1")
			assert(name == nil or type(name) == "string", "funnel step name")
			table.insert(Mock.Analytics, { Kind = "Funnel", Player = player, Step = step, Name = name })
		end,
		LogEconomyEvent = function(_s, player, flow, currency, amount, ending, transaction, sku)
			assert(instances[player], "economy: player")
			assert(enumItems[flow] == "AnalyticsEconomyFlowType", "economy: flow type")
			assert(type(currency) == "string" and type(amount) == "number" and type(ending) == "number")
			assert(amount > 0, "economy: amount must be > 0")
			assert(type(transaction) == "string", "economy: transactionType must be a string")
			assert(sku == nil or type(sku) == "string", "economy: sku")
			table.insert(
				Mock.Analytics,
				{ Kind = "Economy", Player = player, Flow = flow.Name, Currency = currency, Amount = amount, Ending = ending, Sku = sku }
			)
		end,
		LogFunnelStepEvent = function(_s, player, funnelName, sessionId, step, stepName, customFields)
			assert(instances[player] and instances[player].className == "Player", "funnel step: player")
			assert(type(funnelName) == "string" and #funnelName > 0, "funnel step: funnelName")
			assert(sessionId == nil or type(sessionId) == "string", "funnel step: funnelSessionId")
			assert(type(step) == "number" and step >= 1 and step % 1 == 0, "funnel step: step must be an integer >= 1")
			assert(stepName == nil or type(stepName) == "string", "funnel step: stepName")
			Mock.CheckAnalyticsFields(customFields)
			table.insert(Mock.Analytics, {
				Kind = "FunnelStep",
				Player = player,
				Funnel = funnelName,
				Session = sessionId,
				Step = step,
				Name = stepName,
				Fields = customFields,
			})
		end,
		LogProgressionStartEvent = function(_s, player, path, level, levelName, customFields)
			assert(instances[player], "progression: player")
			assert(type(path) == "string" and type(level) == "number" and level >= 1 and level % 1 == 0, "progression: path/level")
			Mock.CheckAnalyticsFields(customFields)
			table.insert(Mock.Analytics, { Kind = "Progression", Status = "Start", Player = player, Path = path, Level = level, Name = levelName, Fields = customFields })
		end,
		LogProgressionCompleteEvent = function(_s, player, path, level, levelName, customFields)
			assert(instances[player], "progression: player")
			assert(type(path) == "string" and type(level) == "number" and level >= 1 and level % 1 == 0, "progression: path/level")
			Mock.CheckAnalyticsFields(customFields)
			table.insert(Mock.Analytics, { Kind = "Progression", Status = "Complete", Player = player, Path = path, Level = level, Name = levelName, Fields = customFields })
		end,
		LogCustomEvent = function() end,
		LogProgressionEvent = function() end,
	}
	classMethods.TweenService = {
		Create = function(_s, inst, info, goals)
			assert(instances[inst], "TweenService:Create expects an Instance")
			assert(mockTypeof(info) == "TweenInfo", "TweenService:Create expects TweenInfo")
			for k, v in goals do
				-- validates property names / types now, like the engine does
				local kind = memberKind(instances[inst].className, k)
				if kind == nil then
					error("TweenService:Create property named '" .. k .. "' cannot be tweened", 2)
				end
				local _ = v
			end
			local completed = newSignal("Completed")
			return {
				Completed = completed,
				Play = function()
					for k, v in goals do
						inst[k] = v
					end
					task.defer(function()
						completed:_fire(Enum.PlaybackState.Completed)
					end)
				end,
				Cancel = function() end,
				Pause = function() end,
				Destroy = function() end,
			}
		end,
	}
	local ws = workspace
	return game, ws
end

-- Character -----------------------------------------------------------------------------------

function Mock.SpawnCharacter(player, position)
	local p = instances[player]
	local old = p.props.Character
	if old then
		methods.Destroy(old)
	end
	for _, c in methods.GetChildren(player) do
		if instances[c].className == "Backpack" then
			methods.Destroy(c)
		end
	end
	local backpack = newInstance("Backpack")
	setParent(instances[backpack], player)
	local character = newInstance("Model")
	instances[character].props.Name = p.props.Name
	local root = newInstance("Part")
	instances[root].props.Name = "HumanoidRootPart"
	instances[root].props.Size = v3(2, 2, 1)
	local pos = position or v3(0, 1027, 4)
	instances[root].props.CFrame = CFrame.new(pos)
	setParent(instances[root], character)
	local head = newInstance("Part")
	instances[head].props.Name = "Head"
	instances[head].props.CFrame = CFrame.new(pos + v3(0, 2, 0))
	setParent(instances[head], character)
	local humanoid = newInstance("Humanoid")
	setParent(instances[humanoid], character)
	instances[character].props.PrimaryPart = root
	p.props.Character = character
	setParent(instances[character], getService("Workspace"))
	getEventSignal(p, "CharacterAdded"):_fire(character)
	return character
end

-- Adds an R15 body (default block proportions: parts, Motor6D joints with the engine's rig
-- attachment C0/C1 values, grip attachments) to a character made by SpawnCharacter.
-- Returns { [jointName] = Motor6D, [partName] = BasePart }.
function Mock.MakeR15(character)
	local rig = {}
	local humanoid = methods.FindFirstChildOfClass(character, "Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	local root = methods.FindFirstChild(character, "HumanoidRootPart")
	rig.HumanoidRootPart = root
	local function limb(name, size)
		local p = methods.FindFirstChild(character, name)
		if not p then
			p = newInstance("Part")
			instances[p].props.Name = name
			setParent(instances[p], character)
		end
		instances[p].props.Size = size
		instances[p].props.CanCollide = false
		rig[name] = p
		return p
	end
	local function joint(name, part0, part1, c0, c1)
		local m = newInstance("Motor6D")
		local props = instances[m].props
		props.Name = name
		props.Part0 = part0
		props.Part1 = part1
		props.C0 = c0
		props.C1 = c1
		setParent(instances[m], part1)
		rig[name] = m
		-- place Part1 in its rest pose
		instances[part1].props.CFrame = instances[part0].props.CFrame * c0 * c1:Inverse()
		return m
	end
	local function attachment(parentPart, name, cframe)
		local a = newInstance("Attachment")
		local props = instances[a].props
		props.Name = name
		props.CFrame = cframe
		props.Position = cframe.Position
		setParent(instances[a], parentPart)
		rig[name] = a
		return a
	end
	local lower = limb("LowerTorso", v3(2, 0.4, 1))
	local upper = limb("UpperTorso", v3(2, 1.6, 1))
	local head = limb("Head", v3(2, 1, 1))
	joint("Root", root, lower, CFrame.new(0, -1, 0), CFrame.new(0, -0.2, 0))
	joint("Waist", lower, upper, CFrame.new(0, 0.2, 0), CFrame.new(0, -0.8, 0))
	joint("Neck", upper, head, CFrame.new(0, 0.8, 0), CFrame.new(0, -0.5, 0))
	for _, side in { { "Right", 1 }, { "Left", -1 } } do
		local s, x = side[1], side[2]
		local ua = limb(s .. "UpperArm", v3(1, 1.169, 1))
		local la = limb(s .. "LowerArm", v3(1, 1.052, 1))
		local hand = limb(s .. "Hand", v3(1, 0.3, 1))
		joint(s .. "Shoulder", upper, ua, CFrame.new(x, 0.563, 0), CFrame.new(-0.5 * x, 0.394, 0))
		joint(s .. "Elbow", ua, la, CFrame.new(0, -0.334, 0), CFrame.new(0, 0.259, 0))
		joint(s .. "Wrist", la, hand, CFrame.new(0, -0.501, 0), CFrame.new(0, 0.125, 0))
		attachment(hand, s .. "GripAttachment", CFrame.new(0, -0.15, 0) * CFrame.Angles(-math.pi / 2, 0, 0))
		local ul = limb(s .. "UpperLeg", v3(1, 1.217, 1))
		joint(s .. "Hip", lower, ul, CFrame.new(0.5 * x, -0.2, 0), CFrame.new(0, 0.42, 0))
	end
	return rig
end

function Mock.AddPlayer(userId, name)
	local player = newInstance("Player")
	local p = instances[player]
	p.props.Name = name
	p.props.DisplayName = name
	p.props.UserId = userId
	p.props.MembershipType = Enum.MembershipType.None
	p.props.AccountAge = 30
	setParent(p, getService("Players"))
	getEventSignal(instances[getService("Players")], "PlayerAdded"):_fire(player)
	return player
end

function Mock.RemovePlayer(player)
	getEventSignal(instances[getService("Players")], "PlayerRemoving"):_fire(player)
	local character = instances[player].props.Character
	setParent(instances[player], nil)
	if character then
		methods.Destroy(character)
	end
end

function Mock.FireTouched(part, hit)
	getEventSignal(instances[part], "Touched"):_fire(hit)
end

function Mock.FindRemote(name)
	local shared = methods.FindFirstChild(getService("ReplicatedStorage"), "Shared")
	local remotes = methods.FindFirstChild(shared, "Remotes")
	local folder = methods.FindFirstChild(remotes, "Net")
	assert(folder, "Remotes.Net folder missing")
	local remote = methods.FindFirstChild(folder, name)
	assert(remote, "remote " .. name .. " missing")
	return remote
end

function Mock.Internal(inst)
	return instances[inst]
end

-- v2.3 streaming simulation (client mode). StreamOut(inst) removes `inst` the way the engine does
-- when it leaves the client's streaming radius: the client's copy is destroyed (Destroying,
-- CollectionService InstanceRemoved, Parent locked). StreamIn(token) brings it back as a NEW
-- instance (a clone with the same tags/attributes/children) under the same parent, which is what
-- client code must cope with: never cache streamed instances across a stream-out.
function Mock.StreamOut(inst)
	local self = instances[inst]
	local parent = self.parent and self.parent.proxy
	local copy = methods.Clone(inst)
	methods.Destroy(inst)
	return { Copy = copy, Parent = parent }
end

function Mock.StreamIn(token)
	token.Copy.Parent = token.Parent
	return token.Copy
end

function Mock.Tagged(t)
	return classMethods.CollectionService.GetTagged(nil, t)
end

-- Client mode -----------------------------------------------------------------------------------

local function makeRay(origin, direction)
	return tag({ Origin = origin, Direction = direction, Unit = nil }, "Ray")
end

classMethods.Camera = {
	ViewportPointToRay = function(cam, x, y, depth)
		local self = instances[cam]
		local vs = self.props.ViewportSize
		local cframe = self.props.CFrame
		local aspect = vs.X / vs.Y
		local tanY = math.tan(math.rad(self.props.FieldOfView) / 2)
		local nx = (x / vs.X) * 2 - 1
		local ny = 1 - (y / vs.Y) * 2
		local dir = cframe:VectorToWorldSpace(v3(nx * tanY * aspect, ny * tanY, -1).Unit)
		return makeRay(cframe.Position + dir * (depth or 0), dir)
	end,
	ScreenPointToRay = function(cam, x, y, depth)
		return classMethods.Camera.ViewportPointToRay(cam, x, y + 58, depth)
	end,
	WorldToViewportPoint = function(cam, pos)
		local self = instances[cam]
		local vs = self.props.ViewportSize
		local rel = self.props.CFrame:PointToObjectSpace(pos)
		local tanY = math.tan(math.rad(self.props.FieldOfView) / 2)
		local aspect = vs.X / vs.Y
		local z = -rel.Z
		if z <= 0 then
			return v3(0, 0, z), false
		end
		local nx = rel.X / (z * tanY * aspect)
		local ny = rel.Y / (z * tanY)
		return v3((nx + 1) / 2 * vs.X, (1 - ny) / 2 * vs.Y, z), math.abs(nx) <= 1 and math.abs(ny) <= 1
	end,
}
classMethods.Camera.WorldToScreenPoint = classMethods.Camera.WorldToViewportPoint

local function raycastTerrain(origin, direction, params)
	local length = direction.Magnitude
	if length == 0 then
		return nil
	end
	local unit = direction / length
	local ignoreWater = params and params.IgnoreWater
	local t = 0
	while t <= length do
		local p = origin + unit * t
		local v = voxels[vkey(math.floor(p.X / VOXEL), math.floor(p.Y / VOXEL), math.floor(p.Z / VOXEL))]
		if v and not (ignoreWater and v.Material.Name == "Water") then
			local cellBottom = math.floor(p.Y / VOXEL) * VOXEL
			if p.Y <= cellBottom + v.Occupancy * VOXEL then
				return tag({
					Position = p,
					Instance = instances[services.Workspace].props.Terrain,
					Material = v.Material,
					Normal = v3(0, 1, 0),
					Distance = t,
				}, "RaycastResult")
			end
		end
		t += 0.25
	end
	return nil
end
Mock.RaycastTerrain = raycastTerrain

local function stub(value)
	return function()
		return value
	end
end

classMethods.Sound = {
	Play = function(snd)
		instances[snd].props.IsPlaying = true
		instances[snd].props.Playing = true
	end,
	Stop = function(snd)
		instances[snd].props.IsPlaying = false
		instances[snd].props.Playing = false
	end,
	Pause = stub(nil),
	Resume = stub(nil),
}
classMethods.ParticleEmitter = { Emit = stub(nil), Clear = stub(nil) }
classMethods.GuiObject = {
	TweenPosition = stub(true),
	TweenSize = stub(true),
	TweenSizeAndPosition = stub(true),
}
classMethods.ScrollingFrame = {}
classMethods.Debris = {
	AddItem = function(_s, item, lifetime)
		task.delay(lifetime or 10, function()
			if instances[item] and not instances[item].destroyed then
				methods.Destroy(item)
			end
		end)
	end,
}
classMethods.ContextActionService = {
	BindAction = function(_s, name, fn, _touch, ...)
		Mock.Actions[name] = { Fn = fn, Keys = { ... } }
	end,
	BindActionAtPriority = function(_s, name, fn, _touch, _priority, ...)
		Mock.Actions[name] = { Fn = fn, Keys = { ... } }
	end,
	UnbindAction = function(_s, name)
		Mock.Actions[name] = nil
	end,
	SetTitle = stub(nil),
	SetImage = stub(nil),
	SetPosition = stub(nil),
	GetButton = stub(nil),
}
Mock.Actions = {}
classMethods.GuiService = {
	GetGuiInset = function()
		return v2(0, 58), v2(0, 0)
	end,
	IsTenFootInterface = stub(false),
}
classMethods.SoundService = { PlayLocalSound = stub(nil) }
-- SocialService (game invites): Mock.CanInvite = false -> CanSendGameInviteAsync answers false;
-- Mock.InviteFail = true -> both calls throw. Opened prompts land in Mock.Invites.
Mock.Invites = {}
Mock.CanInvite = true
Mock.InviteFail = false
classMethods.SocialService = {
	CanSendGameInviteAsync = function(_s, player)
		assert(instances[player] and instances[player].className == "Player", "CanSendGameInviteAsync: Player expected")
		if Mock.InviteFail then
			error("HTTP 500 (mock invite failure)", 2)
		end
		return Mock.CanInvite ~= false
	end,
	PromptGameInvite = function(_s, player)
		assert(instances[player] and instances[player].className == "Player", "PromptGameInvite: Player expected")
		if Mock.InviteFail then
			error("HTTP 500 (mock invite failure)", 2)
		end
		table.insert(Mock.Invites, player)
	end,
}
classMethods.TextService = {
	GetTextSize = function(_s, text, size)
		return v2(#tostring(text) * size * 0.5, size)
	end,
}
classMethods.StarterGui = { SetCoreGuiEnabled = stub(nil), SetCore = stub(nil), GetCore = stub(nil) }
classMethods.UserInputService = {
	GetMouseLocation = function()
		return Mock.MouseLocation
	end,
	GetLastInputType = function()
		return Enum.UserInputType.MouseButton1
	end,
	IsKeyDown = stub(false),
	GetConnectedGamepads = stub({}),
	GetFocusedTextBox = stub(nil),
}
Mock.MouseLocation = v2(640, 360)

function Mock.Input(inputType, keyCode, position)
	local input = newInstance("InputObject")
	local node = instances[input]
	node.props.UserInputType = inputType
	node.props.KeyCode = keyCode or Enum.KeyCode.Unknown
	node.props.UserInputState = Enum.UserInputState.Begin
	node.props.Position = position or v3(Mock.MouseLocation.X, Mock.MouseLocation.Y - 58, 0)
	node.props.Delta = v3(0, 0, 0)
	return input
end

function Mock.FireEvent(inst, eventName, ...)
	getEventSignal(instances[inst], eventName):_fire(...)
end

-- Engine texture completion may not emit a property-change event for cached images.
function Mock.LoadImage(inst)
	local node = instances[inst]
	assert(isA(node.className, "ImageLabel") or isA(node.className, "ImageButton"))
	node.props.IsLoaded = true
end

local function setupClient(workspace)
	local camera = newInstance("Camera")
	local cam = instances[camera]
	cam.props.Name = "Camera"
	cam.props.CFrame = CFrame.new(0, 1040, 30)
	cam.props.ViewportSize = v2(1280, 720)
	cam.props.FieldOfView = 70
	setParent(cam, workspace)
	instances[workspace].props.CurrentCamera = camera
	classMethods.Workspace.Raycast = function(_w, origin, direction, params)
		return raycastTerrain(origin, direction, params)
	end
	local uis = instances[getService("UserInputService")]
	uis.props.MouseEnabled = true
	uis.props.KeyboardEnabled = true
	uis.props.TouchEnabled = false
	uis.props.GamepadEnabled = false
	uis.props.MouseBehavior = Enum.MouseBehavior.Default
	getService("ContextActionService")
	getService("GuiService")
	getService("Debris")
	getService("SoundService")
	getService("TextService")
	getService("StarterGui")
end

function Mock.AddLocalPlayer(userId, name)
	local player = newInstance("Player")
	local p = instances[player]
	p.props.Name = name
	p.props.DisplayName = name
	p.props.UserId = userId
	p.props.MembershipType = Enum.MembershipType.None
	local gui = newInstance("PlayerGui")
	instances[gui].props.Name = "PlayerGui"
	setParent(instances[gui], player)
	local scripts = newInstance("PlayerScripts")
	instances[scripts].props.Name = "PlayerScripts"
	setParent(instances[scripts], player)
	local players = getService("Players")
	instances[players].props.LocalPlayer = player
	setParent(p, players)
	return player
end

-- Module loading --------------------------------------------------------------------------------

local env
local moduleCache = {}
local sourceOf = {}

local function makeEnv(scriptInst)
	return setmetatable({ script = scriptInst }, { __index = env })
end

local function mockRequire(moduleScript)
	if type(moduleScript) == "string" or type(moduleScript) == "number" then
		error("require(" .. tostring(moduleScript) .. "): asset/path requires are not allowed", 2)
	end
	local node = instances[moduleScript]
	assert(node and node.className == "ModuleScript", "require expects a ModuleScript")
	local cached = moduleCache[moduleScript]
	if cached then
		if cached.loading then
			error("Recursive require detected: " .. methods.GetFullName(moduleScript), 2)
		end
		return cached.value
	end
	local entry = { loading = true }
	moduleCache[moduleScript] = entry
	local src = sourceOf[moduleScript]
	local fn, err = loadstring(src, "=" .. methods.GetFullName(moduleScript))
	if not fn then
		error(err, 2)
	end
	setfenv(fn, makeEnv(moduleScript))
	local results = table.pack(fn())
	if results.n ~= 1 then
		error("Module code did not return exactly one value: " .. methods.GetFullName(moduleScript), 2)
	end
	entry.value = results[1]
	entry.loading = false
	return entry.value
end

function Mock.RunScript(scriptInst)
	local fn, err = loadstring(sourceOf[scriptInst], "=" .. methods.GetFullName(scriptInst))
	assert(fn, err)
	setfenv(fn, makeEnv(scriptInst))
	return task.spawn(fn)
end

function Mock.Require(inst)
	return mockRequire(inst)
end

Mock.RenderSteps = {}

function Mock.Init(generated, opts)
	G = generated
	Mock.ClientMode = opts ~= nil and opts.Client == true
	buildEnums()
	local g, workspace = buildGame()
	env = setmetatable({
		game = g,
		workspace = workspace,
		Workspace = workspace,
		shared = {},
		script = nil,
		require = mockRequire,
		task = task,
		os = mockOs,
		-- MicroProfiler markers are engine-only; retain CLI debug helpers for stack traces.
		debug = setmetatable({
			profilebegin = function(label)
				table.insert(Mock.ProfileStack, label)
				table.insert(Mock.ProfileEvents, { Begin = label })
			end,
			profileend = function()
				assert(#Mock.ProfileStack > 0, "unmatched profileend")
				table.insert(Mock.ProfileEvents, { End = table.remove(Mock.ProfileStack) })
			end,
		}, { __index = debug }),
		typeof = mockTypeof,
		warn = mockWarn,
		print = mockPrint,
		tick = function()
			return EPOCH + clock - 1000
		end,
		time = function()
			return clock
		end,
		wait = function(t)
			return task.wait(t)
		end,
		delay = task.delay,
		spawn = task.defer,
		elapsedTime = function()
			return clock
		end,
		Instance = {
			new = function(className, parent)
				local inst = newInstance(className)
				if parent then
					inst.Parent = parent
				end
				return inst
			end,
		},
		Enum = Enum,
		Vector3 = Vector3,
		Vector2 = Vector2,
		CFrame = CFrame,
		Color3 = Color3,
		UDim = UDim,
		UDim2 = UDim2,
		Rect = Rect,
		NumberRange = NumberRange,
		NumberSequence = NumberSequence,
		NumberSequenceKeypoint = NumberSequenceKeypoint,
		ColorSequence = ColorSequence,
		ColorSequenceKeypoint = ColorSequenceKeypoint,
		PhysicalProperties = PhysicalProperties,
		Font = Font,
		BrickColor = BrickColor,
		TweenInfo = TweenInfo,
		Region3 = Region3,
		RaycastParams = RaycastParams,
		OverlapParams = OverlapParams,
		Random = Random,
	}, { __index = _G })
	Mock.Env = env
	if Mock.ClientMode then
		setupClient(workspace)
	end
	Mock.Enum = Enum
	Mock.Vector3 = Vector3
	Mock.Vector2 = Vector2
	Mock.CFrame = CFrame
	Mock.Game = g

	heartbeatFire = function(dt)
		local rs = services.RunService
		if rs then
			local node = instances[rs]
			if Mock.ClientMode then
				for _, fn in Mock.RenderSteps do
					task.spawn(fn, dt)
				end
				if node.events.RenderStepped then
					node.events.RenderStepped:_fire(dt)
				end
			end
			if node.events.Heartbeat then
				node.events.Heartbeat:_fire(dt)
			end
			if node.events.Stepped then
				node.events.Stepped:_fire(clock, dt)
			end
		end
	end

	-- Build the Rojo tree
	local roots = {
		ReplicatedStorage = getService("ReplicatedStorage"),
		ServerScriptService = getService("ServerScriptService"),
		StarterPlayer = getService("StarterPlayer"),
	}
	local byPath = {}
	for _, entry in G.Sources do
		local path = entry.Path
		local parent
		if #path == 2 then
			parent = roots[path[1]]
		elseif path[1] == "StarterPlayer" and #path == 3 then
			parent = byPath["StarterPlayer/StarterPlayerScripts"]
			if not parent then
				parent = newInstance("StarterPlayerScripts")
				instances[parent].props.Name = "StarterPlayerScripts"
				setParent(instances[parent], roots.StarterPlayer)
				byPath["StarterPlayer/StarterPlayerScripts"] = parent
			end
		else
			parent = byPath[table.concat(path, "/", 1, #path - 1)]
		end
		assert(parent, "no parent for " .. table.concat(path, "/"))
		local inst = newInstance(entry.Class)
		instances[inst].props.Name = path[#path]
		setParent(instances[inst], parent)
		byPath[table.concat(path, "/")] = inst
		if entry.Source then
			sourceOf[inst] = entry.Source
		end
	end
	Mock.ByPath = byPath
	return env
end

function Mock.Service(name)
	return getService(name)
end

function Mock.RunBindToClose()
	for _, fn in Mock.BindToClose do
		task.spawn(fn)
	end
end

return Mock
