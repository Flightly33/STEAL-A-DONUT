--[[
	Intro: the opening cinematic (Config.Intro). Plays for brand-new players once the loading screen
	is gone, before the Update Log and the tutorial; anyone can watch it again from Settings (WATCH
	INTRO). Everything here is on this client only, apart from your own character walking (the real
	one, so you end up where the scene leaves you).

	  0.0  black bars slide in; the STEAL A DONUT title pops up over an aerial view of the map
	  3.4  the camera swoops down to your base
	  6.0  you walk through your pen up to the donut shop's window...
	  9.2  ...and ask the baker: "One Donut Box Please"
	 10.6  the baker turns round holding a donut box and holds it out over the counter
	 12.2  WHOOSH: Domer zips in from the side and skids to a stop (an impact puff, a little shake)
	 12.85 he snatches the box (it flies into his hand); the baker gasps
	 13.4  he turns to the camera with a big cheeky grin, a wink and a twinkle on his teeth
	 15.0  and runs off to the first biome with it, legs going like mad; the baker shouts "HEY!"
	 16.6  the camera pulls back behind you, the bars slide away, and the game starts as normal

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
local AnimeFX = require(Shared.AnimeFX)

local Theme = require(script.Parent.UI.Theme)
local HideUI = require(script.Parent.UI.HideUI)
local State = require(script.Parent.State)
local Bases = require(script.Parent.Bases)
local Bakers = require(script.Parent.Bakers)
local SpeedLines = require(script.Parent.SpeedLines)

local Intro = {}

local player = Players.LocalPlayer :: Player
local rgb = Color3.fromRGB
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
	Grab = 12.85,
	Grin = 13.4,
	Run = 15.0,
	Pull = 16.6,
	End = 18.4,
}
Intro.Times = T

local playing = false
local finishedSignal = Instance.new("BindableEvent")
Intro.Finished = finishedSignal.Event

function Intro.IsPlaying(): boolean
	return playing
end

local function ease(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * (3 - 2 * a)
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

-- A speech bubble over `head` (white, rounded, with a tail), the text typed out.
local function bubble(head: BasePart, text: string, height: number, color: Color3?): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "SpeechBubble"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(320, 92)
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
	gui.Parent = workspace:FindFirstChild("IntroScene") or workspace
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.spawn(function()
		local count = utf8.len(text) or #text
		for i = 1, count do
			if not label.Parent then
				return
			end
			label.MaxVisibleGraphemes = i
			task.wait(0.025)
		end
		label.MaxVisibleGraphemes = -1
	end)
	sound("rbxasset://sounds/button.wav", 1.4, 0.5)
	return gui
end

-- The title card, black bars and SKIP button.
type Screen = { Gui: ScreenGui, Title: TextLabel, TitleScale: UIScale, Top: Frame, Bottom: Frame, Skip: GuiButton }
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
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.4)
	title.Size = UDim2.fromScale(0.82, 0.24)
	title.Font = Enum.Font.LuckiestGuy
	title.Text = "STEAL A DONUT"
	title.TextScaled = true
	title.TextColor3 = WHITE
	title.TextTransparency = 1
	title.Rotation = -4
	title.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, rgb(255, 245, 170)),
		ColorSequenceKeypoint.new(0.5, rgb(255, 170, 60)),
		ColorSequenceKeypoint.new(1, rgb(255, 90, 160)),
	})
	gradient.Parent = title
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 7
	stroke.Color = rgb(60, 20, 55)
	stroke.Transparency = 1
	stroke.Parent = title
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = title
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
	return { Gui = gui, Title = title, TitleScale = scale, Top = top, Bottom = bottom, Skip = skip }
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

	local scene = Instance.new("Folder")
	scene.Name = "IntroScene"
	scene.Parent = workspace
	local screen = buildScreen()
	local wasHidden = HideUI.IsHidden()
	HideUI.Set(true, true)
	local oldType = if camera then camera.CameraType else Enum.CameraType.Custom
	local oldFov = if camera then camera.FieldOfView else 70
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	setControls(false)
	TweenService:Create(screen.Top, TweenInfo.new(0.6), { Size = UDim2.fromScale(1, 0.1) }):Play()
	TweenService:Create(screen.Bottom, TweenInfo.new(0.6), { Size = UDim2.fromScale(1, 0.1) }):Play()

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
	local gate = at(0, 0, Layout.PenFront - 10)
	local spot = at(0, 0, zSpot)
	local into = -P.LookVector -- (into the base, towards the shop)
	local baseView = CFrame.lookAt(at(-12, 18, Layout.PenFront - 34), at(0, 5, Layout.PenFront + 6))
	local walkView = CFrame.lookAt(at(-17, 9, zSpot - 13), at(1, 5.5, zSpot + 3))
	local shopView = CFrame.lookAt(at(-14, 8, zSpot - 10), at(1, 6, zSpot + 3.5))
	local wideView = CFrame.lookAt(at(-26, 16, zSpot - 28), at(5, 9, zSpot))
	local closeEye = at(-4, 17, zSpot - 24)

	-- Domer: where he comes from, lands and runs to
	local domerY = floor + 3 * S + 0.3
	local domerFrom = at(80, 0, zSpot - 3) + Vector3.new(0, domerY - P.Position.Y, 0)
	local domerAt = at(13, 0, zSpot - 2) + Vector3.new(0, domerY - P.Position.Y, 0)
	local runPath = { domerAt, at(8, 0, Layout.PenFront - 14) + Vector3.new(0, domerY - P.Position.Y, 0), laneStart + Vector3.new(0, domerY, 0) }

	local domer, grinParts, plainParts = buildDomer()
	if domer then
		domer.Model.Parent = nil
	end
	local baker = if full then Bakers.Take(plotIndex :: number) else nil
	local box: Model? = nil
	local bubbles: { Instance } = {}
	local walkSpeed: number? = nil
	local domerPos = domerFrom
	local domerFacing = CFrame.lookAt(domerFrom, domerAt).Rotation
	local runDistance = 0
	local runDone = false

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

	-- the box: in the baker's hands, flying, then in Domer's hand
	local function boxInBakerHands(): CFrame?
		if not baker then
			return nil
		end
		local pose = baker.Puppet.Pose or baker.Home
		return pose * CFrame.new(0, -0.35 * BAKER_S, -2.0 * BAKER_S)
	end
	local function domerHand(): CFrame?
		if not domer then
			return nil
		end
		local index = Puppet.Find(domer, "Hand", "Right Arm")
		return if index then domer.Parts[index].CFrame else nil
	end

	local t = 0
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
			b:Destroy()
		end
		if walkSpeed and humanoid then
			humanoid.WalkSpeed = walkSpeed
		end
		if skipped or not fired.Run then
			cleanupDomer()
		end
		if full then
			Bakers.Release(plotIndex :: number)
		end
		-- the bars slide away, the screen comes back
		TweenService:Create(screen.Top, TweenInfo.new(0.4), { Size = UDim2.fromScale(1, 0) }):Play()
		TweenService:Create(screen.Bottom, TweenInfo.new(0.4), { Size = UDim2.fromScale(1, 0) }):Play()
		screen.Skip.Visible = false
		task.delay(0.45, function()
			screen.Gui:Destroy()
			if not domerConnection then
				scene:Destroy()
			end
		end)
		if camera then
			camera.CameraType = if oldType == Enum.CameraType.Scriptable then Enum.CameraType.Custom else oldType
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
		finishedSignal:Fire(skipped)
	end
	screen.Skip.Activated:Connect(function()
		skipped = true
		finish()
	end)

	-- Domer running off to the lane (carries on after the scene, then vanishes in a puff)
	local function runDomer(dt: number)
		if not domer then
			return
		end
		local step = 58 * dt
		runDistance += step
		local remaining = step
		while remaining > 0 and #runPath >= 2 do
			local nextPoint = runPath[2]
			local gap = (nextPoint - domerPos).Magnitude
			if gap <= remaining then
				domerPos = nextPoint
				table.remove(runPath, 1)
				remaining -= gap
			else
				domerPos += (nextPoint - domerPos).Unit * remaining
				remaining = 0
			end
		end
		if #runPath >= 2 then
			local ahead = (runPath[2] - domerPos) * Vector3.new(1, 0, 1)
			if ahead.Magnitude > 0.1 then
				domerFacing = CFrame.lookAt(Vector3.zero, ahead).Rotation
			end
		else
			runDone = true
		end
		local phase = runDistance / (1.4 * S)
		local joints = Puppet.Stride(phase, 1.0)
		joints["Right Arm"] = CFrame.Angles(0, 0, math.rad(160)) -- (the box held up over his head)
		local bob = math.abs(math.sin(phase)) * 0.35 * S
		Puppet.Pose(domer, CFrame.new(domerPos + Vector3.new(0, bob, 0)) * domerFacing * CFrame.Angles(math.rad(-14), 0, 0), joints)
		local hand = domerHand()
		if box and hand then
			box:PivotTo(CFrame.new((hand * CFrame.new(0, -0.75 * S, 0)).Position) * domerFacing)
		end
	end

	-- The camera: from one shot to the next, smoothly
	local function chaseView(): CFrame
		local back = -domerFacing.LookVector
		return CFrame.lookAt(domerPos + back * 40 + Vector3.new(0, 20, 0), domerPos + Vector3.new(0, 4, 0))
	end
	local function playerView(): CFrame
		local r = root
		if not r then
			return chaseView()
		end
		local look = (laneStart - r.Position) * Vector3.new(1, 0, 1)
		local dir = if look.Magnitude > 1 then look.Unit else -into
		local eye = r.Position - dir * 13 + Vector3.new(0, 5.5, 0)
		return CFrame.lookAt(eye, r.Position + dir * 4 + Vector3.new(0, 2, 0))
	end
	local function grinView(): CFrame
		return CFrame.lookAt(closeEye, domerAt + Vector3.new(0, 1.5 * S, 0))
	end
	type Key = { Time: number, View: () -> CFrame, Fov: number }
	local keys: { Key } = {
		{ Time = 0, View = function() return aerial0 end, Fov = 60 },
		{ Time = T.Fly, View = function() return aerial1 end, Fov = 60 },
		{ Time = T.Walk, View = function() return baseView end, Fov = 55 },
		{ Time = T.Arrive, View = function() return walkView end, Fov = 55 },
		{ Time = T.Zip, View = function() return shopView end, Fov = 55 },
		{ Time = T.Grab + 0.2, View = function() return wideView end, Fov = 60 },
		{ Time = T.Grin + 0.35, View = grinView, Fov = 45 },
		{ Time = T.Run, View = grinView, Fov = 45 },
		{ Time = T.Pull, View = chaseView, Fov = 60 },
		{ Time = T.End, View = playerView, Fov = oldFov },
	}
	if not full then
		keys = { keys[1], keys[2], { Time = T.Fly + 1.5, View = function() return aerial1 end, Fov = 60 } }
	end
	local endTime = keys[#keys].Time
	local shake = 0

	local function update(dt: number)
		t += dt * speed
		local step = dt * speed
		-- the title card
		if once("TitleIn", t, T.TitleIn) then
			TweenService:Create(screen.Title, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
			local stroke = screen.Title:FindFirstChildOfClass("UIStroke")
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(0.25), { Transparency = 0 }):Play()
			end
			TweenService:Create(screen.TitleScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			sound("rbxasset://sounds/swordlunge.wav", 0.8, 0.5)
		end
		if t > T.TitleIn and t < T.TitleOut then
			screen.Title.Rotation = -4 + math.sin(t * 2) * 1.2
		end
		if once("TitleOut", t, T.TitleOut) then
			TweenService:Create(screen.Title, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			local stroke = screen.Title:FindFirstChildOfClass("UIStroke")
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end
			TweenService:Create(screen.TitleScale, TweenInfo.new(0.4), { Scale = 1.25 }):Play()
		end

		if full and root and humanoid then
			-- the baker: busy at the back of the shop until he turns round with the box
			if baker then
				local turnA = ease((t - T.Turn) / 0.5)
				local lean = ease((t - T.Offer) / 0.4) * (1 - ease((t - T.Grab) / 0.3))
				local cf = baker.Home * CFrame.Angles(0, math.pi * (1 - turnA), 0) * CFrame.new(0, 0, -0.4 * lean * BAKER_S) * CFrame.Angles(math.rad(-8) * lean, 0, 0)
				local joints: { [string]: CFrame } = {}
				if t < T.Turn then
					-- kneading dough at the back
					local k = math.sin(t * 6) * 0.25
					joints["Left Arm"] = CFrame.Angles(math.rad(-60) + k, 0, 0)
					joints["Right Arm"] = CFrame.Angles(math.rad(-60) - k, 0, 0)
				elseif t < T.Run then
					-- holding the box out (then holding nothing, frozen in shock)
					joints["Left Arm"] = CFrame.Angles(math.rad(-80), 0, math.rad(-12))
					joints["Right Arm"] = CFrame.Angles(math.rad(-80), 0, math.rad(12))
					if t >= T.Grab then
						joints.Head = CFrame.Angles(math.rad(10), math.rad(25), 0)
					end
				else
					-- shaking his fist after Domer
					joints["Right Arm"] = CFrame.Angles(0, 0, math.rad(150 + math.sin(t * 18) * 15))
					joints["Left Arm"] = CFrame.Angles(math.rad(-20), 0, math.rad(-10))
					joints.Head = CFrame.Angles(0, math.rad(35), 0)
				end
				Puppet.Pose(baker.Puppet, cf, joints)
			end
			if once("Box", t, T.Turn + 0.15) then
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
			if box and t < T.Grab then
				local held = boxInBakerHands()
				if held then
					box:PivotTo(held)
				end
			end

			-- you: walk up to the window, ask for a box
			if once("Walk", t, T.Walk) then
				walkSpeed = humanoid.WalkSpeed
				local distance = (spot - root.Position).Magnitude
				humanoid.WalkSpeed = math.clamp(distance / (T.Arrive - T.Walk - 0.4), 8, 40)
				pcall(function()
					(humanoid :: Humanoid):MoveTo(spot)
				end)
			end
			if once("Arrive", t, T.Arrive) then
				if walkSpeed then
					humanoid.WalkSpeed = walkSpeed
					walkSpeed = nil
				end
				local here = root.Position
				local flat = Vector3.new(spot.X, here.Y, spot.Z)
				if (flat - here).Magnitude > 4 then
					here = spot + Vector3.new(0, 3.5, 0)
				end
				root.CFrame = CFrame.lookAt(here, here + into)
				local head = character and character:FindFirstChild("Head") :: BasePart?
				if head then
					table.insert(bubbles, bubble(head, Config.Intro.Bubble, 3.2))
				end
			end
			if once("BubbleOff", t, T.Zip) then
				for _, b in bubbles do
					b:Destroy()
				end
				table.clear(bubbles)
			end

			-- Domer zips in, snatches the box, grins, and runs for it
			if domer then
				if once("Zip", t, T.Zip) then
					domer.Model.Parent = scene
					sound("rbxasset://sounds/swordlunge.wav", 0.55, 0.9)
					SpeedLines.Flash(0.55, 0.6)
				end
				if t >= T.Zip and t < T.Run then
					local joints: { [string]: CFrame } = {}
					local cf: CFrame
					if t < T.Land then
						local a = 1 - (1 - math.clamp((t - T.Zip) / (T.Land - T.Zip), 0, 1)) ^ 2
						domerPos = domerFrom:Lerp(domerAt, a)
						joints = Puppet.Stride(t * 30, 1.1)
						cf = CFrame.new(domerPos) * domerFacing * CFrame.Angles(math.rad(-22), 0, 0)
					else
						domerPos = domerAt
						-- skids, then leans towards the window and grabs; then turns to the camera
						local skid = 1 - ease((t - T.Land) / 0.25)
						local face: CFrame
						if t < T.Grin then
							face = CFrame.lookAt(domerAt, at(0, 0, zSpot + 4) + Vector3.new(0, domerAt.Y - P.Position.Y, 0)).Rotation
							local reach = ease((t - T.Grab + 0.1) / 0.15) * (1 - ease((t - T.Grab - 0.3) / 0.2))
							joints["Right Arm"] = CFrame.Angles(math.rad(-95) * reach, 0, math.rad(10) * reach)
						else
							local toCamera = (closeEye - domerAt) * Vector3.new(1, 0, 1)
							local target = CFrame.lookAt(Vector3.zero, toCamera).Rotation
							local from = CFrame.lookAt(domerAt, at(0, 0, zSpot + 4) + Vector3.new(0, domerAt.Y - P.Position.Y, 0)).Rotation
							face = from:Lerp(target, ease((t - T.Grin) / 0.3))
							-- the box held up, a little bounce
							joints["Right Arm"] = CFrame.Angles(0, 0, math.rad(150))
							joints["Left Arm"] = CFrame.Angles(0, 0, math.rad(-20))
						end
						domerFacing = face
						local bounce = if t >= T.Grin then math.abs(math.sin((t - T.Grin) * 7)) * 0.12 * S else 0
						cf = CFrame.new(domerPos + Vector3.new(0, bounce, 0)) * face * CFrame.Angles(math.rad(12) * skid, 0, 0)
					end
					Puppet.Pose(domer, cf, joints)
				end
				if once("Land", t, T.Land) then
					sound("rbxasset://sounds/action_jump_land.mp3", 0.6, 1)
					local feet = Vector3.new(domerAt.X, floor + 1, domerAt.Z)
					local spotPart = Instance.new("Part")
					spotPart.Anchored = true
					spotPart.CanCollide = false
					spotPart.CanQuery = false
					spotPart.CanTouch = false
					spotPart.Transparency = 1
					spotPart.Size = Vector3.one * 0.2
					spotPart.CFrame = CFrame.new(feet)
					spotPart.Parent = scene
					AnimeFX.Fire(AnimeFX.Impact(spotPart, { rgb(255, 210, 120) }, 2.2))
					shake = 0.5
				end
				-- the snatch: the box flies into his hand
				if box and t >= T.Grab then
					local hand = domerHand()
					local held = boxInBakerHands()
					if hand and held and t < T.Grab + 0.3 then
						local a = ease((t - T.Grab) / 0.3)
						local goal = hand * CFrame.new(0, -0.7 * S, 0)
						local p = held.Position:Lerp(goal.Position, a) + Vector3.new(0, math.sin(a * math.pi) * 5, 0)
						box:PivotTo(CFrame.new(p) * held.Rotation:Lerp(domerFacing, a) * CFrame.Angles(0, a * math.pi * 2, 0))
					elseif hand and t < T.Run then
						box:PivotTo(CFrame.new((hand * CFrame.new(0, -0.75 * S, 0)).Position) * domerFacing)
					end
				end
				if once("Grab", t, T.Grab) then
					sound("rbxasset://sounds/unsheath.wav", 1.5, 0.7)
					if baker then
						for _, part in baker.Puppet.Parts do
							if part.Name == "Smile" then
								part.Transparency = 1
							elseif part.Name == "MouthOpen" then
								part.Transparency = 0
							end
						end
						local head = baker.Puppet.Model:FindFirstChild("Head") :: BasePart?
						if head then
							table.insert(bubbles, bubble(head, "!", 3.5 * BAKER_S, rgb(255, 235, 120)))
						end
					end
				end
				if once("Grin", t, T.Grin + 0.2) then
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
				if once("Run", t, T.Run) then
					for _, b in bubbles do
						b:Destroy()
					end
					table.clear(bubbles)
					if baker then
						local head = baker.Puppet.Model:FindFirstChild("Head") :: BasePart?
						if head then
							table.insert(bubbles, bubble(head, "HEY!", 3.5 * BAKER_S, rgb(255, 235, 120)))
						end
					end
					sound("rbxasset://sounds/swordlunge.wav", 0.7, 0.8)
					-- he keeps running after the scene ends, then disappears in a puff
					local lifetime = 0
					domerConnection = RunService.RenderStepped:Connect(function(frame: number)
						lifetime += frame
						runDomer(frame)
						if runDone or lifetime > 9 then
							local last = domerPos
							cleanupDomer()
							local puff = Instance.new("Part")
							puff.Anchored = true
							puff.CanCollide = false
							puff.CanQuery = false
							puff.CanTouch = false
							puff.Transparency = 1
							puff.Size = Vector3.one * 0.2
							puff.CFrame = CFrame.new(last)
							puff.Parent = scene
							AnimeFX.Fire(AnimeFX.Impact(puff, { rgb(255, 230, 160) }, 3))
							task.delay(1.5, function()
								if not playing then
									scene:Destroy()
								end
							end)
						end
					end)
				end
			end
			-- you turn to watch him go
			if once("Watch", t, T.Run + 0.4) then
				local look = (laneStart - root.Position) * Vector3.new(1, 0, 1)
				if look.Magnitude > 1 then
					root.CFrame = CFrame.lookAt(root.Position, root.Position + look.Unit)
				end
			end
		end

		-- the camera
		if camera then
			local view, fov = keys[#keys].View(), keys[#keys].Fov
			for i = 1, #keys - 1 do
				local a, b = keys[i], keys[i + 1]
				if t < b.Time then
					local alpha = ease((t - a.Time) / math.max(b.Time - a.Time, 1e-3))
					view = a.View():Lerp(b.View(), alpha)
					fov = a.Fov + (b.Fov - a.Fov) * alpha
					break
				end
			end
			if shake > 0 then
				shake = math.max(0, shake - step)
				local k = shake * 1.2
				view *= CFrame.new(math.sin(t * 61) * k, math.cos(t * 47) * k, 0)
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
function Intro.Watch(): (boolean, string?)
	if playing then
		return false, "It's already playing!"
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
