--[[
	AdminService
	============
	Type ADMIN_CODE ("ender=cool") in chat to unlock the admin panel for this session: money,
	speed, treadmill, rebirths, any donut (with any mutation/size), eggs, pets, the Luck Event,
	server events, teleporting, flying / magic carpet, and "Domer can't catch me".

	* The code message is never shown to anyone else (TextChannel.ShouldDeliverCallback).
	* With Config.Admin.AllowAnyone on, the code works for everyone, and so does every command
	  (Config.Admin.OwnerOnlyCommands can list commands only the owner may use).
	* HD Admin-style commands on any player (HDAdmin.luau); the owner can't be targeted by others.
	* Flying and the magic carpet: the server sets the "FlyMode" attribute, the client flies.
	* Anyone who used the admin panel is kept off the global leaderboards
	  (Config.Admin.HideFromLeaderboards) so the boards stay fair for everyone else.
	* The game's owner (Studio, the creator / group owner, or Config.Admin.AllowedUserIds) has the
	  panel from the moment they join, without the code, and can take anyone else's admin away
	  (saved: the code stops working for them) or give it back.
	* Every command is checked on the server: the client only asks.

	Type SIZE_CODE ("ender=rich") instead to get ONLY the BIGGER BASE buttons (a small 🏢 BASE
	window and HUD button, no admin panel), for this session, up to Config.Admin.MaxSlots donuts.
	Also hidden from chat, also off for anyone the owner took admin away from.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
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
local HDAdmin = require(script.Parent.HDAdmin)
local Ownership = require(script.Parent.Ownership)

local AdminService = {}

-- The chat code. It's here (server only) so it can't be read from the client.
local ADMIN_CODE = "ender=cool"
local SIZE_CODE = "ender=rich" -- just the bigger-base buttons

local rng = Random.new()

local function notify(player: Player, text: string, kind: string?)
	Remotes.Event("Notify"):FireClient(player, text, kind or "info")
end

local function normalized(text: any): string?
	return if type(text) == "string" then string.lower((string.gsub(text, "^%s*(.-)%s*$", "%1"))) else nil
end

local function isCode(text: any): boolean
	return normalized(text) == ADMIN_CODE
end

local function isSizeCode(text: any): boolean
	return normalized(text) == SIZE_CODE
end

-- The game's owner (or someone they trust): can also use the commands that give away paid products.
local isOwner = Ownership.IsOwner

local function allowed(player: Player): boolean
	return Config.Admin.AllowAnyone or isOwner(player)
end

-- Give a player the admin panel. `quietly` (the owner joining, or the owner giving it back) doesn't
-- pop the panel open: it just says the 🛠 ADMIN button is there.
local function unlock(player: Player, quietly: string?)
	local profile = DataService.Get(player)
	if not profile or not allowed(player) then
		return
	end
	if profile.Data.AdminRevoked and not isOwner(player) then
		notify(player, "🚫 The game's owner took your admin access away.", "error")
		return
	end
	if not profile.Session.Admin then
		profile.Session.Admin = true
		if not quietly then
			profile.Data.UsedAdmin = true
		end
		player:SetAttribute("Admin", true)
		DataService.PushState(player)
		notify(player, quietly or "🛠 Admin panel unlocked! (Admin players don't show up on the global leaderboards)", "success")
	end
	player:SetAttribute("AdminOwner", isOwner(player))
	if not quietly then
		Remotes.Event("AdminPanel"):FireClient(player)
	end
end

-- The base code: only the 🏢 BIGGER BASE buttons (the client opens the window when "SizeAccess"
-- is set).
local function unlockSize(player: Player)
	local profile = DataService.Get(player)
	if not profile or not allowed(player) then
		return
	end
	if profile.Data.AdminRevoked and not isOwner(player) then
		notify(player, "🚫 The game's owner took your admin access away.", "error")
		return
	end
	if not profile.Session.SizeAccess then
		profile.Session.SizeAccess = true
		player:SetAttribute("SizeAccess", true)
		notify(player, `🏢 Base builder unlocked! Make your base bigger (up to {Config.Admin.MaxSlots} donuts) with the 🏢 BASE button.`, "success")
	end
end

-- Make the base `count` sizes bigger (up to Config.Admin.MaxSlots donuts, past the sizes you can
-- buy), or smaller with a negative count (down to the smallest base). Donuts that don't fit a
-- smaller base stay saved and come back when it grows again.
local function growBase(player: Player, profile: DataService.Profile, count: any)
	local cap = Economy.AdminMaxBaseLevel()
	local change = math.floor(tonumber(count) or 1)
	if change < 0 then
		if profile.Data.BaseLevel <= 1 then
			notify(player, "🏢 Your base is already as small as it gets!", "error")
			return
		end
		profile.Data.BaseLevel = math.max(profile.Data.BaseLevel + math.max(change, -cap), 1)
		DataService.SyncAttributes(player)
		PlotService.RefreshPen(player)
		notify(player, `🏢 Your base holds {PlotService.GetSlotCount(player)} donuts now (any that don't fit are kept safe until it's bigger again).`, "success")
		return
	end
	if profile.Data.BaseLevel >= cap then
		notify(player, `🏢 Your base already holds {Economy.SlotCount(cap)} donuts, as big as a base gets!`, "error")
		return
	end
	local add = math.clamp(change, 1, cap)
	profile.Data.BaseLevel = math.min(profile.Data.BaseLevel + add, cap)
	DataService.SyncAttributes(player)
	PlotService.RefreshPen(player)
	notify(player, `🏢 Your base holds {PlotService.GetSlotCount(player)} donuts now!`, "success")
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

-- The next bigger base (free)
function Commands.Expand(player: Player, profile: DataService.Profile)
	if Economy.BaseSizeCost(profile.Data.BaseLevel) then
		profile.Data.BaseLevel += 1
		DataService.SyncAttributes(player)
		PlotService.RefreshPen(player)
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
function Commands.Event(player: Player, _profile: DataService.Profile, eventId: any)
	local event = if type(eventId) == "string" then Events.ById[eventId] else nil
	if event and event.OwnerOnly and not isOwner(player) then
		notify(player, `👑 Only the game's owner can start the {event.Name}.`, "error")
		return
	end
	if event then
		EventService.Start(event)
	else
		-- (a random event is never an owner-only one)
		local pick = Events.Pick(rng)
		while pick.OwnerOnly do
			pick = Events.Pick(rng)
		end
		EventService.Start(pick)
	end
end

-- Owner only: the Eternal Storm, right now.
function Commands.EternalStorm(player: Player)
	if not isOwner(player) then
		notify(player, "👑 Only the game's owner can start the Eternal Storm.", "error")
		return
	end
	EventService.StartById("EternalStorm")
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

-- Every donut on your base is gone.
function Commands.ClearDonuts(player: Player)
	PlotService.ClearAll(player)
	notify(player, "🍩 All the donuts on your base were removed.", "success")
end

-- HD Admin-style player commands (kill, bring, jail, kick, speed, noclip...): see HDAdmin.luau.
function Commands.HD(player: Player, _profile: DataService.Profile, arg: any)
	HDAdmin.Run(player, arg)
end

-- Who an admin-access command is for: a player's UserId, or "others" / "all" (never yourself).
local function adminTargets(caller: Player, target: any): { Player }
	local list = {}
	for _, other in Players:GetPlayers() do
		if other ~= caller and (target == "all" or target == "others" or target == other.UserId) then
			table.insert(list, other)
		end
	end
	return list
end

-- Owner only: take someone's admin panel away. It's saved, so typing the code again doesn't work
-- for them (in any server) until the owner gives it back. The owner can't lose theirs.
function Commands.RevokeAdmin(player: Player, _profile: DataService.Profile, target: any)
	if not isOwner(player) then
		notify(player, "Only the game's owner can remove admins.", "error")
		return
	end
	local count = 0
	for _, other in adminTargets(player, target) do
		local profile = DataService.Get(other)
		if profile and not isOwner(other) then
			profile.Data.AdminRevoked = true
			profile.Session.Admin = false
			profile.Session.GodMode = false
			profile.Session.SizeAccess = false
			other:SetAttribute("Admin", false)
			other:SetAttribute("SizeAccess", nil)
			other:SetAttribute("AdminOwner", false)
			other:SetAttribute("FlyMode", nil)
			DataService.PushState(other)
			notify(other, "🚫 The game's owner took your admin access away.", "error")
			count += 1
		end
	end
	notify(player, `🚫 Admin removed from {count} player{if count == 1 then "" else "s"}`, "success")
end

-- Owner only: give someone their admin panel back.
function Commands.RestoreAdmin(player: Player, _profile: DataService.Profile, target: any)
	if not isOwner(player) then
		notify(player, "Only the game's owner can give admin back.", "error")
		return
	end
	local count = 0
	for _, other in adminTargets(player, target) do
		local profile = DataService.Get(other)
		if profile and profile.Data.AdminRevoked then
			profile.Data.AdminRevoked = false
			unlock(other, "🛠 The game's owner gave you admin! Press the 🛠 ADMIN button.")
			count += 1
		end
	end
	notify(player, `✅ Admin given back to {count} player{if count == 1 then "" else "s"}`, "success")
end

-- The admin panel's 👑 bigger-base buttons: the owner, or anyone who typed the base code.
function Commands.GrowBase(player: Player, profile: DataService.Profile, count: any)
	if not isOwner(player) and not profile.Session.SizeAccess then
		notify(player, "👑 Only the game's owner can make bases that big.", "error")
		return
	end
	growBase(player, profile, count)
end

-- Owner only: put the 👑 Owner's Throne skin on your base (or back to the Classic one).
function Commands.OwnerSkin(player: Player, profile: DataService.Profile)
	if not isOwner(player) then
		notify(player, "👑 Only the game's owner can use that skin!", "error")
		return
	end
	profile.Data.EquippedSkin = if profile.Data.EquippedSkin == "Owner" then "Classic" else "Owner"
	PlotService.ApplySkin(player)
	DataService.PushState(player)
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
		local admin, size = isCode(message.Text), isSizeCode(message.Text)
		if admin or size then
			local source = message.TextSource
			local sender = if source then Players:GetPlayerByUserId(source.UserId) else nil
			if sender then
				task.defer(if admin then unlock else unlockSize, sender)
			end
			return false -- nobody sees the code
		end
		return true
	end
end

function AdminService.Init()
	HDAdmin.IsOwner = isOwner
	HDAdmin.Init()
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
			profile.Data.UsedAdmin = true
			command(player, profile, arg.Arg)
		end
	end)
	-- The 🏢 BASE window (the base code, or the owner)
	ShopService.RegisterAction("GrowBase", function(player: Player, profile, count: any)
		if profile.Session.SizeAccess or isOwner(player) then
			growBase(player, profile, count)
		end
	end)

	-- The game's owner always has the admin panel, without typing the code
	DataService.ProfileLoaded:Connect(function(player: Player)
		if isOwner(player) then
			unlock(player, "🛠 Welcome back, owner! Your admin panel is on the 🛠 ADMIN button.")
		end
	end)

	local function onPlayer(player: Player)
		player.Chatted:Connect(function(message: string)
			if isCode(message) then
				unlock(player)
			elseif isSizeCode(message) then
				unlockSize(player)
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
