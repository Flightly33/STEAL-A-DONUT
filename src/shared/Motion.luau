--[[
	Motion: small tools for smooth, natural-looking movement in scripted scenes (client/Intro and
	the bakers):

	  Motion.Smooth(a)            - 0..1 eased in and out, with no jolt at either end (smootherstep)
	  Motion.Spring(x)            - a springy value: Motion.Step(spring, target, dt, freq, damping)
	                                moves it towards target like something with weight (damping < 1
	                                overshoots and settles, 1 just arrives)
	  Motion.Kick(spring, speed)  - shoves a spring (a recoil, a jolt)
	  Motion.Follow(x, goal, dt, halfLife) - eases a number towards a goal (halfway in halfLife s)
	  Motion.Curve(times, values, t) - a smooth curve through keys that never overshoots them (it
	                                slows to a stop where the values turn round, and at both ends)
	  Motion.Noise(t, seed)       - gentle wobble in -1..1 (a hand-held camera, breathing)
	  Motion.Path(points, radius) - a route through points with its corners rounded off;
	                                Motion.PathAt(path, distance) -> where, which way, how sharp a turn
]]

local Motion = {}

function Motion.Smooth(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * a * (a * (a * 6 - 15) + 10)
end

export type Spring = { X: number, V: number }

function Motion.Spring(x: number): Spring
	return { X = x, V = 0 }
end

-- (small fixed steps, so a big frame never makes it blow up)
function Motion.Step(s: Spring, target: number, dt: number, freq: number, damping: number): number
	local w = 2 * math.pi * freq
	local steps = math.max(1, math.ceil(dt * 240))
	local h = dt / steps
	for _ = 1, steps do
		local accel = w * w * (target - s.X) - 2 * damping * w * s.V
		s.V += accel * h
		s.X += s.V * h
	end
	return s.X
end

function Motion.Kick(s: Spring, speed: number)
	s.V += speed
end

function Motion.Follow(x: number, goal: number, dt: number, halfLife: number): number
	return goal + (x - goal) * 0.5 ^ (dt / math.max(halfLife, 1e-4))
end

-- A monotone cubic (PCHIP) through (times[i], values[i]): smooth, passes through every key,
-- and never swings past one. Flat at both ends.
function Motion.Curve(times: { number }, values: { number }, t: number): number
	local n = #times
	if n == 0 then
		return 0
	elseif n == 1 or t <= times[1] then
		return values[1]
	elseif t >= times[n] then
		return values[n]
	end
	local k = 1
	while k < n - 1 and t >= times[k + 1] do
		k += 1
	end
	local function slope(i: number): number
		local h = times[i + 1] - times[i]
		return if h > 1e-6 then (values[i + 1] - values[i]) / h else 0
	end
	local function tangent(i: number): number
		if i <= 1 or i >= n then
			return 0
		end
		local d0, d1 = slope(i - 1), slope(i)
		if d0 * d1 <= 0 then
			return 0
		end
		local h0, h1 = times[i] - times[i - 1], times[i + 1] - times[i]
		local w1, w2 = 2 * h1 + h0, h1 + 2 * h0
		return (w1 + w2) / (w1 / d0 + w2 / d1)
	end
	local h = times[k + 1] - times[k]
	if h <= 1e-6 then
		return values[k + 1]
	end
	local s = (t - times[k]) / h
	local m0, m1 = tangent(k) * h, tangent(k + 1) * h
	local s2, s3 = s * s, s * s * s
	return (2 * s3 - 3 * s2 + 1) * values[k] + (s3 - 2 * s2 + s) * m0 + (-2 * s3 + 3 * s2) * values[k + 1] + (s3 - s2) * m1
end

function Motion.Noise(t: number, seed: number): number
	return (math.sin(t * 1.37 + seed * 1.91) * 0.5 + math.sin(t * 2.71 + seed * 3.17) * 0.3 + math.sin(t * 5.13 + seed * 0.77) * 0.2)
end

export type Path = { Points: { Vector3 }, Lengths: { number }, Length: number }

-- The route through `points`, each corner rounded into a curve `radius` studs before and after it.
function Motion.Path(points: { Vector3 }, radius: number): Path
	local dense: { Vector3 } = { points[1] }
	for i = 2, #points - 1 do
		local a, b, c = points[i - 1], points[i], points[i + 1]
		local r = math.min(radius, (b - a).Magnitude * 0.45, (c - b).Magnitude * 0.45)
		local p0 = b + (a - b).Unit * r
		local p2 = b + (c - b).Unit * r
		table.insert(dense, p0)
		for j = 1, 11 do
			local s = j / 12
			table.insert(dense, p0:Lerp(b, s):Lerp(b:Lerp(p2, s), s))
		end
		table.insert(dense, p2)
	end
	table.insert(dense, points[#points])
	local lengths = { 0 }
	for i = 2, #dense do
		lengths[i] = lengths[i - 1] + (dense[i] - dense[i - 1]).Magnitude
	end
	return { Points = dense, Lengths = lengths, Length = lengths[#lengths] }
end

-- Where you are `distance` along a path, the way it's heading there, and how sharply it turns
-- (radians of turn per stud; + to the left).
function Motion.PathAt(path: Path, distance: number): (Vector3, Vector3, number)
	local pts, lens = path.Points, path.Lengths
	local d = math.clamp(distance, 0, path.Length)
	local i = 1
	while i < #pts - 1 and lens[i + 1] < d do
		i += 1
	end
	local span = math.max(lens[i + 1] - lens[i], 1e-6)
	local pos = pts[i]:Lerp(pts[i + 1], (d - lens[i]) / span)
	local dir = (pts[i + 1] - pts[i]).Unit
	local turn = 0
	if i + 2 <= #pts then
		local nextDir = (pts[i + 2] - pts[i + 1]).Unit
		local cross = dir:Cross(nextDir).Y
		turn = math.asin(math.clamp(cross, -1, 1)) / math.max(lens[i + 2] - lens[i + 1], 1e-3)
	end
	return pos, dir, turn
end

return Motion
