--[[
	StormFX: what everyone sees and hears during the Eternal Storm (EventService / Config.EternalStorm).

	  * the sky: the server hangs a giant black hole over every world (BlackHoleFX animates it); here
	    the whole picture turns a dark, stormy purple and the Radetzky March plays (Settings)
	  * falling rocks (StormBlock): a huge grassy chunk of rock appears high in the sky and plunges
	    down, with a glowing purple circle on the ground showing where it'll land - get out of it!
	    It smashes into the ground with an explosion, a ring of dust, broken rock and a crater, and
	    shakes the screen of everyone close by (the server flings anyone it lands on)
	  * purple lightning (StormStrike): a giant bolt from the sky onto a donut, which turns ETERNAL
	  * and smaller purple bolts flickering down all around you while it lasts
	The server decides where rocks land and which donuts are struck; everything here is just the
	look, made on this client only.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local StormFX = {}

local rgb = Color3.fromRGB
local TAU = math.pi * 2
local SKY_HEIGHT = 340 -- rocks start this high above the ground
local PURPLE, LIGHT_PURPLE, WHITE = rgb(170, 60, 255), rgb(225, 180, 255), rgb(255, 255, 255)

type Rock = { Model: Model, Circle: BasePart, Target: Vector3, Size: number, Start: number, Fall: number, Spin: Vector3, Drift: Vector3 }
type Fading = { Parts: { BasePart }, Until: number }
type Bolt = { Parts: { BasePart }, Light: PointLight?, Born: number, Life: number }

local folder: Folder
local grade: ColorCorrectionEffect
local active = false
local rng = Random.new()
local rocks: { Rock } = {}
local fading: { Fading } = {}
local bolts: { Bolt } = {}
local flash = 0
local dim = 0 -- how dark the storm makes everything (eases in and out)
local shakeUntil, shakeStrength = 0, 0
local nextAmbient = 0
local setMusic: ((boolean) -> ())? = nil

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

local function sound(at: Vector3, id: string, speed: number, volume: number, range: number)
	local holder = part("Sound", Vector3.one, CFrame.new(at), WHITE, Enum.Material.SmoothPlastic)
	holder.Transparency = 1
	local s = Instance.new("Sound")
	s.SoundId = id
	s.PlaybackSpeed = speed
	s.Volume = volume
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 30
	s.RollOffMaxDistance = range
	s.Parent = holder
	s:Play()
	task.delay(4, function()
		holder:Destroy()
	end)
end

local function thunder(at: Vector3, big: boolean)
	sound(at, "rbxasset://sounds/action_falling.mp3", if big then 0.35 else 0.5, if big then 1 else 0.5, if big then 900 else 400)
	sound(at, "rbxasset://sounds/action_jump_land.mp3", 0.3, if big then 1.2 else 0.5, if big then 900 else 400)
end

local function shake(at: Vector3, strength: number, range: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local closeness = 1 - (camera.CFrame.Position - at).Magnitude / range
	if closeness > 0 then
		shakeStrength = math.max(if os.clock() < shakeUntil then shakeStrength else 0, strength * closeness)
		shakeUntil = os.clock() + 0.55
	end
end

-- A jagged bolt of neon from `from` to `to` (with a white-hot core and a couple of branches).
local function bolt(from: Vector3, to: Vector3, width: number, life: number, light: boolean)
	local parts: { BasePart } = {}
	local function line(a: Vector3, b: Vector3, w: number, depth: number)
		local direction = b - a
		local length = direction.Magnitude
		if length < 0.5 then
			return
		end
		local right = direction:Cross(Vector3.yAxis)
		right = if right.Magnitude < 0.01 then Vector3.xAxis else right.Unit
		local up = right:Cross(direction).Unit
		local segments = math.clamp(math.floor(length / 14), 5, 18)
		local previous = a
		for i = 1, segments do
			local point = if i == segments then b else a + direction * (i / segments) + (right * rng:NextNumber(-1, 1) + up * rng:NextNumber(-1, 1)) * length * 0.045
			local step = point - previous
			local cf = CFrame.lookAt(previous + step / 2, point)
			local glow = part("Bolt", Vector3.new(w, w, step.Magnitude + w * 0.4), cf, PURPLE, Enum.Material.Neon)
			table.insert(parts, glow)
			local core = part("BoltCore", Vector3.new(w * 0.4, w * 0.4, step.Magnitude + w * 0.2), cf, WHITE, Enum.Material.Neon)
			table.insert(parts, core)
			if depth < 1 and i > 1 and i < segments and rng:NextNumber() < 0.22 then
				line(point, point + (rng:NextUnitVector() * Vector3.new(1, 0.3, 1)).Unit * length * rng:NextNumber(0.12, 0.25) + Vector3.new(0, -length * 0.08, 0), w * 0.55, depth + 1)
			end
			previous = point
		end
	end
	line(from, to, width, 0)
	local pointLight: PointLight? = nil
	if light and #parts > 0 then
		local glow = Instance.new("PointLight")
		glow.Color = LIGHT_PURPLE
		glow.Range = 60
		glow.Brightness = 6
		glow.Shadows = false
		glow.Parent = parts[#parts]
		pointLight = glow
	end
	table.insert(bolts, { Parts = parts, Light = pointLight, Born = os.clock(), Life = life })
end

-- A ring bursting out along the ground.
local function ring(at: Vector3, radius: number, color: Color3, duration: number)
	local disc = part("Ring", Vector3.new(0.3, radius * 0.3, radius * 0.3), CFrame.new(at + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.Material.Neon)
	disc.Shape = Enum.PartType.Cylinder
	disc.Transparency = 0.2
	TweenService:Create(disc, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.3, radius * 2, radius * 2), Transparency = 1 }):Play()
	task.delay(duration + 0.1, function()
		disc:Destroy()
	end)
end

--------------------------------------------------------------------------------
-- Falling rocks
--------------------------------------------------------------------------------
local ROCK_COLORS = { rgb(150, 115, 90), rgb(128, 100, 82), rgb(170, 132, 100) }
local GRASS = { rgb(120, 210, 56), rgb(106, 196, 48) }

local function buildRock(size: number, seed: number): Model
	local r = Random.new(seed)
	local model = Instance.new("Model")
	model.Name = "StormRock"
	local main = part("Rock", Vector3.new(size, size * 0.65, size * 0.85), CFrame.identity, ROCK_COLORS[r:NextInteger(1, #ROCK_COLORS)], Enum.Material.Slate, model)
	part("Grass", Vector3.new(size * 0.96, 1.6, size * 0.8), CFrame.new(0, size * 0.325 + 0.6, 0), GRASS[r:NextInteger(1, 2)], Enum.Material.Plastic, model)
	-- lumps of rock stuck on all round, and glowing purple cracks (it came out of the black hole)
	for i = 1, 6 do
		local angle = i / 6 * TAU + r:NextNumber(-0.3, 0.3)
		local lump = size * r:NextNumber(0.3, 0.5)
		part("Lump", Vector3.new(lump, lump * 0.8, lump), CFrame.new(math.cos(angle) * size * 0.42, r:NextNumber(-0.3, 0.1) * size, math.sin(angle) * size * 0.36) * CFrame.Angles(r:NextNumber(0, 3), r:NextNumber(0, 3), r:NextNumber(0, 3)), ROCK_COLORS[r:NextInteger(1, #ROCK_COLORS)], Enum.Material.Slate, model)
	end
	for _ = 1, 4 do
		local crack = part("Crack", Vector3.new(0.5, size * r:NextNumber(0.25, 0.5), 0.5), CFrame.new(r:NextNumber(-0.4, 0.4) * size, r:NextNumber(-0.2, 0.15) * size, -size * 0.43) * CFrame.Angles(0, 0, r:NextNumber(-0.8, 0.8)), PURPLE, Enum.Material.Neon, model)
		crack.Transparency = 0.1
	end
	-- a fiery purple trail behind it
	local trail = Instance.new("ParticleEmitter")
	trail.Texture = "rbxasset://textures/particles/fire_main.dds"
	trail.Color = ColorSequence.new(LIGHT_PURPLE, PURPLE)
	trail.LightEmission = 1
	trail.Rate = 40
	trail.Lifetime = NumberRange.new(0.4, 0.8)
	trail.Speed = NumberRange.new(2, 6)
	trail.EmissionDirection = Enum.NormalId.Top
	trail.Size = NumberSequence.new(size * 0.35, size * 0.1)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Parent = main
	model.PrimaryPart = main
	model.Parent = folder
	return model
end

local function onBlock(info: any)
	if type(info) ~= "table" or typeof(info.Position) ~= "Vector3" or type(info.Size) ~= "number" then
		return
	end
	local size, fall = info.Size, (if type(info.Fall) == "number" then info.Fall else 2.6)
	local target = info.Position :: Vector3
	local model = buildRock(size, if type(info.Seed) == "number" then info.Seed else 1)
	local reach = size * 0.6 + 4
	local circle = part("Warning", Vector3.new(0.25, reach * 0.4, reach * 0.4), CFrame.new(target + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.pi / 2), PURPLE, Enum.Material.Neon)
	circle.Shape = Enum.PartType.Cylinder
	circle.Transparency = 0.45
	local drift = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * 60
	table.insert(rocks, { Model = model, Circle = circle, Target = target, Size = size, Start = os.clock(), Fall = fall, Spin = rng:NextUnitVector(), Drift = drift })
	model:PivotTo(CFrame.new(target + drift + Vector3.new(0, SKY_HEIGHT, 0)))
end

local function impact(rock: Rock)
	local at, size = rock.Target, rock.Size
	rock.Model:Destroy()
	rock.Circle:Destroy()
	-- the crash: an explosion (just the look: the server does the flinging), a ring of dust,
	-- a dark crater with broken rock round it, and the screen shakes
	local boom = Instance.new("Explosion")
	boom.BlastPressure = 0
	boom.BlastRadius = 0
	boom.DestroyJointRadiusPercent = 0
	boom.ExplosionType = Enum.ExplosionType.NoCraters
	boom.Position = at + Vector3.new(0, 2, 0)
	boom.Parent = folder
	ring(at, size * 1.6, rgb(200, 170, 140), 0.7)
	ring(at, size * 1.1, PURPLE, 0.5)
	thunder(at, false)
	shake(at, 1.4, 220)
	local pieces: { BasePart } = {}
	local crater = part("Crater", Vector3.new(0.3, size * 1.3, size * 1.3), CFrame.new(at + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2), rgb(70, 52, 44), Enum.Material.Slate)
	crater.Shape = Enum.PartType.Cylinder
	table.insert(pieces, crater)
	for i = 1, 7 do
		local angle = i / 7 * TAU + rng:NextNumber(-0.3, 0.3)
		local chunk = size * rng:NextNumber(0.18, 0.32)
		local spot = at + Vector3.new(math.cos(angle), 0, math.sin(angle)) * size * rng:NextNumber(0.45, 0.8)
		table.insert(pieces, part("Rubble", Vector3.new(chunk, chunk * 0.7, chunk), CFrame.new(spot + Vector3.new(0, chunk * 0.2, 0)) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, 3), rng:NextNumber(-0.6, 0.6)), ROCK_COLORS[rng:NextInteger(1, #ROCK_COLORS)], Enum.Material.Slate))
	end
	local glow = part("CraterGlow", Vector3.new(0.35, size * 0.6, size * 0.6), CFrame.new(at + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2), PURPLE, Enum.Material.Neon)
	glow.Shape = Enum.PartType.Cylinder
	glow.Transparency = 0.3
	table.insert(pieces, glow)
	table.insert(fading, { Parts = pieces, Until = os.clock() + 12 })
end

--------------------------------------------------------------------------------
-- Lightning
--------------------------------------------------------------------------------
local function onStrike(info: any)
	if type(info) ~= "table" or typeof(info.Position) ~= "Vector3" then
		return
	end
	local at = info.Position :: Vector3
	local from = at + Vector3.new(rng:NextNumber(-40, 40), 420, rng:NextNumber(-40, 40))
	bolt(from, at + Vector3.new(0, 2, 0), 2.6, 0.45, true)
	bolt(from + Vector3.new(rng:NextNumber(-20, 20), 0, rng:NextNumber(-20, 20)), at + Vector3.new(0, 2, 0), 1.2, 0.3, false)
	ring(at, 30, PURPLE, 0.6)
	ring(at, 16, WHITE, 0.35)
	flash = 1
	thunder(at, true)
	shake(at, 0.9, 260)
end

-- Little bolts all round you while the storm lasts (just for the look).
local function ambient(now: number)
	if now < nextAmbient then
		return
	end
	nextAmbient = now + rng:NextNumber(1, 2.8)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local angle = rng:NextNumber(0, TAU)
	local ground = camera.CFrame.Position * Vector3.new(1, 0, 1) + Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(90, 280)
	bolt(ground + Vector3.new(rng:NextNumber(-30, 30), 380, rng:NextNumber(-30, 30)), ground, 1.4, 0.25, false)
	flash = math.max(flash, 0.45)
	if rng:NextNumber() < 0.5 then
		thunder(ground, false)
	end
end

--------------------------------------------------------------------------------
-- Start / stop
--------------------------------------------------------------------------------
local function setActive(on: boolean)
	if on == active then
		return
	end
	active = on
	grade.Enabled = true
	TweenService:Create(grade, TweenInfo.new(2.5), {
		TintColor = if on then rgb(210, 182, 255) else WHITE,
		Contrast = if on then 0.16 else 0,
		Saturation = if on then 0.08 else 0,
	}):Play()
	if not on then
		task.delay(2.6, function()
			if not active then
				grade.Enabled = false
			end
		end)
	end
	if setMusic then
		setMusic(on)
	end
end

local function update(dt: number)
	local now = os.clock()
	-- falling rocks: they speed up all the way down
	for i = #rocks, 1, -1 do
		local rock = rocks[i]
		local a = (now - rock.Start) / rock.Fall
		if a >= 1 then
			table.remove(rocks, i)
			impact(rock)
		else
			local height = SKY_HEIGHT * (1 - a * a)
			local position = rock.Target + rock.Drift * (1 - a * a) + Vector3.new(0, height + rock.Size * 0.3, 0)
			rock.Model:PivotTo(CFrame.new(position) * CFrame.fromAxisAngle(rock.Spin, a * 3))
			local reach = rock.Size * 0.6 + 4
			local grow = 0.4 + 0.6 * a
			rock.Circle.Size = Vector3.new(0.25, reach * 2 * grow, reach * 2 * grow)
			rock.Circle.Transparency = 0.35 + 0.3 * math.abs(math.sin(now * (6 + a * 14)))
		end
	end
	-- broken rock and craters fade away
	for i = #fading, 1, -1 do
		local item = fading[i]
		local left = item.Until - now
		if left <= 0 then
			for _, p in item.Parts do
				p:Destroy()
			end
			table.remove(fading, i)
		elseif left < 2 then
			for _, p in item.Parts do
				p.Transparency = math.max(p.Transparency, 1 - left / 2)
			end
		end
	end
	-- bolts flicker and go
	for i = #bolts, 1, -1 do
		local b = bolts[i]
		local age = now - b.Born
		if age > b.Life then
			for _, p in b.Parts do
				p:Destroy()
			end
			table.remove(bolts, i)
		else
			local t = if age < b.Life * 0.3 then 0 elseif age < b.Life * 0.45 then 0.75 elseif age < b.Life * 0.7 then 0 else 0.6
			for _, p in b.Parts do
				p.Transparency = t
			end
			if b.Light then
				b.Light.Brightness = if t > 0.5 then 1 else 6
			end
		end
	end
	if active then
		ambient(now)
	end
	-- lightning flashes the whole sky
	if flash > 0 then
		flash = math.max(0, flash - 0.08)
	end
	dim += ((if active then -0.08 else 0) - dim) * math.min(1, dt * 1.2)
	if grade.Enabled then
		grade.Brightness = dim + flash * 0.25
	end
end

function StormFX.Init(onMusic: ((boolean) -> ())?)
	setMusic = onMusic
	folder = Instance.new("Folder")
	folder.Name = "StormFXLocal"
	folder.Parent = workspace
	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "StormGrade"
	grade.Enabled = false
	grade.Parent = Lighting
	Remotes.Event("StormBlock").OnClientEvent:Connect(onBlock)
	Remotes.Event("StormStrike").OnClientEvent:Connect(onStrike)
	local function refresh()
		setActive(workspace:GetAttribute("EventId") == "EternalStorm")
	end
	workspace:GetAttributeChangedSignal("EventId"):Connect(refresh)
	refresh()
	RunService.RenderStepped:Connect(update)
	-- Screen shake (after the camera has moved, so it never builds up)
	RunService:BindToRenderStep("StormShake", Enum.RenderPriority.Camera.Value + 1, function()
		local now = os.clock()
		if now >= shakeUntil then
			return
		end
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local strength = shakeStrength * (shakeUntil - now) / 0.55
		camera.CFrame *= CFrame.Angles(math.noise(now * 25, 1.3) * 0.02 * strength, math.noise(now * 25, 4.7) * 0.02 * strength, 0)
			+ Vector3.new(math.noise(now * 30, 9.1), math.noise(now * 30, 2.2), 0) * 0.6 * strength
	end)
end

return StormFX
