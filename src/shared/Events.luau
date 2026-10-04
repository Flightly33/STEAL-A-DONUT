--[[
	Server events: every few minutes (Config.Events) ONE event starts for the whole server. Only one
	runs at a time. Everyone gets a big announcement and a countdown at the top of the screen.

	Kinds:
	  Luck        every box that appears anywhere is better while it runs:
	                Rarity -> Epic and Legendary boxes are this much more likely
	                Luck   -> every mutation chance x this
	                Boost  -> one mutation gets an extra x5 on top (Golden Hour -> Gold ...)
	              and every biome's boxes are replaced the moment it starts.
	  RareRain    Box Rain: a rare box crashes down somewhere players can reach, one at a time,
	              every Config.Events.RareRainInterval seconds.
	  EggShower   every biome that can have eggs gets one, and a new one drops as soon as it's grabbed.
	  DoubleHatch every incubator hatches Config.Events.HatchBoost x as fast.
	  EternalStorm  the Eternal Storm (Config.EternalStorm): a black hole in the sky, falling rocks,
	              and purple lightning that turns boxes Eternal. Very rare; only the game's owner can
	              start it from the admin panel.

	Weight: how often it's picked compared to the others. Weather is the client-side effect.
]]

export type Event = {
	Id: string,
	Name: string,
	Icon: string,
	Kind: string, -- "Luck" | "RareRain" | "EggShower" | "DoubleHatch" | "EternalStorm"
	OwnerOnly: boolean?, -- only the game's owner can start it from the admin panel
	Weight: number,
	Luck: number, -- mutation luck (Luck events)
	Boost: string?, -- mutation with an extra x5
	Rarity: number, -- rare donut luck (1 = normal)
	Weather: string, -- Sand | Snow | Rain | Embers | Bubbles | Sparkles | Stars | Confetti | Ghosts | Coins | Leaves | Rainbow | Eggs | Void
	Color: Color3,
	Tint: Color3,
	Fog: number, -- extra haze (0 = none)
	Description: string,
}

local Config = require(script.Parent.Config)

local rgb = Color3.fromRGB

local Events = {}

local function E(id: string, name: string, icon: string, kind: string, weight: number, luck: number, boost: string?, rarity: number, weather: string, color: Color3, tint: Color3, fog: number, description: string): Event
	return {
		Id = id, Name = name, Icon = icon, Kind = kind, Weight = weight, Luck = luck, Boost = boost, Rarity = rarity,
		Weather = weather, Color = color, Tint = tint, Fog = fog, Description = description,
	}
end

Events.List = {
	-- Luck events: better boxes everywhere
	E("GoldenHour", "Golden Hour", "🌅", "Luck", 10, 2, "Gold", 2, "Sparkles", rgb(255, 205, 60), rgb(255, 232, 190), 0, "Gold boxes x5 and rare boxes x2 everywhere!"),
	E("SprinkleShower", "Sprinkle Shower", "🌈", "Luck", 10, 3, nil, 2, "Confetti", rgb(255, 120, 200), rgb(255, 240, 250), 0, "It's raining sprinkles! Mutations x3, rare boxes x2."),
	E("Sandstorm", "Sandstorm", "🌪️", "Luck", 6, 3, nil, 2, "Sand", rgb(230, 190, 120), rgb(255, 235, 200), 0.25, "Hard to see... but mutations x3 and rare boxes x2!"),
	E("ChocolateRain", "Chocolate Rain", "🍫", "Luck", 6, 3, nil, 2, "Rain", rgb(120, 70, 40), rgb(235, 215, 200), 0.15, "Chocolate rain! Mutations x3, rare boxes x2."),
	E("Blizzard", "Blizzard", "❄️", "Luck", 8, 2, "Diamond", 2, "Snow", rgb(170, 230, 255), rgb(225, 240, 255), 0.25, "Diamond boxes x5 and rare boxes x2 everywhere!"),
	E("Eruption", "Eruption", "🌋", "Luck", 7, 2, "Mythic", 2, "Embers", rgb(255, 90, 30), rgb(255, 210, 190), 0.15, "Mythic boxes x5 and rare boxes x2!"),
	E("GlitchStorm", "Glitch Storm", "👾", "Luck", 6, 4, nil, 2, "Sparkles", rgb(0, 255, 200), rgb(220, 255, 245), 0.1, "Reality is glitching! Mutations x4, rare boxes x2."),
	E("CrystalRain", "Crystal Rain", "💎", "Luck", 6, 2, "Diamond", 2, "Sparkles", rgb(170, 120, 255), rgb(235, 220, 255), 0, "Crystals are falling! Diamond boxes x5."),
	E("MeteorShower", "Meteor Shower", "☄️", "Luck", 5, 3, "Divine", 2, "Stars", rgb(255, 200, 120), rgb(255, 230, 245), 0, "Shooting stars! Divine boxes x5, mutations x3."),
	E("BubbleSurge", "Bubble Surge", "🫧", "Luck", 6, 3, nil, 2, "Bubbles", rgb(120, 220, 255), rgb(215, 240, 255), 0.1, "Bubbles everywhere! Mutations x3, rare boxes x2."),
	E("TreasureTide", "Treasure Tide", "🏴‍☠️", "Luck", 6, 2, "Gold", 2.5, "Coins", rgb(255, 210, 60), rgb(255, 238, 200), 0, "Treasure washed up: Gold boxes x5, rare boxes x2.5!"),
	E("BloodMoon", "Blood Moon", "🌕", "Luck", 5, 2, "Mythic", 2.5, "Ghosts", rgb(255, 60, 70), rgb(255, 195, 195), 0.15, "The blood moon rises... Mythic boxes x5, rare boxes x2.5!"),
	E("DivineLight", "Divine Light", "✨", "Luck", 4, 2, "Divine", 2, "Sparkles", rgb(255, 250, 210), rgb(255, 250, 230), 0, "Heavenly light! Divine boxes x5."),
	E("LeafFall", "Falling Leaves", "🍂", "Luck", 6, 3, nil, 2, "Leaves", rgb(255, 150, 60), rgb(255, 240, 220), 0, "Autumn breeze! Mutations x3, rare boxes x2."),
	E("RainbowRush", "Rainbow Rush", "🌈", "Luck", 2, 3, "Rainbow", 3, "Rainbow", rgb(255, 120, 255), rgb(255, 240, 255), 0, "RAINBOW RUSH! Rainbow boxes x5, mutations x3, rare boxes x3!"),
	-- Special events
	E("RareRain", "Box Rain", "☄️", "RareRain", 8, 1, nil, 1, "Stars", rgb(255, 170, 60), rgb(255, 235, 215), 0, "Rare boxes are crashing down from the sky, one at a time! Grab them first!"),
	E("EggShower", "Egg Shower", "🥚", "EggShower", 8, 1, nil, 1, "Eggs", rgb(255, 230, 150), rgb(255, 248, 230), 0, "Eggs are dropping in every biome! Grab them before they're gone!"),
	E("DoubleHatch", "2x Incubator Speed", "⚡", "DoubleHatch", 7, 1, nil, 1, "Sparkles", rgb(120, 255, 170), rgb(235, 255, 240), 0, "Every incubator hatches twice as fast!"),
	-- The rarest of all
	E("EternalStorm", "ETERNAL STORM", "🌌", "EternalStorm", Config.EternalStorm.Weight, 1, nil, 1, "Void", rgb(180, 80, 255), rgb(205, 175, 255), 0.2, "A black hole tears the sky open! Purple lightning makes boxes ETERNAL (x50 donuts)! Watch out for falling rocks!"),
} :: { Event }
for _, event in Events.List do
	if event.Kind == "EternalStorm" then
		event.OwnerOnly = true
	end
end

Events.ById = {} :: { [string]: Event }
for _, event in Events.List do
	Events.ById[event.Id] = event
end

-- Pick the next event (weighted). `except` = the one that just ran, so it doesn't repeat.
function Events.Pick(rng: Random, except: string?): Event
	local total = 0
	for _, event in Events.List do
		if event.Id ~= except then
			total += event.Weight
		end
	end
	local roll = rng:NextNumber() * total
	for _, event in Events.List do
		if event.Id ~= except then
			roll -= event.Weight
			if roll <= 0 then
				return event
			end
		end
	end
	return Events.List[1]
end

return Events
