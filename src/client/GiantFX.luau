--[[
	GiantFX: draws Cosmic Domer (shared/Giant, server/GiantService) on every client.

	The server only sets workspace attributes - GiantSite (the meteor's crater), GiantSince (when the
	black hole started tearing open) and GiantLeaveAt (when he started sinking back, at the end of
	the storm) - and fires "GiantSlam" for every slam. Everything else happens here, on the server's
	clock, so everyone sees the same thing (and anyone joining late sees him already out):

	  * the black hole tears open over the lane, its rings swirling
	  * he climbs out of it, up to his waist, and breathes; his crown of planets circles his head
	  * a slam: his fist rises, a glowing circle shows where it'll land, it swings slowly down (the
	    swing sound) and smashes into the lane (the impact sound): shock waves, dust, flying rock,
	    cracks, and EVERY screen shakes (hardest near it)
	  * when the storm ends he sinks back into the hole and it closes
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Giant = require(Shared.Giant)
local Remotes = require(Shared.Remotes)

local GiantFX = {}

local rgb = Color3.fromRGB
local TAU = math.pi * 2
local S = Giant.S
local CLOSE_TIME = 1.5 -- seconds: the hole closing after he's gone
local GIANT = Config.CosmicGiant

type Slam = { Hand: string, Target: Vector3, Start: number, Swung: boolean, Hit: boolean, Circle: BasePart? }
type Debris = { Part: BasePart, Velocity: Vector3, Spin: Vector3, Born: number, Life: number }

local folder: Folder
local built: Giant.Built? = nil
local site: Vector3? = nil
local layout: Giant.Layout? = nil
local slams: { [string]: Slam } = {}
local debris: { Debris } = {}
local sounds: { [string]: { Sound } } = {}
local kick, kickAt = 0, 0
local slowClock = 0
local rng = Random.new()

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

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
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
	p.Parent = folder
	return p
end

local function closeness(at: Vector3, range: number): number
	local camera = workspace.CurrentCamera
	if not camera then
		return 0
	end
	return math.clamp(1 - (camera.CFrame.Position - at).Magnitude / range, 0, 1)
end

local function ring(at: Vector3, radius: number, color: Color3, duration: number, height: number)
	local disc = part("Shockwave", Vector3.new(0.4, radius * 0.25, radius * 0.25), CFrame.new(at + Vector3.new(0, height, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.Material.Neon)
	disc.Shape = Enum.PartType.Cylinder
	disc.Transparency = 0.15
	TweenService:Create(disc, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.4, radius * 2, radius * 2), Transparency = 1 }):Play()
	task.delay(duration + 0.1, function()
		disc:Destroy()
	end)
end

--------------------------------------------------------------------------------
-- Building and placing him
--------------------------------------------------------------------------------
local function clear()
	if built then
		built.Model:Destroy()
	end
	for _, slam in slams do
		if slam.Circle then
			slam.Circle:Destroy()
		end
	end
	table.clear(slams)
	built, site, layout = nil, nil, nil
end

local function ensureBuilt(at: Vector3)
	if built and site == at then
		return
	end
	if built then
		clear() -- (a different giant: forget the old one's slams too)
	end
	-- (a slam can arrive before he's built - it's kept)
	built = Giant.Build()
	site = at
	layout = Giant.Layout(at)
	local giant = built :: Giant.Built
	giant.Model.Parent = folder
end

-- 0 (hidden: down and behind the hole) .. 1 (out, up to his waist)
local function emergence(now: number): (number, number)
	local since = workspace:GetAttribute("GiantSince")
	local leaveAt = workspace:GetAttribute("GiantLeaveAt")
	local open, out = 1, 1
	if type(since) == "number" then
		local t = now - localTime(since)
		open = math.clamp(t / Giant.OPEN, 0, 1)
		out = math.clamp((t - Giant.OPEN) / Giant.RISE, 0, 1)
	end
	if type(leaveAt) == "number" then
		local t = now - localTime(leaveAt)
		out = math.min(out, 1 - math.clamp(t / Giant.SINK, 0, 1))
		open = math.min(open, 1 - math.clamp((t - Giant.SINK) / CLOSE_TIME, 0, 1))
	end
	return open, out
end

-- His body's frame: risen `out` of the way, breathing, turned a little towards a slam.
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

-- Where a hand rests between slams: hanging over the rim of the hole, in front of him.
local function restWrist(body: CFrame, side: string): Vector3
	local x = if side == "Left" then -1 else 1
	return (body * CFrame.new(x * 2.1 * S, -0.6 * S, -2.2 * S)).Position
end

local function raisedWrist(body: CFrame, side: string): Vector3
	local x = if side == "Left" then -1 else 1
	return (body * CFrame.new(x * 2.3 * S, 3.6 * S, -0.8 * S)).Position
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

-- Where `side`'s wrist is right now (and how far through a slam it is: 0..1 down, for the shake).
local function wristNow(body: CFrame, side: string, now: number): Vector3
	local slam = slams[side]
	local rest = restWrist(body, side)
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

local function placeArm(body: CFrame, side: string, now: number)
	local giant = built :: Giant.Built
	local arm = giant.Arms[side]
	local shoulder = shoulderOf(body, side)
	local wrist = wristNow(body, side, now)
	local elbow = Giant.Elbow(shoulder, wrist, Giant.UPPER * S, Giant.FORE * S, poleOf(body, side))
	local facing = body.LookVector
	Giant.Place(arm.Upper, Giant.Bone(shoulder, elbow, facing))
	local fore = Giant.Bone(elbow, wrist, facing)
	Giant.Place(arm.Fore, fore)
	-- (the fist carries on along the forearm)
	local dir = (wrist - elbow)
	dir = if dir.Magnitude > 1e-3 then dir.Unit else -Vector3.yAxis
	Giant.Place(arm.Fist, Giant.Bone(wrist, wrist + dir, facing))
end

local function placePortal(open: number, now: number)
	local giant = built :: Giant.Built
	local L = layout :: Giant.Layout
	local scale = math.max(0.02, 1 - (1 - open) ^ 2)
	local function scaled(p: Giant.Piece, cf: CFrame)
		for _, item in p.Parts do
			item.Part.CFrame = cf * CFrame.new(item.Offset.Position * scale) * item.Offset.Rotation
		end
	end
	scaled(giant.Portal, L.Portal)
	for _, item in giant.Portal.Parts do
		local base = item.Part:GetAttribute("BaseSize")
		if typeof(base) ~= "Vector3" then
			base = item.Part.Size
			item.Part:SetAttribute("BaseSize", base)
		end
		local b = base :: Vector3
		item.Part.Size = Vector3.new(b.X, b.Y * scale, b.Z * scale)
	end
	for i, ringPiece in giant.Rings do
		scaled(ringPiece, L.Portal * CFrame.Angles(0, 0, now * (0.35 + i * 0.12) * (if i % 2 == 0 then -1 else 1)))
	end
end

local function slamTwist(now: number): number
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
-- Slams
--------------------------------------------------------------------------------
local function impact(slam: Slam)
	local at = slam.Target
	if slam.Circle then
		slam.Circle:Destroy()
		slam.Circle = nil
	end
	play("Impact", 1.6)
	-- everyone's screen shakes (much harder close by)
	kick = 1.3 + 4 * closeness(at, 1400)
	kickAt = os.clock()
	ring(at, GIANT.KnockRadius * 3.5, rgb(255, 255, 255), 0.9, 0.5)
	ring(at, GIANT.KnockRadius * 2.2, Giant.PINK, 0.7, 0.7)
	ring(at, GIANT.KnockRadius * 5, rgb(210, 190, 170), 1.4, 0.3)
	-- cracks in the lane, glowing, fading
	for i = 1, 9 do
		local angle = i / 9 * TAU + rng:NextNumber(-0.2, 0.2)
		local length = rng:NextNumber(20, 45)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local crack = part("Crack", Vector3.new(2, 0.3, length), CFrame.lookAt(at + dir * (GIANT.KnockRadius * 0.5 + length / 2) + Vector3.new(0, 0.2, 0), at + dir * 500), if i % 2 == 0 then Giant.CYAN else Giant.PINK, Enum.Material.Neon)
		TweenService:Create(crack, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
		task.delay(3.1, function()
			crack:Destroy()
		end)
	end
	-- rock flying up
	for i = 1, 12 do
		local angle = i / 12 * TAU
		local chunk = rng:NextNumber(3, 7)
		local p = part("Debris", Vector3.new(chunk, chunk * 0.8, chunk), CFrame.new(at + Vector3.new(0, 4, 0)), if i % 4 == 0 then Giant.CYAN else rgb(110, 95, 120), if i % 4 == 0 then Enum.Material.Neon else Enum.Material.Slate)
		table.insert(debris, { Part = p, Velocity = Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(40, 100) + Vector3.new(0, rng:NextNumber(60, 120), 0), Spin = rng:NextUnitVector() * 3, Born = os.clock(), Life = 2.2 })
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
	if old and old.Circle then
		old.Circle:Destroy()
	end
	local target = info.Target :: Vector3
	-- the warning: a glowing circle where the fist will land
	local radius = GIANT.KnockRadius
	local circle = part("SlamWarning", Vector3.new(0.3, radius * 2, radius * 2), CFrame.new(target + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), rgb(255, 60, 140), Enum.Material.Neon)
	circle.Shape = Enum.PartType.Cylinder
	circle.Transparency = 0.5
	slams[side] = { Hand = side, Target = target, Start = localTime(info.StartAt), Swung = false, Hit = false, Circle = circle }
end

--------------------------------------------------------------------------------
-- Every frame
--------------------------------------------------------------------------------
local function update(dt: number)
	local now = os.clock()
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
	local at = workspace:GetAttribute("GiantSite")
	if typeof(at) ~= "Vector3" then
		if built then
			clear()
		end
		return
	end
	ensureBuilt(at)
	local giant = built :: Giant.Built
	local open, out = emergence(now)
	-- slams: sounds, the warning circle pulsing, the impact
	for side, slam in slams do
		local t = now - slam.Start
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
			elseif slam.Circle then
				slam.Circle:Destroy()
				slam.Circle = nil
			end
		end
		local circle = slam.Circle
		if circle then
			local a = math.clamp(t / Giant.IMPACT, 0, 1)
			circle.Transparency = 0.25 + 0.45 * math.abs(math.sin(now * (3 + a * 12)))
		end
		if t > Giant.LENGTH + 0.5 then
			slams[side] = nil
		end
	end
	-- the hole and him
	local body = bodyFrame(now, out, slamTwist(now))
	placeArm(body, "Left", now)
	placeArm(body, "Right", now)
	slowClock += dt
	local moving = out < 1 or open < 1 or next(slams) ~= nil
	if slowClock >= 1 / 20 or moving then
		slowClock = 0
		placePortal(open, now)
		Giant.Place(giant.Body, body)
		local head = body * CFrame.new(0, 2.78 * S + 1.45 * S * 1.1, -0.05 * S)
		Giant.Place(giant.Crown, head * CFrame.Angles(math.rad(14), 0, math.rad(-8)) * CFrame.Angles(0, now * 0.6, 0))
	end
end

function GiantFX.Init()
	folder = Instance.new("Folder")
	folder.Name = "GiantFXLocal"
	folder.Parent = workspace
	local soundFolder = Instance.new("Folder")
	soundFolder.Name = "GiantSounds"
	soundFolder.Parent = SoundService
	local ids: { [string]: string } = { Swing = GIANT.Sounds.Swing, Impact = GIANT.Sounds.Impact }
	for name, id in ids do
		local s = Instance.new("Sound")
		s.Name = name
		s.SoundId = id
		s.Parent = soundFolder
		sounds[name] = { s }
	end
	Remotes.Event("GiantSlam").OnClientEvent:Connect(onSlam)
	RunService.RenderStepped:Connect(update)
	-- the impact shake, on every screen (after the camera has moved, so it never builds up)
	RunService:BindToRenderStep("GiantShake", Enum.RenderPriority.Camera.Value + 3, function()
		if kick <= 0 then
			return
		end
		local camera = workspace.CurrentCamera
		local now = os.clock()
		local strength = kick * math.max(0, 1 - (now - kickAt) / 1.6)
		if strength <= 0 then
			kick = 0
			return
		end
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

return GiantFX
