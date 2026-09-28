--[[
	EventService
	============
	Every few minutes one area gets an event (see Events.luau): a Sandstorm in the desert, a Blizzard
	on the glacier, an Eruption at the volcano... While it lasts, donuts in that area roll mutations
	with extra luck, and the area's donuts are all re-rolled when it starts.

	The event is picked near where the players actually are, so someone can enjoy it.
	Clients read the running event from the area folder's attributes (EventId, EventEndsAt),
	so players who join mid-event see it too.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Areas = require(Shared.Areas)
local Economy = require(Shared.Economy)
local Events = require(Shared.Events)
local Remotes = require(Shared.Remotes)

local MapBuilder = require(script.Parent.MapBuilder)
local DataService = require(script.Parent.DataService)
local DonutSpawnService = require(script.Parent.DonutSpawnService)

local EventService = {}

local rng = Random.new()

-- The best area a player can safely steal in.
local function bestArea(player: Player): number?
	local profile = DataService.Get(player)
	if not profile or not profile.Session.Ready then
		return nil
	end
	local walk = Economy.WalkSpeedFromStat(profile.Data.Speed)
	local best = nil
	for _, area in Areas.List do
		if Economy.WorldUnlocked(area.World, profile.Data.Rebirths) and walk + 0.01 >= Economy.WalkSpeedFromStat(Economy.RecommendedSpeed(area.Id)) then
			best = area.Id
		end
	end
	return best
end

local function pickArea(): number?
	local players = Players:GetPlayers()
	if #players == 0 then
		return nil
	end
	local best = bestArea(players[rng:NextInteger(1, #players)])
	if not best then
		return nil
	end
	-- One of the player's top 3 areas in that world
	local world = Areas.List[best].World
	local candidates = {}
	for id = best - 2, best do
		local area = Areas.List[id]
		if area and area.World == world then
			table.insert(candidates, id)
		end
	end
	return candidates[rng:NextInteger(1, #candidates)]
end

function EventService.Start(areaId: number, event: Events.Event, duration: number)
	local area = Areas.List[areaId]
	local folder = MapBuilder.GetArea(areaId)
	DonutSpawnService.SetAreaLuck(areaId, event.Luck, event.Boost)
	folder:SetAttribute("EventId", event.Id)
	folder:SetAttribute("EventEndsAt", workspace:GetServerTimeNow() + duration)
	DonutSpawnService.RerollArea(areaId)
	-- A small toast (not the big banner: those are only for Secret donuts), for players who can get there
	for _, player in Players:GetPlayers() do
		local profile = DataService.Get(player)
		if profile and Economy.WorldUnlocked(area.World, profile.Data.Rebirths) then
			Remotes.Event("Notify"):FireClient(player, `{event.Icon} {event.Name} in {area.Name}! {event.Description}`, "event")
		end
	end
	task.delay(duration, function()
		if folder:GetAttribute("EventId") == event.Id then
			DonutSpawnService.SetAreaLuck(areaId, nil)
			folder:SetAttribute("EventId", nil)
			folder:SetAttribute("EventEndsAt", nil)
		end
	end)
end

function EventService.Init()
	if not Config.Events.Enabled then
		return
	end
	task.spawn(function()
		task.wait(Config.Events.FirstDelay)
		while true do
			local areaId = pickArea()
			if areaId then
				local event = Events.Pick(Areas.List[areaId].Theme, rng)
				EventService.Start(areaId, event, Config.Events.Duration)
				task.wait(Config.Events.Duration)
			end
			task.wait(rng:NextNumber(Config.Events.Interval[1], Config.Events.Interval[2]))
		end
	end)
end

return EventService
