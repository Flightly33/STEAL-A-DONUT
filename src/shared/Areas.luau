--[[
	Areas, from the safe zone outwards. Early areas are plain and bright; later areas get darker,
	more magical, and are guarded by faster guards.

	Worlds: World 1 is the main lane next to the hub. Worlds 2, 3 and 4 are separate lanes reached
	through portals in the hub (unlocked by rebirths). Each world has its own safe zone with a portal home.
	In later worlds everyone moves faster (World.WalkMultiplier), so speed keeps climbing.
	Their first area sits at the end of a long bridge (World.BridgeLength) so an escape there is as long
	as it would be if the lane just kept going - otherwise a slow player could steal right next to
	the safe zone and skip the speed requirements.

	RecommendedSpeed is in "Speed stat" units (the big number in the HUD). It's the BASE the guard's
	WalkSpeed is tuned from (Economy.GuardWalkSpeed: that speed's WalkSpeed + GuardSpeedBonus, times
	the world bonus, times Config.Guard.SpeedMultiplier).

	The "Recommended Speed" players see (signs, HUD, teleporter, events, crate coins) is worked out
	from the chase itself (Economy.RecommendedSpeed): the Speed that gets you home with at least the
	front half of the area's donuts. With Domer at +7.5% that's the base below in World 1's early
	areas and up to ~80 Speed more in World 3. It follows any guard change you make.

	The base goes up by 90 per area (= +9 WalkSpeed, see Config.Speed); GuardSpeedBonus is 5 / 7 / 9
	WalkSpeed in worlds 1 / 2 / 3 / 4 (11).

	Ambience is applied on the client when you walk into the area.
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
	RecommendedSpeed: number,
	GuardSpeedBonus: number,
	WakeDelay: number,
	Floor: { Color3 },
	FloorMaterial: Enum.Material,
	Wall: { Color3 },
	WallMaterial: Enum.Material,
	Trim: Color3,
	TrimMaterial: Enum.Material,
	Guard: { Skin: Color3, Shirt: Color3, Pants: Color3, Aura: string?, Title: string, Hat: string? },
	Ambience: Ambience,
	World: number, -- which world this area belongs to
	Index: number, -- position inside its world's lane (1 = next to the safe zone)
	Length: number?, -- studs along the lane (default Config.Map.AreaLength)
	HalfWidth: number?, -- half the lane's width here (default Config.Map.LaneHalfWidth)
	Lab: boolean?, -- The Black Hole: a pit down to the secret lab with the ULTIMATE REBIRTH button
}

export type World = {
	Id: number,
	Name: string,
	OffsetX: number, -- the world's lane runs along Z at this X
	BridgeLength: number, -- studs between the world's safe zone and its first area
	RequiredRebirths: number,
	RequiredUltimate: number?, -- Ultimate Rebirths needed (World 2 is reached through The Black Hole)
	WalkMultiplier: number, -- everyone (players AND guards) is this much faster in this world
	Color: Color3,
	Icon: string,
}

local Areas = {}

-- Bright, clean "Steal an Egg" style daylight: high sun, clear sky, no fog, vivid colours,
-- soft light shadows.
local DAY = {
	ClockTime = 13.5,
	Tint = Color3.fromRGB(255, 255, 255),
	Saturation = 0.12,
	Contrast = 0.04,
	Ambient = Color3.fromRGB(150, 150, 160),
	AtmosphereColor = Color3.fromRGB(199, 214, 234),
	AtmosphereDensity = 0.05,
	Haze = 0,
	Bloom = 0.1,
}

local function ambience(overrides: { [string]: any }): Ambience
	local result = table.clone(DAY)
	for key, value in overrides do
		(result :: any)[key] = value
	end
	return result
end

Areas.Hub = DAY

Areas.List = {
	---------------------------------------------------------------- World 1: Donut Land
	{
		Id = 1, Name = "Glazed Meadow", Theme = "Meadow",
		RecommendedSpeed = 0, GuardSpeedBonus = 5, WakeDelay = 1.6, World = 1, Index = 1,
		Floor = { Color3.fromRGB(120, 210, 56), Color3.fromRGB(106, 196, 48) }, FloorMaterial = Enum.Material.Plastic,
		Wall = { Color3.fromRGB(206, 136, 78), Color3.fromRGB(192, 124, 68) }, WallMaterial = Enum.Material.Plastic,
		Trim = Color3.fromRGB(100, 200, 60), TrimMaterial = Enum.Material.Grass,
		Guard = { Skin = Color3.fromRGB(255, 217, 15), Shirt = Color3.fromRGB(245, 245, 245), Pants = Color3.fromRGB(70, 110, 200), Title = "Sleepy" },
		Ambience = ambience({}),
	},
	{
		Id = 2, Name = "Sprinkle Park", Theme = "Park",
		RecommendedSpeed = 90, GuardSpeedBonus = 5, WakeDelay = 1.5, World = 1, Index = 2,
		Floor = { Color3.fromRGB(108, 184, 70), Color3.fromRGB(96, 170, 62) }, FloorMaterial = Enum.Material.Plastic,
		Wall = { Color3.fromRGB(184, 124, 74), Color3.fromRGB(168, 110, 64) }, WallMaterial = Enum.Material.Plastic,
		Trim = Color3.fromRGB(230, 110, 180), TrimMaterial = Enum.Material.SmoothPlastic,
		Guard = { Skin = Color3.fromRGB(255, 217, 15), Shirt = Color3.fromRGB(255, 170, 210), Pants = Color3.fromRGB(70, 110, 200), Title = "Sprinkle", Hat = "Cap" },
		Ambience = ambience({ Saturation = 0 }),
	},
	{
		Id = 3, Name = "Sugar Dunes", Theme = "Desert",
		RecommendedSpeed = 180, GuardSpeedBonus = 5, WakeDelay = 1.4, World = 1, Index = 3,
		Floor = { Color3.fromRGB(214, 190, 134), Color3.fromRGB(200, 176, 120) }, FloorMaterial = Enum.Material.Sand,
		Wall = { Color3.fromRGB(215, 170, 100), Color3.fromRGB(200, 155, 90) }, WallMaterial = Enum.Material.Sandstone,
		Trim = Color3.fromRGB(255, 240, 200), TrimMaterial = Enum.Material.Sandstone,
		Guard = { Skin = Color3.fromRGB(255, 200, 40), Shirt = Color3.fromRGB(240, 220, 170), Pants = Color3.fromRGB(150, 110, 60), Title = "Desert", Hat = "Sombrero" },
		Ambience = ambience({ Tint = Color3.fromRGB(255, 242, 222), Saturation = -0.05, AtmosphereColor = Color3.fromRGB(240, 220, 180), Haze = 1.5 }),
	},
	{
		Id = 4, Name = "Frosting Falls", Theme = "Frosting",
		RecommendedSpeed = 270, GuardSpeedBonus = 5, WakeDelay = 1.3, World = 1, Index = 4,
		Floor = { Color3.fromRGB(226, 156, 192), Color3.fromRGB(234, 172, 204) }, FloorMaterial = Enum.Material.Plastic,
		Wall = { Color3.fromRGB(150, 95, 60), Color3.fromRGB(135, 85, 55) }, WallMaterial = Enum.Material.Plastic,
		Trim = Color3.fromRGB(255, 255, 255), TrimMaterial = Enum.Material.SmoothPlastic,
		Guard = { Skin = Color3.fromRGB(255, 217, 15), Shirt = Color3.fromRGB(255, 120, 180), Pants = Color3.fromRGB(255, 255, 255), Title = "Frosted", Hat = "Party" },
		Ambience = ambience({ Tint = Color3.fromRGB(255, 238, 246), Saturation = 0, AtmosphereColor = Color3.fromRGB(255, 210, 235) }),
	},
	{
		Id = 5, Name = "Chocolate Caverns", Theme = "Chocolate",
		RecommendedSpeed = 360, GuardSpeedBonus = 5, WakeDelay = 1.2, World = 1, Index = 5,
		Floor = { Color3.fromRGB(95, 55, 35), Color3.fromRGB(80, 45, 28) }, FloorMaterial = Enum.Material.Slate,
		Wall = { Color3.fromRGB(70, 40, 25), Color3.fromRGB(58, 33, 20) }, WallMaterial = Enum.Material.Rock,
		Trim = Color3.fromRGB(150, 90, 50), TrimMaterial = Enum.Material.Slate,
		Guard = { Skin = Color3.fromRGB(200, 150, 60), Shirt = Color3.fromRGB(120, 70, 40), Pants = Color3.fromRGB(60, 35, 20), Title = "Choco", Hat = "Miner" },
		Ambience = ambience({ ClockTime = 17.2, Tint = Color3.fromRGB(255, 220, 190), Ambient = Color3.fromRGB(90, 60, 45), AtmosphereColor = Color3.fromRGB(120, 80, 50), AtmosphereDensity = 0.45, Haze = 2 }),
	},
	{
		Id = 6, Name = "Glacier Glaze", Theme = "Ice",
		RecommendedSpeed = 450, GuardSpeedBonus = 5, WakeDelay = 1.1, World = 1, Index = 6,
		Floor = { Color3.fromRGB(176, 206, 226), Color3.fromRGB(160, 192, 216) }, FloorMaterial = Enum.Material.Ice,
		Wall = { Color3.fromRGB(150, 205, 240), Color3.fromRGB(130, 190, 230) }, WallMaterial = Enum.Material.Glacier,
		Trim = Color3.fromRGB(255, 255, 255), TrimMaterial = Enum.Material.Snow,
		Guard = { Skin = Color3.fromRGB(200, 230, 255), Shirt = Color3.fromRGB(60, 140, 220), Pants = Color3.fromRGB(230, 245, 255), Aura = "Snow", Title = "Frozen", Hat = "Beanie" },
		Ambience = ambience({ ClockTime = 15.5, Tint = Color3.fromRGB(225, 240, 255), Saturation = -0.1, Ambient = Color3.fromRGB(95, 115, 138), AtmosphereColor = Color3.fromRGB(200, 230, 255), AtmosphereDensity = 0.4, Haze = 1.5 }),
	},
	{
		Id = 7, Name = "Molten Bakery", Theme = "Lava",
		RecommendedSpeed = 540, GuardSpeedBonus = 5, WakeDelay = 1.0, World = 1, Index = 7,
		Floor = { Color3.fromRGB(45, 35, 35), Color3.fromRGB(60, 42, 38) }, FloorMaterial = Enum.Material.Basalt,
		Wall = { Color3.fromRGB(50, 40, 40), Color3.fromRGB(38, 30, 30) }, WallMaterial = Enum.Material.Basalt,
		Trim = Color3.fromRGB(255, 100, 0), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(255, 120, 30), Shirt = Color3.fromRGB(40, 30, 30), Pants = Color3.fromRGB(120, 20, 10), Aura = "Fire", Title = "Lava", Hat = "Chef" },
		Ambience = ambience({ ClockTime = 18.3, Tint = Color3.fromRGB(255, 200, 170), Saturation = 0.05, Contrast = 0.15, Ambient = Color3.fromRGB(105, 52, 30), AtmosphereColor = Color3.fromRGB(255, 120, 60), AtmosphereDensity = 0.45, Haze = 2.5, Bloom = 0.35 }),
	},
	{
		Id = 8, Name = "Neon Donut City", Theme = "Neon",
		RecommendedSpeed = 630, GuardSpeedBonus = 5, WakeDelay = 0.95, World = 1, Index = 8,
		Floor = { Color3.fromRGB(25, 20, 40), Color3.fromRGB(35, 28, 55) }, FloorMaterial = Enum.Material.SmoothPlastic,
		Wall = { Color3.fromRGB(20, 18, 30), Color3.fromRGB(28, 24, 40) }, WallMaterial = Enum.Material.Metal,
		Trim = Color3.fromRGB(0, 255, 220), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(0, 255, 200), Shirt = Color3.fromRGB(255, 0, 200), Pants = Color3.fromRGB(20, 20, 40), Aura = "Neon", Title = "Neon", Hat = "Visor" },
		Ambience = ambience({ ClockTime = 0.5, Tint = Color3.fromRGB(220, 210, 255), Saturation = 0.15, Contrast = 0.2, Ambient = Color3.fromRGB(70, 55, 120), AtmosphereColor = Color3.fromRGB(80, 50, 160), AtmosphereDensity = 0.35, Haze = 1, Bloom = 0.5 }),
	},
	{
		Id = 9, Name = "Crystal Cosmos", Theme = "Crystal",
		RecommendedSpeed = 720, GuardSpeedBonus = 5, WakeDelay = 0.9, World = 1, Index = 9,
		Floor = { Color3.fromRGB(90, 50, 160), Color3.fromRGB(110, 65, 190) }, FloorMaterial = Enum.Material.Glass,
		Wall = { Color3.fromRGB(60, 30, 110), Color3.fromRGB(75, 40, 135) }, WallMaterial = Enum.Material.Glass,
		Trim = Color3.fromRGB(200, 150, 255), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(200, 160, 255), Shirt = Color3.fromRGB(90, 40, 180), Pants = Color3.fromRGB(40, 20, 90), Aura = "Sparkles", Title = "Crystal", Hat = "Crown" },
		Ambience = ambience({ ClockTime = 1, Tint = Color3.fromRGB(225, 200, 255), Saturation = 0.2, Contrast = 0.2, Ambient = Color3.fromRGB(88, 60, 138), AtmosphereColor = Color3.fromRGB(140, 90, 220), AtmosphereDensity = 0.4, Haze = 2, Bloom = 0.6 }),
	},
	{
		Id = 10, Name = "Celestial Donut Dimension", Theme = "Celestial",
		RecommendedSpeed = 810, GuardSpeedBonus = 5, WakeDelay = 0.85, World = 1, Index = 10,
		Floor = { Color3.fromRGB(15, 10, 35), Color3.fromRGB(25, 15, 55) }, FloorMaterial = Enum.Material.Glass,
		Wall = { Color3.fromRGB(10, 5, 25), Color3.fromRGB(20, 10, 40) }, WallMaterial = Enum.Material.Glass,
		Trim = Color3.fromRGB(255, 255, 255), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(255, 240, 150), Shirt = Color3.fromRGB(255, 255, 255), Pants = Color3.fromRGB(120, 80, 255), Aura = "Cosmic", Title = "Cosmic", Hat = "Halo" },
		Ambience = ambience({ ClockTime = 0, Tint = Color3.fromRGB(255, 215, 255), Saturation = 0.25, Contrast = 0.25, Ambient = Color3.fromRGB(110, 70, 150), AtmosphereColor = Color3.fromRGB(200, 120, 255), AtmosphereDensity = 0.3, Haze = 3, Bloom = 0.75 }),
	},
	{
		Id = 11, Name = "Candy Cane Canyon", Theme = "Candy",
		RecommendedSpeed = 900, GuardSpeedBonus = 5, WakeDelay = 0.84, World = 1, Index = 11,
		Floor = { Color3.fromRGB(250, 236, 240), Color3.fromRGB(240, 222, 230) }, FloorMaterial = Enum.Material.SmoothPlastic,
		Wall = { Color3.fromRGB(230, 60, 70), Color3.fromRGB(245, 245, 245) }, WallMaterial = Enum.Material.SmoothPlastic,
		Trim = Color3.fromRGB(255, 90, 120), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(255, 217, 15), Shirt = Color3.fromRGB(230, 40, 50), Pants = Color3.fromRGB(255, 255, 255), Title = "Candy", Hat = "Party" },
		Ambience = ambience({ ClockTime = 14, Tint = Color3.fromRGB(255, 240, 245), Saturation = 0.25, AtmosphereColor = Color3.fromRGB(255, 215, 230) }),
	},
	{
		Id = 12, Name = "Rainbow Sprinkle Summit", Theme = "Rainbow",
		RecommendedSpeed = 990, GuardSpeedBonus = 5, WakeDelay = 0.83, World = 1, Index = 12,
		Floor = { Color3.fromRGB(245, 250, 255), Color3.fromRGB(230, 240, 255) }, FloorMaterial = Enum.Material.Snow,
		Wall = { Color3.fromRGB(170, 200, 255), Color3.fromRGB(150, 185, 250) }, WallMaterial = Enum.Material.SmoothPlastic,
		Trim = Color3.fromRGB(255, 255, 255), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(255, 230, 120), Shirt = Color3.fromRGB(120, 200, 255), Pants = Color3.fromRGB(255, 120, 200), Aura = "Sparkles", Title = "Rainbow", Hat = "Beanie" },
		Ambience = ambience({ ClockTime = 15, Tint = Color3.fromRGB(245, 245, 255), Saturation = 0.3, Ambient = Color3.fromRGB(150, 150, 180), AtmosphereColor = Color3.fromRGB(220, 230, 255), AtmosphereDensity = 0.25, Haze = 1, Bloom = 0.4 }),
	},
	---------------------------------------------------------------- World 2: The Underworld
	-- Lava, fire and brimstone all the way down, lit like Molten Bakery: a low red sun through thick
	-- orange haze, glowing lava everywhere (client/UnderworldFX makes it churn and flicker).
	{
		Id = 13, Name = "Ember Gates", Theme = "EmberGates",
		RecommendedSpeed = 1_080, GuardSpeedBonus = 7, WakeDelay = 0.85, World = 2, Index = 1,
		Floor = { Color3.fromRGB(58, 40, 36), Color3.fromRGB(70, 48, 42) }, FloorMaterial = Enum.Material.Basalt,
		Wall = { Color3.fromRGB(44, 30, 28), Color3.fromRGB(36, 24, 22) }, WallMaterial = Enum.Material.Basalt,
		Trim = Color3.fromRGB(255, 110, 20), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(255, 140, 60), Shirt = Color3.fromRGB(50, 30, 28), Pants = Color3.fromRGB(120, 30, 15), Aura = "Fire", Title = "Gatekeeper", Hat = "Helmet" },
		Ambience = ambience({ ClockTime = 18.4, Tint = Color3.fromRGB(255, 205, 175), Saturation = 0.08, Contrast = 0.16, Ambient = Color3.fromRGB(110, 55, 32), AtmosphereColor = Color3.fromRGB(255, 120, 60), AtmosphereDensity = 0.42, Haze = 2.4, Bloom = 0.35 }),
	},
	{
		Id = 14, Name = "Brimstone Bakery", Theme = "BrimstoneBakery",
		RecommendedSpeed = 1_170, GuardSpeedBonus = 7, WakeDelay = 0.82, World = 2, Index = 2,
		Floor = { Color3.fromRGB(66, 44, 40), Color3.fromRGB(52, 36, 34) }, FloorMaterial = Enum.Material.Slate,
		Wall = { Color3.fromRGB(80, 40, 30), Color3.fromRGB(64, 32, 26) }, WallMaterial = Enum.Material.Brick,
		Trim = Color3.fromRGB(255, 150, 40), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(255, 120, 30), Shirt = Color3.fromRGB(240, 230, 220), Pants = Color3.fromRGB(60, 30, 25), Aura = "Fire", Title = "Burnt Baker", Hat = "Chef" },
		Ambience = ambience({ ClockTime = 18.3, Tint = Color3.fromRGB(255, 200, 165), Saturation = 0.1, Contrast = 0.15, Ambient = Color3.fromRGB(120, 58, 30), AtmosphereColor = Color3.fromRGB(255, 130, 60), AtmosphereDensity = 0.45, Haze = 2.5, Bloom = 0.38 }),
	},
	{
		Id = 15, Name = "Magma Rivers", Theme = "MagmaRivers",
		RecommendedSpeed = 1_260, GuardSpeedBonus = 7, WakeDelay = 0.8, World = 2, Index = 3,
		Floor = { Color3.fromRGB(40, 30, 30), Color3.fromRGB(52, 38, 36) }, FloorMaterial = Enum.Material.Basalt,
		Wall = { Color3.fromRGB(34, 24, 24), Color3.fromRGB(28, 20, 20) }, WallMaterial = Enum.Material.Basalt,
		Trim = Color3.fromRGB(255, 70, 10), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(255, 100, 30), Shirt = Color3.fromRGB(40, 25, 25), Pants = Color3.fromRGB(255, 90, 0), Aura = "Fire", Title = "Lava Surfer", Hat = "Goggles" },
		Ambience = ambience({ ClockTime = 18.6, Tint = Color3.fromRGB(255, 195, 160), Saturation = 0.12, Contrast = 0.2, Ambient = Color3.fromRGB(125, 50, 28), AtmosphereColor = Color3.fromRGB(255, 95, 40), AtmosphereDensity = 0.48, Haze = 2.8, Bloom = 0.4 }),
	},
	{
		Id = 16, Name = "Soul Caverns", Theme = "SoulCaverns",
		RecommendedSpeed = 1_350, GuardSpeedBonus = 7, WakeDelay = 0.78, World = 2, Index = 4,
		Floor = { Color3.fromRGB(30, 34, 44), Color3.fromRGB(38, 42, 54) }, FloorMaterial = Enum.Material.Slate,
		Wall = { Color3.fromRGB(24, 26, 36), Color3.fromRGB(18, 20, 28) }, WallMaterial = Enum.Material.Rock,
		Trim = Color3.fromRGB(70, 220, 255), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(140, 230, 255), Shirt = Color3.fromRGB(30, 40, 60), Pants = Color3.fromRGB(20, 30, 50), Aura = "Ghost", Title = "Soul", Hat = "Miner" },
		Ambience = ambience({ ClockTime = 0.5, Tint = Color3.fromRGB(205, 235, 255), Saturation = 0.05, Contrast = 0.2, Ambient = Color3.fromRGB(45, 65, 95), AtmosphereColor = Color3.fromRGB(60, 150, 200), AtmosphereDensity = 0.45, Haze = 2, Bloom = 0.4 }),
	},
	{
		Id = 17, Name = "Obsidian Forge", Theme = "ObsidianForge",
		RecommendedSpeed = 1_440, GuardSpeedBonus = 7, WakeDelay = 0.75, World = 2, Index = 5,
		Floor = { Color3.fromRGB(36, 30, 40), Color3.fromRGB(28, 24, 32) }, FloorMaterial = Enum.Material.DiamondPlate,
		Wall = { Color3.fromRGB(22, 18, 26), Color3.fromRGB(30, 24, 34) }, WallMaterial = Enum.Material.Basalt,
		Trim = Color3.fromRGB(255, 140, 30), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(255, 150, 60), Shirt = Color3.fromRGB(35, 30, 40), Pants = Color3.fromRGB(90, 70, 60), Aura = "Fire", Title = "Blacksmith", Hat = "Helmet" },
		Ambience = ambience({ ClockTime = 18.5, Tint = Color3.fromRGB(255, 205, 170), Saturation = 0.08, Contrast = 0.2, Ambient = Color3.fromRGB(105, 55, 40), AtmosphereColor = Color3.fromRGB(255, 125, 55), AtmosphereDensity = 0.45, Haze = 2.5, Bloom = 0.4 }),
	},
	{
		Id = 18, Name = "Inferno Spires", Theme = "InfernoSpires",
		RecommendedSpeed = 1_530, GuardSpeedBonus = 7, WakeDelay = 0.74, World = 2, Index = 6,
		Floor = { Color3.fromRGB(48, 28, 26), Color3.fromRGB(60, 34, 30) }, FloorMaterial = Enum.Material.Basalt,
		Wall = { Color3.fromRGB(40, 22, 20), Color3.fromRGB(30, 16, 16) }, WallMaterial = Enum.Material.Basalt,
		Trim = Color3.fromRGB(255, 50, 30), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(255, 80, 40), Shirt = Color3.fromRGB(30, 15, 15), Pants = Color3.fromRGB(160, 20, 20), Aura = "Fire", Title = "Inferno", Hat = "Witch" },
		Ambience = ambience({ ClockTime = 18.7, Tint = Color3.fromRGB(255, 185, 165), Saturation = 0.15, Contrast = 0.22, Ambient = Color3.fromRGB(130, 45, 30), AtmosphereColor = Color3.fromRGB(255, 70, 40), AtmosphereDensity = 0.5, Haze = 3, Bloom = 0.42 }),
	},
	{
		Id = 19, Name = "The Molten Core", Theme = "MoltenCore",
		RecommendedSpeed = 1_620, GuardSpeedBonus = 7, WakeDelay = 0.73, World = 2, Index = 7,
		Floor = { Color3.fromRGB(70, 40, 30), Color3.fromRGB(56, 32, 26) }, FloorMaterial = Enum.Material.Basalt,
		Wall = { Color3.fromRGB(50, 26, 20), Color3.fromRGB(38, 20, 16) }, WallMaterial = Enum.Material.Basalt,
		Trim = Color3.fromRGB(255, 190, 50), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(255, 200, 80), Shirt = Color3.fromRGB(120, 20, 10), Pants = Color3.fromRGB(40, 15, 10), Aura = "Fire", Title = "Magma King", Hat = "Crown" },
		Ambience = ambience({ ClockTime = 18.8, Tint = Color3.fromRGB(255, 200, 160), Saturation = 0.15, Contrast = 0.25, Ambient = Color3.fromRGB(140, 60, 30), AtmosphereColor = Color3.fromRGB(255, 110, 40), AtmosphereDensity = 0.5, Haze = 3, Bloom = 0.45 }),
	},
	---------------------------------------------------------------- World 3: Dream Dimension
	{
		Id = 20, Name = "Cloud Bakery", Theme = "Clouds",
		RecommendedSpeed = 1_710, GuardSpeedBonus = 9, WakeDelay = 0.75, World = 3, Index = 1,
		Floor = { Color3.fromRGB(246, 246, 255), Color3.fromRGB(232, 236, 250) }, FloorMaterial = Enum.Material.SmoothPlastic,
		Wall = { Color3.fromRGB(205, 222, 255), Color3.fromRGB(190, 210, 250) }, WallMaterial = Enum.Material.SmoothPlastic,
		Trim = Color3.fromRGB(255, 190, 225), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(255, 225, 120), Shirt = Color3.fromRGB(255, 255, 255), Pants = Color3.fromRGB(180, 200, 255), Aura = "Sparkles", Title = "Angel", Hat = "Chef" },
		Ambience = ambience({ ClockTime = 12, Tint = Color3.fromRGB(255, 240, 250), Saturation = 0.1, AtmosphereColor = Color3.fromRGB(255, 230, 245), AtmosphereDensity = 0.2, Haze = 1 }),
	},
	{
		Id = 21, Name = "Toy Factory", Theme = "Toys",
		RecommendedSpeed = 1_800, GuardSpeedBonus = 9, WakeDelay = 0.72, World = 3, Index = 2,
		Floor = { Color3.fromRGB(255, 205, 70), Color3.fromRGB(80, 165, 255) }, FloorMaterial = Enum.Material.Plastic,
		Wall = { Color3.fromRGB(240, 80, 80), Color3.fromRGB(80, 200, 110) }, WallMaterial = Enum.Material.Plastic,
		Trim = Color3.fromRGB(255, 255, 255), TrimMaterial = Enum.Material.SmoothPlastic,
		Guard = { Skin = Color3.fromRGB(255, 217, 15), Shirt = Color3.fromRGB(255, 70, 70), Pants = Color3.fromRGB(60, 120, 255), Title = "Toy", Hat = "Propeller" },
		Ambience = ambience({ ClockTime = 13, Saturation = 0.25 }),
	},
	{
		Id = 22, Name = "Haunted Donuttery", Theme = "Haunted",
		RecommendedSpeed = 1_890, GuardSpeedBonus = 9, WakeDelay = 0.7, World = 3, Index = 3,
		Floor = { Color3.fromRGB(62, 52, 72), Color3.fromRGB(52, 44, 62) }, FloorMaterial = Enum.Material.Slate,
		Wall = { Color3.fromRGB(42, 36, 52), Color3.fromRGB(34, 30, 44) }, WallMaterial = Enum.Material.Brick,
		Trim = Color3.fromRGB(140, 255, 120), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(210, 230, 210), Shirt = Color3.fromRGB(60, 50, 70), Pants = Color3.fromRGB(30, 25, 40), Aura = "Ghost", Title = "Ghost", Hat = "Witch" },
		Ambience = ambience({ ClockTime = 22, Tint = Color3.fromRGB(215, 255, 215), Saturation = 0, Contrast = 0.2, Ambient = Color3.fromRGB(70, 90, 80), AtmosphereColor = Color3.fromRGB(90, 140, 100), AtmosphereDensity = 0.5, Haze = 2.5, Bloom = 0.4 }),
	},
	{
		Id = 23, Name = "Clockwork Void", Theme = "Clockwork",
		RecommendedSpeed = 1_980, GuardSpeedBonus = 9, WakeDelay = 0.7, World = 3, Index = 4,
		Floor = { Color3.fromRGB(72, 62, 92), Color3.fromRGB(86, 74, 108) }, FloorMaterial = Enum.Material.DiamondPlate,
		Wall = { Color3.fromRGB(42, 36, 62), Color3.fromRGB(34, 30, 52) }, WallMaterial = Enum.Material.Metal,
		Trim = Color3.fromRGB(255, 190, 60), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(200, 200, 215), Shirt = Color3.fromRGB(120, 90, 50), Pants = Color3.fromRGB(60, 50, 80), Aura = "Neon", Title = "Robo", Hat = "Gears" },
		Ambience = ambience({ ClockTime = 19.4, Tint = Color3.fromRGB(235, 220, 255), Saturation = 0.1, Contrast = 0.2, Ambient = Color3.fromRGB(90, 70, 130), AtmosphereColor = Color3.fromRGB(140, 100, 200), AtmosphereDensity = 0.35, Haze = 1.5, Bloom = 0.5 }),
	},
	{
		Id = 24, Name = "Donut Heaven", Theme = "Heaven",
		RecommendedSpeed = 2_070, GuardSpeedBonus = 9, WakeDelay = 0.7, World = 3, Index = 5,
		Floor = { Color3.fromRGB(255, 242, 205), Color3.fromRGB(255, 230, 175) }, FloorMaterial = Enum.Material.Marble,
		Wall = { Color3.fromRGB(255, 250, 238), Color3.fromRGB(245, 238, 220) }, WallMaterial = Enum.Material.Marble,
		Trim = Color3.fromRGB(255, 215, 90), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(255, 230, 140), Shirt = Color3.fromRGB(255, 255, 255), Pants = Color3.fromRGB(255, 215, 90), Aura = "Cosmic", Title = "Golden", Hat = "Halo" },
		Ambience = ambience({ ClockTime = 12, Tint = Color3.fromRGB(255, 245, 220), Saturation = 0.1, AtmosphereColor = Color3.fromRGB(255, 235, 190), AtmosphereDensity = 0.25, Haze = 1.5, Bloom = 0.6 }),
	},
	{
		Id = 25, Name = "Starfall Garden", Theme = "Starfall",
		RecommendedSpeed = 2_160, GuardSpeedBonus = 9, WakeDelay = 0.68, World = 3, Index = 6,
		Floor = { Color3.fromRGB(40, 30, 80), Color3.fromRGB(52, 40, 100) }, FloorMaterial = Enum.Material.Grass,
		Wall = { Color3.fromRGB(30, 24, 64), Color3.fromRGB(40, 32, 80) }, WallMaterial = Enum.Material.SmoothPlastic,
		Trim = Color3.fromRGB(255, 235, 140), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(255, 240, 180), Shirt = Color3.fromRGB(80, 60, 170), Pants = Color3.fromRGB(40, 30, 90), Aura = "Cosmic", Title = "Starry", Hat = "Witch" },
		Ambience = ambience({ ClockTime = 0.5, Tint = Color3.fromRGB(230, 220, 255), Saturation = 0.25, Contrast = 0.2, Ambient = Color3.fromRGB(100, 90, 160), AtmosphereColor = Color3.fromRGB(120, 100, 220), AtmosphereDensity = 0.3, Haze = 1.5, Bloom = 0.7 }),
	},
	{
		Id = 26, Name = "Aurora Palace", Theme = "Aurora",
		RecommendedSpeed = 2_250, GuardSpeedBonus = 9, WakeDelay = 0.66, World = 3, Index = 7,
		Floor = { Color3.fromRGB(215, 240, 255), Color3.fromRGB(200, 230, 250) }, FloorMaterial = Enum.Material.Glass,
		Wall = { Color3.fromRGB(170, 215, 255), Color3.fromRGB(150, 200, 245) }, WallMaterial = Enum.Material.Glass,
		Trim = Color3.fromRGB(120, 255, 200), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(220, 240, 255), Shirt = Color3.fromRGB(120, 255, 210), Pants = Color3.fromRGB(150, 120, 255), Aura = "Snow", Title = "Aurora", Hat = "Crown" },
		Ambience = ambience({ ClockTime = 22.5, Tint = Color3.fromRGB(220, 255, 245), Saturation = 0.3, Contrast = 0.2, Ambient = Color3.fromRGB(90, 140, 150), AtmosphereColor = Color3.fromRGB(100, 220, 200), AtmosphereDensity = 0.3, Haze = 1.5, Bloom = 0.8 }),
	},
	---------------------------------------------------------------- World 4: Cyber City
	{
		Id = 27, Name = "Neon Streets", Theme = "CyberStreets",
		RecommendedSpeed = 2_340, GuardSpeedBonus = 11, WakeDelay = 0.66, World = 4, Index = 1,
		Floor = { Color3.fromRGB(30, 30, 42), Color3.fromRGB(38, 38, 52) }, FloorMaterial = Enum.Material.Asphalt,
		Wall = { Color3.fromRGB(24, 22, 40), Color3.fromRGB(32, 30, 52) }, WallMaterial = Enum.Material.Metal,
		Trim = Color3.fromRGB(255, 40, 200), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(0, 255, 220), Shirt = Color3.fromRGB(255, 40, 200), Pants = Color3.fromRGB(30, 30, 50), Aura = "Neon", Title = "Street", Hat = "Visor" },
		Ambience = ambience({ ClockTime = 1, Tint = Color3.fromRGB(235, 215, 255), Saturation = 0.25, Contrast = 0.25, Ambient = Color3.fromRGB(80, 60, 140), AtmosphereColor = Color3.fromRGB(200, 60, 255), AtmosphereDensity = 0.46, Haze = 2, Bloom = 0.7 }),
	},
	{
		Id = 28, Name = "Hologram Mall", Theme = "Hologram",
		RecommendedSpeed = 2_430, GuardSpeedBonus = 11, WakeDelay = 0.65, World = 4, Index = 2,
		Floor = { Color3.fromRGB(210, 220, 235), Color3.fromRGB(190, 200, 220) }, FloorMaterial = Enum.Material.Marble,
		Wall = { Color3.fromRGB(60, 70, 100), Color3.fromRGB(70, 80, 115) }, WallMaterial = Enum.Material.Glass,
		Trim = Color3.fromRGB(0, 230, 255), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(0, 255, 220), Shirt = Color3.fromRGB(0, 200, 255), Pants = Color3.fromRGB(240, 240, 255), Aura = "Neon", Title = "Holo", Hat = "Goggles" },
		Ambience = ambience({ ClockTime = 20.5, Tint = Color3.fromRGB(215, 240, 255), Saturation = 0.25, Contrast = 0.25, Ambient = Color3.fromRGB(80, 60, 140), AtmosphereColor = Color3.fromRGB(80, 200, 255), AtmosphereDensity = 0.46, Haze = 2, Bloom = 0.7 }),
	},
	{
		Id = 29, Name = "Robot Factory", Theme = "RobotFactory",
		RecommendedSpeed = 2_520, GuardSpeedBonus = 11, WakeDelay = 0.64, World = 4, Index = 3,
		Floor = { Color3.fromRGB(90, 95, 105), Color3.fromRGB(78, 82, 92) }, FloorMaterial = Enum.Material.DiamondPlate,
		Wall = { Color3.fromRGB(60, 62, 70), Color3.fromRGB(50, 52, 60) }, WallMaterial = Enum.Material.Metal,
		Trim = Color3.fromRGB(255, 190, 0), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(0, 255, 220), Shirt = Color3.fromRGB(255, 190, 0), Pants = Color3.fromRGB(60, 60, 70), Aura = "Fire", Title = "Robo", Hat = "Helmet" },
		Ambience = ambience({ ClockTime = 19, Tint = Color3.fromRGB(255, 235, 210), Saturation = 0.25, Contrast = 0.25, Ambient = Color3.fromRGB(80, 60, 140), AtmosphereColor = Color3.fromRGB(255, 170, 60), AtmosphereDensity = 0.46, Haze = 2, Bloom = 0.7 }),
	},
	{
		Id = 30, Name = "Data Highway", Theme = "DataHighway",
		RecommendedSpeed = 2_610, GuardSpeedBonus = 11, WakeDelay = 0.63, World = 4, Index = 4,
		Floor = { Color3.fromRGB(15, 25, 35), Color3.fromRGB(20, 35, 50) }, FloorMaterial = Enum.Material.Glass,
		Wall = { Color3.fromRGB(10, 20, 30), Color3.fromRGB(15, 28, 42) }, WallMaterial = Enum.Material.Glass,
		Trim = Color3.fromRGB(40, 255, 120), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(0, 255, 220), Shirt = Color3.fromRGB(40, 255, 120), Pants = Color3.fromRGB(10, 30, 20), Aura = "Neon", Title = "Data", Hat = "Visor" },
		Ambience = ambience({ ClockTime = 1, Tint = Color3.fromRGB(210, 255, 225), Saturation = 0.25, Contrast = 0.25, Ambient = Color3.fromRGB(80, 60, 140), AtmosphereColor = Color3.fromRGB(40, 255, 140), AtmosphereDensity = 0.46, Haze = 2, Bloom = 0.7 }),
	},
	{
		Id = 31, Name = "Firewall Fortress", Theme = "Firewall",
		RecommendedSpeed = 2_700, GuardSpeedBonus = 11, WakeDelay = 0.62, World = 4, Index = 5,
		Floor = { Color3.fromRGB(50, 20, 20), Color3.fromRGB(64, 26, 24) }, FloorMaterial = Enum.Material.Metal,
		Wall = { Color3.fromRGB(40, 15, 15), Color3.fromRGB(55, 20, 20) }, WallMaterial = Enum.Material.Metal,
		Trim = Color3.fromRGB(255, 50, 30), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(0, 255, 220), Shirt = Color3.fromRGB(255, 60, 40), Pants = Color3.fromRGB(40, 10, 10), Aura = "Fire", Title = "Firewall", Hat = "Helmet" },
		Ambience = ambience({ ClockTime = 0, Tint = Color3.fromRGB(255, 215, 205), Saturation = 0.25, Contrast = 0.25, Ambient = Color3.fromRGB(80, 60, 140), AtmosphereColor = Color3.fromRGB(255, 60, 40), AtmosphereDensity = 0.46, Haze = 2, Bloom = 0.7 }),
	},
	{
		Id = 32, Name = "Glitch Zone", Theme = "Glitch",
		RecommendedSpeed = 2_790, GuardSpeedBonus = 11, WakeDelay = 0.61, World = 4, Index = 6,
		Floor = { Color3.fromRGB(20, 20, 20), Color3.fromRGB(245, 245, 245) }, FloorMaterial = Enum.Material.SmoothPlastic,
		Wall = { Color3.fromRGB(255, 0, 200), Color3.fromRGB(0, 255, 220) }, WallMaterial = Enum.Material.Neon,
		Trim = Color3.fromRGB(255, 255, 0), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(0, 255, 220), Shirt = Color3.fromRGB(0, 0, 0), Pants = Color3.fromRGB(255, 0, 200), Aura = "Cosmic", Title = "Glitched", Hat = "Gears" },
		Ambience = ambience({ ClockTime = 0, Tint = Color3.fromRGB(240, 220, 255), Saturation = 0.25, Contrast = 0.25, Ambient = Color3.fromRGB(80, 60, 140), AtmosphereColor = Color3.fromRGB(255, 0, 200), AtmosphereDensity = 0.46, Haze = 2, Bloom = 0.7 }),
	},
	{
		Id = 33, Name = "The Mainframe", Theme = "Mainframe",
		RecommendedSpeed = 2_880, GuardSpeedBonus = 11, WakeDelay = 0.6, World = 4, Index = 7,
		Floor = { Color3.fromRGB(10, 12, 30), Color3.fromRGB(18, 22, 50) }, FloorMaterial = Enum.Material.Glass,
		Wall = { Color3.fromRGB(8, 10, 25), Color3.fromRGB(14, 18, 40) }, WallMaterial = Enum.Material.Glass,
		Trim = Color3.fromRGB(80, 160, 255), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(0, 255, 220), Shirt = Color3.fromRGB(255, 255, 255), Pants = Color3.fromRGB(40, 90, 255), Aura = "Cosmic", Title = "Mainframe", Hat = "Halo" },
		Ambience = ambience({ ClockTime = 0, Tint = Color3.fromRGB(215, 230, 255), Saturation = 0.25, Contrast = 0.25, Ambient = Color3.fromRGB(80, 60, 140), AtmosphereColor = Color3.fromRGB(80, 140, 255), AtmosphereDensity = 0.46, Haze = 2, Bloom = 0.7 }),
	},
	{
		-- The end of Cyber City: bigger and wider than any other area. A pit on its right-hand side
		-- drops into the secret lab, where a black hole is held in an experiment behind a glass
		-- window, and the big red ULTIMATE REBIRTH button sends you to World 2.
		Id = 34, Name = "The Black Hole", Theme = "BlackHole",
		RecommendedSpeed = 2_970, GuardSpeedBonus = 11, WakeDelay = 0.59, World = 4, Index = 8,
		Length = 240, HalfWidth = 95, Lab = true,
		Floor = { Color3.fromRGB(14, 10, 26), Color3.fromRGB(22, 16, 40) }, FloorMaterial = Enum.Material.Glass,
		Wall = { Color3.fromRGB(10, 8, 20), Color3.fromRGB(18, 12, 34) }, WallMaterial = Enum.Material.Glass,
		Trim = Color3.fromRGB(170, 90, 255), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(0, 255, 220), Shirt = Color3.fromRGB(20, 20, 30), Pants = Color3.fromRGB(120, 60, 255), Aura = "Cosmic", Title = "Event Horizon", Hat = "Halo" },
		Ambience = ambience({ ClockTime = 0, Tint = Color3.fromRGB(230, 215, 255), Saturation = 0.35, Contrast = 0.32, Ambient = Color3.fromRGB(70, 50, 130), AtmosphereColor = Color3.fromRGB(90, 50, 200), AtmosphereDensity = 0.36, Haze = 1.2, Bloom = 0.7 }),
	},
} :: { Area }

-- World 2 (after an ULTIMATE REBIRTH): Donut Land's twelve areas again, under a starry sky, with
-- rarer cosmic donuts (Donuts.luau makes them from Donut Land's).
Areas.CosmicOffset = #Areas.List -- World 2's area N is area CosmicOffset + N (35..46)
for index = 1, 12 do
	local source = Areas.List[index]
	local copy = table.clone(source)
	copy.Id = Areas.CosmicOffset + index
	copy.Name = "Cosmic " .. source.Name
	copy.World = 5
	copy.Index = index
	-- Galactic: a starry night, and the ground and walls turned deep cosmic purple
	copy.Ambience = table.clone(source.Ambience)
	copy.Ambience.ClockTime = 0
	copy.Ambience.Tint = source.Ambience.Tint:Lerp(Color3.fromRGB(215, 200, 255), 0.5)
	copy.Ambience.Ambient = Color3.fromRGB(120, 105, 175)
	copy.Ambience.AtmosphereColor = Color3.fromRGB(80, 50, 160)
	copy.Ambience.AtmosphereDensity = 0.22
	copy.Ambience.Haze = 0.4
	copy.Ambience.Bloom = source.Ambience.Bloom + 0.1
	copy.Floor = { source.Floor[1]:Lerp(Color3.fromRGB(46, 30, 92), 0.7), source.Floor[2]:Lerp(Color3.fromRGB(36, 24, 76), 0.7) }
	copy.Wall = { source.Wall[1]:Lerp(Color3.fromRGB(30, 22, 64), 0.75), source.Wall[2]:Lerp(Color3.fromRGB(24, 18, 52), 0.75) }
	copy.Trim = source.Trim:Lerp(Color3.fromRGB(170, 120, 255), 0.6)
	copy.TrimMaterial = Enum.Material.Neon
	table.insert(Areas.List, copy)
end

Areas.Worlds = {
	{ Id = 1, Name = "Donut Land", OffsetX = 0, BridgeLength = 0, RequiredRebirths = 0, WalkMultiplier = 1, Color = Color3.fromRGB(120, 210, 56), Icon = "🍩" },
	{ Id = 2, Name = "The Underworld", OffsetX = 2600, BridgeLength = 1920, RequiredRebirths = 1, WalkMultiplier = 1.2, Color = Color3.fromRGB(255, 90, 30), Icon = "🔥" },
	{ Id = 3, Name = "Dream Dimension", OffsetX = -2600, BridgeLength = 3040, RequiredRebirths = 2, WalkMultiplier = 1.3, Color = Color3.fromRGB(200, 140, 255), Icon = "🌙" },
	{ Id = 4, Name = "Cyber City", OffsetX = 5200, BridgeLength = 4160, RequiredRebirths = 3, WalkMultiplier = 1.45, Color = Color3.fromRGB(255, 40, 200), Icon = "🌆" },
	-- Reached by pressing ULTIMATE REBIRTH in The Black Hole's secret lab (no rebirths needed after).
	{ Id = 5, Name = "World 2", OffsetX = -5200, BridgeLength = 0, RequiredRebirths = 0, RequiredUltimate = 1, WalkMultiplier = 1, Color = Color3.fromRGB(90, 120, 255), Icon = "🌌" },
} :: { World }

Areas.UltimateWorld = 5 -- "World 2": where the ULTIMATE REBIRTH sends you

Areas.ByWorld = {} :: { [number]: { Area } }
for _, area in Areas.List do
	Areas.ByWorld[area.World] = Areas.ByWorld[area.World] or {}
	table.insert(Areas.ByWorld[area.World], area)
end

function Areas.Get(id: number): Area?
	return Areas.List[id]
end

function Areas.World(id: number): World
	return Areas.Worlds[id] or Areas.Worlds[1]
end

return Areas
