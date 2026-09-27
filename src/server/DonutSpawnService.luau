--[[
	DonutSpawnService
	=================
	Keeps a donut on every spawn point in the lane. Donuts are rolled from their area's weighted pool,
	re-rolled if nobody steals them for a while, and respawn a few seconds after being stolen.
	Rare spawns are announced to the whole server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Areas = require(Shared.Areas)
local Donuts = require(Shared.Donuts)
local Rarities = require(Shared.Rarities)
local DonutModel = require(Shared.DonutModel)
local Remotes = require(Shared.Remotes)

local MapBuilder = require(script.Parent.MapBuilder)

local DonutSpawnService = {}

export type SpawnRecord = {
	Point: BasePart,
	AreaId: number,
	Model: Model?,
	DonutId: string?,
	SpawnedAt: number,
	Taken: boolean,
	Container: Instance,
}

local records: { SpawnRecord } = {}
local rng = Random.new()
local stealHandler: ((Player, SpawnRecord) -> ())? = nil

-- StealService registers itself here (avoids a circular require).
function DonutSpawnService.SetStealHandler(handler: (Player, SpawnRecord) -> ())
	stealHandler = handler
end

local function spawnDonut(record: SpawnRecord, announce: boolean)
	if record.Model then
		record.Model:Destroy()
		record.Model = nil
	end
	local donut = Donuts.Roll(record.AreaId, rng)
	local model = DonutModel.Build(donut, { Scale = 0.95, Pillar = true })
	DonutModel.PlaceOn(model, record.Point.CFrame)
	model:SetAttribute("Area", record.AreaId)
	local root = model.PrimaryPart :: BasePart

	local info = DonutModel.CreateBillboard(donut, donut.Income, nil, (model:GetAttribute("Top") :: number?) or 3)
	info.Parent = root

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = "Steal"
	prompt.ObjectText = donut.Name
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 11
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
	record.SpawnedAt = os.clock()
	record.Taken = false

	local rarity = Rarities.Get(donut.Rarity)
	if announce and rarity.Order >= Config.Spawns.AnnounceRarity then
		local area = Areas.List[record.AreaId]
		Remotes.Event("AreaAnnouncement"):FireAllClients(`A {string.upper(rarity.Id)} donut appeared in {area.Name}: {donut.Name}!`, rarity.Color)
	end
end

-- Remove the donut from its spawn point (it was stolen). Returns the donut id.
function DonutSpawnService.Take(record: SpawnRecord): string?
	if record.Taken or not record.Model or not record.DonutId then
		return nil
	end
	local donutId = record.DonutId
	record.Taken = true
	record.Model:Destroy()
	record.Model = nil
	record.DonutId = nil
	task.delay(rng:NextNumber(Config.Spawns.RespawnMin, Config.Spawns.RespawnMax), function()
		if record.Taken then
			spawnDonut(record, true)
		end
	end)
	return donutId
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
					local record: SpawnRecord = { Point = point, AreaId = areaId, Model = nil, DonutId = nil, SpawnedAt = 0, Taken = false, Container = container }
					table.insert(records, record)
				end
			end
		end
	end

	for _, record in records do
		spawnDonut(record, false) -- no announcements for the initial fill
	end

	-- Re-roll donuts that have been sitting around too long so the lane stays fresh.
	task.spawn(function()
		while true do
			task.wait(5)
			local now = os.clock()
			for _, record in records do
				if not record.Taken and record.Model and now - record.SpawnedAt > Config.Spawns.Lifetime then
					spawnDonut(record, true)
					task.wait(0.05)
				end
			end
		end
	end)
end

return DonutSpawnService
