--[[
	Tracks which biome the local player is standing in (0 = the lobby), and handles the speed
	gates: every biome needs a Speed to get in (Areas.luau). Each biome's entrance has an invisible
	wall (tagged "SpeedGate", attributes Area + Speed); it's solid - and shows as a faint red
	force field - only on the computer of a player whose Speed is too low, so slow players bump into
	it while everyone else walks through. The server double-checks (WorldService).
	AreaTracker.Blocked fires (areaId) when you walk up to a gate you're too slow for.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Layout)
local Signal = require(Shared.Signal)

local player = Players.LocalPlayer :: Player

local AreaTracker = {}
AreaTracker.Current = -1
AreaTracker.Changed = Signal.new() -- (newArea, oldArea)
AreaTracker.Blocked = Signal.new() -- (areaId) you walked up to a biome you're too slow for

local BLOCKED_COLOR = Color3.fromRGB(255, 70, 70)
local WARN_DISTANCE = 10
local lastBlocked = 0

function AreaTracker.Position(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

-- Can the local player walk into this biome? (admins flying go anywhere)
local function canPass(gate: BasePart): boolean
	if player:GetAttribute("Flying") == true then
		return true
	end
	local need = gate:GetAttribute("Speed")
	local speed = player:GetAttribute("Speed")
	return type(need) ~= "number" or (type(speed) == "number" and speed >= need)
end

local function updateGate(gate: Instance)
	if not gate:IsA("BasePart") then
		return
	end
	local blocked = not canPass(gate)
	if gate.CanCollide ~= blocked then
		gate.CanCollide = blocked
		gate.Material = Enum.Material.ForceField
		gate.Color = BLOCKED_COLOR
		gate.Transparency = if blocked then 0.2 else 1
	end
end

local function updateGates()
	for _, gate in CollectionService:GetTagged("SpeedGate") do
		updateGate(gate)
	end
end

-- Walking up to a gate you can't get through: tell the HUD (at most every few seconds).
local function checkNearGates(position: Vector3)
	local now = os.clock()
	if now - lastBlocked < 3 then
		return
	end
	for _, gate in CollectionService:GetTagged("SpeedGate") do
		if gate:IsA("BasePart") and gate.CanCollide then
			local ahead = gate.Position.Z - position.Z
			if ahead > 0 and ahead < WARN_DISTANCE and math.abs(position.X - gate.Position.X) < gate.Size.X / 2 then
				lastBlocked = now
				local areaId = gate:GetAttribute("Area")
				if type(areaId) == "number" then
					AreaTracker.Blocked:Fire(areaId)
				end
				return
			end
		end
	end
end

CollectionService:GetInstanceAddedSignal("SpeedGate"):Connect(updateGate)
player:GetAttributeChangedSignal("Speed"):Connect(updateGates)
player:GetAttributeChangedSignal("Flying"):Connect(updateGates)
updateGates()

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
			checkNearGates(position)
		end
		task.wait(0.2)
	end
end)

return AreaTracker
