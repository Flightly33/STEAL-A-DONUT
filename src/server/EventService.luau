--[[
	EventService
	============
	Every few minutes ONE server event starts (see Events.luau) and runs for everyone, everywhere:
	  * Luck events: better boxes in every biome (Epic and Legendary boxes, mutations), and every
	    biome's boxes are replaced the moment it starts.
	  * Box Rain: a rare box crashes down, one at a time, in a biome someone can reach (it lands on
	    the ground: whoever grabs it gets chased by that biome's Domer).
	  * Egg Shower: eggs keep dropping in every biome that can have eggs.
	  * 2x Incubator Speed: every incubator hatches twice as fast.
	  * The Eternal Storm (very rare, or the owner's 👑 button): a giant black hole hangs over the
	    lane, huge rocks crash down where people are (whoever they land on is flung), and purple
	    lightning strikes boxes all over the game - every one it hits becomes ETERNAL. Halfway
	    through, while The Cosmic Donut can be crafted, the Cosmic Meteor crashes down
	    (MeteorService). The server
	    picks where rocks land and which boxes get struck, and tells every client (StormBlock /
	    StormStrike) so they all see the same thing; client/StormFX draws it.
	Only one event runs at a time. Clients read it from workspace attributes (EventId, EventEndsAt),
	so players who join mid-event see it too, and show the big announcement when it starts.

	Box Rush (separate, on its own clock): every Config.Boxes.Rush.Interval seconds, for Duration
	seconds, every box in every pen opens Speed times faster (workspace attribute BoxRushEndsAt).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Areas = require(Shared.Areas)
local Economy = require(Shared.Economy)
local Events = require(Shared.Events)
local Boxes = require(Shared.Boxes)
local Rarities = require(Shared.Rarities)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local BoxService = require(script.Parent.BoxService)
local PlotService = require(script.Parent.PlotService)
local PetService = require(script.Parent.PetService)
local ItemService = require(script.Parent.ItemService)
local MeteorService = require(script.Parent.MeteorService)
local GiantService = require(script.Parent.GiantService)
local Decor = require(script.Parent.Decor)
local Layout = require(Shared.Layout)

local EventService = {}

local rng = Random.new()
local current: Events.Event? = nil
local token = 0
local lastId: string? = nil

-- The furthest biome a player is fast enough to get into.
local function bestArea(player: Player): number?
	local profile = DataService.Get(player)
	if not profile or not profile.Session.Ready then
		return nil
	end
	return Economy.BestAreaFor(profile.Data.Speed)
end

-- A biome someone in the server can actually get to (one of a random player's top 3).
local function reachableArea(): number?
	local players = Players:GetPlayers()
	if #players == 0 then
		return nil
	end
	local best = bestArea(players[rng:NextInteger(1, #players)])
	if not best then
		return nil
	end
	return rng:NextInteger(math.max(1, best - 2), best)
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
			local world = Layout.WorldAt(root.CFrame.Position)
			present[world] = true
			if not Layout.IsSafe(root.CFrame.Position) then
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
		base = roots[rng:NextInteger(1, #roots)].CFrame.Position
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
				local offset = root.CFrame.Position - spot
				if Vector3.new(offset.X, 0, offset.Z).Magnitude <= reach and offset.Y < size + 8 then
					ItemService.Fling(player, spot, storm.FlingPower)
				end
			end
		end
	end)
end

-- Purple lightning hits a box waiting in a biome and makes it Eternal (one in a biome someone can
-- get to, if any).
local function strike()
	local reachable: { [number]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local best = bestArea(player)
		if best then
			for id = 1, best do
				reachable[id] = true
			end
		end
	end
	local near, anywhere = {}, {}
	for _, record in BoxService.GetWaiting() do
		if record.Mutation ~= "Eternal" and record.Model then
			table.insert(anywhere, record)
			if reachable[record.AreaId] then
				table.insert(near, record)
			end
		end
	end
	local pool = if #near > 0 then near else anywhere
	if #pool == 0 then
		return
	end
	local record = pool[rng:NextInteger(1, #pool)]
	local model = record.Model
	if not model then
		return
	end
	Remotes.Event("StormStrike"):FireAllClients({ Position = model:GetPivot().Position })
	task.wait(0.3) -- (the bolt lands, then the box changes)
	if not BoxService.Eternalize(record) then
		return
	end
	local area = Areas.List[record.AreaId]
	local name = Rarities.DisplayName(Boxes.DisplayName(record.Tier, record.Size), "Eternal", nil)
	for _, player in Players:GetPlayers() do
		local best = bestArea(player)
		if best and best >= record.AreaId then
			Remotes.Event("Notify"):FireClient(player, `⚡ Purple lightning struck {area.Name}: an {name} is waiting by Domer!`, "rare")
		end
	end
end

local function eternalStorm(myToken: number, length: number)
	-- A black hole high over every world - unless the cosmic sky's images are set up
	-- (Config.EternalStorm.Sky): then every client draws its own, always high in front of them
	local cosmic = storm.Sky.Disk ~= "" and storm.Sky.Halo ~= ""
	if not cosmic then
		local sky = Instance.new("Folder")
		sky.Name = "StormSky"
		for _, world in Areas.Worlds do
			local laneEnd = Layout.LaneEnd(world.Id)
			local center = Vector3.new(world.OffsetX, storm.HoleHeight, (laneEnd - Config.Map.HubDepth) / 2)
			Decor.BlackHole(sky, center, storm.HoleScale, { View = Vector3.new(0, -0.75, -1), Tilt = 22, Roll = 9, JetLength = 4 })
		end
		sky.Parent = workspace
		stormSky = sky
	end
	-- Halfway through: the Cosmic Meteor (if The Cosmic Donut can be crafted)
	task.delay(length / 2, function()
		if token == myToken then
			MeteorService.Start()
		end
	end)
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
	GiantService.Stop() -- (Cosmic Domer sinks back into his black hole)
	workspace:SetAttribute("EventId", nil)
	workspace:SetAttribute("EventEndsAt", nil)
	for _, area in Areas.List do
		BoxService.SetAreaLuck(area.Id, nil)
	end
	BoxService.SetEventRarity(nil)
	PetService.SetEggShower(false)
	PetService.SetHatchBoost(1)
	if event then
		for _, player in Players:GetPlayers() do
			Remotes.Event("Notify"):FireClient(player, `{event.Name} is over.`, "event")
		end
	end
end

-- Box Rain: one rare box at a time crashes down somewhere players can get to.
local function rareRain(myToken: number)
	while token == myToken do
		local areaId = reachableArea()
		if areaId then
			local area = Areas.List[areaId]
			-- (one of the biome's two rarer boxes: Epic / Legendary, or Legendary / Mythic later on)
			local tiers = Boxes.TiersFor(areaId)
			local tier = if #tiers == 1 then tiers[1].Id elseif rng:NextNumber() < 0.3 then tiers[#tiers].Id else tiers[#tiers - 1].Id
			local size = Boxes.RollSize(rng).Id
			local mutation = Rarities.RollMutation(rng, 2).Id
			local half = Layout.AreaHalfWidth(areaId) - 20
			local position = Vector3.new(rng:NextNumber(-half, half), 0, rng:NextNumber(Layout.AreaStart(areaId) + 40, Layout.AreaEnd(areaId) - 90))
			local record = BoxService.Plant(areaId, position, tier, size, mutation)
			record.Planted = nil -- (a real find, not the admin panel's)
			Remotes.Event("StormStrike"):FireAllClients({ Position = position, Color = Boxes.Tier(tier).Color })
			local name = Rarities.DisplayName(Boxes.DisplayName(tier, size), mutation, nil)
			for _, player in Players:GetPlayers() do
				local best = bestArea(player)
				if best and best >= areaId then
					Remotes.Event("Notify"):FireClient(player, `☄️ A {name} crashed into {area.Name}! Grab it before anyone else!`, "rare")
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
			BoxService.SetAreaLuck(area.Id, event.Luck, event.Boost)
		end
		BoxService.SetEventRarity(event.Rarity)
		BoxService.ResetAll() -- (a fresh, luckier batch everywhere)
	elseif event.Kind == "RareRain" then
		task.spawn(rareRain, myToken)
	elseif event.Kind == "EggShower" then
		PetService.SetEggShower(true)
	elseif event.Kind == "DoubleHatch" then
		PetService.SetHatchBoost(Config.Events.HatchBoost)
	elseif event.Kind == "EternalStorm" then
		task.spawn(eternalStorm, myToken, length)
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

-- Box Rush: for a few seconds every box in every pen opens Speed times faster.
local function boxRush()
	local rush = Config.Boxes.Rush
	workspace:SetAttribute("BoxRushEndsAt", workspace:GetServerTimeNow() + rush.Duration)
	for _, player in Players:GetPlayers() do
		Remotes.Event("Notify"):FireClient(player, `⏩ BOX RUSH! Boxes in your pen open {rush.Speed}x faster for {rush.Duration} seconds!`, "event")
	end
	local left = rush.Duration
	while left > 0 do
		local step = math.min(1, left)
		task.wait(step)
		left -= step
		PlotService.RushBoxes(step * (rush.Speed - 1))
	end
	workspace:SetAttribute("BoxRushEndsAt", nil)
end

function EventService.Init()
	task.spawn(function()
		while true do
			workspace:SetAttribute("BoxRushAt", workspace:GetServerTimeNow() + Config.Boxes.Rush.Interval)
			task.wait(Config.Boxes.Rush.Interval)
			boxRush()
		end
	end)
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
