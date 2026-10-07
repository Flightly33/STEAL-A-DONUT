--[[
	IndexThemes: every biome's page section in the Donut Index (UI/Index) gets its own colour
	scheme and a background full of little details that match the biome: sprinkles in Sprinkle
	Park, waves on Frosting Falls, snow on Glacier Glaze, peppermint stripes in Candy Cane Canyon,
	a neon grid on Neon Streets, gears in the Clockwork Void, a starfield and a swirl round The
	Black Hole...

	Everything is drawn with plain UI frames and emoji (nothing to upload). The details sit behind
	the donut cards, faded, so the cards stay easy to read.

	  Palette  - Top / Bottom: the panel's gradient; Accent: its border, header and chips;
	             Card / CardTop: the donut cards; Sky: behind the 3D donuts; Bits: detail colours
	  Pattern  - which background (see PATTERNS below); Icons - emoji scattered over it
]]

local Theme = require(script.Parent.Theme)

local IndexThemes = {}

local rgb = Color3.fromRGB
local WHITE = rgb(255, 255, 255)

export type Palette = {
	Top: Color3,
	Bottom: Color3,
	Accent: Color3,
	Card: Color3,
	CardTop: Color3,
	Sky: Color3,
	Bits: { Color3 },
	Pattern: string,
	Icons: { string },
}

local SPRINKLES = { rgb(255, 90, 120), rgb(255, 220, 70), rgb(90, 200, 255), rgb(255, 255, 255), rgb(140, 230, 110) }

IndexThemes.Palettes = {
	Park = { Top = rgb(86, 170, 74), Bottom = rgb(34, 92, 46), Accent = rgb(255, 150, 210), Card = rgb(30, 70, 40), CardTop = rgb(52, 112, 60), Sky = rgb(150, 210, 255), Bits = SPRINKLES, Pattern = "Sprinkles", Icons = { "🌳", "🌸", "🍩", "🌼", "🦋" } },
	Lake = { Top = rgb(80, 170, 235), Bottom = rgb(150, 70, 140), Accent = rgb(255, 180, 225), Card = rgb(40, 60, 110), CardTop = rgb(70, 100, 165), Sky = rgb(190, 225, 255), Bits = { rgb(255, 255, 255), rgb(255, 170, 215), rgb(170, 230, 255) }, Pattern = "Waves", Icons = { "🌊", "💧", "🦆", "🐟", "🌸" } },
	Desert = { Top = rgb(238, 196, 112), Bottom = rgb(176, 98, 46), Accent = rgb(255, 236, 170), Card = rgb(110, 62, 30), CardTop = rgb(160, 100, 52), Sky = rgb(255, 224, 170), Bits = { rgb(255, 245, 225), rgb(255, 225, 160), rgb(230, 170, 100) }, Pattern = "Dunes", Icons = { "🌵", "☀️", "🐪", "🏜️", "🦂" } },
	Jungle = { Top = rgb(40, 150, 90), Bottom = rgb(16, 66, 48), Accent = rgb(255, 210, 60), Card = rgb(18, 60, 42), CardTop = rgb(36, 104, 66), Sky = rgb(170, 230, 170), Bits = { rgb(255, 80, 100), rgb(255, 205, 50), rgb(90, 210, 100), rgb(170, 100, 255), rgb(255, 150, 50), rgb(70, 180, 255) }, Pattern = "Jellybeans", Icons = { "🌴", "🍃", "🦜", "🐒", "🍌" } },
	Ice = { Top = rgb(150, 215, 250), Bottom = rgb(48, 100, 180), Accent = rgb(225, 245, 255), Card = rgb(36, 70, 130), CardTop = rgb(70, 120, 190), Sky = rgb(225, 240, 255), Bits = { rgb(255, 255, 255), rgb(210, 240, 255) }, Pattern = "Snow", Icons = { "❄️", "⛄", "🐧", "🧊", "🏔️" } },
	Lava = { Top = rgb(250, 120, 40), Bottom = rgb(90, 18, 18), Accent = rgb(255, 210, 90), Card = rgb(70, 22, 18), CardTop = rgb(130, 44, 26), Sky = rgb(255, 190, 140), Bits = { rgb(255, 220, 90), rgb(255, 140, 40), rgb(255, 80, 30) }, Pattern = "Embers", Icons = { "🔥", "🌋", "🥐", "🍞" } },
	Chocolate = { Top = rgb(130, 78, 48), Bottom = rgb(42, 22, 14), Accent = rgb(255, 190, 90), Card = rgb(52, 30, 20), CardTop = rgb(92, 56, 36), Sky = rgb(210, 170, 140), Bits = { rgb(90, 52, 32), rgb(150, 95, 60) }, Pattern = "ChocolateBar", Icons = { "🍫", "🍄", "⛏️", "💎", "🕯️" } },
	Candy = { Top = rgb(232, 60, 84), Bottom = rgb(120, 18, 44), Accent = rgb(255, 255, 255), Card = rgb(96, 18, 40), CardTop = rgb(160, 40, 70), Sky = rgb(255, 210, 225), Bits = { rgb(255, 255, 255), rgb(255, 180, 200) }, Pattern = "Peppermint", Icons = { "🍬", "🍭", "🧁", "🍫", "🍪" } },
	Toys = { Top = rgb(70, 140, 245), Bottom = rgb(36, 50, 150), Accent = rgb(255, 215, 50), Card = rgb(34, 46, 120), CardTop = rgb(60, 90, 190), Sky = rgb(200, 225, 255), Bits = { rgb(235, 60, 60), rgb(255, 205, 50), rgb(70, 190, 90), rgb(255, 140, 40), rgb(170, 90, 230) }, Pattern = "Blocks", Icons = { "🧸", "🚂", "🎲", "🪁", "🎈" } },
	Haunted = { Top = rgb(110, 60, 160), Bottom = rgb(24, 40, 32), Accent = rgb(150, 255, 130), Card = rgb(36, 28, 54), CardTop = rgb(70, 48, 100), Sky = rgb(170, 160, 210), Bits = { rgb(230, 240, 255), rgb(150, 255, 130) }, Pattern = "Mist", Icons = { "👻", "🎃", "🦇", "🕸️", "🕯️" } },
	Clouds = { Top = rgb(140, 200, 255), Bottom = rgb(230, 140, 200), Accent = rgb(255, 255, 255), Card = rgb(70, 90, 160), CardTop = rgb(110, 140, 215), Sky = rgb(235, 245, 255), Bits = { rgb(255, 255, 255), rgb(255, 230, 245) }, Pattern = "Clouds", Icons = { "☁️", "🎈", "🌈", "🧁", "🪁" } },
	CyberStreets = { Top = rgb(30, 24, 70), Bottom = rgb(8, 8, 22), Accent = rgb(0, 230, 255), Card = rgb(16, 16, 40), CardTop = rgb(36, 30, 80), Sky = rgb(40, 30, 80), Bits = { rgb(0, 230, 255), rgb(255, 60, 200), rgb(255, 230, 0) }, Pattern = "NeonGrid", Icons = { "🌃", "💡", "🛹", "🎧" } },
	RobotFactory = { Top = rgb(120, 126, 140), Bottom = rgb(40, 42, 50), Accent = rgb(255, 195, 0), Card = rgb(44, 46, 56), CardTop = rgb(80, 84, 98), Sky = rgb(200, 205, 215), Bits = { rgb(255, 195, 0), rgb(25, 25, 30) }, Pattern = "Hazard", Icons = { "🤖", "⚙️", "🔩", "🏭", "🔧" } },
	Clockwork = { Top = rgb(90, 64, 120), Bottom = rgb(30, 20, 40), Accent = rgb(230, 180, 80), Card = rgb(40, 28, 54), CardTop = rgb(76, 54, 96), Sky = rgb(220, 200, 170), Bits = { rgb(230, 180, 80), rgb(190, 140, 60) }, Pattern = "Gears", Icons = { "⚙️", "🕰️", "⏳", "🔑" } },
	Heaven = { Top = rgb(255, 236, 170), Bottom = rgb(200, 150, 70), Accent = rgb(255, 255, 255), Card = rgb(120, 86, 40), CardTop = rgb(180, 140, 70), Sky = rgb(255, 250, 230), Bits = { rgb(255, 255, 255), rgb(255, 240, 160) }, Pattern = "Glow", Icons = { "✨", "😇", "☁️", "👑", "🌟" } },
	Glitch = { Top = rgb(30, 10, 40), Bottom = rgb(4, 4, 8), Accent = rgb(255, 0, 220), Card = rgb(18, 8, 26), CardTop = rgb(44, 16, 60), Sky = rgb(30, 20, 40), Bits = { rgb(255, 0, 220), rgb(0, 230, 255), rgb(255, 255, 255), rgb(20, 20, 20) }, Pattern = "Pixels", Icons = { "👾", "💾", "⚠️", "📺" } },
	BlackHole = { Top = rgb(40, 20, 80), Bottom = rgb(4, 2, 12), Accent = rgb(190, 120, 255), Card = rgb(18, 10, 38), CardTop = rgb(44, 26, 84), Sky = rgb(14, 8, 30), Bits = { rgb(255, 255, 255), rgb(200, 170, 255), rgb(255, 170, 90) }, Pattern = "Space", Icons = { "🌌", "🪐", "☄️", "⭐", "🛸" } },
} :: { [string]: Palette }

local FALLBACK: Palette = IndexThemes.Palettes.Park

function IndexThemes.Get(theme: string): Palette
	return IndexThemes.Palettes[theme] or FALLBACK
end

--------------------------------------------------------------------------------
-- Drawing helpers (positions are fractions of the panel, so details spread over all of it)
--------------------------------------------------------------------------------
type Ctx = { Parent: Instance, Rng: Random, Palette: Palette }

local function bit(ctx: Ctx): Color3
	local bits = ctx.Palette.Bits
	return bits[ctx.Rng:NextInteger(1, #bits)]
end

local function shape(ctx: Ctx, x: number, y: number, w: number, h: number, color: Color3, transparency: number, corner: number?, rotation: number?): Frame
	local frame = Theme.new("Frame", {
		Name = "Detail",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		Rotation = rotation or 0,
		Parent = ctx.Parent,
	})
	if corner then
		Theme.new("UICorner", { CornerRadius = UDim.new(corner, 0), Parent = frame })
	end
	return frame
end

-- A ring: a circle drawn as its outline only.
local function ring(ctx: Ctx, x: number, y: number, size: number, color: Color3, thickness: number, transparency: number): Frame
	local frame = shape(ctx, x, y, size, size, color, 1, 1)
	Theme.new("UIStroke", { Color = color, Thickness = thickness, Transparency = transparency, Parent = frame })
	return frame
end

-- A band right across the panel at height y (fraction) - for stripes and grid lines.
local function band(ctx: Ctx, y: number, height: number, color: Color3, transparency: number): Frame
	local frame = Theme.new("Frame", {
		Name = "Detail",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, y),
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		Parent = ctx.Parent,
	})
	return frame
end

local function column(ctx: Ctx, x: number, width: number, color: Color3, transparency: number): Frame
	return Theme.new("Frame", {
		Name = "Detail",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(x, 0),
		Size = UDim2.new(0, width, 1, 0),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		Parent = ctx.Parent,
	})
end

local function scatter(ctx: Ctx, count: number, fn: (x: number, y: number) -> ())
	for i = 1, count do
		-- (spread evenly down the panel, randomly across it)
		local y = (i - ctx.Rng:NextNumber(0.1, 0.9)) / count
		fn(ctx.Rng:NextNumber(0.02, 0.98), y)
	end
end

local PATTERNS: { [string]: (Ctx) -> () } = {
	Sprinkles = function(ctx)
		scatter(ctx, 46, function(x, y)
			shape(ctx, x, y, 5, 16, bit(ctx), 0.35, 1, ctx.Rng:NextNumber(0, 180))
		end)
	end,
	Waves = function(ctx)
		for i = 1, 7 do
			local y = i / 8
			for k = 0, 5 do
				local w = 130
				local wave = shape(ctx, (k + (i % 2) * 0.5) / 5, y, w, 34, WHITE, 1, 1)
				Theme.new("UIStroke", { Color = bit(ctx), Thickness = 3, Transparency = 0.65, Parent = wave })
			end
		end
	end,
	Dunes = function(ctx)
		for i = 1, 6 do
			shape(ctx, ctx.Rng:NextNumber(0.1, 0.9), i / 6.5, ctx.Rng:NextNumber(260, 420), 70, rgb(255, 230, 170), 0.82, 1)
		end
		scatter(ctx, 40, function(x, y)
			local s = ctx.Rng:NextNumber(3, 6)
			shape(ctx, x, y, s, s, bit(ctx), 0.4, 0.25, 45)
		end)
	end,
	Jellybeans = function(ctx)
		scatter(ctx, 30, function(x, y)
			shape(ctx, x, y, 26, 14, bit(ctx), 0.45, 1, ctx.Rng:NextNumber(-40, 40))
		end)
	end,
	Snow = function(ctx)
		scatter(ctx, 70, function(x, y)
			local s = ctx.Rng:NextNumber(3, 8)
			shape(ctx, x, y, s, s, bit(ctx), ctx.Rng:NextNumber(0.2, 0.6), 1)
		end)
	end,
	Embers = function(ctx)
		band(ctx, 1, 90, rgb(255, 120, 30), 0.75)
		scatter(ctx, 50, function(x, y)
			local s = ctx.Rng:NextNumber(3, 7)
			local ember = shape(ctx, x, y, s, s, bit(ctx), 0.15, 1)
			Theme.new("UIStroke", { Color = rgb(255, 160, 60), Thickness = 2, Transparency = 0.6, Parent = ember })
		end)
	end,
	ChocolateBar = function(ctx)
		-- a big chocolate bar's squares down the right-hand side, and chocolate chips everywhere else
		for row = 0, 11 do
			for col = 0, 1 do
				shape(ctx, 0.9 + col * 0.06, (row + 0.5) / 12, 46, 46, ctx.Palette.Bits[1], 0.55, 0.15)
			end
		end
		scatter(ctx, 26, function(x, y)
			shape(ctx, x * 0.82, y, 10, 8, ctx.Palette.Bits[2], 0.5, 0.4, ctx.Rng:NextNumber(0, 90))
		end)
	end,
	Peppermint = function(ctx)
		for i = 0, 15 do
			band(ctx, (i + 0.5) / 16, 26, WHITE, if i % 2 == 0 then 0.86 else 1)
		end
		scatter(ctx, 12, function(x, y)
			local swirl = shape(ctx, x, y, 34, 34, WHITE, 0.6, 1)
			Theme.new("UIStroke", { Color = rgb(255, 80, 100), Thickness = 4, Transparency = 0.4, Parent = swirl })
		end)
	end,
	Blocks = function(ctx)
		scatter(ctx, 26, function(x, y)
			local color = bit(ctx)
			local block = shape(ctx, x, y, 34, 26, color, 0.45, 0.12, ctx.Rng:NextNumber(-12, 12))
			for k = 0, 1 do
				local stud = Theme.new("Frame", { Name = "Stud", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.28 + k * 0.44, 0, 0, 1), Size = UDim2.fromOffset(10, 6), BackgroundColor3 = color, BackgroundTransparency = 0.45, BorderSizePixel = 0, Parent = block })
				Theme.new("UICorner", { CornerRadius = UDim.new(0.4, 0), Parent = stud })
			end
		end)
	end,
	Mist = function(ctx)
		scatter(ctx, 16, function(x, y)
			shape(ctx, x, y, ctx.Rng:NextNumber(120, 240), ctx.Rng:NextNumber(40, 80), bit(ctx), 0.9, 1)
		end)
		scatter(ctx, 20, function(x, y)
			local s = ctx.Rng:NextNumber(4, 7)
			local eye = shape(ctx, x, y, s, s, rgb(150, 255, 130), 0.35, 1)
			Theme.new("UIStroke", { Color = rgb(150, 255, 130), Thickness = 2, Transparency = 0.7, Parent = eye })
		end)
	end,
	Clouds = function(ctx)
		scatter(ctx, 14, function(x, y)
			local s = ctx.Rng:NextNumber(40, 70)
			for k = -1, 1 do
				shape(ctx, x, y, s * (if k == 0 then 1.3 else 1), s * (if k == 0 then 1 else 0.8), WHITE, 0.78, 1).Position = UDim2.new(x, k * s * 0.6, y, if k == 0 then -s * 0.15 else 0)
			end
		end)
	end,
	NeonGrid = function(ctx)
		for i = 1, 24 do
			band(ctx, i / 25, 2, ctx.Palette.Bits[(i % 2) + 1], 0.75)
		end
		for i = 1, 11 do
			column(ctx, i / 12, 2, ctx.Palette.Bits[(i % 2) + 1], 0.8)
		end
		scatter(ctx, 18, function(x, y)
			local s = ctx.Rng:NextNumber(5, 9)
			local light = shape(ctx, x, y, s, s, bit(ctx), 0.1, 1)
			Theme.new("UIStroke", { Color = light.BackgroundColor3, Thickness = 3, Transparency = 0.55, Parent = light })
		end)
	end,
	Hazard = function(ctx)
		for _, y in { 0, 1 } do
			for k = 0, 24 do
				shape(ctx, k / 24, y, 22, 22, if k % 2 == 0 then ctx.Palette.Bits[1] else ctx.Palette.Bits[2], 0.15, nil, 45)
			end
		end
		scatter(ctx, 24, function(x, y)
			local bolt = shape(ctx, x, y, 12, 12, rgb(170, 175, 190), 0.5, 1)
			Theme.new("UIStroke", { Color = rgb(60, 62, 72), Thickness = 2, Transparency = 0.5, Parent = bolt })
		end)
	end,
	Gears = function(ctx)
		scatter(ctx, 18, function(x, y)
			local s = ctx.Rng:NextNumber(40, 110)
			ring(ctx, x, y, s, bit(ctx), ctx.Rng:NextNumber(5, 9), 0.6)
			shape(ctx, x, y, s * 0.24, s * 0.24, bit(ctx), 0.55, 1)
		end)
	end,
	Glow = function(ctx)
		-- soft light pouring down from the top, and sparkles
		for i = 1, 5 do
			shape(ctx, 0.5, 0, 160 * i, 160 * i, WHITE, 0.82 + i * 0.03, 1)
		end
		scatter(ctx, 40, function(x, y)
			local s = ctx.Rng:NextNumber(4, 9)
			shape(ctx, x, y, s, s, bit(ctx), 0.25, nil, 45)
		end)
	end,
	Pixels = function(ctx)
		scatter(ctx, 50, function(x, y)
			local w, h = ctx.Rng:NextInteger(1, 5) * 8, ctx.Rng:NextInteger(1, 3) * 8
			local color = bit(ctx)
			shape(ctx, x, y, w, h, color, 0.45)
			-- (a colour-split copy next to it, like a broken screen)
			local split = shape(ctx, x, y, w, h, if color == ctx.Palette.Bits[1] then ctx.Palette.Bits[2] else ctx.Palette.Bits[1], 0.7)
			split.Position = UDim2.new(x, 4, y, 2)
		end)
		for i = 1, 6 do
			band(ctx, ctx.Rng:NextNumber(0.05, 0.95), 3, ctx.Palette.Bits[(i % 2) + 1], 0.6)
		end
	end,
	Space = function(ctx)
		scatter(ctx, 90, function(x, y)
			local s = ctx.Rng:NextNumber(2, 4)
			shape(ctx, x, y, s, s, bit(ctx), ctx.Rng:NextNumber(0, 0.5), 1)
		end)
		-- the black hole in the corner: a dark core in a glowing, tilted swirl
		type Swirl = { Size: number, Color: Color3, Transparency: number }
		local swirls: { Swirl } = {
			{ Size = 260, Color = rgb(255, 170, 90), Transparency = 0.75 },
			{ Size = 200, Color = rgb(200, 120, 255), Transparency = 0.6 },
			{ Size = 150, Color = rgb(255, 210, 150), Transparency = 0.5 },
		}
		for i, info in swirls do
			local swirl = ring(ctx, 0.88, 0.08, info.Size, info.Color, 10 - i * 2, info.Transparency)
			swirl.Size = UDim2.fromOffset(info.Size, info.Size * 0.4)
			swirl.Rotation = -14
		end
		shape(ctx, 0.88, 0.08, 90, 90, rgb(0, 0, 0), 0.05, 1)
	end,
}

-- Fill `backdrop` (a frame filling the biome's panel) with the biome's details. `seed` keeps them
-- the same every time.
function IndexThemes.Decorate(backdrop: Instance, theme: string, seed: number)
	local palette = IndexThemes.Get(theme)
	local ctx: Ctx = { Parent = backdrop, Rng = Random.new(seed), Palette = palette }
	local pattern = PATTERNS[palette.Pattern]
	if pattern then
		pattern(ctx)
	end
	-- big faded emoji down both edges (where the cards don't cover them)
	for i = 1, 14 do
		local left = i % 2 == 0
		local icon = palette.Icons[((i - 1) % #palette.Icons) + 1]
		Theme.new("TextLabel", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(if left then ctx.Rng:NextNumber(0.02, 0.07) else ctx.Rng:NextNumber(0.93, 0.98), (i - 0.5) / 14),
			Size = UDim2.fromOffset(60, 60),
			BackgroundTransparency = 1,
			Text = icon,
			TextSize = ctx.Rng:NextInteger(30, 46),
			TextTransparency = 0.45,
			Rotation = ctx.Rng:NextNumber(-20, 20),
			Font = Enum.Font.GothamBold,
			Parent = backdrop,
		})
	end
end

return IndexThemes
