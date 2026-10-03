--[[
	FXThemes: the effect sets for the mid-to-late game donuts (Legendary and up, and the Mythic /
	Divine / Rainbow / Eternal mutations). Early donuts (Common - Epic, Gold / Diamond) stay
	simple; from Legendary on every rarity gets wilder. A donut can have one theme from its rarity
	and one from its mutation, and gets both (a Secret with the Mythic mutation is Void + Hellfire).

	The server builds the parts that just need to exist (particle emitters, light rays: see
	DonutModel), and every client animates the rest near its camera (client/DonutFX.luau):
	  Flames    -> fire licking up all round the donut (colours, bottom to top)
	  Swirl     -> big glowing spirals turning around it
	  Smoke     -> a dark aura rising off it (colour)
	  Electric  -> crackling bursts of electric sparks all over it (Rate bursts a second)
	  Shards    -> jagged crystal shards tumbling round it, flying out and back (Count of them)
	  Lightning -> bolts every Min..Max seconds. Mode: "Arc" (crackles around the donut),
	               "Rise" (from the ground up into it), "Strike" (down from the sky, with a shockwave)
	  Runes     -> glowing magic circle on the ground that slowly turns
	  Wisps     -> glowing comets with trails orbiting the donut
	  Shockwave -> a ring that bursts out along the ground every Min..Max seconds
	  Pulse     -> how its light pulses: "Glow" | "Shimmer" | "Heartbeat" | "Hue" | "Throb"
	  Outline   -> a glowing outline (only the closest few, Roblox limits how many can show)
	  Tint      -> the donut itself changes colour: "Heartbeat" (throbs red) | "Galaxy" | "Rainbow"
	Rainbow themes cycle through every colour instead of using Colors.
	The particle textures are Roblox's own (always there); Config.DonutFX.Textures can swap in
	any Creator Store particle texture instead.
]]

export type Theme = {
	Id: string,
	Colors: { Color3 },
	Rainbow: boolean?,
	Flames: { Color3 }?,
	Swirl: boolean?,
	Smoke: Color3?,
	Electric: { Rate: number, Colors: { Color3 } }?,
	Shards: { Count: number, Colors: { Color3 } }?,
	Lightning: { Min: number, Max: number, Mode: string }?,
	Runes: boolean?,
	Wisps: number?,
	Shockwave: { Min: number, Max: number }?,
	Pulse: string?,
	Outline: boolean?,
	Tint: string?,
}

local rgb = Color3.fromRGB

local FXThemes = {}

local WHITE = rgb(255, 255, 255)

FXThemes.ById = {
	-- Rarities
	-- Legendary: golden flames and embers, light rays turning behind it
	Radiance = {
		Id = "Radiance",
		Colors = { rgb(255, 215, 80), rgb(255, 245, 190) },
		Flames = { rgb(255, 240, 150), rgb(255, 170, 40), rgb(255, 90, 20) },
		Pulse = "Glow",
	},
	-- Celestial: pink and blue spirals, crystal shards, stars, a magic circle and comets
	Starlight = {
		Id = "Starlight",
		Colors = { rgb(255, 150, 240), rgb(140, 220, 255), WHITE },
		Swirl = true,
		Shards = { Count = 6, Colors = { rgb(255, 170, 245), rgb(150, 225, 255) } },
		Runes = true,
		Wisps = 3,
		Pulse = "Shimmer",
	},
	-- Secret: a corrupted void - dark purple shards and smoke, white electric bursts, galaxy dough
	Void = {
		Id = "Void",
		Colors = { rgb(190, 110, 255), rgb(90, 220, 255), rgb(255, 90, 200) },
		Rainbow = true,
		Smoke = rgb(60, 20, 110),
		Electric = { Rate = 3, Colors = { WHITE, rgb(210, 160, 255) } },
		Shards = { Count = 12, Colors = { rgb(150, 60, 255), rgb(30, 10, 50), rgb(210, 150, 255) } },
		Lightning = { Min = 0.35, Max = 1.1, Mode = "Arc" },
		Runes = true,
		Wisps = 5,
		Shockwave = { Min = 2.5, Max = 4.5 },
		Pulse = "Hue",
		Outline = true,
		Tint = "Galaxy",
	},
	-- Admin: red overload - crimson and black shards, red flames, black smoke, red lightning
	Overload = {
		Id = "Overload",
		Colors = { rgb(255, 40, 40), rgb(255, 255, 255), rgb(120, 0, 0) },
		Flames = { rgb(255, 120, 90), rgb(255, 30, 30), rgb(90, 0, 0) },
		Smoke = rgb(25, 0, 0),
		Electric = { Rate = 3, Colors = { rgb(255, 80, 80), WHITE } },
		Shards = { Count = 12, Colors = { rgb(255, 30, 40), rgb(20, 5, 5), rgb(255, 160, 160) } },
		Lightning = { Min = 0.4, Max = 1.2, Mode = "Rise" },
		Runes = true,
		Shockwave = { Min = 2.5, Max = 4 },
		Pulse = "Heartbeat",
		Outline = true,
	},
	-- Icon: a blue nova - huge white electric bursts, blue shards, strikes from the sky
	Nova = {
		Id = "Nova",
		Colors = { rgb(40, 140, 255), rgb(140, 220, 255), WHITE },
		Swirl = true,
		Electric = { Rate = 5, Colors = { WHITE, rgb(140, 220, 255) } },
		Shards = { Count = 14, Colors = { rgb(60, 150, 255), rgb(200, 240, 255), rgb(10, 30, 80) } },
		Lightning = { Min = 0.4, Max = 1.2, Mode = "Strike" },
		Runes = true,
		Wisps = 6,
		Shockwave = { Min = 2, Max = 3.5 },
		Pulse = "Shimmer",
		Outline = true,
	},
	-- Mutations
	Treasure = { Id = "Treasure", Colors = { rgb(255, 215, 60), rgb(255, 250, 200) }, Pulse = "Glow" },
	Glitter = { Id = "Glitter", Colors = { rgb(160, 240, 255), WHITE }, Pulse = "Shimmer" },
	-- Mythic: hellfire - roaring red flames, embers, bolts rising out of the ground
	Hellfire = {
		Id = "Hellfire",
		Colors = { rgb(255, 40, 30), rgb(255, 140, 20), rgb(150, 0, 20) },
		Flames = { rgb(255, 200, 80), rgb(255, 60, 20), rgb(120, 0, 10) },
		Shards = { Count = 6, Colors = { rgb(255, 60, 30), rgb(40, 5, 5) } },
		Lightning = { Min = 0.6, Max = 1.6, Mode = "Rise" },
		Runes = true,
		Pulse = "Heartbeat",
		Outline = true,
		Tint = "Heartbeat",
	},
	-- Divine: god rays from the sky, golden spirals and white electric sparks
	Holy = {
		Id = "Holy",
		Colors = { rgb(255, 230, 130), rgb(255, 255, 240), rgb(255, 200, 90) },
		Swirl = true,
		Electric = { Rate = 2, Colors = { WHITE, rgb(255, 230, 140) } },
		Lightning = { Min = 1.8, Max = 3.5, Mode = "Strike" },
		Runes = true,
		Wisps = 3,
		Pulse = "Shimmer",
		Outline = true,
	},
	-- Rainbow: every colour at once - rainbow spirals, shards and sparks
	Prism = {
		Id = "Prism",
		Colors = { rgb(255, 80, 80), rgb(80, 255, 120), rgb(90, 150, 255) },
		Rainbow = true,
		Swirl = true,
		Electric = { Rate = 2, Colors = { WHITE } },
		Shards = { Count = 8, Colors = { rgb(255, 80, 80), rgb(255, 230, 60), rgb(80, 255, 120), rgb(90, 150, 255), rgb(200, 90, 255) } },
		Lightning = { Min = 0.8, Max = 2, Mode = "Arc" },
		Runes = true,
		Wisps = 4,
		Pulse = "Hue",
		Outline = true,
		Tint = "Rainbow",
	},
	-- Eternal (Eternal Storm only): a purple glow and a storm of purple lightning all round it
	Eternal = {
		Id = "Eternal",
		Colors = { rgb(180, 80, 255), rgb(235, 200, 255), rgb(110, 20, 220) },
		Swirl = true,
		Smoke = rgb(70, 10, 140),
		Electric = { Rate = 6, Colors = { rgb(225, 170, 255), WHITE, rgb(170, 60, 255) } },
		Shards = { Count = 10, Colors = { rgb(170, 60, 255), rgb(35, 5, 60), rgb(230, 190, 255) } },
		Lightning = { Min = 0.15, Max = 0.5, Mode = "Arc" },
		Runes = true,
		Wisps = 4,
		Shockwave = { Min = 2, Max = 3.5 },
		Pulse = "Throb",
		Outline = true,
	},
} :: { [string]: Theme }

local BY_RARITY: { [string]: string } = { Legendary = "Radiance", Celestial = "Starlight", Secret = "Void", Admin = "Overload", Icon = "Nova" }
local BY_MUTATION: { [string]: string } = { Gold = "Treasure", Diamond = "Glitter", Mythic = "Hellfire", Divine = "Holy", Rainbow = "Prism", Eternal = "Eternal" }

-- The effect themes of a donut (rarity theme first, then its mutation's).
function FXThemes.For(rarityId: string, mutationId: string?): { Theme }
	local themes = {}
	local fromRarity = BY_RARITY[rarityId]
	if fromRarity then
		table.insert(themes, FXThemes.ById[fromRarity])
	end
	local fromMutation = if mutationId then BY_MUTATION[mutationId] else nil
	if fromMutation then
		table.insert(themes, FXThemes.ById[fromMutation])
	end
	return themes
end

return FXThemes
