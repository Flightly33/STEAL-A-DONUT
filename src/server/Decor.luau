--[[
	Decor: themed decoration for each area. Everything here is cosmetic and non-collidable so it
	never blocks players or the guard. The lane centre (|X| < ~44) is kept mostly clear.

	Areas get more magical the further you go: plain grass -> desert -> candy -> caves -> ice ->
	lava -> neon night city -> floating crystals -> a cosmic dimension.
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

function Decor.BuildTheme(theme: string, folder: Instance, zs: number, ze: number, rng: Random)
	local builder = Themes[theme]
	if builder then
		builder(folder, zs, ze, rng)
	else
		warn("[Decor] Unknown theme " .. theme)
	end
end

return Decor
