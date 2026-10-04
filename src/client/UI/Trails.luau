--[[
	Trails window (the 💨 Trails button on the HUD): every trail, what it looks like, and how to get
	it. Locked trails show how much Speed they still need; unlocked ones can be put on and taken
	off. The effects themselves are drawn by client/TrailFX. The server checks every press.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local Format = require(Shared.Format)
local TrailList = require(Shared.Trails)

local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local State = require(script.Parent.Parent.State)

local Trails = {}

type Card = { Button: TextButton, Status: TextLabel, Fill: Frame, Bar: Frame }

local modal: Modal.Modal
local cards: { [string]: Card } = {}

local function unlocked(trail: TrailList.Trail): boolean
	return TrailList.IsUnlocked(trail, State.Data.OwnedTrails, State.Number("BestSpeed"))
end

function Trails.Open()
	modal:Open()
end

-- True when a trail is unlocked but you wear none (the HUD shows a "!" on the button).
function Trails.IsReady(): boolean
	if State.Get("Trail") ~= nil then
		return false
	end
	for _, trail in TrailList.List do
		if unlocked(trail) then
			return true
		end
	end
	return false
end

-- A little picture of the trail: a runner with fading see-through copies behind them and a glass
-- pane cracking (made of plain UI, so it costs nothing).
local function preview(parent: Instance, trail: TrailList.Trail)
	local box = Theme.new("Frame", { Size = UDim2.fromOffset(150, 150), Position = UDim2.fromOffset(10, 10), BackgroundColor3 = Color3.fromRGB(22, 30, 52), Parent = parent }, {
		Theme.Corner(12),
		Theme.Stroke(2.5, trail.Accent),
		Theme.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(70, 110, 170), Color3.fromRGB(20, 26, 46)) }),
	})
	-- glass pane with cracks, behind the runner
	local pane = Theme.new("Frame", { Size = UDim2.fromOffset(52, 78), Position = UDim2.fromOffset(12, 30), Rotation = -8, BackgroundColor3 = trail.Color, BackgroundTransparency = 0.7, Parent = box }, {
		Theme.new("UIStroke", { Color = trail.Accent, Thickness = 2, Transparency = 0.1 }),
	})
	for i, crack in { { 0.5, 0.45, 40, 0.8 }, { 0.35, 0.6, -35, 0.6 }, { 0.62, 0.3, 70, 0.5 } } do
		Theme.new("Frame", { Name = "Crack" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(crack[1], crack[2]), Size = UDim2.new(crack[4], 0, 0, 2), Rotation = crack[3], BackgroundColor3 = trail.Accent, BorderSizePixel = 0, Parent = pane })
	end
	-- shards flying off it
	for i, shard in { { 4, 22, 25 }, { 70, 18, -30 }, { 8, 112, 50 }, { 66, 116, -60 }, { 40, 12, 15 } } do
		Theme.new("Frame", { Name = "Shard" .. i, Size = UDim2.fromOffset(9, 5), Position = UDim2.fromOffset(shard[1], shard[2]), Rotation = shard[3], BackgroundColor3 = trail.Color, BackgroundTransparency = 0.35, Parent = box }, {
			Theme.new("UIStroke", { Color = trail.Accent, Thickness = 1 }),
		})
	end
	-- the afterimages, oldest (faintest) first, and the runner in front
	for i = 1, 4 do
		local runner = Theme.Label({ Text = "🏃", Size = UDim2.fromOffset(70, 70), Position = UDim2.fromOffset(18 + i * 13, 44), StrokeThickness = 0, Parent = box })
		runner.TextTransparency = if i == 4 then 0 else 0.85 - i * 0.15
		runner.TextColor3 = trail.Color
		runner.ZIndex = 2 + i
	end
	Theme.Label({ Text = trail.Icon, Size = UDim2.fromOffset(34, 34), Position = UDim2.new(1, -38, 0, 4), StrokeThickness = 0, ZIndex = 8, Parent = box })
end

local function buildCard(list: Instance, trail: TrailList.Trail)
	local card = Theme.new("Frame", { Name = trail.Id, Size = UDim2.new(1, -12, 0, 170), BackgroundColor3 = Theme.Colors.PanelLight, LayoutOrder = trail.Order, Parent = list }, {
		Theme.Corner(14),
		Theme.Stroke(3, trail.Color),
	})
	preview(card, trail)
	Theme.Label({ Text = `{trail.Icon} {string.upper(trail.Name)} TRAIL`, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = trail.Color, Size = UDim2.new(1, -184, 0, 34), Position = UDim2.fromOffset(174, 10), Parent = card })
	Theme.Label({ Text = trail.Description, Font = Theme.Font, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, -184, 0, 44), Position = UDim2.fromOffset(174, 46), StrokeThickness = 1.2, Parent = card })
	local status = Theme.Label({ Text = "", Font = Theme.Font, RichText = true, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -184, 0, 22), Position = UDim2.fromOffset(174, 92), StrokeThickness = 1.2, Parent = card })
	local bar = Theme.new("Frame", { Size = UDim2.new(1, -330, 0, 22), Position = UDim2.fromOffset(174, 128), BackgroundColor3 = Theme.Colors.Outline, Parent = card }, { Theme.Corner(8), Theme.Stroke(2) })
	local fill = Theme.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Colors.Speed, Parent = bar }, { Theme.Corner(8) })
	local button = Theme.Button({ Text = "WEAR", Color = Theme.Colors.Green, Size = UDim2.fromOffset(140, 46), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -10), Parent = card })
	button.Activated:Connect(function()
		if not unlocked(trail) then
			return
		end
		State.Action("EquipTrail", if State.Get("Trail") == trail.Id then "" else trail.Id)
	end)
	cards[trail.Id] = { Button = button, Status = status, Fill = fill, Bar = bar }
end

local function refresh()
	local best = State.Number("BestSpeed")
	local wearing = State.Get("Trail")
	for _, trail in TrailList.List do
		local card = cards[trail.Id]
		if card then
			local need = TrailList.RequiredSpeed(trail)
			local open = unlocked(trail)
			card.Bar.Visible = not open and need ~= nil
			if open then
				local on = wearing == trail.Id
				card.Status.Text = if on then `<font color="#8dff6a">✓ You're wearing it</font>` else "✓ Unlocked"
				Theme.SetButtonText(card.Button, if on then "TAKE OFF" else "WEAR")
				Theme.SetButtonColor(card.Button, if on then Theme.Colors.Orange else Theme.Colors.Green)
			elseif need then
				local area = trail.UnlockBiome and Areas.List[trail.UnlockBiome]
				card.Status.Text = `🔒 Reach <font color="#c9a0ff"><b>⚡{Format.Number(need)}</b></font> Speed{if area then ` (biome {area.Id}: {area.Name})` else ""}`
				card.Fill.Size = UDim2.fromScale(math.clamp(best / need, 0, 1), 1)
				Theme.SetButtonText(card.Button, "LOCKED")
				Theme.SetButtonColor(card.Button, Theme.Colors.Gray)
			else
				card.Status.Text = "🔒 Coming soon"
				Theme.SetButtonText(card.Button, "LOCKED")
				Theme.SetButtonColor(card.Button, Theme.Colors.Gray)
			end
		end
	end
end

function Trails.Init()
	modal = Modal.new("💨 TRAILS", Theme.Colors.Blue, Vector2.new(640, 420))
	Theme.Label({
		Text = "Trails show behind you while you run fast. Everyone near you can see them!",
		Font = Theme.Font, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 24), StrokeThickness = 1.4, Parent = modal.Body,
	})
	local list = Theme.new("ScrollingFrame", {
		Name = "List", Size = UDim2.new(1, 0, 1, -34), Position = UDim2.fromOffset(0, 34), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 8, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = modal.Body,
	}, {
		Theme.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		Theme.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4) }),
	})
	for _, trail in TrailList.List do
		buildCard(list, trail)
	end
	State.Changed:Connect(refresh)
	State.OnAttribute("Trail", refresh)
	State.OnAttribute("BestSpeed", function()
		if modal:IsOpen() then
			refresh()
		end
	end)
	modal.OnOpen = refresh
	refresh()
end

return Trails
