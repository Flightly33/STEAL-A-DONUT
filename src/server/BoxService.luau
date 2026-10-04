--[[
	BoxService
	==========
	The donut boxes in the biomes (Boxes.luau / Config.Boxes):
	  * Every biome's Domer guards Config.Boxes.PerBiome boxes on the spots in front of his corner
	    (MapBuilder BoxSpots). Each box is a rarity tier, a size and maybe a mutation (rolled when it
	    appears; Luck Events and server events make better boxes more likely).
	  * Every ResetInterval seconds EVERY box in every biome is replaced by a fresh batch and
	    everyone sees "ALL BOXES RESET!". A box someone takes leaves its spot empty until then.
	  * If Domer catches the thief inside the box's own biome (or they drop it there), the SAME box
	    goes straight back onto its spot (Return) - unless the boxes reset since it was taken.
	  * A box knocked out of someone's hands anywhere else (a bat, or caught / dropped outside its own
	    biome) lands on the ground right there (Drop): anyone can pick it up, and the box's own
	    Domer chases whoever does. It vanishes after DroppedLifetime seconds or at the next reset.
	  * The Eternal Storm's lightning can turn a box Eternal (Eternalize): it opens into an Eternal
	    donut.

	StealService handles what happens once a box is picked up (SetStealHandler).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Areas = require(Shared.Areas)
local Boxes = require(Shared.Boxes)
local BoxModel = require(Shared.BoxModel)
local Rarities = require(Shared.Rarities)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local MapBuilder = require(script.Parent.MapBuilder)
local Build = require(script.Parent.Build)

local BoxService = {}

export type BoxRecord = {
	Id: number,
	AreaId: number, -- the biome the box belongs to (its Domer chases whoever has it)
	Spot: BasePart?, -- its spot (nil for a box lying on the ground)
	Tier: string,
	Size: string,
	Mutation: string,
	Model: Model?,
	Taken: boolean,
	Batch: number, -- which reset it's from
	DroppedAt: number?, -- (on the ground) when it was dropped
	Planted: boolean?, -- put there with the admin panel
}

export type ServerLuck = { Rarity: number, Mutation: number, Size: number }

local spots: { [number]: { BasePart } } = {}
local records: { BoxRecord } = {} -- every box on a spot or on the ground
local stealHandler: ((Player, BoxRecord) -> ())? = nil
local rng = Random.new()
local batch = 0
local nextId = 0
local serverLuck: ServerLuck? = nil
local eventRarity = 1
local areaLuck: { [number]: { Luck: number, Boost: string? } } = {}

-- Set by LuckService while a Luck Event runs (nil when it ends).
function BoxService.SetServerLuck(luck: ServerLuck?)
	serverLuck = luck
end

-- Set by EventService while a server event runs: better boxes everywhere (1 = none).
function BoxService.SetEventRarity(luck: number?)
	eventRarity = luck or 1
end

-- Set by EventService: extra mutation luck in one biome.
function BoxService.SetAreaLuck(areaId: number, luck: number?, boost: string?)
	if luck then
		areaLuck[areaId] = { Luck = luck, Boost = boost }
	else
		areaLuck[areaId] = nil
	end
end

-- StealService registers itself here (avoids a circular require).
function BoxService.SetStealHandler(handler: (Player, BoxRecord) -> ())
	stealHandler = handler
end

function BoxService.GetBatch(): number
	return batch
end

local function newId(): number
	nextId += 1
	return nextId
end

-- Seconds until the next reset (clients read the "BoxReset" attribute on workspace instead).
local nextReset = 0
function BoxService.SecondsToReset(): number
	return math.max(0, nextReset - os.clock())
end

local function destroyModel(record: BoxRecord)
	if record.Model then
		record.Model:Destroy()
		record.Model = nil
	end
end

local function remove(record: BoxRecord)
	destroyModel(record)
	local index = table.find(records, record)
	if index then
		table.remove(records, index)
	end
end

-- Build the box's model where it belongs (its spot, or where it was dropped) with its prompt.
local function show(record: BoxRecord, cf: CFrame)
	destroyModel(record)
	local model = BoxModel.Build(record.Tier, record.Size, { Mutation = record.Mutation, Area = record.AreaId })
	BoxModel.PlaceOn(model, cf)
	model:SetAttribute("BoxId", record.Id)
	model:SetAttribute("Ground", record.Spot == nil)
	-- (clients make boxes bob and turn gently, and show their name over them)
	CollectionService:AddTag(model, "LaneBox")
	local scale = Boxes.Size(record.Size).Scale
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = if record.Spot then "Steal" else "Pick up"
	prompt.ObjectText = Rarities.DisplayName(Boxes.DisplayName(record.Tier, record.Size), record.Mutation, nil)
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = Config.Boxes.StealSeconds
	prompt.MaxActivationDistance = 10 + 4 * scale
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player: Player)
		if stealHandler and record.Model == model then
			stealHandler(player, record)
		end
	end)
	-- its name floating over it (in its rarity's colour) and how long it takes to open
	local label = Instance.new("BillboardGui")
	label.Name = "BoxLabel"
	label.Size = UDim2.fromScale(10, 2.5)
	label.StudsOffsetWorldSpace = Vector3.new(0, ((model:GetAttribute("Top") :: number?) or 3) + 2.3, 0)
	label.LightInfluence = 0
	label.MaxDistance = 140
	label.Parent = model.PrimaryPart
	Build.Text(label, prompt.ObjectText, { Size = UDim2.fromScale(1, 0.6), TextColor3 = (if record.Mutation ~= "None" then Rarities.Mutation(record.Mutation).Color else Boxes.Tier(record.Tier).Color):Lerp(Color3.new(1, 1, 1), 0.25), TextStrokeColor3 = Color3.fromRGB(25, 15, 25), TextStrokeTransparency = 0 })
	Build.Text(label, `Opens in {Format.Duration(Boxes.HatchSeconds(record.Tier, record.Size))}`, { Name = "OpenTime", Size = UDim2.fromScale(1, 0.38), Position = UDim2.fromScale(0, 0.62), Font = Enum.Font.FredokaOne, TextColor3 = Color3.fromRGB(255, 255, 255), TextStrokeColor3 = Color3.fromRGB(25, 15, 25), TextStrokeTransparency = 0 })
	-- a glowing ring on the ground under the better boxes, so they stand out from far away
	local tier = Boxes.Tier(record.Tier)
	if Boxes.Rank(record.AreaId, record.Tier) >= 2 or record.Mutation ~= "None" then
		local color = if record.Mutation ~= "None" then Rarities.Mutation(record.Mutation).Color else tier.Color
		local ring = Build.Decor({ Parent = model, Name = "GroundRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 9 * scale, 9 * scale), CFrame = cf * CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = color, Material = Enum.Material.Neon, Transparency = 0.5 })
		ring.CastShadow = false
	end
	model.Parent = MapBuilder.GetArea(record.AreaId)
	record.Model = model
end

local function spotCFrame(spot: BasePart): CFrame
	-- facing the lobby, with a little random turn so a row of boxes doesn't look stamped out
	local turn = ((spot:GetAttribute("Index") :: number?) or 0) * 0.37
	return CFrame.new(spot.Position - Vector3.new(0, spot.Size.Y / 2 + 0.4, 0)) * CFrame.Angles(0, math.pi + turn, 0)
end

-- A fresh random box for a spot.
local function roll(areaId: number): (string, string, string)
	local global = serverLuck
	local tierLuck = (if global then global.Rarity else 1) * eventRarity
	local tier = Boxes.RollTier(areaId, rng, if tierLuck ~= 1 then tierLuck else nil)
	local size = Boxes.RollSize(rng, if global then global.Size else nil)
	local luck = areaLuck[areaId]
	local mutationLuck = (if luck then luck.Luck else 1) * (if global then global.Mutation else 1)
	local mutation = Rarities.RollMutation(rng, mutationLuck, if luck then luck.Boost else nil)
	return tier.Id, size.Id, mutation.Id
end

local function fillSpot(areaId: number, spot: BasePart)
	local tier, size, mutation = roll(areaId)
	local record: BoxRecord = {
		Id = newId(),
		AreaId = areaId,
		Spot = spot,
		Tier = tier,
		Size = size,
		Mutation = mutation,
		Model = nil,
		Taken = false,
		Batch = batch,
	}
	table.insert(records, record)
	show(record, spotCFrame(spot))
end

-- Replace every box in every biome with a fresh batch (boxes being carried right now are kept by
-- their thieves; boxes on the ground vanish).
function BoxService.ResetAll()
	batch += 1
	for _, record in table.clone(records) do
		if not record.Taken then
			remove(record)
		end
	end
	for areaId, list in spots do
		for _, spot in list do
			fillSpot(areaId, spot)
		end
	end
	nextReset = os.clock() + Config.Boxes.ResetInterval
	workspace:SetAttribute("BoxReset", workspace:GetServerTimeNow() + Config.Boxes.ResetInterval)
	Remotes.Event("BoxesReset"):FireAllClients()
end

-- The box is picked up: take it off its spot (or off the ground). Returns false if it's gone.
function BoxService.Take(record: BoxRecord): boolean
	if record.Taken or not record.Model then
		return false
	end
	record.Taken = true
	destroyModel(record)
	return true
end

-- The thief was caught (or dropped it) inside its biome: put it back on its spot, if its batch is
-- still out. A box from the ground just goes back on the ground where it was picked up.
function BoxService.Return(record: BoxRecord, groundAt: Vector3?)
	if record.Spot and record.Batch == batch then
		record.Taken = false
		show(record, spotCFrame(record.Spot))
	elseif not record.Spot and groundAt then
		BoxService.Drop(record, groundAt)
	else
		remove(record)
	end
end

-- A spot by `areaId`'s Domer that no box is using (nil if they all are).
local function freeSpot(areaId: number): BasePart?
	local list: { BasePart } = spots[areaId] or {}
	for _, spot in list do
		local used = false
		for _, other in records do
			if other.Spot == spot then
				used = true
				break
			end
		end
		if not used then
			return spot
		end
	end
	return nil
end

-- Domer caught the thief: he takes the box back to his corner - onto its own spot, or (a box that
-- came off the ground, or one from before the last reset) onto a free spot next to him. If every
-- spot already has a box, he keeps it: it's gone.
function BoxService.ReturnToDomer(record: BoxRecord)
	if record.Spot and record.Batch == batch then
		record.Taken = false
		record.DroppedAt = nil
		show(record, spotCFrame(record.Spot))
		return
	end
	record.Spot = nil -- (an old spot from before a reset isn't its own any more)
	local spot = freeSpot(record.AreaId)
	if not spot then
		remove(record)
		return
	end
	record.Spot = spot
	record.Batch = batch
	record.Taken = false
	record.DroppedAt = nil
	record.Planted = nil
	if not table.find(records, record) then
		table.insert(records, record)
	end
	show(record, spotCFrame(spot))
end

-- The box made it to the lobby (it's in someone's inventory now): its spot stays empty.
function BoxService.Release(record: BoxRecord)
	remove(record)
end

-- Put a box on the ground at `position` (knocked out of someone's hands): anyone can pick it up.
function BoxService.Drop(record: BoxRecord, position: Vector3)
	record.Spot = nil
	record.Taken = false
	record.DroppedAt = os.clock()
	if not table.find(records, record) then
		table.insert(records, record)
	end
	local cf = CFrame.new(position.X, 0, position.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	show(record, cf)
end

-- A box straight onto the ground (the admin panel).
function BoxService.Plant(areaId: number, position: Vector3, tier: string, size: string, mutation: string?): BoxRecord
	local record: BoxRecord = {
		Id = newId(),
		AreaId = areaId,
		Spot = nil,
		Tier = tier,
		Size = size,
		Mutation = mutation or "None",
		Model = nil,
		Taken = false,
		Batch = batch,
		Planted = true,
	}
	BoxService.Drop(record, position)
	return record
end

-- Every box waiting on a spot right now (the Eternal Storm's lightning picks from these).
function BoxService.GetWaiting(areaId: number?): { BoxRecord }
	local list = {}
	for _, record in records do
		if not record.Taken and record.Model and (areaId == nil or record.AreaId == areaId) then
			table.insert(list, record)
		end
	end
	return list
end

-- The Eternal Storm's purple lightning hit this box: it opens into an Eternal donut.
function BoxService.Eternalize(record: BoxRecord): boolean
	if record.Taken or not record.Model or record.Mutation == "Eternal" then
		return false
	end
	local cf = record.Model:GetPivot()
	record.Mutation = "Eternal"
	show(record, cf)
	return true
end

function BoxService.GetRecords(): { BoxRecord }
	return records
end

function BoxService.Init()
	for _, area in Areas.List do
		spots[area.Id] = MapBuilder.GetBoxSpots(area.Id)
	end
	BoxService.ResetAll()
	task.spawn(function()
		while true do
			task.wait(1)
			if os.clock() >= nextReset then
				BoxService.ResetAll()
			end
			-- boxes left lying on the ground vanish after a while
			local now = os.clock()
			for _, record in table.clone(records) do
				if not record.Spot and not record.Taken and record.DroppedAt and now - record.DroppedAt > Config.Boxes.DroppedLifetime then
					remove(record)
				end
			end
		end
	end)
end

return BoxService
