--[[
	Layout: pure geometry helpers for the map (shared by server and client).

	      +Z  (the lane: biome 1 .. the last biome, The Black Hole)
	       ^
	  -----|-----------  Z = SafeZoneZ  (safe zone line, the lobby is open to the lane)
	  [1] | ||   || | [2]       two bases down each side, facing a walkway down the middle
	  [3] | || (o) || | [4]       (o): a little round plaza in the middle - the spawn, the sell
	  [5][6]  ||   ||                  stall and the Cosmic Forge; || the conveyor belts (to the
	  =boards= (high up)               lane and back); the last two bases side by side at the
	                                   back, facing the lane, the leaderboards high on the back
	                                   wall above them, edge to edge in the middle

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

-- Where the lobby's leaderboards hang: on the back wall, up above the back two bases' shops.
function Layout.LeaderboardZ(): number
	return map.SafeZoneZ - map.HubDepth + 1.5
end
Layout.LeaderboardBottom = 22 -- how high the bottom of the boards is (clear of the shops' roofs)

-- The lobby's conveyor belts (Config.Conveyors): a pair down each side of the walkway, between the
-- plaza and the side bases, from the back two bases' gates to the lane's entrance. In each pair
-- the belt nearer the plaza carries you to the front (+Z, towards the lane), the other to the back.
-- Center is the middle of the belt's top.
export type Conveyor = { Name: string, Center: Vector3, Length: number, Width: number, Direction: Vector3 }
function Layout.Conveyors(): { Conveyor }
	local c = Config.Conveyors
	local front = map.SafeZoneZ - c.Front
	local back = Layout.BackRowZ() + Layout.PlotDepth / 2 + c.Back
	local z, length = (front + back) / 2, front - back
	-- the walkway's edge (where the side bases start), then the two belts inwards from it
	local edge = map.HubHalfWidth - Layout.PlotDepth - 4
	local outer = edge - 0.5 - c.Width / 2
	local inner = outer - c.Width - c.Gap
	local belts: { Conveyor } = {}
	for _, side in { -1, 1 } do
		local suffix = if side == -1 then "Left" else "Right"
		table.insert(belts, { Name = "ToFront" .. suffix, Center = Vector3.new(side * inner, 0, z), Length = length, Width = c.Width, Direction = Vector3.new(0, 0, 1) })
		table.insert(belts, { Name = "ToBack" .. suffix, Center = Vector3.new(side * outer, 0, z), Length = length, Width = c.Width, Direction = Vector3.new(0, 0, -1) })
	end
	return belts
end

-- The conveyor belt (if any) under `position`, and the way it goes.
local beltCache: { Conveyor }? = nil
function Layout.ConveyorAt(position: Vector3): Conveyor?
	-- (checked every frame: the belts never move, so work them out once)
	local belts = beltCache or Layout.Conveyors()
	beltCache = belts
	for _, belt in belts do
		local d = position - belt.Center
		if math.abs(d.X) <= belt.Width / 2 + 1 and math.abs(d.Z) <= belt.Length / 2 + 1 and d.Y > -2 and d.Y < 8 then
			return belt
		end
	end
	return nil
end

-- The little round plaza in the middle of the walkway (level with the middle bases): the sell
-- stall and the Cosmic Forge either side of it.
Layout.PlazaRadius = 44
function Layout.PlazaCenter(): Vector3
	return Vector3.new(0, 0, map.SafeZoneZ - Layout.PlotFirstRowZ - Layout.PlotRowSpacing * (Layout.SideRows - 1) / 2)
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
-- Plots: 1-4 down each side of the walkway (odd on the left (-X), even on the right (+X), row 0
-- nearest the lane), facing the walkway; 5-6 side by side at the back (left, right), facing the lane.
--
-- A base is a donut shop with an open pen in front of it (like Steal an Egg): a fenced patch of
-- ground with a low gate at the front, where the donuts roam and boxes wait to open. The pen grows
-- a little with every base upgrade (Config.Plots.Sizes): its front stays by the plaza and it grows
-- sideways and backwards, with the shop moving back behind it.
--------------------------------------------------------------------------------
Layout.PlotWidth = 150 -- plot space X (sideways)
Layout.PlotDepth = 130 -- plot space Z (front, by the plaza, to back)
Layout.PlotRowSpacing = 156 -- bases down a side are this far apart (centre to centre)
Layout.PlotFirstRowZ = 80 -- the first row's centre, this far behind the safe-zone line
Layout.SideRows = 2 -- bases down each side of the walkway (the back two come after them)
Layout.PlotFloorHeight = 0.4
Layout.PenFront = -Layout.PlotDepth / 2 + 14 -- (plot space) the pen's front fence, where the gate is
Layout.ShopDepth = 22 -- the donut shop behind the pen
Layout.GateHalfWidth = 12 -- the gap in the pen's front fence (24 studs: plenty of room to run in)
-- (plot space) how far either side of the pen's middle the treadmill, incubator and podium stand:
-- clear of even the biggest pen. A treadmill reaches TreadmillReach studs either way along its belt
-- (art/treadmills keeps every design within it).
Layout.TreadmillReach = 10.2
Layout.SideItemsX = Layout.PlotWidth / 2 - 9

-- Z of the middle of the back two bases: right behind the last row down the sides.
function Layout.BackRowZ(): number
	local lastRow = map.SafeZoneZ - Layout.PlotFirstRowZ - (Layout.SideRows - 1) * Layout.PlotRowSpacing
	return lastRow - Layout.PlotWidth / 2 - 4 - Layout.PlotDepth / 2
end

Layout.BackGap = 4 -- studs between the back two bases' pens at their biggest
Layout.PenBorder = 2 -- the trim round a pen, outside its fence

-- Half the width of a pen at its biggest (the last size, or the owner's admin size if that's
-- bigger), trim included.
function Layout.MaxPenHalfWidth(): number
	local sizes = Config.Plots.Sizes
	local most = math.max(sizes[#sizes].Slots, Config.Admin.MaxSlots)
	local width = Layout.PenSize(most)
	return width / 2 + Layout.PenBorder
end

-- X of the back two bases' middles (+/-): as close together as they go, BackGap apart at their
-- biggest.
function Layout.BackBaseX(): number
	return Layout.MaxPenHalfWidth() + Layout.BackGap / 2
end

-- The leaderboards: a row edge to edge in the middle of the back wall (high up, above the back
-- two bases' shops). Each board's middle X, left to right, and its size (1: full size, 31 wide).
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
-- the donut shop's roof behind the biggest pen. The back wall stands just behind this for the back
-- two bases.
function Layout.PlotBackReach(): number
	local most = math.max(Config.Plots.Sizes[#Config.Plots.Sizes].Slots, Config.Admin.MaxSlots)
	local _, depth = Layout.PenSize(most)
	return Layout.PenFront + depth + 3 + Layout.ShopDepth + 1.5
end

function Layout.PlotCFrame(plotIndex: number, _worldId: number?): CFrame
	local side = if plotIndex % 2 == 1 then -1 else 1
	if plotIndex > Layout.SideRows * 2 then
		-- the back two, side by side in the middle of the back wall, facing the lane
		local center = Vector3.new(side * Layout.BackBaseX(), 0, Layout.BackRowZ())
		return CFrame.lookAt(center, center + Vector3.new(0, 0, 1))
	end
	-- down the left (odd) or right (even) wall, facing the walkway
	local row = (plotIndex - 1) // 2
	local x = side * (map.HubHalfWidth - Layout.PlotDepth / 2 - 4)
	local z = map.SafeZoneZ - Layout.PlotFirstRowZ - row * Layout.PlotRowSpacing
	local center = Vector3.new(x, 0, z)
	-- LookVector points out of the plot's open side, towards the walkway.
	return CFrame.lookAt(center, center + Vector3.new(-side, 0, 0))
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
