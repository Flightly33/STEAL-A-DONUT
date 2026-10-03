--[[
	MapBuilder
	==========
	Builds the whole world from code: the safe hub (plots, shop, leaderboards, spawn), the safe-zone
	line, and the lane of themed areas with their donut spawn points and guard beds.

	Want to edit the map by hand in Studio? "Bake" it:
		1. In Studio (edit mode, not playing) open View > Command Bar and run:
		   require(game.ServerScriptService.Server.MapBuilder).Build()
		2. A "Map" folder appears in Workspace. Move/replace/restyle anything you like and save.
		3. When the game runs and Workspace.Map already exists, it is used instead of rebuilding.
		Keep the names of: Plots/PlotN (+ Slots/SlotN, Spawn, TreadmillAnchor, PodiumAnchor, SignAnchor),
		Lane/AreaN (+ Spawns/DonutSpawn, GuardHome), Hub/ShopStall/PromptPart, Hub/Leaderboards/Board_X/Screen
		and the Portal models (Hub/Portals, Worlds/WorldN/HomePortal).

	All areas live in Lane/AreaN, whichever world they belong to: World 1's lane starts at the hub,
	the other worlds' lanes are far away along X (Areas.Worlds[].OffsetX), each with its own hub
	(Worlds/WorldN) that has a base plot for every player (Worlds/WorldN/Plots/PlotN) and a portal
	back home.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Areas = require(Shared.Areas)
local Layout = require(Shared.Layout)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Donuts = require(Shared.Donuts)
local DonutModel = require(Shared.DonutModel)

local Build = require(script.Parent.Build)
local WorldDecor = require(script.Parent.WorldDecor)
local Decor = require(script.Parent.Decor)
local BlackHoleModel = require(script.Parent.BlackHoleModel)

local MapBuilder = {}

local rgb = Color3.fromRGB
local map = Config.Map
local HUB_GREEN = { rgb(120, 210, 56), rgb(106, 196, 48) }
local WALL_BROWN = { rgb(206, 136, 78), rgb(192, 124, 68) }

local mapFolder: Folder? = nil
local MAP_VERSION = 11

--------------------------------------------------------------------------------
-- Portals (hub -> other worlds, and back home)
--------------------------------------------------------------------------------
local function buildPortal(parent: Instance, name: string, cf: CFrame, color: Color3, title: string, subtitle: string, targetWorld: number, home: boolean)
	local portal = Instance.new("Model")
	portal.Name = name
	portal:SetAttribute("TargetWorld", targetWorld)
	portal:SetAttribute("Home", home)
	local radius, ball = 7, 3.4
	-- A giant standing donut is the portal ring (faces the people walking in)
	local ringCf = cf * CFrame.new(0, radius + ball / 2 + 1, 0)
	Decor.GiantDonut(portal, ringCf, radius, ball, rgb(222, 165, 95), color, { rgb(255, 255, 255), rgb(255, 230, 60), rgb(255, 90, 150) })
	Build.Part({ Parent = portal, Name = "PortalBase", Size = Vector3.new(radius * 2 + 6, 1, 6), CFrame = cf * CFrame.new(0, 0.5, 0), Color = rgb(245, 245, 245), Material = Enum.Material.Marble })
	local swirl = Build.Decor({ Parent = portal, Name = "Swirl", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, radius * 2 - 1, radius * 2 - 1), CFrame = ringCf * CFrame.Angles(0, math.pi / 2, 0), Color = color, Material = Enum.Material.Neon, Transparency = 0.35 })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	emitter.LightEmission = 1
	emitter.Rate = 25
	emitter.Lifetime = NumberRange.new(1, 1.6)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.5, 0)
	emitter.Parent = swirl
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 20
	light.Brightness = 2
	light.Parent = swirl
	local trigger = Build.Part({ Parent = portal, Name = "Trigger", Size = Vector3.new(radius * 2, 12, 4), CFrame = cf * CFrame.new(0, 6, 0), Transparency = 1, CanCollide = false, CanQuery = false })
	trigger:SetAttribute("PortalTrigger", true)
	local sign = Instance.new("BillboardGui")
	sign.Name = "PortalSign"
	sign.Size = UDim2.fromScale(20, 5.5)
	sign.StudsOffsetWorldSpace = Vector3.new(0, radius * 2 + 9, 0)
	sign.LightInfluence = 0
	sign.MaxDistance = 260
	sign.Parent = trigger
	Build.Text(sign, title, { Name = "Title", Size = UDim2.fromScale(1, 0.62), TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35), TextStrokeColor3 = rgb(30, 20, 40) })
	Build.Text(sign, subtitle, { Name = "Subtitle", Size = UDim2.fromScale(1, 0.38), Position = UDim2.fromScale(0, 0.62), TextColor3 = rgb(255, 235, 120), Font = Enum.Font.FredokaOne })
	portal.PrimaryPart = trigger
	portal.Parent = parent
	return portal
end

local function portalSubtitle(world: Areas.World): string
	if (world.RequiredUltimate or 0) > 0 then
		return "🔒 Needs an ULTIMATE REBIRTH  •  Rarer donuts, 2x money"
	end
	return `🔒 Needs {Economy.WorldRequirementText(world.Id)}  •  Everyone is x{world.WalkMultiplier} faster`
end

local function buildHubPortals(hub: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Portals"
	folder.Parent = hub
	for _, world in Areas.Worlds do
		if world.Id > 1 then
			buildPortal(folder, "Portal_World" .. world.Id, Layout.PortalCFrame(world.Id), world.Color, `{world.Icon} {string.upper(world.Name)}`, portalSubtitle(world), world.Id, false)
		end
	end
end

-- A saved map keeps the text it was built with; rewrite the parts that come from the config.
local function refreshPortalSigns(hub: Instance)
	local portals = hub:FindFirstChild("Portals")
	for _, world in Areas.Worlds do
		local portal = portals and portals:FindFirstChild("Portal_World" .. world.Id)
		local trigger = portal and portal:FindFirstChild("Trigger")
		local sign = trigger and trigger:FindFirstChild("PortalSign")
		local subtitle = sign and sign:FindFirstChild("Subtitle")
		if subtitle and subtitle:IsA("TextLabel") then
			subtitle.Text = portalSubtitle(world)
		end
	end
end

-- The long bridge between a world's landing and its first area. Kept cheap: big floor pieces,
-- low walls, and a few props (it's something you run across, not somewhere you stay).
local function buildBridge(parent: Instance, world: Areas.World)
	local length = world.BridgeLength
	if length <= 0 then
		return
	end
	local bridge = Instance.new("Folder")
	bridge.Name = "Bridge"
	bridge.Parent = parent
	local x0, z0, half = world.OffsetX, map.SafeZoneZ, map.LaneHalfWidth
	local first = Areas.ByWorld[world.Id][1]
	local dream = world.Id == 3
	local cyber = world.Id == 4
	-- (World 2, The Underworld: a basalt bridge over a sea of lava)
	local floorColors = if dream then { rgb(250, 245, 255), rgb(255, 225, 245) } elseif cyber then { rgb(28, 28, 40), rgb(36, 36, 52) } else { rgb(56, 42, 38), rgb(68, 50, 44) }
	local floorMaterial = if dream then Enum.Material.SmoothPlastic elseif cyber then Enum.Material.Metal else Enum.Material.Basalt
	local segment = 80
	local i = 0
	for z = z0, z0 + length - segment, segment do
		i += 1
		Build.Part({ Parent = bridge, Name = "BridgeFloor", Size = Vector3.new(half * 2, 1, segment), Position = Vector3.new(x0, -0.5, z + segment / 2), Color = floorColors[i % 2 + 1], Material = floorMaterial })
	end
	if cyber then
		-- Neon lines along the bridge
		for _, x in { -half + 3, half - 3 } do
			Build.Decor({ Parent = bridge, Name = "NeonLine", Size = Vector3.new(0.8, 0.05, length), Position = Vector3.new(x0 + x, 0.03, z0 + length / 2), Color = if x < 0 then rgb(255, 40, 200) else rgb(0, 230, 255), Material = Enum.Material.Neon })
		end
	elseif not dream then
		-- Lava glowing through cracks along the bridge
		for _, x in { -half + 3, half - 3 } do
			Decor.Lava(bridge, { Name = "LavaSeam", Size = Vector3.new(0.8, 0.05, length), Position = Vector3.new(x0 + x, 0.03, z0 + length / 2) })
		end
	end
	local t, h = 4, 14
	for _, side in { -1, 1 } do
		Build.Part({ Parent = bridge, Name = "BridgeWall", Size = Vector3.new(t, h, length), Position = Vector3.new(x0 + side * (half + t / 2), h / 2, z0 + length / 2), Color = first.Wall[1], Material = first.WallMaterial })
		Build.Part({ Parent = bridge, Name = "BridgeRail", Size = Vector3.new(t + 1, 1.5, length), Position = Vector3.new(x0 + side * (half + t / 2), h + 0.75, z0 + length / 2), Color = first.Trim, Material = first.TrimMaterial })
		-- Clouds (dream), the glowing city floor (cyber) or lava (the Underworld) far below the bridge
		Build.Decor({ Parent = bridge, Name = if dream then "CloudSea" elseif cyber then "CityFloor" else "LavaSea", Size = Vector3.new(400, 1, length), Position = Vector3.new(x0 + side * (half + t + 200), -18, z0 + length / 2), Color = if dream then rgb(255, 240, 250) elseif cyber then rgb(20, 16, 40) else rgb(170, 40, 6), Material = if dream then Enum.Material.SmoothPlastic elseif cyber then Enum.Material.Metal else Enum.Material.Neon })
	end
	-- Props along the edges
	local rng = Random.new(world.Id * 31)
	for z = z0 + 40, z0 + length - 20, 80 do
		for _, side in { -1, 1 } do
			local pos = Vector3.new(x0 + side * (half - 6), 0, z + rng:NextNumber(-10, 10))
			if cyber then
				Build.Pillar(bridge, pos, 10, 0.6, rgb(50, 50, 60), Enum.Material.Metal)
				local lampBall = Build.Ball(bridge, pos + Vector3.new(0, 10.6, 0), 1.6, if side < 0 then rgb(255, 40, 200) else rgb(0, 230, 255), Enum.Material.Neon)
				local light = Instance.new("PointLight")
				light.Color = lampBall.Color
				light.Range = 18
				light.Parent = lampBall
			elseif dream then
				for n = 1, 4 do
					Build.Ball(bridge, pos + Vector3.new(rng:NextNumber(-3, 3), 2 + rng:NextNumber(0, 2), rng:NextNumber(-3, 3)), rng:NextNumber(3, 5), if n % 2 == 0 then rgb(255, 210, 240) else rgb(255, 255, 255))
				end
			else
				-- fire torches
				Build.Pillar(bridge, pos, 9, 1, rgb(45, 36, 34), Enum.Material.Basalt)
				local flame = Build.Ball(bridge, pos + Vector3.new(0, 9.6, 0), 1.6, rgb(255, 150, 40), Enum.Material.Neon)
				local fire = Instance.new("Fire")
				fire.Size = 4
				fire.Heat = 6
				fire.Parent = flame
				local light = Instance.new("PointLight")
				light.Color = rgb(255, 140, 50)
				light.Range = 18
				light.Parent = flame
			end
		end
	end
	-- Signs counting down to the first area
	for z = z0 + 400, z0 + length - 100, 400 do
		local sign = Build.Part({ Parent = bridge, Name = "DistanceSign", Size = Vector3.new(24, 6, 1), CFrame = CFrame.lookAt(Vector3.new(x0, 22, z), Vector3.new(x0, 22, z - 10)), Color = world.Color:Lerp(Color3.new(0, 0, 0), 0.3), Material = Enum.Material.SmoothPlastic, CanCollide = false })
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 12
		gui.LightInfluence = 0
		gui.Parent = sign
		Build.Text(gui, `{first.Name}: {math.floor(z0 + length - z)} studs ➜`, { TextColor3 = rgb(255, 255, 255) })
	end
end

-- The safe hub in front of a world's lane (worlds 2+): same size as the main hub, with a base plot
-- for every player (your base follows you to whichever world you're in), and the portal home.
local buildPlot: (parent: Instance, plotIndex: number, worldId: number) -> ()

local function buildWorldLanding(parent: Instance, world: Areas.World)
	local folder = Instance.new("Model")
	folder.Name = "World" .. world.Id
	folder:SetAttribute("WorldId", world.Id)
	local x0, z0, depth, half = world.OffsetX, map.SafeZoneZ, map.HubDepth, map.HubHalfWidth
	local first = Areas.ByWorld[world.Id][1]
	local floorColors = { first.Floor[1]:Lerp(Color3.new(1, 1, 1), 0.15), first.Floor[2]:Lerp(Color3.new(1, 1, 1), 0.15) }
	Build.CheckerFloor(folder, x0 - half, x0 + half, z0 - depth, z0, map.TileSize, floorColors, first.FloorMaterial)
	local t, h = 4, map.HubWallHeight
	local wallColors = first.Wall
	Build.CheckerWall(folder, Vector3.new(x0 - half - t / 2, 0, z0 - depth - t), Vector3.new(0, 0, 1), depth + t, h, t, wallColors, first.WallMaterial, 20)
	Build.CheckerWall(folder, Vector3.new(x0 + half + t / 2, 0, z0 - depth - t), Vector3.new(0, 0, 1), depth + t, h, t, wallColors, first.WallMaterial, 20)
	Build.CheckerWall(folder, Vector3.new(x0 - half - t, 0, z0 - depth - t / 2), Vector3.new(1, 0, 0), half * 2 + t * 2, h, t, wallColors, first.WallMaterial, 20)
	local laneOuter = map.LaneHalfWidth + t
	for _, side in { -1, 1 } do
		local from = if side < 0 then x0 - half - t else x0 + laneOuter
		Build.CheckerWall(folder, Vector3.new(from, 0, z0 + t / 2), Vector3.new(1, 0, 0), half + t - laneOuter, h, t, wallColors, first.WallMaterial, 20)
		Build.Part({ Parent = folder, Name = "WallTop", Size = Vector3.new(t + 1, 2, depth + t), Position = Vector3.new(x0 + side * (half + t / 2), h + 1, z0 - depth / 2 - t / 2), Color = first.Trim, Material = first.TrimMaterial })
	end
	-- Safe zone line
	Build.Part({ Parent = folder, Name = "SafeZoneLine", Size = Vector3.new(map.LaneHalfWidth * 2, 0.2, 1.5), Position = Vector3.new(x0, 0.1, z0 - 0.75), Color = rgb(255, 50, 50), Material = Enum.Material.Neon, CanCollide = false })
	-- Welcome sign over the lane entrance
	local beam = Build.Part({
		Parent = folder, Name = "WorldSign",
		Size = Vector3.new(map.LaneHalfWidth * 2 + 14, 8, 4),
		CFrame = CFrame.lookAt(Vector3.new(x0, 40, z0 + 2), Vector3.new(x0, 40, z0 - 10)),
		Color = world.Color:Lerp(Color3.new(0, 0, 0), 0.35), Material = Enum.Material.SmoothPlastic,
	})
	for _, side in { -1, 1 } do
		Build.Part({ Parent = folder, Name = "GatePillar", Size = Vector3.new(6, 36, 6), Position = Vector3.new(x0 + side * (map.LaneHalfWidth + 5), 18, z0 + 2), Color = world.Color, Material = Enum.Material.SmoothPlastic })
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 12
	gui.LightInfluence = 0
	gui.Parent = beam
	Build.Text(gui, `{world.Icon} WORLD {world.Id}: {string.upper(world.Name)} {world.Icon}`, { TextColor3 = rgb(255, 255, 255), TextStrokeColor3 = rgb(20, 20, 40) })
	buildPortal(folder, "HomePortal", Layout.PortalCFrame(world.Id, true), rgb(120, 230, 90), "🏠 BACK TO DONUT LAND", "Your base comes with you!", 1, true)
	buildBridge(folder, world)
	WorldDecor.Build(folder, world)
	local marker = Build.Part({ Parent = folder, Name = "Arrival", Size = Vector3.new(4, 1, 4), CFrame = Layout.WorldArrival(world.Id), Transparency = 1, CanCollide = false, CanQuery = false })
	folder.PrimaryPart = marker
	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = folder
	for i = 1, Config.Plots.Count do
		buildPlot(plots, i, world.Id)
	end
	folder.Parent = parent
end

-- The hubs of worlds 2+ (only the missing ones, so a saved map gets new worlds added).
local function buildWorlds(parent: Folder)
	local worlds: Instance
	local found = parent:FindFirstChild("Worlds")
	if found then
		worlds = found
	else
		local folder = Instance.new("Folder")
		folder.Name = "Worlds"
		folder.Parent = parent
		worlds = folder
	end
	for _, world in Areas.Worlds do
		if world.Id > 1 and not worlds:FindFirstChild("World" .. world.Id) then
			buildWorldLanding(worlds, world)
		end
	end
end

--------------------------------------------------------------------------------
-- Hub
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

local function buildStall(parent: Instance, name: string, x: number, title: string, stripe: Color3, tab: string, keeperIndex: number)
	local shop = Instance.new("Model")
	shop.Name = name
	shop:SetAttribute("ShopTab", tab)
	local origin = CFrame.lookAt(Vector3.new(x, 0, -232), Vector3.new(x, 0, -200))
	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end
	-- Counter + posts
	local counter = Build.Part({ Parent = shop, Name = "Counter", Size = Vector3.new(18, 4, 5), CFrame = at(0, 2, -2), Color = rgb(150, 95, 55), Material = Enum.Material.WoodPlanks })
	for _, x in { -8.5, 8.5 } do
		for _, z in { -4, 3 } do
			Build.Part({ Parent = shop, Name = "Post", Size = Vector3.new(0.8, 12, 0.8), CFrame = at(x, 6, z), Color = rgb(120, 75, 40), Material = Enum.Material.Wood })
		end
	end
	-- Striped awning (like the reference stalls)
	for i = 0, 8 do
		Build.Part({ Parent = shop, Name = "Awning", Size = Vector3.new(2.2, 0.5, 10), CFrame = at(-8.8 + i * 2.2, 12.3, -0.5) * CFrame.Angles(math.rad(-12), 0, 0), Color = if i % 2 == 0 then stripe else rgb(255, 255, 255), Material = Enum.Material.SmoothPlastic })
	end
	-- Glowing circle to stand in
	Build.Part({ Parent = shop, Name = "Glow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 14, 14), CFrame = at(0, 0.08, -9) * CFrame.Angles(0, 0, math.pi / 2), Color = stripe, Material = Enum.Material.Neon, Transparency = 0.45, CanCollide = false })
	-- The prompt anchor
	local prompt = Build.Part({ Parent = shop, Name = "PromptPart", Size = Vector3.new(4, 4, 1), CFrame = at(0, 3, -5), Transparency = 1, CanCollide = false })
	-- Sign
	local sign = Instance.new("BillboardGui")
	sign.Name = "Sign"
	sign.Size = UDim2.fromScale(22, 6)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 11, 0)
	sign.LightInfluence = 0
	sign.MaxDistance = 250
	sign.Parent = counter
	Build.Text(sign, title, { TextColor3 = stripe, TextStrokeColor3 = rgb(40, 20, 0) })
	-- A donut shopkeeper on the counter
	local keeper = DonutModel.Build(Donuts.List[keeperIndex], { Scale = 0.9, NoEffects = true })
	DonutModel.PlaceOn(keeper, at(0, 4, -2) * CFrame.Angles(0, math.pi, 0))
	keeper.Parent = shop
	shop.PrimaryPart = counter
	shop.Parent = parent
	prompt:SetAttribute("Shop", true)
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
	buildStall(hub, "ShopStall", -88, "🛒 SHOP", rgb(255, 230, 40), "Upgrades", 1)
	buildStall(hub, "ItemShopStall", 86, "⚔️ ITEM SHOP", rgb(255, 70, 70), "Items", 3)
	buildLeaderboards(hub)
	buildHubPortals(hub)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.lookAt(Vector3.new(0, 0.5, z0 - 150), Vector3.new(0, 0.5, z0))
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = rgb(120, 200, 255)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = hub
end

--------------------------------------------------------------------------------
-- Lane / areas
-- Every area is built around X = 0 and then moved to its world's lane.
--------------------------------------------------------------------------------
-- Third line of an area's arch sign. Rewritten on every start (refreshAreaSigns), so a saved map
-- never shows an old guard name or old speeds after a rebalance.
local function guardInfoText(area: Areas.Area): string
	local guardSpeed = math.floor(Economy.GuardWalkSpeed(area.Id))
	local recommended = Economy.RecommendedSpeed(area.Id)
	local rec = if recommended > 0 then "⚡ Recommended Speed: " .. Format.Number(recommended) else "⚡ Any speed works here!"
	return `😴 {Config.Guard.Name} speed: {guardSpeed}   •   {rec}`
end

local function buildArch(parent: Instance, area: Areas.Area, zs: number)
	local half = Layout.AreaHalfWidth(area.Id)
	local arch = Instance.new("Model")
	arch.Name = "Arch"
	for _, side in { -1, 1 } do
		Build.Part({ Parent = arch, Name = "ArchPillar", Size = Vector3.new(6, 34, 6), Position = Vector3.new(side * (half - 3), 17, zs + 3), Color = area.Wall[1]:Lerp(Color3.new(0, 0, 0), 0.25), Material = area.WallMaterial })
		Build.Part({ Parent = arch, Name = "ArchCap", Size = Vector3.new(7, 1.5, 7), Position = Vector3.new(side * (half - 3), 34.75, zs + 3), Color = area.Trim, Material = area.TrimMaterial })
	end
	local beam = Build.Part({
		Parent = arch, Name = "ArchSign",
		Size = Vector3.new(half * 2 - 4, 9, 4),
		CFrame = CFrame.lookAt(Vector3.new(0, 39, zs + 3), Vector3.new(0, 39, zs - 10)),
		Color = area.Wall[1]:Lerp(Color3.new(0, 0, 0), 0.4), Material = area.WallMaterial,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 14
	gui.LightInfluence = 0
	gui.Parent = beam
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = gui
	Build.Text(gui, "AREA " .. area.Id, { Size = UDim2.fromScale(1, 0.22), TextColor3 = rgb(255, 255, 255), LayoutOrder = 1 })
	Build.Text(gui, string.upper(area.Name), { Size = UDim2.fromScale(1, 0.45), TextColor3 = area.Trim:Lerp(Color3.new(1, 1, 1), 0.35), LayoutOrder = 2 })
	Build.Text(gui, guardInfoText(area), { Name = "GuardInfo", Size = UDim2.fromScale(1, 0.25), TextColor3 = rgb(255, 230, 90), Font = Enum.Font.FredokaOne, LayoutOrder = 3 })
	arch.Parent = parent
end

local function refreshAreaSigns(mapFolder: Instance)
	local lane = mapFolder:FindFirstChild("Lane")
	for _, area in Areas.List do
		local folder = lane and lane:FindFirstChild("Area" .. area.Id)
		local arch = folder and folder:FindFirstChild("Arch")
		local sign = arch and arch:FindFirstChild("ArchSign")
		local gui = sign and sign:FindFirstChildOfClass("SurfaceGui")
		if gui then
			for _, label in gui:GetChildren() do
				-- Older maps have no names on the labels: the guard line is the one with the 😴.
				if label:IsA("TextLabel") and (label.Name == "GuardInfo" or string.find(label.Text, "😴", 1, true)) then
					label.Name = "GuardInfo"
					label.Text = guardInfoText(area)
				end
			end
		end
	end
end

-- Guard bed position before the area is moved to its world (X = 0).
local function localGuardHome(areaId: number): Vector3
	return Vector3.new(0, 0, Layout.AreaEnd(areaId) - Layout.GuardBackOffset)
end

local function buildGuardBed(parent: Instance, areaId: number)
	local home = localGuardHome(areaId)
	local bed = Instance.new("Model")
	bed.Name = "GuardBed"
	-- Picnic blanket, big enough for a HUGE guard (he lies along Z, head towards the back)
	local scale = Config.Guard.Scale
	local tile = math.max(4, math.floor(1.6 * scale + 0.5))
	local columns, rows = 4, math.max(3, math.ceil((5.5 * scale + 2) / tile))
	for i = 0, columns - 1 do
		for j = 0, rows - 1 do
			local x = (i - (columns - 1) / 2) * tile
			local z = (j - (rows - 1) / 2) * tile - 0.5 * scale -- a bit towards his feet
			Build.Decor({ Parent = bed, Name = "Blanket", Size = Vector3.new(tile, 0.25, tile), Position = home + Vector3.new(x, 0.13, z), Color = if (i + j) % 2 == 0 then rgb(220, 40, 40) else rgb(255, 255, 255), Material = Enum.Material.Fabric })
		end
	end
	-- Stack of empty pink donut boxes
	local boxX = columns * tile / 2 + 3
	for n = 0, 3 do
		Build.Decor({ Parent = bed, Name = "DonutBox", Size = Vector3.new(4, 1, 4), CFrame = CFrame.new(home + Vector3.new(boxX, 0.5 + n * 1.02, 3)) * CFrame.Angles(0, n * 0.2, 0), Color = rgb(255, 150, 200), Material = Enum.Material.SmoothPlastic })
	end
	local marker = Build.Part({ Parent = bed, Name = "GuardHome", Size = Vector3.new(2, 1, 2), CFrame = CFrame.lookAt(home + Vector3.new(0, 0.5, 0), home + Vector3.new(0, 0.5, -10)), Transparency = 1, CanCollide = false, CanQuery = false })
	marker:SetAttribute("Area", areaId)
	bed.Parent = parent
end

--------------------------------------------------------------------------------
-- The secret lab under The Black Hole (Areas[].Lab)
-- A pit on the right of the area drops you into a lab under the floor. Its window looks out on a
-- black hole held in an experiment; the big red button on the lectern is the ULTIMATE REBIRTH
-- (WorldService), and a pad in the corner takes you back up.
--------------------------------------------------------------------------------
local PIT_SIZE = Decor.LabPitSize
local LAB_FLOOR, LAB_CEILING = -60, -32

-- Centre of the pit (x, z) in an area built around X = 0 (The Black Hole's decor avoids it too).
local labPit = Decor.LabPit

local function buildLab(parent: Instance, zs: number)
	local lab = Instance.new("Model")
	lab.Name = "SecretLab"
	local px, pz = labPit(zs)
	local h = PIT_SIZE / 2
	local purple, dark, metal = rgb(170, 90, 255), rgb(24, 22, 32), rgb(60, 62, 74)
	local function solid(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
		return Build.Part({ Parent = lab, Name = name, Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.Metal })
	end
	local function glow(name: string, size: Vector3, cf: CFrame, color: Color3, transparency: number?): BasePart
		return Build.Decor({ Parent = lab, Name = name, Size = size, CFrame = cf, Color = color, Material = Enum.Material.Neon, Transparency = transparency or 0 })
	end
	local function lamp(position: Vector3, color: Color3, range: number)
		local bulb = glow("Lamp", Vector3.new(6, 0.4, 1.2), CFrame.new(position), color)
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = range
		light.Brightness = 2
		light.Parent = bulb
	end

	-- The pit: a shaft from the floor down to the lab's ceiling, with a striped hazard rim, bands of
	-- light down the walls and a purple glow rising out of it
	local depth = -LAB_CEILING
	local rim = PIT_SIZE + 2.4
	for _, side in { -1, 1 } do
		solid("ShaftWall", Vector3.new(1, depth, PIT_SIZE + 2), CFrame.new(px + side * (h + 0.5), LAB_CEILING / 2, pz), dark)
		solid("ShaftWall", Vector3.new(PIT_SIZE + 2, depth, 1), CFrame.new(px, LAB_CEILING / 2, pz + side * (h + 0.5)), dark)
		for i = 0, 7 do
			local along = (i - 3.5) * rim / 8
			local color = if i % 2 == 0 then rgb(255, 210, 0) else rgb(22, 22, 26)
			local material = if i % 2 == 0 then Enum.Material.Neon else Enum.Material.SmoothPlastic
			Build.Decor({ Parent = lab, Name = "PitRim", Size = Vector3.new(1.2, 0.3, rim / 8), CFrame = CFrame.new(px + side * (h + 0.6), 0.15, pz + along), Color = color, Material = material })
			Build.Decor({ Parent = lab, Name = "PitRim", Size = Vector3.new(rim / 8, 0.3, 1.2), CFrame = CFrame.new(px + along, 0.15, pz + side * (h + 0.6)), Color = color, Material = material })
		end
		for _, y in { -8, -16, -24 } do
			glow("ShaftLight", Vector3.new(0.2, 0.5, PIT_SIZE), CFrame.new(px + side * (h - 0.1), y, pz), purple, 0.2)
			glow("ShaftLight", Vector3.new(PIT_SIZE, 0.5, 0.2), CFrame.new(px, y, pz + side * (h - 0.1)), purple, 0.2)
		end
	end
	local pitGlow = Build.Decor({ Parent = lab, Name = "PitGlow", Size = Vector3.new(PIT_SIZE - 2, 1, PIT_SIZE - 2), CFrame = CFrame.new(px, LAB_CEILING + 1.5, pz), Transparency = 1 })
	local upLight = Instance.new("SpotLight")
	upLight.Face = Enum.NormalId.Top
	upLight.Color = purple
	upLight.Range = 40
	upLight.Angle = 70
	upLight.Brightness = 3
	upLight.Parent = pitGlow
	local motes = Instance.new("ParticleEmitter")
	motes.EmissionDirection = Enum.NormalId.Top
	motes.Rate = 12
	motes.Lifetime = NumberRange.new(4, 6)
	motes.Speed = NumberRange.new(4, 7)
	motes.SpreadAngle = Vector2.new(8, 8)
	motes.Size = NumberSequence.new(0.35, 0)
	motes.Color = ColorSequence.new(purple, rgb(255, 150, 70))
	motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	motes.LightEmission = 1
	motes.Parent = pitGlow
	-- Guards can't follow you down (GuardService makes this lid solid for guards only)
	local lid = Build.Part({ Parent = lab, Name = "GuardLid", Size = Vector3.new(PIT_SIZE, 1, PIT_SIZE), CFrame = CFrame.new(px, -0.5, pz), Transparency = 1, CanCollide = false, CanQuery = false })
	lid:SetAttribute("GuardBlocker", true)
	local hint = Instance.new("BillboardGui")
	hint.Size = UDim2.fromScale(16, 4)
	hint.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
	hint.LightInfluence = 0
	hint.MaxDistance = 120
	hint.Parent = lid
	Build.Text(hint, "⚠ KEEP OUT ⚠", { Size = UDim2.fromScale(1, 0.6), TextColor3 = rgb(255, 210, 0), TextStrokeColor3 = rgb(40, 20, 0) })
	Build.Text(hint, "restricted experiment below", { Size = UDim2.fromScale(1, 0.4), Position = UDim2.fromScale(0, 0.6), TextColor3 = rgb(220, 200, 255), Font = Enum.Font.FredokaOne })

	-- The lab room: x 35..92, one wall is a big window onto the experiment
	local x0, x1, z0, z1 = 35, 92, pz - 26, pz + 26
	local roomHeight = LAB_CEILING - LAB_FLOOR
	local midY = (LAB_CEILING + LAB_FLOOR) / 2
	Build.CheckerFloor(lab, x0, x1, z0, z1, 8, { rgb(235, 235, 242), rgb(205, 205, 218) }, Enum.Material.SmoothPlastic, LAB_FLOOR)
	-- ceiling around the shaft
	solid("Ceiling", Vector3.new(x1 - x0, 1, (pz - h) - z0), CFrame.new((x0 + x1) / 2, LAB_CEILING + 0.5, (z0 + pz - h) / 2), metal)
	solid("Ceiling", Vector3.new(x1 - x0, 1, z1 - (pz + h)), CFrame.new((x0 + x1) / 2, LAB_CEILING + 0.5, (pz + h + z1) / 2), metal)
	solid("Ceiling", Vector3.new((px - h) - x0, 1, PIT_SIZE), CFrame.new((x0 + px - h) / 2, LAB_CEILING + 0.5, pz), metal)
	solid("Ceiling", Vector3.new(x1 - (px + h), 1, PIT_SIZE), CFrame.new((px + h + x1) / 2, LAB_CEILING + 0.5, pz), metal)
	-- walls
	solid("LabWall", Vector3.new(1, roomHeight, z1 - z0 + 2), CFrame.new(x1 + 0.5, midY, pz), rgb(215, 218, 228), Enum.Material.SmoothPlastic)
	for _, z in { z0 - 0.5, z1 + 0.5 } do
		solid("LabWall", Vector3.new(x1 - x0 + 2, roomHeight, 1), CFrame.new((x0 + x1) / 2, midY, z), rgb(215, 218, 228), Enum.Material.SmoothPlastic)
	end
	-- the window wall (x = x0): glass in the middle, wall around it
	local windowHalf, windowBottom, windowTop = 19, LAB_FLOOR + 5, LAB_CEILING - 4
	solid("LabWall", Vector3.new(1, windowBottom - LAB_FLOOR, z1 - z0), CFrame.new(x0 - 0.5, (LAB_FLOOR + windowBottom) / 2, pz), metal)
	solid("LabWall", Vector3.new(1, LAB_CEILING - windowTop, z1 - z0), CFrame.new(x0 - 0.5, (windowTop + LAB_CEILING) / 2, pz), metal)
	for _, side in { -1, 1 } do
		local edge = pz + side * windowHalf
		local far = if side < 0 then z0 else z1
		solid("LabWall", Vector3.new(1, windowTop - windowBottom, math.abs(far - edge)), CFrame.new(x0 - 0.5, (windowBottom + windowTop) / 2, (edge + far) / 2), metal)
	end
	-- Not Glass: at high graphics settings Glass hides everything see-through behind it (the beams,
	-- sparks and glow that make up the black hole), so it's a clear pane with a little reflection.
	local windowMid = (windowBottom + windowTop) / 2
	local glass = solid("Window", Vector3.new(0.4, windowTop - windowBottom, windowHalf * 2), CFrame.new(x0 - 0.5, windowMid, pz), rgb(180, 220, 255), Enum.Material.SmoothPlastic)
	glass.Transparency = 0.9
	glass.Reflectance = 0.12
	glass.CastShadow = false
	for _, side in { -1, 1 } do
		solid("Mullion", Vector3.new(0.8, windowTop - windowBottom, 0.8), CFrame.new(x0 - 0.3, windowMid, pz + side * windowHalf / 3), metal)
	end
	-- the black hole's light spilling into the lab, and a hazard stripe in front of the window
	local spill = Build.Decor({ Parent = lab, Name = "HoleLight", Size = Vector3.new(0.2, 1, 1), CFrame = CFrame.new(x0 + 0.3, windowTop - 1, pz), Transparency = 1 })
	local spillLight = Instance.new("SpotLight")
	spillLight.Face = Enum.NormalId.Right
	spillLight.Color = rgb(255, 170, 110)
	spillLight.Range = 45
	spillLight.Angle = 110
	spillLight.Brightness = 1.6
	spillLight.Parent = spill
	for i = 0, 9 do
		Build.Decor({ Parent = lab, Name = "FloorStripe", Size = Vector3.new(1.2, 0.06, windowHalf / 5), Position = Vector3.new(x0 + 2.5, LAB_FLOOR + 0.03, pz - windowHalf + (i + 0.5) * windowHalf / 5), Color = if i % 2 == 0 then rgb(255, 210, 0) else rgb(25, 25, 25), Material = Enum.Material.SmoothPlastic })
	end
	glow("WindowFrame", Vector3.new(0.8, 0.5, windowHalf * 2 + 1), CFrame.new(x0 - 0.2, windowBottom, pz), purple)
	glow("WindowFrame", Vector3.new(0.8, 0.5, windowHalf * 2 + 1), CFrame.new(x0 - 0.2, windowTop, pz), purple)
	-- sign over the window
	local sign = solid("ExperimentSign", Vector3.new(0.4, 3, 22), CFrame.new(x0 + 0.2, LAB_CEILING - 2, pz), rgb(20, 20, 28))
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Right
	signGui.LightInfluence = 0
	signGui.Parent = sign
	Build.Text(signGui, "⚠ EXPERIMENT BH-01: CONTAINED BLACK HOLE ⚠", { TextColor3 = rgb(255, 210, 0), TextStrokeColor3 = rgb(0, 0, 0) })
	-- lights
	for _, z in { pz - 16, pz + 16 } do
		lamp(Vector3.new(80, LAB_CEILING - 0.3, z), rgb(235, 240, 255), 40)
	end
	lamp(Vector3.new(50, LAB_CEILING - 0.3, pz), rgb(200, 170, 255), 36)

	-- The lectern in front of the window, with the big red button
	local lx = x0 + 9
	solid("Lectern", Vector3.new(3, 4.5, 6), CFrame.new(lx, LAB_FLOOR + 2.25, pz), metal)
	local top = solid("LecternTop", Vector3.new(4.6, 0.6, 7.4), CFrame.new(lx + 0.3, LAB_FLOOR + 4.8, pz) * CFrame.Angles(0, 0, math.rad(-14)), rgb(40, 42, 52))
	local topCf = top.CFrame * CFrame.new(0, 0.3, 0)
	local ring = Build.Part({ Parent = lab, Name = "ButtonRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 3.4, 3.4), CFrame = topCf * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(255, 210, 0), Material = Enum.Material.SmoothPlastic })
	ring.CanCollide = false
	local button = Build.Part({ Parent = lab, Name = "UltimateButton", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 2.6, 2.6), CFrame = topCf * CFrame.new(0, 0.55, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(230, 20, 30), Material = Enum.Material.Neon })
	button.CanCollide = false
	button:SetAttribute("UltimateButton", true)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UltimatePrompt"
	prompt.ActionText = "ULTIMATE REBIRTH"
	prompt.ObjectText = "⚠ Do NOT press"
	prompt.HoldDuration = 1.2
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = button
	local label = Instance.new("BillboardGui")
	label.Name = "ButtonLabel"
	label.Size = UDim2.fromScale(14, 4.5)
	label.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
	label.LightInfluence = 0
	label.MaxDistance = 80
	label.Parent = button
	Build.Text(label, "ULTIMATE REBIRTH", { Size = UDim2.fromScale(1, 0.72), TextColor3 = rgb(255, 40, 40), TextStrokeColor3 = rgb(255, 255, 255) })
	Build.Text(label, "resets you... and takes you to WORLD 2", { Size = UDim2.fromScale(1, 0.28), Position = UDim2.fromScale(0, 0.72), TextColor3 = rgb(255, 230, 120), Font = Enum.Font.FredokaOne })
	-- smaller buttons and blinking lights on the lectern
	for i, color in { rgb(60, 220, 90), rgb(255, 210, 0), rgb(60, 150, 255), rgb(255, 120, 200) } do
		local small = Build.Decor({ Parent = lab, Name = "SmallButton", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 0.8, 0.8), CFrame = topCf * CFrame.new(-1.3, 0.2, -3 + (i - 1) * 2) * CFrame.Angles(0, 0, math.pi / 2), Color = color, Material = Enum.Material.Neon })
		small.CastShadow = false
	end
	-- monitors on the back wall
	for i, text in { "CONTAINMENT FIELD: 99.7%", "GRAVITY: ∞  •  TIME: ???", "DO NOT PRESS THE RED BUTTON" } do
		local screen = solid("Monitor", Vector3.new(0.4, 5, 9), CFrame.new(x1 - 0.2, LAB_FLOOR + 9, pz - 13 + (i - 1) * 13), rgb(10, 20, 30), Enum.Material.SmoothPlastic)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Left
		gui.LightInfluence = 0
		gui.Parent = screen
		local readout = Build.Text(gui, text, { TextColor3 = if i == 3 then rgb(255, 70, 70) else rgb(80, 255, 170), Font = Enum.Font.Code })
		if i == 1 then
			CollectionService:AddTag(readout, "LabReadout") -- BlackHoleFX makes the reading flicker
		end
	end
	-- the way back up
	local pad = Build.Part({ Parent = lab, Name = "ExitPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 8, 8), CFrame = CFrame.new(86, LAB_FLOOR + 0.2, pz + 19) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(80, 255, 120), Material = Enum.Material.Neon })
	pad.CanCollide = false
	pad:SetAttribute("LabExit", true)
	local exit = Instance.new("ProximityPrompt")
	exit.Name = "ExitPrompt"
	exit.ActionText = "Go back up"
	exit.ObjectText = "⬆ Lift"
	exit.HoldDuration = 0.3
	exit.MaxActivationDistance = 10
	exit.RequiresLineOfSight = false
	exit.Parent = pad

	-- The experiment beyond the window: a tall, dark chamber full of stars. The black hole is held in
	-- two spinning containment rings and fed by four pylons, and its jets hit plates in the ceiling
	-- and floor.
	local cx0, cx1, cz0, cz1, cy0, cy1 = -85, x0 - 1, pz - 62, pz + 62, -122, -3
	local chamber = rgb(8, 6, 16)
	local cyan = rgb(90, 220, 255)
	local function shell(size: Vector3, position: Vector3)
		Build.Decor({ Parent = lab, Name = "ChamberWall", Size = size, Position = position, Color = chamber, Material = Enum.Material.Metal })
	end
	shell(Vector3.new(cx1 - cx0, 1, cz1 - cz0), Vector3.new((cx0 + cx1) / 2, cy0, pz))
	shell(Vector3.new(cx1 - cx0, 1, cz1 - cz0), Vector3.new((cx0 + cx1) / 2, cy1, pz))
	shell(Vector3.new(1, cy1 - cy0, cz1 - cz0), Vector3.new(cx0, (cy0 + cy1) / 2, pz))
	for _, z in { cz0, cz1 } do
		shell(Vector3.new(cx1 - cx0, cy1 - cy0, 1), Vector3.new((cx0 + cx1) / 2, (cy0 + cy1) / 2, z))
	end
	-- the lab's side of the chamber, round the room
	shell(Vector3.new(1, LAB_FLOOR - 1 - cy0, cz1 - cz0), Vector3.new(x0 - 0.5, (cy0 + LAB_FLOOR - 1) / 2, pz))
	shell(Vector3.new(1, cy1 - LAB_CEILING - 1, cz1 - cz0), Vector3.new(x0 - 0.5, (LAB_CEILING + 1 + cy1) / 2, pz))
	for _, side in { -1, 1 } do
		local edge, far = pz + side * 27, pz + side * 62
		shell(Vector3.new(1, LAB_CEILING - LAB_FLOOR + 2, math.abs(far - edge)), Vector3.new(x0 - 0.5, (LAB_FLOOR + LAB_CEILING) / 2, (edge + far) / 2))
	end
	-- stars on the walls, so it looks like space in there
	local starRng = Random.new(zs)
	local starColors = { rgb(255, 255, 255), rgb(200, 220, 255), rgb(220, 190, 255), rgb(255, 230, 200) }
	for _ = 1, 90 do
		local wall = starRng:NextInteger(1, 4)
		local y = starRng:NextNumber(cy0 + 2, cy1 - 2)
		local at = if wall == 1 then Vector3.new(cx0 + 0.6, y, starRng:NextNumber(cz0 + 2, cz1 - 2))
			elseif wall == 2 then Vector3.new(starRng:NextNumber(cx0 + 2, cx1 - 2), y, cz0 + 0.6)
			elseif wall == 3 then Vector3.new(starRng:NextNumber(cx0 + 2, cx1 - 2), y, cz1 - 0.6)
			else Vector3.new(starRng:NextNumber(cx0 + 2, cx1 - 2), cy1 - 0.6, starRng:NextNumber(cz0 + 2, cz1 - 2))
		Build.Decor({ Parent = lab, Name = "Star", Shape = Enum.PartType.Ball, Size = Vector3.one * starRng:NextNumber(0.25, 0.7), Position = at, Color = starColors[starRng:NextInteger(1, #starColors)], Material = Enum.Material.Neon, Transparency = starRng:NextNumber(0, 0.4) })
	end

	local center = Vector3.new(-26, (windowBottom + windowTop) / 2 - 2, pz) -- right in the middle of the view
	local hole = Decor.BlackHole(lab, center, 0.8, { View = Vector3.new(1, -0.1, 0), Tilt = 12, Roll = 7, JetLength = 4.5 })
	local core = hole.PrimaryPart :: BasePart
	local r = core.Size.X / 2

	-- containment field rings on the floor, and plates catching the jets
	local field = Build.Decor({ Parent = lab, Name = "FieldRings", Size = Vector3.one, Position = Vector3.new(center.X, cy0 + 1, center.Z), Transparency = 1 })
	for i, radius in { 14, 23, 32 } do
		BlackHoleModel.Ring(field, "Field" .. i .. "_", radius, 0.7, cyan, 0.25 + i * 0.12, 0.4)
	end
	for n, y in { cy1 - 1, cy0 + 1 } do
		Build.Decor({ Parent = lab, Name = "JetCatcher", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 18, 18), CFrame = CFrame.new(center.X, y, center.Z) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(30, 28, 44), Material = Enum.Material.Metal })
		local catcher = Build.Decor({ Parent = lab, Name = "CatcherRings", Size = Vector3.one, Position = Vector3.new(center.X, y + (if n == 1 then -0.6 else 0.6), center.Z), Transparency = 1 })
		BlackHoleModel.Ring(catcher, "Catch", 8, 0.5, rgb(140, 120, 255), 0.1)
		BlackHoleModel.Ring(catcher, "CatchIn", 4.5, 0.35, cyan, 0.2, 0.8)
	end

	-- two containment rings round it (BlackHoleFX spins them)
	for i, tilt in { CFrame.Angles(0, 0, math.rad(72)), CFrame.Angles(math.rad(64), math.rad(40), 0) } do
		local gyro = Instance.new("Model")
		gyro.Name = "ContainmentRing"
		local base = CFrame.new(center) * tilt
		local hub = Build.Decor({ Parent = gyro, Name = "Hub", Size = Vector3.one, CFrame = base, Transparency = 1 })
		local radius = r * (4.45 + i * 0.25)
		local count = 28
		local length = 2 * radius * math.tan(math.pi / count) + 0.2
		for n = 0, count - 1 do
			Build.Decor({ Parent = gyro, Name = "RingSegment", Size = Vector3.new(1.6, 2.4, length), CFrame = base * CFrame.Angles(0, n / count * math.pi * 2, 0) * CFrame.new(radius, 0, 0), Color = rgb(44, 46, 60), Material = Enum.Material.Metal })
		end
		for n = 0, 3 do
			local node = Build.Decor({ Parent = gyro, Name = "RingNode", Shape = Enum.PartType.Ball, Size = Vector3.one * 3.2, CFrame = base * CFrame.Angles(0, (n + 0.5) * math.pi / 2, 0) * CFrame.new(radius, 0, 0), Color = cyan, Material = Enum.Material.Neon })
			node.CastShadow = false
		end
		BlackHoleModel.Ring(hub, "Strip", radius - 1, 0.5, cyan, 0.15)
		gyro.PrimaryPart = hub
		gyro:SetAttribute("Spin", if i == 1 then 0.35 else -0.25)
		gyro:SetAttribute("Precess", if i == 1 then 0.08 else -0.06)
		CollectionService:AddTag(gyro, "GyroRing")
		gyro.Parent = lab
	end

	-- four pylons feeding it energy
	local feed = Instance.new("Attachment")
	feed.Name = "Feed"
	feed.CFrame = core.CFrame:ToObjectSpace(CFrame.new(center - Vector3.new(0, r * 1.15, 0)))
	feed.Parent = core
	for _, corner in { Vector3.new(-1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(1, 0, 1) } do
		local base = Vector3.new(center.X + corner.X * 40, cy0 + 0.5, center.Z + corner.Z * 42)
		local height = center.Y - 18 - cy0
		Build.Decor({ Parent = lab, Name = "PylonBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 11, 11), CFrame = CFrame.new(base + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(36, 38, 50), Material = Enum.Material.Metal })
		Build.Pillar(lab, base, height, 4, metal, Enum.Material.Metal)
		for c = 1, 3 do
			Build.Decor({ Parent = lab, Name = "Coil", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7, 6, 6), CFrame = CFrame.new(base + Vector3.new(0, height - 2 - c * 2.4, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = cyan, Material = Enum.Material.Neon })
		end
		local tip = Build.Ball(lab, base + Vector3.new(0, height + 2, 0), 4, cyan, Enum.Material.Neon)
		tip.Name = "PylonTip"
		local shield = Build.Ball(lab, tip.Position, 6.5, cyan, Enum.Material.ForceField)
		shield.Name = "PylonShield"
		shield.Transparency = 0.2
		local emitter = Instance.new("Attachment")
		emitter.Name = "Emitter"
		emitter.Parent = tip
		for layer = 1, 2 do
			local beam = Instance.new("Beam")
			beam.Attachment0 = emitter
			beam.Attachment1 = feed
			beam:SetAttribute("From", emitter.Name)
			beam:SetAttribute("To", feed.Name)
			beam.FaceCamera = true
			beam.LightEmission = 1
			beam.LightInfluence = 0
			beam.Segments = 12
			beam.Texture = "rbxasset://textures/particles/smoke_main.dds"
			beam.TextureMode = Enum.TextureMode.Wrap
			if layer == 1 then
				beam.Width0, beam.Width1 = 2.2, 0.8
				beam.Color = ColorSequence.new(cyan, rgb(200, 150, 255))
				beam.Transparency = NumberSequence.new(0.3, 0.55)
				beam.TextureLength = 8
				beam.TextureSpeed = 1.2
			else
				beam.Width0, beam.Width1 = 0.5, 0.25
				beam.Color = ColorSequence.new(rgb(230, 250, 255), rgb(170, 230, 255))
				beam.Transparency = NumberSequence.new(0, 0.2)
				beam.TextureLength = 4
				beam.TextureSpeed = 3
			end
			beam.Parent = tip
		end
		local sparks = Instance.new("ParticleEmitter")
		sparks.Rate = 6
		sparks.Lifetime = NumberRange.new(0.3, 0.6)
		sparks.Speed = NumberRange.new(4, 8)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Size = NumberSequence.new(0.5, 0)
		sparks.Color = ColorSequence.new(rgb(220, 250, 255), cyan)
		sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparks.LightEmission = 1
		sparks.Parent = tip
	end
	for _, z in { cz0 + 2, cz1 - 2 } do
		for _, x in { cx0 + 20, (cx0 + cx1) / 2 + 10 } do
			local warning = glow("WarningLight", Vector3.new(3, 3, 1), CFrame.new(x, cy1 - 8, z), rgb(255, 40, 40))
			local light = Instance.new("PointLight")
			light.Color = rgb(255, 40, 40)
			light.Range = 30
			light.Brightness = 1.5
			light.Parent = warning
		end
	end
	lab.PrimaryPart = button
	lab.Parent = parent
end

local function buildSpawns(parent: Instance, areaId: number, zs: number, ze: number)
	local folder = Instance.new("Folder")
	folder.Name = "Spawns"
	folder.Parent = parent
	local rng = Random.new(areaId * 7919)
	local home = localGuardHome(areaId)
	local points: { Vector3 } = {}
	local attempts = 0
	while #points < map.DonutSpawnsPerArea and attempts < 2000 do
		attempts += 1
		-- Donuts spawn between the hub and the guard, at least 18 studs in front of him.
		local spread = Layout.AreaHalfWidth(areaId) - 18
		local candidate = Vector3.new(rng:NextNumber(-spread, spread), 0, rng:NextNumber(zs + Layout.SpawnStartMargin, ze - Layout.GuardBackOffset - Layout.SpawnGuardMargin))
		local ok = (candidate - home).Magnitude > 18
		if Areas.List[areaId].Lab then
			-- not on the edge of the pit down to the lab
			local px, pz = labPit(zs)
			ok = ok and (candidate - Vector3.new(px, 0, pz)).Magnitude > 20
		end
		for _, other in points do
			if (candidate - other).Magnitude < 17 then
				ok = false
				break
			end
		end
		if ok then
			table.insert(points, candidate)
		end
	end

	local area = Areas.List[areaId]
	for index, point in points do
		-- The nest/plate/pad the donut sits on gets fancier in later areas.
		local color, material, rim
		local fancy = if area.World == 1 then areaId else area.Index + 3
		if area.World == 2 then
			-- The Underworld: basalt stands with a glowing rim
			color, material, rim, fancy = rgb(42, 32, 30), Enum.Material.Basalt, area.Trim, 7
		elseif fancy <= 3 then
			color, material = rgb(170, 120, 65), Enum.Material.Grass
		elseif fancy <= 6 then
			color, material, rim = rgb(250, 250, 250), Enum.Material.SmoothPlastic, area.Trim
		else
			color, material, rim = rgb(25, 20, 40), Enum.Material.SmoothPlastic, area.Trim
		end
		Build.Decor({ Parent = folder, Name = "Nest", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 6.5, 6.5), CFrame = CFrame.new(point + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = color, Material = material })
		if rim then
			Build.Decor({ Parent = folder, Name = "NestRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 7.3, 7.3), CFrame = CFrame.new(point + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = rim, Material = if fancy > 6 then Enum.Material.Neon else Enum.Material.SmoothPlastic })
		end
		local spawnPoint = Build.Part({ Parent = folder, Name = "DonutSpawn", Size = Vector3.new(1, 0.2, 1), CFrame = CFrame.new(point + Vector3.new(0, 0.6, 0)), Transparency = 1, CanCollide = false, CanQuery = false })
		spawnPoint:SetAttribute("Area", areaId)
		spawnPoint:SetAttribute("Index", index)
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

local function buildArea(parent: Instance, area: Areas.Area)
	local zs, ze = Layout.AreaStart(area.Id), Layout.AreaEnd(area.Id)
	local half = Layout.AreaHalfWidth(area.Id)
	local folder = Instance.new("Folder")
	folder.Name = "Area" .. area.Id
	folder:SetAttribute("AreaId", area.Id)
	folder.Parent = parent

	if area.Lab then
		-- floor with a hole for the pit down to the lab
		local px, pz = labPit(zs)
		local hx0, hx1, hz0, hz1 = px - PIT_SIZE / 2, px + PIT_SIZE / 2, pz - PIT_SIZE / 2, pz + PIT_SIZE / 2
		Build.CheckerFloor(folder, -half, half, zs, hz0, map.TileSize, area.Floor, area.FloorMaterial)
		Build.CheckerFloor(folder, -half, half, hz1, ze, map.TileSize, area.Floor, area.FloorMaterial)
		Build.CheckerFloor(folder, -half, hx0, hz0, hz1, map.TileSize, area.Floor, area.FloorMaterial)
		Build.CheckerFloor(folder, hx1, half, hz0, hz1, map.TileSize, area.Floor, area.FloorMaterial)
		buildLab(folder, zs)
	else
		Build.CheckerFloor(folder, -half, half, zs, ze, map.TileSize, area.Floor, area.FloorMaterial)
	end

	local t, h = 4, map.LaneWallHeight
	-- Wider than the area before it: close the gap between the two lanes' walls
	local before = if area.Index > 1 then Areas.ByWorld[area.World][area.Index - 1] else nil
	local beforeHalf = if before then Layout.AreaHalfWidth(before.Id) else half
	if half > beforeHalf then
		for _, side in { -1, 1 } do
			local from = if side < 0 then -(half + t) else beforeHalf + t
			Build.CheckerWall(folder, Vector3.new(from, 0, zs + t / 2), Vector3.new(1, 0, 0), half - beforeHalf, h, t, area.Wall, area.WallMaterial, 20)
		end
	end
	for _, side in { -1, 1 } do
		Build.CheckerWall(folder, Vector3.new(side * (half + t / 2), 0, zs), Vector3.new(0, 0, 1), ze - zs, h, t, area.Wall, area.WallMaterial, 20)
		Build.Part({ Parent = folder, Name = "WallTop", Size = Vector3.new(t + 1, 2, ze - zs), Position = Vector3.new(side * (half + t / 2), h + 1, (zs + ze) / 2), Color = area.Trim, Material = area.TrimMaterial })
	end
	-- Coloured line marking the start of the area
	Build.Part({ Parent = folder, Name = "AreaLine", Size = Vector3.new(half * 2, 0.2, 2), Position = Vector3.new(0, 0.1, zs + 1), Color = area.Trim, Material = if area.Id > 1 then Enum.Material.Neon else Enum.Material.SmoothPlastic, CanCollide = false })

	buildArch(folder, area, zs)
	buildGuardBed(folder, area.Id)
	buildSpawns(folder, area.Id, zs, ze)

	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = folder
	Decor.BuildTheme(area.Theme, decor, zs, ze, Random.new(area.Id * 104729))
	if not area.HalfWidth then
		widenDecor(decor, half)
	end

	-- Close the lane after the last area of each world
	if area.Index == #Areas.ByWorld[area.World] then
		Build.CheckerWall(folder, Vector3.new(-half - t, 0, ze + t / 2), Vector3.new(1, 0, 0), half * 2 + t * 2, h, t, area.Wall, area.WallMaterial, 20)
	end

	-- Move it to its world's lane
	local offset = Layout.WorldOffset(area.World)
	if offset ~= 0 then
		local shift = Vector3.new(offset, 0, 0)
		for _, part in folder:GetDescendants() do
			if part:IsA("BasePart") then
				part.CFrame += shift
			end
		end
	end
end

local function buildLane(parent: Folder)
	local lane = parent:FindFirstChild("Lane")
	if not lane then
		lane = Instance.new("Folder")
		lane.Name = "Lane"
		lane.Parent = parent
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
-- Donut stands: rows of 4 starting at the FRONT of the plot (see Layout.SlotOffset). Stands you
-- haven't unlocked yet are shown see-through by PlotService.
-- A base's pen (like Steal an Egg): a patch of checker ground - one tile per donut - inside a low
-- fence you can hop over, with a gate in the middle of the front. Rebuilt (PlotService) whenever
-- the base gets bigger; `slots` is how many donuts it holds (Layout.PenGrid).
function MapBuilder.BuildPen(plot: Model, slots: number)
	local old = plot:FindFirstChild("Pen")
	if old then
		old:Destroy()
	end
	local cf = Layout.PlotCFrame(plot:GetAttribute("PlotIndex") :: number, (plot:GetAttribute("WorldId") :: number?) or 1)
	local fh = Layout.PlotFloorHeight
	local classic = Config.Skins[1]
	local columns, rows, width, depth = Layout.PenGrid(slots)
	local cell = Config.Plots.CellSize
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
			skinned(role, {
				Parent = floor, Name = "Tile",
				Size = Vector3.new(cell, fh + 0.5, cell),
				CFrame = at(-width / 2 + cell * (column + 0.5), (fh - 0.5) / 2, front + cell * (row + 0.5)),
				Color = if role == "Floor" then classic.Floor else classic.FloorAlt,
				Material = classic.FloorMaterial,
			})
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
	local gate = 8 -- half the gate's width
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
	-- Big corner posts with round caps, and a gate arch
	for _, x in { -hw, hw } do
		for _, z in { z0, z1 } do
			skinned("Trim", { Parent = fence, Name = "CornerPost", Size = Vector3.new(1.8, height + 2, 1.8), CFrame = at(x, fh + (height + 2) / 2, z), Color = classic.Trim, Material = classic.TrimMaterial })
			skinned("Pedestal", { Parent = fence, Name = "CornerCap", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.4, CFrame = at(x, fh + height + 2.6, z), Color = classic.Pedestal, Material = classic.PedestalMaterial })
		end
	end
	local archHeight = 11
	for _, side in { -1, 1 } do
		skinned("Trim", { Parent = fence, Name = "GatePost", Size = Vector3.new(2, archHeight, 2), CFrame = at(side * gate, fh + archHeight / 2, z0), Color = classic.Trim, Material = classic.TrimMaterial })
	end
	skinned("Pedestal", { Parent = fence, Name = "GateArch", Size = Vector3.new(gate * 2 + 2, 1.6, 2.2), CFrame = at(0, fh + archHeight + 0.8, z0), Color = classic.Pedestal, Material = classic.PedestalMaterial })
	pen.Parent = plot
end

function buildPlot(parent: Instance, plotIndex: number, worldId: number)
	local cf = Layout.PlotCFrame(plotIndex, worldId)
	local d, fh = Layout.PlotDepth, Layout.PlotFloorHeight

	local plot = Instance.new("Model")
	plot.Name = "Plot" .. plotIndex
	plot:SetAttribute("PlotIndex", plotIndex)
	plot:SetAttribute("WorldId", worldId)

	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	local hd = d / 2

	-- Anchors used by other services (the sign moves to the back of the pen as it grows)
	Build.Part({ Parent = plot, Name = "Spawn", Size = Vector3.new(4, 1, 4), CFrame = at(0, fh + 0.5, Layout.PenFront + 8), Transparency = 1, CanCollide = false, CanQuery = false })
	Build.Part({ Parent = plot, Name = "SignAnchor", Size = Vector3.new(1, 1, 1), CFrame = at(0, fh + 20, Layout.PenFront + 20), Transparency = 1, CanCollide = false, CanQuery = false })
	Build.Part({ Parent = plot, Name = "TreadmillAnchor", Size = Vector3.new(1, 1, 1), CFrame = at(-17, 0, -hd - 12), Transparency = 1, CanCollide = false, CanQuery = false })
	Build.Part({ Parent = plot, Name = "PodiumAnchor", Size = Vector3.new(1, 1, 1), CFrame = at(17, 0, -hd - 11), Transparency = 1, CanCollide = false, CanQuery = false })
	Build.Part({ Parent = plot, Name = "IncubatorAnchor", Size = Vector3.new(1, 1, 1), CFrame = at(0, 0, -hd - 22), Transparency = 1, CanCollide = false, CanQuery = false })

	local skinFx = Instance.new("Folder")
	skinFx.Name = "SkinFX"
	skinFx.Parent = plot

	plot.PrimaryPart = plot:FindFirstChild("Spawn") :: BasePart
	MapBuilder.BuildPen(plot, Config.Plots.Sizes[1].Slots)
	plot.Parent = parent
end

local function buildPlots(parent: Folder)
	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = parent
	for i = 1, Config.Plots.Count do
		buildPlot(plots, i, 1)
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
			refreshPortalSigns(hub)
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
		buildLane(existing) -- adds any areas that are missing (new worlds)
		buildWorlds(existing) -- adds any world hubs that are missing
		optimize(existing)
		mapFolder = existing
		return existing
	end
	-- No map, or one saved by an older version of the game: build it all from scratch. (Version 11:
	-- bases are open pens and there are 6 of them, every hub is bigger, every area is longer and
	-- wider - nothing of an older map fits any more.)
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Map"
	folder:SetAttribute("MapVersion", MAP_VERSION)
	buildHub(folder)
	buildPlots(folder)
	buildLane(folder)
	buildWorlds(folder)
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

-- A base plot in a world's hub (world 1 = the main hub).
function MapBuilder.GetPlot(index: number, worldId: number?): Model
	local world = worldId or 1
	if world == 1 then
		return MapBuilder.Get():WaitForChild("Plots"):WaitForChild("Plot" .. index) :: Model
	end
	return MapBuilder.Get():WaitForChild("Worlds"):WaitForChild("World" .. world):WaitForChild("Plots"):WaitForChild("Plot" .. index) :: Model
end

function MapBuilder.GetArea(index: number): Folder
	return MapBuilder.Get():WaitForChild("Lane"):WaitForChild("Area" .. index) :: Folder
end

function MapBuilder.GetHub(): Folder
	return MapBuilder.Get():WaitForChild("Hub") :: Folder
end

-- Every portal trigger part (hub portals + the portal home in each world).
function MapBuilder.GetPortals(): { BasePart }
	local triggers = {}
	for _, part in MapBuilder.Get():GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("PortalTrigger") then
			table.insert(triggers, part)
		end
	end
	return triggers
end

return MapBuilder
