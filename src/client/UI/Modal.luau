--[[
	Modal: a centred pop-up window (Shop, Index, Leaderboards...). Only one is open at a time.

	Every window looks the same: an orange header with the stud pattern and two streaks of light,
	its title in big white outlined letters (and a gold count after it, SetCount: "Index (12/88)"),
	a red X, and a dark green body with faint studs. (The studs are drawn the first time the window
	opens, so windows nobody opens cost nothing.) A window can pick other colours (Modal.Style):
	Daily Rewards is dark grey all over.
]]

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Modal = {}
Modal.__index = Modal

export type Modal = {
	Style: Style,
	Frame: Frame,
	Body: Frame,
	Title: TextLabel,
	Count: TextLabel,
	Size: Vector2,
	Studded: boolean,
	OnOpen: (() -> ())?,
	OnClose: (() -> ())?,
	Open: (self: Modal) -> (),
	Close: (self: Modal) -> (),
	Toggle: (self: Modal) -> (),
	IsOpen: (self: Modal) -> boolean,
	SetCount: (self: Modal, text: string?) -> (),
}

local HEADER = 58

-- Other colours for a window (anything left out stays as usual).
export type Style = {
	HeaderTop: Color3?,
	HeaderBottom: Color3?,
	HeaderStuds: Color3?,
	BodyTop: Color3?,
	BodyBottom: Color3?,
}

local gui: ScreenGui? = nil
local current: Modal? = nil

local function getGui(): ScreenGui
	if not gui then
		gui = Theme.ScreenGui("Modals", 10)
	end
	return gui :: ScreenGui
end

-- (`_color` is from before every window had the same orange header.)
function Modal.new(title: string, _color: Color3, size: Vector2, style: Style?): Modal
	local look: Style = style or {}
	local headerBottom = look.HeaderBottom or Theme.Colors.HeaderBottom
	local holder = Theme.new("Frame", {
		Name = title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		Parent = getGui(),
	}, {
		Theme.Corner(12),
		Theme.Stroke(4),
		Theme.Gradient(look.BodyTop or Theme.Colors.Window, look.BodyBottom or Theme.Colors.WindowDark),
	})
	Theme.AutoScale(holder) -- (only one UIScale per object works, so the open "pop" tweens this one too)

	local header = Theme.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, HEADER),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Parent = holder,
	}, {
		Theme.Corner(12),
		Theme.Gradient(look.HeaderTop or Theme.Colors.HeaderTop, headerBottom),
	})
	-- Square off the header's bottom corners, with a dark line under it
	Theme.new("Frame", { Name = "Square", Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14), BackgroundColor3 = headerBottom, BorderSizePixel = 0, Parent = header })
	Theme.new("Frame", { Name = "Line", Size = UDim2.new(1, 0, 0, 4), Position = UDim2.fromOffset(0, HEADER - 2), BackgroundColor3 = Theme.Colors.Outline, BorderSizePixel = 0, ZIndex = 3, Parent = holder })
	-- two streaks of light across it, behind the title
	for i, streak in { { X = 150, W = 26 }, { X = 188, W = 12 } } do
		Theme.new("Frame", {
			Name = "Streak" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, streak.X, 0.5, 0),
			Size = UDim2.fromOffset(streak.W, HEADER * 2),
			Rotation = 24,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.72,
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = header,
		})
	end

	local titleRow = Theme.new("Frame", {
		Name = "TitleRow",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 4),
		Size = UDim2.new(1, -90, 1, -8),
		ZIndex = 3,
		Parent = header,
	}, {
		Theme.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local titleLabel = Theme.Label({ Name = "Title", Text = title, TextScaled = false, TextSize = 40, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), StrokeThickness = 3.5, ZIndex = 3, LayoutOrder = 1, Parent = titleRow })
	local count = Theme.Label({ Name = "Count", Text = "", TextColor3 = Theme.Colors.Gold, TextScaled = false, TextSize = 34, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), StrokeThickness = 3, ZIndex = 3, LayoutOrder = 2, Visible = false, Parent = titleRow })

	local close = Theme.Button({ Name = "Close", Text = "X", Color = Theme.Colors.Red, Size = UDim2.fromOffset(46, 46), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 6), Parent = header })
	close.ZIndex = 3

	local body = Theme.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, HEADER + 10),
		Size = UDim2.new(1, -28, 1, -(HEADER + 22)),
		ZIndex = 2,
		Parent = holder,
	})

	local self = setmetatable({ Style = look, Frame = holder, Body = body, Title = titleLabel, Count = count, Size = size, Studded = false, OnOpen = nil, OnClose = nil }, Modal) :: any
	close.Activated:Connect(function()
		self:Close()
	end)
	return self
end

-- "(12/88)" in gold after the title (nil: none).
function Modal.SetCount(self: Modal, text: string?)
	self.Count.Text = text or ""
	self.Count.Visible = text ~= nil and text ~= ""
end

-- The studs: on the header, and faintly on the body (the first time the window opens).
local function addStuds(self: Modal)
	if self.Studded then
		return
	end
	self.Studded = true
	local header = self.Frame:FindFirstChild("Header") :: Frame
	local headerStuds = Theme.Studs(header, Vector2.new(self.Size.X, HEADER), { Cell = 22, Color = self.Style.HeaderStuds or Color3.fromRGB(150, 70, 0), Transparency = 0.72 })
	headerStuds.ZIndex = 1
	local area = Theme.new("Frame", {
		Name = "BodyStuds",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(0, HEADER),
		Size = UDim2.new(1, 0, 1, -HEADER),
		ZIndex = 1,
		Parent = self.Frame,
	})
	Theme.Studs(area, Vector2.new(self.Size.X, self.Size.Y - HEADER), { Cell = 30, Transparency = 0.86 })
end

function Modal.Open(self: Modal)
	if current and current ~= self then
		current:Close()
	end
	current = self
	addStuds(self)
	if not self.Frame.Visible and Theme.SinceKeyPress() > 0.4 then
		Theme.PlaySound("Open") -- (opened with a button, the button's click is enough)
	end
	local scale = self.Frame:FindFirstChild("AutoScale") :: UIScale
	local target = Theme.CurrentScale()
	scale.Scale = target * 0.85
	self.Frame.Visible = true
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = target }):Play()
	if self.OnOpen then
		task.spawn(self.OnOpen)
	end
end

function Modal.Close(self: Modal)
	local wasOpen = self.Frame.Visible
	self.Frame.Visible = false
	if current == self then
		current = nil
	end
	if wasOpen and self.OnClose then
		task.spawn(self.OnClose)
	end
end

function Modal.Toggle(self: Modal)
	if self.Frame.Visible then
		self:Close()
	else
		self:Open()
	end
end

-- Is any window open right now?
function Modal.AnyOpen(): boolean
	return current ~= nil and current.Frame.Visible
end

function Modal.IsOpen(self: Modal): boolean
	return self.Frame.Visible
end

-- Row of tab buttons; returns a function to select a tab by name.
function Modal.Tabs(parent: Instance, tabs: { { Name: string, Text: string, Color: Color3 } }, onSelect: (string) -> ()): (string) -> ()
	local bar = Theme.new("Frame", { Name = "Tabs", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Parent = parent }, {
		Theme.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local buttons: { [string]: TextButton } = {}
	local function select(name: string)
		for tabName, button in buttons do
			local tab
			for _, t in tabs do
				if t.Name == tabName then
					tab = t
				end
			end
			Theme.SetButtonColor(button, if tabName == name then tab.Color else Theme.Colors.Gray)
		end
		onSelect(name)
	end
	for i, tab in tabs do
		local button = Theme.Button({ Text = tab.Text, Color = tab.Color, Size = UDim2.new(1 / #tabs, -8, 1, 0), LayoutOrder = i, Parent = bar })
		buttons[tab.Name] = button
		button.Activated:Connect(function()
			select(tab.Name)
		end)
	end
	return select
end

return Modal
