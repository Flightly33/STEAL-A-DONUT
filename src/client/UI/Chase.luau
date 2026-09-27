--[[
	Chase UI: everything that happens during a steal.
	  - "RUN!" banner with live distance to the guard and to the safe zone, red screen edges
	  - "SAFE!" message and a glowing path to your base while you carry the donut home
	  - "CAUGHT!" screen (with a comedic fling) or a celebration when the donut is secured
	  - "Welcome back" popup for offline earnings
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Donuts = require(Shared.Donuts)
local Rarities = require(Shared.Rarities)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local Notifications = require(script.Parent.Notifications)
local State = require(script.Parent.Parent.State)

local Chase = {}

local player = Players.LocalPlayer :: Player

local gui: ScreenGui
local banner: Frame
local bannerTitle: TextLabel
local bannerInfo: TextLabel
local edges: { Frame } = {}
local chaseConnection: RBXScriptConnection? = nil
local beam: Beam? = nil
local beamAttachments: { Attachment } = {}

local function rootPart(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function setEdges(visible: boolean, color: Color3?)
	for _, edge in edges do
		edge.Visible = visible
		if color then
			edge.BackgroundColor3 = color
		end
	end
end

local function clearBeam()
	if beam then
		beam:Destroy()
		beam = nil
	end
	for _, attachment in beamAttachments do
		attachment:Destroy()
	end
	beamAttachments = {}
end

-- Glowing guide line from you to your base (or, in another world, to the portal home).
local function showPathHome()
	clearBeam()
	local root = rootPart()
	local index = State.Get("PlotIndex")
	local map = workspace:FindFirstChild("Map")
	local world = State.Number("World")
	local target: BasePart? = nil
	if world > 1 then
		local worlds = map and map:FindFirstChild("Worlds")
		local landing = worlds and worlds:FindFirstChild("World" .. world)
		local portal = landing and landing:FindFirstChild("HomePortal")
		target = portal and portal:FindFirstChild("Trigger") :: BasePart?
	else
		local plots = map and map:FindFirstChild("Plots")
		local plot = plots and plots:FindFirstChild("Plot" .. tostring(index))
		target = plot and plot:FindFirstChild("Spawn") :: BasePart?
	end
	if not root or not target then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 1, 0)
	a1.Parent = target
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Color = ColorSequence.new(Theme.Colors.Yellow)
	b.Width0 = 1.2
	b.Width1 = 1.2
	b.FaceCamera = true
	b.LightEmission = 1
	b.Transparency = NumberSequence.new(0.3)
	b.Parent = root
	beam = b
	beamAttachments = { a0, a1 }
end

local function stopChaseLoop()
	if chaseConnection then
		chaseConnection:Disconnect()
		chaseConnection = nil
	end
end

local function hideBanner()
	stopChaseLoop()
	banner.Visible = false
	setEdges(false)
end

local function onChaseStarted(info: { DonutId: string, AreaId: number, Guard: Model?, GuardSpeed: number?, Raid: boolean?, Mutation: string?, Size: string? })
	local donut = Donuts.ById[info.DonutId]
	local rarity = donut and Rarities.Get(donut.Rarity)
	local size = Rarities.Size(info.Size)
	banner.Visible = true
	bannerTitle.Text = if info.Raid then "🏃 RUN HOME! THEY CAN HIT YOU TO GET IT BACK!" else `🏃 RUN! {string.upper(Config.Guard.Name)} IS AFTER YOU!`
	bannerTitle.TextColor3 = Color3.fromRGB(255, 80, 80)
	setEdges(true, Color3.fromRGB(255, 0, 0))
	Theme.PlaySound("Steal")
	if donut and rarity then
		Notifications.Toast(`You grabbed {Rarities.DisplayName(donut.Name, info.Mutation, info.Size)} ({rarity.Id})!`, "rare")
		if size.CarrySpeed < 1 then
			Notifications.Toast(`🐌 It's {string.lower(size.Id)}! You're {math.floor((1 - size.CarrySpeed) * 100 + 0.5)}% slower while carrying it.`, "error")
		end
	end

	stopChaseLoop()
	if info.Raid then
		showPathHome()
	end
	local pulse = 0
	chaseConnection = RunService.RenderStepped:Connect(function(dt)
		pulse += dt
		local root = rootPart()
		if not root then
			return
		end
		local text
		if info.Raid then
			local beamTarget = beamAttachments[2]
			local home = beamTarget and beamTarget.WorldPosition
			text = if home then `🏠 Your base: {math.floor((home - root.Position).Magnitude)} studs` else "🏠 Get to your base!"
		else
			local toSafe = math.max(0, root.Position.Z - Config.Map.SafeZoneZ)
			text = `🛡 Safe zone: {math.floor(toSafe)} studs`
		end
		local guard = info.Guard
		local guardRoot = guard and guard.Parent and guard.PrimaryPart
		if guardRoot then
			local gap = (guardRoot.Position - root.Position).Magnitude
			text ..= `   •   😡 {Config.Guard.Name}: {math.floor(gap)} studs behind`
		end
		bannerInfo.Text = text
		local alpha = 0.6 + math.sin(pulse * 5) * 0.1 -- gentle pulse, same strength as the blue glow
		for _, edge in edges do
			local gradient = edge:FindFirstChildOfClass("UIGradient")
			if gradient then
				gradient.Transparency = NumberSequence.new(alpha, 1)
			end
		end
	end)
end

local function flingSelf(velocity: Vector3?)
	local character = player.Character
	local root = rootPart()
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
	root.AssemblyLinearVelocity = velocity or Vector3.new(math.random(-20, 20), 55, -35)
	root.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
	task.delay(1.2, function()
		if humanoid.Parent then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

local function bigText(text: string, color: Color3, duration: number)
	local label = Theme.Label({
		Text = text,
		TextColor3 = color,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromScale(0.8, 0.16),
		StrokeThickness = 5,
		Parent = gui,
	})
	local scale = Theme.new("UIScale", { Scale = 0.3, Parent = label })
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(duration, function()
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.wait(0.4)
		label:Destroy()
	end)
end

local function onChaseEnded(result: { Result: string, DonutId: string?, IsNew: boolean?, Reason: string?, Mutation: string?, Size: string? })
	if result.Result == "Safe" then
		stopChaseLoop()
		setEdges(true, Color3.fromRGB(0, 170, 255))
		local otherWorld = State.Number("World") > 1
		bannerTitle.Text = if otherWorld then "🛡 SAFE! Walk into the portal home!" else "🛡 SAFE! Bring the donut to your base!"
		bannerTitle.TextColor3 = Color3.fromRGB(110, 210, 255)
		bannerInfo.Text = "Follow the yellow line ⬇"
		task.delay(1.2, function()
			if bannerTitle.Text:find("SAFE") then
				setEdges(false)
			end
		end)
		showPathHome()
	elseif result.Result == "Deposited" then
		hideBanner()
		clearBeam()
		local donut = result.DonutId and Donuts.ById[result.DonutId]
		if donut then
			local rarity = Rarities.Get(donut.Rarity)
			local mutation = Rarities.Mutation(result.Mutation)
			local color = if mutation.Order > 0 then mutation.Color else rarity.Color
			bigText(if result.IsNew then "✨ NEW DONUT! ✨" else "🍩 DONUT SECURED!", color, 2)
			local income = Economy.DonutIncome(donut.Id, 1, result.Mutation, result.Size)
			Notifications.Banner(Rarities.DisplayName(donut.Name, result.Mutation, result.Size), color, 2.5, `{rarity.Id} • {Format.Money(income)}/s`)
		end
		Theme.PlaySound("Deposit")
	elseif result.Result == "Caught" then
		hideBanner()
		clearBeam()
		setEdges(true, Color3.fromRGB(255, 0, 0))
		bigText(`CAUGHT BY {string.upper(Config.Guard.Name)}!`, Color3.fromRGB(255, 70, 70), 1.8)
		Theme.PlaySound("Caught")
		flingSelf()
		task.delay(1.5, function()
			setEdges(false)
		end)
	else -- Lost
		hideBanner()
		clearBeam()
		if result.Reason then
			Notifications.Toast("Donut lost: " .. result.Reason, "error")
		end
	end
end

local function buildOfflinePopup()
	local modal = Modal.new("🌙 WELCOME BACK!", Theme.Colors.Purple, Vector2.new(520, 300))
	local text = Theme.Label({ Text = "", Font = Theme.Font, RichText = true, Size = UDim2.new(1, 0, 0, 120), StrokeThickness = 1.5, Parent = modal.Body })
	local collect = Theme.Button({ Text = "COLLECT!", Icon = "💰", Color = Theme.Colors.Green, Size = UDim2.fromOffset(240, 62), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Parent = modal.Body })
	collect.Activated:Connect(function()
		modal:Close()
		Theme.PlaySound("Collect")
	end)
	Remotes.Event("OfflineEarnings").OnClientEvent:Connect(function(amount: number, seconds: number, capped: boolean?)
		local capText = if capped then `\n<font size="18">(offline earnings are capped at {Config.Offline.MaxHours}h)</font>` else ""
		text.Text = `Your donuts kept working while you were away for <b>{Format.Duration(seconds)}</b>!\n\n<font color="#8dff6a" size="40"><b>+{Format.Money(amount)}</b></font>{capText}`
		modal:Open()
	end)
end

function Chase.Init()
	gui = Theme.ScreenGui("Chase", 5)

	-- Red/blue glow around the screen edges. Its own ScreenGui that ignores the top bar and the
	-- phone notch/safe area, so the glow reaches every edge of the screen.
	local edgeGui = Theme.ScreenGui("ChaseGlow", 3)
	edgeGui.IgnoreGuiInset = true
	edgeGui.ScreenInsets = Enum.ScreenInsets.None
	local edgeDefs = {
		{ Size = UDim2.new(1, 0, 0.18, 0), Position = UDim2.fromScale(0, 0), Rotation = 90 },
		{ Size = UDim2.new(1, 0, 0.18, 0), Position = UDim2.fromScale(0, 0.82), Rotation = -90 },
		{ Size = UDim2.new(0.12, 0, 1, 0), Position = UDim2.fromScale(0, 0), Rotation = 0 },
		{ Size = UDim2.new(0.12, 0, 1, 0), Position = UDim2.fromScale(0.88, 0), Rotation = 180 },
	}
	for _, def in edgeDefs do
		local edge = Theme.new("Frame", {
			Size = def.Size,
			Position = def.Position,
			BackgroundColor3 = Color3.fromRGB(255, 0, 0),
			BorderSizePixel = 0,
			Visible = false,
			Parent = edgeGui,
		}, {
			Theme.new("UIGradient", { Rotation = def.Rotation, Transparency = NumberSequence.new(0.5, 1) }),
		})
		table.insert(edges, edge)
	end

	banner = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 100),
		Size = UDim2.fromOffset(820, 90),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	Theme.AutoScale(banner)
	bannerTitle = Theme.Label({ Text = "", Size = UDim2.new(1, 0, 0, 54), StrokeThickness = 4, Parent = banner })
	bannerInfo = Theme.Label({ Text = "", Font = Theme.Font, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 56), StrokeThickness = 2, Parent = banner })

	Remotes.Event("ChaseStarted").OnClientEvent:Connect(onChaseStarted)
	Remotes.Event("Flung").OnClientEvent:Connect(function(velocity: Vector3)
		flingSelf(velocity)
		Theme.PlaySound("Caught")
	end)
	Remotes.Event("ChaseEnded").OnClientEvent:Connect(onChaseEnded)
	player.CharacterAdded:Connect(function()
		hideBanner()
		clearBeam()
	end)
	buildOfflinePopup()
end

return Chase
