--[[
	DailyRewards (the window): Day 1 to Day 7, like the big simulator games. Six cards in two rows,
	and Day 7 big on the right. Every card has a dark strip with "Day N" and two streaks of light,
	studs, the reward (a pet, a pile of cash, or a purple coin with a paw: +1 pet slot), a gold
	"OP!" on the special ones and the reward's name at the bottom. Days you've claimed are dimmed
	with a green tick; the one you can claim lights up with a big green "Claim!" (click it). With
	nothing to claim, the title says when the next one is ready.

	The rules (what each day gives, when a day changes) are in shared/DailyRewards; the server
	(server/DailyService) hands them out. Opens by itself after the Update Log when a reward is
	waiting, and from the Daily button on the left.
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rules = require(Shared.DailyRewards)
local Pets = require(Shared.Pets)
local PetModel = require(Shared.PetModel)
local Format = require(Shared.Format)

local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)
local Modal = require(script.Parent.Modal)
local State = require(script.Parent.Parent.State)

local DailyRewards = {}

local rgb = Color3.fromRGB

local SIZE = Vector2.new(780, 490)
local CARD = Vector2.new(158, 199)
local GAP = 12
local BIG = Vector2.new(242, 410)
local GREEN = rgb(120, 255, 100)
local GOLD = rgb(255, 206, 50)
local NAME = rgb(218, 218, 222)

type Card = {
	Day: number,
	Frame: Frame,
	Area: Frame,
	Picture: Frame,
	Label: TextLabel,
	OP: TextLabel,
	Shade: Frame,
	Tick: Frame,
	Glow: Frame,
	Claim: TextLabel,
	Pop: UIScale,
	Shows: string,
	Big: boolean,
}

local modal: Modal.Modal
local cards: { Card } = {}
local studded = false
local lastClaimed: number? = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Is there a reward waiting? (false until your save has arrived)
function DailyRewards.Ready(): boolean
	if type(State.Data.DailyClaims) ~= "number" then
		return false
	end
	return Rules.Ready(State.Data.DailyLastDay or 0, now())
end

local function view(): Rules.View
	return Rules.View(State.Data.DailyClaims or 0, State.Data.DailyLastDay or 0, now())
end

--------------------------------------------------------------------------------
-- Pictures
--------------------------------------------------------------------------------
-- A pet turning slowly in a viewport.
local function petPicture(parent: Frame, pet: Pets.Pet, big: boolean)
	local viewport = Theme.new("ViewportFrame", {
		Name = "Pet",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = rgb(170, 170, 170),
		LightColor = rgb(255, 255, 255),
		LightDirection = Vector3.new(-0.5, -1, 0.8),
		ZIndex = 3,
		Parent = parent,
	})
	local model = PetModel.BuildPet(pet, { NoEffects = true })
	-- facing you, turned a little; centred and framed by its size (a whale is long, a pup is tall)
	model:PivotTo(CFrame.Angles(0, math.rad(-25), 0))
	local box, size = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() - box.Position)
	model.Parent = viewport
	local fit = math.max(size.X, size.Y, size.Z)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	local distance = fit * (if big then 1.2 else 1.5) -- (Day 7's pet fills its big card)
	camera.CFrame = CFrame.lookAt(Vector3.new(0, distance * 0.2, -distance), Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

-- The purple coin with a paw and "+1" (one more pet slot).
local function slotPicture(parent: Frame)
	local coin = Theme.new("Frame", {
		Name = "Coin",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.86, 0.86),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
		Parent = parent,
	}, {
		Theme.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		Theme.Stroke(3.5),
		Theme.Gradient(rgb(178, 98, 255), rgb(104, 36, 196)),
	})
	-- (a darker ring inside the rim)
	Theme.new("Frame", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.8),
		BackgroundColor3 = rgb(92, 30, 170),
		BackgroundTransparency = 0.4,
		ZIndex = 3,
		Parent = coin,
	}, {
		Theme.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
	})
	local paw = Icons.Draw("paw", coin, rgb(140, 64, 230), {
		Size = UDim2.fromScale(0.56, 0.56),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
	})
	paw.ZIndex = 4
	Theme.Label({ Name = "Plus", Text = "+1", Size = UDim2.fromScale(0.5, 0.3), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.78), StrokeThickness = 3, ZIndex = 5, Parent = coin })
end

local function moneyPicture(parent: Frame)
	local cash = Icons.Draw("cash", parent, rgb(90, 90, 96), {
		Size = UDim2.fromScale(0.9, 0.9),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
	})
	cash.ZIndex = 3
end

-- Show `reward` on the card (only rebuilt when it changes).
local function setPicture(card: Card, reward: Config.DailyReward)
	local shows = reward.Kind .. (reward.Pet or "")
	if card.Shows == shows then
		return
	end
	card.Shows = shows
	card.Picture:ClearAllChildren()
	if reward.Kind == "Pet" and reward.Pet and Pets.ById[reward.Pet] then
		petPicture(card.Picture, Pets.ById[reward.Pet], card.Big)
	elseif reward.Kind == "PetSlot" then
		slotPicture(card.Picture)
	else
		moneyPicture(card.Picture)
	end
end

local function nameOf(reward: Config.DailyReward): string
	if reward.Kind == "Pet" and reward.Pet then
		local pet = Pets.ById[reward.Pet]
		return if pet then pet.Name else reward.Pet
	elseif reward.Kind == "PetSlot" then
		return "+1 Pet Slot"
	end
	return Format.Money(Rules.Amount(reward, State.Number("Income")))
end

--------------------------------------------------------------------------------
-- Cards
--------------------------------------------------------------------------------
local function buildCard(parent: Instance, day: number, size: Vector2, position: Vector2, big: boolean): Card
	local frame = Theme.new("Frame", {
		Name = "Day" .. day,
		Size = UDim2.fromOffset(size.X, size.Y),
		Position = UDim2.fromOffset(position.X, position.Y),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
		Parent = parent,
	}, {
		Theme.Corner(6),
		Theme.Stroke(3),
		Theme.Gradient(rgb(120, 120, 126), rgb(80, 80, 86)),
	})
	local pop = Theme.new("UIScale", { Parent = frame })

	-- the dark strip with "Day N" and two streaks of light
	local stripHeight = if big then 48 else 36
	local strip = Theme.new("Frame", {
		Name = "Strip",
		Size = UDim2.new(1, 0, 0, stripHeight),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		ZIndex = 3,
		Parent = frame,
	}, {
		Theme.Corner(6),
		Theme.Gradient(rgb(74, 74, 80), rgb(46, 46, 52)),
	})
	Theme.new("Frame", { Name = "Square", Size = UDim2.new(1, 0, 0, 8), Position = UDim2.new(0, 0, 1, -8), BackgroundColor3 = rgb(46, 46, 52), BorderSizePixel = 0, ZIndex = 3, Parent = strip })
	for i, streak in { { X = 0.16, W = if big then 18 else 13 }, { X = 0.25, W = if big then 8 else 6 } } do
		Theme.new("Frame", {
			Name = "Streak" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(streak.X, 0.5),
			Size = UDim2.new(0, streak.W, 2, 0),
			Rotation = 24,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.84,
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = strip,
		})
	end
	Theme.Label({ Name = "Title", Text = `Day {day}`, Size = UDim2.new(1, -12, 1, -10), Position = UDim2.fromOffset(6, 5), StrokeThickness = 3, ZIndex = 4, Parent = strip })
	Theme.new("Frame", { Name = "Line", Size = UDim2.new(1, 0, 0, 3), Position = UDim2.fromOffset(0, stripHeight - 1), BackgroundColor3 = Theme.Colors.Outline, BorderSizePixel = 0, ZIndex = 4, Parent = frame })

	-- the studded area under it, with the reward in the middle
	local area = Theme.new("Frame", {
		Name = "Area",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(0, stripHeight + 2),
		Size = UDim2.new(1, 0, 1, -(stripHeight + 2)),
		ZIndex = 2,
		Parent = frame,
	})
	local picture = Theme.new("Frame", {
		Name = "Picture",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = if big then UDim2.fromScale(0.96, 0.7) else UDim2.fromScale(0.86, 0.64),
		ZIndex = 3,
		Parent = area,
	})
	local op = Theme.Label({
		Name = "OP",
		Text = "OP!",
		TextColor3 = GOLD,
		Rotation = -10,
		Size = if big then UDim2.fromOffset(110, 54) else UDim2.fromOffset(56, 30),
		Position = UDim2.fromOffset(if big then 6 else 4, if big then 6 else 2),
		StrokeThickness = if big then 5 else 3,
		StrokeColor = rgb(90, 50, 0),
		ZIndex = 6,
		Parent = area,
	})
	local label = Theme.Label({
		Name = "Reward",
		Text = "",
		TextColor3 = NAME,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, -12, 0, if big then 44 else 28),
		StrokeThickness = if big then 4.5 else 3,
		ZIndex = 6,
		Parent = area,
	})

	-- claimed: dimmed with a green tick; ready: a white glow and a big green "Claim!"
	local shade = Theme.new("Frame", { Name = "Shade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 7, Parent = frame }, { Theme.Corner(6) })
	local tick = Icons.Draw("check", frame, rgb(60, 60, 66), {
		Size = UDim2.fromScale(if big then 0.32 else 0.42, if big then 0.32 else 0.42),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
	})
	tick.Name = "Tick"
	tick.ZIndex = 8
	tick.Visible = false
	local glow = Theme.new("Frame", { Name = "Glow", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.55, Visible = false, ZIndex = 7, Parent = frame }, { Theme.Corner(6) })
	local claim = Theme.Label({
		Name = "Claim",
		Text = "Claim!",
		TextColor3 = GREEN,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = if big then UDim2.new(0.9, 0, 0, 74) else UDim2.new(0.94, 0, 0, 48),
		StrokeThickness = if big then 5 else 4,
		Visible = false,
		ZIndex = 9,
		Parent = frame,
	})
	local pulse = Theme.new("UIScale", { Parent = claim })
	TweenService:Create(pulse, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.1 }):Play()

	local button = Theme.new("TextButton", { Name = "Button", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 10, Parent = frame })
	button.Activated:Connect(function()
		if view().Claimable == day then
			State.Action("ClaimDaily")
		end
	end)

	return {
		Day = day,
		Frame = frame,
		Area = area,
		Picture = picture,
		Label = label,
		OP = op,
		Shade = shade,
		Tick = tick,
		Glow = glow,
		Claim = claim,
		Pop = pop,
		Shows = "",
		Big = big,
	}
end

-- The studs on every card (the first time the window opens).
local function addStuds()
	if studded then
		return
	end
	studded = true
	for _, card in cards do
		local size = card.Frame.Size
		local studs = Theme.Studs(card.Area, Vector2.new(size.X.Offset, size.Y.Offset), { Cell = if card.Big then 26 else 20, Transparency = 0.84 })
		studs.ZIndex = 2
	end
end

local function refresh()
	if not modal:IsOpen() then
		return
	end
	local v = view()
	for _, card in cards do
		local reward = Rules.Reward(card.Day, v.Round)
		setPicture(card, reward)
		card.Label.Text = nameOf(reward)
		card.OP.Visible = reward.OP == true
		local claimed = card.Day <= v.Claimed
		local claimable = v.Claimable == card.Day
		card.Shade.BackgroundTransparency = if claimed then 0.45 else 1
		card.Tick.Visible = claimed
		card.Glow.Visible = claimable
		card.Claim.Visible = claimable
	end
	if v.Claimable then
		modal:SetCount(nil)
	else
		modal:SetCount(`Next in {Format.Duration(Rules.NextDayAt(now()) - now())}`)
	end
	-- just claimed one: it pops
	if lastClaimed and v.Claimed > lastClaimed then
		local card = cards[v.Claimed]
		if card then
			card.Pop.Scale = 1.12
			TweenService:Create(card.Pop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end
	lastClaimed = v.Claimed
end

function DailyRewards.Open()
	modal:Open()
end

-- Open the window if a reward is waiting (after the Update Log on joining).
function DailyRewards.OpenIfReady()
	if DailyRewards.Ready() and not Modal.AnyOpen() then
		modal:Open()
	end
end

function DailyRewards.Init()
	modal = Modal.new("Daily Rewards!", Theme.Colors.Gray, SIZE, {
		HeaderTop = rgb(96, 96, 102),
		HeaderBottom = rgb(58, 58, 64),
		HeaderStuds = rgb(20, 20, 24),
		BodyTop = rgb(74, 76, 80),
		BodyBottom = rgb(44, 46, 50),
	})
	local body = modal.Body
	-- Days 1-6 in two rows of three, Day 7 big on the right
	for day = 1, 6 do
		local column, row = (day - 1) % 3, (day - 1) // 3
		table.insert(cards, buildCard(body, day, CARD, Vector2.new(column * (CARD.X + GAP), row * (CARD.Y + GAP)), false))
	end
	table.insert(cards, buildCard(body, 7, BIG, Vector2.new(3 * (CARD.X + GAP), 0), true))

	modal.OnOpen = function()
		addStuds()
		lastClaimed = nil
		refresh()
	end
	State.Changed:Connect(refresh)
	State.OnAttribute("Income", function()
		if modal:IsOpen() then
			refresh()
		end
	end)
	-- the countdown in the title (and the day turning over while it's open)
	task.spawn(function()
		while true do
			task.wait(1)
			refresh()
		end
	end)
end

return DailyRewards
