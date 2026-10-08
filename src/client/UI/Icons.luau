--[[
	Icons: chunky cartoon icons for the HUD and windows (like the big simulator games): a soft white
	body with a thick black outline, a drop shadow, a bit of shading and a shiny highlight, drawn
	from plain Frames so there's nothing to upload (and no emoji anywhere in the game). A
	Theme.Button or a HUD square takes one by name: cart, book, paw, cycle, tools, house, building,
	globe, rocket, palette, heart, news, note, gear, eye, bolt (Speed), cash, coin, clover (luck),
	egg, gift, friends (the Friend Boost), plus, check, and the HUD's coloured ones: basket, indexBook,
	pawPink, houseRed, globeBlue, paletteWood, newsYellow, gearSteel, toolsSteel, buildingBlue.

	Each icon is a list of shapes in a 1 x 1 box (x, y = centre; w, h = size; rot = degrees;
	r = corner rounding, 0.5 = round):
	  fill "white" (default): the body. Overlapping body shapes merge into one silhouette: every
	                          shadow is drawn first, then every outline, then every fill on top.
	                          Outlines always have rounded corners, like a marker pen.
	                          `color = Color3` paints a body shape (the heart is pink)
	  back = 1 or 2:          a body shape behind the rest, with its own outline where the front
	                          pieces overlap it (the wrench under the hammer, the rocket's fins)
	  fill "ink":             black detail drawn on the body (lines, doors, pupils)
	  fill "hole":            a see-through hole, outlined (the gear's middle): it's painted with the
	                          button's own gradient, so it looks like the button shows through
	                          (`plain`: no outline; `outlineOnly`: just the outline)
	  fill <Color3>:          a coloured spot with its own outline (paint on the palette)
	  fill "shine":           a soft white highlight on top of everything
	  plain = true:           no outline or shadow (a detail laid flat on the body)
	  z = name:               an exact layer from Z (for details that stack: the rocket's window)
	  clip = {x0, y0, x1, y1}: only the part inside that box is drawn (the cycle icon's ring)
	  tri = heading:          see roundedTriangle(); keepTop = share: only the front of the shape
	Everything scales with the icon, so it looks the same on a small HUD square and a big window.
]]

local Icons = {}

export type Layout = { Size: UDim2, Position: UDim2, AnchorPoint: Vector2? }

local OUTLINE = 0.055 -- outline thickness, as a share of the icon's size
local SHADOW = Vector2.new(0.025, 0.05) -- drop shadow offset (down and a little right)
local SHADOW_DARKNESS = 0.55 -- the shadow is the button's own colour, this much darker
local BLACK = Color3.fromRGB(18, 18, 26)
local TOP = Color3.fromRGB(255, 255, 255) -- body shading: white at the top...
local BOTTOM = Color3.fromRGB(214, 222, 240) -- ...to a cool grey at the bottom
local RED = Color3.fromRGB(240, 64, 64)
local PINK = Color3.fromRGB(255, 92, 150)
local NO_BACKGROUND = Color3.fromRGB(120, 120, 130)

-- Layers, back to front. Each depth of body (0 = front, 1 and 2 = behind it) has an outline, a
-- fill and its own ink, so a piece in front gets a black edge where it overlaps one behind.
local Z = {
	Shadow = 1,
	SpotOutline = 11,
	Detail = 12, -- front ink, spots, holes
	Over = 13, -- details on details (window glass, pupils)
	Over2 = 14,
	Shine = 15,
}
local function depthLayers(depth: number): (number, number, number)
	local base = 2 + (2 - depth) * 3
	return base, base + 1, base + 2 -- outline, fill, ink
end

type Shape = { [string]: any }

local function box(x: number, y: number, w: number, h: number, extra: Shape?): Shape
	local shape: Shape = { x = x, y = y, w = w, h = h }
	if extra then
		for key, value in extra do
			shape[key] = value
		end
	end
	return shape
end

local function circle(x: number, y: number, d: number, extra: Shape?): Shape
	local shape = box(x, y, d, d, extra)
	shape.r = 0.5
	return shape
end

local function ellipse(x: number, y: number, w: number, h: number, extra: Shape?): Shape
	local shape = box(x, y, w, h, extra)
	shape.r = 0.5
	return shape
end

local function shine(x: number, y: number, w: number, h: number, rot: number?): Shape
	return ellipse(x, y, w, h, { fill = "shine", rot = rot or -25 })
end

-- A pill from (ax, ay) to (bx, by), `width` thick, with round ends centred on the two points.
local function capsule(ax: number, ay: number, bx: number, by: number, width: number, extra: Shape?): Shape
	local dx, dy = bx - ax, by - ay
	local shape = box((ax + bx) / 2, (ay + by) / 2, width, math.sqrt(dx * dx + dy * dy) + width, extra)
	shape.rot = math.deg(math.atan2(dy, dx)) - 90
	shape.r = 0.5
	return shape
end

-- A right-angled arrowhead with rounded corners. Its back edge runs from (ax, ay) to (bx, by) and it
-- points out at right angles (to the right when that edge goes straight up). The edges are pills,
-- so the outline is round at every corner; the middle is the front half of a square on its corner.
local function roundedTriangle(ax: number, ay: number, bx: number, by: number, round: number): { Shape }
	local mx, my = (ax + bx) / 2, (ay + by) / 2
	local half = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2) / 2
	-- the tip: half the back edge's length out from its middle, at right angles
	local nx, ny = (ay - by) / (2 * half), (bx - ax) / (2 * half)
	local tx, ty = mx + nx * half, my + ny * half
	local heading = math.deg(math.atan2(ny, nx))
	return {
		capsule(ax, ay, bx, by, round * 2),
		capsule(bx, by, tx, ty, round * 2),
		capsule(tx, ty, ax, ay, round * 2),
		box(mx, my, half * math.sqrt(2), half * math.sqrt(2), { rot = heading - 45, tri = heading, plain = true }),
	}
end

local SHAPES: { [string]: { Shape } } = {}

-- A shopping cart: a grip, a handle running down into the base bar, a basket whose left side
-- follows the handle (a slanted piece clipped to the basket's height), slots and two wheels
SHAPES.cart = {
	box(0.155, 0.19, 0.25, 0.085, { r = 0.5 }),
	box(0.28, 0.424, 0.075, 0.491, { rot = -16, r = 0.5 }),
	box(0.336, 0.4035, 0.12, 0.5, { rot = -16, clip = { -1, 0.265, 2, 0.575 } }),
	box(0.605, 0.42, 0.55, 0.31, { r = 0.12 }),
	box(0.57, 0.665, 0.54, 0.085, { r = 0.5 }),
	circle(0.36, 0.83, 0.19),
	circle(0.74, 0.83, 0.19),
	box(0.45, 0.43, 0.06, 0.16, { fill = "ink", r = 0.5 }),
	box(0.58, 0.43, 0.06, 0.16, { fill = "ink", r = 0.5 }),
	box(0.71, 0.43, 0.06, 0.16, { fill = "ink", r = 0.5 }),
	circle(0.36, 0.83, 0.065, { fill = "ink" }),
	circle(0.74, 0.83, 0.065, { fill = "ink" }),
	shine(0.42, 0.32, 0.12, 0.04, 0),
}

-- A closed book: the cover in front of the pages, a spine, a title and a red bookmark
SHAPES.book = {
	box(0.56, 0.55, 0.58, 0.72, { rot = -14, r = 0.1, back = 1 }),
	box(0.617, 0.859, 0.48, 0.03, { rot = -14, fill = "ink", back = 1 }),
	box(0.5, 0.47, 0.58, 0.72, { rot = -14, r = 0.12 }),
	box(0.325, 0.514, 0.05, 0.72, { rot = -14, fill = "ink" }),
	box(0.53, 0.37, 0.28, 0.09, { rot = -14, fill = "ink", r = 0.3 }),
	box(0.694, 0.834, 0.085, 0.17, { rot = -14, r = 0.15, fill = RED }),
	shine(0.42, 0.21, 0.13, 0.04, -14),
}

SHAPES.paw = {
	ellipse(0.5, 0.67, 0.46, 0.36),
	ellipse(0.19, 0.42, 0.18, 0.23, { rot = -20 }),
	ellipse(0.38, 0.23, 0.18, 0.23, { rot = -8 }),
	ellipse(0.62, 0.23, 0.18, 0.23, { rot = 8 }),
	ellipse(0.81, 0.42, 0.18, 0.23, { rot = 20 }),
	shine(0.41, 0.6, 0.13, 0.06),
}

-- A circular arrow (↻): one smooth white ring with the top-right quarter missing (the ring is drawn
-- twice, clipped to its left half and its bottom half), a round end at 3 o'clock and an arrowhead
-- at 12 o'clock pointing into the gap. The button shows through the middle.
SHAPES.cycle = (function(): { Shape }
	local cx, cy = 0.5, 0.54
	local outer, hole = 0.33, 0.11
	local inner = hole + OUTLINE -- where the white starts (the hole's outline is inside it)
	local keepLeft = { -1, -1, cx, 2 }
	local keepBottom = { -1, cy, 2, 2 }
	local list = {}
	for _, clip in { keepLeft, keepBottom } do
		table.insert(list, circle(cx, cy, outer * 2, { clip = clip }))
	end
	table.insert(list, circle(cx + (outer + inner) / 2, cy, outer - inner))
	-- The arrowhead's inner corner dips just into the hole's outline, so it covers the ring's end
	-- completely (and the outline there tucks it in)
	local round = 0.035
	for _, shape in roundedTriangle(cx, cy - inner + 0.006, cx, cy - outer - 0.14 + round, round) do
		table.insert(list, shape)
	end
	table.insert(list, circle(cx, cy, hole * 2, { fill = "hole", plain = true }))
	for _, clip in { keepLeft, keepBottom } do
		-- the hole's outline only goes round where the ring is (plus the ends' outline)
		table.insert(list, circle(cx, cy, hole * 2, { fill = "hole", clip = clip, clipPad = OUTLINE, outlineOnly = true }))
	end
	table.insert(list, shine(cx - 0.25, cy - 0.02, 0.055, 0.13, 15))
	return list
end)()

-- A wrench under a hammer
SHAPES.tools = {
	box(0.45, 0.55, 0.13, 0.62, { rot = 45, r = 0.45, back = 1 }),
	circle(0.69, 0.31, 0.34, { back = 1 }),
	box(0.75, 0.25, 0.1, 0.2, { rot = 45, fill = "ink", r = 0.3, back = 1 }),
	box(0.56, 0.56, 0.11, 0.62, { rot = -45, r = 0.45 }),
	box(0.34, 0.34, 0.44, 0.18, { rot = -45, r = 0.15 }),
	box(0.39, 0.39, 0.06, 0.18, { rot = -45, fill = "ink" }),
	box(0.66, 0.66, 0.035, 0.12, { rot = 45, fill = "ink" }),
	box(0.71, 0.71, 0.035, 0.12, { rot = 45, fill = "ink" }),
	shine(0.27, 0.32, 0.1, 0.035, -45),
}

-- A house with a chimney, a door with a knob and a window
SHAPES.house = {
	box(0.72, 0.27, 0.1, 0.2, { r = 0.1, back = 1 }),
	box(0.5, 0.42, 0.5, 0.5, { rot = 45, r = 0.06 }),
	box(0.5, 0.65, 0.56, 0.42, { r = 0.05 }),
	-- (the roof line ends inside the eaves' outline)
	box(0.5, 0.45, 0.66, 0.035, { fill = "ink" }),
	box(0.61, 0.765, 0.15, 0.23, { fill = "ink", r = 0.2 }),
	circle(0.65, 0.77, 0.04, { fill = "shine" }),
	box(0.36, 0.63, 0.15, 0.15, { fill = "ink", r = 0.15 }),
	box(0.36, 0.63, 0.025, 0.15, { fill = "white", plain = true, z = "Over" }),
	box(0.36, 0.63, 0.15, 0.025, { fill = "white", plain = true, z = "Over" }),
	shine(0.39, 0.3, 0.12, 0.04, -45),
}

-- A tall building with an antenna, rows of windows (two of them lit) and a door
SHAPES.building = {
	box(0.5, 0.07, 0.035, 0.09, { fill = "ink" }),
	circle(0.5, 0.035, 0.06, { fill = Color3.fromRGB(255, 80, 80) }),
	box(0.5, 0.15, 0.3, 0.08, { r = 0.25 }),
	box(0.5, 0.55, 0.52, 0.74, { r = 0.06 }),
	box(0.39, 0.3, 0.12, 0.08, { fill = "ink", r = 0.2 }),
	box(0.61, 0.3, 0.12, 0.08, { fill = Color3.fromRGB(255, 215, 70), r = 0.2, plain = true }),
	box(0.39, 0.43, 0.12, 0.08, { fill = "ink", r = 0.2 }),
	box(0.61, 0.43, 0.12, 0.08, { fill = "ink", r = 0.2 }),
	box(0.39, 0.56, 0.12, 0.08, { fill = Color3.fromRGB(255, 215, 70), r = 0.2, plain = true }),
	box(0.61, 0.56, 0.12, 0.08, { fill = "ink", r = 0.2 }),
	box(0.39, 0.69, 0.12, 0.08, { fill = "ink", r = 0.2 }),
	box(0.61, 0.69, 0.12, 0.08, { fill = "ink", r = 0.2 }),
	box(0.5, 0.85, 0.14, 0.14, { fill = "ink", r = 0.2 }),
	shine(0.31, 0.24, 0.035, 0.1, 0),
}

-- A globe with a meridian and lines of latitude (every line reaches the outline)
SHAPES.globe = {
	circle(0.5, 0.5, 0.8),
	ellipse(0.5, 0.5, 0.4, 0.8, { fill = "ink" }),
	ellipse(0.5, 0.5, 0.3, 0.72, { fill = "white", plain = true, z = "Over" }),
	box(0.5, 0.5, 0.82, 0.04, { fill = "ink", z = "Over2" }),
	box(0.5, 0.3, 0.72, 0.035, { fill = "ink", z = "Over2" }),
	box(0.5, 0.7, 0.72, 0.035, { fill = "ink", z = "Over2" }),
	shine(0.21, 0.4, 0.045, 0.1, 20),
}

-- A rocket flying up and to the right: a red nose cone and fins, a porthole and a flame
SHAPES.rocket = (function(): { Shape }
	local cx, cy = 0.55, 0.45
	-- a point `along` the rocket (towards the nose) and `side`ways from its middle
	local function at(along: number, side: number): (number, number)
		return cx + along * 0.7071 + side * 0.7071, cy - along * 0.7071 + side * 0.7071
	end
	local list = {}
	local function add(along: number, side: number, make: (number, number) -> Shape)
		local x, y = at(along, side)
		table.insert(list, make(x, y))
	end
	add(-0.42, 0, function(x, y)
		return ellipse(x, y, 0.2, 0.34, { rot = 45, color = Color3.fromRGB(255, 140, 30), back = 2 })
	end)
	add(-0.44, 0, function(x, y)
		return ellipse(x, y, 0.09, 0.18, { rot = 45, color = Color3.fromRGB(255, 230, 90), plain = true, back = 2 })
	end)
	for _, side in { -0.14, 0.14 } do
		add(-0.2, side, function(x, y)
			return box(x, y, 0.2, 0.2, { rot = 45, r = 0.18, color = RED, back = 1 })
		end)
	end
	local length, nose = 0.68, 0.3 -- the nose is the front 30% of the body
	add(0, 0, function(x, y)
		return box(x, y, 0.3, length, { rot = 45, r = 0.5 })
	end)
	add(0, 0, function(x, y)
		return box(x, y, 0.3, length, { rot = 45, r = 0.5, fill = RED, plain = true, keepTop = nose, z = 10 })
	end)
	add(length / 2 - length * nose, 0, function(x, y)
		return box(x, y, 0.3, 0.035, { rot = 45, fill = "ink" })
	end)
	add(-0.05, 0, function(x, y)
		return circle(x, y, 0.19, { fill = "ink" })
	end)
	add(-0.05, 0, function(x, y)
		return circle(x, y, 0.12, { fill = Color3.fromRGB(110, 200, 255), plain = true, z = "Over" })
	end)
	add(-0.02, -0.03, function(x, y)
		return circle(x, y, 0.04, { fill = "shine" })
	end)
	add(-0.17, -0.09, function(x, y)
		return shine(x, y, 0.035, 0.1, 45)
	end)
	return list
end)()

-- A painter's palette with a thumb hole and four blobs of paint
SHAPES.palette = {
	ellipse(0.5, 0.52, 0.88, 0.7, { rot = -10 }),
	circle(0.68, 0.68, 0.15, { fill = "hole" }),
	circle(0.28, 0.48, 0.15, { fill = RED }),
	circle(0.44, 0.3, 0.15, { fill = Color3.fromRGB(255, 215, 50) }),
	circle(0.66, 0.32, 0.15, { fill = Color3.fromRGB(70, 160, 255) }),
	circle(0.37, 0.69, 0.15, { fill = Color3.fromRGB(80, 210, 90) }),
	shine(0.25, 0.43, 0.05, 0.03, -30),
	shine(0.41, 0.25, 0.05, 0.03, -30),
	shine(0.63, 0.27, 0.05, 0.03, -30),
	shine(0.34, 0.64, 0.05, 0.03, -30),
}

-- A heart: a square on its corner with a circle on each of its top edges, so the sides join
-- smoothly with no dents
SHAPES.heart = (function(): { Shape }
	local side, cy = 0.46, 0.535
	local lobe = side / (2 * math.sqrt(2)) -- from the square's middle to the middle of a top edge
	return {
		-- (the circles are a hair bigger, so the square's side corners always sit just inside them)
		circle(0.5 - lobe, cy - lobe, side + 0.012, { color = PINK }),
		circle(0.5 + lobe, cy - lobe, side + 0.012, { color = PINK }),
		-- (only a little rounding: more would dent the sides where they meet the circles)
		box(0.5, cy, side, side, { rot = 45, r = 0.03, color = PINK }),
		shine(0.28, 0.33, 0.14, 0.08, -40),
		circle(0.4, 0.26, 0.045, { fill = "shine" }),
	}
end)()

-- A newspaper: a headline, a picture and lines of text
SHAPES.news = {
	box(0.5, 0.5, 0.7, 0.8, { r = 0.08 }),
	box(0.5, 0.23, 0.52, 0.09, { fill = "ink", r = 0.2 }),
	box(0.34, 0.47, 0.2, 0.2, { fill = "ink", r = 0.1 }),
	box(0.6, 0.4, 0.24, 0.035, { fill = "ink", r = 0.5 }),
	box(0.6, 0.48, 0.24, 0.035, { fill = "ink", r = 0.5 }),
	box(0.6, 0.56, 0.24, 0.035, { fill = "ink", r = 0.5 }),
	box(0.5, 0.67, 0.52, 0.035, { fill = "ink", r = 0.5 }),
	box(0.45, 0.76, 0.42, 0.035, { fill = "ink", r = 0.5 }),
}

-- Two quavers joined by a beam (). The beam's corners land exactly on the stems' outer edges, so
-- the outline runs straight from one to the other.
SHAPES.note = {
	ellipse(0.3, 0.75, 0.28, 0.21, { rot = -20 }),
	ellipse(0.72, 0.67, 0.28, 0.21, { rot = -20 }),
	box(0.42, 0.45, 0.075, 0.6),
	box(0.84, 0.425, 0.075, 0.49),
	box(0.63, 0.17, 0.47, 0.13, { rot = -11 }),
	shine(0.27, 0.72, 0.08, 0.035, -20),
}

-- A cog with eight teeth
SHAPES.gear = (function(): { Shape }
	local list = {}
	for i = 0, 3 do
		table.insert(list, box(0.5, 0.5, 0.18, 0.9, { rot = i * 45, r = 0.18 }))
	end
	table.insert(list, circle(0.5, 0.5, 0.66))
	table.insert(list, circle(0.5, 0.5, 0.22, { fill = "hole" }))
	table.insert(list, shine(0.32, 0.33, 0.1, 0.04, -40))
	return list
end)()

-- An open eye with a blue iris
SHAPES.eye = {
	ellipse(0.5, 0.5, 0.9, 0.56),
	circle(0.5, 0.5, 0.36, { fill = Color3.fromRGB(90, 170, 255) }),
	circle(0.5, 0.5, 0.18, { fill = "ink", z = "Over" }),
	circle(0.44, 0.44, 0.07, { fill = "shine" }),
}

-- A lightning bolt (Speed)
local YELLOW = Color3.fromRGB(255, 214, 60)
SHAPES.bolt = {
	box(0.6, 0.27, 0.2, 0.44, { rot = 24, r = 0.12, color = YELLOW }),
	box(0.5, 0.5, 0.5, 0.15, { rot = -22, r = 0.2, color = YELLOW }),
	box(0.4, 0.73, 0.2, 0.44, { rot = 24, r = 0.12, color = YELLOW }),
	shine(0.57, 0.2, 0.05, 0.14, 24),
}

-- A banknote on top of another (money)
local GREEN = Color3.fromRGB(110, 225, 90)
SHAPES.cash = {
	box(0.56, 0.42, 0.78, 0.46, { rot = -8, r = 0.12, back = 1, color = GREEN }),
	box(0.47, 0.58, 0.78, 0.46, { rot = -8, r = 0.12, color = GREEN }),
	circle(0.47, 0.58, 0.22, { fill = Color3.fromRGB(60, 160, 60) }),
	box(0.21, 0.62, 0.06, 0.06, { rot = -8, fill = "ink", r = 0.5 }),
	box(0.73, 0.54, 0.06, 0.06, { rot = -8, fill = "ink", r = 0.5 }),
	shine(0.3, 0.45, 0.14, 0.04, -8),
}

-- A gold coin
SHAPES.coin = {
	circle(0.5, 0.5, 0.78, { color = Color3.fromRGB(255, 200, 50) }),
	circle(0.5, 0.5, 0.46, { fill = Color3.fromRGB(240, 165, 30) }),
	box(0.5, 0.5, 0.08, 0.26, { fill = "ink", r = 0.5 }),
	shine(0.34, 0.3, 0.14, 0.05, -40),
}

-- A four-leaf clover (luck)
SHAPES.clover = {
	capsule(0.52, 0.55, 0.66, 0.9, 0.09, { color = GREEN }),
	circle(0.36, 0.36, 0.34, { color = GREEN }),
	circle(0.64, 0.36, 0.34, { color = GREEN }),
	circle(0.36, 0.62, 0.34, { color = GREEN }),
	circle(0.64, 0.62, 0.34, { color = GREEN }),
	shine(0.3, 0.3, 0.1, 0.05, -40),
}

-- A speckled egg
SHAPES.egg = {
	ellipse(0.5, 0.53, 0.6, 0.78, { color = Color3.fromRGB(255, 240, 205) }),
	circle(0.4, 0.45, 0.09, { fill = Color3.fromRGB(255, 170, 80), plain = true }),
	circle(0.6, 0.62, 0.12, { fill = Color3.fromRGB(255, 170, 80), plain = true }),
	circle(0.45, 0.74, 0.07, { fill = Color3.fromRGB(255, 170, 80), plain = true }),
	shine(0.38, 0.3, 0.06, 0.14, -20),
}

-- A present with a ribbon and a bow
SHAPES.gift = {
	box(0.5, 0.64, 0.66, 0.5, { r = 0.08, color = Color3.fromRGB(240, 70, 90) }),
	box(0.5, 0.38, 0.76, 0.18, { r = 0.1, color = Color3.fromRGB(240, 70, 90) }),
	box(0.5, 0.56, 0.14, 0.7, { fill = YELLOW }),
	ellipse(0.4, 0.22, 0.2, 0.14, { rot = 25, fill = YELLOW }),
	ellipse(0.6, 0.22, 0.2, 0.14, { rot = -25, fill = YELLOW }),
	shine(0.27, 0.34, 0.1, 0.04, 0),
}

-- A copy of an icon with its white body painted `color` (spots, ink and holes stay as they are)
local function tinted(shapes: { Shape }, color: Color3): { Shape }
	local copy = {}
	for i, shape in shapes do
		local c = table.clone(shape)
		if (c.fill == nil or c.fill == "white") and c.color == nil then
			c.color = color
		end
		copy[i] = c
	end
	return copy
end

-- The HUD's big icons (like the simulator games): a red shopping basket (Shop), a blue book with a
-- star on the cover (Index), a pink paw (Pets)
local BASKET_RED = Color3.fromRGB(240, 60, 60)
SHAPES.basket = {
	-- the handle arching over it (behind the rim)
	capsule(0.3, 0.45, 0.34, 0.2, 0.09, { color = BASKET_RED, back = 1 }),
	capsule(0.34, 0.2, 0.66, 0.2, 0.09, { color = BASKET_RED, back = 1 }),
	capsule(0.66, 0.2, 0.7, 0.45, 0.09, { color = BASKET_RED, back = 1 }),
	box(0.5, 0.7, 0.7, 0.4, { r = 0.14, color = BASKET_RED }),
	box(0.5, 0.48, 0.86, 0.14, { r = 0.4, color = BASKET_RED }),
	box(0.36, 0.71, 0.07, 0.22, { r = 0.5, fill = Color3.fromRGB(150, 20, 30), plain = true }),
	box(0.5, 0.71, 0.07, 0.22, { r = 0.5, fill = Color3.fromRGB(150, 20, 30), plain = true }),
	box(0.64, 0.71, 0.07, 0.22, { r = 0.5, fill = Color3.fromRGB(150, 20, 30), plain = true }),
	shine(0.3, 0.46, 0.14, 0.04, 0),
}
local BOOK_BLUE = Color3.fromRGB(70, 150, 255)
SHAPES.indexBook = {
	box(0.56, 0.55, 0.58, 0.72, { rot = -14, r = 0.1, back = 1 }), -- (the pages, behind the cover)
	box(0.617, 0.859, 0.48, 0.03, { rot = -14, fill = "ink", back = 1 }),
	box(0.5, 0.47, 0.58, 0.72, { rot = -14, r = 0.12, color = BOOK_BLUE }),
	box(0.325, 0.514, 0.05, 0.72, { rot = -14, fill = "ink" }),
	box(0.53, 0.43, 0.2, 0.2, { rot = 31, r = 0.18, fill = Color3.fromRGB(255, 255, 255) }), -- a star-ish emblem
	box(0.53, 0.43, 0.2, 0.2, { rot = -14, r = 0.18, fill = Color3.fromRGB(255, 255, 255), z = "Over" }),
	box(0.694, 0.834, 0.085, 0.17, { rot = -14, r = 0.15, fill = RED }),
	shine(0.42, 0.21, 0.13, 0.04, -14),
}
SHAPES.pawPink = tinted(SHAPES.paw, Color3.fromRGB(255, 150, 205))

-- ...and the right-hand ones: a house with a red roof (Home), a blue globe (Teleport), a wooden
-- palette (Skins), a yellow newspaper (Updates), a steel gear (Settings), steel tools (Admin), a blue
-- building (Base). (The rocket, heart and eye already have their colours.)
SHAPES.houseRed = (function(): { Shape }
	local copy = tinted(SHAPES.house, Color3.fromRGB(255, 240, 214))
	copy[1].color = Color3.fromRGB(190, 80, 70) -- chimney
	copy[2].color = Color3.fromRGB(240, 82, 70) -- roof
	return copy
end)()
SHAPES.globeBlue = (function(): { Shape }
	local copy = tinted(SHAPES.globe, Color3.fromRGB(80, 165, 255))
	copy[3].fill = Color3.fromRGB(140, 205, 255) -- (the band down its middle)
	return copy
end)()
SHAPES.paletteWood = tinted(SHAPES.palette, Color3.fromRGB(240, 195, 135))
SHAPES.newsYellow = tinted(SHAPES.news, Color3.fromRGB(255, 238, 160))
SHAPES.gearSteel = tinted(SHAPES.gear, Color3.fromRGB(185, 195, 212))
SHAPES.toolsSteel = tinted(SHAPES.tools, Color3.fromRGB(190, 200, 216))
SHAPES.buildingBlue = tinted(SHAPES.building, Color3.fromRGB(120, 180, 255))

-- A green tick (a Daily Reward you've claimed)
SHAPES.check = {
	capsule(0.2, 0.52, 0.42, 0.74, 0.17, { color = Color3.fromRGB(110, 225, 90) }),
	capsule(0.42, 0.74, 0.82, 0.28, 0.17, { color = Color3.fromRGB(110, 225, 90) }),
	shine(0.66, 0.4, 0.04, 0.12, 40),
}

-- A chunky plus (the "get more money" button next to your money)
SHAPES.plus = {
	box(0.5, 0.5, 0.24, 0.76, { r = 0.5 }),
	box(0.5, 0.5, 0.76, 0.24, { r = 0.5 }),
	shine(0.42, 0.24, 0.05, 0.1, 0),
}

-- Two round smiling faces, one peeking out from behind the other (the Friend Boost). The back
-- face's eyes, mouth and cheeks sit on its own layer, so the front face covers them where it
-- overlaps; the mouths are open half-moons (an ellipse with its top half cut off).
local FACE = Color3.fromRGB(255, 168, 52)
local CHEEK = Color3.fromRGB(255, 120, 120)
SHAPES.friends = (function(): { Shape }
	local _, _, backInk = depthLayers(1)
	local function face(x: number, y: number, d: number, back: boolean): { Shape }
		local s = d / 0.54 -- (the front face is 0.54 across: everything else is in step with it)
		local depth = if back then 1 else nil
		local detail = if back then backInk else nil
		local mouthY = y + 0.09 * s
		return {
			circle(x, y, d, { color = FACE, back = depth }),
			ellipse(x - 0.075 * s, y - 0.05 * s, 0.065 * s, 0.1 * s, { fill = "ink", back = depth }),
			ellipse(x + 0.075 * s, y - 0.05 * s, 0.065 * s, 0.1 * s, { fill = "ink", back = depth }),
			ellipse(x, mouthY, 0.17 * s, 0.13 * s, { fill = "ink", back = depth, clip = { x - 0.1 * s, mouthY, x + 0.1 * s, mouthY + 0.08 * s } }),
			ellipse(x - 0.16 * s, y + 0.06 * s, 0.08 * s, 0.05 * s, { fill = CHEEK, plain = true, z = detail }),
			ellipse(x + 0.16 * s, y + 0.06 * s, 0.08 * s, 0.05 * s, { fill = CHEEK, plain = true, z = detail }),
		}
	end
	local list: { Shape } = {}
	for _, shape in face(0.66, 0.34, 0.5, true) do
		table.insert(list, shape)
	end
	for _, shape in face(0.38, 0.6, 0.54, false) do
		table.insert(list, shape)
	end
	table.insert(list, shine(0.25, 0.45, 0.1, 0.05, -40))
	table.insert(list, shine(0.55, 0.18, 0.08, 0.04, -40))
	return list
end)()

-- The icon's name, if there's a drawn icon for it.
function Icons.For(name: string): string?
	return if SHAPES[name] then name else nil
end

-- A see-through step: opaque before `at` (0-1 along the gradient), invisible after it.
local function cut(f: Frame, rotation: number, at: number)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(at, 0),
		NumberSequenceKeypoint.new(math.min(1, at + 0.005), 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = f
end

-- One shape as a Frame, `grow` (a share of the icon) bigger on every side, moved by `offset`.
local function frame(parent: Instance, shape: Shape, color: Color3, grow: number, z: number, offset: Vector2?): Frame
	local f = Instance.new("Frame")
	f.Name = "Shape"
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	local move = offset or Vector2.zero
	local x, y = shape.x + move.X, shape.y + move.Y
	local w, h = shape.w + grow * 2, shape.h + grow * 2
	f.Rotation = shape.rot or 0
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = z
	local r = shape.r or 0
	if r > 0 or grow > 0 then
		-- A corner's scale is a share of the shorter side. Grown copies (outlines, shadows) keep
		-- the same curve, and get one even on square corners, so outlines never have sharp corners.
		local short = math.min(shape.w, shape.h)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(if r >= 0.5 then 0.5 else (r * short + grow) / math.min(w, h), 0)
		corner.Parent = f
	end
	if shape.tri then
		-- only the front half of the square: a triangle
		cut(f, 225, 0.5)
	elseif shape.keepTop then
		cut(f, 90, shape.keepTop)
	end
	local clip = shape.clip
	if clip then
		-- drawn inside a box that cuts off the rest (grown copies get a grown box)
		local pad = if offset then shape.clipPad or 0 else math.max(grow, shape.clipPad or 0)
		local x0, y0 = clip[1] - pad + move.X, clip[2] - pad + move.Y
		local x1, y1 = clip[3] + pad + move.X, clip[4] + pad + move.Y
		local holder = Instance.new("Frame")
		holder.Name = "Clip"
		holder.BackgroundTransparency = 1
		holder.ClipsDescendants = true
		holder.Position = UDim2.fromScale(x0, y0)
		holder.Size = UDim2.fromScale(x1 - x0, y1 - y0)
		holder.ZIndex = z
		holder.Parent = parent
		f.Position = UDim2.fromScale((x - x0) / (x1 - x0), (y - y0) / (y1 - y0))
		f.Size = UDim2.fromScale(w / (x1 - x0), h / (y1 - y0))
		f.Parent = holder
	else
		f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.fromScale(w, h)
		f.Parent = parent
	end
	return f
end

-- How far a shape (grown by `grow`) reaches above and below its centre.
local function halfHeight(shape: Shape, grow: number): number
	local rot = math.rad(shape.rot or 0)
	return (math.abs((shape.w + grow * 2) * math.sin(rot)) + math.abs((shape.h + grow * 2) * math.cos(rot))) / 2
end

-- Paint a frame top-to-bottom with colours picked by `at(y)` (y from the top of the icon), so the
-- shading runs across every shape as one.
local function verticalGradient(f: Frame, shape: Shape, top: number, bottom: number, at: (number) -> Color3)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	local gradient = f:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
	gradient.Rotation = 90 - (shape.rot or 0)
	gradient.Color = ColorSequence.new(at(top), at(bottom))
	gradient.Parent = f
end

-- White to grey from the top of the icon to the bottom (`base` tints it for coloured body shapes).
local function shade(f: Frame, shape: Shape, base: Color3?)
	local function at(y: number): Color3
		local c = TOP:Lerp(BOTTOM, math.clamp(y, 0, 1))
		return if base then Color3.new(c.R * base.R, c.G * base.G, c.B * base.B) else c
	end
	if shape.tri or shape.keepTop then
		-- (these already use their gradient for the cut: one flat colour from their middle)
		f.BackgroundColor3 = at(shape.y)
		return
	end
	local half = halfHeight(shape, 0)
	verticalGradient(f, shape, shape.y - half, shape.y + half, at)
end

local function sample(sequence: ColorSequence, t: number): Color3
	local points = sequence.Keypoints
	t = math.clamp(t, 0, 1)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		if t <= b.Time then
			local span = b.Time - a.Time
			return a.Value:Lerp(b.Value, if span > 0 then (t - a.Time) / span else 0)
		end
	end
	return points[#points].Value
end

-- Draw an icon into a new square Frame (named "Icon") inside `parent`, placed by `layout` (or
-- position and size the returned frame yourself, like an image). `background` is the button's
-- colour. When the parent is a Theme.Button and `layout` is given, holes and shadows follow the
-- button's own top-to-bottom gradient, so holes really look see-through.
function Icons.Draw(name: string, parent: Instance, background: Color3?, layout: Layout?): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Icon"
	holder.BackgroundTransparency = 1
	holder.SizeConstraint = Enum.SizeConstraint.RelativeYY
	holder.ZIndex = 2
	-- where the icon sits on the button, in shares of the button's height (for see-through colours)
	local placeTop: number?, placeHeight: number? = nil, nil
	if layout then
		holder.Size = layout.Size
		holder.Position = layout.Position
		holder.AnchorPoint = layout.AnchorPoint or Vector2.zero
		if layout.Size.Y.Offset == 0 and layout.Position.Y.Offset == 0 then
			placeHeight = layout.Size.Y.Scale
			placeTop = layout.Position.Y.Scale - holder.AnchorPoint.Y * layout.Size.Y.Scale
		end
	end
	local back = background or NO_BACKGROUND
	local buttonGradient = parent:FindFirstChildOfClass("UIGradient")

	-- Frames painted with what's behind the icon (holes) or a darker copy of it (shadows)
	local painted: { { frame: Frame, shape: Shape, top: number, bottom: number, dark: number } } = {}
	local function seeThrough(f: Frame, shape: Shape, grow: number, move: Vector2?, dark: number)
		local half = halfHeight(shape, grow)
		local y = shape.y + (if move then move.Y else 0)
		table.insert(painted, { frame = f, shape = shape, top = y - half, bottom = y + half, dark = dark })
	end
	local function repaint()
		for _, entry in painted do
			if buttonGradient and placeTop and placeHeight and parent:IsA("GuiObject") then
				local tint = (parent :: GuiObject).BackgroundColor3
				local sequence = buttonGradient.Color
				local top, height = placeTop, placeHeight
				verticalGradient(entry.frame, entry.shape, entry.top, entry.bottom, function(y: number): Color3
					local c = sample(sequence, top + y * height)
					return Color3.new(c.R * tint.R, c.G * tint.G, c.B * tint.B):Lerp(BLACK, entry.dark)
				end)
			else
				entry.frame.BackgroundColor3 = back:Lerp(BLACK, entry.dark)
			end
		end
	end

	local shapes: { Shape } = SHAPES[name] or {}
	-- shadows and outlines first...
	for _, shape in shapes do
		local fill = shape.fill or "white"
		if shape.plain or fill == "ink" or fill == "shine" then
			continue
		end
		if fill == "white" then
			local outlineZ = depthLayers(shape.back or 0)
			seeThrough(frame(holder, shape, back, OUTLINE, Z.Shadow, SHADOW), shape, OUTLINE, SHADOW, SHADOW_DARKNESS)
			frame(holder, shape, BLACK, OUTLINE, outlineZ)
		elseif fill == "hole" then
			frame(holder, shape, BLACK, OUTLINE, Z.SpotOutline)
		else
			-- a coloured spot: its own (slightly thinner) outline
			local spot = OUTLINE * 0.75
			seeThrough(frame(holder, shape, back, spot, Z.Shadow, SHADOW), shape, spot, SHADOW, SHADOW_DARKNESS)
			frame(holder, shape, BLACK, spot, Z.SpotOutline)
		end
	end
	-- ...then every fill on top
	for _, shape in shapes do
		local fill = shape.fill or "white"
		local _, fillZ, inkZ = depthLayers(shape.back or 0)
		local z = if typeof(shape.z) == "string" then Z[shape.z] else shape.z
		if fill == "white" then
			shade(frame(holder, shape, TOP, 0, z or fillZ), shape, shape.color)
		elseif fill == "ink" then
			frame(holder, shape, BLACK, 0, z or (if shape.back then inkZ else Z.Detail))
		elseif fill == "shine" then
			local f = frame(holder, shape, TOP, 0, Z.Shine)
			f.BackgroundTransparency = 0.2
		elseif fill == "hole" then
			if not shape.outlineOnly then
				seeThrough(frame(holder, shape, back, 0, z or Z.Detail), shape, 0, nil, 0)
			end
		elseif typeof(fill) == "Color3" then
			frame(holder, shape, fill, 0, z or Z.Detail)
		end
	end
	repaint()
	if buttonGradient then
		-- the button changed colour (Theme.SetButtonColor): repaint the holes and shadows
		buttonGradient:GetPropertyChangedSignal("Color"):Connect(repaint)
	end
	holder.Parent = parent
	return holder
end

return Icons
