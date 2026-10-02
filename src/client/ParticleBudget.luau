--[[
	ParticleBudget: fewer particles everywhere, on this player's screen only (less lag).

	Every ParticleEmitter in the game (donut auras, decorations, effects, pets...) emits
	Config.Particles.ParticleScale of its normal rate, and never more than MaxParticleRate per second.
	If a script changes an emitter's Rate later, the new rate is scaled the same way.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local ParticleBudget = {}

local scaling: { [ParticleEmitter]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function scaled(rate: number): number
	local g = Config.Particles
	return math.min(rate * g.ParticleScale, g.MaxParticleRate)
end

local function apply(item: Instance)
	if not item:IsA("ParticleEmitter") then
		return
	end
	local emitter = item
	local function rescale()
		if scaling[emitter] then
			return
		end
		scaling[emitter] = true
		emitter.Rate = scaled(emitter.Rate)
		scaling[emitter] = nil
	end
	rescale()
	emitter:GetPropertyChangedSignal("Rate"):Connect(rescale)
end

function ParticleBudget.Init()
	for _, root in { workspace, game:GetService("Players").LocalPlayer } do
		for _, item in root:GetDescendants() do
			apply(item)
		end
		root.DescendantAdded:Connect(apply)
	end
end

return ParticleBudget
