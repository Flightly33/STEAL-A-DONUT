--[[
	StormMusic: the Eternal Storm's song, the Radetzky March (Settings starts and stops it).

	The recording in Config.EternalStorm.MusicId (the Radetzky March from the Creator Store) plays,
	looped. With no id (or if it can't load) a built-in version plays,
	made from sounds every Roblox client already has: the march's tune on a bright bell, an
	"oom-pah" bass and chords under it, a bass drum and snare, and a drum roll to start. (It was
	written out from memory, so it's the tune's style more than an exact copy of the score.)
]]

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local StormMusic = {}

local LOUDNESS = 0.9
local BPM = 112 -- quarter notes a minute
local STEP = 60 / BPM / 4 -- one sixteenth note
local BELL = "rbxasset://sounds/electronicpingshort.wav"
local THUMP = "rbxasset://sounds/action_jump_land.mp3"
local TICK = "rbxasset://sounds/button.wav"
local D5_SPEED = 0.6 -- the bell's speed for the note D5 (every other note is worked out from it)

-- Note names -> MIDI numbers (D major: F# and C# are sharp)
local NOTES: { [string]: number } = {
	A3 = 57, D4 = 62, E4 = 64, Fs4 = 66, G4 = 67, A4 = 69, B4 = 71, Cs5 = 73, D5 = 74, E5 = 76, Fs5 = 78, G5 = 79, A5 = 81, B5 = 83, Cs6 = 85, D6 = 86,
	A2 = 45, D3 = 50, E3 = 52, Fs3 = 54,
}

-- The tune: { note, sixteenths } per bar ("R" = rest). Chords: "D" (D F# A) or "A" (A C# E).
type Bar = { Notes: { { any } }, Chord: string }
local function bar(chord: string, notes: { { any } }): Bar
	return { Notes = notes, Chord = chord }
end
local THEME: { Bar } = {
	bar("D", { { "D5", 2 }, { "D5", 1 }, { "D5", 1 }, { "D5", 1 }, { "Cs5", 1 }, { "D5", 1 }, { "E5", 1 } }),
	bar("D", { { "Fs5", 2 }, { "Fs5", 1 }, { "Fs5", 1 }, { "Fs5", 1 }, { "E5", 1 }, { "Fs5", 1 }, { "G5", 1 } }),
	bar("A", { { "A5", 2 }, { "A5", 1 }, { "A5", 1 }, { "A5", 1 }, { "B5", 1 }, { "A5", 1 }, { "G5", 1 } }),
	bar("D", { { "Fs5", 2 }, { "A5", 2 }, { "D6", 2 }, { "R", 2 } }),
	bar("A", { { "B4", 2 }, { "B4", 1 }, { "B4", 1 }, { "B4", 1 }, { "A4", 1 }, { "B4", 1 }, { "Cs5", 1 } }),
	bar("D", { { "D5", 2 }, { "D5", 1 }, { "D5", 1 }, { "D5", 1 }, { "Cs5", 1 }, { "D5", 1 }, { "E5", 1 } }),
	bar("A", { { "Fs5", 2 }, { "E5", 2 }, { "D5", 2 }, { "Cs5", 2 } }),
	bar("D", { { "D5", 4 }, { "R", 2 }, { "A4", 2 } }),
	-- and louder, up high
	bar("A", { { "A5", 2 }, { "A5", 2 }, { "A5", 2 }, { "A5", 2 } }),
	bar("A", { { "B5", 2 }, { "A5", 2 }, { "G5", 2 }, { "Fs5", 2 } }),
	bar("A", { { "E5", 2 }, { "E5", 2 }, { "E5", 2 }, { "E5", 2 } }),
	bar("A", { { "Fs5", 2 }, { "E5", 2 }, { "D5", 2 }, { "Cs5", 2 } }),
	bar("D", { { "D5", 2 }, { "Fs5", 2 }, { "A5", 2 }, { "D6", 2 } }),
	bar("A", { { "Cs6", 2 }, { "B5", 2 }, { "A5", 2 }, { "G5", 2 } }),
	bar("A", { { "Fs5", 2 }, { "E5", 2 }, { "D5", 2 }, { "Cs5", 2 } }),
	bar("D", { { "D5", 4 }, { "R", 2 }, { "A4", 2 } }),
}
local CHORDS: { [string]: { Root: string, Fifth: string, Upper: { string } } } = {
	D = { Root = "D3", Fifth = "A2", Upper = { "Fs4", "A4" } },
	A = { Root = "A2", Fifth = "E3", Upper = { "E4", "Cs5" } },
}

local group: SoundGroup? = nil
local voices: { [string]: { Sounds: { Sound }, Next: number } } = {}
local recording: Sound? = nil
local playing = false
local token = 0

local function voice(name: string, id: string, volume: number, count: number)
	local list = {}
	for i = 1, count do
		local sound = Instance.new("Sound")
		sound.Name = name .. i
		sound.SoundId = id
		sound.Volume = volume
		sound.SoundGroup = group
		sound.Parent = group
		table.insert(list, sound)
	end
	voices[name] = { Sounds = list, Next = 1 }
end

local function setup()
	if group then
		return
	end
	local g = Instance.new("SoundGroup")
	g.Name = "StormMusic"
	g.Volume = 0
	g.Parent = SoundService
	group = g
	local eq = Instance.new("EqualizerSoundEffect")
	eq.LowGain = 3
	eq.MidGain = 0
	eq.HighGain = -9 -- (the bell is bright: soften it)
	eq.Priority = 3
	eq.Parent = g
	local compressor = Instance.new("CompressorSoundEffect")
	compressor.Threshold = -18
	compressor.Ratio = 3
	compressor.Priority = 2
	compressor.Parent = g
	local reverb = Instance.new("ReverbSoundEffect")
	reverb.DecayTime = 1.4
	reverb.WetLevel = -10
	reverb.Priority = 1
	reverb.Parent = g
	voice("Lead", BELL, 0.55, 3)
	voice("Chord", BELL, 0.16, 4)
	voice("Bass", BELL, 0.4, 2)
	voice("Kick", THUMP, 0.45, 2)
	voice("Snare", TICK, 0.12, 3)
	local id = Config.EternalStorm.MusicId
	if id ~= "" then
		local sound = Instance.new("Sound")
		sound.Name = "Recording"
		sound.SoundId = id
		sound.Looped = true
		sound.Volume = 0.8
		sound.SoundGroup = g
		sound.Parent = g
		recording = sound
	end
end

local function play(name: string, speed: number)
	local v = voices[name]
	if not v then
		return
	end
	local sound = v.Sounds[v.Next]
	v.Next = v.Next % #v.Sounds + 1
	sound.PlaybackSpeed = speed
	sound.TimePosition = 0
	sound:Play()
end

local function bell(note: string): number
	return D5_SPEED * 2 ^ ((NOTES[note] - NOTES.D5) / 12)
end

-- Make the sounds now (and load them), so the storm's first note isn't late.
function StormMusic.Preload()
	setup()
	task.spawn(function()
		local list: { Instance } = {}
		for _, v in voices do
			table.insert(list, v.Sounds[1])
		end
		if recording then
			table.insert(list, recording)
		end
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
	end)
end

function StormMusic.IsPlaying(): boolean
	return playing
end

-- `volume`: the player's music volume (0-1).
function StormMusic.SetVolume(volume: number)
	if group and playing then
		TweenService:Create(group, TweenInfo.new(0.5), { Volume = volume * LOUDNESS * Config.EternalStorm.MusicVolume }):Play()
	end
end

-- The built-in march, looped: a drum roll, then the tune over and over.
local function march(myToken: number)
	local start = os.clock()
	local step = 0
	local function waitSteps(count: number)
		step += count
		local delay = start + step * STEP - os.clock()
		if delay > 0 then
			task.wait(delay)
		end
	end
	-- drum roll (two bars), then a big chord
	for i = 1, 16 do
		if not playing or token ~= myToken then
			return
		end
		play("Snare", 0.9 + (i % 2) * 0.1)
		waitSteps(1)
	end
	play("Kick", 0.42)
	play("Bass", bell("D3"))
	for _, note in CHORDS.D.Upper do
		play("Chord", bell(note))
	end
	waitSteps(6)
	play("Lead", bell("A4")) -- the pick-up into the tune
	waitSteps(2)
	while playing and token == myToken do
		for _, b in THEME do
			local chord = CHORDS[b.Chord]
			-- oom-pah under the tune: bass and drum on the beat, chord on the off-beat
			local accompaniment: { [number]: string } = { [0] = "Root", [2] = "Chord", [4] = "Fifth", [6] = "Chord" }
			local melodyAt: { [number]: string } = {}
			local at = 0
			for _, entry in b.Notes do
				melodyAt[at] = entry[1]
				at += entry[2]
			end
			for s = 0, 7 do
				if not playing or token ~= myToken then
					return
				end
				local note = melodyAt[s]
				if note and note ~= "R" then
					play("Lead", bell(note))
				end
				local part = accompaniment[s]
				if part == "Root" or part == "Fifth" then
					play("Bass", bell(if part == "Root" then chord.Root else chord.Fifth))
					play("Kick", 0.42)
				elseif part == "Chord" then
					for _, upper in chord.Upper do
						play("Chord", bell(upper))
					end
					play("Snare", 1)
				end
				waitSteps(1)
			end
		end
	end
end

function StormMusic.Start(volume: number)
	setup()
	if playing then
		StormMusic.SetVolume(volume)
		return
	end
	playing = true
	token += 1
	local myToken = token
	local g = group :: SoundGroup
	TweenService:Create(g, TweenInfo.new(0.8), { Volume = volume * LOUDNESS * Config.EternalStorm.MusicVolume }):Play()
	local track = recording
	if track then
		track.TimePosition = 0
		track:Play()
		-- a recording that can't load (deleted, private) falls back to the built-in march
		task.delay(8, function()
			if playing and token == myToken and track and not track.IsLoaded then
				track:Stop()
				task.spawn(march, myToken)
			end
		end)
	else
		task.spawn(march, myToken)
	end
end

function StormMusic.Stop()
	if not playing then
		return
	end
	playing = false
	token += 1
	local g = group
	if g then
		TweenService:Create(g, TweenInfo.new(0.8), { Volume = 0 }):Play()
		local myToken = token
		task.delay(0.9, function()
			if token == myToken and recording then
				recording:Stop()
			end
		end)
	end
end

return StormMusic
