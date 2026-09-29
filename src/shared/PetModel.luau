--[[
	PetModel: builds pet eggs and pets out of plain parts (no uploaded meshes needed).

	Eggs get more mystical the better they are (Pets.Eggs[].Tier):
	  1  spots + sparkles
	  2  + a soft glow and a frosty shine
	  3  + glowing cracks and a ring of runes orbiting it
	  4  + twinkling stars, a second rune ring and a light pillar in the lane
	  5  + a halo and light rays fanning out behind it
	  6  (Void) + a black-hole vortex of rainbow particles pouring into it, and rainbow cracks
	The client (client/PetFX.luau) wobbles the eggs, spins the rune rings and cycles rainbow colours.

	Eggs are decorated by kind: sprinkles, an icing cap, a royal gold band and crown, or spots.

	Pets are little chibi creatures built from a body plan (Shape) plus Features (see Pets.luau), with
	big shiny eyes that blink and wings / tails / fins / tentacles that the client swings around
	their joints (see BuildPet and client/Followers.luau).
	Both are one rigid assembly welded to an anchored, invisible "Root" part, so moving Root moves
	everything (cheap to animate on the client). The front is -Z.
]]

local CollectionService = game:GetService("CollectionService")

local Pets = require(script.Parent.Pets)

local PetModel = {}

local rgb = Color3.fromRGB
local WHITE = rgb(255, 255, 255)
local BLACK = rgb(20, 20, 25)
local TAU = math.pi * 2
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- stands a cylinder up (they point along X)

export type Options = {
	Scale: number?,
	NoEffects: boolean?, -- no lights/particles (UI previews)
	Pillar: boolean?, -- light pillar for rare eggs in the lane
}

type Builder = {
	Model: Model,
	Root: BasePart,
	S: number,
	Part: (size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?) -> Part,
	Blob: (size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?) -> Part,
	Ball: (diameter: number, position: Vector3, color: Color3, material: Enum.Material?) -> Part,
	Rod: (from: Vector3, to: Vector3, diameter: number, color: Color3, material: Enum.Material?) -> Part,
}

local function newBuilder(name: string, scale: number): Builder
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one * scale
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Massless = true
	root.CFrame = CFrame.identity
	root.Parent = model
	model.PrimaryPart = root

	local function part(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Size = size * scale
		p.CFrame = CFrame.new(cf.Position * scale) * cf.Rotation
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			p.Shape = shape
		end
		p.Anchored = false
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.CastShadow = false
		local weld = Instance.new("Weld")
		weld.Part0 = root
		weld.Part1 = p
		weld.C0 = p.CFrame
		weld.Parent = p
		p.Parent = model
		return p
	end
	local function blob(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
		local p = part(size, cf, color, material)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		return p
	end
	local function ball(diameter: number, position: Vector3, color: Color3, material: Enum.Material?): Part
		return part(Vector3.one * diameter, CFrame.new(position), color, material, Enum.PartType.Ball)
	end
	-- A cylinder from one point to another (a leg, a tail segment, a horn...)
	local function rod(from: Vector3, to: Vector3, diameter: number, color: Color3, material: Enum.Material?): Part
		local along = to - from
		local dir = along.Unit
		local side = dir:Cross(if math.abs(dir.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis).Unit
		local cf = CFrame.fromMatrix((from + to) / 2, dir, side:Cross(dir))
		return part(Vector3.new(along.Magnitude + diameter * 0.3, diameter, diameter), cf, color, material, Enum.PartType.Cylinder)
	end
	return { Model = model, Root = root, S = scale, Part = part, Blob = blob, Ball = ball, Rod = rod }
end

local function emitter(parent: Instance, color: ColorSequence, rate: number, size: number, speed: number, lifetime: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Color = color
	e.LightEmission = 1
	e.Rate = rate
	e.Lifetime = NumberRange.new(lifetime * 0.6, lifetime)
	e.Speed = NumberRange.new(speed * 0.4, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new(size, 0)
	e.Transparency = NumberSequence.new(0.1, 1)
	e.Parent = parent
	return e
end

local function light(parent: Instance, color: Color3, range: number, brightness: number?)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness or 1.5
	l.Shadows = false
	l.Parent = parent
end

-- Measure a model so callers can stand it on a surface (Top / Bottom attributes, like donuts).
local function measure(model: Model, root: BasePart)
	local top, bottom = -math.huge, math.huge
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p ~= root and p.Transparency < 1 then
			local cf, size = p.CFrame, p.Size
			local half = math.abs(cf.RightVector.Y) * size.X / 2 + math.abs(cf.UpVector.Y) * size.Y / 2 + math.abs(cf.LookVector.Y) * size.Z / 2
			top = math.max(top, cf.Position.Y + half)
			bottom = math.min(bottom, cf.Position.Y - half)
		end
	end
	model:SetAttribute("Top", top)
	model:SetAttribute("Bottom", -bottom)
end

-- A ring of glowing runes around an invisible pivot welded to the root (the client spins the weld).
local function runeRing(b: Builder, name: string, radius: number, height: number, count: number, color: Color3, tilt: number, speed: number)
	local pivot = b.Part(Vector3.one * 0.1, CFrame.new(0, height, 0) * CFrame.Angles(tilt, 0, 0), color)
	pivot.Name = name
	pivot.Transparency = 1
	pivot:SetAttribute("Spin", speed)
	for i = 1, count do
		local angle = i / count * TAU
		local rune = Instance.new("Part")
		rune.Name = "Rune"
		rune.Size = Vector3.new(0.34, 0.34, 0.08) * b.S
		rune.Color = color
		rune.Material = Enum.Material.Neon
		rune.CanCollide = false
		rune.CanTouch = false
		rune.CanQuery = false
		rune.Massless = true
		rune.CastShadow = false
		local offset = CFrame.new(math.cos(angle) * radius * b.S, 0, math.sin(angle) * radius * b.S) * CFrame.Angles(0, -angle, math.rad(45))
		rune.CFrame = pivot.CFrame * offset
		local weld = Instance.new("Weld")
		weld.Part0 = pivot
		weld.Part1 = rune
		weld.C0 = offset
		weld.Parent = rune
		rune.Parent = b.Model
	end
end

local PINK = rgb(255, 135, 170)
local CREAM = rgb(250, 240, 220)
local ORANGE = rgb(255, 165, 40)
local GOLD = rgb(255, 205, 50)

-- The point on an ellipsoid (centre, half-sizes) in direction `dir` from its centre.
local function onSurface(center: Vector3, semi: Vector3, dir: Vector3): Vector3
	local d = dir.Unit
	local t = 1 / math.sqrt((d.X / semi.X) ^ 2 + (d.Y / semi.Y) ^ 2 + (d.Z / semi.Z) ^ 2)
	return center + d * t
end

-- The outward direction of that ellipsoid's surface at `point`.
local function normalAt(center: Vector3, semi: Vector3, point: Vector3): Vector3
	local p = point - center
	return Vector3.new(p.X / semi.X ^ 2, p.Y / semi.Y ^ 2, p.Z / semi.Z ^ 2).Unit
end

-- A frame at `position` whose front (-Z) points along `facing`, kept as upright as it can be.
local function facingFrame(position: Vector3, facing: Vector3): CFrame
	local back = -facing.Unit
	local right = Vector3.yAxis:Cross(back)
	right = if right.Magnitude < 1e-3 then Vector3.xAxis else right.Unit
	return CFrame.fromMatrix(position, right, back:Cross(right))
end

-- A ring (tube) lying flat, out of straight cylinder pieces: donut floaties, scarves, halos, bands.
local function flatRing(b: Builder, center: Vector3, radius: number, thickness: number, count: number, color: Color3, material: Enum.Material?)
	local step = TAU / count
	local length = 2 * radius * math.sin(step / 2) + thickness * math.tan(step / 2)
	for i = 0, count - 1 do
		local angle = i * step
		local position = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		b.Part(Vector3.new(length, thickness, thickness), CFrame.fromMatrix(position, tangent, Vector3.yAxis), color, material, Enum.PartType.Cylinder)
	end
end

--------------------------------------------------------------------------------
-- Eggs
--------------------------------------------------------------------------------
function PetModel.BuildEgg(egg: Pets.Egg, options: Options?): Model
	local opts: Options = options or {}
	local b = newBuilder(egg.Id .. "Egg", opts.Scale or 1)
	local tier = egg.Tier
	local material = if tier == 2 then Enum.Material.Glass elseif tier == 3 then Enum.Material.Basalt elseif tier >= 5 then Enum.Material.Pebble else Enum.Material.SmoothPlastic
	if tier == 5 then
		material = Enum.Material.SmoothPlastic
	end
	local shellSemi = Vector3.new(1.1, 1.45, 1.1)
	local shell = b.Blob(shellSemi * 2, CFrame.identity, egg.Color, material)
	shell.Name = "Shell"
	if tier == 2 or tier == 5 then
		shell.Reflectance = 0.25
	end
	-- A point on the shell in direction `dir` from the middle, and the way the shell faces there
	local function onShell(dir: Vector3): (Vector3, Vector3)
		local point = onSurface(Vector3.zero, shellSemi, dir)
		return point, normalAt(Vector3.zero, shellSemi, point)
	end
	local rng = Random.new(#egg.Id * 97)
	local spotMaterial = if tier >= 4 then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local spots = 7
	if egg.Id == "Sprinkle" then
		-- covered in sprinkles instead of spots
		spots = 0
		local colors = { rgb(255, 80, 80), rgb(80, 200, 255), rgb(255, 235, 70), rgb(120, 230, 90), WHITE }
		for i = 1, 26 do
			local point, normal = onShell(Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.9, 1.1), rng:NextNumber(-1, 1)))
			local along = normal:Cross(Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)).Unit).Unit * 0.17
			point += normal * 0.02
			b.Rod(point - along, point + along, 0.12, colors[i % #colors + 1])
		end
	elseif egg.Id == "Frosted" then
		-- an icing cap dripping down the sides
		spots = 4
		-- (a slightly narrower ellipsoid poking out of the top half: a thin, even layer of icing)
		b.Blob(Vector3.new(1.92, 1.3, 1.92), CFrame.new(0, 0.83, 0), WHITE).Reflectance = 0.2
		for i = 0, 6 do
			local angle = i / 7 * TAU + rng:NextNumber(-0.2, 0.2)
			local point, normal = onShell(Vector3.new(math.cos(angle), 0.3 + rng:NextNumber(-0.1, 0.04), math.sin(angle)))
			b.Blob(Vector3.new(0.34, 0.75, 0.16), facingFrame(point, normal), WHITE)
		end
	elseif egg.Id == "Royal" then
		-- a golden band with gems, and a little crown on top
		flatRing(b, Vector3.new(0, -0.05, 0), 1.1, 0.26, 16, GOLD, Enum.Material.Foil)
		for i = 0, 3 do
			local angle = i / 4 * TAU + math.pi / 4
			local point, normal = onShell(Vector3.new(math.cos(angle), 0, math.sin(angle)))
			b.Ball(0.3, point + normal * 0.1, egg.Accent, Enum.Material.Neon)
		end
		local top = onShell(Vector3.yAxis)
		b.Rod(top - Vector3.new(0, 0.15, 0), top + Vector3.new(0, 0.15, 0), 0.8, GOLD, Enum.Material.Foil)
		for i = 0, 4 do
			local angle = i / 5 * TAU
			b.Ball(0.16, top + Vector3.new(math.cos(angle) * 0.34, 0.25, math.sin(angle) * 0.34), GOLD, Enum.Material.Foil)
		end
	end
	-- Spots on the shell
	for i = 1, spots do
		local yaw = i / spots * TAU + rng:NextNumber(-0.3, 0.3)
		local y = if egg.Id == "Frosted" then rng:NextNumber(-0.9, -0.2) else rng:NextNumber(-0.7, 0.8)
		local point, normal = onShell(Vector3.new(math.cos(yaw), y, math.sin(yaw)))
		local spot = b.Blob(Vector3.new(0.55, 0.55, 0.12), facingFrame(point - normal * 0.02, normal), egg.Accent, spotMaterial)
		spot.Name = "Spot"
	end
	-- Glowing zig-zag crack around the middle
	if tier >= 3 then
		for i = 0, 11 do
			local angle = i / 12 * TAU
			local y = if i % 2 == 0 then 0.12 else -0.12
			local point = onShell(Vector3.new(math.cos(angle), y, math.sin(angle)))
			local crack = b.Part(Vector3.new(0.62, 0.1, 0.08), CFrame.new(point) * CFrame.Angles(0, -angle + math.pi / 2, if i % 2 == 0 then 0.35 else -0.35), egg.Accent, Enum.Material.Neon)
			crack.Name = "Crack"
		end
	end
	-- A glossy highlight
	local shine, shineNormal = onShell(Vector3.new(-0.45, 0.55, -0.75))
	local gloss = b.Blob(Vector3.new(0.36, 0.7, 0.08), facingFrame(shine, shineNormal) * CFrame.Angles(0, 0, -0.4), WHITE, Enum.Material.Neon)
	gloss.Name = "Gloss"
	gloss.Transparency = 0.55

	if not opts.NoEffects then
		local root = b.Root
		local accent = ColorSequence.new(egg.Accent, WHITE)
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = egg.Accent
		sparkles.Parent = root
		if tier >= 2 then
			light(root, egg.Accent, 8 + tier * 2)
			emitter(root, accent, 4 + tier * 3, 0.3 * b.S, 1.5 * b.S, 1.6)
		end
		if tier >= 3 then
			runeRing(b, "RuneRing", 2.1, -0.2, 8, egg.Accent, math.rad(12), 1.2)
		end
		if tier >= 4 then
			runeRing(b, "RuneRing2", 2.6, 0.5, 10, WHITE:Lerp(egg.Accent, 0.4), math.rad(-20), -0.8)
			local stars = emitter(root, ColorSequence.new(WHITE, egg.Accent), 10, 0.35 * b.S, 0.01, 1.2)
			stars.Shape = Enum.ParticleEmitterShape.Sphere
			stars.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			stars.Speed = NumberRange.new(0)
			stars.Brightness = 3
			stars.LockedToPart = true
			if opts.Pillar then
				local pillar = b.Part(Vector3.new(50, 3, 3), CFrame.new(0, 24, 0) * UPRIGHT, egg.Accent, Enum.Material.Neon, Enum.PartType.Cylinder)
				pillar.Name = "Pillar"
				pillar.Transparency = 0.8
			end
		end
		if tier >= 5 then
			local halo = b.Part(Vector3.new(0.2, 2.2, 2.2), CFrame.new(0, 2.1, 0) * UPRIGHT, rgb(255, 240, 160), Enum.Material.Neon, Enum.PartType.Cylinder)
			halo.Name = "Halo"
			halo.Transparency = 0.2
			local hole = b.Part(Vector3.new(0.25, 1.6, 1.6), CFrame.new(0, 2.1, 0) * UPRIGHT, egg.Color, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			hole.Name = "HaloInner"
			-- Light rays fanning out behind the egg (spun by the client)
			local rays = b.Part(Vector3.one * 0.2, CFrame.new(0, 0, 0.9), WHITE)
			rays.Name = "Rays"
			rays.Transparency = 1
			rays:SetAttribute("Spin", 0.4)
			local center = Instance.new("Attachment")
			center.Parent = rays
			for i = 1, 8 do
				local angle = i / 8 * TAU
				local reach = (if i % 2 == 0 then 4 else 2.6) * b.S
				local tip = Instance.new("Attachment")
				tip.Position = Vector3.new(math.cos(angle) * reach, math.sin(angle) * reach, 0)
				tip.Parent = rays
				local beam = Instance.new("Beam")
				beam.Attachment0 = center
				beam.Attachment1 = tip
				beam.FaceCamera = true
				beam.Segments = 1
				beam.Width0 = 0.7 * b.S
				beam.Width1 = 0.05 * b.S
				beam.LightEmission = 1
				beam.Brightness = 2
				beam.Color = ColorSequence.new(if i % 2 == 0 then egg.Accent else WHITE)
				beam.Transparency = NumberSequence.new(0.25, 1)
				beam.Parent = rays
			end
		end
		if tier >= 6 then
			-- A black hole: rainbow particles pouring in from all around
			local vortex = b.Part(Vector3.one * 6, CFrame.identity, WHITE)
			vortex.Name = "Vortex"
			vortex.Transparency = 1
			local e = emitter(vortex, ColorSequence.new({
				ColorSequenceKeypoint.new(0, rgb(255, 60, 60)),
				ColorSequenceKeypoint.new(0.25, rgb(255, 220, 60)),
				ColorSequenceKeypoint.new(0.5, rgb(60, 230, 120)),
				ColorSequenceKeypoint.new(0.75, rgb(60, 160, 255)),
				ColorSequenceKeypoint.new(1, rgb(200, 80, 255)),
			}), 40, 0.3 * b.S, 5 * b.S, 0.6)
			e.Shape = Enum.ParticleEmitterShape.Sphere
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
			e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
			e.SpreadAngle = Vector2.new(3, 3)
			e.LockedToPart = true
			e.Brightness = 3
		end
	end

	measure(b.Model, b.Root)
	b.Model:SetAttribute("EggId", egg.Id)
	b.Model:SetAttribute("Tier", tier)
	if egg.Rainbow then
		b.Model:SetAttribute("Rainbow", true)
	end
	CollectionService:AddTag(b.Model, "PetEgg")
	return b.Model
end

--------------------------------------------------------------------------------
-- Pets
--------------------------------------------------------------------------------
--[[
	Pets are chibi critters: a big round head with shiny eyes that blink ("EyeWhite" / "Pupil", like
	the donuts), a body plan (Shape) and Features. Wings, tails, fins and tentacles hang from real
	joints ("Limb" = Wing / Tail / Fluke / Fin / Tentacle, swinging around "Pivot"), so the client can
	flap and wag them (client/Followers.luau). Body-coloured parts are all named "Body" so rainbow pets
	change colour all over.
]]
function PetModel.BuildPet(pet: Pets.Pet, options: Options?): Model
	local opts: Options = options or {}
	local b = newBuilder(pet.Id, (opts.Scale or 1) * (pet.Scale or 1))
	local body, accent = pet.Body, pet.Accent
	local has = function(feature: string): boolean
		return Pets.HasFeature(pet, feature)
	end
	local glowMaterial = if has("Glow") then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local pale = body:Lerp(WHITE, 0.5) -- snouts, paws
	local shape = pet.Shape

	local function limb(part: BasePart, kind: string, side: number, pivot: Vector3)
		part:SetAttribute("Limb", kind)
		part:SetAttribute("Side", side)
		part:SetAttribute("Pivot", pivot * b.S)
	end
	local function skin(part: Part): Part
		part.Name = "Body"
		return part
	end

	-- Every body plan fills these in
	local bodyPart: Part
	local bodyCenter, bodySemi = Vector3.zero, Vector3.one
	local headCenter, headSemi = Vector3.zero, Vector3.one -- the face goes on this (the head, or the body)
	local eyeSpread, eyeLift, eyeSize = 0.42, 0.12, 1
	local snout = false
	local wingRoot = Vector3.new(0.6, 0.45, 0.3)
	local tailRoot: Vector3? = nil
	local spade = false -- devil / dragon tail instead of a curly one
	local stalkEyes: { Vector3 }? = nil

	if shape == "Quad" or shape == "Dragon" then
		local dragon = shape == "Dragon"
		bodyCenter = if dragon then Vector3.new(0, -0.05, 0.45) else Vector3.new(0, -0.1, 0.35)
		bodySemi = if dragon then Vector3.new(0.88, 0.74, 1.3) else Vector3.new(0.8, 0.66, 1.02)
		bodyPart = skin(b.Blob(bodySemi * 2, CFrame.new(bodyCenter), body))
		-- Stubby legs with round paws
		local legZ: { number } = if dragon then { -0.3, 1.2 } else { -0.2, 0.9 }
		for _, x in { -0.47, 0.47 } do
			for _, z in legZ do
				skin(b.Rod(Vector3.new(x, bodyCenter.Y - 0.25, z), Vector3.new(x, -0.98, z), 0.44, body))
				b.Blob(Vector3.new(0.52, 0.28, 0.62), CFrame.new(x, -1.04, z - 0.08), pale)
			end
		end
		if dragon then
			headCenter, headSemi = Vector3.new(0, 1.15, -1.2), Vector3.one * 0.74
			skin(b.Rod(Vector3.new(0, 0.25, -0.35), Vector3.new(0, 0.95, -1.05), 0.78, body)) -- neck
			tailRoot = Vector3.new(0, 0.05, bodyCenter.Z + bodySemi.Z * 0.85)
			spade = true
			wingRoot = Vector3.new(0.55, 0.5, 0.25)
		else
			headCenter, headSemi = Vector3.new(0, 0.72, -0.72), Vector3.one * 0.86
			tailRoot = Vector3.new(0, 0.05, bodyCenter.Z + bodySemi.Z * 0.9)
		end
		skin(b.Ball(headSemi.X * 2, headCenter, body))
		snout = true
		eyeSize = headSemi.X / 0.8
	elseif shape == "Bird" then
		bodyCenter, bodySemi = Vector3.new(0, -0.05, 0.05), Vector3.new(0.92, 0.98, 0.9)
		bodyPart = skin(b.Blob(bodySemi * 2, CFrame.new(bodyCenter), body))
		headCenter, headSemi = Vector3.new(0, 1.12, -0.2), Vector3.one * 0.72
		skin(b.Ball(1.44, headCenter, body))
		for _, side in { -1, 1 } do
			b.Rod(Vector3.new(side * 0.36, -0.8, -0.05), Vector3.new(side * 0.36, -1.0, -0.15), 0.13, ORANGE)
			b.Blob(Vector3.new(0.42, 0.16, 0.62), CFrame.new(side * 0.36, -1.02, -0.3), ORANGE)
			if not has("Wings") then
				-- little wings folded at its sides
				local root = Vector3.new(side * 0.82, 0.25, 0.05)
				local wing = b.Blob(Vector3.new(0.22, 0.8, 0.95), CFrame.new(root + Vector3.new(side * 0.1, -0.3, 0.08)) * CFrame.Angles(0.25, 0, side * 0.18), accent, glowMaterial)
				wing.Name = "Wing"
				limb(wing, "Wing", side, root)
			end
		end
		-- a fan of tail feathers
		for i = -1, 1 do
			local feather = b.Blob(Vector3.new(0.3, 0.14, 0.85), CFrame.new(i * 0.22, -0.25, 0.95) * CFrame.Angles(0, i * 0.35, 0) * CFrame.Angles(-0.5, 0, 0), accent, glowMaterial)
			limb(feather, "Tail", 0, Vector3.new(0, -0.3, 0.7))
		end
		wingRoot = Vector3.new(0.8, 0.3, 0.05)
		eyeSize = 0.95
	elseif shape == "Blob" then
		bodyCenter, bodySemi = Vector3.zero, Vector3.new(1.1, 0.98, 1.05)
		bodyPart = skin(b.Blob(bodySemi * 2, CFrame.new(bodyCenter), body))
		headCenter, headSemi = bodyCenter, bodySemi
		eyeSpread, eyeLift, eyeSize = 0.36, 0.22, 1.2
		wingRoot = Vector3.new(0.9, 0.35, 0.35)
		tailRoot = Vector3.new(0, -0.35, 0.9)
		spade = true
		if has("Ghost") then
			-- a wavy hem instead of a round bottom
			for i = 0, 6 do
				local angle = i / 7 * TAU
				skin(b.Ball(0.62, Vector3.new(math.cos(angle) * 0.74, -0.78, math.sin(angle) * 0.7), body))
			end
		end
	elseif shape == "Whale" then
		bodyCenter, bodySemi = Vector3.zero, Vector3.new(1.1, 0.9, 1.7)
		bodyPart = skin(b.Blob(bodySemi * 2, CFrame.new(bodyCenter), body))
		b.Blob(Vector3.new(1.85, 1.0, 3.0), CFrame.new(0, -0.38, -0.1), accent) -- belly
		headCenter, headSemi = bodyCenter, bodySemi
		eyeSpread, eyeLift, eyeSize = 0.55, 0.08, 1.1
		-- tail and flukes (flap up and down)
		local tailBase = Vector3.new(0, 0.15, 1.35)
		local stock = skin(b.Blob(Vector3.new(0.95, 0.75, 1.5), CFrame.new(0, 0.3, 1.9) * CFrame.Angles(-0.35, 0, 0), body))
		limb(stock, "Fluke", 0, tailBase)
		for _, side in { -1, 1 } do
			local fluke = skin(b.Blob(Vector3.new(1.1, 0.16, 0.62), CFrame.new(side * 0.5, 0.58, 2.5) * CFrame.Angles(0, side * 0.45, 0), body))
			limb(fluke, "Fluke", 0, tailBase)
			local fin = skin(b.Blob(Vector3.new(1.0, 0.18, 0.55), CFrame.new(side * 1.2, -0.3, -0.25) * CFrame.Angles(0, 0, side * 0.5), body))
			limb(fin, "Fin", side, Vector3.new(side * 0.85, -0.2, -0.25))
		end
		wingRoot = Vector3.new(0.9, 0.5, 0.2)
	else -- Crab
		bodyCenter, bodySemi = Vector3.zero, Vector3.new(1.2, 0.62, 0.95)
		bodyPart = skin(b.Blob(bodySemi * 2, CFrame.new(bodyCenter), body))
		headCenter, headSemi = bodyCenter, bodySemi
		local stalks: { Vector3 } = {}
		stalkEyes = stalks
		for _, side in { -1, 1 } do
			-- walking legs
			for i = 0, 2 do
				local z = -0.2 + i * 0.4
				local hip = Vector3.new(side * 0.95, -0.1, z)
				local knee = Vector3.new(side * 1.55, 0.2, z + 0.12 * (i - 1))
				local foot = Vector3.new(side * 1.85, -0.62, z + 0.22 * (i - 1))
				skin(b.Rod(hip, knee, 0.18, body))
				skin(b.Rod(knee, foot, 0.14, body))
			end
			-- big claws
			local shoulder = Vector3.new(side * 0.85, 0.05, -0.55)
			local elbow = Vector3.new(side * 1.35, 0.3, -1.0)
			skin(b.Rod(shoulder, elbow, 0.26, body))
			skin(b.Blob(Vector3.new(0.7, 0.5, 0.78), CFrame.new(side * 1.48, 0.38, -1.3), body))
			b.Blob(Vector3.new(0.26, 0.2, 0.58), CFrame.new(side * 1.34, 0.66, -1.5) * CFrame.Angles(0.45, 0, 0), accent)
			b.Blob(Vector3.new(0.26, 0.18, 0.5), CFrame.new(side * 1.6, 0.2, -1.62), accent)
			-- eye stalks
			local top = Vector3.new(side * 0.4, 1.02, -0.6)
			skin(b.Rod(Vector3.new(side * 0.32, 0.35, -0.55), top, 0.14, body))
			table.insert(stalks, top + Vector3.new(0, 0.12, -0.06))
		end
		eyeSize = 1.05
	end
	bodyPart.Name = "Body"

	-- Face -----------------------------------------------------------------
	local function eye(position: Vector3, facing: Vector3, size: number)
		local frame = facingFrame(position, facing)
		local white = b.Blob(Vector3.new(0.36, 0.46, 0.24) * size, frame, WHITE)
		white.Name = "Eye"
		white:SetAttribute("EyeWhite", true)
		local pupil = b.Blob(Vector3.new(0.26, 0.34, 0.14) * size, frame * CFrame.new(0, -0.02 * size, -0.07 * size), BLACK)
		pupil.Name = "Pupil"
		local glint = b.Ball(0.1 * size, (frame * CFrame.new(-0.05 * size, 0.07 * size, -0.15 * size)).Position, WHITE, Enum.Material.Neon)
		glint.Name = "Glint"
		local glint2 = b.Ball(0.05 * size, (frame * CFrame.new(0.05 * size, -0.08 * size, -0.14 * size)).Position, WHITE, Enum.Material.Neon)
		glint2.Name = "Glint"
		for _, p in { pupil, glint, glint2 } do
			p:SetAttribute("Pupil", true)
		end
	end
	-- A point on the face and the way it faces (x: sideways, y: up, from the middle of the face)
	local function facePoint(x: number, y: number): (Vector3, Vector3)
		local point = onSurface(headCenter, headSemi, Vector3.new(x, y, -1))
		return point, normalAt(headCenter, headSemi, point)
	end
	local function smile(frame: CFrame, size: number)
		for _, side in { -1, 1 } do
			b.Blob(Vector3.new(0.17, 0.06, 0.06) * size, frame * CFrame.new(side * 0.065 * size, 0, 0) * CFrame.Angles(0, 0, side * 0.5), rgb(70, 30, 35))
		end
	end

	if stalkEyes then
		for _, position in stalkEyes do
			eye(position, Vector3.new(0, 0, -1), 1.05)
		end
		local point, normal = facePoint(0, 0.05)
		smile(facingFrame(point + normal * 0.01, normal), 1.3)
	else
		for _, side in { -1, 1 } do
			local point, normal = facePoint(side * eyeSpread, eyeLift)
			eye(point - normal * 0.04 * eyeSize, (normal + Vector3.new(0, 0, -1.5)).Unit, eyeSize)
			local cheekPoint, cheekNormal = facePoint(side * (eyeSpread + 0.14), eyeLift - 0.32)
			b.Blob(Vector3.new(0.28, 0.16, 0.08) * eyeSize, facingFrame(cheekPoint, cheekNormal), PINK).Transparency = 0.3
		end
	end

	if snout then
		local dragon = shape == "Dragon"
		local point, normal = facePoint(0, -0.34)
		local size = if dragon then Vector3.new(0.92, 0.6, 0.9) else Vector3.new(0.76, 0.5, 0.5) * (headSemi.X / 0.86)
		local frame = facingFrame(point + normal * (if dragon then 0.12 else 0.02), Vector3.new(0, -0.1, -1))
		b.Blob(size, frame, if dragon then body:Lerp(accent, 0.3) else pale)
		if dragon then
			for _, side in { -1, 1 } do
				b.Ball(0.1, (frame * CFrame.new(side * 0.16, size.Y * 0.2, -size.Z * 0.46)).Position, BLACK)
			end
		else
			b.Blob(Vector3.new(0.26, 0.17, 0.14), frame * CFrame.new(0, size.Y * 0.16, -size.Z * 0.45), BLACK) -- nose
		end
		smile(frame * CFrame.new(0, -size.Y * 0.2, -size.Z * 0.43), if dragon then 1.3 else 1)
	elseif has("Beak") then
		local point, normal = facePoint(0, -0.12)
		local frame = facingFrame(point + normal * 0.08, Vector3.new(0, -0.15, -1))
		b.Blob(Vector3.new(0.46, 0.24, 0.52), frame, ORANGE)
		b.Blob(Vector3.new(0.36, 0.14, 0.38), frame * CFrame.new(0, -0.12, 0.02), rgb(230, 130, 30))
	elseif not stalkEyes then
		local point, normal = facePoint(0, eyeLift - 0.36)
		smile(facingFrame(point + normal * 0.01, normal), eyeSize * 1.2)
	end

	-- Features ------------------------------------------------------------------
	local headTop = onSurface(headCenter, headSemi, Vector3.yAxis)
	local function onHead(x: number, y: number, z: number): Vector3
		return onSurface(headCenter, headSemi, Vector3.new(x, y, z))
	end

	for _, side in { -1, 1 } do
		if has("PointyEars") then
			-- a square turned on its corner, half buried in the head, reads as a triangle
			local frame = CFrame.new(onHead(side * 0.6, 0.8, 0.05)) * CFrame.Angles(0, 0, side * -0.4)
			skin(b.Part(Vector3.new(0.62, 0.62, 0.18), frame * CFrame.Angles(0, 0, math.rad(45)), body))
			b.Part(Vector3.new(0.34, 0.34, 0.06), frame * CFrame.new(0, 0.06, -0.08) * CFrame.Angles(0, 0, math.rad(45)), accent)
		end
		if has("FloppyEars") then
			local point = onHead(side * 0.8, 0.45, 0.05)
			b.Blob(Vector3.new(0.32, 0.95, 0.58), CFrame.new(point + Vector3.new(side * 0.1, -0.35, 0)) * CFrame.Angles(0, 0, side * 0.28), accent)
		end
		if has("LongEars") then
			local point = onHead(side * 0.35, 1, 0.05)
			local frame = CFrame.new(point + Vector3.new(side * 0.08, 0.55, 0)) * CFrame.Angles(0, 0, side * -0.12)
			skin(b.Blob(Vector3.new(0.36, 1.3, 0.26), frame, body))
			b.Blob(Vector3.new(0.18, 0.95, 0.08), frame * CFrame.new(0, 0, -0.1), PINK)
		end
		if has("RoundEars") then
			local point = onHead(side * 0.62, 0.8, 0.05)
			skin(b.Ball(0.56, point, body))
			b.Ball(0.3, point + Vector3.new(0, 0, -0.16), accent)
		end
		if has("Horns") then
			-- swept back a little
			local base = onHead(side * 0.45, 0.9, 0.15)
			local mid = base + Vector3.new(side * 0.14, 0.32, 0.14)
			local tip = mid + Vector3.new(side * 0.14, 0.2, 0.3)
			b.Rod(base, mid, 0.24, CREAM)
			b.Rod(mid, tip, 0.15, CREAM)
			b.Ball(0.14, tip, CREAM)
		end
		if has("Tufts") then
			local point = onHead(side * 0.55, 0.85, 0)
			b.Blob(Vector3.new(0.2, 0.55, 0.2), CFrame.new(point + Vector3.new(side * 0.1, 0.2, 0)) * CFrame.Angles(0, 0, side * -0.5), accent)
		end
		if has("Wings") then
			-- two layers of feathers (or leather), spreading up and out from the shoulders
			local root = Vector3.new(side * wingRoot.X, wingRoot.Y, wingRoot.Z)
			local k = if shape == "Dragon" then 1.3 else 1
			local frame = CFrame.new(root) * CFrame.Angles(0, side * -0.35, side * -0.6)
			local main = b.Blob(Vector3.new(0.22, 1.35 * k, 1.1 * k), frame * CFrame.new(0, 0.62 * k, 0.15 * k), accent, glowMaterial)
			local inner = b.Blob(Vector3.new(0.2, 0.95 * k, 0.8 * k), frame * CFrame.new(side * 0.05, 0.42 * k, 0.38 * k), accent:Lerp(WHITE, 0.35), glowMaterial)
			for _, wing in { main, inner } do
				wing.Name = "Wing"
				limb(wing, "Wing", side, root)
			end
		end
		if has("Antenna") then
			local base = onHead(side * 0.3, 1, 0)
			local tip = base + Vector3.new(side * 0.25, 0.6, 0.05)
			b.Rod(base, tip, 0.07, rgb(70, 70, 80))
			b.Ball(0.2, tip, accent, Enum.Material.Neon)
		end
	end
	if has("Belly") then
		local point = onSurface(bodyCenter, bodySemi, Vector3.new(0, -0.15, -1))
		b.Blob(Vector3.new(1.2, 1.4, 0.3), facingFrame(point + Vector3.new(0, 0, 0.12), Vector3.new(0, 0, -1)), accent)
	end
	if has("Horn") then
		-- a twisty unicorn horn
		local base = onHead(0, 0.8, -0.6)
		local up = Vector3.new(0, 0.85, -0.5).Unit
		local a, c = base + up * 0.32, base + up * 0.62
		b.Rod(base, a, 0.28, rgb(255, 230, 120), Enum.Material.Neon)
		b.Rod(a, c, 0.2, rgb(255, 240, 170), Enum.Material.Neon)
		b.Rod(c, c + up * 0.28, 0.11, rgb(255, 250, 210), Enum.Material.Neon)
	end
	if has("Crest") then
		for i = 0, 2 do
			b.Blob(Vector3.new(0.14, 0.62, 0.3), CFrame.new(headTop + Vector3.new(0, 0.22 - i * 0.05, 0.05 + i * 0.2)) * CFrame.Angles(-0.25 - i * 0.3, 0, 0), accent, glowMaterial)
		end
	end
	if has("Mane") then
		for i = 0, 4 do
			local a = i / 4
			local point = headTop:Lerp(bodyCenter + Vector3.new(0, bodySemi.Y, -0.2), a) + Vector3.new(0, 0.05, 0.25)
			b.Blob(Vector3.new(0.3, 0.55, 0.42), CFrame.new(point) * CFrame.Angles(0.5, 0, 0), Color3.fromHSV(i / 5, 0.6, 1), Enum.Material.Neon)
		end
	end
	if tailRoot and (has("Tail") or has("PuffTail") or has("BigTail")) then
		local root = tailRoot
		local parts: { BasePart } = {}
		if has("BigTail") then
			local tail = skin(b.Blob(Vector3.new(0.8, 0.8, 1.6), CFrame.new(root + Vector3.new(0, 0.45, 0.6)) * CFrame.Angles(-0.7, 0, 0), body))
			local tip = b.Blob(Vector3.one * 0.66, CFrame.new(root + Vector3.new(0, 0.45, 0.6) + Vector3.new(0, 0.64, 0.76) * 0.72), accent)
			parts = { tail, tip }
		elseif has("PuffTail") then
			parts = { b.Ball(0.62, root + Vector3.new(0, 0.1, 0.1), accent) }
		elseif spade then
			local a = root + Vector3.new(0, 0.1, 0.65)
			local c = a + Vector3.new(0, 0.38, 0.5)
			local tip = b.Part(Vector3.new(0.1, 0.46, 0.46), CFrame.new(c + Vector3.new(0, 0.12, 0.18)) * CFrame.Angles(math.rad(45), 0, 0), accent, glowMaterial)
			parts = { skin(b.Rod(root, a, 0.34, body)), skin(b.Rod(a, c, 0.24, body)), tip }
		else
			local a = root + Vector3.new(0, 0.3, 0.5)
			local c = a + Vector3.new(0, 0.5, 0.12)
			parts = { skin(b.Rod(root, a, 0.28, body)), skin(b.Rod(a, c, 0.22, body)), b.Ball(0.34, c, accent, glowMaterial) }
		end
		for _, part in parts do
			limb(part, "Tail", 0, root)
		end
	end
	if has("Spikes") then
		for i = 0, 3 do
			local point = onSurface(bodyCenter, bodySemi, Vector3.new(0, 1, -0.6 + i * 0.45))
			b.Part(Vector3.new(0.1, 0.34, 0.34), CFrame.new(point) * CFrame.Angles(math.rad(45), 0, 0), accent, glowMaterial)
		end
	end
	if shape == "Dragon" then
		-- a spiky ridge from the top of its head down its back
		for i = 0, 1 do
			local point = onHead(0, 0.75, 0.35 + i * 0.5)
			b.Part(Vector3.new(0.1, 0.26, 0.26), CFrame.new(point) * CFrame.Angles(math.rad(45), 0, 0), accent, glowMaterial)
		end
		for i = 0, 2 do
			local point = onSurface(bodyCenter, bodySemi, Vector3.new(0, 1, -0.3 + i * 0.55))
			b.Part(Vector3.new(0.1, 0.34, 0.34), CFrame.new(point) * CFrame.Angles(math.rad(45), 0, 0), accent, glowMaterial)
		end
	end
	if has("Tentacles") then
		for i = 0, 5 do
			local angle = i / 6 * TAU + 0.26
			local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local root = bodyCenter + out * 0.65 + Vector3.new(0, -0.7, 0)
			local knee = root + out * 0.15 + Vector3.new(0, -0.5, 0)
			local tip = knee + out * 0.3 + Vector3.new(0, -0.22, 0)
			for _, part in { b.Rod(root, knee, 0.32, accent, glowMaterial), b.Rod(knee, tip, 0.22, accent, glowMaterial), b.Ball(0.24, tip, accent, glowMaterial) } do
				part.Name = "Tentacle"
				limb(part, "Tentacle", if i % 2 == 0 then 1 else -1, root)
			end
		end
	end
	if has("Sprinkles") then
		local colors = { rgb(255, 70, 70), rgb(80, 200, 255), rgb(255, 235, 70), rgb(120, 230, 90) }
		local rng = Random.new(#pet.Id)
		for i = 1, 9 do
			local point = onSurface(bodyCenter, bodySemi, Vector3.new(rng:NextNumber(-0.55, 0.55), 1, rng:NextNumber(-0.7, 0.8)))
			local normal = normalAt(bodyCenter, bodySemi, point)
			local along = normal:Cross(Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit).Unit * 0.14
			b.Rod(point - along, point + along, 0.09, colors[i % 4 + 1], Enum.Material.Neon)
		end
	end
	if has("DonutRing") then
		-- a donut floatie round its middle
		flatRing(b, bodyCenter + Vector3.new(0, -0.35, 0), 1.0, 0.44, 12, rgb(222, 165, 95))
		flatRing(b, bodyCenter + Vector3.new(0, -0.24, 0), 1.0, 0.36, 12, rgb(255, 130, 190))
	end
	if has("Scarf") then
		flatRing(b, Vector3.new(0, 0.55, -0.12), 0.64, 0.26, 12, rgb(230, 50, 60), Enum.Material.Fabric)
		b.Blob(Vector3.new(0.3, 0.75, 0.12), CFrame.new(0.32, 0.2, -0.72) * CFrame.Angles(0, 0, 0.2), rgb(230, 50, 60), Enum.Material.Fabric)
	end
	if has("Leaf") then
		b.Rod(headTop - Vector3.new(0, 0.05, 0), headTop + Vector3.new(0.05, 0.3, 0), 0.08, rgb(100, 70, 40))
		b.Blob(Vector3.new(0.95, 0.08, 0.45), CFrame.new(headTop + Vector3.new(0.35, 0.36, 0)) * CFrame.Angles(0, 0.4, 0.3), rgb(90, 200, 70))
	end
	if has("Fluff") then
		-- woolly puffs all over its back and a tuft on its head
		local wool = body:Lerp(WHITE, 0.5)
		for i = 1, 9 do
			local angle = i / 9 * TAU
			b.Ball(0.72, onSurface(bodyCenter, bodySemi, Vector3.new(math.cos(angle) * 0.8, 0.75, math.sin(angle) * 0.9)), wool)
		end
		for i = -1, 1 do
			b.Ball(0.4, headTop + Vector3.new(i * 0.2, 0.02, 0.05), wool)
		end
	end
	if has("Bow") then
		local point = onHead(0.45, 0.85, -0.1)
		for _, side in { -1, 1 } do
			b.Blob(Vector3.new(0.42, 0.32, 0.14), CFrame.new(point + Vector3.new(side * 0.2, 0.05, 0)) * CFrame.Angles(0, 0, side * 0.3), accent)
		end
		b.Ball(0.18, point + Vector3.new(0, 0.05, -0.02), accent)
	end
	if has("Spout") then
		local spout = b.Ball(0.3, onSurface(bodyCenter, bodySemi, Vector3.new(0, 1, -0.3)), accent, Enum.Material.Neon)
		if not opts.NoEffects then
			local water = emitter(spout, ColorSequence.new(accent, WHITE), 8, 0.35 * b.S, 5 * b.S, 0.7)
			water.EmissionDirection = Enum.NormalId.Top
			water.SpreadAngle = Vector2.new(15, 15)
			water.Acceleration = Vector3.new(0, -12, 0)
		end
	end
	if has("Crown") then
		b.Rod(headTop - Vector3.new(0, 0.08, 0), headTop + Vector3.new(0, 0.26, 0), 0.9, GOLD, Enum.Material.Foil)
		for i = 0, 4 do
			local angle = i / 5 * TAU + math.pi / 2
			local point = headTop + Vector3.new(math.cos(angle) * 0.38, 0.4, math.sin(angle) * 0.38)
			b.Part(Vector3.new(0.14, 0.26, 0.14), CFrame.new(point), GOLD, Enum.Material.Foil)
			b.Ball(0.13, point + Vector3.new(0, 0.16, 0), GOLD, Enum.Material.Foil)
		end
		b.Ball(0.2, headTop + Vector3.new(0, 0.1, -0.44), rgb(255, 40, 70), Enum.Material.Neon)
	end
	if has("Halo") then
		flatRing(b, headTop + Vector3.new(0, if has("Crown") then 0.95 else 0.6, 0), 0.5, 0.12, 12, rgb(255, 240, 150), Enum.Material.Neon)
	end
	if has("Shell") then
		local domeCenter, domeSemi = bodyCenter + Vector3.new(0, 0.42, 0), Vector3.new(0.98, 0.55, 1.18)
		b.Blob(domeSemi * 2, CFrame.new(domeCenter), accent, Enum.Material.Slate)
		local plate = accent:Lerp(BLACK, 0.25)
		for i = 0, 6 do
			local dir = if i == 0 then Vector3.yAxis else Vector3.new(math.cos(i / 6 * TAU) * 0.8, 0.75, math.sin(i / 6 * TAU) * 0.8)
			local point = onSurface(domeCenter, domeSemi, dir)
			b.Blob(Vector3.new(0.55, 0.55, 0.1), facingFrame(point, normalAt(domeCenter, domeSemi, point)), plate, Enum.Material.Slate)
		end
	end
	if has("Ghost") then
		for _, part in b.Model:GetChildren() do
			if part:IsA("BasePart") and part.Name == "Body" then
				part.Transparency = 0.25
			end
		end
	end

	if not opts.NoEffects then
		local root = b.Root
		local rarity = Pets.Rarity(pet.Rarity)
		if has("Glow") or rarity.Order >= 5 then
			light(root, accent, 8 + rarity.Order)
		end
		if rarity.Order >= 4 then
			local sparkles = Instance.new("Sparkles")
			sparkles.SparkleColor = accent
			sparkles.Parent = root
		end
		if rarity.Order >= 5 then
			emitter(root, ColorSequence.new(accent, WHITE), 3 + rarity.Order * 2, 0.25 * b.S, 1.2 * b.S, 1.4)
		end
		if has("Stars") then
			local stars = emitter(root, ColorSequence.new(WHITE, accent), 8, 0.3 * b.S, 0.01, 1.2)
			stars.Shape = Enum.ParticleEmitterShape.Sphere
			stars.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			stars.Speed = NumberRange.new(0)
			stars.LockedToPart = true
		end
		if has("Flames") then
			local fire = Instance.new("Fire")
			fire.Color = accent
			fire.SecondaryColor = body
			fire.Size = 2 * b.S
			fire.Heat = 4
			fire.Parent = root
		end
	end

	measure(b.Model, b.Root)
	b.Model:SetAttribute("PetId", pet.Id)
	if has("Rainbow") then
		b.Model:SetAttribute("Rainbow", true)
	end
	if has("Glitch") then
		b.Model:SetAttribute("Glitch", true)
	end
	return b.Model
end

return PetModel
