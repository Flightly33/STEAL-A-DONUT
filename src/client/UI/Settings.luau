--[[
	Settings window + background music player.
	Music on/off and volume are saved per player. Tracks come from Config.Music.Tracks.
	Run speed: type how fast you want to run (a WalkSpeed, at least Config.Speed.MinRunSpeed); MAX
	runs as fast as you can. Saved per player, the server applies it (Actions.SetSpeedLimit).
	Buttons along the bottom: How to Play, the Update Log, and Hide UI (clears the screen for
	screenshots; X on a keyboard does the same, see UI/HideUI). The gear for this window is at the
	top right of the screen (UI/HUD).

	The song is for the lobby: out in the lane (any biome) it fades out and the biomes' own ambience
	(client/BiomeAmbience) takes over, and it fades back in when you come back.

	The music never stops on its own: a single song loops, several songs play one after another
	(and start over), and a watchdog restarts playback if Roblox ever drops it. Songs that fail to
	load (a private asset, a deleted asset, or a typo in the ID) are skipped with a warning in the
	Output window; if none of them load, it keeps retrying (a slow connection while the map loads).
]]

local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Signal = require(Shared.Signal)

local Theme = require(script.Parent.Theme)
local StormMusic = require(script.Parent.StormMusic)
local Modal = require(script.Parent.Modal)
local HideUI = require(script.Parent.HideUI)
local State = require(script.Parent.Parent.State)
local AreaTracker = require(script.Parent.Parent.AreaTracker)

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

-- (No chase music: grabbing a box plays its own sounds, Config.Guard.GrabSounds, and that's all.)
-- The Eternal Storm: its march (StormMusic) plays instead of the normal song.
local storming = false
-- Out in the lane: the song fades out (it keeps playing silently, so it picks up again in the lobby).
local inLane = false

local function applyVolume()
	local TweenService = game:GetService("TweenService")
	local fade = TweenInfo.new(0.6)
	TweenService:Create(sound, fade, { Volume = if not musicOn or storming or inLane then 0 else volume }):Play()
	sound.PlaybackSpeed = 1
	if storming and musicOn then
		StormMusic.Start(volume)
	else
		StormMusic.Stop()
	end
end

-- StormFX calls this when the Eternal Storm starts (true) and ends (false).
function Settings.SetStorm(on: boolean)
	if on ~= storming then
		storming = on
		if on and not musicOn then
			print("[Music] The Eternal Storm's song is muted because music is switched off (the music button or Settings).")
		end
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
	StormMusic.Preload()
	sound = Instance.new("Sound")
	sound.Name = "Soundtrack"
	sound.Looped = false
	sound.Parent = SoundService
	inLane = AreaTracker.Current > 0
	AreaTracker.Changed:Connect(function(areaId: number)
		if (areaId > 0) ~= inLane then
			inLane = areaId > 0
			applyVolume()
		end
	end)
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

	modal = Modal.new("Settings", Theme.Colors.Gray, Vector2.new(520, 540))
	local body = modal.Body

	Theme.Label({ Text = "MUSIC", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 36), Parent = body })
	local nowPlaying = Theme.Label({ Text = "", Font = Theme.Font, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 40), StrokeThickness = 1.5, Parent = body })

	local toggle = Theme.Button({ Text = "", Color = Theme.Colors.Green, Size = UDim2.fromOffset(150, 52), Position = UDim2.fromOffset(0, 80), Parent = body })
	local skip = Theme.Button({ Text = "NEXT", Color = Theme.Colors.Blue, Size = UDim2.fromOffset(150, 52), Position = UDim2.fromOffset(160, 80), Parent = body })

	Theme.Label({ Text = "Volume", Font = Theme.Font, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 150), StrokeThickness = 1.5, Parent = body })
	local minus = Theme.Button({ Text = "−", Color = Theme.Colors.Orange, Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(0, 182), Parent = body })
	local bar = Theme.new("Frame", { Size = UDim2.fromOffset(300, 26), Position = UDim2.fromOffset(62, 195), BackgroundColor3 = Theme.Colors.Outline, Parent = body }, { Theme.Corner(8), Theme.Stroke(2) })
	local fill = Theme.new("Frame", { Size = UDim2.fromScale(volume, 1), BackgroundColor3 = Theme.Colors.Green, Parent = bar }, { Theme.Corner(8) })
	local plus = Theme.Button({ Text = "+", Color = Theme.Colors.Orange, Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(372, 182), Parent = body })
	-- Run speed: a number you type (Enter or clicking away saves it)
	Theme.Label({ Text = "RUN SPEED", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 246), Parent = body })
	local speedBox = Theme.new("TextBox", {
		Name = "RunSpeed", Size = UDim2.fromOffset(150, 48), Position = UDim2.fromOffset(0, 286),
		BackgroundColor3 = Theme.Colors.PanelLight, TextColor3 = Color3.new(1, 1, 1), PlaceholderText = "type a number",
		PlaceholderColor3 = Color3.fromRGB(170, 170, 190), Text = "", Font = Theme.Font, TextScaled = true, ClearTextOnFocus = true, Parent = body,
	}, { Theme.Corner(10), Theme.Stroke(2), Theme.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }) })
	local maxSpeed = Theme.Button({ Text = "MAX", Color = Theme.Colors.Green, Size = UDim2.fromOffset(100, 48), Position = UDim2.fromOffset(160, 286), Parent = body })
	local speedInfo = Theme.Label({ Text = "", Font = Theme.Font, RichText = true, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -272, 0, 48), Position = UDim2.fromOffset(272, 286), StrokeThickness = 1.5, Parent = body })
	Theme.Label({
		Text = `Type how fast you want to run ({Config.Speed.MinRunSpeed} or more). MAX = as fast as you can go.`,
		Font = Theme.Font, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 340), StrokeThickness = 1.2, Parent = body,
	})
	local function renderSpeed()
		local limit = State.Number("SpeedLimit")
		local top = math.floor(math.max(State.Number("WalkSpeed"), Config.Speed.BaseWalkSpeed))
		if not speedBox:IsFocused() then
			speedBox.Text = if limit > 0 then tostring(limit) else "MAX"
		end
		local now = if limit > 0 then math.min(limit, top) else top
		speedInfo.Text = `Running at <font color="#9dff7a"><b>{now}</b></font>\n<font size="18">Your top speed: {top}</font>`
		Theme.SetButtonColor(maxSpeed, if limit > 0 then Theme.Colors.Green else Theme.Colors.Gray)
	end
	speedBox.FocusLost:Connect(function()
		local typed = string.lower((string.gsub(speedBox.Text, "[%s,]", "")))
		local number = tonumber(typed)
		if typed == "max" or typed == "" and State.Number("SpeedLimit") == 0 then
			State.Action("SetSpeedLimit", 0)
		elseif number and number == number and number > 0 then
			State.Action("SetSpeedLimit", math.max(math.floor(number), Config.Speed.MinRunSpeed))
		end
		renderSpeed()
	end)
	maxSpeed.Activated:Connect(function()
		State.Action("SetSpeedLimit", 0)
	end)
	State.OnAttribute("SpeedLimit", renderSpeed)
	State.OnAttribute("WalkSpeed", renderSpeed)
	renderSpeed()

	-- (three buttons along the bottom)
	local help = Theme.Button({ Text = "HOW TO PLAY", Color = Theme.Colors.Blue, Size = UDim2.fromOffset(158, 52), Position = UDim2.fromOffset(0, 376), Parent = body })
	help.Activated:Connect(function()
		modal:Close()
		require(script.Parent.Tutorial).Open()
	end)
	local notes = Theme.Button({ Text = "UPDATE LOG", Color = Theme.Colors.Orange, Size = UDim2.fromOffset(158, 52), Position = UDim2.fromOffset(167, 376), Parent = body })
	notes.Activated:Connect(function()
		require(script.Parent.UpdateNotes).Open()
	end)
	-- Clear the screen for screenshots (the SHOW UI pill, or X again, brings it back)
	local hide = Theme.Button({
		Name = "HideUI",
		Text = if UserInputService.KeyboardEnabled then "HIDE UI (X)" else "HIDE UI",
		Color = Theme.Colors.Gray,
		Size = UDim2.fromOffset(158, 52),
		Position = UDim2.fromOffset(334, 376),
		Parent = body,
	})
	hide.Activated:Connect(function()
		modal:Close()
		HideUI.Set(true)
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
