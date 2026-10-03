--[[
	Roam: where a donut in a base pen is at any moment (bases are open pens where donuts wander
	around, like Steal an Egg).

	The server (to check that a thief is really next to a donut) and every client (which moves the
	donuts: client/DonutIdle.luau) work it out from the same numbers and the shared server clock
	(workspace:GetServerTimeNow()), so everyone sees every donut in the same place and nothing is
	sent over the network.

	Each donut wanders around the middle of its own patch of the pen (Home, within Radius, never
	past the pen's fence). Its time is cut into legs of a few seconds: it stands still for a while
	(doing its idle animations), turns, and walks to the next spot just in time for the next leg.
	The spots come from an integer hash of its seed and the leg number, so every device gets exactly
	the same ones.
]]

local Roam = {}

export type Params = {
	Seed: number,
	Home: Vector3, -- plot space, on the ground
	Radius: number,
	Speed: number, -- studs per second
	Min: Vector2, -- the pen (plot space X, Z) minus a margin: donuts never walk past it
	Max: Vector2,
}

export type State = {
	Position: Vector3, -- plot space, on the ground
	Yaw: number, -- facing (plot space; 0 = towards the front of the base)
	Walk: number, -- studs walked so far in this stride (0 while standing)
	Moving: boolean,
}

local TWO32 = 4294967296
local TURN = 0.7 -- seconds spent turning before setting off
local TAU = math.pi * 2

-- 32-bit multiply without losing precision in a double.
local function mul32(a: number, b: number): number
	local low, high = a % 65536, a // 65536
	return (low * b + ((high * b) % 65536) * 65536) % TWO32
end

-- A number in [0, 1) from three integers (the murmur3 finaliser): the same on every device.
local function hash(seed: number, leg: number, k: number): number
	local h = (seed % 1000003) * 2654 + (leg % 65536) * 7919 + k * 104729
	h = h % TWO32
	h = bit32.bxor(h, bit32.rshift(h, 16))
	h = mul32(h, 0x85ebca6b)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = mul32(h, 0xc2b2ae35)
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return h / TWO32
end

local function legLength(p: Params): number
	return 4 + 3 * hash(p.Seed, 0, 91)
end

-- Where the donut is headed at the end of leg `leg`.
local function waypoint(p: Params, leg: number): Vector3
	local r = p.Radius * math.sqrt(hash(p.Seed, leg, 1))
	local angle = TAU * hash(p.Seed, leg, 2)
	local x = math.clamp(p.Home.X + math.cos(angle) * r, p.Min.X, p.Max.X)
	local z = math.clamp(p.Home.Z + math.sin(angle) * r, p.Min.Y, p.Max.Y)
	return Vector3.new(x, 0, z)
end

local function yawOf(direction: Vector3, fallback: number): number
	if direction.Magnitude < 0.05 then
		return fallback
	end
	return math.atan2(-direction.X, -direction.Z)
end

-- Turn from angle a to angle b the short way round, `alpha` of the way.
local function turnBetween(a: number, b: number, alpha: number): number
	local delta = (b - a + math.pi) % TAU - math.pi
	return a + delta * alpha
end

function Roam.At(p: Params, now: number): State
	local length = legLength(p)
	local shifted = now + hash(p.Seed, 1, 92) * length
	local leg = math.floor(shifted / length)
	local into = shifted - leg * length

	local from = waypoint(p, leg - 1)
	local to = waypoint(p, leg)
	local before = waypoint(p, leg - 2)
	local offset = to - from
	local distance = offset.Magnitude
	local previousYaw = yawOf(from - before, 0)
	local yaw = yawOf(offset, previousYaw)

	-- Walk at Speed, but always arrive before the leg ends
	local walkTime = math.min(distance / math.max(p.Speed, 0.1), length - TURN - 0.5)
	local setOff = length - walkTime
	if into < setOff - TURN or distance < 0.05 then
		return { Position = from, Yaw = previousYaw, Walk = 0, Moving = false }
	elseif into < setOff then
		local alpha = (into - (setOff - TURN)) / TURN
		alpha = alpha * alpha * (3 - 2 * alpha)
		return { Position = from, Yaw = turnBetween(previousYaw, yaw, alpha), Walk = 0, Moving = false }
	end
	local alpha = math.clamp((into - setOff) / walkTime, 0, 1)
	-- ease in and out so it doesn't start or stop dead
	local eased = alpha * alpha * (3 - 2 * alpha)
	return { Position = from + offset * eased, Yaw = yaw, Walk = distance * eased, Moving = alpha < 1 }
end

return Roam
