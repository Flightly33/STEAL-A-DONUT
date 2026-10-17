--[[
	MythicOpening: opening a MYTHIC donut box gets its own little film (instead of the box popping
	open in your pen), right where the box is, with black bars rolling in top and bottom:

	  0.0  high up in the sky, looking down on you and the box (the camera slowly turning)
	  2.2  cut: close up, at an angle just above you, looking at the box as it rattles and shakes
	  4.3  the camera pans round to you: you reach for the lid... it flies off and a bright light
	       and beams of light burst out of the box
	  6.0  the donut LEAPS out of the box - and you stumble back and land sitting on the ground
	  6.5  the camera pans round behind you: you sit there, propped up, looking at the open box with
	       the donut standing on top of it
	  7.7  its name pops onto the screen at an angle, shaking as the screen shakes
	  9.3  it fades out, and you're back where you were

	Sounds: Config.MythicOpening.Sounds. Your real character is used: moved next to the box (and
	back after), held still, and moving with hand-made moves keyframed in Blender - leaning in to
	watch, reaching, shielding your eyes, falling back, sitting (client/PlayerAnims: every joint, R6
	or R15). SKIP ends it any time; if anything breaks, it ends and puts everything back. The donut is already yours (the server gave it when the box
	opened): this is only the show.

	  MythicOpening.CanPlay()           not during another scene, the loading screen or a shot, or
	                                    while you're carrying something
	  MythicOpening.Play(info)          info: { DonutId, Mutation, Size, At? } (At: the box, on the
	                                    ground; without it the film plays right in front of you)
	  MythicOpening.Preview()           the admin panel's test: a random rare donut, nothing given
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local BoxModel = require(Shared.BoxModel)
local Donuts = require(Shared.Donuts)
local DonutModel = require(Shared.DonutModel)
local Rarities = require(Shared.Rarities)

local Cinematic = require(script.Parent.Cinematic)
local HideUI = require(script.Parent.UI.HideUI)
local PlayerAnims = require(script.Parent.PlayerAnims)
local Theme = require(script.Parent.UI.Theme)
local SkipButton = require(script.Parent.UI.SkipButton)
local Treadmill = require(script.Parent.Treadmill)

local MythicOpening = {}

local rgb = Color3.fromRGB
local WHITE = rgb(255, 255, 255)
local CRIMSON = rgb(255, 45, 85)
local GOLD = rgb(255, 210, 90)
local BOX_SCALE = 0.8
local DONUT_SCALE = 0.85
local STAND_OFF = 4.8 -- studs between you and the box

-- When each thing happens (seconds)
local T = { Cut = 2.2, Pan = 4.3, Reach = 4.45, Open = 4.9, Launch = 6.0, Fall = 6.05, Behind = 6.5, Land = 7.0, Name = 7.7, Fade = 9.3, End = 10.0 }
MythicOpening.Times = T
MythicOpening.Sounds = {} :: { [string]: Sound } -- (the last film's sounds, by cue: for the tests)

local player = Players.LocalPlayer
local playing = false

export type Info = { DonutId: string, Mutation: string?, Size: string?, At: CFrame? }

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

function MythicOpening.CanPlay(): boolean
	if playing or not player then
		return false
	end
	if player:GetAttribute("Intro") or player:GetAttribute("FreeCam") or player:GetAttribute("LoadingScreen") or player:GetAttribute("CarryKind") ~= nil or Cinematic.IsPlaying() then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return root ~= nil and humanoid ~= nil
end

function MythicOpening.IsPlaying(): boolean
	return playing
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

-- The screen: black bars, a dark vignette all round, the fades, the name card, SKIP
type Screen = { Gui: ScreenGui, Bars: { Frame }, Edges: { Frame }, Fade: Frame, Card: Frame, CardScale: UIScale, Title: TextLabel, Name: TextLabel, Skip: GuiButton }
local CARD_TILT = -9 -- degrees: the name card sits at an angle
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
	for _, side in { { 0, 0, 0.25, 1, 0 }, { 1, 0, 0.25, 1, 180 }, { 0, 0, 1, 0.3, 90 }, { 0, 1, 1, 0.3, 270 } } do
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
	-- its name, on a card turned at an angle (it pops in, then shakes with the screen)
	local card = Instance.new("Frame")
	card.Name = "NameCard"
	card.BackgroundTransparency = 1
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.4)
	card.Size = UDim2.fromOffset(760, 160)
	card.Rotation = CARD_TILT
	card.Visible = false
	card.ZIndex = 5
	card.Parent = gui
	local cardScale = Instance.new("UIScale")
	cardScale.Parent = card
	local title = Theme.Label({ Name = "Title", Text = "MYTHIC!", TextColor3 = CRIMSON, Size = UDim2.new(1, 0, 0.5, 0), StrokeThickness = 6, Parent = card })
	title.ZIndex = 5
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, GOLD), ColorSequenceKeypoint.new(0.5, WHITE), ColorSequenceKeypoint.new(1, CRIMSON) })
	gradient.Rotation = 90
	gradient.Parent = title
	local name = Theme.Label({ Name = "DonutName", Text = "", TextColor3 = WHITE, Position = UDim2.fromScale(0, 0.52), Size = UDim2.new(1, 0, 0.42, 0), StrokeThickness = 4, Parent = card })
	name.ZIndex = 5
	-- (hidden until you click or tap: then it pops up on the bottom bar - UI/SkipButton)
	local skip = SkipButton.Attach(gui, function() end)
	return { Gui = gui, Bars = bars, Edges = edges, Fade = fade, Card = card, CardScale = cardScale, Title = title, Name = name, Skip = skip }
end

function MythicOpening.Play(info: Info): boolean
	if not MythicOpening.CanPlay() then
		return false
	end
	local donut = Donuts.ById[info.DonutId]
	local rarity = Rarities.Get(if donut then donut.Rarity else "Common")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local camera = workspace.CurrentCamera
	if not (donut and character and root and humanoid and camera) then
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
	local soundFolder = Instance.new("Folder")
	soundFolder.Name = "MythicOpeningSounds"
	local connections: { RBXScriptConnection } = {}
	local done = false
	-- (the room's light as it was, and what we last set it to: only our own changes are undone)
	local lightingBefore: { [string]: any } = {}
	local lightingSet: { [string]: any } = {}
	local grade: ColorCorrectionEffect? = nil
	table.clear(MythicOpening.Sounds)

	local function finish()
		if done then
			return
		end
		done = true
		for _, c in connections do
			c:Disconnect()
		end
		-- your own animations back (under the black screen)
		pcall(PlayerAnims.Stop, character :: Model, 0)
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
		pcall(function()
			soundFolder:Destroy()
		end)
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
		-- the room's light as it was (unless something else changed it since)
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
		soundFolder.Parent = SoundService
		-- (off the treadmill, or it would keep pulling you back onto its belt)
		Treadmill.Stop()
		local screen = buildScreen()
		HideUI.Set(true, true)
		camera.CameraType = Enum.CameraType.Scriptable
		setControls(false)

		-- Where it happens: the box on the ground (in your pen), you a few steps in front of it, facing
		-- it. (All while the screen is still black.)
		local here = root.CFrame
		local boxGround = info.At or (here * CFrame.new(0, -3, -STAND_OFF))
		local boxPos = boxGround.Position
		local away = Vector3.new(here.Position.X - boxPos.X, 0, here.Position.Z - boxPos.Z)
		if away.Magnitude < 0.5 then
			away = -boxGround.LookVector * Vector3.new(1, 0, 1)
		end
		away = if away.Magnitude > 1e-3 then away.Unit else Vector3.new(0, 0, 1)
		local hip = if humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight + root.Size.Y / 2 else 3
		local spot = boxPos + away * STAND_OFF
		-- (the floor under you; if it can't be found, the floor the box stands on)
		local ground = boxPos.Y
		pcall(function()
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { character, scene }
			local hit = workspace:Raycast(spot + Vector3.new(0, 6, 0), Vector3.new(0, -20, 0), params)
			if hit then
				ground = hit.Position.Y
			end
		end)
		local stand = CFrame.lookAt(Vector3.new(spot.X, ground + hip, spot.Z), Vector3.new(boxPos.X, ground + hip, boxPos.Z))
		-- sitting on the ground after the fall: further back, low (the Sit move leans you back on
		-- your hands)
		local sitHeight = if humanoid.RigType == Enum.HumanoidRigType.R15 then 1.05 else 1.45
		local sitFlat = stand * CFrame.new(0, sitHeight - hip, 2.2)
		root.Anchored = true
		root.CFrame = stand

		-- Your moves (client/PlayerAnims: keyframed in Blender, played on every joint)
		local function move(name: string, fade: number, after: string?)
			PlayerAnims.Play(character :: Model, name, { Fade = fade, Then = after })
		end
		-- (from the very start, under the black: your own animations would keep putting your arms down)
		move("Watch", 0.3)

		-- Sounds (Config.MythicOpening.Sounds)
		local cues = Config.MythicOpening.Sounds
		local function play(cue: string, def: { Id: string, Volume: number }, looped: boolean?): Sound
			local s = Instance.new("Sound")
			s.Name = cue
			s.SoundId = def.Id
			s.Volume = def.Volume
			s.Looped = looped == true
			s.Parent = soundFolder
			s:Play()
			MythicOpening.Sounds[cue] = s
			return s
		end
		local function fadeOut(s: Sound?, seconds: number)
			if s then
				TweenService:Create(s, TweenInfo.new(seconds), { Volume = 0 }):Play()
				task.delay(seconds, function()
					pcall(s.Stop, s)
				end)
			end
		end
		local background = play("Background", cues.Background, true)
		local intro = play("Intro", cues.Intro)
		local sky: Sound? = play("Sky", cues.Sky)
		local shake: Sound? = nil

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

		-- The box (the real Mythic one, with all its glow), on the ground in front of you
		local box = BoxModel.Build("Mythic", "Small", { Scale = BOX_SCALE })
		anchorAll(box)
		box.Parent = scene
		local boxRest = CFrame.lookAt(Vector3.new(boxPos.X, ground, boxPos.Z), Vector3.new(spot.X, ground, spot.Z))
		box:PivotTo(boxRest)
		local lidParts: { BasePart } = {}
		local lidOffsets: { CFrame } = {}
		for _, part in box:GetDescendants() do
			if part:IsA("BasePart") then
				local start = string.sub(part.Name, 1, 3)
				if start == "Lid" or start == "Bow" then
					table.insert(lidParts, part)
					table.insert(lidOffsets, boxRest:ToObjectSpace(part.CFrame))
				end
			end
		end
		local top = (box:GetAttribute("Top") :: number?) or 2
		local _, extents = box:GetBoundingBox()
		local lidGone = false

		-- The light inside, the beams of light, a pillar of light and sparkles (made when it opens)
		local glow: BasePart? = nil
		local light: PointLight? = nil
		local pillar: Beam? = nil
		local sparkles: ParticleEmitter? = nil
		local shafts: { BasePart } = {}
		local flying: Model? = nil
		local flyingScale = 1
		local donutBottom = 0

		local t = 0
		local fired: { [string]: boolean } = {}
		local function once(name: string, at: number): boolean
			if t >= at and not fired[name] then
				fired[name] = true
				return true
			end
			return false
		end

		local function update(dt: number)
			t += dt
			-- the black bars roll slowly in from the start (out again at the very end)
			local cover = smooth((t - 0.2) / 2.6) * (1 - smooth((t - T.End + 0.4) / 0.4))
			for _, bar in screen.Bars do
				bar.Size = UDim2.fromScale(1, 0.12 * cover)
			end
			for _, edge in screen.Edges do
				edge.BackgroundTransparency = 1 - 0.6 * cover
			end
			-- in from black at the start, out to black at the end
			if t < 0.6 then
				screen.Fade.BackgroundTransparency = smooth(t / 0.5)
			elseif t >= T.Fade then
				screen.Fade.BackgroundTransparency = 1 - smooth((t - T.Fade) / (T.End - T.Fade - 0.1))
			else
				screen.Fade.BackgroundTransparency = 1
			end

			-- Sounds on their cues
			if once("IntroFade", Config.MythicOpening.Sounds.Intro.Seconds) then
				fadeOut(intro, 0.8)
			end
			if once("SkyEnd", T.Cut) then
				fadeOut(sky, 0.15)
				sky = nil
				shake = play("Shake", cues.Shake)
				play("ShakeBeams", cues.Beams)
			end
			if once("ShakeEnd", T.Open) then
				fadeOut(shake, 0.3)
				play("Beams", cues.Beams)
			end
			if once("Launch", T.Launch) then
				for i, def in cues.Launch do
					play("Launch" .. i, def)
				end
			end
			if once("FallSound", T.Fall + 0.1) then
				play("Fall", cues.Fall)
			end
			if t >= T.Fade then
				background.Volume = cues.Background.Volume * (1 - smooth((t - T.Fade) / (T.End - T.Fade)))
			end

			dimRoom(smooth((t - T.Open) / 2.5))

			-- You: leaning in to watch it rattle, reaching for the lid, flinching from the light, then
			-- knocked back onto the ground as the donut leaps out, and sitting there, propped up on
			-- your hands
			if once("MoveReach", T.Reach) then
				move("Reach", 0.2)
			end
			if once("MoveShield", T.Open) then
				move("Shield", 0.12)
			end
			if once("MoveFall", T.Fall) then
				move("Fall", 0.08, "Sit")
			end
			local body = stand
			if t >= T.Fall then
				local k = smooth((t - T.Fall) / 0.5)
				local hop = math.sin(math.min(k, 1) * math.pi) * 0.9
				body = stand:Lerp(sitFlat, k) * CFrame.new(0, hop, 0)
			end
			root.CFrame = body

			-- The box: still... then rattling and hopping, harder and harder, until it's opened
			if t >= T.Cut and t < T.Open + 0.1 then
				local r = smooth((t - T.Cut) / (T.Open - T.Cut))
				local strength = 0.25 + 0.75 * r
				local hop = math.max(0, math.sin(t * 17)) * 0.18 * strength
				box:PivotTo(boxRest * CFrame.new(0, hop, 0) * CFrame.Angles(math.sin(t * 43) * 0.06 * strength, math.sin(t * 29) * 0.05 * strength, math.sin(t * 51) * 0.07 * strength))
			elseif t >= T.Open + 0.1 then
				box:PivotTo(boxRest)
			end
			-- the lid: rattles with the box, then flies up and off away from you, spinning
			if not lidGone then
				local pivot = box:GetPivot()
				local middle = CFrame.new(0, top * 0.85, 0)
				local move = CFrame.identity
				if t >= T.Open then
					local k = (t - T.Open) / 0.9
					-- (the box faces you: its +Z is away from you)
					move = CFrame.new(0, 9 * k - 4 * k * k, 5 * k) * middle * CFrame.Angles(3 * k, 0, 2 * k) * middle:Inverse()
					if k >= 1 then
						lidGone = true
						for _, part in lidParts do
							part.Transparency = 1
						end
					end
				elseif t >= T.Cut then
					local r = (t - T.Cut) / (T.Open - T.Cut)
					move = CFrame.new(0, 0.1 * math.abs(math.sin(t * 37)) * r, 0) * middle * CFrame.Angles(math.sin(t * 53) * 0.08 * r, 0, math.sin(t * 61) * 0.08 * r) * middle:Inverse()
				end
				for i, part in lidParts do
					part.CFrame = pivot * move * lidOffsets[i]
				end
			end
			-- the light and the beams of light burst out
			if once("Light", T.Open) then
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
				g.CFrame = boxRest * CFrame.new(0, top * 0.62, 0)
				g.Parent = scene
				glow = g
				local l = Instance.new("PointLight")
				l.Color = rgb(255, 225, 170)
				l.Range = 16
				l.Brightness = 0
				l.Shadows = false
				l.Parent = g
				light = l
				local a0 = Instance.new("Attachment")
				a0.Parent = g
				local a1 = Instance.new("Attachment")
				a1.Position = Vector3.new(0, 16, 0)
				a1.Parent = g
				local beam = Instance.new("Beam")
				beam.Attachment0, beam.Attachment1 = a0, a1
				beam.Width0, beam.Width1 = extents.X * 0.5, extents.X * 1.6
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
				e.Speed = NumberRange.new(3, 8)
				e.SpreadAngle = Vector2.new(30, 30)
				e.EmissionDirection = Enum.NormalId.Top
				e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
				e.Color = ColorSequence.new(GOLD, CRIMSON)
				e.LightEmission = 1
				e.Parent = g
				sparkles = e
				-- shafts of light fanning out of the box, turning slowly
				for i = 1, 7 do
					local shaft = Instance.new("Part")
					shaft.Name = "LightShaft"
					shaft.Anchored = true
					shaft.CanCollide = false
					shaft.CanQuery = false
					shaft.CanTouch = false
					shaft.CastShadow = false
					shaft.Material = Enum.Material.Neon
					shaft.Color = if i % 2 == 0 then rgb(255, 235, 170) else rgb(255, 250, 235)
					shaft.Transparency = 1
					shaft.Size = Vector3.new(0.35, 10 + (i % 3) * 3, 0.35)
					shaft.Parent = scene
					table.insert(shafts, shaft)
				end
			end
			if glow then
				local k = smooth((t - T.Open) / 0.35)
				local fadeAway = 1 - smooth((t - T.Behind) / 1.4) * 0.6
				if light then
					light.Brightness = 9 * k * fadeAway * (1 + 0.08 * math.sin(t * 20))
				end
				for i, shaft in shafts do
					local around = (i / #shafts) * math.pi * 2 + t * 0.6
					local lean = math.rad(20 + 10 * math.sin(i * 1.7))
					local length = shaft.Size.Y
					shaft.CFrame = boxRest * CFrame.new(0, top * 0.6, 0) * CFrame.Angles(0, around, 0) * CFrame.Angles(lean, 0, 0) * CFrame.new(0, length / 2, 0)
					shaft.Transparency = 1 - (0.55 + 0.15 * math.sin(t * 6 + i)) * k * fadeAway
				end
			end

			-- The donut: leaps out of the box, high up, spinning, and lands standing on top of it
			if once("Donut", T.Launch) then
				local d = DonutModel.Build(donut, { Scale = DONUT_SCALE, Mutation = info.Mutation, Size = info.Size, Calm = true })
				anchorAll(d)
				d.Parent = scene
				donutBottom = (d:GetAttribute("Bottom") :: number?) or 1.5
				flying = d
			end
			if flying then
				local u = math.clamp((t - T.Launch) / (T.Land - T.Launch), 0, 1)
				local grow = math.max(0.05, smooth((t - T.Launch) / 0.3))
				if grow ~= flyingScale then
					flyingScale = grow
					pcall(function()
						(flying :: Model):ScaleTo(grow)
					end)
				end
				local rest = boxRest * CFrame.new(0, top + donutBottom * grow, 0)
				local height = 10 * 4 * u * (1 - u)
				-- (a little bounce as it lands, then it breathes)
				local after = t - T.Land
				local bounce = if after > 0 then math.abs(math.sin(after * 9)) * 0.7 * math.exp(-after * 5) else 0
				local bob = if after > 0 then math.sin(after * 2.2) * 0.12 else 0
				local spin = if u < 1 then u * math.pi * 4 else 0
				local facing = CFrame.lookAt(rest.Position, Vector3.new(spot.X, rest.Position.Y, spot.Z))
				flying:PivotTo(facing * CFrame.new(0, height + bounce + bob, 0) * CFrame.Angles(0, spin, 0))
			end
			-- the light settles once the donut's out
			if pillar and t > T.Launch then
				local k = 1 - 0.7 * smooth((t - T.Launch) / 1.2)
				pillar.Width0 = extents.X * 0.5 * k + 0.01
				if sparkles then
					sparkles.Rate = 40 * k
				end
			end

			-- Its name pops onto the screen at an angle and shakes with the screen
			local shakeAmount = 0
			if once("Name", T.Name) then
				screen.Title.Text = `{string.upper(rarity.Id)}!`
				screen.Name.Text = Rarities.DisplayName(donut.Name, info.Mutation, info.Size)
				screen.Card.Visible = true
				screen.CardScale.Scale = 2.6
				TweenService:Create(screen.CardScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
				play("Name", cues.Name)
			end
			if t >= T.Name then
				shakeAmount = 0.15 + 0.85 * math.exp(-(t - T.Name) * 2.5)
				screen.Card.Position = UDim2.new(0.5, math.sin(t * 61) * 7 * shakeAmount, 0.4, math.cos(t * 53) * 6 * shakeAmount)
				screen.Card.Rotation = CARD_TILT + math.sin(t * 47) * 2.2 * shakeAmount
			end

			-- The camera, in your standing spot's space (+X your right, +Y up, +Z behind you; the box
			-- is ahead, at -Z): up in the sky turning slowly; cut to just above you at an angle on the
			-- rattling box; a pan round to your side as you open it (tilting up after the donut as it
			-- leaps); then a pan round behind you sitting on the ground, looking at the box and donut
			local function at(x: number, y: number, z: number): Vector3
				return (stand * CFrame.new(x, y, z)).Position
			end
			local boxTop = (boxRest * CFrame.new(0, top, 0)).Position
			local middle = at(0, -hip + 1, -STAND_OFF / 2)
			local eye: Vector3, look: Vector3
			local fov = 50
			if t < T.Cut then
				local turn = CFrame.Angles(0, t * 0.15, 0)
				local height = 72 - 8 * smooth(t / T.Cut)
				eye = middle + turn:VectorToWorldSpace(stand:VectorToWorldSpace(Vector3.new(9, 0, 16))) + Vector3.new(0, height, 0)
				look = middle
				fov = 45
			elseif t < T.Pan then
				local push = smooth((t - T.Cut) / (T.Pan - T.Cut))
				eye = at(3.4, 4.4, 3.2):Lerp(at(2.6, 3.7, 2.1), push)
				look = boxTop
				fov = 46
			else
				local side = at(-5.6, 2.8, -2.3)
				local opening = at(0, 0.6 - 0.4 * hip, -STAND_OFF * 0.55)
				local pan = smooth((t - T.Pan) / 0.9)
				eye = at(2.6, 3.7, 2.1):Lerp(side, pan)
				look = boxTop:Lerp(opening, pan)
				if flying then
					look = look:Lerp(flying:GetPivot().Position, 0.55 * smooth((t - T.Launch) / 0.3) * (1 - smooth((t - T.Behind) / 0.9)))
				end
				-- behind you, low over your shoulder, at the box with the donut on it
				local behind = smooth((t - T.Behind) / 1.2)
				if behind > 0 then
					local sitEye = (sitFlat * CFrame.new(1.7, 1.9, 4.6)).Position
					local onBox = if flying then flying:GetPivot().Position:Lerp(boxTop, 0.35) else boxTop
					eye = eye:Lerp(sitEye:Lerp((sitFlat * CFrame.new(1.3, 1.7, 3.6)).Position, smooth((t - T.Behind - 1.2) / 2.5)), behind)
					look = look:Lerp(onBox, behind)
				end
				fov = 48 + 6 * smooth((t - T.Behind) / 1.2)
			end
			-- the screen shakes: the box hopping, the light bursting out, the donut leaping, the name
			local jolt = shakeAmount * 0.6
			if t > T.Open and t < T.Open + 0.4 then
				jolt += (1 - (t - T.Open) / 0.4) * 0.5
			end
			if t > T.Launch and t < T.Launch + 0.5 then
				jolt += (1 - (t - T.Launch) / 0.5) * 0.6
			end
			camera.CFrame = CFrame.lookAt(eye, look) * CFrame.Angles(math.sin(t * 47) * 0.02 * jolt, math.cos(t * 41) * 0.02 * jolt, math.sin(t * 37) * 0.012 * jolt)
			camera.FieldOfView = fov
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
