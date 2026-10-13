--[[
	StormSky: the Eternal Storm's sky full of space, made from parts and Roblox's own effects (nothing
	to upload), on this client only - over the normal sky or the uploaded cosmic one (client/StormFX).

	  * three spiral galaxies in different colours (pink and violet, cyan and blue, gold and peach),
	    each a white-hot core in a glowing disk with two arms of stars, slowly turning
	  * two clouds of glowing nebula that slowly breathe
	  * a ringed planet with a little moon
	  * a field of twinkling stars all round the sky
	  * aurora ribbons of purple, cyan and pink light waving across it
	Everything hangs far away in fixed directions and moves with your camera (so it looks as far away
	as the stars). It fades in as the storm's black hole tears open, and out when the storm ends.

	  StormSky.Start(delay)  StormSky.Stop()  StormSky.Step(dt) (every frame, from StormFX)
]]

local StormSky = {}

local rgb = Color3.fromRGB
local TAU = math.pi * 2
local WHITE = rgb(255, 255, 255)
local STAR_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

type Piece = { Part: BasePart, Group: number, Local: CFrame, Base: number }
type Group = { Frame: CFrame, Spin: number, Turn: number, Pulse: number }
type Ribbon = { Beam: Beam, Phase: number, Curve: number }

local folder: Folder? = nil
local anchor: BasePart? = nil
local pieces: { Piece } = {}
local groups: { Group } = {}
local ribbons: { Ribbon } = {}
local parts: { BasePart } = {}
local frames: { CFrame } = {}
local fade = 0 -- 0 (gone) .. 1 (all there)
local fadeGoal = 0
local fadeStart = 0
local clock = 0
local bulkMove = true

-- The frame of something `distance` studs away, `turn` degrees round from straight ahead (+Z) and
-- `up` degrees up, tipped so you see it at a slant: `tip` degrees about the line to it.
local function skyFrame(distance: number, turn: number, up: number, tip: number, roll: number): CFrame
	local direction = CFrame.Angles(0, math.rad(turn), 0) * CFrame.Angles(math.rad(-up), 0, 0)
	local center = direction:VectorToWorldSpace(Vector3.new(0, 0, distance))
	-- face back at you, then tip it
	return CFrame.lookAt(center, Vector3.zero) * CFrame.Angles(math.rad(90 - tip), 0, math.rad(roll))
end

local function piece(name: string, size: Vector3, group: number, localFrame: CFrame, color: Color3, transparency: number, shape: Enum.PartType?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.Transparency = 1
	if shape then
		p.Shape = shape
	end
	p.Parent = folder
	table.insert(pieces, { Part = p, Group = group, Local = localFrame, Base = transparency })
	table.insert(parts, p)
	table.insert(frames, CFrame.identity)
	return p
end

-- A spiral galaxy: a core, a glowing disk, arms of stars winding out from it.
local function galaxy(frame: CFrame, radius: number, core: Color3, arm: Color3, edge: Color3, spin: number, arms: number)
	table.insert(groups, { Frame = frame, Spin = spin, Turn = math.random() * TAU, Pulse = 0 })
	local g = #groups
	-- (the disk lies flat in the group's XZ plane)
	piece("GalaxyHalo", Vector3.new(radius * 0.06, radius * 2.1, radius * 2.1), g, CFrame.Angles(0, 0, math.pi / 2), arm, 0.9, Enum.PartType.Cylinder)
	piece("GalaxyDisk", Vector3.new(radius * 0.08, radius * 1.1, radius * 1.1), g, CFrame.Angles(0, 0, math.pi / 2), core:Lerp(arm, 0.4), 0.72, Enum.PartType.Cylinder)
	piece("GalaxyCore", Vector3.one * radius * 0.26, g, CFrame.identity, WHITE:Lerp(core, 0.25), 0.05, Enum.PartType.Ball)
	piece("GalaxyCoreGlow", Vector3.one * radius * 0.46, g, CFrame.identity, core, 0.55, Enum.PartType.Ball)
	local stars = if arms > 2 then 14 else 20
	for side = 0, arms - 1 do
		for i = 1, stars do
			local u = i / stars
			local angle = side * TAU / arms + u * 3.6 -- (winding out)
			local r = radius * (0.14 + 0.86 * u)
			local size = radius * (0.11 - 0.07 * u)
			local color = arm:Lerp(edge, u)
			piece("GalaxyArm", Vector3.one * size, g, CFrame.new(math.cos(angle) * r, 0, math.sin(angle) * r), color, 0.15 + 0.6 * u, Enum.PartType.Ball)
		end
	end
end

-- A nebula: a cloud of big, faint glowing balls, breathing slowly.
local function nebula(frame: CFrame, radius: number, colors: { Color3 }, seed: number)
	table.insert(groups, { Frame = frame, Spin = 0, Turn = 0, Pulse = seed })
	local g = #groups
	local rng = Random.new(seed)
	-- (each puff is a few balls inside each other, brighter in the middle: soft, like a cloud)
	for i = 1, 5 do
		local offset = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.25, 0.25), rng:NextNumber(-1, 1)) * radius * 0.7
		local size = radius * rng:NextNumber(0.55, 0.9)
		local color = colors[(i - 1) % #colors + 1]
		for k, shell in { { 1, 0.94 }, { 0.68, 0.9 }, { 0.38, 0.84 } } do
			piece("Nebula", Vector3.one * size * shell[1], g, CFrame.new(offset), color:Lerp(WHITE, (k - 1) * 0.15), shell[2], Enum.PartType.Ball)
		end
	end
end

-- A planet with a ring, and its moon.
local function planet(frame: CFrame, radius: number)
	table.insert(groups, { Frame = frame, Spin = 0.02, Turn = 0, Pulse = 0 })
	local g = #groups
	piece("PlanetRing", Vector3.new(radius * 0.05, radius * 4.4, radius * 4.4), g, CFrame.Angles(0, 0, math.pi / 2), rgb(255, 196, 140), 0.45, Enum.PartType.Cylinder)
	piece("PlanetRingInner", Vector3.new(radius * 0.06, radius * 2.7, radius * 2.7), g, CFrame.Angles(0, 0, math.pi / 2), rgb(60, 30, 90), 0.2, Enum.PartType.Cylinder)
	local body = piece("Planet", Vector3.one * radius * 2, g, CFrame.identity, rgb(130, 90, 230), 0, Enum.PartType.Ball)
	body.Material = Enum.Material.SmoothPlastic
	piece("PlanetGlow", Vector3.one * radius * 2.25, g, CFrame.identity, rgb(170, 120, 255), 0.8, Enum.PartType.Ball)
	piece("Moon", Vector3.one * radius * 0.5, g, CFrame.new(radius * 3.2, radius * 0.9, -radius * 0.6), rgb(225, 225, 255), 0.05, Enum.PartType.Ball)
end

local function stars(parent: BasePart)
	for i, color in { WHITE, rgb(200, 220, 255), rgb(255, 210, 240) } do
		local e = Instance.new("ParticleEmitter")
		e.Name = "Stars" .. i
		e.Texture = STAR_TEXTURE
		e.Shape = Enum.ParticleEmitterShape.Sphere
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		e.LockedToPart = true
		e.Speed = NumberRange.new(0)
		e.Lifetime = NumberRange.new(5, 9)
		e.Rate = 14
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.15, 14), NumberSequenceKeypoint.new(0.5, 9), NumberSequenceKeypoint.new(0.85, 15), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new(0.1)
		e.Color = ColorSequence.new(color)
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Brightness = 3
		e.Parent = parent
	end
end

-- Aurora ribbons: long bands of light between two points in the sky, waving.
local function aurora(parent: BasePart)
	local colors = {
		{ rgb(170, 60, 255), rgb(80, 220, 255) },
		{ rgb(80, 220, 255), rgb(255, 120, 220) },
		{ rgb(255, 120, 220), rgb(170, 60, 255) },
	}
	for i, pair in colors do
		local a0 = Instance.new("Attachment")
		local a1 = Instance.new("Attachment")
		local turn = math.rad(-70 + i * 45)
		local up = 0.42 + i * 0.07
		a0.Position = Vector3.new(math.sin(turn) * 900, 900 * up, math.cos(turn) * 900)
		a1.Position = Vector3.new(math.sin(turn + 1.4) * 900, 900 * (up + 0.1), math.cos(turn + 1.4) * 900)
		a0.Parent = parent
		a1.Parent = parent
		local beam = Instance.new("Beam")
		beam.Name = "Aurora"
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Color = ColorSequence.new(pair[1], pair[2])
		beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.55), NumberSequenceKeypoint.new(0.8, 0.55), NumberSequenceKeypoint.new(1, 1) })
		beam.Width0, beam.Width1 = 160, 220
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Segments = 24
		beam.FaceCamera = true
		beam.Enabled = false
		beam.Parent = parent
		table.insert(ribbons, { Beam = beam, Phase = i * 1.7, Curve = 160 + i * 40 })
	end
end

local function build()
	local f = Instance.new("Folder")
	f.Name = "StormSkyDressing"
	f.Parent = workspace
	folder = f
	galaxy(skyFrame(1350, 160, 34, 35, 10), 330, rgb(255, 150, 230), rgb(190, 90, 255), rgb(90, 60, 200), 0.05, 2)
	galaxy(skyFrame(1250, -95, 46, 50, -20), 260, rgb(170, 240, 255), rgb(70, 170, 255), rgb(40, 70, 190), -0.07, 3)
	galaxy(skyFrame(1300, 65, 22, 28, 30), 210, rgb(255, 235, 170), rgb(255, 170, 90), rgb(220, 90, 120), 0.09, 2)
	nebula(skyFrame(1200, -40, 62, 0, 0), 300, { rgb(160, 70, 255), rgb(255, 90, 200), rgb(90, 140, 255) }, 7)
	nebula(skyFrame(1250, 120, 14, 0, 0), 260, { rgb(60, 200, 220), rgb(120, 90, 255), rgb(60, 120, 200) }, 19)
	planet(skyFrame(1100, -150, 20, 70, 18), 60)
	local a = Instance.new("Part")
	a.Name = "SkyAnchor"
	a.Anchored = true
	a.CanCollide = false
	a.CanQuery = false
	a.CanTouch = false
	a.CastShadow = false
	a.Transparency = 1
	a.Size = Vector3.one * 1500 -- (the star field: on the surface of a ball this big round you)
	a.Shape = Enum.PartType.Ball
	a.Parent = f
	anchor = a
	stars(a)
	aurora(a)
end

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

function StormSky.Start(delay: number?)
	if not folder then
		build()
	end
	fadeGoal = 1
	fadeStart = os.clock() + (delay or 0)
end

function StormSky.Stop()
	fadeGoal = 0
	fadeStart = os.clock()
end

function StormSky.IsShowing(): boolean
	return folder ~= nil and fade > 0.01
end

local function clear()
	if folder then
		folder:Destroy()
	end
	folder, anchor = nil, nil
	table.clear(pieces)
	table.clear(groups)
	table.clear(ribbons)
	table.clear(parts)
	table.clear(frames)
	fade = 0
end

function StormSky.Step(dt: number)
	if not folder then
		return
	end
	local now = os.clock()
	clock += dt
	-- fading in (over 3 seconds, once it's time) or out (over 2)
	if now >= fadeStart then
		local rate = if fadeGoal > fade then 1 / 3 else 1 / 2
		fade = if fadeGoal > fade then math.min(fadeGoal, fade + dt * rate) else math.max(fadeGoal, fade - dt * rate)
	end
	if fadeGoal == 0 and fade <= 0 then
		clear()
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local origin = CFrame.new(camera.CFrame.Position)
	local shown = smooth(fade)
	for _, g in groups do
		g.Turn += g.Spin * dt
	end
	for i, p in pieces do
		local g = groups[p.Group]
		frames[i] = origin * g.Frame * CFrame.Angles(0, g.Turn, 0) * p.Local
		local breathe = if g.Pulse ~= 0 then 0.03 * math.sin(clock * 0.6 + g.Pulse + i) else 0
		p.Part.Transparency = 1 - (1 - math.clamp(p.Base + breathe, 0, 1)) * shown
	end
	if bulkMove then
		local ok = pcall(function()
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end)
		bulkMove = ok
	end
	if not bulkMove then
		for i, p in parts do
			p.CFrame = frames[i]
		end
	end
	if anchor then
		anchor.CFrame = origin
		for _, e in anchor:GetChildren() do
			if e:IsA("ParticleEmitter") then
				e.Enabled = shown > 0.3
			end
		end
	end
	for _, r in ribbons do
		r.Beam.Enabled = shown > 0.05
		r.Beam.CurveSize0 = r.Curve * math.sin(clock * 0.35 + r.Phase)
		r.Beam.CurveSize1 = -r.Curve * math.sin(clock * 0.3 + r.Phase * 1.3)
		local a = 1 - 0.45 * shown
		r.Beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, a), NumberSequenceKeypoint.new(0.8, a), NumberSequenceKeypoint.new(1, 1) })
	end
end

-- (gone straight away, no fading)
function StormSky.Clear()
	clear()
	fadeGoal = 0
end

return StormSky
