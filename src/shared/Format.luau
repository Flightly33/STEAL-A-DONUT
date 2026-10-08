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

-- Rates such as speed per second: 0.115 -> "0.12", 2.5 -> "2.5", 12345 -> "12.3K"
function Format.Rate(value: number): string
	return Format.Multiplier(value)
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

-- A chance (0-1) in an odds list for something bought with Robux: rounded to 4 decimal places (as
-- Roblox's rules for paid random items ask, so the list adds up to 100%), without trailing
-- zeros: "61.25%", "0.0015%".
function Format.Odds(chance: number): string
	local text = string.format("%.4f", chance * 100)
	text = (string.gsub(text, "0+$", ""))
	text = (string.gsub(text, "%.$", ""))
	return text .. "%"
end

function Format.Commas(value: number): string
	local text = tostring(math.floor(value))
	local result = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (result:gsub("^,", ""))
end

-- Is this character an emoji, or part of one? (Pictographs, the symbols and arrows that have emoji
-- forms, variation selectors, joiners, keycaps and the tag letters of flags.)
local function isEmoji(c: number): boolean
	return (c >= 0x1F000 and c <= 0x1FAFF)
		or (c >= 0x2600 and c <= 0x27BF)
		or (c >= 0x2300 and c <= 0x23FF)
		or (c >= 0x2B00 and c <= 0x2BFF)
		or (c >= 0xFE00 and c <= 0xFE0F)
		or c == 0x200D
		or c == 0x20E3
		or (c >= 0xE0020 and c <= 0xE007F)
end

-- `text` without any emoji (the game never shows one): each goes, and so does the space it leaves.
function Format.Plain(text: string): string
	if not string.find(text, "[\128-\255]") then
		return text -- (plain ASCII)
	end
	local out: { string } = {}
	local dropped = false
	local ok = pcall(function()
		for _, c in utf8.codes(text) do
			if isEmoji(c) then
				dropped = true
			elseif c == 32 and dropped and (#out == 0 or out[#out] == " ") then
				continue -- (one space is enough)
			else
				if c ~= 32 then
					dropped = false
				end
				table.insert(out, utf8.char(c))
			end
		end
	end)
	if not ok then
		return text -- (not valid UTF-8: leave it alone)
	end
	if dropped then
		while out[#out] == " " do
			table.remove(out)
		end
	end
	return table.concat(out)
end

return Format
