--[[
	Donut Index: every donut in the game, grouped by biome and by the box it comes out of (with the
	chance of each box, and of each donut inside its box), with 3D previews. Donuts you haven't
	found yet show as black silhouettes named "???".

	Rewards: every donut you've found can be claimed once for cash. Epic and rarer donuts let you
	pick a permanent treadmill speed bonus instead. "Claim All" (top right) claims every reward at
	once: the speed bonus where a donut offers one (until the bonus is capped), cash for the rest. The dots under a donut show which mutations
	of it you've found.

	Global rarity scale: Legendary and rarer donuts show how many times they've spawned and been
	found in the WHOLE game (every server), and what share of all spawns that is. The line at the
	top does the same for every mutation. (StatsService on the server keeps the counts.)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local Boxes = require(Shared.Boxes)
local Donuts = require(Shared.Donuts)
local Rarities = require(Shared.Rarities)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local DonutModel = require(Shared.DonutModel)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local State = require(script.Parent.Parent.State)

local Index = {}

type Card = {
	Viewport: ViewportFrame,
	Name: TextLabel,
	Info: TextLabel,
	Rarity: TextLabel,
	Global: TextLabel,
	Dots: { [string]: Frame },
	Cash: TextButton,
	Speed: TextButton?,
	Status: TextLabel,
}

local modal: Modal.Modal
local pages: { [number]: ScrollingFrame } = {}
local cards: { [string]: Card } = {}
local counter: TextLabel
local claimAll: TextButton
local legend: TextLabel
local selectPage: (string) -> ()
local currentPage = 1

-- The tabs: five biomes each
local PAGES = { { 1, 6 }, { 7, 12 }, { 13, 17 } }

type Counts = { [string]: { number } }
local globalStats: { D: Counts, M: Counts }? = nil

-- Share of all spawns, as a readable percentage ("0.0031%")
local function percent(part: number, total: number): string
	if total <= 0 or part <= 0 then
		return "0%"
	end
	local p = part / total * 100
	return if p >= 1 then string.format("%.1f%%", p) elseif p >= 0.01 then string.format("%.2f%%", p) else string.format("%.2g%%", p)
end

-- Donuts found but not claimed yet (the HUD shows this as a badge on the Index button).
function Index.UnclaimedCount(): number
	local discovered: { [string]: boolean } = State.Data.Discovered or {}
	local claims: { [string]: string } = State.Data.IndexClaims or {}
	local count = 0
	for id in discovered do
		if Donuts.ById[id] and not claims[id] then
			count += 1
		end
	end
	return count
end

local function preview(parent: Instance, donut: Donuts.Donut): ViewportFrame
	local viewport = Theme.new("ViewportFrame", {
		BackgroundColor3 = Color3.fromRGB(25, 25, 40),
		Size = UDim2.new(1, -12, 0, 96),
		Position = UDim2.fromOffset(6, 6),
		Ambient = Color3.fromRGB(170, 170, 170),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-0.5, -1, 0.8),
		Parent = parent,
	}, { Theme.Corner(10) })
	local model = DonutModel.Build(donut, { NoEffects = true })
	model.Parent = viewport
	local top = (model:GetAttribute("Top") :: number?) or 2.5
	local bottom = (model:GetAttribute("Bottom") :: number?) or 2.5
	local centerY = (top - bottom) / 2
	local height = top + bottom
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(2.2, centerY + 1, -(height * 1.35 + 4)), Vector3.new(0, centerY, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport
end

local function refresh()
	local discovered: { [string]: boolean } = State.Data.Discovered or {}
	local claims: { [string]: string } = State.Data.IndexClaims or {}
	local mutations: { [string]: { [string]: boolean } } = State.Data.DiscoveredMutations or {}
	local found = 0
	for _ in discovered do
		found += 1
	end
	local stats = globalStats
	local totalSpawns = 0
	if stats then
		for _, counts in stats.D do
			totalSpawns += counts[1] or 0
		end
	end
	-- While a Luck Event runs, show the boosted odds too (Roblox wants boosted odds shown when the
	-- boost was paid for).
	local luckEndsAt = workspace:GetAttribute("LuckEndsAt")
	local lucky = type(luckEndsAt) == "number" and luckEndsAt > workspace:GetServerTimeNow()
	for id, card in cards do
		local donut = Donuts.ById[id]
		local rarity = Rarities.Get(donut.Rarity)
		local cash = Economy.IndexCashReward(id)
		local speed = Economy.IndexSpeedReward(id)
		local chance = if not Donuts.Spawnable(donut) then "Admin panel only" else `{string.format("%.2g", Donuts.Chance(donut) * 100)}% of box`
		card.Rarity.Text = `{rarity.Id} • {chance}`
		local counts = stats and stats.D[id]
		if rarity.Order >= Config.GlobalStats.ShowFromRarity and Donuts.Spawnable(donut) then
			local spawned = if counts then counts[1] or 0 else 0
			local gotHome = if counts then counts[2] or 0 else 0
			card.Global.Text = if stats then `🌍 {Format.Number(spawned)} spawned ({percent(spawned, totalSpawns)}) • {Format.Number(gotHome)} found` else "🌍 loading..."
		else
			card.Global.Text = ""
		end
		for mutationId, dot in card.Dots do
			local has = mutations[id] and mutations[id][mutationId]
			dot.BackgroundTransparency = if has then 0 else 0.75
		end
		if discovered[id] then
			card.Viewport.ImageColor3 = Color3.new(1, 1, 1)
			card.Name.Text = donut.Name
			card.Info.Text = `{Format.Money(donut.Income)}/s`
		else
			card.Viewport.ImageColor3 = Color3.new(0, 0, 0)
			card.Name.Text = "???"
			card.Info.Text = "Not found yet"
		end
		local claimed = claims[id]
		local canClaim = discovered[id] and not claimed
		card.Cash.Visible = canClaim == true
		if card.Speed then
			card.Speed.Visible = canClaim == true
		end
		card.Status.Visible = not canClaim
		if claimed == "Speed" then
			card.Status.Text = `✓ +{speed or 0}% speed`
			card.Status.TextColor3 = Color3.fromRGB(200, 160, 255)
		elseif claimed then
			card.Status.Text = `✓ Claimed {Format.Money(cash)}`
			card.Status.TextColor3 = Theme.Colors.Money
		else
			card.Status.Text = if speed then `🎁 {Format.Money(cash)} or +{speed}% speed` else `🎁 {Format.Money(cash)}`
			card.Status.TextColor3 = Color3.fromRGB(200, 200, 210)
		end
	end
	local bonus = State.Number("IndexBonus")
	local unclaimed = Index.UnclaimedCount()
	counter.Text = `Discovered {found}/{#Donuts.List}   •   📖 Speed bonus: +{bonus}%   •   🎁 {unclaimed} to claim`
	Theme.SetButtonText(claimAll, if unclaimed > 0 then `🎁 Claim All ({unclaimed})` else "🎁 Claim All")
	Theme.SetButtonColor(claimAll, if unclaimed > 0 then Theme.Colors.Green else Theme.Colors.Gray)
	-- Mutations: chance per spawn + how many were found in the whole game
	local parts = {}
	for _, mutation in Rarities.Mutations do
		if mutation.Order > 0 then
			local counts = stats and stats.M[mutation.Id]
			local foundCount = if counts then counts[2] or 0 else 0
			local boosted = if lucky and not mutation.EventOnly then ` → 🍀 {percent(mutation.Chance * Config.LuckEvent.MutationLuck, 1)}` else ""
			local chance = if mutation.EventOnly then "⚡ Eternal Storm only" else percent(mutation.Chance, 1)
			table.insert(parts, `<font color="#{mutation.Color:ToHex()}">{mutation.Id}</font> {chance}{boosted} ({if stats then Format.Number(foundCount) else "?"} found)`)
		end
	end
	legend.Text = (if lucky then `🍀 Luck Event: Epic & Legendary boxes x{Config.LuckEvent.RarityLuck}!  ` else "") .. "🌍 " .. table.concat(parts, "  ")
end

local function fetchStats()
	local ok, result = pcall(function()
		return Remotes.Function("GetGlobalStats"):InvokeServer()
	end)
	if ok and type(result) == "table" and type(result.D) == "table" and type(result.M) == "table" then
		globalStats = result
		refresh()
	end
end

local function buildCard(grid: Instance, donut: Donuts.Donut, order: number)
	local rarity = Rarities.Get(donut.Rarity)
	local cardFrame = Theme.new("Frame", { BackgroundColor3 = Theme.Colors.PanelLight, LayoutOrder = order, Parent = grid }, {
		Theme.Corner(12),
		Theme.Stroke(3, rarity.Color),
	})
	local viewport = preview(cardFrame, donut)
	local rarityLabel = Theme.Label({ Text = rarity.Id, TextColor3 = rarity.Color, Font = Theme.Font, Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromOffset(4, 104), StrokeThickness = 1.5, Parent = cardFrame })
	local nameLabel = Theme.Label({ Text = "", Font = Theme.Font, Size = UDim2.new(1, -8, 0, 26), Position = UDim2.fromOffset(4, 122), StrokeThickness = 1.5, Parent = cardFrame })
	local info = Theme.Label({ Text = "", Font = Theme.Font, TextColor3 = Theme.Colors.Money, Size = UDim2.new(1, -8, 0, 17), Position = UDim2.fromOffset(4, 148), StrokeThickness = 1.2, Parent = cardFrame })
	local global = Theme.Label({ Text = "", Font = Theme.Font, TextColor3 = Color3.fromRGB(170, 220, 255), Size = UDim2.new(1, -8, 0, 15), Position = UDim2.fromOffset(4, 166), StrokeThickness = 1, Parent = cardFrame })
	-- Mutation dots
	local dotRow = Theme.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 14), Position = UDim2.fromOffset(4, 185), Parent = cardFrame }, {
		Theme.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local dots: { [string]: Frame } = {}
	for _, mutation in Rarities.Mutations do
		if mutation.Order > 0 then
			dots[mutation.Id] = Theme.new("Frame", { Size = UDim2.fromOffset(14, 14), BackgroundColor3 = mutation.Color, BackgroundTransparency = 0.75, LayoutOrder = mutation.Order, Parent = dotRow }, {
				Theme.Corner(7),
				Theme.Stroke(1.5),
			})
		end
	end
	-- Reward buttons
	local speed = Economy.IndexSpeedReward(donut.Id)
	local cash = Theme.Button({ Text = "💵 " .. Format.Money(Economy.IndexCashReward(donut.Id)), Color = Theme.Colors.Green, Size = UDim2.new(if speed then 0.5 else 1, -8, 0, 32), Position = UDim2.new(0, 5, 1, -38), Parent = cardFrame })
	cash.Activated:Connect(function()
		State.Action("ClaimIndex", { DonutId = donut.Id, Kind = "Cash" })
	end)
	local speedButton: TextButton? = nil
	if speed then
		local button = Theme.Button({ Text = `⚡ +{speed}%`, Color = Theme.Colors.Purple, Size = UDim2.new(0.5, -8, 0, 32), Position = UDim2.new(0.5, 3, 1, -38), Parent = cardFrame })
		button.Activated:Connect(function()
			State.Action("ClaimIndex", { DonutId = donut.Id, Kind = "Speed" })
		end)
		speedButton = button
	end
	local status = Theme.Label({ Text = "", Font = Theme.Font, Size = UDim2.new(1, -8, 0, 26), Position = UDim2.new(0, 4, 1, -34), StrokeThickness = 1.2, Parent = cardFrame })
	cards[donut.Id] = { Viewport = viewport, Name = nameLabel, Info = info, Rarity = rarityLabel, Global = global, Dots = dots, Cash = cash, Speed = speedButton, Status = status }
end

-- How a box is described over its donuts: "📦 EPIC DONUT BOX • 25% of boxes • opens in 10m"
local function boxTitle(biome: number, tier: Boxes.Tier): string
	local chance = Boxes.TierChance(biome, tier.Id)
	local share = if chance >= 1 then "every box" else `{math.floor(chance * 1000 + 0.5) / 10}% of boxes`
	return `📦 {string.upper(tier.Name)} • {share} • opens in {Format.Duration(Boxes.HatchSeconds(tier.Id, "Small"))}`
end

-- Build one tab's page (previews are only built the first time you look at it).
local function buildPage(pageId: number)
	if pages[pageId] then
		return
	end
	local scroll = Theme.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 104),
		Size = UDim2.new(1, 0, 1, -104),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 8,
		Visible = false,
		Parent = modal.Body,
	}, {
		Theme.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		Theme.new("UIPadding", { PaddingRight = UDim.new(0, 12), PaddingLeft = UDim.new(0, 2), PaddingBottom = UDim.new(0, 10) }),
	})
	pages[pageId] = scroll
	local range = PAGES[pageId]
	local order = 0
	local function section(title: string, color: Color3, size: number): Frame
		order += 1
		local frame = Theme.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = scroll })
		Theme.Label({ Text = title, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, size), Parent = frame })
		return frame
	end
	local function grid(parent: Instance, y: number): Frame
		return Theme.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = parent }, {
			Theme.new("UIGridLayout", { CellSize = UDim2.fromOffset(170, 242), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
	end
	for biome = range[1], range[2] do
		local area = Areas.List[biome]
		if not area then
			continue
		end
		local escape = Economy.EscapeSpeed(area.Id)
		local need = if escape > 0 then `⚡{Format.Number(escape)} to escape` else "any speed escapes"
		section(`BIOME {area.Id} • {string.upper(area.Name)} • {need}`, area.Trim:Lerp(Color3.new(1, 1, 1), 0.3), 32)
		for _, tier in Boxes.TiersFor(biome) do
			local list = Donuts.ByBox[biome] and Donuts.ByBox[biome][tier.Id]
			if list and #list > 0 then
				local frame = section(boxTitle(biome, tier), tier.Color:Lerp(Color3.new(1, 1, 1), 0.25), 24)
				local cells = grid(frame, 28)
				for index, donut in list do
					buildCard(cells, donut, index)
				end
			end
		end
		-- donuts only the admin panel makes
		local extra = {}
		local inBiome: { Donuts.Donut } = Donuts.ByArea[biome] or {}
		for _, donut in inBiome do
			if not donut.Box then
				table.insert(extra, donut)
			end
		end
		if #extra > 0 then
			local frame = section("🛠 ADMIN PANEL ONLY", Rarities.Get("Admin").Color, 24)
			local cells = grid(frame, 28)
			for index, donut in extra do
				buildCard(cells, donut, index)
			end
		end
	end
end

function Index.Open()
	modal:Open()
end

function Index.Init()
	modal = Modal.new("📖 DONUT INDEX", Theme.Colors.Blue, Vector2.new(780, 540))
	counter = Theme.Label({ Text = "", Font = Theme.Font, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -196, 0, 24), Position = UDim2.fromOffset(0, 50), Parent = modal.Body })
	claimAll = Theme.Button({ Name = "ClaimAll", Text = "🎁 Claim All", Color = Theme.Colors.Gray, Size = UDim2.fromOffset(186, 28), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, 47), Parent = modal.Body })
	claimAll.Activated:Connect(function()
		if Index.UnclaimedCount() > 0 then
			State.Action("ClaimIndexAll")
		end
	end)
	legend = Theme.Label({ Text = "", Font = Theme.Font, RichText = true, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 76), StrokeThickness = 1.2, Parent = modal.Body })
	local tabs = {}
	for pageId, range in PAGES do
		table.insert(tabs, { Name = tostring(pageId), Text = `Biomes {range[1]}-{range[2]}`, Color = Areas.List[range[1]].Trim })
	end
	selectPage = Modal.Tabs(modal.Body, tabs, function(name)
		currentPage = tonumber(name) or 1
		buildPage(currentPage)
		for pageId, page in pages do
			page.Visible = pageId == currentPage
		end
		refresh()
	end)
	modal.OnOpen = function()
		selectPage(tostring(currentPage))
		task.spawn(fetchStats)
	end
	-- Keep the global numbers fresh while the Index is open
	task.spawn(function()
		while true do
			task.wait(60)
			if modal:IsOpen() then
				fetchStats()
			end
		end
	end)
	State.Changed:Connect(refresh)
	State.OnAttribute("IndexBonus", function()
		if modal:IsOpen() then
			refresh()
		end
	end)
	workspace:GetAttributeChangedSignal("LuckEndsAt"):Connect(function()
		if modal:IsOpen() then
			refresh()
		end
	end)
end

return Index
