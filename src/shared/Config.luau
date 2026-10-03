--[[
	Config
	======
	Every tunable number in the game lives here (plus Areas.luau / Donuts.luau / Rarities.luau).
	You should be able to rebalance the whole game without touching any other script.

	>>> BEFORE PUBLISHING <<<
	1. Game Passes: their IDs are in Config.GamePasses[...].GamePassId (from the Creator Dashboard).
	   A GamePassId of 0 means "not set up yet" and the item shows as "Coming Soon" in live servers.
	2. Developer Products: Luck Event, one per crate, one per tip. IDs are in
	   Config.LuckEvent.DeveloperProductId, Config.Crates.Products[...] and
	   Config.Donations.Products[...].DeveloperProductId. Crates are "paid random items": say so in
	   the Maturity & Compliance Questionnaire on the Creator Dashboard.
	3. The admin code works for EVERYONE who types it (Config.Admin.AllowAnyone). Luck Events and
	   crates from the panel only work for the owner / Config.Admin.AllowedUserIds.
	4. In Studio: Game Settings > Security > "Enable Studio Access to API Services" so DataStores work
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
	OwnerOnly: boolean?, -- only the game's owner can use it (it's hidden from everyone else's Shop)
}

local Config = {}

Config.GameName = "Steal a Donut"

--------------------------------------------------------------------------------
-- Guard (the sleeping donut-lover who guards each area)
--------------------------------------------------------------------------------
Config.Guard = {
	-- Shown above every guard and in all UI text ("Domer is chasing you!"). Changing this one string
	-- renames the guard everywhere.
	Name = "Domer",

	-- Every player has their OWN guards: you only ever see (and get chased by) yours, so other
	-- players can't wake him up for you. When a chase ends he poofs back to his blanket.
	Scale = 4, -- model scale (1 = normal player size). He's HUGE: about 20 studs tall.
	-- His walk and idle animations (Roblox's R6 ones). Clients preload them when the game starts, so
	-- he doesn't stand frozen for a moment the first time he wakes up.
	WalkAnimation = "rbxassetid://180426354",
	IdleAnimation = "rbxassetid://180435571",
	CatchRadius = 10, -- studs (horizontal) between his centre and yours that counts as "caught"
	-- Every Domer runs this much faster than the area's base guard speed (1.075 = +7.5%).
	SpeedMultiplier = 1.075,
	-- Lag compensation: the catch is judged against where the guard was on YOUR screen (the server
	-- rewinds him by your ping plus Roblox's interpolation delay), so a fast chase over a laggy
	-- connection can't catch you while he still looks 40 studs away. Capped so lag can't be abused.
	InterpolationDelay = 0.1,
	MaxRewind = 0.35,
	GiveUpDelay = 1.2, -- seconds he stands there fuming after you reach safety, before teleporting home
	StunTime = 2.3, -- seconds after being caught (and flung) before being sent home

	-- Footsteps + screen shake while he's close (client side, only for your own guard).
	FootstepRange = 110, -- studs: you start hearing him
	ShakeRange = 45, -- studs: the camera starts shaking
	MaxShake = 0.9, -- strongest shake (studs of camera offset) when he's right behind you

	-- Random line he yells when he wakes up.
	WakeShouts = { "D'OH!", "HEY! MY DONUT!", "WHY YOU LITTLE...!", "MMM... DONUT THIEF!", "COME BACK HERE!" },
	CatchShouts = { "WOO-HOO!", "GOTCHA!", "MINE! ALL MINE!", "MMM... DONUT..." },
}

--------------------------------------------------------------------------------
-- Map layout (studs). Floor top is at Y = 0.
--------------------------------------------------------------------------------
Config.Map = {
	LaneHalfWidth = 70, -- the lane runs along +Z, from X = -70 to X = 70
	AreaLength = 240, -- each area is this long in Z (must be a multiple of TileSize)
	TileSize = 20,
	LaneWallHeight = 60,

	SafeZoneZ = 0, -- everything with Z < SafeZoneZ is the safe hub (bases, shop, leaderboards)
	HubHalfWidth = 230,
	HubDepth = 400, -- deep enough for 4 rows of bases Layout.PlotRowSpacing apart (every world's hub)
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
	-- Upper floors: once all SlotsPerPlot stands are unlocked, buy a second floor, then a third,
	-- each with Slots more stands (same layout, Height studs up - above even a Giant donut). Lift
	-- pads at the front of the base take you between floors. Kept through rebirths, like expansions.
	UpperFloors = {
		Costs = {
			1e19, -- 2nd floor: $10Qn, 2000x the last expansion (bots get it around Rebirth 2)
			1e23, -- 3rd floor: $100Sx, 10,000x the 2nd floor (around Rebirth 3)
		},
		Slots = 24, -- per floor (at most SlotsPerPlot)
		Height = 26,
	},
	-- Every base is a building: glass windows from the top of its low walls up to a roof above its
	-- top floor, so you can see the donuts inside. The front stays open (that's the way in), and a
	-- thief can only get in there, not over the sides.
	-- Enclosed = false: no glass walls (low walls you can hop over from the side, and no roof).
	Building = {
		Enclosed = true,
		GlassColor = Color3.fromRGB(170, 225, 255),
		GlassTransparency = 0.55,
		EntranceHeight = 12, -- the open gap at the front of the ground floor (studs)
	},
	DonutScale = 1.1,
	PodiumDonutScale = 1.7,
}

--------------------------------------------------------------------------------
-- Speed
-- The "Speed" stat turns into a real Roblox WalkSpeed in a straight line: every SpeedPerWalk Speed
-- is +1 WalkSpeed, so twice the training really is twice the extra speed.
--   WalkSpeed = BaseWalkSpeed + Speed / SpeedPerWalk      (Speed 0 = 24, 90 = 33, 810 = 105)
-- Each area needs 90 more Speed than the one before (Areas.luau), so every area is +9 WalkSpeed.
-- There's no maximum: the more you train, the faster you run. (Around WalkSpeed 1000+ Roblox physics
-- can let a player slip through a thin wall; the speed slider on the HUD lets players slow down.)
--------------------------------------------------------------------------------
Config.Speed = {
	BaseWalkSpeed = 24,
	-- Domer's speeds are worked out from this instead (Economy.GuardWalkSpeed). It goes up with
	-- BaseWalkSpeed (players start 3 ahead of it), so the early Domers keep pace (Area 1: ~27.9).
	GuardBaseWalkSpeed = 21,
	SpeedPerWalk = 10,
}

-- Treadmill tiers. Tier 1 is free. "Rate" is Speed gained per second while running on it.
-- The last tiers need rebirths (they only make sense in the later worlds).
-- Balance: a simulated bot that plays well (no passes, pets or Index bonus) reaches Area 2 in ~7 min,
-- Area 10 in ~1.9 h and rebirths at ~37 min, ~2 h, ~4.6 h and ~9.2 h (Config.Rebirth). Real players
-- take longer (breaks, getting caught).
local rgb = Color3.fromRGB
Config.Treadmill = {
	BeltSpeed = 13, -- how fast the belt stripes scroll (visual only)
	-- Head Start: treadmill gains are x Multiplier at Speed 0, fading evenly to x1 at UntilSpeed
	-- (Area 6). Makes the first areas quick for new players, and the climb back after each rebirth.
	-- (Simulated good player: Area 2 in ~7 min instead of ~16, Area 5 in ~29 min instead of ~54.)
	HeadStart = { Multiplier = 4, UntilSpeed = 450 },
	Tiers = {
		{ Name = "Rusty", Rate = 0.1, Cost = 0, RequiredRebirths = 0, Base = rgb(120, 110, 100), Accent = rgb(150, 80, 50), Material = Enum.Material.CorrodedMetal },
		{ Name = "Basic", Rate = 0.115, Cost = 1_500, RequiredRebirths = 0, Base = rgb(230, 230, 230), Accent = rgb(40, 40, 40), Material = Enum.Material.SmoothPlastic },
		{ Name = "Sporty", Rate = 0.125, Cost = 20_000, RequiredRebirths = 0, Base = rgb(220, 40, 40), Accent = rgb(255, 255, 255), Material = Enum.Material.SmoothPlastic },
		{ Name = "Pro", Rate = 0.14, Cost = 150_000, RequiredRebirths = 0, Base = rgb(40, 90, 200), Accent = rgb(0, 220, 255), Material = Enum.Material.Metal, Neon = true },
		{ Name = "Turbo", Rate = 0.155, Cost = 1_200_000, RequiredRebirths = 0, Base = rgb(255, 140, 0), Accent = rgb(255, 240, 0), Material = Enum.Material.Metal, Neon = true, Fire = true },
		{ Name = "Neon", Rate = 0.17, Cost = 9_000_000, RequiredRebirths = 0, Base = rgb(20, 20, 30), Accent = rgb(0, 255, 120), Material = Enum.Material.SmoothPlastic, Neon = true, Light = true },
		{ Name = "Diamond", Rate = 0.185, Cost = 70_000_000, RequiredRebirths = 0, Base = rgb(150, 230, 255), Accent = rgb(255, 255, 255), Material = Enum.Material.Glass, Neon = true, Light = true, Sparkles = true },
		{ Name = "Plasma", Rate = 0.2, Cost = 600_000_000, RequiredRebirths = 0, Base = rgb(60, 10, 90), Accent = rgb(200, 60, 255), Material = Enum.Material.SmoothPlastic, Neon = true, Light = true, Sparkles = true },
		{ Name = "Quantum", Rate = 0.225, Cost = 5_000_000_000, RequiredRebirths = 0, Base = rgb(10, 10, 10), Accent = rgb(255, 0, 170), Material = Enum.Material.Glass, Neon = true, Light = true, Sparkles = true, Rainbow = true },
		{ Name = "Cosmic", Rate = 0.245, Cost = 40_000_000_000, RequiredRebirths = 0, Base = rgb(40, 20, 90), Accent = rgb(120, 200, 255), Material = Enum.Material.Glass, Neon = true, Light = true, Sparkles = true, Rainbow = true, Halo = true },
		{ Name = "Tropical", Rate = 0.28, Cost = 400_000_000_000, RequiredRebirths = 1, Base = rgb(255, 225, 150), Accent = rgb(0, 210, 200), Material = Enum.Material.SmoothPlastic, Neon = true, Light = true, Sparkles = true },
		{ Name = "Tsunami", Rate = 0.315, Cost = 30_000_000_000_000, RequiredRebirths = 1, Base = rgb(20, 70, 150), Accent = rgb(120, 230, 255), Material = Enum.Material.Glass, Neon = true, Light = true, Sparkles = true, Halo = true },
		{ Name = "Magma", Rate = 0.35, Cost = 1_500_000_000_000_000, RequiredRebirths = 1, Base = rgb(50, 30, 30), Accent = rgb(255, 110, 0), Material = Enum.Material.Basalt, Neon = true, Light = true, Fire = true, Halo = true },
		{ Name = "Dream", Rate = 0.4, Cost = 100_000_000_000_000_000, RequiredRebirths = 2, Base = rgb(245, 235, 255), Accent = rgb(255, 150, 230), Material = Enum.Material.SmoothPlastic, Neon = true, Light = true, Sparkles = true, Rainbow = true, Halo = true },
		{ Name = "Infinity", Rate = 0.455, Cost = 4_000_000_000_000_000_000, RequiredRebirths = 2, Base = rgb(255, 215, 90), Accent = rgb(255, 255, 255), Material = Enum.Material.Foil, Neon = true, Light = true, Sparkles = true, Rainbow = true, Halo = true },
		{ Name = "Cyber", Rate = 0.52, Cost = 2e23, RequiredRebirths = 3, Base = rgb(15, 15, 25), Accent = rgb(255, 40, 200), Material = Enum.Material.Glass, Neon = true, Light = true, Sparkles = true, Halo = true },
		{ Name = "Singularity", Rate = 0.6, Cost = 1e26, RequiredRebirths = 3, Base = rgb(5, 5, 10), Accent = rgb(120, 170, 255), Material = Enum.Material.Glass, Neon = true, Light = true, Sparkles = true, Rainbow = true, Halo = true },
	} :: { TreadmillTier },
}

-- "Speed Multiplier" upgrade bought with money in the Shop. Every level adds PerLevel to your
-- treadmill gains (+5%, +10%, ... +100% at level 20). It adds instead of multiplying: with a
-- straight-line WalkSpeed, a multiplying upgrade would make speed explode late in the game.
Config.SpeedMultiplier = {
	PerLevel = 0.05,
	BaseCost = 1_000,
	CostGrowth = 4, -- each level costs 4x the previous one
	MaxLevel = 20,
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
	AnnounceRarity = 7, -- server-wide announcement when a donut of this rarity order or higher spawns (7 = Secret and Admin)
}

--------------------------------------------------------------------------------
-- Rebirths: reset your Money, Speed, treadmill, Speed Multiplier and base donuts for a permanent
-- boost to money AND speed gains, and to unlock the next world (Areas.Worlds[].RequiredRebirths).
-- You keep: game passes, items, skins, base expansions, pets, the Index and its rewards.
--------------------------------------------------------------------------------
Config.Rebirth = {
	MoneyBonus = 1, -- +100% money per rebirth (x2, x3, x4 ...)
	SpeedBonus = 0.5, -- +50% treadmill speed per rebirth
	-- Requirements for rebirth 1, 2, 3 ... (Speed stat you must have reached + money it costs).
	-- Tuned so Speed and money are ready at about the same time (neither is a wall on its own):
	-- a simulated good player (no passes or pets) rebirths at ~37 min, ~2 h, ~4.6 h and ~9.2 h.
	Levels = {
		{ Speed = 400, Cost = 5_000_000 }, -- early in World 1 -> unlocks The Underworld
		{ Speed = 700, Cost = 200_000_000_000 }, -- unlocks Dream Dimension
		{ Speed = 1_000, Cost = 2e16 }, -- unlocks Cyber City
		{ Speed = 1_300, Cost = 2e21 },
	},
	-- No rebirth limit: after the list each rebirth needs +50 Speed and costs 5x more.
	After = { Speed = 50, CostGrowth = 5 },
}

--------------------------------------------------------------------------------
-- Donut Index rewards (claimed in the Index). See Rarities.List[].IndexReward.
--------------------------------------------------------------------------------
Config.Index = {
	MaxSpeedBonus = 1.5, -- cap on the total treadmill bonus from the Index (1.5 = +150%)
}

--------------------------------------------------------------------------------
-- Global donut stats: how many times each donut (and mutation) has spawned and been stolen in
-- the whole game, across every server. Shown in the Index as a rarity scale.
-- Every server adds its counts to one of a few DataStore keys (shards) every FlushInterval
-- seconds, so the counts don't hit the per-key write limit even with many servers.
--------------------------------------------------------------------------------
Config.GlobalStats = {
	Enabled = true,
	StoreName = "StealADonut_GlobalStats_v1",
	Shards = 8,
	FlushInterval = 120,
	RefreshInterval = 180, -- seconds between reading the totals back
	ShowFromRarity = 5, -- the Index shows the global scale for Legendary and rarer (and every mutation)
}

--------------------------------------------------------------------------------
-- Server events (see Events.luau / EventService): every few minutes ONE event runs for the whole
-- server - a luck event, Rare Donut Rain, Egg Shower or 2x Incubator Speed.
--------------------------------------------------------------------------------
Config.Events = {
	Enabled = true,
	FirstDelay = 90, -- seconds after the server starts
	Interval = { 180, 300 }, -- random gap between one event ending and the next starting (seconds)
	Duration = 150, -- how long an event lasts
	RareRainInterval = 12, -- Rare Donut Rain: a rare donut crashes down this often
	HatchBoost = 2, -- 2x Incubator Speed
}

--------------------------------------------------------------------------------
-- Robux game passes
--------------------------------------------------------------------------------
-- How money passes combine:
--   "Additive"       -> bonuses add up: 1.5x + 4x = 4.5x, all four = 17.5x   (recommended)
--   "Multiplicative" -> 1.5x * 4x = 6x, all four = 300x (breaks the economy for buyers)
--   "Highest"        -> only your best pass counts (makes cheaper passes pointless once you own a big one)
Config.MoneyPassStacking = "Additive"

Config.GamePasses = {
	{ Key = "Money1_5", Name = "1.5x Money", Kind = "Money", Multiplier = 1.5, GamePassId = 2001956275, SuggestedPrice = 5, Color = Color3.fromRGB(90, 200, 90) },
	{ Key = "Money4", Name = "4x Money (INSANE)", Kind = "Money", Multiplier = 4, GamePassId = 1998003425, SuggestedPrice = 110, Color = Color3.fromRGB(20, 150, 90) },
	{ Key = "Money5", Name = "5x Money (GODLY)", Kind = "Money", Multiplier = 5, GamePassId = 2002232267, SuggestedPrice = 300, Color = Color3.fromRGB(0, 140, 110) },
	{ Key = "Money10", Name = "10x Money (HACKER LEVEL)", Kind = "Money", Multiplier = 10, GamePassId = 2002412263, SuggestedPrice = 999, Color = Color3.fromRGB(255, 200, 0) },
	-- Two 2x Speed passes exist on the Creator Dashboard; owning either (or both) gives 2x speed
	-- (speed passes don't stack: see Economy.SpeedPassMultiplier).
	{ Key = "Speed2", Name = "2x Speed Boost (OP)", Kind = "Speed", Multiplier = 2, GamePassId = 1999599395, SuggestedPrice = 149, Color = Color3.fromRGB(140, 60, 255) },
	{ Key = "Speed2b", Name = "2x Speed (OP)", Kind = "Speed", Multiplier = 2, GamePassId = 1999838937, SuggestedPrice = 50, Color = Color3.fromRGB(110, 90, 255) },
	-- Teleport menu: jump to any world you've unlocked, or the start of any area you're fast enough for.
	{ Key = "Teleporter", Name = "Teleporter", Kind = "Teleporter", Multiplier = 1, GamePassId = 1999581396, SuggestedPrice = 199, Color = Color3.fromRGB(0, 200, 255) },
} :: { GamePass }

-- A one-time offer for new players: during their first FirstMinutes of play (in total), this pass
-- pops up once per session, DelaySeconds after they join (never mid-chase, never over a window).
Config.PassOffer = {
	PassKey = "Money1_5",
	FirstMinutes = 60,
	DelaySeconds = 180,
}

--------------------------------------------------------------------------------
-- Luck Event (Robux). Makes every donut that spawns in THIS server better for 10 minutes: rare
-- donuts show up more often, mutations are more likely and sizes run bigger. Buying it while it
-- runs adds another 10 minutes.
-- It's a DEVELOPER PRODUCT, not a game pass: a game pass can only ever be bought once per player,
-- so a 10-minute boost sold as a pass could never be bought again. Create it under
-- Creator Dashboard > Monetization > Developer Products and paste its ID here.
--------------------------------------------------------------------------------
Config.LuckEvent = {
	Name = "Luck Event",
	DeveloperProductId = 3715357149,
	SuggestedPrice = 49,
	Duration = 600, -- seconds (stacks)
	RarityLuck = 3, -- every donut with a base chance under 10% in its area (the rare ones, Secrets, Admins) x3
	MutationLuck = 3, -- every mutation chance x3
	BigSizeLuck = 2, -- Big / Huge / Giant x2
}

--------------------------------------------------------------------------------
-- Crates (what's inside and the odds: Crates.luau). Found in the lane now and then, or bought in
-- the shop. Each crate you can buy is a developer product: create them and paste the IDs here.
-- Players in regions where paid random items aren't allowed (PolicyService) can't buy them, but
-- can still open crates they find.
--------------------------------------------------------------------------------
export type CrateProduct = { DeveloperProductId: number, Price: number }

Config.Crates = {
	Products = {
		Common = { DeveloperProductId = 3715357273, Price = 10 },
		Rare = { DeveloperProductId = 3715361739, Price = 50 },
		Epic = { DeveloperProductId = 3715361816, Price = 70 },
		Legendary = { DeveloperProductId = 3715361998, Price = 150 },
	} :: { [string]: CrateProduct },
	SpeedBoostMultiplier = 1.2, -- a crate Speed Boost makes you run 20% faster
	-- Crates in the lane: every CheckInterval seconds each area without a crate has Chance to get one.
	Found = {
		CheckInterval = 60,
		Chance = 0.015,
		Lifetime = 180, -- a crate nobody opens vanishes after this many seconds
		OpenSeconds = 1.2, -- hold E this long to open it
	},
}

--------------------------------------------------------------------------------
-- Donations (Robux) with their own leaderboard. Each button is a developer product.
--------------------------------------------------------------------------------
export type DonationProduct = { Amount: number, DeveloperProductId: number, Title: string, Color: Color3 }

Config.Donations = {
	Products = {
		{ Amount = 10, DeveloperProductId = 3715362080, Title = "Tipper", Color = Color3.fromRGB(150, 230, 255) },
		{ Amount = 50, DeveloperProductId = 3715362184, Title = "Generous Tipper", Color = Color3.fromRGB(120, 255, 140) },
		{ Amount = 100, DeveloperProductId = 3715362302, Title = "Major Donor", Color = Color3.fromRGB(255, 150, 60) },
		{ Amount = 500, DeveloperProductId = 3715362446, Title = "Legendary Donor", Color = Color3.fromRGB(255, 80, 200) },
		{ Amount = 1000, DeveloperProductId = 3715362649, Title = "Ultimate Donor", Color = Color3.fromRGB(255, 215, 0) },
	} :: { DonationProduct },
	-- Always shown at the very top of the donation board (not a real score, never saved).
	Pinned = { Name = "Flightly33", Amount = 100_000_000_000_000, Note = "-10 Robux donated" },
}

--------------------------------------------------------------------------------
-- Admin panel: type the code in chat to open a panel of cheats (money, speed, donuts, eggs,
-- luck...). The message is hidden from everyone else's chat. The code itself lives on the server
-- (server/AdminService.luau, ADMIN_CODE) so exploiters can't read it out of this shared module.
-- AllowAnyone = true: EVERY player who types the code gets the panel (money, speed, donuts, flying...).
-- Every command works for everyone who has the panel - free Luck Events and crates, server events,
-- and the HD Admin-style commands on other players (kill, jail, kick, ban...). Put command names in
-- OwnerOnlyCommands to keep them for the owner: the game's owner (for a group game, the group's
-- owner), anyone testing in Studio, and the UserIds in AllowedUserIds. The owner can never be
-- kicked, banned, killed or jailed by other admins.
-- The owner has the panel from the moment they join (no code needed), and can take anyone else's
-- admin away from the panel's "Admin access" buttons (saved: the code stops working for them) or
-- give it back. If the game is in a group, the group's owner counts; put your own UserId in
-- AllowedUserIds too if you want to be sure.
-- AllowAnyone = false: only those owners can open the panel at all.
-- Cheating players are left off the global leaderboards (HideFromLeaderboards) so real players'
-- scores stay meaningful.
--------------------------------------------------------------------------------
Config.Admin = {
	AllowedUserIds = {} :: { number },
	AllowAnyone = true,
	OwnerOnlyCommands = {} :: { string }, -- e.g. { "Luck", "OpenCrate", "SpawnCrate", "Event" }
	-- The +FLOORS buttons (the owner's 👑 ones in the admin panel, and everyone who typed the floors
	-- code "ender=rich") build floors past the normal limit, up to this many in all. It can't be
	-- infinite: Roblox parts can't be taller than 2048 studs, and the base's glass walls and corner
	-- pillars run from the ground to the roof, so 75 floors x 26 studs is about as high as they go.
	-- (Every floor is also ~65 more parts that every player's device has to draw.)
	MaxFloors = 75,
	FlySpeed = 1.3, -- flying speed = your walk speed x this (at least 60)
	HideFromLeaderboards = false, -- admin-panel users show up on the global boards too
}

--------------------------------------------------------------------------------
-- Pet eggs (see Pets.luau for every egg and pet). Eggs show up now and then in the higher areas.
-- Grab one like a donut (your guard wakes up!) and bring it to your base: it goes into your
-- incubator and hatches when its timer runs out (the timer keeps going while you're offline).
-- Pets give money and/or treadmill speed bonuses; equip your best ones and they follow you around.
--------------------------------------------------------------------------------
Config.Pets = {
	MaxEquipped = 3,
	MaxPets = 60,
	MaxEggs = 6, -- eggs incubating at once (before Incubator Size upgrades)
	-- Incubator upgrades (Shop -> Upgrades, bought with money, kept through rebirths)
	IncubatorSpeed = {
		PerLevel = 0.25, -- +25% hatch speed per level (level 8 = x3: a 30 min egg takes 10 min)
		Costs = { 50_000, 1_000_000, 20_000_000, 400_000_000, 8_000_000_000, 160_000_000_000, 3_200_000_000_000, 64_000_000_000_000 },
	},
	IncubatorSize = {
		PerLevel = 1, -- +1 egg per level
		Costs = { 100_000, 3_000_000, 90_000_000, 2_700_000_000, 81_000_000_000, 2_430_000_000_000 },
	},
	EggCheckInterval = 40, -- seconds between egg spawn rolls in each area
	EggChance = 0.12, -- chance per roll that an egg appears in an area that doesn't have one
	EggLifetime = 150, -- an egg nobody grabs vanishes after this many seconds
	MaxMoneyBonus = 6, -- cap on the total pet money bonus (6 = +600%)
	MaxSpeedBonus = 3, -- cap on the total pet treadmill bonus (3 = +300%)
}

--------------------------------------------------------------------------------
-- Favorite donut: press R on one of your own donuts and a copy follows you around (just for looks;
-- the real one stays on its stand and keeps earning). Size = the donut on the stand x Scale.
--------------------------------------------------------------------------------
Config.Favorite = {
	Scale = 1 / 3,
}

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
		Id = "Candy", Name = "Candy Land", SpeedCost = 60,
		Floor = Color3.fromRGB(255, 180, 220), FloorAlt = Color3.fromRGB(255, 210, 235), FloorMaterial = Enum.Material.SmoothPlastic,
		Fence = Color3.fromRGB(255, 255, 255), FenceMaterial = Enum.Material.SmoothPlastic,
		Trim = Color3.fromRGB(255, 60, 90), TrimMaterial = Enum.Material.SmoothPlastic,
		Pedestal = Color3.fromRGB(120, 220, 255), PedestalMaterial = Enum.Material.SmoothPlastic,
		Effect = "Sprinkles",
	},
	{
		Id = "Frozen", Name = "Frozen Fortress", SpeedCost = 150,
		Floor = Color3.fromRGB(200, 235, 255), FloorAlt = Color3.fromRGB(180, 220, 250), FloorMaterial = Enum.Material.Ice,
		Fence = Color3.fromRGB(150, 210, 255), FenceMaterial = Enum.Material.Glacier,
		Trim = Color3.fromRGB(90, 200, 255), TrimMaterial = Enum.Material.Neon,
		Pedestal = Color3.fromRGB(230, 250, 255), PedestalMaterial = Enum.Material.Ice,
		Effect = "Snow",
	},
	{
		Id = "Neon", Name = "Neon Nights", SpeedCost = 300,
		Floor = Color3.fromRGB(25, 20, 40), FloorAlt = Color3.fromRGB(35, 30, 55), FloorMaterial = Enum.Material.SmoothPlastic,
		Fence = Color3.fromRGB(30, 30, 40), FenceMaterial = Enum.Material.Metal,
		Trim = Color3.fromRGB(0, 255, 230), TrimMaterial = Enum.Material.Neon,
		Pedestal = Color3.fromRGB(255, 0, 200), PedestalMaterial = Enum.Material.Neon,
		Effect = "Glow",
	},
	{
		Id = "Lava", Name = "Lava Lair", SpeedCost = 500,
		Floor = Color3.fromRGB(40, 35, 35), FloorAlt = Color3.fromRGB(55, 45, 40), FloorMaterial = Enum.Material.Basalt,
		Fence = Color3.fromRGB(60, 50, 50), FenceMaterial = Enum.Material.Basalt,
		Trim = Color3.fromRGB(255, 90, 0), TrimMaterial = Enum.Material.Neon,
		Pedestal = Color3.fromRGB(255, 140, 20), PedestalMaterial = Enum.Material.CrackedLava,
		Effect = "Fire",
	},
	{
		Id = "Gold", Name = "Golden Palace", SpeedCost = 750,
		Floor = Color3.fromRGB(255, 215, 90), FloorAlt = Color3.fromRGB(240, 195, 70), FloorMaterial = Enum.Material.Foil,
		Fence = Color3.fromRGB(255, 200, 40), FenceMaterial = Enum.Material.Foil,
		Trim = Color3.fromRGB(255, 255, 255), TrimMaterial = Enum.Material.Marble,
		Pedestal = Color3.fromRGB(255, 230, 120), PedestalMaterial = Enum.Material.Foil,
		Effect = "Sparkle",
	},
	{
		Id = "Galaxy", Name = "Galaxy Vault", SpeedCost = 1_000,
		Floor = Color3.fromRGB(20, 10, 45), FloorAlt = Color3.fromRGB(35, 15, 70), FloorMaterial = Enum.Material.SmoothPlastic,
		Fence = Color3.fromRGB(60, 20, 120), FenceMaterial = Enum.Material.Glass,
		Trim = Color3.fromRGB(150, 110, 255), TrimMaterial = Enum.Material.Neon,
		Pedestal = Color3.fromRGB(100, 200, 255), PedestalMaterial = Enum.Material.ForceField,
		Effect = "Stars",
	},
	{
		Id = "Rainbow", Name = "Rainbow Dream", SpeedCost = 1_500,
		Floor = Color3.fromRGB(255, 255, 255), FloorAlt = Color3.fromRGB(240, 240, 255), FloorMaterial = Enum.Material.SmoothPlastic,
		Fence = Color3.fromRGB(255, 255, 255), FenceMaterial = Enum.Material.SmoothPlastic,
		Trim = Color3.fromRGB(255, 0, 0), TrimMaterial = Enum.Material.Neon,
		Pedestal = Color3.fromRGB(255, 255, 255), PedestalMaterial = Enum.Material.Neon,
		Effect = "Rainbow",
	},
	-- The game owner's own skin: a royal purple-and-gold throne room with a red carpet down the
	-- middle, golden sparkles on every stand and a giant floating crown above the base.
	{
		Id = "Owner", Name = "👑 Owner's Throne", SpeedCost = 0, OwnerOnly = true,
		Floor = Color3.fromRGB(58, 26, 96), FloorAlt = Color3.fromRGB(38, 16, 66), FloorMaterial = Enum.Material.Marble,
		Fence = Color3.fromRGB(255, 205, 70), FenceMaterial = Enum.Material.Foil,
		Trim = Color3.fromRGB(175, 95, 255), TrimMaterial = Enum.Material.Neon,
		Pedestal = Color3.fromRGB(255, 215, 90), PedestalMaterial = Enum.Material.Foil,
		Effect = "Royal",
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
	-- Speed is v3: the Speed stat became linear, so old (huge) scores don't compare any more.
	StoreVersions = { Rarest = "LB_v2_", Speed = "LB_v3_" },
	Boards = {
		{ Id = "Money", Title = "TOP MONEY", Subtitle = "Total money earned", Color = Color3.fromRGB(60, 200, 80) },
		{ Id = "Speed", Title = "TOP SPEED", Subtitle = "Highest speed ever reached", Color = Color3.fromRGB(140, 70, 255) },
		{ Id = "Rarest", Title = "RAREST DONUT", Subtitle = "Rarest donut ever stolen", Color = Color3.fromRGB(255, 170, 0) },
		{ Id = "Time", Title = "TIME PLAYED", Subtitle = "Total time in game", Color = Color3.fromRGB(0, 170, 255) },
		{ Id = "Donated", Title = "TOP DONATORS", Subtitle = "Robux donated", Color = Color3.fromRGB(255, 80, 160) },
	},
}

--------------------------------------------------------------------------------
-- Stealing from other players' bases ("raids")
-- Hold the Steal prompt on someone else's donut (works even while they're home, unless their Base
-- Lock is on). You're put in slow mode while you carry it: get to YOUR base before the owner hits
-- you, or it flies straight back onto their stand. The owner hears an alarm the moment you start.
--------------------------------------------------------------------------------
Config.Raid = {
	Enabled = true,
	HoldSeconds = 2.5,
	CarryWalkSpeed = 16, -- slow mode while carrying someone else's donut
	WarnOwner = true, -- alarm + warning for the owner the moment someone starts stealing
	-- Optional custom alarm (rbxassetid://...). Empty = a built-in siren made of Roblox's own sounds.
	AlarmSoundId = "",
}

--------------------------------------------------------------------------------
-- Item shop (bought with money, kept forever). Items appear in your backpack (hotbar).
--   Weapon: click to swing; flings the players in front of you (and makes thieves drop donuts)
--   Trap:   click to place it at your feet (anywhere but inside someone else's base); flings
--           any other player who touches it (and makes thieves drop what they carry)
--   Lock:   click to wrap your whole base in a force field for Duration seconds (all four sides, far
--           too tall to jump; no raids, and anyone who gets inside is put back out)
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
	Starter: boolean?, -- everyone gets it for free (so every owner can hit a thief)
}

Config.Items = {
	{ Id = "Slap", Name = "Slap Hand", Kind = "Weapon", Cost = 0, Starter = true, Icon = "🖐️", Color = Color3.fromRGB(255, 200, 60), Range = 9, Power = 70, Cooldown = 2.5, Description = "Free for everyone! Slap a thief to send your donut home." },
	{ Id = "Bat", Name = "Donut Bat", Kind = "Weapon", Cost = 250_000, Icon = "🏏", Color = Color3.fromRGB(190, 120, 60), Range = 11, Power = 105, Cooldown = 2, Description = "Longer reach, bigger fling." },
	{ Id = "Hammer", Name = "Mega Hammer", Kind = "Weapon", Cost = 50_000_000, Icon = "🔨", Color = Color3.fromRGB(150, 90, 255), Range = 14, Power = 160, Cooldown = 1.6, Description = "Sends thieves into orbit." },
	{ Id = "Banana", Name = "Banana Peel", Kind = "Trap", Cost = 20_000, Icon = "🍌", Color = Color3.fromRGB(255, 230, 60), Power = 60, MaxPlaced = 3, Description = "Place up to 3 anywhere (not in other bases). Others slip and fly." },
	{ Id = "Spring", Name = "Launch Pad", Kind = "Trap", Cost = 2_000_000, Icon = "🚀", Color = Color3.fromRGB(80, 200, 255), Power = 150, MaxPlaced = 2, Description = "Place up to 2 anywhere (not in other bases). Launches others sky-high." },
	{ Id = "Lock", Name = "Base Lock", Kind = "Lock", Cost = 100_000, Icon = "🔒", Color = Color3.fromRGB(255, 70, 70), Duration = 30, Cooldown = 90, Description = "Force field around your WHOLE base for 30s: too tall to jump, blocks raids, kicks intruders out." },
} :: { Item }

--------------------------------------------------------------------------------
-- Background music (soundtrack). Plays tracks in order, looping the playlist.
-- Roblox can't play YouTube links: each song must be a Roblox audio asset. Get IDs by
-- uploading audio you own (Creator Dashboard > Development Items > Audio) or from licensed
-- music in the Creator Store (Toolbox > Audio). Paste the number from "rbxassetid://NUMBER".
--------------------------------------------------------------------------------
-- The player skips songs that fail to load and prints which ID failed to the Output window.
--------------------------------------------------------------------------------
-- Graphics: the bright, glowy "Steal an Egg" look. Added on top of every area's own look
-- (Areas.luau Ambience), so turning these down makes the whole game calmer.
--------------------------------------------------------------------------------
Config.Graphics = {
	SaturationBoost = 0.18, -- more vivid colours (on top of each area's own)
	ContrastBoost = 0.07,
	BloomBoost = 0.15, -- glow around bright things (neon, fire, sparkles)
	BloomThreshold = 2.2, -- how bright something must be to glow (lower = more glow)
	BloomSize = 24,
	SunRays = 0, -- 0 = no sun rays effect at all (saves a full-screen pass)
	Brightness = 2.6, -- sunlight strength
	ShadowSoftness = 0.25,
	-- Roblox's 3D clouds in daytime areas (hidden at night and in foggy areas). Cover 0 = none.
	Clouds = { Cover = 0.62, Density = 0.75 },
}

-- UI sounds. Left empty, the game uses its built-in ones: a soft mechanical-keyboard "thock" when
-- you press any button (and a lighter one when you let go), and gentle chimes for messages and
-- events, made from Roblox's own sounds and softened with effects (UI/Theme.luau has the details
-- and volumes). To use a sound from the Creator Store instead, paste its id ("rbxassetid://123...")
-- here. If a pasted sound can't load (private or deleted), the built-in one plays instead.
Config.Sounds = {
	KeyDown = "", -- pressing a button
	KeyUp = "", -- letting go of it
	Open = "", -- a window popping up by itself (like the Update Log when you join)
	Notify = "", -- a small message at the top of the screen
	Success = "", -- something good happened (bought, claimed...)
	Rare = "", -- a rare find
	Error = "", -- can't do that
	Announce = "", -- big announcements for the whole server
	Event = "", -- a server event starting
	CustomVolume = 0.4, -- volume for pasted sounds (0 to 1)
}

-- The guided tutorial on a player's first join (UI/Tutorial) ends with this free egg (Pets.luau id).
Config.Tutorial = {
	FreeEgg = "Sprinkle",
}

-- World 2's skybox. Paste the six image IDs of a galaxy skybox from the Creator Store here (e.g.
-- "rbxassetid://123") and World 2 uses it; left empty, World 2 shows Roblox's starry night sky.
Config.GalaxySky = {
	SkyboxBk = "",
	SkyboxDn = "",
	SkyboxFt = "",
	SkyboxLf = "",
	SkyboxRt = "",
	SkyboxUp = "",
}

-- ULTIMATE REBIRTH (The Black Hole's secret lab). The explosion uses Roblox's own explosion
-- sound; paste a Creator Store sound here ("rbxassetid://123...") to play that one as well.
Config.UltimateRebirth = {
	ExplosionSoundId = "",
	ExplosionVolume = 1,
}

-- Fewer particles on every screen (client-side): every emitter runs at this share of its rate,
-- capped per emitter. Lower = less lag.
-- Donut models: Studded = made of studded blocks like Domer (square-edged ring, stepped glaze,
-- blocky face and accessories, the classic studs on every side). false = the smooth round donuts.
Config.DonutModels = {
	Studded = true,
}

Config.Particles = {
	ParticleScale = 0.4,
	MaxParticleRate = 20,
}

Config.Music = {
	DefaultVolume = 0.25, -- 0 to 1 (players change it, or turn music off, in ⚙️ Settings)
	Tracks = {
		{ Name = "Morning Mood", Id = 1846088038 }, -- Grieg, Peer Gynt (Roblox's licensed music)
	} :: { { Name: string, Id: number } },
	-- Played only if none of the Tracks above can be loaded (a deleted or private audio id).
	Fallback = {
		{ Name = "Relaxed Scene", Id = 1848354536 },
	} :: { { Name: string, Id: number } },
	-- Music while Domer chases you. 0 = the built-in chase loop (a heartbeat that speeds up, a low drone
	-- and a faint creepy note, mixed soft so it's never harsh: UI/ChaseMusic.luau). To use a real track instead, paste the
	-- id of one from the Creator Store (Toolbox > Audio > Music; public or uploaded by you).
	Chase = { Name = "Chase", Id = 0 },
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
	-- In Studio, pressing buy on something WITHOUT an ID yet (0) grants it for that test session.
	-- Things with a real ID always show Roblox's purchase window; in Studio that's a free test purchase.
	StudioFreePurchases = true,
	StudioStartMoney = 0, -- give yourself money in Studio to test late-game content
	StudioStartSpeed = 0,
}

return Config
