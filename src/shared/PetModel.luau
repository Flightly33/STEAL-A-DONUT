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

	Pets are little creatures built from a body plan (Shape) plus Features (see Pets.luau).
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
	return { Model = model, Root = root, S = scale, Part = part, Blob = blob }
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
	local shell = b.Blob(Vector3.new(2.2, 2.9, 2.2), CFrame.new(0, 0, 0), egg.Color, material)
	shell.Name = "Shell"
	if tier == 2 or tier == 5 then
		shell.Reflectance = 0.25
	end
	-- Spots on the surface of the ellipsoid
	local rng = Random.new(#egg.Id * 97)
	for i = 1, 7 do
		local yaw = i / 7 * TAU + rng:NextNumber(-0.3, 0.3)
		local y = rng:NextNumber(-0.9, 1.0)
		local ring = math.sqrt(math.max(0, 1 - (y / 1.45) ^ 2)) * 1.08
		local spot = b.Blob(Vector3.new(0.55, 0.55, 0.12), CFrame.lookAt(Vector3.new(math.cos(yaw) * ring, y, math.sin(yaw) * ring), Vector3.zero), egg.Accent, if tier >= 4 then Enum.Material.Neon else Enum.Material.SmoothPlastic)
		spot.Name = "Spot"
	end
	-- Glowing zig-zag crack around the middle
	if tier >= 3 then
		for i = 0, 11 do
			local angle = i / 12 * TAU
			local y = if i % 2 == 0 then 0.12 else -0.12
			local crack = b.Part(Vector3.new(0.62, 0.1, 0.08), CFrame.new(math.cos(angle) * 1.1, y, math.sin(angle) * 1.1) * CFrame.Angles(0, -angle + math.pi / 2, if i % 2 == 0 then 0.35 else -0.35), egg.Accent, Enum.Material.Neon)
			crack.Name = "Crack"
		end
	end

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
function PetModel.BuildPet(pet: Pets.Pet, options: Options?): Model
	local opts: Options = options or {}
	local b = newBuilder(pet.Id, (opts.Scale or 1) * (pet.Scale or 1))
	local body, accent = pet.Body, pet.Accent
	local has = function(feature: string): boolean
		return Pets.HasFeature(pet, feature)
	end
	local glowMaterial = if has("Glow") then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local shape = pet.Shape

	-- Body plan: where the head sits, how big it is, and where the back / tail go.
	local head: CFrame
	local headSize = 1.5
	local back = CFrame.new(0, 0.8, 0.9)
	local bodyPart: Part
	if shape == "Bird" then
		bodyPart = b.Blob(Vector3.new(1.8, 2, 1.8), CFrame.new(0, 0, 0), body)
		head = CFrame.new(0, 1.35, -0.15)
		headSize = 1.35
		back = CFrame.new(0, 0.2, 0.8)
		for _, side in { -1, 1 } do
			b.Blob(Vector3.new(0.5, 0.2, 0.7), CFrame.new(side * 0.4, -1.05, -0.3), rgb(255, 170, 40))
		end
	elseif shape == "Blob" then
		bodyPart = b.Blob(Vector3.new(2.3, 2, 2.3), CFrame.new(0, 0, 0), body, if has("Ghost") then Enum.Material.SmoothPlastic else nil)
		head = CFrame.new(0, 0.3, -0.35)
		headSize = 0 -- the body is the head
		back = CFrame.new(0, 0.6, 0.8)
	elseif shape == "Whale" then
		bodyPart = b.Blob(Vector3.new(2.3, 1.7, 3.6), CFrame.new(0, 0, 0), body)
		b.Blob(Vector3.new(1.9, 1, 3.2), CFrame.new(0, -0.35, -0.05), accent)
		head = CFrame.new(0, 0.2, -1.35)
		headSize = 0
		back = CFrame.new(0, 0.3, 1.6)
		b.Blob(Vector3.new(2.2, 0.25, 0.9), CFrame.new(0, 0.2, 2.1) * CFrame.Angles(0.3, 0, 0), body)
		for _, side in { -1, 1 } do
			b.Blob(Vector3.new(1.1, 0.2, 0.6), CFrame.new(side * 1.2, -0.3, -0.2) * CFrame.Angles(0, 0, side * 0.5), body)
		end
	elseif shape == "Crab" then
		bodyPart = b.Blob(Vector3.new(2.6, 1.2, 2), CFrame.new(0, 0, 0), body)
		head = CFrame.new(0, 0.9, -0.6)
		headSize = 0
		back = CFrame.new(0, 0.4, 0.9)
		for _, side in { -1, 1 } do
			for i = 0, 2 do
				b.Part(Vector3.new(0.9, 0.18, 0.18), CFrame.new(side * 1.45, -0.4, -0.5 + i * 0.5) * CFrame.Angles(0, 0, side * -0.6), body, nil, Enum.PartType.Cylinder)
			end
			-- eye stalks
			b.Part(Vector3.new(0.6, 0.15, 0.15), CFrame.new(side * 0.35, 0.85, -0.6) * UPRIGHT, body, nil, Enum.PartType.Cylinder)
		end
	else -- Quad / Dragon: a body with four legs and a head at the front
		local dragon = shape == "Dragon"
		bodyPart = b.Blob(Vector3.new(1.9, 1.6, if dragon then 3 else 2.5), CFrame.new(0, 0, 0.1), body)
		head = if dragon then CFrame.new(0, 1.3, -1.6) else CFrame.new(0, 0.85, -1.15)
		headSize = if dragon then 1.35 else 1.55
		for _, x in { -0.6, 0.6 } do
			for _, z in { -0.8, 0.9 } do
				b.Part(Vector3.new(0.7, 0.45, 0.45), CFrame.new(x, -0.95, z) * UPRIGHT, body, nil, Enum.PartType.Cylinder)
				b.Part(Vector3.one * 0.5, CFrame.new(x, -1.2, z - 0.05), accent, nil, Enum.PartType.Ball)
			end
		end
		if dragon then
			b.Part(Vector3.new(1, 0.6, 0.6), CFrame.new(0, 0.75, -1.1) * CFrame.Angles(0, math.pi / 2, math.rad(40)), body, nil, Enum.PartType.Cylinder)
		end
		if has("Shell") then
			b.Blob(Vector3.new(2.3, 1.2, 2.6), CFrame.new(0, 0.55, 0.1), accent, Enum.Material.Slate)
			for i = 0, 5 do
				local angle = i / 6 * TAU
				b.Blob(Vector3.new(0.6, 0.15, 0.6), CFrame.new(math.cos(angle) * 0.6, 1.05, 0.1 + math.sin(angle) * 0.6), accent:Lerp(BLACK, 0.3))
			end
		end
	end
	bodyPart.Name = "Body"
	if has("Ghost") then
		bodyPart.Transparency = 0.25
	end

	-- Head (or the face on the body) + eyes, cheeks and a smile
	local face = head
	if headSize > 0 then
		local headPart = b.Part(Vector3.one * headSize, head, body, nil, Enum.PartType.Ball)
		headPart.Name = "Head"
		face = head * CFrame.new(0, 0, -headSize * 0.42)
	else
		face = head * CFrame.new(0, 0, -0.75)
	end
	local eyeSpread = if headSize > 0 then headSize * 0.22 else 0.38
	for _, side in { -1, 1 } do
		local eye = face * CFrame.new(side * eyeSpread, 0.12, 0)
		b.Part(Vector3.one * 0.42, eye, WHITE, nil, Enum.PartType.Ball)
		b.Part(Vector3.one * 0.26, eye * CFrame.new(0, -0.02, -0.14), BLACK, nil, Enum.PartType.Ball)
		b.Part(Vector3.one * 0.08, eye * CFrame.new(0.05, 0.06, -0.25), WHITE, Enum.Material.Neon, Enum.PartType.Ball)
		b.Blob(Vector3.new(0.3, 0.15, 0.05), face * CFrame.new(side * eyeSpread * 1.35, -0.2, 0.05), rgb(255, 140, 170))
	end
	b.Part(Vector3.new(0.3, 0.06, 0.05), face * CFrame.new(0, -0.22, -0.02), BLACK)

	-- Features
	local headTop = if headSize > 0 then head * CFrame.new(0, headSize * 0.45, 0) else head * CFrame.new(0, 0.85, 0.3)
	for _, side in { -1, 1 } do
		if has("PointyEars") then
			b.Part(Vector3.new(0.45, 0.6, 0.18), headTop * CFrame.new(side * 0.4, 0.2, 0.05) * CFrame.Angles(0, 0, side * -0.3), body)
			b.Part(Vector3.new(0.25, 0.35, 0.2), headTop * CFrame.new(side * 0.4, 0.17, 0.02) * CFrame.Angles(0, 0, side * -0.3), accent)
		end
		if has("FloppyEars") then
			b.Blob(Vector3.new(0.35, 0.9, 0.5), headTop * CFrame.new(side * 0.72, -0.35, 0.1) * CFrame.Angles(0, 0, side * 0.3), accent)
		end
		if has("LongEars") then
			b.Blob(Vector3.new(0.35, 1.4, 0.25), headTop * CFrame.new(side * 0.3, 0.6, 0.1) * CFrame.Angles(0, 0, side * -0.15), body)
			b.Blob(Vector3.new(0.18, 1.1, 0.26), headTop * CFrame.new(side * 0.3, 0.6, 0.08) * CFrame.Angles(0, 0, side * -0.15), accent)
		end
		if has("RoundEars") then
			b.Part(Vector3.one * 0.5, headTop * CFrame.new(side * 0.5, 0.05, 0.05), body, nil, Enum.PartType.Ball)
		end
		if has("Horns") then
			b.Part(Vector3.new(0.2, 0.7, 0.2), headTop * CFrame.new(side * 0.35, 0.3, 0.1) * CFrame.Angles(0, 0, side * -0.35), rgb(250, 240, 220))
		end
		if has("Tufts") then
			b.Part(Vector3.new(0.18, 0.5, 0.18), headTop * CFrame.new(side * 0.4, 0.15, 0) * CFrame.Angles(0, 0, side * -0.5), accent)
		end
		if has("Wings") then
			local wing = back * CFrame.new(side * 1.05, 0.3, 0) * CFrame.Angles(0, 0, side * -0.5)
			local w = b.Blob(Vector3.new(0.25, 1.4, 1.6), wing * CFrame.new(side * 0.4, 0.4, 0), accent, glowMaterial)
			w.Name = "Wing"
			w:SetAttribute("Flap", side)
		end
		if has("Claws") then
			b.Blob(Vector3.new(0.9, 0.55, 0.7), CFrame.new(side * 1.5, 0.1, -1.1), accent)
		end
		if has("Belly") then
			b.Blob(Vector3.new(1.2, 1.5, 0.3), CFrame.new(0, -0.1, -0.78), accent)
		end
	end
	if has("Horn") then
		b.Part(Vector3.new(0.9, 0.22, 0.22), headTop * CFrame.new(0, 0.3, -0.35) * CFrame.Angles(0, 0, math.rad(80)) * CFrame.Angles(0, math.rad(-20), 0), rgb(255, 230, 120), Enum.Material.Neon, Enum.PartType.Cylinder)
	end
	if has("Beak") then
		b.Blob(Vector3.new(0.45, 0.3, 0.6), face * CFrame.new(0, -0.08, -0.2), rgb(255, 170, 40))
	end
	if has("Crest") then
		for i = 0, 2 do
			b.Part(Vector3.new(0.12, 0.6, 0.3), headTop * CFrame.new(0, 0.2, 0.1 + i * 0.25) * CFrame.Angles(0.3 * i, 0, 0), accent, glowMaterial)
		end
	end
	if has("Antenna") then
		for _, side in { -1, 1 } do
			b.Part(Vector3.new(0.7, 0.08, 0.08), headTop * CFrame.new(side * 0.25, 0.35, 0) * CFrame.Angles(0, 0, side * -1.2), accent, nil, Enum.PartType.Cylinder)
		end
	end
	if has("Mane") then
		for i = 0, 4 do
			b.Blob(Vector3.new(0.35, 0.6, 0.4), headTop * CFrame.new(0, -0.1 - i * 0.25, 0.3 + i * 0.22), Color3.fromHSV(i / 5, 0.6, 1), Enum.Material.Neon)
		end
	end
	if has("Tail") then
		b.Part(Vector3.new(1.2, 0.3, 0.3), back * CFrame.new(0, -0.3, 0.8) * CFrame.Angles(0, math.pi / 2, math.rad(35)), body, nil, Enum.PartType.Cylinder)
		b.Part(Vector3.one * 0.4, back * CFrame.new(0, 0.1, 1.35), accent, glowMaterial, Enum.PartType.Ball)
	end
	if has("PuffTail") then
		b.Part(Vector3.one * 0.6, back * CFrame.new(0, -0.4, 0.4), accent, nil, Enum.PartType.Ball)
	end
	if has("BigTail") then
		b.Blob(Vector3.new(0.8, 0.8, 1.8), back * CFrame.new(0, 0, 0.9) * CFrame.Angles(0.6, 0, 0), body)
		b.Blob(Vector3.new(0.6, 0.6, 0.6), back * CFrame.new(0, 0.55, 1.55), accent)
	end
	if has("Spikes") then
		for i = 0, 3 do
			b.Part(Vector3.new(0.25, 0.45, 0.25), CFrame.new(0, 0.85, -0.6 + i * 0.45) * CFrame.Angles(0, math.rad(45), 0), accent)
		end
	end
	if has("Tentacles") then
		for i = 0, 5 do
			local angle = i / 6 * TAU
			local t = b.Part(Vector3.new(1.1, 0.3, 0.3), CFrame.new(math.cos(angle) * 0.7, -1.1, math.sin(angle) * 0.7) * CFrame.Angles(0, -angle, math.rad(70)), accent, glowMaterial, Enum.PartType.Cylinder)
			t.Name = "Tentacle"
		end
	end
	if has("Sprinkles") then
		local colors = { rgb(255, 70, 70), rgb(80, 200, 255), rgb(255, 235, 70), rgb(120, 230, 90) }
		for i = 1, 8 do
			local angle = i / 8 * TAU
			b.Part(Vector3.new(0.08, 0.08, 0.3), CFrame.new(math.cos(angle) * 0.6, 0.82, 0.1 + math.sin(angle) * 0.8) * CFrame.Angles(0, angle, 0), colors[i % 4 + 1], Enum.Material.Neon)
		end
	end
	if has("DonutRing") then
		for i = 0, 9 do
			local angle = i / 10 * TAU
			b.Part(Vector3.one * 0.42, CFrame.new(math.cos(angle) * 1.05, -0.2, math.sin(angle) * 1.05), rgb(222, 165, 95), nil, Enum.PartType.Ball)
			b.Part(Vector3.one * 0.34, CFrame.new(math.cos(angle) * 1.05, -0.02, math.sin(angle) * 1.05), rgb(255, 130, 190), nil, Enum.PartType.Ball)
		end
	end
	if has("Scarf") then
		b.Part(Vector3.new(0.35, 1.5, 1.5), CFrame.new(0, 0.55, -0.1) * UPRIGHT, rgb(230, 50, 60), Enum.Material.Fabric, Enum.PartType.Cylinder)
	end
	if has("Leaf") then
		b.Blob(Vector3.new(1, 0.1, 0.5), headTop * CFrame.new(0.2, 0.15, 0) * CFrame.Angles(0, 0.5, 0.3), rgb(90, 200, 70))
	end
	if has("Fluff") then
		for i = 1, 7 do
			local angle = i / 7 * TAU
			b.Part(Vector3.one * 0.9, CFrame.new(math.cos(angle) * 0.75, 0.5, math.sin(angle) * 0.9), rgb(255, 255, 255), nil, Enum.PartType.Ball)
		end
	end
	if has("Bow") then
		for _, side in { -1, 1 } do
			b.Blob(Vector3.new(0.45, 0.35, 0.15), headTop * CFrame.new(side * 0.25 + 0.3, 0.05, -0.1) * CFrame.Angles(0, 0, side * 0.3), accent)
		end
	end
	if has("Spout") then
		local spout = b.Part(Vector3.one * 0.3, CFrame.new(0, 1.1, -0.4), accent, Enum.Material.Neon, Enum.PartType.Ball)
		if not opts.NoEffects then
			local water = emitter(spout, ColorSequence.new(accent, WHITE), 8, 0.35 * b.S, 5 * b.S, 0.7)
			water.EmissionDirection = Enum.NormalId.Top
			water.SpreadAngle = Vector2.new(15, 15)
			water.Acceleration = Vector3.new(0, -12, 0)
		end
	end
	if has("Crown") then
		b.Part(Vector3.new(0.3, 1, 1), headTop * CFrame.new(0, 0.15, 0) * UPRIGHT, rgb(255, 205, 50), Enum.Material.Foil, Enum.PartType.Cylinder)
		for i = 0, 4 do
			local angle = i / 5 * TAU
			b.Part(Vector3.new(0.14, 0.32, 0.14), headTop * CFrame.new(math.cos(angle) * 0.42, 0.4, math.sin(angle) * 0.42), rgb(255, 205, 50), Enum.Material.Foil)
		end
	end
	if has("Halo") then
		b.Part(Vector3.new(0.12, 1.2, 1.2), headTop * CFrame.new(0, 0.75, 0) * UPRIGHT, rgb(255, 240, 150), Enum.Material.Neon, Enum.PartType.Cylinder)
		b.Part(Vector3.new(0.14, 0.9, 0.9), headTop * CFrame.new(0, 0.75, 0) * UPRIGHT, body, nil, Enum.PartType.Cylinder)
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
