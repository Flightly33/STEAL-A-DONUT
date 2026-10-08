--[[
	MeteorService: the Cosmic Meteor (shared/Meteor). 45 seconds into the Eternal Storm
	(Config.CosmicDonut.MeteorAt: EventService starts it, while Config.CosmicDonut is on) a huge
	meteor shatters the sky and crashes into one of biomes 2-6 (Config.CosmicDonut.Biomes; in the
	front half of the biome, away from its Domer). Every client plays the show on
	the same clock (client/MeteorFX: the white screen, the shaking, the sky cracking, the fall); here
	it lands - anyone right under it is flung - and cracks open in a crater with its shards lying
	round it (Config.CosmicDonut.Pieces). Then Cosmic Domer climbs out of a black hole over the
	crater (GiantService).

	A shard is carried like an egg (StealService.StartCustom): one at a time, nobody chases you, and
	it's yours once you're back over the lobby line (Data.MeteorShards). Get flung or knocked and it
	drops right there for anyone to grab. When the storm ends (EventService calls Clear) the crater
	and every shard left on the ground evaporate (client/MeteorFX draws it); one you're carrying is
	still yours to bring home, but drop it after that and it evaporates too. Spend them at the
	Cosmic Forge (CraftService).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Areas = require(Shared.Areas)
local Layout = require(Shared.Layout)
local Meteor = require(Shared.Meteor)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local StealService = require(script.Parent.StealService)
local ItemService = require(script.Parent.ItemService)
local GiantService = require(script.Parent.GiantService)

local MeteorService = {}

local COSMIC = Config.CosmicDonut
local LEAD = 0.5 -- seconds between telling the clients and the show starting (so it starts in sync)
local REACH = 14 -- how close you have to be to take a shard

local rng = Random.new()
local folder: Folder? = nil
local landing = 0 -- (bumped by Clear: a meteor still on its way doesn't land)
local active = false -- a meteor has landed this storm (its shards can lie on the ground)

local function notify(player: Player, text: string, kind: string?)
	Remotes.Event("Notify"):FireClient(player, text, kind or "info")
end

local function getFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "MeteorSite"
	f.Parent = workspace
	folder = f
	return f
end

-- Where it lands: one of the first biomes, in the front half and near the middle of the lane.
local function landingSpot(): (Vector3, number)
	local first = math.clamp(COSMIC.Biomes[1], 1, #Areas.List)
	local last = math.clamp(COSMIC.Biomes[2], first, #Areas.List)
	local areaId = rng:NextInteger(first, last)
	local from, to = Layout.AreaStart(areaId), Layout.AreaEnd(areaId)
	local z = rng:NextNumber(from + math.min(70, (to - from) * 0.2), (from + to) / 2)
	local half = Layout.AreaHalfWidth(areaId)
	return Vector3.new(rng:NextNumber(-half * 0.3, half * 0.3), 0, z), areaId
end

local take: (Player, Model) -> ()

-- A shard lying on the ground, glowing, waiting to be taken.
local function placeShard(at: Vector3, seed: number): Model
	local shard = Meteor.BuildShard(1.6, seed)
	shard:PivotTo(CFrame.new(at.X, 0, at.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	shard:SetAttribute("ExpiresAt", os.clock() + COSMIC.ShardLife)
	local holder = shard.PrimaryPart :: BasePart
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(190, 110, 255)
	light.Range = 14
	light.Brightness = 2
	light.Parent = holder
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(Color3.fromRGB(230, 200, 255), Color3.fromRGB(120, 230, 255))
	sparkle.LightEmission = 1
	sparkle.Rate = 6
	sparkle.Lifetime = NumberRange.new(0.8, 1.4)
	sparkle.Speed = NumberRange.new(1, 3)
	sparkle.Size = NumberSequence.new(0.6, 0)
	sparkle.Parent = holder
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TakeShard"
	prompt.ActionText = "Take shard"
	prompt.ObjectText = "Meteor Shard"
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = REACH - 2
	prompt.RequiresLineOfSight = false
	prompt.Parent = holder
	prompt.Triggered:Connect(function(player: Player)
		take(player, shard)
	end)
	shard.Parent = getFolder()
	return shard
end

-- Back over the lobby line with it: one more shard.
local function deposit(player: Player): boolean
	local profile = DataService.Get(player)
	if not profile then
		return false
	end
	local data = profile.Data
	data.MeteorShards += 1
	DataService.PushState(player)
	Remotes.Event("ChaseEnded"):FireClient(player, { Result = "Deposited", Kind = "Shard", Count = data.MeteorShards, Cost = COSMIC.ShardCost })
	notify(player, if data.MeteorShards >= COSMIC.ShardCost
		then `{data.MeteorShards} meteor shards! Craft THE COSMIC DONUT at the Cosmic Forge by the spawn!`
		else `Meteor shard secured! {data.MeteorShards}/{COSMIC.ShardCost} for The Cosmic Donut`, "success")
	return true
end

-- Fade it away (every client draws the evaporating: client/MeteorFX), then remove it.
local function evaporate(model: Instance)
	if model:GetAttribute("EvaporateAt") then
		return
	end
	model:SetAttribute("EvaporateAt", workspace:GetServerTimeNow())
	for _, prompt in model:GetDescendants() do
		if prompt:IsA("ProximityPrompt") then
			prompt.Enabled = false
		end
	end
	task.delay(Meteor.EVAPORATE + 0.2, function()
		model:Destroy()
	end)
end

take = function(player: Player, shard: Model)
	if not shard.Parent or shard:GetAttribute("EvaporateAt") then
		return
	end
	local root = StealService.CanPickUp(player, shard:GetPivot().Position, REACH + 4)
	if not root then
		return
	end
	local started = StealService.StartCustom(player, {
		Kind = "Shard",
		DonutId = "MeteorShard",
		Level = 1,
		Mutation = "None",
		Size = "Normal",
		Record = nil,
		AreaId = 0, -- (nobody chases you for it)
		Secured = false,
		LastPos = root.Position,
		LastTime = os.clock(),
		DepositInLobby = true,
		OnDeposit = deposit,
		OnLost = function(loser: Player)
			-- it drops right where you are (on the ground, inside the lane's walls), for anyone to grab
			local character = loser.Character
			local at = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local spot = if at then at.Position else root.Position
			local area = Layout.AreaAt(spot)
			if area > 0 then
				local half = Layout.AreaHalfWidth(area) - 4
				spot = Vector3.new(math.clamp(spot.X, -half, half), 0, spot.Z)
			end
			local dropped = placeShard(spot, rng:NextInteger(1, 1_000_000))
			if not active then
				evaporate(dropped) -- (the storm's over: it doesn't stay)
			end
		end,
	})
	if started then
		shard:Destroy()
	end
end

-- It hits: whoever's under it is flung, the crater and the shards appear.
local function land(at: Vector3, seed: number, myLanding: number)
	if landing ~= myLanding then
		return -- (the storm ended before it got here)
	end
	active = true
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local offset = root.Position - at
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= Meteor.CRATER / 2 + 8 and offset.Y < 60 then
				ItemService.Fling(player, at, COSMIC.FlingPower)
			end
		end
	end
	local site = getFolder()
	for _, old in site:GetChildren() do
		old:Destroy() -- (anything left from an earlier meteor)
	end
	local crater = Meteor.BuildShell(at, seed)
	crater:SetAttribute("ExpiresAt", os.clock() + COSMIC.ShardLife)
	crater.Parent = site
	local r = Random.new(seed)
	for i = 1, COSMIC.Pieces do
		local angle = i / COSMIC.Pieces * math.pi * 2 + r:NextNumber(-0.2, 0.2)
		local distance = Meteor.CRATER * r:NextNumber(0.6, 1.1)
		placeShard(at + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance, seed + i)
	end
	-- and Cosmic Domer climbs out of a black hole over it (GiantService)
	GiantService.Start(at)
end

-- Start the show (EventService, 45 seconds into the storm). Returns where it'll land.
function MeteorService.Start(): Vector3?
	if not COSMIC.Enabled then
		return nil
	end
	local at, areaId = landingSpot()
	local seed = rng:NextInteger(1, 1_000_000)
	Remotes.Event("Meteor"):FireAllClients({ Position = at, StartAt = workspace:GetServerTimeNow() + LEAD, Seed = seed, Area = areaId })
	-- (the announcement waits until the white screen has gone)
	task.delay(LEAD + Meteor.SHATTER_AT, function()
		Remotes.Event("AreaAnnouncement"):FireAllClients(`A COSMIC METEOR IS CRASHING INTO {string.upper(Areas.List[areaId].Name)}! GRAB ITS SHARDS!`, Color3.fromRGB(200, 120, 255))
	end)
	task.delay(LEAD + Meteor.IMPACT_AT, land, at, seed, landing)
	return at
end

-- The storm's over (EventService): the crater and every shard left on the ground evaporate.
function MeteorService.Clear()
	landing += 1
	active = false
	if folder then
		for _, child in folder:GetChildren() do
			evaporate(child)
		end
	end
end

-- The shards lying on the ground right now (tests, the admin panel).
function MeteorService.Shards(): { Model }
	local list = {}
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("Model") and child.Name == "MeteorShard" then
				table.insert(list, child)
			end
		end
	end
	return list
end

MeteorService.Take = function(player: Player, shard: Model)
	take(player, shard)
end

function MeteorService.Init()
	-- shards nobody took, and the crater, evaporate after a while (if the storm hasn't ended first)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 1 or not folder then
			return
		end
		accumulator = 0
		local now = os.clock()
		for _, child in folder:GetChildren() do
			local expires = child:GetAttribute("ExpiresAt")
			if type(expires) == "number" and now >= expires then
				evaporate(child)
			end
		end
	end)
end

return MeteorService
