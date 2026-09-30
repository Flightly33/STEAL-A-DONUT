--[[
	Theme: colours, fonts and small UI building helpers (chunky outlined "simulator" style).
]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local Theme = {}

local rgb = Color3.fromRGB

Theme.Font = Enum.Font.FredokaOne
Theme.Title = Enum.Font.LuckiestGuy

Theme.Colors = {
	Green = rgb(80, 215, 50),
	Blue = rgb(30, 160, 255),
	Orange = rgb(255, 140, 30),
	Red = rgb(235, 55, 55),
	Purple = rgb(150, 70, 255),
	Yellow = rgb(255, 210, 40),
	Pink = rgb(255, 110, 190),
	Gray = rgb(120, 120, 130),
	Money = rgb(90, 255, 70),
	Speed = rgb(120, 60, 255),
	Panel = rgb(35, 35, 55),
	PanelLight = rgb(55, 55, 80),
	Outline = rgb(15, 15, 25),
	White = rgb(255, 255, 255),
}

Theme.IsTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Sound effects: quiet and soft by default. Id = any sound (paste "rbxassetid://123" from the
-- Creator Store to use your own), Volume 0-1, Pitch 1 = normal (lower = deeper/softer).
-- Set Id = "" to turn a sound off.
-- Notes = { pitch, ... } plays the sound once per note, one after the other (a little jingle).
local PING = "rbxasset://sounds/electronicpingshort.wav"
local WHOOSH = "rbxasset://sounds/Rocket whoosh 01.wav"
local THUD = "rbxasset://sounds/action_jump_land.mp3"
export type SoundDef = { Id: string, Volume: number, Pitch: number, Notes: { number }?, Gap: number? }
Theme.Sounds = {
	Click = { Id = "rbxasset://sounds/button.wav", Volume = 0.12, Pitch = 1.15 },
	-- Stealing: a quick "swipe", a rising "got it!" jingle, then the chase starts
	Grab = { Id = WHOOSH, Volume = 0.35, Pitch = 1.8 },
	Steal = { Id = PING, Volume = 0.2, Pitch = 1, Notes = { 1, 1.26, 1.5 }, Gap = 0.07 },
	Hatch = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.3, Pitch = 1.6 },
	Crack = { Id = THUD, Volume = 0.4, Pitch = 1.8 },
	-- Home safe: a bright "cha-ching" arpeggio
	Deposit = { Id = PING, Volume = 0.24, Pitch = 1, Notes = { 1, 1.26, 1.5, 2 }, Gap = 0.08 },
	Collect = { Id = PING, Volume = 0.2, Pitch = 1 },
	Announce = { Id = PING, Volume = 0.12, Pitch = 0.7 },
	-- Caught: a big BONK and a whoosh as you go flying
	Caught = { Id = THUD, Volume = 0.8, Pitch = 0.55 },
	Fling = { Id = WHOOSH, Volume = 0.5, Pitch = 0.8 },
	Error = { Id = "", Volume = 0, Pitch = 1 },
} :: { [string]: SoundDef }

local function playOnce(id: string, volume: number, pitch: number)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = pitch
	SoundService:PlayLocalSound(sound)
	task.delay(3, function()
		sound:Destroy()
	end)
end

function Theme.PlaySound(name: string, _volume: number?)
	local def = Theme.Sounds[name]
	if not def or def.Id == "" then
		return
	end
	local notes = def.Notes
	if notes then
		task.spawn(function()
			for i, note in notes do
				playOnce(def.Id, def.Volume, def.Pitch * note)
				if i < #notes then
					task.wait(def.Gap or 0.08)
				end
			end
		end)
	else
		playOnce(def.Id, def.Volume, def.Pitch)
	end
end

-- Instance.new with a property table and optional children.
function Theme.new(className: string, props: { [string]: any }?, children: { any }?): any
	local instance = Instance.new(className :: any)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Theme.Corner(radius: number?): any
	return Theme.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function Theme.Stroke(thickness: number?, color: Color3?, mode: Enum.ApplyStrokeMode?): any
	return Theme.new("UIStroke", {
		Thickness = thickness or 3,
		Color = color or Theme.Colors.Outline,
		ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border,
	})
end

function Theme.Gradient(top: Color3, bottom: Color3): any
	return Theme.new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = 90 })
end

function Theme.Padding(px: number): any
	local u = UDim.new(0, px)
	return Theme.new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

-- Outlined text label (thick black stroke like the reference UI).
function Theme.Label(props: { [string]: any }): TextLabel
	local label = Theme.new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Theme.Title,
		TextColor3 = Theme.Colors.White,
		TextScaled = true,
		Text = "",
	})
	for key, value in props do
		if key ~= "Parent" and key ~= "StrokeThickness" and key ~= "StrokeColor" then
			(label :: any)[key] = value
		end
	end
	Theme.new("UIStroke", {
		Thickness = props.StrokeThickness or 2.5,
		Color = props.StrokeColor or Theme.Colors.Outline,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = label,
	})
	label.Parent = props.Parent
	return label
end

local function lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

local function darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end
Theme.Lighten = lighten
Theme.Darken = darken

-- Pop animation on press.
function Theme.Bounce(button: GuiObject)
	local scale = button:FindFirstChild("BounceScale") :: UIScale?
	if not scale then
		scale = Theme.new("UIScale", { Name = "BounceScale", Parent = button })
	end
	local s = scale :: UIScale
	s.Scale = 0.9
	TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- Big chunky button: coloured gradient, dark outline, outlined text, optional emoji icon.
function Theme.Button(props: {
	Text: string,
	Color: Color3,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Icon: string?,
	Parent: Instance?,
	LayoutOrder: number?,
	Name: string?,
	TextSize: number?,
}): TextButton
	local button = Theme.new("TextButton", {
		Name = props.Name or "Button",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
	}, {
		Theme.Corner(9),
		Theme.Stroke(3.5),
		Theme.Gradient(lighten(props.Color, 0.3), darken(props.Color, 0.12)),
	})
	button:SetAttribute("BaseColor", props.Color)
	local textX = 0
	if props.Icon then
		Theme.Label({
			Name = "Icon",
			Text = props.Icon,
			Font = Enum.Font.GothamBold,
			Size = UDim2.fromScale(0.8, 0.8), -- square: both relative to the button height
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0.5, 0),
			Parent = button,
		})
		textX = 0.3
	end
	Theme.Label({
		Name = "Text",
		Text = props.Text,
		Size = UDim2.new(1 - textX, -10, 0.7, 0),
		Position = UDim2.new(textX, if props.Icon then 0 else 5, 0.15, 0),
		Parent = button,
	})
	button.MouseButton1Down:Connect(function()
		Theme.Bounce(button)
		Theme.PlaySound("Click")
	end)
	button.Parent = props.Parent
	return button
end

-- Recolour a Theme.Button (e.g. grey when you can't afford something).
function Theme.SetButtonColor(button: TextButton, color: Color3)
	local gradient = button:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Color = ColorSequence.new(lighten(color, 0.25), darken(color, 0.1))
	end
end

function Theme.SetButtonText(button: TextButton, text: string)
	local label = button:FindFirstChild("Text") :: TextLabel?
	if label then
		label.Text = text
	end
end

-- Keeps a UIScale in sync with the screen size (UI is designed for 1280x720, then drawn at
-- Theme.UIScale of that so it stays out of the way of the game).
Theme.UIScale = 0.82
local scales: { UIScale } = {}
local function currentScale(): number
	local camera = workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return math.clamp(math.min(size.X / 1280, size.Y / 720), 0.55, 1.2) * Theme.UIScale
end

function Theme.CurrentScale(): number
	return currentScale()
end

function Theme.AutoScale(target: GuiObject): UIScale
	local scale = Theme.new("UIScale", { Name = "AutoScale", Scale = currentScale(), Parent = target })
	table.insert(scales, scale)
	return scale
end

local function hookCamera()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			local value = currentScale()
			for _, scale in scales do
				scale.Scale = value
			end
		end)
	end
end
hookCamera()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hookCamera)

function Theme.PlayerGui(): PlayerGui
	return (Players.LocalPlayer :: Player):WaitForChild("PlayerGui") :: PlayerGui
end

function Theme.ScreenGui(name: string, displayOrder: number?): ScreenGui
	return Theme.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder or 0,
		IgnoreGuiInset = false,
		Parent = Theme.PlayerGui(),
	})
end

return Theme
