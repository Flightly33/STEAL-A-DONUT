--[[
	DonutLayers
	===========
	The layers DonutModel puts on top of a donut's glaze, from its look (DonutLooks):

	  * Drips: tongues of glaze with a drop at the end, hanging over the outer edge ("Drippy"), or
	    running down from the edge of a half-dipped donut's glaze ("HalfDip").
	  * Shine: light dashes on the raised glaze, beside the soft gloss.
	  * Markings from the name: drizzle, stripes, spots, lightning bolts, flames, runes, hearts,
	    scales, swirls or stars. On Legendary and up they glow.
	  * Trims on the rarer donuts: a string of beads round the glaze (Epic: pearls, Legendary: gold,
	    Celestial and up: glowing in the rarity's colour) and a gem on the front (Legendary and up).
	  * A champion's belt on the strongest donuts (Maximus, Supremus, Odin, Zeus...).

	Built with DonutModel's Kit (DonutExtras.Kit): unscaled numbers in the donut's own space,
	-Z = front, the ring in the XY plane. Drips are named "Frosting" so the client's colour effects
	(rainbow, galaxy) paint them with the rest of the glaze.
]]

local DonutExtras = require(script.Parent.DonutExtras)
local DonutLooks = require(script.Parent.DonutLooks)

type Kit = DonutExtras.Kit
type Look = DonutLooks.Look

export type Info = {
	Accent: Color3, -- the second colour (drizzle, markings)
	Crown: Color3, -- the raised middle of the glaze
	Material: Enum.Material, -- the glaze's material
	ShoulderFront: number, -- how far in front the glaze's two layers stand (-Z)
	CrownFront: number,
	HalfDip: number, -- sin(angle) where a half-dipped donut's glaze ends
	Square: boolean, -- a square brick donut (DonutModel makes its drips itself, cell by cell)
	Glow: Color3, -- the rarity's (or mutation's) colour
	NoEffects: boolean,
	NoFace: boolean,
}

local DonutLayers = {}

local rgb = Color3.fromRGB
local WHITE = rgb(255, 255, 255)
local BLACK = Color3.new(0, 0, 0)
local NEON = Enum.Material.Neon
local TAU = math.pi * 2
local FACE = math.pi / 2 -- the face is at the top of the ring

local function awayFromFace(angle: number, margin: number): boolean
	local d = math.abs(((angle - FACE + math.pi) % TAU) - math.pi)
	return d > margin
end

-- A drip of glaze hanging from (x, yTop): a tongue `length` long and a drop at its end.
local function drip(k: Kit, info: Info, x: number, yTop: number, length: number, width: number, z: number, color: Color3): (BasePart, BasePart)
	local tongue = k.block(Vector3.new(width, length, 0.22), color, k.at(x, yTop - length / 2, z), info.Material, "Frosting")
	local bead = k.ball(width * 1.35, color, k.at(x, yTop - length - width * 0.3, z), info.Material, "Frosting")
	tongue.Reflectance = 0.15
	bead.Reflectance = 0.15
	return tongue, bead
end

local function drips(k: Kit, look: Look, info: Info)
	local color = k.Frosting
	local z = info.ShoulderFront - 0.06
	local outer = k.R + k.FROST_R - 0.06
	if look.Glaze == "HalfDip" then
		-- running down from where the glaze stops, on both sides
		local stop = math.asin(info.HalfDip)
		for _, base in { stop - 0.2, math.pi - stop + 0.2 } do
			for i, r in { 1.15, 1.85 } do
				local length = if i == 1 then k.Rng:NextNumber(0.5, 0.75) else k.Rng:NextNumber(0.25, 0.4)
				drip(k, info, r * math.cos(base), r * math.sin(base) + 0.06, length, 0.24, z, color)
			end
		end
		return
	end
	-- hanging off the bottom edge (shorter beside the legs)
	for _, degrees in { 205, 232, 308, 335 } do
		local angle = math.rad(degrees + k.Rng:NextNumber(-4, 4))
		local x, y = outer * math.cos(angle), outer * math.sin(angle)
		local length = k.Rng:NextNumber(0.45, 0.95)
		if math.abs(x) > 0.25 and math.abs(x) < 0.9 and y < -1.5 then
			length = math.min(length, 0.5) -- (beside a leg)
		end
		drip(k, info, x, y + 0.08, length, 0.24, z, color)
	end
end

-- Light dashes on the raised glaze: the glossy highlight.
local function shine(k: Kit, look: Look, info: Info)
	local light = info.Crown:Lerp(WHITE, 0.6)
	for i, degrees in { 160, 176, 189 } do
		if look.Glaze == "HalfDip" and math.sin(math.rad(degrees)) < info.HalfDip + 0.1 then
			continue
		end
		local angle = math.rad(degrees)
		local cf = k.onGlaze(angle, -0.18, 0.01) * CFrame.Angles(0, 0, if info.Square then math.pi / 2 else angle + math.pi / 2)
		k.block(Vector3.new(if i == 2 then 0.42 else 0.2, 0.1, 0.04), light, cf, nil, "Shine")
	end
end

-- Spots on the glaze for a pattern (away from the face, on the glaze of a half-dipped donut).
local function spots(k: Kit, look: Look, info: Info, count: number, from: number, to: number): { number }
	local list = {}
	for i = 0, count - 1 do
		local angle = math.rad(from + (to - from) * (i + 0.5) / count + k.Rng:NextNumber(-5, 5))
		if awayFromFace(angle, 0.8) and (look.Glaze ~= "HalfDip" or math.sin(angle) > info.HalfDip + 0.15) then
			table.insert(list, angle)
		end
	end
	return list
end

local Markings: { [string]: (k: Kit, look: Look, info: Info, color: Color3, material: Enum.Material?) -> () } = {}

function Markings.Drizzle(k, look, info, color, material)
	for i, angle in spots(k, look, info, 14, -170, 170) do
		local cf = k.onGlaze(angle, 0, 0.012) * CFrame.Angles(0, 0, angle + (if i % 2 == 0 then 0.6 else -0.6))
		k.block(Vector3.new(0.82, 0.07, 0.04), color, cf, material, "Drizzle")
	end
end

function Markings.Stripes(k, look, info, color, material)
	local dark = if material then color else k.Frosting:Lerp(BLACK, 0.6)
	for i, angle in spots(k, look, info, 12, -165, 165) do
		local cf = k.onGlaze(angle, (if i % 2 == 0 then 0.25 else -0.25), 0.012) * CFrame.Angles(0, 0, angle + 0.2)
		k.block(Vector3.new(if i % 2 == 0 then 0.7 else 0.5, 0.12, 0.04), dark, cf, material, "Stripe")
	end
end

function Markings.Spots(k, look, info, color, material)
	local spot = if material then color elseif (k.Frosting.R + k.Frosting.G + k.Frosting.B) > 1.8 then rgb(45, 35, 35) else WHITE
	for i, angle in spots(k, look, info, 8, -165, 165) do
		local cf = k.onGlaze(angle, k.Rng:NextNumber(-0.6, 0.6), 0.012) * CFrame.Angles(0, 0, k.Rng:NextNumber(0, TAU))
		local size = if i % 3 == 0 then 0.42 else 0.3
		k.block(Vector3.new(size, size * 0.8, 0.04), spot, cf, material, "Spot")
	end
end

function Markings.Bolts(k, look, info, _color, material)
	local yellow = rgb(255, 230, 60)
	for _, angle in spots(k, look, info, 4, -160, 160) do
		local base = k.onGlaze(angle, 0, 0.015) * CFrame.Angles(0, 0, angle)
		-- a zigzag: three short strokes across the glaze
		for j, step in { { -0.2, 0.5 }, { 0, -0.5 }, { 0.2, 0.5 } } do
			local cf = base * CFrame.new(step[1] * k.s, (j - 2) * 0.05 * k.s, 0) * CFrame.Angles(0, 0, step[2])
			k.block(Vector3.new(0.26, 0.08, 0.04), yellow, cf, material or NEON, "Bolt")
		end
	end
end

function Markings.Flames(k, look, info, _color, material)
	for _, angle in spots(k, look, info, 5, -150, -30) do
		-- licking up from the bottom edge towards the hole
		local radial = Vector3.new(math.cos(angle), math.sin(angle), 0)
		local function at(r: number): CFrame
			local p = radial * r
			return k.face(p.X, p.Y, 0.012) * CFrame.Angles(0, 0, angle + math.pi / 2)
		end
		k.block(Vector3.new(0.3, 0.38, 0.04), rgb(255, 110, 30), at(k.R + 0.18), material, "Flame")
		k.block(Vector3.new(0.15, 0.34, 0.045), rgb(255, 220, 80), at(k.R - 0.14) * CFrame.Angles(0, 0, k.Rng:NextNumber(-0.3, 0.3)), material, "Flame")
	end
end

function Markings.Runes(k, look, info, color, material)
	local glow = if material then rgb(120, 230, 255) else color
	for _, angle in spots(k, look, info, 4, -160, 160) do
		local base = k.onGlaze(angle, 0, 0.012) * CFrame.Angles(0, 0, angle)
		-- a stem and two strokes off it, like an old rune
		k.block(Vector3.new(0.5, 0.06, 0.04), glow, base, material, "Rune")
		k.block(Vector3.new(0.26, 0.06, 0.04), glow, base * CFrame.new(0.06 * k.s, 0.1 * k.s, 0) * CFrame.Angles(0, 0, 0.7), material, "Rune")
		k.block(Vector3.new(0.26, 0.06, 0.04), glow, base * CFrame.new(-0.1 * k.s, 0.1 * k.s, 0) * CFrame.Angles(0, 0, 0.7), material, "Rune")
	end
end

local function heart(k: Kit, cf: CFrame, size: number, color: Color3, material: Enum.Material?, name: string)
	local lobe = size * 0.42
	for _, side in { -1, 1 } do
		k.block(Vector3.new(lobe, lobe, 0.04), color, cf * CFrame.new(side * size * 0.2 * k.s, size * 0.16 * k.s, 0) * CFrame.Angles(0, 0, math.rad(45)), material, name)
	end
	k.block(Vector3.new(size * 0.52, size * 0.52, 0.04), color, cf * CFrame.new(0, -size * 0.1 * k.s, 0) * CFrame.Angles(0, 0, math.rad(45)), material, name)
end

function Markings.Hearts(k, look, info, _color, material)
	for i, angle in spots(k, look, info, 5, -160, 160) do
		heart(k, k.onGlaze(angle, k.Rng:NextNumber(-0.4, 0.4), 0.012), 0.36, if i % 2 == 0 then rgb(255, 80, 130) else rgb(255, 160, 200), material, "Heart")
	end
end

function Markings.Scales(k, look, _info, _color, material)
	-- overlapping plates down the outer sides of the dough, like a dragon's
	local plate = k.Frosting:Lerp(BLACK, 0.25)
	local half = k.BALL / 2
	for i = 0, 6 do
		local angle = math.rad(200 + i * 23.3)
		local radial = Vector3.new(math.cos(angle), math.sin(angle), 0)
		local tangent = Vector3.new(-radial.Y, radial.X, 0)
		for row, zz in { -0.35, 0.15 } do
			local point = radial * (k.R + half + 0.03) + Vector3.new(0, 0, zz)
			local cf = CFrame.fromMatrix(point * k.s, tangent, radial, -Vector3.zAxis) * CFrame.Angles(math.rad(-18), 0, 0)
			k.block(Vector3.new(0.42, 0.08, 0.44), if (i + row) % 2 == 0 then plate else plate:Lerp(WHITE, 0.15), cf, material, "Scale")
		end
	end
	local _ = look
end

function Markings.Swirls(k, look, info, color, material)
	for _, angle in spots(k, look, info, 3, -150, 150) do
		local center = k.onGlaze(angle, 0, 0.014)
		-- a curl: an arc winding in to a dot
		local points = {}
		for j = 0, 4 do
			local t = j / 4 * math.pi * 1.6
			local r = 0.32 - j * 0.06
			table.insert(points, Vector3.new(math.cos(t + angle) * r, math.sin(t + angle) * r, 0))
		end
		for j = 1, #points - 1 do
			local a, b = points[j], points[j + 1]
			local along = b - a
			local cf = center * CFrame.new((a + b) / 2 * k.s) * CFrame.Angles(0, 0, math.atan2(along.Y, along.X))
			k.block(Vector3.new(along.Magnitude + 0.06, 0.07, 0.04), color, cf, material, "Swirl")
		end
		k.ball(0.12, color, center * CFrame.new(points[#points] * k.s), material, "Swirl")
	end
end

function Markings.Stars(k, look, info, _color, material)
	for i, angle in spots(k, look, info, 5, -160, 160) do
		local cf = k.onGlaze(angle, k.Rng:NextNumber(-0.4, 0.4), 0.012) * CFrame.Angles(0, 0, math.rad(45 * (i % 2)))
		local color = if i % 2 == 0 then rgb(255, 235, 120) else WHITE
		k.block(Vector3.new(0.07, 0.34, 0.04), color, cf, material or NEON, "Star")
		k.block(Vector3.new(0.34, 0.07, 0.04), color, cf, material or NEON, "Star")
	end
end

-- A string of beads round the outside of the glaze (Epic and up).
local function beads(k: Kit, info: Info)
	local order = k.RarityOrder
	local color, material = rgb(245, 240, 235), Enum.Material.SmoothPlastic -- pearls
	if order >= 6 then
		color, material = info.Glow:Lerp(WHITE, 0.35), NEON
	elseif order >= 5 then
		color, material = rgb(255, 200, 60), Enum.Material.Foil
	end
	local radius = k.R + k.FROST_R - 0.04
	for i = 0, 11 do
		local angle = math.rad(15 + i * 30)
		if awayFromFace(angle, math.rad(35)) then
			-- (square: along the glaze's outer cells)
			local cf = if info.Square then k.onGlaze(angle, 1.25, 0.05) else k.at(math.cos(angle) * radius, math.sin(angle) * radius, info.ShoulderFront - 0.05)
			local bead = k.ball(0.18, color, cf, material, "Bead")
			bead.Reflectance = 0.25
		end
	end
end

-- A big gem set in gold on the front (Legendary and up).
local function gem(k: Kit, info: Info)
	local cf = k.onGlaze(-math.pi / 2, 0, 0.03) * CFrame.Angles(0, 0, math.rad(45))
	k.block(Vector3.new(0.44, 0.44, 0.06), rgb(255, 200, 60), cf, Enum.Material.Foil, "GemSetting")
	k.block(Vector3.new(0.3, 0.3, 0.1), info.Glow:Lerp(WHITE, 0.15), cf * CFrame.new(0, 0, -0.03 * k.s), NEON, "Gem")
end

-- A champion's belt across the bottom of the ring: red straps, a gold plate and a gem.
local function belt(k: Kit, info: Info)
	for _, degrees in { 238, 302 } do
		local angle = math.rad(degrees)
		k.block(Vector3.new(0.86, 0.62, 0.05), rgb(200, 30, 40), k.onGlaze(angle, 0, 0.012) * CFrame.Angles(0, 0, angle + math.pi / 2), nil, "Belt")
	end
	local plate = k.onGlaze(-math.pi / 2, 0, 0.03)
	k.block(Vector3.new(0.9, 0.66, 0.08), rgb(255, 200, 60), plate, Enum.Material.Foil, "BeltPlate")
	k.block(Vector3.new(0.7, 0.46, 0.09), rgb(255, 225, 120), plate * CFrame.new(0, 0, -0.02 * k.s), Enum.Material.Foil, "BeltPlate")
	k.block(Vector3.new(0.24, 0.24, 0.1), info.Glow, plate * CFrame.new(0, 0, -0.05 * k.s) * CFrame.Angles(0, 0, math.rad(45)), NEON, "Gem")
	for _, side in { -1, 1 } do
		k.ball(0.12, rgb(255, 230, 140), plate * CFrame.new(side * 0.36 * k.s, 0, -0.04 * k.s), Enum.Material.Foil, "BeltStud")
	end
end

function DonutLayers.Build(k: Kit, look: Look, info: Info)
	if (look.Glaze == "Drippy" or look.Glaze == "HalfDip") and not info.Square then
		drips(k, look, info)
	end
	shine(k, look, info)
	if info.NoFace then
		return
	end
	local marking = look.Marking
	if marking and Markings[marking] then
		local material = if look.MarkGlow then NEON else nil
		local color = if look.MarkGlow then info.Accent:Lerp(WHITE, 0.25) else info.Accent
		Markings[marking](k, look, info, color, material)
	end
	if k.RarityOrder >= 4 then
		beads(k, info)
	end
	if look.Muscles >= 2 then
		belt(k, info)
	elseif k.RarityOrder >= 5 then
		gem(k, info)
	end
end

return DonutLayers
