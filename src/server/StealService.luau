--[[
	StealService
	============
	The core loop:
	  1. Hold E on a donut in the lane -> you pick it up (it floats above your head) and YOUR guard
	     for that area wakes up and chases you. Big donuts slow you down while you carry them.
	  2. Cross the safe-zone line -> the guard gives up (in other worlds, walk into the portal home).
	  3. Walk into your own base -> the donut is placed on a free stand and starts earning money.
	  If the guard catches you first, you drop the donut and get sent back to your base.

	Raids (see RaidService): a donut stolen from another player's base is carried the same way, keeps
	its level, and goes back to its owner if the thief is hit/flung or dies before reaching home.
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

local StealService = {}

type Carry = {
	Kind: string, -- "Lane" | "Raid"
	DonutId: string,
	Level: number,
	Mutation: string,
	Size: string,
	Victim: Player?, -- raids: who it was stolen from
	AreaId: number,
	Visual: Model?,
	Secured: boolean,
	LastPos: Vector3,
	LastTime: number,
}

local carriers: { [Player]: Carry } = {}

local function notify(player: Player, text: string, kind: string?)
	Remotes.Event("Notify"):FireClient(player, text, kind or "info")
end

function StealService.IsCarrying(player: Player): boolean
	return carriers[player] ~= nil
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
	end
	return carry
end

local function startCarry(player: Player, carry: Carry)
	carriers[player] = carry
	player:SetAttribute("CarryingDonut", carry.DonutId)
	player:SetAttribute("CarrySize", carry.Size)
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

-- Lose the donut without depositing it (died, left, cheated...).
function StealService.Drop(player: Player, reason: string?)
	local carry = clearCarry(player)
	if not carry then
		return
	end
	GuardService.StopChase(player)
	if player.Parent then
		Remotes.Event("ChaseEnded"):FireClient(player, { Result = "Lost", Reason = reason })
	end
	-- A raided donut goes back to its owner if they're still here and have room.
	local victim = carry.Victim
	if carry.Kind == "Raid" and victim and victim.Parent then
		local donut = Donuts.ById[carry.DonutId]
		if PlotService.AddDonut(victim, carry.DonutId, carry.Level, carry.Mutation, carry.Size) then
			notify(victim, `🛡 You got your {donut.Name} back!`, "success")
		else
			notify(victim, `Your {donut.Name} was dropped but your base is full, so it's gone.`, "error")
		end
	end
end

-- Weapons and traps call this: anyone carrying a donut drops it.
function StealService.Knock(player: Player)
	if carriers[player] then
		StealService.Drop(player, "You got hit!")
	end
end

local function attachVisual(player: Player, donutId: string, mutationId: string, sizeId: string): Model?
	local character = player.Character
	local head = character and (character:FindFirstChild("Head") :: BasePart?)
	local donut = Donuts.ById[donutId]
	if not character or not head or not donut then
		return nil
	end
	local model = DonutModel.Build(donut, { Scale = 0.55, Mutation = mutationId, Size = sizeId })
	local root = model.PrimaryPart :: BasePart
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
	return model
end

-- Start carrying a donut stolen from `victim`'s base (RaidService already removed it there).
function StealService.StartRaid(thief: Player, victim: Player, slot: DataService.SlotData)
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
		AreaId = 0,
		Visual = attachVisual(thief, slot.Id, mutation, size),
		Secured = true, -- no guard: the only danger is getting hit
		LastPos = root.Position,
		LastTime = os.clock(),
	})
	Remotes.Event("ChaseStarted"):FireClient(thief, { DonutId = slot.Id, AreaId = 0, Raid = true, Mutation = mutation, Size = size })
end

local function trySteal(player: Player, record: DonutSpawnService.SpawnRecord)
	local profile = DataService.Get(player)
	if not profile or not profile.Session.Ready then
		return
	end
	if carriers[player] then
		notify(player, "You're already carrying a donut! Bring it home first.", "error")
		return
	end
	if profile.Session.Stunned then
		return
	end
	if not PlotService.HasFreeSlot(player) then
		notify(player, "Your base is full! Sell a donut (hold F on it) to make room.", "error")
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not root then
		return
	end
	-- Server-side reach check (prompts are client-activated)
	local model = record.Model
	if not model or (model:GetPivot().Position - root.Position).Magnitude > 16 then
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
	local slot = PlotService.AddDonut(player, carry.DonutId, carry.Level, carry.Mutation, carry.Size)
	if not slot then
		notify(player, "Your base is full! Sell a donut (hold F on it) to make room.", "error")
		return -- keep carrying until there's room
	end
	clearCarry(player)
	GuardService.StopChase(player)

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
	Remotes.Event("ChaseEnded"):FireClient(player, { Result = "Deposited", DonutId = donut.Id, IsNew = isNew, Mutation = carry.Mutation, Size = carry.Size })
	notify(player, `{name} is earning {Format.Money(Economy.DonutIncome(donut.Id, carry.Level, carry.Mutation, carry.Size))}/s at your base!`, "success")
	local victim = carry.Victim
	if carry.Kind == "Raid" and victim and victim.Parent then
		notify(victim, `😱 {player.DisplayName} got away with your {name}!`, "error")
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
	local profile = DataService.Get(player)
	Remotes.Event("ChaseEnded"):FireClient(player, { Result = "Caught", AreaId = areaId })
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

		-- Basic anti-teleport: you can't move much faster than your WalkSpeed while carrying.
		-- (Only measured when the position actually changes, so laggy players aren't punished.)
		local flat = Vector2.new(pos.X - carry.LastPos.X, pos.Z - carry.LastPos.Z).Magnitude
		if flat > 0.01 then
			local profile = DataService.Get(player)
			local walkSpeed = Economy.PlayerWalkSpeed(if profile then profile.Data.Speed else 0, Layout.WorldAt(pos))
			local allowed = (walkSpeed * 1.6 + 25) * (now - carry.LastTime) + 6
			if flat > allowed then
				notify(player, "You moved too fast and dropped the donut!", "error")
				StealService.Drop(player, "Moved too fast")
				continue
			end
			carry.LastPos = pos
			carry.LastTime = now
		end

		if not carry.Secured and Layout.IsSafe(pos) then
			carry.Secured = true
			GuardService.StopChase(player, "Safe")
			Remotes.Event("ChaseEnded"):FireClient(player, { Result = "Safe", DonutId = carry.DonutId })
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
				StealService.Drop(player, "You fell!")
			end
		end)
	end
end

function StealService.OnPlayerRemoving(player: Player)
	clearCarry(player)
	GuardService.StopChase(player)
end

function StealService.Init()
	DonutSpawnService.SetStealHandler(trySteal)
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
