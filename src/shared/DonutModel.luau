--[[
	DonutModel
	==========
	Builds a donut "character" out of plain parts (no uploaded meshes needed): a smooth dough ring
	(a torus made of short cylinders laid end to end), a glossy glaze ring in front of it with a wavy,
	dripping edge, sprinkles lying on the glaze, a cute face and brainrot accessories (legs,
	sunglasses, shark fin...).

	Rarer donuts get more and more effects (sparkles, lights, floating, light pillars, orbiting orbs,
	halos, rainbow frosting, a shimmering aura for Secrets). Mutations recolour the donut and add
	their own effects (Gold shines, Diamond is glassy, Mythic grows horns, Divine gets wings and a
	halo, Rainbow cycles colours). Sizes scale the whole donut.
	On top of that, Legendary+ donuts and mutated ones get a mystical theme (FXThemes.luau): sun rays,
	particle vortexes, hellfire, god rays... plus lightning, magic circles and comets animated by
	each client (client/DonutFX.luau).

	The model is a single rigid assembly: the invisible "Root" part is anchored and every other part is
	welded to it, so moving Root moves the whole donut (cheap to animate on the client).
	Moving parts (legs, arms, wings, propellers, orbiting orbs, tentacles, capes) are marked with a
	"Limb" attribute and the point they swing around ("Pivot", in the donut's own space); the eyes
	("EyeWhite"), pupils ("Pupil") and mouth ("Mouth") are marked too, so the client can make the
	donut blink, look around and open its mouth (see client/DonutIdle.luau).

	Used by the server (lane spawns, bases, podiums, carried donuts) and the client (Index previews).
]]

local CollectionService = game:GetService("CollectionService")

local Config = require(script.Parent.Config)

local Rarities = require(script.Parent.Rarities)
local Format = require(script.Parent.Format)
local Donuts = require(script.Parent.Donuts)
local Areas = require(script.Parent.Areas)
local FXThemes = require(script.Parent.FXThemes)
local DonutExtras = require(script.Parent.DonutExtras)
local DonutLooks = require(script.Parent.DonutLooks)
local DonutLayers = require(script.Parent.DonutLayers)
local DonutAuras = require(script.Parent.DonutAuras)

type Donut = Donuts.Donut

local DonutModel = {}

local RING_RADIUS = 1.5
local BALL = 1.55 -- thickness of the dough ring
local SEGMENTS = 16 -- tube pieces in the dough ring
local GLAZE_SEGMENTS = 18 -- the glaze is shinier, so it gets a few more (smoother highlights)
local FROSTING_OFFSET = -0.3 -- the glaze sits on the front face (-Z is the donut's front)
local FROSTING_TUBE = 1.36
-- Studded donuts (Config.DonutModels): the ring is built from square-edged blocks, a few fewer of
-- them (chunkier), and the glaze is two steps: a wide "shoulder" and a narrower raised "crown" in the
-- middle, so its front follows the round glaze closely and everything placed on it still sits on it.
local STUDDED = Config.DonutModels.Studded
local STUDDED_SEGMENTS, STUDDED_GLAZE_SEGMENTS = 12, 14
-- (the shoulder stands a little proud of the dough's front, -BALL / 2, so both layers show)
local CROWN_HALF, CROWN_FRONT, SHOULDER_FRONT = 0.38, -1.0, -0.86
local HALF_DIP = -0.3 -- a half-dipped donut's glaze stops where sin(angle round the ring) drops below this
local STUD_FACES = { "TopSurface", "BottomSurface", "FrontSurface", "BackSurface", "LeftSurface", "RightSurface" }

local rgb = Color3.fromRGB
local WHITE = rgb(255, 255, 255)
local BLACK = rgb(20, 20, 20)

export type BuildOptions = {
	Scale: number?,
	Pillar: boolean?, -- tall light pillar (rare lane donuts, so players can spot them from afar)
	NoEffects: boolean?, -- skip lights/particles (viewport previews)
	Calm: boolean?, -- softer effects (donuts on bases: lots of them side by side would glare)
	Mutation: string?,
	Size: string?,
	NoFace: boolean?, -- just a donut (the Update Log's emblem): no face, sprinkles all the way round
}

local function hashString(text: string): number
	local hash = 7
	for i = 1, #text do
		hash = (hash * 31 + string.byte(text, i)) % 2147483647
	end
	return hash
end

local function emitter(parent: Instance, color: ColorSequence, rate: number, size: number, speed: number, lifetime: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Color = color
	e.LightEmission = 1
	e.Rate = rate
	e.Lifetime = NumberRange.new(lifetime * 0.6, lifetime)
	e.Speed = NumberRange.new(speed * 0.4, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new(0.1, 1)
	e.Parent = parent
	return e
end

-- Particle textures: Roblox's own (always there), unless Config.DonutFX.Textures names others.
local TEXTURES: { [string]: string } = {
	Spark = "rbxasset://textures/particles/sparkles_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Swirl = "rbxasset://textures/particles/forcefield_vortex_main.dds",
}
local function texture(name: string): string
	local custom = Config.DonutFX.Textures[name]
	return if type(custom) == "string" and custom ~= "" then custom else TEXTURES[name]
end
DonutModel.Texture = texture

local function keys(colors: { Color3 }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local list = {}
	for i, color in colors do
		table.insert(list, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(list)
end

function DonutModel.Build(donut: Donut, options: BuildOptions?): Model
	local opts: BuildOptions = options or {}
	local rarity = Rarities.Get(donut.Rarity)
	local mutation = Rarities.Mutation(opts.Mutation)
	local size = Rarities.Size(opts.Size)
	-- Its personality (face, feet, muscles, glaze style, markings, size) comes from its name
	local look = DonutLooks.For(donut, rarity.Order)
	local s = (opts.Scale or 1) * size.Scale * look.Scale
	local rng = Random.new(hashString(donut.Id))
	local partsSet = {}
	for _, name in donut.Parts do
		partsSet[name] = true
	end
	if mutation.Halo then
		partsSet.Halo = true
	end
	if mutation.Wings then
		partsSet.Wings = true
	end
	if mutation.Horns then
		partsSet.Horns = true
	end
	if look.Muscles > 0 and not partsSet.PlaneWings and not partsSet.Tentacles then
		partsSet.Arms = true -- strong donuts show off their arms
	end

	local doughColor = mutation.Dough or donut.Dough
	local frostingColor = mutation.Frosting or donut.Frosting
	-- the second colour (two-tone glaze, drizzles, markings): a mutation keeps to its own colours
	local accent = if mutation.Frosting then frostingColor:Lerp(if mutation.Id == "Gold" then WHITE else Color3.new(0, 0, 0), 0.35) else look.Accent
	local frostingMaterial = mutation.Material or Enum.Material.SmoothPlastic
	local doughMaterial = if mutation.Material == Enum.Material.Neon then Enum.Material.SmoothPlastic else (mutation.Material or Enum.Material.SmoothPlastic)
	local special = mutation.Order >= 1 -- mutated donuts look shinier

	local model = Instance.new("Model")
	model.Name = donut.Id

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(3, 3, 1.5) * s
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Massless = true
	root.CFrame = CFrame.identity
	root.Parent = model
	model.PrimaryPart = root

	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x * s, y * s, z * s)
	end

	local function add(p: BasePart, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
		p.Anchored = false
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Material = material or Enum.Material.SmoothPlastic
		p.Color = color
		p.CFrame = cf
		local weld = Instance.new("Weld")
		weld.Part0 = root
		weld.Part1 = p
		weld.C0 = cf
		weld.Parent = p
		p.Parent = model
		return p
	end

	local function ball(diameter: number, color: Color3, cf: CFrame, material: Enum.Material?, name: string?): BasePart
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.one * diameter * s
		p.Name = name or "Ball"
		return add(p, cf, color, material)
	end

	-- Stretched ball (a block with a sphere mesh: Ball parts are always perfectly round).
	local function ellipsoid(sizeV: Vector3, color: Color3, cf: CFrame, material: Enum.Material?, name: string?): BasePart
		local p = Instance.new("Part")
		p.Size = sizeV * s
		p.Name = name or "Ellipsoid"
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		return add(p, cf, color, material)
	end

	local function block(sizeV: Vector3, color: Color3, cf: CFrame, material: Enum.Material?, name: string?): BasePart
		local p = Instance.new("Part")
		p.Size = sizeV * s
		p.Name = name or "Block"
		return add(p, cf, color, material)
	end

	-- Cylinder standing upright (Roblox cylinders point along X by default).
	local function cylinder(height: number, diameter: number, color: Color3, cf: CFrame, material: Enum.Material?, name: string?): BasePart
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(height, diameter, diameter) * s
		p.Name = name or "Cylinder"
		return add(p, cf * CFrame.Angles(0, 0, math.pi / 2), color, material)
	end

	local function wedge(sizeV: Vector3, color: Color3, cf: CFrame, material: Enum.Material?): BasePart
		local p = Instance.new("WedgePart")
		p.Size = sizeV * s
		p.Name = "Wedge"
		return add(p, cf, color, material)
	end

	-- Mark a part as an animatable limb that swings around `pivot` (unscaled donut coordinates).
	local function limb(part: BasePart, kind: string, side: number, px: number, py: number, pz: number): BasePart
		part:SetAttribute("Limb", kind)
		part:SetAttribute("Side", side)
		part:SetAttribute("Pivot", Vector3.new(px, py, pz) * s)
		return part
	end

	local R = RING_RADIUS
	local TOP = R + BALL / 2 -- top of the ring
	local shine = if rarity.Shine or special then 0.15 else 0.06
	local TAU = math.pi * 2
	local FROST_R = FROSTING_TUBE / 2

	-- A smooth ring (a torus) out of straight tube pieces: one cylinder per segment lying along the
	-- ring, each just long enough to meet its neighbours on the outside without a notch.
	-- `shade(angle)` lightens (+) or darkens (-) each piece a little: baked-looking dough, glossy glaze.
	-- (studded: square blocks, `depth` deep front to back)
	-- `keep(angle)` leaves pieces out (half-dipped glaze).
	local function ring(count: number, diameter: number, z: number, color: Color3, material: Enum.Material, name: string, shade: ((number) -> number)?, depth: number?, keep: ((number) -> boolean)?): { BasePart }
		local step = TAU / count
		local length = 2 * R * math.sin(step / 2) + diameter * math.tan(step / 2)
		local pieces = {}
		for i = 0, count - 1 do
			local angle = i * step
			if keep and not keep(angle) then
				continue
			end
			local p = Instance.new("Part")
			p.Shape = if STUDDED then Enum.PartType.Block else Enum.PartType.Cylinder
			p.Size = Vector3.new(length, diameter, depth or diameter) * s
			p.Name = name
			local cf = at(R * math.cos(angle), R * math.sin(angle), z) * CFrame.Angles(0, 0, angle + math.pi / 2)
			local tint = color
			if shade then
				local amount = shade(angle)
				tint = if amount > 0 then color:Lerp(WHITE, amount) else color:Lerp(Color3.new(0, 0, 0), -amount)
			end
			table.insert(pieces, add(p, cf, tint, material))
		end
		return pieces
	end

	-- A spot on the glaze, facing out of it: `angle` around the ring, `tilt` from the front of the
	-- tube towards its outer edge (negative = towards the hole), `lift` above the surface.
	local function onGlaze(angle: number, tilt: number, lift: number): CFrame
		local radial = Vector3.new(math.cos(angle), math.sin(angle), 0)
		local normal = radial * math.sin(tilt) + Vector3.new(0, 0, -math.cos(tilt))
		local point = radial * R + Vector3.new(0, 0, FROSTING_OFFSET) + normal * (FROST_R + lift)
		if STUDDED then
			-- on the flat front of the stepped glaze (the crown in the middle, the shoulder outside it)
			local offset = math.sin(tilt) * FROST_R
			local front = if math.abs(offset) <= CROWN_HALF then CROWN_FRONT else SHOULDER_FRONT
			point = radial * (R + offset) + Vector3.new(0, 0, front) + normal * lift
		end
		return CFrame.lookAt(point * s, (point + normal) * s)
	end

	-- The glaze surface in front of the point (x, y) on the donut's face.
	local function face(x: number, y: number, lift: number): CFrame
		local offset = math.clamp(math.sqrt(x * x + y * y) - R, -FROST_R * 0.95, FROST_R * 0.95)
		return onGlaze(math.atan2(y, x), math.asin(offset / FROST_R), lift)
	end

	-- Dough ring, with the glaze in front of it (the dough shows around its edges)
	-- (the dough is golden on top and more baked underneath; the glaze catches light from the top left)
	for _, piece in ring(if STUDDED then STUDDED_SEGMENTS else SEGMENTS, BALL, 0, doughColor, doughMaterial, "Dough", function(angle: number): number
		local up = math.sin(angle)
		return if up > 0 then up * 0.1 else up * 0.2
	end) do
		piece.Reflectance = shine * 0.3
	end
	local function glazeShade(angle: number): number
		local light = math.cos(angle - math.rad(135))
		return if light > 0 then light * 0.1 else light * 0.07
	end
	-- Glaze styles (DonutLooks): a half-dipped donut only has glaze on its top part
	local function glazed(angle: number): boolean
		return look.Glaze ~= "HalfDip" or math.sin(angle) > HALF_DIP
	end
	-- Two layers of glaze: a wide one a shade darker, and a raised middle on top of it that catches
	-- the light (a second colour on "TwoTone" donuts)
	local underColor = if look.Rim and not mutation.Frosting then look.Rim else frostingColor:Lerp(Color3.new(0, 0, 0), 0.14)
	local crownColor = if look.Glaze == "TwoTone" then accent else frostingColor
	local glaze
	if STUDDED then
		-- shoulder: as wide as the round glaze, standing a little proud of the dough; crown on top
		glaze = ring(STUDDED_GLAZE_SEGMENTS, FROSTING_TUBE, SHOULDER_FRONT / 2, underColor, frostingMaterial, "Frosting", glazeShade, -SHOULDER_FRONT, glazed)
		local crownDepth = SHOULDER_FRONT - CROWN_FRONT + 0.1
		for _, piece in ring(STUDDED_GLAZE_SEGMENTS, CROWN_HALF * 2, CROWN_FRONT + crownDepth / 2, crownColor, frostingMaterial, "Frosting", function(angle: number): number
			return glazeShade(angle) + 0.05 -- the raised middle catches a bit more light
		end, crownDepth, glazed) do
			table.insert(glaze, piece)
		end
	else
		glaze = ring(GLAZE_SEGMENTS, FROSTING_TUBE, FROSTING_OFFSET, frostingColor, frostingMaterial, "Frosting", glazeShade, nil, glazed)
	end

	-- Wavy glaze edge: tongues of glaze lying over the dough rim all the way round; on the lower
	-- sides some run right over the edge like drips.
	local edgeCount = 8
	for n = 0, edgeCount - 1 do
		local angle = (n + rng:NextNumber(-0.25, 0.25)) / edgeCount * TAU + 0.2
		local radial = Vector3.new(math.cos(angle), math.sin(angle), 0)
		local dripChance = if look.Glaze == "Drippy" or look.Glaze == "MegaDrip" then 1 else 0.75
		local drip = radial.Y < -0.2 and math.abs(radial.X) > 0.4 and rng:NextNumber() < dripChance
		if not glazed(angle) then
			continue
		end
		-- how far round the dough tube (from its front towards the outside) the tongue sits
		local around = math.rad(if drip then 74 else 60)
		local normal = radial * math.sin(around) + Vector3.new(0, 0, -math.cos(around))
		local downTube = radial * math.cos(around) + Vector3.new(0, 0, math.sin(around))
		local tangent = Vector3.new(-radial.Y, radial.X, 0)
		local center = (radial * R + normal * (BALL / 2)) * s
		local length = if drip then rng:NextNumber(0.85, 1.1) else rng:NextNumber(0.45, 0.6)
		local cf = CFrame.fromMatrix(center, tangent, normal, downTube)
		if STUDDED then
			-- a flat tab of glaze on the square ring's outer side, running back from its front edge
			local depth = math.min(length, BALL) * 0.8
			center = (radial * (R + BALL / 2 + 0.06) + Vector3.new(0, 0, -BALL / 2 + depth / 2)) * s
			cf = CFrame.fromMatrix(center, tangent, radial, Vector3.new(0, 0, 1))
			length = depth
		end
		table.insert(glaze, ellipsoid(Vector3.new(if drip then 0.4 else 0.55, 0.2, length), if look.Rim and not mutation.Frosting then underColor else frostingColor, cf, frostingMaterial, "Frosting"))
	end
	-- a band of another colour round the edge of the hole (HoleColor), over the outer layer
	local holeColor = if look.HoleColor and not mutation.Frosting then look.HoleColor else underColor
	if STUDDED and look.HoleColor and not mutation.Frosting then
		local count = STUDDED_GLAZE_SEGMENTS
		local width = FROST_R - CROWN_HALF + 0.02
		local radius = R - (FROST_R + CROWN_HALF) / 2
		local step = TAU / count
		for n = 0, count - 1 do
			local angle = n * step
			local piece = Instance.new("Part")
			piece.Size = Vector3.new(2 * radius * math.sin(step / 2) + width * math.tan(step / 2), width, 0.08) * s
			piece.Name = "Frosting"
			local cf = at(radius * math.cos(angle), radius * math.sin(angle), SHOULDER_FRONT - 0.03) * CFrame.Angles(0, 0, angle + math.pi / 2)
			table.insert(glaze, add(piece, cf, holeColor, frostingMaterial))
		end
	end
	-- glaze lining the inside of the hole too (HoleLining)
	if look.HoleLining then
		local count = 12
		local inner = R - BALL / 2 - 0.04
		for n = 0, count - 1 do
			local angle = (n + 0.5) / count * TAU
			local radial = Vector3.new(math.cos(angle), math.sin(angle), 0)
			local tangent = Vector3.new(-radial.Y, radial.X, 0)
			local piece = Instance.new("Part")
			piece.Size = Vector3.new(2 * inner * math.sin(math.pi / count) + 0.1, 0.1, BALL * 0.92) * s
			piece.Name = "Frosting"
			table.insert(glaze, add(piece, CFrame.fromMatrix(radial * inner * s, tangent, radial, -Vector3.zAxis), holeColor, frostingMaterial))
		end
	end
	for _, piece in glaze do
		piece.Reflectance = shine
		if mutation.Id == "Diamond" then
			piece.Transparency = 0.15
		end
	end

	-- Sprinkles lying on the glaze (none on the face): rods, tiny beads, flat confetti or chunks
	local sprinkleColors = donut.Sprinkles
	if mutation.Id == "Gold" then
		sprinkleColors = { rgb(255, 250, 200), rgb(255, 180, 40) }
	elseif mutation.Id == "Diamond" then
		sprinkleColors = { WHITE, rgb(150, 230, 255) }
	end
	if sprinkleColors then
		local colors = sprinkleColors
		local style = if opts.NoFace then "Jimmies" else look.Sprinkles
		local count = if opts.NoFace then 26 elseif style == "Nonpareils" then 20 elseif style == "Chunks" then 12 else 16
		for n = 1, count do
			local angle
			repeat
				angle = rng:NextNumber(0, TAU)
			until (opts.NoFace or math.abs(angle - math.pi / 2) > 0.62) and (glazed(angle) and math.sin(angle) > HALF_DIP + 0.12 or look.Glaze ~= "HalfDip")
			local sprinkle = Instance.new("Part")
			sprinkle.Name = "Sprinkle"
			local color = colors[(n - 1) % #colors + 1]
			local cf = onGlaze(angle, rng:NextNumber(-1.0, 1.1), 0.0) * CFrame.Angles(0, 0, rng:NextNumber(0, TAU))
			if style == "Nonpareils" then
				sprinkle.Shape = Enum.PartType.Ball
				sprinkle.Size = Vector3.one * 0.16 * s
			elseif style == "Confetti" then
				sprinkle.Size = Vector3.new(0.24, 0.24, 0.05) * s
			elseif style == "Chunks" then
				sprinkle.Size = Vector3.new(0.24, 0.2, 0.16) * s
				cf *= CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.4, 0.4), 0)
				color = if n % 3 == 0 then color else look.Accent:Lerp(Color3.new(0, 0, 0), 0.25)
			else
				sprinkle.Shape = Enum.PartType.Cylinder
				sprinkle.Size = Vector3.new(0.4, 0.12, 0.12) * s
			end
			add(sprinkle, cf, color, if special then Enum.Material.Neon else Enum.Material.SmoothPlastic)
		end
	end

	-- A soft shine on the glaze (top left, beside the face)
	if mutation.Id ~= "Diamond" then
		local gloss = ellipsoid(Vector3.new(0.85, 0.2, 0.05), WHITE, onGlaze(math.rad(150), -0.25, 0.012) * CFrame.Angles(0, 0, math.rad(150) + math.pi / 2), nil, "Gloss")
		gloss.Transparency = 0.55
	end

	-- Face: layered eyes (a dark rim, the white, a coloured iris, the pupil and two shines), cheeks
	-- and a mouth, all shaped by the donut's mood (DonutLooks): angry brows, sleepy lids, a toothy
	-- grin, a tongue sticking out, glowing ghost eyes, robot screen eyes...
	-- The client squashes the eye whites and rims ("EyeWhite") to blink, shifts the irises, pupils
	-- and shines ("Pupil") to look around, and opens the mouth (widens the middle, "Mouth" =
	-- "Middle", and hides the rest, "Mouth" = "Corner") when the donut jumps or dances.
	if not opts.NoFace then
		local eyesCovered = partsSet.Sunglasses or partsSet.Visor
		local EYE_Y = TOP - 0.66
		local mood = look.Mood
		local tiltCf = CFrame.Angles(0, 0, -look.Tilt)
		local DARK = rgb(45, 28, 32)
		local NEON = Enum.Material.Neon
		-- (x, y) on the face, turned with the head tilt about the middle of the face
		local function lean(x: number, y: number): (number, number)
			if look.Tilt == 0 then
				return x, y
			end
			local c, sn = math.cos(-look.Tilt), math.sin(-look.Tilt)
			local dy = y - (EYE_Y - 0.3)
			return x * c - dy * sn, EYE_Y - 0.3 + x * sn + dy * c
		end
		-- a point (u, v) in an eye centred on (ex, ey), `z` deep
		local function eyePoint(ex: number, ey: number, u: number, v: number, z: number): CFrame
			return at(ex, ey, z) * tiltCf * CFrame.new(u * s, v * s, 0)
		end
		local function onFace(x: number, y: number, lift: number): CFrame
			local lx, ly = lean(x, y)
			return face(lx, ly, lift) * tiltCf
		end
		local function tag(part: BasePart, key: string, value: any): BasePart
			part:SetAttribute(key, value)
			return part
		end
		local skin = crownColor:Lerp(Color3.new(0, 0, 0), 0.08) -- eyelids are glaze-coloured

		local function roundEye(side: number)
			local W, H = 0.62, 0.8
			if mood == "Fierce" or mood == "Mighty" then
				W, H = 0.66, 0.6
			elseif mood == "Spooky" then
				W, H = 0.66, 0.74
			elseif mood == "Robot" then
				W, H = 0.72, 0.46
			elseif mood == "Silly" then
				local k = if side < 0 then 1.15 else 0.86
				W, H = 0.62 * k, 0.8 * k
			end
			local ex, ey = lean(side * 0.5, EYE_Y + (if mood == "Fierce" or mood == "Mighty" then -0.05 else 0))
			local white = if mood == "Spooky" then rgb(25, 14, 36) elseif mood == "Robot" then rgb(14, 22, 34) else WHITE
			local rimColor = if mood == "Robot" then rgb(95, 100, 115) elseif mood == "Spooky" then rgb(8, 4, 12) else DARK
			if mood == "Robot" or mood == "Spooky" then
				-- a screen's metal bezel / a dark socket
				tag(ellipsoid(Vector3.new(W + 0.12, H + 0.12, 0.36), rimColor, eyePoint(ex, ey, 0, 0, CROWN_FRONT + 0.04), if mood == "Robot" then Enum.Material.Metal else nil, "EyeRim"), "EyeWhite", true)
			end
			tag(ellipsoid(Vector3.new(W, H, 0.36), white, eyePoint(ex, ey, 0, 0, CROWN_FRONT + 0.01), nil, "Eye"), "EyeWhite", true)
			local px = if mood == "Silly" then -side * 0.1 else -side * 0.04 -- looking a little inwards
			local k = W / 0.62
			if mood == "Robot" then
				tag(block(Vector3.new(W * 0.78, H * 0.36, 0.06), look.Iris, eyePoint(ex, ey, 0, 0, CROWN_FRONT - 0.19), NEON, "Pupil"), "Pupil", true)
				tag(block(Vector3.new(W * 0.26, H * 0.1, 0.05), WHITE, eyePoint(ex, ey, -W * 0.2, H * 0.06, CROWN_FRONT - 0.23), NEON, "Glint"), "Pupil", true)
			elseif mood == "Spooky" then
				tag(ellipsoid(Vector3.new(W * 0.5, H * 0.54, 0.06), look.Iris, eyePoint(ex, ey, px, -0.04, CROWN_FRONT - 0.19), NEON, "Pupil"), "Pupil", true)
				tag(ball(0.08, WHITE, eyePoint(ex, ey, px - 0.05, 0.05, CROWN_FRONT - 0.24), NEON, "Glint"), "Pupil", true)
			else
				tag(ellipsoid(Vector3.new(W * 0.7, H * 0.7, 0.06), look.Iris, eyePoint(ex, ey, px, -0.04, CROWN_FRONT - 0.19), if look.GlowEyes then NEON else nil, "Iris"), "Pupil", true)
				tag(ellipsoid(Vector3.new(W * 0.38, H * 0.42, 0.06), BLACK, eyePoint(ex, ey, px, -0.05, CROWN_FRONT - 0.22), nil, "Pupil"), "Pupil", true)
				tag(ball(0.17 * k, WHITE, eyePoint(ex, ey, px - 0.08 * k, 0.09 * k, CROWN_FRONT - 0.26), NEON, "Glint"), "Pupil", true)
				tag(ball(0.08 * k, WHITE, eyePoint(ex, ey, px + 0.08 * k, -0.14 * k, CROWN_FRONT - 0.26), NEON, "Glint"), "Pupil", true)
			end
			-- sleepy / cool / regal eyelids, lashes and brows
			local top = (H + 0.12) / 2
			local lid = if mood == "Dreamy" then 0.46 elseif mood == "Cool" then 0.38 elseif mood == "Royal" then 0.3 else 0
			if lid > 0 then
				local lh = (H + 0.12) * lid
				block(Vector3.new(W + 0.16, lh, 0.1), skin, eyePoint(ex, ey, 0, top - lh / 2 + 0.02, CROWN_FRONT - 0.31), nil, "EyeLid")
				block(Vector3.new(W + 0.18, 0.07, 0.11), DARK, eyePoint(ex, ey, 0, top - lh + 0.02, CROWN_FRONT - 0.315), nil, "LashLine")
				top -= lh
			end
			if look.Lashes then
				for i = 0, 1 do
					block(Vector3.new(0.22, 0.06, 0.08), DARK, eyePoint(ex, ey, side * (W / 2 + 0.04), top - i * 0.12, CROWN_FRONT - 0.3) * CFrame.Angles(0, 0, side * (0.6 - i * 0.45)), nil, "Lash")
				end
			end
			if mood == "Fierce" or mood == "Mighty" or mood == "Royal" or mood == "Silly" then
				local bw, bh, angle, rise = 0.66, 0.17, side * 0.38, 0.14
				if mood == "Mighty" then
					bw, bh, angle = 0.72, 0.2, side * 0.22
				elseif mood == "Royal" then
					bw, bh, angle = 0.5, 0.08, -side * 0.18
				elseif mood == "Silly" then
					bw, bh = 0.5, 0.1
					angle, rise = if side < 0 then side * 0.25 else 0, if side < 0 then 0.3 else 0.12
				end
				block(Vector3.new(bw, bh, 0.3), rgb(55, 32, 28), eyePoint(ex, ey, -side * 0.02, (H + 0.12) / 2 + rise, CROWN_FRONT - 0.03) * CFrame.Angles(0, 0, angle), nil, "Brow")
			end
		end

		-- Big anime eyes: a thick dark lash line with a flick at the corner, a big grey iris with a
		-- white heart for its shine, and little drops at the outer corners (Look.Eyes "Heart")
		local function heartEye(side: number)
			local W, H = 0.86, 0.7
			local ex, ey = lean(side * 0.55, EYE_Y - 0.04)
			local LASH = rgb(22, 20, 26)
			tag(ellipsoid(Vector3.new(W, H, 0.34), WHITE, eyePoint(ex, ey, 0, 0, CROWN_FRONT), nil, "Eye"), "EyeWhite", true)
			local ix = -side * 0.04
			tag(ellipsoid(Vector3.new(0.6, 0.66, 0.06), look.Iris, eyePoint(ex, ey, ix, -0.02, CROWN_FRONT - 0.19), nil, "Iris"), "Pupil", true)
			tag(block(Vector3.new(0.58, 0.2, 0.05), look.Iris:Lerp(Color3.new(0, 0, 0), 0.6), eyePoint(ex, ey, ix, 0.21, CROWN_FRONT - 0.215), nil, "Pupil"), "Pupil", true)
			-- the heart: two diamond lobes and a bigger diamond for its point
			for _, lobe in { -1, 1 } do
				tag(block(Vector3.new(0.16, 0.16, 0.05), WHITE, eyePoint(ex, ey, ix + lobe * 0.078, 0.02, CROWN_FRONT - 0.25) * CFrame.Angles(0, 0, math.rad(45)), NEON, "Heart"), "Pupil", true)
			end
			tag(block(Vector3.new(0.2, 0.2, 0.05), WHITE, eyePoint(ex, ey, ix, -0.08, CROWN_FRONT - 0.25) * CFrame.Angles(0, 0, math.rad(45)), NEON, "Heart"), "Pupil", true)
			tag(ball(0.07, WHITE, eyePoint(ex, ey, ix - side * 0.19, -0.2, CROWN_FRONT - 0.25), NEON, "Glint"), "Pupil", true)
			-- lashes: the thick top line, its flick past the outer corner and a soft line underneath
			block(Vector3.new(W + 0.08, 0.15, 0.12), LASH, eyePoint(ex, ey, side * 0.02, H / 2 + 0.03, CROWN_FRONT - 0.25), nil, "Lash")
			block(Vector3.new(0.32, 0.12, 0.12), LASH, eyePoint(ex, ey, side * (W / 2 + 0.1), H / 2 - 0.07, CROWN_FRONT - 0.25) * CFrame.Angles(0, 0, -side * 0.55), nil, "Lash")
			block(Vector3.new(0.14, 0.1, 0.12), LASH, eyePoint(ex, ey, -side * (W / 2 + 0.02), H / 2 - 0.02, CROWN_FRONT - 0.25) * CFrame.Angles(0, 0, side * 0.35), nil, "Lash")
			block(Vector3.new(0.42, 0.05, 0.08), rgb(95, 88, 100), eyePoint(ex, ey, side * 0.14, -H / 2 - 0.01, CROWN_FRONT - 0.2), nil, "Lash")
			-- the drops at the outer corner
			for i, drop in { { 0, 0.15, 0.22 }, { 0.18, 0.12, 0.17 } } do
				local tear = ellipsoid(Vector3.new(drop[2], drop[3], 0.08), rgb(195, 228, 255), eyePoint(ex, ey, side * (W / 2 - 0.04 - drop[1]), -H / 2 - 0.09 - i * 0.03, CROWN_FRONT - 0.14), Enum.Material.Glass, "Tear")
				tear.Transparency = 0.15
				tear.Reflectance = 0.3
			end
		end

		-- Dizzy anime eyes: a thick lash line, a swirly iris (rings getting smaller and turning as they
		-- go in, dark and light in turn), grey shadows under them and worried brows (Look.Eyes "Spiral")
		local function spiralEye(side: number)
			local W, H = 0.84, 0.66
			local ex, ey = lean(side * 0.52, EYE_Y - 0.04)
			local LASH = rgb(22, 20, 26)
			tag(ellipsoid(Vector3.new(W, H, 0.34), WHITE, eyePoint(ex, ey, 0, 0, CROWN_FRONT), nil, "Eye"), "EyeWhite", true)
			local ix = -side * 0.03
			for ring = 0, 4 do
				local size = 0.58 - ring * 0.11
				local color = if ring % 2 == 0 then look.Iris else rgb(235, 235, 240)
				local cf = eyePoint(ex, ey, ix, -0.02, CROWN_FRONT - 0.19 - ring * 0.012) * CFrame.Angles(0, 0, side * ring * 0.32)
				tag(block(Vector3.new(size, size, 0.05), color, cf, nil, if ring == 0 then "Pupil" else "Iris"), "Pupil", true)
			end
			tag(ball(0.07, WHITE, eyePoint(ex, ey, ix - side * 0.2, 0.17, CROWN_FRONT - 0.27), NEON, "Glint"), "Pupil", true)
			-- lashes: the thick top line with a flick at the corner, a soft line underneath
			block(Vector3.new(W + 0.08, 0.15, 0.12), LASH, eyePoint(ex, ey, side * 0.02, H / 2 + 0.03, CROWN_FRONT - 0.27), nil, "Lash")
			block(Vector3.new(0.3, 0.11, 0.12), LASH, eyePoint(ex, ey, side * (W / 2 + 0.09), H / 2 - 0.06, CROWN_FRONT - 0.27) * CFrame.Angles(0, 0, -side * 0.5), nil, "Lash")
			block(Vector3.new(0.4, 0.05, 0.08), rgb(95, 88, 100), eyePoint(ex, ey, side * 0.12, -H / 2 - 0.01, CROWN_FRONT - 0.2), nil, "Lash")
			-- grey shadows under the eyes and worried brows, high up and slanting up to the middle
			block(Vector3.new(W * 0.8, 0.14, 0.04), rgb(150, 140, 150), eyePoint(ex, ey, side * 0.04, -H / 2 - 0.1, CROWN_FRONT - 0.13), nil, "EyeBag").Transparency = 0.35
			block(Vector3.new(0.5, 0.06, 0.2), rgb(50, 40, 45), eyePoint(ex, ey, -side * 0.06, H / 2 + 0.24, CROWN_FRONT - 0.06) * CFrame.Angles(0, 0, -side * 0.28), nil, "Brow")
		end

		for _, side in { -1, 1 } do
			if look.Eyes == "Heart" then
				heartEye(side)
			elseif look.Eyes == "Spiral" then
				spiralEye(side)
			elseif not eyesCovered and not (partsSet.EyePatch and side == 1) then
				roundEye(side)
			end
			if mood ~= "Fierce" and mood ~= "Mighty" and mood ~= "Spooky" and mood ~= "Robot" and mood ~= "Cool" and look.Eyes ~= "Spiral" then
				ellipsoid(Vector3.new(0.4, 0.22, 0.1), rgb(255, 120, 150), onFace(side * 0.9, TOP - 1.1, 0), nil, "Cheek").Transparency = 0.3
				if look.Eyes == "Heart" then
					-- anime blush lines
					for i = -1, 1 do
						block(Vector3.new(0.05, 0.22, 0.06), rgb(255, 95, 135), onFace(side * (0.92 + i * 0.11), TOP - 1.1, 0.04) * CFrame.Angles(0, 0, -0.45), nil, "Blush")
					end
				end
			end
		end

		if not partsSet.Mustache and not partsSet.Beak and not partsSet.Fangs then
			local mouthY = TOP - 1.2
			local dark = rgb(90, 30, 35)
			local pink = rgb(255, 120, 140)
			local function middle(part: BasePart)
				part:SetAttribute("Mouth", "Middle")
			end
			local function corner(part: BasePart)
				part:SetAttribute("Mouth", "Corner")
			end
			if look.Eyes == "Spiral" then
				-- a little nose mark, a big open "o" mouth, and drool running out of it in strands that
				-- hang down over the hole, each with a drop at its end
				block(Vector3.new(0.05, 0.07, 0.06), rgb(70, 60, 65), onFace(0.04, EYE_Y - 0.42, 0.03), nil, "Nose")
				-- (placed straight in front of the glaze: face() would pull the bits that hang over the
				-- hole back onto the glaze, and tip the mouth with the tube's curve)
				local function hanging(x: number, y: number, depth: number?): CFrame
					local lx, ly = lean(x, y)
					return at(lx, ly, SHOULDER_FRONT - (depth or 0.15)) * tiltCf
				end
				local mouthMid = mouthY - 0.195
				middle(ellipsoid(Vector3.new(0.44, 0.54, 0.12), rgb(40, 25, 30), hanging(0, mouthMid, 0.1), nil, "Mouth"))
				local lip = mouthMid - 0.26
				corner(ellipsoid(Vector3.new(0.26, 0.1, 0.1), rgb(150, 140, 150), hanging(0, lip + 0.08), nil, "Mouth"))
				local drool = rgb(205, 225, 240)
				local function droolPart(size: Vector3, cf: CFrame)
					local part = block(size, drool, cf, Enum.Material.Glass, "Drool")
					part.Transparency = 0.2
					part.Reflectance = 0.3
					corner(part)
				end
				droolPart(Vector3.new(0.3, 0.07, 0.08), hanging(0, lip))
				for _, strand in { { X = 0.05, Length = 0.55, Width = 0.09 }, { X = -0.08, Length = 0.36, Width = 0.07 }, { X = 0.13, Length = 0.2, Width = 0.06 } } do
					droolPart(Vector3.new(strand.Width, strand.Length, 0.07), hanging(strand.X, lip - strand.Length / 2))
					droolPart(Vector3.one * (strand.Width * 1.7), hanging(strand.X, lip - strand.Length - strand.Width * 0.6))
				end
			elseif mood == "Happy" then
				middle(ellipsoid(Vector3.new(0.44, 0.24, 0.1), dark, onFace(0, mouthY - 0.06, 0.02), nil, "Mouth"))
				corner(ellipsoid(Vector3.new(0.24, 0.1, 0.1), pink, onFace(0, mouthY - 0.12, 0.05), nil, "Tongue"))
				for _, side in { -1, 1 } do
					corner(ellipsoid(Vector3.new(0.14, 0.09, 0.1), dark, onFace(side * 0.25, mouthY + 0.03, 0.02) * CFrame.Angles(0, 0, side * math.rad(40)), nil, "Mouth"))
				end
			elseif mood == "Fierce" or mood == "Mighty" then
				local wide = if mood == "Fierce" then 0.62 else 0.5
				middle(block(Vector3.new(wide, if mood == "Fierce" then 0.22 else 0.17, 0.1), dark, onFace(0, mouthY - 0.04, 0.02), nil, "Mouth"))
				corner(block(Vector3.new(wide - 0.08, 0.07, 0.1), WHITE, onFace(0, mouthY + 0.02, 0.04), nil, "Teeth"))
				if mood == "Fierce" then
					for _, side in { -1, 1 } do
						corner(block(Vector3.new(0.08, 0.13, 0.1), WHITE, onFace(side * 0.17, mouthY - 0.04, 0.05), nil, "Teeth"))
					end
				end
			elseif mood == "Silly" then
				middle(ellipsoid(Vector3.new(0.4, 0.2, 0.1), dark, onFace(0.04, mouthY - 0.05, 0.02), nil, "Mouth"))
				corner(block(Vector3.new(0.22, 0.3, 0.1), pink, onFace(0.1, mouthY - 0.2, 0.05) * CFrame.Angles(0, 0, -0.25), nil, "Tongue"))
			elseif mood == "Cool" then
				middle(ellipsoid(Vector3.new(0.3, 0.09, 0.1), dark, onFace(0.06, mouthY - 0.02, 0.02) * CFrame.Angles(0, 0, 0.12), nil, "Mouth"))
				corner(ellipsoid(Vector3.new(0.16, 0.08, 0.1), dark, onFace(0.24, mouthY + 0.03, 0.02) * CFrame.Angles(0, 0, 0.6), nil, "Mouth"))
			elseif mood == "Spooky" then
				middle(ellipsoid(Vector3.new(0.26, 0.32, 0.1), rgb(20, 10, 25), onFace(0, mouthY - 0.08, 0.02), nil, "Mouth"))
			elseif mood == "Robot" then
				middle(block(Vector3.new(0.46, 0.08, 0.06), look.Iris, onFace(0, mouthY - 0.03, 0.03), NEON, "Mouth"))
				for _, side in { -1, 1 } do
					corner(block(Vector3.new(0.08, 0.08, 0.06), look.Iris, onFace(side * 0.27, mouthY + 0.03, 0.03), NEON, "Mouth"))
				end
			else
				-- a smile (smaller and calmer on dreamy and royal donuts)
				local small = mood == "Dreamy" or mood == "Royal"
				middle(ellipsoid(Vector3.new(if small then 0.2 else 0.28, if small then 0.09 else 0.11, 0.1), dark, onFace(0, mouthY - 0.035, 0.02), nil, "Mouth"))
				for _, side in { -1, 1 } do
					corner(ellipsoid(Vector3.new(if small then 0.16 else 0.22, if small then 0.08 else 0.1, 0.1), dark, onFace(side * (if small then 0.13 else 0.18), mouthY, 0.02) * CFrame.Angles(0, 0, side * math.rad(if small then 35 else 30)), nil, "Mouth"))
				end
			end
		end
	end

	-- Brainrot accessories
	local accessories = {}

	-- Legs, and feet that match the donut (DonutLooks): layered sneakers (sole, toe cap, stripe,
	-- laces), high-tops, boots with a buckle, paws with toe beans, hooves, claws, webbed feet, robot
	-- feet or sandals. Strong donuts have thicker legs.
	function accessories.Legs()
		local thick = if look.Muscles >= 2 then 0.5 elseif look.Muscles == 1 then 0.44 else 0.36
		local shoe, stripe, sole = look.Shoe, look.ShoeAccent, look.Sole
		for _, side in { -1, 1 } do
			local hipX, hipY = side * 0.55, -TOP + 0.2
			local x = side * 0.55
			local function leg(part: BasePart): BasePart
				return limb(part, "Leg", side, hipX, hipY, 0)
			end
			leg(block(Vector3.new(thick, 1.25, thick), doughColor, at(x, -TOP - 0.42, 0), nil, "Leg"))
			local feet = look.Feet
			if feet == "Plain" then
				-- (restyled by ballet slippers, flamingo legs...)
				leg(ellipsoid(Vector3.new(0.62, 0.46, 0.92), rgb(235, 50, 60), at(x, -TOP - 1.08, -0.16), nil, "Shoe"))
				leg(ellipsoid(Vector3.new(0.7, 0.2, 1.0), WHITE, at(x, -TOP - 1.24, -0.17), nil, "Sole"))
			elseif feet == "Sneakers" or feet == "HighTops" then
				local high = feet == "HighTops"
				leg(block(Vector3.new(0.72, 0.2, 1.04), sole, at(x, -TOP - 1.24, -0.17), nil, "Sole"))
				leg(block(Vector3.new(0.64, if high then 0.62 else 0.4, 0.92), shoe, at(x, -TOP - (if high then 0.95 else 1.04), -0.14), nil, "Shoe"))
				leg(block(Vector3.new(0.62, 0.24, 0.3), sole:Lerp(shoe, 0.12), at(x, -TOP - 1.1, -0.53), nil, "ToeCap"))
				leg(block(Vector3.new(0.68, 0.1, 0.5), stripe, at(x, -TOP - 1.02, -0.02), nil, "ShoeStripe"))
				if high then
					leg(block(Vector3.new(0.68, 0.14, 0.62), stripe, at(x, -TOP - 0.66, 0), nil, "Collar"))
				else
					leg(block(Vector3.new(0.34, 0.07, 0.3), WHITE, at(x, -TOP - 0.83, -0.36), nil, "Laces"))
				end
			elseif feet == "Boots" then
				leg(block(Vector3.new(0.72, 0.18, 1.0), sole, at(x, -TOP - 1.25, -0.16), nil, "Sole"))
				leg(block(Vector3.new(0.66, 0.44, 0.94), shoe, at(x, -TOP - 1.06, -0.15), nil, "Shoe"))
				leg(block(Vector3.new(0.6, 0.62, 0.62), shoe, at(x, -TOP - 0.62, 0.02), nil, "BootShaft"))
				leg(block(Vector3.new(0.68, 0.14, 0.68), shoe:Lerp(WHITE, 0.3), at(x, -TOP - 0.32, 0.02), nil, "BootCuff"))
				leg(block(Vector3.new(0.22, 0.16, 0.06), stripe, at(x, -TOP - 0.86, -0.31), Enum.Material.Foil, "Buckle"))
			elseif feet == "Paws" then
				leg(block(Vector3.new(0.66, 0.1, 0.78), sole, at(x, -TOP - 1.3, -0.16), nil, "Sole"))
				leg(block(Vector3.new(0.72, 0.46, 0.86), shoe, at(x, -TOP - 1.08, -0.16), nil, "Shoe"))
				for i = -1, 1 do
					leg(block(Vector3.new(0.16, 0.13, 0.06), stripe, at(x + i * 0.21, -TOP - 1.02, -0.61), nil, "ToeBean"))
				end
			elseif feet == "Hooves" then
				leg(block(Vector3.new(0.6, 0.46, 0.7), shoe, at(x, -TOP - 1.12, -0.08), nil, "Shoe"))
				leg(block(Vector3.new(0.7, 0.2, 0.78), stripe, at(x, -TOP - 0.86, -0.08), nil, "FurCuff"))
				leg(block(Vector3.new(0.06, 0.42, 0.06), sole, at(x, -TOP - 1.13, -0.44), nil, "HoofSplit"))
			elseif feet == "Claws" then
				leg(block(Vector3.new(0.68, 0.4, 0.84), shoe, at(x, -TOP - 1.14, -0.12), nil, "Shoe"))
				leg(block(Vector3.new(0.7, 0.12, 0.88), sole, at(x, -TOP - 0.95, -0.1), nil, "Scale"))
				for i = -1, 1 do
					leg(wedge(Vector3.new(0.14, 0.2, 0.3), stripe, at(x + i * 0.22, -TOP - 1.24, -0.68)))
				end
			elseif feet == "Webbed" then
				leg(block(Vector3.new(0.84, 0.16, 0.95), shoe, at(x, -TOP - 1.28, -0.2), nil, "Shoe"))
				for i = -1, 1, 2 do
					leg(block(Vector3.new(0.05, 0.18, 0.6), stripe, at(x + i * 0.2, -TOP - 1.27, -0.32), nil, "Webbing"))
				end
			elseif feet == "Robot" then
				leg(block(Vector3.new(0.74, 0.16, 1.02), sole, at(x, -TOP - 1.27, -0.16), nil, "Sole"))
				leg(block(Vector3.new(0.68, 0.4, 0.94), shoe, at(x, -TOP - 1.06, -0.15), Enum.Material.Metal, "Shoe"))
				leg(block(Vector3.new(0.7, 0.08, 0.5), stripe, at(x, -TOP - 1.0, -0.3), Enum.Material.Neon, "ShoeLight"))
				leg(ball(0.42, shoe:Lerp(WHITE, 0.2), at(x, -TOP - 0.8, 0), Enum.Material.Metal, "Ankle"))
			else -- Sandals
				leg(block(Vector3.new(0.7, 0.14, 1.0), sole, at(x, -TOP - 1.27, -0.16), nil, "Sole"))
				leg(block(Vector3.new(0.56, 0.26, 0.86), shoe, at(x, -TOP - 1.08, -0.15), nil, "Shoe"))
				for _, z in { -0.36, 0.04 } do
					leg(block(Vector3.new(0.62, 0.08, 0.14), stripe, at(x, -TOP - 0.98, z), nil, "Strap"))
				end
			end
		end
	end

	function accessories.Arms()
		local shoulderY = -0.25
		if look.Muscles > 0 then
			-- Flexing: a round shoulder, a big bicep, the forearm up, a sweatband and a fist
			local k = if look.Muscles >= 2 then 1.15 else 1
			local arm = doughColor
			local band = if look.Feet == "Boots" then rgb(225, 40, 50) else look.Shoe
			for _, side in { -1, 1 } do
				local shoulderX = side * (R + 0.74)
				local function piece(part: BasePart)
					limb(part, "Arm", side, shoulderX, shoulderY, -0.1)
				end
				piece(ball(0.6 * k, arm:Lerp(WHITE, 0.05), at(side * (R + 0.8), 0.02, -0.1), nil, "Shoulder"))
				piece(block(Vector3.new(1.0, 0.46 * k, 0.46 * k), arm, at(side * (R + 1.28), -0.12, -0.1) * CFrame.Angles(0, 0, side * -0.06), nil, "UpperArm"))
				piece(block(Vector3.new(0.62 * k, 0.5 * k, 0.52 * k), arm:Lerp(WHITE, 0.14), at(side * (R + 1.05), 0.2 + 0.08 * k, -0.12), nil, "Bicep"))
				piece(block(Vector3.new(0.42 * k, 0.7, 0.42 * k), arm:Lerp(Color3.new(0, 0, 0), 0.08), at(side * (R + 1.66), 0.2, -0.1) * CFrame.Angles(0, 0, side * -0.12), nil, "Forearm"))
				piece(block(Vector3.new(0.5 * k, 0.16, 0.5 * k), band, at(side * (R + 1.62), 0.56, -0.1), nil, "Wristband"))
				piece(ball(0.56 * k, WHITE, at(side * (R + 1.58), 0.84, -0.1), nil, "Glove"))
			end
			return
		end
		for _, side in { -1, 1 } do
			local cf = at(side * (R + 1.05), 0.2, -0.1) * CFrame.Angles(0, 0, side * math.rad(-35))
			-- The shoulder is the arm's inner end, where it meets the ring
			local shoulderX = side * (R + 0.74)
			limb(cylinder(1.1, 0.3, doughColor, cf), "Arm", side, shoulderX, shoulderY, -0.1)
			-- a cuff in the colour of its shoes, then the glove
			limb(block(Vector3.new(0.4, 0.16, 0.4), look.Shoe, at(side * (R + 1.29), 0.5, -0.1) * CFrame.Angles(0, 0, side * math.rad(-35)), nil, "Cuff"), "Arm", side, shoulderX, shoulderY, -0.1)
			limb(ball(0.52, WHITE, at(side * (R + 1.42), 0.72, -0.1), nil, "Glove"), "Arm", side, shoulderX, shoulderY, -0.1)
		end
	end

	function accessories.Bat()
		cylinder(2.8, 0.4, rgb(150, 100, 55), at(R + 1.5, 0.6, -0.4) * CFrame.Angles(0, 0, math.rad(-20)), Enum.Material.Wood, "Bat")
	end

	function accessories.Tutu()
		cylinder(0.22, 3.6, rgb(255, 170, 220), at(0, -TOP + 0.2, 0), Enum.Material.SmoothPlastic, "Tutu").Transparency = 0.15
	end

	function accessories.Mustache()
		for _, side in { -1, 1 } do
			ellipsoid(Vector3.new(0.58, 0.24, 0.2), BLACK, face(side * 0.26, TOP - 1.14, 0.02) * CFrame.Angles(0, 0, side * math.rad(-15)), nil, "Mustache")
		end
	end

	function accessories.TopHat()
		cylinder(0.12, 1.9, BLACK, at(0, TOP + 0.06, 0))
		cylinder(1.2, 1.15, BLACK, at(0, TOP + 0.7, 0))
		cylinder(0.25, 1.17, rgb(200, 30, 40), at(0, TOP + 0.3, 0))
	end

	function accessories.Sunglasses()
		for _, side in { -1, 1 } do
			block(Vector3.new(0.7, 0.46, 0.12), BLACK, at(side * 0.5, TOP - 0.66, -1.12), Enum.Material.Glass, "Lens").Reflectance = 0.3
		end
		block(Vector3.new(0.36, 0.08, 0.1), BLACK, at(0, TOP - 0.58, -1.12))
	end

	function accessories.Visor()
		block(Vector3.new(1.9, 0.44, 0.14), rgb(0, 255, 255), at(0, TOP - 0.66, -1.12), Enum.Material.Neon, "Visor")
	end

	function accessories.Camel()
		for _, side in { -1, 1 } do
			ball(1.05, rgb(200, 150, 90), at(side * 0.5, TOP + 0.15, 0.25), nil, "Hump")
		end
	end

	function accessories.SharkFin()
		wedge(Vector3.new(0.3, 1.5, 1.6), rgb(120, 140, 170), at(0, TOP + 0.6, 0.35))
	end

	function accessories.Pharaoh()
		local gold, blue = rgb(255, 200, 40), rgb(30, 60, 180)
		block(Vector3.new(2.2, 0.9, 1.5), gold, at(0, TOP + 0.35, 0.1), Enum.Material.Foil)
		for i, side in { -1, 1 } do
			for j = 0, 2 do
				block(Vector3.new(0.45, 0.5, 1.1), if (i + j) % 2 == 0 then gold else blue, at(side * 1.25, TOP - 0.1 - j * 0.5, 0.1), Enum.Material.SmoothPlastic)
			end
		end
		ball(0.35, rgb(0, 200, 120), at(0, TOP + 0.45, -0.7), Enum.Material.Neon, "Gem")
	end

	function accessories.CoffeeCup()
		cylinder(1.2, 1.3, WHITE, at(0, TOP + 0.55, 0), Enum.Material.SmoothPlastic, "Cup")
		cylinder(0.05, 1.15, rgb(110, 65, 35), at(0, TOP + 1.16, 0), Enum.Material.SmoothPlastic, "Coffee")
		block(Vector3.new(0.2, 0.7, 0.2), WHITE, at(0.8, TOP + 0.55, 0))
	end

	function accessories.MonkeyEars()
		for _, side in { -1, 1 } do
			ball(0.9, rgb(120, 75, 40), at(side * (R + 0.55), 0.9, 0.05), nil, "Ear")
			ball(0.5, rgb(255, 190, 170), at(side * (R + 0.55), 0.9, -0.2), nil, "EarInner")
		end
	end

	function accessories.Horns()
		local color = if mutation.Horns then rgb(255, 30, 50) else rgb(240, 230, 200)
		local material = if mutation.Horns then Enum.Material.Neon else Enum.Material.SmoothPlastic
		for _, side in { -1, 1 } do
			block(Vector3.new(0.35, 0.7, 0.35), color, at(side * 0.95, TOP + 0.2, -0.05) * CFrame.Angles(0, 0, side * math.rad(-25)), material)
			block(Vector3.new(0.22, 0.5, 0.22), color, at(side * 1.18, TOP + 0.65, -0.05) * CFrame.Angles(0, 0, side * math.rad(-45)), material)
		end
	end

	function accessories.PlaneWings()
		local grey = rgb(110, 125, 110)
		block(Vector3.new(6, 0.2, 1.3), grey, at(0, 0, 0.3), Enum.Material.Metal, "Wing")
		for _, side in { -1, 1 } do
			cylinder(1.2, 0.55, rgb(80, 80, 80), at(side * 2.3, -0.4, 0.1) * CFrame.Angles(math.pi / 2, 0, 0), Enum.Material.Metal, "Engine")
		end
		block(Vector3.new(0.2, 1.1, 0.9), grey, at(0, TOP + 0.4, 0.5), Enum.Material.Metal, "Tail")
	end

	function accessories.Crown()
		local gold = rgb(255, 205, 50)
		cylinder(0.4, 1.6, gold, at(0, TOP + 0.15, 0), Enum.Material.Foil, "Crown")
		for i = 0, 4 do
			local angle = i / 5 * math.pi * 2
			block(Vector3.new(0.22, 0.5, 0.22), gold, at(math.cos(angle) * 0.65, TOP + 0.55, math.sin(angle) * 0.65), Enum.Material.Foil, "Crown")
		end
		ball(0.3, rgb(255, 30, 60), at(0, TOP + 0.15, -0.8), Enum.Material.Neon, "Gem")
	end

	function accessories.Halo()
		local color = if mutation.Id == "Rainbow" then rgb(255, 140, 255) else rgb(255, 240, 150)
		for i = 0, 11 do
			local angle = i / 12 * math.pi * 2
			ball(0.32, color, at(math.cos(angle) * 0.95, TOP + 1.0, math.sin(angle) * 0.95), Enum.Material.Neon, "Halo")
		end
	end

	function accessories.Wings()
		local glowing = rarity.Order >= 6 or mutation.Wings
		local material = if glowing then Enum.Material.Neon else Enum.Material.SmoothPlastic
		local color = if mutation.Wings then rgb(255, 250, 225) elseif glowing then rarity.Color:Lerp(WHITE, 0.6) else WHITE
		for _, side in { -1, 1 } do
			for f = 0, 2 do
				local wing = ellipsoid(
					Vector3.new(2.4 - f * 0.4, 0.8, 0.18),
					color,
					at(side * (R + 1.0 + f * 0.15), 0.9 - f * 0.55, 0.6) * CFrame.Angles(0, side * math.rad(-20), side * math.rad(25 - f * 12)),
					material,
					"Wing"
				)
				limb(wing, "Wing", side, side * (R - 0.1), 0.4, 0.6)
			end
		end
	end

	function accessories.Flames()
		local holder = block(Vector3.new(1, 1, 1), WHITE, at(0, TOP + 0.3, 0), nil, "FlameHolder")
		holder.Transparency = 1
		local fire = Instance.new("Fire")
		fire.Size = 3 * s
		fire.Heat = 6
		fire.Color = rgb(255, 120, 20)
		fire.SecondaryColor = rgb(255, 220, 60)
		fire.Parent = holder
	end

	function accessories.IceSpikes()
		local ice = rgb(170, 230, 255)
		for i = -2, 2 do
			block(Vector3.new(0.3, 0.9 - math.abs(i) * 0.15, 0.3), ice, at(i * 0.4, TOP + 0.3, 0) * CFrame.Angles(0, 0, math.rad(i * -12)), Enum.Material.Glass, "Spike")
		end
	end

	function accessories.Beak()
		wedge(Vector3.new(0.6, 0.35, 0.6), rgb(255, 160, 20), at(0, TOP - 1.1, -1.1) * CFrame.Angles(0, math.pi, 0))
	end

	function accessories.Antenna()
		block(Vector3.new(0.1, 1.2, 0.1), rgb(80, 80, 90), at(0, TOP + 0.55, 0), Enum.Material.Metal)
		ball(0.4, rgb(255, 40, 40), at(0, TOP + 1.2, 0), Enum.Material.Neon, "AntennaTip")
	end

	function accessories.Cape()
		local cape = block(Vector3.new(2.8, 3.2, 0.1), rgb(200, 30, 40), at(0, -0.4, 1.0) * CFrame.Angles(math.rad(-8), 0, 0), Enum.Material.Fabric, "Cape")
		limb(cape, "Cape", 0, 0, 1.2, 0.8)
	end

	function accessories.Orbit()
		local colors = { rgb(255, 200, 80), rgb(120, 200, 255), rgb(255, 120, 255) }
		for i = 1, 3 do
			local angle = i / 3 * math.pi * 2
			local orb = ball(0.5, colors[i], at(math.cos(angle) * (R + 1.7), math.sin(angle * 2) * 0.6, math.sin(angle) * (R + 1.7)), Enum.Material.Neon, "Orbit")
			limb(orb, "Orbit", 0, 0, 0, 0)
		end
	end

	function accessories.Leaf()
		local green = rgb(70, 180, 60)
		block(Vector3.new(0.12, 0.6, 0.12), rgb(100, 70, 40), at(0, TOP + 0.25, 0))
		ellipsoid(Vector3.new(1.1, 0.14, 0.55), green, at(0.45, TOP + 0.5, 0) * CFrame.Angles(0, 0, math.rad(20)), nil, "Leaf")
	end

	function accessories.Snorkel()
		for _, side in { -1, 1 } do
			cylinder(0.14, 0.92, rgb(120, 220, 255), at(side * 0.5, TOP - 0.66, -1.2) * CFrame.Angles(math.pi / 2, 0, 0), Enum.Material.Glass, "Goggle")
		end
		block(Vector3.new(2.1, 0.12, 0.1), rgb(40, 40, 50), at(0, TOP - 0.66, -1.12))
		cylinder(1.6, 0.22, rgb(255, 200, 40), at(R + 0.6, TOP - 0.1, -0.3), Enum.Material.SmoothPlastic, "Snorkel")
	end

	function accessories.Tentacles()
		-- Six tentacles hanging from the bottom of the ring, curling outwards at the ends
		local color = doughColor:Lerp(WHITE, 0.15)
		for n = 0, 5 do
			local angle = math.rad(228 + n * 16.8)
			local radial = Vector3.new(math.cos(angle), math.sin(angle), 0)
			local root = radial * (R + 0.35)
			local side = if radial.X < 0 then -1 else 1
			local down = (radial * 0.35 + Vector3.new(0, -1, 0)).Unit
			local curl = CFrame.fromAxisAngle(Vector3.zAxis, side * math.rad(40)):VectorToWorldSpace(down)
			local knee = root + down * 0.75
			local tip = knee + curl * 0.55
			local function segment(from: Vector3, to: Vector3, diameter: number): BasePart
				local mid = (from + to) / 2
				local p = Instance.new("Part")
				p.Shape = Enum.PartType.Cylinder
				p.Size = Vector3.new((to - from).Magnitude + diameter * 0.5, diameter, diameter) * s
				p.Name = "Tentacle"
				local along = (to - from).Unit
				return add(p, CFrame.fromMatrix(mid * s, along, Vector3.zAxis:Cross(along).Unit), color)
			end
			for _, piece in { segment(root, knee, 0.36), segment(knee, tip, 0.26), ball(0.3, frostingColor, at(tip.X, tip.Y, tip.Z), nil, "Tentacle") } do
				limb(piece, "Tentacle", side, root.X, root.Y, root.Z)
			end
		end
	end

	function accessories.Fangs()
		for _, side in { -1, 1 } do
			wedge(Vector3.new(0.12, 0.26, 0.12), WHITE, face(side * 0.17, TOP - 1.3, 0.04) * CFrame.Angles(math.pi, 0, 0))
		end
		ellipsoid(Vector3.new(0.6, 0.2, 0.12), rgb(90, 20, 30), face(0, TOP - 1.18, 0), nil, "Mouth")
	end

	function accessories.PirateHat()
		-- A tricorne: wide brim with the sides turned up, a round crown, and a skull badge
		ellipsoid(Vector3.new(2.4, 0.3, 1.5), BLACK, at(0, TOP - 0.02, 0), nil, "PirateHat")
		for _, side in { -1, 1 } do
			ellipsoid(Vector3.new(0.9, 0.3, 1.3), BLACK, at(side * 0.95, TOP + 0.18, 0) * CFrame.Angles(0, 0, side * math.rad(35)), nil, "PirateHat")
		end
		ellipsoid(Vector3.new(1.45, 1.0, 1.2), BLACK, at(0, TOP + 0.3, 0.05), nil, "PirateHat")
		ball(0.36, WHITE, at(0, TOP + 0.32, -0.56), nil, "Skull")
		for _, side in { -1, 1 } do
			block(Vector3.new(0.48, 0.08, 0.08), WHITE, at(0, TOP + 0.22, -0.58) * CFrame.Angles(0, 0, side * math.rad(35)), nil, "Skull")
		end
	end

	function accessories.EyePatch()
		ellipsoid(Vector3.new(0.66, 0.62, 0.16), BLACK, at(0.5, TOP - 0.66, -1.0), nil, "EyePatch")
		block(Vector3.new(2.6, 0.08, 0.08), BLACK, at(0, TOP - 0.45, -1.02) * CFrame.Angles(0, 0, math.rad(-12)))
	end

	function accessories.Propeller()
		ellipsoid(Vector3.new(1.6, 0.6, 1.4), rgb(255, 60, 60), at(0, TOP + 0.2, 0), nil, "Cap")
		block(Vector3.new(0.1, 0.5, 0.1), rgb(255, 230, 60), at(0, TOP + 0.65, 0))
		limb(block(Vector3.new(2, 0.06, 0.3), rgb(60, 140, 255), at(0, TOP + 0.9, 0), nil, "Propeller"), "Spin", 0, 0, TOP + 0.9, 0)
	end

	function accessories.WitchHat()
		local purple = rgb(60, 30, 80)
		cylinder(0.1, 2.4, purple, at(0, TOP + 0.05, 0))
		for i = 0, 3 do
			cylinder(0.45, 1.3 - i * 0.3, purple, at(i * 0.06, TOP + 0.3 + i * 0.42, 0))
		end
		cylinder(0.14, 1.32, rgb(140, 255, 120), at(0, TOP + 0.25, 0), Enum.Material.Neon)
	end

	function accessories.Gears()
		local brass = rgb(230, 180, 70)
		cylinder(0.2, 1.3, brass, at(0.3, TOP + 0.35, 0) * CFrame.Angles(math.pi / 2, 0, 0), Enum.Material.Foil, "Gear")
		cylinder(0.2, 0.8, brass, at(-0.55, TOP + 0.2, 0.1) * CFrame.Angles(math.pi / 2, 0, 0), Enum.Material.Foil, "Gear")
		for i = 0, 7 do
			local angle = i / 8 * math.pi * 2
			block(Vector3.new(0.2, 0.2, 0.2), brass, at(0.3 + math.cos(angle) * 0.7, TOP + 0.35 + math.sin(angle) * 0.7, 0), Enum.Material.Foil, "Tooth")
		end
	end

	function accessories.Kart()
		-- A little go-kart: the donut sits in it (a "Fake Kar")
		local paint, stripe, black = rgb(40, 140, 255), WHITE, rgb(25, 25, 30)
		block(Vector3.new(4.2, 0.8, 5.2), paint, at(0, -TOP + 0.25, 0), Enum.Material.SmoothPlastic, "KartBody").Reflectance = 0.15
		block(Vector3.new(4.24, 0.2, 5.24), stripe, at(0, -TOP + 0.5, 0), Enum.Material.SmoothPlastic, "KartStripe")
		block(Vector3.new(3.6, 1.6, 0.4), paint, at(0, -TOP + 1.2, 1.9) * CFrame.Angles(math.rad(-12), 0, 0), Enum.Material.SmoothPlastic, "KartSeat")
		-- front nose and bumper
		wedge(Vector3.new(3.4, 0.7, 1.4), paint, at(0, -TOP + 0.2, -3.2) * CFrame.Angles(0, math.pi, 0))
		local bumper = Instance.new("Part")
		bumper.Shape = Enum.PartType.Cylinder
		bumper.Size = Vector3.new(4, 0.35, 0.35) * s
		bumper.Name = "KartBumper"
		add(bumper, at(0, -TOP - 0.05, -3.95), black)
		for _, side in { -1, 1 } do
			ball(0.4, rgb(255, 240, 150), at(side * 1.3, -TOP + 0.45, -3.4), Enum.Material.Neon, "Headlight")
			for _, z in { -1.8, 1.8 } do
				local wheel = Instance.new("Part")
				wheel.Shape = Enum.PartType.Cylinder
				wheel.Size = Vector3.new(0.7, 1.4, 1.4) * s
				wheel.Name = "Wheel"
				add(wheel, at(side * 2.35, -TOP - 0.35, z), black)
				local hub = Instance.new("Part")
				hub.Shape = Enum.PartType.Cylinder
				hub.Size = Vector3.new(0.74, 0.6, 0.6) * s
				hub.Name = "Hubcap"
				add(hub, at(side * 2.36, -TOP - 0.35, z), rgb(200, 205, 215), Enum.Material.Metal)
			end
		end
		-- steering wheel in front of the donut, and a spoiler on the back
		local steering = Instance.new("Part")
		steering.Shape = Enum.PartType.Cylinder
		steering.Size = Vector3.new(0.15, 1.1, 1.1) * s
		steering.Name = "SteeringWheel"
		add(steering, at(0, -TOP + 1.1, -1.9) * CFrame.Angles(0, math.pi / 2, math.rad(-30)), black)
		for _, side in { -1, 1 } do
			block(Vector3.new(0.2, 0.9, 0.2), black, at(side * 1.4, -TOP + 1.2, 2.5), Enum.Material.Metal, "SpoilerPost")
		end
		block(Vector3.new(4, 0.2, 0.9), paint, at(0, -TOP + 1.7, 2.6) * CFrame.Angles(math.rad(10), 0, 0), Enum.Material.SmoothPlastic, "Spoiler")
	end

	function accessories.Bow()
		local pink = rgb(255, 110, 180)
		for _, side in { -1, 1 } do
			ellipsoid(Vector3.new(0.7, 0.5, 0.25), pink, at(side * 0.4 + 0.8, TOP + 0.05, -0.2) * CFrame.Angles(0, 0, side * math.rad(20)), nil, "Bow")
		end
		ball(0.3, pink, at(0.8, TOP + 0.05, -0.2), nil, "BowKnot")
	end

	for name in partsSet do
		local builder = accessories[name]
		if builder then
			builder()
		elseif not DonutExtras.Has(name) then
			warn(`[DonutModel] Unknown accessory "{name}" on donut {donut.Id}`)
		end
	end

	-- Signature accessories (DonutExtras) and the home area's little touches. They come after the
	-- classic ones because some restyle them (ballet slippers, crab claws...).
	local function findParts(name: string): { BasePart }
		local found = {}
		for _, child in model:GetChildren() do
			if child.Name == name and child:IsA("BasePart") then
				table.insert(found, child)
			end
		end
		return found
	end
	local kit: DonutExtras.Kit = {
		Id = donut.Id,
		s = s,
		R = R,
		TOP = TOP,
		BALL = BALL,
		FROST_R = FROST_R,
		Dough = doughColor,
		Frosting = frostingColor,
		Sprinkles = donut.Sprinkles or {},
		RarityOrder = rarity.Order,
		Studded = STUDDED,
		Rng = rng,
		at = at,
		ball = ball,
		ellipsoid = ellipsoid,
		block = block,
		cylinder = cylinder,
		wedge = wedge,
		limb = limb,
		onGlaze = onGlaze,
		face = face,
		has = function(name: string): boolean
			return partsSet[name] == true
		end,
		find = findParts,
		add = add,
	}
	for _, name in donut.Parts do
		if not accessories[name] then
			DonutExtras.Build(kit, name)
		end
	end
	if not opts.NoFace and look.BiomeDetails then
		local area = Areas.Get(donut.Area)
		if area then
			DonutExtras.Theme(kit, area.Theme, false)
		end
	end
	-- Drips, shine, markings, beads and gems on top of the glaze (DonutLayers)
	DonutLayers.Build(kit, look, {
		Accent = accent,
		Crown = crownColor,
		Material = frostingMaterial,
		ShoulderFront = if STUDDED then SHOULDER_FRONT else FROSTING_OFFSET - FROST_R,
		CrownFront = if STUDDED then CROWN_FRONT else FROSTING_OFFSET - FROST_R,
		HalfDip = HALF_DIP,
		Glow = if mutation.Order > 0 then mutation.Color else rarity.Color,
		NoEffects = opts.NoEffects == true,
		NoFace = opts.NoFace == true,
	})

	-- Studded (Config.DonutModels): every solid part becomes a block with the classic studs on all
	-- six sides, like Domer (see-through glows, force fields and the invisible root are left alone)
	if STUDDED then
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") and p ~= root and p.Transparency < 0.6 and p.Material ~= Enum.Material.ForceField then
				if p:IsA("Part") then
					p.Shape = Enum.PartType.Block
				end
				local mesh = p:FindFirstChildOfClass("SpecialMesh")
				if mesh and (mesh.MeshType == Enum.MeshType.Sphere or mesh.MeshType == Enum.MeshType.Cylinder) then
					mesh:Destroy()
				end
				for _, side in STUD_FACES do
					(p :: any)[side] = Enum.SurfaceType.Studs
				end
				if p.Material == Enum.Material.SmoothPlastic then
					p.Material = Enum.Material.Plastic
				end
			end
		end
	end

	-- Measure the model so callers can stand it on a surface and put labels above it.
	local top, bottom = -math.huge, math.huge
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p ~= root and p.Transparency < 1 and p.Name ~= "Aura" then
			local cf, sizeV = p.CFrame, p.Size
			local half = math.abs(cf.RightVector.Y) * sizeV.X / 2 + math.abs(cf.UpVector.Y) * sizeV.Y / 2 + math.abs(cf.LookVector.Y) * sizeV.Z / 2
			top = math.max(top, cf.Position.Y + half)
			bottom = math.min(bottom, cf.Position.Y - half)
		end
	end
	model:SetAttribute("DonutId", donut.Id)
	model:SetAttribute("Rarity", donut.Rarity)
	model:SetAttribute("Mutation", mutation.Id)
	model:SetAttribute("Size", size.Id)
	model:SetAttribute("Top", top)
	model:SetAttribute("Bottom", -bottom)

	-- Mystical theme parts ----------------------------------------------------
	local RAINBOW_SEQUENCE = ColorSequence.new({
		ColorSequenceKeypoint.new(0, rgb(255, 60, 60)),
		ColorSequenceKeypoint.new(0.2, rgb(255, 200, 40)),
		ColorSequenceKeypoint.new(0.4, rgb(60, 230, 90)),
		ColorSequenceKeypoint.new(0.6, rgb(60, 170, 255)),
		ColorSequenceKeypoint.new(0.8, rgb(170, 80, 255)),
		ColorSequenceKeypoint.new(1, rgb(255, 80, 200)),
	})

	-- Invisible welded part to hang effects on.
	local function holder(name: string, sizeV: Vector3, cf: CFrame): BasePart
		local p = Instance.new("Part")
		p.Size = sizeV
		p.Name = name
		local part = add(p, cf, WHITE)
		part.Transparency = 1
		return part
	end

	-- Light rays fanning out behind the donut; the client spins them (FXSpin = radians/second).
	local function burst(count: number, length: number, colors: { Color3 }, spin: number)
		local rays = holder("Burst", Vector3.one * 0.2, at(0, 0, 0.9))
		rays:SetAttribute("FXSpin", spin)
		local center = Instance.new("Attachment")
		center.Parent = rays
		for i = 1, count do
			local angle = i / count * TAU
			local reach = length * (if i % 2 == 0 then 1 else 0.62) * s
			local tip = Instance.new("Attachment")
			tip.Position = Vector3.new(math.cos(angle) * reach, math.sin(angle) * reach, 0)
			tip.Parent = rays
			local beam = Instance.new("Beam")
			beam.Attachment0 = center
			beam.Attachment1 = tip
			beam.FaceCamera = true
			beam.Segments = 1
			beam.Width0 = 0.75 * s
			beam.Width1 = 0.05 * s
			beam.LightEmission = 1
			beam.Brightness = 2
			beam.Color = ColorSequence.new(colors[(i - 1) % #colors + 1])
			beam.Transparency = NumberSequence.new(0.2, 1)
			beam.Parent = rays
		end
	end

	-- A sphere of particles around the donut, rushing in towards it or bursting out of it.
	local function shell(radius: number, inward: boolean, color: ColorSequence, rate: number, size: number, speed: number): ParticleEmitter
		local sphere = holder(if inward then "Vortex" else "Glitter", Vector3.one * radius * 2 * s, CFrame.identity)
		local e = emitter(sphere, color, rate, size * s, speed * s, radius / speed)
		e.Shape = Enum.ParticleEmitterShape.Sphere
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		e.ShapeInOut = if inward then Enum.ParticleEmitterShapeInOut.Inward else Enum.ParticleEmitterShapeInOut.Outward
		e.SpreadAngle = Vector2.new(4, 4)
		e.Speed = NumberRange.new(speed * s)
		e.Lifetime = NumberRange.new(radius / speed * 0.95)
		e.Brightness = 3
		e.LockedToPart = true
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0), NumberSequenceKeypoint.new(1, 0.3) })
		return e
	end

	-- Stars that pop in and out around the donut.
	local function twinkles(radius: number, color: ColorSequence, rate: number, size: number)
		local space = holder("Twinkles", Vector3.one * radius * 2 * s, CFrame.identity)
		local e = emitter(space, color, rate, size * s, 0.01, 1.2)
		e.Shape = Enum.ParticleEmitterShape.Sphere
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.Speed = NumberRange.new(0)
		e.Brightness = 4
		e.LockedToPart = true
		e.Rotation = NumberRange.new(0, 360)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, size * s), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new(0)
	end

	-- Rays of light shining down from the sky onto the donut, and flecks of light drifting down.
	local function godRays(colors: { Color3 })
		local sky = holder("HolySky", Vector3.new(4 * s, 0.2, 4 * s), at(0, 16, 0))
		local target = Instance.new("Attachment")
		target.Parent = root
		for i = 1, 5 do
			local angle = i / 5 * TAU
			local top = Instance.new("Attachment")
			top.Position = Vector3.new(math.cos(angle) * 2.4 * s, 0, math.sin(angle) * 2.4 * s)
			top.Parent = sky
			local ray = Instance.new("Beam")
			ray.Attachment0 = top
			ray.Attachment1 = target
			ray.FaceCamera = true
			ray.Segments = 1
			ray.Width0 = 2.6 * s
			ray.Width1 = 0.7 * s
			ray.LightEmission = 1
			ray.Brightness = 1.5
			ray.Color = ColorSequence.new(colors[1], colors[#colors])
			ray.Transparency = NumberSequence.new(0.92, 0.55)
			ray.Parent = sky
		end
		local motes = emitter(sky, ColorSequence.new(colors[1], colors[#colors]), 14, 0.28 * s, 5 * s, 3)
		motes.EmissionDirection = Enum.NormalId.Bottom
		motes.Shape = Enum.ParticleEmitterShape.Box
		motes.SpreadAngle = Vector2.new(8, 8)
		motes.Brightness = 3
	end

	-- The mutations' own extras (their flames, spirals and lightning are in themeEffects)
	local themeParts: { [string]: (FXThemes.Theme) -> () } = {}

	function themeParts.Treasure(_theme: FXThemes.Theme)
		twinkles(2.6, ColorSequence.new(rgb(255, 230, 90), rgb(255, 255, 220)), 7, 0.55)
	end

	function themeParts.Glitter(_theme: FXThemes.Theme)
		twinkles(2.2, ColorSequence.new(rgb(220, 250, 255), rgb(140, 225, 255)), 5, 0.4)
	end

	function themeParts.Hellfire(_theme: FXThemes.Theme)
		local fire = Instance.new("Fire")
		fire.Color = rgb(255, 40, 10)
		fire.SecondaryColor = rgb(60, 0, 0)
		fire.Size = 3.5 * s
		fire.Heat = 7
		fire.Parent = root
		local smoke = Instance.new("Smoke")
		smoke.Color = rgb(50, 0, 10)
		smoke.Opacity = 0.12
		smoke.RiseVelocity = 3
		smoke.Size = 2.5 * s
		smoke.Parent = root
		-- Embers drifting up
		local embers = emitter(root, ColorSequence.new(rgb(255, 210, 70), rgb(255, 30, 0)), 20, 0.2 * s, 3 * s, 2.4)
		embers.EmissionDirection = Enum.NormalId.Top
		embers.SpreadAngle = Vector2.new(35, 35)
		embers.Acceleration = Vector3.new(0, 3, 0)
		embers.Brightness = 4
		-- Dark red souls swirling in
		shell(3, true, ColorSequence.new(rgb(255, 60, 40), rgb(90, 0, 10)), 16, 0.4, 3)
	end

	function themeParts.Holy(_theme: FXThemes.Theme)
		godRays({ rgb(255, 245, 200), rgb(255, 215, 110) })
	end

	function themeParts.Eternal(_theme: FXThemes.Theme)
		-- Purple light rays, a purple vortex pulling in, purple stars all round
		burst(12, 6, { rgb(180, 80, 255), rgb(235, 200, 255), rgb(110, 20, 220) }, 0.55)
		shell(3.6, true, ColorSequence.new(rgb(230, 180, 255), rgb(120, 20, 230)), 28, 0.32, 6)
		twinkles(4.6, ColorSequence.new(rgb(255, 255, 255), rgb(190, 110, 255)), 16, 0.55)
	end

	function themeParts.Prism(_theme: FXThemes.Theme)
		burst(10, 4.6, { rgb(255, 70, 70), rgb(255, 170, 40), rgb(255, 240, 60), rgb(80, 240, 110), rgb(70, 170, 255), rgb(190, 90, 255) }, 0.6)
		shell(2.8, false, RAINBOW_SEQUENCE, 18, 0.22, 3)
	end

	-- Particles drifting round a donut (a signature aura's Drift): snow, petals and feathers falling,
	-- embers, bubbles and steam rising, confetti bursting out, speed lines streaking back.
	local function drift(theme: FXThemes.Theme)
		local d = theme.Drift
		if not d then
			return
		end
		local colors: { Color3 } = theme.DriftColors or theme.Colors
		local spread = ColorSequence.new(colors[1], colors[math.min(2, #colors)])
		local soft = d.Texture == "Smoke"
		local function make(parent: BasePart, color: ColorSequence, rate: number): ParticleEmitter
			local e = Instance.new("ParticleEmitter")
			e.Name = "Drift"
			e.Texture = texture(d.Texture)
			e.Color = color
			e.Rate = rate
			e.LightEmission = if soft then 0.25 else 0.7
			e.LightInfluence = if soft then 0.6 else 0
			e.Brightness = if soft then 1.2 else 2.5
			e.Rotation = NumberRange.new(0, 360)
			e.RotSpeed = NumberRange.new(-70, 70)
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, d.Size * s), NumberSequenceKeypoint.new(1, d.Size * 0.6 * s) })
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.12, 0.15), NumberSequenceKeypoint.new(0.8, 0.35), NumberSequenceKeypoint.new(1, 1) })
			e:SetAttribute("FXBoost", true)
			e.Parent = parent
			return e
		end
		if d.Mode == "Fall" then
			local sky = holder("DriftFX", Vector3.new(6, 0.2, 6) * s, at(0, TOP + 2.6, 0))
			local e = make(sky, spread, d.Rate)
			e.Shape = Enum.ParticleEmitterShape.Box
			e.EmissionDirection = Enum.NormalId.Bottom
			e.SpreadAngle = Vector2.new(20, 20)
			e.Speed = NumberRange.new(1.2 * s, 2.4 * s)
			e.Acceleration = Vector3.new(0, -0.6 * s, 0)
			e.Drag = 0.5
			e.Lifetime = NumberRange.new(2.6, 3.6)
		elseif d.Mode == "Rise" then
			local base = holder("DriftFX", Vector3.new(4, 0.6, 3) * s, at(0, -TOP * 0.7, 0))
			local e = make(base, spread, d.Rate)
			e.Shape = Enum.ParticleEmitterShape.Box
			e.EmissionDirection = Enum.NormalId.Top
			e.SpreadAngle = Vector2.new(25, 25)
			e.Speed = NumberRange.new(1.5 * s, 3.5 * s)
			e.Acceleration = Vector3.new(0, 1.5 * s, 0)
			e.Lifetime = NumberRange.new(1.6, 2.6)
			if d.Size > 1 then -- (steam puffs grow as they rise)
				e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, d.Size * 0.4 * s), NumberSequenceKeypoint.new(1, d.Size * s) })
			end
		elseif d.Mode == "Burst" then
			-- confetti in every colour, popping out and fluttering down
			local center = holder("DriftFX", Vector3.one * 1.5 * s, CFrame.identity)
			for _, color in colors do
				local e = make(center, ColorSequence.new(color), d.Rate / #colors)
				e.Shape = Enum.ParticleEmitterShape.Sphere
				e.SpreadAngle = Vector2.new(180, 180)
				e.Speed = NumberRange.new(4 * s, 7 * s)
				e.Acceleration = Vector3.new(0, -7 * s, 0)
				e.Drag = 2
				e.RotSpeed = NumberRange.new(-260, 260)
				e.Lifetime = NumberRange.new(1.2, 1.8)
			end
		else -- Streak: speed lines flying off behind it
			local front = holder("DriftFX", Vector3.new(4.5, 4, 0.2) * s, at(0, 0, 0.6))
			local e = make(front, spread, d.Rate)
			e.Shape = Enum.ParticleEmitterShape.Box
			e.EmissionDirection = Enum.NormalId.Back
			e.SpreadAngle = Vector2.new(3, 3)
			e.Speed = NumberRange.new(12 * s, 18 * s)
			e.Lifetime = NumberRange.new(0.25, 0.4)
			e.Orientation = Enum.ParticleOrientation.VelocityParallel
			e.Squash = NumberSequence.new(3)
			e.RotSpeed = NumberRange.new(0)
		end
	end

	-- A signature aura's other blocks (FXThemes): light rays, god rays, stars, a vortex or glitter,
	-- a haze of light rising round it, glowing crystals under it.
	local function auraEffects(theme: FXThemes.Theme)
		local colors = theme.Colors
		local rays = theme.Rays
		if rays then
			burst(rays.Count, rays.Length, colors, rays.Spin)
		end
		if theme.GodRays then
			godRays({ colors[2], colors[1] })
		end
		local stars = theme.Stars
		if stars then
			twinkles(stars.Radius, ColorSequence.new(colors[1]:Lerp(WHITE, 0.4), WHITE), stars.Rate, 0.45)
		end
		local vortex = theme.Vortex
		if vortex then
			shell(vortex.Radius, true, ColorSequence.new(colors[1], colors[3]), vortex.Rate, 0.3, 5):SetAttribute("FXBoost", true)
		end
		local glitter = theme.Glitter
		if glitter then
			shell(glitter.Radius, false, ColorSequence.new(colors[1]:Lerp(WHITE, 0.3), colors[2]), glitter.Rate, 0.25, 3):SetAttribute("FXBoost", true)
		end
		drift(theme)
		local mist = theme.Mist
		if mist then
			local aura = holder("GlowAura", Vector3.new(4, 0.5, 4) * s, at(0, -TOP * 0.7, 0))
			local haze = Instance.new("ParticleEmitter")
			haze.Name = "GlowMist"
			haze.Texture = texture("Smoke")
			haze.Color = ColorSequence.new(mist, mist:Lerp(WHITE, 0.5))
			haze.LightEmission = 1
			haze.LightInfluence = 0
			haze.Rate = 7
			haze.Lifetime = NumberRange.new(1.6, 2.6)
			haze.Speed = NumberRange.new(1.5 * s, 3 * s)
			haze.SpreadAngle = Vector2.new(25, 25)
			haze.EmissionDirection = Enum.NormalId.Top
			haze.Rotation = NumberRange.new(0, 360)
			haze.RotSpeed = NumberRange.new(-25, 25)
			haze.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2 * s), NumberSequenceKeypoint.new(1, 5 * s) })
			haze.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.55), NumberSequenceKeypoint.new(1, 1) })
			haze.Parent = aura
		end
		if theme.Crystals then
			-- glowing shards leaning out from under it, like a crystal bloom
			for i = 0, 4 do
				local angle = i / 5 * TAU + 0.3
				local height = 1.5 + (i % 3) * 0.4
				local radius = R + 0.6
				local crystal = ellipsoid(
					Vector3.new(0.55, height, 0.55),
					colors[(i % #colors) + 1]:Lerp(WHITE, 0.2),
					CFrame.new(math.cos(angle) * radius * s, bottom + height * 0.35 * s, math.sin(angle) * radius * s)
						* CFrame.Angles(0, -angle, 0)
						* CFrame.Angles(0, 0, math.rad(-28)),
					Enum.Material.Neon,
					"Crystal"
				)
				crystal.Transparency = 0.2
			end
		end
	end

	-- The big effects of the mid-to-late game themes (FXThemes): fire, spirals, smoke and the
	-- points the electric sparks burst from (the client sets those off, and adds the shards).
	-- FXBoost: these run near full strength (client/ParticleBudget), but only on the donuts closest
	-- to you - DonutFX switches them off on the rest.
	local function themeEffects(theme: FXThemes.Theme)
		local low = bottom * 0.55
		if theme.Flames then
			local base = holder("FlameFX", Vector3.new(4, 0.8, 2.6) * s, CFrame.new(0, low, 0))
			local fire = Instance.new("ParticleEmitter")
			fire.Name = "Flames"
			fire.Texture = texture("Fire")
			fire.Color = keys(theme.Flames)
			-- (half-solid, not pure glow, so they still read in bright daylight)
			fire.LightEmission = 0.55
			fire.LightInfluence = 0
			fire.Brightness = 2.6
			fire.Rate = 40
			fire.Lifetime = NumberRange.new(0.6, 1.1)
			fire.Speed = NumberRange.new(3 * s, 6.5 * s)
			fire.SpreadAngle = Vector2.new(14, 14)
			fire.EmissionDirection = Enum.NormalId.Top
			fire.Acceleration = Vector3.new(0, 5 * s, 0)
			fire.Rotation = NumberRange.new(-25, 25)
			fire.RotSpeed = NumberRange.new(-60, 60)
			fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2 * s), NumberSequenceKeypoint.new(0.35, 3.6 * s), NumberSequenceKeypoint.new(1, 0.5 * s) })
			fire.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.12, 0.1), NumberSequenceKeypoint.new(0.7, 0.45), NumberSequenceKeypoint.new(1, 1) })
			fire:SetAttribute("FXBoost", true)
			fire.Parent = base
			-- embers flying up out of it
			local embers = emitter(base, keys({ theme.Flames[1], theme.Flames[#theme.Flames] }), 16, 0.22 * s, 7 * s, 1.6)
			embers.Name = "Embers"
			embers.EmissionDirection = Enum.NormalId.Top
			embers.SpreadAngle = Vector2.new(30, 30)
			embers.Brightness = 4
			embers.Acceleration = Vector3.new(0, 3 * s, 0)
			embers:SetAttribute("FXBoost", true)
		end
		if theme.Swirl then
			local sphere = holder("SwirlFX", Vector3.one * 3.4 * s, CFrame.identity)
			local swirl = Instance.new("ParticleEmitter")
			swirl.Name = "Swirl"
			swirl.Texture = texture("Swirl")
			swirl.Color = if theme.Rainbow
				then ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(255, 80, 80)), ColorSequenceKeypoint.new(0.33, rgb(255, 230, 60)), ColorSequenceKeypoint.new(0.66, rgb(80, 255, 140)), ColorSequenceKeypoint.new(1, rgb(120, 140, 255)) })
				else keys(theme.Colors)
			swirl.LightEmission = 0.5
			swirl.LightInfluence = 0
			swirl.Brightness = 2.2
			swirl.Rate = 7
			swirl.Lifetime = NumberRange.new(1.4, 2.2)
			swirl.Speed = NumberRange.new(0)
			swirl.Shape = Enum.ParticleEmitterShape.Sphere
			swirl.LockedToPart = true
			swirl.Rotation = NumberRange.new(0, 360)
			swirl.RotSpeed = NumberRange.new(140, 220)
			swirl.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5 * s), NumberSequenceKeypoint.new(1, 7.5 * s) })
			swirl.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(1, 1) })
			swirl:SetAttribute("FXBoost", true)
			swirl.Parent = sphere
		end
		if theme.Smoke then
			local base = holder("SmokeFX", Vector3.new(4, 1, 3) * s, CFrame.new(0, low, 0))
			local smoke = Instance.new("ParticleEmitter")
			smoke.Name = "DarkSmoke"
			smoke.Texture = texture("Smoke")
			smoke.Color = ColorSequence.new(theme.Smoke, theme.Smoke:Lerp(BLACK, 0.5))
			smoke.LightEmission = 0
			smoke.LightInfluence = 0
			smoke.Rate = 9
			smoke.Lifetime = NumberRange.new(1.8, 2.8)
			smoke.Speed = NumberRange.new(1.5 * s, 3 * s)
			smoke.SpreadAngle = Vector2.new(25, 25)
			smoke.EmissionDirection = Enum.NormalId.Top
			smoke.Rotation = NumberRange.new(0, 360)
			smoke.RotSpeed = NumberRange.new(-30, 30)
			smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5 * s), NumberSequenceKeypoint.new(1, 6 * s) })
			smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.45), NumberSequenceKeypoint.new(1, 1) })
			smoke:SetAttribute("FXBoost", true)
			smoke.Parent = base
		end
		local electric = theme.Electric
		if electric then
			-- Six points round the donut. The client picks one and sets off a burst there: a star
			-- of long thin sparks (stretched along how they fly) that's gone in a blink.
			local points = holder("ElectricFX", Vector3.one * 0.2, CFrame.identity)
			for i = 1, 6 do
				local direction = Vector3.new(math.cos(i * 2.1), math.sin(i * 1.3) * 0.8, math.sin(i * 2.1)).Unit
				local point = Instance.new("Attachment")
				point.Name = "Spark"
				point.Position = direction * 1.7 * s
				point.Parent = points
				local spark = Instance.new("ParticleEmitter")
				spark.Name = "Crackle"
				spark.Texture = texture("Spark")
				spark.Color = keys(electric.Colors)
				spark.LightEmission = 0.7
				spark.LightInfluence = 0
				spark.Brightness = 7
				spark.Rate = 0 -- (bursts only: client/DonutFX calls Emit)
				spark.Lifetime = NumberRange.new(0.08, 0.2)
				spark.Speed = NumberRange.new(14 * s, 30 * s)
				spark.SpreadAngle = Vector2.new(180, 180)
				spark.Orientation = Enum.ParticleOrientation.VelocityParallel
				spark.Squash = NumberSequence.new(2.6)
				spark.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9 * s), NumberSequenceKeypoint.new(1, 0.15 * s) })
				spark.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.6) })
				spark.Drag = 6
				spark.Parent = point
			end
			points:SetAttribute("ElectricRate", electric.Rate)
		end
	end

	-- Effects: every Epic-and-up donut has its OWN signature aura (DonutAuras: picked from its name,
	-- in its own colours) - nothing is shared by a whole rarity any more - and a mutation adds its
	-- effects on top. (The moving parts - lightning, magic circles, comets, shapes circling it -
	-- are animated by each client: client/DonutFX.)
	if not opts.NoEffects then
		local themes = DonutAuras.Themes(donut, mutation.Id)
		local signature = if themes[1] and themes[1].Id == "Signature" then themes[1] else nil
		local glowColor = if mutation.Order > 0 then mutation.Color elseif signature then signature.Colors[1] else rarity.Color
		local lightRange = math.max(if signature then rarity.Light or 0 else 0, mutation.Light or 0)
		if lightRange > 0 then
			local light = Instance.new("PointLight")
			light.Color = glowColor
			light.Brightness = 1.5
			light.Range = lightRange * s
			light.Shadows = false
			light.Parent = root
		end
		if mutation.Particles then
			local e = emitter(root, ColorSequence.new(mutation.Color, WHITE), mutation.Particles, 0.3 * s, 2 * s, 1.5)
			if mutation.Rainbow then
				e.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, rgb(255, 60, 60)),
					ColorSequenceKeypoint.new(0.25, rgb(255, 220, 60)),
					ColorSequenceKeypoint.new(0.5, rgb(60, 220, 90)),
					ColorSequenceKeypoint.new(0.75, rgb(60, 150, 255)),
					ColorSequenceKeypoint.new(1, rgb(200, 80, 255)),
				})
			end
		end
		if mutation.Id == "Gold" or mutation.Id == "Diamond" then
			local sparkles = Instance.new("Sparkles")
			sparkles.SparkleColor = mutation.Color
			sparkles.Parent = root
		end
		if opts.Pillar and signature and (rarity.Beam or mutation.Order >= 3) then
			local pillar = Instance.new("Part")
			pillar.Name = "Pillar"
			pillar.Shape = Enum.PartType.Cylinder
			pillar.Size = Vector3.new(60, 3.5, 3.5)
			-- `bottom` is the lowest point of the donut, so the pillar starts at the ground.
			local pillarCf = CFrame.new(0, bottom + 30, 0) * CFrame.Angles(0, 0, math.pi / 2)
			add(pillar, pillarCf, glowColor, Enum.Material.Neon)
			pillar.Transparency = 0.8
		end
		-- a glowing outline in its aura's colour when you're close (client/DonutGlow)
		if signature or mutation.Order >= 1 then
			CollectionService:AddTag(model, "DonutOutline")
			model:SetAttribute("OutlineColor", glowColor)
		end
		if (rarity.Float and look.Effects) or mutation.Order >= 2 then
			CollectionService:AddTag(model, "DonutFloat")
		end
		if mutation.Rainbow then
			CollectionService:AddTag(model, "DonutRainbow")
		end

		if #themes > 0 then
			CollectionService:AddTag(model, "DonutFX")
			model:SetAttribute("FXScale", s)
			for _, theme in themes do
				if theme.Outline then
					model:SetAttribute("FXOutline", true) -- (DonutFX draws its outline, not DonutGlow)
				end
				local build = themeParts[theme.Id]
				if build then
					build(theme)
				end
				themeEffects(theme)
				auraEffects(theme)
			end
		end
	end

	-- On a base many rare donuts stand side by side, and their effects add up to a white glare:
	-- fewer, dimmer particles, softer beams and lights, so every donut stays easy to see.
	if opts.Calm then
		for _, effect in model:GetDescendants() do
			if effect:IsA("ParticleEmitter") then
				effect.Rate *= 0.55
				effect.Brightness = math.min(effect.Brightness, if effect.Name == "Crackle" then 3 else 1.4)
				effect.LightEmission *= 0.75
			elseif effect:IsA("Beam") then
				effect.Brightness = math.min(effect.Brightness, 0.8)
				effect.LightEmission *= 0.6
			elseif effect:IsA("PointLight") then
				effect.Brightness *= 0.45
				effect.Range *= 0.6
			end
		end
	end

	return model
end

-- Place a built donut so its lowest point rests on `surface` (a CFrame on top of a pedestal etc.).
function DonutModel.PlaceOn(model: Model, surface: CFrame)
	local bottom = (model:GetAttribute("Bottom") :: number?) or 0
	model:PivotTo(surface * CFrame.new(0, bottom, 0))
end

-- Floating label like: "GIANT GOLD" / "Epic" / "Silver Tob Tobi" / "$344/s" / "Lv. 3"
function DonutModel.CreateBillboard(donut: Donut, income: number, level: number?, top: number, mutationId: string?, sizeId: string?): BillboardGui
	local rarity = Rarities.Get(donut.Rarity)
	local mutation = Rarities.Mutation(mutationId)
	local size = Rarities.Size(sizeId)
	local hasTag = mutation.Order > 0 or size.Id ~= "Normal"

	local gui = Instance.new("BillboardGui")
	gui.Name = "DonutInfo"
	local rows = 2.8 + (if level then 0.8 else 0) + (if hasTag then 0.8 else 0)
	gui.Size = UDim2.new(9, 0, rows, 0)
	gui.StudsOffsetWorldSpace = Vector3.new(0, top + 1.2 + rows * 0.25, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = gui

	local unit = 1 / rows
	local function line(name: string, text: string, color: Color3, height: number, order: number): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, height * unit)
		label.Font = Enum.Font.FredokaOne
		label.Text = text
		label.TextColor3 = color
		label.TextScaled = true
		label.TextStrokeTransparency = 0
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.LayoutOrder = order
		label.Parent = gui
		return label
	end

	if hasTag then
		local parts = {}
		if size.Id ~= "Normal" then
			table.insert(parts, string.upper(size.Id))
		end
		if mutation.Order > 0 then
			table.insert(parts, string.upper(mutation.Id))
		end
		local tag = line("Mutation", table.concat(parts, " "), if mutation.Order > 0 then mutation.Color else Color3.fromRGB(255, 255, 255), 0.8, 0)
		if mutation.Rainbow then
			CollectionService:AddTag(tag, "RainbowText")
		end
	end
	local rarityLabel = line("Rarity", rarity.Id, rarity.Color, 0.9, 1)
	if rarity.Rainbow then
		CollectionService:AddTag(rarityLabel, "RainbowText")
	end
	line("DonutName", donut.Name, Color3.new(1, 1, 1), 0.95, 2)
	line("Income", Format.Money(income) .. "/s", Color3.fromRGB(90, 255, 90), 0.95, 3)
	if level then
		line("Level", "Lv. " .. level, Color3.fromRGB(255, 220, 90), 0.8, 4)
	end

	return gui
end

return DonutModel
