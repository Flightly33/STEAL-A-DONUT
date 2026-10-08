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

	He doesn't only slam (server/GiantService picks his attacks in turn):
	  STAR RAIN   he throws both fists up, the hole flares, and cosmic stars rain down round the
	              crater (each with a glowing circle where it'll land)
	  EYE BEAM    his eyes charge up, a line glows on the lane, and two beams sweep along it

	Built out of blocks like everything else (about 650 of them: armour plates, gold trim, rivets,
	a reactor core in his chest, a star halo, orbiting moons and asteroids, a nebula cape...).
	Every part is anchored; the client moves them. His eyes are alive: they follow you, blink, and
	narrow (with a frown) when he attacks.
]]

local Giant = {}

Giant.S = 48 -- his scale: Domer is ~2 studs wide, this one ~150
Giant.PORTAL_OFFSET = Vector3.new(0, 130, 120) -- the hole, from the crater (just past it, towards the end of the lane)
Giant.PORTAL_RADIUS = 215
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

Giant.STAR_CHARGE = 1.3 -- star rain: fists up, the hole flares...
Giant.STAR_FALL = 2.2 -- ...then the stars fall (landing at STAR_CHARGE + STAR_FALL)
Giant.STAR_SPREAD = 1 -- (seconds between the first and the last star landing)
Giant.STAR_LAUNCH_SPREAD = 1.2 -- (...and between the first and the last leaving his fists, each with its own launch sound)
Giant.BEAM_CHARGE = 1.7 -- eye beam: his eyes charge up, the line glows...
Giant.BEAM_SWEEP = 2.4 -- ...then the beams sweep along it

local rgb = Color3.fromRGB
Giant.SKIN = rgb(255, 210, 40)
Giant.ARMOUR = rgb(34, 20, 78)
Giant.ARMOUR_LIGHT = rgb(60, 36, 120)
Giant.CYAN = rgb(90, 230, 255)
Giant.PINK = rgb(255, 120, 220)
Giant.GOLD = rgb(255, 205, 80)
Giant.VIOLET = rgb(170, 90, 255)
local WHITE = rgb(255, 255, 255)
local BLACK = rgb(20, 16, 30)

-- Where things are in his body (the waist's frame)
local S0 = Giant.S
Giant.HEAD_SIZE = 1.45 * S0
Giant.HEAD = CFrame.new(0, 2.78 * S0 + Giant.HEAD_SIZE / 2, -0.05 * S0)
Giant.CORE = CFrame.new(0, 1.75 * S0, -1.08 * S0)
local FACE = Giant.HEAD_SIZE / 1.3 -- (Domer's face, scaled to this head)

-- His eyes (in FACE units, the head's frame): round eyeballs like Domer's, each with an iris made
-- of balls sunk into it one inside the next (a dark ring, the glowing iris, a violet ring, a pink
-- "event horizon" and a black-hole pupil), so it stays flush however far the eye turns.
local EYE_X, EYE_Y, EYE_Z, EYE_R = 0.27, 0.16, -0.6, 0.28 -- (bulging out of his face, like Domer's)
type IrisLayer = { Name: string, Radius: number, Depth: number } -- (Depth: its centre from the eyeball's)
local IRIS_LAYERS: { IrisLayer } = {
	{ Name = "IrisRing", Radius = 0.269, Depth = 0.016 },
	{ Name = "Iris", Radius = 0.242, Depth = 0.05 },
	{ Name = "IrisInner", Radius = 0.192, Depth = 0.105 },
	{ Name = "EventHorizon", Radius = 0.12, Depth = 0.184 },
	{ Name = "Pupil", Radius = 0.068, Depth = 0.243 },
}
local PUPIL_FRONT = 0.311
Giant.LOOK_YAW = 0.38 -- how far (radians) his eyes turn left / right...
Giant.LOOK_UP = 0.14 -- ...up (his heavy lids hide the rest)...
Giant.LOOK_DOWN = 0.32 -- ...and down

-- The centre of an eyeball (the waist's frame).
function Giant.EyeCenter(side: string): CFrame
	local x = if side == "Left" then -1 else 1
	return Giant.HEAD * CFrame.new(x * EYE_X * FACE, EYE_Y * FACE, EYE_Z * FACE)
end

-- An iris's frame (the waist's frame; -Z out of the eye) with the eyes turned by `look`
-- (-1..1 each way: +X towards his right, +Y up). Both eyes turn a little in, towards his nose.
function Giant.IrisFrame(side: string, look: Vector2): CFrame
	local x = if side == "Left" then -1 else 1
	local yaw = math.clamp(look.X, -1, 1) * Giant.LOOK_YAW
	local pitch = if look.Y >= 0 then math.min(look.Y, 1) * Giant.LOOK_UP else math.max(look.Y, -1) * Giant.LOOK_DOWN
	return Giant.EyeCenter(side) * CFrame.Angles(0, -yaw + x * 0.04, 0) * CFrame.Angles(pitch, 0, 0)
end

-- Where each eye looks out from, its pupil (the waist's frame): his eye beams start here.
function Giant.Eye(side: string, look: Vector2?): CFrame
	return Giant.IrisFrame(side, look or Vector2.zero) * CFrame.new(0, 0, -PUPIL_FRONT * FACE)
end

-- Which way to turn his eyes (see IrisFrame) to look at `target`, his head being at `head` (world).
function Giant.LookAt(head: CFrame, target: Vector3): Vector2
	local p = head:PointToObjectSpace(target)
	local forward = math.max(-p.Z, 1)
	local yaw = math.atan2(p.X, forward)
	local pitch = math.atan2(p.Y, forward)
	return Vector2.new(math.clamp(yaw / Giant.LOOK_YAW, -1, 1), math.clamp(pitch / (if pitch >= 0 then Giant.LOOK_UP else Giant.LOOK_DOWN), -1, 1))
end

-- His upper eyelid (the waist's frame), `closed`: 0 = as usual (heavy, over the top of his iris),
-- 1 = shut, below 0 = eyes wide open. Its centre, its size and the dark lash line along its edge.
function Giant.Lid(side: string, closed: number): (CFrame, Vector3, CFrame)
	local x = if side == "Left" then -1 else 1
	local height = math.max(0.04, 0.2 + math.clamp(closed, -0.35, 1) * 0.46)
	-- (it hugs the eyeball: only as deep as the eye bulges out under its edge, plus the iris)
	local bottom = 0.48 - height - EYE_Y
	local bulge = if bottom <= 0 then EYE_R else math.sqrt(math.max(0, EYE_R * EYE_R - bottom * bottom))
	local back, front = 0.24, -EYE_Z + bulge + 0.065 -- (+ the iris and its highlights)
	local top = Giant.HEAD * CFrame.new(x * EYE_X * FACE, 0.48 * FACE, 0) * CFrame.Angles(0, 0, x * 0.12)
	return top * CFrame.new(0, -height / 2 * FACE, -(back + front) / 2 * FACE), Vector3.new(0.62, height, front - back) * FACE, top * CFrame.new(0, -height * FACE, -(front + 0.01) * FACE)
end

-- His eyebrow (the waist's frame), `anger` 0..1: lower and steeper when he's angry.
function Giant.Brow(side: string, anger: number): CFrame
	local x = if side == "Left" then -1 else 1
	local a = math.clamp(anger, 0, 1)
	return Giant.HEAD * CFrame.new(x * 0.27 * FACE, (0.55 - 0.06 * a) * FACE, -0.77 * FACE) * CFrame.Angles(0, 0, x * (0.22 + 0.2 * a))
end

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

-- Where the eye beam hits the lane `a` (0..1) of the way through its sweep: it starts slow, races
-- across the middle and slows down at the end (the server knocks players by the same curve).
function Giant.BeamPoint(from: Vector3, to: Vector3, a: number): Vector3
	local t = math.clamp(a, 0, 1)
	return from:Lerp(to, t * t * (3 - 2 * t))
end

-- When star `i` of `count` lands (seconds after its rain started).
-- When star `i` of `count` leaves his fists (seconds after its rain started): one after another.
function Giant.StarLaunch(i: number, count: number): number
	return Giant.STAR_CHARGE + (if count > 1 then (i - 1) / (count - 1) else 0) * Giant.STAR_LAUNCH_SPREAD
end

function Giant.StarLanding(i: number, count: number): number
	return Giant.STAR_CHARGE + Giant.STAR_FALL + (if count > 1 then (i - 1) / (count - 1) else 0) * Giant.STAR_SPREAD
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

local function add(p: Piece, model: Instance, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, transparency: number?): Part
	local made = part(model, name, size, offset, color, material)
	if transparency then
		made.Transparency = transparency
	end
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

-- A ring of blocks round `center` (in its XY plane).
local function ringOf(p: Piece, model: Instance, name: string, center: CFrame, radius: number, count: number, size: Vector3, colors: { Color3 }, material: Enum.Material?, transparency: number?)
	for i = 0, count - 1 do
		local angle = i / count * math.pi * 2
		add(p, model, name, size, center * CFrame.new(math.cos(angle) * radius, math.sin(angle) * radius, 0) * CFrame.Angles(0, 0, angle + math.pi / 2), colors[(i % #colors) + 1], material, transparency)
	end
end

export type Eye = {
	Iris: Piece, -- in the iris's frame (IrisFrame)
	Lid: BasePart, -- the upper eyelid (Lid: it grows down to blink)
	Lash: BasePart, -- the lash line along its edge
	Brow: BasePart,
}

export type Built = {
	Model: Model,
	Body: Piece, -- in the waist's frame
	Arms: { [string]: { Upper: Piece, Fore: Piece, Fist: Piece } }, -- in each bone's frame
	Crown: Piece, -- over his head (spins)
	Halo: Piece, -- the star halo behind his head (turns)
	CoreRings: { Piece }, -- round the reactor in his chest (spin, opposite ways)
	Moons: { [string]: Piece }, -- one circling each shoulder
	Asteroids: Piece, -- circling his waist
	Cape: Piece, -- hanging from his shoulders (sways), its frame at the top
	Portal: Piece, -- in the hole's frame
	Rings: { Piece }, -- spinning rings of the hole (their own frames = the hole's)
	Swirl: Piece, -- the spiral arms pouring into the hole (spin fast)
	Core: BasePart, -- the reactor (pulses)
	Irises: { [string]: BasePart }, -- his glowing eyes (they blaze before an eye beam)
	Eyes: { [string]: Eye }, -- what moves in each eye (see IrisFrame, Lid and Brow)
	Fists: { [string]: BasePart },
	Palms: { [string]: BasePart }, -- glowing palms (charge up before a slam)
}

function Giant.Build(): Built
	local S = Giant.S
	local model = Instance.new("Model")
	model.Name = "CosmicDomer"
	local body = piece()
	local skin, armour, light, gold = Giant.SKIN, Giant.ARMOUR, Giant.ARMOUR_LIGHT, Giant.GOLD
	local dark = armour:Lerp(BLACK, 0.4)
	local foil, neon = Enum.Material.Foil, Enum.Material.Neon

	----------------------------------------------------------------------------
	-- Belly, belt and the armoured skirt going down into the hole
	add(body, model, "Belly", Vector3.new(2.4, 1.1, 1.4) * S, CFrame.new(0, 0.55 * S, 0), armour)
	for row = 0, 2 do
		for _, side in { -1, 1 } do
			add(body, model, "AbPlate", Vector3.new(0.62, 0.26, 0.12) * S, CFrame.new(side * 0.36 * S, (0.28 + row * 0.24) * S, -0.74 * S), light)
		end
	end
	add(body, model, "AbSeam", Vector3.new(0.05, 0.8, 0.1) * S, CFrame.new(0, 0.52 * S, -0.75 * S), Giant.CYAN, neon)
	add(body, model, "Belt", Vector3.new(2.55, 0.3, 1.55) * S, CFrame.new(0, 1.0 * S, 0), gold, foil)
	add(body, model, "BeltBand", Vector3.new(2.58, 0.07, 1.58) * S, CFrame.new(0, 1.0 * S, 0), Giant.PINK, neon)
	-- the buckle: a gold donut with a glowing gem
	ringOf(body, model, "Buckle", CFrame.new(0, 1.0 * S, -0.82 * S), 0.2 * S, 10, Vector3.new(0.13, 0.11, 0.1) * S, { gold, gold:Lerp(WHITE, 0.3) }, foil)
	add(body, model, "BuckleGem", Vector3.new(0.14, 0.14, 0.1) * S, CFrame.new(0, 1.0 * S, -0.85 * S) * CFrame.Angles(0, 0, math.rad(45)), Giant.CYAN, neon)
	for i, x in { -0.75, 0, 0.75 } do
		local tasset = CFrame.new(x * S, 0.6 * S, -0.79 * S) * CFrame.Angles(0.1, 0, -x * 0.15)
		add(body, model, "Tasset", Vector3.new(0.62, 0.62, 0.1) * S, tasset, if i == 2 then light else armour)
		add(body, model, "TassetEdge", Vector3.new(0.64, 0.06, 0.12) * S, tasset * CFrame.new(0, -0.31 * S, 0), if i == 2 then gold else Giant.PINK, if i == 2 then foil else neon)
		add(body, model, "TassetStud", Vector3.one * 0.09 * S, tasset * CFrame.new(0, 0.18 * S, -0.06 * S) * CFrame.Angles(0, 0, math.rad(45)), gold, foil)
	end
	stars(body, model, CFrame.new(0, 0.55 * S, 0), 2.2 * S, 0.9 * S, 1.4 * S, 10, 5)

	----------------------------------------------------------------------------
	-- Chest: plates, gold trim, ribs, rivets, the reactor
	add(body, model, "Chest", Vector3.new(3.1, 1.35, 1.6) * S, CFrame.new(0, 1.7 * S, 0), armour)
	for _, side in { -1, 1 } do
		add(body, model, "Pec", Vector3.new(1.3, 0.8, 0.3) * S, CFrame.new(side * 0.72 * S, 1.78 * S, -0.88 * S), light)
		add(body, model, "PecTrim", Vector3.new(1.32, 0.07, 0.32) * S, CFrame.new(side * 0.72 * S, 1.37 * S, -0.88 * S), gold, foil)
		add(body, model, "PecTrim", Vector3.new(0.07, 0.8, 0.32) * S, CFrame.new(side * 1.38 * S, 1.78 * S, -0.88 * S), gold, foil)
		add(body, model, "Seam", Vector3.new(0.06, 1.2, 0.06) * S, CFrame.new(side * 1.5 * S, 1.62 * S, -0.82 * S), Giant.CYAN, neon)
		for rib = 0, 3 do
			add(body, model, "Rib", Vector3.new(0.12, 0.13, 1.25) * S, CFrame.new(side * 1.56 * S, (1.18 + rib * 0.17) * S, 0) * CFrame.Angles(0, 0, side * 0.1), light)
		end
		for n = 0, 3 do
			add(body, model, "Rivet", Vector3.one * 0.08 * S, CFrame.new(side * (0.2 + n * 0.36) * S, 2.24 * S, -0.82 * S) * CFrame.Angles(0, 0, math.rad(45)), gold, foil)
		end
	end
	add(body, model, "CoreFrame", Vector3.new(0.78, 0.78, 0.12) * S, Giant.CORE * CFrame.new(0, 0, 0.04 * S) * CFrame.Angles(0, 0, math.rad(45)), gold, foil)
	add(body, model, "CoreFrameInner", Vector3.new(0.62, 0.62, 0.13) * S, Giant.CORE * CFrame.new(0, 0, 0.03 * S) * CFrame.Angles(0, 0, math.rad(45)), dark)
	local core = add(body, model, "Core", Vector3.new(0.42, 0.42, 0.16) * S, Giant.CORE * CFrame.Angles(0, 0, math.rad(45)), WHITE, neon)
	stars(body, model, CFrame.new(0, 1.45 * S, 0), 2.9 * S, 1.1 * S, 1.6 * S, 22, 3)

	----------------------------------------------------------------------------
	-- Collar of stacked plates, shoulders of three tiers with crystals
	for i, info in { { 1.85, 1.2 }, { 1.68, 1.1 }, { 1.5, 1.0 } } do
		add(body, model, "Gorget", Vector3.new(info[1], 0.17, info[2]) * S, CFrame.new(0, (2.4 + (i - 1) * 0.15) * S, 0.02 * S), if i % 2 == 1 then light else gold, if i % 2 == 1 then nil else foil)
	end
	add(body, model, "Traps", Vector3.new(1.9, 0.45, 1.0) * S, CFrame.new(0, 2.55 * S, 0.18 * S), skin)
	for _, side in { -1, 1 } do
		local x = side * 1.62 * S
		for tier, info in { { 1.9, 0.55, 1.85, 2.0 }, { 1.62, 0.45, 1.58, 2.42 }, { 1.28, 0.35, 1.22, 2.76 } } do
			local cf = CFrame.new(x + side * (3 - tier) * 0.06 * S, info[4] * S, 0) * CFrame.Angles(0, 0, side * -0.12)
			add(body, model, "Pauldron", Vector3.new(info[1], info[2], info[3]) * S, cf, if tier == 2 then armour else light)
			add(body, model, "PauldronTrim", Vector3.new(info[1] + 0.04, 0.07, info[3] + 0.04) * S, cf * CFrame.new(0, -info[2] / 2 * S, 0), if tier == 1 then Giant.PINK elseif tier == 2 then gold else Giant.CYAN, if tier == 2 then foil else neon)
		end
		stars(body, model, CFrame.new(x, 2.0 * S, 0) * CFrame.Angles(0, 0, side * -0.12), 1.6 * S, 0.4 * S, 1.85 * S, 6, if side < 0 then 21 else 22)
		-- a cluster of crystals growing out of the top
		for c, info in { { 0, 1.0, 0 }, { 0.32, 0.7, 0.5 }, { -0.3, 0.6, -0.45 } } do
			local crystal = CFrame.new(x + side * info[1] * S, (3.0 + info[2] * 0.4) * S, info[3] * S * 0.6) * CFrame.Angles(info[3] * 0.4, 0, side * (-0.3 - c * 0.12))
			add(body, model, "Crystal", Vector3.new(0.24, info[2], 0.24) * S, crystal, if c == 1 then Giant.CYAN else Giant.VIOLET, neon)
			add(body, model, "CrystalTip", Vector3.new(0.17, 0.17, 0.17) * S, crystal * CFrame.new(0, info[2] / 2 * S, 0) * CFrame.Angles(0, math.rad(45), math.rad(45)), WHITE, neon)
		end
	end

	----------------------------------------------------------------------------
	-- Head: Domer's face - stern, with glowing eyes, war paint and a gold circlet
	local headSize = Giant.HEAD_SIZE
	local head = Giant.HEAD
	local k = FACE
	local function h(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
		return add(body, model, name, size * k, head * CFrame.new(offset.Position * k) * offset.Rotation, color, material)
	end
	add(body, model, "Head", Vector3.one * headSize, head, skin)
	local irises: { [string]: BasePart } = {}
	local eyes: { [string]: Eye } = {}
	local function ball(p: Piece, name: string, radius: number, offset: CFrame, color: Color3, material: Enum.Material?): Part
		local made = add(p, model, name, Vector3.one * radius * 2 * k, offset, color, material)
		made.Shape = Enum.PartType.Ball
		return made
	end
	for _, side in { -1, 1 } do
		local name = if side < 0 then "Left" else "Right"
		-- a shadowy socket round a big round eyeball, a puffy lower lid under it
		h("EyeSocket", Vector3.new(0.68, 0.64, 0.05), CFrame.new(side * EYE_X, 0.17, -0.665), skin:Lerp(Giant.VIOLET, 0.4):Lerp(BLACK, 0.25))
		local eyeball = h("Eye", Vector3.one * EYE_R * 2, CFrame.new(side * EYE_X, EYE_Y, EYE_Z), rgb(242, 244, 255))
		eyeball.Shape = Enum.PartType.Ball
		h("LowerLid", Vector3.new(0.46, 0.06, 0.2), CFrame.new(side * EYE_X, -0.13, -0.66), skin:Lerp(BLACK, 0.08))
		h("LowerLidLine", Vector3.new(0.4, 0.022, 0.03), CFrame.new(side * EYE_X, -0.1, -0.75), skin:Lerp(BLACK, 0.45))
		-- the iris (in its own frame, so it can look round): layers of balls, glowing flecks
		-- round it, a twinkling star in the black-hole pupil, and two shiny highlights
		local iris = piece()
		for _, layer in IRIS_LAYERS do
			local layerName, radius, depth = layer.Name, layer.Radius, layer.Depth
			local color = if layerName == "IrisRing" then rgb(16, 24, 80) elseif layerName == "Iris" then Giant.CYAN elseif layerName == "IrisInner" then Giant.VIOLET elseif layerName == "EventHorizon" then Giant.PINK else rgb(6, 2, 14)
			local made = ball(iris, layerName, radius, CFrame.new(0, 0, -depth * k), color, if layerName == "IrisRing" or layerName == "Pupil" then nil else neon)
			if layerName == "Iris" then
				irises[name] = made
			end
		end
		for n = 0, 11 do
			local angle = n / 12 * math.pi * 2
			add(iris, model, "IrisFleck", Vector3.new(0.014, if n % 2 == 0 then 0.055 else 0.04, 0.012) * k, CFrame.new(0, 0, -0.259 * k) * CFrame.Angles(0, 0, angle) * CFrame.new(0, 0.122 * k, 0) * CFrame.Angles(0.53, 0, 0), if n % 3 == 0 then Giant.PINK:Lerp(WHITE, 0.6) else rgb(215, 255, 255), neon)
		end
		-- (a little diamond, like the stars on his hairs - not an "x" or a "+", which read as
		-- knocked out or as a cross)
		add(iris, model, "PupilStar", Vector3.new(0.03, 0.03, 0.01) * k, CFrame.new(0, 0, -(PUPIL_FRONT + 0.002) * k) * CFrame.Angles(0, 0, math.rad(45)), WHITE, neon)
		ball(iris, "Catchlight", 0.0375, CFrame.new(0.07 * k, 0.075 * k, -0.2695 * k), WHITE, neon)
		ball(iris, "Catchlight", 0.018, CFrame.new(-0.06 * k, -0.055 * k, -0.2792 * k), WHITE, neon)
		-- his heavy upper lid with its lash line, and his brow (they move: blinking, squinting, frowning)
		local lidFrame, lidSize, lashFrame = Giant.Lid(name, 0)
		local lid = part(model, "Eyelid", lidSize, lidFrame, skin:Lerp(BLACK, 0.06))
		local lash = part(model, "LashLine", Vector3.new(0.64, 0.055, 0.04) * k, lashFrame, BLACK)
		local brow = part(model, "Brow", Vector3.new(0.52, 0.11, 0.24) * k, Giant.Brow(name, 0), skin:Lerp(BLACK, 0.18))
		eyes[name] = { Iris = iris, Lid = lid, Lash = lash, Brow = brow }
		for n = 0, 1 do
			h("WarPaint", Vector3.new(0.26, 0.045, 0.04), CFrame.new(side * 0.36, -0.2 - n * 0.08, -0.69) * CFrame.Angles(0, 0, side * 0.25), if n == 0 then Giant.PINK else Giant.VIOLET, neon)
		end
		h("Ear", Vector3.one * 0.34, CFrame.new(side * 0.66, -0.05, 0.05), skin)
		h("Earring", Vector3.new(0.06, 0.24, 0.24), CFrame.new(side * 0.7, -0.32, 0.05), gold, foil)
		h("EarGem", Vector3.new(0.08, 0.1, 0.1), CFrame.new(side * 0.71, -0.32, 0.05) * CFrame.Angles(math.rad(45), 0, 0), Giant.CYAN, neon)
		for n = 0, 2 do
			h("SideHair", Vector3.new(0.06, 0.16, 0.24), CFrame.new(side * 0.64, 0.2 + n * 0.1, 0.18 + n * 0.08) * CFrame.Angles(if n % 2 == 0 then 0.6 else -0.6, 0, 0), BLACK)
		end
		-- the circlet round his head
		h("Circlet", Vector3.new(0.06, 0.14, 1.32), CFrame.new(side * 0.66, 0.5, 0), gold, foil)
		h("CircletGem", Vector3.new(0.12, 0.12, 0.08), CFrame.new(side * 0.36, 0.5, -0.67) * CFrame.Angles(0, 0, math.rad(45)), Giant.PINK, neon)
		-- a determined frown
		h("MouthCorner", Vector3.new(0.12, 0.06, 0.05), CFrame.new(side * 0.25, -0.39, -0.69) * CFrame.Angles(0, 0, side * 0.5), rgb(50, 20, 40))
	end
	h("Circlet", Vector3.new(1.32, 0.14, 0.06), CFrame.new(0, 0.5, -0.66), gold, foil)
	h("Circlet", Vector3.new(1.32, 0.14, 0.06), CFrame.new(0, 0.5, 0.66), gold, foil)
	h("CircletJewel", Vector3.new(0.2, 0.2, 0.1), CFrame.new(0, 0.52, -0.7) * CFrame.Angles(0, 0, math.rad(45)), Giant.CYAN, neon)
	h("Nose", Vector3.new(0.28, 0.28, 0.46), CFrame.new(0, -0.12, -0.72), skin)
	h("Stubble", Vector3.new(0.95, 0.62, 0.7), CFrame.new(0, -0.33, -0.33), rgb(120, 85, 180))
	local r = Random.new(9)
	for _ = 1, 7 do
		h("StubbleStar", Vector3.new(0.05, 0.05, 0.03), CFrame.new(r:NextNumber(-0.4, 0.4), r:NextNumber(-0.58, -0.18), -0.69) * CFrame.Angles(0, 0, math.rad(45)), WHITE, neon)
	end
	h("Mouth", Vector3.new(0.4, 0.07, 0.05), CFrame.new(0, -0.36, -0.69), rgb(50, 20, 40))
	-- his famous two hairs, glowing, with a star on each tip
	for i, x in { -0.12, 0.12 } do
		local hair = CFrame.new(x, 0.78, -0.02) * CFrame.Angles(0, 0, x * -2.2)
		h("Hair" .. i, Vector3.new(0.05, 0.42, 0.05), hair, Giant.CYAN, neon)
		h("HairStar", Vector3.new(0.1, 0.1, 0.04), hair * CFrame.new(0, 0.22, 0) * CFrame.Angles(0, 0, math.rad(45)), WHITE, neon)
	end

	----------------------------------------------------------------------------
	-- A crown of planets circling over his head
	local crown = piece()
	for i = 0, 11 do
		local angle = i / 12 * math.pi * 2
		local size = (if i % 3 == 0 then 0.28 else 0.16) * S
		add(crown, model, "CrownPlanet", Vector3.one * size, CFrame.new(math.cos(angle) * 0.95 * S, 0, math.sin(angle) * 0.95 * S), if i % 3 == 0 then gold elseif i % 2 == 0 then Giant.CYAN else Giant.PINK, neon)
	end
	-- a great halo of starlight behind his head
	local halo = piece()
	ringOf(halo, model, "Halo", CFrame.identity, 1.35 * S, 28, Vector3.new(0.34, 0.1, 0.06) * S, { Giant.VIOLET, Giant.PINK }, neon, 0.15)
	ringOf(halo, model, "HaloInner", CFrame.identity, 1.12 * S, 22, Vector3.new(0.3, 0.05, 0.05) * S, { WHITE }, neon, 0.35)
	for i = 0, 7 do
		local angle = i / 8 * math.pi * 2
		local long = if i % 2 == 0 then 0.75 else 0.45
		add(halo, model, "HaloRay", Vector3.new(0.12, long, 0.05) * S, CFrame.Angles(0, 0, angle) * CFrame.new(0, (1.45 + long / 2) * S, 0), if i % 2 == 0 then gold else Giant.CYAN, neon)
	end
	-- two rings spinning round the reactor
	local coreRings = { piece(), piece() }
	ringOf(coreRings[1], model, "CoreRing", CFrame.identity, 0.5 * S, 10, Vector3.new(0.16, 0.09, 0.08) * S, { Giant.PINK, gold }, neon)
	ringOf(coreRings[2], model, "CoreRing", CFrame.identity, 0.68 * S, 14, Vector3.new(0.14, 0.06, 0.06) * S, { Giant.CYAN, WHITE }, neon, 0.2)
	-- a little moon circling each shoulder
	local moons = {}
	for i, side in { "Left", "Right" } do
		local moon = piece()
		add(moon, model, "Moon", Vector3.one * 0.38 * S, CFrame.Angles(0.3, 0.6, 0.2), if i == 1 then rgb(150, 170, 255) else rgb(255, 170, 120))
		ringOf(moon, model, "MoonRing", CFrame.Angles(math.rad(70), 0, 0), 0.36 * S, 10, Vector3.new(0.12, 0.04, 0.03) * S, { WHITE, Giant.CYAN }, neon, 0.2)
		moons[side] = moon
	end
	-- asteroids circling his waist, some cracked and glowing
	local asteroids = piece()
	local ra = Random.new(17)
	for i = 1, 14 do
		local angle = i / 14 * math.pi * 2 + ra:NextNumber(-0.2, 0.2)
		local size = ra:NextNumber(0.18, 0.42) * S
		local at = CFrame.new(math.cos(angle) * ra:NextNumber(3.0, 3.7) * S, ra:NextNumber(-0.3, 0.9) * S, math.sin(angle) * ra:NextNumber(2.2, 2.8) * S) * CFrame.Angles(ra:NextNumber(0, 3), ra:NextNumber(0, 3), ra:NextNumber(0, 3))
		add(asteroids, model, "Asteroid", Vector3.new(size, size * 0.8, size * 0.9), at, rgb(70, 56, 90), Enum.Material.Slate)
		if i % 3 == 0 then
			add(asteroids, model, "AsteroidCrack", Vector3.new(size * 0.1, size * 0.85, size * 0.95), at, Giant.PINK, neon)
		end
	end
	-- a cape of night sky hanging from his shoulders (its frame is the top of it)
	local cape = piece()
	for i = -3, 3 do
		local panel = CFrame.new(i * 0.42 * S, 0, 0) * CFrame.Angles(0, i * -0.08, i * 0.05) * CFrame.new(0, -1.7 * S, 0)
		local color = armour:Lerp(rgb(30, 40, 140), (i + 3) / 6)
		add(cape, model, "Cape", Vector3.new(0.46, 3.4, 0.08) * S, panel, color)
		add(cape, model, "CapeEdge", Vector3.new(0.48, 0.07, 0.1) * S, panel * CFrame.new(0, -1.7 * S, 0), if i % 2 == 0 then Giant.PINK else Giant.CYAN, neon)
		local rs = Random.new(30 + i)
		for _ = 1, 3 do
			add(cape, model, "CapeStar", Vector3.new(0.06, 0.06, 0.04) * S, panel * CFrame.new(rs:NextNumber(-0.18, 0.18) * S, rs:NextNumber(-1.5, 1.5) * S, 0.06 * S) * CFrame.Angles(0, 0, math.rad(45)), WHITE, neon)
		end
	end

	----------------------------------------------------------------------------
	-- Arms: banded sleeves, elbow spikes, gauntlets with glowing runes, fists with gold knuckles
	local arms = {}
	local fists: { [string]: BasePart }, palms: { [string]: BasePart } = {}, {}
	for _, side in { "Left", "Right" } do
		local upper, fore, fist = piece(), piece(), piece()
		local U, F = Giant.UPPER * S, Giant.FORE * S
		add(upper, model, "ShoulderJoint", Vector3.one * 1.3 * S, CFrame.new(0, -0.2 * S, 0), dark)
		add(upper, model, "Sleeve", Vector3.new(1.15 * S, U, 1.15 * S), CFrame.new(0, -U / 2, 0), armour)
		for i, y in { 0.28, 0.5, 0.72 } do
			add(upper, model, "SleeveBand", Vector3.new(1.22, 0.12, 1.22) * S, CFrame.new(0, -U * y, 0), if i == 2 then gold else Giant.PINK, if i == 2 then foil else neon)
		end
		stars(upper, model, CFrame.new(0, -U / 2, 0), 0.9 * S, U * 0.8, 1.15 * S, 8, if side == "Left" then 11 else 12)
		add(upper, model, "ElbowGuard", Vector3.new(1.32, 0.72, 1.32) * S, CFrame.new(0, -U + 0.1 * S, 0), light)
		add(upper, model, "ElbowSpike", Vector3.new(0.26, 0.8, 0.26) * S, CFrame.new(0, -U + 0.05 * S, 0.75 * S) * CFrame.Angles(math.rad(70), 0, 0), Giant.VIOLET, neon)
		add(fore, model, "Forearm", Vector3.new(1.05 * S, F, 1.05 * S), CFrame.new(0, -F / 2, 0), skin)
		add(fore, model, "Gauntlet", Vector3.new(1.17 * S, F * 0.55, 1.17 * S), CFrame.new(0, -F * 0.72, 0), armour)
		add(fore, model, "GauntletRim", Vector3.new(1.22 * S, 0.12 * S, 1.22 * S), CFrame.new(0, -F * 0.45, 0), gold, foil)
		add(fore, model, "Cuff", Vector3.new(1.24 * S, 0.16 * S, 1.24 * S), CFrame.new(0, -F + 0.08 * S, 0), Giant.CYAN, neon)
		for n = -1, 1 do
			add(fore, model, "Rune", Vector3.new(0.07 * S, F * 0.38, 0.05 * S), CFrame.new(n * 0.3 * S, -F * 0.72, -0.6 * S), if n == 0 then Giant.PINK else Giant.CYAN, neon)
		end
		local fs = Giant.FIST * S
		fists[side] = add(fist, model, "Fist", Vector3.one * fs, CFrame.new(0, -fs / 2, 0), skin)
		for n = 0, 3 do
			add(fist, model, "Finger", Vector3.new(fs * 0.23, fs * 0.34, fs * 0.3), CFrame.new((n - 1.5) * fs * 0.25, -fs * 0.74, -fs * 0.38), skin:Lerp(BLACK, 0.08))
		end
		add(fist, model, "KnuckleGuard", Vector3.new(fs * 1.06, fs * 0.18, fs * 0.12), CFrame.new(0, -fs * 0.6, -fs * 0.55), gold, foil)
		add(fist, model, "Thumb", Vector3.new(fs * 0.3, fs * 0.5, fs * 0.3), CFrame.new((if side == "Left" then 1 else -1) * fs * 0.52, -fs * 0.45, -fs * 0.2), skin)
		add(fist, model, "HandStar", Vector3.new(fs * 0.25, fs * 0.25, fs * 0.06), CFrame.new(0, -fs * 0.5, fs * 0.51) * CFrame.Angles(0, 0, math.rad(45)), Giant.CYAN, neon)
		palms[side] = add(fist, model, "Palm", Vector3.new(fs * 0.6, fs * 0.6, fs * 0.05), CFrame.new(0, -fs * 0.5, -fs * 0.52), Giant.PINK, neon, 0.5)
		arms[side] = { Upper = upper, Fore = fore, Fist = fist }
	end

	----------------------------------------------------------------------------
	-- The hole: a black core, a thin white ring of bent light, a swirling glowing disk, spiral arms
	-- pouring in, and the sky torn round its edge
	local portal = piece()
	local R = Giant.PORTAL_RADIUS
	local hole = add(portal, model, "HoleCore", Vector3.new(4, R * 1.7, R * 1.7), CFrame.Angles(0, math.pi / 2, 0), rgb(4, 2, 10))
	hole.Shape = Enum.PartType.Cylinder
	local haze = add(portal, model, "HoleHaze", Vector3.new(1, R * 2.7, R * 2.7), CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(-6, 0, 0), rgb(120, 60, 220), neon, 0.82)
	haze.Shape = Enum.PartType.Cylinder
	local rt = Random.new(23)
	for i = 0, 19 do
		local angle = i / 20 * math.pi * 2 + rt:NextNumber(-0.1, 0.1)
		local length = rt:NextNumber(0.18, 0.4) * R
		local at = CFrame.Angles(0, 0, angle) * CFrame.new(R * rt:NextNumber(1.3, 1.42), 0, 4) * CFrame.Angles(0, 0, rt:NextNumber(-0.5, 0.5))
		add(portal, model, "Tear", Vector3.new(length, rt:NextNumber(4, 9), 1.5), at, rgb(30, 14, 60))
		add(portal, model, "TearGlow", Vector3.new(length * 0.9, 1.2, 1.6), at * CFrame.new(0, -2, -0.2), if i % 2 == 0 then Giant.PINK else Giant.CYAN, neon)
	end
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
		ringOf(ring, model, "HoleRing", CFrame.new(0, 0, -1), spec.Radius, spec.Count, Vector3.new(chord, spec.Width, 0.6), spec.Colors, neon, spec.Transparency)
		table.insert(rings, ring)
	end
	local swirl = piece()
	for arm = 0, 5 do
		for n = 0, 8 do
			local t = n / 8
			local radius = R * (0.82 - t * 0.6)
			local angle = arm / 6 * math.pi * 2 + t * 2.4
			local size = (1 - t * 0.6) * 0.3 * S
			add(swirl, model, "Swirl", Vector3.new(size * 2.2, size, 0.5), CFrame.new(math.cos(angle) * radius, math.sin(angle) * radius, -2.5) * CFrame.Angles(0, 0, angle + math.pi / 2 + 0.5), if arm % 2 == 0 then Giant.VIOLET else Giant.PINK, neon, 0.25 + t * 0.4)
		end
	end
	return {
		Model = model,
		Body = body,
		Arms = arms,
		Crown = crown,
		Halo = halo,
		CoreRings = coreRings,
		Moons = moons,
		Asteroids = asteroids,
		Cape = cape,
		Portal = portal,
		Rings = rings,
		Swirl = swirl,
		Core = core,
		Irises = irises,
		Eyes = eyes,
		Fists = fists,
		Palms = palms,
	}
end

-- Where a piece's parts go, with the piece's frame at `cf` (added to `parts` / `frames`, so the
-- client can move everything in one go).
function Giant.Collect(p: Piece, cf: CFrame, parts: { BasePart }, frames: { CFrame })
	for _, item in p.Parts do
		table.insert(parts, item.Part)
		table.insert(frames, cf * item.Offset)
	end
end

-- Put a piece's parts where they go, with the piece's frame at `cf`.
function Giant.Place(p: Piece, cf: CFrame)
	for _, item in p.Parts do
		item.Part.CFrame = cf * item.Offset
	end
end

return Giant
