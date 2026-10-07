--[[
	DecorProps: the little things that make every biome feel lived in - igloos, snowmen and
	penguins on Glacier Glaze, benches, swings and a duck pond in Sprinkle Park, mine carts in
	Chocolate Caverns, gingerbread houses in Candy Cane Canyon, a crashed satellite in The Black
	Hole... (one list per theme, see Sets at the bottom).

	They stand in the band between the running path (|X| < 44) and the big decoration along the
	walls, a few on each side every so often, turned to face the lane. Each theme also has a
	Feature: a bigger set piece (an igloo village, a pyramid trio, a playground...) built twice per
	biome. Nothing is built near Domer's corner or right at the entrance.

	Every prop is a Model of plain decoration parts (Build.Decor: no collisions, nothing to click),
	so they never block a chase. A biome gets ~150-350 more parts; the client hides them with the
	rest of a far-away biome's decoration (client/Culling).
]]

local Build = require(script.Parent.Build)
local Layout = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Layout"))

local DecorProps = {}

local rgb = Color3.fromRGB
local M = Enum.Material
local UP = CFrame.Angles(0, 0, math.pi / 2) -- turns a cylinder (its axis is X) upright
local WHITE = rgb(255, 255, 255)
local BLACK = rgb(25, 25, 30)

type Builder = (parent: Instance, cf: CFrame, rng: Random) -> Model

--------------------------------------------------------------------------------
-- Building blocks (positions are in the prop's own space: `cf` on the floor, -Z facing the lane)
--------------------------------------------------------------------------------
local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function block(m: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, transparency: number?): BasePart
	return Build.Decor({ Parent = m, Name = name, Size = size, CFrame = cf, Color = color, Material = material or M.SmoothPlastic, Transparency = transparency or 0 })
end

local function ball(m: Instance, name: string, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	return Build.Decor({ Parent = m, Name = name, Shape = Enum.PartType.Ball, Size = Vector3.one * diameter, CFrame = cf, Color = color, Material = material or M.SmoothPlastic })
end

-- A squashed / stretched ball (a block with a sphere mesh).
local function blob(m: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	local part = block(m, name, size, cf, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- Upright cylinder centred at `cf`.
local function cyl(m: Instance, name: string, height: number, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?, transparency: number?): BasePart
	return Build.Decor({ Parent = m, Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, diameter, diameter), CFrame = cf * UP, Color = color, Material = material or M.SmoothPlastic, Transparency = transparency or 0 })
end

-- Cylinder lying along `cf`'s X axis.
local function log(m: Instance, name: string, length: number, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	return Build.Decor({ Parent = m, Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, diameter, diameter), CFrame = cf, Color = color, Material = material or M.SmoothPlastic })
end

local function wedge(m: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	return Build.Decor({ Parent = m, Name = name, Size = size, CFrame = cf, Color = color, Material = material or M.SmoothPlastic }, "WedgePart")
end

-- A thin bar from `a` to `b` (world positions).
local function rod(m: Instance, name: string, a: Vector3, b: Vector3, thickness: number, color: Color3, material: Enum.Material?): BasePart
	local length = math.max((b - a).Magnitude, 0.05)
	local cf = if (b - a).Magnitude > 1e-3 then CFrame.lookAt((a + b) / 2, b) else CFrame.new(a)
	return block(m, name, Vector3.new(thickness, thickness, length), cf, color, material)
end

-- A gable roof: two wedges meeting at a ridge along local X, `width` across (local Z).
local function roof(m: Instance, cf: CFrame, length: number, width: number, height: number, color: Color3, material: Enum.Material?)
	wedge(m, "Roof", Vector3.new(length, height, width / 2), cf * CFrame.new(0, 0, width / 4) * CFrame.Angles(0, math.pi, 0), color, material)
	wedge(m, "Roof", Vector3.new(length, height, width / 2), cf * CFrame.new(0, 0, -width / 4), color, material)
end

-- A little donut lying flat (dough ring, frosting, dark hole): 3 parts.
local function donut(m: Instance, cf: CFrame, size: number, dough: Color3, frosting: Color3)
	cyl(m, "Dough", size * 0.32, size, cf, dough)
	cyl(m, "Frosting", size * 0.1, size * 0.86, cf * CFrame.new(0, size * 0.18, 0), frosting)
	cyl(m, "Hole", size * 0.36, size * 0.3, cf * CFrame.new(0, 0.02, 0), rgb(60, 35, 25))
end

-- A simple gear: a disc with teeth round it. `cf`'s X axis is the gear's axle.
local function gear(m: Instance, cf: CFrame, diameter: number, thickness: number, teeth: number, color: Color3, material: Enum.Material?)
	log(m, "Gear", thickness, diameter, cf, color, material or M.Metal)
	for i = 1, teeth do
		local angle = i / teeth * math.pi * 2
		block(m, "Tooth", Vector3.new(thickness, diameter * 0.16, diameter * 0.16), cf * CFrame.Angles(angle, 0, 0) * CFrame.new(0, diameter / 2, 0), color, material or M.Metal)
	end
	log(m, "Hub", thickness * 1.3, diameter * 0.28, cf, color:Lerp(BLACK, 0.3), material or M.Metal)
end

local function at(cf: CFrame, x: number, y: number, z: number): CFrame
	return cf * CFrame.new(x, y, z)
end

local function pos(cf: CFrame, x: number, y: number, z: number): Vector3
	return (cf * CFrame.new(x, y, z)).Position
end

local function pick<T>(list: { T }, rng: Random): T
	return list[rng:NextInteger(1, #list)]
end

local CANDY = { rgb(255, 90, 120), rgb(255, 200, 60), rgb(90, 210, 120), rgb(80, 170, 255), rgb(190, 110, 255), rgb(255, 140, 60) }

--------------------------------------------------------------------------------
-- Sprinkle Park
--------------------------------------------------------------------------------
local function bench(parent: Instance, cf: CFrame, _rng: Random, wood: Color3?, iron: Color3?): Model
	local m = model(parent, "Bench")
	local w, i = wood or rgb(170, 110, 60), iron or rgb(50, 50, 55)
	block(m, "Seat", Vector3.new(7, 0.4, 2), at(cf, 0, 1.8, 0), w, M.Wood)
	block(m, "Back", Vector3.new(7, 1.6, 0.35), at(cf, 0, 3.2, 0.95) * CFrame.Angles(math.rad(-10), 0, 0), w, M.Wood)
	for _, x in { -3, 3 } do
		block(m, "Leg", Vector3.new(0.35, 1.8, 2), at(cf, x, 0.9, 0), i, M.Metal)
		block(m, "Arm", Vector3.new(0.35, 0.3, 2), at(cf, x, 2.6, -0.1), i, M.Metal)
	end
	return m
end

local function picnic(parent: Instance, cf: CFrame, _rng: Random): Model
	local m = model(parent, "Picnic")
	for i = 0, 3 do
		local x, z = (i % 2) * 3 - 1.5, (i // 2) * 3 - 1.5
		block(m, "Blanket", Vector3.new(3, 0.12, 3), at(cf, x, 0.06, z), if i == 0 or i == 3 then rgb(230, 60, 60) else WHITE, M.Fabric)
	end
	block(m, "Basket", Vector3.new(1.8, 1.1, 1.2), at(cf, 1.3, 0.65, 1.2), rgb(190, 140, 80), M.WoodPlanks)
	block(m, "Lid", Vector3.new(1.9, 0.2, 1.3), at(cf, 1.3, 1.3, 1.2), rgb(160, 115, 60), M.WoodPlanks)
	cyl(m, "Plate", 0.15, 1.8, at(cf, -1.1, 0.2, -0.9), WHITE)
	donut(m, at(cf, -1.1, 0.42, -0.9), 1, rgb(220, 165, 95), rgb(255, 120, 180))
	return m
end

local function swings(parent: Instance, cf: CFrame, _rng: Random): Model
	local m = model(parent, "Swings")
	local frame, h = rgb(230, 70, 70), 9
	for _, x in { -5, 5 } do
		for _, z in { -2, 2 } do
			rod(m, "Leg", pos(cf, x, 0, z), pos(cf, x, h, 0), 0.5, frame, M.Metal)
		end
	end
	log(m, "TopBar", 10.6, 0.6, at(cf, 0, h, 0), frame, M.Metal)
	for _, x in { -2.2, 2.2 } do
		block(m, "Seat", Vector3.new(2, 0.25, 1), at(cf, x, 2, 0), rgb(60, 140, 230))
		for _, dx in { -0.85, 0.85 } do
			rod(m, "Rope", pos(cf, x + dx, 2, 0), pos(cf, x + dx, h, 0), 0.12, rgb(90, 90, 95), M.Metal)
		end
	end
	return m
end

local function slide(parent: Instance, cf: CFrame, _rng: Random): Model
	local m = model(parent, "Slide")
	local rail = rgb(60, 140, 230)
	for _, x in { -1.2, 1.2 } do
		rod(m, "Ladder", pos(cf, x, 0, 3), pos(cf, x, 7, 1.6), 0.3, rail, M.Metal)
	end
	for i = 1, 3 do
		block(m, "Rung", Vector3.new(2.4, 0.2, 0.2), CFrame.new(pos(cf, 0, i * 1.7, 3 - i * 0.33)) * (cf - cf.Position), rail, M.Metal)
	end
	block(m, "Platform", Vector3.new(3, 0.4, 2.4), at(cf, 0, 7, 0.6), rgb(255, 210, 60))
	for _, x in { -1.3, 1.3 } do
		rod(m, "Post", pos(cf, x, 0, -0.4), pos(cf, x, 7, -0.4), 0.35, rail, M.Metal)
	end
	block(m, "Chute", Vector3.new(2.4, 0.3, 10), CFrame.lookAt(pos(cf, 0, 3.6, -4), pos(cf, 0, 0.4, -8.6)), rgb(255, 120, 40))
	return m
end

local function duckPond(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "DuckPond")
	cyl(m, "Water", 0.2, 14, at(cf, 0, 0.1, 0), rgb(90, 170, 230), M.Glass, 0.15)
	for i = 0, 9 do
		local angle = i / 10 * math.pi * 2
		ball(m, "Stone", rng:NextNumber(1.4, 2.2), at(cf, math.cos(angle) * 7.2, 0.3, math.sin(angle) * 7.2), rgb(150, 150, 140), M.Slate)
	end
	for i = 1, 3 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local d = at(cf, math.cos(angle) * rng:NextNumber(1, 4.5), 0.5, math.sin(angle) * rng:NextNumber(1, 4.5)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		blob(m, "Duck", Vector3.new(1.2, 0.9, 1.7), d, if i == 2 then rgb(200, 180, 140) else rgb(255, 230, 80))
		ball(m, "DuckHead", 0.75, d * CFrame.new(0, 0.6, -0.65), if i == 2 then rgb(60, 130, 70) else rgb(255, 230, 80))
		block(m, "Beak", Vector3.new(0.3, 0.15, 0.4), d * CFrame.new(0, 0.55, -1.1), rgb(255, 140, 30))
	end
	cyl(m, "LilyPad", 0.08, 1.8, at(cf, 3, 0.22, 3), rgb(80, 170, 70))
	return m
end

local function flowerBed(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "FlowerBed")
	block(m, "Edge", Vector3.new(9, 0.6, 3.6), at(cf, 0, 0.3, 0), rgb(200, 190, 175), M.Brick)
	block(m, "Soil", Vector3.new(8.4, 0.62, 3), at(cf, 0, 0.32, 0), rgb(110, 75, 50), M.Ground)
	for i = 1, 9 do
		local x = -3.6 + (i - 1) * 0.9
		ball(m, "Bloom", rng:NextNumber(0.7, 1.1), at(cf, x, 0.95, rng:NextNumber(-0.8, 0.8)), pick({ rgb(255, 90, 90), rgb(255, 220, 60), WHITE, rgb(200, 120, 255), rgb(255, 150, 200) }, rng))
	end
	return m
end

local function donutCart(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "DonutCart")
	block(m, "Cart", Vector3.new(5, 3, 2.6), at(cf, 0, 2.2, 0), rgb(255, 150, 190))
	block(m, "Counter", Vector3.new(5.4, 0.3, 3), at(cf, 0, 3.85, 0), WHITE)
	for _, x in { -1.8, 1.8 } do
		log(m, "Wheel", 0.4, 1.8, at(cf, x, 0.9, -1.4) * CFrame.Angles(0, math.pi / 2, 0), BLACK)
	end
	rod(m, "Handle", pos(cf, 2.5, 2.6, 0), pos(cf, 4.2, 3.2, 0), 0.25, rgb(80, 80, 85), M.Metal)
	cyl(m, "Pole", 4, 0.25, at(cf, 0, 6, 0.5), rgb(80, 80, 85), M.Metal)
	cyl(m, "Umbrella", 0.3, 7, at(cf, 0, 8, 0.5), rgb(255, 200, 60), M.Fabric)
	ball(m, "Tip", 0.6, at(cf, 0, 8.4, 0.5), WHITE)
	for i = -1, 1 do
		donut(m, at(cf, i * 1.5, 4.15, -0.4), 1.1, rgb(220, 165, 95), pick(CANDY, rng))
	end
	return m
end

local function lampPost(parent: Instance, cf: CFrame, _rng: Random): Model
	local m = model(parent, "LampPost")
	cyl(m, "Base", 0.8, 1.6, at(cf, 0, 0.4, 0), rgb(40, 40, 45), M.Metal)
	cyl(m, "Pole", 8, 0.45, at(cf, 0, 4.6, 0), rgb(40, 40, 45), M.Metal)
	block(m, "Lamp", Vector3.new(1.3, 1.6, 1.3), at(cf, 0, 9.2, 0), rgb(255, 240, 190), M.Neon, 0.1)
	block(m, "Cap", Vector3.new(1.7, 0.3, 1.7), at(cf, 0, 10.1, 0), rgb(40, 40, 45), M.Metal)
	return m
end

local function playground(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "Playground")
	swings(m, at(cf, -6, 0, 0), rng)
	slide(m, at(cf, 7, 0, 2), rng)
	-- sandbox with a bucket and spade
	for _, s in { { 0, -3.5, 9, 0.6 }, { 0, 3.5, 9, 0.6 }, { -4.2, 0, 0.6, 7.6 }, { 4.2, 0, 0.6, 7.6 } } do
		block(m, "SandboxEdge", Vector3.new(s[3], 0.8, s[4]), at(cf, s[1], 0.4, s[2] - 10), rgb(170, 110, 60), M.Wood)
	end
	block(m, "Sand", Vector3.new(7.8, 0.6, 6.4), at(cf, 0, 0.3, -10), rgb(240, 215, 150), M.Sand)
	cyl(m, "Bucket", 1, 1, at(cf, 1.5, 1.1, -10.5), rgb(60, 140, 230))
	blob(m, "SandCastle", Vector3.new(1.8, 1.2, 1.8), at(cf, -1.5, 0.9, -9.5), rgb(230, 200, 130), M.Sand)
	return m
end

--------------------------------------------------------------------------------
-- Frosting Falls (lake)
--------------------------------------------------------------------------------
local function rowboat(m: Instance, cf: CFrame, color: Color3)
	block(m, "Hull", Vector3.new(3, 1.1, 6), at(cf, 0, 0.55, 0), color, M.WoodPlanks)
	wedge(m, "Bow", Vector3.new(3, 1.1, 2), at(cf, 0, 0.55, -4) * CFrame.Angles(0, math.pi, 0), color, M.WoodPlanks)
	block(m, "Inside", Vector3.new(2.4, 0.2, 5.4), at(cf, 0, 1.05, 0), color:Lerp(BLACK, 0.35), M.WoodPlanks)
	block(m, "Seat", Vector3.new(2.6, 0.2, 0.8), at(cf, 0, 1.2, 0.3), rgb(150, 100, 60), M.Wood)
	rod(m, "Oar", pos(cf, -1.3, 1.3, 0.3), pos(cf, -3.6, 0.2, -1.2), 0.2, rgb(150, 100, 60), M.Wood)
end

local function dock(parent: Instance, cf: CFrame, _rng: Random): Model
	local m = model(parent, "Dock")
	cyl(m, "Water", 0.2, 16, at(cf, 0, 0.1, -3), rgb(110, 190, 235), M.Glass, 0.15)
	block(m, "Deck", Vector3.new(4, 0.5, 12), at(cf, 0, 1, 1), rgb(160, 110, 70), M.WoodPlanks)
	for _, x in { -1.8, 1.8 } do
		for _, z in { -4.6, 0.4, 5.4 } do
			cyl(m, "Post", 2.4, 0.6, at(cf, x, 0.8, z), rgb(120, 80, 50), M.Wood)
		end
	end
	rowboat(m, at(cf, 4.2, 0, -3) * CFrame.Angles(0, math.rad(12), 0), rgb(220, 90, 70))
	return m
end

local function lighthouse(parent: Instance, cf: CFrame, _rng: Random): Model
	local m = model(parent, "Lighthouse")
	cyl(m, "Rock", 1.2, 7, at(cf, 0, 0.6, 0), rgb(140, 140, 130), M.Slate)
	for i = 0, 3 do
		cyl(m, "Tower", 3.2, 4.6 - i * 0.45, at(cf, 0, 2.8 + i * 3.2, 0), if i % 2 == 0 then rgb(230, 60, 60) else WHITE)
	end
	cyl(m, "Gallery", 0.5, 4.2, at(cf, 0, 14.2, 0), rgb(40, 40, 45), M.Metal)
	cyl(m, "Lamp", 2.2, 2.6, at(cf, 0, 15.5, 0), rgb(255, 240, 160), M.Neon, 0.1)
	ball(m, "Dome", 3, at(cf, 0, 16.9, 0), rgb(230, 60, 60))
	return m
end

local function cattails(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "Cattails")
	for _ = 1, 6 do
		local base = pos(cf, rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
		local top = base + Vector3.new(rng:NextNumber(-0.6, 0.6), rng:NextNumber(4, 6), rng:NextNumber(-0.6, 0.6))
		rod(m, "Stalk", base, top, 0.18, rgb(90, 150, 60), M.Grass)
		blob(m, "Tip", Vector3.new(0.45, 1.2, 0.45), CFrame.new(top), rgb(120, 75, 40), M.Fabric)
	end
	return m
end

local function fishingSpot(parent: Instance, cf: CFrame, _rng: Random): Model
	local m = model(parent, "FishingSpot")
	cyl(m, "Pond", 0.2, 7, at(cf, 0, 0.1, -3.5), rgb(100, 180, 230), M.Glass, 0.15)
	cyl(m, "Stool", 1.6, 1.4, at(cf, 0, 0.8, 1.2), rgb(150, 100, 60), M.Wood)
	rod(m, "Rod", pos(cf, 0.3, 1.8, 1.2), pos(cf, 0.6, 6.5, -2.5), 0.15, rgb(60, 60, 65), M.Metal)
	rod(m, "Line", pos(cf, 0.6, 6.5, -2.5), pos(cf, 0.6, 0.2, -3.6), 0.04, WHITE)
	ball(m, "Bobber", 0.4, at(cf, 0.6, 0.25, -3.6), rgb(230, 50, 50))
	cyl(m, "Bucket", 1.1, 1.2, at(cf, 1.4, 0.55, 1.6), rgb(150, 160, 170), M.Metal)
	blob(m, "Fish", Vector3.new(0.4, 0.5, 1.1), at(cf, 1.4, 1.2, 1.6) * CFrame.Angles(math.rad(70), 0, 0), rgb(255, 150, 60))
	return m
end

local function lilyPond(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "LilyPond")
	cyl(m, "Water", 0.2, 10, at(cf, 0, 0.1, 0), rgb(100, 180, 230), M.Glass, 0.15)
	for _ = 1, 4 do
		cyl(m, "LilyPad", 0.08, rng:NextNumber(1.4, 2.2), at(cf, rng:NextNumber(-3.5, 3.5), 0.22, rng:NextNumber(-3.5, 3.5)), rgb(80, 170, 70))
	end
	ball(m, "Flower", 0.7, at(cf, 1.5, 0.45, -1), rgb(255, 150, 200))
	local frog = at(cf, -1.5, 0.3, 1.2)
	cyl(m, "FrogPad", 0.08, 2, frog * CFrame.new(0, -0.08, 0), rgb(80, 170, 70))
	blob(m, "Frog", Vector3.new(1.1, 0.7, 1.2), frog * CFrame.new(0, 0.35, 0), rgb(110, 200, 80))
	for _, x in { -0.3, 0.3 } do
		ball(m, "Eye", 0.35, frog * CFrame.new(x, 0.75, -0.35), WHITE)
	end
	return m
end

local function pier(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "Pier")
	dock(m, at(cf, -5, 0, 0), rng)
	lighthouse(m, at(cf, 8, 0, 2), rng)
	cattails(m, at(cf, -9, 0, 6), rng)
	return m
end

--------------------------------------------------------------------------------
-- Sugar Dunes (desert)
--------------------------------------------------------------------------------
local function stepPyramid(parent: Instance, cf: CFrame, rng: Random, scale: number?): Model
	local m = model(parent, "Pyramid")
	local s = scale or rng:NextNumber(0.8, 1.2)
	for i = 0, 4 do
		local w = (12 - i * 2.4) * s
		block(m, "Step", Vector3.new(w, 2.2 * s, w), at(cf, 0, (1.1 + i * 2.2) * s, 0), rgb(225, 195, 135):Lerp(rgb(200, 165, 105), i / 5), M.Sandstone)
	end
	block(m, "Cap", Vector3.new(1.6, 1.6, 1.6) * s, at(cf, 0, 11.8 * s, 0), rgb(255, 215, 80), M.Neon)
	block(m, "Door", Vector3.new(2, 3, 0.2) * s, at(cf, 0, 1.5 * s, -6 * s - 0.05), rgb(70, 50, 35))
	return m
end

local function palm(m: Instance, cf: CFrame, rng: Random)
	local base = cf.Position
	local lean = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
	local last = base
	for i = 1, 4 do
		local nextPoint = base + Vector3.new(0, i * 2.4, 0) + lean * (i / 4) ^ 2 * 2
		rod(m, "Trunk", last, nextPoint, 1 - i * 0.1, rgb(150, 110, 70), M.Wood)
		last = nextPoint
	end
	for i = 1, 6 do
		local angle = i / 6 * math.pi * 2
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local tip = last + dir * 4.5 + Vector3.new(0, -1.6, 0)
		block(m, "Leaf", Vector3.new(1.4, 0.2, 5), CFrame.lookAt((last + tip) / 2, tip), rgb(70, 170, 70), M.Grass)
	end
	for i = 1, 3 do
		ball(m, "Coconut", 0.8, CFrame.new(last + Vector3.new(math.cos(i * 2.1) * 0.6, -0.6, math.sin(i * 2.1) * 0.6)), rgb(110, 75, 40))
	end
end

local function oasis(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "Oasis")
	cyl(m, "Sand", 0.3, 15, at(cf, 0, 0.15, 0), rgb(235, 210, 150), M.Sand)
	cyl(m, "Water", 0.32, 10, at(cf, 0, 0.18, 0), rgb(70, 190, 220), M.Glass, 0.1)
	palm(m, at(cf, -6, 0, 3), rng)
	palm(m, at(cf, 5.5, 0, -4), rng)
	return m
end

local function tent(parent: Instance, cf: CFrame, _rng: Random): Model
	local m = model(parent, "Tent")
	roof(m, at(cf, 0, 2.5, 0) * CFrame.Angles(0, math.pi / 2, 0), 7, 7, 5, rgb(235, 225, 200), M.Fabric)
	wedge(m, "Door", Vector3.new(0.2, 3.2, 1.6), at(cf, 0, 1.6, -3.5) * CFrame.Angles(0, -math.pi / 2, 0), rgb(190, 80, 60), M.Fabric)
	block(m, "Rug", Vector3.new(3, 0.1, 2.2), at(cf, 0, 0.05, -5.2), rgb(200, 60, 60), M.Fabric)
	return m
end

local function pots(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "Pots")
	for i = 1, 3 do
		local p = at(cf, (i - 2) * 2, 0, rng:NextNumber(-0.6, 0.6))
		local size = rng:NextNumber(1.6, 2.4)
		blob(m, "Pot", Vector3.new(size, size * 1.1, size), p * CFrame.new(0, size * 0.55, 0), rgb(200, 110, 70), M.Slate)
		cyl(m, "Neck", 0.5, size * 0.5, p * CFrame.new(0, size * 1.15, 0), rgb(180, 95, 60), M.Slate)
	end
	return m
end

local function camel(parent: Instance, cf: CFrame, _rng: Random): Model
	local m = model(parent, "Camel")
	local tan = rgb(205, 160, 100)
	blob(m, "Body", Vector3.new(3, 3, 6), at(cf, 0, 5, 0), tan, M.Fabric)
	ball(m, "Hump", 2.4, at(cf, 0, 6.6, 0.6), tan, M.Fabric)
	for _, x in { -0.9, 0.9 } do
		for _, z in { -2, 2 } do
			rod(m, "Leg", pos(cf, x, 4.2, z), pos(cf, x, 0, z), 0.7, tan, M.Fabric)
		end
	end
	rod(m, "Neck", pos(cf, 0, 5.5, -2.6), pos(cf, 0, 8, -3.8), 1, tan, M.Fabric)
	blob(m, "Head", Vector3.new(1.2, 1.2, 2.2), at(cf, 0, 8.2, -4.4), tan, M.Fabric)
	for _, x in { -0.45, 0.45 } do
		ball(m, "Eye", 0.3, at(cf, x, 8.5, -4.9), BLACK)
	end
	return m
end

local function tumbleweeds(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "Tumbleweeds")
	for i = 1, 3 do
		local d = rng:NextNumber(1.6, 2.6)
		ball(m, "Tumbleweed", d, at(cf, (i - 2) * 3, d / 2, rng:NextNumber(-1, 1)), rgb(170, 130, 80), M.Fabric)
	end
	return m
end

local function pyramidTrio(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "PyramidTrio")
	stepPyramid(m, at(cf, 0, 0, 4), rng, 1.25)
	stepPyramid(m, at(cf, -11, 0, 0), rng, 0.75)
	stepPyramid(m, at(cf, 10, 0, 1), rng, 0.6)
	camel(m, at(cf, 4, 0, -10) * CFrame.Angles(0, math.rad(70), 0), rng)
	return m
end

--------------------------------------------------------------------------------
-- Jellybean Jungle
--------------------------------------------------------------------------------
local function stiltHut(parent: Instance, cf: CFrame, _rng: Random): Model
	local m = model(parent, "StiltHut")
	local wood = rgb(140, 95, 55)
	for _, x in { -2.6, 2.6 } do
		for _, z in { -2.6, 2.6 } do
			cyl(m, "Stilt", 4, 0.7, at(cf, x, 2, z), wood, M.Wood)
		end
	end
	block(m, "Floor", Vector3.new(7, 0.5, 7), at(cf, 0, 4.2, 0), wood, M.WoodPlanks)
	block(m, "Walls", Vector3.new(5.6, 4, 5.6), at(cf, 0, 6.4, 0), rgb(175, 130, 80), M.WoodPlanks)
	block(m, "Door", Vector3.new(1.6, 2.6, 0.2), at(cf, 0, 5.7, -2.85), rgb(60, 40, 25))
	roof(m, at(cf, 0, 9.6, 0), 7.6, 8, 2.8, rgb(215, 190, 100), M.Grass)
	for _, x in { -0.7, 0.7 } do
		rod(m, "Ladder", pos(cf, x, 0, -5.4), pos(cf, x, 4.4, -3.4), 0.25, wood, M.Wood)
	end
	for i = 1, 3 do
		block(m, "Rung", Vector3.new(1.6, 0.18, 0.18), CFrame.new(pos(cf, 0, i * 1.1, -5.4 + i * 0.5)) * (cf - cf.Position), wood, M.Wood)
	end
	return m
end

local function totem(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "Totem")
	local colors = { rgb(200, 80, 60), rgb(80, 160, 90), rgb(230, 180, 60) }
	for i = 1, 3 do
		local c = at(cf, 0, i * 2.4 - 1.2, 0)
		block(m, "Head", Vector3.new(2.4, 2.4, 2.4), c, colors[(i + rng:NextInteger(0, 2)) % 3 + 1], M.Wood)
		for _, x in { -0.55, 0.55 } do
			block(m, "Eye", Vector3.new(0.5, 0.4, 0.1), c * CFrame.new(x, 0.35, -1.22), WHITE, M.Neon)
		end
		block(m, "Mouth", Vector3.new(1.3, 0.3, 0.1), c * CFrame.new(0, -0.55, -1.22), BLACK)
	end
	for _, side in { -1, 1 } do
		wedge(m, "Wing", Vector3.new(0.3, 1.2, 2.4), at(cf, side * 1.9, 6.6, 0) * CFrame.Angles(0, side * math.pi / 2, 0), rgb(60, 140, 200), M.Wood)
	end
	return m
end

local function fern(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "Fern")
	for i = 1, 7 do
		local angle = i / 7 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local tip = pos(cf, math.cos(angle) * 3.4, rng:NextNumber(1.6, 2.6), math.sin(angle) * 3.4)
		local base = pos(cf, 0, 0.4, 0)
		block(m, "Leaf", Vector3.new(1.3, 0.15, (tip - base).Magnitude + 0.5), CFrame.lookAt((base + tip) / 2, tip), rgb(60, 160, 60):Lerp(rgb(110, 200, 70), rng:NextNumber()), M.Grass)
	end
	return m
end

local function jellybeans(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "Jellybeans")
	for i = 1, 11 do
		local layer = if i <= 6 then 0 elseif i <= 10 then 1 else 2
		local spread = 1.8 - layer * 0.6
		blob(m, "Jellybean", Vector3.new(0.8, 0.75, 1.4), at(cf, rng:NextNumber(-spread, spread), 0.4 + layer * 0.65, rng:NextNumber(-spread, spread)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)), pick(CANDY, rng))
	end
	return m
end

local function parrot(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "Parrot")
	cyl(m, "Perch", 6, 0.4, at(cf, 0, 3, 0), rgb(120, 80, 50), M.Wood)
	log(m, "Bar", 2.4, 0.3, at(cf, 0, 5.8, 0), rgb(120, 80, 50), M.Wood)
	local body = pick({ rgb(230, 50, 50), rgb(60, 180, 90), rgb(60, 130, 230) }, rng)
	blob(m, "Body", Vector3.new(0.9, 1.5, 1), at(cf, 0, 6.8, 0), body)
	ball(m, "Head", 0.8, at(cf, 0, 7.8, -0.1), body)
	wedge(m, "Beak", Vector3.new(0.3, 0.4, 0.4), at(cf, 0, 7.75, -0.55), rgb(255, 210, 60))
	blob(m, "Wing", Vector3.new(0.3, 1.1, 0.8), at(cf, 0.5, 6.8, 0.05), rgb(255, 210, 60))
	block(m, "Tail", Vector3.new(0.3, 1.2, 0.2), at(cf, 0, 5.7, 0.45) * CFrame.Angles(math.rad(20), 0, 0), rgb(60, 130, 230))
	return m
end

local function mushrooms(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "Mushrooms")
	for i = 1, 3 do
		local h = rng:NextNumber(1.2, 2.4)
		local c = at(cf, (i - 2) * 1.8, 0, rng:NextNumber(-0.8, 0.8))
		cyl(m, "Stem", h, h * 0.35, c * CFrame.new(0, h / 2, 0), rgb(245, 235, 215))
		blob(m, "Cap", Vector3.new(h * 1.1, h * 0.55, h * 1.1), c * CFrame.new(0, h, 0), rgb(220, 60, 60))
	end
	return m
end

local function jungleCamp(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "JungleCamp")
	stiltHut(m, at(cf, -8, 0, 2), rng)
	stiltHut(m, at(cf, 7, 0, 4) * CFrame.Angles(0, math.rad(-20), 0), rng)
	totem(m, at(cf, 0, 0, 6), rng)
	for i = 0, 5 do
		local angle = i / 6 * math.pi * 2
		ball(m, "FireStone", 0.9, at(cf, math.cos(angle) * 1.5, 0.3, -5 + math.sin(angle) * 1.5), rgb(120, 120, 115), M.Slate)
	end
	blob(m, "Fire", Vector3.new(1.4, 1.8, 1.4), at(cf, 0, 0.8, -5), rgb(255, 150, 40), M.Neon)
	return m
end

--------------------------------------------------------------------------------
-- Glacier Glaze (ice)
--------------------------------------------------------------------------------
local SNOW = rgb(245, 250, 255)

-- A dome of snow blocks (half of it is under the floor), with seams, a tunnel and a dark doorway.
local function igloo(parent: Instance, cf: CFrame, _rng: Random, size: number?): Model
	local m = model(parent, "Igloo")
	local d = size or 13
	local r = d / 2
	ball(m, "Dome", d, cf, SNOW, M.Snow)
	for _, y in { r * 0.35, r * 0.68 } do
		cyl(m, "Seam", 0.18, 2 * math.sqrt(r * r - y * y) + 0.12, at(cf, 0, y, 0), rgb(205, 225, 245), M.Ice)
	end
	log(m, "Tunnel", r * 0.9, r * 0.85, at(cf, 0, 0, -r * 0.95) * CFrame.Angles(0, math.pi / 2, 0), SNOW, M.Snow)
	log(m, "Doorway", 0.2, r * 0.6, at(cf, 0, 0, -r * 1.42) * CFrame.Angles(0, math.pi / 2, 0), rgb(40, 55, 80))
	return m
end

local function snowman(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "Snowman")
	ball(m, "Bottom", 5, at(cf, 0, 2.2, 0), SNOW, M.Snow)
	ball(m, "Middle", 3.6, at(cf, 0, 5.6, 0), SNOW, M.Snow)
	ball(m, "Head", 2.6, at(cf, 0, 8.2, 0), SNOW, M.Snow)
	for _, x in { -0.45, 0.45 } do
		ball(m, "Eye", 0.35, at(cf, x, 8.55, -1.15), BLACK)
	end
	wedge(m, "Nose", Vector3.new(0.35, 0.35, 1.2), at(cf, 0, 8.2, -1.7), rgb(255, 140, 0))
	for i = 1, 3 do
		ball(m, "Button", 0.35, at(cf, 0, 4.9 + i * 0.6, -1.7 + math.abs(i - 2) * 0.1), BLACK)
	end
	for _, side in { -1, 1 } do
		rod(m, "Arm", pos(cf, side * 1.6, 6, 0), pos(cf, side * 3.6, 7.6, 0), 0.25, rgb(110, 75, 45), M.Wood)
	end
	cyl(m, "Scarf", 0.6, 2.9, at(cf, 0, 7.2, 0), pick({ rgb(230, 50, 60), rgb(60, 130, 230), rgb(60, 180, 90) }, rng), M.Fabric)
	cyl(m, "HatBrim", 0.2, 2.6, at(cf, 0, 9.4, 0), BLACK)
	cyl(m, "Hat", 1.5, 1.8, at(cf, 0, 10.2, 0), BLACK)
	return m
end

local function penguin(parent: Instance, cf: CFrame, scale: number): Model
	local m = model(parent, "Penguin")
	local s = scale
	blob(m, "Body", Vector3.new(2.2, 3.2, 2) * s, at(cf, 0, 1.7 * s, 0), BLACK)
	blob(m, "Belly", Vector3.new(1.6, 2.5, 0.9) * s, at(cf, 0, 1.6 * s, -0.6 * s), WHITE)
	ball(m, "Head", 1.5 * s, at(cf, 0, 3.6 * s, 0), BLACK)
	for _, x in { -0.32, 0.32 } do
		ball(m, "Eye", 0.32 * s, at(cf, x * s, 3.8 * s, -0.62 * s), WHITE)
	end
	wedge(m, "Beak", Vector3.new(0.35, 0.3, 0.6) * s, at(cf, 0, 3.5 * s, -0.9 * s), rgb(255, 160, 30))
	for _, side in { -1, 1 } do
		blob(m, "Flipper", Vector3.new(0.3, 1.6, 0.8) * s, at(cf, side * 1.15 * s, 1.9 * s, 0) * CFrame.Angles(0, 0, side * math.rad(18)), BLACK)
		block(m, "Foot", Vector3.new(0.6, 0.2, 0.8) * s, at(cf, side * 0.45 * s, 0.1 * s, -0.4 * s), rgb(255, 160, 30))
	end
	return m
end

local function penguins(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "Penguins")
	penguin(m, at(cf, -1.4, 0, 0) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), 1)
	penguin(m, at(cf, 1.6, 0, 0.4) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), 0.9)
	penguin(m, at(cf, 0.2, 0, -1.6) * CFrame.Angles(0, rng:NextNumber(-0.6, 0.6), 0), 0.55)
	return m
end

local function iceFishing(parent: Instance, cf: CFrame, _rng: Random): Model
	local m = model(parent, "IceFishing")
	cyl(m, "Rim", 0.2, 4, at(cf, 0, 0.1, -2.5), SNOW, M.Snow)
	cyl(m, "Hole", 0.22, 2.6, at(cf, 0, 0.12, -2.5), rgb(30, 70, 120), M.Glass)
	cyl(m, "Stool", 1.4, 1.4, at(cf, 0, 0.7, 1), rgb(150, 100, 60), M.Wood)
	rod(m, "Rod", pos(cf, 0.2, 1.6, 0.8), pos(cf, 0, 4, -2.4), 0.14, rgb(60, 60, 65), M.Metal)
	rod(m, "Line", pos(cf, 0, 4, -2.4), pos(cf, 0, 0.2, -2.5), 0.04, WHITE)
	cyl(m, "Bucket", 1, 1.1, at(cf, 1.4, 0.5, 1.2), rgb(150, 160, 170), M.Metal)
	blob(m, "Fish", Vector3.new(0.4, 0.5, 1.1), at(cf, 1.4, 1.1, 1.2) * CFrame.Angles(math.rad(70), 0, 0), rgb(120, 190, 255))
	return m
end

local function sled(parent: Instance, cf: CFrame, _rng: Random): Model
	local m = model(parent, "Sled")
	for _, x in { -0.9, 0.9 } do
		block(m, "Runner", Vector3.new(0.2, 0.25, 5), at(cf, x, 0.15, 0), rgb(180, 40, 40), M.Metal)
		block(m, "Curl", Vector3.new(0.2, 1, 0.25), at(cf, x, 0.6, -2.5) * CFrame.Angles(math.rad(-20), 0, 0), rgb(180, 40, 40), M.Metal)
	end
	block(m, "Deck", Vector3.new(2.2, 0.25, 4.2), at(cf, 0, 0.6, 0.2), rgb(170, 110, 60), M.WoodPlanks)
	rod(m, "Rope", pos(cf, -0.9, 0.9, -2.6), pos(cf, 0.4, 0.1, -4.5), 0.1, rgb(220, 200, 150), M.Fabric)
	return m
end

local function snowPine(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "SnowPine")
	cyl(m, "Trunk", 2.4, 0.9, at(cf, 0, 1.2, 0), rgb(110, 75, 45), M.Wood)
	local h = rng:NextNumber(0.9, 1.2)
	for i = 0, 2 do
		local w = (5.5 - i * 1.5) * h
		local y = (2.6 + i * 2.1) * h
		block(m, "Needles", Vector3.new(w, 2.2 * h, w), at(cf, 0, y, 0) * CFrame.Angles(0, math.rad(45 * i), 0), rgb(40, 110, 70), M.Grass)
		block(m, "Snow", Vector3.new(w * 0.85, 0.35, w * 0.85), at(cf, 0, y + 1.2 * h, 0) * CFrame.Angles(0, math.rad(45 * i), 0), SNOW, M.Snow)
	end
	return m
end

local function snowFort(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "SnowFort")
	block(m, "Wall", Vector3.new(7, 2.4, 1.4), at(cf, 0, 1.2, 1), SNOW, M.Snow)
	for _, side in { -1, 1 } do
		block(m, "Wall", Vector3.new(1.4, 2.4, 4), at(cf, side * 3.2, 1.2, -0.6), SNOW, M.Snow)
	end
	for i = 1, 6 do
		local layer = if i <= 3 then 0 elseif i <= 5 then 1 else 2
		ball(m, "Snowball", 0.9, at(cf, (i % 3 - 1) * 0.8 + layer * 0.4 - 0.4, 0.45 + layer * 0.7, -1.4 + rng:NextNumber(-0.2, 0.2)), SNOW, M.Snow)
	end
	return m
end

local function iglooVillage(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "IglooVillage")
	igloo(m, at(cf, -7, 0, 3) * CFrame.Angles(0, math.rad(15), 0), rng, 14)
	igloo(m, at(cf, 7, 0, 4) * CFrame.Angles(0, math.rad(-20), 0), rng, 11)
	igloo(m, at(cf, 1, 0, 13) * CFrame.Angles(0, math.rad(5), 0), rng, 9)
	snowman(m, at(cf, 0, 0, -3), rng)
	penguins(m, at(cf, -5, 0, -7) * CFrame.Angles(0, math.rad(30), 0), rng)
	-- a little campfire to keep warm
	for i = 0, 4 do
		local angle = i / 5 * math.pi * 2
		log(m, "Firewood", 2, 0.5, at(cf, 4 + math.cos(angle) * 0.6, 0.3, -6 + math.sin(angle) * 0.6) * CFrame.Angles(0, angle, 0), rgb(110, 75, 45), M.Wood)
	end
	blob(m, "Fire", Vector3.new(1.2, 1.6, 1.2), at(cf, 4, 1, -6), rgb(255, 160, 50), M.Neon)
	return m
end

--------------------------------------------------------------------------------
-- Molten Bakery (lava)
--------------------------------------------------------------------------------
local function cauldron(parent: Instance, cf: CFrame, _rng: Random, liquid: Color3?): Model
	local m = model(parent, "Cauldron")
	for i = 0, 2 do
		local angle = i / 3 * math.pi * 2
		rod(m, "Leg", pos(cf, math.cos(angle) * 1.6, 0, math.sin(angle) * 1.6), pos(cf, math.cos(angle) * 1.2, 1.4, math.sin(angle) * 1.2), 0.3, BLACK, M.Metal)
	end
	blob(m, "Pot", Vector3.new(4, 3, 4), at(cf, 0, 2.6, 0), rgb(45, 45, 50), M.Metal)
	cyl(m, "Rim", 0.4, 3.4, at(cf, 0, 3.9, 0), rgb(60, 60, 65), M.Metal)
	cyl(m, "Liquid", 0.2, 3, at(cf, 0, 4, 0), liquid or rgb(255, 120, 20), M.Neon)
	ball(m, "Bubble", 0.7, at(cf, 0.6, 4.2, -0.4), (liquid or rgb(255, 120, 20)):Lerp(WHITE, 0.3), M.Neon)
	ball(m, "Bubble", 0.45, at(cf, -0.7, 4.15, 0.5), (liquid or rgb(255, 120, 20)):Lerp(WHITE, 0.3), M.Neon)
	return m
end

local function obsidianRocks(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "ObsidianRocks")
	for _ = 1, 4 do
		local size = Vector3.new(rng:NextNumber(1.5, 3.5), rng:NextNumber(1.5, 4), rng:NextNumber(1.5, 3.5))
		block(m, "Rock", size, at(cf, rng:NextNumber(-3, 3), size.Y * 0.35, rng:NextNumber(-3, 3)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, math.pi), rng:NextNumber(-0.4, 0.4)), rgb(30, 24, 32), M.Basalt)
	end
	block(m, "Crack", Vector3.new(0.3, 0.1, 4), at(cf, 0, 0.05, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), rgb(255, 110, 20), M.Neon)
	return m
end

local function burntDonuts(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "BurntDonuts")
	cyl(m, "Tray", 0.2, 4.2, at(cf, 0, 0.1, 0), rgb(90, 90, 95), M.Metal)
	for i = 1, 3 do
		local angle = i / 3 * math.pi * 2
		donut(m, at(cf, math.cos(angle) * 1.1, 0.4, math.sin(angle) * 1.1), 1.5, rgb(60, 35, 25), rgb(40, 25, 20))
	end
	donut(m, at(cf, 0, 0.9, 0) * CFrame.Angles(0, 0, rng:NextNumber(-0.2, 0.2)), 1.5, rgb(70, 40, 25), rgb(255, 120, 30))
	return m
end

local function warningSign(parent: Instance, cf: CFrame, _rng: Random): Model
	local m = model(parent, "WarningSign")
	cyl(m, "Post", 5, 0.3, at(cf, 0, 2.5, 0), rgb(110, 110, 115), M.Metal)
	block(m, "Sign", Vector3.new(2.6, 2.6, 0.2), at(cf, 0, 5.5, -0.2) * CFrame.Angles(0, 0, math.rad(45)), rgb(255, 210, 40))
	block(m, "Mark", Vector3.new(0.35, 1.3, 0.1), at(cf, 0, 5.75, -0.32), BLACK)
	block(m, "Dot", Vector3.new(0.35, 0.35, 0.1), at(cf, 0, 4.8, -0.32), BLACK)
	return m
end

local function miniOven(parent: Instance, cf: CFrame, _rng: Random): Model
	local m = model(parent, "Oven")
	block(m, "Body", Vector3.new(6, 5, 4), at(cf, 0, 2.5, 0), rgb(150, 70, 50), M.Brick)
	block(m, "Door", Vector3.new(3.6, 2.4, 0.2), at(cf, 0, 2.2, -2.05), rgb(40, 30, 30), M.Glass)
	block(m, "Glow", Vector3.new(3.2, 0.4, 0.1), at(cf, 0, 1.3, -2.15), rgb(255, 130, 30), M.Neon)
	cyl(m, "Chimney", 3, 1.2, at(cf, 1.8, 6.5, 0.8), rgb(120, 60, 45), M.Brick)
	return m
end

local function bakerRack(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "BakerRack")
	local metal = rgb(150, 150, 160)
	for _, x in { -2, 2 } do
		for _, z in { -0.9, 0.9 } do
			cyl(m, "Post", 6, 0.25, at(cf, x, 3, z), metal, M.Metal)
		end
	end
	for i = 1, 3 do
		local y = i * 1.8
		block(m, "Shelf", Vector3.new(4.4, 0.15, 2), at(cf, 0, y, 0), metal, M.DiamondPlate)
		for _, x in { -1.1, 1.1 } do
			cyl(m, "Dough", 0.4, 1.2, at(cf, x, y + 0.28, 0), rgb(225, 170, 100))
			cyl(m, "Frosting", 0.12, 1, at(cf, x, y + 0.52, 0), pick(CANDY, rng))
		end
	end
	return m
end

local function lavaBakery(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "LavaBakery")
	block(m, "BigOven", Vector3.new(12, 9, 7), at(cf, 0, 4.5, 4), rgb(120, 55, 40), M.Brick)
	blob(m, "OvenMouth", Vector3.new(6, 5, 0.6), at(cf, 0, 3, 0.5), rgb(255, 120, 20), M.Neon)
	cyl(m, "Chimney", 6, 2, at(cf, 3.5, 12, 5), rgb(100, 50, 40), M.Brick)
	bakerRack(m, at(cf, -9, 0, 1), rng)
	burntDonuts(m, at(cf, 8, 0, -1), rng)
	warningSign(m, at(cf, -4, 0, -5), rng)
	return m
end

--------------------------------------------------------------------------------
-- Chocolate Caverns
--------------------------------------------------------------------------------
local CHOC, CHOC_DARK = rgb(105, 60, 35), rgb(70, 38, 22)

local function rails(m: Instance, cf: CFrame, length: number)
	for _, x in { -1.2, 1.2 } do
		block(m, "Rail", Vector3.new(0.25, 0.25, length), at(cf, x, 0.35, 0), rgb(120, 120, 125), M.Metal)
	end
	for i = 0, math.floor(length / 2.5) do
		block(m, "Sleeper", Vector3.new(3.4, 0.25, 0.7), at(cf, 0, 0.12, -length / 2 + i * 2.5 + 0.5), rgb(110, 75, 45), M.Wood)
	end
end

local function mineCart(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "MineCart")
	rails(m, at(cf, 0, 0, 0), 12)
	local cart = at(cf, 0, 0, rng:NextNumber(-2, 2))
	local metal = rgb(90, 90, 95)
	block(m, "CartFloor", Vector3.new(2.8, 0.3, 4), cart * CFrame.new(0, 1.2, 0), metal, M.Metal)
	for _, x in { -1.4, 1.4 } do
		block(m, "CartSide", Vector3.new(0.25, 1.8, 4), cart * CFrame.new(x, 2.1, 0), metal, M.Metal)
	end
	for _, z in { -2, 2 } do
		block(m, "CartEnd", Vector3.new(2.8, 1.8, 0.25), cart * CFrame.new(0, 2.1, z), metal, M.Metal)
	end
	for _, x in { -1.25, 1.25 } do
		for _, z in { -1.3, 1.3 } do
			log(m, "Wheel", 0.3, 1, cart * CFrame.new(x, 0.75, z), BLACK, M.Metal)
		end
	end
	for _ = 1, 3 do
		block(m, "Chunk", Vector3.new(1.2, 1, 1.2), cart * CFrame.new(rng:NextNumber(-0.6, 0.6), 2.8, rng:NextNumber(-1.2, 1.2)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 1), 0), CHOC, M.Slate)
	end
	return m
end

local function supportBeam(parent: Instance, cf: CFrame, _rng: Random): Model
	local m = model(parent, "SupportBeam")
	for _, x in { -3, 3 } do
		block(m, "Post", Vector3.new(1, 9, 1), at(cf, x, 4.5, 0), rgb(120, 80, 45), M.Wood)
	end
	block(m, "Lintel", Vector3.new(8, 1, 1.2), at(cf, 0, 9.4, 0), rgb(120, 80, 45), M.Wood)
	rod(m, "Chain", pos(cf, 0, 8.9, 0), pos(cf, 0, 7.4, 0), 0.12, rgb(70, 70, 75), M.Metal)
	local lantern = block(m, "Lantern", Vector3.new(0.9, 1.2, 0.9), at(cf, 0, 6.8, 0), rgb(255, 210, 120), M.Neon)
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 200, 120)
	light.Range = 16
	light.Brightness = 1.2
	light.Parent = lantern
	return m
end

local function chocoBars(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "ChocoBars")
	for i = 0, 2 do
		local bar = at(cf, rng:NextNumber(-0.3, 0.3), 0.5 + i * 1, 0) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0)
		block(m, "Bar", Vector3.new(5, 1, 2.4), bar, if i == 1 then rgb(240, 225, 200) else CHOC, M.SmoothPlastic)
		for _, x in { -1.25, 0, 1.25 } do
			block(m, "Groove", Vector3.new(0.12, 0.08, 2.2), bar * CFrame.new(x, 0.52, 0), CHOC_DARK)
		end
	end
	return m
end

local function stalagmites(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "Stalagmites")
	for _ = 1, 3 do
		local h = rng:NextNumber(3, 7)
		local c = at(cf, rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		block(m, "Stalagmite", Vector3.new(h * 0.45, h * 0.6, h * 0.45), c * CFrame.new(0, h * 0.3, 0), CHOC_DARK, M.Slate)
		block(m, "Stalagmite", Vector3.new(h * 0.25, h * 0.5, h * 0.25), c * CFrame.new(0, h * 0.8, 0) * CFrame.Angles(0, math.rad(45), 0), CHOC, M.Slate)
	end
	return m
end

local function pickaxeBarrel(parent: Instance, cf: CFrame, _rng: Random): Model
	local m = model(parent, "PickaxeBarrel")
	cyl(m, "Barrel", 3, 2.2, at(cf, 0, 1.5, 0), rgb(130, 85, 50), M.WoodPlanks)
	for _, y in { 0.6, 2.4 } do
		cyl(m, "Band", 0.25, 2.3, at(cf, 0, y, 0), rgb(70, 70, 75), M.Metal)
	end
	rod(m, "Handle", pos(cf, 1.3, 0, -0.5), pos(cf, 1.6, 4, -1), 0.25, rgb(150, 105, 60), M.Wood)
	block(m, "Head", Vector3.new(0.3, 0.4, 2.4), CFrame.lookAt(pos(cf, 1.6, 3.9, -1), pos(cf, 1.6, 3.9, -3)), rgb(120, 120, 125), M.Metal)
	return m
end

local function chocoPuddle(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "ChocoPuddle")
	local puddle = cyl(m, "Puddle", 0.12, rng:NextNumber(5, 8), at(cf, 0, 0.06, 0), CHOC_DARK, M.SmoothPlastic)
	puddle.Reflectance = 0.25
	cyl(m, "Puddle", 0.14, rng:NextNumber(2, 3.5), at(cf, rng:NextNumber(2.5, 4), 0.07, rng:NextNumber(-1, 1)), CHOC_DARK, M.SmoothPlastic).Reflectance = 0.25
	return m
end

local function mineEntrance(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "MineEntrance")
	block(m, "Rockface", Vector3.new(16, 12, 4), at(cf, 0, 6, 8), CHOC_DARK, M.Rock)
	block(m, "Tunnel", Vector3.new(6, 7, 0.4), at(cf, 0, 3.5, 5.9), rgb(15, 10, 8))
	supportBeam(m, at(cf, 0, 0, 5.4), rng)
	rails(m, at(cf, 0, 0, -1), 13)
	mineCart(m, at(cf, 6, 0, -2) * CFrame.Angles(0, math.rad(25), 0), rng)
	return m
end

--------------------------------------------------------------------------------
-- Candy Cane Canyon
--------------------------------------------------------------------------------
local function gingerbreadHouse(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "GingerbreadHouse")
	local ginger, icing = rgb(180, 110, 55), WHITE
	block(m, "Walls", Vector3.new(7, 5, 6), at(cf, 0, 2.5, 0), ginger, M.SmoothPlastic)
	roof(m, at(cf, 0, 6.5, 0), 8, 7.6, 3.2, rgb(130, 75, 40), M.SmoothPlastic)
	for _, side in { -1, 1 } do
		block(m, "Icing", Vector3.new(8.2, 0.35, 0.35), at(cf, 0, 5.05, side * 3.75), icing)
		block(m, "Window", Vector3.new(1.4, 1.4, 0.15), at(cf, side * 2.2, 3, -3.05), rgb(255, 220, 120), M.Neon)
	end
	block(m, "Door", Vector3.new(1.6, 2.8, 0.15), at(cf, 0, 1.4, -3.05), rgb(220, 50, 60))
	for i = -1, 1 do
		ball(m, "Gumdrop", 0.9, at(cf, i * 2.6, 8.2, 0), pick(CANDY, rng))
	end
	block(m, "Chimney", Vector3.new(1.2, 2.4, 1.2), at(cf, 2.2, 8, 1.5), rgb(230, 70, 80))
	return m
end

local function gumdrops(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "Gumdrops")
	for _ = 1, 5 do
		local d = rng:NextNumber(1.6, 3)
		blob(m, "Gumdrop", Vector3.new(d, d * 0.9, d), at(cf, rng:NextNumber(-3, 3), d * 0.3, rng:NextNumber(-3, 3)), pick(CANDY, rng), M.Sand)
	end
	return m
end

local function peppermint(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "Peppermint")
	local disc = at(cf, 0, 3.1, 0) * CFrame.Angles(0, math.pi / 2, rng:NextNumber(-0.15, 0.15))
	log(m, "Mint", 0.8, 6, disc, WHITE)
	for i = 0, 2 do
		block(m, "Stripe", Vector3.new(0.9, 5.6, 0.7), disc * CFrame.Angles(math.rad(i * 60), 0, 0), rgb(230, 40, 50))
	end
	return m
end

local function wrappedCandies(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "WrappedCandies")
	for i = 1, 3 do
		local c = at(cf, (i - 2) * 2.4, 0.6, rng:NextNumber(-1, 1)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		local color = pick(CANDY, rng)
		blob(m, "Candy", Vector3.new(1.8, 1.2, 1.2), c, color)
		for _, side in { -1, 1 } do
			wedge(m, "Twist", Vector3.new(0.8, 1, 0.6), c * CFrame.new(side * 1.2, 0, 0) * CFrame.Angles(0, side * math.pi / 2, 0), color:Lerp(WHITE, 0.3))
		end
	end
	return m
end

local function candyCorn(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "CandyCorn")
	for i = 1, 3 do
		local c = at(cf, (i - 2) * 2.2, 0, rng:NextNumber(-0.8, 0.8)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		block(m, "Corn", Vector3.new(1.8, 1, 1.2), c * CFrame.new(0, 0.5, 0), rgb(255, 210, 50))
		block(m, "Corn", Vector3.new(1.3, 1, 1), c * CFrame.new(0, 1.5, 0), rgb(255, 140, 30))
		block(m, "Corn", Vector3.new(0.8, 0.8, 0.8), c * CFrame.new(0, 2.4, 0), WHITE)
	end
	return m
end

local function iceCream(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "IceCream")
	cyl(m, "Cone", 2.4, 1.4, at(cf, 0, 1.2, 0), rgb(220, 170, 100), M.WoodPlanks)
	cyl(m, "Cone", 1.4, 2.2, at(cf, 0, 3.1, 0), rgb(220, 170, 100), M.WoodPlanks)
	ball(m, "Scoop", 2.6, at(cf, 0, 4.6, 0), pick({ rgb(255, 170, 200), rgb(140, 90, 60), rgb(250, 245, 230) }, rng))
	ball(m, "Scoop", 2.2, at(cf, 0, 6.3, 0), pick({ rgb(160, 230, 160), rgb(255, 220, 120), rgb(200, 160, 255) }, rng))
	ball(m, "Cherry", 0.8, at(cf, 0, 7.6, 0), rgb(220, 30, 40))
	return m
end

local function candyVillage(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "CandyVillage")
	gingerbreadHouse(m, at(cf, -6, 0, 3), rng)
	gingerbreadHouse(m, at(cf, 7, 0, 5) * CFrame.Angles(0, math.rad(-15), 0), rng)
	for i = 0, 6 do
		local post = at(cf, -9 + i * 3, 0, -5)
		cyl(m, "FencePost", 2.4, 0.6, post * CFrame.new(0, 1.2, 0), if i % 2 == 0 then rgb(230, 40, 50) else WHITE)
		ball(m, "FenceTop", 0.8, post * CFrame.new(0, 2.6, 0), if i % 2 == 0 then WHITE else rgb(230, 40, 50))
	end
	iceCream(m, at(cf, 1, 0, -1), rng)
	return m
end

--------------------------------------------------------------------------------
-- Toy Factory
--------------------------------------------------------------------------------
local TOY = { rgb(235, 60, 60), rgb(60, 140, 235), rgb(255, 205, 50), rgb(70, 190, 90), rgb(255, 140, 40), rgb(170, 90, 230) }

local function blockStack(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "BlockStack")
	local spots = { { -3, 1.5, 0 }, { 0, 1.5, 0 }, { 3, 1.5, 0 }, { -1.5, 4.5, 0 }, { 1.5, 4.5, 0 }, { 0, 7.5, 0 } }
	for _, s in spots do
		local part = block(m, "ToyBlock", Vector3.new(3, 3, 3), at(cf, s[1], s[2], s[3]) * CFrame.Angles(0, rng:NextNumber(-0.15, 0.15), 0), pick(TOY, rng), M.Plastic)
		part.TopSurface = Enum.SurfaceType.Studs
	end
	return m
end

local function toyCar(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "ToyCar")
	local color = pick(TOY, rng)
	block(m, "Body", Vector3.new(3.4, 1.4, 6), at(cf, 0, 1.4, 0), color, M.Plastic)
	block(m, "Cabin", Vector3.new(3, 1.4, 3), at(cf, 0, 2.8, 0.4), color:Lerp(WHITE, 0.25), M.Plastic)
	block(m, "Windshield", Vector3.new(2.6, 1, 0.1), at(cf, 0, 2.9, -1.12), rgb(160, 210, 255), M.Glass)
	for _, x in { -1.7, 1.7 } do
		for _, z in { -2, 2 } do
			log(m, "Wheel", 0.6, 1.6, at(cf, x, 0.8, z), BLACK)
		end
	end
	for _, x in { -1.1, 1.1 } do
		block(m, "Headlight", Vector3.new(0.6, 0.4, 0.1), at(cf, x, 1.5, -3.02), rgb(255, 245, 180), M.Neon)
	end
	return m
end

local function rubberDuck(parent: Instance, cf: CFrame, _rng: Random): Model
	local m = model(parent, "RubberDuck")
	local yellow = rgb(255, 215, 40)
	blob(m, "Body", Vector3.new(5, 3.6, 6.4), at(cf, 0, 1.8, 0), yellow)
	ball(m, "Head", 3.2, at(cf, 0, 4.4, -1.8), yellow)
	blob(m, "Beak", Vector3.new(1.8, 0.7, 1.6), at(cf, 0, 4.1, -3.4), rgb(255, 130, 30))
	for _, x in { -0.8, 0.8 } do
		ball(m, "Eye", 0.6, at(cf, x, 5, -3), BLACK)
	end
	wedge(m, "Tail", Vector3.new(1.6, 1.4, 1.4), at(cf, 0, 3, 3.2), yellow)
	return m
end

local function teddyBear(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "TeddyBear")
	local fur = pick({ rgb(170, 115, 70), rgb(230, 170, 120), rgb(240, 200, 210) }, rng)
	blob(m, "Body", Vector3.new(3.4, 3.8, 3), at(cf, 0, 2.6, 0), fur, M.Fabric)
	ball(m, "Head", 2.8, at(cf, 0, 5.4, -0.1), fur, M.Fabric)
	for _, side in { -1, 1 } do
		ball(m, "Ear", 1.1, at(cf, side * 1.1, 6.6, 0), fur, M.Fabric)
		ball(m, "Eye", 0.35, at(cf, side * 0.5, 5.7, -1.25), BLACK)
		blob(m, "Arm", Vector3.new(1, 2.4, 1), at(cf, side * 1.9, 3.2, -0.4) * CFrame.Angles(math.rad(-30), 0, side * math.rad(25)), fur, M.Fabric)
		blob(m, "Leg", Vector3.new(1.2, 1.2, 2.2), at(cf, side * 1, 0.6, -1.2), fur, M.Fabric)
	end
	blob(m, "Muzzle", Vector3.new(1.3, 0.9, 0.8), at(cf, 0, 5, -1.25), fur:Lerp(WHITE, 0.4), M.Fabric)
	ball(m, "Nose", 0.4, at(cf, 0, 5.2, -1.65), BLACK)
	cyl(m, "Bow", 0.4, 1.4, at(cf, 0, 4.2, -0.4) * CFrame.Angles(math.rad(90), 0, 0), rgb(230, 50, 70), M.Fabric)
	return m
end

local function rockingHorse(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "RockingHorse")
	local wood = rgb(220, 170, 110)
	for _, x in { -1, 1 } do
		blob(m, "Rocker", Vector3.new(0.4, 1, 8), at(cf, x, 0.4, 0), rgb(170, 60, 50), M.Wood)
		for _, z in { -2, 2 } do
			rod(m, "Leg", pos(cf, x, 0.6, z), pos(cf, x * 0.6, 3.2, z * 0.8), 0.4, wood, M.Wood)
		end
	end
	blob(m, "Body", Vector3.new(2, 2, 5), at(cf, 0, 3.6, 0), wood, M.Wood)
	rod(m, "Neck", pos(cf, 0, 4, -2), pos(cf, 0, 6, -2.8), 1.1, wood, M.Wood)
	blob(m, "Head", Vector3.new(1.2, 1.2, 2.4), at(cf, 0, 6.2, -3.4), wood, M.Wood)
	block(m, "Mane", Vector3.new(0.4, 2.2, 1), at(cf, 0, 5.8, -2.2) * CFrame.Angles(math.rad(-30), 0, 0), pick(TOY, rng), M.Fabric)
	block(m, "Saddle", Vector3.new(2.2, 0.3, 1.8), at(cf, 0, 4.6, 0.2), rgb(200, 40, 50), M.Fabric)
	return m
end

local function toySoldier(parent: Instance, cf: CFrame, _rng: Random): Model
	local m = model(parent, "ToySoldier")
	for _, x in { -0.5, 0.5 } do
		block(m, "Leg", Vector3.new(0.8, 3, 0.9), at(cf, x, 1.5, 0), rgb(40, 50, 120))
	end
	block(m, "Coat", Vector3.new(2, 2.8, 1.2), at(cf, 0, 4.4, 0), rgb(220, 40, 50))
	block(m, "Belt", Vector3.new(2.05, 0.35, 1.25), at(cf, 0, 3.4, 0), WHITE)
	for _, x in { -1.3, 1.3 } do
		block(m, "Arm", Vector3.new(0.6, 2.4, 0.7), at(cf, x, 4.4, 0), rgb(220, 40, 50))
	end
	ball(m, "Head", 1.4, at(cf, 0, 6.4, 0), rgb(255, 210, 170))
	cyl(m, "Hat", 2, 1.4, at(cf, 0, 7.8, 0), BLACK)
	ball(m, "Plume", 0.6, at(cf, 0, 8.9, 0), rgb(255, 205, 50))
	return m
end

local function beachBall(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "BeachBall")
	local d = rng:NextNumber(3, 4.5)
	ball(m, "Ball", d, at(cf, 0, d / 2, 0), WHITE)
	blob(m, "Stripe", Vector3.new(d * 1.02, d * 1.02, d * 0.3), at(cf, 0, d / 2, 0), rgb(235, 60, 60))
	blob(m, "Stripe", Vector3.new(d * 0.3, d * 1.02, d * 1.02), at(cf, 0, d / 2, 0), rgb(60, 140, 235))
	return m
end

local function toyPile(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "ToyPile")
	teddyBear(m, at(cf, -5, 0, 2), rng)
	blockStack(m, at(cf, 5, 0, 4), rng)
	rubberDuck(m, at(cf, 0, 0, -5) * CFrame.Angles(0, math.rad(-30), 0), rng)
	beachBall(m, at(cf, -7, 0, -5), rng)
	return m
end

--------------------------------------------------------------------------------
-- Haunted Donuttery (friendly spooky)
--------------------------------------------------------------------------------
local function pumpkin(m: Instance, cf: CFrame, size: number, face: boolean)
	blob(m, "Pumpkin", Vector3.new(size, size * 0.75, size), cf * CFrame.new(0, size * 0.36, 0), rgb(255, 130, 20))
	cyl(m, "Stem", size * 0.3, size * 0.15, cf * CFrame.new(0, size * 0.8, 0), rgb(80, 120, 40))
	if face then
		for _, x in { -0.22, 0.22 } do
			wedge(m, "PumpkinEye", Vector3.new(0.1, size * 0.18, size * 0.2), cf * CFrame.new(x * size, size * 0.48, -size * 0.49) * CFrame.Angles(0, math.sign(x) * math.pi / 2, 0), rgb(255, 230, 90), M.Neon)
		end
		block(m, "PumpkinMouth", Vector3.new(size * 0.45, size * 0.1, 0.1), cf * CFrame.new(0, size * 0.25, -size * 0.49), rgb(255, 230, 90), M.Neon)
	end
end

local function pumpkinPatch(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "PumpkinPatch")
	pumpkin(m, at(cf, -2.4, 0, 0.5), 3, true)
	pumpkin(m, at(cf, 1.8, 0, 1), 2.4, false)
	pumpkin(m, at(cf, 0, 0, -2.2) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), 1.8, rng:NextNumber() < 0.5)
	return m
end

local function graves(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "Graves")
	for i = -1, 1 do
		local c = at(cf, i * 3.2, 0, rng:NextNumber(-0.5, 0.5)) * CFrame.Angles(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.1, 0.1))
		block(m, "Stone", Vector3.new(2, 2.6, 0.5), c * CFrame.new(0, 1.3, 0), rgb(140, 140, 150), M.Slate)
		log(m, "StoneTop", 0.5, 2, c * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, math.pi / 2, 0), rgb(140, 140, 150), M.Slate)
		blob(m, "Mound", Vector3.new(2.2, 0.6, 3.4), c * CFrame.new(0, 0.1, 2), rgb(70, 60, 55), M.Ground)
	end
	return m
end

local function ghost(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "FriendlyGhost")
	local g = at(cf, 0, rng:NextNumber(4, 7), 0)
	local body = blob(m, "Ghost", Vector3.new(3, 3.6, 2.6), g, rgb(240, 245, 255))
	body.Transparency = 0.2
	for i = -1, 1 do
		local tail = blob(m, "GhostTail", Vector3.new(1, 1.4, 1), g * CFrame.new(i * 0.9, -1.9, 0.2), rgb(240, 245, 255))
		tail.Transparency = 0.25
	end
	for _, x in { -0.55, 0.55 } do
		blob(m, "Eye", Vector3.new(0.45, 0.7, 0.2), g * CFrame.new(x, 0.5, -1.2), BLACK)
	end
	blob(m, "Mouth", Vector3.new(0.5, 0.4, 0.2), g * CFrame.new(0, -0.2, -1.25), rgb(255, 150, 170))
	for _, side in { -1, 1 } do
		blob(m, "Hand", Vector3.new(0.8, 1.4, 0.7), g * CFrame.new(side * 1.6, 0.1, -0.2) * CFrame.Angles(0, 0, side * math.rad(-40)), rgb(240, 245, 255)).Transparency = 0.2
	end
	return m
end

local function deadTree(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "SpookyTree")
	local bark = rgb(60, 45, 50)
	local top = pos(cf, rng:NextNumber(-0.8, 0.8), 9, rng:NextNumber(-0.8, 0.8))
	rod(m, "Trunk", pos(cf, 0, 0, 0), top, 1.4, bark, M.Wood)
	for i = 1, 4 do
		local from = pos(cf, 0, 4 + i * 1.2, 0)
		local angle = i * 1.7 + rng:NextNumber(-0.3, 0.3)
		rod(m, "Branch", from, from + Vector3.new(math.cos(angle) * 3.5, rng:NextNumber(1, 3), math.sin(angle) * 3.5), 0.45, bark, M.Wood)
	end
	return m
end

local function candles(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "Candles")
	block(m, "Table", Vector3.new(4, 0.3, 2), at(cf, 0, 2.6, 0), rgb(60, 40, 45), M.Wood)
	for _, x in { -1.7, 1.7 } do
		block(m, "TableLeg", Vector3.new(0.3, 2.5, 0.3), at(cf, x, 1.25, 0), rgb(60, 40, 45), M.Wood)
	end
	for i = -1, 1 do
		local h = rng:NextNumber(0.8, 1.6)
		cyl(m, "Candle", h, 0.4, at(cf, i * 1.1, 2.75 + h / 2, 0), rgb(245, 235, 210))
		blob(m, "Flame", Vector3.new(0.3, 0.5, 0.3), at(cf, i * 1.1, 2.95 + h, 0), rgb(255, 210, 90), M.Neon)
	end
	return m
end

local function ironFence(parent: Instance, cf: CFrame, _rng: Random): Model
	local m = model(parent, "IronFence")
	for _, y in { 0.8, 3.4 } do
		block(m, "Rail", Vector3.new(9, 0.25, 0.25), at(cf, 0, y, 0), BLACK, M.Metal)
	end
	for i = 0, 6 do
		local x = -4.5 + i * 1.5
		block(m, "Bar", Vector3.new(0.25, 4.2, 0.25), at(cf, x, 2.1, 0), BLACK, M.Metal)
		block(m, "Spike", Vector3.new(0.35, 0.35, 0.35), at(cf, x, 4.3, 0) * CFrame.Angles(0, 0, math.rad(45)), BLACK, M.Metal)
	end
	return m
end

local function ghostParty(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "GhostParty")
	ironFence(m, at(cf, -4, 0, 6), rng)
	ironFence(m, at(cf, 5, 0, 6), rng)
	pumpkinPatch(m, at(cf, -6, 0, 1), rng)
	cauldron(m, at(cf, 4, 0, 0), rng, rgb(120, 255, 100))
	ghost(m, at(cf, -1, 0, -2), rng)
	ghost(m, at(cf, 7, 0, -4), rng)
	return m
end

--------------------------------------------------------------------------------
-- Cloud Bakery
--------------------------------------------------------------------------------
local function cloudPuff(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "CloudPuff")
	for i = 1, 5 do
		local d = rng:NextNumber(2.5, 4.5)
		ball(m, "Cloud", d, at(cf, (i - 3) * 1.8, d * 0.35 + rng:NextNumber(0, 0.8), rng:NextNumber(-1, 1)), WHITE)
	end
	return m
end

local function hotAirBalloon(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "HotAirBalloon")
	local c = at(cf, 0, rng:NextNumber(14, 24), 0)
	local color = pick(CANDY, rng)
	blob(m, "Balloon", Vector3.new(8, 9.5, 8), c, color, M.Fabric)
	cyl(m, "Band", 1.2, 8.1, c * CFrame.new(0, 0.6, 0), WHITE, M.Fabric)
	block(m, "Basket", Vector3.new(2.4, 1.8, 2.4), c * CFrame.new(0, -7.6, 0), rgb(170, 120, 70), M.WoodPlanks)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			rod(m, "Rope", (c * CFrame.new(x * 1.1, -6.7, z * 1.1)).Position, (c * CFrame.new(x * 2.4, -3.8, z * 2.4)).Position, 0.1, rgb(80, 60, 40))
		end
	end
	ball(m, "Burner", 0.7, c * CFrame.new(0, -5.6, 0), rgb(255, 170, 60), M.Neon)
	return m
end

local function kite(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "Kite")
	local top = at(cf, rng:NextNumber(-2, 2), rng:NextNumber(14, 20), 0)
	local color = pick(CANDY, rng)
	block(m, "Kite", Vector3.new(3, 3, 0.15), top * CFrame.Angles(0, 0, math.rad(45)), color, M.Fabric)
	block(m, "KiteStick", Vector3.new(0.12, 4.2, 0.12), top * CFrame.new(0, 0, -0.1), rgb(150, 100, 60), M.Wood)
	for i = 1, 3 do
		blob(m, "Bow", Vector3.new(0.7, 0.4, 0.2), top * CFrame.new(0.3 * i, -2.2 - i * 1.1, 0), pick(CANDY, rng), M.Fabric)
	end
	rod(m, "String", top.Position, pos(cf, 0, 0.5, 0), 0.05, WHITE)
	cyl(m, "Stake", 1, 0.3, at(cf, 0, 0.5, 0), rgb(150, 100, 60), M.Wood)
	return m
end

local function cupcake(m: Instance, cf: CFrame, rng: Random)
	cyl(m, "Wrapper", 1, 1.2, cf * CFrame.new(0, 0.5, 0), pick(CANDY, rng), M.Fabric)
	ball(m, "Frosting", 1.3, cf * CFrame.new(0, 1.2, 0), rgb(255, 235, 245))
	ball(m, "Cherry", 0.4, cf * CFrame.new(0, 1.9, 0), rgb(220, 30, 40))
end

local function cupcakeStall(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "CupcakeStall")
	block(m, "Counter", Vector3.new(7, 3.2, 2.6), at(cf, 0, 1.6, 0), rgb(255, 200, 225))
	for _, x in { -3.3, 3.3 } do
		cyl(m, "Post", 4, 0.3, at(cf, x, 5.2, 1), WHITE)
	end
	for i = 0, 5 do
		block(m, "Awning", Vector3.new(1.2, 0.2, 3.6), at(cf, -3 + i * 1.2, 7.3, 0) * CFrame.Angles(math.rad(-12), 0, 0), if i % 2 == 0 then rgb(255, 120, 170) else WHITE, M.Fabric)
	end
	for i = -1, 1 do
		cupcake(m, at(cf, i * 2, 3.2, -0.3), rng)
	end
	return m
end

local function layerCake(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "LayerCake")
	for i = 0, 2 do
		local d = 6 - i * 1.6
		cyl(m, "Tier", 1.6, d, at(cf, 0, 0.8 + i * 1.7, 0), rgb(255, 240, 220))
		cyl(m, "Icing", 0.3, d + 0.2, at(cf, 0, 1.6 + i * 1.7, 0), pick(CANDY, rng))
	end
	for i = -1, 1 do
		cyl(m, "Candle", 1, 0.25, at(cf, i * 0.7, 5.9, 0), WHITE)
		blob(m, "Flame", Vector3.new(0.25, 0.45, 0.25), at(cf, i * 0.7, 6.6, 0), rgb(255, 200, 80), M.Neon)
	end
	return m
end

local function balloonFestival(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "BalloonFestival")
	hotAirBalloon(m, at(cf, -7, 0, 4), rng)
	hotAirBalloon(m, at(cf, 6, 0, 8), rng)
	hotAirBalloon(m, at(cf, 0, 6, -4), rng)
	cupcakeStall(m, at(cf, 0, 0, 0), rng)
	return m
end

--------------------------------------------------------------------------------
-- Neon Streets
--------------------------------------------------------------------------------
local NEON = { rgb(255, 40, 200), rgb(0, 230, 255), rgb(255, 220, 0), rgb(40, 255, 120) }

local function vendingMachine(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "VendingMachine")
	local glow = pick(NEON, rng)
	block(m, "Body", Vector3.new(3, 6, 2), at(cf, 0, 3, 0), rgb(40, 40, 55), M.Metal)
	block(m, "Front", Vector3.new(2.2, 4, 0.1), at(cf, -0.2, 3.6, -1.02), glow, M.Neon, 0.3)
	block(m, "Slot", Vector3.new(2, 0.6, 0.15), at(cf, 0, 1, -1.02), BLACK)
	for i = 0, 2 do
		block(m, "Button", Vector3.new(0.25, 0.25, 0.1), at(cf, 1.15, 3.2 + i * 0.6, -1.03), glow:Lerp(WHITE, 0.4), M.Neon)
	end
	return m
end

local function trafficCones(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "TrafficCones")
	for i = 1, 3 do
		local c = at(cf, (i - 2) * 2.2, 0, rng:NextNumber(-0.8, 0.8))
		block(m, "ConeBase", Vector3.new(1.6, 0.2, 1.6), c * CFrame.new(0, 0.1, 0), BLACK)
		cyl(m, "Cone", 1, 1.1, c * CFrame.new(0, 0.7, 0), rgb(255, 120, 20))
		cyl(m, "ConeBand", 0.5, 0.8, c * CFrame.new(0, 1.45, 0), WHITE, M.Neon)
		cyl(m, "Cone", 0.7, 0.55, c * CFrame.new(0, 2.05, 0), rgb(255, 120, 20))
	end
	return m
end

local function foodCart(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "FoodCart")
	local glow = pick(NEON, rng)
	block(m, "Cart", Vector3.new(5, 3, 2.6), at(cf, 0, 2.1, 0), rgb(60, 60, 75), M.Metal)
	for _, x in { -1.8, 1.8 } do
		log(m, "Wheel", 0.4, 1.6, at(cf, x, 0.8, -1.4) * CFrame.Angles(0, math.pi / 2, 0), BLACK)
	end
	block(m, "Awning", Vector3.new(5.6, 0.25, 3.4), at(cf, 0, 6.2, 0.2), rgb(40, 40, 55), M.Metal)
	block(m, "AwningGlow", Vector3.new(5.6, 0.3, 0.2), at(cf, 0, 6, -1.5), glow, M.Neon)
	for _, x in { -2.5, 2.5 } do
		cyl(m, "Post", 2.6, 0.2, at(cf, x, 4.8, 1.4), rgb(90, 90, 100), M.Metal)
	end
	block(m, "Sign", Vector3.new(3, 1, 0.15), at(cf, 0, 7, -1.5), glow, M.Neon, 0.2)
	return m
end

local function scooter(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "Scooter")
	local glow = pick(NEON, rng)
	block(m, "Deck", Vector3.new(1, 0.25, 4), at(cf, 0, 0.75, 0), rgb(40, 40, 50), M.Metal)
	for _, z in { -1.8, 1.8 } do
		log(m, "Wheel", 0.3, 1, at(cf, 0, 0.5, z), BLACK)
	end
	rod(m, "Stem", pos(cf, 0, 0.8, -1.8), pos(cf, 0, 4, -2.1), 0.2, rgb(90, 90, 100), M.Metal)
	log(m, "Bar", 2, 0.2, at(cf, 0, 4, -2.1), rgb(90, 90, 100), M.Metal)
	block(m, "Glow", Vector3.new(0.9, 0.1, 3.6), at(cf, 0, 0.55, 0), glow, M.Neon)
	return m
end

local function phoneBooth(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "PhoneBooth")
	local glow = pick(NEON, rng)
	for _, x in { -1.3, 1.3 } do
		for _, z in { -1.3, 1.3 } do
			block(m, "Frame", Vector3.new(0.25, 7, 0.25), at(cf, x, 3.5, z), rgb(40, 40, 55), M.Metal)
		end
	end
	block(m, "Glass", Vector3.new(2.5, 6.6, 2.5), at(cf, 0, 3.4, 0), rgb(160, 210, 255), M.Glass, 0.6)
	block(m, "Roof", Vector3.new(3, 0.5, 3), at(cf, 0, 7.2, 0), glow, M.Neon)
	block(m, "Phone", Vector3.new(0.8, 1.2, 0.4), at(cf, 0, 4.2, 1.05), BLACK, M.Metal)
	return m
end

local function holoAd(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "HoloAd")
	local glow = pick(NEON, rng)
	cyl(m, "Pole", 8, 0.4, at(cf, 0, 4, 0), rgb(60, 60, 75), M.Metal)
	block(m, "Frame", Vector3.new(6.4, 3.8, 0.3), at(cf, 0, 9.8, 0), rgb(40, 40, 55), M.Metal)
	block(m, "Screen", Vector3.new(6, 3.4, 0.1), at(cf, 0, 9.8, -0.2), glow, M.Neon, 0.35)
	donut(m, at(cf, 0, 9.8, -0.4) * CFrame.Angles(math.rad(90), 0, 0), 2.2, glow:Lerp(WHITE, 0.5), WHITE)
	return m
end

local function streetCorner(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "StreetCorner")
	vendingMachine(m, at(cf, -6, 0, 3), rng)
	vendingMachine(m, at(cf, -2.8, 0, 3), rng)
	bench(m, at(cf, 3, 0, 2), rng, rgb(60, 60, 75), rgb(30, 30, 40))
	phoneBooth(m, at(cf, 9, 0, 3), rng)
	trafficCones(m, at(cf, 0, 0, -5), rng)
	return m
end

--------------------------------------------------------------------------------
-- Robot Factory
--------------------------------------------------------------------------------
local function crates(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "Crates")
	local spots = { { -1.6, 1.5, 0 }, { 1.6, 1.5, 0.3 }, { 0, 4.5, 0.1 } }
	for _, s in spots do
		block(m, "Crate", Vector3.new(3, 3, 3), at(cf, s[1], s[2], s[3]) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), rgb(170, 120, 70), M.WoodPlanks)
	end
	block(m, "HazardLabel", Vector3.new(1.4, 1, 0.1), at(cf, -1.6, 1.6, -1.55), rgb(255, 200, 0))
	return m
end

local function barrels(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "Barrels")
	for i = 1, 3 do
		local c = at(cf, (i - 2) * 2.4, 0, rng:NextNumber(-0.6, 0.6))
		local color = pick({ rgb(60, 110, 200), rgb(200, 60, 50), rgb(70, 160, 80) }, rng)
		cyl(m, "Barrel", 3.2, 2.2, c * CFrame.new(0, 1.6, 0), color, M.Metal)
		cyl(m, "Band", 0.4, 2.3, c * CFrame.new(0, 2.4, 0), rgb(255, 200, 0), M.Metal)
	end
	return m
end

local function robotArm(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "RobotArm")
	local orange = rgb(255, 150, 30)
	cyl(m, "Base", 1, 4, at(cf, 0, 0.5, 0), rgb(60, 60, 70), M.Metal)
	cyl(m, "Turntable", 1, 2.6, at(cf, 0, 1.5, 0), orange, M.Metal)
	local shoulder = pos(cf, 0, 2.2, 0)
	local elbow = pos(cf, rng:NextNumber(-1, 1), 7, 2)
	local wrist = pos(cf, 0, 6, -2.5)
	rod(m, "LowerArm", shoulder, elbow, 1.2, orange, M.Metal)
	ball(m, "Joint", 1.6, CFrame.new(elbow), rgb(60, 60, 70), M.Metal)
	rod(m, "UpperArm", elbow, wrist, 0.9, orange, M.Metal)
	for _, x in { -0.4, 0.4 } do
		block(m, "Claw", Vector3.new(0.25, 1.2, 0.3), CFrame.new(wrist + Vector3.new(x, -0.7, 0)), rgb(80, 80, 90), M.Metal)
	end
	ball(m, "Light", 0.4, CFrame.new(elbow + Vector3.new(0, 0.9, 0)), rgb(0, 255, 120), M.Neon)
	return m
end

local function littleRobot(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "LittleRobot")
	local shell = pick({ rgb(200, 205, 215), rgb(255, 200, 60), rgb(90, 170, 255) }, rng)
	for _, x in { -0.9, 0.9 } do
		block(m, "Tread", Vector3.new(0.8, 0.9, 2.4), at(cf, x, 0.45, 0), BLACK, M.Metal)
	end
	block(m, "Body", Vector3.new(2.6, 2.4, 2), at(cf, 0, 2.1, 0), shell, M.Metal)
	block(m, "Head", Vector3.new(1.8, 1.4, 1.6), at(cf, 0, 4, 0), shell, M.Metal)
	for _, x in { -0.4, 0.4 } do
		block(m, "Eye", Vector3.new(0.4, 0.4, 0.1), at(cf, x, 4.1, -0.82), rgb(0, 230, 255), M.Neon)
	end
	rod(m, "Antenna", pos(cf, 0, 4.7, 0), pos(cf, 0, 5.7, 0), 0.12, rgb(80, 80, 90), M.Metal)
	ball(m, "AntennaTip", 0.4, at(cf, 0, 5.8, 0), rgb(255, 60, 60), M.Neon)
	for _, side in { -1, 1 } do
		rod(m, "Arm", pos(cf, side * 1.3, 2.8, 0), pos(cf, side * 2, 1.6, -0.6), 0.3, rgb(80, 80, 90), M.Metal)
	end
	return m
end

local function gearPile(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "GearPile")
	gear(m, at(cf, -1, 0.4, 0) * CFrame.Angles(0, 0, math.pi / 2), 4, 0.6, 8, pick({ rgb(160, 160, 170), rgb(205, 160, 60) }, rng))
	gear(m, at(cf, 2, 0.35, 1) * CFrame.Angles(0, 0, math.pi / 2), 2.6, 0.5, 6, rgb(205, 160, 60))
	gear(m, at(cf, 0.5, 2.4, 0.5) * CFrame.Angles(0, rng:NextNumber(0, 1), math.rad(60)), 2.2, 0.4, 6, rgb(160, 160, 170))
	return m
end

local function forklift(parent: Instance, cf: CFrame, _rng: Random): Model
	local m = model(parent, "Forklift")
	local yellow = rgb(255, 200, 30)
	block(m, "Body", Vector3.new(3.4, 2.2, 4.4), at(cf, 0, 1.9, 0.6), yellow, M.Metal)
	for _, x in { -1.5, 1.5 } do
		for _, z in { -1, 2.4 } do
			log(m, "Wheel", 0.6, 1.5, at(cf, x, 0.75, z), BLACK)
		end
		rod(m, "CabPost", pos(cf, x, 3, 1.8), pos(cf, x, 6, 1.8), 0.25, BLACK, M.Metal)
		rod(m, "CabPost", pos(cf, x, 3, -0.6), pos(cf, x, 6, -0.6), 0.25, BLACK, M.Metal)
	end
	block(m, "CabRoof", Vector3.new(3.4, 0.25, 2.8), at(cf, 0, 6.1, 0.6), BLACK, M.Metal)
	for _, x in { -1, 1 } do
		block(m, "Mast", Vector3.new(0.35, 6, 0.35), at(cf, x, 3, -1.8), rgb(80, 80, 90), M.Metal)
		block(m, "Fork", Vector3.new(0.4, 0.2, 3), at(cf, x * 0.8, 0.5, -3.3), rgb(80, 80, 90), M.Metal)
	end
	return m
end

local function assemblyLine(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "AssemblyLine")
	block(m, "Belt", Vector3.new(4, 0.5, 20), at(cf, 0, 2.2, 0), rgb(35, 35, 40), M.Metal)
	for i = -2, 2 do
		block(m, "BeltLeg", Vector3.new(4.2, 2, 0.4), at(cf, 0, 1, i * 4.5), rgb(80, 80, 90), M.Metal)
	end
	for i = -1, 1 do
		block(m, "Box", Vector3.new(1.8, 1.8, 1.8), at(cf, 0, 3.35, i * 6 + rng:NextNumber(-1, 1)), pick({ rgb(255, 150, 190), rgb(190, 120, 255), rgb(255, 210, 60) }, rng))
	end
	robotArm(m, at(cf, -5, 0, -4) * CFrame.Angles(0, math.rad(-70), 0), rng)
	robotArm(m, at(cf, 5, 0, 4) * CFrame.Angles(0, math.rad(110), 0), rng)
	littleRobot(m, at(cf, 6, 0, -6), rng)
	return m
end

--------------------------------------------------------------------------------
-- Clockwork Void
--------------------------------------------------------------------------------
local BRASS = rgb(210, 165, 70)

local function standingGear(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "StandingGear")
	block(m, "Stand", Vector3.new(2, 1, 3), at(cf, 0, 0.5, 0), rgb(70, 60, 90), M.Metal)
	local d = rng:NextNumber(6, 9)
	gear(m, at(cf, 0, d / 2 + 0.4, 0) * CFrame.Angles(0, math.pi / 2, rng:NextNumber(0, 1)), d, 0.8, 10, BRASS)
	return m
end

local function hourglass(parent: Instance, cf: CFrame, _rng: Random): Model
	local m = model(parent, "Hourglass")
	for _, y in { 0.3, 7.2 } do
		cyl(m, "Plate", 0.6, 4, at(cf, 0, y, 0), rgb(120, 80, 50), M.Wood)
	end
	for i = 0, 2 do
		local angle = i / 3 * math.pi * 2
		cyl(m, "Post", 6.4, 0.35, at(cf, math.cos(angle) * 1.6, 3.75, math.sin(angle) * 1.6), BRASS, M.Metal)
	end
	for _, y in { 2.2, 5.3 } do
		local glass = ball(m, "Glass", 3, at(cf, 0, y, 0), rgb(200, 230, 255), M.Glass)
		glass.Transparency = 0.6
	end
	ball(m, "Sand", 1.8, at(cf, 0, 1.6, 0), rgb(240, 210, 130), M.Sand)
	ball(m, "Sand", 1, at(cf, 0, 5.9, 0), rgb(240, 210, 130), M.Sand)
	return m
end

local function pocketWatch(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "PocketWatch")
	local w = at(cf, 0, 0.5, 0) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, math.pi), 0)
	cyl(m, "Case", 0.6, 5, w, BRASS, M.Metal)
	cyl(m, "Face", 0.62, 4.2, w * CFrame.new(0, 0.02, 0), rgb(250, 245, 230))
	block(m, "Hand", Vector3.new(0.15, 0.1, 1.7), w * CFrame.new(0, 0.36, -0.7), BLACK)
	block(m, "Hand", Vector3.new(1.2, 0.1, 0.15), w * CFrame.new(0.5, 0.36, 0), BLACK)
	cyl(m, "Crown", 0.6, 0.6, w * CFrame.new(0, 0, -2.8) * CFrame.Angles(math.pi / 2, 0, 0), BRASS, M.Metal)
	return m
end

local function grandfatherClock(parent: Instance, cf: CFrame, _rng: Random): Model
	local m = model(parent, "GrandfatherClock")
	local wood = rgb(110, 65, 40)
	block(m, "Case", Vector3.new(2.6, 9, 1.6), at(cf, 0, 4.5, 0), wood, M.Wood)
	block(m, "Top", Vector3.new(3, 0.8, 1.9), at(cf, 0, 9.4, 0), wood, M.Wood)
	log(m, "Face", 0.15, 2.2, at(cf, 0, 7.8, -0.85) * CFrame.Angles(0, math.pi / 2, 0), rgb(250, 245, 230))
	block(m, "Hand", Vector3.new(0.1, 0.9, 0.05), at(cf, 0, 8.15, -0.95), BLACK)
	block(m, "Hand", Vector3.new(0.6, 0.1, 0.05), at(cf, 0.25, 7.8, -0.95), BLACK)
	block(m, "Window", Vector3.new(1.6, 4, 0.1), at(cf, 0, 3.6, -0.82), rgb(40, 30, 30), M.Glass)
	rod(m, "Pendulum", pos(cf, 0, 6.2, -0.9), pos(cf, 0.4, 2.6, -0.9), 0.12, BRASS, M.Metal)
	log(m, "Bob", 0.15, 0.9, at(cf, 0.4, 2.5, -0.92) * CFrame.Angles(0, math.pi / 2, 0), BRASS, M.Metal)
	return m
end

local function springs(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "Springs")
	for s = 1, 2 do
		local c = at(cf, (s - 1.5) * 3, 0, rng:NextNumber(-0.5, 0.5))
		for i = 0, 5 do
			cyl(m, "Coil", 0.25, 1.8, c * CFrame.new(math.sin(i) * 0.1, 0.3 + i * 0.55, 0) * CFrame.Angles(0, 0, math.rad(if i % 2 == 0 then 6 else -6)), rgb(190, 190, 200), M.Metal)
		end
	end
	return m
end

local function clockPlaza(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "ClockPlaza")
	standingGear(m, at(cf, -6, 0, 4), rng)
	grandfatherClock(m, at(cf, 5, 0, 5), rng)
	hourglass(m, at(cf, 0, 0, -1), rng)
	pocketWatch(m, at(cf, 7, 0, -4), rng)
	springs(m, at(cf, -6, 0, -5), rng)
	return m
end

--------------------------------------------------------------------------------
-- Donut Heaven
--------------------------------------------------------------------------------
local MARBLE, GOLD = rgb(250, 246, 236), rgb(255, 210, 90)

local function columns(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "Columns")
	for i = -1, 1 do
		local h = if i == 1 then rng:NextNumber(3, 5) else 9
		local c = at(cf, i * 4, 0, 0)
		block(m, "ColumnBase", Vector3.new(2.6, 0.8, 2.6), c * CFrame.new(0, 0.4, 0), MARBLE, M.Marble)
		cyl(m, "Column", h, 1.8, c * CFrame.new(0, 0.8 + h / 2, 0), MARBLE, M.Marble)
		if i < 1 then
			block(m, "ColumnCap", Vector3.new(2.6, 0.8, 2.6), c * CFrame.new(0, h + 1.2, 0), GOLD, M.Marble)
		end
	end
	block(m, "Rubble", Vector3.new(1.6, 1.2, 1.4), at(cf, 5.5, 0.6, -2) * CFrame.Angles(0.3, 0.6, 0.2), MARBLE, M.Marble)
	return m
end

local function fountain(parent: Instance, cf: CFrame, _rng: Random): Model
	local m = model(parent, "Fountain")
	cyl(m, "Basin", 1.6, 11, at(cf, 0, 0.8, 0), MARBLE, M.Marble)
	cyl(m, "Water", 0.2, 10, at(cf, 0, 1.55, 0), rgb(150, 210, 255), M.Glass, 0.2)
	cyl(m, "Pillar", 4, 1.4, at(cf, 0, 3.2, 0), MARBLE, M.Marble)
	cyl(m, "Bowl", 0.8, 4.6, at(cf, 0, 5.4, 0), GOLD, M.Marble)
	ball(m, "Spout", 1.4, at(cf, 0, 6.4, 0), rgb(180, 230, 255), M.Neon)
	return m
end

local function goldenHarp(parent: Instance, cf: CFrame, _rng: Random): Model
	local m = model(parent, "GoldenHarp")
	block(m, "Base", Vector3.new(1.4, 0.6, 3.4), at(cf, 0, 0.3, 0), GOLD, M.Metal)
	local bottomBack, topBack, topFront = pos(cf, 0, 0.6, 1.4), pos(cf, 0, 7, 1.2), pos(cf, 0, 5.2, -1.6)
	rod(m, "Pillar", bottomBack, topBack, 0.5, GOLD, M.Metal)
	rod(m, "Neck", topBack, topFront, 0.45, GOLD, M.Metal)
	rod(m, "Body", topFront, pos(cf, 0, 0.6, -1.4), 0.6, GOLD, M.Metal)
	for i = 1, 5 do
		local t = i / 6
		local top = topBack:Lerp(topFront, t)
		rod(m, "String", top, Vector3.new(top.X, cf.Position.Y + 0.6, top.Z), 0.05, WHITE)
	end
	return m
end

local function cloudBench(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "CloudBench")
	for i = 1, 4 do
		ball(m, "Cloud", rng:NextNumber(2.4, 3), at(cf, (i - 2.5) * 1.8, 1.4, 0), WHITE)
	end
	block(m, "BackRail", Vector3.new(6.6, 0.3, 0.3), at(cf, 0, 3.2, 1), GOLD, M.Metal)
	for _, x in { -3, 3 } do
		cyl(m, "RailPost", 1.6, 0.3, at(cf, x, 2.4, 1), GOLD, M.Metal)
	end
	return m
end

local function angelDonut(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "AngelDonut")
	cyl(m, "Pedestal", 3, 2.6, at(cf, 0, 1.5, 0), MARBLE, M.Marble)
	local d = at(cf, 0, 5.4, 0) * CFrame.Angles(math.rad(90), 0, 0)
	donut(m, d, 3.4, rgb(235, 190, 120), pick({ rgb(255, 245, 210), rgb(255, 200, 230), GOLD }, rng))
	for _, side in { -1, 1 } do
		blob(m, "Wing", Vector3.new(3.4, 2.2, 0.4), at(cf, side * 2.6, 5.9, 0.3) * CFrame.Angles(0, 0, side * math.rad(-20)), WHITE)
	end
	for i = 0, 7 do
		local angle = i / 8 * math.pi * 2
		ball(m, "Halo", 0.35, at(cf, math.cos(angle) * 1.2, 7.9, math.sin(angle) * 1.2), GOLD, M.Neon)
	end
	return m
end

local function goldLantern(parent: Instance, cf: CFrame, _rng: Random): Model
	local m = model(parent, "GoldLantern")
	cyl(m, "Post", 6, 0.4, at(cf, 0, 3, 0), GOLD, M.Metal)
	block(m, "Lantern", Vector3.new(1.2, 1.6, 1.2), at(cf, 0, 6.8, 0), rgb(255, 235, 170), M.Neon, 0.1)
	block(m, "LanternCap", Vector3.new(1.5, 0.3, 1.5), at(cf, 0, 7.75, 0), GOLD, M.Metal)
	return m
end

local function lightGarden(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "LightGarden")
	fountain(m, at(cf, 0, 0, 2), rng)
	for _, s in { { -8, 6 }, { 8, 6 }, { -8, -4 }, { 8, -4 } } do
		goldLantern(m, at(cf, s[1], 0, s[2]), rng)
	end
	angelDonut(m, at(cf, -5, 0, -6), rng)
	angelDonut(m, at(cf, 5, 0, -6), rng)
	return m
end

--------------------------------------------------------------------------------
-- Glitch Zone
--------------------------------------------------------------------------------
local GLITCH = { rgb(255, 0, 200), rgb(0, 255, 220), rgb(255, 255, 0), rgb(120, 255, 60) }

local function missingTexture(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "MissingTexture")
	local c = at(cf, 0, rng:NextNumber(1, 3), 0) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, math.pi), rng:NextNumber(-0.5, 0.5))
	for x = 0, 1 do
		for y = 0, 1 do
			for z = 0, 1 do
				block(m, "Checker", Vector3.new(2, 2, 2), c * CFrame.new(x * 2 - 1, y * 2 - 1, z * 2 - 1), if (x + y + z) % 2 == 0 then rgb(255, 0, 220) else BLACK)
			end
		end
	end
	return m
end

local function pixelCloud(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "PixelCloud")
	for _ = 1, 8 do
		local s = rng:NextNumber(0.6, 1.6)
		block(m, "Pixel", Vector3.new(s, s, s), at(cf, rng:NextNumber(-3, 3), rng:NextNumber(3, 11), rng:NextNumber(-3, 3)), pick(GLITCH, rng), M.Neon)
	end
	return m
end

local function errorSign(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "ErrorSign")
	cyl(m, "Post", 5, 0.3, at(cf, 0, 2.5, 0), rgb(120, 120, 130), M.Metal)
	local panel = at(cf, 0, 6, 0) * CFrame.Angles(0, 0, rng:NextNumber(-0.25, 0.25))
	block(m, "Panel", Vector3.new(4, 3, 0.3), panel, rgb(220, 30, 40))
	for _, angle in { 45, -45 } do
		block(m, "X", Vector3.new(0.4, 2.4, 0.1), panel * CFrame.new(0, 0, -0.2) * CFrame.Angles(0, 0, math.rad(angle)), WHITE, M.Neon)
	end
	return m
end

local function wireframe(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "Wireframe")
	local s = rng:NextNumber(4, 6)
	local c = at(cf, 0, s / 2 + rng:NextNumber(0.5, 3), 0) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, math.pi), rng:NextNumber(0, 1))
	local color = pick(GLITCH, rng)
	local h = s / 2
	for _, a in { -h, h } do
		for _, b in { -h, h } do
			block(m, "Edge", Vector3.new(s, 0.15, 0.15), c * CFrame.new(0, a, b), color, M.Neon)
			block(m, "Edge", Vector3.new(0.15, s, 0.15), c * CFrame.new(a, 0, b), color, M.Neon)
			block(m, "Edge", Vector3.new(0.15, 0.15, s), c * CFrame.new(a, b, 0), color, M.Neon)
		end
	end
	return m
end

local function glitchTree(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "GlitchTree")
	block(m, "Trunk", Vector3.new(1.2, 6, 1.2), at(cf, 0, 3, 0), rgb(120, 80, 50))
	for i = 1, 3 do
		block(m, "Leaves", Vector3.new(4, 3, 4) * rng:NextNumber(0.7, 1.1), at(cf, rng:NextNumber(-1.5, 1.5), 6 + i * 1.6, rng:NextNumber(-1.5, 1.5)), if i == 2 then pick(GLITCH, rng) else rgb(70, 190, 80), if i == 2 then M.Neon else M.Grass)
	end
	block(m, "Leaves", Vector3.new(2, 2, 2), at(cf, rng:NextNumber(-4, 4), 13, rng:NextNumber(-4, 4)), rgb(70, 190, 80), M.Grass)
	return m
end

local function sunkBlocks(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "SunkBlocks")
	for _ = 1, 3 do
		local s = rng:NextNumber(2, 4)
		block(m, "Block", Vector3.new(s, s, s), at(cf, rng:NextNumber(-3, 3), s * 0.25, rng:NextNumber(-3, 3)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 1), rng:NextNumber(0, 1)), pick(GLITCH, rng), M.Neon)
	end
	return m
end

local function corruptedHouse(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "CorruptedHouse")
	block(m, "Walls", Vector3.new(8, 6, 7), at(cf, 0, 3, 2), rgb(230, 230, 235))
	roof(m, at(cf, 1.2, 7.6, 2.6) * CFrame.Angles(0, 0, math.rad(8)), 9, 8, 3, rgb(255, 0, 200), M.Neon)
	block(m, "Door", Vector3.new(1.8, 3, 0.2), at(cf, -1, 1.5, -1.55), BLACK)
	for i = 1, 3 do
		block(m, "Window", Vector3.new(1.4, 1.4, 0.2), at(cf, 2 + i * 0.6, 3.5 + i * 1.6, -1.6 - i * 0.8), pick(GLITCH, rng), M.Neon)
	end
	missingTexture(m, at(cf, -7, 0, -2), rng)
	pixelCloud(m, at(cf, 0, 4, 2), rng)
	errorSign(m, at(cf, 7, 0, -3), rng)
	return m
end

--------------------------------------------------------------------------------
-- The Black Hole
--------------------------------------------------------------------------------
local SPACE_ROCK = rgb(70, 60, 90)

local function asteroids(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "Asteroids")
	for i = 1, 4 do
		local s = rng:NextNumber(1.5, 4)
		block(m, "Asteroid", Vector3.new(s, s * rng:NextNumber(0.7, 1), s * rng:NextNumber(0.7, 1.2)), at(cf, rng:NextNumber(-4, 4), if i == 1 then s * 0.35 else rng:NextNumber(3, 13), rng:NextNumber(-4, 4)) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3)), SPACE_ROCK, M.Slate)
	end
	return m
end

local function satellite(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "Satellite")
	local c = at(cf, 0, 1.6, 0) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, math.pi), rng:NextNumber(0.2, 0.5))
	block(m, "Body", Vector3.new(2.4, 2.4, 3), c, rgb(220, 180, 70), M.Foil)
	for _, side in { -1, 1 } do
		block(m, "Panel", Vector3.new(5, 0.15, 2.4), c * CFrame.new(side * 3.8, 0, 0), rgb(40, 70, 160), M.Glass)
		block(m, "PanelArm", Vector3.new(1.4, 0.2, 0.2), c * CFrame.new(side * 1.2, 0, 0), rgb(150, 150, 160), M.Metal)
	end
	log(m, "Dish", 0.3, 2.4, c * CFrame.new(0, 0, -1.8) * CFrame.Angles(0, math.pi / 2, 0), WHITE, M.Metal)
	rod(m, "Antenna", (c * CFrame.new(0, 1.2, 0)).Position, (c * CFrame.new(0, 3, 0.4)).Position, 0.1, rgb(150, 150, 160), M.Metal)
	return m
end

local function astroFlag(parent: Instance, cf: CFrame, _rng: Random): Model
	local m = model(parent, "AstroFlag")
	block(m, "Rock", Vector3.new(2.4, 1, 2.2), at(cf, 0, 0.5, 0) * CFrame.Angles(0, 0.4, 0), SPACE_ROCK, M.Slate)
	cyl(m, "Pole", 7, 0.2, at(cf, 0, 4, 0), rgb(200, 200, 210), M.Metal)
	block(m, "Flag", Vector3.new(3.2, 2, 0.1), at(cf, 1.6, 6.4, 0), rgb(170, 90, 255), M.Neon)
	donut(m, at(cf, 1.6, 6.4, -0.1) * CFrame.Angles(math.rad(90), 0, 0), 1.2, WHITE, rgb(255, 200, 240))
	return m
end

local function starCrystals(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "StarCrystals")
	for _ = 1, 3 do
		local h = rng:NextNumber(2, 5)
		block(m, "Crystal", Vector3.new(h * 0.35, h, h * 0.35), at(cf, rng:NextNumber(-2, 2), h * 0.4, rng:NextNumber(-2, 2)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)), rgb(190, 120, 255), M.Neon)
	end
	return m
end

local function capsule(parent: Instance, cf: CFrame, _rng: Random): Model
	local m = model(parent, "Capsule")
	cyl(m, "Body", 5, 4, at(cf, 0, 4.2, 0), rgb(235, 235, 240), M.Metal)
	ball(m, "Nose", 4, at(cf, 0, 6.7, 0), rgb(235, 235, 240), M.Metal)
	log(m, "Window", 0.2, 1.6, at(cf, 0, 5, -2) * CFrame.Angles(0, math.pi / 2, 0), rgb(120, 200, 255), M.Neon)
	for i = 0, 2 do
		local angle = i / 3 * math.pi * 2
		rod(m, "Leg", pos(cf, math.cos(angle) * 1.6, 2.2, math.sin(angle) * 1.6), pos(cf, math.cos(angle) * 3, 0, math.sin(angle) * 3), 0.35, rgb(150, 150, 160), M.Metal)
	end
	cyl(m, "Stripe", 0.5, 4.05, at(cf, 0, 2.2, 0), rgb(170, 90, 255), M.Neon)
	return m
end

local function moonRover(parent: Instance, cf: CFrame, _rng: Random): Model
	local m = model(parent, "MoonRover")
	block(m, "Chassis", Vector3.new(4, 1, 5.6), at(cf, 0, 1.7, 0), rgb(200, 200, 210), M.Metal)
	for _, x in { -2.2, 2.2 } do
		for _, z in { -2, 2 } do
			log(m, "Wheel", 0.7, 1.8, at(cf, x, 0.9, z), rgb(60, 60, 70))
		end
	end
	rod(m, "Mast", pos(cf, 1, 2.2, -1.8), pos(cf, 1, 4.8, -1.8), 0.25, rgb(150, 150, 160), M.Metal)
	block(m, "Camera", Vector3.new(1, 0.7, 0.8), at(cf, 1, 5.1, -1.8), rgb(60, 60, 70), M.Metal)
	log(m, "Dish", 0.2, 2, at(cf, -1, 3, 1.4) * CFrame.Angles(0, 0, math.rad(60)), WHITE, M.Metal)
	return m
end

local function landingSite(parent: Instance, cf: CFrame, rng: Random): Model
	local m = model(parent, "LandingSite")
	capsule(m, at(cf, -5, 0, 3), rng)
	moonRover(m, at(cf, 5, 0, 2) * CFrame.Angles(0, math.rad(-30), 0), rng)
	astroFlag(m, at(cf, 0, 0, -5), rng)
	starCrystals(m, at(cf, -8, 0, -5), rng)
	return m
end

--------------------------------------------------------------------------------
-- Which props go where
--------------------------------------------------------------------------------
type Entry = { Build: Builder, Weight: number }
type Set = { Props: { Entry }, Feature: Builder }

local function e(build: Builder, weight: number): Entry
	return { Build = build, Weight = weight }
end

local Sets: { [string]: Set } = {
	Park = { Feature = playground, Props = { e(bench, 3), e(picnic, 2), e(swings, 1), e(duckPond, 1), e(flowerBed, 2), e(donutCart, 1), e(lampPost, 2) } },
	Lake = { Feature = pier, Props = { e(dock, 2), e(lighthouse, 1), e(cattails, 3), e(fishingSpot, 2), e(lilyPond, 2), e(bench, 1) } },
	Desert = { Feature = pyramidTrio, Props = { e(stepPyramid, 2), e(oasis, 1), e(tent, 2), e(pots, 2), e(camel, 2), e(tumbleweeds, 2) } },
	Jungle = { Feature = jungleCamp, Props = { e(stiltHut, 1), e(totem, 2), e(fern, 3), e(jellybeans, 2), e(parrot, 2), e(mushrooms, 2) } },
	Ice = { Feature = iglooVillage, Props = { e(igloo, 3), e(snowman, 2), e(penguins, 3), e(iceFishing, 2), e(sled, 2), e(snowPine, 3), e(snowFort, 2) } },
	Lava = { Feature = lavaBakery, Props = { e(cauldron, 2), e(obsidianRocks, 3), e(burntDonuts, 2), e(warningSign, 2), e(miniOven, 2), e(bakerRack, 1) } },
	Chocolate = { Feature = mineEntrance, Props = { e(mineCart, 2), e(supportBeam, 2), e(chocoBars, 2), e(stalagmites, 3), e(pickaxeBarrel, 2), e(chocoPuddle, 2) } },
	Candy = { Feature = candyVillage, Props = { e(gingerbreadHouse, 2), e(gumdrops, 3), e(peppermint, 2), e(wrappedCandies, 2), e(candyCorn, 2), e(iceCream, 2) } },
	Toys = { Feature = toyPile, Props = { e(blockStack, 3), e(toyCar, 2), e(rubberDuck, 2), e(teddyBear, 2), e(rockingHorse, 2), e(toySoldier, 2), e(beachBall, 2) } },
	Haunted = { Feature = ghostParty, Props = { e(pumpkinPatch, 3), e(graves, 2), e(ghost, 2), e(deadTree, 2), e(candles, 2), e(ironFence, 2) } },
	Clouds = { Feature = balloonFestival, Props = { e(cloudPuff, 3), e(hotAirBalloon, 2), e(kite, 2), e(cupcakeStall, 1), e(layerCake, 2) } },
	CyberStreets = { Feature = streetCorner, Props = { e(vendingMachine, 3), e(trafficCones, 2), e(foodCart, 2), e(scooter, 2), e(phoneBooth, 1), e(holoAd, 2) } },
	RobotFactory = { Feature = assemblyLine, Props = { e(crates, 3), e(barrels, 3), e(robotArm, 2), e(littleRobot, 2), e(gearPile, 2), e(forklift, 1) } },
	Clockwork = { Feature = clockPlaza, Props = { e(standingGear, 3), e(hourglass, 2), e(pocketWatch, 2), e(grandfatherClock, 2), e(springs, 2), e(gearPile, 2) } },
	Heaven = { Feature = lightGarden, Props = { e(columns, 3), e(fountain, 1), e(goldenHarp, 2), e(cloudBench, 2), e(angelDonut, 2), e(goldLantern, 3) } },
	Glitch = { Feature = corruptedHouse, Props = { e(missingTexture, 3), e(pixelCloud, 3), e(errorSign, 2), e(wireframe, 3), e(glitchTree, 2), e(sunkBlocks, 2) } },
	BlackHole = { Feature = landingSite, Props = { e(asteroids, 3), e(satellite, 2), e(astroFlag, 1), e(starCrystals, 3), e(capsule, 1), e(moonRover, 1) } },
}
DecorProps.Sets = Sets

local function choose(set: Set, rng: Random, last: Builder?): Builder
	local total = 0
	for _, entry in set.Props do
		total += entry.Weight
	end
	for _ = 1, 3 do
		local roll = rng:NextNumber() * total
		for _, entry in set.Props do
			roll -= entry.Weight
			if roll <= 0 then
				if entry.Build ~= last then
					return entry.Build
				end
				break
			end
		end
	end
	return set.Props[1].Build
end

local BAND_MIN = 50 -- |X| where the props start (the running path is |X| < 44)
local BAND_OUTER = 74 -- ...and end (the big edge decoration is further out)
local FEATURE_X = 66
local KEEP_OUT = Layout.BoxRadius + 30 -- studs around Domer's corner with nothing built
local ENTRANCE = 46 -- studs after a biome's entrance with nothing built (the arch)

-- Build `theme`'s props into `folder` for the biome `areaId` (zs..ze along the lane). Returns the
-- folder they went in (nil for a theme with no props).
function DecorProps.Build(theme: string, folder: Instance, areaId: number, zs: number, ze: number): Folder?
	local set = Sets[theme]
	if not set then
		return nil
	end
	local rng = Random.new(areaId * 7919 + 17)
	local props = Instance.new("Folder")
	props.Name = "Props"
	props.Parent = folder
	local home = Layout.GuardHome(areaId)
	local half = Layout.AreaHalfWidth(areaId)
	local outer = math.min(BAND_OUTER, half - 22)
	local function clear(position: Vector3, radius: number): boolean
		local flat = Vector2.new(position.X - home.X, position.Z - home.Z).Magnitude
		return flat > KEEP_OUT + radius and position.Z > zs + ENTRANCE and position.Z < ze - 20
	end
	local function facing(position: Vector3): CFrame
		return CFrame.lookAt(position, Vector3.new(0, 0, position.Z))
	end

	-- The set piece, twice: a third and two thirds of the way along, on opposite sides. A short
	-- biome gets it once, near the entrance: Domer's corner fills one side of it, so two would
	-- both land on the other side and leave no room for anything else.
	local length = ze - zs
	local short = length < 300
	local reserved: { { Z: number, Side: number } } = {}
	local side = if rng:NextNumber() < 0.5 then -1 else 1
	local spots: { number } = if short then { 0.3 } else { 0.32, 0.7 }
	for _, f in spots do
		local position = Vector3.new(side * FEATURE_X, 0, zs + length * f)
		if not clear(position, 16) then
			position = Vector3.new(-side * FEATURE_X, 0, position.Z) -- (Domer's side: try the other one)
		end
		if clear(position, 16) then
			set.Feature(props, facing(position), rng)
			table.insert(reserved, { Z = position.Z, Side = math.sign(position.X) })
		end
		side = -side
	end

	-- Single props all the way along both sides (closer together in a short biome, where the
	-- entrance and Domer's corner take up most of the room)
	local step = if short then 18 else math.max(38, length / 14)
	local z = zs + ENTRANCE + 8
	local last: Builder? = nil
	while z < ze - 24 do
		for _, s in { -1, 1 } do
			local position = Vector3.new(s * rng:NextNumber(BAND_MIN + 4, outer), 0, z + rng:NextNumber(-8, 8))
			local free = clear(position, 8)
			for _, r in reserved do
				if r.Side == s and math.abs(r.Z - position.Z) < 30 then
					free = false
				end
			end
			if free then
				local build = choose(set, rng, last)
				build(props, facing(position) * CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0), rng)
				last = build
			end
		end
		z += step * rng:NextNumber(0.85, 1.15)
	end
	return props
end

return DecorProps
