--[[
	MeteorFX: the Cosmic Meteor (shared/Meteor, server/MeteorService), played on every client on
	the server's clock, so everyone sees the same thing at the same moment:

	  0s     the whole screen turns white for 2 seconds (with its sound)
	  2s     everything shakes like crazy
	  2.6s   the sky cracks open like glass where the meteor is coming through, and pieces of sky
	         fall out of it (the sky shatter sound)
	  3.4s   the meteor breaks through: a huge burning space rock falls out of the hole, spinning,
	         with a trail of fire behind it, and a glowing circle on the lane shows where it'll hit
	         (the falling sound)
	  7.4s   it smashes into the lane: a fireball, shock waves, flying rock, a beam of light, and a
	         huge shake (bigger the closer you are; the two impact sounds). The server builds the
	         cracked-open meteor and its shards right then (they're the real thing you can grab).

	Also spins the black hole horizon round The Cosmic Donut floating over the Cosmic Forge
	(tagged "HorizonSpin"; donuts in pens are spun by DonutIdle).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Meteor = require(Shared.Meteor)
local Remotes = require(Shared.Remotes)

local MeteorFX = {}

local rgb = Color3.fromRGB
local TAU = math.pi * 2
local WHITE, VIOLET, PINK, CYAN = rgb(255, 255, 255), rgb(175, 95, 255), rgb(255, 120, 220), rgb(110, 230, 255)
local FIRE, HOT = rgb(255, 150, 60), rgb(255, 230, 170)
local SKY_GLASS = { rgb(150, 190, 255), rgb(190, 165, 255), rgb(120, 160, 235) }
local GRAVITY = Vector3.new(0, -196, 0)
local CRACK_RADIUS = 260 -- studs, the crack in the sky
local HOLE_RADIUS = 80 -- ...and the hole the meteor bursts out of
local SHAKE_HARD = 4 -- the big shake after the white screen
local IMPACT_RANGE = 1600 -- the impact shakes everyone this close (more the closer)

type Piece = { Part: BasePart, Velocity: Vector3, Spin: Vector3, Born: number, Life: number }
type CrackLine = { Part: BasePart, Reveal: number }
type Show = {
	Start: number, -- os.clock() when the white screen comes on
	Landing: Vector3,
	Entry: Vector3,
	Seed: number,
	Done: { [string]: boolean },
	Gui: ScreenGui?,
	White: Frame?,
	Crack: Model?,
	Lines: { CrackLine },
	Hole: BasePart?,
	Rim: BasePart?,
	Rock: Model?,
	Plasma: { BasePart },
	Tail: { BasePart },
	Circle: BasePart?,
	Spin: Vector3,
	Kick: number, -- the impact shake (fades)
	KickAt: number,
}

local folder: Folder
local soundFolder: Folder
local sounds: { [string]: { Sound } } = {}
local current: Show? = nil
local pieces: { Piece } = {}
local rng = Random.new()

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Parent = parent or folder
	return p
end

local function play(name: string, volume: number)
	local list = sounds[name]
	if list then
		for _, s in list do
			s.Volume = volume
			s.TimePosition = 0
			s:Play()
		end
	end
end

local function stop(name: string)
	local list = sounds[name]
	if list then
		for _, s in list do
			s:Stop()
		end
	end
end

-- A ring bursting out along the ground.
local function ring(at: Vector3, radius: number, color: Color3, duration: number, height: number?)
	local disc = part("Shockwave", Vector3.new(0.4, radius * 0.25, radius * 0.25), CFrame.new(at + Vector3.new(0, height or 0.4, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.Material.Neon)
	disc.Shape = Enum.PartType.Cylinder
	disc.Transparency = 0.15
	TweenService:Create(disc, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.4, radius * 2, radius * 2), Transparency = 1 }):Play()
	task.delay(duration + 0.1, function()
		disc:Destroy()
	end)
end

-- Something flying off on its own (pieces of sky, broken rock): falls, spins and fades.
local function fling(p: BasePart, velocity: Vector3, life: number)
	table.insert(pieces, { Part = p, Velocity = velocity, Spin = rng:NextUnitVector() * rng:NextNumber(1, 4), Born = os.clock(), Life = life })
end

local function closeness(at: Vector3, range: number): number
	local camera = workspace.CurrentCamera
	if not camera then
		return 0
	end
	return math.clamp(1 - (camera.CFrame.Position - at).Magnitude / range, 0, 1)
end

--------------------------------------------------------------------------------
-- The white screen
--------------------------------------------------------------------------------
local function whiteScreen(show: Show)
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "MeteorFlash"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.DisplayOrder = 95 -- over everything
	local white = Instance.new("Frame")
	white.Name = "White"
	white.Size = UDim2.fromScale(1, 1)
	white.BackgroundColor3 = WHITE
	white.BackgroundTransparency = 1
	white.BorderSizePixel = 0
	white.Parent = gui
	gui.Parent = playerGui
	show.Gui, show.White = gui, white
end

-- How see-through the white screen is, `t` seconds into the show (it snaps on, stays 2 seconds, and
-- fades away while the shaking starts). Later it flashes again, softer, when the meteor hits.
local function whiteness(show: Show, t: number): number
	local amount = 0
	if t >= 0 and t < Meteor.FLASH then
		amount = math.min(1, t / 0.12)
	elseif t >= Meteor.FLASH and t < Meteor.FLASH + 0.6 then
		amount = 1 - (t - Meteor.FLASH) / 0.6
	end
	-- the meteor bursting through the sky, and hitting the ground
	if t >= Meteor.FALL_AT and t < Meteor.FALL_AT + 0.35 then
		amount = math.max(amount, 0.35 * (1 - (t - Meteor.FALL_AT) / 0.35))
	end
	if t >= Meteor.IMPACT_AT and t < Meteor.IMPACT_AT + 0.6 then
		amount = math.max(amount, (0.25 + 0.55 * closeness(show.Landing, 700)) * (1 - (t - Meteor.IMPACT_AT) / 0.6))
	end
	return 1 - amount
end

--------------------------------------------------------------------------------
-- The sky cracking open
--------------------------------------------------------------------------------
-- A jagged crack line from `a` to `b` (in the crack's own flat plane), with a soft glow round it.
local function crackLine(show: Show, model: Model, frame: CFrame, a: Vector2, b: Vector2, width: number, reveal: number)
	local from = frame:PointToWorldSpace(Vector3.new(a.X, a.Y, 0))
	local to = frame:PointToWorldSpace(Vector3.new(b.X, b.Y, 0))
	local length = (to - from).Magnitude
	if length < 1 then
		return
	end
	local cf = CFrame.lookAt((from + to) / 2, to, frame.LookVector)
	local core = part("Crack", Vector3.new(width, width, length + width), cf, if width > 4 then WHITE else rgb(235, 215, 255), Enum.Material.Neon, model)
	core.Transparency = 1
	table.insert(show.Lines, { Part = core, Reveal = reveal })
	local glow = part("CrackGlow", Vector3.new(width * 3.2, width * 3.2, length + width * 2), cf, if #show.Lines % 4 == 1 then PINK else VIOLET, Enum.Material.Neon, model)
	glow.Transparency = 1
	table.insert(show.Lines, { Part = glow, Reveal = reveal + 0.05 })
end

local function skyShards(show: Show, count: number, from: Vector3, spread: number, frame: CFrame)
	for _ = 1, count do
		local angle = rng:NextNumber(0, TAU)
		local offset = frame:VectorToWorldSpace(Vector3.new(math.cos(angle), math.sin(angle), 0)) * rng:NextNumber(0.2, 1) * spread
		local size = rng:NextNumber(18, 48)
		local wedge = Instance.new("WedgePart")
		wedge.Name = "SkyShard"
		wedge.Anchored = true
		wedge.CanCollide = false
		wedge.CanQuery = false
		wedge.CanTouch = false
		wedge.CastShadow = false
		wedge.Size = Vector3.new(2, size, size * rng:NextNumber(0.5, 1.1))
		wedge.CFrame = CFrame.new(from + offset) * CFrame.Angles(rng:NextNumber(0, TAU), rng:NextNumber(0, TAU), rng:NextNumber(0, TAU))
		-- (glowing pieces of sky, so they show against the dark storm sky)
		wedge.Color = SKY_GLASS[rng:NextInteger(1, #SKY_GLASS)]
		wedge.Material = Enum.Material.Neon
		wedge.Transparency = 0.2
		wedge.Parent = folder
		local velocity = offset.Unit * rng:NextNumber(40, 110) + frame.LookVector * rng:NextNumber(20, 80) + Vector3.new(0, rng:NextNumber(-40, 20), 0)
		fling(wedge, velocity, rng:NextNumber(3.5, 5))
	end
end

local function shatter(show: Show)
	local camera = workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else show.Landing + Vector3.new(0, 20, -400)
	-- the crack is a flat star of broken glass, turned to face you
	local frame = CFrame.lookAt(show.Entry, eye)
	local model = Instance.new("Model")
	model.Name = "SkyCrack"
	local r = Random.new(show.Seed)
	local rays = 10
	local rings: { { Vector2 } } = { {}, {} }
	for i = 1, rays do
		local angle = i / rays * TAU + r:NextNumber(-0.18, 0.18)
		local reach = CRACK_RADIUS * r:NextNumber(0.7, 1.15)
		local point = Vector2.zero
		local steps = 4
		for step = 1, steps do
			local bend = angle + r:NextNumber(-0.35, 0.35)
			local nextPoint = Vector2.new(math.cos(bend), math.sin(bend)) * reach * step / steps
			crackLine(show, model, frame, point, nextPoint, if step <= 2 then 6 else 4, step * 0.06)
			-- little branches off the main crack
			if step >= 2 and r:NextNumber() < 0.7 then
				local side = if r:NextNumber() < 0.5 then 1 else -1
				local branch = bend + side * r:NextNumber(0.5, 0.9)
				crackLine(show, model, frame, nextPoint, nextPoint + Vector2.new(math.cos(branch), math.sin(branch)) * reach * r:NextNumber(0.15, 0.3), 2.5, step * 0.06 + 0.1)
			end
			if step == 1 or step == 3 then
				table.insert(rings[if step == 1 then 1 else 2], nextPoint)
			end
			point = nextPoint
		end
	end
	-- rings of cracks joining the rays up, like a smashed window
	for ringIndex, points in rings do
		for i, a in points do
			local b = points[i % #points + 1]
			local middle = (a + b) / 2 * r:NextNumber(0.85, 1.1)
			crackLine(show, model, frame, a, middle, 3, 0.2 + ringIndex * 0.08)
			crackLine(show, model, frame, middle, b, 3, 0.24 + ringIndex * 0.08)
		end
	end
	-- the hole it bursts out of (opens when it comes through), with a burning edge
	local face = frame * CFrame.Angles(0, math.pi / 2, 0) -- (a cylinder's round faces point along its X)
	local rim = part("HoleRim", Vector3.new(1.5, 1, 1), face * CFrame.new(-1, 0, 0), PINK, Enum.Material.Neon, model)
	rim.Shape = Enum.PartType.Cylinder
	rim.Transparency = 1
	local hole = part("Hole", Vector3.new(2, 1, 1), face, rgb(6, 0, 16), Enum.Material.SmoothPlastic, model)
	hole.Shape = Enum.PartType.Cylinder
	hole.Transparency = 1
	local light = Instance.new("PointLight")
	light.Color = VIOLET
	light.Range = 60
	light.Brightness = 10
	light.Parent = rim
	model.Parent = folder
	show.Crack, show.Hole, show.Rim = model, hole, rim
	skyShards(show, 10, show.Entry, CRACK_RADIUS * 0.7, frame)
	play("Shatter", 1.4)
end

--------------------------------------------------------------------------------
-- The fall
--------------------------------------------------------------------------------
local function emitter(parent: BasePart, texture: string, colors: ColorSequence, size: number, rate: number, life: number, emission: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Color = colors
	e.LightEmission = emission
	e.Rate = rate
	e.Lifetime = NumberRange.new(life * 0.6, life)
	e.Speed = NumberRange.new(4, 14)
	e.SpreadAngle = Vector2.new(30, 30)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 2.2) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.RotSpeed = NumberRange.new(-90, 90)
	e.Parent = parent
	return e
end

local function startFall(show: Show)
	local rock = Meteor.BuildRock(Meteor.SIZE, show.Seed)
	local core = rock.PrimaryPart :: BasePart
	-- burning: two glowing shells of plasma round it, fire and smoke pouring off it, and a light
	type Shell = { Name: string, Scale: number, Color: Color3, Transparency: number }
	local shells: { Shell } = {
		{ Name = "Plasma", Scale = 1.3, Color = FIRE, Transparency = 0.55 },
		{ Name = "PlasmaOuter", Scale = 1.6, Color = PINK, Transparency = 0.78 },
	}
	for _, info in shells do
		local shell = part(info.Name, Vector3.one * Meteor.SIZE * info.Scale, CFrame.identity, info.Color, Enum.Material.Neon)
		shell.Shape = Enum.PartType.Ball
		shell.Transparency = info.Transparency
		table.insert(show.Plasma, shell)
	end
	emitter(core, "rbxasset://textures/particles/fire_main.dds", ColorSequence.new(HOT, FIRE), Meteor.SIZE * 0.55, 70, 1.1, 1)
	emitter(core, "rbxasset://textures/particles/fire_main.dds", ColorSequence.new(PINK, VIOLET), Meteor.SIZE * 0.45, 40, 1.4, 1)
	emitter(core, "rbxasset://textures/particles/smoke_main.dds", ColorSequence.new(rgb(90, 70, 110), rgb(40, 30, 60)), Meteor.SIZE * 0.6, 30, 2.4, 0)
	emitter(core, "rbxasset://textures/particles/sparkles_main.dds", ColorSequence.new(WHITE, CYAN), 3, 60, 1.2, 1)
	local light = Instance.new("PointLight")
	light.Color = FIRE
	light.Range = 60
	light.Brightness = 8
	light.Parent = core
	rock:PivotTo(CFrame.new(show.Entry))
	rock.Parent = folder
	show.Rock = rock
	-- its trail of fire, back up the sky the way it came
	show.Tail = {
		part("Tail", Vector3.new(Meteor.SIZE * 0.75, Meteor.SIZE * 0.75, 1), CFrame.new(show.Entry), FIRE, Enum.Material.Neon),
		part("TailGlow", Vector3.new(Meteor.SIZE * 1.3, Meteor.SIZE * 1.3, 1), CFrame.new(show.Entry), VIOLET, Enum.Material.Neon),
	}
	show.Tail[1].Transparency = 0.35
	show.Tail[2].Transparency = 0.7
	-- where it's going to hit
	local circle = part("Warning", Vector3.new(0.3, Meteor.CRATER * 0.4, Meteor.CRATER * 0.4), CFrame.new(show.Landing + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), rgb(255, 70, 160), Enum.Material.Neon)
	circle.Shape = Enum.PartType.Cylinder
	circle.Transparency = 0.4
	show.Circle = circle
	-- the sky bursts open round it
	if show.Crack then
		skyShards(show, 8, show.Entry, HOLE_RADIUS, CFrame.lookAt(show.Entry, show.Landing))
	end
	play("Fall", 1.3)
end

-- Where the meteor is `a` of the way down (0..1): it speeds up all the way.
local function fallPosition(show: Show, a: number): Vector3
	local eased = a * 0.3 + a * a * 0.7
	return show.Entry:Lerp(show.Landing + Vector3.new(0, Meteor.SIZE * 0.35, 0), eased)
end

--------------------------------------------------------------------------------
-- The impact
--------------------------------------------------------------------------------
local function impact(show: Show)
	local at = show.Landing
	if show.Rock then
		show.Rock:Destroy()
	end
	if show.Circle then
		show.Circle:Destroy()
	end
	for _, list in { show.Plasma, show.Tail } do
		for _, p in list do
			p:Destroy()
		end
		table.clear(list)
	end
	show.Rock, show.Circle = nil, nil
	stop("Fall")
	play("Impact", 1.6)
	-- an explosion (just the look: it can't hurt anyone) and a fireball swelling up
	for i = 0, 2 do
		local boom = Instance.new("Explosion")
		boom.BlastPressure = 0
		boom.BlastRadius = 24
		boom.DestroyJointRadiusPercent = 0
		boom.ExplosionType = Enum.ExplosionType.NoCraters
		boom.Position = at + Vector3.new(math.cos(i * 2.1) * 10, 4 + i * 6, math.sin(i * 2.1) * 10)
		boom.Parent = folder
	end
	local fireball = part("Fireball", Vector3.one * Meteor.SIZE, CFrame.new(at + Vector3.new(0, 6, 0)), HOT, Enum.Material.Neon)
	fireball.Shape = Enum.PartType.Ball
	fireball.Transparency = 0.1
	TweenService:Create(fireball, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * Meteor.CRATER * 2.4, Transparency = 1, Color = PINK }):Play()
	-- a beam of cosmic light shooting up out of it
	local beam = part("Beam", Vector3.new(500, 22, 22), CFrame.new(at + Vector3.new(0, 250, 0)) * CFrame.Angles(0, 0, math.pi / 2), rgb(220, 190, 255), Enum.Material.Neon)
	beam.Shape = Enum.PartType.Cylinder
	beam.Transparency = 0.1
	TweenService:Create(beam, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.new(500, 2, 2), Transparency = 1 }):Play()
	-- shock waves racing out along the ground
	ring(at, Meteor.CRATER * 4.5, WHITE, 1.1)
	ring(at, Meteor.CRATER * 3, VIOLET, 0.9, 0.6)
	ring(at, Meteor.CRATER * 1.8, FIRE, 0.6, 0.8)
	ring(at, Meteor.CRATER * 6, rgb(200, 175, 150), 1.6, 0.3) -- (dust)
	-- broken rock flying everywhere
	local r = Random.new(show.Seed + 99)
	for i = 1, 16 do
		local angle = i / 16 * TAU + r:NextNumber(-0.2, 0.2)
		local chunk = r:NextNumber(3, 7)
		local glow = i % 4 == 0
		local p = part("Debris", Vector3.new(chunk, chunk * 0.8, chunk), CFrame.new(at + Vector3.new(0, 6, 0)), if glow then VIOLET else rgb(60, 46, 74), if glow then Enum.Material.Neon else Enum.Material.Slate)
		fling(p, Vector3.new(math.cos(angle), 0, math.sin(angle)) * r:NextNumber(50, 130) + Vector3.new(0, r:NextNumber(70, 150), 0), r:NextNumber(1.8, 2.6))
	end
	-- the ground shakes: hard right there, still a good jolt from the other end of the map
	show.Kick = 1.2 + 4.5 * closeness(at, IMPACT_RANGE)
	show.KickAt = os.clock()
	task.delay(1.5, function()
		fireball:Destroy()
		beam:Destroy()
	end)
end

--------------------------------------------------------------------------------
-- Every frame
--------------------------------------------------------------------------------
local function clearShow(show: Show)
	local items: { Instance? } = { show.Gui, show.Crack, show.Rock, show.Circle }
	for _, item in items do
		if item then
			item:Destroy()
		end
	end
	for _, list in { show.Plasma, show.Tail } do
		for _, p in list do
			p:Destroy()
		end
	end
	stop("Fall")
	if current == show then
		current = nil
	end
end

local function shakeAmount(show: Show, t: number): number
	local amount = 0
	if t >= Meteor.SHAKE_AT and t < Meteor.SHAKE_AT + Meteor.SHAKE then
		-- slams in, then slowly settles to half
		local a = (t - Meteor.SHAKE_AT) / Meteor.SHAKE
		amount = SHAKE_HARD * (if a < 0.08 then a / 0.08 else 1 - (a - 0.08) * 0.55)
	end
	if t >= Meteor.FALL_AT and t < Meteor.IMPACT_AT then
		-- a rumble growing as it comes down
		local a = (t - Meteor.FALL_AT) / Meteor.FALL
		amount = math.max(amount, 0.5 + 1.6 * a * a)
	end
	if show.Kick > 0 then
		local since = os.clock() - show.KickAt
		amount = math.max(amount, show.Kick * math.max(0, 1 - since / 1.8))
	end
	return amount
end

local function update(dt: number)
	local now = os.clock()
	-- flying pieces (sky glass, rock): fall, spin and fade
	for i = #pieces, 1, -1 do
		local piece = pieces[i]
		local age = now - piece.Born
		if age > piece.Life or not piece.Part.Parent then
			piece.Part:Destroy()
			table.remove(pieces, i)
		else
			piece.Velocity += GRAVITY * 0.35 * dt
			local cf = piece.Part.CFrame
			piece.Part.CFrame = (cf + piece.Velocity * dt) * CFrame.fromAxisAngle(piece.Spin.Unit, piece.Spin.Magnitude * dt)
			local fade = math.clamp((age - piece.Life * 0.6) / (piece.Life * 0.4), 0, 1)
			if fade > 0 then
				piece.Part.Transparency = math.max(piece.Part.Transparency, fade)
			end
		end
	end
	local show = current
	if not show then
		return
	end
	local t = now - show.Start
	local done = show.Done
	-- what happens when (in order, so a late start still catches up)
	if not done.Flash and t >= 0 then
		done.Flash = true
		if t < Meteor.FLASH then
			play("Flash", 1.5)
		end
	end
	if not done.Shatter and t >= Meteor.SHATTER_AT then
		done.Shatter = true
		shatter(show)
	end
	if not done.Fall and t >= Meteor.FALL_AT then
		done.Fall = true
		startFall(show)
	end
	if not done.Impact and t >= Meteor.IMPACT_AT then
		done.Impact = true
		impact(show)
	end
	-- the white screen
	local white = show.White
	if white and white.Parent then
		white.BackgroundTransparency = whiteness(show, t)
	end
	-- the crack spreading across the sky, then glowing, then closing up again (its lines are
	-- only touched while it spreads and while it fades: there are a lot of them)
	local crackAge = t - Meteor.SHATTER_AT
	if show.Crack and crackAge >= 0 then
		local gone = math.clamp((t - Meteor.IMPACT_AT - 3) / 2.5, 0, 1)
		local flicker = 0.08 * math.sin(now * 23)
		if crackAge < 0.8 or gone > 0 then
			for _, line in show.Lines do
				local shown = math.clamp((crackAge - line.Reveal) / 0.12, 0, 1)
				local base = if line.Part.Name == "CrackGlow" then 0.55 else 0
				line.Part.Transparency = 1 - shown + shown * math.clamp(base + gone, 0, 1)
			end
		end
		-- the hole tears open as the meteor comes through
		local open = math.clamp((t - Meteor.FALL_AT + 0.25) / 0.5, 0, 1) * (1 - gone)
		local hole, rim = show.Hole, show.Rim
		if hole and rim then
			local radius = math.max(1, HOLE_RADIUS * open)
			hole.Size = Vector3.new(2, radius * 2, radius * 2)
			rim.Size = Vector3.new(1.5, radius * 2.35, radius * 2.35)
			hole.Transparency = if open > 0 then 0 else 1
			rim.Transparency = if open > 0 then 0.05 + flicker else 1
		end
		if gone >= 1 then
			show.Crack:Destroy()
			show.Crack, show.Hole, show.Rim = nil, nil, nil
			table.clear(show.Lines)
		end
	end
	-- the meteor coming down, and its tail
	local rock = show.Rock
	if rock then
		local a = math.clamp((t - Meteor.FALL_AT) / Meteor.FALL, 0, 1)
		local position = fallPosition(show, a)
		rock:PivotTo(CFrame.new(position) * CFrame.fromAxisAngle(show.Spin, (t - Meteor.FALL_AT) * 2.2))
		for i, shell in show.Plasma do
			shell.CFrame = CFrame.new(position)
			shell.Transparency = (if i == 1 then 0.55 else 0.78) + 0.08 * math.sin(now * 30 + i)
		end
		local back = (show.Entry - position)
		local length = math.min(back.Magnitude, 420)
		if length > 1 then
			local tailEnd = position + back.Unit * length
			for i, tail in show.Tail do
				local width = Meteor.SIZE * (if i == 1 then 0.75 else 1.3)
				tail.Size = Vector3.new(width, width, length)
				tail.CFrame = CFrame.lookAt((position + tailEnd) / 2, position)
			end
		end
		local circle = show.Circle
		if circle then
			local grow = (0.4 + 0.9 * a) * Meteor.CRATER
			circle.Size = Vector3.new(0.3, grow, grow)
			circle.Transparency = 0.3 + 0.35 * math.abs(math.sin(now * (5 + a * 16)))
		end
	end
	if show.Gui and t > Meteor.IMPACT_AT + 1 then
		show.Gui:Destroy()
		show.Gui, show.White = nil, nil
	end
	if t > Meteor.IMPACT_AT + 8 then
		clearShow(show)
	end
end

local function onMeteor(info: any)
	if type(info) ~= "table" or typeof(info.Position) ~= "Vector3" or type(info.StartAt) ~= "number" then
		return
	end
	local start = os.clock() + (info.StartAt - workspace:GetServerTimeNow())
	if os.clock() - start > Meteor.IMPACT_AT + 1 then
		return -- (you joined after it already hit: the crater's there)
	end
	if current then
		clearShow(current)
	end
	local landing = info.Position :: Vector3
	local seed = if type(info.Seed) == "number" then info.Seed else 1
	local show: Show = {
		Start = start,
		Landing = landing,
		Entry = landing + Meteor.ENTRY,
		Seed = seed,
		Done = {},
		Lines = {},
		Plasma = {},
		Tail = {},
		Spin = Random.new(seed):NextUnitVector(),
		Kick = 0,
		KickAt = 0,
	}
	whiteScreen(show)
	current = show
end

--------------------------------------------------------------------------------
-- The Cosmic Donut's horizon (the one floating over the forge)
--------------------------------------------------------------------------------
type Ring = { Weld: Weld, Base: CFrame, Pivot: CFrame, Axis: Vector3, Spin: number }
local horizons: { [Model]: { Ring } } = {}

local function addHorizon(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local rings: { Ring } = {}
	for _, p in instance:GetDescendants() do
		if p:IsA("BasePart") and p:GetAttribute("Limb") == "Horizon" then
			local weld = p:FindFirstChildOfClass("Weld")
			local axis = p:GetAttribute("Axis")
			local pivot = p:GetAttribute("Pivot")
			local spin = p:GetAttribute("Spin")
			if weld and typeof(axis) == "Vector3" then
				table.insert(rings, {
					Weld = weld,
					Base = weld.C0,
					Pivot = CFrame.new(if typeof(pivot) == "Vector3" then pivot else Vector3.zero),
					Axis = axis,
					Spin = if type(spin) == "number" then spin else 1,
				})
			end
		end
	end
	if #rings > 0 then
		horizons[instance] = rings
	end
end

local function spinHorizons()
	local now = os.clock()
	for model, rings in horizons do
		if not model.Parent then
			horizons[model] = nil
			continue
		end
		for _, ringInfo in rings do
			local rotation = CFrame.fromAxisAngle(ringInfo.Axis, (now * ringInfo.Spin) % TAU)
			ringInfo.Weld.C0 = ringInfo.Pivot * rotation * ringInfo.Pivot:Inverse() * ringInfo.Base
		end
	end
end

function MeteorFX.Init()
	folder = Instance.new("Folder")
	folder.Name = "MeteorFXLocal"
	folder.Parent = workspace
	-- the sounds are made now, so they've loaded by the time a meteor comes
	soundFolder = Instance.new("Folder")
	soundFolder.Name = "MeteorSounds"
	soundFolder.Parent = SoundService
	local ids = Config.CosmicDonut.Sounds
	local lists: { [string]: { string } } = { Flash = { ids.Flash }, Shatter = { ids.Shatter }, Fall = { ids.Fall }, Impact = ids.Impact }
	for name, list in lists do
		sounds[name] = {}
		for i, id in list do
			local s = Instance.new("Sound")
			s.Name = name .. i
			s.SoundId = id
			s.Parent = soundFolder
			table.insert(sounds[name], s)
		end
	end
	Remotes.Event("Meteor").OnClientEvent:Connect(onMeteor)
	for _, instance in CollectionService:GetTagged("HorizonSpin") do
		task.spawn(addHorizon, instance)
	end
	CollectionService:GetInstanceAddedSignal("HorizonSpin"):Connect(addHorizon)
	RunService.RenderStepped:Connect(update)
	RunService.RenderStepped:Connect(spinHorizons)
	-- the shaking (after the camera has moved, so it never builds up)
	RunService:BindToRenderStep("MeteorShake", Enum.RenderPriority.Camera.Value + 2, function()
		local show = current
		local camera = workspace.CurrentCamera
		if not show or not camera then
			return
		end
		local now = os.clock()
		local strength = shakeAmount(show, now - show.Start)
		if strength <= 0 then
			return
		end
		camera.CFrame *= CFrame.Angles(math.noise(now * 22, 1.3) * 0.022 * strength, math.noise(now * 22, 4.7) * 0.022 * strength, math.noise(now * 18, 8.2) * 0.012 * strength)
			+ Vector3.new(math.noise(now * 28, 9.1), math.noise(now * 28, 2.2), 0) * 0.55 * strength
	end)
end

return MeteorFX
