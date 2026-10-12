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

	Style: solid, deep colours and dark ink outlines (cel-shaded), not glow. Every effect stays
	under the game's bloom threshold (Config.Graphics.BloomThreshold), so it reads as a crisp shape
	in daylight instead of a white blur; they look big and layered rather than bright.
]]

local Config = require(script.Parent.Config)

local AnimeFX = {}

local rgb = Color3.fromRGB
local WHITE = rgb(255, 255, 255)
local BLACK = rgb(15, 10, 25)

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
	Chain = "",
	Seal = "",
	Runes = "rbxasset://textures/particles/sparkles_main.dds",
	Crack = "",
	DarkFlame = "rbxasset://textures/particles/fire_main.dds",
	Ember = "rbxasset://textures/particles/sparkles_main.dds",
	Wisp = "rbxasset://textures/particles/smoke_main.dds",
	Burst = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
}
AnimeFX.Names = { "Aura", "ToonFire", "ShockRing", "Impact", "ToonSmoke", "Lightning", "Slash", "SpeedLines", "Kira", "Petal", "Chain", "Seal", "Runes", "Crack", "DarkFlame", "Ember", "Wisp", "Burst" }

-- How each flipbook plays (only used with the uploaded texture: the built-in ones are single images).
local FLIPBOOKS: { [string]: { Layout: Enum.ParticleFlipbookLayout, Mode: Enum.ParticleFlipbookMode, Rate: number? } } = {
	Aura = { Layout = Enum.ParticleFlipbookLayout.Grid4x4, Mode = Enum.ParticleFlipbookMode.Loop, Rate = 20 },
	ToonFire = { Layout = Enum.ParticleFlipbookLayout.Grid4x4, Mode = Enum.ParticleFlipbookMode.Loop, Rate = 18 },
	ShockRing = { Layout = Enum.ParticleFlipbookLayout.Grid4x4, Mode = Enum.ParticleFlipbookMode.OneShot },
	Impact = { Layout = Enum.ParticleFlipbookLayout.Grid4x4, Mode = Enum.ParticleFlipbookMode.OneShot },
	ToonSmoke = { Layout = Enum.ParticleFlipbookLayout.Grid4x4, Mode = Enum.ParticleFlipbookMode.OneShot },
	Lightning = { Layout = Enum.ParticleFlipbookLayout.Grid2x2, Mode = Enum.ParticleFlipbookMode.Random },
	Runes = { Layout = Enum.ParticleFlipbookLayout.Grid2x2, Mode = Enum.ParticleFlipbookMode.Random },
	DarkFlame = { Layout = Enum.ParticleFlipbookLayout.Grid4x4, Mode = Enum.ParticleFlipbookMode.Loop, Rate = 18 },
	Wisp = { Layout = Enum.ParticleFlipbookLayout.Grid4x4, Mode = Enum.ParticleFlipbookMode.OneShot },
	Burst = { Layout = Enum.ParticleFlipbookLayout.Grid4x4, Mode = Enum.ParticleFlipbookMode.OneShot },
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
-- feet). `size` = how tall the flames are, `rate` = flames a second. Two layers - big flames in the
-- aura's deep colours and a brighter, narrower core in front - and specks of energy shooting up.
-- Returns its emitters.
function AnimeFX.Ki(parent: BasePart, colors: { Color3 }, size: number, rate: number): { ParticleEmitter }
	local main, deep = colors[1], colors[#colors]
	local outer, custom = base(parent, "KiAura", "Aura")
	outer.Color = colorsOf({ main, main:Lerp(deep, 0.5), deep })
	outer.LightEmission = 0.25
	outer.Brightness = 1.3
	outer.Rate = rate
	outer.Shape = Enum.ParticleEmitterShape.Box
	outer.EmissionDirection = Enum.NormalId.Top
	outer.SpreadAngle = Vector2.new(6, 6)
	outer.Speed = NumberRange.new(size * 0.6, size * 1.1)
	outer.Acceleration = Vector3.new(0, size * 0.9, 0)
	outer.Drag = 1.5
	outer.Lifetime = NumberRange.new(0.55, 0.85)
	outer.Rotation = if custom then NumberRange.new(-6, 6) else NumberRange.new(-12, 12)
	outer.Size = if custom then seq({ 0, size * 0.7, 0.4, size * 1.25, 1, size }) else seq({ 0, size * 0.45, 0.4, size * 0.9, 1, size * 0.2 })
	outer.Transparency = seq({ 0, 1, 0.15, 0.05, 0.75, 0.3, 1, 1 })
	outer.Squash = NumberSequence.new(if custom then 0 else 0.6) -- (taller, thinner flames)
	outer:SetAttribute("FXBoost", true)

	local core = base(parent, "KiCore", "Aura")
	core.Color = colorsOf({ main:Lerp(WHITE, 0.35), main })
	core.LightEmission = 0.45
	core.Brightness = 1.5
	core.Rate = rate * 0.7
	core.Shape = Enum.ParticleEmitterShape.Box
	core.EmissionDirection = Enum.NormalId.Top
	core.SpreadAngle = Vector2.new(4, 4)
	core.Speed = NumberRange.new(size * 0.5, size * 0.9)
	core.Acceleration = Vector3.new(0, size * 0.7, 0)
	core.Drag = 1.5
	core.Lifetime = NumberRange.new(0.45, 0.7)
	core.Rotation = outer.Rotation
	core.Size = if custom then seq({ 0, size * 0.4, 0.4, size * 0.7, 1, size * 0.55 }) else seq({ 0, size * 0.25, 0.4, size * 0.5, 1, size * 0.1 })
	core.Transparency = seq({ 0, 1, 0.15, 0, 0.75, 0.25, 1, 1 })
	core.Squash = outer.Squash
	core.ZOffset = 0.8 -- (in front of the outer flames)
	core:SetAttribute("FXBoost", true)

	-- specks of energy shooting up through it
	local specks = base(parent, "KiSpecks", "Spark")
	specks.Color = ColorSequence.new(main:Lerp(WHITE, 0.4), main)
	specks.LightEmission = 0.5
	specks.Brightness = 1.6
	specks.Rate = rate * 0.8
	specks.Shape = Enum.ParticleEmitterShape.Box
	specks.EmissionDirection = Enum.NormalId.Top
	specks.SpreadAngle = Vector2.new(4, 4)
	specks.Speed = NumberRange.new(size * 3, size * 5)
	specks.Lifetime = NumberRange.new(0.25, 0.45)
	specks.Orientation = Enum.ParticleOrientation.VelocityParallel
	specks.Squash = NumberSequence.new(5)
	specks.Size = seq({ 0, size * 0.16, 1, 0 })
	specks.Transparency = seq({ 0, 0, 1, 0.5 })
	specks:SetAttribute("FXBoost", true)
	return { outer, core, specks }
end

-- Cartoon flames licking up from a flat box under it (solid, with a dark outline: not a glow).
function AnimeFX.ToonFire(parent: BasePart, colors: { Color3 }, size: number, rate: number): ParticleEmitter
	local e, custom = base(parent, "ToonFire", "ToonFire")
	e.Color = colorsOf(colors)
	e.LightEmission = if custom then 0.1 else 0.2
	e.Brightness = if custom then 1.25 else 1.5
	e.Rate = rate
	e.Shape = Enum.ParticleEmitterShape.Box
	e.EmissionDirection = Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(10, 10)
	e.Speed = NumberRange.new(size * 0.8, size * 1.6)
	e.Acceleration = Vector3.new(0, size, 0)
	e.Lifetime = NumberRange.new(0.5, 0.8)
	e.Rotation = NumberRange.new(-8, 8)
	e.Size = seq({ 0, size * 0.6, 0.35, size, 1, size * 0.35 })
	e.Transparency = seq({ 0, 1, 0.1, 0, 0.8, 0.1, 1, 1 })
	e:SetAttribute("FXBoost", true)
	return e
end

-- Crescent slashes flashing on a sphere round it (`parent`: a part the size of that sphere).
function AnimeFX.Slashes(parent: BasePart, color: Color3, size: number, rate: number): ParticleEmitter
	local e, custom = base(parent, "Slashes", "Slash")
	e.Color = ColorSequence.new(color:Lerp(WHITE, 0.3), color)
	e.Rate = rate
	e.Shape = Enum.ParticleEmitterShape.Sphere
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	e.LockedToPart = true
	if custom then
		e.LightEmission = 0.35
		e.Brightness = 1.6
		e.Speed = NumberRange.new(0)
		e.Lifetime = NumberRange.new(0.22, 0.32)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-260, 260)
		e.Size = seq({ 0, size * 0.5, 0.25, size * 1.25, 1, size * 1.4 })
		e.Transparency = seq({ 0, 0, 0.55, 0, 1, 1 })
	else
		-- (no slash picture yet: long thin cuts flicking across it)
		e.LightEmission = 0.5
		e.Brightness = 1.8
		e.Speed = NumberRange.new(size * 6, size * 9)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Drag = 10
		e.Lifetime = NumberRange.new(0.14, 0.22)
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.Squash = NumberSequence.new(5)
		e.Size = seq({ 0, size * 0.4, 1, size * 0.12 })
		e.Transparency = seq({ 0, 0, 1, 0.7 })
	end
	e:SetAttribute("FXBoost", true)
	return e
end

-- Four-point twinkles popping all over a sphere round it.
function AnimeFX.Kira(parent: BasePart, color: Color3, size: number, rate: number): ParticleEmitter
	local e, custom = base(parent, "Kira", "Kira")
	e.Color = ColorSequence.new(color:Lerp(WHITE, 0.45), color)
	e.LightEmission = 0.6
	e.Brightness = 1.6
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
	e.Color = colorsOf({ colors[1]:Lerp(WHITE, 0.35), colors[1] })
	e.LightEmission = 0.55
	e.Brightness = 1.8
	e.Rate = rate
	e.Shape = Enum.ParticleEmitterShape.Sphere
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	e.LockedToPart = true
	if custom then
		e.Speed = NumberRange.new(0)
		e.Lifetime = NumberRange.new(0.08, 0.16)
		e.Rotation = NumberRange.new(0, 360)
		e.Size = seq({ 0, size * 1.1, 1, size * 1.25 })
		e.Transparency = seq({ 0, 0, 1, 0.3 })
	else
		-- (no bolt picture yet: short, thin jagged-looking flickers)
		e.Speed = NumberRange.new(0.5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Lifetime = NumberRange.new(0.06, 0.12)
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.Squash = NumberSequence.new(6)
		e.Size = NumberSequence.new(size * 0.5)
		e.Transparency = NumberSequence.new(0)
	end
	e:SetAttribute("FXBoost", true)
	return e
end

-- An impact frame (ring, star flash, dark manga burst lines, smoke puffs), built ready to fire:
-- put it at the centre of the hit (`parent`: an Attachment or a part). `size` = how big the hit is.
function AnimeFX.Impact(parent: Instance, colors: { Color3 }, size: number): { ParticleEmitter }
	local list = {}
	local main = colors[1]
	local ring, ringCustom = base(parent, "ImpactRing", "ShockRing")
	ring.Color = ColorSequence.new(main:Lerp(WHITE, 0.3), main)
	ring.LightEmission = 0.3
	ring.Brightness = 1.5
	ring.Rate = 0
	ring.Speed = NumberRange.new(0)
	ring.Lifetime = NumberRange.new(0.45)
	ring.Rotation = NumberRange.new(0, 360)
	ring.Size = if ringCustom then seq({ 0, size * 3, 1, size * 7.5 }) else seq({ 0, size * 0.6, 0.3, size * 5, 1, size * 7.5 })
	ring.Transparency = if ringCustom then NumberSequence.new(0) else seq({ 0, 0, 0.6, 0.2, 1, 1 })
	ring.ZOffset = 1
	ring:SetAttribute("Burst", 1)
	table.insert(list, ring)

	local star = base(parent, "ImpactStar", "Impact")
	star.Color = ColorSequence.new(main:Lerp(WHITE, 0.5), main)
	star.LightEmission = 0.45
	star.Brightness = 1.9
	star.Rate = 0
	star.Speed = NumberRange.new(0)
	star.Lifetime = NumberRange.new(0.28)
	star.Rotation = NumberRange.new(0, 360)
	star.Size = seq({ 0, size * 3.8, 1, size * 5 })
	star.Transparency = seq({ 0, 0, 0.6, 0.05, 1, 1 })
	star.ZOffset = 1.5
	star:SetAttribute("Burst", 1)
	table.insert(list, star)

	-- (dark, like the burst lines in a manga panel)
	local lines = base(parent, "ImpactLines", "Spark")
	lines.Color = ColorSequence.new(main:Lerp(BLACK, 0.55), main:Lerp(BLACK, 0.35))
	lines.LightEmission = 0
	lines.Brightness = 1
	lines.Rate = 0
	lines.SpreadAngle = Vector2.new(180, 180)
	lines.Speed = NumberRange.new(size * 16, size * 26)
	lines.Drag = 6
	lines.Lifetime = NumberRange.new(0.2, 0.32)
	lines.Orientation = Enum.ParticleOrientation.VelocityParallel
	lines.Squash = NumberSequence.new(6)
	lines.Size = seq({ 0, size * 0.6, 1, size * 0.15 })
	lines.Transparency = seq({ 0, 0, 1, 0.6 })
	lines:SetAttribute("Burst", 14)
	table.insert(list, lines)

	local smoke = base(parent, "ImpactSmoke", "ToonSmoke")
	smoke.Color = ColorSequence.new(rgb(235, 232, 240), main:Lerp(rgb(120, 115, 135), 0.65))
	smoke.LightEmission = 0.05
	smoke.Brightness = 1
	smoke.Rate = 0
	smoke.SpreadAngle = Vector2.new(180, 20)
	smoke.EmissionDirection = Enum.NormalId.Front
	smoke.Speed = NumberRange.new(size * 4, size * 7)
	smoke.Drag = 4
	smoke.Lifetime = NumberRange.new(0.55, 0.8)
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-60, 60)
	smoke.Size = seq({ 0, size * 1.1, 1, size * 2.1 })
	smoke.Transparency = seq({ 0, 0.05, 0.7, 0.25, 1, 1 })
	smoke:SetAttribute("Burst", 6)
	table.insert(list, smoke)
	return list
end

-- The hellfire set (the hell donuts' chains: shared/HellChains) ---------------------------------

-- Embers drifting up off `parent` (a part: they start anywhere over it).
function AnimeFX.Embers(parent: BasePart, colors: { Color3 }, size: number, rate: number): ParticleEmitter
	local e, custom = base(parent, "Embers", "Ember")
	e.Color = colorsOf(colors)
	e.LightEmission = 0.7
	e.Brightness = 1.6
	e.Rate = rate
	e.EmissionDirection = Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(18, 18)
	e.Speed = NumberRange.new(size * 6, size * 11)
	e.Acceleration = Vector3.new(0, size * 4, 0)
	e.Drag = 1.2
	e.Lifetime = NumberRange.new(0.9, 1.7)
	e.Orientation = if custom then Enum.ParticleOrientation.VelocityParallel else Enum.ParticleOrientation.FacingCamera
	e.Size = seq({ 0, size, 0.7, size * 0.8, 1, 0 })
	e.Transparency = seq({ 0, 0, 0.75, 0.1, 1, 1 })
	e.Rotation = NumberRange.new(0, 360)
	e:SetAttribute("FXBoost", true)
	return e
end

-- Hellfire licking up off `parent`: a bright edge round a dark heart (the built-in stand-in is a
-- deep red flame).
function AnimeFX.DarkFlame(parent: BasePart, colors: { Color3 }, size: number, rate: number): ParticleEmitter
	local e, custom = base(parent, "DarkFlame", "DarkFlame")
	e.Color = if custom then colorsOf(colors) else ColorSequence.new(colors[1]:Lerp(BLACK, 0.35), colors[#colors]:Lerp(BLACK, 0.6))
	e.LightEmission = if custom then 0.35 else 0.2
	e.Brightness = 1.4
	e.Rate = rate
	e.EmissionDirection = Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(8, 8)
	e.Speed = NumberRange.new(size * 0.8, size * 1.6)
	e.Lifetime = NumberRange.new(0.45, 0.8)
	e.Size = seq({ 0, size * 0.6, 0.3, size, 1, size * 0.4 })
	e.Transparency = seq({ 0, 0.05, 0.75, 0.2, 1, 1 })
	e.Rotation = if custom then NumberRange.new(-8, 8) else NumberRange.new(0, 360)
	e:SetAttribute("FXBoost", true)
	return e
end

-- Curls of dark smoke rising off `parent`.
function AnimeFX.Wisps(parent: BasePart, color: Color3, size: number, rate: number): ParticleEmitter
	local e, custom = base(parent, "Wisps", "Wisp")
	e.Color = ColorSequence.new(color:Lerp(WHITE, 0.15), color)
	e.LightEmission = 0.05
	e.Rate = rate
	e.EmissionDirection = Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(15, 15)
	e.Speed = NumberRange.new(size * 0.4, size * 0.9)
	e.Lifetime = NumberRange.new(1.4, 2.2)
	e.Rotation = if custom then NumberRange.new(-15, 15) else NumberRange.new(0, 360)
	e.RotSpeed = if custom then NumberRange.new(0) else NumberRange.new(-30, 30)
	e.Size = seq({ 0, size * 0.6, 1, size * 1.2 })
	e.Transparency = seq({ 0, 0.25, 0.7, 0.45, 1, 1 })
	e:SetAttribute("FXBoost", true)
	return e
end

-- Glowing marks floating slowly up off `parent` (the seal under a chained donut).
function AnimeFX.Runes(parent: BasePart, color: Color3, size: number, rate: number): ParticleEmitter
	local e = base(parent, "Runes", "Runes")
	e.Color = ColorSequence.new(color:Lerp(WHITE, 0.4), color)
	e.LightEmission = 0.6
	e.Brightness = 1.6
	e.Rate = rate
	e.EmissionDirection = Enum.NormalId.Top
	e.Speed = NumberRange.new(size * 0.8, size * 1.6)
	e.Drag = 0.6
	e.Lifetime = NumberRange.new(1.6, 2.6)
	e.Rotation = NumberRange.new(-10, 10)
	e.Size = seq({ 0, 0, 0.2, size, 0.8, size, 1, 0 })
	e.Transparency = seq({ 0, 0.1, 0.7, 0.2, 1, 1 })
	e:SetAttribute("FXBoost", true)
	return e
end

-- A power-up burst of spikes round `parent`, built ready to go: AnimeFX.Fire sets it off.
function AnimeFX.Burst(parent: Instance, colors: { Color3 }, size: number): ParticleEmitter
	local e, custom = base(parent, "BurstSpikes", "Burst")
	e.Color = colorsOf(colors)
	e.LightEmission = 0.45
	e.Brightness = 1.8
	e.Rate = 0
	e.Speed = NumberRange.new(0)
	e.Lifetime = NumberRange.new(0.4)
	e.Rotation = NumberRange.new(0, 360)
	e.Size = if custom then seq({ 0, size * 2.2, 1, size * 4 }) else seq({ 0, size * 0.5, 0.3, size * 3.2, 1, size * 4 })
	e.Transparency = if custom then NumberSequence.new(0) else seq({ 0, 0, 0.6, 0.3, 1, 1 })
	e.ZOffset = 1
	e:SetAttribute("Burst", 1)
	return e
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
