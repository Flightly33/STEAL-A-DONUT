--[[
	LoadingUI: the loading screen you see while the game loads in.

	A purple stage with spotlights from above and, in 3D, the bandit donut: a brick donut in a mask
	and a crown with six little donuts in the rarity colours and sprinkles floating round it (made
	in Blender: art/loading_screen, built here from LoadingScene in a ViewportFrame; the camera
	sways slowly from side to side). Under it the title, "Loading... 42%", a row of nine donuts in
	the rarity colours that light up one by one as things load, and a tip at the bottom.
	A SKIP button (bottom right) closes it straight away.

	It waits for: the place to load (every part of the map), the Map, your saved data and the queue
	of images / sounds to download. It stays at least MIN_SECONDS (no flash) and at most MAX_SECONDS.

	This runs from ReplicatedFirst before anything else has arrived, so it can't use the game's
	shared modules: colours and fonts are copied in here.
	While it's up, the local player has the attribute LoadingScreen = true (the Update Log waits).
	Pictures instead (once they're uploaded to Roblox):
	  KEY_ART_IMAGE - art/loading_screen/key_art.jpg: the same scene rendered in Blender (soft light,
	                  shadows, a glowing stage). It replaces the stage, spotlights and 3D scene.
	  LOGO_IMAGE    - branding/logo.png in place of the 3D scene.
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LoadingScene = require(script.Parent:WaitForChild("LoadingScene"))

local LoadingUI = {}

local KEY_ART_IMAGE = "" -- e.g. "rbxassetid://123456789"
local LOGO_IMAGE = ""
local MIN_SECONDS = 2.5
local MAX_SECONDS = 45
local DESIGN = Vector2.new(1280, 720)

local rgb = Color3.fromRGB
local WHITE = rgb(255, 255, 255)
local BACKGROUND = rgb(24, 13, 38)
local STAGE_GLOW = rgb(200, 90, 220)
local GREY = rgb(150, 150, 162)
local OUTLINE = rgb(25, 18, 20)
local TITLE_FONT = Enum.Font.LuckiestGuy
local TEXT_FONT = Enum.Font.GothamBold

-- One donut per rarity, Common -> Icon (the same colours as Rarities.luau)
local RARITY_COLORS = {
	rgb(215, 215, 215), rgb(85, 225, 90), rgb(55, 150, 255), rgb(190, 70, 255), rgb(255, 190, 25),
	rgb(255, 110, 255), rgb(255, 255, 255), rgb(255, 40, 40), rgb(40, 140, 255),
}

LoadingUI.Tips = {
	"Tip: Run on your treadmill to get faster than Domer!",
	"Tip: Rarer donuts glow brighter. Look for the shiny ones!",
	"Tip: Click a box in your pen when its timer runs out to open it.",
	"Tip: Grab a box and run! Domer always takes it back if he catches you.",
	"Tip: Hatch eggs to get pets that boost your money and speed.",
	"Tip: Press X to hide the UI for screenshots.",
	"Tip: Use Claim All in the Index to grab every reward at once.",
	"Tip: Domer sleeps until you grab a box. Then RUN!",
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

-- The 3D scene (LoadingScene, made in Blender): every block is a part in a ViewportFrame the size
-- of the stage, seen through the scene's own camera. Returns the camera (Step sways it).
local function buildScene(stage: Frame): Camera
	local view = new("ViewportFrame", {
		Name = "Scene",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(DESIGN.X, DESIGN.Y),
		Ambient = rgb(165, 150, 185),
		LightColor = rgb(255, 246, 236),
		LightDirection = Vector3.new(1, -1.3, -1), -- (from the top left, in front)
		ZIndex = 3,
		Parent = stage,
	})
	local camera = new("Camera", {
		FieldOfView = LoadingScene.Camera.FieldOfView,
		CFrame = CFrame.lookAt(LoadingScene.Camera.Position, LoadingScene.Camera.Target),
		Parent = view,
	})
	view.CurrentCamera = camera
	for _, group in LoadingScene.Groups do
		for _, block in group.Blocks do
			local part = Instance.new("Part")
			part.Name = group.Name
			part.Anchored = true
			part.CanCollide = false
			part.CastShadow = false
			part.Shape = if block.Shape == "Cylinder" then Enum.PartType.Cylinder else Enum.PartType.Block
			part.Size = block.Size
			part.CFrame = group.Pivot * block.Offset
			part.Color = block.Color
			part.Material = block.Material
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			part.Parent = view
		end
	end
	return camera
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
	if KEY_ART_IMAGE ~= "" then
		-- the Blender picture fills the screen (cropped to fit, never stretched)
		new("ImageLabel", { Name = "KeyArt", Image = KEY_ART_IMAGE, ScaleType = Enum.ScaleType.Crop, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = background })
	end
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

	-- Spotlights fanning down from above the donut (the key art has its own)
	local rays = {}
	for i, angle in (if KEY_ART_IMAGE ~= "" then {} else { -38, -22, -9, 9, 22, 38 }) :: { number } do
		local length = 1150
		local width = if math.abs(angle) < 15 then 150 else 230
		local theta = math.rad(angle)
		local x = 640 - math.sin(theta) * length / 2
		local y = -90 + math.cos(theta) * length / 2
		local ray = box(stage, "Spotlight", x, y, width, length, { Color = rgb(255, 235, 255), Rotation = angle, Transparency = 0 })
		fade({ { 0, 0.9 }, { 0.4, 0.96 }, { 1, 1 } }, 90).Parent = ray
		-- softer, wider halo around each beam
		local halo = box(stage, "SpotlightHalo", x, y, width * 2.2, length, { Rotation = angle, Transparency = 0 })
		fade({ { 0, 0.97 }, { 0.4, 0.99 }, { 1, 1 } }, 90).Parent = halo
		rays[i] = { Ray = ray, Halo = halo, Angle = angle, Phase = i * 1.7 }
	end

	-- A pink glow behind the donut, and sparkles round it (four-pointed stars: two crossed beams,
	-- fading towards their tips), between the little donuts
	local sparkles: { { number } } = if KEY_ART_IMAGE ~= "" then {} else { { 300, 185, 110, 0.5 }, { 980, 185, 110, 0.5 }, { 505, 62, 54, 0.55 }, { 780, 66, 46, 0.55 } }
	if KEY_ART_IMAGE == "" then
		for i, size in { 620, 440, 280 } do
			local glow = box(stage, "Glow", 640, 172, size, size * 0.8, { Color = STAGE_GLOW, Transparency = 0.93 - i * 0.015 })
			corner().Parent = glow
		end
	end
	for _, s in sparkles do
		for _, rotation in { 0, 90 } do
			local beam = box(stage, "Sparkle", s[1], s[2], s[3] * 0.12, s[3] * 0.8, { Color = GREY, Transparency = s[4], Rotation = rotation, ZIndex = 2 })
			fade({ { 0, 1 }, { 0.5, 0 }, { 1, 1 } }, 90).Parent = beam
		end
	end

	-- the 3D scene, or a picture (the key art has the scene in it already)
	local camera: Camera? = nil
	if LOGO_IMAGE ~= "" and KEY_ART_IMAGE == "" then
		new("ImageLabel", { Name = "Logo", Image = LOGO_IMAGE, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(640, 180), Size = UDim2.fromOffset(300, 300), ZIndex = 3, Parent = stage })
	elseif KEY_ART_IMAGE == "" then
		camera = buildScene(stage)
	end
	local cameraHome = if camera then camera.CFrame else CFrame.identity

	-- Title
	-- a soft pink glow behind the title, fading out to the sides
	local titleGlow = box(stage, "TitleGlow", 640, 420, 760, 150, { Color = STAGE_GLOW, ZIndex = 4 })
	corner().Parent = titleGlow
	fade({ { 0, 1 }, { 0.5, 0.9 }, { 1, 1 } }).Parent = titleGlow
	local stealA = text(stage, "TitleTop", "STEAL A", 640, 352, 600, 64, { Font = TITLE_FONT, Stroke = 5, ZIndex = 6 })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, rgb(205, 205, 215)), Parent = stealA })
	local title = text(stage, "Title", "DONUT!", 640, 430, 760, 118, { Font = TITLE_FONT, Stroke = 7, ZIndex = 6 })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(rgb(255, 250, 225), rgb(255, 200, 70)), Parent = title })
	-- ornament under the title: fading lines and a diamond
	for _, side in { -1, 1 } do
		local line = box(stage, "Ornament", 640 + side * 170, 505, 300, 3, { Color = GREY, ZIndex = 4 })
		fade(if side < 0 then { { 0, 1 }, { 1, 0.3 } } else { { 0, 0.3 }, { 1, 1 } }).Parent = line
	end
	box(stage, "OrnamentGem", 640, 505, 13, 13, { Color = rgb(255, 170, 210), Rotation = 45, ZIndex = 5 })

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
		local frame, edge = ring(stage, "Icon", x, 625, 36, 14, rgb(64, 64, 74), 5)
		-- (square, like the brick donuts)
		local iconCorner = frame:FindFirstChildOfClass("UICorner") :: UICorner
		iconCorner.CornerRadius = UDim.new(0, 3)
		local glowCorner = glow:FindFirstChildOfClass("UICorner") :: UICorner
		glowCorner.CornerRadius = UDim.new(0, 14)
		icons[i] = { Ring = edge, Glow = glow, Color = color, Lit = false }
	end

	local tip = text(stage, "Tip", "", 640, 690, 1000, 22, { Color = rgb(140, 140, 152), ZIndex = 6 })

	-- Skip
	local skip = new("TextButton", {
		Name = "Skip",
		Text = "SKIP",
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
		if camera then
			-- sway slowly from side to side round the donut, bobbing a little
			local sway = math.rad(math.sin(t * 0.55) * 9)
			local pivot = CFrame.new(0, -0.9, 0)
			camera.CFrame = pivot * CFrame.Angles(0, sway, 0) * pivot:Inverse() * cameraHome * CFrame.new(0, math.sin(t * 1.3) * 0.35, 0)
		end
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
