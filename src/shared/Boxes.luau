--[[
	Boxes: donut boxes - what you steal from each biome's Domer (Config.Boxes has the numbers).

	A box is a rarity TIER and a SIZE:
	  * Tier: Basic (the plain pink box, first biome only), Rare, Epic, Legendary or Mythic. Which
	    ones a biome has (and how often) is its lineup (Config.Boxes.Lineups): Rare / Epic /
	    Legendary, then Epic / Legendary / Mythic in the later biomes. The tier picks which of the
	    biome's donuts can come out (Donuts.ByBox) and how long it takes to open.
	  * Size: Small, Big, Huge or GIANT. Bigger boxes are rarer, take longer to open, slow you down
	    while you carry them and hold a bigger donut (Rarities.Sizes) that earns more.

	A box in your pen opens after HatchSeconds (its tier) x HatchMultiplier (its size) - the same
	in every biome: a Small Rare box takes 1 minute whether it's from biome 2 or biome 19.
]]

local Config = require(script.Parent.Config)

export type Tier = {
	Id: string,
	Name: string,
	Order: number,
	HatchSeconds: number,
	Color: Color3,
	Trim: Color3,
}

export type LineupEntry = { Tier: Tier, Weight: number }

export type Size = {
	Id: string,
	Name: string,
	HatchMultiplier: number,
	Weight: number,
	Scale: number,
	DonutSize: string,
	CarrySpeed: number,
}

local Boxes = {}

Boxes.Tiers = Config.Boxes.Tiers :: { Tier }
Boxes.Sizes = Config.Boxes.Sizes :: { Size }

Boxes.TierById = {} :: { [string]: Tier }
for _, tier in Boxes.Tiers do
	Boxes.TierById[tier.Id] = tier
end
Boxes.SizeById = {} :: { [string]: Size }
for _, size in Boxes.Sizes do
	Boxes.SizeById[size.Id] = size
end

function Boxes.Tier(id: string?): Tier
	return Boxes.TierById[id or "Basic"] or Boxes.Tiers[1]
end

function Boxes.Size(id: string?): Size
	return Boxes.SizeById[id or "Small"] or Boxes.Sizes[1]
end

-- Seconds a box takes to open in your pen (before Box Rushes and skips).
function Boxes.HatchSeconds(tierId: string, sizeId: string?): number
	return Boxes.Tier(tierId).HatchSeconds * Boxes.Size(sizeId).HatchMultiplier
end

local lineups: { { From: number, Entries: { LineupEntry } } } = {}
for _, lineup in Config.Boxes.Lineups do
	local entries = {}
	for _, entry in lineup.Tiers do
		local tier = Boxes.TierById[entry.Id]
		assert(tier, "Unknown box tier in Config.Boxes.Lineups: " .. entry.Id)
		table.insert(entries, { Tier = tier, Weight = entry.Weight })
	end
	table.insert(lineups, { From = lineup.From, Entries = entries })
end
table.sort(lineups, function(a, b)
	return a.From < b.From
end)

-- The boxes a biome's Domer guards, most common first, with how often each turns up.
function Boxes.Lineup(biome: number): { LineupEntry }
	local found = lineups[1].Entries
	for _, lineup in lineups do
		if biome >= lineup.From then
			found = lineup.Entries
		end
	end
	return found
end

-- The tiers a biome's Domer guards, most common first.
function Boxes.TiersFor(biome: number): { Tier }
	local list = {}
	for _, entry in Boxes.Lineup(biome) do
		table.insert(list, entry.Tier)
	end
	return list
end

-- Where a tier is in its biome's lineup: 1 = the common box, 3 = the rarest (0 = not there).
function Boxes.Rank(biome: number, tierId: string): number
	for i, entry in Boxes.Lineup(biome) do
		if entry.Tier.Id == tierId then
			return i
		end
	end
	return 0
end

-- A random tier for a fresh box in `biome`. `luck` multiplies the weights of every box but the
-- common one.
function Boxes.RollTier(biome: number, rng: Random, luck: number?): Tier
	local lineup = Boxes.Lineup(biome)
	local boost = luck or 1
	local total = 0
	for i, entry in lineup do
		total += entry.Weight * (if i > 1 then boost else 1)
	end
	local left = rng:NextNumber() * total
	for i, entry in lineup do
		left -= entry.Weight * (if i > 1 then boost else 1)
		if left <= 0 then
			return entry.Tier
		end
	end
	return lineup[#lineup].Tier
end

-- Chance (0-1) that a fresh box in `biome` is this tier. `luck`: the Luck Event's boost, the same
-- way RollTier uses it (so the Index can show the boosted odds while one runs).
function Boxes.TierChance(biome: number, tierId: string, luck: number?): number
	local lineup = Boxes.Lineup(biome)
	local boost = luck or 1
	local total, mine = 0, 0
	for i, entry in lineup do
		local weight = entry.Weight * (if i > 1 then boost else 1)
		total += weight
		if entry.Tier.Id == tierId then
			mine = weight
		end
	end
	return if total > 0 then mine / total else 0
end

-- A random size. `bigLuck` multiplies every size bigger than Small (Luck Event).
function Boxes.RollSize(rng: Random, bigLuck: number?): Size
	local luck = bigLuck or 1
	local total = 0
	for i, size in Boxes.Sizes do
		total += size.Weight * (if i > 1 then luck else 1)
	end
	local left = rng:NextNumber() * total
	for i, size in Boxes.Sizes do
		left -= size.Weight * (if i > 1 then luck else 1)
		if left <= 0 then
			return size
		end
	end
	return Boxes.Sizes[1]
end

-- "GIANT Legendary Donut Box", "Donut Box", "Big Epic Donut Box"
function Boxes.DisplayName(tierId: string, sizeId: string?): string
	local size = Boxes.Size(sizeId)
	local name = Boxes.Tier(tierId).Name
	return if size.Id == "Small" then name else `{size.Name} {name}`
end

return Boxes
