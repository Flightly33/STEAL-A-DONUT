--[[
	ShopService
	===========
	Handles every client request that costs money, Speed or Robux, plus a few small player actions:
	  BuySpeedMultiplier, BuyTreadmill, BuyBaseSize (a bigger pen)   (in-game money)
	  BuyIncubatorUpgrade "Speed" | "Size"                            (in-game money)
	  BuySkin <id>, EquipSkin <id>                     (bought with your Speed stat)
	  BuyTrail <id>, EquipTrail <id | "">              (trails cost in-game money: shared/Trails)
	  BuyPass <key>                                    (Robux game passes)
	  ClaimIndex { DonutId, Kind }, ClaimIndexAll
	  TeleportArea <id>                                (Teleporter game pass)
	  SetSpeedLimit <walk speed, 0 = full>, TeleportHome, SetMusic { Volume, On }
	  SellInventory <uid>, SellAllInventory <rarity>, SellSlot <slot>   (the sell stall)
	  HatchEgg <uid?>, EquipPet <uid>, UnequipPet <uid>, EquipBestPets, ReleasePet <uid>
	  BuyLuck, BuyCrate <id>, Donate <amount>          (Robux developer products)
	Other services can add their own actions with ShopService.RegisterAction (e.g. the admin panel).

	Game pass ownership is checked with MarketplaceService on join and cached in the player's data,
	so a player never loses a pass they paid for if Roblox's API has a hiccup.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local UpdateNotes = require(Shared.UpdateNotes)
local Donuts = require(Shared.Donuts)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Trails = require(Shared.Trails)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local TreadmillService = require(script.Parent.TreadmillService)
local StealService = require(script.Parent.StealService)
local WorldService = require(script.Parent.WorldService)
local InventoryService = require(script.Parent.InventoryService)
local PetService = require(script.Parent.PetService)
local ProductService = require(script.Parent.ProductService)
local Ownership = require(script.Parent.Ownership)
local CraftService = require(script.Parent.CraftService)

local ShopService = {}

local requestLog: { [Player]: { number } } = {}
local lastTeleport: { [Player]: number } = {}

local function notify(player: Player, text: string, kind: string?)
	Remotes.Event("Notify"):FireClient(player, text, kind or "info")
end

local function findPass(key: string?, id: number?): Config.GamePass?
	for _, pass in Config.GamePasses do
		if (key and pass.Key == key) or (id and id > 0 and pass.GamePassId == id) then
			return pass
		end
	end
	return nil
end

local function findSkin(skinId: string?): Config.Skin?
	for _, skin in Config.Skins do
		if skin.Id == skinId then
			return skin
		end
	end
	return nil
end

-- (an owner-only skin is the game owner's alone, whatever their save says)
local function ownsSkin(player: Player, profile: DataService.Profile, skinId: string): boolean
	local skin = findSkin(skinId)
	if not skin then
		return false
	end
	if skin.OwnerOnly then
		return Ownership.IsOwner(player)
	end
	return skin.SpeedCost <= 0 or profile.Data.OwnedSkins[skinId] == true
end

-- Studio only: something without a real ID yet (0) is granted for this test session. Anything with
-- an ID goes through Roblox's purchase window (a free test purchase in Studio).
local function studioFree(id: number): boolean
	return RunService:IsStudio() and Config.Debug.StudioFreePurchases and id <= 0
end

-- Re-apply everything that depends on owned passes.
function ShopService.RefreshMultipliers(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	player:SetAttribute("MoneyMultiplier", DataService.MoneyMultiplier(profile))
	player:SetAttribute("SpeedPassMultiplier", Economy.SpeedPassMultiplier(profile.Passes))
	TreadmillService.Refresh(player)
	PlotService.RefreshSign(player)
	DataService.PushState(player)
end

-- Give a pass's perks. `persist` also records it in the save, so it's never lost if Roblox's
-- ownership check fails or lags later (never for Studio test purchases, which aren't real).
local function grantPass(player: Player, pass: Config.GamePass, persist: boolean)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local already = profile.Passes[pass.Key] == true
	profile.Passes[pass.Key] = true
	if persist and not RunService:IsStudio() then
		profile.Data.CachedPasses[pass.Key] = true
	end
	ShopService.RefreshMultipliers(player)
	if not already then
		notify(player, `{pass.Name} unlocked! Thank you!`, "success")
	end
end

local function ownsOnRoblox(player: Player, pass: Config.GamePass): boolean?
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.GamePassId)
	return if ok then owns == true else nil
end

-- Called once per player after their data loads. Yields (web requests).
-- A pass counts as owned if Roblox says so, or if we recorded buying it: Roblox's check can lag
-- behind a purchase for a while, so a "no" from it never takes away a pass we saw being bought.
-- If the check fails outright it's retried in the background.
function ShopService.LoadOwnership(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local retry: { Config.GamePass } = {}
	for _, pass in Config.GamePasses do
		if pass.GamePassId > 0 then
			local owns = ownsOnRoblox(player, pass)
			if owns then
				profile.Passes[pass.Key] = true
				profile.Data.CachedPasses[pass.Key] = true
			elseif profile.Data.CachedPasses[pass.Key] then
				profile.Passes[pass.Key] = true
			elseif owns == nil then
				table.insert(retry, pass)
			end
		end
	end
	if #retry > 0 then
		task.delay(10, function()
			for _, pass in retry do
				if player.Parent and DataService.Get(player) and ownsOnRoblox(player, pass) then
					grantPass(player, pass, true)
				end
			end
		end)
	end
	if not ownsSkin(player, profile, profile.Data.EquippedSkin) then
		profile.Data.EquippedSkin = "Classic"
	end
	player:SetAttribute("MoneyMultiplier", DataService.MoneyMultiplier(profile))
	player:SetAttribute("SpeedPassMultiplier", Economy.SpeedPassMultiplier(profile.Passes))
	PlotService.RefreshSign(player) -- base sign and donut labels include the money passes
end

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------
local Actions = {}

function Actions.BuySpeedMultiplier(player: Player, profile: DataService.Profile)
	local level = profile.Data.SpeedMultLevel
	if level >= Config.SpeedMultiplier.MaxLevel then
		notify(player, "Speed multiplier is maxed out!", "error")
		return
	end
	local cost = Economy.SpeedMultiplierCost(level)
	if not DataService.TrySpend(player, cost) then
		notify(player, "Not enough money! Need " .. Format.Money(cost), "error")
		return
	end
	profile.Data.SpeedMultLevel = level + 1
	player:SetAttribute("SpeedMultLevel", level + 1)
	TreadmillService.Refresh(player)
	notify(player, `Speed multiplier is now x{Format.Multiplier(Economy.SpeedMultiplier(level + 1))}!`, "success")
end

function Actions.BuyTreadmill(player: Player, profile: DataService.Profile)
	local level = profile.Data.TreadmillLevel
	if level >= Economy.MaxTreadmillLevel() then
		notify(player, "Your treadmill is already the best one!", "error")
		return
	end
	local nextTier = Economy.TreadmillTier(level + 1)
	if not DataService.TrySpend(player, nextTier.Cost) then
		notify(player, "Not enough money! Need " .. Format.Money(nextTier.Cost), "error")
		return
	end
	profile.Data.TreadmillLevel = level + 1
	player:SetAttribute("TreadmillLevel", level + 1)
	TreadmillService.Build(player)
	notify(player, `{nextTier.Name} Treadmill installed! (+{Format.Number(nextTier.PerStep)} every step)`, "success")
end

function Actions.BuyBaseSize(player: Player, _profile: DataService.Profile)
	PlotService.BuySize(player)
end

function Actions.BuyIncubatorUpgrade(player: Player, _profile: DataService.Profile, kind: any)
	PetService.BuyUpgrade(player, kind)
end

function Actions.BuyPass(player: Player, profile: DataService.Profile, key: any)
	local pass = findPass(if type(key) == "string" then key else nil, nil)
	if not pass then
		return
	end
	if profile.Passes[pass.Key] then
		notify(player, "You already own " .. pass.Name .. "!")
		return
	end
	-- Never sell a pass that does the same as one you have (or one that's only kept for its owners)
	for _, other in Config.GamePasses do
		if pass.SameAs == other.Key or (other.SameAs == pass.Key and profile.Passes[other.Key]) then
			notify(player, "You already have " .. (if pass.SameAs then other.Name else pass.Name) .. "!")
			return
		end
	end
	if studioFree(pass.GamePassId) then
		grantPass(player, pass, false)
		notify(player, "(Studio test purchase - not saved)")
	elseif pass.GamePassId <= 0 then
		notify(player, pass.Name .. " is coming soon!", "error")
	else
		MarketplaceService:PromptGamePassPurchase(player, pass.GamePassId)
	end
end

-- Skins are bought with SPEED (it's spent: you'll be slower until you train it back).
function Actions.BuySkin(player: Player, profile: DataService.Profile, skinId: any)
	local skin = findSkin(if type(skinId) == "string" then skinId else nil)
	if not skin then
		return
	end
	if ownsSkin(player, profile, skin.Id) then
		Actions.EquipSkin(player, profile, skin.Id)
		return
	end
	if skin.OwnerOnly then
		notify(player, "Only the game's owner can use that skin!", "error")
		return
	end
	if StealService.IsCarrying(player) then
		notify(player, "Bring your donut home first!", "error")
		return
	end
	if not DataService.TrySpendSpeed(player, skin.SpeedCost) then
		notify(player, `Not enough speed! Need {Format.Number(skin.SpeedCost)}`, "error")
		return
	end
	profile.Data.OwnedSkins[skin.Id] = true
	profile.Data.EquippedSkin = skin.Id
	PlotService.ApplySkin(player)
	DataService.PushState(player)
	notify(player, `{skin.Name} base skin unlocked and equipped! (-{Format.Number(skin.SpeedCost)})`, "success")
end

function Actions.EquipSkin(player: Player, profile: DataService.Profile, skinId: any)
	if type(skinId) ~= "string" or not ownsSkin(player, profile, skinId) then
		return
	end
	profile.Data.EquippedSkin = skinId
	PlotService.ApplySkin(player)
	DataService.PushState(player)
end

-- Index rewards: every donut you've found can be claimed once, as cash, or (Epic and up) as a
-- permanent treadmill speed bonus.
function Actions.ClaimIndex(player: Player, profile: DataService.Profile, arg: any)
	if type(arg) ~= "table" or type(arg.DonutId) ~= "string" then
		return
	end
	local donut = Donuts.ById[arg.DonutId]
	local data = profile.Data
	if not donut or not data.Discovered[donut.Id] or data.IndexClaims[donut.Id] then
		return
	end
	local speed = Economy.IndexSpeedReward(donut.Id)
	if arg.Kind == "Speed" and speed then
		data.IndexClaims[donut.Id] = "Speed"
		player:SetAttribute("IndexBonus", DataService.IndexSpeedBonus(data))
		TreadmillService.Refresh(player)
		notify(player, `+{speed}% treadmill speed forever from {donut.Name}!`, "success")
	else
		local cash = Economy.IndexCashReward(donut.Id)
		data.IndexClaims[donut.Id] = "Cash"
		DataService.AddMoney(player, cash)
		notify(player, `+{Format.Money(cash)} from {donut.Name}!`, "success")
	end
	DataService.PushState(player)
end

-- Trails window: wear a trail you've unlocked ("" takes it off). Admins may try any trail.
function Actions.EquipTrail(player: Player, profile: DataService.Profile, trailId: any)
	local data = profile.Data
	if trailId == "" then
		data.EquippedTrail = ""
	elseif type(trailId) == "string" and Trails.ById[trailId] then
		DataService.CheckTrails(player)
		if not data.OwnedTrails[trailId] and not profile.Session.Admin then
			notify(player, "You haven't unlocked that trail yet!", "error")
			return
		end
		data.EquippedTrail = trailId
	else
		return
	end
	player:SetAttribute("Trail", if data.EquippedTrail ~= "" then data.EquippedTrail else nil)
	DataService.PushState(player)
end

-- Trails window: buy a trail with in-game money (Trail.Cost). It's yours for good, and you put it on.
function Actions.BuyTrail(player: Player, profile: DataService.Profile, trailId: any)
	local data = profile.Data
	local trail = if type(trailId) == "string" then Trails.ById[trailId] else nil
	if not trail or not trail.Cost then
		return
	end
	if data.OwnedTrails[trail.Id] then
		notify(player, "You already own that trail!", "error")
		return
	end
	if not DataService.TrySpend(player, trail.Cost) then
		notify(player, "Not enough money! Need " .. Format.Money(trail.Cost), "error")
		return
	end
	data.OwnedTrails[trail.Id] = true
	data.EquippedTrail = trail.Id
	player:SetAttribute("Trail", trail.Id)
	notify(player, `You bought the {trail.Name} trail! You're wearing it now.`, "success")
	DataService.PushState(player)
end

-- The Index's "Claim All" button: every reward you haven't claimed yet, in one go. Donuts that
-- offer a permanent speed bonus give that (until the Index bonus is capped), the rest give cash.
function Actions.ClaimIndexAll(player: Player, profile: DataService.Profile)
	local data = profile.Data
	local cap = Config.Index.MaxSpeedBonus * 100
	local cashTotal, speedTotal, count = 0, 0, 0
	for _, donut in Donuts.List do
		if data.Discovered[donut.Id] and not data.IndexClaims[donut.Id] then
			local speed = Economy.IndexSpeedReward(donut.Id)
			if speed and DataService.IndexSpeedBonus(data) + speed <= cap then
				data.IndexClaims[donut.Id] = "Speed"
				speedTotal += speed
			else
				data.IndexClaims[donut.Id] = "Cash"
				cashTotal += Economy.IndexCashReward(donut.Id)
			end
			count += 1
		end
	end
	if count == 0 then
		notify(player, "Nothing to claim yet. Find new donuts first!", "info")
		return
	end
	if cashTotal > 0 then
		DataService.AddMoney(player, cashTotal)
	end
	if speedTotal > 0 then
		player:SetAttribute("IndexBonus", DataService.IndexSpeedBonus(data))
		TreadmillService.Refresh(player)
	end
	local gains = {}
	if cashTotal > 0 then
		table.insert(gains, "+" .. Format.Money(cashTotal))
	end
	if speedTotal > 0 then
		table.insert(gains, `+{speedTotal}% treadmill speed forever`)
	end
	notify(player, `Claimed {count} reward{if count == 1 then "" else "s"}: {table.concat(gains, " and ")}!`, "success")
	DataService.PushState(player)
end

function Actions.TeleportArea(player: Player, _profile: DataService.Profile, areaId: any)
	WorldService.TeleportToArea(player, areaId)
end

-- The sell stall: sell a donut from your inventory, or every inventory donut of a rarity.
function Actions.SellInventory(player: Player, _profile: DataService.Profile, uid: any)
	InventoryService.Sell(player, uid)
end

function Actions.SellAllInventory(player: Player, _profile: DataService.Profile, rarity: any)
	InventoryService.SellAll(player, rarity)
end

-- Sell a donut that's in your pen (the sell stall's list).
function Actions.SellSlot(player: Player, _profile: DataService.Profile, slot: any)
	if type(slot) == "number" then
		PlotService.SellSlot(player, slot)
	end
end

function Actions.SeenTutorial(player: Player, profile: DataService.Profile)
	profile.Data.SeenTutorial = true
	DataService.PushState(player)
end

-- The free egg at the end of the tutorial: once per player, ever.
function Actions.ClaimTutorialEgg(player: Player, profile: DataService.Profile)
	profile.Data.SeenTutorial = true
	if profile.Data.TutorialEggClaimed then
		Remotes.Event("Notify"):FireClient(player, "You already claimed your free egg.", "info")
	elseif PetService.AddEgg(player, Config.Tutorial.FreeEgg, true) then
		profile.Data.TutorialEggClaimed = true
		Remotes.Event("Notify"):FireClient(player, "Free egg added to your incubator! It hatches into a pet.", "success")
	end
	DataService.PushState(player)
end

-- The update notes were shown (UpdateNotes): remember the newest Version seen.
function Actions.SeenUpdate(_player: Player, profile: DataService.Profile, version: any)
	if type(version) == "number" and version == version then
		profile.Data.SeenUpdate = math.clamp(math.floor(version), profile.Data.SeenUpdate, UpdateNotes.Latest)
	end
end

-- The Update Log's "Shown on login / Hidden on login" switch.
function Actions.NotesOnLogin(player: Player, profile: DataService.Profile, on: any)
	if type(on) == "boolean" then
		profile.Data.NotesOnLogin = on
		DataService.PushState(player)
	end
end

function Actions.SetMusic(player: Player, profile: DataService.Profile, settings: any)
	if type(settings) ~= "table" then
		return
	end
	if type(settings.Volume) == "number" and settings.Volume == settings.Volume then
		profile.Data.MusicVolume = math.clamp(settings.Volume, 0, 1)
	end
	if type(settings.On) == "boolean" then
		profile.Data.MusicOn = settings.On
	end
end

function Actions.HatchEgg(player: Player, _profile: DataService.Profile, uid: any)
	PetService.Hatch(player, if type(uid) == "string" then uid else nil)
end

function Actions.EquipPet(player: Player, _profile: DataService.Profile, uid: any)
	PetService.Equip(player, uid)
end

function Actions.UnequipPet(player: Player, _profile: DataService.Profile, uid: any)
	PetService.Unequip(player, uid)
end

function Actions.EquipBestPets(player: Player)
	PetService.EquipBest(player)
end

function Actions.ReleasePet(player: Player, _profile: DataService.Profile, uid: any)
	PetService.Release(player, uid)
end

function Actions.BuyLuck(player: Player)
	ProductService.BuyLuck(player)
end

function Actions.BuyCrate(player: Player, _profile: DataService.Profile, crateId: any)
	ProductService.BuyCrate(player, crateId)
end

function Actions.Donate(player: Player, _profile: DataService.Profile, amount: any)
	ProductService.Donate(player, amount)
end

-- BUY under a box's odds ("Open now": UI/SkipOdds)
function Actions.ConfirmSkip(player: Player, _profile: DataService.Profile, slot: any)
	ProductService.ConfirmSkip(player, slot)
end

-- Run speed (Settings): the WalkSpeed you typed, never below Config.Speed.MinRunSpeed. 0 = run as
-- fast as you can. A number above your top speed just means "full speed" until you get faster.
function Actions.SetSpeedLimit(player: Player, profile: DataService.Profile, limit: any)
	if type(limit) ~= "number" or limit ~= limit then
		return
	end
	limit = math.floor(limit)
	profile.Data.SpeedLimit = if limit <= 0 then 0 else math.clamp(limit, Config.Speed.MinRunSpeed, 1e9)
	player:SetAttribute("SpeedLimit", profile.Data.SpeedLimit)
end

-- The small "Drop box" button: put the box down where you stand.
function Actions.CraftCosmic(player: Player)
	CraftService.Craft(player)
end

function Actions.DropCarried(player: Player)
	local carry = StealService.GetCarry(player)
	if carry and carry.Kind == "Box" then
		StealService.Drop(player, "You dropped the box.")
	end
end

function Actions.TeleportHome(player: Player, profile: DataService.Profile)
	if StealService.IsCarrying(player) then
		notify(player, "You can't teleport while carrying something - run!", "error")
		return
	end
	if profile.Session.Stunned then
		return
	end
	local now = os.clock()
	if lastTeleport[player] and now - lastTeleport[player] < 3 then
		return
	end
	lastTeleport[player] = now
	local spawnCf = PlotService.GetSpawnCFrame(player)
	if spawnCf then
		StealService.Teleport(player, spawnCf)
	end
end

-- Let another service handle a client action (name must be unique).
function ShopService.RegisterAction(name: string, handler: (Player, DataService.Profile, any) -> ())
	assert(Actions[name] == nil, "Duplicate action " .. name)
	Actions[name] = handler
end

local function isRateLimited(player: Player): boolean
	local now = os.clock()
	local log = requestLog[player] or {}
	requestLog[player] = log
	while log[1] and now - log[1] > 1 do
		table.remove(log, 1)
	end
	if #log >= 12 then
		return true
	end
	table.insert(log, now)
	return false
end

function ShopService.OnPlayerRemoving(player: Player)
	requestLog[player] = nil
	lastTeleport[player] = nil
end

function ShopService.Init()
	Remotes.Event("Action").OnServerEvent:Connect(function(player: Player, action: any, arg: any)
		if type(action) ~= "string" or isRateLimited(player) then
			return
		end
		local handler = Actions[action]
		local profile = DataService.Get(player)
		if handler and profile and profile.Session.Ready then
			handler(player, profile, arg)
		end
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		local pass = findPass(nil, passId)
		if not pass then
			return
		end
		-- (the purchase can finish while they're still joining: wait for their data)
		local _, profile = DataService.WaitForReady(player.UserId, 60)
		if not profile then
			return -- they left: the pass is picked up when they join again
		end
		if purchased then
			grantPass(player, pass, true)
		elseif not profile.Passes[pass.Key] and ownsOnRoblox(player, pass) then
			-- Roblox said "you already own this" (our check at join must have failed): give it now
			grantPass(player, pass, true)
		end
	end)
end

return ShopService
