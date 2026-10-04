--[[
	ItemCard: the details card that pops up when you hover a donut, pet or egg (the Update Log's
	cards use it). Like an item tooltip in other games:

	  * the name, and its rarity in the rarity's colour
	  * three stat boxes (a donut's money per second, spawn chance and area; a pet's boosts and
	    hatch chance; an egg's hatch time, pets and rarest odds)
	  * a description with the important words coloured (mutations, the egg's pets...)
	  * the real 3D model, spinning, on the right
	  * "How to get" along the bottom

	With a mouse it follows the pointer while you hover. On phones and tablets, tap a card to show
	it next to the card, and tap anywhere else to hide it.

	ItemCard.Attach(button, { Kind = "Donut" | "Pet" | "Egg", Id = "...", Note = "..."? }, onHover?)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Areas = require(Shared.Areas)
local Boxes = require(Shared.Boxes)
local Donuts = require(Shared.Donuts)
local DonutModel = require(Shared.DonutModel)
local Pets = require(Shared.Pets)
local PetModel = require(Shared.PetModel)
local Rarities = require(Shared.Rarities)
local Format = require(Shared.Format)
local Theme = require(script.Parent.Theme)

local ItemCard = {}

export type Item = { Kind: string, Id: string, Note: string? }
export type Stat = { Label: string, Value: string, Color: Color3 }
export type Info = {
	Name: string,
	Kind: string, -- "Legendary Donut", "Epic Pet", "Egg"...
	Rarity: string, -- short tag for small cards
	Color: Color3,
	Stats: { Stat },
	Lines: { string }, -- rich text
	HowTo: string,
}

local rgb = Color3.fromRGB
local WIDTH = 470
local LEFT = 304
local MONEY = rgb(110, 255, 90)
local SPEED = rgb(170, 130, 255)
local CHANCE = rgb(255, 215, 80)
local PLACE = rgb(120, 200, 255)
local MUTATIONS = { "Gold", "Diamond", "Mythic", "Divine", "Rainbow" }

-- Colour some words; dark colours (a Cosmic Egg's purple) are lightened so they read on the card
local function paint(text: string, color: Color3): string
	local brightness = color.R * 0.299 + color.G * 0.587 + color.B * 0.114
	if brightness < 0.55 then
		color = color:Lerp(Color3.new(1, 1, 1), math.clamp((0.55 - brightness) * 1.6, 0, 0.7))
	end
	return `<font color="#{color:ToHex()}">{text}</font>`
end

local function percent(chance: number): string
	if chance >= 0.01 then
		return string.format("%.3g%%", chance * 100)
	elseif chance > 0 then
		return "1 in " .. Format.Commas(math.floor(1 / chance + 0.5))
	end
	return "-"
end

local function areaName(id: number): string
	local area = Areas.Get(id)
	if not area then
		return `Biome {id}`
	end
	return `{area.Name} (biome {area.Id})`
end

-- "Sugar Dunes to Candy Cane Canyon (biomes 3-8)"
local function areaRange(from: number, to: number): string
	local a, b = Areas.Get(from), Areas.Get(to)
	if a and b then
		return `{a.Name} to {b.Name} (biomes {a.Id}-{b.Id})`
	end
	return `{areaName(from)} to {areaName(to)}`
end

-- 180 -> "3m", 90 -> "1m 30s"
local function duration(seconds: number): string
	return (string.gsub(Format.Duration(seconds), " 0s$", ""))
end

---------------------------------------------------------------------------------------------------
-- What a card says about each kind of thing
---------------------------------------------------------------------------------------------------

function ItemCard.Model(item: Item): Model?
	local ok, model = pcall(function(): Model?
		if item.Kind == "Donut" then
			local donut = Donuts.ById[item.Id]
			return if donut then DonutModel.Build(donut, { NoEffects = true }) else nil
		elseif item.Kind == "Pet" then
			local pet = Pets.ById[item.Id]
			return if pet then PetModel.BuildPet(pet, { NoEffects = true }) else nil
		elseif item.Kind == "Egg" then
			local egg = Pets.EggById[item.Id]
			return if egg then PetModel.BuildEgg(egg, { NoEffects = true }) else nil
		end
		return nil
	end)
	return if ok then model else nil
end

function ItemCard.Describe(item: Item): Info
	local info: Info
	if item.Kind == "Donut" and Donuts.ById[item.Id] then
		local donut = Donuts.ById[item.Id]
		local rarity = Rarities.Get(donut.Rarity)
		local area = Areas.Get(donut.Area)
		local spawnable = Donuts.Spawnable(donut)
		local box = if donut.Box then Boxes.Tier(donut.Box) else nil
		local mutations = {}
		for _, id in MUTATIONS do
			local mutation = Rarities.Mutation(id)
			table.insert(mutations, paint(`{id} x{mutation.Multiplier}`, mutation.Color))
		end
		info = {
			Name = donut.Name,
			Kind = `{donut.Rarity} Donut`,
			Rarity = donut.Rarity,
			Color = rarity.Color,
			Stats = {
				{ Label = "Money", Value = `{Format.Money(donut.Income)}/s`, Color = MONEY },
				{ Label = "Box chance", Value = if spawnable then percent(Donuts.Chance(donut)) else "Admin only", Color = CHANCE },
				{ Label = "Biome", Value = tostring(donut.Area), Color = PLACE },
			},
			Lines = if spawnable and box
				then {
					`Comes out of a {paint(box.Name, box.Color)} from {paint(if area then area.Name else "the lane", if area then area.Trim else PLACE)}. Steal one before {paint(Config.Guard.Name, rgb(255, 90, 90))} wakes up!`,
					`Can come as {table.concat(mutations, ", ")} for more money.`,
				}
				else {
					`Never comes out of a box: only the {paint("admin panel", rarity.Color)} can make one.`,
					`Can come as {table.concat(mutations, ", ")} for more money.`,
				},
			HowTo = if spawnable and box then `{box.Name}, {areaName(donut.Area)}` else "Admin panel only",
		}
	elseif item.Kind == "Pet" and Pets.ById[item.Id] then
		local pet = Pets.ById[item.Id]
		local rarity = Pets.Rarity(pet.Rarity)
		local egg = Pets.EggOf(pet.Id)
		local chance = if egg then Pets.Chance(egg, pet.Id) else 0
		info = {
			Name = pet.Name,
			Kind = `{pet.Rarity} Pet`,
			Rarity = pet.Rarity,
			Color = rarity.Color,
			Stats = {
				{ Label = "Money", Value = `+{math.floor(pet.Money * 100 + 0.5)}%`, Color = MONEY },
				{ Label = "Speed", Value = `+{math.floor(pet.Speed * 100 + 0.5)}%`, Color = SPEED },
				{ Label = "Hatch chance", Value = if egg then percent(chance) else "-", Color = CHANCE },
			},
			Lines = {
				`Follows you around and gives {paint(Pets.BonusText(pet), MONEY)}.`,
				if egg then `Hatches from the {paint(egg.Name, egg.Color)} ({percent(chance)} chance).` else `A rare find: {paint(pet.Exclusive or "special", CHANCE)} only.`,
			},
			HowTo = if pet.Exclusive then `From the {pet.Exclusive}` elseif egg then `Hatch it from a {egg.Name}` else "Special pet",
		}
	elseif item.Kind == "Egg" and Pets.EggById[item.Id] then
		local egg = Pets.EggById[item.Id]
		local odds = {}
		for _, entry in egg.Pool do
			local pet = Pets.ById[entry.Pet]
			if pet then
				table.insert(odds, `{paint(pet.Name, Pets.Rarity(pet.Rarity).Color)} {percent(Pets.Chance(egg, pet.Id))}`)
			end
		end
		local last = egg.Pool[#egg.Pool]
		info = {
			Name = egg.Name,
			Kind = `Tier {egg.Tier} Egg`,
			Rarity = "Egg",
			Color = egg.Color,
			Stats = {
				{ Label = "Hatch time", Value = duration(egg.HatchSeconds), Color = PLACE },
				{ Label = "Pets inside", Value = tostring(#egg.Pool), Color = MONEY },
				{ Label = "Rarest pet", Value = if last then percent(Pets.Chance(egg, last.Pet)) else "-", Color = CHANCE },
			},
			Lines = {
				`Bring it to your incubator to hatch one of: {table.concat(odds, ", ")}.`,
			},
			HowTo = if egg.CrateOnly then "Only found in crates" else `Grab one in the lane, from {areaRange(egg.MinArea, egg.MaxArea)}`,
		}
	else
		info = { Name = item.Id, Kind = item.Kind, Rarity = "", Color = Theme.Colors.Gray, Stats = {}, Lines = {}, HowTo = "" }
	end
	if item.Note then
		table.insert(info.Lines, 1, paint(item.Note, rgb(255, 235, 140)))
	end
	return info
end

---------------------------------------------------------------------------------------------------
-- The floating card
---------------------------------------------------------------------------------------------------
local gui: ScreenGui? = nil
local card: Frame
local nameLabel: TextLabel
local kindLabel: TextLabel
local statBoxes: { Frame } = {}
local description: TextLabel
local howTo: TextLabel
local viewport: ViewportFrame
local camera: Camera
local cardGradient: UIGradient
local cardStroke: UIStroke

local current: GuiObject? = nil
local currentHover: ((boolean) -> ())? = nil
local pinned = false
local models: { [string]: Model } = {}
local shownModel: Model? = nil
local distance = 10

local function text(props: { [string]: any }): TextLabel
	props.Font = props.Font or Theme.Font
	props.TextScaled = false
	props.TextWrapped = true
	props.AutomaticSize = props.AutomaticSize or Enum.AutomaticSize.Y
	return Theme.Label(props)
end

local function build()
	local screen = Theme.ScreenGui("ItemCard", 40)
	gui = screen
	card = Theme.new("Frame", {
		Name = "Card",
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		Parent = screen,
	}, {
		Theme.Corner(12),
		Theme.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	cardGradient = Theme.new("UIGradient", { Rotation = 90, Parent = card })
	cardStroke = Theme.Stroke(3)
	cardStroke.Parent = card
	Theme.AutoScale(card)

	local top = Theme.new("Frame", { Name = "Top", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = card })
	local left = Theme.new("Frame", {
		Name = "Info",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(LEFT, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = top,
	}, {
		Theme.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		Theme.new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12) }),
	})
	nameLabel = text({ Name = "ItemName", Font = Theme.Title, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -4, 0, 0), StrokeThickness = 2.5, LayoutOrder = 1, Parent = left })
	kindLabel = text({ Name = "Kind", TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -4, 0, 0), StrokeThickness = 2, LayoutOrder = 2, Parent = left })
	local stats = Theme.new("Frame", { Name = "Stats", BackgroundTransparency = 1, Size = UDim2.new(1, -4, 0, 54), LayoutOrder = 3, Parent = left }, {
		Theme.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i = 1, 3 do
		local box = Theme.new("Frame", {
			Name = "Stat" .. i,
			Size = UDim2.new(1 / 3, -4, 1, 0),
			BackgroundColor3 = rgb(12, 11, 20),
			LayoutOrder = i,
			Parent = stats,
		}, { Theme.Corner(8), Theme.Stroke(2, rgb(60, 58, 80)) })
		-- (same size in every box: long labels shrink, short ones don't blow up)
		local label = Theme.Label({ Name = "Label", Font = Theme.Font, TextColor3 = rgb(185, 180, 205), Size = UDim2.new(1, -8, 0, 16), Position = UDim2.fromOffset(4, 4), StrokeThickness = 1.2, Parent = box })
		Theme.new("UITextSizeConstraint", { MaxTextSize = 14, Parent = label })
		local value = Theme.Label({ Name = "Value", Size = UDim2.new(1, -8, 0, 26), Position = UDim2.fromOffset(4, 22), StrokeThickness = 2, Parent = box })
		Theme.new("UITextSizeConstraint", { MaxTextSize = 24, Parent = value })
		statBoxes[i] = box
	end
	local descBox = Theme.new("Frame", {
		Name = "Description",
		BackgroundColor3 = rgb(10, 9, 17),
		BackgroundTransparency = 0.15,
		Size = UDim2.new(1, -4, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 4,
		Parent = left,
	}, { Theme.Corner(8), Theme.Stroke(2, rgb(60, 58, 80)), Theme.Padding(8) })
	description = text({ Name = "Text", RichText = true, TextSize = 16, LineHeight = 1.05, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromScale(1, 0), StrokeThickness = 1.5, Parent = descBox })

	viewport = Theme.new("ViewportFrame", {
		Name = "Model",
		BackgroundTransparency = 1,
		Ambient = rgb(190, 185, 205),
		LightColor = rgb(255, 255, 255),
		LightDirection = Vector3.new(-0.5, -1, 0.8),
		Position = UDim2.fromOffset(LEFT + 6, 8),
		Size = UDim2.fromOffset(WIDTH - LEFT - 14, 150),
		Parent = top,
	})
	camera = Instance.new("Camera")
	camera.FieldOfView = 38
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local bar = Theme.new("Frame", {
		Name = "HowTo",
		BackgroundColor3 = rgb(30, 28, 44),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = card,
	}, { Theme.Corner(10), Theme.new("UIPadding", { PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }) })
	howTo = text({ Name = "Text", RichText = true, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromScale(1, 0), StrokeThickness = 1.5, Parent = bar })
end

-- Is this GUI object actually on screen (it and every parent visible)?
local function onScreen(object: Instance): boolean
	local node: Instance? = object
	while node do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		elseif node:IsA("LayerCollector") then
			return node.Enabled
		end
		node = node.Parent
	end
	return false
end

local function lastInputWasTouch(): boolean
	local ok, kind = pcall(function()
		return UserInputService:GetLastInputType()
	end)
	if ok and kind then
		return kind == Enum.UserInputType.Touch
	end
	return Theme.IsTouch
end

local function guiInset(): Vector2
	local ok, inset = pcall(function()
		return GuiService:GetGuiInset()
	end)
	return if ok and typeof(inset) == "Vector2" then inset else Vector2.zero
end

local function keyOf(item: Item): string
	return item.Kind .. ":" .. item.Id
end

local function show(target: GuiObject, item: Item, pin: boolean, onHover: ((boolean) -> ())?)
	if not gui then
		build()
	end
	if currentHover and current ~= target then
		currentHover(false)
	end
	current = target
	currentHover = onHover
	pinned = pin
	local info = ItemCard.Describe(item)
	nameLabel.Text = info.Name
	kindLabel.Text = info.Kind
	kindLabel.TextColor3 = Theme.Lighten(info.Color, 0.15)
	cardGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.Darken(info.Color, 0.62)),
		ColorSequenceKeypoint.new(0.35, rgb(22, 20, 34)),
		ColorSequenceKeypoint.new(1, rgb(16, 15, 26)),
	})
	cardStroke.Color = Theme.Darken(info.Color, 0.25)
	for i, box in statBoxes do
		local stat = info.Stats[i]
		box.Visible = stat ~= nil
		if stat then
			(box:FindFirstChild("Label") :: TextLabel).Text = stat.Label
			local value = box:FindFirstChild("Value") :: TextLabel
			value.Text = stat.Value
			value.TextColor3 = stat.Color
		end
	end
	description.Text = table.concat(info.Lines, "\n")
	howTo.Text = `<font color="#FFD25A">How to get:</font> {info.HowTo}`

	-- the model (built once per item, then kept)
	if shownModel then
		shownModel.Parent = nil
		shownModel = nil
	end
	local key = keyOf(item)
	local model = models[key]
	if not model then
		local built = ItemCard.Model(item)
		if built then
			local box = built:GetBoundingBox()
			built:PivotTo(built:GetPivot() - box.Position)
			models[key] = built
			model = built
		end
	end
	if model then
		local _, size = model:GetBoundingBox()
		distance = math.max(size.X, size.Y, size.Z) * 1.9
		model.Parent = viewport
		shownModel = model
	end
	card.Visible = true
end

function ItemCard.Hide()
	if gui then
		card.Visible = false
	end
	local hover = currentHover
	current = nil
	currentHover = nil
	pinned = false
	if hover then
		hover(false)
	end
end

function ItemCard.IsShowing(): boolean
	return gui ~= nil and card.Visible
end

function ItemCard.Attach(target: GuiButton, item: Item, onHover: ((boolean) -> ())?)
	target.MouseEnter:Connect(function()
		if lastInputWasTouch() then
			return -- phones: tap instead (Activated)
		end
		show(target, item, false, onHover)
		if onHover then
			onHover(true)
		end
	end)
	target.MouseLeave:Connect(function()
		if current == target and not pinned then
			ItemCard.Hide()
		elseif onHover then
			onHover(false)
		end
	end)
	target.Activated:Connect(function()
		if not lastInputWasTouch() then
			return
		end
		if current == target and pinned then
			ItemCard.Hide()
		else
			show(target, item, true, onHover)
			if onHover then
				onHover(true)
			end
		end
	end)
end

local started = false
function ItemCard.Init()
	if started then
		return
	end
	started = true
	-- A tap anywhere but the card's button hides a pinned card
	UserInputService.InputBegan:Connect(function(input: InputObject)
		local target = current
		if not pinned or not target or input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local at = Vector2.new(input.Position.X, input.Position.Y)
		local from, size = target.AbsolutePosition, target.AbsoluteSize
		if at.X < from.X or at.Y < from.Y or at.X > from.X + size.X or at.Y > from.Y + size.Y then
			ItemCard.Hide()
		end
	end)
	RunService.RenderStepped:Connect(function()
		if not gui or not card.Visible then
			return
		end
		local target = current
		if not target or not onScreen(target) then
			ItemCard.Hide()
			return
		end
		local t = os.clock()
		camera.CFrame = CFrame.lookAt(Vector3.new(math.sin(t * 0.9) * distance, distance * 0.2, -math.cos(t * 0.9) * distance), Vector3.zero)

		-- Next to the pointer (or next to the tapped card), kept on screen
		local screenGui = gui :: ScreenGui
		local screen = screenGui.AbsoluteSize
		local size = card.AbsoluteSize
		local x, y
		if pinned then
			local from, targetSize = target.AbsolutePosition, target.AbsoluteSize
			x = from.X + targetSize.X + 10
			if x + size.X > screen.X - 6 then
				x = from.X - size.X - 10
			end
			y = from.Y
		else
			local mouse = UserInputService:GetMouseLocation() - guiInset()
			-- (MouseLeave doesn't always fire, e.g. when the list scrolls under the pointer)
			local from, targetSize = target.AbsolutePosition, target.AbsoluteSize
			if mouse.X < from.X or mouse.Y < from.Y or mouse.X > from.X + targetSize.X or mouse.Y > from.Y + targetSize.Y then
				ItemCard.Hide()
				return
			end
			x = mouse.X + 18
			if x + size.X > screen.X - 6 then
				x = mouse.X - size.X - 18
			end
			y = mouse.Y + 12
		end
		x = math.clamp(x, 6, math.max(6, screen.X - size.X - 6))
		y = math.clamp(y, 6, math.max(6, screen.Y - size.Y - 6))
		card.Position = UDim2.fromOffset(x, y)
	end)
end

return ItemCard
