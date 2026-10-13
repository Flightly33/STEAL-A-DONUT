--[[
	DonutTitle: the game's name made to look like a donut, for the opening cinematic (client/Intro).

	  STEAL A  - glossy bright pink frosting, dripping down off the letters, covered in sprinkles
	  DONUT    - golden baked dough, and its O is a real frosted donut

	Lettered like the game's logo: a chunky round font (Fredoka One), every letter tipped a little
	this way or that on a bouncy baseline, a thick dark outline with a pink rim round it all, and a
	solid 3D edge under every letter so the title pops out of the screen. It slams in letter by
	letter, then punches out once with a burst of light behind it.

	Built from text and frames only (nothing to upload). It's designed at a fixed size (WIDTH x
	HEIGHT pixels, the letters at TextSize 82 and 110) and a UIScale makes it fit the screen, so the
	letters stay sharp at any size.

	  local title = DonutTitle.new(parent)
	  DonutTitle.Step(title, now, start, alpha, viewport, grow) - every frame: from `start` the letters
	      pop in one by one, the frosting drips down, the sprinkles pop on and the donut spins in;
	      `alpha` fades all of it; `grow` scales it up (for going out)

	Where the drips and sprinkles sit was measured from the font itself (Fredoka One): every drip
	starts inside its letter and flows out of its bottom edge, and every sprinkle sits on a thick
	part of a letter. All in units of the letters' text size (the line: the capitals fill it from
	CAP_TOP to CAP_BOTTOM).
]]

local DonutTitle = {}

local rgb = Color3.fromRGB
local WHITE = rgb(255, 255, 255)

local WIDTH, HEIGHT = 440, 188
local TOP_SIZE, BOTTOM_SIZE = 82, 110
local CAP_TOP, CAP_BOTTOM = 0.2, 0.805 -- (where the capitals are in a line, from the top)
local CAP_MID = (CAP_TOP + CAP_BOTTOM) / 2
local TOP_Y, BOTTOM_Y = 8 - CAP_TOP * 82, 94 - CAP_TOP * 110
-- the room between letters (pixels), and between STEAL and A (a share of the text size)
local TOP_GAP, BOTTOM_GAP, WORD_GAP = 9, 11, 0.45

local FROSTING = { rgb(255, 196, 238), rgb(255, 102, 200), rgb(236, 40, 160) }
local DOUGH = { rgb(255, 238, 150), rgb(255, 196, 60), rgb(234, 130, 26) }
local BERRY = rgb(84, 10, 58)
local CRUST = rgb(92, 40, 14)
local RIM = rgb(255, 128, 176) -- (the pink rim round the outline, like the logo)
local DEPTH = 5 -- layers in each letter's 3D edge
-- each letter's tilt (degrees) and how far it's bumped up or down (share of its size), in order:
-- S T E A L A, then D O N U T
local BOUNCE = { { -8, 0.02 }, { 5, -0.03 }, { -4, 0.02 }, { 7, -0.02 }, { -6, 0.03 }, { 6, -0.01 }, { -5, -0.02 }, { 0, 0.02 }, { 5, -0.03 }, { -6, 0.02 }, { 7, 0 } }
local SPRINKLES = { WHITE, rgb(255, 214, 60), rgb(90, 200, 255), rgb(120, 222, 110), rgb(190, 120, 255), rgb(255, 140, 60), rgb(255, 84, 96) }

type Glyph = { Advance: number, Sprinkles: { { number } }?, Drips: { { number } }? }
-- Drips: { x, where it starts (inside the letter), width, length }.
local GLYPHS: { [string]: Glyph } = {
	S = {
		Advance = 0.4814,
		Sprinkles = { { 0.2686, 0.5124 }, { 0.1529, 0.2562 }, { 0.1364, 0.7355 }, { 0.3595, 0.719 } },
		Drips = { { 0.17, 0.74, 0.085, 0.24 }, { 0.31, 0.74, 0.075, 0.13 } },
	},
	T = {
		Advance = 0.6033,
		Sprinkles = { { 0.2934, 0.3574 }, { 0.3182, 0.7541 }, { 0.5331, 0.25 }, { 0.062, 0.25 }, { 0.2851, 0.5558 } },
		Drips = { { 0.3, 0.74, 0.09, 0.33 } },
	},
	E = {
		Advance = 0.5269,
		Sprinkles = { { 0.3636, 0.4979 }, { 0.0826, 0.7459 }, { 0.0826, 0.2583 }, { 0.4463, 0.7541 }, { 0.4463, 0.25 } },
		Drips = { { 0.1, 0.74, 0.085, 0.18 }, { 0.33, 0.74, 0.09, 0.3 } },
	},
	A = {
		Advance = 0.6322,
		Sprinkles = { { 0.1942, 0.5475 }, { 0.5661, 0.7376 }, { 0.3264, 0.2583 }, { 0.4504, 0.4979 }, { 0.0702, 0.7459 } },
		Drips = { { 0.095, 0.74, 0.085, 0.27 }, { 0.535, 0.74, 0.08, 0.15 } },
	},
	L = {
		Advance = 0.4855,
		Sprinkles = { { 0.1157, 0.5806 }, { 0.4132, 0.7541 }, { 0.0909, 0.25 }, { 0.2149, 0.7541 } },
		Drips = { { 0.08, 0.74, 0.085, 0.33 }, { 0.36, 0.74, 0.08, 0.17 } },
	},
	D = { Advance = 0.5826 },
	N = { Advance = 0.595 },
	U = { Advance = 0.5992 },
}
-- (the second A drips differently from the first)
local SECOND_A_DRIPS = { { 0.11, 0.74, 0.08, 0.16 }, { 0.53, 0.74, 0.085, 0.3 } }

type Fade = { Object: Instance, Property: string, Base: number }
type Drip = { Fill: Frame, Line: Frame, Blob: Frame, BlobLine: Frame, X: number, Y: number, Width: number, Length: number, Start: number, Phase: number }
type Pop = { Item: GuiObject, Scale: UIScale, Start: number }
type Letter = { Holder: Frame, Scale: UIScale, X: number, Y: number, Tilt: number, Start: number, Spin: boolean }
type Ray = { Bar: Frame, Angle: number }
export type Title = {
	Frame: Frame,
	Scale: UIScale,
	Letters: { Letter },
	Rays: { Ray },
	Burst: Frame,
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
	local burst = Instance.new("Frame")
	burst.Name = "Burst"
	burst.BackgroundTransparency = 1
	burst.AnchorPoint = Vector2.new(0.5, 0.5)
	burst.Position = UDim2.fromScale(0.5, 0.5)
	burst.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	burst.ZIndex = 0
	burst.Parent = frame
	local title: Title = { Frame = frame, Scale = scale, Letters = {}, Rays = {}, Burst = burst, Drips = {}, Sprinkles = {}, Fades = {}, Alpha = -1 }
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
	-- A letter: its pink rim (a thick light outline, furthest back), its solid 3D edge (copies
	-- stepping down and right, in the outline's colour), then the letter itself on top, its colours
	-- running down the capital, with a thick dark outline.
	local function glyph(holder: Frame, ch: string, size: number, colors: { Color3 }, line: Color3, thickness: number)
		local step = Vector2.new(0.011, 0.016) * size
		local function copy(name: string, offset: Vector2, color: Color3, strokeColor: Color3, strokeWidth: number, z: number): TextLabel
			local label = Instance.new("TextLabel")
			label.Name = name
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Position = UDim2.fromOffset(offset.X, offset.Y)
			label.Font = Enum.Font.FredokaOne
			label.Text = ch
			label.TextSize = size
			label.TextColor3 = color
			label.ZIndex = z
			label.Parent = holder
			fade(label, "TextTransparency", 0)
			local stroke = Instance.new("UIStroke")
			stroke.Color = strokeColor
			stroke.Thickness = strokeWidth
			stroke.LineJoinMode = Enum.LineJoinMode.Round
			stroke.Parent = label
			fade(stroke, "Transparency", 0)
			return label
		end
		copy("Rim", step * DEPTH * 0.5, RIM, RIM, thickness * 2.6, 1)
		for k = DEPTH, 1, -1 do
			copy("Extrude", step * k, line, line, thickness, 1)
		end
		local face = copy("Glyph", Vector2.zero, WHITE, line, thickness, 3)
		-- (the colours run down the capital)
		gradient(face, colors, 90, { CAP_TOP, CAP_MID, CAP_BOTTOM })
	end
	local letterCount = 0
	local function letterHolder(name: string, x: number, y: number, w: number, h: number, start: number, spin: boolean): (Frame, Letter)
		letterCount += 1
		local bounce = BOUNCE[letterCount] or { 0, 0 }
		y += bounce[2] * h
		local holder = Instance.new("Frame")
		holder.Name = name
		holder.BackgroundTransparency = 1
		-- (it pops up from the middle of the capital)
		holder.AnchorPoint = Vector2.new(0.5, CAP_MID)
		holder.Position = UDim2.fromOffset(x + w / 2, y + h * CAP_MID)
		holder.Rotation = bounce[1]
		holder.Size = UDim2.fromOffset(w, h)
		-- (DONUT in front: any long drip hangs down behind it)
		holder.ZIndex = if y >= BOTTOM_Y then 3 else 2
		holder.Parent = frame
		local s = Instance.new("UIScale")
		s.Scale = 0
		s.Parent = holder
		local letter: Letter = { Holder = holder, Scale = s, X = x + w / 2, Y = y + h * CAP_MID, Tilt = bounce[1], Start = start, Spin = spin }
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
		widths += if ch == " " then WORD_GAP * TOP_SIZE else GLYPHS[ch].Advance * TOP_SIZE + TOP_GAP
	end
	local x = (WIDTH - widths) / 2
	local order = 0
	local seenA = false
	for _, ch in top do
		if ch == " " then
			x += WORD_GAP * TOP_SIZE
			continue
		end
		local g = GLYPHS[ch]
		local w = g.Advance * TOP_SIZE
		local start = order * 0.07
		order += 1
		local holder = letterHolder("Letter" .. ch, x, TOP_Y, w, TOP_SIZE, start, false)
		glyph(holder, ch, TOP_SIZE, FROSTING, BERRY, 4)
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
		x += w + TOP_GAP
	end

	-- DONUT: baked dough, with a real donut for the O
	local bottom = { "D", "O", "N", "U", "T" }
	local ring = 0.68 * BOTTOM_SIZE
	widths = 0
	for _, ch in bottom do
		widths += (if ch == "O" then ring + 6 else GLYPHS[ch].Advance * BOTTOM_SIZE) + BOTTOM_GAP
	end
	x = (WIDTH - widths) / 2
	order = 0
	for _, ch in bottom do
		local start = 0.45 + order * 0.07
		order += 1
		if ch == "O" then
			local w = ring + 6
			local holder = letterHolder("DonutO", x, BOTTOM_Y, w, BOTTOM_SIZE, start, true)
			local cx, cy = w / 2, BOTTOM_SIZE * CAP_MID
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
			-- (its rim and 3D edge, like the letters)
			local step = Vector2.new(0.011, 0.016) * BOTTOM_SIZE
			local rim = ringOf("RingRim", hole - 13, band + 13, RIM, 1)
			rim.Position = UDim2.fromOffset(cx + step.X * DEPTH * 0.5, cy + step.Y * DEPTH * 0.5)
			for k = DEPTH, 1, -1 do
				local edge = ringOf("RingEdge", hole - 5, band + 5, CRUST, 1)
				edge.Position = UDim2.fromOffset(cx + step.X * k, cy + step.Y * k)
			end
			ringOf("RingLine", hole - 5, band + 5, CRUST, 2)
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
			x += w + BOTTOM_GAP
		else
			local w = GLYPHS[ch].Advance * BOTTOM_SIZE
			local holder = letterHolder("Letter" .. ch, x, BOTTOM_Y, w, BOTTOM_SIZE, start, false)
			glyph(holder, ch, BOTTOM_SIZE, DOUGH, CRUST, 5)
			x += w + BOTTOM_GAP
		end
	end
	-- The burst behind it: soft rays of light from its middle (bars through the middle, each one
	-- two rays), popping out once the letters have landed and turning slowly
	local burstScale = Instance.new("UIScale")
	burstScale.Scale = 0
	burstScale.Parent = burst
	for i = 1, 9 do
		local bar = block("Ray", if i % 2 == 0 then rgb(255, 214, 236) else WHITE, 0, burst)
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.fromOffset(WIDTH * 1.3, if i % 2 == 0 then 20 else 30)
		bar.Rotation = (i - 1) * 20
		corner(bar, UDim.new(0.5, 0))
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.22, 0.55),
			NumberSequenceKeypoint.new(0.5, 0.3),
			NumberSequenceKeypoint.new(0.78, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = bar
		title.Fades[#title.Fades].Base = 0.45
		bar.BackgroundTransparency = 0.45
		table.insert(title.Rays, { Bar = bar, Angle = bar.Rotation })
	end
	frame.Parent = parent
	return title
end

local function smooth(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * a * (a * (a * 6 - 15) + 10)
end
local function backOut(u: number, c: number?): number
	u = math.clamp(u, 0, 1)
	local k = c or 1.70158
	return 1 + (k + 1) * (u - 1) ^ 3 + k * (u - 1) ^ 2
end

-- A letter slamming onto the screen: it drops in big (1.9x) and fast, squashes a little small
-- as it lands, then bounces back to size. 0 before it starts.
local SLAM = 0.16 -- (seconds to land)
local SETTLE = 0.34 -- (seconds to bounce back)
local function slam(t: number): number
	if t < 0 then
		return 0
	elseif t < SLAM then
		local u = t / SLAM
		return 1.9 + (0.84 - 1.9) * u * u
	end
	return 0.84 + 0.16 * backOut((t - SLAM) / SETTLE, 3)
end

function DonutTitle.Step(title: Title, now: number, start: number, alpha: number, viewport: Vector2, grow: number)
	local t = now - start
	title.Frame.Visible = alpha > 0.002 and t > 0
	if not title.Frame.Visible then
		return
	end
	-- fits about 60% of the screen's width, 40% of its height (whichever is smaller)
	local fit = math.min(viewport.X * 0.6 / WIDTH, viewport.Y * 0.4 / HEIGHT)
	title.Frame.Rotation = -3 + math.sin(now * 1.7) * 1.2
	local landed = 0
	for i, letter in title.Letters do
		local lt = t - letter.Start
		letter.Scale.Scale = slam(lt)
		local u = smooth(lt / SLAM)
		local settle = smooth((lt - SLAM) / SETTLE)
		-- (drops in from above, swinging into its tilt from the other side)
		letter.Holder.Position = UDim2.fromOffset(letter.X, letter.Y - (1 - u) * 34)
		local swing = (if i % 2 == 0 then 1 else -1) * 16 * (1 - settle)
		letter.Holder.Rotation = letter.Tilt + swing + (if letter.Spin then -240 * (1 - u) else 0)
		landed = math.max(landed, letter.Start + SLAM + SETTLE)
	end
	-- once they've all landed, the whole title punches out once and the burst pops behind it
	local punch = t - landed + SETTLE * 0.5
	local pulse = if punch > 0 and punch < 0.36 then math.sin(punch / 0.36 * math.pi) * 0.09 else 0
	title.Scale.Scale = fit * grow * (1 + pulse)
	local burstScale = title.Burst:FindFirstChildOfClass("UIScale")
	if burstScale then
		burstScale.Scale = backOut(punch / 0.45, 2.2) * (1 + 0.04 * math.sin(now * 2.3))
	end
	title.Burst.Rotation = now * 9
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
