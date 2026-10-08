--[[
	HUD: always-on screen UI in the chunky "Steal an Egg" style, kept away from Roblox's own UI
	(chat top-left, player list top-right, hotbar bottom-centre):
	  left   - a column of big drawn icons with their names under them (no button boxes): Shop (a red
	           basket), Index (a blue book), Pets (a pink paw), Trails (a bolt), Daily (a present)
	  right  - a grid of square buttons: Home / Boosts / Skins / Donate / Updates / Settings (music
	           is in there) / Hide UI (+ Admin, + Base after the base code, + Teleport for
	           Teleporter pass owners), centred on the right edge
	  stats  - Speed; "Friend Boost: +N%" (the money your friends here add) with a green + that opens
	           Roblox's invite-friends window; Money (a yellow + after it opens the money game passes);
	           income per second (bottom-left; top-right on phones and tablets)
	  biomes - a banner at the top whenever you walk into a biome: its name, the Speed it needs and
	           how fast its Domer runs (server events show their time left in the pills up there too)

	  luck   - a pill at the top while a Luck Event runs (anyone can add 10 more minutes)
]]

local UserInputService = game:GetService("UserInputService")
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
	OpenTrails: () -> (),
	OpenTeleport: () -> (),
	OpenBaseSize: () -> (),
	OpenPets: () -> (),
	OpenDonate: () -> (),
	OpenUpdates: () -> (),
	OpenAdmin: () -> (),
	HideUI: () -> (),
	UnclaimedIndex: () -> number,
	TrailReady: () -> boolean,
	ReadyEggs: () -> number,
	OpenDaily: () -> (),
	DailyReady: () -> boolean,
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

local function buildLeft(gui: ScreenGui, callbacks: Callbacks)
	local left = Theme.new("Frame", {
		Name = "LeftButtons",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.42, 0),
		Size = UDim2.fromOffset(106, 5 * 88),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Theme.new("UIListLayout", { Padding = UDim.new(0, 2), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	Theme.AutoScale(left)

	-- A big drawn icon with its name under it, no button box around it (like the simulator games)
	local function iconButton(name: string, icon: string, caption: string, order: number): TextButton
		local button = Theme.new("TextButton", {
			Name = name,
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(104, 86),
			LayoutOrder = order,
			Parent = left,
		})
		local drawn = Icons.Draw(icon, button, nil, {
			Size = UDim2.fromScale(0.77, 0.77),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
		})
		drawn.ZIndex = 1
		Theme.Label({ Name = "Caption", Text = caption, Size = UDim2.new(1, 0, 0, 26), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), StrokeThickness = 3, ZIndex = 3, Parent = button })
		button.MouseButton1Down:Connect(function()
			Theme.Bounce(button)
		end)
		return button
	end
	local shop = iconButton("Shop", "basket", "Shop", 1)
	local index = iconButton("Index", "indexBook", "Index", 2)
	local pets = iconButton("Pets", "pawPink", "Pets", 3)
	local trails = iconButton("Trails", "bolt", "Trails", 4)
	local daily = iconButton("Daily", "gift", "Daily", 5)
	shop.Activated:Connect(function()
		callbacks.OpenShop("Upgrades")
	end)
	pets.Activated:Connect(callbacks.OpenPets)
	index.Activated:Connect(callbacks.OpenIndex)
	trails.Activated:Connect(callbacks.OpenTrails)
	daily.Activated:Connect(callbacks.OpenDaily)

	-- Badges: unclaimed Index rewards, eggs ready to hatch, a trail unlocked but none worn, a daily
	-- reward waiting
	local indexBadge = badge(index)
	local petsBadge = badge(pets)
	local trailsBadge = badge(trails)
	local dailyBadge = badge(daily)
	for _, bubble in { indexBadge, petsBadge, trailsBadge, dailyBadge } do
		bubble.Position = UDim2.new(0.5, 30, 0, 8) -- (the icon's top-right corner)
	end
	local function updateBadges()
		local unclaimed = callbacks.UnclaimedIndex()
		indexBadge.Visible = unclaimed > 0
		indexBadge.Text = if unclaimed > 99 then "99+" else tostring(unclaimed)
		local ready = callbacks.ReadyEggs()
		petsBadge.Visible = ready > 0
		petsBadge.Text = tostring(ready)
		trailsBadge.Visible = callbacks.TrailReady()
		trailsBadge.Text = "!"
		dailyBadge.Visible = callbacks.DailyReady()
		dailyBadge.Text = "!"
	end
	State.Changed:Connect(updateBadges)
	for _, name in { "Money", "Speed", "BestSpeed", "Trail" } do -- (and every 2 seconds below: a new day)
		State.OnAttribute(name, updateBadges)
	end
	task.spawn(function()
		while true do
			task.wait(2) -- eggs finish hatching on their own
			updateBadges()
		end
	end)
end

local function buildRight(gui: ScreenGui, callbacks: Callbacks)
	local right = Theme.new("Frame", {
		Name = "RightButtons",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(160, 410),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Theme.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(74, 74),
			CellPadding = UDim2.fromOffset(9, 9),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})
	Theme.AutoScale(right)

	local function square(icon: string, caption: string, color: Color3, order: number, onClick: () -> ()): TextButton
		local button = Theme.Button({ Text = "", Color = color, Size = UDim2.fromOffset(74, 74), LayoutOrder = order, Parent = right })
		local drawn = Icons.For(icon)
		if drawn then
			Icons.Draw(drawn, button, color, {
				Size = UDim2.fromScale(0.56, 0.56),
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0.08),
			})
		end
		Theme.Label({ Name = "Caption", Text = caption, Font = Theme.Title, Size = UDim2.new(1, -6, 0.26, 0), Position = UDim2.new(0, 3, 0.7, 0), StrokeThickness = 2, Parent = button })
		button.Activated:Connect(onClick)
		return button
	end
	local admin = square("tools", "ADMIN", Theme.Colors.Red, 0, callbacks.OpenAdmin)
	admin.Visible = false
	-- The base code ("ender=rich"): just the bigger-base buttons
	local baseSize = square("building", "BASE", Theme.Colors.Blue, 0, callbacks.OpenBaseSize)
	State.OnAttribute("SizeAccess", function(value)
		baseSize.Visible = value == true
	end)
	square("house", "HOME", Theme.Colors.Red, 1, function()
		State.Action("TeleportHome")
	end)
	-- Teleporter pass owners: jump to any biome. Everyone else walks.
	local teleport = square("globe", "TELEPORT", Theme.Colors.Blue, 2, callbacks.OpenTeleport)
	local function showTeleport()
		teleport.Visible = State.Data.Passes ~= nil and State.Data.Passes.Teleporter == true
	end
	State.Changed:Connect(showTeleport)
	showTeleport()
	square("rocket", "BOOSTS", Theme.Colors.Orange, 3, function()
		callbacks.OpenShop("Passes")
	end)
	square("palette", "SKINS", Theme.Colors.Purple, 4, function()
		callbacks.OpenShop("Skins")
	end)
	square("heart", "DONATE", Theme.Colors.Pink, 5, callbacks.OpenDonate)
	square("news", "UPDATES", Theme.Colors.Yellow, 6, function()
		callbacks.OpenUpdates()
	end)
	-- Settings: music on/off, next song and volume live in its window
	square("gear", "SETTINGS", Theme.Colors.Gray, 7, callbacks.OpenSettings)
	-- Clear the screen for screenshots (X on a keyboard does the same; see HideUI)
	local hide = square("eye", "HIDE UI", Theme.Colors.Gray, 8, callbacks.HideUI)
	if UserInputService.KeyboardEnabled then
		-- a little dark key cap on the top-right corner: "X" (it fits in the gaps beside the square)
		local key = Theme.new("Frame", {
			Name = "Key",
			BackgroundColor3 = Theme.Colors.Panel,
			Size = UDim2.fromOffset(24, 24),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -4, 0, 4),
			ZIndex = 5,
			Parent = hide,
		}, {
			Theme.Corner(6),
			Theme.Stroke(2),
		})
		Theme.Label({ Text = "X", Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), ZIndex = 6, StrokeThickness = 1.5, Parent = key })
	end
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
		Size = UDim2.fromOffset(380, 170),
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
	local speedLabel = row("Speed", "bolt", Theme.Colors.Speed, 0)
	-- (the +: the Boosts page, which starts with the money passes)
	local moneyLabel = row("Money", "cash", Theme.Colors.Money, 88, function()
		callbacks.OpenShop("Passes")
	end)
	local incomeLabel = Theme.Label({ Text = "", TextColor3 = Color3.fromRGB(255, 255, 255), Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 143), TextXAlignment = align, StrokeThickness = 3, Parent = stats })

	-- Friend Boost, between Speed and Money: always there (+0% until a friend of yours is in the
	-- server: FriendService), with a green + that opens Roblox's invite-friends window
	local friendLine = Theme.new("Frame", {
		Name = "FriendBoost",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -6, 0, 32),
		Position = UDim2.fromOffset(if Theme.IsTouch then 0 else 6, 54),
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
	end
	State.OnAttribute("Income", updateIncome)
	State.OnAttribute("MoneyMultiplier", updateIncome)
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
	announceBiomes()
	buildLuck(gui)
	buildBaseMarker()
end

return HUD
