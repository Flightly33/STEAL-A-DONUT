--[[
	Donut Index: every donut in the game grouped by area, with 3D previews.
	Donuts you haven't stolen yet show as black silhouettes named "???".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local Donuts = require(Shared.Donuts)
local Rarities = require(Shared.Rarities)
local Format = require(Shared.Format)
local DonutModel = require(Shared.DonutModel)

local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local State = require(script.Parent.Parent.State)

local Index = {}

local modal: Modal.Modal
local built = false
local cards: { [string]: { Viewport: ViewportFrame, Name: TextLabel, Info: TextLabel, Rarity: TextLabel } } = {}
local counter: TextLabel

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
	if not built then
		return
	end
	local discovered = State.Data.Discovered or {}
	local found = 0
	for id, card in cards do
		local donut = Donuts.ById[id]
		local rarity = Rarities.Get(donut.Rarity)
		if discovered[id] then
			found += 1
			card.Viewport.ImageColor3 = Color3.new(1, 1, 1)
			card.Name.Text = donut.Name
			card.Info.Text = `{Format.Money(donut.Income)}/s`
		else
			card.Viewport.ImageColor3 = Color3.new(0, 0, 0)
			card.Name.Text = "???"
			card.Info.Text = "Not found yet"
		end
		card.Rarity.Text = `{rarity.Id} • {string.format("%.2g", Donuts.Chance(donut) * 100)}%`
	end
	counter.Text = `Discovered {found}/{#Donuts.List}`
end

local function build()
	built = true
	local scroll = Theme.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 1, -40),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 8,
		Parent = modal.Body,
	}, {
		Theme.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		Theme.new("UIPadding", { PaddingRight = UDim.new(0, 12), PaddingLeft = UDim.new(0, 2), PaddingBottom = UDim.new(0, 10) }),
	})

	for areaId, area in Areas.List do
		local section = Theme.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = areaId, Parent = scroll })
		Theme.Label({ Text = `AREA {areaId} • {string.upper(area.Name)}`, TextColor3 = area.Trim:Lerp(Color3.new(1, 1, 1), 0.3), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 30), Parent = section })
		local grid = Theme.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = section }, {
			Theme.new("UIGridLayout", { CellSize = UDim2.fromOffset(160, 176), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		local areaDonuts: { Donuts.Donut } = Donuts.ByArea[areaId] or {}
		for order, donut in areaDonuts do
			local rarity = Rarities.Get(donut.Rarity)
			local cardFrame = Theme.new("Frame", { BackgroundColor3 = Theme.Colors.PanelLight, LayoutOrder = order, Parent = grid }, {
				Theme.Corner(12),
				Theme.Stroke(3, rarity.Color),
			})
			local viewport = preview(cardFrame, donut)
			local rarityLabel = Theme.Label({ Text = rarity.Id, TextColor3 = rarity.Color, Font = Theme.Font, Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromOffset(4, 104), StrokeThickness = 1.5, Parent = cardFrame })
			local nameLabel = Theme.Label({ Text = "", Font = Theme.Font, Size = UDim2.new(1, -8, 0, 30), Position = UDim2.fromOffset(4, 122), StrokeThickness = 1.5, Parent = cardFrame })
			local info = Theme.Label({ Text = "", Font = Theme.Font, TextColor3 = Theme.Colors.Money, Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromOffset(4, 153), StrokeThickness = 1.2, Parent = cardFrame })
			cards[donut.Id] = { Viewport = viewport, Name = nameLabel, Info = info, Rarity = rarityLabel }
		end
	end
end

function Index.Open()
	modal:Open()
end

function Index.Init()
	modal = Modal.new("📖 DONUT INDEX", Theme.Colors.Blue, Vector2.new(760, 520))
	counter = Theme.Label({ Text = "", Font = Theme.Font, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 30), Parent = modal.Body })
	modal.OnOpen = function()
		if not built then
			build() -- previews are built the first time the Index is opened
		end
		refresh()
	end
	State.Changed:Connect(refresh)
end

return Index
