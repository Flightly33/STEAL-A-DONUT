--[[
	PetService
	==========
	Pet eggs and pets (see Pets.luau / Config.Pets):
	  * Every Config.Pets.EggCheckInterval seconds each area that can have eggs (Pets.EggsForArea)
	    may get one somewhere in the lane. It glows (rarer eggs are more mystical) and vanishes after
	    a while if nobody grabs it. Rare eggs are announced to the server.
	  * Grab it like a donut: your guard wakes up and chases you. Lose it and it goes back to its
	    spot. Bring it into your base and it goes into your incubator (next to your treadmill).
	  * An incubating egg hatches after its HatchSeconds (real time, also while you're offline).
	    Hatch it from the Pets window: it becomes a random pet from that egg's pool.
	  * Equip up to Config.Pets.MaxEquipped pets for money / treadmill speed bonuses. Equipped pets
	    follow you around (drawn by every client from the player's "Pets" attribute).
	  * Incubator upgrades (bought in the Shop): faster hatching and room for more eggs.
	  * Server events: Egg Shower (every area keeps getting eggs) and 2x Incubator Speed.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Areas = require(Shared.Areas)
local Pets = require(Shared.Pets)
local PetModel = require(Shared.PetModel)
local Layout = require(Shared.Layout)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Economy = require(Shared.Economy)

local Build = require(script.Parent.Build)
local MapBuilder = require(script.Parent.MapBuilder)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local TreadmillService = require(script.Parent.TreadmillService)
local StealService = require(script.Parent.StealService)

local PetService = {}

type EggSpot = {
	AreaId: number,
	Model: Model?,
	EggId: string?,
	Position: Vector3,
	SpawnedAt: number,
	Taken: boolean,
	Container: Instance,
}

local cfg = Config.Pets
local rng = Random.new()
local spots: { [number]: EggSpot } = {} -- one egg at a time per area
local lastFullWarning: { [Player]: number } = {}
local eggLuck = 1
local eggShower = false -- Egg Shower event
local hatchBoost = 1 -- 2x Incubator Speed event

local function notify(player: Player, text: string, kind: string?)
	Remotes.Event("Notify"):FireClient(player, text, kind or "info")
end

-- Set by LuckService while a Luck Event runs.
function PetService.SetEggLuck(luck: number)
	eggLuck = luck
end

-- Set by EventService: eggs keep dropping in every area while an Egg Shower runs.
function PetService.SetEggShower(on: boolean)
	eggShower = on
end

-- Set by EventService: every incubator runs `mult` x as fast (1 = normal).
function PetService.SetHatchBoost(mult: number)
	hatchBoost = mult
end

-- How many eggs a player's incubator holds, and how fast it hatches (upgrades).
function PetService.Capacity(profile: DataService.Profile): number
	return Economy.IncubatorCapacity(profile.Data.IncubatorSize)
end

--------------------------------------------------------------------------------
-- Player state
--------------------------------------------------------------------------------
local function findPet(data: DataService.Data, uid: string): (DataService.PetData?, number?)
	for index, pet in data.Pets do
		if pet.Uid == uid then
			return pet, index
		end
	end
	return nil, nil
end

-- Equipped pets changed: update bonuses, followers and everything that shows them.
local function refreshPets(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local data = profile.Data
	-- Drop equipped uids that no longer exist
	local valid = {}
	for _, uid in data.EquippedPets do
		if findPet(data, uid) and #valid < cfg.MaxEquipped and not table.find(valid, uid) then
			table.insert(valid, uid)
		end
	end
	data.EquippedPets = valid
	player:SetAttribute("Pets", table.concat(DataService.EquippedPetIds(data), ","))
	player:SetAttribute("PetSpeedBonus", DataService.PetSpeedBonus(data))
	player:SetAttribute("MoneyMultiplier", DataService.MoneyMultiplier(profile))
	TreadmillService.Refresh(player)
	PlotService.RefreshSign(player)
	DataService.PushState(player)
end

--------------------------------------------------------------------------------
-- Incubator at the base
--------------------------------------------------------------------------------
local function rebuildIncubator(player: Player, plot: Model?)
	local target = plot or PlotService.GetPlotModel(player)
	if not target then
		return
	end
	local old = target:FindFirstChild("Incubator")
	if old then
		old:Destroy()
	end
	local profile = DataService.Get(player)
	local anchor = target:FindFirstChild("IncubatorAnchor") :: BasePart?
	if not profile or not anchor or plot then
		return -- (a plot passed in explicitly is one the base just left: only clear it)
	end
	local incubator = Instance.new("Model")
	incubator.Name = "Incubator"
	local cf = anchor.CFrame
	-- A glowing nest of straw with a sign
	Build.Part({ Parent = incubator, Name = "Nest", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 13, 13), CFrame = cf * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(190, 150, 80), Material = Enum.Material.Grass })
	local rim = Build.Decor({ Parent = incubator, Name = "NestRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 14, 14), CFrame = cf * CFrame.new(0, 1.1, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(255, 200, 90), Material = Enum.Material.Neon, Transparency = 0.5 })
	local warmth = Instance.new("PointLight")
	warmth.Color = Color3.fromRGB(255, 190, 110)
	warmth.Range = 16
	warmth.Brightness = 1.2
	warmth.Parent = rim
	local signHolder = Build.Part({ Parent = incubator, Name = "SignHolder", Size = Vector3.one, CFrame = cf * CFrame.new(0, 9, 0), Transparency = 1, CanCollide = false, CanQuery = false })
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromScale(14, 2.4)
	sign.LightInfluence = 0
	sign.MaxDistance = 110
	sign.Parent = signHolder
	local count = #profile.Data.Eggs
	local capacity = PetService.Capacity(profile)
	local label = if count > capacity then `INCUBATOR ({count} eggs)` else `INCUBATOR {count}/{capacity}`
	Build.Text(sign, label, { TextColor3 = Color3.fromRGB(255, 225, 140), TextStrokeColor3 = Color3.fromRGB(60, 30, 0) })

	for i, eggData in profile.Data.Eggs do
		local egg = Pets.EggById[eggData.Id]
		if egg then
			local angle = (i - 1) / math.max(count, 1) * math.pi * 2
			local radius = if count <= 1 then 0 else math.max(3.6, count * 0.6)
			local model = PetModel.BuildEgg(egg, { Scale = 1.05 })
			local bottom = (model:GetAttribute("Bottom") :: number?) or 1.5
			model:PivotTo(cf * CFrame.new(math.cos(angle) * radius, 1.2 + bottom, math.sin(angle) * radius))
			model:SetAttribute("HatchAt", eggData.HatchAt)
			model:SetAttribute("Uid", eggData.Uid)
			model.Parent = incubator
			-- Countdown label (the text is updated by each client from HatchAt)
			local gui = Instance.new("BillboardGui")
			gui.Name = "EggTimer"
			gui.Size = UDim2.fromScale(7, 1.8)
			gui.StudsOffsetWorldSpace = Vector3.new(0, ((model:GetAttribute("Top") :: number?) or 1.5) + 1.6, 0)
			gui.LightInfluence = 0
			gui.MaxDistance = 80
			gui.Parent = model.PrimaryPart
			Build.Text(gui, egg.Name, { Name = "EggName", Size = UDim2.fromScale(1, 0.5), TextColor3 = egg.Accent:Lerp(Color3.new(1, 1, 1), 0.4), Font = Enum.Font.FredokaOne })
			Build.Text(gui, "", { Name = "Countdown", Size = UDim2.fromScale(1, 0.5), Position = UDim2.fromScale(0, 0.5), TextColor3 = Color3.fromRGB(255, 255, 255) })
		end
	end
	incubator.Parent = target
end

-- Add an egg to the player's incubator. `force` (crate rewards) goes past the incubator limit, so a
-- reward is never lost.
function PetService.AddEgg(player: Player, eggId: string, force: boolean?): boolean
	local profile = DataService.Get(player)
	local egg = Pets.EggById[eggId]
	if not profile or not egg then
		return false
	end
	if #profile.Data.Eggs >= PetService.Capacity(profile) and not force then
		return false
	end
	local seconds = egg.HatchSeconds / Economy.IncubatorSpeed(profile.Data.IncubatorSpeed)
	table.insert(profile.Data.Eggs, { Uid = HttpService:GenerateGUID(false), Id = egg.Id, HatchAt = os.time() + seconds })
	rebuildIncubator(player)
	DataService.PushState(player)
	return true
end

-- Hatch one egg (uid) or every ready egg (uid = nil). `force` skips the timer (admin panel).
function PetService.Hatch(player: Player, uid: string?, force: boolean?)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local data = profile.Data
	local now = os.time()
	local hatched = 0
	local index = 1
	while index <= #data.Eggs do
		local eggData = data.Eggs[index]
		local egg = Pets.EggById[eggData.Id]
		local wanted = uid == nil or eggData.Uid == uid
		if wanted and egg and (force or now >= eggData.HatchAt) then
			if #data.Pets >= cfg.MaxPets then
				notify(player, `Your pet inventory is full ({cfg.MaxPets})! Release a pet first.`, "error")
				break
			end
			table.remove(data.Eggs, index)
			local pet = Pets.RollPet(egg, rng)
			local petData = { Uid = HttpService:GenerateGUID(false), Id = pet.Id }
			table.insert(data.Pets, petData)
			hatched += 1
			Remotes.Event("EggHatched"):FireClient(player, { EggId = egg.Id, PetId = pet.Id, Uid = petData.Uid })
			local rarity = Pets.Rarity(pet.Rarity)
			if rarity.Order >= 6 then
				Remotes.Event("AreaAnnouncement"):FireAllClients(`{player.DisplayName} hatched a {string.upper(rarity.Id)} {pet.Name}! ({string.format("%.2g", Pets.Chance(egg, pet.Id) * 100)}% chance)`, rarity.Color)
			end
			-- Auto-equip into a free pet slot
			if #data.EquippedPets < cfg.MaxEquipped then
				table.insert(data.EquippedPets, petData.Uid)
			end
		elseif wanted and uid then
			notify(player, "That egg isn't ready yet!", "error")
			index += 1
		else
			index += 1
		end
	end
	if hatched > 0 then
		rebuildIncubator(player)
		refreshPets(player)
	elseif uid == nil then
		notify(player, "No eggs are ready to hatch yet.", "error")
	end
end

function PetService.Equip(player: Player, uid: any)
	local profile = DataService.Get(player)
	if not profile or type(uid) ~= "string" or not findPet(profile.Data, uid) then
		return
	end
	local equipped = profile.Data.EquippedPets
	if table.find(equipped, uid) then
		return
	end
	if #equipped >= cfg.MaxEquipped then
		notify(player, `You can equip {cfg.MaxEquipped} pets at once. Unequip one first.`, "error")
		return
	end
	table.insert(equipped, uid)
	refreshPets(player)
end

function PetService.Unequip(player: Player, uid: any)
	local profile = DataService.Get(player)
	if not profile or type(uid) ~= "string" then
		return
	end
	local index = table.find(profile.Data.EquippedPets, uid)
	if index then
		table.remove(profile.Data.EquippedPets, index)
		refreshPets(player)
	end
end

-- Equip the pets with the biggest total bonus.
function PetService.EquipBest(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local list = table.clone(profile.Data.Pets)
	table.sort(list, function(a, b)
		local pa, pb = Pets.ById[a.Id], Pets.ById[b.Id]
		return (if pa then pa.Money + pa.Speed else 0) > (if pb then pb.Money + pb.Speed else 0)
	end)
	local equipped = {}
	for i = 1, math.min(cfg.MaxEquipped, #list) do
		table.insert(equipped, list[i].Uid)
	end
	profile.Data.EquippedPets = equipped
	refreshPets(player)
end

function PetService.Release(player: Player, uid: any)
	local profile = DataService.Get(player)
	if not profile or type(uid) ~= "string" then
		return
	end
	local pet, index = findPet(profile.Data, uid)
	if pet and index then
		table.remove(profile.Data.Pets, index)
		local equippedIndex = table.find(profile.Data.EquippedPets, uid)
		if equippedIndex then
			table.remove(profile.Data.EquippedPets, equippedIndex)
		end
		local def = Pets.ById[pet.Id]
		notify(player, `Released {if def then def.Name else "your pet"}. Bye bye!`)
		refreshPets(player)
	end
end

--------------------------------------------------------------------------------
-- Eggs in the lane
--------------------------------------------------------------------------------
local spawnEgg: (spot: EggSpot, eggId: string, announce: boolean) -> ()

local function clearSpot(spot: EggSpot)
	if spot.Model then
		spot.Model:Destroy()
	end
	spot.Model = nil
	spot.EggId = nil
	spot.Taken = false
end

local function tryGrab(player: Player, spot: EggSpot, model: Model)
	if spot.Model ~= model or spot.Taken or not spot.EggId then
		return
	end
	if not StealService.CanPickUp(player, model:GetPivot().Position, 18) then
		return
	end
	local profile = DataService.Get(player)
	if profile and #profile.Data.Eggs >= PetService.Capacity(profile) then
		notify(player, `Your incubator is full ({PetService.Capacity(profile)} eggs)! Hatch some eggs first, or upgrade it in the Shop.`, "error")
		return
	end
	local egg = Pets.EggById[spot.EggId]
	local eggId = spot.EggId
	spot.Taken = true
	model:Destroy()
	spot.Model = nil
	-- (the egg in your hands is drawn by every client from your Carry* attributes)
	local started = StealService.StartCustom(player, {
		Kind = "Egg",
		DonutId = eggId,
		Level = 1,
		Mutation = "None",
		Size = "Normal",
		Record = nil,
		AreaId = spot.AreaId,
		Secured = false,
		LastPos = Vector3.zero,
		LastTime = 0,
		OnDeposit = function(carrier: Player): boolean
			if PetService.AddEgg(carrier, eggId) then
				clearSpot(spot)
				notify(carrier, `{egg.Name} is in your incubator! It hatches in {Format.Duration(egg.HatchSeconds)}.`, "success")
				Remotes.Event("ChaseEnded"):FireClient(carrier, { Result = "Deposited", Kind = "Egg", EggId = eggId })
				return true
			end
			local now = os.clock()
			if not lastFullWarning[carrier] or now - lastFullWarning[carrier] > 4 then
				lastFullWarning[carrier] = now
				local carrierProfile = DataService.Get(carrier)
				local capacity = if carrierProfile then PetService.Capacity(carrierProfile) else cfg.MaxEggs
				notify(carrier, `Your incubator is full ({capacity} eggs)! Hatch some eggs first, or upgrade it in the Shop.`, "error")
			end
			return false
		end,
		OnLost = function()
			-- Back to its spot
			spot.Taken = false
			spawnEgg(spot, eggId, false)
		end,
	})
	if not started then
		spot.Taken = false
		spawnEgg(spot, eggId, false)
	end
end

function spawnEgg(spot: EggSpot, eggId: string, announce: boolean)
	local egg = Pets.EggById[eggId]
	if not egg then
		return
	end
	if spot.Model then
		spot.Model:Destroy()
	end
	local model = PetModel.BuildEgg(egg, { Scale = 1.1, Pillar = true })
	local bottom = (model:GetAttribute("Bottom") :: number?) or 1.6
	model:PivotTo(CFrame.new(spot.Position + Vector3.new(0, bottom + 0.3, 0)))
	local root = model.PrimaryPart :: BasePart
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EggPrompt"
	prompt.ActionText = "Grab Egg"
	prompt.ObjectText = `{egg.Name} (hatches in {Format.Duration(egg.HatchSeconds)})`
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		tryGrab(player, spot, model)
	end)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(8, 2)
	gui.StudsOffsetWorldSpace = Vector3.new(0, ((model:GetAttribute("Top") :: number?) or 1.6) + 1.8, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 140
	gui.Parent = root
	Build.Text(gui, `{egg.Name}`, { TextColor3 = egg.Accent:Lerp(Color3.new(1, 1, 1), 0.3), Font = Enum.Font.FredokaOne })
	model.Parent = spot.Container
	spot.Model = model
	spot.EggId = eggId
	spot.SpawnedAt = os.clock()
	spot.Taken = false
	if announce and egg.Tier >= 5 then
		local area = Areas.List[spot.AreaId]
		Remotes.Event("AreaAnnouncement"):FireAllClients(`A {string.upper(egg.Name)} appeared in {area.Name}!`, egg.Accent)
	end
end

-- A random spot in the biome, away from Domer's corner and his boxes.
-- (Crates use it too: PetService.RandomLanePosition.)
local function randomPosition(areaId: number): Vector3?
	local home = Layout.GuardHome(areaId)
	local half = Layout.AreaHalfWidth(areaId) - 20
	for _ = 1, 30 do
		local candidate = Vector3.new(rng:NextNumber(-half, half), 0, rng:NextNumber(Layout.AreaStart(areaId) + 25, Layout.AreaEnd(areaId) - 40))
		if (Vector3.new(home.X, 0, home.Z) - candidate).Magnitude > Layout.BoxRadius + 25 then
			return candidate
		end
	end
	return nil
end

-- Give a pet directly (crate rewards, admin panel). Goes past the pet limit so a reward is never lost.
function PetService.GivePet(player: Player, petId: string): boolean
	local profile = DataService.Get(player)
	local pet = Pets.ById[petId]
	if not profile or not pet then
		return false
	end
	local data = profile.Data
	local petData = { Uid = HttpService:GenerateGUID(false), Id = pet.Id }
	table.insert(data.Pets, petData)
	if #data.EquippedPets < cfg.MaxEquipped then
		table.insert(data.EquippedPets, petData.Uid)
	end
	refreshPets(player)
	return true
end

function PetService.RandomLanePosition(areaId: number): Vector3?
	return randomPosition(areaId)
end

--------------------------------------------------------------------------------
-- Incubator upgrades
--------------------------------------------------------------------------------
-- kind: "Speed" (hatch faster) or "Size" (more eggs at once). Paid with money.
function PetService.BuyUpgrade(player: Player, kind: any)
	local profile = DataService.Get(player)
	if not profile or (kind ~= "Speed" and kind ~= "Size") then
		return
	end
	local data = profile.Data
	local level = if kind == "Speed" then data.IncubatorSpeed else data.IncubatorSize
	local cost = Economy.IncubatorUpgradeCost(kind, level)
	if not cost then
		notify(player, "That incubator upgrade is maxed!", "error")
		return
	end
	if not DataService.TrySpend(player, cost) then
		notify(player, "Not enough money! Need " .. Format.Money(cost), "error")
		return
	end
	if kind == "Speed" then
		-- Eggs already incubating speed up too
		local old, new = Economy.IncubatorSpeed(level), Economy.IncubatorSpeed(level + 1)
		local now = os.time()
		for _, eggData in data.Eggs do
			local left = eggData.HatchAt - now
			if left > 0 then
				eggData.HatchAt = now + left * old / new
			end
		end
		data.IncubatorSpeed = level + 1
		player:SetAttribute("IncubatorSpeed", data.IncubatorSpeed)
		notify(player, `Incubator speed x{Format.Multiplier(new)}! Eggs hatch faster.`, "success")
	else
		data.IncubatorSize = level + 1
		player:SetAttribute("IncubatorSize", data.IncubatorSize)
		notify(player, `Your incubator now holds {PetService.Capacity(profile)} eggs!`, "success")
	end
	rebuildIncubator(player)
	DataService.PushState(player)
end

--------------------------------------------------------------------------------
-- Admin helpers
--------------------------------------------------------------------------------
function PetService.GiveEgg(player: Player, eggId: string)
	if not PetService.AddEgg(player, eggId) then
		notify(player, "Incubator full (or unknown egg).", "error")
	end
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------
function PetService.OnPlayerReady(player: Player)
	refreshPets(player)
	rebuildIncubator(player)
end

function PetService.OnPlayerRemoving(player: Player)
	lastFullWarning[player] = nil
	local plot = PlotService.GetPlotModel(player)
	local incubator = plot and plot:FindFirstChild("Incubator")
	if incubator then
		incubator:Destroy()
	end
end

function PetService.Init()
	for _, area in Areas.List do
		if #Pets.EggsForArea(area.Id) > 0 then
			local folder = Instance.new("Folder")
			folder.Name = "ActiveEggs"
			folder.Parent = MapBuilder.GetArea(area.Id)
			spots[area.Id] = { AreaId = area.Id, Model = nil, EggId = nil, Position = Vector3.zero, SpawnedAt = 0, Taken = false, Container = folder }
		end
	end

	-- Egg Shower: every area that can have eggs keeps getting one
	task.spawn(function()
		while true do
			task.wait(3)
			if eggShower then
				for areaId, spot in spots do
					if not spot.Taken and not spot.Model then
						local egg = Pets.RollEgg(areaId, rng)
						local position = randomPosition(areaId)
						if egg and position then
							spot.Position = position
							spawnEgg(spot, egg.Id, false)
						end
					end
				end
			end
		end
	end)

	-- 2x Incubator Speed: eggs of everyone in the server count down faster
	task.spawn(function()
		local last = os.clock()
		local pushed = 0
		while true do
			task.wait(1)
			local now = os.clock()
			local dt = now - last
			last = now
			if hatchBoost > 1 then
				pushed += dt
				for player, profile in DataService.GetAll() do
					if profile.Session.Ready and #profile.Data.Eggs > 0 then
						for _, eggData in profile.Data.Eggs do
							eggData.HatchAt -= dt * (hatchBoost - 1)
						end
						-- Move the countdowns above the eggs in the incubator along
						local plot = PlotService.GetPlotModel(player)
						local incubator = plot and plot:FindFirstChild("Incubator")
						if incubator then
							for _, model in incubator:GetChildren() do
								local uid = model:GetAttribute("Uid")
								for _, eggData in profile.Data.Eggs do
									if eggData.Uid == uid then
										model:SetAttribute("HatchAt", eggData.HatchAt)
									end
								end
							end
						end
						if pushed >= 5 then
							DataService.PushState(player)
						end
					end
				end
				if pushed >= 5 then
					pushed = 0
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(cfg.EggCheckInterval)
			local now = os.clock()
			for areaId, spot in spots do
				if spot.Taken then
					continue
				end
				if spot.Model and now - spot.SpawnedAt > cfg.EggLifetime then
					clearSpot(spot)
				elseif not spot.Model and rng:NextNumber() < cfg.EggChance * eggLuck and #Players:GetPlayers() > 0 then
					local egg = Pets.RollEgg(areaId, rng)
					local position = randomPosition(areaId)
					if egg and position then
						spot.Position = position
						spawnEgg(spot, egg.Id, true)
					end
				end
			end
		end
	end)
end

return PetService
