--[[
	Pets window:
	  Eggs - the eggs in your incubator, each with a countdown, and a HATCH button when it's ready
	         (plus what's inside each egg and the chances)
	  Pets - every pet you own: equip up to Config.Pets.MaxEquipped, plus a slot from Daily Rewards (they follow you and give their
	         money / treadmill bonus), Equip Best, or release pets you don't want.
	Hatching plays a full-screen animation in a vignette: the egg drops in, wobbles and cracks three
	times as the light behind it grows, glows from inside (in the pet's colour if it's Epic or
	better), bursts in a flash of shell, and the pet pops out spinning under its rarity. Click to
	skip ahead. PetsWindow.PreviewHatch() plays one just to watch (the admin panel).
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Pets = require(Shared.Pets)
local PetModel = require(Shared.PetModel)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local State = require(script.Parent.Parent.State)

local PetsWindow = {}

local modal: Modal.Modal
local pages: { [string]: ScrollingFrame } = {}
local header: TextLabel
local eggCards: { [string]: { Frame: Frame, Bar: Frame, Label: TextLabel, Button: TextButton, HatchAt: number } } = {}
local currentTab = "Eggs"
local overlay: Frame
local confirmRelease: string? = nil

-- A 3D preview of a model in a ViewportFrame (the model's Top/Bottom attributes frame the camera).
-- With a `color`, it sits on studs of that colour (like the Index's pictures).
local function preview(parent: Instance, model: Model, size: UDim2, position: UDim2, color: Color3?): ViewportFrame
	local viewport = Theme.new("ViewportFrame", {
		BackgroundColor3 = Color3.fromRGB(25, 25, 40),
		Size = size,
		Position = position,
		Ambient = Color3.fromRGB(170, 170, 170),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-0.5, -1, 0.8),
		Parent = parent,
	}, { Theme.Corner(10) })
	if color then
		local picture = Theme.Picture(parent, size, position, color, Vector2.new(170, 110))
		viewport.BackgroundTransparency = 1
		viewport.Size = UDim2.fromScale(1, 1)
		viewport.Position = UDim2.new()
		viewport.ZIndex = 2
		viewport.Parent = picture
	end
	model:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(200), 0))
	model.Parent = viewport
	local top = (model:GetAttribute("Top") :: number?) or 1.5
	local bottom = (model:GetAttribute("Bottom") :: number?) or 1.5
	local centerY = (top - bottom) / 2
	local height = top + bottom
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(0, centerY + height * 0.25, -(height * 1.6 + 3)), Vector3.new(0, centerY, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport
end

local function clearPage(page: ScrollingFrame)
	for _, child in page:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function card(page: Instance, order: number, color: Color3): Frame
	return Theme.Card(page, order, color)
end

--------------------------------------------------------------------------------
-- Eggs
--------------------------------------------------------------------------------
local function refreshEggTimers()
	local now = workspace:GetServerTimeNow()
	for _, entry in eggCards do
		local left = entry.HatchAt - now
		if left <= 0 then
			entry.Label.Text = "READY!"
			entry.Label.TextColor3 = Color3.fromRGB(120, 255, 130)
			entry.Bar.Size = UDim2.fromScale(1, 1)
			entry.Button.Visible = true
		else
			entry.Label.Text = Format.Duration(left)
			entry.Label.TextColor3 = Color3.fromRGB(255, 255, 255)
			entry.Button.Visible = false
		end
	end
end

type EggData = { Uid: string, Id: string, HatchAt: number }
type PetData = { Uid: string, Id: string }

local function buildEggs()
	local page = pages.Eggs
	clearPage(page)
	table.clear(eggCards)
	local eggs: { EggData } = State.Data.Eggs or {}
	if #eggs == 0 then
		local empty = card(page, 1, Theme.Colors.Gray)
		Theme.Label({
			Text = "No eggs yet! Eggs show up in Area 4 and further. Grab one (your guard wakes up!) and bring it to your base.",
			Font = Theme.Font, Size = UDim2.new(1, -16, 1, -16), Position = UDim2.fromOffset(8, 8), StrokeThickness = 1.5, Parent = empty,
		})
	end
	for order, eggData in eggs do
		local egg = Pets.EggById[eggData.Id]
		if egg then
			local c = card(page, order, egg.Accent)
			preview(c, PetModel.BuildEgg(egg, { NoEffects = true }), UDim2.new(1, -12, 0, 92), UDim2.fromOffset(6, 8), egg.Accent:Lerp(Color3.new(1, 1, 1), 0.25))
			Theme.Label({ Text = egg.Name, TextColor3 = egg.Accent:Lerp(Color3.new(1, 1, 1), 0.4), Size = UDim2.new(1, -8, 0, 22), Position = UDim2.fromOffset(4, 100), StrokeThickness = 2, Parent = c })
			local barBack = Theme.new("Frame", { Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 126), BackgroundColor3 = Theme.Colors.Outline, Parent = c }, { Theme.Corner(6) })
			local total = egg.HatchSeconds
			local done = math.clamp(1 - (eggData.HatchAt - workspace:GetServerTimeNow()) / total, 0, 1)
			local bar = Theme.new("Frame", { Size = UDim2.fromScale(done, 1), BackgroundColor3 = egg.Accent, Parent = barBack }, { Theme.Corner(6) })
			TweenService:Create(bar, TweenInfo.new(math.max(0, eggData.HatchAt - workspace:GetServerTimeNow()), Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) }):Play()
			local label = Theme.Label({ Text = "", Font = Theme.Font, Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 2), StrokeThickness = 1.5, Parent = barBack })
			-- What's inside
			local odds = {}
			for _, entry in egg.Pool do
				local pet = Pets.ById[entry.Pet]
				table.insert(odds, `{pet.Name} {string.format("%.3g", Pets.Chance(egg, pet.Id) * 100)}%`)
			end
			Theme.Label({ Text = table.concat(odds, " • "), Font = Theme.Font, TextColor3 = Color3.fromRGB(200, 200, 215), Size = UDim2.new(1, -10, 0, 30), Position = UDim2.fromOffset(5, 152), StrokeThickness = 1, Parent = c })
			local hatch = Theme.Button({ Text = "HATCH!", Color = Theme.Colors.Green, Size = UDim2.new(1, -16, 0, 34), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Parent = c })
			hatch.Visible = false
			hatch.Activated:Connect(function()
				State.Action("HatchEgg", eggData.Uid)
			end)
			eggCards[eggData.Uid] = { Frame = c, Bar = bar, Label = label, Button = hatch, HatchAt = eggData.HatchAt }
		end
	end
	refreshEggTimers()
end

--------------------------------------------------------------------------------
-- Pets
--------------------------------------------------------------------------------
local function buildPets()
	local page = pages.Pets
	clearPage(page)
	local owned: { PetData } = State.Data.Pets or {}
	local equipped: { string } = State.Data.EquippedPets or {}
	local list = table.clone(owned)
	table.sort(list, function(a, b)
		local ea, eb = table.find(equipped, a.Uid) ~= nil, table.find(equipped, b.Uid) ~= nil
		if ea ~= eb then
			return ea
		end
		local pa, pb = Pets.ById[a.Id], Pets.ById[b.Id]
		local sa = if pa then pa.Money + pa.Speed else 0
		local sb = if pb then pb.Money + pb.Speed else 0
		return sa > sb
	end)
	if #list == 0 then
		local empty = card(page, 1, Theme.Colors.Gray)
		Theme.Label({ Text = "No pets yet! Hatch an egg to get your first pet.", Font = Theme.Font, Size = UDim2.new(1, -16, 1, -16), Position = UDim2.fromOffset(8, 8), StrokeThickness = 1.5, Parent = empty })
	end
	for order, petData in list do
		local pet = Pets.ById[petData.Id]
		if pet then
			local rarity = Pets.Rarity(pet.Rarity)
			local isEquipped = table.find(equipped, petData.Uid) ~= nil
			local c = card(page, order, if isEquipped then Theme.Colors.Green else rarity.Color)
			preview(c, PetModel.BuildPet(pet, { NoEffects = true }), UDim2.new(1, -12, 0, 92), UDim2.fromOffset(6, 8), rarity.Color:Lerp(Color3.new(1, 1, 1), 0.2))
			Theme.Label({ Text = rarity.Id, TextColor3 = rarity.Color, Font = Theme.Font, Size = UDim2.new(1, -8, 0, 16), Position = UDim2.fromOffset(4, 100), StrokeThickness = 1.2, Parent = c })
			Theme.Label({ Text = pet.Name, Size = UDim2.new(1, -8, 0, 22), Position = UDim2.fromOffset(4, 116), StrokeThickness = 2, Parent = c })
			Theme.Label({ Text = Pets.BonusText(pet), Font = Theme.Font, TextColor3 = Theme.Colors.Money, Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromOffset(4, 140), StrokeThickness = 1.2, Parent = c })
			local equip = Theme.Button({ Text = if isEquipped then "UNEQUIP" else "EQUIP", Color = if isEquipped then Theme.Colors.Orange else Theme.Colors.Green, Size = UDim2.new(0.72, -10, 0, 32), Position = UDim2.new(0, 6, 1, -38), Parent = c })
			equip.Activated:Connect(function()
				State.Action(if isEquipped then "UnequipPet" else "EquipPet", petData.Uid)
			end)
			local release = Theme.Button({ Text = "X", Color = Theme.Colors.Red, Size = UDim2.new(0.28, -4, 0, 32), Position = UDim2.new(0.72, -2, 1, -38), Parent = c })
			release.Activated:Connect(function()
				if confirmRelease == petData.Uid then
					confirmRelease = nil
					State.Action("ReleasePet", petData.Uid)
				else
					confirmRelease = petData.Uid
					Theme.SetButtonText(release, "SURE?")
					task.delay(3, function()
						if confirmRelease == petData.Uid then
							confirmRelease = nil
						end
						if release.Parent then
							Theme.SetButtonText(release, "X")
						end
					end)
				end
			end)
		end
	end
end

local function refreshHeader()
	local equippedIds = {}
	local pets: { PetData } = State.Data.Pets or {}
	local equipped: { string } = State.Data.EquippedPets or {}
	for _, uid in equipped do
		for _, pet in pets do
			if pet.Uid == uid then
				table.insert(equippedIds, pet.Id)
			end
		end
	end
	local money, speed = Economy.PetBonuses(equippedIds)
	if currentTab == "Eggs" then
		local capacity = Config.Pets.MaxEggs + Config.Pets.IncubatorSize.PerLevel * State.Number("IncubatorSize")
		local hatchSpeed = 1 + Config.Pets.IncubatorSpeed.PerLevel * State.Number("IncubatorSpeed")
		header.Text = `Incubator {#(State.Data.Eggs or {})}/{capacity}  •  x{Format.Multiplier(hatchSpeed)} speed  •  upgrade it in the Shop`
	else
		header.Text = `{#pets}/{Config.Pets.MaxPets} pets   •   Equipped {#equippedIds}/{Economy.MaxEquippedPets(State.Data.ExtraPetSlots)}: +{math.floor(money * 100 + 0.5)}% money, +{math.floor(speed * 100 + 0.5)}% speed`
	end
end

local function refresh()
	refreshHeader()
	if currentTab == "Eggs" then
		buildEggs()
	else
		buildPets()
	end
end

-- How many eggs are ready to hatch (HUD badge).
function PetsWindow.ReadyEggs(): number
	local now = workspace:GetServerTimeNow()
	local count = 0
	local eggs: { EggData } = State.Data.Eggs or {}
	for _, egg in eggs do
		if egg.HatchAt <= now then
			count += 1
		end
	end
	return count
end

--------------------------------------------------------------------------------
-- Hatch animation
--------------------------------------------------------------------------------
-- On its own clock (seconds): the egg drops in and bounces, wobbles three times (a crack and a
-- punch-in each time, the glow behind it growing), shakes like mad while it glows from inside -
-- in the pet's rarity colour if it's Epic or better, a hint of what's coming - then bursts in a
-- flash with bits of shell flying, and the pet pops out spinning, its rarity slammed on top.
-- Click to skip ahead (to the burst, then to the end).
local HATCH = { Drop = 0.55, Wobbles = { 0.8, 1.5, 2.15 }, Wobble = 0.42, Shake = 2.65, Burst = 3.3, Title = 3.5, Hold = 6.7, Close = 7.05 }

local function smooth(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * a * (a * (a * 6 - 15) + 10)
end

-- Overshoots past 1 and settles back (for pops)
local function backOut(a: number, s: number?): number
	a = math.clamp(a, 0, 1) - 1
	local c = s or 1.7
	return 1 + (c + 1) * a * a * a + c * a * a
end

-- Pulls back a little before it goes (for closing)
local function backIn(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * (2.7 * a - 1.7)
end

local function bounceOut(a: number): number
	a = math.clamp(a, 0, 1)
	if a < 1 / 2.75 then
		return 7.5625 * a * a
	elseif a < 2 / 2.75 then
		a -= 1.5 / 2.75
		return 7.5625 * a * a + 0.75
	elseif a < 2.5 / 2.75 then
		a -= 2.25 / 2.75
		return 7.5625 * a * a + 0.9375
	end
	a -= 2.625 / 2.75
	return 7.5625 * a * a + 0.984375
end

-- The cracks across the egg (x1, y1, x2, y2 in the 340x340 stage), the ones each wobble opens
local CRACKS = {
	{ { 114, 168, 134, 183 }, { 134, 183, 151, 160 }, { 151, 160, 146, 137 } },
	{ { 151, 160, 170, 185 }, { 170, 185, 188, 158 }, { 170, 185, 165, 207 } },
	{ { 188, 158, 206, 181 }, { 206, 181, 226, 165 }, { 188, 158, 196, 132 }, { 206, 181, 213, 204 } },
}

local WHITE = Color3.new(1, 1, 1)

local function crackLine(parent: Instance, x1: number, y1: number, x2: number, y2: number): Frame
	local dx, dy = x2 - x1, y2 - y1
	return Theme.new("Frame", {
		Name = "Crack",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2),
		Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + 3, 4),
		Rotation = math.deg(math.atan2(dy, dx)),
		BackgroundColor3 = Color3.fromRGB(255, 250, 225),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 4,
		Parent = parent,
	}, { Theme.new("UIStroke", { Thickness = 1.5, Color = Color3.fromRGB(45, 28, 22), Transparency = 0.15 }) })
end

local function circle(parent: Instance, name: string, size: Vector2, color: Color3, z: number): Frame
	return Theme.new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = color,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	}, { Theme.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
end

-- Dark edges round the screen (like a film), faded in with `alpha`
local function vignette(parent: Instance): { Frame }
	local edges = {}
	for _, side in { { 0, 0, 0.27, 1, 0 }, { 1, 0, 0.27, 1, 180 }, { 0, 0, 1, 0.32, 90 }, { 0, 1, 1, 0.32, 270 } } do
		table.insert(
			edges,
			Theme.new("Frame", {
				Name = "Vignette",
				AnchorPoint = Vector2.new(side[1], side[2]),
				Position = UDim2.fromScale(side[1], side[2]),
				Size = UDim2.fromScale(side[3], side[4]),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 8,
				Parent = parent,
			}, {
				Theme.new("UIGradient", {
					Rotation = side[5],
					Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.65), NumberSequenceKeypoint.new(1, 1) }),
				}),
			})
		)
	end
	return edges
end

-- A label's text and outline, `alpha` 0 (hidden) .. 1 (shown)
local function showText(label: TextLabel, alpha: number)
	label.TextTransparency = 1 - alpha
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = 1 - alpha
	end
end

local function playHatch(info: { EggId: string, PetId: string }, speed: number?)
	local egg = Pets.EggById[info.EggId]
	local pet = Pets.ById[info.PetId]
	if not egg or not pet then
		return
	end
	local rarity = Pets.Rarity(pet.Rarity)
	local rate = speed or 1
	if modal then
		modal:Close()
	end
	overlay.Visible = true
	overlay.BackgroundTransparency = 1
	local rng = Random.new()
	local eggGlow = egg.Accent:Lerp(WHITE, 0.45)
	-- (Epic and better: the glow turns their colour just before it bursts)
	local teaseGlow = if rarity.Order >= 4 then rarity.Color else eggGlow

	local show = Theme.new("Frame", { Name = "Show", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = overlay })
	local stage = Theme.new("Frame", { Name = "Stage", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromOffset(340, 340), BackgroundTransparency = 1, Parent = show })
	Theme.AutoScale(stage)
	-- (everything on the stage moves together in here: the slow push-in, the punches, the shakes)
	local inner = Theme.new("Frame", { Name = "Inner", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = stage })
	local zoom = Theme.new("UIScale", { Scale = 1, Parent = inner })
	local edges = vignette(show)
	local flash = Theme.new("Frame", { Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 9, Parent = show })
	local skip = Theme.new("TextButton", { Name = "Skip", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 10, Parent = show })
	skip:SetAttribute("Silent", true)
	local hint = Theme.Label({ Text = "Click to skip", Font = Theme.Font, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(240, 24), StrokeThickness = 2, ZIndex = 10, Parent = show })
	showText(hint, 0)

	-- The glow behind the egg (rings of light), and rays turning round it
	local glows = {}
	for i, spec in { { 340, 0.9 }, { 250, 0.8 }, { 165, 0.68 } } do
		glows[i] = { Frame = circle(inner, "Glow", Vector2.new(spec[1], spec[1]), eggGlow, 1), Size = spec[1], Alpha = 1 - spec[2] }
	end
	local rays = {}
	local rayCount = 6 + rarity.Order * 2
	for i = 1, rayCount do
		rays[i] = Theme.new("Frame", {
			Name = "Ray",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(if i % 2 == 0 then 16 else 30, 640),
			BackgroundColor3 = eggGlow,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 1,
			Parent = inner,
		}, {
			Theme.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }),
		})
	end
	-- Shockwaves when it bursts
	local rings = {}
	for i = 1, 2 do
		local ring = circle(inner, "Shockwave", Vector2.new(40, 40), WHITE, 2)
		rings[i] = { Frame = ring, Stroke = Theme.new("UIStroke", { Thickness = if i == 1 then 12 else 5, Color = if i == 1 then WHITE else rarity.Color, Transparency = 1, Parent = ring }), Delay = (i - 1) * 0.09 }
	end

	-- The egg, the light inside it and its cracks
	local eggHolder = Theme.new("Frame", { Name = "Egg", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -560), Size = UDim2.fromOffset(340, 340), BackgroundTransparency = 1, ZIndex = 3, Parent = inner })
	local eggView = preview(eggHolder, PetModel.BuildEgg(egg, { NoEffects = true }), UDim2.fromScale(1, 1), UDim2.new())
	eggView.BackgroundTransparency = 1
	local inside = circle(eggHolder, "InnerGlow", Vector2.new(124, 168), eggGlow, 2)
	local cracks: { { Frame } } = {}
	for wobble, list in CRACKS do
		cracks[wobble] = {}
		for _, s in list do
			table.insert(cracks[wobble], crackLine(eggHolder, s[1], s[2], s[3], s[4]))
		end
	end

	-- The pet (built now, hidden, so the burst doesn't stutter)
	local petHolder = Theme.new("Frame", { Name = "Pet", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(340, 340), BackgroundTransparency = 1, Visible = false, ZIndex = 3, Parent = inner })
	local petView = preview(petHolder, PetModel.BuildPet(pet, { NoEffects = true }), UDim2.fromScale(1, 1), UDim2.new())
	petView.BackgroundTransparency = 1
	local pop = Theme.new("UIScale", { Scale = 0.15, Parent = petHolder })
	local petCamera = petView:FindFirstChildOfClass("Camera")
	local petCameraStart = if petCamera then petCamera.CFrame else CFrame.identity

	-- Twinkles round the pet (more for rarer pets)
	local sparkles = {}
	for i = 1, 4 + rarity.Order * 2 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(110, 180)
		local color = if i % 2 == 0 then rarity.Color:Lerp(WHITE, 0.45) else WHITE
		local star = Theme.new("Frame", {
			Name = "Sparkle",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(170 + math.cos(angle) * radius, 170 + math.sin(angle) * radius * 0.85),
			Size = UDim2.fromOffset(28, 28),
			Rotation = rng:NextNumber(-20, 20),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 4,
			Parent = inner,
		}, {
			Theme.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = color, BorderSizePixel = 0 }, { Theme.Corner(2) }),
			Theme.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.7, 0, 0, 4), BackgroundColor3 = color, BorderSizePixel = 0 }, { Theme.Corner(2) }),
		})
		sparkles[i] = { Frame = star, Scale = Theme.new("UIScale", { Scale = 0, Parent = star }), Phase = rng:NextNumber(0, 1), Speed = rng:NextNumber(2.2, 3.6) }
	end

	-- What it is
	local title = Theme.Label({ Text = `{string.upper(rarity.Id)}!`, TextColor3 = rarity.Color, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, -38), Size = UDim2.fromOffset(460, 62), StrokeThickness = 4, ZIndex = 5, Parent = inner })
	local titleScale = Theme.new("UIScale", { Scale = 1, Parent = title })
	local name = Theme.Label({ Text = pet.Name, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(420, 44), StrokeThickness = 3.5, ZIndex = 5, Parent = inner })
	local bonus = Theme.Label({
		Text = `{Pets.BonusText(pet)}  ({string.format("%.3g", Pets.Chance(egg, pet.Id) * 100)}% chance)`,
		Font = Theme.Font,
		TextColor3 = Theme.Colors.Money,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 46),
		Size = UDim2.fromOffset(420, 26),
		StrokeThickness = 2,
		ZIndex = 5,
		Parent = inner,
	})
	for _, label in { title, name, bonus } do
		showText(label, 0)
	end

	local chips = {}
	local function burstShell()
		for i = 1, 18 do
			local angle = rng:NextNumber(0, math.pi * 2)
			local fling = rng:NextNumber(320, 720)
			local chip = Theme.new("Frame", {
				Name = "Shell",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(rng:NextInteger(12, 28), rng:NextInteger(10, 22)),
				BackgroundColor3 = if i % 3 == 0 then egg.Accent else egg.Color,
				BorderSizePixel = 0,
				ZIndex = 4,
				Parent = inner,
			}, { Theme.Corner(4) })
			chips[i] = {
				Frame = chip,
				Stroke = Theme.new("UIStroke", { Thickness = 1.5, Color = Color3.fromRGB(35, 22, 22), Parent = chip }),
				X = 170 + math.cos(angle) * 20,
				Y = 170 + math.sin(angle) * 30,
				VX = math.cos(angle) * fling,
				VY = math.sin(angle) * fling - 260,
				Turn = rng:NextNumber(0, 360),
				Spin = rng:NextNumber(-540, 540),
			}
		end
	end

	-- Moments that happen once (sounds, the burst), in order
	local events = {}
	for i, at in HATCH.Wobbles do
		table.insert(events, { At = at + HATCH.Wobble * 0.45, Name = "Crack", Index = i })
	end
	table.insert(events, { At = HATCH.Burst, Name = "Burst" })
	table.insert(events, { At = HATCH.Title + 0.14, Name = "Slam" })
	local nextEvent = 1
	local punchAt = -10 -- (when the last punch-in happened: cracks and the title slam)
	local shakeAt = -10

	local skipTo: number? = nil
	skip.Activated:Connect(function()
		skipTo = -1 -- (worked out on the next frame, on the hatch's own clock)
	end)

	local startedAt = os.clock()
	local offset = 0
	local last = 0
	local run = function()
		while true do
			task.wait()
			local t = (os.clock() - startedAt) * rate + offset
			if skipTo then
				-- before the burst: straight to it; after it: to the end
				local goal = if t < HATCH.Burst - 0.05 then HATCH.Burst - 0.05 elseif t > HATCH.Burst + 0.5 and t < HATCH.Hold then HATCH.Hold else t
				if goal > t then
					offset += goal - t
					t = goal
					-- (the cracks we skipped past open without their sounds)
					while events[nextEvent] and events[nextEvent].At < t and events[nextEvent].Name == "Crack" do
						for _, line in cracks[events[nextEvent].Index] do
							line.Visible = true
						end
						nextEvent += 1
					end
				end
				skipTo = nil
			end
			local dt = math.max(t - last, 0)
			last = t
			if t >= HATCH.Close then
				break
			end

			-- Moments
			while events[nextEvent] and t >= events[nextEvent].At do
				local event = events[nextEvent]
				nextEvent += 1
				if event.Name == "Crack" then
					for _, line in cracks[event.Index] do
						line.Visible = true
					end
					Theme.PlaySound("Crack")
					punchAt = t
				elseif event.Name == "Burst" then
					Theme.PlaySound("Hatch")
					eggHolder.Visible = false
					petHolder.Visible = true
					burstShell()
					shakeAt = t
				elseif event.Name == "Slam" then
					Theme.PlaySound(if rarity.Order >= 4 then "Rare" else "Success")
					punchAt = t
					shakeAt = t
				end
			end

			-- The backdrop and the vignette
			local closing = smooth((t - HATCH.Hold) / (HATCH.Close - HATCH.Hold))
			overlay.BackgroundTransparency = 1 - 0.72 * smooth(t / 0.35) * (1 - closing)
			for _, edge in edges do
				edge.BackgroundTransparency = 1 - 0.85 * smooth(t / 0.4) * (1 - closing)
			end
			showText(hint, smooth((t - 0.5) / 0.4) * (1 - closing) * 0.8)

			-- The slow push-in, punches and shakes
			local burst = t - HATCH.Burst
			local push = if burst < 0 then 1 + 0.14 * smooth(t / HATCH.Burst) else 1.14 - 0.1 * smooth(burst / 0.6)
			local sincePunch = t - punchAt
			local punch = if sincePunch >= 0 and sincePunch < 0.4 then 0.06 * math.exp(-sincePunch * 9) else 0
			zoom.Scale = (push + punch) * (1 - backIn(closing))
			local sinceShake = t - shakeAt
			local shake = if sinceShake >= 0 and sinceShake < 0.45 then 14 * math.exp(-sinceShake * 7) else 0
			if t > HATCH.Shake and burst < 0 then
				shake += 2 + 6 * smooth((t - HATCH.Shake) / (HATCH.Burst - HATCH.Shake))
			end
			inner.Position = UDim2.new(0.5, math.sin(t * 71) * shake, 0.5, math.cos(t * 63) * shake * 0.7)

			-- The egg: drop, bounce, wobbles, the shake before it bursts
			if burst < 0 then
				local drop = bounceOut(t / HATCH.Drop)
				local land = t - HATCH.Drop
				local squash = if land >= 0 then 0.16 * math.exp(-land * 9) * math.cos(land * 28) else 0
				local rot, hop = math.sin(t * 2.1) * 2, 0
				for i, at in HATCH.Wobbles do
					local w = (t - at) / HATCH.Wobble
					if w >= 0 and w < 1 then
						local amount = 9 + i * 6
						rot = math.sin(w * math.pi * 5) * amount * (1 - w)
						hop = -math.abs(math.sin(w * math.pi * 2)) * amount * 0.9 * (1 - w)
					end
				end
				local fury = smooth((t - HATCH.Shake) / (HATCH.Burst - HATCH.Shake))
				if fury > 0 then
					rot = math.sin(t * 58) * (6 + fury * 12)
					hop = math.cos(t * 47) * fury * 6
				end
				eggHolder.Position = UDim2.new(0.5, 0, 0.5, -560 * (1 - drop) + hop)
				eggHolder.Size = UDim2.fromOffset(340 * (1 + squash), 340 * (1 - squash))
				eggHolder.Rotation = rot
				-- (light from inside: a flicker at each crack, white-hot just before the burst)
				local crackGlow = if sincePunch >= 0 and sincePunch < 0.35 then 0.35 * (1 - sincePunch / 0.35) else 0
				inside.BackgroundColor3 = eggGlow:Lerp(teaseGlow, fury):Lerp(WHITE, fury * fury * 0.6)
				inside.BackgroundTransparency = 1 - math.clamp(crackGlow + fury * 0.85, 0, 0.92)
				inside.Size = UDim2.fromOffset(124 * (1 + fury * 0.25), 168 * (1 + fury * 0.25))
			end

			-- The glow and the rays: growing with every crack, full blast at the burst
			local build = smooth((t - HATCH.Wobbles[1]) / (HATCH.Burst - HATCH.Wobbles[1]))
			local fury = smooth((t - HATCH.Shake) / (HATCH.Burst - HATCH.Shake))
			local glowColor = if burst < 0 then eggGlow:Lerp(teaseGlow, fury) else rarity.Color
			local glowAmount = if burst < 0 then 0.25 + build * 0.6 else 1
			local pulse = 1 + 0.05 * math.sin(t * 5)
			for _, glow in glows do
				local grow = if burst < 0 then 0.55 + build * 0.45 else 1 + 0.25 * math.exp(-burst * 3)
				glow.Frame.BackgroundColor3 = glowColor
				glow.Frame.BackgroundTransparency = 1 - glow.Alpha * glowAmount * (1 - closing)
				glow.Frame.Size = UDim2.fromOffset(glow.Size * grow * pulse, glow.Size * grow * pulse)
			end
			local rayAlpha = if burst < 0 then smooth((t - HATCH.Wobbles[2]) / 1.2) * 0.45 else 0.75
			local spin = t * 18 + (if burst > 0 then 140 * (1 - math.exp(-burst * 2.5)) else 0)
			for i, ray in rays do
				ray.BackgroundColor3 = glowColor
				ray.BackgroundTransparency = 1 - rayAlpha * (1 - closing) * (if i % 2 == 0 then 0.7 else 1)
				ray.Rotation = i / rayCount * 180 + spin
				local reach = if burst < 0 then 0.55 + build * 0.3 else 1
				ray.Size = UDim2.fromOffset(if i % 2 == 0 then 16 else 30, 640 * reach)
			end

			-- The burst: a white flash, shockwaves, bits of shell
			if burst >= 0 then
				flash.BackgroundTransparency = 1 - math.clamp(1 - burst / 0.55, 0, 1) ^ 2
				for _, ring in rings do
					local k = (burst - ring.Delay) / 0.55
					if k >= 0 and k <= 1 then
						local size = 40 + 760 * (1 - (1 - k) ^ 3)
						ring.Frame.Size = UDim2.fromOffset(size, size)
						ring.Stroke.Transparency = k
					else
						ring.Stroke.Transparency = 1
					end
				end
				for _, chip in chips do
					chip.VY += 1150 * dt
					chip.X += chip.VX * dt
					chip.Y += chip.VY * dt
					chip.Turn += chip.Spin * dt
					local fade = math.clamp((burst - 0.55) / 0.5, 0, 1)
					chip.Frame.Position = UDim2.fromOffset(chip.X, chip.Y)
					chip.Frame.Rotation = chip.Turn
					chip.Frame.BackgroundTransparency = fade
					chip.Stroke.Transparency = fade
					chip.Frame.Visible = fade < 1
				end

				-- The pet pops out (squash and stretch), spins round once and floats
				local k = burst / 0.5
				pop.Scale = 0.15 + 0.85 * backOut(k, 2.6)
				local stretch = 0.2 * math.exp(-burst * 7) * math.cos(burst * 24)
				petHolder.Size = UDim2.fromOffset(340 * (1 - stretch), 340 * (1 + stretch))
				petHolder.Position = UDim2.new(0.5, 0, 0.5, math.sin(burst * 2.2) * 5)
				if petCamera then
					local whirl = math.pi * 2 * (1 - (1 - math.clamp(burst / 0.9, 0, 1)) ^ 3)
					petCamera.CFrame = CFrame.Angles(0, whirl + burst * 0.7, 0) * petCameraStart
				end
				for _, sparkle in sparkles do
					sparkle.Frame.Visible = true
					local twinkle = math.max(0, math.sin((burst * sparkle.Speed + sparkle.Phase) * math.pi * 2))
					sparkle.Scale.Scale = twinkle * smooth(burst / 0.4) * (1 - closing)
					sparkle.Frame.Rotation += dt * 40
				end
			end

			-- The rarity slams down, then the name and what it gives slide in
			local slam = (t - HATCH.Title) / 0.14
			if slam >= 0 then
				showText(title, smooth(slam * 2) * (1 - closing))
				-- (drops from big onto the screen, then squashes and springs back)
				titleScale.Scale = if slam < 1 then 2.6 - 1.6 * slam * slam else 1 - 0.14 * math.exp(-(slam - 1) * 0.9) * math.sin((slam - 1) * 1.6)
				if rarity.Order >= 6 then
					title.TextColor3 = Color3.fromHSV((t * 0.4) % 1, 0.7, 1)
				end
			end
			for i, label in { name, bonus } do
				local k = smooth((t - HATCH.Title - 0.2 - i * 0.12) / 0.3)
				showText(label, k * (1 - closing))
				label.Position = UDim2.new(0.5, 0, 1, (i - 1) * 46 + 24 * (1 - k))
			end
		end
	end
	local ok, err = pcall(function()
		run()
	end)
	if not ok then
		warn(`[Hatch] {err}`)
	end
	show:Destroy()
	overlay.BackgroundTransparency = 1
	overlay.Visible = false
end

-- One hatch after another (Hatch All): quicker while more are waiting
local queue: { { EggId: string, PetId: string } } = {}
local hatching = false
local function enqueue(info: { EggId: string, PetId: string })
	table.insert(queue, info)
	if hatching then
		return
	end
	hatching = true
	while #queue > 0 do
		local nextHatch = table.remove(queue, 1)
		if nextHatch then
			local ok, err = pcall(function()
				playHatch(nextHatch, if #queue > 0 then 1.5 else 1)
			end)
			if not ok then
				-- (never leave the show - and its full-screen skip button - over the game)
				warn(`[Hatch] {err}`)
				for _, child in overlay:GetChildren() do
					child:Destroy()
				end
				overlay.Visible = false
			end
		end
	end
	hatching = false
end

-- For the admin panel: hatch a random pet from a random egg, just to watch (nothing is given). Every
-- pet in the egg is as likely as the next, so the rare reveals show up too.
function PetsWindow.PreviewHatch(): boolean
	if not overlay or #Pets.Eggs == 0 then
		return false
	end
	local rng = Random.new()
	local egg = Pets.Eggs[rng:NextInteger(1, #Pets.Eggs)]
	local entry = egg.Pool[rng:NextInteger(1, #egg.Pool)]
	task.spawn(enqueue, { EggId = egg.Id, PetId = entry.Pet })
	return true
end

function PetsWindow.Open()
	modal:Open()
end

function PetsWindow.Init()
	modal = Modal.new("Pets", Theme.Colors.Pink, Vector2.new(760, 520))
	local body = modal.Body
	header = Theme.Label({ Text = "", Font = Theme.Font, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -330, 0, 28), Position = UDim2.fromOffset(0, 50), StrokeThickness = 1.5, Parent = body })
	local hatchAll = Theme.Button({ Text = "HATCH ALL READY", Color = Theme.Colors.Green, Size = UDim2.fromOffset(170, 34), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -150, 0, 48), Parent = body })
	hatchAll.Activated:Connect(function()
		State.Action("HatchEgg")
	end)
	local best = Theme.Button({ Text = "EQUIP BEST", Color = Theme.Colors.Blue, Size = UDim2.fromOffset(140, 34), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 48), Parent = body })
	best.Activated:Connect(function()
		State.Action("EquipBestPets")
	end)
	for _, name in { "Eggs", "Pets" } do
		pages[name] = Theme.new("ScrollingFrame", {
			Name = name,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 88),
			Size = UDim2.new(1, 0, 1, -88),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 8,
			Visible = false,
			Parent = body,
		}, {
			Theme.new("UIGridLayout", { CellSize = UDim2.fromOffset(168, 228), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
			Theme.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 8) }),
		})
	end
	local selectTab = Modal.Tabs(body, {
		{ Name = "Eggs", Text = "Eggs", Color = Theme.Colors.Orange },
		{ Name = "Pets", Text = "Pets", Color = Theme.Colors.Pink },
	}, function(name)
		currentTab = name
		for pageName, page in pages do
			page.Visible = pageName == name
		end
		hatchAll.Visible = name == "Eggs"
		best.Visible = name == "Pets"
		refresh()
	end)
	modal.OnOpen = function()
		selectTab(currentTab)
	end
	State.Changed:Connect(function()
		if modal:IsOpen() then
			refresh()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if modal:IsOpen() and currentTab == "Eggs" then
				refreshEggTimers()
			end
		end
	end)

	local gui = Theme.ScreenGui("Hatching", 30)
	overlay = Theme.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Visible = false, Parent = gui })
	gui.IgnoreGuiInset = true
	Remotes.Event("EggHatched").OnClientEvent:Connect(enqueue)
end

return PetsWindow
