--[[
	UpdateNotes: the Update Log window (the notes themselves are in Shared/UpdateNotes).

	  * a ribbon tab "Update Log", a "Shown on login / Hidden on login" switch, an "Update N" picker
	    and a round close button along the top
	  * left: the game's logo, the update's name, "Update N Patch Notes", a box listing everything new
	    (✦ between them), then each section: heading, tag and bullet lines
	  * right: groups of new things as cards with spinning 3D models of the real donuts / pets / eggs
	    (built from the game's own models, so there are no images to upload)
	It opens by itself the first time a player joins after a new update (their save remembers the
	last one they saw), unless they set it to "Hidden on login"; Settings > Update Log opens it any
	time. Brand-new players get the tutorial instead.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Notes = require(Shared.UpdateNotes)
local Donuts = require(Shared.Donuts)
local DonutModel = require(Shared.DonutModel)
local Pets = require(Shared.Pets)
local PetModel = require(Shared.PetModel)
local Rarities = require(Shared.Rarities)
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local State = require(script.Parent.Parent.State)

local UpdateNotes = {}

local WIDTH, HEIGHT = 900, 540
local SIDEBAR = 256
local rgb = Color3.fromRGB

type Spinner = { Camera: Camera, Distance: number, Height: number, Phase: number }

local modal: Modal.Modal
local show: (version: number) -> ()

function UpdateNotes.Open(version: number?)
	show(version or Notes.Latest)
	modal:Open()
end

local function hex(color: Color3): string
	return string.format("#%02X%02X%02X", math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255))
end

local function text(props: { [string]: any }): TextLabel
	props.Font = props.Font or Theme.Font
	props.TextScaled = false
	props.TextWrapped = true
	props.AutomaticSize = Enum.AutomaticSize.Y
	return Theme.Label(props)
end

-- What a sidebar card shows: the model, its name and its rarity colour.
local function describe(item: Notes.Item): (Model?, string, string, Color3)
	if item.Kind == "Donut" then
		local donut = Donuts.ById[item.Id]
		if donut then
			local ok, model = pcall(DonutModel.Build, donut, { NoEffects = true })
			return if ok then model else nil, donut.Name, donut.Rarity, Rarities.Get(donut.Rarity).Color
		end
	elseif item.Kind == "Pet" then
		local pet = Pets.ById[item.Id]
		if pet then
			local ok, model = pcall(PetModel.BuildPet, pet, { NoEffects = true })
			return if ok then model else nil, pet.Name, pet.Rarity, Pets.Rarity(pet.Rarity).Color
		end
	elseif item.Kind == "Egg" then
		local egg = Pets.EggById[item.Id]
		if egg then
			local ok, model = pcall(PetModel.BuildEgg, egg, { NoEffects = true })
			return if ok then model else nil, egg.Name, "Egg", egg.Color
		end
	end
	return nil, item.Id, "", Theme.Colors.Gray
end

-- Put a model in a ViewportFrame, centred, and return a spinner for its camera.
local function stage(viewport: ViewportFrame, model: Model, zoom: number): Spinner
	local box, size = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() - box.Position)
	model.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local distance = math.max(size.X, size.Y, size.Z) * zoom
	local spinner = { Camera = camera, Distance = distance, Height = distance * 0.18, Phase = math.random() * 6 }
	camera.CFrame = CFrame.lookAt(Vector3.new(0, spinner.Height, -distance), Vector3.zero)
	return spinner
end

function UpdateNotes.Init()
	modal = Modal.new("UPDATE LOG", Theme.Colors.Orange, Vector2.new(WIDTH, HEIGHT))
	local frame = modal.Frame
	-- Our own top bar instead of the usual window header
	local header = frame:FindFirstChild("Header")
	if header and header:IsA("GuiObject") then
		header.Visible = false
	end
	frame.BackgroundColor3 = rgb(14, 12, 24)
	local panelGradient = frame:FindFirstChildOfClass("UIGradient")
	if panelGradient then
		panelGradient:Destroy()
	end
	modal.Body.Position = UDim2.new()
	modal.Body.Size = UDim2.fromScale(1, 1)
	local body = modal.Body

	-- Left: the patch notes, over a big faded model
	local left = Theme.new("Frame", {
		Name = "Notes",
		Position = UDim2.fromOffset(12, 64),
		Size = UDim2.new(1, -(SIDEBAR + 34), 1, -76),
		ClipsDescendants = true,
		Parent = body,
	}, { Theme.Corner(12), Theme.Stroke(3) })
	local leftGradient = Theme.new("UIGradient", { Rotation = 90, Parent = left })
	local backdrop = Theme.new("ViewportFrame", {
		Name = "Backdrop",
		BackgroundTransparency = 1,
		ImageTransparency = 0.6,
		Ambient = rgb(200, 190, 220),
		LightColor = rgb(255, 255, 255),
		LightDirection = Vector3.new(-0.4, -1, 0.7),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -10),
		Size = UDim2.new(1, 40, 0, 260),
		Parent = left,
	})
	local scroll = Theme.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = left,
	}, {
		Theme.new("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
		Theme.new("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 16) }),
	})

	-- Right: the new things, as cards
	local right = Theme.new("Frame", {
		Name = "Sidebar",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 64),
		Size = UDim2.new(0, SIDEBAR, 1, -76),
		BackgroundColor3 = rgb(8, 7, 14),
		Parent = body,
	}, { Theme.Corner(12), Theme.Stroke(3) })
	local cards = Theme.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = right,
	}, {
		Theme.new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
		Theme.new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 12) }),
	})

	-- Top bar: the ribbon tab, the two pickers and the close button
	Theme.new("Frame", { Name = "TopBar", Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = rgb(10, 9, 18), BorderSizePixel = 0, Parent = body }, { Theme.Corner(18) })
	local ribbon = Theme.new("Frame", {
		Name = "Ribbon",
		Position = UDim2.fromOffset(-30, -24),
		Size = UDim2.fromOffset(380, 70),
		ZIndex = 3,
		Parent = body,
	}, { Theme.Corner(12), Theme.Stroke(3.5) })
	local ribbonGradient = Theme.new("UIGradient", { Rotation = 90, Parent = ribbon })
	Theme.Label({ Text = "Update Log", TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(96, 12), Size = UDim2.new(1, -110, 0, 46), StrokeThickness = 3.5, ZIndex = 4, Parent = ribbon })
	local badge = Theme.new("Frame", {
		Name = "Badge",
		Position = UDim2.fromOffset(-44, -34),
		Size = UDim2.fromOffset(96, 96),
		BackgroundColor3 = Theme.Colors.Yellow,
		ZIndex = 5,
		Parent = body,
	}, { Theme.new("UICorner", { CornerRadius = UDim.new(1, 0) }), Theme.Stroke(4), Theme.Gradient(rgb(255, 230, 120), rgb(255, 150, 40)) })
	Theme.Label({ Text = "🍩", Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), ZIndex = 6, Parent = badge })

	local close = Theme.Button({ Text = "X", Color = Theme.Colors.Red, Size = UDim2.fromOffset(58, 58), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -8, 0, 8), Parent = body })
	close.ZIndex = 5
	for _, child in close:GetDescendants() do
		if child:IsA("UICorner") then
			child.CornerRadius = UDim.new(1, 0)
		end
	end
	close.Activated:Connect(function()
		modal:Close()
	end)
	local versionButton = Theme.Button({ Text = "", Color = rgb(55, 55, 70), Size = UDim2.fromOffset(170, 42), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -52, 0, 8), Parent = body })
	local loginButton = Theme.Button({ Text = "", Color = rgb(55, 55, 70), Size = UDim2.fromOffset(230, 42), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -232, 0, 8), Parent = body })

	-- "Update N" picker: a little menu of every update
	local menu = Theme.new("Frame", {
		Name = "VersionMenu",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -52, 0, 54),
		Size = UDim2.fromOffset(170, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = rgb(30, 30, 44),
		Visible = false,
		ZIndex = 10,
		Parent = body,
	}, { Theme.Corner(10), Theme.Stroke(2.5), Theme.new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }), Theme.new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }) })
	for i, update in Notes.List do
		local option = Theme.Button({ Text = `Update {update.Version}`, Color = if i == 1 then Theme.Colors.Orange else rgb(70, 70, 90), Size = UDim2.new(1, 0, 0, 36), Parent = menu })
		option.LayoutOrder = i
		option.ZIndex = 11
		option.Activated:Connect(function()
			menu.Visible = false
			show(update.Version)
		end)
	end
	versionButton.Activated:Connect(function()
		menu.Visible = not menu.Visible
	end)

	-- "Shown on login" switch (saved)
	local function showLogin()
		Theme.SetButtonText(loginButton, if State.Get("NotesOnLogin") == false then "▼ Hidden on login" else "▼ Shown on login")
	end
	loginButton.Activated:Connect(function()
		local on = State.Get("NotesOnLogin") == false
		State.Action("NotesOnLogin", on)
		Theme.SetButtonText(loginButton, if on then "▼ Shown on login" else "▼ Hidden on login")
	end)
	State.Changed:Connect(showLogin)
	showLogin()

	local spinners: { Spinner } = {}
	show = function(version: number)
		local update = Notes.Get(version) or Notes.List[1]
		menu.Visible = false
		table.clear(spinners)
		for _, container in { scroll, cards } do
			for _, child in container:GetChildren() do
				if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
					child:Destroy()
				end
			end
		end
		backdrop:ClearAllChildren()
		Theme.SetButtonText(versionButton, `▼ Update {update.Version}`)
		leftGradient.Color = ColorSequence.new(Theme.Lighten(update.Color, 0.12), Theme.Darken(update.Color, 0.45))
		ribbonGradient.Color = ColorSequence.new(Theme.Lighten(update.Accent, 0.15), Theme.Darken(update.Accent, 0.2))
		local accent = update.Accent

		-- Left column
		local order = 0
		local function add(instance: GuiObject)
			order += 1
			instance.LayoutOrder = order
			instance.Parent = scroll
		end
		local logo = Theme.Label({ Text = "STEAL A DONUT", Size = UDim2.new(1, -30, 0, 70), StrokeThickness = 5 })
		Theme.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(rgb(255, 255, 255), rgb(255, 190, 225)), Parent = logo })
		add(logo)
		add(Theme.Label({ Text = update.Name, TextColor3 = accent, Size = UDim2.new(1, -30, 0, 48), StrokeThickness = 4 }))
		add(Theme.Label({ Text = `Update {update.Version} Patch Notes  •  {update.Date}`, Font = Theme.Font, TextColor3 = rgb(205, 200, 220), Size = UDim2.new(1, -30, 0, 24), StrokeThickness = 2 }))
		-- The box listing everything new
		local titles = {}
		for _, section in update.Sections do
			table.insert(titles, section.Title)
		end
		local box = Theme.new("Frame", {
			Size = UDim2.new(1, -60, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = rgb(0, 0, 0),
			BackgroundTransparency = 0.55,
		}, { Theme.Corner(10), Theme.Stroke(2, Theme.Darken(accent, 0.4)), Theme.Padding(12) })
		text({ Text = table.concat(titles, `  <font color="{hex(accent)}">✦</font>  `), RichText = true, TextSize = 22, LineHeight = 1.1, Size = UDim2.fromScale(1, 0), StrokeThickness = 2, Parent = box })
		add(Theme.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 6) }))
		add(box)
		add(Theme.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 10) }))
		for _, section in update.Sections do
			add(Theme.Label({ Text = section.Title, TextColor3 = accent, Size = UDim2.new(1, -30, 0, 34), StrokeThickness = 3 }))
			add(Theme.Label({ Text = section.Tag, Font = Theme.Font, TextColor3 = rgb(200, 195, 215), Size = UDim2.new(1, -30, 0, 22), StrokeThickness = 2 }))
			for _, line in section.Lines do
				add(text({ Text = "• " .. line, TextSize = 21, Size = UDim2.new(1, -60, 0, 0), StrokeThickness = 2 }))
			end
			add(Theme.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 10) }))
		end

		-- Right column: groups of cards
		local cardOrder = 0
		local firstModel: Model? = nil
		for _, group in update.Sidebar do
			cardOrder += 1
			Theme.Label({ Text = group.Title, TextColor3 = accent, Size = UDim2.new(1, -16, 0, 30), StrokeThickness = 3, LayoutOrder = cardOrder, Parent = cards })
			cardOrder += 1
			local grid = Theme.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = cardOrder, Parent = cards }, {
				Theme.new("UIGridLayout", { CellSize = UDim2.fromOffset(112, 112), CellPadding = UDim2.fromOffset(8, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
			})
			for i, item in group.Items do
				local model, name, rarity, color = describe(item)
				local card = Theme.new("Frame", { LayoutOrder = i, Parent = grid }, {
					Theme.Corner(12),
					Theme.Stroke(3, Theme.Lighten(color, 0.35)),
					Theme.Gradient(Theme.Lighten(color, 0.1), Theme.Darken(color, 0.55)),
				})
				Theme.Label({ Text = string.upper(rarity), TextColor3 = Theme.Lighten(color, 0.5), TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(7, 4), Size = UDim2.new(0.8, 0, 0, 15), StrokeThickness = 1.5, ZIndex = 3, Parent = card })
				Theme.Label({ Text = name, Font = Theme.Font, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, -8, 0, 30), StrokeThickness = 2, ZIndex = 3, Parent = card })
				if model then
					if not firstModel then
						firstModel = model:Clone()
					end
					local viewport = Theme.new("ViewportFrame", {
						BackgroundTransparency = 1,
						Ambient = rgb(190, 185, 205),
						LightColor = rgb(255, 255, 255),
						LightDirection = Vector3.new(-0.5, -1, 0.8),
						Position = UDim2.fromOffset(4, 10),
						Size = UDim2.new(1, -8, 1, -30),
						ZIndex = 2,
						Parent = card,
					})
					table.insert(spinners, stage(viewport, model, 1.6))
				end
			end
		end
		if firstModel then
			table.insert(spinners, stage(backdrop, firstModel, 1.2))
		end
		scroll.CanvasPosition = Vector2.zero
		cards.CanvasPosition = Vector2.zero
	end

	-- The models sway gently while the window is open
	RunService.RenderStepped:Connect(function()
		if not modal:IsOpen() then
			return
		end
		local t = os.clock()
		for _, spinner in spinners do
			local angle = math.sin(t * 0.8 + spinner.Phase) * 0.6
			spinner.Camera.CFrame = CFrame.lookAt(Vector3.new(math.sin(angle) * spinner.Distance, spinner.Height, -math.cos(angle) * spinner.Distance), Vector3.zero)
		end
	end)

	-- Joining after a new update: show it once (brand-new players get the tutorial instead)
	local checked = false
	State.Changed:Connect(function(snapshot)
		if checked then
			return
		end
		checked = true
		if (snapshot.SeenUpdate or 0) >= Notes.Latest then
			return
		end
		State.Action("SeenUpdate", Notes.Latest)
		if snapshot.SeenTutorial ~= false and snapshot.NotesOnLogin ~= false then
			task.delay(1.5, function()
				if not Modal.AnyOpen() then
					UpdateNotes.Open()
				end
			end)
		end
	end)
end

return UpdateNotes
