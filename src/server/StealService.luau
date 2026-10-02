--[[
	StealService
	============
	The core loop:
	  1. Hold E on a donut in the lane -> you pick it up (it floats above your head) and YOUR guard
	     for that area wakes up and chases you. Big donuts slow you down while you carry them.
	  2. Cross the safe-zone line -> the guard gives up.
	  3. Walk into your own base (it's in whichever world you're in) -> the donut is placed on a free
	     stand and starts earning money.
	  If the guard catches you, you get hit, or you fall, the donut goes BACK to where you took it
	  from (the same donut, on the same spot) and you're sent back to your base.

	Everything you can carry uses the same system:
	  Lane -> a donut from the lane (returns to its spawn spot when lost)
	  Raid -> a donut stolen from another player's base (see RaidService). You're in slow mode while
	          you carry it; if you're hit before you get home it flies back onto the owner's stand.
	  Egg  -> a pet egg from the lane (see PetService; returns to its spot when lost)
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Donuts = require(Shared.Donuts)
local Rarities = require(Shared.Rarities)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Layout = require(Shared.Layout)
local DonutModel = require(Shared.DonutModel)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local DonutSpawnService = require(script.Parent.DonutSpawnService)
local GuardService = require(script.Parent.GuardService)
local StatsService = require(script.Parent.StatsService)

local StealService = {}

export type Carry = {
	Kind: string, -- "Lane" | "Raid" | "Egg"
	DonutId: string, -- the donut's id (for eggs: the egg's id)
	Level: number,
	Mutation: string,
	Size: string,
	Victim: Player?, -- raids: who it was stolen from
	VictimSlot: number?, -- raids: the stand it was taken from
	Record: DonutSpawnService.SpawnRecord?, -- lane donuts: the spot it was taken from
	AreaId: number,
	Visual: Model?,
	Secured: boolean,
	LastPos: Vector3,
	LastTime: number,
	-- Custom behaviour (eggs): deposit returns false to keep carrying; lost puts it back.
	OnDeposit: ((Player) -> boolean)?,
	OnLost: ((Player) -> ())?,
}

-- A single jump longer than this (studs) while carrying something is treated as a teleport hack.
local TELEPORT_DISTANCE = 400

local carriers: { [Player]: Carry } = {}
local lastFullWarning: { [Player]: number } = {}

local function notify(player: Player, text: string, kind: string?)
	Remotes.Event("Notify"):FireClient(player, text, kind or "info")
end

function StealService.IsCarrying(player: Player): boolean
	return carriers[player] ~= nil
end

function StealService.GetCarry(player: Player): Carry?
	return carriers[player]
end

local function clearCarry(player: Player): Carry?
	local carry = carriers[player]
	if not carry then
		return nil
	end
	carriers[player] = nil
	if carry.Visual then
		carry.Visual:Destroy()
	end
	if player.Parent then
		player:SetAttribute("CarryingDonut", nil)
		player:SetAttribute("CarrySize", nil)
		player:SetAttribute("CarryKind", nil)
	end
	return carry
end

local function startCarry(player: Player, carry: Carry)
	carriers[player] = carry
	player:SetAttribute("CarryingDonut", carry.DonutId)
	player:SetAttribute("CarrySize", carry.Size)
	player:SetAttribute("CarryKind", carry.Kind)
end

-- Put whatever the player was carrying back where it came from.
local function returnLost(player: Player, carry: Carry)
	if carry.OnLost then
		carry.OnLost(player)
	elseif carry.Kind == "Lane" and carry.Record then
		DonutSpawnService.Return(carry.Record)
	elseif carry.Kind == "Raid" then
		-- A raided donut flies back onto its owner's stand (if they're still here and have room).
		local victim = carry.Victim
		local donut = Donuts.ById[carry.DonutId]
		if victim and victim.Parent and donut then
			local name = Rarities.DisplayName(donut.Name, carry.Mutation, carry.Size)
			if PlotService.AddDonut(victim, carry.DonutId, carry.Level, carry.Mutation, carry.Size, carry.VictimSlot) then
				notify(victim, `🛡 You got your {name} back!`, "success")
				Remotes.Event("Alarm"):FireClient(victim, { Stage = "Recovered", Thief = player, Name = name })
			else
				notify(victim, `Your {name} was dropped but your base is full, so it's gone.`, "error")
			end
		end
	end
end

-- Move a player somewhere without tripping the carry speed check (portals, teleports).
function StealService.Teleport(player: Player, cf: CFrame)
	local character = player.Character
	if not character then
		return
	end
	character:PivotTo(cf)
	local carry = carriers[player]
	if carry then
		carry.LastPos = cf.Position
		carry.LastTime = os.clock()
	end
end

-- Lose what you're carrying without depositing it (hit, died, left, cheated...). It goes back.
function StealService.Drop(player: Player, reason: string?)
	local carry = clearCarry(player)
	if not carry then
		return
	end
	GuardService.StopChase(player)
	if player.Parent then
		Remotes.Event("ChaseEnded"):FireClient(player, { Result = "Lost", Reason = reason, Kind = carry.Kind })
	end
	returnLost(player, carry)
end

-- Weapons and traps call this: anyone carrying something drops it (and it goes back).
function StealService.Knock(player: Player)
	if carriers[player] then
		StealService.Drop(player, "You got hit! It went back where it came from.")
	end
end

-- Weld a model above the player's head (the thing they carry).
function StealService.AttachAboveHead(player: Player, model: Model): boolean
	local character = player.Character
	local head = character and (character:FindFirstChild("Head") :: BasePart?)
	local root = model.PrimaryPart
	if not character or not head or not root then
		return false
	end
	local lift = 1.2 + ((model:GetAttribute("Bottom") :: number?) or 1.4)
	model:PivotTo(head.CFrame * CFrame.new(0, lift, 0))
	root.Anchored = false
	local weld = Instance.new("Weld")
	weld.Part0 = head
	weld.Part1 = root
	weld.C0 = CFrame.new(0, lift, 0)
	weld.Parent = root
	model.Name = "CarriedDonut"
	model.Parent = character
	return true
end

-- Arms reach forward while holding a donut (R15 and R6 shoulder joints); undone when it's gone.
local ARM_JOINTS = { "RightShoulder", "LeftShoulder", "Right Shoulder", "Left Shoulder" }
local function raiseArms(character: Model, model: Model)
	local saved: { [Motor6D]: CFrame } = {}
	for _, joint in character:GetDescendants() do
		if joint:IsA("Motor6D") and table.find(ARM_JOINTS, joint.Name) then
			saved[joint] = joint.C0
			-- R6 shoulders point sideways (rotate about their own Z), R15 about X
			joint.C0 = joint.C0 * (if string.find(joint.Name, " ") then CFrame.Angles(0, 0, if joint.Name == "Right Shoulder" then math.rad(80) else math.rad(-80)) else CFrame.Angles(math.rad(80), 0, 0))
		end
	end
	model.Destroying:Connect(function()
		for joint, c0 in saved do
			if joint.Parent then
				joint.C0 = c0
			end
		end
	end)
end

-- Weld a donut in front of the player's chest, held in both arms.
function StealService.AttachInArms(player: Player, model: Model): boolean
	local character = player.Character
	local torso = character and ((character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?)
	local root = model.PrimaryPart
	if not character or not torso or not root then
		return false
	end
	local _, size = model:GetBoundingBox()
	local offset = CFrame.new(0, 0.2, -(torso.Size.Z / 2 + size.Z / 2 + 0.3))
	model:PivotTo(torso.CFrame * offset)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Massless = true
			part.CanCollide = false
		end
	end
	root.Anchored = false
	local weld = Instance.new("Weld")
	weld.Part0 = torso
	weld.Part1 = root
	weld.C0 = offset
	weld.Parent = root
	model.Name = "CarriedDonut"
	model.Parent = character
	raiseArms(character, model)
	return true
end

local function attachVisual(player: Player, donutId: string, mutationId: string, sizeId: string): Model?
	local donut = Donuts.ById[donutId]
	if not donut then
		return nil
	end
	local model = DonutModel.Build(donut, { Scale = 0.45, Mutation = mutationId, Size = sizeId })
	if not StealService.AttachInArms(player, model) and not StealService.AttachAboveHead(player, model) then
		model:Destroy()
		return nil
	end
	return model
end

-- Anything else that can be carried (eggs). The guard of `areaId` wakes up if areaId > 0.
function StealService.StartCustom(player: Player, carry: Carry): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or carriers[player] then
		return false
	end
	carry.LastPos = root.Position
	carry.LastTime = os.clock()
	startCarry(player, carry)
	local guard = if carry.AreaId > 0 then GuardService.Alert(carry.AreaId, player) else nil
	Remotes.Event("ChaseStarted"):FireClient(player, {
		DonutId = carry.DonutId,
		AreaId = carry.AreaId,
		Kind = carry.Kind,
		Guard = guard and guard.Model,
		GuardSpeed = if carry.AreaId > 0 then Economy.GuardWalkSpeed(carry.AreaId) else nil,
	})
	return true
end

-- Start carrying a donut stolen from `victim`'s base (RaidService already removed it there).
function StealService.StartRaid(thief: Player, victim: Player, slot: DataService.SlotData, slotIndex: number)
	local root = thief.Character and thief.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local mutation, size = slot.Mutation or "None", slot.Size or "Normal"
	startCarry(thief, {
		Kind = "Raid",
		DonutId = slot.Id,
		Level = slot.Level,
		Mutation = mutation,
		Size = size,
		Victim = victim,
		VictimSlot = slotIndex,
		Record = nil,
		AreaId = 0,
		Visual = attachVisual(thief, slot.Id, mutation, size),
		Secured = true, -- no guard: the danger is the owner hitting you
		LastPos = root.Position,
		LastTime = os.clock(),
	})
	Remotes.Event("ChaseStarted"):FireClient(thief, { DonutId = slot.Id, AreaId = 0, Raid = true, Kind = "Raid", Mutation = mutation, Size = size, Victim = victim })
end

-- Checks shared by everything you can pick up. Returns the player's root part if they can.
function StealService.CanPickUp(player: Player, target: Vector3, reach: number): BasePart?
	local profile = DataService.Get(player)
	if not profile or not profile.Session.Ready or profile.Session.Stunned then
		return nil
	end
	if carriers[player] then
		notify(player, "You're already carrying something! Bring it home first.", "error")
		return nil
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not root then
		return nil
	end
	-- Server-side reach check (prompts are client-activated)
	if (target - root.Position).Magnitude > reach then
		return nil
	end
	return root
end

local function trySteal(player: Player, record: DonutSpawnService.SpawnRecord)
	local model = record.Model
	if not model then
		return
	end
	local root = StealService.CanPickUp(player, model:GetPivot().Position, 16 + 6 * Rarities.Size(record.Size).Scale)
	if not root then
		return
	end
	if not PlotService.HasFreeSlot(player) then
		notify(player, "Your base is full! Sell a donut (hold F on it) to make room.", "error")
		return
	end

	local donutId, mutation, size = DonutSpawnService.Take(record)
	if not donutId then
		return
	end
	local donut = Donuts.ById[donutId]
	startCarry(player, {
		Kind = "Lane",
		DonutId = donutId,
		Level = 1,
		Mutation = mutation,
		Size = size,
		Victim = nil,
		VictimSlot = nil,
		Record = record,
		AreaId = record.AreaId,
		Visual = attachVisual(player, donutId, mutation, size),
		Secured = false,
		LastPos = root.Position,
		LastTime = os.clock(),
	})

	local guard = GuardService.Alert(record.AreaId, player)
	Remotes.Event("ChaseStarted"):FireClient(player, {
		DonutId = donutId,
		AreaId = record.AreaId,
		Kind = "Lane",
		Mutation = mutation,
		Size = size,
		Guard = guard and guard.Model,
		GuardSpeed = Economy.GuardWalkSpeed(record.AreaId),
	})

	local rarity = Rarities.Get(donut.Rarity)
	if rarity.Order >= Config.Spawns.AnnounceRarity then
		Remotes.Event("AreaAnnouncement"):FireAllClients(`{player.DisplayName} is stealing a {string.upper(rarity.Id)} donut: {Rarities.DisplayName(donut.Name, mutation, size)}!`, rarity.Color)
	end
end

local function deposit(player: Player)
	local carry = carriers[player]
	local profile = DataService.Get(player)
	if not carry or not profile then
		return
	end
	if carry.OnDeposit then
		if carry.OnDeposit(player) then
			clearCarry(player)
			GuardService.StopChase(player)
		end
		return
	end
	local slot = PlotService.AddDonut(player, carry.DonutId, carry.Level, carry.Mutation, carry.Size)
	if not slot then
		local now = os.clock()
		if not lastFullWarning[player] or now - lastFullWarning[player] > 4 then
			lastFullWarning[player] = now
			notify(player, "Your base is full! Sell a donut (hold F on it) to make room.", "error")
		end
		return -- keep carrying until there's room
	end
	clearCarry(player)
	GuardService.StopChase(player)
	if carry.Kind == "Lane" and carry.Record then
		DonutSpawnService.Release(carry.Record)
	end

	local donut = Donuts.ById[carry.DonutId]
	local isNew = not profile.Data.Discovered[donut.Id]
	profile.Data.Discovered[donut.Id] = true
	local found = profile.Data.DiscoveredMutations[donut.Id] or {}
	profile.Data.DiscoveredMutations[donut.Id] = found
	local newMutation = carry.Mutation ~= "None" and not found[carry.Mutation]
	found[carry.Mutation] = true
	local score = Donuts.Score(donut, carry.Mutation)
	if score > profile.Data.BestDonutScore then
		profile.Data.BestDonutScore = score
	end
	local name = Rarities.DisplayName(donut.Name, carry.Mutation, carry.Size)
	-- Global "found" counter: only real lane finds (raids just move a donut between bases, and
	-- admin-planted donuts or players who used the admin panel would skew the rarity numbers).
	local fromLane = carry.Kind == "Lane"
	local counts = fromLane and not (carry.Record and carry.Record.Planted) and not profile.Data.UsedAdmin
	local foundCount = if counts then StatsService.RecordFound(donut.Id, carry.Mutation) else nil
	Remotes.Event("ChaseEnded"):FireClient(player, { Result = "Deposited", DonutId = donut.Id, IsNew = isNew, Mutation = carry.Mutation, Size = carry.Size, Kind = carry.Kind })
	notify(player, `{name} is earning {Format.Money(Economy.DonutIncome(donut.Id, carry.Level, carry.Mutation, carry.Size))}/s at your base!`, "success")
	local rarity = Rarities.Get(donut.Rarity)
	if fromLane and rarity.Order >= Config.Spawns.AnnounceRarity then
		local ever = if foundCount then ` (#{Format.Commas(foundCount)} ever found)` else ""
		Remotes.Event("AreaAnnouncement"):FireAllClients(`{player.DisplayName} got a {string.upper(rarity.Id)} donut home: {name}!{ever}`, rarity.Color)
	end
	local victim = carry.Victim
	if carry.Kind == "Raid" and victim and victim.Parent then
		notify(victim, `😱 {player.DisplayName} got away with your {name}!`, "error")
		Remotes.Event("Alarm"):FireClient(victim, { Stage = "Lost", Thief = player, Name = name })
	end
	if isNew or newMutation then
		DataService.PushState(player)
	end
	if isNew and Economy.IndexCashReward(donut.Id) > 0 then
		notify(player, "📖 New donut! Claim its reward in the Index.", "success")
	end
end

local function onCaught(player: Player, areaId: number)
	local carry = clearCarry(player)
	if not carry then
		return
	end
	returnLost(player, carry)
	local profile = DataService.Get(player)
	Remotes.Event("ChaseEnded"):FireClient(player, { Result = "Caught", AreaId = areaId, Kind = carry.Kind })
	if not profile then
		return
	end
	profile.Session.Stunned = true
	task.delay(Config.Guard.StunTime, function()
		if not player.Parent then
			return
		end
		profile.Session.Stunned = false
		local spawnCf = PlotService.GetSpawnCFrame(player)
		local character = player.Character
		if spawnCf and character then
			character:PivotTo(spawnCf)
		end
	end)
end

local function updateCarriers()
	local now = os.clock()
	for player, carry in carriers do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or not player.Parent then
			StealService.Drop(player, "Lost")
			continue
		end
		local pos = root.Position

		-- Teleport-hack guard only. Running fast never drops anything (there used to be a speed check
		-- here, but network lag made fast players drop their donut). Only a jump of hundreds of studs
		-- in one step - which nobody can run - sends it back. Game teleports (lift pads, portals)
		-- go through StealService.Teleport, which moves LastPos along, so they never trigger this.
		local flat = Vector2.new(pos.X - carry.LastPos.X, pos.Z - carry.LastPos.Z).Magnitude
		if flat > 0.01 then
			local profile = DataService.Get(player)
			local walkSpeed = if profile then Economy.PlayerWalkSpeed(profile.Data.Speed, Layout.WorldAt(pos)) * DataService.WalkBoost(profile.Data) else 16
			local elapsed = math.max(now - carry.LastTime, 0.1)
			if flat > TELEPORT_DISTANCE and flat > walkSpeed * elapsed * 4 then
				notify(player, "Teleporting isn't allowed while carrying something!", "error")
				StealService.Drop(player, "Teleported")
				continue
			end
			carry.LastPos = pos
			carry.LastTime = now
		end

		if not carry.Secured and Layout.IsSafe(pos) then
			carry.Secured = true
			GuardService.StopChase(player, "Safe")
			Remotes.Event("ChaseEnded"):FireClient(player, { Result = "Safe", DonutId = carry.DonutId, Kind = carry.Kind })
		end
		if carry.Secured and PlotService.IsInOwnPlot(player, pos) then
			deposit(player)
		end
	end
end

function StealService.OnCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid.Died:Connect(function()
			if carriers[player] then
				StealService.Drop(player, "You fell! It went back where it came from.")
			end
		end)
	end
end

function StealService.OnPlayerRemoving(player: Player)
	lastFullWarning[player] = nil
	local carry = clearCarry(player)
	GuardService.StopChase(player)
	if carry then
		returnLost(player, carry)
	end
end

function StealService.Init()
	DonutSpawnService.SetStealHandler(trySteal)
	PlotService.Teleporter = StealService.Teleport -- lift pads between base floors
	GuardService.Caught:Connect(onCaught)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.1 then
			accumulator = 0
			updateCarriers()
		end
	end)
end

return StealService
