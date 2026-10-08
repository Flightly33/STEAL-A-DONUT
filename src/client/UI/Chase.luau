--[[
	Chase UI: everything that happens during a steal.
	  - "RUN!" banner with live distance to Domer and to the lobby, red screen edges
	  - Domer's footsteps: heavy thuds that get louder as he closes in, and the camera shakes when
	    he's right behind you (Config.Guard FootstepRange / ShakeRange / MaxShake)
	  - "BOX SECURED!" when you get a box back to the lobby (it goes into your inventory)
	  - "CAUGHT!" screen (with a comedic fling): the box went back to Domer, or fell on the ground
	  - A small "Drop" button while you carry a box
	  - "Welcome back" popup for offline earnings
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Boxes = require(Shared.Boxes)
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

-- One heavy footstep from the guard (a 3D sound on him, so you hear where he is). A few sounds
-- are made once per chase and reused, instead of a new one every step.
local steps: { Sound } = {}
local stepIndex = 0
local function footstep(guardRoot: BasePart, volume: number)
	if not steps[1] or steps[1].Parent ~= guardRoot then
		for _, old in steps do
			old:Destroy()
		end
		steps = {}
		for i = 1, 3 do
			local sound = Instance.new("Sound")
			sound.Name = "Footstep" .. i
			sound.SoundId = STEP_SOUND
			sound.RollOffMinDistance = 20
			sound.RollOffMaxDistance = Config.Guard.FootstepRange * 2
			sound.Parent = guardRoot
			steps[i] = sound
		end
	end
	stepIndex = stepIndex % #steps + 1
	local sound = steps[stepIndex]
	sound.Volume = volume
	sound.PlaybackSpeed = 0.42 + math.random() * 0.08
	sound.TimePosition = 0
	sound:Play()
end

-- Grabbing a box: Config.Guard.GrabSounds, all at once (made in Chase.Init)
local grabSounds: { Sound } = {}

type ChaseInfo = { DonutId: string, AreaId: number, Kind: string?, Guard: Model?, GuardSpeed: number?, Mutation: string?, Size: string? }

local function onChaseStarted(info: ChaseInfo)
	Settings.SetChasing(true)
	local kind = info.Kind or "Box"
	local donut = Donuts.ById[info.DonutId]
	local rarity = donut and Rarities.Get(donut.Rarity)
	local size = Rarities.Size(info.Size)
	showBanner(true)
	bannerTitle.Text = `RUN! {string.upper(Config.Guard.Name)} IS AFTER YOU!`
	bannerTitle.TextColor3 = Color3.fromRGB(255, 80, 80)
	setEdges(true, Color3.fromRGB(255, 0, 0))
	if kind == "Box" and #grabSounds > 0 then
		for _, sound in grabSounds do
			sound.TimePosition = 0
			sound:Play()
		end
	else
		Theme.PlaySound("Grab")
	end
	if kind == "Shard" then
		-- (nobody chases you for a meteor shard: just get it back over the lobby line)
		bannerTitle.Text = "Bring the meteor shard back to the lobby!"
		bannerTitle.TextColor3 = Color3.fromRGB(215, 160, 255)
		setEdges(true, Color3.fromRGB(160, 80, 255))
		Notifications.Toast("You grabbed a METEOR SHARD! Don't get hit - you'll drop it!", "rare")
	elseif kind ~= "Box" or #grabSounds == 0 then
		Theme.PlaySound("Steal")
	end
	if kind == "Shard" then
		-- (the toast above)
	elseif kind == "Box" then
		-- (for a box, DonutId is the box tier)
		local tier = Boxes.Tier(info.DonutId)
		local boxSize = Boxes.Size(info.Size)
		Notifications.Toast(`You grabbed a {Rarities.DisplayName(Boxes.DisplayName(tier.Id, boxSize.Id), info.Mutation, nil)}! Get it to the lobby!`, "rare")
		if boxSize.CarrySpeed < 1 then
			Notifications.Toast(`It's a {boxSize.Name} box! You're {math.floor((1 - boxSize.CarrySpeed) * 100 + 0.5)}% slower while carrying it.`, "error")
		end
	elseif kind == "Egg" then
		local egg = Pets.EggById[info.DonutId]
		if egg then
			Notifications.Toast(`You grabbed a {egg.Name}! Bring it to your incubator!`, "rare")
		end
	elseif donut and rarity then
		Notifications.Toast(`You grabbed {Rarities.DisplayName(donut.Name, info.Mutation, info.Size)} ({rarity.Id})!`, "rare")
		if size.CarrySpeed < 1 then
			Notifications.Toast(`It's {string.lower(size.Id)}! You're {math.floor((1 - size.CarrySpeed) * 100 + 0.5)}% slower while carrying it.`, "error")
		end
	end

	stopChaseLoop()
	local pulse = 0
	local nextStep = 0
	local lastText = ""
	local nextText = 0
	local nextGlow = 0
	chaseConnection = RunService.RenderStepped:Connect(function(dt)
		pulse += dt
		local root = rootPart()
		if not root then
			return
		end
		local toSafe = math.max(0, root.Position.Z - Config.Map.SafeZoneZ)
		local text = `Lobby: {math.floor(toSafe)} studs`
		local closeness = 0
		local guard = info.Guard
		local guardRoot = guard and guard.Parent and guard.PrimaryPart
		if guardRoot then
			local offset = guardRoot.Position - root.Position
			local gap = Vector2.new(offset.X, offset.Z).Magnitude
			text ..= `   •   {Config.Guard.Name}: {math.floor(gap)} studs behind`
			-- Footsteps (faster the faster he runs) and screen shake when he's close
			local speed = Vector2.new(guardRoot.AssemblyLinearVelocity.X, guardRoot.AssemblyLinearVelocity.Z).Magnitude
			if gap < Config.Guard.FootstepRange and speed > 2 and pulse >= nextStep then
				local stride = 2.2 * Config.Guard.Scale
				nextStep = pulse + math.clamp(stride / speed, 0.17, 0.6)
				footstep(guardRoot, math.clamp(0.9 * (1 - gap / Config.Guard.FootstepRange), 0.1, 0.9))
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
		-- (only touch the label when the numbers change, at most 10 times a second: re-fitting
		-- scaled text every frame is slow on phones)
		if text ~= lastText and pulse >= nextText then
			lastText = text
			nextText = pulse + 0.1
			bannerInfo.Text = text
		end
		-- The red glow pulses faster and stronger the closer he gets (30 updates a second is plenty)
		if pulse >= nextGlow then
			nextGlow = pulse + 1 / 30
			local rate = 5 + closeness * 10
			setEdgeStrength(0.6 - closeness * 0.35 + math.sin(pulse * rate) * 0.1)
		end
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

-- A big pop-up message (it takes over the header at the top of the screen for a moment).
local function bigText(text: string, color: Color3, duration: number, subtitle: string?)
	Notifications.Banner(text, color, duration, subtitle, { Big = true })
end

type ChaseResult = { Result: string, DonutId: string?, IsNew: boolean?, Reason: string?, Mutation: string?, Size: string?, Kind: string?, EggId: string?, Tier: string?, BoxBack: boolean?, Count: number?, Cost: number? }

local function onChaseEnded(result: ChaseResult)
	Settings.SetChasing(false)
	if result.Result == "Safe" then
		stopChaseLoop()
		setEdges(true, Color3.fromRGB(0, 170, 255))
		bannerTitle.Text = if result.Kind == "Egg" then "SAFE! Bring the egg to your base!" else "SAFE! Bring the donut to your base!"
		bannerTitle.TextColor3 = Color3.fromRGB(110, 210, 255)
		bannerInfo.Text = "Follow the yellow line"
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
			bigText("EGG SECURED!", if egg then egg.Accent else Theme.Colors.Pink, 2)
			Theme.PlaySound("Deposit")
			return
		elseif result.Kind == "Shard" then
			local count, cost = result.Count or 0, result.Cost or Config.CosmicDonut.ShardCost
			bigText(`METEOR SHARD! {count}/{cost}`, Color3.fromRGB(205, 140, 255), if count >= cost then 3.5 else 2.2, if count >= cost then "You have enough shards! Craft THE COSMIC DONUT at the Cosmic Forge by the spawn" else nil)
			Theme.PlaySound("Deposit")
			return
		elseif result.Kind == "Box" then
			local tier = Boxes.Tier(result.Tier)
			local mutation = Rarities.Mutation(result.Mutation)
			local color = if mutation.Order > 0 then mutation.Color else tier.Color
			bigText("BOX SECURED!", color, 2.8, `{Rarities.DisplayName(Boxes.DisplayName(tier.Id, result.Size), result.Mutation, nil)} • in your inventory: hold it and click in your pen`)
			Theme.PlaySound("Deposit")
			return
		end
		local donut = result.DonutId and Donuts.ById[result.DonutId]
		if donut then
			local rarity = Rarities.Get(donut.Rarity)
			local mutation = Rarities.Mutation(result.Mutation)
			local color = if mutation.Order > 0 then mutation.Color else rarity.Color
			local income = Economy.DonutIncome(donut.Id, 1, result.Mutation, result.Size)
			bigText(if result.IsNew then "NEW DONUT!" else "DONUT SECURED!", color, 2.8, `{Rarities.DisplayName(donut.Name, result.Mutation, result.Size)} • {rarity.Id} • {Format.Money(income)}/s`)
		end
		Theme.PlaySound("Deposit")
	elseif result.Result == "Caught" then
		hideBanner()
		clearBeam()
		setEdges(true, Color3.fromRGB(255, 0, 0))
		bigText(`CAUGHT BY {string.upper(Config.Guard.Name)}!`, Color3.fromRGB(255, 70, 70), 1.8)
		if result.Kind == "Box" then
			Notifications.Toast(if result.BoxBack
				then `{Config.Guard.Name} took the box back. Try again!`
				else "You dropped the box! Grab it before someone else does!", "error")
		else
			Notifications.Toast("It went back where you found it. Try again!", "error")
		end
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

local function buildOfflinePopup()
	local modal = Modal.new("Welcome Back!", Theme.Colors.Purple, Vector2.new(500, 290))
	local text = Theme.Label({ Text = "", Font = Theme.Font, RichText = true, Size = UDim2.new(1, 0, 0, 120), StrokeThickness = 1.5, Parent = modal.Body })
	local collect = Theme.Button({ Text = "COLLECT!", Icon = "cash", Color = Theme.Colors.Green, Size = UDim2.fromOffset(230, 58), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Parent = modal.Body })
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
	for i, def in Config.Guard.GrabSounds do
		local sound = Instance.new("Sound")
		sound.Name = "Grab" .. i
		sound.SoundId = def.Id
		sound.Volume = def.Volume
		sound.Parent = SoundService
		table.insert(grabSounds, sound)
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(grabSounds)
		end)
	end)

	-- Small "Drop" button, only while you carry a box. Kept small and away from the other buttons (right side, under the middle) so it isn't hit by accident.
	local dropHolder = Theme.new("Frame", {
		Name = "DropCarried", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.64, 0),
		Size = UDim2.fromOffset(112, 32), BackgroundTransparency = 1, Visible = false, Parent = gui,
	})
	Theme.AutoScale(dropHolder)
	local drop = Theme.Button({ Text = "Drop box", Color = Theme.Colors.Gray, Size = UDim2.fromScale(1, 1), Parent = dropHolder })
	drop.Activated:Connect(function()
		Remotes.Event("Action"):FireServer("DropCarried")
	end)
	local function updateDrop()
		dropHolder.Visible = player:GetAttribute("CarryKind") == "Box"
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

	-- (under the header, in the column at the top of the screen: UI/Notifications)
	banner = Theme.Band({
		Name = "ChaseBanner",
		Size = UDim2.fromOffset(940, 82),
		Darkness = 0.55,
		Visible = false,
		Parent = Notifications.ChaseSlot(),
	})
	bannerTitle = Theme.Label({ Name = "Title", Text = "", Size = UDim2.new(1, -160, 0, 46), Position = UDim2.fromOffset(80, 4), StrokeThickness = 4, Parent = banner })
	bannerInfo = Theme.Label({ Name = "Info", Text = "", Font = Theme.Font, Size = UDim2.new(1, -160, 0, 26), Position = UDim2.fromOffset(80, 52), StrokeThickness = 2.5, Parent = banner })

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
