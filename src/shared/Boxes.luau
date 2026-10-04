--[[
	Boxes: donut boxes - what you steal from each biome's Domer (Config.Boxes has the numbers).

	A box is a rarity TIER and a SIZE:
	  * Tier: Basic (the plain pink box, first biome only), Rare, Epic or Legendary. It picks which of
	    the biome's donuts can come out (Donuts.ByBox) and how long it takes to open.
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
	Weight: number,
	Color: Color3,
	Trim: Color3,
}

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

-- The tiers a biome's Domer guards: just the pink box in the first biome, Rare / Epic /
-- Legendary everywhere else.
function Boxes.TiersFor(biome: number): { Tier }
	if biome <= 1 then
		return { Boxes.TierById.Basic }
	end
	local list = {}
	for _, tier in Boxes.Tiers do
		if tier.Id ~= "Basic" then
			table.insert(list, tier)
		end
	end
	return list
end

-- A random tier for a fresh box in `biome`. `luck` multiplies the Epic and Legendary weights.
function Boxes.RollTier(biome: number, rng: Random, luck: number?): Tier
	local list = Boxes.TiersFor(biome)
	if #list == 1 then
		return list[1]
	end
	local boost = luck or 1
	local total = 0
	for _, tier in list do
		total += tier.Weight * (if tier.Order >= 2 then boost else 1)
	end
	local left = rng:NextNumber() * total
	for _, tier in list do
		left -= tier.Weight * (if tier.Order >= 2 then boost else 1)
		if left <= 0 then
			return tier
		end
	end
	return list[#list]
end

-- Chance (0-1) that a fresh box in `biome` is this tier.
function Boxes.TierChance(biome: number, tierId: string): number
	local list = Boxes.TiersFor(biome)
	local total, mine = 0, 0
	for _, tier in list do
		total += tier.Weight
		if tier.Id == tierId then
			mine = tier.Weight
		end
	end
	if #list == 1 then
		return if list[1].Id == tierId then 1 else 0
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
