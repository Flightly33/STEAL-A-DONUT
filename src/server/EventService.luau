--[[
	EventService
	============
	Every few minutes ONE server event starts (see Events.luau) and runs for everyone, everywhere:
	  * Luck events: better donuts in every area (mutations, rare donuts), and every area's donuts
	    are re-rolled when it starts.
	  * Rare Donut Rain: a rare donut crashes down, one at a time, in an area someone can reach.
	  * Egg Shower: eggs keep dropping in every area that can have eggs.
	  * 2x Incubator Speed: every incubator hatches twice as fast.
	Only one event runs at a time. Clients read it from workspace attributes (EventId, EventEndsAt),
	so players who join mid-event see it too, and show the big announcement when it starts.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Areas = require(Shared.Areas)
local Economy = require(Shared.Economy)
local Events = require(Shared.Events)
local Donuts = require(Shared.Donuts)
local Rarities = require(Shared.Rarities)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local DonutSpawnService = require(script.Parent.DonutSpawnService)
local PetService = require(script.Parent.PetService)

local EventService = {}

local rng = Random.new()
local current: Events.Event? = nil
local token = 0
local lastId: string? = nil

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

-- An area someone in the server can actually get to (one of a random player's top 3).
local function reachableArea(): number?
	local players = Players:GetPlayers()
	if #players == 0 then
		return nil
	end
	local best = bestArea(players[rng:NextInteger(1, #players)])
	if not best then
		return nil
	end
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

function EventService.Current(): Events.Event?
	return current
end

local function stop()
	local event = current
	current = nil
	workspace:SetAttribute("EventId", nil)
	workspace:SetAttribute("EventEndsAt", nil)
	for _, area in Areas.List do
		DonutSpawnService.SetAreaLuck(area.Id, nil)
	end
	DonutSpawnService.SetEventRarity(nil)
	PetService.SetEggShower(false)
	PetService.SetHatchBoost(1)
	if event then
		for _, player in Players:GetPlayers() do
			Remotes.Event("Notify"):FireClient(player, `{event.Icon} {event.Name} is over.`, "event")
		end
	end
end

-- Rare Donut Rain: one rare donut at a time, somewhere players can get to.
local function rareRain(myToken: number)
	while token == myToken do
		local areaId = reachableArea()
		local record = if areaId then DonutSpawnService.DropRare(areaId) else nil
		local donut = if record and record.DonutId then Donuts.ById[record.DonutId] else nil
		if areaId and record and donut then
			local area = Areas.List[areaId]
			local rarity = Rarities.Get(donut.Rarity)
			local name = Rarities.DisplayName(donut.Name, record.Mutation, record.Size)
			for _, player in Players:GetPlayers() do
				local profile = DataService.Get(player)
				if profile and Economy.WorldUnlocked(area.World, profile.Data.Rebirths) then
					Remotes.Event("Notify"):FireClient(player, `☄️ A {string.upper(rarity.Id)} donut crashed into {area.Name}: {name}!`, "rare")
				end
			end
		end
		task.wait(Config.Events.RareRainInterval)
	end
end

-- Start an event for the whole server (ends the one that's running, if any).
function EventService.Start(event: Events.Event, duration: number?)
	if current then
		stop()
	end
	local length = duration or Config.Events.Duration
	token += 1
	local myToken = token
	current = event
	lastId = event.Id
	workspace:SetAttribute("EventId", event.Id)
	workspace:SetAttribute("EventEndsAt", workspace:GetServerTimeNow() + length)
	if event.Kind == "Luck" then
		for _, area in Areas.List do
			DonutSpawnService.SetAreaLuck(area.Id, event.Luck, event.Boost)
		end
		DonutSpawnService.SetEventRarity(event.Rarity)
		for _, area in Areas.List do
			DonutSpawnService.RerollArea(area.Id)
		end
	elseif event.Kind == "RareRain" then
		task.spawn(rareRain, myToken)
	elseif event.Kind == "EggShower" then
		PetService.SetEggShower(true)
	elseif event.Kind == "DoubleHatch" then
		PetService.SetHatchBoost(Config.Events.HatchBoost)
	end
	task.delay(length, function()
		if token == myToken then
			token += 1
			stop()
		end
	end)
end

function EventService.StartById(id: string, duration: number?): boolean
	local event = Events.ById[id]
	if not event then
		return false
	end
	EventService.Start(event, duration)
	return true
end

function EventService.Init()
	if not Config.Events.Enabled then
		return
	end
	task.spawn(function()
		task.wait(Config.Events.FirstDelay)
		while true do
			if #Players:GetPlayers() > 0 and not current then
				EventService.Start(Events.Pick(rng, lastId))
			end
			task.wait(Config.Events.Duration + rng:NextNumber(Config.Events.Interval[1], Config.Events.Interval[2]))
		end
	end)
end

return EventService
