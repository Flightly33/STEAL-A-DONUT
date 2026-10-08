--[[
	BiomeAmbience: the sound of the biomes (Config.BiomeAmbience). Its loops all play together, on
	repeat, while you're out in the lane - in any biome - and fade out when you're back in the lobby,
	or while the Eternal Storm is on (it has its own ambience: client/StormFX).
]]

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local AreaTracker = require(script.Parent.AreaTracker)

local BiomeAmbience = {}

local AMBIENCE = Config.BiomeAmbience

type Loop = { Sound: Sound, Volume: number }
local loops: { Loop } = {}
local on = false -- (wanted: fading in or playing)
local playing = false -- (the loops are playing, maybe fading out)
local token = 0

-- Fade every loop in (in a biome) or out (in the lobby, or in the storm).
local function update()
	local want = AreaTracker.Current > 0 and workspace:GetAttribute("EventId") ~= "EternalStorm"
	if want == on then
		return
	end
	on = want
	token += 1
	local myToken = token
	local info = TweenInfo.new(AMBIENCE.Fade, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local start = want and not playing
	if want then
		playing = true
	end
	for _, loop in loops do
		if start then
			loop.Sound.Volume = 0
			loop.Sound:Play()
		end
		TweenService:Create(loop.Sound, info, { Volume = if want then loop.Volume else 0 }):Play()
	end
	if not want then
		-- (stopped once they've faded, unless you've walked back into a biome since)
		task.delay(AMBIENCE.Fade + 0.1, function()
			if token == myToken then
				playing = false
				for _, loop in loops do
					loop.Sound:Stop()
				end
			end
		end)
	end
end

function BiomeAmbience.IsOn(): boolean
	return on
end

function BiomeAmbience.Init()
	local folder = Instance.new("Folder")
	folder.Name = "BiomeAmbience"
	folder.Parent = SoundService
	for i, layer in AMBIENCE.Loops do
		if layer.Id ~= "" then
			local sound = Instance.new("Sound")
			sound.Name = "Loop" .. i
			sound.SoundId = layer.Id
			sound.Looped = true
			sound.Volume = 0
			sound.Parent = folder
			table.insert(loops, { Sound = sound, Volume = layer.Volume })
		end
	end
	task.spawn(function()
		local list = {}
		for _, loop in loops do
			table.insert(list, loop.Sound)
		end
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
	end)
	AreaTracker.Changed:Connect(update)
	workspace:GetAttributeChangedSignal("EventId"):Connect(update)
	update()
end

return BiomeAmbience
