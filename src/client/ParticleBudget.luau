--[[
	ParticleBudget: fewer particles everywhere, on this player's screen only (less lag).

	Every ParticleEmitter in the game (donut auras, decorations, effects, pets...) emits
	Config.Particles.ParticleScale of its normal rate, and never more than MaxParticleRate per second.
	(The flames, spirals and smoke of the rarest donuts - FXBoost - get more: see below.)
	If a script changes an emitter's Rate later, the new rate is scaled the same way.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local ParticleBudget = {}

local scaling: { [ParticleEmitter]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- The big mid-to-late game donut effects (emitters with the FXBoost attribute) are allowed more:
-- DonutFX only keeps them switched on for the few donuts closest to you.
local BOOST_SCALE, BOOST_MAX = 0.85, 40

local function scaled(rate: number, boost: boolean): number
	local g = Config.Particles
	if boost then
		return math.min(rate * BOOST_SCALE, BOOST_MAX)
	end
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
		emitter.Rate = scaled(emitter.Rate, emitter:GetAttribute("FXBoost") == true)
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
