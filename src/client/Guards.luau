--[[
	Guards (client side)
	====================
	* Builds YOUR sleeping guard on every blanket (only you can see him; everyone has their own).
	* When you steal a donut the server spawns your chasing guard: your sleeping one disappears in a
	  puff of smoke, and pops back onto the blanket when the chase is over.
	* Other players' chasing guards are hidden, so you never see anyone else's Domers.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local GuardModel = require(Shared.GuardModel)

local player = Players.LocalPlayer :: Player

local Guards = {}

type Sleeper = { Model: Model, Status: TextLabel, Home: CFrame, Hidden: boolean }

local sleepers: { [number]: Sleeper } = {}
local folder: Folder

--------------------------------------------------------------------------------
-- Poof
--------------------------------------------------------------------------------
function Guards.Poof(position: Vector3, color: Color3?)
	local part = Instance.new("Part")
	part.Name = "Poof"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(4, 6, 4)
	part.CFrame = CFrame.new(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color or Color3.fromRGB(255, 255, 255))
	emitter.LightEmission = 0.3
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(6, 12)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 5
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 3.5) })
	emitter.Transparency = NumberSequence.new(0.2, 1)
	emitter.Rate = 0
	emitter.Parent = part
	part.Parent = folder
	emitter:Emit(28)
	task.delay(1.5, function()
		part:Destroy()
	end)
end

--------------------------------------------------------------------------------
-- Sleeping guards (local only)
--------------------------------------------------------------------------------
local function setHidden(sleeper: Sleeper, hidden: boolean)
	if sleeper.Hidden == hidden then
		return
	end
	sleeper.Hidden = hidden
	sleeper.Model.Parent = if hidden then nil else folder
	Guards.Poof(sleeper.Home.Position + Vector3.new(0, 2, 0))
end

local function buildSleeper(areaId: number)
	local map = workspace:WaitForChild("Map")
	local lane = map:WaitForChild("Lane")
	local area = lane:WaitForChild("Area" .. areaId, 30)
	local marker = area and area:FindFirstChild("GuardHome", true)
	if not marker or not marker:IsA("BasePart") then
		return
	end
	local model, status = GuardModel.Build(areaId)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	local home = CFrame.new(marker.Position.X, 0, marker.Position.Z)
	model:PivotTo(GuardModel.SleepCFrame(home))
	model.Parent = folder
	sleepers[areaId] = { Model = model, Status = status, Home = home, Hidden = false }
end

--------------------------------------------------------------------------------
-- Chasing guards (server side): hide other players', swap ours with the sleeper
--------------------------------------------------------------------------------
local function hideForMe(model: Instance)
	local function hide(d: Instance)
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 1
		elseif d:IsA("Decal") then
			d.LocalTransparencyModifier = 1
		elseif d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("Highlight") or d:IsA("Fire") or d:IsA("Sparkles") or d:IsA("Smoke") then
			(d :: any).Enabled = false
		elseif d:IsA("Sound") then
			d.Volume = 0
		end
	end
	for _, d in model:GetDescendants() do
		hide(d)
	end
	model.DescendantAdded:Connect(hide)
end

local function onGuardAdded(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local owner = instance:GetAttribute("OwnerUserId")
	if owner ~= player.UserId then
		hideForMe(instance)
		return
	end
	local areaId = instance:GetAttribute("Area")
	local sleeper = if type(areaId) == "number" then sleepers[areaId] else nil
	if sleeper then
		setHidden(sleeper, true)
	end
	local lastPosition = instance:GetPivot().Position
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		if instance.Parent then
			lastPosition = instance:GetPivot().Position
		else
			connection:Disconnect()
			-- The chase is over: he teleports back to his blanket.
			Guards.Poof(lastPosition + Vector3.new(0, 2, 0))
			if sleeper then
				setHidden(sleeper, false)
			end
		end
	end)
end

function Guards.Init()
	folder = Instance.new("Folder")
	folder.Name = "MyGuards"
	folder.Parent = workspace

	task.spawn(function()
		for areaId = 1, #Areas.List do
			buildSleeper(areaId)
		end
	end)

	for _, instance in CollectionService:GetTagged("Guard") do
		task.spawn(onGuardAdded, instance)
	end
	CollectionService:GetInstanceAddedSignal("Guard"):Connect(onGuardAdded)

	-- Snoring "Zzz"
	task.spawn(function()
		local frames = { "z", "zZ", "zZz", "zZzZ" }
		local frame = 0
		while true do
			task.wait(0.45)
			frame = frame % #frames + 1
			for _, sleeper in sleepers do
				if not sleeper.Hidden then
					sleeper.Status.Text = frames[frame]
				end
			end
		end
	end)
end

return Guards
