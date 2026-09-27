--[[
	HUD: always-on screen UI.
	  left   - Shop / Index / Top 500 buttons + Slow Mode toggle
	  right  - Home / Passes / Skins square buttons
	  stats  - Speed, Money, income per second
	  area   - where you are and how your speed compares to that area's guard
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Areas = require(Shared.Areas)
local Economy = require(Shared.Economy)
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
}

local function buildLeft(gui: ScreenGui, callbacks: Callbacks)
	local left = Theme.new("Frame", {
		Name = "LeftButtons",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.45, 0),
		Size = UDim2.fromOffset(190, 260),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Theme.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	Theme.AutoScale(left)

	local shop = Theme.Button({ Text = "Shop", Icon = "🛒", Color = Theme.Colors.Green, Size = UDim2.fromOffset(180, 62), LayoutOrder = 1, Parent = left })
	local index = Theme.Button({ Text = "Index", Icon = "📖", Color = Theme.Colors.Blue, Size = UDim2.fromOffset(180, 62), LayoutOrder = 2, Parent = left })
	local top = Theme.Button({ Text = "Top 500", Icon = "🏆", Color = Theme.Colors.Orange, Size = UDim2.fromOffset(180, 62), LayoutOrder = 3, Parent = left })
	shop.Activated:Connect(function()
		callbacks.OpenShop("Upgrades")
	end)
	index.Activated:Connect(callbacks.OpenIndex)
	top.Activated:Connect(callbacks.OpenLeaderboards)

	-- Slow Mode toggle (walk at normal speed on your base when you're very fast)
	local row = Theme.new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(190, 34), LayoutOrder = 4, Parent = left })
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
		Theme.PlaySound("Click", 0.3)
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
		Size = UDim2.fromOffset(74, 250),
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
	square("🎟️", "PASSES", Theme.Colors.Orange, 2, function()
		callbacks.OpenShop("Passes")
	end)
	square("🎨", "SKINS", Theme.Colors.Purple, 3, function()
		callbacks.OpenShop("Skins")
	end)
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
		local walk = Economy.WalkSpeedFromStat(State.Number("Speed"))
		local mult = State.Number("MoneyMultiplier")
		local multText = if mult > 1 then string.format("  (x%s money)", Format.Number(mult)) else ""
		incomeLabel.Text = `+{Format.Money(State.Number("Income"))}/s{multText}   🏃 {math.floor(walk)} walk speed`
	end
	State.OnAttribute("Income", updateIncome)
	State.OnAttribute("Speed", updateIncome)
	State.OnAttribute("MoneyMultiplier", updateIncome)
end

local function buildAreaInfo(gui: ScreenGui)
	local panel = Theme.new("Frame", {
		Name = "AreaInfo",
		AnchorPoint = if Theme.IsTouch then Vector2.new(0, 0) else Vector2.new(1, 1),
		Position = if Theme.IsTouch then UDim2.new(0, 12, 0, 6) else UDim2.new(1, -12, 1, -12),
		Size = UDim2.fromOffset(330, 74),
		BackgroundColor3 = Theme.Colors.Outline,
		BackgroundTransparency = 0.45,
		Parent = gui,
	}, {
		Theme.Corner(12),
	})
	Theme.AutoScale(panel)
	local nameLabel = Theme.Label({ Text = "", Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 4), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 2.5, Parent = panel })
	local detail = Theme.Label({ Text = "", Font = Theme.Font, RichText = true, Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 40), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 1.5, Parent = panel })

	local function refresh()
		local areaId = AreaTracker.Current
		local walk = Economy.WalkSpeedFromStat(State.Number("Speed"))
		if areaId <= 0 then
			nameLabel.Text = "🛡 SAFE ZONE"
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
	State.OnAttribute("Speed", function()
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
