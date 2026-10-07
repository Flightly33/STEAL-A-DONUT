--[[
	StormClock: when the Eternal Storm comes (Config.EternalStorm.Schedule). It runs on the real
	clock, so it's the same moment on every server: every few hours, on the hour, in US Pacific
	time (daylight saving included) - 12am, 2am, 4am ... 2pm, 4pm ... every day.

	Times here are Unix time in seconds (UTC): what workspace:GetServerTimeNow() gives, on the
	server (server/EventService starts the storm) and on every client (the countdown at the top of
	the screen, UI/EventBanner).
]]

local Config = require(script.Parent.Config)

local StormClock = {}

local SCHEDULE = Config.EternalStorm.Schedule
local HOUR, DAY = 3600, 86400

-- Days since 1 January 1970 of a date.
local function daysFrom(y: number, m: number, d: number): number
	local year = if m <= 2 then y - 1 else y
	local era = (if year >= 0 then year else year - 399) // 400
	local yoe = year - era * 400
	local doy = (153 * (if m > 2 then m - 3 else m + 9) + 2) // 5 + d - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return era * 146097 + doe - 719468
end

-- The year at Unix time `t`.
local function yearAt(t: number): number
	local y = 1970 + math.floor(t / (365.2425 * DAY))
	if daysFrom(y, 1, 1) * DAY > t then
		y -= 1
	elseif daysFrom(y + 1, 1, 1) * DAY <= t then
		y += 1
	end
	return y
end

-- The `nth` Sunday of a month (days since 1970).
local function sunday(y: number, m: number, nth: number): number
	local first = daysFrom(y, m, 1)
	local weekday = (first + 4) % 7 -- (1 January 1970 was a Thursday; 0 = Sunday)
	return first + (7 - weekday) % 7 + (nth - 1) * 7
end

-- Hours between UTC and the schedule's clock at Unix time `t` (US daylight saving: an hour later
-- from 2am on the second Sunday in March until 2am on the first Sunday in November).
function StormClock.Offset(t: number): number
	local standard = SCHEDULE.UtcOffset
	if not SCHEDULE.DaylightSaving then
		return standard
	end
	local y = yearAt(t + standard * HOUR)
	local starts = sunday(y, 3, 2) * DAY + (2 - standard) * HOUR -- (2am standard time)
	local ends = sunday(y, 11, 1) * DAY + (2 - standard - 1) * HOUR -- (2am daylight time)
	return if t >= starts and t < ends then standard + 1 else standard
end

-- A time on the schedule's clock (seconds since 1970 as the clock reads) as Unix time.
local function toUnix(clockTime: number, near: number): number
	local guess = clockTime - StormClock.Offset(near) * HOUR
	return clockTime - StormClock.Offset(guess) * HOUR
end

local function slot(now: number): number
	local clockNow = now + StormClock.Offset(now) * HOUR
	return math.floor((clockNow - SCHEDULE.Hour * HOUR) / (SCHEDULE.Every * HOUR))
end

-- When storm number `k` starts (nil if the clocks skip that time: 2am the night they go forward).
local function startOf(k: number, now: number): number?
	local clockTime = SCHEDULE.Hour * HOUR + k * SCHEDULE.Every * HOUR
	local t = toUnix(clockTime, now)
	if t + StormClock.Offset(t) * HOUR ~= clockTime then
		return nil
	end
	return t
end

-- When the next storm starts (after `now`).
function StormClock.Next(now: number): number
	local k = slot(now) + 1
	while true do
		local t = startOf(k, now)
		if t and t > now then
			return t
		end
		k += 1
	end
end

-- When the last storm started (at or before `now`).
function StormClock.Previous(now: number): number
	local k = slot(now)
	while true do
		local t = startOf(k, now)
		if t and t <= now then
			return t
		end
		k -= 1
	end
end

-- If a storm's on right now: when it started.
function StormClock.Current(now: number): number?
	local start = StormClock.Previous(now)
	return if now < start + Config.EternalStorm.Duration then start else nil
end

return StormClock
