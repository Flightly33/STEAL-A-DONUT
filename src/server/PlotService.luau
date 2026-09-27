--[[
	PlotService
	===========
	Player bases: plot assignment, the donuts on their pedestals (with Upgrade / Sell prompts),
	base income, the owner sign, base skins, and the podium that shows off the player's rarest or
	best-earning donut.
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

local Build = require(script.Parent.Build)
local MapBuilder = require(script.Parent.MapBuilder)
local DataService = require(script.Parent.DataService)

local PlotService = {}

-- Set by RaidService: called for every new raid prompt (owner, slotIndex, prompt).
PlotService.RaidHandler = nil :: ((Player, number, ProximityPrompt) -> ())?

local rgb = Color3.fromRGB

local plotOwners: { [number]: Player } = {}
local playerPlots: { [Player]: number } = {}
local slotModels: { [Player]: { [number]: Model } } = {}
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

function PlotService.GetPlotModel(player: Player): Model?
	local index = playerPlots[player]
	return if index then MapBuilder.GetPlot(index) else nil
end

function PlotService.GetSpawnCFrame(player: Player): CFrame?
	local plot = PlotService.GetPlotModel(player)
	local spawn = plot and plot:FindFirstChild("Spawn") :: BasePart?
	return if spawn then spawn.CFrame * CFrame.new(0, 3.5, 0) else nil
end

function PlotService.IsInOwnPlot(player: Player, position: Vector3): boolean
	local index = playerPlots[player]
	return index ~= nil and Layout.IsInPlot(index, position)
end

function PlotService.GetBaseIncome(player: Player): number
	return baseIncome[player] or 0
end

function PlotService.GetFreeSlot(player: Player): number?
	local profile = DataService.Get(player)
	if not profile then
		return nil
	end
	for i = 1, Config.Plots.SlotsPerPlot do
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
			total += Economy.DonutIncome(slot.Id, slot.Level)
		end
	end
	baseIncome[player] = total
end

--------------------------------------------------------------------------------
-- Sign above the plot
--------------------------------------------------------------------------------
local function refreshSign(plotIndex: number, owner: Player?)
	local plot = MapBuilder.GetPlot(plotIndex)
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
	if owner then
		nameLabel.Text = owner.DisplayName
		nameLabel.TextColor3 = rgb(255, 255, 255)
		local profile = DataService.Get(owner)
		local mult = if profile then Economy.MoneyMultiplier(profile.Passes) else 1
		incomeLabel.Text = Format.Money((baseIncome[owner] or 0) * mult) .. "/s"
	else
		nameLabel.Text = "Empty Base"
		nameLabel.TextColor3 = rgb(200, 200, 200)
		incomeLabel.Text = ""
	end
end

function PlotService.RefreshSign(player: Player)
	local index = playerPlots[player]
	if index then
		refreshSign(index, player)
	end
end

--------------------------------------------------------------------------------
-- Podium (rarest / best earning donut)
--------------------------------------------------------------------------------
local function pickPodiumDonut(player: Player): (string?, number)
	local profile = DataService.Get(player)
	if not profile then
		return nil, 1
	end
	local mode = profile.Data.PodiumMode
	local bestId, bestLevel, bestKey = nil, 1, -math.huge
	for _, slot in profile.Data.Slots do
		local donut = Donuts.ById[slot.Id]
		if donut then
			local income = Economy.DonutIncome(slot.Id, slot.Level)
			local key = if mode == "Earner" then income else Rarities.Get(donut.Rarity).Order * 1e30 + income
			if key > bestKey then
				bestId, bestLevel, bestKey = slot.Id, slot.Level, key
			end
		end
	end
	return bestId, bestLevel
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

	local donutId, level = pickPodiumDonut(player)
	local donut = donutId and Donuts.ById[donutId]
	local showcase = Instance.new("Folder")
	showcase.Name = "Showcase"
	showcase.Parent = podium

	local labelHolder = Build.Part({ Parent = showcase, Name = "LabelHolder", Size = Vector3.one, CFrame = top.CFrame, Transparency = 1, CanCollide = false, CanQuery = false })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(14, 2)
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.Parent = labelHolder

	if donut then
		local model = DonutModel.Build(donut, { Scale = Config.Plots.PodiumDonutScale })
		DonutModel.PlaceOn(model, top.CFrame * CFrame.new(0, 0.1, 0))
		CollectionService:AddTag(model, "PodiumSpin")
		model.Parent = showcase
		local info = DonutModel.CreateBillboard(donut, Economy.DonutIncome(donut.Id, level), level, (model:GetAttribute("Top") :: number?) or 3)
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

local function updateSlotLabels(player: Player, slotIndex: number)
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
	local income = Economy.DonutIncome(slot.Id, slot.Level)
	model:SetAttribute("Income", income) -- used by the client's "+$" popups

	local old = root:FindFirstChild("DonutInfo")
	if old then
		old:Destroy()
	end
	local info = DonutModel.CreateBillboard(donut, income, slot.Level, (model:GetAttribute("Top") :: number?) or 3)
	info.Parent = root

	local upgrade = root:FindFirstChild("UpgradePrompt") :: ProximityPrompt?
	local sell = root:FindFirstChild("SellPrompt") :: ProximityPrompt?
	if upgrade then
		if slot.Level >= Config.DonutUpgrade.MaxLevel then
			upgrade.ActionText = "MAX LEVEL"
			upgrade.Enabled = false
		else
			upgrade.ActionText = "Upgrade " .. Format.Money(Economy.DonutUpgradeCost(slot.Id, slot.Level))
		end
		upgrade.ObjectText = `Lv. {slot.Level} → {slot.Level + 1}  (+{Format.Money(donut.Income * Config.DonutUpgrade.IncomePerLevel)}/s)`
	end
	if sell then
		sell.ActionText = "Sell " .. Format.Money(Economy.SellPrice(slot.Id, slot.Level))
		sell.ObjectText = donut.Name
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

	local model = DonutModel.Build(donut, { Scale = Config.Plots.DonutScale })
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

	-- Raid prompt: other players hold this for Config.Raid.HoldSeconds while the owner is away.
	-- RaidService turns it on/off and handles the steal; the owner never sees it.
	if Config.Raid.Enabled then
		local raid = Instance.new("ProximityPrompt")
		raid.Name = "RaidPrompt"
		raid.ActionText = "Steal"
		raid.ObjectText = donut.Name
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

	model.Parent = plot
	slotModels[player][slotIndex] = model
	updateSlotLabels(player, slotIndex)
end

local function afterSlotsChanged(player: Player)
	recalcIncome(player)
	PlotService.RefreshSign(player)
	PlotService.RefreshPodium(player)
end

-- Put a donut on the first free pedestal. Returns the slot index, or nil when the base is full.
function PlotService.AddDonut(player: Player, donutId: string, level: number?): number?
	local profile = DataService.Get(player)
	local slotIndex = PlotService.GetFreeSlot(player)
	if not profile or not slotIndex or not Donuts.ById[donutId] then
		return nil
	end
	profile.Data.Slots[tostring(slotIndex)] = { Id = donutId, Level = level or 1 }
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
	local cost = Economy.DonutUpgradeCost(slot.Id, slot.Level)
	if not DataService.TrySpend(player, cost) then
		notify(player, "Not enough money! Need " .. Format.Money(cost), "error")
		return
	end
	slot.Level += 1
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
	local price = Economy.SellPrice(slot.Id, slot.Level)
	local donut = Donuts.ById[slot.Id]
	profile.Data.Slots[key] = nil
	DataService.AddMoney(player, price, false)
	local model = slotModels[player] and slotModels[player][slotIndex]
	if model then
		model:Destroy()
		slotModels[player][slotIndex] = nil
	end
	afterSlotsChanged(player)
	notify(player, `Sold {donut and donut.Name or "donut"} for {Format.Money(price)}`, "success")
end

--------------------------------------------------------------------------------
-- Skins
--------------------------------------------------------------------------------
local function clearChildren(instance: Instance)
	for _, child in instance:GetChildren() do
		child:Destroy()
	end
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
	local center = Layout.PlotCFrame(plot:GetAttribute("PlotIndex") :: number)
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
			if pedestal:IsA("BasePart") then
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
-- Assign / release
--------------------------------------------------------------------------------
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
	MapBuilder.GetPlot(index):SetAttribute("OwnerUserId", player.UserId)

	local profile = DataService.Get(player)
	if profile then
		-- Drop any saved slot that points at a donut that no longer exists (e.g. removed from Donuts.luau).
		for key, slot in profile.Data.Slots do
			if not Donuts.ById[slot.Id] or (tonumber(key) or 99) > Config.Plots.SlotsPerPlot then
				profile.Data.Slots[key] = nil
			end
		end
		for i = 1, Config.Plots.SlotsPerPlot do
			spawnSlotModel(player, i)
		end
	end
	recalcIncome(player)
	PlotService.ApplySkin(player)
	PlotService.RefreshSign(player)
	PlotService.RefreshPodium(player)
	return index
end

function PlotService.Release(player: Player)
	local index = playerPlots[player]
	if not index then
		return
	end
	if slotModels[player] then
		for _, model in slotModels[player] do
			model:Destroy()
		end
	end
	slotModels[player] = nil
	baseIncome[player] = nil
	playerPlots[player] = nil
	plotOwners[index] = nil

	local plot = MapBuilder.GetPlot(index)
	plot:SetAttribute("OwnerUserId", nil)
	local podium = plot:FindFirstChild("Podium")
	if podium then
		podium:Destroy()
	end
	applySkinToPlot(plot, "Classic")
	refreshSign(index, nil)
end

function PlotService.Init()
	for i = 1, Config.Plots.Count do
		refreshSign(i, nil)
	end
end

return PlotService
