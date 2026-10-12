--[[
	Bakers: a baker (shared/BakerModel) behind the counter of every base's donut shop, on this client
	only. He breathes, looks round at you when you come near, and moves along when a base gets
	bigger (its shop moves back). The opening cinematic (client/Intro) borrows your base's baker:
	Bakers.Take stops his idling and hands him over, Bakers.Release gives him back.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BakerModel = require(Shared.BakerModel)
local Puppet = require(Shared.Puppet)

local Bakers = {}

local SCALE = 1.5
local NEAR = 170 -- studs from the camera: closer than this, he moves
local LOOK = 45 -- ...and closer than this to you, he looks at you

export type Baker = { Puppet: Puppet.Puppet, Counter: BasePart, Home: CFrame, Taken: boolean, Phase: number }

local bakers: { [number]: Baker } = {}
local folder: Folder? = nil
local player = Players.LocalPlayer

-- Where he stands for a counter: behind it, facing out of the window (the counter's front).
function Bakers.HomeFor(counter: BasePart): CFrame
	local s = SCALE
	-- (feet on the shop floor, 2 studs under the counter's middle; his root is 3 rig units up)
	return counter.CFrame * CFrame.new(0, -2 + 3 * s, 3.4)
end

local function plotsFolder(): Instance?
	local map = workspace:FindFirstChild("Map")
	return map and map:FindFirstChild("Plots")
end

local function counterOf(plot: Instance): BasePart?
	local pen = plot:FindFirstChild("Pen")
	local shop = pen and pen:FindFirstChild("DonutShop")
	local counter = shop and shop:FindFirstChild("Counter")
	return if counter and counter:IsA("BasePart") then counter else nil
end

local function refresh()
	local plots = plotsFolder()
	if not plots then
		return
	end
	if not folder then
		local f = Instance.new("Folder")
		f.Name = "Bakers"
		f.Parent = workspace
		folder = f
	end
	for _, plot in plots:GetChildren() do
		local index = plot:GetAttribute("PlotIndex")
		local counter = if type(index) == "number" then counterOf(plot) else nil
		if type(index) == "number" and counter then
			local baker = bakers[index]
			if baker and baker.Counter ~= counter then
				-- the shop moved back (the base got bigger): he follows it
				baker.Counter = counter
				baker.Home = Bakers.HomeFor(counter)
				if not baker.Taken then
					Puppet.Pose(baker.Puppet, baker.Home)
				end
			elseif not baker then
				local model = BakerModel.Build(SCALE)
				local puppet = Puppet.new(model)
				if puppet then
					model.Name = "Baker" .. index
					model.Parent = folder
					local home = Bakers.HomeFor(counter)
					Puppet.Pose(puppet, home)
					bakers[index] = { Puppet = puppet, Counter = counter, Home = home, Taken = false, Phase = math.random() * 6 }
				end
			end
		end
	end
end

-- Your base's baker for a scene (he stops idling). nil if he isn't there (yet).
function Bakers.Take(plotIndex: number): Baker?
	refresh()
	local baker = bakers[plotIndex]
	if baker then
		baker.Taken = true
	end
	return baker
end

function Bakers.Release(plotIndex: number)
	local baker = bakers[plotIndex]
	if baker then
		baker.Taken = false
		for _, part in baker.Puppet.Parts do
			if part.Name == "MouthOpen" then
				part.Transparency = 1
			elseif part.Name == "Smile" then
				part.Transparency = 0
			end
		end
		Puppet.Pose(baker.Puppet, baker.Home)
	end
end

function Bakers.Get(plotIndex: number): Baker?
	return bakers[plotIndex]
end

function Bakers.Init()
	task.spawn(function()
		while true do
			refresh()
			task.wait(2)
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
		local character = player and player.Character
		local you = character and character:FindFirstChild("Head") :: BasePart?
		for _, baker in bakers do
			if baker.Taken or (baker.Home.Position - eye).Magnitude > NEAR then
				continue
			end
			local t = clock + baker.Phase
			-- breathing, a little sway, and he looks at you when you're close
			local breathe = math.sin(t * 1.6) * 0.04 * SCALE
			local joints: { [string]: CFrame } = {
				["Left Arm"] = CFrame.Angles(math.rad(-25 + 4 * math.sin(t * 1.6)), 0, math.rad(-6)),
				["Right Arm"] = CFrame.Angles(math.rad(-25 + 4 * math.sin(t * 1.6 + 0.5)), 0, math.rad(6)),
			}
			local turn = math.sin(t * 0.35) * 0.25
			if you then
				local here = baker.Home:PointToObjectSpace(you.Position)
				if here.Magnitude < LOOK and here.Z < 0 then
					turn = math.clamp(math.atan2(-here.X, -here.Z), -0.7, 0.7)
				end
			end
			joints.Head = CFrame.Angles(0, turn, 0)
			Puppet.Pose(baker.Puppet, baker.Home * CFrame.new(0, breathe, 0) * CFrame.Angles(0, 0, math.sin(t * 0.8) * 0.02), joints)
		end
	end)
end

return Bakers
