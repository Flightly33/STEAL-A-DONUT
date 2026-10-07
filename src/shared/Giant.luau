--[[
	Giant: Cosmic Domer, a colossal Domer dressed in cosmic armour, who climbs out of a black hole
	that tears open over the lane once the Cosmic Meteor has crashed (server/GiantService runs him,
	client/GiantFX draws him). Only his top half comes out of the hole - head, torso and two huge
	arms - and every few seconds he slowly lifts a fist and smashes it into the lane near the meteor's
	crater. Anyone under it is knocked flying (and drops what they're carrying); every screen in the
	server shakes.

	The black hole hangs upright over the lane, a little past the crater (PORTAL_OFFSET), facing the
	lobby; his waist is in the middle of it.

	Every slam, on the server's clock:
	  0s                      he lifts his fist high (RAISE)
	  RAISE                   it swings slowly down at the lane (SWING) - the swing sound
	  RAISE + SWING           it hits: the impact sound, the knock, the shake (IMPACT)
	  ... + HOLD              it rests on the ground a moment
	  ... + RETURN            and goes back to the side of the hole

	Built out of blocks like everything else. Every part is anchored; the client moves them.
]]

local Giant = {}

Giant.S = 48 -- his scale: Domer is ~2 studs wide, this one ~150
Giant.PORTAL_OFFSET = Vector3.new(0, 118, 175) -- the hole, from the crater
Giant.PORTAL_RADIUS = 165
Giant.LEAN = math.rad(18) -- leaning out of the hole towards the lobby
Giant.UPPER = 3.2 -- arm lengths (in S): long enough to reach all round the crater
Giant.FORE = 3.0
Giant.FIST = 1.05

Giant.OPEN = 2 -- seconds: the hole opening
Giant.RISE = 5 -- seconds: him climbing out
Giant.SINK = 4 -- seconds: him sinking back when the storm ends (then the hole closes)

Giant.RAISE = 1.4
Giant.SWING = 2.3
Giant.HOLD = 0.8
Giant.RETURN = 1.8
Giant.IMPACT = Giant.RAISE + Giant.SWING
Giant.LENGTH = Giant.IMPACT + Giant.HOLD + Giant.RETURN

local rgb = Color3.fromRGB
Giant.SKIN = rgb(255, 210, 40)
Giant.ARMOUR = rgb(34, 20, 78)
Giant.ARMOUR_LIGHT = rgb(60, 36, 120)
Giant.CYAN = rgb(90, 230, 255)
Giant.PINK = rgb(255, 120, 220)
Giant.GOLD = rgb(255, 205, 80)
local WHITE = rgb(255, 255, 255)
local BLACK = rgb(20, 16, 30)

export type Layout = {
	Portal: CFrame, -- the hole: its centre, its front facing the lobby
	Waist: CFrame, -- his waist (in the hole), leaning towards the lobby
	Shoulders: { [string]: Vector3 }, -- "Left" / "Right"
}

-- Where everything is, for a crater at `site`.
function Giant.Layout(site: Vector3): Layout
	local center = Vector3.new(0, 0, site.Z) + Giant.PORTAL_OFFSET
	local hole = center + Vector3.new(0, 10, 30) -- (just behind him)
	local portal = CFrame.lookAt(hole, hole - Vector3.zAxis) * CFrame.Angles(math.rad(-8), 0, 0)
	local waist = CFrame.new(center) * CFrame.Angles(-Giant.LEAN, 0, 0)
	local S = Giant.S
	return {
		Portal = portal,
		Waist = waist,
		Shoulders = {
			Left = (waist * CFrame.new(-1.62 * S, 2.05 * S, 0)).Position,
			Right = (waist * CFrame.new(1.62 * S, 2.05 * S, 0)).Position,
		},
	}
end

-- Which hand reaches for `target` (the one on its side of him).
function Giant.HandFor(site: Vector3, target: Vector3): string
	return if target.X >= Giant.Layout(site).Waist.Position.X then "Right" else "Left"
end

-- Can that hand put his fist down on `target`? (the wrist, a fist's height above it, in reach)
function Giant.CanReach(site: Vector3, target: Vector3): boolean
	local shoulder = Giant.Layout(site).Shoulders[Giant.HandFor(site, target)]
	local wrist = target + Vector3.new(0, Giant.FIST * Giant.S, 0)
	return (wrist - shoulder).Magnitude <= (Giant.UPPER + Giant.FORE) * Giant.S * 0.97
end

-- Two-bone IK: where the elbow goes for the wrist to reach `wrist` from `shoulder` (arm lengths
-- a and b), bending towards `pole`.
function Giant.Elbow(shoulder: Vector3, wrist: Vector3, a: number, b: number, pole: Vector3): Vector3
	local offset = wrist - shoulder
	local d = math.clamp(offset.Magnitude, math.abs(a - b) + 0.01, a + b - 0.01)
	local dir = if offset.Magnitude > 1e-3 then offset.Unit else -Vector3.yAxis
	-- distance along the shoulder->wrist line to the elbow's foot, and how far it sticks out
	local along = (a * a - b * b + d * d) / (2 * d)
	local out = math.sqrt(math.max(0, a * a - along * along))
	local toPole = pole - shoulder
	local side = toPole - dir * toPole:Dot(dir)
	side = if side.Magnitude > 1e-3 then side.Unit else Vector3.yAxis:Cross(dir).Unit
	return shoulder + dir * along + side * out
end

-- A bone from `a` to `b`: its frame has -Y pointing from a to b (so parts built hanging down
-- from the joint follow it) and `facing` roughly its front.
function Giant.Bone(a: Vector3, b: Vector3, facing: Vector3): CFrame
	local up = (a - b)
	up = if up.Magnitude > 1e-3 then up.Unit else Vector3.yAxis
	local right = facing:Cross(up)
	right = if right.Magnitude > 1e-3 then right.Unit else up:Cross(Vector3.zAxis).Unit
	return CFrame.fromMatrix(a, right, up)
end

--------------------------------------------------------------------------------
-- The model
--------------------------------------------------------------------------------
local function part(model: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
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
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = model
	return p
end

-- A list of parts and where each sits in its piece's own frame (the client moves the piece).
export type Piece = { Parts: { { Part: BasePart, Offset: CFrame } } }

local function piece(): Piece
	return { Parts = {} }
end

local function add(p: Piece, model: Instance, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
	local made = part(model, name, size, offset, color, material)
	table.insert(p.Parts, { Part = made, Offset = offset })
	return made
end

-- Glowing stars sprinkled over a block (in its frame), on its front.
local function stars(p: Piece, model: Instance, center: CFrame, w: number, h: number, depth: number, count: number, seed: number)
	local r = Random.new(seed)
	for _ = 1, count do
		local s = r:NextNumber(0.05, 0.11) * Giant.S
		add(p, model, "Star", Vector3.new(s, s, s * 0.4), center * CFrame.new(r:NextNumber(-w / 2, w / 2), r:NextNumber(-h / 2, h / 2), -depth / 2 - s * 0.15) * CFrame.Angles(0, 0, math.rad(45)), if r:NextNumber() < 0.7 then WHITE else Giant.CYAN, Enum.Material.Neon)
	end
end

export type Built = {
	Model: Model,
	Body: Piece, -- in the waist's frame
	Arms: { [string]: { Upper: Piece, Fore: Piece, Fist: Piece } }, -- in each bone's frame
	Crown: Piece, -- in the head's frame (spins)
	Portal: Piece, -- in the hole's frame
	Rings: { Piece }, -- spinning rings of the hole (their own frames = the hole's)
}

function Giant.Build(): Built
	local S = Giant.S
	local model = Instance.new("Model")
	model.Name = "CosmicDomer"
	local body = piece()
	local skin, armour, light = Giant.SKIN, Giant.ARMOUR, Giant.ARMOUR_LIGHT

	-- Torso: armoured belly in the hole, a huge chest, traps
	add(body, model, "Belly", Vector3.new(2.4, 1.1, 1.4) * S, CFrame.new(0, 0.55 * S, 0), armour)
	add(body, model, "Belt", Vector3.new(2.5, 0.28, 1.5) * S, CFrame.new(0, 0.95 * S, 0), Giant.GOLD, Enum.Material.Foil)
	add(body, model, "Chest", Vector3.new(3.1, 1.35, 1.6) * S, CFrame.new(0, 1.7 * S, 0), armour)
	for _, side in { -1, 1 } do
		add(body, model, "Pec", Vector3.new(1.3, 0.8, 0.3) * S, CFrame.new(side * 0.7 * S, 1.75 * S, -0.88 * S), light)
		-- glowing seams down the armour
		add(body, model, "Seam", Vector3.new(0.08, 1.3, 0.06) * S, CFrame.new(side * 1.45 * S, 1.6 * S, -0.82 * S), Giant.CYAN, Enum.Material.Neon)
		add(body, model, "Pauldron", Vector3.new(1.75, 0.95, 1.7) * S, CFrame.new(side * 1.62 * S, 2.2 * S, 0), light)
		add(body, model, "PauldronTrim", Vector3.new(1.8, 0.14, 1.75) * S, CFrame.new(side * 1.62 * S, 1.72 * S, 0), Giant.PINK, Enum.Material.Neon)
		add(body, model, "PauldronSpike", Vector3.new(0.35, 0.8, 0.35) * S, CFrame.new(side * 1.95 * S, 2.95 * S, 0) * CFrame.Angles(0, 0, side * -0.35), Giant.CYAN, Enum.Material.Neon)
	end
	add(body, model, "Traps", Vector3.new(1.9, 0.45, 1.0) * S, CFrame.new(0, 2.55 * S, 0.05 * S), skin)
	add(body, model, "Collar", Vector3.new(1.5, 0.3, 1.1) * S, CFrame.new(0, 2.45 * S, -0.1 * S), Giant.CYAN, Enum.Material.Neon)
	-- the emblem on his chest: a glowing donut with a star in the middle
	for i = 0, 9 do
		local angle = i / 10 * math.pi * 2
		add(body, model, "Emblem", Vector3.new(0.2, 0.2, 0.08) * S, CFrame.new(math.cos(angle) * 0.36 * S, 1.75 * S + math.sin(angle) * 0.36 * S, -1.06 * S) * CFrame.Angles(0, 0, angle), if i % 2 == 0 then Giant.PINK else Giant.GOLD, Enum.Material.Neon)
	end
	add(body, model, "EmblemStar", Vector3.new(0.22, 0.22, 0.1) * S, CFrame.new(0, 1.75 * S, -1.07 * S) * CFrame.Angles(0, 0, math.rad(45)), WHITE, Enum.Material.Neon)
	stars(body, model, CFrame.new(0, 1.3 * S, 0), 2.8 * S, 1.6 * S, 1.6 * S, 26, 3)

	-- Head (Domer's face, with glowing eyes)
	local headSize = 1.45 * S
	local head = CFrame.new(0, 2.78 * S + headSize / 2, -0.05 * S)
	local k = headSize / 1.3 -- (Domer's face, scaled to this head)
	local function h(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?)
		add(body, model, name, size * k, head * CFrame.new(offset.Position * k) * offset.Rotation, color, material)
	end
	add(body, model, "Head", Vector3.one * headSize, head, skin)
	for _, side in { -1, 1 } do
		h("Eye", Vector3.one * 0.56, CFrame.new(side * 0.27, 0.16, -0.5), rgb(245, 245, 255))
		h("Pupil", Vector3.new(0.17, 0.17, 0.05), CFrame.new(side * 0.25, 0.16, -0.79), Giant.CYAN, Enum.Material.Neon)
		h("Ear", Vector3.one * 0.34, CFrame.new(side * 0.66, -0.05, 0.05), skin)
		h("Earring", Vector3.new(0.08, 0.2, 0.08), CFrame.new(side * 0.7, -0.3, 0.05), Giant.CYAN, Enum.Material.Neon)
		for n = 0, 2 do
			h("SideHair", Vector3.new(0.06, 0.16, 0.24), CFrame.new(side * 0.64, 0.2 + n * 0.1, 0.18 + n * 0.08) * CFrame.Angles(if n % 2 == 0 then 0.6 else -0.6, 0, 0), BLACK)
		end
	end
	h("Nose", Vector3.new(0.3, 0.3, 0.46), CFrame.new(0, -0.05, -0.72), skin)
	h("Stubble", Vector3.new(0.95, 0.62, 0.7), CFrame.new(0, -0.33, -0.33), rgb(150, 110, 200))
	h("Mouth", Vector3.new(0.42, 0.06, 0.05), CFrame.new(0, -0.36, -0.69), rgb(50, 20, 40))
	for i, x in { -0.12, 0.12 } do
		h("Hair" .. i, Vector3.new(0.05, 0.42, 0.05), CFrame.new(x, 0.78, -0.02) * CFrame.Angles(0, 0, x * -2.2), BLACK)
	end
	-- a cosmic crown: a tilted ring of little glowing planets circling over his head
	local crown = piece()
	for i = 0, 11 do
		local angle = i / 12 * math.pi * 2
		local size = (if i % 3 == 0 then 0.28 else 0.16) * S
		add(crown, model, "CrownPlanet", Vector3.one * size, CFrame.new(math.cos(angle) * 0.95 * S, 0, math.sin(angle) * 0.95 * S), if i % 3 == 0 then Giant.GOLD elseif i % 2 == 0 then Giant.CYAN else Giant.PINK, Enum.Material.Neon)
	end

	-- Arms: armoured sleeve and elbow guard, a huge forearm with glowing bracers, a big fist
	local arms = {}
	for _, side in { "Left", "Right" } do
		local upper, fore, fist = piece(), piece(), piece()
		local U, F = Giant.UPPER * S, Giant.FORE * S
		add(upper, model, "Sleeve", Vector3.new(1.15, U, 1.15) * Vector3.new(S, 1, S), CFrame.new(0, -U / 2, 0), armour)
		add(upper, model, "SleeveTrim", Vector3.new(1.22 * S, 0.14 * S, 1.22 * S), CFrame.new(0, -U * 0.35, 0), Giant.PINK, Enum.Material.Neon)
		stars(upper, model, CFrame.new(0, -U / 2, 0), 0.9 * S, U * 0.8, 1.15 * S, 6, if side == "Left" then 11 else 12)
		add(upper, model, "ElbowGuard", Vector3.new(1.3, 0.7, 1.3) * S, CFrame.new(0, -U + 0.1 * S, 0), light)
		add(fore, model, "Forearm", Vector3.new(1.05 * S, F, 1.05 * S), CFrame.new(0, -F / 2, 0), skin)
		for _, y in { 0.55, 0.85 } do
			add(fore, model, "Bracer", Vector3.new(1.15 * S, 0.16 * S, 1.15 * S), CFrame.new(0, -F * y, 0), if y < 0.7 then Giant.CYAN else Giant.PINK, Enum.Material.Neon)
		end
		local fs = Giant.FIST * S
		add(fist, model, "Fist", Vector3.one * fs, CFrame.new(0, -fs / 2, 0), skin)
		add(fist, model, "Knuckles", Vector3.new(fs * 1.02, fs * 0.25, fs * 0.3), CFrame.new(0, -fs * 0.82, -fs * 0.38), skin:Lerp(BLACK, 0.12))
		add(fist, model, "Thumb", Vector3.new(fs * 0.3, fs * 0.5, fs * 0.3), CFrame.new((if side == "Left" then 1 else -1) * fs * 0.52, -fs * 0.45, -fs * 0.2), skin)
		add(fist, model, "HandStar", Vector3.new(fs * 0.25, fs * 0.25, fs * 0.06), CFrame.new(0, -fs * 0.5, fs * 0.51) * CFrame.Angles(0, 0, math.rad(45)), Giant.CYAN, Enum.Material.Neon)
		arms[side] = { Upper = upper, Fore = fore, Fist = fist }
	end

	-- The hole: a black core, a thin white ring of bent light round it, a swirling glowing disk
	local portal = piece()
	local R = Giant.PORTAL_RADIUS
	local core = add(portal, model, "HoleCore", Vector3.new(4, R * 1.7, R * 1.7), CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(0, 0, 0), rgb(4, 2, 10))
	core.Shape = Enum.PartType.Cylinder
	local haze = add(portal, model, "HoleHaze", Vector3.new(1, R * 2.7, R * 2.7), CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(-6, 0, 0), rgb(120, 60, 220), Enum.Material.Neon)
	haze.Shape = Enum.PartType.Cylinder
	haze.Transparency = 0.82
	local rings = {}
	type RingSpec = { Radius: number, Count: number, Width: number, Colors: { Color3 }, Transparency: number }
	local specs: { RingSpec } = {
		{ Radius = R * 0.88, Count = 28, Width = 0.1 * S, Colors = { WHITE }, Transparency = 0 },
		{ Radius = R * 1.02, Count = 30, Width = 0.32 * S, Colors = { rgb(255, 230, 170), rgb(255, 160, 70), rgb(255, 110, 180) }, Transparency = 0.05 },
		{ Radius = R * 1.22, Count = 32, Width = 0.42 * S, Colors = { rgb(255, 110, 180), rgb(190, 90, 255), rgb(110, 90, 255) }, Transparency = 0.3 },
	}
	for _, spec in specs do
		local ring = piece()
		local chord = 2 * math.pi * spec.Radius / spec.Count * 1.08
		for i = 0, spec.Count - 1 do
			local angle = i / spec.Count * math.pi * 2
			local made = add(ring, model, "HoleRing", Vector3.new(chord, spec.Width, 0.6), CFrame.new(math.cos(angle) * spec.Radius, math.sin(angle) * spec.Radius, -1) * CFrame.Angles(0, 0, angle + math.pi / 2), spec.Colors[(i % #spec.Colors) + 1], Enum.Material.Neon)
			made.Transparency = spec.Transparency
		end
		table.insert(rings, ring)
	end
	return { Model = model, Body = body, Arms = arms, Crown = crown, Portal = portal, Rings = rings }
end

-- Put a piece's parts where they go, with the piece's frame at `cf`.
function Giant.Place(p: Piece, cf: CFrame)
	for _, item in p.Parts do
		item.Part.CFrame = cf * item.Offset
	end
end

return Giant
