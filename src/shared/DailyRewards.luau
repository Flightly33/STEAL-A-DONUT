--[[
	DailyRewards: the rules of the Daily Rewards (Config.DailyRewards), the same on the server, which
	hands them out (server/DailyService), and on your screen (UI/DailyRewards).

	Saved per player: DailyClaims (how many rewards you've claimed, ever) and DailyLastDay (the day
	you claimed the last one). The next reward is Day (DailyClaims % 7) + 1, and it's ready as soon
	as the day has changed since DailyLastDay. So missing days never loses your streak: it just
	waits for you, and your next claim is the next day in the list.

	Days change at midnight on the Eternal Storm's clock (US Pacific, daylight saving included).
]]

local Config = require(script.Parent.Config)
local StormClock = require(script.Parent.StormClock)

local DailyRewards = {}

DailyRewards.Days = Config.DailyRewards.Days

local HOUR, DAY = 3600, 86400

-- Which day it is at Unix time `t` (days since 1970 on the clock).
function DailyRewards.DayNumber(t: number): number
	return math.floor((t + StormClock.Offset(t) * HOUR) / DAY)
end

-- When the next day starts (Unix time), after `t`.
function DailyRewards.NextDayAt(t: number): number
	local day = DailyRewards.DayNumber(t)
	local at = (day + 1) * DAY - StormClock.Offset(t) * HOUR
	-- (the clocks may change between now and midnight: step to the hour where the day really turns)
	if DailyRewards.DayNumber(at) <= day then
		at += HOUR
	elseif DailyRewards.DayNumber(at - HOUR) > day then
		at -= HOUR
	end
	return at
end

-- Which day (1 to 7) is claimed next, after `claims` rewards.
function DailyRewards.NextDay(claims: number): number
	return claims % #DailyRewards.Days + 1
end

-- Can the next reward be claimed at `now`?
function DailyRewards.Ready(lastDay: number, now: number): boolean
	return lastDay < DailyRewards.DayNumber(now)
end

-- What `day` gives in round `round` (0 = the first time through the 7 days). The extra pet slot
-- is only given the first time round: after that its day gives its Instead.
function DailyRewards.Reward(day: number, round: number): Config.DailyReward
	local reward = DailyRewards.Days[day]
	if reward.Kind == "PetSlot" and round > 0 and reward.Instead then
		return reward.Instead
	end
	return reward
end

-- The round the next claim is in, after `claims` rewards.
function DailyRewards.Round(claims: number): number
	return claims // #DailyRewards.Days
end

-- What a Money reward gives when you earn `income` per second.
function DailyRewards.Amount(reward: Config.DailyReward, income: number): number
	return math.max(reward.Min or 0, math.floor(math.max(0, income) * (reward.Minutes or 0) * 60))
end

-- How the 7 days look right now: how many of this round are claimed already, which one can be
-- claimed (nil if none: come back tomorrow) and which round it is.
export type View = { Claimed: number, Claimable: number?, Round: number }
function DailyRewards.View(claims: number, lastDay: number, now: number): View
	if DailyRewards.Ready(lastDay, now) then
		local day = DailyRewards.NextDay(claims)
		return { Claimed = day - 1, Claimable = day, Round = DailyRewards.Round(claims) }
	end
	-- claimed today: every day up to today's stays ticked (all 7 after Day 7) until tomorrow
	if claims <= 0 then
		return { Claimed = 0, Claimable = nil, Round = 0 }
	end
	local today = (claims - 1) % #DailyRewards.Days + 1
	return { Claimed = today, Claimable = nil, Round = DailyRewards.Round(claims - 1) }
end

return DailyRewards
