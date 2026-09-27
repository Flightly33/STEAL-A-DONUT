--[[
	Weather: the client-side look of area events (see Events.luau / EventService).
	While you stand in an area with a running event you get its weather around you (sand, snow,
	rain, embers, bubbles, sparkles, shooting stars, confetti, ghosts, coins, leaves, rainbows)
	and a colour tint. A Sandstorm or Blizzard also cuts visibility with thick haze.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Events = require(Shared.Events)

local AreaTracker = require(script.Parent.AreaTracker)

local Weather = {}

local player = Players.LocalPlayer :: Player
local rgb = Color3.fromRGB

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, rgb(255, 70, 70)),
	ColorSequenceKeypoint.new(0.25, rgb(255, 220, 60)),
	ColorSequenceKeypoint.new(0.5, rgb(70, 220, 100)),
	ColorSequenceKeypoint.new(0.75, rgb(70, 150, 255)),
	ColorSequenceKeypoint.new(1, rgb(200, 90, 255)),
})

type Style = {
	Rate: number,
	Speed: NumberRange,
	Size: NumberSequence,
	Lifetime: NumberRange,
	Color: ColorSequence?,
	Direction: Enum.NormalId,
	Acceleration: Vector3?,
	Squash: number?,
	Light: number?,
	Spin: boolean?,
	Transparency: NumberSequence?,
	Height: number,
}

local STYLES: { [string]: Style } = {
	Sand = { Rate = 350, Speed = NumberRange.new(20, 40), Size = NumberSequence.new(0.35, 0.2), Lifetime = NumberRange.new(1.5, 2.5), Color = ColorSequence.new(rgb(225, 190, 130)), Direction = Enum.NormalId.Bottom, Acceleration = Vector3.new(60, 0, 20), Height = 25 },
	Snow = { Rate = 220, Speed = NumberRange.new(6, 12), Size = NumberSequence.new(0.45, 0.3), Lifetime = NumberRange.new(4, 6), Color = ColorSequence.new(rgb(255, 255, 255)), Direction = Enum.NormalId.Bottom, Acceleration = Vector3.new(6, 0, 3), Light = 0.3, Height = 40 },
	Rain = { Rate = 500, Speed = NumberRange.new(70, 90), Size = NumberSequence.new(0.12), Lifetime = NumberRange.new(0.6, 0.9), Direction = Enum.NormalId.Bottom, Squash = -3, Height = 45 },
	Embers = { Rate = 140, Speed = NumberRange.new(4, 10), Size = NumberSequence.new(0.35, 0), Lifetime = NumberRange.new(3, 5), Color = ColorSequence.new(rgb(255, 170, 40), rgb(255, 60, 0)), Direction = Enum.NormalId.Top, Light = 1, Height = -2 },
	Bubbles = { Rate = 90, Speed = NumberRange.new(3, 7), Size = NumberSequence.new(0.4, 0.8), Lifetime = NumberRange.new(4, 6), Color = ColorSequence.new(rgb(210, 245, 255)), Direction = Enum.NormalId.Top, Transparency = NumberSequence.new(0.3, 0.8), Height = -2 },
	Sparkles = { Rate = 120, Speed = NumberRange.new(1, 4), Size = NumberSequence.new(0.5, 0), Lifetime = NumberRange.new(2, 3), Direction = Enum.NormalId.Bottom, Light = 1, Height = 20 },
	Stars = { Rate = 30, Speed = NumberRange.new(90, 130), Size = NumberSequence.new(0.6, 0.2), Lifetime = NumberRange.new(0.8, 1.2), Color = ColorSequence.new(rgb(255, 240, 180)), Direction = Enum.NormalId.Bottom, Acceleration = Vector3.new(80, 0, 40), Squash = -4, Light = 1, Height = 70 },
	Confetti = { Rate = 180, Speed = NumberRange.new(6, 12), Size = NumberSequence.new(0.35), Lifetime = NumberRange.new(4, 6), Color = RAINBOW, Direction = Enum.NormalId.Bottom, Spin = true, Height = 35 },
	Ghosts = { Rate = 8, Speed = NumberRange.new(2, 5), Size = NumberSequence.new(2.5, 4), Lifetime = NumberRange.new(4, 7), Color = ColorSequence.new(rgb(220, 255, 220)), Direction = Enum.NormalId.Top, Transparency = NumberSequence.new(0.7, 1), Light = 0.5, Height = 0 },
	Coins = { Rate = 70, Speed = NumberRange.new(10, 18), Size = NumberSequence.new(0.45), Lifetime = NumberRange.new(2.5, 4), Color = ColorSequence.new(rgb(255, 210, 60)), Direction = Enum.NormalId.Bottom, Spin = true, Light = 0.4, Height = 35 },
	Leaves = { Rate = 90, Speed = NumberRange.new(4, 8), Size = NumberSequence.new(0.5), Lifetime = NumberRange.new(5, 7), Color = ColorSequence.new(rgb(255, 150, 50), rgb(200, 80, 30)), Direction = Enum.NormalId.Bottom, Acceleration = Vector3.new(5, 0, 2), Spin = true, Height = 35 },
	Rainbow = { Rate = 200, Speed = NumberRange.new(4, 10), Size = NumberSequence.new(0.5, 0), Lifetime = NumberRange.new(3, 5), Color = RAINBOW, Direction = Enum.NormalId.Bottom, Light = 1, Spin = true, Height = 30 },
}

local holder: Part? = nil
local tint: ColorCorrectionEffect
local activeId: string? = nil

local function areaFolder(areaId: number): Instance?
	local map = workspace:FindFirstChild("Map")
	local lane = map and map:FindFirstChild("Lane")
	return lane and lane:FindFirstChild("Area" .. areaId)
end

local function stop()
	activeId = nil
	if holder then
		holder:Destroy()
		holder = nil
	end
	TweenService:Create(tint, TweenInfo.new(2), { TintColor = Color3.new(1, 1, 1) }):Play()
end

local function start(event: Events.Event)
	stop()
	activeId = event.Id
	local style = STYLES[event.Weather] or STYLES.Sparkles
	local part = Instance.new("Part")
	part.Name = "EventWeather"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(110, 1, 110)
	part:SetAttribute("Height", style.Height)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = style.Rate
	emitter.Speed = style.Speed
	emitter.Size = style.Size
	emitter.Lifetime = style.Lifetime
	emitter.Color = style.Color or ColorSequence.new(event.Color)
	emitter.EmissionDirection = style.Direction
	emitter.SpreadAngle = Vector2.new(10, 10)
	emitter.Acceleration = style.Acceleration or Vector3.zero
	emitter.LightEmission = style.Light or 0
	emitter.Transparency = style.Transparency or NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0.1), NumberSequenceKeypoint.new(1, 0.6) })
	if style.Squash then
		emitter.Squash = NumberSequence.new(style.Squash)
		emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
	end
	if style.Spin then
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-180, 180)
	end
	emitter.Parent = part
	if event.Fog > 0 then
		-- Thick haze close to you (the lane further away disappears into it)
		local haze = Instance.new("ParticleEmitter")
		haze.Rate = 25 * event.Fog * 2
		haze.Speed = NumberRange.new(2, 6)
		haze.Size = NumberSequence.new(14, 20)
		haze.Lifetime = NumberRange.new(4, 6)
		haze.Color = ColorSequence.new(event.Color)
		haze.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 1 - event.Fog), NumberSequenceKeypoint.new(1, 1) })
		haze.SpreadAngle = Vector2.new(180, 180)
		haze.Parent = part
	end
	part.Parent = workspace
	holder = part
	TweenService:Create(tint, TweenInfo.new(2), { TintColor = event.Tint }):Play()
end

function Weather.Init()
	tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "EventTint"
	tint.Parent = Lighting

	-- Follow the player
	RunService.RenderStepped:Connect(function()
		local part = holder
		if not part then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local height = (part:GetAttribute("Height") :: number?) or 30
			part.CFrame = CFrame.new(root.Position + Vector3.new(0, height, 0))
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.5)
			local areaId = AreaTracker.Current
			local folder = if areaId > 0 then areaFolder(areaId) else nil
			local eventId = folder and folder:GetAttribute("EventId")
			local event = if type(eventId) == "string" then Events.ById[eventId] else nil
			if event and event.Id ~= activeId then
				start(event)
			elseif not event and activeId then
				stop()
			end
		end
	end)
end

return Weather
