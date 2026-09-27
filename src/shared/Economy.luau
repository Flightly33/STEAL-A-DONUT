--[[
	Economy: every formula that turns config numbers into prices, incomes and speeds.
	Shared by server (authoritative) and client (to display prices).
]]

local Config = require(script.Parent.Config)
local Donuts = require(script.Parent.Donuts)
local Areas = require(script.Parent.Areas)

local Economy = {}

--------------------------------------------------------------------------------
-- Speed
--------------------------------------------------------------------------------
function Economy.WalkSpeedFromStat(stat: number): number
	local s = Config.Speed
	local walk = s.BaseWalkSpeed + s.WalkPerDoubling * math.log(1 + math.max(stat, 0) / s.StatScale, 2)
	return math.min(walk, s.MaxWalkSpeed)
end

function Economy.StatForWalkSpeed(walkSpeed: number): number
	local s = Config.Speed
	return s.StatScale * (2 ^ ((walkSpeed - s.BaseWalkSpeed) / s.WalkPerDoubling) - 1)
end

function Economy.GuardWalkSpeed(areaId: number): number
	local area = Areas.List[areaId]
	return Economy.WalkSpeedFromStat(area.RecommendedSpeed) + area.GuardSpeedBonus
end

function Economy.SpeedMultiplier(level: number): number
	return 1 + Config.SpeedMultiplier.PerLevel * level
end

-- Price to go from `level` to `level + 1`.
function Economy.SpeedMultiplierCost(level: number): number
	local c = Config.SpeedMultiplier
	return math.floor(c.BaseCost * c.CostGrowth ^ level)
end

function Economy.TreadmillTier(level: number)
	local tiers = Config.Treadmill.Tiers
	return tiers[math.clamp(level, 1, #tiers)]
end

function Economy.MaxTreadmillLevel(): number
	return #Config.Treadmill.Tiers
end

-- Speed gained per second on the treadmill.
function Economy.TreadmillRate(treadmillLevel: number, multiplierLevel: number, speedPassMultiplier: number): number
	return Economy.TreadmillTier(treadmillLevel).Rate * Economy.SpeedMultiplier(multiplierLevel) * speedPassMultiplier
end

--------------------------------------------------------------------------------
-- Donuts
--------------------------------------------------------------------------------
function Economy.DonutIncome(donutId: string, level: number): number
	local donut = Donuts.ById[donutId]
	if not donut then
		return 0
	end
	return donut.Income * (1 + Config.DonutUpgrade.IncomePerLevel * (level - 1))
end

-- Price to go from `level` to `level + 1`.
function Economy.DonutUpgradeCost(donutId: string, level: number): number
	local donut = Donuts.ById[donutId]
	if not donut then
		return math.huge
	end
	local u = Config.DonutUpgrade
	return math.floor(donut.Income * u.CostSeconds * u.CostGrowth ^ (level - 1))
end

function Economy.SellPrice(donutId: string, level: number): number
	return math.floor(Economy.DonutIncome(donutId, level) * Config.SellSeconds)
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
