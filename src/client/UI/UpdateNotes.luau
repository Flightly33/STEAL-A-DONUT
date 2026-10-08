--[[
	UpdateNotes: the Update Log window (the notes themselves are in Shared/UpdateNotes).

	  * the corner emblem: a 3D donut in the update's colours on a turning wheel (UpdateDecor), a
	    ribbon tab "Update Log", an "Update N" picker
	    and a round close button along the top
	  * left: the game's logo, the update's name, "Update N Patch Notes", a box listing everything new,
	    then each section (heading, tag and bullet lines) with a gem divider between them, over a big
	    faded model, the update's floating decorations, corner swirls and a soft glow
	  * right: groups of new things as cards with spinning 3D models of the real donuts / pets / eggs
	    (built from the game's own models, so there are no images to upload). Hover a card (tap it
	    on a phone) for its details card (ItemCard).
	Everything (window border, ribbon, panels, emblem, decorations) takes the update's own colours.

	It opens every time a player joins (after the "Welcome back" window if there is one). On a
	player's first visit the tutorial starts once they close it. The UPDATES button on the side and
	Settings > Update Log open it any time.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Notes = require(Shared.UpdateNotes)
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local ItemCard = require(script.Parent.ItemCard)
local UpdateDecor = require(script.Parent.UpdateDecor)
local State = require(script.Parent.Parent.State)

local UpdateNotes = {}

local WIDTH, HEIGHT = 900, 540
local SIDEBAR = 256
local EMBLEM = 132
local rgb = Color3.fromRGB

type Spinner = { Camera: Camera, Distance: number, Height: number, Phase: number }

local modal: Modal.Modal
local show: (version: number) -> ()

-- The log that opens on joining: things that wait for it to be closed (the first-join tutorial)
local joinShown = false
local joinDone = false
local joinWaiters: { () -> () } = {}
local function finishJoin()
	if joinDone then
		return
	end
	joinDone = true
	for _, waiter in joinWaiters do
		task.spawn(waiter)
	end
	table.clear(joinWaiters)
end

-- Runs `callback` once the Update Log that opened on joining has been closed (right away if it
-- already was).
function UpdateNotes.AfterJoinLog(callback: () -> ())
	if joinDone then
		task.spawn(callback)
	else
		table.insert(joinWaiters, callback)
	end
end

function UpdateNotes.Open(version: number?)
	show(version or Notes.Latest)
	modal:Open()
end

local function text(props: { [string]: any }): TextLabel
	props.Font = props.Font or Theme.Font
	props.TextScaled = false
	props.TextWrapped = true
	props.AutomaticSize = Enum.AutomaticSize.Y
	return Theme.Label(props)
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

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") and not child:IsA("UIStroke") and not child:IsA("UIGradient") then
			child:Destroy()
		end
	end
end

function UpdateNotes.Init()
	ItemCard.Init()
	modal = Modal.new("Update Log", Theme.Colors.Orange, Vector2.new(WIDTH, HEIGHT))
	local frame = modal.Frame
	-- Our own top bar instead of the usual window header
	local header = frame:FindFirstChild("Header")
	if header and header:IsA("GuiObject") then
		header.Visible = false
	end
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	local windowGradient = frame:FindFirstChildOfClass("UIGradient") or Theme.new("UIGradient", { Parent = frame })
	windowGradient.Rotation = 90
	modal.Body.Position = UDim2.new()
	modal.Body.Size = UDim2.fromScale(1, 1)
	local body = modal.Body

	-- Left: the patch notes, over a big faded model and the update's decorations
	local left = Theme.new("Frame", {
		Name = "Notes",
		Position = UDim2.fromOffset(12, 64),
		Size = UDim2.new(1, -(SIDEBAR + 34), 1, -76),
		BackgroundColor3 = Color3.new(1, 1, 1),
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
		ZIndex = 1,
		Parent = left,
	})
	local decor = Theme.new("Frame", { Name = "Decor", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = left })
	local scroll = Theme.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ZIndex = 3,
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
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = body,
	}, { Theme.Corner(12), Theme.Stroke(3) })
	local rightGradient = Theme.new("UIGradient", { Rotation = 90, Parent = right })
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

	-- Top bar
	local topBar = Theme.new("Frame", { Name = "TopBar", Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = body }, { Theme.Corner(18) })
	local topGradient = Theme.new("UIGradient", { Rotation = 90, Parent = topBar })

	-- The glowing border, in the update's colours (it slowly runs round the window)
	local border = Theme.new("Frame", {
		Name = "Border",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
		ZIndex = 2,
		Parent = body,
	}, { Theme.Corner(16) })
	local borderStroke = Theme.new("UIStroke", { Thickness = 3, Color = Color3.new(1, 1, 1), Parent = border })
	local borderGradient = Theme.new("UIGradient", { Parent = borderStroke })

	-- The ribbon tab, with a pointed end
	local ribbon = Theme.new("Frame", {
		Name = "Ribbon",
		Position = UDim2.fromOffset(-30, -24),
		Size = UDim2.fromOffset(380, 70),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 4,
		Parent = body,
	}, { Theme.Corner(12), Theme.Stroke(3.5) })
	local ribbonGradient = Theme.new("UIGradient", { Rotation = 90, Parent = ribbon })
	local tip = Theme.new("Frame", {
		Name = "Tip",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 350, 0, 11),
		Size = UDim2.fromOffset(48, 48),
		Rotation = 45,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
		Parent = body,
	}, { Theme.Corner(6), Theme.Stroke(3.5) })
	local tipGradient = Theme.new("UIGradient", { Rotation = 45, Parent = tip })
	local ribbonTrim = Theme.new("Frame", { Name = "Trim", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 96, 1, -7), Size = UDim2.new(1, -120, 0, 3), BorderSizePixel = 0, ZIndex = 5, Parent = ribbon }, {
		Theme.new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2), NumberSequenceKeypoint.new(1, 1) }) }),
	})
	Theme.Label({ Text = "Update Log", TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(104, 10), Size = UDim2.new(1, -120, 0, 46), StrokeThickness = 3.5, ZIndex = 6, Parent = ribbon })
	local ribbonDecor = Theme.new("Frame", { Name = "Decor", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, ZIndex = 5, Parent = ribbon })

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
		local option = Theme.Button({ Text = `Update {update.Version}`, Color = update.Color, Size = UDim2.new(1, 0, 0, 36), Parent = menu })
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

	local spinners: { Spinner } = {}
	local steps: { UpdateDecor.Step } = {}
	local emblem: Frame? = nil
	show = function(version: number)
		local update = Notes.Get(version) or Notes.List[1]
		local color, accent = update.Color, update.Accent
		local style = UpdateDecor.Style(update)
		menu.Visible = false
		ItemCard.Hide()
		table.clear(spinners)
		table.clear(steps)
		clear(scroll)
		clear(cards)
		clear(decor)
		clear(ribbonDecor)
		backdrop:ClearAllChildren()
		Theme.SetButtonText(versionButton, `▼ Update {update.Version}`)

		-- Colours: everything takes the update's theme
		windowGradient.Color = ColorSequence.new(Theme.Darken(color, 0.55), Theme.Darken(color, 0.85))
		leftGradient.Color = ColorSequence.new(Theme.Lighten(color, 0.12), Theme.Darken(color, 0.45))
		rightGradient.Color = ColorSequence.new(Theme.Darken(color, 0.6), rgb(8, 7, 14))
		topGradient.Color = ColorSequence.new(Theme.Darken(color, 0.5), Theme.Darken(color, 0.78))
		ribbonGradient.Color = ColorSequence.new(Theme.Lighten(color, 0.25), Theme.Darken(color, 0.15))
		tipGradient.Color = ColorSequence.new(Theme.Lighten(color, 0.1), Theme.Darken(color, 0.2))
		ribbonTrim.BackgroundColor3 = accent
		borderGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, accent),
			ColorSequenceKeypoint.new(0.25, Theme.Lighten(color, 0.35)),
			ColorSequenceKeypoint.new(0.5, Theme.Lighten(accent, 0.4)),
			ColorSequenceKeypoint.new(0.75, Theme.Lighten(color, 0.35)),
			ColorSequenceKeypoint.new(1, accent),
		})
		Theme.SetButtonColor(versionButton, Theme.Darken(color, 0.2))

		-- The corner emblem and the decorations
		if emblem then
			emblem:Destroy()
		end
		local badge, emblemStep = UpdateDecor.Emblem(body, update, EMBLEM, 6)
		badge.Position = UDim2.fromOffset(-58, -52)
		emblem = badge
		table.insert(steps, emblemStep)
		table.insert(steps, UpdateDecor.Glow(decor, style.Glow or accent, 150, 0.45, 2))
		local swirlA = UpdateDecor.Swirl(decor, UDim2.fromScale(0, 1), 230, accent, 0.7, 2)
		local swirlB = UpdateDecor.Swirl(decor, UDim2.fromScale(1, 0), 190, accent, 0.72, 2)
		if style.Spin then
			table.insert(steps, swirlA)
			table.insert(steps, swirlB)
		end
		table.insert(steps, UpdateDecor.Rays(decor, UDim2.new(0.5, 0, 0, 120), 300, 10, Theme.Lighten(accent, 0.3), 0.82, 2))
		table.insert(steps, UpdateDecor.Motes(decor, update, 2))
		UpdateDecor.Swirl(ribbonDecor, UDim2.new(1, -36, 0.5, 0), 70, accent, 0.65, 5)

		-- Left column
		local order = 0
		local function add(instance: GuiObject)
			order += 1
			instance.LayoutOrder = order
			instance.Parent = scroll
		end
		local logo = Theme.Label({ Text = "STEAL A DONUT", Size = UDim2.new(1, -30, 0, 70), StrokeThickness = 5 })
		Theme.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(rgb(255, 255, 255), Theme.Lighten(accent, 0.55)), Parent = logo })
		add(logo)
		local title = Theme.Label({ Text = update.Name, TextColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, -30, 0, 50), StrokeThickness = 4 })
		Theme.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Theme.Lighten(accent, 0.45), Theme.Darken(accent, 0.1)), Parent = title })
		add(title)
		add(Theme.Label({ Text = `Update {update.Version} Patch Notes  •  {update.Date}`, Font = Theme.Font, TextColor3 = rgb(225, 220, 235), Size = UDim2.new(1, -30, 0, 24), StrokeThickness = 2 }))
		-- The box listing everything new
		local titles = {}
		for _, section in update.Sections do
			table.insert(titles, section.Title)
		end
		local box = Theme.new("Frame", {
			Size = UDim2.new(1, -60, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.4,
		}, {
			Theme.Corner(10),
			Theme.Stroke(2.5, Theme.Darken(accent, 0.3)),
			Theme.Padding(12),
			Theme.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Theme.Darken(color, 0.55), rgb(0, 0, 0)) }),
		})
		text({ Text = table.concat(titles, `  <font color="#{accent:ToHex()}"></font>  `), RichText = true, TextSize = 22, LineHeight = 1.1, Size = UDim2.fromScale(1, 0), StrokeThickness = 2, Parent = box })
		add(Theme.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 6) }))
		add(box)
		add(Theme.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 8) }))
		for _, section in update.Sections do
			add(UpdateDecor.Divider(accent, 300))
			local heading = Theme.Label({ Text = section.Title, TextColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, -30, 0, 34), StrokeThickness = 3 })
			Theme.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Theme.Lighten(accent, 0.35), accent), Parent = heading })
			add(heading)
			add(Theme.Label({ Text = string.upper(section.Tag), Font = Theme.Font, TextColor3 = Theme.Lighten(color, 0.6), Size = UDim2.new(1, -30, 0, 20), StrokeThickness = 2 }))
			for _, line in section.Lines do
				add(text({ Text = `<font color="#{accent:ToHex()}">•</font> {line}`, RichText = true, TextSize = 21, Size = UDim2.new(1, -60, 0, 0), StrokeThickness = 2 }))
			end
			add(Theme.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 8) }))
		end

		-- Right column: groups of cards (hover one for its details)
		local cardOrder = 0
		local firstModel: Model? = nil
		for _, group in update.Sidebar do
			cardOrder += 1
			local groupTitle = Theme.Label({ Text = group.Title, TextColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, -16, 0, 30), StrokeThickness = 3, LayoutOrder = cardOrder, Parent = cards })
			Theme.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Theme.Lighten(accent, 0.35), accent), Parent = groupTitle })
			cardOrder += 1
			local grid = Theme.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -12, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = cardOrder, Parent = cards }, {
				Theme.new("UIGridLayout", { CellSize = UDim2.fromOffset(112, 112), CellPadding = UDim2.fromOffset(8, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
			})
			for i, item in group.Items do
				local info = ItemCard.Describe(item)
				local model = ItemCard.Model(item)
				local itemColor = info.Color
				local card = Theme.new("Frame", { Name = "Card", LayoutOrder = i, BackgroundColor3 = Color3.new(1, 1, 1), Parent = grid }, {
					Theme.Corner(12),
					Theme.Gradient(Theme.Lighten(itemColor, 0.1), Theme.Darken(itemColor, 0.55)),
				})
				local cardStroke = Theme.Stroke(3, Theme.Lighten(itemColor, 0.35))
				cardStroke.Parent = card
				Theme.Label({ Text = string.upper(info.Rarity), TextColor3 = Theme.Lighten(itemColor, 0.5), TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(7, 4), Size = UDim2.new(0.8, 0, 0, 15), StrokeThickness = 1.5, ZIndex = 3, Parent = card })
				Theme.Label({ Text = info.Name, Font = Theme.Font, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, -8, 0, 30), StrokeThickness = 2, ZIndex = 3, Parent = card })
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
				-- Hover (or tap) for the details card; the card lights up while you do
				local hit = Theme.new("TextButton", { Name = "Hover", Text = "", BackgroundTransparency = 1, AutoButtonColor = false, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = card })
				ItemCard.Attach(hit, item, function(on: boolean)
					cardStroke.Color = if on then Theme.Lighten(itemColor, 0.75) else Theme.Lighten(itemColor, 0.35)
					cardStroke.Thickness = if on then 4.5 else 3
				end)
			end
		end
		if firstModel then
			table.insert(spinners, stage(backdrop, firstModel, 1.2))
		end
		scroll.CanvasPosition = Vector2.zero
		cards.CanvasPosition = Vector2.zero
	end

	-- The models sway and the decorations move while the window is open
	local started = os.clock()
	local last = started
	RunService.RenderStepped:Connect(function()
		if not modal:IsOpen() then
			return
		end
		local now = os.clock()
		local t, dt = now - started, math.min(now - last, 0.1)
		last = now
		for _, spinner in spinners do
			local angle = math.sin(t * 0.8 + spinner.Phase) * 0.6
			spinner.Camera.CFrame = CFrame.lookAt(Vector3.new(math.sin(angle) * spinner.Distance, spinner.Height, -math.cos(angle) * spinner.Distance), Vector3.zero)
		end
		for _, step in steps do
			step(t, dt)
		end
		borderGradient.Rotation = (t * 40) % 360
	end)

	-- Every join: the log opens as soon as the screen is free (the "Welcome back" offline earnings
	-- arrive together with the save, and only one window shows at a time). Brand-new players see
	-- it too; their tutorial starts once they close it (UpdateNotes.AfterJoinLog).
	modal.OnClose = function()
		if joinShown then
			finishJoin()
		end
	end
	local checked = false
	State.Changed:Connect(function(snapshot)
		if checked then
			return
		end
		checked = true
		if (snapshot.SeenUpdate or 0) < Notes.Latest then
			State.Action("SeenUpdate", Notes.Latest)
		end
		task.spawn(function()
			-- wait for the loading screen to finish first
			local player = game:GetService("Players").LocalPlayer
			local loading = 0
			while player:GetAttribute("LoadingScreen") and loading < 60 do
				task.wait(0.25)
				loading += 0.25
			end
			task.wait(1.5)
			local waited = 0
			while Modal.AnyOpen() and waited < 600 do
				task.wait(0.5)
				waited += 0.5
			end
			if Modal.AnyOpen() then
				finishJoin() -- (somebody's been in a window for 10 minutes: don't hold the tutorial)
				return
			end
			joinShown = true
			UpdateNotes.Open()
		end)
	end)
end

return UpdateNotes
