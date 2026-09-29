--[[
	Followers: every player's favourite donut and equipped pets, following them around.

	Drawn by each client from the player's attributes (nothing is simulated or replicated):
	  "Favorite" -> "donutId|mutation|size" of their favourite base donut: a copy at
	                Config.Favorite.Scale (1/3) of its size on the stand, mutation look included
	  "Pets"     -> comma-separated ids of their equipped pets
	Walkers hop along behind you, flyers and blobs float. Wings flap, tails wag (faster while you're
	on the move), whale flukes paddle, tentacles wiggle and everyone blinks - all by swinging the
	parts PetModel marked ("Limb") around their joints ("Pivot"). Only followers near the camera are
	animated.
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
	Vector3.new(4, 0, 3.5), -- favourite donut (pushed further out when it's a big one)
	Vector3.new(-4, 0, 3.5),
	Vector3.new(0, 0, 6),
	Vector3.new(-4.5, 0, 8),
	Vector3.new(4.5, 0, 8),
}

-- Limbs that move while following (a favourite donut's arms and legs stay put)
local ANIMATED = { Wing = true, Tail = true, Fluke = true, Fin = true, Tentacle = true, Spin = true, Orbit = true }

type Limb = { Weld: Weld, Base: CFrame, Pivot: CFrame, Kind: string, Side: number }
type Eye = { Part: BasePart, Size: Vector3, Color: Color3 }
type Follower = {
	Model: Model,
	Root: BasePart,
	Slot: number,
	Offset: Vector3, -- where it walks, relative to its owner
	Floats: boolean,
	Height: number, -- root height above the ground
	Phase: number,
	CFrame: CFrame,
	Limbs: { Limb },
	Eyes: { Eye },
	Pupils: { BasePart },
	Blinking: boolean,
	NextBlink: number,
	Rainbow: { BasePart },
	Glitch: boolean,
}

local folder: Folder
local byPlayer: { [Player]: { Follower } } = {}

local function prepare(model: Model, slot: number, floats: boolean, spread: number?): Follower
	local root = model.PrimaryPart :: BasePart
	model:SetAttribute("Follower", true)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	local limbs: { Limb } = {}
	local eyes: { Eye } = {}
	local pupils: { BasePart } = {}
	local rainbow: { BasePart } = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local weld = part:FindFirstChildOfClass("Weld")
			local kind = part:GetAttribute("Limb")
			if weld and type(kind) == "string" and ANIMATED[kind] then
				local pivot = part:GetAttribute("Pivot")
				local side = part:GetAttribute("Side")
				table.insert(limbs, {
					Weld = weld,
					Base = weld.C0,
					Pivot = CFrame.new(if typeof(pivot) == "Vector3" then pivot else Vector3.zero),
					Kind = kind,
					Side = if type(side) == "number" then side else 0,
				})
			end
			if part:GetAttribute("EyeWhite") then
				table.insert(eyes, { Part = part, Size = part.Size, Color = part.Color })
			elseif part:GetAttribute("Pupil") then
				table.insert(pupils, part)
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
		Offset = SLOTS[slot] * (spread or 1),
		Floats = floats,
		Height = bottom + (if floats then 2.2 else 0.05),
		Phase = math.random() * 6,
		CFrame = CFrame.new(),
		Limbs = limbs,
		Eyes = eyes,
		Pupils = pupils,
		Blinking = false,
		NextBlink = os.clock() + math.random() * 4,
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
	local favorite = player:GetAttribute("Favorite")
	local parts = if type(favorite) == "string" then string.split(favorite, "|") else {}
	local donut = Donuts.ById[parts[1] or ""]
	if donut then
		-- Same build as the donut on the stand, just smaller
		local model = DonutModel.Build(donut, { Scale = Config.Plots.DonutScale * Config.Favorite.Scale, Mutation = parts[2], Size = parts[3] })
		local _, size = model:GetBoundingBox()
		table.insert(list, prepare(model, 1, true, math.max(1, math.max(size.X, size.Z) / 3)))
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
	player:GetAttributeChangedSignal("Favorite"):Connect(function()
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
			local target = (flat * CFrame.new(follower.Offset)).Position
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
			local phase = t + follower.Phase
			for _, limb in follower.Limbs do
				local kind = limb.Kind
				local rotation
				if kind == "Wing" then
					rotation = CFrame.Angles(0, 0, math.sin(phase * 12) * 0.45 * limb.Side)
				elseif kind == "Tail" then
					rotation = CFrame.Angles(0, math.sin(phase * (if moving then 16 else 8)) * 0.4, 0)
				elseif kind == "Fluke" then
					rotation = CFrame.Angles(math.sin(phase * 3) * 0.22, 0, 0)
				elseif kind == "Fin" then
					rotation = CFrame.Angles(0, 0, math.sin(phase * 4) * 0.25 * limb.Side)
				elseif kind == "Tentacle" then
					rotation = CFrame.Angles(0, 0, math.sin(phase * 3 + limb.Side) * 0.2)
				elseif kind == "Spin" then
					rotation = CFrame.Angles(0, (t * 14) % (math.pi * 2), 0)
				elseif kind == "Orbit" then
					rotation = CFrame.Angles(0, (t * 1.3) % (math.pi * 2), 0)
				else
					rotation = CFrame.identity
				end
				limb.Weld.C0 = limb.Pivot * rotation * limb.Pivot:Inverse() * limb.Base
			end
			-- Blink: squash the eyes shut for a moment every few seconds
			local shut = t < follower.NextBlink + 0.12 and t >= follower.NextBlink
			if shut ~= follower.Blinking then
				follower.Blinking = shut
				for _, eye in follower.Eyes do
					eye.Part.Size = if shut then Vector3.new(eye.Size.X * 1.05, eye.Size.Y * 0.14, eye.Size.Z * 0.8) else eye.Size
					eye.Part.Color = if shut then Color3.fromRGB(40, 25, 30) else eye.Color
				end
				for _, pupil in follower.Pupils do
					pupil.Transparency = if shut then 1 else 0
				end
			end
			if t >= follower.NextBlink + 0.12 then
				follower.NextBlink = t + 2 + math.random() * 3.5
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
