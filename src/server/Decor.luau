--[[
	Decor: themed decoration for each area. Everything here is cosmetic and non-collidable so it
	never blocks players or the guard. The lane centre (|X| < ~44) is kept mostly clear.

	Areas get more magical the further you go: plain grass -> desert -> candy -> caves -> ice ->
	lava -> neon night city -> floating crystals -> a cosmic dimension. World 2 (The Underworld) goes
	ember gates -> brimstone bakery -> magma rivers -> soul caverns -> obsidian forge -> inferno
	spires -> the molten core,
	World 3 (Dream Dimension) clouds -> toy factory -> haunted bakery -> clockwork void -> donut heaven
	-> starfall garden -> aurora palace, and World 4 (Cyber City) neon streets -> hologram mall ->
	robot factory -> data highway -> firewall fortress -> glitch zone -> the mainframe.
	World 1 also ends with candy cane canyon -> rainbow sprinkle summit.
]]

local CollectionService = game:GetService("CollectionService")

local Build = require(script.Parent.Build)
local BlackHoleModel = require(script.Parent.BlackHoleModel)
local Areas = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Areas"))

local Decor = {}

local rgb = Color3.fromRGB

-- The themes are laid out for a lane DESIGN_HALF studs either side of the middle (MapBuilder moves
-- what stands by the walls out to the real walls afterwards). Things that span the whole lane - cave
-- ceilings, bridges, a rainbow - are built for the real width (`laneHalf`, set by BuildTheme), inside
-- a Model centred on the lane so MapBuilder leaves them where they are.
local DESIGN_HALF = 60
local laneHalf = DESIGN_HALF
local WALL_HEIGHT = 60 -- (Config.Map.LaneWallHeight)

--------------------------------------------------------------------------------
-- Reusable props
--------------------------------------------------------------------------------
function Decor.GiantDonut(parent: Instance, cf: CFrame, radius: number, ball: number, dough: Color3, frosting: Color3, sprinkles: { Color3 }?, material: Enum.Material?): Model
	local model = Instance.new("Model")
	model.Name = "GiantDonut"
	local segments = 14
	for i = 0, segments - 1 do
		local angle = i / segments * math.pi * 2
		local offset = Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius, 0)
		Build.Decor({ Parent = model, Name = "Dough", Shape = Enum.PartType.Ball, Size = Vector3.one * ball, CFrame = cf * CFrame.new(offset), Color = dough, Material = Enum.Material.SmoothPlastic })
		Build.Decor({ Parent = model, Name = "Frosting", Shape = Enum.PartType.Ball, Size = Vector3.one * ball * 0.9, CFrame = cf * CFrame.new(offset + Vector3.new(0, 0, -ball * 0.18)), Color = frosting, Material = material or Enum.Material.SmoothPlastic })
	end
	if sprinkles then
		local rng = Random.new(math.floor(cf.Position.Magnitude))
		for n = 1, 40 do
			local angle = rng:NextNumber(0, math.pi * 2)
			local r = radius + rng:NextNumber(-ball * 0.3, ball * 0.3)
			local pos = Vector3.new(math.cos(angle) * r, math.sin(angle) * r, -ball * 0.62)
			Build.Decor({
				Parent = model, Name = "Sprinkle",
				Size = Vector3.new(ball * 0.07, ball * 0.25, ball * 0.07),
				CFrame = cf * CFrame.new(pos) * CFrame.Angles(0, 0, rng:NextNumber(0, math.pi * 2)),
				Color = sprinkles[(n - 1) % #sprinkles + 1], Material = Enum.Material.SmoothPlastic,
			})
		end
	end
	model.Parent = parent
	return model
end

-- Giant donut standing on the floor at `position`, facing -Z (towards the hub).
function Decor.DonutStatue(parent: Instance, position: Vector3, size: number, dough: Color3, frosting: Color3, sprinkles: { Color3 }?, material: Enum.Material?)
	local radius, ball = size, size * 0.9
	Build.Decor({ Parent = parent, Name = "StatueBase", Size = Vector3.new(size * 2.2, 1.5, size * 1.6), Position = position + Vector3.new(0, 0.75, 0), Color = rgb(235, 235, 235), Material = Enum.Material.Marble })
	local cf = CFrame.new(position + Vector3.new(0, 1.5 + radius + ball / 2 - ball * 0.25, 0))
	return Decor.GiantDonut(parent, cf, radius, ball, dough, frosting, sprinkles, material)
end

local function bush(parent: Instance, pos: Vector3, color: Color3, rng: Random)
	local w = rng:NextNumber(5, 8)
	Build.Decor({ Parent = parent, Name = "Bush", Size = Vector3.new(w, 3, w), Position = pos + Vector3.new(0, 1.5, 0), Color = color, Material = Enum.Material.Plastic, TopSurface = Enum.SurfaceType.Studs })
	Build.Decor({ Parent = parent, Name = "Bush", Size = Vector3.new(w * 0.6, 2.5, w * 0.6), Position = pos + Vector3.new(rng:NextNumber(-1, 1), 4.25, rng:NextNumber(-1, 1)), Color = color:Lerp(Color3.new(0, 0, 0), 0.08), Material = Enum.Material.Plastic, TopSurface = Enum.SurfaceType.Studs })
end

local FLOWER_COLORS = { rgb(255, 90, 90), rgb(255, 220, 60), rgb(255, 255, 255), rgb(200, 120, 255), rgb(255, 150, 200) }

local function flower(parent: Instance, pos: Vector3, rng: Random)
	Build.Decor({ Parent = parent, Name = "Stem", Size = Vector3.new(0.2, 1.2, 0.2), Position = pos + Vector3.new(0, 0.6, 0), Color = rgb(60, 160, 50) })
	Build.Ball(parent, pos + Vector3.new(0, 1.3, 0), 0.7, FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)])
end

local function tree(parent: Instance, pos: Vector3, trunk: Color3, leaves: Color3, sprinkles: { Color3 }?, rng: Random)
	local height = rng:NextNumber(9, 13)
	Build.Pillar(parent, pos, height, 2, trunk, Enum.Material.Wood)
	local size = rng:NextNumber(9, 12)
	local center = pos + Vector3.new(0, height + size * 0.3, 0)
	Build.Ball(parent, center, size, leaves)
	if sprinkles then
		for n = 1, 14 do
			local dir = rng:NextUnitVector()
			if dir.Y < -0.2 then
				dir = Vector3.new(dir.X, -dir.Y, dir.Z)
			end
			Build.Decor({ Parent = parent, Name = "Sprinkle", Size = Vector3.new(0.4, 1.3, 0.4), CFrame = CFrame.lookAt(center + dir * size * 0.5, center + dir * size) * CFrame.Angles(math.pi / 2, 0, 0), Color = sprinkles[(n - 1) % #sprinkles + 1] })
		end
	end
end

local function cactus(parent: Instance, pos: Vector3, rng: Random)
	local green = rgb(70, 160, 70)
	local h = rng:NextNumber(7, 11)
	Build.Decor({ Parent = parent, Name = "Cactus", Size = Vector3.new(2, h, 2), Position = pos + Vector3.new(0, h / 2, 0), Color = green, Material = Enum.Material.Grass })
	for _, side in { -1, 1 } do
		local armY = rng:NextNumber(h * 0.35, h * 0.65)
		Build.Decor({ Parent = parent, Name = "Cactus", Size = Vector3.new(2, 1.4, 1.4), Position = pos + Vector3.new(side * 1.9, armY, 0), Color = green, Material = Enum.Material.Grass })
		Build.Decor({ Parent = parent, Name = "Cactus", Size = Vector3.new(1.4, 3, 1.4), Position = pos + Vector3.new(side * 2.5, armY + 1.4, 0), Color = green, Material = Enum.Material.Grass })
	end
	Build.Ball(parent, pos + Vector3.new(0, h + 0.3, 0), 1, rgb(255, 120, 180))
end

local function candyCane(parent: Instance, pos: Vector3)
	local red, white = rgb(230, 30, 40), rgb(255, 255, 255)
	for i = 0, 9 do
		Build.Decor({ Parent = parent, Name = "Cane", Size = Vector3.new(1.4, 1.2, 1.4), Position = pos + Vector3.new(0, 0.6 + i * 1.2, 0), Color = if i % 2 == 0 then red else white, Material = Enum.Material.SmoothPlastic })
	end
	-- the hook: an arc from the top of the stick over and down (every block touching the last)
	for i = 0, 5 do
		local angle = i / 5 * math.pi
		Build.Decor({ Parent = parent, Name = "Cane", Size = Vector3.new(1.4, 1.4, 1.4), Position = pos + Vector3.new(1.6 - math.cos(angle) * 1.6, 12.2 + math.sin(angle) * 1.5, 0), Color = if i % 2 == 0 then red else white, Material = Enum.Material.SmoothPlastic })
	end
	Build.Decor({ Parent = parent, Name = "Cane", Size = Vector3.new(1.4, 1.4, 1.4), Position = pos + Vector3.new(3.2, 11, 0), Color = red, Material = Enum.Material.SmoothPlastic })
end

local function crystal(parent: Instance, pos: Vector3, color: Color3, size: number, rng: Random, light: boolean?)
	for n = 1, 3 do
		local h = size * rng:NextNumber(0.6, 1.2)
		local part = Build.Decor({
			Parent = parent, Name = "Crystal",
			Size = Vector3.new(size * 0.35, h, size * 0.35),
			CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-1, 1) * size * 0.25, h * 0.4, rng:NextNumber(-1, 1) * size * 0.25))
				* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, math.pi), rng:NextNumber(-0.4, 0.4)),
			Color = color, Material = Enum.Material.Glass, Transparency = 0.2,
		})
		if light and n == 1 then
			local pointLight = Instance.new("PointLight")
			pointLight.Color = color
			pointLight.Range = size * 2
			pointLight.Brightness = 2
			pointLight.Parent = part
		end
	end
end

local function lamp(parent: Instance, pos: Vector3, color: Color3, height: number?)
	local h = height or 10
	Build.Pillar(parent, pos, h, 0.6, rgb(40, 40, 45), Enum.Material.Metal)
	local bulb = Build.Ball(parent, pos + Vector3.new(0, h + 0.6, 0), 1.6, color, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 18
	light.Brightness = 1.5
	light.Parent = bulb
end

local function ringOfBalls(parent: Instance, cf: CFrame, radius: number, ballSize: number, color: Color3, count: number, tag: string?): Model
	local model = Instance.new("Model")
	model.Name = "Ring"
	local center = Build.Decor({ Parent = model, Name = "Center", Size = Vector3.one, CFrame = cf, Transparency = 1 })
	for i = 0, count - 1 do
		local angle = i / count * math.pi * 2
		Build.Decor({ Parent = model, Name = "RingBall", Shape = Enum.PartType.Ball, Size = Vector3.one * ballSize, CFrame = cf * CFrame.new(math.cos(angle) * radius, math.sin(angle) * radius, 0), Color = color, Material = Enum.Material.Neon })
	end
	model.PrimaryPart = center :: BasePart
	if tag then
		CollectionService:AddTag(model, tag)
	end
	model.Parent = parent
	return model
end

-- Particle "weather" across a whole area (snow, embers, stars...).
local function weather(parent: Instance, zs: number, ze: number, color: Color3, direction: Enum.NormalId, rate: number, speed: number, size: number, lifetime: number)
	local emitterPart = Build.Decor({
		Parent = parent, Name = "Weather",
		Size = Vector3.new(110, 1, ze - zs),
		Position = Vector3.new(0, if direction == Enum.NormalId.Bottom then 45 else 1, (zs + ze) / 2),
		Transparency = 1,
	})
	local emitter = Instance.new("ParticleEmitter")
	emitter.EmissionDirection = direction
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.8
	emitter.Rate = rate
	emitter.Speed = NumberRange.new(speed * 0.6, speed)
	emitter.Lifetime = NumberRange.new(lifetime * 0.7, lifetime)
	emitter.SpreadAngle = Vector2.new(15, 15)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 0.4) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.1), NumberSequenceKeypoint.new(1, 1) })
	emitter.Parent = emitterPart
end

-- Calls fn(position, side) along both lane edges.
local function alongEdges(zs: number, ze: number, step: number, rng: Random, fn: (Vector3, number) -> ())
	local z = zs + 12
	while z < ze - 8 do
		for _, side in { -1, 1 } do
			fn(Vector3.new(side * rng:NextNumber(47, 54), 0, z + rng:NextNumber(-3, 3)), side)
		end
		z += step
	end
end

-- Random points in the playable middle (for small, walk-through clutter).
local function scatter(zs: number, ze: number, count: number, rng: Random, fn: (Vector3) -> ())
	for _ = 1, count do
		fn(Vector3.new(rng:NextNumber(-44, 44), 0, rng:NextNumber(zs + 8, ze - 8)))
	end
end

--------------------------------------------------------------------------------
-- Themes
--------------------------------------------------------------------------------
local Themes = {}

function Themes.Meadow(folder: Instance, zs: number, ze: number, rng: Random)
	alongEdges(zs, ze, 22, rng, function(pos)
		bush(folder, pos, rgb(75, 170, 55), rng)
	end)
	scatter(zs, ze, 30, rng, function(pos)
		flower(folder, pos, rng)
	end)
	for _, side in { -1, 1 } do
		Build.Decor({ Parent = folder, Name = "Bamboo", Size = Vector3.new(0.6, 9, 0.6), Position = Vector3.new(side * 30, 4.5, zs + 120), Color = rgb(60, 170, 70), Material = Enum.Material.Grass })
	end
	Decor.DonutStatue(folder, Vector3.new(-50, 0, zs + 130), 4, rgb(222, 165, 95), rgb(255, 170, 210), { rgb(255, 60, 60), rgb(60, 200, 255), rgb(255, 230, 60) })
end

function Themes.Park(folder: Instance, zs: number, ze: number, rng: Random)
	local sprinkles = { rgb(255, 60, 60), rgb(255, 230, 60), rgb(60, 200, 255), rgb(255, 255, 255) }
	alongEdges(zs, ze, 30, rng, function(pos, side)
		tree(folder, pos, rgb(120, 80, 45), if side < 0 then rgb(255, 150, 200) else rgb(120, 220, 110), sprinkles, rng)
	end)
	for z = zs + 30, ze - 20, 45 do
		lamp(folder, Vector3.new(-44, 0, z), rgb(255, 240, 200))
		lamp(folder, Vector3.new(44, 0, z + 20), rgb(255, 240, 200))
	end
	scatter(zs, ze, 25, rng, function(pos)
		flower(folder, pos, rng)
	end)
	Decor.DonutStatue(folder, Vector3.new(50, 0, zs + 70), 5, rgb(222, 165, 95), rgb(255, 255, 255), sprinkles)
end

function Themes.Desert(folder: Instance, zs: number, ze: number, rng: Random)
	alongEdges(zs, ze, 26, rng, function(pos)
		cactus(folder, pos, rng)
	end)
	-- Sugar-cube pyramid
	local base = Vector3.new(-40, 0, zs + 105)
	for level = 0, 5 do
		local w = 22 - level * 3.6
		Build.Decor({ Parent = folder, Name = "SugarPyramid", Size = Vector3.new(w, 2.4, w), Position = base + Vector3.new(0, 1.2 + level * 2.4, 0), Color = if level % 2 == 0 then rgb(250, 245, 230) else rgb(240, 225, 190), Material = Enum.Material.Sandstone })
	end
	for n = 1, 12 do
		Build.Decor({ Parent = folder, Name = "SugarCube", Size = Vector3.one * 1.4, CFrame = CFrame.new(rng:NextNumber(-44, 44), 0.7, rng:NextNumber(zs + 8, ze - 8)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color = rgb(255, 255, 255), Material = Enum.Material.Sand })
	end
	Decor.DonutStatue(folder, Vector3.new(48, 0, zs + 40), 4.5, rgb(200, 140, 70), rgb(240, 222, 190), nil, Enum.Material.Sandstone)
end

function Themes.Frosting(folder: Instance, zs: number, ze: number, rng: Random)
	alongEdges(zs, ze, 24, rng, function(pos)
		candyCane(folder, pos)
	end)
	local gumdrops = { rgb(255, 60, 90), rgb(90, 220, 90), rgb(255, 200, 40), rgb(120, 120, 255), rgb(255, 130, 40) }
	scatter(zs, ze, 18, rng, function(pos)
		Build.Ball(folder, pos + Vector3.new(0, 0.4, 0), rng:NextNumber(1.6, 2.6), gumdrops[rng:NextInteger(1, #gumdrops)], Enum.Material.Glass).Transparency = 0.1
	end)
	-- Icing waterfalls pouring down both walls
	for _, side in { -1, 1 } do
		local z = zs + 60 + (side + 1) * 25
		local fall = Build.Decor({ Parent = folder, Name = "IcingFall", Size = Vector3.new(1, 58, 16), Position = Vector3.new(side * 59.4, 29, z), Color = if side < 0 then rgb(255, 170, 215) else rgb(150, 220, 255), Material = Enum.Material.Glass, Transparency = 0.15 })
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(fall.Color)
		emitter.Rate = 25
		emitter.Speed = NumberRange.new(3, 6)
		emitter.Lifetime = NumberRange.new(1, 2)
		emitter.Size = NumberSequence.new(1.2, 0)
		emitter.EmissionDirection = Enum.NormalId.Bottom
		emitter.Parent = fall
		Build.Decor({ Parent = folder, Name = "IcingPool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 22, 22), CFrame = CFrame.new(side * 52, 0.2, z) * CFrame.Angles(0, 0, math.pi / 2), Color = fall.Color, Material = Enum.Material.Glass, Transparency = 0.1 })
	end
	Decor.DonutStatue(folder, Vector3.new(-48, 0, zs + 30), 5, rgb(222, 165, 95), rgb(255, 100, 160), { rgb(255, 255, 255), rgb(255, 230, 60) })
end

function Themes.Chocolate(folder: Instance, zs: number, ze: number, rng: Random)
	local choc = { rgb(95, 55, 35), rgb(75, 42, 25), rgb(115, 70, 45) }
	alongEdges(zs, ze, 18, rng, function(pos)
		local h = rng:NextNumber(8, 16)
		for level = 0, 3 do
			local w = 5 - level * 1.1
			Build.Decor({ Parent = folder, Name = "Stalagmite", Size = Vector3.new(w, h / 4, w), CFrame = CFrame.new(pos + Vector3.new(0, h / 8 + level * h / 4, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color = choc[rng:NextInteger(1, #choc)], Material = Enum.Material.Slate })
		end
	end)
	-- Glowing mushrooms light the cave
	scatter(zs, ze, 10, rng, function(pos)
		local p = Vector3.new(math.sign(pos.X) * rng:NextNumber(36, 44), 0, pos.Z)
		Build.Pillar(folder, p, 2.5, 0.8, rgb(240, 230, 210))
		local cap = Build.Ball(folder, p + Vector3.new(0, 2.7, 0), 3, rgb(255, 170, 60), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = rgb(255, 170, 60)
		light.Range = 22
		light.Brightness = 2
		light.Parent = cap
	end)
	-- The cave ceiling: thick rock beams from wall to wall (sunk into the tops of the walls, with a
	-- bracket of rock under each end), big stalactites hanging from them
	for z = zs + 12, ze - 12, 24 do
		local ceiling = Instance.new("Model")
		ceiling.Name = "CaveCeiling"
		local span = laneHalf * 2 + 8
		Build.Decor({ Parent = ceiling, Name = "CaveBeam", Size = Vector3.new(span, 6, 10), Position = Vector3.new(0, WALL_HEIGHT - 3, z), Color = rgb(70, 40, 25), Material = Enum.Material.Rock })
		for _, side in { -1, 1 } do
			Build.Decor({ Parent = ceiling, Name = "CaveBracket", Size = Vector3.new(6, 10, 9), CFrame = CFrame.new(side * (laneHalf - 2), WALL_HEIGHT - 9, z) * CFrame.Angles(0, 0, side * 0.35), Color = rgb(80, 46, 28), Material = Enum.Material.Rock })
		end
		local x = -laneHalf + rng:NextNumber(8, 16)
		while x < laneHalf - 8 do
			local width = rng:NextNumber(3, 5.5)
			local length = rng:NextNumber(8, 17)
			local top = WALL_HEIGHT - 6
			for level = 0, 2 do
				local w = width * (1 - level * 0.3)
				local h = length / 3
				Build.Decor({ Parent = ceiling, Name = "Stalactite", Size = Vector3.new(w, h + 0.4, w), CFrame = CFrame.new(x, top - h / 2 - level * h, z + rng:NextNumber(-1.5, 1.5) * level * 0.3) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color = choc[rng:NextInteger(1, #choc)], Material = Enum.Material.Slate })
			end
			x += rng:NextNumber(20, 34)
		end
		ceiling.Parent = folder
	end
	Decor.DonutStatue(folder, Vector3.new(50, 0, zs + 120), 5, rgb(110, 60, 35), rgb(70, 40, 25), { rgb(255, 215, 60) })
end

function Themes.Ice(folder: Instance, zs: number, ze: number, rng: Random)
	alongEdges(zs, ze, 16, rng, function(pos)
		crystal(folder, pos, rgb(150, 220, 255), rng:NextNumber(5, 9), rng, rng:NextNumber() < 0.3)
	end)
	scatter(zs, ze, 12, rng, function(pos)
		Build.Ball(folder, pos, rng:NextNumber(2, 4), rgb(250, 252, 255), Enum.Material.Snow)
	end)
	-- Snowmen
	for _, p in { Vector3.new(-38, 0, zs + 50), Vector3.new(38, 0, zs + 115) } do
		Build.Ball(folder, p + Vector3.new(0, 2.2, 0), 5, rgb(250, 252, 255), Enum.Material.Snow)
		Build.Ball(folder, p + Vector3.new(0, 5.6, 0), 3.6, rgb(250, 252, 255), Enum.Material.Snow)
		Build.Ball(folder, p + Vector3.new(0, 8.2, 0), 2.6, rgb(250, 252, 255), Enum.Material.Snow)
		Build.Decor({ Parent = folder, Name = "Nose", Size = Vector3.new(0.4, 0.4, 1.2), Position = p + Vector3.new(0, 8.2, -1.6), Color = rgb(255, 140, 0) })
	end
	weather(folder, zs, ze, rgb(255, 255, 255), Enum.NormalId.Bottom, 60, 8, 0.6, 7)
	Decor.DonutStatue(folder, Vector3.new(-50, 0, zs + 90), 5, rgb(200, 230, 255), rgb(255, 255, 255), { rgb(120, 200, 255) }, Enum.Material.Ice)
end

function Themes.Lava(folder: Instance, zs: number, ze: number, rng: Random)
	alongEdges(zs, ze, 30, rng, function(pos)
		local pool = Build.Decor({ Parent = folder, Name = "LavaPool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 12, 12), CFrame = CFrame.new(pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(255, 90, 0), Material = Enum.Material.Neon })
		local fire = Instance.new("Fire")
		fire.Size = 8
		fire.Heat = 12
		fire.Parent = pool
		for n = 1, 3 do
			Build.Decor({ Parent = folder, Name = "Basalt", Size = Vector3.new(3, rng:NextNumber(2, 5), 3), CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-6, 6), 1.5, rng:NextNumber(-6, 6))) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 3), 0), Color = rgb(40, 35, 35), Material = Enum.Material.Basalt })
		end
	end)
	-- Bakery ovens
	for _, p in { Vector3.new(-46, 0, zs + 55), Vector3.new(46, 0, zs + 105) } do
		Build.Decor({ Parent = folder, Name = "Oven", Size = Vector3.new(10, 9, 9), Position = p + Vector3.new(0, 4.5, 0), Color = rgb(70, 65, 65), Material = Enum.Material.Brick })
		local window = Build.Decor({ Parent = folder, Name = "OvenGlow", Size = Vector3.new(6, 3.5, 0.4), Position = p + Vector3.new(0, 4, -4.6), Color = rgb(255, 120, 20), Material = Enum.Material.Neon })
		local light = Instance.new("PointLight")
		light.Color = rgb(255, 120, 20)
		light.Range = 25
		light.Brightness = 3
		light.Parent = window
		local chimney = Build.Decor({ Parent = folder, Name = "Chimney", Size = Vector3.new(2.5, 8, 2.5), Position = p + Vector3.new(2.5, 13, 2), Color = rgb(60, 55, 55), Material = Enum.Material.Brick })
		local smoke = Instance.new("Smoke")
		smoke.Color = rgb(80, 70, 70)
		smoke.RiseVelocity = 6
		smoke.Size = 3
		smoke.Parent = chimney
	end
	weather(folder, zs, ze, rgb(255, 140, 30), Enum.NormalId.Top, 40, 6, 0.35, 5)
	Decor.DonutStatue(folder, Vector3.new(-48, 0, zs + 135), 5, rgb(60, 40, 35), rgb(255, 90, 0), { rgb(255, 220, 60) }, Enum.Material.Neon)
end

function Themes.Neon(folder: Instance, zs: number, ze: number, rng: Random)
	local neon = { rgb(0, 255, 220), rgb(255, 0, 200), rgb(255, 240, 0), rgb(120, 80, 255) }
	-- Tall buildings along the walls
	for z = zs + 10, ze - 10, 26 do
		for _, side in { -1, 1 } do
			local h = rng:NextNumber(25, 55)
			local x = side * 53
			Build.Decor({ Parent = folder, Name = "Building", Size = Vector3.new(12, h, 20), Position = Vector3.new(x, h / 2, z), Color = rgb(20, 18, 30), Material = Enum.Material.Metal })
			local color = neon[rng:NextInteger(1, #neon)]
			for y = 6, h - 4, 6 do
				Build.Decor({ Parent = folder, Name = "Window", Size = Vector3.new(0.3, 1.2, 16), Position = Vector3.new(x - side * 6.1, y, z), Color = color, Material = Enum.Material.Neon })
			end
		end
	end
	-- Neon arches over the lane
	for z = zs + 40, ze - 20, 60 do
		local color = neon[rng:NextInteger(1, #neon)]
		for _, side in { -1, 1 } do
			Build.Decor({ Parent = folder, Name = "ArchLeg", Size = Vector3.new(1, 30, 1), Position = Vector3.new(side * 45, 15, z), Color = color, Material = Enum.Material.Neon })
		end
		Build.Decor({ Parent = folder, Name = "ArchTop", Size = Vector3.new(91, 1, 1), Position = Vector3.new(0, 30, z), Color = color, Material = Enum.Material.Neon })
	end
	for z = zs + 20, ze - 10, 40 do
		lamp(folder, Vector3.new(-42, 0, z), neon[1], 12)
		lamp(folder, Vector3.new(42, 0, z + 20), neon[2], 12)
	end
	-- Floating neon donut sign
	ringOfBalls(folder, CFrame.new(0, 42, zs + 110), 8, 2.2, neon[2], 18, "SpinSlow")
end

function Themes.Crystal(folder: Instance, zs: number, ze: number, rng: Random)
	local colors = { rgb(190, 120, 255), rgb(120, 200, 255), rgb(255, 150, 255) }
	alongEdges(zs, ze, 18, rng, function(pos)
		crystal(folder, pos, colors[rng:NextInteger(1, #colors)], rng:NextNumber(7, 13), rng, true)
	end)
	-- Floating crystals that slowly spin
	for n = 1, 8 do
		local color = colors[rng:NextInteger(1, #colors)]
		local model = Instance.new("Model")
		model.Name = "FloatingCrystal"
		local part = Build.Decor({ Parent = model, Name = "Crystal", Size = Vector3.new(3, 7, 3), CFrame = CFrame.new(rng:NextNumber(-45, 45), rng:NextNumber(18, 38), rng:NextNumber(zs + 10, ze - 10)) * CFrame.Angles(0.3, 0, 0.3), Color = color, Material = Enum.Material.Neon, Transparency = 0.1 })
		model.PrimaryPart = part
		CollectionService:AddTag(model, "SpinSlow")
		model.Parent = folder
	end
	weather(folder, zs, ze, rgb(220, 180, 255), Enum.NormalId.Top, 35, 2, 0.5, 8)
	Decor.DonutStatue(folder, Vector3.new(48, 0, zs + 40), 6, rgb(90, 50, 160), rgb(200, 150, 255), { rgb(255, 255, 255) }, Enum.Material.Glass)
end

function Themes.Celestial(folder: Instance, zs: number, ze: number, rng: Random)
	-- Rainbow pillars along the edges
	for z = zs + 12, ze - 8, 22 do
		for _, side in { -1, 1 } do
			local pillar = Build.Pillar(folder, Vector3.new(side * 52, 0, z), 45, 4, rgb(255, 0, 0), Enum.Material.Neon)
			CollectionService:AddTag(pillar, "RainbowPart")
			Build.Ball(folder, Vector3.new(side * 52, 47, z), 5, rgb(255, 255, 255), Enum.Material.Neon)
		end
	end
	-- Floating halo rings and orbs
	for n = 1, 5 do
		ringOfBalls(folder, CFrame.new(rng:NextNumber(-35, 35), rng:NextNumber(20, 40), rng:NextNumber(zs + 15, ze - 15)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), 0), rng:NextNumber(4, 7), 1.2, rgb(255, 240, 150), 16, "SpinSlow")
	end
	for n = 1, 10 do
		local orb = Build.Ball(folder, Vector3.new(rng:NextNumber(-45, 45), rng:NextNumber(10, 40), rng:NextNumber(zs + 5, ze - 5)), rng:NextNumber(1.5, 3.5), rgb(200, 150, 255), Enum.Material.Neon)
		CollectionService:AddTag(orb, "RainbowPart")
	end
	weather(folder, zs, ze, rgb(255, 255, 255), Enum.NormalId.Top, 70, 1.5, 0.45, 10)
	-- The final portal: a giant rainbow donut at the very end of the lane
	local portal = Decor.GiantDonut(folder, CFrame.new(0, 32, ze - 6), 20, 14, rgb(20, 10, 40), rgb(255, 255, 255), { rgb(255, 60, 60), rgb(255, 230, 60), rgb(60, 220, 90), rgb(60, 150, 255), rgb(200, 80, 255) }, Enum.Material.Neon)
	CollectionService:AddTag(portal, "DonutRainbow")
end

--------------------------------------------------------------------------------
-- World 3: Dream Dimension
--------------------------------------------------------------------------------
local function cloud(parent: Instance, center: Vector3, size: number, rng: Random, color: Color3?)
	for n = 1, 5 do
		Build.Ball(parent, center + Vector3.new(rng:NextNumber(-1, 1) * size, rng:NextNumber(-0.3, 0.4) * size, rng:NextNumber(-0.6, 0.6) * size), size * rng:NextNumber(0.9, 1.4), color or rgb(255, 255, 255), Enum.Material.SmoothPlastic)
	end
end

function Themes.Clouds(folder: Instance, zs: number, ze: number, rng: Random)
	alongEdges(zs, ze, 16, rng, function(pos)
		cloud(folder, pos + Vector3.new(0, 2, 0), rng:NextNumber(3, 5), rng)
	end)
	for n = 1, 8 do
		cloud(folder, Vector3.new(rng:NextNumber(-45, 45), rng:NextNumber(25, 45), rng:NextNumber(zs + 10, ze - 10)), rng:NextNumber(3, 6), rng, if n % 3 == 0 then rgb(255, 220, 240) else nil)
	end
	-- Cotton-candy trees
	alongEdges(zs + 8, ze, 32, rng, function(pos)
		local p = Vector3.new(pos.X * 0.8, 0, pos.Z)
		Build.Pillar(folder, p, 8, 0.8, rgb(255, 255, 255))
		Build.Ball(folder, p + Vector3.new(0, 10, 0), 7, if rng:NextNumber() < 0.5 then rgb(255, 170, 220) else rgb(170, 220, 255))
	end)
	-- A rainbow arching right over the lane, from one wall to the other (its ends rest on the
	-- floor, each band one smooth curve)
	local colors = { rgb(255, 60, 60), rgb(255, 160, 40), rgb(255, 230, 60), rgb(80, 220, 90), rgb(60, 150, 255), rgb(170, 90, 255) }
	local arch = Instance.new("Model")
	arch.Name = "RainbowArch"
	local band = 3.2
	for i, color in colors do
		local radius = laneHalf - 4 - (i - 0.5) * band
		local function at(angle: number): Vector3
			return Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius * 0.75, zs + 100)
		end
		local pieces = 30
		for n = 0, pieces - 1 do
			local a, b = at(n / pieces * math.pi), at((n + 1) / pieces * math.pi)
			local length = (b - a).Magnitude + 0.6
			Build.Decor({ Parent = arch, Name = "Rainbow", Size = Vector3.new(band, 2.4, length), CFrame = CFrame.lookAt((a + b) / 2, b, Vector3.new(0, 0, 1)), Color = color, Material = Enum.Material.Neon })
		end
	end
	arch.Parent = folder
	weather(folder, zs, ze, rgb(255, 250, 255), Enum.NormalId.Top, 30, 1, 0.4, 8)
end

function Themes.Toys(folder: Instance, zs: number, ze: number, rng: Random)
	local toy = { rgb(255, 70, 70), rgb(60, 140, 255), rgb(255, 210, 40), rgb(70, 200, 90), rgb(200, 90, 255) }
	-- Stacks of alphabet blocks
	alongEdges(zs, ze, 18, rng, function(pos)
		for i = 0, rng:NextInteger(1, 3) do
			Build.Decor({ Parent = folder, Name = "ToyBlock", Size = Vector3.one * 4, CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-0.4, 0.4), 2 + i * 4, rng:NextNumber(-0.4, 0.4))) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), Color = toy[rng:NextInteger(1, #toy)], Material = Enum.Material.SmoothPlastic })
		end
	end)
	-- Bouncy balls
	scatter(zs, ze, 12, rng, function(pos)
		Build.Ball(folder, pos + Vector3.new(0, 1, 0), rng:NextNumber(1.5, 2.5), toy[rng:NextInteger(1, #toy)], Enum.Material.SmoothPlastic)
	end)
	-- Spinning tops
	for n = 1, 4 do
		local model = Instance.new("Model")
		model.Name = "SpinningTop"
		local center = CFrame.new((if n % 2 == 0 then 1 else -1) * 38, 3, zs + n * 32)
		local body = Build.Decor({ Parent = model, Name = "Top", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 6, 6), CFrame = center * CFrame.Angles(0, 0, math.pi / 2), Color = toy[n], Material = Enum.Material.SmoothPlastic })
		Build.Decor({ Parent = model, Name = "Tip", Shape = Enum.PartType.Ball, Size = Vector3.one * 2, CFrame = center * CFrame.new(0, -1.6, 0), Color = rgb(240, 240, 240) })
		Build.Decor({ Parent = model, Name = "Handle", Size = Vector3.new(0.6, 2.5, 0.6), CFrame = center * CFrame.new(0, 2, 0), Color = rgb(240, 240, 240) })
		model.PrimaryPart = body
		CollectionService:AddTag(model, "SpinSlow")
		model.Parent = folder
	end
	-- A toy train track along the left side
	Build.Decor({ Parent = folder, Name = "Track", Size = Vector3.new(4, 0.3, ze - zs - 10), Position = Vector3.new(-44, 0.15, (zs + ze) / 2), Color = rgb(150, 100, 60), Material = Enum.Material.WoodPlanks })
	for z = zs + 10, ze - 10, 4 do
		Build.Decor({ Parent = folder, Name = "Sleeper", Size = Vector3.new(6, 0.35, 1), Position = Vector3.new(-44, 0.2, z), Color = rgb(110, 70, 40), Material = Enum.Material.Wood })
	end
	for i = 0, 2 do
		Build.Decor({ Parent = folder, Name = "TrainCar", Size = Vector3.new(4.5, 4, 7), Position = Vector3.new(-44, 2.4, zs + 60 + i * 8), Color = toy[i + 1], Material = Enum.Material.SmoothPlastic })
	end
	weather(folder, zs, ze, rgb(255, 200, 80), Enum.NormalId.Top, 20, 2, 0.35, 6)
end

function Themes.Haunted(folder: Instance, zs: number, ze: number, rng: Random)
	-- Dead trees
	alongEdges(zs, ze, 24, rng, function(pos)
		local h = rng:NextNumber(10, 16)
		Build.Pillar(folder, pos, h, 1.6, rgb(50, 40, 40), Enum.Material.Wood)
		for n = 1, 4 do
			local y = h * rng:NextNumber(0.5, 0.95)
			local angle = rng:NextNumber(0, math.pi * 2)
			Build.Decor({ Parent = folder, Name = "Branch", Size = Vector3.new(0.5, 0.5, rng:NextNumber(3, 6)), CFrame = CFrame.new(pos + Vector3.new(0, y, 0)) * CFrame.Angles(0, angle, 0) * CFrame.Angles(math.rad(30), 0, 0) * CFrame.new(0, 0, -2), Color = rgb(50, 40, 40), Material = Enum.Material.Wood })
		end
	end)
	-- Gravestones
	scatter(zs, ze, 14, rng, function(pos)
		local p = Vector3.new(math.sign(pos.X) * rng:NextNumber(28, 44), 0, pos.Z)
		Build.Decor({ Parent = folder, Name = "Grave", Size = Vector3.new(3, 4, 0.8), CFrame = CFrame.new(p + Vector3.new(0, 2, 0)) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(-0.3, 0.3), 0), Color = rgb(120, 120, 130), Material = Enum.Material.Slate })
	end)
	-- Jack-o'-lanterns
	for n = 1, 8 do
		local pos = Vector3.new((if n % 2 == 0 then 1 else -1) * rng:NextNumber(24, 40), 1.2, zs + n * 18)
		local pumpkin = Build.Decor({ Parent = folder, Name = "Pumpkin", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 2.4, 3), Position = pos, Color = rgb(255, 130, 30), Material = Enum.Material.SmoothPlastic })
		Build.Decor({ Parent = folder, Name = "PumpkinFace", Size = Vector3.new(1.6, 0.6, 0.2), Position = pos + Vector3.new(0, -0.1, -1.45), Color = rgb(255, 230, 90), Material = Enum.Material.Neon })
		local light = Instance.new("PointLight")
		light.Color = rgb(255, 150, 50)
		light.Range = 12
		light.Parent = pumpkin
	end
	for z = zs + 20, ze - 10, 40 do
		lamp(folder, Vector3.new(-42, 0, z), rgb(140, 255, 120), 9)
		lamp(folder, Vector3.new(42, 0, z + 20), rgb(170, 90, 255), 9)
	end
	weather(folder, zs, ze, rgb(200, 255, 200), Enum.NormalId.Top, 12, 1, 1.5, 8)
end

function Themes.Clockwork(folder: Instance, zs: number, ze: number, rng: Random)
	local brass = rgb(220, 170, 70)
	-- Giant gears turning on the walls, each on an axle going into the wall (they turn round the
	-- axle: client/Effects "GearSpin")
	local z, turn = zs + 22, 1
	while z < ze - 14 do
		for _, side in { -1, 1 } do
			local radius = rng:NextNumber(10, 15)
			local wallX = side * DESIGN_HALF
			local x = wallX - side * 3
			local cf = CFrame.new(x, radius + 8, z) * CFrame.Angles(0, math.pi / 2, 0)
			local model = ringOfBalls(folder, cf, radius, 3, brass, 18, nil)
			for _, piece in model:GetChildren() do
				if piece:IsA("BasePart") and piece.Name == "RingBall" then
					piece.Material = Enum.Material.Metal
				end
			end
			-- a solid brass wheel with the teeth round its edge, spokes and a hub on its face
			Build.Decor({ Parent = model, Name = "GearDisc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, radius * 2 - 0.6, radius * 2 - 0.6), CFrame = cf * CFrame.Angles(0, math.pi / 2, 0), Color = rgb(190, 145, 65), Material = Enum.Material.Metal })
			for spoke = 0, 3 do
				Build.Decor({ Parent = model, Name = "Spoke", Size = Vector3.new(radius * 2 - 1, 1.4, 1.8), CFrame = cf * CFrame.Angles(0, 0, spoke * math.pi / 4), Color = rgb(140, 105, 50), Material = Enum.Material.Metal })
			end
			Build.Decor({ Parent = model, Name = "Hub", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, radius * 0.5, radius * 0.5), CFrame = cf * CFrame.Angles(0, math.pi / 2, 0), Color = rgb(120, 90, 50), Material = Enum.Material.Metal })
			model:SetAttribute("SpinDir", turn)
			turn = -turn -- (neighbours turn opposite ways, like meshing gears)
			CollectionService:AddTag(model, "GearSpin")
			-- the axle, from the hub into the wall (it doesn't turn)
			Build.Decor({ Parent = folder, Name = "Axle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(5, 2.2, 2.2), CFrame = CFrame.new(wallX - side * 1.5, radius + 8, z), Color = rgb(90, 70, 45), Material = Enum.Material.Metal })
		end
		z += rng:NextNumber(40, 48)
	end
	-- Steam pipes
	alongEdges(zs, ze, 26, rng, function(pos)
		local p = Vector3.new(pos.X * 0.85, 0, pos.Z)
		local pipe = Build.Pillar(folder, p, 12, 1.6, rgb(150, 120, 80), Enum.Material.Metal)
		local smoke = Instance.new("Smoke")
		smoke.Color = rgb(230, 230, 240)
		smoke.RiseVelocity = 5
		smoke.Size = 2
		smoke.Opacity = 0.15
		smoke.Parent = pipe
	end)
	-- Clock tower with a glowing face (one model, so it moves out to the wall in one piece)
	local tower = Vector3.new(-40, 0, zs + 100)
	local clock = Instance.new("Model")
	clock.Name = "ClockTower"
	Build.Decor({ Parent = clock, Name = "ClockTower", Size = Vector3.new(10, 34, 10), Position = tower + Vector3.new(0, 17, 0), Color = rgb(70, 60, 90), Material = Enum.Material.Brick })
	Build.Decor({ Parent = clock, Name = "ClockFace", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 8, 8), CFrame = CFrame.new(tower + Vector3.new(5.2, 28, 0)), Color = rgb(255, 240, 200), Material = Enum.Material.Neon })
	for i = 0, 11 do
		local angle = i / 12 * math.pi * 2
		Build.Decor({ Parent = clock, Name = "ClockMark", Size = Vector3.new(0.3, 0.6, 0.3), Position = tower + Vector3.new(5.5, 28 + math.cos(angle) * 3.2, math.sin(angle) * 3.2), Color = rgb(40, 30, 20) })
	end
	clock.Parent = folder
	scatter(zs, ze, 10, rng, function(pos)
		Build.Decor({ Parent = folder, Name = "Cog", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 3, 3), CFrame = CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = brass, Material = Enum.Material.Foil })
	end)
	weather(folder, zs, ze, rgb(255, 200, 100), Enum.NormalId.Top, 25, 2, 0.3, 6)
end

function Themes.Heaven(folder: Instance, zs: number, ze: number, rng: Random)
	local gold = rgb(255, 210, 80)
	-- Marble columns with golden caps
	alongEdges(zs, ze, 20, rng, function(pos)
		Build.Pillar(folder, pos, 26, 4, rgb(250, 248, 240), Enum.Material.Marble)
		Build.Decor({ Parent = folder, Name = "ColumnCap", Size = Vector3.new(5.5, 1.5, 5.5), Position = pos + Vector3.new(0, 26.75, 0), Color = gold, Material = Enum.Material.Foil })
		Build.Decor({ Parent = folder, Name = "ColumnBase", Size = Vector3.new(5.5, 1, 5.5), Position = pos + Vector3.new(0, 0.5, 0), Color = gold, Material = Enum.Material.Foil })
	end)
	-- Clouds on the floor
	scatter(zs, ze, 10, rng, function(pos)
		cloud(folder, Vector3.new(math.sign(pos.X) * rng:NextNumber(30, 42), 1, pos.Z), rng:NextNumber(2, 3.5), rng)
	end)
	-- Floating halos
	for n = 1, 6 do
		ringOfBalls(folder, CFrame.new(rng:NextNumber(-35, 35), rng:NextNumber(18, 38), rng:NextNumber(zs + 15, ze - 15)) * CFrame.Angles(math.pi / 2, 0, 0), rng:NextNumber(3, 5), 1, rgb(255, 240, 150), 14, "SpinSlow")
	end
	-- The golden gates at the end of the biome: pillars, bars, a golden beam across the top and the
	-- biggest donut of all sitting on it (one model, so the clean-up round Domer's corner keeps the
	-- whole gate or none of it)
	local gate = Instance.new("Model")
	gate.Name = "GoldenGate"
	for _, side in { -1, 1 } do
		Build.Decor({ Parent = gate, Name = "GatePillar", Size = Vector3.new(5, 40, 5), Position = Vector3.new(side * 24, 20, ze - 8), Color = gold, Material = Enum.Material.Foil })
	end
	for x = -20, 20, 4 do
		Build.Decor({ Parent = gate, Name = "GateBar", Size = Vector3.new(0.6, 30, 0.6), Position = Vector3.new(x, 15, ze - 8), Color = gold, Material = Enum.Material.Foil })
	end
	Build.Decor({ Parent = gate, Name = "GateRail", Size = Vector3.new(44, 1.2, 1), Position = Vector3.new(0, 30.4, ze - 8), Color = gold, Material = Enum.Material.Foil })
	Build.Decor({ Parent = gate, Name = "GateLintel", Size = Vector3.new(56, 3, 7), Position = Vector3.new(0, 41.5, ze - 8), Color = gold, Material = Enum.Material.Foil })
	gate.Parent = folder
	local donut = Decor.GiantDonut(gate, CFrame.new(0, 58.8, ze - 8), 12, 9, rgb(255, 215, 0), rgb(255, 255, 255), { rgb(255, 60, 60), rgb(255, 230, 60), rgb(60, 220, 90), rgb(60, 150, 255), rgb(200, 80, 255) }, Enum.Material.Neon)
	CollectionService:AddTag(donut, "DonutRainbow")
	weather(folder, zs, ze, rgb(255, 245, 200), Enum.NormalId.Top, 50, 1.5, 0.4, 9)
end

--------------------------------------------------------------------------------
-- New areas at the end of Worlds 1-3
--------------------------------------------------------------------------------
local RAINBOW_COLORS = { rgb(255, 60, 60), rgb(255, 160, 40), rgb(255, 230, 60), rgb(80, 220, 90), rgb(60, 150, 255), rgb(170, 90, 255) }

local function lollipop(parent: Instance, pos: Vector3, rng: Random)
	local h = rng:NextNumber(8, 12)
	Build.Pillar(parent, pos, h, 0.5, rgb(250, 250, 250))
	local color = RAINBOW_COLORS[rng:NextInteger(1, #RAINBOW_COLORS)]
	local cf = CFrame.new(pos + Vector3.new(0, h + 2.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	Build.Decor({ Parent = parent, Name = "Lollipop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 6, 6), CFrame = cf * CFrame.Angles(0, math.pi / 2, 0), Color = color, Material = Enum.Material.SmoothPlastic })
	Build.Decor({ Parent = parent, Name = "Swirl", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.85, 3.4, 3.4), CFrame = cf * CFrame.Angles(0, math.pi / 2, 0), Color = rgb(255, 255, 255), Material = Enum.Material.SmoothPlastic })
end

local function rainbowArch(parent: Instance, z: number, radius: number)
	for i, color in RAINBOW_COLORS do
		local r = radius - i * 2
		for n = 0, 16 do
			local angle = n / 16 * math.pi
			Build.Decor({ Parent = parent, Name = "Rainbow", Size = Vector3.new(2.2, 2.2, 2), Position = Vector3.new(math.cos(angle) * r, math.sin(angle) * r * 0.8, z), Color = color, Material = Enum.Material.Neon })
		end
	end
end

function Themes.Candy(folder: Instance, zs: number, ze: number, rng: Random)
	alongEdges(zs, ze, 18, rng, function(pos, side)
		if rng:NextNumber() < 0.5 then
			candyCane(folder, pos)
		else
			lollipop(folder, pos, rng)
		end
	end)
	-- Gumdrops you can run past
	scatter(zs, ze, 18, rng, function(pos)
		local p = Vector3.new(math.sign(pos.X) * rng:NextNumber(20, 42), 0, pos.Z)
		Build.Decor({ Parent = folder, Name = "Gumdrop", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 2.6, 3), Position = p + Vector3.new(0, 1, 0), Color = RAINBOW_COLORS[rng:NextInteger(1, #RAINBOW_COLORS)], Material = Enum.Material.Glass, Transparency = 0.15 })
	end)
	-- Giant chocolate bar bridges across the canyon, from the top of one wall to the other (the
	-- squares of the bar on top, a drip of melted chocolate here and there)
	for z = zs + 30, ze - 20, 50 do
		local bridge = Instance.new("Model")
		bridge.Name = "ChocoBridge"
		local y = WALL_HEIGHT - 2.5
		Build.Decor({ Parent = bridge, Name = "ChocoBar", Size = Vector3.new(laneHalf * 2 + 10, 5, 16), Position = Vector3.new(0, y, z), Color = rgb(110, 60, 35), Material = Enum.Material.SmoothPlastic })
		local x = -laneHalf + 5
		while x <= laneHalf - 5 do
			Build.Decor({ Parent = bridge, Name = "ChocoSquare", Size = Vector3.new(9, 1.2, 6.5), Position = Vector3.new(x, y + 3, z - 3.6), Color = rgb(120, 66, 40), Material = Enum.Material.SmoothPlastic })
			Build.Decor({ Parent = bridge, Name = "ChocoSquare", Size = Vector3.new(9, 1.2, 6.5), Position = Vector3.new(x, y + 3, z + 3.6), Color = rgb(120, 66, 40), Material = Enum.Material.SmoothPlastic })
			if rng:NextNumber() < 0.3 then
				local drip = rng:NextNumber(3, 7)
				Build.Decor({ Parent = bridge, Name = "ChocoDrip", Size = Vector3.new(1.6, drip, 1.6), Position = Vector3.new(x + rng:NextNumber(-3, 3), y - 2.5 - drip / 2 + 0.3, z + rng:NextNumber(-6, 6)), Color = rgb(95, 50, 30), Material = Enum.Material.SmoothPlastic })
			end
			x += 10
		end
		bridge.Parent = folder
	end
	Decor.DonutStatue(folder, Vector3.new(44, 0, zs + 120), 4, rgb(245, 245, 245), rgb(230, 40, 50), { rgb(255, 255, 255) })
	weather(folder, zs, ze, rgb(255, 150, 200), Enum.NormalId.Bottom, 35, 3, 0.35, 7)
end

function Themes.Rainbow(folder: Instance, zs: number, ze: number, rng: Random)
	-- Snowy peaks along the walls
	alongEdges(zs, ze, 20, rng, function(pos)
		local h = rng:NextNumber(10, 18)
		for i = 0, 3 do
			local s = (4 - i) * 3
			Build.Decor({ Parent = folder, Name = "Peak", Size = Vector3.new(s, h / 4, s), Position = pos + Vector3.new(0, h / 8 + i * h / 4, 0), Color = if i == 3 then rgb(255, 255, 255) else rgb(190, 205, 235), Material = if i == 3 then Enum.Material.Snow else Enum.Material.Rock })
		end
	end)
	-- Sprinkle piles
	scatter(zs, ze, 14, rng, function(pos)
		local p = Vector3.new(math.sign(pos.X) * rng:NextNumber(18, 40), 0, pos.Z)
		for n = 1, 8 do
			Build.Decor({ Parent = folder, Name = "Sprinkle", Size = Vector3.new(0.5, 0.5, 2), CFrame = CFrame.new(p + Vector3.new(rng:NextNumber(-1.5, 1.5), 0.3 + n * 0.12, rng:NextNumber(-1.5, 1.5))) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color = RAINBOW_COLORS[(n - 1) % #RAINBOW_COLORS + 1], Material = Enum.Material.SmoothPlastic })
		end
	end)
	rainbowArch(folder, zs + 40, 50)
	rainbowArch(folder, zs + 120, 50)
	for n = 1, 8 do
		cloud(folder, Vector3.new(rng:NextNumber(-45, 45), rng:NextNumber(30, 50), rng:NextNumber(zs + 10, ze - 10)), rng:NextNumber(3, 5), rng)
	end
	weather(folder, zs, ze, rgb(255, 255, 255), Enum.NormalId.Bottom, 90, 6, 0.4, 7)
end

function Themes.Starfall(folder: Instance, zs: number, ze: number, rng: Random)
	-- Giant glowing flowers
	alongEdges(zs, ze, 18, rng, function(pos)
		local h = rng:NextNumber(6, 12)
		Build.Pillar(folder, pos, h, 0.6, rgb(90, 200, 120), Enum.Material.Neon)
		local color = if rng:NextNumber() < 0.5 then rgb(255, 170, 240) else rgb(170, 200, 255)
		for n = 0, 5 do
			local angle = n / 6 * math.pi * 2
			Build.Ball(folder, pos + Vector3.new(math.cos(angle) * 1.8, h + 0.5, math.sin(angle) * 1.8), 2.2, color, Enum.Material.Neon)
		end
		Build.Ball(folder, pos + Vector3.new(0, h + 0.7, 0), 1.6, rgb(255, 240, 150), Enum.Material.Neon)
	end)
	-- Floating stars
	for n = 1, 10 do
		local p = Vector3.new(rng:NextNumber(-45, 45), rng:NextNumber(18, 45), rng:NextNumber(zs + 10, ze - 10))
		local star = ringOfBalls(folder, CFrame.new(p) * CFrame.Angles(math.pi / 2, 0, 0), 1.6, 1, rgb(255, 240, 160), 5, "SpinSlow")
		Build.Decor({ Parent = star, Name = "StarCore", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.8, CFrame = CFrame.new(p), Color = rgb(255, 250, 200), Material = Enum.Material.Neon })
	end
	-- A huge moon at the end of the garden
	local moon = Build.Ball(folder, Vector3.new(0, 70, ze + 30), 40, rgb(245, 240, 220), Enum.Material.Neon)
	moon.Transparency = 0.1
	-- Firefly paths
	scatter(zs, ze, 20, rng, function(pos)
		Build.Ball(folder, Vector3.new(pos.X, rng:NextNumber(2, 6), pos.Z), 0.4, rgb(255, 255, 150), Enum.Material.Neon)
	end)
	weather(folder, zs, ze, rgb(255, 245, 160), Enum.NormalId.Top, 40, 1, 0.3, 8)
end

function Themes.Aurora(folder: Instance, zs: number, ze: number, rng: Random)
	-- Ice spires
	alongEdges(zs, ze, 16, rng, function(pos)
		crystal(folder, pos, if rng:NextNumber() < 0.5 then rgb(170, 230, 255) else rgb(200, 180, 255), rng:NextNumber(8, 14), rng, rng:NextNumber() < 0.3)
	end)
	-- Palace towers along the walls
	for z = zs + 30, ze - 20, 55 do
		for _, side in { -1, 1 } do
			local base = Vector3.new(side * 50, 0, z)
			Build.Pillar(folder, base, 34, 8, rgb(225, 240, 255), Enum.Material.Glass)
			for i = 0, 3 do
				Build.Decor({ Parent = folder, Name = "Spire", Size = Vector3.new(7 - i * 1.6, 3, 7 - i * 1.6), Position = base + Vector3.new(0, 35.5 + i * 3, 0), Color = rgb(150, 200, 255), Material = Enum.Material.Glass, Transparency = 0.2 })
			end
			Build.Ball(folder, base + Vector3.new(0, 48, 0), 1.6, rgb(120, 255, 200), Enum.Material.Neon)
		end
	end
	-- Aurora ribbons in the sky
	local auroraColors = { rgb(90, 255, 170), rgb(90, 200, 255), rgb(200, 120, 255) }
	for i, color in auroraColors do
		for n = 0, 7 do
			local z = zs + 10 + n * 20
			Build.Decor({ Parent = folder, Name = "Aurora", Size = Vector3.new(90, 8, 1), CFrame = CFrame.new(0, 60 + i * 6 + math.sin(n + i) * 3, z) * CFrame.Angles(0.3, 0, math.sin(n * 0.7 + i) * 0.12), Color = color, Material = Enum.Material.Neon, Transparency = 0.7 })
		end
	end
	weather(folder, zs, ze, rgb(230, 250, 255), Enum.NormalId.Bottom, 80, 5, 0.4, 7)
end

--------------------------------------------------------------------------------
-- World 4: Cyber City
--------------------------------------------------------------------------------
local CYBER = { rgb(255, 40, 200), rgb(0, 230, 255), rgb(255, 220, 0), rgb(40, 255, 120), rgb(170, 90, 255) }

-- A tall building against the lane wall with glowing window strips.
local function building(parent: Instance, pos: Vector3, rng: Random, accent: Color3?)
	local w, d, h = rng:NextNumber(8, 12), rng:NextNumber(8, 12), rng:NextNumber(30, 70)
	local color = rgb(24, 24, 38):Lerp(rgb(40, 40, 60), rng:NextNumber())
	Build.Decor({ Parent = parent, Name = "Building", Size = Vector3.new(w, h, d), Position = pos + Vector3.new(0, h / 2, 0), Color = color, Material = Enum.Material.Metal })
	local glow = accent or CYBER[rng:NextInteger(1, #CYBER)]
	for y = 6, h - 4, 6 do
		Build.Decor({ Parent = parent, Name = "Windows", Size = Vector3.new(w + 0.2, 0.8, d + 0.2), Position = pos + Vector3.new(0, y, 0), Color = glow, Material = Enum.Material.Neon, Transparency = 0.35 })
	end
	Build.Decor({ Parent = parent, Name = "Roof", Size = Vector3.new(w + 1, 1, d + 1), Position = pos + Vector3.new(0, h + 0.5, 0), Color = glow, Material = Enum.Material.Neon })
end

-- A glowing sign with text on both faces.
local function neonSign(parent: Instance, cf: CFrame, text: string, color: Color3, width: number?, height: number?)
	local h = height or 4
	local sign = Build.Decor({ Parent = parent, Name = "NeonSign", Size = Vector3.new(width or 14, h, 0.6), CFrame = cf, Color = rgb(15, 15, 25), Material = Enum.Material.SmoothPlastic })
	Build.Decor({ Parent = parent, Name = "SignFrame", Size = Vector3.new((width or 14) + 0.6, h + 0.6, 0.4), CFrame = cf * CFrame.new(0, 0, 0.1), Color = color, Material = Enum.Material.Neon })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 20
		gui.Parent = sign
		Build.Text(gui, text, { TextColor3 = color, Font = Enum.Font.Arcade, TextStrokeTransparency = 1 })
	end
end

local function streetLamp(parent: Instance, pos: Vector3, color: Color3)
	Build.Pillar(parent, pos, 12, 0.5, rgb(50, 50, 60), Enum.Material.Metal)
	Build.Decor({ Parent = parent, Name = "LampArm", Size = Vector3.new(4, 0.4, 0.4), Position = pos + Vector3.new(-math.sign(pos.X) * 2, 12, 0), Color = rgb(50, 50, 60), Material = Enum.Material.Metal })
	local bulb = Build.Decor({ Parent = parent, Name = "LampLight", Size = Vector3.new(2, 0.4, 1), Position = pos + Vector3.new(-math.sign(pos.X) * 3.6, 11.7, 0), Color = color, Material = Enum.Material.Neon })
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 20
	light.Brightness = 1.5
	light.Parent = bulb
end

function Themes.CyberStreets(folder: Instance, zs: number, ze: number, rng: Random)
	-- A skyline behind the walls (you see it above them)
	for z = zs + 8, ze - 8, 16 do
		for _, side in { -1, 1 } do
			building(folder, Vector3.new(side * rng:NextNumber(72, 90), 0, z + rng:NextNumber(-3, 3)), rng)
		end
	end
	for z = zs + 15, ze - 10, 28 do
		streetLamp(folder, Vector3.new(-50, 0, z), CYBER[1])
		streetLamp(folder, Vector3.new(50, 0, z + 14), CYBER[2])
	end
	-- Big neon signs bolted to the walls
	local signs = { "DONUTS 24/7", "GLAZE.EXE", "NEON DUNK", "SPRINKLE.NET", "HACK THE DONUT" }
	for n = 1, 4 do
		local side = if n % 2 == 0 then 1 else -1
		local mount = Instance.new("Model")
		mount.Name = "WallSign"
		local x, y, z = side * (DESIGN_HALF - 2.2), 24 + n * 4, zs + n * 32
		-- (facing the lane: its glowing frame behind it, against the wall)
		neonSign(mount, CFrame.new(x, y, z) * CFrame.Angles(0, side * math.pi / 2, 0), signs[(n - 1) % #signs + 1], CYBER[n], 26, 6.5)
		for _, dz in { -9, 9 } do
			for _, dy in { -2.4, 2.4 } do
				Build.Decor({ Parent = mount, Name = "SignBracket", Size = Vector3.new(2.6, 0.5, 0.5), Position = Vector3.new(side * (DESIGN_HALF - 1.2), y + dy, z + dz), Color = rgb(60, 60, 75), Material = Enum.Material.Metal })
			end
		end
		mount.Parent = folder
	end
	-- Road markings
	for z = zs + 6, ze - 6, 12 do
		Build.Decor({ Parent = folder, Name = "RoadLine", Size = Vector3.new(1, 0.05, 6), Position = Vector3.new(0, 0.03, z), Color = rgb(255, 220, 0), Material = Enum.Material.Neon })
	end
	weather(folder, zs, ze, rgb(160, 200, 255), Enum.NormalId.Bottom, 140, 50, 0.12, 1.2)
end

function Themes.Hologram(folder: Instance, zs: number, ze: number, rng: Random)
	-- Shop fronts along the walls
	alongEdges(zs, ze, 24, rng, function(pos, side)
		local p = Vector3.new(side * 53, 0, pos.Z)
		Build.Decor({ Parent = folder, Name = "Shop", Size = Vector3.new(8, 14, 16), Position = p + Vector3.new(0, 7, 0), Color = rgb(60, 70, 100), Material = Enum.Material.Glass, Transparency = 0.3 })
		Build.Decor({ Parent = folder, Name = "ShopTrim", Size = Vector3.new(8.4, 1, 16.4), Position = p + Vector3.new(0, 14.5, 0), Color = CYBER[rng:NextInteger(1, #CYBER)], Material = Enum.Material.Neon })
	end)
	-- Hologram donuts slowly turning in the air
	for n = 1, 5 do
		local p = Vector3.new(if n % 2 == 0 then 30 else -30, 14, zs + n * 28)
		local ring = ringOfBalls(folder, CFrame.new(p), 4, 2.2, rgb(0, 230, 255), 14, "SpinSlow")
		for _, part in ring:GetChildren() do
			if part:IsA("BasePart") and part.Name == "RingBall" then
				part.Transparency = 0.4
			end
		end
		Build.Decor({ Parent = folder, Name = "Projector", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 4, 4), CFrame = CFrame.new(p.X, 0.5, p.Z) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(40, 40, 60), Material = Enum.Material.Metal })
		Build.Decor({ Parent = folder, Name = "HoloBeam", Size = Vector3.new(0.4, 12, 0.4), Position = Vector3.new(p.X, 7, p.Z), Color = rgb(0, 230, 255), Material = Enum.Material.Neon, Transparency = 0.6 })
	end
	-- Escalators
	for _, side in { -1, 1 } do
		Build.Decor({ Parent = folder, Name = "Escalator", Size = Vector3.new(6, 1, 30), CFrame = CFrame.new(side * 42, 8, zs + 80) * CFrame.Angles(math.rad(28), 0, 0), Color = rgb(170, 175, 190), Material = Enum.Material.DiamondPlate })
	end
	neonSign(folder, CFrame.new(0, 34, zs + 130), "HOLO MALL - 99% OFF DONUTS", CYBER[2], 40)
	weather(folder, zs, ze, rgb(0, 230, 255), Enum.NormalId.Top, 30, 2, 0.3, 5)
end

function Themes.RobotFactory(folder: Instance, zs: number, ze: number, rng: Random)
	local yellow, dark = rgb(255, 190, 0), rgb(50, 52, 60)
	-- Conveyor belts along both walls, with boxes riding them
	for _, side in { -1, 1 } do
		Build.Decor({ Parent = folder, Name = "Conveyor", Size = Vector3.new(6, 2, ze - zs - 10), Position = Vector3.new(side * 52, 1, (zs + ze) / 2), Color = dark, Material = Enum.Material.DiamondPlate })
		for z = zs + 10, ze - 10, 8 do
			Build.Decor({ Parent = folder, Name = "BeltStripe", Size = Vector3.new(6.1, 0.1, 1), Position = Vector3.new(side * 52, 2.05, z), Color = yellow, Material = Enum.Material.SmoothPlastic })
		end
		for z = zs + 14, ze - 14, 22 do
			Build.Decor({ Parent = folder, Name = "Crate", Size = Vector3.new(3.5, 3.5, 3.5), Position = Vector3.new(side * 52, 3.8, z + rng:NextNumber(-3, 3)), Color = rgb(150, 110, 60), Material = Enum.Material.WoodPlanks })
		end
	end
	-- Robot arms
	for n = 1, 5 do
		local side = if n % 2 == 0 then 1 else -1
		local base = Vector3.new(side * 42, 0, zs + n * 27)
		Build.Pillar(folder, base, 2, 5, dark, Enum.Material.Metal)
		Build.Decor({ Parent = folder, Name = "ArmLower", Size = Vector3.new(1.6, 10, 1.6), CFrame = CFrame.new(base + Vector3.new(0, 6.5, 0)) * CFrame.Angles(0, 0, side * 0.35), Color = yellow, Material = Enum.Material.Metal })
		Build.Decor({ Parent = folder, Name = "ArmUpper", Size = Vector3.new(1.4, 8, 1.4), CFrame = CFrame.new(base + Vector3.new(side * 4.5, 12.5, 0)) * CFrame.Angles(0, 0, side * 1.3), Color = yellow, Material = Enum.Material.Metal })
		local tool = Build.Ball(folder, base + Vector3.new(side * 8.5, 11, 0), 1.4, rgb(255, 120, 0), Enum.Material.Neon)
		local sparks = Instance.new("ParticleEmitter")
		sparks.Color = ColorSequence.new(rgb(255, 220, 120))
		sparks.LightEmission = 1
		sparks.Rate = 25
		sparks.Speed = NumberRange.new(6, 14)
		sparks.Lifetime = NumberRange.new(0.3, 0.6)
		sparks.Size = NumberSequence.new(0.25, 0)
		sparks.SpreadAngle = Vector2.new(60, 60)
		sparks.Acceleration = Vector3.new(0, -30, 0)
		sparks.Parent = tool
	end
	-- Smoke stacks
	for _, x in { -30, 30 } do
		local stack = Build.Pillar(folder, Vector3.new(x, 0, ze - 25), 45, 5, rgb(90, 90, 100), Enum.Material.Metal)
		local smoke = Instance.new("Smoke")
		smoke.Color = rgb(200, 200, 210)
		smoke.RiseVelocity = 6
		smoke.Size = 4
		smoke.Opacity = 0.2
		smoke.Parent = stack
	end
	weather(folder, zs, ze, rgb(255, 200, 80), Enum.NormalId.Top, 30, 3, 0.25, 4)
end

function Themes.DataHighway(folder: Instance, zs: number, ze: number, rng: Random)
	local green = rgb(40, 255, 120)
	-- Glowing data lanes on the floor
	for _, x in { -40, -20, 20, 40 } do
		Build.Decor({ Parent = folder, Name = "DataLane", Size = Vector3.new(1, 0.06, ze - zs - 6), Position = Vector3.new(x, 0.04, (zs + ze) / 2), Color = if math.abs(x) > 30 then green else rgb(80, 200, 255), Material = Enum.Material.Neon })
	end
	-- Server racks with blinking lights
	alongEdges(zs, ze, 14, rng, function(pos, side)
		local p = Vector3.new(side * 52, 0, pos.Z)
		Build.Decor({ Parent = folder, Name = "ServerRack", Size = Vector3.new(5, 16, 7), Position = p + Vector3.new(0, 8, 0), Color = rgb(20, 24, 30), Material = Enum.Material.Metal })
		for y = 2, 14, 2 do
			Build.Decor({ Parent = folder, Name = "RackLight", Size = Vector3.new(0.2, 0.3, 0.6), Position = p + Vector3.new(-side * 2.55, y, rng:NextNumber(-2.5, 2.5)), Color = if rng:NextNumber() < 0.7 then green else rgb(255, 60, 60), Material = Enum.Material.Neon })
		end
	end)
	-- Floating packets of data
	for n = 1, 12 do
		local p = Vector3.new(rng:NextNumber(-44, 44), rng:NextNumber(12, 35), rng:NextNumber(zs + 10, ze - 10))
		Build.Decor({ Parent = folder, Name = "Packet", Size = Vector3.one * rng:NextNumber(1.5, 3), CFrame = CFrame.new(p) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0), Color = if n % 2 == 0 then green else rgb(80, 200, 255), Material = Enum.Material.Neon, Transparency = 0.3 })
	end
	-- Cables hanging across the lane
	for z = zs + 20, ze - 20, 40 do
		Build.Decor({ Parent = folder, Name = "Cable", Size = Vector3.new(120, 0.6, 0.6), CFrame = CFrame.new(0, 38, z) * CFrame.Angles(0, 0, 0.03), Color = rgb(30, 30, 40) })
	end
	weather(folder, zs, ze, green, Enum.NormalId.Bottom, 120, 30, 0.2, 2)
end

function Themes.Firewall(folder: Instance, zs: number, ze: number, rng: Random)
	local red = rgb(255, 50, 30)
	-- Laser walls along the sides
	for z = zs + 10, ze - 10, 20 do
		for _, side in { -1, 1 } do
			Build.Decor({ Parent = folder, Name = "Laser", Size = Vector3.new(0.4, 30, 16), Position = Vector3.new(side * 54, 15, z), Color = red, Material = Enum.Material.Neon, Transparency = 0.6 })
		end
	end
	-- Shield generators
	for n = 1, 5 do
		local p = Vector3.new(if n % 2 == 0 then 38 else -38, 0, zs + n * 27)
		Build.Pillar(folder, p, 6, 3, rgb(60, 60, 70), Enum.Material.Metal)
		local orb = Build.Ball(folder, p + Vector3.new(0, 8, 0), 4, red, Enum.Material.ForceField)
		local light = Instance.new("PointLight")
		light.Color = red
		light.Range = 18
		light.Brightness = 2
		light.Parent = orb
	end
	-- Burning braziers
	scatter(zs, ze, 8, rng, function(pos)
		local p = Vector3.new(math.sign(pos.X) * rng:NextNumber(22, 34), 0, pos.Z)
		local bowl = Build.Decor({ Parent = folder, Name = "Brazier", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 4, 4), CFrame = CFrame.new(p + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(40, 40, 45), Material = Enum.Material.Metal })
		local fire = Instance.new("Fire")
		fire.Size = 5
		fire.Heat = 8
		fire.Color = red
		fire.Parent = bowl
	end)
	-- The gate itself
	for x = -48, 48, 12 do
		Build.Decor({ Parent = folder, Name = "Battlement", Size = Vector3.new(6, 6, 6), Position = Vector3.new(x, 55, zs + 150), Color = rgb(70, 25, 25), Material = Enum.Material.Metal })
	end
	neonSign(folder, CFrame.new(0, 46, zs + 150), "ACCESS DENIED", red, 30)
	weather(folder, zs, ze, rgb(255, 120, 40), Enum.NormalId.Top, 60, 6, 0.3, 4)
end

function Themes.Glitch(folder: Instance, zs: number, ze: number, rng: Random)
	-- "Missing texture" cubes floating at odd angles
	for n = 1, 26 do
		local size = rng:NextNumber(2, 7)
		local p = Vector3.new(rng:NextNumber(-55, 55), rng:NextNumber(3, 45), rng:NextNumber(zs + 5, ze - 5))
		if math.abs(p.X) < 40 and p.Y < 14 then
			p = Vector3.new(p.X, p.Y + 14, p.Z) -- keep the running line clear
		end
		local cube = Build.Decor({ Parent = folder, Name = "GlitchCube", Size = Vector3.one * size, CFrame = CFrame.new(p) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3)), Color = if n % 2 == 0 then rgb(255, 0, 220) else rgb(10, 10, 10), Material = if n % 2 == 0 then Enum.Material.Neon else Enum.Material.SmoothPlastic })
		if n % 5 == 0 then
			CollectionService:AddTag(cube, "RainbowPart")
		end
	end
	-- Torn "pixels" on the floor
	scatter(zs, ze, 30, rng, function(pos)
		Build.Decor({ Parent = folder, Name = "Pixel", Size = Vector3.new(rng:NextNumber(1, 3), 0.1, rng:NextNumber(1, 3)), Position = Vector3.new(pos.X, 0.06, pos.Z), Color = CYBER[rng:NextInteger(1, #CYBER)], Material = Enum.Material.Neon })
	end)
	-- Error windows stuck in the air
	local errors = { "ERROR 404", "DONUT.EXE HAS STOPPED", "NaN NaN NaN", "SEGFAULT", "LAG" }
	for n = 1, 5 do
		neonSign(folder, CFrame.new(if n % 2 == 0 then 44 else -44, 18 + n * 4, zs + n * 28) * CFrame.Angles(0, math.pi / 2 + rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.2, 0.2)), errors[n], if n % 2 == 0 then rgb(255, 60, 60) else rgb(0, 230, 255), 18)
	end
	weather(folder, zs, ze, rgb(255, 0, 220), Enum.NormalId.Top, 50, 4, 0.5, 3)
end

function Themes.Mainframe(folder: Instance, zs: number, ze: number, rng: Random)
	local blue = rgb(80, 160, 255)
	-- Pillars of light
	alongEdges(zs, ze, 18, rng, function(pos)
		Build.Pillar(folder, pos, 40, 3, rgb(20, 24, 50), Enum.Material.Glass)
		Build.Decor({ Parent = folder, Name = "LightStrip", Size = Vector3.new(0.6, 40, 0.6), Position = pos + Vector3.new(0, 20, 0), Color = blue, Material = Enum.Material.Neon })
	end)
	-- Cables running into the core
	for _, x in { -30, -10, 10, 30 } do
		Build.Decor({ Parent = folder, Name = "CoreCable", Size = Vector3.new(1.2, 1.2, ze - zs), Position = Vector3.new(x, 44, (zs + ze) / 2), Color = rgb(30, 40, 80), Material = Enum.Material.Metal })
	end
	-- The core at the very end of the last lane, with rings turning around it
	local center = CFrame.new(0, 62, ze - 10)
	local core = Build.Ball(folder, center.Position, 30, blue, Enum.Material.Neon)
	core.Transparency = 0.15
	for i = 1, 3 do
		ringOfBalls(folder, center * CFrame.Angles(i * 0.9, i * 0.6, 0), 22 + i * 4, 2, if i == 2 then rgb(255, 40, 200) else rgb(0, 230, 255), 24, "SpinSlow")
	end
	local light = Instance.new("PointLight")
	light.Color = blue
	light.Range = 60
	light.Brightness = 3
	light.Parent = core
	-- Floating code blocks
	for n = 1, 10 do
		local p = Vector3.new(rng:NextNumber(-45, 45), rng:NextNumber(15, 40), rng:NextNumber(zs + 10, ze - 30))
		Build.Decor({ Parent = folder, Name = "CodeBlock", Size = Vector3.new(4, 2, 0.3), CFrame = CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color = if n % 2 == 0 then blue else rgb(255, 40, 200), Material = Enum.Material.Neon, Transparency = 0.4 })
	end
	weather(folder, zs, ze, rgb(150, 200, 255), Enum.NormalId.Top, 60, 2, 0.3, 6)
end

-- The black hole model (see BlackHoleModel): used in The Black Hole's sky and in its lab.
function Decor.BlackHole(parent: Instance, center: Vector3, scale: number, options: BlackHoleModel.Options?): Model
	return BlackHoleModel.Build(parent, center, scale, options)
end

-- (The Black Hole used to have a pit down to a secret lab. The lab is gone; the theme still asks
-- where the pit is, so it's somewhere far outside the lane.)
Decor.LabPitSize = 20
function Decor.LabPit(_zs: number): (number, number)
	return 100_000, -100_000
end

-- A glowing beam between two attachments on `holder`. A map baked to a file can't keep the
-- references, so the attachments' names are stored too and MapBuilder reconnects them.
local function glowBeam(holder: BasePart, from: CFrame, to: CFrame): Beam
	local a0 = Instance.new("Attachment")
	a0.Name = "BeamFrom"
	a0.CFrame = from
	a0.Parent = holder
	local a1 = Instance.new("Attachment")
	a1.Name = "BeamTo"
	a1.CFrame = to
	a1.Parent = holder
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam:SetAttribute("From", a0.Name)
	beam:SetAttribute("To", a1.Name)
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Parent = holder
	return beam
end

-- The Black Hole: a wide, dark area under a giant black hole that's tearing a star apart. The
-- pillars along the walls bend towards it, rocks drift up and are pulled apart into streams of
-- dust, sparks rise off the floor and a spacetime grid glows on it (MapBuilder builds the secret
-- lab under the floor).
function Themes.BlackHole(folder: Instance, zs: number, ze: number, rng: Random)
	local purple, hot, dark = rgb(170, 90, 255), rgb(255, 150, 70), rgb(18, 12, 34)
	local holeAt = Vector3.new(0, 175, ze + 90)

	-- Spacetime grid on the tile edges (the lines stop at the pit)
	local px, pz = Decor.LabPit(zs)
	local pitHalf = Decor.LabPitSize / 2 + 1
	local gridColor = rgb(130, 70, 255)
	local half = 95 -- (the area's half width: Areas.luau)
	for _, area in Areas.List do
		if area.Theme == "BlackHole" and area.HalfWidth then
			half = area.HalfWidth
		end
	end
	local function line(x0: number, x1: number, z0: number, z1: number)
		if x1 - x0 > 0.5 or z1 - z0 > 0.5 then
			Build.Decor({ Parent = folder, Name = "GridLine", Size = Vector3.new(math.max(0.3, x1 - x0), 0.1, math.max(0.3, z1 - z0)), Position = Vector3.new((x0 + x1) / 2, 0.06, (z0 + z1) / 2), Color = gridColor, Material = Enum.Material.Neon, Transparency = 0.55 })
		end
	end
	local x = -half + 20
	while x < half do
		if math.abs(x - px) <= pitHalf then
			line(x, x, zs, pz - pitHalf)
			line(x, x, pz + pitHalf, ze)
		else
			line(x, x, zs, ze)
		end
		x += 20
	end
	local z = zs + 20
	while z < ze do
		if math.abs(z - pz) <= pitHalf then
			line(-half, px - pitHalf, z, z)
			line(px + pitHalf, half, z, z)
		else
			line(-half, half, z, z)
		end
		z += 20
	end

	-- Pillars along the walls, bending towards the hole (harder the closer they are)
	z = zs + 14
	while z < ze - 10 do
		local pull = (z - zs) / (ze - zs)
		for _, side in { -1, 1 } do
			if side * (half - 9) > px - pitHalf and math.abs(z - pz) < pitHalf + 3 then
				continue -- not on the edge of the pit
			end
			local cf = CFrame.new(side * (half - 9), 0, z)
			for segment = 1, 3 do
				cf *= CFrame.Angles(pull * 0.12, 0, side * pull * 0.04)
				Build.Decor({ Parent = folder, Name = "Pillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(13, 3, 3), CFrame = cf * CFrame.new(0, 6.5, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = dark, Material = Enum.Material.Glass })
				Build.Decor({ Parent = folder, Name = "LightStrip", Size = Vector3.new(0.6, 13, 0.6), CFrame = cf * CFrame.new(-side * 1.6, 6.5, 0), Color = purple, Material = Enum.Material.Neon })
				if segment > 1 then
					Build.Decor({ Parent = folder, Name = "PillarJoint", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 3.8, 3.8), CFrame = cf * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(50, 40, 80), Material = Enum.Material.Metal })
				end
				cf *= CFrame.new(0, 13, 0)
			end
			Build.Ball(folder, cf.Position, 2.4, purple:Lerp(hot, pull), Enum.Material.Neon)
		end
		z += 26
	end

	-- Rocks drifting up towards the hole, stretched and shedding dust as they're pulled apart
	for _ = 1, 18 do
		local p = Vector3.new(rng:NextNumber(-85, 85), rng:NextNumber(16, 70), rng:NextNumber(zs + 10, ze - 10))
		local pull = (p.Z - zs) / (ze - zs)
		local toHole = (holeAt - p).Unit
		local side = toHole:Cross(Vector3.yAxis).Unit
		local facing = CFrame.fromMatrix(p, side, side:Cross(toHole), -toHole) * CFrame.Angles(0, 0, rng:NextNumber(0, math.pi))
		local size = rng:NextNumber(2, 5.5)
		local length = size * (1.1 + pull * 0.9)
		local rock = Build.Decor({ Parent = folder, Name = "Rock", Size = Vector3.new(size, size * 0.8, length), CFrame = facing, Color = rgb(40, 34, 55), Material = Enum.Material.Basalt })
		rock.CastShadow = false
		Build.Decor({ Parent = folder, Name = "Rock", Size = Vector3.new(size * 0.7, size * 0.7, length * 0.7), CFrame = facing * CFrame.new(size * 0.2, size * 0.15, length * 0.1) * CFrame.Angles(0.5, 0.6, 0.4), Color = rgb(52, 44, 70), Material = Enum.Material.Basalt }).CastShadow = false
		Build.Decor({ Parent = folder, Name = "RockCrack", Size = Vector3.new(0.25, size * 0.85, length * 0.9), CFrame = facing * CFrame.Angles(0, 0, 0.3), Color = purple:Lerp(hot, pull), Material = Enum.Material.Neon })
		local dust = glowBeam(rock, CFrame.new(), CFrame.new(0, 0, -size * 9))
		dust.Width0 = size * 0.8
		dust.Width1 = size * 0.1
		dust.Color = ColorSequence.new(purple, hot)
		dust.Transparency = NumberSequence.new(0.35, 1)
		dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
		dust.TextureMode = Enum.TextureMode.Wrap
		dust.TextureLength = size * 3
		dust.TextureSpeed = 0.6
	end

	-- Warning holograms, each beamed up from a projector on the floor
	for n, text in { "GRAVITY WELL", "SPACETIME UNSTABLE", "EXPERIMENT BH-01" } do
		local side = if n % 2 == 0 then 1 else -1
		local color = if n == 1 then rgb(255, 210, 0) else purple
		local at = Vector3.new(side * 66, 26 + n * 5, zs + 30 + n * 55)
		local holo = Instance.new("Model")
		holo.Name = "WarningHologram"
		neonSign(holo, CFrame.new(at) * CFrame.Angles(0, side * math.pi / 2 + rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.12, 0.12)), text, color, 24)
		Build.Decor({ Parent = holo, Name = "Projector", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 7, 7), CFrame = CFrame.new(at.X, 0.7, at.Z) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(40, 34, 60), Material = Enum.Material.Metal })
		Build.Decor({ Parent = holo, Name = "ProjectorLens", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 4, 4), CFrame = CFrame.new(at.X, 1.5, at.Z) * CFrame.Angles(0, 0, math.pi / 2), Color = color, Material = Enum.Material.Neon })
		Build.Decor({ Parent = holo, Name = "HoloBeam", Shape = Enum.PartType.Cylinder, Size = Vector3.new(at.Y - 2, 2.2, 2.2), CFrame = CFrame.new(at.X, (at.Y - 2) / 2 + 1.5, at.Z) * CFrame.Angles(0, 0, math.pi / 2), Color = color, Material = Enum.Material.Neon, Transparency = 0.7 })
		holo.Parent = folder
	end

	-- Sparks lifting off the floor and falling up into the hole
	local sparksPart = Build.Decor({ Parent = folder, Name = "Debris", Size = Vector3.new(170, 1, ze - zs - 20), Position = Vector3.new(0, 1, (zs + ze) / 2), Transparency = 1 })
	local sparks = Instance.new("ParticleEmitter")
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Rate = 30
	sparks.Lifetime = NumberRange.new(6, 9)
	sparks.Speed = NumberRange.new(2, 5)
	sparks.Acceleration = Vector3.new(0, 5, 4)
	sparks.SpreadAngle = Vector2.new(20, 20)
	sparks.Size = NumberSequence.new(0.35, 0.1)
	sparks.Color = ColorSequence.new(purple, hot)
	sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.2), NumberSequenceKeypoint.new(1, 1) })
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.LightEmission = 1
	sparks.Parent = sparksPart

	-- The black hole itself, over the end of the area, tearing a star apart
	Decor.BlackHole(folder, holeAt, 3.2, { View = Vector3.new(0, -0.45, -1), Tilt = 13, Roll = 8, JetLength = 9, Star = true })
	weather(folder, zs, ze, rgb(200, 170, 255), Enum.NormalId.Top, 30, 3, 0.3, 5)
end

--------------------------------------------------------------------------------
-- World 2: The Underworld - lava, fire and brimstone, lit like Molten Bakery:
-- ember gates -> brimstone bakery -> magma rivers -> soul caverns -> obsidian forge ->
-- inferno spires -> the molten core. Lava is tagged "Lava" and geysers "Geyser" so
-- client/UnderworldFX can make the lava churn and the geysers erupt.
--------------------------------------------------------------------------------
local LAVA = rgb(255, 90, 0)
local LAVA_HOT = rgb(255, 170, 40)
local OBSIDIAN = rgb(22, 18, 26)
local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

-- Glowing lava (Neon, no shadow), tagged so the client can make it churn.
local function lava(parent: Instance, props: Build.Props): BasePart
	props.Parent = parent
	props.Material = Enum.Material.Neon
	props.Color = props.Color or LAVA
	local part = Build.Decor(props)
	part.CastShadow = false
	CollectionService:AddTag(part, "Lava")
	return part
end

local function flames(part: BasePart, size: number, color: Color3?, secondary: Color3?)
	local fire = Instance.new("Fire")
	fire.Size = size
	fire.Heat = size * 1.5
	if color then
		fire.Color = color
		fire.SecondaryColor = secondary or color
	end
	fire.Parent = part
end

local function glowLight(part: BasePart, color: Color3, range: number, brightness: number?)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = math.min(60, range)
	light.Brightness = brightness or 1.5
	light.Parent = part
end

-- A pool of lava ringed by basalt, flames licking up (like Molten Bakery's).
local function lavaPool(folder: Instance, pos: Vector3, size: number, rng: Random): BasePart
	local pool = lava(folder, { Name = "LavaPool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, size, size), CFrame = CFrame.new(pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2) })
	flames(pool, size * 0.6)
	glowLight(pool, LAVA, size * 2)
	for n = 1, 4 do
		local angle = n / 4 * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local h = rng:NextNumber(1.5, 4)
		Build.Decor({ Parent = folder, Name = "Basalt", Size = Vector3.new(rng:NextNumber(2, 3.5), h, rng:NextNumber(2, 3.5)), CFrame = CFrame.new(pos + Vector3.new(math.cos(angle) * size * 0.55, h / 2, math.sin(angle) * size * 0.55)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 3), 0), Color = rgb(40, 34, 34), Material = Enum.Material.Basalt })
	end
	return pool
end

-- A stone brazier with a fire in it (blue soul fire in Soul Caverns).
local function brazier(folder: Instance, pos: Vector3, fire: Color3?, fire2: Color3?)
	Build.Pillar(folder, pos, 5, 1.4, rgb(40, 34, 34), Enum.Material.Basalt)
	Build.Decor({ Parent = folder, Name = "Brazier", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 4.4, 4.4), CFrame = CFrame.new(pos + Vector3.new(0, 5.4, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(60, 50, 45), Material = Enum.Material.Metal })
	local coals = lava(folder, { Name = "Coals", Shape = Enum.PartType.Ball, Size = Vector3.one * 3.4, CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)), Color = fire or LAVA_HOT })
	flames(coals, 6, fire, fire2)
	glowLight(coals, fire or rgb(255, 140, 40), 26, 2)
end

-- Lava pouring over a basalt ledge at `top`: a glowing ribbon whose texture flows downwards,
-- with a splash (and a pool, unless it falls into a river).
local function lavaFall(folder: Instance, top: Vector3, height: number, width: number, rng: Random, pool: boolean?)
	Build.Decor({ Parent = folder, Name = "LavaLedge", Size = Vector3.new(width + 3, 2.4, 5), Position = top + Vector3.new(0, 1.2, 0), Color = rgb(36, 28, 28), Material = Enum.Material.Basalt })
	local holder = Build.Decor({ Parent = folder, Name = "LavaFall", Size = Vector3.one, Position = top, Transparency = 1 })
	local fall = glowBeam(holder, CFrame.new(), CFrame.new(0, -height, 0))
	fall.Width0 = width
	fall.Width1 = width * 1.25
	fall.Color = ColorSequence.new(rgb(255, 200, 80), rgb(255, 90, 0))
	fall.Transparency = NumberSequence.new(0.05, 0.15)
	fall.LightEmission = 0.8
	fall.Texture = SMOKE_TEXTURE
	fall.TextureMode = Enum.TextureMode.Wrap
	fall.TextureLength = width * 1.5
	fall.TextureSpeed = 1.3
	fall.Segments = 6
	local glow = fall:Clone()
	glow.Width0 = width * 2.2
	glow.Width1 = width * 2.8
	glow.Color = ColorSequence.new(rgb(255, 130, 30))
	glow.Transparency = NumberSequence.new(0.7, 0.85)
	glow.TextureSpeed = 0.7
	glow.Parent = holder
	for _, beam in { fall, glow } do
		pcall(function()
			(beam :: any).Brightness = 1.4
		end)
	end
	local bottom = top - Vector3.new(0, height, 0)
	if pool ~= false then
		lavaPool(folder, bottom, width * 2.2, rng)
	end
	local splash = Build.Decor({ Parent = folder, Name = "LavaSplash", Size = Vector3.new(width, 0.5, 2), Position = bottom + Vector3.new(0, 0.5, 0), Transparency = 1 })
	local drops = Instance.new("ParticleEmitter")
	drops.EmissionDirection = Enum.NormalId.Top
	drops.Rate = 18
	drops.Speed = NumberRange.new(6, 12)
	drops.SpreadAngle = Vector2.new(40, 40)
	drops.Lifetime = NumberRange.new(0.6, 1)
	drops.Acceleration = Vector3.new(0, -30, 0)
	drops.Size = NumberSequence.new(0.6, 0)
	drops.Color = ColorSequence.new(rgb(255, 220, 90), rgb(255, 90, 0))
	drops.LightEmission = 1
	drops.Parent = splash
end

-- A tall obsidian spire (volcanic glass) with glowing cracks and a hot tip.
local function spire(folder: Instance, pos: Vector3, height: number, rng: Random, crack: Color3?)
	local base = math.max(4, height * 0.18)
	local cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0) * CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.06, 0.06))
	local steps = 4
	for i = 0, steps - 1 do
		local w = base * (1 - i / steps * 0.75)
		local h = height / steps
		local block = Build.Decor({ Parent = folder, Name = "Spire", Size = Vector3.new(w, h, w), CFrame = cf * CFrame.new(0, h * (i + 0.5), 0) * CFrame.Angles(0, i * 0.5, 0), Color = OBSIDIAN, Material = Enum.Material.Glass })
		lava(folder, { Name = "LavaCrack", Size = Vector3.new(0.3, h * 0.85, 0.35), CFrame = block.CFrame * CFrame.new(w / 2 + 0.05, 0, rng:NextNumber(-0.25, 0.25) * w) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), 0, 0), Color = crack or LAVA })
	end
	lava(folder, { Name = "SpireTip", Shape = Enum.PartType.Ball, Size = Vector3.one * base * 0.4, CFrame = cf * CFrame.new(0, height, 0), Color = crack or LAVA_HOT })
end

-- A chain of iron links from one point to another.
local function chain(folder: Instance, from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	local links = math.max(2, math.floor(length / 1.5))
	local along = (to - from).Unit
	local side = along:Cross(Vector3.yAxis)
	side = if side.Magnitude < 0.01 then Vector3.xAxis else side.Unit
	for i = 0, links - 1 do
		local at = from + along * (i + 0.5) * length / links
		Build.Decor({ Parent = folder, Name = "ChainLink", Size = Vector3.new(0.9, 1.7, 0.3), CFrame = CFrame.fromMatrix(at, side, along) * CFrame.Angles(0, if i % 2 == 0 then 0 else math.pi / 2, 0), Color = rgb(55, 50, 55), Material = Enum.Material.Metal })
	end
end

-- A lava geyser. It steams all the time and erupts now and then (UnderworldFX switches its
-- "Eruption" emitter on for a moment).
local function geyser(folder: Instance, pos: Vector3)
	Build.Decor({ Parent = folder, Name = "GeyserRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 7, 7), CFrame = CFrame.new(pos + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(45, 36, 34), Material = Enum.Material.Basalt })
	local vent = lava(folder, { Name = "GeyserVent", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.3, 4.5, 4.5), CFrame = CFrame.new(pos + Vector3.new(0, 0.62, 0)) * CFrame.Angles(0, 0, math.pi / 2) })
	local steam = Instance.new("Smoke")
	steam.Color = rgb(90, 70, 60)
	steam.Opacity = 0.15
	steam.RiseVelocity = 5
	steam.Size = 2
	steam.Parent = vent
	local jet = Build.Decor({ Parent = folder, Name = "Geyser", Size = Vector3.new(3, 1, 3), Position = pos + Vector3.new(0, 1.4, 0), Transparency = 1 })
	local burst = Instance.new("ParticleEmitter")
	burst.Name = "Eruption"
	burst.Enabled = false
	burst.EmissionDirection = Enum.NormalId.Top
	burst.Rate = 90
	burst.Speed = NumberRange.new(34, 48)
	burst.SpreadAngle = Vector2.new(9, 9)
	burst.Acceleration = Vector3.new(0, -45, 0)
	burst.Lifetime = NumberRange.new(1.3, 1.8)
	burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.6), NumberSequenceKeypoint.new(1, 0.6) })
	burst.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(255, 230, 120)), ColorSequenceKeypoint.new(0.4, rgb(255, 110, 20)), ColorSequenceKeypoint.new(1, rgb(90, 20, 10)) })
	burst.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.3), NumberSequenceKeypoint.new(1, 1) })
	burst.Texture = FIRE_TEXTURE
	burst.LightEmission = 1
	burst.Parent = jet
	CollectionService:AddTag(jet, "Geyser")
end

-- A brick bakery oven with a roaring fire, its mouth facing the lane.
local function oven(folder: Instance, pos: Vector3, side: number)
	local face = CFrame.new(pos) * CFrame.Angles(0, if side > 0 then math.pi / 2 else -math.pi / 2, 0)
	Build.Decor({ Parent = folder, Name = "Oven", Size = Vector3.new(12, 11, 10), CFrame = face * CFrame.new(0, 5.5, 0), Color = rgb(75, 45, 38), Material = Enum.Material.Brick })
	Build.Decor({ Parent = folder, Name = "OvenDome", Shape = Enum.PartType.Ball, Size = Vector3.one * 11, CFrame = face * CFrame.new(0, 11, 0), Color = rgb(70, 42, 36), Material = Enum.Material.Brick })
	local mouth = lava(folder, { Name = "OvenFire", Size = Vector3.new(7, 4.5, 0.4), CFrame = face * CFrame.new(0, 3.5, -5.05), Color = rgb(255, 120, 20) })
	flames(mouth, 5)
	glowLight(mouth, rgb(255, 120, 30), 28, 2.5)
	Build.Decor({ Parent = folder, Name = "OvenArch", Size = Vector3.new(8.4, 0.8, 0.8), CFrame = face * CFrame.new(0, 6.1, -5.2), Color = rgb(40, 30, 28), Material = Enum.Material.Metal })
	local chimney = Build.Decor({ Parent = folder, Name = "Chimney", Size = Vector3.new(2.6, 9, 2.6), CFrame = face * CFrame.new(3, 17, 2), Color = rgb(60, 40, 36), Material = Enum.Material.Brick })
	local smoke = Instance.new("Smoke")
	smoke.Color = rgb(60, 50, 50)
	smoke.RiseVelocity = 7
	smoke.Size = 4
	smoke.Opacity = 0.2
	smoke.Parent = chimney
end

local function embers(folder: Instance, zs: number, ze: number, rate: number?)
	weather(folder, zs, ze, rgb(255, 140, 30), Enum.NormalId.Top, rate or 45, 6, 0.35, 5)
end

-- Obsidian gates with a raised portcullis and a welcome sign, braziers and lava pools.
function Themes.EmberGates(folder: Instance, zs: number, ze: number, rng: Random)
	local gateZ = zs + 22
	for _, side in { -1, 1 } do
		local base = Vector3.new(side * 50, 0, gateZ)
		Build.Decor({ Parent = folder, Name = "GateTower", Size = Vector3.new(10, 46, 10), Position = base + Vector3.new(0, 23, 0), Color = OBSIDIAN, Material = Enum.Material.Glass })
		for y = 10, 40, 10 do
			lava(folder, { Name = "GateBand", Size = Vector3.new(10.4, 0.6, 10.4), Position = base + Vector3.new(0, y, 0) })
		end
		brazier(folder, base + Vector3.new(0, 46, 0))
		chain(folder, base + Vector3.new(-side * 5, 40, 3), Vector3.new(side * 60, 56, gateZ + 40))
	end
	Build.Decor({ Parent = folder, Name = "GateLintel", Size = Vector3.new(110, 6, 8), Position = Vector3.new(0, 49, gateZ), Color = OBSIDIAN, Material = Enum.Material.Glass })
	lava(folder, { Name = "GateGlow", Size = Vector3.new(90, 0.6, 8.4), Position = Vector3.new(0, 45.9, gateZ) })
	for x = -40, 40, 5 do
		Build.Decor({ Parent = folder, Name = "Portcullis", Size = Vector3.new(0.8, 8, 0.8), Position = Vector3.new(x, 42, gateZ), Color = rgb(50, 46, 50), Material = Enum.Material.Metal })
	end
	neonSign(folder, CFrame.new(0, 54.5, gateZ), "WELCOME TO THE UNDERWORLD", rgb(255, 120, 30), 50)
	alongEdges(zs + 40, ze, 30, rng, function(pos)
		if rng:NextNumber() < 0.5 then
			brazier(folder, pos)
		else
			lavaPool(folder, pos, rng:NextNumber(8, 12), rng)
		end
	end)
	for n = 1, 6 do
		spire(folder, Vector3.new((if n % 2 == 0 then 1 else -1) * rng:NextNumber(53, 57), 0, rng:NextNumber(zs + 50, ze - 10)), rng:NextNumber(18, 34), rng)
	end
	embers(folder, zs, ze)
end

-- Roaring ovens down both sides, burnt donuts, sulphur vents and a molten donut statue.
function Themes.BrimstoneBakery(folder: Instance, zs: number, ze: number, rng: Random)
	local z, i = zs + 25, 0
	while z < ze - 15 do
		i += 1
		local side = if i % 2 == 0 then 1 else -1
		oven(folder, Vector3.new(side * 52, 0, z), side)
		-- across the lane: a burnt donut cooling, or a lava pool
		if i % 2 == 0 then
			Decor.GiantDonut(folder, CFrame.new(-side * 50, 3.2, z) * CFrame.Angles(0, math.pi / 2, 0), 2.2, 2, rgb(50, 32, 28), rgb(255, 100, 20), { rgb(255, 210, 60) }, Enum.Material.Neon)
		else
			lavaPool(folder, Vector3.new(-side * 51, 0, z), 10, rng)
		end
		z += 28
	end
	for _ = 1, 5 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local vent = Build.Decor({ Parent = folder, Name = "SulphurVent", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 4, 4), CFrame = CFrame.new(side * rng:NextNumber(55, 58), 0.5, rng:NextNumber(zs + 10, ze - 10)) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(120, 110, 50), Material = Enum.Material.Basalt })
		local fumes = Instance.new("Smoke")
		fumes.Color = rgb(220, 200, 90)
		fumes.Opacity = 0.15
		fumes.RiseVelocity = 5
		fumes.Size = 3
		fumes.Parent = vent
	end
	Decor.DonutStatue(folder, Vector3.new(-48, 0, ze - 30), 5, rgb(60, 40, 35), rgb(255, 90, 0), { rgb(255, 220, 60) }, Enum.Material.Neon)
	embers(folder, zs, ze)
end

-- A river of lava down each side, lava falling into it from the walls.
function Themes.MagmaRivers(folder: Instance, zs: number, ze: number, rng: Random)
	for _, side in { -1, 1 } do
		local x = side * 51
		lava(folder, { Name = "LavaRiver", Size = Vector3.new(10, 0.3, ze - zs), Position = Vector3.new(x, 0.15, (zs + ze) / 2), Color = rgb(255, 80, 0) })
		Build.Decor({ Parent = folder, Name = "Bank", Size = Vector3.new(1.5, 1.2, ze - zs), Position = Vector3.new(x - side * 5.7, 0.6, (zs + ze) / 2), Color = rgb(36, 28, 28), Material = Enum.Material.Basalt })
		for _ = 1, 8 do
			Build.Decor({ Parent = folder, Name = "Crust", Size = Vector3.new(rng:NextNumber(2, 4), 0.4, rng:NextNumber(2, 5)), CFrame = CFrame.new(x + rng:NextNumber(-3, 3), 0.35, rng:NextNumber(zs + 5, ze - 5)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color = rgb(40, 30, 28), Material = Enum.Material.Basalt })
		end
		-- bright blobs drifting downstream
		local flow = Build.Decor({ Parent = folder, Name = "LavaFlow", Size = Vector3.new(8, 0.5, ze - zs), Position = Vector3.new(x, 0.6, (zs + ze) / 2), Transparency = 1 })
		local blobs = Instance.new("ParticleEmitter")
		blobs.EmissionDirection = Enum.NormalId.Top
		blobs.Rate = 20
		blobs.Speed = NumberRange.new(0.3, 0.8)
		blobs.Acceleration = Vector3.new(0, 0, 4)
		blobs.Lifetime = NumberRange.new(3, 5)
		blobs.Size = NumberSequence.new(1.2, 0.4)
		blobs.Color = ColorSequence.new(rgb(255, 230, 120), rgb(255, 110, 20))
		blobs.Transparency = NumberSequence.new(0.2, 1)
		blobs.LightEmission = 1
		blobs.Parent = flow
		for z = zs + 40, ze - 30, 70 do
			lavaFall(folder, Vector3.new(side * 58, 44, z), 44, 5, rng, false)
		end
	end
	for _ = 1, 4 do
		spire(folder, Vector3.new((if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(57, 59), 0, rng:NextNumber(zs + 10, ze - 10)), rng:NextNumber(20, 30), rng)
	end
	embers(folder, zs, ze, 55)
end

-- A cave: rock arches with stalactites, blue soul fire, glowing crystals and wisps.
function Themes.SoulCaverns(folder: Instance, zs: number, ze: number, rng: Random)
	local soul, soulHot = rgb(70, 220, 255), rgb(200, 245, 255)
	for z = zs + 30, ze - 20, 45 do
		Build.Decor({ Parent = folder, Name = "CaveArch", Size = Vector3.new(124, 8, 10), Position = Vector3.new(0, 52, z), Color = rgb(30, 32, 42), Material = Enum.Material.Rock })
		for _ = 1, 9 do
			local x = rng:NextNumber(-55, 55)
			local length = rng:NextNumber(6, 16)
			Build.Decor({ Parent = folder, Name = "Stalactite", Size = Vector3.new(3, length * 0.6, 3), Position = Vector3.new(x, 48 - length * 0.3, z + rng:NextNumber(-3, 3)), Color = rgb(34, 36, 48), Material = Enum.Material.Rock })
			Build.Decor({ Parent = folder, Name = "Stalactite", Size = Vector3.new(1.5, length * 0.4, 1.5), Position = Vector3.new(x, 48 - length * 0.8, z), Color = rgb(34, 36, 48), Material = Enum.Material.Rock })
			lava(folder, { Name = "SoulDrip", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.8, CFrame = CFrame.new(x, 48 - length - 0.2, z), Color = soul })
		end
	end
	alongEdges(zs + 10, ze, 32, rng, function(pos)
		brazier(folder, pos, soul, soulHot)
	end)
	for n = 1, 10 do
		local side = if n % 2 == 0 then 1 else -1
		crystal(folder, Vector3.new(side * rng:NextNumber(52, 57), 0, rng:NextNumber(zs + 10, ze - 10)), if n % 3 == 0 then rgb(170, 110, 255) else soul, rng:NextNumber(4, 8), rng, n % 3 == 0)
	end
	for _ = 1, 5 do
		ringOfBalls(folder, CFrame.new(rng:NextNumber(-35, 35), rng:NextNumber(18, 34), rng:NextNumber(zs + 20, ze - 20)) * CFrame.Angles(math.pi / 2, 0, 0), rng:NextNumber(3, 5), 0.9, soulHot, 6, "SpinSlow")
	end
	weather(folder, zs, ze, soul, Enum.NormalId.Top, 35, 2, 0.3, 7)
end

-- Forges full of glowing coals, anvils throwing sparks, hammers hanging on chains.
function Themes.ObsidianForge(folder: Instance, zs: number, ze: number, rng: Random)
	local z, i = zs + 20, 0
	while z < ze - 15 do
		i += 1
		local side = if i % 2 == 0 then 1 else -1
		local pos = Vector3.new(side * 51, 0, z)
		Build.Decor({ Parent = folder, Name = "Hearth", Size = Vector3.new(9, 3, 12), Position = pos + Vector3.new(0, 1.5, 0), Color = rgb(50, 44, 48), Material = Enum.Material.Cobblestone })
		local coals = lava(folder, { Name = "ForgeCoals", Size = Vector3.new(7, 0.6, 10), Position = pos + Vector3.new(0, 3.2, 0) })
		flames(coals, 6)
		glowLight(coals, rgb(255, 130, 40), 26, 2.5)
		Build.Decor({ Parent = folder, Name = "ForgeHood", Size = Vector3.new(8, 6, 8), Position = pos + Vector3.new(0, 14, 0), Color = rgb(40, 36, 40), Material = Enum.Material.Metal })
		local chimney = Build.Decor({ Parent = folder, Name = "ForgeChimney", Size = Vector3.new(3, 30, 3), Position = pos + Vector3.new(0, 32, 0), Color = rgb(34, 30, 34), Material = Enum.Material.Metal })
		local smoke = Instance.new("Smoke")
		smoke.Color = rgb(50, 45, 45)
		smoke.Opacity = 0.2
		smoke.RiseVelocity = 8
		smoke.Parent = chimney
		-- an anvil with a glowing bar that throws sparks
		local anvil = pos + Vector3.new(-side * 7, 0, 5)
		Build.Decor({ Parent = folder, Name = "Anvil", Size = Vector3.new(2.4, 2.5, 2.4), Position = anvil + Vector3.new(0, 1.25, 0), Color = rgb(45, 45, 50), Material = Enum.Material.Metal })
		Build.Decor({ Parent = folder, Name = "Anvil", Size = Vector3.new(1.4, 1, 1.4), Position = anvil + Vector3.new(0, 3, 0), Color = rgb(45, 45, 50), Material = Enum.Material.Metal })
		Build.Decor({ Parent = folder, Name = "Anvil", Size = Vector3.new(2.2, 1.4, 5), Position = anvil + Vector3.new(0, 4.2, 0), Color = rgb(55, 55, 60), Material = Enum.Material.Metal })
		local bar = lava(folder, { Name = "HotBar", Size = Vector3.new(0.5, 0.5, 3), Position = anvil + Vector3.new(0, 5.15, 0), Color = LAVA_HOT })
		local sparks = Instance.new("ParticleEmitter")
		sparks.Rate = 8
		sparks.Speed = NumberRange.new(6, 12)
		sparks.SpreadAngle = Vector2.new(70, 70)
		sparks.Lifetime = NumberRange.new(0.4, 0.8)
		sparks.Acceleration = Vector3.new(0, -30, 0)
		sparks.Size = NumberSequence.new(0.25, 0)
		sparks.Color = ColorSequence.new(rgb(255, 240, 150), rgb(255, 140, 30))
		sparks.Texture = SPARK_TEXTURE
		sparks.LightEmission = 1
		sparks.Parent = bar
		-- a great hammer hanging from the wall on a chain
		chain(folder, Vector3.new(side * 59, 58, z + 9), Vector3.new(side * 53, 32, z + 9))
		Build.Decor({ Parent = folder, Name = "HammerHandle", Size = Vector3.new(0.8, 5, 0.8), Position = Vector3.new(side * 53, 29.5, z + 9), Color = rgb(70, 50, 35), Material = Enum.Material.Wood })
		Build.Decor({ Parent = folder, Name = "HammerHead", Size = Vector3.new(2.6, 3, 5.5), Position = Vector3.new(side * 53, 25.5, z + 9), Color = rgb(40, 40, 46), Material = Enum.Material.Metal })
		z += 34
	end
	for _, side in { -1, 1 } do
		lava(folder, { Name = "MoltenChannel", Size = Vector3.new(1.6, 0.25, ze - zs - 10), Position = Vector3.new(side * 57.5, 0.13, (zs + ze) / 2), Color = LAVA_HOT })
	end
	for _ = 1, 4 do
		spire(folder, Vector3.new((if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(55, 58), 0, rng:NextNumber(zs + 10, ze - 10)), rng:NextNumber(18, 28), rng)
	end
	weather(folder, zs, ze, rgb(255, 200, 80), Enum.NormalId.Top, 50, 9, 0.25, 3)
end

-- Towering spires with red-hot cracks, fire tornadoes, geysers and meteors.
function Themes.InfernoSpires(folder: Instance, zs: number, ze: number, rng: Random)
	local red = rgb(255, 60, 20)
	for z = zs + 12, ze - 8, 22 do
		for _, side in { -1, 1 } do
			spire(folder, Vector3.new(side * rng:NextNumber(52, 56), 0, z + rng:NextNumber(-5, 5)), rng:NextNumber(30, 55), rng, red)
		end
	end
	for n = 1, 3 do
		local pos = Vector3.new(if n % 2 == 0 then 49 else -49, 0, zs + n * (ze - zs) / 4)
		lavaPool(folder, pos, 9, rng)
		local column = Build.Decor({ Parent = folder, Name = "FireTornado", Size = Vector3.new(5, 1, 5), Position = pos + Vector3.new(0, 1, 0), Transparency = 1 })
		local swirl = Instance.new("ParticleEmitter")
		swirl.EmissionDirection = Enum.NormalId.Top
		swirl.Rate = 40
		swirl.Speed = NumberRange.new(14, 20)
		swirl.SpreadAngle = Vector2.new(6, 6)
		swirl.Lifetime = NumberRange.new(1.6, 2.2)
		swirl.Rotation = NumberRange.new(0, 360)
		swirl.RotSpeed = NumberRange.new(200, 300)
		swirl.Size = NumberSequence.new(3, 7)
		swirl.Texture = FIRE_TEXTURE
		swirl.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(255, 230, 120)), ColorSequenceKeypoint.new(0.5, rgb(255, 90, 20)), ColorSequenceKeypoint.new(1, rgb(80, 20, 15)) })
		swirl.Transparency = NumberSequence.new(0.2, 1)
		swirl.LightEmission = 1
		swirl.Parent = column
	end
	for n = 1, 4 do
		geyser(folder, Vector3.new(if n % 2 == 0 then 50 else -50, 0, zs + 20 + n * (ze - zs - 40) / 5))
	end
	local sky = Build.Decor({ Parent = folder, Name = "Meteors", Size = Vector3.new(120, 1, ze - zs), Position = Vector3.new(0, 90, (zs + ze) / 2), Transparency = 1 })
	local meteors = Instance.new("ParticleEmitter")
	meteors.EmissionDirection = Enum.NormalId.Bottom
	meteors.Rate = 3
	meteors.Speed = NumberRange.new(40, 60)
	meteors.SpreadAngle = Vector2.new(20, 20)
	meteors.Lifetime = NumberRange.new(1.2, 1.8)
	meteors.Orientation = Enum.ParticleOrientation.VelocityParallel
	meteors.Size = NumberSequence.new(2, 1)
	meteors.Texture = FIRE_TEXTURE
	meteors.Color = ColorSequence.new(rgb(255, 200, 90), rgb(255, 60, 10))
	meteors.LightEmission = 1
	meteors.Parent = sky
	embers(folder, zs, ze, 55)
end

-- The heart of the Underworld: a huge molten core chained over the end of the lane, ringed by
-- fire, with lava lakes, geysers and lava falls below it.
function Themes.MoltenCore(folder: Instance, zs: number, ze: number, rng: Random)
	local center = CFrame.new(0, 58, ze - 14)
	local core = lava(folder, { Name = "MoltenCore", Shape = Enum.PartType.Ball, Size = Vector3.one * 30, CFrame = center, Color = LAVA_HOT })
	Build.Decor({ Parent = folder, Name = "CoreHeat", Shape = Enum.PartType.Ball, Size = Vector3.one * 38, CFrame = center, Color = rgb(255, 90, 20), Material = Enum.Material.ForceField, Transparency = 0.25 })
	flames(core, 20)
	glowLight(core, rgb(255, 130, 40), 60, 3)
	for i = 1, 3 do
		ringOfBalls(folder, center * CFrame.Angles(i * 0.9, i * 0.6, 0), 22 + i * 4, 2, if i == 2 then rgb(255, 220, 80) else rgb(255, 90, 20), 24, "SpinSlow")
	end
	for _, side in { -1, 1 } do
		chain(folder, Vector3.new(side * 60, 60, ze - 40), center.Position + Vector3.new(side * 14, 0, -8))
		lava(folder, { Name = "LavaLake", Size = Vector3.new(12, 0.3, ze - zs - 20), Position = Vector3.new(side * 52, 0.15, (zs + ze) / 2) })
		for n = 1, 3 do
			geyser(folder, Vector3.new(side * 52, 0, zs + n * (ze - zs) / 4 + side * 10))
		end
		lavaFall(folder, Vector3.new(side * 58, 44, zs + (if side < 0 then 50 else 110)), 44, 6, rng, false)
	end
	alongEdges(zs + 15, ze - 20, 40, rng, function(pos)
		brazier(folder, Vector3.new(math.sign(pos.X) * 44, 0, pos.Z)) -- on the lake shore
	end)
	Decor.DonutStatue(folder, Vector3.new(-44, 0, ze - 45), 6, rgb(70, 30, 20), rgb(255, 170, 40), { rgb(255, 230, 120) }, Enum.Material.Neon)
	weather(folder, zs, ze, rgb(255, 150, 40), Enum.NormalId.Top, 70, 7, 0.4, 5)
end

-- Shared with WorldDecor (The Underworld's hub and the lane's sides)
Decor.Spire = spire
Decor.LavaFall = lavaFall
Decor.Brazier = brazier
Decor.Lava = lava

-- Frosting Falls: a lake biome. Two big ponds with lily pads and pink lotus flowers, reeds and
-- rocks round their edges, trees along the walls and an icing waterfall pouring into the far pond.
function Themes.Lake(folder: Instance, zs: number, ze: number, rng: Random)
	local water = rgb(70, 170, 235)
	local function pond(center: Vector3, rx: number, rz: number)
		-- an oval of overlapping discs (the water), a sandy rim, lily pads, lotus flowers and reeds
		for n = 0, 4 do
			local t = (n - 2) / 2
			local c = center + Vector3.new(t * rx * 0.55, 0, 0)
			local r = rz * (1 - 0.35 * math.abs(t))
			Build.Decor({ Parent = folder, Name = "PondRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, r * 2 + 4, r * 2 + 4), CFrame = CFrame.new(c + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(225, 205, 150), Material = Enum.Material.Sand })
			Build.Decor({ Parent = folder, Name = "Water", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, r * 2, r * 2), CFrame = CFrame.new(c + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = water, Material = Enum.Material.Glass, Transparency = 0.15, Reflectance = 0.12 })
		end
		for _ = 1, 9 do
			local angle = rng:NextNumber(0, math.pi * 2)
			local d = rng:NextNumber(0.2, 0.75)
			local p = center + Vector3.new(math.cos(angle) * rx * d, 0.4, math.sin(angle) * rz * d)
			local size = rng:NextNumber(3, 5.5)
			Build.Decor({ Parent = folder, Name = "LilyPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, size, size), CFrame = CFrame.new(p) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(70, 160, 70), Material = Enum.Material.SmoothPlastic })
			if rng:NextNumber() < 0.45 then
				Build.Ball(folder, p + Vector3.new(0, 0.6, 0), 1.3, rgb(255, 150, 200), Enum.Material.SmoothPlastic)
			end
		end
		for _ = 1, 10 do
			local angle = rng:NextNumber(0, math.pi * 2)
			local p = center + Vector3.new(math.cos(angle) * (rx + 2), 0, math.sin(angle) * (rz + 2))
			for k = 0, 2 do
				local h = rng:NextNumber(3, 5.5)
				Build.Decor({ Parent = folder, Name = "Reed", Size = Vector3.new(0.35, h, 0.35), CFrame = CFrame.new(p + Vector3.new(k * 0.6, h / 2, rng:NextNumber(-0.5, 0.5))) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15)), Color = rgb(60, 150, 60), Material = Enum.Material.Grass })
			end
			if rng:NextNumber() < 0.4 then
				Build.Decor({ Parent = folder, Name = "Rock", Size = Vector3.new(rng:NextNumber(2, 4), rng:NextNumber(1.2, 2.5), rng:NextNumber(2, 4)), CFrame = CFrame.new(p + Vector3.new(1.5, 0.8, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), rng:NextNumber(-0.2, 0.2)), Color = rgb(140, 140, 135), Material = Enum.Material.Slate })
			end
		end
	end
	local length = ze - zs
	pond(Vector3.new(-26, 0, zs + length * 0.3), 30, 18)
	pond(Vector3.new(22, 0, zs + length * 0.62), 26, 16)
	alongEdges(zs, ze, 34, rng, function(pos)
		tree(folder, pos, rgb(115, 78, 45), rgb(90, 190, 80), nil, rng)
	end)
	alongEdges(zs + 15, ze, 34, rng, function(pos)
		bush(folder, pos, rgb(80, 175, 60), rng)
	end)
	scatter(zs, ze, 26, rng, function(pos)
		flower(folder, pos, rng)
	end)
	-- the icing waterfall the biome is named after, pouring down the left wall into a pink pool
	local z = zs + length * 0.82
	local fall = Build.Decor({ Parent = folder, Name = "IcingFall", Size = Vector3.new(1, 58, 18), Position = Vector3.new(-59.4, 29, z), Color = rgb(255, 170, 215), Material = Enum.Material.Glass, Transparency = 0.15 })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(fall.Color)
	emitter.Rate = 25
	emitter.Speed = NumberRange.new(3, 6)
	emitter.Lifetime = NumberRange.new(1, 2)
	emitter.Size = NumberSequence.new(1.2, 0)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Parent = fall
	Build.Decor({ Parent = folder, Name = "IcingPool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 24, 24), CFrame = CFrame.new(-50, 0.2, z) * CFrame.Angles(0, 0, math.pi / 2), Color = fall.Color, Material = Enum.Material.Glass, Transparency = 0.1 })
	Decor.DonutStatue(folder, Vector3.new(48, 0, zs + 40), 5, rgb(222, 165, 95), rgb(120, 200, 255), { rgb(255, 255, 255), rgb(255, 150, 200) })
end

-- Jellybean Jungle: palm trees and giant leaves along the walls, vines hanging over the edge,
-- tiki torches, mossy boulders and big jellybeans scattered in the grass.
function Themes.Jungle(folder: Instance, zs: number, ze: number, rng: Random)
	local function palm(pos: Vector3)
		local height = rng:NextNumber(16, 24)
		local lean = rng:NextNumber(-0.25, 0.25)
		local top = pos
		for i = 0, 5 do
			local y = i * height / 6
			local p = pos + Vector3.new(lean * y, y + height / 12, 0)
			Build.Decor({ Parent = folder, Name = "Trunk", Size = Vector3.new(2.2 - i * 0.15, height / 6 + 0.2, 2.2 - i * 0.15), CFrame = CFrame.new(p) * CFrame.Angles(0, i * 0.5, lean), Color = if i % 2 == 0 then rgb(130, 90, 50) else rgb(110, 75, 42), Material = Enum.Material.Wood })
			top = p
		end
		for n = 0, 5 do
			local angle = n / 6 * math.pi * 2
			Build.Decor({ Parent = folder, Name = "Frond", Size = Vector3.new(2.6, 0.4, 10), CFrame = CFrame.new(top + Vector3.new(0, height / 12, 0)) * CFrame.Angles(0, angle, 0) * CFrame.new(0, -1, 4.5) * CFrame.Angles(math.rad(-22), 0, 0), Color = if n % 2 == 0 then rgb(60, 170, 60) else rgb(80, 190, 70), Material = Enum.Material.Grass })
		end
		for n = 0, 2 do
			Build.Ball(folder, top + Vector3.new(math.cos(n * 2.1) * 1.2, -0.6, math.sin(n * 2.1) * 1.2), 1.4, rgb(120, 80, 40))
		end
	end
	local function bigLeaf(pos: Vector3, side: number)
		for n = 0, 2 do
			Build.Decor({ Parent = folder, Name = "Leaf", Size = Vector3.new(5, 0.4, 9), CFrame = CFrame.new(pos + Vector3.new(0, 2 + n, 0)) * CFrame.Angles(0, n * 1.6 + rng:NextNumber(0, 1), 0) * CFrame.new(0, 0, 3.5) * CFrame.Angles(math.rad(-30), 0, side * 0.2), Color = rgb(40 + n * 15, 150 + n * 10, 55), Material = Enum.Material.Grass })
		end
	end
	local function torch(pos: Vector3)
		Build.Pillar(folder, pos, 7, 0.9, rgb(120, 80, 45), Enum.Material.Wood)
		Build.Decor({ Parent = folder, Name = "TorchBowl", Size = Vector3.new(2, 1.2, 2), Position = pos + Vector3.new(0, 7.4, 0), Color = rgb(90, 60, 40), Material = Enum.Material.Wood })
		local flame = Build.Decor({ Parent = folder, Name = "Flame", Size = Vector3.new(1, 1, 1), Position = pos + Vector3.new(0, 8.3, 0), Transparency = 1 })
		local fire = Instance.new("Fire")
		fire.Size = 4
		fire.Heat = 7
		fire.Parent = flame
		local light = Instance.new("PointLight")
		light.Color = rgb(255, 170, 70)
		light.Range = 18
		light.Brightness = 1.6
		light.Parent = flame
	end
	alongEdges(zs, ze, 30, rng, function(pos, side)
		palm(pos)
		bigLeaf(pos + Vector3.new(-side * 6, 0, 8), side)
	end)
	for z = zs + 25, ze - 15, 60 do
		torch(Vector3.new(-42, 0, z))
		torch(Vector3.new(42, 0, z + 30))
	end
	-- vines hanging over the tops of the walls
	for z = zs + 10, ze - 10, 16 do
		for _, side in { -1, 1 } do
			local h = rng:NextNumber(12, 30)
			Build.Decor({ Parent = folder, Name = "Vine", Size = Vector3.new(0.6, h, 0.6), Position = Vector3.new(side * 59.2, 60 - h / 2, z + rng:NextNumber(-5, 5)), Color = rgb(50, 140, 50), Material = Enum.Material.Grass })
		end
	end
	local beans = { rgb(255, 70, 90), rgb(255, 200, 40), rgb(80, 200, 90), rgb(160, 90, 255), rgb(255, 140, 40), rgb(60, 170, 255) }
	scatter(zs, ze, 30, rng, function(pos)
		Build.Decor({ Parent = folder, Name = "Jellybean", Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 1.6, 1.6), CFrame = CFrame.new(pos + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color = beans[rng:NextInteger(1, #beans)], Material = Enum.Material.Glass, Transparency = 0.05 })
	end)
	scatter(zs, ze, 10, rng, function(pos)
		local p = Vector3.new(math.sign(pos.X) * rng:NextNumber(30, 44), 0, pos.Z)
		local height = rng:NextNumber(3, 5)
		Build.Decor({ Parent = folder, Name = "Boulder", Size = Vector3.new(rng:NextNumber(5, 8), height, rng:NextNumber(5, 8)), CFrame = CFrame.new(p + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color = rgb(120, 125, 110), Material = Enum.Material.Slate })
		Build.Decor({ Parent = folder, Name = "Moss", Size = Vector3.new(4, 0.6, 4), Position = p + Vector3.new(0, height + 0.2, 0), Color = rgb(70, 160, 60), Material = Enum.Material.Grass })
	end)
	Decor.DonutStatue(folder, Vector3.new(-48, 0, zs + 60), 5, rgb(222, 165, 95), rgb(90, 200, 90), { rgb(255, 70, 90), rgb(255, 200, 40), rgb(160, 90, 255) })
end

function Decor.BuildTheme(theme: string, folder: Instance, zs: number, ze: number, rng: Random, half: number?)
	local builder = Themes[theme]
	laneHalf = half or DESIGN_HALF
	if builder then
		builder(folder, zs, ze, rng)
	else
		warn("[Decor] Unknown theme " .. theme)
	end
end

return Decor
