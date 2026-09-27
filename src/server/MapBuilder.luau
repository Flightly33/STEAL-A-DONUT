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
		Lane/AreaN (+ Spawns/DonutSpawn, GuardHome), Hub/ShopStall/PromptPart and Hub/Leaderboards/Board_X/Screen.
]]

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
local Decor = require(script.Parent.Decor)

local MapBuilder = {}

local rgb = Color3.fromRGB
local map = Config.Map
local HUB_GREEN = { rgb(96, 172, 58), rgb(84, 158, 50) }
local WALL_BROWN = { rgb(176, 116, 66), rgb(160, 104, 58) }

local mapFolder: Folder? = nil

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

local function buildShop(parent: Instance)
	local shop = Instance.new("Model")
	shop.Name = "ShopStall"
	local origin = CFrame.lookAt(Vector3.new(-88, 0, -232), Vector3.new(-88, 0, -200))
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
		Build.Part({ Parent = shop, Name = "Awning", Size = Vector3.new(2.2, 0.5, 10), CFrame = at(-8.8 + i * 2.2, 12.3, -0.5) * CFrame.Angles(math.rad(-12), 0, 0), Color = if i % 2 == 0 then rgb(255, 230, 40) else rgb(255, 255, 255), Material = Enum.Material.SmoothPlastic })
	end
	-- Glowing circle to stand in
	Build.Part({ Parent = shop, Name = "Glow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 14, 14), CFrame = at(0, 0.08, -9) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(255, 230, 40), Material = Enum.Material.Neon, Transparency = 0.45, CanCollide = false })
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
	Build.Text(sign, "🛒 SHOP", { TextColor3 = rgb(255, 230, 40), TextStrokeColor3 = rgb(90, 50, 0) })
	-- A donut shopkeeper on the counter
	local keeper = DonutModel.Build(Donuts.List[1], { Scale = 0.9, NoEffects = true })
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
	for index, board in Config.Leaderboards.Boards do
		local x = -54 + (index - 1) * 33
		local z = -250
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

local function buildHub(parent: Folder)
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = parent

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
		Build.Part({ Parent = walls, Name = "WallTop", Position = info[1], Size = info[2], Color = rgb(78, 165, 52), Material = Enum.Material.Grass })
	end

	buildSafeZoneLine(hub)
	buildEntranceGate(hub)
	buildShop(hub)
	buildLeaderboards(hub)

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
--------------------------------------------------------------------------------
local function buildArch(parent: Instance, area: Areas.Area, zs: number)
	local half = map.LaneHalfWidth
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
	local guardSpeed = math.floor(Economy.GuardWalkSpeed(area.Id))
	local rec = if area.RecommendedSpeed > 0 then "⚡ Recommended Speed: " .. Format.Number(area.RecommendedSpeed) else "⚡ Any speed works here!"
	Build.Text(gui, `😴 {Config.Guard.Name} speed: {guardSpeed}   •   {rec}`, { Size = UDim2.fromScale(1, 0.25), TextColor3 = rgb(255, 230, 90), Font = Enum.Font.FredokaOne, LayoutOrder = 3 })
	arch.Parent = parent
end

local function buildGuardBed(parent: Instance, areaId: number)
	local home = Layout.GuardHome(areaId)
	local bed = Instance.new("Model")
	bed.Name = "GuardBed"
	-- Picnic blanket
	for i = 0, 3 do
		for j = 0, 2 do
			Build.Decor({ Parent = bed, Name = "Blanket", Size = Vector3.new(4, 0.25, 4), Position = home + Vector3.new(-6 + i * 4, 0.13, -4 + j * 4), Color = if (i + j) % 2 == 0 then rgb(220, 40, 40) else rgb(255, 255, 255), Material = Enum.Material.Fabric })
		end
	end
	-- Stack of empty pink donut boxes
	for n = 0, 3 do
		Build.Decor({ Parent = bed, Name = "DonutBox", Size = Vector3.new(4, 1, 4), CFrame = CFrame.new(home + Vector3.new(11, 0.5 + n * 1.02, 3)) * CFrame.Angles(0, n * 0.2, 0), Color = rgb(255, 150, 200), Material = Enum.Material.SmoothPlastic })
	end
	local marker = Build.Part({ Parent = bed, Name = "GuardHome", Size = Vector3.new(2, 1, 2), CFrame = CFrame.lookAt(home + Vector3.new(0, 0.5, 0), home + Vector3.new(0, 0.5, -10)), Transparency = 1, CanCollide = false, CanQuery = false })
	marker:SetAttribute("Area", areaId)
	bed.Parent = parent
end

local function buildSpawns(parent: Instance, areaId: number, zs: number, ze: number)
	local folder = Instance.new("Folder")
	folder.Name = "Spawns"
	folder.Parent = parent
	local rng = Random.new(areaId * 7919)
	local home = Layout.GuardHome(areaId)
	local points: { Vector3 } = {}
	local attempts = 0
	while #points < map.DonutSpawnsPerArea and attempts < 2000 do
		attempts += 1
		-- Donuts spawn between the hub and the guard, at least 18 studs in front of him.
		local candidate = Vector3.new(rng:NextNumber(-42, 42), 0, rng:NextNumber(zs + 20, ze - Layout.GuardBackOffset - 18))
		local ok = (candidate - home).Magnitude > 18
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
		if areaId <= 3 then
			color, material = rgb(170, 120, 65), Enum.Material.Grass
		elseif areaId <= 6 then
			color, material, rim = rgb(250, 250, 250), Enum.Material.SmoothPlastic, area.Trim
		else
			color, material, rim = rgb(25, 20, 40), Enum.Material.SmoothPlastic, area.Trim
		end
		Build.Decor({ Parent = folder, Name = "Nest", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 6.5, 6.5), CFrame = CFrame.new(point + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = color, Material = material })
		if rim then
			Build.Decor({ Parent = folder, Name = "NestRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 7.3, 7.3), CFrame = CFrame.new(point + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = rim, Material = if areaId > 6 then Enum.Material.Neon else Enum.Material.SmoothPlastic })
		end
		local spawnPoint = Build.Part({ Parent = folder, Name = "DonutSpawn", Size = Vector3.new(1, 0.2, 1), CFrame = CFrame.new(point + Vector3.new(0, 0.6, 0)), Transparency = 1, CanCollide = false, CanQuery = false })
		spawnPoint:SetAttribute("Area", areaId)
		spawnPoint:SetAttribute("Index", index)
	end
end

local function buildArea(parent: Instance, area: Areas.Area)
	local zs, ze = Layout.AreaStart(area.Id), Layout.AreaEnd(area.Id)
	local half = map.LaneHalfWidth
	local folder = Instance.new("Folder")
	folder.Name = "Area" .. area.Id
	folder:SetAttribute("AreaId", area.Id)
	folder.Parent = parent

	Build.CheckerFloor(folder, -half, half, zs, ze, map.TileSize, area.Floor, area.FloorMaterial)

	local t, h = 4, map.LaneWallHeight
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

	-- Close the lane after the last area
	if area.Id == #Areas.List then
		Build.CheckerWall(folder, Vector3.new(-half - t, 0, ze + t / 2), Vector3.new(1, 0, 0), half * 2 + t * 2, h, t, area.Wall, area.WallMaterial, 20)
	end
end

local function buildLane(parent: Folder)
	local lane = Instance.new("Folder")
	lane.Name = "Lane"
	lane.Parent = parent
	for _, area in Areas.List do
		buildArea(lane, area)
		task.wait() -- spread the work over a few frames
	end
end

--------------------------------------------------------------------------------
-- Plots
--------------------------------------------------------------------------------
local function buildPlot(parent: Instance, plotIndex: number)
	local cf = Layout.PlotCFrame(plotIndex)
	local w, d, fh = Layout.PlotWidth, Layout.PlotDepth, Layout.PlotFloorHeight
	local classic = Config.Skins[1]

	local plot = Instance.new("Model")
	plot.Name = "Plot" .. plotIndex
	plot:SetAttribute("PlotIndex", plotIndex)

	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end

	local function skinned(role: string, props): BasePart
		props.Parent = props.Parent or plot
		local part = Build.Part(props)
		part:SetAttribute("SkinRole", role)
		return part
	end

	-- Floor (checker, raised slightly above the hub)
	local floor = Instance.new("Folder")
	floor.Name = "Floor"
	floor.Parent = plot
	local tile = 14
	for ix = 0, w / tile - 1 do
		for iz = 0, d / tile - 1 do
			local role = if (ix + iz) % 2 == 0 then "Floor" else "FloorAlt"
			skinned(role, {
				Parent = floor, Name = "Tile",
				Size = Vector3.new(tile, fh + 0.5, tile),
				CFrame = at(-w / 2 + tile / 2 + ix * tile, (fh - 0.5) / 2, -d / 2 + tile / 2 + iz * tile),
				Color = if role == "Floor" then classic.Floor else classic.FloorAlt,
				Material = classic.FloorMaterial,
			})
		end
	end

	-- Fence with an opening at the front
	local fence = Instance.new("Folder")
	fence.Name = "Fence"
	fence.Parent = plot
	local fenceHeight = 5
	local function fenceLine(from: Vector3, to: Vector3)
		local length = (to - from).Magnitude
		local dir = (to - from).Unit
		local posts = math.max(1, math.floor(length / 7))
		for i = 0, posts do
			local p = from + dir * (length * i / posts)
			skinned("Fence", { Parent = fence, Name = "Post", Size = Vector3.new(1.2, fenceHeight + 1, 1.2), CFrame = at(p.X, fh + (fenceHeight + 1) / 2, p.Z), Color = classic.Fence, Material = classic.FenceMaterial })
			skinned("Trim", { Parent = fence, Name = "PostCap", Size = Vector3.new(1.5, 0.4, 1.5), CFrame = at(p.X, fh + fenceHeight + 1.2, p.Z), Color = classic.Trim, Material = classic.TrimMaterial })
		end
		local mid = (from + to) / 2
		for _, y in { 1.8, 4 } do
			local rail = CFrame.lookAt(Vector3.new(mid.X, 0, mid.Z), Vector3.new(to.X, 0, to.Z))
			skinned("Fence", { Parent = fence, Name = "Rail", Size = Vector3.new(0.5, 0.7, length), CFrame = cf * rail * CFrame.new(0, fh + y, 0), Color = classic.Fence, Material = classic.FenceMaterial })
		end
	end
	local hw, hd, gap = w / 2, d / 2, 9
	fenceLine(Vector3.new(-hw, 0, hd), Vector3.new(hw, 0, hd)) -- back
	fenceLine(Vector3.new(-hw, 0, -hd), Vector3.new(-hw, 0, hd)) -- left
	fenceLine(Vector3.new(hw, 0, -hd), Vector3.new(hw, 0, hd)) -- right
	fenceLine(Vector3.new(-hw, 0, -hd), Vector3.new(-gap, 0, -hd)) -- front left
	fenceLine(Vector3.new(gap, 0, -hd), Vector3.new(hw, 0, -hd)) -- front right

	-- Donut pedestals: 3 rows x 4 columns in the back of the plot
	local slots = Instance.new("Folder")
	slots.Name = "Slots"
	slots.Parent = plot
	local columns = { -19.5, -6.5, 6.5, 19.5 }
	local rows = { 7, 23, 39 }
	local index = 0
	for _, z in rows do
		for _, x in columns do
			index += 1
			if index > Config.Plots.SlotsPerPlot then
				break
			end
			local pedestal = skinned("Pedestal", {
				Parent = slots, Name = "Slot" .. index,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1, 7.5, 7.5),
				CFrame = at(x, fh + 0.5, z) * CFrame.Angles(0, 0, math.pi / 2),
				Color = classic.Pedestal, Material = classic.PedestalMaterial,
			})
			pedestal:SetAttribute("SlotIndex", index)
			-- Where the donut stands (top of pedestal, facing out of the plot)
			pedestal:SetAttribute("Surface", at(x, fh + 1, z))
		end
	end

	-- Anchors used by other services
	Build.Part({ Parent = plot, Name = "Spawn", Size = Vector3.new(4, 1, 4), CFrame = at(0, fh + 0.5, -hd + 12), Transparency = 1, CanCollide = false, CanQuery = false })
	Build.Part({ Parent = plot, Name = "SignAnchor", Size = Vector3.new(1, 1, 1), CFrame = at(0, fh + 20, hd - 6), Transparency = 1, CanCollide = false, CanQuery = false })
	Build.Part({ Parent = plot, Name = "TreadmillAnchor", Size = Vector3.new(1, 1, 1), CFrame = at(-17, 0, -hd - 12), Transparency = 1, CanCollide = false, CanQuery = false })
	Build.Part({ Parent = plot, Name = "PodiumAnchor", Size = Vector3.new(1, 1, 1), CFrame = at(17, 0, -hd - 11), Transparency = 1, CanCollide = false, CanQuery = false })

	local skinFx = Instance.new("Folder")
	skinFx.Name = "SkinFX"
	skinFx.Parent = plot

	plot.PrimaryPart = plot:FindFirstChild("Spawn") :: BasePart
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
	-- Easy on the eyes: lower sun for longer shadows, darker ambient so shadows actually read,
	-- slightly reduced exposure, gentle colour grading and very little bloom.
	Lighting.GlobalShadows = true
	Lighting.ClockTime = 15.3
	Lighting.Brightness = 1.8
	Lighting.ExposureCompensation = -0.15
	Lighting.ShadowSoftness = 0.2
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.OutdoorAmbient = rgb(95, 97, 108)
	Lighting.Ambient = rgb(78, 80, 92)
	local atmosphere = ensure("Atmosphere", "Atmosphere") :: Atmosphere
	atmosphere.Density = 0.32
	atmosphere.Haze = 1
	atmosphere.Glare = 0
	atmosphere.Color = rgb(199, 214, 234)
	atmosphere.Decay = rgb(106, 112, 125)
	local tint = ensure("ColorCorrectionEffect", "AreaTint") :: ColorCorrectionEffect
	tint.Brightness = -0.03
	tint.Saturation = -0.08
	tint.Contrast = 0.12
	tint.TintColor = rgb(255, 248, 238)
	local bloom = ensure("BloomEffect", "Bloom") :: BloomEffect
	bloom.Intensity = 0.12
	bloom.Size = 18
	bloom.Threshold = 2.2
	local sunRays = ensure("SunRaysEffect", "SunRays") :: SunRaysEffect
	sunRays.Intensity = 0.03
	sunRays.Spread = 0.6
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------
function MapBuilder.Build(): Folder
	setupLighting()
	local existing = workspace:FindFirstChild("Map")
	if existing and existing:IsA("Folder") then
		mapFolder = existing
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "Map"
	buildHub(folder)
	buildPlots(folder)
	buildLane(folder)
	folder.Parent = workspace
	mapFolder = folder
	return folder
end

function MapBuilder.Get(): Folder
	assert(mapFolder, "MapBuilder.Build() has not run yet")
	return mapFolder :: Folder
end

function MapBuilder.GetPlot(index: number): Model
	return MapBuilder.Get():WaitForChild("Plots"):WaitForChild("Plot" .. index) :: Model
end

function MapBuilder.GetArea(index: number): Folder
	return MapBuilder.Get():WaitForChild("Lane"):WaitForChild("Area" .. index) :: Folder
end

function MapBuilder.GetHub(): Folder
	return MapBuilder.Get():WaitForChild("Hub") :: Folder
end

return MapBuilder
