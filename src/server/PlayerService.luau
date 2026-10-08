--[[
	PlayerService
	=============
	Glues everything together for each player:
	  join  -> load data -> check game passes -> assign base -> build treadmill -> offline earnings
	  every second -> base income is paid out, play time ticks up
	  always -> WalkSpeed follows the Speed stat (in a straight line), the world you're in and the
	            donut you carry (or slow mode / stun; a donut stolen from a base forces slow mode)
	  leave -> drop carried donut -> write leaderboards -> save -> free the base
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local TreadmillService = require(script.Parent.TreadmillService)
local StealService = require(script.Parent.StealService)
local ShopService = require(script.Parent.ShopService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local ItemService = require(script.Parent.ItemService)
local InventoryService = require(script.Parent.InventoryService)
local WorldService = require(script.Parent.WorldService)
local PetService = require(script.Parent.PetService)
local CrateService = require(script.Parent.CrateService)

local PlayerService = {}

local leaderstats: { [Player]: { Money: StringValue, Speed: StringValue } } = {}
local clientReady: { [Player]: boolean } = {}

-- Messages that need the player's UI to be listening. Sent once both the data is loaded and
-- the client has said it's ready (whichever happens last).
local function sendWelcome(player: Player)
	local profile = DataService.Get(player)
	if not profile or not profile.Session.Ready or not clientReady[player] then
		return
	end
	DataService.PushState(player)
	local pending = profile.Session.PendingOffline
	if pending then
		profile.Session.PendingOffline = nil
		Remotes.Event("OfflineEarnings"):FireClient(player, pending.Amount, pending.Seconds, pending.Capped)
	end
	if not DataService.DataStoresEnabled() then
		Remotes.Event("Notify"):FireClient(player, "Saving is OFF (enable Studio Access to API Services to test saving)", "error")
	end
end

local function setCollisionGroup(character: Model)
	local function apply(part: Instance)
		if part:IsA("BasePart") then
			part.CollisionGroup = "Players"
		end
	end
	for _, part in character:GetDescendants() do
		apply(part)
	end
	character.DescendantAdded:Connect(apply)
end

local function onCharacterAdded(player: Player, character: Model)
	setCollisionGroup(character)
	StealService.OnCharacterAdded(player, character)
	task.defer(ItemService.GiveTools, player) -- the backpack is recreated on every spawn
	InventoryService.OnCharacterAdded(player) -- (boxes and donuts you're holding: tools too)
	-- Spawn inside your own base
	task.defer(function()
		local spawnCf = PlotService.GetSpawnCFrame(player)
		if spawnCf and character.Parent then
			local root = character:WaitForChild("HumanoidRootPart", 5)
			if root then
				character:PivotTo(spawnCf)
			end
		end
	end)
end

-- The Roblox player list. Its columns must come out in the same order on every device: the
-- client lists stats in the order they reach it, and children that arrive together (a folder
-- parented with its values inside) can come out in any order - which swapped Money and Speed for
-- some players. So the folder goes in first, then one value per frame, Money marked as the main
-- stat (IsPrimary) so it's always the first column.
local function createLeaderstats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	folder.Parent = player
	local function stat(className: string, name: string, primary: boolean?): ValueBase
		local value = Instance.new(className) :: ValueBase
		value.Name = name
		if primary then
			local flag = Instance.new("BoolValue")
			flag.Name = "IsPrimary"
			flag.Value = true
			flag.Parent = value
		end
		return value
	end
	local money = stat("StringValue", "Money", true) :: StringValue
	local speed = stat("StringValue", "Speed") :: StringValue
	leaderstats[player] = { Money = money, Speed = speed }
	task.spawn(function()
		for _, value in { money, speed } :: { ValueBase } do
			if not folder.Parent then
				return
			end
			value.Parent = folder
			task.wait()
		end
	end)
end

local function grantOfflineEarnings(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local last = profile.Data.LastOnline
	if last <= 0 then
		return
	end
	local away = os.time() - last
	if away < Config.Offline.MinSecondsForPopup then
		return
	end
	local seconds = math.min(away, Config.Offline.MaxHours * 3600)
	local perSecond = PlotService.GetBaseIncome(player) * DataService.MoneyMultiplier(profile, true)
	local earned = perSecond * seconds * Config.Offline.Efficiency
	if earned > 0 then
		DataService.AddMoney(player, earned)
		profile.Session.PendingOffline = { Amount = earned, Seconds = seconds, Capped = away > seconds }
	end
end

local function onPlayerAdded(player: Player)
	local profile = DataService.Load(player)
	if not profile or not player.Parent then
		return
	end
	ShopService.LoadOwnership(player)
	if not player.Parent then
		return
	end

	local plotIndex = PlotService.Assign(player)
	if not plotIndex then
		player:Kick("This server is full. Please join another server!")
		return
	end
	TreadmillService.Build(player)
	InventoryService.SyncTools(player)
	createLeaderstats(player)
	grantOfflineEarnings(player)

	profile.Session.Ready = true
	player:SetAttribute("World", 1)
	player:SetAttribute("Donated", profile.Data.Donated)
	DataService.SyncAttributes(player)
	DataService.CheckTrails(player) -- (saves from before trails: already fast enough for one)
	PetService.OnPlayerReady(player) -- pets' bonuses (money multiplier), followers, incubator
	CrateService.OnPlayerReady(player) -- may this player buy crates? (paid random items rules)
	DataService.PushState(player)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
	sendWelcome(player)
end

local function onPlayerRemoving(player: Player)
	StealService.OnPlayerRemoving(player)
	PetService.OnPlayerRemoving(player)
	ShopService.OnPlayerRemoving(player)
	ItemService.OnPlayerRemoving(player)
	WorldService.OnPlayerRemoving(player)
	task.spawn(LeaderboardService.OnPlayerRemoving, player) -- reads data immediately, then yields on web calls
	TreadmillService.Remove(player)
	PlotService.Release(player)
	leaderstats[player] = nil
	clientReady[player] = nil
	DataService.Release(player) -- yields while saving
end

local function desiredWalkSpeed(player: Player, profile: DataService.Profile): number
	if profile.Session.Stunned or player:GetAttribute("Frozen") then
		return 0
	end
	-- Admin panel "speed" command
	local adminSpeed = player:GetAttribute("AdminWalkSpeed")
	if type(adminSpeed) == "number" then
		return adminSpeed
	end
	local carrySize = player:GetAttribute("CarrySize")
	local carry = Economy.CarrySpeed(if type(carrySize) == "string" then carrySize else nil)
	-- The run speed typed in Settings caps how fast you go (0 = as fast as you can)
	local full = Economy.PlayerWalkSpeed(profile.Data.Speed, profile.Session.World) * DataService.WalkBoost(profile.Data)
	local limit = profile.Data.SpeedLimit
	local speed = if limit > 0 then math.min(full, math.max(limit, Config.Speed.MinRunSpeed)) else full
	return speed * carry
end

function PlayerService.Init()
	Remotes.Event("ClientReady").OnServerEvent:Connect(function(player: Player)
		if not clientReady[player] then
			clientReady[player] = true
			sendWelcome(player)
		end
	end)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- Income + play time (once per second, using real elapsed time so nothing drifts)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1)
			local now = os.clock()
			local dt = now - last
			last = now
			for player, profile in DataService.GetAll() do
				if profile.Session.Ready and player.Parent then
					local income = PlotService.GetBaseIncome(player) * DataService.MoneyMultiplier(profile)
					if income > 0 then
						DataService.AddMoney(player, income * dt)
					end
					profile.Data.PlayTime += dt
					-- Crate Speed Boost counts down while you play
					if profile.Data.SpeedBoostSeconds > 0 then
						profile.Data.SpeedBoostSeconds = math.max(0, profile.Data.SpeedBoostSeconds - dt)
						if profile.Data.SpeedBoostSeconds <= 0 then
							DataService.SyncSpeedBoost(player)
							Remotes.Event("Notify"):FireClient(player, "Your Speed Boost ran out.", "info")
						end
					end
					player:SetAttribute("Income", income)
					player:SetAttribute("PlayTime", profile.Data.PlayTime)
					local stats = leaderstats[player]
					if stats then
						stats.Money.Value = Format.Money(profile.Data.Money)
						stats.Speed.Value = Format.Number(profile.Data.Speed)
					end
				end
			end
		end
	end)

	-- WalkSpeed follows the Speed stat
	task.spawn(function()
		while true do
			task.wait(0.25)
			for player, profile in DataService.GetAll() do
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if humanoid and profile.Session.Ready then
					local target = desiredWalkSpeed(player, profile)
					if math.abs(humanoid.WalkSpeed - target) > 0.05 then
						humanoid.WalkSpeed = target
					end
					player:SetAttribute("WalkSpeed", Economy.PlayerWalkSpeed(profile.Data.Speed, profile.Session.World) * DataService.WalkBoost(profile.Data))
				end
			end
		end
	end)
end

return PlayerService
