--[[
	ShopService
	===========
	Handles every client request that costs money or Robux, plus a few small player actions:
	  BuySpeedMultiplier, BuyTreadmill           (in-game money)
	  BuyPass <key>, BuySkin <id>, EquipSkin <id> (Robux game passes)
	  SetSlowMode <bool>, TeleportHome

	Game pass ownership is checked with MarketplaceService on join and cached in the player's data,
	so a player never loses a pass they paid for if Roblox's API has a hiccup.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
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

local function findSkin(skinId: string?, passId: number?): Config.Skin?
	for _, skin in Config.Skins do
		if (skinId and skin.Id == skinId) or (passId and passId > 0 and skin.GamePassId == passId) then
			return skin
		end
	end
	return nil
end

local function ownsSkin(profile: DataService.Profile, skinId: string): boolean
	local skin = findSkin(skinId)
	return skin ~= nil and (skin.Free == true or profile.Data.OwnedSkins[skinId] == true or profile.SessionSkins[skinId] == true)
end

local function studioFree(): boolean
	return RunService:IsStudio() and Config.Debug.StudioFreePurchases
end

-- Re-apply everything that depends on owned passes.
local function refreshPassEffects(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	player:SetAttribute("MoneyMultiplier", Economy.MoneyMultiplier(profile.Passes))
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
	refreshPassEffects(player)
	notify(player, `🎉 {pass.Name} unlocked! Thank you!`, "success")
end

local function grantSkin(player: Player, skin: Config.Skin, persist: boolean)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	if persist then
		profile.Data.OwnedSkins[skin.Id] = true
	else
		profile.SessionSkins[skin.Id] = true
	end
	profile.Data.EquippedSkin = skin.Id
	PlotService.ApplySkin(player)
	DataService.PushState(player)
	notify(player, `🎨 {skin.Name} base skin unlocked and equipped!`, "success")
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
	for _, skin in Config.Skins do
		if not skin.Free and skin.GamePassId > 0 and not profile.Data.OwnedSkins[skin.Id] then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, skin.GamePassId)
			if ok and owns then
				profile.Data.OwnedSkins[skin.Id] = true
			end
		end
	end
	if not ownsSkin(profile, profile.Data.EquippedSkin) then
		profile.Data.EquippedSkin = "Classic"
	end
	player:SetAttribute("MoneyMultiplier", Economy.MoneyMultiplier(profile.Passes))
	player:SetAttribute("SpeedPassMultiplier", Economy.SpeedPassMultiplier(profile.Passes))
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
	notify(player, `⚡ Speed multiplier is now x{Economy.SpeedMultiplier(level + 1)}!`, "success")
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
	notify(player, `🏃 {nextTier.Name} Treadmill installed! (+{Format.Number(nextTier.Rate)} speed/s base)`, "success")
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
	if studioFree() then
		grantPass(player, pass, false)
		notify(player, "(Studio test purchase - not saved)")
	elseif pass.GamePassId <= 0 then
		notify(player, pass.Name .. " is coming soon!", "error")
	else
		MarketplaceService:PromptGamePassPurchase(player, pass.GamePassId)
	end
end

function Actions.BuySkin(player: Player, profile: DataService.Profile, skinId: any)
	local skin = findSkin(if type(skinId) == "string" then skinId else nil, nil)
	if not skin then
		return
	end
	if ownsSkin(profile, skin.Id) then
		Actions.EquipSkin(player, profile, skin.Id)
		return
	end
	if studioFree() then
		grantSkin(player, skin, false)
		notify(player, "(Studio test purchase - not saved)")
	elseif skin.GamePassId <= 0 then
		notify(player, skin.Name .. " is coming soon!", "error")
	else
		MarketplaceService:PromptGamePassPurchase(player, skin.GamePassId)
	end
end

function Actions.EquipSkin(player: Player, profile: DataService.Profile, skinId: any)
	if type(skinId) ~= "string" or not ownsSkin(profile, skinId) then
		return
	end
	profile.Data.EquippedSkin = skinId
	PlotService.ApplySkin(player)
	DataService.PushState(player)
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

function Actions.SetSlowMode(player: Player, profile: DataService.Profile, enabled: any)
	profile.Session.SlowMode = enabled == true
	player:SetAttribute("SlowMode", profile.Session.SlowMode)
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
	if spawnCf and player.Character then
		player.Character:PivotTo(spawnCf)
	end
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
			return
		end
		local skin = findSkin(nil, passId)
		if skin then
			grantSkin(player, skin, true)
		end
	end)
end

return ShopService
