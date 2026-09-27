--[[
	Every donut in the game.

	Area     -> which area it spawns in (see Areas.luau)
	Weight   -> spawn chance relative to the other donuts in the same area
	Income   -> money per second at level 1
	Dough / Frosting / Sprinkles -> colours used by DonutModel
	Parts    -> brainrot accessories (see DonutModel.Accessories for the full list)

	To add a donut: copy a line, give it a unique Id, pick an area/rarity/income. That's it:
	the Index, leaderboards, spawns and podium all pick it up automatically.
]]

local Rarities = require(script.Parent.Rarities)

export type Donut = {
	Id: string,
	Name: string,
	Rarity: string,
	Area: number,
	Income: number,
	Weight: number,
	Dough: Color3,
	Frosting: Color3,
	Sprinkles: { Color3 }?,
	Parts: { string },
	Score: number,
	Index: number,
}

local rgb = Color3.fromRGB

local DOUGH = rgb(222, 165, 95)
local DARK_DOUGH = rgb(120, 70, 40)
local RAINBOW = { rgb(255, 60, 60), rgb(255, 200, 0), rgb(60, 220, 90), rgb(40, 150, 255), rgb(200, 80, 255), rgb(255, 255, 255) }
local WHITE = { rgb(255, 255, 255) }
local BLACK = { rgb(25, 25, 25) }
local GOLD = { rgb(255, 215, 60), rgb(255, 245, 170) }
local STARS = { rgb(255, 255, 255), rgb(255, 240, 150), rgb(160, 220, 255) }
local EMBERS = { rgb(255, 200, 0), rgb(255, 80, 0), rgb(40, 30, 30) }
local NEON = { rgb(0, 255, 200), rgb(255, 0, 200), rgb(255, 255, 0) }

local function D(id: string, name: string, rarity: string, area: number, income: number, weight: number, dough: Color3, frosting: Color3, sprinkles: { Color3 }?, parts: { string })
	return {
		Id = id, Name = name, Rarity = rarity, Area = area, Income = income, Weight = weight,
		Dough = dough, Frosting = frosting, Sprinkles = sprinkles, Parts = parts,
		Score = 0, Index = 0,
	}
end

local Donuts = {}

Donuts.List = {
	-- 1. Glazed Meadow
	D("glazino", "Plain Glazino", "Common", 1, 1, 42, DOUGH, rgb(255, 236, 200), nil, { "Legs" }),
	D("sugarino", "Sugarino Dunkarino", "Common", 1, 2, 28, DOUGH, rgb(250, 250, 250), nil, { "Legs", "Arms" }),
	D("tungglazur", "Tung Tung Glazur", "Uncommon", 1, 4, 17, DOUGH, rgb(125, 75, 45), nil, { "Legs", "Bat" }),
	D("sprinkolini", "Sprinkolini Pinkolini", "Uncommon", 1, 7, 10, DOUGH, rgb(255, 150, 200), RAINBOW, { "Legs", "Arms" }),
	D("glazzerina", "Glazzerina Ballerina", "Rare", 1, 15, 3, DOUGH, rgb(255, 200, 230), WHITE, { "Legs", "Tutu" }),

	-- 2. Sprinkle Park
	D("crullero", "Crullero Crullala", "Common", 2, 6, 42, DOUGH, rgb(240, 190, 100), nil, { "Legs", "Mustache" }),
	D("kremelino", "Boston Kremelino", "Uncommon", 2, 11, 28, DOUGH, rgb(110, 65, 40), nil, { "Legs", "TopHat" }),
	D("sahursprinkle", "Sahur Sprinkle Sahur", "Uncommon", 2, 21, 17, DOUGH, rgb(255, 255, 255), RAINBOW, { "Legs", "Arms", "Bat" }),
	D("jellyfillo", "Jellyfillo Jellyfilla", "Rare", 2, 42, 10, DOUGH, rgb(220, 40, 60), WHITE, { "Legs", "Sunglasses" }),
	D("patadonut", "Brr Brr Patadonut", "Epic", 2, 90, 3, DOUGH, rgb(110, 200, 90), RAINBOW, { "Legs", "Arms", "Mustache" }),

	-- 3. Sugar Dunes
	D("cinnamonio", "Cinnamonio Camelino", "Uncommon", 3, 36, 42, rgb(190, 120, 60), rgb(240, 222, 190), nil, { "Legs", "Camel" }),
	D("frigocamel", "Frigo Cameldonut", "Rare", 3, 65, 28, DOUGH, rgb(170, 220, 255), WHITE, { "Legs", "Arms", "Camel" }),
	D("lirililarila", "Lirili Larila Glaze", "Rare", 3, 126, 17, DOUGH, rgb(100, 200, 80), WHITE, { "Legs", "Sunglasses" }),
	D("tradonut", "Tralalero Tradonut", "Epic", 3, 252, 10, DOUGH, rgb(40, 140, 255), WHITE, { "Legs", "SharkFin" }),
	D("glazamun", "Pharaoh Glazamun", "Legendary", 3, 540, 3, DOUGH, rgb(255, 200, 40), { rgb(40, 80, 200) }, { "Legs", "Pharaoh" }),

	-- 4. Frosting Falls
	D("strawberrini", "Strawberrini Frostini", "Rare", 4, 220, 42, DOUGH, rgb(255, 100, 140), WHITE, { "Legs" }),
	D("cappuccino", "Cappuccino Donutino", "Rare", 4, 390, 28, rgb(150, 100, 60), rgb(200, 150, 110), nil, { "Legs", "CoffeeCup" }),
	D("chimpanzini", "Chimpanzini Glazanini", "Epic", 4, 760, 17, DOUGH, rgb(255, 230, 90), nil, { "Legs", "Arms", "MonkeyEars" }),
	D("lavaca", "La Vaca Sprinkla Sprinkla", "Legendary", 4, 1_500, 10, DOUGH, rgb(255, 255, 255), BLACK, { "Legs", "Horns" }),
	D("bombardonut", "Bombardonut Crocodonut", "Mythic", 4, 3_250, 3, DOUGH, rgb(60, 140, 60), { rgb(40, 90, 40) }, { "PlaneWings", "Sunglasses" }),

	-- 5. Chocolate Caverns
	D("chocolatto", "Chocolatto Cavernino", "Rare", 5, 1_300, 42, DARK_DOUGH, rgb(90, 50, 30), nil, { "Legs", "Arms" }),
	D("trippitroppi", "Trippi Troppi Cocoa", "Epic", 5, 2_350, 28, DARK_DOUGH, rgb(150, 95, 60), WHITE, { "Legs", "Mustache" }),
	D("bobrito", "Bobrito Bandonuto", "Epic", 5, 4_550, 17, DARK_DOUGH, rgb(60, 40, 30), GOLD, { "Legs", "Sunglasses", "Cape" }),
	D("fudgeroni", "Fudgeroni Fudgerona", "Legendary", 5, 9_100, 10, DARK_DOUGH, rgb(80, 45, 25), GOLD, { "Legs", "Crown" }),
	D("tungfudgur", "Tung Tung Tung Fudgur", "Mythic", 5, 19_500, 3, DARK_DOUGH, rgb(65, 35, 20), GOLD, { "Legs", "Arms", "Bat", "Horns" }),

	-- 6. Glacier Glaze
	D("frostaroni", "Frostaroni Frostarini", "Epic", 6, 7_800, 42, DOUGH, rgb(170, 220, 255), WHITE, { "Legs", "IceSpikes" }),
	D("pinguino", "Pinguino Glazino", "Epic", 6, 14_000, 28, DOUGH, rgb(35, 35, 45), WHITE, { "Legs", "Beak" }),
	D("icicladonut", "Brr Brr Icicladonut", "Legendary", 6, 27_000, 17, DOUGH, rgb(120, 230, 255), WHITE, { "Legs", "Arms", "IceSpikes" }),
	D("yetisprinkletti", "Yeti Sprinkletti", "Mythic", 6, 55_000, 10, rgb(240, 240, 250), rgb(245, 250, 255), { rgb(120, 200, 255) }, { "Legs", "Arms", "Horns" }),
	D("glacierino", "Glacierino Divinino", "Divine", 6, 117_000, 3, DOUGH, rgb(200, 255, 255), WHITE, { "Legs", "Wings", "Halo" }),

	-- 7. Molten Bakery
	D("lavaccino", "Lavaccino Lavaccina", "Epic", 7, 47_000, 42, rgb(60, 40, 35), rgb(255, 120, 30), EMBERS, { "Legs", "Flames" }),
	D("magmarino", "Magmarino Glazerino", "Legendary", 7, 84_000, 28, rgb(60, 40, 35), rgb(255, 70, 20), BLACK, { "Legs", "Horns" }),
	D("flambino", "Bombardiro Flambino", "Legendary", 7, 163_000, 17, rgb(50, 40, 40), rgb(60, 50, 50), EMBERS, { "PlaneWings", "Flames" }),
	D("infernolo", "Infernolo Donutolo", "Mythic", 7, 327_000, 10, rgb(50, 30, 30), rgb(255, 40, 0), EMBERS, { "Legs", "Horns", "Flames", "Cape" }),
	D("dragonini", "Dragonini Crullerini", "Divine", 7, 700_000, 3, rgb(90, 30, 20), rgb(255, 160, 0), EMBERS, { "Legs", "Wings", "Horns", "Flames" }),

	-- 8. Neon Donut City
	D("neonino", "Neonino Glowzino", "Legendary", 8, 280_000, 42, rgb(30, 30, 40), rgb(0, 255, 120), NEON, { "Legs", "Visor" }),
	D("cyberino", "Cyberino Sprinklino", "Legendary", 8, 504_000, 28, rgb(30, 30, 40), rgb(0, 220, 255), NEON, { "Legs", "Visor", "Antenna" }),
	D("glitchero", "Glitchero Glitcheri", "Mythic", 8, 980_000, 17, rgb(30, 30, 40), rgb(255, 0, 200), NEON, { "Legs", "Arms", "Visor" }),
	D("robodunkaroni", "Robo Dunkaroni", "Mythic", 8, 1_960_000, 10, rgb(150, 150, 160), rgb(210, 210, 220), NEON, { "Legs", "Arms", "Antenna" }),
	D("hologlazolo", "Holo Holo Glazolo", "Divine", 8, 4_200_000, 3, rgb(40, 40, 60), rgb(150, 255, 255), NEON, { "Visor", "Wings", "Halo" }),

	-- 9. Crystal Cosmos
	D("amethystino", "Amethystino Donutino", "Mythic", 9, 1_680_000, 42, rgb(70, 40, 110), rgb(160, 90, 255), WHITE, { "Legs", "IceSpikes" }),
	D("crystallo", "Crystallo Crullero", "Mythic", 9, 3_000_000, 28, rgb(70, 40, 110), rgb(120, 200, 255), WHITE, { "Legs", "Crown" }),
	D("prismarino", "Prismarino Prismarina", "Divine", 9, 5_900_000, 17, rgb(90, 60, 140), rgb(255, 200, 255), RAINBOW, { "Wings", "Halo" }),
	D("stardustino", "Stardustino Sprinkolo", "Divine", 9, 11_800_000, 10, rgb(30, 20, 60), rgb(40, 20, 80), STARS, { "Legs", "Orbit" }),
	D("nebulini", "Nebulini Glazolini", "Celestial", 9, 25_000_000, 3, rgb(40, 20, 70), rgb(255, 100, 220), STARS, { "Wings", "Halo", "Orbit" }),
	D("grandeglazzarino", "La Grande Glazzarino", "Secret", 9, 100_000_000, 0.3, rgb(20, 20, 20), rgb(255, 255, 255), RAINBOW, { "Crown", "Wings", "Halo", "Orbit" }),

	-- 10. Celestial Donut Dimension
	D("galaxia", "Galaxia Donutia", "Divine", 10, 10_000_000, 42, rgb(20, 20, 60), rgb(40, 40, 160), STARS, { "Legs", "Orbit" }),
	D("cosmotung", "Cosmo Tung Tung Sahur", "Divine", 10, 18_000_000, 28, rgb(20, 20, 60), rgb(90, 60, 200), STARS, { "Legs", "Arms", "Bat", "Halo" }),
	D("supernova", "Supernova Glazanova", "Celestial", 10, 35_000_000, 17, rgb(255, 150, 50), rgb(255, 220, 100), STARS, { "Wings", "Halo", "Flames" }),
	D("odindindin", "Odin Din Din Donut", "Celestial", 10, 70_000_000, 10, rgb(60, 60, 90), rgb(180, 200, 255), GOLD, { "Legs", "Horns", "Crown", "Cape" }),
	D("infinito", "Infinito Glazinfinito", "Celestial", 10, 150_000_000, 3, rgb(20, 10, 40), rgb(255, 255, 255), RAINBOW, { "Wings", "Halo", "Orbit", "Crown" }),
	D("eternaldonut", "The Eternal Donut", "Secret", 10, 600_000_000, 0.5, rgb(10, 10, 10), rgb(255, 255, 255), STARS, { "Wings", "Halo", "Orbit", "Crown" }),
	D("maximus", "Donutus Maximus Supremus", "Secret", 10, 1_500_000_000, 0.15, rgb(255, 215, 0), rgb(255, 255, 255), RAINBOW, { "Wings", "Halo", "Orbit", "Crown", "Cape" }),
} :: { Donut }

Donuts.ById = {} :: { [string]: Donut }
Donuts.ByArea = {} :: { [number]: { Donut } }
Donuts.ByScore = {} :: { [number]: Donut }

for index, donut in Donuts.List do
	assert(Donuts.ById[donut.Id] == nil, "Duplicate donut id: " .. donut.Id)
	assert(Rarities.ById[donut.Rarity], "Unknown rarity on donut " .. donut.Id .. ": " .. donut.Rarity)
	donut.Index = index
	-- Leaderboard score for "rarest donut": rarity first, then its position in the list.
	donut.Score = Rarities.ById[donut.Rarity].Order * 1000 + index
	Donuts.ById[donut.Id] = donut
	Donuts.ByScore[donut.Score] = donut
	Donuts.ByArea[donut.Area] = Donuts.ByArea[donut.Area] or {}
	table.insert(Donuts.ByArea[donut.Area], donut)
end

function Donuts.Get(id: string): Donut?
	return Donuts.ById[id]
end

-- Weighted random donut for an area. `rng` is a Random object.
function Donuts.Roll(areaId: number, rng: Random): Donut
	local pool = Donuts.ByArea[areaId]
	assert(pool and #pool > 0, "No donuts defined for area " .. tostring(areaId))
	local total = 0
	for _, donut in pool do
		total += donut.Weight
	end
	local pick = rng:NextNumber() * total
	for _, donut in pool do
		pick -= donut.Weight
		if pick <= 0 then
			return donut
		end
	end
	return pool[#pool]
end

-- Chance (0-1) of a donut spawning in its area.
function Donuts.Chance(donut: Donut): number
	local total = 0
	for _, other in Donuts.ByArea[donut.Area] do
		total += other.Weight
	end
	return donut.Weight / total
end

return Donuts
