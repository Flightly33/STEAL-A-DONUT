--[[
	GuardNaps: how each later biome's Domer sleeps (biomes 5 and up; the first ones sleep on their
	couch, GuardModel.Sleep). Every biome has its own pose and its own bed:

	   5 Glacier Glaze      zipped into a puffy sleeping bag, a mug of hot cocoa beside him
	   6 Molten Bakery      soaking in a hot tub of bubbling caramel, arms along the rim, a rubber duck
	   7 Chocolate Caverns  face down in a food coma on a giant chocolate bar, a bitten donut in reach
	   8 Candy Cane Canyon  in a hammock slung between two candy canes, one arm dangling a lollipop
	   9 Toy Factory        slumped in a beanbag, a game controller still in his hands
	  10 Haunted Donuttery  in a comfy coffin with a cushion, arms folded, candles either side
	  11 Cloud Bakery       on a fluffy cloud mattress, hands behind his head, ankles crossed
	  12 Neon Streets       head down on his gaming desk, the monitor still glowing
	  13 Robot Factory      in a recliner with his feet up, the remote in his hand
	  14 Clockwork Void     draped over the top of a giant gear
	  15 Donut Heaven       floating on a donut pool float, arms spread
	  16 Glitch Zone        stuck floating in a glitched T-pose (the client jitters him)
	  17 The Black Hole     curled up, floating in zero gravity with a sleep mask, hugging a moon
	                        pillow (the client turns him slowly)

	GuardNaps.Pose(model, areaId, home) poses a model from GuardModel.Build: eyes shut, mouth open,
	every part anchored and the joints removed, put in place at `home` (a CFrame on the floor, -Z
	facing the lane). Returns his mouth (the Z's come out of it) and his bed and things as a model of
	their own (they stay when he gets up to chase you). Only the client uses it.
]]

local GuardNaps = {}

local rgb = Color3.fromRGB
local WHITE = rgb(255, 255, 255)
local BLACK = rgb(25, 25, 25)
local rad = math.rad
local TAU = math.pi * 2

type Rig = {
	Model: Model,
	Props: Model,
	s: number, -- the model's scale (1 rig unit = s studs: a standing Domer is about 6 units tall)
	Origin: CFrame, -- his root, standing (every pose is worked out in this space first)
	Groups: { [BasePart]: { BasePart } },
	Head: BasePart,
	HeadParts: { BasePart },
	Home: CFrame,
	Placed: CFrame?,
}

local STUD_FACES = { "TopSurface", "BottomSurface", "FrontSurface", "BackSurface", "LeftSurface", "RightSurface" }

local function newPart(parent: Instance, name: string, size: Vector3, color: Color3, cf: CFrame, material: Enum.Material?, studs: boolean?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.CFrame = cf
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = material or Enum.Material.SmoothPlastic
	if studs then
		for _, face in STUD_FACES do
			(part :: any)[face] = Enum.SurfaceType.Studs
		end
		if part.Material == Enum.Material.SmoothPlastic then
			part.Material = Enum.Material.Plastic
		end
	end
	part.Parent = parent
	return part
end

-- Anchors him, removes his joints, groups his pieces by the body part they're welded to, shuts
-- his eyes and opens his mouth.
local function prepare(model: Model, home: CFrame): Rig?
	local root = model.PrimaryPart
	local torso = model:FindFirstChild("Torso") :: BasePart?
	local head = model:FindFirstChild("Head") :: BasePart?
	if not root or not torso or not head then
		return nil
	end
	local s = torso.Size.Y / 2
	local groups: { [BasePart]: { BasePart } } = {}
	local joints = {}
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			local weld = item:FindFirstChildOfClass("Weld")
			local base = if weld and weld.Part0 then weld.Part0 else item
			groups[base] = groups[base] or {}
			table.insert(groups[base], item)
		elseif item:IsA("JointInstance") then
			table.insert(joints, item)
		end
	end
	for _, joint in joints do
		joint:Destroy()
	end
	local props = Instance.new("Model")
	props.Name = "NapProps"
	local rig: Rig = {
		Model = model,
		Props = props,
		s = s,
		Origin = root.CFrame,
		Groups = groups,
		Head = head,
		HeadParts = groups[head] or { head },
		Home = home,
		Placed = nil,
	}
	-- eyes shut (thick lines), mouth open
	for _, part in rig.HeadParts do
		if part.Name == "Eye" or part.Name == "Pupil" then
			part.Transparency = 1
		elseif part.Name == "Mouth" then
			part.Size = Vector3.new(0.3, 0.2, 0.06) * s
			part.Color = rgb(70, 25, 25)
		end
	end
	for _, side in { -1, 1 } do
		local x = side * 0.27
		local function bar(dx: number, dy: number, width: number, tilt: number)
			local cf = head.CFrame * CFrame.new((x + dx) * s, (0.1 + dy) * s, -0.67 * s) * CFrame.Angles(0, 0, tilt)
			table.insert(rig.HeadParts, newPart(model, "ClosedEye", Vector3.new(width, 0.075, 0.05) * s, rgb(35, 20, 20), cf))
		end
		bar(0, 0, 0.24, 0)
		bar(-0.15, 0.04, 0.13, rad(-38))
		bar(0.15, 0.04, 0.13, rad(38))
	end
	return rig
end

-- Turn `parts` by `rotation` round `pivot` (in rig units, in his standing space).
local function turn(rig: Rig, parts: { BasePart }, pivot: Vector3, rotation: CFrame)
	local at = rig.Origin * CFrame.new(pivot * rig.s)
	local change = at * rotation * at:Inverse()
	for _, part in parts do
		part.CFrame = change * part.CFrame
	end
end

-- The rotation that turns "straight down" to point along `to`.
local function aim(to: Vector3): CFrame
	local from = Vector3.new(0, -1, 0)
	local unit = to.Unit
	local axis = from:Cross(unit)
	if axis.Magnitude < 1e-4 then
		return if from:Dot(unit) > 0 then CFrame.identity else CFrame.Angles(0, 0, math.pi)
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(from:Dot(unit), -1, 1)))
end

local function limbParts(rig: Rig, name: string): ({ BasePart }, BasePart?)
	local limb = rig.Model:FindFirstChild(name) :: BasePart?
	return if limb then rig.Groups[limb] or { limb } else {}, limb
end

-- An arm: the upper arm points along `upper` (from the shoulder, standing space), the forearm
-- along `lower` (bent at the elbow; nil = straight on).
local function arm(rig: Rig, side: number, upper: Vector3, lower: Vector3?)
	local parts, limb = limbParts(rig, if side < 0 then "Left Arm" else "Right Arm")
	if not limb then
		return
	end
	limb.Transparency = 1 -- (the straight arm block underneath can't bend: its pieces show it)
	local forearm = {}
	for _, part in parts do
		if part.Name == "Forearm" or part.Name == "Hand" then
			table.insert(forearm, part)
		end
	end
	local shoulder = Vector3.new(side * 1.5, 0.5, 0)
	local raise = aim(upper)
	turn(rig, parts, shoulder, raise)
	if lower then
		local elbow = shoulder + upper.Unit * 0.9
		local from = upper.Unit
		local to = lower.Unit
		local axis = from:Cross(to)
		if axis.Magnitude > 1e-4 then
			turn(rig, forearm, elbow, CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(from:Dot(to), -1, 1))))
		end
	end
end

-- A leg pointing along `dir` from the hip (standing space).
local function leg(rig: Rig, side: number, dir: Vector3)
	local parts = limbParts(rig, if side < 0 then "Left Leg" else "Right Leg")
	turn(rig, parts, Vector3.new(side * 0.5, -1, 0), aim(dir))
end

local function nod(rig: Rig, rotation: CFrame)
	turn(rig, rig.HeadParts, Vector3.new(0, 1, 0), rotation)
end

local function hand(rig: Rig, side: number): CFrame
	local parts = limbParts(rig, if side < 0 then "Left Arm" else "Right Arm")
	for _, part in parts do
		if part.Name == "Hand" then
			return part.CFrame
		end
	end
	return rig.Origin
end

-- A piece that moves with him (`cf` in rig units: his standing space, or given straight as a world
-- CFrame when `world` is set, e.g. a hand's).
local function piece(rig: Rig, name: string, size: Vector3, color: Color3, cf: CFrame, material: Enum.Material?, studs: boolean?): Part
	local at = rig.Origin * CFrame.new(cf.Position * rig.s) * cf.Rotation
	return newPart(rig.Model, name, size * rig.s, color, at, material, studs)
end
local function held(rig: Rig, name: string, size: Vector3, color: Color3, at: CFrame, offset: CFrame, material: Enum.Material?): Part
	local cf = at * CFrame.new(offset.Position * rig.s) * offset.Rotation
	local part = newPart(rig.Model, name, size * rig.s, color, cf, material)
	part:SetAttribute("Held", true) -- (place: not part of his body)
	return part
end

-- Puts him in place: `rotation` turns him (from standing), and he's moved so the lowest point of
-- his body (not his arms; or only of the body parts named in `only`) sits at `y` rig units above
-- the floor, his middle at x, z.
local function place(rig: Rig, rotation: CFrame, x: number, y: number, z: number, only: { string }?)
	local s = rig.s
	local inverse = rig.Origin:Inverse()
	local lowest = math.huge
	local skip: { [BasePart]: boolean } = {}
	for _, name in { "Left Arm", "Right Arm" } do
		for _, part in limbParts(rig, name) do
			skip[part] = true
		end
	end
	local keep: { [BasePart]: boolean }? = nil
	if only then
		local set: { [BasePart]: boolean } = {}
		for _, name in only do
			for _, part in limbParts(rig, name) do
				set[part] = true
			end
		end
		keep = set
	end
	for _, part in rig.Model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 and not skip[part] and (not keep or keep[part]) and not part:GetAttribute("Held") then
			local local_ = rotation * inverse * part.CFrame
			local half = part.Size / 2
			for _, cx in { -1, 1 } do
				for _, cy in { -1, 1 } do
					for _, cz in { -1, 1 } do
						lowest = math.min(lowest, (local_ * Vector3.new(cx * half.X, cy * half.Y, cz * half.Z)).Y)
					end
				end
			end
		end
	end
	local placed = rig.Home * CFrame.new(x * s, y * s - lowest, z * s) * rotation
	rig.Model:PivotTo(placed)
	rig.Placed = placed
	rig.Origin = placed
end

-- A piece of his bed and things (`cf` in rig units, on the floor at his home; -Z towards the lane).
local function prop(rig: Rig, name: string, size: Vector3, color: Color3, cf: CFrame, material: Enum.Material?, studs: boolean?): Part
	local at = rig.Home * CFrame.new(cf.Position * rig.s) * cf.Rotation
	return newPart(rig.Props, name, size * rig.s, color, at, material, if studs == nil then true else studs)
end

-- A flat round disc lying on the floor (rig units, home space; `at` = its middle).
local function disc(rig: Rig, name: string, diameter: number, thick: number, color: Color3, at: Vector3, material: Enum.Material?): Part
	local part = prop(rig, name, Vector3.new(thick, diameter, diameter), color, CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2), material, false)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- A round puff (rig units, home space).
local function ball(rig: Rig, name: string, diameter: number, color: Color3, at: Vector3, material: Enum.Material?): Part
	local part = prop(rig, name, Vector3.one * diameter, color, CFrame.new(at), material, false)
	part.Shape = Enum.PartType.Ball
	return part
end

-- A beam-like block from a to b (rig units, home space).
local function strut(rig: Rig, name: string, a: Vector3, b: Vector3, thick: number, color: Color3, material: Enum.Material?): Part
	local middle = (a + b) / 2
	local cf = CFrame.lookAt(middle, b)
	return prop(rig, name, Vector3.new(thick, thick, (b - a).Magnitude), color, cf, material, false)
end

-- A ring of blocks (a round tub, a float, a gear): `count` blocks round a circle of `radius` on the
-- plane of `frame` (its X and Z), each `size` (X along the ring, Y up, Z out).
local function ring(rig: Rig, name: string, frame: CFrame, radius: number, count: number, size: Vector3, color: Color3 | (number) -> Color3, material: Enum.Material?, studs: boolean?, skip: { [number]: boolean }?)
	for i = 0, count - 1 do
		if not (skip and skip[i]) then
			local angle = i / count * TAU
			local cf = frame * CFrame.Angles(0, -angle, 0) * CFrame.new(0, 0, -radius)
			local c = if type(color) == "function" then color(i) else color
			prop(rig, name, size, c, cf, material, studs)
		end
	end
end

local function emitter(parent: BasePart, color: Color3, rate: number, size: number, speed: number, lifetime: number, rise: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.Rate = rate
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.5), NumberSequenceKeypoint.new(1, size) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.Lifetime = NumberRange.new(lifetime * 0.7, lifetime)
	e.EmissionDirection = Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(20, 20)
	e.Acceleration = Vector3.new(0, rise, 0)
	e.LightInfluence = 0.5
	e.Parent = parent
	return e
end

-- Wide hats come off (lying down, the brim would stick through his bed): moved to `cf` (rig units,
-- home space; the hat's crown at its middle). Call after place.
local WIDE_HATS = { Hat = true, HatTop = true, HatBand = true, HatCone = true, Flower = true, HatBrim = true }
local function hatOff(rig: Rig, cf: CFrame)
	local top = rig.Head.CFrame * CFrame.new(0, 0.62 * rig.s, 0)
	local spot = rig.Home * CFrame.new(cf.Position * rig.s) * cf.Rotation
	for _, part in rig.HeadParts do
		if WIDE_HATS[part.Name] then
			part.CFrame = spot * top:ToObjectSpace(part.CFrame)
			part.Parent = rig.Props
		end
	end
end

-- The standing-space directions below: +X his right, +Y up, -Z his front.
local ON_BACK = CFrame.Angles(rad(90), 0, 0) -- front up, head towards +Z
local FACE_DOWN = CFrame.Angles(rad(-90), 0, 0) -- front down, head towards -Z
local HEAD_RIGHT = CFrame.Angles(0, rad(-90), 0) -- (then) head towards +X... see each pose

local Poses: { [number]: (Rig) -> () } = {}

-- 5 Glacier Glaze: snuggled into a puffy sleeping bag up to his belly, hands folded on top of it,
-- his beanie on, a pillow under his head and a mug of hot cocoa (still steaming) beside him.
Poses[5] = function(rig)
	for _, side in { -1, 1 } do
		arm(rig, side, Vector3.new(side * 0.12, -1, -0.55), Vector3.new(-side * 0.8, -0.1, -0.6)) -- hands folded on the bag
		leg(rig, side, Vector3.new(-side * 0.03, -1, 0))
	end
	nod(rig, CFrame.Angles(0, rad(18), 0) * CFrame.Angles(rad(-12), 0, 0))
	local blue, light = rgb(255, 130, 60), rgb(255, 235, 200) -- (warm orange: he's dressed in blue)
	-- (the bag: up over his legs and belly, its open top folded back; flat under his back and head)
	piece(rig, "SleepingBag", Vector3.new(3.9, 3.5, 1.55), blue, CFrame.new(0, -2.15, -0.12), nil, true)
	piece(rig, "SleepingBag", Vector3.new(3.2, 0.5, 1.2), blue:Lerp(BLACK, 0.12), CFrame.new(0, -4.05, -0.08), nil, true)
	for _, y in { -1.6, -2.5, -3.4 } do
		piece(rig, "Quilt", Vector3.new(3.95, 0.12, 0.05), blue:Lerp(BLACK, 0.3), CFrame.new(0, y, -0.9))
	end
	piece(rig, "BagFlap", Vector3.new(4.1, 0.55, 1.75), light, CFrame.new(0, -0.45, -0.12), nil, true)
	piece(rig, "BagBack", Vector3.new(4.4, 3.4, 0.3), light, CFrame.new(0, 1.0, 0.92), nil, true)
	piece(rig, "Zip", Vector3.new(0.12, 3.4, 0.06), rgb(255, 215, 60), CFrame.new(1.4, -2.2, -0.9), Enum.Material.Foil)
	piece(rig, "Pillow", Vector3.new(2.6, 1.4, 0.5), WHITE, CFrame.new(0, 1.85, 0.62), nil, true)
	place(rig, CFrame.Angles(0, rad(-90), 0) * ON_BACK, 0, 0.25, 0)
	-- a soft patch of snow under him and the mug of cocoa beside his head
	prop(rig, "Snow", Vector3.new(7.8, 0.25, 4.4), rgb(235, 245, 255), CFrame.new(0, 0.12, 0), nil, false)
	local mug = prop(rig, "Mug", Vector3.new(0.7, 0.8, 0.7), rgb(220, 70, 70), CFrame.new(-4.0, 0.4, -1.6))
	prop(rig, "MugHandle", Vector3.new(0.2, 0.45, 0.4), rgb(220, 70, 70), CFrame.new(-4.45, 0.45, -1.6))
	prop(rig, "Cocoa", Vector3.new(0.56, 0.06, 0.56), rgb(110, 60, 30), CFrame.new(-4.0, 0.8, -1.6), nil, false)
	emitter(mug, WHITE, 2, 0.6 * rig.s, 0.6 * rig.s, 2, 0.3 * rig.s)
end

-- 6 Molten Bakery: soaking in a round hot tub of bubbling caramel, leaning back, arms out along
-- the rim, head back, a rubber duck bobbing beside him.
Poses[6] = function(rig)
	for _, side in { -1, 1 } do
		arm(rig, side, Vector3.new(side * 1, 0.05, 0.15))
		leg(rig, side, Vector3.new(side * 0.15, -0.35, -1))
	end
	nod(rig, CFrame.Angles(rad(28), 0, rad(10)))
	place(rig, CFrame.Angles(rad(30), 0, 0), 0, 0.75, 1.0)
	local iron, rim = rgb(90, 50, 40), rgb(255, 160, 70)
	disc(rig, "TubFloor", 8.6, 0.6, iron, Vector3.new(0, 0.3, 0))
	ring(rig, "TubWall", CFrame.new(0, 1.7, 0), 4.0, 12, Vector3.new(2.2, 2.8, 0.7), iron)
	ring(rig, "TubRim", CFrame.new(0, 3.2, 0), 4.0, 12, Vector3.new(2.3, 0.3, 1.0), rim)
	local syrup = disc(rig, "Caramel", 7.4, 0.2, rgb(255, 150, 40), Vector3.new(0, 2.5, 0), Enum.Material.Neon)
	syrup.Transparency = 0.25
	emitter(syrup, rgb(255, 200, 120), 6, 0.5 * rig.s, 0.4 * rig.s, 1.2, 0.2 * rig.s).Name = "Bubbles"
	emitter(syrup, rgb(255, 240, 220), 2, 1.4 * rig.s, 0.5 * rig.s, 3, 0.2 * rig.s).Name = "Steam"
	-- the duck
	prop(rig, "DuckBody", Vector3.new(0.9, 0.6, 1.1), rgb(255, 220, 40), CFrame.new(-2.4, 2.75, -1.6) * CFrame.Angles(0, rad(30), 0))
	prop(rig, "DuckHead", Vector3.new(0.55, 0.55, 0.55), rgb(255, 220, 40), CFrame.new(-2.55, 3.25, -1.95) * CFrame.Angles(0, rad(30), 0))
	prop(rig, "DuckBeak", Vector3.new(0.3, 0.15, 0.3), rgb(255, 130, 30), CFrame.new(-2.7, 3.2, -2.25) * CFrame.Angles(0, rad(30), 0), nil, false)
	-- steps up to the tub
	prop(rig, "Step", Vector3.new(3, 0.8, 1.4), iron:Lerp(WHITE, 0.15), CFrame.new(0, 0.4, -5.0))
end

-- 7 Chocolate Caverns: face down in a food coma, head turned towards you on a giant chocolate bar,
-- one arm stretched out to a bitten donut, empty donut boxes piled by his feet.
Poses[7] = function(rig)
	arm(rig, 1, Vector3.new(0.45, 1, -0.15))
	arm(rig, -1, Vector3.new(-0.35, -1, -0.25), Vector3.new(0.1, -0.6, -1))
	leg(rig, 1, Vector3.new(0.12, -1, 0))
	leg(rig, -1, Vector3.new(-0.12, -1, 0.05))
	nod(rig, CFrame.Angles(0, rad(85), 0))
	-- face down, head towards +X, his left side (and his face) towards the lane
	place(rig, CFrame.Angles(0, rad(-90), 0) * FACE_DOWN, -0.4, 0.45, 0)
	local choc, light = rgb(95, 55, 35), rgb(130, 80, 50)
	prop(rig, "ChocolateBar", Vector3.new(3.4, 0.45, 2.6), choc, CFrame.new(2.6, 0.22, -0.2))
	for i = -1, 1 do
		prop(rig, "BarSquare", Vector3.new(0.95, 0.12, 2.3), light, CFrame.new(2.6 + i * 1.1, 0.5, -0.2), nil, false)
	end
	-- the bitten donut (a ring with a bite out of it)
	local donut = CFrame.new(5.6, 0.35, -1.4)
	ring(rig, "Donut", donut, 0.95, 10, Vector3.new(0.65, 0.7, 0.75), rgb(225, 170, 100), nil, false, { [2] = true })
	ring(rig, "DonutGlaze", donut * CFrame.new(0, 0.38, 0), 0.95, 10, Vector3.new(0.62, 0.12, 0.72), rgb(255, 140, 190), nil, false, { [2] = true, [3] = true })
	-- empty donut boxes by his feet
	for i, cf in { CFrame.new(-5.2, 0.5, 1.4) * CFrame.Angles(0, rad(20), 0), CFrame.new(-5.6, 1.5, 1.2) * CFrame.Angles(0, rad(-12), 0), CFrame.new(-4.6, 0.5, -1.4) * CFrame.Angles(0, rad(40), rad(8)) } do
		prop(rig, "DonutBox", Vector3.new(2.2, 1, 2.2), if i % 2 == 0 then rgb(255, 150, 200) else rgb(255, 205, 225), cf)
		prop(rig, "BoxLid", Vector3.new(2.2, 0.1, 1.1), rgb(255, 245, 250), cf * CFrame.new(0, 0.9, 1.4) * CFrame.Angles(rad(-60), 0, 0), nil, false)
	end
	for i = 1, 8 do
		local a = i * 2.4
		prop(rig, "Crumb", Vector3.one * 0.18, rgb(200, 150, 90), CFrame.new(4.6 + math.cos(a) * 1.4, 0.09, -1.2 + math.sin(a) * 1.1), nil, false)
	end
end

-- 8 Candy Cane Canyon: in a striped hammock slung between two giant candy canes, one arm dangling
-- over the side with a lollipop, the other on his belly.
Poses[8] = function(rig)
	arm(rig, 1, Vector3.new(0.35, -0.25, 1)) -- (dangling: +Z is down, lying on his back)
	arm(rig, -1, Vector3.new(-0.2, -1, -0.35), Vector3.new(0.9, 0.1, -0.45))
	for _, side in { -1, 1 } do
		leg(rig, side, Vector3.new(-side * 0.08, -1, -0.05))
	end
	nod(rig, CFrame.Angles(0, rad(-20), 0) * CFrame.Angles(rad(-10), 0, 0))
	local lolly = hand(rig, 1)
	held(rig, "LollipopStick", Vector3.new(0.12, 1.6, 0.12), WHITE, lolly, CFrame.new(0, -0.6, 0))
	held(rig, "Lollipop", Vector3.new(1.0, 1.0, 0.25), rgb(255, 90, 170), lolly, CFrame.new(0, -1.5, 0), Enum.Material.SmoothPlastic)
	held(rig, "LollipopSwirl", Vector3.new(0.6, 0.6, 0.27), WHITE, lolly, CFrame.new(0, -1.5, 0) * CFrame.Angles(0, 0, rad(45)))
	-- lying on his back along X, head towards +X
	place(rig, CFrame.Angles(0, rad(90), 0) * ON_BACK, 0.4, 3.0, 0)
	-- the hammock: a sagging row of stripes, and ropes up to the canes
	local stripes = { rgb(255, 120, 170), WHITE, rgb(120, 220, 200) }
	local points = { { -5.0, 4.9 }, { -3.4, 3.7 }, { -1.7, 3.05 }, { 0, 2.85 }, { 1.7, 3.05 }, { 3.4, 3.7 }, { 5.0, 4.9 } }
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local from, to = Vector3.new(a[1], a[2], 0), Vector3.new(b[1], b[2], 0)
		local mid = (from + to) / 2
		prop(rig, "Hammock", Vector3.new((to - from).Magnitude + 0.1, 0.18, 3.2), stripes[(i % 3) + 1], CFrame.lookAt(mid, mid + Vector3.new(0, 0, -1), (to - from):Cross(Vector3.new(0, 0, -1)).Unit) , nil, false)
	end
	for _, side in { -1, 1 } do
		local x = side * 6.6
		for k = 0, 9 do
			prop(rig, "CandyCane", Vector3.new(0.75, 0.8, 0.75), if k % 2 == 0 then rgb(230, 40, 50) else WHITE, CFrame.new(x, 0.4 + k * 0.8, 0) * CFrame.Angles(0, rad(k * 12), 0))
		end
		-- the hook at the top, curling over towards the hammock, its end hanging down
		for k = 1, 5 do
			local angle = k / 5 * math.pi
			prop(rig, "CandyCane", Vector3.new(0.7, 0.7, 0.75), if k % 2 == 0 then rgb(230, 40, 50) else WHITE, CFrame.new(x - side * (1 - math.cos(angle)) * 1.0, 7.9 + math.sin(angle) * 1.0, 0) * CFrame.Angles(0, 0, side * angle))
		end
		prop(rig, "CandyCane", Vector3.new(0.7, 0.7, 0.75), rgb(230, 40, 50), CFrame.new(x - side * 2.0, 7.3, 0))
		strut(rig, "Rope", Vector3.new(side * 5.0, 4.9, 1.4), Vector3.new(x, 6.6, 0), 0.12, rgb(240, 230, 210))
		strut(rig, "Rope", Vector3.new(side * 5.0, 4.9, -1.4), Vector3.new(x, 6.6, 0), 0.12, rgb(240, 230, 210))
	end
end

-- 9 Toy Factory: slumped back in a big beanbag, legs out, a game controller still in his hands,
-- toy blocks scattered round.
Poses[9] = function(rig)
	for _, side in { -1, 1 } do
		arm(rig, side, Vector3.new(side * 0.25, -1, -0.45), Vector3.new(-side * 0.75, 0.15, -0.65))
		leg(rig, side, Vector3.new(side * 0.25, -0.75, -1))
	end
	nod(rig, CFrame.Angles(rad(18), 0, rad(-22)))
	local left, right = hand(rig, -1), hand(rig, 1)
	local middle = CFrame.new((left.Position + right.Position) / 2) * rig.Origin.Rotation * CFrame.Angles(rad(-70), 0, 0)
	held(rig, "Controller", Vector3.new(2.3, 0.35, 0.9), rgb(60, 60, 75), middle, CFrame.new(0, 0, 0))
	held(rig, "ButtonA", Vector3.new(0.22, 0.12, 0.22), rgb(255, 70, 70), middle, CFrame.new(0.55, 0.2, -0.1))
	held(rig, "ButtonB", Vector3.new(0.22, 0.12, 0.22), rgb(70, 200, 255), middle, CFrame.new(0.8, 0.2, 0.1))
	held(rig, "Pad", Vector3.new(0.4, 0.12, 0.14), rgb(30, 30, 35), middle, CFrame.new(-0.65, 0.2, 0))
	place(rig, CFrame.Angles(rad(42), 0, 0), 0, 1.0, 0.6)
	local bag, dark = rgb(255, 90, 90), rgb(210, 60, 70)
	prop(rig, "Beanbag", Vector3.new(6.2, 1.6, 5.4), bag, CFrame.new(0, 0.8, 1.0))
	prop(rig, "Beanbag", Vector3.new(5.4, 3.2, 2.0), dark, CFrame.new(0, 2.0, 3.3) * CFrame.Angles(rad(-25), 0, 0))
	for _, side in { -1, 1 } do
		prop(rig, "Beanbag", Vector3.new(1.4, 2.0, 4.2), bag:Lerp(dark, 0.5), CFrame.new(side * 3.0, 1.2, 1.4))
	end
	-- toy blocks
	local toys = { rgb(255, 210, 60), rgb(80, 170, 255), rgb(100, 220, 120), rgb(255, 120, 200) }
	for i, at in { Vector3.new(-4.6, 0.5, -2.4), Vector3.new(-3.6, 0.5, -3.4), Vector3.new(-4.1, 1.5, -2.9), Vector3.new(4.4, 0.5, -3.0), Vector3.new(5.0, 0.5, -1.4) } do
		prop(rig, "ToyBlock", Vector3.one, toys[(i - 1) % #toys + 1], CFrame.new(at) * CFrame.Angles(0, rad(i * 23), 0))
	end
end

-- 10 Haunted Donuttery: in a comfy open coffin with a purple cushion, arms folded on his chest,
-- the lid leaning behind, a candle at each end and his witch hat hung on the lid.
Poses[10] = function(rig)
	for _, side in { -1, 1 } do
		arm(rig, side, Vector3.new(side * 0.1, -1, -0.95), Vector3.new(-side * 1, 0.55, -0.35))
		leg(rig, side, Vector3.new(0, -1, 0))
	end
	-- lying on his back along X, head towards +X
	place(rig, CFrame.Angles(0, rad(90), 0) * ON_BACK, 0.3, 0.8, 0)
	local wood, satin = rgb(70, 45, 70), rgb(150, 100, 200)
	-- the coffin: a six-sided box, wide at his shoulders
	local outline = { Vector3.new(-3.9, 0, -1.3), Vector3.new(1.7, 0, -2.6), Vector3.new(4.3, 0, -1.6), Vector3.new(4.3, 0, 1.6), Vector3.new(1.7, 0, 2.6), Vector3.new(-3.9, 0, 1.3) }
	prop(rig, "CoffinFloor", Vector3.new(8.2, 0.5, 4.6), wood, CFrame.new(0.2, 0.25, 0))
	prop(rig, "Cushion", Vector3.new(7.8, 0.35, 4.0), satin, CFrame.new(0.2, 0.62, 0), Enum.Material.Fabric, false)
	for i = 1, #outline do
		local a, b = outline[i], outline[i % #outline + 1]
		local mid = (a + b) / 2 + Vector3.new(0, 1.0, 0)
		prop(rig, "CoffinSide", Vector3.new(0.4, 2.0, (b - a).Magnitude + 0.4), wood, CFrame.lookAt(mid, mid + (b - a)))
	end
	prop(rig, "Lid", Vector3.new(8.4, 0.4, 4.8), wood:Lerp(WHITE, 0.08), CFrame.new(0.2, 3.0, 3.6) * CFrame.Angles(rad(70), 0, 0))
	prop(rig, "Pumpkin", Vector3.new(1.5, 1.2, 1.5), rgb(255, 140, 30), CFrame.new(-5.2, 0.6, 1.4) * CFrame.Angles(0, rad(30), 0))
	prop(rig, "PumpkinStem", Vector3.new(0.25, 0.4, 0.25), rgb(80, 140, 50), CFrame.new(-5.2, 1.4, 1.4), nil, false)
	for _, dx in { -0.3, 0.3 } do
		prop(rig, "PumpkinEye", Vector3.new(0.25, 0.25, 0.05), rgb(255, 230, 120), CFrame.new(-5.2, 0.7, 1.4) * CFrame.Angles(0, rad(30), 0) * CFrame.new(dx, 0.1, -0.76), Enum.Material.Neon, false)
	end
	hatOff(rig, CFrame.new(-2.6, 4.4, 3.2) * CFrame.Angles(rad(-20), 0, rad(12)))
	for _, side in { -1, 1 } do
		local x = if side > 0 then 5.4 else -4.9
		prop(rig, "CandleStand", Vector3.new(0.8, 0.3, 0.8), rgb(40, 30, 40), CFrame.new(x, 0.15, -2.2))
		prop(rig, "Candle", Vector3.new(0.4, 1.6, 0.4), rgb(245, 240, 225), CFrame.new(x, 1.1, -2.2), nil, false)
		prop(rig, "CandleFlame", Vector3.new(0.22, 0.4, 0.22), rgb(255, 200, 70), CFrame.new(x, 2.1, -2.2), Enum.Material.Neon, false)
	end
end

-- 11 Cloud Bakery: on a fluffy cloud mattress floating off the ground, hands behind his head,
-- ankles crossed, chef's hat still on.
Poses[11] = function(rig)
	for _, side in { -1, 1 } do
		arm(rig, side, Vector3.new(side * 0.55, 1, 0.1), Vector3.new(-side * 0.95, 0.15, 0.4))
	end
	leg(rig, 1, Vector3.new(-0.18, -1, -0.12))
	leg(rig, -1, Vector3.new(0.14, -1, 0.05))
	nod(rig, CFrame.Angles(rad(-6), rad(10), 0))
	place(rig, CFrame.Angles(0, rad(90), 0) * ON_BACK, 0.2, 2.4, 0)
	-- the cloud: a flat bed inside, round puffs all round it
	prop(rig, "Cloud", Vector3.new(9.4, 1.2, 4.2), rgb(255, 225, 240), CFrame.new(0, 1.75, 0), nil, false)
	local tints = { rgb(255, 225, 240), rgb(238, 226, 255), rgb(255, 238, 248) }
	local n = 0
	for _, row in { { -2.05, 0 }, { 2.05, 0.6 } } do
		for i = 0, 5 do
			n += 1
			local x = -4.4 + i * 1.76 + row[2] * 0.5
			ball(rig, "CloudPuff", 2.2 + (n % 3) * 0.35, tints[n % 3 + 1], Vector3.new(x, 1.5 + (n % 2) * 0.25, row[1]))
		end
	end
	for _, at in { Vector3.new(-5.0, 1.7, 0), Vector3.new(5.1, 1.9, 0), Vector3.new(-1.5, 1.3, -2.4), Vector3.new(2.2, 1.3, 2.4) } do
		n += 1
		ball(rig, "CloudPuff", 2.4, tints[n % 3 + 1], at)
	end
	ball(rig, "CloudPillow", 1.9, rgb(250, 242, 255), Vector3.new(4.5, 2.7, 0))
	emitter(prop(rig, "Mist", Vector3.new(8, 0.2, 4), WHITE, CFrame.new(0, 0.5, 0), nil, false), WHITE, 3, 1.6 * rig.s, 0.2 * rig.s, 3, 0).Name = "Mist"
	for _, part in rig.Props:GetChildren() do
		if part.Name == "Mist" and part:IsA("BasePart") then
			part.Transparency = 1
		end
	end
end

-- 12 Neon Streets: fell asleep gaming - slumped forward on his chair, head on his folded arms on
-- the desk, the monitor still glowing and the keyboard lit up.
Poses[12] = function(rig)
	rig.Home = rig.Home * CFrame.Angles(0, rad(150), 0)
	for _, side in { -1, 1 } do
		arm(rig, side, Vector3.new(side * 0.2, -0.15, -1), Vector3.new(-side * 1, -0.05, -0.2))
		leg(rig, side, Vector3.new(side * 0.12, -0.15, -1))
	end
	nod(rig, CFrame.Angles(rad(-40), 0, rad(14)))
	place(rig, CFrame.Angles(rad(-28), 0, 0), 0, 2.3, 0.6, { "Torso", "Left Leg", "Right Leg" })
	local metal, neon = rgb(40, 40, 55), rgb(0, 255, 220)
	-- chair
	prop(rig, "ChairSeat", Vector3.new(3.4, 0.5, 3.0), rgb(30, 30, 40), CFrame.new(0, 2.05, 0.9))
	prop(rig, "ChairBack", Vector3.new(3.2, 4.2, 0.5), rgb(30, 30, 40), CFrame.new(0, 4.2, 2.6) * CFrame.Angles(rad(-8), 0, 0))
	prop(rig, "ChairStripe", Vector3.new(0.4, 4.0, 0.08), rgb(255, 40, 200), CFrame.new(0, 4.2, 2.33) * CFrame.Angles(rad(-8), 0, 0), Enum.Material.Neon, false)
	prop(rig, "ChairPole", Vector3.new(0.4, 1.6, 0.4), metal, CFrame.new(0, 1.0, 0.9), nil, false)
	prop(rig, "ChairFeet", Vector3.new(2.6, 0.25, 2.6), metal, CFrame.new(0, 0.15, 0.9), nil, false)
	-- desk
	prop(rig, "Desk", Vector3.new(7.6, 0.4, 3.4), metal, CFrame.new(0, 3.55, -3.0))
	prop(rig, "DeskEdge", Vector3.new(7.6, 0.08, 0.1), neon, CFrame.new(0, 3.55, -1.27), Enum.Material.Neon, false)
	for _, side in { -1, 1 } do
		prop(rig, "DeskLeg", Vector3.new(0.4, 3.4, 3.0), metal, CFrame.new(side * 3.5, 1.7, -3.0))
	end
	prop(rig, "Monitor", Vector3.new(5.0, 2.8, 0.3), rgb(20, 20, 28), CFrame.new(0, 5.6, -4.3))
	prop(rig, "Screen", Vector3.new(4.6, 2.4, 0.05), rgb(40, 120, 255), CFrame.new(0, 5.6, -4.13), Enum.Material.Neon, false)
	for i = 1, 4 do
		prop(rig, "Code", Vector3.new(1.0 + (i % 3) * 0.7, 0.18, 0.04), if i % 2 == 0 then neon else rgb(255, 80, 220), CFrame.new(-1.4 + (i % 3) * 0.35, 6.4 - i * 0.42, -4.1), Enum.Material.Neon, false)
	end
	prop(rig, "MonitorStand", Vector3.new(0.5, 1.2, 0.4), rgb(20, 20, 28), CFrame.new(0, 4.3, -4.4), nil, false)
	prop(rig, "Keyboard", Vector3.new(3.0, 0.15, 0.9), rgb(25, 25, 35), CFrame.new(2.6, 3.83, -2.4) * CFrame.Angles(0, rad(-12), 0), nil, false)
	prop(rig, "KeyGlow", Vector3.new(2.8, 0.05, 0.7), rgb(255, 60, 200), CFrame.new(2.6, 3.92, -2.4) * CFrame.Angles(0, rad(-12), 0), Enum.Material.Neon, false)
	prop(rig, "Can", Vector3.new(0.45, 0.8, 0.45), rgb(120, 255, 90), CFrame.new(-3.0, 4.15, -2.6), nil, false)
end

-- 13 Robot Factory: in a big recliner with the footrest up, one hand still on the remote, head
-- tipped back, a little toolbox beside him.
Poses[13] = function(rig)
	arm(rig, 1, Vector3.new(0.35, -1, -0.3), Vector3.new(0.05, -0.1, -1))
	arm(rig, -1, Vector3.new(-0.35, -1, -0.3), Vector3.new(-0.05, -0.1, -1))
	for _, side in { -1, 1 } do
		leg(rig, side, Vector3.new(side * 0.06, -0.62, -1))
	end
	nod(rig, CFrame.Angles(rad(22), rad(-12), 0))
	held(rig, "Remote", Vector3.new(0.4, 0.2, 1.1), rgb(50, 50, 60), hand(rig, 1), CFrame.new(0, -0.45, -0.2))
	held(rig, "RemoteButton", Vector3.new(0.18, 0.1, 0.18), rgb(255, 60, 60), hand(rig, 1), CFrame.new(0, -0.56, -0.5), Enum.Material.Neon)
	place(rig, CFrame.Angles(rad(38), 0, 0), 0, 2.1, 0.4)
	local cushion, frame = rgb(255, 170, 40), rgb(110, 110, 125)
	prop(rig, "Seat", Vector3.new(4.4, 1.0, 3.8), cushion, CFrame.new(0, 1.6, 0.6))
	prop(rig, "Base", Vector3.new(4.2, 1.1, 3.6), frame, CFrame.new(0, 0.55, 0.6))
	prop(rig, "Back", Vector3.new(4.4, 5.0, 1.0), cushion, CFrame.new(0, 3.9, 3.0) * CFrame.Angles(rad(-38), 0, 0))
	prop(rig, "Headrest", Vector3.new(3.2, 1.4, 0.6), cushion:Lerp(WHITE, 0.2), CFrame.new(0, 6.0, 4.2) * CFrame.Angles(rad(-38), 0, 0))
	prop(rig, "Footrest", Vector3.new(3.4, 0.7, 3.4), cushion, CFrame.new(0, 1.5, -2.9))
	prop(rig, "FootrestArm", Vector3.new(3.0, 0.3, 1.6), frame, CFrame.new(0, 1.0, -1.6) * CFrame.Angles(rad(-25), 0, 0))
	for _, side in { -1, 1 } do
		prop(rig, "Armrest", Vector3.new(1.0, 2.2, 4.4), cushion:Lerp(BLACK, 0.12), CFrame.new(side * 2.7, 2.0, 0.8))
	end
	prop(rig, "Toolbox", Vector3.new(1.8, 1.1, 1.0), rgb(220, 40, 40), CFrame.new(-4.6, 0.55, -1.0) * CFrame.Angles(0, rad(25), 0))
	prop(rig, "ToolboxHandle", Vector3.new(1.0, 0.25, 0.2), rgb(60, 60, 60), CFrame.new(-4.6, 1.22, -1.0) * CFrame.Angles(0, rad(25), 0), nil, false)
	prop(rig, "Wrench", Vector3.new(0.3, 0.12, 1.6), rgb(190, 190, 200), CFrame.new(-3.4, 0.08, -2.4) * CFrame.Angles(0, rad(-30), 0), Enum.Material.Metal, false)
end

-- 14 Clockwork Void: flopped over the top of a giant upright gear like a towel, head and arms
-- hanging down one side, legs down the other (side-on to the lane, the gear facing you).
Poses[14] = function(rig)
	for _, side in { -1, 1 } do
		arm(rig, side, Vector3.new(side * 0.25, -0.15, -1))
		leg(rig, side, Vector3.new(side * 0.12, -0.25, -1))
	end
	nod(rig, CFrame.Angles(rad(-60), 0, rad(10)))
	-- belly down across the gear's top, head towards +X
	place(rig, CFrame.Angles(0, rad(-90), 0) * FACE_DOWN, 0, 7.55, 0, { "Torso" })
	local brass, dark = rgb(220, 170, 70), rgb(150, 105, 45)
	local wheel = CFrame.new(0, 3.8, 0) * CFrame.Angles(rad(90), 0, 0) -- (its plane: X-Y)
	ring(rig, "GearRim", wheel, 2.8, 16, Vector3.new(1.2, 0.9, 1.0), brass, Enum.Material.Foil, false)
	ring(rig, "GearTooth", wheel, 3.45, 16, Vector3.new(0.6, 0.9, 0.7), dark, Enum.Material.Foil, false, nil)
	for i = 0, 3 do
		prop(rig, "GearSpoke", Vector3.new(0.5, 5.0, 0.7), dark, CFrame.new(0, 3.8, 0) * CFrame.Angles(0, 0, rad(i * 45)), Enum.Material.Foil, false)
	end
	prop(rig, "GearHub", Vector3.new(1.4, 1.4, 1.2), brass, CFrame.new(0, 3.8, 0) * CFrame.Angles(0, 0, rad(45)), Enum.Material.Foil, false)
	prop(rig, "GearStand", Vector3.new(3.2, 0.5, 2.0), dark, CFrame.new(0, 0.25, 0))
	prop(rig, "GearPost", Vector3.new(0.6, 3.4, 0.6), dark, CFrame.new(0, 1.9, 0.75), Enum.Material.Foil, false)
	-- small gears lying round
	for i, at in { Vector3.new(-4.4, 0.15, -1.8), Vector3.new(4.2, 0.15, 1.6), Vector3.new(3.6, 0.15, -2.4) } do
		ring(rig, "SmallGear", CFrame.new(at), 0.7 + (i % 2) * 0.2, 8, Vector3.new(0.5, 0.3, 0.45), if i == 2 then dark else brass, Enum.Material.Foil, false)
	end
end

-- 15 Donut Heaven: lounging on a giant frosted donut pool float on a pool of golden light, arms
-- spread on the float, halo still on.
Poses[15] = function(rig)
	for _, side in { -1, 1 } do
		arm(rig, side, Vector3.new(side * 1, -0.15, 0.35))
		leg(rig, side, Vector3.new(side * 0.2, -0.45, -1))
	end
	nod(rig, CFrame.Angles(rad(30), 0, rad(-8)))
	place(rig, CFrame.Angles(rad(55), 0, 0), 0, 0.9, 0.9)
	local pool = prop(rig, "Pool", Vector3.new(11, 0.3, 11), rgb(255, 235, 160), CFrame.new(0, 0.15, 0), Enum.Material.Neon, false)
	pool.Transparency = 0.35
	local float = CFrame.new(0, 1.0, 0.6)
	ring(rig, "Float", float, 2.9, 14, Vector3.new(1.5, 1.4, 1.7), rgb(235, 180, 110), nil, false)
	ring(rig, "FloatFrosting", float * CFrame.new(0, 0.62, 0), 2.9, 14, Vector3.new(1.4, 0.3, 1.6), rgb(255, 130, 200), nil, false)
	local sprinkleColors = { rgb(255, 230, 60), rgb(90, 200, 255), WHITE, rgb(120, 230, 120) }
	for i = 0, 13 do
		local angle = i / 14 * TAU + 0.2
		prop(rig, "Sprinkle", Vector3.new(0.4, 0.1, 0.12), sprinkleColors[i % 4 + 1], float * CFrame.Angles(0, -angle, 0) * CFrame.new(0.2 * (i % 3 - 1), 0.8, -2.9 + 0.3 * (i % 2)) * CFrame.Angles(0, rad(i * 47), 0), nil, false)
	end
	emitter(pool, rgb(255, 245, 200), 4, 0.4 * rig.s, 0.5 * rig.s, 2, 0.3 * rig.s).Name = "Sparkle"
end

-- 16 Glitch Zone: frozen mid-air in a T-pose, lying on nothing at a wonky angle (the client
-- jitters him), a "missing texture" pillow under his head and glitch cubes hanging round.
Poses[16] = function(rig)
	for _, side in { -1, 1 } do
		arm(rig, side, Vector3.new(side * 1, 0, 0))
		leg(rig, side, Vector3.new(0, -1, 0))
	end
	place(rig, CFrame.Angles(0, rad(90), 0) * ON_BACK * CFrame.Angles(0, rad(12), rad(8)), 0, 4.2, 0)
	rig.Model:SetAttribute("NapMotion", "Jitter")
	-- the pillow: a purple and black checkerboard
	for i = 0, 3 do
		for j = 0, 1 do
			prop(rig, "MissingPillow", Vector3.new(0.75, 0.6, 1.4), if (i + j) % 2 == 0 then rgb(255, 0, 255) else BLACK, CFrame.new(3.6 + (i - 1.5) * 0.75, 3.7, (j - 0.5) * 1.4), Enum.Material.Neon, false)
		end
	end
	local colors = { rgb(255, 0, 200), rgb(0, 255, 220), rgb(255, 255, 255) }
	for i = 1, 10 do
		local a = i * 2.39
		local r = 3.5 + (i % 3)
		prop(rig, "GlitchCube", Vector3.one * (0.4 + (i % 3) * 0.3), colors[i % 3 + 1], CFrame.new(math.cos(a) * r, 1 + (i * 1.7) % 6, math.sin(a) * r * 0.7), Enum.Material.Neon, false)
	end
	prop(rig, "Shadow", Vector3.new(7, 0.1, 3), BLACK, CFrame.new(0, 0.05, 0), nil, false).Transparency = 0.6
end

-- 17 The Black Hole: curled up asleep, floating in zero gravity with a starry sleep mask on,
-- hugging a moon pillow (the client turns him slowly and bobs him).
Poses[17] = function(rig)
	for _, side in { -1, 1 } do
		arm(rig, side, Vector3.new(side * 0.3, -0.6, -1), Vector3.new(-side * 1, 0.25, -0.2))
		leg(rig, side, Vector3.new(side * 0.1, -0.35, -1))
	end
	local mask = rgb(60, 30, 120)
	local function onHead(name: string, size: Vector3, color: Color3, offset: CFrame, material: Enum.Material?)
		local part = held(rig, name, size, color, rig.Head.CFrame, offset, material)
		table.insert(rig.HeadParts, part)
	end
	onHead("SleepMask", Vector3.new(1.42, 0.42, 0.1), mask, CFrame.new(0, 0.12, -0.72))
	onHead("MaskBand", Vector3.new(1.4, 0.16, 1.4), mask, CFrame.new(0, 0.12, 0))
	onHead("MaskStar", Vector3.new(0.14, 0.14, 0.04), rgb(255, 230, 120), CFrame.new(-0.3, 0.16, -0.78) * CFrame.Angles(0, 0, rad(45)), Enum.Material.Neon)
	onHead("MaskStar", Vector3.new(0.14, 0.14, 0.04), rgb(255, 230, 120), CFrame.new(0.3, 0.16, -0.78) * CFrame.Angles(0, 0, rad(45)), Enum.Material.Neon)
	nod(rig, CFrame.Angles(rad(-38), 0, 0))
	-- the moon pillow he's hugging
	local moon = rgb(255, 225, 110)
	for i = 0, 6 do
		local angle = rad(-75 + i * 25)
		piece(rig, "MoonPillow", Vector3.new(0.9, 1.0, 0.9), moon, CFrame.new(math.sin(angle) * 1.2 - 0.2, -0.4 + math.cos(angle) * 1.2 - 0.9, -1.6) * CFrame.Angles(0, 0, -angle), nil, true)
	end
	-- curled up as if sitting in the air, side-on to the lane (his right side towards you), leaning back
	place(rig, CFrame.Angles(0, rad(70), 0) * CFrame.Angles(rad(25), 0, 0), 0, 3.6, 0)
	rig.Model:SetAttribute("NapMotion", "Drift")
	prop(rig, "Shadow", Vector3.new(5, 0.1, 5), BLACK, CFrame.new(0, 0.05, 0), nil, false).Transparency = 0.65
	-- little stars and a tiny ringed planet floating round him
	for i = 1, 6 do
		local a = i / 6 * TAU + 0.4
		local r = 4.2 + (i % 2) * 1.2
		local star = prop(rig, "FloatingStar", Vector3.new(0.45, 0.45, 0.12), if i % 2 == 0 then rgb(255, 230, 120) else rgb(150, 220, 255), CFrame.new(math.cos(a) * r, 2.2 + (i % 3) * 1.4, math.sin(a) * r * 0.8) * CFrame.Angles(0, a, rad(45)), Enum.Material.Neon, false)
		star:SetAttribute("Float", i)
	end
	ball(rig, "Planet", 1.3, rgb(170, 110, 255), Vector3.new(-4.6, 5.4, 1.6))
	disc(rig, "PlanetRing", 2.4, 0.08, rgb(255, 200, 240), Vector3.new(-4.6, 5.4, 1.6), Enum.Material.Neon).CFrame *= CFrame.Angles(rad(20), 0, 0)
end

-- Does this biome's Domer have a pose of his own?
function GuardNaps.Has(areaId: number): boolean
	return Poses[areaId] ~= nil
end

-- Poses and places him (see the top). Returns his mouth and his bed and things (not parented).
function GuardNaps.Pose(model: Model, areaId: number, home: CFrame): (BasePart?, Model?)
	local pose = Poses[areaId]
	if not pose then
		return nil, nil
	end
	local rig = prepare(model, home)
	if not rig then
		return nil, nil
	end
	pose(rig)
	if not rig.Placed then
		place(rig, CFrame.identity, 0, 0, 0)
	end
	local mouth = model:FindFirstChild("Mouth", true)
	return if mouth and mouth:IsA("BasePart") then mouth else nil, rig.Props
end

local _ = HEAD_RIGHT

return GuardNaps
