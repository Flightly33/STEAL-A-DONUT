--[[
	FXThemes: the building blocks of the donuts' magic effects, and the effect sets of the mutations
	(Gold, Diamond, Mythic, Divine, Rainbow, Eternal).

	Every Epic-and-up donut gets its OWN signature aura made from these blocks (DonutAuras.luau
	picks them from the donut's name); a mutation adds its set on top.

	The server builds the parts that just need to exist (particle emitters, light rays: see
	DonutModel), and every client animates the rest near its camera (client/DonutFX.luau):
	  Flames    -> fire licking up all round the donut (colours, bottom to top)
	  Swirl     -> big glowing spirals turning around it
	  Smoke     -> a dark aura rising off it (colour)
	  Electric  -> crackling bursts of electric sparks all over it (Rate bursts a second)
	  Shards    -> jagged crystal shards tumbling round it, flying out and back (Count of them)
	  Orbiters  -> little shapes circling it (client): Heart, Star, Coin, Bubble, Cube, Note, Leaf,
	               Snowflake, Gear, Bolt, Feather
	  Lightning -> bolts every Min..Max seconds. Mode: "Arc" (crackles around the donut),
	               "Rise" (from the ground up into it), "Strike" (down from the sky, with a shockwave)
	  Runes     -> glowing magic circle on the ground that slowly turns
	  Wisps     -> glowing comets with trails orbiting the donut
	  Shockwave -> a ring that bursts out along the ground every Min..Max seconds
	  Rays      -> light rays fanning out behind it, slowly turning
	  GodRays   -> rays of light shining down on it from the sky, specks drifting down
	  Stars     -> stars popping in and out all round it
	  Vortex    -> particles rushing in towards it; Glitter: bursting out of it
	  Drift     -> particles drifting round it: "Fall" (snow, petals, feathers), "Rise" (embers,
	               bubbles, steam), "Burst" (confetti), "Streak" (speed lines flying back)
	  Mist      -> a soft haze of light rising round it (colour)
	  Crystals  -> glowing crystals growing out of the ground round it
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
	Orbiters: { Shape: string, Count: number }?,
	Rays: { Count: number, Length: number, Spin: number }?,
	GodRays: boolean?,
	Stars: { Rate: number, Radius: number }?,
	Vortex: { Rate: number, Radius: number }?,
	Glitter: { Rate: number, Radius: number }?,
	Drift: { Mode: string, Rate: number, Size: number, Texture: string }?,
	Mist: Color3?,
	Crystals: boolean?,
	DriftColors: { Color3 }?,
	Elements: { string }?, -- (a signature aura: the elements it came from)
}

local rgb = Color3.fromRGB

local FXThemes = {}

local WHITE = rgb(255, 255, 255)

FXThemes.ById = {
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

local BY_MUTATION: { [string]: string } = { Gold = "Treasure", Diamond = "Glitter", Mythic = "Hellfire", Divine = "Holy", Rainbow = "Prism", Eternal = "Eternal" }

-- A mutation's effect set (nil for none).
function FXThemes.ForMutation(mutationId: string?): Theme?
	local id = if mutationId then BY_MUTATION[mutationId] else nil
	return if id then FXThemes.ById[id] else nil
end

return FXThemes
