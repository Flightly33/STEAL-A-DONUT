--[[
	FXThemes: the mystical effect sets for the rarest donuts. A donut can have one from its rarity
	and one from its mutation, and gets both (a Secret with the Mythic mutation is Void + Hellfire).

	The server builds the parts that just need to exist (fire, smoke, particle vortexes, light rays:
	see DonutModel), and every client animates the rest near its camera (client/DonutFX.luau):
	  Lightning -> bolts every Min..Max seconds. Mode: "Arc" (crackles around the donut),
	               "Rise" (from the ground up into it), "Strike" (down from the sky, with a shockwave)
	  Runes     -> glowing magic circle on the ground that slowly turns
	  Wisps     -> glowing comets with trails orbiting the donut
	  Shockwave -> a ring that bursts out along the ground every Min..Max seconds
	  Pulse     -> how its light pulses: "Glow" | "Shimmer" | "Heartbeat" | "Hue"
	  Outline   -> a glowing outline (only the closest few, Roblox limits how many can show)
	  Tint      -> the donut itself changes colour: "Heartbeat" (throbs red) | "Galaxy" | "Rainbow"
	Rainbow themes cycle through every colour instead of using Colors.
]]

export type Theme = {
	Id: string,
	Colors: { Color3 },
	Rainbow: boolean?,
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

FXThemes.ById = {
	-- Rarities
	Radiance = { Id = "Radiance", Colors = { rgb(255, 215, 80), rgb(255, 245, 190) }, Pulse = "Glow" },
	Starlight = { Id = "Starlight", Colors = { rgb(255, 150, 240), rgb(140, 220, 255), rgb(255, 255, 255) }, Runes = true, Wisps = 3, Pulse = "Shimmer" },
	Void = {
		Id = "Void",
		Colors = { rgb(190, 110, 255), rgb(90, 220, 255), rgb(255, 90, 200) },
		Rainbow = true,
		Lightning = { Min = 0.35, Max = 1.1, Mode = "Arc" },
		Runes = true,
		Wisps = 5,
		Shockwave = { Min = 2.5, Max = 4.5 },
		Pulse = "Hue",
		Outline = true,
		Tint = "Galaxy",
	},
	-- Mutations
	Treasure = { Id = "Treasure", Colors = { rgb(255, 215, 60), rgb(255, 250, 200) }, Pulse = "Glow" },
	Glitter = { Id = "Glitter", Colors = { rgb(160, 240, 255), rgb(255, 255, 255) }, Wisps = 3, Pulse = "Shimmer" },
	Hellfire = {
		Id = "Hellfire",
		Colors = { rgb(255, 40, 30), rgb(255, 140, 20), rgb(150, 0, 20) },
		Lightning = { Min = 0.6, Max = 1.6, Mode = "Rise" },
		Runes = true,
		Pulse = "Heartbeat",
		Outline = true,
		Tint = "Heartbeat",
	},
	Holy = {
		Id = "Holy",
		Colors = { rgb(255, 230, 130), rgb(255, 255, 240), rgb(255, 200, 90) },
		Lightning = { Min = 1.8, Max = 3.5, Mode = "Strike" },
		Runes = true,
		Wisps = 3,
		Pulse = "Shimmer",
		Outline = true,
	},
	Prism = {
		Id = "Prism",
		Colors = { rgb(255, 80, 80), rgb(80, 255, 120), rgb(90, 150, 255) },
		Rainbow = true,
		Lightning = { Min = 0.8, Max = 2, Mode = "Arc" },
		Runes = true,
		Wisps = 4,
		Pulse = "Hue",
		Outline = true,
		Tint = "Rainbow",
	},
} :: { [string]: Theme }

local BY_RARITY: { [string]: string } = { Legendary = "Radiance", Celestial = "Starlight", Secret = "Void" }
local BY_MUTATION: { [string]: string } = { Gold = "Treasure", Diamond = "Glitter", Mythic = "Hellfire", Divine = "Holy", Rainbow = "Prism" }

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
