--[[
	Economy: every formula that turns config numbers into prices, incomes and speeds.
	Shared by server (authoritative) and client (to display prices).
]]

local Config = require(script.Parent.Config)
local Donuts = require(script.Parent.Donuts)
local Rarities = require(script.Parent.Rarities)
local Areas = require(script.Parent.Areas)

local Economy = {}

--------------------------------------------------------------------------------
-- Speed
--------------------------------------------------------------------------------
-- WalkSpeed from the Speed stat, before the world bonus and carry slowdown.
function Economy.WalkSpeedFromStat(stat: number): number
	local s = Config.Speed
	local walk = s.BaseWalkSpeed + s.WalkPerDoubling * math.log(1 + math.max(stat, 0) / s.StatScale, 2)
	return math.min(walk, s.MaxWalkSpeed)
end

function Economy.StatForWalkSpeed(walkSpeed: number): number
	local s = Config.Speed
	return s.StatScale * (2 ^ ((walkSpeed - s.BaseWalkSpeed) / s.WalkPerDoubling) - 1)
end

function Economy.WorldWalkMultiplier(worldId: number?): number
	return Areas.World(worldId or 1).WalkMultiplier
end

-- How much a carried donut slows you down (1 = not at all).
function Economy.CarrySpeed(sizeId: string?): number
	return Rarities.Size(sizeId).CarrySpeed
end

-- The WalkSpeed a player actually gets.
function Economy.PlayerWalkSpeed(stat: number, worldId: number?, carrySizeId: string?): number
	local walk = Economy.WalkSpeedFromStat(stat) * Economy.WorldWalkMultiplier(worldId)
	if carrySizeId then
		walk *= Economy.CarrySpeed(carrySizeId)
	end
	return walk
end

-- Guards in later worlds get the same world bonus as players, so the recommended speeds still hold.
function Economy.GuardWalkSpeed(areaId: number): number
	local area = Areas.List[areaId]
	return (Economy.WalkSpeedFromStat(area.RecommendedSpeed) + area.GuardSpeedBonus) * Economy.WorldWalkMultiplier(area.World)
end

function Economy.SpeedMultiplier(level: number): number
	return Config.SpeedMultiplier.PerLevel ^ level
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

--------------------------------------------------------------------------------
-- Rebirths
--------------------------------------------------------------------------------
function Economy.RebirthMoneyMultiplier(rebirths: number): number
	return 1 + Config.Rebirth.MoneyBonus * rebirths
end

function Economy.RebirthSpeedMultiplier(rebirths: number): number
	return 1 + Config.Rebirth.SpeedBonus * rebirths
end

-- Requirements for the NEXT rebirth (nil when there are no more).
function Economy.NextRebirth(rebirths: number): { Speed: number, Cost: number }?
	return Config.Rebirth.Levels[rebirths + 1]
end

function Economy.MaxRebirths(): number
	return #Config.Rebirth.Levels
end

function Economy.WorldUnlocked(worldId: number, rebirths: number): boolean
	return rebirths >= Areas.World(worldId).RequiredRebirths
end

-- Speed gained per second on the treadmill.
-- indexBonus: total Index speed bonus in % (e.g. 35 = +35%).
function Economy.TreadmillRate(treadmillLevel: number, multiplierLevel: number, speedPassMultiplier: number, rebirths: number?, indexBonus: number?): number
	local index = math.min((indexBonus or 0) / 100, Config.Index.MaxSpeedBonus)
	return Economy.TreadmillTier(treadmillLevel).Rate
		* Economy.SpeedMultiplier(multiplierLevel)
		* speedPassMultiplier
		* Economy.RebirthSpeedMultiplier(rebirths or 0)
		* (1 + index)
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
function Economy.SlotCount(expansions: number): number
	local p = Config.Plots
	return math.min(p.StartSlots + p.ExpansionSlots * expansions, p.SlotsPerPlot)
end

-- Price of the next expansion (nil when fully expanded).
function Economy.ExpansionCost(expansions: number): number?
	return Config.Plots.ExpansionCosts[expansions + 1]
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

function Economy.SpeedPassMultiplier(ownedPasses: { [string]: boolean }): number
	local result = 1
	for _, pass in Config.GamePasses do
		if pass.Kind == "Speed" and ownedPasses[pass.Key] then
			result *= pass.Multiplier
		end
	end
	return result
end

return Economy
