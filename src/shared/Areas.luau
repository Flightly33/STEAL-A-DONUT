--[[
	Areas ("biomes"): one long lane running out of the lobby, biome 1 next to it. Every biome has its
	own Domer asleep in a back corner, guarding Config.Boxes.PerBiome donut boxes (Boxes.luau).

	RecommendedSpeed is the Speed (the big number in the HUD) you need to get AWAY from the biome's
	Domer: with exactly that Speed you just make it out of his biome before he catches you
	(Economy.GuardWalkSpeed works out how fast he runs from that). Anyone can walk into any biome.

	Every biome is as long as a fair run at its Speed: the faster you are, the longer the map
	(Areas.Length; worked out with the plain Speed curve, before Config.Speed.StatMultiplier). The first one is short,
	the next ones a little longer, Glacier Glaze and Molten Bakery longer, and from there each one
	is longer than the last.

	Couch = true: Domer naps lying on his couch (the first biomes). Later Domers sleep standing up,
	head down.

	Ambience is applied on the client when you walk into the biome.
]]

export type Ambience = {
	ClockTime: number,
	Tint: Color3,
	Saturation: number,
	Contrast: number,
	Ambient: Color3,
	AtmosphereColor: Color3,
	AtmosphereDensity: number,
	Haze: number,
	Bloom: number,
}

export type Area = {
	Id: number,
	Name: string,
	Theme: string,
	RecommendedSpeed: number, -- the Speed you need to get in
	WakeDelay: number,
	DomerBoost: number?, -- this biome's Domer runs this much faster again (on top of Config.Guard.SpeedBoost)
	Floor: { Color3 },
	FloorMaterial: Enum.Material,
	Wall: { Color3 },
	WallMaterial: Enum.Material,
	Trim: Color3,
	TrimMaterial: Enum.Material,
	Guard: { Skin: Color3, Shirt: Color3, Pants: Color3, Aura: string?, Title: string, Hat: string? },
	Ambience: Ambience,
	World: number, -- (always 1: there's one lane)
	Index: number, -- position along the lane (1 = next to the lobby)
	Length: number?, -- studs along the lane (filled in below)
	HalfWidth: number?, -- half the lane's width here (default Config.Map.LaneHalfWidth)
	Couch: boolean?, -- Domer naps on his couch here
}

export type World = {
	Id: number,
	Name: string,
	OffsetX: number,
	BridgeLength: number,
	WalkMultiplier: number,
	Color: Color3,
	Icon: string,
}

local Config = require(script.Parent.Config)

local Areas = {}

-- Bright, clean "Steal an Egg" style daylight: high sun, puffy clouds, very vivid colours, bright
-- shade, soft shadows and a light blue haze far away.
local DAY = {
	ClockTime = 13.5,
	Tint = Color3.fromRGB(255, 255, 255),
	Saturation = 0.14,
	Contrast = 0.05,
	Ambient = Color3.fromRGB(172, 172, 184),
	AtmosphereColor = Color3.fromRGB(199, 220, 245),
	AtmosphereDensity = 0.18,
	Haze = 0,
	Bloom = 0.2,
}

local function ambience(overrides: { [string]: any }): Ambience
	local result = table.clone(DAY)
	for key, value in overrides do
		(result :: any)[key] = value
	end
	return result
end

Areas.Hub = DAY

-- The Eternal Storm (client/Effects swaps this in everywhere while it lasts): midnight under a
-- purple sky, thin air so the stars and the black hole show through, a strong glow
Areas.Storm = ambience({
	ClockTime = 0,
	Tint = Color3.fromRGB(235, 220, 255),
	Saturation = 0.2,
	Contrast = 0.22,
	Ambient = Color3.fromRGB(95, 75, 150),
	AtmosphereColor = Color3.fromRGB(110, 60, 190),
	AtmosphereDensity = 0.2,
	Haze = 0.3,
	Bloom = 0.85,
})

Areas.List = {
	{
		-- Forest
		Id = 1, Name = "Sprinkle Park", Theme = "Park",
		RecommendedSpeed = 0, WakeDelay = 1.6, World = 1, Index = 1, Couch = true,
		Floor = { Color3.fromRGB(108, 184, 70), Color3.fromRGB(96, 170, 62) }, FloorMaterial = Enum.Material.Plastic,
		Wall = { Color3.fromRGB(184, 124, 74), Color3.fromRGB(168, 110, 64) }, WallMaterial = Enum.Material.Plastic,
		Trim = Color3.fromRGB(230, 110, 180), TrimMaterial = Enum.Material.SmoothPlastic,
		Guard = { Skin = Color3.fromRGB(255, 217, 15), Shirt = Color3.fromRGB(255, 170, 210), Pants = Color3.fromRGB(70, 110, 200), Title = "Sprinkle", Hat = "Cap" },
		Ambience = ambience({ Saturation = 0 }),
	},
	{
		-- Lake
		Id = 2, Name = "Frosting Falls", Theme = "Lake",
		RecommendedSpeed = 900, WakeDelay = 1.5, World = 1, Index = 2, Couch = true,
		Floor = { Color3.fromRGB(112, 196, 70), Color3.fromRGB(100, 182, 62) }, FloorMaterial = Enum.Material.Plastic,
		Wall = { Color3.fromRGB(176, 118, 70), Color3.fromRGB(160, 106, 62) }, WallMaterial = Enum.Material.Plastic,
		Trim = Color3.fromRGB(255, 255, 255), TrimMaterial = Enum.Material.SmoothPlastic,
		Guard = { Skin = Color3.fromRGB(255, 217, 15), Shirt = Color3.fromRGB(255, 120, 180), Pants = Color3.fromRGB(255, 255, 255), Title = "Frosted", Hat = "Party" },
		Ambience = ambience({ Tint = Color3.fromRGB(255, 238, 246), Saturation = 0, AtmosphereColor = Color3.fromRGB(255, 210, 235) }),
	},
	{
		-- Desert
		Id = 3, Name = "Sugar Dunes", Theme = "Desert",
		RecommendedSpeed = 10_000, WakeDelay = 1.4, World = 1, Index = 3, Couch = true,
		Floor = { Color3.fromRGB(214, 190, 134), Color3.fromRGB(200, 176, 120) }, FloorMaterial = Enum.Material.Sand,
		Wall = { Color3.fromRGB(215, 170, 100), Color3.fromRGB(200, 155, 90) }, WallMaterial = Enum.Material.Sandstone,
		Trim = Color3.fromRGB(255, 240, 200), TrimMaterial = Enum.Material.Sandstone,
		Guard = { Skin = Color3.fromRGB(255, 200, 40), Shirt = Color3.fromRGB(240, 220, 170), Pants = Color3.fromRGB(150, 110, 60), Title = "Desert", Hat = "Sombrero" },
		Ambience = ambience({ Tint = Color3.fromRGB(255, 242, 222), Saturation = -0.05, AtmosphereColor = Color3.fromRGB(240, 220, 180), Haze = 1.5 }),
	},
	{
		-- Jungle
		Id = 4, Name = "Jellybean Jungle", Theme = "Jungle",
		RecommendedSpeed = 40_000, WakeDelay = 1.3, World = 1, Index = 4, Couch = true,
		Floor = { Color3.fromRGB(92, 168, 58), Color3.fromRGB(80, 152, 50) }, FloorMaterial = Enum.Material.Grass,
		Wall = { Color3.fromRGB(70, 110, 60), Color3.fromRGB(60, 96, 52) }, WallMaterial = Enum.Material.Slate,
		Trim = Color3.fromRGB(110, 200, 70), TrimMaterial = Enum.Material.Grass,
		Guard = { Skin = Color3.fromRGB(255, 205, 40), Shirt = Color3.fromRGB(110, 140, 60), Pants = Color3.fromRGB(150, 120, 70), Title = "Jungle", Hat = "Cap" },
		Ambience = ambience({ Tint = Color3.fromRGB(235, 255, 225), Saturation = 0.12, AtmosphereColor = Color3.fromRGB(190, 225, 170), AtmosphereDensity = 0.32, Haze = 1.2 }),
	},
	{
		-- Snow
		Id = 5, Name = "Glacier Glaze", Theme = "Ice",
		RecommendedSpeed = 170_000, WakeDelay = 1.25, World = 1, Index = 5,
		Floor = { Color3.fromRGB(176, 206, 226), Color3.fromRGB(160, 192, 216) }, FloorMaterial = Enum.Material.Ice,
		Wall = { Color3.fromRGB(150, 205, 240), Color3.fromRGB(130, 190, 230) }, WallMaterial = Enum.Material.Glacier,
		Trim = Color3.fromRGB(255, 255, 255), TrimMaterial = Enum.Material.Snow,
		Guard = { Skin = Color3.fromRGB(200, 230, 255), Shirt = Color3.fromRGB(60, 140, 220), Pants = Color3.fromRGB(230, 245, 255), Aura = "Snow", Title = "Frozen", Hat = "Beanie" },
		Ambience = ambience({ ClockTime = 15.5, Tint = Color3.fromRGB(225, 240, 255), Saturation = -0.1, Ambient = Color3.fromRGB(95, 115, 138), AtmosphereColor = Color3.fromRGB(200, 230, 255), AtmosphereDensity = 0.4, Haze = 1.5 }),
	},
	{
		-- Volcano
		Id = 6, Name = "Molten Bakery", Theme = "Lava",
		RecommendedSpeed = 700_000, WakeDelay = 1.2, World = 1, Index = 6,
		Floor = { Color3.fromRGB(45, 35, 35), Color3.fromRGB(60, 42, 38) }, FloorMaterial = Enum.Material.Basalt,
		Wall = { Color3.fromRGB(50, 40, 40), Color3.fromRGB(38, 30, 30) }, WallMaterial = Enum.Material.Basalt,
		Trim = Color3.fromRGB(255, 100, 0), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(255, 120, 30), Shirt = Color3.fromRGB(40, 30, 30), Pants = Color3.fromRGB(120, 20, 10), Aura = "Fire", Title = "Lava", Hat = "Chef" },
		Ambience = ambience({ ClockTime = 18.3, Tint = Color3.fromRGB(255, 200, 170), Saturation = 0.05, Contrast = 0.15, Ambient = Color3.fromRGB(105, 52, 30), AtmosphereColor = Color3.fromRGB(255, 120, 60), AtmosphereDensity = 0.45, Haze = 2.5, Bloom = 0.35 }),
	},
	{
		Id = 7, Name = "Chocolate Caverns", Theme = "Chocolate",
		RecommendedSpeed = 1_300_000, WakeDelay = 1.15, World = 1, Index = 7,
		Floor = { Color3.fromRGB(95, 55, 35), Color3.fromRGB(80, 45, 28) }, FloorMaterial = Enum.Material.Slate,
		Wall = { Color3.fromRGB(70, 40, 25), Color3.fromRGB(58, 33, 20) }, WallMaterial = Enum.Material.Rock,
		Trim = Color3.fromRGB(150, 90, 50), TrimMaterial = Enum.Material.Slate,
		Guard = { Skin = Color3.fromRGB(200, 150, 60), Shirt = Color3.fromRGB(120, 70, 40), Pants = Color3.fromRGB(60, 35, 20), Title = "Choco", Hat = "Miner" },
		Ambience = ambience({ ClockTime = 17.2, Tint = Color3.fromRGB(255, 220, 190), Ambient = Color3.fromRGB(90, 60, 45), AtmosphereColor = Color3.fromRGB(120, 80, 50), AtmosphereDensity = 0.45, Haze = 2 }),
	},
	{
		Id = 8, Name = "Candy Cane Canyon", Theme = "Candy",
		RecommendedSpeed = 2_600_000, WakeDelay = 1.1, World = 1, Index = 8,
		Floor = { Color3.fromRGB(250, 236, 240), Color3.fromRGB(240, 222, 230) }, FloorMaterial = Enum.Material.SmoothPlastic,
		Wall = { Color3.fromRGB(230, 60, 70), Color3.fromRGB(245, 245, 245) }, WallMaterial = Enum.Material.SmoothPlastic,
		Trim = Color3.fromRGB(255, 90, 120), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(255, 217, 15), Shirt = Color3.fromRGB(230, 40, 50), Pants = Color3.fromRGB(255, 255, 255), Title = "Candy", Hat = "Party" },
		Ambience = ambience({ ClockTime = 14, Tint = Color3.fromRGB(255, 240, 245), Saturation = 0.25, AtmosphereColor = Color3.fromRGB(255, 215, 230) }),
	},
	{
		Id = 9, Name = "Toy Factory", Theme = "Toys",
		RecommendedSpeed = 5_000_000, WakeDelay = 1.05, World = 1, Index = 9,
		Floor = { Color3.fromRGB(255, 205, 70), Color3.fromRGB(80, 165, 255) }, FloorMaterial = Enum.Material.Plastic,
		Wall = { Color3.fromRGB(240, 80, 80), Color3.fromRGB(80, 200, 110) }, WallMaterial = Enum.Material.Plastic,
		Trim = Color3.fromRGB(255, 255, 255), TrimMaterial = Enum.Material.SmoothPlastic,
		Guard = { Skin = Color3.fromRGB(255, 217, 15), Shirt = Color3.fromRGB(255, 70, 70), Pants = Color3.fromRGB(60, 120, 255), Title = "Toy", Hat = "Propeller" },
		Ambience = ambience({ ClockTime = 13, Saturation = 0.25 }),
	},
	{
		Id = 10, Name = "Haunted Donuttery", Theme = "Haunted",
		RecommendedSpeed = 9_500_000, WakeDelay = 1.0, World = 1, Index = 10,
		Floor = { Color3.fromRGB(62, 52, 72), Color3.fromRGB(52, 44, 62) }, FloorMaterial = Enum.Material.Slate,
		Wall = { Color3.fromRGB(42, 36, 52), Color3.fromRGB(34, 30, 44) }, WallMaterial = Enum.Material.Brick,
		Trim = Color3.fromRGB(140, 255, 120), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(210, 230, 210), Shirt = Color3.fromRGB(60, 50, 70), Pants = Color3.fromRGB(30, 25, 40), Aura = "Ghost", Title = "Ghost", Hat = "Witch" },
		Ambience = ambience({ ClockTime = 22, Tint = Color3.fromRGB(215, 255, 215), Saturation = 0, Contrast = 0.2, Ambient = Color3.fromRGB(70, 90, 80), AtmosphereColor = Color3.fromRGB(90, 140, 100), AtmosphereDensity = 0.5, Haze = 2.5, Bloom = 0.4 }),
	},
	{
		Id = 11, Name = "Cloud Bakery", Theme = "Clouds",
		RecommendedSpeed = 18_000_000, WakeDelay = 0.98, World = 1, Index = 11,
		Floor = { Color3.fromRGB(246, 246, 255), Color3.fromRGB(232, 236, 250) }, FloorMaterial = Enum.Material.SmoothPlastic,
		Wall = { Color3.fromRGB(205, 222, 255), Color3.fromRGB(190, 210, 250) }, WallMaterial = Enum.Material.SmoothPlastic,
		Trim = Color3.fromRGB(255, 190, 225), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(255, 225, 120), Shirt = Color3.fromRGB(255, 255, 255), Pants = Color3.fromRGB(180, 200, 255), Aura = "Sparkles", Title = "Angel", Hat = "Chef" },
		Ambience = ambience({ ClockTime = 12, Tint = Color3.fromRGB(255, 240, 250), Saturation = 0.1, AtmosphereColor = Color3.fromRGB(255, 230, 245), AtmosphereDensity = 0.2, Haze = 1 }),
	},
	{
		Id = 12, Name = "Neon Streets", Theme = "CyberStreets",
		RecommendedSpeed = 30_000_000, WakeDelay = 0.92, World = 1, Index = 12,
		Floor = { Color3.fromRGB(30, 30, 42), Color3.fromRGB(38, 38, 52) }, FloorMaterial = Enum.Material.Asphalt,
		Wall = { Color3.fromRGB(24, 22, 40), Color3.fromRGB(32, 30, 52) }, WallMaterial = Enum.Material.Metal,
		Trim = Color3.fromRGB(255, 40, 200), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(0, 255, 220), Shirt = Color3.fromRGB(255, 40, 200), Pants = Color3.fromRGB(30, 30, 50), Aura = "Neon", Title = "Street", Hat = "Visor" },
		Ambience = ambience({ ClockTime = 1, Tint = Color3.fromRGB(235, 215, 255), Saturation = 0.25, Contrast = 0.25, Ambient = Color3.fromRGB(80, 60, 140), AtmosphereColor = Color3.fromRGB(200, 60, 255), AtmosphereDensity = 0.46, Haze = 2, Bloom = 0.7 }),
	},
	{
		Id = 13, Name = "Robot Factory", Theme = "RobotFactory",
		RecommendedSpeed = 50_000_000, WakeDelay = 0.9, World = 1, Index = 13,
		Floor = { Color3.fromRGB(90, 95, 105), Color3.fromRGB(78, 82, 92) }, FloorMaterial = Enum.Material.DiamondPlate,
		Wall = { Color3.fromRGB(60, 62, 70), Color3.fromRGB(50, 52, 60) }, WallMaterial = Enum.Material.Metal,
		Trim = Color3.fromRGB(255, 190, 0), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(0, 255, 220), Shirt = Color3.fromRGB(255, 190, 0), Pants = Color3.fromRGB(60, 60, 70), Aura = "Fire", Title = "Robo", Hat = "Helmet" },
		Ambience = ambience({ ClockTime = 19, Tint = Color3.fromRGB(255, 235, 210), Saturation = 0.25, Contrast = 0.25, Ambient = Color3.fromRGB(80, 60, 140), AtmosphereColor = Color3.fromRGB(255, 170, 60), AtmosphereDensity = 0.46, Haze = 2, Bloom = 0.7 }),
	},
	{
		Id = 14, Name = "Clockwork Void", Theme = "Clockwork",
		RecommendedSpeed = 85_000_000, WakeDelay = 0.88, World = 1, Index = 14,
		Floor = { Color3.fromRGB(72, 62, 92), Color3.fromRGB(86, 74, 108) }, FloorMaterial = Enum.Material.DiamondPlate,
		Wall = { Color3.fromRGB(42, 36, 62), Color3.fromRGB(34, 30, 52) }, WallMaterial = Enum.Material.Metal,
		Trim = Color3.fromRGB(255, 190, 60), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(200, 200, 215), Shirt = Color3.fromRGB(120, 90, 50), Pants = Color3.fromRGB(60, 50, 80), Aura = "Neon", Title = "Robo", Hat = "Gears" },
		Ambience = ambience({ ClockTime = 19.4, Tint = Color3.fromRGB(235, 220, 255), Saturation = 0.1, Contrast = 0.2, Ambient = Color3.fromRGB(90, 70, 130), AtmosphereColor = Color3.fromRGB(140, 100, 200), AtmosphereDensity = 0.35, Haze = 1.5, Bloom = 0.5 }),
	},
	{
		Id = 15, Name = "Donut Heaven", Theme = "Heaven",
		RecommendedSpeed = 140_000_000, WakeDelay = 0.82, World = 1, Index = 15, DomerBoost = 1.3,
		Floor = { Color3.fromRGB(255, 242, 205), Color3.fromRGB(255, 230, 175) }, FloorMaterial = Enum.Material.Marble,
		Wall = { Color3.fromRGB(255, 250, 238), Color3.fromRGB(245, 238, 220) }, WallMaterial = Enum.Material.Marble,
		Trim = Color3.fromRGB(255, 215, 90), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(255, 230, 140), Shirt = Color3.fromRGB(255, 255, 255), Pants = Color3.fromRGB(255, 215, 90), Aura = "Cosmic", Title = "Golden", Hat = "Halo" },
		Ambience = ambience({ ClockTime = 12, Tint = Color3.fromRGB(255, 245, 220), Saturation = 0.1, AtmosphereColor = Color3.fromRGB(255, 235, 190), AtmosphereDensity = 0.25, Haze = 1.5, Bloom = 0.6 }),
	},
	{
		Id = 16, Name = "Glitch Zone", Theme = "Glitch",
		RecommendedSpeed = 240_000_000, WakeDelay = 0.8, World = 1, Index = 16,
		Floor = { Color3.fromRGB(20, 20, 20), Color3.fromRGB(245, 245, 245) }, FloorMaterial = Enum.Material.SmoothPlastic,
		Wall = { Color3.fromRGB(255, 0, 200), Color3.fromRGB(0, 255, 220) }, WallMaterial = Enum.Material.Neon,
		Trim = Color3.fromRGB(255, 255, 0), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(0, 255, 220), Shirt = Color3.fromRGB(0, 0, 0), Pants = Color3.fromRGB(255, 0, 200), Aura = "Cosmic", Title = "Glitched", Hat = "Gears" },
		Ambience = ambience({ ClockTime = 0, Tint = Color3.fromRGB(240, 220, 255), Saturation = 0.25, Contrast = 0.25, Ambient = Color3.fromRGB(80, 60, 140), AtmosphereColor = Color3.fromRGB(255, 0, 200), AtmosphereDensity = 0.46, Haze = 2, Bloom = 0.7 }),
	},
	{
		Id = 17, Name = "The Black Hole", Theme = "BlackHole",
		RecommendedSpeed = 400_000_000, WakeDelay = 0.78, World = 1, Index = 17, HalfWidth = 135, DomerBoost = 1.5,
		Floor = { Color3.fromRGB(14, 10, 26), Color3.fromRGB(22, 16, 40) }, FloorMaterial = Enum.Material.Glass,
		Wall = { Color3.fromRGB(10, 8, 20), Color3.fromRGB(18, 12, 34) }, WallMaterial = Enum.Material.Glass,
		Trim = Color3.fromRGB(170, 90, 255), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(0, 255, 220), Shirt = Color3.fromRGB(20, 20, 30), Pants = Color3.fromRGB(120, 60, 255), Aura = "Cosmic", Title = "Event Horizon", Hat = "Halo" },
		Ambience = ambience({ ClockTime = 0, Tint = Color3.fromRGB(230, 215, 255), Saturation = 0.35, Contrast = 0.32, Ambient = Color3.fromRGB(70, 50, 130), AtmosphereColor = Color3.fromRGB(90, 50, 200), AtmosphereDensity = 0.36, Haze = 1.2, Bloom = 0.7 }),
	},
} :: { Area }

-- Lengths: the first biomes have their own (FIRST_LENGTHS: a short first one), the next two are
-- SecondLength; after that a biome is as long as RunSeconds of running at its own Speed (and
-- always longer than the last).
local FIRST_LENGTHS = { 160, 420, 600, 500 }
local SECOND_LENGTH, RUN_SECONDS, TILE = 600, 6, Config.Map.TileSize
local function walkSpeed(speed: number): number
	local s = Config.Speed
	return s.BaseWalkSpeed + s.CurveScale * math.max(speed, 0) ^ s.CurvePower
end
local previous = 0
for index, area in Areas.List do
	local length = if index <= #FIRST_LENGTHS then FIRST_LENGTHS[index] elseif index <= 6 then SECOND_LENGTH else walkSpeed(area.RecommendedSpeed) * RUN_SECONDS
	length = math.max(math.floor(length / TILE + 0.5) * TILE, previous + (if index > 6 then 2 * TILE else 0))
	area.Length = length
	previous = length
end

-- (One lane now: the old worlds and their portals are gone. Kept as a single world so code that
-- asks "which world" still has an answer.)
Areas.Worlds = {
	{ Id = 1, Name = "Donut Land", OffsetX = 0, BridgeLength = 0, WalkMultiplier = 1, Color = Color3.fromRGB(120, 210, 56), Icon = "🍩" },
} :: { World }

Areas.ByWorld = {} :: { [number]: { Area } }
for _, area in Areas.List do
	Areas.ByWorld[area.World] = Areas.ByWorld[area.World] or {}
	table.insert(Areas.ByWorld[area.World], area)
end

function Areas.Get(id: number): Area?
	return Areas.List[id]
end

function Areas.World(id: number?): World
	return Areas.Worlds[id or 1] or Areas.Worlds[1]
end

return Areas
