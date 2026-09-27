--[[
	Settings window + background music player.
	Music on/off and volume are saved per player. Tracks come from Config.Music.Tracks.
]]

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local State = require(script.Parent.Parent.State)

local Settings = {}

local modal: Modal.Modal
local sound: Sound
local trackIndex = 1
local volume = Config.Music.DefaultVolume
local musicOn = true
local loaded = false -- becomes true once the saved settings arrive
local refresh: () -> () = function() end

local tracks = Config.Music.Tracks

local function applyVolume()
	sound.Volume = if musicOn then volume else 0
end

local function playTrack(index: number)
	if #tracks == 0 then
		return
	end
	trackIndex = (index - 1) % #tracks + 1
	sound:Stop()
	sound.SoundId = "rbxassetid://" .. tostring(tracks[trackIndex].Id)
	sound.TimePosition = 0
	sound:Play()
	refresh()
end

local function save()
	State.Action("SetMusic", { Volume = volume, On = musicOn })
end

function Settings.Open()
	modal:Open()
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
		nowPlaying.Text = if #tracks == 0 then "No songs added yet (Config.Music.Tracks)" else "Now playing: " .. tracks[trackIndex].Name
	end

	toggle.Activated:Connect(function()
		musicOn = not musicOn
		applyVolume()
		refresh()
		save()
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
	end)

	refresh()
	playTrack(1)
end

return Settings
