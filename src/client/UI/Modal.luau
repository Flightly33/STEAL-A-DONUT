--[[
	Modal: a centred pop-up window (Shop, Index, Leaderboards...). Only one is open at a time.
]]

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Modal = {}
Modal.__index = Modal

export type Modal = {
	Frame: Frame,
	Body: Frame,
	Title: TextLabel,
	OnOpen: (() -> ())?,
	Open: (self: Modal) -> (),
	Close: (self: Modal) -> (),
	Toggle: (self: Modal) -> (),
	IsOpen: (self: Modal) -> boolean,
}

local gui: ScreenGui? = nil
local current: Modal? = nil

local function getGui(): ScreenGui
	if not gui then
		gui = Theme.ScreenGui("Modals", 10)
	end
	return gui :: ScreenGui
end

function Modal.new(title: string, color: Color3, size: Vector2): Modal
	local holder = Theme.new("Frame", {
		Name = title,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = Theme.Colors.Panel,
		Visible = false,
		Parent = getGui(),
	}, {
		Theme.Corner(18),
		Theme.Stroke(4),
		Theme.Gradient(Theme.Colors.PanelLight, Theme.Colors.Panel),
	})
	Theme.AutoScale(holder) -- (only one UIScale per object works, so the open "pop" tweens this one too)

	local header = Theme.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = color,
		Parent = holder,
	}, {
		Theme.Corner(18),
		Theme.Gradient(Theme.Lighten(color, 0.2), Theme.Darken(color, 0.1)),
	})
	-- Square off the header's bottom corners
	Theme.new("Frame", { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 1, -18), BackgroundColor3 = Theme.Darken(color, 0.1), BorderSizePixel = 0, Parent = header })
	local titleLabel = Theme.Label({ Name = "Title", Text = title, Size = UDim2.new(1, -120, 0, 44), Position = UDim2.fromOffset(20, 7), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 3, Parent = header })

	local close = Theme.Button({ Name = "Close", Text = "X", Color = Theme.Colors.Red, Size = UDim2.fromOffset(46, 46), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 6), Parent = header })

	local body = Theme.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 68),
		Size = UDim2.new(1, -28, 1, -80),
		Parent = holder,
	})

	local self = setmetatable({ Frame = holder, Body = body, Title = titleLabel, OnOpen = nil }, Modal) :: any
	close.Activated:Connect(function()
		self:Close()
	end)
	return self
end

function Modal.Open(self: Modal)
	if current and current ~= self then
		current:Close()
	end
	current = self
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
	self.Frame.Visible = false
	if current == self then
		current = nil
	end
end

function Modal.Toggle(self: Modal)
	if self.Frame.Visible then
		self:Close()
	else
		self:Open()
	end
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
