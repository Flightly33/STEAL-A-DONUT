--[[
	Theme: colours, fonts and small UI building helpers (chunky outlined "simulator" style).
]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Icons = require(script.Parent.Icons)

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

-- Sound effects: quiet and soft by default. Every UI sound is made from sounds that ship with
-- Roblox (rbxasset://sounds/...), layered and softened with sound effects, so nothing has to be
-- uploaded. Paste Creator Store sounds into Config.Sounds to use your own instead.
--   Id / Volume (0-1) / Pitch (1 = normal, lower = deeper and softer); Id = "" turns it off
--   Notes  = { pitch, ... } plays it once per note, one after the other (a little jingle); a
--            note can be a list of pitches to play together (a chord)
--   Layers = more sounds played at the same time (a key's low "thock" under its click)
--   Vary   = random pitch wobble (0.04 = +-4%) so repeated clicks don't sound robotic
--   Group  = "Keys" (muffled, like a keyboard with soft switches) or "Chimes" (soft, with a bit of
--            room echo)
local PING = "rbxasset://sounds/electronicpingshort.wav"
local WHOOSH = "rbxasset://sounds/Rocket whoosh 01.wav"
local THUD = "rbxasset://sounds/action_jump_land.mp3"
local CLICK = "rbxasset://sounds/button.wav"
export type Layer = { Id: string, Volume: number, Pitch: number }
export type SoundDef = { Id: string, Volume: number, Pitch: number, Notes: { any }?, Gap: number?, Layers: { Layer }?, Vary: number?, Group: string? }
-- Musical steps above the first note (major scale), for the chimes
local THIRD, FIFTH, OCTAVE = 1.26, 1.498, 2
Theme.Sounds = {
	-- Buttons: a soft mechanical keyboard. Pressing = a muffled click over a low wooden "thock";
	-- letting go = the same, lighter and higher, like a key springing back up.
	KeyDown = { Id = CLICK, Volume = 0.09, Pitch = 0.72, Layers = { { Id = THUD, Volume = 0.3, Pitch = 2.5 } }, Vary = 0.05, Group = "Keys" },
	KeyUp = { Id = CLICK, Volume = 0.045, Pitch = 0.95, Layers = { { Id = THUD, Volume = 0.13, Pitch = 3.1 } }, Vary = 0.06, Group = "Keys" },
	-- A window popping up by itself: a deeper "space bar" thock
	Open = { Id = CLICK, Volume = 0.08, Pitch = 0.6, Layers = { { Id = THUD, Volume = 0.32, Pitch = 1.9 } }, Vary = 0.03, Group = "Keys" },
	-- Messages: soft chimes, each kind its own little tune
	Notify = { Id = PING, Volume = 0.1, Pitch = 0.8, Notes = { 1, 1.335 }, Gap = 0.08, Group = "Chimes" },
	Success = { Id = PING, Volume = 0.11, Pitch = 0.8, Notes = { 1, THIRD, FIFTH }, Gap = 0.07, Group = "Chimes" },
	Rare = { Id = PING, Volume = 0.09, Pitch = 0.8, Notes = { FIFTH, OCTAVE, OCTAVE * THIRD, OCTAVE * FIFTH }, Gap = 0.05, Group = "Chimes" },
	Error = { Id = PING, Volume = 0.1, Pitch = 0.5, Notes = { 1, 0.84 }, Gap = 0.1, Group = "Chimes" },
	Announce = { Id = PING, Volume = 0.11, Pitch = 0.72, Notes = { 1, THIRD, FIFTH, { 1, THIRD, OCTAVE } :: any }, Gap = 0.09, Group = "Chimes" },
	-- A server event starting: a rising fanfare ending on a chord, over a soft low boom
	Event = { Id = PING, Volume = 0.13, Pitch = 0.7, Notes = { 1, THIRD, FIFTH, OCTAVE, { FIFTH, OCTAVE, OCTAVE * THIRD } :: any }, Gap = 0.11, Layers = { { Id = THUD, Volume = 0.35, Pitch = 0.45 } }, Group = "Chimes" },
	-- Stealing: a quick "swipe", a rising "got it!" jingle, then the chase starts
	Grab = { Id = WHOOSH, Volume = 0.35, Pitch = 1.8 },
	Steal = { Id = PING, Volume = 0.2, Pitch = 1, Notes = { 1, 1.26, 1.5 }, Gap = 0.07 },
	Hatch = { Id = PING, Volume = 0.3, Pitch = 1.6 },
	Crack = { Id = THUD, Volume = 0.4, Pitch = 1.8 },
	-- Home safe: a bright "cha-ching" arpeggio
	Deposit = { Id = PING, Volume = 0.24, Pitch = 1, Notes = { 1, 1.26, 1.5, 2 }, Gap = 0.08 },
	Collect = { Id = PING, Volume = 0.2, Pitch = 1 },
	-- Caught: a big BONK and a whoosh as you go flying
	Caught = { Id = THUD, Volume = 0.8, Pitch = 0.55 },
	Fling = { Id = WHOOSH, Volume = 0.5, Pitch = 0.8 },
} :: { [string]: SoundDef }
Theme.Sounds.Click = Theme.Sounds.KeyDown

-- Sound groups: effects shared by every sound in them
type GroupEffects = { Equalizer: { HighGain: number, MidGain: number, LowGain: number }?, Reverb: { [string]: number }? }
local GROUPS: { [string]: GroupEffects } = {
	-- muffle the click's sharp top end (soft, "lubed" switches) and add a little body
	Keys = { Equalizer = { HighGain = -12, MidGain = -2, LowGain = 3 } },
	-- round off the ping into a bell, with a small room around it
	Chimes = { Equalizer = { HighGain = -8, MidGain = 0, LowGain = 1 }, Reverb = { DecayTime = 1.3, Density = 1, Diffusion = 1, DryLevel = 0, WetLevel = -13 } },
}
local soundFolder: Folder? = nil
local soundGroups: { [string]: SoundGroup } = {}
local function folder(): Folder
	if not soundFolder then
		local f = Instance.new("Folder")
		f.Name = "UISounds"
		f.Parent = SoundService
		for name, effects in GROUPS do
			local group = Instance.new("SoundGroup")
			group.Name = name
			group.Volume = 1
			local equalizer = effects.Equalizer
			if equalizer then
				local eq = Instance.new("EqualizerSoundEffect")
				eq.HighGain = equalizer.HighGain
				eq.MidGain = equalizer.MidGain
				eq.LowGain = equalizer.LowGain
				eq.Priority = 1
				eq.Parent = group
			end
			local reverb = effects.Reverb
			if reverb then
				local effect = Instance.new("ReverbSoundEffect")
				for key, value in reverb do
					(effect :: any)[key] = value
				end
				effect.Priority = 0
				effect.Parent = group
			end
			group.Parent = f
			soundGroups[name] = group
		end
		soundFolder = f
	end
	return soundFolder :: Folder
end

local random = Random.new()
local function playOnce(id: string, volume: number, pitch: number, group: string?)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = pitch
	local holder = folder()
	if group then
		sound.SoundGroup = soundGroups[group]
	end
	sound.Parent = holder
	sound:Play()
	task.delay(4, function()
		sound:Destroy()
	end)
end

-- Config.Sounds: pasted Creator Store sounds replace the built-in ones (until one fails to load)
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local custom: { [string]: string } = {}
for name, id in Config.Sounds :: { [string]: any } do
	if type(id) == "string" and id ~= "" then
		custom[name] = id
	end
end
if next(custom) then
	task.spawn(function()
		local list = {}
		for name, id in custom do
			local probe = Instance.new("Sound")
			probe.Name = name
			probe.SoundId = id
			table.insert(list, probe)
		end
		pcall(function()
			ContentProvider:PreloadAsync(list, function(contentId: string, status: Enum.AssetFetchStatus)
				if status == Enum.AssetFetchStatus.Failure then
					for name, id in custom do
						if id == contentId then
							custom[name] = nil
							warn(`[Sounds] Config.Sounds.{name} ({id}) couldn't load, so the built-in sound plays instead.`)
						end
					end
				end
			end)
		end)
	end)
end

local lastSound = 0
function Theme.PlaySound(name: string, _volume: number?)
	if name ~= "KeyDown" and name ~= "KeyUp" then
		lastSound = os.clock()
	end
	local own = custom[name]
	if own then
		playOnce(own, Config.Sounds.CustomVolume, 1, nil)
		return
	end
	local def = Theme.Sounds[name]
	if not def or def.Id == "" then
		return
	end
	local wobble = if def.Vary then 1 + random:NextNumber(-def.Vary, def.Vary) else 1
	if def.Layers then
		for _, layer in def.Layers do
			playOnce(layer.Id, layer.Volume, layer.Pitch * wobble, def.Group)
		end
	end
	local notes = def.Notes
	if notes then
		task.spawn(function()
			for i, note in notes do
				if type(note) == "table" then
					for _, pitch in note do
						playOnce(def.Id, def.Volume * 0.8, def.Pitch * pitch, def.Group)
					end
				else
					playOnce(def.Id, def.Volume, def.Pitch * note * wobble, def.Group)
				end
				if i < #notes then
					task.wait(def.Gap or 0.08)
				end
			end
		end)
	else
		playOnce(def.Id, def.Volume, def.Pitch * wobble, def.Group)
	end
end

-- Every button in `root` (now and later) clicks like a soft keyboard key: down when pressed, up
-- when let go. Give a button the attribute Silent = true to keep it quiet.
local lastKey = 0
local wired: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local function wireButton(button: GuiButton)
	if wired[button] then
		return -- (moved to another frame: already clicks)
	end
	wired[button] = true
	button.MouseButton1Down:Connect(function()
		if not button:GetAttribute("Silent") then
			lastKey = os.clock()
			Theme.PlaySound("KeyDown")
		end
	end)
	button.MouseButton1Up:Connect(function()
		if not button:GetAttribute("Silent") then
			Theme.PlaySound("KeyUp")
		end
	end)
end
function Theme.WireClickSounds(root: Instance)
	for _, child in root:GetDescendants() do
		if child:IsA("GuiButton") then
			wireButton(child)
		end
	end
	root.DescendantAdded:Connect(function(child: Instance)
		if child:IsA("GuiButton") then
			wireButton(child)
		end
	end)
end

-- Seconds since the last button press (a window opened by a click doesn't need its own sound).
function Theme.SinceKeyPress(): number
	return os.clock() - lastKey
end

-- Seconds since the last sound other than a key click (so chimes don't pile up on each other).
function Theme.SinceSound(): number
	return os.clock() - lastSound
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
		local drawn = Icons.For(props.Icon)
		if drawn then
			-- a chunky white outlined icon (UI/Icons) instead of the emoji
			Icons.Draw(drawn, button, props.Color, {
				Size = UDim2.fromScale(0.74, 0.74),
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 8, 0.5, 0),
			})
		else
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
		end
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
		Theme.Bounce(button) -- (the click sound comes from Theme.WireClickSounds)
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
