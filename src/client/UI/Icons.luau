--[[
	Icons: chunky cartoon icons for the HUD and windows (like the big simulator games): a soft white
	body with a thick black outline, a drop shadow, a bit of shading and a shiny highlight, drawn
	from plain Frames so there's nothing to upload. They replace these emojis wherever a
	Theme.Button or a HUD square uses one: 🛒 📖 🐾 🔄 🛠 🏠 🌀 🚀 🎨 💖 📰 🎵 ⚙️ 👁

	Each icon is a list of shapes in a 1 x 1 box (x, y = centre; w, h = size; rot = degrees;
	r = corner rounding, 0.5 = round):
	  fill "white" (default): the body. Overlapping body shapes merge into one silhouette: every
	                          shadow is drawn first, then every outline, then every fill on top.
	                          `color = Color3` paints a body shape (the heart is pink)
	  fill "ink":             black detail drawn on the body (lines, doors, pupils)
	  fill "hole":            a darker shade of the button, outlined (a cut-out: the gear's middle)
	  fill <Color3>:          a coloured spot with its own outline (paint on the palette)
	  fill "shine":           a soft white highlight on top of everything
	  plain = true:           no outline or shadow (a detail laid flat on the body)
	  z = n:                  an exact layer, for details that stack (the rocket's window)
	  tri = heading:          see triangle() (the cycle icon's arrowhead)
	Everything scales with the icon, so it looks the same on a small HUD square and a big window.
]]

local Icons = {}

local OUTLINE = 0.055 -- outline thickness, as a share of the icon's size
local SHADOW = Vector2.new(0.025, 0.05) -- drop shadow offset (down and a little right)
local BLACK = Color3.fromRGB(18, 18, 26)
local TOP = Color3.fromRGB(255, 255, 255) -- body shading: white at the top...
local BOTTOM = Color3.fromRGB(214, 222, 240) -- ...to a cool grey at the bottom
local RED = Color3.fromRGB(240, 64, 64)
local NO_BACKGROUND = Color3.fromRGB(120, 120, 130)

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

-- A right-angled arrowhead pointing `heading` degrees (clockwise from 3 o'clock): the front half
-- of a `size` square standing on its corner, so its back edge runs through (x, y)
local function triangle(x: number, y: number, size: number, heading: number): Shape
	return box(x, y, size, size, { rot = heading - 45, r = 0.1, tri = heading })
end

local SHAPES: { [string]: { Shape } } = {}

-- A shopping cart: handle, basket with slots, two wheels
SHAPES.cart = {
	box(0.13, 0.19, 0.2, 0.085, { r = 0.5 }),
	box(0.27, 0.39, 0.075, 0.42, { rot = -16 }),
	box(0.58, 0.42, 0.6, 0.31, { r = 0.12 }),
	box(0.57, 0.665, 0.54, 0.085, { r = 0.5 }),
	circle(0.36, 0.83, 0.19),
	circle(0.74, 0.83, 0.19),
	box(0.45, 0.43, 0.06, 0.16, { fill = "ink", r = 0.5 }),
	box(0.58, 0.43, 0.06, 0.16, { fill = "ink", r = 0.5 }),
	box(0.71, 0.43, 0.06, 0.16, { fill = "ink", r = 0.5 }),
	circle(0.36, 0.83, 0.065, { fill = "ink" }),
	circle(0.74, 0.83, 0.065, { fill = "ink" }),
}

-- A closed book with a spine, a title strip, page edges and a red bookmark
SHAPES.book = {
	box(0.56, 0.55, 0.58, 0.72, { rot = -14, r = 0.1 }),
	box(0.5, 0.47, 0.58, 0.72, { rot = -14, r = 0.12 }),
	box(0.66, 0.86, 0.08, 0.2, { rot = -14, fill = RED }),
	box(0.31, 0.52, 0.05, 0.64, { rot = -14, fill = "ink" }),
	box(0.53, 0.37, 0.28, 0.09, { rot = -14, fill = "ink", r = 0.3 }),
	box(0.62, 0.84, 0.44, 0.03, { rot = -14, fill = "ink" }),
	box(0.6, 0.78, 0.42, 0.03, { rot = -14, fill = "ink" }),
}

SHAPES.paw = {
	ellipse(0.5, 0.67, 0.46, 0.36),
	ellipse(0.19, 0.42, 0.18, 0.23, { rot = -20 }),
	ellipse(0.38, 0.23, 0.18, 0.23, { rot = -8 }),
	ellipse(0.62, 0.23, 0.18, 0.23, { rot = 8 }),
	ellipse(0.81, 0.42, 0.18, 0.23, { rot = 20 }),
	shine(0.41, 0.6, 0.13, 0.06),
}

-- A circular arrow (↻): a thick arc of overlapping circles (they merge into one smooth band, and
-- the button itself shows through the middle and the gap), with an arrowhead at the top
local function arc(cx: number, cy: number, radius: number, band: number, from: number, to: number): { Shape }
	local list = {}
	local steps = math.ceil((to - from) / 6)
	for i = 0, steps do
		local a = math.rad(from + (to - from) * i / steps)
		table.insert(list, circle(cx + radius * math.cos(a), cy + radius * math.sin(a), band))
	end
	return list
end

-- point `along` the tangent (clockwise) and `out` from the centre, at the arc's end
local function fromEnd(cx: number, cy: number, radius: number, to: number, along: number, out: number): (number, number)
	local a = math.rad(to)
	local r = radius + out
	return cx + r * math.cos(a) - along * math.sin(a), cy + r * math.sin(a) + along * math.cos(a)
end

SHAPES.cycle = (function(): { Shape }
	local cx, cy, radius, band, from, to = 0.5, 0.56, 0.27, 0.18, 5, 245
	local list = arc(cx, cy, radius, band, from, to)
	local x, y = fromEnd(cx, cy, radius, to, 0, 0.035)
	table.insert(list, triangle(x, y, 0.31, to + 90))
	table.insert(list, shine(0.26, 0.55, 0.055, 0.13, 15))
	return list
end)()

-- A wrench crossed with a hammer
SHAPES.tools = {
	box(0.45, 0.55, 0.13, 0.62, { rot = 45, r = 0.45 }),
	circle(0.69, 0.31, 0.34),
	box(0.75, 0.25, 0.1, 0.2, { rot = 45, fill = "ink", r = 0.3 }),
	box(0.56, 0.56, 0.11, 0.62, { rot = -45, r = 0.45 }),
	box(0.34, 0.34, 0.44, 0.18, { rot = -45, r = 0.15 }),
	box(0.39, 0.39, 0.06, 0.18, { rot = -45, fill = "ink" }),
	box(0.66, 0.66, 0.035, 0.12, { rot = 45, fill = "ink" }),
	box(0.71, 0.71, 0.035, 0.12, { rot = 45, fill = "ink" }),
}

-- A house with a chimney, a door with a knob and a window
SHAPES.house = {
	box(0.72, 0.27, 0.1, 0.2),
	box(0.5, 0.42, 0.5, 0.5, { rot = 45, r = 0.06 }),
	box(0.5, 0.65, 0.56, 0.42),
	box(0.5, 0.45, 0.6, 0.035, { fill = "ink" }),
	box(0.61, 0.76, 0.15, 0.24, { fill = "ink", r = 0.2 }),
	circle(0.65, 0.77, 0.04, { fill = "shine" }),
	box(0.36, 0.63, 0.15, 0.15, { fill = "ink", r = 0.1 }),
	box(0.36, 0.63, 0.025, 0.15, { fill = "white", plain = true, z = 7 }),
	box(0.36, 0.63, 0.15, 0.025, { fill = "white", plain = true, z = 7 }),
}

-- A globe with a meridian and lines of latitude
SHAPES.globe = {
	circle(0.5, 0.5, 0.8),
	ellipse(0.5, 0.5, 0.4, 0.8, { fill = "ink" }),
	ellipse(0.5, 0.5, 0.29, 0.73, { fill = "white", plain = true, z = 7 }),
	box(0.5, 0.5, 0.78, 0.04, { fill = "ink", z = 8 }),
	box(0.5, 0.3, 0.62, 0.035, { fill = "ink", z = 8 }),
	box(0.5, 0.7, 0.62, 0.035, { fill = "ink", z = 8 }),
	shine(0.3, 0.27, 0.12, 0.06, -40),
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
		return ellipse(x, y, 0.2, 0.34, { rot = 45, color = Color3.fromRGB(255, 140, 30), z = 3 })
	end)
	add(-0.44, 0, function(x, y)
		return ellipse(x, y, 0.09, 0.18, { rot = 45, fill = "white", color = Color3.fromRGB(255, 230, 90), plain = true, z = 3 })
	end)
	for _, side in { -0.14, 0.14 } do
		add(-0.2, side, function(x, y)
			return box(x, y, 0.2, 0.2, { rot = 45, r = 0.18, color = RED, z = 3 })
		end)
	end
	-- the whole body is red; the white part covers all but the nose
	add(0, 0, function(x, y)
		return box(x, y, 0.3, 0.68, { rot = 45, r = 0.5, color = RED })
	end)
	add(-0.015, 0, function(x, y)
		return box(x, y, 0.3, 0.37, { rot = 45, fill = "white", plain = true, z = 5 })
	end)
	add(-0.19, 0, function(x, y)
		return circle(x, y, 0.3, { fill = "white", plain = true, z = 5 })
	end)
	add(0.17, 0, function(x, y)
		return box(x, y, 0.3, 0.035, { rot = 45, fill = "ink" })
	end)
	add(-0.03, 0, function(x, y)
		return circle(x, y, 0.19, { fill = "ink" })
	end)
	add(-0.03, 0, function(x, y)
		return circle(x, y, 0.12, { fill = Color3.fromRGB(110, 200, 255), plain = true, z = 7 })
	end)
	add(0, -0.03, function(x, y)
		return circle(x, y, 0.04, { fill = "shine" })
	end)
	add(0.05, -0.1, function(x, y)
		return shine(x, y, 0.035, 0.12, 45)
	end)
	return list
end)()

-- A painter's palette with a thumb hole and four blobs of paint
SHAPES.palette = {
	ellipse(0.5, 0.52, 0.88, 0.7, { rot = -10 }),
	circle(0.68, 0.68, 0.17, { fill = "hole" }),
	circle(0.28, 0.48, 0.15, { fill = RED }),
	circle(0.44, 0.3, 0.15, { fill = Color3.fromRGB(255, 215, 50) }),
	circle(0.66, 0.32, 0.15, { fill = Color3.fromRGB(70, 160, 255) }),
	circle(0.37, 0.69, 0.15, { fill = Color3.fromRGB(80, 210, 90) }),
	shine(0.25, 0.43, 0.05, 0.03, -30),
	shine(0.41, 0.25, 0.05, 0.03, -30),
	shine(0.63, 0.27, 0.05, 0.03, -30),
	shine(0.34, 0.64, 0.05, 0.03, -30),
}

local PINK = Color3.fromRGB(255, 92, 150)
SHAPES.heart = {
	circle(0.33, 0.38, 0.42, { color = PINK }),
	circle(0.67, 0.38, 0.42, { color = PINK }),
	box(0.5, 0.56, 0.48, 0.48, { rot = 45, r = 0.08, color = PINK }),
	shine(0.28, 0.33, 0.14, 0.08, -40),
	circle(0.4, 0.27, 0.045, { fill = "shine" }),
}

-- A newspaper: a headline, a picture and lines of text
SHAPES.news = {
	box(0.5, 0.5, 0.7, 0.8, { r = 0.08 }),
	box(0.5, 0.23, 0.52, 0.09, { fill = "ink", r = 0.2 }),
	box(0.34, 0.47, 0.2, 0.2, { fill = "ink", r = 0.1 }),
	box(0.6, 0.4, 0.24, 0.035, { fill = "ink" }),
	box(0.6, 0.48, 0.24, 0.035, { fill = "ink" }),
	box(0.6, 0.56, 0.24, 0.035, { fill = "ink" }),
	box(0.5, 0.67, 0.52, 0.035, { fill = "ink" }),
	box(0.45, 0.76, 0.42, 0.035, { fill = "ink" }),
}

-- Two quavers joined by a beam (♫)
SHAPES.note = {
	ellipse(0.3, 0.75, 0.28, 0.21, { rot = -20 }),
	ellipse(0.72, 0.67, 0.28, 0.21, { rot = -20 }),
	box(0.42, 0.46, 0.075, 0.58),
	box(0.84, 0.38, 0.075, 0.58),
	box(0.63, 0.17, 0.5, 0.13, { rot = -11 }),
}

-- A cog with eight teeth
SHAPES.gear = (function(): { Shape }
	local list = {}
	for i = 0, 3 do
		table.insert(list, box(0.5, 0.5, 0.18, 0.9, { rot = i * 45, r = 0.18 }))
	end
	table.insert(list, circle(0.5, 0.5, 0.66))
	table.insert(list, circle(0.5, 0.5, 0.26, { fill = "hole" }))
	return list
end)()

-- An open eye with a blue iris
SHAPES.eye = {
	ellipse(0.5, 0.5, 0.9, 0.56),
	circle(0.5, 0.5, 0.36, { fill = Color3.fromRGB(90, 170, 255) }),
	circle(0.5, 0.5, 0.18, { fill = "ink", z = 7 }),
	circle(0.44, 0.44, 0.07, { fill = "shine" }),
}

local BY_EMOJI: { [string]: string } = {
	["🛒"] = "cart",
	["📖"] = "book",
	["🐾"] = "paw",
	["🔄"] = "cycle",
	["🛠"] = "tools",
	["🛠️"] = "tools",
	["🏠"] = "house",
	["🌀"] = "globe",
	["🌍"] = "globe",
	["🚀"] = "rocket",
	["🎨"] = "palette",
	["💖"] = "heart",
	["📰"] = "news",
	["🎵"] = "note",
	["⚙️"] = "gear",
	["⚙"] = "gear",
	["👁"] = "eye",
}

-- The icon's name for an emoji (or a name), if there's a drawn icon for it.
function Icons.For(emojiOrName: string): string?
	if SHAPES[emojiOrName] then
		return emojiOrName
	end
	return BY_EMOJI[emojiOrName]
end

-- One shape as a Frame, `grow` (a share of the icon) bigger on every side, moved by `offset`.
local function frame(parent: Instance, shape: Shape, color: Color3, grow: number, z: number, offset: Vector2?): Frame
	local f = Instance.new("Frame")
	f.Name = "Shape"
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	local move = offset or Vector2.zero
	local x, y, w, h = shape.x, shape.y, shape.w + grow * 2, shape.h + grow * 2
	if shape.tri then
		-- a triangle's outline sticks out further at its corners (1.4x at the tip): grow the square
		-- so every edge moves out by `grow`, and slide it back so the back edge does too
		local heading = math.rad(shape.tri)
		w = shape.w + grow * (2 + math.sqrt(2))
		h = w
		x -= grow * math.cos(heading)
		y -= grow * math.sin(heading)
	end
	f.Position = UDim2.fromScale(x + move.X, y + move.Y)
	f.Size = UDim2.fromScale(w, h)
	f.Rotation = shape.rot or 0
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = z
	local r = shape.r or 0
	if r > 0 then
		-- (a corner's scale is a share of the shorter side: grown copies keep the same curve)
		local short = math.min(shape.w, shape.h)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(if r >= 0.5 then 0.5 else (r * short + grow) / math.min(w, h), 0)
		corner.Parent = f
	end
	if shape.tri then
		-- only the front half: a sharp see-through step across the square's middle
		local cut = Instance.new("UIGradient")
		cut.Rotation = 45
		cut.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 1),
			NumberSequenceKeypoint.new(0.505, 0),
			NumberSequenceKeypoint.new(1, 0),
		})
		cut.Parent = f
	end
	f.Parent = parent
	return f
end

-- White to grey from the top of the icon to the bottom, so the shading runs across every shape
-- of the body as one (`base` tints it for coloured body shapes).
local function shade(f: Frame, shape: Shape, base: Color3?)
	if shape.tri then
		local c = TOP:Lerp(BOTTOM, math.clamp(shape.y, 0, 1))
		f.BackgroundColor3 = if base then Color3.new(c.R * base.R, c.G * base.G, c.B * base.B) else c
		return
	end
	local rot = math.rad(shape.rot or 0)
	local half = (math.abs(shape.w * math.sin(rot)) + math.abs(shape.h * math.cos(rot))) / 2
	local top = math.clamp(shape.y - half, 0, 1)
	local bottom = math.clamp(shape.y + half, 0, 1)
	local function at(t: number): Color3
		local c = TOP:Lerp(BOTTOM, t)
		if base then
			c = Color3.new(c.R * base.R, c.G * base.G, c.B * base.B)
		end
		return c
	end
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90 - (shape.rot or 0)
	gradient.Color = ColorSequence.new(at(top), at(bottom))
	gradient.Parent = f
end

-- Layers, back to front
local Z = {
	Shadow = 1,
	Outline = 2,
	Body = 4, -- (a body shape with z = 3 sits behind the rest: the rocket's fins)
	SpotOutline = 5,
	Detail = 6, -- ink, spots, cut-outs
	Shine = 10,
}

-- Draw an icon into a new square Frame (named "Icon") inside `parent`. `background` is the
-- button's colour (for cut-outs and the shadow). Position and size the returned frame like an image.
function Icons.Draw(name: string, parent: Instance, background: Color3?): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Icon"
	holder.BackgroundTransparency = 1
	holder.SizeConstraint = Enum.SizeConstraint.RelativeYY
	holder.ZIndex = 2
	local shapes: { Shape } = SHAPES[name] or {}
	local back = background or NO_BACKGROUND
	-- the shadow is a solid darker shade of the button, so overlapping shapes don't stack darker
	local shadowColor = back:Lerp(BLACK, 0.55)
	local holeColor = back:Lerp(BLACK, 0.2)
	for _, shape in shapes do
		local fill = shape.fill or "white"
		if shape.plain or fill == "ink" or fill == "shine" then
			continue
		end
		if fill == "white" then
			frame(holder, shape, shadowColor, OUTLINE, Z.Shadow, SHADOW)
			frame(holder, shape, BLACK, OUTLINE, Z.Outline)
		else
			-- a coloured spot or a cut-out: its own (slightly thinner) outline
			if fill ~= "hole" then
				frame(holder, shape, shadowColor, OUTLINE * 0.75, Z.Shadow, SHADOW)
			end
			frame(holder, shape, BLACK, OUTLINE * 0.75, Z.SpotOutline)
		end
	end
	for _, shape in shapes do
		local fill = shape.fill or "white"
		if fill == "white" then
			local f = frame(holder, shape, TOP, 0, shape.z or Z.Body)
			shade(f, shape, shape.color)
		elseif fill == "ink" then
			frame(holder, shape, BLACK, 0, shape.z or Z.Detail)
		elseif fill == "shine" then
			local f = frame(holder, shape, TOP, 0, Z.Shine)
			f.BackgroundTransparency = 0.2
		elseif fill == "hole" or typeof(fill) == "Color3" then
			frame(holder, shape, if fill == "hole" then holeColor else fill, 0, shape.z or Z.Detail)
		end
	end
	holder.Parent = parent
	return holder
end

return Icons
