--[[
	DonutExtras
	===========
	The details that make every donut its own character (used by DonutModel):

	  * Theme details: every donut gets a few small touches from the area it lives in. Lava cracks
	    and embers in The Underworld, circuit traces in Cyber City, icicles in Glacier Glaze, star
	    specks in space, slime in the Haunted Donuttery... Cosmic copies (World 2) get star specks
	    on top of their home area's touches.
	  * Signature accessories: the bits that match a donut's NAME, listed in its Parts in
	    Donuts.luau like the classic accessories: "AlarmClock" (Tick Tock Glazock), "Volcano"
	    (Volcanito), "WifiArcs" (Wifinut), "Banhammer", "CrabClaws", "Katanas"...

	Everything is made of plain parts welded to the donut (no meshes or images), using the Kit that
	DonutModel hands over: its builders place parts in the donut's own space (unscaled, -Z = front,
	the ring in the XY plane) and scale them for big donuts.

	Moving bits are marked like DonutModel's: Limb = "Tail" (wags), "Sway" (flags, flames,
	antennae), "Roll" (clock hands, wind-up keys: turns around the front-back axis), "Orbit" (slowly
	circles round the donut's vertical axis), "Wing", "Arm", "Leg", "Tentacle".

	Keep an accessory to about 12 parts: a full base holds 48 donuts.
]]

local DonutExtras = {}

export type Kit = {
	Id: string,
	s: number,
	R: number,
	TOP: number,
	BALL: number,
	FROST_R: number,
	Dough: Color3,
	Frosting: Color3,
	Sprinkles: { Color3 },
	RarityOrder: number,
	Studded: boolean,
	Rng: Random,
	at: (x: number, y: number, z: number) -> CFrame,
	ball: (diameter: number, color: Color3, cf: CFrame, material: Enum.Material?, name: string?) -> BasePart,
	ellipsoid: (size: Vector3, color: Color3, cf: CFrame, material: Enum.Material?, name: string?) -> BasePart,
	block: (size: Vector3, color: Color3, cf: CFrame, material: Enum.Material?, name: string?) -> BasePart,
	cylinder: (height: number, diameter: number, color: Color3, cf: CFrame, material: Enum.Material?, name: string?) -> BasePart,
	wedge: (size: Vector3, color: Color3, cf: CFrame, material: Enum.Material?) -> BasePart,
	limb: (part: BasePart, kind: string, side: number, px: number, py: number, pz: number) -> BasePart,
	onGlaze: (angle: number, tilt: number, lift: number) -> CFrame,
	face: (x: number, y: number, lift: number) -> CFrame,
	has: (name: string) -> boolean,
	find: (name: string) -> { BasePart },
	add: (part: BasePart, cf: CFrame, color: Color3, material: Enum.Material?) -> BasePart,
}

local rgb = Color3.fromRGB
local WHITE = rgb(255, 255, 255)
local BLACK = rgb(20, 20, 24)
local GOLD = rgb(255, 200, 60)
local SILVER = rgb(205, 210, 220)
local NEON = Enum.Material.Neon
local GLASS = Enum.Material.Glass
local FOIL = Enum.Material.Foil
local METAL = Enum.Material.Metal
local WOOD = Enum.Material.Wood
local TAU = math.pi * 2

local function brightness(c: Color3): number
	return c.R * 0.299 + c.G * 0.587 + c.B * 0.114
end

---------------------------------------------------------------------------------------------------
-- Shared helpers (all in the donut's unscaled space)
---------------------------------------------------------------------------------------------------

-- A cylinder from `a` to `b` (rods, sticks, tails, strands).
local function segment(k: Kit, a: Vector3, b: Vector3, diameter: number, color: Color3, material: Enum.Material?, name: string?): BasePart
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	local along = b - a
	p.Size = Vector3.new(along.Magnitude + diameter * 0.4, diameter, diameter) * k.s
	p.Name = name or "Rod"
	local x = along.Unit
	local helper = if math.abs(x.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis
	local z = x:Cross(helper).Unit
	local y = z:Cross(x).Unit
	return k.add(p, CFrame.fromMatrix((a + b) / 2 * k.s, x, y, z), color, material)
end

-- A flat disc facing along `cf`'s look direction (coins, clock faces, wheels, shields).
local function disc(k: Kit, cf: CFrame, thickness: number, diameter: number, color: Color3, material: Enum.Material?, name: string?): BasePart
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(thickness, diameter, diameter) * k.s
	p.Name = name or "Disc"
	-- cylinders run along X: turn X onto the look direction
	return k.add(p, cf * CFrame.Angles(0, math.pi / 2, 0), color, material)
end

-- Where `cf` (built from unscaled numbers) sits once scaled: rotation kept, position scaled.
local function scaled(k: Kit, cf: CFrame): CFrame
	return cf - cf.Position + cf.Position * k.s
end

-- A ring of short rods around `center` (unscaled CFrame; the ring lies in its XY plane), from
-- angle `from` to `to` (radians, 0 = +X). Good for loops, arcs, wheels, portals.
local function torus(k: Kit, center: CFrame, radius: number, thickness: number, count: number, color: Color3, material: Enum.Material?, name: string?, from: number?, to: number?, colors: { Color3 }?): { BasePart }
	local a0, a1 = from or 0, to or TAU
	local step = (a1 - a0) / count
	local pieces = {}
	for i = 0, count - 1 do
		local t0, t1 = a0 + step * i, a0 + step * (i + 1)
		local p0 = center:PointToWorldSpace(Vector3.new(math.cos(t0) * radius, math.sin(t0) * radius, 0))
		local p1 = center:PointToWorldSpace(Vector3.new(math.cos(t1) * radius, math.sin(t1) * radius, 0))
		table.insert(pieces, segment(k, p0, p1, thickness, if colors then colors[(i % #colors) + 1] else color, material, name))
	end
	return pieces
end

-- A point on the dough tube: `angle` round the ring, `around` from the front (0) over the outer
-- edge (pi/2) to the back (pi). The CFrame's up is the surface normal, X runs along the ring,
-- Z runs round the tube.
local function onDough(k: Kit, angle: number, around: number, lift: number): CFrame
	local radial = Vector3.new(math.cos(angle), math.sin(angle), 0)
	local normal = radial * math.sin(around) + Vector3.new(0, 0, -math.cos(around))
	local downTube = radial * math.cos(around) + Vector3.new(0, 0, math.sin(around))
	local tangent = Vector3.new(-radial.Y, radial.X, 0)
	local point = radial * k.R + normal * (k.BALL / 2 + lift)
	if k.Studded then
		-- the square-edged dough ring: its outer side (from 45 degrees round), else its front
		local half = k.BALL / 2
		point = if around >= math.pi / 4
			then radial * (k.R + half) + Vector3.new(0, 0, -half * math.cos(around) / math.sin(around)) + normal * lift
			else radial * (k.R + half * math.tan(around)) + Vector3.new(0, 0, -half) + normal * lift
	end
	return CFrame.fromMatrix(point * k.s, tangent, normal, downTube)
end

-- A random angle on the glaze away from the face (which sits at the top).
local function glazeAngle(k: Kit): number
	local angle
	repeat
		angle = k.Rng:NextNumber(0, TAU)
	until math.abs(angle - math.pi / 2) > 0.8
	return angle
end

-- Where the right (side 1) or left (-1) hand is. Donuts without arms get a floating glove there.
-- (strong donuts flex their arms, so their fists are a little further out and up)
local function hand(k: Kit, side: number): Vector3
	local flexing = #k.find("Bicep") > 0
	local point = if flexing then Vector3.new(side * (k.R + 1.58), 0.84, -0.1) else Vector3.new(side * (k.R + 1.42), 0.72, -0.1)
	if not k.has("Arms") then
		local existing = false
		for _, glove in k.find("FloatingGlove") do
			if (glove.Position.X > 0) == (side > 0) then
				existing = true
			end
		end
		if not existing then
			k.ball(0.52, WHITE, k.at(point.X, point.Y, point.Z), nil, "FloatingGlove")
		end
	end
	return point
end

-- A four-pointed sparkle star.
local function sparkle(k: Kit, cf: CFrame, size: number, color: Color3, name: string?): { BasePart }
	return {
		k.ellipsoid(Vector3.new(size * 0.22, size, size * 0.12), color, cf, NEON, name or "Star"),
		k.ellipsoid(Vector3.new(size, size * 0.22, size * 0.12), color, cf, NEON, name or "Star"),
	}
end

-- A screen with a line of text (signs, error screens, terminals).
local function screen(k: Kit, cf: CFrame, size: Vector2, frame: Color3, back: Color3, text: string, textColor: Color3, font: Enum.Font?)
	k.block(Vector3.new(size.X + 0.16, size.Y + 0.16, 0.14), frame, cf, METAL, "ScreenFrame")
	local panel = k.block(Vector3.new(size.X, size.Y, 0.06), back, cf * CFrame.new(0, 0, -0.06 * k.s), NEON, "Screen")
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(size.X * 60, size.Y * 60)
	gui.LightInfluence = 0
	gui.Parent = panel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = font or Enum.Font.Arcade
	label.TextColor3 = textColor
	label.Parent = gui
end

-- Wrapped round the tube at a ring angle: ridges, stripes, bands.
local function ridges(k: Kit, count: number, twist: number, color: Color3, width: number, material: Enum.Material?, name: string, skipFace: boolean?)
	for i = 0, count - 1 do
		local angle = (i + 0.5) / count * TAU
		if not skipFace or math.abs(angle - math.pi / 2) > 0.7 then
			local cf = onDough(k, angle, math.rad(95), -0.03) * CFrame.Angles(0, twist, 0)
			k.ellipsoid(Vector3.new(width, 0.1, 1.3), color, cf, material, name)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Theme details: a few small touches from the donut's home area
---------------------------------------------------------------------------------------------------
local Theme: { [string]: (k: Kit) -> () } = {}

local function lavaCracks(k: Kit, count: number, color: Color3)
	for _ = 1, count do
		local angle = k.Rng:NextNumber(0, TAU)
		local around = math.rad(k.Rng:NextNumber(70, 115))
		local cf = onDough(k, angle, around, -0.01) * CFrame.Angles(0, k.Rng:NextNumber(-0.9, 0.9), 0)
		k.ellipsoid(Vector3.new(0.07, 0.08, k.Rng:NextNumber(0.5, 0.9)), color, cf, NEON, "LavaCrack")
	end
end

local function specks(k: Kit, count: number, colors: { Color3 }, size: number, material: Enum.Material?, name: string)
	for i = 1, count do
		local cf = k.onGlaze(glazeAngle(k), k.Rng:NextNumber(-0.8, 0.9), -0.02) * CFrame.Angles(k.Rng:NextNumber(0, 3), k.Rng:NextNumber(0, 3), 0)
		k.block(Vector3.one * size, colors[(i - 1) % #colors + 1], cf, material, name)
	end
end

local function stars(k: Kit, count: number, color: Color3)
	for _ = 1, count do
		local cf = k.onGlaze(glazeAngle(k), k.Rng:NextNumber(-0.7, 0.8), 0.02)
		k.ball(0.14, color, cf, NEON, "StarSpeck")
	end
end

local function circuit(k: Kit, color: Color3)
	-- two traces running round the lower glaze, each ending in a pad
	for _, side in { -1, 1 } do
		local a0 = -math.pi / 2 + side * 0.25
		local a1 = a0 + side * 0.7
		for i = 0, 1 do
			local angle = a0 + (a1 - a0) * (i + 0.5) / 2
			local tilt = if i == 0 then 0.55 else -0.35
			k.ellipsoid(Vector3.new(0.6, 0.06, 0.05), color, k.onGlaze(angle, tilt, 0.005) * CFrame.Angles(0, 0, angle + math.pi / 2), NEON, "Circuit")
		end
		k.ball(0.17, color, k.onGlaze(a1, -0.35, 0.01), NEON, "CircuitPad")
	end
end

local function puffs(k: Kit, count: number, color: Color3, transparency: number)
	for i = 1, count do
		local angle = math.rad(200 + (i - 1) * 140 / math.max(count - 1, 1))
		local p = Vector3.new(math.cos(angle) * (k.R + 0.55), math.sin(angle) * (k.R + 0.55), 0.35)
		k.ball(k.Rng:NextNumber(0.75, 1.05), color, k.at(p.X, p.Y, p.Z), nil, "Puff").Transparency = transparency
	end
end

function Theme.Meadow(k: Kit)
	-- a daisy on the glaze
	local cf = k.onGlaze(math.rad(-35), 0.35, 0.02)
	k.ball(0.2, rgb(255, 210, 40), cf, nil, "Daisy")
	for i = 0, 4 do
		local a = i / 5 * TAU
		k.ellipsoid(Vector3.new(0.3, 0.13, 0.06), WHITE, cf * CFrame.Angles(0, 0, a) * CFrame.new(0.17 * k.s, 0, 0.01 * k.s), nil, "Petal")
	end
end

function Theme.Park(k: Kit)
	-- a lucky clover
	local cf = k.onGlaze(math.rad(-40), 0.3, 0.02)
	for i = 0, 2 do
		local a = i / 3 * TAU + 0.5
		k.ball(0.22, rgb(70, 190, 70), cf * CFrame.new(math.cos(a) * 0.11 * k.s, math.sin(a) * 0.11 * k.s, 0), nil, "Clover")
	end
	k.ellipsoid(Vector3.new(0.05, 0.3, 0.05), rgb(60, 150, 60), cf * CFrame.new(0.05 * k.s, -0.2 * k.s, 0), nil, "Clover")
end

function Theme.Desert(k: Kit)
	specks(k, 6, { rgb(255, 245, 220), rgb(240, 215, 160) }, 0.13, GLASS, "SugarCrystal")
end

function Theme.Frosting(k: Kit)
	-- a dollop of whipped cream with a cherry
	local cf = k.onGlaze(math.rad(-50), 0.2, 0.05)
	k.ellipsoid(Vector3.new(0.6, 0.6, 0.35), rgb(255, 250, 240), cf, nil, "Cream")
	k.ellipsoid(Vector3.new(0.4, 0.4, 0.3), rgb(255, 250, 240), cf * CFrame.new(0, 0, -0.2 * k.s), nil, "Cream")
	k.ball(0.26, rgb(220, 20, 50), cf * CFrame.new(0, 0, -0.38 * k.s), nil, "Cherry").Reflectance = 0.2
end

function Theme.Chocolate(k: Kit)
	-- chocolate drizzle (white chocolate on dark glaze)
	local color = if brightness(k.Frosting) < 0.35 then rgb(250, 240, 225) else rgb(70, 35, 20)
	for i = 0, 2 do
		local angle = math.rad(-90 + (i - 1) * 38)
		k.ellipsoid(Vector3.new(0.08, 1.3, 0.05), color, k.onGlaze(angle, 0, 0.01) * CFrame.Angles(0, 0, angle + 0.5), nil, "Drizzle")
	end
end

function Theme.Ice(k: Kit)
	-- icicles hanging under the ring
	for i = 0, 2 do
		local angle = math.rad(-125 + i * 35)
		local x, y = math.cos(angle) * (k.R + 0.15), math.sin(angle) * (k.R + 0.15)
		local icicle = k.ellipsoid(Vector3.new(0.2, 0.75, 0.2), rgb(190, 235, 255), k.at(x, y - 0.4, -0.35), GLASS, "Icicle")
		icicle.Transparency = 0.15
	end
end

function Theme.Lava(k: Kit)
	lavaCracks(k, 3, rgb(255, 140, 30))
end

function Theme.Neon(k: Kit)
	circuit(k, k.Sprinkles[1] or rgb(0, 255, 200))
end

function Theme.Crystal(k: Kit)
	for i = 0, 2 do
		local angle = math.rad(-60 - i * 30)
		local cf = onDough(k, angle, math.rad(100), 0.15) * CFrame.Angles(0, math.rad(45), k.Rng:NextNumber(-0.3, 0.3))
		local shard = k.block(Vector3.new(0.28, 0.75 - i * 0.12, 0.28), k.Frosting:Lerp(WHITE, 0.35), cf, GLASS, "Crystal")
		shard.Transparency = 0.2
		shard.Reflectance = 0.3
	end
end

function Theme.Celestial(k: Kit)
	stars(k, 4, rgb(255, 250, 210))
end

function Theme.Candy(k: Kit)
	local colors = { rgb(255, 70, 90), rgb(255, 220, 60), rgb(90, 220, 120) }
	for i = 0, 2 do
		local cf = k.onGlaze(math.rad(-60 - i * 30), k.Rng:NextNumber(-0.3, 0.4), 0.08)
		k.ellipsoid(Vector3.new(0.3, 0.3, 0.26), colors[i + 1], cf, nil, "Gumdrop").Reflectance = 0.1
	end
end

function Theme.Rainbow(k: Kit)
	local colors = { rgb(255, 60, 60), rgb(255, 160, 40), rgb(255, 230, 60), rgb(80, 220, 100), rgb(60, 150, 255), rgb(170, 90, 255) }
	for i, color in colors do
		local angle = math.rad(-160 + (i - 1) * 28)
		k.ball(0.2, color, k.onGlaze(angle, 0.75, 0.02), NEON, "RainbowDot")
	end
end

-- The Underworld
function Theme.EmberGates(k: Kit)
	lavaCracks(k, 3, rgb(255, 120, 20))
	k.ball(0.16, rgb(255, 210, 80), k.onGlaze(glazeAngle(k), 0.2, 0.05), NEON, "Ember")
end
function Theme.BrimstoneBakery(k: Kit)
	lavaCracks(k, 2, rgb(255, 150, 30))
	specks(k, 4, { rgb(255, 230, 80), rgb(230, 200, 60) }, 0.12, nil, "Brimstone")
end
function Theme.MagmaRivers(k: Kit)
	lavaCracks(k, 2, rgb(255, 110, 20))
	local angle = math.rad(-60)
	local radial = Vector3.new(math.cos(angle), math.sin(angle), 0)
	local p = radial * (k.R + 0.55)
	k.ellipsoid(Vector3.new(0.3, 0.95, 0.3), rgb(255, 120, 20), k.at(p.X, p.Y - 0.35, -0.3), NEON, "LavaDrip")
end
function Theme.SoulCaverns(k: Kit)
	for i = 0, 1 do
		local p = Vector3.new(if i == 0 then -2.6 else 2.5, if i == 0 then 1.4 else -0.6, 0.3)
		local wisp = k.ellipsoid(Vector3.new(0.4, 0.55, 0.4), rgb(120, 230, 255), k.at(p.X, p.Y, p.Z), NEON, "Wisp")
		wisp.Transparency = 0.35
		k.limb(wisp, "Orbit", 0, 0, 0, 0)
	end
end
function Theme.ObsidianForge(k: Kit)
	lavaCracks(k, 2, rgb(255, 100, 20))
	local cf = onDough(k, math.rad(-140), math.rad(95), 0.15) * CFrame.Angles(0, math.rad(45), 0.3)
	k.block(Vector3.new(0.3, 0.7, 0.3), rgb(25, 20, 35), cf, GLASS, "Obsidian").Reflectance = 0.4
end
function Theme.InfernoSpires(k: Kit)
	lavaCracks(k, 3, rgb(255, 80, 20))
end
function Theme.MoltenCore(k: Kit)
	lavaCracks(k, 4, rgb(255, 170, 40))
end

-- Dream Dimension
function Theme.Clouds(k: Kit)
	puffs(k, 3, WHITE, 0.05)
end
function Theme.Toys(k: Kit)
	-- stitching round the outer edge
	for i = 0, 4 do
		local angle = math.rad(-150 + i * 30)
		k.block(Vector3.new(0.25, 0.05, 0.06), rgb(255, 255, 255), onDough(k, angle, math.rad(85), 0.005), nil, "Stitch")
	end
end
function Theme.Haunted(k: Kit)
	-- green slime dripping off the bottom
	for i = 0, 1 do
		local angle = math.rad(if i == 0 then -60 else -125)
		local p = Vector3.new(math.cos(angle) * (k.R + 0.45), math.sin(angle) * (k.R + 0.45), -0.35)
		k.ellipsoid(Vector3.new(0.3, 0.8, 0.3), rgb(140, 255, 110), k.at(p.X, p.Y - 0.25, p.Z), NEON, "Slime").Transparency = 0.15
	end
end
function Theme.Clockwork(k: Kit)
	for i = 0, 3 do
		local angle = math.rad(-150 + i * 40)
		k.ball(0.17, rgb(220, 170, 70), onDough(k, angle, math.rad(80), 0), FOIL, "Rivet")
	end
end
function Theme.Heaven(k: Kit)
	stars(k, 3, rgb(255, 225, 120))
end
function Theme.Starfall(k: Kit)
	stars(k, 4, rgb(255, 240, 180))
end
function Theme.Aurora(k: Kit)
	local cf = k.at(0, 0.4, 0.95) * CFrame.Angles(0, 0, 0.35)
	local band = k.ellipsoid(Vector3.new(5.2, 0.5, 0.08), rgb(120, 255, 200), cf, NEON, "Aurora")
	band.Transparency = 0.55
	local band2 = k.ellipsoid(Vector3.new(4.6, 0.4, 0.08), rgb(190, 120, 255), cf * CFrame.new(0, -0.35 * k.s, 0.05 * k.s), NEON, "Aurora")
	band2.Transparency = 0.6
end

-- Cyber City
function Theme.CyberStreets(k: Kit)
	circuit(k, k.Sprinkles[1] or rgb(255, 0, 200))
end
function Theme.Hologram(k: Kit)
	-- hologram scanlines across the front
	for i = 0, 1 do
		local line = k.block(Vector3.new(4.6, 0.07, 0.04), rgb(120, 240, 255), k.at(0, -0.6 + i * 1.3, -1.02), NEON, "Scanline")
		line.Transparency = 0.45
	end
end
function Theme.RobotFactory(k: Kit)
	for i = 0, 3 do
		k.ball(0.17, rgb(170, 175, 185), onDough(k, math.rad(-150 + i * 40), math.rad(80), 0), METAL, "Rivet")
	end
end
function Theme.DataHighway(k: Kit)
	circuit(k, rgb(60, 255, 140))
end
function Theme.Firewall(k: Kit)
	lavaCracks(k, 3, rgb(255, 60, 40))
end
function Theme.Glitch(k: Kit)
	for i = 0, 2 do
		local y = -1.2 + i * 1.1
		local glitch = k.block(Vector3.new(k.Rng:NextNumber(1.2, 2.4), 0.16, 0.06), if i % 2 == 0 then rgb(255, 0, 200) else rgb(0, 255, 230), k.at(k.Rng:NextNumber(-1.2, 1.2), y, -1.0), NEON, "Glitch")
		glitch.Transparency = 0.35
	end
end
function Theme.Mainframe(k: Kit)
	circuit(k, rgb(80, 170, 255))
end
function Theme.BlackHole(k: Kit)
	stars(k, 3, rgb(210, 180, 255))
	local band = k.ellipsoid(Vector3.new(5.4, 0.12, 5.4), rgb(160, 100, 255), k.at(0, -0.3, 0) * CFrame.Angles(math.rad(12), 0, math.rad(-10)), NEON, "Accretion")
	band.Transparency = 0.75
end

function DonutExtras.Theme(k: Kit, theme: string, cosmic: boolean)
	local builder = Theme[theme]
	if builder then
		builder(k)
	end
	if cosmic then
		stars(k, 3, rgb(200, 180, 255))
	end
end

---------------------------------------------------------------------------------------------------
-- Signature accessories (match the donut's name)
---------------------------------------------------------------------------------------------------
local A: { [string]: (k: Kit) -> () } = {}
DonutExtras.Accessories = A

-- Sweets ------------------------------------------------------------------------------------------

function A.SugarCoat(k: Kit)
	specks(k, 10, { WHITE, rgb(240, 240, 255) }, 0.13, GLASS, "Sugar")
end

function A.SprinkleStorm(k: Kit)
	local colors = if #k.Sprinkles > 0 then k.Sprinkles else { WHITE }
	for n = 1, 12 do
		local cf
		if n % 3 == 0 then
			cf = onDough(k, k.Rng:NextNumber(0, TAU), math.rad(k.Rng:NextNumber(60, 120)), 0.03) * CFrame.Angles(0, k.Rng:NextNumber(0, 3), 0)
		else
			cf = k.onGlaze(glazeAngle(k), k.Rng:NextNumber(-1, 1.1), -0.035) * CFrame.Angles(0, 0, k.Rng:NextNumber(0, TAU))
		end
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(0.4, 0.12, 0.12) * k.s
		p.Name = "Sprinkle"
		k.add(p, cf, colors[(n - 1) % #colors + 1])
	end
end

function A.WoodGrain(k: Kit)
	-- a log of a donut: wooden dough with knots
	for _, piece in k.find("Dough") do
		piece.Material = WOOD
	end
	for i = 0, 1 do
		local cf = onDough(k, math.rad(if i == 0 then -30 else 200), math.rad(90), 0.0)
		k.ellipsoid(Vector3.new(0.45, 0.08, 0.35), k.Dough:Lerp(BLACK, 0.45), cf, WOOD, "Knot")
	end
end

function A.CrullerRidges(k: Kit)
	ridges(k, 10, math.rad(35), k.Dough:Lerp(WHITE, 0.25), 0.2, nil, "Ridge")
end

function A.PumpkinRidges(k: Kit)
	ridges(k, 8, 0, k.Dough:Lerp(BLACK, 0.3), 0.14, nil, "Rib")
end

function A.CreamFilling(k: Kit)
	local cream = rgb(255, 240, 200)
	k.ellipsoid(Vector3.new(1.05, 0.55, 0.9), cream, k.at(0, -0.5, -0.15), nil, "Cream")
	k.ellipsoid(Vector3.new(0.5, 0.35, 0.55), cream, onDough(k, math.rad(-20), math.rad(80), 0.08), nil, "Cream")
	k.ellipsoid(Vector3.new(0.22, 0.5, 0.22), cream, k.at(k.R + 0.62, -0.95, -0.25), nil, "Cream")
end

function A.JellyOoze(k: Kit)
	local jelly = rgb(215, 25, 55)
	local blob = k.ellipsoid(Vector3.new(1.0, 0.6, 0.85), jelly, k.at(0, -0.48, -0.15), GLASS, "Jelly")
	blob.Transparency = 0.1
	blob.Reflectance = 0.25
	k.ellipsoid(Vector3.new(0.5, 0.35, 0.5), jelly, onDough(k, math.rad(-25), math.rad(85), 0.08), GLASS, "Jelly").Reflectance = 0.25
	k.ellipsoid(Vector3.new(0.24, 0.55, 0.24), jelly, k.at(k.R + 0.55, -1.05, -0.3), GLASS, "Jelly").Reflectance = 0.25
	k.ball(0.18, jelly, k.at(k.R + 0.5, -1.5, -0.3), GLASS, "Jelly")
end

function A.FudgeDrips(k: Kit)
	local fudge = k.Frosting:Lerp(BLACK, 0.25)
	for i = 0, 3 do
		local angle = math.rad(-160 + i * 45)
		local radial = Vector3.new(math.cos(angle), math.sin(angle), 0)
		local p = radial * (k.R + 0.6)
		local drip = k.ellipsoid(Vector3.new(0.35, 0.9 + (i % 2) * 0.35, 0.3), fudge, k.at(p.X, p.Y - 0.25, -0.3), nil, "Fudge")
		drip.Reflectance = 0.2
	end
end

function A.CaramelDrips(k: Kit)
	local caramel = rgb(225, 140, 40)
	for i = 0, 3 do
		local angle = math.rad(-150 + i * 40)
		local radial = Vector3.new(math.cos(angle), math.sin(angle), 0)
		local p = radial * (k.R + 0.6)
		k.ellipsoid(Vector3.new(0.3, 0.85 + (i % 2) * 0.3, 0.28), caramel, k.at(p.X, p.Y - 0.25, -0.3), GLASS, "Caramel").Reflectance = 0.3
	end
	k.ellipsoid(Vector3.new(0.07, 2.2, 0.05), caramel, k.onGlaze(math.rad(-90), 0, 0.01) * CFrame.Angles(0, 0, 1.1), GLASS, "Drizzle")
end

function A.CinnamonSwirl(k: Kit)
	local cinnamon = rgb(150, 85, 35)
	for i = 0, 7 do
		local angle = math.rad(-170 + i * 22)
		k.ellipsoid(Vector3.new(0.34, 0.12, 0.05), cinnamon, k.onGlaze(angle, math.sin(i * 1.3) * 0.55, 0.005) * CFrame.Angles(0, 0, angle + math.pi / 2 + math.sin(i) * 0.5), nil, "Cinnamon")
	end
end

function A.StrawberrySlices(k: Kit)
	local red = rgb(235, 40, 70)
	for i = 0, 1 do
		local cf = k.onGlaze(math.rad(-50 - i * 70), 0.15, 0.04) * CFrame.Angles(0, 0, i * 1.2)
		k.ellipsoid(Vector3.new(0.6, 0.5, 0.1), red, cf, nil, "Strawberry")
		k.ellipsoid(Vector3.new(0.32, 0.26, 0.11), rgb(255, 200, 210), cf * CFrame.new(0, -0.03 * k.s, -0.01 * k.s), nil, "Strawberry")
	end
	-- a whole strawberry on top
	k.ellipsoid(Vector3.new(0.55, 0.65, 0.55), red, k.at(0.7, k.TOP + 0.25, 0), nil, "Strawberry").Reflectance = 0.15
	k.ellipsoid(Vector3.new(0.6, 0.12, 0.6), rgb(70, 170, 60), k.at(0.7, k.TOP + 0.55, 0), nil, "Leaves")
end

function A.Gumdrops(k: Kit)
	local colors = { rgb(255, 60, 80), rgb(255, 210, 50), rgb(80, 220, 110), rgb(170, 90, 255) }
	for i, color in colors do
		local angle = math.rad(20 + (i - 1) * 47)
		local x, y = math.cos(angle) * 0.9, k.TOP - 0.05 + math.sin(i) * 0.05
		k.ellipsoid(Vector3.new(0.5, 0.5, 0.5), color, k.at(x - 0.5, y + 0.1, (i - 2.5) * 0.25), nil, "Gumdrop").Reflectance = 0.1
	end
end

function A.CandyCane(k: Kit)
	local h = hand(k, -1)
	local base = h + Vector3.new(0, -1.1, -0.1)
	local top = h + Vector3.new(0, 1.3, -0.1)
	for i = 0, 3 do
		local a = base:Lerp(top, i / 4)
		local b = base:Lerp(top, (i + 1) / 4)
		segment(k, a, b, 0.3, if i % 2 == 0 then rgb(230, 30, 45) else WHITE, nil, "CandyCane")
	end
	torus(k, CFrame.new(top + Vector3.new(0.4, 0, 0)), 0.4, 0.3, 4, WHITE, nil, "CandyCane", 0, math.pi, { rgb(230, 30, 45), WHITE })
end

function A.Lollipop(k: Kit)
	local h = hand(k, 1)
	local top = h + Vector3.new(0, 1.6, -0.1)
	segment(k, h + Vector3.new(0, -0.3, -0.1), top, 0.12, WHITE, nil, "Stick")
	local cf = CFrame.new(top + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, math.pi, 0)
	disc(k, scaled(k, cf), 0.18, 1.2, k.Frosting, nil, "Lollipop")
	disc(k, scaled(k, cf * CFrame.new(0, 0, -0.03)), 0.18, 0.8, WHITE, nil, "Swirl")
	disc(k, scaled(k, cf * CFrame.new(0, 0, -0.06)), 0.18, 0.42, k.Frosting:Lerp(BLACK, 0.2), nil, "Swirl")
end

function A.PeppermintSwirl(k: Kit)
	-- a big peppermint behind the donut, slowly turning
	local center = Vector3.new(0, 0.2, 0.95)
	local cf = scaled(k, CFrame.new(center))
	disc(k, cf, 0.2, 5.2, WHITE, nil, "Peppermint")
	for i = 0, 3 do
		local stripe = k.ellipsoid(Vector3.new(0.7, 2.5, 0.22), rgb(230, 30, 45), cf * CFrame.Angles(0, 0, i / 4 * math.pi) * CFrame.new(0, 1.2 * k.s, -0.08 * k.s), nil, "Peppermint")
		k.limb(stripe, "Roll", 0, center.X, center.Y, center.Z)
	end
end

-- Animals -----------------------------------------------------------------------------------------

function A.CatEars(k: Kit)
	for _, side in { -1, 1 } do
		local cf = k.at(side * 0.85, k.TOP + 0.25, 0.05) * CFrame.Angles(0, 0, side * math.rad(-15))
		k.wedge(Vector3.new(0.22, 0.75, 0.6), k.Dough:Lerp(BLACK, 0.15), cf * CFrame.Angles(0, math.pi / 2, 0))
		k.wedge(Vector3.new(0.23, 0.45, 0.32), rgb(255, 170, 190), cf * CFrame.new(0, -0.08 * k.s, -0.06 * k.s) * CFrame.Angles(0, math.pi / 2, 0))
	end
end

function A.BigNose(k: Kit)
	k.ellipsoid(Vector3.new(0.45, 0.42, 0.8), rgb(255, 190, 150), k.face(0, k.TOP - 0.98, 0.18), nil, "Nose")
end

function A.Trunk(k: Kit)
	local grey = rgb(150, 170, 140)
	local p0 = Vector3.new(0, k.TOP - 0.95, -1.05)
	local p1 = Vector3.new(0, k.TOP - 1.5, -1.35)
	local p2 = Vector3.new(0, k.TOP - 2.05, -1.25)
	local p3 = Vector3.new(0.2, k.TOP - 2.35, -0.95)
	for _, piece in { { From = p0, To = p1, D = 0.42 }, { From = p1, To = p2, D = 0.34 }, { From = p2, To = p3, D = 0.26 } } do
		local part = segment(k, piece.From, piece.To, piece.D, grey, nil, "Trunk")
		k.limb(part, "Tentacle", 1, p0.X, p0.Y, p0.Z)
	end
end

function A.SharkTail(k: Kit)
	local grey = rgb(120, 140, 170)
	local pivot = Vector3.new(0, -0.8, 0.75)
	local upper = k.wedge(Vector3.new(0.22, 1.0, 0.9), grey, k.at(0, -0.55, 1.45) * CFrame.Angles(math.rad(-35), math.pi, 0))
	local lower = k.wedge(Vector3.new(0.22, 0.8, 0.7), grey, k.at(0, -1.25, 1.35) * CFrame.Angles(math.rad(-150), math.pi, 0))
	for _, part in { upper, lower } do
		part.Name = "SharkTail"
		k.limb(part, "Tail", 0, pivot.X, pivot.Y, pivot.Z)
	end
end

function A.SharkGills(k: Kit)
	for i = 0, 2 do
		k.ellipsoid(Vector3.new(0.06, 0.5, 0.05), BLACK, k.onGlaze(math.rad(-15 - i * 9), 0.6, 0.0) * CFrame.Angles(0, 0, 0.2), nil, "Gill")
	end
end

function A.ShrimpTail(k: Kit)
	local pink = rgb(255, 140, 110)
	local pivot = Vector3.new(0, -0.9, 0.7)
	local points = { Vector3.new(0, -0.9, 0.9), Vector3.new(0, -1.45, 1.3), Vector3.new(0, -1.8, 1.75) }
	for i, p in points do
		local part = k.ellipsoid(Vector3.new(0.75 - i * 0.15, 0.55 - i * 0.1, 0.6), if i % 2 == 0 then pink:Lerp(WHITE, 0.25) else pink, k.at(p.X, p.Y, p.Z) * CFrame.Angles(math.rad(-30 - i * 15), 0, 0), nil, "ShrimpTail")
		k.limb(part, "Tail", 0, pivot.X, pivot.Y, pivot.Z)
	end
	for _, side in { -1, 1 } do
		local fan = k.ellipsoid(Vector3.new(0.45, 0.1, 0.7), pink, k.at(side * 0.22, -2.05, 2.1) * CFrame.Angles(0.4, side * 0.5, 0), nil, "ShrimpTail")
		k.limb(fan, "Tail", 0, pivot.X, pivot.Y, pivot.Z)
	end
end

function A.BeaverTeeth(k: Kit)
	for _, side in { -1, 1 } do
		k.block(Vector3.new(0.18, 0.28, 0.06), WHITE, k.face(side * 0.1, k.TOP - 1.38, 0.03), nil, "Tooth")
	end
	local tail = k.ellipsoid(Vector3.new(1.0, 0.18, 1.6), rgb(110, 75, 50), k.at(0, -1.7, 1.4) * CFrame.Angles(math.rad(-25), 0, 0), nil, "BeaverTail")
	k.limb(tail, "Tail", 0, 0, -1.2, 0.7)
end

function A.CowSpots(k: Kit)
	for _ = 1, 4 do
		local cf = k.onGlaze(glazeAngle(k), k.Rng:NextNumber(-0.6, 0.6), 0.005) * CFrame.Angles(0, 0, k.Rng:NextNumber(0, 3))
		k.ellipsoid(Vector3.new(k.Rng:NextNumber(0.5, 0.8), k.Rng:NextNumber(0.35, 0.55), 0.04), BLACK, cf, nil, "CowSpot")
	end
end

function A.CowBell(k: Kit)
	k.ellipsoid(Vector3.new(2.6, 0.22, 0.25), rgb(150, 60, 40), k.at(0, -k.R + 0.05, -0.85), nil, "Collar")
	k.ellipsoid(Vector3.new(0.5, 0.55, 0.45), GOLD, k.at(0, -k.R - 0.35, -1.0), FOIL, "Bell")
	k.ball(0.15, rgb(120, 90, 30), k.at(0, -k.R - 0.62, -1.0), nil, "Bell")
end

function A.CrocSnout(k: Kit)
	local green = k.Frosting:Lerp(rgb(40, 120, 50), 0.4)
	local cf = k.face(0, k.TOP - 1.3, 0.45)
	k.ellipsoid(Vector3.new(1.0, 0.45, 1.5), green, cf, nil, "Snout")
	for _, side in { -1, 1 } do
		k.ball(0.14, BLACK, cf * CFrame.new(side * 0.15 * k.s, 0.18 * k.s, -0.6 * k.s), nil, "Nostril")
		for t = 0, 1 do
			k.wedge(Vector3.new(0.08, 0.16, 0.12), WHITE, cf * CFrame.new(side * 0.4 * k.s, -0.2 * k.s, (-0.35 + t * 0.35) * k.s) * CFrame.Angles(math.pi, 0, 0))
		end
	end
end

function A.Flippers(k: Kit)
	k.ellipsoid(Vector3.new(1.3, 0.95, 0.1), WHITE, k.onGlaze(-math.pi / 2, 0, 0.02), nil, "Belly")
	for _, side in { -1, 1 } do
		local flipper = k.ellipsoid(Vector3.new(0.4, 1.3, 0.25), k.Frosting, k.at(side * (k.R + 0.95), -0.3, 0) * CFrame.Angles(0, 0, side * math.rad(25)), nil, "Flipper")
		k.limb(flipper, "Wing", side, side * (k.R + 0.7), 0.2, 0)
	end
end

function A.BowTie(k: Kit)
	local red = rgb(220, 30, 50)
	local cf = k.face(0, 0.9, 0.05)
	for _, side in { -1, 1 } do
		k.wedge(Vector3.new(0.12, 0.4, 0.35), red, cf * CFrame.new(side * 0.2 * k.s, 0, 0) * CFrame.Angles(0, side * math.pi / 2, math.pi / 2))
	end
	k.ball(0.18, red:Lerp(BLACK, 0.2), cf, nil, "BowTie")
end

function A.FurTufts(k: Kit)
	local fur = k.Dough:Lerp(WHITE, 0.6)
	for i = 0, 5 do
		local angle = math.rad(-170 + i * 36)
		if math.abs(angle - math.pi / 2) > 0.6 then
			k.ball(k.Rng:NextNumber(0.5, 0.65), fur, onDough(k, angle, math.rad(95), 0.05), nil, "Fur")
		end
	end
end

function A.TigerStripes(k: Kit)
	for i = 0, 5 do
		local angle = math.rad(-160 + i * 28)
		k.ellipsoid(Vector3.new(0.1, 0.75, 0.04), BLACK, k.onGlaze(angle, 0.1, 0.005) * CFrame.Angles(0, 0, angle + 0.3), nil, "Stripe")
	end
end

function A.CrabClaws(k: Kit)
	local red = k.Frosting:Lerp(rgb(200, 40, 30), 0.5)
	for _, glove in k.find("Glove") do
		glove.Color = red
	end
	for _, side in { -1, 1 } do
		local h = hand(k, side)
		local shoulderX, shoulderY = side * (k.R + 0.74), -0.25
		for j, tilt in { 0.35, -0.35 } do
			local claw = k.ellipsoid(Vector3.new(0.35, 0.85, 0.35), red, k.at(h.X + side * 0.15, h.Y + 0.45, h.Z) * CFrame.Angles(0, 0, side * tilt), nil, "Claw")
			if j == 2 then
				claw.Size = claw.Size * 0.8
			end
			k.limb(claw, "Arm", side, shoulderX, shoulderY, -0.1)
		end
	end
end

function A.FlamingoLegs(k: Kit)
	local pink = rgb(255, 120, 165)
	for _, part in k.find("Leg") do
		if part:GetAttribute("Limb") == "Leg" then
			part.Color = pink
			part.Size = Vector3.new(part.Size.X, part.Size.Y * 0.6, part.Size.Z * 0.6)
		end
	end
	for _, name in { "Shoe", "Sole" } do
		for _, part in k.find(name) do
			part.Color = pink:Lerp(BLACK, if name == "Sole" then 0.3 else 0.1)
		end
	end
end

function A.FeatherTuft(k: Kit)
	local pink = k.Frosting:Lerp(rgb(255, 120, 170), 0.5)
	for i = -1, 1 do
		local f = k.ellipsoid(Vector3.new(0.22, 0.95, 0.12), pink, k.at(i * 0.22, k.TOP + 0.45, 0.1) * CFrame.Angles(0, 0, -i * 0.4), nil, "Feather")
		k.limb(f, "Sway", 0, 0, k.TOP, 0)
	end
end

function A.BigBeak(k: Kit)
	local cf = k.face(0, k.TOP - 1.15, 0.6)
	k.ellipsoid(Vector3.new(0.7, 0.55, 1.6), rgb(255, 150, 30), cf, nil, "Beak")
	k.ellipsoid(Vector3.new(0.72, 0.3, 0.6), rgb(255, 220, 60), cf * CFrame.new(0, 0.12 * k.s, 0.2 * k.s), nil, "Beak")
	k.ball(0.3, BLACK, cf * CFrame.new(0, 0, -0.75 * k.s), nil, "BeakTip")
end

function A.DinoSpikes(k: Kit)
	local color = k.Frosting:Lerp(BLACK, 0.25)
	for i = 0, 4 do
		local angle = math.rad(30 + i * 30)
		local cf = onDough(k, angle, math.rad(110), 0.0)
		k.wedge(Vector3.new(0.2, 0.55 - math.abs(i - 2) * 0.08, 0.5), color, cf)
	end
end

function A.DragonTail(k: Kit)
	local color = k.Frosting:Lerp(k.Dough, 0.4)
	local pivot = Vector3.new(0, -1.0, 0.7)
	local points = { Vector3.new(0, -1.0, 0.7), Vector3.new(0.5, -1.7, 1.6), Vector3.new(1.4, -2.0, 2.2), Vector3.new(2.2, -1.7, 2.5) }
	for i = 1, 3 do
		local part = segment(k, points[i], points[i + 1], 0.55 - i * 0.12, color, nil, "Tail")
		k.limb(part, "Tail", 0, pivot.X, pivot.Y, pivot.Z)
		local spike = k.wedge(Vector3.new(0.12, 0.35, 0.3), color:Lerp(BLACK, 0.3), k.at(points[i].X, points[i].Y + 0.3, points[i].Z) * CFrame.Angles(0, -0.6, 0))
		k.limb(spike, "Tail", 0, pivot.X, pivot.Y, pivot.Z)
	end
	local tip = k.wedge(Vector3.new(0.12, 0.6, 0.55), color:Lerp(BLACK, 0.3), k.at(points[4].X + 0.2, points[4].Y, points[4].Z) * CFrame.Angles(0, -1.0, math.pi / 2))
	k.limb(tip, "Tail", 0, pivot.X, pivot.Y, pivot.Z)
end

function A.DevilTail(k: Kit)
	local red = rgb(200, 20, 30)
	local pivot = Vector3.new(0, -1.0, 0.7)
	local points = { Vector3.new(0, -1.0, 0.7), Vector3.new(0.7, -1.9, 1.3), Vector3.new(1.6, -1.6, 1.6), Vector3.new(2.1, -0.9, 1.6) }
	for i = 1, 3 do
		k.limb(segment(k, points[i], points[i + 1], 0.16, red, nil, "Tail"), "Tail", 0, pivot.X, pivot.Y, pivot.Z)
	end
	local spade = k.wedge(Vector3.new(0.1, 0.5, 0.5), red, k.at(2.2, -0.6, 1.6) * CFrame.Angles(0, math.pi / 2, 0))
	k.limb(spade, "Tail", 0, pivot.X, pivot.Y, pivot.Z)
end

function A.PhoenixCrest(k: Kit)
	local colors = { rgb(255, 230, 80), rgb(255, 140, 30), rgb(255, 60, 30) }
	for i, color in colors do
		local f = k.ellipsoid(Vector3.new(0.2, 1.1 - i * 0.12, 0.14), color, k.at((i - 2) * 0.2, k.TOP + 0.5, 0.15 + i * 0.12) * CFrame.Angles(-0.35 - i * 0.1, 0, (2 - i) * 0.3), NEON, "Crest")
		k.limb(f, "Sway", 0, 0, k.TOP, 0)
	end
end

function A.PhoenixTail(k: Kit)
	local colors = { rgb(255, 210, 60), rgb(255, 120, 30), rgb(255, 60, 30) }
	local pivot = Vector3.new(0, -1.0, 0.7)
	for i, color in colors do
		local f = k.ellipsoid(Vector3.new(0.3, 2.2, 0.15), color, k.at((i - 2) * 0.55, -2.0, 1.4) * CFrame.Angles(0.6, 0, (i - 2) * 0.35), NEON, "TailFeather")
		f.Transparency = 0.1
		k.limb(f, "Tail", 0, pivot.X, pivot.Y, pivot.Z)
	end
end

function A.Bats(k: Kit)
	for i = 0, 1 do
		local angle = i * math.pi + 0.6
		local p = Vector3.new(math.cos(angle) * (k.R + 1.9), 1.2 - i * 0.8, math.sin(angle) * (k.R + 1.9))
		local body = k.ball(0.32, BLACK, k.at(p.X, p.Y, p.Z), nil, "Bat")
		k.limb(body, "Orbit", 0, 0, 0, 0)
		for _, side in { -1, 1 } do
			local wing = k.wedge(Vector3.new(0.06, 0.3, 0.55), BLACK, k.at(p.X + side * 0.3, p.Y + 0.05, p.Z) * CFrame.Angles(0, side * math.pi / 2, 0))
			k.limb(wing, "Orbit", 0, 0, 0, 0)
		end
	end
end

-- Hats & heads ------------------------------------------------------------------------------------

function A.Tiara(k: Kit)
	local cf = k.at(0, k.TOP + 0.05, -0.15)
	k.ellipsoid(Vector3.new(1.3, 0.16, 0.6), SILVER, cf, METAL, "Tiara")
	for i = -1, 1 do
		k.wedge(Vector3.new(0.1, 0.4 - math.abs(i) * 0.12, 0.25), SILVER, cf * CFrame.new(i * 0.35 * k.s, 0.2 * k.s, -0.1 * k.s) * CFrame.Angles(0, math.pi / 2, 0))
	end
	k.ball(0.2, rgb(255, 120, 200), cf * CFrame.new(0, 0.12 * k.s, -0.3 * k.s), NEON, "Gem")
end

function A.LeafCrown(k: Kit)
	local green = rgb(80, 180, 70)
	for i = 0, 3 do
		local a = i / 4 * TAU + 0.4
		k.ellipsoid(Vector3.new(0.9, 0.12, 0.38), green, k.at(math.cos(a) * 0.45, k.TOP + 0.3, math.sin(a) * 0.45) * CFrame.Angles(0, -a, math.rad(30)), nil, "Leaf")
	end
	k.block(Vector3.new(0.1, 0.5, 0.1), rgb(110, 75, 40), k.at(0, k.TOP + 0.3, 0), WOOD, "Twig")
end

function A.MinerHelmet(k: Kit)
	k.ellipsoid(Vector3.new(1.8, 1.0, 1.6), rgb(255, 200, 30), k.at(0, k.TOP + 0.2, 0), nil, "Helmet")
	k.cylinder(0.08, 2.1, rgb(240, 180, 20), k.at(0, k.TOP - 0.05, 0), nil, "Brim")
	disc(k, k.at(0, k.TOP + 0.3, -0.78) * CFrame.Angles(0, math.pi, 0), 0.2, 0.5, rgb(60, 60, 60), METAL, "Lamp")
	disc(k, k.at(0, k.TOP + 0.3, -0.85) * CFrame.Angles(0, math.pi, 0), 0.06, 0.36, rgb(255, 250, 200), NEON, "LampLight")
end

function A.Fedora(k: Kit)
	local brown = rgb(70, 50, 40)
	k.ellipsoid(Vector3.new(2.3, 0.12, 1.9), brown, k.at(0, k.TOP, 0) * CFrame.Angles(0, 0, 0.08), nil, "Fedora")
	k.ellipsoid(Vector3.new(1.35, 0.85, 1.15), brown, k.at(0, k.TOP + 0.35, 0), nil, "Fedora")
	k.cylinder(0.18, 1.3, BLACK, k.at(0, k.TOP + 0.15, 0), nil, "Band")
end

function A.Goggles(k: Kit)
	k.ellipsoid(Vector3.new(2.6, 0.18, 1.7), rgb(90, 60, 40), k.at(0, k.TOP - 0.15, 0.05) * CFrame.Angles(0.25, 0, 0), nil, "Strap")
	for _, side in { -1, 1 } do
		local cf = k.at(side * 0.4, k.TOP + 0.05, -0.65) * CFrame.Angles(0.6, math.pi, 0)
		disc(k, cf, 0.22, 0.55, rgb(160, 120, 60), METAL, "GoggleRim")
		disc(k, cf * CFrame.new(0, 0, 0.06 * k.s), 0.1, 0.4, rgb(255, 160, 60), GLASS, "GoggleLens").Transparency = 0.2
	end
end

function A.Busby(k: Kit)
	k.ellipsoid(Vector3.new(1.4, 2.1, 1.3), rgb(25, 22, 22), k.at(0, k.TOP + 0.95, 0), nil, "Busby")
	k.ellipsoid(Vector3.new(0.25, 0.7, 0.25), rgb(230, 30, 40), k.at(0.55, k.TOP + 1.5, -0.2), nil, "Plume")
	k.ellipsoid(Vector3.new(2.4, 0.1, 0.12), GOLD, k.face(0, k.TOP - 0.3, 0.03), FOIL, "ChinStrap")
end

function A.IceCrown(k: Kit)
	local ice = rgb(180, 235, 255)
	k.cylinder(0.25, 1.5, ice, k.at(0, k.TOP + 0.1, 0), GLASS, "IceCrown").Transparency = 0.15
	for i = 0, 4 do
		local a = i / 5 * TAU - math.pi / 2
		local spike = k.block(Vector3.new(0.2, 0.75 + (if i == 0 then 0.35 else 0), 0.2), ice, k.at(math.cos(a) * 0.62, k.TOP + 0.55, math.sin(a) * 0.62) * CFrame.Angles(0, math.rad(45), 0), GLASS, "IceSpike")
		spike.Transparency = 0.1
		spike.Reflectance = 0.3
	end
end

function A.TrojanHelmet(k: Kit)
	local bronze = rgb(205, 145, 70)
	k.ellipsoid(Vector3.new(1.9, 1.0, 1.7), bronze, k.at(0, k.TOP + 0.15, 0), FOIL, "Helmet")
	k.ellipsoid(Vector3.new(0.35, 0.9, 2.2), rgb(210, 30, 40), k.at(0, k.TOP + 0.85, 0.2), nil, "Crest")
	for _, side in { -1, 1 } do
		k.block(Vector3.new(0.12, 0.9, 0.5), bronze, k.at(side * 1.05, k.TOP - 0.35, -0.55), FOIL, "CheekGuard")
	end
end

function A.SpaceHelmet(k: Kit)
	local bubble = k.ball(5.6, rgb(200, 230, 255), k.at(0, 0.1, 0), nil, "Bubble")
	bubble.Transparency = 0.82
	bubble.Reflectance = 0.25
	for _, piece in torus(k, CFrame.new(0, -2.35, 0) * CFrame.Angles(math.pi / 2, 0, 0), 1.6, 0.35, 8, WHITE, nil, "Collar") do
		piece.Material = Enum.Material.SmoothPlastic
	end
	k.block(Vector3.new(1.6, 1.8, 0.7), WHITE, k.at(0, -0.2, 1.3), nil, "Backpack")
end

function A.BrainDome(k: Kit)
	local dome = k.ellipsoid(Vector3.new(1.9, 1.4, 1.7), rgb(200, 240, 255), k.at(0, k.TOP + 0.35, 0), GLASS, "Dome")
	dome.Transparency = 0.6
	k.ellipsoid(Vector3.new(1.3, 0.9, 1.1), rgb(255, 140, 180), k.at(0, k.TOP + 0.3, 0), nil, "Brain")
	k.ellipsoid(Vector3.new(0.06, 0.85, 1.05), rgb(220, 100, 140), k.at(0, k.TOP + 0.33, 0), nil, "Brain")
	k.ball(0.15, rgb(120, 220, 255), k.at(0.35, k.TOP + 0.65, -0.3), NEON, "Synapse")
end

function A.Headphones(k: Kit)
	local dark = rgb(40, 40, 50)
	local glow = k.Sprinkles[1] or rgb(0, 255, 220)
	torus(k, CFrame.new(0, 0.9, -0.05), 2.25, 0.2, 6, dark, nil, "Headband", math.rad(15), math.rad(165))
	for _, side in { -1, 1 } do
		local cf = k.at(side * 2.3, 0.75, -0.05) * CFrame.Angles(0, side * math.pi / 2, 0)
		disc(k, cf, 0.4, 1.0, dark, nil, "EarCup")
		disc(k, cf * CFrame.new(0, 0, -0.21 * k.s), 0.05, 0.7, glow, NEON, "EarGlow")
	end
end

function A.Beard(k: Kit)
	local color = rgb(240, 240, 245)
	for i, spec in { { 0.95, 1.25, 0.65 }, { 0.35, 1.0, 0.75 }, { -0.25, 0.65, 0.7 } } do
		k.ellipsoid(Vector3.new(spec[2], spec[3], 0.4), color, k.at(0, spec[1], -1.05 - i * 0.03), nil, "Beard")
	end
end

function A.FireBeard(k: Kit)
	local colors = { rgb(255, 200, 60), rgb(255, 130, 30), rgb(255, 70, 20) }
	for i, spec in { { 0.95, 1.25, 0.65 }, { 0.35, 1.0, 0.75 }, { -0.25, 0.65, 0.7 } } do
		local part = k.ellipsoid(Vector3.new(spec[2], spec[3], 0.4), colors[i], k.at(0, spec[1], -1.05 - i * 0.03), NEON, "Beard")
		k.limb(part, "Sway", 0, 0, 1.2, -1.0)
	end
end

function A.FlameHair(k: Kit)
	local base = k.Frosting:Lerp(rgb(255, 120, 20), 0.5)
	for i = -2, 2 do
		local f = k.ellipsoid(Vector3.new(0.38, 1.0 - math.abs(i) * 0.15, 0.38), if math.abs(i) == 1 then rgb(255, 220, 80) else base, k.at(i * 0.32, k.TOP + 0.45, 0.05) * CFrame.Angles(0, 0, -i * 0.25), NEON, "FlameHair")
		f.Transparency = 0.1
		k.limb(f, "Sway", 0, 0, k.TOP, 0)
	end
end

function A.SummitFlag(k: Kit)
	k.ellipsoid(Vector3.new(1.6, 0.45, 1.3), WHITE, k.at(0, k.TOP + 0.05, 0), nil, "SnowCap")
	k.cylinder(2.0, 0.1, rgb(150, 150, 160), k.at(0.4, k.TOP + 1.0, 0), METAL, "FlagPole")
	local flag = k.block(Vector3.new(0.95, 0.6, 0.05), rgb(230, 40, 50), k.at(0.9, k.TOP + 1.65, 0), nil, "Flag")
	k.limb(flag, "Sway", 0, 0.4, k.TOP + 1.65, 0)
	k.ball(0.18, GOLD, k.at(0.4, k.TOP + 2.0, 0), FOIL, "PoleTip")
end

function A.Chimney(k: Kit)
	local brick = rgb(160, 70, 50)
	k.cylinder(1.1, 0.65, brick, k.at(0.55, k.TOP + 0.45, 0.2), nil, "Chimney")
	k.cylinder(0.18, 0.8, brick:Lerp(BLACK, 0.3), k.at(0.55, k.TOP + 1.0, 0.2), nil, "ChimneyCap")
	for i = 0, 1 do
		local puff = k.ball(0.6 + i * 0.25, rgb(90, 80, 80), k.at(0.75 + i * 0.35, k.TOP + 1.5 + i * 0.6, 0.2), nil, "Smoke")
		puff.Transparency = 0.35 + i * 0.2
		k.limb(puff, "Sway", 0, 0.55, k.TOP + 1.0, 0.2)
	end
end

function A.SmokeStack(k: Kit)
	local brass = rgb(210, 160, 70)
	k.cylinder(1.3, 0.5, brass, k.at(-0.55, k.TOP + 0.55, 0.2), FOIL, "SmokeStack")
	k.cylinder(0.15, 0.7, brass:Lerp(BLACK, 0.3), k.at(-0.55, k.TOP + 1.2, 0.2), METAL, "StackRim")
	for i = 0, 1 do
		local puff = k.ball(0.55 + i * 0.25, rgb(230, 230, 235), k.at(-0.75 - i * 0.3, k.TOP + 1.65 + i * 0.55, 0.2), nil, "Steam")
		puff.Transparency = 0.3 + i * 0.25
		k.limb(puff, "Sway", 0, -0.55, k.TOP + 1.2, 0.2)
	end
end

function A.Volcano(k: Kit)
	local rock = rgb(80, 55, 45)
	for i = 0, 2 do
		k.cylinder(0.4, 1.9 - i * 0.5, rock:Lerp(BLACK, i * 0.1), k.at(0, k.TOP + 0.15 + i * 0.38, 0.05), nil, "Volcano")
	end
	k.cylinder(0.1, 0.8, rgb(255, 120, 20), k.at(0, k.TOP + 1.05, 0.05), NEON, "Lava")
	for _, side in { -1, 1 } do
		k.ellipsoid(Vector3.new(0.18, 0.75, 0.15), rgb(255, 100, 20), k.at(side * 0.45, k.TOP + 0.6, -0.55) * CFrame.Angles(0, 0, side * 0.45), NEON, "LavaRun")
	end
	local blob = k.ball(0.35, rgb(255, 160, 40), k.at(0, k.TOP + 1.5, 0.05), NEON, "LavaBlob")
	k.limb(blob, "Sway", 0, 0, k.TOP + 1.0, 0.05)
end

function A.BombFuse(k: Kit)
	k.cylinder(0.3, 0.7, rgb(60, 60, 70), k.at(0, k.TOP + 0.1, 0), METAL, "FuseCap")
	segment(k, Vector3.new(0, k.TOP + 0.2, 0), Vector3.new(0.3, k.TOP + 0.9, -0.1), 0.1, rgb(200, 180, 140), nil, "Fuse")
	local spark = k.ball(0.35, rgb(255, 220, 80), k.at(0.32, k.TOP + 1.0, -0.1), NEON, "Spark")
	k.limb(spark, "Sway", 0, 0.15, k.TOP + 0.5, 0)
end

function A.JellyDome(k: Kit)
	local dome = k.ellipsoid(Vector3.new(2.4, 1.3, 2.1), k.Frosting:Lerp(WHITE, 0.2), k.at(0, k.TOP + 0.25, 0), NEON, "JellyBell")
	dome.Transparency = 0.55
	for i = 0, 3 do
		local a = i / 4 * TAU
		k.ball(0.22, k.Frosting:Lerp(WHITE, 0.5), k.at(math.cos(a) * 0.5, k.TOP + 0.45, math.sin(a) * 0.5), NEON, "JellySpot")
	end
end

function A.Laurel(k: Kit)
	for i = 0, 9 do
		local a = i / 10 * TAU
		k.ellipsoid(Vector3.new(0.45, 0.12, 0.22), GOLD, k.at(math.cos(a) * 0.8, k.TOP + 0.12, math.sin(a) * 0.8) * CFrame.Angles(0, -a, 0.6), FOIL, "Laurel")
	end
end

-- Held things -------------------------------------------------------------------------------------

function A.Katanas(k: Kit)
	-- crossed on its back, the hilts sticking up over the shoulders
	for _, side in { -1, 1 } do
		local cf = k.at(side * 0.9, 1.3, 0.95) * CFrame.Angles(0, 0, side * math.rad(-30))
		k.block(Vector3.new(0.1, 2.6, 0.22), SILVER, cf * CFrame.new(0, -0.5 * k.s, 0), METAL, "Blade").Reflectance = 0.3
		k.block(Vector3.new(0.42, 0.08, 0.42), GOLD, cf * CFrame.new(0, 0.85 * k.s, 0), FOIL, "Guard")
		k.block(Vector3.new(0.17, 0.75, 0.17), BLACK, cf * CFrame.new(0, 1.3 * k.s, 0), nil, "Hilt")
	end
end

function A.Trident(k: Kit)
	local h = hand(k, 1)
	local gold = rgb(255, 190, 50)
	segment(k, h + Vector3.new(0, -1.6, -0.1), h + Vector3.new(0, 1.9, -0.1), 0.14, gold, FOIL, "Trident")
	k.block(Vector3.new(0.9, 0.12, 0.12), gold, k.at(h.X, h.Y + 1.9, h.Z - 0.1), FOIL, "Trident")
	for i = -1, 1 do
		k.wedge(Vector3.new(0.12, 0.6, 0.18), gold, k.at(h.X + i * 0.38, h.Y + 2.25, h.Z - 0.1) * CFrame.Angles(0, math.pi / 2, 0))
	end
end

function A.Spear(k: Kit)
	local h = hand(k, 1)
	segment(k, h + Vector3.new(0, -2.0, -0.1), h + Vector3.new(0, 2.2, -0.1), 0.13, rgb(120, 90, 60), WOOD, "Spear")
	for _, flip in { 0, math.pi } do
		k.wedge(Vector3.new(0.12, 0.7, 0.3), SILVER, k.at(h.X, h.Y + 2.55, h.Z - 0.1) * CFrame.Angles(0, math.pi / 2 + flip, 0))
	end
	k.ball(0.2, GOLD, k.at(h.X, h.Y + 2.2, h.Z - 0.1), FOIL, "SpearRing")
end

function A.Scepter(k: Kit)
	local h = hand(k, -1)
	segment(k, h + Vector3.new(0, -1.2, -0.1), h + Vector3.new(0, 1.5, -0.1), 0.16, GOLD, FOIL, "Scepter")
	k.ball(0.6, k.Frosting:Lerp(WHITE, 0.15), k.at(h.X, h.Y + 1.8, h.Z - 0.1), NEON, "ScepterOrb")
	for i = 0, 2 do
		local a = i / 3 * TAU
		k.block(Vector3.new(0.1, 0.35, 0.1), GOLD, k.at(h.X + math.cos(a) * 0.25, h.Y + 1.55, h.Z - 0.1 + math.sin(a) * 0.25), FOIL, "ScepterClaw")
	end
end

function A.Ankh(k: Kit)
	local h = hand(k, -1)
	segment(k, h + Vector3.new(0, -1.0, -0.1), h + Vector3.new(0, 0.9, -0.1), 0.16, GOLD, FOIL, "Ankh")
	segment(k, h + Vector3.new(-0.45, 0.75, -0.1), h + Vector3.new(0.45, 0.75, -0.1), 0.15, GOLD, FOIL, "Ankh")
	torus(k, CFrame.new(h + Vector3.new(0, 1.3, -0.1)), 0.38, 0.14, 6, GOLD, FOIL, "Ankh")
end

function A.ForgeHammer(k: Kit)
	local h = hand(k, 1)
	segment(k, h + Vector3.new(0, -0.8, -0.1), h + Vector3.new(0, 1.3, -0.1), 0.18, rgb(120, 85, 55), WOOD, "Handle")
	k.block(Vector3.new(1.1, 0.5, 0.5), rgb(80, 80, 90), k.at(h.X, h.Y + 1.45, h.Z - 0.1), METAL, "HammerHead")
	k.block(Vector3.new(0.12, 0.42, 0.42), rgb(255, 120, 30), k.at(h.X - 0.58, h.Y + 1.45, h.Z - 0.1), NEON, "HotFace")
end

function A.Banhammer(k: Kit)
	local h = hand(k, 1)
	segment(k, h + Vector3.new(0, -1.0, -0.1), h + Vector3.new(0, 1.8, -0.1), 0.22, BLACK, nil, "Handle")
	local head = k.block(Vector3.new(1.9, 0.95, 0.95), rgb(220, 30, 40), k.at(h.X, h.Y + 2.1, h.Z - 0.1), nil, "HammerHead")
	head.Reflectance = 0.15
	for _, side in { -1, 1 } do
		k.block(Vector3.new(0.12, 1.0, 1.0), BLACK, k.at(h.X + side * 0.98, h.Y + 2.1, h.Z - 0.1), METAL, "HammerCap")
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(190, 95)
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "BAN"
	label.TextScaled = true
	label.Font = Enum.Font.LuckiestGuy
	label.TextColor3 = WHITE
	label.Parent = gui
end

function A.Sword(k: Kit)
	local h = hand(k, 1)
	k.block(Vector3.new(0.14, 2.6, 0.3), rgb(255, 240, 200), k.at(h.X, h.Y + 1.7, h.Z - 0.1), NEON, "Blade")
	k.block(Vector3.new(0.75, 0.14, 0.28), GOLD, k.at(h.X, h.Y + 0.35, h.Z - 0.1), FOIL, "Guard")
	k.block(Vector3.new(0.17, 0.6, 0.17), rgb(120, 70, 40), k.at(h.X, h.Y, h.Z - 0.1), nil, "Hilt")
	local flame = k.ellipsoid(Vector3.new(0.4, 2.4, 0.4), rgb(255, 170, 40), k.at(h.X, h.Y + 1.8, h.Z - 0.1), NEON, "Flame")
	flame.Transparency = 0.6
end

function A.LaserSword(k: Kit)
	local h = hand(k, 1)
	k.block(Vector3.new(0.18, 0.7, 0.18), rgb(70, 70, 80), k.at(h.X, h.Y, h.Z - 0.1), METAL, "Hilt")
	local blade = k.cylinder(2.8, 0.22, rgb(255, 50, 50), k.at(h.X, h.Y + 1.75, h.Z - 0.1), NEON, "Laser")
	blade.Transparency = 0.05
	k.cylinder(2.9, 0.4, rgb(255, 120, 120), k.at(h.X, h.Y + 1.75, h.Z - 0.1), NEON, "LaserGlow").Transparency = 0.7
end

function A.LightningBolt(k: Kit)
	local h = hand(k, 1)
	local yellow = rgb(255, 235, 70)
	local points = { h + Vector3.new(0, 0, -0.1), h + Vector3.new(-0.35, 0.8, -0.1), h + Vector3.new(0.25, 1.1, -0.1), h + Vector3.new(-0.15, 2.0, -0.1) }
	for i = 1, 3 do
		segment(k, points[i], points[i + 1], 0.24, yellow, NEON, "Lightning")
	end
end

function A.Broom(k: Kit)
	segment(k, Vector3.new(-2.6, -1.6, 0.9), Vector3.new(2.6, 1.6, 0.9), 0.16, rgb(130, 90, 50), WOOD, "Broom")
	k.ellipsoid(Vector3.new(1.2, 0.7, 0.7), rgb(210, 170, 90), k.at(-2.9, -1.85, 0.9) * CFrame.Angles(0, 0, math.atan2(1.6, 2.6)), nil, "Bristles")
	k.cylinder(0.15, 0.4, rgb(120, 60, 160), k.at(-2.35, -1.45, 0.9) * CFrame.Angles(0, 0, -math.atan2(2.6, 1.6)), nil, "BroomBand")
end

function A.YoYo(k: Kit)
	local h = hand(k, 1)
	local bottom = h + Vector3.new(0.1, -2.0, -0.2)
	segment(k, h, bottom, 0.04, WHITE, nil, "String")
	local cf = CFrame.new(bottom) * CFrame.Angles(0, math.pi / 2, 0)
	for _, x in { -0.13, 0.13 } do
		disc(k, scaled(k, cf * CFrame.new(0, 0, x)), 0.2, 0.75, k.Frosting, nil, "YoYo")
	end
	disc(k, scaled(k, cf), 0.08, 0.3, WHITE, nil, "YoYoAxle")
end

function A.StarWand(k: Kit)
	local h = hand(k, 1)
	segment(k, h + Vector3.new(0, -0.3, -0.1), h + Vector3.new(0, 1.4, -0.1), 0.1, rgb(240, 240, 255), nil, "Wand")
	local tip = k.at(h.X, h.Y + 1.7, h.Z - 0.1)
	sparkle(k, tip, 0.9, rgb(255, 235, 120), "WandStar")
	k.ball(0.25, WHITE, tip, NEON, "WandStar")
end

function A.FairyWand(k: Kit)
	local h = hand(k, 1)
	segment(k, h + Vector3.new(0, -0.3, -0.1), h + Vector3.new(0, 1.4, -0.1), 0.1, rgb(255, 210, 240), nil, "Wand")
	local tip = k.at(h.X, h.Y + 1.7, h.Z - 0.1)
	sparkle(k, tip, 0.9, rgb(255, 160, 230), "WandStar")
	k.ball(0.25, WHITE, tip, NEON, "WandStar")
	for i = 1, 2 do
		k.ball(0.12, rgb(255, 230, 250), k.at(h.X + 0.25 * i, h.Y + 1.7 - 0.35 * i, h.Z - 0.1), NEON, "Sparkle")
	end
end

function A.Harp(k: Kit)
	local h = hand(k, -1)
	local base = h + Vector3.new(0, -0.6, -0.2)
	local gold = rgb(255, 205, 80)
	segment(k, base, base + Vector3.new(0, 1.8, 0), 0.16, gold, FOIL, "Harp")
	segment(k, base, base + Vector3.new(-1.0, 0.3, 0), 0.14, gold, FOIL, "Harp")
	segment(k, base + Vector3.new(-1.0, 0.3, 0), base + Vector3.new(0, 1.8, 0), 0.16, gold, FOIL, "Harp")
	for i = 1, 3 do
		local x = -i * 0.24
		segment(k, base + Vector3.new(x, 0.08 + i * 0.07, 0), base + Vector3.new(x, 1.8 + x * 1.5, 0), 0.03, WHITE, NEON, "String")
	end
end

function A.Shield(k: Kit)
	local h = hand(k, -1)
	local cf = k.at(h.X - 0.3, h.Y - 0.2, h.Z - 0.45) * CFrame.Angles(0, 0.35, 0)
	disc(k, cf, 0.18, 2.0, rgb(200, 60, 50), nil, "Shield")
	disc(k, cf * CFrame.new(0, 0, 0.06 * k.s), 0.2, 2.15, GOLD, FOIL, "ShieldRim")
	k.ball(0.5, GOLD, cf * CFrame.new(0, 0, -0.12 * k.s), FOIL, "ShieldBoss")
end

function A.BrickShield(k: Kit)
	local h = hand(k, -1)
	local cf = k.at(h.X - 0.2, h.Y, h.Z - 0.45) * CFrame.Angles(0, 0.35, 0)
	k.block(Vector3.new(1.4, 1.5, 0.25), rgb(170, 70, 50), cf, nil, "Bricks")
	for i = 0, 1 do
		k.block(Vector3.new(1.42, 0.06, 0.27), rgb(220, 200, 180), cf * CFrame.new(0, (-0.25 + i * 0.5) * k.s, 0), nil, "Mortar")
	end
	for i = -1, 1 do
		local flame = k.ellipsoid(Vector3.new(0.35, 0.8, 0.3), if i == 0 then rgb(255, 220, 70) else rgb(255, 110, 30), cf * CFrame.new(i * 0.4 * k.s, 1.0 * k.s, 0), NEON, "Flame")
		k.limb(flame, "Sway", 0, h.X, h.Y + 0.8, h.Z)
	end
end

function A.Envelope(k: Kit)
	local h = hand(k, -1)
	local cf = k.at(h.X, h.Y + 0.6, h.Z - 0.35)
	k.block(Vector3.new(1.2, 0.8, 0.08), WHITE, cf, nil, "Envelope")
	k.wedge(Vector3.new(0.09, 0.4, 1.2), rgb(235, 235, 240), cf * CFrame.new(0, 0.2 * k.s, -0.04 * k.s) * CFrame.Angles(math.pi / 2, math.pi / 2, 0))
	k.ball(0.22, rgb(220, 30, 40), cf * CFrame.new(0, 0, -0.08 * k.s), nil, "Seal")
end

function A.ShoppingBags(k: Kit)
	for i, side in { -1, 1 } do
		local h = hand(k, side)
		local color = if i == 1 then rgb(255, 90, 170) else rgb(80, 200, 255)
		k.block(Vector3.new(0.9, 1.0, 0.45), color, k.at(h.X, h.Y - 0.85, h.Z), nil, "Bag")
		torus(k, CFrame.new(h + Vector3.new(0, -0.3, 0)), 0.25, 0.06, 3, BLACK, nil, "BagHandle", 0, math.pi)
	end
end

function A.Joystick(k: Kit)
	local cf = k.at(0, k.TOP + 0.15, 0)
	k.block(Vector3.new(1.3, 0.35, 0.9), rgb(30, 30, 40), cf, nil, "ArcadeBase")
	k.cylinder(0.75, 0.12, rgb(160, 160, 170), cf * CFrame.new(-0.25 * k.s, 0.5 * k.s, 0), METAL, "Stick")
	k.ball(0.4, rgb(230, 30, 40), cf * CFrame.new(-0.25 * k.s, 0.9 * k.s, 0), nil, "Knob").Reflectance = 0.2
	for i = 0, 1 do
		k.cylinder(0.12, 0.25, if i == 0 then rgb(255, 220, 40) else rgb(40, 160, 255), cf * CFrame.new((0.25 + i * 0.3) * k.s, 0.2 * k.s, -0.1 * k.s), NEON, "Button")
	end
end

-- Tech --------------------------------------------------------------------------------------------

function A.RoboPlates(k: Kit)
	for i = 0, 2 do
		local angle = math.rad(-150 + i * 60)
		local cf = onDough(k, angle, math.rad(85), 0.02)
		k.block(Vector3.new(0.75, 0.1, 0.8), rgb(160, 165, 175), cf, METAL, "Plate")
		k.ball(0.14, rgb(110, 110, 120), cf * CFrame.new(0.28 * k.s, 0.06 * k.s, 0.28 * k.s), METAL, "Bolt")
	end
end

function A.RoboClaw(k: Kit)
	local h = hand(k, 1)
	for _, glove in k.find("Glove") do
		if glove.Position.X > 0 then
			glove.Color = rgb(150, 155, 165)
			glove.Material = METAL
		end
	end
	local shoulderX, shoulderY = k.R + 0.74, -0.25
	for _, tilt in { 0.4, -0.4 } do
		local prong = k.block(Vector3.new(0.14, 0.6, 0.2), rgb(150, 155, 165), k.at(h.X + 0.1, h.Y + 0.4, h.Z) * CFrame.Angles(0, 0, tilt), METAL, "Claw")
		if k.has("Arms") then
			k.limb(prong, "Arm", 1, shoulderX, shoulderY, -0.1)
		end
	end
end

function A.WindUpKey(k: Kit)
	local brass = rgb(220, 170, 70)
	local center = Vector3.new(0, 0.2, 1.0)
	local shaft = segment(k, center, center + Vector3.new(0, 0, 0.6), 0.18, brass, FOIL, "Key")
	k.limb(shaft, "Roll", 0, center.X, center.Y, center.Z)
	for _, side in { -1, 1 } do
		local lobe = k.ellipsoid(Vector3.new(0.65, 0.45, 0.12), brass, k.at(side * 0.38, 0.2, 1.65), FOIL, "Key")
		k.limb(lobe, "Roll", 0, center.X, center.Y, center.Z)
	end
end

function A.Bolts(k: Kit)
	for i = 0, 2 do
		local cf = onDough(k, math.rad(-140 + i * 50), math.rad(80), 0.05)
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(0.18, 0.4, 0.4) * k.s
		p.Name = "Nut"
		k.add(p, cf * CFrame.Angles(0, 0, math.pi / 2), rgb(170, 175, 185), METAL)
	end
	segment(k, Vector3.new(1.2, k.TOP - 0.2, 0.1), Vector3.new(1.5, k.TOP + 0.6, 0.1), 0.16, rgb(170, 175, 185), METAL, "Bolt")
	k.cylinder(0.15, 0.4, rgb(150, 155, 165), k.at(1.52, k.TOP + 0.65, 0.1), METAL, "BoltHead")
end

function A.ShoulderCannons(k: Kit)
	for _, side in { -1, 1 } do
		k.block(Vector3.new(0.7, 0.4, 0.8), rgb(70, 72, 80), k.at(side * 1.4, k.TOP - 0.25, 0.2), METAL, "CannonMount")
		local cf = k.at(side * 1.4, k.TOP + 0.1, -0.15) * CFrame.Angles(0, math.pi / 2, 0)
		local barrel = Instance.new("Part")
		barrel.Shape = Enum.PartType.Cylinder
		barrel.Size = Vector3.new(1.3, 0.35, 0.35) * k.s
		barrel.Name = "Cannon"
		k.add(barrel, cf, rgb(90, 92, 100), METAL)
		k.ball(0.22, rgb(255, 160, 40), k.at(side * 1.4, k.TOP + 0.1, -0.82), NEON, "Muzzle")
	end
end

function A.WeldMask(k: Kit)
	local dark = rgb(50, 50, 60)
	k.block(Vector3.new(1.6, 0.9, 0.2), dark, k.at(0, k.TOP + 0.35, -0.35) * CFrame.Angles(math.rad(-55), 0, 0), nil, "WeldMask")
	k.block(Vector3.new(0.8, 0.25, 0.22), rgb(60, 255, 120), k.at(0, k.TOP + 0.4, -0.42) * CFrame.Angles(math.rad(-55), 0, 0), GLASS, "WeldWindow")
	local h = hand(k, 1)
	segment(k, h, h + Vector3.new(0.3, 0.9, -0.3), 0.18, rgb(120, 120, 130), METAL, "Torch")
	k.ball(0.28, rgb(120, 200, 255), k.at(h.X + 0.35, h.Y + 1.05, h.Z - 0.35), NEON, "TorchFlame")
end

function A.CPUChip(k: Kit)
	local cf = k.at(0, k.TOP + 0.1, 0)
	k.block(Vector3.new(1.3, 0.18, 1.3), rgb(25, 30, 35), cf, nil, "Chip")
	k.block(Vector3.new(0.6, 0.2, 0.6), rgb(200, 205, 215), cf * CFrame.new(0, 0.03 * k.s, 0), METAL, "ChipLid")
	for i = -1, 1 do
		for _, side in { -1, 1 } do
			k.block(Vector3.new(0.1, 0.06, 0.32), GOLD, cf * CFrame.new(i * 0.38 * k.s, -0.02 * k.s, side * 0.78 * k.s), FOIL, "Pin")
		end
	end
	k.ball(0.15, rgb(80, 200, 255), cf * CFrame.new(0.45 * k.s, 0.12 * k.s, -0.45 * k.s), NEON, "ChipLight")
end

function A.ServerRack(k: Kit)
	local cf = k.at(-(k.R + 1.6), -0.4, 0.4) * CFrame.Angles(0, math.rad(20), 0)
	k.block(Vector3.new(1.5, 3.0, 1.0), rgb(35, 38, 48), cf, METAL, "Server")
	for i = 0, 3 do
		k.block(Vector3.new(1.15, 0.08, 0.05), if i % 2 == 0 then rgb(60, 255, 120) else rgb(80, 170, 255), cf * CFrame.new(0, (-1.0 + i * 0.65) * k.s, -0.52 * k.s), NEON, "ServerLED")
	end
end

function A.VendingMachine(k: Kit)
	local cf = k.at(k.R + 1.75, -0.6, 0.4) * CFrame.Angles(0, math.rad(-20), 0)
	k.block(Vector3.new(2.0, 2.6, 0.9), rgb(220, 40, 60), cf, nil, "Vending")
	local window = k.block(Vector3.new(1.3, 1.6, 0.05), rgb(200, 240, 255), cf * CFrame.new(-0.2 * k.s, 0.3 * k.s, -0.46 * k.s), GLASS, "VendingWindow")
	window.Transparency = 0.4
	for i = 0, 2 do
		k.block(Vector3.new(0.3, 0.4, 0.2), ({ rgb(255, 220, 40), rgb(80, 200, 255), rgb(120, 255, 120) })[i + 1], cf * CFrame.new((-0.6 + i * 0.4) * k.s, 0.55 * k.s, -0.3 * k.s), nil, "Snack")
	end
	k.block(Vector3.new(0.25, 0.5, 0.06), BLACK, cf * CFrame.new(0.72 * k.s, 0.4 * k.s, -0.46 * k.s), nil, "CoinSlot")
end

function A.ConveyorBelt(k: Kit)
	local y = -k.TOP - 1.45
	k.block(Vector3.new(3.2, 0.25, 1.6), rgb(40, 40, 45), k.at(0, y, -0.1), nil, "Belt")
	for i = 0, 3 do
		local roller = Instance.new("Part")
		roller.Shape = Enum.PartType.Cylinder
		roller.Size = Vector3.new(1.7, 0.4, 0.4) * k.s
		roller.Name = "Roller"
		k.add(roller, k.at(-1.2 + i * 0.8, y - 0.25, -0.1) * CFrame.Angles(0, math.pi / 2, 0), rgb(150, 150, 160), METAL)
	end
	for _, side in { -1, 1 } do
		k.block(Vector3.new(3.2, 0.12, 0.08), rgb(255, 210, 0), k.at(0, y + 0.13, -0.1 + side * 0.8), NEON, "Stripe")
	end
end

function A.Skateboard(k: Kit)
	local y = -k.TOP - 1.45
	k.ellipsoid(Vector3.new(1.3, 0.14, 3.4), rgb(170, 90, 255), k.at(0, y, -0.15), nil, "Deck")
	k.block(Vector3.new(0.9, 0.05, 2.6), rgb(0, 255, 230), k.at(0, y - 0.1, -0.15), NEON, "Underglow")
	for _, z in { -1.1, 0.8 } do
		for _, side in { -1, 1 } do
			local wheel = Instance.new("Part")
			wheel.Shape = Enum.PartType.Cylinder
			wheel.Size = Vector3.new(0.18, 0.35, 0.35) * k.s
			wheel.Name = "Wheel"
			k.add(wheel, k.at(side * 0.45, y - 0.25, z - 0.15), rgb(255, 230, 60))
		end
	end
end

function A.Surfboard(k: Kit)
	local board = k.ellipsoid(Vector3.new(1.3, 4.4, 0.2), rgb(255, 230, 120), k.at(0.4, 0.3, 1.15) * CFrame.Angles(0, 0, -0.25), nil, "Surfboard")
	board.Reflectance = 0.1
	k.ellipsoid(Vector3.new(0.35, 4.2, 0.22), rgb(255, 100, 30), k.at(0.4, 0.3, 1.16) * CFrame.Angles(0, 0, -0.25), nil, "Stripe")
end

function A.PixelBlocks(k: Kit)
	local colors = { rgb(255, 40, 200), rgb(0, 255, 220), rgb(255, 230, 0), rgb(120, 255, 80) }
	for i = 0, 5 do
		local angle = math.rad(-170 + i * 30)
		k.block(Vector3.one * 0.32, colors[i % #colors + 1], onDough(k, angle, math.rad(70 + (i % 2) * 40), 0.1), NEON, "Pixel")
	end
end

function A.GlitchSlices(k: Kit)
	for i = 0, 2 do
		local slice = k.block(Vector3.new(4.6, 0.3, 1.8), if i % 2 == 0 then rgb(255, 0, 200) else rgb(0, 255, 230), k.at(if i % 2 == 0 then 0.35 else -0.35, -1.2 + i * 1.2, 0), NEON, "GlitchSlice")
		slice.Transparency = 0.7
	end
end

function A.BinaryRing(k: Kit)
	local green = rgb(60, 255, 120)
	for i = 0, 7 do
		local a = i / 8 * TAU
		local p = Vector3.new(math.cos(a) * (k.R + 1.6), 0.4 + math.sin(a * 2) * 0.3, math.sin(a) * (k.R + 1.6))
		local bit = if i % 3 == 0 then k.ellipsoid(Vector3.new(0.25, 0.42, 0.08), green, k.at(p.X, p.Y, p.Z) * CFrame.Angles(0, -a, 0), NEON, "Bit")
			else k.block(Vector3.new(0.09, 0.42, 0.09), green, k.at(p.X, p.Y, p.Z), NEON, "Bit")
		k.limb(bit, "Orbit", 0, 0, 0, 0)
	end
end

function A.WifiArcs(k: Kit)
	local green = rgb(120, 255, 160)
	local base = CFrame.new(0, k.TOP + 0.3, 0)
	for i = 1, 3 do
		torus(k, base, 0.4 * i, 0.14, 2 + i, green, NEON, "Wifi", math.rad(45), math.rad(135))
	end
	k.ball(0.25, green, k.at(0, k.TOP + 0.35, 0), NEON, "WifiDot")
end

function A.FiberStrands(k: Kit)
	local colors = { rgb(255, 80, 200), rgb(80, 220, 255), rgb(255, 240, 120), rgb(120, 255, 160), rgb(200, 120, 255) }
	for i = -2, 2 do
		local from = Vector3.new(i * 0.3, k.TOP - 0.1, 0.1)
		local to = Vector3.new(i * 0.75, k.TOP + 1.3 - math.abs(i) * 0.2, 0.1 + math.abs(i) * 0.1)
		local strand = segment(k, from, to, 0.06, WHITE, nil, "Fiber")
		strand.Transparency = 0.3
		local tip = k.ball(0.22, colors[i + 3], k.at(to.X, to.Y, to.Z), NEON, "FiberTip")
		k.limb(strand, "Sway", 0, from.X, from.Y, from.Z)
		k.limb(tip, "Sway", 0, from.X, from.Y, from.Z)
	end
end

function A.AtomOrbits(k: Kit)
	local color = rgb(200, 140, 255)
	for _, tilt in { math.rad(60), math.rad(-60) } do
		local center = CFrame.new(0, 0, 0.3) * CFrame.Angles(0, 0, tilt) * CFrame.Angles(math.rad(75), 0, 0)
		for _, piece in torus(k, center, k.R + 1.4, 0.07, 7, color, NEON, "Orbit") do
			piece.Transparency = 0.3
		end
	end
	local electron = k.ball(0.35, rgb(120, 230, 255), k.at(k.R + 1.4, 0, 0.3), NEON, "Electron")
	k.limb(electron, "Orbit", 0, 0, 0, 0)
end

function A.HoloRing(k: Kit)
	local color = rgb(120, 240, 255)
	local center = CFrame.new(0, 0.2, 0) * CFrame.Angles(math.rad(80), 0, math.rad(15))
	for _, piece in torus(k, center, k.R + 1.4, 0.12, 8, color, NEON, "HoloRing") do
		piece.Transparency = 0.35
		k.limb(piece, "Orbit", 0, 0, 0, 0)
	end
end

function A.NeonTube(k: Kit)
	local color = if #k.Sprinkles > 0 then k.Sprinkles[1] else rgb(0, 255, 200)
	torus(k, CFrame.new(0, 0, 0.45), k.R + 1.05, 0.14, 10, color, NEON, "NeonTube")
end

function A.LoadingRing(k: Kit)
	local center = Vector3.new(0, k.TOP + 1.2, 0)
	local pieces = torus(k, CFrame.new(center), 0.55, 0.16, 7, rgb(0, 255, 220), NEON, "Loading", 0, math.rad(300))
	for i, piece in pieces do
		piece.Transparency = (i - 1) / #pieces * 0.8
		k.limb(piece, "Roll", 0, center.X, center.Y, center.Z)
	end
end

function A.ErrorSign(k: Kit)
	screen(k, k.at(0, k.TOP + 1.0, 0.05), Vector2.new(1.8, 0.9), rgb(60, 60, 70), rgb(30, 30, 40), "404", rgb(255, 60, 60))
end

function A.BlueScreen(k: Kit)
	screen(k, k.at(0, k.TOP + 1.0, 0.05), Vector2.new(1.8, 1.1), rgb(60, 60, 70), rgb(20, 70, 210), ":(", WHITE, Enum.Font.GothamBold)
end

function A.Terminal(k: Kit)
	screen(k, k.at(0, k.TOP + 1.0, 0.05), Vector2.new(1.8, 0.9), rgb(40, 40, 45), rgb(5, 15, 5), "> sudo_", rgb(60, 255, 100), Enum.Font.Code)
end

function A.Billboard(k: Kit)
	for _, side in { -1, 1 } do
		k.block(Vector3.new(0.12, 1.0, 0.12), rgb(80, 80, 90), k.at(side * 0.7, k.TOP + 0.4, 0.2), METAL, "Post")
	end
	screen(k, k.at(0, k.TOP + 1.25, 0.2), Vector2.new(2.4, 0.9), rgb(50, 50, 60), k.Frosting:Lerp(BLACK, 0.55), "DONUTS 24/7", k.Frosting:Lerp(WHITE, 0.5), Enum.Font.LuckiestGuy)
end

function A.SentinelEye(k: Kit)
	local center = Vector3.new(0, k.TOP + 1.1, 0)
	k.ball(0.9, rgb(40, 20, 20), k.at(center.X, center.Y, center.Z), METAL, "Sentinel")
	k.ball(0.55, rgb(255, 40, 30), k.at(center.X, center.Y, center.Z - 0.25), NEON, "SentinelEye")
	for _, piece in torus(k, CFrame.new(center) * CFrame.Angles(math.pi / 2, 0, 0), 0.75, 0.08, 6, rgb(255, 80, 60), NEON, "SentinelRing") do
		k.limb(piece, "Orbit", 0, center.X, center.Y, center.Z)
	end
end

function A.Checkerboard(k: Kit)
	-- MissingDonut: the missing-texture checkerboard
	for i, piece in k.find("Frosting") do
		if i % 2 == 0 and piece:IsA("Part") and (piece :: Part).Shape == Enum.PartType.Cylinder then
			piece.Color = BLACK
		end
	end
	for i, piece in k.find("Dough") do
		piece.Color = if i % 2 == 0 then rgb(255, 0, 220) else BLACK
	end
end

-- Space -------------------------------------------------------------------------------------------

function A.GalaxySwirl(k: Kit)
	-- a little spiral galaxy floating above, facing out and slowly turning
	local center = Vector3.new(0, k.TOP + 1.4, 0)
	local disk = disc(k, k.at(center.X, center.Y, center.Z), 0.05, 2.0, rgb(120, 80, 255), NEON, "Galaxy")
	disk.Transparency = 0.7
	k.ball(0.38, rgb(255, 240, 200), k.at(center.X, center.Y, center.Z - 0.05), NEON, "GalaxyCore")
	for arm = 0, 1 do
		for i = 1, 4 do
			local a = arm * math.pi + i * 0.75
			local r = i * 0.22
			local star = k.ball(0.17 - i * 0.015, if i >= 3 then rgb(150, 200, 255) else rgb(255, 200, 255), k.at(center.X + math.cos(a) * r, center.Y + math.sin(a) * r, center.Z - 0.06), NEON, "GalaxyStar")
			k.limb(star, "Roll", 0, center.X, center.Y, center.Z)
		end
	end
	k.limb(disk, "Roll", 0, center.X, center.Y, center.Z)
end

function A.NovaBurst(k: Kit)
	local center = Vector3.new(0, 0, 0.9)
	for i = 0, 7 do
		local a = i / 8 * TAU
		local ray = k.ellipsoid(Vector3.new(0.3, 1.5 - (i % 2) * 0.5, 0.1), if i % 2 == 0 then rgb(255, 230, 120) else rgb(255, 150, 60), k.at(math.cos(a) * 3.0, math.sin(a) * 3.0, 0.9) * CFrame.Angles(0, 0, a - math.pi / 2), NEON, "NovaRay")
		ray.Transparency = 0.15
		k.limb(ray, "Roll", 0, center.X, center.Y, center.Z)
	end
end

function A.InfinityRing(k: Kit)
	local color = rgb(220, 200, 255)
	for _, side in { -1, 1 } do
		for _, piece in torus(k, CFrame.new(side * 0.55, k.TOP + 1.2, 0), 0.5, 0.14, 6, color, NEON, "Infinity") do
			k.limb(piece, "Orbit", 0, 0, k.TOP + 1.2, 0)
		end
	end
end

function A.NebulaCloud(k: Kit)
	local colors = { rgb(255, 120, 220), rgb(150, 110, 255), rgb(100, 200, 255) }
	for i, color in colors do
		local a = i / 3 * TAU
		local puff = k.ball(1.1, color, k.at(math.cos(a) * 2.9, 0.6 + math.sin(a * 2) * 0.6, math.sin(a) * 2.9), NEON, "Nebula")
		puff.Transparency = 0.6
		k.limb(puff, "Orbit", 0, 0, 0, 0)
	end
end

function A.Prism(k: Kit)
	local center = Vector3.new(0, k.TOP + 1.3, 0)
	for _, flip in { 0, math.pi } do
		local piece = k.wedge(Vector3.new(0.7, 0.8, 0.45), rgb(230, 245, 255), k.at(center.X, center.Y, center.Z) * CFrame.Angles(0, flip, 0) * CFrame.new(0, 0, 0.225 * k.s), GLASS)
		piece.Transparency = 0.25
		piece.Reflectance = 0.3
		k.limb(piece, "Orbit", 0, center.X, center.Y, center.Z)
	end
	local colors = { rgb(255, 70, 70), rgb(255, 230, 60), rgb(70, 220, 255) }
	for i, color in colors do
		local ray = k.block(Vector3.new(1.2, 0.08, 0.08), color, k.at(center.X + 0.9, center.Y - 0.1 - i * 0.1, center.Z) * CFrame.Angles(0, 0, -0.15 * i), NEON, "PrismRay")
		k.limb(ray, "Orbit", 0, center.X, center.Y, center.Z)
	end
end

function A.Moon(k: Kit)
	local center = CFrame.new(-2.7, k.TOP + 0.6, 0.2) * CFrame.Angles(0, 0, 0.5)
	for _, piece in torus(k, center, 0.55, 0.32, 5, rgb(255, 240, 170), NEON, "Moon", math.rad(70), math.rad(290)) do
		k.limb(piece, "Orbit", 0, 0, 0, 0)
	end
end

function A.FallingStars(k: Kit)
	for i = 0, 1 do
		local a = i * math.pi + 0.8
		local cf = k.at(math.cos(a) * 3.0, 1.3 - i * 1.4, math.sin(a) * 3.0)
		for _, part in sparkle(k, cf, 0.9, rgb(255, 235, 140)) do
			k.limb(part, "Orbit", 0, 0, 0, 0)
		end
	end
end

function A.Flower(k: Kit)
	local center = k.at(0.5, k.TOP + 0.55, -0.05)
	local petal = k.Frosting:Lerp(WHITE, 0.3)
	k.ball(0.42, rgb(255, 220, 80), center, NEON, "FlowerHeart")
	for i = 0, 4 do
		local a = i / 5 * TAU
		k.ellipsoid(Vector3.new(0.5, 0.3, 0.12), petal, center * CFrame.Angles(0, 0, a) * CFrame.new(0.38 * k.s, 0, 0.03 * k.s), nil, "Petal")
	end
end

function A.AuroraRibbon(k: Kit)
	for i, color in { rgb(120, 255, 200), rgb(190, 120, 255) } do
		local ribbon = k.ellipsoid(Vector3.new(0.7, 4.4, 0.08), color, k.at((i - 1.5) * 1.6, 0.2, 1.1) * CFrame.Angles(0.15, 0, (i - 1.5) * 0.5), NEON, "AuroraRibbon")
		ribbon.Transparency = 0.45
		k.limb(ribbon, "Cape", 0, 0, 1.5, 0.9)
	end
end

function A.SeraphWings(k: Kit)
	for _, side in { -1, 1 } do
		for f = 0, 1 do
			local wing = k.ellipsoid(Vector3.new(1.9 - f * 0.4, 0.6, 0.16), rgb(255, 250, 225), k.at(side * (k.R + 0.7 + f * 0.2), 2.0 + f * 0.4, 0.75) * CFrame.Angles(0, side * math.rad(-15), side * math.rad(55 + f * 15)), NEON, "Wing")
			k.limb(wing, "Wing", side, side * (k.R - 0.2), 1.4, 0.7)
		end
	end
end

function A.CosmicEye(k: Kit)
	local cf = k.at(0, k.TOP + 1.1, -0.1)
	k.ellipsoid(Vector3.new(1.1, 0.6, 0.35), WHITE, cf, nil, "CosmicEye")
	k.ball(0.42, rgb(170, 90, 255), cf * CFrame.new(0, 0, -0.12 * k.s), NEON, "Iris")
	k.ball(0.2, BLACK, cf * CFrame.new(0, 0, -0.27 * k.s), nil, "Pupil")
end

function A.VoidRing(k: Kit)
	torus(k, CFrame.new(0, 0, 0.6), k.R + 1.25, 0.3, 10, rgb(30, 10, 50), nil, "VoidRing")
	for _, piece in torus(k, CFrame.new(0, 0, 0.62), k.R + 1.25, 0.38, 10, rgb(150, 70, 255), NEON, "VoidGlow") do
		piece.Transparency = 0.75
	end
end

function A.AccretionDisk(k: Kit)
	local center = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(75), 0, math.rad(-12))
	local colors = { rgb(255, 170, 60), rgb(255, 230, 150), rgb(255, 110, 40) }
	for _, piece in torus(k, center, k.R + 1.5, 0.3, 12, WHITE, NEON, "Accretion", nil, nil, colors) do
		piece.Transparency = 0.2
		k.limb(piece, "Orbit", 0, 0, 0, 0)
	end
end

function A.GravityRings(k: Kit)
	for i, tilt in { math.rad(70), math.rad(110) } do
		local center = CFrame.new(0, 0, 0) * CFrame.Angles(tilt, math.rad(i * 30), 0)
		for _, piece in torus(k, center, k.R + 1.2 + i * 0.35, 0.1, 7, rgb(90, 200, 255), NEON, "GravityRing") do
			piece.Transparency = 0.25
			k.limb(piece, "Orbit", 0, 0, 0, 0)
		end
	end
end

function A.QuasarJets(k: Kit)
	for _, dir in { 1, -1 } do
		local core = k.ellipsoid(Vector3.new(0.45, 3.0, 0.45), rgb(220, 240, 255), k.at(0, dir * (k.TOP + 1.4), 0.4), NEON, "Jet")
		core.Transparency = 0.1
		local glow = k.ellipsoid(Vector3.new(1.0, 3.6, 1.0), rgb(110, 170, 255), k.at(0, dir * (k.TOP + 1.5), 0.4), NEON, "JetGlow")
		glow.Transparency = 0.7
	end
end

function A.Wormhole(k: Kit)
	local center = Vector3.new(0, 0.1, 1.0)
	k.cylinder(0.1, 3.4, rgb(5, 0, 15), k.at(center.X, center.Y, center.Z + 0.1) * CFrame.Angles(math.pi / 2, 0, 0), nil, "WormholeCore")
	for i, spec in { { Radius = 2.3, Color = rgb(170, 90, 255) }, { Radius = 1.8, Color = rgb(90, 160, 255) } } do
		for _, piece in torus(k, CFrame.new(center + Vector3.new(0, 0, i * 0.05)), spec.Radius, 0.22, 8, spec.Color, NEON, "Wormhole") do
			piece.Transparency = 0.15 * i
			k.limb(piece, "Roll", 0, center.X, center.Y, center.Z)
		end
	end
end

function A.Spaghetti(k: Kit)
	-- spaghettified: strands of dough and glaze stretched off towards the black hole
	for i = 0, 4 do
		local y = -1.4 + i * 0.7
		local from = Vector3.new(k.R + 0.3, y * 0.8, 0.1)
		local to = Vector3.new(k.R + 2.6 + (i % 2) * 0.6, y * 1.05, 0.3)
		local strand = segment(k, from, to, 0.18 - (i % 2) * 0.05, if i % 2 == 0 then k.Frosting else k.Dough, nil, "Spaghetti")
		strand.Transparency = 0.1 + (i % 3) * 0.15
	end
end

-- Toys, spooky, time ------------------------------------------------------------------------------

function A.AlarmClock(k: Kit)
	-- the hole is a clock face; bells on top
	local center = Vector3.new(0, 0, -0.25)
	disc(k, k.at(center.X, center.Y, center.Z) * CFrame.Angles(0, math.pi, 0), 0.12, 1.45, rgb(255, 250, 235), nil, "ClockFace")
	for i = 0, 3 do
		local a = i / 4 * TAU
		k.block(Vector3.new(0.06, 0.18, 0.04), BLACK, k.at(math.cos(a) * 0.55, math.sin(a) * 0.55, center.Z - 0.07) * CFrame.Angles(0, 0, a + math.pi / 2), nil, "Tick")
	end
	local hour = k.block(Vector3.new(0.08, 0.38, 0.04), BLACK, k.at(0, 0.17, center.Z - 0.09), nil, "Hand")
	local minute = k.block(Vector3.new(0.06, 0.55, 0.04), rgb(200, 30, 40), k.at(0.24, 0.0, center.Z - 0.1) * CFrame.Angles(0, 0, -math.pi / 2), nil, "Hand")
	k.limb(minute, "Roll", 0, center.X, center.Y, center.Z)
	k.limb(hour, "Roll", 0, center.X, center.Y, center.Z)
	for _, side in { -1, 1 } do
		k.ellipsoid(Vector3.new(0.75, 0.55, 0.75), GOLD, k.at(side * 0.75, k.TOP + 0.25, 0) * CFrame.Angles(0, 0, side * -0.4), FOIL, "Bell")
	end
end

function A.Hourglass(k: Kit)
	local center = Vector3.new(-2.8, 1.2, 0.2)
	local cf = k.at(center.X, center.Y, center.Z)
	for _, dir in { 1, -1 } do
		local bulb = k.ellipsoid(Vector3.new(0.6, 0.65, 0.6), rgb(220, 240, 255), cf * CFrame.new(0, dir * 0.33 * k.s, 0), GLASS, "Hourglass")
		bulb.Transparency = 0.5
		k.cylinder(0.1, 0.8, GOLD, cf * CFrame.new(0, dir * 0.7 * k.s, 0), FOIL, "HourglassCap")
	end
	k.ellipsoid(Vector3.new(0.4, 0.3, 0.4), rgb(255, 210, 120), cf * CFrame.new(0, -0.45 * k.s, 0), NEON, "Sand")
	for _, part in k.find("Hourglass") do
		k.limb(part, "Orbit", 0, 0, 0, 0)
	end
	for _, part in k.find("HourglassCap") do
		k.limb(part, "Orbit", 0, 0, 0, 0)
	end
	for _, part in k.find("Sand") do
		k.limb(part, "Orbit", 0, 0, 0, 0)
	end
end

function A.JackCrank(k: Kit)
	local center = Vector3.new(0, 0.1, 0.95)
	local arm = segment(k, center + Vector3.new(0, 0, 0.3), center + Vector3.new(0.6, 0.0, 0.3), 0.14, rgb(200, 30, 40), nil, "Crank")
	local knob = k.ball(0.3, rgb(255, 220, 40), k.at(center.X + 0.65, center.Y, center.Z + 0.45), nil, "CrankKnob")
	local shaft = segment(k, center, center + Vector3.new(0, 0, 0.32), 0.14, rgb(160, 160, 170), METAL, "Crank")
	for _, part in { arm, knob, shaft } do
		k.limb(part, "Roll", 0, center.X, center.Y, center.Z)
	end
	-- a spring popping out of the top with a little hat
	for i = 0, 3 do
		k.cylinder(0.08, 0.6, rgb(190, 190, 200), k.at(0, k.TOP + 0.15 + i * 0.22, 0), METAL, "Spring")
	end
end

function A.ToyDrum(k: Kit)
	local cf = k.at(0, -k.R - 0.15, -1.15)
	k.cylinder(0.75, 1.3, rgb(220, 40, 50), cf, nil, "Drum")
	for _, dy in { -0.38, 0.38 } do
		k.cylinder(0.1, 1.36, GOLD, cf * CFrame.new(0, dy * k.s, 0), FOIL, "DrumRim")
	end
	for _, side in { -1, 1 } do
		segment(k, Vector3.new(side * 0.25, -k.R + 0.3, -1.15), Vector3.new(side * 0.55, -k.R + 0.95, -1.3), 0.08, rgb(240, 220, 190), WOOD, "Drumstick")
	end
end

function A.Stitches(k: Kit)
	local cf = k.onGlaze(math.rad(-55), 0.1, 0.02)
	k.block(Vector3.new(0.75, 0.6, 0.05), k.Frosting:Lerp(rgb(255, 230, 150), 0.6), cf, Enum.Material.Fabric, "Patch")
	for i = 0, 3 do
		local corner = cf * CFrame.new((if i % 2 == 0 then -0.37 else 0.37) * k.s, (if i < 2 then -0.3 else 0.3) * k.s, -0.03 * k.s)
		k.block(Vector3.new(0.18, 0.04, 0.03), BLACK, corner * CFrame.Angles(0, 0, math.rad(45)), nil, "Stitch")
	end
	k.cylinder(0.08, 0.32, rgb(60, 40, 30), k.onGlaze(math.rad(-120), 0.2, 0.02) * CFrame.Angles(math.pi / 2, 0, 0), nil, "Button")
end

function A.GhostTail(k: Kit)
	local white = k.Frosting:Lerp(WHITE, 0.5)
	for i = -1, 1 do
		local wisp = k.ellipsoid(Vector3.new(1.1, 1.8 - math.abs(i) * 0.4, 0.9), white, k.at(i * 0.95, -k.TOP - 0.3 + math.abs(i) * 0.25, 0.1), nil, "GhostTail")
		wisp.Transparency = 0.25
		k.limb(wisp, "Tentacle", if i < 0 then -1 else 1, i * 0.9, -k.R, 0)
	end
end

function A.VampireCollar(k: Kit)
	for _, side in { -1, 1 } do
		k.wedge(Vector3.new(0.12, 1.5, 1.0), rgb(30, 10, 15), k.at(side * 1.15, k.TOP - 0.1, 0.55) * CFrame.Angles(0, side * 0.6, side * 0.35))
		k.wedge(Vector3.new(0.13, 1.3, 0.85), rgb(170, 20, 35), k.at(side * 1.1, k.TOP - 0.15, 0.48) * CFrame.Angles(0, side * 0.6, side * 0.35))
	end
end

function A.Ribcage(k: Kit)
	-- crossed bones on the glaze
	local bone = rgb(245, 240, 225)
	for _, tilt in { 0.6, -0.6 } do
		local cf = k.onGlaze(-math.pi / 2, 0.05, 0.08) * CFrame.Angles(0, 0, tilt)
		k.block(Vector3.new(1.3, 0.16, 0.12), bone, cf, nil, "Bone")
		for _, x in { -0.68, 0.68 } do
			for _, y in { -0.08, 0.08 } do
				k.ball(0.18, bone, cf * CFrame.new(x * k.s, y * k.s, 0), nil, "BoneEnd")
			end
		end
	end
end

function A.RainCloud(k: Kit)
	local center = Vector3.new(0, k.TOP + 1.4, 0)
	for i = -1, 1 do
		k.ball(0.8 - math.abs(i) * 0.15, rgb(235, 240, 255), k.at(center.X + i * 0.5, center.Y + (1 - math.abs(i)) * 0.15, center.Z), nil, "Cloud")
	end
	for i = -1, 1 do
		k.ellipsoid(Vector3.new(0.12, 0.28, 0.12), rgb(90, 170, 255), k.at(center.X + i * 0.45, center.Y - 0.6 - (i % 2) * 0.2, center.Z), GLASS, "Raindrop")
	end
end

function A.CloudPuffs(k: Kit)
	puffs(k, 5, WHITE, 0)
end

function A.RainbowArc(k: Kit)
	local colors = { rgb(255, 60, 60), rgb(255, 150, 40), rgb(255, 230, 60), rgb(80, 220, 100), rgb(60, 150, 255), rgb(130, 80, 255), rgb(200, 90, 255) }
	torus(k, CFrame.new(0, 0.3, 0.75), k.R + 1.3, 0.38, 7, WHITE, NEON, "Rainbow", math.rad(5), math.rad(175), colors)
	for _, side in { -1, 1 } do
		k.ball(0.75, WHITE, k.at(side * (k.R + 1.3), 0.25, 0.75), nil, "Cloud")
	end
end

-- Treasure & fire ---------------------------------------------------------------------------------

function A.TreasureCoins(k: Kit)
	for i = 0, 4 do
		local a = i / 5 * TAU
		local coin = disc(k, k.at(math.cos(a) * 2.9, 0.4 + math.sin(a * 3) * 0.5, math.sin(a) * 2.9) * CFrame.Angles(0, -a, 0), 0.08, 0.55, GOLD, FOIL, "Coin")
		k.limb(coin, "Orbit", 0, 0, 0, 0)
	end
end

function A.Gems(k: Kit)
	local colors = { rgb(255, 40, 80), rgb(60, 220, 120), rgb(70, 140, 255) }
	for i, color in colors do
		local cf = k.onGlaze(math.rad(-150 + i * 40), 0.2, 0.08) * CFrame.Angles(0, 0, math.rad(45))
		k.block(Vector3.new(0.3, 0.3, 0.2), color, cf, GLASS, "Gem").Reflectance = 0.4
	end
end

function A.LavaDrips(k: Kit)
	for i = 0, 2 do
		local angle = math.rad(-150 + i * 55)
		local radial = Vector3.new(math.cos(angle), math.sin(angle), 0)
		local p = radial * (k.R + 0.6)
		k.ellipsoid(Vector3.new(0.3, 0.9 + (i % 2) * 0.4, 0.28), rgb(255, 110, 20), k.at(p.X, p.Y - 0.25, -0.3), NEON, "LavaDrip")
		k.ball(0.18, rgb(255, 180, 60), k.at(p.X, p.Y - 0.85 - (i % 2) * 0.3, -0.3), NEON, "LavaDrop")
	end
end

function A.LavaCracks(k: Kit)
	lavaCracks(k, 5, rgb(255, 150, 30))
end

function A.LavaBubbles(k: Kit)
	for _ = 1, 4 do
		local bubble = k.ball(k.Rng:NextNumber(0.2, 0.38), rgb(255, 170, 60), k.onGlaze(glazeAngle(k), k.Rng:NextNumber(-0.6, 0.7), 0.06), GLASS, "Bubble")
		bubble.Transparency = 0.25
		bubble.Reflectance = 0.3
	end
end

function A.CharcoalChunks(k: Kit)
	for i = 1, 4 do
		local cf = k.onGlaze(glazeAngle(k), k.Rng:NextNumber(-0.6, 0.6), 0.05) * CFrame.Angles(k.Rng:NextNumber(0, 3), k.Rng:NextNumber(0, 3), 0)
		k.block(Vector3.new(0.32, 0.26, 0.3), rgb(40, 36, 36), cf, nil, "Charcoal")
		if i <= 2 then
			k.ball(0.12, rgb(255, 120, 30), cf * CFrame.new(0.12 * k.s, 0.1 * k.s, 0), NEON, "Ember")
		end
	end
end

function A.ObsidianShards(k: Kit)
	for i = 0, 3 do
		local cf = onDough(k, math.rad(-160 + i * 45), math.rad(95), 0.25) * CFrame.Angles(0, math.rad(45), k.Rng:NextNumber(-0.4, 0.4))
		local shard = k.block(Vector3.new(0.3, 0.9 - (i % 2) * 0.3, 0.3), rgb(25, 18, 38), cf, GLASS, "Obsidian")
		shard.Reflectance = 0.45
	end
end

function A.BasaltPlates(k: Kit)
	for i = 0, 2 do
		local cf = onDough(k, math.rad(-140 + i * 50), math.rad(85), 0.03)
		local plate = Instance.new("Part")
		plate.Shape = Enum.PartType.Cylinder
		plate.Size = Vector3.new(0.14, 0.75, 0.75) * k.s
		plate.Name = "Basalt"
		k.add(plate, cf * CFrame.Angles(0, 0, math.pi / 2), rgb(60, 55, 58), Enum.Material.Basalt)
	end
	lavaCracks(k, 2, rgb(255, 110, 20))
end

function A.MagmaCore(k: Kit)
	k.ball(1.0, rgb(255, 150, 40), k.at(0, 0, 0), NEON, "MagmaCore")
	k.ball(1.35, rgb(255, 90, 20), k.at(0, 0, 0), NEON, "MagmaGlow").Transparency = 0.6
end

function A.LavaWave(k: Kit)
	local center = Vector3.new(0, 0.6, 1.2)
	local pieces = torus(k, CFrame.new(center) * CFrame.Angles(0, 0, math.rad(-20)), 2.6, 0.55, 5, rgb(255, 120, 30), NEON, "LavaWave", math.rad(10), math.rad(170), { rgb(255, 90, 20), rgb(255, 150, 40), rgb(255, 210, 80) })
	for _, piece in pieces do
		k.limb(piece, "Cape", 0, 0, 0.6, 1.0)
	end
	k.ball(0.6, rgb(255, 220, 120), k.at(-2.4, 1.6, 1.2), NEON, "Foam")
end

function A.Bombs(k: Kit)
	for _, side in { -1, 1 } do
		k.ellipsoid(Vector3.new(0.45, 0.45, 0.95), rgb(50, 55, 50), k.at(side * 1.4, -0.45, 0.45), METAL, "Bomb")
		k.wedge(Vector3.new(0.08, 0.3, 0.3), rgb(200, 40, 40), k.at(side * 1.4, -0.25, 0.95))
	end
end

function A.Hook(k: Kit)
	local h = hand(k, 1)
	for _, glove in k.find("Glove") do
		if glove.Position.X > 0 then
			glove.Color = rgb(60, 45, 35)
		end
	end
	local base = h + Vector3.new(0, 0.3, 0)
	local pieces = { segment(k, h, base, 0.12, SILVER, METAL, "Hook") }
	for _, piece in torus(k, CFrame.new(base + Vector3.new(0.25, 0.2, 0)), 0.3, 0.1, 4, SILVER, METAL, "Hook", math.rad(180), math.rad(360)) do
		table.insert(pieces, piece)
	end
	if k.has("Arms") then
		for _, piece in pieces do
			k.limb(piece, "Arm", 1, k.R + 0.74, -0.25, -0.1)
		end
	end
end

function A.Snowflakes(k: Kit)
	for i = 0, 1 do
		local a = i * math.pi + 0.3
		local cf = k.at(math.cos(a) * 2.9, 1.0 - i * 1.2, math.sin(a) * 2.9)
		for j = 0, 2 do
			local arm = k.block(Vector3.new(0.06, 0.6, 0.06), WHITE, cf * CFrame.Angles(0, 0, j * math.pi / 3), NEON, "Snowflake")
			k.limb(arm, "Orbit", 0, 0, 0, 0)
		end
	end
end

function A.BananaPeel(k: Kit)
	local yellow = rgb(255, 225, 70)
	-- the donut sits in a half-peeled banana: four peel petals cupping its lower half
	for i = 0, 3 do
		local a = i / 4 * TAU + math.pi / 4
		local peel = k.ellipsoid(Vector3.new(1.3, 2.6, 0.2), yellow, k.at(math.cos(a) * 2.1, -1.1, math.sin(a) * 1.45) * CFrame.Angles(0, -a + math.pi / 2, 0) * CFrame.Angles(math.rad(-18), 0, 0), nil, "Peel")
		peel.Reflectance = 0.05
	end
	k.ellipsoid(Vector3.new(0.4, 0.45, 0.4), rgb(110, 80, 40), k.at(0, -2.35, 0.9), nil, "PeelTip")
end

function A.Cactus(k: Kit)
	local green = rgb(80, 170, 80)
	k.cylinder(1.1, 0.5, green, k.at(-0.6, k.TOP + 0.45, 0.1), nil, "Cactus")
	k.ball(0.5, green, k.at(-0.6, k.TOP + 1.0, 0.1), nil, "Cactus")
	k.cylinder(0.45, 0.28, green, k.at(-1.0, k.TOP + 0.7, 0.1), nil, "Cactus")
	k.block(Vector3.new(0.35, 0.22, 0.22), green, k.at(-0.85, k.TOP + 0.5, 0.1), nil, "Cactus")
	k.ball(0.28, rgb(255, 120, 190), k.at(-0.6, k.TOP + 1.25, 0.1), nil, "CactusFlower")
end

function A.BalletSlippers(k: Kit)
	for _, name in { "Shoe", "Sole" } do
		for _, part in k.find(name) do
			part.Color = if name == "Shoe" then rgb(255, 170, 210) else rgb(255, 210, 230)
		end
	end
	for _, side in { -1, 1 } do
		for _, tilt in { 0.5, -0.5 } do
			local ribbon = k.block(Vector3.new(0.05, 0.45, 0.05), rgb(255, 150, 200), k.at(side * 0.55, -k.TOP - 0.65, -0.19) * CFrame.Angles(0, 0, tilt), nil, "Ribbon")
			k.limb(ribbon, "Leg", side, side * 0.55, -k.TOP + 0.2, 0)
		end
	end
end

function A.Icicles(k: Kit)
	-- a fringe of icicles all along the bottom, with frost on the rim
	for i = 0, 5 do
		local angle = math.rad(-165 + i * 30)
		local radial = Vector3.new(math.cos(angle), math.sin(angle), 0)
		local p = radial * (k.R + 0.45)
		local length = 0.55 + ((i * 7) % 3) * 0.2
		local icicle = k.ellipsoid(Vector3.new(0.2, length, 0.2), rgb(200, 240, 255), k.at(p.X, p.Y - length * 0.45, -0.45), GLASS, "Icicle")
		icicle.Transparency = 0.15
		icicle.Reflectance = 0.25
	end
end

function A.CrystalCluster(k: Kit)
	local color = k.Frosting:Lerp(WHITE, 0.25)
	for i = 0, 3 do
		local angle = math.rad(25 + i * 42)
		local cf = onDough(k, angle, math.rad(100), 0.25) * CFrame.Angles(0, math.rad(45), (i - 1.5) * 0.25)
		local shard = k.block(Vector3.new(0.32, 1.0 - (i % 2) * 0.3, 0.32), color, cf, GLASS, "Crystal")
		shard.Transparency = 0.2
		shard.Reflectance = 0.35
	end
end

function A.PufferSpikes(k: Kit)
	local color = k.Frosting:Lerp(rgb(255, 230, 150), 0.4)
	for i = 0, 7 do
		local angle = (i + 0.5) / 8 * TAU
		if math.abs(angle - math.pi / 2) > 0.5 then
			local cf = onDough(k, angle, math.rad(95), 0.1)
			k.wedge(Vector3.new(0.14, 0.45, 0.35), color, cf)
		end
	end
end

function A.SoulWisps(k: Kit)
	for i = 0, 2 do
		local a = i / 3 * TAU + 0.4
		local wisp = k.ellipsoid(Vector3.new(0.45, 0.7, 0.45), rgb(110, 230, 255), k.at(math.cos(a) * 2.9, 0.8 + math.sin(a * 2) * 0.5, math.sin(a) * 2.9), NEON, "Wisp")
		wisp.Transparency = 0.3
		k.limb(wisp, "Orbit", 0, 0, 0, 0)
		local tail = k.ellipsoid(Vector3.new(0.25, 0.6, 0.25), rgb(180, 245, 255), k.at(math.cos(a) * 2.9, 0.35 + math.sin(a * 2) * 0.5, math.sin(a) * 2.9), NEON, "Wisp")
		tail.Transparency = 0.6
		k.limb(tail, "Orbit", 0, 0, 0, 0)
	end
end

---------------------------------------------------------------------------------------------------

function DonutExtras.Has(name: string): boolean
	return A[name] ~= nil
end

function DonutExtras.Build(k: Kit, name: string): boolean
	local builder = A[name]
	if not builder then
		return false
	end
	builder(k)
	return true
end

return DonutExtras
