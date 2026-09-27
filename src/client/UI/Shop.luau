--[[
	Shop window with three tabs:
	  Upgrades  - Speed Multiplier and Treadmill tiers (in-game money)
	  Passes    - 1.5x / 2x / 3x / 4x / 5x / 10x Money and 2x Speed (Robux)
	  Skins     - base skins (Robux), equip the ones you own
]]

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)

local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local State = require(script.Parent.Parent.State)

local Shop = {}

local modal: Modal.Modal
local pages: { [string]: ScrollingFrame } = {}
local selectTab: (string) -> ()
local refreshers: { () -> () } = {}
local robuxPrices: { [number]: number } = {}

local function refreshAll()
	for _, refresh in refreshers do
		refresh()
	end
end

local function newPage(name: string, parent: Instance, columns: number, cardHeight: number): ScrollingFrame
	local page = Theme.new("ScrollingFrame", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 1, -54),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
		Parent = parent,
	}, {
		Theme.new("UIGridLayout", {
			CellSize = UDim2.new(1 / columns, -10, 0, cardHeight),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Theme.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 8) }),
	})
	pages[name] = page
	return page
end

local function card(parent: Instance, order: number, color: Color3): Frame
	return Theme.new("Frame", {
		BackgroundColor3 = Theme.Colors.PanelLight,
		LayoutOrder = order,
		Parent = parent,
	}, {
		Theme.Corner(14),
		Theme.Stroke(3, Theme.Darken(color, 0.3)),
		Theme.Gradient(Theme.Lighten(Theme.Colors.PanelLight, 0.08), Theme.Colors.Panel),
	})
end

--------------------------------------------------------------------------------
-- Upgrades
--------------------------------------------------------------------------------
local function buildUpgrades(page: ScrollingFrame)
	-- Speed multiplier
	local multCard = card(page, 1, Theme.Colors.Purple)
	Theme.Label({ Text = "⚡ SPEED MULTIPLIER", TextColor3 = Color3.fromRGB(200, 160, 255), Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 8), Parent = multCard })
	local multInfo = Theme.Label({ Text = "", Font = Theme.Font, Size = UDim2.new(1, -20, 0, 50), Position = UDim2.fromOffset(10, 46), StrokeThickness = 1.5, Parent = multCard })
	local multButton = Theme.Button({ Text = "", Color = Theme.Colors.Green, Size = UDim2.new(1, -20, 0, 54), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Parent = multCard })
	multButton.Activated:Connect(function()
		State.Action("BuySpeedMultiplier")
	end)

	-- Treadmill
	local treadCard = card(page, 2, Theme.Colors.Orange)
	Theme.Label({ Text = "🏃 TREADMILL", TextColor3 = Color3.fromRGB(255, 200, 120), Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 8), Parent = treadCard })
	local treadInfo = Theme.Label({ Text = "", Font = Theme.Font, Size = UDim2.new(1, -20, 0, 50), Position = UDim2.fromOffset(10, 46), StrokeThickness = 1.5, Parent = treadCard })
	local treadButton = Theme.Button({ Text = "", Color = Theme.Colors.Green, Size = UDim2.new(1, -20, 0, 54), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Parent = treadCard })
	treadButton.Activated:Connect(function()
		State.Action("BuyTreadmill")
	end)

	-- Summary
	local summary = card(page, 3, Theme.Colors.Blue)
	local summaryText = Theme.Label({ Text = "", Font = Theme.Font, RichText = true, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -24, 1, -20), Position = UDim2.fromOffset(12, 10), StrokeThickness = 1.5, Parent = summary })
	local tip = card(page, 4, Theme.Colors.Green)
	Theme.Label({
		Text = "💡 Run on your treadmill to gain Speed. Faster = you can steal from further areas, where donuts are rarer and earn way more!",
		Font = Theme.Font, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -24, 1, -20), Position = UDim2.fromOffset(12, 10), StrokeThickness = 1.5, Parent = tip,
	})

	table.insert(refreshers, function()
		local money = State.Number("Money")
		local passMult = math.max(1, State.Number("SpeedPassMultiplier"))

		local multLevel = State.Number("SpeedMultLevel")
		if multLevel >= Config.SpeedMultiplier.MaxLevel then
			multInfo.Text = `x{Economy.SpeedMultiplier(multLevel)} (MAX)`
			Theme.SetButtonText(multButton, "MAXED")
			Theme.SetButtonColor(multButton, Theme.Colors.Gray)
		else
			local cost = Economy.SpeedMultiplierCost(multLevel)
			multInfo.Text = `x{Economy.SpeedMultiplier(multLevel)}  →  x{Economy.SpeedMultiplier(multLevel + 1)}\nMultiplies treadmill speed gain`
			Theme.SetButtonText(multButton, "Buy " .. Format.Money(cost))
			Theme.SetButtonColor(multButton, if money >= cost then Theme.Colors.Green else Theme.Colors.Gray)
		end

		local level = math.max(1, State.Number("TreadmillLevel"))
		local tier = Economy.TreadmillTier(level)
		if level >= Economy.MaxTreadmillLevel() then
			treadInfo.Text = `{tier.Name} (Tier {level}/{Economy.MaxTreadmillLevel()}) - the best!\n+{Format.Number(tier.Rate)} speed/s base`
			Theme.SetButtonText(treadButton, "MAXED")
			Theme.SetButtonColor(treadButton, Theme.Colors.Gray)
		else
			local nextTier = Economy.TreadmillTier(level + 1)
			treadInfo.Text = `{tier.Name} → {nextTier.Name} (Tier {level + 1})\n+{Format.Number(tier.Rate)}/s → +{Format.Number(nextTier.Rate)}/s base`
			Theme.SetButtonText(treadButton, "Buy " .. Format.Money(nextTier.Cost))
			Theme.SetButtonColor(treadButton, if money >= nextTier.Cost then Theme.Colors.Green else Theme.Colors.Gray)
		end

		local rate = Economy.TreadmillRate(level, multLevel, passMult)
		local walk = Economy.WalkSpeedFromStat(State.Number("Speed"))
		summaryText.Text = `<b>YOUR STATS</b>\nTreadmill: <font color="#c9a0ff">+{Format.Number(rate)} speed/s</font>\nSpeed: <font color="#c9a0ff">{Format.Number(State.Number("Speed"))}</font> (walk speed {math.floor(walk)})\nIncome: <font color="#8dff6a">{Format.Money(State.Number("Income"))}/s</font>`
	end)
end

--------------------------------------------------------------------------------
-- Game passes
--------------------------------------------------------------------------------
local function robuxText(passId: number, suggested: number): string
	if passId <= 0 then
		return `R$ {suggested}`
	end
	local price = robuxPrices[passId]
	return if price then `R$ {price}` else "R$ ..."
end

local function fetchPrice(passId: number)
	if passId <= 0 or robuxPrices[passId] then
		return
	end
	task.spawn(function()
		local ok, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, passId, Enum.InfoType.GamePass)
		if ok and info and info.PriceInRobux then
			robuxPrices[passId] = info.PriceInRobux
			refreshAll()
		end
	end)
end

local function buildPasses(page: ScrollingFrame)
	for order, pass in Config.GamePasses do
		fetchPrice(pass.GamePassId)
		local c = card(page, order, pass.Color)
		local isMoney = pass.Kind == "Money"
		Theme.Label({ Text = if isMoney then "💵" else "⚡", Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(10, 10), Parent = c })
		Theme.Label({ Text = string.upper(pass.Name), TextColor3 = pass.Color:Lerp(Color3.new(1, 1, 1), 0.3), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -86, 0, 36), Position = UDim2.fromOffset(74, 12), Parent = c })
		Theme.Label({
			Text = if isMoney then `Earn {pass.Multiplier}x money from every donut, forever` else "Double speed from your treadmill, forever",
			Font = Theme.Font, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -86, 0, 36), Position = UDim2.fromOffset(74, 50), StrokeThickness = 1.2, Parent = c,
		})
		local button = Theme.Button({ Text = "", Color = Theme.Colors.Green, Size = UDim2.new(1, -20, 0, 48), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Parent = c })
		button.Activated:Connect(function()
			if not State.Data.Passes[pass.Key] then
				State.Action("BuyPass", pass.Key)
			end
		end)
		table.insert(refreshers, function()
			if State.Data.Passes[pass.Key] then
				Theme.SetButtonText(button, "OWNED ✓")
				Theme.SetButtonColor(button, Theme.Colors.Gray)
			else
				Theme.SetButtonText(button, robuxText(pass.GamePassId, pass.SuggestedPrice))
				Theme.SetButtonColor(button, Theme.Colors.Green)
			end
		end)
	end
	if Config.MoneyPassStacking == "Additive" then
		local note = card(page, 100, Theme.Colors.Blue)
		Theme.Label({ Text = "💡 Money passes stack! Own 2x + 3x = 4x money.", Font = Theme.Font, Size = UDim2.new(1, -20, 1, -20), Position = UDim2.fromOffset(10, 10), StrokeThickness = 1.5, Parent = note })
	end
end

--------------------------------------------------------------------------------
-- Skins
--------------------------------------------------------------------------------
local function buildSkins(page: ScrollingFrame)
	for order, skin in Config.Skins do
		fetchPrice(skin.GamePassId)
		local c = card(page, order, skin.Trim)
		-- Colour swatch preview of the skin
		local swatch = Theme.new("Frame", { Size = UDim2.new(1, -20, 0, 64), Position = UDim2.fromOffset(10, 10), BackgroundColor3 = skin.Floor, Parent = c }, { Theme.Corner(10), Theme.Stroke(2) })
		for i, color in { skin.FloorAlt, skin.Fence, skin.Trim, skin.Pedestal } do
			Theme.new("Frame", { Size = UDim2.new(0.2, -4, 1, -16), Position = UDim2.new(0.04 + (i - 1) * 0.24, 0, 0, 8), BackgroundColor3 = color, Parent = swatch }, { Theme.Corner(8), Theme.Stroke(1.5) })
		end
		Theme.Label({ Text = string.upper(skin.Name), Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 80), Parent = c })
		local button = Theme.Button({ Text = "", Color = Theme.Colors.Green, Size = UDim2.new(1, -20, 0, 46), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Parent = c })
		button.Activated:Connect(function()
			if State.Data.OwnedSkins[skin.Id] or skin.Free then
				State.Action("EquipSkin", skin.Id)
			else
				State.Action("BuySkin", skin.Id)
			end
		end)
		table.insert(refreshers, function()
			local owned = skin.Free or State.Data.OwnedSkins[skin.Id]
			if State.Data.EquippedSkin == skin.Id then
				Theme.SetButtonText(button, "EQUIPPED")
				Theme.SetButtonColor(button, Theme.Colors.Gray)
			elseif owned then
				Theme.SetButtonText(button, "EQUIP")
				Theme.SetButtonColor(button, Theme.Colors.Blue)
			else
				Theme.SetButtonText(button, robuxText(skin.GamePassId, skin.SuggestedPrice))
				Theme.SetButtonColor(button, Theme.Colors.Green)
			end
		end)
	end
end

function Shop.Open(tab: string?)
	modal:Open()
	selectTab(tab or "Upgrades")
end

function Shop.Init()
	modal = Modal.new("🛒 SHOP", Theme.Colors.Green, Vector2.new(760, 500))
	local body = modal.Body
	selectTab = Modal.Tabs(body, {
		{ Name = "Upgrades", Text = "⚡ Upgrades", Color = Theme.Colors.Purple },
		{ Name = "Passes", Text = "🎟️ Passes", Color = Theme.Colors.Orange },
		{ Name = "Skins", Text = "🎨 Base Skins", Color = Theme.Colors.Pink },
	}, function(name)
		for pageName, page in pages do
			page.Visible = pageName == name
		end
		refreshAll()
	end)
	buildUpgrades(newPage("Upgrades", body, 2, 190))
	buildPasses(newPage("Passes", body, 2, 160))
	buildSkins(newPage("Skins", body, 3, 180))

	for _, name in { "Money", "Speed", "SpeedMultLevel", "TreadmillLevel", "SpeedPassMultiplier", "Income" } do
		State.OnAttribute(name, function()
			if modal:IsOpen() then
				refreshAll()
			end
		end)
	end
	State.Changed:Connect(refreshAll)

	-- The shop stall in the hub opens this window
	task.spawn(function()
		local map = workspace:WaitForChild("Map")
		local prompt = map:WaitForChild("Hub"):WaitForChild("ShopStall"):WaitForChild("PromptPart")
		local proximity = Theme.new("ProximityPrompt", {
			ActionText = "Open Shop",
			ObjectText = "Shop",
			HoldDuration = 0,
			MaxActivationDistance = 12,
			RequiresLineOfSight = false,
			Parent = prompt,
		})
		proximity.Triggered:Connect(function()
			Shop.Open("Upgrades")
		end)
	end)
end

return Shop
