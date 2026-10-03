--[[
	ChaseMusic: the scary loop that plays while Domer chases you (Settings starts and stops it).

	Built from sounds every Roblox client already has, so it can never fail to load:
	  * a low rumbling drone (two slowed-down wind loops slightly out of tune with each other)
	  * a heartbeat ("lub-dub") that speeds up the longer the chase goes on
	  * a soft, low boom every two bars and a faint creepy note every other bar
	  * a gentle whoosh when the chase starts
	All of it runs through a soft reverb, an EQ that takes the edge off the highs and a compressor
	that evens out the peaks, so it's tense but never harsh, and no louder than the normal music.
	The sounds are made (and preloaded) when the game starts, so the first chase doesn't stutter.
	A real track in Config.Music.Chase replaces it.
]]

local ContentProvider = game:GetService("ContentProvider")

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local ChaseMusic = {}

local START_BPM, TOP_BPM, RAMP_SECONDS = 96, 138, 30
local LOUDNESS = 0.9 -- relative to the music volume setting

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
	local eq = Instance.new("EqualizerSoundEffect")
	eq.LowGain = 2 -- (a big bass boost distorts on phone speakers)
	eq.MidGain = -1
	eq.HighGain = -12 -- takes the sharp edge off everything
	eq.Priority = 3
	eq.Parent = g
	local compressor = Instance.new("CompressorSoundEffect")
	compressor.Threshold = -20
	compressor.Ratio = 4
	compressor.Attack = 0.01
	compressor.Release = 0.2
	compressor.Priority = 2
	compressor.Parent = g
	local reverb = Instance.new("ReverbSoundEffect")
	reverb.DecayTime = 1.6
	reverb.Density = 1
	reverb.WetLevel = -12
	reverb.Priority = 1
	reverb.Parent = g
	make("Drone", "rbxasset://sounds/action_falling.mp3", 0.32, 0.5, true)
	make("Drone2", "rbxasset://sounds/action_falling.mp3", 0.45, 0.18, true)
	make("Lub", "rbxasset://sounds/action_jump_land.mp3", 0.55, 0.75)
	make("Dub", "rbxasset://sounds/action_jump_land.mp3", 0.63, 0.45)
	make("Boom", "rbxasset://sounds/action_jump_land.mp3", 0.34, 0.6)
	make("Ping", "rbxasset://sounds/electronicpingshort.wav", 0.42, 0.12)
	make("Ping2", "rbxasset://sounds/electronicpingshort.wav", 0.445, 0.1)
	make("Whoosh", "rbxasset://sounds/Rocket whoosh 01.wav", 0.45, 0.5)
end

-- Make the sounds now (and load them) so starting the first chase costs nothing.
function ChaseMusic.Preload()
	setup()
	task.spawn(function()
		local list = {}
		for _, sound in sounds do
			table.insert(list, sound)
		end
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
	end)
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
			if beat % 8 == 4 then
				hit(if (beat // 8) % 2 == 0 then "Ping" else "Ping2")
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
