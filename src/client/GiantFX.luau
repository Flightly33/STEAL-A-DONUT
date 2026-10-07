--[[
	GiantFX: draws the Cosmic Domer boss fight (shared/Giant, server/GiantService) on every client.

	The server only sets workspace attributes - GiantSite (the meteor's crater), GiantSince (when the
	black hole started tearing open) and GiantLeaveAt (when he started sinking back, at the end of
	the storm) - and fires one remote per attack ("GiantSlam", "GiantStarRain", "GiantBeam").
	Everything else happens here, on the server's clock, so everyone sees the same thing:

	  * the black hole tears open: spiral arms pour into it, its rings swirl, lightning crackles
	    off its torn edge
	  * he climbs out of it with his entrance sound (Sounds.Emerge), a shock wave (every screen shakes) and his title card
	    slams onto the screen; a boss bar at the top shows how long until he leaves
	  * all the time: his reactor pulses, his halo turns, moons circle his shoulders, asteroids his
	    waist, his cape sways, his crown of planets circles his head
	  * SLAM: his palm glows and a ball of energy grows round his fist as he lifts it; runes circle
	    the glowing target and a pillar of light marks it; the fist swings down trailing light
	    (the swing sound) and smashes the lane (the impact sound): a flash, shock waves, crystal
	    spikes bursting up, cracks, flying rock, a scorch mark, and every screen shakes
	  * STAR RAIN: both fists go up, the hole flares, and burning stars fly out of it onto glowing
	    circles round the crater
	  * EYE BEAM: his eyes blaze, a line glows on the lane, and two beams burn along it
	  * when the storm ends he sinks back into the hole and it closes
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Giant = require(Shared.Giant)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.UI.Theme)

local GiantFX = {}

local rgb = Color3.fromRGB
local TAU = math.pi * 2
local S = Giant.S
local CLOSE_TIME = 1.5 -- seconds: the hole closing after he's gone
local GIANT = Config.CosmicGiant
local WHITE = rgb(255, 255, 255)
-- (Roblox's own sounds for the parts that didn't come with one: nothing to upload)
local ROAR, THUD = "rbxasset://sounds/action_falling.mp3", "rbxasset://sounds/action_jump_land.mp3"

type Slam = { Hand: string, Target: Vector3, Start: number, Swung: boolean, Hit: boolean, Warning: Model?, Charge: BasePart?, Trail: Trail? }
type Star = { Target: Vector3, Land: number, Part: BasePart?, Warning: Model?, Landed: boolean }
type Rain = { Start: number, Stars: { Star }, Launched: boolean }
type Beam = { From: Vector3, To: Vector3, Start: number, Warning: Model?, Parts: { BasePart }, Fired: boolean, Laser: Sound?, LaserOn: boolean, NextScorch: number }
type Debris = { Part: BasePart, Velocity: Vector3, Spin: Vector3, Born: number, Life: number }
type Bolt = { Parts: { BasePart }, Born: number, Life: number }
type Spike = { Part: BasePart, Base: CFrame, Height: number, Born: number }

local folder: Folder
local soundFolder: Folder
local built: Giant.Built? = nil
local site: Vector3? = nil
local layout: Giant.Layout? = nil
local slams: { [string]: Slam } = {}
local rains: { Rain } = {}
local beams: { Beam } = {}
local debris: { Debris } = {}
local bolts: { Bolt } = {}
local spikes: { Spike } = {}
local sounds: { [string]: { Sound } } = {}
local kick, kickAt = 0, 0
local rumble = 0 -- a steady shake while a beam burns
local slowClock = 0
local nextBolt = 0
local roared = false
local rng = Random.new()
local bulkMove = false -- (workspace:BulkMoveTo works: much faster than moving 600 parts one by one)

-- the boss UI
local bossGui: ScreenGui? = nil
local bossBar: Frame? = nil
local bossFill: Frame? = nil
local bossTimer: TextLabel? = nil
local flash: Frame? = nil
local flashUntil, flashStrength = 0, 0
local grade: ColorCorrectionEffect? = nil
local flare = 0 -- how bright the hole is flaring (star rain)
local lastStarImpact = 0

-- his eyes: which way they look (Giant.IrisFrame), his lids (Giant.Lid) and brows (Giant.Brow)
local BLINK = 0.22 -- seconds
local look = Vector2.new(0, -0.6)
local lidClosed, browAnger = 0, 0
local nextBlink, blinkStart = 0, -10

-- Server time -> os.clock()
local function localTime(serverTime: number): number
	return os.clock() + (serverTime - workspace:GetServerTimeNow())
end

local function play(name: string, volume: number)
	local list = sounds[name]
	if list then
		for _, s in list do
			s.Volume = volume
			s.TimePosition = 0
			s:Play()
		end
	end
end

local function oneShot(id: string, volume: number, pitch: number)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = pitch
	s.Parent = soundFolder
	s:Play()
	task.delay(6, function()
		s:Destroy()
	end)
end

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Parent = parent or folder
	return p
end

local function disc(name: string, radius: number, at: Vector3, color: Color3, material: Enum.Material, transparency: number, parent: Instance?): Part
	local d = part(name, Vector3.new(0.3, radius * 2, radius * 2), CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2), color, material, parent)
	d.Shape = Enum.PartType.Cylinder
	d.Transparency = transparency
	return d
end

local function fadeAway(p: BasePart, duration: number, delay: number?)
	task.delay(delay or 0, function()
		if p.Parent then
			TweenService:Create(p, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
		end
	end)
	task.delay((delay or 0) + duration + 0.1, function()
		p:Destroy()
	end)
end

local function closeness(at: Vector3, range: number): number
	local camera = workspace.CurrentCamera
	if not camera then
		return 0
	end
	return math.clamp(1 - (camera.CFrame.Position - at).Magnitude / range, 0, 1)
end

local function shake(strength: number)
	local now = os.clock()
	local current = kick * math.max(0, 1 - (now - kickAt) / 1.6)
	kick = math.max(current, strength)
	kickAt = now
end

local function screenFlash(strength: number, color: Color3?)
	local f = flash
	if f then
		f.BackgroundColor3 = color or WHITE
	end
	flashStrength = math.max(flashStrength, strength)
	flashUntil = os.clock() + 0.5
end

local function ring(at: Vector3, radius: number, color: Color3, duration: number, height: number)
	local d = disc("Shockwave", radius * 0.12, at + Vector3.new(0, height, 0), color, Enum.Material.Neon, 0.15)
	TweenService:Create(d, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.3, radius * 2, radius * 2), Transparency = 1 }):Play()
	task.delay(duration + 0.1, function()
		d:Destroy()
	end)
end

-- A jagged bolt of lightning from `a` to `b` (fades fast).
local function bolt(a: Vector3, b: Vector3, width: number, color: Color3)
	local parts: { BasePart } = {}
	local points = { a }
	local steps = 7
	local dir = b - a
	local side = dir:Cross(Vector3.yAxis)
	side = if side.Magnitude > 1e-3 then side.Unit else Vector3.xAxis
	for i = 1, steps - 1 do
		table.insert(points, a + dir * (i / steps) + side * rng:NextNumber(-1, 1) * dir.Magnitude * 0.06 + Vector3.new(0, rng:NextNumber(-1, 1) * dir.Magnitude * 0.04, 0))
	end
	table.insert(points, b)
	for i = 1, #points - 1 do
		local p, q = points[i], points[i + 1]
		local length = (q - p).Magnitude
		table.insert(parts, part("Lightning", Vector3.new(width, width, length + width), CFrame.lookAt((p + q) / 2, q), color, Enum.Material.Neon))
		table.insert(parts, part("LightningCore", Vector3.new(width * 0.4, width * 0.4, length + width * 0.4), CFrame.lookAt((p + q) / 2, q), WHITE, Enum.Material.Neon))
	end
	table.insert(bolts, { Parts = parts, Born = os.clock(), Life = 0.35 })
end

-- Move many parts at once (one call), or one by one where that isn't available.
local function moveAll(parts: { BasePart }, frames: { CFrame })
	if bulkMove then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	else
		for i, p in parts do
			p.CFrame = frames[i]
		end
	end
end

--------------------------------------------------------------------------------
-- The boss UI: title card, boss bar, flashes
--------------------------------------------------------------------------------
local function buildBossUi()
	-- (the flash covers the whole screen; the bar sits under the event pill, below the top bar)
	local flashGui = Theme.ScreenGui("GiantFlash", 7)
	flashGui.IgnoreGuiInset = true
	local f = Theme.new("Frame", { Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = flashGui })
	flash = f
	local gui = Theme.ScreenGui("GiantBoss", 7)
	bossGui = gui
	local bar = Theme.new("Frame", {
		Name = "BossBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 50),
		Size = UDim2.fromOffset(470, 58),
		BackgroundColor3 = rgb(14, 8, 32),
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = gui,
	}, { Theme.Corner(14), Theme.Stroke(3, Giant.VIOLET) })
	Theme.AutoScale(bar)
	bossBar = bar
	Theme.Label({ Name = "BossName", Text = "☄️ COSMIC DOMER", TextColor3 = rgb(235, 210, 255), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.62, 0, 0, 24), Position = UDim2.fromOffset(14, 4), StrokeThickness = 2.5, Parent = bar })
	bossTimer = Theme.Label({ Name = "BossTimer", Text = "", Font = Theme.Font, TextColor3 = rgb(255, 230, 150), TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0.38, -14, 0, 20), Position = UDim2.new(0.62, 0, 0, 6), StrokeThickness = 1.8, Parent = bar })
	local back = Theme.new("Frame", { Name = "Track", BackgroundColor3 = rgb(40, 24, 70), Size = UDim2.new(1, -24, 0, 16), Position = UDim2.fromOffset(12, 33), Parent = bar }, { Theme.Corner(8), Theme.Stroke(2) })
	local fill = Theme.new("Frame", { Name = "Fill", BackgroundColor3 = WHITE, Size = UDim2.fromScale(1, 1), Parent = back }, { Theme.Corner(8) })
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Giant.CYAN), ColorSequenceKeypoint.new(0.5, Giant.VIOLET), ColorSequenceKeypoint.new(1, Giant.PINK) })
	gradient.Parent = fill
	bossFill = fill
end

-- "⚠ COSMIC DOMER ⚠ / RULER OF THE BLACK HOLE" slams onto the screen.
local function titleCard()
	local gui = bossGui
	if not gui then
		return
	end
	local card = Theme.new("Frame", { Name = "TitleCard", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(640, 150), BackgroundTransparency = 1, Parent = gui })
	local scale = Theme.new("UIScale", { Scale = 2.2, Parent = card })
	local title = Theme.Label({ Text = "⚠ COSMIC DOMER ⚠", TextColor3 = rgb(240, 215, 255), Size = UDim2.new(1, 0, 0, 84), StrokeThickness = 6, Parent = card })
	local sub = Theme.Label({ Text = "RULER OF THE BLACK HOLE", Font = Theme.Font, TextColor3 = Giant.CYAN, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 92), StrokeThickness = 3, Parent = card })
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Giant.PINK), ColorSequenceKeypoint.new(0.5, WHITE), ColorSequenceKeypoint.new(1, Giant.CYAN) })
	gradient.Parent = title
	TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(3.4, function()
		TweenService:Create(title, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		TweenService:Create(sub, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		task.wait(0.7)
		card:Destroy()
	end)
end

local function updateBossUi(now: number, out: number, leaving: boolean)
	local bar, fill, timer = bossBar, bossFill, bossTimer
	if not bar or not fill or not timer then
		return
	end
	bar.Visible = built ~= nil and out > 0.5 and not leaving
	if not bar.Visible then
		return
	end
	local endsAt = workspace:GetAttribute("EventEndsAt")
	local since = workspace:GetAttribute("GiantSince")
	if type(endsAt) == "number" and type(since) == "number" then
		local start = since + Giant.OPEN + Giant.RISE
		local left = math.max(0, endsAt - workspace:GetServerTimeNow())
		local total = math.max(1, endsAt - start)
		fill.Size = UDim2.fromScale(math.clamp(left / total, 0, 1), 1)
		timer.Text = string.format("leaves in %d:%02d", left // 60, math.floor(left % 60))
	else
		fill.Size = UDim2.fromScale(1, 1)
		timer.Text = ""
	end
end

--------------------------------------------------------------------------------
-- Building and placing him
--------------------------------------------------------------------------------
-- (the trail and its two attachments on the fist)
local function dropTrail(slam: Slam)
	local trail = slam.Trail
	if trail then
		for _, attachment in { trail.Attachment0, trail.Attachment1 } :: { Attachment? } do
			if attachment then
				attachment:Destroy()
			end
		end
		trail:Destroy()
		slam.Trail = nil
	end
end

local function clearAttacks()
	for _, slam in slams do
		dropTrail(slam)
		for _, item in { slam.Warning, slam.Charge } :: { Instance? } do
			if item then
				item:Destroy()
			end
		end
	end
	table.clear(slams)
	for _, rain in rains do
		for _, star in rain.Stars do
			for _, item in { star.Part, star.Warning } :: { Instance? } do
				if item then
					item:Destroy()
				end
			end
		end
	end
	table.clear(rains)
	for _, beam in beams do
		if beam.Warning then
			beam.Warning:Destroy()
		end
		for _, p in beam.Parts do
			p:Destroy()
		end
		if beam.Laser then
			beam.Laser:Destroy()
		end
	end
	table.clear(beams)
	rumble = 0
end

local function clear()
	if built then
		built.Model:Destroy()
	end
	clearAttacks()
	built, site, layout = nil, nil, nil
	roared = false
end

-- His glow: lights and drifting cosmic dust (made once, with him).
local function dressUp(giant: Giant.Built)
	local coreLight = Instance.new("PointLight")
	coreLight.Name = "CoreLight"
	coreLight.Color = Giant.PINK
	coreLight.Range = 60
	coreLight.Brightness = 4
	coreLight.Parent = giant.Core
	local dust = Instance.new("ParticleEmitter")
	dust.Name = "CosmicDust"
	dust.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	dust.Color = ColorSequence.new(Giant.CYAN, Giant.PINK)
	dust.LightEmission = 1
	dust.Rate = 18
	dust.Lifetime = NumberRange.new(2, 4)
	dust.Speed = NumberRange.new(8, 20)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Size = NumberSequence.new(3, 0)
	dust.Parent = giant.Core
	for _, iris in giant.Irises do
		local light = Instance.new("PointLight")
		light.Color = Giant.CYAN
		light.Range = 30
		light.Brightness = 3
		light.Parent = iris
	end
	local hole = giant.Model:FindFirstChild("HoleHaze")
	if hole and hole:IsA("BasePart") then
		local inflow = Instance.new("ParticleEmitter")
		inflow.Name = "Inflow"
		inflow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		inflow.Color = ColorSequence.new(rgb(255, 200, 255), Giant.VIOLET)
		inflow.LightEmission = 1
		inflow.Rate = 30
		inflow.Lifetime = NumberRange.new(1.5, 3)
		inflow.Speed = NumberRange.new(5, 12)
		inflow.Size = NumberSequence.new(4, 0)
		inflow.Parent = hole
	end
end

local function ensureBuilt(at: Vector3)
	if built and site == at then
		return
	end
	nextBlink = os.clock() + rng:NextNumber(2, 4) -- (not the moment he appears)
	if built then
		clear() -- (a different giant: forget the old one's attacks too)
	end
	-- (an attack can arrive before he's built - it's kept)
	built = Giant.Build()
	site = at
	layout = Giant.Layout(at)
	local giant = built :: Giant.Built
	dressUp(giant)
	giant.Model.Parent = folder
end

-- 0 (hidden: down and behind the hole) .. 1 (out, up to his waist); how open the hole is;
-- seconds since he started climbing out
local function emergence(now: number): (number, number, number, boolean)
	local since = workspace:GetAttribute("GiantSince")
	local leaveAt = workspace:GetAttribute("GiantLeaveAt")
	local open, out, age = 1, 1, 1000
	if type(since) == "number" then
		age = now - localTime(since)
		open = math.clamp(age / Giant.OPEN, 0, 1)
		out = math.clamp((age - Giant.OPEN) / Giant.RISE, 0, 1)
	end
	local leaving = type(leaveAt) == "number"
	if type(leaveAt) == "number" then
		local t = now - localTime(leaveAt)
		out = math.min(out, 1 - math.clamp(t / Giant.SINK, 0, 1))
		open = math.min(open, 1 - math.clamp((t - Giant.SINK) / CLOSE_TIME, 0, 1))
	end
	return open, out, age, leaving
end

-- His body's frame: risen `out` of the way, breathing, turned a little towards an attack.
local function bodyFrame(now: number, out: number, twist: number): CFrame
	local L = layout :: Giant.Layout
	local eased = 1 - (1 - out) ^ 3
	local hidden = CFrame.new(0, -2.8 * S, 4.5 * S)
	local offset = hidden:Lerp(CFrame.identity, eased)
	local breathe = CFrame.new(0, math.sin(now * 0.9) * 0.04 * S * out, 0)
	return CFrame.new(L.Waist.Position) * offset * breathe * CFrame.Angles(0, twist, 0) * L.Waist.Rotation
end

local function shoulderOf(body: CFrame, side: string): Vector3
	return (body * CFrame.new((if side == "Left" then -1 else 1) * 1.62 * S, 2.05 * S, 0)).Position
end

-- Where a hand rests between attacks: hanging over the rim of the hole, in front of him.
local function restWrist(body: CFrame, side: string): Vector3
	local x = if side == "Left" then -1 else 1
	return (body * CFrame.new(x * 2.1 * S, -0.6 * S, -2.2 * S)).Position
end

local function raisedWrist(body: CFrame, side: string): Vector3
	local x = if side == "Left" then -1 else 1
	return (body * CFrame.new(x * 2.3 * S, 3.6 * S, -0.8 * S)).Position
end

-- Both fists thrown up to the sky (star rain).
local function summonWrist(body: CFrame, side: string, now: number): Vector3
	local x = if side == "Left" then -1 else 1
	return (body * CFrame.new(x * 1.9 * S, 4.6 * S + math.sin(now * 8) * 0.05 * S, -0.6 * S)).Position
end

-- Where the elbow bends towards (out to the side and back, like a real arm).
local function poleOf(body: CFrame, side: string): Vector3
	local x = if side == "Left" then -1 else 1
	return (body * CFrame.new(x * 4 * S, 1.2 * S, 2.5 * S)).Position
end

-- The wrist position that puts the fist down flat on the lane right over `target` (the fist
-- carries on along the forearm, so this settles in a few steps).
local function impactWrist(body: CFrame, side: string, target: Vector3): Vector3
	local fist = Giant.FIST * S
	local shoulder = shoulderOf(body, side)
	local center = target + Vector3.new(0, fist * 0.42, 0)
	local wrist = center + Vector3.new(0, fist / 2, 0)
	for _ = 1, 4 do
		local elbow = Giant.Elbow(shoulder, wrist, Giant.UPPER * S, Giant.FORE * S, poleOf(body, side))
		local dir = wrist - elbow
		dir = if dir.Magnitude > 1e-3 then dir.Unit else -Vector3.yAxis
		wrist = center - dir * fist / 2
	end
	return wrist
end

local function bezier(a: Vector3, c: Vector3, b: Vector3, t: number): Vector3
	return a:Lerp(c, t):Lerp(c:Lerp(b, t), t)
end

-- How far into summoning the stars he is (0 = not, 1 = fists right up), now.
local function summoning(now: number): number
	local amount = 0
	for _, rain in rains do
		local t = now - rain.Start
		local hold = Giant.STAR_CHARGE + Giant.STAR_FALL
		if t > 0 and t < hold + 1 then
			amount = math.max(amount, math.clamp(t / 0.6, 0, 1) * math.clamp((hold + 1 - t) / 1, 0, 1))
		end
	end
	return amount
end

-- Where `side`'s wrist is right now.
local function wristNow(body: CFrame, side: string, now: number): Vector3
	local slam = slams[side]
	local rest = restWrist(body, side)
	local summon = summoning(now)
	if summon > 0 and not slam then
		return rest:Lerp(summonWrist(body, side, now), summon * summon * (3 - 2 * summon))
	end
	if not slam then
		return rest
	end
	local t = now - slam.Start
	local up = raisedWrist(body, side)
	local hit = impactWrist(body, side, slam.Target)
	if t < 0 then
		return rest
	elseif t < Giant.RAISE then
		local a = t / Giant.RAISE
		return rest:Lerp(up, 1 - (1 - a) ^ 2)
	elseif t < Giant.IMPACT then
		-- slow at first, faster and faster: down and out over the lane
		local a = ((t - Giant.RAISE) / Giant.SWING) ^ 2.2
		local control = (up + hit) / 2 + Vector3.new(0, 1.6 * S, 0) + (body.LookVector * 1.2 * S)
		return bezier(up, control, hit, a)
	elseif t < Giant.IMPACT + Giant.HOLD then
		return hit
	elseif t < Giant.LENGTH then
		local a = (t - Giant.IMPACT - Giant.HOLD) / Giant.RETURN
		a = a * a * (3 - 2 * a)
		return hit:Lerp(rest, a) + Vector3.new(0, math.sin(a * math.pi) * 1.2 * S, 0)
	end
	return rest
end

local function collectArm(body: CFrame, side: string, now: number, parts: { BasePart }, frames: { CFrame })
	local giant = built :: Giant.Built
	local arm = giant.Arms[side]
	local shoulder = shoulderOf(body, side)
	local wrist = wristNow(body, side, now)
	local elbow = Giant.Elbow(shoulder, wrist, Giant.UPPER * S, Giant.FORE * S, poleOf(body, side))
	local facing = body.LookVector
	Giant.Collect(arm.Upper, Giant.Bone(shoulder, elbow, facing), parts, frames)
	Giant.Collect(arm.Fore, Giant.Bone(elbow, wrist, facing), parts, frames)
	-- (the fist carries on along the forearm)
	local dir = (wrist - elbow)
	dir = if dir.Magnitude > 1e-3 then dir.Unit else -Vector3.yAxis
	Giant.Collect(arm.Fist, Giant.Bone(wrist, wrist + dir, facing), parts, frames)
end

local function collectPortal(open: number, now: number, parts: { BasePart }, frames: { CFrame })
	local giant = built :: Giant.Built
	local L = layout :: Giant.Layout
	local scale = math.max(0.02, 1 - (1 - open) ^ 2)
	local function scaled(p: Giant.Piece, cf: CFrame)
		for _, item in p.Parts do
			table.insert(parts, item.Part)
			table.insert(frames, cf * CFrame.new(item.Offset.Position * scale) * item.Offset.Rotation)
		end
	end
	scaled(giant.Portal, L.Portal)
	for _, item in giant.Portal.Parts do
		local disk = item.Part
		if disk:IsA("Part") and disk.Shape == Enum.PartType.Cylinder then
			local base = disk:GetAttribute("BaseSize")
			if typeof(base) ~= "Vector3" then
				base = disk.Size
				disk:SetAttribute("BaseSize", base)
			end
			local b = base :: Vector3
			local size = Vector3.new(b.X, b.Y * scale, b.Z * scale)
			if disk.Size ~= size then
				disk.Size = size
			end
		end
	end
	local speedUp = 1 + flare * 2.5
	for i, ringPiece in giant.Rings do
		scaled(ringPiece, L.Portal * CFrame.Angles(0, 0, now * (0.35 + i * 0.12) * speedUp * (if i % 2 == 0 then -1 else 1)))
	end
	scaled(giant.Swirl, L.Portal * CFrame.Angles(0, 0, -now * 0.9 * speedUp))
end

--------------------------------------------------------------------------------
-- His eyes: they follow you, blink every few seconds, glare at where he's about to hit (lids
-- down, brows frowning), open wide as his eye beams charge, and look up at the stars he summons
--------------------------------------------------------------------------------
local function eyeMood(now: number, head: CFrame): (Vector2, number, number)
	for _, beam in beams do
		local t = now - beam.Start
		if t >= 0 and t < Giant.BEAM_CHARGE + Giant.BEAM_SWEEP then
			local a = math.clamp((t - Giant.BEAM_CHARGE) / Giant.BEAM_SWEEP, 0, 1)
			return Giant.LookAt(head, Giant.BeamPoint(beam.From, beam.To, a)), if t < Giant.BEAM_CHARGE then -0.35 else 0.15, 1
		end
	end
	for _, slam in slams do
		local t = now - slam.Start
		if t >= 0 and t < Giant.IMPACT + Giant.HOLD then
			return Giant.LookAt(head, slam.Target), 0.3, 1
		end
	end
	if summoning(now) > 0.3 then
		return Vector2.new(0, 1), -0.2, 0.5
	end
	local player = Players.LocalPlayer
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return Giant.LookAt(head, root.CFrame.Position), 0, 0.25
	end
	return Vector2.new(0, -0.6), 0, 0.2
end

local function updateEyes(now: number, dt: number, head: CFrame)
	local want, lid, anger = eyeMood(now, head)
	look = look:Lerp(want, math.min(1, dt * 7))
	lidClosed += (lid - lidClosed) * math.min(1, dt * 10)
	browAnger += (anger - browAnger) * math.min(1, dt * 6)
	if math.abs(lid - lidClosed) < 0.002 then
		lidClosed = lid
	end
	if now >= nextBlink then
		blinkStart = now
		nextBlink = now + rng:NextNumber(2.5, 6)
	end
end

-- How shut his eyes are right now (a blink shuts them all the way).
local function lidNow(now: number): number
	local b = (now - blinkStart) / BLINK
	if b >= 0 and b < 1 then
		return math.max(lidClosed, math.sin(b * math.pi))
	end
	return lidClosed
end

local function collectEyes(body: CFrame, now: number, parts: { BasePart }, frames: { CFrame })
	local giant = built :: Giant.Built
	local closed = lidNow(now)
	for side, eye in giant.Eyes do
		Giant.Collect(eye.Iris, body * Giant.IrisFrame(side, look), parts, frames)
		local lidFrame, lidSize, lashFrame = Giant.Lid(side, closed)
		if (eye.Lid.Size - lidSize).Magnitude > 0.01 then
			eye.Lid.Size = lidSize
		end
		table.insert(parts, eye.Lid)
		table.insert(frames, body * lidFrame)
		table.insert(parts, eye.Lash)
		table.insert(frames, body * lashFrame)
		table.insert(parts, eye.Brow)
		table.insert(frames, body * Giant.Brow(side, browAnger))
	end
end

local function collectBody(body: CFrame, now: number, parts: { BasePart }, frames: { CFrame })
	local giant = built :: Giant.Built
	Giant.Collect(giant.Body, body, parts, frames)
	collectEyes(body, now, parts, frames)
	local head = body * Giant.HEAD
	Giant.Collect(giant.Crown, head * CFrame.new(0, Giant.HEAD_SIZE * 0.62, 0) * CFrame.Angles(math.rad(14), 0, math.rad(-8)) * CFrame.Angles(0, now * 0.6, 0), parts, frames)
	Giant.Collect(giant.Halo, head * CFrame.new(0, 0.15 * S, 0.95 * S) * CFrame.Angles(0, 0, now * 0.25), parts, frames)
	local core = body * Giant.CORE * CFrame.new(0, 0, -0.08 * S)
	Giant.Collect(giant.CoreRings[1], core * CFrame.Angles(0, 0, now * 1.6), parts, frames)
	Giant.Collect(giant.CoreRings[2], core * CFrame.Angles(0, 0, -now * 1.1), parts, frames)
	for i, side in { "Left", "Right" } do
		local x = if side == "Left" then -1 else 1
		local orbit = body * CFrame.new(x * 1.62 * S, 3.1 * S, 0) * CFrame.Angles(0, now * 1.2 * x + i, 0) * CFrame.new(1.25 * S, math.sin(now * 2 + i) * 0.15 * S, 0)
		Giant.Collect(giant.Moons[side], orbit * CFrame.Angles(0, now * 2, 0), parts, frames)
	end
	Giant.Collect(giant.Asteroids, body * CFrame.new(0, 0.5 * S, 0) * CFrame.Angles(0, now * 0.22, 0), parts, frames)
	Giant.Collect(giant.Cape, body * CFrame.new(0, 2.55 * S, 0.9 * S) * CFrame.Angles(0.1 + math.sin(now * 0.7) * 0.04, 0, math.sin(now * 0.5) * 0.02), parts, frames)
end

local function attackTwist(now: number): number
	local twist = 0
	for side, slam in slams do
		local t = now - slam.Start
		if t > 0 and t < Giant.LENGTH then
			local weight = math.sin(math.clamp(t / Giant.LENGTH, 0, 1) * math.pi)
			twist += (if side == "Left" then 1 else -1) * 0.12 * weight
		end
	end
	return twist
end

--------------------------------------------------------------------------------
-- Telegraphs: the glowing circle (with runes circling it and a pillar of light) where something
-- is about to land, and the line an eye beam will burn along
--------------------------------------------------------------------------------
local function warningCircle(at: Vector3, radius: number, color: Color3): Model
	local model = Instance.new("Model")
	model.Name = "SlamWarning"
	local base = disc("WarnDisc", radius, at + Vector3.new(0, 0.3, 0), color, Enum.Material.Neon, 0.55, model)
	model.PrimaryPart = base
	disc("WarnRim", radius + 1.5, at + Vector3.new(0, 0.25, 0), WHITE, Enum.Material.Neon, 0.5, model)
	for i = 0, 7 do
		local angle = i / 8 * TAU
		part("WarnRune", Vector3.new(3.5, 0.4, 1.4), CFrame.new(at + Vector3.new(math.cos(angle) * (radius + 4), 0.5, math.sin(angle) * (radius + 4))) * CFrame.Angles(0, -angle, 0), WHITE, Enum.Material.Neon, model)
	end
	local pillar = part("WarnPillar", Vector3.new(160, radius * 0.3, radius * 0.3), CFrame.new(at + Vector3.new(0, 80, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.Material.Neon, model)
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Transparency = 0.9
	model.Parent = folder
	return model
end

local function pulseWarning(model: Model, now: number, urgency: number)
	local center = (model.PrimaryPart :: BasePart).CFrame.Position
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			if p.Name == "WarnDisc" then
				p.Transparency = 0.25 + 0.45 * math.abs(math.sin(now * (3 + urgency * 12)))
			elseif p.Name == "WarnRune" then
				-- (the runes circle the target, faster as it gets closer)
				local offset = p.CFrame.Position - center
				local turned = CFrame.Angles(0, (1 + urgency * 4) * 0.03, 0) * Vector3.new(offset.X, 0, offset.Z)
				p.CFrame = CFrame.new(center + Vector3.new(turned.X, offset.Y, turned.Z)) * CFrame.Angles(0, math.atan2(-turned.Z, turned.X), 0)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Slams
--------------------------------------------------------------------------------
local function crystalSpikes(at: Vector3, radius: number, count: number)
	for i = 1, count do
		local angle = i / count * TAU + rng:NextNumber(-0.2, 0.2)
		local spot = at + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius * rng:NextNumber(0.9, 1.3)
		local height = rng:NextNumber(14, 28)
		local base = CFrame.new(spot) * CFrame.Angles(math.cos(angle) * 0.35, 0, -math.sin(angle) * 0.35) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
		local p = part("Spike", Vector3.new(4, height, 4), base * CFrame.new(0, -height / 2, 0), if i % 2 == 0 then Giant.VIOLET else Giant.CYAN, Enum.Material.Neon)
		p.Transparency = 0.1
		table.insert(spikes, { Part = p, Base = base, Height = height, Born = os.clock() })
	end
end

local function impact(slam: Slam)
	local at = slam.Target
	for _, item in { slam.Warning, slam.Charge } :: { Instance? } do
		if item then
			item:Destroy()
		end
	end
	slam.Warning, slam.Charge = nil, nil
	if slam.Trail then
		slam.Trail.Enabled = false
	end
	play("Impact", 1.6)
	oneShot(THUD, 1.2, 0.35)
	-- everyone's screen shakes (much harder close by), and flashes if you're close
	shake(1.4 + 4.2 * closeness(at, 1400))
	screenFlash(0.55 * closeness(at, 500), rgb(255, 225, 255))
	ring(at, GIANT.KnockRadius * 3.5, WHITE, 0.9, 0.5)
	ring(at, GIANT.KnockRadius * 2.2, Giant.PINK, 0.7, 0.7)
	ring(at, GIANT.KnockRadius * 5, rgb(210, 190, 170), 1.4, 0.3)
	-- a dome of light bursting up
	local dome = part("ImpactDome", Vector3.one * GIANT.KnockRadius, CFrame.new(at), rgb(255, 210, 255), Enum.Material.Neon)
	dome.Shape = Enum.PartType.Ball
	dome.Transparency = 0.2
	TweenService:Create(dome, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * GIANT.KnockRadius * 3.2, Transparency = 1 }):Play()
	task.delay(0.7, function()
		dome:Destroy()
	end)
	crystalSpikes(at, GIANT.KnockRadius, 9)
	-- a scorch mark that glows, then fades
	local scorch = disc("Scorch", GIANT.KnockRadius * 1.05, at + Vector3.new(0, 0.12, 0), rgb(30, 18, 40), Enum.Material.Slate, 0.15)
	local glow = disc("ScorchGlow", GIANT.KnockRadius * 0.55, at + Vector3.new(0, 0.18, 0), Giant.PINK, Enum.Material.Neon, 0.3)
	fadeAway(scorch, 2.5, 4)
	fadeAway(glow, 2, 1.5)
	-- cracks in the lane, glowing, fading
	for i = 1, 10 do
		local angle = i / 10 * TAU + rng:NextNumber(-0.2, 0.2)
		local length = rng:NextNumber(22, 50)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local crack = part("Crack", Vector3.new(2, 0.3, length), CFrame.lookAt(at + dir * (GIANT.KnockRadius * 0.5 + length / 2) + Vector3.new(0, 0.2, 0), at + dir * 500), if i % 2 == 0 then Giant.CYAN else Giant.PINK, Enum.Material.Neon)
		fadeAway(crack, 3)
	end
	-- rock flying up
	for i = 1, 14 do
		local angle = i / 14 * TAU
		local chunk = rng:NextNumber(3, 7)
		local p = part("Debris", Vector3.new(chunk, chunk * 0.8, chunk), CFrame.new(at + Vector3.new(0, 4, 0)), if i % 4 == 0 then Giant.CYAN else rgb(110, 95, 120), if i % 4 == 0 then Enum.Material.Neon else Enum.Material.Slate)
		table.insert(debris, { Part = p, Velocity = Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(40, 110) + Vector3.new(0, rng:NextNumber(60, 130), 0), Spin = rng:NextUnitVector() * 3, Born = os.clock(), Life = 2.2 })
	end
	local boom = Instance.new("Explosion")
	boom.BlastPressure = 0
	boom.BlastRadius = 20
	boom.DestroyJointRadiusPercent = 0
	boom.ExplosionType = Enum.ExplosionType.NoCraters
	boom.Position = at + Vector3.new(0, 4, 0)
	boom.Parent = folder
end

local function onSlam(info: any)
	if type(info) ~= "table" or typeof(info.Target) ~= "Vector3" or type(info.StartAt) ~= "number" then
		return
	end
	local side = if info.Hand == "Left" then "Left" else "Right"
	local old = slams[side]
	if old then
		for _, item in { old.Warning, old.Charge } :: { Instance? } do
			if item then
				item:Destroy()
			end
		end
	end
	local target = info.Target :: Vector3
	slams[side] = { Hand = side, Target = target, Start = localTime(info.StartAt), Swung = false, Hit = false, Warning = warningCircle(target, GIANT.KnockRadius, rgb(255, 60, 140)) }
end

-- The energy round a slamming fist: a ball that grows while he lifts it, and a trail of light
-- behind it as it comes down.
local function chargeFist(slam: Slam, t: number)
	local giant = built
	if not giant then
		return
	end
	local fist = giant.Fists[slam.Hand]
	local palm = giant.Palms[slam.Hand]
	local fs = Giant.FIST * S
	if t >= 0 and t < Giant.IMPACT then
		local a = math.clamp(t / Giant.RAISE, 0, 1)
		local charge = slam.Charge
		if not charge then
			local ball = part("FistCharge", Vector3.one, fist.CFrame, Giant.PINK, Enum.Material.Neon)
			ball.Shape = Enum.PartType.Ball
			ball.Transparency = 0.7
			local light = Instance.new("PointLight")
			light.Color = Giant.PINK
			light.Range = 50
			light.Brightness = 5
			light.Parent = ball
			slam.Charge = ball
			charge = ball
		end
		local c = charge :: BasePart
		c.Size = Vector3.one * fs * (0.3 + 0.75 * a) * (1 + 0.06 * math.sin(t * 30))
		c.CFrame = fist.CFrame
		c.Color = Giant.PINK:Lerp(WHITE, a * 0.6)
		palm.Transparency = 0.5 - 0.5 * a
		if not slam.Trail and t >= Giant.RAISE then
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(0, fs * 0.5, 0)
			a0.Parent = fist
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(0, -fs * 0.5, 0)
			a1.Parent = fist
			local trail = Instance.new("Trail")
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Lifetime = 0.45
			trail.LightEmission = 1
			trail.Color = ColorSequence.new(Giant.PINK, Giant.CYAN)
			trail.Transparency = NumberSequence.new(0.15, 1)
			trail.FaceCamera = true
			trail.Parent = fist
			slam.Trail = trail
		end
	else
		palm.Transparency = 0.5
		if slam.Charge then
			slam.Charge:Destroy()
			slam.Charge = nil
		end
	end
end

--------------------------------------------------------------------------------
-- Star rain
--------------------------------------------------------------------------------
local function onStarRain(info: any)
	if type(info) ~= "table" or type(info.Targets) ~= "table" or type(info.StartAt) ~= "number" then
		return
	end
	local start = localTime(info.StartAt)
	local stars: { Star } = {}
	local count = #info.Targets
	for i, target in info.Targets do
		if typeof(target) == "Vector3" then
			table.insert(stars, { Target = target, Land = start + Giant.StarLanding(i, count), Warning = warningCircle(target, GIANT.StarRain.Radius, rgb(255, 170, 60)), Landed = false })
		end
	end
	table.insert(rains, { Start = start, Stars = stars, Launched = false })
end

local function starLanded(star: Star)
	if star.Part then
		star.Part:Destroy()
		star.Part = nil
	end
	if star.Warning then
		star.Warning:Destroy()
		star.Warning = nil
	end
	local at = star.Target
	-- the impact sound (it's loud: a few at most each moment, however many land together)
	local clock = os.clock()
	if clock - lastStarImpact >= 0.15 then
		lastStarImpact = clock
		oneShot(GIANT.Sounds.StarImpact, GIANT.StarRain.ImpactVolume, 1)
	end
	shake(0.6 + 2 * closeness(at, 700))
	ring(at, GIANT.StarRain.Radius * 2.6, rgb(255, 200, 120), 0.6, 0.5)
	ring(at, GIANT.StarRain.Radius * 1.6, WHITE, 0.4, 0.7)
	crystalSpikes(at, GIANT.StarRain.Radius * 0.7, 5)
	local mark = disc("StarScorch", GIANT.StarRain.Radius * 0.9, at + Vector3.new(0, 0.12, 0), rgb(40, 22, 30), Enum.Material.Slate, 0.2)
	fadeAway(mark, 2, 3)
	for i = 1, 6 do
		local angle = i / 6 * TAU
		local p = part("Debris", Vector3.one * rng:NextNumber(2, 4), CFrame.new(at + Vector3.new(0, 3, 0)), if i % 2 == 0 then rgb(255, 200, 120) else Giant.VIOLET, Enum.Material.Neon)
		table.insert(debris, { Part = p, Velocity = Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(30, 70) + Vector3.new(0, rng:NextNumber(50, 90), 0), Spin = rng:NextUnitVector() * 4, Born = os.clock(), Life = 1.6 })
	end
end

local function updateRains(now: number)
	local L = layout
	for r = #rains, 1, -1 do
		local rain = rains[r]
		local t = now - rain.Start
		if not rain.Launched and t >= Giant.STAR_CHARGE then
			rain.Launched = true
			play("StarLaunch", GIANT.StarRain.LaunchVolume)
			screenFlash(0.2, Giant.VIOLET)
		end
		local done = true
		for i, star in rain.Stars do
			if star.Warning then
				pulseWarning(star.Warning, now, math.clamp(t / (star.Land - rain.Start), 0, 1))
			end
			if not star.Landed then
				done = false
				local launch = rain.Start + Giant.STAR_CHARGE
				if now >= star.Land then
					star.Landed = true
					if now < star.Land + 1 then
						starLanded(star)
					elseif star.Warning then
						star.Warning:Destroy()
						star.Warning = nil
					end
				elseif now >= launch and L then
					-- out of his raised fists (one each way), arcing high over the lane, down onto its circle
					local a = (now - launch) / (star.Land - launch)
					local giant = built
					local from = if giant then giant.Fists[if i % 2 == 0 then "Left" else "Right"].CFrame.Position + Vector3.new(0, Giant.FIST * S, 0) else L.Portal.Position
					local control = (from + star.Target) / 2 + Vector3.new(0, 160, 0)
					local position = bezier(from, control, star.Target + Vector3.new(0, 4, 0), a * a)
					local p = star.Part
					if not p then
						local ball = part("CosmicStar", Vector3.one * 12, CFrame.new(position), rgb(255, 220, 150), Enum.Material.Neon)
						ball.Shape = Enum.PartType.Ball
						local a0 = Instance.new("Attachment")
						a0.Position = Vector3.new(0, 5, 0)
						a0.Parent = ball
						local a1 = Instance.new("Attachment")
						a1.Position = Vector3.new(0, -5, 0)
						a1.Parent = ball
						local trail = Instance.new("Trail")
						trail.Attachment0 = a0
						trail.Attachment1 = a1
						trail.Lifetime = 0.6
						trail.LightEmission = 1
						trail.FaceCamera = true
						trail.Color = ColorSequence.new(rgb(255, 230, 160), Giant.VIOLET)
						trail.Transparency = NumberSequence.new(0, 1)
						trail.Parent = ball
						local light = Instance.new("PointLight")
						light.Color = rgb(255, 200, 120)
						light.Range = 40
						light.Brightness = 4
						light.Parent = ball
						star.Part = ball
						p = ball
					end
					(p :: BasePart).CFrame = CFrame.new(position)
				end
			end
		end
		if done and t > Giant.STAR_CHARGE + Giant.STAR_FALL + Giant.STAR_SPREAD + 1.5 then
			table.remove(rains, r)
		end
	end
end

--------------------------------------------------------------------------------
-- Eye beam
--------------------------------------------------------------------------------
local function onBeam(info: any)
	if type(info) ~= "table" or typeof(info.From) ~= "Vector3" or typeof(info.To) ~= "Vector3" or type(info.StartAt) ~= "number" then
		return
	end
	local from, to = info.From :: Vector3, info.To :: Vector3
	-- the warning: a glowing line along the lane, a circle at each end
	local model = Instance.new("Model")
	model.Name = "BeamWarning"
	local length = (to - from).Magnitude
	local line = part("BeamLine", Vector3.new(GIANT.Beam.Radius * 2, 0.3, length), CFrame.lookAt((from + to) / 2 + Vector3.new(0, 0.3, 0), to + Vector3.new(0, 0.3, 0)), rgb(255, 60, 100), Enum.Material.Neon, model)
	line.Transparency = 0.6
	model.PrimaryPart = line
	for _, at in { from, to } do
		disc("BeamEnd", GIANT.Beam.Radius, at + Vector3.new(0, 0.35, 0), WHITE, Enum.Material.Neon, 0.5, model)
	end
	model.Parent = folder
	-- the laser eyes sound: from when his eyes start to charge until the beams stop, looping
	-- (it's 3 seconds long; the charge and the sweep together are longer)
	local template = soundFolder:FindFirstChild("Laser")
	local laser = if template and template:IsA("Sound") then template:Clone() else nil
	if laser then
		laser.Name = "LaserPlaying"
		laser.Parent = soundFolder
	end
	table.insert(beams, { From = from, To = to, Start = localTime(info.StartAt), Warning = model, Parts = {}, Fired = false, Laser = laser, LaserOn = false, NextScorch = 0 })
end

local function updateBeams(now: number, body: CFrame?)
	local giant = built
	local strongest = 0
	for b = #beams, 1, -1 do
		local beam = beams[b]
		local t = now - beam.Start
		-- the laser eyes sound: on as his eyes start to charge, looping until the beams stop
		local laser = beam.Laser
		if laser and not beam.LaserOn and t >= 0 and t < Giant.BEAM_CHARGE + Giant.BEAM_SWEEP then
			beam.LaserOn = true
			laser.TimePosition = 0
			laser:Play()
		end
		-- charging: his eyes blaze white and swell
		local charge = math.clamp(t / Giant.BEAM_CHARGE, 0, 1)
		if giant then
			for _, iris in giant.Irises do
				iris.Color = Giant.CYAN:Lerp(WHITE, if t < Giant.BEAM_CHARGE + Giant.BEAM_SWEEP then charge else 0)
			end
		end
		local warning = beam.Warning
		if warning then
			local line = warning.PrimaryPart
			if line then
				line.Transparency = 0.25 + 0.4 * math.abs(math.sin(now * (4 + charge * 14)))
			end
		end
		local sweeping = t >= Giant.BEAM_CHARGE and t < Giant.BEAM_CHARGE + Giant.BEAM_SWEEP
		if sweeping and body then
			if not beam.Fired then
				beam.Fired = true
				screenFlash(0.25, rgb(255, 120, 200))
				if beam.Warning then
					beam.Warning:Destroy()
					beam.Warning = nil
				end
				for i = 1, 2 do
					local outer = part("EyeBeam", Vector3.new(7, 7, 10), CFrame.identity, rgb(255, 90, 200), Enum.Material.Neon)
					outer.Transparency = 0.35
					local inner = part("EyeBeamCore", Vector3.new(2.5, 2.5, 10), CFrame.identity, WHITE, Enum.Material.Neon)
					table.insert(beam.Parts, outer)
					table.insert(beam.Parts, inner)
					if i == 1 then
						local glow = part("BeamGlow", Vector3.one * 16, CFrame.identity, rgb(255, 200, 240), Enum.Material.Neon)
						glow.Shape = Enum.PartType.Ball
						glow.Transparency = 0.3
						local light = Instance.new("PointLight")
						light.Color = rgb(255, 120, 200)
						light.Range = 60
						light.Brightness = 6
						light.Parent = glow
						table.insert(beam.Parts, glow)
					end
				end
			end
			local a = (t - Giant.BEAM_CHARGE) / Giant.BEAM_SWEEP
			local point = Giant.BeamPoint(beam.From, beam.To, a)
			local index = 1
			for _, side in { "Left", "Right" } do
				local eye = (body * Giant.Eye(side, look)).Position
				local hit = point + Vector3.new(if side == "Left" then -2 else 2, 0, 0)
				local length = (hit - eye).Magnitude
				local cf = CFrame.lookAt((eye + hit) / 2, hit)
				local outer, inner = beam.Parts[index], beam.Parts[index + 1]
				outer.Size = Vector3.new(7 + math.sin(now * 40) * 1.2, 7, length)
				outer.CFrame = cf
				inner.Size = Vector3.new(2.5, 2.5, length)
				inner.CFrame = cf
				index += if side == "Left" then 3 else 2
			end
			local glow = beam.Parts[3]
			if glow then
				glow.CFrame = CFrame.new(point + Vector3.new(0, 2, 0))
			end
			-- it leaves a burning trail on the lane
			if now >= beam.NextScorch then
				beam.NextScorch = now + 0.08
				local mark = disc("BeamScorch", GIANT.Beam.Radius * 0.7, point + Vector3.new(0, 0.15, 0), if rng:NextNumber() < 0.5 then Giant.PINK else rgb(255, 160, 80), Enum.Material.Neon, 0.25)
				fadeAway(mark, 1.8, 0.6)
			end
			strongest = math.max(strongest, 0.5 + 1.5 * closeness(point, 600))
		elseif t >= Giant.BEAM_CHARGE + Giant.BEAM_SWEEP then
			for _, p in beam.Parts do
				p:Destroy()
			end
			table.clear(beam.Parts)
			if beam.Laser then
				beam.Laser:Stop()
				beam.Laser:Destroy()
				beam.Laser = nil
			end
			if beam.Warning then
				beam.Warning:Destroy()
				beam.Warning = nil
			end
			table.remove(beams, b)
		end
	end
	rumble = strongest
end

--------------------------------------------------------------------------------
-- Every frame
--------------------------------------------------------------------------------
local function updateLoose(now: number, dt: number)
	-- flying rock
	for i = #debris, 1, -1 do
		local d = debris[i]
		local age = now - d.Born
		if age > d.Life then
			d.Part:Destroy()
			table.remove(debris, i)
		else
			d.Velocity += Vector3.new(0, -120, 0) * dt
			d.Part.CFrame = (d.Part.CFrame + d.Velocity * dt) * CFrame.fromAxisAngle(d.Spin.Unit, d.Spin.Magnitude * dt)
			if age > d.Life * 0.6 then
				d.Part.Transparency = (age - d.Life * 0.6) / (d.Life * 0.4)
			end
		end
	end
	-- lightning fades
	for i = #bolts, 1, -1 do
		local b = bolts[i]
		local age = now - b.Born
		if age > b.Life then
			for _, p in b.Parts do
				p:Destroy()
			end
			table.remove(bolts, i)
		else
			local flicker = if age < b.Life * 0.3 then 0 elseif age < b.Life * 0.5 then 0.7 else 0.2 + age / b.Life * 0.8
			for _, p in b.Parts do
				p.Transparency = flicker
			end
		end
	end
	-- crystal spikes burst up, then sink back down
	for i = #spikes, 1, -1 do
		local s = spikes[i]
		local age = now - s.Born
		if age > 2.2 then
			s.Part:Destroy()
			table.remove(spikes, i)
		else
			local up = if age < 0.18 then age / 0.18 elseif age < 1 then 1 else 1 - (age - 1) / 1.2
			s.Part.CFrame = s.Base * CFrame.new(0, -s.Height / 2 + s.Height * up, 0)
		end
	end
	-- the screen flash fades
	local f = flash
	if f then
		local left = math.max(0, flashUntil - now) / 0.5
		f.BackgroundTransparency = 1 - flashStrength * left
		if left <= 0 then
			flashStrength = 0
		end
	end
end

local function update(dt: number)
	local now = os.clock()
	updateLoose(now, dt)
	local at = workspace:GetAttribute("GiantSite")
	if typeof(at) ~= "Vector3" then
		if built then
			clear()
		end
		if grade and grade.Enabled then
			grade.Enabled = false
		end
		updateBossUi(now, 0, true)
		return
	end
	ensureBuilt(at)
	local giant = built :: Giant.Built
	local L = layout :: Giant.Layout
	local open, out, age, leaving = emergence(now)
	-- his entrance: a roar, a shock wave, his title card (once, when he's just come out)
	if not roared and age >= Giant.OPEN and not leaving then
		roared = true
		if age < Giant.OPEN + Giant.RISE + 3 then
			play("Emerge", 1)
			oneShot(THUD, 1.5, 0.25)
			shake(2.6)
			screenFlash(0.35, Giant.VIOLET)
			ring(L.Portal.Position - Vector3.new(0, L.Portal.Position.Y - 1, 0), 500, Giant.VIOLET, 1.6, 1)
			for _ = 1, 6 do
				local angle = rng:NextNumber(0, TAU)
				local rim = (L.Portal * CFrame.new(math.cos(angle) * Giant.PORTAL_RADIUS * 1.3, math.sin(angle) * Giant.PORTAL_RADIUS * 1.3, 0)).Position
				bolt(rim, Vector3.new(rng:NextNumber(-100, 100), 0, L.Portal.Position.Z - rng:NextNumber(60, 220)), 3, Giant.VIOLET)
			end
		end
		titleCard()
	end
	-- lightning crackles off the hole's torn edge now and then
	if out > 0.2 and not leaving and now >= nextBolt then
		nextBolt = now + rng:NextNumber(1.8, 4)
		local angle = rng:NextNumber(0, TAU)
		local rim = (L.Portal * CFrame.new(math.cos(angle) * Giant.PORTAL_RADIUS * 1.32, math.sin(angle) * Giant.PORTAL_RADIUS * 1.32, 0)).Position
		local to = rim + (rim - L.Portal.Position).Unit * rng:NextNumber(60, 140) + Vector3.new(0, rng:NextNumber(-60, 20), 0)
		bolt(rim, to, 2.2, if rng:NextNumber() < 0.5 then Giant.VIOLET else Giant.CYAN)
		oneShot(ROAR, 0.3, 0.6)
	end
	-- slams: sounds, energy, warnings, the impact
	for side, slam in slams do
		local t = now - slam.Start
		chargeFist(slam, t)
		if not slam.Swung and t >= Giant.RAISE then
			slam.Swung = true
			if t < Giant.IMPACT then
				play("Swing", 1.2)
			end
		end
		if not slam.Hit and t >= Giant.IMPACT then
			slam.Hit = true
			if t < Giant.IMPACT + 1 then
				impact(slam)
			elseif slam.Warning then
				slam.Warning:Destroy()
				slam.Warning = nil
			end
		end
		if slam.Warning then
			pulseWarning(slam.Warning, now, math.clamp(t / Giant.IMPACT, 0, 1))
		end
		if t > Giant.LENGTH + 0.5 then
			dropTrail(slam)
			slams[side] = nil
		end
	end
	updateRains(now)
	-- the hole flares while he summons the stars
	local summon = summoning(now)
	flare += (summon - flare) * math.min(1, dt * 4)
	-- his reactor and his eyes pulse
	local pulse = 0.5 + 0.5 * math.sin(now * 3)
	giant.Core.Color = Giant.PINK:Lerp(WHITE, pulse * 0.7 + flare * 0.3)
	local haze = giant.Model:FindFirstChild("HoleHaze")
	if haze and haze:IsA("BasePart") then
		haze.Transparency = 0.82 - flare * 0.35
	end
	-- him, his arms, the hole (everything moved in one go)
	local body = bodyFrame(now, out, attackTwist(now))
	updateEyes(now, dt, body * Giant.HEAD)
	updateBeams(now, body)
	local parts: { BasePart } = {}
	local frames: { CFrame } = {}
	collectArm(body, "Left", now, parts, frames)
	collectArm(body, "Right", now, parts, frames)
	slowClock += dt
	local busy = out < 1 or open < 1 or next(slams) ~= nil or #rains > 0 or #beams > 0
	if slowClock >= 1 / 30 or busy then
		slowClock = 0
		collectPortal(open, now, parts, frames)
		collectBody(body, now, parts, frames)
	end
	moveAll(parts, frames)
	-- a purple tint over everything while he's fighting
	local g = grade
	if g then
		local strength = if leaving then 0 else out
		g.Enabled = strength > 0.01
		g.TintColor = WHITE:Lerp(rgb(235, 215, 255), strength)
		g.Contrast = 0.08 * strength
		g.Brightness = flashStrength * math.max(0, flashUntil - now) * 0.2
	end
	updateBossUi(now, out, leaving)
end

function GiantFX.Init()
	folder = Instance.new("Folder")
	folder.Name = "GiantFXLocal"
	folder.Parent = workspace
	local sf = Instance.new("Folder")
	sf.Name = "GiantSounds"
	sf.Parent = SoundService
	soundFolder = sf
	local ids: { [string]: string } = { Swing = GIANT.Sounds.Swing, Impact = GIANT.Sounds.Impact, Emerge = GIANT.Sounds.Emerge, StarLaunch = GIANT.Sounds.StarLaunch, StarImpact = GIANT.Sounds.StarImpact }
	for name, id in ids do
		local s = Instance.new("Sound")
		s.Name = name
		s.SoundId = id
		s.Parent = sf
		sounds[name] = { s }
	end
	-- (each eye beam plays a copy of this, looping)
	local laser = Instance.new("Sound")
	laser.Name = "Laser"
	laser.SoundId = GIANT.Sounds.Laser
	laser.Volume = GIANT.Beam.Volume
	laser.Looped = true
	laser.Parent = sf
	bulkMove = pcall(function()
		workspace:BulkMoveTo({}, {}, Enum.BulkMoveMode.FireCFrameChanged)
	end)
	local g = Instance.new("ColorCorrectionEffect")
	g.Name = "GiantGrade"
	g.Enabled = false
	g.Parent = Lighting
	grade = g
	if Players.LocalPlayer then
		buildBossUi()
	end
	Remotes.Event("GiantSlam").OnClientEvent:Connect(onSlam)
	Remotes.Event("GiantStarRain").OnClientEvent:Connect(onStarRain)
	Remotes.Event("GiantBeam").OnClientEvent:Connect(onBeam)
	RunService.RenderStepped:Connect(update)
	-- the shaking, on every screen (after the camera has moved, so it never builds up)
	RunService:BindToRenderStep("GiantShake", Enum.RenderPriority.Camera.Value + 3, function()
		local now = os.clock()
		local strength = math.max(kick * math.max(0, 1 - (now - kickAt) / 1.6), rumble)
		if strength <= 0 then
			return
		end
		local camera = workspace.CurrentCamera
		if camera then
			camera.CFrame *= CFrame.Angles(math.noise(now * 22, 3.3) * 0.022 * strength, math.noise(now * 22, 6.1) * 0.022 * strength, math.noise(now * 18, 1.7) * 0.01 * strength)
				+ Vector3.new(math.noise(now * 28, 5.5), math.noise(now * 28, 8.8), 0) * 0.55 * strength
		end
	end)
end

-- (tests) the giant being drawn right now, if any
function GiantFX.Current(): Giant.Built?
	return built
end

-- (tests) his next blink, in `seconds`
function GiantFX.BlinkIn(seconds: number)
	nextBlink = os.clock() + seconds
end

return GiantFX
