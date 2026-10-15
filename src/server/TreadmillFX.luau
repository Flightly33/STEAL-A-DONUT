--[[
	TreadmillFX: a treadmill's effects. Each one's list (Vfx in shared/TreadmillModels) is designed
	with its model in art/treadmills, and they go from bad to epic as the treadmills get better:

	  the junk ones   - black smoke sputtering out of the motor, sparks grinding off the belt, a dusty
	                    cough, a bulb that won't stop flickering (and the console rattles)
	  the middle ones - exhaust and speed lines, jet afterburners, rings of light, lightning arcs and
	                    strikes, prism rays, eruptions of lava
	  the top ones    - auras of energy round the runner, black holes sucking in light, a dragon
	                    breathing fire, a supernova bursting, god rays and falling feathers

	Every effect has an Idle and a Run strength: standing still it ticks over, and while the owner
	runs it goes all out (TreadmillFX.SetRunning). Bursts (power-ups, shockwaves, rings of light,
	lightning strikes) and the crackling, flickering and swinging are set off by the clients
	(client/Treadmill), on everyone's screen at once.

	  TreadmillFX.Build(model, origin, design, groups)   adds the effects to a treadmill model
	  TreadmillFX.SetRunning(model, running)             everything to its Run (or Idle) strength
	  TreadmillFX.Presets                                 the particle presets an Emit can use
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimeFX = require(Shared.AnimeFX)
local TreadmillModels = require(Shared.TreadmillModels)

local Build = require(script.Parent.Build)

local TreadmillFX = {}

type Spec = TreadmillModels.Vfx
type Preset = (holder: BasePart, spec: Spec, colors: { Color3 }, size: number, rate: number) -> { ParticleEmitter }

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local RING = "rbxasset://textures/particles/explosion01_shockwave_main.dds"
local VORTEX = "rbxasset://textures/particles/forcefield_vortex_main.dds"

local function seq(points: { number }): NumberSequence
	local keys = {}
	for i = 1, #points, 2 do
		table.insert(keys, NumberSequenceKeypoint.new(points[i], points[i + 1]))
	end
	return NumberSequence.new(keys)
end

local function colorsOf(colors: { Color3 }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local keys = {}
	for i, color in colors do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(keys)
end

local function direction(spec: Spec): Enum.NormalId
	return (Enum.NormalId :: any)[spec.Dir or "Top"] or Enum.NormalId.Top
end

-- A plain emitter on `holder` (its texture: one of Roblox's own, or an AnimeFX one by name)
local function emitter(holder: BasePart, name: string, texture: string, colors: { Color3 }, rate: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	if string.find(texture, "://") then
		e.Texture = texture
	else
		AnimeFX.Skin(e, texture)
	end
	e.Color = colorsOf(colors)
	e.LightInfluence = 0
	e.Rate = rate
	e.Rotation = NumberRange.new(0, 360)
	e.Parent = holder
	return e
end

local Presets: { [string]: Preset } = {}
TreadmillFX.Presets = Presets

-- Puffs of smoke (a junk motor sputtering)
function Presets.Smoke(holder, spec, colors, size, rate)
	local e = emitter(holder, "Smoke", "ToonSmoke", colors, rate)
	e.Brightness = 1
	e.EmissionDirection = direction(spec)
	e.SpreadAngle = Vector2.new(25, 25)
	e.Speed = NumberRange.new(size * 1.5, size * 3)
	e.Acceleration = Vector3.new(0, size * 1.2, 0)
	e.Drag = 1.2
	e.Lifetime = NumberRange.new(1, 1.8)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.Size = seq({ 0, size * 0.5, 0.5, size * 1.3, 1, size * 1.8 })
	e.Transparency = seq({ 0, 0.15, 0.6, 0.45, 1, 1 })
	return { e }
end

-- Hot sparks flying off and falling (grinding metal, a jet's afterburner)
function Presets.Sparks(holder, spec, colors, size, rate)
	local e = emitter(holder, "Sparks", SPARK, colors, rate)
	e.LightEmission = 1
	e.Brightness = 2
	e.EmissionDirection = direction(spec)
	e.SpreadAngle = Vector2.new(35, 35)
	e.Speed = NumberRange.new(size * 8, size * 16)
	e.Acceleration = Vector3.new(0, -45, 0)
	e.Drag = 0.5
	e.Lifetime = NumberRange.new(0.3, 0.6)
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Squash = NumberSequence.new(3)
	e.Size = seq({ 0, size * 0.18, 1, 0 })
	return { e }
end

-- A dusty cough
function Presets.Dust(holder, spec, colors, size, rate)
	local e = emitter(holder, "Dust", SMOKE, colors, rate)
	e.EmissionDirection = direction(spec)
	e.SpreadAngle = Vector2.new(50, 50)
	e.Speed = NumberRange.new(2, 5)
	e.Lifetime = NumberRange.new(0.6, 1.1)
	e.Size = seq({ 0, size * 0.6, 1, size * 2 })
	e.Transparency = seq({ 0, 0.5, 1, 1 })
	return { e }
end

-- Speed lines streaking away
function Presets.Streaks(holder, spec, colors, size, rate)
	local e = emitter(holder, "Streaks", SPARK, colors, rate)
	e.LightEmission = 0.8
	e.Brightness = 1.5
	e.EmissionDirection = direction(spec)
	e.SpreadAngle = Vector2.new(3, 3)
	e.Speed = NumberRange.new(size * 30, size * 45)
	e.Lifetime = NumberRange.new(0.12, 0.25)
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Squash = NumberSequence.new(8)
	e.Rotation = NumberRange.new(0)
	e.Size = seq({ 0, size * 0.25, 1, size * 0.03 })
	e.Transparency = seq({ 0, 0.1, 1, 1 })
	return { e }
end

-- Exhaust puffing out of a pipe
function Presets.Exhaust(holder, spec, colors, size, rate)
	local e = emitter(holder, "Exhaust", SMOKE, colors, rate)
	e.EmissionDirection = direction(spec)
	e.SpreadAngle = Vector2.new(15, 15)
	e.Speed = NumberRange.new(4, 7)
	e.Acceleration = Vector3.new(0, 1.5, 0)
	e.Drag = 1
	e.Lifetime = NumberRange.new(0.8, 1.4)
	e.Size = seq({ 0, size * 0.5, 1, size * 2.2 })
	e.Transparency = seq({ 0, 0.3, 1, 1 })
	return { e }
end

-- Cartoon flames (shooting out sideways as a jet if they don't go up)
function Presets.Flame(holder, spec, colors, size, rate)
	local e = AnimeFX.ToonFire(holder, colors, size, rate)
	local dir = direction(spec)
	e.EmissionDirection = dir
	if dir ~= Enum.NormalId.Top then
		e.Speed = NumberRange.new(size * 5, size * 9)
		e.Acceleration = Vector3.new(0, size * 0.5, 0)
		e.SpreadAngle = Vector2.new(8, 8)
	end
	return { e }
end

-- A jet of fire breathed out (the dragon)
function Presets.Breath(holder, spec, colors, size, rate)
	local e = AnimeFX.ToonFire(holder, colors, size, rate)
	e.Name = "Breath"
	e.EmissionDirection = direction(spec)
	e.SpreadAngle = Vector2.new(10, 10)
	e.Speed = NumberRange.new(size * 10, size * 16)
	e.Drag = 2
	e.Acceleration = Vector3.new(0, size * 1.5, 0)
	e.Lifetime = NumberRange.new(0.4, 0.7)
	e.Size = seq({ 0, size * 0.5, 0.5, size * 1.4, 1, size * 2 })
	return { e }
end

-- The anime set (shared/AnimeFX): power-up auras, twinkles, lightning, embers, hellfire, smoke
function Presets.Ki(holder, _spec, colors, size, rate)
	return AnimeFX.Ki(holder, colors, size, rate)
end
function Presets.Kira(holder, _spec, colors, size, rate)
	return { AnimeFX.Kira(holder, colors[1], size, rate) }
end
function Presets.Zaps(holder, _spec, colors, size, rate)
	return { AnimeFX.Zaps(holder, colors, size, rate) }
end
function Presets.Embers(holder, _spec, colors, size, rate)
	return { AnimeFX.Embers(holder, colors, size, rate) }
end
function Presets.DarkFlame(holder, _spec, colors, size, rate)
	return { AnimeFX.DarkFlame(holder, colors, size, rate) }
end
function Presets.Wisps(holder, _spec, colors, size, rate)
	return { AnimeFX.Wisps(holder, colors[1], size, rate) }
end

-- Low mist rolling round the bottom
function Presets.Mist(holder, _spec, colors, size, rate)
	local e = emitter(holder, "Mist", SMOKE, colors, rate)
	e.LightEmission = 0.1
	e.SpreadAngle = Vector2.new(80, 80)
	e.Speed = NumberRange.new(0.5, 1.5)
	e.Acceleration = Vector3.new(0, 0.3, 0)
	e.Lifetime = NumberRange.new(2, 3)
	e.RotSpeed = NumberRange.new(-15, 15)
	e.Size = seq({ 0, size * 0.8, 1, size * 1.6 })
	e.Transparency = seq({ 0, 1, 0.3, 0.7, 1, 1 })
	return { e }
end

-- Rain falling from a storm cloud
function Presets.Rain(holder, spec, colors, size, rate)
	local e = emitter(holder, "Rain", SPARK, colors, rate)
	e.LightEmission = 0.3
	e.EmissionDirection = direction(spec)
	e.SpreadAngle = Vector2.new(2, 2)
	e.Speed = NumberRange.new(30, 40)
	e.Lifetime = NumberRange.new(0.25, 0.4)
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Squash = NumberSequence.new(10)
	e.Rotation = NumberRange.new(0)
	e.Size = NumberSequence.new(size * 0.12)
	e.Transparency = NumberSequence.new(0.35)
	return { e }
end

-- Stars twinkling all round it
function Presets.Stars(holder, _spec, colors, size, rate)
	local e = emitter(holder, "Stars", "Kira", colors, rate)
	e.LightEmission = 1
	e.Brightness = 1.6
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Speed = NumberRange.new(0)
	e.Lifetime = NumberRange.new(1, 2)
	e.Size = seq({ 0, 0, 0.5, size, 1, 0 })
	return { e }
end

-- Shooting stars streaking across
function Presets.Shooting(holder, spec, colors, size, rate)
	local e = emitter(holder, "Shooting", SPARK, colors, rate)
	e.LightEmission = 1
	e.Brightness = 2
	e.EmissionDirection = direction(spec)
	e.SpreadAngle = Vector2.new(35, 35)
	e.Speed = NumberRange.new(45, 70)
	e.Lifetime = NumberRange.new(0.25, 0.45)
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Squash = NumberSequence.new(14)
	e.Rotation = NumberRange.new(0)
	e.Size = seq({ 0, size * 0.3, 1, 0 })
	e.Transparency = seq({ 0, 0, 1, 0.6 })
	return { e }
end

-- Soft glowing clouds of colour drifting about
function Presets.Nebula(holder, _spec, colors, size, rate)
	local e = emitter(holder, "Nebula", SMOKE, colors, rate)
	e.LightEmission = 0.6
	e.Brightness = 1.2
	e.SpreadAngle = Vector2.new(180, 180)
	e.Speed = NumberRange.new(0.3, 0.8)
	e.Lifetime = NumberRange.new(3, 5)
	e.RotSpeed = NumberRange.new(-15, 15)
	e.Size = seq({ 0, size, 0.5, size * 1.6, 1, size * 1.8 })
	e.Transparency = seq({ 0, 1, 0.3, 0.75, 0.7, 0.75, 1, 1 })
	return { e }
end

-- A galaxy swirling flat on the ground
function Presets.Vortex(holder, _spec, colors, size, rate)
	local e = emitter(holder, "Vortex", VORTEX, colors, rate)
	e.LightEmission = 1
	e.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	e.SpreadAngle = Vector2.new(0, 0)
	e.Speed = NumberRange.new(0.01)
	e.Lifetime = NumberRange.new(1.6, 2.2)
	e.RotSpeed = NumberRange.new(90, 160)
	e.Size = seq({ 0, size * 0.3, 0.4, size, 1, size * 1.2 })
	e.Transparency = seq({ 0, 1, 0.3, 0.35, 0.8, 0.5, 1, 1 })
	return { e }
end

-- Sparks pulled in from all round into the middle (a black hole)
function Presets.Suck(holder, _spec, colors, size, rate)
	local e = emitter(holder, "Suck", SPARK, colors, rate)
	e.LightEmission = 1
	e.Brightness = 1.8
	e.Shape = Enum.ParticleEmitterShape.Sphere
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	local radius = math.min(holder.Size.X, holder.Size.Y, holder.Size.Z) / 2
	e.Speed = NumberRange.new(size * 9, size * 13)
	e.Lifetime = NumberRange.new(radius / (size * 13), radius / (size * 9))
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Squash = NumberSequence.new(4)
	e.Size = seq({ 0, size * 0.25, 1, size * 0.05 })
	e.Transparency = seq({ 0, 0.4, 0.3, 0, 1, 0.3 })
	return { e }
end

-- Feathers drifting down
function Presets.Feathers(holder, spec, colors, size, rate)
	local e = emitter(holder, "Feathers", "Petal", colors, rate)
	e.LightEmission = 0.2
	e.EmissionDirection = direction(spec)
	e.SpreadAngle = Vector2.new(20, 20)
	e.Speed = NumberRange.new(1, 2)
	e.Acceleration = Vector3.new(0, -0.6, 0)
	e.Drag = 0.3
	e.Lifetime = NumberRange.new(4, 6)
	e.RotSpeed = NumberRange.new(-80, 80)
	e.Size = seq({ 0, size, 1, size * 0.9 })
	e.Transparency = seq({ 0, 0.1, 0.85, 0.2, 1, 1 })
	return { e }
end

-- Bubbles of lava popping
function Presets.Bubbles(holder, _spec, colors, size, rate)
	local e = emitter(holder, "Bubbles", SMOKE, colors, rate)
	e.LightEmission = 1
	e.Speed = NumberRange.new(0.3, 1)
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Size = seq({ 0, 0, 0.7, size, 1, size * 1.4 })
	e.Transparency = seq({ 0, 0, 0.7, 0, 1, 1 })
	return { e }
end

-- Glitching bars of colour flicking on and off
function Presets.Glitch(holder, _spec, colors, size, rate)
	local e = emitter(holder, "Glitch", SPARK, colors, rate)
	e.LightEmission = 1
	e.Brightness = 1.6
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Speed = NumberRange.new(0)
	e.Lifetime = NumberRange.new(0.08, 0.2)
	e.Rotation = NumberRange.new(0)
	e.Squash = NumberSequence.new(-3)
	e.Size = NumberSequence.new(size)
	return { e }
end

-- Bursts (fired by the clients every Every seconds while running, EveryIdle standing): a power-up
-- burst of spikes, an impact frame, a ring of light spreading over the ground
function Presets.Burst(holder, _spec, colors, size, _rate)
	return { AnimeFX.Burst(holder, colors, size) }
end
function Presets.Impact(holder, _spec, colors, size, _rate)
	return AnimeFX.Impact(holder, colors, size)
end
function Presets.Ring(holder, spec, colors, _size, _rate)
	local e = emitter(holder, "Ring", RING, colors, 0)
	e.LightEmission = 1
	e.Brightness = 1.5
	e.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	e.SpreadAngle = Vector2.new(0, 0)
	e.Speed = NumberRange.new(0.01)
	e.Rotation = NumberRange.new(0, 360)
	e.Lifetime = NumberRange.new(1.4)
	local radius = spec.Radius or 8
	e.Size = seq({ 0, 0.5, 1, radius * 2 })
	e.Transparency = seq({ 0, 0.05, 0.7, 0.5, 1, 1 })
	e:SetAttribute("Burst", 1)
	return { e }
end

-- An invisible holder part for an effect, placed in treadmill space
local function holderAt(parent: Instance, name: string, origin: CFrame, pos: Vector3, size: Vector3?): BasePart
	local s = size or Vector3.one * 0.2
	local part = Build.Decor({
		Parent = parent,
		Name = name,
		Size = Vector3.new(math.max(s.X, 0.2), math.max(s.Y, 0.2), math.max(s.Z, 0.2)),
		CFrame = origin * CFrame.new(pos),
		Transparency = 1,
	})
	part.CastShadow = false
	return part
end

local function emit(spec: Spec, origin: CFrame, parent: Instance)
	local preset = Presets[spec.Preset or ""]
	if not preset then
		return
	end
	local holder = holderAt(parent, "FX_" .. (spec.Preset :: string), origin, spec.Pos or Vector3.zero, spec.Area)
	local idle, run = spec.Idle or 0, spec.Run or 0
	local most = math.max(idle, run, 0.001)
	local colors = spec.Colors or { Color3.new(1, 1, 1) }
	local emitters = preset(holder, spec, colors, spec.Size or 1, most)
	local burst = spec.Every ~= nil or spec.EveryIdle ~= nil
	for _, e in emitters do
		if spec.Shape == "Sphere" and spec.Preset ~= "Suck" then
			e.Shape = Enum.ParticleEmitterShape.Sphere
		end
		-- (the big effects of the best treadmills get more particles: client/ParticleBudget)
		e:SetAttribute("FXBoost", if spec.Boost then true else nil)
		if burst then
			e.Rate = 0
		else
			local base = e.Rate
			e:SetAttribute("IdleRate", base * idle / most)
			e:SetAttribute("RunRate", base * run / most)
			e.Rate = base * idle / most
		end
	end
	if burst then
		holder:SetAttribute("Every", spec.Every)
		holder:SetAttribute("EveryIdle", spec.EveryIdle)
		CollectionService:AddTag(holder, "TreadmillBurst")
	end
end

-- Lightning: a jagged chain of short beams through points the clients keep jolting about
local ARC_POINTS = 7

local function beam(spec: Spec, origin: CFrame, parent: Instance)
	local from, to = spec.From or Vector3.zero, spec.To or Vector3.zero
	local holder = holderAt(parent, "FX_Beam", origin, from)
	local colors = colorsOf(spec.Colors or { Color3.new(1, 1, 1) })
	local width0 = spec.Width or 0.3
	local width1 = spec.Width1 or width0
	local style = spec.Style or "Ray"
	holder:SetAttribute("Style", style)
	local function link(a0: Attachment, a1: Attachment, w0: number, w1: number): Beam
		local b = Instance.new("Beam")
		b.Attachment0 = a0
		b.Attachment1 = a1
		b.Color = colors
		b.Width0 = w0
		b.Width1 = w1
		b.LightEmission = 1
		b.LightInfluence = 0
		b.FaceCamera = true
		b.Segments = 1
		b.Parent = holder
		return b
	end
	if style == "Ray" then
		-- a soft shaft of light, fading out at both ends
		local a0 = Instance.new("Attachment")
		a0.Parent = holder
		local a1 = Instance.new("Attachment")
		a1.Position = to - from
		a1.Parent = holder
		local t = spec.Transparency or 0.4
		local b = link(a0, a1, width0, width1)
		b.Transparency = seq({ 0, 1, 0.12, t, 0.85, t, 1, 1 })
		return
	end
	-- electricity: points along the line (the ends stay put; the clients jolt the middle ones about
	-- so it crackles, or, for a Strike, flash it on every Every seconds while running)
	local points: { Attachment } = {}
	for i = 0, ARC_POINTS - 1 do
		local a = Instance.new("Attachment")
		a.Name = "P" .. i
		a.Position = (to - from) * (i / (ARC_POINTS - 1))
		a:SetAttribute("Home", a.Position)
		a.Parent = holder
		table.insert(points, a)
	end
	local strike = style == "Strike"
	for i = 1, ARC_POINTS - 1 do
		local f0, f1 = (i - 1) / (ARC_POINTS - 1), i / (ARC_POINTS - 1)
		local b = link(points[i], points[i + 1], width0 + (width1 - width0) * f0, width0 + (width1 - width0) * f1)
		b.Name = "Bolt"
		b.Transparency = NumberSequence.new(spec.Transparency or 0)
		b.Enabled = not strike
	end
	-- (and a faint wide glow along the whole of it)
	local glow = link(points[1], points[ARC_POINTS], width0 * 4, width1 * 4)
	glow.Name = "Glow"
	glow.Transparency = NumberSequence.new(0.8)
	glow.Enabled = not strike
	holder:SetAttribute("Length", (to - from).Magnitude)
	if strike then
		holder:SetAttribute("Every", spec.Every or 2)
	end
	CollectionService:AddTag(holder, "TreadmillArc")
end

local function light(spec: Spec, origin: CFrame, parent: Instance)
	local holder = holderAt(parent, "FX_Light", origin, spec.Pos or Vector3.zero)
	local l: Light
	if spec.Spot then
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Angle = spec.Angle or 45
		l = spot
	else
		l = Instance.new("PointLight")
	end
	l.Color = spec.Color or Color3.new(1, 1, 1)
	;(l :: any).Range = spec.Range or 12
	l.Brightness = spec.Idle or 1
	l:SetAttribute("IdleBrightness", spec.Idle or 1)
	l:SetAttribute("RunBrightness", spec.Run or spec.Idle or 1)
	l.Parent = holder
	if spec.Flicker then
		CollectionService:AddTag(l, "TreadmillFlicker")
	end
end

local function pulse(spec: Spec, origin: CFrame, parent: Instance)
	-- a ring of light spreading out over the ground: a burst the clients fire every so often
	local holder = holderAt(parent, "FX_Pulse", origin, spec.Pos or Vector3.zero)
	local color = spec.Color or Color3.new(1, 1, 1)
	Presets.Ring(holder, spec, { color:Lerp(Color3.new(1, 1, 1), 0.35), color }, 1, 0)
	holder:SetAttribute("Every", if (spec.Run or 0) > 0 then spec.Run else nil)
	holder:SetAttribute("EveryIdle", if (spec.Idle or 0) > 0 then spec.Idle else nil)
	holder:SetAttribute("Phase", spec.Phase or 0)
	CollectionService:AddTag(holder, "TreadmillBurst")
end

local function fire(spec: Spec, origin: CFrame, parent: Instance)
	local holder = holderAt(parent, "FX_Fire", origin, spec.Pos or Vector3.zero)
	local f = Instance.new("Fire")
	local color = spec.Color or Color3.fromRGB(255, 140, 40)
	f.Color = color
	f.SecondaryColor = color:Lerp(Color3.new(1, 1, 0.6), 0.5)
	f.Heat = 5
	f.Size = math.clamp(spec.Idle or 2, 2, 30)
	f:SetAttribute("IdleSize", math.clamp(spec.Idle or 2, 2, 30))
	f:SetAttribute("RunSize", math.clamp(spec.Run or spec.Idle or 2, 2, 30))
	f.Parent = holder
end

local function sparkles(spec: Spec, origin: CFrame, parent: Instance)
	local holder = holderAt(parent, "FX_Sparkles", origin, spec.Pos or Vector3.zero)
	local s = Instance.new("Sparkles")
	s.SparkleColor = spec.Color or Color3.new(1, 1, 1)
	s.Parent = holder
end

local BUILDERS: { [string]: (Spec, CFrame, Instance) -> () } = {
	Emit = emit,
	Beam = beam,
	Light = light,
	Pulse = pulse,
	Fire = fire,
	Sparkles = sparkles,
}

-- Adds `design`'s effects to `model` (`origin`: the treadmill's CFrame; `groups`: its moving groups,
-- for effects that move with one)
function TreadmillFX.Build(model: Model, origin: CFrame, design: TreadmillModels.Model, groups: { [string]: Model })
	for _, spec in design.Vfx do
		local builder = BUILDERS[spec.Kind]
		if builder then
			local parent: Instance = if spec.Group and groups[spec.Group] then groups[spec.Group] else model
			builder(spec, origin, parent)
		end
	end
end

-- Every effect to its Run strength while the owner runs, its Idle one when they stop.
function TreadmillFX.SetRunning(model: Instance, running: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("ParticleEmitter") then
			local rate = d:GetAttribute(if running then "RunRate" else "IdleRate")
			if type(rate) == "number" then
				d.Rate = rate
			end
		elseif d:IsA("Light") then
			local brightness = d:GetAttribute(if running then "RunBrightness" else "IdleBrightness")
			if type(brightness) == "number" then
				d.Brightness = brightness
			end
		elseif d:IsA("Fire") then
			local size = d:GetAttribute(if running then "RunSize" else "IdleSize")
			if type(size) == "number" then
				d.Size = size
			end
		end
	end
end

return TreadmillFX
