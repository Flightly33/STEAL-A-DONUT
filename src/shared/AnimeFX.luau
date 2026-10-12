--[[
	AnimeFX
	=======
	Anime-style particle effects, shared by the donuts (DonutModel, from their DonutAuras) and the
	Domers (client/Guards and client/GiantFX):

	  Ki       -> a "power up" aura: flames of energy rising round it, with bright specks shooting up
	  ToonFire -> cartoon flames (solid, with a dark edge, not a glow)
	  Slashes  -> crescent sword slashes flashing round it
	  Kira     -> four-point twinkles popping on it (the anime "sparkle")
	  Zaps     -> little lightning bolts flickering round it
	  Impact   -> an impact frame: a ring breaking apart, a star flash, speed lines bursting out and
	              cartoon smoke puffs. Built with Rate 0: call AnimeFX.Fire to set one off.

	The textures are drawn in Blender (art/anime_vfx); most are flipbooks (several frames in one
	image that Roblox plays in turn). Until their ids are pasted into Config.AnimeFX.Textures, every
	effect uses one of Roblox's own built-in particles instead (still looks right, just less anime).
]]

local Config = require(script.Parent.Config)

local AnimeFX = {}

local rgb = Color3.fromRGB
local WHITE = rgb(255, 255, 255)

-- Roblox's own particles, standing in until the Blender textures are uploaded.
local FALLBACK: { [string]: string } = {
	Aura = "rbxasset://textures/particles/fire_main.dds",
	ToonFire = "rbxasset://textures/particles/fire_main.dds",
	ShockRing = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
	Impact = "rbxasset://textures/particles/sparkles_main.dds",
	ToonSmoke = "rbxasset://textures/particles/smoke_main.dds",
	Lightning = "rbxasset://textures/particles/sparkles_main.dds",
	Slash = "rbxasset://textures/particles/sparkles_main.dds",
	SpeedLines = "",
	Kira = "rbxasset://textures/particles/sparkles_main.dds",
	Petal = "rbxasset://textures/particles/smoke_main.dds",
	Spark = "rbxasset://textures/particles/sparkles_main.dds",
}
AnimeFX.Names = { "Aura", "ToonFire", "ShockRing", "Impact", "ToonSmoke", "Lightning", "Slash", "SpeedLines", "Kira", "Petal" }

-- How each flipbook plays (only used with the uploaded texture: the built-in ones are single images).
local FLIPBOOKS: { [string]: { Layout: Enum.ParticleFlipbookLayout, Mode: Enum.ParticleFlipbookMode, Rate: number? } } = {
	Aura = { Layout = Enum.ParticleFlipbookLayout.Grid4x4, Mode = Enum.ParticleFlipbookMode.Loop, Rate = 20 },
	ToonFire = { Layout = Enum.ParticleFlipbookLayout.Grid4x4, Mode = Enum.ParticleFlipbookMode.Loop, Rate = 18 },
	ShockRing = { Layout = Enum.ParticleFlipbookLayout.Grid4x4, Mode = Enum.ParticleFlipbookMode.OneShot },
	Impact = { Layout = Enum.ParticleFlipbookLayout.Grid4x4, Mode = Enum.ParticleFlipbookMode.OneShot },
	ToonSmoke = { Layout = Enum.ParticleFlipbookLayout.Grid4x4, Mode = Enum.ParticleFlipbookMode.OneShot },
	Lightning = { Layout = Enum.ParticleFlipbookLayout.Grid2x2, Mode = Enum.ParticleFlipbookMode.Random },
}

-- The uploaded texture's id, or nil while it's still empty.
function AnimeFX.Custom(name: string): string?
	local id = Config.AnimeFX.Textures[name]
	return if type(id) == "string" and id ~= "" then id else nil
end

-- The texture to use: the uploaded one, else Roblox's own stand-in.
function AnimeFX.Texture(name: string): string
	return AnimeFX.Custom(name) or FALLBACK[name] or FALLBACK.Spark
end

-- Gives an emitter its texture (and flipbook, if it's the uploaded one). True = the uploaded one.
function AnimeFX.Skin(e: ParticleEmitter, name: string): boolean
	local custom = AnimeFX.Custom(name)
	e.Texture = custom or FALLBACK[name] or FALLBACK.Spark
	local book = FLIPBOOKS[name]
	if custom and book then
		e.FlipbookLayout = book.Layout
		e.FlipbookMode = book.Mode
		if book.Rate then
			e.FlipbookFramerate = NumberRange.new(book.Rate * 0.85, book.Rate * 1.15)
			e.FlipbookStartRandom = true
		end
	end
	return custom ~= nil
end

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

local function base(parent: Instance, name: string, texture: string): (ParticleEmitter, boolean)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	local custom = AnimeFX.Skin(e, texture)
	e.LightInfluence = 0
	e.ZOffset = 0.5
	e.Parent = parent
	return e, custom
end

-- A power-up aura rising off a flat box under it (`parent`: a part as wide as the aura, at its
-- feet). `size` = how tall the flames are, `rate` = flames a second. Returns the two emitters.
function AnimeFX.Ki(parent: BasePart, colors: { Color3 }, size: number, rate: number): (ParticleEmitter, ParticleEmitter)
	local e, custom = base(parent, "KiAura", "Aura")
	e.Color = colorsOf({ colors[1]:Lerp(WHITE, 0.55), colors[1], colors[#colors] })
	e.LightEmission = if custom then 0.9 else 0.75
	e.Brightness = if custom then 2.4 else 3
	e.Rate = rate
	e.Shape = Enum.ParticleEmitterShape.Box
	e.EmissionDirection = Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(6, 6)
	e.Speed = NumberRange.new(size * 0.6, size * 1.1)
	e.Acceleration = Vector3.new(0, size * 0.8, 0)
	e.Drag = 1.5
	e.Lifetime = NumberRange.new(0.55, 0.85)
	e.Rotation = if custom then NumberRange.new(-6, 6) else NumberRange.new(-15, 15)
	e.Size = if custom then seq({ 0, size * 0.55, 0.4, size, 1, size * 0.8 }) else seq({ 0, size * 0.35, 0.4, size * 0.7, 1, size * 0.15 })
	e.Transparency = seq({ 0, 1, 0.15, 0.05, 0.75, 0.35, 1, 1 })
	e.Squash = NumberSequence.new(if custom then 0 else 0.6) -- (taller, thinner flames)
	e:SetAttribute("FXBoost", true)
	-- bright specks shooting up through it
	local specks = base(parent, "KiSpecks", "Spark")
	specks.Color = ColorSequence.new(WHITE, colors[1]:Lerp(WHITE, 0.3))
	specks.LightEmission = 1
	specks.Brightness = 5
	specks.Rate = rate * 0.6
	specks.Shape = Enum.ParticleEmitterShape.Box
	specks.EmissionDirection = Enum.NormalId.Top
	specks.SpreadAngle = Vector2.new(4, 4)
	specks.Speed = NumberRange.new(size * 3, size * 5)
	specks.Lifetime = NumberRange.new(0.25, 0.45)
	specks.Orientation = Enum.ParticleOrientation.VelocityParallel
	specks.Squash = NumberSequence.new(3.5)
	specks.Size = seq({ 0, size * 0.14, 1, 0 })
	specks.Transparency = seq({ 0, 0, 1, 0.6 })
	specks:SetAttribute("FXBoost", true)
	return e, specks
end

-- Cartoon flames licking up from a flat box under it.
function AnimeFX.ToonFire(parent: BasePart, colors: { Color3 }, size: number, rate: number): ParticleEmitter
	local e, custom = base(parent, "ToonFire", "ToonFire")
	e.Color = colorsOf(colors)
	-- (mostly solid, so it reads as a drawn flame and not a glow)
	e.LightEmission = if custom then 0.25 else 0.35
	e.Brightness = if custom then 1.6 else 2.4
	e.Rate = rate
	e.Shape = Enum.ParticleEmitterShape.Box
	e.EmissionDirection = Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(10, 10)
	e.Speed = NumberRange.new(size * 0.8, size * 1.6)
	e.Acceleration = Vector3.new(0, size, 0)
	e.Lifetime = NumberRange.new(0.5, 0.8)
	e.Rotation = NumberRange.new(-8, 8)
	e.Size = seq({ 0, size * 0.5, 0.35, size * 0.85, 1, size * 0.3 })
	e.Transparency = seq({ 0, 1, 0.1, 0, 0.8, 0.1, 1, 1 })
	e:SetAttribute("FXBoost", true)
	return e
end

-- Crescent slashes flashing on a sphere round it (`parent`: a part the size of that sphere).
function AnimeFX.Slashes(parent: BasePart, color: Color3, size: number, rate: number): ParticleEmitter
	local e, custom = base(parent, "Slashes", "Slash")
	e.Color = ColorSequence.new(WHITE, color)
	e.LightEmission = 1
	e.Brightness = 4
	e.Rate = rate
	e.Shape = Enum.ParticleEmitterShape.Sphere
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	e.LockedToPart = true
	if custom then
		e.Speed = NumberRange.new(0)
		e.Lifetime = NumberRange.new(0.2, 0.3)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-260, 260)
		e.Size = seq({ 0, size * 0.4, 0.25, size, 1, size * 1.15 })
		e.Transparency = seq({ 0, 0, 0.5, 0.1, 1, 1 })
	else
		-- (no slash picture yet: long thin cuts flicking across it)
		e.Speed = NumberRange.new(size * 6, size * 9)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Drag = 10
		e.Lifetime = NumberRange.new(0.14, 0.22)
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.Squash = NumberSequence.new(5)
		e.Size = seq({ 0, size * 0.35, 1, size * 0.1 })
		e.Transparency = seq({ 0, 0, 1, 0.8 })
	end
	e:SetAttribute("FXBoost", true)
	return e
end

-- Four-point twinkles popping all over a sphere round it.
function AnimeFX.Kira(parent: BasePart, color: Color3, size: number, rate: number): ParticleEmitter
	local e, custom = base(parent, "Kira", "Kira")
	e.Color = ColorSequence.new(WHITE, color:Lerp(WHITE, 0.25))
	e.LightEmission = 1
	e.Brightness = 4
	e.Rate = rate
	e.Shape = Enum.ParticleEmitterShape.Sphere
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.LockedToPart = true
	e.Speed = NumberRange.new(0)
	e.Lifetime = NumberRange.new(0.45, 0.75)
	e.Rotation = if custom then NumberRange.new(-12, 12) else NumberRange.new(0, 360)
	e.RotSpeed = if custom then NumberRange.new(-30, 30) else NumberRange.new(-90, 90)
	e.Size = seq({ 0, 0, 0.35, size, 1, 0 })
	e.Transparency = NumberSequence.new(0)
	e:SetAttribute("FXBoost", true)
	return e
end

-- Little lightning bolts flickering round it.
function AnimeFX.Zaps(parent: BasePart, colors: { Color3 }, size: number, rate: number): ParticleEmitter
	local e, custom = base(parent, "Zaps", "Lightning")
	e.Color = colorsOf({ WHITE, colors[1] })
	e.LightEmission = 1
	e.Brightness = 6
	e.Rate = rate
	e.Shape = Enum.ParticleEmitterShape.Sphere
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	e.LockedToPart = true
	if custom then
		e.Speed = NumberRange.new(0)
		e.Lifetime = NumberRange.new(0.08, 0.16)
		e.Rotation = NumberRange.new(0, 360)
		e.Size = seq({ 0, size, 1, size * 1.1 })
		e.Transparency = seq({ 0, 0, 1, 0.3 })
	else
		-- (no bolt picture yet: short, thin jagged-looking flickers)
		e.Speed = NumberRange.new(0.5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Lifetime = NumberRange.new(0.06, 0.12)
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.Squash = NumberSequence.new(6)
		e.Size = NumberSequence.new(size * 0.45)
		e.Transparency = NumberSequence.new(0)
	end
	e:SetAttribute("FXBoost", true)
	return e
end

-- An impact frame (ring, star flash, speed lines, smoke puffs), built ready to fire: put it at the
-- centre of the hit (`parent`: an Attachment or a part). `size` = how big the hit is.
function AnimeFX.Impact(parent: Instance, colors: { Color3 }, size: number): { ParticleEmitter }
	local list = {}
	local main = colors[1]
	local ring, ringCustom = base(parent, "ImpactRing", "ShockRing")
	ring.Color = ColorSequence.new(WHITE, main:Lerp(WHITE, 0.3))
	ring.LightEmission = 1
	ring.Brightness = 4
	ring.Rate = 0
	ring.Speed = NumberRange.new(0)
	ring.Lifetime = NumberRange.new(0.4)
	ring.Rotation = NumberRange.new(0, 360)
	ring.Size = if ringCustom then seq({ 0, size * 2.5, 1, size * 6 }) else seq({ 0, size * 0.5, 0.3, size * 4, 1, size * 6 })
	ring.Transparency = if ringCustom then NumberSequence.new(0) else seq({ 0, 0, 0.6, 0.2, 1, 1 })
	ring.ZOffset = 1
	ring:SetAttribute("Burst", 1)
	table.insert(list, ring)

	local star = base(parent, "ImpactStar", "Impact")
	star.Color = ColorSequence.new(WHITE, main)
	star.LightEmission = 1
	star.Brightness = 6
	star.Rate = 0
	star.Speed = NumberRange.new(0)
	star.Lifetime = NumberRange.new(0.25)
	star.Rotation = NumberRange.new(0, 360)
	star.Size = seq({ 0, size * 3.2, 1, size * 4.2 })
	star.Transparency = seq({ 0, 0, 0.6, 0.1, 1, 1 })
	star.ZOffset = 1.5
	star:SetAttribute("Burst", 1)
	table.insert(list, star)

	local lines = base(parent, "ImpactLines", "Spark")
	lines.Color = ColorSequence.new(WHITE, main:Lerp(WHITE, 0.5))
	lines.LightEmission = 1
	lines.Brightness = 5
	lines.Rate = 0
	lines.SpreadAngle = Vector2.new(180, 180)
	lines.Speed = NumberRange.new(size * 14, size * 22)
	lines.Drag = 6
	lines.Lifetime = NumberRange.new(0.18, 0.3)
	lines.Orientation = Enum.ParticleOrientation.VelocityParallel
	lines.Squash = NumberSequence.new(4)
	lines.Size = seq({ 0, size * 0.5, 1, size * 0.1 })
	lines.Transparency = seq({ 0, 0, 1, 0.7 })
	lines:SetAttribute("Burst", 10)
	table.insert(list, lines)

	local smoke = base(parent, "ImpactSmoke", "ToonSmoke")
	smoke.Color = ColorSequence.new(rgb(235, 235, 245), main:Lerp(rgb(140, 140, 160), 0.6))
	smoke.LightEmission = 0.1
	smoke.Brightness = 1.2
	smoke.Rate = 0
	smoke.SpreadAngle = Vector2.new(180, 20)
	smoke.EmissionDirection = Enum.NormalId.Front
	smoke.Speed = NumberRange.new(size * 4, size * 7)
	smoke.Drag = 4
	smoke.Lifetime = NumberRange.new(0.5, 0.75)
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-60, 60)
	smoke.Size = seq({ 0, size * 0.9, 1, size * 1.8 })
	smoke.Transparency = seq({ 0, 0.1, 0.7, 0.3, 1, 1 })
	smoke:SetAttribute("Burst", 5)
	table.insert(list, smoke)
	return list
end

-- Sets off an impact frame (from AnimeFX.Impact, or everything named Impact* under `holder`).
-- `scale` multiplies how many particles each part of it shoots.
function AnimeFX.Fire(list: { ParticleEmitter }, scale: number?)
	for _, e in list do
		if e.Parent then
			local count = (e:GetAttribute("Burst") :: number?) or 1
			e:Emit(math.max(1, math.round(count * (scale or 1))))
		end
	end
end

-- The impact frames already built under `holder` (as made by AnimeFX.Impact).
function AnimeFX.Find(holder: Instance): { ParticleEmitter }
	local list = {}
	for _, e in holder:GetDescendants() do
		if e:IsA("ParticleEmitter") and e:GetAttribute("Burst") ~= nil then
			table.insert(list, e)
		end
	end
	return list
end

return AnimeFX
