--[[
	LoadingUI: the loading screen you see while the game loads in.

	Plain and calm: a grayish-black screen (a little lighter in the middle) with "Loading: 42%" in
	white in the middle, and a small SKIP button in the corner that closes it straight away. When
	it's done it fades out into the game.

	It waits for: the place to load (every part of the map), the Map, your saved data and the queue
	of images / sounds to download. It stays at least MIN_SECONDS (no flash) and at most MAX_SECONDS.

	This runs from ReplicatedFirst before anything else has arrived, so it can't use the game's
	shared modules. While it's up, the local player has the attribute LoadingScreen = true (the
	Update Log and the opening scene wait for it).
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LoadingUI = {}

local MIN_SECONDS = 2.5
local MAX_SECONDS = 45

local rgb = Color3.fromRGB
local WHITE = rgb(255, 255, 255)
local BACKGROUND = rgb(17, 19, 24) -- grayish black
local CENTRE = rgb(30, 33, 40) -- (a little lighter in the middle)
local FONT = Enum.Font.Gotham

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

type Signal = { Connect: (Signal, () -> ()) -> (), Fire: (Signal) -> () }

export type Screen = {
	Gui: ScreenGui,
	SetProgress: (progress: number) -> (),
	SetStatus: (status: string) -> (),
	Close: (instant: boolean?) -> (),
	Skipped: Signal,
	Closed: Signal,
	Step: (dt: number) -> (),
}

-- Builds the screen (shown right away).
function LoadingUI.Build(parent: Instance): Screen
	local gui = Instance.new("ScreenGui")
	gui.Name = "LoadingScreen"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	local background = Instance.new("Frame")
	background.Name = "Background"
	background.BorderSizePixel = 0
	background.BackgroundColor3 = WHITE
	background.Size = UDim2.fromScale(1, 1)
	background.Parent = gui
	-- (dark at the edges, a touch lighter in the middle)
	local shade = Instance.new("UIGradient")
	shade.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, BACKGROUND), ColorSequenceKeypoint.new(0.5, CENTRE), ColorSequenceKeypoint.new(1, BACKGROUND) })
	shade.Rotation = 90
	shade.Parent = background
	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.AnchorPoint = Vector2.new(0.5, 0.5)
	status.Position = UDim2.fromScale(0.5, 0.5)
	status.Size = UDim2.new(1, 0, 0, 40)
	status.Font = FONT
	status.TextSize = 26
	status.TextColor3 = WHITE
	status.Text = "Loading: 0%"
	status.Parent = gui
	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.AnchorPoint = Vector2.new(1, 1)
	skip.Position = UDim2.new(1, -20, 1, -20)
	skip.Size = UDim2.fromOffset(84, 32)
	skip.BackgroundColor3 = rgb(44, 47, 56)
	skip.BackgroundTransparency = 0.2
	skip.BorderSizePixel = 0
	skip.Font = FONT
	skip.TextSize = 15
	skip.TextColor3 = rgb(200, 202, 210)
	skip.Text = "SKIP"
	skip.AutoButtonColor = true
	skip.Parent = gui
	local skipCorner = Instance.new("UICorner")
	skipCorner.CornerRadius = UDim.new(0, 8)
	skipCorner.Parent = skip
	gui.Parent = parent

	local screen = {} :: Screen
	screen.Gui = gui
	screen.Skipped = signal()
	screen.Closed = signal()
	local progress = 0
	local baseStatus = "Loading"
	local closing = false

	function screen.SetProgress(value: number)
		progress = math.clamp(value, 0, 1)
	end

	function screen.SetStatus(value: string)
		baseStatus = value
	end

	function screen.Step(_: number)
		status.Text = if baseStatus == "Loading" then `Loading: {math.floor(progress * 100)}%` else baseStatus
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
		-- fade out into the game
		local info = TweenInfo.new(0.6, Enum.EasingStyle.Quad)
		TweenService:Create(background, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(status, info, { TextTransparency = 1 }):Play()
		TweenService:Create(skip, info, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		task.delay(0.65, finish)
	end

	skip.Activated:Connect(function()
		screen.Skipped:Fire()
		screen.Close()
	end)

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
		screen.Step(dt)
		if not done and shown >= 0.999 then
			done = true
			screen.SetStatus("Loading: 100%")
			task.delay(0.4, screen.Close)
		end
	end)
	return screen
end

return LoadingUI
