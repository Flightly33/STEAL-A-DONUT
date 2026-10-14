--[[
	SkipButton: the SKIP button every cutscene shares (the opening scene, the Mythic box film, the
	storm and Cosmic Domer cinematics). It stays out of the way: click or tap anywhere while a
	cutscene plays and it pops up in the bottom-right corner, on the black bar, for a few seconds.

	  SkipButton.Attach(gui, onSkip) -> the button (named "Skip"), inside `gui`. Clicking it calls
	  onSkip. Everything it listens to is let go when `gui` goes.
	  SkipButton.Show(button)          pop it up now (it hides again after SkipButton.Linger)
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)

local SkipButton = {}

SkipButton.Linger = 4 -- seconds it stays up after the last click

local hideAt: { [GuiButton]: number } = {}

function SkipButton.Show(button: GuiButton)
	local wasVisible = button.Visible
	button.Visible = true
	hideAt[button] = os.clock() + SkipButton.Linger
	if not wasVisible then
		local scale = button:FindFirstChild("PopScale") :: UIScale?
		if scale then
			scale.Scale = 0.6
			TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end
	local until_ = hideAt[button]
	task.delay(SkipButton.Linger + 0.05, function()
		if hideAt[button] == until_ and button.Parent then
			button.Visible = false
		end
	end)
end

function SkipButton.Attach(gui: Instance, onSkip: () -> ()): TextButton
	local button = Theme.Button({
		Name = "Skip",
		Text = "SKIP  >>",
		Color = Theme.Colors.Gray,
		Size = UDim2.fromOffset(118, 38),
		AnchorPoint = Vector2.new(1, 1),
		-- (bottom right, on the black bar)
		Position = UDim2.new(1, -18, 1, -12),
		Parent = gui,
	})
	button.Visible = false
	button.ZIndex = 20
	for _, d in button:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = 21
		end
	end
	local scale = Instance.new("UIScale")
	scale.Name = "PopScale"
	scale.Parent = button
	button.Activated:Connect(function()
		hideAt[button] = nil
		onSkip()
	end)
	local input = UserInputService.InputBegan:Connect(function(io: InputObject)
		if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
			SkipButton.Show(button)
		end
	end)
	gui.AncestryChanged:Connect(function()
		if not gui.Parent then
			input:Disconnect()
			hideAt[button] = nil
		end
	end)
	return button
end

return SkipButton
