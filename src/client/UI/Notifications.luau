--[[
	Notifications: everything that tells you something at the top of the screen, in ONE column down
	its middle, so nothing ever lands on top of anything else. From the top:
	  * pills (Notifications.Pill): small lines that stay up a while - the Luck Event, the server
	    event, the box timer, the countdown to the next Eternal Storm, Cosmic Domer's boss bar
	  * the header: ONE big message at a time (Notifications.Banner, ShowHeader): a biome's name as
	    you walk in, announcements, a server event starting, "BOX SECURED!"... A new one fades out
	    whatever was there instead of landing on top of it. The tutorial is the header for as long
	    as it runs (SetPersistentHeader): biome names wait their turn, and anything more important
	    takes over for a few seconds, then the tutorial fades back in
	  * the chase banner (Chase: ChaseSlot)
	  * toasts (Notifications.Toast), newest first
	All of it is big outlined letters on dark bands that fade out at their ends - never a box, never
	an emoji (Format.Plain takes them out of anything the server sends).
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local Theme = require(script.Parent.Theme)

local Notifications = {}

-- How important a header is: a less important one never replaces a more important one.
Notifications.Priority = {
	News = 1, -- a biome's name as you walk in
	Tutorial = 2,
	Announcement = 3, -- everything else
}

-- The text's colour for each kind of toast
local KIND_COLORS = {
	info = Color3.fromRGB(255, 255, 255),
	success = Color3.fromRGB(140, 255, 120),
	error = Color3.fromRGB(255, 120, 110),
	rare = Color3.fromRGB(255, 220, 90),
	event = Color3.fromRGB(255, 150, 220),
}

local KIND_SOUNDS = {
	info = "Notify",
	success = "Success",
	error = "Error",
	rare = "Rare",
	event = "Announce",
}

local WIDTH = 960 -- the column (before the screen's UI scale)
local FADE = 0.3

type Header = { Group: CanvasGroup, Priority: number, Height: number }

local column: Frame
local pills: Frame
local headerSlot: Frame
local chaseSlot: Frame
local toastHolder: Frame
local toastCounter = 0
local current: Header? = nil -- the header showing now (not the tutorial)
local persistent: Header? = nil -- the tutorial's
local persistentShown = false
local token = 0

--------------------------------------------------------------------------------
-- The header
--------------------------------------------------------------------------------
-- The slot is as tall as what's in it (nothing: it folds away, and everything under it moves up).
local function resize()
	local height = 0
	if current then
		height = current.Height
	elseif persistent and persistentShown then
		height = persistent.Height
	end
	headerSlot.Size = UDim2.new(1, 0, 0, height)
	headerSlot.Visible = height > 0
end

local function fade(header: Header, visible: boolean, after: (() -> ())?)
	local group = header.Group
	if visible then
		group.Visible = true
	end
	local tween = TweenService:Create(group, TweenInfo.new(FADE, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { GroupTransparency = if visible then 0 else 1 })
	tween:Play()
	if not visible or after then
		task.delay(FADE, function()
			if not visible and group.GroupTransparency >= 0.99 then
				group.Visible = false
			end
			if after then
				after()
			end
		end)
	end
end

local function wrap(content: GuiObject, priority: number, name: string): Header
	local height = content.Size.Y.Offset
	local group = Theme.new("CanvasGroup", {
		Name = name,
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
		Visible = false,
		Parent = headerSlot,
	})
	content.AnchorPoint = Vector2.new(0.5, 0)
	content.Position = UDim2.fromScale(0.5, 0)
	content.Parent = group
	return { Group = group, Priority = priority, Height = height }
end

-- Show `content` (a full-width frame, its height in pixels) as the header for `duration` seconds.
-- Whatever was there fades out first (the tutorial fades back in afterwards). Something less
-- important than what's showing is dropped (returns false).
function Notifications.ShowHeader(content: GuiObject, priority: number, duration: number): boolean
	local blocked = (current and current.Priority > priority) or (persistent and persistentShown and persistent.Priority > priority)
	if blocked then
		content:Destroy()
		return false
	end
	local old = current
	if old then
		fade(old, false, function()
			old.Group:Destroy()
		end)
	end
	if persistent and persistentShown then
		fade(persistent, false)
	end
	local header = wrap(content, priority, "Header")
	current = header
	resize()
	fade(header, true)
	token += 1
	local myToken = token
	task.delay(duration, function()
		if current == header and token == myToken then
			current = nil
			fade(header, false, function()
				header.Group:Destroy()
				resize()
			end)
			if persistent and persistentShown then
				fade(persistent, true)
			end
		end
	end)
	return true
end

-- The tutorial: `content` is the header whenever `shown` (under anything more important that
-- comes and goes). Always the same content: it's kept between steps.
function Notifications.SetPersistentHeader(content: GuiObject, shown: boolean)
	if not persistent or persistent.Group ~= content.Parent then
		if persistent then
			persistent.Group:Destroy()
		end
		persistent = wrap(content, Notifications.Priority.Tutorial, "Persistent")
	end
	local header = persistent :: Header
	if shown == persistentShown then
		return
	end
	persistentShown = shown
	if shown then
		if not current then
			fade(header, true)
		end
		resize()
	else
		-- (the slot folds away once it has faded out)
		fade(header, false, resize)
	end
end

-- Is something other than the tutorial in the header right now? (tests)
function Notifications.HeaderBusy(): boolean
	return current ~= nil
end

--------------------------------------------------------------------------------
-- Pills, the chase banner and toasts
--------------------------------------------------------------------------------
-- Put a small pill (a frame with its own fixed size) in the stack at the top. `order`: where in it.
function Notifications.Pill(pill: GuiObject, order: number)
	pill.LayoutOrder = order
	pill.Parent = pills
end

-- Where the chase banner goes (under the header).
function Notifications.ChaseSlot(): Frame
	return chaseSlot
end

function Notifications.Toast(text: string, kind: string?)
	local color = KIND_COLORS[kind or "info"] or KIND_COLORS.info
	toastCounter -= 1 -- newest first
	local toast = Theme.Band({ Name = "Toast", Size = UDim2.fromOffset(620, 36), LayoutOrder = toastCounter, Darkness = 0.62, Parent = toastHolder })
	local label = Theme.Label({ Name = "Text", Text = Format.Plain(text), Font = Theme.Font, TextColor3 = color, Size = UDim2.new(1, -120, 1, -6), Position = UDim2.fromOffset(60, 3), StrokeThickness = 2.5, Parent = toast })
	-- A soft chime for each kind (skipped if another sound just played, like the steal jingle)
	if Theme.SinceSound() > 0.35 then
		Theme.PlaySound(KIND_SOUNDS[kind or "info"] or "Notify")
	end

	-- Keep at most 3 toasts
	local toasts = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 4, #toasts do
		toasts[i]:Destroy()
	end

	task.delay(3.5, function()
		if toast.Parent then
			TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			task.wait(0.4)
			toast:Destroy()
		end
	end)
end

-- A big message in the header: `text` big in `color`, `subtitle` under it. Big = even bigger
-- letters ("BOX SECURED!"). Priority: Notifications.Priority (Announcement unless given).
export type BannerOptions = { Priority: number?, Big: boolean? }
function Notifications.Banner(text: string, color: Color3, duration: number?, subtitle: string?, options: BannerOptions?)
	local o: BannerOptions = options or {}
	local titleHeight = if o.Big then 66 else 50
	local height = titleHeight + (if subtitle then 34 else 0) + 14
	local banner = Theme.Band({ Name = "Banner", Size = UDim2.new(1, 0, 0, height), Darkness = 0.55 })
	local title = Theme.Label({ Name = "Title", Text = Format.Plain(text), TextColor3 = color, Size = UDim2.new(1, -180, 0, titleHeight), Position = UDim2.fromOffset(90, 6), StrokeThickness = if o.Big then 5 else 3.5, Parent = banner })
	if subtitle then
		Theme.Label({ Name = "Subtitle", Text = Format.Plain(subtitle), Font = Theme.Font, Size = UDim2.new(1, -180, 0, 28), Position = UDim2.fromOffset(90, titleHeight + 8), TextColor3 = Theme.Colors.White, StrokeThickness = 2.5, Parent = banner })
	end
	if o.Big then
		-- (it pops in)
		local scale = Theme.new("UIScale", { Scale = 0.6, Parent = title })
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	Notifications.ShowHeader(banner, o.Priority or Notifications.Priority.Announcement, duration or 3)
end

function Notifications.Init()
	local gui = Theme.ScreenGui("Notifications", 20)
	column = Theme.new("Frame", {
		Name = "Column",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Theme.new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	Theme.AutoScale(column)
	local function slot(name: string, order: number, padding: number): Frame
		return Theme.new("Frame", {
			Name = name,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order,
			Parent = column,
		}, {
			Theme.new("UIListLayout", { Padding = UDim.new(0, padding), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
		})
	end
	pills = slot("Pills", 1, 4)
	headerSlot = Theme.new("Frame", { Name = "HeaderSlot", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), Visible = false, LayoutOrder = 2, Parent = column })
	chaseSlot = slot("ChaseSlot", 3, 0)
	toastHolder = slot("Toasts", 4, 6)

	Remotes.Event("Notify").OnClientEvent:Connect(function(text: string, kind: string?)
		Notifications.Toast(text, kind)
	end)
	Remotes.Event("AreaAnnouncement").OnClientEvent:Connect(function(text: string, color: Color3)
		Notifications.Banner(text, color, 5)
		Theme.PlaySound("Announce")
	end)
end

return Notifications
