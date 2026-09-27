--[[
	Config
	======
	Every tunable number in the game lives here (plus Areas.luau / Donuts.luau / Rarities.luau).
	You should be able to rebalance the whole game without touching any other script.

	>>> BEFORE PUBLISHING <<<
	1. Create the Game Passes on the Creator Dashboard and paste their IDs into
	   Config.GamePasses[...].GamePassId and Config.Skins[...].GamePassId.
	   A GamePassId of 0 means "not set up yet" and the item shows as "Coming Soon" in live servers.
	2. In Studio: Game Settings > Security > "Enable Studio Access to API Services" so DataStores work
	   while testing.
]]

export type TreadmillTier = {
	Name: string,
	Rate: number,
	Cost: number,
	Base: Color3,
	Accent: Color3,
	Material: Enum.Material,
	Neon: boolean?,
	Fire: boolean?,
	Light: boolean?,
	Sparkles: boolean?,
	Rainbow: boolean?,
	Halo: boolean?,
}

export type GamePass = {
	Key: string,
	Name: string,
	Kind: string,
	Multiplier: number,
	GamePassId: number,
	SuggestedPrice: number,
	Color: Color3,
}

export type Skin = {
	Id: string,
	Name: string,
	GamePassId: number,
	SuggestedPrice: number,
	Free: boolean?,
	Floor: Color3,
	FloorAlt: Color3,
	FloorMaterial: Enum.Material,
	Fence: Color3,
	FenceMaterial: Enum.Material,
	Trim: Color3,
	TrimMaterial: Enum.Material,
	Pedestal: Color3,
	PedestalMaterial: Enum.Material,
	Effect: string?,
}

local Config = {}

Config.GameName = "Steal a Donut"

--------------------------------------------------------------------------------
-- Guard (the sleeping donut-lover who guards each area)
--------------------------------------------------------------------------------
Config.Guard = {
	-- Shown above every guard and in all UI text ("Homer is chasing you!").
	-- NOTE: "Homer Simpson" is Disney/Fox IP. Roblox removes games for IP infringement when a rights
	-- holder files a DMCA claim. Changing this one string renames the guard everywhere.
	Name = "Homer",

	Scale = 1.7, -- model scale (1 = normal player size)
	CatchRadius = 5.5, -- studs (horizontal) between guard and player that counts as "caught"
	ReturnSpeedMultiplier = 0.6, -- how fast he walks home compared to his chase speed
	MaxGuardsPerArea = 3, -- extra copies wake up if several players steal in the same area at once
	StunTime = 1.6, -- seconds a caught player is frozen before being sent home

	-- Random line he yells when he wakes up.
	WakeShouts = { "D'OH!", "HEY! MY DONUT!", "WHY YOU LITTLE...!", "MMM... DONUT THIEF!", "COME BACK HERE!" },
	CatchShouts = { "WOO-HOO!", "GOTCHA!", "MINE! ALL MINE!", "MMM... DONUT..." },
}

--------------------------------------------------------------------------------
-- Map layout (studs). Floor top is at Y = 0.
--------------------------------------------------------------------------------
Config.Map = {
	LaneHalfWidth = 60, -- the lane runs along +Z, from X = -60 to X = 60
	AreaLength = 160, -- each area is this long in Z (must be a multiple of TileSize)
	TileSize = 20,
	LaneWallHeight = 60,

	SafeZoneZ = 0, -- everything with Z < SafeZoneZ is the safe hub (bases, shop, leaderboards)
	HubHalfWidth = 230,
	HubDepth = 260,
	HubWallHeight = 40,

	DonutSpawnsPerArea = 7,
}

--------------------------------------------------------------------------------
-- Player bases (plots)
--------------------------------------------------------------------------------
Config.Plots = {
	Count = 8, -- set the place's Max Players to this number
	SlotsPerPlot = 12,
	DonutScale = 1.1,
	PodiumDonutScale = 1.7,
}

--------------------------------------------------------------------------------
-- Speed
-- The "Speed" stat grows forever (1, 1K, 5.3M, ...). It is turned into a real Roblox WalkSpeed with
-- a logarithmic curve so that big numbers stay playable:
--   WalkSpeed = BaseWalkSpeed + WalkPerDoubling * log2(1 + Speed / StatScale)
-- => every 10x more Speed gives roughly +10 WalkSpeed.
--------------------------------------------------------------------------------
Config.Speed = {
	BaseWalkSpeed = 16,
	WalkPerDoubling = 3,
	StatScale = 5,
	MaxWalkSpeed = 130,
	SlowModeWalkSpeed = 16,
}

-- Treadmill tiers. Tier 1 is free. "Rate" is Speed gained per second while running on it.
Config.Treadmill = {
	BeltSpeed = 13, -- how fast the belt stripes scroll (visual only)
	Tiers = {
		{ Name = "Rusty", Rate = 1, Cost = 0, Base = Color3.fromRGB(120, 110, 100), Accent = Color3.fromRGB(150, 80, 50), Material = Enum.Material.CorrodedMetal },
		{ Name = "Basic", Rate = 4, Cost = 1_500, Base = Color3.fromRGB(230, 230, 230), Accent = Color3.fromRGB(40, 40, 40), Material = Enum.Material.SmoothPlastic },
		{ Name = "Sporty", Rate = 28, Cost = 15_000, Base = Color3.fromRGB(220, 40, 40), Accent = Color3.fromRGB(255, 255, 255), Material = Enum.Material.SmoothPlastic },
		{ Name = "Pro", Rate = 200, Cost = 120_000, Base = Color3.fromRGB(40, 90, 200), Accent = Color3.fromRGB(0, 220, 255), Material = Enum.Material.Metal, Neon = true },
		{ Name = "Turbo", Rate = 1_400, Cost = 900_000, Base = Color3.fromRGB(255, 140, 0), Accent = Color3.fromRGB(255, 240, 0), Material = Enum.Material.Metal, Neon = true, Fire = true },
		{ Name = "Neon", Rate = 10_000, Cost = 6_000_000, Base = Color3.fromRGB(20, 20, 30), Accent = Color3.fromRGB(0, 255, 120), Material = Enum.Material.SmoothPlastic, Neon = true, Light = true },
		{ Name = "Diamond", Rate = 70_000, Cost = 40_000_000, Base = Color3.fromRGB(150, 230, 255), Accent = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Glass, Neon = true, Light = true, Sparkles = true },
		{ Name = "Plasma", Rate = 500_000, Cost = 260_000_000, Base = Color3.fromRGB(60, 10, 90), Accent = Color3.fromRGB(200, 60, 255), Material = Enum.Material.SmoothPlastic, Neon = true, Light = true, Sparkles = true },
		{ Name = "Quantum", Rate = 3_500_000, Cost = 1_700_000_000, Base = Color3.fromRGB(10, 10, 10), Accent = Color3.fromRGB(255, 0, 170), Material = Enum.Material.Glass, Neon = true, Light = true, Sparkles = true, Rainbow = true },
		{ Name = "Cosmic", Rate = 25_000_000, Cost = 11_000_000_000, Base = Color3.fromRGB(25, 0, 60), Accent = Color3.fromRGB(120, 200, 255), Material = Enum.Material.ForceField, Neon = true, Light = true, Sparkles = true, Rainbow = true, Halo = true },
	} :: { TreadmillTier },
}

-- "Speed Multiplier" upgrade bought with money in the shop. Multiplies treadmill gains.
Config.SpeedMultiplier = {
	PerLevel = 0.2, -- x1.0, x1.2, x1.4 ...
	BaseCost = 500,
	CostGrowth = 2.2, -- each level costs 2.2x the previous one
	MaxLevel = 50,
}

--------------------------------------------------------------------------------
-- Donut economy
--------------------------------------------------------------------------------
Config.DonutUpgrade = {
	IncomePerLevel = 0.25, -- +25% of base income per level (linear)
	CostSeconds = 30, -- level 1 -> 2 costs 30 seconds of the donut's base income
	CostGrowth = 1.5, -- each upgrade costs 1.5x the previous one
	MaxLevel = 40,
}

Config.SellSeconds = 20 -- selling a donut gives this many seconds of its current income

Config.Offline = {
	MaxHours = 12, -- cap so players can't skip the game by staying offline for a month
	Efficiency = 1.0, -- 1.0 = 100% of normal income while offline
	MinSecondsForPopup = 60,
}

Config.Spawns = {
	RespawnMin = 5,
	RespawnMax = 10,
	Lifetime = 240, -- an untouched donut re-rolls after this many seconds
	AnnounceRarity = 6, -- server-wide announcement when a donut of this rarity order or higher spawns (6 = Mythic)
}

--------------------------------------------------------------------------------
-- Robux game passes
--------------------------------------------------------------------------------
-- How money passes combine:
--   "Additive"       -> bonuses add up: 1.5x + 2x = 2.5x, all six = 20.5x   (recommended)
--   "Multiplicative" -> 1.5x * 2x = 3x, all six = 1800x (breaks the economy for buyers)
--   "Highest"        -> only your best pass counts (makes cheaper passes pointless once you own a big one)
Config.MoneyPassStacking = "Additive"

Config.GamePasses = {
	{ Key = "Money1_5", Name = "1.5x Money", Kind = "Money", Multiplier = 1.5, GamePassId = 0, SuggestedPrice = 49, Color = Color3.fromRGB(90, 200, 90) },
	{ Key = "Money2", Name = "2x Money", Kind = "Money", Multiplier = 2, GamePassId = 0, SuggestedPrice = 99, Color = Color3.fromRGB(60, 190, 80) },
	{ Key = "Money3", Name = "3x Money", Kind = "Money", Multiplier = 3, GamePassId = 0, SuggestedPrice = 199, Color = Color3.fromRGB(40, 170, 70) },
	{ Key = "Money4", Name = "4x Money", Kind = "Money", Multiplier = 4, GamePassId = 0, SuggestedPrice = 349, Color = Color3.fromRGB(20, 150, 90) },
	{ Key = "Money5", Name = "5x Money", Kind = "Money", Multiplier = 5, GamePassId = 0, SuggestedPrice = 499, Color = Color3.fromRGB(0, 140, 110) },
	{ Key = "Money10", Name = "10x Money", Kind = "Money", Multiplier = 10, GamePassId = 0, SuggestedPrice = 1499, Color = Color3.fromRGB(255, 200, 0) },
	{ Key = "Speed2", Name = "2x Speed", Kind = "Speed", Multiplier = 2, GamePassId = 0, SuggestedPrice = 149, Color = Color3.fromRGB(140, 60, 255) },
} :: { GamePass }

--------------------------------------------------------------------------------
-- Base skins (Robux game passes). "Classic" is free and always owned.
-- SkinRole colours: Floor / FloorAlt (checker) / Fence / Trim / Pedestal / Sign
--------------------------------------------------------------------------------
Config.Skins = {
	{
		Id = "Classic", Name = "Classic Farm", GamePassId = 0, SuggestedPrice = 0, Free = true,
		Floor = Color3.fromRGB(120, 205, 60), FloorAlt = Color3.fromRGB(106, 190, 50), FloorMaterial = Enum.Material.Plastic,
		Fence = Color3.fromRGB(140, 86, 48), FenceMaterial = Enum.Material.WoodPlanks,
		Trim = Color3.fromRGB(110, 65, 35), TrimMaterial = Enum.Material.Wood,
		Pedestal = Color3.fromRGB(200, 200, 200), PedestalMaterial = Enum.Material.SmoothPlastic,
	},
	{
		Id = "Candy", Name = "Candy Land", GamePassId = 0, SuggestedPrice = 99,
		Floor = Color3.fromRGB(255, 180, 220), FloorAlt = Color3.fromRGB(255, 210, 235), FloorMaterial = Enum.Material.SmoothPlastic,
		Fence = Color3.fromRGB(255, 255, 255), FenceMaterial = Enum.Material.SmoothPlastic,
		Trim = Color3.fromRGB(255, 60, 90), TrimMaterial = Enum.Material.SmoothPlastic,
		Pedestal = Color3.fromRGB(120, 220, 255), PedestalMaterial = Enum.Material.SmoothPlastic,
		Effect = "Sprinkles",
	},
	{
		Id = "Frozen", Name = "Frozen Fortress", GamePassId = 0, SuggestedPrice = 149,
		Floor = Color3.fromRGB(200, 235, 255), FloorAlt = Color3.fromRGB(180, 220, 250), FloorMaterial = Enum.Material.Ice,
		Fence = Color3.fromRGB(150, 210, 255), FenceMaterial = Enum.Material.Glacier,
		Trim = Color3.fromRGB(90, 200, 255), TrimMaterial = Enum.Material.Neon,
		Pedestal = Color3.fromRGB(230, 250, 255), PedestalMaterial = Enum.Material.Ice,
		Effect = "Snow",
	},
	{
		Id = "Neon", Name = "Neon Nights", GamePassId = 0, SuggestedPrice = 199,
		Floor = Color3.fromRGB(25, 20, 40), FloorAlt = Color3.fromRGB(35, 30, 55), FloorMaterial = Enum.Material.SmoothPlastic,
		Fence = Color3.fromRGB(30, 30, 40), FenceMaterial = Enum.Material.Metal,
		Trim = Color3.fromRGB(0, 255, 230), TrimMaterial = Enum.Material.Neon,
		Pedestal = Color3.fromRGB(255, 0, 200), PedestalMaterial = Enum.Material.Neon,
		Effect = "Glow",
	},
	{
		Id = "Lava", Name = "Lava Lair", GamePassId = 0, SuggestedPrice = 249,
		Floor = Color3.fromRGB(40, 35, 35), FloorAlt = Color3.fromRGB(55, 45, 40), FloorMaterial = Enum.Material.Basalt,
		Fence = Color3.fromRGB(60, 50, 50), FenceMaterial = Enum.Material.Basalt,
		Trim = Color3.fromRGB(255, 90, 0), TrimMaterial = Enum.Material.Neon,
		Pedestal = Color3.fromRGB(255, 140, 20), PedestalMaterial = Enum.Material.CrackedLava,
		Effect = "Fire",
	},
	{
		Id = "Gold", Name = "Golden Palace", GamePassId = 0, SuggestedPrice = 299,
		Floor = Color3.fromRGB(255, 215, 90), FloorAlt = Color3.fromRGB(240, 195, 70), FloorMaterial = Enum.Material.Foil,
		Fence = Color3.fromRGB(255, 200, 40), FenceMaterial = Enum.Material.Foil,
		Trim = Color3.fromRGB(255, 255, 255), TrimMaterial = Enum.Material.Marble,
		Pedestal = Color3.fromRGB(255, 230, 120), PedestalMaterial = Enum.Material.Foil,
		Effect = "Sparkle",
	},
	{
		Id = "Galaxy", Name = "Galaxy Vault", GamePassId = 0, SuggestedPrice = 399,
		Floor = Color3.fromRGB(20, 10, 45), FloorAlt = Color3.fromRGB(35, 15, 70), FloorMaterial = Enum.Material.SmoothPlastic,
		Fence = Color3.fromRGB(60, 20, 120), FenceMaterial = Enum.Material.Glass,
		Trim = Color3.fromRGB(150, 110, 255), TrimMaterial = Enum.Material.Neon,
		Pedestal = Color3.fromRGB(100, 200, 255), PedestalMaterial = Enum.Material.ForceField,
		Effect = "Stars",
	},
	{
		Id = "Rainbow", Name = "Rainbow Dream", GamePassId = 0, SuggestedPrice = 499,
		Floor = Color3.fromRGB(255, 255, 255), FloorAlt = Color3.fromRGB(240, 240, 255), FloorMaterial = Enum.Material.SmoothPlastic,
		Fence = Color3.fromRGB(255, 255, 255), FenceMaterial = Enum.Material.SmoothPlastic,
		Trim = Color3.fromRGB(255, 0, 0), TrimMaterial = Enum.Material.Neon,
		Pedestal = Color3.fromRGB(255, 255, 255), PedestalMaterial = Enum.Material.Neon,
		Effect = "Rainbow",
	},
} :: { Skin }

--------------------------------------------------------------------------------
-- Leaderboards (OrderedDataStores)
--------------------------------------------------------------------------------
Config.Leaderboards = {
	Size = 500, -- top N (fetched in pages of 100)
	RefreshInterval = 90, -- seconds between refreshing ONE board (boards rotate, so each board refreshes every 4 * 90s)
	WriteInterval = 120, -- seconds between writing a player's scores
	StorePrefix = "LB_v1_",
	Boards = {
		{ Id = "Money", Title = "TOP MONEY", Subtitle = "Total money earned", Color = Color3.fromRGB(60, 200, 80) },
		{ Id = "Speed", Title = "TOP SPEED", Subtitle = "Highest speed", Color = Color3.fromRGB(140, 70, 255) },
		{ Id = "Rarest", Title = "RAREST DONUT", Subtitle = "Rarest donut ever stolen", Color = Color3.fromRGB(255, 170, 0) },
		{ Id = "Time", Title = "TIME PLAYED", Subtitle = "Total time in game", Color = Color3.fromRGB(0, 170, 255) },
	},
}

--------------------------------------------------------------------------------
-- Background music (soundtrack). Plays tracks in order, looping the playlist.
-- Roblox can't play YouTube links: each song must be a Roblox audio asset. Get IDs by
-- uploading audio you own (Creator Dashboard > Development Items > Audio) or from licensed
-- music in the Creator Store (Toolbox > Audio). Paste the number from "rbxassetid://NUMBER".
--------------------------------------------------------------------------------
Config.Music = {
	DefaultVolume = 0.5, -- 0 to 1 (players change it in Settings)
	Tracks = {
		-- { Name = "Donut Theme", Id = 1234567890 },
	} :: { { Name: string, Id: number } },
}

--------------------------------------------------------------------------------
-- Saving
--------------------------------------------------------------------------------
Config.Data = {
	StoreName = "StealADonut_PlayerData_v1",
	AutosaveInterval = 90,
	SessionLockSeconds = 180, -- a lock older than this is treated as a crashed server and taken over
}

--------------------------------------------------------------------------------
-- Studio testing helpers (never active in live servers)
--------------------------------------------------------------------------------
Config.Debug = {
	StudioFreePurchases = true, -- in Studio, "buying" a game pass grants it for that test session only
	StudioStartMoney = 0, -- give yourself money in Studio to test late-game content
	StudioStartSpeed = 0,
}

return Config
