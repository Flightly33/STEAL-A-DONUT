--[[
	Hotbar: our own inventory bar along the bottom of the screen (Roblox's plain grey one is off).

	  * A row of rounded tiles, one per item: the real 3D donut or box spinning slowly inside, the
	    tile tinted its rarity's colour (a box: its tier's), a number key in the corner, and a
	    little tag along the bottom (a grown donut's size like "2.35x", a mutation, a box's size).
	  * Click or tap a tile (or press its number, 1 - 9) to hold that item; again to put it away.
	    The one in your hand lifts up with a gold rim.
	  * More than nine items: the last tile is a bag ("+12") that opens every item in a grid.
	  * Hovering a tile shows the item's full name above it.
	The bat is always first; everything else keeps the order you got it in.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boxes = require(Shared.Boxes)
local BoxModel = require(Shared.BoxModel)
local Donuts = require(Shared.Donuts)
local DonutModel = require(Shared.DonutModel)
local Rarities = require(Shared.Rarities)

local Theme = require(script.Parent.Theme)

local Hotbar = {}

local player = Players.LocalPlayer :: Player
local rgb = Color3.fromRGB

local SLOTS = 9 -- tiles on the bar (the 9th becomes the bag when there are more items)
local TILE = 66
local GAP = 8
local GOLD = rgb(255, 214, 92)
-- (number keys by name: 1 - 9)
local KEYS: { [string]: number } = { One = 1, Two = 2, Three = 3, Four = 4, Five = 5, Six = 6, Seven = 7, Eight = 8, Nine = 9 }

type Tile = {
	Button: TextButton,
	Lift: Frame,
	Stroke: UIStroke,
	Gradient: UIGradient,
	Key: TextLabel,
	Tag: TextLabel,
	View: ViewportFrame,
	Tool: Tool?,
	Look: string?,
	Model: Model?,
	Camera: Camera?,
}

local gui: ScreenGui
local bar: Frame
local tooltip: TextLabel
local bag: Frame
local bagGrid: ScrollingFrame
local tiles: { Tile } = {}
local order: { Tool } = {} -- every item, in the order you got it (the bat first)
local known: { [Tool]: boolean } = {}
local dirty = true
local bagOpen = false
local spin = 0
local lastRefresh = 0

--------------------------------------------------------------------------------
-- What an item is
--------------------------------------------------------------------------------
-- (its tint, its tag along the bottom, and what its 3D icon is: "Donut|id|mutation|size" ...)
local function describe(tool: Tool): (Color3, string, string)
	local kind = tool:GetAttribute("InvKind")
	local mutation = tool:GetAttribute("Mutation")
	local size = tool:GetAttribute("Size")
	local mutationText = if type(mutation) == "string" and mutation ~= "None" then string.upper(mutation) else ""
	if kind == "Donut" then
		local id = tool:GetAttribute("DonutId")
		local donut = if type(id) == "string" then Donuts.ById[id] else nil
		local color = if donut then Rarities.Get(donut.Rarity).Color else rgb(255, 170, 205)
		local sizeText = if type(size) == "string" and size ~= "Normal" then string.upper(Rarities.SizeLabel(size)) else ""
		local tag = if mutationText ~= "" and sizeText ~= "" then `{sizeText} {mutationText}` else sizeText .. mutationText
		return color, tag, `Donut|{id}|{mutation}|{size}`
	elseif kind == "Box" then
		local tier = tool:GetAttribute("Tier")
		local boxSize = Boxes.Size(if type(size) == "string" then size else nil)
		local color = Boxes.Tier(if type(tier) == "string" then tier else nil).Color
		local tag = if boxSize.Id ~= "Small" then string.upper(boxSize.Name) else mutationText
		return color, tag, `Box|{tier}|{size}|{mutation}`
	end
	return rgb(170, 175, 190), "", `Tool|{tool.Name}`
end

-- The 3D model inside a tile (the item's own tool for anything else, like the bat).
local function buildModel(tool: Tool): Model?
	local kind = tool:GetAttribute("InvKind")
	local mutation = tool:GetAttribute("Mutation")
	local size = tool:GetAttribute("Size")
	local ok, model = pcall(function(): Model?
		if kind == "Donut" then
			local id = tool:GetAttribute("DonutId")
			local donut = if type(id) == "string" then Donuts.ById[id] else nil
			if not donut then
				return nil
			end
			-- (every donut drawn the same size in its tile, however big it grew)
			return DonutModel.Build(donut, { NoEffects = true, Calm = true, Mutation = if type(mutation) == "string" then mutation else nil })
		elseif kind == "Box" then
			local tier = tool:GetAttribute("Tier")
			return BoxModel.Build(if type(tier) == "string" then tier else "Basic", if type(size) == "string" then size else nil, { Mutation = if type(mutation) == "string" then mutation else nil })
		end
		local copy = Instance.new("Model")
		for _, child in tool:GetChildren() do
			if child:IsA("BasePart") then
				local part = child:Clone()
				part.Anchored = true
				part.Parent = copy
				if child.Name == "Handle" or not copy.PrimaryPart then
					copy.PrimaryPart = part
				end
			end
		end
		return if #copy:GetChildren() > 0 then copy else nil
	end)
	return if ok then model else nil
end

-- Put the model in the tile, centred, with a camera looking at it (the tile keeps the camera).
local function frame(tile: Tile, model: Model)
	local view = tile.View
	model.Parent = view
	local cf, extents = model:GetBoundingBox()
	local reach = math.max(extents.X, extents.Y, extents.Z)
	model:PivotTo(model:GetPivot() - cf.Position)
	local camera = tile.Camera or Instance.new("Camera")
	camera.FieldOfView = 30
	camera.CFrame = CFrame.lookAt(Vector3.new(0, reach * 0.35, -reach * 2.1), Vector3.zero)
	camera.Parent = view
	view.CurrentCamera = camera
	tile.Camera = camera
end

--------------------------------------------------------------------------------
-- Tiles
--------------------------------------------------------------------------------
local function newTile(parent: Instance, index: number?): Tile
	local button = Theme.new("TextButton", {
		Name = if index then `Slot{index}` else "Item",
		Size = UDim2.fromOffset(TILE, TILE),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = index or 0,
		Parent = parent,
	}) :: TextButton
	local lift = Theme.new("Frame", {
		Name = "Lift",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = rgb(32, 30, 38),
		Parent = button,
	}, { Theme.Corner(14) }) :: Frame
	local gradient = Theme.new("UIGradient", { Rotation = 90, Parent = lift }) :: UIGradient
	local stroke = Theme.new("UIStroke", { Thickness = 2.5, Color = rgb(255, 255, 255), Transparency = 0.35, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = lift }) :: UIStroke
	-- a soft shine across the top half
	Theme.new("Frame", {
		Name = "Shine",
		Size = UDim2.new(1, -8, 0.42, 0),
		Position = UDim2.fromOffset(4, 3),
		BackgroundColor3 = rgb(255, 255, 255),
		BackgroundTransparency = 0.86,
		ZIndex = 3,
		Parent = lift,
	}, { Theme.Corner(11) })
	local view = Theme.new("ViewportFrame", {
		Name = "Icon",
		Size = UDim2.new(1, -6, 1, -6),
		Position = UDim2.fromOffset(3, 3),
		BackgroundTransparency = 1,
		Ambient = rgb(190, 190, 190),
		LightColor = rgb(255, 255, 255),
		LightDirection = Vector3.new(-0.5, -1, 0.8),
		ZIndex = 2,
		Parent = lift,
	}) :: ViewportFrame
	local key = Theme.Label({
		Name = "Key",
		Text = if index then tostring(index) else "",
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.fromOffset(5, 3),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 4,
		Parent = lift,
	})
	local tag = Theme.Label({
		Name = "Tag",
		Text = "",
		Size = UDim2.new(1, -6, 0, 15),
		Position = UDim2.new(0, 3, 1, -17),
		ZIndex = 4,
		Parent = lift,
	})
	return { Button = button, Lift = lift, Stroke = stroke, Gradient = gradient, Key = key, Tag = tag, View = view, Tool = nil, Look = nil, Model = nil }
end

local function humanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function holding(tool: Tool?): boolean
	return tool ~= nil and player.Character ~= nil and tool.Parent == player.Character
end

-- Hold it (or put it away if you already are).
function Hotbar.Use(tool: Tool?)
	local h = humanoid()
	if not tool or not h then
		return
	end
	if holding(tool) then
		h:UnequipTools()
	else
		h:EquipTool(tool)
	end
	dirty = true
end

local function showTool(tile: Tile, tool: Tool?)
	tile.Tool = tool
	tile.Button.Visible = tool ~= nil
	if not tool then
		return
	end
	local color, tagText, look = describe(tool)
	tile.Gradient.Color = ColorSequence.new(color:Lerp(rgb(255, 255, 255), 0.15), color:Lerp(rgb(20, 18, 28), 0.55))
	tile.Tag.Text = tagText
	local mutation = tool:GetAttribute("Mutation")
	tile.Tag.TextColor3 = if type(mutation) == "string" and mutation ~= "None" then Rarities.Mutation(mutation).Color else rgb(255, 255, 255)
	if tile.Look ~= look then
		tile.Look = look
		if tile.Model then
			tile.Model:Destroy()
			tile.Model = nil
		end
		local model = buildModel(tool)
		if model and pcall(frame, tile, model) then
			tile.Model = model
		elseif model then
			model:Destroy()
		end
	end
	local held = holding(tool)
	tile.Stroke.Color = if held then GOLD else color:Lerp(rgb(255, 255, 255), 0.5)
	tile.Stroke.Thickness = if held then 4 else 2.5
	tile.Stroke.Transparency = if held then 0 else 0.25
	tile.Lift.Position = if held then UDim2.fromOffset(0, -10) else UDim2.fromOffset(0, 0)
end

--------------------------------------------------------------------------------
-- Keeping up with the backpack
--------------------------------------------------------------------------------
local function collect(): { Tool }
	local found: { Tool } = {}
	local containers: { Instance } = {}
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		table.insert(containers, backpack)
	end
	if player.Character then
		table.insert(containers, player.Character :: Instance)
	end
	for _, container in containers do
		for _, child in container:GetChildren() do
			if child:IsA("Tool") then
				table.insert(found, child)
			end
		end
	end
	return found
end

-- The items, in a steady order: the bat (and other non-inventory tools) first, then the order
-- you got things in.
function Hotbar.Items(): { Tool }
	local present: { [Tool]: boolean } = {}
	for _, tool in collect() do
		present[tool] = true
		if not known[tool] then
			known[tool] = true
			if tool:GetAttribute("InvUid") == nil then
				table.insert(order, 1, tool)
			else
				table.insert(order, tool)
			end
		end
	end
	local kept: { Tool } = {}
	for _, tool in order do
		if present[tool] then
			table.insert(kept, tool)
		else
			known[tool] = nil
		end
	end
	order = kept
	return kept
end

local bagTiles: { Tile } = {}

local function refreshBag(items: { Tool })
	for i, tool in items do
		local tile: Tile = bagTiles[i] or newTile(bagGrid)
		if not bagTiles[i] then
			bagTiles[i] = tile
			tile.Button.Activated:Connect(function()
				Hotbar.Use(tile.Tool)
			end)
		end
		tile.Button.LayoutOrder = i
		showTool(tile, tool)
	end
	for i = #items + 1, #bagTiles do
		showTool(bagTiles[i], nil)
	end
end

function Hotbar.Refresh()
	dirty = false
	local items = Hotbar.Items()
	local overflow = #items > SLOTS
	local onBar = if overflow then SLOTS - 1 else SLOTS
	for i = 1, SLOTS do
		local tile = tiles[i]
		if i == SLOTS and overflow then
			-- the bag: every item in a grid
			showTool(tile, nil)
			tile.Button.Visible = true
			tile.Tool = nil
			tile.Look = nil
			if tile.Model then
				tile.Model:Destroy()
				tile.Model = nil
			end
			tile.Gradient.Color = ColorSequence.new(rgb(120, 90, 60), rgb(60, 40, 28))
			tile.Stroke.Color = if bagOpen then GOLD else rgb(255, 220, 170)
			tile.Stroke.Thickness = 2.5
			tile.Stroke.Transparency = 0.2
			tile.Lift.Position = UDim2.fromOffset(0, 0)
			tile.Tag.Text = `+{#items - onBar}`
			tile.Tag.TextColor3 = rgb(255, 255, 255)
		else
			showTool(tile, items[i])
		end
	end
	bar.Visible = #items > 0
	if bagOpen and overflow then
		bag.Visible = true
		refreshBag(items)
	else
		bagOpen = false
		bag.Visible = false
	end
end

function Hotbar.ToggleBag(open: boolean?)
	bagOpen = if open == nil then not bagOpen else open
	dirty = true
	Hotbar.Refresh()
end

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------
local function watch(container: Instance)
	container.ChildAdded:Connect(function()
		dirty = true
	end)
	container.ChildRemoved:Connect(function()
		dirty = true
	end)
end

function Hotbar.Init()
	-- Roblox's own hotbar goes away (ours replaces it)
	task.spawn(function()
		for _ = 1, 20 do
			local ok = pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			end)
			if ok then
				return
			end
			task.wait(0.5)
		end
	end)

	gui = Theme.ScreenGui("Hotbar", 4)
	local holder = Theme.new("Frame", {
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(SLOTS * TILE + (SLOTS - 1) * GAP + 24, TILE + 30),
		BackgroundTransparency = 1,
		Parent = gui,
	}) :: Frame
	Theme.AutoScale(holder)
	bar = Theme.new("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(0, 0, 0, TILE + 16),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = rgb(18, 16, 24),
		BackgroundTransparency = 0.35,
		Parent = holder,
	}, {
		Theme.Corner(20),
		Theme.Stroke(2, rgb(255, 255, 255)),
		Theme.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }),
		Theme.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom }),
	}) :: Frame
	local barStroke = bar:FindFirstChildOfClass("UIStroke")
	if barStroke then
		barStroke.Transparency = 0.8
	end
	for i = 1, SLOTS do
		local tile = newTile(bar, i)
		tiles[i] = tile
		tile.Button.Activated:Connect(function()
			if tile.Tool then
				Hotbar.Use(tile.Tool)
			elseif i == SLOTS then
				Hotbar.ToggleBag()
			end
		end)
		tile.Button.MouseEnter:Connect(function()
			if tile.Tool then
				tooltip.Text = tile.Tool.Name
			elseif i == SLOTS and tile.Button.Visible then
				tooltip.Text = "All your items"
			else
				return
			end
			tooltip.Parent = tile.Button
			tooltip.Visible = true
		end)
		tile.Button.MouseLeave:Connect(function()
			tooltip.Visible = false
		end)
	end
	-- (the hovered tile's name, just above it)
	tooltip = Theme.Label({
		Name = "Tooltip",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -16),
		Size = UDim2.fromOffset(260, 24),
		ZIndex = 10,
		Visible = false,
		Parent = holder,
	})

	-- the bag: every item, above the bar
	bag = Theme.new("Frame", {
		Name = "Bag",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -12),
		Size = UDim2.fromOffset(6 * (TILE + GAP) + 24, 3 * (TILE + GAP) + 50),
		BackgroundColor3 = rgb(18, 16, 24),
		BackgroundTransparency = 0.2,
		Visible = false,
		Parent = holder,
	}, {
		Theme.Corner(18),
		Theme.Stroke(2, rgb(255, 220, 170)),
	}) :: Frame
	Theme.Label({ Name = "Title", Text = "YOUR ITEMS", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 6), Parent = bag })
	bagGrid = Theme.new("ScrollingFrame", {
		Name = "Grid",
		Size = UDim2.new(1, -16, 1, -46),
		Position = UDim2.fromOffset(8, 40),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = bag,
	}, {
		Theme.new("UIGridLayout", { CellSize = UDim2.fromOffset(TILE, TILE), CellPadding = UDim2.fromOffset(GAP, GAP + 4), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }),
		Theme.new("UIPadding", { PaddingTop = UDim.new(0, 12) }),
	}) :: ScrollingFrame

	local function hookCharacter(character: Model)
		watch(character)
		dirty = true
	end
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			watch(child)
			dirty = true
		end
	end)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		watch(backpack)
	end
	if player.Character then
		hookCharacter(player.Character)
	end
	player.CharacterAdded:Connect(hookCharacter)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		local index = KEYS[input.KeyCode.Name]
		if not index then
			return
		end
		local tile = tiles[index]
		if tile and tile.Tool then
			Hotbar.Use(tile.Tool)
		elseif tile and index == SLOTS and tile.Button.Visible then
			Hotbar.ToggleBag()
		end
	end)

	-- the icons turn slowly (only the ones you can see)
	RunService.RenderStepped:Connect(function(dt: number)
		-- (right away when something changes, and twice a second anyway in case we missed it)
		local now = os.clock()
		if dirty or now - lastRefresh > 0.5 then
			lastRefresh = now
			Hotbar.Refresh()
		end
		if not gui.Enabled or not bar.Visible then
			return
		end
		spin += dt * 0.6
		local turn = CFrame.Angles(0, spin, 0)
		local function turnTile(tile: Tile)
			local model = tile.Model
			if model and tile.Button.Visible then
				local camera = tile.Camera
				if camera then
					local distance = camera.CFrame.Position.Magnitude
					camera.CFrame = CFrame.lookAt((turn * Vector3.new(0, distance * 0.16, -distance)), Vector3.zero)
				end
			end
		end
		for _, tile in tiles do
			turnTile(tile)
		end
		if bagOpen then
			for _, tile in bagTiles do
				turnTile(tile)
			end
		end
	end)
	Hotbar.Refresh()
end

return Hotbar
