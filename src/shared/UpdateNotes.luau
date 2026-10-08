--[[
	UpdateNotes: the Update Log that pops up every time a player joins (UI/UpdateNotes).

	PUBLISHING AN UPDATE? Add a new entry at the TOP of UpdateNotes.List with the next Version number.
	It shows on every join (a brand-new player's tutorial starts once they close it). The UPDATES
	button on the side shows every update any time.

	  Version  - goes up by one every update (1, 2, 3...)
	  Name     - the update's name, big under the game's logo
	  Date     - shown after "Update N Patch Notes"
	  Color    - the window's background colour; Accent - the headings' colour
	  Decor    - what floats around the notes: "Rise" (golden diamonds and sparkles drifting up),
	             "Embers" (sparks rising from a lava glow), "Stars" (twinkling stars, shooting stars
	             and a slowly turning swirl) or "Sparkles" (soft glowing bubbles)
	  Emblem   - the 3D donut in the top-left corner: { Frosting = colour, Sprinkles = { colours },
	             Dough = colour (optional) }. Its ring and the window's border use Color and Accent.
	  Sections - the patch notes: a heading, a small tag under it and bullet lines
	             { Title = "The Black Hole", Tag = "NEW Area", Lines = { "...", "..." } }
	             (the box at the top lists every section's Title)
	  Sidebar  - groups of new things shown as spinning 3D cards, built from the game's own models (no
	             images to upload, so nothing for Roblox to moderate). Kind is "Donut", "Pet" or "Egg";
	             Id is the id in Donuts.luau / Pets.luau.
	             { Title = "7 New Donuts", Items = { { Kind = "Donut", Id = "fakekar" }, ... } }
	             Hovering a card (tapping it on a phone) shows its details: rarity, stats, odds and
	             where to get it. Add Note = "..." to an item to put an extra line on that card.
]]

export type Item = { Kind: string, Id: string, Note: string? }
export type Emblem = { Frosting: Color3, Sprinkles: { Color3 }, Dough: Color3? }
export type Section = { Title: string, Tag: string, Lines: { string } }
export type Group = { Title: string, Items: { Item } }
export type Update = {
	Version: number,
	Name: string,
	Date: string,
	Color: Color3,
	Accent: Color3,
	Decor: string?,
	Emblem: Emblem?,
	Sections: { Section },
	Sidebar: { Group },
}

local UpdateNotes = {}

local function donuts(ids: { string }): { Item }
	local items = {}
	for _, id in ids do
		table.insert(items, { Kind = "Donut", Id = id })
	end
	return items
end

UpdateNotes.List = {
	{
		Version = 8,
		Name = "Studs & Sounds",
		Date = "Oct 8, 2026",
		Color = Color3.fromRGB(46, 72, 32),
		Accent = Color3.fromRGB(255, 196, 90),
		Decor = "Sparkles",
		Emblem = { Frosting = Color3.fromRGB(255, 170, 50), Sprinkles = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 220, 90), Color3.fromRGB(255, 90, 90) }, Dough = Color3.fromRGB(200, 140, 80) },
		Sections = {
			{ Title = "A New Look", Tag = "NEW Look", Lines = {
				"Every window has a new look: an orange header covered in studs, like the bricks the whole game is built from, a big red X and a dark green body",
				"Shop items, pets and trails sit on studs too",
				"Messages, announcements, events and the tutorial are now big outlined letters on a dark band across the screen",
				"Only one big message at a time: a new one fades the last one out instead of landing on top of it, and everything else at the top lines up underneath",
				"The tutorial is now the big message at the top of the screen, right in the middle",
				"No more emojis anywhere: every icon is drawn by the game itself",
				"A yellow + right next to your money takes you straight to the money boosts",
			} },
			{ Title = "Friend Boost", Tag = "NEW", Lines = {
				"Play in the same server as your Roblox friends to earn more money!",
				"Your first friend here adds +1x to your money multiplier, and every friend after that adds +0.25x more",
				"A red badge with two smiling faces shows your boost while your friends are here",
			} },
			{ Title = "The New Index", Tag = "NEW Look", Lines = {
				"One biome at a time: flip through them with the arrows on the biome's banner",
				"Every box the biome's Domer guards, how often it turns up, an arrow, then every donut that can come out of it with its chance",
				"Donuts you haven't found yet are dark silhouettes on studs, called ???",
				"Box sizes and box mutations at the bottom of every page: how likely each one is and how much more it earns",
				"The title shows how many donuts you've found: Index (12/88)",
			} },
			{ Title = "Sounds", Tag = "NEW", Lines = {
				"Every biome has its own background sounds, nice and loud",
				"The lobby music fades away when you head out into the lane, and comes back when you return",
				"Sneak up to Domer's boxes and you'll hear him snoring: the closer you get to him, the louder it gets",
			} },
			{ Title = "Eternal Storm", Tag = "CHANGED", Lines = {
				"The meteor now crashes 45 seconds into the storm, anywhere from biome 2 to biome 6",
				"Cosmic Domer climbs out of the black hole over its crater the moment it lands, and guards the shards for the rest of the storm",
				"His star rain fires twice as many rockets",
			} },
		},
		Sidebar = {},
	},
	{
		Version = 7,
		Name = "The Cosmic Meteor",
		Date = "Oct 7, 2026",
		Color = Color3.fromRGB(36, 18, 78),
		Accent = Color3.fromRGB(205, 160, 255),
		Decor = "Stars",
		Emblem = { Frosting = Color3.fromRGB(130, 60, 255), Sprinkles = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 230, 255), Color3.fromRGB(255, 120, 220) }, Dough = Color3.fromRGB(24, 14, 52) },
		Sections = {
			{ Title = "The Cosmic Meteor", Tag = "NEW Event", Lines = {
				"45 seconds into every Eternal Storm, the whole screen flashes white... then EVERYTHING shakes",
				"The sky cracks open like glass, and a giant burning meteor bursts through and falls",
				"It smashes into the lane anywhere from biome 2 to biome 6 (never the first one!): watch out, it flings anyone right under it!",
				"It cracks open in a glowing crater with 8 meteor shards around it: be quick, there aren't enough for everyone",
				"The Eternal Storm now comes every 2 hours on the real clock, at the same moment in every server, with a countdown at the top of the screen",
				"When the storm ends, the meteor's crater and any shards left on the ground evaporate: grab them while you can!",
				"The storm sounds bigger now: a rumbling background all the way through, with distant thunder rolling in now and then, and every falling rock crashes when it lands",
				"Fast Guy trail: every pane of glass you leave behind now breaks with a soft glass sound",
			} },
			{ Title = "Cosmic Domer", Tag = "NEW Boss", Lines = {
				"The moment it lands, a black hole tears open over its crater and a GIANT Domer in cosmic armour climbs out to guard the shards till the storm ends",
				"He comes out of a bigger black hole, closer to the lobby, with his own entrance sound, a shock wave and title card, and a boss bar shows how long he's staying",
				"Look closer: a crown of planets, a halo, a reactor in his chest, crystal shoulder armour, rune gauntlets, a starry cape, moons and asteroids circling him",
				"His cosmic eyes: glowing irises with a black-hole pupil and a twinkling star in it. They follow you round the lane, blink, narrow when he's about to hit, and open wide as his eye beams charge",
				"SLAM: he slowly raises a glowing fist and smashes it into the lane near the crater, with crystal spikes, cracks and a scorch mark",
				"STAR RAIN: he throws both fists up and fires a volley of 14 burning star rockets all round the crater, and you hear every one launch and hit",
				"EYE BEAM: his eyes blaze white, then two beams burn a line right across the lane",
				"Every attack shows you where it'll hit first (glowing circles and lines): get out of them! If you're hit, you go flying and drop whatever you're carrying",
				"Every screen in the server shakes when his fist hits the ground",
				"He sinks back into the black hole when the Eternal Storm ends",
			} },
			{ Title = "Meteor Shards", Tag = "NEW", Lines = {
				"Grab a shard from round the crater and run it back to the lobby to keep it",
				"Nobody chases you, but get hit by a bat or flung and you drop it for anyone to grab!",
				"Shards nobody takes fade away after a few minutes, so be quick",
			} },
			{ Title = "The Cosmic Donut", Tag = "LIMITED TIME", Lines = {
				"Bring 10 meteor shards to the new Cosmic Forge by the spawn to craft THE COSMIC DONUT",
				"The best donut in the game: it earns twice as much as the best donut from any box",
				"Swirling space colours, a glowing black hole horizon spinning round it, falling stars and a cosmic aura",
				"It's only here for a limited time, so collect your shards while you can!",
			} },
			{ Title = "Index Makeover", Tag = "NEW Look", Lines = {
				"Every biome in the Index has its own colours and background: sprinkles in Sprinkle Park, snow on Glacier Glaze, peppermint stripes in Candy Cane Canyon, a neon grid on Neon Streets, gears in the Clockwork Void, stars round The Black Hole...",
				"Each biome's donuts sit on its own sky, under a big header with its number and the Speed you need to escape it",
			} },
			{ Title = "Biome Fixes", Tag = "Fixed", Lines = {
				"Chocolate Caverns has a real cave ceiling: huge rock beams from wall to wall with big stalactites hanging from them",
				"Candy Cane Canyon's chocolate bar bridges now go all the way across the canyon",
				"Cloud Bakery's rainbow arches right over the lane from wall to wall",
				"Clockwork Void's giant gears sit on axles in the walls and turn properly; its clock tower got its clock back",
				"Neon Streets' signs are bolted to the walls, Donut Heaven's giant donut sits on top of its golden gate, and The Black Hole's holograms beam up from projectors",
			} },
		},
		Sidebar = {
			{ Title = "Crafted Donut", Items = { { Kind = "Donut", Id = "cosmicdonut", Note = "10 meteor shards at the Cosmic Forge" } } },
		},
	},
	{
		Version = 6,
		Name = "Donut Boxes",
		Date = "Oct 4, 2026",
		Color = Color3.fromRGB(120, 45, 85),
		Accent = Color3.fromRGB(255, 200, 225),
		Decor = "Sparkles",
		Emblem = { Frosting = Color3.fromRGB(255, 130, 190), Sprinkles = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(90, 200, 255), Color3.fromRGB(255, 220, 80) } },
		Sections = {
			{ Title = "Fresh Start", Tag = "Read me!", Lines = {
				"The whole game is new, so everyone starts again from the beginning",
				"You keep your game passes, donations, time played and skins",
				"The Money, Speed and Rarest Donut boards start over (Time Played and Donations stay)",
			} },
			{ Title = "Donut Boxes", Tag = "NEW", Lines = {
				"Steal donut boxes from right next to a sleeping Domer and run them back to the lobby",
				"Every biome has Rare, Epic and Legendary boxes (the first one has the pink box)",
				"From biome 11 the new MYTHIC boxes take the Rare boxes' place: Epic, Legendary and Mythic!",
				"Lucky? Find a Big, Huge or GIANT box: it holds a bigger donut but slows you down",
				"Boxes go into your inventory: hold one and click in your pen to put it down",
				"When its timer runs out, click the box to open it and out pops a donut!",
				"Rare boxes take 1 min, Epic 10 min, Legendary 1 hour and Mythic 2 hours",
				"BOX RUSH every 2:30: boxes in pens open 30x faster for 10 seconds",
				"Every 5 minutes, all the boxes are replaced with new ones",
			} },
			{ Title = "New Donut Looks", Tag = "NEW", Lines = {
				"Every donut got a makeover: two layers of glaze, shines, drips and patterns that match its name",
				"Square brick donuts: every donut is a chunky square ring built in layers - studded dough, a thick glaze and a raised top - with drips that run down the blocks",
				"The donuts closest to you breathe in and out",
				"Faces with feelings: angry brows, sleepy eyes, silly tongues, glowing ghost eyes and robot screens",
				"Strong donuts flex big muscles and wear a champion belt; animals get paws, hooves or claws",
				"Everyone has their own shoes: sneakers, high-tops, boots, sandals, robot feet...",
				"Every Epic and rarer donut has its OWN aura, made from its name: flames, falling snow, lightning, god rays, hearts, coins or snowflakes circling it... no two are the same",
				"The rarer the donut, the more its aura does (Icon donuts have 6 effects!), and they glow with a shiny outline when you're close",
			} },
			{ Title = "Cosmic Storm", Tag = "Eternal Storm", Lines = {
				"The Eternal Storm turns the sky to midnight, with shooting stars streaking across it",
				"The black hole's glowing spiral arms spin round, so you can see the whole thing turning",
			} },
			{ Title = "Fancier Boxes", Tag = "Changed", Lines = {
				"Every box rarity looks different now: ribbons, bows, gold corners and a lid you can see",
				"Legendary and Mythic boxes sit open a crack with light pouring out",
			} },
			{ Title = "17 Biomes", Tag = "NEW Map", Lines = {
				"One long lane of 17 huge biomes, from Sprinkle Park to The Black Hole",
				"Walk into any biome you like: there are no speed gates",
				"Every biome is full of little things: igloos and penguins, pyramids, mine carts, gingerbread houses, friendly ghosts...",
			} },
			{ Title = "Domer", Tag = "Changed", Lines = {
				"Domer naps in a corner of every biome: on his comfy couch in the first ones",
				"Each biome shows the Speed you need to escape its Domer: with it, you just make it out of his biome",
				"Every Domer is faster now, and the Donut Heaven and Black Hole Domers are MUCH faster",
				"Fast Domers can really catch you now (they used to trail behind you when you were very fast)",
				"Caught in his biome? He takes the box back. Caught outside it? The box stays on the ground",
				"He walks back to his corner afterwards. Grab the box again and he turns around and runs at you!",
			} },
			{ Title = "Speed", Tag = "Changed", Lines = {
				"Your Speed counts double: 100 Speed runs like 200",
				"Choose how fast you run in Settings: type a number, or MAX",
			} },
			{ Title = "Trails", Tag = "NEW", Lines = {
				"Open Trails on the left to wear one",
				"FAST GUY: leave frozen afterimages and shattering glass behind you",
				"Buy it in the Trails window for $100M",
			} },
			{ Title = "Bases & Shop", Tag = "Changed", Lines = {
				"Every base is a donut shop with a pen: upgrade it at the sign by the gate (7 to 20 donuts)",
				"Pick up a donut from your base to move it, or sell it at the sell stall: you hold a tiny copy of it in your hand",
				"8 bases per server, and two conveyor belts down the middle of the lobby: one to the biomes, one back to the bases",
				"12 treadmills, from Rusty to the Heavenly treadmill",
				"A sell stall in the lobby, and a free bat for everyone: hit a thief to make them drop their box",
				"The Index has a Claim All button",
				"No more base locks, raids, rebirths or shop items",
			} },
		},
		Sidebar = {
			{ Title = "Box Donuts", Items = donuts({ "pufferino", "cocobombo", "magmazilla", "toysoldier", "nebulini", "gravitoni" }) },
		},
	},
	{
		Version = 5,
		Name = "The Eternal Storm",
		Date = "Oct 3, 2026",
		Color = Color3.fromRGB(45, 20, 85),
		Accent = Color3.fromRGB(215, 160, 255),
		Decor = "Stars",
		Emblem = { Frosting = Color3.fromRGB(190, 100, 255), Sprinkles = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(235, 200, 255), Color3.fromRGB(120, 40, 230) }, Dough = Color3.fromRGB(45, 15, 70) },
		Sections = {
			{ Title = "Eternal Storm", Tag = "NEW Event", Lines = {
				"The rarest event ever: a giant black hole tears open the sky!",
				"Purple lightning strikes donuts in every world and makes them ETERNAL (x50 money!)",
				"Huge rocks crash down from the sky: get out of the purple circle or you'll be flung!",
				"It comes with its own song: the Radetzky March",
			} },
			{ Title = "Open Bases", Tag = "NEW", Lines = {
				"Bases are big open pens now, like Steal an Egg",
				"Your donuts are alive: they walk around their pen, hop, wave and look around",
				"Make your base bigger in the Shop to fit more donuts (you keep every donut you had)",
				"6 bases per server, with lots more room between them",
				"Everyone's avatar and name float above their base",
			} },
			{ Title = "Wild Effects", Tag = "NEW Looks", Lines = {
				"Legendary and up get flames, spirals, crystal shards and electric sparks",
				"Secret, Admin and Icon donuts are a storm of lightning and shards",
				"Early donuts look clean and simple",
			} },
			{ Title = "Rarer Finds", Tag = "Balance", Lines = {
				"The best donut of every area spawns less often",
				"Mutations are about half as common: finding one really means something",
			} },
			{ Title = "Bigger World", Tag = "NEW", Lines = {
				"Every area is longer and wider",
				"Grassy rocky hills around the lobby walls",
			} },
			{ Title = "Domer", Tag = "Improvements", Lines = {
				"Getting caught flings you, but you're not sent back to your base any more",
				"His Z's are much bigger",
			} },
			{ Title = "Fair Leaderboards", Tag = "Improvements", Lines = {
				"Admins don't show up on the global leaderboards",
				"The player list's Money / Speed columns never swap any more",
			} },
		},
		Sidebar = {
			{ Title = "Wildest Effects", Items = donuts({ "fakekar", "grandeglazzarino", "adminglazino", "nebulini", "tungfudgur" }) },
		},
	},
	{
		Version = 4,
		Name = "Faster Progress",
		Date = "Oct 1, 2026",
		Color = Color3.fromRGB(30, 110, 60),
		Accent = Color3.fromRGB(255, 220, 90),
		Decor = "Rise",
		Emblem = { Frosting = Color3.fromRGB(130, 235, 140), Sprinkles = { Color3.fromRGB(255, 215, 60), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 245, 170) } },
		Sections = {
			{ Title = "Chases", Tag = "NEW", Lines = {
				"You now carry stolen donuts in your arms",
				"Intense music plays while Domer chases you",
				"Sleeping Domers have their eyes closed",
			} },
			{ Title = "Head Start", Tag = "Balance", Lines = {
				"The treadmill gives x4 Speed when you're just starting, slowly fading by Area 6",
				"Area 2 takes about 4 minutes of running instead of 15!",
				"Everyone now starts at 18 walk speed (was 16)",
			} },
			{ Title = "New Tutorial", Tag = "NEW", Lines = {
				"Follow the red arrow to learn the game step by step",
				"Finish it to claim a free egg!",
			} },
			{ Title = "Every Donut Is Unique", Tag = "NEW Looks", Lines = {
				"Every donut got details that match its name: Tick Tock has a clock, Volcanito a volcano, Wifinut wifi, Banhammer a giant hammer...",
				"Donuts carry their home area's theme: lava cracks, circuits, icicles, stars, slime and more",
				"Nine pets got new details too: drone rotors, a jester hat, a tiki mask, a treasure crate...",
			} },
			{ Title = "New Update Log", Tag = "NEW", Lines = {
				"Shows every time you join, themed to each update",
				"Hover any card on the right (tap on phones) to see its stats, odds and how to get it",
			} },
			{ Title = "Less Lag", Tag = "Performance", Lines = {
				"Far-away areas, worlds and bases aren't drawn until you get close",
				"Far-away donuts on bases skip their tiniest details",
				"Half as many shadows, lighter lighting and calmer particles",
				"Way fewer particles everywhere",
				"Empty areas stop re-rolling their donuts, so there's less to download",
				"Grabbing a donut no longer stutters on phones: your device draws the donut in your arms itself",
				"Running down the lane is smoother: areas appear bit by bit and far donuts move less often",
			} },
			{ Title = "Studded Donuts", Tag = "NEW Looks", Lines = {
				"Every donut is now built from classic studded blocks, just like Domer!",
			} },
			{ Title = "Bigger Lanes", Tag = "Balance", Lines = {
				"Every area is longer and a bit wider (same number of donuts)",
				"You start at 24 walk speed, and the first Domers speed up to match",
				"New chase music: a heartbeat that speeds up the longer Domer chases you (soft, not too loud)",
			} },
			{ Title = "Brighter Graphics", Tag = "NEW Looks", Lines = {
				"Sunnier, more colourful lighting with puffy 3D clouds",
				"Neon and fire glow, far-away places fade into a soft blue haze",
			} },
			{ Title = "Loading Screen", Tag = "NEW", Lines = {
				"A brand new loading screen with tips while the game loads",
				"Don't want to wait? Press SKIP!",
			} },
			{ Title = "Sleepy Domer", Tag = "NEW", Lines = {
				"Domer really sleeps now: eyes shut, head on a pillow, one arm over his head",
				"Z's float out of his mouth and you can hear him snore when you sneak close",
				"Grab a donut and he wakes up with an angry grunt!",
				"Donuts in the lane hop, blink and watch you walk by",
			} },
			{ Title = "Cleaner Buttons", Tag = "Improvements", Lines = {
				"Shiny new cartoon icons on every button",
				"Music on/off, next song and volume are now in Settings",
				"No more Worlds button: walk through the portals in the hub (Teleporter owners get a TELEPORT button)",
			} },
			{ Title = "Hide UI", Tag = "NEW", Lines = {
				"Press X (or the HIDE UI button) to clear the screen for screenshots",
				"Press X again or tap SHOW UI to bring it all back",
			} },
			{ Title = "Softer Sounds", Tag = "Improvements", Lines = {
				"Buttons click like a soft mechanical keyboard",
				"New gentle chimes for messages, rare finds and server events",
			} },
			{ Title = "Domer Hit The Gym", Tag = "NEW Looks", Lines = {
				"Domer is now built from chunky studded blocks, pixel style",
				"He's also way more buff: big shoulders, biceps and a six-pack",
			} },
			{ Title = "Admin Donuts", Tag = "Balance", Lines = {
				"Admin donuts no longer spawn in the lane: only the admin panel can make them",
			} },
			{ Title = "Calmer Bases", Tag = "Improvements", Lines = {
				"Rare donuts on bases glow softer, so every donut is easy to see",
			} },
			{ Title = "Purchases", Tag = "Fixes", Lines = {
				"Boosts and Robux purchases are more reliable and never get lost",
			} },
		},
		Sidebar = {
			{ Title = "Unique Looks", Items = donuts({ "ticktock", "volcanito", "banhammer", "wifinut", "crabbo", "missingno" }) },
			{ Title = "Free Tutorial Egg", Items = { { Kind = "Egg", Id = "Sprinkle", Note = "Free for finishing the tutorial!" } } },
		},
	},
	{
		Version = 3,
		Name = "The Underworld",
		Date = "Oct 1, 2026",
		Color = Color3.fromRGB(120, 25, 10),
		Accent = Color3.fromRGB(255, 170, 50),
		Decor = "Embers",
		Emblem = { Frosting = Color3.fromRGB(255, 110, 20), Dough = Color3.fromRGB(80, 40, 30), Sprinkles = { Color3.fromRGB(255, 220, 60), Color3.fromRGB(255, 60, 0), Color3.fromRGB(40, 30, 30) } },
		Sections = {
			{ Title = "The Underworld", Tag = "NEW World", Lines = {
				"Glaze Islands is gone: World 2 is now The Underworld!",
				"Cross a basalt bridge over a sea of lava to get there",
			} },
			{ Title = "7 Fiery Levels", Tag = "NEW Levels", Lines = {
				"Ember Gates, Brimstone Bakery, Magma Rivers and Soul Caverns",
				"Obsidian Forge, Inferno Spires and The Molten Core",
			} },
			{ Title = "Living Lava", Tag = "NEW Effects", Lines = {
				"Lava glows and churns, geysers erupt and lava pours down the walls",
				"Warm, flickering firelight all through The Underworld",
			} },
			{ Title = "Underworld Donuts", Tag = "New Looks", Lines = {
				"Every World 2 donut got a fiery new look and name, even the ones you already own",
				"The World 2 Secret is now Hadesnut Supremo!",
			} },
		},
		Sidebar = {
			{ Title = "Underworld Donuts", Items = donuts({ "poseidonut", "templeking", "lagunamax", "junglejelly", "crabbo", "pufferino" }) },
		},
	},
	{
		Version = 2,
		Name = "The Black Hole",
		Date = "Sep 30, 2026",
		Color = Color3.fromRGB(70, 30, 140),
		Accent = Color3.fromRGB(255, 170, 60),
		Decor = "Stars",
		Emblem = { Frosting = Color3.fromRGB(120, 70, 230), Sprinkles = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 170, 60), Color3.fromRGB(120, 200, 255) } },
		Sections = {
			{ Title = "The Black Hole", Tag = "NEW Area", Lines = {
				"A huge, wide new level at the end of Cyber City",
				"A giant black hole is tearing a star apart in the sky above it",
				"Its guard, Event Horizon, is the fastest yet!",
			} },
			{ Title = "7 New Donuts", Tag = "NEW Donuts", Lines = {
				"Seven space donuts live in The Black Hole",
				"Including a new Secret: Wormholio Infinitoni",
			} },
			{ Title = "Icon Rarity", Tag = "NEW Rarity", Lines = {
				"The rarest rarity in the game, with a glowing blue title",
				"The first Icon donut is Fake Kar!",
			} },
			{ Title = "The Secret Lab", Tag = "NEW Secret", Lines = {
				"Rumour says there's a hidden room somewhere in The Black Hole...",
				"...with a big red button. Don't press it.",
			} },
			{ Title = "World 2", Tag = "NEW World", Lines = {
				"A galactic world under a starry sky",
				"Donuts there are rarer, but make 2x money",
			} },
			{ Title = "2 New Treadmills", Tag = "NEW Upgrades", Lines = {
				"Two more treadmill levels to get even faster",
			} },
			{ Title = "Boosts", Tag = "Shop", Lines = {
				"Passes are now called Boosts",
			} },
			{ Title = "Look & Feel", Tag = "Improvements", Lines = {
				"Better lighting, calmer glow and colour-matched fog",
				"New steal sounds, a How to Play guide and new music",
			} },
		},
		Sidebar = {
			{ Title = "7 New Donuts", Items = donuts({ "fakekar", "wormholio", "supermassivo", "quasarino", "gravitoni", "eventhorizonte", "singularino" }) },
		},
	},
	{
		Version = 1,
		Name = "The Glow Up",
		Date = "Sep 29, 2026",
		Color = Color3.fromRGB(150, 40, 110),
		Accent = Color3.fromRGB(255, 200, 80),
		Decor = "Sparkles",
		Emblem = { Frosting = Color3.fromRGB(255, 140, 200), Sprinkles = { Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 200, 0), Color3.fromRGB(60, 220, 90), Color3.fromRGB(40, 150, 255), Color3.fromRGB(255, 255, 255) } },
		Sections = {
			{ Title = "New Looks", Tag = "Models", Lines = {
				"Every donut, pet and egg got a brand new look",
			} },
			{ Title = "Livelier Donuts", Tag = "NEW Animations", Lines = {
				"Donuts on your base look around, blink and react to you",
			} },
			{ Title = "Crates", Tag = "Fix", Lines = {
				"Crates bought with Robux open right away",
			} },
			{ Title = "Bases", Tag = "NEW Floors", Lines = {
				"Glass base buildings with a third floor",
			} },
		},
		Sidebar = {
			{ Title = "New Looks", Items = donuts({ "sprinkolini", "glazamun", "tungfudgur", "dragonini" }) },
			{ Title = "New Pet Looks", Items = { { Kind = "Pet", Id = "NebulaCat" }, { Kind = "Pet", Id = "LavaDragon" }, { Kind = "Egg", Id = "Sprinkle" } } },
		},
	},
} :: { Update }

UpdateNotes.Latest = UpdateNotes.List[1].Version

function UpdateNotes.Get(version: number): Update?
	for _, update in UpdateNotes.List do
		if update.Version == version then
			return update
		end
	end
	return nil
end

return UpdateNotes
