--[[
	UnderworldFX: The Underworld's (World 2's) living lava and firelight, on the client.
	  * lava (tagged "Lava" by Decor) churns: its glow swells and fades, each piece in its own rhythm
	  * geysers (tagged "Geyser") erupt every few seconds
	  * while you're in The Underworld the colour grading flickers warmly, like firelight
	Only things near the camera are animated.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local AreaTracker = require(script.Parent.AreaTracker)
local State = require(script.Parent.State)

local UnderworldFX = {}

local WORLD = 2
local LAVA_DISTANCE = 450
local GEYSER_DISTANCE = 400
local HOT = Color3.new(1, 1, 0.8)

type Lava = { Base: Color3, Phase: number, Speed: number }
type Geyser = { Emitter: ParticleEmitter, Position: Vector3, NextAt: number, StopAt: number }

local function track<T>(tag: string, onAdd: (Instance) -> T?): { [Instance]: T }
	local set: { [Instance]: T } = {}
	local function add(instance: Instance)
		local value = onAdd(instance)
		if value ~= nil and instance.Parent then
			set[instance] = value
		end
	end
	for _, instance in CollectionService:GetTagged(tag) do
		task.spawn(add, instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		set[instance] = nil
	end)
	return set
end

local function inUnderworld(): boolean
	local area = AreaTracker.Current
	if area > 0 then
		local info = Areas.List[area]
		return info ~= nil and info.World == WORLD
	end
	return area == 0 and State.Number("World") == WORLD
end

function UnderworldFX.Init()
	local rng = Random.new()
	local lavas: { [Instance]: Lava } = track("Lava", function(instance): Lava?
		if not instance:IsA("BasePart") then
			return nil
		end
		return { Base = instance.Color, Phase = rng:NextNumber(0, 6.28), Speed = rng:NextNumber(0.8, 1.6) }
	end)
	local geysers: { [Instance]: Geyser } = track("Geyser", function(instance): Geyser?
		local emitter = instance:WaitForChild("Eruption", 10)
		if not instance:IsA("BasePart") or not emitter or not emitter:IsA("ParticleEmitter") then
			return nil
		end
		return { Emitter = emitter, Position = instance.Position, NextAt = os.clock() + rng:NextNumber(1, 6), StopAt = 0 }
	end)

	local firelight = Instance.new("ColorCorrectionEffect")
	firelight.Name = "Firelight"
	firelight.Enabled = false
	firelight.Parent = Lighting
	local strength = 0
	local sinceLava = 0

	RunService.RenderStepped:Connect(function(dt: number)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local cam = camera.CFrame.Position
		local t = os.clock()

		-- Lava churns (20 times a second is plenty)
		sinceLava += dt
		if sinceLava >= 0.05 then
			sinceLava = 0
			for instance, lava in lavas do
				local part = instance :: BasePart
				if not part.Parent then
					lavas[instance] = nil
				elseif (part.Position - cam).Magnitude < LAVA_DISTANCE then
					local wave = 0.5 + 0.5 * math.sin(t * lava.Speed + lava.Phase)
					part.Color = lava.Base:Lerp(HOT, 0.06 + 0.22 * wave)
				end
			end
		end

		-- Geysers erupt now and then
		for instance, geyser in geysers do
			if not instance.Parent then
				geysers[instance] = nil
			elseif (geyser.Position - cam).Magnitude < GEYSER_DISTANCE then
				if t >= geyser.NextAt then
					geyser.Emitter.Enabled = true
					geyser.StopAt = t + 1.2
					geyser.NextAt = t + rng:NextNumber(4, 8)
				elseif geyser.Emitter.Enabled and t >= geyser.StopAt then
					geyser.Emitter.Enabled = false
				end
			elseif geyser.Emitter.Enabled then
				geyser.Emitter.Enabled = false
			end
		end

		-- Firelight: a warm, flickering grade that fades in when you arrive
		local target = if inUnderworld() then 1 else 0
		strength += (target - strength) * math.min(1, dt * 1.5)
		firelight.Enabled = strength > 0.01
		if firelight.Enabled then
			local flicker = math.noise(t * 3.1, 0.37)
			firelight.Brightness = strength * 0.025 * flicker
			firelight.Contrast = strength * (0.05 + 0.03 * math.noise(t * 1.7, 4.2))
			firelight.TintColor = Color3.new(1, 1 - strength * (0.04 + 0.02 * flicker), 1 - strength * 0.1)
		end
	end)
end

return UnderworldFX
