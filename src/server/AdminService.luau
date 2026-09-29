--[[
	AdminService
	============
	Type ADMIN_CODE ("ender=cool") in chat to unlock the admin panel for this session: money,
	speed, treadmill, rebirths, any donut (with any mutation/size), eggs, pets, the Luck Event,
	server events, teleporting, flying / magic carpet, and "Domer can't catch me".

	* The code message is never shown to anyone else (TextChannel.ShouldDeliverCallback).
	* With Config.Admin.AllowAnyone on, the code works for everyone. The commands that give away
	  things the game sells (Config.Admin.OwnerOnlyCommands) only work for the game's owner, in
	  Studio, and for Config.Admin.AllowedUserIds.
	* Flying and the magic carpet: the server sets the "FlyMode" attribute, the client flies.
	* Anyone who used the admin panel is kept off the global leaderboards
	  (Config.Admin.HideFromLeaderboards) so the boards stay fair for everyone else.
	* Every command is checked on the server: the client only asks.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Areas = require(Shared.Areas)
local Donuts = require(Shared.Donuts)
local Rarities = require(Shared.Rarities)
local Pets = require(Shared.Pets)
local Events = require(Shared.Events)
local Economy = require(Shared.Economy)
local Layout = require(Shared.Layout)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local TreadmillService = require(script.Parent.TreadmillService)
local DonutSpawnService = require(script.Parent.DonutSpawnService)
local StealService = require(script.Parent.StealService)
local PetService = require(script.Parent.PetService)
local LuckService = require(script.Parent.LuckService)
local CrateService = require(script.Parent.CrateService)
local EventService = require(script.Parent.EventService)
local ShopService = require(script.Parent.ShopService)
local ItemService = require(script.Parent.ItemService)

local AdminService = {}

-- The chat code. It's here (server only) so it can't be read from the client.
local ADMIN_CODE = "ender=cool"

local rng = Random.new()

local function notify(player: Player, text: string, kind: string?)
	Remotes.Event("Notify"):FireClient(player, text, kind or "info")
end

local function isCode(text: any): boolean
	return type(text) == "string" and string.lower((string.gsub(text, "^%s*(.-)%s*$", "%1"))) == ADMIN_CODE
end

-- The game's owner (or someone they trust): can also use the commands that give away paid products.
local function isOwner(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if table.find(Config.Admin.AllowedUserIds, player.UserId) then
		return true
	end
	-- The game's owner always can (for a group game: the group's owner).
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
	return ok and rank == 255
end

local function allowed(player: Player): boolean
	return Config.Admin.AllowAnyone or isOwner(player)
end

local function unlock(player: Player)
	local profile = DataService.Get(player)
	if not profile or not allowed(player) then
		return
	end
	if not profile.Session.Admin then
		profile.Session.Admin = true
		profile.Data.UsedAdmin = true
		player:SetAttribute("Admin", true)
		DataService.PushState(player)
		notify(player, "🛠 Admin panel unlocked! (Admin players don't show up on the global leaderboards)", "success")
	end
	player:SetAttribute("AdminOwner", isOwner(player))
	Remotes.Event("AdminPanel"):FireClient(player)
end

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------
local Commands: { [string]: (Player, DataService.Profile, any) -> () } = {}

function Commands.Money(player: Player, profile: DataService.Profile, amount: any)
	if amount == "x10" then
		DataService.AddMoney(player, math.max(profile.Data.Money, 1000) * 9, false)
	elseif type(amount) == "number" and amount > 0 and amount < 1e30 then
		DataService.AddMoney(player, amount, false)
	end
end

function Commands.Speed(player: Player, profile: DataService.Profile, amount: any)
	if type(amount) == "number" and amount == amount then
		DataService.AddSpeed(player, math.max(amount, -profile.Data.Speed))
	end
end

function Commands.MaxTreadmill(player: Player, profile: DataService.Profile)
	profile.Data.TreadmillLevel = Economy.MaxTreadmillLevel()
	profile.Data.SpeedMultLevel = Config.SpeedMultiplier.MaxLevel
	player:SetAttribute("TreadmillLevel", profile.Data.TreadmillLevel)
	player:SetAttribute("SpeedMultLevel", profile.Data.SpeedMultLevel)
	TreadmillService.Build(player)
end

function Commands.Rebirth(player: Player, profile: DataService.Profile)
	if profile.Data.Rebirths < Economy.MaxRebirths() then
		profile.Data.Rebirths += 1
		player:SetAttribute("Rebirths", profile.Data.Rebirths)
		ShopService.RefreshMultipliers(player)
		notify(player, `🔄 Rebirths: {profile.Data.Rebirths} (all worlds it unlocks are open)`, "success")
	end
end

-- Next base expansion, then the next floor (free)
function Commands.Expand(player: Player, profile: DataService.Profile)
	if Economy.ExpansionCost(profile.Data.Expansions) then
		profile.Data.Expansions += 1
		player:SetAttribute("Expansions", profile.Data.Expansions)
		PlotService.RefreshLocks(player)
		PlotService.ApplySkin(player)
	else
		local floorCost = Economy.NextFloorCost(profile.Data.Expansions, profile.Data.Floors)
		if floorCost then
			DataService.AddMoney(player, floorCost, false)
			PlotService.BuyFloor(player)
		end
	end
end

-- Put any donut on your base: { DonutId, Mutation, Size }
function Commands.Donut(player: Player, profile: DataService.Profile, arg: any)
	if type(arg) ~= "table" or type(arg.DonutId) ~= "string" or not Donuts.ById[arg.DonutId] then
		return
	end
	local mutation = if type(arg.Mutation) == "string" and Rarities.MutationById[arg.Mutation] then arg.Mutation else "None"
	local size = if type(arg.Size) == "string" and Rarities.SizeById[arg.Size] then arg.Size else "Normal"
	if not PlotService.AddDonut(player, arg.DonutId, 1, mutation, size) then
		notify(player, "Your base is full!", "error")
		return
	end
	profile.Data.Discovered[arg.DonutId] = true
	local found = profile.Data.DiscoveredMutations[arg.DonutId] or {}
	found[mutation] = true
	profile.Data.DiscoveredMutations[arg.DonutId] = found
	DataService.PushState(player)
	notify(player, `Added {Rarities.DisplayName(Donuts.ById[arg.DonutId].Name, mutation, size)} to your base`, "success")
end

-- Drop a donut on the closest spawn spot in the lane (to test stealing it): { DonutId, Mutation, Size }
function Commands.SpawnDonut(player: Player, _profile: DataService.Profile, arg: any)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or type(arg) ~= "table" or type(arg.DonutId) ~= "string" then
		return
	end
	local best, bestDistance = nil, math.huge
	for _, record in DonutSpawnService.GetRecords() do
		local distance = (record.Point.Position - root.Position).Magnitude
		if not record.Taken and distance < bestDistance then
			best, bestDistance = record, distance
		end
	end
	if best then
		DonutSpawnService.ForceSpawn(best, arg.DonutId, if type(arg.Mutation) == "string" then arg.Mutation else "None", if type(arg.Size) == "string" then arg.Size else "Normal")
	end
end

function Commands.Egg(player: Player, _profile: DataService.Profile, eggId: any)
	if type(eggId) == "string" and Pets.EggById[eggId] then
		PetService.GiveEgg(player, eggId)
	end
end

function Commands.HatchAll(player: Player)
	PetService.Hatch(player, nil, true)
end

function Commands.Pet(player: Player, profile: DataService.Profile, petId: any)
	if type(petId) == "string" and Pets.ById[petId] and #profile.Data.Pets < Config.Pets.MaxPets then
		table.insert(profile.Data.Pets, { Uid = HttpService:GenerateGUID(false), Id = petId })
		DataService.PushState(player)
		notify(player, `Added pet: {Pets.ById[petId].Name}`, "success")
	end
end

function Commands.Luck(player: Player)
	LuckService.Start(player)
end

-- Open a crate right now (free): crate id
function Commands.OpenCrate(player: Player, _profile: DataService.Profile, crateId: any)
	if type(crateId) == "string" then
		CrateService.Open(player, crateId, "Admin")
	end
end

-- Put a crate in the area you're standing in (or area 1 from the safe zone): crate id
function Commands.SpawnCrate(player: Player, _profile: DataService.Profile, crateId: any)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local areaId = if root then Layout.AreaAt(root.Position) else 0
	if areaId <= 0 then
		areaId = 1
	end
	if type(crateId) == "string" and CrateService.SpawnInArea(areaId, crateId) then
		notify(player, `🎁 {crateId} crate spawned in {Areas.List[areaId].Name}`, "success")
	end
end

-- Start a server event: an event id, or a random one
function Commands.Event(_player: Player, _profile: DataService.Profile, eventId: any)
	if type(eventId) == "string" and Events.ById[eventId] then
		EventService.Start(Events.ById[eventId])
	else
		EventService.Start(Events.Pick(rng))
	end
end

function Commands.GodMode(player: Player, profile: DataService.Profile)
	profile.Session.GodMode = not profile.Session.GodMode
	DataService.PushState(player)
	notify(player, if profile.Session.GodMode then `🛡 {Config.Guard.Name} can't catch you now` else `{Config.Guard.Name} can catch you again`, "success")
end

function Commands.Teleport(player: Player, _profile: DataService.Profile, areaId: any)
	if type(areaId) ~= "number" or not Areas.List[areaId] or StealService.IsCarrying(player) then
		return
	end
	PlotService.MoveBase(player, Areas.List[areaId].World)
	StealService.Teleport(player, Layout.AreaArrival(areaId))
end

function Commands.ResetSpeed(player: Player, profile: DataService.Profile)
	DataService.TrySpendSpeed(player, profile.Data.Speed)
end

-- Flying: "Fly", "Carpet" (a magic carpet under your feet) or anything else to stop. The client does
-- the flying (Flight.luau); the server only says who may.
function Commands.Fly(player: Player, _profile: DataService.Profile, mode: any)
	local value = if mode == "Fly" or mode == "Carpet" then mode else nil
	player:SetAttribute("FlyMode", value)
	notify(player, if value == "Carpet" then "🧞 Magic carpet! Space = up, Shift = down." elseif value then "🕊 You can fly! Space = up, Shift = down." else "Back on your feet.", "success")
end

-- A Base Lock that never runs out (kept when you rejoin), or take it off again.
function Commands.PermaLock(player: Player, profile: DataService.Profile)
	local on = not profile.Data.PermaLock
	ItemService.SetPermanentLock(player, on)
	notify(player, if on then "🔒 Your base is locked for good (press again to unlock)." else "🔓 Permanent lock off.", "success")
end

function Commands.ResetMoney(player: Player, profile: DataService.Profile)
	DataService.TrySpend(player, profile.Data.Money)
	notify(player, "💸 Money reset to $0.", "success")
end

-- Every donut on your base is gone (both floors).
function Commands.ClearDonuts(player: Player)
	PlotService.ClearAll(player)
	notify(player, "🍩 All the donuts on your base were removed.", "success")
end

function Commands.ClearEggs(player: Player, profile: DataService.Profile)
	profile.Data.Eggs = {}
	PetService.OnPlayerReady(player)
end

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------
local function hookChannel(channel: Instance)
	if not channel:IsA("TextChannel") then
		return
	end
	channel.ShouldDeliverCallback = function(message: TextChatMessage, _target: TextSource): boolean
		if isCode(message.Text) then
			local source = message.TextSource
			local sender = if source then Players:GetPlayerByUserId(source.UserId) else nil
			if sender then
				task.defer(unlock, sender)
			end
			return false -- nobody sees the code
		end
		return true
	end
end

function AdminService.Init()
	ShopService.RegisterAction("Admin", function(player: Player, profile, arg: any)
		if not profile.Session.Admin or type(arg) ~= "table" or type(arg.Cmd) ~= "string" then
			return
		end
		local command = Commands[arg.Cmd]
		if command and table.find(Config.Admin.OwnerOnlyCommands, arg.Cmd) and not isOwner(player) then
			notify(player, "Only the game's owner can do that (it's something the game sells).", "error")
			return
		end
		if command then
			command(player, profile, arg.Arg)
		end
	end)

	local function onPlayer(player: Player)
		player.Chatted:Connect(function(message: string)
			if isCode(message) then
				unlock(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	task.spawn(function()
		local channels = TextChatService:WaitForChild("TextChannels", 30)
		if not channels then
			return
		end
		for _, channel in channels:GetChildren() do
			hookChannel(channel)
		end
		channels.ChildAdded:Connect(hookChannel)
	end)
end

return AdminService
