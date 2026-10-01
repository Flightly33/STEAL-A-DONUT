--[[
	DonutSpawnService
	=================
	Keeps a donut on every spawn point in the lane. Donuts are rolled from their area's weighted pool
	(plus a mutation and a size), re-rolled if nobody steals them for a while, and a new one appears
	a few seconds after one is brought home. Secret and Admin spawns are announced to the server.
	During an area event (EventService) the area's spawns roll mutations with extra luck, and during
	a Luck Event (LuckService) every spawn in the server is luckier.

	A stolen donut is only "held" by its thief until they get it home: if they're caught, hit, or
	fall, the SAME donut pops back onto the spot it was taken from (Return).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Areas = require(Shared.Areas)
local Donuts = require(Shared.Donuts)
local Rarities = require(Shared.Rarities)
local Economy = require(Shared.Economy)
local DonutModel = require(Shared.DonutModel)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)

local MapBuilder = require(script.Parent.MapBuilder)

local DonutSpawnService = {}

export type SpawnRecord = {
	Point: BasePart,
	AreaId: number,
	Model: Model?,
	DonutId: string?,
	Mutation: string,
	Size: string,
	SpawnedAt: number,
	Taken: boolean,
	Held: { DonutId: string, Mutation: string, Size: string }?, -- what the thief is carrying
	Planted: boolean?, -- put there with the admin panel (not counted in the global stats)
	Container: Instance,
}

export type ServerLuck = { Rarity: number, Mutation: number, Size: number }

local records: { SpawnRecord } = {}
local rng = Random.new()
local stealHandler: ((Player, SpawnRecord) -> ())? = nil
local serverLuck: ServerLuck? = nil

-- Fired for every donut that appears in the lane: (donutId, mutationId). Used by the global stats.
DonutSpawnService.Spawned = Signal.new()

-- Set by LuckService while a Luck Event runs (nil when it ends).
function DonutSpawnService.SetServerLuck(luck: ServerLuck?)
	serverLuck = luck
end

-- Set by EventService while a server event runs: extra rare-donut luck everywhere (1 = none).
local eventRarity = 1
function DonutSpawnService.SetEventRarity(luck: number?)
	eventRarity = luck or 1
end

-- Set by EventService while an event runs: areaId -> { Luck, Boost }
local areaLuck: { [number]: { Luck: number, Boost: string? } } = {}

function DonutSpawnService.SetAreaLuck(areaId: number, luck: number?, boost: string?)
	if luck then
		areaLuck[areaId] = { Luck = luck, Boost = boost }
	else
		areaLuck[areaId] = nil
	end
end

-- StealService registers itself here (avoids a circular require).
function DonutSpawnService.SetStealHandler(handler: (Player, SpawnRecord) -> ())
	stealHandler = handler
end

type Forced = { DonutId: string, Mutation: string, Size: string }

-- Put a donut on a spawn point: a fresh random one, or `forced` (a stolen donut coming back).
-- `rareOnly`: a rare donut of the area (Rare Donut Rain event).
local function spawnDonut(record: SpawnRecord, announce: boolean, forced: Forced?, rareOnly: boolean?)
	if record.Model then
		record.Model:Destroy()
		record.Model = nil
	end
	local luck = areaLuck[record.AreaId]
	local global = serverLuck
	local donut, mutation, size
	if forced and Donuts.ById[forced.DonutId] then
		donut = Donuts.ById[forced.DonutId]
		mutation = Rarities.Mutation(forced.Mutation)
		size = Rarities.Size(forced.Size)
	else
		local rarityLuck = (if global then global.Rarity else 1) * eventRarity
		donut = if rareOnly then Donuts.RollRare(record.AreaId, rng) else Donuts.Roll(record.AreaId, rng, if rarityLuck ~= 1 then rarityLuck else nil)
		local mutationLuck = (if luck then luck.Luck else 1) * (if global then global.Mutation else 1)
		mutation = Rarities.RollMutation(rng, mutationLuck, if luck then luck.Boost else nil)
		size = Rarities.RollSize(rng, if global then global.Size else nil)
	end
	local model = DonutModel.Build(donut, { Scale = 0.95, Pillar = true, Mutation = mutation.Id, Size = size.Id })
	DonutModel.PlaceOn(model, record.Point.CFrame)
	model:SetAttribute("Area", record.AreaId)
	local root = model.PrimaryPart :: BasePart

	local income = Economy.DonutIncome(donut.Id, 1, mutation.Id, size.Id)
	local info = DonutModel.CreateBillboard(donut, income, nil, (model:GetAttribute("Top") :: number?) or 3, mutation.Id, size.Id)
	info.Parent = root

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = if size.CarrySpeed < 1 then `Steal (heavy: {math.floor((1 - size.CarrySpeed) * 100 + 0.5)}% slower)` else "Steal"
	prompt.ObjectText = Rarities.DisplayName(donut.Name, mutation.Id, size.Id)
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 11 * math.max(1, size.Scale * 0.9)
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		if stealHandler and record.Model == model and not record.Taken then
			stealHandler(player, record)
		end
	end)

	model.Parent = record.Container
	record.Model = model
	record.DonutId = donut.Id
	record.Mutation = mutation.Id
	record.Size = size.Id
	record.SpawnedAt = os.clock()
	record.Taken = false
	record.Held = nil
	if forced then
		return -- a returned donut isn't a new spawn
	end
	record.Planted = nil
	DonutSpawnService.Spawned:Fire(donut.Id, mutation.Id)

	local rarity = Rarities.Get(donut.Rarity)
	if announce and rarity.Order >= Config.Spawns.AnnounceRarity then
		local area = Areas.List[record.AreaId]
		local name = Rarities.DisplayName(donut.Name, mutation.Id, size.Id)
		local text = if rarity.Id == "Icon"
			then `💎 AN ICON DONUT APPEARED IN {string.upper(area.Name)}: {name}! 💎`
			elseif rarity.Id == "Admin"
			then `🚨 AN ADMIN DONUT APPEARED IN {string.upper(area.Name)}: {name}! 🚨`
			else `A {string.upper(rarity.Id)} donut appeared in {area.Name}: {name}!`
		Remotes.Event("AreaAnnouncement"):FireAllClients(text, rarity.Color)
	end
end

-- Remove the donut from its spawn point (it was stolen). Returns the donut id, mutation and size.
-- The spot stays empty until the thief either gets home (Release) or loses it (Return).
function DonutSpawnService.Take(record: SpawnRecord): (string?, string, string)
	if record.Taken or not record.Model or not record.DonutId then
		return nil, "None", "Normal"
	end
	local donutId = record.DonutId
	local mutation, size = record.Mutation, record.Size
	record.Taken = true
	record.Held = { DonutId = donutId, Mutation = mutation, Size = size }
	record.Model:Destroy()
	record.Model = nil
	record.DonutId = nil
	return donutId, mutation, size
end

-- The thief lost the donut (caught, hit, fell, left): it goes back where it was taken from.
function DonutSpawnService.Return(record: SpawnRecord)
	local held = record.Held
	if record.Taken and held then
		spawnDonut(record, false, held)
	end
end

-- The thief got the donut home: a new random donut appears on the spot a few seconds later.
function DonutSpawnService.Release(record: SpawnRecord)
	if not record.Taken then
		return
	end
	record.Held = nil
	task.delay(rng:NextNumber(Config.Spawns.RespawnMin, Config.Spawns.RespawnMax), function()
		if record.Taken and not record.Held then
			spawnDonut(record, true)
		end
	end)
end

-- Every spawn point (the admin panel uses this to drop a donut in front of you).
function DonutSpawnService.GetRecords(): { SpawnRecord }
	return records
end

-- Replace whatever is on a spawn point with a specific donut (admin panel).
function DonutSpawnService.ForceSpawn(record: SpawnRecord, donutId: string, mutationId: string, sizeId: string)
	if record.Taken or not Donuts.ById[donutId] then
		return
	end
	spawnDonut(record, false, { DonutId = donutId, Mutation = mutationId, Size = sizeId })
	record.Planted = true
end

-- Rare Donut Rain: a rare donut crashes onto a random free spot of the area (with a boom).
-- Returns the spot's record, or nil if the area has no free spot.
function DonutSpawnService.DropRare(areaId: number): SpawnRecord?
	local free = {}
	for _, record in records do
		if record.AreaId == areaId and not record.Taken then
			table.insert(free, record)
		end
	end
	if #free == 0 then
		return nil
	end
	local record = free[rng:NextInteger(1, #free)]
	spawnDonut(record, true, nil, true)
	local boom = Instance.new("Explosion")
	boom.BlastPressure = 0
	boom.BlastRadius = 0
	boom.DestroyJointRadiusPercent = 0
	boom.Position = record.Point.Position
	boom.Parent = workspace
	return record
end

-- Re-roll every untaken donut in an area (an event just started there).
function DonutSpawnService.RerollArea(areaId: number)
	task.spawn(function()
		for _, record in records do
			if record.AreaId == areaId and not record.Taken then
				spawnDonut(record, true)
				task.wait(0.03)
			end
		end
	end)
end

function DonutSpawnService.Init()
	for areaId = 1, #Areas.List do
		local area = MapBuilder.GetArea(areaId)
		local spawns = area:FindFirstChild("Spawns")
		local container = Instance.new("Folder")
		container.Name = "ActiveDonuts"
		container.Parent = area
		if spawns then
			for _, point in spawns:GetChildren() do
				if point:IsA("BasePart") and point.Name == "DonutSpawn" then
					local record: SpawnRecord = { Point = point, AreaId = areaId, Model = nil, DonutId = nil, Mutation = "None", Size = "Normal", SpawnedAt = 0, Taken = false, Held = nil, Container = container }
					table.insert(records, record)
				end
			end
		end
	end

	for _, record in records do
		spawnDonut(record, false) -- no announcements for the initial fill
	end

	-- Re-roll donuts that have been sitting around too long so the lane stays fresh, but only
	-- where someone can see them: every re-roll sends a whole new donut model to every player,
	-- and nobody needs fresh donuts in an empty area (they re-roll once someone comes near).
	local REROLL_DISTANCE = 450
	task.spawn(function()
		while true do
			task.wait(5)
			local now = os.clock()
			local positions = {}
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if rootPart then
					table.insert(positions, rootPart.Position)
				end
			end
			for _, record in records do
				if not record.Taken and record.Model and now - record.SpawnedAt > Config.Spawns.Lifetime then
					local here = record.Point.Position
					local watched = false
					for _, position in positions do
						if (position - here).Magnitude < REROLL_DISTANCE then
							watched = true
							break
						end
					end
					if watched then
						spawnDonut(record, true)
						task.wait(0.05)
					end
				end
			end
		end
	end)
end

return DonutSpawnService
