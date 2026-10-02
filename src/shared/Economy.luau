--[[
	Economy: every formula that turns config numbers into prices, incomes and speeds.
	Shared by server (authoritative) and client (to display prices).
]]

local Config = require(script.Parent.Config)
local Donuts = require(script.Parent.Donuts)
local Rarities = require(script.Parent.Rarities)
local Areas = require(script.Parent.Areas)
local Pets = require(script.Parent.Pets)
local Layout = require(script.Parent.Layout)

local Economy = {}

--------------------------------------------------------------------------------
-- Speed
--------------------------------------------------------------------------------
-- WalkSpeed from the Speed stat, before the world bonus and carry slowdown. A straight line:
-- every Config.Speed.SpeedPerWalk Speed is +1 WalkSpeed.
function Economy.WalkSpeedFromStat(stat: number): number
	local s = Config.Speed
	return s.BaseWalkSpeed + math.max(stat, 0) / s.SpeedPerWalk -- no cap: keep training, keep getting faster
end

function Economy.StatForWalkSpeed(walkSpeed: number): number
	local s = Config.Speed
	return math.max(0, (walkSpeed - s.BaseWalkSpeed) * s.SpeedPerWalk)
end

-- The old logarithmic curve (saves from before the Speed stat became linear are converted with it).
function Economy.LegacyWalkSpeed(stat: number): number
	return math.min(16 + 3 * math.log(1 + math.max(stat, 0) / 5, 2), 180)
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
	return (Config.Speed.GuardBaseWalkSpeed + area.RecommendedSpeed / Config.Speed.SpeedPerWalk + area.GuardSpeedBonus) * Economy.WorldWalkMultiplier(area.World) * Config.Guard.SpeedMultiplier
end

-- The Speed that gets you home with at least the front half of an area's donuts: a straight race
-- to the safe zone against Domer, who wakes up after the area's WakeDelay and catches you within
-- CatchRadius. It's worked out from the guard settings, so the signs stay honest when you make
-- Domer faster or slower. (Areas' RecommendedSpeed is the base the guard's speed is tuned from.)
local recommendedCache: { [number]: number } = {}
function Economy.RecommendedSpeed(areaId: number): number
	local cached = recommendedCache[areaId]
	if cached then
		return cached
	end
	local area = Areas.List[areaId]
	local worldMult = Economy.WorldWalkMultiplier(area.World)
	local guardZ = Layout.AreaEnd(areaId) - Layout.GuardBackOffset
	local firstSpawn = Layout.AreaStart(areaId) + Layout.SpawnStartMargin
	local lastSpawn = guardZ - Layout.SpawnGuardMargin
	local donutZ = (firstSpawn + lastSpawn) / 2 -- the middle of the spawn range
	local guard = Economy.GuardWalkSpeed(areaId)
	local wake = area.WakeDelay
	local function escapes(walk: number): boolean
		if walk >= guard then
			return true
		end
		local home = (donutZ - Config.Map.SafeZoneZ) / walk
		local caughtAt = wake + ((guardZ - donutZ) + walk * wake - Config.Guard.CatchRadius) / (guard - walk)
		return caughtAt >= home
	end
	local lo, hi = Config.Speed.BaseWalkSpeed * worldMult, guard
	if escapes(lo) then
		hi = lo
	else
		for _ = 1, 40 do
			local mid = (lo + hi) / 2
			if escapes(mid) then
				hi = mid
			else
				lo = mid
			end
		end
	end
	local stat = math.max(0, Economy.StatForWalkSpeed(hi / worldMult))
	local result = math.max(area.RecommendedSpeed, math.ceil(stat / 10 - 1e-9) * 10)
	recommendedCache[areaId] = result
	return result
end

-- WalkSpeed of a player with exactly the area's recommended Speed (world bonus included).
function Economy.RecommendedWalkSpeed(areaId: number): number
	local area = Areas.List[areaId]
	return Economy.WalkSpeedFromStat(Economy.RecommendedSpeed(areaId)) * Economy.WorldWalkMultiplier(area.World)
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

function Economy.WorldUnlocked(worldId: number, rebirths: number, ultimate: number?): boolean
	local world = Areas.World(worldId)
	return rebirths >= world.RequiredRebirths and (ultimate or 0) >= (world.RequiredUltimate or 0)
end

-- What a world needs, for messages: "2 Rebirths" / "an ULTIMATE REBIRTH".
function Economy.WorldRequirementText(worldId: number): string
	local world = Areas.World(worldId)
	if (world.RequiredUltimate or 0) > 0 then
		return "an ULTIMATE REBIRTH (find it in The Black Hole)"
	end
	return if world.RequiredRebirths == 1 then "1 Rebirth" else `{world.RequiredRebirths} Rebirths`
end

-- Head Start bonus on treadmill gains for a player with this much Speed: x4 at 0, fading evenly
-- to x1 at Config.Treadmill.HeadStart.UntilSpeed.
function Economy.HeadStartMultiplier(speed: number): number
	local headStart = Config.Treadmill.HeadStart
	return 1 + (headStart.Multiplier - 1) * math.clamp(1 - speed / headStart.UntilSpeed, 0, 1)
end

-- Speed gained per second on the treadmill.
-- indexBonus: total Index speed bonus in % (e.g. 35 = +35%).
-- petBonus: total speed bonus of your equipped pets (0.25 = +25%).
-- speed: the player's current Speed (for the Head Start bonus; leave it out for the plain rate).
function Economy.TreadmillRate(treadmillLevel: number, multiplierLevel: number, speedPassMultiplier: number, rebirths: number?, indexBonus: number?, petBonus: number?, speed: number?): number
	local index = math.min((indexBonus or 0) / 100, Config.Index.MaxSpeedBonus)
	local pets = math.min(petBonus or 0, Config.Pets.MaxSpeedBonus)
	return Economy.TreadmillTier(treadmillLevel).Rate
		* Economy.SpeedMultiplier(multiplierLevel)
		* speedPassMultiplier
		* Economy.RebirthSpeedMultiplier(rebirths or 0)
		* (1 + index)
		* (1 + pets)
		* (if speed then Economy.HeadStartMultiplier(speed) else 1)
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
-- The furthest area a player is fast enough for (in a world they've unlocked).
function Economy.BestAreaFor(speed: number, rebirths: number, ultimate: number?): number
	local best = 1
	for _, area in Areas.List do
		-- (World 2's areas copy Donut Land's speeds; "furthest" means the most valuable donuts)
		if Economy.WorldUnlocked(area.World, rebirths, ultimate) and speed >= Economy.RecommendedSpeed(area.Id) and area.World ~= 5 then
			best = math.max(best, area.Id)
		end
	end
	return best
end

-- Crate coins: `seconds` of income from the best normal donut (no Secrets / Admins) of the
-- furthest area your Speed is good for, with your rebirth money bonus. Grows as you progress.
function Economy.CrateCoins(seconds: number, speed: number, rebirths: number): number
	local best = 0
	for _, donut in Donuts.ByArea[Economy.BestAreaFor(speed, rebirths)] do
		if donut.Rarity ~= "Secret" and donut.Rarity ~= "Admin" and donut.Rarity ~= "Icon" then
			best = math.max(best, donut.Income)
		end
	end
	return math.floor(seconds * best * Economy.RebirthMoneyMultiplier(rebirths))
end

function Economy.SlotCount(expansions: number, floors: number?): number
	local p = Config.Plots
	local ground = math.min(p.StartSlots + p.ExpansionSlots * expansions, p.SlotsPerPlot)
	local upper = math.clamp((floors or 1) - 1, 0, #p.UpperFloors.Costs)
	return ground + p.UpperFloors.Slots * upper
end

function Economy.MaxFloors(): number
	return 1 + #Config.Plots.UpperFloors.Costs
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

-- Price of the next floor (2nd, then 3rd): nil until the ground floor is fully expanded, or once
-- every floor is built.
function Economy.NextFloorCost(expansions: number, floors: number): number?
	if floors >= Economy.MaxFloors() or Economy.SlotCount(expansions, 1) < Config.Plots.SlotsPerPlot then
		return nil
	end
	return Config.Plots.UpperFloors.Costs[math.max(floors, 1)]
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
