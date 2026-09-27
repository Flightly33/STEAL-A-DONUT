--[[
	DataService
	===========
	Loads/saves player data with DataStoreService, including:
	  * session locking (a player's data can't be loaded by two servers at once -> no rollbacks)
	  * autosave every Config.Data.AutosaveInterval seconds
	  * save on leave and on server shutdown (BindToClose)
	  * automatic fallback to temporary data in Studio when API access is disabled

	Every other service reads/writes player data through here.
]]

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Donuts = require(Shared.Donuts)
local Economy = require(Shared.Economy)
local Signal = require(Shared.Signal)
local Remotes = require(Shared.Remotes)

local DataService = {}

export type SlotData = { Id: string, Level: number, Mutation: string?, Size: string? }
export type EggData = { Uid: string, Id: string, HatchAt: number } -- HatchAt: os.time() when it's ready
export type PetData = { Uid: string, Id: string }

export type Data = {
	Version: number,
	Money: number,
	TotalEarned: number,
	Speed: number,
	TreadmillLevel: number,
	SpeedMultLevel: number,
	Slots: { [string]: SlotData },
	Discovered: { [string]: boolean },
	DiscoveredMutations: { [string]: { [string]: boolean } }, -- donutId -> mutations found
	IndexClaims: { [string]: string }, -- donutId -> "Cash" | "Speed"
	BestDonutScore: number,
	BestSpeed: number,
	Rebirths: number,
	Expansions: number,
	PlayTime: number,
	LastOnline: number,
	OwnedSkins: { [string]: boolean },
	EquippedSkin: string,
	CachedPasses: { [string]: boolean },
	PodiumMode: string,
	MusicVolume: number,
	MusicOn: boolean,
	Items: { [string]: boolean },
	Eggs: { EggData },
	Pets: { PetData },
	EquippedPets: { string }, -- pet Uids
	Buddy: string?, -- donut id following you around
	Donated: number, -- Robux donated
	Purchases: { string }, -- the last developer product receipts granted (PurchaseIds), newest last
	UsedAdmin: boolean, -- opened the admin panel (kept off the global leaderboards)
	SessionLock: { JobId: string, Time: number }?,
}

export type Profile = {
	Player: Player,
	Data: Data,
	Passes: { [string]: boolean }, -- owned game passes this session
	SessionSkins: { [string]: boolean }, -- Studio test purchases (never saved)
	Session: { SlowMode: boolean, Stunned: boolean, Ready: boolean, World: number, PendingOffline: { Amount: number, Seconds: number, Capped: boolean }?, Admin: boolean, GodMode: boolean },
	NoSave: boolean,
}

local DATA_VERSION = 3

local TEMPLATE: Data = {
	Version = DATA_VERSION,
	Money = 0,
	TotalEarned = 0,
	Speed = 0,
	TreadmillLevel = 1,
	SpeedMultLevel = 0,
	Slots = {},
	Discovered = {},
	DiscoveredMutations = {},
	IndexClaims = {},
	BestDonutScore = 0,
	BestSpeed = 0,
	Rebirths = 0,
	Expansions = 0,
	PlayTime = 0,
	LastOnline = 0,
	OwnedSkins = { Classic = true },
	EquippedSkin = "Classic",
	CachedPasses = {},
	PodiumMode = "Rarest",
	MusicVolume = Config.Music.DefaultVolume,
	MusicOn = true,
	Items = {},
	Eggs = {},
	Pets = {},
	EquippedPets = {},
	Buddy = nil,
	Donated = 0,
	Purchases = {},
	UsedAdmin = false,
}

DataService.ProfileLoaded = Signal.new() -- (player, profile)

local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil
local dataStoresEnabled = true
local saving: { [Player]: boolean } = {}

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in value :: any do
		copy[key] = deepCopy(inner)
	end
	return copy :: any
end

-- Fill in keys that were added to TEMPLATE after this player's data was first saved.
local function reconcile(data: { [string]: any }, template: { [string]: any })
	for key, value in template do
		if data[key] == nil then
			data[key] = deepCopy(value)
		end
	end
end

-- Upgrade data saved by older versions of the game.
local function migrate(data: Data, isNew: boolean)
	if data.Version < 2 then
		if not isNew then
			-- Everyone used to have 12 stands: keep them (12 = 8 to start + 1 expansion).
			data.Expansions = math.max(data.Expansions, 1)
		end
		-- "Rarest donut" scores used to be rarity * 1000 + index.
		if data.BestDonutScore > 0 and data.BestDonutScore < 10_000 then
			local donut = Donuts.FromScore(data.BestDonutScore)
			data.BestDonutScore = if donut then donut.Score else 0
		end
		data.BestSpeed = math.max(data.BestSpeed, data.Speed)
		data.Version = 2
	end
	if data.Version < 3 then
		-- Version 3: the Speed stat became linear (WalkSpeed = 16 + Speed / 10). Convert old Speed
		-- so you keep exactly the WalkSpeed you had; skins bought with the old huge numbers stay owned.
		if not isNew then
			local function convert(old: number): number
				return math.floor(Economy.StatForWalkSpeed(Economy.LegacyWalkSpeed(old)))
			end
			data.Speed = convert(data.Speed)
			data.BestSpeed = convert(data.BestSpeed)
			-- Speed Multiplier levels used to go to 40 (x1.25 each); the new ones add +5% up to 20.
			data.SpeedMultLevel = math.min(data.SpeedMultLevel, Config.SpeedMultiplier.MaxLevel)
		end
		data.Version = 3
	end
end

-- Pet ids of the pets the player has equipped.
function DataService.EquippedPetIds(data: Data): { string }
	local ids = {}
	for _, uid in data.EquippedPets do
		for _, pet in data.Pets do
			if pet.Uid == uid then
				table.insert(ids, pet.Id)
				break
			end
		end
	end
	return ids
end

-- Total money multiplier: game passes x rebirths x equipped pets.
function DataService.MoneyMultiplier(profile: Profile): number
	local petMoney = Economy.PetBonuses(DataService.EquippedPetIds(profile.Data))
	return Economy.MoneyMultiplier(profile.Passes) * Economy.RebirthMoneyMultiplier(profile.Data.Rebirths) * (1 + petMoney)
end

-- Speed bonus from equipped pets (0.25 = +25% treadmill speed).
function DataService.PetSpeedBonus(data: Data): number
	local _, speed = Economy.PetBonuses(DataService.EquippedPetIds(data))
	return speed
end

-- Total Index treadmill bonus in % (from rewards claimed as Speed).
function DataService.IndexSpeedBonus(data: Data): number
	local total = 0
	for donutId, kind in data.IndexClaims do
		if kind == "Speed" then
			total += Economy.IndexSpeedReward(donutId) or 0
		end
	end
	return total
end

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

--------------------------------------------------------------------------------
-- Loading
--------------------------------------------------------------------------------
local function loadData(player: Player): (Data?, boolean)
	if not dataStoresEnabled or not store then
		return deepCopy(TEMPLATE), true
	end
	local ds = store :: DataStore
	local lockSeconds = Config.Data.SessionLockSeconds
	for attempt = 1, 8 do
		local lockedElsewhere = false
		local loaded: Data? = nil
		local ok, err = pcall(function()
			ds:UpdateAsync(keyFor(player), function(old: any)
				local data = old or deepCopy(TEMPLATE)
				local lock = data.SessionLock
				-- Another live server still owns this data: wait for it to save (unless the lock is stale).
				if lock and lock.JobId ~= game.JobId and os.time() - lock.Time < lockSeconds and attempt < 8 then
					lockedElsewhere = true
					return nil
				end
				data.SessionLock = { JobId = game.JobId, Time = os.time() }
				loaded = data
				return data
			end)
		end)
		if ok and loaded then
			return loaded, false
		end
		if not ok then
			warn(`[DataService] Load attempt {attempt} failed for {player.Name}: {err}`)
		end
		if not player.Parent then
			return nil, false
		end
		task.wait(if lockedElsewhere then 5 else 2)
	end
	return nil, false
end

function DataService.Load(player: Player): Profile?
	local data, noSave = loadData(player)
	if not data then
		if player.Parent then
			player:Kick("Your data could not be loaded. Please rejoin in a moment - your progress is safe.")
		end
		return nil
	end
	local isNew = (data :: any).Version == nil or (data.PlayTime == 0 and data.TotalEarned == 0)
	reconcile(data :: any, TEMPLATE :: any)
	migrate(data, isNew)

	if RunService:IsStudio() then
		if Config.Debug.StudioStartMoney > 0 and data.Money < Config.Debug.StudioStartMoney then
			data.Money = Config.Debug.StudioStartMoney
		end
		if Config.Debug.StudioStartSpeed > 0 and data.Speed < Config.Debug.StudioStartSpeed then
			data.Speed = Config.Debug.StudioStartSpeed
		end
	end

	local profile: Profile = {
		Player = player,
		Data = data,
		Passes = {},
		SessionSkins = {},
		Session = { SlowMode = false, Stunned = false, Ready = false, World = 1, Admin = false, GodMode = false },
		NoSave = noSave,
	}
	profiles[player] = profile
	if not player.Parent then
		-- They left while we were loading: hand the session lock straight back.
		DataService.Release(player)
		return nil
	end
	DataService.SyncAttributes(player)
	DataService.ProfileLoaded:Fire(player, profile)
	return profile
end

--------------------------------------------------------------------------------
-- Saving
--------------------------------------------------------------------------------
function DataService.Save(player: Player, release: boolean?)
	local profile = profiles[player]
	if not profile or profile.NoSave or not store then
		return
	end
	if saving[player] and not release then
		return
	end
	saving[player] = true
	local data = profile.Data
	data.LastOnline = os.time()
	local ds = store :: DataStore
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			ds:UpdateAsync(keyFor(player), function(old: any)
				-- If another server took over this player's data, never overwrite it.
				if old and old.SessionLock and old.SessionLock.JobId ~= game.JobId then
					return nil
				end
				data.SessionLock = if release then nil else { JobId = game.JobId, Time = os.time() }
				return data
			end)
		end)
		if ok then
			break
		end
		warn(`[DataService] Save attempt {attempt} failed for {player.Name}: {err}`)
		task.wait(1)
	end
	saving[player] = nil
end

-- Save right now, even if an autosave is already running (waits for it, then saves again).
-- Used after granting a Robux purchase so the receipt is on disk before it's confirmed.
function DataService.SaveNow(player: Player)
	local started = os.clock()
	while saving[player] and os.clock() - started < 15 do
		task.wait(0.2)
	end
	DataService.Save(player)
end

function DataService.Release(player: Player)
	DataService.Save(player, true)
	profiles[player] = nil
end

--------------------------------------------------------------------------------
-- Accessors
--------------------------------------------------------------------------------
function DataService.Get(player: Player): Profile?
	return profiles[player]
end

function DataService.GetAll(): { [Player]: Profile }
	return profiles
end

function DataService.IsReady(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.Session.Ready
end

function DataService.SyncAttributes(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local data = profile.Data
	player:SetAttribute("Money", data.Money)
	player:SetAttribute("TotalEarned", data.TotalEarned)
	player:SetAttribute("Speed", data.Speed)
	player:SetAttribute("TreadmillLevel", data.TreadmillLevel)
	player:SetAttribute("SpeedMultLevel", data.SpeedMultLevel)
	player:SetAttribute("PlayTime", data.PlayTime)
	player:SetAttribute("SlowMode", profile.Session.SlowMode)
	player:SetAttribute("Rebirths", data.Rebirths)
	player:SetAttribute("Expansions", data.Expansions)
	player:SetAttribute("BestSpeed", data.BestSpeed)
	player:SetAttribute("IndexBonus", DataService.IndexSpeedBonus(data))
	player:SetAttribute("PetSpeedBonus", DataService.PetSpeedBonus(data))
	player:SetAttribute("Buddy", data.Buddy)
end

function DataService.AddMoney(player: Player, amount: number, countsAsEarned: boolean?)
	local profile = profiles[player]
	if not profile or amount ~= amount then
		return
	end
	profile.Data.Money += amount
	if countsAsEarned ~= false and amount > 0 then
		profile.Data.TotalEarned += amount
	end
	player:SetAttribute("Money", profile.Data.Money)
	player:SetAttribute("TotalEarned", profile.Data.TotalEarned)
end

function DataService.TrySpend(player: Player, amount: number): boolean
	local profile = profiles[player]
	if not profile or amount ~= amount or amount < 0 or profile.Data.Money < amount then
		return false
	end
	profile.Data.Money -= amount
	player:SetAttribute("Money", profile.Data.Money)
	return true
end

function DataService.AddSpeed(player: Player, amount: number)
	local profile = profiles[player]
	if not profile or amount ~= amount then
		return
	end
	profile.Data.Speed += amount
	player:SetAttribute("Speed", profile.Data.Speed)
	if profile.Data.Speed > profile.Data.BestSpeed then
		profile.Data.BestSpeed = profile.Data.Speed
		player:SetAttribute("BestSpeed", profile.Data.BestSpeed)
	end
end

function DataService.TrySpendSpeed(player: Player, amount: number): boolean
	local profile = profiles[player]
	if not profile or amount ~= amount or amount < 0 or profile.Data.Speed < amount then
		return false
	end
	profile.Data.Speed -= amount
	player:SetAttribute("Speed", profile.Data.Speed)
	return true
end

-- Sends the table-shaped state the client UI needs (owned passes, skins, discovered donuts...).
function DataService.PushState(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local skins = table.clone(profile.Data.OwnedSkins)
	for id in profile.SessionSkins do
		skins[id] = true
	end
	Remotes.Event("State"):FireClient(player, {
		Passes = profile.Passes,
		OwnedSkins = skins,
		EquippedSkin = profile.Data.EquippedSkin,
		Discovered = profile.Data.Discovered,
		DiscoveredMutations = profile.Data.DiscoveredMutations,
		IndexClaims = profile.Data.IndexClaims,
		PodiumMode = profile.Data.PodiumMode,
		MusicVolume = profile.Data.MusicVolume,
		MusicOn = profile.Data.MusicOn,
		Items = profile.Data.Items,
		PlotIndex = player:GetAttribute("PlotIndex"),
		SlowMode = profile.Session.SlowMode,
		Eggs = profile.Data.Eggs,
		Pets = profile.Data.Pets,
		EquippedPets = profile.Data.EquippedPets,
		Buddy = profile.Data.Buddy,
		Donated = profile.Data.Donated,
		Admin = profile.Session.Admin,
		GodMode = profile.Session.GodMode,
	})
end

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------
function DataService.Init()
	local ok, result = pcall(function()
		local ds = DataStoreService:GetDataStore(Config.Data.StoreName)
		-- Probe once so Studio without API access falls back instantly instead of retrying.
		ds:GetAsync("__probe")
		return ds
	end)
	if ok then
		store = result
	else
		dataStoresEnabled = false
		warn("[DataService] DataStores unavailable - progress will NOT save this session. " .. "In Studio: Game Settings > Security > Enable Studio Access to API Services. (" .. tostring(result) .. ")")
	end

	-- Autosave (staggered so we don't burst the DataStore budget)
	task.spawn(function()
		while true do
			task.wait(Config.Data.AutosaveInterval)
			for player in profiles do
				if player.Parent then
					task.spawn(DataService.Save, player)
					task.wait(0.5)
				end
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and not dataStoresEnabled then
			return
		end
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				DataService.Save(player, true)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

function DataService.DataStoresEnabled(): boolean
	return dataStoresEnabled
end

return DataService
