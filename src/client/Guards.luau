--[[
	Guards (client side)
	====================
	* Builds YOUR sleeping Domer in every biome's back corner (only you can see him; everyone has
	  their own): in the first biomes he's asleep on his back on his couch (GuardModel.Sleep), later
	  on he sleeps standing up with his head down (GuardModel.Doze). Eyes shut; every breath out puffs
	  a few Z's out of his open mouth, and up close you hear him snore: Config.Guard.SnoreSoundId
	  while you're close enough to grab one of his boxes (their prompts' reach), louder the closer
	  you get to him - or, with no snore pasted there, a deep rattling breath in and a soft breath
	  out made from Roblox's own sounds, whenever you're near him.
	* The moment he wakes up to chase you, he lets out an angry grunt (Config.Guard.GruntSoundId).
	* When you steal a box the server spawns your chasing guard: your sleeping one disappears in a
	  puff of smoke, and lies back down once the chasing one has walked back to his corner. His
	  animations are preloaded at the start, so he never freezes the first time he wakes up.
	* Other players' chasing guards are hidden, so you never see anyone else's Domers.
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
local Layout = require(Shared.Layout)

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
}

local SNORE_RANGE = 85 -- studs: how far away you can hear him (the built-in snore)
local CUSTOM_SNORE = Config.Guard.SnoreSoundId ~= ""
-- (the pasted snore: SnoreVolume within SNORE_NEAR studs of him, down to a third of it at
-- SNORE_FAR - about as far as you can be from him and still reach one of his boxes)
local SNORE_NEAR = 16
local SNORE_FAR = Layout.BoxRadius + 22
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
local function makeSnore(mouth: BasePart?): Sound?
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
	sound.Parent = mouth
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
	return Config.Guard.SnoreVolume * (1 - t * 2 / 3)
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

-- The angry grunt when he wakes up: a deep, growly "HUUGH!" with a heavy thump.
local function grunt(part: BasePart)
	local custom = Config.Guard.GruntSoundId
	type Layer = { Id: string, Speed: number, Volume: number, Growl: boolean }
	local layers: { Layer } = if custom ~= ""
		then { { Id = custom, Speed = 1, Volume = 1, Growl = false } }
		else {
			{ Id = "rbxasset://sounds/uuhhh.mp3", Speed = 0.5, Volume = 1.3, Growl = true },
			{ Id = "rbxasset://sounds/action_jump_land.mp3", Speed = 0.4, Volume = 0.8, Growl = false },
		}
	for _, layer in layers do
		local sound = Instance.new("Sound")
		sound.Name = "Grunt"
		sound.SoundId = layer.Id
		sound.PlaybackSpeed = layer.Speed
		sound.Volume = layer.Volume
		sound.RollOffMinDistance = 30
		sound.RollOffMaxDistance = 300
		if layer.Growl then
			local growl = Instance.new("DistortionSoundEffect")
			growl.Level = 0.35
			growl.Parent = sound
			local eq = Instance.new("EqualizerSoundEffect")
			eq.LowGain = 4
			eq.HighGain = -8
			eq.Parent = sound
		end
		sound.Parent = part
		sound:Play()
		task.delay(4, function()
			sound:Destroy()
		end)
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
	-- On his couch: asleep on his back, eyes shut, mouth open. Later biomes: asleep on his feet,
	-- head down. (Both anchor every part.)
	local onCouch = marker:GetAttribute("Couch") == true
	local mouth = if onCouch then GuardModel.Sleep(model) else GuardModel.Doze(model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	status.Text = "" -- (the Z's come out of his mouth)
	local facing = marker.CFrame.LookVector * Vector3.new(1, 0, 1)
	local floor = marker.CFrame.Position * Vector3.new(1, 0, 1)
	local home = CFrame.lookAt(floor, floor + (if facing.Magnitude > 0.01 then facing.Unit else Vector3.new(0, 0, -1)))
	model:PivotTo(if onCouch then GuardModel.CouchCFrame(home) else GuardModel.StandCFrame(home))
	model.Parent = folder
	sleepers[areaId] = {
		Model = model,
		Status = status,
		Home = home,
		Hidden = false,
		Mouth = mouth,
		Snore = makeSnore(mouth),
		Phase = math.random() * BREATH,
		BreathingOut = false,
		Snoring = false,
	}
end

--------------------------------------------------------------------------------
-- Chasing guards (server side): hide other players', swap ours with the sleeper
--------------------------------------------------------------------------------
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
	-- Woken up: an angry grunt
	task.spawn(function()
		local head = instance:WaitForChild("Head", 3)
		if head and head:IsA("BasePart") then
			grunt(head)
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
				if CUSTOM_SNORE then
					local fromYou = if at and not sleeper.Hidden then (sleeper.Home.Position - at).Magnitude else math.huge
					breathe(sleeper, now, distance < Z_RANGE, reach[areaId] == true and not sleeper.Hidden, snoreVolume(fromYou))
				else
					breathe(sleeper, now, distance < Z_RANGE, distance < SNORE_RANGE + 10, 0)
				end
			end
		end
	end)
end

return Guards
