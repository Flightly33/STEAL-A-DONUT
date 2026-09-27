--[[
	Followers: every player's buddy donut and equipped pets, following them around.

	Drawn by each client from the player's attributes (nothing is simulated or replicated):
	  "Buddy" -> the id of the donut they picked in the Index
	  "Pets"  -> comma-separated ids of their equipped pets
	Walkers hop along behind you, flyers and blobs float, wings flap. Only followers near the camera
	are animated.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Donuts = require(Shared.Donuts)
local Pets = require(Shared.Pets)
local DonutModel = require(Shared.DonutModel)
local PetModel = require(Shared.PetModel)

local Followers = {}

local RANGE = 220
-- Where followers walk, relative to their owner (behind them, spread out)
local SLOTS = {
	Vector3.new(4, 0, 3.5), -- buddy
	Vector3.new(-4, 0, 3.5),
	Vector3.new(0, 0, 6),
	Vector3.new(-4.5, 0, 8),
	Vector3.new(4.5, 0, 8),
}

type Wing = { Weld: Weld, Base: CFrame, Side: number }
type Follower = {
	Model: Model,
	Root: BasePart,
	Slot: number,
	Floats: boolean,
	Height: number, -- root height above the ground
	Phase: number,
	CFrame: CFrame,
	Wings: { Wing },
	Rainbow: { BasePart },
	Glitch: boolean,
}

local folder: Folder
local byPlayer: { [Player]: { Follower } } = {}

local function prepare(model: Model, slot: number, floats: boolean): Follower
	local root = model.PrimaryPart :: BasePart
	model:SetAttribute("Follower", true)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	local wings: { Wing } = {}
	local rainbow: { BasePart } = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local weld = part:FindFirstChildOfClass("Weld")
			local side = part:GetAttribute("Flap")
			if weld and type(side) == "number" then
				table.insert(wings, { Weld = weld, Base = weld.C0, Side = side })
			end
			if model:GetAttribute("Rainbow") and (part.Name == "Body" or part.Name == "Wing") then
				table.insert(rainbow, part)
			end
		end
	end
	local bottom = (model:GetAttribute("Bottom") :: number?) or 1
	return {
		Model = model,
		Root = root,
		Slot = slot,
		Floats = floats,
		Height = bottom + (if floats then 2.2 else 0.05),
		Phase = math.random() * 6,
		CFrame = CFrame.new(),
		Wings = wings,
		Rainbow = rainbow,
		Glitch = model:GetAttribute("Glitch") == true,
	}
end

local function clear(player: Player)
	local list = byPlayer[player]
	if list then
		for _, follower in list do
			follower.Model:Destroy()
		end
	end
	byPlayer[player] = nil
end

local function rebuild(player: Player)
	clear(player)
	local list: { Follower } = {}
	local buddy = player:GetAttribute("Buddy")
	local donut = if type(buddy) == "string" then Donuts.ById[buddy] else nil
	if donut then
		local model = DonutModel.Build(donut, { Scale = Config.Buddy.Scale })
		table.insert(list, prepare(model, 1, true))
	end
	local pets = player:GetAttribute("Pets")
	if type(pets) == "string" and pets ~= "" then
		local slot = 2
		for _, id in string.split(pets, ",") do
			local pet = Pets.ById[id]
			if pet and slot <= #SLOTS then
				local model = PetModel.BuildPet(pet, { Scale = 0.7 })
				local floats = pet.Shape == "Blob" or pet.Shape == "Whale" or Pets.HasFeature(pet, "Wings")
				table.insert(list, prepare(model, slot, floats))
				slot += 1
			end
		end
	end
	for _, follower in list do
		follower.Model.Parent = folder
	end
	byPlayer[player] = list
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("Buddy"):Connect(function()
		rebuild(player)
	end)
	player:GetAttributeChangedSignal("Pets"):Connect(function()
		rebuild(player)
	end)
	rebuild(player)
end

local function update(dt: number)
	local camera = workspace.CurrentCamera
	local cam = if camera then camera.CFrame.Position else Vector3.zero
	local t = os.clock()
	local alpha = 1 - math.exp(-dt * 9)
	for player, list in byPlayer do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local visible = root ~= nil and (root.Position - cam).Magnitude < RANGE
		for _, follower in list do
			local model = follower.Model
			if not visible or not root then
				if model.Parent then
					model.Parent = nil
				end
				continue
			end
			if not model.Parent then
				model.Parent = folder
				follower.CFrame = CFrame.new(root.Position)
			end
			-- Stand behind the owner, on the ground (feet ~3 studs below the root part)
			local hip = if humanoid and humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight + root.Size.Y / 2 else 3
			local ground = root.Position.Y - hip
			local flat = CFrame.new(root.Position) * CFrame.Angles(0, select(2, root.CFrame:ToEulerAnglesYXZ()), 0)
			local target = (flat * CFrame.new(SLOTS[follower.Slot])).Position
			local moving = root.AssemblyLinearVelocity.Magnitude > 2
			local bob = if follower.Floats then math.sin(t * 2.5 + follower.Phase) * 0.35 elseif moving then math.abs(math.sin(t * 9 + follower.Phase)) * 0.6 else 0
			target = Vector3.new(target.X, ground + follower.Height + bob, target.Z)
			local position = follower.CFrame.Position:Lerp(target, alpha)
			-- Face where the owner is going (or the owner, when standing still)
			local look = if moving then root.CFrame.LookVector else (root.Position - position)
			look = Vector3.new(look.X, 0, look.Z)
			local facing = if look.Magnitude > 0.01 then CFrame.lookAt(position, position + look) else CFrame.new(position)
			if (target - position).Magnitude > 80 then
				facing = CFrame.new(target) -- teleported: snap
			end
			follower.CFrame = facing
			local finalCf = facing
			if follower.Glitch and math.random() < 0.03 then
				finalCf = facing * CFrame.new(math.random() - 0.5, 0, math.random() - 0.5)
			end
			follower.Root.CFrame = finalCf
			for _, wing in follower.Wings do
				wing.Weld.C0 = wing.Base * CFrame.Angles(0, 0, math.sin(t * 12 + follower.Phase) * 0.45 * wing.Side)
			end
			if #follower.Rainbow > 0 then
				local color = Color3.fromHSV((t * 0.25) % 1, 0.55, 1)
				for _, part in follower.Rainbow do
					part.Color = color
				end
			end
		end
	end
end

function Followers.Init()
	folder = Instance.new("Folder")
	folder.Name = "Followers"
	folder.Parent = workspace
	for _, player in Players:GetPlayers() do
		task.spawn(watch, player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)
	RunService.RenderStepped:Connect(update)
end

return Followers
