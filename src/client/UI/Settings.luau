--[[
	Settings window + background music player.
	Music on/off and volume are saved per player. Tracks come from Config.Music.Tracks.

	The music never stops on its own: a single song loops, several songs play one after another
	(and start over), and a watchdog restarts playback if Roblox ever drops it. Songs that fail to
	load (a private asset, a deleted asset, or a typo in the ID) are skipped with a warning in the
	Output window; if none of them load, it keeps retrying (a slow connection while the map loads).
]]

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Signal = require(Shared.Signal)

local Theme = require(script.Parent.Theme)
local ChaseMusic = require(script.Parent.ChaseMusic)
local Modal = require(script.Parent.Modal)
local State = require(script.Parent.Parent.State)

local Settings = {}

-- Fires (on: boolean) whenever music is switched on or off (the HUD's music toggle listens).
Settings.MusicChanged = Signal.new()

local modal: Modal.Modal
local sound: Sound
local trackIndex = 1
local volume = Config.Music.DefaultVolume
local musicOn = true
local loaded = false -- becomes true once the saved settings arrive
local refresh: () -> () = function() end
local status = "" -- shown under "Now playing" when something is wrong
local playToken = 0
local failed: { [number]: boolean } = {}
local LOAD_TIMEOUT = 25 -- seconds a song may take to load before it's skipped
local RETRY_DELAY = 30 -- seconds before trying again when no song could be loaded
local retryPending = false

local tracks = Config.Music.Tracks
local usingFallback = false

-- Chase music: while Domer chases you, the normal song fades out and a scary chase loop plays
-- (ChaseMusic, made from Roblox's built-in sounds), or the track in Config.Music.Chase if it has one.
local chaseSound: Sound? = nil
local chasing = false

local function chaseReady(): boolean
	return chaseSound ~= nil and chaseSound.IsLoaded and chaseSound.TimeLength > 0
end

local function applyVolume()
	local TweenService = game:GetService("TweenService")
	local fade = TweenInfo.new(0.6)
	local useChase = chasing and chaseReady()
	TweenService:Create(sound, fade, { Volume = if not musicOn or chasing then 0 else volume }):Play()
	sound.PlaybackSpeed = 1
	if chasing and musicOn and not useChase then
		ChaseMusic.Start(volume)
	else
		ChaseMusic.Stop()
	end
	if chaseSound then
		if useChase and not chaseSound.IsPlaying then
			chaseSound.TimePosition = 0
			chaseSound:Play()
		end
		TweenService:Create(chaseSound, fade, { Volume = if useChase and musicOn then volume * 1.3 else 0 }):Play()
		if not chasing then
			task.delay(0.7, function()
				if not chasing and chaseSound then
					chaseSound:Stop()
				end
			end)
		end
	end
end

-- Chase.luau calls this when a chase starts (true) and ends (false).
function Settings.SetChasing(on: boolean)
	if on ~= chasing then
		chasing = on
		applyVolume()
	end
end

local function workingTracks(): number
	local count = 0
	for i = 1, #tracks do
		if not failed[i] then
			count += 1
		end
	end
	return count
end

local playTrack: (index: number) -> ()

playTrack = function(index: number)
	if #tracks == 0 then
		return
	end
	if workingTracks() == 0 and not usingFallback and #Config.Music.Fallback > 0 then
		-- None of the chosen songs loads: play the backup song(s) instead
		usingFallback = true
		tracks = Config.Music.Fallback
		table.clear(failed)
		playTrack(1)
		return
	end
	if workingTracks() == 0 then
		-- Nothing loaded (yet): try every song again in a while instead of going silent for good.
		sound:Stop()
		status = "Couldn't load the music - trying again soon"
		refresh()
		if not retryPending then
			retryPending = true
			task.delay(RETRY_DELAY, function()
				retryPending = false
				table.clear(failed)
				playTrack(trackIndex)
			end)
		end
		return
	end
	-- Skip songs that already failed
	for _ = 1, #tracks do
		trackIndex = (index - 1) % #tracks + 1
		if not failed[trackIndex] then
			break
		end
		index += 1
	end
	playToken += 1
	local token = playToken
	local track = tracks[trackIndex]
	sound:Stop()
	-- One song: let Roblox loop it seamlessly. Several: play them in turn (Ended / the watchdog).
	sound.Looped = workingTracks() <= 1
	sound.SoundId = "rbxassetid://" .. tostring(track.Id)
	sound.TimePosition = 0
	sound:Play()
	status = ""
	refresh()
	-- A song that never loads (private/deleted asset) never plays: skip it after a while.
	task.delay(LOAD_TIMEOUT, function()
		if token ~= playToken then
			return
		end
		if not sound.IsLoaded or sound.TimeLength <= 0 then
			failed[trackIndex] = true
			warn(`[Music] Couldn't load "{track.Name}" (rbxassetid://{track.Id}). Audio must be public or uploaded by the game's owner. Skipping it.`)
			playTrack(trackIndex + 1)
		end
	end)
end

local function save()
	State.Action("SetMusic", { Volume = volume, On = musicOn })
end

function Settings.Open()
	modal:Open()
end

function Settings.MusicOn(): boolean
	return musicOn
end

function Settings.SetMusicOn(on: boolean)
	if on == musicOn then
		return
	end
	musicOn = on
	applyVolume()
	refresh()
	save()
	Settings.MusicChanged:Fire(musicOn)
end

function Settings.Init()
	sound = Instance.new("Sound")
	sound.Name = "Soundtrack"
	sound.Looped = false
	sound.Parent = SoundService
	if Config.Music.Chase.Id > 0 then
		local chase = Instance.new("Sound")
		chase.Name = "ChaseMusic"
		chase.Looped = true
		chase.Volume = 0
		chase.SoundId = "rbxassetid://" .. tostring(Config.Music.Chase.Id)
		chase.Parent = SoundService
		chaseSound = chase
	end
	applyVolume()
	sound.Ended:Connect(function()
		if not sound.Looped then
			playTrack(trackIndex + 1)
		end
	end)
	-- Watchdog: if the music ever stops by itself (a missed Ended event, the engine dropping the
	-- sound...), start the next song. "Music off" only turns the volume down, so this never fights it.
	task.spawn(function()
		while true do
			task.wait(3)
			if #tracks > 0 and not retryPending and sound.IsLoaded and not sound.IsPlaying then
				playTrack(if sound.Looped then trackIndex else trackIndex + 1)
			end
		end
	end)

	modal = Modal.new("⚙️ SETTINGS", Theme.Colors.Gray, Vector2.new(520, 420))
	local body = modal.Body

	Theme.Label({ Text = "🎵 MUSIC", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 36), Parent = body })
	local nowPlaying = Theme.Label({ Text = "", Font = Theme.Font, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 40), StrokeThickness = 1.5, Parent = body })

	local toggle = Theme.Button({ Text = "", Color = Theme.Colors.Green, Size = UDim2.fromOffset(150, 52), Position = UDim2.fromOffset(0, 80), Parent = body })
	local skip = Theme.Button({ Text = "NEXT ⏭", Color = Theme.Colors.Blue, Size = UDim2.fromOffset(150, 52), Position = UDim2.fromOffset(160, 80), Parent = body })

	Theme.Label({ Text = "Volume", Font = Theme.Font, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 150), StrokeThickness = 1.5, Parent = body })
	local minus = Theme.Button({ Text = "−", Color = Theme.Colors.Orange, Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(0, 182), Parent = body })
	local bar = Theme.new("Frame", { Size = UDim2.fromOffset(300, 26), Position = UDim2.fromOffset(62, 195), BackgroundColor3 = Theme.Colors.Outline, Parent = body }, { Theme.Corner(8), Theme.Stroke(2) })
	local fill = Theme.new("Frame", { Size = UDim2.fromScale(volume, 1), BackgroundColor3 = Theme.Colors.Green, Parent = bar }, { Theme.Corner(8) })
	local plus = Theme.Button({ Text = "+", Color = Theme.Colors.Orange, Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(372, 182), Parent = body })
	local help = Theme.Button({ Text = "❓ HOW TO PLAY", Color = Theme.Colors.Blue, Size = UDim2.fromOffset(220, 52), Position = UDim2.fromOffset(0, 256), Parent = body })
	help.Activated:Connect(function()
		modal:Close()
		require(script.Parent.Tutorial).Open()
	end)
	local notes = Theme.Button({ Text = "📰 UPDATE LOG", Color = Theme.Colors.Orange, Size = UDim2.fromOffset(220, 52), Position = UDim2.fromOffset(230, 256), Parent = body })
	notes.Activated:Connect(function()
		require(script.Parent.UpdateNotes).Open()
	end)
	local percent = Theme.Label({ Text = "", Font = Theme.Font, Size = UDim2.fromOffset(60, 30), Position = UDim2.fromOffset(430, 193), StrokeThickness = 1.5, Parent = body })

	refresh = function()
		Theme.SetButtonText(toggle, if musicOn then "MUSIC: ON" else "MUSIC: OFF")
		Theme.SetButtonColor(toggle, if musicOn then Theme.Colors.Green else Theme.Colors.Gray)
		fill.Size = UDim2.fromScale(volume, 1)
		percent.Text = math.floor(volume * 100 + 0.5) .. "%"
		if #tracks == 0 then
			nowPlaying.Text = "No songs added yet (Config.Music.Tracks)"
		elseif status ~= "" then
			nowPlaying.Text = status
		else
			nowPlaying.Text = "Now playing: " .. tracks[trackIndex].Name
		end
	end

	toggle.Activated:Connect(function()
		Settings.SetMusicOn(not musicOn)
	end)
	skip.Activated:Connect(function()
		playTrack(trackIndex + 1)
	end)
	local function changeVolume(delta: number)
		volume = math.clamp(math.floor((volume + delta) * 10 + 0.5) / 10, 0, 1)
		applyVolume()
		refresh()
		save()
	end
	minus.Activated:Connect(function()
		changeVolume(-0.1)
	end)
	plus.Activated:Connect(function()
		changeVolume(0.1)
	end)

	-- Use the player's saved settings once they arrive
	State.Changed:Connect(function(snapshot)
		if loaded then
			return
		end
		loaded = true
		if type(snapshot.MusicVolume) == "number" then
			volume = snapshot.MusicVolume
		end
		if type(snapshot.MusicOn) == "boolean" then
			musicOn = snapshot.MusicOn
		end
		applyVolume()
		refresh()
		Settings.MusicChanged:Fire(musicOn)
	end)

	refresh()
	playTrack(1)
end

return Settings
