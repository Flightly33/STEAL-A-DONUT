--[[
	Every donut in the game.

	Area     -> which area it spawns in (see Areas.luau)
	Weight   -> spawn chance relative to the other donuts in the same area
	Income   -> money per second at level 1 (before its mutation and size, see Rarities.luau)
	Dough / Frosting / Sprinkles -> colours used by DonutModel
	Parts    -> brainrot accessories (see DonutModel for the full list)

	Each area has 5 regular donuts weighted 50 / 28 / 14 / 4 / 1 (so the best one is about a 1% spawn),
	a few areas also have a Secret (0.006% - 0.03%), and the last area of each world has an ADMIN donut
	(about 1 in 25,000 spawns). Every spawn can also roll a mutation (Gold, Diamond, Mythic, Divine,
	Rainbow) and a size, which multiply its income.

	To add a donut: copy a line, give it a unique Id, pick an area/rarity/income. That's it:
	the Index, leaderboards, spawns and podium all pick it up automatically.
	Add new donuts at the END of the list: the list position is part of the saved "rarest donut" score.
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
local OCEAN = { rgb(255, 255, 255), rgb(120, 220, 255), rgb(255, 150, 190) }
local SPOOKY = { rgb(140, 255, 120), rgb(170, 90, 255), rgb(255, 140, 30) }
local ADMIN = { rgb(255, 40, 40), rgb(255, 255, 255), rgb(20, 20, 20) }

local function D(id: string, name: string, rarity: string, area: number, income: number, weight: number, dough: Color3, frosting: Color3, sprinkles: { Color3 }?, parts: { string })
	return {
		Id = id, Name = name, Rarity = rarity, Area = area, Income = income, Weight = weight,
		Dough = dough, Frosting = frosting, Sprinkles = sprinkles, Parts = parts,
		Score = 0, Index = 0,
	}
end

local Donuts = {}

Donuts.List = {
	---------------------------------------------------------------- World 1: Donut Land
	-- 1. Glazed Meadow
	D("glazino", "Plain Glazino", "Common", 1, 1, 50, DOUGH, rgb(255, 236, 200), nil, { "Legs" }),
	D("sugarino", "Sugarino Dunkarino", "Common", 1, 2, 28, DOUGH, rgb(250, 250, 250), nil, { "Legs", "Arms" }),
	D("tungglazur", "Tung Tung Glazur", "Uncommon", 1, 4, 14, DOUGH, rgb(125, 75, 45), nil, { "Legs", "Bat" }),
	D("sprinkolini", "Sprinkolini Pinkolini", "Uncommon", 1, 7, 4, DOUGH, rgb(255, 150, 200), RAINBOW, { "Legs", "Arms" }),
	D("glazzerina", "Glazzerina Ballerina", "Rare", 1, 15, 1, DOUGH, rgb(255, 200, 230), WHITE, { "Legs", "Tutu" }),
	-- 2. Sprinkle Park
	D("crullero", "Crullero Crullala", "Common", 2, 6, 50, DOUGH, rgb(240, 190, 100), nil, { "Legs", "Mustache" }),
	D("kremelino", "Boston Kremelino", "Uncommon", 2, 11, 28, DOUGH, rgb(110, 65, 40), nil, { "Legs", "TopHat" }),
	D("sahursprinkle", "Sahur Sprinkle Sahur", "Uncommon", 2, 21, 14, DOUGH, rgb(255, 255, 255), RAINBOW, { "Legs", "Arms", "Bat" }),
	D("jellyfillo", "Jellyfillo Jellyfilla", "Rare", 2, 42, 4, DOUGH, rgb(220, 40, 60), WHITE, { "Legs", "Sunglasses" }),
	D("patadonut", "Brr Brr Patadonut", "Rare", 2, 90, 1, DOUGH, rgb(110, 200, 90), RAINBOW, { "Legs", "Arms", "Mustache" }),
	-- 3. Sugar Dunes
	D("cinnamonio", "Cinnamonio Camelino", "Common", 3, 36, 50, rgb(190, 120, 60), rgb(240, 222, 190), nil, { "Legs", "Camel" }),
	D("frigocamel", "Frigo Cameldonut", "Uncommon", 3, 65, 28, DOUGH, rgb(170, 220, 255), WHITE, { "Legs", "Arms", "Camel" }),
	D("lirililarila", "Lirili Larila Glaze", "Rare", 3, 126, 14, DOUGH, rgb(100, 200, 80), WHITE, { "Legs", "Sunglasses" }),
	D("tradonut", "Tralalero Tradonut", "Rare", 3, 252, 4, DOUGH, rgb(40, 140, 255), WHITE, { "Legs", "SharkFin" }),
	D("glazamun", "Pharaoh Glazamun", "Epic", 3, 540, 1, DOUGH, rgb(255, 200, 40), { rgb(40, 80, 200) }, { "Legs", "Pharaoh" }),
	-- 4. Frosting Falls
	D("strawberrini", "Strawberrini Frostini", "Uncommon", 4, 220, 50, DOUGH, rgb(255, 100, 140), WHITE, { "Legs" }),
	D("cappuccino", "Cappuccino Donutino", "Uncommon", 4, 390, 28, rgb(150, 100, 60), rgb(200, 150, 110), nil, { "Legs", "CoffeeCup" }),
	D("chimpanzini", "Chimpanzini Glazanini", "Rare", 4, 760, 14, DOUGH, rgb(255, 230, 90), nil, { "Legs", "Arms", "MonkeyEars" }),
	D("lavaca", "La Vaca Sprinkla Sprinkla", "Epic", 4, 1_500, 4, DOUGH, rgb(255, 255, 255), BLACK, { "Legs", "Horns" }),
	D("bombardonut", "Bombardonut Crocodonut", "Epic", 4, 3_250, 1, DOUGH, rgb(60, 140, 60), { rgb(40, 90, 40) }, { "PlaneWings", "Sunglasses" }),
	-- 5. Chocolate Caverns
	D("chocolatto", "Chocolatto Cavernino", "Uncommon", 5, 1_300, 50, DARK_DOUGH, rgb(90, 50, 30), nil, { "Legs", "Arms" }),
	D("trippitroppi", "Trippi Troppi Cocoa", "Rare", 5, 2_350, 28, DARK_DOUGH, rgb(150, 95, 60), WHITE, { "Legs", "Mustache" }),
	D("bobrito", "Bobrito Bandonuto", "Rare", 5, 4_550, 14, DARK_DOUGH, rgb(60, 40, 30), GOLD, { "Legs", "Sunglasses", "Cape" }),
	D("fudgeroni", "Fudgeroni Fudgerona", "Epic", 5, 9_100, 4, DARK_DOUGH, rgb(80, 45, 25), GOLD, { "Legs", "Crown" }),
	D("tungfudgur", "Tung Tung Tung Fudgur", "Legendary", 5, 19_500, 1, DARK_DOUGH, rgb(65, 35, 20), GOLD, { "Legs", "Arms", "Bat", "Horns" }),
	-- 6. Glacier Glaze
	D("frostaroni", "Frostaroni Frostarini", "Uncommon", 6, 7_800, 50, DOUGH, rgb(170, 220, 255), WHITE, { "Legs", "IceSpikes" }),
	D("pinguino", "Pinguino Glazino", "Rare", 6, 14_000, 28, DOUGH, rgb(35, 35, 45), WHITE, { "Legs", "Beak" }),
	D("icicladonut", "Brr Brr Icicladonut", "Epic", 6, 27_000, 14, DOUGH, rgb(120, 230, 255), WHITE, { "Legs", "Arms", "IceSpikes" }),
	D("yetisprinkletti", "Yeti Sprinkletti", "Epic", 6, 55_000, 4, rgb(240, 240, 250), rgb(245, 250, 255), { rgb(120, 200, 255) }, { "Legs", "Arms", "Horns" }),
	D("glacierino", "Glacierino Frostino", "Legendary", 6, 117_000, 1, DOUGH, rgb(200, 255, 255), WHITE, { "Legs", "Wings", "Halo" }),
	-- 7. Molten Bakery
	D("lavaccino", "Lavaccino Lavaccina", "Rare", 7, 47_000, 50, rgb(60, 40, 35), rgb(255, 120, 30), EMBERS, { "Legs", "Flames" }),
	D("magmarino", "Magmarino Glazerino", "Rare", 7, 84_000, 28, rgb(60, 40, 35), rgb(255, 70, 20), BLACK, { "Legs", "Horns" }),
	D("flambino", "Bombardiro Flambino", "Epic", 7, 163_000, 14, rgb(50, 40, 40), rgb(60, 50, 50), EMBERS, { "PlaneWings", "Flames" }),
	D("infernolo", "Infernolo Donutolo", "Legendary", 7, 327_000, 4, rgb(50, 30, 30), rgb(255, 40, 0), EMBERS, { "Legs", "Horns", "Flames", "Cape" }),
	D("dragonini", "Dragonini Crullerini", "Legendary", 7, 700_000, 1, rgb(90, 30, 20), rgb(255, 160, 0), EMBERS, { "Legs", "Wings", "Horns", "Flames" }),
	-- 8. Neon Donut City
	D("neonino", "Neonino Glowzino", "Rare", 8, 280_000, 50, rgb(30, 30, 40), rgb(0, 255, 120), NEON, { "Legs", "Visor" }),
	D("cyberino", "Cyberino Sprinklino", "Epic", 8, 504_000, 28, rgb(30, 30, 40), rgb(0, 220, 255), NEON, { "Legs", "Visor", "Antenna" }),
	D("glitchero", "Glitchero Glitcheri", "Epic", 8, 980_000, 14, rgb(30, 30, 40), rgb(255, 0, 200), NEON, { "Legs", "Arms", "Visor" }),
	D("robodunkaroni", "Robo Dunkaroni", "Legendary", 8, 1_960_000, 4, rgb(150, 150, 160), rgb(210, 210, 220), NEON, { "Legs", "Arms", "Antenna" }),
	D("hologlazolo", "Holo Holo Glazolo", "Legendary", 8, 4_200_000, 1, rgb(40, 40, 60), rgb(150, 255, 255), NEON, { "Visor", "Wings", "Halo" }),
	-- 9. Crystal Cosmos
	D("amethystino", "Amethystino Donutino", "Rare", 9, 1_680_000, 50, rgb(70, 40, 110), rgb(160, 90, 255), WHITE, { "Legs", "IceSpikes" }),
	D("crystallo", "Crystallo Crullero", "Epic", 9, 3_000_000, 28, rgb(70, 40, 110), rgb(120, 200, 255), WHITE, { "Legs", "Crown" }),
	D("prismarino", "Prismarino Prismarina", "Legendary", 9, 5_900_000, 14, rgb(90, 60, 140), rgb(255, 200, 255), RAINBOW, { "Wings", "Halo" }),
	D("stardustino", "Stardustino Sprinkolo", "Legendary", 9, 11_800_000, 4, rgb(30, 20, 60), rgb(40, 20, 80), STARS, { "Legs", "Orbit" }),
	D("nebulini", "Nebulini Glazolini", "Celestial", 9, 25_000_000, 1, rgb(40, 20, 70), rgb(255, 100, 220), STARS, { "Wings", "Halo", "Orbit" }),
	D("grandeglazzarino", "La Grande Glazzarino", "Secret", 9, 100_000_000, 0.03, rgb(20, 20, 20), rgb(255, 255, 255), RAINBOW, { "Crown", "Wings", "Halo", "Orbit" }),
	-- 10. Celestial Donut Dimension
	D("galaxia", "Galaxia Donutia", "Epic", 10, 10_000_000, 50, rgb(20, 20, 60), rgb(40, 40, 160), STARS, { "Legs", "Orbit" }),
	D("cosmotung", "Cosmo Tung Tung Sahur", "Epic", 10, 18_000_000, 28, rgb(20, 20, 60), rgb(90, 60, 200), STARS, { "Legs", "Arms", "Bat", "Halo" }),
	D("supernova", "Supernova Glazanova", "Legendary", 10, 35_000_000, 14, rgb(255, 150, 50), rgb(255, 220, 100), STARS, { "Wings", "Halo", "Flames" }),
	D("odindindin", "Odin Din Din Donut", "Legendary", 10, 70_000_000, 4, rgb(60, 60, 90), rgb(180, 200, 255), GOLD, { "Legs", "Horns", "Crown", "Cape" }),
	D("infinito", "Infinito Glazinfinito", "Celestial", 10, 150_000_000, 1, rgb(20, 10, 40), rgb(255, 255, 255), RAINBOW, { "Wings", "Halo", "Orbit", "Crown" }),
	D("eternaldonut", "The Eternal Donut", "Secret", 10, 600_000_000, 0.02, rgb(10, 10, 10), rgb(255, 255, 255), STARS, { "Wings", "Halo", "Orbit", "Crown" }),
	D("maximus", "Donutus Maximus Supremus", "Secret", 10, 1_500_000_000, 0.008, rgb(255, 215, 0), rgb(255, 255, 255), RAINBOW, { "Wings", "Halo", "Orbit", "Crown", "Cape" }),

	---------------------------------------------------------------- World 2: Glaze Islands
	-- 11. Glaze Beach
	D("coconutto", "Coconutto Donutto", "Uncommon", 11, 60_000_000, 50, rgb(130, 85, 50), rgb(250, 248, 240), { rgb(130, 85, 50) }, { "Legs", "Leaf" }),
	D("surferino", "Surferino Glazerino", "Rare", 11, 110_000_000, 28, DOUGH, rgb(80, 200, 255), WHITE, { "Legs", "Arms", "Sunglasses" }),
	D("flamingo", "Flamingo Frostingo", "Rare", 11, 210_000_000, 14, DOUGH, rgb(255, 120, 170), WHITE, { "Legs", "Beak", "Bow" }),
	D("tralalerobeach", "Tralalero Beachalero", "Epic", 11, 420_000_000, 4, DOUGH, rgb(60, 160, 255), OCEAN, { "Legs", "SharkFin", "Sunglasses" }),
	D("crabbo", "Crabbo Crullero", "Legendary", 11, 900_000_000, 1, rgb(220, 80, 55), rgb(255, 110, 80), WHITE, { "Legs", "Arms", "Antenna", "Fangs" }),
	-- 12. Coral Crullers
	D("bubblino", "Bubblino Glazino", "Rare", 12, 360_000_000, 50, DOUGH, rgb(170, 230, 255), WHITE, { "Legs", "Snorkel" }),
	D("jellyfishino", "Jellyfishino Donutino", "Rare", 12, 650_000_000, 28, rgb(230, 170, 255), rgb(255, 150, 230), WHITE, { "Tentacles" }),
	D("octopussi", "Octopussi Sprinklussi", "Epic", 12, 1_270_000_000, 14, rgb(200, 80, 160), rgb(230, 100, 200), { rgb(255, 230, 250) }, { "Tentacles", "Sunglasses" }),
	D("sharkshark", "Shark Shark Glazark", "Epic", 12, 2_540_000_000, 4, rgb(120, 140, 170), rgb(90, 110, 140), WHITE, { "Legs", "SharkFin", "Fangs" }),
	D("pufferino", "Pufferino Donuferino", "Legendary", 12, 5_400_000_000, 1, DOUGH, rgb(255, 220, 90), { rgb(120, 90, 40) }, { "Legs", "IceSpikes", "Snorkel" }),
	-- 13. Pirate Cove
	D("pirato", "Pirato Donutto", "Rare", 13, 2_200_000_000, 50, DOUGH, rgb(240, 200, 130), nil, { "Legs", "PirateHat" }),
	D("barnacle", "Barnacle Bombardino", "Epic", 13, 3_900_000_000, 28, rgb(110, 120, 100), rgb(90, 110, 90), { rgb(200, 200, 180) }, { "PlaneWings", "EyePatch" }),
	D("parrotino", "Parrotino Glazarrot", "Epic", 13, 7_600_000_000, 14, DOUGH, rgb(60, 200, 90), RAINBOW, { "Legs", "Beak", "Wings" }),
	D("crullbeard", "Captain Crullbeard", "Legendary", 13, 15_000_000_000, 4, DOUGH, rgb(120, 60, 40), GOLD, { "Legs", "Arms", "PirateHat", "EyePatch", "Mustache" }),
	D("treasurino", "Treasurino Goldonut", "Legendary", 13, 33_000_000_000, 1, rgb(230, 180, 50), rgb(255, 215, 60), GOLD, { "Legs", "Crown", "Cape" }),
	-- 14. Jelly Jungle
	D("bananini", "Bananini Jellini", "Rare", 14, 13_000_000_000, 50, DOUGH, rgb(255, 230, 80), BLACK, { "Legs", "Leaf" }),
	D("toucanino", "Toucanino Sprinklino", "Epic", 14, 23_500_000_000, 28, rgb(30, 30, 30), rgb(255, 160, 30), RAINBOW, { "Legs", "Beak" }),
	D("chimpanzilla", "Chimpanzilla Glazilla", "Legendary", 14, 46_000_000_000, 14, DOUGH, rgb(120, 75, 40), GOLD, { "Legs", "Arms", "MonkeyEars", "Crown" }),
	D("tigrino", "Tigrino Tigrella", "Legendary", 14, 91_000_000_000, 4, DOUGH, rgb(255, 150, 40), BLACK, { "Legs", "Fangs", "MonkeyEars" }),
	D("junglejelly", "Jungle Jelly Kingo", "Celestial", 14, 196_000_000_000, 1, rgb(80, 160, 60), rgb(255, 60, 160), RAINBOW, { "Legs", "Crown", "Leaf", "Cape" }),
	-- 15. Volcano Isle
	D("lavalino", "Lavalino Lavalone", "Epic", 15, 78_000_000_000, 50, rgb(60, 40, 35), rgb(255, 110, 30), EMBERS, { "Legs", "Flames" }),
	D("obsidiano", "Obsidiano Donudiano", "Epic", 15, 141_000_000_000, 28, rgb(25, 20, 30), rgb(50, 40, 60), { rgb(255, 100, 0) }, { "Legs", "Horns" }),
	D("tikitiki", "Tiki Tiki Glazoki", "Legendary", 15, 274_000_000_000, 14, rgb(140, 90, 50), rgb(200, 140, 80), EMBERS, { "Legs", "Arms", "Leaf", "Mustache" }),
	D("magmazilla", "Magmazilla Crullazilla", "Celestial", 15, 549_000_000_000, 4, rgb(50, 30, 30), rgb(255, 60, 0), EMBERS, { "Legs", "Horns", "Wings", "Flames", "Fangs" }),
	D("volcanito", "Volcanito Supremito", "Celestial", 15, 1_180_000_000_000, 1, rgb(60, 40, 35), rgb(255, 140, 0), GOLD, { "Crown", "Flames", "Cape", "Wings" }),
	D("eruptus", "Eruptus Maximus", "Secret", 15, 5_000_000_000_000, 0.025, rgb(20, 10, 10), rgb(255, 80, 0), EMBERS, { "Crown", "Wings", "Flames", "Halo", "Orbit" }),

	---------------------------------------------------------------- World 3: Dream Dimension
	-- 16. Cloud Bakery
	D("cloudino", "Cloudino Puffino", "Rare", 16, 470_000_000_000, 50, rgb(245, 245, 255), rgb(255, 255, 255), { rgb(180, 210, 255) }, { "Legs", "Wings" }),
	D("angelino", "Angelino Glazelino", "Epic", 16, 850_000_000_000, 28, DOUGH, rgb(255, 250, 230), GOLD, { "Legs", "Wings", "Halo" }),
	D("cumulus", "Cumulus Crullus", "Epic", 16, 1_650_000_000_000, 14, rgb(230, 235, 255), rgb(200, 220, 255), WHITE, { "Legs", "Arms", "Propeller" }),
	D("rainbowtto", "Rainbowtto Sprinklotto", "Legendary", 16, 3_300_000_000_000, 4, DOUGH, rgb(255, 255, 255), RAINBOW, { "Legs", "Wings", "Bow" }),
	D("zeusino", "Zeusino Donuteus", "Legendary", 16, 7_000_000_000_000, 1, rgb(230, 230, 240), rgb(120, 170, 255), GOLD, { "Legs", "Arms", "Crown", "Mustache", "Cape" }),
	-- 17. Toy Factory
	D("robotino", "Robotino Glazobot", "Epic", 17, 2_800_000_000_000, 50, rgb(150, 150, 165), rgb(80, 160, 255), NEON, { "Legs", "Antenna", "Gears" }),
	D("teddy", "Teddy Donutteddy", "Epic", 17, 5_100_000_000_000, 28, rgb(170, 110, 60), rgb(200, 140, 90), nil, { "Legs", "Arms", "MonkeyEars", "Bow" }),
	D("yoyo", "Yo-Yo Glazoyo", "Legendary", 17, 9_900_000_000_000, 14, DOUGH, rgb(255, 60, 60), WHITE, { "Legs", "Arms", "Propeller" }),
	D("jackinthedonut", "Jack in the Donut", "Legendary", 17, 19_700_000_000_000, 4, DOUGH, rgb(255, 220, 40), RAINBOW, { "Legs", "TopHat", "Mustache" }),
	D("toysoldier", "Toy Soldier Crullero", "Celestial", 17, 42_000_000_000_000, 1, DOUGH, rgb(220, 30, 40), GOLD, { "Legs", "Arms", "TopHat", "Mustache", "Cape" }),
	-- 18. Haunted Donuttery
	D("ghostino", "Ghostino Boolino", "Epic", 18, 17_000_000_000_000, 50, rgb(235, 240, 245), rgb(255, 255, 255), nil, { "Arms", "Fangs" }),
	D("pumpkino", "Pumpkino Spicino", "Legendary", 18, 30_000_000_000_000, 28, rgb(230, 120, 30), rgb(255, 150, 40), { rgb(60, 40, 20) }, { "Legs", "Leaf", "WitchHat" }),
	D("vampirino", "Vampirino Glazula", "Legendary", 18, 59_000_000_000_000, 14, rgb(60, 20, 30), rgb(150, 10, 30), BLACK, { "Legs", "Fangs", "Cape" }),
	D("skeletonno", "Skeletonno Crunchino", "Celestial", 18, 118_000_000_000_000, 4, rgb(240, 240, 230), rgb(30, 30, 35), WHITE, { "Legs", "Arms", "TopHat" }),
	D("witchy", "Witchy Glazitchy", "Celestial", 18, 254_000_000_000_000, 1, rgb(80, 40, 110), rgb(120, 220, 90), SPOOKY, { "Legs", "WitchHat", "Cape", "Orbit" }),
	D("booboo", "Boo Boo Donutboo", "Secret", 18, 1_000_000_000_000_000, 0.025, rgb(20, 20, 30), rgb(200, 255, 200), SPOOKY, { "WitchHat", "Wings", "Halo", "Orbit", "Fangs" }),
	-- 19. Clockwork Void
	D("ticktock", "Tick Tock Glazock", "Epic", 19, 100_000_000_000_000, 50, rgb(200, 160, 80), rgb(255, 230, 150), { rgb(80, 60, 30) }, { "Legs", "Gears" }),
	D("cogwheelo", "Cogwheelo Donutelo", "Legendary", 19, 183_000_000_000_000, 28, rgb(120, 120, 130), rgb(200, 170, 90), GOLD, { "Legs", "Arms", "Gears" }),
	D("steampunko", "Steamo Punko", "Legendary", 19, 355_000_000_000_000, 14, rgb(110, 70, 40), rgb(180, 120, 60), GOLD, { "Legs", "TopHat", "Visor", "Gears" }),
	D("chrono", "Chrono Crullero", "Celestial", 19, 711_000_000_000_000, 4, rgb(40, 30, 60), rgb(255, 200, 90), STARS, { "Legs", "Gears", "Orbit", "Crown" }),
	D("voidino", "Voidino Nullino", "Celestial", 19, 1_500_000_000_000_000, 1, rgb(10, 5, 20), rgb(90, 40, 160), STARS, { "Wings", "Halo", "Orbit" }),
	-- 20. Donut Heaven
	D("harpino", "Harpino Glazelino", "Legendary", 20, 610_000_000_000_000, 50, DOUGH, rgb(255, 245, 210), GOLD, { "Legs", "Wings", "Halo" }),
	D("goldino", "Goldino Donutino", "Legendary", 20, 1_100_000_000_000_000, 28, rgb(255, 200, 60), rgb(255, 225, 110), WHITE, { "Legs", "Crown" }),
	D("seraphino", "Seraphino Sprinklino", "Celestial", 20, 2_100_000_000_000_000, 14, rgb(255, 240, 220), rgb(255, 255, 255), GOLD, { "Wings", "Halo", "Orbit" }),
	D("archangelo", "Archangelo Crullero", "Celestial", 20, 4_300_000_000_000_000, 4, DOUGH, rgb(255, 230, 160), STARS, { "Legs", "Arms", "Wings", "Halo", "Cape" }),
	D("heavenlyglaze", "Heavenly Glaze Supremo", "Celestial", 20, 9_100_000_000_000_000, 1, rgb(255, 250, 240), rgb(255, 255, 255), RAINBOW, { "Wings", "Halo", "Crown", "Orbit" }),
	D("omnidonut", "Omnidonut Infinitus", "Secret", 20, 40_000_000_000_000_000, 0.015, rgb(10, 10, 20), rgb(255, 255, 255), RAINBOW, { "Wings", "Halo", "Crown", "Orbit", "Cape" }),
	D("finaldonut", "The Final Donut", "Secret", 20, 120_000_000_000_000_000, 0.006, rgb(255, 215, 0), rgb(255, 250, 230), STARS, { "Wings", "Halo", "Crown", "Orbit", "Cape", "Flames" }),

	---------------------------------------------------------------- ADMIN (rarer than Secret)
	D("adminglazino", "Adminio Glazinio", "Admin", 10, 15_000_000_000, 0.004, rgb(15, 15, 20), rgb(255, 30, 40), ADMIN, { "Crown", "Sunglasses", "Cape", "Wings", "Orbit" }),
	D("banhammer", "Banhammer Donutto", "Admin", 15, 50_000_000_000_000, 0.004, rgb(15, 15, 20), rgb(255, 30, 40), ADMIN, { "Crown", "Sunglasses", "Cape", "Horns", "Orbit" }),
	D("sudosupremo", "Sudo Supremo Sprinklo", "Admin", 20, 1_200_000_000_000_000_000, 0.004, rgb(15, 15, 20), rgb(255, 30, 40), ADMIN, { "Crown", "Sunglasses", "Cape", "Wings", "Halo", "Orbit", "Flames" }),
} :: { Donut }

Donuts.ById = {} :: { [string]: Donut }
Donuts.ByArea = {} :: { [number]: { Donut } }
Donuts.ByScore = {} :: { [number]: Donut }

-- "Rarest donut" score (leaderboard + podium): rarity first, then mutation, then list position.
--   score = rarity * 10000 + mutation * 1000 + list index
local RARITY_UNIT = 10_000
local MUTATION_UNIT = 1_000

for index, donut in Donuts.List do
	assert(Donuts.ById[donut.Id] == nil, "Duplicate donut id: " .. donut.Id)
	assert(Rarities.ById[donut.Rarity], "Unknown rarity on donut " .. donut.Id .. ": " .. donut.Rarity)
	assert(index < MUTATION_UNIT, "Too many donuts for the score encoding")
	donut.Index = index
	donut.Score = Rarities.ById[donut.Rarity].Order * RARITY_UNIT + index
	Donuts.ById[donut.Id] = donut
	Donuts.ByScore[donut.Score] = donut
	Donuts.ByArea[donut.Area] = Donuts.ByArea[donut.Area] or {}
	table.insert(Donuts.ByArea[donut.Area], donut)
end

function Donuts.Get(id: string): Donut?
	return Donuts.ById[id]
end

function Donuts.Score(donut: Donut, mutationId: string?): number
	return donut.Score + Rarities.Mutation(mutationId).Order * MUTATION_UNIT
end

-- Score -> (donut, mutation id). Also understands scores saved before mutations existed
-- (rarity * 1000 + index), which only ever used list positions 1-53.
function Donuts.FromScore(score: number): (Donut?, string)
	if score <= 0 then
		return nil, "None"
	end
	if score < RARITY_UNIT then
		return Donuts.List[score % 1000], "None"
	end
	local donut = Donuts.List[score % MUTATION_UNIT]
	local mutationOrder = (score // MUTATION_UNIT) % 10
	for _, mutation in Rarities.Mutations do
		if mutation.Order == mutationOrder then
			return donut, mutation.Id
		end
	end
	return donut, "None"
end

-- A donut counts as "rare" for luck boosts when its base chance in its area is under this.
Donuts.RareChance = 0.1

-- Weighted random donut for an area. `rng` is a Random object. `luck` multiplies the weight of
-- every rare donut (Luck Event).
function Donuts.Roll(areaId: number, rng: Random, luck: number?): Donut
	local pool = Donuts.ByArea[areaId]
	assert(pool and #pool > 0, "No donuts defined for area " .. tostring(areaId))
	local boost = luck or 1
	local base = 0
	for _, donut in pool do
		base += donut.Weight
	end
	local function weight(donut: Donut): number
		return if boost ~= 1 and donut.Weight / base < Donuts.RareChance then donut.Weight * boost else donut.Weight
	end
	local total = 0
	for _, donut in pool do
		total += weight(donut)
	end
	local pick = rng:NextNumber() * total
	for _, donut in pool do
		pick -= weight(donut)
		if pick <= 0 then
			return donut
		end
	end
	return pool[#pool]
end

-- Chance (0-1) of a donut spawning in its area.
-- Chance (0-1) that a spawn in the donut's area is this donut. `luck` = the Luck Event's rarity
-- boost (same maths as Donuts.Roll), so the Index can show the boosted odds while it runs.
function Donuts.Chance(donut: Donut, luck: number?): number
	local boost = luck or 1
	local pool = Donuts.ByArea[donut.Area]
	local base = 0
	for _, other in pool do
		base += other.Weight
	end
	local function weight(d: Donut): number
		return if boost ~= 1 and d.Weight / base < Donuts.RareChance then d.Weight * boost else d.Weight
	end
	local total = 0
	for _, other in pool do
		total += weight(other)
	end
	return weight(donut) / total
end

return Donuts
