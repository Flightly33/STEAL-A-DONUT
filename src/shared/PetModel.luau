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

	Pets are little brick critters with studs, built from the blocks the Blender script
	art/studded_pets/studded_pets.py exports (PetBlocks): a body plan (Shape) plus Features (see
	Pets.luau). Their eyes blink, and wings / tails / fins / tentacles swing round their joints
	(see BuildPet and client/Followers.luau).
	Both are one rigid assembly welded to an anchored, invisible "Root" part, so moving Root moves
	everything (cheap to animate on the client). The front is -Z.
]]

local CollectionService = game:GetService("CollectionService")

local Pets = require(script.Parent.Pets)
local PetBlocks = require(script.Parent.PetBlocks)

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
	Bar: (from: Vector3, to: Vector3, thickness: number, color: Color3, material: Enum.Material?) -> Part,
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
	-- A square bar from one point to another (a pet's legs and arms: PetBlocks rods)
	local function bar(from: Vector3, to: Vector3, thickness: number, color: Color3, material: Enum.Material?): Part
		local along = to - from
		local up = if math.abs(along.Unit.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
		local cf = CFrame.lookAt((from + to) / 2, to, up)
		return part(Vector3.new(thickness, thickness, along.Magnitude + thickness * 0.3), cf, color, material)
	end
	return { Model = model, Root = root, S = scale, Part = part, Blob = blob, Ball = ball, Rod = rod, Bar = bar }
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
	Pets are little brick critters, like Domer and the brick donuts: chunky blocks with studs on top,
	square eyes with a white glint that blink ("EyeWhite" / "Pupil"), pink cheeks. Every block comes
	from PetBlocks, which the Blender script art/studded_pets/studded_pets.py exports (it renders them
	all too): a body plan (Shape) plus a list of blocks for each Feature. Wings, tails, fins and
	tentacles hang from real joints ("Limb" = Wing / Tail / Fluke / Fin / Tentacle / Spin, swinging
	around "Pivot"), so the client can flap and wag them (client/Followers.luau). Body-coloured parts
	are all named "Body" so rainbow pets change colour all over (their studs too).
]]

-- What a block's colour name means for this pet (PetBlocks: Color = "Body", "Accent"...)
local function roleColors(pet: Pets.Pet): { [string]: Color3 }
	local body, accent = pet.Body, pet.Accent
	return {
		Body = body,
		Accent = accent,
		Pale = body:Lerp(WHITE, 0.5), -- muzzles, paws, chests, wool
		Shade = body:Lerp(BLACK, 0.25),
		AccentLight = accent:Lerp(WHITE, 0.35),
		Snout = body:Lerp(accent, 0.3),
		ShellPlate = accent:Lerp(BLACK, 0.25),
	}
end

local MATERIALS: { [string]: Enum.Material } = {
	Smooth = Enum.Material.SmoothPlastic,
	Neon = Enum.Material.Neon,
	Foil = Enum.Material.Foil,
	Wood = Enum.Material.Wood,
	WoodPlanks = Enum.Material.WoodPlanks,
	Metal = Enum.Material.Metal,
	Slate = Enum.Material.Slate,
	Fabric = Enum.Material.Fabric,
}

-- Is `point` inside an (unturned) block? (studs under another block aren't made)
local function inBlock(point: Vector3, block: PetBlocks.Block): boolean
	local half = (block.Size :: Vector3) / 2 + Vector3.one * 0.02
	local d = point - (block.Pos :: Vector3)
	return math.abs(d.X) < half.X and math.abs(d.Y) < half.Y and math.abs(d.Z) < half.Z
end

function PetModel.BuildPet(pet: Pets.Pet, options: Options?): Model
	local opts: Options = options or {}
	local b = newBuilder(pet.Id, (opts.Scale or 1) * (pet.Scale or 1))
	local has: { [string]: boolean } = {}
	for _, feature in pet.Features do
		has[feature] = true
	end
	local colors = roleColors(pet)

	-- The pet's blocks: its body plan, then each of its features (for that body plan)
	local blocks: { PetBlocks.Block } = {}
	local function take(list: { PetBlocks.Block }?)
		local found: { PetBlocks.Block } = list or {}
		for _, block in found do
			if (block.Only == nil or has[block.Only]) and (block.Unless == nil or not has[block.Unless]) then
				table.insert(blocks, block)
			end
		end
	end
	local shape = PetBlocks.Shapes[pet.Shape] or PetBlocks.Shapes.Quad
	take(shape.Blocks)
	for _, feature in pet.Features do
		local byShape = PetBlocks.Features[feature]
		if byShape then
			take(byShape[pet.Shape])
		end
	end

	local function colorOf(block: PetBlocks.Block): Color3
		local c = block.Color
		return if typeof(c) == "Color3" then c else colors[c :: string] or pet.Body
	end
	local function materialOf(block: PetBlocks.Block): Enum.Material
		local m = block.Material
		if m == "Glow" then
			return if has.Glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
		return MATERIALS[m or "Smooth"] or Enum.Material.SmoothPlastic
	end
	-- Name, see-through, joints and blinking: the same for a block and for its studs
	local function mark(part: BasePart, block: PetBlocks.Block)
		part.Name = block.Name or "Part"
		part.Transparency = block.Transparency or (if has.Ghost and block.Name == "Body" then 0.25 else 0)
		local limb = block.Limb
		if limb then
			part:SetAttribute("Limb", limb.Kind)
			part:SetAttribute("Side", limb.Side)
			part:SetAttribute("Pivot", limb.Pivot * b.S)
		end
		if block.Eye then
			part:SetAttribute("EyeWhite", true)
		elseif block.Pupil then
			part:SetAttribute("Pupil", true)
		end
	end

	for _, block in blocks do
		local part
		if block.From and block.To and block.Thick then
			part = b.Bar(block.From, block.To, block.Thick, colorOf(block), materialOf(block))
		else
			local rot = block.Rot
			local turn = if rot then CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z)) else CFrame.identity
			part = b.Part(block.Size :: Vector3, CFrame.new(block.Pos :: Vector3) * turn, colorOf(block), materialOf(block))
		end
		mark(part, block)
	end

	-- Studs on the tops of the big blocks, every StudPitch (none where another block covers them)
	local pitch = PetBlocks.StudPitch
	for _, block in blocks do
		local pos, size = block.Pos, block.Size
		if block.Studs and pos and size and not block.Rot then
			local nx = math.max(1, math.floor(size.X / pitch + 1e-6))
			local nz = math.max(1, math.floor(size.Z / pitch + 1e-6))
			for i = 0, nx - 1 do
				for j = 0, nz - 1 do
					local point = pos + Vector3.new(-(nx - 1) * pitch / 2 + i * pitch, size.Y / 2 + PetBlocks.StudSize.X / 2, -(nz - 1) * pitch / 2 + j * pitch)
					local hidden = false
					for _, other in blocks do
						if other ~= block and other.Pos and not other.Rot and (other.Transparency or 0) < 1 and inBlock(point, other) then
							hidden = true
							break
						end
					end
					if not hidden then
						local stud = b.Part(PetBlocks.StudSize, CFrame.new(point) * UPRIGHT, colorOf(block), materialOf(block), Enum.PartType.Cylinder)
						mark(stud, block)
					end
				end
			end
		end
	end

	if not opts.NoEffects then
		local root = b.Root
		local accent = pet.Accent
		local rarity = Pets.Rarity(pet.Rarity)
		if has.Glow or rarity.Order >= 5 then
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
		if has.Stars then
			local stars = emitter(root, ColorSequence.new(WHITE, accent), 8, 0.3 * b.S, 0.01, 1.2)
			stars.Shape = Enum.ParticleEmitterShape.Sphere
			stars.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			stars.Speed = NumberRange.new(0)
			stars.LockedToPart = true
		end
		if has.Flames then
			local fire = Instance.new("Fire")
			fire.Color = accent
			fire.SecondaryColor = pet.Body
			fire.Size = 2 * b.S
			fire.Heat = 4
			fire.Parent = root
		end
		-- the whale's spout sprays water
		local spout = b.Model:FindFirstChild("Spout")
		if spout then
			local water = emitter(spout, ColorSequence.new(accent, WHITE), 8, 0.35 * b.S, 5 * b.S, 0.7)
			water.EmissionDirection = Enum.NormalId.Top
			water.SpreadAngle = Vector2.new(15, 15)
			water.Acceleration = Vector3.new(0, -12, 0)
		end
	end

	measure(b.Model, b.Root)
	b.Model:SetAttribute("PetId", pet.Id)
	if has.Rainbow then
		b.Model:SetAttribute("Rainbow", true)
	end
	if has.Glitch then
		b.Model:SetAttribute("Glitch", true)
	end
	return b.Model
end

return PetModel
