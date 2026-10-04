--[[
	DonutAuras
	==========
	Every Epic-and-up donut gets its OWN signature aura, read from its name, its accessories and the
	biome it comes from - no two rare donuts share the same set of effects.

	  * Its main ELEMENT comes from its name ("Magma..." -> Inferno, "Ghost..." -> Phantom,
	    "...Maximus" -> Power), else its accessories (a halo -> Divine, gears -> Clockwork), else
	    its biome (The Black Hole -> Void). A second element (the next match, or its biome's) mixes
	    in, so two fire donuts still look different.
	  * Each element has its own effects, best first: Inferno has flames, rising embers, bolts from
	    the ground...; Frost has falling snow, snowflakes circling it, a cold haze...
	  * Rarer donuts get more of them: Epic 2, Legendary 3, Celestial 4, Secret and Admin 5, Icon 6.
	    Which of its element's effects it gets, how fast and which way they turn depend on the donut
	    itself, and no two donuts get the same set (each is checked against all the donuts before it).
	  * The colours are the element's, tinted with the donut's own glaze.

	A mutation's effects (FXThemes) are added on top: they show what was rolled. DonutLooks can turn
	a donut's own effects off (Effects = false: Miha Jon).

	Pure data: DonutModel (server parts) and client/DonutFX (moving parts) build the same thing.
]]

local Areas = require(script.Parent.Areas)
local FXThemes = require(script.Parent.FXThemes)
local DonutLooks = require(script.Parent.DonutLooks)
local Rarities = require(script.Parent.Rarities)
local Donuts = require(script.Parent.Donuts)

type Theme = FXThemes.Theme

local DonutAuras = {}

local rgb = Color3.fromRGB
local WHITE = rgb(255, 255, 255)

type Donut = { Id: string, Name: string, Rarity: string, Area: number, Frosting: Color3, Dough: Color3, Sprinkles: { Color3 }?, Parts: { string } }

-- A move fills in a few theme fields. `i` = intensity (0.6 for Epic ... 1.6 for Icon), `r` = the
-- donut's own random numbers, `c` = the aura's colours.
type Move = (t: Theme, i: number, r: Random, c: { Color3 }) -> ()

local function spin(r: Random): number
	return (if r:NextNumber() < 0.5 then -1 else 1) * r:NextNumber(0.25, 0.6)
end

local Moves: { [string]: Move } = {
	flames = function(t, _i, _r, c)
		t.Flames = { c[2]:Lerp(WHITE, 0.3), c[1], c[3] }
	end,
	aura = function(t, _i, _r, c)
		-- a rising "power up" aura of energy flames in its own colours
		t.Flames = { WHITE, c[1]:Lerp(WHITE, 0.3), c[1] }
	end,
	embers = function(t, i, _r, _c)
		t.Drift = { Mode = "Rise", Rate = 12 * i, Size = 0.22, Texture = "Spark" }
	end,
	snow = function(t, i, _r, _c)
		t.Drift = { Mode = "Fall", Rate = 10 * i, Size = 0.32, Texture = "Spark" }
	end,
	petals = function(t, i, _r, _c)
		t.Drift = { Mode = "Fall", Rate = 7 * i, Size = 0.4, Texture = "Smoke" }
	end,
	feathers = function(t, i, _r, _c)
		t.Drift = { Mode = "Fall", Rate = 4 * i, Size = 0.6, Texture = "Smoke" }
	end,
	bubbles = function(t, i, _r, _c)
		t.Drift = { Mode = "Rise", Rate = 6 * i, Size = 0.45, Texture = "Smoke" }
	end,
	steam = function(t, i, _r, _c)
		t.Drift = { Mode = "Rise", Rate = 3 * i, Size = 1.4, Texture = "Smoke" }
	end,
	confetti = function(t, i, _r, _c)
		t.Drift = { Mode = "Burst", Rate = 14 * i, Size = 0.3, Texture = "Spark" }
	end,
	streaks = function(t, i, _r, _c)
		t.Drift = { Mode = "Streak", Rate = 14 * i, Size = 0.35, Texture = "Spark" }
	end,
	electric = function(t, i, _r, c)
		t.Electric = { Rate = 1.5 * i, Colors = { WHITE, c[1] } }
	end,
	arcs = function(t, i, r, _c)
		t.Lightning = { Min = r:NextNumber(0.8, 1.4) / i, Max = r:NextNumber(2, 3) / i, Mode = "Arc" }
	end,
	strike = function(t, i, r, _c)
		t.Lightning = { Min = r:NextNumber(1.6, 2.4) / i, Max = r:NextNumber(3.5, 5) / i, Mode = "Strike" }
	end,
	rise = function(t, i, r, _c)
		t.Lightning = { Min = r:NextNumber(1, 1.6) / i, Max = r:NextNumber(2.4, 3.4) / i, Mode = "Rise" }
	end,
	shockwave = function(t, i, r, _c)
		t.Shockwave = { Min = r:NextNumber(2.5, 3.5) / i, Max = r:NextNumber(4.5, 6) / i }
	end,
	swirl = function(t)
		t.Swirl = true
	end,
	smoke = function(t, _i, _r, c)
		t.Smoke = c[3]:Lerp(rgb(0, 0, 0), 0.5)
	end,
	shards = function(t, i, _r, c)
		t.Shards = { Count = math.max(3, math.round(6 * i)), Colors = { c[1], c[2], c[3] } }
	end,
	runes = function(t)
		t.Runes = true
	end,
	wisps = function(t, i)
		t.Wisps = math.max(2, math.round(3 * i))
	end,
	rays = function(t, _i, r, _c)
		t.Rays = { Count = 8 + 2 * r:NextInteger(0, 2), Length = r:NextNumber(4, 5.4), Spin = spin(r) }
	end,
	godrays = function(t)
		t.GodRays = true
	end,
	stars = function(t, i, r, _c)
		t.Stars = { Rate = 9 * i, Radius = r:NextNumber(3, 4) }
	end,
	vortex = function(t, i, r, _c)
		t.Vortex = { Rate = 18 * i, Radius = r:NextNumber(3, 3.8) }
	end,
	glitter = function(t, i, r, _c)
		t.Glitter = { Rate = 14 * i, Radius = r:NextNumber(2.6, 3.4) }
	end,
	mist = function(t, _i, _r, c)
		t.Mist = c[1]
	end,
	crystals = function(t)
		t.Crystals = true
	end,
	galaxy = function(t)
		t.Tint = "Galaxy"
	end,
	rainbow = function(t)
		t.Tint = "Rainbow"
	end,
}
for _, shape in { "Heart", "Star", "Coin", "Bubble", "Cube", "Note", "Leaf", "Snowflake", "Gear", "Bolt", "Feather" } do
	Moves["orbit" .. shape] = function(t, i)
		t.Orbiters = { Shape = shape, Count = math.max(3, math.round(5 * i)) }
	end
end

-- The field each move fills (a donut never gets two moves that fill the same one).
local function field(move: string): string
	if string.sub(move, 1, 5) == "orbit" then
		return "Orbiters"
	end
	local fields = {
		flames = "Flames", aura = "Flames", embers = "Drift", snow = "Drift", petals = "Drift", feathers = "Drift",
		bubbles = "Drift", steam = "Drift", confetti = "Drift", streaks = "Drift", arcs = "Lightning",
		strike = "Lightning", rise = "Lightning", galaxy = "Tint", rainbow = "Tint",
	}
	return fields[move] or move
end

export type Element = {
	Id: string,
	Keys: { string }, -- name keywords (the start of a word)
	Parts: { string }, -- accessories that bring it
	Biomes: { string }, -- biome themes that bring it
	Colors: { Color3 },
	Pulse: string,
	Moves: { string }, -- best first
	Drift: { Color3 }?, -- the drifting particles' colours (default: the aura's)
}

-- In order: the first one a name matches is its main element.
DonutAuras.Elements = {
	{ Id = "Power", Keys = { "maximus", "maxima", "supremus", "titan", "odin", "hades", "prime", "banhammer", "glazilla", "crullazilla", "zilla", "mighty" }, Parts = { "Banhammer" }, Biomes = {}, Colors = { rgb(255, 80, 60), rgb(255, 230, 120), rgb(120, 10, 20) }, Pulse = "Heartbeat", Moves = { "aura", "shockwave", "rise", "electric", "swirl", "shards" } },
	{ Id = "Void", Keys = { "void", "singular", "wormhol", "gravit", "horizon", "accretion", "supermassiv", "quantum", "null", "missingdonut" }, Parts = { "AccretionDisk", "Wormhole", "VoidRing", "GravityRings", "AtomOrbits", "Spaghetti" }, Biomes = { "BlackHole" }, Colors = { rgb(170, 90, 255), rgb(80, 220, 255), rgb(25, 5, 45) }, Pulse = "Throb", Moves = { "vortex", "smoke", "shards", "arcs", "runes", "galaxy" } },
	{ Id = "Phantom", Keys = { "ghost", "boo", "spook", "soul", "wisp", "vampir", "skeleton", "witch", "haunt", "bone", "phantom", "zombie" }, Parts = { "GhostTail", "Bats", "Ribcage", "WitchHat", "SoulWisps", "VampireCollar" }, Biomes = { "Haunted" }, Colors = { rgb(120, 255, 150), rgb(180, 100, 255), rgb(40, 10, 50) }, Pulse = "Throb", Moves = { "smoke", "wisps", "vortex", "arcs", "shards", "runes" } },
	{ Id = "Dizzy", Keys = { "dizzy", "nasmean", "spin", "hypno" }, Parts = {}, Biomes = {}, Colors = { rgb(255, 230, 90), rgb(255, 150, 220), rgb(140, 200, 255) }, Pulse = "Shimmer", Moves = { "orbitStar", "swirl", "stars", "wisps", "shockwave" } },
	{ Id = "Divine", Keys = { "angel", "heaven", "seraph", "harp", "archangel", "divine", "laurel", "holy" }, Parts = { "Halo", "SeraphWings", "Harp", "Laurel", "CloudPuffs" }, Biomes = { "Heaven", "Clouds" }, Colors = { rgb(255, 225, 130), WHITE, rgb(255, 185, 80) }, Pulse = "Shimmer", Moves = { "godrays", "feathers", "wisps", "rays", "runes", "glitter" }, Drift = { WHITE, rgb(255, 245, 220) } },
	{ Id = "Storm", Keys = { "zeus", "bolt", "thunder", "storm", "overclock", "volt", "spark", "electr", "laser", "wifi", "signal", "quasar", "lightning" }, Parts = { "LightningBolt", "WifiArcs", "QuasarJets" }, Biomes = {}, Colors = { rgb(255, 235, 90), WHITE, rgb(90, 170, 255) }, Pulse = "Shimmer", Moves = { "electric", "arcs", "orbitBolt", "strike", "swirl", "shockwave" } },
	{ Id = "Inferno", Keys = { "flame", "blaze", "infern", "magma", "lava", "ember", "scorch", "volcan", "erupt", "hell", "cinda", "molten", "phoenix", "burn", "crullfire", "fire", "dragon", "imp$", "impolo", "devil", "brimst" }, Parts = { "Flames", "FlameHair", "FireBeard", "LavaDrips", "Volcano", "MagmaCore", "LavaWave", "PhoenixTail", "DragonTail", "DevilTail" }, Biomes = { "Lava" }, Colors = { rgb(255, 120, 30), rgb(255, 225, 90), rgb(190, 20, 10) }, Pulse = "Glow", Moves = { "flames", "embers", "rise", "shards", "shockwave", "smoke" }, Drift = { rgb(255, 220, 90), rgb(255, 90, 20) } },
	{ Id = "Frost", Keys = { "ice", "frost", "glacier", "snow", "yeti", "frigo", "icicl", "palazzo", "pinguino", "brr", "aurora", "borealis", "frozen" }, Parts = { "IceSpikes", "Icicles", "IceCrown", "Snowflakes", "AuroraRibbon" }, Biomes = { "Ice" }, Colors = { rgb(150, 225, 255), WHITE, rgb(60, 140, 255) }, Pulse = "Shimmer", Moves = { "snow", "orbitSnowflake", "mist", "shards", "runes", "wisps" }, Drift = { WHITE, rgb(200, 240, 255) } },
	{ Id = "Digital", Keys = { "robo", "mecha", "cyber", "glitch", "byte", "data", "packet", "binary", "server", "processore", "pixel", "error", "bluescreen", "holo", "firewall", "trojan", "antivirus", "sentinel", "mainfram", "donutronic", "neon", "billboard", "arcade", "joystick", "escalator", "vendomatic", "conveyor", "weld", "boltino", "404", "coreino", "root", "sudo", "admin", "terminal" }, Parts = { "Visor", "Antenna", "RoboPlates", "CPUChip", "ServerRack", "BinaryRing", "Terminal", "ErrorSign", "BlueScreen", "GlitchSlices", "PixelBlocks", "HoloRing", "NeonTube", "Billboard" }, Biomes = { "CyberStreets", "RobotFactory", "Glitch" }, Colors = { rgb(60, 230, 255), rgb(80, 255, 140), rgb(255, 60, 200) }, Pulse = "Shimmer", Moves = { "orbitCube", "runes", "electric", "shockwave", "glitter", "arcs" } },
	{ Id = "Clockwork", Keys = { "tick", "tock", "chrono", "clock", "cog", "gear", "steam", "hourglass", "windup" }, Parts = { "Gears", "AlarmClock", "Hourglass", "WindUpKey", "JackCrank" }, Biomes = { "Clockwork" }, Colors = { rgb(255, 190, 90), rgb(255, 240, 200), rgb(170, 110, 50) }, Pulse = "Glow", Moves = { "runes", "orbitGear", "steam", "glitter", "shockwave", "wisps" }, Drift = { rgb(240, 240, 245), rgb(200, 200, 210) } },
	{ Id = "Ocean", Keys = { "shark", "wave", "surf", "tsunami", "octo", "jelly", "bubbl", "puffer", "laguna", "trident", "crab", "tralalero", "pirat", "captain", "poseid" }, Parts = { "Tentacles", "SharkFin", "SharkTail", "Trident", "JellyDome", "Surfboard", "LavaBubbles" }, Biomes = { "Lake" }, Colors = { rgb(80, 200, 255), WHITE, rgb(30, 110, 220) }, Pulse = "Glow", Moves = { "bubbles", "orbitBubble", "swirl", "shockwave", "mist", "wisps" }, Drift = { rgb(200, 240, 255), WHITE } },
	{ Id = "Love", Keys = { "heart", "love", "amor", "teddy", "cupid", "sweetheart", "valentin" }, Parts = { "Bow" }, Biomes = {}, Colors = { rgb(255, 90, 150), rgb(255, 185, 215), WHITE }, Pulse = "Heartbeat", Moves = { "orbitHeart", "glitter", "wisps", "mist", "stars" } },
	{ Id = "Music", Keys = { "music", "song", "melod", "dj", "headphone", "jazz", "drum", "tune" }, Parts = { "Headphones", "ToyDrum", "Harp" }, Biomes = {}, Colors = { rgb(140, 200, 255), rgb(255, 150, 230), WHITE }, Pulse = "Shimmer", Moves = { "orbitNote", "wisps", "glitter", "shockwave" } },
	{ Id = "Crystal", Keys = { "crystal", "amethyst", "prism", "diamond", "gem", "obsidian", "quartz", "jewel", "lucent" }, Parts = { "CrystalCluster", "ObsidianShards", "Gems", "Prism" }, Biomes = {}, Colors = { rgb(200, 130, 255), rgb(140, 230, 255), WHITE }, Pulse = "Shimmer", Moves = { "crystals", "shards", "glitter", "rays", "runes", "stars" } },
	{ Id = "Bloom", Keys = { "flower", "petal", "bloom", "lily", "floretta", "leaf", "jungle", "fairy", "garden", "pumpkin" }, Parts = { "Flower", "Leaf", "LeafCrown", "FairyWand" }, Biomes = { "Jungle", "Park" }, Colors = { rgb(255, 150, 200), rgb(140, 230, 110), rgb(255, 235, 120) }, Pulse = "Glow", Moves = { "petals", "orbitLeaf", "glitter", "wisps", "runes", "mist" }, Drift = { rgb(255, 160, 205), rgb(255, 215, 235) } },
	{ Id = "Cosmos", Keys = { "star", "nova", "nebul", "galax", "cosmo", "comet", "moon", "astro", "celestial", "stardust", "infinit", "eternal" }, Parts = { "Orbit", "Moon", "FallingStars", "NebulaCloud", "GalaxySwirl", "NovaBurst", "StarWand", "InfinityRing" }, Biomes = {}, Colors = { rgb(255, 150, 240), rgb(140, 210, 255), WHITE }, Pulse = "Shimmer", Moves = { "stars", "wisps", "swirl", "orbitStar", "rays", "runes" } },
	{ Id = "Sugar", Keys = { "candy", "lollipop", "gum", "peppermint", "caramel", "rainbow", "arcobal", "sugar", "sweet", "toy", "yo-yo", "glazoyo", "jack" }, Parts = { "CandyCane", "Lollipop", "Gumdrops", "RainbowArc", "PeppermintSwirl", "YoYo" }, Biomes = { "Candy", "Toys" }, Colors = { rgb(255, 120, 190), rgb(120, 220, 255), rgb(255, 230, 100) }, Pulse = "Glow", Moves = { "confetti", "swirl", "orbitStar", "shockwave", "wisps" }, Drift = { rgb(255, 90, 150), rgb(90, 200, 255), rgb(255, 230, 80), rgb(120, 230, 120) } },
	{ Id = "Treasure", Keys = { "king", "queen", "crown", "gold", "treasure", "idol", "pharaoh", "glazamun", "grande", "imperatrix", "supremo", "supremito", "majest", "final", "omnidonut", "coin" }, Parts = { "Crown", "TreasureCoins", "Gems", "Pharaoh", "Scepter", "Tiara" }, Biomes = { "Desert" }, Colors = { rgb(255, 210, 70), rgb(255, 250, 215), rgb(255, 150, 30) }, Pulse = "Glow", Moves = { "rays", "orbitCoin", "glitter", "runes", "wisps", "godrays" } },
	{ Id = "Earth", Keys = { "forg", "charcoal", "basalt", "cavern", "miner", "rock", "stone", "coal", "choco", "cocoa", "fudge" }, Parts = { "ForgeHammer", "MinerHelmet", "CharcoalChunks", "BasaltPlates" }, Biomes = { "Chocolate" }, Colors = { rgb(255, 150, 60), rgb(255, 220, 140), rgb(90, 60, 45) }, Pulse = "Glow", Moves = { "embers", "shards", "smoke", "shockwave", "runes" }, Drift = { rgb(255, 200, 90), rgb(255, 120, 40) } },
	{ Id = "Speed", Keys = { "kar", "kart", "skate", "rocket", "jet", "turbo", "racer", "speed", "zoom" }, Parts = { "Kart", "Skateboard" }, Biomes = {}, Colors = { rgb(80, 170, 255), WHITE, rgb(255, 120, 40) }, Pulse = "Shimmer", Moves = { "streaks", "flames", "wisps", "shockwave", "electric" } },
} :: { Element }

DonutAuras.ById = {} :: { [string]: Element }
for _, element in DonutAuras.Elements do
	DonutAuras.ById[element.Id] = element
	for _, move in element.Moves do
		assert(Moves[move], "Unknown aura move " .. move .. " in " .. element.Id)
	end
end

-- Per-donut choices: { Primary = element id, Secondary = element id }.
DonutAuras.Overrides = {
	nasmeanman = { Primary = "Dizzy", Secondary = "Cosmos" },
} :: { [string]: { Primary: string?, Secondary: string? } }

-- How many effects, and how strong, by rarity order (Epic = 4 ...).
local TIERS: { [number]: { Count: number, Intensity: number } } = {
	[4] = { Count = 2, Intensity = 0.6 },
	[5] = { Count = 3, Intensity = 0.85 },
	[6] = { Count = 4, Intensity = 1 },
	[7] = { Count = 5, Intensity = 1.3 },
	[8] = { Count = 5, Intensity = 1.5 },
	[9] = { Count = 6, Intensity = 1.6 },
}

-- Effects any element can borrow when its own are used up (keeps every donut's set different).
local WILD = { "stars", "glitter", "wisps", "mist", "shockwave", "runes", "swirl", "rays", "vortex" }

local function hashString(text: string): number
	local hash = 23
	for i = 1, #text do
		hash = (hash * 41 + string.byte(text, i)) % 2147483647
	end
	return hash
end

local function wordsOf(donut: Donut): { string }
	local words = {}
	for word in string.gmatch(string.lower(donut.Name .. " " .. donut.Id), "[^%s]+") do
		table.insert(words, word)
	end
	return words
end

local function nameMatches(element: Element, words: { string }): boolean
	for _, key in element.Keys do
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

local function partMatches(element: Element, parts: { [string]: boolean }): boolean
	for _, name in element.Parts do
		if parts[name] then
			return true
		end
	end
	return false
end

-- The donut's main and second elements.
function DonutAuras.ElementsOf(donut: Donut): (Element, Element?)
	local words = wordsOf(donut)
	local parts = {}
	for _, name in donut.Parts do
		parts[name] = true
	end
	local area = Areas.Get(donut.Area)
	local biome = area and area.Theme or ""
	local found: { Element } = {}
	local function addIf(element: Element)
		if not table.find(found, element) then
			table.insert(found, element)
		end
	end
	for _, element in DonutAuras.Elements do
		if nameMatches(element, words) then
			addIf(element)
		end
	end
	for _, element in DonutAuras.Elements do
		if partMatches(element, parts) then
			addIf(element)
		end
	end
	for _, element in DonutAuras.Elements do
		if table.find(element.Biomes, biome) then
			addIf(element)
		end
	end
	local override = DonutAuras.Overrides[donut.Id]
	if override then
		if override.Secondary then
			table.insert(found, 1, DonutAuras.ById[override.Secondary])
		end
		if override.Primary then
			table.insert(found, 1, DonutAuras.ById[override.Primary])
		end
	end
	local primary = found[1] or DonutAuras.Elements[hashString(donut.Id) % #DonutAuras.Elements + 1]
	local secondary: Element? = nil
	for _, element in found do
		if element ~= primary then
			secondary = element
			break
		end
	end
	return primary, secondary
end

-- The donut's own aura (nil below Epic, or when its look turns effects off).
-- Builds a donut's aura. `used` holds the effect sets earlier donuts already have: it keeps
-- trying other picks (its element's second or third best effect first, other effects from its
-- second element, then borrowed ones) until it finds a set no other donut has.
local function build(donut: Donut, used: { [string]: boolean }?): Theme?
	local rarity = Rarities.Get(donut.Rarity)
	local tier = TIERS[math.min(rarity.Order, 9)]
	if not tier then
		return nil
	end
	local look = DonutLooks.For(donut :: any, rarity.Order)
	if not look.Effects then
		return nil
	end
	local primary, secondary = DonutAuras.ElementsOf(donut)
	-- its colours: the element's, the first tinted with the donut's own glaze
	local frosting = donut.Frosting
	local saturated = math.max(frosting.R, frosting.G, frosting.B) - math.min(frosting.R, frosting.G, frosting.B) > 0.25
	local colors = {
		if saturated then primary.Colors[1]:Lerp(frosting, 0.3) else primary.Colors[1],
		primary.Colors[2],
		primary.Colors[3],
	}

	local chosen: { { Move: string, From: Element } } = {}
	local r = Random.new(hashString(donut.Id))
	for attempt = 0, 60 do
		r = Random.new(hashString(donut.Id) + attempt * 7919)
		chosen = {}
		local function take(move: string, from: Element)
			if #chosen >= tier.Count then
				return
			end
			for _, other in chosen do
				if field(other.Move) == field(move) then
					return
				end
			end
			table.insert(chosen, { Move = move, From = from })
		end
		-- its main effect: its element's best (then second, third best on later tries)
		take(primary.Moves[1 + (attempt // 4) % math.min(3, #primary.Moves)], primary)
		-- one from its second element
		if secondary then
			take(secondary.Moves[1 + attempt % math.min(3, #secondary.Moves)], secondary)
		end
		-- the rest from its own element, borrowing a few more on later tries
		local rest = table.clone(primary.Moves)
		if attempt >= 8 then
			for _, move in WILD do
				table.insert(rest, move)
			end
		end
		while #chosen < tier.Count and #rest > 0 do
			take(table.remove(rest, r:NextInteger(1, #rest)) :: string, primary)
		end
		if not used then
			break
		end
		local names = {}
		for _, pick in chosen do
			table.insert(names, pick.Move)
		end
		table.sort(names)
		local key = table.concat(names, "+")
		if not used[key] then
			used[key] = true
			break
		end
	end

	local theme: Theme = {
		Id = "Signature",
		Colors = colors,
		Pulse = primary.Pulse,
		Outline = if rarity.Order >= 7 then true else nil,
	}
	local elements = { primary.Id }
	for _, pick in chosen do
		Moves[pick.Move](theme, tier.Intensity, r, colors)
		if field(pick.Move) == "Drift" then
			-- (drifting particles take the colours of the element that brought them)
			theme.DriftColors = pick.From.Drift or { pick.From.Colors[1], pick.From.Colors[2] }
		end
		if pick.From ~= primary and not table.find(elements, pick.From.Id) then
			table.insert(elements, pick.From.Id)
		end
	end
	theme.Elements = elements
	return theme
end

-- Every donut's aura, worked out once in list order (so each one's set is different from all the
-- donuts before it, the same on the server and every client).
local cache: { [string]: Theme | false }? = nil
local function all(): { [string]: Theme | false }
	local known = cache
	if known then
		return known
	end
	local built: { [string]: Theme | false } = {}
	local used = {}
	for _, donut in Donuts.List do
		built[donut.Id] = build(donut :: any, used) or false
	end
	cache = built
	return built
end

-- The donut's own aura (nil below Epic, or when its look turns effects off).
function DonutAuras.For(donut: Donut): Theme?
	if Donuts.ById[donut.Id] == donut then
		return all()[donut.Id] or nil
	end
	return build(donut, nil) -- (a donut made up on the spot, like the Update Log's emblem)
end

-- Every effect set a donut has: its own aura, then its mutation's.
function DonutAuras.Themes(donut: Donut, mutationId: string?): { Theme }
	local themes = {}
	local own = DonutAuras.For(donut)
	if own then
		table.insert(themes, own)
	end
	local fromMutation = FXThemes.ForMutation(mutationId)
	if fromMutation then
		table.insert(themes, fromMutation)
	end
	return themes
end

return DonutAuras
