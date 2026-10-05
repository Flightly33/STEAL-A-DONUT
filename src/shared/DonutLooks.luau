--[[
	DonutLooks
	==========
	A donut's personality, read from its NAME (and its accessories, rarity and colours), so no two
	donuts are built the same way (DonutModel builds it, DonutLayers adds the layers):

	  * Mood: the face. "Cute" (big shiny eyes, the default), "Happy" (open smile), "Fierce"
	    (angry brows, fiery eyes, a toothy grin: lava, dragons, sharks...), "Mighty" (strong
	    names: determined brows, see Muscles), "Silly" (one big eye, tongue out: Tung Tung, Brr
	    Brr...), "Cool" (half-closed eyes and a smirk), "Dreamy" (sleepy lids and lashes: clouds,
	    angels, moons), "Royal" (lashes and a calm smile: kings and queens), "Spooky" (dark eyes
	    with glowing pupils: ghosts, vampires) and "Robot" (glowing screen eyes).
	  * Eyes: "Heart" swaps the eyes for big anime eyes with heart-shaped shines; "Spiral" for dizzy
	    anime eyes with swirly irises, worried brows and a drooling "o" mouth (only by Overrides).
	  * Effects: false = no aura or glow of its own (DonutAuras); BiomeDetails: false = none of its
	    biome's little touches (DonutExtras.Theme); Scale: a smaller or bigger donut;
	    Rim: the outer glaze layer (round the rim and the hole) in another colour; HoleColor: a band
	    of another colour round the edge of the hole; HoleLining: the inside of its hole glazed too
	    (in HoleColor, if it has one).
	  * Muscles: 0, 1 (toned arms: fighters and guards) or 2 (huge flexing arms and a champion
	    belt: Maximus, Supremus, Odin, Zeus, -zilla...). A strong donut gets arms if it has none.
	  * Feet: "Sneakers" (in the donut's own colours), "HighTops", "Boots", "Paws" (with toe
	    beans), "Hooves", "Claws", "Webbed", "Robot", "Sandals", or "Plain" (accessories that
	    restyle the shoes themselves: ballet slippers, flamingo legs).
	  * Glaze: "Glossy" (two layers of glaze and a shine), "TwoTone" (the raised middle of the glaze
	    in a second colour), "HalfDip" (only the top dipped, drips at the edge), "Drippy" (drips
	    over the edges and into the hole) or "MegaDrip" (glaze pouring off it everywhere).
	  * Marking: a pattern on the glaze from the name - "Drizzle", "Stripes", "Spots", "Bolts",
	    "Flames", "Runes", "Hearts", "Scales", "Swirls" or "Stars". Legendary and up glow.
	  * Sprinkles: "Jimmies" (rods), "Nonpareils" (tiny beads), "Confetti" (flat squares) or
	    "Chunks" (chocolate-chip chunks).

	Everything here is plain data (DonutLooks.For is pure), so it's cheap and easy to test.
]]

local DonutLooks = {}

export type Look = {
	Mood: string,
	Eyes: string,
	Iris: Color3,
	GlowEyes: boolean,
	Lashes: boolean,
	Muscles: number,
	Feet: string,
	Shoe: Color3,
	ShoeAccent: Color3,
	Sole: Color3,
	Glaze: string,
	Accent: Color3,
	Marking: string?,
	MarkGlow: boolean,
	Sprinkles: string,
	Tilt: number, -- radians the face leans (head tilt)
	Effects: boolean,
	BiomeDetails: boolean,
	Scale: number,
	Rim: Color3?,
	HoleColor: Color3?,
	HoleLining: boolean,
}

local rgb = Color3.fromRGB
local WHITE = rgb(255, 255, 255)
local BLACK = rgb(30, 30, 36)

-- Per-donut choices that beat whatever the name says.
DonutLooks.Overrides = {
	tradonut = { Shoe = rgb(40, 110, 235), ShoeAccent = WHITE }, -- Tralalero's blue sneakers
	tralalerobeach = { Shoe = rgb(40, 110, 235), ShoeAccent = rgb(255, 140, 40) },
	frigocamel = { Feet = "Boots" }, -- Frigo Camelo wears boots
	lirililarila = { Feet = "Sandals" },
} :: { [string]: { [string]: any } }

local function hashString(text: string): number
	local hash = 17
	for i = 1, #text do
		hash = (hash * 37 + string.byte(text, i)) % 2147483647
	end
	return hash
end

local function brightness(c: Color3): number
	return c.R * 0.299 + c.G * 0.587 + c.B * 0.114
end

local function saturation(c: Color3): number
	return math.max(c.R, c.G, c.B) - math.min(c.R, c.G, c.B)
end

-- Sneaker colours: { shoe, stripe, sole }
local SNEAKERS = {
	{ rgb(230, 45, 55), WHITE, WHITE },
	{ rgb(40, 110, 235), WHITE, WHITE },
	{ rgb(35, 35, 42), WHITE, WHITE },
	{ rgb(245, 245, 248), rgb(230, 40, 50), rgb(200, 200, 208) },
	{ rgb(60, 190, 80), rgb(255, 220, 60), WHITE },
	{ rgb(140, 70, 220), rgb(255, 140, 210), WHITE },
	{ rgb(255, 130, 30), BLACK, WHITE },
	{ rgb(255, 120, 180), WHITE, WHITE },
	{ rgb(30, 185, 190), WHITE, WHITE },
	{ rgb(255, 205, 40), BLACK, WHITE },
}

local IRISES = {
	rgb(110, 70, 40), -- brown
	rgb(60, 140, 255), -- blue
	rgb(50, 175, 90), -- green
	rgb(150, 90, 230), -- violet
	rgb(30, 175, 185), -- teal
	rgb(175, 120, 40), -- hazel
	rgb(235, 90, 160), -- pink
}

-- Name keywords. A keyword matches the start of any word in the donut's name or its id
-- ("rex" matches "Rexorino" but not "Fluorex"); one ending in "$" has to be the whole word.
local KEYS = {
	Spooky = { "ghost", "boo", "spook", "soul", "vampir", "skeleton", "witch", "wisp", "bone", "phantom", "zombie", "haunt" },
	Robot = { "robo", "mecha", "glazobot", "servero", "donutronic", "processore", "mainframo", "sentinelo", "antivirus", "weldonut", "vendomatico", "conveyoro", "boltino", "a.i." },
	Silly = { "tung", "brr", "trippi", "troppi", "yo-yo", "glazoyo", "lirili", "tralalero", "chimpanz", "bobrito", "sahur", "jack", "gumdroppa", "spaghett", "lag", "missingdonut", "patadonut" },
	Fierce = { "infern", "magma", "lava", "devil", "imp$", "impolo", "dragon", "rex", "shark", "scorch", "croc", "bomb", "blast", "blaze", "ember", "flamb", "volcan", "erupt", "crab", "tigr", "tiger", "pirat", "captain", "basalt", "obsidian", "cinda", "flame", "fire", "molten", "crullfire", "katana" },
	Royal = { "king", "queen", "imperatrix", "pharaoh", "glazamun", "grande", "palazzo", "prince", "final", "omnidonut", "supremo", "supremito", "eternal", "infinit", "goldino", "treasurino", "idolonut" },
	Dreamy = { "cloud", "angel", "heaven", "seraph", "harp", "moon", "dream", "petal", "bloom", "fairy", "nebul", "cumulus", "puffino", "floretta", "aurora", "comet" },
	Cool = { "surf", "skater", "neonetto", "street", "billboard", "cool", "neonino" },
	Happy = { "candy", "lollipop", "sprink", "strawberr", "rainbow", "arcobal", "teddy", "toy", "gum", "sugar", "sweet", "party" },

	Mighty = { "maximus", "maxima", "supremus", "zilla", "glazilla", "crullazilla", "odin", "zeus", "hades", "titan", "prime", "banhammer", "overclockus" },
	Toned = { "forgy", "firewallo", "shieldonut", "sentinelo", "antivirus", "soldier", "archangelo", "crashino", "guardino", "defendo", "blockerino" },

	Webbed = { "pinguino", "duck", "goose" },
	Paws = { "cat", "tigr", "tiger", "chimp", "monkey", "teddy", "yeti", "bear", "wolf", "lion", "dog", "pup", "kitty", "bobrito", "trippi", "patadonut" },
	Hooves = { "vaca", "cow", "camel", "trojan", "horse", "devil", "infernolino", "imp$", "impolo", "goat" },
	Claws = { "dragon", "rex", "zilla", "glazilla", "crullazilla", "croc", "dino", "raptor", "lizard", "phoenix", "parrot", "toucan", "glazarrot", "soulcanino" },
	Boots = { "soldier", "pirat", "captain", "cowboy", "frigo", "odin", "viking", "chocolatto", "summitino", "witch", "knight", "archangelo", "shieldonut", "sentinelo", "firewallo", "hades", "zeusino", "laserino" },
	Sandals = { "lirili", "pharaoh", "glazamun", "surf", "wavino", "beach", "laguna", "idolonut", "templ" },
	HighTops = { "skater", "street", "neonetto", "arcadonut", "pixel", "sahur" },

	Drippy = { "fudge", "caramel", "lava", "magma", "molten", "drip", "jelly", "honey", "syrup", "slime", "ooze", "melt", "eruptus", "volcan", "lavaccino", "lavalino" },
	HalfDip = { "dunk", "dip" },

	Drizzle = { "choco", "cocoa", "fudge", "mocha", "cappucc", "coffee", "caramel", "kreme", "boston", "cavern", "charcoal" },
	Stripes = { "tigr", "tiger", "zebra", "stripol", "bee", "wasp" },
	Spots = { "vaca", "cow", "leopard", "cheetah", "dalmat", "ladybug", "puffer", "jaguar", "spot" },
	Bolts = { "zeus", "bolt", "thunder", "storm", "overclock", "volt", "electr", "spark" },
	Flames = { "flame", "blaze", "infern", "fire", "scorch", "ember", "burn", "flamb", "cinda", "hellfire", "crullfire" },
	Runes = { "odin", "rune", "idol", "pharaoh", "glazamun", "templ", "ancient", "chrono", "eternal", "mystic" },
	Hearts = { "teddy", "love", "amor", "heart", "sweet", "lollipop", "cupid", "strawberr" },
	Scales = { "dragon", "rex", "zilla", "glazilla", "crullazilla", "croc", "dino", "basalt" },
	Swirls = { "soul", "wisp", "spirit", "aurora", "dream", "galax", "nebul", "cosmo", "void", "quantum", "infinit", "wormhol", "singular" },
	Stars = { "star", "comet", "astro", "cosmic", "nova", "supernova" },

	Chunks = { "choco", "cocoa", "fudge", "cookie", "charcoal", "basalt", "obsidian", "rocky", "cavern" },
	Nonpareils = { "pearl", "crystal", "amethyst", "prism", "diamond", "frost", "ice", "glacier", "snow" },
	Confetti = { "party", "confetti", "arcade", "pixel", "glitch", "toy", "jack" },
}

-- Accessories that already paint the same pattern (no double layers).
local SAME_PATTERN = {
	Stripes = { "TigerStripes", "CandyCane", "PeppermintSwirl" },
	Spots = { "CowSpots" },
	Drizzle = { "CaramelDrips" },
	Swirls = { "CinnamonSwirl", "GalaxySwirl" },
}

-- Glowing eyes for these moods once a donut is rare enough.
local IRIS_BY_MOOD: { [string]: Color3 } = {
	Spooky = rgb(120, 255, 150),
	Robot = rgb(60, 230, 255),
	Fierce = rgb(255, 150, 30),
	Mighty = rgb(255, 90, 50),
	Royal = rgb(160, 90, 255),
	Dreamy = rgb(200, 140, 255),
}

function DonutLooks.For(donut: { Id: string, Name: string, Rarity: string, Frosting: Color3, Dough: Color3, Sprinkles: { Color3 }?, Parts: { string } }, rarityOrder: number): Look
	local words = {}
	for word in string.gmatch(string.lower(donut.Name .. " " .. donut.Id), "[^%s]+") do
		table.insert(words, word)
	end
	local function any(list: { string }): boolean
		for _, key in list do
			for _, word in words do
				if string.sub(key, -1) == "$" then
					if word == string.sub(key, 1, -2) then
						return true
					end
				elseif string.sub(word, 1, #key) == key then
					return true
				end
			end
		end
		return false
	end
	local parts = {}
	for _, name in donut.Parts do
		parts[name] = true
	end
	local hash = hashString(donut.Id)
	local function pick<T>(list: { T }, salt: number): T
		return list[(math.floor(hash / salt) % #list) + 1]
	end

	-- Muscles: strong names (and the donuts that carry a big hammer or a shield)
	local muscles = if any(KEYS.Mighty) then 2
		elseif any(KEYS.Toned) or parts.ForgeHammer or parts.Shield or parts.BrickShield or parts.Banhammer or parts.Sword then 1
		else 0

	-- Mood
	local mood = "Cute"
	if any(KEYS.Spooky) or parts.GhostTail then
		mood = "Spooky"
	elseif any(KEYS.Robot) or parts.RoboPlates then
		mood = "Robot"
	elseif muscles > 0 then
		mood = "Mighty"
	elseif any(KEYS.Silly) then
		mood = "Silly"
	elseif any(KEYS.Fierce) or parts.Fangs or parts.DevilTail then
		mood = "Fierce"
	elseif any(KEYS.Royal) or (parts.Crown and rarityOrder >= 6) then
		mood = "Royal"
	elseif any(KEYS.Dreamy) or parts.CloudPuffs then
		mood = "Dreamy"
	elseif any(KEYS.Cool) or parts.Sunglasses or parts.Visor then
		mood = "Cool"
	elseif any(KEYS.Happy) or hash % 3 == 0 then
		mood = "Happy"
	end

	local iris = IRIS_BY_MOOD[mood] or pick(IRISES, 7)
	local glowEyes = mood == "Spooky" or mood == "Robot" or (rarityOrder >= 6 and IRIS_BY_MOOD[mood] and true or false)
	local lashes = mood == "Royal" or mood == "Dreamy" or parts.Tiara == true or parts.Tutu == true or parts.Bow == true

	-- Feet
	local feet = "Sneakers"
	if parts.FlamingoLegs or parts.BalletSlippers or parts.Flippers then
		feet = "Plain"
	elseif any(KEYS.Webbed) then
		feet = "Webbed"
	elseif mood == "Robot" then
		feet = "Robot"
	elseif any(KEYS.Claws) or parts.DragonTail or parts.DinoSpikes or parts.CrocSnout then
		feet = "Claws"
	elseif any(KEYS.Paws) or parts.CatEars or parts.MonkeyEars or parts.FurTufts then
		feet = "Paws"
	elseif any(KEYS.Hooves) or parts.DevilTail or parts.Camel or parts.CowBell then
		feet = "Hooves"
	elseif any(KEYS.Boots) or muscles > 0 or parts.PirateHat or parts.MinerHelmet or parts.Busby or parts.WitchHat then
		feet = "Boots"
	elseif any(KEYS.Sandals) or parts.Pharaoh then
		feet = "Sandals"
	elseif any(KEYS.HighTops) then
		feet = "HighTops"
	end
	local sneaker = pick(SNEAKERS, 11)
	local shoe, shoeAccent, sole = sneaker[1], sneaker[2], sneaker[3]
	if saturation(donut.Frosting) > 0.3 and (hash % 5) < 2 then
		-- shoes to match the glaze
		shoe, shoeAccent, sole = donut.Frosting:Lerp(BLACK, 0.12), WHITE, WHITE
	end
	-- (for the other feet: Shoe = the foot, ShoeAccent = buckle / toe beans / claws..., Sole = the bottom)
	if feet == "Boots" then
		shoe, shoeAccent, sole = pick({ rgb(95, 60, 35), rgb(40, 38, 46), rgb(120, 35, 45), rgb(70, 75, 92) }, 13), rgb(255, 200, 60), rgb(40, 32, 28)
	elseif feet == "Paws" then
		local fur = donut.Dough:Lerp(WHITE, 0.12)
		shoe, shoeAccent, sole = fur, rgb(255, 150, 175), fur:Lerp(BLACK, 0.3)
	elseif feet == "Hooves" then
		shoe, shoeAccent, sole = rgb(70, 55, 50), donut.Dough:Lerp(WHITE, 0.55), rgb(30, 24, 22)
	elseif feet == "Claws" then
		local scales = donut.Frosting:Lerp(BLACK, 0.3)
		shoe, shoeAccent, sole = scales, rgb(245, 238, 220), scales:Lerp(WHITE, 0.2)
	elseif feet == "Robot" then
		shoe, shoeAccent, sole = rgb(150, 155, 168), iris, rgb(50, 52, 60)
	elseif feet == "Webbed" then
		shoe, shoeAccent, sole = rgb(255, 150, 40), rgb(225, 105, 20), rgb(225, 105, 20)
	elseif feet == "Sandals" then
		shoe, shoeAccent, sole = donut.Dough, pick({ rgb(230, 60, 60), rgb(60, 140, 240), rgb(255, 200, 60) }, 13), rgb(150, 95, 50)
	end

	-- Glaze
	local glaze = "Glossy"
	if any(KEYS.Drippy) or parts.LavaDrips or parts.FudgeDrips or parts.JellyOoze then
		glaze = "Drippy"
	elseif any(KEYS.HalfDip) or (rarityOrder <= 3 and hash % 7 == 0) then
		glaze = "HalfDip"
	elseif hash % 4 == 1 then
		glaze = "TwoTone"
	end
	local accent
	local sprinkles = donut.Sprinkles
	if any(KEYS.Drizzle) then
		accent = if brightness(donut.Frosting) < 0.45 then rgb(255, 245, 230) else rgb(105, 60, 35)
	elseif sprinkles and #sprinkles > 0 and math.abs(brightness(sprinkles[1]) - brightness(donut.Frosting)) > 0.18 then
		accent = sprinkles[1]
	elseif brightness(donut.Frosting) < 0.5 then
		accent = donut.Frosting:Lerp(WHITE, 0.6)
	else
		accent = donut.Frosting:Lerp(BLACK, 0.35)
	end

	-- Marking
	local marking: string? = nil
	for _, name in { "Drizzle", "Bolts", "Flames", "Runes", "Stripes", "Spots", "Scales", "Hearts", "Swirls", "Stars" } do
		if any(KEYS[name]) then
			marking = name
			break
		end
	end
	if marking and SAME_PATTERN[marking] then
		for _, accessory in SAME_PATTERN[marking] do
			if parts[accessory] then
				marking = nil
				break
			end
		end
	end
	if not marking and rarityOrder >= 6 then
		marking = "Swirls" -- the rarest donuts all get glowing swirls (like the mythical creatures)
	end
	if not marking and glaze == "Glossy" and rarityOrder >= 3 and hash % 3 == 0 then
		marking = "Drizzle"
	end

	local sprinkleStyle = "Jimmies"
	if any(KEYS.Chunks) then
		sprinkleStyle = "Chunks"
	elseif any(KEYS.Nonpareils) then
		sprinkleStyle = "Nonpareils"
	elseif any(KEYS.Confetti) then
		sprinkleStyle = "Confetti"
	elseif hash % 6 == 2 then
		sprinkleStyle = "Nonpareils"
	elseif hash % 6 == 4 then
		sprinkleStyle = "Confetti"
	end

	local look: Look = {
		Mood = mood,
		Eyes = "Round",
		Iris = iris,
		GlowEyes = glowEyes,
		Lashes = lashes,
		Muscles = muscles,
		Feet = feet,
		Shoe = shoe,
		ShoeAccent = shoeAccent,
		Sole = sole,
		Glaze = glaze,
		Accent = accent,
		Marking = marking,
		MarkGlow = rarityOrder >= 5,
		Sprinkles = sprinkleStyle,
		Tilt = 0,
		Effects = true,
		BiomeDetails = true,
		Scale = 1,
		Rim = nil,
		HoleColor = nil,
		HoleLining = false,
	}
	local override = DonutLooks.Overrides[donut.Id]
	if override then
		for key, value in override do
			(look :: any)[key] = value
		end
	end
	return look
end

return DonutLooks
