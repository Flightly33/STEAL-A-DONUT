--[[
	CrateService
	============
	Crates (Crates.luau for what's inside, Config.Crates for products and spawning):
	  * Now and then a crate appears somewhere in the lane (any area). Hold E next to it to open it
	    right there - no chase. Epic and Legendary crates are announced to the server.
	  * Crates can be bought in the shop (developer products, granted through ProductService).
	  * Opening rolls ONE reward: coins (scaled to your progress), a Speed Boost (run faster), a
	    server-wide Luck Event, an egg (straight into your incubator) or a pet.

	Paid random items: players whose region doesn't allow them (PolicyService
	ArePaidRandomItemsRestricted) can't buy crates. Until the policy is known we assume they can't.
]]

local PolicyService = game:GetService("PolicyService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Areas = require(Shared.Areas)
local Crates = require(Shared.Crates)
local CrateModel = require(Shared.CrateModel)
local Economy = require(Shared.Economy)
local Pets = require(Shared.Pets)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Build = require(script.Parent.Build)
local MapBuilder = require(script.Parent.MapBuilder)
local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)
local LuckService = require(script.Parent.LuckService)

local CrateService = {}

type Spot = { AreaId: number, Model: Model?, SpawnedAt: number, Container: Instance }

local cfg = Config.Crates
local rng = Random.new()
local spots: { [number]: Spot } = {}

local function notify(player: Player, text: string, kind: string?)
	Remotes.Event("Notify"):FireClient(player, text, kind or "info")
end

--------------------------------------------------------------------------------
-- Opening
--------------------------------------------------------------------------------
export type Result = { Crate: string, Kind: string, Amount: number?, Seconds: number?, Egg: string?, Pet: string? }

-- Open a crate for a player: roll one reward and give it. Returns what they got.
function CrateService.Open(player: Player, crateId: string, source: string?): Result?
	local crate = Crates.ById[crateId]
	local profile = DataService.Get(player)
	if not crate or not profile then
		return nil
	end
	local reward, eggId = Crates.Roll(crate, rng)
	local result: Result = { Crate = crate.Id, Kind = reward.Kind }
	local got: string
	if reward.Kind == "Coins" then
		local amount = Economy.CrateCoins(reward.Seconds or 60, profile.Data.Speed, profile.Data.Rebirths)
		DataService.AddMoney(player, amount, false) -- not "earned": keeps the Money board about playing
		result.Amount = amount
		got = Format.Money(amount)
	elseif reward.Kind == "SpeedBoost" then
		local seconds = reward.Seconds or 600
		profile.Data.SpeedBoostSeconds += seconds
		DataService.SyncSpeedBoost(player)
		result.Seconds = seconds
		got = `a {Format.Duration(seconds)} Speed Boost (run {math.floor((cfg.SpeedBoostMultiplier - 1) * 100 + 0.5)}% faster)`
	elseif reward.Kind == "Luck" then
		local seconds = reward.Seconds or 600
		LuckService.Start(player, seconds, crate.Name)
		result.Seconds = seconds
		got = `a {Format.Duration(seconds)} LUCK EVENT for the whole server`
	elseif reward.Kind == "Egg" and eggId then
		PetService.AddEgg(player, eggId, true)
		result.Egg = eggId
		got = `a {Pets.EggById[eggId].Name}`
	elseif reward.Kind == "Pet" and reward.Pet then
		PetService.GivePet(player, reward.Pet)
		result.Pet = reward.Pet
		got = Pets.ById[reward.Pet].Name
	else
		return nil
	end
	Remotes.Event("CrateOpened"):FireClient(player, result)
	notify(player, `🎁 {crate.Name}: you got {got}!`, "success")
	if crate.Order >= 4 or reward.Kind == "Pet" then
		Remotes.Event("AreaAnnouncement"):FireAllClients(`🎁 {player.DisplayName} opened a {string.upper(crate.Name)} and got {got}!`, crate.Color)
	end
	DataService.PushState(player)
	return result
end

--------------------------------------------------------------------------------
-- Buying (paid random items rules)
--------------------------------------------------------------------------------
-- Look up whether this player may pay for random items (region / age rules).
local function checkPolicy(player: Player)
	if RunService:IsStudio() then
		player:SetAttribute("CratesBlocked", false)
		return
	end
	player:SetAttribute("CratesBlocked", true) -- until we know
	for _ = 1, 3 do
		local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
		if ok and type(info) == "table" then
			player:SetAttribute("CratesBlocked", info.ArePaidRandomItemsRestricted == true)
			return
		end
		task.wait(5)
	end
end

function CrateService.CanBuy(player: Player): boolean
	return player:GetAttribute("CratesBlocked") == false
end

--------------------------------------------------------------------------------
-- Crates in the lane
--------------------------------------------------------------------------------
local function clear(spot: Spot)
	if spot.Model then
		spot.Model:Destroy()
	end
	spot.Model = nil
end

local function spawnCrate(spot: Spot, crate: Crates.Crate, position: Vector3)
	clear(spot)
	local model = CrateModel.Build(crate.Id, { Scale = 1.1 })
	model:PivotTo(CFrame.new(position + Vector3.new(0, ((model:GetAttribute("Bottom") :: number?) or 1.8) + 0.2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model:AddTag("SpinSlow") -- the client turns it slowly (Effects.luau)
	local root = model.PrimaryPart :: BasePart
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CratePrompt"
	prompt.ActionText = "Open Crate"
	prompt.ObjectText = crate.Name
	prompt.HoldDuration = cfg.Found.OpenSeconds
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = root
	prompt.Triggered:Connect(function(player: Player)
		if spot.Model ~= model then
			return
		end
		local profile = DataService.Get(player)
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not profile or not profile.Session.Ready or profile.Session.Stunned or not hrp then
			return
		end
		if (hrp.Position - root.Position).Magnitude > 16 then
			return -- server-side reach check (prompts are client-activated)
		end
		clear(spot)
		CrateService.Open(player, crate.Id, "Found")
	end)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(9, 2)
	gui.StudsOffsetWorldSpace = Vector3.new(0, ((model:GetAttribute("Top") :: number?) or 2) + 2.2, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 160
	gui.Parent = root
	Build.Text(gui, `🎁 {crate.Name}`, { TextColor3 = crate.Color:Lerp(Color3.new(1, 1, 1), 0.35), Font = Enum.Font.FredokaOne })
	model.Parent = spot.Container
	spot.Model = model
	spot.SpawnedAt = os.clock()
	if crate.Order >= 3 then
		local area = Areas.List[spot.AreaId]
		Remotes.Event("AreaAnnouncement"):FireAllClients(`🎁 A {string.upper(crate.Name)} appeared in {area.Name}!`, crate.Color)
	end
end

-- Put a crate in an area right now (admin panel / tests). Returns false if there's no room.
function CrateService.SpawnInArea(areaId: number, crateId: string?): boolean
	local spot = spots[areaId]
	local position = PetService.RandomLanePosition(areaId)
	if not spot or not position then
		return false
	end
	local crate = if crateId then Crates.ById[crateId] else Crates.RollFound(rng)
	if not crate then
		return false
	end
	spawnCrate(spot, crate, position)
	return true
end

function CrateService.GetSpot(areaId: number): Model?
	local spot = spots[areaId]
	return spot and spot.Model
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------
function CrateService.OnPlayerReady(player: Player)
	task.spawn(checkPolicy, player)
end

function CrateService.Init()
	for _, area in Areas.List do
		local folder = Instance.new("Folder")
		folder.Name = "ActiveCrates"
		folder.Parent = MapBuilder.GetArea(area.Id)
		spots[area.Id] = { AreaId = area.Id, Model = nil, SpawnedAt = 0, Container = folder }
	end
	task.spawn(function()
		while true do
			task.wait(cfg.Found.CheckInterval)
			local now = os.clock()
			for areaId, spot in spots do
				if spot.Model and now - spot.SpawnedAt > cfg.Found.Lifetime then
					clear(spot)
				elseif not spot.Model and #Players:GetPlayers() > 0 and rng:NextNumber() < cfg.Found.Chance then
					CrateService.SpawnInArea(areaId)
				end
			end
		end
	end)
end

return CrateService
