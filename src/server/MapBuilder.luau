--[[
	MapBuilder
	==========
	Builds the whole world from code: the safe lobby (bases, sell stall, leaderboards, spawn), the
	safe-zone line, and the lane of biomes, each with its Domer's corner and box spots.

	Want to edit the map by hand in Studio? "Bake" it:
		1. In Studio (edit mode, not playing) open View > Command Bar and run:
		   require(game.ServerScriptService.Server.MapBuilder).Build()
		2. A "Map" folder appears in Workspace. Move/replace/restyle anything you like and save.
		3. When the game runs and Workspace.Map already exists, it is used instead of rebuilding.
		Keep the names of: Plots/PlotN (+ Spawn, TreadmillAnchor, PodiumAnchor, SignAnchor,
		IncubatorAnchor, UpgradeSign), Lane/AreaN (+ GuardHome, BoxSpots/BoxSpot),
		Hub/SellStall/PromptPart and Hub/Leaderboards/Board_X/Screen.

	Biomes (Lane/AreaN) run one after another along +Z from the lobby. Each one has:
	  * thick grassy walls (Config.Map.WallThickness) and a checker floor,
	  * an arch at its entrance with its name and the Speed you need to escape its Domer (anyone
	    can walk in: there are no speed gates),
	  * its Domer's spot in a back corner (GuardHome; the first biomes have his couch there) and
	    the box spots around it (BoxSpots: BoxService puts the boxes on them),
	  * its theme's decorations (Decor.luau) and lots of little props (DecorProps.luau: igloos,
	    benches, mine carts...), cleared away from Domer's corner.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Areas = require(Shared.Areas)
local Layout = require(Shared.Layout)
local Format = require(Shared.Format)
local Donuts = require(Shared.Donuts)
local DonutModel = require(Shared.DonutModel)

local Build = require(script.Parent.Build)
local Decor = require(script.Parent.Decor)
local DecorProps = require(script.Parent.DecorProps)

local MapBuilder = {}

local rgb = Color3.fromRGB
local map = Config.Map
local HUB_GREEN = { rgb(120, 210, 56), rgb(106, 196, 48) }
local WALL_BROWN = { rgb(206, 136, 78), rgb(192, 124, 68) }

local mapFolder: Folder? = nil
local MAP_VERSION = 14

-- Every face of a part covered in studs (the classic Roblox brick look).
local function studs(part: BasePart): BasePart
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Inlet
	part.FrontSurface = Enum.SurfaceType.Studs
	part.BackSurface = Enum.SurfaceType.Studs
	part.LeftSurface = Enum.SurfaceType.Studs
	part.RightSurface = Enum.SurfaceType.Studs
	return part
end

--------------------------------------------------------------------------------
-- Lobby
--------------------------------------------------------------------------------
local function buildEntranceGate(parent: Instance)
	local gate = Instance.new("Model")
	gate.Name = "EntranceGate"
	local half = map.LaneHalfWidth
	for _, side in { -1, 1 } do
		Build.Part({ Parent = gate, Name = "GatePillar", Size = Vector3.new(8, 44, 8), Position = Vector3.new(side * (half + 7), 22, map.SafeZoneZ + 2), Color = rgb(215, 120, 170), Material = Enum.Material.Plastic })
	end
	local beam = Build.Part({
		Parent = gate, Name = "GateBeam",
		Size = Vector3.new(half * 2 + 22, 8, 8),
		CFrame = CFrame.lookAt(Vector3.new(0, 48, map.SafeZoneZ + 2), Vector3.new(0, 48, map.SafeZoneZ - 10)),
		Color = rgb(200, 95, 155), Material = Enum.Material.Plastic,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 12
	gui.LightInfluence = 0
	gui.Parent = beam
	Build.Text(gui, "🍩 " .. string.upper(Config.GameName) .. " 🍩", { TextColor3 = rgb(255, 240, 80), TextStrokeColor3 = rgb(120, 30, 80) })
	Decor.GiantDonut(gate, CFrame.new(0, 64, map.SafeZoneZ + 2), 8, 7, rgb(222, 165, 95), rgb(255, 150, 200), { rgb(255, 60, 60), rgb(255, 230, 60), rgb(60, 200, 255), rgb(255, 255, 255) })
	gate.Parent = parent
end

local function buildSafeZoneLine(parent: Instance)
	local half = map.LaneHalfWidth
	Build.Part({ Parent = parent, Name = "SafeZoneLine", Size = Vector3.new(half * 2, 0.2, 1.5), Position = Vector3.new(0, 0.1, map.SafeZoneZ - 0.75), Color = rgb(255, 50, 50), Material = Enum.Material.Neon, CanCollide = false })
	local label = Build.Part({ Parent = parent, Name = "SafeZoneLabel", Size = Vector3.new(44, 0.1, 8), Position = Vector3.new(0, 0.06, map.SafeZoneZ - 6), Transparency = 1, CanCollide = false })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 10
	gui.LightInfluence = 0
	gui.Parent = label
	-- Two copies (one upside down) so it reads correctly from either side.
	local top = Build.Text(gui, "🛡 SAFE ZONE 🛡", { Size = UDim2.fromScale(1, 0.5), TextColor3 = rgb(90, 200, 255), TextTransparency = 0.1 })
	top.TextStrokeColor3 = rgb(20, 40, 90)
	local bottom = Build.Text(gui, "🛡 SAFE ZONE 🛡", { Size = UDim2.fromScale(1, 0.5), Position = UDim2.fromScale(0, 0.5), Rotation = 180, TextColor3 = rgb(90, 200, 255), TextTransparency = 0.1 })
	bottom.TextStrokeColor3 = rgb(20, 40, 90)
end

-- The sell stall: a market stall in the plaza where you sell donuts you don't want any more.
local function buildSellStall(parent: Instance)
	local stall = Instance.new("Model")
	stall.Name = "SellStall"
	local origin = Layout.SellStallCFrame()
	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end
	local green = rgb(60, 200, 90)
	-- Counter + posts
	local counter = Build.Part({ Parent = stall, Name = "Counter", Size = Vector3.new(20, 4, 5), CFrame = at(0, 2, -2), Color = rgb(150, 95, 55), Material = Enum.Material.WoodPlanks })
	for _, x in { -9.5, 9.5 } do
		for _, z in { -4, 3 } do
			Build.Part({ Parent = stall, Name = "Post", Size = Vector3.new(0.8, 12, 0.8), CFrame = at(x, 6, z), Color = rgb(120, 75, 40), Material = Enum.Material.Wood })
		end
	end
	-- Striped awning
	for i = 0, 9 do
		Build.Part({ Parent = stall, Name = "Awning", Size = Vector3.new(2.2, 0.5, 10), CFrame = at(-9.9 + i * 2.2, 12.3, -0.5) * CFrame.Angles(math.rad(-12), 0, 0), Color = if i % 2 == 0 then green else rgb(255, 255, 255), Material = Enum.Material.SmoothPlastic })
	end
	-- Coins piled on the counter
	for n = 1, 9 do
		Build.Decor({ Parent = stall, Name = "Coin", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, 1.6, 1.6), CFrame = at(-6 + (n % 3) * 1.4, 4.2 + (n // 3) * 0.36, -2 + (n % 2) * 0.5) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(255, 205, 50), Material = Enum.Material.Foil })
	end
	-- Glowing circle to stand in
	Build.Part({ Parent = stall, Name = "Glow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 14, 14), CFrame = at(0, 0.08, -9) * CFrame.Angles(0, 0, math.pi / 2), Color = green, Material = Enum.Material.Neon, Transparency = 0.45, CanCollide = false })
	local prompt = Build.Part({ Parent = stall, Name = "PromptPart", Size = Vector3.new(4, 4, 1), CFrame = at(0, 3, -5), Transparency = 1, CanCollide = false })
	prompt:SetAttribute("SellStall", true)
	local sign = Instance.new("BillboardGui")
	sign.Name = "Sign"
	sign.Size = UDim2.fromScale(24, 6)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 11, 0)
	sign.LightInfluence = 0
	sign.MaxDistance = 260
	sign.Parent = counter
	Build.Text(sign, "💰 SELL DONUTS", { TextColor3 = rgb(120, 255, 140), TextStrokeColor3 = rgb(10, 50, 20) })
	-- A donut shopkeeper on the counter
	local keeper = DonutModel.Build(Donuts.List[2], { Scale = 0.9, NoEffects = true })
	DonutModel.PlaceOn(keeper, at(4, 4, -2) * CFrame.Angles(0, math.pi, 0))
	keeper.Parent = stall
	stall.PrimaryPart = counter
	stall.Parent = parent
end

local function buildLeaderboards(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Leaderboards"
	folder.Parent = parent
	local count = #Config.Leaderboards.Boards
	for index, board in Config.Leaderboards.Boards do
		local x = (index - (count + 1) / 2) * 33
		local z = Layout.LeaderboardZ()
		local model = Instance.new("Model")
		model.Name = "Board_" .. board.Id
		local frame = Build.Part({ Parent = model, Name = "Frame", Size = Vector3.new(31, 40, 1.5), Position = Vector3.new(x, 21, z - 0.6), Color = board.Color, Material = Enum.Material.SmoothPlastic })
		for _, side in { -1, 1 } do
			Build.Part({ Parent = model, Name = "Leg", Size = Vector3.new(2, 2, 2), Position = Vector3.new(x + side * 12, 1, z - 0.6), Color = board.Color:Lerp(Color3.new(0, 0, 0), 0.4), Material = Enum.Material.SmoothPlastic })
		end
		Build.Part({ Parent = model, Name = "Trim", Size = Vector3.new(32, 1, 2), Position = Vector3.new(x, 41.5, z - 0.6), Color = rgb(255, 255, 255), Material = Enum.Material.Neon })
		local screen = Build.Part({
			Parent = model, Name = "Screen",
			Size = Vector3.new(28, 37, 0.3),
			CFrame = CFrame.lookAt(Vector3.new(x, 21, z + 0.3), Vector3.new(x, 21, z + 10)),
			Color = rgb(20, 20, 30), Material = Enum.Material.SmoothPlastic,
		})
		screen:SetAttribute("BoardId", board.Id)
		model.PrimaryPart = frame
		model.Parent = folder
	end
end

-- The hub's floor and outer walls (sized by Config.Map.HubHalfWidth / HubDepth).
local function buildHubGround(hub: Instance)
	local hw, depth, z0 = map.HubHalfWidth, map.HubDepth, map.SafeZoneZ
	Build.CheckerFloor(hub, -hw, hw, z0 - depth, z0, map.TileSize, HUB_GREEN, Enum.Material.Plastic)

	local h, t = map.HubWallHeight, 4
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = hub
	Build.CheckerWall(walls, Vector3.new(-hw - t / 2, 0, z0 - depth - t), Vector3.new(0, 0, 1), depth + t, h, t, WALL_BROWN, Enum.Material.Plastic, 20)
	Build.CheckerWall(walls, Vector3.new(hw + t / 2, 0, z0 - depth - t), Vector3.new(0, 0, 1), depth + t, h, t, WALL_BROWN, Enum.Material.Plastic, 20)
	Build.CheckerWall(walls, Vector3.new(-hw - t, 0, z0 - depth - t / 2), Vector3.new(1, 0, 0), hw * 2 + t * 2, h, t, WALL_BROWN, Enum.Material.Plastic, 20)
	local laneOuter = map.LaneHalfWidth + t
	Build.CheckerWall(walls, Vector3.new(-hw - t, 0, z0 + t / 2), Vector3.new(1, 0, 0), hw + t - laneOuter, h, t, WALL_BROWN, Enum.Material.Plastic, 20)
	Build.CheckerWall(walls, Vector3.new(laneOuter, 0, z0 + t / 2), Vector3.new(1, 0, 0), hw + t - laneOuter, h, t, WALL_BROWN, Enum.Material.Plastic, 20)
	-- Grass strip along the top of the hub walls
	for _, info in {
		{ Vector3.new(-hw - t / 2, h + 1, z0 - depth / 2 - t / 2), Vector3.new(t + 1, 2, depth + t) },
		{ Vector3.new(hw + t / 2, h + 1, z0 - depth / 2 - t / 2), Vector3.new(t + 1, 2, depth + t) },
		{ Vector3.new(0, h + 1, z0 - depth - t / 2), Vector3.new(hw * 2 + t * 2, 2, t + 1) },
	} do
		Build.Part({ Parent = walls, Name = "WallTop", Position = info[1], Size = info[2], Color = rgb(100, 200, 60), Material = Enum.Material.Grass })
	end
end

-- Rocky hills along the tops of the hub's outer walls, in the lobby's own green and brown, so
-- you look at grassy rocks instead of the empty sky past the walls. Two rows of chunky, tilted
-- boulders with grass on top, the outer row taller; seeded, so every server builds the same ridge.
local function buildRidge(hub: Instance)
	local hw, depth, z0, h, t = map.HubHalfWidth, map.HubDepth, map.SafeZoneZ, map.HubWallHeight, 4
	local ridge = Instance.new("Model")
	ridge.Name = "Ridge"
	local rng = Random.new(2024)
	local rockColors = { WALL_BROWN[1], WALL_BROWN[2], rgb(178, 112, 62), rgb(214, 148, 92) }
	local function boulder(at: Vector3, size: Vector3)
		local tilt = CFrame.Angles(rng:NextNumber(-0.18, 0.18), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.18, 0.18))
		local cf = CFrame.new(at) * tilt
		Build.Part({ Parent = ridge, Name = "Rock", Size = size, CFrame = cf, Color = rockColors[rng:NextInteger(1, #rockColors)], Material = Enum.Material.Slate })
		-- grass on top (a slab sitting on the rock's top face, a little smaller)
		local grass = Vector3.new(size.X * 0.92, 1.6, size.Z * 0.92)
		Build.Part({ Parent = ridge, Name = "Grass", Size = grass, CFrame = cf * CFrame.new(0, size.Y / 2 + 0.6, 0), Color = HUB_GREEN[rng:NextInteger(1, 2)], Material = Enum.Material.Plastic })
	end
	-- `from` -> `to` along the top of a wall; `outward` points away from the hub
	local function line(from: Vector3, to: Vector3, outward: Vector3)
		local length = (to - from).Magnitude
		local dir = (to - from).Unit
		local d = 0
		while d < length do
			local base = from + dir * d
			-- inner row: low, right on the wall top
			local inner = Vector3.new(rng:NextNumber(14, 22), rng:NextNumber(12, 20), rng:NextNumber(14, 22))
			boulder(base + outward * rng:NextNumber(6, 10) + Vector3.new(0, h + inner.Y * 0.18, 0), inner)
			-- outer row: tall peaks
			local outer = Vector3.new(rng:NextNumber(18, 30), rng:NextNumber(26, 46), rng:NextNumber(18, 30))
			boulder(base + dir * rng:NextNumber(-4, 4) + outward * rng:NextNumber(20, 30) + Vector3.new(0, h + outer.Y * 0.2, 0), outer)
			d += rng:NextNumber(13, 19)
		end
	end
	local laneOuter = map.LaneHalfWidth + t
	line(Vector3.new(-hw - t, 0, z0 - depth - t), Vector3.new(-hw - t, 0, z0 + t), Vector3.new(-1, 0, 0)) -- left
	line(Vector3.new(hw + t, 0, z0 - depth - t), Vector3.new(hw + t, 0, z0 + t), Vector3.new(1, 0, 0)) -- right
	line(Vector3.new(-hw - t, 0, z0 - depth - t), Vector3.new(hw + t, 0, z0 - depth - t), Vector3.new(0, 0, -1)) -- back
	-- the front walls either side of the lane (the rocks lean back over the lane's own walls' side)
	line(Vector3.new(-hw - t, 0, z0 + t), Vector3.new(-laneOuter - 30, 0, z0 + t), Vector3.new(0, 0, 1))
	line(Vector3.new(laneOuter + 30, 0, z0 + t), Vector3.new(hw + t, 0, z0 + t), Vector3.new(0, 0, 1))
	ridge.Parent = hub
end

local function buildHub(parent: Folder)
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = parent
	local z0 = map.SafeZoneZ
	buildHubGround(hub)
	buildRidge(hub)

	buildSafeZoneLine(hub)
	buildEntranceGate(hub)
	buildSellStall(hub)
	buildLeaderboards(hub)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.lookAt(Vector3.new(0, 0.5, z0 - 170), Vector3.new(0, 0.5, z0))
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = rgb(120, 200, 255)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = hub
end

--------------------------------------------------------------------------------
-- Lane / biomes
--------------------------------------------------------------------------------
-- Third line of a biome's arch sign. Rewritten on every start (refreshAreaSigns), so a saved map
-- never shows old speeds after a rebalance.
local function speedText(area: Areas.Area): string
	if area.RecommendedSpeed <= 0 then
		return "🌱 No speed needed - start here!"
	end
	return "⚡ " .. Format.Number(area.RecommendedSpeed) .. " Speed to escape " .. Config.Guard.Name
end

local function buildArch(parent: Instance, area: Areas.Area, zs: number)
	local half = Layout.AreaHalfWidth(area.Id)
	local arch = Instance.new("Model")
	arch.Name = "Arch"
	for _, side in { -1, 1 } do
		Build.Part({ Parent = arch, Name = "ArchPillar", Size = Vector3.new(8, 38, 8), Position = Vector3.new(side * (half - 4), 19, zs + 4), Color = area.Wall[1]:Lerp(Color3.new(0, 0, 0), 0.25), Material = area.WallMaterial })
		Build.Part({ Parent = arch, Name = "ArchCap", Size = Vector3.new(9, 1.5, 9), Position = Vector3.new(side * (half - 4), 38.75, zs + 4), Color = area.Trim, Material = area.TrimMaterial })
	end
	local beam = Build.Part({
		Parent = arch, Name = "ArchSign",
		Size = Vector3.new(half * 2 - 6, 12, 4),
		CFrame = CFrame.lookAt(Vector3.new(0, 45, zs + 4), Vector3.new(0, 45, zs - 10)),
		Color = area.Wall[1]:Lerp(Color3.new(0, 0, 0), 0.4), Material = area.WallMaterial,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 12
	gui.LightInfluence = 0
	gui.Parent = beam
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = gui
	Build.Text(gui, "BIOME " .. area.Id, { Size = UDim2.fromScale(1, 0.22), TextColor3 = rgb(255, 255, 255), LayoutOrder = 1 })
	Build.Text(gui, string.upper(area.Name), { Size = UDim2.fromScale(1, 0.46), TextColor3 = area.Trim:Lerp(Color3.new(1, 1, 1), 0.35), LayoutOrder = 2 })
	Build.Text(gui, speedText(area), { Name = "SpeedInfo", Size = UDim2.fromScale(1, 0.26), TextColor3 = rgb(255, 230, 90), Font = Enum.Font.FredokaOne, LayoutOrder = 3 })
	arch.Parent = parent
end

local function refreshAreaSigns(folder: Instance)
	local lane = folder:FindFirstChild("Lane")
	for _, area in Areas.List do
		local biome = lane and lane:FindFirstChild("Area" .. area.Id)
		local arch = biome and biome:FindFirstChild("Arch")
		local sign = arch and arch:FindFirstChild("ArchSign")
		local gui = sign and sign:FindFirstChildOfClass("SurfaceGui")
		local label = gui and gui:FindFirstChild("SpeedInfo")
		if label and label:IsA("TextLabel") then
			label.Text = speedText(area)
		end
		-- (old saved maps: the speed gates are gone)
		local gate = biome and biome:FindFirstChild("SpeedGate")
		if gate then
			gate:Destroy()
		end
	end
end

-- Domer's couch (the first biomes): a big, comfy, orange-brown three-seater made of studded bricks,
-- with buttons on the back, round arms, a pillow at one end and a blanket thrown over the other.
-- `cf`: the couch's middle on the floor, its front (LookVector) facing the lane.
local COUCH = rgb(204, 112, 48)
local COUCH_LIGHT = rgb(220, 128, 60)
local COUCH_DARK = rgb(150, 78, 34)
local function buildCouch(parent: Instance, cf: CFrame): Model
	local couch = Instance.new("Model")
	couch.Name = "Couch"
	-- (deep, with a low back: Domer is huge, and the arm on the back's side drapes over the top of
	-- it - see GuardModel.Sleep)
	local L, D = 30, 18 -- length (local X) and depth (local Z, front = -Z)
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	-- (Decor: Domer appears right on top of it when he wakes up, so nothing in it is solid)
	local function brick(name: string, size: Vector3, c: CFrame, color: Color3): BasePart
		return studs(Build.Decor({ Parent = couch, Name = name, Size = size, CFrame = c, Color = color, Material = Enum.Material.Plastic }))
	end
	-- stubby wooden legs
	for _, x in { -L / 2 + 2, L / 2 - 2 } do
		for _, z in { -D / 2 + 1.5, D / 2 - 1.5 } do
			Build.Decor({ Parent = couch, Name = "Leg", Size = Vector3.new(1.6, 1.2, 1.6), CFrame = at(x, 0.6, z), Color = rgb(110, 70, 40), Material = Enum.Material.Wood })
		end
	end
	-- frame, seat cushions, back and arms
	brick("Frame", Vector3.new(L - 2, 3, D - 1), at(0, 2.7, 0.5), COUCH_DARK)
	local seatW = (L - 7) / 3
	for i = -1, 1 do
		brick("Cushion", Vector3.new(seatW - 0.3, 2.4, D - 4), at(i * seatW, 5.4, -1), COUCH_LIGHT)
	end
	brick("Back", Vector3.new(L - 6, 4.5, 2.5), at(0, 6.25, D / 2 - 1.25), COUCH)
	Build.Decor({ Parent = couch, Name = "BackTop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(L - 6, 3.6, 3.6), CFrame = at(0, 8.5, D / 2 - 1.25), Color = COUCH, Material = Enum.Material.Plastic })
	for _, side in { -1, 1 } do
		brick("Arm", Vector3.new(3.4, 5.5, D), at(side * (L / 2 - 1.7), 5.6, 0), COUCH)
		Build.Decor({ Parent = couch, Name = "ArmTop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(D, 4, 4), CFrame = at(side * (L / 2 - 1.7), 8.4, 0) * CFrame.Angles(0, math.pi / 2, 0), Color = COUCH, Material = Enum.Material.Plastic })
	end
	-- three buttons in the back
	for i = -1, 1 do
		Build.Decor({ Parent = couch, Name = "Button", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, CFrame = at(i * seatW, 7.4, D / 2 - 2.55), Color = COUCH_DARK, Material = Enum.Material.SmoothPlastic })
	end
	-- pillow on one arm, blanket thrown over the other
	studs(Build.Decor({ Parent = couch, Name = "Pillow", Size = Vector3.new(3, 2.2, 6), CFrame = at(L / 2 - 4.6, 7.8, 0) * CFrame.Angles(0, 0, math.rad(-18)), Color = rgb(225, 225, 230), Material = Enum.Material.Fabric }))
	for n = 0, 2 do
		Build.Decor({ Parent = couch, Name = "Blanket", Size = Vector3.new(5, 0.4, 9), CFrame = at(-L / 2 + 1.2, 7.4 - n * 2.3, -0.5) * CFrame.Angles(0, 0, math.rad(-35 - n * 25)), Color = rgb(160, 170, 175), Material = Enum.Material.Fabric })
	end
	couch.PrimaryPart = couch:FindFirstChild("Frame") :: BasePart
	couch.Parent = parent
	return couch
end

-- Domer's spot in the back corner. The GuardHome marker faces where he looks (towards the lobby,
-- turned a little to the middle of the lane); on a couch biome it's the couch's frame instead.
local function buildGuardSpot(parent: Instance, area: Areas.Area)
	local home = Layout.GuardHome(area.Id)
	local side = Layout.GuardSide(area.Id)
	local spot = Instance.new("Model")
	spot.Name = "GuardSpot"
	local marker
	if area.Couch then
		-- the couch stands along the side wall, its front facing the middle of the lane
		local couchCf = CFrame.lookAt(home, home + Vector3.new(-side, 0, 0))
		buildCouch(spot, couchCf)
		marker = Build.Part({ Parent = spot, Name = "GuardHome", Size = Vector3.new(2, 1, 2), CFrame = couchCf + Vector3.new(0, 0.5, 0), Transparency = 1, CanCollide = false, CanQuery = false })
		marker:SetAttribute("Couch", true)
	else
		local facing = CFrame.Angles(0, side * math.rad(40), 0):VectorToWorldSpace(Vector3.new(0, 0, -1))
		marker = Build.Part({ Parent = spot, Name = "GuardHome", Size = Vector3.new(2, 1, 2), CFrame = CFrame.lookAt(home + Vector3.new(0, 0.5, 0), home + Vector3.new(0, 0.5, 0) + facing), Transparency = 1, CanCollide = false, CanQuery = false })
		-- a patch of trampled ground under him
		Build.Decor({ Parent = spot, Name = "Patch", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 26, 26), CFrame = CFrame.new(home + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = area.Floor[1]:Lerp(Color3.new(0, 0, 0), 0.18), Material = area.FloorMaterial })
	end
	marker:SetAttribute("Area", area.Id)
	spot.Parent = parent
end

-- Where the boxes sit: a nest of twigs in the first biomes, a stand with a glowing rim later on.
local function buildBoxSpots(parent: Instance, area: Areas.Area)
	local folder = Instance.new("Folder")
	folder.Name = "BoxSpots"
	folder.Parent = parent
	for index, point in Layout.BoxSpots(area.Id) do
		if area.Id <= 6 then
			Build.Decor({ Parent = folder, Name = "Nest", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 9, 9), CFrame = CFrame.new(point + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(140, 92, 50), Material = Enum.Material.Wood })
			for n = 0, 7 do
				local angle = n / 8 * math.pi * 2
				Build.Decor({ Parent = folder, Name = "Twig", Size = Vector3.new(0.5, 0.5, 3.2), CFrame = CFrame.new(point + Vector3.new(math.cos(angle) * 4.2, 0.9, math.sin(angle) * 4.2)) * CFrame.Angles(0, -angle, math.rad(10)), Color = rgb(115, 74, 40), Material = Enum.Material.Wood })
			end
		else
			Build.Decor({ Parent = folder, Name = "Stand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 9, 9), CFrame = CFrame.new(point + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = area.Wall[1]:Lerp(Color3.new(0, 0, 0), 0.3), Material = Enum.Material.SmoothPlastic })
			Build.Decor({ Parent = folder, Name = "StandRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 9.8, 9.8), CFrame = CFrame.new(point + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = area.Trim, Material = Enum.Material.Neon })
		end
		local spot = Build.Part({ Parent = folder, Name = "BoxSpot", Size = Vector3.new(1, 0.2, 1), CFrame = CFrame.new(point + Vector3.new(0, 1, 0)), Transparency = 1, CanCollide = false, CanQuery = false })
		spot:SetAttribute("Area", area.Id)
		spot:SetAttribute("Index", index)
	end
end

-- The themes (Decor.luau) were designed for a lane DECOR_DESIGN_HALF studs either side of the
-- middle. In a wider lane, everything near the walls moves out to the walls with them (each prop
-- as a whole); the props in the middle stay where they are.
local DECOR_DESIGN_HALF = 60
local function widenDecor(decor: Instance, half: number)
	local extra = half - DECOR_DESIGN_HALF
	if extra == 0 then
		return
	end
	for _, item in decor:GetChildren() do
		local parts: { BasePart } = {}
		if item:IsA("BasePart") then
			table.insert(parts, item)
		end
		for _, d in item:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			end
		end
		if #parts > 0 then
			local sum = 0
			for _, part in parts do
				sum += part.Position.X
			end
			local x = sum / #parts
			if math.abs(x) >= 36 then
				local shift = Vector3.new(math.sign(x) * extra, 0, 0)
				for _, part in parts do
					part.CFrame += shift
				end
			end
		end
	end
end

-- Decorations right next to Domer and his boxes are taken away, so nothing stands in the way of
-- a steal (or hides a box).
local function clearCorner(decor: Instance, areaId: number)
	local home = Layout.GuardHome(areaId)
	local radius = Layout.BoxRadius + 16
	for _, item in decor:GetChildren() do
		local parts: { BasePart } = {}
		if item:IsA("BasePart") then
			table.insert(parts, item)
		end
		for _, d in item:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			end
		end
		-- (DecorProps keeps away from his corner by itself)
		if #parts > 0 and item.Name ~= "Props" then
			local sum = Vector3.zero
			for _, part in parts do
				sum += part.Position
			end
			local center = sum / #parts
			local size = parts[1].Size
			-- (the big area-wide pieces, like weather emitters and floor grids, stay)
			if size.X < 60 and size.Z < 60 and Vector2.new(center.X - home.X, center.Z - home.Z).Magnitude < radius then
				item:Destroy()
			end
		end
	end
end

local function buildArea(parent: Instance, area: Areas.Area)
	local zs, ze = Layout.AreaStart(area.Id), Layout.AreaEnd(area.Id)
	local half = Layout.AreaHalfWidth(area.Id)
	local folder = Instance.new("Folder")
	folder.Name = "Area" .. area.Id
	folder:SetAttribute("AreaId", area.Id)
	folder.Parent = parent

	Build.CheckerFloor(folder, -half, half, zs, ze, map.TileSize, area.Floor, area.FloorMaterial)

	-- Thick walls with grass (or the biome's trim) on top, so there's no void beside the lane
	local t, h = map.WallThickness, map.LaneWallHeight
	local before = Areas.List[area.Id - 1]
	local beforeHalf = if before then Layout.AreaHalfWidth(before.Id) else half
	if half ~= beforeHalf then
		-- a different width from the biome before: close the step between the two
		local inner, outer = math.min(half, beforeHalf), math.max(half, beforeHalf)
		for _, side in { -1, 1 } do
			local from = if side < 0 then -(outer + t) else inner
			Build.CheckerWall(folder, Vector3.new(from, 0, zs + 2), Vector3.new(1, 0, 0), outer + t - inner, h, 4, area.Wall, area.WallMaterial, 20)
		end
	end
	for _, side in { -1, 1 } do
		Build.CheckerWall(folder, Vector3.new(side * (half + t / 2), 0, zs), Vector3.new(0, 0, 1), ze - zs, h, t, area.Wall, area.WallMaterial, 20)
		Build.Part({ Parent = folder, Name = "WallTop", Size = Vector3.new(t + 1, 2, ze - zs), Position = Vector3.new(side * (half + t / 2), h + 1, (zs + ze) / 2), Color = area.Trim, Material = area.TrimMaterial })
	end
	-- Coloured line marking the start of the biome
	Build.Part({ Parent = folder, Name = "AreaLine", Size = Vector3.new(half * 2, 0.2, 2), Position = Vector3.new(0, 0.1, zs + 1), Color = area.Trim, Material = if area.Id > 1 then Enum.Material.Neon else Enum.Material.SmoothPlastic, CanCollide = false })

	buildArch(folder, area, zs)
	buildGuardSpot(folder, area)
	buildBoxSpots(folder, area)

	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = folder
	Decor.BuildTheme(area.Theme, decor, zs, ze, Random.new(area.Id * 104729))
	if not area.HalfWidth then
		widenDecor(decor, half)
	end
	DecorProps.Build(area.Theme, decor, area.Id, zs, ze) -- (the little things: igloos, benches...)
	clearCorner(decor, area.Id)

	-- Close the lane after the last biome
	if area.Id == #Areas.List then
		Build.CheckerWall(folder, Vector3.new(-half - t, 0, ze + 2), Vector3.new(1, 0, 0), half * 2 + t * 2, h, 4, area.Wall, area.WallMaterial, 20)
	end
end

local function buildLane(parent: Folder)
	local lane: Instance? = parent:FindFirstChild("Lane")
	if not lane then
		local folder = Instance.new("Folder")
		folder.Name = "Lane"
		folder.Parent = parent
		lane = folder
	end
	for _, area in Areas.List do
		if not (lane :: Instance):FindFirstChild("Area" .. area.Id) then
			buildArea(lane :: Instance, area)
			task.wait() -- spread the work over a few frames
		end
	end
end

--------------------------------------------------------------------------------
-- Plots
--------------------------------------------------------------------------------
local SHOP_WALL = rgb(255, 205, 225)
local SHOP_TRIM = rgb(255, 255, 255)
local SHOP_ROOF = rgb(110, 62, 36)
local SHOP_ICING = rgb(255, 140, 190)

-- The donut shop at the back of a pen: a little pink bakery made of studded bricks, with a striped
-- awning over the counter window, a chocolate roof dripping with icing and a giant donut on top.
-- `zb`: (plot space) where its front wall is, facing the pen.
local function buildShop(pen: Model, cf: CFrame, zb: number)
	local shop = Instance.new("Model")
	shop.Name = "DonutShop"
	local W, D, H = 40, Layout.ShopDepth, 16
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	local function brick(name: string, size: Vector3, c: CFrame, color: Color3): BasePart
		return studs(Build.Part({ Parent = shop, Name = name, Size = size, CFrame = c, Color = color, Material = Enum.Material.Plastic }))
	end
	brick("ShopFloor", Vector3.new(W, 1, D), at(0, 0.5, zb + D / 2), SHOP_TRIM)
	brick("BackWall", Vector3.new(W, H, 1.5), at(0, H / 2 + 1, zb + D - 0.75), SHOP_WALL)
	for _, side in { -1, 1 } do
		brick("SideWall", Vector3.new(1.5, H, D), at(side * (W / 2 - 0.75), H / 2 + 1, zb + D / 2), SHOP_WALL)
		-- the front wall either side of the window
		brick("FrontWall", Vector3.new(W / 2 - 11, H, 1.5), at(side * (W / 4 + 5.5), H / 2 + 1, zb + 0.75), SHOP_WALL)
		brick("Corner", Vector3.new(2, H + 1, 2), at(side * (W / 2 - 1), (H + 1) / 2 + 1, zb + 0.5), SHOP_TRIM)
	end
	-- the window: counter below, a lintel with the shop's name above
	brick("Counter", Vector3.new(22, 4, 2.5), at(0, 3, zb + 1), SHOP_TRIM)
	local lintel = brick("Lintel", Vector3.new(22, 4.5, 1.5), at(0, H - 1.25, zb + 0.75), SHOP_WALL)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 14
	gui.LightInfluence = 0
	gui.Parent = lintel
	Build.Text(gui, "🍩 DONUT SHOP 🍩", { TextColor3 = rgb(255, 90, 160), TextStrokeColor3 = rgb(255, 255, 255), TextStrokeTransparency = 0 })
	-- striped awning over the window
	for i = 0, 9 do
		Build.Decor({ Parent = shop, Name = "Awning", Size = Vector3.new(2.3, 0.4, 6), CFrame = at(-10.35 + i * 2.3, H - 4.6, zb - 2.2) * CFrame.Angles(math.rad(18), 0, 0), Color = if i % 2 == 0 then SHOP_ICING else SHOP_TRIM, Material = Enum.Material.SmoothPlastic })
	end
	-- chocolate roof with icing dripping over the front edge
	brick("Roof", Vector3.new(W + 3, 1.6, D + 3), at(0, H + 1.8, zb + D / 2), SHOP_ROOF)
	brick("Icing", Vector3.new(W + 2, 0.8, D + 2), at(0, H + 3, zb + D / 2), SHOP_ICING)
	for i = 0, 8 do
		local drip = 1.2 + (i % 3) * 0.8
		Build.Decor({ Parent = shop, Name = "Drip", Size = Vector3.new(2.2, drip, 0.8), CFrame = at(-W / 2 + 2.5 + i * (W - 5) / 8, H + 2.6 - drip / 2, zb - 1.2), Color = SHOP_ICING, Material = Enum.Material.SmoothPlastic })
	end
	-- the giant donut on the roof
	Decor.GiantDonut(shop, at(0, H + 10, zb + D / 2), 5, 3.4, rgb(222, 165, 95), SHOP_ICING, { rgb(255, 60, 60), rgb(255, 230, 60), rgb(60, 200, 255), rgb(255, 255, 255) })
	shop.PrimaryPart = shop:FindFirstChild("ShopFloor") :: BasePart
	shop.Parent = pen
end

-- A base's pen (like Steal an Egg): a patch of checker ground - one tile per donut - inside a low
-- fence you can hop over, with a low gate in the middle of the front and the donut shop behind it.
-- Rebuilt (PlotService) whenever the base gets bigger; `slots` is how many donuts it holds.
function MapBuilder.BuildPen(plot: Model, slots: number)
	local old = plot:FindFirstChild("Pen")
	if old then
		old:Destroy()
	end
	local cf = Layout.PlotCFrame(plot:GetAttribute("PlotIndex") :: number)
	local fh = Layout.PlotFloorHeight
	local classic = Config.Skins[1]
	local columns, rows, width, depth = Layout.PenGrid(slots)
	local cellX, cellZ = width / columns, depth / rows
	local front = Layout.PenFront
	local pen = Instance.new("Model")
	pen.Name = "Pen"
	pen:SetAttribute("Slots", slots)
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	local function skinned(role: string, props): BasePart
		props.Parent = props.Parent or pen
		local part = Build.Part(props)
		part:SetAttribute("SkinRole", role)
		return part
	end
	-- Ground: one checker tile per donut patch, with a border round the edge
	local floor = Instance.new("Folder")
	floor.Name = "Floor"
	floor.Parent = pen
	for column = 0, columns - 1 do
		for row = 0, rows - 1 do
			local role = if (column + row) % 2 == 0 then "Floor" else "FloorAlt"
			local tile = skinned(role, {
				Parent = floor, Name = "Tile",
				Size = Vector3.new(cellX, fh + 0.5, cellZ),
				CFrame = at(-width / 2 + cellX * (column + 0.5), (fh - 0.5) / 2, front + cellZ * (row + 0.5)),
				Color = if role == "Floor" then classic.Floor else classic.FloorAlt,
				Material = classic.FloorMaterial,
			})
			tile.TopSurface = Enum.SurfaceType.Studs
		end
	end
	local border = 2
	for _, side in { -1, 1 } do
		skinned("Trim", { Parent = floor, Name = "Border", Size = Vector3.new(border, fh + 0.6, depth + border * 2), CFrame = at(side * (width / 2 + border / 2), (fh - 0.4) / 2, front + depth / 2), Color = classic.Trim, Material = classic.TrimMaterial })
		skinned("Trim", { Parent = floor, Name = "Border", Size = Vector3.new(width, fh + 0.6, border), CFrame = at(0, (fh - 0.4) / 2, if side < 0 then front - border / 2 else front + depth + border / 2), Color = classic.Trim, Material = classic.TrimMaterial })
	end

	-- Fence: posts and two rails all the way round, a gap for the gate at the front
	local fence = Instance.new("Folder")
	fence.Name = "Fence"
	fence.Parent = pen
	local height = Config.Plots.FenceHeight
	local gate = 7 -- half the gate's width
	local function fenceLine(from: Vector3, to: Vector3)
		local length = (to - from).Magnitude
		if length < 0.5 then
			return
		end
		local dir = (to - from).Unit
		local posts = math.max(1, math.floor(length / 6.5 + 0.5))
		for i = 0, posts do
			local p = from + dir * (length * i / posts)
			skinned("Fence", { Parent = fence, Name = "Post", Size = Vector3.new(1.1, height + 0.6, 1.1), CFrame = at(p.X, fh + (height + 0.6) / 2, p.Z), Color = classic.Fence, Material = classic.FenceMaterial })
		end
		local mid = (from + to) / 2
		local line = CFrame.lookAt(Vector3.new(mid.X, 0, mid.Z), Vector3.new(to.X, 0, to.Z))
		for _, y in { height * 0.4, height * 0.85 } do
			skinned("Fence", { Parent = fence, Name = "Rail", Size = Vector3.new(0.45, 0.6, length), CFrame = cf * line * CFrame.new(0, fh + y, 0), Color = classic.Fence, Material = classic.FenceMaterial })
		end
		skinned("Trim", { Parent = fence, Name = "RailCap", Size = Vector3.new(0.7, 0.3, length), CFrame = cf * line * CFrame.new(0, fh + height + 0.45, 0), Color = classic.Trim, Material = classic.TrimMaterial })
	end
	local hw, z0, z1 = width / 2 + border, front - border, front + depth + border
	fenceLine(Vector3.new(-hw, 0, z1), Vector3.new(hw, 0, z1)) -- back
	fenceLine(Vector3.new(-hw, 0, z0), Vector3.new(-hw, 0, z1)) -- left
	fenceLine(Vector3.new(hw, 0, z0), Vector3.new(hw, 0, z1)) -- right
	fenceLine(Vector3.new(-hw, 0, z0), Vector3.new(-gate, 0, z0)) -- front left
	fenceLine(Vector3.new(gate, 0, z0), Vector3.new(hw, 0, z0)) -- front right
	-- Corner posts with round caps, and two low gate posts
	for _, x in { -hw, hw } do
		for _, z in { z0, z1 } do
			skinned("Trim", { Parent = fence, Name = "CornerPost", Size = Vector3.new(1.8, height + 1.4, 1.8), CFrame = at(x, fh + (height + 1.4) / 2, z), Color = classic.Trim, Material = classic.TrimMaterial })
			skinned("Pedestal", { Parent = fence, Name = "CornerCap", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.2, CFrame = at(x, fh + height + 1.9, z), Color = classic.Pedestal, Material = classic.PedestalMaterial })
		end
	end
	for _, side in { -1, 1 } do
		skinned("Trim", { Parent = fence, Name = "GatePost", Size = Vector3.new(2, height + 2.5, 2), CFrame = at(side * gate, fh + (height + 2.5) / 2, z0), Color = classic.Trim, Material = classic.TrimMaterial })
		skinned("Pedestal", { Parent = fence, Name = "GateCap", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.6, CFrame = at(side * gate, fh + height + 3.2, z0), Color = classic.Pedestal, Material = classic.PedestalMaterial })
	end

	buildShop(pen, cf, z1 + 3)
	pen.Parent = plot
end

-- The big button under the upgrade sign's board: "UPGRADE" and the price. PlotService colours it
-- (green when the owner can afford the next size, red when not, grey at the biggest size) and makes
-- it clickable. Also called on maps saved before the sign had a button.
function MapBuilder.BuildUpgradeButton(sign: Model): BasePart?
	local existing = sign:FindFirstChild("UpgradeButton")
	if existing and existing:IsA("BasePart") then
		return existing
	end
	local board = sign:FindFirstChild("Board")
	if not board or not board:IsA("BasePart") then
		return nil
	end
	Build.Part({ Parent = sign, Name = "ButtonRim", Size = Vector3.new(6.4, 2.6, 0.5), CFrame = board.CFrame * CFrame.new(0, -3.6, 0), Color = rgb(70, 40, 20), Material = Enum.Material.WoodPlanks })
	local button = Build.Part({ Parent = sign, Name = "UpgradeButton", Size = Vector3.new(5.8, 2.1, 0.7), CFrame = board.CFrame * CFrame.new(0, -3.6, -0.4), Color = rgb(130, 130, 130), Material = Enum.Material.SmoothPlastic })
	button.TopSurface = Enum.SurfaceType.Studs
	local gui = Instance.new("SurfaceGui")
	gui.Name = "ButtonGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.Parent = button
	Build.Text(gui, "UPGRADE", { Name = "Label", Size = UDim2.fromScale(0.92, 0.58), Position = UDim2.fromScale(0.04, 0.04), TextColor3 = rgb(255, 255, 255), TextStrokeColor3 = rgb(30, 30, 30) })
	Build.Text(gui, "", { Name = "Price", Size = UDim2.fromScale(0.92, 0.36), Position = UDim2.fromScale(0.04, 0.6), TextColor3 = rgb(255, 255, 255), TextStrokeColor3 = rgb(30, 30, 30), Font = Enum.Font.FredokaOne })
	return button
end

-- The sign by the gate where you upgrade your base (PlotService writes the price on it).
local function buildUpgradeSign(plot: Model, cf: CFrame)
	local sign = Instance.new("Model")
	sign.Name = "UpgradeSign"
	local p = Layout.UpgradeSignPosition()
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(p.X + x, y, p.Z + z)
	end
	for _, x in { -3.6, 3.6 } do
		Build.Part({ Parent = sign, Name = "SignPost", Size = Vector3.new(0.8, 7, 0.8), CFrame = at(x, 3.5, 0), Color = rgb(120, 75, 40), Material = Enum.Material.Wood })
	end
	local board = Build.Part({ Parent = sign, Name = "Board", Size = Vector3.new(9, 4.6, 0.6), CFrame = at(0, 6.4, -0.2), Color = rgb(170, 110, 60), Material = Enum.Material.WoodPlanks })
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = board
	Build.Text(gui, "UPGRADE BASE", { Name = "Title", Size = UDim2.fromScale(1, 0.4), TextColor3 = rgb(255, 240, 120), TextStrokeColor3 = rgb(60, 30, 10) })
	Build.Text(gui, "", { Name = "Info", Size = UDim2.fromScale(1, 0.6), Position = UDim2.fromScale(0, 0.4), TextColor3 = rgb(255, 255, 255), TextStrokeColor3 = rgb(60, 30, 10), Font = Enum.Font.FredokaOne })
	local prompt = Build.Part({ Parent = sign, Name = "PromptPart", Size = Vector3.new(4, 4, 1), CFrame = at(0, 3, -1.5), Transparency = 1, CanCollide = false })
	prompt:SetAttribute("UpgradeSign", true)
	sign.PrimaryPart = board
	MapBuilder.BuildUpgradeButton(sign)
	sign.Parent = plot
end

local function buildPlot(parent: Instance, plotIndex: number)
	local cf = Layout.PlotCFrame(plotIndex)
	local fh = Layout.PlotFloorHeight

	local plot = Instance.new("Model")
	plot.Name = "Plot" .. plotIndex
	plot:SetAttribute("PlotIndex", plotIndex)
	plot:SetAttribute("WorldId", 1)

	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	-- Anchors used by other services: the treadmill and incubator beside the pen, the podium on
	-- the other side, the name sign above the shop (PlotService moves it as the pen grows).
	local side = Layout.PlotWidth / 2 - 13
	Build.Part({ Parent = plot, Name = "Spawn", Size = Vector3.new(4, 1, 4), CFrame = at(0, fh + 0.5, Layout.PenFront + 8), Transparency = 1, CanCollide = false, CanQuery = false })
	Build.Part({ Parent = plot, Name = "SignAnchor", Size = Vector3.new(1, 1, 1), CFrame = at(0, fh + 30, 30), Transparency = 1, CanCollide = false, CanQuery = false })
	Build.Part({ Parent = plot, Name = "TreadmillAnchor", Size = Vector3.new(1, 1, 1), CFrame = at(-side, 0, Layout.PenFront + 4) * CFrame.Angles(0, math.pi / 2, 0), Transparency = 1, CanCollide = false, CanQuery = false })
	Build.Part({ Parent = plot, Name = "IncubatorAnchor", Size = Vector3.new(1, 1, 1), CFrame = at(-side, 0, Layout.PenFront + 34), Transparency = 1, CanCollide = false, CanQuery = false })
	Build.Part({ Parent = plot, Name = "PodiumAnchor", Size = Vector3.new(1, 1, 1), CFrame = at(side, 0, Layout.PenFront + 10), Transparency = 1, CanCollide = false, CanQuery = false })

	local skinFx = Instance.new("Folder")
	skinFx.Name = "SkinFX"
	skinFx.Parent = plot

	plot.PrimaryPart = plot:FindFirstChild("Spawn") :: BasePart
	MapBuilder.BuildPen(plot, Config.Plots.Sizes[1].Slots)
	buildUpgradeSign(plot, cf)
	plot.Parent = parent
end

local function buildPlots(parent: Folder)
	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = parent
	for i = 1, Config.Plots.Count do
		buildPlot(plots, i)
	end
end

--------------------------------------------------------------------------------
-- Lighting (post effects the client tweens per area)
--------------------------------------------------------------------------------
local function setupLighting()
	local function ensure(className: string, name: string): Instance
		local existing = Lighting:FindFirstChild(name)
		if existing then
			return existing
		end
		local instance = Instance.new(className :: any)
		instance.Name = name
		instance.Parent = Lighting
		return instance
	end
	-- Bright, clean daylight like the reference: high sun, clear sky, no fog, vivid colours.
	Lighting.GlobalShadows = true
	Lighting.ClockTime = 13.5
	Lighting.Brightness = Config.Graphics.Brightness
	Lighting.ExposureCompensation = 0
	Lighting.ShadowSoftness = Config.Graphics.ShadowSoftness
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.OutdoorAmbient = rgb(190, 190, 200) -- bright shade, like the reference
	Lighting.Ambient = rgb(172, 172, 184)
	local atmosphere = ensure("Atmosphere", "Atmosphere") :: Atmosphere
	atmosphere.Density = 0.18
	atmosphere.Offset = 0.25
	atmosphere.Haze = 0
	atmosphere.Glare = 0
	atmosphere.Color = rgb(199, 220, 245)
	atmosphere.Decay = rgb(110, 121, 135)
	local tint = ensure("ColorCorrectionEffect", "AreaTint") :: ColorCorrectionEffect
	tint.Brightness = 0.02
	tint.Saturation = 0.12 + Config.Graphics.SaturationBoost
	tint.Contrast = 0.04 + Config.Graphics.ContrastBoost
	tint.TintColor = rgb(255, 255, 255)
	local bloom = ensure("BloomEffect", "Bloom") :: BloomEffect
	bloom.Intensity = 0.1 + Config.Graphics.BloomBoost
	bloom.Size = Config.Graphics.BloomSize
	bloom.Threshold = Config.Graphics.BloomThreshold
	if Config.Graphics.SunRays > 0 then
		local sunRays = ensure("SunRaysEffect", "SunRays") :: SunRaysEffect
		sunRays.Intensity = Config.Graphics.SunRays
		sunRays.Spread = 0.6
	else
		local old = Lighting:FindFirstChild("SunRays")
		if old then
			old:Destroy()
		end
	end
	-- Puffy 3D clouds (the client hides them at night and in foggy areas)
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain and Config.Graphics.Clouds.Cover > 0 then
		local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
		clouds.Cover = Config.Graphics.Clouds.Cover
		clouds.Density = Config.Graphics.Clouds.Density
		clouds.Color = rgb(255, 255, 255)
		clouds.Parent = terrain
	end
	-- Roblox's own sky, with lots of stars for the night-time areas (World 2 swaps in the galaxy
	-- skybox from Config.GalaxySky on the client)
	local sky = ensure("Sky", "Sky") :: Sky
	sky.StarCount = 5000
	sky.CelestialBodiesShown = true
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------
-- Beams and trails keep their attachments' names ("From" / "To"), since a baked map can't keep the
-- references: look on the part they're in, then anywhere in their model.
local function reconnectAttachments(effect: any)
	local function find(name: unknown): Attachment?
		if type(name) ~= "string" then
			return nil
		end
		local found = effect.Parent and effect.Parent:FindFirstChild(name)
		local model = effect:FindFirstAncestorOfClass("Model")
		if not found and model then
			found = model:FindFirstChild(name, true)
		end
		return if found and found:IsA("Attachment") then found else nil
	end
	if not effect.Attachment0 then
		effect.Attachment0 = find(effect:GetAttribute("From"))
	end
	if not effect.Attachment1 then
		effect.Attachment1 = find(effect:GetAttribute("To"))
	end
end

--------------------------------------------------------------------------------
-- Performance pass (runs once when the server starts): small, glowing and see-through parts
-- don't cast shadows (the shadow pass draws every caster again, ~half the map was casting), and
-- decorations can't be touched or hit by raycasts (less physics work). Decorations' particle
-- emitters are capped so one busy area can't flood the screen.
--------------------------------------------------------------------------------
local MAX_DECOR_PARTICLE_RATE = 30
local NO_SHADOW_MATERIALS = {
	[Enum.Material.Neon] = true,
	[Enum.Material.Glass] = true,
	[Enum.Material.ForceField] = true,
}
local function optimize(root: Instance)
	local decorFolders: { Instance } = {}
	for _, child in root:GetDescendants() do
		if (child.Name == "Decor" or child.Name == "Scenery") and (child:IsA("Folder") or child:IsA("Model")) then
			table.insert(decorFolders, child)
		end
	end
	for _, part in root:GetDescendants() do
		if part:IsA("BasePart") then
			local size = part.Size
			if NO_SHADOW_MATERIALS[part.Material] or part.Transparency >= 0.2 or size.X * size.Y * size.Z < 24 then
				part.CastShadow = false
			end
		end
	end
	for _, folder in decorFolders do
		for _, item in folder:GetDescendants() do
			if item:IsA("BasePart") then
				item.CanTouch = false
				item.CanQuery = false
			elseif item:IsA("ParticleEmitter") and item.Rate > MAX_DECOR_PARTICLE_RATE then
				item.Rate = MAX_DECOR_PARTICLE_RATE
			end
		end
	end
end

function MapBuilder.Build(): Folder
	setupLighting()
	local existing = workspace:FindFirstChild("Map")
	if existing and existing:IsA("Folder") and ((existing:GetAttribute("MapVersion") or 1) :: number) >= MAP_VERSION then
		-- A baked map (saved in the place file): reconnect the model references a saved copy may
		-- have lost, and refresh what can change between updates.
		for _, instance in existing:GetDescendants() do
			local primaryName = instance:GetAttribute("PrimaryPartName")
			if instance:IsA("Model") and not instance.PrimaryPart and type(primaryName) == "string" then
				local primary = instance:FindFirstChild(primaryName)
				if primary and primary:IsA("BasePart") then
					instance.PrimaryPart = primary
				end
			elseif instance:IsA("Beam") or instance:IsA("Trail") then
				reconnectAttachments(instance)
			end
		end
		local hub = existing:FindFirstChild("Hub")
		if hub then
			-- New leaderboards (e.g. donations): rebuild the row of boards.
			local boards = hub:FindFirstChild("Leaderboards")
			local missing = boards == nil
			for _, board in Config.Leaderboards.Boards do
				if boards and not boards:FindFirstChild("Board_" .. board.Id) then
					missing = true
				end
			end
			if missing then
				if boards then
					boards:Destroy()
				end
				buildLeaderboards(hub)
			end
		end
		refreshAreaSigns(existing)
		buildLane(existing) -- adds any biomes that are missing
		optimize(existing)
		mapFolder = existing
		return existing
	end
	-- No map, or one saved by an older version of the game: build it all from scratch. (Version 12:
	-- one lobby, one lane of 17 biomes with Domer's corners and box spots, donut-shop bases.)
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Map"
	folder:SetAttribute("MapVersion", MAP_VERSION)
	buildHub(folder)
	buildPlots(folder)
	buildLane(folder)
	-- Remember each model's main part by name, so a baked copy of the map can reconnect it.
	for _, model in folder:GetDescendants() do
		if model:IsA("Model") and model.PrimaryPart then
			model:SetAttribute("PrimaryPartName", model.PrimaryPart.Name)
		end
	end
	optimize(folder)
	folder.Parent = workspace
	mapFolder = folder
	return folder
end

function MapBuilder.Get(): Folder
	assert(mapFolder, "MapBuilder.Build() has not run yet")
	return mapFolder :: Folder
end

function MapBuilder.GetPlot(index: number, _worldId: number?): Model
	return MapBuilder.Get():WaitForChild("Plots"):WaitForChild("Plot" .. index) :: Model
end

function MapBuilder.GetArea(index: number): Folder
	return MapBuilder.Get():WaitForChild("Lane"):WaitForChild("Area" .. index) :: Folder
end

function MapBuilder.GetHub(): Folder
	return MapBuilder.Get():WaitForChild("Hub") :: Folder
end

-- The spots where a biome's boxes sit, in order (BoxSpots/BoxSpot, Index 1..PerBiome).
function MapBuilder.GetBoxSpots(areaId: number): { BasePart }
	local folder = MapBuilder.GetArea(areaId):WaitForChild("BoxSpots")
	local spots: { BasePart } = {}
	for _, spot in folder:GetChildren() do
		if spot:IsA("BasePart") and spot.Name == "BoxSpot" then
			table.insert(spots, spot)
		end
	end
	table.sort(spots, function(a, b)
		return ((a:GetAttribute("Index") :: number?) or 0) < ((b:GetAttribute("Index") :: number?) or 0)
	end)
	return spots
end

return MapBuilder
