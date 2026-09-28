--[[
	WorldService
	============
	* Tracks which world each player is in (everyone is faster in later worlds), and moves their base
	  there with them (PlotService.MoveBase), so there's always a base right next to the lane.
	* Portals: the hub portals take you to the other worlds once you have enough rebirths; the portal
	  home in each world takes you back to your base in Donut Land. No portals while you carry
	  something: your base is already in the world you're in.
	* Teleporter game pass: jump to any unlocked world, or to the start of any area you're fast
	  enough for.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local Economy = require(Shared.Economy)
local Layout = require(Shared.Layout)
local Remotes = require(Shared.Remotes)

local MapBuilder = require(script.Parent.MapBuilder)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local StealService = require(script.Parent.StealService)

local WorldService = {}

local lastPortal: { [Player]: number } = {}
local lastWarning: { [Player]: number } = {}

local function notify(player: Player, text: string, kind: string?)
	Remotes.Event("Notify"):FireClient(player, text, kind or "info")
end

local function warnOnce(player: Player, text: string)
	local now = os.clock()
	if lastWarning[player] and now - lastWarning[player] < 3 then
		return
	end
	lastWarning[player] = now
	notify(player, text, "error")
end

local function rebirthsText(count: number): string
	return if count == 1 then "1 Rebirth" else `{count} Rebirths`
end

function WorldService.CanEnterWorld(player: Player, worldId: number): boolean
	local profile = DataService.Get(player)
	return profile ~= nil and Economy.WorldUnlocked(worldId, profile.Data.Rebirths)
end

local function setWorld(player: Player, worldId: number)
	local profile = DataService.Get(player)
	if profile and profile.Session.World ~= worldId then
		profile.Session.World = worldId
		player:SetAttribute("World", worldId)
	end
	PlotService.MoveBase(player, worldId)
end

local function arrive(player: Player, worldId: number)
	setWorld(player, worldId)
	StealService.Teleport(player, Layout.WorldArrival(worldId))
	local world = Areas.World(worldId)
	if worldId > 1 then
		notify(player, `{world.Icon} Welcome to {world.Name}! Everyone is x{world.WalkMultiplier} faster here.`, "success")
	end
end

local function usePortal(player: Player, trigger: BasePart)
	local now = os.clock()
	if lastPortal[player] and now - lastPortal[player] < 2 then
		return
	end
	local portal = trigger.Parent
	if not portal then
		return
	end
	if StealService.IsCarrying(player) then
		warnOnce(player, "Bring it to your base first - your base is right here in this world!")
		return
	end
	if portal:GetAttribute("Home") then
		lastPortal[player] = now
		setWorld(player, 1)
		local spawnCf = PlotService.GetSpawnCFrame(player)
		if spawnCf then
			StealService.Teleport(player, spawnCf)
		end
		return
	end
	local worldId = portal:GetAttribute("TargetWorld")
	if type(worldId) ~= "number" then
		return
	end
	if not WorldService.CanEnterWorld(player, worldId) then
		warnOnce(player, `🔒 {Areas.World(worldId).Name} needs {rebirthsText(Areas.World(worldId).RequiredRebirths)}. Rebirth from the menu!`)
		return
	end
	lastPortal[player] = now
	arrive(player, worldId)
end

local function insideTrigger(trigger: BasePart, position: Vector3): boolean
	local p = trigger.CFrame:PointToObjectSpace(position)
	local half = trigger.Size / 2
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y + 2 and math.abs(p.Z) <= half.Z + 1
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
		notify(player, "The Teleporter game pass lets you teleport anywhere you've unlocked!", "error")
		return false
	end
	if StealService.IsCarrying(player) then
		notify(player, "You can't teleport while carrying a donut - run!", "error")
		return false
	end
	if profile.Session.Stunned then
		return false
	end
	local now = os.clock()
	if lastPortal[player] and now - lastPortal[player] < 2 then
		return false
	end
	lastPortal[player] = now
	return true
end

function WorldService.TeleportToWorld(player: Player, worldId: any)
	if type(worldId) ~= "number" or not Areas.Worlds[worldId] then
		return
	end
	if not WorldService.CanEnterWorld(player, worldId) then
		notify(player, `🔒 {Areas.World(worldId).Name} needs {rebirthsText(Areas.World(worldId).RequiredRebirths)}.`, "error")
		return
	end
	if canTeleport(player) then
		arrive(player, worldId)
	end
end

function WorldService.TeleportToArea(player: Player, areaId: any)
	local profile = DataService.Get(player)
	if not profile or type(areaId) ~= "number" or not Areas.List[areaId] then
		return
	end
	local area = Areas.List[areaId]
	if not WorldService.CanEnterWorld(player, area.World) then
		notify(player, `🔒 {Areas.World(area.World).Name} needs {rebirthsText(Areas.World(area.World).RequiredRebirths)}.`, "error")
		return
	end
	if Economy.WalkSpeedFromStat(profile.Data.Speed) + 0.01 < Economy.WalkSpeedFromStat(Economy.RecommendedSpeed(area.Id)) then
		notify(player, "You're not fast enough for that area yet!", "error")
		return
	end
	if canTeleport(player) then
		setWorld(player, area.World)
		StealService.Teleport(player, Layout.AreaArrival(areaId))
	end
end

function WorldService.OnPlayerRemoving(player: Player)
	lastPortal[player] = nil
	lastWarning[player] = nil
end

function WorldService.Init()
	local triggers = MapBuilder.GetPortals()
	task.spawn(function()
		while true do
			task.wait(0.15)
			for _, player in Players:GetPlayers() do
				local profile = DataService.Get(player)
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if profile and profile.Session.Ready and root then
					local position = root.Position
					local world = Layout.WorldAt(position)
					if profile.Session.World ~= world or PlotService.GetBaseWorld(player) ~= world then
						setWorld(player, world)
					end
					for _, trigger in triggers do
						if insideTrigger(trigger, position) then
							usePortal(player, trigger)
							break
						end
					end
				end
			end
		end
	end)
end

return WorldService
