--[[
	EventService
	============
	Every few minutes ONE server event starts (see Events.luau) and runs for everyone, everywhere:
	  * Luck events: better donuts in every area (mutations, rare donuts), and every area's donuts
	    are re-rolled when it starts.
	  * Rare Donut Rain: a rare donut crashes down, one at a time, in an area someone can reach.
	  * Egg Shower: eggs keep dropping in every area that can have eggs.
	  * 2x Incubator Speed: every incubator hatches twice as fast.
	  * The Eternal Storm (very rare, or the owner's 👑 button): a giant black hole hangs over every
	    world, huge rocks crash down in the lanes where people are (whoever they land on is flung),
	    and purple lightning strikes lane donuts all over the game - every one it hits becomes
	    ETERNAL. The server picks where rocks land and which donuts get struck, and tells every
	    client (StormBlock / StormStrike) so they all see the same thing; client/StormFX draws it.
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
local ItemService = require(script.Parent.ItemService)
local Decor = require(script.Parent.Decor)
local Layout = require(Shared.Layout)

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
		if Economy.WorldUnlocked(area.World, profile.Data.Rebirths, profile.Data.UltimateRebirths) and walk + 0.01 >= Economy.WalkSpeedFromStat(Economy.RecommendedSpeed(area.Id)) then
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

--------------------------------------------------------------------------------
-- The Eternal Storm
--------------------------------------------------------------------------------
local storm = Config.EternalStorm
local stormSky: Folder? = nil
local blockId = 0

-- Where everyone is: world id -> the roots of players in that world's lanes (out of the safe zone),
-- and the set of worlds with anyone in them at all.
local function playersByWorld(): ({ [number]: { BasePart } }, { [number]: boolean })
	local inLanes: { [number]: { BasePart } } = {}
	local present: { [number]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local world = Layout.WorldAt(root.Position)
			present[world] = true
			if not Layout.IsSafe(root.Position) then
				inLanes[world] = inLanes[world] or {}
				table.insert(inLanes[world], root)
			end
		end
	end
	return inLanes, present
end

-- A spot in a lane for a rock: near someone running there (so it's exciting), never in a safe zone.
local function rockSpot(worldId: number, roots: { BasePart }?): Vector3?
	local base: Vector3
	if roots and #roots > 0 then
		base = roots[rng:NextInteger(1, #roots)].Position
		local angle = rng:NextNumber(0, math.pi * 2)
		base += Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(8, 45)
	else
		-- nobody out there: somewhere in the first few areas, where the hub can see it
		local list = Areas.ByWorld[worldId]
		if not list or #list == 0 then
			return nil
		end
		local area = list[rng:NextInteger(1, math.min(3, #list))]
		base = Vector3.new(Layout.WorldOffset(worldId), 0, rng:NextNumber(Layout.AreaStart(area.Id) + 20, Layout.AreaEnd(area.Id) - 20))
	end
	base = Vector3.new(base.X, 0, math.max(base.Z, Config.Map.SafeZoneZ + 25))
	local areaId = Layout.AreaAt(base)
	if areaId == 0 then
		return nil
	end
	local minX, maxX = Layout.LaneLimits(areaId)
	return Vector3.new(math.clamp(base.X, minX + 6, maxX - 6), 0, base.Z)
end

local function dropRock(worldId: number, roots: { BasePart }?)
	local spot = rockSpot(worldId, roots)
	if not spot then
		return
	end
	blockId += 1
	local size = rng:NextNumber(storm.BlockSize[1], storm.BlockSize[2])
	Remotes.Event("StormBlock"):FireAllClients({ Id = blockId, Position = spot, Size = size, Fall = storm.FallTime, Seed = rng:NextInteger(1, 1_000_000) })
	task.delay(storm.FallTime, function()
		-- whoever it lands on (or right next to) is sent flying
		local reach = size * 0.6 + 4
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local offset = root.Position - spot
				if Vector3.new(offset.X, 0, offset.Z).Magnitude <= reach and offset.Y < size + 8 then
					ItemService.Fling(player, spot, storm.FlingPower)
				end
			end
		end
	end)
end

-- Purple lightning hits a lane donut and makes it Eternal (one in a world someone is in, if any).
local function strike()
	local _, present = playersByWorld()
	local near, anywhere = {}, {}
	for _, record in DonutSpawnService.GetRecords() do
		if record.Model and not record.Taken and record.Mutation ~= "Eternal" then
			table.insert(anywhere, record)
			if present[Areas.List[record.AreaId].World] then
				table.insert(near, record)
			end
		end
	end
	local pool = if #near > 0 then near else anywhere
	if #pool == 0 then
		return
	end
	local record = pool[rng:NextInteger(1, #pool)]
	Remotes.Event("StormStrike"):FireAllClients({ Position = record.Point.Position })
	task.wait(0.3) -- (the bolt lands, then the donut changes)
	if not DonutSpawnService.Eternalize(record) then
		return
	end
	local donut = record.DonutId and Donuts.ById[record.DonutId]
	local area = Areas.List[record.AreaId]
	if not donut then
		return
	end
	local name = Rarities.DisplayName(donut.Name, "Eternal", record.Size)
	for _, player in Players:GetPlayers() do
		local profile = DataService.Get(player)
		if profile and Economy.WorldUnlocked(area.World, profile.Data.Rebirths, profile.Data.UltimateRebirths) then
			Remotes.Event("Notify"):FireClient(player, `⚡ Purple lightning struck {area.Name}: {name} is ETERNAL now!`, "rare")
		end
	end
end

local function eternalStorm(myToken: number)
	-- A black hole high over every world
	local sky = Instance.new("Folder")
	sky.Name = "StormSky"
	for _, world in Areas.Worlds do
		local laneEnd = Layout.LaneEnd(world.Id)
		local center = Vector3.new(world.OffsetX, storm.HoleHeight, (laneEnd - Config.Map.HubDepth) / 2)
		Decor.BlackHole(sky, center, storm.HoleScale, { View = Vector3.new(0, -0.75, -1), Tilt = 22, Roll = 9, JetLength = 4 })
	end
	sky.Parent = workspace
	stormSky = sky
	-- Rocks
	task.spawn(function()
		while token == myToken do
			local inLanes, present = playersByWorld()
			for worldId in present do
				dropRock(worldId, inLanes[worldId])
			end
			task.wait(rng:NextNumber(storm.BlockInterval[1], storm.BlockInterval[2]))
		end
	end)
	-- Lightning
	task.wait(3)
	while token == myToken do
		strike()
		task.wait(rng:NextNumber(storm.StrikeInterval[1], storm.StrikeInterval[2]))
	end
end

local function stop()
	local event = current
	current = nil
	if stormSky then
		stormSky:Destroy()
		stormSky = nil
	end
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
				if profile and Economy.WorldUnlocked(area.World, profile.Data.Rebirths, profile.Data.UltimateRebirths) then
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
	local length = duration or (if event.Kind == "EternalStorm" then storm.Duration else Config.Events.Duration)
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
	elseif event.Kind == "EternalStorm" then
		task.spawn(eternalStorm, myToken)
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
