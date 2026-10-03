--[[
	Carried: the donut (or egg) each player is carrying, drawn by every client.

	The server only sets attributes on the carrier - CarryingDonut (the donut's or egg's id),
	CarryKind ("Lane" / "Raid" / "Egg"), CarryMutation and CarrySize - and every client builds the
	model itself: donuts held in both arms (arms raised), eggs above the head. Nothing is sent over
	the network and nothing is welded into a character on the server, which is what used to make the
	first second of a steal stutter on phones (a donut is ~110 parts).

	To make the grab itself instant, the donut is already built while you hold the Steal button, so
	it's ready the moment the server says you got it. Other players' donuts are only built while
	they're near you.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Donuts = require(Shared.Donuts)
local Pets = require(Shared.Pets)
local DonutModel = require(Shared.DonutModel)
local PetModel = require(Shared.PetModel)

local Carried = {}

local player = Players.LocalPlayer :: Player

local DONUT_SCALE = 0.45
local EGG_SCALE = 0.6
local BUILD_RANGE = 250 -- other players' carried donuts are drawn within this many studs of you...
local DROP_RANGE = 320 -- ...and removed again past this
local SPARE_LIFETIME = 6 -- seconds a donut built in advance (while holding Steal) is kept
local ARM_JOINTS = { "RightShoulder", "LeftShoulder", "Right Shoulder", "Left Shoulder" }

type Held = { Key: string, Model: Model, Character: Model, Arms: { [Motor6D]: CFrame } }

local held: { [Player]: Held } = {}
local pending: { [Player]: boolean } = {}
local spare: { Key: string, Model: Model, At: number }? = nil

-- What `target` is carrying, as a key ("Lane|glazey|Gold|Big"), or nil.
local function keyFor(target: Player): string?
	local id = target:GetAttribute("CarryingDonut")
	if type(id) ~= "string" then
		return nil
	end
	local kind = target:GetAttribute("CarryKind")
	local mutation = target:GetAttribute("CarryMutation")
	local size = target:GetAttribute("CarrySize")
	return `{if kind == "Egg" then "Egg" else "Donut"}|{id}|{mutation or "None"}|{size or "Normal"}`
end

local function build(key: string): Model?
	local fields = string.split(key, "|")
	local model: Model? = nil
	if fields[1] == "Egg" then
		local egg = Pets.EggById[fields[2]]
		model = if egg then PetModel.BuildEgg(egg, { Scale = EGG_SCALE }) else nil
	else
		local donut = Donuts.ById[fields[2]]
		model = if donut then DonutModel.Build(donut, { Scale = DONUT_SCALE, Mutation = fields[3], Size = fields[4] }) else nil
	end
	if not model or not model.PrimaryPart then
		return nil
	end
	model.Name = "CarriedDonut"
	model:SetAttribute("Carried", true)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Massless = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
	return model
end

-- Arms reach forward while holding a donut (R15 and R6 shoulder joints); undone when it's gone.
local function raiseArms(character: Model): { [Motor6D]: CFrame }
	local saved: { [Motor6D]: CFrame } = {}
	for _, joint in character:GetDescendants() do
		if joint:IsA("Motor6D") and table.find(ARM_JOINTS, joint.Name) then
			saved[joint] = joint.C0
			-- R6 shoulders point sideways (rotate about their own Z), R15 about X
			joint.C0 = joint.C0
				* (if string.find(joint.Name, " ")
					then CFrame.Angles(0, 0, if joint.Name == "Right Shoulder" then math.rad(80) else math.rad(-80))
					else CFrame.Angles(math.rad(80), 0, 0))
		end
	end
	return saved
end

-- Weld the model to the character: in front of the chest (donuts) or above the head (eggs, or a
-- character without a torso). The model is parented last, so it joins the character in one go.
local function attach(character: Model, model: Model, inArms: boolean): boolean
	local root = model.PrimaryPart :: BasePart
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	local head = character:FindFirstChild("Head") :: BasePart?
	local anchor: BasePart?, offset: CFrame
	if inArms and torso then
		local _, size = model:GetBoundingBox()
		anchor, offset = torso, CFrame.new(0, 0.2, -(torso.Size.Z / 2 + size.Z / 2 + 0.3))
	elseif head then
		anchor, offset = head, CFrame.new(0, 1.2 + ((model:GetAttribute("Bottom") :: number?) or 1.4), 0)
	else
		return false
	end
	local part = anchor :: BasePart
	model:PivotTo(part.CFrame * offset)
	root.Anchored = false
	local weld = Instance.new("Weld")
	weld.Part0 = part
	weld.Part1 = root
	weld.C0 = offset
	weld.Parent = root
	model.Parent = character
	return true
end

local function drop(target: Player)
	local current = held[target]
	if not current then
		return
	end
	held[target] = nil
	current.Model:Destroy()
	for joint, c0 in current.Arms do
		if joint.Parent then
			joint.C0 = c0
		end
	end
end

local function inRange(target: Player, range: number): boolean
	if target == player then
		return true
	end
	local camera = workspace.CurrentCamera
	local character = target.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return camera ~= nil and root ~= nil and (root.Position - camera.CFrame.Position).Magnitude < range
end

local function refresh(target: Player)
	pending[target] = nil
	local key = keyFor(target)
	local character = target.Character
	local current = held[target]
	if current and key == current.Key and character == current.Character and current.Model.Parent then
		if not inRange(target, DROP_RANGE) then
			drop(target)
		end
		return
	end
	drop(target)
	if not key or not character or not inRange(target, BUILD_RANGE) then
		return
	end
	local model: Model?
	local ready = spare
	if target == player and ready and ready.Key == key then
		model = ready.Model -- built while you held the Steal button
		spare = nil
	else
		model = build(key)
	end
	if not model then
		return
	end
	local isEgg = string.sub(key, 1, 4) == "Egg|"
	if not attach(character, model, not isEgg) then
		model:Destroy()
		return
	end
	held[target] = { Key = key, Model = model, Character = character, Arms = if isEgg then {} else raiseArms(character) }
end

-- Several attributes change together: refresh once, after they've all arrived.
local function schedule(target: Player)
	if not pending[target] then
		pending[target] = true
		task.defer(refresh, target)
	end
end

local function watch(target: Player)
	for _, name in { "CarryingDonut", "CarryKind", "CarryMutation", "CarrySize" } do
		target:GetAttributeChangedSignal(name):Connect(function()
			schedule(target)
		end)
	end
	target.CharacterAdded:Connect(function()
		schedule(target)
	end)
	schedule(target)
end

-- Holding Steal on a donut: build the one you'll carry now, so the grab itself costs nothing.
local function prebuild(prompt: ProximityPrompt, who: Player)
	if who ~= player or (prompt.Name ~= "StealPrompt" and prompt.Name ~= "RaidPrompt") then
		return
	end
	local source: Instance? = prompt.Parent
	while source and source:GetAttribute("DonutId") == nil do
		source = source.Parent
	end
	if not source then
		return
	end
	local key = `Donut|{source:GetAttribute("DonutId")}|{source:GetAttribute("Mutation") or "None"}|{source:GetAttribute("Size") or "Normal"}`
	if spare and spare.Key == key then
		spare.At = os.clock()
		return
	end
	task.defer(function()
		local model = build(key)
		if not model then
			return
		end
		if spare then
			spare.Model:Destroy()
		end
		spare = { Key = key, Model = model, At = os.clock() }
	end)
end

function Carried.Init()
	for _, target in Players:GetPlayers() do
		watch(target)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(target)
		drop(target)
		pending[target] = nil
	end)
	ProximityPromptService.PromptButtonHoldBegan:Connect(prebuild)

	-- Other players' donuts come and go with distance; an unused spare is thrown away.
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, target in Players:GetPlayers() do
				if target ~= player and keyFor(target) ~= nil then
					local near = held[target] ~= nil
					if near ~= inRange(target, if near then DROP_RANGE else BUILD_RANGE) then
						schedule(target)
					end
				end
			end
			local old = spare
			if old and os.clock() - old.At > SPARE_LIFETIME then
				old.Model:Destroy()
				spare = nil
			end
		end
	end)
end

return Carried
