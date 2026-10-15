--[[
	Treadmill (client): step onto your own treadmill and you're locked onto the belt, running in
	place automatically. Press Space / Jump (or the "Get off" button) to step off.
	While running: a "+speed" popup every second, the camera zooms out a little (FOV kick), speed
	lines streak across the screen, a trail in your treadmill's colour follows you, and every time
	you gain a whole point of WalkSpeed (every Config.Speed.SpeedPerWalk Speed) a "+1 WALK SPEED!"
	burst pops up.
	Every treadmill's moving parts and effects are animated here too (harder while someone runs on
	it): LED strips, fans, turbines and planets spinning, wings flapping, a junk console rattling,
	lightning crackling and striking, power-up bursts and rings of light going off on a beat, and
	broken bulbs flickering.

	The server decides how much speed you actually get (TreadmillService); this only handles the
	feel.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimeFX = require(Shared.AnimeFX)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)

local Theme = require(script.Parent.UI.Theme)
local State = require(script.Parent.State)
local Bases = require(script.Parent.Bases)

local Treadmill = {}

local player = Players.LocalPlayer :: Player

local BELT_HALF_WIDTH = 3.3
local BELT_HALF_LENGTH = 6.8
local R6_RUN = "rbxassetid://180426354"
local R15_RUN = "rbxassetid://913376220"

local running = false
local pinned: CFrame? = nil
local track: AnimationTrack? = nil
local cooldownUntil = 0
local hint: Frame
local popupLayer: Frame
local rateLabel: TextLabel
local speedLines: Frame
local trail: Trail? = nil
local trailAttachments: { Attachment } = {}
local baseFov = 70
local lastWalkPoint = 0

local function getCharacter(): (Model?, BasePart?, Humanoid?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return character, root, humanoid
end

local function getBelt(): BasePart?
	local plot = Bases.Mine()
	local treadmill = plot and plot:FindFirstChild("Treadmill")
	local belt = treadmill and treadmill:FindFirstChild("Belt")
	return if belt and belt:IsA("BasePart") then belt else nil
end

local function currentRate(): number
	local level = math.max(1, State.Number("TreadmillLevel"))
	return Economy.TreadmillRate(level, State.Number("SpeedMultLevel"), math.max(1, State.Number("SpeedPassMultiplier")), State.Number("IndexBonus"), State.Number("PetSpeedBonus"))
end

local function tierColor(): Color3
	return Economy.TreadmillTier(math.max(1, State.Number("TreadmillLevel"))).Accent
end

-- Trail + FOV kick + speed lines while running
local function setRunFX(on: boolean, root: BasePart?)
	local camera = workspace.CurrentCamera
	if camera then
		if on then
			baseFov = camera.FieldOfView
		end
		TweenService:Create(camera, TweenInfo.new(0.5, Enum.EasingStyle.Sine), { FieldOfView = if on then baseFov + 10 else baseFov }):Play()
	end
	speedLines.Visible = on
	if trail then
		trail:Destroy()
		trail = nil
	end
	for _, attachment in trailAttachments do
		attachment:Destroy()
	end
	trailAttachments = {}
	if on and root then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 1, 0)
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -1.5, 0)
		a1.Parent = root
		local t = Instance.new("Trail")
		t.Attachment0 = a0
		t.Attachment1 = a1
		t.Color = ColorSequence.new(tierColor(), Color3.new(1, 1, 1))
		t.LightEmission = 0.8
		t.Lifetime = 0.35
		t.Transparency = NumberSequence.new(0.3, 1)
		t.FaceCamera = true
		t.Parent = root
		trail = t
		trailAttachments = { a0, a1 }
	end
end

-- Streaks flying across the screen while you run
local function buildSpeedLines(parent: Instance)
	speedLines = Theme.new("Frame", { Name = "SpeedLines", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = parent })
	local lines = {}
	for i = 1, 14 do
		local line = Theme.new("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.75,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(math.random(80, 220), 3),
			Position = UDim2.fromScale(math.random(), (i - 0.5) / 14),
			Parent = speedLines,
		})
		table.insert(lines, { Frame = line, Speed = math.random(9, 16) / 10, Y = (i - 0.5) / 14 })
	end
	RunService.RenderStepped:Connect(function(dt: number)
		if not speedLines.Visible then
			return
		end
		for _, line in lines do
			local x = line.Frame.Position.X.Scale - dt * line.Speed
			if x < -0.15 then
				x = 1.15
				line.Frame.BackgroundColor3 = tierColor():Lerp(Color3.new(1, 1, 1), 0.5)
			end
			-- keep the middle of the screen clear
			local edge = math.abs(line.Y - 0.5) > 0.22
			line.Frame.BackgroundTransparency = if edge then 0.7 else 1
			line.Frame.Position = UDim2.fromScale(x, line.Y)
		end
	end)
end

-- "+1 WALK SPEED!" every time the Speed stat crosses a whole WalkSpeed point
local function walkSpeedBurst(points: number)
	local label = Theme.Label({
		Text = `+{points} WALK SPEED!`,
		TextColor3 = Color3.fromRGB(120, 255, 140),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(360, 56),
		StrokeThickness = 3.5,
		Parent = popupLayer,
	})
	local scale = Theme.new("UIScale", { Scale = 0.2, Parent = label })
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = Theme.CurrentScale() * 1.1 }):Play()
	TweenService:Create(label, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.22) }):Play()
	task.delay(0.9, function()
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.wait(0.45)
		label:Destroy()
	end)
end

-- LED strips chase along every treadmill, its spinning parts turn (a fan, turbines, planets, halos -
-- all faster while someone runs on it), and the electric arcs flicker
-- How long `treadmill`'s owner has been running on it (nil: nobody's on it)
local runStart: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local function runningFor(treadmill: Instance?, t: number): number?
	if treadmill and treadmill:GetAttribute("Running") == true then
		local since = runStart[treadmill]
		if not since then
			since = t
			runStart[treadmill] = t
		end
		return t - since
	end
	if treadmill then
		runStart[treadmill] = nil
	end
	return nil
end

local function treadmillOf(instance: Instance): Instance?
	return instance:FindFirstAncestor("Treadmill")
end

local function startTreadmillAnimations()
	type LED = { Part: BasePart, Index: number, Model: Instance? }
	type Spinner = {
		Model: Model,
		Base: CFrame,
		Axis: string,
		Idle: number,
		Run: number,
		Mode: string,
		Amp: number,
		Dir: number,
		Angle: number,
		Shown: number,
		Seed: number,
	}
	type Flicker = { Part: BasePart?, Light: Light?, Base: number }
	type Arc = { Holder: BasePart, Points: { Attachment }, Homes: { Vector3 }, Beams: { Beam }, Strike: boolean, Every: number, Length: number, Side: Vector3, Up: Vector3, Clock: number }
	type Burst = { Holder: BasePart, Emitters: { ParticleEmitter }, Every: number?, EveryIdle: number?, Phase: number, Mode: string, Count: number }
	local leds: { [Instance]: LED } = {}
	local spinners: { [Instance]: Spinner } = {}
	local flickers: { [Instance]: Flicker } = {}
	local arcs: { [Instance]: Arc } = {}
	local bursts: { [Instance]: Burst } = {}
	local function addLED(instance: Instance)
		if instance:IsA("BasePart") then
			leds[instance] = { Part = instance, Index = (instance:GetAttribute("LEDIndex") :: number?) or 0, Model = treadmillOf(instance) }
		end
	end
	local function number(instance: Instance, name: string, default: number): number
		local value = instance:GetAttribute(name)
		return if type(value) == "number" then value else default
	end
	local function addSpinner(instance: Instance)
		if instance:IsA("Model") and instance.PrimaryPart then
			local axis = instance:GetAttribute("Axis")
			local mode = instance:GetAttribute("Mode")
			spinners[instance] = {
				Model = instance,
				Base = instance:GetPivot(),
				Axis = if type(axis) == "string" then axis else "Y",
				Idle = number(instance, "Idle", 0.5),
				Run = number(instance, "Run", 2),
				Mode = if type(mode) == "string" then mode else "Spin",
				Amp = math.rad(number(instance, "Amp", 10)),
				Dir = number(instance, "Dir", 1),
				Angle = 0,
				Shown = 0,
				Seed = math.random() * 100,
			}
		end
	end
	local function addFlicker(instance: Instance)
		if instance:IsA("BasePart") then
			flickers[instance] = { Part = instance, Base = instance.Transparency }
		elseif instance:IsA("Light") then
			flickers[instance] = { Light = instance, Base = instance.Brightness }
		end
	end
	local function addArc(instance: Instance)
		if not instance:IsA("BasePart") then
			return
		end
		local points: { Attachment } = {}
		local homes: { Vector3 } = {}
		for i = 0, 31 do
			local point = instance:FindFirstChild("P" .. i)
			if not (point and point:IsA("Attachment")) then
				break
			end
			local home = point:GetAttribute("Home")
			table.insert(points, point)
			table.insert(homes, if typeof(home) == "Vector3" then home else point.Position)
		end
		if #points < 2 then
			return
		end
		local beams: { Beam } = {}
		for _, child in instance:GetChildren() do
			if child:IsA("Beam") then
				table.insert(beams, child)
			end
		end
		local along = homes[#homes] - homes[1]
		local dir = if along.Magnitude > 0.01 then along.Unit else Vector3.yAxis
		local side = dir:Cross(if math.abs(dir.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis).Unit
		arcs[instance] = {
			Holder = instance,
			Points = points,
			Homes = homes,
			Beams = beams,
			Strike = instance:GetAttribute("Style") == "Strike",
			Every = math.max(number(instance, "Every", 2), 0.3),
			Length = number(instance, "Length", along.Magnitude),
			Side = side,
			Up = dir:Cross(side).Unit,
			Clock = 0,
		}
	end
	local function addBurst(instance: Instance)
		if not instance:IsA("BasePart") then
			return
		end
		local every, everyIdle = instance:GetAttribute("Every"), instance:GetAttribute("EveryIdle")
		bursts[instance] = {
			Holder = instance,
			Emitters = AnimeFX.Find(instance),
			Every = if type(every) == "number" and every > 0 then every else nil,
			EveryIdle = if type(everyIdle) == "number" and everyIdle > 0 then everyIdle else nil,
			Phase = number(instance, "Phase", 0),
			Mode = "",
			Count = 0,
		}
	end
	-- (the bigger ones wait a moment for their parts to replicate)
	local function later(add: (Instance) -> ()): (Instance) -> ()
		return function(instance: Instance)
			task.delay(0.2, function()
				if instance.Parent then
					add(instance)
				end
			end)
		end
	end
	local tracked: { [string]: { add: (Instance) -> (), list: { [Instance]: any }, wait: boolean } } = {
		TreadmillLED = { add = addLED, list = leds, wait = false },
		TreadmillSpin = { add = addSpinner, list = spinners, wait = true },
		TreadmillFlicker = { add = addFlicker, list = flickers, wait = false },
		TreadmillArc = { add = addArc, list = arcs, wait = true },
		TreadmillBurst = { add = addBurst, list = bursts, wait = true },
	}
	for tag, info in tracked do
		for _, instance in CollectionService:GetTagged(tag) do
			info.add(instance)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(if info.wait then later(info.add) else info.add)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
			info.list[instance] = nil
		end)
	end

	local function turn(axis: string, a: number): CFrame
		return if axis == "X" then CFrame.Angles(a, 0, 0) elseif axis == "Z" then CFrame.Angles(0, 0, a) else CFrame.Angles(0, a, 0)
	end
	local flickerClock = 0
	RunService.RenderStepped:Connect(function(dt: number)
		local t = os.clock()
		local camera = workspace.CurrentCamera
		local cam = if camera then camera.CFrame.Position else Vector3.zero
		for instance, led in leds do
			if not instance.Parent then
				leds[instance] = nil
				continue
			end
			if (led.Part.Position - cam).Magnitude < 120 then
				local running = led.Model ~= nil and led.Model:GetAttribute("Running") == true
				local speed = if running then 14 else 3
				local wave = math.sin(t * speed - led.Index * 0.8)
				led.Part.Transparency = if running then 0.5 - wave * 0.5 else 0.35 - wave * 0.3
			end
		end
		-- spinning (fans, turbines, planets, halos), swinging (wings) and rattling (a junk console)
		for instance, spinner in spinners do
			local treadmill = instance.Parent
			if not treadmill then
				spinners[instance] = nil
				continue
			end
			if (spinner.Base.Position - cam).Magnitude >= 120 then
				continue
			end
			local running = treadmill:GetAttribute("Running") == true
			local speed = if running then spinner.Run else spinner.Idle
			spinner.Angle += dt * speed
			local a = spinner.Angle
			if spinner.Mode == "Swing" then
				a = math.sin(spinner.Angle) * spinner.Amp * spinner.Dir
			elseif spinner.Mode == "Wobble" then
				a = if speed > 0 then math.clamp(math.noise(spinner.Angle, spinner.Seed) * 2.2, -1, 1) * spinner.Amp else 0
			end
			if a ~= spinner.Shown then
				spinner.Shown = a
				spinner.Model:PivotTo(spinner.Base * turn(spinner.Axis, a))
			end
		end
		-- lightning: the middle of each bolt jolts about; a strike flashes on as the beat comes round
		for instance, arc in arcs do
			if not instance.Parent then
				arcs[instance] = nil
				continue
			end
			if (arc.Holder.Position - cam).Magnitude >= 150 then
				continue
			end
			local runFor = runningFor(treadmillOf(instance), t)
			local on = if arc.Strike then runFor ~= nil and runFor % arc.Every < 0.24 else true
			arc.Clock += dt
			local wait = if runFor then 0.045 else 0.09
			if not on then
				if arc.Beams[1] and arc.Beams[1].Enabled then
					for _, b in arc.Beams do
						b.Enabled = false
					end
				end
			elseif arc.Clock >= wait then
				arc.Clock = 0
				local n = #arc.Points
				local reach = arc.Length * (if arc.Strike then 0.11 else 0.08)
				for i = 2, n - 1 do
					local middle = math.sin(math.pi * (i - 1) / (n - 1))
					local jolt = arc.Side * (math.random() * 2 - 1) + arc.Up * (math.random() * 2 - 1)
					arc.Points[i].Position = arc.Homes[i] + jolt * reach * middle
				end
				-- (now and then it cuts out for a moment)
				local shown = arc.Strike or math.random() > 0.12
				for _, b in arc.Beams do
					b.Enabled = shown
				end
			end
		end
		-- bursts: power-ups, impact frames, rings of light, on a beat (everyone sees them at once:
		-- from when the owner stepped on while they run, from the clock while it stands)
		for instance, burst in bursts do
			if not instance.Parent then
				bursts[instance] = nil
				continue
			end
			local runFor = runningFor(treadmillOf(instance), t)
			local mode, n = "off", 0
			if runFor and burst.Every then
				mode, n = "run", math.floor((runFor - burst.Phase) / burst.Every)
			elseif not runFor and burst.EveryIdle then
				mode, n = "idle", math.floor((t - burst.Phase) / burst.EveryIdle)
			end
			if mode ~= burst.Mode then
				-- (stepping on sets the first one off straight away)
				burst.Mode = mode
				burst.Count = if mode == "run" then -1 else n
			end
			if mode ~= "off" and n > burst.Count then
				burst.Count = n
				if (burst.Holder.Position - cam).Magnitude < 150 then
					if #burst.Emitters == 0 then
						burst.Emitters = AnimeFX.Find(instance)
					end
					AnimeFX.Fire(burst.Emitters)
				end
			end
		end
		-- a broken bulb, a glitching part: on and off a few times a second
		flickerClock += dt
		if flickerClock >= 0.07 then
			flickerClock = 0
			for instance, flicker in flickers do
				if not instance.Parent then
					flickers[instance] = nil
					continue
				end
				local part, light = flicker.Part, flicker.Light
				if part then
					if (part.Position - cam).Magnitude < 120 then
						part.Transparency = if math.random() < 0.3 then flicker.Base + (1 - flicker.Base) * 0.85 else flicker.Base
					end
				elseif light then
					local treadmill = treadmillOf(instance)
					local running = treadmill ~= nil and treadmill:GetAttribute("Running") == true
					local full = number(light, if running then "RunBrightness" else "IdleBrightness", flicker.Base)
					local roll = math.random()
					light.Brightness = full * (if roll < 0.2 then 0.05 elseif roll < 0.35 then 0.4 else 0.8 + math.random() * 0.2)
				end
			end
		end
	end)
end

-- Disable / enable walking input (so holding W doesn't fight the treadmill).
-- The controls object is looked up once in the background so this never yields.
local controls: any = nil
local function setControls(enabled: boolean)
	if not controls then
		return
	end
	pcall(function()
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end)
end

local function runAnimationId(character: Model, humanoid: Humanoid): string
	local animate = character:FindFirstChild("Animate")
	local runFolder = animate and animate:FindFirstChild("run")
	local anim = runFolder and runFolder:FindFirstChildOfClass("Animation")
	if anim and anim.AnimationId ~= "" then
		return anim.AnimationId
	end
	return if humanoid.RigType == Enum.HumanoidRigType.R15 then R15_RUN else R6_RUN
end

local function start(belt: BasePart, character: Model, root: BasePart, humanoid: Humanoid)
	running = true
	-- Stand in the middle of the belt, facing the console.
	local hip = if humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight + root.Size.Y / 2 else 3
	local top = belt.Position.Y + belt.Size.Y / 2 + hip
	local center = Vector3.new(belt.Position.X, top, belt.Position.Z)
	pinned = CFrame.lookAt(center, center + belt.CFrame.LookVector * Vector3.new(1, 0, 1))
	humanoid.AutoRotate = false
	setControls(false)

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local animation = Instance.new("Animation")
		animation.AnimationId = runAnimationId(character, humanoid)
		local ok, loaded = pcall(animator.LoadAnimation, animator, animation)
		if ok and loaded then
			loaded.Priority = Enum.AnimationPriority.Action
			loaded.Looped = true
			loaded:Play(0.2)
			loaded:AdjustSpeed(1.4)
			track = loaded
		end
	end
	rateLabel.Text = `RUNNING!  +{Format.Rate(currentRate())} /s`
	hint.Visible = true
	lastWalkPoint = math.floor(Economy.WalkSpeedFromStat(State.Number("Speed")))
	setRunFX(true, root)
end

local function stop(stepOff: boolean)
	if not running then
		return
	end
	-- Everything here is instant (no yields) so the belt can't re-grab you mid-step.
	running = false
	cooldownUntil = os.clock() + 1
	local _, root, humanoid = getCharacter()
	if stepOff and root and pinned then
		-- Hop off the back so you don't instantly step back on.
		root.CFrame = pinned * CFrame.new(0, 0, BELT_HALF_LENGTH + 3)
	end
	pinned = nil
	hint.Visible = false
	if humanoid then
		humanoid.AutoRotate = true
	end
	if track then
		track:Stop(0.2)
		track = nil
	end
	setControls(true)
	setRunFX(false, nil)
end

local function isOnBelt(belt: BasePart, position: Vector3): boolean
	local localPos = belt.CFrame:PointToObjectSpace(position)
	return math.abs(localPos.X) < BELT_HALF_WIDTH and math.abs(localPos.Z) < BELT_HALF_LENGTH and localPos.Y > 0 and localPos.Y < 8
end

local function popup()
	local amount = currentRate()
	local label = Theme.Label({
		Text = "+" .. Format.Rate(amount),
		TextColor3 = Color3.fromRGB(200, 150, 255),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(math.random(10, 90) / 100, math.random(18, 78) / 100),
		Size = UDim2.fromOffset(190, 54),
		Rotation = math.random(-12, 12),
		StrokeThickness = 3,
		Parent = popupLayer,
	})
	local scale = Theme.new("UIScale", { Scale = 0.2, Parent = label })
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = Theme.CurrentScale() }):Play()
	TweenService:Create(label, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = label.Position - UDim2.fromOffset(0, 60) }):Play()
	task.delay(0.6, function()
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
		task.wait(0.45)
		label:Destroy()
	end)
end

function Treadmill.IsRunning(): boolean
	return running
end

-- Lets go of you (no hop off the back): for a cutscene that moves you somewhere else
function Treadmill.Stop()
	stop(false)
end

function Treadmill.Init()
	task.spawn(function()
		pcall(function()
			local playerModule = require((player :: any).PlayerScripts:WaitForChild("PlayerModule", 10)) :: any
			controls = playerModule:GetControls()
		end)
	end)
	local gui = Theme.ScreenGui("Treadmill", 4)
	buildSpeedLines(gui)
	popupLayer = Theme.new("Frame", { Name = "Popups", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
	startTreadmillAnimations()
	State.OnAttribute("Speed", function(value)
		if running and type(value) == "number" then
			local point = math.floor(Economy.WalkSpeedFromStat(value))
			if point > lastWalkPoint then
				walkSpeedBurst(point - lastWalkPoint)
			end
			lastWalkPoint = point
		end
	end)

	hint = Theme.new("Frame", {
		Name = "RunningHint",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, if Theme.IsTouch then -150 else -24),
		Size = UDim2.fromOffset(420, 110),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	Theme.AutoScale(hint)
	rateLabel = Theme.Label({ Text = "", TextColor3 = Color3.fromRGB(210, 170, 255), Size = UDim2.new(1, 0, 0, 44), StrokeThickness = 3, Parent = hint })
	local getOff = Theme.Button({
		Text = if Theme.IsTouch then "GET OFF" else "GET OFF (Space)",
		Color = Theme.Colors.Red,
		Size = UDim2.fromOffset(260, 56),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 50),
		Parent = hint,
	})
	getOff.Activated:Connect(function()
		stop(true)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if running and not processed and (input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA) then
			stop(true)
		end
	end)
	UserInputService.JumpRequest:Connect(function()
		if running then
			stop(true)
		end
	end)

	-- Keep the character pinned to the belt (before physics and before rendering).
	local function pin()
		if not running or not pinned then
			return
		end
		local _, root = getCharacter()
		if root then
			root.CFrame = pinned
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
	RunService.Stepped:Connect(pin)
	RunService.RenderStepped:Connect(pin)

	-- Detect stepping on / leaving the treadmill
	task.spawn(function()
		while true do
			task.wait(0.1)
			local character, root, humanoid = getCharacter()
			local belt = getBelt()
			if running then
				if not character or not root or not humanoid or humanoid.Health <= 0 or not belt or player:GetAttribute("CarryingDonut") then
					stop(false)
				end
			elseif character and root and humanoid and belt and os.clock() > cooldownUntil and humanoid.Health > 0 then
				if isOnBelt(belt, root.Position) and not player:GetAttribute("CarryingDonut") then
					start(belt, character, root, humanoid)
				end
			end
		end
	end)

	-- One popup per second while running
	task.spawn(function()
		while true do
			task.wait(1)
			if running then
				popup()
				rateLabel.Text = `RUNNING!  +{Format.Rate(currentRate())} /s`
			end
		end
	end)

	player.CharacterAdded:Connect(function()
		running = false
		pinned = nil
		track = nil
		hint.Visible = false
		setControls(true)
		setRunFX(false, nil)
	end)
end

return Treadmill
