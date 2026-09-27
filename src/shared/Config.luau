--[[
	Config
	======
	Every tunable number in the game lives here (plus Areas.luau / Donuts.luau / Rarities.luau).
	You should be able to rebalance the whole game without touching any other script.

	>>> BEFORE PUBLISHING <<<
	1. Create the Game Passes on the Creator Dashboard and paste their IDs into
	   Config.GamePasses[...].GamePassId.
	   A GamePassId of 0 means "not set up yet" and the item shows as "Coming Soon" in live servers.
	2. In Studio: Game Settings > Security > "Enable Studio Access to API Services" so DataStores work
	   while testing.
]]

export type TreadmillTier = {
	Name: string,
	Rate: number,
	Cost: number,
	RequiredRebirths: number,
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
	SpeedCost: number, -- paid with your Speed stat (0 = free)
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

	-- Every player has their OWN guards: you only ever see (and get chased by) yours, so other
	-- players can't wake him up for you. When a chase ends he poofs back to his blanket.
	Scale = 1.7, -- model scale (1 = normal player size)
	CatchRadius = 5.5, -- studs (horizontal) between guard and player that counts as "caught"
	GiveUpDelay = 1.2, -- seconds he stands there fuming after you reach safety, before teleporting home
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
	StartSlots = 8, -- donut stands you start with
	SlotsPerPlot = 24, -- stands a fully expanded base has
	-- Each expansion adds one row of 4 stands. Bought with money in the Shop, kept through rebirths.
	ExpansionSlots = 4,
	ExpansionCosts = { 50_000, 250_000_000, 1_000_000_000_000, 5_000_000_000_000_000 },
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
	MaxWalkSpeed = 180, -- before the world bonus (Areas.Worlds[].WalkMultiplier: later worlds are faster)
	SlowModeWalkSpeed = 16,
}

-- Treadmill tiers. Tier 1 is free. "Rate" is Speed gained per second while running on it.
-- The last tiers need rebirths (they only make sense in the later worlds).
local rgb = Color3.fromRGB
Config.Treadmill = {
	BeltSpeed = 13, -- how fast the belt stripes scroll (visual only)
	Tiers = {
		{ Name = "Rusty", Rate = 1, Cost = 0, RequiredRebirths = 0, Base = rgb(120, 110, 100), Accent = rgb(150, 80, 50), Material = Enum.Material.CorrodedMetal },
		{ Name = "Basic", Rate = 3, Cost = 1_500, RequiredRebirths = 0, Base = rgb(230, 230, 230), Accent = rgb(40, 40, 40), Material = Enum.Material.SmoothPlastic },
		{ Name = "Sporty", Rate = 8, Cost = 20_000, RequiredRebirths = 0, Base = rgb(220, 40, 40), Accent = rgb(255, 255, 255), Material = Enum.Material.SmoothPlastic },
		{ Name = "Pro", Rate = 25, Cost = 150_000, RequiredRebirths = 0, Base = rgb(40, 90, 200), Accent = rgb(0, 220, 255), Material = Enum.Material.Metal, Neon = true },
		{ Name = "Turbo", Rate = 80, Cost = 1_200_000, RequiredRebirths = 0, Base = rgb(255, 140, 0), Accent = rgb(255, 240, 0), Material = Enum.Material.Metal, Neon = true, Fire = true },
		{ Name = "Neon", Rate = 300, Cost = 9_000_000, RequiredRebirths = 0, Base = rgb(20, 20, 30), Accent = rgb(0, 255, 120), Material = Enum.Material.SmoothPlastic, Neon = true, Light = true },
		{ Name = "Diamond", Rate = 1_200, Cost = 70_000_000, RequiredRebirths = 0, Base = rgb(150, 230, 255), Accent = rgb(255, 255, 255), Material = Enum.Material.Glass, Neon = true, Light = true, Sparkles = true },
		{ Name = "Plasma", Rate = 5_000, Cost = 600_000_000, RequiredRebirths = 0, Base = rgb(60, 10, 90), Accent = rgb(200, 60, 255), Material = Enum.Material.SmoothPlastic, Neon = true, Light = true, Sparkles = true },
		{ Name = "Quantum", Rate = 20_000, Cost = 5_000_000_000, RequiredRebirths = 0, Base = rgb(10, 10, 10), Accent = rgb(255, 0, 170), Material = Enum.Material.Glass, Neon = true, Light = true, Sparkles = true, Rainbow = true },
		{ Name = "Cosmic", Rate = 80_000, Cost = 40_000_000_000, RequiredRebirths = 0, Base = rgb(40, 20, 90), Accent = rgb(120, 200, 255), Material = Enum.Material.Glass, Neon = true, Light = true, Sparkles = true, Rainbow = true, Halo = true },
		{ Name = "Tropical", Rate = 400_000, Cost = 400_000_000_000, RequiredRebirths = 1, Base = rgb(255, 225, 150), Accent = rgb(0, 210, 200), Material = Enum.Material.SmoothPlastic, Neon = true, Light = true, Sparkles = true },
		{ Name = "Tsunami", Rate = 3_000_000, Cost = 30_000_000_000_000, RequiredRebirths = 1, Base = rgb(20, 70, 150), Accent = rgb(120, 230, 255), Material = Enum.Material.Glass, Neon = true, Light = true, Sparkles = true, Halo = true },
		{ Name = "Magma", Rate = 25_000_000, Cost = 1_500_000_000_000_000, RequiredRebirths = 1, Base = rgb(50, 30, 30), Accent = rgb(255, 110, 0), Material = Enum.Material.Basalt, Neon = true, Light = true, Fire = true, Halo = true },
		{ Name = "Dream", Rate = 200_000_000, Cost = 100_000_000_000_000_000, RequiredRebirths = 2, Base = rgb(245, 235, 255), Accent = rgb(255, 150, 230), Material = Enum.Material.SmoothPlastic, Neon = true, Light = true, Sparkles = true, Rainbow = true, Halo = true },
		{ Name = "Infinity", Rate = 2_000_000_000, Cost = 4_000_000_000_000_000_000, RequiredRebirths = 2, Base = rgb(255, 215, 90), Accent = rgb(255, 255, 255), Material = Enum.Material.Foil, Neon = true, Light = true, Sparkles = true, Rainbow = true, Halo = true },
	} :: { TreadmillTier },
}

-- "Speed Multiplier" upgrade bought with money in the Shop. Every level MULTIPLIES your treadmill
-- gains by PerLevel (x1.25, x1.56, x1.95, ... x35 at level 16), so it stays worth buying all game.
Config.SpeedMultiplier = {
	PerLevel = 1.25,
	BaseCost = 1_000,
	CostGrowth = 3, -- each level costs 3x the previous one
	MaxLevel = 40,
}

--------------------------------------------------------------------------------
-- Donut economy
--------------------------------------------------------------------------------
Config.DonutUpgrade = {
	IncomePerLevel = 0.25, -- +25% of the donut's level-1 income per level
	CostSeconds = 20, -- level 1 -> 2 costs 20 seconds of the donut's level-1 income (pays for itself in ~80s)
	CostGrowth = 1.3, -- each upgrade costs 1.3x the previous one
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
	AnnounceRarity = 7, -- server-wide announcement when a donut of this rarity order or higher spawns (7 = Secret only)
}

--------------------------------------------------------------------------------
-- Rebirths: reset your Money, Speed, treadmill, Speed Multiplier and base donuts for a permanent
-- boost to money AND speed gains, and to unlock the next world (Areas.Worlds[].RequiredRebirths).
-- You keep: game passes, items, skins, base expansions, the Index and its rewards.
--------------------------------------------------------------------------------
Config.Rebirth = {
	MoneyBonus = 1, -- +100% money per rebirth (x2, x3, x4 ...)
	SpeedBonus = 1, -- +100% treadmill speed per rebirth
	-- Requirements for rebirth 1, 2, 3 ... (Speed stat you must have reached + money it costs)
	Levels = {
		{ Speed = 50_000_000, Cost = 100_000_000_000 }, -- end of World 1 -> unlocks Glaze Islands
		{ Speed = 400_000_000_000, Cost = 5_000_000_000_000_000 }, -- end of World 2 -> unlocks Dream Dimension
		{ Speed = 3_000_000_000_000_000, Cost = 5e19 }, -- end of World 3
		{ Speed = 2e16, Cost = 5e20 },
		{ Speed = 1.5e17, Cost = 5e21 },
		{ Speed = 1e18, Cost = 5e22 },
		{ Speed = 8e18, Cost = 5e23 },
		{ Speed = 6e19, Cost = 5e24 },
		{ Speed = 5e20, Cost = 5e25 },
		{ Speed = 4e21, Cost = 5e26 },
	},
}

--------------------------------------------------------------------------------
-- Donut Index rewards (claimed in the Index). See Rarities.List[].IndexReward.
--------------------------------------------------------------------------------
Config.Index = {
	MaxSpeedBonus = 10, -- cap on the total treadmill bonus from the Index (10 = +1000%)
}

--------------------------------------------------------------------------------
-- Area events (see Events.luau): every so often one area gets weather + boosted mutation luck.
--------------------------------------------------------------------------------
Config.Events = {
	Enabled = true,
	FirstDelay = 90, -- seconds after the server starts
	Interval = { 200, 320 }, -- random gap between events (seconds)
	Duration = 100,
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
	-- Teleport menu: jump to any world you've unlocked, or the start of any area you're fast enough for.
	{ Key = "Teleporter", Name = "Teleporter", Kind = "Teleporter", Multiplier = 1, GamePassId = 0, SuggestedPrice = 199, Color = Color3.fromRGB(0, 200, 255) },
} :: { GamePass }

--------------------------------------------------------------------------------
-- Base skins, bought with your SPEED stat (spending speed makes you slower until you train it back).
-- "Classic" is free and always owned. Skins are kept forever (also through rebirths).
-- SkinRole colours: Floor / FloorAlt (checker) / Fence / Trim / Pedestal / Sign
--------------------------------------------------------------------------------
Config.Skins = {
	{
		Id = "Classic", Name = "Classic Farm", SpeedCost = 0,
		Floor = Color3.fromRGB(120, 205, 60), FloorAlt = Color3.fromRGB(106, 190, 50), FloorMaterial = Enum.Material.Plastic,
		Fence = Color3.fromRGB(140, 86, 48), FenceMaterial = Enum.Material.WoodPlanks,
		Trim = Color3.fromRGB(110, 65, 35), TrimMaterial = Enum.Material.Wood,
		Pedestal = Color3.fromRGB(200, 200, 200), PedestalMaterial = Enum.Material.SmoothPlastic,
	},
	{
		Id = "Candy", Name = "Candy Land", SpeedCost = 5_000,
		Floor = Color3.fromRGB(255, 180, 220), FloorAlt = Color3.fromRGB(255, 210, 235), FloorMaterial = Enum.Material.SmoothPlastic,
		Fence = Color3.fromRGB(255, 255, 255), FenceMaterial = Enum.Material.SmoothPlastic,
		Trim = Color3.fromRGB(255, 60, 90), TrimMaterial = Enum.Material.SmoothPlastic,
		Pedestal = Color3.fromRGB(120, 220, 255), PedestalMaterial = Enum.Material.SmoothPlastic,
		Effect = "Sprinkles",
	},
	{
		Id = "Frozen", Name = "Frozen Fortress", SpeedCost = 100_000,
		Floor = Color3.fromRGB(200, 235, 255), FloorAlt = Color3.fromRGB(180, 220, 250), FloorMaterial = Enum.Material.Ice,
		Fence = Color3.fromRGB(150, 210, 255), FenceMaterial = Enum.Material.Glacier,
		Trim = Color3.fromRGB(90, 200, 255), TrimMaterial = Enum.Material.Neon,
		Pedestal = Color3.fromRGB(230, 250, 255), PedestalMaterial = Enum.Material.Ice,
		Effect = "Snow",
	},
	{
		Id = "Neon", Name = "Neon Nights", SpeedCost = 2_000_000,
		Floor = Color3.fromRGB(25, 20, 40), FloorAlt = Color3.fromRGB(35, 30, 55), FloorMaterial = Enum.Material.SmoothPlastic,
		Fence = Color3.fromRGB(30, 30, 40), FenceMaterial = Enum.Material.Metal,
		Trim = Color3.fromRGB(0, 255, 230), TrimMaterial = Enum.Material.Neon,
		Pedestal = Color3.fromRGB(255, 0, 200), PedestalMaterial = Enum.Material.Neon,
		Effect = "Glow",
	},
	{
		Id = "Lava", Name = "Lava Lair", SpeedCost = 50_000_000,
		Floor = Color3.fromRGB(40, 35, 35), FloorAlt = Color3.fromRGB(55, 45, 40), FloorMaterial = Enum.Material.Basalt,
		Fence = Color3.fromRGB(60, 50, 50), FenceMaterial = Enum.Material.Basalt,
		Trim = Color3.fromRGB(255, 90, 0), TrimMaterial = Enum.Material.Neon,
		Pedestal = Color3.fromRGB(255, 140, 20), PedestalMaterial = Enum.Material.CrackedLava,
		Effect = "Fire",
	},
	{
		Id = "Gold", Name = "Golden Palace", SpeedCost = 1_000_000_000,
		Floor = Color3.fromRGB(255, 215, 90), FloorAlt = Color3.fromRGB(240, 195, 70), FloorMaterial = Enum.Material.Foil,
		Fence = Color3.fromRGB(255, 200, 40), FenceMaterial = Enum.Material.Foil,
		Trim = Color3.fromRGB(255, 255, 255), TrimMaterial = Enum.Material.Marble,
		Pedestal = Color3.fromRGB(255, 230, 120), PedestalMaterial = Enum.Material.Foil,
		Effect = "Sparkle",
	},
	{
		Id = "Galaxy", Name = "Galaxy Vault", SpeedCost = 50_000_000_000,
		Floor = Color3.fromRGB(20, 10, 45), FloorAlt = Color3.fromRGB(35, 15, 70), FloorMaterial = Enum.Material.SmoothPlastic,
		Fence = Color3.fromRGB(60, 20, 120), FenceMaterial = Enum.Material.Glass,
		Trim = Color3.fromRGB(150, 110, 255), TrimMaterial = Enum.Material.Neon,
		Pedestal = Color3.fromRGB(100, 200, 255), PedestalMaterial = Enum.Material.ForceField,
		Effect = "Stars",
	},
	{
		Id = "Rainbow", Name = "Rainbow Dream", SpeedCost = 5_000_000_000_000,
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
	-- Boards whose score format changed get their own fresh store (old scores would sort wrongly).
	StoreVersions = { Rarest = "LB_v2_", Speed = "LB_v2_" },
	Boards = {
		{ Id = "Money", Title = "TOP MONEY", Subtitle = "Total money earned", Color = Color3.fromRGB(60, 200, 80) },
		{ Id = "Speed", Title = "TOP SPEED", Subtitle = "Highest speed ever reached", Color = Color3.fromRGB(140, 70, 255) },
		{ Id = "Rarest", Title = "RAREST DONUT", Subtitle = "Rarest donut ever stolen", Color = Color3.fromRGB(255, 170, 0) },
		{ Id = "Time", Title = "TIME PLAYED", Subtitle = "Total time in game", Color = Color3.fromRGB(0, 170, 255) },
	},
}

--------------------------------------------------------------------------------
-- Stealing from other players' bases ("raids")
-- Hold the Steal prompt on someone else's donut while they're OUTSIDE their base.
-- Hitting the thief (weapons / traps) before they get home returns the donut to its owner.
--------------------------------------------------------------------------------
Config.Raid = {
	Enabled = true,
	HoldSeconds = 15,
	WarnOwner = true, -- tell the owner the moment someone starts stealing
}

--------------------------------------------------------------------------------
-- Item shop (bought with money, kept forever). Items appear in your backpack (hotbar).
--   Weapon: click to swing; flings the players in front of you (and makes thieves drop donuts)
--   Trap:   click inside your base to place it at your feet; flings intruders who touch it
--   Lock:   click to seal your base entrance with a laser for Duration seconds (no raids)
--------------------------------------------------------------------------------
export type Item = {
	Id: string,
	Name: string,
	Kind: string,
	Cost: number,
	Description: string,
	Icon: string,
	Color: Color3,
	Range: number?,
	Power: number?,
	Cooldown: number?,
	MaxPlaced: number?,
	Duration: number?,
}

Config.Items = {
	{ Id = "Slap", Name = "Slap Hand", Kind = "Weapon", Cost = 5_000, Icon = "🖐️", Color = Color3.fromRGB(255, 200, 60), Range = 9, Power = 70, Cooldown = 2.5, Description = "A big slappy glove. Knocks thieves away." },
	{ Id = "Bat", Name = "Donut Bat", Kind = "Weapon", Cost = 250_000, Icon = "🏏", Color = Color3.fromRGB(190, 120, 60), Range = 11, Power = 105, Cooldown = 2, Description = "Longer reach, bigger fling." },
	{ Id = "Hammer", Name = "Mega Hammer", Kind = "Weapon", Cost = 50_000_000, Icon = "🔨", Color = Color3.fromRGB(150, 90, 255), Range = 14, Power = 160, Cooldown = 1.6, Description = "Sends thieves into orbit." },
	{ Id = "Banana", Name = "Banana Peel", Kind = "Trap", Cost = 20_000, Icon = "🍌", Color = Color3.fromRGB(255, 230, 60), Power = 60, MaxPlaced = 3, Description = "Place up to 3 in your base. Intruders slip and fly." },
	{ Id = "Spring", Name = "Launch Pad", Kind = "Trap", Cost = 2_000_000, Icon = "🚀", Color = Color3.fromRGB(80, 200, 255), Power = 150, MaxPlaced = 2, Description = "Place up to 2. Launches intruders sky-high." },
	{ Id = "Lock", Name = "Base Lock", Kind = "Lock", Cost = 100_000, Icon = "🔒", Color = Color3.fromRGB(255, 70, 70), Duration = 30, Cooldown = 90, Description = "Laser door for 30s: blocks raids, flings intruders." },
} :: { Item }

--------------------------------------------------------------------------------
-- Background music (soundtrack). Plays tracks in order, looping the playlist.
-- Roblox can't play YouTube links: each song must be a Roblox audio asset. Get IDs by
-- uploading audio you own (Creator Dashboard > Development Items > Audio) or from licensed
-- music in the Creator Store (Toolbox > Audio). Paste the number from "rbxassetid://NUMBER".
--------------------------------------------------------------------------------
-- The player skips songs that fail to load and prints which ID failed to the Output window.
Config.Music = {
	DefaultVolume = 0.35, -- 0 to 1 (players change it in Settings)
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
