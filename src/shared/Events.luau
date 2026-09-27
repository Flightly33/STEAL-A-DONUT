--[[
	Area events: every few minutes (Config.Events) one area gets special weather for a while.
	During an event every donut that spawns in that area rolls mutations with extra luck, and the
	area's donuts are all re-rolled the moment it starts, so it's worth running over there.

	Luck  -> multiplies every mutation chance
	Boost -> one mutation gets an extra x5 on top (Golden Hour -> Gold, Blizzard -> Diamond ...)
	Weather is the client-side effect: particles, fog colour and a tint.
]]

export type Event = {
	Id: string,
	Name: string,
	Icon: string,
	Themes: { string }, -- area themes where it can happen ("Any" = everywhere, as a rare roll)
	Luck: number,
	Boost: string?,
	Weather: string, -- Sand | Snow | Rain | Embers | Bubbles | Sparkles | Stars | Confetti | Ghosts | Coins | Leaves | Rainbow
	Color: Color3,
	Tint: Color3,
	Fog: number, -- extra atmosphere density (0 = none)
	Description: string,
}

local rgb = Color3.fromRGB

local Events = {}

Events.List = {
	{ Id = "GoldenHour", Name = "Golden Hour", Icon = "🌅", Themes = { "Meadow", "Park", "Beach", "Heaven" }, Luck = 2, Boost = "Gold", Weather = "Sparkles", Color = rgb(255, 205, 60), Tint = rgb(255, 232, 190), Fog = 0, Description = "Gold mutations are everywhere!" },
	{ Id = "Sandstorm", Name = "Sandstorm", Icon = "🌪️", Themes = { "Desert" }, Luck = 3, Boost = nil, Weather = "Sand", Color = rgb(230, 190, 120), Tint = rgb(255, 225, 175), Fog = 0.45, Description = "Hard to see... but mutations are 3x more likely!" },
	{ Id = "SprinkleShower", Name = "Sprinkle Shower", Icon = "🌈", Themes = { "Park", "Frosting", "Toys" }, Luck = 3, Boost = nil, Weather = "Confetti", Color = rgb(255, 120, 200), Tint = rgb(255, 240, 250), Fog = 0, Description = "It's raining sprinkles! 3x mutation luck." },
	{ Id = "ChocolateRain", Name = "Chocolate Rain", Icon = "🍫", Themes = { "Chocolate" }, Luck = 3, Boost = nil, Weather = "Rain", Color = rgb(120, 70, 40), Tint = rgb(230, 205, 185), Fog = 0.25, Description = "Chocolate rain! 3x mutation luck." },
	{ Id = "Blizzard", Name = "Blizzard", Icon = "❄️", Themes = { "Ice" }, Luck = 2, Boost = "Diamond", Weather = "Snow", Color = rgb(170, 230, 255), Tint = rgb(220, 240, 255), Fog = 0.4, Description = "Diamond donuts freeze into existence!" },
	{ Id = "Eruption", Name = "Eruption", Icon = "🌋", Themes = { "Lava", "Volcano" }, Luck = 2, Boost = "Mythic", Weather = "Embers", Color = rgb(255, 90, 30), Tint = rgb(255, 205, 180), Fog = 0.3, Description = "The volcano blows! Mythic donuts are way more common." },
	{ Id = "GlitchStorm", Name = "Glitch Storm", Icon = "👾", Themes = { "Neon", "Clockwork" }, Luck = 4, Boost = nil, Weather = "Sparkles", Color = rgb(0, 255, 200), Tint = rgb(220, 255, 245), Fog = 0.15, Description = "Reality is glitching! 4x mutation luck." },
	{ Id = "CrystalRain", Name = "Crystal Rain", Icon = "💎", Themes = { "Crystal", "Coral" }, Luck = 2, Boost = "Diamond", Weather = "Sparkles", Color = rgb(170, 120, 255), Tint = rgb(235, 220, 255), Fog = 0, Description = "Crystals are falling! Diamond mutations x5." },
	{ Id = "MeteorShower", Name = "Meteor Shower", Icon = "☄️", Themes = { "Celestial", "Clouds" }, Luck = 3, Boost = "Divine", Weather = "Stars", Color = rgb(255, 200, 120), Tint = rgb(255, 230, 245), Fog = 0, Description = "Shooting stars! Divine donuts are falling from the sky." },
	{ Id = "BubbleSurge", Name = "Bubble Surge", Icon = "🫧", Themes = { "Coral", "Beach" }, Luck = 3, Boost = nil, Weather = "Bubbles", Color = rgb(120, 220, 255), Tint = rgb(215, 240, 255), Fog = 0.2, Description = "Bubbles everywhere! 3x mutation luck." },
	{ Id = "TreasureTide", Name = "Treasure Tide", Icon = "🏴‍☠️", Themes = { "Pirate" }, Luck = 2, Boost = "Gold", Weather = "Coins", Color = rgb(255, 210, 60), Tint = rgb(255, 238, 200), Fog = 0, Description = "The tide washed up treasure: Gold donuts x5!" },
	{ Id = "Monsoon", Name = "Monsoon", Icon = "🌧️", Themes = { "Jungle", "Clouds" }, Luck = 3, Boost = nil, Weather = "Rain", Color = rgb(120, 170, 255), Tint = rgb(210, 225, 245), Fog = 0.35, Description = "A tropical downpour! 3x mutation luck." },
	{ Id = "BloodMoon", Name = "Blood Moon", Icon = "🌕", Themes = { "Haunted", "Chocolate" }, Luck = 2, Boost = "Mythic", Weather = "Ghosts", Color = rgb(255, 60, 70), Tint = rgb(255, 190, 190), Fog = 0.3, Description = "The blood moon rises... Mythic donuts x5!" },
	{ Id = "DivineLight", Name = "Divine Light", Icon = "✨", Themes = { "Heaven", "Crystal" }, Luck = 2, Boost = "Divine", Weather = "Sparkles", Color = rgb(255, 250, 210), Tint = rgb(255, 250, 230), Fog = 0, Description = "Heavenly light! Divine donuts x5." },
	{ Id = "LeafFall", Name = "Falling Leaves", Icon = "🍂", Themes = { "Meadow", "Jungle", "Haunted" }, Luck = 3, Boost = nil, Weather = "Leaves", Color = rgb(255, 150, 60), Tint = rgb(255, 240, 220), Fog = 0, Description = "Autumn breeze! 3x mutation luck." },
	-- Rare: can happen anywhere
	{ Id = "RainbowRush", Name = "Rainbow Rush", Icon = "🌈", Themes = { "Any" }, Luck = 3, Boost = "Rainbow", Weather = "Rainbow", Color = rgb(255, 120, 255), Tint = rgb(255, 240, 255), Fog = 0, Description = "RAINBOW RUSH! Rainbow donuts x5 and every mutation x3!" },
} :: { Event }

Events.ById = {} :: { [string]: Event }
for _, event in Events.List do
	Events.ById[event.Id] = event
end

Events.RareChance = 0.08 -- chance an event is one of the "Any" events instead of a themed one

-- Pick an event for an area theme.
function Events.Pick(theme: string, rng: Random): Event
	local themed, anywhere = {}, {}
	for _, event in Events.List do
		for _, t in event.Themes do
			if t == theme then
				table.insert(themed, event)
			elseif t == "Any" then
				table.insert(anywhere, event)
			end
		end
	end
	if #anywhere > 0 and (#themed == 0 or rng:NextNumber() < Events.RareChance) then
		return anywhere[rng:NextInteger(1, #anywhere)]
	end
	if #themed == 0 then
		return Events.List[1]
	end
	return themed[rng:NextInteger(1, #themed)]
end

return Events
