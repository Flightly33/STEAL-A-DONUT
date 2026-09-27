--[[
	Rarities, Mutations and Sizes.

	Every donut that spawns has:
	  * a base RARITY (from Donuts.luau)       Common ... Secret
	  * a MUTATION (rolled on spawn, rare)     None / Gold / Diamond / Mythic / Divine / Rainbow
	  * a SIZE (rolled on spawn)               Small / Normal / Big / Huge / Giant

	Income = base income x mutation multiplier x size multiplier x upgrade level.
	Bigger donuts slow you down while you carry them (CarrySpeed).

	Rarity effects (they stack up the rarer a donut is; Legendary+ also sparkle and get a glowing ring
	on the ground in the lane):
		Shine      -> glossy frosting
		Light      -> PointLight in the rarity colour
		Particles  -> particle aura (rate)
		Rainbow    -> frosting cycles through colours (client side)
		Float      -> donut bobs and spins (client side)
		Halo       -> glowing ring above the donut
		Beam       -> light pillar under the donut (lane only, so you can spot it from afar)
		Orbit      -> little glowing orbs circling it
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
	Orbit: boolean?,
	IndexReward: { Cash: number, Speed: number? },
}

export type Mutation = {
	Id: string,
	Order: number,
	Multiplier: number,
	Chance: number, -- per spawn (before event luck)
	Color: Color3,
	Dough: Color3?,
	Frosting: Color3?,
	Material: Enum.Material?,
	Particles: number?,
	Rainbow: boolean?,
	Halo: boolean?,
	Wings: boolean?,
	Horns: boolean?,
	Light: number?,
}

export type Size = {
	Id: string,
	Order: number,
	Scale: number,
	Multiplier: number,
	Weight: number,
	CarrySpeed: number, -- WalkSpeed multiplier while you carry it
}

local Rarities = {}

--------------------------------------------------------------------------------
-- Base rarities. IndexReward: what you can claim in the Index once you've found the donut.
--   Cash  -> this many seconds of the donut's base income
--   Speed -> (Epic and up) you can pick this permanent % bonus to treadmill gains INSTEAD of the cash
--------------------------------------------------------------------------------
Rarities.List = {
	{ Id = "Common", Order = 1, Color = Color3.fromRGB(215, 215, 215), IndexReward = { Cash = 300 } },
	{ Id = "Uncommon", Order = 2, Color = Color3.fromRGB(85, 225, 90), IndexReward = { Cash = 450 } },
	{ Id = "Rare", Order = 3, Color = Color3.fromRGB(55, 150, 255), Shine = true, Particles = 3, IndexReward = { Cash = 600 } },
	{ Id = "Epic", Order = 4, Color = Color3.fromRGB(190, 70, 255), Shine = true, Light = 7, Particles = 7, Float = true, IndexReward = { Cash = 900, Speed = 1 } },
	{ Id = "Legendary", Order = 5, Color = Color3.fromRGB(255, 190, 25), Shine = true, Light = 10, Particles = 14, Float = true, Beam = true, IndexReward = { Cash = 1200, Speed = 3 } },
	{ Id = "Celestial", Order = 6, Color = Color3.fromRGB(255, 110, 255), Shine = true, Light = 13, Particles = 24, Rainbow = true, Float = true, Halo = true, Beam = true, Orbit = true, IndexReward = { Cash = 1800, Speed = 8 } },
	{ Id = "Secret", Order = 7, Color = Color3.fromRGB(255, 255, 255), Shine = true, Light = 16, Particles = 40, Rainbow = true, Float = true, Halo = true, Beam = true, Orbit = true, IndexReward = { Cash = 3600, Speed = 20 } },
} :: { Rarity }

--------------------------------------------------------------------------------
-- Mutations: rolled on every spawn. Chances are per spawn; area events multiply them.
--------------------------------------------------------------------------------
Rarities.Mutations = {
	{ Id = "None", Order = 0, Multiplier = 1, Chance = 0, Color = Color3.fromRGB(255, 255, 255) },
	{ Id = "Gold", Order = 1, Multiplier = 2, Chance = 0.03, Color = Color3.fromRGB(255, 205, 40), Dough = Color3.fromRGB(230, 170, 40), Frosting = Color3.fromRGB(255, 215, 60), Material = Enum.Material.Foil, Particles = 6, Light = 6 },
	{ Id = "Diamond", Order = 2, Multiplier = 3, Chance = 0.012, Color = Color3.fromRGB(120, 230, 255), Dough = Color3.fromRGB(170, 230, 255), Frosting = Color3.fromRGB(200, 250, 255), Material = Enum.Material.Glass, Particles = 12, Light = 8 },
	{ Id = "Mythic", Order = 3, Multiplier = 5, Chance = 0.004, Color = Color3.fromRGB(255, 45, 85), Dough = Color3.fromRGB(60, 20, 30), Frosting = Color3.fromRGB(255, 40, 70), Material = Enum.Material.Neon, Particles = 18, Horns = true, Light = 10 },
	{ Id = "Divine", Order = 4, Multiplier = 10, Chance = 0.0012, Color = Color3.fromRGB(255, 250, 200), Dough = Color3.fromRGB(255, 240, 200), Frosting = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Neon, Particles = 25, Halo = true, Wings = true, Light = 14 },
	{ Id = "Rainbow", Order = 5, Multiplier = 25, Chance = 0.0003, Color = Color3.fromRGB(255, 120, 255), Particles = 35, Rainbow = true, Halo = true, Light = 16 },
} :: { Mutation }

--------------------------------------------------------------------------------
-- Sizes: bigger = more money but slower to carry home.
--------------------------------------------------------------------------------
Rarities.Sizes = {
	{ Id = "Small", Order = 1, Scale = 0.75, Multiplier = 0.6, Weight = 22, CarrySpeed = 1 },
	{ Id = "Normal", Order = 2, Scale = 1, Multiplier = 1, Weight = 55, CarrySpeed = 1 },
	{ Id = "Big", Order = 3, Scale = 1.3, Multiplier = 1.8, Weight = 16, CarrySpeed = 0.95 },
	{ Id = "Huge", Order = 4, Scale = 1.65, Multiplier = 3.5, Weight = 6, CarrySpeed = 0.9 },
	{ Id = "Giant", Order = 5, Scale = 2.1, Multiplier = 7, Weight = 1, CarrySpeed = 0.84 },
} :: { Size }

Rarities.ById = {} :: { [string]: Rarity }
for _, rarity in Rarities.List do
	Rarities.ById[rarity.Id] = rarity
end
Rarities.MutationById = {} :: { [string]: Mutation }
for _, mutation in Rarities.Mutations do
	Rarities.MutationById[mutation.Id] = mutation
end
Rarities.SizeById = {} :: { [string]: Size }
for _, size in Rarities.Sizes do
	Rarities.SizeById[size.Id] = size
end

function Rarities.Get(id: string): Rarity
	return Rarities.ById[id] or Rarities.List[1]
end

function Rarities.Mutation(id: string?): Mutation
	return Rarities.MutationById[id or "None"] or Rarities.Mutations[1]
end

function Rarities.Size(id: string?): Size
	return Rarities.SizeById[id or "Normal"] or Rarities.Sizes[2]
end

-- Roll a mutation. `luck` multiplies every chance and `boost` names one mutation that gets an extra
-- x5 (area events use both).
function Rarities.RollMutation(rng: Random, luck: number?, boost: string?): Mutation
	local roll = rng:NextNumber()
	local l = luck or 1
	-- Rarest first so a lucky roll lands on the best mutation.
	for i = #Rarities.Mutations, 2, -1 do
		local mutation = Rarities.Mutations[i]
		local chance = mutation.Chance * l * (if mutation.Id == boost then 5 else 1)
		if roll < chance then
			return mutation
		end
		roll -= chance
	end
	return Rarities.Mutations[1]
end

function Rarities.RollSize(rng: Random): Size
	local total = 0
	for _, size in Rarities.Sizes do
		total += size.Weight
	end
	local pick = rng:NextNumber() * total
	for _, size in Rarities.Sizes do
		pick -= size.Weight
		if pick <= 0 then
			return size
		end
	end
	return Rarities.Sizes[2]
end

-- "Giant Gold Glazino", "Glazino", "Huge Rainbow ..."
function Rarities.DisplayName(baseName: string, mutationId: string?, sizeId: string?): string
	local parts = {}
	if sizeId and sizeId ~= "Normal" then
		table.insert(parts, sizeId)
	end
	if mutationId and mutationId ~= "None" then
		table.insert(parts, mutationId)
	end
	table.insert(parts, baseName)
	return table.concat(parts, " ")
end

return Rarities
