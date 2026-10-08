--[[
	Server event announcement (EventService / Events.luau).

	When an event starts, a big announcement drops in near the top of the screen in the game's
	message style (outlined letters on a dark band that fades out at its ends, lines of the event's
	colour along it): "SERVER EVENT", its name in its colour, what it does and how long it lasts,
	with a little fanfare, pulsing so nobody misses it. After a few seconds it shrinks into a
	smaller band at the top of the screen with a countdown, which stays until the event ends.
	Players who join mid-event just get that.

	Also the countdown to the next Eternal Storm ("ETERNAL STORM IN 1:23:45"): it comes on the real
	clock (shared/StormClock), so this is worked out right here, the same on every server. It sits
	in the first free row at the top (under the Luck Event, event and box pills when they're up)
	and hides while the storm is on (the event pill counts that down).
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Events = require(Shared.Events)
local Format = require(Shared.Format)
local StormClock = require(Shared.StormClock)

local Theme = require(script.Parent.Theme)

local EventBanner = {}

local gui: ScreenGui
local holder: Frame -- screen-size scaling for the big card (the card has its own pop-in scale)
local pill: Frame
local pillLabel: TextLabel
local card: Frame? = nil
local countdown: Frame
local countdownLabel: TextLabel
local otherPills: { [string]: GuiObject } = {} -- (the Luck Event and box pills, once found)

local STORM_TEXT = Color3.fromRGB(235, 215, 255)
local STORM_SOON = Color3.fromRGB(255, 140, 225)

-- "1:23:45", or "4:05" under an hour.
local function clockText(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local h, m, sec = s // 3600, (s % 3600) // 60, s % 60
	return if h > 0 then string.format("%d:%02d:%02d", h, m, sec) else string.format("%d:%02d", m, sec)
end

-- The first row at the top of the screen that nothing else is using.
local function freeRow(): number
	local taken: { [number]: boolean } = {}
	if pill.Visible then
		taken[pill.Position.Y.Offset] = true
	end
	local playerGui = gui.Parent
	for _, name in { "LuckEvent", "BoxPill" } do
		local other = otherPills[name]
		if not other and playerGui then
			local found = playerGui:FindFirstChild(name, true)
			if found and found:IsA("GuiObject") then
				otherPills[name] = found
				other = found
			end
		end
		if other and other.Visible then
			taken[other.Position.Y.Offset] = true
		end
	end
	for _, row in { 4, 46, 88, 130 } do
		if not taken[row] then
			return row
		end
	end
	return 172
end

local function updateCountdown()
	local now = workspace:GetServerTimeNow()
	local schedule = Config.EternalStorm.Schedule
	countdown.Visible = schedule.Enabled and workspace:GetAttribute("EventId") ~= "EternalStorm" and StormClock.Current(now) == nil
	if not countdown.Visible then
		return
	end
	local left = StormClock.Next(now) - now
	countdownLabel.Text = `ETERNAL STORM IN {clockText(left)}`
	-- the last minute: brighter, pulsing
	countdownLabel.TextColor3 = if left <= 60 then STORM_TEXT:Lerp(STORM_SOON, 0.5 + 0.5 * math.sin(now * 6)) else STORM_TEXT
	countdown.Position = UDim2.new(0.5, 0, 0, freeRow())
end

local function endsIn(): number
	local endsAt = workspace:GetAttribute("EventEndsAt")
	return if type(endsAt) == "number" then math.max(0, endsAt - workspace:GetServerTimeNow()) else 0
end

local function fanfare()
	Theme.PlaySound("Event")
end

local function showCard(event: Events.Event)
	if card then
		card:Destroy()
	end
	local frame = Theme.Band({
		Name = "EventCard",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromScale(1, 1),
		Darkness = 0.62,
		Parent = holder,
	})
	-- a line of the event's colour along the top and the bottom, fading out like the band
	local lines = {}
	for i, y in { 0, 1 } do
		local line = Theme.Band({ Name = "Line" .. i, AnchorPoint = Vector2.new(0, y), Position = UDim2.fromScale(0, y), Size = UDim2.new(1, 0, 0, 4), Darkness = 1, Parent = frame })
		line.BackgroundColor3 = event.Color
		table.insert(lines, line)
	end
	Theme.Label({ Name = "Kicker", Text = "SERVER EVENT", Font = Theme.Font, TextColor3 = Color3.fromRGB(255, 255, 255), Size = UDim2.new(1, -200, 0, 26), Position = UDim2.fromOffset(100, 12), StrokeThickness = 2.5, Parent = frame })
	Theme.Label({ Name = "EventName", Text = string.upper(Format.Plain(event.Name)), TextColor3 = event.Color:Lerp(Color3.new(1, 1, 1), 0.15), Size = UDim2.new(1, -160, 0, 62), Position = UDim2.fromOffset(80, 38), StrokeThickness = 4.5, Parent = frame })
	Theme.Label({ Name = "Description", Text = Format.Plain(event.Description), Font = Theme.Font, Size = UDim2.new(1, -200, 0, 30), Position = UDim2.fromOffset(100, 102), StrokeThickness = 2.5, Parent = frame })
	local timer = Theme.Label({ Name = "Timer", Text = "", Font = Theme.Font, TextColor3 = Color3.fromRGB(255, 240, 170), Size = UDim2.new(1, -200, 0, 24), Position = UDim2.fromOffset(100, 134), StrokeThickness = 2, Parent = frame })
	card = frame

	-- Pop in, then pulse
	local scale = Theme.new("UIScale", { Scale = 0.2, Parent = frame })
	TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	fanfare()
	local startedAt = os.clock()
	task.spawn(function()
		while frame.Parent and os.clock() - startedAt < 7 do
			local t = os.clock() - startedAt
			if t > 0.5 then
				scale.Scale = 1 + math.sin(t * 6) * 0.03
			end
			for _, line in lines do
				line.BackgroundColor3 = event.Color:Lerp(Color3.new(1, 1, 1), 0.3 + 0.3 * math.sin(t * 5))
			end
			timer.Text = `{Format.Duration(endsIn())} left`
			task.wait()
		end
		if frame.Parent then
			-- Shrink into the band at the top
			TweenService:Create(scale, TweenInfo.new(0.35), { Scale = 0.1 }):Play()
			TweenService:Create(frame, TweenInfo.new(0.35), { Position = UDim2.new(0.5, 0, 0, -60), BackgroundTransparency = 1 }):Play()
			task.wait(0.35)
			frame:Destroy()
			if card == frame then
				card = nil
			end
		end
	end)
end

function EventBanner.Init()
	gui = Theme.ScreenGui("EventBanner", 25)
	holder = Theme.new("Frame", {
		Name = "CardHolder",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(860, 170),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Theme.AutoScale(holder)
	pill = Theme.Band({
		Name = "EventPill",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.fromOffset(560, 38),
		Darkness = 0.6,
		Visible = false,
		Parent = gui,
	})
	Theme.AutoScale(pill)
	pillLabel = Theme.Label({ Name = "Text", Text = "", Font = Theme.Font, Size = UDim2.new(1, -120, 1, -6), Position = UDim2.fromOffset(60, 3), StrokeThickness = 2.5, Parent = pill })
	countdown = Theme.Band({
		Name = "StormCountdown",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.fromOffset(440, 36),
		Darkness = 0.6,
		Visible = false,
		Parent = gui,
	})
	Theme.AutoScale(countdown)
	countdownLabel = Theme.Label({ Name = "Text", Text = "", Font = Theme.Font, TextColor3 = STORM_TEXT, Size = UDim2.new(1, -110, 1, -6), Position = UDim2.fromOffset(55, 3), StrokeThickness = 2.5, Parent = countdown })
	task.spawn(function()
		while true do
			updateCountdown()
			task.wait(0.25)
		end
	end)

	local shownId: string? = workspace:GetAttribute("EventId") :: string? -- (joined mid-event: pill only)
	workspace:GetAttributeChangedSignal("EventId"):Connect(function()
		local id = workspace:GetAttribute("EventId")
		local event = if type(id) == "string" then Events.ById[id] else nil
		if event and id ~= shownId then
			showCard(event)
		end
		shownId = if type(id) == "string" then id else nil
	end)

	task.spawn(function()
		while true do
			local id = workspace:GetAttribute("EventId")
			local event = if type(id) == "string" then Events.ById[id] else nil
			local left = endsIn()
			pill.Visible = event ~= nil and left > 0 and card == nil
			if event and pill.Visible then
				pillLabel.TextColor3 = event.Color:Lerp(Color3.new(1, 1, 1), 0.35)
				pillLabel.Text = `{string.upper(Format.Plain(event.Name))}  •  {Format.Duration(left)}`
				-- Sit under the Luck Event pill when both are running
				local luckEndsAt = workspace:GetAttribute("LuckEndsAt")
				local luck = type(luckEndsAt) == "number" and luckEndsAt > workspace:GetServerTimeNow()
				pill.Position = UDim2.new(0.5, 0, 0, if luck then 46 else 4)
			end
			task.wait(0.5)
		end
	end)
end

return EventBanner
