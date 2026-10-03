--[[
	Layout: pure geometry helpers for the map (shared by server and client).

	      +Z  (each world's lane goes this way, area 1 .. area N of that world)
	       ^
	  -----|-----------------  Z = SafeZoneZ  (safe zone line, the same in every world)
	  plots | hub / plaza | plots
	       (spawn, shop, leaderboards, portals)

	World 1's lane starts at the hub. Worlds 2 and 3 are separate lanes far away along X
	(Areas.Worlds[].OffsetX), each with its own safe hub (Z < SafeZoneZ): the same 8 base plots as
	the main hub, and a portal home. Your base follows you to whichever world you're in.
]]

local Config = require(script.Parent.Config)
local Areas = require(script.Parent.Areas)

local Layout = {}

local map = Config.Map

--------------------------------------------------------------------------------
-- Worlds / areas
--------------------------------------------------------------------------------
function Layout.WorldOffset(worldId: number): number
	return Areas.World(worldId).OffsetX
end

-- How long (along Z) and how wide an area is: most use Config.Map, The Black Hole is bigger.
function Layout.AreaLength(areaId: number): number
	return Areas.List[areaId].Length or map.AreaLength
end

function Layout.AreaHalfWidth(areaId: number): number
	return Areas.List[areaId].HalfWidth or map.LaneHalfWidth
end

-- Z where an area starts / ends (its position inside its own world's lane, after the bridge).
local startCache: { [number]: number } = {}
function Layout.AreaStart(areaId: number): number
	local cached = startCache[areaId]
	if cached then
		return cached
	end
	local area = Areas.List[areaId]
	local z = map.SafeZoneZ + Areas.World(area.World).BridgeLength
	for _, other in Areas.ByWorld[area.World] do
		if other.Index < area.Index then
			z += Layout.AreaLength(other.Id)
		end
	end
	startCache[areaId] = z
	return z
end

function Layout.AreaEnd(areaId: number): number
	return Layout.AreaStart(areaId) + Layout.AreaLength(areaId)
end

function Layout.LaneEnd(worldId: number?): number
	local list = Areas.ByWorld[Areas.World(worldId or 1).Id]
	return Layout.AreaEnd(list[#list].Id)
end

-- Which world a position is in (the nearest lane along X).
function Layout.WorldAt(position: Vector3): number
	local best, bestDistance = 1, math.huge
	for _, world in Areas.Worlds do
		local distance = math.abs(position.X - world.OffsetX)
		if distance < bestDistance then
			best, bestDistance = world.Id, distance
		end
	end
	return best
end

-- 0 = safe (hub or a world's landing), otherwise the area id (1..#Areas.List).
function Layout.AreaAt(position: Vector3): number
	if position.Z < map.SafeZoneZ then
		return 0
	end
	local world = Areas.World(Layout.WorldAt(position))
	local list = Areas.ByWorld[world.Id]
	-- (the bridge in front of a world's first area counts as that area, and past the end is the last)
	for _, area in list do
		if position.Z < Layout.AreaEnd(area.Id) then
			return area.Id
		end
	end
	return list[#list].Id
end

function Layout.IsSafe(position: Vector3): boolean
	return position.Z < map.SafeZoneZ
end

-- X range a guard may chase in (the lane minus the wall decorations).
function Layout.LaneLimits(areaId: number): (number, number)
	local x = Layout.WorldOffset(Areas.List[areaId].World)
	local limit = Layout.AreaHalfWidth(areaId) - 8
	return x - limit, x + limit
end

-- The guard sleeps at the BACK of his area, so every steal is a straight race to the safe zone
-- (donuts never spawn behind him, which would force you to run past an awake guard).
Layout.GuardBackOffset = 14
-- Donuts spawn at least SpawnStartMargin studs into their area and SpawnGuardMargin studs in front
-- of the guard's blanket (MapBuilder; Economy.RecommendedSpeed uses the same range).
Layout.SpawnStartMargin = 20
Layout.SpawnGuardMargin = 18

function Layout.GuardHome(areaId: number): Vector3
	local x = Layout.WorldOffset(Areas.List[areaId].World)
	return Vector3.new(x, 0, Layout.AreaEnd(areaId) - Layout.GuardBackOffset)
end

-- Where you land when you arrive in a world (hub side of its first area, facing the lane).
function Layout.WorldArrival(worldId: number): CFrame
	local x = Layout.WorldOffset(worldId)
	local z = map.SafeZoneZ - (if worldId == 1 then 26 else 30)
	return CFrame.lookAt(Vector3.new(x, 3.5, z), Vector3.new(x, 3.5, z + 10))
end

-- Start of an area (Teleporter pass).
function Layout.AreaArrival(areaId: number): CFrame
	local x = Layout.WorldOffset(Areas.List[areaId].World)
	local z = Layout.AreaStart(areaId) + 8
	return CFrame.lookAt(Vector3.new(x, 3.5, z), Vector3.new(x, 3.5, z + 10))
end

-- World landings (worlds 2+): a safe platform in front of the lane.
Layout.LandingDepth = 90

-- Portals: in the hub one per extra world; in every extra world one back home.
-- Returns the portal's CFrame (LookVector = the side you walk in from).
function Layout.PortalCFrame(worldId: number, home: boolean?): CFrame
	if home then
		local x = Layout.WorldOffset(worldId)
		local position = Vector3.new(x, 0, map.SafeZoneZ - Layout.LandingDepth + 14)
		return CFrame.lookAt(position, position + Vector3.new(0, 0, 1))
	end
	-- Hub portals: a row at the back of the hub (out of the way), facing the spawn, in world order
	local count, slot = 0, 0
	for _, world in Areas.Worlds do
		if world.Id > 1 then
			count += 1
			if world.Id == worldId then
				slot = count
			end
		end
	end
	local position = Vector3.new((slot - (count + 1) / 2) * 48, 0, map.SafeZoneZ - map.HubDepth + 70)
	return CFrame.lookAt(position, position + Vector3.new(0, 0, 1))
end

-- Where the hub's leaderboards stand: along the back wall, behind the portals.
function Layout.LeaderboardZ(): number
	return map.SafeZoneZ - map.HubDepth + 8
end

Layout.PortalRadius = 6

--------------------------------------------------------------------------------
-- Plots: odd numbers on the left (-X), even on the right (+X), row 0 nearest the lane.
-- Every world's hub has the same plots around its own lane (worldId, default 1).
--
-- A base is an open pen on its plot (like Steal an Egg): a fenced patch of ground with a gate at
-- the front, where the donuts roam. The pen grows with the base's size (Config.Plots.Sizes): its
-- front stays at the front of the plot and it grows sideways and backwards, so the plot is as big
-- as the biggest pen (Config.Admin.MaxSlots donuts).
--------------------------------------------------------------------------------
Layout.PlotWidth = 180 -- plot space X (sideways)
Layout.PlotDepth = 180 -- plot space Z (front, by the plaza, to back)
-- Bases in a row are this far apart (centre to centre): 40 studs of open ground between two plots.
Layout.PlotRowSpacing = 220
Layout.PlotFirstRowZ = 102 -- the first row's centre, this far behind the safe-zone line
Layout.PlotFloorHeight = 0.4
Layout.PenFront = -Layout.PlotDepth / 2 + 3 -- (plot space) the pen's front fence, where the gate is

function Layout.PlotCFrame(plotIndex: number, worldId: number?): CFrame
	local side = if plotIndex % 2 == 1 then -1 else 1
	local row = (plotIndex - 1) // 2
	local x = Layout.WorldOffset(worldId or 1) + side * (map.HubHalfWidth - Layout.PlotDepth / 2 - 2)
	local z = map.SafeZoneZ - Layout.PlotFirstRowZ - row * Layout.PlotRowSpacing
	local center = Vector3.new(x, 0, z)
	-- LookVector points out of the plot's open side, towards the plaza.
	return CFrame.lookAt(center, center + Vector3.new(-side, 0, 0))
end

-- The pen's grid for a base with room for `slots` donuts: one CellSize patch per donut, about as
-- many columns as rows. Returns columns, rows, width (plot X) and depth (plot Z) in studs.
function Layout.PenGrid(slots: number): (number, number, number, number)
	local cell = Config.Plots.CellSize
	local count = math.max(slots, 1)
	local columns = math.ceil(math.sqrt(count) - 1e-9)
	local rows = math.ceil(count / columns)
	return columns, rows, columns * cell, rows * cell
end

-- The pen's middle (plot space) and its size (X, Z).
function Layout.PenBounds(slots: number): (Vector3, Vector2)
	local _, _, width, depth = Layout.PenGrid(slots)
	return Vector3.new(0, 0, Layout.PenFront + depth / 2), Vector2.new(width, depth)
end

-- Where donut number `slotIndex` lives in the pen (plot space, on the ground): the middle of its
-- patch. Patches fill the pen from the front row (by the gate) to the back.
function Layout.SlotHome(slotIndex: number, slots: number): Vector3
	local columns, _, width = Layout.PenGrid(slots)
	local cell = Config.Plots.CellSize
	local index = slotIndex - 1
	local column = index % columns
	local row = index // columns
	-- (rows alternate direction so neighbours along the fill order stay close)
	if row % 2 == 1 then
		column = columns - 1 - column
	end
	return Vector3.new(-width / 2 + cell * (column + 0.5), 0, Layout.PenFront + cell * (row + 0.5))
end

-- Is `position` inside a base's pen (`slots`: how many donuts it holds)? `margin` widens it.
function Layout.IsInPlot(plotIndex: number, position: Vector3, worldId: number?, slots: number?, margin: number?): boolean
	local localPos = Layout.PlotCFrame(plotIndex, worldId):PointToObjectSpace(position)
	local center, size = Layout.PenBounds(slots or Config.Plots.Sizes[1].Slots)
	local m = margin or 2
	return math.abs(localPos.X - center.X) <= size.X / 2 + m
		and math.abs(localPos.Z - center.Z) <= size.Y / 2 + m
		and localPos.Y > -5
		and localPos.Y < 60
end

return Layout
