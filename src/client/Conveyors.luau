--[[
	Conveyors: slides the glowing arrows along the lobby's two conveyor belts (MapBuilder), at the
	belts' own speed, so you can see which way each one goes. The belts themselves carry you (the
	server gives them their velocity); this is only the look, on this player's screen.

	Every arrow moves forward by the same amount and jumps back one gap when it has gone a whole
	gap, so the row of arrows looks like one endless moving belt.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Conveyors = {}

local RANGE = 900 -- studs from the camera to a belt's middle: further away its arrows stand still

type Belt = { Parts: { BasePart }, Bases: { CFrame }, Direction: Vector3, Center: Vector3 }

local belts: { Belt } = {}

local function collect(folder: Instance)
	for _, model in folder:GetChildren() do
		local belt = model:FindFirstChild("Belt")
		local direction = belt and belt:GetAttribute("Direction")
		if belt and belt:IsA("BasePart") and typeof(direction) == "Vector3" then
			local parts, bases = {}, {}
			for _, part in model:GetChildren() do
				if part:IsA("BasePart") and part:GetAttribute("ConveyorArrow") then
					table.insert(parts, part)
					table.insert(bases, part.CFrame)
				end
			end
			table.insert(belts, { Parts = parts, Bases = bases, Direction = direction, Center = belt.Position })
		end
	end
end

function Conveyors.Init()
	task.spawn(function()
		local map = workspace:WaitForChild("Map", 60)
		local hub = map and map:WaitForChild("Hub", 30)
		local folder = hub and hub:WaitForChild("Conveyors", 30)
		if not folder then
			return
		end
		task.wait(1) -- (let every arrow arrive)
		collect(folder)
		local spacing = Config.Conveyors.ArrowSpacing
		local speed = Config.Conveyors.Speed
		local clock = 0
		local bulkMove = true
		RunService.RenderStepped:Connect(function(dt: number)
			clock += dt
			local camera = workspace.CurrentCamera
			if not camera then
				return
			end
			local offset = (clock * speed) % spacing
			for _, belt in belts do
				if (camera.CFrame.Position - belt.Center).Magnitude > RANGE then
					continue
				end
				local shift = belt.Direction * offset
				local frames = table.create(#belt.Parts)
				for i, base in belt.Bases do
					frames[i] = base + shift
				end
				if bulkMove then
					bulkMove = pcall(function()
						workspace:BulkMoveTo(belt.Parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
					end)
				end
				if not bulkMove then
					for i, part in belt.Parts do
						part.CFrame = frames[i]
					end
				end
			end
		end)
	end)
end

return Conveyors
