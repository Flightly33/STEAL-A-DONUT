--[[
	Icons: chunky cartoon icons for the HUD and windows, white with a thick black outline (like the
	big simulator games), drawn from plain Frames so there's nothing to upload. They replace these
	emojis wherever a Theme.Button or a HUD square uses one: 🛒 📖 🐾 🔄 🛠 🏠 🌀 🚀 🎨 💖 📰 🎵 ⚙️ 👁

	Each icon is a list of shapes in a 1 x 1 box (x, y = centre; w, h = size; rot = degrees):
	  fill "white" (default): white with the shared black outline (overlapping shapes merge into one
	                          silhouette: every outline is drawn first, then every fill on top)
	  fill "ink":             black detail drawn on top (lines, doors, pupils)
	  fill "hole":            the button's own colour, outlined (a cut-out: the gear's middle)
	  fill <Color3>:          a coloured dot with its own outline (paint on the palette)
	  fill "glint":           a small white highlight on top of the ink
	  ring = n:               just an outline of that thickness (the globe's lines)
]]

local Icons = {}

local OUTLINE = 3 -- pixels (before the HUD's UIScale)
local BLACK = Color3.fromRGB(20, 20, 26)
local WHITE = Color3.fromRGB(255, 255, 255)

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

local SHAPES: { [string]: { Shape } } = {}

SHAPES.cart = {
	box(0.56, 0.42, 0.62, 0.34, { r = 0.15 }),
	box(0.14, 0.2, 0.2, 0.08, { r = 0.5 }),
	box(0.26, 0.42, 0.07, 0.44, { rot = -14 }),
	box(0.55, 0.66, 0.58, 0.08, { r = 0.5 }),
	circle(0.34, 0.83, 0.17),
	circle(0.72, 0.83, 0.17),
	box(0.46, 0.42, 0.045, 0.22, { fill = "ink" }),
	box(0.66, 0.42, 0.045, 0.22, { fill = "ink" }),
}

SHAPES.book = {
	box(0.52, 0.5, 0.6, 0.74, { rot = -14, r = 0.12 }),
	box(0.326, 0.548, 0.05, 0.66, { rot = -14, fill = "ink" }),
	box(0.593, 0.79, 0.46, 0.035, { rot = -14, fill = "ink" }),
	box(0.58, 0.74, 0.44, 0.03, { rot = -14, fill = "ink" }),
}

SHAPES.paw = {
	ellipse(0.5, 0.67, 0.46, 0.36),
	ellipse(0.19, 0.42, 0.18, 0.23, { rot = -20 }),
	ellipse(0.38, 0.23, 0.18, 0.23, { rot = -8 }),
	ellipse(0.62, 0.23, 0.18, 0.23, { rot = 8 }),
	ellipse(0.81, 0.42, 0.18, 0.23, { rot = 20 }),
}

-- A circular arrow (↻): a thick white ring with a gap at the top right and an arrowhead
SHAPES.cycle = {
	circle(0.5, 0.54, 0.76),
	circle(0.5, 0.54, 0.38, { fill = "hole" }),
	box(0.72, 0.368, 0.15, 0.26, { rot = 52, fill = "hole", plain = true }),
	-- arrowhead: a chevron whose tip points round the ring into the gap
	box(0.606, 0.2035, 0.24, 0.1, { rot = -110, r = 0.5, top = true }),
	box(0.5416, 0.3149, 0.24, 0.1, { rot = 170, r = 0.5, top = true }),
}

-- A wrench crossed with a hammer
SHAPES.tools = {
	box(0.45, 0.55, 0.12, 0.6, { rot = 45, r = 0.4 }),
	circle(0.69, 0.31, 0.32),
	box(0.76, 0.24, 0.13, 0.2, { rot = 45, fill = "hole" }),
	box(0.55, 0.55, 0.1, 0.62, { rot = -45, r = 0.4 }),
	box(0.338, 0.338, 0.42, 0.17, { rot = -45, r = 0.15 }),
}

SHAPES.house = {
	box(0.72, 0.27, 0.09, 0.2),
	box(0.5, 0.42, 0.5, 0.5, { rot = 45, r = 0.06 }),
	box(0.5, 0.64, 0.56, 0.42),
	box(0.5, 0.75, 0.14, 0.2, { fill = "ink", r = 0.15 }),
}

SHAPES.globe = {
	circle(0.5, 0.5, 0.8),
	ellipse(0.5, 0.5, 0.36, 0.78, { ring = 2.5 }),
	box(0.5, 0.5, 0.78, 0.035, { fill = "ink" }),
	box(0.5, 0.3, 0.62, 0.03, { fill = "ink" }),
	box(0.5, 0.7, 0.62, 0.03, { fill = "ink" }),
}

SHAPES.rocket = {
	ellipse(0.22, 0.78, 0.14, 0.28, { rot = 45, fill = Color3.fromRGB(255, 150, 40) }),
	box(0.25, 0.57, 0.2, 0.12, { rot = -45, r = 0.3 }),
	box(0.43, 0.75, 0.2, 0.12, { rot = -45, r = 0.3 }),
	box(0.55, 0.45, 0.3, 0.66, { rot = 45, r = 0.5 }),
	circle(0.6, 0.4, 0.15, { fill = "ink" }),
	circle(0.585, 0.385, 0.05, { fill = "glint" }),
}

SHAPES.palette = {
	ellipse(0.5, 0.52, 0.88, 0.7, { rot = -10 }),
	circle(0.68, 0.68, 0.16, { fill = "hole" }),
	circle(0.28, 0.48, 0.14, { fill = Color3.fromRGB(255, 70, 70) }),
	circle(0.44, 0.3, 0.14, { fill = Color3.fromRGB(255, 215, 50) }),
	circle(0.66, 0.32, 0.14, { fill = Color3.fromRGB(70, 160, 255) }),
	circle(0.36, 0.68, 0.14, { fill = Color3.fromRGB(80, 210, 90) }),
}

SHAPES.heart = {
	circle(0.33, 0.38, 0.42),
	circle(0.67, 0.38, 0.42),
	box(0.5, 0.56, 0.48, 0.48, { rot = 45, r = 0.08 }),
	circle(0.3, 0.33, 0.09, { fill = "glint" }),
}

SHAPES.news = {
	box(0.5, 0.5, 0.7, 0.8, { r = 0.08 }),
	box(0.5, 0.24, 0.5, 0.08, { fill = "ink" }),
	box(0.5, 0.42, 0.5, 0.035, { fill = "ink" }),
	box(0.5, 0.54, 0.5, 0.035, { fill = "ink" }),
	box(0.5, 0.66, 0.5, 0.035, { fill = "ink" }),
	box(0.42, 0.78, 0.34, 0.035, { fill = "ink" }),
}

SHAPES.note = {
	ellipse(0.3, 0.75, 0.27, 0.2, { rot = -20 }),
	ellipse(0.72, 0.67, 0.27, 0.2, { rot = -20 }),
	box(0.415, 0.46, 0.07, 0.58),
	box(0.835, 0.38, 0.07, 0.58),
	box(0.625, 0.17, 0.5, 0.12, { rot = -11 }),
}

SHAPES.gear = (function(): { Shape }
	local list = {}
	for i = 0, 3 do
		table.insert(list, box(0.5, 0.5, 0.17, 0.88, { rot = i * 45, r = 0.15 }))
	end
	table.insert(list, circle(0.5, 0.5, 0.66))
	table.insert(list, circle(0.5, 0.5, 0.26, { fill = "hole" }))
	return list
end)()

SHAPES.eye = {
	ellipse(0.5, 0.5, 0.88, 0.54),
	circle(0.5, 0.5, 0.32, { fill = "ink" }),
	circle(0.45, 0.44, 0.09, { fill = "glint" }),
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

local function frame(parent: Instance, shape: Shape, color: Color3, grow: number, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = "Shape"
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(shape.x, shape.y)
	f.Size = UDim2.new(shape.w, grow * 2, shape.h, grow * 2)
	f.Rotation = shape.rot or 0
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = z
	if shape.r and shape.r > 0 then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(shape.r, if shape.r >= 0.5 then 0 else grow)
		corner.Parent = f
	end
	f.Parent = parent
	return f
end

-- Draw an icon into a new square Frame (named "Icon") inside `parent`. `background` is the
-- button's colour (for cut-outs). Position and size the returned frame like an image.
function Icons.Draw(name: string, parent: Instance, background: Color3?): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Icon"
	holder.BackgroundTransparency = 1
	holder.SizeConstraint = Enum.SizeConstraint.RelativeYY
	holder.ZIndex = 2
	local shapes: { Shape } = SHAPES[name] or {}
	local base = holder.ZIndex
	for _, shape in shapes do
		local fill = shape.fill or "white"
		if not shape.ring and fill == "white" then
			-- ("top" shapes sit above the cut-outs: the cycle icon's arrowhead)
			frame(holder, shape, BLACK, OUTLINE, if shape.top then base + 3 else base)
		end
	end
	for _, shape in shapes do
		local fill = shape.fill or "white"
		if shape.ring then
			local f = frame(holder, shape, WHITE, 0, base + 2)
			f.BackgroundTransparency = 1
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = shape.ring
			stroke.Color = BLACK
			stroke.Parent = f
		elseif fill == "white" then
			frame(holder, shape, WHITE, 0, if shape.top then base + 4 else base + 1)
		elseif fill == "ink" then
			frame(holder, shape, BLACK, 0, base + 2)
		elseif fill == "glint" then
			frame(holder, shape, WHITE, 0, base + 3)
		elseif fill == "hole" and shape.plain then
			-- a plain gap in the button's colour, drawn over the white (and its outline)
			frame(holder, shape, background or Color3.fromRGB(120, 120, 130), OUTLINE, base + 2)
		elseif fill == "hole" or typeof(fill) == "Color3" then
			local f = frame(holder, shape, if fill == "hole" then background or Color3.fromRGB(120, 120, 130) else fill, 0, base + 2)
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = OUTLINE - 0.5
			stroke.Color = BLACK
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Parent = f
		end
	end
	holder.Parent = parent
	return holder
end

return Icons
