--[[
	Layout: pure geometry helpers for the map (shared by server and client).

	      +Z  (the lane: biome 1 .. the last biome, The Black Hole)
	       ^
	  -----|-----------  Z = SafeZoneZ  (safe zone line, the lobby is open to the lane)
	  [6] [ base ]  |      |  [ base ] [7]   one base either side of the lane's entrance, facing in
	                  (o)                     (o): the round plaza - spawn, sell stall, Cosmic Forge
	  [3]  [4]  [1]  [2]  [5]                 a row of 5 bases side by side, facing the lane
	  ======== boards ========                the leaderboards high on the back wall

	Each biome's Domer sleeps in a back corner (GuardHome) with the biome's donut boxes around him
	(BoxSpots). A biome's entrance (AreaStart) has a speed gate: players slower than its
	RecommendedSpeed can't walk in.
]]

local Config = require(script.Parent.Config)
local Areas = require(script.Parent.Areas)

local Layout = {}

local map = Config.Map

--------------------------------------------------------------------------------
-- Biomes
--------------------------------------------------------------------------------
-- (There's one lane now, at X = 0. Kept so callers that pass a world still work.)
function Layout.WorldOffset(_worldId: number?): number
	return 0
end

function Layout.WorldAt(_position: Vector3): number
	return 1
end

function Layout.AreaLength(areaId: number): number
	return Areas.List[areaId].Length or map.AreaLength
end

function Layout.AreaHalfWidth(areaId: number): number
	return Areas.List[areaId].HalfWidth or map.LaneHalfWidth
end

-- Z where a biome starts / ends.
local startCache: { [number]: number } = {}
function Layout.AreaStart(areaId: number): number
	local cached = startCache[areaId]
	if cached then
		return cached
	end
	local z = map.SafeZoneZ
	for id = 1, areaId - 1 do
		z += Layout.AreaLength(id)
	end
	startCache[areaId] = z
	return z
end

function Layout.AreaEnd(areaId: number): number
	return Layout.AreaStart(areaId) + Layout.AreaLength(areaId)
end

function Layout.LaneEnd(_worldId: number?): number
	return Layout.AreaEnd(#Areas.List)
end

-- 0 = the safe lobby, otherwise the biome id (1..#Areas.List).
function Layout.AreaAt(position: Vector3): number
	if position.Z < map.SafeZoneZ then
		return 0
	end
	for _, area in Areas.List do
		if position.Z < Layout.AreaEnd(area.Id) then
			return area.Id
		end
	end
	return #Areas.List
end

function Layout.IsSafe(position: Vector3): boolean
	return position.Z < map.SafeZoneZ
end

-- X range a guard may chase in (the lane minus the wall decorations).
function Layout.LaneLimits(areaId: number): (number, number)
	local limit = Layout.AreaHalfWidth(areaId) - 8
	return -limit, limit
end

-- Domer sleeps in a back corner of his biome (right-hand corner in odd biomes, left in even ones),
-- facing the lobby. His boxes sit in an arc in front of him.
Layout.GuardCornerInset = 46
function Layout.GuardSide(areaId: number): number
	return if areaId % 2 == 1 then 1 else -1
end

function Layout.GuardHome(areaId: number): Vector3
	local x = Layout.GuardSide(areaId) * (Layout.AreaHalfWidth(areaId) - Layout.GuardCornerInset)
	return Vector3.new(x, 0, Layout.AreaEnd(areaId) - Layout.GuardCornerInset)
end

-- Where the biome's boxes sit (on the ground), in front of and beside Domer.
Layout.BoxRadius = 34
function Layout.BoxSpots(areaId: number): { Vector3 }
	local home = Layout.GuardHome(areaId)
	local side = Layout.GuardSide(areaId)
	-- facing the lobby, turned 40 degrees towards the middle of the lane
	local facing = CFrame.Angles(0, side * math.rad(40), 0):VectorToWorldSpace(Vector3.new(0, 0, -1))
	local spots = {}
	local count = Config.Boxes.PerBiome
	for i = 1, count do
		local angle = math.rad(-70 + 140 * (i - 1) / math.max(count - 1, 1))
		local dir = CFrame.Angles(0, angle, 0):VectorToWorldSpace(facing)
		table.insert(spots, home + dir * Layout.BoxRadius)
	end
	return spots
end

-- Start of a biome (Teleporter pass), facing into it.
function Layout.AreaArrival(areaId: number): CFrame
	local z = Layout.AreaStart(areaId) + 10
	return CFrame.lookAt(Vector3.new(0, 3.5, z), Vector3.new(0, 3.5, z + 10))
end

-- Where you land in the lobby: the spawn, at the front of the walkway just behind the safe-zone
-- line, facing the lane - a few steps from the first biome, so a new player is in the action
-- within seconds of joining.
Layout.SpawnBehindLine = 24
function Layout.LobbyArrival(): CFrame
	local z = map.SafeZoneZ - Layout.SpawnBehindLine
	return CFrame.lookAt(Vector3.new(0, 3.5, z), Vector3.new(0, 3.5, z + 10))
end

-- Where the lobby's leaderboards hang: on the back wall, up above the row of bases' shops.
function Layout.LeaderboardZ(): number
	return map.SafeZoneZ - map.HubDepth + 1.5
end
Layout.LeaderboardBottom = 22 -- how high the bottom of the boards is (clear of the shops' roofs)

-- The little round plaza just inside the lane's entrance, between the two front bases: the sell
-- stall and the Cosmic Forge either side of it.
Layout.PlazaRadius = 44
function Layout.PlazaCenter(): Vector3
	return Vector3.new(0, 0, map.SafeZoneZ - 70)
end

-- The Cosmic Forge (Config.CosmicDonut): on the plaza, left of the spawn, facing it.
function Layout.CosmicForgeCFrame(): CFrame
	local center = Layout.PlazaCenter()
	return CFrame.lookAt(center + Vector3.new(-28, 0, 0), center)
end

-- The sell stall: on the plaza, right of the spawn, facing it.
function Layout.SellStallCFrame(): CFrame
	local center = Layout.PlazaCenter()
	return CFrame.lookAt(center + Vector3.new(28, 0, 0), center)
end

--------------------------------------------------------------------------------
-- Plots: 7 bases. Two (1 and 2) either side of the lane's entrance, facing into the lobby; behind
-- them a row of five side by side across the lobby (3 in the middle, then 4 / 5, then 6 / 7 at the
-- ends), facing the lane. (New players get the lowest free number: the ones nearest the lane.)
--
-- A base is a donut shop with an open pen in front of it (like Steal an Egg): a fenced patch of
-- ground with a low gate at the front, where the donuts roam and boxes wait to open. The pen grows
-- a little with every base upgrade (Config.Plots.Sizes): its front stays put and it grows sideways
-- and backwards, with the shop moving back behind it.
--------------------------------------------------------------------------------
Layout.PlotWidth = 150 -- plot space X (sideways)
Layout.PlotDepth = 130 -- plot space Z (front to back)
Layout.PlotSpacing = 156 -- the row's bases are this far apart (centre to centre)
Layout.FrontBaseGap = 6 -- the two front bases stand this far from the lane's walls
Layout.RowFrontZ = 190 -- the row's front edge, this far behind the safe-zone line
Layout.PlotFloorHeight = 0.4
Layout.PenFront = -Layout.PlotDepth / 2 + 14 -- (plot space) the pen's front fence, where the gate is
Layout.ShopDepth = 22 -- the donut shop behind the pen
Layout.GateHalfWidth = 12 -- the gap in the pen's front fence (24 studs: plenty of room to run in)
-- (plot space) how far either side of the pen's middle the treadmill, incubator and podium stand:
-- clear of even the biggest pen. A treadmill reaches TreadmillReach studs either way along its belt
-- (art/treadmills keeps every design within it).
Layout.TreadmillReach = 10.2
Layout.SideItemsX = Layout.PlotWidth / 2 - 9
Layout.PenBorder = 2 -- the trim round a pen, outside its fence
Layout.RowCount = 5

-- The leaderboards: a row edge to edge in the middle of the back wall (high up, above the row of
-- bases' shops). Each board's middle X, left to right, and its size (1: full size, 31 wide).
Layout.LeaderboardSpacing = 31
function Layout.LeaderboardSpots(count: number): { { X: number, Scale: number } }
	local room = (map.HubHalfWidth - 4) * 2
	local spacing = math.min(Layout.LeaderboardSpacing, room / math.max(count, 1))
	local spots = {}
	for index = 1, count do
		table.insert(spots, { X = (index - (count + 1) / 2) * spacing, Scale = spacing / Layout.LeaderboardSpacing })
	end
	return spots
end

-- (plot space) How far back a base's things reach at its biggest (the owner's too): the back of
-- the donut shop's roof behind the biggest pen.
function Layout.PlotBackReach(): number
	local most = math.max(Config.Plots.Sizes[#Config.Plots.Sizes].Slots, Config.Admin.MaxSlots)
	local _, depth = Layout.PenSize(most)
	return Layout.PenFront + depth + 3 + Layout.ShopDepth + 1.5
end

-- Z of the middle of the row of five.
function Layout.RowZ(): number
	return map.SafeZoneZ - Layout.RowFrontZ - Layout.PlotWidth / 2
end

-- Which slot in the row (1 = far left .. 5 = far right) a row base stands in.
local ROW_SLOT = { [3] = 3, [4] = 2, [5] = 4, [6] = 1, [7] = 5 }

function Layout.PlotCFrame(plotIndex: number, _worldId: number?): CFrame
	-- every base's entrance faces the middle of the lobby: the ones off to the sides turn sideways
	-- (their plot's depth runs along X then, its width along Z)
	if plotIndex <= 2 then
		-- either side of the lane's entrance, right by its walls, facing in towards the plaza
		local side = if plotIndex == 1 then -1 else 1
		local x = side * (map.LaneHalfWidth + 4 + Layout.FrontBaseGap + Layout.PlotDepth / 2)
		local center = Vector3.new(x, 0, map.SafeZoneZ - 4 - Layout.PlotWidth / 2)
		return CFrame.lookAt(center, center + Vector3.new(-side, 0, 0))
	end
	-- the row, side by side: the middle one faces the lane, the rest face the middle
	local slot = ROW_SLOT[plotIndex] or 3
	local x = (slot - (Layout.RowCount + 1) / 2) * Layout.PlotSpacing
	local center = Vector3.new(x, 0, Layout.RowZ())
	if math.abs(x) < 1e-6 then
		return CFrame.lookAt(center, center + Vector3.new(0, 0, 1))
	end
	return CFrame.lookAt(center, center + Vector3.new(-math.sign(x), 0, 0))
end

-- The pen for a base with room for `slots` donuts: about CellSize x CellSize per donut, a little
-- wider than deep, so every upgrade makes it a bit bigger. Returns width (plot X), depth (plot Z).
function Layout.PenSize(slots: number): (number, number)
	local cell = Config.Plots.CellSize
	local count = math.max(slots, 1)
	local across = math.sqrt(count * 1.4)
	local width = math.floor(cell * across * 2 + 0.5) / 2
	local depth = math.floor(cell * count / across * 2 + 0.5) / 2
	return width, depth
end

-- How the pen is split into one patch per donut: columns and rows.
function Layout.PenGrid(slots: number): (number, number, number, number)
	local count = math.max(slots, 1)
	local columns = math.max(1, math.floor(math.sqrt(count * 1.4) + 0.5))
	local rows = math.ceil(count / columns)
	local width, depth = Layout.PenSize(slots)
	return columns, rows, width, depth
end

-- The pen's middle (plot space) and its size (X, Z).
function Layout.PenBounds(slots: number): (Vector3, Vector2)
	local width, depth = Layout.PenSize(slots)
	return Vector3.new(0, 0, Layout.PenFront + depth / 2), Vector2.new(width, depth)
end

-- Where donut (or box) number `slotIndex` lives in the pen (plot space, on the ground): the middle
-- of its patch. Patches fill the pen from the front row (by the gate) to the back.
function Layout.SlotHome(slotIndex: number, slots: number): Vector3
	local columns, rows, width, depth = Layout.PenGrid(slots)
	local index = slotIndex - 1
	local column = index % columns
	local row = index // columns
	-- (rows alternate direction so neighbours along the fill order stay close)
	if row % 2 == 1 then
		column = columns - 1 - column
	end
	local cellX, cellZ = width / columns, depth / rows
	return Vector3.new(-width / 2 + cellX * (column + 0.5), 0, Layout.PenFront + cellZ * (row + 0.5))
end

-- Is `position` inside a base's pen (`slots`: how many donuts it holds)? `margin` widens it.
function Layout.IsInPlot(plotIndex: number, position: Vector3, _worldId: number?, slots: number?, margin: number?): boolean
	local localPos = Layout.PlotCFrame(plotIndex):PointToObjectSpace(position)
	local center, size = Layout.PenBounds(slots or Config.Plots.Sizes[1].Slots)
	local m = margin or 2
	return math.abs(localPos.X - center.X) <= size.X / 2 + m
		and math.abs(localPos.Z - center.Z) <= size.Y / 2 + m
		and localPos.Y > -5
		and localPos.Y < 60
end

-- The upgrade sign, just outside the pen's gate (plot space).
function Layout.UpgradeSignPosition(): Vector3
	return Vector3.new(Layout.GateHalfWidth + 7, 0, Layout.PenFront - 7)
end

return Layout
