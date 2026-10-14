--[[
	DonutMenu: the card that floats over the pen donut you point at (client/DonutHover picks the
	donut). Instead of Roblox's plain grey prompt boxes:

	  * a header in the donut's rarity colour with its name ("2.35x Gold Glazino") and rarity
	  * three big buttons: Upgrade (green: the cost, and level and income it goes up to),
	    Pick up (orange: fills up as you hold it) and Favorite (pink)
	  * each shows its key (E / F / R) - press the key or click / tap the button
	  * it pops in, and fades its buttons with "WALK CLOSER TO USE" when you're too far away

	The donut's ProximityPrompts still do the work (their own UI is switched off: Style Custom), so
	the server side is unchanged.

	  DonutMenu.Show(model, prompts, near, height)  model nil hides it; prompts by name
	  DonutMenu.SetHeld(prompt, since)               the prompt being held (the fill), or nil
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarities = require(Shared.Rarities)

local Theme = require(script.Parent.Theme)

local DonutMenu = {}

local player = Players.LocalPlayer :: Player
local rgb = Color3.fromRGB

local WIDTH = 270
local HEADER = 48
local ROW = 46
local GAP = 6

type RowDef = { Prompt: string, Key: string, Color: Color3, Sub: string? }
local ROWS: { RowDef } = {
	{ Prompt = "UpgradePrompt", Key = "E", Color = rgb(70, 200, 60) },
	{ Prompt = "PickUpPrompt", Key = "F", Color = rgb(255, 150, 40), Sub = "Back into your items" },
	{ Prompt = "FavoritePrompt", Key = "R", Color = rgb(255, 105, 185) },
}

type Row = { Def: RowDef, Button: TextButton, Fill: Frame, Title: TextLabel, Sub: TextLabel, Key: TextLabel, Gradient: UIGradient }

local gui: BillboardGui? = nil
local scale: UIScale
local headerGradient: UIGradient
local nameLabel: TextLabel
local rarityLabel: TextLabel
local rows: { Row } = {}
local shown: Model? = nil
local prompts: { [string]: ProximityPrompt } = {}
local isNear = false
local held: ProximityPrompt? = nil
local heldSince = 0

local function press(row: Row, down: boolean)
	local prompt = prompts[row.Def.Prompt]
	if not prompt or not isNear then
		return
	end
	pcall(function()
		if down then
			prompt:InputHoldBegin()
		else
			prompt:InputHoldEnd()
		end
	end)
end

local function build(): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DonutMenu"
	billboard.Size = UDim2.fromOffset(WIDTH, HEADER + 8 + #ROWS * (ROW + GAP) + 2)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.ResetOnSpawn = false
	billboard.Active = true
	billboard.MaxDistance = 200
	billboard.Enabled = false
	scale = Theme.new("UIScale", { Scale = 0, Parent = billboard }) :: UIScale

	local card = Theme.new("Frame", {
		Name = "Card",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Panel,
		Parent = billboard,
	}, { Theme.Corner(16), Theme.Stroke(3, Theme.Colors.Outline) }) :: Frame
	Theme.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(rgb(255, 255, 255), rgb(170, 170, 170)), Parent = card })

	-- the header: the donut's name on its rarity's colour
	local header = Theme.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, HEADER),
		BackgroundColor3 = rgb(255, 255, 255),
		Parent = card,
	}, { Theme.Corner(16) }) :: Frame
	headerGradient = Theme.new("UIGradient", { Rotation = 90, Parent = header }) :: UIGradient
	-- (square off the header's bottom corners)
	Theme.new("Frame", {
		Name = "HeaderBase",
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.new(0, 0, 1, -16),
		BackgroundColor3 = rgb(255, 255, 255),
		BorderSizePixel = 0,
		Parent = header,
	}, { Theme.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(rgb(200, 200, 200), rgb(170, 170, 170)) }) })
	nameLabel = Theme.Label({
		Name = "DonutName",
		Size = UDim2.new(1, -20, 0, 26),
		Position = UDim2.fromOffset(10, 4),
		ZIndex = 3,
		Parent = header,
	})
	rarityLabel = Theme.Label({
		Name = "Rarity",
		Size = UDim2.new(1, -20, 0, 14),
		Position = UDim2.fromOffset(10, 30),
		StrokeThickness = 1.5,
		ZIndex = 3,
		Parent = header,
	})

	for i, def in ROWS do
		local y = HEADER + 8 + (i - 1) * (ROW + GAP)
		local button = Theme.new("TextButton", {
			Name = def.Prompt,
			Size = UDim2.new(1, -16, 0, ROW),
			Position = UDim2.fromOffset(8, y),
			BackgroundColor3 = rgb(255, 255, 255),
			AutoButtonColor = false,
			Text = "",
			ClipsDescendants = true,
			Parent = card,
		}, { Theme.Corner(12), Theme.Stroke(2.5, Theme.Colors.Outline) }) :: TextButton
		local gradient = Theme.new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(def.Color:Lerp(rgb(255, 255, 255), 0.18), def.Color:Lerp(rgb(0, 0, 0), 0.3)),
			Parent = button,
		}) :: UIGradient
		local fill = Theme.new("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = rgb(255, 255, 255),
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = button,
		}) :: Frame
		-- the key, on a little white keycap
		local cap = Theme.new("Frame", {
			Name = "KeyCap",
			Size = UDim2.fromOffset(32, 32),
			Position = UDim2.new(0, 7, 0.5, -16),
			BackgroundColor3 = rgb(250, 250, 250),
			ZIndex = 3,
			Parent = button,
		}, { Theme.Corner(8), Theme.Stroke(2, Theme.Colors.Outline) }) :: Frame
		local key = Theme.new("TextLabel", {
			Name = "Key",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Theme.Title,
			TextScaled = true,
			Text = def.Key,
			TextColor3 = rgb(30, 30, 36),
			ZIndex = 4,
			Parent = cap,
		}, { Theme.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }) }) :: TextLabel
		local title = Theme.Label({
			Name = "Action",
			Size = UDim2.new(1, -56, 0, 24),
			Position = UDim2.fromOffset(48, 3),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3,
			Parent = button,
		})
		local sub = Theme.Label({
			Name = "Detail",
			Size = UDim2.new(1, -56, 0, 14),
			Position = UDim2.fromOffset(48, 27),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = rgb(255, 250, 230),
			StrokeThickness = 1.5,
			ZIndex = 3,
			Parent = button,
		})
		local row: Row = { Def = def, Button = button, Fill = fill, Title = title, Sub = sub, Key = key, Gradient = gradient }
		button.MouseButton1Down:Connect(function()
			press(row, true)
		end)
		button.MouseButton1Up:Connect(function()
			press(row, false)
		end)
		button.MouseLeave:Connect(function()
			if held == prompts[def.Prompt] then
				press(row, false)
			end
		end)
		button.MouseEnter:Connect(function()
			button.BackgroundColor3 = rgb(255, 255, 255)
			gradient.Offset = Vector2.new(0, -0.08)
		end)
		table.insert(rows, row)
	end

	billboard.Parent = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui")
	return billboard
end

local function setText(label: TextLabel, text: string)
	if label.Text ~= text then
		label.Text = text
	end
end

-- Show the menu over `model` (nil: hide it). `height`: studs above its pivot.
function DonutMenu.Show(model: Model?, byName: { [string]: ProximityPrompt }, near: boolean, height: number)
	local billboard = gui or build()
	gui = billboard
	if model ~= shown then
		shown = model
		if model then
			(billboard :: any).Adornee = model.PrimaryPart
			billboard.Enabled = true
			scale.Scale = 0.6
			TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		else
			billboard.Enabled = false
			(billboard :: any).Adornee = nil
			held = nil
		end
	end
	if not model then
		return
	end
	prompts = byName
	isNear = near
	billboard.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	-- the header: name and rarity
	local rarityId = model:GetAttribute("Rarity")
	local rarity = Rarities.Get(if type(rarityId) == "string" then rarityId else "Common")
	headerGradient.Color = ColorSequence.new(rarity.Color:Lerp(rgb(255, 255, 255), 0.2), rarity.Color:Lerp(rgb(0, 0, 0), 0.25))
	local pickUp = byName.PickUpPrompt
	setText(nameLabel, if pickUp and pickUp.ObjectText ~= "" then pickUp.ObjectText else "Your Donut")
	-- (too far away to use it: says so in place of the rarity)
	setText(rarityLabel, if near then string.upper(rarity.Id) else "WALK CLOSER TO USE")
	rarityLabel.TextColor3 = if near then rgb(255, 255, 255) else rgb(255, 230, 120)
	-- the buttons
	local now = os.clock()
	for _, row in rows do
		local prompt = byName[row.Def.Prompt]
		row.Button.Visible = (prompt :: any) ~= nil
		if prompt then
			setText(row.Title, prompt.ActionText)
			setText(row.Sub, row.Def.Sub or prompt.ObjectText)
			local keyName = prompt.KeyboardKeyCode.Name
			setText(row.Key, if #keyName == 1 then keyName else row.Def.Key)
			local maxed = prompt.ActionText == "MAX LEVEL"
			row.Button.BackgroundTransparency = if near and not maxed then 0 else 0.45
			local progress = 0
			if held == prompt and prompt.HoldDuration > 0 then
				progress = math.clamp((now - heldSince) / prompt.HoldDuration, 0, 1)
			end
			row.Fill.Size = UDim2.fromScale(progress, 1)
		end
	end
end

function DonutMenu.SetHeld(prompt: ProximityPrompt?, since: number)
	held = prompt
	heldSince = since
end

function DonutMenu.Current(): Model?
	return shown
end

return DonutMenu
