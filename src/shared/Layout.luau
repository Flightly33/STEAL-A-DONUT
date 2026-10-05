--[[
	Layout: pure geometry helpers for the map (shared by server and client).

	      +Z  (the lane: biome 1 .. the last biome, The Black Hole)
	       ^
	  -----|-----------------  Z = SafeZoneZ  (safe zone line)
	  bases | lobby plaza | bases
	       (spawn, treadmills by the bases, sell stall, leaderboards along the back wall)

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

-- Where you land in the lobby (the middle of the plaza, facing the lane).
function Layout.LobbyArrival(): CFrame
	local z = map.SafeZoneZ - 40
	return CFrame.lookAt(Vector3.new(0, 3.5, z), Vector3.new(0, 3.5, z + 10))
end

-- The lobby's two conveyor belts (Config.Conveyors), side by side: the first carries you to the
-- front (+Z, towards the lane), the second to the back. Center is the middle of the belt's top.
export type Conveyor = { Name: string, Center: Vector3, Length: number, Direction: Vector3 }
function Layout.Conveyors(): { Conveyor }
	local c = Config.Conveyors
	local front = map.SafeZoneZ - c.Front
	local back = map.SafeZoneZ - map.HubDepth + c.Back
	local offset = (c.Width + c.Gap) / 2
	local z = (front + back) / 2
	return {
		{ Name = "ToFront", Center = Vector3.new(c.X - offset, 0, z), Length = front - back, Direction = Vector3.new(0, 0, 1) },
		{ Name = "ToBack", Center = Vector3.new(c.X + offset, 0, z), Length = front - back, Direction = Vector3.new(0, 0, -1) },
	}
end

-- Where the lobby's leaderboards stand: along the very back wall.
function Layout.LeaderboardZ(): number
	return map.SafeZoneZ - map.HubDepth + 10
end

-- The sell stall: in the plaza, to one side of the path to the lane.
function Layout.SellStallCFrame(): CFrame
	local position = Vector3.new(-70, 0, map.SafeZoneZ - 120)
	return CFrame.lookAt(position, position + Vector3.new(1, 0, 0))
end

--------------------------------------------------------------------------------
-- Plots: odd numbers on the left (-X), even on the right (+X), row 0 nearest the lane.
--
-- A base is a donut shop with an open pen in front of it (like Steal an Egg): a fenced patch of
-- ground with a low gate at the front, where the donuts roam and boxes wait to open. The pen grows
-- a little with every base upgrade (Config.Plots.Sizes): its front stays by the plaza and it grows
-- sideways and backwards, with the shop moving back behind it.
--------------------------------------------------------------------------------
Layout.PlotWidth = 150 -- plot space X (sideways)
Layout.PlotDepth = 150 -- plot space Z (front, by the plaza, to back)
Layout.PlotRowSpacing = 170 -- bases in a row are this far apart (centre to centre)
Layout.PlotFirstRowZ = 95 -- the first row's centre, this far behind the safe-zone line
Layout.PlotFloorHeight = 0.4
Layout.PenFront = -Layout.PlotDepth / 2 + 14 -- (plot space) the pen's front fence, where the gate is
Layout.ShopDepth = 22 -- the donut shop behind the pen

function Layout.PlotCFrame(plotIndex: number, _worldId: number?): CFrame
	local side = if plotIndex % 2 == 1 then -1 else 1
	local row = (plotIndex - 1) // 2
	local x = side * (map.HubHalfWidth - Layout.PlotDepth / 2 - 4)
	local z = map.SafeZoneZ - Layout.PlotFirstRowZ - row * Layout.PlotRowSpacing
	local center = Vector3.new(x, 0, z)
	-- LookVector points out of the plot's open side, towards the plaza.
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
	return Vector3.new(14, 0, Layout.PenFront - 7)
end

return Layout
