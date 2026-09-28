--[[
	Pets window:
	  Eggs - the eggs in your incubator, each with a countdown, and a HATCH button when it's ready
	         (plus what's inside each egg and the chances)
	  Pets - every pet you own: equip up to Config.Pets.MaxEquipped (they follow you and give their
	         money / treadmill bonus), Equip Best, or release pets you don't want.
	Hatching plays a full-screen animation: the egg shakes harder and harder, cracks, flashes, and
	the pet pops out.
]]

local RunService = game:GetService("RunService")
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
local function preview(parent: Instance, model: Model, size: UDim2, position: UDim2): ViewportFrame
	local viewport = Theme.new("ViewportFrame", {
		BackgroundColor3 = Color3.fromRGB(25, 25, 40),
		Size = size,
		Position = position,
		Ambient = Color3.fromRGB(170, 170, 170),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-0.5, -1, 0.8),
		Parent = parent,
	}, { Theme.Corner(10) })
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
	return Theme.new("Frame", { BackgroundColor3 = Theme.Colors.PanelLight, LayoutOrder = order, Parent = page }, {
		Theme.Corner(12),
		Theme.Stroke(3, color),
	})
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
			entry.Label.Text = "⏳ " .. Format.Duration(left)
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
			preview(c, PetModel.BuildEgg(egg, { NoEffects = true }), UDim2.new(1, -12, 0, 92), UDim2.fromOffset(6, 6))
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
			preview(c, PetModel.BuildPet(pet, { NoEffects = true }), UDim2.new(1, -12, 0, 92), UDim2.fromOffset(6, 6))
			Theme.Label({ Text = rarity.Id, TextColor3 = rarity.Color, Font = Theme.Font, Size = UDim2.new(1, -8, 0, 16), Position = UDim2.fromOffset(4, 100), StrokeThickness = 1.2, Parent = c })
			Theme.Label({ Text = pet.Name, Size = UDim2.new(1, -8, 0, 22), Position = UDim2.fromOffset(4, 116), StrokeThickness = 2, Parent = c })
			Theme.Label({ Text = Pets.BonusText(pet), Font = Theme.Font, TextColor3 = Theme.Colors.Money, Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromOffset(4, 140), StrokeThickness = 1.2, Parent = c })
			local equip = Theme.Button({ Text = if isEquipped then "UNEQUIP" else "EQUIP", Color = if isEquipped then Theme.Colors.Orange else Theme.Colors.Green, Size = UDim2.new(0.72, -10, 0, 32), Position = UDim2.new(0, 6, 1, -38), Parent = c })
			equip.Activated:Connect(function()
				State.Action(if isEquipped then "UnequipPet" else "EquipPet", petData.Uid)
			end)
			local release = Theme.Button({ Text = "✖", Color = Theme.Colors.Red, Size = UDim2.new(0.28, -4, 0, 32), Position = UDim2.new(0.72, -2, 1, -38), Parent = c })
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
							Theme.SetButtonText(release, "✖")
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
		header.Text = `🥚 Incubator {#(State.Data.Eggs or {})}/{capacity}  •  ⚡ x{Format.Multiplier(hatchSpeed)} speed  •  upgrade it in the Shop`
	else
		header.Text = `🐾 {#pets}/{Config.Pets.MaxPets} pets   •   Equipped {#equippedIds}/{Config.Pets.MaxEquipped}: +{math.floor(money * 100 + 0.5)}% money, +{math.floor(speed * 100 + 0.5)}% speed`
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
local function playHatch(info: { EggId: string, PetId: string })
	local egg = Pets.EggById[info.EggId]
	local pet = Pets.ById[info.PetId]
	if not egg or not pet then
		return
	end
	local rarity = Pets.Rarity(pet.Rarity)
	modal:Close()
	overlay.Visible = true
	overlay.BackgroundTransparency = 1
	TweenService:Create(overlay, TweenInfo.new(0.3), { BackgroundTransparency = 0.35 }):Play()
	local stage = Theme.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromOffset(340, 340), BackgroundTransparency = 1, Parent = overlay })
	Theme.AutoScale(stage)
	local eggView = preview(stage, PetModel.BuildEgg(egg, { NoEffects = true }), UDim2.fromScale(1, 1), UDim2.new())
	eggView.BackgroundTransparency = 1
	-- Shake harder and harder
	local shaking = true
	local startedAt = os.clock()
	local connection = RunService.RenderStepped:Connect(function()
		if not shaking then
			return
		end
		local p = math.clamp((os.clock() - startedAt) / 2.2, 0, 1)
		eggView.Rotation = math.sin(os.clock() * (8 + p * 30)) * (4 + p * 22)
		eggView.Position = UDim2.fromOffset(math.sin(os.clock() * 40) * p * 6, 0)
	end)
	for i = 1, 3 do
		task.delay(0.6 * i, function()
			Theme.PlaySound("Crack")
		end)
	end
	task.wait(2.2)
	shaking = false
	connection:Disconnect()
	-- Flash!
	local flash = Theme.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, ZIndex = 5, Parent = overlay })
	TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	task.delay(0.7, function()
		flash:Destroy()
	end)
	Theme.PlaySound("Hatch")
	eggView:Destroy()
	-- Rays behind the pet for the rare ones
	if rarity.Order >= 4 then
		for i = 1, 8 do
			local ray = Theme.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(18, 460), Rotation = i * 22.5, BackgroundColor3 = rarity.Color, BackgroundTransparency = 0.6, BorderSizePixel = 0, Parent = stage }, {
				Theme.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }) }),
			})
			TweenService:Create(ray, TweenInfo.new(6, Enum.EasingStyle.Linear), { Rotation = ray.Rotation + 90 }):Play()
		end
	end
	local petView = preview(stage, PetModel.BuildPet(pet, { NoEffects = true }), UDim2.fromScale(1, 1), UDim2.new())
	petView.BackgroundTransparency = 1
	local popScale = Theme.new("UIScale", { Scale = 0.2, Parent = petView })
	TweenService:Create(popScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local title = Theme.Label({ Text = `{string.upper(rarity.Id)}!`, TextColor3 = rarity.Color, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -70), Size = UDim2.fromOffset(420, 48), StrokeThickness = 4, Parent = stage })
	Theme.Label({ Text = pet.Name, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(420, 44), StrokeThickness = 3.5, Parent = stage })
	Theme.Label({ Text = `{Pets.BonusText(pet)}  ({string.format("%.3g", Pets.Chance(egg, pet.Id) * 100)}% chance)`, Font = Theme.Font, TextColor3 = Theme.Colors.Money, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 46), Size = UDim2.fromOffset(420, 26), StrokeThickness = 2, Parent = stage })
	if rarity.Order >= 6 then
		task.spawn(function()
			while title.Parent do
				title.TextColor3 = Color3.fromHSV((os.clock() * 0.4) % 1, 0.7, 1)
				task.wait()
			end
		end)
	end
	-- Spin the pet slowly until it closes
	local camera = petView:FindFirstChildOfClass("Camera")
	local spin = RunService.RenderStepped:Connect(function(dt: number)
		if camera then
			camera.CFrame = CFrame.Angles(0, dt * 0.8, 0) * camera.CFrame
		end
	end)
	task.wait(3.2)
	spin:Disconnect()
	TweenService:Create(overlay, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	stage:Destroy()
	task.wait(0.3)
	overlay.Visible = false
end

function PetsWindow.Open()
	modal:Open()
end

function PetsWindow.Init()
	modal = Modal.new("🐾 PETS", Theme.Colors.Pink, Vector2.new(760, 520))
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
		{ Name = "Eggs", Text = "🥚 Eggs", Color = Theme.Colors.Orange },
		{ Name = "Pets", Text = "🐾 Pets", Color = Theme.Colors.Pink },
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
	local queue: { { EggId: string, PetId: string } } = {}
	local playing = false
	Remotes.Event("EggHatched").OnClientEvent:Connect(function(info)
		table.insert(queue, info)
		if playing then
			return
		end
		playing = true
		while #queue > 0 do
			local next = table.remove(queue, 1)
			if next then
				playHatch(next)
			end
		end
		playing = false
	end)
end

return PetsWindow
