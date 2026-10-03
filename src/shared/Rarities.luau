--[[
	Rarities, Mutations and Sizes.

	Every donut that spawns has:
	  * a base RARITY (from Donuts.luau)       Common ... Secret, Admin, Icon
	  * a MUTATION (rolled on spawn, rare)     None / Gold / Diamond / Mythic / Divine / Rainbow
	                                           (+ Eternal, only from the Eternal Storm event)
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
	AdminOnly: boolean?, -- never spawns by itself: only the admin panel can make one
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
	EventOnly: boolean?, -- never rolled on a spawn (Eternal: only the Eternal Storm gives it)
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
	-- (early game: Common - Rare are plain donuts, Epic only glows a little; the big effects start at
	-- Legendary and get wilder from there - see FXThemes)
	{ Id = "Rare", Order = 3, Color = Color3.fromRGB(55, 150, 255), Shine = true, IndexReward = { Cash = 600 } },
	{ Id = "Epic", Order = 4, Color = Color3.fromRGB(190, 70, 255), Shine = true, Light = 6, Particles = 3, IndexReward = { Cash = 900, Speed = 1 } },
	{ Id = "Legendary", Order = 5, Color = Color3.fromRGB(255, 190, 25), Shine = true, Light = 10, Particles = 14, Float = true, Beam = true, IndexReward = { Cash = 1200, Speed = 2 } },
	{ Id = "Celestial", Order = 6, Color = Color3.fromRGB(255, 110, 255), Shine = true, Light = 13, Particles = 24, Rainbow = true, Float = true, Halo = true, Beam = true, Orbit = true, IndexReward = { Cash = 1800, Speed = 4 } },
	{ Id = "Secret", Order = 7, Color = Color3.fromRGB(255, 255, 255), Shine = true, Light = 16, Particles = 40, Rainbow = true, Float = true, Halo = true, Beam = true, Orbit = true, IndexReward = { Cash = 3600, Speed = 8 } },
	-- Rarer than Secret: one per world, a fraction of a percent of a percent per spawn.
	{ Id = "Admin", Order = 8, Color = Color3.fromRGB(255, 40, 40), Shine = true, Light = 22, Particles = 60, Float = true, Halo = true, Beam = true, Orbit = true, AdminOnly = true, IndexReward = { Cash = 7200, Speed = 15 } },
	-- The rarest of all: a handful of legendary one-offs (the first is Fake Kar, in The Black Hole).
	{ Id = "Icon", Order = 9, Color = Color3.fromRGB(40, 140, 255), Shine = true, Light = 26, Particles = 80, Float = true, Halo = true, Beam = true, Orbit = true, IndexReward = { Cash = 14400, Speed = 25 } },
} :: { Rarity }

--------------------------------------------------------------------------------
-- Mutations: rolled on every spawn. Chances are per spawn; area events and the Luck Event multiply
-- them. Gold 0.6%, Diamond 0.25%, Mythic 0.08%, Divine 0.02%, Rainbow 0.006% (1 in ~17,000).
-- Eternal never rolls: only the Eternal Storm's purple lightning gives it (EventService).
--------------------------------------------------------------------------------
Rarities.Mutations = {
	{ Id = "None", Order = 0, Multiplier = 1, Chance = 0, Color = Color3.fromRGB(255, 255, 255) },
	{ Id = "Gold", Order = 1, Multiplier = 2, Chance = 0.006, Color = Color3.fromRGB(255, 205, 40), Dough = Color3.fromRGB(230, 170, 40), Frosting = Color3.fromRGB(255, 215, 60), Material = Enum.Material.Foil, Light = 5 },
	{ Id = "Diamond", Order = 2, Multiplier = 3, Chance = 0.0025, Color = Color3.fromRGB(120, 230, 255), Dough = Color3.fromRGB(170, 230, 255), Frosting = Color3.fromRGB(200, 250, 255), Material = Enum.Material.Glass, Particles = 4, Light = 7 },
	{ Id = "Mythic", Order = 3, Multiplier = 5, Chance = 0.0008, Color = Color3.fromRGB(255, 45, 85), Dough = Color3.fromRGB(60, 20, 30), Frosting = Color3.fromRGB(255, 40, 70), Material = Enum.Material.Neon, Particles = 18, Horns = true, Light = 10 },
	{ Id = "Divine", Order = 4, Multiplier = 10, Chance = 0.0002, Color = Color3.fromRGB(255, 250, 200), Dough = Color3.fromRGB(255, 240, 200), Frosting = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Neon, Particles = 25, Halo = true, Wings = true, Light = 14 },
	{ Id = "Rainbow", Order = 5, Multiplier = 25, Chance = 0.00006, Color = Color3.fromRGB(255, 120, 255), Particles = 35, Rainbow = true, Halo = true, Light = 16 },
	{ Id = "Eternal", Order = 6, Multiplier = 50, Chance = 0, Color = Color3.fromRGB(175, 70, 255), Dough = Color3.fromRGB(45, 15, 70), Frosting = Color3.fromRGB(200, 110, 255), Material = Enum.Material.Neon, Particles = 30, Halo = true, Light = 20, EventOnly = true },
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

-- Roll a size. `bigLuck` multiplies the chance of every size bigger than Normal (Luck Event).
function Rarities.RollSize(rng: Random, bigLuck: number?): Size
	local luck = bigLuck or 1
	local function weight(size: Size): number
		return if size.Order > 2 then size.Weight * luck else size.Weight
	end
	local total = 0
	for _, size in Rarities.Sizes do
		total += weight(size)
	end
	local pick = rng:NextNumber() * total
	for _, size in Rarities.Sizes do
		pick -= weight(size)
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
