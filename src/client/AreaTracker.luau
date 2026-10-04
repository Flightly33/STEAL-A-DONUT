--[[
	Tracks which biome the local player is standing in (0 = the lobby). Anyone can walk into any
	biome: a biome's Speed is what you need to get away from its Domer, not to get in.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Layout)
local Signal = require(Shared.Signal)

local player = Players.LocalPlayer :: Player

local AreaTracker = {}
AreaTracker.Current = -1
AreaTracker.Changed = Signal.new() -- (newArea, oldArea)

function AreaTracker.Position(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

task.spawn(function()
	while true do
		local position = AreaTracker.Position()
		if position then
			local area = Layout.AreaAt(position)
			if area ~= AreaTracker.Current then
				local old = AreaTracker.Current
				AreaTracker.Current = area
				AreaTracker.Changed:Fire(area, old)
			end
		end
		task.wait(0.2)
	end
end)

return AreaTracker
