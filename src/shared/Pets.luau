--[[
	Pets and pet eggs.

	Eggs appear now and then in the higher areas (MinArea..MaxArea). Grab one, bring it home, and it
	incubates at your base for HatchSeconds (real time: it keeps going while you're offline).
	Then it hatches into one of its Pets (weighted). Rarer eggs take longer and hold better pets.

	Pets give bonuses while equipped (Config.Pets.MaxEquipped at once):
	  Money -> +x income from your base (0.25 = +25%)
	  Speed -> +x Speed gained on the treadmill
	Bonuses from equipped pets add up (capped by Config.Pets.MaxMoneyBonus / MaxSpeedBonus).

	Look: Shape is the body plan (see PetModel.luau), Features are extra bits (ears, wings, horn...).
	To add a pet: add a line to Pets.List and put its Id in an egg's Pool.

	Crate exclusives: eggs with CrateOnly never appear in the lane (only from crates, see Crates.luau),
	and pets with Exclusive set can't be hatched from normal eggs.
]]

local rgb = Color3.fromRGB

export type PetRarity = { Id: string, Order: number, Color: Color3 }

export type Pet = {
	Id: string,
	Name: string,
	Rarity: string,
	Money: number,
	Speed: number,
	Shape: string, -- "Quad" | "Bird" | "Blob" | "Dragon" | "Whale" | "Crab"
	Body: Color3,
	Accent: Color3,
	Features: { string },
	Scale: number?,
	Exclusive: string?, -- where it comes from if not a normal egg, e.g. "Legendary Crate"
}

export type Egg = {
	Id: string,
	Name: string,
	MinArea: number,
	MaxArea: number,
	Weight: number, -- chance relative to the other eggs that can appear in the same area
	HatchSeconds: number,
	Tier: number, -- 1..6: how fancy (and mystical) its effects are
	Color: Color3,
	Accent: Color3,
	Rainbow: boolean?,
	CrateOnly: boolean?, -- only from crates, never in the lane
	Pool: { { Pet: string, Weight: number } },
}

local Pets = {}

Pets.Rarities = {
	{ Id = "Common", Order = 1, Color = rgb(215, 215, 215) },
	{ Id = "Uncommon", Order = 2, Color = rgb(85, 225, 90) },
	{ Id = "Rare", Order = 3, Color = rgb(55, 150, 255) },
	{ Id = "Epic", Order = 4, Color = rgb(190, 70, 255) },
	{ Id = "Legendary", Order = 5, Color = rgb(255, 190, 25) },
	{ Id = "Mythic", Order = 6, Color = rgb(255, 60, 90) },
	{ Id = "Secret", Order = 7, Color = rgb(255, 255, 255) },
} :: { PetRarity }

Pets.List = {
	-- Sprinkle Egg
	{ Id = "GlazePup", Name = "Glaze Pup", Rarity = "Common", Money = 0.05, Speed = 0, Shape = "Quad", Body = rgb(222, 165, 95), Accent = rgb(255, 150, 200), Features = { "FloppyEars", "Tail", "Sprinkles" } },
	{ Id = "SprinkleKitty", Name = "Sprinkle Kitty", Rarity = "Common", Money = 0, Speed = 0.05, Shape = "Quad", Body = rgb(255, 200, 230), Accent = rgb(255, 110, 170), Features = { "PointyEars", "Tail", "Sprinkles" } },
	{ Id = "ChocoBunny", Name = "Choco Bunny", Rarity = "Uncommon", Money = 0.06, Speed = 0.04, Shape = "Quad", Body = rgb(120, 70, 40), Accent = rgb(255, 230, 200), Features = { "LongEars", "PuffTail" } },
	{ Id = "DonutDuck", Name = "Donut Duck", Rarity = "Rare", Money = 0.12, Speed = 0.04, Shape = "Bird", Body = rgb(255, 230, 90), Accent = rgb(255, 150, 40), Features = { "Beak", "DonutRing" } },
	-- Frosted Egg
	{ Id = "FrostPenguin", Name = "Frost Penguin", Rarity = "Common", Money = 0, Speed = 0.08, Shape = "Bird", Body = rgb(40, 45, 60), Accent = rgb(240, 245, 255), Features = { "Beak", "Belly", "Scarf" } },
	{ Id = "SnowFox", Name = "Snow Fox", Rarity = "Uncommon", Money = 0.12, Speed = 0, Shape = "Quad", Body = rgb(240, 245, 255), Accent = rgb(150, 210, 255), Features = { "PointyEars", "BigTail" } },
	{ Id = "IceOwl", Name = "Ice Owl", Rarity = "Rare", Money = 0.06, Speed = 0.12, Shape = "Bird", Body = rgb(170, 220, 255), Accent = rgb(255, 255, 255), Features = { "Beak", "Wings", "Tufts" } },
	{ Id = "YetiCub", Name = "Yeti Cub", Rarity = "Epic", Money = 0.2, Speed = 0.1, Shape = "Quad", Body = rgb(245, 248, 255), Accent = rgb(120, 200, 255), Features = { "Horns", "RoundEars", "Glow" } },
	-- Molten Egg
	{ Id = "EmberLizard", Name = "Ember Lizard", Rarity = "Uncommon", Money = 0, Speed = 0.12, Shape = "Quad", Body = rgb(230, 90, 30), Accent = rgb(255, 210, 60), Features = { "Tail", "Spikes" } },
	{ Id = "MagmaHound", Name = "Magma Hound", Rarity = "Rare", Money = 0.2, Speed = 0, Shape = "Quad", Body = rgb(60, 40, 40), Accent = rgb(255, 110, 0), Features = { "PointyEars", "Tail", "Flames", "Glow" } },
	{ Id = "FirePhoenix", Name = "Fire Phoenix", Rarity = "Epic", Money = 0.15, Speed = 0.2, Shape = "Bird", Body = rgb(255, 120, 30), Accent = rgb(255, 230, 60), Features = { "Beak", "Wings", "Crest", "Flames", "Glow" } },
	{ Id = "LavaDragon", Name = "Lava Dragon", Rarity = "Legendary", Money = 0.35, Speed = 0.2, Shape = "Dragon", Body = rgb(90, 30, 20), Accent = rgb(255, 140, 0), Features = { "Wings", "Horns", "Tail", "Flames", "Glow" } },
	-- Cosmic Egg
	{ Id = "StarJelly", Name = "Star Jelly", Rarity = "Rare", Money = 0.25, Speed = 0, Shape = "Blob", Body = rgb(150, 110, 255), Accent = rgb(255, 240, 150), Features = { "Tentacles", "Stars", "Glow" } },
	{ Id = "NebulaCat", Name = "Nebula Cat", Rarity = "Epic", Money = 0.2, Speed = 0.25, Shape = "Quad", Body = rgb(60, 30, 120), Accent = rgb(255, 120, 230), Features = { "PointyEars", "Tail", "Stars", "Glow" } },
	{ Id = "GalaxyWhale", Name = "Galaxy Whale", Rarity = "Legendary", Money = 0.45, Speed = 0.25, Shape = "Whale", Body = rgb(30, 30, 90), Accent = rgb(120, 200, 255), Features = { "Stars", "Spout", "Glow" } },
	{ Id = "CosmicUnicorn", Name = "Cosmic Unicorn", Rarity = "Mythic", Money = 0.7, Speed = 0.4, Shape = "Quad", Body = rgb(255, 245, 255), Accent = rgb(200, 120, 255), Features = { "Horn", "Mane", "Wings", "Stars", "Rainbow", "Glow" } },
	-- Tropical Egg
	{ Id = "ParrotPal", Name = "Parrot Pal", Rarity = "Rare", Money = 0.3, Speed = 0, Shape = "Bird", Body = rgb(60, 200, 90), Accent = rgb(255, 60, 60), Features = { "Beak", "Wings", "Crest" } },
	{ Id = "CoralCrab", Name = "Coral Crab", Rarity = "Epic", Money = 0.1, Speed = 0.3, Shape = "Crab", Body = rgb(255, 110, 90), Accent = rgb(255, 220, 200), Features = { "Claws", "Antenna" } },
	{ Id = "TikiTurtle", Name = "Tiki Turtle", Rarity = "Legendary", Money = 0.5, Speed = 0.3, Shape = "Quad", Body = rgb(110, 190, 90), Accent = rgb(170, 110, 60), Features = { "Shell", "Leaf", "Glow" } },
	{ Id = "KrakenJr", Name = "Kraken Jr.", Rarity = "Mythic", Money = 0.9, Speed = 0.5, Shape = "Blob", Body = rgb(170, 50, 120), Accent = rgb(80, 220, 255), Features = { "Tentacles", "Crown", "Glow" } },
	-- Dream Egg
	{ Id = "CloudSheep", Name = "Cloud Sheep", Rarity = "Epic", Money = 0.4, Speed = 0.3, Shape = "Quad", Body = rgb(250, 250, 255), Accent = rgb(255, 190, 225), Features = { "Fluff", "RoundEars" } },
	{ Id = "TeddyGhost", Name = "Teddy Ghost", Rarity = "Legendary", Money = 0.7, Speed = 0.4, Shape = "Blob", Body = rgb(235, 240, 255), Accent = rgb(170, 130, 255), Features = { "RoundEars", "Bow", "Ghost", "Glow" } },
	{ Id = "AngelBear", Name = "Angel Bear", Rarity = "Mythic", Money = 1.2, Speed = 0.6, Shape = "Quad", Body = rgb(255, 235, 200), Accent = rgb(255, 230, 120), Features = { "RoundEars", "Wings", "Halo", "Glow" } },
	{ Id = "DreamDragon", Name = "Dream Dragon", Rarity = "Secret", Money = 2, Speed = 1, Shape = "Dragon", Body = rgb(255, 200, 240), Accent = rgb(150, 220, 255), Features = { "Wings", "Horns", "Tail", "Halo", "Stars", "Rainbow", "Glow" } },
	-- Void Egg (ultra rare, anywhere from area 8)
	{ Id = "VoidImp", Name = "Void Imp", Rarity = "Legendary", Money = 0.8, Speed = 0.5, Shape = "Blob", Body = rgb(20, 10, 30), Accent = rgb(200, 60, 255), Features = { "Horns", "Wings", "Tail", "Glow" } },
	{ Id = "VoidSerpent", Name = "Void Serpent", Rarity = "Mythic", Money = 1.5, Speed = 0.8, Shape = "Dragon", Body = rgb(15, 5, 25), Accent = rgb(120, 255, 220), Features = { "Horns", "Tail", "Stars", "Glow" } },
	{ Id = "GlitchGod", Name = "Glitch God", Rarity = "Secret", Money = 3, Speed = 1.5, Shape = "Blob", Body = rgb(0, 0, 0), Accent = rgb(0, 255, 180), Features = { "Crown", "Halo", "Stars", "Rainbow", "Glitch", "Glow" }, Scale = 1.2 },
	-- Crate exclusives: the Royal Egg (Epic / Legendary crates) ...
	{ Id = "RoyalCorgi", Name = "Royal Corgi", Rarity = "Legendary", Money = 0.8, Speed = 0.4, Shape = "Quad", Body = rgb(240, 170, 90), Accent = rgb(255, 215, 60), Features = { "PointyEars", "PuffTail", "Crown", "Glow" }, Exclusive = "Royal Egg" },
	{ Id = "JesterMonkey", Name = "Jester Monkey", Rarity = "Legendary", Money = 0.5, Speed = 0.8, Shape = "Quad", Body = rgb(150, 95, 60), Accent = rgb(170, 60, 255), Features = { "RoundEars", "Tail", "Bow", "Glow" }, Exclusive = "Royal Egg" },
	{ Id = "RoyalGriffin", Name = "Royal Griffin", Rarity = "Mythic", Money = 1.4, Speed = 0.9, Shape = "Bird", Body = rgb(245, 220, 150), Accent = rgb(255, 200, 40), Features = { "Beak", "Wings", "Crest", "Crown", "Glow" }, Exclusive = "Royal Egg" },
	{ Id = "CrownWhale", Name = "Crown Whale", Rarity = "Mythic", Money = 1.8, Speed = 0.6, Shape = "Whale", Body = rgb(60, 40, 140), Accent = rgb(255, 215, 60), Features = { "Crown", "Spout", "Stars", "Glow" }, Exclusive = "Royal Egg" },
	-- ... and one pet that only comes straight out of a Legendary Crate.
	{ Id = "CrateKing", Name = "Crate King", Rarity = "Secret", Money = 3, Speed = 1.5, Shape = "Dragon", Body = rgb(255, 200, 40), Accent = rgb(255, 60, 60), Features = { "Wings", "Horns", "Tail", "Crown", "Halo", "Rainbow", "Glow" }, Scale = 1.15, Exclusive = "Legendary Crate" },
} :: { Pet }

Pets.Eggs = {
	{
		Id = "Sprinkle", Name = "Sprinkle Egg", MinArea = 4, MaxArea = 10, Weight = 100, HatchSeconds = 180, Tier = 1,
		Color = rgb(255, 170, 215), Accent = rgb(255, 255, 255),
		Pool = { { Pet = "GlazePup", Weight = 45 }, { Pet = "SprinkleKitty", Weight = 30 }, { Pet = "ChocoBunny", Weight = 18 }, { Pet = "DonutDuck", Weight = 7 } },
	},
	{
		Id = "Frosted", Name = "Frosted Egg", MinArea = 6, MaxArea = 12, Weight = 60, HatchSeconds = 480, Tier = 2,
		Color = rgb(170, 225, 255), Accent = rgb(255, 255, 255),
		Pool = { { Pet = "FrostPenguin", Weight = 45 }, { Pet = "SnowFox", Weight = 30 }, { Pet = "IceOwl", Weight = 18 }, { Pet = "YetiCub", Weight = 7 } },
	},
	{
		Id = "Molten", Name = "Molten Egg", MinArea = 7, MaxArea = 15, Weight = 40, HatchSeconds = 900, Tier = 3,
		Color = rgb(70, 40, 35), Accent = rgb(255, 120, 0),
		Pool = { { Pet = "EmberLizard", Weight = 45 }, { Pet = "MagmaHound", Weight = 32 }, { Pet = "FirePhoenix", Weight = 17 }, { Pet = "LavaDragon", Weight = 6 } },
	},
	{
		Id = "Cosmic", Name = "Cosmic Egg", MinArea = 9, MaxArea = 20, Weight = 25, HatchSeconds = 1800, Tier = 4,
		Color = rgb(40, 20, 90), Accent = rgb(150, 220, 255),
		Pool = { { Pet = "StarJelly", Weight = 48 }, { Pet = "NebulaCat", Weight = 33 }, { Pet = "GalaxyWhale", Weight = 16 }, { Pet = "CosmicUnicorn", Weight = 3 } },
	},
	{
		Id = "Tropical", Name = "Tropical Egg", MinArea = 11, MaxArea = 20, Weight = 35, HatchSeconds = 2700, Tier = 4,
		Color = rgb(255, 220, 120), Accent = rgb(0, 200, 190),
		Pool = { { Pet = "ParrotPal", Weight = 48 }, { Pet = "CoralCrab", Weight = 33 }, { Pet = "TikiTurtle", Weight = 16 }, { Pet = "KrakenJr", Weight = 3 } },
	},
	{
		Id = "Dream", Name = "Dream Egg", MinArea = 16, MaxArea = 20, Weight = 35, HatchSeconds = 3600, Tier = 5,
		Color = rgb(255, 235, 250), Accent = rgb(190, 150, 255),
		Pool = { { Pet = "CloudSheep", Weight = 55 }, { Pet = "TeddyGhost", Weight = 32 }, { Pet = "AngelBear", Weight = 12 }, { Pet = "DreamDragon", Weight = 1 } },
	},
	{
		Id = "Void", Name = "Void Egg", MinArea = 8, MaxArea = 20, Weight = 3, HatchSeconds = 5400, Tier = 6, Rainbow = true,
		Color = rgb(10, 5, 20), Accent = rgb(200, 80, 255),
		Pool = { { Pet = "VoidImp", Weight = 70 }, { Pet = "VoidSerpent", Weight = 28 }, { Pet = "GlitchGod", Weight = 2 } },
	},
	{
		Id = "Royal", Name = "Royal Egg", MinArea = 0, MaxArea = 0, Weight = 0, HatchSeconds = 1200, Tier = 6, CrateOnly = true,
		Color = rgb(255, 205, 50), Accent = rgb(170, 60, 255),
		Pool = { { Pet = "RoyalCorgi", Weight = 40 }, { Pet = "JesterMonkey", Weight = 35 }, { Pet = "RoyalGriffin", Weight = 17 }, { Pet = "CrownWhale", Weight = 8 } },
	},
} :: { Egg }

Pets.ById = {} :: { [string]: Pet }
for _, pet in Pets.List do
	assert(Pets.ById[pet.Id] == nil, "Duplicate pet id: " .. pet.Id)
	Pets.ById[pet.Id] = pet
end
Pets.EggById = {} :: { [string]: Egg }
for _, egg in Pets.Eggs do
	Pets.EggById[egg.Id] = egg
	for _, entry in egg.Pool do
		assert(Pets.ById[entry.Pet], `Egg {egg.Id} has unknown pet {entry.Pet}`)
	end
end
Pets.RarityById = {} :: { [string]: PetRarity }
for _, rarity in Pets.Rarities do
	Pets.RarityById[rarity.Id] = rarity
end

function Pets.Rarity(id: string): PetRarity
	return Pets.RarityById[id] or Pets.Rarities[1]
end

function Pets.HasFeature(pet: Pet, feature: string): boolean
	return table.find(pet.Features, feature) ~= nil
end

-- Eggs that can show up in an area.
function Pets.EggsForArea(areaId: number): { Egg }
	local result = {}
	for _, egg in Pets.Eggs do
		if not egg.CrateOnly and areaId >= egg.MinArea and areaId <= egg.MaxArea then
			table.insert(result, egg)
		end
	end
	return result
end

function Pets.RollEgg(areaId: number, rng: Random): Egg?
	local pool = Pets.EggsForArea(areaId)
	local total = 0
	for _, egg in pool do
		total += egg.Weight
	end
	if total <= 0 then
		return nil
	end
	local pick = rng:NextNumber() * total
	for _, egg in pool do
		pick -= egg.Weight
		if pick <= 0 then
			return egg
		end
	end
	return pool[#pool]
end

function Pets.RollPet(egg: Egg, rng: Random): Pet
	local total = 0
	for _, entry in egg.Pool do
		total += entry.Weight
	end
	local pick = rng:NextNumber() * total
	for _, entry in egg.Pool do
		pick -= entry.Weight
		if pick <= 0 then
			return Pets.ById[entry.Pet]
		end
	end
	return Pets.ById[egg.Pool[#egg.Pool].Pet]
end

-- Chance (0-1) of an egg hatching into a pet.
function Pets.Chance(egg: Egg, petId: string): number
	local total, weight = 0, 0
	for _, entry in egg.Pool do
		total += entry.Weight
		if entry.Pet == petId then
			weight = entry.Weight
		end
	end
	return if total > 0 then weight / total else 0
end

-- The egg a pet comes from.
function Pets.EggOf(petId: string): Egg?
	for _, egg in Pets.Eggs do
		for _, entry in egg.Pool do
			if entry.Pet == petId then
				return egg
			end
		end
	end
	return nil
end

-- "+25% money • +10% speed"
function Pets.BonusText(pet: Pet): string
	local parts = {}
	if pet.Money > 0 then
		table.insert(parts, `+{math.floor(pet.Money * 100 + 0.5)}% money`)
	end
	if pet.Speed > 0 then
		table.insert(parts, `+{math.floor(pet.Speed * 100 + 0.5)}% speed`)
	end
	return table.concat(parts, " • ")
end

return Pets
