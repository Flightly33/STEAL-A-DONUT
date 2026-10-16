--[[
	HUD: always-on screen UI in the chunky simulator style, kept away from Roblox's own UI (chat
	top-left, player list top-right, hotbar bottom-centre):
	  left   - big wide buttons, an icon and a bold name on each: Shop (green: upgrades, boosts,
	           crates, skins, trails and tips - UI/Shop), Inventory (purple: every item you're
	           carrying, UI/Hotbar's bag), Index (blue); and under them the Slow Mode switch (walk
	           at Config.Speed.SlowModeSpeed - handy round your base; off: as fast as you can)
	  right  - coloured squares with an icon and a name: Pets, + Admin, + Base after the base code,
	           + Teleport for Teleporter pass owners
	  top    - small round buttons in Roblox's top bar, top right: Daily Rewards (a "!" when one is
	           waiting) and Settings (music, run speed, Hide UI...)
	  stats  - bottom-left: Speed; Money with what you earn a second right after it (and a yellow +
	           for the money game passes); "Friend Boost: +N%" with a green + to invite friends
	  biomes - a banner at the top whenever you walk into a biome: its name, the Speed it needs and
	           how fast its Domer runs (server events show their time left in the pills up there too)
	  luck   - a pill at the top while a Luck Event runs (anyone can add 10 more minutes)
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Areas = require(Shared.Areas)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)

local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Notifications = require(script.Parent.Notifications)
local State = require(script.Parent.Parent.State)
local AreaTracker = require(script.Parent.Parent.AreaTracker)
local Bases = require(script.Parent.Parent.Bases)

local HUD = {}

export type Callbacks = {
	OpenShop: (tab: string?) -> (),
	OpenIndex: () -> (),
	OpenSettings: () -> (),
	OpenTeleport: () -> (),
	OpenBaseSize: () -> (),
	OpenPets: () -> (),
	OpenAdmin: () -> (),
	UnclaimedIndex: () -> number,
	TrailReady: () -> boolean,
	ReadyEggs: () -> number,
	OpenDaily: () -> (),
	DailyReady: () -> boolean,
	OpenInventory: () -> (),
}

-- Little red number bubble in a button's corner.
local function badge(button: GuiObject): TextLabel
	local bubble = Theme.Label({
		Name = "Badge",
		Text = "",
		Font = Theme.Font,
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.Colors.Red,
		Size = UDim2.fromOffset(26, 26),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		ZIndex = 5,
		StrokeThickness = 1.5,
		Visible = false,
		Parent = button,
	})
	Theme.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bubble })
	return bubble
end

-- A big wide button: a drawn icon on the left and its name in bold, on a bright colour with a chunky
-- dark outline (the left column)
local WIDE = Vector2.new(214, 64)
local function wideButton(parent: Instance, name: string, icon: string, caption: string, color: Color3, order: number): TextButton
	local button = Theme.new("TextButton", {
		Name = name,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(WIDE.X, WIDE.Y),
		LayoutOrder = order,
		Parent = parent,
	}, {
		Theme.Corner(10),
		Theme.Gradient(Theme.Lighten(color, 0.25), Theme.Darken(color, 0.15)),
	})
	Theme.new("UIStroke", { Thickness = 4, Color = Theme.Darken(color, 0.65), ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = button })
	-- (a thin light rim inside, like a chunky plastic button)
	Theme.new("Frame", {
		Name = "Rim",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -6, 1, -6),
		Position = UDim2.fromOffset(3, 3),
		Parent = button,
	}, { Theme.Corner(8), Theme.new("UIStroke", { Thickness = 2, Color = Theme.Lighten(color, 0.55), Transparency = 0.2 }) })
	local drawn = Icons.Draw(icon, button, color, {
		Size = UDim2.fromScale(0.92, 0.92),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
	})
	drawn.ZIndex = 2
	Theme.Label({ Name = "Caption", Text = caption, Size = UDim2.new(1, -78, 0.66, 0), Position = UDim2.new(0, 70, 0.17, 0), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 3.5, ZIndex = 3, Parent = button })
	button.MouseButton1Down:Connect(function()
		Theme.Bounce(button)
	end)
	return button
end

-- A coloured square with an icon and its name across the bottom (the right column)
local SQUARE = Vector2.new(92, 92)
local function squareButton(parent: Instance, name: string, icon: string, caption: string, color: Color3, order: number): TextButton
	local button = Theme.new("TextButton", {
		Name = name,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(SQUARE.X, SQUARE.Y),
		LayoutOrder = order,
		Parent = parent,
	}, {
		Theme.Corner(10),
		Theme.Gradient(Theme.Lighten(color, 0.25), Theme.Darken(color, 0.15)),
	})
	Theme.new("UIStroke", { Thickness = 4, Color = Theme.Darken(color, 0.65), ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = button })
	local drawn = Icons.Draw(icon, button, color, {
		Size = UDim2.fromScale(0.7, 0.7),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
	})
	drawn.ZIndex = 2
	Theme.Label({ Name = "Caption", Text = caption, Size = UDim2.new(1, -6, 0, 24), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3), StrokeThickness = 2.5, ZIndex = 3, Parent = button })
	button.MouseButton1Down:Connect(function()
		Theme.Bounce(button)
	end)
	return button
end

local GREEN = Color3.fromRGB(70, 200, 60)
local PURPLE = Color3.fromRGB(130, 80, 230)
local BLUE = Color3.fromRGB(40, 170, 245)

-- The Slow Mode switch: a pill with a sliding knob (lit when on) and its name beside it
local function buildSlowMode(parent: Instance)
	local row = Theme.new("Frame", { Name = "SlowMode", BackgroundTransparency = 1, Size = UDim2.fromOffset(WIDE.X, 48), LayoutOrder = 10, Parent = parent })
	local toggle = Theme.new("TextButton", {
		Name = "Toggle",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(40, 110, 50),
		Size = UDim2.fromOffset(88, 42),
		Position = UDim2.fromOffset(0, 3),
		Parent = row,
	}, {
		Theme.Corner(8),
		Theme.new("UIStroke", { Thickness = 3, Color = Color3.fromRGB(16, 40, 20) }),
	})
	local knob = Theme.new("Frame", {
		Name = "Knob",
		BackgroundColor3 = Color3.fromRGB(120, 230, 90),
		Size = UDim2.fromOffset(36, 32),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 5, 0.5, 0),
		Parent = toggle,
	}, { Theme.Corner(6), Theme.new("UIStroke", { Thickness = 2, Color = Color3.fromRGB(16, 40, 20) }) })
	Theme.Label({ Name = "Caption", Text = "Slow Mode", Size = UDim2.new(1, -98, 0.8, 0), Position = UDim2.new(0, 98, 0.1, 0), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 3, Parent = row })
	local function show()
		local on = State.Number("SpeedLimit") > 0
		row:SetAttribute("On", on)
		TweenService:Create(knob, TweenInfo.new(0.15), { Position = if on then UDim2.new(1, -41, 0.5, 0) else UDim2.new(0, 5, 0.5, 0) }):Play()
		knob.BackgroundColor3 = if on then Color3.fromRGB(150, 255, 110) else Color3.fromRGB(110, 200, 90)
		toggle.BackgroundColor3 = if on then Color3.fromRGB(60, 160, 60) else Color3.fromRGB(40, 110, 50)
	end
	toggle.Activated:Connect(function()
		Theme.Bounce(toggle)
		local on = State.Number("SpeedLimit") > 0
		State.Action("SetSpeedLimit", if on then 0 else Config.Speed.SlowModeSpeed)
	end)
	State.OnAttribute("SpeedLimit", show)
	show()
end

local function buildLeft(gui: ScreenGui, callbacks: Callbacks)
	local left = Theme.new("Frame", {
		Name = "LeftButtons",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.44, 0),
		Size = UDim2.fromOffset(WIDE.X + 8, 3 * (WIDE.Y + 10) + 56),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Theme.new("UIListLayout", { Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Left, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	Theme.AutoScale(left)

	local shop = wideButton(left, "Shop", "basket", "Shop", GREEN, 1)
	local inventory = wideButton(left, "Inventory", "backpack", "Inventory", PURPLE, 2)
	local index = wideButton(left, "Index", "indexBook", "Index", BLUE, 3)
	buildSlowMode(left)
	shop.Activated:Connect(function()
		callbacks.OpenShop(if callbacks.TrailReady() then "Trails" else "Upgrades")
	end)
	inventory.Activated:Connect(callbacks.OpenInventory)
	index.Activated:Connect(callbacks.OpenIndex)

	-- Badges: unclaimed Index rewards, a trail unlocked but not worn (the Shop's Trails)
	local indexBadge = badge(index)
	local shopBadge = badge(shop)
	shopBadge.Text = "!"
	local function updateBadges()
		local unclaimed = callbacks.UnclaimedIndex()
		indexBadge.Visible = unclaimed > 0
		indexBadge.Text = if unclaimed > 99 then "99+" else tostring(unclaimed)
		shopBadge.Visible = callbacks.TrailReady()
	end
	State.Changed:Connect(updateBadges)
	for _, name in { "Money", "Speed", "BestSpeed", "Trail" } do
		State.OnAttribute(name, updateBadges)
	end
end

local function buildRight(gui: ScreenGui, callbacks: Callbacks)
	-- (on phones and tablets the stats are at the top right: the squares sit a little lower there)
	local right = Theme.new("Frame", {
		Name = "RightButtons",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, if Theme.IsTouch then 0.58 else 0.5, 0),
		Size = UDim2.fromOffset(SQUARE.X + 8, 4 * (SQUARE.Y + 12)),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Theme.new("UIListLayout", {
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})
	Theme.AutoScale(right)

	local function button(name: string, icon: string, caption: string, color: Color3, order: number, onClick: () -> ()): TextButton
		local b = squareButton(right, name, icon, caption, color, order)
		b.Activated:Connect(onClick)
		return b
	end
	local pets = button("Pets", "pawPink", "Pets", Color3.fromRGB(255, 140, 40), 1, callbacks.OpenPets)
	local petsBadge = badge(pets)
	task.spawn(function()
		while true do
			-- (eggs finish hatching on their own)
			local ready = callbacks.ReadyEggs()
			petsBadge.Visible = ready > 0
			petsBadge.Text = tostring(ready)
			task.wait(2)
		end
	end)
	local admin = button("Admin", "toolsSteel", "Admin", Color3.fromRGB(110, 120, 140), 4, callbacks.OpenAdmin)
	admin.Visible = false
	-- The base code ("ender=rich"): just the bigger-base buttons
	local baseSize = button("Base", "buildingBlue", "Base", Color3.fromRGB(60, 110, 220), 3, callbacks.OpenBaseSize)
	baseSize.Visible = false
	State.OnAttribute("SizeAccess", function(value)
		baseSize.Visible = value == true
	end)
	-- Teleporter pass owners: jump to any biome. Everyone else walks.
	local teleport = button("Teleport", "globeBlue", "Teleport", Color3.fromRGB(40, 190, 200), 2, callbacks.OpenTeleport)
	local function showTeleport()
		teleport.Visible = State.Data.Passes ~= nil and State.Data.Passes.Teleporter == true
	end
	State.Changed:Connect(showTeleport)
	showTeleport()
	State.OnAttribute("Admin", function(value)
		admin.Visible = value == true
	end)
end

-- The green + next to Friend Boost: Roblox's own "invite friends" window (if Roblox lets this
-- player send invites; otherwise a hint)
local function inviteFriends()
	task.spawn(function()
		local ok, sent = pcall(function(): boolean
			local social = game:GetService("SocialService")
			local player = Players.LocalPlayer
			if social:CanSendGameInviteAsync(player) then
				social:PromptGameInvite(player)
				return true
			end
			return false
		end)
		if not ok or not sent then
			Notifications.Toast("Play with your Roblox friends: every friend in your server boosts your money!", "info")
		end
	end)
end

local function buildStats(gui: ScreenGui, callbacks: Callbacks)
	local stats = Theme.new("Frame", {
		Name = "Stats",
		AnchorPoint = if Theme.IsTouch then Vector2.new(1, 0) else Vector2.new(0, 1),
		Position = if Theme.IsTouch then UDim2.new(1, -10, 0, 4) else UDim2.new(0, 10, 1, -10),
		Size = UDim2.fromOffset(480, 160),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Theme.AutoScale(stats)
	local align = if Theme.IsTouch then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left

	-- Big outlined numbers with an icon, like the reference game. `onPlus`: a yellow + button right
	-- after the number (the number then sizes to its text, so the button follows it).
	local function row(name: string, icon: string, color: Color3, y: number, onPlus: (() -> ())?): TextLabel
		local holder = Theme.new("Frame", { Name = name, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), Position = UDim2.fromOffset(0, y), Parent = stats })
		local drawn = Icons.Draw(icon, holder, nil, nil)
		drawn.Size = UDim2.fromOffset(46, 46)
		drawn.Position = if Theme.IsTouch then UDim2.new(1, -48, 0, 2) else UDim2.fromOffset(2, 2)
		-- (a little shorter than the row, so tall glyphs like "$" don't touch the row above)
		local size = UDim2.new(1, -58, 0.86, 0)
		local position = if Theme.IsTouch then UDim2.fromScale(0, 0.07) else UDim2.new(0, 56, 0.07, 0)
		local label = Theme.Label({ Name = "Amount", Text = "0", TextColor3 = color, Size = size, Position = position, TextXAlignment = align, StrokeThickness = 4, Parent = holder })
		if onPlus then
			local line = Theme.new("Frame", { Name = "Line", BackgroundTransparency = 1, Size = size, Position = position, Parent = holder }, {
				Theme.new("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = if Theme.IsTouch then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 8),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			})
			label.TextScaled = false
			label.TextSize = 44
			label.AutomaticSize = Enum.AutomaticSize.X
			label.Size = UDim2.fromScale(0, 1)
			label.Position = UDim2.new()
			label.LayoutOrder = 1
			label.Parent = line
			local plus = Theme.Button({ Name = "Plus", Text = "", Color = Theme.Colors.Yellow, Size = UDim2.fromOffset(36, 36), LayoutOrder = 2, Parent = line })
			Icons.Draw("plus", plus, Theme.Colors.Yellow, { Size = UDim2.fromScale(0.74, 0.74), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
			plus.Activated:Connect(onPlus)
		end
		return label
	end
	local speedLabel = row("Speed", "bolt", Theme.Colors.Speed, 6)
	-- (the +: the Shop's Boosts, which start with the money passes)
	local moneyLabel = row("Money", "cash", Theme.Colors.Money, 62, function()
		callbacks.OpenShop("Passes")
	end)
	-- what you earn a second, right after your money (like "$760K +$244/s")
	local moneyLine = (moneyLabel.Parent :: Instance)
	local incomeLabel = Theme.Label({ Name = "Income", Text = "", TextColor3 = Theme.Colors.Money, TextScaled = false, TextSize = 28, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 0.8), LayoutOrder = 2, StrokeThickness = 3, Parent = moneyLine })
	local moneyPlus = moneyLine:FindFirstChild("Plus") :: GuiObject?
	if moneyPlus then
		moneyPlus.LayoutOrder = 3
	end

	-- Friend Boost, at the bottom (under Money): always there (+0% until a friend of yours is in the
	-- server: FriendService), with a green + that opens Roblox's invite-friends window
	local friendLine = Theme.new("Frame", {
		Name = "FriendBoost",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -6, 0, 32),
		Position = UDim2.fromOffset(if Theme.IsTouch then 0 else 6, 124),
		Parent = stats,
	}, {
		Theme.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = if Theme.IsTouch then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local friendText = Theme.Label({ Name = "Boost", Text = "Friend Boost: +0%", TextScaled = false, TextSize = 25, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), StrokeThickness = 3, LayoutOrder = 1, Parent = friendLine })
	local lime = Color3.fromRGB(140, 210, 40)
	local invite = Theme.Button({ Name = "Invite", Text = "", Color = lime, Size = UDim2.fromOffset(30, 30), LayoutOrder = 2, Parent = friendLine })
	Icons.Draw("plus", invite, lime, { Size = UDim2.fromScale(0.74, 0.74), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	invite.Activated:Connect(inviteFriends)
	local pop = Theme.new("UIScale", { Parent = friendText })
	local shownBoost = 0
	State.OnAttribute("FriendBoost", function()
		local bonus = State.Number("FriendBoost")
		friendText.Text = `Friend Boost: +{math.floor(bonus * 100 + 0.5)}%`
		if bonus > shownBoost then
			-- (it pops when a friend joins)
			pop.Scale = 1.25
			TweenService:Create(pop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		shownBoost = bonus
	end)

	local function updateSpeed()
		-- A crate Speed Boost shows its countdown next to your speed
		local endsAt = State.Get("SpeedBoostEndsAt")
		local left = if type(endsAt) == "number" then endsAt - workspace:GetServerTimeNow() else 0
		local boost = if left > 0
			then `  <font size="20" color="#ffe14a">+{math.floor((Config.Crates.SpeedBoostMultiplier - 1) * 100 + 0.5)}% {Format.Duration(left)}</font>`
			else ""
		speedLabel.Text = `{Format.Number(State.Number("Speed"))}{boost}`
	end
	speedLabel.RichText = true
	State.OnAttribute("Speed", updateSpeed)
	State.OnAttribute("SpeedBoostEndsAt", updateSpeed)
	task.spawn(function()
		while true do
			task.wait(1)
			if State.Get("SpeedBoostEndsAt") ~= nil then
				updateSpeed()
			end
		end
	end)
	State.OnAttribute("Money", function(value)
		moneyLabel.Text = Format.Money(value or 0)
	end)
	local function updateIncome()
		local mult = State.Number("MoneyMultiplier")
		local multText = if mult > 1 then `  (x{Format.Multiplier(mult)} money)` else ""
		incomeLabel.Text = `+{Format.Money(State.Number("Income"))}/s{multText}`
		incomeLabel.TextSize = if multText ~= "" then 22 else 28
	end
	State.OnAttribute("Income", updateIncome)
	State.OnAttribute("MoneyMultiplier", updateIncome)
end


-- Small round buttons in the free part of Roblox's top bar, at the top right, the size of Roblox's
-- own top-bar buttons: Daily Rewards, then Settings at the right end. (Just below the bar is where
-- Roblox's player list opens, which would cover them.)
local function buildCorner(callbacks: Callbacks)
	local gui = Theme.ScreenGui("TopBar", 1)
	gui.ScreenInsets = Enum.ScreenInsets.None
	local dark = Color3.fromRGB(18, 21, 30)
	local function roundButton(name: string, icon: string, onClick: () -> ()): TextButton
		local button = Theme.new("TextButton", {
			Name = name,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = dark,
			BackgroundTransparency = 0.08,
			AnchorPoint = Vector2.new(1, 0.5),
			Parent = gui,
		}, {
			Theme.new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		})
		Icons.Draw(icon, button, dark, { Size = UDim2.fromScale(0.82, 0.82), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
		button.Activated:Connect(onClick)
		button.MouseButton1Down:Connect(function()
			Theme.Bounce(button)
		end)
		return button
	end
	local settings = roundButton("Settings", "gearSteel", callbacks.OpenSettings)
	local daily = roundButton("Daily", "calendar", callbacks.OpenDaily)
	-- (a red "!" when a reward is waiting)
	local dot = badge(daily)
	dot.Text = "!"
	dot.Size = UDim2.fromOffset(18, 18)
	dot.Position = UDim2.new(1, -3, 0, 3)
	task.spawn(function()
		while true do
			dot.Visible = callbacks.DailyReady()
			task.wait(1)
		end
	end)
	local function place()
		local inset = GuiService.TopbarInset
		-- (before Roblox reports its bar: the usual 58-pixel one)
		local height = if inset.Height > 0 then inset.Height else 58
		local size = math.floor(height * 0.76 + 0.5)
		local camera = workspace.CurrentCamera
		local width = if camera then camera.ViewportSize.X else 0
		-- the free space's right edge, at least 12 pixels in from the screen's (like Roblox's own buttons)
		local right = if inset.Width > 0 then inset.Max.X else width
		if width > 0 then
			right = math.min(right, width - 12)
		end
		local y = inset.Min.Y + height / 2
		for i, button in { settings, daily } do
			local shift = (i - 1) * (size + 10)
			button.Size = UDim2.fromOffset(size, size)
			button.Position = if right > 0 then UDim2.fromOffset(right - shift, y) else UDim2.new(1, -12 - shift, 0, height / 2)
		end
	end
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(place)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
	end
	place()
end

-- A banner at the top whenever you walk into a biome: its name and the Speed you need to get away
-- from its Domer (or LOBBY when you're back).
local function announceBiomes()
	AreaTracker.Changed:Connect(function(areaId: number, old: number)
		if old == -1 then
			return
		end
		if areaId == 0 then
			Notifications.Banner("LOBBY", Color3.fromRGB(110, 200, 255), 1.5, nil, { Priority = Notifications.Priority.News })
		else
			-- Walked into a biome: its name and the Speed you need to get away from its Domer
			local area = Areas.List[areaId]
			local recommended = Economy.RecommendedSpeed(areaId)
			local need = if recommended > 0 then `{Format.Number(recommended)} Speed to escape` else "Any speed escapes!"
			Notifications.Banner(`BIOME {areaId}: {string.upper(area.Name)}`, area.Trim:Lerp(Color3.new(1, 1, 1), 0.25), 2.5, `{need} • {Config.Guard.Name} runs {math.floor(Economy.GuardWalkSpeed(areaId))}`, { Priority = Notifications.Priority.News })
		end
	end)
end

-- Luck Event pill at the top of the screen (only while one is running).
local function buildLuck(gui: ScreenGui)
	local pill = Theme.Band({
		Name = "LuckEvent",
		Size = UDim2.fromOffset(600, 38),
		Darkness = 0.6,
		Visible = false,
	})
	Notifications.Pill(pill, 1)
	local label = Theme.Label({ Text = "", Font = Theme.Font, TextColor3 = Color3.fromRGB(140, 255, 150), Size = UDim2.new(1, -250, 1, -6), Position = UDim2.fromOffset(60, 3), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 2.5, Parent = pill })
	local extend = Theme.Button({ Text = `+10 MIN R$ {Config.LuckEvent.SuggestedPrice}`, Color = Theme.Colors.Yellow, Size = UDim2.fromOffset(124, 30), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -60, 0.5, 0), Parent = pill })
	extend.Activated:Connect(function()
		State.Action("BuyLuck")
	end)
	task.spawn(function()
		while true do
			local endsAt = workspace:GetAttribute("LuckEndsAt")
			local left = if type(endsAt) == "number" then endsAt - workspace:GetServerTimeNow() else 0
			pill.Visible = left > 0
			if left > 0 then
				local by = workspace:GetAttribute("LuckBy")
				label.Text = `LUCK EVENT {Format.Duration(left)}{if type(by) == "string" then " • by " .. by else ""}`
			end
			task.wait(0.5)
		end
	end)
end

-- "YOUR BASE" marker visible through walls, so you always know where to run.
local function buildBaseMarker()
	local marker: BillboardGui? = nil
	local function place()
		local plot: Model? = nil
		for _ = 1, 60 do
			plot = Bases.Mine()
			if plot then
				break
			end
			task.wait(0.5)
		end
		local anchor = plot and plot:FindFirstChild("SignAnchor")
		if not anchor or not anchor:IsA("BasePart") then
			return
		end
		if marker then
			marker:Destroy()
		end
		local gui = Theme.new("BillboardGui", {
			Name = "YourBaseMarker",
			Adornee = anchor,
			AlwaysOnTop = true,
			Size = UDim2.fromOffset(150, 38),
			StudsOffsetWorldSpace = Vector3.new(0, 7, 0),
			LightInfluence = 0,
			Parent = Theme.PlayerGui(),
		})
		Theme.Label({ Text = "YOUR BASE", TextColor3 = Theme.Colors.Yellow, Size = UDim2.fromScale(1, 1), StrokeThickness = 3, Parent = gui })
		marker = gui
	end
	State.OnAttribute("PlotIndex", function()
		task.spawn(place)
	end)
end

function HUD.Init(callbacks: Callbacks)
	local gui = Theme.ScreenGui("HUD", 1)
	buildLeft(gui, callbacks)
	buildRight(gui, callbacks)
	buildStats(gui, callbacks)
	buildCorner(callbacks)
	announceBiomes()
	buildLuck(gui)
	buildBaseMarker()
end

return HUD
