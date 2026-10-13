--[[
	MythicOpening: opening a MYTHIC donut box gets its own little film (instead of the box popping
	open in your pen), all of it in a vignette between black bars:

	  0.0  you're inside your donut shop with the baker; he holds out the glowing Mythic box -
	       "A MYTHIC box... just for you!"
	  1.7  your arms come up and you take it from him
	  2.9  the camera cranes up to just above you, looking down at the box in your hands
	  4.0  the lid rattles... and blows off in a burst of bright light (a pillar of light, sparkles
	       rising)
	  5.0  you reach into the light... and pull the donut out; a white flash and you're holding it
	       up high, the camera in front of you looking up at it
	  6.6  its rarity and name slam onto the screen
	  7.8  everything fades out to white, and you're back where you were

	Your real character is used: it's moved into the shop (and back after), held still, and its
	arms are posed by turning its shoulder joints every frame after its animations (R6 or R15).
	The baker is your shop's own (client/Bakers). SKIP ends it any time; if anything breaks, it ends
	and puts everything back. The donut is already yours (the server gave it when the box opened):
	this is only the show.

	  MythicOpening.CanPlay()           not during another scene, the loading screen or a shot, or
	                                    while you're carrying something
	  MythicOpening.Play(info)          info: { DonutId, Mutation, Size } (the box's BoxOpened info)
	  MythicOpening.Preview()           the admin panel's test: a random rare donut, nothing given
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BoxModel = require(Shared.BoxModel)
local Donuts = require(Shared.Donuts)
local DonutModel = require(Shared.DonutModel)
local Rarities = require(Shared.Rarities)
local Puppet = require(Shared.Puppet)

local Bakers = require(script.Parent.Bakers)
local Bases = require(script.Parent.Bases)
local Cinematic = require(script.Parent.Cinematic)
local HideUI = require(script.Parent.UI.HideUI)
local Theme = require(script.Parent.UI.Theme)
local Treadmill = require(script.Parent.Treadmill)

local MythicOpening = {}

local rgb = Color3.fromRGB
local WHITE = rgb(255, 255, 255)
local CRIMSON = rgb(255, 45, 85)
local GOLD = rgb(255, 210, 90)
local BAKER_S = 1.5
local BOX_SCALE = 0.5 -- (a box small enough to hold in your hands)

-- When each thing happens (seconds)
local T = { Ask = 0.3, Reach = 1.7, Take = 2.2, Swing = 2.9, Open = 4.0, Light = 4.35, Dip = 5.0, Pull = 5.55, Raise = 6.1, Title = 6.6, Fade = 7.8, End = 8.6 }
MythicOpening.Times = T

local player = Players.LocalPlayer
local playing = false

export type Info = { DonutId: string, Mutation: string?, Size: string? }

local function smooth(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * a * (a * (a * 6 - 15) + 10)
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

-- Your shop's counter and baker (nil if your base isn't there)
local function myShop(): (BasePart?, number?)
	local index = player:GetAttribute("PlotIndex")
	local plot = if type(index) == "number" then Bases.GetPlot(index) else nil
	local pen = plot and plot:FindFirstChild("Pen")
	local shop = pen and pen:FindFirstChild("DonutShop")
	local counter = shop and shop:FindFirstChild("Counter")
	if counter and counter:IsA("BasePart") and type(index) == "number" then
		return counter, index
	end
	return nil, nil
end

function MythicOpening.CanPlay(): boolean
	if playing or not player then
		return false
	end
	if player:GetAttribute("Intro") or player:GetAttribute("LoadingScreen") or player:GetAttribute("CarryKind") ~= nil or Cinematic.IsPlaying() then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local counter = myShop()
	return root ~= nil and counter ~= nil
end

function MythicOpening.IsPlaying(): boolean
	return playing
end

-- Your character's shoulder joints (R6: in the Torso; R15: in each upper arm)
local function shoulders(character: Model): { [string]: Motor6D }
	local found: { [string]: Motor6D } = {}
	local torso = character:FindFirstChild("Torso")
	local joints: { { Side: string, R6: string, R15: string } } = {
		{ Side = "Left", R6 = "Left Shoulder", R15 = "LeftShoulder" },
		{ Side = "Right", R6 = "Right Shoulder", R15 = "RightShoulder" },
	}
	for _, joint in joints do
		local motor = torso and torso:FindFirstChild(joint.R6)
		if not motor then
			local upper = character:FindFirstChild(joint.Side .. "UpperArm")
			motor = upper and upper:FindFirstChild(joint.R15)
		end
		if motor and motor:IsA("Motor6D") then
			found[joint.Side] = motor
		end
	end
	return found
end

-- Where your hand is (the bottom of an R6 arm, or an R15 hand); nil if it can't be found, or if
-- it's nowhere near you (an odd custom rig)
local function handOf(character: Model, side: string, body: Vector3): Vector3?
	local at: Vector3? = nil
	local hand = character:FindFirstChild(side .. "Hand")
	local arm = character:FindFirstChild(side .. " Arm")
	if hand and hand:IsA("BasePart") then
		at = hand.CFrame.Position
	elseif arm and arm:IsA("BasePart") then
		at = (arm.CFrame * CFrame.new(0, -arm.Size.Y / 2 + 0.2, 0)).Position
	end
	return if at and (at - body).Magnitude < 6 then at else nil
end

local function anchorAll(model: Model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
end

-- The screen: black bars, a dark vignette all round, the fades, the title, SKIP
type Screen = { Gui: ScreenGui, Bars: { Frame }, Edges: { Frame }, Fade: Frame, Title: TextLabel, Name: TextLabel, TitleScale: UIScale, Skip: GuiButton }
local function buildScreen(): Screen
	local gui = Theme.ScreenGui("MythicOpening", 61)
	gui.IgnoreGuiInset = true
	local bars: { Frame } = {}
	for _, y in { 0, 1 } do
		local f = Instance.new("Frame")
		f.Name = if y == 0 then "TopBar" else "BottomBar"
		f.BorderSizePixel = 0
		f.BackgroundColor3 = rgb(0, 0, 0)
		f.AnchorPoint = Vector2.new(0, y)
		f.Position = UDim2.fromScale(0, y)
		f.Size = UDim2.fromScale(1, 0)
		f.ZIndex = 4
		f.Parent = gui
		table.insert(bars, f)
	end
	local edges: { Frame } = {}
	for _, side in { { 0, 0, 0.28, 1, 0 }, { 1, 0, 0.28, 1, 180 }, { 0, 0, 1, 0.32, 90 }, { 0, 1, 1, 0.32, 270 } } do
		local f = Instance.new("Frame")
		f.Name = "Vignette"
		f.BorderSizePixel = 0
		f.BackgroundColor3 = rgb(0, 0, 0)
		f.BackgroundTransparency = 1
		f.AnchorPoint = Vector2.new(side[1], side[2])
		f.Position = UDim2.fromScale(side[1], side[2])
		f.Size = UDim2.fromScale(side[3], side[4])
		f.ZIndex = 2
		local g = Instance.new("UIGradient")
		g.Rotation = side[5]
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.45, 0.55), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = f
		f.Parent = gui
		table.insert(edges, f)
	end
	local fade = Instance.new("Frame")
	fade.Name = "Fade"
	fade.BorderSizePixel = 0
	fade.BackgroundColor3 = rgb(0, 0, 0)
	fade.BackgroundTransparency = 0
	fade.Size = UDim2.fromScale(1, 1)
	fade.ZIndex = 6
	fade.Parent = gui
	local title = Theme.Label({ Name = "Title", Text = "MYTHIC!", TextColor3 = CRIMSON, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.72), Size = UDim2.fromOffset(700, 90), StrokeThickness = 6, Parent = gui })
	title.ZIndex = 5
	title.Visible = false
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, GOLD), ColorSequenceKeypoint.new(0.5, WHITE), ColorSequenceKeypoint.new(1, CRIMSON) })
	gradient.Rotation = 90
	gradient.Parent = title
	local titleScale = Instance.new("UIScale")
	titleScale.Parent = title
	local name = Theme.Label({ Name = "DonutName", Text = "", TextColor3 = WHITE, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.81), Size = UDim2.fromOffset(700, 44), StrokeThickness = 3.5, Parent = gui })
	name.ZIndex = 5
	name.Visible = false
	local skip = Theme.Button({ Name = "Skip", Text = "SKIP", Color = Theme.Colors.Gray, Size = UDim2.fromOffset(120, 42), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -18), Parent = gui })
	skip.ZIndex = 7
	return { Gui = gui, Bars = bars, Edges = edges, Fade = fade, Title = title, Name = name, TitleScale = titleScale, Skip = skip }
end

-- A speech bubble over the baker's head
local function bubble(head: BasePart, text: string): BillboardGui
	local b = Instance.new("BillboardGui")
	b.Name = "SpeechBubble"
	b.Size = UDim2.fromOffset(300, 56)
	b.StudsOffsetWorldSpace = Vector3.new(0, 3.2 * BAKER_S, 0)
	b.AlwaysOnTop = true
	b.LightInfluence = 0
	b.Adornee = head
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = WHITE
	frame.Parent = b
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = rgb(40, 30, 40)
	stroke.Parent = frame
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Theme.Font
	label.TextScaled = true
	label.TextColor3 = rgb(40, 30, 40)
	label.Text = text
	label.Parent = frame
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
	padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
	padding.Parent = frame
	b.Parent = head
	return b
end

function MythicOpening.Play(info: Info): boolean
	if not MythicOpening.CanPlay() then
		return false
	end
	local donut = Donuts.ById[info.DonutId]
	local counter, plotIndex = myShop()
	local rarity = Rarities.Get(if donut then donut.Rarity else "Common")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local camera = workspace.CurrentCamera
	if not (donut and counter and plotIndex and character and root and humanoid and camera) then
		return false
	end
	playing = true
	player:SetAttribute("MythicOpening", true)
	-- (everything as it was, to put back at the end - whatever happens)
	local wasHidden = HideUI.IsHidden()
	local oldFov = camera.FieldOfView
	local oldType = camera.CameraType
	local saved = root.CFrame
	local wasAnchored = root.Anchored
	local scene = Instance.new("Folder")
	scene.Name = "MythicOpeningScene"
	local connections: { RBXScriptConnection } = {}
	local motors: { [string]: Motor6D } = {}
	local tookBaker = false
	local done = false
	local animate: BaseScript? = nil
	local animateWasEnabled = true
	-- (the room's light as it was, and what we last set it to: only our own changes are undone)
	local lightingBefore: { [string]: any } = {}
	local lightingSet: { [string]: any } = {}
	local grade: ColorCorrectionEffect? = nil

	local function finish()
		if done then
			return
		end
		done = true
		for _, c in connections do
			c:Disconnect()
		end
		-- (the next animation frame puts your shoulders back by itself)
		pcall(function()
			for _, motor in motors do
				motor.Transform = CFrame.identity
			end
		end)
		pcall(function()
			local gui = player:FindFirstChild("PlayerGui")
			local screen = gui and gui:FindFirstChild("MythicOpening")
			if screen then
				screen:Destroy()
			end
		end)
		pcall(function()
			scene:Destroy()
		end)
		if tookBaker then
			pcall(Bakers.Release, plotIndex :: number)
		end
		pcall(function()
			local r = root :: BasePart
			r.CFrame = saved
			r.Anchored = wasAnchored
		end)
		pcall(function()
			camera.CameraType = if oldType == Enum.CameraType.Scriptable then Enum.CameraType.Custom else oldType
			camera.FieldOfView = oldFov
			camera.CameraSubject = humanoid
		end)
		setControls(true)
		if not wasHidden then
			pcall(HideUI.Set, false)
		end
		-- your animations back on, and the room's light as it was (unless something else changed it since)
		pcall(function()
			if animate then
				animate.Enabled = animateWasEnabled
			end
		end)
		for key, value in lightingBefore do
			pcall(function()
				if (Lighting :: any)[key] == lightingSet[key] then
					(Lighting :: any)[key] = value
				end
			end)
		end
		if grade then
			pcall(function()
				(grade :: ColorCorrectionEffect):Destroy()
			end)
		end
		player:SetAttribute("MythicOpening", nil)
		playing = false
		Theme.PlaySound("Collect")
	end

	local started, problem = pcall(function()
		scene.Parent = workspace
		-- (off the treadmill, or it would keep pulling you back onto its belt)
		Treadmill.Stop()
		local screen = buildScreen()
		HideUI.Set(true, true)
		camera.CameraType = Enum.CameraType.Scriptable
		setControls(false)
		local baker = Bakers.Take(plotIndex :: number)
		tookBaker = baker ~= nil

		-- It all happens inside your shop, on the open floor left of the prep table (in the counter's
		-- own space: +X across the shop, +Z deeper in, the floor half its height below its middle):
		-- the baker steps over there and turns round, and you stand in front of him facing the
		-- window, held still. (All while the screen is still black.)
		local SPOT_X, BAKER_Z, YOU_Z = -8.5, 4.5, 9.3
		local floorY = -counter.Size.Y / 2
		local bakerSpot = counter.CFrame * CFrame.new(SPOT_X, floorY + 3 * BAKER_S, BAKER_Z) * CFrame.Angles(0, math.pi, 0)
		local front = counter.CFrame * CFrame.new(SPOT_X, 0, YOU_Z)
		local facing = (counter.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
		local hip = if humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight + root.Size.Y / 2 else 3
		-- (the floor under you; if it can't be found, the floor the counter stands on)
		local ground = front.Position.Y - counter.Size.Y / 2
		pcall(function()
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { character, scene }
			local hit = workspace:Raycast(front.Position + Vector3.new(0, 6, 0), Vector3.new(0, -20, 0), params)
			if hit then
				ground = hit.Position.Y
			end
		end)
		local stand = CFrame.lookAt(Vector3.new(front.Position.X, ground + hip, front.Position.Z), Vector3.new(front.Position.X, ground + hip, front.Position.Z) + facing)
		root.Anchored = true
		root.CFrame = stand

		-- Your arms: turned at the shoulders every frame, after your animations
		motors = shoulders(character)
		local armGoal: { [string]: CFrame } = { Left = CFrame.identity, Right = CFrame.identity }
		local armNow: { [string]: CFrame } = { Left = CFrame.identity, Right = CFrame.identity }
		local function poseArms(dt: number)
			for side, motor in motors do
				armNow[side] = armNow[side]:Lerp(armGoal[side], math.min(1, dt * 9))
				local q = motor.C0.Rotation
				motor.Transform = q:Inverse() * armNow[side] * q
			end
		end
		-- (after the animations step, and again just before every frame is drawn: nothing else gets
		-- the last word on your arms)
		table.insert(connections, RunService.Stepped:Connect(function(_, dt: number)
			poseArms(dt)
		end))
		table.insert(connections, RunService.RenderStepped:Connect(function()
			poseArms(0)
		end))
		-- Your own animations would keep putting your arms back down, so they pause for the film
		local animateScript = character:FindFirstChild("Animate")
		if animateScript and animateScript:IsA("BaseScript") then
			animate = animateScript
			pcall(function()
				animateWasEnabled = animateScript.Enabled
			end)
			animateScript.Enabled = false
		end
		pcall(function()
			local animator = humanoid:FindFirstChildOfClass("Animator")
			if animator then
				for _, track in animator:GetPlayingAnimationTracks() do
					track:Stop(0.15)
				end
			end
		end)

		-- Once the light pours out, the room slowly darkens round it (the light, the donut and you stay
		-- bright): less sun and sky light, darker shadows, a touch more contrast
		local DARK = rgb(16, 12, 22)
		local function dimRoom(dim: number)
			if dim <= 0 then
				return
			end
			if not grade then
				for _, key in { "Brightness", "Ambient", "OutdoorAmbient", "EnvironmentDiffuseScale", "EnvironmentSpecularScale" } do
					pcall(function()
						lightingBefore[key] = (Lighting :: any)[key]
					end)
				end
				local effect = Instance.new("ColorCorrectionEffect")
				effect.Name = "MythicOpeningGrade"
				effect.Parent = Lighting
				grade = effect
			end
			local want: { [string]: any } = {}
			if lightingBefore.Brightness then
				want.Brightness = lightingBefore.Brightness * (1 - 0.85 * dim)
			end
			if lightingBefore.Ambient then
				want.Ambient = (lightingBefore.Ambient :: Color3):Lerp(DARK, dim)
			end
			if lightingBefore.OutdoorAmbient then
				want.OutdoorAmbient = (lightingBefore.OutdoorAmbient :: Color3):Lerp(DARK, dim)
			end
			for _, key in { "EnvironmentDiffuseScale", "EnvironmentSpecularScale" } do
				if lightingBefore[key] then
					want[key] = lightingBefore[key] * (1 - 0.8 * dim)
				end
			end
			for key, value in want do
				pcall(function()
					(Lighting :: any)[key] = value
					lightingSet[key] = (Lighting :: any)[key]
				end)
			end
			local effect = grade :: ColorCorrectionEffect
			effect.Contrast = 0.18 * dim
			effect.Saturation = 0.1 * dim
		end
		-- (in your body's own space: X turns an arm up in front of you, Z swings it in towards your middle)
		local function arm(side: string, forward: number, inward: number)
			armGoal[side] = CFrame.Angles(math.rad(forward), 0, math.rad(if side == "Left" then inward else -inward))
		end

		-- The box (the real Mythic one, with all its glow), in the baker's hands
		local box = BoxModel.Build("Mythic", "Small", { Scale = BOX_SCALE })
		anchorAll(box)
		box.Parent = scene
		local boxPivot = box:GetPivot()
		local lidParts: { BasePart } = {}
		local lidOffsets: { CFrame } = {}
		for _, part in box:GetDescendants() do
			if part:IsA("BasePart") then
				local start = string.sub(part.Name, 1, 3)
				if start == "Lid" or start == "Bow" then
					table.insert(lidParts, part)
					table.insert(lidOffsets, boxPivot:ToObjectSpace(part.CFrame))
				end
			end
		end
		local top = (box:GetAttribute("Top") :: number?) or 2
		local _, extents = box:GetBoundingBox()
		local lidGone = false

		-- The light inside, a pillar of light and sparkles (made when it opens)
		local glow: BasePart? = nil
		local light: PointLight? = nil
		local pillar: Beam? = nil
		local sparkles: ParticleEmitter? = nil
		local held: Model? = nil
		local heldScale = 1
		local heldGlow: BasePart? = nil

		local bakerHead = baker and baker.Puppet.Model:FindFirstChild("Head") :: BasePart?
		local speech: BillboardGui? = nil
		local function bakerHands(): CFrame?
			if not baker then
				return nil
			end
			local pz = baker.Puppet
			local l, r = Puppet.Find(pz, "Hand", "Left Arm"), Puppet.Find(pz, "Hand", "Right Arm")
			if not (l and r) then
				return nil
			end
			local body = (pz.Pose or bakerSpot).Rotation
			local middle = pz.Parts[l].CFrame.Position:Lerp(pz.Parts[r].CFrame.Position, 0.5)
			return CFrame.new(middle) * body * CFrame.new(0, -0.9, -0.3 * BAKER_S)
		end
		-- Where the box sits in your hands: at their height, but always fully in front of your body
		-- (its back edge a little past your chest - real avatars are thick, and hands held out
		-- aren't far enough forward for a box this deep)
		local torso = (character :: Model):FindFirstChild("UpperTorso") or (character :: Model):FindFirstChild("Torso")
		local chest = (if torso and torso:IsA("BasePart") then torso.Size.Z / 2 else 0.5) + 0.45
		local hold = chest + extents.Z / 2
		local function yourHands(): CFrame
			local l, r = handOf(character :: Model, "Left", stand.Position), handOf(character :: Model, "Right", stand.Position)
			local height = if l and r then stand:PointToObjectSpace(l:Lerp(r, 0.5)).Y else 0
			return stand * CFrame.new(0, height - 0.55, -hold) * CFrame.Angles(0, math.pi, 0)
		end

		local t = 0
		local fired: { [string]: boolean } = {}
		local function once(name: string, at: number): boolean
			if t >= at and not fired[name] then
				fired[name] = true
				return true
			end
			return false
		end
		local boxFrom: CFrame? = nil
		local boxHeld: CFrame? = nil -- (where it stays once it's in your hands)

		local function update(dt: number)
			t += dt
			local cover = smooth(t / 0.5) * (1 - smooth((t - T.End + 0.4) / 0.4))
			for _, bar in screen.Bars do
				bar.Size = UDim2.fromScale(1, 0.1 * cover)
			end
			for _, edge in screen.Edges do
				edge.BackgroundTransparency = 1 - 0.75 * cover
			end
			-- fading in from black at the start; a white flash as the donut comes up (the cut to it);
			-- out to white at the end
			if t < 0.6 then
				screen.Fade.BackgroundColor3 = rgb(0, 0, 0)
				screen.Fade.BackgroundTransparency = smooth(t / 0.5)
			elseif t >= T.Fade then
				screen.Fade.BackgroundColor3 = WHITE
				local u = (t - T.Fade) / (T.End - T.Fade)
				screen.Fade.BackgroundTransparency = if u < 0.45 then 1 - smooth(u / 0.45) else smooth((u - 0.55) / 0.45)
			elseif t >= T.Raise and t < T.Raise + 0.35 then
				screen.Fade.BackgroundColor3 = WHITE
				screen.Fade.BackgroundTransparency = 0.2 + 0.8 * smooth((t - T.Raise) / 0.35)
			else
				screen.Fade.BackgroundTransparency = 1
			end

			dimRoom(smooth((t - T.Light) / 2.5))

			-- The baker: holding the box out, then letting go and clasping his hands, beaming
			if baker then
				local joints: { [string]: CFrame } = {}
				local state = "Offer"
				if t < T.Take + 0.15 then
					-- (low, down to your hands)
					joints["Left Arm"] = CFrame.Angles(math.rad(-50), 0, math.rad(-6))
					joints["Right Arm"] = CFrame.Angles(math.rad(-50), 0, math.rad(6))
					joints.Head = CFrame.Angles(math.rad(-14), 0, 0)
				else
					-- (a step back to watch, hands clasped)
					state = "Proud"
					joints["Left Arm"] = CFrame.Angles(math.rad(-28), 0, math.rad(24))
					joints["Right Arm"] = CFrame.Angles(math.rad(-28), 0, math.rad(-24))
					joints.Head = CFrame.Angles(math.rad(-12) + math.sin(t * 3) * 0.04, 0, 0)
				end
				local back = 1.4 * smooth((t - T.Take - 0.1) / 0.7)
				Puppet.Animate(baker.Anim, dt, bakerSpot * CFrame.new(0, math.sin(t * 2.2) * 0.04, back), joints, state, 0.35)
			end
			if once("Ask", T.Ask) and bakerHead then
				speech = bubble(bakerHead, "A MYTHIC box... just for you!")
			end
			if once("Hush", T.Swing) and speech then
				speech:Destroy()
			end

			-- Your arms: reaching for it, holding it, one hand into the box, then up high
			if t < T.Reach then
				arm("Left", 0, 0)
				arm("Right", 0, 0)
			elseif t < T.Dip then
				arm("Left", 70, 4)
				arm("Right", 70, 4)
			elseif t < T.Pull then
				arm("Left", 70, 4)
				arm("Right", 48, 22)
			elseif t < T.Raise then
				arm("Left", 70, 4)
				arm("Right", 105, 16)
			else
				arm("Left", 66, 4)
				arm("Right", 155, 8)
			end

			-- The box: in the baker's hands, across to yours, the lid opening
			if t < T.Take then
				local h = bakerHands() or (bakerSpot * CFrame.new(0, -1.5, -2.4))
				box:PivotTo(h)
				boxFrom = h
			elseif not boxHeld then
				local k = smooth((t - T.Take) / 0.6)
				local goal = yourHands()
				local from = boxFrom or goal
				local p = from.Position:Lerp(goal.Position, k) + Vector3.new(0, math.sin(k * math.pi) * 0.8, 0)
				box:PivotTo(CFrame.new(p) * from.Rotation:Lerp(goal.Rotation, k))
				if k >= 1 then
					boxHeld = goal
				end
			end
			-- the lid: rattles as the light pushes at it, then blows off in a burst of light and
			-- tumbles away to your right (away from the camera), out of the shot
			if t >= T.Open and not lidGone then
				local pivot = box:GetPivot()
				local middle = CFrame.new(0, top * 0.85, 0) -- (the lid turns round its own middle)
				local move: CFrame
				if t < T.Light then
					local r = (t - T.Open) / (T.Light - T.Open)
					move = CFrame.new(0, 0.12 * r + 0.08 * math.abs(math.sin(t * 40)) * r, 0) * middle * CFrame.Angles(math.sin(t * 53) * 0.07 * r, 0, math.sin(t * 61) * 0.07 * r) * middle:Inverse()
				else
					-- (the box faces you, so its -X is your right)
					local k = (t - T.Light) / 0.9
					move = CFrame.new(-6 * k, 6 * k - 3 * k * k, 0) * middle * CFrame.Angles(2.5 * k, 0, 4 * k) * middle:Inverse()
					if k >= 1 then
						lidGone = true
						for _, part in lidParts do
							part.Transparency = 1
						end
					end
				end
				for i, part in lidParts do
					part.CFrame = pivot * move * lidOffsets[i]
				end
			end
			if once("Crack", T.Open) then
				Theme.PlaySound("Crack")
			end
			-- the light pours out
			if once("Light", T.Light) then
				Theme.PlaySound("Hatch")
				local pivot = box:GetPivot()
				local g = Instance.new("Part")
				g.Name = "BoxLight"
				g.Anchored = true
				g.CanCollide = false
				g.CanQuery = false
				g.CanTouch = false
				g.CastShadow = false
				g.Material = Enum.Material.Neon
				g.Color = rgb(255, 245, 210)
				g.Size = Vector3.new(extents.X * 0.55, 0.1, extents.Z * 0.55)
				g.CFrame = pivot * CFrame.new(0, top * 0.62, 0)
				g.Parent = scene
				glow = g
				local l = Instance.new("PointLight")
				l.Color = rgb(255, 225, 170)
				l.Range = 18
				l.Brightness = 0
				l.Shadows = false
				l.Parent = g
				light = l
				local a0 = Instance.new("Attachment")
				a0.Parent = g
				local a1 = Instance.new("Attachment")
				a1.Position = Vector3.new(0, 10, 0) -- (up to the shop's roof)
				a1.Parent = g
				local beam = Instance.new("Beam")
				beam.Attachment0, beam.Attachment1 = a0, a1
				beam.Width0, beam.Width1 = extents.X * 0.5, extents.X * 1.3
				beam.FaceCamera = true
				beam.LightEmission = 1
				beam.LightInfluence = 0
				beam.Color = ColorSequence.new(rgb(255, 250, 225), rgb(255, 200, 120))
				beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.6, 0.7), NumberSequenceKeypoint.new(1, 1) })
				beam.Parent = g
				pillar = beam
				local e = Instance.new("ParticleEmitter")
				e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				e.Rate = 40
				e.Lifetime = NumberRange.new(0.8, 1.6)
				e.Speed = NumberRange.new(3, 7)
				e.SpreadAngle = Vector2.new(25, 25)
				e.EmissionDirection = Enum.NormalId.Top
				e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
				e.Color = ColorSequence.new(GOLD, CRIMSON)
				e.LightEmission = 1
				e.Parent = g
				sparkles = e
			end
			if glow then
				local pivot = box:GetPivot()
				glow.CFrame = pivot * CFrame.new(0, top * 0.62, 0)
				local k = smooth((t - T.Light) / 0.4)
				if light then
					light.Brightness = 9 * k * (1 + 0.08 * math.sin(t * 20))
					light.Range = 18 - 9 * smooth((t - T.Raise) / 1)
				end
			end
			-- the donut: comes up out of the light in your hand, held up high, turning
			if once("Donut", T.Dip + 0.35) then
				local d = DonutModel.Build(donut, { Scale = 0.6, Mutation = info.Mutation, Size = info.Size, Calm = true })
				anchorAll(d)
				d.Parent = scene
				held = d
				local ball = Instance.new("Part")
				ball.Name = "DonutGlow"
				ball.Shape = Enum.PartType.Ball
				ball.Anchored = true
				ball.CanCollide = false
				ball.CanQuery = false
				ball.CanTouch = false
				ball.CastShadow = false
				ball.Material = Enum.Material.Neon
				ball.Color = rgb(255, 235, 190)
				ball.Transparency = 1
				ball.Size = Vector3.one * 2.4
				ball.Parent = scene
				local warm = Instance.new("PointLight")
				warm.Name = "DonutLight"
				warm.Color = rgb(255, 220, 170)
				warm.Range = 9
				warm.Brightness = 0
				warm.Shadows = false
				warm.Parent = ball
				heldGlow = ball
			end
			if held then
				local hand = handOf(character :: Model, "Right", stand.Position) or (stand * CFrame.new(0, 2, -1.5)).Position
				-- (it grows out of the light: rescaled only while it grows)
				local size = math.max(0.05, smooth((t - T.Dip - 0.35) / 0.35))
				if size ~= heldScale then
					heldScale = size
					pcall(function()
						(held :: Model):ScaleTo(size)
					end)
				end
				-- (held up facing the camera - its face is its front - swaying a little)
				local spot = hand + Vector3.new(0, 1.5, 0)
				local hold = CFrame.lookAt(spot, camera.CFrame.Position) * CFrame.Angles(math.sin(t * 1.3) * 0.08, math.sin(t * 2) * 0.25, 0)
				held:PivotTo(hold)
				if heldGlow then
					heldGlow.CFrame = CFrame.new(spot)
					local shine = smooth((t - T.Pull) / 0.4)
					heldGlow.Transparency = 1 - 0.12 * shine * (1 - smooth((t - T.Title) / 0.8))
					local warm = heldGlow:FindFirstChildOfClass("PointLight")
					if warm then
						warm.Brightness = 3 * shine
					end
				end
			end
			-- the light fades once the donut's out
			if pillar and t > T.Raise then
				local k = 1 - smooth((t - T.Raise) / 0.8)
				pillar.Width0 = extents.X * 0.5 * k + 0.01
				if sparkles then
					sparkles.Rate = 40 * k
				end
			end
			-- its name
			if once("Title", T.Title) then
				screen.Title.Text = `{string.upper(rarity.Id)}!`
				screen.Title.Visible = true
				screen.Name.Visible = true
				screen.Name.Text = Rarities.DisplayName(donut.Name, info.Mutation, info.Size)
				screen.TitleScale.Scale = 2.4
				TweenService:Create(screen.TitleScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			end

			-- The camera, in your own space (+X your right, +Y up, +Z behind you): side on, the baker
			-- and you either side of the box (from the open floor by the bat rack), easing in; then
			-- craning up high in front of you, to your left, to look down into the box as it opens
			-- (your face lit by it, your head well off to the side of the box), tilting up after the
			-- donut as you lift it out; then - in a white flash - a cut to the front, low, looking up at
			-- the donut held high, slowly pushing in
			local function at(x: number, y: number, z: number): Vector3
				return (stand * CFrame.new(x, y, z)).Position
			end
			local boxAt = box:GetPivot().Position
			local inside = (box:GetPivot() * CFrame.new(0, top * 0.6, 0)).Position
			local you = at(0, 1.5, 0)
			local between = at(0, 1.4, -2.4)
			local eye: Vector3, look: Vector3
			if held and t >= T.Raise then
				local push = smooth((t - T.Raise) / 2.4)
				eye = at(6.2, 0.9, -5.2):Lerp(at(5.3, 1.2, -4.3), push)
				look = held:GetPivot().Position:Lerp(you, 0.3)
			elseif t < T.Swing then
				eye = at(-8, 2.2, -2.4):Lerp(at(-7.2, 2, -1.9), smooth(t / T.Swing))
				look = between:Lerp(boxAt, 0.3)
			else
				local crane = smooth((t - T.Swing) / (T.Open - T.Swing))
				eye = at(-7.2, 2, -1.9):Lerp(at(-4.6, 5.4, -3.4), crane)
				eye = eye:Lerp(at(-3.9, 4.7, -3), smooth((t - T.Open) / 1.4))
				look = between:Lerp(boxAt, 0.3):Lerp(inside, crane)
				if held then
					look = look:Lerp(held:GetPivot().Position, 0.6 * smooth((t - T.Pull) / 0.5))
				end
			end
			local shake = if t > T.Light and t < T.Light + 0.4 then (1 - (t - T.Light) / 0.4) * 0.15 else 0
			camera.CFrame = CFrame.lookAt(eye, look) * CFrame.Angles(math.sin(t * 47) * 0.02 * shake, math.cos(t * 41) * 0.02 * shake, 0)
			camera.FieldOfView = oldFov + (52 - oldFov) * smooth((t - T.Swing) / 1.2) + 4 * smooth((t - T.Pull) / 1.1)
			if t >= T.End then
				finish()
			end
		end

		screen.Skip.Activated:Connect(function()
			finish()
		end)
		table.insert(connections, RunService.RenderStepped:Connect(function(dt: number)
			local ok, err = pcall(function()
				update(math.min(dt, 0.1))
			end)
			if not ok then
				warn("[MythicOpening] broke: " .. tostring(err))
				finish()
			end
		end))
		-- (and never longer than it should be)
		task.delay(T.End + 6, function()
			finish()
		end)
	end)
	if not started then
		warn("[MythicOpening] couldn't start: " .. tostring(problem))
		finish()
		return false
	end
	return true
end

-- The admin panel's test: a random rare donut, nothing given
function MythicOpening.Preview(): boolean
	local pool = {}
	for _, d in Donuts.List do
		local rarity = Rarities.Get(d.Rarity)
		if rarity.Order >= 5 and not rarity.AdminOnly then
			table.insert(pool, d)
		end
	end
	local pick = pool[math.random(1, math.max(1, #pool))] or Donuts.List[1]
	return MythicOpening.Play({ DonutId = pick.Id, Mutation = "Mythic", Size = nil })
end

return MythicOpening
