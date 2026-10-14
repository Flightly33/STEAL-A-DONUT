--[[
	HellChainsFX: brings the hell donuts' chains (shared/HellChains) to life, on this client, for
	the chained donuts near the camera:

	  - the sealing circle turns slowly and its glow breathes
	  - the chains glow brighter and thicken while the donut strains against them (DonutIdle's
	    Tug), and the shackles flare
	  - each tug: a burst of spikes and an impact puff round the donut and a spray of embers
	    (no sound: donuts are silent)
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimeFX = require(Shared.AnimeFX)

local DonutIdle = require(script.Parent.DonutIdle)

local HellChainsFX = {}

local RANGE = 120 -- studs from the camera

type Rig = { Model: Model, Root: BasePart, Beams: { Beam }, Shackles: { BasePart }, Seal: GuiObject?, SealRings: Model?, Embers: ParticleEmitter?, Core: BasePart?, Spin: number }
local rigs: { [Model]: Rig } = {}

local function register(model: Instance)
	if not model:IsA("Model") or rigs[model] then
		return
	end
	local folder = model:FindFirstChild("HellChains")
	local root = model.PrimaryPart
	if not folder or not root then
		return
	end
	local rig: Rig = { Model = model, Root = root, Beams = {}, Shackles = {}, Seal = nil, SealRings = nil, Embers = nil, Core = nil, Spin = math.random() * 360 }
	for _, d in folder:GetDescendants() do
		if d:IsA("Beam") then
			table.insert(rig.Beams, d)
		elseif d:IsA("BasePart") and d.Name == "Shackle" then
			table.insert(rig.Shackles, d)
		elseif d.Name == "Seal" and d:IsA("GuiObject") then
			rig.Seal = d
		elseif d.Name == "SealRings" and d:IsA("Model") then
			rig.SealRings = d
		elseif d:IsA("ParticleEmitter") and d.Name == "Embers" then
			rig.Embers = d
		elseif d.Name == "TugCore" and d:IsA("BasePart") then
			rig.Core = d
		end
	end
	rigs[model] = rig
end

function HellChainsFX.Init()
	for _, model in CollectionService:GetTagged("HellChains") do
		register(model)
	end
	CollectionService:GetInstanceAddedSignal("HellChains"):Connect(function(model)
		-- (its parts may still be arriving)
		task.defer(register, model)
	end)
	CollectionService:GetInstanceRemovedSignal("HellChains"):Connect(function(model)
		rigs[model :: Model] = nil
	end)

	DonutIdle.Tugged:Connect(function(model: Model)
		local rig = rigs[model]
		if not rig or not rig.Core or not rig.Core.Parent then
			return
		end
		AnimeFX.Fire(AnimeFX.Find(rig.Core))
		for _, e in rig.Core:GetChildren() do
			if e:IsA("ParticleEmitter") and e.Name == "BurstSpikes" then
				e:Emit(1)
			end
		end
		if rig.Embers then
			rig.Embers:Emit(14)
		end
	end)

	local clock = 0
	RunService.RenderStepped:Connect(function(dt: number)
		clock += dt
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local eye = camera.CFrame.Position
		for model, rig in rigs do
			if not model.Parent then
				rigs[model] = nil
				continue
			end
			if (rig.Root.CFrame.Position - eye).Magnitude > RANGE then
				continue
			end
			local strain = DonutIdle.Strain(model)
			local breathe = 0.5 + 0.5 * math.sin(clock * 1.6 + rig.Spin)
			-- the chains: hotter and thicker the harder it pulls, a slow glow otherwise
			for _, beam in rig.Beams do
				local base = (beam:GetAttribute("BaseWidth") :: number?) or beam.Width0
				local w = base * (1 + 0.25 * strain)
				beam.Width0, beam.Width1 = w, w
				beam.Brightness = 1.4 + 0.4 * breathe + 2.2 * strain
			end
			for _, bar in rig.Shackles do
				bar.Transparency = 0.25 - 0.2 * strain - 0.08 * breathe
			end
			-- the seal turns slowly
			rig.Spin += dt * (8 + 40 * strain)
			if rig.Seal then
				rig.Seal.Rotation = rig.Spin
				if rig.Seal:IsA("ImageLabel") then
					rig.Seal.ImageTransparency = 0.25 - 0.2 * breathe - 0.05 * strain
				end
			elseif rig.SealRings and rig.SealRings.PrimaryPart == nil then
				-- (the block seal: just its glow breathes)
				for _, p in rig.SealRings:GetChildren() do
					if p:IsA("BasePart") then
						p.Transparency = 0.3 - 0.2 * breathe - 0.1 * strain
					end
				end
			end
		end
	end)
end

return HellChainsFX
