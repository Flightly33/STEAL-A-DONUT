--[[
	Tutorial: a short "how to play" window, shown once on a player's first join (saved as
	SeenTutorial) and any time from Settings > How to play.

	Four pages, each with a coloured picture card (a spinning 3D donut / Domer, or a big icon) and one
	or two lines of text, plus progress dots, Back / Next and Skip.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Donuts = require(Shared.Donuts)
local DonutModel = require(Shared.DonutModel)
local GuardModel = require(Shared.GuardModel)
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local State = require(script.Parent.Parent.State)

local Tutorial = {}

type Page = { Icon: string, Title: string, Text: string, Color: Color3, Model: string? }

local PAGES: { Page } = {
	{ Icon = "🍩", Title = "GRAB DONUTS", Text = "Run into the donut lane, walk up to a donut and press Steal to grab it.", Color = Theme.Colors.Pink, Model = "Donut" },
	{ Icon = "🏃", Title = "RUN HOME!", Text = `{Config.Guard.Name} wakes up and chases you! Get the donut back to your base before he catches you.`, Color = Theme.Colors.Red, Model = "Guard" },
	{ Icon = "💰", Title = "GET RICH", Text = "Donuts on your base make money every second. Run on your treadmill to get faster, then go for rarer donuts!", Color = Theme.Colors.Green },
	{ Icon = "😈", Title = "STEAL & DEFEND", Text = "Sneak into other bases and steal their donuts. Use a Base Lock to keep yours safe!", Color = Theme.Colors.Purple },
}

local modal: Modal.Modal
local page = 1
local render: () -> ()

function Tutorial.Open()
	page = 1
	render()
	modal:Open()
end

-- A 3D model in a ViewportFrame (hidden until its page is shown); returns its camera.
local function showcase(parent: Instance, model: Model, distance: number, height: number): (Camera, ViewportFrame)
	local viewport = Theme.new("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(180, 180, 190),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-0.5, -1, 0.8),
		Visible = false,
		Parent = parent,
	})
	model.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	camera.CFrame = CFrame.lookAt(Vector3.new(0, height, -distance), Vector3.new(0, height, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return camera, viewport
end

function Tutorial.Init()
	modal = Modal.new("❓ HOW TO PLAY", Theme.Colors.Blue, Vector2.new(500, 440))
	local body = modal.Body

	-- Picture card: the 3D model or a big icon on the page's colour
	local card = Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 170),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = body,
	}, { Theme.Corner(14), Theme.Stroke(3) })
	local cardGradient = Theme.new("UIGradient", { Rotation = 90, Parent = card })
	local icon = Theme.Label({ Text = "", Font = Enum.Font.GothamBold, TextScaled = false, TextSize = 96, Size = UDim2.fromScale(1, 1), Parent = card })

	local donutCamera: Camera? = nil
	local donutView: ViewportFrame? = nil
	local guardView: ViewportFrame? = nil
	local guardCamera: Camera? = nil
	local guardDistance, guardHeight = 10, 3
	local showcaseDonut = Donuts.ById["sprinkolini"] or Donuts.List[1]
	local okDonut, donutModel = pcall(DonutModel.Build, showcaseDonut, { NoEffects = true })
	if okDonut then
		donutCamera, donutView = showcase(card, donutModel, 12, 0.3)
	end
	local okGuard, guardModel = pcall(function(): Model
		local model = GuardModel.Build(1, {})
		return model
	end)
	if okGuard then
		local model = guardModel :: Model
		local box, size = model:GetBoundingBox()
		model:PivotTo(model:GetPivot() - box.Position) -- centre him on the origin
		guardDistance, guardHeight = size.Y * 1.7, 0
		guardCamera, guardView = showcase(card, model, guardDistance, guardHeight)
	end

	local title = Theme.Label({ Text = "", Size = UDim2.new(1, 0, 0, 42), Position = UDim2.fromOffset(0, 180), StrokeThickness = 3.5, Parent = body })
	local text = Theme.Label({ Text = "", Font = Theme.Font, TextScaled = false, TextSize = 21, TextWrapped = true, Size = UDim2.new(1, -24, 0, 64), Position = UDim2.fromOffset(12, 224), StrokeThickness = 2, Parent = body })

	-- Progress dots (the current page is a longer yellow pill)
	local dots = Theme.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 294), Size = UDim2.fromOffset(160, 14), Parent = body }, {
		Theme.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local dotFrames: { Frame } = {}
	for i = 1, #PAGES do
		table.insert(dotFrames, Theme.new("Frame", { Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Theme.Colors.Gray, LayoutOrder = i, Parent = dots }, { Theme.new("UICorner", { CornerRadius = UDim.new(1, 0) }), Theme.Stroke(2) }))
	end

	local back = Theme.Button({ Text = "◀ BACK", Color = Theme.Colors.Gray, Size = UDim2.new(0.3, -6, 0, 50), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Parent = body })
	local skip = Theme.Button({ Text = "Skip", Color = Theme.Colors.Gray, Size = UDim2.new(0.22, -6, 0, 50), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.41, 0, 1, 0), Parent = body })
	local nextButton = Theme.Button({ Text = "", Color = Theme.Colors.Green, Size = UDim2.new(0.46, -6, 0, 50), AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Parent = body })
	local pop = Theme.new("UIScale", { Name = "Pop", Parent = card })

	render = function()
		local p = PAGES[page]
		title.Text = p.Title
		title.TextColor3 = p.Color:Lerp(Color3.new(1, 1, 1), 0.35)
		text.Text = p.Text
		cardGradient.Color = ColorSequence.new(p.Color:Lerp(Color3.new(1, 1, 1), 0.35), p.Color:Lerp(Color3.new(0, 0, 0), 0.25))
		-- the 3D model if this page has one, otherwise the big icon
		local showDonut = p.Model == "Donut" and donutView ~= nil
		local showGuard = p.Model == "Guard" and guardView ~= nil
		if donutView then
			donutView.Visible = showDonut
		end
		if guardView then
			guardView.Visible = showGuard
		end
		icon.Visible = not (showDonut or showGuard)
		icon.Text = p.Icon
		for i, dot in dotFrames do
			dot.BackgroundColor3 = if i == page then Theme.Colors.Yellow else Theme.Colors.Gray
			dot.Size = if i == page then UDim2.fromOffset(28, 14) else UDim2.fromOffset(14, 14)
		end
		back.Visible = page > 1
		skip.Visible = page < #PAGES
		Theme.SetButtonText(nextButton, if page < #PAGES then "NEXT ▶" else "LET'S GO! 🍩")
		pop.Scale = 0.92
		TweenService:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end

	back.Activated:Connect(function()
		page = math.max(1, page - 1)
		render()
	end)
	skip.Activated:Connect(function()
		modal:Close()
	end)
	nextButton.Activated:Connect(function()
		if page < #PAGES then
			page += 1
			render()
		else
			modal:Close()
		end
	end)

	-- Turn the 3D models slowly while the window is open
	RunService.RenderStepped:Connect(function()
		if not modal:IsOpen() then
			return
		end
		local angle = os.clock() * 0.9
		if donutCamera then
			donutCamera.CFrame = CFrame.lookAt(Vector3.new(math.sin(angle) * 12, 0.8, -math.cos(angle) * 12), Vector3.new(0, 0.3, 0))
		end
		if guardCamera then
			local a = angle * 0.6
			guardCamera.CFrame = CFrame.lookAt(Vector3.new(math.sin(a) * guardDistance, guardHeight, -math.cos(a) * guardDistance), Vector3.new(0, guardHeight, 0))
		end
	end)

	-- First join: show it once the saved data arrives, and remember it's been seen
	local checked = false
	State.Changed:Connect(function(snapshot)
		if checked then
			return
		end
		checked = true
		if snapshot.SeenTutorial == false then
			State.Action("SeenTutorial")
			Tutorial.Open()
		end
	end)
	render()
end

return Tutorial
