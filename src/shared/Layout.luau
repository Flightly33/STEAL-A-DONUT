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

-- Z where an area starts / ends (its position inside its own world's lane, after the bridge).
function Layout.AreaStart(areaId: number): number
	local area = Areas.List[areaId]
	return map.SafeZoneZ + Areas.World(area.World).BridgeLength + (area.Index - 1) * map.AreaLength
end

function Layout.AreaEnd(areaId: number): number
	return Layout.AreaStart(areaId) + map.AreaLength
end

function Layout.LaneEnd(worldId: number?): number
	local world = Areas.World(worldId or 1)
	return map.SafeZoneZ + world.BridgeLength + #Areas.ByWorld[world.Id] * map.AreaLength
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
	-- (the bridge in front of a world's first area counts as that area)
	local index = math.clamp(math.floor((position.Z - map.SafeZoneZ - world.BridgeLength) / map.AreaLength) + 1, 1, #list)
	return list[index].Id
end

function Layout.IsSafe(position: Vector3): boolean
	return position.Z < map.SafeZoneZ
end

-- X range a guard may chase in (the lane minus the wall decorations).
function Layout.LaneLimits(areaId: number): (number, number)
	local x = Layout.WorldOffset(Areas.List[areaId].World)
	local limit = map.LaneHalfWidth - 8
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
	local side = if Layout.WorldOffset(worldId) >= 0 then 1 else -1
	local position = Vector3.new(side * 96, 0, map.SafeZoneZ - 112)
	return CFrame.lookAt(position, position + Vector3.new(-side, 0, 0))
end

Layout.PortalRadius = 6

--------------------------------------------------------------------------------
-- Plots: odd numbers on the left (-X), even on the right (+X), row 0 nearest the lane.
-- Every world's hub has the same plots around its own lane (worldId, default 1).
--------------------------------------------------------------------------------
Layout.PlotWidth = 56
Layout.PlotDepth = 98
Layout.PlotRowSpacing = 60
Layout.PlotFloorHeight = 0.4

function Layout.PlotCFrame(plotIndex: number, worldId: number?): CFrame
	local side = if plotIndex % 2 == 1 then -1 else 1
	local row = (plotIndex - 1) // 2
	local x = Layout.WorldOffset(worldId or 1) + side * (map.HubHalfWidth - Layout.PlotDepth / 2 - 2)
	local z = map.SafeZoneZ - 34 - row * Layout.PlotRowSpacing
	local center = Vector3.new(x, 0, z)
	-- LookVector points out of the plot's open side, towards the plaza.
	return CFrame.lookAt(center, center + Vector3.new(-side, 0, 0))
end

-- Donut stands, in plot space: rows from the FRONT (entrance) to the back, 4 per row, so the
-- first stands you own are the ones everybody walks past.
Layout.SlotColumns = { -19.5, -6.5, 6.5, 19.5 }
Layout.SlotRows = { -26, -12, 2, 16, 30, 42 }
-- Stands SlotsPerPlot+1 .. MaxSlots are on the second floor (same layout, SecondFloor.Height up).
Layout.MaxSlots = Config.Plots.SlotsPerPlot + Config.Plots.SecondFloor.Slots
-- Lift pad between the floors (plot space): front-left, clear of the entrance and the stands.
Layout.LiftOffset = Vector3.new(-18, 0, -40)

function Layout.SlotOffset(slotIndex: number): Vector3
	local perFloor = Config.Plots.SlotsPerPlot
	local floor = (slotIndex - 1) // perFloor
	local index = (slotIndex - 1) % perFloor + 1
	local columns = #Layout.SlotColumns
	local row = (index - 1) // columns + 1
	local column = (index - 1) % columns + 1
	return Vector3.new(Layout.SlotColumns[column], floor * Config.Plots.SecondFloor.Height, Layout.SlotRows[row])
end

-- Is `position` inside the plot's fenced area?
function Layout.IsInPlot(plotIndex: number, position: Vector3, worldId: number?): boolean
	local localPos = Layout.PlotCFrame(plotIndex, worldId):PointToObjectSpace(position)
	return math.abs(localPos.X) <= Layout.PlotWidth / 2
		and math.abs(localPos.Z) <= Layout.PlotDepth / 2
		and localPos.Y > -5
		and localPos.Y < Config.Plots.SecondFloor.Height + 20
end

return Layout
