--[[
	Meteor: the Cosmic Meteor that crashes down halfway through every Eternal Storm (while
	Config.CosmicDonut is on). The server decides where it lands and when (server/MeteorService);
	every client plays it on that same timeline (client/MeteorFX):

	  0s     the screen turns white (2 seconds) - FLASH
	  2s     the ground shakes like crazy - SHAKE
	  2.6s   the sky cracks open where it's coming through - SHATTER
	  3.4s   the meteor bursts through and falls, burning - FALL
	  7.4s   it smashes into the lane and cracks open - IMPACT: its shards are there to grab

	Also builds its models, out of plain blocks like everything else: the burning rock, the shell
	it leaves in its crater, and the glowing shards you carry home (every part anchored).
]]

local Meteor = {}

Meteor.FLASH = 2 -- seconds the screen stays white
Meteor.SHAKE_AT, Meteor.SHAKE = 2, 2.4
Meteor.SHATTER_AT = 2.6
Meteor.FALL_AT = 3.4
Meteor.FALL = 4
Meteor.IMPACT_AT = Meteor.FALL_AT + Meteor.FALL
Meteor.SIZE = 34 -- studs across, the rock
-- where it comes through the sky: high up over the lane, further out (so the lobby sees it coming)
Meteor.ENTRY = Vector3.new(170, 650, 430)
Meteor.CRATER = 46 -- studs across

local rgb = Color3.fromRGB
local ROCK = { rgb(58, 44, 72), rgb(46, 36, 60), rgb(72, 54, 84) }
local GLOW = { rgb(190, 90, 255), rgb(90, 220, 255), rgb(255, 120, 220) }
local HOT = rgb(255, 170, 70)

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Parent = parent
	return p
end

-- The burning rock: a lumpy block of dark space rock, cracked with glowing purple, cyan and orange,
-- with crystals sticking out of it. Its pivot is its middle.
function Meteor.BuildRock(size: number, seed: number): Model
	local r = Random.new(seed)
	local model = Instance.new("Model")
	model.Name = "Meteor"
	-- (turned, so it isn't a plain box from any side)
	local turn = CFrame.Angles(0.6, 0.75, 0.3)
	local half = size * 0.36
	local core = part(model, "Rock", Vector3.one * half * 2, turn, ROCK[1], Enum.Material.Slate)
	model.PrimaryPart = core
	-- glowing cracks across every face of the core, zig-zagging (before the lumps, which cover some)
	local faces = { Vector3.xAxis, -Vector3.xAxis, Vector3.yAxis, -Vector3.yAxis, Vector3.zAxis, -Vector3.zAxis }
	for i, normal in faces do
		local across = if math.abs(normal.Y) > 0.5 then Vector3.xAxis else Vector3.yAxis
		local side = normal:Cross(across)
		local point = across * r:NextNumber(-0.6, 0.6) * half + side * -0.8 * half
		for step = 1, 3 do
			local nextPoint = across * r:NextNumber(-0.7, 0.7) * half + side * (-0.8 + step * 0.55) * half
			local from, to = normal * half + point, normal * half + nextPoint
			local length = (to - from).Magnitude
			local color = if (i + step) % 3 == 0 then HOT else GLOW[((i + step) % 2) + 1]
			part(model, "Crack", Vector3.new(size * 0.05, size * 0.05, length + size * 0.05), turn * CFrame.lookAt((from + to) / 2, to, normal), color, Enum.Material.Neon)
			point = nextPoint
		end
	end
	-- lumps of rock stuck on all round
	for i = 1, 12 do
		local dir = r:NextUnitVector()
		local lump = size * r:NextNumber(0.24, 0.38)
		part(model, "Rock", Vector3.new(lump, lump * r:NextNumber(0.6, 0.9), lump), CFrame.new(dir * size * 0.36) * CFrame.Angles(r:NextNumber(0, 3), r:NextNumber(0, 3), r:NextNumber(0, 3)), ROCK[(i % #ROCK) + 1], Enum.Material.Slate)
	end
	-- crystals
	for i = 1, 6 do
		local dir = r:NextUnitVector()
		local length = size * r:NextNumber(0.2, 0.32)
		part(model, "Crystal", Vector3.new(size * 0.09, length, size * 0.09), CFrame.lookAt(dir * size * 0.44, dir * size * 2) * CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.new(0, length / 2, 0), GLOW[(i % #GLOW) + 1], Enum.Material.Neon)
	end
	return model
end

-- A meteor shard: a glowing crystal growing out of a chip of rock (about 3 studs at scale 1). Its
-- pivot is its bottom.
function Meteor.BuildShard(scale: number, seed: number): Model
	local r = Random.new(seed)
	local model = Instance.new("Model")
	model.Name = "MeteorShard"
	local base = part(model, "Rock", Vector3.new(1.8, 0.8, 1.6) * scale, CFrame.new(0, 0.4 * scale, 0) * CFrame.Angles(0, r:NextNumber(0, 3), 0), ROCK[2], Enum.Material.Slate)
	model.PrimaryPart = base
	for i = 1, 4 do
		local tall = r:NextNumber(1.4, 2.6) * scale
		local lean = if i == 1 then 0 else 0.45
		local angle = i / 4 * math.pi * 2 + r:NextNumber(-0.4, 0.4)
		local cf = CFrame.new(0, 0.6 * scale, 0) * CFrame.Angles(0, angle, 0) * CFrame.Angles(lean, 0, 0) * CFrame.new(0, tall / 2, if i == 1 then 0 else 0.3 * scale)
		part(model, "Crystal", Vector3.new(0.55, tall, 0.55) * Vector3.new(scale, 1, scale), cf * CFrame.Angles(0, math.pi / 4, 0), GLOW[(i % #GLOW) + 1], Enum.Material.Neon)
	end
	model:SetAttribute("Bottom", 0)
	return model
end

-- What's left in the crater: a scorched crater, the rock split open in pieces round a glowing core.
function Meteor.BuildShell(at: Vector3, seed: number): Model
	local r = Random.new(seed)
	local model = Instance.new("Model")
	model.Name = "MeteorCrater"
	local ground = CFrame.new(at)
	local crater = part(model, "Crater", Vector3.new(0.4, Meteor.CRATER, Meteor.CRATER), ground * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2), rgb(40, 28, 40), Enum.Material.Slate)
	crater.Shape = Enum.PartType.Cylinder
	model.PrimaryPart = crater
	local pool = part(model, "Glow", Vector3.new(0.5, Meteor.CRATER * 0.42, Meteor.CRATER * 0.42), ground * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2), GLOW[1], Enum.Material.Neon)
	pool.Shape = Enum.PartType.Cylinder
	pool.Transparency = 0.2
	local light = Instance.new("PointLight")
	light.Color = GLOW[1]
	light.Range = 40
	light.Brightness = 3
	light.Parent = pool
	-- the rock in pieces, leaning out like a cracked egg
	local size = Meteor.SIZE * 0.55
	for i = 0, 3 do
		local angle = i / 4 * math.pi * 2 + r:NextNumber(-0.3, 0.3)
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local cf = CFrame.lookAt(at + out * size * 0.55 + Vector3.new(0, size * 0.4, 0), at + out * size * 2 + Vector3.new(0, size * 0.9, 0))
		part(model, "Shell", Vector3.new(size * 0.8, size * 0.9, size * 0.35), cf, ROCK[(i % #ROCK) + 1], Enum.Material.Slate)
		part(model, "ShellGlow", Vector3.new(size * 0.6, size * 0.7, 0.4), cf * CFrame.new(0, 0, size * 0.18 + 0.2), GLOW[(i % #GLOW) + 1], Enum.Material.Neon)
	end
	-- the glowing heart it cracked open from
	part(model, "Heart", Vector3.one * size * 0.45, ground * CFrame.new(0, size * 0.25, 0) * CFrame.Angles(0.6, 0.8, 0.3), GLOW[2], Enum.Material.Neon)
	-- scorched rubble round the rim
	for i = 1, 10 do
		local angle = i / 10 * math.pi * 2 + r:NextNumber(-0.2, 0.2)
		local chunk = r:NextNumber(2.5, 5)
		local spot = at + Vector3.new(math.cos(angle), 0, math.sin(angle)) * Meteor.CRATER * r:NextNumber(0.42, 0.55)
		part(model, "Rubble", Vector3.new(chunk, chunk * 0.7, chunk), CFrame.new(spot + Vector3.new(0, chunk * 0.3, 0)) * CFrame.Angles(r:NextNumber(-0.5, 0.5), r:NextNumber(0, 3), r:NextNumber(-0.5, 0.5)), ROCK[(i % #ROCK) + 1], Enum.Material.Slate)
	end
	return model
end

return Meteor
