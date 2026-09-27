--[[
	Rarities: order, colour and the visual effects a donut of that rarity gets.
	Effects:
		Shine      -> reflective, slightly glossy material
		Light      -> PointLight in the rarity colour
		Particles  -> particle aura (rate)
		Rainbow    -> frosting cycles through colours (client side)
		Float      -> donut bobs and spins (client side)
		Halo       -> glowing ring above the donut
		Beam       -> light pillar under the donut
]]

export type Rarity = {
	Id: string,
	Order: number,
	Color: Color3,
	Shine: boolean?,
	Light: number?,
	Particles: number?,
	Rainbow: boolean?,
	Float: boolean?,
	Halo: boolean?,
	Beam: boolean?,
}

local Rarities = {}

Rarities.List = {
	{ Id = "Common", Order = 1, Color = Color3.fromRGB(215, 215, 215) },
	{ Id = "Uncommon", Order = 2, Color = Color3.fromRGB(85, 225, 90) },
	{ Id = "Rare", Order = 3, Color = Color3.fromRGB(55, 150, 255), Shine = true },
	{ Id = "Epic", Order = 4, Color = Color3.fromRGB(190, 70, 255), Shine = true, Light = 6, Float = true },
	{ Id = "Legendary", Order = 5, Color = Color3.fromRGB(255, 190, 25), Shine = true, Light = 8, Particles = 6, Float = true },
	{ Id = "Mythic", Order = 6, Color = Color3.fromRGB(255, 45, 85), Shine = true, Light = 10, Particles = 12, Float = true, Beam = true },
	{ Id = "Divine", Order = 7, Color = Color3.fromRGB(110, 255, 240), Shine = true, Light = 12, Particles = 18, Float = true, Halo = true, Beam = true },
	{ Id = "Celestial", Order = 8, Color = Color3.fromRGB(255, 110, 255), Shine = true, Light = 14, Particles = 25, Rainbow = true, Float = true, Halo = true, Beam = true },
	{ Id = "Secret", Order = 9, Color = Color3.fromRGB(255, 255, 255), Shine = true, Light = 16, Particles = 35, Rainbow = true, Float = true, Halo = true, Beam = true },
} :: { Rarity }

Rarities.ById = {} :: { [string]: Rarity }
for _, rarity in Rarities.List do
	Rarities.ById[rarity.Id] = rarity
end

function Rarities.Get(id: string): Rarity
	return Rarities.ById[id] or Rarities.List[1]
end

return Rarities
