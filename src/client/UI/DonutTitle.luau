--[[
	DonutTitle: the game's name made to look like a donut, for the opening cinematic (client/Intro).

	  STEAL A  - glossy pink frosting, dripping down off the letters, covered in sprinkles
	  DONUT    - golden baked dough, and its O is a real frosted donut

	Built from text and frames only (nothing to upload). It's designed at a fixed size (WIDTH x
	HEIGHT pixels, the letters at TextSize 74 and 100) and a UIScale makes it fit the screen, so the
	letters stay sharp at any size.

	  local title = DonutTitle.new(parent)
	  DonutTitle.Step(title, now, start, alpha, viewport, grow) - every frame: from `start` the letters
	      pop in one by one, the frosting drips down, the sprinkles pop on and the donut spins in;
	      `alpha` fades all of it; `grow` scales it up (for going out)

	Where the drips and sprinkles sit was measured from the font itself (Luckiest Guy): every drip
	starts inside its letter and flows out of its bottom edge, and every sprinkle sits on a thick
	part of a letter. All in units of the letters' text size.
]]

local DonutTitle = {}

local rgb = Color3.fromRGB
local WHITE = rgb(255, 255, 255)

local WIDTH, HEIGHT = 344, 168
local TOP_SIZE, BOTTOM_SIZE = 74, 100
local TOP_Y, BOTTOM_Y = 4, 80
local CAP = 0.7 -- (how much of a line the capitals fill, from the top)

local FROSTING = { rgb(255, 214, 236), rgb(255, 140, 200), rgb(243, 86, 164) }
local DOUGH = { rgb(255, 226, 168), rgb(238, 176, 98), rgb(193, 120, 56) }
local BERRY = rgb(104, 22, 64)
local CRUST = rgb(86, 46, 22)
local SPRINKLES = { WHITE, rgb(255, 214, 60), rgb(90, 200, 255), rgb(120, 222, 110), rgb(190, 120, 255), rgb(255, 140, 60), rgb(255, 84, 96) }

type Glyph = { Advance: number, Sprinkles: { { number } }?, Drips: { { number } }? }
-- Drips: { x, where it starts (inside the letter), width, length }.
local GLYPHS: { [string]: Glyph } = {
	S = {
		Advance = 0.53,
		Sprinkles = { { 0.2925, 0.35 }, { 0.0825, 0.61 }, { 0.4025, 0.05 }, { 0.1125, 0.12 } },
		Drips = { { 0.106, 0.64, 0.1, 0.27 }, { 0.33, 0.66, 0.085, 0.15 } },
	},
	T = {
		Advance = 0.5425,
		Sprinkles = { { 0.3425, 0.185 }, { 0.2125, 0.625 }, { 0.0725, 0.065 }, { 0.2125, 0.385 }, { 0.4725, 0.065 } },
		Drips = { { 0.06, 0.19, 0.075, 0.13 }, { 0.245, 0.64, 0.11, 0.4 } },
	},
	E = {
		Advance = 0.48,
		Sprinkles = { { 0.2525, 0.3375 }, { 0.0825, 0.6375 }, { 0.4225, 0.0575 }, { 0.0925, 0.0575 } },
		Drips = { { 0.08, 0.66, 0.09, 0.2 }, { 0.31, 0.66, 0.095, 0.32 } },
	},
	A = {
		Advance = 0.625,
		Sprinkles = { { 0.425, 0.3825 }, { 0.065, 0.6125 }, { 0.225, 0.0725 }, { 0.145, 0.3425 }, { 0.555, 0.6125 }, { 0.435, 0.1525 } },
		Drips = { { 0.095, 0.64, 0.1, 0.3 }, { 0.53, 0.64, 0.09, 0.16 } },
	},
	L = {
		Advance = 0.4525,
		Sprinkles = { { 0.1225, 0.415 }, { 0.2225, 0.055 }, { 0.3825, 0.575 }, { 0.0925, 0.215 } },
		Drips = { { 0.06, 0.63, 0.095, 0.36 }, { 0.33, 0.62, 0.085, 0.19 } },
	},
	D = { Advance = 0.5825 },
	N = { Advance = 0.7025 },
	U = { Advance = 0.6225 },
}
-- (the second A drips differently from the first)
local SECOND_A_DRIPS = { { 0.11, 0.64, 0.095, 0.18 }, { 0.5, 0.64, 0.1, 0.33 } }

type Fade = { Object: Instance, Property: string, Base: number }
type Drip = { Fill: Frame, Line: Frame, Blob: Frame, BlobLine: Frame, X: number, Y: number, Width: number, Length: number, Start: number, Phase: number }
type Pop = { Item: GuiObject, Scale: UIScale, Start: number }
type Letter = { Holder: Frame, Scale: UIScale, Y: number, Start: number, Spin: boolean }
export type Title = {
	Frame: Frame,
	Scale: UIScale,
	Letters: { Letter },
	Drips: { Drip },
	Sprinkles: { Pop },
	Fades: { Fade },
	Alpha: number,
}

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

local function gradient(parent: Instance, colors: { Color3 }, rotation: number, stops: { number }?)
	local g = Instance.new("UIGradient")
	local at = stops or { 0, 0.5, 1 }
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(at[1], colors[1]),
		ColorSequenceKeypoint.new(at[2], colors[2]),
		ColorSequenceKeypoint.new(at[3], colors[3]),
	})
	g.Rotation = rotation
	g.Parent = parent
end

function DonutTitle.new(parent: Instance): Title
	local frame = Instance.new("Frame")
	frame.Name = "Title"
	frame:SetAttribute("Text", "STEAL A DONUT")
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.38)
	frame.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	frame.Rotation = -4
	frame.Visible = false
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	local title: Title = { Frame = frame, Scale = scale, Letters = {}, Drips = {}, Sprinkles = {}, Fades = {}, Alpha = -1 }
	local rng = Random.new(20261012)

	local function fade(object: Instance, property: string, base: number)
		table.insert(title.Fades, { Object = object, Property = property, Base = base })
	end
	local function block(name: string, color: Color3, z: number, parentTo: Instance): Frame
		local f = Instance.new("Frame")
		f.Name = name
		f.BorderSizePixel = 0
		f.BackgroundColor3 = color
		f.ZIndex = z
		f.Parent = parentTo
		fade(f, "BackgroundTransparency", 0)
		return f
	end
	local function glyph(holder: Frame, ch: string, size: number, colors: { Color3 }, line: Color3, thickness: number, shadow: boolean)
		local label = Instance.new("TextLabel")
		label.Name = if shadow then "Shadow" else "Glyph"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Position = if shadow then UDim2.fromOffset(0, size * 0.055) else UDim2.fromOffset(0, 0)
		label.Font = Enum.Font.LuckiestGuy
		label.Text = ch
		label.TextSize = size
		label.TextColor3 = if shadow then rgb(60, 18, 40) else WHITE
		label.ZIndex = if shadow then 1 else 3
		label.Parent = holder
		fade(label, "TextTransparency", if shadow then 0.45 else 0)
		if not shadow then
			-- (the colours run down the capitals, which fill the top of the line)
			gradient(label, colors, 90, { 0, CAP * 0.45, CAP })
		end
		local stroke = Instance.new("UIStroke")
		stroke.Color = if shadow then rgb(60, 18, 40) else line
		stroke.Thickness = thickness
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Parent = label
		fade(stroke, "Transparency", if shadow then 0.45 else 0)
	end
	local function letterHolder(name: string, x: number, y: number, w: number, h: number, start: number, spin: boolean): (Frame, Letter)
		local holder = Instance.new("Frame")
		holder.Name = name
		holder.BackgroundTransparency = 1
		-- (it pops up from the middle of the capital)
		holder.AnchorPoint = Vector2.new(0.5, CAP / 2)
		holder.Position = UDim2.fromOffset(x + w / 2, y + h * CAP / 2)
		holder.Size = UDim2.fromOffset(w, h)
		-- (DONUT in front: any long drip hangs down behind it)
		holder.ZIndex = if y >= BOTTOM_Y then 3 else 2
		holder.Parent = frame
		local s = Instance.new("UIScale")
		s.Scale = 0
		s.Parent = holder
		local letter: Letter = { Holder = holder, Scale = s, Y = y + h * CAP / 2, Start = start, Spin = spin }
		table.insert(title.Letters, letter)
		return holder, letter
	end
	local function sprinkle(holder: Instance, cx: number, cy: number, size: number, start: number)
		local s = block("Sprinkle", SPRINKLES[rng:NextInteger(1, #SPRINKLES)], 5, holder)
		s.AnchorPoint = Vector2.new(0.5, 0.5)
		s.Position = UDim2.fromOffset(cx, cy)
		s.Size = UDim2.fromOffset(size * 0.1, size * 0.034)
		s.Rotation = rng:NextNumber(0, 180)
		corner(s, UDim.new(0.5, 0))
		local pop = Instance.new("UIScale")
		pop.Scale = 0
		pop.Parent = s
		table.insert(title.Sprinkles, { Item = s, Scale = pop, Start = start })
	end

	-- STEAL A: frosting
	local top = { "S", "T", "E", "A", "L", " ", "A" }
	local widths = 0
	for _, ch in top do
		widths += if ch == " " then 0.3 * TOP_SIZE else GLYPHS[ch].Advance * TOP_SIZE + 2
	end
	local x = (WIDTH - widths) / 2
	local order = 0
	local seenA = false
	for _, ch in top do
		if ch == " " then
			x += 0.3 * TOP_SIZE
			continue
		end
		local g = GLYPHS[ch]
		local w = g.Advance * TOP_SIZE
		local start = order * 0.07
		order += 1
		local holder = letterHolder("Letter" .. ch, x, TOP_Y, w, TOP_SIZE, start, false)
		glyph(holder, ch, TOP_SIZE, FROSTING, BERRY, 3.5, true)
		glyph(holder, ch, TOP_SIZE, FROSTING, BERRY, 3.5, false)
		local drips: { { number } } = g.Drips or {}
		if ch == "A" then
			drips = if seenA then SECOND_A_DRIPS else drips
			seenA = true
		end
		for _, d in drips do
			local dx, dy, dw, dl = d[1] * TOP_SIZE, d[2] * TOP_SIZE, d[3] * TOP_SIZE, d[4] * TOP_SIZE
			-- outline behind the letter (it only shows outside it), pink fill in front of it (so
			-- it flows out of the letter with no line across it)
			local line = block("DripLine", BERRY, 2, holder)
			local fill = block("Drip", FROSTING[3], 4, holder)
			local blobLine = block("BlobLine", BERRY, 2, holder)
			local blob = block("Blob", FROSTING[3], 4, holder)
			gradient(fill, { FROSTING[3], FROSTING[2], FROSTING[3] }, 0, { 0, 0.35, 1 })
			gradient(blob, { FROSTING[3], FROSTING[2], FROSTING[3] }, 0, { 0, 0.35, 1 })
			for _, f in { line, fill, blobLine, blob } do
				f.AnchorPoint = Vector2.new(0.5, 0)
				corner(f, UDim.new(0.5, 0))
			end
			blob.AnchorPoint = Vector2.new(0.5, 0.5)
			blobLine.AnchorPoint = Vector2.new(0.5, 0.5)
			table.insert(title.Drips, { Fill = fill, Line = line, Blob = blob, BlobLine = blobLine, X = dx, Y = dy, Width = dw, Length = dl, Start = start + 0.35 + rng:NextNumber(0, 0.3), Phase = rng:NextNumber(0, 6) })
		end
		local spots: { { number } } = g.Sprinkles or {}
		for _, p in spots do
			sprinkle(holder, p[1] * TOP_SIZE, p[2] * TOP_SIZE, TOP_SIZE, 0.95 + rng:NextNumber(0, 0.55))
		end
		x += w + 2
	end

	-- DONUT: baked dough, with a real donut for the O
	local bottom = { "D", "O", "N", "U", "T" }
	local ring = 0.74 * BOTTOM_SIZE
	widths = 0
	for _, ch in bottom do
		widths += (if ch == "O" then ring + 6 else GLYPHS[ch].Advance * BOTTOM_SIZE) + 3
	end
	x = (WIDTH - widths) / 2
	order = 0
	for _, ch in bottom do
		local start = 0.45 + order * 0.07
		order += 1
		if ch == "O" then
			local w = ring + 6
			local holder = letterHolder("DonutO", x, BOTTOM_Y, w, BOTTOM_SIZE, start, true)
			local cx, cy = w / 2, BOTTOM_SIZE * CAP / 2
			local hole = ring * 0.34
			local band = (ring - hole) / 2
			-- a ring is a round frame's outline (UIStroke): the dough, its crust line, the frosting
			local function ringOf(name: string, inner: number, thickness: number, color: Color3, z: number, colors: { Color3 }?): Frame
				local f = Instance.new("Frame")
				f.Name = name
				f.BackgroundTransparency = 1
				f.AnchorPoint = Vector2.new(0.5, 0.5)
				f.Position = UDim2.fromOffset(cx, cy)
				f.Size = UDim2.fromOffset(inner, inner)
				f.ZIndex = z
				f.Parent = holder
				corner(f, UDim.new(0.5, 0))
				local stroke = Instance.new("UIStroke")
				stroke.Color = if colors then WHITE else color
				stroke.Thickness = thickness
				stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				stroke.Parent = f
				fade(stroke, "Transparency", 0)
				if colors then
					gradient(stroke, colors, 90)
				end
				return f
			end
			local shadow = ringOf("RingShadow", hole - 4, band + 4, rgb(60, 18, 40), 1)
			shadow.Position = UDim2.fromOffset(cx, cy + BOTTOM_SIZE * 0.055)
			local shadowStroke = shadow:FindFirstChildOfClass("UIStroke")
			if shadowStroke then
				shadowStroke.Transparency = 0.45
				title.Fades[#title.Fades].Base = 0.45
			end
			ringOf("RingLine", hole - 4.5, band + 4.5, CRUST, 2)
			ringOf("Dough", hole, band, WHITE, 3, DOUGH)
			local inner = hole + band * 0.32
			local frostBand = band * 0.62
			ringOf("Frosting", inner, frostBand, WHITE, 4, FROSTING)
			-- a wavy edge to the frosting, and a couple of drips over the side
			local edge = inner / 2 + frostBand
			for i = 1, 11 do
				local a = (i / 11) * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
				local d = band * rng:NextNumber(0.34, 0.46)
				local bump = block("Wave", FROSTING[2], 4, holder)
				bump.AnchorPoint = Vector2.new(0.5, 0.5)
				bump.Size = UDim2.fromOffset(d, d)
				bump.Position = UDim2.fromOffset(cx + math.cos(a) * (edge - d * 0.3), cy + math.sin(a) * (edge - d * 0.3))
				corner(bump, UDim.new(0.5, 0))
			end
			for _, a in { 0.62, 0.95 } do
				local ang = a * math.pi -- (lower half: y grows downwards)
				local d = block("RingDrip", FROSTING[2], 4, holder)
				d.AnchorPoint = Vector2.new(0.5, 0)
				d.Size = UDim2.fromOffset(band * 0.3, band * 0.55)
				d.Position = UDim2.fromOffset(cx + math.cos(ang) * (edge - 3), cy + math.sin(ang) * (edge - 3))
				corner(d, UDim.new(0.5, 0))
			end
			for i = 1, 9 do
				local a = (i / 9) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
				local r = inner / 2 + frostBand * rng:NextNumber(0.35, 0.75)
				sprinkle(holder, cx + math.cos(a) * r, cy + math.sin(a) * r, BOTTOM_SIZE * 0.85, 1.05 + rng:NextNumber(0, 0.5))
			end
			local shine = block("Shine", WHITE, 6, holder)
			shine.AnchorPoint = Vector2.new(0.5, 0.5)
			shine.Size = UDim2.fromOffset(band * 0.55, band * 0.16)
			shine.Position = UDim2.fromOffset(cx - ring * 0.25, cy - ring * 0.3)
			shine.Rotation = -40
			corner(shine, UDim.new(0.5, 0))
			title.Fades[#title.Fades].Base = 0.35
			shine.BackgroundTransparency = 0.35
			x += w + 3
		else
			local w = GLYPHS[ch].Advance * BOTTOM_SIZE
			local holder = letterHolder("Letter" .. ch, x, BOTTOM_Y, w, BOTTOM_SIZE, start, false)
			glyph(holder, ch, BOTTOM_SIZE, DOUGH, CRUST, 4.5, true)
			glyph(holder, ch, BOTTOM_SIZE, DOUGH, CRUST, 4.5, false)
			x += w + 3
		end
	end
	frame.Parent = parent
	return title
end

local function smooth(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * a * (a * (a * 6 - 15) + 10)
end
local function backOut(u: number): number
	u = math.clamp(u, 0, 1)
	local c = 1.70158
	return 1 + (c + 1) * (u - 1) ^ 3 + c * (u - 1) ^ 2
end

function DonutTitle.Step(title: Title, now: number, start: number, alpha: number, viewport: Vector2, grow: number)
	local t = now - start
	title.Frame.Visible = alpha > 0.002 and t > 0
	if not title.Frame.Visible then
		return
	end
	-- fits about 60% of the screen's width, 40% of its height (whichever is smaller)
	local fit = math.min(viewport.X * 0.6 / WIDTH, viewport.Y * 0.4 / HEIGHT)
	title.Scale.Scale = fit * grow
	title.Frame.Rotation = -4 + math.sin(now * 1.7) * 1.2
	for _, letter in title.Letters do
		local u = (t - letter.Start) / 0.42
		letter.Scale.Scale = backOut(u)
		letter.Holder.Position = UDim2.fromOffset(letter.Holder.Position.X.Offset, letter.Y - (1 - smooth(u)) * 22)
		if letter.Spin then
			letter.Holder.Rotation = -220 * (1 - smooth(u))
		end
	end
	-- the frosting oozes down, then sways a little
	for _, d in title.Drips do
		local u = math.clamp((t - d.Start) / 0.9, 0, 1)
		local length = d.Length * (1 - (1 - u) ^ 3) * (1 + 0.03 * math.sin(now * 2.1 + d.Phase))
		local blob = d.Width * 1.32
		d.Fill.Position = UDim2.fromOffset(d.X, d.Y)
		d.Fill.Size = UDim2.fromOffset(d.Width, math.max(length, d.Width))
		d.Line.Position = UDim2.fromOffset(d.X, d.Y - 1.75)
		d.Line.Size = UDim2.fromOffset(d.Width + 3.5, math.max(length, d.Width) + 3.5)
		d.Blob.Position = UDim2.fromOffset(d.X, d.Y + length)
		d.Blob.Size = UDim2.fromOffset(blob, blob)
		d.BlobLine.Position = UDim2.fromOffset(d.X, d.Y + length)
		d.BlobLine.Size = UDim2.fromOffset(blob + 3.5, blob + 3.5)
	end
	for _, s in title.Sprinkles do
		s.Scale.Scale = backOut((t - s.Start) / 0.25)
	end
	if math.abs(alpha - title.Alpha) > 1e-3 then
		title.Alpha = alpha
		for _, f in title.Fades do
			(f.Object :: any)[f.Property] = 1 - (1 - f.Base) * alpha
		end
	end
end

return DonutTitle
