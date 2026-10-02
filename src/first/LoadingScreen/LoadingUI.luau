--[[
	LoadingUI: the loading screen you see while the game loads in.

	Dark stage with spotlights from above, the Steal a Donut logo (a masked donut in front of a
	slowly turning wheel of sprinkles, sparkles, the title), "Loading... 42%", a row of nine donuts in
	the rarity colours that light up one by one as things load, and a tip at the bottom.
	A SKIP button (bottom right) closes it straight away.

	It waits for: the place to load (every part of the map), the Map, your saved data and the queue
	of images / sounds to download. It stays at least MIN_SECONDS (no flash) and at most MAX_SECONDS.

	This runs from ReplicatedFirst before anything else has arrived, so it can't use the game's
	shared modules: colours and fonts are copied in here.
	While it's up, the local player has the attribute LoadingScreen = true (the Update Log waits).
	To show the real logo picture instead of the built one, upload branding/logo.png to Roblox and
	paste its id into LOGO_IMAGE.
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LoadingUI = {}

local LOGO_IMAGE = "" -- e.g. "rbxassetid://123456789"
local MIN_SECONDS = 2.5
local MAX_SECONDS = 45
local DESIGN = Vector2.new(1280, 720)

local rgb = Color3.fromRGB
local WHITE = rgb(255, 255, 255)
local BACKGROUND = rgb(12, 11, 15)
local GREY = rgb(150, 150, 162)
local OUTLINE = rgb(25, 18, 20)
local TITLE_FONT = Enum.Font.LuckiestGuy
local TEXT_FONT = Enum.Font.GothamBold

-- One donut per rarity, Common -> Icon (the same colours as Rarities.luau)
local RARITY_COLORS = {
	rgb(215, 215, 215), rgb(85, 225, 90), rgb(55, 150, 255), rgb(190, 70, 255), rgb(255, 190, 25),
	rgb(255, 110, 255), rgb(255, 255, 255), rgb(255, 40, 40), rgb(40, 140, 255),
}
local SPRINKLES = { rgb(255, 80, 80), rgb(255, 220, 60), rgb(90, 220, 120), rgb(80, 170, 255), rgb(255, 255, 255), rgb(200, 110, 255) }

LoadingUI.Tips = {
	"Tip: Run on your treadmill to get faster than Domer!",
	"Tip: Rarer donuts glow brighter. Look for the shiny ones!",
	"Tip: Lock your base so nobody can steal your donuts.",
	"Tip: Rebirth to unlock new worlds and earn way more money.",
	"Tip: Hatch eggs to get pets that boost your money and speed.",
	"Tip: Press X to hide the UI for screenshots.",
	"Tip: Check the Index to claim rewards for every donut you find.",
	"Tip: Domer sleeps until you grab a donut. Then RUN!",
}

local function new(className: string, props: { [string]: any }, children: { Instance }?): any
	local item = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(item :: any)[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = item
		end
	end
	item.Parent = props.Parent
	return item
end

local function corner(radius: number?): UICorner
	return new("UICorner", { CornerRadius = if radius then UDim.new(0, radius) else UDim.new(1, 0) })
end

local function stroke(thickness: number, color: Color3, transparency: number?): UIStroke
	return new("UIStroke", { Thickness = thickness, Color = color, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function fade(alphas: { { number } }, rotation: number?, color: Color3?): UIGradient
	local keys = {}
	for _, pair in alphas do
		table.insert(keys, NumberSequenceKeypoint.new(pair[1], pair[2]))
	end
	return new("UIGradient", { Transparency = NumberSequence.new(keys), Rotation = rotation or 0, Color = ColorSequence.new(color or WHITE) })
end

-- A box centred on (x, y) in the 1280x720 design space.
local function box(parent: Instance, name: string, x: number, y: number, w: number, h: number, props: { [string]: any }?): Frame
	local p: { [string]: any } = props or {}
	local frame = new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = p.Color or WHITE,
		BackgroundTransparency = p.Transparency or 0,
		BorderSizePixel = 0,
		Rotation = p.Rotation or 0,
		ZIndex = p.ZIndex or 1,
		Parent = parent,
	})
	return frame
end

local function text(parent: Instance, name: string, value: string, x: number, y: number, w: number, h: number, props: { [string]: any }?): TextLabel
	local p: { [string]: any } = props or {}
	local label = new("TextLabel", {
		Name = name,
		Text = value,
		Font = p.Font or TEXT_FONT,
		TextSize = p.TextSize or h,
		TextScaled = p.TextScaled or false,
		TextColor3 = p.Color or WHITE,
		TextTransparency = p.Transparency or 0,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		ZIndex = p.ZIndex or 5,
		Parent = parent,
	})
	if p.Stroke then
		new("UIStroke", { Thickness = p.Stroke, Color = p.StrokeColor or OUTLINE, Transparency = p.StrokeTransparency or 0, Parent = label })
	end
	return label
end

-- A donut drawn as rings: `size` across, hole `hole` across.
local function ring(parent: Instance, name: string, x: number, y: number, size: number, hole: number, color: Color3, zIndex: number?): (Frame, UIStroke)
	local frame = box(parent, name, x, y, hole, hole, { Transparency = 1, ZIndex = zIndex })
	corner().Parent = frame
	local edge = stroke((size - hole) / 2, color)
	edge.Parent = frame
	return frame, edge
end

-- The emblem: a turning wheel of sprinkles with a masked donut in front (like the game's logo).
local function buildEmblem(stage: Frame): (Frame, Frame)
	local cx, cy = 640, 205
	-- soft glow behind
	for i, size in { 430, 330, 240 } do
		local glow = box(stage, "Glow", cx, cy, size, size, { Transparency = 0.975 - i * 0.008 })
		corner().Parent = glow
	end
	-- the wheel (it turns: everything inside rotates with it)
	local wheel = box(stage, "Wheel", cx, cy, 320, 320, { Transparency = 1, ZIndex = 2 })
	for k = 0, 3 do
		local spoke = box(wheel, "Spoke", 160, 160, 9, 318, { Color = GREY, Transparency = 0.45, Rotation = k * 45, ZIndex = 2 })
		corner(4).Parent = spoke
	end
	for k = 0, 7 do
		local angle = math.rad(k * 45)
		local knob = box(wheel, "Handle", 160 + math.sin(angle) * 158, 160 - math.cos(angle) * 158, 30, 30, { Color = GREY, Transparency = 0.35, ZIndex = 2 })
		corner().Parent = knob
		-- sprinkle-coloured studs on the rim
		local stud = box(wheel, "Sprinkle", 160 + math.sin(angle + math.rad(22.5)) * 118, 160 - math.cos(angle + math.rad(22.5)) * 118, 7, 20, { Color = SPRINKLES[k % #SPRINKLES + 1], Transparency = 0.25, Rotation = k * 45 + 22.5 + 90, ZIndex = 3 })
		corner(3).Parent = stud
	end
	local _, rim = ring(wheel, "Rim", 160, 160, 262, 238, GREY, 2)
	rim.Transparency = 0.4
	local _, hub = ring(wheel, "Hub", 160, 160, 120, 100, GREY, 2)
	hub.Transparency = 0.5

	-- the donut
	local donut = box(stage, "Donut", cx, cy + 6, 200, 200, { Transparency = 1, ZIndex = 4 })
	if LOGO_IMAGE ~= "" then
		new("ImageLabel", { Image = LOGO_IMAGE, BackgroundTransparency = 1, Size = UDim2.fromScale(1.4, 1.4), Position = UDim2.fromScale(-0.2, -0.2), ZIndex = 4, Parent = donut })
		return wheel, donut
	end
	ring(donut, "Outline", 100, 100, 176, 52, OUTLINE, 4)
	ring(donut, "Dough", 100, 100, 166, 62, rgb(222, 160, 90), 5)
	ring(donut, "Frosting", 100, 92, 146, 70, rgb(255, 120, 190), 6)
	local _, holeRim = ring(donut, "HoleRim", 100, 100, 70, 62, OUTLINE, 7)
	holeRim.Transparency = 0.1
	for k = 1, 9 do
		local angle = math.rad(k * 40 + 10)
		local radius = if k % 2 == 0 then 50 else 60
		local sprinkle = box(donut, "Sprinkle", 100 + math.sin(angle) * radius, 92 - math.cos(angle) * radius * 0.92, 5, 14, { Color = SPRINKLES[k % #SPRINKLES + 1], Rotation = k * 63, ZIndex = 8 })
		corner(3).Parent = sprinkle
	end
	-- bandit mask + eyes, and a little crown
	local mask = box(donut, "Mask", 100, 44, 132, 24, { Color = OUTLINE, ZIndex = 9 })
	corner(10).Parent = mask
	for _, side in { -1, 1 } do
		local eye = box(donut, "Eye", 100 + side * 28, 44, 26, 26, { ZIndex = 10 })
		corner().Parent = eye
		stroke(2.5, OUTLINE).Parent = eye
		local pupil = box(donut, "Pupil", 100 + side * 28 + 3, 46, 10, 10, { Color = OUTLINE, ZIndex = 11 })
		corner().Parent = pupil
	end
	text(donut, "Crown", "👑", 100, -4, 60, 46, { Font = Enum.Font.GothamBold, ZIndex = 12 })
	return wheel, donut
end

-- A tiny signal (Connect / Fire).
export type Signal = { Connect: (self: Signal, callback: () -> ()) -> (), Fire: (self: Signal) -> () }
local function signal(): Signal
	local callbacks: { () -> () } = {}
	local self = {} :: Signal
	function self.Connect(_: Signal, callback: () -> ())
		table.insert(callbacks, callback)
	end
	function self.Fire(_: Signal)
		for _, callback in callbacks do
			task.spawn(callback)
		end
	end
	return self
end

export type Screen = {
	Gui: ScreenGui,
	SetProgress: (progress: number) -> (),
	SetStatus: (status: string) -> (),
	SetTip: (index: number) -> (),
	Close: (instant: boolean?) -> (),
	Skipped: Signal,
	Closed: Signal,
	Step: (dt: number) -> (),
}

-- Builds the screen (shown right away). Nothing moves until Step is called every frame.
function LoadingUI.Build(parent: Instance): Screen
	local gui = new("ScreenGui", {
		Name = "LoadingScreen",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 1000,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = parent,
	})
	local background = new("Frame", { Name = "Background", BackgroundColor3 = BACKGROUND, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = gui })
	-- darker towards the bottom and the sides (vignette)
	new("Frame", { Name = "ShadeBottom", BackgroundColor3 = rgb(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = background }, {
		fade({ { 0, 1 }, { 0.55, 0.75 }, { 1, 0.15 } }, 90, rgb(0, 0, 0)) :: Instance,
	})
	new("Frame", { Name = "ShadeSides", BackgroundColor3 = rgb(0, 0, 0), BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = background }, {
		fade({ { 0, 0.35 }, { 0.3, 1 }, { 0.7, 1 }, { 1, 0.35 } }, 0, rgb(0, 0, 0)) :: Instance,
	})

	-- Everything else is laid out at 1280x720 and scaled to the screen
	local stage = new("Frame", {
		Name = "Stage",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(DESIGN.X, DESIGN.Y),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local scale = new("UIScale", { Parent = stage })
	local function rescale()
		local camera = workspace.CurrentCamera
		local view = if camera then camera.ViewportSize else DESIGN
		scale.Scale = math.clamp(math.min(view.X / DESIGN.X, view.Y / DESIGN.Y), 0.4, 2)
	end
	rescale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	-- Spotlights fanning down from above the logo
	local rays = {}
	for i, angle in { -38, -22, -9, 9, 22, 38 } do
		local length = 1150
		local width = if math.abs(angle) < 15 then 150 else 230
		local theta = math.rad(angle)
		local x = 640 - math.sin(theta) * length / 2
		local y = -90 + math.cos(theta) * length / 2
		local ray = box(stage, "Spotlight", x, y, width, length, { Rotation = angle, Transparency = 0 })
		fade({ { 0, 0.9 }, { 0.4, 0.96 }, { 1, 1 } }, 90).Parent = ray
		-- softer, wider halo around each beam
		local halo = box(stage, "SpotlightHalo", x, y, width * 2.2, length, { Rotation = angle, Transparency = 0 })
		fade({ { 0, 0.97 }, { 0.4, 0.99 }, { 1, 1 } }, 90).Parent = halo
		rays[i] = { Ray = ray, Halo = halo, Angle = angle, Phase = i * 1.7 }
	end

	-- Sparkles around the logo (four-pointed stars)
	for _, s in { { 330, 250, 150, 0.55 }, { 950, 250, 150, 0.55 }, { 420, 330, 70, 0.6 }, { 860, 330, 70, 0.6 }, { 520, 120, 46, 0.65 }, { 760, 120, 46, 0.65 } } do
		text(stage, "Sparkle", "✦", s[1], s[2], s[3], s[3], { Color = GREY, Transparency = s[4], Font = Enum.Font.GothamBold, ZIndex = 2 })
	end

	local wheel, donut = buildEmblem(stage)

	-- Title
	local titleGlow = box(stage, "TitleGlow", 640, 420, 760, 150, { Transparency = 0.975, ZIndex = 4 })
	corner().Parent = titleGlow
	local stealA = text(stage, "TitleTop", "STEAL A", 640, 352, 600, 64, { Font = TITLE_FONT, Stroke = 5, ZIndex = 6 })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, rgb(205, 205, 215)), Parent = stealA })
	local title = text(stage, "Title", "DONUT!", 640, 430, 760, 118, { Font = TITLE_FONT, Stroke = 7, ZIndex = 6 })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(rgb(255, 250, 225), rgb(255, 200, 70)), Parent = title })
	-- ornament under the title: fading lines and a diamond
	for _, side in { -1, 1 } do
		local line = box(stage, "Ornament", 640 + side * 170, 505, 300, 3, { Color = GREY, ZIndex = 4 })
		fade(if side < 0 then { { 0, 1 }, { 1, 0.3 } } else { { 0, 0.3 }, { 1, 1 } }).Parent = line
	end
	text(stage, "OrnamentGem", "◆", 640, 505, 30, 22, { Color = rgb(255, 170, 210), Font = Enum.Font.GothamBold, ZIndex = 5 })

	-- "Loading..."
	local status = text(stage, "Status", "Loading...", 640, 568, 600, 28, { Color = rgb(225, 225, 232), ZIndex = 6 })

	-- Progress: nine rarity donuts between two glowing lines
	for _, side in { -1, 1 } do
		local line = box(stage, "ProgressLine", 640 + side * 420, 625, 380, 2, { Color = GREY, ZIndex = 4 })
		fade(if side < 0 then { { 0, 1 }, { 1, 0.35 } } else { { 0, 0.35 }, { 1, 1 } }).Parent = line
	end
	local icons = {}
	for i, color in RARITY_COLORS do
		local x = 640 + (i - 5) * 50
		local glow = box(stage, "IconGlow", x, 625, 54, 54, { Color = color, Transparency = 1, ZIndex = 4 })
		corner().Parent = glow
		local _, edge = ring(stage, "Icon", x, 625, 36, 14, rgb(64, 64, 74), 5)
		icons[i] = { Ring = edge, Glow = glow, Color = color, Lit = false }
	end

	local tip = text(stage, "Tip", "", 640, 690, 1000, 22, { Color = rgb(140, 140, 152), ZIndex = 6 })

	-- Skip
	local skip = new("TextButton", {
		Name = "Skip",
		Text = "SKIP  ⏭",
		Font = TEXT_FONT,
		TextSize = 18,
		TextColor3 = WHITE,
		AutoButtonColor = true,
		BackgroundColor3 = rgb(30, 30, 38),
		BackgroundTransparency = 0.2,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -24),
		Size = UDim2.fromOffset(130, 44),
		ZIndex = 20,
		Parent = gui,
	}, { corner(22) :: Instance, stroke(2, WHITE, 0.55) })

	local blackout = new("Frame", { Name = "Blackout", BackgroundColor3 = rgb(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = gui })

	local screen = {} :: Screen
	screen.Gui = gui
	screen.Skipped = signal()
	screen.Closed = signal()
	local progress = 0
	local baseStatus = "Loading"
	local closing = false
	local t = 0

	function screen.SetProgress(value: number)
		progress = math.clamp(value, 0, 1)
		local lit = math.floor(progress * #icons + 1e-6)
		for i, icon in icons do
			local on = i <= lit
			if on ~= icon.Lit then
				icon.Lit = on
				icon.Ring.Color = if on then icon.Color else rgb(64, 64, 74)
				icon.Glow.BackgroundTransparency = if on then 0.8 else 1
			end
		end
	end

	function screen.SetStatus(value: string)
		baseStatus = value
	end

	function screen.SetTip(index: number)
		tip.Text = LoadingUI.Tips[(index - 1) % #LoadingUI.Tips + 1]
	end

	function screen.Step(dt: number)
		t += dt
		wheel.Rotation = (t * 9) % 360
		donut.Rotation = math.sin(t * 1.6) * 4
		for _, r in rays do
			local sway = math.sin(t * 0.5 + r.Phase) * 2.5
			r.Ray.Rotation = r.Angle + sway
			r.Halo.Rotation = r.Angle + sway
		end
		local dots = string.rep(".", math.floor(t * 2.5) % 4)
		status.Text = if baseStatus == "Loading" then `Loading{dots}  {math.floor(progress * 100)}%` else baseStatus
		-- the next donut to light up pulses
		local nextIcon = icons[math.floor(progress * #icons + 1e-6) + 1]
		if nextIcon then
			nextIcon.Glow.BackgroundTransparency = 0.88 + math.sin(t * 6) * 0.06
		end
	end

	function screen.Close(instant: boolean?)
		if closing then
			return
		end
		closing = true
		local function finish()
			gui:Destroy()
			screen.Closed:Fire()
		end
		if instant then
			finish()
			return
		end
		-- fade to black, drop the screen, then fade the black away into the game
		TweenService:Create(blackout, TweenInfo.new(0.35), { BackgroundTransparency = 0 }):Play()
		task.delay(0.4, function()
			background.Visible = false
			stage.Visible = false
			skip.Visible = false
			TweenService:Create(blackout, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
			task.delay(0.65, finish)
		end)
	end

	skip.Activated:Connect(function()
		screen.Skipped:Fire()
		screen.Close()
	end)

	screen.SetTip(math.random(1, #LoadingUI.Tips))
	screen.SetProgress(0)
	screen.Step(0)
	return screen
end

-- How far along loading is (0-1), and whether everything is in.
local function measure(player: Player, state: { [string]: any }): (number, boolean)
	local loaded = true
	pcall(function()
		loaded = game:IsLoaded()
	end)
	local map = workspace:FindFirstChild("Map") ~= nil
	local data = player:GetAttribute("Speed") ~= nil -- the server sets your stats once your save has loaded
	local queue = 0
	pcall(function()
		queue = game:GetService("ContentProvider").RequestQueueSize
	end)
	state.MaxQueue = math.max(state.MaxQueue or 0, queue)
	local downloads = if state.MaxQueue > 0 then 1 - queue / state.MaxQueue else 1
	if not loaded then
		downloads = math.min(downloads, 0.5)
	end
	local value = (if loaded then 0.25 else 0) + (if map then 0.15 else 0) + (if data then 0.25 else 0) + 0.35 * downloads
	return value, loaded and map and data and queue <= 2
end

-- Shows the loading screen until the game has loaded (or the player skips it).
function LoadingUI.Run(player: Player): Screen
	player:SetAttribute("LoadingScreen", true)
	local screen = LoadingUI.Build(player:WaitForChild("PlayerGui"))
	local state = {}
	local shown = 0
	local elapsed = 0
	local tipTimer = 0
	local tipIndex = math.random(1, #LoadingUI.Tips)
	local done = false
	local connection: RBXScriptConnection
	local function stop()
		if connection then
			connection:Disconnect()
		end
		player:SetAttribute("LoadingScreen", nil)
	end
	screen.Closed:Connect(stop)
	screen.Skipped:Connect(function()
		player:SetAttribute("LoadingScreen", nil)
	end)
	connection = RunService.RenderStepped:Connect(function(dt: number)
		elapsed += dt
		local target, ready = measure(player, state)
		if elapsed >= MAX_SECONDS then
			target, ready = 1, true
		end
		-- ease towards the real progress (never backwards)
		shown = math.max(shown, shown + (target - shown) * math.min(1, dt * 3))
		if ready and elapsed >= MIN_SECONDS then
			shown = math.min(1, shown + dt * 1.5)
		end
		screen.SetProgress(shown)
		tipTimer += dt
		if tipTimer >= 4 then
			tipTimer = 0
			tipIndex += 1
			screen.SetTip(tipIndex)
		end
		screen.Step(dt)
		if not done and shown >= 0.999 then
			done = true
			screen.SetStatus("Ready!")
			task.delay(0.4, screen.Close)
		end
	end)
	return screen
end

return LoadingUI
