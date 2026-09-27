--[[
	Number and time formatting: 1234 -> "1.2K", 60_200_000_000 -> "60.2B".
]]

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg" }

function Format.Number(value: number): string
	if value ~= value then
		return "0"
	end
	if value == math.huge then
		return "inf"
	end
	local negative = value < 0
	value = math.abs(value)

	local text
	if value < 1000 then
		if value < 10 and value ~= math.floor(value) then
			text = string.format("%.1f", math.floor(value * 10) / 10)
		else
			text = tostring(math.floor(value))
		end
	else
		local tier = math.min(math.floor(math.log10(value) / 3), #SUFFIXES - 1)
		local scaled = value / 10 ^ (tier * 3)
		-- Truncate (never round up) so "$999.99" shows as "999.9", not "1000.0".
		if scaled >= 100 then
			text = string.format("%d", math.floor(scaled))
		else
			text = string.format("%.1f", math.floor(scaled * 10) / 10):gsub("%.0$", "")
		end
		text ..= SUFFIXES[tier + 1]
	end

	return if negative then "-" .. text else text
end

-- Multipliers: 1.25 -> "1.25", 35.53 -> "35.5", 2 -> "2", 12345 -> "12.3K"
function Format.Multiplier(value: number): string
	if value >= 1000 then
		return Format.Number(value)
	end
	local text = if value < 10 then string.format("%.2f", value) elseif value < 100 then string.format("%.1f", value) else string.format("%d", math.floor(value))
	if string.find(text, "%.") then
		text = string.gsub(text, "0+$", "")
		text = string.gsub(text, "%.$", "")
	end
	return text
end

function Format.Money(value: number): string
	return "$" .. Format.Number(value)
end

-- 3725 -> "1h 2m", 65 -> "1m 5s", 9 -> "9s"
function Format.Duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local days = seconds // 86400
	local hours = (seconds % 86400) // 3600
	local minutes = (seconds % 3600) // 60
	local secs = seconds % 60
	if days > 0 then
		return string.format("%dd %dh", days, hours)
	elseif hours > 0 then
		return string.format("%dh %dm", hours, minutes)
	elseif minutes > 0 then
		return string.format("%dm %ds", minutes, secs)
	end
	return string.format("%ds", secs)
end

function Format.Commas(value: number): string
	local text = tostring(math.floor(value))
	local result = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (result:gsub("^,", ""))
end

return Format
