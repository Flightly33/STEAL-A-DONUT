--[[
	Chase UI: everything that happens during a steal.
	  - "RUN!" banner with live distance to the guard and to the safe zone, red screen edges
	  - Domer's footsteps: heavy thuds that get louder as he closes in, and the camera shakes when
	    he's right behind you (Config.Guard FootstepRange / ShakeRange / MaxShake)
	  - "SAFE!" message and a glowing path to your base while you carry the donut home
	  - "CAUGHT!" screen (with a comedic fling) or a celebration when the donut is secured
	  - Base alarm: a siren, red edges and a red outline on the thief when someone steals from you
	  - "Welcome back" popup for offline earnings
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Donuts = require(Shared.Donuts)
local Rarities = require(Shared.Rarities)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Pets = require(Shared.Pets)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local Notifications = require(script.Parent.Notifications)
local Bases = require(script.Parent.Parent.Bases)

local Settings = require(script.Parent.Settings)

local Chase = {}

local player = Players.LocalPlayer :: Player

local STEP_SOUND = "rbxasset://sounds/action_jump_land.mp3"
local SIREN_SOUND = "rbxasset://sounds/electronicpingshort.wav"

local gui: ScreenGui
local banner: Frame
local bannerTitle: TextLabel
local bannerInfo: TextLabel
local edges: { Frame } = {}
local chaseConnection: RBXScriptConnection? = nil
local beam: Beam? = nil
local beamAttachments: { Attachment } = {}
local alarmConnection: RBXScriptConnection? = nil
local thiefHighlight: Highlight? = nil

local function rootPart(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function setEdges(visible: boolean, color: Color3?)
	for _, edge in edges do
		edge.Visible = visible
		if color then
			edge.BackgroundColor3 = color
		end
	end
end

local function setEdgeStrength(alpha: number)
	for _, edge in edges do
		local gradient = edge:FindFirstChildOfClass("UIGradient")
		if gradient then
			gradient.Transparency = NumberSequence.new(alpha, 1)
		end
	end
end

local function showBanner(visible: boolean)
	banner.Visible = visible
	Notifications.SetToastOffset(if visible then 84 else 0)
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

-- Glowing guide line from you to your base (it's in the world you're in).
local function showPathHome()
	clearBeam()
	local root = rootPart()
	local plot = Bases.Mine()
	local target = plot and plot:FindFirstChild("Spawn")
	if not root or not target or not target:IsA("BasePart") then
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

local function resetShake()
	local h = humanoid()
	if h then
		h.CameraOffset = Vector3.zero
	end
end

local function stopChaseLoop()
	if chaseConnection then
		chaseConnection:Disconnect()
		chaseConnection = nil
	end
	resetShake()
end

local function hideBanner()
	stopChaseLoop()
	showBanner(false)
	setEdges(false)
end

-- One heavy footstep from the guard (a 3D sound on him, so you hear where he is).
local function footstep(guardRoot: BasePart, volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = STEP_SOUND
	sound.Volume = volume
	sound.PlaybackSpeed = 0.42 + math.random() * 0.08
	sound.RollOffMinDistance = 20
	sound.RollOffMaxDistance = Config.Guard.FootstepRange * 2
	sound.Parent = guardRoot
	sound:Play()
	task.delay(2, function()
		sound:Destroy()
	end)
end

type ChaseInfo = { DonutId: string, AreaId: number, Kind: string?, Guard: Model?, GuardSpeed: number?, Raid: boolean?, Mutation: string?, Size: string?, Victim: Player? }

local function onChaseStarted(info: ChaseInfo)
	Settings.SetChasing(true)
	local kind = info.Kind or (if info.Raid then "Raid" else "Lane")
	local donut = Donuts.ById[info.DonutId]
	local rarity = donut and Rarities.Get(donut.Rarity)
	local size = Rarities.Size(info.Size)
	showBanner(true)
	if kind == "Raid" then
		local owner = if info.Victim then info.Victim.DisplayName else "the owner"
		bannerTitle.Text = `🐌 SLOW MODE! GET HOME BEFORE {string.upper(owner)} HITS YOU!`
	else
		bannerTitle.Text = `🏃 RUN! {string.upper(Config.Guard.Name)} IS AFTER YOU!`
	end
	bannerTitle.TextColor3 = Color3.fromRGB(255, 80, 80)
	setEdges(true, Color3.fromRGB(255, 0, 0))
	Theme.PlaySound("Grab")
	Theme.PlaySound("Steal")
	if kind == "Egg" then
		local egg = Pets.EggById[info.DonutId]
		if egg then
			Notifications.Toast(`You grabbed a {egg.Name}! Bring it to your incubator!`, "rare")
		end
	elseif donut and rarity then
		Notifications.Toast(`You grabbed {Rarities.DisplayName(donut.Name, info.Mutation, info.Size)} ({rarity.Id})!`, "rare")
		if size.CarrySpeed < 1 then
			Notifications.Toast(`🐌 It's {string.lower(size.Id)}! You're {math.floor((1 - size.CarrySpeed) * 100 + 0.5)}% slower while carrying it.`, "error")
		end
	end

	stopChaseLoop()
	if kind == "Raid" then
		showPathHome()
	end
	local pulse = 0
	local nextStep = 0
	chaseConnection = RunService.RenderStepped:Connect(function(dt)
		pulse += dt
		local root = rootPart()
		if not root then
			return
		end
		local text
		if kind == "Raid" then
			local beamTarget = beamAttachments[2]
			local home = beamTarget and beamTarget.WorldPosition
			text = if home then `🏠 Your base: {math.floor((home - root.Position).Magnitude)} studs` else "🏠 Get to your base!"
		else
			local toSafe = math.max(0, root.Position.Z - Config.Map.SafeZoneZ)
			text = `🛡 Safe zone: {math.floor(toSafe)} studs`
		end
		local closeness = 0
		local guard = info.Guard
		local guardRoot = guard and guard.Parent and guard.PrimaryPart
		if guardRoot then
			local offset = guardRoot.Position - root.Position
			local gap = Vector2.new(offset.X, offset.Z).Magnitude
			text ..= `   •   😡 {Config.Guard.Name}: {math.floor(gap)} studs behind`
			-- Footsteps (faster the faster he runs) and screen shake when he's close
			local speed = Vector2.new(guardRoot.AssemblyLinearVelocity.X, guardRoot.AssemblyLinearVelocity.Z).Magnitude
			if gap < Config.Guard.FootstepRange and speed > 2 and pulse >= nextStep then
				local stride = 2.2 * Config.Guard.Scale
				nextStep = pulse + math.clamp(stride / speed, 0.17, 0.6)
				footstep(guardRoot, math.clamp(1.4 * (1 - gap / Config.Guard.FootstepRange), 0.15, 1.4))
			end
			closeness = math.clamp(1 - gap / Config.Guard.ShakeRange, 0, 1)
		end
		local h = humanoid()
		if h then
			if closeness > 0 then
				local strength = Config.Guard.MaxShake * closeness ^ 1.4
				h.CameraOffset = Vector3.new(math.noise(pulse * 18, 0.3) * strength, math.noise(pulse * 18, 7.1) * strength, 0)
			elseif h.CameraOffset ~= Vector3.zero then
				h.CameraOffset = Vector3.zero
			end
		end
		bannerInfo.Text = text
		-- The red glow pulses faster and stronger the closer he gets
		local rate = 5 + closeness * 10
		setEdgeStrength(0.6 - closeness * 0.35 + math.sin(pulse * rate) * 0.1)
	end)
end

local function flingSelf(velocity: Vector3?)
	local character = player.Character
	local root = rootPart()
	local h = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not h then
		return
	end
	h:ChangeState(Enum.HumanoidStateType.FallingDown)
	-- Caught: launched high and far back towards the hub, spinning (like getting bonked in Steal an Egg)
	root.AssemblyLinearVelocity = velocity or Vector3.new(math.random(-25, 25), 95, -130)
	root.AssemblyAngularVelocity = Vector3.new(math.random(-12, 12), math.random(-12, 12), math.random(-12, 12))
	Theme.PlaySound("Fling")
	task.delay(if velocity then 1.2 else 1.9, function()
		if h.Parent then
			h:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

local function bigText(text: string, color: Color3, duration: number)
	local label = Theme.Label({
		Text = text,
		TextColor3 = color,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromScale(0.7, 0.12),
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

type ChaseResult = { Result: string, DonutId: string?, IsNew: boolean?, Reason: string?, Mutation: string?, Size: string?, Kind: string?, EggId: string? }

local function onChaseEnded(result: ChaseResult)
	Settings.SetChasing(false)
	if result.Result == "Safe" then
		stopChaseLoop()
		setEdges(true, Color3.fromRGB(0, 170, 255))
		bannerTitle.Text = if result.Kind == "Egg" then "🛡 SAFE! Bring the egg to your base!" else "🛡 SAFE! Bring the donut to your base!"
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
		if result.Kind == "Egg" then
			local egg = result.EggId and Pets.EggById[result.EggId]
			bigText("🥚 EGG SECURED!", if egg then egg.Accent else Theme.Colors.Pink, 2)
			Theme.PlaySound("Deposit")
			return
		end
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
		Notifications.Toast("It went back where you found it. Try again!", "error")
		Theme.PlaySound("Caught")
		flingSelf()
		task.delay(1.5, function()
			setEdges(false)
		end)
	else -- Lost
		hideBanner()
		clearBeam()
		if result.Reason then
			Notifications.Toast(result.Reason, "error")
		end
	end
end

--------------------------------------------------------------------------------
-- Base alarm (someone is stealing from you)
--------------------------------------------------------------------------------
local function siren(seconds: number)
	local custom = Config.Raid.AlarmSoundId
	if custom ~= "" then
		local sound = Instance.new("Sound")
		sound.SoundId = custom
		sound.Volume = 0.6
		SoundService:PlayLocalSound(sound)
		task.delay(seconds + 3, function()
			sound:Destroy()
		end)
		return
	end
	-- A two-tone siren made of Roblox's built-in ping
	task.spawn(function()
		local steps = math.floor(seconds / 0.3)
		for i = 1, steps do
			local sound = Instance.new("Sound")
			sound.SoundId = SIREN_SOUND
			sound.Volume = 0.45
			sound.PlaybackSpeed = if i % 2 == 0 then 1.7 else 1.25
			SoundService:PlayLocalSound(sound)
			task.delay(1, function()
				sound:Destroy()
			end)
			task.wait(0.3)
		end
	end)
end

local function stopAlarm()
	if alarmConnection then
		alarmConnection:Disconnect()
		alarmConnection = nil
	end
	if thiefHighlight then
		thiefHighlight:Destroy()
		thiefHighlight = nil
	end
	if not chaseConnection and bannerTitle.Text:find("STOLE") then
		showBanner(false)
		setEdges(false)
	end
end

type AlarmInfo = { Stage: string, Thief: Player?, Name: string? }

local function onAlarm(info: AlarmInfo)
	local thief = info.Thief
	local thiefName = if thief then thief.DisplayName else "Someone"
	if info.Stage == "Started" then
		siren(1.2)
		setEdges(true, Color3.fromRGB(255, 40, 40))
		setEdgeStrength(0.45)
		task.delay(1.5, function()
			if not chaseConnection and not alarmConnection then
				setEdges(false)
			end
		end)
	elseif info.Stage == "Stolen" then
		siren(2.4)
		bigText(`🚨 {string.upper(thiefName)} STOLE YOUR DONUT! 🚨`, Color3.fromRGB(255, 60, 60), 2.5)
		if chaseConnection then
			return -- you're busy running yourself: the toast is enough
		end
		stopAlarm()
		showBanner(true)
		bannerTitle.Text = `🚨 {string.upper(thiefName)} STOLE YOUR {string.upper(info.Name or "DONUT")}!`
		bannerTitle.TextColor3 = Color3.fromRGB(255, 80, 80)
		setEdges(true, Color3.fromRGB(255, 0, 0))
		local character = thief and thief.Character
		if character then
			local highlight = Instance.new("Highlight")
			highlight.FillColor = Color3.fromRGB(255, 40, 40)
			highlight.FillTransparency = 0.6
			highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
			highlight.Adornee = character
			highlight.Parent = gui
			thiefHighlight = highlight
		end
		local pulse = 0
		alarmConnection = RunService.RenderStepped:Connect(function(dt)
			pulse += dt
			local root = rootPart()
			local thiefRoot = thief and thief.Character and thief.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not thief or not thief.Parent or thief:GetAttribute("CarryKind") ~= "Raid" then
				stopAlarm()
				return
			end
			if root and thiefRoot then
				bannerInfo.Text = `⚔️ Hit them with your Slap Hand! They're {math.floor((thiefRoot.Position - root.Position).Magnitude)} studs away`
			end
			setEdgeStrength(0.5 + math.sin(pulse * 8) * 0.15)
		end)
	elseif info.Stage == "Recovered" then
		stopAlarm()
		bigText("🛡 YOU GOT IT BACK!", Color3.fromRGB(120, 255, 120), 2)
		Theme.PlaySound("Deposit")
	elseif info.Stage == "Lost" then
		stopAlarm()
		bigText(`😱 {string.upper(thiefName)} GOT AWAY...`, Color3.fromRGB(255, 150, 150), 2)
	end
end

local function buildOfflinePopup()
	local modal = Modal.new("🌙 WELCOME BACK!", Theme.Colors.Purple, Vector2.new(500, 290))
	local text = Theme.Label({ Text = "", Font = Theme.Font, RichText = true, Size = UDim2.new(1, 0, 0, 120), StrokeThickness = 1.5, Parent = modal.Body })
	local collect = Theme.Button({ Text = "COLLECT!", Icon = "💰", Color = Theme.Colors.Green, Size = UDim2.fromOffset(230, 58), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Parent = modal.Body })
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

	-- Small "Drop donut" button, only while you carry a donut stolen from someone's base. Kept small
	-- and away from the other buttons (right side, under the middle) so it isn't hit by accident.
	local dropHolder = Theme.new("Frame", {
		Name = "DropDonut", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.64, 0),
		Size = UDim2.fromOffset(112, 32), BackgroundTransparency = 1, Visible = false, Parent = gui,
	})
	Theme.AutoScale(dropHolder)
	local drop = Theme.Button({ Text = "✋ Drop donut", Color = Theme.Colors.Gray, Size = UDim2.fromScale(1, 1), Parent = dropHolder })
	drop.Activated:Connect(function()
		Remotes.Event("Action"):FireServer("DropCarried")
	end)
	local function updateDrop()
		dropHolder.Visible = player:GetAttribute("CarryKind") == "Raid"
	end
	player:GetAttributeChangedSignal("CarryKind"):Connect(updateDrop)
	updateDrop()

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
		Position = UDim2.new(0.5, 0, 0, 186),
		Size = UDim2.fromOffset(780, 78),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	Theme.AutoScale(banner)
	bannerTitle = Theme.Label({ Text = "", Size = UDim2.new(1, 0, 0, 46), StrokeThickness = 4, Parent = banner })
	bannerInfo = Theme.Label({ Text = "", Font = Theme.Font, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 49), StrokeThickness = 2, Parent = banner })

	Remotes.Event("ChaseStarted").OnClientEvent:Connect(onChaseStarted)
	Remotes.Event("Flung").OnClientEvent:Connect(function(velocity: Vector3)
		flingSelf(velocity)
		Theme.PlaySound("Caught")
	end)
	Remotes.Event("ChaseEnded").OnClientEvent:Connect(onChaseEnded)
	Remotes.Event("Alarm").OnClientEvent:Connect(onAlarm)
	player.CharacterAdded:Connect(function()
		hideBanner()
		clearBeam()
	end)
	buildOfflinePopup()
end

return Chase
