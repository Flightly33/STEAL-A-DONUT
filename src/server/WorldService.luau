--[[
	WorldService
	============
	* Teleporter game pass: jump to the start of any biome, or home. (There are no speed gates:
	  anyone can walk into any biome. A biome's Speed is what you need to get away from its Domer.)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local Layout = require(Shared.Layout)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local StealService = require(script.Parent.StealService)

local WorldService = {}

local lastTeleport: { [Player]: number } = {}

local function notify(player: Player, text: string, kind: string?)
	Remotes.Event("Notify"):FireClient(player, text, kind or "info")
end

--------------------------------------------------------------------------------
-- Teleporter game pass
--------------------------------------------------------------------------------
local function canTeleport(player: Player): boolean
	local profile = DataService.Get(player)
	if not profile then
		return false
	end
	if not profile.Passes.Teleporter then
		notify(player, "The Teleporter game pass lets you teleport to any biome!", "error")
		return false
	end
	if StealService.IsCarrying(player) then
		notify(player, "You can't teleport while carrying something - run!", "error")
		return false
	end
	if profile.Session.Stunned then
		return false
	end
	local now = os.clock()
	if lastTeleport[player] and now - lastTeleport[player] < 2 then
		return false
	end
	lastTeleport[player] = now
	return true
end

function WorldService.TeleportToArea(player: Player, areaId: any)
	local profile = DataService.Get(player)
	if not profile or type(areaId) ~= "number" or not Areas.List[areaId] then
		return
	end
	if canTeleport(player) then
		StealService.Teleport(player, Layout.AreaArrival(areaId))
	end
end

function WorldService.TeleportHome(player: Player)
	if canTeleport(player) then
		local spawnCf = PlotService.GetSpawnCFrame(player)
		if spawnCf then
			StealService.Teleport(player, spawnCf)
		end
	end
end

function WorldService.OnPlayerRemoving(player: Player)
	lastTeleport[player] = nil
end

function WorldService.Init() end

return WorldService
