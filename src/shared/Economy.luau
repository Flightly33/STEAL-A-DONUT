--[[
	Economy: every formula that turns config numbers into prices, incomes and speeds.
	Shared by server (authoritative) and client (to display prices).
]]

local Config = require(script.Parent.Config)
local Donuts = require(script.Parent.Donuts)
local Rarities = require(script.Parent.Rarities)
local Areas = require(script.Parent.Areas)
local Boxes = require(script.Parent.Boxes)
local Pets = require(script.Parent.Pets)
local Layout = require(script.Parent.Layout)

local Economy = {}

--------------------------------------------------------------------------------
-- Speed
--------------------------------------------------------------------------------
-- WalkSpeed from the Speed stat, before the carry slowdown (Config.Speed): grows with Speed, but
-- more gently the bigger it gets (Speed reaches the hundreds of millions). The stat counts
-- Config.Speed.StatMultiplier times (100 Speed runs like 200).
function Economy.WalkSpeedFromStat(stat: number): number
	local s = Config.Speed
	return s.BaseWalkSpeed + s.CurveScale * (s.StatMultiplier * math.max(stat, 0)) ^ s.CurvePower
end

function Economy.StatForWalkSpeed(walkSpeed: number): number
	local s = Config.Speed
	local extra = walkSpeed - s.BaseWalkSpeed
	if extra <= 0 then
		return 0
	end
	return (extra / s.CurveScale) ^ (1 / s.CurvePower) / s.StatMultiplier
end

-- The old logarithmic curve (saves from before the Speed stat became linear are converted with it).
function Economy.LegacyWalkSpeed(stat: number): number
	return math.min(16 + 3 * math.log(1 + math.max(stat, 0) / 5, 2), 180)
end

-- (There's one world now: nobody gets a world bonus.)
function Economy.WorldWalkMultiplier(_worldId: number?): number
	return 1
end

-- How much a carried box or donut slows you down (1 = not at all).
function Economy.CarrySpeed(sizeId: string?): number
	return Rarities.Size(sizeId).CarrySpeed
end

-- The WalkSpeed a player actually gets.
function Economy.PlayerWalkSpeed(stat: number, _worldId: number?, carrySizeId: string?): number
	local walk = Economy.WalkSpeedFromStat(stat)
	if carrySizeId then
		walk *= Economy.CarrySpeed(carrySizeId)
	end
	return walk
end

-- How fast a biome's Domer runs. A biome's Speed is the Speed that just gets you away from him:
-- with exactly that Speed you grab a box (they sit `ahead` studs in front of him, `run` studs from
-- the biome's entrance), run straight back while he wakes up (WakeDelay seconds), get out of his
-- biome - and he catches you (Config.Guard.CatchRadius) EscapeMargin studs past the entrance.
-- Solving that for his speed gives runner * (run + margin + ahead - catch) / (run + margin -
-- runner * wake): about 1.2-1.3x the runner. The first biome's Domer is slower than anyone.
local guardSpeeds: { [number]: number } = {}
function Economy.GuardWalkSpeed(areaId: number): number
	local cached = guardSpeeds[areaId]
	if cached then
		return cached
	end
	local area = Areas.List[areaId]
	if not area or area.RecommendedSpeed <= 0 then
		return Config.Guard.BeginnerSpeed
	end
	local runner = Economy.WalkSpeedFromStat(area.RecommendedSpeed)
	local home = Layout.GuardHome(areaId)
	local boxZ = 0
	local spots = Layout.BoxSpots(areaId)
	for _, spot in spots do
		boxZ += spot.Z / #spots
	end
	local ahead = home.Z - boxZ
	local run = boxZ - Layout.AreaStart(areaId)
	local g = Config.Guard
	local distance = run + g.EscapeMargin
	local headStart = math.max(distance - runner * area.WakeDelay, distance * 0.25)
	local speed = runner * (distance + ahead - g.CatchRadius) / headStart
	speed = math.clamp(speed, runner * 1.05, runner * 2)
	guardSpeeds[areaId] = speed
	return speed
end

-- The Speed you need to get into a biome.
function Economy.RecommendedSpeed(areaId: number): number
	local area = Areas.List[areaId]
	return if area then area.RecommendedSpeed else 0
end

-- WalkSpeed of a player with exactly the biome's Speed requirement.
function Economy.RecommendedWalkSpeed(areaId: number): number
	return Economy.WalkSpeedFromStat(Economy.RecommendedSpeed(areaId))
end

-- Treadmill multiplier from the Speed Multiplier upgrade (+5% per level, adds up).
function Economy.SpeedMultiplier(level: number): number
	return 1 + Config.SpeedMultiplier.PerLevel * level
end

-- Price to go from `level` to `level + 1`.
function Economy.SpeedMultiplierCost(level: number): number
	local c = Config.SpeedMultiplier
	return math.floor(c.BaseCost * c.CostGrowth ^ level)
end

function Economy.TreadmillTier(level: number): Config.TreadmillTier
	local tiers = Config.Treadmill.Tiers
	return tiers[math.clamp(level, 1, #tiers)]
end

function Economy.MaxTreadmillLevel(): number
	return #Config.Treadmill.Tiers
end

-- Speed gained per second on the treadmill (StepsPerSecond steps of the tier's PerStep).
-- indexBonus: total Index speed bonus in % (e.g. 35 = +35%).
-- petBonus: total speed bonus of your equipped pets (0.25 = +25%).
function Economy.TreadmillRate(treadmillLevel: number, multiplierLevel: number, speedPassMultiplier: number, indexBonus: number?, petBonus: number?): number
	local index = math.min((indexBonus or 0) / 100, Config.Index.MaxSpeedBonus)
	local pets = math.min(petBonus or 0, Config.Pets.MaxSpeedBonus)
	return Economy.TreadmillTier(treadmillLevel).PerStep
		* Config.Treadmill.StepsPerSecond
		* Economy.SpeedMultiplier(multiplierLevel)
		* speedPassMultiplier
		* (1 + index)
		* (1 + pets)
end

--------------------------------------------------------------------------------
-- Donuts
--------------------------------------------------------------------------------
-- Income at level 1 (base income x mutation x size).
function Economy.DonutBaseIncome(donutId: string, mutationId: string?, sizeId: string?): number
	local donut = Donuts.ById[donutId]
	if not donut then
		return 0
	end
	return donut.Income * Rarities.Mutation(mutationId).Multiplier * Rarities.Size(sizeId).Multiplier
end

function Economy.DonutIncome(donutId: string, level: number, mutationId: string?, sizeId: string?): number
	return Economy.DonutBaseIncome(donutId, mutationId, sizeId) * (1 + Config.DonutUpgrade.IncomePerLevel * (level - 1))
end

-- Price to go from `level` to `level + 1`.
function Economy.DonutUpgradeCost(donutId: string, level: number, mutationId: string?, sizeId: string?): number
	local base = Economy.DonutBaseIncome(donutId, mutationId, sizeId)
	if base <= 0 then
		return math.huge
	end
	local u = Config.DonutUpgrade
	return math.floor(base * u.CostSeconds * u.CostGrowth ^ (level - 1))
end

function Economy.SellPrice(donutId: string, level: number, mutationId: string?, sizeId: string?): number
	return math.floor(Economy.DonutIncome(donutId, level, mutationId, sizeId) * Config.SellSeconds)
end

--------------------------------------------------------------------------------
-- Base expansions
--------------------------------------------------------------------------------
-- The furthest biome a player is fast enough to get into.
function Economy.BestAreaFor(speed: number): number
	local best = 1
	for _, area in Areas.List do
		if speed >= area.RecommendedSpeed then
			best = math.max(best, area.Id)
		end
	end
	return best
end

-- What a donut out of a (Small, plain) box from `biome` earns on average: every box tier and
-- every donut in it, weighted by their chances.
function Economy.TypicalBoxIncome(biome: number): number
	local total = 0
	for _, tier in Boxes.TiersFor(biome) do
		local chance = Boxes.TierChance(biome, tier.Id)
		local pool = Donuts.ByBox[biome] and Donuts.ByBox[biome][tier.Id]
		if chance > 0 and pool then
			for _, donut in pool do
				total += chance * Donuts.Chance(donut) * donut.Income
			end
		end
	end
	return total
end

-- Crate coins: `seconds` of income from a typical donut of the furthest biome your Speed is good
-- for. Grows as you progress.
function Economy.CrateCoins(seconds: number, speed: number): number
	return math.floor(seconds * Economy.TypicalBoxIncome(Economy.BestAreaFor(speed)))
end

-- How many donuts a base of size `level` holds (Config.Plots.Sizes; past the last size - the
-- owner and the "ender=rich" code - ExtraSlots more per size, up to Config.Admin.MaxSlots).
function Economy.SlotCount(level: number): number
	local sizes = Config.Plots.Sizes
	local l = math.max(math.floor(level), 1)
	if l <= #sizes then
		return sizes[l].Slots
	end
	return math.min(sizes[#sizes].Slots + Config.Plots.ExtraSlots * (l - #sizes), math.max(Config.Admin.MaxSlots, sizes[#sizes].Slots))
end

-- The biggest size you can buy, and the biggest the owner / the code can grow a base to.
function Economy.MaxBaseLevel(): number
	return #Config.Plots.Sizes
end

function Economy.AdminMaxBaseLevel(): number
	local sizes = Config.Plots.Sizes
	local extra = math.max(Config.Admin.MaxSlots - sizes[#sizes].Slots, 0)
	return #sizes + math.ceil(extra / Config.Plots.ExtraSlots)
end

-- The smallest size that holds at least `slots` donuts (old saves: stands + floors -> a pen).
function Economy.LevelForSlots(slots: number): number
	for level = 1, Economy.AdminMaxBaseLevel() do
		if Economy.SlotCount(level) >= slots then
			return level
		end
	end
	return Economy.AdminMaxBaseLevel()
end

-- Price of the next bigger base (nil once it's the biggest you can buy).
function Economy.BaseSizeCost(level: number): number?
	local nextSize = Config.Plots.Sizes[math.max(level, 1) + 1]
	return if nextSize then nextSize.Cost else nil
end

-- Incubator upgrades: hatch speed multiplier, egg capacity, and the price of the next level.
function Economy.IncubatorSpeed(level: number): number
	return 1 + Config.Pets.IncubatorSpeed.PerLevel * level
end

function Economy.IncubatorCapacity(level: number): number
	return Config.Pets.MaxEggs + Config.Pets.IncubatorSize.PerLevel * level
end

function Economy.IncubatorUpgradeCost(kind: string, level: number): number?
	local upgrade = if kind == "Speed" then Config.Pets.IncubatorSpeed else Config.Pets.IncubatorSize
	return upgrade.Costs[level + 1]
end

--------------------------------------------------------------------------------
-- Index rewards
--------------------------------------------------------------------------------
function Economy.IndexCashReward(donutId: string): number
	local donut = Donuts.ById[donutId]
	if not donut then
		return 0
	end
	return math.floor(donut.Income * Rarities.Get(donut.Rarity).IndexReward.Cash)
end

-- % bonus to treadmill gains you can pick instead of the cash (nil = cash only).
function Economy.IndexSpeedReward(donutId: string): number?
	local donut = Donuts.ById[donutId]
	return donut and Rarities.Get(donut.Rarity).IndexReward.Speed
end

--------------------------------------------------------------------------------
-- Game passes
--------------------------------------------------------------------------------
-- ownedPasses: { [passKey]: true }
function Economy.MoneyMultiplier(ownedPasses: { [string]: boolean }): number
	local mode = Config.MoneyPassStacking
	local result = 1
	for _, pass in Config.GamePasses do
		if pass.Kind == "Money" and ownedPasses[pass.Key] then
			if mode == "Multiplicative" then
				result *= pass.Multiplier
			elseif mode == "Highest" then
				result = math.max(result, pass.Multiplier)
			else -- Additive
				result += pass.Multiplier - 1
			end
		end
	end
	return result
end

--------------------------------------------------------------------------------
-- Pets
--------------------------------------------------------------------------------
-- Total money / speed bonus of a list of equipped pet ids (0.5 = +50%), capped by Config.Pets.
function Economy.PetBonuses(petIds: { string }): (number, number)
	local money, speed = 0, 0
	for _, id in petIds do
		local pet = Pets.ById[id]
		if pet then
			money += pet.Money
			speed += pet.Speed
		end
	end
	return math.min(money, Config.Pets.MaxMoneyBonus), math.min(speed, Config.Pets.MaxSpeedBonus)
end

-- Speed passes don't stack (there are two 2x Speed passes: owning both is still 2x).
function Economy.SpeedPassMultiplier(ownedPasses: { [string]: boolean }): number
	local result = 1
	for _, pass in Config.GamePasses do
		if pass.Kind == "Speed" and ownedPasses[pass.Key] then
			result = math.max(result, pass.Multiplier)
		end
	end
	return result
end

return Economy
