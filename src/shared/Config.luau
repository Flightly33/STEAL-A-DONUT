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
	PerStep: number, -- Speed gained per step (Config.Treadmill.StepsPerSecond steps a second)
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
	Heavenly: boolean?, -- the last treadmill: white marble and gold, wings and a halo of light
}

export type GamePass = {
	Key: string,
	Name: string,
	Kind: string,
	Multiplier: number,
	GamePassId: number,
	SuggestedPrice: number,
	Color: Color3,
	-- Does exactly what that pass (its Key) does: not sold in the game, but owning it still counts.
	SameAs: string?,
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
	-- players can't wake him up for you. When a chase ends he walks back to his corner.
	Scale = 4, -- model scale (1 = normal player size). He's HUGE: about 20 studs tall.
	-- His walk and idle animations (Roblox's R6 ones). Clients preload them when the game starts, so
	-- he doesn't stand frozen for a moment the first time he wakes up.
	WalkAnimation = "rbxassetid://180426354",
	IdleAnimation = "rbxassetid://180435571",
	-- His snore and the angry grunt when he wakes up. "" = made from Roblox's own sounds; paste
	-- "rbxassetid://..." from the Creator Store to use a real recording. A pasted snore plays only
	-- while you're close enough to grab one of his boxes, louder the closer you are to him:
	-- SnoreVolume right next to him, a third of it at the far side of his boxes.
	SnoreSoundId = "rbxassetid://9115480677",
	SnoreVolume = 0.45,
	GruntSoundId = "",
	-- Grabbing one of his boxes: these all play at once (Volume: 0 to 10, 1 = as uploaded). An empty
	-- list plays the built-in swipe and "got it!" jingle instead (eggs and meteor shards always do).
	GrabSounds = {
		{ Id = "rbxassetid://6506461886", Volume = 0.5 },
		{ Id = "rbxassetid://135439749484858", Volume = 0.5 },
	} :: { { Id: string, Volume: number } },
	-- The "!?" over his head while he's waking up and chasing you (client/Guards): rainbow letters
	-- with a soft glow, turning round Spin times a second. Size in studs; Glow: how bright (1 = flat).
	Alert = { Text = "!?", Spin = 0.5, Size = 6, Glow = 1.6 },
	CatchRadius = 10, -- studs (horizontal) between his centre and yours that counts as "caught"
	-- A biome's Speed is the Speed you need to get away from its Domer: each Domer is just fast
	-- enough that a player with exactly that Speed, running a small box straight back, gets out of
	-- his biome and is caught EscapeMargin studs past its entrance (outside his biome, so the box
	-- stays on the ground there). Any slower and he catches you inside (he takes the box back); a
	-- big or GIANT box slows you down, so you need more. He's about 1.2-1.3x as fast as a player
	-- with exactly the biome's Speed (Economy.GuardWalkSpeed).
	EscapeMargin = 60,
	-- After a catch (or once you reach the lobby) he walks back to his corner at this share of
	-- his chase speed. Pick the box up again and he turns around and runs at you from wherever
	-- he is.
	ReturnSpeedFactor = 0.45,
	TurnDelay = 0.4, -- seconds he takes to turn around when you grab his box again on his way home
	MaxReturnSeconds = 240, -- a walk home that takes longer than this ends with him back asleep
	-- The first biome's Domer is slower than anyone (beginners always get away).
	BeginnerSpeed = 18,
	-- Every Domer runs this much faster than the escape rule above says (a biome can add its own
	-- DomerBoost in Areas.luau); the Speed shown on the signs is worked out from his real speed
	-- (Economy.EscapeSpeed).
	SpeedBoost = 1.25,
	-- Shown in the RUN! warning while he chases you.
	RunText = "RUN!",
	-- Lag compensation: the catch is judged against where the guard was on YOUR screen (the server
	-- rewinds him by your ping plus Roblox's interpolation delay), so a fast chase over a laggy
	-- connection can't catch you while he still looks 40 studs away. Capped so lag can't be abused.
	InterpolationDelay = 0.1,
	MaxRewind = 0.35,
	GiveUpDelay = 1.2, -- seconds he stands there fuming after you reach safety, before walking home
	StunTime = 2.3, -- seconds after being caught (and flung) before you can grab anything again

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
-- One lobby (bases, treadmills, the sell stall, leaderboards) and one long lane of biomes (Areas.luau)
-- running from it along +Z. Every biome is LaneHalfWidth * 2 studs wide with thick grassy walls.
--------------------------------------------------------------------------------
Config.Map = {
	LaneHalfWidth = 100, -- the lane runs along +Z, from X = -100 to X = 100
	AreaLength = 500, -- a biome's length when Areas.luau doesn't give one (multiple of TileSize)
	TileSize = 20,
	LaneWallHeight = 60,
	WallThickness = 40, -- the lane's walls are this thick (grass on top), so there's no void beside it

	SafeZoneZ = 0, -- everything with Z < SafeZoneZ is the safe lobby (bases, treadmills, leaderboards)
	HubHalfWidth = 280, -- a compact lobby, so nothing is far away
	HubDepth = 480, -- the bases make a C round the plaza (open to the lane): 2 down each side, 2 along the back, the leaderboards between the back two
	HubWallHeight = 40,
}

-- Two conveyor belts side by side on EACH side of the lobby, just in front of the bases: one
-- carries you from the back (the leaderboards) to the front (the lane), the other back again. Anyone standing on
-- one rides along at Speed studs a second on top of their own running.
Config.Conveyors = {
	Speed = 50,
	Width = 12, -- each belt
	Gap = 4, -- between the two belts
	BaseGap = 8, -- each pair of belts sits this far in front of the bases (on the plaza side of them)
	Front = 24, -- they end this far behind the safe-zone line, by the lane's entrance
	Back = 20, -- and stop this far in front of the back row of bases (where the sides of the C end)
	ArrowSpacing = 18, -- the glowing arrows sliding along them
}

--------------------------------------------------------------------------------
-- Player bases (plots)
--------------------------------------------------------------------------------
Config.Plots = {
	Count = 6, -- bases per server: set the game's Max Players to this too (Game Settings > Places > Server Size)
	-- Your base is a donut shop with an open pen in front (like Steal an Egg) where your donuts roam.
	-- Upgrade it at the sign by its gate: every size holds Slots donuts (and boxes waiting to open)
	-- and the pen grows a little each time.
	Sizes = {
		{ Slots = 7, Cost = 0 },
		{ Slots = 9, Cost = 100_000 },
		{ Slots = 11, Cost = 1_500_000 },
		{ Slots = 13, Cost = 22_000_000 },
		{ Slots = 15, Cost = 320_000_000 },
		{ Slots = 17, Cost = 4_600_000_000 },
		{ Slots = 19, Cost = 68_000_000_000 },
		{ Slots = 20, Cost = 1_000_000_000_000 },
	},
	-- Past the last size (the owner, and the "ender=rich" code): ExtraSlots more per size, up to
	-- Config.Admin.MaxSlots.
	ExtraSlots = 5,
	-- The pen holds a CellSize x CellSize patch of ground per donut (a little wider than deep).
	-- Every donut roams around its own patch, up to RoamRadius x CellSize from its middle.
	CellSize = 18,
	RoamRadius = 0.85,
	RoamSpeed = 3.5, -- studs per second while walking (bigger donuts take bigger strides)
	FenceHeight = 3.5, -- a low fence anyone can hop over (like Steal an Egg)
	DonutScale = 1.5,
	PodiumDonutScale = 1.7,
}

--------------------------------------------------------------------------------
-- Speed
-- The "Speed" stat is the big number in the HUD (it climbs into the hundreds of millions). How fast
-- you actually run grows more gently with it, or late-game players would break Roblox's physics.
-- Your Speed counts StatMultiplier times when you run (100 Speed runs like 200):
--   WalkSpeed = BaseWalkSpeed + CurveScale * (StatMultiplier * Speed) ^ CurvePower
--   (Speed 0 = 24, 900 = 45, 10K = 57, 700K = 102, 30M = 189, 400M = 302)
-- Each biome shows the Speed you need to get away from its Domer (Areas.luau; anyone can walk in).
--------------------------------------------------------------------------------
Config.Speed = {
	StartSpeed = 30, -- the Speed stat a brand new player starts with (it runs like 34: see the formula above)
	BaseWalkSpeed = 24,
	StatMultiplier = 2, -- your Speed counts double when you run
	MinRunSpeed = 16, -- the slowest run speed you can type in Settings
	CurveScale = 4.6,
	CurvePower = 0.2,
}

-- Treadmills: the one by your base gives Speed every step while you run on it (StepsPerSecond steps
-- a second). Buy the next one in the Shop. PerStep is before your Speed Multiplier, Index, pets
-- and 2x Speed pass.
-- Balance (economy sim, a good player with no passes or pets, sharing boxes with other players):
-- biome 6 at ~1.3 h, biome 12 at ~6.5 h, the last biome at ~12.5 h; the last treadmill at ~11 h.
-- Real players take longer (breaks, getting caught, losing boxes to bats).
local rgb = Color3.fromRGB
Config.Treadmill = {
	BeltSpeed = 13, -- how fast the belt stripes scroll (visual only)
	StepsPerSecond = 12,
	Tiers = {
		{ Name = "Rusty", PerStep = 3, Cost = 0, Base = rgb(120, 110, 100), Accent = rgb(150, 80, 50), Material = Enum.Material.CorrodedMetal },
		{ Name = "Basic", PerStep = 5, Cost = 15_000, Base = rgb(230, 230, 230), Accent = rgb(40, 40, 40), Material = Enum.Material.SmoothPlastic },
		{ Name = "Sporty", PerStep = 12, Cost = 250_000, Base = rgb(220, 40, 40), Accent = rgb(255, 255, 255), Material = Enum.Material.SmoothPlastic },
		{ Name = "Pro", PerStep = 30, Cost = 3_000_000, Base = rgb(40, 90, 200), Accent = rgb(0, 220, 255), Material = Enum.Material.Metal, Neon = true },
		{ Name = "Turbo", PerStep = 80, Cost = 75_000_000, Base = rgb(255, 140, 0), Accent = rgb(255, 240, 0), Material = Enum.Material.Metal, Neon = true, Fire = true },
		{ Name = "Neon", PerStep = 100, Cost = 1_500_000_000, Base = rgb(20, 20, 30), Accent = rgb(0, 255, 120), Material = Enum.Material.SmoothPlastic, Neon = true, Light = true },
		{ Name = "Diamond", PerStep = 250, Cost = 50_000_000_000, Base = rgb(150, 230, 255), Accent = rgb(255, 255, 255), Material = Enum.Material.Glass, Neon = true, Light = true, Sparkles = true },
		{ Name = "Plasma", PerStep = 500, Cost = 1_000_000_000_000, Base = rgb(60, 10, 90), Accent = rgb(200, 60, 255), Material = Enum.Material.SmoothPlastic, Neon = true, Light = true, Sparkles = true },
		{ Name = "Quantum", PerStep = 1_000, Cost = 15_000_000_000_000, Base = rgb(10, 10, 10), Accent = rgb(255, 0, 170), Material = Enum.Material.Glass, Neon = true, Light = true, Sparkles = true, Rainbow = true },
		{ Name = "Cosmic", PerStep = 1_500, Cost = 45_000_000_000_000, Base = rgb(40, 20, 90), Accent = rgb(120, 200, 255), Material = Enum.Material.Glass, Neon = true, Light = true, Sparkles = true, Rainbow = true, Halo = true },
		{ Name = "Void", PerStep = 2_000, Cost = 100_000_000_000_000, Base = rgb(5, 5, 10), Accent = rgb(150, 90, 255), Material = Enum.Material.Glass, Neon = true, Light = true, Sparkles = true, Halo = true },
		{ Name = "Heavenly", PerStep = 3_000, Cost = 500_000_000_000_000, Base = rgb(255, 250, 235), Accent = rgb(255, 215, 90), Material = Enum.Material.Marble, Neon = true, Light = true, Sparkles = true, Rainbow = true, Halo = true, Heavenly = true },
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
	AnnounceRarity = 7, -- server-wide announcement when someone gets a donut of this rarity order or higher home (7 = Secret and up)
}

--------------------------------------------------------------------------------
-- Donut boxes (Boxes.luau): what you steal. Each biome's Domer sleeps in a back corner with
-- PerBiome boxes around him; every box in every biome is replaced by a fresh batch every
-- ResetInterval seconds ("ALL BOXES RESET!"). A box you steal leaves its spot empty until then.
-- Bring a box back to the lobby and it goes into your inventory; take it out in your pen and it
-- opens after its rarity's HatchSeconds x its size's HatchMultiplier (also while you're offline).
-- Which boxes each biome's Domer guards (Lineups): the plain pink box in the first biome, Rare /
-- Epic / Legendary after that, and from biome 11 on the Rare box makes way for the MYTHIC box:
-- Epic / Legendary / Mythic. Weight = how often each turns up. (The economy sim checked the Mythic
-- lineup: its boxes are worth more but take longer to open, so the 12-16 hour pace stays the same.)
--------------------------------------------------------------------------------
local PINK = Color3.fromRGB(255, 170, 205)
Config.Boxes = {
	PerBiome = 5,
	ResetInterval = 300,
	Tiers = {
		{ Id = "Basic", Name = "Donut Box", Order = 0, HatchSeconds = 30, Color = PINK, Trim = Color3.fromRGB(255, 255, 255) },
		{ Id = "Rare", Name = "Rare Donut Box", Order = 1, HatchSeconds = 60, Color = Color3.fromRGB(80, 160, 255), Trim = Color3.fromRGB(255, 255, 255) },
		{ Id = "Epic", Name = "Epic Donut Box", Order = 2, HatchSeconds = 600, Color = Color3.fromRGB(175, 80, 255), Trim = Color3.fromRGB(255, 220, 255) },
		{ Id = "Legendary", Name = "Legendary Donut Box", Order = 3, HatchSeconds = 3600, Color = Color3.fromRGB(255, 195, 40), Trim = Color3.fromRGB(255, 255, 255) },
		{ Id = "Mythic", Name = "Mythic Donut Box", Order = 4, HatchSeconds = 7200, Color = Color3.fromRGB(210, 25, 60), Trim = Color3.fromRGB(255, 210, 80) },
	},
	Lineups = {
		{ From = 1, Tiers = { { Id = "Basic", Weight = 1 } } },
		{ From = 2, Tiers = { { Id = "Rare", Weight = 70 }, { Id = "Epic", Weight = 25 }, { Id = "Legendary", Weight = 5 } } },
		{ From = 11, Tiers = { { Id = "Epic", Weight = 70 }, { Id = "Legendary", Weight = 25 }, { Id = "Mythic", Weight = 5 } } },
	},
	-- Bigger boxes are rarer, take longer to open and hold a bigger donut (that earns more).
	-- CarrySpeed: you run this much slower while you carry it.
	Sizes = {
		{ Id = "Small", Name = "Small", HatchMultiplier = 1, Weight = 80, Scale = 1, DonutSize = "Normal", CarrySpeed = 1 },
		{ Id = "Big", Name = "Big", HatchMultiplier = 1.5, Weight = 14, Scale = 1.4, DonutSize = "Big", CarrySpeed = 0.95 },
		{ Id = "Huge", Name = "Huge", HatchMultiplier = 2, Weight = 5, Scale = 1.85, DonutSize = "Huge", CarrySpeed = 0.9 },
		{ Id = "Giant", Name = "GIANT", HatchMultiplier = 3, Weight = 1, Scale = 2.5, DonutSize = "Giant", CarrySpeed = 0.84 },
	},
	-- "Open now" for Robux (a developer product, bought again every time: create it under
	-- Creator Dashboard > Monetization > Developer Products and paste its ID here). 0 = not set up
	-- yet: the button says "Coming Soon" in live servers (Studio test purchases still work).
	SkipProductId = 0,
	SkipPrice = 49,
	-- Box Rush: every Interval seconds, for Duration seconds, every box in every pen opens Speed
	-- times faster (so 10 seconds of it is 5 minutes of waiting).
	Rush = { Interval = 150, Duration = 10, Speed = 30 },
	-- A box dropped outside its own biome (caught by Domer out there, knocked out of your hands)
	-- stays on the ground this long.
	DroppedLifetime = 120,
	StealSeconds = 0.6, -- hold E this long to grab a box
	MaxInventory = 60, -- boxes + donuts you can carry in your inventory
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
-- The Eternal Storm: a VERY rare server event (or the owner's button in the admin panel). A
-- giant black hole fills the sky, huge chunks of rock rain down (anyone they land on is flung), and
-- purple lightning strikes donuts in every world's lanes: every donut it hits becomes ETERNAL
-- (x50 money, purple glow, a storm of purple lightning round it). Only lane donuts get struck.
Config.EternalStorm = {
	Weight = 0.6, -- (only if Schedule is off) how often it's picked compared to the other events
	Duration = 180,
	-- Ambience all through the storm (client/StormFX): a loop in the background, and now and then
	-- distant thunder or the other sound (taking turns, Gap seconds apart)
	-- a falling rock (a tiny meteor) crashing down: louder the closer you are
	RockCrash = { Id = "rbxassetid://122368977681778", Volume = 0.7 },
	Ambience = {
		Loop = { Id = "rbxassetid://9114222288", Volume = 0.3 },
		Thunder = { Id = "rbxassetid://9119840732", Volume = 0.5 },
		Other = { Id = "rbxassetid://236328669", Volume = 0.4 },
		Gap = { 9, 20 },
	},
	-- When it comes (shared/StormClock): on the real clock, the same moment on every server - every
	-- Every hours, on the hour, counting from Hour, in US Pacific time: 12am, 2am ... 2pm, 4pm ...
	-- A countdown at the top of the screen shows how long until the next one.
	Schedule = {
		Enabled = true,
		Every = 2, -- hours between storms
		Hour = 14, -- one of the times it comes (2pm); the others are every Every hours from it
		UtcOffset = -8, -- US Pacific standard time...
		DaylightSaving = true, -- ...an hour later from the second Sunday in March to the first in November
	},
	StrikeInterval = { 7, 12 }, -- seconds between lightning strikes that turn a donut Eternal
	BlockInterval = { 1.2, 2.6 }, -- seconds between falling rocks (in each world someone is in)
	BlockSize = { 18, 34 }, -- studs
	FallTime = 2.6, -- seconds from a rock appearing in the sky to it hitting the ground
	FlingPower = 115,
	HoleScale = 20, -- the black hole in the sky (The Black Hole's own is 3)
	HoleHeight = 760,
	-- The cosmic sky, made in Blender (art/eternal_sky). Upload the images in Studio (Asset Manager >
	-- Bulk Import) and paste each one's id here, like "rbxassetid://1234567890":
	--   the six Skybox faces: space full of stars, nebulae and a galaxy band, slowly turning
	--   Disk + Halo: a giant black hole hanging high in front of you wherever you are, its disk
	--     spinning (instead of the black hole made of parts); Galaxy: a spinning galaxy behind you
	-- Leave them empty and the storm keeps its built-in look.
	Sky = {
		SkyboxFt = "",
		SkyboxBk = "",
		SkyboxLf = "",
		SkyboxRt = "",
		SkyboxUp = "",
		SkyboxDn = "",
		Disk = "",
		Halo = "",
		Galaxy = "",
	},
	SkySpin = 1.2, -- degrees per second the cosmic sky turns
	DiskSpin = 16, -- degrees per second the black hole's disk spins
	-- The event's song: the Radetzky March from the Creator Store. Empty (or an id that won't load)
	-- = a built-in version of the march played with Roblox's own sounds.
	MusicId = "rbxassetid://1844280451",
	MusicVolume = 1, -- x the player's music volume
}

-- The Cosmic Donut (limited time). 45 seconds into every Eternal Storm (MeteorAt) a huge meteor
-- shatters the sky and cracks open on the lane (and Cosmic Domer climbs out over its crater): carry its shards back to the lobby (one at a time) and craft The
-- Cosmic Donut with them at the Cosmic Forge by the spawn. Enabled = false ends it - no more
-- meteors or crafting, and the storm goes back to being super rare (anyone who made one keeps it).
Config.CosmicDonut = {
	Enabled = true,
	ShardCost = 10, -- meteor shards to craft The Cosmic Donut
	Pieces = 8, -- shards a meteor cracks into (fewer than ShardCost: a Cosmic Donut takes more than one meteor)
	StormWeight = 6.5, -- (only if EternalStorm.Schedule is off) the storm's weight while Enabled, instead of EternalStorm.Weight
	ShardLife = 240, -- seconds the shards lie on the lane after the meteor lands
	MeteorAt = 45, -- seconds into the 3:00 storm that the meteor show starts (it lands about 8 seconds later)
	Biomes = { 2, 6 }, -- the biomes it can land in, first to last (never the first, right by the lobby: too easy)
	FlingPower = 140, -- anyone it lands on
	-- (Creator Store sounds: they have to be public, or allowed in this game, to play)
	Sounds = {
		Flash = "rbxassetid://113285467514193", -- the screen goes white
		Shatter = "rbxassetid://9117235691", -- the sky shatters and the meteor bursts through
		Fall = "rbxassetid://87028588436252", -- the meteor falling
		Impact = { "rbxassetid://82448878741528", "rbxassetid://9114587083" }, -- it hits the lane and cracks open
	},
}

-- Cosmic Domer (shared/Giant, server/GiantService): after the Cosmic Meteor crashes, a colossal
-- Domer climbs out of a black hole over the lane for the rest of the Eternal Storm and smashes his
-- fists into the lane near the crater. Enabled = false: no giant.
Config.CosmicGiant = {
	Enabled = true,
	SlamEvery = 7, -- seconds between slams (one fist at a time)
	KnockRadius = 30, -- studs round where a fist lands: anyone inside is knocked flying and drops what they carry
	FlingPower = 130,
	Reach = { 15, 60 }, -- how far from the crater his fists land (studs)
	-- What he does, over and over (one attack every SlamEvery seconds)
	Pattern = { "Slam", "Slam", "Stars", "Slam", "Slam", "Beam" },
	StarRain = {
		Count = 14, -- stars (his rockets) he pulls out of the black hole and fires
		Radius = 16, -- studs round where each lands: anyone inside is knocked flying
		Spread = { 25, 110 }, -- how far from the crater they land (studs)
		LaunchVolume = 0.15, -- Sounds.StarLaunch, once for every star as it leaves his fist (a loud one)
		ImpactVolume = 0.35, -- Sounds.StarImpact (loud too; one for every star, a few at most each moment)
	},
	Beam = {
		Radius = 12, -- studs either side of his eye beams' path that knock you flying
		Volume = 0.1, -- the laser eyes sound (it's a loud one)
	},
	Sounds = {
		Swing = "rbxassetid://9039691442", -- his arm swinging down
		Impact = "rbxassetid://91288569991875", -- his fist hitting the lane
		Laser = "rbxassetid://126321934365548", -- his laser eyes (a 3 second sound: it loops for as long as they're on)
		Emerge = "rbxassetid://9125404769", -- him coming out of the black hole
		StarLaunch = "rbxassetid://80568077150111", -- star rain: the stars (his missiles) launching from his fists
		StarImpact = "rbxassetid://107480513009908", -- ...and each one hitting the lane
	},
}

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

-- Friend Boost: more money while your Roblox friends are in the same server. The first friend adds
-- First to your money multiplier, every friend after that adds Each more (1 friend: +1x, 2: +1.25x,
-- 3: +1.5x...). It adds on like a money pass (so with the 1.5x pass and one friend: 2.5x), pets
-- multiply it like the rest, and it's left out of offline earnings (nobody was playing with you).
Config.FriendBoost = {
	First = 1,
	Each = 0.25,
}

Config.GamePasses = {
	{ Key = "Money1_5", Name = "1.5x Money", Kind = "Money", Multiplier = 1.5, GamePassId = 2001956275, SuggestedPrice = 5, Color = Color3.fromRGB(90, 200, 90) },
	{ Key = "Money4", Name = "4x Money (INSANE)", Kind = "Money", Multiplier = 4, GamePassId = 1998003425, SuggestedPrice = 110, Color = Color3.fromRGB(20, 150, 90) },
	{ Key = "Money5", Name = "5x Money (GODLY)", Kind = "Money", Multiplier = 5, GamePassId = 2002232267, SuggestedPrice = 300, Color = Color3.fromRGB(0, 140, 110) },
	{ Key = "Money10", Name = "10x Money (HACKER LEVEL)", Kind = "Money", Multiplier = 10, GamePassId = 2002412263, SuggestedPrice = 999, Color = Color3.fromRGB(255, 200, 0) },
	-- Two 2x Speed passes exist on the Creator Dashboard and they don't stack (see
	-- Economy.SpeedPassMultiplier), so only one is sold in the game: selling both would have
	-- players pay twice for the same thing. The 149 R$ one is sold; the 50 R$ one isn't any more,
	-- but whoever already bought it keeps 2x speed.
	-- (Take the 50 R$ one off sale on the Creator Dashboard too: it's still on the game's Store tab.)
	{ Key = "Speed2", Name = "2x Speed Boost (OP)", Kind = "Speed", Multiplier = 2, GamePassId = 1999599395, SuggestedPrice = 149, Color = Color3.fromRGB(140, 60, 255) },
	{ Key = "Speed2b", Name = "2x Speed (OP)", Kind = "Speed", Multiplier = 2, GamePassId = 1999838937, SuggestedPrice = 50, Color = Color3.fromRGB(110, 90, 255), SameAs = "Speed2" },
	-- Teleport menu: jump to the start of any biome.
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
-- Luck Event (Robux). Makes every box that spawns in THIS server better for 10 minutes: the rarer
-- boxes show up more often, mutations are more likely and sizes run bigger. Buying it while it
-- runs adds another 10 minutes. The shop says exactly what it does, and the Index shows the
-- boosted odds while it runs (Roblox's rules for boosts you pay for), so keep those in step.
-- It's a DEVELOPER PRODUCT, not a game pass: a game pass can only ever be bought once per player,
-- so a 10-minute boost sold as a pass could never be bought again. Create it under
-- Creator Dashboard > Monetization > Developer Products and paste its ID here.
--------------------------------------------------------------------------------
Config.LuckEvent = {
	Name = "Luck Event",
	DeveloperProductId = 3715357149,
	SuggestedPrice = 49,
	Duration = 600, -- seconds (stacks)
	RarityLuck = 3, -- every box tier but the most common one in each biome x3 (Boxes.RollTier)
	MutationLuck = 3, -- every mutation chance x3
	BigSizeLuck = 2, -- Big / Huge / Giant boxes x2
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
	-- The BIGGER BASE buttons (the owner's ones in the admin panel, and everyone who typed the
	-- code "ender=rich") grow a base past the biggest size you can buy, up to this many donuts. It
	-- can't be infinite: every base has to fit on its plot in the hub, and every roaming donut is
	-- ~100 parts that every player's device has to move.
	MaxSlots = 25,
	FlySpeed = 1.3, -- flying speed = your walk speed x this (at least 60)
	-- Admins (everyone who used the admin panel, and the game's owner) are left off the global
	-- boards, except the donation board. Their old scores are removed the next time they play.
	HideFromLeaderboards = true,
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
	-- Incubator upgrades (Shop -> Upgrades, bought with money)
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
-- "Classic" is free and always owned. Skins are kept forever.
-- SkinRole colours: Floor / FloorAlt (the pen's checker ground) / Fence / Trim (posts, border) / Pedestal (gate arch, post caps) / Sign
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
		Id = "Candy", Name = "Candy Land", SpeedCost = 20_000,
		Floor = Color3.fromRGB(255, 180, 220), FloorAlt = Color3.fromRGB(255, 210, 235), FloorMaterial = Enum.Material.SmoothPlastic,
		Fence = Color3.fromRGB(255, 255, 255), FenceMaterial = Enum.Material.SmoothPlastic,
		Trim = Color3.fromRGB(255, 60, 90), TrimMaterial = Enum.Material.SmoothPlastic,
		Pedestal = Color3.fromRGB(120, 220, 255), PedestalMaterial = Enum.Material.SmoothPlastic,
		Effect = "Sprinkles",
	},
	{
		Id = "Frozen", Name = "Frozen Fortress", SpeedCost = 200_000,
		Floor = Color3.fromRGB(200, 235, 255), FloorAlt = Color3.fromRGB(180, 220, 250), FloorMaterial = Enum.Material.Ice,
		Fence = Color3.fromRGB(150, 210, 255), FenceMaterial = Enum.Material.Glacier,
		Trim = Color3.fromRGB(90, 200, 255), TrimMaterial = Enum.Material.Neon,
		Pedestal = Color3.fromRGB(230, 250, 255), PedestalMaterial = Enum.Material.Ice,
		Effect = "Snow",
	},
	{
		Id = "Neon", Name = "Neon Nights", SpeedCost = 1_000_000,
		Floor = Color3.fromRGB(25, 20, 40), FloorAlt = Color3.fromRGB(35, 30, 55), FloorMaterial = Enum.Material.SmoothPlastic,
		Fence = Color3.fromRGB(30, 30, 40), FenceMaterial = Enum.Material.Metal,
		Trim = Color3.fromRGB(0, 255, 230), TrimMaterial = Enum.Material.Neon,
		Pedestal = Color3.fromRGB(255, 0, 200), PedestalMaterial = Enum.Material.Neon,
		Effect = "Glow",
	},
	{
		Id = "Lava", Name = "Lava Lair", SpeedCost = 5_000_000,
		Floor = Color3.fromRGB(40, 35, 35), FloorAlt = Color3.fromRGB(55, 45, 40), FloorMaterial = Enum.Material.Basalt,
		Fence = Color3.fromRGB(60, 50, 50), FenceMaterial = Enum.Material.Basalt,
		Trim = Color3.fromRGB(255, 90, 0), TrimMaterial = Enum.Material.Neon,
		Pedestal = Color3.fromRGB(255, 140, 20), PedestalMaterial = Enum.Material.CrackedLava,
		Effect = "Fire",
	},
	{
		Id = "Gold", Name = "Golden Palace", SpeedCost = 25_000_000,
		Floor = Color3.fromRGB(255, 215, 90), FloorAlt = Color3.fromRGB(240, 195, 70), FloorMaterial = Enum.Material.Foil,
		Fence = Color3.fromRGB(255, 200, 40), FenceMaterial = Enum.Material.Foil,
		Trim = Color3.fromRGB(255, 255, 255), TrimMaterial = Enum.Material.Marble,
		Pedestal = Color3.fromRGB(255, 230, 120), PedestalMaterial = Enum.Material.Foil,
		Effect = "Sparkle",
	},
	{
		Id = "Galaxy", Name = "Galaxy Vault", SpeedCost = 100_000_000,
		Floor = Color3.fromRGB(20, 10, 45), FloorAlt = Color3.fromRGB(35, 15, 70), FloorMaterial = Enum.Material.SmoothPlastic,
		Fence = Color3.fromRGB(60, 20, 120), FenceMaterial = Enum.Material.Glass,
		Trim = Color3.fromRGB(150, 110, 255), TrimMaterial = Enum.Material.Neon,
		Pedestal = Color3.fromRGB(100, 200, 255), PedestalMaterial = Enum.Material.ForceField,
		Effect = "Stars",
	},
	{
		Id = "Rainbow", Name = "Rainbow Dream", SpeedCost = 300_000_000,
		Floor = Color3.fromRGB(255, 255, 255), FloorAlt = Color3.fromRGB(240, 240, 255), FloorMaterial = Enum.Material.SmoothPlastic,
		Fence = Color3.fromRGB(255, 255, 255), FenceMaterial = Enum.Material.SmoothPlastic,
		Trim = Color3.fromRGB(255, 0, 0), TrimMaterial = Enum.Material.Neon,
		Pedestal = Color3.fromRGB(255, 255, 255), PedestalMaterial = Enum.Material.Neon,
		Effect = "Rainbow",
	},
	-- The game owner's own skin: a royal purple-and-gold throne room with a red carpet down the
	-- middle, golden sparkles on every stand and a giant floating crown above the base.
	{
		Id = "Owner", Name = "Owner's Throne", SpeedCost = 0, OwnerOnly = true,
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
	-- Boards whose score format changed (or that were reset) get their own fresh store.
	-- (Update 6 reset every board except Time played and Donations: v4.)
	StoreVersions = { Money = "LB_v4_", Rarest = "LB_v4_", Speed = "LB_v4_" },
	Boards = {
		{ Id = "Money", Title = "TOP MONEY", Subtitle = "Total money earned", Color = Color3.fromRGB(60, 200, 80) },
		{ Id = "Speed", Title = "TOP SPEED", Subtitle = "Highest speed ever reached", Color = Color3.fromRGB(140, 70, 255) },
		{ Id = "Rarest", Title = "RAREST DONUT", Subtitle = "Rarest donut ever stolen", Color = Color3.fromRGB(255, 170, 0) },
		{ Id = "Time", Title = "TIME PLAYED", Subtitle = "Total time in game", Color = Color3.fromRGB(0, 170, 255) },
		{ Id = "Donated", Title = "TOP DONATORS", Subtitle = "Robux donated", Color = Color3.fromRGB(255, 80, 160) },
	},
}

--------------------------------------------------------------------------------
-- Items (in your backpack / hotbar). There's just one now: the free bat. Click to swing; it flings
-- the players in front of you and makes anyone carrying a box drop it.
--------------------------------------------------------------------------------
export type Item = {
	Id: string,
	Name: string,
	Kind: string,
	Cost: number,
	Description: string,
	Color: Color3,
	Range: number?,
	Power: number?,
	Cooldown: number?,
	MaxPlaced: number?,
	Duration: number?,
	Starter: boolean?, -- everyone gets it for free (so every owner can hit a thief)
}

Config.Items = {
	-- Everyone gets the bat for free, and it's the only item: hit someone carrying a box and they
	-- drop it on the ground for anyone to grab.
	{ Id = "Bat", Name = "Donut Bat", Kind = "Weapon", Cost = 0, Starter = true, Color = Color3.fromRGB(190, 120, 60), Range = 11, Power = 105, Cooldown = 2, Description = "Free for everyone! Hit someone carrying a box and they drop it - then grab it yourself." },
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

-- The sound of the biomes (client/BiomeAmbience): these loops all play together, on repeat, while
-- you're out in the lane (any biome), where the lobby's song (Config.Music) is faded out. They fade
-- out (Fade seconds) in the lobby and during the Eternal Storm, which has its own ambience
-- (Config.EternalStorm.Ambience). Volume: 0 to 10 (1 = the sound as uploaded).
Config.BiomeAmbience = {
	Loops = {
		{ Id = "rbxassetid://9116969962", Volume = 0.6 },
		{ Id = "rbxassetid://128828483841636", Volume = 1.2 }, -- (twice as loud as the first)
	} :: { { Id: string, Volume: number } },
	Fade = 1.5,
}

-- Fast Guy trail (client/TrailFX): the sound every pane of glass makes when it shatters behind you
-- (you hear your own trail only). The audio is loud, so it plays very quietly: 0 to 1.
Config.TrailSounds = {
	Glass = { Id = "rbxassetid://134429275459040", Volume = 0.05 },
}

-- The guided tutorial on a player's first join (UI/Tutorial) ends with this free egg (Pets.luau id).
Config.Tutorial = {
	FreeEgg = "Sprinkle",
}

-- Daily Rewards (shared/DailyRewards, server/DailyService, UI/DailyRewards): one reward a day, Day 1
-- to Day 7, then round again from Day 1. A new day starts at midnight on the same clock as the
-- Eternal Storm (Config.EternalStorm.Schedule: US Pacific). Miss a few days and nothing is lost:
-- your streak just waits, and your next claim is the next day in the list.
--   Money:   Minutes of your income (whatever you earn per second right now), at least Min
--   Pet:     that pet (Pets.luau), equipped straight away if you have a free slot
--   PetSlot: +1 pet you can equip at once, forever. Only the first time round; after that the day
--            gives Instead
-- OP = the gold "OP!" tag on its card.
export type DailyReward = { Kind: string, Minutes: number?, Min: number?, Pet: string?, OP: boolean?, Instead: DailyReward? }
Config.DailyRewards = {
	Days = {
		{ Kind = "Money", Minutes = 10, Min = 1_000 },
		{ Kind = "Pet", Pet = "ChocoBunny", OP = true },
		{ Kind = "PetSlot", OP = true, Instead = { Kind = "Money", Minutes = 45, Min = 5_000 } },
		{ Kind = "Pet", Pet = "MagmaHound", OP = true },
		{ Kind = "Money", Minutes = 120, Min = 10_000 },
		{ Kind = "Pet", Pet = "YetiCub", OP = true },
		{ Kind = "Pet", Pet = "GalaxyWhale", OP = true }, -- (the big one)
	} :: { DailyReward },
}

-- Fewer particles on every screen (client-side): every emitter runs at this share of its rate,
-- capped per emitter. Lower = less lag.
-- Donut models: Studded = made of studded blocks like Domer (square-edged ring, stepped glaze,
-- blocky face and accessories, the classic studs on every side). false = the smooth round donuts.
-- Shape (studded only): "Square" = the brick donut from art/brick_donut (a square ring with its
-- corners cut off, in layers: baked back, dough, glaze, raised crown); "Round" = a ring of blocks.
Config.DonutModels = {
	Studded = true,
	Shape = "Square",
}

-- Donut effects (FXThemes: Legendary and up). The particle textures they use: empty = Roblox's own
-- built-in ones. To use a Creator Store particle texture instead, paste its id, e.g.
-- Spark = "rbxassetid://1234567" (Spark: the electric bursts, Fire: the flames, Smoke: the dark
-- aura, Swirl: the spirals).
Config.DonutFX = {
	Textures = { Spark = "", Fire = "", Smoke = "", Swirl = "" } :: { [string]: string },
}

Config.Particles = {
	ParticleScale = 0.4,
	MaxParticleRate = 20,
}

Config.Music = {
	DefaultVolume = 0.25, -- 0 to 1 (players change it, or turn music off, in Settings)
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
	-- Studio only: pretend this many of your friends are in the server, to see the Friend Boost
	-- while testing alone (test players are never each other's friends).
	StudioFakeFriends = 0,
}

return Config
