--[[
	UpdateNotes: the Update Log that pops up every time a player joins (UI/UpdateNotes).

	PUBLISHING AN UPDATE? Add a new entry at the TOP of UpdateNotes.List with the next Version number.
	It shows on every join (a brand-new player's tutorial starts once they close it). The 📰 UPDATES
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
		Version = 4,
		Name = "Faster Rebirths",
		Date = "Oct 1, 2026",
		Color = Color3.fromRGB(30, 110, 60),
		Accent = Color3.fromRGB(255, 220, 90),
		Decor = "Rise",
		Emblem = { Frosting = Color3.fromRGB(130, 235, 140), Sprinkles = { Color3.fromRGB(255, 215, 60), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 245, 170) } },
		Sections = {
			{ Title = "Rebirths", Tag = "Balance", Lines = {
				"Rebirths are easier: less Speed and money needed",
				"No more rebirth limit: keep rebirthing forever!",
			} },
			{ Title = "Chases", Tag = "NEW", Lines = {
				"You now carry stolen donuts in your arms",
				"Intense music plays while Domer chases you",
				"Sleeping Domers have their eyes closed",
			} },
			{ Title = "Head Start", Tag = "Balance", Lines = {
				"The treadmill gives x4 Speed when you're just starting, slowly fading by Area 6",
				"Area 2 takes about 4 minutes of running instead of 15!",
				"It comes back after every rebirth too",
				"Everyone now starts at 18 walk speed (was 16)",
			} },
			{ Title = "Easier Rebirths", Tag = "Balance", Lines = {
				"Rebirths need half the Speed and far less money",
				"Every rebirth now gives +50% treadmill speed (was +25%)",
				"Reaching each new world takes about half as long",
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
			} },
			{ Title = "Loading Screen", Tag = "NEW", Lines = {
				"A brand new loading screen with tips while the game loads",
				"Don't want to wait? Press SKIP!",
			} },
			{ Title = "Hide UI", Tag = "NEW", Lines = {
				"Press X (or the 👁 HIDE UI button) to clear the screen for screenshots",
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
			{ Title = "Cosmic Donuts", Items = donuts({ "cosmic_glazzerina", "cosmic_sprinkolini", "cosmic_tradonut", "cosmic_glazamun" }) },
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
