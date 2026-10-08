--[[
	Donut Index: every donut in the game, one biome at a time (the arrows on the biome's banner
	flip between biomes), laid out like the boxes they come from:

	  [ the box and its chance ]  ->  [ donut ] [ donut ] [ donut ] ...

	one row per box the biome's Domer guards, with the chance of that box and of each donut inside
	it; then two rows every biome shares: box sizes and box mutations, with their chances (and, for
	mutations, how many the whole game has found). The window's title counts the donuts you've
	found: "Index (12/88)".

	A card: the donut's name on a dark strip, the donut in 3D on studs in its box's colour (a dark
	see-through silhouette called "???" until you find it), then its rarity and chance, what it
	earns, dots for the mutations of it you've found, and its reward.

	Rewards: every donut you've found can be claimed once for cash. Epic and rarer donuts let you
	pick a permanent treadmill speed bonus instead. "Claim All" claims every reward at once: the
	speed bonus where a donut offers one (until the bonus is capped), cash for the rest.

	Global rarity scale: Legendary and rarer donuts show how many times they've spawned and been
	found in the WHOLE game (every server), and what share of all spawns that is (StatsService on
	the server keeps the counts). Each biome's banner wears its own colours and details
	(UI/IndexThemes).

	A page is built the first time you look at it, and only the last two you looked at are kept.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local Boxes = require(Shared.Boxes)
local BoxModel = require(Shared.BoxModel)
local Donuts = require(Shared.Donuts)
local Rarities = require(Shared.Rarities)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local DonutModel = require(Shared.DonutModel)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local IndexThemes = require(script.Parent.IndexThemes)
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
type Page = {
	Frame: ScrollingFrame,
	Donuts: { string },
	Boxes: { { Label: TextLabel, Tier: Boxes.Tier } },
	Mutations: { [string]: TextLabel },
}

local WIDTH, HEIGHT = 880, 600
local CARD = Vector2.new(140, 226) -- a donut card
local HEAD, BODY = 26, 104 -- its name strip and its picture
local SMALL = Vector2.new(140, 168) -- a size or mutation card
local LEFT = 150 -- the box's panel at the start of a row
local GAP = 8
local KEEP = 2 -- pages kept built

local modal: Modal.Modal
local pages: { [number]: Page } = {}
local recent: { number } = {}
local cards: { [string]: Card } = {}
local summary: TextLabel
local claimAll: TextButton
local banner: Frame
local bannerTitle: TextLabel
local bannerInfo: TextLabel
local bannerBack: Frame
local current = 1

type Counts = { [string]: { number } }
local globalStats: { D: Counts, M: Counts }? = nil

local STRIP_TOP = Color3.fromRGB(62, 62, 62)
local STRIP_BOTTOM = Color3.fromRGB(36, 36, 36)
local ARROW = Color3.fromRGB(20, 215, 100)

-- Share of all spawns, as a readable percentage ("0.0031%")
local function percent(part: number, total: number): string
	if total <= 0 or part <= 0 then
		return "0%"
	end
	local p = part / total * 100
	return if p >= 1 then string.format("%.1f%%", p) elseif p >= 0.01 then string.format("%.2f%%", p) else string.format("%.2g%%", p)
end

local function lucky(): boolean
	local luckEndsAt = workspace:GetAttribute("LuckEndsAt")
	return type(luckEndsAt) == "number" and luckEndsAt > workspace:GetServerTimeNow()
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

--------------------------------------------------------------------------------
-- Pieces
--------------------------------------------------------------------------------
local function label(props: { [string]: any }): TextLabel
	if props.Font == nil then
		props.Font = Theme.Font
	end
	return Theme.Label(props)
end

-- A model in a see-through viewport, looked at from the front.
local function viewport(parent: Instance, model: Model, top: number, bottom: number, size: UDim2, position: UDim2): ViewportFrame
	local view = Theme.new("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = size,
		Position = position,
		Ambient = Color3.fromRGB(170, 170, 170),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-0.5, -1, 0.8),
		ZIndex = 3,
		Parent = parent,
	})
	model.Parent = view
	local centerY = (top - bottom) / 2
	local height = top + bottom
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(2.2, centerY + 1, -(height * 1.35 + 4)), Vector3.new(0, centerY, 0))
	camera.Parent = view
	view.CurrentCamera = camera
	return view
end

-- A card like the reference: the dark name strip (with two slanted marks at its left), and under
-- it a picture area on studs in `color`. Returns (card, name label, picture area).
local function cardFrame(parent: Instance, order: number, size: Vector2, color: Color3): (Frame, TextLabel, Frame)
	local card = Theme.new("Frame", {
		Name = "Card",
		BackgroundColor3 = Theme.Colors.Panel,
		Size = UDim2.fromOffset(size.X, size.Y),
		LayoutOrder = order,
		Parent = parent,
	}, {
		Theme.Corner(6),
		Theme.Stroke(2.5),
	})
	local strip = Theme.new("Frame", {
		Name = "Strip",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 0, HEAD),
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = card,
	}, {
		Theme.Corner(6),
		Theme.Gradient(STRIP_TOP, STRIP_BOTTOM),
	})
	for i, x in { 8, 20 } do
		Theme.new("Frame", {
			Name = "Mark" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, x, 0.5, 0),
			Size = UDim2.fromOffset(7, HEAD + 10),
			Rotation = 20,
			BackgroundColor3 = Color3.fromRGB(120, 120, 120),
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = strip,
		})
	end
	local name = label({ Name = "CardName", Text = "", Size = UDim2.new(1, -44, 1, -6), Position = UDim2.fromOffset(30, 3), StrokeThickness = 2, ZIndex = 3, Parent = strip })
	local body = Theme.new("Frame", {
		Name = "Picture",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(0, HEAD),
		Size = UDim2.new(1, 0, 0, BODY),
		ZIndex = 2,
		Parent = card,
	})
	Theme.Studs(body, Vector2.new(size.X, BODY), { Cell = 20, Transparency = 0.72, ZIndex = 2 })
	return card, name, body
end

-- The green arrow between a box and what comes out of it.
local function arrow(parent: Instance, x: number)
	local holder = Theme.new("Frame", { Name = "Arrow", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, x, 0.5, 0), Size = UDim2.fromOffset(40, 40), Parent = parent })
	Theme.new("Frame", { Name = "Shaft", BackgroundColor3 = ARROW, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 12), Size = UDim2.fromOffset(22, 16), Parent = holder }, { Theme.Stroke(2.5) })
	local tip = Theme.new("Frame", { Name = "Tip", BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.fromOffset(18, 0), Size = UDim2.fromOffset(22, 40), Parent = holder })
	Theme.new("Frame", { BackgroundColor3 = ARROW, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(0, 20), Size = UDim2.fromOffset(27, 27), Rotation = 45, Parent = tip }, { Theme.Stroke(2.5) })
	-- (covers the shaft's outline where it meets the tip)
	Theme.new("Frame", { BackgroundColor3 = ARROW, BorderSizePixel = 0, Position = UDim2.fromOffset(16, 13.5), Size = UDim2.fromOffset(8, 13), ZIndex = 2, Parent = holder })
end

-- One row: the box (or a title) on the left, the arrow, and the cards. Returns (left panel, cards).
local function row(page: ScrollingFrame, order: number, name: string, cell: Vector2?): (Frame, Frame)
	local frame = Theme.new("Frame", {
		Name = name,
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.08,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Parent = page,
	}, {
		Theme.Corner(6),
		Theme.Stroke(3),
		Theme.new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
	})
	local left = Theme.new("Frame", { Name = "Left", BackgroundTransparency = 1, Size = UDim2.new(0, LEFT, 1, 0), Parent = frame })
	arrow(frame, LEFT + 6)
	local grid = Theme.new("Frame", {
		Name = "Cards",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(LEFT + 56, 0),
		Size = UDim2.new(1, -(LEFT + 56), 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = frame,
	}, {
		Theme.new("UIGridLayout", { CellSize = UDim2.fromOffset((cell or CARD).X, (cell or CARD).Y), CellPadding = UDim2.fromOffset(GAP, GAP), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	return left, grid
end

--------------------------------------------------------------------------------
-- Donut cards
--------------------------------------------------------------------------------
local function donutCard(grid: Instance, donut: Donuts.Donut, order: number, color: Color3)
	local rarity = Rarities.Get(donut.Rarity)
	local card, name, body = cardFrame(grid, order, CARD, color)
	card.Name = donut.Id
	local model = DonutModel.Build(donut, { NoEffects = true })
	local view = viewport(body, model, (model:GetAttribute("Top") :: number?) or 2.5, (model:GetAttribute("Bottom") :: number?) or 2.5, UDim2.fromScale(1, 1), UDim2.new())
	view.Name = "Donut"
	local foot = Theme.new("Frame", { Name = "Footer", BackgroundTransparency = 1, Position = UDim2.fromOffset(4, HEAD + BODY + 2), Size = UDim2.new(1, -8, 1, -(HEAD + BODY + 6)), Parent = card })
	local rarityLabel = label({ Name = "Rarity", Text = "", TextColor3 = rarity.Color, Size = UDim2.new(1, 0, 0, 16), StrokeThickness = 1.5, Parent = foot })
	local info = label({ Name = "Info", Text = "", TextColor3 = Theme.Colors.Money, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 17), StrokeThickness = 1.5, Parent = foot })
	local global = label({ Name = "Global", Text = "", TextColor3 = Color3.fromRGB(170, 220, 255), Size = UDim2.new(1, 0, 0, 12), Position = UDim2.fromOffset(0, 34), StrokeThickness = 1, Parent = foot })
	-- the mutations of it you've found
	local dotRow = Theme.new("Frame", { Name = "Dots", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 10), Position = UDim2.fromOffset(0, 48), Parent = foot }, {
		Theme.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local dots: { [string]: Frame } = {}
	for _, mutation in Rarities.Mutations do
		if mutation.Order > 0 then
			dots[mutation.Id] = Theme.new("Frame", { Name = mutation.Id, Size = UDim2.fromOffset(10, 10), BackgroundColor3 = mutation.Color, BackgroundTransparency = 0.75, LayoutOrder = mutation.Order, Parent = dotRow }, {
				Theme.Corner(5),
				Theme.Stroke(1.2),
			})
		end
	end
	-- its reward
	local speed = Economy.IndexSpeedReward(donut.Id)
	local cash = Theme.Button({ Name = "ClaimCash", Text = Format.Money(Economy.IndexCashReward(donut.Id)), Color = Theme.Colors.Green, Size = UDim2.new(if speed then 0.5 else 1, -2, 0, 26), Position = UDim2.new(0, 0, 1, -27), Parent = foot })
	cash.Activated:Connect(function()
		State.Action("ClaimIndex", { DonutId = donut.Id, Kind = "Cash" })
	end)
	local speedButton: TextButton? = nil
	if speed then
		local button = Theme.Button({ Name = "ClaimSpeed", Text = `+{speed}%`, Color = Theme.Colors.Purple, Size = UDim2.new(0.5, -2, 0, 26), Position = UDim2.new(0.5, 2, 1, -27), Parent = foot })
		button.Activated:Connect(function()
			State.Action("ClaimIndex", { DonutId = donut.Id, Kind = "Speed" })
		end)
		speedButton = button
	end
	local status = label({ Name = "Status", Text = "", Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 1, -25), StrokeThickness = 1.5, Parent = foot })
	cards[donut.Id] = { Viewport = view, Name = name, Info = info, Rarity = rarityLabel, Global = global, Dots = dots, Cash = cash, Speed = speedButton, Status = status }
end

-- The left of a box's row: the box itself, its name, how often it turns up and how long it takes.
local function boxPanel(left: Frame, tier: Boxes.Tier): TextLabel
	local model = BoxModel.Build(tier.Id, "Small")
	local top = (model:GetAttribute("Top") :: number?) or 3
	local view = viewport(left, model, top, 0, UDim2.fromOffset(LEFT, 112), UDim2.fromOffset(0, 4))
	view.Name = "Box"
	label({ Name = "BoxName", Text = Format.Plain(tier.Name), Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 118), StrokeThickness = 2.5, Parent = left })
	local chance = label({ Name = "Chance", Text = "", TextColor3 = Theme.Colors.Gold, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 144), StrokeThickness = 2, Parent = left })
	label({ Name = "Opens", Text = `Opens in {Format.Duration(Boxes.HatchSeconds(tier.Id, "Small"))}`, TextColor3 = Color3.fromRGB(220, 220, 220), Size = UDim2.new(1, 0, 0, 15), Position = UDim2.fromOffset(0, 164), StrokeThickness = 1.5, Parent = left })
	return chance
end

-- "70% of boxes", with the boosted chance while a Luck Event runs.
local function boxChance(biome: number, tier: Boxes.Tier, isLucky: boolean): string
	local chance = Boxes.TierChance(biome, tier.Id)
	if chance >= 1 then
		return "Every box"
	end
	local text = `{math.floor(chance * 1000 + 0.5) / 10}% of boxes`
	if isLucky then
		text ..= ` ({math.floor(Boxes.TierChance(biome, tier.Id, Config.LuckEvent.RarityLuck) * 1000 + 0.5) / 10}% luck)`
	end
	return text
end

-- A title on the left of a row that isn't a box (sizes, mutations, crafted...).
local function titlePanel(left: Frame, title: string, detail: string, color: Color3)
	label({ Name = "Title", Text = title, TextColor3 = color, TextWrapped = true, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(0, 20), StrokeThickness = 2.5, Parent = left })
	label({ Name = "Detail", Text = detail, TextColor3 = Color3.fromRGB(225, 225, 225), TextWrapped = true, Size = UDim2.new(1, 0, 0, 48), Position = UDim2.fromOffset(0, 84), StrokeThickness = 1.5, Parent = left })
end

-- A smaller card for a box size or a mutation: a big word on studs, and lines under it.
local function smallCard(grid: Instance, order: number, title: string, color: Color3, big: string, lines: { string }): { TextLabel }
	local card, name, body = cardFrame(grid, order, SMALL, color)
	card.Name = title
	name.Text = title
	label({ Name = "Big", Font = Theme.Title, Text = big, Size = UDim2.new(1, -16, 0, 50), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), StrokeThickness = 3.5, ZIndex = 3, Parent = body })
	local out = {}
	for i, text in lines do
		table.insert(out, label({ Name = "Line" .. i, Text = text, TextColor3 = if i == 1 then Theme.Colors.Gold else Color3.fromRGB(225, 225, 225), Size = UDim2.new(1, -8, 0, 16), Position = UDim2.fromOffset(4, HEAD + BODY + 2 + (i - 1) * 18), StrokeThickness = 1.5, Parent = card }))
	end
	return out
end

--------------------------------------------------------------------------------
-- Pages
--------------------------------------------------------------------------------
local function buildPage(biome: number): Page
	local scroll = Theme.new("ScrollingFrame", {
		Name = "Biome" .. biome,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 112),
		Size = UDim2.new(1, 0, 1, -112),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 8,
		Visible = false,
		Parent = modal.Body,
	}, {
		Theme.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		Theme.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingRight = UDim.new(0, 14), PaddingLeft = UDim.new(0, 4), PaddingBottom = UDim.new(0, 10) }),
	})
	local page: Page = { Frame = scroll, Donuts = {}, Boxes = {}, Mutations = {} }
	local order = 0
	local function add(list: { Donuts.Donut }, grid: Frame, color: Color3)
		for i, donut in list do
			donutCard(grid, donut, i, color)
			table.insert(page.Donuts, donut.Id)
		end
	end
	-- a row for each box this biome's Domer guards
	for _, tier in Boxes.TiersFor(biome) do
		local list = Donuts.ByBox[biome] and Donuts.ByBox[biome][tier.Id]
		if list and #list > 0 then
			order += 1
			local left, grid = row(scroll, order, "Box" .. tier.Id)
			table.insert(page.Boxes, { Label = boxPanel(left, tier), Tier = tier })
			add(list, grid, tier.Color:Lerp(Color3.new(1, 1, 1), 0.2))
		end
	end
	-- donuts crafted at the Cosmic Forge (limited time), and donuts only the admin panel makes
	local crafted, extra = {}, {}
	local inBiome: { Donuts.Donut } = Donuts.ByArea[biome] or {}
	for _, donut in inBiome do
		if donut.Crafted then
			table.insert(crafted, donut)
		elseif not donut.Box then
			table.insert(extra, donut)
		end
	end
	if #crafted > 0 then
		order += 1
		local left, grid = row(scroll, order, "Crafted")
		titlePanel(left, "Cosmic Forge", "Crafted from meteor shards. Limited time!", Color3.fromRGB(200, 140, 255))
		add(crafted, grid, Color3.fromRGB(120, 70, 200))
	end
	if #extra > 0 then
		order += 1
		local left, grid = row(scroll, order, "AdminOnly")
		titlePanel(left, "Admin Only", "Only the admin panel makes these", Rarities.Get("Admin").Color)
		add(extra, grid, Color3.fromRGB(150, 150, 160))
	end
	-- box sizes (the same in every biome)
	order += 1
	local sizeLeft, sizeGrid = row(scroll, order, "Sizes", SMALL)
	titlePanel(sizeLeft, "Box Sizes", "Bigger boxes hold bigger donuts that earn more, but you carry them slower", Color3.fromRGB(255, 200, 120))
	local totalWeight = 0
	for _, size in Boxes.Sizes do
		totalWeight += size.Weight
	end
	for i, size in Boxes.Sizes do
		local donutSize = Rarities.Size(size.DonutSize)
		smallCard(sizeGrid, i, size.Name, Color3.fromRGB(150, 120, 90):Lerp(Color3.fromRGB(255, 190, 80), (i - 1) / 3), `x{donutSize.Multiplier}`, {
			percent(size.Weight, totalWeight),
			if size.CarrySpeed < 1 then `{math.floor((1 - size.CarrySpeed) * 100 + 0.5)}% slower to carry` else "Normal speed",
		})
	end
	-- box mutations: any box can be one
	order += 1
	local mutationLeft, mutationGrid = row(scroll, order, "Mutations", SMALL)
	titlePanel(mutationLeft, "Box Mutations", "Any box can come out mutated: its donut earns that many times more", Color3.fromRGB(255, 150, 230))
	for _, mutation in Rarities.Mutations do
		if mutation.Order > 0 then
			local lines = smallCard(mutationGrid, mutation.Order, mutation.Id, mutation.Color:Lerp(Color3.new(0, 0, 0), 0.15), `x{mutation.Multiplier}`, { "", "" })
			page.Mutations[mutation.Id] = lines[1]
			page.Mutations[mutation.Id .. "Found"] = lines[2]
		end
	end
	return page
end

-- Forget the pages looked at longest ago (their cards go too).
local function trim()
	while #recent > KEEP do
		local old = table.remove(recent, 1) :: number
		local page = pages[old]
		if page then
			for _, id in page.Donuts do
				cards[id] = nil
			end
			page.Frame:Destroy()
			pages[old] = nil
		end
	end
end

--------------------------------------------------------------------------------
-- Refresh
--------------------------------------------------------------------------------
local function refresh()
	local discovered: { [string]: boolean } = State.Data.Discovered or {}
	local claims: { [string]: string } = State.Data.IndexClaims or {}
	local mutations: { [string]: { [string]: boolean } } = State.Data.DiscoveredMutations or {}
	local found, claimed = 0, 0
	for id in discovered do
		if Donuts.ById[id] then
			found += 1
			if claims[id] then
				claimed += 1
			end
		end
	end
	modal:SetCount(`({found}/{#Donuts.List})`)
	local stats = globalStats
	local totalSpawns = 0
	if stats then
		for _, counts in stats.D do
			totalSpawns += counts[1] or 0
		end
	end
	-- While a Luck Event runs, show the boosted odds too (Roblox wants boosted odds shown when the
	-- boost was paid for).
	local isLucky = lucky()
	for id, card in cards do
		local donut = Donuts.ById[id]
		local rarity = Rarities.Get(donut.Rarity)
		local cash = Economy.IndexCashReward(id)
		local speed = Economy.IndexSpeedReward(id)
		local chance = if donut.Crafted then "Crafted"
			elseif not Donuts.Spawnable(donut) then "Admin only"
			else `{string.format("%.2g", Donuts.Chance(donut) * 100)}%`
		card.Rarity.Text = `{rarity.Id} • {chance}`
		local counts = stats and stats.D[id]
		if rarity.Order >= Config.GlobalStats.ShowFromRarity and Donuts.Spawnable(donut) then
			local spawned = if counts then counts[1] or 0 else 0
			local gotHome = if counts then counts[2] or 0 else 0
			card.Global.Text = if stats then `{Format.Number(spawned)} spawned ({percent(spawned, totalSpawns)}) • {Format.Number(gotHome)} found` else "loading..."
		else
			card.Global.Text = ""
		end
		for mutationId, dot in card.Dots do
			local has = mutations[id] and mutations[id][mutationId]
			dot.BackgroundTransparency = if has then 0 else 0.75
		end
		if discovered[id] then
			card.Viewport.ImageColor3 = Color3.new(1, 1, 1)
			card.Viewport.ImageTransparency = 0
			card.Name.Text = donut.Name
			card.Info.Text = `{Format.Money(donut.Income)}/s`
		else
			-- a dark silhouette you can see the studs through
			card.Viewport.ImageColor3 = Color3.new(0, 0, 0)
			card.Viewport.ImageTransparency = 0.25
			card.Name.Text = "???"
			card.Info.Text = "Not found yet"
		end
		local claimedKind = claims[id]
		local canClaim = discovered[id] and not claimedKind
		card.Cash.Visible = canClaim == true
		if card.Speed then
			card.Speed.Visible = canClaim == true
		end
		card.Status.Visible = not canClaim
		if claimedKind == "Speed" then
			card.Status.Text = `Claimed +{speed or 0}% speed`
			card.Status.TextColor3 = Color3.fromRGB(200, 160, 255)
		elseif claimedKind then
			card.Status.Text = `Claimed {Format.Money(cash)}`
			card.Status.TextColor3 = Theme.Colors.Money
		else
			card.Status.Text = if speed then `{Format.Money(cash)} or +{speed}%` else `Reward {Format.Money(cash)}`
			card.Status.TextColor3 = Color3.fromRGB(200, 200, 210)
		end
	end
	-- the box chances and the mutations on the pages that are built
	for biome, page in pages do
		for _, entry in page.Boxes do
			entry.Label.Text = boxChance(biome, entry.Tier, isLucky)
		end
		for _, mutation in Rarities.Mutations do
			local chanceLabel = page.Mutations[mutation.Id]
			local foundLabel = page.Mutations[mutation.Id .. "Found"]
			if chanceLabel and foundLabel then
				local counts = stats and stats.M[mutation.Id]
				local foundCount = if counts then counts[2] or 0 else 0
				chanceLabel.Text = if mutation.EventOnly then "Eternal Storm only"
					elseif isLucky then `{percent(mutation.Chance * Config.LuckEvent.MutationLuck, 1)} (luck)`
					else percent(mutation.Chance, 1)
				foundLabel.Text = if stats then `{Format.Number(foundCount)} found in game` else "loading..."
			end
		end
	end
	-- the banner: the biome you're looking at and how many of its donuts you've found
	local area = Areas.List[current]
	local inBiome: { Donuts.Donut } = Donuts.ByArea[current] or {}
	local foundHere = 0
	for _, donut in inBiome do
		if discovered[donut.Id] then
			foundHere += 1
		end
	end
	local escape = Economy.EscapeSpeed(current)
	bannerTitle.Text = `{current}. {string.upper(area.Name)}`
	bannerInfo.Text = `{foundHere}/{#inBiome} found  •  ` .. (if escape > 0 then `{Format.Number(escape)} Speed to escape` else "any speed escapes")
	local bonus = State.Number("IndexBonus")
	local unclaimed = Index.UnclaimedCount()
	summary.Text = `Rewards claimed {claimed}/{found}  •  Speed bonus +{bonus}%` .. (if isLucky then `  •  Luck Event: rarer boxes x{Config.LuckEvent.RarityLuck}!` else "")
	Theme.SetButtonText(claimAll, if unclaimed > 0 then `Claim All ({unclaimed})` else "Claim All")
	Theme.SetButtonColor(claimAll, if unclaimed > 0 then Theme.Colors.Green else Theme.Colors.Gray)
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

-- Show a biome's page (building it if needed) and dress the banner in its colours.
local function show(biome: number)
	current = math.clamp(biome, 1, #Areas.List)
	if not pages[current] then
		pages[current] = buildPage(current)
	end
	local index = table.find(recent, current)
	if index then
		table.remove(recent, index)
	end
	table.insert(recent, current)
	trim()
	for id, page in pages do
		page.Frame.Visible = id == current
	end
	local area = Areas.List[current]
	local palette = IndexThemes.Get(area.Theme)
	local gradient = banner:FindFirstChildOfClass("UIGradient") :: UIGradient
	gradient.Color = ColorSequence.new(palette.Top, palette.Bottom)
	bannerInfo.TextColor3 = palette.Accent:Lerp(Color3.new(1, 1, 1), 0.3)
	bannerBack:ClearAllChildren()
	IndexThemes.Decorate(bannerBack, area.Theme, current * 7919)
	refresh()
end

function Index.Open()
	modal:Open()
end

-- Look at a biome's page (the arrows; tests).
function Index.Show(biome: number)
	show(biome)
end

function Index.Init()
	modal = Modal.new("Index", Theme.Colors.Orange, Vector2.new(WIDTH, HEIGHT))
	summary = label({ Name = "Summary", Text = "", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -200, 0, 26), Position = UDim2.fromOffset(2, 4), StrokeThickness = 2, Parent = modal.Body })
	claimAll = Theme.Button({ Name = "ClaimAll", Text = "Claim All", Color = Theme.Colors.Gray, Size = UDim2.fromOffset(186, 34), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, 0), Parent = modal.Body })
	claimAll.Activated:Connect(function()
		if Index.UnclaimedCount() > 0 then
			State.Action("ClaimIndexAll")
		end
	end)
	-- the biome's banner: its colours and details, its name, and arrows to the others
	banner = Theme.new("Frame", {
		Name = "Banner",
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 0, 62),
		Parent = modal.Body,
	}, {
		Theme.Corner(8),
		Theme.Stroke(3),
		Theme.Gradient(Color3.new(1, 1, 1), Color3.new(1, 1, 1)),
	})
	bannerBack = Theme.new("Frame", { Name = "Backdrop", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1, Parent = banner })
	Theme.Band({ Name = "Shade", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.7, 1), Darkness = 0.45, ZIndex = 2, Parent = banner })
	bannerTitle = label({ Name = "Title", Font = Theme.Title, Text = "", Size = UDim2.new(1, -140, 0, 34), Position = UDim2.fromOffset(70, 3), StrokeThickness = 3, ZIndex = 3, Parent = banner })
	bannerInfo = label({ Name = "Info", Text = "", Size = UDim2.new(1, -140, 0, 20), Position = UDim2.fromOffset(70, 38), StrokeThickness = 2, ZIndex = 3, Parent = banner })
	for _, side in { -1, 1 } do
		local button = Theme.Button({
			Name = if side < 0 then "Previous" else "Next",
			Text = if side < 0 then "<" else ">",
			Color = Theme.Colors.Orange,
			Size = UDim2.fromOffset(48, 48),
			AnchorPoint = Vector2.new(if side < 0 then 0 else 1, 0.5),
			Position = UDim2.new(if side < 0 then 0 else 1, side * -7, 0.5, 0),
			Parent = banner,
		})
		button.ZIndex = 4
		button.Activated:Connect(function()
			local count = #Areas.List
			show((current - 1 + side) % count + 1)
		end)
	end
	modal.OnOpen = function()
		show(current)
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
	State.Changed:Connect(function()
		if modal:IsOpen() then
			refresh()
		end
	end)
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
