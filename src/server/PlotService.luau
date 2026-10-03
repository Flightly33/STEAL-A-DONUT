--[[
	PlotService
	===========
	Player bases: plot assignment, the donuts on their stands (with Upgrade / Sell prompts),
	base income, the owner sign, base expansions (more stands), base skins, and the podium that
	shows off the player's rarest or best-earning donut.

	Every world's hub has the same 8 plots. You keep the same plot number everywhere, and your base
	(donuts, treadmill, podium, incubator) moves to whichever world you're in (MoveBase), so you
	never have to run back to the main hub to drop off a donut.

	Upper floors (Config.Plots.UpperFloors): once the ground floor is fully expanded you can buy a
	second floor, then a third, each a deck over your whole base with more stands (slots
	SlotsPerPlot+1 ..). They're built on whichever plot your base is on, lift pads at the front take
	anyone between floors (thieves too), and the building around the base (glass walls and a roof,
	MapBuilder.BuildShell) grows with them.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Donuts = require(Shared.Donuts)
local Rarities = require(Shared.Rarities)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Layout = require(Shared.Layout)
local DonutModel = require(Shared.DonutModel)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)
local Areas = require(Shared.Areas)

local Build = require(script.Parent.Build)
local MapBuilder = require(script.Parent.MapBuilder)
local DataService = require(script.Parent.DataService)

local PlotService = {}

-- Set by RaidService: called for every new raid prompt (owner, slotIndex, prompt).
PlotService.RaidHandler = nil :: ((Player, number, ProximityPrompt) -> ())?
-- Fired after a player's base moved to another world: (player, oldWorld, newWorld).
-- The treadmill, incubator and traps rebuild themselves from this.
PlotService.BaseMoved = Signal.new()
-- How the lift pads move a character. StealService swaps in its own Teleport (so someone carrying
-- a donut isn't mistaken for a teleport cheater).
PlotService.Teleporter = function(player: Player, cf: CFrame)
	local character = player.Character
	if character then
		character:PivotTo(cf)
	end
end :: (Player, CFrame) -> ()

local rgb = Color3.fromRGB

local plotOwners: { [number]: Player } = {}
local playerPlots: { [Player]: number } = {}
local baseWorlds: { [Player]: number } = {}
local slotModels: { [Player]: { [number]: Model } } = {}
local baseIncome: { [Player]: number } = {}
local buildUpperFloors: (player: Player) -> ()
local removeUpperFloors: (plot: Model) -> ()

local function notify(player: Player, text: string, kind: string?)
	Remotes.Event("Notify"):FireClient(player, text, kind or "info")
end

local function getSkin(id: string)
	for _, skin in Config.Skins do
		if skin.Id == id then
			return skin
		end
	end
	return Config.Skins[1]
end

--------------------------------------------------------------------------------
-- Queries
--------------------------------------------------------------------------------
function PlotService.GetPlotIndex(player: Player): number?
	return playerPlots[player]
end

-- The world the player's base is in right now.
function PlotService.GetBaseWorld(player: Player): number
	return baseWorlds[player] or 1
end

function PlotService.GetPlotModel(player: Player): Model?
	local index = playerPlots[player]
	return if index then MapBuilder.GetPlot(index, PlotService.GetBaseWorld(player)) else nil
end

function PlotService.GetSpawnCFrame(player: Player): CFrame?
	local plot = PlotService.GetPlotModel(player)
	local spawn = plot and plot:FindFirstChild("Spawn") :: BasePart?
	return if spawn then spawn.CFrame * CFrame.new(0, 3.5, 0) else nil
end

-- How many floors the player's base has (more than can be bought for the game's owner).
function PlotService.GetFloors(player: Player): number
	local profile = DataService.Get(player)
	return if profile then math.clamp(profile.Data.Floors, 1, math.max(Layout.MaxFloors, Config.Admin.MaxFloors)) else 1
end

function PlotService.IsInOwnPlot(player: Player, position: Vector3): boolean
	local index = playerPlots[player]
	return index ~= nil and Layout.IsInPlot(index, position, PlotService.GetBaseWorld(player), PlotService.GetFloors(player))
end

function PlotService.GetBaseIncome(player: Player): number
	return baseIncome[player] or 0
end

-- How many stands this player has unlocked.
function PlotService.GetSlotCount(player: Player): number
	local profile = DataService.Get(player)
	return if profile then Economy.SlotCount(profile.Data.Expansions, profile.Data.Floors) else Config.Plots.StartSlots
end

function PlotService.GetFreeSlot(player: Player): number?
	local profile = DataService.Get(player)
	if not profile then
		return nil
	end
	for i = 1, PlotService.GetSlotCount(player) do
		if not profile.Data.Slots[tostring(i)] then
			return i
		end
	end
	return nil
end

function PlotService.HasFreeSlot(player: Player): boolean
	return PlotService.GetFreeSlot(player) ~= nil
end

local function recalcIncome(player: Player)
	local profile = DataService.Get(player)
	local total = 0
	if profile then
		for _, slot in profile.Data.Slots do
			total += Economy.DonutIncome(slot.Id, slot.Level, slot.Mutation, slot.Size)
		end
	end
	baseIncome[player] = total
end

--------------------------------------------------------------------------------
-- Sign above the plot
--------------------------------------------------------------------------------
-- How far above its anchor the sign floats: over the roof of the building (or over the top deck
-- when bases aren't enclosed), so it's always visible.
local function signOffset(floors: number): Vector3
	if Config.Plots.Building.Enclosed then
		return Vector3.new(0, Layout.FloorY(floors + 1) - 8, 0)
	end
	return Vector3.new(0, if floors >= 2 then Layout.FloorY(floors) + 12 else 0, 0)
end

-- `away`: the owner's base is in another world right now (this plot stays reserved for them).
local function refreshSign(plotIndex: number, owner: Player?, worldId: number?, away: boolean?)
	local plot = MapBuilder.GetPlot(plotIndex, worldId)
	local anchor = plot:FindFirstChild("SignAnchor") :: BasePart?
	if not anchor then
		return
	end
	local gui = anchor:FindFirstChild("OwnerSign") :: BillboardGui?
	if not gui then
		local newGui = Instance.new("BillboardGui")
		newGui.Name = "OwnerSign"
		newGui.Size = UDim2.fromScale(26, 7)
		newGui.MaxDistance = 400
		newGui.LightInfluence = 0
		newGui.Parent = anchor
		Build.Text(newGui, "", { Name = "OwnerName", Size = UDim2.fromScale(1, 0.62), TextStrokeColor3 = rgb(40, 20, 0) })
		Build.Text(newGui, "", { Name = "Income", Size = UDim2.fromScale(1, 0.38), Position = UDim2.fromScale(0, 0.62), TextColor3 = rgb(90, 255, 90) })
		gui = newGui
	end
	local signGui = gui :: BillboardGui
	local nameLabel = signGui:FindFirstChild("OwnerName") :: TextLabel
	local incomeLabel = signGui:FindFirstChild("Income") :: TextLabel
	signGui.StudsOffsetWorldSpace = signOffset(1)
	if owner and away then
		nameLabel.Text = `{owner.DisplayName}'s base`
		nameLabel.TextColor3 = rgb(200, 200, 200)
		incomeLabel.Text = `(in {Areas.World(PlotService.GetBaseWorld(owner)).Name})`
		incomeLabel.TextColor3 = rgb(200, 200, 200)
	elseif owner then
		nameLabel.Text = owner.DisplayName
		nameLabel.TextColor3 = rgb(255, 255, 255)
		incomeLabel.TextColor3 = rgb(90, 255, 90)
		local profile = DataService.Get(owner)
		signGui.StudsOffsetWorldSpace = signOffset(if profile then profile.Data.Floors else 1)
		local mult = if profile then DataService.MoneyMultiplier(profile) else 1
		local rebirths = if profile then profile.Data.Rebirths else 0
		nameLabel.Text = if rebirths > 0 then `{owner.DisplayName}  🔄{rebirths}` else owner.DisplayName
		incomeLabel.Text = Format.Money((baseIncome[owner] or 0) * mult) .. "/s"
	else
		nameLabel.Text = "Empty Base"
		nameLabel.TextColor3 = rgb(200, 200, 200)
		incomeLabel.Text = ""
	end
end

local updateSlotLabels: (player: Player, slotIndex: number) -> ()
local labelMultiplier: { [Player]: number } = {} -- the money multiplier the stand labels show

function PlotService.RefreshSign(player: Player)
	local index = playerPlots[player]
	if index then
		refreshSign(index, player, PlotService.GetBaseWorld(player))
	end
	-- Money passes, rebirths and pets changed what every donut earns: update their labels.
	local profile = DataService.Get(player)
	local mult = if profile then DataService.MoneyMultiplier(profile) else 1
	if labelMultiplier[player] ~= mult and slotModels[player] then
		labelMultiplier[player] = mult
		for slotIndex in slotModels[player] do
			updateSlotLabels(player, slotIndex)
		end
	end
end

--------------------------------------------------------------------------------
-- Podium (rarest / best earning donut)
--------------------------------------------------------------------------------
local function pickPodiumDonut(player: Player): DataService.SlotData?
	local profile = DataService.Get(player)
	if not profile then
		return nil
	end
	local mode = profile.Data.PodiumMode
	local best: DataService.SlotData?, bestKey = nil, -math.huge
	for _, slot in profile.Data.Slots do
		local donut = Donuts.ById[slot.Id]
		if donut then
			local income = Economy.DonutIncome(slot.Id, slot.Level, slot.Mutation, slot.Size)
			-- Rarest: rarity, then mutation (the leaderboard score), then income
			local key = if mode == "Earner" then income else Donuts.Score(donut, slot.Mutation) * 1e30 + income
			if key > bestKey then
				best, bestKey = slot, key
			end
		end
	end
	return best
end

local function buildPodiumBase(plot: Model): Model?
	local anchor = plot:FindFirstChild("PodiumAnchor") :: BasePart?
	if not anchor then
		return nil
	end
	local existing = plot:FindFirstChild("Podium")
	if existing then
		return existing :: Model
	end
	local podium = Instance.new("Model")
	podium.Name = "Podium"
	local cf = anchor.CFrame
	local steps = {
		{ Size = 11, Color = rgb(255, 255, 255) },
		{ Size = 8.5, Color = rgb(255, 210, 60) },
		{ Size = 6, Color = rgb(255, 255, 255) },
	}
	for i, step in steps do
		Build.Part({ Parent = podium, Name = "Step", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, step.Size, step.Size), CFrame = cf * CFrame.new(0, 0.6 + (i - 1) * 1.2, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = step.Color, Material = if i == 2 then Enum.Material.Foil else Enum.Material.Marble })
	end
	local ring = Build.Decor({ Parent = podium, Name = "GlowRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 12, 12), CFrame = cf * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(255, 220, 80), Material = Enum.Material.Neon, Transparency = 0.4 })
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 230, 150)
	light.Range = 16
	light.Brightness = 2
	light.Parent = ring
	local top = Build.Part({ Parent = podium, Name = "Top", Size = Vector3.new(1, 0.2, 1), CFrame = cf * CFrame.new(0, 3.6, 0), Transparency = 1, CanCollide = false, CanQuery = false })
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PodiumPrompt"
	prompt.ActionText = "Switch Display"
	prompt.ObjectText = "Podium"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = top
	prompt.Triggered:Connect(function(who: Player)
		if plot:GetAttribute("OwnerUserId") == who.UserId then
			PlotService.TogglePodiumMode(who)
		end
	end)
	podium.PrimaryPart = top :: BasePart
	podium.Parent = plot
	return podium
end

function PlotService.RefreshPodium(player: Player)
	local plot = PlotService.GetPlotModel(player)
	if not plot then
		return
	end
	local podium = buildPodiumBase(plot)
	if not podium then
		return
	end
	local old = podium:FindFirstChild("Showcase")
	if old then
		old:Destroy()
	end
	local top = podium:FindFirstChild("Top") :: BasePart
	local prompt = top:FindFirstChild("PodiumPrompt") :: ProximityPrompt
	prompt:SetAttribute("OwnerUserId", player.UserId)

	local profile = DataService.Get(player)
	local mode = if profile then profile.Data.PodiumMode else "Rarest"
	local title = if mode == "Earner" then `💰 {player.DisplayName}'s Top Earner` else `👑 {player.DisplayName}'s Rarest Donut`

	local slot = pickPodiumDonut(player)
	local donut = slot and Donuts.ById[slot.Id]
	local showcase = Instance.new("Folder")
	showcase.Name = "Showcase"
	showcase.Parent = podium

	local labelHolder = Build.Part({ Parent = showcase, Name = "LabelHolder", Size = Vector3.one, CFrame = top.CFrame, Transparency = 1, CanCollide = false, CanQuery = false })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(14, 2)
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Parent = labelHolder

	if slot and donut then
		local model = DonutModel.Build(donut, { Scale = Config.Plots.PodiumDonutScale, Mutation = slot.Mutation, Calm = true })
		DonutModel.PlaceOn(model, top.CFrame * CFrame.new(0, 0.1, 0))
		CollectionService:AddTag(model, "PodiumSpin")
		model.Parent = showcase
		local info = DonutModel.CreateBillboard(donut, Economy.DonutIncome(donut.Id, slot.Level, slot.Mutation, slot.Size), slot.Level, (model:GetAttribute("Top") :: number?) or 3, slot.Mutation, slot.Size)
		info.Parent = model.PrimaryPart
		gui.StudsOffsetWorldSpace = Vector3.new(0, ((model:GetAttribute("Top") :: number?) or 3) + (model:GetAttribute("Bottom") :: number? or 3) + 7.5, 0)
		Build.Text(gui, title, { TextColor3 = rgb(255, 225, 80), TextStrokeColor3 = rgb(80, 40, 0) })
	else
		gui.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
		Build.Text(gui, title .. "\n(steal a donut!)", { TextColor3 = rgb(230, 230, 230) })
	end
end

function PlotService.TogglePodiumMode(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	profile.Data.PodiumMode = if profile.Data.PodiumMode == "Earner" then "Rarest" else "Earner"
	PlotService.RefreshPodium(player)
	notify(player, if profile.Data.PodiumMode == "Earner" then "Podium now shows your top earning donut" else "Podium now shows your rarest donut")
	DataService.PushState(player)
end

--------------------------------------------------------------------------------
-- Donut slots
--------------------------------------------------------------------------------
local function getSlotPart(plot: Model, slotIndex: number): BasePart?
	local slots = plot:FindFirstChild("Slots")
	return slots and slots:FindFirstChild("Slot" .. slotIndex) :: BasePart?
end

-- The label under each donut shows what it REALLY earns: its income times your money
-- multiplier (money passes, rebirths, pets).
function updateSlotLabels(player: Player, slotIndex: number)
	local profile = DataService.Get(player)
	local model = slotModels[player] and slotModels[player][slotIndex]
	if not profile or not model then
		return
	end
	local slot = profile.Data.Slots[tostring(slotIndex)]
	if not slot then
		return
	end
	local root = model.PrimaryPart :: BasePart
	local donut = Donuts.ById[slot.Id]
	local baseIncome = Economy.DonutIncome(slot.Id, slot.Level, slot.Mutation, slot.Size)
	model:SetAttribute("Income", baseIncome) -- the client's "+$" popups multiply this themselves
	local income = baseIncome * DataService.MoneyMultiplier(profile)

	local old = root:FindFirstChild("DonutInfo")
	if old then
		old:Destroy()
	end
	local info = DonutModel.CreateBillboard(donut, income, slot.Level, (model:GetAttribute("Top") :: number?) or 3, slot.Mutation, slot.Size)
	info.Parent = root

	local upgrade = root:FindFirstChild("UpgradePrompt") :: ProximityPrompt?
	local sell = root:FindFirstChild("SellPrompt") :: ProximityPrompt?
	if upgrade then
		if slot.Level >= Config.DonutUpgrade.MaxLevel then
			upgrade.ActionText = "MAX LEVEL"
			upgrade.Enabled = false
		else
			upgrade.ActionText = "Upgrade " .. Format.Money(Economy.DonutUpgradeCost(slot.Id, slot.Level, slot.Mutation, slot.Size))
		end
		local gain = Economy.DonutBaseIncome(slot.Id, slot.Mutation, slot.Size) * Config.DonutUpgrade.IncomePerLevel * DataService.MoneyMultiplier(profile)
		upgrade.ObjectText = `Lv. {slot.Level} → {slot.Level + 1}  (+{Format.Money(gain)}/s)`
	end
	if sell then
		sell.ActionText = "Sell " .. Format.Money(Economy.SellPrice(slot.Id, slot.Level, slot.Mutation, slot.Size))
		sell.ObjectText = Rarities.DisplayName(donut.Name, slot.Mutation, slot.Size)
	end
end

local function spawnSlotModel(player: Player, slotIndex: number)
	local profile = DataService.Get(player)
	local plot = PlotService.GetPlotModel(player)
	if not profile or not plot then
		return
	end
	slotModels[player] = slotModels[player] or {}
	local existing = slotModels[player][slotIndex]
	if existing then
		existing:Destroy()
		slotModels[player][slotIndex] = nil
	end
	local slot = profile.Data.Slots[tostring(slotIndex)]
	local donut = slot and Donuts.ById[slot.Id]
	local pedestal = getSlotPart(plot, slotIndex)
	if not slot or not donut or not pedestal then
		return
	end

	local model = DonutModel.Build(donut, { Scale = Config.Plots.DonutScale, Mutation = slot.Mutation, Size = slot.Size, Calm = true })
	local surface = pedestal:GetAttribute("Surface") :: CFrame
	DonutModel.PlaceOn(model, surface)
	model.Name = "SlotDonut" .. slotIndex
	local root = model.PrimaryPart :: BasePart

	local upgrade = Instance.new("ProximityPrompt")
	upgrade.Name = "UpgradePrompt"
	upgrade.KeyboardKeyCode = Enum.KeyCode.E
	upgrade.GamepadKeyCode = Enum.KeyCode.ButtonX
	upgrade.HoldDuration = 0
	upgrade.MaxActivationDistance = 9
	upgrade.RequiresLineOfSight = false
	upgrade:SetAttribute("OwnerUserId", player.UserId)
	upgrade.Parent = root

	local sell = Instance.new("ProximityPrompt")
	sell.Name = "SellPrompt"
	sell.KeyboardKeyCode = Enum.KeyCode.F
	sell.GamepadKeyCode = Enum.KeyCode.ButtonY
	sell.HoldDuration = 1
	sell.MaxActivationDistance = 9
	sell.RequiresLineOfSight = false
	sell.UIOffset = Vector2.new(0, 70)
	sell:SetAttribute("OwnerUserId", player.UserId)
	sell.Parent = root

	local favorite = Instance.new("ProximityPrompt")
	favorite.Name = "FavoritePrompt"
	favorite.ActionText = if profile.Data.Favorite == tostring(slotIndex) then "💔 Unfavorite" else "❤ Favorite"
	favorite.ObjectText = "Follows you at 1/3 size"
	favorite.KeyboardKeyCode = Enum.KeyCode.R
	favorite.GamepadKeyCode = Enum.KeyCode.ButtonB
	favorite.HoldDuration = 0
	favorite.MaxActivationDistance = 9
	favorite.RequiresLineOfSight = false
	favorite.UIOffset = Vector2.new(0, 140)
	favorite:SetAttribute("OwnerUserId", player.UserId)
	favorite.Parent = root

	-- Raid prompt: other players hold this for Config.Raid.HoldSeconds while the owner is away.
	-- RaidService turns it on/off and handles the steal; the owner never sees it.
	if Config.Raid.Enabled then
		local raid = Instance.new("ProximityPrompt")
		raid.Name = "RaidPrompt"
		raid.ActionText = "Steal"
		raid.ObjectText = Rarities.DisplayName(donut.Name, slot.Mutation, slot.Size)
		raid.KeyboardKeyCode = Enum.KeyCode.E
		raid.GamepadKeyCode = Enum.KeyCode.ButtonX
		raid.HoldDuration = Config.Raid.HoldSeconds
		raid.MaxActivationDistance = 10
		raid.RequiresLineOfSight = false
		raid.Enabled = false
		raid:SetAttribute("HideForUserId", player.UserId)
		raid:SetAttribute("SlotIndex", slotIndex)
		raid.Parent = root
		if PlotService.RaidHandler then
			PlotService.RaidHandler(player, slotIndex, raid)
		end
	end

	upgrade.Triggered:Connect(function(who)
		if who == player then
			PlotService.UpgradeSlot(player, slotIndex)
		end
	end)
	sell.Triggered:Connect(function(who)
		if who == player then
			PlotService.SellSlot(player, slotIndex)
		end
	end)
	favorite.Triggered:Connect(function(who)
		if who == player then
			PlotService.FavoriteSlot(player, slotIndex)
		end
	end)

	-- Base donuts play idle animations on every client (client/DonutIdle.luau)
	model:SetAttribute("IdleSeed", slotIndex)
	CollectionService:AddTag(model, "BaseDonut")
	model.Parent = plot
	slotModels[player][slotIndex] = model
	updateSlotLabels(player, slotIndex)
end

-- The favourite donut: a 1/3-size copy follows its owner around (every client draws it from the
-- "Favorite" attribute). It's cleared when that donut leaves the base (sold, stolen, rebirth).
local function syncFavorite(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local key = profile.Data.Favorite
	if key and not profile.Data.Slots[key] then
		profile.Data.Favorite = nil
	end
	player:SetAttribute("Favorite", DataService.FavoriteTag(profile.Data))
	local models: { [number]: Model } = slotModels[player] or {}
	for index, model in models do
		local root = model.PrimaryPart
		local prompt = root and root:FindFirstChild("FavoritePrompt") :: ProximityPrompt?
		if prompt then
			prompt.ActionText = if profile.Data.Favorite == tostring(index) then "💔 Unfavorite" else "❤ Favorite"
		end
	end
end

function PlotService.FavoriteSlot(player: Player, slotIndex: number)
	local profile = DataService.Get(player)
	local key = tostring(slotIndex)
	local slot = profile and profile.Data.Slots[key]
	if not profile or not slot then
		return
	end
	local donut = Donuts.ById[slot.Id]
	if profile.Data.Favorite == key then
		profile.Data.Favorite = nil
		notify(player, "Unfavorited. It stays on your base.")
	else
		profile.Data.Favorite = key
		notify(player, `❤ {Rarities.DisplayName(donut.Name, slot.Mutation, slot.Size)} is your favorite! It follows you around (and keeps earning on its stand).`, "success")
	end
	syncFavorite(player)
	DataService.PushState(player)
end

local function afterSlotsChanged(player: Player)
	recalcIncome(player)
	PlotService.RefreshSign(player)
	PlotService.RefreshPodium(player)
	syncFavorite(player)
end

-- Put a donut on the first free stand (or on `preferredSlot` if that one is free: a donut that
-- was stolen and won back goes back where it was). Returns the slot index, or nil when full.
function PlotService.AddDonut(player: Player, donutId: string, level: number?, mutationId: string?, sizeId: string?, preferredSlot: number?): number?
	local profile = DataService.Get(player)
	local slotIndex = PlotService.GetFreeSlot(player)
	if profile and preferredSlot and preferredSlot <= PlotService.GetSlotCount(player) and not profile.Data.Slots[tostring(preferredSlot)] then
		slotIndex = preferredSlot
	end
	if not profile or not slotIndex or not Donuts.ById[donutId] then
		return nil
	end
	profile.Data.Slots[tostring(slotIndex)] = {
		Id = donutId,
		Level = level or 1,
		Mutation = if mutationId and mutationId ~= "None" then mutationId else nil,
		Size = if sizeId and sizeId ~= "Normal" then sizeId else nil,
	}
	spawnSlotModel(player, slotIndex)
	afterSlotsChanged(player)
	return slotIndex
end

-- Remove a donut from a base without paying for it (it was stolen). Returns its data.
function PlotService.TakeSlot(player: Player, slotIndex: number): DataService.SlotData?
	local profile = DataService.Get(player)
	local key = tostring(slotIndex)
	local slot = profile and profile.Data.Slots[key]
	if not profile or not slot then
		return nil
	end
	profile.Data.Slots[key] = nil
	local model = slotModels[player] and slotModels[player][slotIndex]
	if model then
		model:Destroy()
		slotModels[player][slotIndex] = nil
	end
	afterSlotsChanged(player)
	return slot
end

-- All raid prompts on a player's base (so RaidService can switch them on and off).
function PlotService.GetRaidPrompts(player: Player): { ProximityPrompt }
	local prompts = {}
	local models: { [number]: Model } = slotModels[player] or {}
	for _, model in models do
		local root = model.PrimaryPart
		local prompt = root and root:FindFirstChild("RaidPrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			table.insert(prompts, prompt)
		end
	end
	return prompts
end

function PlotService.UpgradeSlot(player: Player, slotIndex: number)
	local profile = DataService.Get(player)
	local slot = profile and profile.Data.Slots[tostring(slotIndex)]
	if not profile or not slot then
		return
	end
	if slot.Level >= Config.DonutUpgrade.MaxLevel then
		notify(player, "This donut is already max level!", "error")
		return
	end
	local cost = Economy.DonutUpgradeCost(slot.Id, slot.Level, slot.Mutation, slot.Size)
	if not DataService.TrySpend(player, cost) then
		notify(player, "Not enough money! Need " .. Format.Money(cost), "error")
		return
	end
	slot.Level += 1
	player:SetAttribute("DonutUpgrades", ((player:GetAttribute("DonutUpgrades") :: number?) or 0) + 1) -- (the tutorial watches this)
	updateSlotLabels(player, slotIndex)
	afterSlotsChanged(player)
	notify(player, `Upgraded to Lv. {slot.Level}!`, "success")
end

function PlotService.SellSlot(player: Player, slotIndex: number)
	local profile = DataService.Get(player)
	local key = tostring(slotIndex)
	local slot = profile and profile.Data.Slots[key]
	if not profile or not slot then
		return
	end
	local price = Economy.SellPrice(slot.Id, slot.Level, slot.Mutation, slot.Size)
	local donut = Donuts.ById[slot.Id]
	profile.Data.Slots[key] = nil
	DataService.AddMoney(player, price, false)
	local model = slotModels[player] and slotModels[player][slotIndex]
	if model then
		model:Destroy()
		slotModels[player][slotIndex] = nil
	end
	afterSlotsChanged(player)
	notify(player, `Sold {if donut then Rarities.DisplayName(donut.Name, slot.Mutation, slot.Size) else "donut"} for {Format.Money(price)}`, "success")
end

-- Remove every donut from a base (rebirth).
function PlotService.ClearAll(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	profile.Data.Slots = {}
	if slotModels[player] then
		for _, model in slotModels[player] do
			model:Destroy()
		end
	end
	slotModels[player] = {}
	afterSlotsChanged(player)
end

--------------------------------------------------------------------------------
-- Stands you haven't unlocked yet are see-through with a lock sign on each locked row.
--------------------------------------------------------------------------------
local function applySlotLocks(plotIndex: number, unlocked: number, worldId: number)
	local plot = MapBuilder.GetPlot(plotIndex, worldId)
	local slots = plot:FindFirstChild("Slots")
	if not slots then
		return
	end
	for _, child in slots:GetChildren() do
		if child.Name == "LockSign" then
			child:Destroy()
		end
	end
	local columns = #Layout.SlotColumns
	for index = 1, math.max(Layout.MaxSlots, unlocked) do
		local pedestal = slots:FindFirstChild("Slot" .. index)
		if pedestal and pedestal:IsA("BasePart") then
			local locked = index > unlocked
			pedestal.Transparency = if locked then 0.8 else 0
			pedestal.CanCollide = not locked
			-- One sign per locked row, on its first stand
			if locked and (index - 1) % columns == 0 then
				local holder = Instance.new("Part")
				holder.Name = "LockSign"
				holder.Anchored = true
				holder.CanCollide = false
				holder.CanQuery = false
				holder.CanTouch = false
				holder.Transparency = 1
				holder.Size = Vector3.one
				local offset = Layout.SlotOffset(index)
				local rowCenter = Layout.PlotCFrame(plotIndex, worldId) * CFrame.new(0, offset.Y + Layout.PlotFloorHeight + 3, offset.Z)
				holder.CFrame = rowCenter
				local gui = Instance.new("BillboardGui")
				gui.Size = UDim2.fromScale(22, 2.2)
				gui.LightInfluence = 0
				gui.MaxDistance = 90
				gui.Parent = holder
				Build.Text(gui, "🔒 Expand your base in the Shop", { TextColor3 = rgb(255, 230, 120), Font = Enum.Font.FredokaOne })
				holder.Parent = slots
			end
		end
	end
end

function PlotService.RefreshLocks(player: Player)
	local index = playerPlots[player]
	if index then
		applySlotLocks(index, PlotService.GetSlotCount(player), PlotService.GetBaseWorld(player))
	end
end

-- Buy the next base expansion (one more row of stands).
function PlotService.Expand(player: Player): boolean
	local profile = DataService.Get(player)
	if not profile then
		return false
	end
	local cost = Economy.ExpansionCost(profile.Data.Expansions)
	if not cost then
		notify(player, "Your base is fully expanded!", "error")
		return false
	end
	if not DataService.TrySpend(player, cost) then
		notify(player, "Not enough money! Need " .. Format.Money(cost), "error")
		return false
	end
	profile.Data.Expansions += 1
	player:SetAttribute("Expansions", profile.Data.Expansions)
	PlotService.RefreshLocks(player)
	PlotService.ApplySkin(player)
	notify(player, `🏗 Base expanded! You now have {PlotService.GetSlotCount(player)} donut stands.`, "success")
	return true
end

--------------------------------------------------------------------------------
-- Skins
--------------------------------------------------------------------------------
local function clearChildren(instance: Instance)
	for _, child in instance:GetChildren() do
		child:Destroy()
	end
end

-- The owner's skin: a red carpet with gold edges down the middle of every floor, gold sparkles
-- on the ground floor's stands, gentle gold glitter, and a giant crown floating above the roof.
-- (Sparkles only downstairs: an owner's base can have dozens of floors.)
local function buildRoyal(plot: Model, fx: Instance, center: CFrame)
	local d = Layout.PlotDepth
	local floors = 1
	while plot:FindFirstChild("Floor" .. (floors + 1)) do
		floors += 1
	end
	local gold, purple = rgb(255, 205, 70), rgb(175, 95, 255)
	for floor = 1, floors do
		local y = Layout.FloorY(floor) + Layout.PlotFloorHeight + 0.12
		Build.Decor({ Parent = fx, Name = "Carpet", Size = Vector3.new(4, 0.2, d - 6), CFrame = center * CFrame.new(0, y, 0), Color = rgb(195, 25, 45), Material = Enum.Material.Fabric })
		for _, side in { -1, 1 } do
			Build.Decor({ Parent = fx, Name = "CarpetTrim", Size = Vector3.new(0.4, 0.24, d - 6), CFrame = center * CFrame.new(side * 2.1, y, 0), Color = gold, Material = Enum.Material.Foil })
		end
	end
	local slots = plot:FindFirstChild("Slots")
	if slots then
		for _, pedestal in slots:GetChildren() do
			local index = pedestal:GetAttribute("SlotIndex") or tonumber(string.match(pedestal.Name, "^Slot(%d+)$"))
			if pedestal:IsA("BasePart") and pedestal.Transparency < 0.5 and type(index) == "number" and index <= Config.Plots.SlotsPerPlot then
				local holder = Build.Decor({ Parent = fx, Name = "PedestalFX", Size = Vector3.one, CFrame = CFrame.new(pedestal.Position), Transparency = 1 })
				local sparkles = Instance.new("Sparkles")
				sparkles.SparkleColor = gold
				sparkles.Parent = holder
			end
		end
	end
	local glitter = Build.Decor({ Parent = fx, Name = "Emitter", Size = Vector3.new(Layout.PlotWidth - 4, 1, d - 4), CFrame = center * CFrame.new(0, 1, 0), Transparency = 1 })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(gold, purple)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.LightEmission = 0.8
	emitter.Rate = 12
	emitter.Speed = NumberRange.new(1, 2.5)
	emitter.Lifetime = NumberRange.new(3, 5)
	emitter.Size = NumberSequence.new(0.35, 0)
	emitter.Parent = glitter

	-- The crown: a gold band with five points topped with gems, on a purple velvet cushion
	local boxCFrame, boxSize = plot:GetBoundingBox()
	local top = boxCFrame.Position.Y + boxSize.Y / 2
	local base = CFrame.new(center.Position.X, top + 10, center.Position.Z)
	local crown = Instance.new("Model")
	crown.Name = "OwnerCrown"
	local radius = 9
	Build.Decor({ Parent = crown, Name = "Cushion", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, radius * 2 - 1, radius * 2 - 1), CFrame = base * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(110, 30, 150), Material = Enum.Material.Fabric })
	for k = 0, 9 do
		local angle = k * math.pi / 5
		Build.Decor({ Parent = crown, Name = "Band", Size = Vector3.new(6, 4, 1.2), CFrame = base * CFrame.Angles(0, angle, 0) * CFrame.new(0, 1.5, -radius), Color = gold, Material = Enum.Material.Foil })
	end
	for k = 0, 4 do
		local angle = k * 2 * math.pi / 5
		local spike = base * CFrame.Angles(0, angle, 0) * CFrame.new(0, 6, -radius)
		Build.Decor({ Parent = crown, Name = "Point", Size = Vector3.new(3, 7, 1.2), CFrame = spike, Color = gold, Material = Enum.Material.Foil })
		Build.Decor({ Parent = crown, Name = "Gem", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.4, CFrame = spike * CFrame.new(0, 4.2, 0), Color = if k % 2 == 0 then purple else rgb(255, 50, 80), Material = Enum.Material.Neon })
		Build.Decor({ Parent = crown, Name = "BandGem", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.4, CFrame = base * CFrame.Angles(0, angle + math.pi / 5, 0) * CFrame.new(0, 1.5, -radius - 0.5), Color = rgb(80, 200, 255), Material = Enum.Material.Neon })
	end
	local light = Instance.new("PointLight")
	light.Color = gold
	light.Range = 30
	light.Brightness = 1.5
	light.Parent = crown:FindFirstChild("Cushion")
	local label = Instance.new("BillboardGui")
	label.Size = UDim2.fromScale(26, 5)
	label.StudsOffsetWorldSpace = Vector3.new(0, 15, 0)
	label.LightInfluence = 0
	label.MaxDistance = 400
	label.Parent = crown:FindFirstChild("Cushion")
	Build.Text(label, "👑 OWNER'S BASE 👑", { TextColor3 = rgb(255, 215, 90) })
	crown.Parent = fx
end

local function applySkinToPlot(plot: Model, skinId: string)
	local skin = getSkin(skinId)
	for _, part in plot:GetDescendants() do
		local role = part:GetAttribute("SkinRole")
		if role and part:IsA("BasePart") then
			CollectionService:RemoveTag(part, "RainbowPart")
			if role == "Floor" then
				part.Color, part.Material = skin.Floor, skin.FloorMaterial
			elseif role == "FloorAlt" then
				part.Color, part.Material = skin.FloorAlt, skin.FloorMaterial
			elseif role == "Fence" then
				part.Color, part.Material = skin.Fence, skin.FenceMaterial
			elseif role == "Trim" then
				part.Color, part.Material = skin.Trim, skin.TrimMaterial
				if skin.Effect == "Rainbow" then
					CollectionService:AddTag(part, "RainbowPart")
				end
			elseif role == "Pedestal" then
				part.Color, part.Material = skin.Pedestal, skin.PedestalMaterial
				if skin.Effect == "Rainbow" then
					CollectionService:AddTag(part, "RainbowPart")
				end
			end
			if part.Material == Enum.Material.Plastic and (role == "Floor" or role == "FloorAlt") then
				part.TopSurface = Enum.SurfaceType.Studs
			else
				part.TopSurface = Enum.SurfaceType.Smooth
			end
		end
	end

	local fx: Instance
	local existingFx = plot:FindFirstChild("SkinFX")
	if existingFx then
		fx = existingFx
	else
		fx = Instance.new("Folder")
		fx.Name = "SkinFX"
		fx.Parent = plot
	end
	clearChildren(fx)
	local center = Layout.PlotCFrame(plot:GetAttribute("PlotIndex") :: number, (plot:GetAttribute("WorldId") :: number?) or 1)
	local w, d = Layout.PlotWidth, Layout.PlotDepth

	local function areaEmitter(color: Color3, direction: Enum.NormalId, rate: number, speed: number, size: number)
		local part = Build.Decor({ Parent = fx, Name = "Emitter", Size = Vector3.new(w - 4, 1, d - 4), CFrame = center * CFrame.new(0, if direction == Enum.NormalId.Bottom then 22 else 1, 0), Transparency = 1 })
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(color)
		emitter.EmissionDirection = direction
		emitter.LightEmission = 0.7
		emitter.Rate = rate
		emitter.Speed = NumberRange.new(speed * 0.5, speed)
		emitter.Lifetime = NumberRange.new(3, 5)
		emitter.Size = NumberSequence.new(size, 0)
		emitter.Parent = part
	end

	local effect = skin.Effect
	if effect == "Sprinkles" then
		local rng = Random.new(7)
		local colors = { rgb(255, 60, 60), rgb(255, 230, 60), rgb(60, 200, 255), rgb(90, 220, 90), rgb(200, 90, 255) }
		for n = 1, 45 do
			Build.Decor({ Parent = fx, Name = "Sprinkle", Size = Vector3.new(0.5, 0.3, 1.6), CFrame = center * CFrame.new(rng:NextNumber(-w / 2 + 2, w / 2 - 2), Layout.PlotFloorHeight + 0.15, rng:NextNumber(-d / 2 + 2, d / 2 - 2)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color = colors[(n - 1) % #colors + 1] })
		end
	elseif effect == "Snow" then
		areaEmitter(rgb(255, 255, 255), Enum.NormalId.Bottom, 25, 5, 0.5)
	elseif effect == "Glow" or effect == "Fire" or effect == "Sparkle" or effect == "Stars" or effect == "Rainbow" then
		local slots = plot:FindFirstChild("Slots")
		local pedestals: { Instance } = if slots then slots:GetChildren() else {}
		for _, pedestal in pedestals do
			if pedestal:IsA("BasePart") and pedestal.Transparency < 0.5 then -- skip locked stands
				local holder = Build.Decor({ Parent = fx, Name = "PedestalFX", Size = Vector3.one, CFrame = CFrame.new(pedestal.Position), Transparency = 1 })
				if effect == "Glow" then
					local light = Instance.new("PointLight")
					light.Color = skin.Pedestal
					light.Range = 10
					light.Brightness = 1.5
					light.Parent = holder
				elseif effect == "Fire" then
					local fire = Instance.new("Fire")
					fire.Size = 2
					fire.Heat = 4
					fire.Parent = holder
				else
					local sparkles = Instance.new("Sparkles")
					sparkles.SparkleColor = if effect == "Stars" then rgb(170, 140, 255) else skin.Trim
					sparkles.Parent = holder
				end
			end
		end
		if effect == "Stars" then
			areaEmitter(rgb(200, 170, 255), Enum.NormalId.Top, 20, 2, 0.4)
		elseif effect == "Sparkle" then
			areaEmitter(rgb(255, 230, 120), Enum.NormalId.Top, 15, 2, 0.35)
		end
	elseif effect == "Royal" then
		buildRoyal(plot, fx, center)
	end
end

function PlotService.ApplySkin(player: Player)
	local profile = DataService.Get(player)
	local plot = PlotService.GetPlotModel(player)
	if profile and plot then
		applySkinToPlot(plot, profile.Data.EquippedSkin)
	end
end

--------------------------------------------------------------------------------
-- Upper floors (2nd, 3rd)
--------------------------------------------------------------------------------
local liftCooldown: { [Player]: number } = {}
local FLOOR_NAMES = { "GROUND FLOOR", "2ND FLOOR", "3RD FLOOR" }
local function floorName(floor: number): string
	return FLOOR_NAMES[floor] or `FLOOR {floor}`
end

-- A glowing lift pad: step on it and you're taken to `target`.
local function liftPad(parent: Instance, cf: CFrame, text: string, target: CFrame)
	local pad = Build.Part({
		Parent = parent, Name = "LiftPad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 7, 7),
		CFrame = cf * CFrame.Angles(0, 0, math.pi / 2),
		Color = rgb(90, 220, 255), Material = Enum.Material.Neon,
		CanCollide = false,
	})
	pad.CanTouch = true
	local beam = Build.Decor({ Parent = parent, Name = "LiftGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 6.6, 6.6), CFrame = cf * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(120, 230, 255), Material = Enum.Material.Neon, Transparency = 0.85 })
	beam.CanTouch = false
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(10, 2)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 7.5, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 90
	gui.Parent = pad
	Build.Text(gui, text, { TextColor3 = rgb(160, 240, 255), Font = Enum.Font.FredokaOne })
	pad.Touched:Connect(function(hit: BasePart)
		local character = hit.Parent
		local player = if character then Players:GetPlayerFromCharacter(character) else nil
		if not player then
			return
		end
		local now = os.clock()
		if liftCooldown[player] and now - liftCooldown[player] < 1 then
			return
		end
		liftCooldown[player] = now
		PlotService.Teleporter(player, target)
	end)
end

function removeUpperFloors(plot: Model)
	for _, child in plot:GetChildren() do
		-- ("SecondFloor": the deck's name before there was a third floor)
		if child.Name == "SecondFloor" or string.match(child.Name, "^Floor%d+$") then
			child:Destroy()
		end
	end
	local slots = plot:FindFirstChild("Slots")
	if slots then
		for _, pedestal in slots:GetChildren() do
			local index = tonumber(string.match(pedestal.Name, "^Slot(%d+)$"))
			if index and index > Config.Plots.SlotsPerPlot then
				pedestal:Destroy()
			end
		end
	end
end

-- Build the owner's upper floors (and the building around them) on the plot their base is on.
function buildUpperFloors(player: Player)
	local profile = DataService.Get(player)
	local plot = PlotService.GetPlotModel(player)
	local index = playerPlots[player]
	if not plot or not index then
		return
	end
	local floors = if profile then PlotService.GetFloors(player) else 1
	-- Floors that are already built stay as they are (adding floors only sends the new ones to
	-- everyone's device); any above the new top are removed.
	for _, child in plot:GetChildren() do
		local number = tonumber(string.match(child.Name, "^Floor(%d+)$"))
		if child.Name == "SecondFloor" or (number and number > floors) then
			child:Destroy()
		end
	end
	local slotFolder = plot:FindFirstChild("Slots")
	if slotFolder then
		local last = Layout.SlotsForFloors(floors)
		for _, pedestal in slotFolder:GetChildren() do
			local slotIndex = tonumber(string.match(pedestal.Name, "^Slot(%d+)$"))
			if slotIndex and slotIndex > last then
				pedestal:Destroy()
			end
		end
	end
	MapBuilder.BuildShell(plot, floors)
	local cf = Layout.PlotCFrame(index, PlotService.GetBaseWorld(player))
	local w, d, fh = Layout.PlotWidth, Layout.PlotDepth, Layout.PlotFloorHeight
	local classic = Config.Skins[1]
	local enclosed = Config.Plots.Building.Enclosed
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	for floor = 2, floors do
		if plot:FindFirstChild("Floor" .. floor) then
			continue -- already built
		end
		local height = Layout.FloorY(floor)
		local below = Layout.FloorY(floor - 1)
		local deck = Instance.new("Model")
		deck.Name = "Floor" .. floor
		local function skinned(role: string, props): BasePart
			props.Parent = props.Parent or deck
			local part = Build.Part(props)
			part:SetAttribute("SkinRole", role)
			return part
		end
		-- Deck (checker tiles like the ground floor, so skins recolour it too)
		local tile = 14
		for ix = 0, w / tile - 1 do
			for iz = 0, d / tile - 1 do
				local role = if (ix + iz) % 2 == 0 then "Floor" else "FloorAlt"
				skinned(role, { Name = "Tile", Size = Vector3.new(tile, fh + 0.5, tile), CFrame = at(-w / 2 + tile / 2 + ix * tile, height + (fh - 0.5) / 2, -d / 2 + tile / 2 + iz * tile), Color = if role == "Floor" then classic.Floor else classic.FloorAlt, Material = classic.FloorMaterial })
			end
		end
		-- Pillars holding it up (from the floor below)
		local pillarHeight = height - below
		for _, x in { -w / 2 + 1.5, w / 2 - 1.5 } do
			for _, z in { -d / 2 + 1.5, 0, d / 2 - 1.5 } do
				skinned("Trim", { Name = "Pillar", Size = Vector3.new(2.4, pillarHeight, 2.4), CFrame = at(x, below + pillarHeight / 2, z), Color = classic.Trim, Material = classic.TrimMaterial })
			end
		end
		-- Railing round the edge (the building's glass walls do that job when bases are enclosed)
		if not enclosed then
			local railHeight = 4
			local function rail(from: Vector3, to: Vector3)
				local length = (to - from).Magnitude
				local mid = (from + to) / 2
				local line = CFrame.lookAt(Vector3.new(mid.X, 0, mid.Z), Vector3.new(to.X, 0, to.Z))
				skinned("Fence", { Name = "Rail", Size = Vector3.new(0.6, railHeight, length), CFrame = cf * line * CFrame.new(0, height + fh + railHeight / 2, 0), Color = classic.Fence, Material = classic.FenceMaterial, Transparency = 0.4 })
				skinned("Trim", { Name = "RailCap", Size = Vector3.new(0.9, 0.4, length), CFrame = cf * line * CFrame.new(0, height + fh + railHeight + 0.2, 0), Color = classic.Trim, Material = classic.TrimMaterial })
			end
			local hw, hd = w / 2 - 0.3, d / 2 - 0.3
			rail(Vector3.new(-hw, 0, -hd), Vector3.new(hw, 0, -hd))
			rail(Vector3.new(-hw, 0, hd), Vector3.new(hw, 0, hd))
			rail(Vector3.new(-hw, 0, -hd), Vector3.new(-hw, 0, hd))
			rail(Vector3.new(hw, 0, -hd), Vector3.new(hw, 0, hd))
		end
		-- Lift pads between this floor and the one below, exactly above each other (so a carried
		-- donut never "teleports" sideways)
		local lift = Layout.LiftOffset(floor - 1)
		local step = Vector3.new(0, 0, 7) -- step off the pad towards the stands
		liftPad(deck, at(lift.X, below + fh + 0.2, lift.Z), "⬆ " .. floorName(floor), at(lift.X + step.X, height + fh + 3, lift.Z + step.Z))
		liftPad(deck, at(lift.X, height + fh + 0.2, lift.Z), "⬇ " .. floorName(floor - 1), at(lift.X + step.X, below + fh + 3, lift.Z + step.Z))
		-- This floor's stands (in the plot's Slots folder, like the ground floor's)
		local slots = plot:FindFirstChild("Slots")
		if slots then
			local first = Config.Plots.SlotsPerPlot + (floor - 2) * Config.Plots.UpperFloors.Slots + 1
			for slotIndex = first, first + Config.Plots.UpperFloors.Slots - 1 do
				local offset = Layout.SlotOffset(slotIndex)
				local pedestal = Build.Part({
					Parent = slots, Name = "Slot" .. slotIndex,
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(1, 7.5, 7.5),
					CFrame = cf * CFrame.new(offset.X, offset.Y + fh + 0.5, offset.Z) * CFrame.Angles(0, 0, math.pi / 2),
					Color = classic.Pedestal, Material = classic.PedestalMaterial,
				})
				pedestal:SetAttribute("SkinRole", "Pedestal")
				pedestal:SetAttribute("SlotIndex", slotIndex)
				pedestal:SetAttribute("Surface", cf * CFrame.new(offset.X, offset.Y + fh + 1, offset.Z))
			end
		end
		deck.Parent = plot
	end
end

-- Rebuild the base after its number of floors changed (bought, or the owner's admin panel).
function PlotService.RefreshFloors(player: Player)
	buildUpperFloors(player)
	PlotService.RefreshLocks(player)
	PlotService.ApplySkin(player)
	PlotService.RefreshSign(player)
end

-- Buy the next floor (the 2nd once the ground floor is fully expanded, then the 3rd).
function PlotService.BuyFloor(player: Player): boolean
	local profile = DataService.Get(player)
	if not profile then
		return false
	end
	local cost = Economy.NextFloorCost(profile.Data.Expansions, profile.Data.Floors)
	if not cost then
		notify(player, if profile.Data.Floors >= Layout.MaxFloors then "Your base already has every floor!" else "Fully expand your base first!", "error")
		return false
	end
	if not DataService.TrySpend(player, cost) then
		notify(player, "Not enough money! Need " .. Format.Money(cost), "error")
		return false
	end
	profile.Data.Floors = math.min(profile.Data.Floors + 1, Layout.MaxFloors)
	player:SetAttribute("Floors", profile.Data.Floors)
	PlotService.RefreshFloors(player)
	local name = string.lower(floorName(profile.Data.Floors))
	notify(player, `🏢 {string.upper(name)} built! +{Config.Plots.UpperFloors.Slots} stands ({PlotService.GetSlotCount(player)} total). Take the lift pad at the front of your base.`, "success")
	return true
end

--------------------------------------------------------------------------------
-- Assign / release / move to another world
--------------------------------------------------------------------------------
-- Put everything that belongs to the player's base on the plot in their current base world.
local function showBase(player: Player)
	local index = playerPlots[player]
	local profile = DataService.Get(player)
	if not index then
		return
	end
	local worldId = PlotService.GetBaseWorld(player)
	MapBuilder.GetPlot(index, worldId):SetAttribute("OwnerUserId", player.UserId)
	player:SetAttribute("BaseWorld", worldId)
	if profile then
		buildUpperFloors(player) -- (their stands must exist before the donuts go on them)
		for i = 1, Layout.SlotsForFloors(math.max(PlotService.GetFloors(player), Layout.MaxFloors)) do
			spawnSlotModel(player, i)
		end
	end
	PlotService.RefreshLocks(player)
	recalcIncome(player)
	PlotService.ApplySkin(player)
	PlotService.RefreshSign(player)
	PlotService.RefreshPodium(player)
end

-- Take the player's base off the plot in `worldId` (the plot stays reserved for them if `away`).
local function hideBase(player: Player, worldId: number, away: boolean)
	local index = playerPlots[player]
	if not index then
		return
	end
	if slotModels[player] then
		for _, model in slotModels[player] do
			model:Destroy()
		end
	end
	slotModels[player] = {}
	local plot = MapBuilder.GetPlot(index, worldId)
	plot:SetAttribute("OwnerUserId", nil)
	removeUpperFloors(plot)
	MapBuilder.BuildShell(plot, 1)
	local podium = plot:FindFirstChild("Podium")
	if podium then
		podium:Destroy()
	end
	applySkinToPlot(plot, "Classic")
	applySlotLocks(index, Config.Plots.StartSlots, worldId)
	refreshSign(index, if away then player else nil, worldId, away)
end

function PlotService.Assign(player: Player): number?
	if playerPlots[player] then
		return playerPlots[player]
	end
	local index: number? = nil
	for i = 1, Config.Plots.Count do
		if not plotOwners[i] then
			index = i
			break
		end
	end
	if not index then
		return nil
	end
	plotOwners[index] = player
	playerPlots[player] = index
	baseWorlds[player] = 1
	player:SetAttribute("PlotIndex", index)

	local profile = DataService.Get(player)
	if profile then
		-- Drop any saved slot that points at a donut that no longer exists (e.g. removed from Donuts.luau).
		for key, slot in profile.Data.Slots do
			if not Donuts.ById[slot.Id] or (tonumber(key) or math.huge) > Layout.SlotsForFloors(math.max(PlotService.GetFloors(player), Layout.MaxFloors)) then
				profile.Data.Slots[key] = nil
			end
		end
	end
	-- The same plot number is reserved for them in the other worlds.
	for _, world in Areas.Worlds do
		if world.Id ~= 1 then
			refreshSign(index, player, world.Id, true)
		end
	end
	showBase(player)
	return index
end

-- Move the player's base to another world (they just arrived there).
function PlotService.MoveBase(player: Player, worldId: number)
	local index = playerPlots[player]
	local old = PlotService.GetBaseWorld(player)
	if not index or old == worldId or not Areas.Worlds[worldId] then
		return
	end
	baseWorlds[player] = worldId
	hideBase(player, old, true)
	showBase(player)
	PlotService.BaseMoved:Fire(player, old, worldId)
end

function PlotService.Release(player: Player)
	local index = playerPlots[player]
	if not index then
		return
	end
	hideBase(player, PlotService.GetBaseWorld(player), false)
	for _, world in Areas.Worlds do
		refreshSign(index, nil, world.Id, false)
	end
	slotModels[player] = nil
	labelMultiplier[player] = nil
	baseIncome[player] = nil
	liftCooldown[player] = nil
	playerPlots[player] = nil
	baseWorlds[player] = nil
	plotOwners[index] = nil
end

function PlotService.Init()
	for _, world in Areas.Worlds do
		for i = 1, Config.Plots.Count do
			refreshSign(i, nil, world.Id, false)
			applySlotLocks(i, Config.Plots.StartSlots, world.Id)
		end
	end
end

return PlotService
