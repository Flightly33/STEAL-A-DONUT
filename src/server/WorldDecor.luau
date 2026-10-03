--[[
	WorldDecor: scenery for the hubs and skies of Worlds 2-4, so each world feels like its own place.
	Everything is cosmetic and non-collidable, and kept out of the way of the bases, treadmills,
	portals and the lane entrance.

	  World 2 The Underworld: a sea of lava round the hub and along the lane, obsidian spires,
	                         lava falls from floating rocks, braziers and embers.
	  World 3 Dream Dimension: cotton-candy trees, pastel clouds at every height, floating islands
	                         with waterfalls and rainbows, giant floating donuts, star rings and a
	                         crescent moon.
	  World 4 Cyber City:    a neon skyline around the hub and along the lane, flying cars, holo
	                         donuts and neon signs.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Areas = require(Shared.Areas)
local Layout = require(Shared.Layout)

local Build = require(script.Parent.Build)
local Decor = require(script.Parent.Decor)

local WorldDecor = {}

local rgb = Color3.fromRGB
local map = Config.Map

--------------------------------------------------------------------------------
-- Props
--------------------------------------------------------------------------------
local function cloud(parent: Instance, center: Vector3, size: number, rng: Random, color: Color3?)
	for _ = 1, 5 do
		Build.Ball(parent, center + Vector3.new(rng:NextNumber(-1, 1) * size, rng:NextNumber(-0.3, 0.4) * size, rng:NextNumber(-0.6, 0.6) * size), size * rng:NextNumber(0.9, 1.4), color or rgb(255, 255, 255), Enum.Material.SmoothPlastic)
	end
end

-- A floating island: a rocky cone underneath, grass on top, and something growing on it.
local function floatingIsland(parent: Instance, center: Vector3, size: number, rng: Random, top: Color3, rock: Color3, grow: (Vector3) -> ())
	for i = 0, 3 do
		local s = size * (1 - i * 0.22)
		Build.Decor({ Parent = parent, Name = "IslandRock", Size = Vector3.new(s, size * 0.22, s), CFrame = CFrame.new(center - Vector3.new(0, i * size * 0.22, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color = rock:Lerp(Color3.new(0, 0, 0), i * 0.08), Material = Enum.Material.Rock })
	end
	Build.Decor({ Parent = parent, Name = "IslandTop", Size = Vector3.new(size * 1.02, 1.2, size * 1.02), CFrame = CFrame.new(center + Vector3.new(0, size * 0.11 + 0.6, 0)), Color = top, Material = Enum.Material.Grass })
	grow(center + Vector3.new(0, size * 0.11 + 1.2, 0))
end

local function cottonCandyTree(parent: Instance, pos: Vector3, rng: Random)
	local h = rng:NextNumber(8, 14)
	Build.Pillar(parent, pos, h, 1, rgb(255, 255, 255))
	local color = ({ rgb(255, 170, 220), rgb(170, 220, 255), rgb(210, 180, 255), rgb(255, 230, 170) })[rng:NextInteger(1, 4)]
	for _ = 1, 3 do
		Build.Ball(parent, pos + Vector3.new(rng:NextNumber(-2, 2), h + rng:NextNumber(0, 3), rng:NextNumber(-2, 2)), rng:NextNumber(6, 9), color)
	end
end

local function rainbow(parent: Instance, center: Vector3, radius: number, facing: number)
	local colors = { rgb(255, 60, 60), rgb(255, 160, 40), rgb(255, 230, 60), rgb(80, 220, 90), rgb(60, 150, 255), rgb(170, 90, 255) }
	for i, color in colors do
		local r = radius - i * 1.6
		for n = 0, 14 do
			local angle = n / 14 * math.pi
			Build.Decor({ Parent = parent, Name = "Rainbow", Size = Vector3.new(1.8, 1.8, 1.6), CFrame = CFrame.new(center) * CFrame.Angles(0, facing, 0) * CFrame.new(math.cos(angle) * r, math.sin(angle) * r * 0.8, 0), Color = color, Material = Enum.Material.Neon, Transparency = 0.2 })
		end
	end
end

local function tower(parent: Instance, pos: Vector3, rng: Random)
	local w, d, h = rng:NextNumber(14, 24), rng:NextNumber(14, 24), rng:NextNumber(60, 150)
	local glow = ({ rgb(255, 40, 200), rgb(0, 230, 255), rgb(255, 220, 0), rgb(40, 255, 120), rgb(170, 90, 255) })[rng:NextInteger(1, 5)]
	Build.Decor({ Parent = parent, Name = "Tower", Size = Vector3.new(w, h, d), Position = pos + Vector3.new(0, h / 2, 0), Color = rgb(22, 22, 36), Material = Enum.Material.Metal })
	for y = 8, h - 6, 9 do
		Build.Decor({ Parent = parent, Name = "TowerWindows", Size = Vector3.new(w + 0.3, 1, d + 0.3), Position = pos + Vector3.new(0, y, 0), Color = glow, Material = Enum.Material.Neon, Transparency = 0.4 })
	end
	Build.Decor({ Parent = parent, Name = "Antenna", Size = Vector3.new(0.6, 14, 0.6), Position = pos + Vector3.new(0, h + 7, 0), Color = rgb(60, 60, 70), Material = Enum.Material.Metal })
	local beacon = Build.Ball(parent, pos + Vector3.new(0, h + 14.5, 0), 1.6, rgb(255, 40, 40), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 40, 40)
	light.Range = 20
	light.Parent = beacon
end

local function flyingCar(parent: Instance, pos: Vector3, rng: Random)
	local glow = ({ rgb(255, 40, 200), rgb(0, 230, 255), rgb(255, 220, 0) })[rng:NextInteger(1, 3)]
	local cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	Build.Decor({ Parent = parent, Name = "CarBody", Size = Vector3.new(4, 1.6, 8), CFrame = cf, Color = rgb(40, 40, 55), Material = Enum.Material.Metal })
	Build.Decor({ Parent = parent, Name = "CarRoof", Size = Vector3.new(3.4, 1.2, 4), CFrame = cf * CFrame.new(0, 1.3, 0.5), Color = rgb(120, 200, 255), Material = Enum.Material.Glass, Transparency = 0.3 })
	Build.Decor({ Parent = parent, Name = "CarGlow", Size = Vector3.new(4.2, 0.3, 8.2), CFrame = cf * CFrame.new(0, -0.9, 0), Color = glow, Material = Enum.Material.Neon })
end

--------------------------------------------------------------------------------
-- Worlds
--------------------------------------------------------------------------------
-- Spots inside a world's hub that are free (not bases, treadmills, portal or the lane entrance).
local function hubSpots(x0: number, rng: Random, count: number): { Vector3 }
	local spots = {}
	for _ = 1, count do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		table.insert(spots, Vector3.new(x0 + side * rng:NextNumber(20, 92), 0, rng:NextNumber(-(map.HubDepth - 40), -120)))
	end
	return spots
end

-- Positions along a world's whole lane (bridge + areas), outside the walls, for sky scenery.
local function alongLane(world: Areas.World, step: number, fn: (x: number, z: number, side: number) -> ())
	local laneEnd = Layout.LaneEnd(world.Id)
	for z = map.SafeZoneZ + 10, laneEnd, step do -- (the hub has its own scenery)
		for _, side in { -1, 1 } do
			fn(world.OffsetX + side * (map.LaneHalfWidth + 90), z, side)
		end
	end
end

-- World 2: The Underworld. A sea of lava all round the hub and along the whole lane (just under
-- the floors, outside the walls), with a crust of basalt drifting on it, obsidian spires rising out
-- of it, lava pouring from floating rocks, braziers in the hub and embers in the air.
local function underworld(folder: Instance, world: Areas.World, rng: Random)
	local x0 = world.OffsetX
	local function lavaSea(xMin: number, xMax: number, zMin: number, zMax: number)
		local z = zMin
		while z < zMax - 0.01 do
			local length = math.min(2000, zMax - z)
			Decor.Lava(folder, { Name = "LavaSea", Size = Vector3.new(xMax - xMin, 1, length), Position = Vector3.new((xMin + xMax) / 2, -2.5, z + length / 2), Color = rgb(190, 50, 8) })
			for _ = 1, math.clamp(math.floor((xMax - xMin) * length / 3000), 2, 30) do
				Build.Decor({ Parent = folder, Name = "Crust", Size = Vector3.new(rng:NextNumber(6, 16), 1, rng:NextNumber(6, 16)), CFrame = CFrame.new(rng:NextNumber(xMin, xMax), -1.8, rng:NextNumber(z, z + length)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color = rgb(36, 28, 28), Material = Enum.Material.Basalt })
			end
			z += length
		end
	end
	local hubBack, hubSide = -(map.HubDepth + 120), map.HubHalfWidth + 4
	for _, side in { -1, 1 } do
		local function strip(inner: number, outer: number, zMin: number, zMax: number)
			lavaSea(math.min(x0 + side * inner, x0 + side * outer), math.max(x0 + side * inner, x0 + side * outer), zMin, zMax)
		end
		strip(hubSide, hubSide + 190, hubBack, 60) -- beside the hub
		strip(map.LaneHalfWidth + 4, map.LaneHalfWidth + 230, 0, Layout.AreaStart(Areas.ByWorld[world.Id][1].Id)) -- beside the bridge
		for _, area in Areas.ByWorld[world.Id] do
			local zs, ze = Layout.AreaStart(area.Id), Layout.AreaEnd(area.Id)
			strip(Layout.AreaHalfWidth(area.Id) + 4, Layout.AreaHalfWidth(area.Id) + 230, zs, if area.Index == #Areas.ByWorld[world.Id] then ze + 60 else ze)
		end
	end
	lavaSea(x0 - hubSide - 190, x0 + hubSide + 190, hubBack, -(map.HubDepth + 4)) -- behind the hub
	-- Obsidian spires rising out of the lava round the hub and all along the lane
	for _ = 1, 16 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		Decor.Spire(folder, Vector3.new(x0 + side * rng:NextNumber(map.HubHalfWidth + 30, map.HubHalfWidth + 170), -2, rng:NextNumber(-(map.HubDepth + 100), 40)), rng:NextNumber(60, 140), rng)
	end
	for _ = 1, 6 do
		Decor.Spire(folder, Vector3.new(x0 + rng:NextNumber(-map.HubHalfWidth - 150, map.HubHalfWidth + 150), -2, rng:NextNumber(hubBack, -(map.HubDepth + 20))), rng:NextNumber(70, 150), rng)
	end
	alongLane(world, 110, function(x, z, side)
		Decor.Spire(folder, Vector3.new(x + side * rng:NextNumber(0, 70), -2, z + rng:NextNumber(-30, 30)), rng:NextNumber(40, 100), rng)
	end)
	-- Floating rocks pouring lava into the sea
	for n = 1, 4 do
		local side = if n % 2 == 0 then 1 else -1
		local top = Vector3.new(x0 + side * rng:NextNumber(map.HubHalfWidth + 40, map.HubHalfWidth + 130), rng:NextNumber(80, 110), rng:NextNumber(-(map.HubDepth + 40), -60))
		for i = 0, 2 do
			local size = 26 - i * 7
			Build.Decor({ Parent = folder, Name = "FloatingRock", Size = Vector3.new(size, 7, size), CFrame = CFrame.new(top + Vector3.new(0, 4 - i * 6, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color = rgb(40, 32, 32), Material = Enum.Material.Basalt })
		end
		Decor.LavaFall(folder, top + Vector3.new(0, -12, 0), top.Y - 10, 8, rng, false)
	end
	-- Braziers round the hub
	for _, pos in hubSpots(x0, rng, 12) do
		Decor.Brazier(folder, pos)
	end
	-- Embers drifting up over the hub
	local air = Build.Decor({ Parent = folder, Name = "Embers", Size = Vector3.new(map.HubHalfWidth * 2, 1, map.HubDepth), Position = Vector3.new(x0, 2, -map.HubDepth / 2), Transparency = 1 })
	local sparks = Instance.new("ParticleEmitter")
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Rate = 40
	sparks.Lifetime = NumberRange.new(6, 9)
	sparks.Speed = NumberRange.new(3, 6)
	sparks.SpreadAngle = Vector2.new(20, 20)
	sparks.Size = NumberSequence.new(0.35, 0.1)
	sparks.Color = ColorSequence.new(rgb(255, 200, 80), rgb(255, 80, 20))
	sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.2), NumberSequenceKeypoint.new(1, 1) })
	sparks.LightEmission = 1
	sparks.Parent = air
end

local function dream(folder: Instance, world: Areas.World, rng: Random)
	local x0 = world.OffsetX
	local pastel = { rgb(255, 210, 240), rgb(210, 230, 255), rgb(235, 215, 255), rgb(255, 245, 210), rgb(255, 255, 255) }
	-- Cotton-candy trees in the hub
	for _, pos in hubSpots(x0, rng, 16) do
		cottonCandyTree(folder, pos, rng)
	end
	-- Pastel clouds at every height over the hub
	for _ = 1, 22 do
		cloud(folder, Vector3.new(x0 + rng:NextNumber(-260, 260), rng:NextNumber(45, 150), rng:NextNumber(-(map.HubDepth + 40), 60)), rng:NextNumber(5, 11), rng, pastel[rng:NextInteger(1, #pastel)])
	end
	-- A crescent moon and a giant floating donut above the hub
	local moon = Vector3.new(x0 + 140, 170, -(map.HubDepth + 60))
	Build.Ball(folder, moon, 60, rgb(255, 250, 225), Enum.Material.Neon)
	Build.Ball(folder, moon + Vector3.new(-18, 8, 14), 56, rgb(40, 30, 70), Enum.Material.SmoothPlastic)
	local donut = Decor.GiantDonut(folder, CFrame.new(x0 - 120, 110, -200) * CFrame.Angles(0, 0.6, 0), 14, 10, rgb(255, 225, 150), rgb(255, 170, 230), { rgb(255, 255, 255), rgb(120, 220, 255), rgb(255, 230, 120) })
	local center = Build.Decor({ Parent = donut, Name = "Center", Size = Vector3.one, CFrame = CFrame.new(x0 - 120, 110, -200), Transparency = 1 })
	donut.PrimaryPart = center
	CollectionService:AddTag(donut, "SpinSlow")
	-- Floating islands with waterfalls and rainbows, star rings, and more donuts along the lane
	alongLane(world, 150, function(x, z, side)
		local roll = rng:NextNumber()
		if roll < 0.4 then
			local center2 = Vector3.new(x + side * rng:NextNumber(0, 60), rng:NextNumber(60, 120), z + rng:NextNumber(-40, 40))
			local size = rng:NextNumber(18, 32)
			floatingIsland(folder, center2, size, rng, rgb(170, 240, 170), rgb(200, 180, 230), function(topPos)
				cottonCandyTree(folder, topPos, rng)
			end)
			Build.Decor({ Parent = folder, Name = "Waterfall", Size = Vector3.new(3, 40, 1), Position = center2 + Vector3.new(size * 0.45, -20, 0), Color = rgb(170, 230, 255), Material = Enum.Material.Neon, Transparency = 0.5 })
			if rng:NextNumber() < 0.5 then
				rainbow(folder, center2 + Vector3.new(0, 4, 0), size * 0.9, if side > 0 then math.pi / 2 else -math.pi / 2)
			end
		elseif roll < 0.6 then
			local ring = Instance.new("Model")
			ring.Name = "StarRing"
			local c = CFrame.new(x + side * rng:NextNumber(0, 40), rng:NextNumber(70, 120), z) * CFrame.Angles(math.pi / 2, 0, 0)
			local core = Build.Decor({ Parent = ring, Name = "Center", Size = Vector3.one, CFrame = c, Transparency = 1 })
			for i = 0, 11 do
				local angle = i / 12 * math.pi * 2
				Build.Decor({ Parent = ring, Name = "Star", Shape = Enum.PartType.Ball, Size = Vector3.one * 2, CFrame = c * CFrame.new(math.cos(angle) * 8, math.sin(angle) * 8, 0), Color = rgb(255, 245, 170), Material = Enum.Material.Neon })
			end
			ring.PrimaryPart = core
			CollectionService:AddTag(ring, "SpinSlow")
			ring.Parent = folder
		elseif roll < 0.72 then
			Decor.GiantDonut(folder, CFrame.new(x + side * rng:NextNumber(0, 50), rng:NextNumber(70, 120), z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), rng:NextNumber(7, 11), 6, rgb(255, 225, 150), pastel[rng:NextInteger(1, #pastel)], { rgb(255, 255, 255), rgb(255, 120, 200) })
		else
			cloud(folder, Vector3.new(x + side * rng:NextNumber(0, 90), rng:NextNumber(60, 140), z), rng:NextNumber(7, 12), rng, pastel[rng:NextInteger(1, #pastel)])
		end
	end)
	-- Sparkles drifting down over the hub
	local sky = Build.Decor({ Parent = folder, Name = "DreamSparkles", Size = Vector3.new(460, 1, 260), Position = Vector3.new(x0, 60, -130), Transparency = 1 })
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(rgb(255, 220, 250), rgb(200, 230, 255))
	sparkles.LightEmission = 1
	sparkles.Rate = 60
	sparkles.Speed = NumberRange.new(2, 5)
	sparkles.Lifetime = NumberRange.new(8, 12)
	sparkles.Size = NumberSequence.new(0.5, 0)
	sparkles.EmissionDirection = Enum.NormalId.Bottom
	sparkles.Parent = sky
end

local function cyber(folder: Instance, world: Areas.World, rng: Random)
	local x0 = world.OffsetX
	-- Dark city ground under the whole skyline, so the towers stand on something instead of floating
	-- in the void (it sits just under the floors, outside the walls)
	local function ground(xMin: number, xMax: number, zMin: number, zMax: number)
		local z = zMin
		while z < zMax - 0.01 do
			local length = math.min(2000, zMax - z)
			Build.Decor({ Parent = folder, Name = "CityGround", Size = Vector3.new(xMax - xMin, 1, length), Position = Vector3.new((xMin + xMax) / 2, -0.8, z + length / 2), Color = rgb(16, 14, 30), Material = Enum.Material.SmoothPlastic })
			z += length
		end
	end
	local hubBack, hubSide = -(map.HubDepth + 80), map.HubHalfWidth + 4
	for _, side in { -1, 1 } do
		local function strip(inner: number, outer: number, zMin: number, zMax: number)
			ground(math.min(x0 + side * inner, x0 + side * outer), math.max(x0 + side * inner, x0 + side * outer), zMin, zMax)
		end
		strip(hubSide, hubSide + 110, hubBack, 60) -- beside the hub
		local laneWall = map.LaneHalfWidth + 4
		local firstArea = Layout.AreaStart(Areas.ByWorld[world.Id][1].Id)
		strip(laneWall, laneWall + 170, 0, firstArea) -- beside the bridge
		for _, area in Areas.ByWorld[world.Id] do
			local zs, ze = Layout.AreaStart(area.Id), Layout.AreaEnd(area.Id)
			strip(Layout.AreaHalfWidth(area.Id) + 4, Layout.AreaHalfWidth(area.Id) + 174, zs, if area.Index == #Areas.ByWorld[world.Id] then ze + 20 else ze)
		end
	end
	ground(x0 - hubSide - 110, x0 + hubSide + 110, hubBack, -(map.HubDepth + 4)) -- behind the hub
	-- A skyline all around the hub (outside its walls)
	for z = -(map.HubDepth + 40), 40, 34 do
		for _, side in { -1, 1 } do
			tower(folder, Vector3.new(x0 + side * rng:NextNumber(map.HubHalfWidth + 25, map.HubHalfWidth + 70), 0, z), rng)
		end
	end
	for x = x0 - map.HubHalfWidth - 10, x0 + map.HubHalfWidth + 10, 36 do
		tower(folder, Vector3.new(x, 0, rng:NextNumber(-(map.HubDepth + 60), -(map.HubDepth + 30))), rng)
	end
	-- Flying cars and holo donuts over the hub
	for _ = 1, 14 do
		flyingCar(folder, Vector3.new(x0 + rng:NextNumber(-220, 220), rng:NextNumber(50, 110), rng:NextNumber(-(map.HubDepth + 20), 20)), rng)
	end
	for n = 1, 3 do
		local c = CFrame.new(x0 + (n - 2) * 70, 70, -200)
		local holo = Decor.GiantDonut(folder, c, 9, 6, rgb(0, 230, 255), rgb(255, 40, 200), nil, Enum.Material.Neon)
		for _, part in holo:GetChildren() do
			if part:IsA("BasePart") then
				part.Transparency = 0.45
			end
		end
		local core = Build.Decor({ Parent = holo, Name = "Center", Size = Vector3.one, CFrame = c, Transparency = 1 })
		holo.PrimaryPart = core
		CollectionService:AddTag(holo, "SpinSlow")
	end
	-- Street lamps in the hub
	for _, pos in hubSpots(x0, rng, 10) do
		Build.Pillar(folder, pos, 14, 0.6, rgb(50, 50, 60), Enum.Material.Metal)
		local bulb = Build.Ball(folder, pos + Vector3.new(0, 14.6, 0), 1.8, rgb(0, 230, 255), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = rgb(0, 230, 255)
		light.Range = 22
		light.Brightness = 1.5
		light.Parent = bulb
	end
	-- The skyline keeps going along the lane
	alongLane(world, 95, function(x, z, side)
		tower(folder, Vector3.new(x + side * rng:NextNumber(0, 60), 0, z + rng:NextNumber(-15, 15)), rng)
		if rng:NextNumber() < 0.3 then
			flyingCar(folder, Vector3.new(x - side * rng:NextNumber(20, 60), rng:NextNumber(65, 100), z), rng)
		end
	end)
end

-- World 2: Donut Land's layout under a galactic night sky: planets, a spiral galaxy over the hub,
-- nebulae, asteroids, star lamps and falling stardust.
local function cosmos(folder: Instance, world: Areas.World, rng: Random)
	local x0 = world.OffsetX
	local colors = { rgb(255, 150, 90), rgb(120, 200, 255), rgb(200, 140, 255), rgb(255, 220, 120), rgb(120, 255, 190) }
	local function planet(position: Vector3, size: number)
		local color = colors[rng:NextInteger(1, #colors)]
		local ball = Build.Ball(folder, position, size, color, Enum.Material.SmoothPlastic)
		ball.CastShadow = false
		if rng:NextNumber() < 0.5 then
			Build.Decor({
				Parent = folder, Name = "PlanetRing", Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.4, size * 1.9, size * 1.9),
				CFrame = CFrame.new(position) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), 0, math.pi / 2 + rng:NextNumber(-0.4, 0.4)),
				Color = color:Lerp(Color3.new(1, 1, 1), 0.4), Material = Enum.Material.Neon, Transparency = 0.4,
			})
		end
	end
	for _ = 1, 6 do
		planet(Vector3.new(x0 + rng:NextNumber(-250, 250), rng:NextNumber(80, 160), rng:NextNumber(-(map.HubDepth + 60), -40)), rng:NextNumber(14, 34))
	end
	alongLane(world, 150, function(x, z, side)
		planet(Vector3.new(x + side * rng:NextNumber(20, 80), rng:NextNumber(70, 140), z + rng:NextNumber(-30, 30)), rng:NextNumber(12, 30))
	end)
	-- Twinkling stars over the whole world
	local sky = Build.Decor({ Parent = folder, Name = "Stars", Size = Vector3.new(700, 1, Layout.LaneEnd(world.Id) + map.HubDepth + 200), Position = Vector3.new(x0, 170, (Layout.LaneEnd(world.Id) - map.HubDepth) / 2), Transparency = 1 })
	local stars = Instance.new("ParticleEmitter")
	stars.Color = ColorSequence.new(rgb(255, 255, 255), rgb(190, 170, 255))
	stars.LightEmission = 1
	stars.Rate = 60
	stars.Lifetime = NumberRange.new(3, 5)
	stars.Speed = NumberRange.new(0)
	stars.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 1.6), NumberSequenceKeypoint.new(1, 0) })
	stars.Parent = sky

	-- A spiral galaxy hanging over the back of the hub: a bright core and two arms of stars
	local galaxy = CFrame.new(x0 + 40, 230, -(map.HubDepth + 260)) * CFrame.Angles(math.rad(62), math.rad(-18), 0)
	local core = Build.Ball(folder, galaxy.Position, 34, rgb(255, 236, 205), Enum.Material.Neon)
	core.CastShadow = false
	local halo = Build.Ball(folder, galaxy.Position, 70, rgb(255, 190, 150), Enum.Material.ForceField)
	halo.Transparency = 0.35
	Build.Decor({ Parent = folder, Name = "GalaxyDisk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 420, 420), CFrame = galaxy * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(120, 80, 220), Material = Enum.Material.ForceField, Transparency = 0.45 })
	local armColors = { rgb(150, 190, 255), rgb(210, 160, 255), rgb(255, 170, 220) }
	for arm = 0, 1 do
		for i = 1, 46 do
			local f = i / 46
			local angle = arm * math.pi + f * math.pi * 2.3
			local radius = 24 + f * 190
			local spread = rng:NextNumber(-1, 1) * (6 + f * 16)
			local at = galaxy * CFrame.new(math.cos(angle) * (radius + spread), rng:NextNumber(-3, 3), math.sin(angle) * (radius + spread))
			local star = Build.Ball(folder, at.Position, (1 - f) * 10 + rng:NextNumber(2, 5), armColors[rng:NextInteger(1, #armColors)], Enum.Material.Neon)
			star.Transparency = f * 0.5
			star.CastShadow = false
		end
	end
	-- Nebula clouds far away, and asteroids drifting round the hub
	local nebulae = { rgb(255, 90, 200), rgb(90, 150, 255), rgb(160, 90, 255), rgb(80, 220, 220) }
	for n = 1, 7 do
		local angle = n / 7 * math.pi * 2
		local cloud = Build.Ball(folder, Vector3.new(x0 + math.cos(angle) * 520, rng:NextNumber(180, 320), -map.HubDepth / 2 + math.sin(angle) * 520), rng:NextNumber(140, 220), nebulae[(n - 1) % #nebulae + 1], Enum.Material.Neon)
		cloud.Transparency = 0.9
		cloud.CastShadow = false
	end
	for _ = 1, 14 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local at = Vector3.new(x0 + side * rng:NextNumber(map.HubHalfWidth + 30, map.HubHalfWidth + 140), rng:NextNumber(30, 110), rng:NextNumber(-map.HubDepth - 80, 40))
		local rock = Build.Decor({ Parent = folder, Name = "Asteroid", Size = Vector3.new(rng:NextNumber(5, 14), rng:NextNumber(4, 10), rng:NextNumber(5, 14)), CFrame = CFrame.new(at) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3)), Color = rgb(58, 50, 78), Material = Enum.Material.Basalt })
		rock.CastShadow = false
	end
	-- Star lamps round the hub
	for _, pos in hubSpots(x0, rng, 10) do
		Build.Pillar(folder, pos, 12, 0.6, rgb(40, 34, 70), Enum.Material.Metal)
		local bulb = Build.Ball(folder, pos + Vector3.new(0, 12.8, 0), 2, rgb(190, 160, 255), Enum.Material.Neon)
		local shell = Build.Ball(folder, bulb.Position, 3.4, rgb(150, 110, 255), Enum.Material.ForceField)
		shell.Transparency = 0.3
		local light = Instance.new("PointLight")
		light.Color = rgb(170, 140, 255)
		light.Range = 20
		light.Brightness = 1.2
		light.Parent = bulb
	end
	-- Stardust drifting down over the hub
	local dustPart = Build.Decor({ Parent = folder, Name = "Stardust", Size = Vector3.new(map.HubHalfWidth * 2, 1, map.HubDepth), Position = Vector3.new(x0, 50, -map.HubDepth / 2), Transparency = 1 })
	local dust = Instance.new("ParticleEmitter")
	dust.EmissionDirection = Enum.NormalId.Bottom
	dust.Rate = 25
	dust.Lifetime = NumberRange.new(8, 12)
	dust.Speed = NumberRange.new(2, 4)
	dust.SpreadAngle = Vector2.new(25, 25)
	dust.Size = NumberSequence.new(0.35, 0.1)
	dust.Color = ColorSequence.new(rgb(200, 180, 255), rgb(140, 200, 255))
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.3), NumberSequenceKeypoint.new(1, 1) })
	dust.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	dust.LightEmission = 1
	dust.Parent = dustPart
end

function WorldDecor.Build(parent: Instance, world: Areas.World)
	local folder = Instance.new("Folder")
	folder.Name = "Scenery"
	folder.Parent = parent
	local rng = Random.new(world.Id * 7717)
	if world.Id == 2 then
		underworld(folder, world, rng)
	elseif world.Id == 3 then
		dream(folder, world, rng)
	elseif world.Id == 4 then
		cyber(folder, world, rng)
	elseif world.Id == Areas.UltimateWorld then
		cosmos(folder, world, rng)
	end
end

return WorldDecor
