--[[
	Crates: open one and get ONE random reward from its list.

	You can find crates now and then in the lane (Config.Crates.Found), or buy them for Robux in the
	shop (developer products, Config.Crates.Products).

	Rewards:
	  Coins      -> Seconds of income from the best donut in the best area your Speed is good for
	                (so the amount keeps up with how far you are). Rebirth money bonus included.
	  SpeedBoost -> you run x Config.Crates.SpeedBoostMultiplier faster for Seconds (counts down only
	                while you're in the game; more boosts add more time)
	  Luck       -> starts / extends the server-wide Luck Event for Seconds (everyone benefits)
	  Egg        -> one egg from Eggs (weighted), straight into your incubator
	  Pet        -> that pet, straight into your pets

	!! Roblox rules for paid random items: every outcome and its exact chance must be shown BEFORE
	the purchase, adding up to 100%. The shop builds that list from this file (Crates.Odds), so
	whatever you change here is what players see. Nothing (luck, passes) changes these odds.
]]

local rgb = Color3.fromRGB

export type Reward = {
	Kind: string, -- "Coins" | "SpeedBoost" | "Luck" | "Egg" | "Pet"
	Weight: number,
	Seconds: number?, -- Coins: seconds of income; SpeedBoost / Luck: duration
	Eggs: { { Egg: string, Weight: number } }?,
	Pet: string?,
}

export type Crate = {
	Id: string,
	Name: string,
	Order: number,
	Color: Color3,
	Accent: Color3,
	FoundWeight: number, -- how often this kind shows up in the lane (relative to the others)
	Rewards: { Reward },
}

-- One line of the odds list: what you get, the chance (0-1), and for eggs the chance of each pet.
export type Outcome = { Reward: Reward, Label: string, Chance: number, Egg: string?, Pet: string? }

local Crates = {}

Crates.List = {
	{
		Id = "Common", Name = "Common Crate", Order = 1, Color = rgb(170, 120, 70), Accent = rgb(230, 230, 230), FoundWeight = 75,
		Rewards = {
			{ Kind = "Coins", Weight = 65, Seconds = 600 },
			{ Kind = "Egg", Weight = 35, Eggs = { { Egg = "Sprinkle", Weight = 70 }, { Egg = "Frosted", Weight = 30 } } },
		},
	},
	{
		Id = "Rare", Name = "Rare Crate", Order = 2, Color = rgb(50, 120, 230), Accent = rgb(150, 220, 255), FoundWeight = 20,
		Rewards = {
			{ Kind = "Coins", Weight = 45, Seconds = 1800 },
			{ Kind = "SpeedBoost", Weight = 30, Seconds = 600 },
			{ Kind = "Egg", Weight = 25, Eggs = { { Egg = "Frosted", Weight = 45 }, { Egg = "Molten", Weight = 40 }, { Egg = "Cosmic", Weight = 15 } } },
		},
	},
	{
		Id = "Epic", Name = "Epic Crate", Order = 3, Color = rgb(150, 60, 230), Accent = rgb(255, 150, 255), FoundWeight = 4.5,
		Rewards = {
			{ Kind = "Coins", Weight = 35, Seconds = 5400 },
			{ Kind = "SpeedBoost", Weight = 25, Seconds = 600 },
			{ Kind = "Luck", Weight = 20, Seconds = 600 },
			{ Kind = "Egg", Weight = 20, Eggs = { { Egg = "Cosmic", Weight = 40 }, { Egg = "Tropical", Weight = 35 }, { Egg = "Dream", Weight = 25 } } },
		},
	},
	{
		Id = "Legendary", Name = "Legendary Crate", Order = 4, Color = rgb(255, 190, 30), Accent = rgb(255, 80, 80), FoundWeight = 0.5,
		Rewards = {
			{ Kind = "Coins", Weight = 50, Seconds = 36000 },
			{ Kind = "Egg", Weight = 40, Eggs = { { Egg = "Royal", Weight = 1 } } },
			{ Kind = "Pet", Weight = 10, Pet = "CrateKing" },
		},
	},
} :: { Crate }

Crates.ById = {} :: { [string]: Crate }
for _, crate in Crates.List do
	Crates.ById[crate.Id] = crate
end

local function weightsOf(list: { any }): { number }
	local weights = {}
	for _, entry in list do
		table.insert(weights, entry.Weight :: number)
	end
	return weights
end

local function total(weights: { number }): number
	local sum = 0
	for _, weight in weights do
		sum += weight
	end
	return sum
end

-- Index of a weighted random entry.
local function pickIndex(weights: { number }, rng: Random): number
	local roll = rng:NextNumber() * total(weights)
	for index, weight in weights do
		roll -= weight
		if roll <= 0 then
			return index
		end
	end
	return #weights
end

-- Roll a crate: the reward, plus the egg id for egg rewards.
function Crates.Roll(crate: Crate, rng: Random): (Reward, string?)
	local reward = crate.Rewards[pickIndex(weightsOf(crate.Rewards), rng)]
	local eggs = reward.Eggs
	local eggId = if eggs then eggs[pickIndex(weightsOf(eggs), rng)].Egg else nil
	return reward, eggId
end

-- Roll which kind of crate shows up in the lane.
function Crates.RollFound(rng: Random): Crate
	local weights = {}
	for _, crate in Crates.List do
		table.insert(weights, crate.FoundWeight)
	end
	return Crates.List[pickIndex(weights, rng)]
end

-- Every possible outcome of a crate with its exact chance (eggs are split per egg). Adds up to 1.
function Crates.Odds(crate: Crate): { Outcome }
	local result: { Outcome } = {}
	local sum = total(weightsOf(crate.Rewards))
	for _, reward in crate.Rewards do
		local chance = reward.Weight / sum
		if reward.Eggs then
			local eggs = reward.Eggs
			local eggSum = total(weightsOf(eggs))
			for _, entry in eggs do
				table.insert(result, { Reward = reward, Label = entry.Egg, Chance = chance * entry.Weight / eggSum, Egg = entry.Egg })
			end
		else
			table.insert(result, { Reward = reward, Label = reward.Kind, Chance = chance, Pet = reward.Pet })
		end
	end
	return result
end

return Crates
