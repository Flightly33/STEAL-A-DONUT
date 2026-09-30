--[[
	UltimateRebirth: the big red button in The Black Hole's secret lab.
	  * UltimateAsk      -> "are you sure?" (what resets, what you keep)
	  * UltimateRebirth  -> the screen flashes white, an explosion goes off and "WORLD 2" appears
	                        while the server moves you there
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local State = require(script.Parent.Parent.State)

local UltimateRebirth = {}

local function explode()
	-- Roblox's own explosion (sound + blast), in front of the camera, harmless (made on this client)
	local camera = workspace.CurrentCamera
	if camera then
		local blast = Instance.new("Explosion")
		blast.Position = camera.CFrame.Position + camera.CFrame.LookVector * 25
		blast.BlastPressure = 0
		blast.BlastRadius = 0
		blast.DestroyJointRadiusPercent = 0
		blast.ExplosionType = Enum.ExplosionType.NoCraters
		blast.Parent = workspace
	end
	local id = Config.UltimateRebirth.ExplosionSoundId
	if id ~= "" then
		local sound = Instance.new("Sound")
		sound.SoundId = id
		sound.Volume = Config.UltimateRebirth.ExplosionVolume
		SoundService:PlayLocalSound(sound)
		task.delay(8, function()
			sound:Destroy()
		end)
	end
end

local function flash(gui: ScreenGui, worldName: string)
	local white = Theme.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 50, Parent = gui })
	local title = Theme.Label({
		Text = string.upper(worldName),
		Font = Theme.Title,
		TextColor3 = Color3.fromRGB(70, 90, 255),
		StrokeThickness = 6,
		StrokeColor = Color3.fromRGB(20, 20, 60),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.8, 0.22),
		TextTransparency = 1,
		ZIndex = 51,
		Parent = gui,
	})
	local sub = Theme.Label({
		Text = "Rarer donuts. 2x money. A whole new start.",
		Font = Theme.Font,
		TextColor3 = Color3.fromRGB(60, 60, 90),
		StrokeThickness = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.fromScale(0.6, 0.06),
		TextTransparency = 1,
		ZIndex = 51,
		Parent = gui,
	})
	local titleStroke = title:FindFirstChildOfClass("UIStroke")
	if titleStroke then
		titleStroke.Transparency = 1
	end
	explode()
	TweenService:Create(white, TweenInfo.new(0.35), { BackgroundTransparency = 0 }):Play()
	task.wait(0.5)
	local scale = Theme.new("UIScale", { Scale = 0.4, Parent = title })
	TweenService:Create(scale, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(title, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
	TweenService:Create(sub, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
	if titleStroke then
		titleStroke.Transparency = 0
	end
	task.wait(2.4)
	local out = TweenInfo.new(1.1)
	TweenService:Create(white, out, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(title, out, { TextTransparency = 1 }):Play()
	TweenService:Create(sub, out, { TextTransparency = 1 }):Play()
	if titleStroke then
		TweenService:Create(titleStroke, out, { Transparency = 1 }):Play()
	end
	task.wait(1.2)
	white:Destroy()
	title:Destroy()
	sub:Destroy()
end

function UltimateRebirth.Init()
	local gui = Theme.ScreenGui("UltimateRebirth", 100)
	gui.IgnoreGuiInset = true

	local modal = Modal.new("💥 ULTIMATE REBIRTH", Color3.fromRGB(220, 30, 40), Vector2.new(500, 380))
	local body = modal.Body
	Theme.Label({ Text = "Are you SURE?", Font = Theme.Title, TextColor3 = Color3.fromRGB(255, 80, 80), Size = UDim2.new(1, 0, 0, 44), StrokeThickness = 3, Parent = body })
	Theme.Label({
		Text = "Your Money, Speed, Rebirths and the donuts on your base reset.\nYou KEEP your pets, passes, items, base upgrades and Index.\n\nYou'll be sent to WORLD 2: rarer donuts worth 2x money!",
		Font = Theme.Font, TextScaled = false, TextSize = 19, TextWrapped = true,
		Size = UDim2.new(1, -16, 0, 150), Position = UDim2.fromOffset(8, 50), StrokeThickness = 1.5, Parent = body,
	})
	local press = Theme.Button({ Text = "PRESS IT! 💥", Color = Theme.Colors.Red, Size = UDim2.new(0.58, -6, 0, 56), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Parent = body })
	local cancel = Theme.Button({ Text = "Not yet", Color = Theme.Colors.Gray, Size = UDim2.new(0.42, -6, 0, 56), AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Parent = body })
	press.Activated:Connect(function()
		modal:Close()
		State.Action("UltimateRebirth")
	end)
	cancel.Activated:Connect(function()
		modal:Close()
	end)

	Remotes.Event("UltimateAsk").OnClientEvent:Connect(function()
		modal:Open()
	end)
	Remotes.Event("UltimateRebirth").OnClientEvent:Connect(function(worldName: string)
		task.spawn(flash, gui, if type(worldName) == "string" then worldName else "World 2")
	end)
end

return UltimateRebirth
