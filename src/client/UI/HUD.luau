--[[
	HUD: always-on screen UI.
	  left   - Shop / Index / Top 500 / Rebirth buttons + Slow Mode toggle
	  right  - Home / Worlds / Passes / Skins / Settings square buttons
	  stats  - Speed, Money, income per second
	  area   - where you are, how your speed compares to that area's guard, and any running event
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Areas = require(Shared.Areas)
local Economy = require(Shared.Economy)
local Events = require(Shared.Events)
local Format = require(Shared.Format)

local Theme = require(script.Parent.Theme)
local Notifications = require(script.Parent.Notifications)
local State = require(script.Parent.Parent.State)
local AreaTracker = require(script.Parent.Parent.AreaTracker)

local HUD = {}

export type Callbacks = {
	OpenShop: (tab: string?) -> (),
	OpenIndex: () -> (),
	OpenLeaderboards: () -> (),
	OpenSettings: () -> (),
	OpenRebirth: () -> (),
	OpenWorlds: () -> (),
	UnclaimedIndex: () -> number,
	RebirthReady: () -> boolean,
}

-- Little red number bubble in a button's corner.
local function badge(button: GuiObject): TextLabel
	local bubble = Theme.Label({
		Name = "Badge",
		Text = "",
		Font = Theme.Font,
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.Colors.Red,
		Size = UDim2.fromOffset(30, 30),
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
		Position = UDim2.new(0, 12, 0.45, 0),
		Size = UDim2.fromOffset(190, 330),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Theme.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	Theme.AutoScale(left)

	local shop = Theme.Button({ Text = "Shop", Icon = "🛒", Color = Theme.Colors.Green, Size = UDim2.fromOffset(180, 62), LayoutOrder = 1, Parent = left })
	local index = Theme.Button({ Text = "Index", Icon = "📖", Color = Theme.Colors.Blue, Size = UDim2.fromOffset(180, 62), LayoutOrder = 2, Parent = left })
	local top = Theme.Button({ Text = "Top 500", Icon = "🏆", Color = Theme.Colors.Orange, Size = UDim2.fromOffset(180, 62), LayoutOrder = 3, Parent = left })
	local rebirth = Theme.Button({ Text = "Rebirth", Icon = "🔄", Color = Theme.Colors.Yellow, Size = UDim2.fromOffset(180, 62), LayoutOrder = 4, Parent = left })
	shop.Activated:Connect(function()
		callbacks.OpenShop("Upgrades")
	end)
	index.Activated:Connect(callbacks.OpenIndex)
	top.Activated:Connect(callbacks.OpenLeaderboards)
	rebirth.Activated:Connect(callbacks.OpenRebirth)

	-- Badges: unclaimed Index rewards, rebirth ready
	local indexBadge = badge(index)
	local rebirthBadge = badge(rebirth)
	local function updateBadges()
		local unclaimed = callbacks.UnclaimedIndex()
		indexBadge.Visible = unclaimed > 0
		indexBadge.Text = if unclaimed > 99 then "99+" else tostring(unclaimed)
		rebirthBadge.Visible = callbacks.RebirthReady()
		rebirthBadge.Text = "!"
	end
	State.Changed:Connect(updateBadges)
	for _, name in { "Money", "Speed", "Rebirths" } do
		State.OnAttribute(name, updateBadges)
	end

	-- Slow Mode toggle (walk at normal speed on your base when you're very fast)
	local row = Theme.new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(190, 34), LayoutOrder = 5, Parent = left })
	local track = Theme.new("Frame", { Size = UDim2.fromOffset(64, 30), Position = UDim2.fromOffset(2, 2), BackgroundColor3 = Theme.Colors.Outline, BackgroundTransparency = 0.3, Parent = row }, { Theme.Corner(8), Theme.Stroke(2.5) })
	local knob = Theme.new("Frame", { Size = UDim2.fromOffset(26, 24), Position = UDim2.fromOffset(3, 3), BackgroundColor3 = Theme.Colors.Gray, Parent = track }, { Theme.Corner(6) })
	Theme.Label({ Text = "Slow Mode", Font = Theme.Font, Size = UDim2.new(1, -74, 0, 26), Position = UDim2.fromOffset(74, 4), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 2, Parent = row })
	local function render(enabled: boolean)
		TweenService:Create(knob, TweenInfo.new(0.15), {
			Position = UDim2.fromOffset(if enabled then 35 else 3, 3),
			BackgroundColor3 = if enabled then Theme.Colors.Green else Theme.Colors.Gray,
		}):Play()
	end
	row.Activated:Connect(function()
		local enabled = not (State.Get("SlowMode") == true)
		render(enabled)
		State.Action("SetSlowMode", enabled)
		Theme.PlaySound("Click")
	end)
	State.OnAttribute("SlowMode", function(value)
		render(value == true)
	end)
end

local function buildRight(gui: ScreenGui, callbacks: Callbacks)
	local right = Theme.new("Frame", {
		Name = "RightButtons",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.45, 0),
		Size = UDim2.fromOffset(74, 430),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Theme.new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Right }),
	})
	Theme.AutoScale(right)

	local function square(icon: string, caption: string, color: Color3, order: number, onClick: () -> ())
		local button = Theme.Button({ Text = "", Color = color, Size = UDim2.fromOffset(72, 72), LayoutOrder = order, Parent = right })
		Theme.Label({ Text = icon, Font = Enum.Font.GothamBold, Size = UDim2.new(1, 0, 0.62, 0), Position = UDim2.fromScale(0, 0.06), Parent = button })
		Theme.Label({ Text = caption, Font = Theme.Font, Size = UDim2.new(1, -6, 0.26, 0), Position = UDim2.new(0, 3, 0.7, 0), StrokeThickness = 1.8, Parent = button })
		button.Activated:Connect(onClick)
	end
	square("🏠", "HOME", Theme.Colors.Red, 1, function()
		State.Action("TeleportHome")
	end)
	square("🌀", "WORLDS", Theme.Colors.Blue, 2, callbacks.OpenWorlds)
	square("🎟️", "PASSES", Theme.Colors.Orange, 3, function()
		callbacks.OpenShop("Passes")
	end)
	square("🎨", "SKINS", Theme.Colors.Purple, 4, function()
		callbacks.OpenShop("Skins")
	end)
	square("⚙️", "SETTINGS", Theme.Colors.Gray, 5, callbacks.OpenSettings)
end

local function buildStats(gui: ScreenGui)
	local stats = Theme.new("Frame", {
		Name = "Stats",
		AnchorPoint = if Theme.IsTouch then Vector2.new(1, 0) else Vector2.new(0, 1),
		Position = if Theme.IsTouch then UDim2.new(1, -12, 0, 6) else UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(360, 140),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Theme.AutoScale(stats)
	local align = if Theme.IsTouch then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left

	local function row(icon: string, color: Color3, y: number): TextLabel
		local holder = Theme.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), Position = UDim2.fromOffset(0, y), Parent = stats })
		Theme.Label({ Text = icon, Font = Enum.Font.GothamBold, Size = UDim2.fromOffset(50, 50), Position = if Theme.IsTouch then UDim2.new(1, -50, 0, 0) else UDim2.new(), Parent = holder })
		return Theme.Label({
			Text = "0",
			TextColor3 = color,
			Size = UDim2.new(1, -60, 1, 0),
			Position = if Theme.IsTouch then UDim2.new() else UDim2.fromOffset(58, 0),
			TextXAlignment = align,
			StrokeThickness = 3.5,
			Parent = holder,
		})
	end
	local speedLabel = row("👟", Theme.Colors.Speed, 0)
	local moneyLabel = row("💵", Theme.Colors.Money, 52)
	local incomeLabel = Theme.Label({ Text = "", Font = Theme.Font, TextColor3 = Color3.fromRGB(200, 255, 190), Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 108), TextXAlignment = align, StrokeThickness = 2, Parent = stats })

	State.OnAttribute("Speed", function(value)
		speedLabel.Text = Format.Number(value or 0)
	end)
	State.OnAttribute("Money", function(value)
		moneyLabel.Text = Format.Money(value or 0)
	end)
	local function updateIncome()
		local walk = State.Number("WalkSpeed")
		local mult = State.Number("MoneyMultiplier")
		local multText = if mult > 1 then `  (x{Format.Multiplier(mult)} money)` else ""
		incomeLabel.Text = `+{Format.Money(State.Number("Income"))}/s{multText}   🏃 {math.floor(walk)} walk speed`
	end
	State.OnAttribute("Income", updateIncome)
	State.OnAttribute("WalkSpeed", updateIncome)
	State.OnAttribute("MoneyMultiplier", updateIncome)
end

local function buildAreaInfo(gui: ScreenGui)
	local panel = Theme.new("Frame", {
		Name = "AreaInfo",
		AnchorPoint = if Theme.IsTouch then Vector2.new(0, 0) else Vector2.new(1, 1),
		Position = if Theme.IsTouch then UDim2.new(0, 12, 0, 6) else UDim2.new(1, -12, 1, -12),
		Size = UDim2.fromOffset(330, 100),
		BackgroundColor3 = Theme.Colors.Outline,
		BackgroundTransparency = 0.45,
		Parent = gui,
	}, {
		Theme.Corner(12),
	})
	Theme.AutoScale(panel)
	local nameLabel = Theme.Label({ Text = "", Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 4), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 2.5, Parent = panel })
	local detail = Theme.Label({ Text = "", Font = Theme.Font, RichText = true, Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 40), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 1.5, Parent = panel })
	local eventLabel = Theme.Label({ Text = "", Font = Theme.Font, Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 70), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 1.5, Parent = panel })

	local function areaFolder(areaId: number): Instance?
		local map = workspace:FindFirstChild("Map")
		local lane = map and map:FindFirstChild("Lane")
		return lane and lane:FindFirstChild("Area" .. areaId)
	end

	local function refresh()
		local areaId = AreaTracker.Current
		local walk = State.Number("WalkSpeed")
		local world = Areas.World(math.max(1, State.Number("World")))
		if areaId <= 0 then
			nameLabel.Text = if world.Id > 1 then `🛡 {world.Icon} {world.Name}` else "🛡 SAFE ZONE"
			nameLabel.TextColor3 = Color3.fromRGB(110, 200, 255)
			detail.Text = `Your walk speed: <font color="#9dff7a">{math.floor(walk)}</font>`
			return
		end
		local area = Areas.List[areaId]
		local guard = math.floor(Economy.GuardWalkSpeed(areaId))
		local color = if walk + 3 >= guard then "#7dff6a" elseif walk + 8 >= guard then "#ffd54a" else "#ff5a5a"
		nameLabel.Text = `📍 {area.Name}`
		nameLabel.TextColor3 = area.Trim:Lerp(Color3.new(1, 1, 1), 0.3)
		detail.Text = `😴 {Config.Guard.Name}: <b>{guard}</b>   •   🏃 You: <font color="{color}"><b>{math.floor(walk)}</b></font>`
	end

	-- Running event in the area you're standing in (with a countdown)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local areaId = AreaTracker.Current
			local folder = if areaId > 0 then areaFolder(areaId) else nil
			local eventId = folder and folder:GetAttribute("EventId")
			local endsAt = folder and folder:GetAttribute("EventEndsAt")
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
			local rec = if area.RecommendedSpeed > 0 then "Recommended speed ⚡" .. Format.Number(area.RecommendedSpeed) else "Anyone can make it back from here!"
			Notifications.Banner(`AREA {areaId}: {string.upper(area.Name)}`, area.Trim:Lerp(Color3.new(1, 1, 1), 0.25), 2.5, `{Config.Guard.Name} speed {math.floor(Economy.GuardWalkSpeed(areaId))} • {rec}`)
		end
	end)
	State.OnAttribute("WalkSpeed", function()
		refresh()
	end)
	State.OnAttribute("World", function()
		refresh()
	end)
end

-- "YOUR BASE" marker visible through walls, so you always know where to run.
local function buildBaseMarker()
	local marker: BillboardGui? = nil
	local function place()
		local index = State.Get("PlotIndex")
		if not index then
			return
		end
		local map = workspace:WaitForChild("Map", 30)
		local plots = map and map:WaitForChild("Plots", 30)
		local plot = plots and plots:WaitForChild("Plot" .. tostring(index), 30)
		local anchor = plot and plot:WaitForChild("SignAnchor", 30)
		if not anchor then
			return
		end
		if marker then
			marker:Destroy()
		end
		local gui = Theme.new("BillboardGui", {
			Name = "YourBaseMarker",
			Adornee = anchor,
			AlwaysOnTop = true,
			Size = UDim2.fromOffset(170, 44),
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
end

function HUD.Init(callbacks: Callbacks)
	local gui = Theme.ScreenGui("HUD", 1)
	buildLeft(gui, callbacks)
	buildRight(gui, callbacks)
	buildStats(gui)
	buildAreaInfo(gui)
	buildBaseMarker()
end

return HUD
