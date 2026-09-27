--[[
	DonutModel
	==========
	Builds a donut "character" out of plain parts (no uploaded meshes needed): a ring of dough balls,
	a frosting layer, sprinkles, a face and brainrot accessories (legs, sunglasses, shark fin...).
	Rarer donuts automatically get lights, particles, halos, light pillars and rainbow frosting.

	The model is a single rigid assembly: the invisible "Root" part is anchored and every other part is
	welded to it, so moving Root moves the whole donut (cheap to animate on the client).

	Used by the server (lane spawns, bases, podiums, carried donuts) and the client (Index previews).
]]

local CollectionService = game:GetService("CollectionService")

local Rarities = require(script.Parent.Rarities)
local Format = require(script.Parent.Format)
local Donuts = require(script.Parent.Donuts)

type Donut = Donuts.Donut

local DonutModel = {}

local RING_RADIUS = 1.5
local BALL = 1.6
local SEGMENTS = 10
local FROSTING_OFFSET = -0.28 -- frosting sits on the front face (-Z is the donut's front)
local FROSTING_BALL = BALL * 0.9

export type BuildOptions = {
	Scale: number?,
	Pillar: boolean?, -- tall light pillar (rare lane donuts, so players can spot them from afar)
	NoEffects: boolean?, -- skip lights/particles (viewport previews)
}

local function hashString(text: string): number
	local hash = 7
	for i = 1, #text do
		hash = (hash * 31 + string.byte(text, i)) % 2147483647
	end
	return hash
end

function DonutModel.Build(donut: Donut, options: BuildOptions?): Model
	local opts: BuildOptions = options or {}
	local s = opts.Scale or 1
	local rarity = Rarities.Get(donut.Rarity)
	local rng = Random.new(hashString(donut.Id))
	local partsSet = {}
	for _, name in donut.Parts do
		partsSet[name] = true
	end
	if rarity.Halo then
		partsSet.Halo = true
	end

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

	local function block(size: Vector3, color: Color3, cf: CFrame, material: Enum.Material?, name: string?): BasePart
		local p = Instance.new("Part")
		p.Size = size * s
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

	local function wedge(size: Vector3, color: Color3, cf: CFrame, material: Enum.Material?): BasePart
		local p = Instance.new("WedgePart")
		p.Size = size * s
		p.Name = "Wedge"
		return add(p, cf, color, material)
	end

	local R = RING_RADIUS
	local TOP = R + BALL / 2 -- top of the ring
	local shine = rarity.Shine and 0.12 or 0

	-- Dough ring + frosting
	for i = 0, SEGMENTS - 1 do
		local angle = (i / SEGMENTS) * math.pi * 2
		local x, y = R * math.cos(angle), R * math.sin(angle)
		local dough = ball(BALL, donut.Dough, at(x, y, 0), Enum.Material.SmoothPlastic, "Dough")
		dough.Reflectance = shine * 0.5
		local frosting = ball(FROSTING_BALL, donut.Frosting, at(x, y, FROSTING_OFFSET), Enum.Material.SmoothPlastic, "Frosting")
		frosting.Reflectance = shine
	end

	-- Sprinkles on the frosting (skipping the two balls under the face)
	if donut.Sprinkles then
		local colors = donut.Sprinkles
		local frostRadius = FROSTING_BALL / 2
		for n = 1, 16 do
			local segment
			repeat
				segment = rng:NextInteger(0, SEGMENTS - 1)
			until segment ~= 2 and segment ~= 3
			local angle = (segment / SEGMENTS) * math.pi * 2
			local dx, dy
			repeat
				dx, dy = rng:NextNumber(-0.45, 0.45), rng:NextNumber(-0.45, 0.45)
			until dx * dx + dy * dy < 0.2
			local z = FROSTING_OFFSET - math.sqrt(frostRadius * frostRadius - dx * dx - dy * dy) + 0.04
			local cf = at(R * math.cos(angle) + dx, R * math.sin(angle) + dy, z) * CFrame.Angles(0, 0, rng:NextNumber(0, math.pi * 2))
			block(Vector3.new(0.11, 0.38, 0.11), colors[(n - 1) % #colors + 1], cf, Enum.Material.SmoothPlastic, "Sprinkle")
		end
	end

	-- Face (skipped when something covers the eyes)
	local black = Color3.fromRGB(20, 20, 20)
	local white = Color3.fromRGB(255, 255, 255)
	local eyesCovered = partsSet.Sunglasses or partsSet.Visor
	for _, side in { -1, 1 } do
		ball(0.62, white, at(side * 0.5, TOP - 0.68, -0.95), nil, "Eye")
		if not eyesCovered then
			ball(0.32, black, at(side * 0.47, TOP - 0.7, -1.2), nil, "Pupil")
		end
	end
	if not partsSet.Mustache and not partsSet.Beak then
		block(Vector3.new(0.55, 0.1, 0.1), black, at(0, TOP - 1.22, -0.74) * CFrame.Angles(0, 0, 0), nil, "Mouth")
	end

	-- Brainrot accessories
	local accessories = {}

	function accessories.Legs()
		for _, side in { -1, 1 } do
			cylinder(1.3, 0.38, donut.Dough, at(side * 0.55, -TOP - 0.45, 0))
			block(Vector3.new(0.55, 0.32, 0.8), white, at(side * 0.55, -TOP - 1.12, -0.15), nil, "Shoe")
			block(Vector3.new(0.57, 0.1, 0.82), Color3.fromRGB(230, 40, 40), at(side * 0.55, -TOP - 1.0, -0.15), nil, "ShoeStripe")
		end
	end

	function accessories.Arms()
		for _, side in { -1, 1 } do
			local cf = at(side * (R + 1.05), 0.2, -0.1) * CFrame.Angles(0, 0, side * math.rad(-35))
			cylinder(1.1, 0.3, donut.Dough, cf)
			ball(0.45, white, at(side * (R + 1.4), 0.7, -0.1), nil, "Glove")
		end
	end

	function accessories.Bat()
		cylinder(2.8, 0.4, Color3.fromRGB(150, 100, 55), at(R + 1.5, 0.6, -0.4) * CFrame.Angles(0, 0, math.rad(-20)), Enum.Material.Wood, "Bat")
	end

	function accessories.Tutu()
		cylinder(0.22, 3.6, Color3.fromRGB(255, 170, 220), at(0, -TOP + 0.2, 0), Enum.Material.SmoothPlastic, "Tutu").Transparency = 0.15
	end

	function accessories.Mustache()
		for _, side in { -1, 1 } do
			block(Vector3.new(0.5, 0.2, 0.14), black, at(side * 0.24, TOP - 1.12, -0.82) * CFrame.Angles(0, 0, side * math.rad(-15)), nil, "Mustache")
		end
	end

	function accessories.TopHat()
		cylinder(0.12, 1.9, black, at(0, TOP + 0.06, 0))
		cylinder(1.2, 1.15, black, at(0, TOP + 0.7, 0))
		cylinder(0.25, 1.17, Color3.fromRGB(200, 30, 40), at(0, TOP + 0.3, 0))
	end

	function accessories.Sunglasses()
		for _, side in { -1, 1 } do
			block(Vector3.new(0.62, 0.4, 0.12), black, at(side * 0.48, TOP - 0.68, -1.28), Enum.Material.Glass, "Lens").Reflectance = 0.3
		end
		block(Vector3.new(0.36, 0.08, 0.1), black, at(0, TOP - 0.62, -1.28))
	end

	function accessories.Visor()
		block(Vector3.new(1.9, 0.4, 0.14), Color3.fromRGB(0, 255, 255), at(0, TOP - 0.68, -1.28), Enum.Material.Neon, "Visor")
	end

	function accessories.Camel()
		for _, side in { -1, 1 } do
			ball(1.05, Color3.fromRGB(200, 150, 90), at(side * 0.5, TOP + 0.15, 0.25), nil, "Hump")
		end
	end

	function accessories.SharkFin()
		wedge(Vector3.new(0.3, 1.5, 1.6), Color3.fromRGB(120, 140, 170), at(0, TOP + 0.6, 0.35))
	end

	function accessories.Pharaoh()
		local gold, blue = Color3.fromRGB(255, 200, 40), Color3.fromRGB(30, 60, 180)
		block(Vector3.new(2.2, 0.9, 1.5), gold, at(0, TOP + 0.35, 0.1), Enum.Material.Foil)
		for i, side in { -1, 1 } do
			for j = 0, 2 do
				block(Vector3.new(0.45, 0.5, 1.1), if (i + j) % 2 == 0 then gold else blue, at(side * 1.25, TOP - 0.1 - j * 0.5, 0.1), Enum.Material.SmoothPlastic)
			end
		end
		ball(0.35, Color3.fromRGB(0, 200, 120), at(0, TOP + 0.45, -0.7), Enum.Material.Neon, "Gem")
	end

	function accessories.CoffeeCup()
		cylinder(1.2, 1.3, white, at(0, TOP + 0.55, 0), Enum.Material.SmoothPlastic, "Cup")
		cylinder(0.05, 1.15, Color3.fromRGB(110, 65, 35), at(0, TOP + 1.16, 0), Enum.Material.SmoothPlastic, "Coffee")
		block(Vector3.new(0.2, 0.7, 0.2), white, at(0.8, TOP + 0.55, 0))
	end

	function accessories.MonkeyEars()
		for _, side in { -1, 1 } do
			ball(0.9, Color3.fromRGB(120, 75, 40), at(side * (R + 0.55), 0.9, 0.05), nil, "Ear")
			ball(0.5, Color3.fromRGB(255, 190, 170), at(side * (R + 0.55), 0.9, -0.2), nil, "EarInner")
		end
	end

	function accessories.Horns()
		for _, side in { -1, 1 } do
			block(Vector3.new(0.35, 0.7, 0.35), Color3.fromRGB(240, 230, 200), at(side * 0.95, TOP + 0.2, -0.05) * CFrame.Angles(0, 0, side * math.rad(-25)))
			block(Vector3.new(0.22, 0.5, 0.22), Color3.fromRGB(240, 230, 200), at(side * 1.18, TOP + 0.65, -0.05) * CFrame.Angles(0, 0, side * math.rad(-45)))
		end
	end

	function accessories.PlaneWings()
		local grey = Color3.fromRGB(110, 125, 110)
		block(Vector3.new(6, 0.2, 1.3), grey, at(0, 0, 0.3), Enum.Material.Metal, "Wing")
		for _, side in { -1, 1 } do
			cylinder(1.2, 0.55, Color3.fromRGB(80, 80, 80), at(side * 2.3, -0.4, 0.1) * CFrame.Angles(math.pi / 2, 0, 0), Enum.Material.Metal, "Engine")
		end
		block(Vector3.new(0.2, 1.1, 0.9), grey, at(0, TOP + 0.4, 0.5), Enum.Material.Metal, "Tail")
	end

	function accessories.Crown()
		local gold = Color3.fromRGB(255, 205, 50)
		cylinder(0.4, 1.6, gold, at(0, TOP + 0.15, 0), Enum.Material.Foil, "Crown")
		for i = 0, 4 do
			local angle = i / 5 * math.pi * 2
			block(Vector3.new(0.22, 0.5, 0.22), gold, at(math.cos(angle) * 0.65, TOP + 0.55, math.sin(angle) * 0.65), Enum.Material.Foil, "Crown")
		end
		ball(0.3, Color3.fromRGB(255, 30, 60), at(0, TOP + 0.15, -0.8), Enum.Material.Neon, "Gem")
	end

	function accessories.Halo()
		local color = Color3.fromRGB(255, 240, 150)
		for i = 0, 11 do
			local angle = i / 12 * math.pi * 2
			ball(0.32, color, at(math.cos(angle) * 0.95, TOP + 1.0, math.sin(angle) * 0.95), Enum.Material.Neon, "Halo")
		end
	end

	function accessories.Wings()
		local material = if rarity.Order >= 8 then Enum.Material.Neon else Enum.Material.SmoothPlastic
		local color = if rarity.Order >= 8 then rarity.Color:Lerp(white, 0.6) else white
		for _, side in { -1, 1 } do
			for f = 0, 2 do
				block(
					Vector3.new(2.3 - f * 0.4, 0.8, 0.15),
					color,
					at(side * (R + 1.0 + f * 0.15), 0.9 - f * 0.55, 0.6) * CFrame.Angles(0, side * math.rad(-20), side * math.rad(25 - f * 12)),
					material,
					"Wing"
				)
			end
		end
	end

	function accessories.Flames()
		local holder = block(Vector3.new(1, 1, 1), white, at(0, TOP + 0.3, 0), nil, "FlameHolder")
		holder.Transparency = 1
		local fire = Instance.new("Fire")
		fire.Size = 3 * s
		fire.Heat = 6
		fire.Color = Color3.fromRGB(255, 120, 20)
		fire.SecondaryColor = Color3.fromRGB(255, 220, 60)
		fire.Parent = holder
	end

	function accessories.IceSpikes()
		local ice = Color3.fromRGB(170, 230, 255)
		for i = -2, 2 do
			block(Vector3.new(0.3, 0.9 - math.abs(i) * 0.15, 0.3), ice, at(i * 0.4, TOP + 0.3, 0) * CFrame.Angles(0, 0, math.rad(i * -12)), Enum.Material.Glass, "Spike")
		end
	end

	function accessories.Beak()
		wedge(Vector3.new(0.6, 0.35, 0.6), Color3.fromRGB(255, 160, 20), at(0, TOP - 1.1, -1.1) * CFrame.Angles(0, math.pi, 0))
	end

	function accessories.Antenna()
		block(Vector3.new(0.1, 1.2, 0.1), Color3.fromRGB(80, 80, 90), at(0, TOP + 0.55, 0), Enum.Material.Metal)
		ball(0.4, Color3.fromRGB(255, 40, 40), at(0, TOP + 1.2, 0), Enum.Material.Neon, "AntennaTip")
	end

	function accessories.Cape()
		block(Vector3.new(2.8, 3.2, 0.1), Color3.fromRGB(200, 30, 40), at(0, -0.4, 1.0) * CFrame.Angles(math.rad(-8), 0, 0), Enum.Material.Fabric, "Cape")
	end

	function accessories.Orbit()
		local colors = { Color3.fromRGB(255, 200, 80), Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 120, 255) }
		for i = 1, 3 do
			local angle = i / 3 * math.pi * 2
			ball(0.5, colors[i], at(math.cos(angle) * (R + 1.7), math.sin(angle * 2) * 0.6, math.sin(angle) * (R + 1.7)), Enum.Material.Neon, "Orbit")
		end
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
		if p:IsA("BasePart") and p ~= root and p.Transparency < 1 then
			local cf, size = p.CFrame, p.Size
			local half = math.abs(cf.RightVector.Y) * size.X / 2 + math.abs(cf.UpVector.Y) * size.Y / 2 + math.abs(cf.LookVector.Y) * size.Z / 2
			top = math.max(top, cf.Position.Y + half)
			bottom = math.min(bottom, cf.Position.Y - half)
		end
	end
	model:SetAttribute("DonutId", donut.Id)
	model:SetAttribute("Rarity", donut.Rarity)
	model:SetAttribute("Top", top)
	model:SetAttribute("Bottom", -bottom)

	-- Rarity effects
	if not opts.NoEffects then
		if rarity.Light then
			local light = Instance.new("PointLight")
			light.Color = rarity.Color
			light.Brightness = 1.5
			light.Range = rarity.Light * s
			light.Shadows = false
			light.Parent = root
		end
		if rarity.Particles then
			local emitter = Instance.new("ParticleEmitter")
			emitter.Color = ColorSequence.new(rarity.Color, Color3.new(1, 1, 1))
			emitter.LightEmission = 1
			emitter.Rate = rarity.Particles
			emitter.Lifetime = NumberRange.new(1, 1.8)
			emitter.Speed = NumberRange.new(1 * s, 3 * s)
			emitter.SpreadAngle = Vector2.new(180, 180)
			emitter.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.35 * s),
				NumberSequenceKeypoint.new(1, 0),
			})
			emitter.Transparency = NumberSequence.new(0.1, 1)
			emitter.Parent = root
		end
		if opts.Pillar and rarity.Beam then
			local pillar = Instance.new("Part")
			pillar.Name = "Pillar"
			pillar.Shape = Enum.PartType.Cylinder
			pillar.Size = Vector3.new(60, 3.5, 3.5)
			-- `bottom` is the lowest point of the donut, so the pillar starts at the ground.
			local pillarCf = CFrame.new(0, bottom + 30, 0) * CFrame.Angles(0, 0, math.pi / 2)
			add(pillar, pillarCf, rarity.Color, Enum.Material.Neon)
			pillar.Transparency = 0.8
		end
		if rarity.Float then
			CollectionService:AddTag(model, "DonutFloat")
		end
		if rarity.Rainbow then
			CollectionService:AddTag(model, "DonutRainbow")
		end
	end

	return model
end

-- Place a built donut so its lowest point rests on `surface` (a CFrame on top of a pedestal etc.).
function DonutModel.PlaceOn(model: Model, surface: CFrame)
	local bottom = (model:GetAttribute("Bottom") :: number?) or 0
	model:PivotTo(surface * CFrame.new(0, bottom, 0))
end

-- Floating label like: "Epic" / "Silver Tob Tobi" / "$344/s" / "Lv. 3"
function DonutModel.CreateBillboard(donut: Donut, income: number, level: number?, top: number): BillboardGui
	local rarity = Rarities.Get(donut.Rarity)

	local gui = Instance.new("BillboardGui")
	gui.Name = "DonutInfo"
	gui.Size = UDim2.new(9, 0, if level then 4.2 else 3.4, 0)
	gui.StudsOffsetWorldSpace = Vector3.new(0, top + (if level then 2.4 else 2), 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = gui

	local function line(name: string, text: string, color: Color3, height: number, order: number): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, height)
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

	local rarityLabel = line("Rarity", rarity.Id, rarity.Color, 0.26, 1)
	if rarity.Rainbow then
		CollectionService:AddTag(rarityLabel, "RainbowText")
	end
	line("DonutName", donut.Name, Color3.new(1, 1, 1), 0.27, 2)
	line("Income", Format.Money(income) .. "/s", Color3.fromRGB(90, 255, 90), 0.27, 3)
	if level then
		line("Level", "Lv. " .. level, Color3.fromRGB(255, 220, 90), 0.2, 4)
	end

	return gui
end

return DonutModel
