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
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Donuts = require(Shared.Donuts)
local Economy = require(Shared.Economy)
local Signal = require(Shared.Signal)
local Remotes = require(Shared.Remotes)
local Trails = require(Shared.Trails)

local DataService = {}

export type SlotData = { Id: string, Level: number, Mutation: string?, Size: string? }
-- A donut box waiting to open in the pen (it takes a slot, like a donut). HatchAt: os.time() it opens.
export type PenBox = { Tier: string, Size: string, Area: number, Mutation: string?, HatchAt: number }
-- Something in the inventory (a Tool in the backpack): a box to put in your pen, or a donut.
export type InvItem = { Uid: string, Kind: string, Id: string?, Level: number?, Tier: string?, Size: string?, Area: number?, Mutation: string? }
export type EggData = { Uid: string, Id: string, HatchAt: number } -- HatchAt: os.time() when it's ready
export type PetData = { Uid: string, Id: string }

export type Data = {
	Version: number,
	Money: number,
	TotalEarned: number,
	Speed: number,
	TreadmillLevel: number,
	SpeedMultLevel: number,
	Slots: { [string]: SlotData }, -- donuts in the pen ("1".."N")
	PenBoxes: { [string]: PenBox }, -- boxes waiting to open in the pen (same slot numbers)
	Inventory: { InvItem }, -- boxes brought home and donuts that came out of them
	NextUid: number,
	Discovered: { [string]: boolean },
	DiscoveredMutations: { [string]: { [string]: boolean } }, -- donutId -> mutations found
	IndexClaims: { [string]: string }, -- donutId -> "Cash" | "Speed"
	BestDonutScore: number,
	BestSpeed: number,
	Expansions: number, -- (old saves: base expansions, before bases were pens - see BaseLevel)
	BaseLevel: number, -- base size (Config.Plots.Sizes): how many donuts the pen holds
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
	Favorite: string?, -- slot key of the favourite donut (a 1/3-size copy follows you around)
	Donated: number, -- Robux donated
	Purchases: { string }, -- the last developer product receipts granted (PurchaseIds), newest last
	UsedAdmin: boolean, -- opened the admin panel (kept off the global leaderboards)
	SpeedBoostSeconds: number, -- crate Speed Boost time left (only counts down while online)
	Floors: number, -- (old saves: floors bought, before bases were pens - see BaseLevel)
	SpeedLimit: number, -- the run speed typed in Settings (a WalkSpeed); 0 = as fast as you can go
	OwnedTrails: { [string]: boolean }, -- trails unlocked (shared/Trails)
	EquippedTrail: string, -- the trail you wear ("" = none)
	IncubatorSpeed: number, -- incubator upgrade levels
	IncubatorSize: number,
	DonorTier: number, -- the biggest tip bought (Config.Donations.Products[].Amount): gives a title
	HiddenItems: { [string]: boolean }, -- items taken off the hotbar (still owned)
	SeenTutorial: boolean, -- the first-join "how to play" window
	SeenUpdate: number, -- the last UpdateNotes Version this player was shown
	NotesOnLogin: boolean, -- the Update Log pops up after a new update ("Shown on login")
	TutorialEggClaimed: boolean, -- the free egg at the end of the tutorial (once)
	AdminRevoked: boolean, -- the game's owner took their admin panel away (the chat code won't work)
	SessionLock: { JobId: string, Time: number }?,
}

export type Profile = {
	Player: Player,
	Data: Data,
	Passes: { [string]: boolean }, -- owned game passes this session
	SessionSkins: { [string]: boolean }, -- Studio test purchases (never saved)
	-- TestDonated / TestDonorTier: Studio test tips (shown for the session, never saved)
	Session: { Stunned: boolean, Ready: boolean, World: number, PendingOffline: { Amount: number, Seconds: number, Capped: boolean }?, Admin: boolean, SizeAccess: boolean, GodMode: boolean, TestDonated: number, TestDonorTier: number, PendingSkip: number? },
	NoSave: boolean,
}

local DATA_VERSION = 7

local TEMPLATE: Data = {
	Version = DATA_VERSION,
	Money = 0,
	TotalEarned = 0,
	Speed = 0,
	TreadmillLevel = 1,
	SpeedMultLevel = 0,
	Slots = {},
	PenBoxes = {},
	Inventory = {},
	NextUid = 1,
	Discovered = {},
	DiscoveredMutations = {},
	IndexClaims = {},
	BestDonutScore = 0,
	BestSpeed = 0,
	Expansions = 0,
	BaseLevel = 1,
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
	Favorite = nil,
	Donated = 0,
	Purchases = {},
	UsedAdmin = false,
	SpeedBoostSeconds = 0,
	Floors = 1,
	SpeedLimit = 0,
	OwnedTrails = {},
	EquippedTrail = "",
	IncubatorSpeed = 0,
	IncubatorSize = 0,
	DonorTier = 0,
	HiddenItems = {},
	SeenTutorial = false,
	SeenUpdate = 0,
	NotesOnLogin = true,
	TutorialEggClaimed = false,
	AdminRevoked = false,
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

-- Forget donuts that were taken out of the game (Donuts.luau): out of your inventory (they'd be
-- tools you can't sell or place) and the Index. Saved pen slots are dropped by PlotService.Assign.
local function dropRemovedDonuts(data: Data)
	for i = #data.Inventory, 1, -1 do
		local item = data.Inventory[i]
		if item.Kind == "Donut" and not (item.Id and Donuts.ById[item.Id]) then
			table.remove(data.Inventory, i)
		end
	end
	for donutId in data.Discovered do
		if not Donuts.ById[donutId] then
			data.Discovered[donutId] = nil
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
	if data.Version < 4 then
		-- Version 4: music is on now (Relaxed Scene) at 0.3; move the old untouched default (0.35).
		if math.abs(data.MusicVolume - 0.35) < 1e-6 then
			data.MusicVolume = Config.Music.DefaultVolume
		end
		data.Version = 4
	end
	if data.Version < 5 then
		-- Version 5: bases are open pens that you make bigger (BaseLevel), instead of rows of stands
		-- (8 + 4 per expansion, up to 24) with 24 more on every floor. Everyone gets a pen that
		-- holds at least as many donuts as they had stands.
		if not isNew then
			local stands = math.min(8 + 4 * data.Expansions, 24) + 24 * math.max(data.Floors - 1, 0)
			data.BaseLevel = math.max(data.BaseLevel, Economy.LevelForSlots(stands))
		end
		data.Version = 5
	end
	if data.Version < 6 then
		-- Version 6 (Update 6): donut boxes, one long lane of 20 biomes, a new money and speed curve.
		-- Old progress doesn't fit the new game, so everyone starts over: money, speed, donuts,
		-- pets, rebirths, base size, treadmills and the Index. Kept: game passes, Robux donated,
		-- time played, owned skins, settings, admin flags.
		if not isNew then
			data.Money = 0
			data.TotalEarned = 0
			data.Speed = 0
			data.BestSpeed = 0
			data.TreadmillLevel = 1
			data.SpeedMultLevel = 0
			data.Slots = {}
			data.PenBoxes = {}
			data.Inventory = {}
			data.Discovered = {}
			data.DiscoveredMutations = {}
			data.IndexClaims = {}
			data.BestDonutScore = 0
			data.BaseLevel = 1
			data.Expansions = 0
			data.Floors = 1
			data.Items = {}
			data.Eggs = {}
			data.Pets = {}
			data.EquippedPets = {}
			data.Favorite = nil
			data.SpeedBoostSeconds = 0
			data.IncubatorSpeed = 0
			data.IncubatorSize = 0
			data.SeenTutorial = false
			data.TutorialEggClaimed = false
		end
		data.Version = 6
	end
	if data.Version < 7 then
		-- Version 7: Crystal Cosmos, Starfall Garden and Aurora Palace are gone (20 -> 17 biomes).
		-- Boxes waiting in a pen or the inventory keep their biome's place in the new lane: each
		-- old biome maps to the closest one left that isn't faster (rebirths are gone too: the old
		-- Rebirths field is simply ignored).
		local OLD_TO_NEW = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 12, 13, 14, 14, 15, 15, 16, 17 }
		local function remap(area: number?): number?
			return if area then OLD_TO_NEW[area] or math.clamp(area, 1, 17) else nil
		end
		for _, box in data.PenBoxes do
			box.Area = remap(box.Area) or 1
		end
		for _, item in data.Inventory do
			if item.Kind == "Box" then
				item.Area = remap(item.Area)
			end
		end
		data.Version = 7
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

-- Total money multiplier: game passes x equipped pets.
function DataService.MoneyMultiplier(profile: Profile): number
	local petMoney = Economy.PetBonuses(DataService.EquippedPetIds(profile.Data))
	return Economy.MoneyMultiplier(profile.Passes) * (1 + petMoney)
end

-- Speed bonus from equipped pets (0.25 = +25% treadmill speed).
-- "donutId|mutation|size" of the favourite donut (what every client draws following you), or nil.
function DataService.FavoriteTag(data: Data): string?
	local slot = if data.Favorite then data.Slots[data.Favorite] else nil
	if not slot then
		return nil
	end
	return `{slot.Id}|{slot.Mutation or "None"}|{slot.Size or "Normal"}`
end

-- x WalkSpeed from a crate Speed Boost (1 when none is running).
function DataService.WalkBoost(data: Data): number
	return if data.SpeedBoostSeconds > 0 then Config.Crates.SpeedBoostMultiplier else 1
end

-- Tell clients when the Speed Boost ends (server time), or clear it.
function DataService.SyncSpeedBoost(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local left = profile.Data.SpeedBoostSeconds
	player:SetAttribute("SpeedBoostEndsAt", if left > 0 then workspace:GetServerTimeNow() + left else nil)
end

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
	dropRemovedDonuts(data)

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
		Session = { Stunned = false, Ready = false, World = 1, Admin = false, SizeAccess = false, GodMode = false, TestDonated = 0, TestDonorTier = 0 },
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
-- Returns true once the data is safely stored (or saving is off, e.g. Studio without API access).
function DataService.Save(player: Player, release: boolean?): boolean
	local profile = profiles[player]
	if not profile or profile.NoSave or not store then
		return profile ~= nil
	end
	if saving[player] and not release then
		return false
	end
	saving[player] = true
	local data = profile.Data
	data.LastOnline = os.time()
	local ds = store :: DataStore
	local saved = false
	for attempt = 1, 3 do
		local written = false
		local ok, err = pcall(function()
			ds:UpdateAsync(keyFor(player), function(old: any)
				-- If another server took over this player's data, never overwrite it.
				if old and old.SessionLock and old.SessionLock.JobId ~= game.JobId then
					return nil
				end
				data.SessionLock = if release then nil else { JobId = game.JobId, Time = os.time() }
				written = true
				return data
			end)
		end)
		if ok then
			saved = written
			break
		end
		warn(`[DataService] Save attempt {attempt} failed for {player.Name}: {err}`)
		task.wait(1)
	end
	saving[player] = nil
	return saved
end

-- Save right now, even if an autosave is already running (waits for it, then saves again).
-- Used after granting a Robux purchase so the receipt is on disk before it's confirmed.
-- Returns true if the data was stored.
function DataService.SaveNow(player: Player): boolean
	local started = os.clock()
	while saving[player] and os.clock() - started < 15 do
		task.wait(0.2)
	end
	return DataService.Save(player)
end

-- The player's profile once they've fully joined (data loaded, base assigned), waiting up to
-- `timeout` seconds for it. Used by purchases, which Roblox can deliver while someone is joining.
function DataService.WaitForReady(userId: number, timeout: number): (Player?, Profile?)
	local deadline = os.clock() + timeout
	while true do
		local player = Players:GetPlayerByUserId(userId)
		local profile = if player then profiles[player] else nil
		if player and profile and profile.Session.Ready then
			return player, profile
		end
		if os.clock() >= deadline then
			return nil, nil
		end
		task.wait(0.5)
	end
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
	player:SetAttribute("SpeedLimit", data.SpeedLimit)
	player:SetAttribute("Trail", if Trails.ById[data.EquippedTrail] then data.EquippedTrail else nil)
	player:SetAttribute("IncubatorSpeed", data.IncubatorSpeed)
	player:SetAttribute("IncubatorSize", data.IncubatorSize)
	player:SetAttribute("BaseLevel", data.BaseLevel)
	player:SetAttribute("BaseSlots", Economy.SlotCount(data.BaseLevel))
	player:SetAttribute("BestSpeed", data.BestSpeed)
	player:SetAttribute("IndexBonus", DataService.IndexSpeedBonus(data))
	player:SetAttribute("PetSpeedBonus", DataService.PetSpeedBonus(data))
	player:SetAttribute("SpeedBoostEndsAt", if data.SpeedBoostSeconds > 0 then workspace:GetServerTimeNow() + data.SpeedBoostSeconds else nil)
	player:SetAttribute("Favorite", DataService.FavoriteTag(data))
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
		DataService.CheckTrails(player)
	end
end

-- Trails unlocked by Speed (Trails.UnlockBiome) are yours for good the first time your best Speed
-- gets there. If you wear no trail, the new one is put on for you.
function DataService.CheckTrails(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local data = profile.Data
	local changed = false
	for _, trail in Trails.List do
		if not data.OwnedTrails[trail.Id] and Trails.IsUnlocked(trail, nil, data.BestSpeed) then
			data.OwnedTrails[trail.Id] = true
			changed = true
			local wear = not Trails.ById[data.EquippedTrail]
			if wear then
				data.EquippedTrail = trail.Id
				player:SetAttribute("Trail", trail.Id)
			end
			Remotes.Event("Notify"):FireClient(player, `{trail.Icon} You unlocked the {trail.Name} trail!` .. (if wear then " You're wearing it now." else " Put it on in Trails."), "rare")
		end
	end
	if changed then
		DataService.PushState(player)
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
		OwnedTrails = profile.Data.OwnedTrails,
		EquippedTrail = profile.Data.EquippedTrail,
		PodiumMode = profile.Data.PodiumMode,
		MusicVolume = profile.Data.MusicVolume,
		MusicOn = profile.Data.MusicOn,
		Items = profile.Data.Items,
		PlotIndex = player:GetAttribute("PlotIndex"),
		Eggs = profile.Data.Eggs,
		Pets = profile.Data.Pets,
		EquippedPets = profile.Data.EquippedPets,
		Favorite = profile.Data.Favorite,
		Donated = profile.Data.Donated + profile.Session.TestDonated,
		HiddenItems = profile.Data.HiddenItems,
		SeenTutorial = profile.Data.SeenTutorial,
		SeenUpdate = profile.Data.SeenUpdate,
		NotesOnLogin = profile.Data.NotesOnLogin,
		TutorialEggClaimed = profile.Data.TutorialEggClaimed,
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
