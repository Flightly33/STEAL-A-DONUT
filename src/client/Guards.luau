--[[
	Guards (client side)
	====================
	* Builds YOUR sleeping Domer in every biome's back corner (only you can see him; everyone has
	  their own): in the first biomes he's asleep on his back on his couch (GuardModel.Sleep), later
	  on each biome has its own bed and pose (GuardNaps: a sleeping bag, a hot tub of caramel, a
	  hammock between candy canes, a gaming desk, floating in zero gravity...; his bed stays when
	  he gets up). The Glitch Zone's one jitters, the Black Hole's one drifts and turns. Eyes shut; every breath out puffs
	  a few Z's out of his open mouth, and up close you hear him snore: Config.Guard.SnoreSoundId
	  while you're close enough to grab one of his boxes (their prompts' reach), louder the closer
	  you get to him - or, with no snore pasted there, a deep rattling breath in and a soft breath
	  out made from Roblox's own sounds, whenever you're near him.
	* The moment he wakes up to chase you (silently: grabbing his box plays Config.Guard.GrabSounds),
	  a rainbow "!?" pops up over his head, glowing a little and turning round (Config.Guard.Alert)
	  for as long as he's after you (his model's "State": Waking or Chasing).
	* When you steal a box the server spawns your chasing guard: your sleeping one disappears in a
	  puff of smoke, and lies back down once the chasing one has walked back to his corner. His
	  animations are preloaded at the start, so he never freezes the first time he wakes up.
	* Other players' chasing guards are hidden, so you never see anyone else's Domers.
	* His anime effects (DomerFX): an impact frame and speed lines when he wakes, a power-up aura
	  while he chases you (crazier in the later biomes), twinkles round the last biomes' sleepers.
]]

local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local Config = require(Shared.Config)
local GuardModel = require(Shared.GuardModel)
local GuardNaps = require(Shared.GuardNaps)
local Layout = require(Shared.Layout)

local DomerFX = require(script.Parent.DomerFX)

local player = Players.LocalPlayer :: Player

local Guards = {}

type Sleeper = {
	Model: Model,
	Status: TextLabel,
	Home: CFrame,
	Hidden: boolean,
	Mouth: BasePart?,
	Snore: Sound?,
	Phase: number,
	BreathingOut: boolean,
	Snoring: boolean,
	Motion: string?, -- GuardNaps' NapMotion: "Jitter" (Glitch Zone) or "Drift" (The Black Hole)
	Rest: CFrame, -- where he lies (his pivot), for the motions
	NextJitter: number,
}

local SNORE_RANGE = 85 -- studs: how far away you can hear him (the built-in snore)
local CUSTOM_SNORE = Config.Guard.SnoreSoundId ~= ""
-- (the pasted snore: SnoreVolume within SNORE_NEAR studs of him, down to a third of it at
-- SNORE_FAR - about as far as you can be from him and still reach one of his boxes)
local SNORE_NEAR = 16
local SNORE_FAR = Layout.BoxRadius + 22
-- ...and it carries further than that, fading out by SNORE_HEAR (you, or your camera, that close)
local SNORE_HEAR = Layout.BoxRadius + 55
local Z_RANGE = 240 -- ...and see his Z's
local BREATH = 3.8 -- seconds per breath (in 1.7 s, out 1.3 s, then a pause)
local BREATH_IN = 1.7
local BREATH_OUT = 1.3

local sleepers: { [number]: Sleeper } = {}
local folder: Folder

--------------------------------------------------------------------------------
-- Poof
--------------------------------------------------------------------------------
function Guards.Poof(position: Vector3, color: Color3?)
	local part = Instance.new("Part")
	part.Name = "Poof"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(4, 6, 4)
	part.CFrame = CFrame.new(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color or Color3.fromRGB(255, 255, 255))
	emitter.LightEmission = 0.3
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(6, 12)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 5
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 3.5) })
	emitter.Transparency = NumberSequence.new(0.2, 1)
	emitter.Rate = 0
	emitter.Parent = part
	part.Parent = folder
	emitter:Emit(28)
	task.delay(1.5, function()
		part:Destroy()
	end)
end

--------------------------------------------------------------------------------
-- Sleeping guards (local only)
--------------------------------------------------------------------------------
local function setHidden(sleeper: Sleeper, hidden: boolean)
	if sleeper.Hidden == hidden then
		return
	end
	sleeper.Hidden = hidden
	sleeper.Model.Parent = if hidden then nil else folder
	Guards.Poof(sleeper.Home.Position + Vector3.new(0, 2, 0))
end

-- His snore: a slowed-down rumble with a fast flutter on it (the rattle), fading in and out with
-- every breath (see breathe). A pasted Creator Store snore plays as it is instead.
local function makeSnore(mouth: BasePart?, model: Model): Sound?
	if not mouth then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "Snore"
	sound.SoundId = if CUSTOM_SNORE then Config.Guard.SnoreSoundId else "rbxasset://sounds/action_falling.mp3"
	sound.Looped = true
	sound.Volume = 0
	if CUSTOM_SNORE then
		-- (it comes from his mouth, but how loud it is is up to breathe: no fading with distance here)
		sound.RollOffMode = Enum.RollOffMode.Linear
		sound.RollOffMinDistance = 300
		sound.RollOffMaxDistance = 400
	else
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = 15
		sound.RollOffMaxDistance = SNORE_RANGE
	end
	if not CUSTOM_SNORE then
		local rattle = Instance.new("TremoloSoundEffect")
		rattle.Frequency = 22
		rattle.Depth = 0.85
		rattle.Duty = 0.5
		rattle.Parent = sound
		local eq = Instance.new("EqualizerSoundEffect")
		eq.LowGain = 5
		eq.MidGain = -3
		eq.HighGain = -16
		eq.Parent = sound
	end
	-- A pasted snore isn't placed in the world (its loudness is worked out from how far you are):
	-- placed in his mouth it went silent with you or your camera right up against (or inside) him.
	sound.Parent = if CUSTOM_SNORE then model else mouth
	return sound
end

-- A few Z's puff out of his mouth and float up, growing and fading.
local function puffZs(sleeper: Sleeper)
	local mouth = sleeper.Mouth
	if not mouth then
		return
	end
	local scale = Config.Guard.Scale
	local drift = (if math.random() < 0.5 then -1 else 1) * scale * 0.5
	for i = 1, 3 do
		task.delay((i - 1) * 0.45, function()
			if sleeper.Hidden or not mouth.Parent then
				return
			end
			local gui = Instance.new("BillboardGui")
			gui.Name = "Z"
			gui.Adornee = mouth
			gui.LightInfluence = 0
			gui.MaxDistance = Z_RANGE
			local start = (1 + i * 0.3) * scale -- (big enough to read from across the area)
			gui.Size = UDim2.fromScale(start, start)
			gui.StudsOffsetWorldSpace = Vector3.new(0, 0.35 * scale, 0)
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Font = Enum.Font.LuckiestGuy
			label.Text = if i == 1 then "z" else "Z"
			label.TextScaled = true
			label.TextColor3 = Color3.fromRGB(235, 245, 255)
			label.TextStrokeTransparency = 1
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(50, 70, 140)
			stroke.Thickness = 3
			stroke.Parent = label
			label.Rotation = math.random(-18, 18)
			label.Parent = gui
			gui.Parent = sleeper.Model
			local size = start * 1.9
			TweenService:Create(gui, TweenInfo.new(2.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				StudsOffsetWorldSpace = Vector3.new(drift * (1.5 + i * 0.6), (3.2 + i * 0.9) * scale, 0),
				Size = UDim2.fromScale(size, size),
			}):Play()
			TweenService:Create(label, TweenInfo.new(1.1, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 1.5), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
				Rotation = label.Rotation + math.random(-25, 25),
			}):Play()
			TweenService:Create(stroke, TweenInfo.new(1.1, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 1.5), { Transparency = 1 }):Play()
			task.delay(2.7, function()
				gui:Destroy()
			end)
		end)
	end
end

-- How loud the pasted snore is `distance` studs from him.
local function snoreVolume(distance: number): number
	local t = math.clamp((distance - SNORE_NEAR) / (SNORE_FAR - SNORE_NEAR), 0, 1)
	local beyond = math.clamp((distance - SNORE_FAR) / (SNORE_HEAR - SNORE_FAR), 0, 1)
	return Config.Guard.SnoreVolume * (1 - t * 2 / 3) * (1 - beyond)
end

-- The biomes with a box you're close enough to grab right now (within its prompt's reach).
local function boxesInReach(at: Vector3?): { [number]: boolean }
	local areas = {}
	if not at then
		return areas
	end
	for _, box in CollectionService:GetTagged("LaneBox") do
		local primary = if box:IsA("Model") then box.PrimaryPart else nil
		local prompt = primary and primary:FindFirstChild("StealPrompt")
		if primary and prompt and prompt:IsA("ProximityPrompt") then
			local position = primary.CFrame.Position
			if (position - at).Magnitude <= prompt.MaxActivationDistance then
				areas[Layout.AreaAt(position)] = true
			end
		end
	end
	return areas
end

-- One step of his breathing (every few frames): the snore swells while he breathes in, a soft
-- whoosh and the Z's come out while he breathes out. (`loudness`: for a pasted snore.)
local function breathe(sleeper: Sleeper, now: number, seen: boolean, heard: boolean, loudness: number)
	local cycle = (now + sleeper.Phase) % BREATH
	local out = cycle >= BREATH_IN and cycle < BREATH_IN + BREATH_OUT
	if out and not sleeper.BreathingOut and seen then
		puffZs(sleeper)
	end
	sleeper.BreathingOut = out
	local sound = sleeper.Snore
	if not sound then
		return
	end
	if CUSTOM_SNORE then
		-- a real recording: it fades in when you get in reach of his boxes, swells as you get
		-- closer to him, and fades out (then stops) when you leave
		sound.Volume += ((if heard then loudness else 0) - sound.Volume) * 0.3
		if heard and not sleeper.Snoring then
			sleeper.Snoring = true
			sound:Play()
		elseif not heard and sleeper.Snoring and sound.Volume < 0.005 then
			sleeper.Snoring = false
			sound.Volume = 0
			sound:Stop()
		end
		return
	end
	if heard ~= sleeper.Snoring then
		sleeper.Snoring = heard
		if heard then
			sound:Play()
		else
			sound:Stop()
		end
	end
	if not heard then
		return
	end
	local rattle = sound:FindFirstChildOfClass("TremoloSoundEffect")
	if cycle < BREATH_IN then
		-- in: a deep rattling rumble that builds up, then stops short
		local a = cycle / BREATH_IN
		local fade = if a > 0.9 then (1 - a) / 0.1 else 1
		sound.Volume = 0.55 * math.sin(math.min(a * 1.2, 1) * math.pi * 0.5) * fade
		sound.PlaybackSpeed = 0.2 + 0.05 * a
		if rattle then
			rattle.Enabled = true
		end
	elseif out then
		-- out: a soft "pfff"
		local a = (cycle - BREATH_IN) / BREATH_OUT
		sound.Volume = 0.2 * math.sin(a * math.pi)
		sound.PlaybackSpeed = 0.45
		if rattle then
			rattle.Enabled = false
		end
	else
		sound.Volume = 0
	end
end

local function buildSleeper(areaId: number)
	local map = workspace:WaitForChild("Map")
	local lane = map:WaitForChild("Lane")
	local area = lane:WaitForChild("Area" .. areaId, 30)
	local marker = area and area:FindFirstChild("GuardHome", true)
	if not marker or not marker:IsA("BasePart") then
		return
	end
	local model, status = GuardModel.Build(areaId)
	-- On his couch: asleep on his back, eyes shut, mouth open. Later biomes: his biome's own bed
	-- and pose (GuardNaps), else asleep on his feet, head down. (All anchor every part.)
	local onCouch = marker:GetAttribute("Couch") == true
	local facing = marker.CFrame.LookVector * Vector3.new(1, 0, 1)
	local floor = marker.CFrame.Position * Vector3.new(1, 0, 1)
	local home = CFrame.lookAt(floor, floor + (if facing.Magnitude > 0.01 then facing.Unit else Vector3.new(0, 0, -1)))
	local mouth: BasePart? = nil
	if onCouch then
		mouth = GuardModel.Sleep(model)
		model:PivotTo(GuardModel.CouchCFrame(home))
	elseif GuardNaps.Has(areaId) then
		local props
		mouth, props = GuardNaps.Pose(model, areaId, home)
		if props then
			props.Name = "Bed" .. areaId
			props.Parent = folder
		end
	else
		mouth = GuardModel.Doze(model)
		model:PivotTo(GuardModel.StandCFrame(home))
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	status.Text = "" -- (the Z's come out of his mouth)
	DomerFX.Sleeper(model, areaId)
	model.Parent = folder
	local motion = model:GetAttribute("NapMotion")
	sleepers[areaId] = {
		Model = model,
		Status = status,
		Home = home,
		Hidden = false,
		Mouth = mouth,
		Snore = makeSnore(mouth, model),
		Phase = math.random() * BREATH,
		BreathingOut = false,
		Snoring = false,
		Motion = if type(motion) == "string" then motion else nil,
		Rest = model:GetPivot(),
		NextJitter = 0,
	}
end

-- The Glitch Zone's Domer glitches about (little jumps, now and then a big one, snapping back);
-- the Black Hole's one drifts up and down, slowly turning round.
local glitchRng = Random.new()
local function moveSleeper(sleeper: Sleeper, now: number)
	local motion = sleeper.Motion
	if motion == "Drift" then
		local rest = sleeper.Rest
		local bob = Vector3.new(0, math.sin(now * 0.7) * 0.35 * Config.Guard.Scale, 0)
		sleeper.Model:PivotTo(CFrame.new(rest.Position + bob) * CFrame.Angles(0, now * 0.18, math.sin(now * 0.5) * 0.08) * rest.Rotation)
	elseif motion == "Jitter" and now >= sleeper.NextJitter then
		local big = glitchRng:NextNumber() < 0.12
		local reach = (if big then 0.6 else 0.12) * Config.Guard.Scale
		local twist = if big then 0.25 else 0.05
		local offset = if glitchRng:NextNumber() < 0.45
			then CFrame.identity -- (snapped back)
			else CFrame.new(glitchRng:NextNumber(-reach, reach), glitchRng:NextNumber(-reach, reach) * 0.5, glitchRng:NextNumber(-reach, reach))
				* CFrame.Angles(glitchRng:NextNumber(-twist, twist), glitchRng:NextNumber(-twist, twist), glitchRng:NextNumber(-twist, twist))
		sleeper.Model:PivotTo(sleeper.Rest * offset)
		sleeper.NextJitter = now + (if big then 0.08 else glitchRng:NextNumber(0.12, 0.5))
	end
end

--------------------------------------------------------------------------------
-- Chasing guards (server side): hide other players', swap ours with the sleeper
--------------------------------------------------------------------------------
-- The "!?" over a chasing Domer's head: rainbow letters on both sides of a thin, invisible board
-- that turns round over his head. It pops in, and follows him until he gives up (then it's gone).
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 170, 40)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 240, 70)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(90, 235, 110)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(80, 170, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 100, 255)),
})
local function alertSign(model: Model, head: BasePart)
	local cfg = Config.Guard.Alert
	local size = cfg.Size
	local board = Instance.new("Part")
	board.Name = "GuardAlert"
	board.Anchored = true
	board.CanCollide = false
	board.CanQuery = false
	board.CanTouch = false
	board.CastShadow = false
	board.Transparency = 1
	board.Size = Vector3.new(size, size, 0.05)
	local gradients: { UIGradient } = {}
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local surface = Instance.new("SurfaceGui")
		surface.Name = face.Name
		surface.Face = face
		surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		surface.CanvasSize = Vector2.new(200, 200)
		surface.LightInfluence = 0
		surface.Brightness = cfg.Glow -- (a little brighter than flat: the bloom gives it a soft glow)
		surface.AlwaysOnTop = false
		surface.Parent = board
		local text = Instance.new("TextLabel")
		text.Name = "Text"
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.LuckiestGuy
		text.Text = cfg.Text
		text.TextScaled = true
		text.TextColor3 = Color3.new(1, 1, 1)
		text.Parent = surface
		local gradient = Instance.new("UIGradient")
		gradient.Color = RAINBOW
		gradient.Rotation = 90
		gradient.Parent = text
		table.insert(gradients, gradient)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 5
		stroke.Color = Color3.fromRGB(30, 10, 50)
		stroke.Parent = text
	end
	board.Parent = folder
	local started = os.clock()
	local connection: RBXScriptConnection
	local function remove()
		connection:Disconnect()
		board:Destroy()
	end
	connection = RunService.RenderStepped:Connect(function()
		local ok, state = pcall(model.GetAttribute, model, "State") -- (he may be gone)
		if not ok or not model.Parent or not head.Parent or (state ~= "Waking" and state ~= "Chasing") then
			remove()
			return
		end
		local t = os.clock() - started
		-- it pops in (a little overshoot), then turns round and bobs
		local grow = math.min(1, t / 0.3)
		local pop = if grow < 1 then grow * (1 + 0.35 * math.sin(grow * math.pi)) else 1
		board.Size = Vector3.new(size * pop, size * pop, 0.05)
		local spin = t * cfg.Spin * math.pi * 2
		local above = head.CFrame.Position + Vector3.new(0, 2.4 * Config.Guard.Scale + size * 0.75 + math.sin(t * 3) * 0.3, 0)
		board.CFrame = CFrame.new(above) * CFrame.Angles(0, spin, 0)
		-- the rainbow runs slowly up through the letters
		for _, gradient in gradients do
			gradient.Offset = Vector2.new(0, (t * 0.4) % 1 - 0.5)
		end
	end)
	return board
end

-- Waking up, on your screen only: he sits up, springs to his feet throwing his arms up, then
-- stomps and shakes his head, fists out, steaming. It's quick (Guards.WakeTime) and fits inside
-- his wake delay, so it never changes your head start: the server starts the chase at exactly
-- the same moment either way. Poses are angles in degrees for his R6 joints: Root/Neck pitch
-- (+ = forward), arms and legs forward (+), arms out to the side (Out).
Guards.WakeTime = 0.85
type WakeKey = { T: number, Root: number, Neck: number, Arms: number, Out: number, RightLeg: number, LeftLeg: number }
local WAKE_KEYS: { WakeKey } = {
	{ T = 0, Root = -45, Neck = -20, Arms = -35, Out = 5, RightLeg = 75, LeftLeg = 75 }, -- sitting up
	{ T = 0.22, Root = -10, Neck = -15, Arms = 150, Out = 15, RightLeg = 10, LeftLeg = 10 }, -- springing up
	{ T = 0.38, Root = -6, Neck = -20, Arms = 170, Out = 20, RightLeg = 0, LeftLeg = 0 }, -- arms in the air
	{ T = 0.52, Root = 16, Neck = 18, Arms = 25, Out = 38, RightLeg = 42, LeftLeg = 0 }, -- fists out, foot up
	{ T = 0.62, Root = 20, Neck = 18, Arms = 15, Out = 40, RightLeg = -4, LeftLeg = 0 }, -- STOMP
	{ T = 0.85, Root = 12, Neck = 12, Arms = 10, Out = 32, RightLeg = 0, LeftLeg = 0 },
}

-- His pose `t` seconds into waking up (joint name -> Motor6D.Transform).
function Guards.WakePose(t: number): { [string]: CFrame }
	local a, b = WAKE_KEYS[1], WAKE_KEYS[#WAKE_KEYS]
	for i = 1, #WAKE_KEYS - 1 do
		if t >= WAKE_KEYS[i].T and t <= WAKE_KEYS[i + 1].T then
			a, b = WAKE_KEYS[i], WAKE_KEYS[i + 1]
			break
		end
	end
	local span = math.max(b.T - a.T, 1e-3)
	local k = math.clamp((t - a.T) / span, 0, 1)
	k = k * k * (3 - 2 * k)
	local function mix(key: string): number
		return math.rad((a :: any)[key] + ((b :: any)[key] - (a :: any)[key]) * k)
	end
	-- (shaking his head, furious, once he's up)
	local shake = if t > 0.45 then math.rad(22) * math.sin(t * 38) * math.clamp((Guards.WakeTime - t) / 0.2, 0, 1) else 0
	local out = mix("Out")
	return {
		RootJoint = CFrame.Angles(mix("Root"), 0, 0),
		Neck = CFrame.Angles(mix("Neck"), 0, shake),
		["Right Shoulder"] = CFrame.Angles(-out, 0, mix("Arms")),
		["Left Shoulder"] = CFrame.Angles(-out, 0, -mix("Arms")),
		["Right Hip"] = CFrame.Angles(0, 0, mix("RightLeg")),
		["Left Hip"] = CFrame.Angles(0, 0, -mix("LeftLeg")),
	}
end

local function steamPuff(head: BasePart)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "AngrySteam"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 120, 110), Color3.fromRGB(255, 235, 230))
	emitter.LightEmission = 0.2
	emitter.Lifetime = NumberRange.new(0.4, 0.7)
	emitter.Speed = NumberRange.new(10, 18)
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Drag = 4
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3) })
	emitter.Transparency = NumberSequence.new(0.15, 1)
	emitter.Rate = 0
	emitter.Parent = head
	emitter:Emit(18)
	task.delay(1.2, function()
		emitter:Destroy()
	end)
end

function Guards.WakeUp(model: Model)
	local motors: { [string]: Motor6D } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			motors[d.Name] = d
		end
	end
	if not motors.RootJoint then
		return
	end
	local head = model:FindFirstChild("Head")
	local started = os.clock()
	local stomped = false
	local connections: { RBXScriptConnection } = {}
	local function pose()
		local t = os.clock() - started
		local ok, state = pcall(model.GetAttribute, model, "State")
		if t > Guards.WakeTime or not ok or not model.Parent or state ~= "Waking" then
			for _, connection in connections do
				connection:Disconnect()
			end
			return
		end
		for name, transform in Guards.WakePose(t) do
			local motor = motors[name]
			if motor then
				motor.Transform = transform
			end
		end
		if not stomped and t >= 0.6 then
			stomped = true
			if head and head:IsA("BasePart") then
				steamPuff(head)
			end
			Guards.Poof(model:GetPivot().Position - Vector3.new(0, 2.5 * Config.Guard.Scale, 0), Color3.fromRGB(230, 210, 190))
		end
	end
	-- (after his animations step, and again right before each frame: our pose wins)
	table.insert(connections, RunService.Stepped:Connect(pose))
	table.insert(connections, RunService.RenderStepped:Connect(pose))
	pose()
end

local function hideForMe(model: Instance)
	local function hide(d: Instance)
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 1
		elseif d:IsA("Decal") then
			d.LocalTransparencyModifier = 1
		elseif d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("Highlight") or d:IsA("Fire") or d:IsA("Sparkles") or d:IsA("Smoke") then
			(d :: any).Enabled = false
		elseif d:IsA("Sound") then
			d.Volume = 0
		end
	end
	for _, d in model:GetDescendants() do
		hide(d)
	end
	model.DescendantAdded:Connect(hide)
end

local function onGuardAdded(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local owner = instance:GetAttribute("OwnerUserId")
	if owner ~= player.UserId then
		hideForMe(instance)
		return
	end
	local areaId = instance:GetAttribute("Area")
	local sleeper = if type(areaId) == "number" then sleepers[areaId] else nil
	if sleeper then
		setHidden(sleeper, true)
		if sleeper.Snore then
			sleeper.Snore:Stop()
			sleeper.Snoring = false
		end
	end
	-- Woken up: the "!?" over his head (again each time he's woken up while
	-- walking back: the server sets his State)
	task.spawn(function()
		local head = instance:WaitForChild("Head", 3)
		if head and head:IsA("BasePart") then
			local sign: BasePart? = nil
			local chase: DomerFX.Chase? = nil
			local waking = false
			local function update()
				local state = instance:GetAttribute("State")
				local alert = state == "Waking" or state == "Chasing"
				-- he gets up, furious (each time he's woken)
				if state == "Waking" and not waking then
					Guards.WakeUp(instance)
				end
				waking = state == "Waking"
				if alert and not (sign and sign.Parent) then
					sign = alertSign(instance, head)
				end
				-- his anime effects: the impact frame as he wakes, his aura while he's after you
				if alert and not (chase and chase.Active) and type(areaId) == "number" then
					DomerFX.Wake(instance, areaId)
					chase = DomerFX.Chase(instance, areaId)
				end
			end
			instance:GetAttributeChangedSignal("State"):Connect(update)
			update()
		end
	end)
	local lastPosition = instance:GetPivot().Position
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		if instance.Parent then
			lastPosition = instance:GetPivot().Position
		else
			connection:Disconnect()
			-- The chase is over and he walked back to his corner: he lies back down there. (A puff
			-- where he was too, if he didn't make it all the way.)
			if not sleeper or (lastPosition - sleeper.Home.Position).Magnitude > 20 then
				Guards.Poof(lastPosition + Vector3.new(0, 2, 0))
			end
			if sleeper then
				setHidden(sleeper, false)
			end
		end
	end)
end

function Guards.Init()
	-- Load his animations (and his snore) now, not the moment they're first needed
	task.spawn(function()
		local list: { Instance } = {}
		for _, id in { Config.Guard.WalkAnimation, Config.Guard.IdleAnimation } do
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			table.insert(list, animation)
		end
		if CUSTOM_SNORE then
			local snore = Instance.new("Sound")
			snore.SoundId = Config.Guard.SnoreSoundId
			table.insert(list, snore)
		end
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
	end)

	folder = Instance.new("Folder")
	folder.Name = "MyGuards"
	folder.Parent = workspace

	task.spawn(function()
		for areaId = 1, #Areas.List do
			buildSleeper(areaId)
		end
	end)

	for _, instance in CollectionService:GetTagged("Guard") do
		task.spawn(onGuardAdded, instance)
	end
	CollectionService:GetInstanceAddedSignal("Guard"):Connect(onGuardAdded)

	-- Breathing: snoring and Z's for the sleepers near you
	task.spawn(function()
		local started = os.clock()
		local reach: { [number]: boolean } = {}
		local nextReach = 0
		while true do
			task.wait(0.05)
			local camera = workspace.CurrentCamera
			local eye = if camera then camera.CFrame.Position else Vector3.zero
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local at = if root then root.CFrame.Position else nil
			local now = os.clock() - started
			if CUSTOM_SNORE and now >= nextReach then
				nextReach = now + 0.2
				reach = boxesInReach(at)
			end
			for areaId, sleeper in sleepers do
				local distance = if sleeper.Hidden then math.huge else (sleeper.Home.Position - eye).Magnitude
				if sleeper.Motion and distance < Z_RANGE then
					moveSleeper(sleeper, now)
				end
				if CUSTOM_SNORE then
					-- heard near him (you or your camera, even right up against him) or near his boxes
					local fromYou = if at and not sleeper.Hidden then (sleeper.Home.Position - at).Magnitude else math.huge
					local closest = math.min(fromYou, distance)
					local near = closest < SNORE_HEAR or (reach[areaId] == true and not sleeper.Hidden)
					breathe(sleeper, now, distance < Z_RANGE, near, snoreVolume(math.min(closest, SNORE_FAR)))
				else
					breathe(sleeper, now, distance < Z_RANGE, distance < SNORE_RANGE + 10, 0)
				end
			end
		end
	end)
end

return Guards
