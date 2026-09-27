--[[
	Decor: themed decoration for each area. Everything here is cosmetic and non-collidable so it
	never blocks players or the guard. The lane centre (|X| < ~44) is kept mostly clear.

	Areas get more magical the further you go: plain grass -> desert -> candy -> caves -> ice ->
	lava -> neon night city -> floating crystals -> a cosmic dimension. World 2 (Glaze Islands) goes
	beach -> coral reef -> pirate cove -> jelly jungle -> volcano, and World 3 (Dream Dimension)
	clouds -> toy factory -> haunted bakery -> clockwork void -> donut heaven.
]]

local CollectionService = game:GetService("CollectionService")

local Build = require(script.Parent.Build)

local Decor = {}

local rgb = Color3.fromRGB

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
	for i = 1, 4 do
		local angle = i / 4 * math.pi
		Build.Decor({ Parent = parent, Name = "Cane", Size = Vector3.new(1.4, 1.4, 1.4), Position = pos + Vector3.new(1.5 - math.cos(angle) * 1.5, 12 + math.sin(angle) * 1.6, 0), Color = if i % 2 == 0 then red else white, Material = Enum.Material.SmoothPlastic })
	end
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
	-- Stalactites hanging from the ceiling beams
	for z = zs + 10, ze - 10, 20 do
		Build.Decor({ Parent = folder, Name = "CaveBeam", Size = Vector3.new(124, 4, 6), Position = Vector3.new(0, 58, z), Color = rgb(70, 40, 25), Material = Enum.Material.Rock })
		for n = 1, 4 do
			Build.Decor({ Parent = folder, Name = "Stalactite", Size = Vector3.new(2, 6, 2), Position = Vector3.new(rng:NextNumber(-50, 50), 53, z), Color = rgb(90, 50, 30), Material = Enum.Material.Slate })
		end
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
-- World 2: Glaze Islands
--------------------------------------------------------------------------------
local function palm(parent: Instance, pos: Vector3, rng: Random)
	local height = rng:NextNumber(12, 18)
	local lean = rng:NextNumber(-0.25, 0.25)
	for i = 0, 5 do
		local y = i * height / 6
		Build.Decor({ Parent = parent, Name = "PalmTrunk", Size = Vector3.new(1.6 - i * 0.12, height / 6 + 0.2, 1.6 - i * 0.12), CFrame = CFrame.new(pos + Vector3.new(lean * y, y + height / 12, 0)), Color = if i % 2 == 0 then rgb(150, 105, 60) else rgb(130, 90, 50), Material = Enum.Material.Wood })
	end
	local top = pos + Vector3.new(lean * height, height, 0)
	for n = 0, 5 do
		local angle = n / 6 * math.pi * 2
		Build.Decor({ Parent = parent, Name = "PalmLeaf", Size = Vector3.new(1.8, 0.3, 8), CFrame = CFrame.new(top) * CFrame.Angles(0, angle, 0) * CFrame.new(0, -0.8, -3.8) * CFrame.Angles(math.rad(-22), 0, 0), Color = rgb(60, 170, 60), Material = Enum.Material.Grass })
	end
	for n = 1, 3 do
		Build.Ball(parent, top + Vector3.new(rng:NextNumber(-0.8, 0.8), -0.8, rng:NextNumber(-0.8, 0.8)), 1.1, rgb(120, 80, 40))
	end
end

function Themes.Beach(folder: Instance, zs: number, ze: number, rng: Random)
	alongEdges(zs, ze, 24, rng, function(pos)
		palm(folder, pos, rng)
	end)
	-- Shallow sea along the right wall
	Build.Decor({ Parent = folder, Name = "Sea", Size = Vector3.new(14, 0.3, ze - zs - 4), Position = Vector3.new(52, 0.12, (zs + ze) / 2), Color = rgb(60, 190, 240), Material = Enum.Material.Glass, Transparency = 0.2 })
	Build.Decor({ Parent = folder, Name = "Foam", Size = Vector3.new(1.2, 0.32, ze - zs - 4), Position = Vector3.new(45, 0.13, (zs + ze) / 2), Color = rgb(255, 255, 255), Material = Enum.Material.SmoothPlastic })
	-- Umbrellas and towels
	local stripes = { rgb(255, 80, 80), rgb(255, 210, 50), rgb(60, 170, 255), rgb(255, 130, 200) }
	for n = 1, 5 do
		local pos = Vector3.new(rng:NextNumber(-44, -30), 0, zs + 15 + n * 26)
		local color = stripes[(n - 1) % #stripes + 1]
		Build.Pillar(folder, pos, 7, 0.35, rgb(240, 240, 240))
		Build.Decor({ Parent = folder, Name = "Umbrella", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 8, 8), CFrame = CFrame.new(pos + Vector3.new(0, 7, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = color, Material = Enum.Material.Fabric })
		Build.Decor({ Parent = folder, Name = "Towel", Size = Vector3.new(3.5, 0.12, 6), CFrame = CFrame.new(pos + Vector3.new(4, 0.06, 1)) * CFrame.Angles(0, 0.3, 0), Color = stripes[n % #stripes + 1], Material = Enum.Material.Fabric })
	end
	-- Sandcastle
	local castle = Vector3.new(-38, 0, zs + 95)
	Build.Decor({ Parent = folder, Name = "Sandcastle", Size = Vector3.new(10, 4, 10), Position = castle + Vector3.new(0, 2, 0), Color = rgb(225, 195, 130), Material = Enum.Material.Sand })
	for _, corner in { Vector3.new(-5, 0, -5), Vector3.new(5, 0, -5), Vector3.new(-5, 0, 5), Vector3.new(5, 0, 5) } do
		Build.Pillar(folder, castle + corner, 7, 3, rgb(225, 195, 130), Enum.Material.Sand)
	end
	-- An inflatable donut ring bobbing in the sea
	Decor.GiantDonut(folder, CFrame.new(53, 1.2, zs + 60) * CFrame.Angles(math.pi / 2, 0, 0), 3, 2.6, rgb(255, 255, 255), rgb(255, 100, 150), nil)
	weather(folder, zs, ze, rgb(255, 250, 220), Enum.NormalId.Top, 12, 1, 0.3, 6)
end

function Themes.Coral(folder: Instance, zs: number, ze: number, rng: Random)
	local corals = { rgb(255, 110, 150), rgb(255, 160, 60), rgb(190, 110, 255), rgb(80, 220, 200) }
	alongEdges(zs, ze, 14, rng, function(pos)
		local color = corals[rng:NextInteger(1, #corals)]
		local h = rng:NextNumber(4, 10)
		for i = 0, 3 do
			local y = i * h / 4
			Build.Ball(folder, pos + Vector3.new(rng:NextNumber(-1, 1), y + 1, rng:NextNumber(-1, 1)), 2.6 - i * 0.35, color, Enum.Material.SmoothPlastic)
		end
		Build.Ball(folder, pos + Vector3.new(0, h + 1.5, 0), 1.2, color:Lerp(Color3.new(1, 1, 1), 0.4), Enum.Material.Neon)
	end)
	-- Swaying seaweed
	scatter(zs, ze, 16, rng, function(pos)
		local p = Vector3.new(math.sign(pos.X) * rng:NextNumber(30, 44), 0, pos.Z)
		for i = 0, 3 do
			Build.Decor({ Parent = folder, Name = "Seaweed", Size = Vector3.new(0.6, 2.2, 0.3), CFrame = CFrame.new(p + Vector3.new(math.sin(i) * 0.4, 1.1 + i * 2, 0)) * CFrame.Angles(0, 0, math.sin(i * 1.7) * 0.25), Color = rgb(40, 150, 80), Material = Enum.Material.Grass })
		end
	end)
	-- Giant clams with glowing pearls
	for _, pos in { Vector3.new(-40, 0, zs + 45), Vector3.new(40, 0, zs + 120) } do
		Build.Decor({ Parent = folder, Name = "Clam", Shape = Enum.PartType.Ball, Size = Vector3.one * 7, Position = pos + Vector3.new(0, -1.5, 0), Color = rgb(240, 200, 220), Material = Enum.Material.SmoothPlastic })
		Build.Decor({ Parent = folder, Name = "ClamTop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 7, 7), CFrame = CFrame.new(pos + Vector3.new(0, 4, 2.5)) * CFrame.Angles(math.rad(-50), 0, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(240, 200, 220), Material = Enum.Material.SmoothPlastic })
		local pearl = Build.Ball(folder, pos + Vector3.new(0, 2.6, 0), 2, rgb(255, 255, 255), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = rgb(200, 240, 255)
		light.Range = 16
		light.Parent = pearl
	end
	-- Schools of fish circling overhead
	for n = 1, 3 do
		ringOfBalls(folder, CFrame.new(rng:NextNumber(-30, 30), rng:NextNumber(18, 30), rng:NextNumber(zs + 20, ze - 20)) * CFrame.Angles(math.pi / 2, 0, 0), rng:NextNumber(5, 8), 1.2, corals[n], 10, "SpinSlow")
	end
	weather(folder, zs, ze, rgb(220, 245, 255), Enum.NormalId.Top, 45, 3, 0.5, 8)
end

function Themes.Pirate(folder: Instance, zs: number, ze: number, rng: Random)
	-- Barrels and crates along the walls
	alongEdges(zs, ze, 16, rng, function(pos)
		if rng:NextNumber() < 0.5 then
			Build.Pillar(folder, pos, 4, 3.2, rgb(140, 95, 50), Enum.Material.WoodPlanks)
			Build.Decor({ Parent = folder, Name = "BarrelBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 3.3, 3.3), CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(70, 70, 75), Material = Enum.Material.Metal })
		else
			Build.Decor({ Parent = folder, Name = "Crate", Size = Vector3.new(4, 4, 4), CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), Color = rgb(170, 120, 70), Material = Enum.Material.WoodPlanks })
		end
	end)
	-- A pirate ship docked along the left wall
	local ship = Vector3.new(-50, 0, zs + 80)
	Build.Decor({ Parent = folder, Name = "Hull", Size = Vector3.new(12, 8, 60), Position = ship + Vector3.new(0, 4, 0), Color = rgb(90, 55, 30), Material = Enum.Material.WoodPlanks })
	Build.Decor({ Parent = folder, Name = "Deck", Size = Vector3.new(12.4, 0.6, 60.4), Position = ship + Vector3.new(0, 8, 0), Color = rgb(150, 105, 60), Material = Enum.Material.WoodPlanks })
	for i, z in { -14, 12 } do
		Build.Pillar(folder, ship + Vector3.new(0, 8, z), 28 - i * 4, 1.2, rgb(110, 75, 45), Enum.Material.Wood)
		Build.Decor({ Parent = folder, Name = "Sail", Size = Vector3.new(0.3, 14, 18), Position = ship + Vector3.new(1, 24 - i * 2, z), Color = rgb(245, 240, 225), Material = Enum.Material.Fabric })
	end
	Build.Decor({ Parent = folder, Name = "Flag", Size = Vector3.new(0.2, 3, 5), Position = ship + Vector3.new(0, 36, -14), Color = rgb(20, 20, 20), Material = Enum.Material.Fabric })
	-- Treasure chests spilling gold
	for _, pos in { Vector3.new(40, 0, zs + 40), Vector3.new(36, 0, zs + 130) } do
		Build.Decor({ Parent = folder, Name = "Chest", Size = Vector3.new(6, 3.5, 4), Position = pos + Vector3.new(0, 1.75, 0), Color = rgb(130, 80, 40), Material = Enum.Material.WoodPlanks })
		Build.Decor({ Parent = folder, Name = "ChestTrim", Size = Vector3.new(6.2, 0.5, 4.2), Position = pos + Vector3.new(0, 3.2, 0), Color = rgb(255, 205, 60), Material = Enum.Material.Foil })
		for n = 1, 10 do
			Build.Decor({ Parent = folder, Name = "Coin", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 1, 1), CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-5, 5), 0.1, rng:NextNumber(-4, 4))) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(255, 205, 60), Material = Enum.Material.Foil })
		end
	end
	for z = zs + 25, ze - 10, 40 do
		lamp(folder, Vector3.new(44, 0, z), rgb(255, 190, 90), 9)
	end
end

function Themes.Jungle(folder: Instance, zs: number, ze: number, rng: Random)
	local jelly = { rgb(255, 60, 160), rgb(80, 220, 255), rgb(255, 220, 60), rgb(160, 90, 255) }
	alongEdges(zs, ze, 20, rng, function(pos)
		tree(folder, pos, rgb(100, 70, 40), rgb(50, 150, 50), nil, rng)
		-- Hanging vines
		for n = 1, 3 do
			Build.Decor({ Parent = folder, Name = "Vine", Size = Vector3.new(0.3, rng:NextNumber(6, 10), 0.3), Position = pos + Vector3.new(rng:NextNumber(-3, 3), 10, rng:NextNumber(-3, 3)), Color = rgb(60, 130, 40), Material = Enum.Material.Grass })
		end
	end)
	-- Wobbly jelly blobs
	scatter(zs, ze, 14, rng, function(pos)
		local blob = Build.Ball(folder, pos + Vector3.new(0, 0.8, 0), rng:NextNumber(2, 3.5), jelly[rng:NextInteger(1, #jelly)], Enum.Material.Glass)
		blob.Transparency = 0.25
	end)
	-- Big leaves
	for n = 1, 10 do
		local x = (if n % 2 == 0 then 1 else -1) * rng:NextNumber(38, 46)
		Build.Decor({ Parent = folder, Name = "BigLeaf", Size = Vector3.new(5, 0.3, 9), CFrame = CFrame.new(x, 2, rng:NextNumber(zs + 10, ze - 10)) * CFrame.Angles(math.rad(35), rng:NextNumber(0, 6), 0), Color = rgb(70, 170, 60), Material = Enum.Material.Grass })
	end
	-- Jelly waterfall
	local fall = Build.Decor({ Parent = folder, Name = "JellyFall", Size = Vector3.new(1, 58, 18), Position = Vector3.new(59.4, 29, zs + 90), Color = rgb(255, 90, 180), Material = Enum.Material.Glass, Transparency = 0.2 })
	Build.Decor({ Parent = folder, Name = "JellyPool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 22, 22), CFrame = CFrame.new(52, 0.2, zs + 90) * CFrame.Angles(0, 0, math.pi / 2), Color = fall.Color, Material = Enum.Material.Glass, Transparency = 0.15 })
	weather(folder, zs, ze, rgb(210, 255, 120), Enum.NormalId.Top, 25, 1.5, 0.3, 6) -- fireflies
end

function Themes.Volcano(folder: Instance, zs: number, ze: number, rng: Random)
	-- The volcano at the back of the island
	local base = Vector3.new(0, 0, ze + 56)
	for level = 0, 8 do
		local d = 90 - level * 8.5
		Build.Decor({ Parent = folder, Name = "Volcano", Shape = Enum.PartType.Cylinder, Size = Vector3.new(8, d, d), CFrame = CFrame.new(base + Vector3.new(0, 4 + level * 8, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = if level % 2 == 0 then rgb(70, 55, 50) else rgb(60, 45, 42), Material = Enum.Material.Basalt })
	end
	local crater = Build.Decor({ Parent = folder, Name = "Crater", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 18, 18), CFrame = CFrame.new(base + Vector3.new(0, 72.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(255, 100, 0), Material = Enum.Material.Neon })
	local fire = Instance.new("Fire")
	fire.Size = 25
	fire.Heat = 25
	fire.Parent = crater
	-- Tiki torches along the lane
	alongEdges(zs, ze, 22, rng, function(pos)
		Build.Pillar(folder, pos, 7, 0.8, rgb(120, 80, 45), Enum.Material.Wood)
		local bowl = Build.Decor({ Parent = folder, Name = "TorchBowl", Size = Vector3.new(1.6, 1, 1.6), Position = pos + Vector3.new(0, 7.3, 0), Color = rgb(90, 60, 35), Material = Enum.Material.Wood })
		local torch = Instance.new("Fire")
		torch.Size = 3
		torch.Heat = 6
		torch.Parent = bowl
	end)
	-- Lava streams and obsidian rocks
	for n = 1, 4 do
		local x = (if n % 2 == 0 then 1 else -1) * rng:NextNumber(34, 44)
		Build.Decor({ Parent = folder, Name = "LavaStream", Size = Vector3.new(4, 0.3, 30), Position = Vector3.new(x, 0.15, zs + n * 32), Color = rgb(255, 90, 0), Material = Enum.Material.Neon })
	end
	scatter(zs, ze, 10, rng, function(pos)
		Build.Decor({ Parent = folder, Name = "Obsidian", Size = Vector3.new(2.5, rng:NextNumber(1.5, 3), 2.5), CFrame = CFrame.new(Vector3.new(math.sign(pos.X) * rng:NextNumber(30, 44), 1, pos.Z)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), 0), Color = rgb(30, 25, 40), Material = Enum.Material.Glass })
	end)
	weather(folder, zs, ze, rgb(255, 120, 30), Enum.NormalId.Top, 45, 6, 0.35, 5)
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
	-- Rainbow arch over the lane
	local colors = { rgb(255, 60, 60), rgb(255, 160, 40), rgb(255, 230, 60), rgb(80, 220, 90), rgb(60, 150, 255), rgb(170, 90, 255) }
	for i, color in colors do
		local radius = 44 - i * 2
		for n = 0, 16 do
			local angle = n / 16 * math.pi
			Build.Decor({ Parent = folder, Name = "Rainbow", Size = Vector3.new(2.2, 2.2, 2), Position = Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius * 0.8, zs + 100), Color = color, Material = Enum.Material.Neon })
		end
	end
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
	-- Giant gears turning on the walls
	for z = zs + 20, ze - 10, 36 do
		for _, side in { -1, 1 } do
			local radius = rng:NextNumber(7, 11)
			local cf = CFrame.new(side * 56, radius + 4, z) * CFrame.Angles(0, math.pi / 2, 0)
			local model = ringOfBalls(folder, cf, radius, 2.2, brass, 14, "SpinSlow")
			Build.Decor({ Parent = model, Name = "Hub", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, radius, radius), CFrame = cf * CFrame.Angles(0, math.pi / 2, 0), Color = rgb(120, 90, 50), Material = Enum.Material.Metal })
		end
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
	-- Clock tower with a glowing face
	local tower = Vector3.new(-40, 0, zs + 100)
	Build.Decor({ Parent = folder, Name = "ClockTower", Size = Vector3.new(10, 34, 10), Position = tower + Vector3.new(0, 17, 0), Color = rgb(70, 60, 90), Material = Enum.Material.Brick })
	Build.Decor({ Parent = folder, Name = "ClockFace", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 8, 8), CFrame = CFrame.new(tower + Vector3.new(5.2, 28, 0)), Color = rgb(255, 240, 200), Material = Enum.Material.Neon })
	for i = 0, 11 do
		local angle = i / 12 * math.pi * 2
		Build.Decor({ Parent = folder, Name = "ClockMark", Size = Vector3.new(0.3, 0.6, 0.3), Position = tower + Vector3.new(5.5, 28 + math.cos(angle) * 3.2, math.sin(angle) * 3.2), Color = rgb(40, 30, 20) })
	end
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
	-- The golden gates at the very end of the last lane, with the biggest donut of all
	for _, side in { -1, 1 } do
		Build.Decor({ Parent = folder, Name = "GatePillar", Size = Vector3.new(5, 40, 5), Position = Vector3.new(side * 24, 20, ze - 8), Color = gold, Material = Enum.Material.Foil })
	end
	for x = -20, 20, 4 do
		Build.Decor({ Parent = folder, Name = "GateBar", Size = Vector3.new(0.6, 30, 0.6), Position = Vector3.new(x, 15, ze - 8), Color = gold, Material = Enum.Material.Foil })
	end
	local donut = Decor.GiantDonut(folder, CFrame.new(0, 52, ze - 8), 12, 9, rgb(255, 215, 0), rgb(255, 255, 255), { rgb(255, 60, 60), rgb(255, 230, 60), rgb(60, 220, 90), rgb(60, 150, 255), rgb(200, 80, 255) }, Enum.Material.Neon)
	CollectionService:AddTag(donut, "DonutRainbow")
	weather(folder, zs, ze, rgb(255, 245, 200), Enum.NormalId.Top, 50, 1.5, 0.4, 9)
end

function Decor.BuildTheme(theme: string, folder: Instance, zs: number, ze: number, rng: Random)
	local builder = Themes[theme]
	if builder then
		builder(folder, zs, ze, rng)
	else
		warn("[Decor] Unknown theme " .. theme)
	end
end

return Decor
