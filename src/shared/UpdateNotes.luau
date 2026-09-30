--[[
	UpdateNotes: the Update Log players see the first time they join after an update (UI/UpdateNotes).

	PUBLISHING AN UPDATE? Add a new entry at the TOP of UpdateNotes.List with the next Version number.
	Everyone who joins after that sees it once (their save remembers the last Version they saw), unless
	they switched the log to "Hidden on login". Brand-new players get the how-to-play tutorial instead.
	The 📰 button in Settings shows every update any time.

	  Version  - goes up by one every update (1, 2, 3...)
	  Name     - the update's name, big under the game's logo
	  Date     - shown after "Update N Patch Notes"
	  Color    - the window's background colour; Accent - the headings' colour
	  Sections - the patch notes: a heading, a small tag under it and bullet lines
	             { Title = "The Black Hole", Tag = "NEW Area", Lines = { "...", "..." } }
	             (the box at the top lists every section's Title)
	  Sidebar  - groups of new things shown as spinning 3D cards, built from the game's own models (no
	             images to upload, so nothing for Roblox to moderate). Kind is "Donut", "Pet" or "Egg";
	             Id is the id in Donuts.luau / Pets.luau.
	             { Title = "7 New Donuts", Items = { { Kind = "Donut", Id = "fakekar" }, ... } }
]]

export type Item = { Kind: string, Id: string }
export type Section = { Title: string, Tag: string, Lines: { string } }
export type Group = { Title: string, Items: { Item } }
export type Update = {
	Version: number,
	Name: string,
	Date: string,
	Color: Color3,
	Accent: Color3,
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
		Version = 3,
		Name = "The Underworld",
		Date = "Oct 1, 2026",
		Color = Color3.fromRGB(120, 25, 10),
		Accent = Color3.fromRGB(255, 170, 50),
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
