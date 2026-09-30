--[[
	WorldDecor: scenery for the hubs and skies of Worlds 2-4, so each world feels like its own place.
	Everything is cosmetic and non-collidable, and kept out of the way of the bases, treadmills,
	portals and the lane entrance.

	  World 2 Glaze Islands: palm trees, beach umbrellas, a lighthouse, and green floating islands
	                         and clouds in the sky along the whole lane.
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

local function palm(parent: Instance, pos: Vector3, rng: Random)
	local height = rng:NextNumber(14, 22)
	local lean = rng:NextNumber(-0.25, 0.25)
	for i = 0, 5 do
		local y = i * height / 6
		Build.Decor({ Parent = parent, Name = "PalmTrunk", Size = Vector3.new(1.8 - i * 0.12, height / 6 + 0.2, 1.8 - i * 0.12), CFrame = CFrame.new(pos + Vector3.new(lean * y, y + height / 12, 0)), Color = if i % 2 == 0 then rgb(150, 105, 60) else rgb(130, 90, 50), Material = Enum.Material.Wood })
	end
	local top = pos + Vector3.new(lean * height, height, 0)
	for n = 0, 6 do
		local angle = n / 7 * math.pi * 2
		Build.Decor({ Parent = parent, Name = "PalmLeaf", Size = Vector3.new(2, 0.3, 9), CFrame = CFrame.new(top) * CFrame.Angles(0, angle, 0) * CFrame.new(0, -0.8, -4.2) * CFrame.Angles(math.rad(-22), 0, 0), Color = rgb(60, 170, 60), Material = Enum.Material.Grass })
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

local function islands(folder: Instance, world: Areas.World, rng: Random)
	local x0 = world.OffsetX
	-- Palm trees and beach umbrellas in the hub, and a lighthouse by the back wall
	for _, pos in hubSpots(x0, rng, 12) do
		palm(folder, pos, rng)
	end
	local stripes = { rgb(255, 80, 80), rgb(255, 210, 50), rgb(60, 170, 255), rgb(255, 130, 200) }
	for n = 1, 6 do
		local pos = Vector3.new(x0 + (if n % 2 == 0 then 1 else -1) * rng:NextNumber(30, 85), 0, rng:NextNumber(-(map.HubDepth - 50), -130))
		Build.Pillar(folder, pos, 8, 0.4, rgb(240, 240, 240))
		Build.Decor({ Parent = folder, Name = "Umbrella", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 9, 9), CFrame = CFrame.new(pos + Vector3.new(0, 8, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = stripes[(n - 1) % #stripes + 1], Material = Enum.Material.Fabric })
	end
	local light = Vector3.new(x0 - 60, 0, -235)
	for i = 0, 7 do
		Build.Decor({ Parent = folder, Name = "Lighthouse", Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 9 - i * 0.4, 9 - i * 0.4), CFrame = CFrame.new(light + Vector3.new(0, 3 + i * 6, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = if i % 2 == 0 then rgb(245, 245, 245) else rgb(230, 50, 50), Material = Enum.Material.SmoothPlastic })
	end
	local lamp = Build.Ball(folder, light + Vector3.new(0, 52, 0), 5, rgb(255, 240, 160), Enum.Material.Neon)
	local glow = Instance.new("PointLight")
	glow.Color = rgb(255, 240, 160)
	glow.Range = 60
	glow.Brightness = 2
	glow.Parent = lamp
	-- Floating islands and clouds along the whole lane
	alongLane(world, 170, function(x, z, _side)
		if rng:NextNumber() < 0.55 then
			floatingIsland(folder, Vector3.new(x + rng:NextNumber(-40, 60) * math.sign(x - world.OffsetX), rng:NextNumber(55, 110), z + rng:NextNumber(-40, 40)), rng:NextNumber(16, 30), rng, rgb(90, 190, 70), rgb(150, 120, 90), function(topPos)
				palm(folder, topPos, rng)
			end)
		else
			cloud(folder, Vector3.new(x + rng:NextNumber(0, 80) * math.sign(x - world.OffsetX), rng:NextNumber(70, 130), z), rng:NextNumber(6, 10), rng)
		end
	end)
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
	-- A skyline all around the hub (outside its walls)
	for z = -(map.HubDepth + 40), 40, 34 do
		for _, side in { -1, 1 } do
			tower(folder, Vector3.new(x0 + side * rng:NextNumber(255, 300), 0, z), rng)
		end
	end
	for x = x0 - 240, x0 + 240, 36 do
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

-- World 2: Donut Land's layout under a night sky full of planets, with shooting-star sparkle.
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
end

function WorldDecor.Build(parent: Instance, world: Areas.World)
	local folder = Instance.new("Folder")
	folder.Name = "Scenery"
	folder.Parent = parent
	local rng = Random.new(world.Id * 7717)
	if world.Id == 2 then
		islands(folder, world, rng)
	elseif world.Id == 3 then
		dream(folder, world, rng)
	elseif world.Id == 4 then
		cyber(folder, world, rng)
	elseif world.Id == Areas.UltimateWorld then
		cosmos(folder, world, rng)
	end
end

return WorldDecor
