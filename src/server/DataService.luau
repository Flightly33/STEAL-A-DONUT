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
local Signal = require(Shared.Signal)
local Remotes = require(Shared.Remotes)

local DataService = {}

export type SlotData = { Id: string, Level: number }

export type Data = {
	Version: number,
	Money: number,
	TotalEarned: number,
	Speed: number,
	TreadmillLevel: number,
	SpeedMultLevel: number,
	Slots: { [string]: SlotData },
	Discovered: { [string]: boolean },
	BestDonutScore: number,
	PlayTime: number,
	LastOnline: number,
	OwnedSkins: { [string]: boolean },
	EquippedSkin: string,
	CachedPasses: { [string]: boolean },
	PodiumMode: string,
	SessionLock: { JobId: string, Time: number }?,
}

export type Profile = {
	Player: Player,
	Data: Data,
	Passes: { [string]: boolean }, -- owned game passes this session
	SessionSkins: { [string]: boolean }, -- Studio test purchases (never saved)
	Session: { SlowMode: boolean, Stunned: boolean, Ready: boolean, PendingOffline: { Amount: number, Seconds: number, Capped: boolean }? },
	NoSave: boolean,
}

local TEMPLATE: Data = {
	Version = 1,
	Money = 0,
	TotalEarned = 0,
	Speed = 0,
	TreadmillLevel = 1,
	SpeedMultLevel = 0,
	Slots = {},
	Discovered = {},
	BestDonutScore = 0,
	PlayTime = 0,
	LastOnline = 0,
	OwnedSkins = { Classic = true },
	EquippedSkin = "Classic",
	CachedPasses = {},
	PodiumMode = "Rarest",
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
	reconcile(data :: any, TEMPLATE :: any)

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
		Session = { SlowMode = false, Stunned = false, Ready = false },
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
		PodiumMode = profile.Data.PodiumMode,
		PlotIndex = player:GetAttribute("PlotIndex"),
		SlowMode = profile.Session.SlowMode,
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
