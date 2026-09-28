--[[
	Shop window with five tabs:
	  Upgrades  - Speed Multiplier, Treadmill tiers, Base Expansions and Incubator upgrades (money)
	  Passes    - 1.5x / 2x / 3x / 4x / 5x / 10x Money, 2x Speed, Teleporter and the Luck Event (Robux)
	  Crates    - Common / Rare / Epic / Legendary crates (Robux). Every outcome and its exact chance
	              is shown on the card, and "All odds" lists the pets inside every egg too (Roblox's
	              paid random items rules). Hidden purchase for players whose region blocks them.
	  Items     - weapons, traps and the base lock (in-game money), with spinning 3D previews of the
	              real models (shared/ItemModel.luau)
	  Skins     - base skins (paid with your Speed stat), equip the ones you own
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local ItemModel = require(Shared.ItemModel)
local Crates = require(Shared.Crates)
local CrateModel = require(Shared.CrateModel)
local Pets = require(Shared.Pets)

local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local State = require(script.Parent.Parent.State)

local Shop = {}

local modal: Modal.Modal
local pages: { [string]: ScrollingFrame } = {}
local selectTab: (string) -> ()
local refreshers: { () -> () } = {}
local robuxPrices: { [number]: number } = {}
local buildItems: (ScrollingFrame) -> ()

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

	-- Base expansion
	local expandCard = card(page, 3, Theme.Colors.Blue)
	local expandTitle = Theme.Label({ Text = "🏗 BASE EXPANSION", TextColor3 = Color3.fromRGB(140, 210, 255), Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 8), Parent = expandCard })
	local expandInfo = Theme.Label({ Text = "", Font = Theme.Font, Size = UDim2.new(1, -20, 0, 50), Position = UDim2.fromOffset(10, 46), StrokeThickness = 1.5, Parent = expandCard })
	local expandButton = Theme.Button({ Text = "", Color = Theme.Colors.Green, Size = UDim2.new(1, -20, 0, 54), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Parent = expandCard })
	expandButton.Activated:Connect(function()
		local expansions = State.Number("Expansions")
		if Economy.ExpansionCost(expansions) then
			State.Action("BuyExpansion")
		elseif Economy.SecondFloorCost(expansions, math.max(1, State.Number("Floors"))) then
			State.Action("BuySecondFloor")
		end
	end)

	-- Incubator upgrades
	local function incubatorCard(order: number, kind: string, title: string, color: Color3): (TextLabel, TextButton)
		local c = card(page, order, color)
		Theme.Label({ Text = title, TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.4), Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 8), Parent = c })
		local info = Theme.Label({ Text = "", Font = Theme.Font, Size = UDim2.new(1, -20, 0, 50), Position = UDim2.fromOffset(10, 46), StrokeThickness = 1.5, Parent = c })
		local button = Theme.Button({ Text = "", Color = Theme.Colors.Green, Size = UDim2.new(1, -20, 0, 54), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Parent = c })
		button.Activated:Connect(function()
			State.Action("BuyIncubatorUpgrade", kind)
		end)
		return info, button
	end
	local hatchInfo, hatchButton = incubatorCard(4, "Speed", "⚡ INCUBATOR SPEED", Theme.Colors.Pink)
	local sizeInfo, sizeButton = incubatorCard(5, "Size", "🥚 INCUBATOR SIZE", Theme.Colors.Orange)

	-- Summary
	local summary = card(page, 6, Theme.Colors.Blue)
	local summaryText = Theme.Label({ Text = "", Font = Theme.Font, RichText = true, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -24, 1, -20), Position = UDim2.fromOffset(12, 10), StrokeThickness = 1.5, Parent = summary })
	local tip = card(page, 7, Theme.Colors.Green)
	Theme.Label({
		Text = `💡 Run on your treadmill to gain Speed: every {Config.Speed.SpeedPerWalk} Speed is +1 walk speed. Faster = you can steal from further areas, where donuts are rarer and earn way more! Upgrading your donuts (E on them) is cheap early on.`,
		Font = Theme.Font, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -24, 1, -20), Position = UDim2.fromOffset(12, 10), StrokeThickness = 1.5, Parent = tip,
	})

	table.insert(refreshers, function()
		local money = State.Number("Money")
		local passMult = math.max(1, State.Number("SpeedPassMultiplier"))

		local rebirths = State.Number("Rebirths")
		local multLevel = State.Number("SpeedMultLevel")
		if multLevel >= Config.SpeedMultiplier.MaxLevel then
			multInfo.Text = `x{Format.Multiplier(Economy.SpeedMultiplier(multLevel))} (MAX)`
			Theme.SetButtonText(multButton, "MAXED")
			Theme.SetButtonColor(multButton, Theme.Colors.Gray)
		else
			local cost = Economy.SpeedMultiplierCost(multLevel)
			local percent = math.floor(Config.SpeedMultiplier.PerLevel * 100 + 0.5)
			multInfo.Text = `x{Format.Multiplier(Economy.SpeedMultiplier(multLevel))}  →  x{Format.Multiplier(Economy.SpeedMultiplier(multLevel + 1))}\n+{percent}% treadmill speed per level (Lv {multLevel}/{Config.SpeedMultiplier.MaxLevel})`
			Theme.SetButtonText(multButton, "Buy " .. Format.Money(cost))
			Theme.SetButtonColor(multButton, if money >= cost then Theme.Colors.Green else Theme.Colors.Gray)
		end

		local level = math.max(1, State.Number("TreadmillLevel"))
		local tier = Economy.TreadmillTier(level)
		if level >= Economy.MaxTreadmillLevel() then
			treadInfo.Text = `{tier.Name} (Tier {level}/{Economy.MaxTreadmillLevel()}) - the best!\n+{Format.Rate(tier.Rate)} speed/s base`
			Theme.SetButtonText(treadButton, "MAXED")
			Theme.SetButtonColor(treadButton, Theme.Colors.Gray)
		else
			local nextTier = Economy.TreadmillTier(level + 1)
			treadInfo.Text = `{tier.Name} → {nextTier.Name} (Tier {level + 1})\n+{Format.Rate(tier.Rate)}/s → +{Format.Rate(nextTier.Rate)}/s base`
			if rebirths < nextTier.RequiredRebirths then
				Theme.SetButtonText(treadButton, `🔒 Needs Rebirth {nextTier.RequiredRebirths}`)
				Theme.SetButtonColor(treadButton, Theme.Colors.Gray)
			else
				Theme.SetButtonText(treadButton, "Buy " .. Format.Money(nextTier.Cost))
				Theme.SetButtonColor(treadButton, if money >= nextTier.Cost then Theme.Colors.Green else Theme.Colors.Gray)
			end
		end

		local expansions = State.Number("Expansions")
		local floors = math.max(1, State.Number("Floors"))
		local slots = Economy.SlotCount(expansions, floors)
		local expandCost = Economy.ExpansionCost(expansions)
		local floorCost = Economy.SecondFloorCost(expansions, floors)
		if expandCost then
			expandTitle.Text = "🏗 BASE EXPANSION"
			expandInfo.Text = `{slots} → {slots + Config.Plots.ExpansionSlots} donut stands\nKept forever, even when you rebirth`
			Theme.SetButtonText(expandButton, "Buy " .. Format.Money(expandCost))
			Theme.SetButtonColor(expandButton, if money >= expandCost then Theme.Colors.Green else Theme.Colors.Gray)
		elseif floorCost then
			-- Ground floor full: the next step is a whole second floor
			expandTitle.Text = "🏢 SECOND FLOOR"
			expandInfo.Text = `{slots} → {slots + Config.Plots.SecondFloor.Slots} donut stands on a new floor\nKept forever, even when you rebirth`
			Theme.SetButtonText(expandButton, "Buy " .. Format.Money(floorCost))
			Theme.SetButtonColor(expandButton, if money >= floorCost then Theme.Colors.Green else Theme.Colors.Gray)
		else
			expandTitle.Text = "🏢 BASE"
			expandInfo.Text = `{slots} donut stands on 2 floors - fully built!`
			Theme.SetButtonText(expandButton, "MAXED")
			Theme.SetButtonColor(expandButton, Theme.Colors.Gray)
		end

		local function incubatorRow(kind: string, info: TextLabel, button: TextButton)
			local level = State.Number(if kind == "Speed" then "IncubatorSpeed" else "IncubatorSize")
			local cost = Economy.IncubatorUpgradeCost(kind, level)
			local now = if kind == "Speed" then `x{Format.Multiplier(Economy.IncubatorSpeed(level))} hatch speed` else `{Economy.IncubatorCapacity(level)} eggs at once`
			if cost then
				local nextText = if kind == "Speed" then `x{Format.Multiplier(Economy.IncubatorSpeed(level + 1))}` else `{Economy.IncubatorCapacity(level + 1)} eggs`
				info.Text = `{now}  →  {nextText}\nKept forever, even when you rebirth`
				Theme.SetButtonText(button, "Buy " .. Format.Money(cost))
				Theme.SetButtonColor(button, if money >= cost then Theme.Colors.Green else Theme.Colors.Gray)
			else
				info.Text = `{now} (MAX)`
				Theme.SetButtonText(button, "MAXED")
				Theme.SetButtonColor(button, Theme.Colors.Gray)
			end
		end
		incubatorRow("Speed", hatchInfo, hatchButton)
		incubatorRow("Size", sizeInfo, sizeButton)

		local indexBonus = State.Number("IndexBonus")
		local petBonus = State.Number("PetSpeedBonus")
		local rate = Economy.TreadmillRate(level, multLevel, passMult, rebirths, indexBonus, petBonus)
		local walk = State.Number("WalkSpeed")
		local extras = {}
		if rebirths > 0 then
			table.insert(extras, `🔄 x{Format.Multiplier(Economy.RebirthSpeedMultiplier(rebirths))}`)
		end
		if indexBonus > 0 then
			table.insert(extras, `📖 +{indexBonus}%`)
		end
		if petBonus > 0 then
			table.insert(extras, `🐾 +{math.floor(petBonus * 100 + 0.5)}%`)
		end
		local extraText = if #extras > 0 then " (" .. table.concat(extras, " ") .. ")" else ""
		summaryText.Text = `<b>YOUR STATS</b>\nTreadmill: <font color="#c9a0ff">+{Format.Rate(rate)} speed/s</font>{extraText}\nSpeed: <font color="#c9a0ff">{Format.Number(State.Number("Speed"))}</font> (walk speed {math.floor(walk)})\nIncome: <font color="#8dff6a">{Format.Money(State.Number("Income"))}/s</font>`
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

local function fetchPrice(passId: number, infoType: Enum.InfoType?)
	if passId <= 0 or robuxPrices[passId] then
		return
	end
	task.spawn(function()
		local ok, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, passId, infoType or Enum.InfoType.GamePass)
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
		local icon = if pass.Kind == "Money" then "💵" elseif pass.Kind == "Speed" then "⚡" else "🌀"
		local description = if pass.Kind == "Money"
			then `Earn {pass.Multiplier}x money from every donut, forever`
			elseif pass.Kind == "Speed" then "Double speed from your treadmill, forever"
			else "Teleport to any world or area you've unlocked, any time"
		Theme.Label({ Text = icon, Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(10, 10), Parent = c })
		Theme.Label({ Text = string.upper(pass.Name), TextColor3 = pass.Color:Lerp(Color3.new(1, 1, 1), 0.3), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -86, 0, 36), Position = UDim2.fromOffset(74, 12), Parent = c })
		Theme.Label({
			Text = description,
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
	-- Luck Event (a developer product: can be bought again and again)
	local luck = card(page, 90, Color3.fromRGB(60, 200, 90))
	Theme.Label({ Text = "🍀", Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(10, 10), Parent = luck })
	Theme.Label({ Text = "LUCK EVENT (10 MIN)", TextColor3 = Color3.fromRGB(140, 255, 160), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -86, 0, 36), Position = UDim2.fromOffset(74, 12), Parent = luck })
	Theme.Label({ Text = `Rare donuts x{Config.LuckEvent.RarityLuck}, mutations x{Config.LuckEvent.MutationLuck}, big sizes x{Config.LuckEvent.BigSizeLuck} for EVERYONE (boosted odds show in the Index)`, Font = Theme.Font, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -86, 0, 36), Position = UDim2.fromOffset(74, 50), StrokeThickness = 1.2, Parent = luck })
	local luckButton = Theme.Button({ Text = `R$ {Config.LuckEvent.SuggestedPrice}`, Color = Theme.Colors.Green, Size = UDim2.new(1, -20, 0, 48), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Parent = luck })
	luckButton.Activated:Connect(function()
		State.Action("BuyLuck")
	end)

	if Config.MoneyPassStacking == "Additive" then
		local note = card(page, 100, Theme.Colors.Blue)
		Theme.Label({ Text = "💡 Money passes stack! Own 2x + 3x = 4x money.", Font = Theme.Font, Size = UDim2.new(1, -20, 1, -20), Position = UDim2.fromOffset(10, 10), StrokeThickness = 1.5, Parent = note })
	end
end

--------------------------------------------------------------------------------
-- Crates
--------------------------------------------------------------------------------
local KIND_ICON = { Coins = "💰", SpeedBoost = "⚡", Luck = "🍀", Egg = "🥚", Pet = "🐾" }

local function percent(chance: number): string
	local p = chance * 100
	return if p >= 10 then string.format("%.1f%%", p) elseif p >= 1 then string.format("%.2f%%", p) else string.format("%.3f%%", p)
end

-- What an outcome gives, in words (coins are estimated for you right now).
local function outcomeText(outcome: Crates.Outcome): string
	local reward = outcome.Reward
	if reward.Kind == "Coins" then
		local amount = Economy.CrateCoins(reward.Seconds or 60, State.Number("Speed"), State.Number("Rebirths"))
		return `Coins (~{Format.Money(amount)} for you now)`
	elseif reward.Kind == "SpeedBoost" then
		return `Speed Boost: run {math.floor((Config.Crates.SpeedBoostMultiplier - 1) * 100 + 0.5)}% faster for {Format.Duration(reward.Seconds or 600)}`
	elseif reward.Kind == "Luck" then
		return `Luck Event for the whole server ({Format.Duration(reward.Seconds or 600)})`
	elseif outcome.Egg then
		local egg = Pets.EggById[outcome.Egg]
		return if egg then egg.Name .. (if egg.CrateOnly then " (exclusive)" else "") else outcome.Egg
	elseif outcome.Pet then
		local pet = Pets.ById[outcome.Pet]
		return if pet then `{pet.Name} ({pet.Rarity} pet, exclusive)` else outcome.Pet
	end
	return reward.Kind
end

local function buildCrates(page: ScrollingFrame, body: Instance)
	-- "All odds" panel (on top of the shop): every outcome, and the pets inside every egg
	local details = Theme.new("Frame", {
		Name = "CrateOdds",
		BackgroundColor3 = Theme.Colors.Panel,
		Size = UDim2.new(1, 0, 1, -54),
		Position = UDim2.fromOffset(0, 54),
		Visible = false,
		ZIndex = 20,
		Parent = body,
	}, { Theme.Corner(14), Theme.Stroke(3) })
	local detailsTitle = Theme.Label({ Text = "", Size = UDim2.new(1, -130, 0, 36), Position = UDim2.fromOffset(12, 8), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21, Parent = details })
	local close = Theme.Button({ Text = "BACK", Color = Theme.Colors.Red, Size = UDim2.fromOffset(100, 38), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Parent = details })
	close.ZIndex = 21
	close.Activated:Connect(function()
		details.Visible = false
	end)
	local detailsText = Theme.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 52),
		Size = UDim2.new(1, -24, 1, -62),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 8,
		ZIndex = 21,
		Parent = details,
	})
	local detailsLabel = Theme.Label({ Text = "", Font = Theme.Font, RichText = true, TextScaled = false, TextSize = 20, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -12, 0, 0), StrokeThickness = 1.2, ZIndex = 21, Parent = detailsText })

	local function showOdds(crate: Crates.Crate)
		detailsTitle.Text = `🎁 {string.upper(crate.Name)} - ALL ODDS`
		local lines = { "You get ONE of these (adds up to 100%). Luck and passes never change these odds.", "" }
		for _, outcome in Crates.Odds(crate) do
			table.insert(lines, `<b>{KIND_ICON[outcome.Reward.Kind] or "🎁"} {outcomeText(outcome)}: {percent(outcome.Chance)}</b>`)
			local egg = if outcome.Egg then Pets.EggById[outcome.Egg] else nil
			if egg then
				table.insert(lines, `      it hatches (after {Format.Duration(egg.HatchSeconds)}) into:`)
				for _, entry in egg.Pool do
					local pet = Pets.ById[entry.Pet]
					local inEgg = Pets.Chance(egg, entry.Pet)
					table.insert(lines, `      • {pet.Name} ({pet.Rarity}, {Pets.BonusText(pet)}): {percent(inEgg)} of the egg = {percent(outcome.Chance * inEgg)} of the crate`)
				end
			end
		end
		detailsLabel.Text = table.concat(lines, "\n")
		details.Visible = true
	end

	local spinning: { Camera } = {}
	for _, crate in Crates.List do
		local product = Config.Crates.Products[crate.Id]
		fetchPrice(product.DeveloperProductId, Enum.InfoType.Product)
		local c = card(page, crate.Order, crate.Color)
		local viewport = Theme.new("ViewportFrame", {
			BackgroundColor3 = Color3.fromRGB(25, 25, 40),
			Size = UDim2.fromOffset(84, 84),
			Position = UDim2.fromOffset(8, 8),
			Ambient = Color3.fromRGB(180, 180, 180),
			LightColor = Color3.fromRGB(255, 255, 255),
			LightDirection = Vector3.new(-0.5, -1, 0.8),
			Parent = c,
		}, { Theme.Corner(10) })
		local model = CrateModel.Build(crate.Id, { NoEffects = true })
		model:PivotTo(CFrame.new(0, -0.3, 0))
		model.Parent = viewport
		local camera = Instance.new("Camera")
		camera.FieldOfView = 40
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		table.insert(spinning, camera)
		Theme.Label({ Text = string.upper(crate.Name), TextColor3 = crate.Color:Lerp(Color3.new(1, 1, 1), 0.35), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -110, 0, 32), Position = UDim2.fromOffset(100, 10), Parent = c })
		Theme.Label({ Text = "Opens right away: ONE of these", Font = Theme.Font, TextColor3 = Color3.fromRGB(200, 200, 210), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -110, 0, 20), Position = UDim2.fromOffset(100, 44), StrokeThickness = 1, Parent = c })
		local odds = Theme.Label({ Text = "", Font = Theme.Font, RichText = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, -20, 0, 118), Position = UDim2.fromOffset(10, 98), StrokeThickness = 1.2, Parent = c })
		local all = Theme.Button({ Text = "📋 All odds", Color = Theme.Colors.Blue, Size = UDim2.new(0.38, -12, 0, 46), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -10), Parent = c })
		all.Activated:Connect(function()
			showOdds(crate)
		end)
		local buy = Theme.Button({ Text = "", Color = Theme.Colors.Green, Size = UDim2.new(0.62, -12, 0, 46), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -10), Parent = c })
		buy.Activated:Connect(function()
			if State.Get("CratesBlocked") ~= true then
				State.Action("BuyCrate", crate.Id)
			end
		end)
		table.insert(refreshers, function()
			local lines = {}
			for _, outcome in Crates.Odds(crate) do
				table.insert(lines, `{KIND_ICON[outcome.Reward.Kind] or "🎁"} {outcomeText(outcome)} <b>{percent(outcome.Chance)}</b>`)
			end
			odds.Text = table.concat(lines, "\n")
			if State.Get("CratesBlocked") == true then
				Theme.SetButtonText(buy, "Not available in your region")
				Theme.SetButtonColor(buy, Theme.Colors.Gray)
			else
				Theme.SetButtonText(buy, robuxText(product.DeveloperProductId, product.Price))
				Theme.SetButtonColor(buy, Theme.Colors.Green)
			end
		end)
	end
	local note = card(page, 10, Theme.Colors.Orange)
	Theme.Label({ Text = "🎁 Crates also show up for free in the lane now and then - hold E to open one! Eggs go straight into your incubator.", Font = Theme.Font, Size = UDim2.new(1, -20, 1, -20), Position = UDim2.fromOffset(10, 10), StrokeThickness = 1.5, Parent = note })
	RunService.RenderStepped:Connect(function()
		if not page.Visible then
			return
		end
		local angle = os.clock() * 0.8
		for _, camera in spinning do
			camera.CFrame = CFrame.lookAt(Vector3.new(math.sin(angle) * 11, 4, -math.cos(angle) * 11), Vector3.new(0, 0.2, 0))
		end
	end)
	State.OnAttribute("CratesBlocked", refreshAll)
end

--------------------------------------------------------------------------------
-- Skins
--------------------------------------------------------------------------------
local function buildSkins(page: ScrollingFrame)
	local note = card(page, 0, Theme.Colors.Purple)
	Theme.Label({ Text = "🎨 Skins are bought with SPEED ⚡ (you'll be slower until you train it back). They're yours forever, even after rebirths!", Font = Theme.Font, Size = UDim2.new(1, -20, 1, -20), Position = UDim2.fromOffset(10, 10), StrokeThickness = 1.5, Parent = note })
	for order, skin in Config.Skins do
		local c = card(page, order, skin.Trim)
		-- Colour swatch preview of the skin
		local swatch = Theme.new("Frame", { Size = UDim2.new(1, -20, 0, 64), Position = UDim2.fromOffset(10, 10), BackgroundColor3 = skin.Floor, Parent = c }, { Theme.Corner(10), Theme.Stroke(2) })
		for i, color in { skin.FloorAlt, skin.Fence, skin.Trim, skin.Pedestal } do
			Theme.new("Frame", { Size = UDim2.new(0.2, -4, 1, -16), Position = UDim2.new(0.04 + (i - 1) * 0.24, 0, 0, 8), BackgroundColor3 = color, Parent = swatch }, { Theme.Corner(8), Theme.Stroke(1.5) })
		end
		Theme.Label({ Text = string.upper(skin.Name), Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 80), Parent = c })
		local button = Theme.Button({ Text = "", Color = Theme.Colors.Green, Size = UDim2.new(1, -20, 0, 46), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Parent = c })
		button.Activated:Connect(function()
			if State.Data.OwnedSkins[skin.Id] or skin.SpeedCost <= 0 then
				State.Action("EquipSkin", skin.Id)
			else
				State.Action("BuySkin", skin.Id)
			end
		end)
		table.insert(refreshers, function()
			local owned = skin.SpeedCost <= 0 or State.Data.OwnedSkins[skin.Id]
			if State.Data.EquippedSkin == skin.Id then
				Theme.SetButtonText(button, "EQUIPPED")
				Theme.SetButtonColor(button, Theme.Colors.Gray)
			elseif owned then
				Theme.SetButtonText(button, "EQUIP")
				Theme.SetButtonColor(button, Theme.Colors.Blue)
			else
				Theme.SetButtonText(button, "⚡ " .. Format.Number(skin.SpeedCost))
				Theme.SetButtonColor(button, if State.Number("Speed") >= skin.SpeedCost then Theme.Colors.Purple else Theme.Colors.Gray)
			end
		end)
	end
end

--------------------------------------------------------------------------------
-- Items (weapons, traps, base lock)
--------------------------------------------------------------------------------
local KIND_LABEL = { Weapon = "⚔️ WEAPON", Trap = "🪤 TRAP", Lock = "🛡 DEFENSE" }

function buildItems(page: ScrollingFrame)
	local spinning: { { Camera: Camera, Radius: number, Height: number } } = {}
	for order, item in Config.Items do
		local c = card(page, order, item.Color)
		-- A 3D preview of the real model, slowly turning
		local viewport = Theme.new("ViewportFrame", {
			BackgroundColor3 = Color3.fromRGB(25, 25, 40),
			Size = UDim2.fromOffset(60, 60),
			Position = UDim2.fromOffset(8, 6),
			Ambient = Color3.fromRGB(170, 170, 170),
			LightColor = Color3.fromRGB(255, 255, 255),
			LightDirection = Vector3.new(-0.5, -1, 0.8),
			Parent = c,
		}, { Theme.Corner(10) })
		local model = ItemModel.BuildPreview(item)
		-- The item's +Z is "up the item": stand it upright, then centre it on the origin
		local upright = CFrame.Angles(math.rad(-90), 0, 0)
		model:PivotTo(upright)
		local box, size = model:GetBoundingBox()
		model:PivotTo(CFrame.new(-box.Position) * upright)
		model.Parent = viewport
		local radius = math.max(size.X, size.Y, size.Z) * 1.25 + 1
		local camera = Instance.new("Camera")
		camera.FieldOfView = 40
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, -radius), Vector3.zero)
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		table.insert(spinning, { Camera = camera, Radius = radius, Height = 0 })
		Theme.Label({ Text = string.upper(item.Name), TextColor3 = item.Color:Lerp(Color3.new(1, 1, 1), 0.3), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -86, 0, 30), Position = UDim2.fromOffset(74, 8), Parent = c })
		Theme.Label({ Text = KIND_LABEL[item.Kind] or item.Kind, Font = Theme.Font, TextColor3 = Color3.fromRGB(200, 200, 210), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -86, 0, 18), Position = UDim2.fromOffset(74, 38), StrokeThickness = 1, Parent = c })
		Theme.Label({ Text = item.Description, Font = Theme.Font, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -20, 0, 36), Position = UDim2.fromOffset(10, 68), StrokeThickness = 1.2, Parent = c })
		local button = Theme.Button({ Text = "", Color = Theme.Colors.Green, Size = UDim2.new(1, -20, 0, 48), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Parent = c })
		button.Activated:Connect(function()
			local owned = item.Starter or (State.Data.Items and State.Data.Items[item.Id])
			if not owned then
				State.Action("BuyItem", item.Id)
			end
		end)
		table.insert(refreshers, function()
			local owned = item.Starter or (State.Data.Items and State.Data.Items[item.Id])
			if owned then
				Theme.SetButtonText(button, if item.Starter then "FREE ✓ (in hotbar)" else "OWNED ✓ (in hotbar)")
				Theme.SetButtonColor(button, Theme.Colors.Gray)
			else
				Theme.SetButtonText(button, "Buy " .. Format.Money(item.Cost))
				Theme.SetButtonColor(button, if State.Number("Money") >= item.Cost then Theme.Colors.Green else Theme.Colors.Gray)
			end
		end)
	end
	RunService.RenderStepped:Connect(function()
		if not page.Visible then
			return
		end
		local angle = os.clock() * 0.8
		for _, entry in spinning do
			entry.Camera.CFrame = CFrame.lookAt(Vector3.new(math.sin(angle) * entry.Radius, entry.Height, -math.cos(angle) * entry.Radius), Vector3.zero)
		end
	end)
end

function Shop.Open(tab: string?)
	modal:Open()
	selectTab(tab or "Upgrades")
end

function Shop.Init()
	modal = Modal.new("🛒 SHOP", Theme.Colors.Green, Vector2.new(740, 490))
	local body = modal.Body
	selectTab = Modal.Tabs(body, {
		{ Name = "Upgrades", Text = "⚡ Upgrades", Color = Theme.Colors.Purple },
		{ Name = "Passes", Text = "🎟️ Passes", Color = Theme.Colors.Orange },
		{ Name = "Crates", Text = "🎁 Crates", Color = Theme.Colors.Yellow },
		{ Name = "Items", Text = "⚔️ Items", Color = Theme.Colors.Red },
		{ Name = "Skins", Text = "🎨 Skins", Color = Theme.Colors.Pink },
	}, function(name)
		for pageName, page in pages do
			page.Visible = pageName == name
		end
		refreshAll()
	end)
	buildUpgrades(newPage("Upgrades", body, 2, 190))
	buildPasses(newPage("Passes", body, 2, 160))
	buildCrates(newPage("Crates", body, 2, 290), body)
	buildItems(newPage("Items", body, 2, 175))
	buildSkins(newPage("Skins", body, 3, 180))

	for _, name in { "Money", "Speed", "SpeedMultLevel", "TreadmillLevel", "SpeedPassMultiplier", "Income", "Rebirths", "Expansions", "Floors", "IndexBonus", "IncubatorSpeed", "IncubatorSize" } do
		State.OnAttribute(name, function()
			if modal:IsOpen() then
				refreshAll()
			end
		end)
	end
	State.Changed:Connect(refreshAll)

	-- Shop stalls in the hub: walk onto a glowing circle (or press E at the counter) to open that
	-- stall's tab. Walking off closes it again.
	task.spawn(function()
		local hub = workspace:WaitForChild("Map"):WaitForChild("Hub")
		local player = Players.LocalPlayer :: Player
		local stalls: { { Glow: BasePart, Tab: string, Inside: boolean } } = {}
		local autoOpened = false
		local function addStall(stall: Instance)
			local tab = stall:GetAttribute("ShopTab")
			if type(tab) ~= "string" then
				return
			end
			local glow = stall:WaitForChild("Glow") :: BasePart
			local promptPart = stall:WaitForChild("PromptPart")
			table.insert(stalls, { Glow = glow, Tab = tab, Inside = false })
			local proximity = Theme.new("ProximityPrompt", {
				ActionText = "Open",
				ObjectText = stall.Name,
				HoldDuration = 0,
				MaxActivationDistance = 12,
				RequiresLineOfSight = false,
				Parent = promptPart,
			})
			proximity.Triggered:Connect(function()
				Shop.Open(tab)
			end)
		end
		for _, child in hub:GetChildren() do
			task.spawn(addStall, child)
		end
		while true do
			task.wait(0.15)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			for _, stall in stalls do
				local inside = false
				if root then
					local offset = root.Position - stall.Glow.Position
					inside = Vector2.new(offset.X, offset.Z).Magnitude < stall.Glow.Size.Y / 2 and math.abs(offset.Y) < 8
				end
				if inside and not stall.Inside then
					Shop.Open(stall.Tab)
					autoOpened = true
				elseif not inside and stall.Inside and autoOpened then
					modal:Close()
					autoOpened = false
				end
				stall.Inside = inside
			end
		end
	end)
end

return Shop
