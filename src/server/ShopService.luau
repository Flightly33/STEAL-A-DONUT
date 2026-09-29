--[[
	ShopService
	===========
	Handles every client request that costs money, Speed or Robux, plus a few small player actions:
	  BuySpeedMultiplier, BuyTreadmill, BuyExpansion, BuyFloor (2nd / 3rd floor)   (in-game money)
	  BuyIncubatorUpgrade "Speed" | "Size"                            (in-game money)
	  BuySkin <id>, EquipSkin <id>                     (bought with your Speed stat)
	  BuyPass <key>                                    (Robux game passes)
	  Rebirth, ClaimIndex { DonutId, Kind }
	  TeleportWorld <id>, TeleportArea <id>            (Teleporter game pass)
	  SetSpeedChoice <0..1>, TeleportHome, BuyItem <id>, SetMusic { Volume, On }
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
local Donuts = require(Shared.Donuts)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local TreadmillService = require(script.Parent.TreadmillService)
local StealService = require(script.Parent.StealService)
local ItemService = require(script.Parent.ItemService)
local WorldService = require(script.Parent.WorldService)
local PetService = require(script.Parent.PetService)
local ProductService = require(script.Parent.ProductService)

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

local function ownsSkin(profile: DataService.Profile, skinId: string): boolean
	local skin = findSkin(skinId)
	return skin ~= nil and (skin.SpeedCost <= 0 or profile.Data.OwnedSkins[skinId] == true)
end

-- Studio only: something without a real ID yet (0) is granted for this test session. Anything with
-- an ID goes through Roblox's purchase window (a free test purchase in Studio).
local function studioFree(id: number): boolean
	return RunService:IsStudio() and Config.Debug.StudioFreePurchases and id <= 0
end

-- Re-apply everything that depends on owned passes / rebirths.
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

local function grantPass(player: Player, pass: Config.GamePass, persist: boolean)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	profile.Passes[pass.Key] = true
	if persist then
		profile.Data.CachedPasses[pass.Key] = true
	end
	ShopService.RefreshMultipliers(player)
	notify(player, `🎉 {pass.Name} unlocked! Thank you!`, "success")
end

-- Called once per player after their data loads. Yields (web requests).
function ShopService.LoadOwnership(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	for _, pass in Config.GamePasses do
		if pass.GamePassId > 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.GamePassId)
			if ok then
				profile.Passes[pass.Key] = owns or nil
				profile.Data.CachedPasses[pass.Key] = owns or nil
			elseif profile.Data.CachedPasses[pass.Key] then
				profile.Passes[pass.Key] = true -- API failed: trust our saved record
			end
		end
	end
	if not ownsSkin(profile, profile.Data.EquippedSkin) then
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
	notify(player, `⚡ Speed multiplier is now x{Format.Multiplier(Economy.SpeedMultiplier(level + 1))}!`, "success")
end

function Actions.BuyTreadmill(player: Player, profile: DataService.Profile)
	local level = profile.Data.TreadmillLevel
	if level >= Economy.MaxTreadmillLevel() then
		notify(player, "Your treadmill is already the best one!", "error")
		return
	end
	local nextTier = Economy.TreadmillTier(level + 1)
	if profile.Data.Rebirths < nextTier.RequiredRebirths then
		notify(player, `🔒 The {nextTier.Name} Treadmill needs {nextTier.RequiredRebirths} rebirth{if nextTier.RequiredRebirths == 1 then "" else "s"}.`, "error")
		return
	end
	if not DataService.TrySpend(player, nextTier.Cost) then
		notify(player, "Not enough money! Need " .. Format.Money(nextTier.Cost), "error")
		return
	end
	profile.Data.TreadmillLevel = level + 1
	player:SetAttribute("TreadmillLevel", level + 1)
	TreadmillService.Build(player)
	notify(player, `🏃 {nextTier.Name} Treadmill installed! (+{Format.Rate(nextTier.Rate)} speed/s base)`, "success")
end

function Actions.BuyExpansion(player: Player, _profile: DataService.Profile)
	PlotService.Expand(player)
end

function Actions.BuyFloor(player: Player, _profile: DataService.Profile)
	PlotService.BuyFloor(player)
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
	if ownsSkin(profile, skin.Id) then
		Actions.EquipSkin(player, profile, skin.Id)
		return
	end
	if StealService.IsCarrying(player) then
		notify(player, "Bring your donut home first!", "error")
		return
	end
	if not DataService.TrySpendSpeed(player, skin.SpeedCost) then
		notify(player, `Not enough speed! Need ⚡{Format.Number(skin.SpeedCost)}`, "error")
		return
	end
	profile.Data.OwnedSkins[skin.Id] = true
	profile.Data.EquippedSkin = skin.Id
	PlotService.ApplySkin(player)
	DataService.PushState(player)
	notify(player, `🎨 {skin.Name} base skin unlocked and equipped! (-⚡{Format.Number(skin.SpeedCost)})`, "success")
end

function Actions.EquipSkin(player: Player, profile: DataService.Profile, skinId: any)
	if type(skinId) ~= "string" or not ownsSkin(profile, skinId) then
		return
	end
	profile.Data.EquippedSkin = skinId
	PlotService.ApplySkin(player)
	DataService.PushState(player)
end

function Actions.Rebirth(player: Player, profile: DataService.Profile)
	local data = profile.Data
	local nextRebirth = Economy.NextRebirth(data.Rebirths)
	if not nextRebirth then
		notify(player, "You've reached the max rebirth. Legend!", "error")
		return
	end
	if StealService.IsCarrying(player) then
		notify(player, "Bring your donut home first!", "error")
		return
	end
	if data.Speed < nextRebirth.Speed then
		notify(player, `Reach ⚡{Format.Number(nextRebirth.Speed)} speed to rebirth!`, "error")
		return
	end
	if not DataService.TrySpend(player, nextRebirth.Cost) then
		notify(player, "Not enough money! Need " .. Format.Money(nextRebirth.Cost), "error")
		return
	end
	-- Reset
	data.Money = 0
	data.Speed = 0
	data.TreadmillLevel = 1
	data.SpeedMultLevel = 0
	PlotService.ClearAll(player)
	data.Rebirths += 1
	DataService.SyncAttributes(player)
	TreadmillService.Build(player)
	ShopService.RefreshMultipliers(player)
	local spawnCf = PlotService.GetSpawnCFrame(player)
	if spawnCf then
		StealService.Teleport(player, spawnCf)
	end
	notify(player, `🔄 REBIRTH {data.Rebirths}! Money x{Format.Multiplier(Economy.RebirthMoneyMultiplier(data.Rebirths))} and treadmill speed x{Format.Multiplier(Economy.RebirthSpeedMultiplier(data.Rebirths))} forever!`, "success")
	DataService.Save(player)
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
		notify(player, `📖 +{speed}% treadmill speed forever from {donut.Name}!`, "success")
	else
		local cash = Economy.IndexCashReward(donut.Id)
		data.IndexClaims[donut.Id] = "Cash"
		DataService.AddMoney(player, cash)
		notify(player, `📖 +{Format.Money(cash)} from {donut.Name}!`, "success")
	end
	DataService.PushState(player)
end

function Actions.TeleportWorld(player: Player, _profile: DataService.Profile, worldId: any)
	WorldService.TeleportToWorld(player, worldId)
end

function Actions.TeleportArea(player: Player, _profile: DataService.Profile, areaId: any)
	WorldService.TeleportToArea(player, areaId)
end

function Actions.BuyItem(player: Player, _profile: DataService.Profile, itemId: any)
	ItemService.Buy(player, itemId)
end

function Actions.ToggleHotbar(player: Player, _profile: DataService.Profile, itemId: any)
	ItemService.ToggleHotbar(player, itemId)
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

-- Speed slider: 0 = walk at normal speed (16) ... 1 = full speed.
function Actions.SetSpeedChoice(player: Player, profile: DataService.Profile, choice: any)
	if type(choice) ~= "number" or choice ~= choice then
		return
	end
	profile.Data.SpeedChoice = math.clamp(choice, 0, 1)
	player:SetAttribute("SpeedChoice", profile.Data.SpeedChoice)
end

-- The small "Drop donut" button while raiding: give the donut up (it goes back to its owner's stand).
function Actions.DropCarried(player: Player)
	local carry = StealService.GetCarry(player)
	if carry and carry.Kind == "Raid" then
		StealService.Drop(player, "You dropped it. It went back to its owner.")
	end
end

function Actions.TeleportHome(player: Player, profile: DataService.Profile)
	if StealService.IsCarrying(player) then
		notify(player, "You can't teleport while carrying a donut - run!", "error")
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
		if not purchased then
			return
		end
		local pass = findPass(nil, passId)
		if pass then
			grantPass(player, pass, true)
		end
	end)
end

return ShopService
