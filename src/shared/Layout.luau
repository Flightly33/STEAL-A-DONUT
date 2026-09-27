--[[
	Layout: pure geometry helpers for the map (shared by server and client).

	      +Z  (lane goes this way, area 1 .. area N)
	       ^
	  -----|-----------------  Z = SafeZoneZ  (safe zone line)
	  plots | hub / plaza | plots
	       (spawn, shop, leaderboards)
]]

local Config = require(script.Parent.Config)
local Areas = require(script.Parent.Areas)

local Layout = {}

local map = Config.Map

function Layout.AreaStart(areaId: number): number
	return map.SafeZoneZ + (areaId - 1) * map.AreaLength
end

function Layout.AreaEnd(areaId: number): number
	return map.SafeZoneZ + areaId * map.AreaLength
end

function Layout.LaneEnd(): number
	return Layout.AreaEnd(#Areas.List)
end

-- 0 = safe hub, 1..N = lane areas
function Layout.AreaAt(position: Vector3): number
	if position.Z < map.SafeZoneZ then
		return 0
	end
	local index = math.floor((position.Z - map.SafeZoneZ) / map.AreaLength) + 1
	return math.clamp(index, 1, #Areas.List)
end

function Layout.IsSafe(position: Vector3): boolean
	return position.Z < map.SafeZoneZ
end

-- The guard sleeps at the BACK of his area, so every steal is a straight race to the safe zone
-- (donuts never spawn behind him, which would force you to run past an awake guard).
Layout.GuardBackOffset = 14

function Layout.GuardHome(areaId: number): Vector3
	return Vector3.new(0, 0, Layout.AreaEnd(areaId) - Layout.GuardBackOffset)
end

-- Plots: odd numbers on the left (-X), even on the right (+X), row 0 nearest the lane.
Layout.PlotWidth = 56
Layout.PlotDepth = 98
Layout.PlotRowSpacing = 60
Layout.PlotFloorHeight = 0.4

function Layout.PlotCFrame(plotIndex: number): CFrame
	local side = if plotIndex % 2 == 1 then -1 else 1
	local row = (plotIndex - 1) // 2
	local x = side * (map.HubHalfWidth - Layout.PlotDepth / 2 - 2)
	local z = map.SafeZoneZ - 34 - row * Layout.PlotRowSpacing
	local center = Vector3.new(x, 0, z)
	-- LookVector points out of the plot's open side, towards the plaza.
	return CFrame.lookAt(center, center + Vector3.new(-side, 0, 0))
end

-- Is `position` inside the plot's fenced area?
function Layout.IsInPlot(plotIndex: number, position: Vector3): boolean
	local localPos = Layout.PlotCFrame(plotIndex):PointToObjectSpace(position)
	return math.abs(localPos.X) <= Layout.PlotWidth / 2
		and math.abs(localPos.Z) <= Layout.PlotDepth / 2
		and localPos.Y > -5
		and localPos.Y < 25
end

return Layout
