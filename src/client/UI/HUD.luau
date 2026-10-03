--[[
	HUD: always-on screen UI in the chunky "Steal an Egg" style, kept away from Roblox's own UI
	(chat top-left, player list top-right, hotbar bottom-centre):
	  left   - big Shop / Index / Pets / Rebirth buttons + the speed slider (middle of the screen)
	  right  - a grid of square buttons: Home / Boosts / Skins / Donate / Updates / Settings (music
	           is in there) / Hide UI (+ Admin, + Floors after the floors code, + Teleport for
	           Teleporter pass owners), centred on the right edge. Everyone else travels between worlds through the hub's portals.
	  stats  - Speed, Money, income per second (bottom-left)
	  area   - where you are, how your speed compares to that area's guard, and any event (bottom-right)
	  luck   - a pill at the top while a Luck Event runs (anyone can add 10 more minutes)
]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Areas = require(Shared.Areas)
local Economy = require(Shared.Economy)
local Events = require(Shared.Events)
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
	OpenRebirth: () -> (),
	OpenWorlds: () -> (),
	OpenFloors: () -> (),
	OpenPets: () -> (),
	OpenDonate: () -> (),
	OpenUpdates: () -> (),
	OpenAdmin: () -> (),
	HideUI: () -> (),
	UnclaimedIndex: () -> number,
	RebirthReady: () -> boolean,
	ReadyEggs: () -> number,
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
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(196, 340),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Theme.new("UIListLayout", { Padding = UDim.new(0, 9), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	Theme.AutoScale(left)

	-- Shop and Index are the big ones; Pets and Rebirth a bit smaller underneath
	local big, small = UDim2.fromOffset(190, 64), UDim2.fromOffset(190, 50)
	local shop = Theme.Button({ Text = "Shop", Icon = "🛒", Color = Theme.Colors.Green, Size = big, LayoutOrder = 1, Parent = left })
	local index = Theme.Button({ Text = "Index", Icon = "📖", Color = Theme.Colors.Blue, Size = big, LayoutOrder = 2, Parent = left })
	local pets = Theme.Button({ Text = "Pets", Icon = "🐾", Color = Theme.Colors.Pink, Size = small, LayoutOrder = 3, Parent = left })
	local rebirth = Theme.Button({ Text = "Rebirth", Icon = "🔄", Color = Theme.Colors.Yellow, Size = small, LayoutOrder = 5, Parent = left })
	shop.Activated:Connect(function()
		callbacks.OpenShop("Upgrades")
	end)
	pets.Activated:Connect(callbacks.OpenPets)
	index.Activated:Connect(callbacks.OpenIndex)
	rebirth.Activated:Connect(callbacks.OpenRebirth)

	-- Badges: unclaimed Index rewards, eggs ready to hatch, rebirth ready
	local indexBadge = badge(index)
	local petsBadge = badge(pets)
	local rebirthBadge = badge(rebirth)
	local function updateBadges()
		local unclaimed = callbacks.UnclaimedIndex()
		indexBadge.Visible = unclaimed > 0
		indexBadge.Text = if unclaimed > 99 then "99+" else tostring(unclaimed)
		local ready = callbacks.ReadyEggs()
		petsBadge.Visible = ready > 0
		petsBadge.Text = tostring(ready)
		rebirthBadge.Visible = callbacks.RebirthReady()
		rebirthBadge.Text = "!"
	end
	State.Changed:Connect(updateBadges)
	for _, name in { "Money", "Speed", "Rebirths" } do
		State.OnAttribute(name, updateBadges)
	end
	task.spawn(function()
		while true do
			task.wait(2) -- eggs finish hatching on their own
			updateBadges()
		end
	end)

	-- Speed slider: anything from the starting walk speed up to your full speed. Handy on your
	-- base or on the treadmill when you're very fast.
	local sliderRow = Theme.new("Frame", { Name = "SpeedSlider", BackgroundTransparency = 1, Size = UDim2.fromOffset(196, 52), LayoutOrder = 6, Parent = left })
	local sliderLabel = Theme.Label({ Text = "", Font = Theme.Font, RichText = true, Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 2, Parent = sliderRow })
	local bar = Theme.new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.new(1, -12, 0, 16), Position = UDim2.fromOffset(6, 26), BackgroundColor3 = Theme.Colors.Outline, BackgroundTransparency = 0.3, Parent = sliderRow }, { Theme.Corner(8), Theme.Stroke(2.5) })
	local fill = Theme.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Colors.Green, Parent = bar }, { Theme.Corner(8) })
	local knob = Theme.new("Frame", { Size = UDim2.fromOffset(18, 26), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1, 0.5), BackgroundColor3 = Color3.fromRGB(255, 255, 255), ZIndex = 3, Parent = bar }, { Theme.Corner(6), Theme.Stroke(2) })
	local choice = 1
	local dragging = false
	local lastSent = 0
	local function render()
		fill.Size = UDim2.fromScale(choice, 1)
		knob.Position = UDim2.fromScale(choice, 0.5)
		fill.BackgroundColor3 = Theme.Colors.Gray:Lerp(Theme.Colors.Green, choice)
		local base = Config.Speed.BaseWalkSpeed
		local full = math.max(State.Number("WalkSpeed"), base)
		local chosen = base + (full - base) * choice
		sliderLabel.Text = `Speed <font color="#9dff7a">{math.floor(chosen)}</font> / {math.floor(full)}`
	end
	local function send(force: boolean?)
		local now = os.clock()
		if force or now - lastSent > 0.2 then
			lastSent = now
			State.Action("SetSpeedChoice", choice)
		end
	end
	local function setFromX(x: number)
		local width = math.max(bar.AbsoluteSize.X, 1)
		choice = math.clamp((x - bar.AbsolutePosition.X) / width, 0, 1)
		render()
		send()
	end
	bar.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			send(true)
		end
	end)
	State.OnAttribute("SpeedChoice", function(value)
		if type(value) == "number" and not dragging then
			choice = math.clamp(value, 0, 1)
			render()
		end
	end)
	State.OnAttribute("WalkSpeed", render)
	render()
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
		else
			Theme.Label({ Text = icon, Font = Enum.Font.GothamBold, Size = UDim2.new(1, 0, 0.62, 0), Position = UDim2.fromScale(0, 0.06), Parent = button })
		end
		Theme.Label({ Name = "Caption", Text = caption, Font = Theme.Title, Size = UDim2.new(1, -6, 0.26, 0), Position = UDim2.new(0, 3, 0.7, 0), StrokeThickness = 2, Parent = button })
		button.Activated:Connect(onClick)
		return button
	end
	local admin = square("🛠", "ADMIN", Theme.Colors.Red, 0, callbacks.OpenAdmin)
	admin.Visible = false
	-- The floors code ("ender=rich"): just the floor buttons
	local floors = square("🏢", "FLOORS", Theme.Colors.Blue, 0, callbacks.OpenFloors)
	State.OnAttribute("FloorAccess", function(value)
		floors.Visible = value == true
	end)
	square("🏠", "HOME", Theme.Colors.Red, 1, function()
		State.Action("TeleportHome")
	end)
	-- Teleporter pass owners: jump to any world or area (the Worlds window). Everyone else walks
	-- through the hub's portals, so they don't get a button.
	local teleport = square("🌀", "TELEPORT", Theme.Colors.Blue, 2, callbacks.OpenWorlds)
	local function showTeleport()
		teleport.Visible = State.Data.Passes ~= nil and State.Data.Passes.Teleporter == true
	end
	State.Changed:Connect(showTeleport)
	showTeleport()
	square("🚀", "BOOSTS", Theme.Colors.Orange, 3, function()
		callbacks.OpenShop("Passes")
	end)
	square("🎨", "SKINS", Theme.Colors.Purple, 4, function()
		callbacks.OpenShop("Skins")
	end)
	square("💖", "DONATE", Theme.Colors.Pink, 5, callbacks.OpenDonate)
	square("📰", "UPDATES", Theme.Colors.Yellow, 6, function()
		callbacks.OpenUpdates()
	end)
	-- Settings: music on/off, next song and volume live in its window
	square("⚙️", "SETTINGS", Theme.Colors.Gray, 7, callbacks.OpenSettings)
	-- Clear the screen for screenshots (X on a keyboard does the same; see HideUI)
	local hide = square("👁", "HIDE UI", Theme.Colors.Gray, 8, callbacks.HideUI)
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

local function buildStats(gui: ScreenGui)
	local stats = Theme.new("Frame", {
		Name = "Stats",
		AnchorPoint = if Theme.IsTouch then Vector2.new(1, 0) else Vector2.new(0, 1),
		Position = if Theme.IsTouch then UDim2.new(1, -10, 0, 4) else UDim2.new(0, 10, 1, -10),
		Size = UDim2.fromOffset(380, 136),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Theme.AutoScale(stats)
	local align = if Theme.IsTouch then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left

	-- Big outlined numbers with an icon, like the reference game
	local function row(icon: string, color: Color3, y: number): TextLabel
		local holder = Theme.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), Position = UDim2.fromOffset(0, y), Parent = stats })
		Theme.Label({ Text = icon, Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(50, 50), Position = if Theme.IsTouch then UDim2.new(1, -50, 0, 0) else UDim2.new(), Parent = holder })
		-- (a little shorter than the row, so tall glyphs like "$" don't touch the row above)
		return Theme.Label({
			Text = "0",
			TextColor3 = color,
			Size = UDim2.new(1, -58, 0.86, 0),
			Position = if Theme.IsTouch then UDim2.fromScale(0, 0.07) else UDim2.new(0, 56, 0.07, 0),
			TextXAlignment = align,
			StrokeThickness = 4,
			Parent = holder,
		})
	end
	local speedLabel = row("👟", Theme.Colors.Speed, 0)
	local moneyLabel = row("💵", Theme.Colors.Money, 52)
	local incomeLabel = Theme.Label({ Text = "", TextColor3 = Color3.fromRGB(255, 255, 255), Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 109), TextXAlignment = align, StrokeThickness = 3, Parent = stats })

	local function updateSpeed()
		-- A crate Speed Boost shows its countdown next to your speed
		local endsAt = State.Get("SpeedBoostEndsAt")
		local left = if type(endsAt) == "number" then endsAt - workspace:GetServerTimeNow() else 0
		local boost = if left > 0
			then `  <font size="20" color="#ffe14a">⚡+{math.floor((Config.Crates.SpeedBoostMultiplier - 1) * 100 + 0.5)}% {Format.Duration(left)}</font>`
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

local function buildAreaInfo(gui: ScreenGui)
	local panel = Theme.new("Frame", {
		Name = "AreaInfo",
		AnchorPoint = if Theme.IsTouch then Vector2.new(0, 0) else Vector2.new(1, 1),
		Position = if Theme.IsTouch then UDim2.new(0, 10, 0, 4) else UDim2.new(1, -10, 1, -10),
		Size = UDim2.fromOffset(290, 88),
		BackgroundColor3 = Theme.Colors.Outline,
		BackgroundTransparency = 0.45,
		Parent = gui,
	}, {
		Theme.Corner(12),
	})
	Theme.AutoScale(panel)
	local nameLabel = Theme.Label({ Text = "", Size = UDim2.new(1, -18, 0, 30), Position = UDim2.fromOffset(9, 4), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 2.5, Parent = panel })
	local detail = Theme.Label({ Text = "", Font = Theme.Font, RichText = true, Size = UDim2.new(1, -18, 0, 24), Position = UDim2.fromOffset(9, 36), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 1.5, Parent = panel })
	local eventLabel = Theme.Label({ Text = "", Font = Theme.Font, Size = UDim2.new(1, -18, 0, 22), Position = UDim2.fromOffset(9, 62), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 1.5, Parent = panel })

	local function refresh()
		local areaId = AreaTracker.Current
		local world = Areas.World(math.max(1, State.Number("World")))
		if areaId <= 0 then
			nameLabel.Text = if world.Id > 1 then `🛡 {world.Icon} {world.Name}` else "🛡 SAFE ZONE"
			nameLabel.TextColor3 = Color3.fromRGB(110, 200, 255)
			detail.Text = `{Config.Guard.Name} can't get you here`
			return
		end
		-- (no walk speed here: the Speed stat on the left is the number that counts)
		local area = Areas.List[areaId]
		local guard = math.floor(Economy.GuardWalkSpeed(areaId))
		local speed = State.Number("Speed")
		local recommended = Economy.RecommendedSpeed(areaId)
		local color = if speed >= recommended then "#7dff6a" elseif speed + 80 >= recommended then "#ffd54a" else "#ff5a5a"
		nameLabel.Text = `📍 {area.Name}`
		nameLabel.TextColor3 = area.Trim:Lerp(Color3.new(1, 1, 1), 0.3)
		detail.Text = if recommended > 0
			then `😴 {Config.Guard.Name}: <b>{guard}</b>   •   Need <font color="{color}"><b>⚡{Format.Number(recommended)}</b></font>`
			else `😴 {Config.Guard.Name}: <b>{guard}</b>   •   <font color="#7dff6a">Any speed!</font>`
	end

	-- The server event that's running (with a countdown)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local eventId = workspace:GetAttribute("EventId")
			local endsAt = workspace:GetAttribute("EventEndsAt")
			local event = if type(eventId) == "string" then Events.ById[eventId] else nil
			if event and type(endsAt) == "number" then
				eventLabel.Text = `{event.Icon} {event.Name}: {Format.Duration(endsAt - workspace:GetServerTimeNow())} left`
				eventLabel.TextColor3 = event.Color
			else
				eventLabel.Text = ""
			end
		end
	end)
	AreaTracker.Changed:Connect(function(areaId: number, old: number)
		refresh()
		if old == -1 then
			return
		end
		if areaId == 0 then
			Notifications.Banner("🛡 SAFE ZONE", Color3.fromRGB(110, 200, 255), 1.5)
		else
			local area = Areas.List[areaId]
			local recommended = Economy.RecommendedSpeed(areaId)
			local rec = if recommended > 0 then `Recommended speed ⚡{Format.Number(recommended)}` else "Anyone can make it back from here!"
			Notifications.Banner(`AREA {areaId}: {string.upper(area.Name)}`, area.Trim:Lerp(Color3.new(1, 1, 1), 0.25), 2.5, `{Config.Guard.Name} speed {math.floor(Economy.GuardWalkSpeed(areaId))} • {rec}`)
		end
	end)
	State.OnAttribute("Speed", function()
		refresh()
	end)
	State.OnAttribute("World", function()
		refresh()
	end)
end

-- Luck Event pill at the top of the screen (only while one is running).
local function buildLuck(gui: ScreenGui)
	local pill = Theme.new("Frame", {
		Name = "LuckEvent",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.fromOffset(430, 38),
		BackgroundColor3 = Color3.fromRGB(30, 120, 50),
		Visible = false,
		Parent = gui,
	}, {
		Theme.Corner(19),
		Theme.Stroke(3),
		Theme.Gradient(Color3.fromRGB(80, 220, 110), Color3.fromRGB(20, 110, 50)),
	})
	Theme.AutoScale(pill)
	local label = Theme.Label({ Text = "", Font = Theme.Font, Size = UDim2.new(1, -140, 1, -8), Position = UDim2.fromOffset(12, 4), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 2, Parent = pill })
	local extend = Theme.Button({ Text = `+10 MIN R$ {Config.LuckEvent.SuggestedPrice}`, Color = Theme.Colors.Yellow, Size = UDim2.fromOffset(124, 30), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Parent = pill })
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
				label.Text = `🍀 LUCK EVENT {Format.Duration(left)}{if type(by) == "string" then " • by " .. by else ""}`
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
		Theme.Label({ Text = "⬇ YOUR BASE ⬇", TextColor3 = Theme.Colors.Yellow, Size = UDim2.fromScale(1, 1), StrokeThickness = 3, Parent = gui })
		marker = gui
	end
	State.OnAttribute("PlotIndex", function()
		task.spawn(place)
	end)
	State.OnAttribute("BaseWorld", function()
		task.spawn(place)
	end)
end

function HUD.Init(callbacks: Callbacks)
	local gui = Theme.ScreenGui("HUD", 1)
	buildLeft(gui, callbacks)
	buildRight(gui, callbacks)
	buildStats(gui)
	buildAreaInfo(gui)
	buildLuck(gui)
	buildBaseMarker()
end

return HUD
