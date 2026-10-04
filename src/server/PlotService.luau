--[[
	PlotService
	===========
	Player bases: plot assignment, what's in them (donuts with Upgrade / Sell / Favorite prompts,
	and donut boxes waiting to open), base income, the owner sign, the upgrade sign by the gate,
	base skins, and the podium that shows off the player's rarest or best-earning donut.

	A base is a donut shop with an open pen in front (like Steal an Egg): a fenced patch of ground
	where your donuts roam around. Every donut has its own patch of the pen (Layout.SlotHome) and
	wanders around it; the clients move them (client/DonutIdle.luau) along the path Roam.luau works
	out from the shared server clock, and the server uses the same path to check that a thief is
	really next to one (GetDonutPosition). Upgrading the base at its sign (BuySize,
	Config.Plots.Sizes) makes the pen a little bigger, with room for more donuts.

	Boxes (AddBox): a box you put down in your pen takes a slot and gets a timer (Boxes.HatchSeconds
	- it also runs while you're offline; Box Rushes speed it up). When it runs out the box is ready
	and waits for you: click it (or press E) to open it (OpenReadyBox). "Open now" for Robux opens it
	straight away (SkipBox). It pops open (every client plays BoxFX), and the donut inside goes into
	your inventory (BoxOpened -> InventoryService).
]]

local CollectionService = game:GetService("CollectionService")
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
local Roam = require(Shared.Roam)
local Boxes = require(Shared.Boxes)
local BoxModel = require(Shared.BoxModel)

local Build = require(script.Parent.Build)
local MapBuilder = require(script.Parent.MapBuilder)
local DataService = require(script.Parent.DataService)
local StatsService = require(script.Parent.StatsService)

local PlotService = {}

-- Set by RaidService: called for every new raid prompt (owner, slotIndex, prompt).
PlotService.RaidHandler = nil :: ((Player, number, ProximityPrompt) -> ())?
-- Fired after a player's base got bigger (its pen was rebuilt): (player).
PlotService.Resized = Signal.new()
-- Fired when a box in a pen opens: (player, donutId, mutationId, sizeId). The donut goes into the
-- owner's inventory (InventoryService).
PlotService.BoxOpened = Signal.new()

local rgb = Color3.fromRGB

local plotOwners: { [number]: Player } = {}
local playerPlots: { [Player]: number } = {}
local slotModels: { [Player]: { [number]: Model } } = {}
local boxModels: { [Player]: { [number]: Model } } = {}
local opening: { [Player]: { [number]: boolean } } = {} -- boxes playing their opening animation
local rng = Random.new()
local baseIncome: { [Player]: number } = {}

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

-- (There's one lobby now: every base is in world 1.)
function PlotService.GetBaseWorld(_player: Player): number
	return 1
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

-- How big the player's base is (Config.Plots.Sizes; more than can be bought for the owner).
function PlotService.GetBaseLevel(player: Player): number
	local profile = DataService.Get(player)
	return if profile then math.clamp(profile.Data.BaseLevel, 1, math.max(Economy.MaxBaseLevel(), Economy.AdminMaxBaseLevel())) else 1
end

function PlotService.IsInOwnPlot(player: Player, position: Vector3): boolean
	local index = playerPlots[player]
	return index ~= nil and Layout.IsInPlot(index, position, PlotService.GetBaseWorld(player), PlotService.GetSlotCount(player))
end

function PlotService.GetBaseIncome(player: Player): number
	return baseIncome[player] or 0
end

-- How many donuts this player's base holds.
function PlotService.GetSlotCount(player: Player): number
	return Economy.SlotCount(PlotService.GetBaseLevel(player))
end

-- Is a slot of the pen taken (by a donut or a box waiting to open)?
local function slotTaken(profile: DataService.Profile, key: string): boolean
	return profile.Data.Slots[key] ~= nil or profile.Data.PenBoxes[key] ~= nil
end

function PlotService.GetFreeSlot(player: Player): number?
	local profile = DataService.Get(player)
	if not profile then
		return nil
	end
	local busy = opening[player] or {}
	for i = 1, PlotService.GetSlotCount(player) do
		if not slotTaken(profile, tostring(i)) and not busy[i] then
			return i
		end
	end
	return nil
end

function PlotService.HasFreeSlot(player: Player): boolean
	return PlotService.GetFreeSlot(player) ~= nil
end

-- (only donuts that fit in the base earn: ones saved past its end - it was made smaller - wait
-- until it's big enough again)
local function recalcIncome(player: Player)
	local profile = DataService.Get(player)
	local total = 0
	if profile then
		local count = PlotService.GetSlotCount(player)
		for key, slot in profile.Data.Slots do
			if (tonumber(key) or math.huge) <= count then
				total += Economy.DonutIncome(slot.Id, slot.Level, slot.Mutation, slot.Size)
			end
		end
	end
	baseIncome[player] = total
end

-- Move donuts saved past the end of the base into free spots inside it. Any that still don't fit
-- stay saved (nothing is ever thrown away) and come back when the base is big enough again.
local function compactSlots(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local count = PlotService.GetSlotCount(player)
	local overflow = {}
	for _, list in { profile.Data.Slots, profile.Data.PenBoxes } :: { { [string]: any } } do
		for key in list do
			local number = tonumber(key)
			if number and number > count then
				table.insert(overflow, number)
			end
		end
	end
	table.sort(overflow)
	local free = 1
	for _, number in overflow do
		while free <= count and slotTaken(profile, tostring(free)) do
			free += 1
		end
		if free > count then
			break
		end
		local key, target = tostring(number), tostring(free)
		if profile.Data.Slots[key] then
			profile.Data.Slots[target] = profile.Data.Slots[key]
			profile.Data.Slots[key] = nil
			if profile.Data.Favorite == key then
				profile.Data.Favorite = target
			end
		else
			profile.Data.PenBoxes[target] = profile.Data.PenBoxes[key]
			profile.Data.PenBoxes[key] = nil
		end
	end
end

--------------------------------------------------------------------------------
-- Sign above the plot
--------------------------------------------------------------------------------
-- The owner sign floats over the donut shop at the back of the pen (which moves back as the
-- base gets bigger), above the giant donut on its roof.
local function placeSign(plot: Model, slots: number)
	local anchor = plot:FindFirstChild("SignAnchor") :: BasePart?
	local index = plot:GetAttribute("PlotIndex")
	if not anchor or type(index) ~= "number" then
		return
	end
	local center, size = Layout.PenBounds(slots)
	local cf = Layout.PlotCFrame(index)
	anchor.CFrame = cf * CFrame.new(0, Layout.PlotFloorHeight + 38, center.Z + size.Y / 2 + 5 + Layout.ShopDepth / 2)
end

local function refreshSign(plotIndex: number, owner: Player?)
	local away = false
	local plot = MapBuilder.GetPlot(plotIndex)
	local anchor = plot:FindFirstChild("SignAnchor") :: BasePart?
	if not anchor then
		return
	end
	local gui = anchor:FindFirstChild("OwnerSign") :: BillboardGui?
	if not gui then
		-- The owner's avatar in a black ring, their name under it, and the base's income
		local newGui = Instance.new("BillboardGui")
		newGui.Name = "OwnerSign"
		newGui.Size = UDim2.fromScale(24, 22)
		newGui.MaxDistance = 600
		newGui.LightInfluence = 0
		newGui.Parent = anchor
		local ring = Instance.new("Frame")
		ring.Name = "AvatarRing"
		ring.AnchorPoint = Vector2.new(0.5, 0)
		ring.Position = UDim2.fromScale(0.5, 0)
		ring.Size = UDim2.fromScale(0.62, 0.62)
		ring.SizeConstraint = Enum.SizeConstraint.RelativeYY
		ring.BackgroundColor3 = rgb(15, 15, 20)
		ring.Parent = newGui
		local ringCorner = Instance.new("UICorner")
		ringCorner.CornerRadius = UDim.new(0.5, 0)
		ringCorner.Parent = ring
		local avatar = Instance.new("ImageLabel")
		avatar.Name = "Avatar"
		avatar.AnchorPoint = Vector2.new(0.5, 0.5)
		avatar.Position = UDim2.fromScale(0.5, 0.5)
		avatar.Size = UDim2.fromScale(0.86, 0.86)
		avatar.BackgroundColor3 = rgb(70, 120, 190)
		avatar.ScaleType = Enum.ScaleType.Crop
		avatar.Parent = ring
		local avatarCorner = Instance.new("UICorner")
		avatarCorner.CornerRadius = UDim.new(0.5, 0)
		avatarCorner.Parent = avatar
		Build.Text(newGui, "", { Name = "OwnerName", Font = Enum.Font.FredokaOne, Size = UDim2.fromScale(1, 0.22), Position = UDim2.fromScale(0, 0.62), TextStrokeColor3 = rgb(20, 20, 25) })
		Build.Text(newGui, "", { Name = "Income", Font = Enum.Font.FredokaOne, Size = UDim2.fromScale(1, 0.15), Position = UDim2.fromScale(0, 0.84), TextColor3 = rgb(90, 255, 90), TextStrokeColor3 = rgb(10, 40, 10) })
		gui = newGui
	end
	local signGui = gui :: BillboardGui
	local nameLabel = signGui:FindFirstChild("OwnerName") :: TextLabel
	local incomeLabel = signGui:FindFirstChild("Income") :: TextLabel
	local ring = signGui:FindFirstChild("AvatarRing") :: Frame?
	local avatar = ring and ring:FindFirstChild("Avatar") :: ImageLabel?
	if ring and avatar then
		ring.Visible = owner ~= nil
		avatar.Image = if owner then `rbxthumb://type=AvatarHeadShot&id={owner.UserId}&w=150&h=150` else ""
		avatar.ImageTransparency = if away then 0.45 else 0
	end
	placeSign(plot, if owner and not away then PlotService.GetSlotCount(owner) else Config.Plots.Sizes[1].Slots)
	if owner then
		nameLabel.Text = owner.DisplayName
		nameLabel.TextColor3 = rgb(255, 255, 255)
		incomeLabel.TextColor3 = rgb(90, 255, 90)
		local profile = DataService.Get(owner)
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
		refreshSign(index, player)
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
-- How donut `slotIndex` of this player roams their pen (see Roam.luau). The same numbers go on
-- the model as attributes, so every client can move it along the same path.
local function roamParams(player: Player, slotIndex: number, sizeId: string?): (Roam.Params, CFrame)
	local slots = PlotService.GetSlotCount(player)
	local origin = Layout.PlotCFrame(playerPlots[player] or 1, PlotService.GetBaseWorld(player))
	local center, size = Layout.PenBounds(slots)
	local scale = Config.Plots.DonutScale * Rarities.Size(sizeId).Scale
	local margin = 1.6 * scale -- (keep the whole donut inside the fence)
	local half = Vector2.new(math.max(size.X / 2 - margin, 0.5), math.max(size.Y / 2 - margin, 0.5))
	return {
		Seed = (player.UserId % 99991) * 37 + slotIndex * 7919,
		Home = Layout.SlotHome(slotIndex, slots),
		Radius = Config.Plots.CellSize * Config.Plots.RoamRadius,
		Speed = Config.Plots.RoamSpeed * math.sqrt(Rarities.Size(sizeId).Scale),
		Min = Vector2.new(center.X - half.X, center.Z - half.Y),
		Max = Vector2.new(center.X + half.X, center.Z + half.Y),
	}, origin
end

-- Where a donut in a pen is right now (world space, on the pen's floor). Thieves are checked
-- against this, since the donut the thief sees has walked away from where the server put it.
function PlotService.GetDonutPosition(player: Player, slotIndex: number): Vector3?
	local profile = DataService.Get(player)
	local slot = profile and profile.Data.Slots[tostring(slotIndex)]
	if not slot or not playerPlots[player] then
		return nil
	end
	local params, origin = roamParams(player, slotIndex, slot.Size)
	local state = Roam.At(params, workspace:GetServerTimeNow())
	return origin * (state.Position + Vector3.new(0, Layout.PlotFloorHeight + 2, 0))
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
	if not slot or not donut or slotIndex > PlotService.GetSlotCount(player) then
		return
	end

	-- It starts in the middle of its patch of the pen; every client walks it around from there.
	local model = DonutModel.Build(donut, { Scale = Config.Plots.DonutScale, Mutation = slot.Mutation, Size = slot.Size, Calm = true })
	local params, origin = roamParams(player, slotIndex, slot.Size)
	DonutModel.PlaceOn(model, origin * CFrame.new(params.Home + Vector3.new(0, Layout.PlotFloorHeight, 0)))
	model:SetAttribute("RoamOrigin", origin)
	model:SetAttribute("RoamHome", params.Home)
	model:SetAttribute("RoamSeed", params.Seed)
	model:SetAttribute("RoamRadius", params.Radius)
	model:SetAttribute("RoamSpeed", params.Speed)
	model:SetAttribute("RoamMin", params.Min)
	model:SetAttribute("RoamMax", params.Max)
	model.Name = "SlotDonut" .. slotIndex
	local root = model.PrimaryPart :: BasePart

	local upgrade = Instance.new("ProximityPrompt")
	upgrade.Name = "UpgradePrompt"
	upgrade.KeyboardKeyCode = Enum.KeyCode.E
	upgrade.GamepadKeyCode = Enum.KeyCode.ButtonX
	upgrade.HoldDuration = 0
	upgrade.MaxActivationDistance = 12
	upgrade.RequiresLineOfSight = false
	upgrade:SetAttribute("OwnerUserId", player.UserId)
	upgrade.Parent = root

	local sell = Instance.new("ProximityPrompt")
	sell.Name = "SellPrompt"
	sell.KeyboardKeyCode = Enum.KeyCode.F
	sell.GamepadKeyCode = Enum.KeyCode.ButtonY
	sell.HoldDuration = 1
	sell.MaxActivationDistance = 12
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
	favorite.MaxActivationDistance = 12
	favorite.RequiresLineOfSight = false
	favorite.UIOffset = Vector2.new(0, 140)
	favorite:SetAttribute("OwnerUserId", player.UserId)
	favorite.Parent = root

	-- Raid prompt: other players hold this for Config.Raid.HoldSeconds (whether the owner is home
	-- or not: there are no base locks). RaidService handles the steal; the owner never sees it.
	if Config.Raid.Enabled then
		local raid = Instance.new("ProximityPrompt")
		raid.Name = "RaidPrompt"
		raid.ActionText = "Steal"
		raid.ObjectText = Rarities.DisplayName(donut.Name, slot.Mutation, slot.Size)
		raid.KeyboardKeyCode = Enum.KeyCode.E
		raid.GamepadKeyCode = Enum.KeyCode.ButtonX
		raid.HoldDuration = Config.Raid.HoldSeconds
		raid.MaxActivationDistance = 13
		raid.RequiresLineOfSight = false
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
-- Boxes in the pen
--------------------------------------------------------------------------------
local OPEN_ANIMATION = 2.8 -- seconds the opening plays (client/BoxFX) before the box is gone

-- A donut came out of a box: the Index, the "rarest donut" score, the global stats and a
-- server-wide announcement for the really rare ones.
function PlotService.RecordFind(player: Player, donutId: string, mutationId: string, sizeId: string)
	local profile = DataService.Get(player)
	local donut = Donuts.ById[donutId]
	if not profile or not donut then
		return
	end
	local isNew = not profile.Data.Discovered[donut.Id]
	profile.Data.Discovered[donut.Id] = true
	local found = profile.Data.DiscoveredMutations[donut.Id] or {}
	profile.Data.DiscoveredMutations[donut.Id] = found
	local newMutation = mutationId ~= "None" and not found[mutationId]
	found[mutationId] = true
	local score = Donuts.Score(donut, mutationId)
	if score > profile.Data.BestDonutScore then
		profile.Data.BestDonutScore = score
	end
	-- (admins' finds would skew the global rarity numbers)
	local foundCount = nil
	if not profile.Data.UsedAdmin then
		StatsService.RecordSpawn(donut.Id, mutationId)
		foundCount = StatsService.RecordFound(donut.Id, mutationId)
	end
	local rarity = Rarities.Get(donut.Rarity)
	if rarity.Order >= Config.Spawns.AnnounceRarity or mutationId == "Rainbow" or mutationId == "Eternal" then
		local ever = if foundCount then ` (#{Format.Commas(foundCount)} ever found)` else ""
		Remotes.Event("AreaAnnouncement"):FireAllClients(`{player.DisplayName} got a {string.upper(rarity.Id)} donut: {Rarities.DisplayName(donut.Name, mutationId, sizeId)}!{ever}`, rarity.Color)
	end
	if isNew or newMutation then
		DataService.PushState(player)
	end
	if isNew and Economy.IndexCashReward(donut.Id) > 0 then
		notify(player, "📖 New donut! Claim its reward in the Index.", "success")
	end
end

-- What the label over a box in the pen says right now (clients keep counting it down: client/BoxFX).
local function boxTimerText(box: DataService.PenBox): string
	local left = box.HatchAt - os.time()
	return if left > 0 then Format.Duration(left) else "CLICK TO OPEN!"
end

-- A box is ready: it waits for its owner to click it (it never opens by itself).
local function markReady(player: Player, slotIndex: number, model: Model, announce: boolean)
	if model:GetAttribute("Ready") == true then
		return
	end
	model:SetAttribute("Ready", true)
	local root = model.PrimaryPart
	local info = root and root:FindFirstChild("BoxInfo")
	local timer = info and info:FindFirstChild("Timer", true)
	if timer and timer:IsA("TextLabel") then
		timer.Text = "CLICK TO OPEN!"
	end
	if announce then
		local profile = DataService.Get(player)
		local box = profile and profile.Data.PenBoxes[tostring(slotIndex)]
		if box then
			notify(player, `📦 Your {Rarities.DisplayName(Boxes.DisplayName(box.Tier, box.Size), box.Mutation, nil)} is ready! Click it to open it.`, "success")
		end
	end
end

local lastNotReady: { [Player]: number } = {}

local function spawnBoxModel(player: Player, slotIndex: number)
	local profile = DataService.Get(player)
	local plot = PlotService.GetPlotModel(player)
	if not profile or not plot then
		return
	end
	boxModels[player] = boxModels[player] or {}
	local existing = boxModels[player][slotIndex]
	if existing then
		existing:Destroy()
		boxModels[player][slotIndex] = nil
	end
	local box = profile.Data.PenBoxes[tostring(slotIndex)]
	if not box or slotIndex > PlotService.GetSlotCount(player) then
		return
	end
	local slots = PlotService.GetSlotCount(player)
	local origin = Layout.PlotCFrame(playerPlots[player] or 1)
	local home = Layout.SlotHome(slotIndex, slots)
	local model = BoxModel.Build(box.Tier, box.Size, { Mutation = box.Mutation, Area = box.Area })
	-- (facing the gate, so you read "DONUTS" from the front)
	BoxModel.PlaceOn(model, origin * CFrame.new(home + Vector3.new(0, Layout.PlotFloorHeight, 0)) * CFrame.Angles(0, math.pi, 0))
	model.Name = "PenBox" .. slotIndex
	model:SetAttribute("HatchAt", box.HatchAt)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Slot", slotIndex)
	local root = model.PrimaryPart :: BasePart
	-- Over the box: its name, and a timer (the time left, then "CLICK TO OPEN!") on a dark pill so
	-- it's easy to read. The server writes the first value; clients count it down from HatchAt.
	local gui = Instance.new("BillboardGui")
	gui.Name = "BoxInfo"
	gui.Size = UDim2.fromScale(10, 3.4)
	gui.StudsOffsetWorldSpace = Vector3.new(0, ((model:GetAttribute("Top") :: number?) or 3) + 2.6, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 140
	gui.Parent = root
	Build.Text(gui, Rarities.DisplayName(Boxes.DisplayName(box.Tier, box.Size), box.Mutation, nil), { Name = "BoxName", Size = UDim2.fromScale(1, 0.4), TextColor3 = Boxes.Tier(box.Tier).Color:Lerp(Color3.new(1, 1, 1), 0.3), TextStrokeColor3 = rgb(30, 20, 30), TextStrokeTransparency = 0 })
	local pill = Instance.new("Frame")
	pill.Name = "TimerPill"
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.fromScale(0.5, 0.44)
	pill.Size = UDim2.fromScale(0.66, 0.54)
	pill.BackgroundColor3 = rgb(25, 15, 30)
	pill.BackgroundTransparency = 0.25
	pill.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = pill
	local stroke = Instance.new("UIStroke")
	stroke.Color = rgb(255, 255, 255)
	stroke.Transparency = 0.6
	stroke.Thickness = 2
	stroke.Parent = pill
	Build.Text(pill, boxTimerText(box), { Name = "Timer", Size = UDim2.fromScale(0.9, 0.8), Position = UDim2.fromScale(0.05, 0.1), TextColor3 = rgb(255, 255, 255), TextStrokeColor3 = rgb(30, 20, 30), TextStrokeTransparency = 0, Font = Enum.Font.FredokaOne })
	-- "Open now" for Robux while it's waiting, then "Open!" once it's ready (clients show each one
	-- only to the owner, and only when it applies: client/BoxFX)
	local function prompt(name: string, action: string, object: string): ProximityPrompt
		local p = Instance.new("ProximityPrompt")
		p.Name = name
		p.ActionText = action
		p.ObjectText = object
		p.KeyboardKeyCode = Enum.KeyCode.E
		p.GamepadKeyCode = Enum.KeyCode.ButtonX
		p.HoldDuration = 0
		p.MaxActivationDistance = 12
		p.RequiresLineOfSight = false
		p:SetAttribute("OwnerUserId", player.UserId)
		p.Parent = root
		return p
	end
	prompt("SkipPrompt", `Open now (R$ {Config.Boxes.SkipPrice})`, "Skip the wait").Triggered:Connect(function(who)
		if who == player then
			PlotService.SkipHandler(player, slotIndex)
		end
	end)
	prompt("OpenPrompt", "Open!", Boxes.DisplayName(box.Tier, box.Size)).Triggered:Connect(function(who)
		if who == player then
			PlotService.OpenReadyBox(player, slotIndex)
		end
	end)
	-- ...and click (or tap) the box itself to open it
	local click = Instance.new("ClickDetector")
	click.Name = "OpenClick"
	click.MaxActivationDistance = 60
	click.Parent = model
	click.MouseClick:Connect(function(who)
		if who == player then
			PlotService.OpenReadyBox(player, slotIndex)
		end
	end)
	if box.HatchAt <= os.time() then
		markReady(player, slotIndex, model, false)
	end
	model.Parent = plot
	CollectionService:AddTag(model, "PenBox") -- (after parenting: clients find it complete)
	boxModels[player][slotIndex] = model
end

-- Set by ProductService: "Open now" was pressed on a box (prompts the Robux purchase).
PlotService.SkipHandler = function(_player: Player, _slotIndex: number) end

-- Put a box down in the pen: it takes the free slot closest to `near` (where the player is
-- standing) and its timer starts.
function PlotService.AddBox(player: Player, tier: string, size: string, area: number, mutation: string?, near: Vector3?): number?
	local profile = DataService.Get(player)
	if not profile or not playerPlots[player] then
		return nil
	end
	local slotIndex = PlotService.GetFreeSlot(player)
	if slotIndex and near then
		local origin = Layout.PlotCFrame(playerPlots[player])
		local slots = PlotService.GetSlotCount(player)
		local busy = opening[player] or {}
		local best = math.huge
		for i = 1, slots do
			if not slotTaken(profile, tostring(i)) and not busy[i] then
				local distance = (origin * Layout.SlotHome(i, slots) - near).Magnitude
				if distance < best then
					best, slotIndex = distance, i
				end
			end
		end
	end
	if not slotIndex then
		return nil
	end
	profile.Data.PenBoxes[tostring(slotIndex)] = {
		Tier = tier,
		Size = size,
		Area = area,
		Mutation = if mutation and mutation ~= "None" then mutation else nil,
		HatchAt = os.time() + math.ceil(Boxes.HatchSeconds(tier, size)),
	}
	spawnBoxModel(player, slotIndex)
	player:SetAttribute("BoxesPlaced", ((player:GetAttribute("BoxesPlaced") :: number?) or 0) + 1) -- (the tutorial watches this)
	return slotIndex
end

local function openBox(player: Player, slotIndex: number)
	local profile = DataService.Get(player)
	local key = tostring(slotIndex)
	local box = profile and profile.Data.PenBoxes[key]
	if not profile or not box then
		return
	end
	-- The box is gone from the save right away (the donut is in the inventory from this moment),
	-- but its slot stays busy while it plays the opening.
	profile.Data.PenBoxes[key] = nil
	opening[player] = opening[player] or {}
	opening[player][slotIndex] = true
	local donut = Donuts.Roll(box.Area, box.Tier, rng)
	local mutation = box.Mutation or "None"
	local size = Boxes.Size(box.Size).DonutSize
	PlotService.BoxOpened:Fire(player, donut.Id, mutation, size)
	PlotService.RecordFind(player, donut.Id, mutation, size)
	local model = boxModels[player] and boxModels[player][slotIndex]
	Remotes.Event("BoxOpened"):FireAllClients({
		Owner = player,
		Slot = slotIndex,
		Box = model,
		DonutId = donut.Id,
		Mutation = mutation,
		Size = size,
	})
	notify(player, `📦 You got {Rarities.DisplayName(donut.Name, mutation, size)}! It's in your inventory - put it in your pen.`, "success")
	task.delay(OPEN_ANIMATION, function()
		if model then
			model:Destroy()
		end
		if boxModels[player] and boxModels[player][slotIndex] == model then
			boxModels[player][slotIndex] = nil
		end
		if opening[player] then
			opening[player][slotIndex] = nil
		end
	end)
end

-- The owner clicked a box in their pen: it opens if its time is up.
function PlotService.OpenReadyBox(player: Player, slotIndex: number)
	local profile = DataService.Get(player)
	local box = profile and profile.Data.PenBoxes[tostring(slotIndex)]
	if not box or (opening[player] and opening[player][slotIndex]) then
		return
	end
	local left = box.HatchAt - os.time()
	if left > 0 then
		local now = os.clock()
		if not lastNotReady[player] or now - lastNotReady[player] > 1.5 then
			lastNotReady[player] = now
			notify(player, `Not ready yet! {Format.Duration(left)} to go.`, "error")
		end
		return
	end
	openBox(player, slotIndex)
end

-- Open a box right away (the Robux skip, or the admin panel). No slot (or one that's gone): the
-- box with the longest wait left.
function PlotService.SkipBox(player: Player, slotIndex: number?): boolean
	local profile = DataService.Get(player)
	if not profile then
		return false
	end
	local key = if slotIndex then tostring(slotIndex) else nil
	if not key or not profile.Data.PenBoxes[key] then
		local longest = -math.huge
		for k, box in profile.Data.PenBoxes do
			if box.HatchAt > longest then
				longest, key = box.HatchAt, k
			end
		end
	end
	local box = key and profile.Data.PenBoxes[key]
	local index = key and tonumber(key)
	if not box or not index then
		return false
	end
	box.HatchAt = math.min(box.HatchAt, os.time())
	openBox(player, index)
	return true
end

-- Box Rush (EventService): every box in every pen gets `seconds` closer to being ready.
function PlotService.RushBoxes(seconds: number)
	for player in playerPlots do
		local profile = DataService.Get(player)
		if profile then
			for key, box in profile.Data.PenBoxes do
				box.HatchAt -= seconds
				local model = boxModels[player] and boxModels[player][tonumber(key) or 0]
				if model then
					model:SetAttribute("HatchAt", box.HatchAt)
				end
			end
		end
	end
end

-- Every second: boxes whose time is up become ready (offline time counts too) and wait for a click.
local function updateBoxes()
	local now = os.time()
	for player in playerPlots do
		local profile = DataService.Get(player)
		local models = boxModels[player]
		if profile and profile.Session.Ready and models then
			for key, box in profile.Data.PenBoxes do
				local index = tonumber(key)
				local model = index and models[index]
				if model and box.HatchAt <= now then
					markReady(player, index :: number, model, true)
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- The upgrade sign by the gate
--------------------------------------------------------------------------------
local UPGRADE_GREEN = rgb(60, 200, 90)
local UPGRADE_RED = rgb(215, 55, 55)
local UPGRADE_GREY = rgb(130, 130, 130)
local upgradeLook: { [number]: string } = {} -- what each sign shows now (only touched when it changes)

-- The sign by the gate: what the next size gives, and the button - green when the owner can afford
-- it, red when not, grey at the biggest size (and on a free plot).
local function refreshUpgradeSign(plotIndex: number, owner: Player?)
	local plot = MapBuilder.GetPlot(plotIndex)
	local sign = plot:FindFirstChild("UpgradeSign")
	if not sign or not sign:IsA("Model") then
		return
	end
	local profile = if owner then DataService.Get(owner) else nil
	local text, price, color, enabled, action = "", "", UPGRADE_GREY, false, "Upgrade Base"
	if owner and profile then
		local level = profile.Data.BaseLevel
		local cost = Economy.BaseSizeCost(level)
		local slots = PlotService.GetSlotCount(owner)
		if cost then
			text = `{slots} to {Economy.SlotCount(level + 1)} donuts`
			price = Format.Money(cost)
			color = if profile.Data.Money >= cost then UPGRADE_GREEN else UPGRADE_RED
			action = `Upgrade {price}`
			enabled = true
		else
			text = `{slots} donuts\nMAX SIZE`
			price = "MAX SIZE"
		end
	end
	local look = `{text}|{price}|{color:ToHex()}|{enabled}|{if owner then owner.UserId else -1}`
	if upgradeLook[plotIndex] == look then
		return
	end
	upgradeLook[plotIndex] = look
	local board = sign:FindFirstChild("Board")
	local gui = board and board:FindFirstChild("SignGui")
	local info = gui and gui:FindFirstChild("Info") :: TextLabel?
	if info then
		info.Text = text
	end
	local button = sign:FindFirstChild("UpgradeButton") :: BasePart?
	if button then
		button.Color = color
		local buttonGui = button:FindFirstChild("ButtonGui")
		local priceLabel = buttonGui and buttonGui:FindFirstChild("Price") :: TextLabel?
		if priceLabel then
			priceLabel.Text = price
		end
	end
	local promptPart = sign:FindFirstChild("PromptPart")
	local prompt = promptPart and promptPart:FindFirstChild("UpgradePrompt") :: ProximityPrompt?
	if prompt then
		prompt.ActionText = action
		prompt.Enabled = enabled
		prompt:SetAttribute("OwnerUserId", if owner then owner.UserId else -1)
	end
end

function PlotService.RefreshUpgradeSign(player: Player)
	local index = playerPlots[player]
	if index then
		refreshUpgradeSign(index, player)
	end
end

local function setUpUpgradeSign(plotIndex: number)
	local plot = MapBuilder.GetPlot(plotIndex)
	local sign = plot:FindFirstChild("UpgradeSign")
	local promptPart = sign and sign:FindFirstChild("PromptPart")
	if not promptPart or promptPart:FindFirstChild("UpgradePrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UpgradePrompt"
	prompt.ActionText = "Upgrade Base"
	prompt.ObjectText = "Bigger pen, room for 2 more donuts"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt:SetAttribute("OwnerUserId", -1)
	prompt.Parent = promptPart
	prompt.Triggered:Connect(function(who: Player)
		if plotOwners[plotIndex] == who then
			PlotService.BuySize(who)
		end
	end)
	-- the button on the sign: click or tap it
	local button = MapBuilder.BuildUpgradeButton(sign :: Model)
	if button and not button:FindFirstChild("UpgradeClick") then
		local click = Instance.new("ClickDetector")
		click.Name = "UpgradeClick"
		click.MaxActivationDistance = 40
		click.Parent = button
		click.MouseClick:Connect(function(who: Player)
			if plotOwners[plotIndex] == who then
				PlotService.BuySize(who)
			end
		end)
	end
end

--------------------------------------------------------------------------------
-- Skins
--------------------------------------------------------------------------------
local function clearChildren(instance: Instance)
	for _, child in instance:GetChildren() do
		child:Destroy()
	end
end

-- The pen of a base on its plot: its middle (a CFrame on the ground) and its size.
local function penArea(plot: Model): (CFrame, Vector2)
	local pen = plot:FindFirstChild("Pen")
	local slots = (pen and pen:GetAttribute("Slots") :: number?) or Config.Plots.Sizes[1].Slots
	local center, size = Layout.PenBounds(slots)
	local cf = Layout.PlotCFrame(plot:GetAttribute("PlotIndex") :: number, (plot:GetAttribute("WorldId") :: number?) or 1)
	return cf * CFrame.new(center), size
end

-- The big posts of the pen's fence (corners and gate): where skins put their lights and flames.
local function fencePosts(plot: Model): { BasePart }
	local posts = {}
	local pen = plot:FindFirstChild("Pen")
	local fence = pen and pen:FindFirstChild("Fence")
	if fence then
		for _, part in fence:GetChildren() do
			if part:IsA("BasePart") and (part.Name == "CornerPost" or part.Name == "GatePost") then
				table.insert(posts, part)
			end
		end
	end
	return posts
end

-- The owner's skin: a red carpet with gold edges from the gate to the back of the pen, gold
-- sparkles on the fence's big posts, gentle gold glitter, and a giant crown floating above.
local function buildRoyal(plot: Model, fx: Instance, center: CFrame, size: Vector2)
	local d = size.Y
	local gold, purple = rgb(255, 205, 70), rgb(175, 95, 255)
	local y = Layout.PlotFloorHeight + 0.12
	Build.Decor({ Parent = fx, Name = "Carpet", Size = Vector3.new(4, 0.2, d - 2), CFrame = center * CFrame.new(0, y, 0), Color = rgb(195, 25, 45), Material = Enum.Material.Fabric })
	for _, side in { -1, 1 } do
		Build.Decor({ Parent = fx, Name = "CarpetTrim", Size = Vector3.new(0.4, 0.24, d - 2), CFrame = center * CFrame.new(side * 2.1, y, 0), Color = gold, Material = Enum.Material.Foil })
	end
	for _, post in fencePosts(plot) do
		local holder = Build.Decor({ Parent = fx, Name = "PostFX", Size = Vector3.one, CFrame = CFrame.new(post.Position + Vector3.new(0, post.Size.Y / 2, 0)), Transparency = 1 })
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = gold
		sparkles.Parent = holder
	end
	local glitter = Build.Decor({ Parent = fx, Name = "Emitter", Size = Vector3.new(size.X - 4, 1, d - 4), CFrame = center * CFrame.new(0, 1, 0), Transparency = 1 })
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
	local base = CFrame.new(center.Position.X, center.Position.Y + 34, center.Position.Z)
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
	local center, size = penArea(plot)
	local w, d = size.X, size.Y

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
		for _, post in fencePosts(plot) do
			do
				local holder = Build.Decor({ Parent = fx, Name = "PostFX", Size = Vector3.one, CFrame = CFrame.new(post.Position + Vector3.new(0, post.Size.Y / 2 + 0.5, 0)), Transparency = 1 })
				if effect == "Glow" then
					local light = Instance.new("PointLight")
					light.Color = skin.Trim
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
		buildRoyal(plot, fx, center, size)
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
-- Bigger bases
--------------------------------------------------------------------------------
-- Rebuild the pen after the base changed size (bought, or the owner's admin panel / the code):
-- a bigger fence, and every donut moves to its patch in the new pen.
function PlotService.RefreshPen(player: Player)
	local plot = PlotService.GetPlotModel(player)
	if not plot then
		return
	end
	local count = PlotService.GetSlotCount(player)
	compactSlots(player) -- (a smaller base: squeeze its donuts into the spots it still has)
	MapBuilder.BuildPen(plot, count)
	for _, list in { slotModels[player] or {}, boxModels[player] or {} } :: { { [number]: Model } } do
		for index, model in list do
			if index > count then
				model:Destroy()
				list[index] = nil
			end
		end
	end
	for i = 1, count do
		spawnSlotModel(player, i)
		spawnBoxModel(player, i)
	end
	afterSlotsChanged(player)
	PlotService.ApplySkin(player)
	PlotService.RefreshUpgradeSign(player)
	PlotService.Resized:Fire(player)
end

-- Buy the next bigger base.
function PlotService.BuySize(player: Player): boolean
	local profile = DataService.Get(player)
	if not profile then
		return false
	end
	local cost = Economy.BaseSizeCost(profile.Data.BaseLevel)
	if not cost then
		notify(player, "Your base is as big as it gets!", "error")
		return false
	end
	if not DataService.TrySpend(player, cost) then
		notify(player, "Not enough money! Need " .. Format.Money(cost), "error")
		return false
	end
	profile.Data.BaseLevel += 1
	DataService.SyncAttributes(player)
	PlotService.RefreshPen(player)
	notify(player, `🍩 Your base got bigger! Room for {PlotService.GetSlotCount(player)} donuts now.`, "success")
	return true
end

--------------------------------------------------------------------------------
-- Assign / release
--------------------------------------------------------------------------------
-- Put everything that belongs to the player's base on their plot.
local function showBase(player: Player)
	local index = playerPlots[player]
	local profile = DataService.Get(player)
	if not index then
		return
	end
	local plot = MapBuilder.GetPlot(index)
	plot:SetAttribute("OwnerUserId", player.UserId)
	player:SetAttribute("BaseWorld", 1)
	if profile then
		MapBuilder.BuildPen(plot, PlotService.GetSlotCount(player))
		for i = 1, PlotService.GetSlotCount(player) do
			spawnSlotModel(player, i)
			spawnBoxModel(player, i)
		end
	end
	recalcIncome(player)
	PlotService.ApplySkin(player)
	PlotService.RefreshSign(player)
	PlotService.RefreshPodium(player)
	refreshUpgradeSign(index, player)
end

-- Take the player's base off their plot.
local function hideBase(player: Player)
	local index = playerPlots[player]
	if not index then
		return
	end
	for _, list in { slotModels[player] or {}, boxModels[player] or {} } :: { { [number]: Model } } do
		for _, model in list do
			model:Destroy()
		end
	end
	slotModels[player] = {}
	boxModels[player] = {}
	local plot = MapBuilder.GetPlot(index)
	plot:SetAttribute("OwnerUserId", nil)
	MapBuilder.BuildPen(plot, Config.Plots.Sizes[1].Slots)
	local podium = plot:FindFirstChild("Podium")
	if podium then
		podium:Destroy()
	end
	applySkinToPlot(plot, "Classic")
	refreshSign(index, nil)
	refreshUpgradeSign(index, nil)
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
	player:SetAttribute("PlotIndex", index)

	local profile = DataService.Get(player)
	if profile then
		-- Drop any saved slot that points at a donut that no longer exists (e.g. removed from
		-- Donuts.luau), and move anything saved past the end of the base into free spots.
		for key, slot in profile.Data.Slots do
			if not Donuts.ById[slot.Id] or not tonumber(key) then
				profile.Data.Slots[key] = nil
			end
		end
		for key, box in profile.Data.PenBoxes do
			if not tonumber(key) or not Donuts.HasBox(box.Area, box.Tier) then
				profile.Data.PenBoxes[key] = nil
			end
		end
		compactSlots(player)
	end
	showBase(player)
	return index
end

function PlotService.Release(player: Player)
	local index = playerPlots[player]
	if not index then
		return
	end
	hideBase(player)
	slotModels[player] = nil
	boxModels[player] = nil
	opening[player] = nil
	lastNotReady[player] = nil
	labelMultiplier[player] = nil
	baseIncome[player] = nil
	playerPlots[player] = nil
	plotOwners[index] = nil
end

function PlotService.Init()
	for i = 1, Config.Plots.Count do
		refreshSign(i, nil)
		setUpUpgradeSign(i)
		refreshUpgradeSign(i, nil)
	end
	task.spawn(function()
		while true do
			task.wait(1)
			updateBoxes()
			-- (the upgrade buttons turn green the moment their owner can afford the next size)
			for player, index in playerPlots do
				refreshUpgradeSign(index, player)
			end
		end
	end)
end

return PlotService
