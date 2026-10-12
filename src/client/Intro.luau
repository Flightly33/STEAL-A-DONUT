--[[
	Intro: the opening cinematic (Config.Intro). Plays for brand-new players once the loading screen
	is gone, before the Update Log and the tutorial; anyone can watch it again from Settings (WATCH
	INTRO). Everything here is on this client only, apart from your own character walking (the real
	one, so you end up where the scene leaves you).

	  0.0  black bars slide in; the STEAL A DONUT title pops up over an aerial view of the map
	  3.4  the camera glides down to your base
	  6.0  you walk through your pen up to the donut shop's window...
	  9.2  ...and ask the baker: "One Donut Box Please" (he glances back over his shoulder)
	 10.6  he turns round with a donut box and holds it out over the counter
	 12.2  WHOOSH: Domer zips in from the side and skids to a stop beside you (dust, a little shake)
	 13.1  he winds up and snatches the box (it flies into his hand); the baker jumps back
	 13.65 he turns to the camera with a big cheeky grin, a wink and a twinkle on his teeth
	 15.0  his legs spin on the spot like a cartoon, then he zooms off to the first biome with it;
	       the baker shouts "HEY!", you point at him and run after him
	 16.7  the camera rises over your base, then swoops down behind you into the normal view, the
	       bars slide away, and the game starts as normal

	How it moves: nothing snaps from one pose to the next (Puppet.Animate fades between them),
	Domer and the baker lean, recoil and settle on springs (Motion.Spring), Domer's feet stay on
	the ground as he runs, and the camera glides through all its shots on one smooth curve
	(Motion.Curve) with a little hand-held drift, ending exactly where the normal camera takes
	over. Everything runs on the scene's own clock, so it plays the same at any frame rate.

	A SKIP button ends it at any time. The UI is hidden while it plays (HideUI, quietly) and your
	controls are off; both come back when it ends. While it's on, the player has the attribute
	Intro = true (the Update Log waits for it).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Layout = require(Shared.Layout)
local GuardModel = require(Shared.GuardModel)
local BoxModel = require(Shared.BoxModel)
local Puppet = require(Shared.Puppet)
local Motion = require(Shared.Motion)
local AnimeFX = require(Shared.AnimeFX)
local Signal = require(Shared.Signal)

local Theme = require(script.Parent.UI.Theme)
local HideUI = require(script.Parent.UI.HideUI)
local State = require(script.Parent.State)
local Bases = require(script.Parent.Bases)
local Bakers = require(script.Parent.Bakers)
local SpeedLines = require(script.Parent.SpeedLines)
local DonutTitle = require(script.Parent.UI.DonutTitle)

local Intro = {}

local player = Players.LocalPlayer :: Player
local rgb = Color3.fromRGB
local rad = math.rad
local smooth = Motion.Smooth
local WHITE = rgb(255, 255, 255)
local DARK = rgb(35, 20, 30)
local S = Config.Guard.Scale -- (Domer's scale: about 20 studs tall)
local BAKER_S = 1.5

-- When each part of the scene starts (seconds).
local T = {
	TitleIn = 0.3,
	TitleOut = 3.0,
	Fly = 3.4,
	Walk = 6.0,
	Arrive = 9.2,
	Turn = 10.6,
	Offer = 11.3,
	Zip = 12.2,
	Land = 12.55,
	Grab = 13.1,
	Grin = 13.65,
	Run = 15.0,
	Dash = 15.4,
	Chase = 15.7,
	Pull = 16.7,
	End = 18.6,
}
Intro.Times = T

local playing = false
-- fires when it ends (true = skipped)
Intro.Finished = Signal.new()

function Intro.IsPlaying(): boolean
	return playing
end

-- 0..1 with a little overshoot at the end (things popping into place)
local function backOut(u: number): number
	u = math.clamp(u, 0, 1)
	local c = 1.70158
	return 1 + (c + 1) * (u - 1) ^ 3 + c * (u - 1) ^ 2
end

-- Which way something faces (as a turn about the vertical), and the shorter way round to it.
local function yawOf(v: Vector3): number
	return math.atan2(-v.X, -v.Z)
end
local function near(angle: number, ref: number): number
	return ref + ((angle - ref + math.pi) % (2 * math.pi) - math.pi)
end
local function angles(cf: CFrame): (number, number)
	local look = cf.LookVector
	return yawOf(look), math.asin(math.clamp(look.Y, -1, 1))
end

local function sound(id: string, speed: number, volume: number)
	local s = Instance.new("Sound")
	s.Name = "IntroSound"
	s.SoundId = id
	s.PlaybackSpeed = speed
	s.Volume = volume
	s.Parent = SoundService
	s:Play()
	task.delay(4, function()
		s:Destroy()
	end)
end

local function setControls(on: boolean)
	pcall(function()
		local scripts = player:FindFirstChild("PlayerScripts")
		local module = scripts and scripts:FindFirstChild("PlayerModule")
		if module and module:IsA("ModuleScript") then
			local controls = (require(module) :: any):GetControls()
			if on then
				controls:Enable()
			else
				controls:Disable()
			end
		end
	end)
end

local function stillPart(name: string, cf: CFrame, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one * 0.2
	p.CFrame = cf
	p.Parent = parent
	return p
end

-- A speech bubble over `head` (white, rounded, with a tail). It pops up, types its words out, bobs
-- gently and shrinks away when it's done - all on the scene's clock (stepBubble).
type Bubble = { Gui: BillboardGui, Label: TextLabel, Scale: UIScale, Height: number, Born: number, Dying: number?, Count: number }
local function makeBubble(head: BasePart, text: string, height: number, color: Color3?, now: number, parent: Instance): Bubble
	local gui = Instance.new("BillboardGui")
	gui.Name = "SpeechBubble"
	gui.Adornee = head
	-- (as wide as the text needs: "!" gets a little round bubble, a sentence a long one)
	gui.Size = UDim2.fromOffset(math.clamp(40 + (utf8.len(text) or #text) * 15, 92, 340), 92)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = gui
	local box = Instance.new("Frame")
	box.Name = "Bubble"
	box.AnchorPoint = Vector2.new(0.5, 0)
	box.Position = UDim2.fromScale(0.5, 0)
	box.Size = UDim2.new(1, 0, 1, -18)
	box.BackgroundColor3 = color or WHITE
	box.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 22)
	corner.Parent = box
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = DARK
	stroke.Parent = box
	local tail = Instance.new("Frame")
	tail.Name = "Tail"
	tail.AnchorPoint = Vector2.new(0.5, 0.5)
	tail.Position = UDim2.new(0.5, 0, 1, -18)
	tail.Size = UDim2.fromOffset(22, 22)
	tail.Rotation = 45
	tail.BackgroundColor3 = color or WHITE
	tail.ZIndex = 0
	tail.Parent = gui
	local tailStroke = stroke:Clone()
	tailStroke.Parent = tail
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -24, 1, -10)
	label.Position = UDim2.fromOffset(12, 5)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = DARK
	label.Text = text
	label.MaxVisibleGraphemes = 0
	label.Parent = box
	gui.Parent = parent
	sound("rbxasset://sounds/button.wav", 1.4, 0.5)
	return { Gui = gui, Label = label, Scale = scale, Height = height, Born = now, Dying = nil, Count = utf8.len(text) or #text }
end

-- false once it has gone
local function stepBubble(b: Bubble, now: number): boolean
	local age = now - b.Born
	local size = 0.2 + 0.8 * backOut(age / 0.35)
	if b.Dying then
		local k = (now - b.Dying) / 0.14
		if k >= 1 then
			b.Gui:Destroy()
			return false
		end
		size *= 1 - smooth(k)
	end
	b.Scale.Scale = math.max(size, 0)
	local shown = math.floor(age / 0.025)
	b.Label.MaxVisibleGraphemes = if shown >= b.Count then -1 else shown
	b.Gui.StudsOffsetWorldSpace = Vector3.new(0, b.Height + math.sin(age * 3) * 0.08, 0)
	return true
end

-- The title card (a donut: client/UI/DonutTitle), black bars and SKIP button.
type Screen = { Gui: ScreenGui, Title: DonutTitle.Title, Top: Frame, Bottom: Frame, Skip: GuiButton }
local function buildScreen(): Screen
	local gui = Theme.ScreenGui("Intro", 60)
	gui.IgnoreGuiInset = true
	local function bar(name: string, y: number): Frame
		local f = Instance.new("Frame")
		f.Name = name
		f.BorderSizePixel = 0
		f.BackgroundColor3 = rgb(0, 0, 0)
		f.AnchorPoint = Vector2.new(0, y)
		f.Position = UDim2.fromScale(0, y)
		f.Size = UDim2.fromScale(1, 0)
		f.Parent = gui
		return f
	end
	local top, bottom = bar("TopBar", 0), bar("BottomBar", 1)
	local title = DonutTitle.new(gui)
	local skip = Theme.Button({
		Name = "Skip",
		Text = "SKIP",
		Color = Theme.Colors.Gray,
		Size = UDim2.fromOffset(120, 42),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -18),
		Parent = gui,
	})
	skip.ZIndex = 5
	return { Gui = gui, Title = title, Top = top, Bottom = bottom, Skip = skip }
end

-- Domer for the scene: the first biome's, with a grin and a wink he can switch to.
local function buildDomer(): (Puppet.Puppet?, { BasePart }, { BasePart })
	local model = GuardModel.Build(1)
	local tag = model:FindFirstChild("GuardTag", true)
	if tag and tag:IsA("BillboardGui") then
		tag.Enabled = false
	end
	local head = model:FindFirstChild("Head") :: BasePart?
	local grin: { BasePart } = {}
	local plain: { BasePart } = {}
	if head then
		local s = head.Size.X / 1.3
		local function piece(name: string, size: Vector3, color: Color3, offset: CFrame): Part
			local p = Instance.new("Part")
			p.Name = name
			p.Size = size * s
			p.Color = color
			p.Material = Enum.Material.SmoothPlastic
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			p.CFrame = head.CFrame * CFrame.new(offset.Position * s) * offset.Rotation
			p.Transparency = 1
			p.Parent = model
			local weld = Instance.new("Weld")
			weld.Part0 = head
			weld.Part1 = p
			weld.Parent = p
			table.insert(grin, p)
			return p
		end
		-- a wide grin with teeth, its corners turned up, and a wink ("^") on his right eye
		piece("Grin", Vector3.new(0.72, 0.2, 0.05), rgb(60, 20, 20), CFrame.new(0, -0.38, -0.71))
		piece("Teeth", Vector3.new(0.6, 0.09, 0.05), WHITE, CFrame.new(0, -0.32, -0.735))
		for _, side in { -1, 1 } do
			piece("GrinCorner", Vector3.new(0.18, 0.07, 0.05), rgb(60, 20, 20), CFrame.new(side * 0.4, -0.3, -0.71) * CFrame.Angles(0, 0, math.rad(side * 35)))
		end
		for _, side in { -1, 1 } do
			piece("Wink", Vector3.new(0.2, 0.07, 0.05), rgb(35, 20, 20), CFrame.new(0.27 + side * 0.08, 0.2, -0.8) * CFrame.Angles(0, 0, math.rad(side * -35)))
		end
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				local weld = part:FindFirstChildOfClass("Weld")
				local onHead = weld and weld.Part0 == head
				if onHead and (part.Name == "Mouth" or ((part.Name == "Eye" or part.Name == "Pupil") and head.CFrame:PointToObjectSpace(part.Position).X > 0)) then
					table.insert(plain, part)
				end
			end
		end
	end
	return Puppet.new(model), grin, plain
end

-- A soft cloud of dust kicked up off the ground (Domer's skid), switched on and off by its caller.
local function dustCloud(parent: BasePart): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "SkidDust"
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(rgb(245, 232, 205), rgb(205, 185, 150))
	e.LightEmission = 0
	e.Rate = 0
	e.Enabled = false
	e.Lifetime = NumberRange.new(0.45, 0.8)
	e.Speed = NumberRange.new(5, 11)
	e.SpreadAngle = Vector2.new(55, 55)
	e.Drag = 3
	e.Acceleration = Vector3.new(0, 4, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-40, 40)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 4.5) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = parent
	return e
end

-- Plays it (yields until it's over). opts.Speed: how fast (tests run it quicker).
function Intro.Play(opts: { Speed: number? }?)
	if playing then
		return
	end
	playing = true
	player:SetAttribute("Intro", true)
	local speed = (opts and opts.Speed) or 1
	local camera = workspace.CurrentCamera

	-- what we need: your base, its shop and baker, your character
	local plot: Instance? = nil
	local counter: BasePart? = nil
	local character: Model? = nil
	local root: BasePart? = nil
	local humanoid: Humanoid? = nil
	local waited = 0
	while waited < 12 do
		local index = player:GetAttribute("PlotIndex")
		plot = if type(index) == "number" then Bases.GetPlot(index) else nil
		local pen = plot and plot:FindFirstChild("Pen")
		local shop = pen and pen:FindFirstChild("DonutShop")
		local c = shop and shop:FindFirstChild("Counter")
		counter = if c and c:IsA("BasePart") then c else nil
		character = player.Character
		root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if counter and root and humanoid then
			break
		end
		task.wait(0.25)
		waited += 0.25
	end
	local plotIndex = player:GetAttribute("PlotIndex")
	local full = counter ~= nil and root ~= nil and humanoid ~= nil and plot ~= nil and type(plotIndex) == "number"

	-- How far behind you your camera sits now, so the scene can hand it back without a jump
	local zoom = 12.5
	pcall(function()
		local r = root
		if camera and r and camera.CameraType == Enum.CameraType.Custom then
			local focus = camera.Focus.Position
			local distance = (camera.CFrame.Position - focus).Magnitude
			if (focus - (r.Position + Vector3.new(0, 1.5, 0))).Magnitude < 4 and distance > 1 then
				zoom = math.clamp(distance, 6, 40)
			end
		end
	end)

	local scene = Instance.new("Folder")
	scene.Name = "IntroScene"
	scene.Parent = workspace
	local screen = buildScreen()
	local wasHidden = HideUI.IsHidden()
	HideUI.Set(true, true)
	local oldFov = if camera then camera.FieldOfView else 70
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	setControls(false)

	-- The map: an aerial view over the lobby, looking out towards the lane
	local map = Config.Map
	local lobby = Vector3.new(0, 0, map.SafeZoneZ - map.HubDepth / 2)
	local laneStart = Vector3.new(0, 0, Layout.AreaStart(1) + 30)
	local aerial0 = CFrame.lookAt(lobby + Vector3.new(-60, 320, -300), lobby + Vector3.new(0, 0, 120))
	local aerial1 = CFrame.lookAt(lobby + Vector3.new(30, 270, -220), lobby + Vector3.new(0, 0, 150))

	-- Your base (plot space: -Z towards the plaza, the shop at +Z behind the pen)
	local P = if plot then Layout.PlotCFrame(plotIndex :: number) else CFrame.new(lobby)
	local floor = P.Position.Y + Layout.PlotFloorHeight
	local counterLocal = if counter then P:PointToObjectSpace(counter.Position) else Vector3.new(0, 3, 40)
	local zSpot = counterLocal.Z - 6.5
	local function at(x: number, y: number, z: number): Vector3
		return P * Vector3.new(x, y, z)
	end
	-- (a spot on the ground)
	local function ground(x: number, z: number): Vector3
		local p = at(x, 0, z)
		return Vector3.new(p.X, floor, p.Z)
	end
	local gate = at(0, 0, Layout.PenFront - 10)
	local spot = at(0, 0, zSpot)
	local into = -P.LookVector -- (into the base, towards the shop)
	local out = P.LookVector
	local exit = at(0, 0, Layout.PenFront + 6) -- (where you run to, after Domer)

	-- Domer: where he comes from, skids to, and runs off along
	local domerFrom = ground(80, zSpot - 3)
	local domerAt = ground(11, zSpot - 3)
	local window = ground(0, zSpot + 4)
	local runPath = Motion.Path({ domerAt, ground(20, Layout.PenFront - 14), Vector3.new(laneStart.X, floor, laneStart.Z) }, 22)
	local domerMiddle = domerAt + Vector3.new(0, 3 * S, 0)

	-- The shots
	local baseView = CFrame.lookAt(at(-12, 18, Layout.PenFront - 34), at(0, 5, Layout.PenFront + 6))
	local walkView = CFrame.lookAt(at(-17, 10.5, zSpot - 13), at(1, 5.5, zSpot + 3))
	local shopView = CFrame.lookAt(at(-14, 9.5, zSpot - 10), at(1, 6, zSpot + 3.5))
	local wideEye, wideAt = at(-26, 16, zSpot - 28), at(4, 9, zSpot - 1)
	local wideView = CFrame.lookAt(wideEye, wideAt)
	local wideView2 = CFrame.lookAt(wideEye:Lerp(wideAt, 0.08), wideAt) -- (creeping in)
	local closeEye = at(-4, 17, zSpot - 24)
	local faceAt = domerMiddle + Vector3.new(0, 1.5 * S, 0)
	local grinView = CFrame.lookAt(closeEye, faceAt)
	local grinView2 = CFrame.lookAt(closeEye:Lerp(faceAt, 0.07), faceAt)
	-- (further back, for his legs spinning on the spot: all of him in the shot)
	local windEye = at(-14, 13, zSpot - 34)
	local windView = CFrame.lookAt(windEye, domerMiddle)
	local function youAt(): Vector3
		return if root then root.Position else spot + Vector3.new(0, 3, 0)
	end
	-- (the shots that follow you trail a little behind your real starts and stops, catching up
	-- exactly by the end, where the normal camera takes over)
	local follow = youAt()
	local function followYou(dt: number, now: number)
		local real = youAt()
		follow = follow:Lerp(real, 1 - math.exp(-dt * 5))
		follow = follow:Lerp(real, smooth((now - (T.End - 0.9)) / 0.9))
	end
	-- high over your base, looking out the way you're running: you, and Domer racing off ahead
	local function overView(): CFrame
		local r = follow
		return CFrame.lookAt(r + Vector3.new(0, 55, 0) - out * 30, r + out * 20)
	end
	-- the normal camera, exactly: behind you at your usual distance, looking over your head
	local handLook = (Vector3.new(out.X, 0, out.Z).Unit - Vector3.new(0, 0.23, 0)).Unit
	local function playerView(): CFrame
		local focus = follow + Vector3.new(0, 1.5, 0)
		return CFrame.lookAt(focus - handLook * zoom, focus)
	end
	local function still(cf: CFrame): () -> CFrame
		return function()
			return cf
		end
	end
	type Key = { Time: number, View: () -> CFrame, Fov: number, Hand: number }
	local keys: { Key } = {
		{ Time = 0, View = still(aerial0), Fov = 60, Hand = 0.3 },
		{ Time = T.Fly, View = still(aerial1), Fov = 60, Hand = 0.3 },
		{ Time = T.Walk, View = still(baseView), Fov = 55, Hand = 0.6 },
		{ Time = T.Arrive, View = still(walkView), Fov = 55, Hand = 0.7 },
		{ Time = T.Zip, View = still(shopView), Fov = 55, Hand = 0.7 },
		{ Time = T.Land + 0.15, View = still(wideView), Fov = 60, Hand = 0.9 },
		{ Time = T.Grin, View = still(wideView2), Fov = 58, Hand = 0.8 },
		{ Time = T.Grin + 0.55, View = still(grinView), Fov = 45, Hand = 0.8 },
		{ Time = T.Run - 0.2, View = still(grinView2), Fov = 44, Hand = 0.8 },
		{ Time = T.Run + 0.4, View = still(windView), Fov = 55, Hand = 0.9 },
		{ Time = T.Pull, View = overView, Fov = 60, Hand = 0.5 },
		{ Time = T.End, View = playerView, Fov = oldFov, Hand = 0 },
	}
	if not full then
		keys = { keys[1], keys[2], { Time = T.Fly + 1.5, View = still(aerial1), Fov = 60, Hand = 0 } }
	end
	local endTime = keys[#keys].Time
	local times: { number } = {}
	for i, k in keys do
		times[i] = k.Time
	end
	-- Where the camera is at `now`: one smooth curve through every shot (position, the way it
	-- faces, zoom), with a touch of hand-held drift.
	local function cameraAt(now: number): (CFrame, number)
		local xs, ys, zs, yaws, pitches, fovs, hands = {}, {}, {}, {}, {}, {}, {}
		local lastYaw: number? = nil
		for i, k in keys do
			local cf = k.View()
			local yaw, pitch = angles(cf)
			if lastYaw then
				yaw = near(yaw, lastYaw)
			end
			lastYaw = yaw
			local p = cf.Position
			xs[i], ys[i], zs[i], yaws[i], pitches[i], fovs[i], hands[i] = p.X, p.Y, p.Z, yaw, pitch, k.Fov, k.Hand
		end
		local C = Motion.Curve
		local pos = Vector3.new(C(times, xs, now), C(times, ys, now), C(times, zs, now))
		local yaw, pitch = C(times, yaws, now), C(times, pitches, now)
		local hand = math.max(0, C(times, hands, now))
		yaw += Motion.Noise(now * 0.9, 1) * 0.0045 * hand
		pitch += Motion.Noise(now * 0.8, 2) * 0.0035 * hand
		pos += Vector3.new(Motion.Noise(now * 0.7, 3), Motion.Noise(now * 0.6, 4), Motion.Noise(now * 0.75, 5)) * 0.08 * hand
		return CFrame.new(pos) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0), C(times, fovs, now)
	end

	-- The cast
	local domer, grinParts, plainParts = buildDomer()
	local domerAnim = if domer then Puppet.Animator(domer) else nil
	if domer then
		domer.Model.Parent = nil
	end
	local baker = if full then Bakers.Take(plotIndex :: number) else nil
	local box: Model? = nil
	local boxFrom: CFrame? = nil
	local bubbles: { Bubble } = {}
	local walkSpeed: number? = nil
	local turnGoal: Vector3? = nil

	-- Domer's body: where he is (on the ground), which way he faces, how he leans... all springy
	local dPos = domerFrom
	local dYaw = Motion.Spring(yawOf(domerAt - domerFrom))
	local dLean = Motion.Spring(rad(-26)) -- (+ leaning back)
	local dRoll = Motion.Spring(0)
	local dHead = Motion.Spring(0) -- (his head turned from his body: it leads every turn)
	local dHeight = Motion.Spring(floor + 3 * S)
	local dStep = Motion.Spring(0) -- (the lunge towards the window)
	local tiltX, tiltZ = Motion.Spring(0), Motion.Spring(0) -- (the box he holds swinging about)
	local stridePhase, runDistance, runSpeed = 0, 0, 0
	local runDone = false
	local lastHand: Vector3? = nil
	local handVelocity = Vector3.zero
	local dust: ParticleEmitter? = nil
	local dustPart: BasePart? = nil
	-- the baker's springs
	local bLean = Motion.Spring(0)
	local bHead = Motion.Spring(0)

	if full and root then
		-- (out of sight while the camera is still up in the air)
		root.CFrame = CFrame.lookAt(gate + Vector3.new(0, 3.5, 0), gate + Vector3.new(0, 3.5, 0) + into)
		pcall(function()
			(root :: BasePart).AssemblyLinearVelocity = Vector3.zero
		end)
	end

	local fired: { [string]: boolean } = {}
	local function once(name: string, t: number, at_: number): boolean
		if t >= at_ and not fired[name] then
			fired[name] = true
			return true
		end
		return false
	end

	local function say(head: BasePart?, text: string, height: number, color: Color3?, now: number)
		for _, b in bubbles do
			b.Dying = b.Dying or now
		end
		if head then
			table.insert(bubbles, makeBubble(head, text, height, color, now, scene))
		end
	end

	-- Domer posed: his springy body, the joints given, standing on the ground (or not)
	local function poseDomer(dt: number, state: string, fade: number, joints: { [string]: CFrame }, grounded: boolean, lift: number)
		if not (domer and domerAnim) then
			return
		end
		local turn = CFrame.Angles(0, dYaw.X, 0) * CFrame.Angles(dLean.X, 0, dRoll.X)
		local want = floor + 3 * S + lift
		if grounded then
			-- (high enough that his lowest foot just touches the ground)
			local probe = CFrame.new(dPos + Vector3.new(0, 3 * S, 0)) * turn
			want = probe.Position.Y + floor + lift - Puppet.Lowest(domer, probe, joints)
		end
		Motion.Step(dHeight, want, dt, 7, 1)
		Puppet.Animate(domerAnim, dt, CFrame.new(dPos.X, dHeight.X, dPos.Z) * turn, joints, state, fade)
	end
	local function domerPart(name: string, limb: string?): BasePart?
		if not domer then
			return nil
		end
		local index = Puppet.Find(domer, name, limb)
		return if index then domer.Parts[index] else nil
	end
	-- where the box sits when Domer holds it: on his palm, the right way up, swinging a little
	local function domerHolds(): CFrame?
		local hand = domerPart("Hand", "Right Arm")
		if not hand then
			return nil
		end
		return CFrame.new((hand.CFrame * CFrame.new(0, -0.75 * S, 0)).Position) * CFrame.Angles(0, dYaw.X, 0) * CFrame.Angles(tiltX.X, 0, tiltZ.X)
	end
	-- (the box lags behind his hand when it speeds up or slows down, and swings back)
	local function swingBox(dt: number)
		local hand = domerPart("Hand", "Right Arm")
		if not hand or dt <= 0 then
			return
		end
		local p = hand.CFrame.Position
		local v = if lastHand then (p - lastHand) / dt else Vector3.zero
		local a = (v - handVelocity) / dt
		lastHand, handVelocity = p, v
		local here = CFrame.Angles(0, dYaw.X, 0):VectorToObjectSpace(a)
		Motion.Step(tiltX, math.clamp(-here.Z * 0.0012, -0.3, 0.3), dt, 1.8, 0.3)
		Motion.Step(tiltZ, math.clamp(here.X * 0.0012, -0.3, 0.3), dt, 1.8, 0.3)
	end
	-- where the box sits when the baker holds it: between his hands
	local function bakerHolds(): CFrame?
		if not baker then
			return nil
		end
		local pz = baker.Puppet
		local l, r = Puppet.Find(pz, "Hand", "Left Arm"), Puppet.Find(pz, "Hand", "Right Arm")
		if not (l and r) then
			return nil
		end
		local body = (pz.Pose or baker.Home).Rotation
		local middle = pz.Parts[l].CFrame.Position:Lerp(pz.Parts[r].CFrame.Position, 0.5)
		return CFrame.new(middle) * body * CFrame.new(0, -1.15, -0.35 * BAKER_S)
	end
	local function gaze(from: CFrame, target: Vector3, limit: number): number
		local v = from:PointToObjectSpace(target)
		return math.clamp(math.atan2(-v.X, -v.Z), -limit, limit)
	end
	local function domerHeadAt(): Vector3
		local head = domerPart("Head")
		return if head and head.Parent then head.CFrame.Position else faceAt
	end

	local t = 0
	local shake = 0
	local connection: RBXScriptConnection? = nil
	local domerConnection: RBXScriptConnection? = nil
	local done = false
	local skipped = false

	local function cleanupDomer()
		if domerConnection then
			domerConnection:Disconnect()
			domerConnection = nil
		end
		if domer then
			domer.Model:Destroy()
		end
		if box then
			box:Destroy()
		end
	end

	local function finish()
		if done then
			return
		end
		done = true
		if connection then
			connection:Disconnect()
		end
		for _, b in bubbles do
			b.Gui:Destroy()
		end
		table.clear(bubbles)
		if walkSpeed and humanoid then
			humanoid.WalkSpeed = walkSpeed
		end
		if fired.Walk and humanoid and root then
			-- (stop where you are: from here on, you're walking)
			local r = root
			pcall(function()
				(humanoid :: Humanoid):MoveTo(r.Position)
			end)
		end
		if skipped or not fired.Run then
			cleanupDomer()
		end
		if full then
			Bakers.Release(plotIndex :: number)
		end
		-- the bars slide away, the screen comes back
		TweenService:Create(screen.Top, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Size = UDim2.fromScale(1, 0) }):Play()
		TweenService:Create(screen.Bottom, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Size = UDim2.fromScale(1, 0) }):Play()
		screen.Skip.Visible = false
		screen.Title.Frame.Visible = false
		task.delay(0.45, function()
			screen.Gui:Destroy()
			if not domerConnection then
				scene:Destroy()
			end
		end)
		if camera then
			-- (always the normal camera: the scene hands it over behind you)
			camera.CameraType = Enum.CameraType.Custom
			camera.FieldOfView = oldFov
			if humanoid then
				camera.CameraSubject = humanoid
			end
		end
		setControls(true)
		if not wasHidden then
			HideUI.Set(false)
		end
		player:SetAttribute("Intro", nil)
		playing = false
		Intro.Finished:Fire(skipped)
	end
	screen.Skip.Activated:Connect(function()
		skipped = true
		finish()
	end)

	-- Domer running off to the lane (carries on after the scene, then vanishes in a puff). First
	-- the cartoon wind-up: he crouches, his legs spin faster and faster on the spot... then he's off.
	local launched = false
	local function runDomer(dt: number, age: number)
		if not domer then
			return
		end
		local windup = T.Dash - T.Run
		local joints: { [string]: CFrame }
		if age < windup then
			local u = age / windup
			local _, dir0 = Motion.PathAt(runPath, 0)
			stridePhase += dt * (5 + 17 * smooth((u - 0.2) / 0.6))
			joints = Puppet.Gait(stridePhase, 1.1 * smooth((u - 0.15) / 0.4))
			joints["Right Arm"] = CFrame.Angles(rad(-160), 0, rad(14))
			Motion.Step(dYaw, near(yawOf(dir0), dYaw.X), dt, 4, 0.9)
			Motion.Step(dLean, rad(-8) - rad(22) * smooth((u - 0.3) / 0.5), dt, 6, 0.8)
			Motion.Step(dHead, 0, dt, 5, 0.8)
			joints.Head = CFrame.Angles(0, dHead.X, 0)
			-- (a crouch to get ready, then up on his toes, hovering like a cartoon)
			local hover = -0.3 * S * smooth(u / 0.3) * (1 - smooth((u - 0.35) / 0.3)) + 0.22 * S * smooth((u - 0.45) / 0.4)
			poseDomer(dt, "Windup", 0.15, joints, false, hover)
		else
			if not launched then
				launched = true
				sound("rbxasset://sounds/swordlunge.wav", 0.7, 0.8)
				SpeedLines.Flash(0.45, 0.5)
				local puff = stillPart("DashDust", CFrame.new(dPos + Vector3.new(0, 1, 0)), scene)
				AnimeFX.Fire(AnimeFX.Impact(puff, { rgb(255, 225, 170) }, 2.4))
			end
			-- a burst of speed, leaning into it, banking round the corner
			runSpeed = math.min(58, runSpeed + dt * 58 / 0.28)
			runDistance += runSpeed * dt
			local pos, dir, turn = Motion.PathAt(runPath, runDistance)
			dPos = pos
			stridePhase += runSpeed * dt / (1.25 * S)
			local bounce, twist
			joints, bounce, twist = Puppet.Gait(stridePhase, 0.78)
			joints["Right Arm"] = CFrame.Angles(rad(-162), 0, rad(14))
			Motion.Step(dYaw, near(yawOf(dir) + twist * 0.07, dYaw.X), dt, 6, 0.9)
			Motion.Step(dLean, rad(-15) - rad(10) * (1 - runSpeed / 58), dt, 5, 0.8)
			Motion.Step(dRoll, math.clamp(turn * runSpeed * 0.1, -0.3, 0.3), dt, 3, 0.8)
			-- (his head stays steady while his shoulders twist, eyes on where he's going)
			Motion.Step(dHead, -twist * 0.07, dt, 6, 0.9)
			joints.Head = CFrame.Angles(0, dHead.X, 0) * CFrame.Angles(-dLean.X * 0.5, 0, 0)
			poseDomer(dt, "Run", 0.25, joints, true, bounce * 0.22 * S)
			if runDistance >= runPath.Length - 0.5 then
				runDone = true
			end
		end
		swingBox(dt)
		local held = domerHolds()
		if box and held then
			box:PivotTo(held)
		end
	end

	-- You: walk up to the window, ask for a box, point after Domer and run after him
	local function updateYou(dt: number)
		local r, h = root, humanoid
		if not (r and h) then
			return
		end
		if once("Walk", t, T.Walk) then
			walkSpeed = h.WalkSpeed
			local distance = (spot - r.Position).Magnitude
			h.WalkSpeed = math.clamp(distance / (T.Arrive - T.Walk - 0.4), 8, 40)
			pcall(function()
				h:MoveTo(spot)
			end)
		end
		if once("Arrive", t, T.Arrive) then
			if walkSpeed then
				h.WalkSpeed = walkSpeed
				walkSpeed = nil
			end
			local here = r.Position
			if (Vector3.new(spot.X, here.Y, spot.Z) - here).Magnitude > 4 then
				-- (something was in the way: just be there)
				r.CFrame = CFrame.lookAt(spot + Vector3.new(0, 3.5, 0), spot + Vector3.new(0, 3.5, 0) + into)
			end
			turnGoal = into
			say(character and character:FindFirstChild("Head") :: BasePart?, Config.Intro.Bubble, 3.2, nil, t)
		end
		if once("BubbleOff", t, T.Zip) then
			for _, b in bubbles do
				b.Dying = b.Dying or t
			end
		end
		if once("Point", t, T.Run + 0.05) then
			turnGoal = (dPos - r.Position) * Vector3.new(1, 0, 1)
			-- (the point emote, where the avatar's animations have it)
			task.spawn(function()
				pcall(function()
					h:PlayEmoteAsync("point")
				end)
			end)
		end
		if once("Chase", t, T.Chase) then
			turnGoal = nil
			pcall(function()
				h:MoveTo(exit)
			end)
		end
		-- turning smoothly to face something (only while standing: walking, you face your way)
		local walking = (t >= T.Walk and t < T.Arrive) or t >= T.Chase
		local goal = turnGoal
		if goal and not walking and goal.Magnitude > 0.01 then
			local yaw = yawOf(r.CFrame.LookVector)
			local want = near(yawOf(goal), yaw)
			if math.abs(want - yaw) < 0.01 then
				turnGoal = nil
			else
				yaw += (want - yaw) * (1 - math.exp(-dt * 10))
				r.CFrame = CFrame.new(r.Position) * CFrame.Angles(0, yaw, 0)
			end
		end
	end

	-- The baker: kneading at the back, a glance over his shoulder, turning round with the box,
	-- holding it out... jumping back when it's snatched, then shaking his fist after Domer
	local function updateBaker(dt: number)
		if not baker then
			return
		end
		local s = BAKER_S
		local turnA = smooth((t - T.Turn - 0.08) / 0.55)
		local headA = smooth((t - T.Turn) / 0.4)
		local body = baker.Home * CFrame.Angles(0, math.pi * (1 - turnA), 0)
		local joints: { [string]: CFrame } = {}
		local state, fade = "Knead", 0.3
		local leanGoal, headGoal, dip = 0, 0, 0
		local headTilt = CFrame.identity
		local release = T.Grab + 0.1
		if t < T.Turn then
			local k = math.sin(t * 2 * math.pi * 1.4)
			joints["Left Arm"] = CFrame.Angles(rad(-62) + 0.2 * k, 0, rad(-8))
			joints["Right Arm"] = CFrame.Angles(rad(-62) + 0.2 * k, 0, rad(8))
			headTilt = CFrame.Angles(rad(-12) - 0.05 * k, 0, 0)
			dip = -(k + 1) * 0.035 * s
			leanGoal = rad(-6) - 0.04 * k
			-- ("Coming!": a look back over his shoulder when you ask)
			local glance = smooth((t - T.Arrive - 0.5) / 0.3) * (1 - smooth((t - T.Arrive - 1.3) / 0.35))
			headGoal = -1.2 * glance
		elseif t < T.Offer then
			state, fade = "Carry", 0.35
			joints["Left Arm"] = CFrame.Angles(rad(-58), 0, rad(-10))
			joints["Right Arm"] = CFrame.Angles(rad(-58), 0, rad(10))
			-- (his head comes round first, his body follows)
			headGoal = math.clamp(math.pi * (turnA - headA), -1.2, 0)
			dip = -math.sin(math.pi * turnA) * 0.07 * s
		elseif t < release then
			state, fade = "Offer", 0.4
			joints["Left Arm"] = CFrame.Angles(rad(-84), 0, rad(-6))
			joints["Right Arm"] = CFrame.Angles(rad(-84), 0, rad(6))
			headTilt = CFrame.Angles(rad(-4), 0, 0)
			leanGoal = rad(-9)
			if root then
				headGoal = gaze(body, root.Position + Vector3.new(0, 1.5, 0), 0.5)
			end
		elseif t < T.Run then
			local startled = t < release + 0.6
			state, fade = (if startled then "Startle" else "Stunned"), (if startled then 0.09 else 0.5)
			joints["Left Arm"] = if startled then CFrame.Angles(rad(-128), 0, rad(-28)) else CFrame.Angles(rad(-32), 0, rad(-14))
			joints["Right Arm"] = if startled then CFrame.Angles(rad(-128), 0, rad(28)) else CFrame.Angles(rad(-32), 0, rad(14))
			headTilt = if startled then CFrame.Angles(rad(12), 0, 0) else CFrame.Angles(0, 0, rad(-6))
			leanGoal = rad(4)
			headGoal = gaze(body, domerHeadAt(), 1.1)
		else
			state, fade = "Angry", 0.25
			local shake = math.sin(t * 2 * math.pi * 5.5)
			joints["Right Arm"] = CFrame.Angles(rad(-150) + 0.22 * shake, 0, rad(12))
			joints["Left Arm"] = CFrame.Angles(rad(-40), 0, rad(-12))
			leanGoal = rad(-10)
			dip = -math.abs(math.sin(t * 2 * math.pi * 2.75)) * 0.05 * s
			headGoal = gaze(body, domerHeadAt(), 1.2)
		end
		if once("Recoil", t, release) then
			Motion.Kick(bLean, 3.2)
		end
		Motion.Step(bLean, leanGoal, dt, 2.6, 0.45)
		Motion.Step(bHead, headGoal, dt, 4, 0.85)
		joints.Head = CFrame.Angles(0, bHead.X, 0) * headTilt
		local breathe = math.sin(t * 1.7) * 0.025 * s
		Puppet.Animate(baker.Anim, dt, body * CFrame.new(0, dip + breathe, 0) * CFrame.Angles(bLean.X, 0, 0), joints, state, fade)
	end

	-- Domer: zips in, skids, wobbles upright, winds up and snatches the box, then grins at you
	local ZIP = T.Land + 0.22 - T.Zip
	local function updateDomer(dt: number)
		if not (domer and domerAnim) then
			return
		end
		if once("Zip", t, T.Zip) then
			domer.Model.Parent = scene
			sound("rbxasset://sounds/swordlunge.wav", 0.55, 0.9)
			SpeedLines.Flash(0.55, 0.6)
			local dustAt = stillPart("SkidDust", CFrame.new(domerAt), scene)
			dustPart = dustAt
			dust = dustCloud(dustAt)
		end
		if t < T.Zip or t >= T.Run then
			return
		end
		local u = math.min((t - T.Zip) / ZIP, 1)
		local travel = 1 - (1 - u) ^ 3
		local joints: { [string]: CFrame } = {}
		local state, fade = "Zip", 0.1
		local lift = 0
		local toWindow = (window - domerAt).Unit
		if t < T.Land then
			-- legs a blur, arms swept back, leaning into it
			stridePhase += dt * 22
			joints = Puppet.Gait(stridePhase, 1.0)
			joints["Left Arm"] = CFrame.Angles(rad(55), 0, rad(-14))
			joints["Right Arm"] = CFrame.Angles(rad(55), 0, rad(14))
			Motion.Step(dLean, rad(-26), dt, 4, 0.7)
			lift = 0.15 * S * math.abs(math.sin(stridePhase))
		elseif u < 1 then
			-- skidding to a stop: heels dug in, leaning back, arms out for balance
			state, fade = "Skid", 0.2
			joints["Left Leg"] = CFrame.Angles(rad(-38), 0, 0)
			joints["Right Leg"] = CFrame.Angles(rad(12), 0, 0)
			joints["Left Arm"] = CFrame.Angles(rad(-75), 0, rad(-30))
			joints["Right Arm"] = CFrame.Angles(rad(-65), 0, rad(30))
			Motion.Step(dLean, rad(20), dt, 5, 0.6)
		elseif t < T.Grab - 0.16 then
			-- upright again with a wobble, eyes on the box
			state, fade = "Stand", 0.22
			joints["Left Arm"] = CFrame.Angles(rad(-8), 0, rad(-6))
			joints["Right Arm"] = CFrame.Angles(rad(-8), 0, rad(6))
			joints.Head = CFrame.Angles(rad(-14), 0, 0)
			Motion.Step(dLean, 0, dt, 2.8, 0.35)
		elseif t < T.Grab + 0.12 then
			-- winds his arm back... and lunges for it
			local wind = t < T.Grab
			state, fade = (if wind then "Wind" else "Reach"), (if wind then 0.12 else 0.08)
			joints["Right Arm"] = if wind then CFrame.Angles(rad(30), 0, rad(14)) else CFrame.Angles(rad(-100), 0, rad(6))
			joints["Left Arm"] = CFrame.Angles(rad(if wind then -15 else 25), 0, rad(-10))
			joints.Head = CFrame.Angles(rad(-12), 0, 0)
			Motion.Step(dLean, if wind then rad(6) else rad(-12), dt, 4.5, 0.6)
			Motion.Step(dStep, if wind then -0.6 else 1.8, dt, 5, 0.8)
		elseif t < T.Grin then
			-- pulls it in close
			state, fade = "Hold", 0.18
			joints["Right Arm"] = CFrame.Angles(rad(-55), 0, rad(-12))
			joints["Left Arm"] = CFrame.Angles(rad(-35), 0, rad(-14))
			Motion.Step(dLean, rad(4), dt, 3, 0.5)
		else
			-- a big grin at you, the box held up high, a chuckle
			state, fade = "Grin", 0.32
			joints["Right Arm"] = CFrame.Angles(rad(-160), 0, rad(14))
			joints["Left Arm"] = CFrame.Angles(rad(-12), 0, rad(-28))
			local chuckle = math.sin((t - T.Grin) * 2 * math.pi * 4.5) * smooth((t - T.Grin - 0.25) / 0.2) * (1 - smooth((t - T.Grin - 1.0) / 0.4))
			lift = math.abs(chuckle) * 0.05 * S
			joints.Head = CFrame.Angles(0, 0, rad(8) * smooth((t - T.Grin) / 0.4))
			Motion.Step(dLean, rad(-3) + chuckle * 0.03, dt, 4, 0.6)
		end
		if t >= T.Grab + 0.12 then
			Motion.Step(dStep, 0, dt, 2.5, 0.9)
		end
		dPos = domerFrom:Lerp(domerAt, travel) + Vector3.new(toWindow.X, 0, toWindow.Z) * dStep.X
		-- which way he faces: where he's going, then the box, then you; his head gets there first
		local goal = if u < 1 then yawOf(domerAt - domerFrom) elseif t < T.Grin then yawOf(window - domerAt) else yawOf(closeEye - domerAt)
		goal = near(goal, dYaw.X)
		Motion.Step(dYaw, goal, dt, if t < T.Grin then 3 else 1.8, 0.85)
		Motion.Step(dHead, math.clamp(goal - dYaw.X, -0.9, 0.9), dt, 5, 0.8)
		joints.Head = CFrame.Angles(0, dHead.X, 0) * (joints.Head or CFrame.identity)
		Motion.Step(dRoll, 0, dt, 3, 0.8)
		poseDomer(dt, state, fade, joints, true, lift)

		if dust and dustPart then
			-- (kicking up dust while he skids)
			dustPart.CFrame = CFrame.new(dPos + Vector3.new(0, 0.6, 0))
			dust.Enabled = t >= T.Land - 0.08 and u < 1
			dust.Rate = 90
		end
		if once("Land", t, T.Land) then
			sound("rbxasset://sounds/action_jump_land.mp3", 0.6, 1)
			local puff = stillPart("LandDust", CFrame.new(domerAt + Vector3.new(0, 1, 0)), scene)
			AnimeFX.Fire(AnimeFX.Impact(puff, { rgb(255, 210, 120) }, 1.8))
			shake = 0.5
		end
		if once("Grab", t, T.Grab + 0.1) then
			sound("rbxasset://sounds/unsheath.wav", 1.5, 0.7)
			if baker then
				for _, part in baker.Puppet.Parts do
					if part.Name == "Smile" then
						part.Transparency = 1
					elseif part.Name == "MouthOpen" then
						part.Transparency = 0
					end
				end
				say(baker.Puppet.Model:FindFirstChild("Head") :: BasePart?, "!", 3.5 * BAKER_S, rgb(255, 235, 120), t)
			end
		end
		if once("Grin", t, T.Grin + 0.25) then
			-- (the baker's "!" goes: this close-up is all Domer's)
			for _, b in bubbles do
				b.Dying = b.Dying or t
			end
			for _, part in plainParts do
				part.Transparency = 1
			end
			for _, part in grinParts do
				part.Transparency = 0
			end
			local teeth = domer.Model:FindFirstChild("Teeth") :: BasePart?
			if teeth then
				local twinkle = AnimeFX.Kira(teeth, WHITE, 2.4, 0)
				twinkle.Enabled = true
				twinkle:Emit(2)
			end
			sound("rbxasset://sounds/electronicpingshort.wav", 2, 0.6)
		end
	end

	-- The box: appears in the baker's hands while his back is turned, flies to Domer's hand
	local function updateBox(dt: number)
		if once("Box", t, T.Turn - 0.25) then
			local b = BoxModel.Build("Basic", nil, { NoEffects = true })
			for _, part in b:GetDescendants() do
				if part:IsA("BasePart") then
					part.Anchored = true
					part.CanCollide = false
					part.CanQuery = false
					part.CanTouch = false
				end
			end
			b.Parent = scene
			box = b
		end
		local b = box
		if not b or t >= T.Run then
			return
		end
		local release = T.Grab + 0.1
		if t < release then
			local held = bakerHolds()
			if held then
				b:PivotTo(held)
				boxFrom = held
			end
		elseif t < release + 0.24 then
			local goal, from = domerHolds(), boxFrom
			if goal and from then
				local a = smooth((t - release) / 0.24)
				local p = from.Position:Lerp(goal.Position, a) + Vector3.new(0, math.sin(a * math.pi) * 3.5, 0)
				b:PivotTo(CFrame.new(p) * from.Rotation:Lerp(goal.Rotation, a) * CFrame.Angles(0, a * math.pi * 2, 0))
			end
		else
			swingBox(dt)
			local held = domerHolds()
			if held then
				b:PivotTo(held)
			end
		end
	end

	-- The run: from T.Run, on its own clock (he keeps going after the scene ends)
	local function startRun()
		say(if baker then baker.Puppet.Model:FindFirstChild("Head") :: BasePart? else nil, "HEY!", 3.5 * BAKER_S, rgb(255, 235, 120), t)
		sound("rbxasset://sounds/action_footsteps_plastic.mp3", 3, 0.9) -- (feet spinning on the spot)
		if dust then
			dust.Enabled = false
		end
		local lifetime = 0
		domerConnection = RunService.RenderStepped:Connect(function(frame: number)
			local dt = math.min(frame, 0.1) * speed
			lifetime += dt
			runDomer(dt, lifetime)
			if runDone or lifetime > 9 then
				local last = dPos + Vector3.new(0, 3 * S, 0)
				cleanupDomer()
				local puff = stillPart("Puff", CFrame.new(last), scene)
				AnimeFX.Fire(AnimeFX.Impact(puff, { rgb(255, 230, 160) }, 3))
				task.delay(1.5, function()
					if not playing then
						scene:Destroy()
					end
				end)
			end
		end)
	end

	-- The screen: black bars, the title, the speech bubbles
	local function updateScreen()
		local bars = 0.1 * smooth(t / 0.6)
		screen.Top.Size = UDim2.fromScale(1, bars)
		screen.Bottom.Size = UDim2.fromScale(1, bars)
		-- the title: its letters pop in, the frosting drips, then it swells and fades away
		local outA = smooth((t - T.TitleOut) / 0.45)
		local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		DonutTitle.Step(screen.Title, t, T.TitleIn, 1 - outA, viewport, 1 + 0.15 * outA)
		if once("TitleIn", t, T.TitleIn) then
			sound("rbxasset://sounds/swordlunge.wav", 0.8, 0.5)
		end
		for i = #bubbles, 1, -1 do
			if not stepBubble(bubbles[i], t) then
				table.remove(bubbles, i)
			end
		end
	end

	local function update(dt: number)
		local step = dt * speed
		t += step
		updateScreen()
		if full and root and humanoid then
			updateYou(step)
			updateBaker(step)
			updateDomer(step)
			updateBox(step)
			if domer and once("Run", t, T.Run) then
				startRun()
			end
		end
		-- the camera (and a shake when Domer lands)
		if camera then
			followYou(step, t)
			local view, fov = cameraAt(t)
			if shake > 0 then
				shake = math.max(0, shake - step * 1.8)
				local k = shake * shake
				view *= CFrame.new(math.sin(t * 53) * 0.5 * k, math.cos(t * 47) * 0.5 * k, 0) * CFrame.Angles(math.sin(t * 41) * 0.012 * k, math.cos(t * 37) * 0.012 * k, 0)
			end
			camera.CFrame = view
			camera.FieldOfView = fov
		end
		if t >= endTime then
			finish()
		end
	end

	connection = RunService.RenderStepped:Connect(function(dt: number)
		if character and humanoid and humanoid.Health <= 0 then
			skipped = true
			finish()
			return
		end
		update(math.min(dt, 0.1))
	end)
	while not done do
		task.wait(0.1)
	end
end


-- Settings > WATCH INTRO: again, from the lobby (not while you're carrying something or out in
-- the lane). Returns false (with why) if you can't right now.
-- The admin panel's buttons pass `anywhere` (no lobby or carrying check: for testing) and a
-- `speed` (0.5 = half speed, to look at it closely).
function Intro.Watch(anywhere: boolean?, speed: number?): (boolean, string?)
	if playing then
		return false, "It's already playing!"
	end
	if anywhere then
		task.spawn(Intro.Play, { Speed = speed or 1 })
		return true, nil
	end
	if player:GetAttribute("CarryKind") then
		return false, "Put down what you're carrying first!"
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not Layout.IsSafe(root.Position) then
		return false, "Go back to the lobby to watch the intro."
	end
	task.spawn(Intro.Play)
	return true, nil
end

function Intro.Init()
	if not Config.Intro.Enabled then
		return
	end
	-- Brand-new players (or everyone, with EveryJoin): once the loading screen has gone. (The
	-- attribute goes on straight away, so the Update Log knows to wait.)
	local checked = false
	State.Changed:Connect(function(snapshot)
		if checked then
			return
		end
		checked = true
		if snapshot.SeenTutorial == false or Config.Intro.EveryJoin then
			player:SetAttribute("Intro", true)
			task.spawn(function()
				local waited = 0
				while player:GetAttribute("LoadingScreen") and waited < 60 do
					task.wait(0.25)
					waited += 0.25
				end
				task.wait(0.3)
				Intro.Play()
			end)
		end
	end)
end

return Intro
