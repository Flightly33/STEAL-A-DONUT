--[[
	ChaseMusic: the scary loop that plays while Domer chases you (Settings starts and stops it).

	Built from sounds every Roblox client already has, so it can never fail to load:
	  * a deep rumbling drone (two slowed-down wind loops slightly out of tune with each other)
	  * a pounding heartbeat ("lub-dub") that speeds up the longer the chase goes on
	  * creepy out-of-tune pings every bar, and a low boom every two bars
	  * a deep whoosh when the chase starts
	All of it runs through a reverb + bass boost. A real track in Config.Music.Chase replaces it.
]]

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local ChaseMusic = {}

local START_BPM, TOP_BPM, RAMP_SECONDS = 108, 168, 25
local LOUDNESS = 2.2 -- relative to the music volume setting

local group: SoundGroup? = nil
local sounds: { [string]: Sound } = {}
local playing = false
local token = 0

local function make(name: string, id: string, speed: number, volume: number, looped: boolean?): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.PlaybackSpeed = speed
	sound.Volume = volume
	sound.Looped = looped == true
	sound.SoundGroup = group
	sound.Parent = group
	sounds[name] = sound
	return sound
end

local function setup()
	if group then
		return
	end
	local g = Instance.new("SoundGroup")
	g.Name = "ChaseMusic"
	g.Volume = 0
	g.Parent = SoundService
	group = g
	local reverb = Instance.new("ReverbSoundEffect")
	reverb.DecayTime = 2.5
	reverb.Density = 1
	reverb.WetLevel = -4
	reverb.Parent = g
	local eq = Instance.new("EqualizerSoundEffect")
	eq.LowGain = 6
	eq.MidGain = -2
	eq.HighGain = -6
	eq.Parent = g
	make("Drone", "rbxasset://sounds/action_falling.mp3", 0.32, 0.9, true)
	make("Drone2", "rbxasset://sounds/action_falling.mp3", 0.45, 0.35, true)
	make("Lub", "rbxasset://sounds/action_jump_land.mp3", 0.55, 1.4)
	make("Dub", "rbxasset://sounds/action_jump_land.mp3", 0.63, 1)
	make("Boom", "rbxasset://sounds/action_jump_land.mp3", 0.34, 1.8)
	make("Ping", "rbxasset://sounds/electronicpingshort.wav", 0.42, 0.45)
	make("Ping2", "rbxasset://sounds/electronicpingshort.wav", 0.445, 0.4)
	make("Whoosh", "rbxasset://sounds/Rocket whoosh 01.wav", 0.45, 1.2)
end

local function hit(name: string)
	local sound = sounds[name]
	if sound then
		sound.TimePosition = 0
		sound:Play()
	end
end

function ChaseMusic.IsPlaying(): boolean
	return playing
end

-- `volume`: the player's music volume (0-1).
function ChaseMusic.SetVolume(volume: number)
	if group and playing then
		TweenService:Create(group, TweenInfo.new(0.4), { Volume = volume * LOUDNESS }):Play()
	end
end

function ChaseMusic.Start(volume: number)
	setup()
	if playing then
		ChaseMusic.SetVolume(volume)
		return
	end
	playing = true
	token += 1
	local myToken = token
	local g = group :: SoundGroup
	TweenService:Create(g, TweenInfo.new(0.5), { Volume = volume * LOUDNESS }):Play()
	sounds.Drone:Play()
	sounds.Drone2:Play()
	hit("Whoosh")
	task.spawn(function()
		local started = os.clock()
		local beat = 0
		while playing and token == myToken do
			local t = os.clock() - started
			local bpm = START_BPM + (TOP_BPM - START_BPM) * math.min(1, t / RAMP_SECONDS)
			local interval = 60 / bpm
			hit("Lub")
			if beat % 8 == 0 then
				hit("Boom")
			end
			if beat % 4 == 2 then
				hit(if (beat // 4) % 2 == 0 then "Ping" else "Ping2")
			end
			task.wait(math.min(0.17, interval * 0.3))
			if not playing or token ~= myToken then
				break
			end
			hit("Dub")
			task.wait(math.max(0.05, interval - math.min(0.17, interval * 0.3)))
			beat += 1
		end
	end)
end

function ChaseMusic.Stop()
	if not playing then
		return
	end
	playing = false
	token += 1
	local myToken = token
	local g = group :: SoundGroup
	TweenService:Create(g, TweenInfo.new(0.8), { Volume = 0 }):Play()
	task.delay(0.9, function()
		if token == myToken and not playing then
			for _, sound in sounds do
				sound:Stop()
			end
		end
	end)
end

return ChaseMusic
