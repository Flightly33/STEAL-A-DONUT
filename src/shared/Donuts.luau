--[[
	Every donut in the game.

	Area     -> which area it spawns in (see Areas.luau)
	Weight   -> spawn chance relative to the other donuts in the same area
	Income   -> money per second at level 1 (before its mutation and size, see Rarities.luau)
	Dough / Frosting / Sprinkles -> colours used by DonutModel
	Parts    -> brainrot accessories (see DonutModel for the full list)

	Each area has 5 regular donuts weighted 50 / 28 / 14 / 4 / 1 (spawning at 50 / 28 / 12 / 3 / 0.6: the best one is
	about a 0.6% spawn),
	a few areas also have a Secret (0.006% - 0.03%), and the last area of each world has an ADMIN donut
	that never spawns by itself: only the admin panel can make one (Rarities AdminOnly). Every spawn can also roll a mutation (Gold, Diamond, Mythic, Divine,
	Rainbow) and a size, which multiply its income.

	To add a donut: copy a line, give it a unique Id, pick an area/rarity/income. That's it:
	the Index, leaderboards, spawns and podium all pick it up automatically.
	Add new donuts at the END of the list: the list position is part of the saved "rarest donut" score.
]]

local Rarities = require(script.Parent.Rarities)
local Areas = require(script.Parent.Areas)
local Boxes = require(script.Parent.Boxes)

export type Donut = {
	Id: string,
	Name: string,
	Rarity: string,
	Area: number, -- the biome whose boxes it comes out of
	Box: string?, -- which of that biome's boxes (Boxes.luau tier id); nil = admin panel only (or crafted)
	Crafted: boolean?, -- never in a box: crafted at the Cosmic Forge (limited time, Config.CosmicDonut)
	Income: number,
	Weight: number, -- chance relative to the other donuts in the same box
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
local SPOOKY = { rgb(140, 255, 120), rgb(170, 90, 255), rgb(255, 140, 30) }
local ADMIN = { rgb(255, 40, 40), rgb(255, 255, 255), rgb(20, 20, 20) }

local function D(id: string, name: string, rarity: string, area: number, income: number, weight: number, dough: Color3, frosting: Color3, sprinkles: { Color3 }?, parts: { string })
	return {
		Id = id, Name = name, Rarity = rarity, Area = area, Box = nil, Income = income, Weight = weight,
		Dough = dough, Frosting = frosting, Sprinkles = sprinkles, Parts = parts,
		Score = 0, Index = 0, Crafted = nil :: boolean?,
	}
end

local Donuts = {}

Donuts.List = {
	---------------------------------------------------------------- World 1: Donut Land
	-- 1. Glazed Meadow
	D("glazino", "Plain Glazino", "Common", 1, 1, 50, DOUGH, rgb(255, 236, 200), nil, { "Legs" }),
	D("sugarino", "Sugarino Dunkarino", "Common", 1, 2, 28, DOUGH, rgb(250, 250, 250), nil, { "Legs", "Arms", "SugarCoat" }),
	D("tungglazur", "Tung Tung Glazur", "Uncommon", 1, 4, 14, DOUGH, rgb(125, 75, 45), nil, { "Legs", "Bat", "WoodGrain" }),
	D("sprinkolini", "Sprinkolini Pinkolini", "Uncommon", 1, 7, 4, DOUGH, rgb(255, 150, 200), RAINBOW, { "Legs", "Arms", "SprinkleStorm" }),
	D("glazzerina", "Glazzerina Ballerina", "Rare", 1, 15, 1, DOUGH, rgb(255, 200, 230), WHITE, { "Legs", "Tutu", "BalletSlippers", "Tiara" }),
	-- 2. Sprinkle Park
	D("crullero", "Crullero Crullala", "Common", 2, 6, 50, DOUGH, rgb(240, 190, 100), nil, { "Legs", "Mustache", "CrullerRidges" }),
	D("kremelino", "Boston Kremelino", "Uncommon", 2, 11, 28, DOUGH, rgb(110, 65, 40), nil, { "Legs", "TopHat", "CreamFilling" }),
	D("sahursprinkle", "Sahur Sprinkle Sahur", "Uncommon", 2, 21, 14, DOUGH, rgb(255, 255, 255), RAINBOW, { "Legs", "Arms", "Bat", "WoodGrain" }),
	D("jellyfillo", "Jellyfillo Jellyfilla", "Rare", 2, 42, 4, DOUGH, rgb(220, 40, 60), WHITE, { "Legs", "Sunglasses", "JellyOoze" }),
	D("patadonut", "Brr Brr Patadonut", "Rare", 2, 90, 1, DOUGH, rgb(110, 200, 90), RAINBOW, { "Legs", "Arms", "Mustache", "BigNose", "LeafCrown" }),
	-- 3. Sugar Dunes
	D("cinnamonio", "Cinnamonio Camelino", "Common", 3, 36, 50, rgb(190, 120, 60), rgb(240, 222, 190), nil, { "Legs", "Camel", "CinnamonSwirl" }),
	D("frigocamel", "Frigo Cameldonut", "Uncommon", 3, 65, 28, DOUGH, rgb(170, 220, 255), WHITE, { "Legs", "Arms", "Camel", "Snowflakes" }),
	D("lirililarila", "Lirili Larila Glaze", "Rare", 3, 126, 14, DOUGH, rgb(100, 200, 80), WHITE, { "Legs", "Sunglasses", "Trunk", "Cactus" }),
	D("tradonut", "Tralalero Tradonut", "Rare", 3, 252, 4, DOUGH, rgb(40, 140, 255), WHITE, { "Legs", "SharkFin", "SharkTail" }),
	D("glazamun", "Pharaoh Glazamun", "Epic", 3, 540, 1, DOUGH, rgb(255, 200, 40), { rgb(40, 80, 200) }, { "Legs", "Pharaoh", "Ankh" }),
	-- 4. Frosting Falls
	D("strawberrini", "Strawberrini Frostini", "Uncommon", 4, 220, 50, DOUGH, rgb(255, 100, 140), WHITE, { "Legs", "StrawberrySlices" }),
	D("cappuccino", "Cappuccino Donutino", "Uncommon", 4, 390, 28, rgb(150, 100, 60), rgb(200, 150, 110), nil, { "Legs", "CoffeeCup", "Katanas" }),
	D("chimpanzini", "Chimpanzini Glazanini", "Rare", 4, 760, 14, DOUGH, rgb(255, 230, 90), nil, { "Legs", "Arms", "MonkeyEars", "BananaPeel" }),
	D("lavaca", "La Vaca Sprinkla Sprinkla", "Epic", 4, 1_500, 4, DOUGH, rgb(255, 255, 255), BLACK, { "Legs", "Horns", "CowSpots", "CowBell" }),
	D("bombardonut", "Bombardonut Crocodonut", "Epic", 4, 3_250, 1, DOUGH, rgb(60, 140, 60), { rgb(40, 90, 40) }, { "PlaneWings", "Sunglasses", "CrocSnout", "Bombs" }),
	-- 5. Chocolate Caverns
	D("chocolatto", "Chocolatto Cavernino", "Uncommon", 5, 1_300, 50, DARK_DOUGH, rgb(90, 50, 30), nil, { "Legs", "Arms", "MinerHelmet" }),
	D("trippitroppi", "Trippi Troppi Cocoa", "Rare", 5, 2_350, 28, DARK_DOUGH, rgb(150, 95, 60), WHITE, { "Legs", "Mustache", "ShrimpTail", "CatEars" }),
	D("bobrito", "Bobrito Bandonuto", "Rare", 5, 4_550, 14, DARK_DOUGH, rgb(60, 40, 30), GOLD, { "Legs", "Sunglasses", "Cape", "BeaverTeeth", "Fedora" }),
	D("fudgeroni", "Fudgeroni Fudgerona", "Epic", 5, 9_100, 4, DARK_DOUGH, rgb(80, 45, 25), GOLD, { "Legs", "Crown", "FudgeDrips" }),
	D("tungfudgur", "Tung Tung Tung Fudgur", "Legendary", 5, 19_500, 1, DARK_DOUGH, rgb(65, 35, 20), GOLD, { "Legs", "Arms", "Bat", "Horns", "WoodGrain" }),
	-- 6. Glacier Glaze
	D("frostaroni", "Frostaroni Frostarini", "Uncommon", 6, 7_800, 50, DOUGH, rgb(170, 220, 255), WHITE, { "Legs", "IceSpikes", "Snowflakes" }),
	D("pinguino", "Pinguino Glazino", "Rare", 6, 14_000, 28, DOUGH, rgb(35, 35, 45), WHITE, { "Legs", "Beak", "Flippers", "BowTie" }),
	D("icicladonut", "Brr Brr Icicladonut", "Epic", 6, 27_000, 14, DOUGH, rgb(120, 230, 255), WHITE, { "Legs", "Arms", "IceSpikes", "Icicles" }),
	D("yetisprinkletti", "Yeti Sprinkletti", "Epic", 6, 55_000, 4, rgb(240, 240, 250), rgb(245, 250, 255), { rgb(120, 200, 255) }, { "Legs", "Arms", "Horns", "FurTufts" }),
	D("glacierino", "Glacierino Frostino", "Legendary", 6, 117_000, 1, DOUGH, rgb(200, 255, 255), WHITE, { "Legs", "Wings", "IceCrown" }),
	-- 7. Molten Bakery
	D("lavaccino", "Lavaccino Lavaccina", "Rare", 7, 47_000, 50, rgb(60, 40, 35), rgb(255, 120, 30), EMBERS, { "Legs", "Flames", "LavaDrips" }),
	D("magmarino", "Magmarino Glazerino", "Rare", 7, 84_000, 28, rgb(60, 40, 35), rgb(255, 70, 20), BLACK, { "Legs", "Horns", "LavaCracks" }),
	D("flambino", "Bombardiro Flambino", "Epic", 7, 163_000, 14, rgb(50, 40, 40), rgb(60, 50, 50), EMBERS, { "PlaneWings", "Flames", "Bombs", "Goggles" }),
	D("infernolo", "Infernolo Donutolo", "Legendary", 7, 327_000, 4, rgb(50, 30, 30), rgb(255, 40, 0), EMBERS, { "Legs", "Horns", "Flames", "Cape", "Trident", "DevilTail" }),
	D("dragonini", "Dragonini Crullerini", "Legendary", 7, 700_000, 1, rgb(90, 30, 20), rgb(255, 160, 0), EMBERS, { "Legs", "Wings", "Horns", "Flames", "DragonTail" }),
	-- 8. Neon Donut City
	D("neonino", "Neonino Glowzino", "Rare", 8, 280_000, 50, rgb(30, 30, 40), rgb(0, 255, 120), NEON, { "Legs", "Visor", "NeonTube" }),
	D("cyberino", "Cyberino Sprinklino", "Epic", 8, 504_000, 28, rgb(30, 30, 40), rgb(0, 220, 255), NEON, { "Legs", "Visor", "Antenna", "Headphones" }),
	D("glitchero", "Glitchero Glitcheri", "Epic", 8, 980_000, 14, rgb(30, 30, 40), rgb(255, 0, 200), NEON, { "Legs", "Arms", "Visor", "GlitchSlices" }),
	D("robodunkaroni", "Robo Dunkaroni", "Legendary", 8, 1_960_000, 4, rgb(150, 150, 160), rgb(210, 210, 220), NEON, { "Legs", "Arms", "Antenna", "RoboPlates", "RoboClaw" }),
	D("hologlazolo", "Holo Holo Glazolo", "Legendary", 8, 4_200_000, 1, rgb(40, 40, 60), rgb(150, 255, 255), NEON, { "Visor", "Wings", "Halo", "HoloRing" }),
	-- 9. Crystal Cosmos
	D("amethystino", "Amethystino Donutino", "Rare", 9, 1_680_000, 50, rgb(70, 40, 110), rgb(160, 90, 255), WHITE, { "Legs", "IceSpikes", "CrystalCluster" }),
	D("crystallo", "Crystallo Crullero", "Epic", 9, 3_000_000, 28, rgb(70, 40, 110), rgb(120, 200, 255), WHITE, { "Legs", "Crown", "CrystalCluster" }),
	D("prismarino", "Prismarino Prismarina", "Legendary", 9, 5_900_000, 14, rgb(90, 60, 140), rgb(255, 200, 255), RAINBOW, { "Wings", "Halo", "Prism" }),
	D("stardustino", "Stardustino Sprinkolo", "Legendary", 9, 11_800_000, 4, rgb(30, 20, 60), rgb(40, 20, 80), STARS, { "Legs", "Orbit", "StarWand" }),
	D("nebulini", "Nebulini Glazolini", "Celestial", 9, 25_000_000, 1, rgb(40, 20, 70), rgb(255, 100, 220), STARS, { "Wings", "Halo", "Orbit", "NebulaCloud" }),
	D("grandeglazzarino", "La Grande Glazzarino", "Secret", 9, 100_000_000, 0.03, rgb(20, 20, 20), rgb(255, 255, 255), RAINBOW, { "Crown", "Wings", "Halo", "Orbit", "Scepter" }),
	-- 10. Celestial Donut Dimension
	D("galaxia", "Galaxia Donutia", "Epic", 10, 10_000_000, 50, rgb(20, 20, 60), rgb(40, 40, 160), STARS, { "Legs", "Orbit", "GalaxySwirl" }),
	D("cosmotung", "Cosmo Tung Tung Sahur", "Epic", 10, 18_000_000, 28, rgb(20, 20, 60), rgb(90, 60, 200), STARS, { "Legs", "Arms", "Bat", "Halo", "SpaceHelmet" }),
	D("supernova", "Supernova Glazanova", "Legendary", 10, 35_000_000, 14, rgb(255, 150, 50), rgb(255, 220, 100), STARS, { "Wings", "Halo", "Flames", "NovaBurst" }),
	D("odindindin", "Odin Din Din Donut", "Legendary", 10, 70_000_000, 4, rgb(60, 60, 90), rgb(180, 200, 255), GOLD, { "Legs", "Horns", "Crown", "Cape", "Beard", "Spear" }),
	D("infinito", "Infinito Glazinfinito", "Celestial", 10, 150_000_000, 1, rgb(20, 10, 40), rgb(255, 255, 255), RAINBOW, { "Wings", "Halo", "Orbit", "Crown", "InfinityRing" }),
	D("eternaldonut", "The Eternal Donut", "Secret", 10, 600_000_000, 0.02, rgb(10, 10, 10), rgb(255, 255, 255), STARS, { "Wings", "Halo", "Orbit", "Crown", "Hourglass" }),
	D("maximus", "Donutus Maximus Supremus", "Secret", 10, 1_500_000_000, 0.008, rgb(255, 215, 0), rgb(255, 255, 255), RAINBOW, { "Wings", "Halo", "Orbit", "Crown", "Cape", "Scepter" }),

	---------------------------------------------------------------- World 2: The Underworld
	-- 13. Ember Gates
	D("coconutto", "Charcoalino Donutto", "Uncommon", 13, 2_160_000_000, 50, rgb(60, 40, 35), rgb(95, 72, 66), EMBERS, { "Legs", "Horns", "CharcoalChunks" }),
	D("surferino", "Emberino Glazerino", "Rare", 13, 3_960_000_000, 28, DOUGH, rgb(255, 120, 40), EMBERS, { "Legs", "Arms", "Sunglasses", "FlameHair" }),
	D("flamingo", "Flamingo Flamerino", "Rare", 13, 7_560_000_000, 14, DOUGH, rgb(255, 90, 70), EMBERS, { "Legs", "Beak", "Flames", "FlamingoLegs", "FeatherTuft" }),
	D("tralalerobeach", "Tralalero Infernalero", "Epic", 13, 15_120_000_000, 4, DOUGH, rgb(255, 70, 30), EMBERS, { "Legs", "SharkFin", "Horns", "SharkTail", "LavaDrips" }),
	D("crabbo", "Lava Crabbo Crullero", "Legendary", 13, 32_400_000_000, 1, rgb(90, 25, 20), rgb(255, 60, 30), EMBERS, { "Legs", "Arms", "Antenna", "Fangs", "CrabClaws" }),
	-- 14. Brimstone Bakery
	D("bubblino", "Bubblino Brimstino", "Rare", 14, 12_960_000_000, 50, DOUGH, rgb(255, 210, 90), EMBERS, { "Legs", "Mustache", "LavaBubbles" }),
	D("jellyfishino", "Scorchino Jellino", "Rare", 14, 23_400_000_000, 28, rgb(70, 40, 35), rgb(255, 130, 50), EMBERS, { "Tentacles", "JellyDome" }),
	D("octopussi", "Octofurnacci Sprinklussi", "Epic", 14, 45_720_000_000, 14, rgb(120, 30, 30), rgb(255, 90, 40), EMBERS, { "Tentacles", "Sunglasses", "Chimney" }),
	D("sharkshark", "Shark Shark Scorchark", "Epic", 14, 91_440_000_000, 4, rgb(70, 60, 60), rgb(255, 100, 40), EMBERS, { "Legs", "SharkFin", "Fangs", "SharkTail", "SharkGills" }),
	D("pufferino", "Pufferino Brimstino", "Legendary", 14, 194_400_000_000, 1, DOUGH, rgb(255, 200, 60), { rgb(255, 90, 0) }, { "Legs", "IceSpikes", "Flames", "PufferSpikes" }),
	-- 15. Magma Rivers
	D("pirato", "Magma Pirato Donutto", "Rare", 15, 79_200_000_000, 50, DOUGH, rgb(255, 140, 60), nil, { "Legs", "PirateHat", "Hook" }),
	D("barnacle", "Basaltico Bombardino", "Epic", 15, 140_400_000_000, 28, rgb(60, 50, 50), rgb(90, 70, 70), { rgb(255, 100, 0) }, { "PlaneWings", "EyePatch", "BasaltPlates", "Bombs" }),
	D("parrotino", "Phoenixino Glazarrot", "Epic", 15, 273_600_000_000, 14, DOUGH, rgb(255, 110, 30), EMBERS, { "Legs", "Beak", "Wings", "PhoenixCrest", "PhoenixTail" }),
	D("crullbeard", "Captain Crullfire", "Legendary", 15, 540_000_000_000, 4, DOUGH, rgb(160, 40, 20), GOLD, { "Legs", "Arms", "PirateHat", "EyePatch", "Mustache", "FireBeard", "Hook" }),
	D("treasurino", "Molten Treasurino", "Legendary", 15, 1_188_000_000_000, 1, rgb(230, 120, 40), rgb(255, 170, 40), GOLD, { "Legs", "Crown", "Cape", "TreasureCoins", "Gems" }),
	-- 16. Soul Caverns
	D("bananini", "Spookini Soulini", "Rare", 16, 468_000_000_000, 50, rgb(40, 50, 70), rgb(120, 220, 255), { rgb(200, 245, 255) }, { "WitchHat", "GhostTail" }),
	D("toucanino", "Soulcanino Sprinklino", "Epic", 16, 846_000_000_000, 28, rgb(30, 30, 40), rgb(80, 200, 255), { rgb(160, 240, 255), rgb(255, 255, 255) }, { "Legs", "BigBeak" }),
	D("chimpanzilla", "Ghostzilla Glazilla", "Legendary", 16, 1_656_000_000_000, 14, rgb(180, 220, 240), rgb(220, 245, 255), { rgb(90, 200, 255) }, { "Legs", "Arms", "MonkeyEars", "Crown", "DinoSpikes" }),
	D("tigrino", "Wisprino Tigrella", "Legendary", 16, 3_276_000_000_000, 4, rgb(40, 60, 90), rgb(90, 210, 255), BLACK, { "Legs", "Fangs", "TigerStripes", "CatEars" }),
	D("junglejelly", "Soul Jelly Kingo", "Celestial", 16, 7_056_000_000_000, 1, rgb(30, 50, 80), rgb(70, 230, 255), { rgb(70, 230, 255), rgb(255, 255, 255) }, { "Legs", "Crown", "Halo", "Cape", "SoulWisps" }),
	-- 17. Obsidian Forge
	D("lavalino", "Lavalino Lavalone", "Epic", 17, 2_808_000_000_000, 50, rgb(60, 40, 35), rgb(255, 110, 30), EMBERS, { "Legs", "Flames", "LavaDrips" }),
	D("obsidiano", "Obsidiano Donudiano", "Epic", 17, 5_076_000_000_000, 28, rgb(25, 20, 30), rgb(50, 40, 60), { rgb(255, 100, 0) }, { "Legs", "Horns", "ObsidianShards" }),
	D("tikitiki", "Forgy Forgy Glazoki", "Legendary", 17, 9_864_000_000_000, 14, rgb(70, 60, 60), rgb(255, 140, 40), EMBERS, { "Legs", "Arms", "Gears", "Mustache", "ForgeHammer" }),
	D("magmazilla", "Magmazilla Crullazilla", "Celestial", 17, 19_764_000_000_000, 4, rgb(50, 30, 30), rgb(255, 60, 0), EMBERS, { "Legs", "Horns", "Wings", "Flames", "Fangs", "DinoSpikes", "DragonTail" }),
	D("volcanito", "Volcanito Supremito", "Celestial", 17, 42_480_000_000_000, 1, rgb(60, 40, 35), rgb(255, 140, 0), GOLD, { "Flames", "Cape", "Wings", "Volcano" }),
	D("eruptus", "Eruptus Maximus", "Secret", 17, 180_000_000_000_000, 0.025, rgb(20, 10, 10), rgb(255, 80, 0), EMBERS, { "Wings", "Flames", "Halo", "Orbit", "Volcano", "LavaDrips" }),

	---------------------------------------------------------------- World 3: Dream Dimension
	-- 20. Cloud Bakery
	D("cloudino", "Cloudino Puffino", "Rare", 20, 609_120_000_000_000, 50, rgb(245, 245, 255), rgb(255, 255, 255), { rgb(180, 210, 255) }, { "Legs", "Wings", "CloudPuffs" }),
	D("angelino", "Angelino Glazelino", "Epic", 20, 1_101_600_000_000_000, 28, DOUGH, rgb(255, 250, 230), GOLD, { "Legs", "Wings", "Halo", "CloudPuffs" }),
	D("cumulus", "Cumulus Crullus", "Epic", 20, 2_138_400_000_000_000, 14, rgb(230, 235, 255), rgb(200, 220, 255), WHITE, { "Legs", "Arms", "Propeller", "RainCloud" }),
	D("rainbowtto", "Rainbowtto Sprinklotto", "Legendary", 20, 4_276_800_000_000_000, 4, DOUGH, rgb(255, 255, 255), RAINBOW, { "Legs", "Wings", "Bow", "RainbowArc" }),
	D("zeusino", "Zeusino Donuteus", "Legendary", 20, 9.072e15, 1, rgb(230, 230, 240), rgb(120, 170, 255), GOLD, { "Legs", "Arms", "Crown", "Mustache", "Cape", "LightningBolt", "Beard" }),
	-- 21. Toy Factory
	D("robotino", "Robotino Glazobot", "Epic", 21, 3_628_800_000_000_000, 50, rgb(150, 150, 165), rgb(80, 160, 255), NEON, { "Legs", "Antenna", "Gears", "RoboPlates", "WindUpKey" }),
	D("teddy", "Teddy Donutteddy", "Epic", 21, 6_609_600_000_000_000, 28, rgb(170, 110, 60), rgb(200, 140, 90), nil, { "Legs", "Arms", "MonkeyEars", "Bow", "Stitches" }),
	D("yoyo", "Yo-Yo Glazoyo", "Legendary", 21, 1.28304e16, 14, DOUGH, rgb(255, 60, 60), WHITE, { "Legs", "Arms", "Propeller", "YoYo" }),
	D("jackinthedonut", "Jack in the Donut", "Legendary", 21, 2.55312e16, 4, DOUGH, rgb(255, 220, 40), RAINBOW, { "Legs", "TopHat", "Mustache", "JackCrank" }),
	D("toysoldier", "Toy Soldier Crullero", "Celestial", 21, 5.4432e16, 1, DOUGH, rgb(220, 30, 40), GOLD, { "Legs", "Arms", "Mustache", "Cape", "Busby", "ToyDrum" }),
	-- 22. Haunted Donuttery
	D("ghostino", "Ghostino Boolino", "Epic", 22, 2.2032e16, 50, rgb(235, 240, 245), rgb(255, 255, 255), nil, { "Arms", "Fangs", "GhostTail" }),
	D("pumpkino", "Pumpkino Spicino", "Legendary", 22, 3.888e16, 28, rgb(230, 120, 30), rgb(255, 150, 40), { rgb(60, 40, 20) }, { "Legs", "Leaf", "WitchHat", "PumpkinRidges" }),
	D("vampirino", "Vampirino Glazula", "Legendary", 22, 7.6464e16, 14, rgb(60, 20, 30), rgb(150, 10, 30), BLACK, { "Legs", "Fangs", "Cape", "VampireCollar", "Bats" }),
	D("skeletonno", "Skeletonno Crunchino", "Celestial", 22, 1.52928e17, 4, rgb(240, 240, 230), rgb(30, 30, 35), WHITE, { "Legs", "Arms", "TopHat", "Ribcage" }),
	D("witchy", "Witchy Glazitchy", "Celestial", 22, 3.29184e17, 1, rgb(80, 40, 110), rgb(120, 220, 90), SPOOKY, { "Legs", "WitchHat", "Cape", "Orbit", "Broom" }),
	D("booboo", "Boo Boo Donutboo", "Secret", 22, 1.296e18, 0.025, rgb(20, 20, 30), rgb(200, 255, 200), SPOOKY, { "WitchHat", "Wings", "Halo", "Orbit", "Fangs", "GhostTail" }),
	-- 23. Clockwork Void
	D("ticktock", "Tick Tock Glazock", "Epic", 23, 1.296e17, 50, rgb(200, 160, 80), rgb(255, 230, 150), { rgb(80, 60, 30) }, { "Legs", "Gears", "AlarmClock" }),
	D("cogwheelo", "Cogwheelo Donutelo", "Legendary", 23, 2.37168e17, 28, rgb(120, 120, 130), rgb(200, 170, 90), GOLD, { "Legs", "Arms", "Gears", "WindUpKey" }),
	D("steampunko", "Steamo Punko", "Legendary", 23, 4.6008e17, 14, rgb(110, 70, 40), rgb(180, 120, 60), GOLD, { "Legs", "TopHat", "Gears", "Goggles" }),
	D("chrono", "Chrono Crullero", "Celestial", 23, 9.21456e17, 4, rgb(40, 30, 60), rgb(255, 200, 90), STARS, { "Legs", "Gears", "Orbit", "Crown", "Hourglass" }),
	D("voidino", "Voidino Nullino", "Celestial", 23, 1.944e18, 1, rgb(10, 5, 20), rgb(90, 40, 160), STARS, { "Wings", "Halo", "Orbit", "VoidRing" }),
	-- 24. Donut Heaven
	D("harpino", "Harpino Glazelino", "Legendary", 24, 7.9056e17, 50, DOUGH, rgb(255, 245, 210), GOLD, { "Legs", "Wings", "Halo", "Harp" }),
	D("goldino", "Goldino Donutino", "Legendary", 24, 1.4256e18, 28, rgb(255, 200, 60), rgb(255, 225, 110), WHITE, { "Legs", "Crown", "TreasureCoins" }),
	D("seraphino", "Seraphino Sprinklino", "Celestial", 24, 2.7216e18, 14, rgb(255, 240, 220), rgb(255, 255, 255), GOLD, { "Wings", "Halo", "Orbit", "SeraphWings" }),
	D("archangelo", "Archangelo Crullero", "Celestial", 24, 5.5728e18, 4, DOUGH, rgb(255, 230, 160), STARS, { "Legs", "Arms", "Wings", "Halo", "Cape", "Sword" }),
	D("heavenlyglaze", "Heavenly Glaze Supremo", "Celestial", 24, 1.17936e19, 1, rgb(255, 250, 240), rgb(255, 255, 255), RAINBOW, { "Wings", "Halo", "Orbit", "Laurel" }),
	D("omnidonut", "Omnidonut Infinitus", "Secret", 24, 5.184e19, 0.015, rgb(10, 10, 20), rgb(255, 255, 255), RAINBOW, { "Wings", "Halo", "Crown", "Orbit", "Cape", "CosmicEye" }),
	D("finaldonut", "The Final Donut", "Secret", 24, 1.5552e20, 0.006, rgb(255, 215, 0), rgb(255, 250, 230), STARS, { "Wings", "Halo", "Crown", "Orbit", "Cape", "Flames", "Scepter" }),

	---------------------------------------------------------------- ADMIN (rarer than Secret)
	D("adminglazino", "Adminio Glazinio", "Admin", 12, 540_000_000_000, 0.004, rgb(15, 15, 20), rgb(255, 30, 40), ADMIN, { "Crown", "Sunglasses", "Cape", "Wings", "Orbit", "Scepter" }),
	D("banhammer", "Banhammer Donutto", "Admin", 19, 1.53e17, 0.004, rgb(15, 15, 20), rgb(255, 30, 40), ADMIN, { "Crown", "Sunglasses", "Cape", "Horns", "Orbit", "Banhammer" }),
	D("sudosupremo", "Sudo Supremo Sprinklo", "Admin", 26, 4.25e22, 0.004, rgb(15, 15, 20), rgb(255, 30, 40), ADMIN, { "Crown", "Sunglasses", "Cape", "Wings", "Orbit", "Flames", "Terminal" }),
	---------------------------------------------------------------- New areas (added later: kept at the end, see the note at the top)
	-- 11. Candy Cane Canyon
	D("candycanino", "Candycanino Stripolino", "Uncommon", 11, 60_000_000, 50, DOUGH, rgb(255, 255, 255), { rgb(230, 40, 50) }, { "Legs", "Arms", "CandyCane" }),
	D("lollipoppo", "Lollipoppo Swirlino", "Rare", 11, 108_000_000, 28, DOUGH, rgb(255, 110, 190), RAINBOW, { "Legs", "Bow", "Lollipop" }),
	D("gumdroppa", "Gumdroppa Bouncera", "Rare", 11, 210_000_000, 14, DOUGH, rgb(90, 210, 120), { rgb(255, 60, 60), rgb(255, 220, 60) }, { "Legs", "Gumdrops" }),
	D("peppermintus", "Peppermintus Maximus", "Epic", 11, 420_000_000, 4, rgb(245, 245, 245), rgb(230, 40, 50), WHITE, { "Legs", "Arms", "PeppermintSwirl" }),
	D("caramelloso", "Caramelloso Canyonero", "Legendary", 11, 900_000_000, 1, rgb(200, 130, 60), rgb(255, 190, 90), GOLD, { "Legs", "Arms", "TopHat", "Mustache", "CaramelDrips" }),
	-- 12. Rainbow Sprinkle Summit
	D("summitino", "Summitino Sprinklino", "Rare", 12, 360_000_000, 50, DOUGH, rgb(240, 245, 255), RAINBOW, { "Legs", "Visor", "SummitFlag" }),
	D("arcobalenino", "Arcobalenino Glazino", "Rare", 12, 648_000_000, 28, DOUGH, rgb(255, 150, 220), RAINBOW, { "Legs", "Arms", "Bow", "RainbowArc" }),
	D("yetisprinkle", "Yeti Sprinkle Yeti", "Epic", 12, 1_260_000_000, 14, rgb(240, 240, 255), rgb(170, 210, 255), WHITE, { "Legs", "Arms", "IceSpikes", "FurTufts" }),
	D("cloudcruller", "Cloudy Crullerino", "Epic", 12, 2_520_000_000, 4, rgb(250, 250, 255), rgb(200, 230, 255), RAINBOW, { "Wings", "Halo", "CloudPuffs" }),
	D("rainbowrex", "Rainbow Rexorino", "Legendary", 12, 5_400_000_000, 1, DOUGH, rgb(120, 200, 255), RAINBOW, { "Legs", "Arms", "Horns", "Wings", "DinoSpikes", "DragonTail" }),
	-- 18. Inferno Spires
	D("mangolino", "Infernolino Spirino", "Epic", 18, 17_000_000_000_000, 50, DOUGH, rgb(255, 80, 40), EMBERS, { "Legs", "Horns", "DevilTail" }),
	D("flamingonut", "Flamingonut Blazerino", "Legendary", 18, 30_600_000_000_000, 28, DOUGH, rgb(255, 60, 90), EMBERS, { "Legs", "Beak", "Sunglasses", "FlamingoLegs", "FeatherTuft" }),
	D("cocobombo", "Cindabombo Blastino", "Legendary", 18, 59_400_000_000_000, 14, rgb(50, 35, 30), rgb(255, 120, 40), EMBERS, { "Legs", "Arms", "Flames", "BombFuse" }),
	D("tikiglaze", "Imp Glaze Impolo", "Celestial", 18, 119_000_000_000_000, 4, rgb(150, 30, 30), rgb(255, 90, 50), GOLD, { "Legs", "Arms", "Horns", "Fangs", "DevilTail", "Trident" }),
	D("lagunamax", "Inferna Maxima Donutta", "Celestial", 18, 255_000_000_000_000, 1, rgb(60, 20, 20), rgb(255, 60, 30), EMBERS, { "Wings", "Halo", "Horns", "Trident" }),
	-- 19. The Molten Core
	D("templino", "Coreino Magmarino", "Epic", 19, 102_000_000_000_000, 50, rgb(80, 50, 40), rgb(255, 150, 50), EMBERS, { "Legs", "Arms", "MagmaCore" }),
	D("wavino", "Lava Wavino Surfarino", "Legendary", 19, 184_000_000_000_000, 28, DOUGH, rgb(255, 110, 30), EMBERS, { "Legs", "Arms", "SharkFin", "Surfboard" }),
	D("idolonut", "Molten Idolonut", "Legendary", 19, 356_000_000_000_000, 14, rgb(255, 170, 40), rgb(255, 210, 90), GOLD, { "Legs", "Crown", "Pharaoh", "Gems" }),
	D("tsunamo", "Magmamo Crashino", "Celestial", 19, 714_000_000_000_000, 4, rgb(80, 20, 10), rgb(255, 90, 20), EMBERS, { "Legs", "Tentacles", "Flames", "LavaWave" }),
	D("templeking", "Magma Kingo Glazo", "Celestial", 19, 1_530_000_000_000_000, 1, rgb(70, 30, 20), rgb(255, 170, 40), GOLD, { "Legs", "Arms", "Crown", "Cape", "Scepter", "LavaDrips" }),
	-- 25. Starfall Garden
	D("starbloom", "Starbloom Petalino", "Legendary", 25, 4.72e18, 50, rgb(40, 30, 80), rgb(255, 200, 240), STARS, { "Legs", "Leaf", "Flower" }),
	D("moonpetal", "Moonpetal Dreamino", "Legendary", 25, 8.49e18, 28, rgb(60, 50, 120), rgb(220, 220, 255), STARS, { "Legs", "Halo", "Moon" }),
	D("cometfairy", "Comet Fairy Glazetta", "Celestial", 25, 1.65e19, 14, rgb(40, 30, 90), rgb(255, 240, 160), STARS, { "Wings", "Tutu", "Orbit", "FairyWand" }),
	D("nebulily", "Nebulily Floretta", "Celestial", 25, 3.3e19, 4, rgb(50, 20, 90), rgb(200, 120, 255), STARS, { "Legs", "Leaf", "Wings", "Flower" }),
	D("starfallo", "Starfallo Supremo", "Celestial", 25, 7.08e19, 1, rgb(20, 15, 50), rgb(255, 230, 120), STARS, { "Wings", "Halo", "Crown", "Orbit", "FallingStars" }),
	-- 26. Aurora Palace
	D("aurorino", "Aurorino Borealino", "Legendary", 26, 2.83e19, 50, rgb(215, 240, 255), rgb(120, 255, 200), STARS, { "Legs", "IceSpikes", "AuroraRibbon" }),
	D("palazzonut", "Palazzo Donutto", "Celestial", 26, 5.09e19, 28, rgb(230, 240, 255), rgb(170, 215, 255), WHITE, { "Legs", "Cape", "IceCrown" }),
	D("icequeen", "Ice Queenerina", "Celestial", 26, 9.89e19, 14, rgb(220, 240, 255), rgb(150, 220, 255), WHITE, { "Legs", "Tutu", "IceCrown", "Snowflakes" }),
	D("prismaro", "Prismaro Lucentino", "Celestial", 26, 1.98e20, 4, rgb(240, 250, 255), rgb(255, 170, 255), RAINBOW, { "Wings", "Halo", "Orbit", "Prism" }),
	D("aurorarex", "Aurora Rex Glazorum", "Celestial", 26, 4.25e20, 1, rgb(30, 40, 80), rgb(120, 255, 200), RAINBOW, { "Wings", "Crown", "Orbit", "DinoSpikes", "AuroraRibbon" }),
	-- 27. Neon Streets
	D("pixelino", "Pixelino Bitterino", "Rare", 27, 1.7e20, 50, rgb(30, 30, 45), rgb(255, 40, 200), NEON, { "Legs", "Visor", "PixelBlocks" }),
	D("neonetto", "Neonetto Streeterino", "Epic", 27, 3.06e20, 28, rgb(30, 30, 45), rgb(0, 255, 220), NEON, { "Legs", "Arms", "Sunglasses", "NeonTube" }),
	D("arcadonut", "Arcadonut Joystickino", "Epic", 27, 5.94e20, 14, rgb(40, 40, 60), rgb(255, 220, 0), NEON, { "Legs", "Arms", "Antenna", "Joystick" }),
	D("billboardo", "Billboardo Glowino", "Legendary", 27, 1.19e21, 4, rgb(30, 30, 45), rgb(255, 90, 40), NEON, { "Legs", "Visor", "Cape", "Billboard" }),
	D("cyberskater", "Cyber Skaterino", "Legendary", 27, 2.55e21, 1, rgb(20, 20, 35), rgb(170, 90, 255), NEON, { "Legs", "Arms", "Visor", "Flames", "Skateboard" }),
	-- 28. Hologram Mall
	D("hologlaze", "Hologlaze Shopperino", "Epic", 28, 1.02e21, 50, rgb(200, 220, 240), rgb(0, 230, 255), NEON, { "Legs", "Arms", "CoffeeCup", "ShoppingBags" }),
	D("escalatoro", "Escalatoro Rollerino", "Epic", 28, 1.83e21, 28, rgb(180, 190, 210), rgb(120, 160, 255), WHITE, { "Legs", "Antenna", "HoloRing" }),
	D("mannequino", "Mannequino Posetto", "Legendary", 28, 3.56e21, 14, rgb(240, 240, 245), rgb(255, 255, 255), NEON, { "Legs", "Arms", "TopHat", "BowTie" }),
	D("vendomatico", "Vendomatico Snackerino", "Legendary", 28, 7.14e21, 4, rgb(60, 70, 100), rgb(255, 60, 90), NEON, { "Legs", "Arms", "Gears", "VendingMachine" }),
	D("holoqueen", "Holo Queen Glazerina", "Celestial", 28, 1.53e22, 1, rgb(180, 240, 255), rgb(0, 230, 255), RAINBOW, { "Legs", "Tutu", "Halo", "Tiara", "HoloRing" }),
	-- 29. Robot Factory
	D("boltino", "Boltino Screwerino", "Epic", 29, 6.11e21, 50, rgb(120, 125, 135), rgb(255, 190, 0), { rgb(60, 60, 70) }, { "Legs", "Gears", "Bolts" }),
	D("robodunk", "Robodunk 3000", "Legendary", 29, 1.1e22, 28, rgb(150, 155, 165), rgb(80, 160, 255), NEON, { "Legs", "Arms", "Antenna", "Visor", "RoboPlates", "RoboClaw" }),
	D("conveyoro", "Conveyoro Beltino", "Legendary", 29, 2.14e22, 14, rgb(90, 95, 105), rgb(255, 140, 0), EMBERS, { "Legs", "Gears", "Propeller", "ConveyorBelt" }),
	D("weldonut", "Weldonut Sparkino", "Celestial", 29, 4.28e22, 4, rgb(70, 70, 80), rgb(255, 220, 120), EMBERS, { "Legs", "Arms", "Visor", "Flames", "WeldMask" }),
	D("mechadonut", "Mecha Donut Prime", "Celestial", 29, 9.17e22, 1, rgb(60, 62, 70), rgb(255, 190, 0), GOLD, { "Legs", "Arms", "Gears", "Antenna", "Cape", "ShoulderCannons", "RoboPlates" }),
	-- 30. Data Highway
	D("bytecruller", "Byte Cruller", "Legendary", 30, 3.67e22, 50, rgb(15, 30, 45), rgb(40, 255, 120), NEON, { "Legs", "Antenna", "BinaryRing" }),
	D("packetino", "Packetino Routerino", "Legendary", 30, 6.6e22, 28, rgb(20, 35, 50), rgb(80, 200, 255), NEON, { "Legs", "Arms", "Antenna", "Visor", "Envelope" }),
	D("wifinut", "Wifinut Signalino", "Celestial", 30, 1.28e23, 14, rgb(20, 30, 45), rgb(120, 255, 160), NEON, { "Legs", "Orbit", "WifiArcs" }),
	D("fiberino", "Fiberino Opticello", "Celestial", 30, 2.57e23, 4, rgb(10, 20, 30), rgb(255, 255, 255), RAINBOW, { "Legs", "Tentacles", "FiberStrands" }),
	D("datadragon", "Data Dragonino", "Celestial", 30, 5.5e23, 1, rgb(10, 25, 20), rgb(40, 255, 120), NEON, { "Wings", "Horns", "Flames", "Orbit", "DragonTail", "BinaryRing" }),
	-- 31. Firewall Fortress
	D("firewallo", "Firewallo Blockerino", "Legendary", 31, 2.2e23, 50, rgb(60, 20, 20), rgb(255, 60, 40), EMBERS, { "Legs", "Arms", "Horns", "BrickShield" }),
	D("trojanut", "Trojanut Horsino", "Legendary", 31, 3.96e23, 28, rgb(120, 80, 50), rgb(255, 200, 90), EMBERS, { "Legs", "Visor", "TrojanHelmet" }),
	D("laserino", "Laserino Guardino", "Celestial", 31, 7.69e23, 14, rgb(40, 15, 15), rgb(255, 40, 40), EMBERS, { "Legs", "Arms", "Visor", "LaserSword" }),
	D("shieldonut", "Shieldonut Defendo", "Celestial", 31, 1.54e24, 4, rgb(80, 80, 90), rgb(255, 90, 60), GOLD, { "Legs", "Arms", "Cape", "Crown", "Shield" }),
	D("sentinelo", "Sentinelo Supremo", "Celestial", 31, 3.3e24, 1, rgb(30, 10, 10), rgb(255, 50, 30), EMBERS, { "Wings", "Horns", "Flames", "Orbit", "SentinelEye" }),
	-- 32. Glitch Zone
	D("glitchino", "Glitchino Glitchano", "Legendary", 32, 1.32e24, 50, rgb(20, 20, 20), rgb(255, 0, 200), NEON, { "Legs", "Antenna", "GlitchSlices" }),
	D("errorino", "Error 404 Donutto", "Celestial", 32, 2.38e24, 28, rgb(245, 245, 245), rgb(0, 120, 255), BLACK, { "Legs", "Arms", "Sunglasses", "ErrorSign" }),
	D("lagspikeo", "Lag Spikeo", "Celestial", 32, 4.62e24, 14, rgb(20, 20, 20), rgb(0, 255, 220), NEON, { "Legs", "IceSpikes", "Orbit", "LoadingRing" }),
	D("bluescreen", "Bluescreen Crashino", "Celestial", 32, 9.25e24, 4, rgb(20, 60, 200), rgb(40, 100, 255), WHITE, { "Legs", "Arms", "Fangs", "BlueScreen" }),
	D("missingno", "MissingDonut", "Celestial", 32, 1.98e25, 1, rgb(0, 0, 0), rgb(255, 0, 255), RAINBOW, { "Wings", "Tentacles", "Horns", "Orbit", "Checkerboard" }),
	-- 33. The Mainframe
	D("coreino", "Coreino Processore", "Celestial", 33, 7.92e24, 50, rgb(10, 12, 30), rgb(80, 160, 255), NEON, { "Legs", "CPUChip" }),
	D("quantumo", "Quantumo Qubitto", "Celestial", 33, 1.43e25, 28, rgb(15, 15, 40), rgb(200, 120, 255), STARS, { "Legs", "Orbit", "Halo", "AtomOrbits" }),
	D("servero", "Servero Rackino", "Celestial", 33, 2.77e25, 14, rgb(40, 45, 60), rgb(40, 255, 120), NEON, { "Legs", "Arms", "Antenna", "Visor", "ServerRack" }),
	D("aicore", "A.I. Donutronic", "Celestial", 33, 5.55e25, 4, rgb(240, 245, 255), rgb(80, 160, 255), STARS, { "Wings", "Halo", "Visor", "Orbit", "BrainDome" }),
	D("mainframeo", "Mainframo Supremo", "Celestial", 33, 1.19e26, 1, rgb(10, 12, 30), rgb(80, 200, 255), RAINBOW, { "Wings", "Crown", "Cape", "Orbit", "Halo", "BinaryRing" }),
	-- Secrets of the new areas, and World 4's ADMIN donut
	D("arcobalenosupremo", "Arcobaleno Supremo", "Secret", 12, 21_600_000_000, 0.02, rgb(255, 255, 255), rgb(255, 120, 220), RAINBOW, { "Wings", "Halo", "Crown", "Orbit", "RainbowArc" }),
	D("poseidonut", "Hadesnut Supremo", "Secret", 19, 6_120_000_000_000_000, 0.02, rgb(20, 10, 10), rgb(255, 70, 20), EMBERS, { "Horns", "Wings", "Orbit", "FlameHair", "Trident" }),
	D("auroraimperatrix", "Aurora Imperatrix", "Secret", 26, 1.7e21, 0.015, rgb(20, 30, 60), rgb(120, 255, 200), RAINBOW, { "Wings", "Crown", "Halo", "Orbit", "AuroraRibbon", "Scepter" }),
	D("antivirus", "Antivirus Supremo", "Secret", 31, 1.32e25, 0.02, rgb(20, 20, 20), rgb(255, 60, 40), EMBERS, { "Wings", "Crown", "Visor", "Orbit", "Shield" }),
	D("overclockus", "Overclockus Maximus", "Secret", 33, 4.75e26, 0.015, rgb(10, 10, 30), rgb(80, 160, 255), NEON, { "Wings", "Crown", "Flames", "Gears", "Orbit", "LightningBolt" }),
	D("singularity", "The Singularity Donut", "Secret", 33, 1.43e27, 0.006, rgb(0, 0, 0), rgb(20, 20, 20), STARS, { "Wings", "Halo", "Crown", "Orbit", "Cape", "Flames", "AccretionDisk" }),
	D("rootaccess", "Root Access Admino", "Admin", 33, 1.19e28, 0.004, rgb(15, 15, 20), rgb(255, 30, 40), ADMIN, { "Crown", "Sunglasses", "Cape", "Wings", "Orbit", "Antenna", "Terminal" }),

	---------------------------------------------------------------- Area 34: The Black Hole
	D("singularino", "Singularino Spaghettino", "Celestial", 34, 4.75e25, 50, rgb(20, 14, 40), rgb(150, 90, 255), STARS, { "Legs", "Orbit", "Spaghetti" }),
	D("eventhorizonte", "Event Horizonte", "Celestial", 34, 8.6e25, 28, rgb(10, 8, 20), rgb(255, 150, 60), STARS, { "Legs", "Arms", "Halo", "AccretionDisk" }),
	D("gravitoni", "Gravitoni Glazoni", "Celestial", 34, 1.66e26, 14, rgb(30, 20, 60), rgb(90, 200, 255), NEON, { "Legs", "Wings", "Orbit", "GravityRings" }),
	D("quasarino", "Quasarino Crullero", "Celestial", 34, 3.33e26, 4, rgb(15, 10, 30), rgb(255, 255, 255), STARS, { "Legs", "Arms", "Visor", "QuasarJets" }),
	D("supermassivo", "Supermassivo Sprinklo", "Celestial", 34, 7.1e26, 1, rgb(5, 5, 10), rgb(120, 60, 255), RAINBOW, { "Wings", "Crown", "Cape", "Orbit", "Halo", "AccretionDisk" }),
	D("wormholio", "Wormholio Infinitoni", "Secret", 34, 2.9e27, 0.012, rgb(0, 0, 0), rgb(170, 90, 255), STARS, { "Wings", "Halo", "Crown", "Orbit", "Tentacles", "Wormhole" }),
	-- The first ICON donut: the rarest natural spawn (about 1 in 70,000 spawns in The Black Hole)
	D("fakekar", "Fake Kar", "Icon", 34, 2.5e29, 0.0015, rgb(20, 30, 70), rgb(40, 140, 255), { rgb(255, 255, 255), rgb(120, 220, 255) }, { "Kart", "Sunglasses", "Crown", "Orbit" }),
	---------------------------------------------------------------- Limited time
	-- THE COSMIC DONUT: never in a box - crafted from 10 meteor shards at the Cosmic Forge while
	-- Config.CosmicDonut is on (the meteor falls halfway through the Eternal Storm). The best donut
	-- in the game: a black hole's horizon spins round it. (Its biome and income are set below.)
	D("cosmicdonut", "The Cosmic Donut", "Icon", 0, 0, 0, rgb(24, 14, 52), rgb(130, 60, 255), { rgb(255, 255, 255), rgb(120, 230, 255), rgb(255, 120, 220), rgb(255, 240, 150) }, { "Legs", "Arms", "CosmicHorizon", "GalaxySwirl", "FallingStars" }),
} :: { Donut }

-- Crafted donuts (only in the Index under The Black Hole): twice what the best donut in any box earns.
local CRAFTED = { cosmicdonut = true }

--------------------------------------------------------------------------------
-- Update 6: donuts come out of donut BOXES (Boxes.luau). Every donut above now lives in one of
-- the 17 biomes (Areas.luau) and in one of its boxes:
--   * BIOME_DONUTS: which of the old areas' donuts each biome's boxes hold (in the order above).
--   * Biome 1 only has the plain pink box: all its donuts are "Basic" box donuts.
--   * Everywhere else the donuts are sorted from weakest to best: the weakest ~40% are in the
--     Rare box, the next half of the rest in the Epic box and the best in the Legendary box.
--     Secret and Icon donuts are a tiny chance (SECRET_WEIGHT) inside the Legendary box.
--   * Inside a box the weaker donuts are the common ones (each one ~half as likely as the one
--     before) and the rarer ones earn more; on average a box's donut earns
--     BIOME_INCOME[biome] x TIER_INCOME[box].
-- Admin donuts never come out of a box (only the admin panel makes them).
--------------------------------------------------------------------------------
local BIOME_DONUTS: { { number } } = {
	{ 1, 2 }, -- 1 Sprinkle Park
	{ 4, 14 }, -- 2 Frosting Falls
	{ 3, 19 }, -- 3 Sugar Dunes
	{ 16, 18 }, -- 4 Jellybean Jungle
	{ 6, 12 }, -- 5 Glacier Glaze
	{ 7, 17 }, -- 6 Molten Bakery
	{ 5, 15 }, -- 7 Chocolate Caverns
	{ 11, 13 }, -- 8 Candy Cane Canyon
	{ 21 }, -- 9 Toy Factory
	{ 22 }, -- 10 Haunted Donuttery
	{ 20, 9 }, -- 11 Cloud Bakery (+ the crystal donuts)
	{ 27, 8 }, -- 12 Neon Streets
	{ 29, 28 }, -- 13 Robot Factory
	{ 23, 25 }, -- 14 Clockwork Void (+ the starfall donuts)
	{ 24, 26, 10 }, -- 15 Donut Heaven (+ the aurora and celestial donuts)
	{ 32, 30, 31 }, -- 16 Glitch Zone
	{ 34, 33 }, -- 17 The Black Hole
}

-- Money per second of an average x1 donut in each biome (level 1, no mutation, normal size); each
-- box multiplies it (TIER_INCOME: a Rare box x1 ... a Mythic box x30).
-- Tuned with the economy sim (see Config.Treadmill).
local BIOME_INCOME = {
	7, 22, 72, 230, 730, 2_350, 8_700, 32_000, 120_000, 440_000,
	1_630_000, 9_800_000, 59_000_000, 350_000_000, 2_100_000_000, 12_700_000_000, 76_000_000_000,
}
local TIER_INCOME: { [string]: number } = { Basic = 1, Rare = 1, Epic = 3, Legendary = 10, Mythic = 30 }
local SECRET_WEIGHT = 0.4 -- % of the biome's rarest box (each Secret / Icon donut)
local SECRET_INCOME = 8 -- x the average of the biome's rarest box

local oldArea: { [string]: number } = {}
for _, donut in Donuts.List do
	oldArea[donut.Id] = donut.Area
end

-- Weights and income factors for `count` donuts in one box: each is ~55% as likely as the one
-- before and earns 1.45x more, scaled so the box's average income factor is exactly 1.
local function spread(count: number): ({ number }, { number })
	local w, f = {}, {}
	local totalW, mean = 0, 0
	for i = 1, count do
		w[i] = 100 * 0.55 ^ (i - 1)
		f[i] = 1.45 ^ (i - 1)
		totalW += w[i]
	end
	for i = 1, count do
		mean += w[i] / totalW * f[i]
	end
	for i = 1, count do
		f[i] /= mean
	end
	return w, f
end

local function assign(list: { Donut }, biome: number, box: string)
	local weights, factors = spread(#list)
	for i, donut in list do
		donut.Area = biome
		donut.Box = box
		donut.Weight = weights[i]
		donut.Income = BIOME_INCOME[biome] * TIER_INCOME[box] * factors[i]
	end
end

for biome, sources in BIOME_DONUTS do
	-- the biome's boxes, most common first: Rare / Epic / Legendary, or Epic / Legendary / Mythic
	local tiers = Boxes.TiersFor(biome)
	local top = tiers[#tiers].Id
	local regular, special = {}, {}
	for _, area in sources do
		for _, donut in Donuts.List do
			if oldArea[donut.Id] == area then
				local rarity = Rarities.Get(donut.Rarity)
				if rarity.AdminOnly then
					donut.Area = biome
					donut.Box = nil
					donut.Weight = 0
					donut.Income = BIOME_INCOME[biome] * TIER_INCOME[top] * SECRET_INCOME * 2
				elseif donut.Rarity == "Secret" or donut.Rarity == "Icon" then
					table.insert(special, donut)
				else
					table.insert(regular, donut)
				end
			end
		end
	end
	table.sort(regular, function(a, b)
		return a.Income < b.Income
	end)
	if #tiers == 1 then
		assign(regular, biome, tiers[1].Id)
	else
		-- the cheapest 40% in the common box, half the rest in the middle one, the best in the rarest
		local common = math.ceil(#regular * 0.4)
		local middle = math.ceil((#regular - common) * 0.5)
		local lists = { {}, {}, {} }
		for i, donut in regular do
			table.insert(lists[if i <= common then 1 elseif i <= common + middle then 2 else 3], donut)
		end
		for i, tier in tiers do
			assign(lists[i], biome, tier.Id)
		end
		local topWeight = 0
		for _, donut in lists[3] do
			topWeight += donut.Weight
		end
		for _, donut in special do
			donut.Area = biome
			donut.Box = top
			donut.Weight = topWeight * SECRET_WEIGHT / 100
			donut.Income = BIOME_INCOME[biome] * TIER_INCOME[top] * SECRET_INCOME * (if donut.Rarity == "Icon" then 3 else 1)
		end
	end
end
local best = 0
for _, donut in Donuts.List do
	if not CRAFTED[donut.Id] then
		best = math.max(best, donut.Income)
	end
end
for _, donut in Donuts.List do
	if CRAFTED[donut.Id] then
		donut.Crafted = true
		donut.Area = #Areas.List
		donut.Box = nil
		donut.Weight = 0
		donut.Income = best * 2
	end
end
for _, donut in Donuts.List do
	assert(donut.Area >= 1 and donut.Area <= #Areas.List and (donut.Box ~= nil or Rarities.Get(donut.Rarity).AdminOnly or donut.Crafted), "Donut not in any biome's boxes: " .. donut.Id)
end

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

-- A donut counts as "rare" for luck boosts when its chance inside its box is under this.
Donuts.RareChance = 0.1

-- Can this donut come out of a box by itself? Admin donuts can't: only the admin panel makes them.
function Donuts.Spawnable(donut: Donut): boolean
	return donut.Box ~= nil and not Rarities.ById[donut.Rarity].AdminOnly
end

-- Every donut of a biome's box (in list order).
Donuts.ByBox = {} :: { [number]: { [string]: { Donut } } }
for _, donut in Donuts.List do
	if donut.Box then
		local biome = Donuts.ByBox[donut.Area] or {}
		Donuts.ByBox[donut.Area] = biome
		biome[donut.Box] = biome[donut.Box] or {}
		table.insert(biome[donut.Box], donut)
	end
end

-- Weight of every donut in a box. `luck` multiplies the weight of every rare one (Luck Event).
local function weights(biome: number, box: string, luck: number?): ({ Donut }, { number }, number)
	local pool = Donuts.ByBox[biome] and Donuts.ByBox[biome][box]
	assert(pool and #pool > 0, `No donuts in biome {biome}'s {box} box`)
	local boost = luck or 1
	local base = 0
	for _, donut in pool do
		base += donut.Weight
	end
	local list, total = {}, 0
	for i, donut in pool do
		local rare = donut.Weight / base < Donuts.RareChance
		local weight = if boost ~= 1 and rare then donut.Weight * boost else donut.Weight
		list[i] = weight
		total += weight
	end
	return pool, list, total
end

-- Does this biome have this box?
function Donuts.HasBox(biome: number, box: string): boolean
	local pools = Donuts.ByBox[biome]
	return pools ~= nil and pools[box] ~= nil and #pools[box] > 0
end

-- The donut that comes out of a box from `biome`. `luck` boosts the rare ones (Luck Event).
function Donuts.Roll(biome: number, box: string, rng: Random, luck: number?): Donut
	local pool, list, total = weights(biome, box, luck)
	local left = rng:NextNumber() * total
	for i, donut in pool do
		left -= list[i]
		if left <= 0 then
			return donut
		end
	end
	return pool[#pool]
end

-- Chance (0-1) that the donut's box gives this donut (0 for admin-only donuts). `luck` = the Luck
-- Event's rarity boost, so the Index can show the boosted odds while it runs.
function Donuts.Chance(donut: Donut, luck: number?): number
	if not donut.Box then
		return 0
	end
	local pool, list, total = weights(donut.Area, donut.Box, luck)
	return list[table.find(pool, donut) :: number] / total
end

return Donuts
