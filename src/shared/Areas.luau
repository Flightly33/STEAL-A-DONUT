--[[
	Areas, from the safe zone outwards. Early areas are plain and bright; later areas get darker,
	more magical, and are guarded by faster guards.

	RecommendedSpeed is in "Speed stat" units (the big number in the HUD). The guard's WalkSpeed is
	derived from it (see Economy.GuardWalkSpeed) so the two always stay in sync when you rebalance.

	Balance (simulated with ~120ms of network lag): at the recommended speed you escape even from
	the donut right next to the guard. About 2 walk speed below it, the risky donuts near him get you
	caught; about 8 below, nothing in the area is safe. Area 1 is escapable at the starting speed.

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
	Guard: { Skin: Color3, Shirt: Color3, Pants: Color3, Aura: string?, Title: string },
	Ambience: Ambience,
}

local Areas = {}

local DAY = {
	ClockTime = 14,
	Tint = Color3.fromRGB(255, 255, 255),
	Saturation = 0.1,
	Contrast = 0.05,
	Ambient = Color3.fromRGB(120, 120, 130),
	AtmosphereColor = Color3.fromRGB(199, 214, 234),
	AtmosphereDensity = 0.25,
	Haze = 0,
	Bloom = 0.4,
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
	{
		Id = 1, Name = "Glazed Meadow", Theme = "Meadow",
		RecommendedSpeed = 0, GuardSpeedBonus = 3, WakeDelay = 1.6,
		Floor = { Color3.fromRGB(120, 205, 70), Color3.fromRGB(105, 190, 60) }, FloorMaterial = Enum.Material.Plastic,
		Wall = { Color3.fromRGB(205, 135, 75), Color3.fromRGB(190, 120, 65) }, WallMaterial = Enum.Material.Plastic,
		Trim = Color3.fromRGB(90, 200, 60), TrimMaterial = Enum.Material.Grass,
		Guard = { Skin = Color3.fromRGB(255, 217, 15), Shirt = Color3.fromRGB(245, 245, 245), Pants = Color3.fromRGB(70, 110, 200), Title = "Sleepy" },
		Ambience = ambience({}),
	},
	{
		Id = 2, Name = "Sprinkle Park", Theme = "Park",
		RecommendedSpeed = 25, GuardSpeedBonus = 3, WakeDelay = 1.5,
		Floor = { Color3.fromRGB(140, 220, 90), Color3.fromRGB(125, 205, 80) }, FloorMaterial = Enum.Material.Plastic,
		Wall = { Color3.fromRGB(215, 145, 85), Color3.fromRGB(198, 128, 72) }, WallMaterial = Enum.Material.Plastic,
		Trim = Color3.fromRGB(255, 120, 200), TrimMaterial = Enum.Material.SmoothPlastic,
		Guard = { Skin = Color3.fromRGB(255, 217, 15), Shirt = Color3.fromRGB(255, 170, 210), Pants = Color3.fromRGB(70, 110, 200), Title = "Sprinkle" },
		Ambience = ambience({ Saturation = 0.2 }),
	},
	{
		Id = 3, Name = "Sugar Dunes", Theme = "Desert",
		RecommendedSpeed = 200, GuardSpeedBonus = 3, WakeDelay = 1.4,
		Floor = { Color3.fromRGB(240, 215, 150), Color3.fromRGB(228, 200, 135) }, FloorMaterial = Enum.Material.Sand,
		Wall = { Color3.fromRGB(215, 170, 100), Color3.fromRGB(200, 155, 90) }, WallMaterial = Enum.Material.Sandstone,
		Trim = Color3.fromRGB(255, 240, 200), TrimMaterial = Enum.Material.Sandstone,
		Guard = { Skin = Color3.fromRGB(255, 200, 40), Shirt = Color3.fromRGB(240, 220, 170), Pants = Color3.fromRGB(150, 110, 60), Title = "Desert" },
		Ambience = ambience({ Tint = Color3.fromRGB(255, 244, 225), Saturation = 0.15, AtmosphereColor = Color3.fromRGB(240, 220, 180), Haze = 1 }),
	},
	{
		Id = 4, Name = "Frosting Falls", Theme = "Frosting",
		RecommendedSpeed = 1_500, GuardSpeedBonus = 3, WakeDelay = 1.3,
		Floor = { Color3.fromRGB(255, 175, 215), Color3.fromRGB(255, 195, 225) }, FloorMaterial = Enum.Material.SmoothPlastic,
		Wall = { Color3.fromRGB(150, 95, 60), Color3.fromRGB(135, 85, 55) }, WallMaterial = Enum.Material.Plastic,
		Trim = Color3.fromRGB(255, 255, 255), TrimMaterial = Enum.Material.SmoothPlastic,
		Guard = { Skin = Color3.fromRGB(255, 217, 15), Shirt = Color3.fromRGB(255, 120, 180), Pants = Color3.fromRGB(255, 255, 255), Title = "Frosted" },
		Ambience = ambience({ Tint = Color3.fromRGB(255, 235, 245), Saturation = 0.3, AtmosphereColor = Color3.fromRGB(255, 210, 235) }),
	},
	{
		Id = 5, Name = "Chocolate Caverns", Theme = "Chocolate",
		RecommendedSpeed = 12_000, GuardSpeedBonus = 3, WakeDelay = 1.2,
		Floor = { Color3.fromRGB(95, 55, 35), Color3.fromRGB(80, 45, 28) }, FloorMaterial = Enum.Material.Slate,
		Wall = { Color3.fromRGB(70, 40, 25), Color3.fromRGB(58, 33, 20) }, WallMaterial = Enum.Material.Rock,
		Trim = Color3.fromRGB(150, 90, 50), TrimMaterial = Enum.Material.Slate,
		Guard = { Skin = Color3.fromRGB(200, 150, 60), Shirt = Color3.fromRGB(120, 70, 40), Pants = Color3.fromRGB(60, 35, 20), Title = "Choco" },
		Ambience = ambience({ ClockTime = 17.2, Tint = Color3.fromRGB(255, 220, 190), Ambient = Color3.fromRGB(90, 60, 45), AtmosphereColor = Color3.fromRGB(120, 80, 50), AtmosphereDensity = 0.45, Haze = 2 }),
	},
	{
		Id = 6, Name = "Glacier Glaze", Theme = "Ice",
		RecommendedSpeed = 100_000, GuardSpeedBonus = 3, WakeDelay = 1.1,
		Floor = { Color3.fromRGB(215, 240, 255), Color3.fromRGB(195, 228, 250) }, FloorMaterial = Enum.Material.Ice,
		Wall = { Color3.fromRGB(150, 205, 240), Color3.fromRGB(130, 190, 230) }, WallMaterial = Enum.Material.Glacier,
		Trim = Color3.fromRGB(255, 255, 255), TrimMaterial = Enum.Material.Snow,
		Guard = { Skin = Color3.fromRGB(200, 230, 255), Shirt = Color3.fromRGB(60, 140, 220), Pants = Color3.fromRGB(230, 245, 255), Aura = "Snow", Title = "Frozen" },
		Ambience = ambience({ ClockTime = 15.5, Tint = Color3.fromRGB(225, 240, 255), Saturation = 0.1, Ambient = Color3.fromRGB(140, 170, 200), AtmosphereColor = Color3.fromRGB(200, 230, 255), AtmosphereDensity = 0.4, Haze = 1.5 }),
	},
	{
		Id = 7, Name = "Molten Bakery", Theme = "Lava",
		RecommendedSpeed = 800_000, GuardSpeedBonus = 3, WakeDelay = 1.0,
		Floor = { Color3.fromRGB(45, 35, 35), Color3.fromRGB(60, 42, 38) }, FloorMaterial = Enum.Material.Basalt,
		Wall = { Color3.fromRGB(50, 40, 40), Color3.fromRGB(38, 30, 30) }, WallMaterial = Enum.Material.Basalt,
		Trim = Color3.fromRGB(255, 100, 0), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(255, 120, 30), Shirt = Color3.fromRGB(40, 30, 30), Pants = Color3.fromRGB(120, 20, 10), Aura = "Fire", Title = "Lava" },
		Ambience = ambience({ ClockTime = 18.3, Tint = Color3.fromRGB(255, 200, 170), Saturation = 0.25, Contrast = 0.15, Ambient = Color3.fromRGB(140, 60, 30), AtmosphereColor = Color3.fromRGB(255, 120, 60), AtmosphereDensity = 0.45, Haze = 2.5, Bloom = 0.8 }),
	},
	{
		Id = 8, Name = "Neon Donut City", Theme = "Neon",
		RecommendedSpeed = 7_000_000, GuardSpeedBonus = 3, WakeDelay = 0.95,
		Floor = { Color3.fromRGB(25, 20, 40), Color3.fromRGB(35, 28, 55) }, FloorMaterial = Enum.Material.SmoothPlastic,
		Wall = { Color3.fromRGB(20, 18, 30), Color3.fromRGB(28, 24, 40) }, WallMaterial = Enum.Material.Metal,
		Trim = Color3.fromRGB(0, 255, 220), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(0, 255, 200), Shirt = Color3.fromRGB(255, 0, 200), Pants = Color3.fromRGB(20, 20, 40), Aura = "Neon", Title = "Neon" },
		Ambience = ambience({ ClockTime = 0.5, Tint = Color3.fromRGB(220, 210, 255), Saturation = 0.35, Contrast = 0.2, Ambient = Color3.fromRGB(80, 60, 140), AtmosphereColor = Color3.fromRGB(80, 50, 160), AtmosphereDensity = 0.35, Haze = 1, Bloom = 1.2 }),
	},
	{
		Id = 9, Name = "Crystal Cosmos", Theme = "Crystal",
		RecommendedSpeed = 60_000_000, GuardSpeedBonus = 3, WakeDelay = 0.9,
		Floor = { Color3.fromRGB(90, 50, 160), Color3.fromRGB(110, 65, 190) }, FloorMaterial = Enum.Material.Glass,
		Wall = { Color3.fromRGB(60, 30, 110), Color3.fromRGB(75, 40, 135) }, WallMaterial = Enum.Material.Glass,
		Trim = Color3.fromRGB(200, 150, 255), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(200, 160, 255), Shirt = Color3.fromRGB(90, 40, 180), Pants = Color3.fromRGB(40, 20, 90), Aura = "Sparkles", Title = "Crystal" },
		Ambience = ambience({ ClockTime = 1, Tint = Color3.fromRGB(225, 200, 255), Saturation = 0.4, Contrast = 0.2, Ambient = Color3.fromRGB(110, 70, 170), AtmosphereColor = Color3.fromRGB(140, 90, 220), AtmosphereDensity = 0.4, Haze = 2, Bloom = 1.4 }),
	},
	{
		Id = 10, Name = "Celestial Donut Dimension", Theme = "Celestial",
		RecommendedSpeed = 500_000_000, GuardSpeedBonus = 3, WakeDelay = 0.85,
		Floor = { Color3.fromRGB(15, 10, 35), Color3.fromRGB(25, 15, 55) }, FloorMaterial = Enum.Material.Glass,
		Wall = { Color3.fromRGB(10, 5, 25), Color3.fromRGB(20, 10, 40) }, WallMaterial = Enum.Material.Glass,
		Trim = Color3.fromRGB(255, 255, 255), TrimMaterial = Enum.Material.Neon,
		Guard = { Skin = Color3.fromRGB(255, 240, 150), Shirt = Color3.fromRGB(255, 255, 255), Pants = Color3.fromRGB(120, 80, 255), Aura = "Cosmic", Title = "Cosmic" },
		Ambience = ambience({ ClockTime = 0, Tint = Color3.fromRGB(255, 215, 255), Saturation = 0.5, Contrast = 0.25, Ambient = Color3.fromRGB(150, 90, 200), AtmosphereColor = Color3.fromRGB(200, 120, 255), AtmosphereDensity = 0.3, Haze = 3, Bloom = 1.8 }),
	},
} :: { Area }

function Areas.Get(id: number): Area?
	return Areas.List[id]
end

return Areas
