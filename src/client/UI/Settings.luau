--[[
	Settings window + background music player.
	Music on/off and volume are saved per player. Tracks come from Config.Music.Tracks.

	Songs that fail to load (a private asset, a deleted asset, or a typo in the ID) are skipped
	automatically, and a warning with the ID is printed to the Output window so you can fix it.
]]

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Signal = require(Shared.Signal)

local Theme = require(script.Parent.Theme)
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

local tracks = Config.Music.Tracks

local function applyVolume()
	sound.Volume = if musicOn then volume else 0
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
	if workingTracks() == 0 then
		sound:Stop()
		status = "Couldn't load any songs - check the IDs in Config.Music.Tracks"
		refresh()
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
	sound.SoundId = "rbxassetid://" .. tostring(track.Id)
	sound.TimePosition = 0
	sound:Play()
	status = ""
	refresh()
	-- A song that never loads (private/deleted asset) never fires Ended: skip it after a while.
	task.delay(10, function()
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
	applyVolume()
	sound.Ended:Connect(function()
		playTrack(trackIndex + 1)
	end)

	modal = Modal.new("⚙️ SETTINGS", Theme.Colors.Gray, Vector2.new(520, 360))
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
