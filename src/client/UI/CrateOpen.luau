--[[
	Crate opening animation (Remotes "CrateOpened", sent by the server's CrateService after it has
	already given the reward): the crate shakes harder and harder, flashes open, and what you got
	pops out - an egg or pet in 3D, or a big icon for coins / Speed Boost / Luck Event.
	Several crates in a row are queued and played one after another.
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Crates = require(Shared.Crates)
local CrateModel = require(Shared.CrateModel)
local PetModel = require(Shared.PetModel)
local Pets = require(Shared.Pets)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)

local CrateOpen = {}

type Info = { Crate: string, Kind: string, Amount: number?, Seconds: number?, Egg: string?, Pet: string? }

local overlay: Frame

-- A 3D model in a ViewportFrame, framed by its Top / Bottom attributes.
local function preview(parent: Instance, model: Model): ViewportFrame
	local viewport = Theme.new("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(180, 180, 180),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-0.5, -1, 0.8),
		Parent = parent,
	})
	model:PivotTo(CFrame.Angles(0, math.rad(200), 0))
	model.Parent = viewport
	local top = (model:GetAttribute("Top") :: number?) or 1.5
	local bottom = (model:GetAttribute("Bottom") :: number?) or 1.5
	local centerY = (top - bottom) / 2
	local height = top + bottom
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(0, centerY + height * 0.3, -(height * 1.7 + 3)), Vector3.new(0, centerY, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport
end

-- Big text for what you got: (icon, title, detail)
local function describe(info: Info): (string, string, string)
	if info.Kind == "Coins" then
		return "💰", Format.Money(info.Amount or 0), "Coins!"
	elseif info.Kind == "SpeedBoost" then
		return "⚡", "SPEED BOOST", `Run {math.floor((Config.Crates.SpeedBoostMultiplier - 1) * 100 + 0.5)}% faster for {Format.Duration(info.Seconds or 600)}`
	elseif info.Kind == "Luck" then
		return "🍀", "LUCK EVENT", `Better donuts for the whole server for {Format.Duration(info.Seconds or 600)}`
	elseif info.Kind == "Egg" and info.Egg and Pets.EggById[info.Egg] then
		local egg = Pets.EggById[info.Egg]
		return "🥚", string.upper(egg.Name), `In your incubator - hatches in {Format.Duration(egg.HatchSeconds)}`
	elseif info.Kind == "Pet" and info.Pet and Pets.ById[info.Pet] then
		local pet = Pets.ById[info.Pet]
		return "🐾", string.upper(pet.Name), `{pet.Rarity} pet! {Pets.BonusText(pet)}`
	end
	return "🎁", "SURPRISE", ""
end

local function play(info: Info)
	local crate = Crates.ById[info.Crate] or Crates.List[1]
	overlay.Visible = true
	overlay.BackgroundTransparency = 1
	TweenService:Create(overlay, TweenInfo.new(0.3), { BackgroundTransparency = 0.35 }):Play()
	local stage = Theme.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromOffset(320, 320), BackgroundTransparency = 1, Parent = overlay })
	Theme.AutoScale(stage)
	Theme.Label({ Text = string.upper(crate.Name), TextColor3 = crate.Color:Lerp(Color3.new(1, 1, 1), 0.3), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -64), Size = UDim2.fromOffset(420, 44), StrokeThickness = 4, Parent = stage })

	-- Shake harder and harder
	local crateView = preview(stage, CrateModel.Build(crate.Id, { NoEffects = true }))
	local startedAt = os.clock()
	local shake = RunService.RenderStepped:Connect(function()
		local p = math.clamp((os.clock() - startedAt) / 1.8, 0, 1)
		crateView.Rotation = math.sin(os.clock() * (10 + p * 30)) * (3 + p * 18)
		crateView.Position = UDim2.fromOffset(math.sin(os.clock() * 45) * p * 7, 0)
	end)
	for i = 1, 3 do
		task.delay(0.5 * i, function()
			Theme.PlaySound("Crack")
		end)
	end
	task.wait(1.8)
	shake:Disconnect()

	-- Flash open
	local flash = Theme.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, ZIndex = 5, Parent = overlay })
	TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	task.delay(0.7, function()
		flash:Destroy()
	end)
	Theme.PlaySound("Hatch")
	crateView:Destroy()
	if crate.Order >= 2 then
		for i = 1, 8 do
			local ray = Theme.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(18, 440), Rotation = i * 22.5, BackgroundColor3 = crate.Color, BackgroundTransparency = 0.6, BorderSizePixel = 0, Parent = stage }, {
				Theme.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }) }),
			})
			TweenService:Create(ray, TweenInfo.new(6, Enum.EasingStyle.Linear), { Rotation = ray.Rotation + 90 }):Play()
		end
	end

	-- What you got
	local icon, title, detail = describe(info)
	local reveal: GuiObject
	if info.Kind == "Egg" and info.Egg and Pets.EggById[info.Egg] then
		reveal = preview(stage, PetModel.BuildEgg(Pets.EggById[info.Egg], { NoEffects = true }))
	elseif info.Kind == "Pet" and info.Pet and Pets.ById[info.Pet] then
		reveal = preview(stage, PetModel.BuildPet(Pets.ById[info.Pet], { NoEffects = true }))
	else
		reveal = Theme.Label({ Text = icon, Font = Enum.Font.GothamBold, Size = UDim2.fromScale(0.6, 0.6), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = stage })
	end
	local pop = Theme.new("UIScale", { Scale = 0.2, Parent = reveal })
	TweenService:Create(pop, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local titleLabel = Theme.Label({ Text = title, TextColor3 = if info.Kind == "Coins" then Theme.Colors.Money else Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(460, 46), StrokeThickness = 3.5, Parent = stage })
	Theme.Label({ Text = detail, Font = Theme.Font, TextColor3 = Color3.fromRGB(255, 240, 180), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 48), Size = UDim2.fromOffset(460, 26), StrokeThickness = 2, Parent = stage })
	if info.Kind == "Pet" then
		task.spawn(function()
			while titleLabel.Parent do
				titleLabel.TextColor3 = Color3.fromHSV((os.clock() * 0.4) % 1, 0.7, 1)
				task.wait()
			end
		end)
	end
	-- Spin 3D rewards slowly
	local camera = reveal:FindFirstChildOfClass("Camera")
	local spin = RunService.RenderStepped:Connect(function(dt: number)
		if camera then
			camera.CFrame = CFrame.Angles(0, dt * 0.8, 0) * camera.CFrame
		end
	end)
	task.wait(3)
	spin:Disconnect()
	TweenService:Create(overlay, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	stage:Destroy()
	task.wait(0.3)
	overlay.Visible = false
end

function CrateOpen.Init()
	local gui = Theme.ScreenGui("CrateOpening", 31)
	gui.IgnoreGuiInset = true
	overlay = Theme.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Visible = false, Parent = gui })
	local queue: { Info } = {}
	local playing = false
	Remotes.Event("CrateOpened").OnClientEvent:Connect(function(info: Info)
		table.insert(queue, info)
		if playing then
			return
		end
		playing = true
		while #queue > 0 do
			local nextInfo = table.remove(queue, 1)
			if nextInfo then
				play(nextInfo)
			end
		end
		playing = false
	end)
end

return CrateOpen
