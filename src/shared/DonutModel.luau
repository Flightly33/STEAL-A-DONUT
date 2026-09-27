--[[
	DonutModel
	==========
	Builds a donut "character" out of plain parts (no uploaded meshes needed): a ring of dough balls,
	a glossy frosting layer with drips, sprinkles, a cute face and brainrot accessories (legs,
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
	"Limb" attribute and the point they swing around ("Pivot", in the donut's own space), and each eye
	has a hidden eyelid ("Lid"), so the client can play idle animations (see client/DonutIdle.luau).

	Used by the server (lane spawns, bases, podiums, carried donuts) and the client (Index previews).
]]

local CollectionService = game:GetService("CollectionService")

local Rarities = require(script.Parent.Rarities)
local Format = require(script.Parent.Format)
local Donuts = require(script.Parent.Donuts)
local FXThemes = require(script.Parent.FXThemes)

type Donut = Donuts.Donut

local DonutModel = {}

local RING_RADIUS = 1.5
local BALL = 1.55
local SEGMENTS = 12
local FROSTING_OFFSET = -0.28 -- frosting sits on the front face (-Z is the donut's front)
local FROSTING_BALL = BALL * 0.92

local rgb = Color3.fromRGB
local WHITE = rgb(255, 255, 255)
local BLACK = rgb(20, 20, 20)

export type BuildOptions = {
	Scale: number?,
	Pillar: boolean?, -- tall light pillar (rare lane donuts, so players can spot them from afar)
	NoEffects: boolean?, -- skip lights/particles (viewport previews)
	Mutation: string?,
	Size: string?,
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

function DonutModel.Build(donut: Donut, options: BuildOptions?): Model
	local opts: BuildOptions = options or {}
	local rarity = Rarities.Get(donut.Rarity)
	local mutation = Rarities.Mutation(opts.Mutation)
	local size = Rarities.Size(opts.Size)
	local s = (opts.Scale or 1) * size.Scale
	local rng = Random.new(hashString(donut.Id))
	local partsSet = {}
	for _, name in donut.Parts do
		partsSet[name] = true
	end
	if rarity.Halo or mutation.Halo then
		partsSet.Halo = true
	end
	if mutation.Wings then
		partsSet.Wings = true
	end
	if mutation.Horns then
		partsSet.Horns = true
	end

	local doughColor = mutation.Dough or donut.Dough
	local frostingColor = mutation.Frosting or donut.Frosting
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
	local shine = if rarity.Shine or special then 0.15 else 0.04

	-- Dough ring + frosting (+ a lighter "inner ring" so the hole reads clearly)
	for i = 0, SEGMENTS - 1 do
		local angle = (i / SEGMENTS) * math.pi * 2
		local x, y = R * math.cos(angle), R * math.sin(angle)
		local dough = ball(BALL, doughColor, at(x, y, 0), doughMaterial, "Dough")
		dough.Reflectance = shine * 0.4
		local frosting = ball(FROSTING_BALL, frostingColor, at(x, y, FROSTING_OFFSET), frostingMaterial, "Frosting")
		frosting.Reflectance = shine
		if mutation.Id == "Diamond" then
			frosting.Transparency = 0.15
		end
	end
	ball(BALL * 0.55, doughColor:Lerp(BLACK, 0.25), at(0, 0, 0.35), nil, "Hole").Transparency = 0.2

	-- Frosting drips running down the outside of the ring
	for n = 1, 5 do
		local angle = math.rad(200 + n * 28 + rng:NextNumber(-8, 8))
		local dripLength = rng:NextNumber(0.35, 0.7)
		local cf = at((R + FROSTING_BALL * 0.42) * math.cos(angle), (R + FROSTING_BALL * 0.42) * math.sin(angle) - dripLength * 0.4, FROSTING_OFFSET - 0.1)
		ellipsoid(Vector3.new(0.34, dripLength + 0.3, 0.34), frostingColor, cf, frostingMaterial, "Frosting").Reflectance = shine
	end

	-- Sprinkles on the frosting (skipping the balls under the face)
	local sprinkleColors = donut.Sprinkles
	if mutation.Id == "Gold" then
		sprinkleColors = { rgb(255, 250, 200), rgb(255, 180, 40) }
	elseif mutation.Id == "Diamond" then
		sprinkleColors = { WHITE, rgb(150, 230, 255) }
	end
	if sprinkleColors then
		local colors = sprinkleColors
		local frostRadius = FROSTING_BALL / 2
		for n = 1, 20 do
			local segment
			repeat
				segment = rng:NextInteger(0, SEGMENTS - 1)
			until segment ~= 2 and segment ~= 3 and segment ~= 4
			local angle = (segment / SEGMENTS) * math.pi * 2
			local dx, dy
			repeat
				dx, dy = rng:NextNumber(-0.45, 0.45), rng:NextNumber(-0.45, 0.45)
			until dx * dx + dy * dy < 0.2
			local z = FROSTING_OFFSET - math.sqrt(frostRadius * frostRadius - dx * dx - dy * dy) + 0.04
			local cf = at(R * math.cos(angle) + dx, R * math.sin(angle) + dy, z) * CFrame.Angles(0, 0, rng:NextNumber(0, math.pi * 2))
			block(Vector3.new(0.11, 0.38, 0.11), colors[(n - 1) % #colors + 1], cf, if special then Enum.Material.Neon else Enum.Material.SmoothPlastic, "Sprinkle")
		end
	end

	-- Face (eyes with shiny highlights, blushing cheeks, a smile)
	local eyesCovered = partsSet.Sunglasses or partsSet.Visor
	for _, side in { -1, 1 } do
		if not (partsSet.EyePatch and side == 1) then
			ball(0.64, WHITE, at(side * 0.5, TOP - 0.68, -0.95), nil, "Eye")
			if not eyesCovered then
				ball(0.34, BLACK, at(side * 0.47, TOP - 0.7, -1.2), nil, "Pupil")
				ball(0.11, WHITE, at(side * 0.42, TOP - 0.6, -1.36), Enum.Material.Neon, "Glint")
				-- Eyelid + lashes: invisible until the client makes the donut blink
				local lid = ellipsoid(Vector3.new(0.72, 0.72, 0.46), frostingColor:Lerp(doughColor, 0.5), at(side * 0.49, TOP - 0.68, -1.2), nil, "Lid")
				lid.Transparency = 1
				lid:SetAttribute("Blink", true)
				local lash = block(Vector3.new(0.5, 0.07, 0.06), BLACK, at(side * 0.49, TOP - 0.72, -1.45), nil, "Lash")
				lash.Transparency = 1
				lash:SetAttribute("Blink", true)
			end
		end
		ellipsoid(Vector3.new(0.36, 0.2, 0.1), rgb(255, 130, 160), at(side * 0.86, TOP - 1.08, -0.86), nil, "Cheek").Transparency = 0.25
	end
	if not partsSet.Mustache and not partsSet.Beak and not partsSet.Fangs then
		ellipsoid(Vector3.new(0.5, 0.18, 0.12), rgb(90, 30, 30), at(0, TOP - 1.2, -0.76), nil, "Mouth")
	end

	-- Brainrot accessories
	local accessories = {}

	function accessories.Legs()
		for _, side in { -1, 1 } do
			local hipX, hipY = side * 0.55, -TOP + 0.2
			limb(cylinder(1.3, 0.38, doughColor, at(side * 0.55, -TOP - 0.45, 0)), "Leg", side, hipX, hipY, 0)
			limb(block(Vector3.new(0.55, 0.32, 0.8), WHITE, at(side * 0.55, -TOP - 1.12, -0.15), nil, "Shoe"), "Leg", side, hipX, hipY, 0)
			limb(block(Vector3.new(0.57, 0.1, 0.82), rgb(230, 40, 40), at(side * 0.55, -TOP - 1.0, -0.15), nil, "ShoeStripe"), "Leg", side, hipX, hipY, 0)
		end
	end

	function accessories.Arms()
		for _, side in { -1, 1 } do
			local cf = at(side * (R + 1.05), 0.2, -0.1) * CFrame.Angles(0, 0, side * math.rad(-35))
			-- The shoulder is the arm's inner end, where it meets the ring
			local shoulderX, shoulderY = side * (R + 0.74), -0.25
			limb(cylinder(1.1, 0.3, doughColor, cf), "Arm", side, shoulderX, shoulderY, -0.1)
			limb(ball(0.45, WHITE, at(side * (R + 1.4), 0.7, -0.1), nil, "Glove"), "Arm", side, shoulderX, shoulderY, -0.1)
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
			ellipsoid(Vector3.new(0.55, 0.22, 0.16), BLACK, at(side * 0.25, TOP - 1.12, -0.82) * CFrame.Angles(0, 0, side * math.rad(-15)), nil, "Mustache")
		end
	end

	function accessories.TopHat()
		cylinder(0.12, 1.9, BLACK, at(0, TOP + 0.06, 0))
		cylinder(1.2, 1.15, BLACK, at(0, TOP + 0.7, 0))
		cylinder(0.25, 1.17, rgb(200, 30, 40), at(0, TOP + 0.3, 0))
	end

	function accessories.Sunglasses()
		for _, side in { -1, 1 } do
			block(Vector3.new(0.62, 0.4, 0.12), BLACK, at(side * 0.48, TOP - 0.68, -1.28), Enum.Material.Glass, "Lens").Reflectance = 0.3
		end
		block(Vector3.new(0.36, 0.08, 0.1), BLACK, at(0, TOP - 0.62, -1.28))
	end

	function accessories.Visor()
		block(Vector3.new(1.9, 0.4, 0.14), rgb(0, 255, 255), at(0, TOP - 0.68, -1.28), Enum.Material.Neon, "Visor")
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
			cylinder(0.14, 0.6, rgb(120, 220, 255), at(side * 0.48, TOP - 0.68, -1.25) * CFrame.Angles(math.pi / 2, 0, 0), Enum.Material.Glass, "Goggle")
		end
		block(Vector3.new(1.9, 0.12, 0.1), rgb(40, 40, 50), at(0, TOP - 0.68, -1.2))
		cylinder(1.6, 0.22, rgb(255, 200, 40), at(R + 0.6, TOP - 0.1, -0.3), Enum.Material.SmoothPlastic, "Snorkel")
	end

	function accessories.Tentacles()
		for n = 0, 5 do
			local x = -1.25 + n * 0.5
			for k = 0, 2 do
				local piece = ball(0.42 - k * 0.08, doughColor:Lerp(WHITE, 0.15), at(x + math.sin(n + k) * 0.12, -TOP - 0.1 - k * 0.38, 0), nil, "Tentacle")
				limb(piece, "Tentacle", if n % 2 == 0 then 1 else -1, x, -TOP + 0.1, 0)
			end
		end
	end

	function accessories.Fangs()
		for _, side in { -1, 1 } do
			wedge(Vector3.new(0.14, 0.32, 0.14), WHITE, at(side * 0.2, TOP - 1.3, -0.84) * CFrame.Angles(math.pi, 0, 0))
		end
		ellipsoid(Vector3.new(0.6, 0.2, 0.12), rgb(90, 20, 30), at(0, TOP - 1.16, -0.78), nil, "Mouth")
	end

	function accessories.PirateHat()
		ellipsoid(Vector3.new(2.3, 0.7, 1.1), BLACK, at(0, TOP + 0.35, 0), nil, "PirateHat")
		ball(0.4, WHITE, at(0, TOP + 0.4, -0.5), nil, "Skull")
	end

	function accessories.EyePatch()
		block(Vector3.new(0.6, 0.5, 0.1), BLACK, at(0.5, TOP - 0.68, -1.18), nil, "EyePatch")
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
		else
			warn(`[DonutModel] Unknown accessory "{name}" on donut {donut.Id}`)
		end
	end

	-- Secret donuts get a shimmering force-field aura
	if rarity.Id == "Secret" then
		local aura = ball(6.5, rarity.Color, at(0, 0, 0), Enum.Material.ForceField, "Aura")
		aura.Transparency = 0.3
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
	local TAU = math.pi * 2
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

	local themeParts: { [string]: (FXThemes.Theme) -> () } = {}

	function themeParts.Radiance(theme: FXThemes.Theme)
		burst(8, 4.2, theme.Colors, 0.35)
	end

	function themeParts.Starlight(_theme: FXThemes.Theme)
		twinkles(3.6, ColorSequence.new(rgb(255, 170, 240), rgb(150, 230, 255)), 14, 0.45)
	end

	function themeParts.Void(_theme: FXThemes.Theme)
		-- Rainbow particles pouring into the donut like a black hole, a prismatic star of rays,
		-- and stars popping all around it
		shell(3.4, true, RAINBOW_SEQUENCE, 45, 0.3, 6)
		burst(12, 5.2, { rgb(255, 90, 90), rgb(255, 220, 60), rgb(80, 255, 140), rgb(80, 180, 255), rgb(200, 100, 255), rgb(255, 255, 255) }, -0.5)
		twinkles(4.2, ColorSequence.new(rgb(255, 255, 255), rgb(200, 150, 255)), 18, 0.5)
	end

	function themeParts.Treasure(_theme: FXThemes.Theme)
		twinkles(2.6, ColorSequence.new(rgb(255, 230, 90), rgb(255, 255, 220)), 7, 0.55)
	end

	function themeParts.Glitter(_theme: FXThemes.Theme)
		shell(1.9, false, ColorSequence.new(rgb(200, 250, 255), rgb(120, 220, 255)), 22, 0.18, 2.5)
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
		-- God rays shining down from the sky, and flecks of light drifting down
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
			ray.Color = ColorSequence.new(rgb(255, 245, 200), rgb(255, 215, 110))
			ray.Transparency = NumberSequence.new(0.92, 0.55)
			ray.Parent = sky
		end
		local motes = emitter(sky, ColorSequence.new(rgb(255, 250, 220), rgb(255, 210, 90)), 14, 0.28 * s, 5 * s, 3)
		motes.EmissionDirection = Enum.NormalId.Bottom
		motes.Shape = Enum.ParticleEmitterShape.Box
		motes.SpreadAngle = Vector2.new(8, 8)
		motes.Brightness = 3
	end

	function themeParts.Prism(_theme: FXThemes.Theme)
		burst(10, 4.6, { rgb(255, 70, 70), rgb(255, 170, 40), rgb(255, 240, 60), rgb(80, 240, 110), rgb(70, 170, 255), rgb(190, 90, 255) }, 0.6)
		shell(2.8, false, RAINBOW_SEQUENCE, 18, 0.22, 3)
	end

	-- Effects: rarity and mutation effects stack
	if not opts.NoEffects then
		local lightRange = math.max(rarity.Light or 0, mutation.Light or 0)
		if lightRange > 0 then
			local light = Instance.new("PointLight")
			light.Color = if mutation.Order > 0 then mutation.Color else rarity.Color
			light.Brightness = 1.5
			light.Range = lightRange * s
			light.Shadows = false
			light.Parent = root
		end
		if rarity.Particles then
			emitter(root, ColorSequence.new(rarity.Color, WHITE), rarity.Particles, 0.35 * s, 3 * s, 1.8)
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
		if mutation.Id == "Gold" or mutation.Id == "Diamond" or rarity.Order >= 5 then
			local sparkles = Instance.new("Sparkles")
			sparkles.SparkleColor = if mutation.Order > 0 then mutation.Color else rarity.Color
			sparkles.Parent = root
		end
		if opts.Pillar and (rarity.Beam or mutation.Order >= 3) then
			local pillar = Instance.new("Part")
			pillar.Name = "Pillar"
			pillar.Shape = Enum.PartType.Cylinder
			pillar.Size = Vector3.new(60, 3.5, 3.5)
			-- `bottom` is the lowest point of the donut, so the pillar starts at the ground.
			local pillarCf = CFrame.new(0, bottom + 30, 0) * CFrame.Angles(0, 0, math.pi / 2)
			add(pillar, pillarCf, if mutation.Order >= 3 then mutation.Color else rarity.Color, Enum.Material.Neon)
			pillar.Transparency = 0.8
		end
		if opts.Pillar and rarity.Order >= 5 then
			-- Glowing ring on the ground under legendary+ lane donuts
			local ring = Instance.new("Part")
			ring.Name = "GroundGlow"
			ring.Shape = Enum.PartType.Cylinder
			ring.Size = Vector3.new(0.15, 6 * s, 6 * s)
			add(ring, CFrame.new(0, bottom + 0.1, 0) * CFrame.Angles(0, 0, math.pi / 2), rarity.Color, Enum.Material.Neon)
			ring.Transparency = 0.5
		end
		if rarity.Float or mutation.Order >= 2 then
			CollectionService:AddTag(model, "DonutFloat")
		end
		if rarity.Rainbow or mutation.Rainbow then
			CollectionService:AddTag(model, "DonutRainbow")
		end

		-- Mystical themes (the moving parts - lightning, magic circles, comets - are client-side)
		local themes = FXThemes.For(rarity.Id, mutation.Id)
		if #themes > 0 then
			CollectionService:AddTag(model, "DonutFX")
			model:SetAttribute("FXScale", s)
			for _, theme in themes do
				local build = themeParts[theme.Id]
				if build then
					build(theme)
				end
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
