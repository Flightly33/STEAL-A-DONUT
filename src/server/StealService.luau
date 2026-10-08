--[[
	StealService
	============
	The core loop:
	  1. Hold E on a donut box by a biome's Domer -> you pick it up (you carry it in your arms) and
	     YOUR Domer of that biome wakes up and chases you. With the biome's Speed you just get out
	     of his biome before he catches you (Economy.GuardWalkSpeed); big boxes slow you down.
	  2. Get back to the lobby (cross the safe-zone line) -> Domer gives up and the box goes into
	     your inventory (InventoryService). Put it down in your pen and its timer starts.
	  If Domer catches you, you're flung. Inside his biome he takes the box back to his corner
	  (BoxService.ReturnToDomer); outside it the box drops on the ground right there and he walks
	  home. Anyone can pick a box up off the ground - and whoever does gets chased by that biome's
	  Domer (from wherever he is: see GuardService.Alert). Get hit by someone's bat while carrying
	  a box and it drops right there too. Drop it yourself (the Drop button) and it goes back onto
	  its spot if you're still in its biome, or onto the ground anywhere else.

	What you carry is drawn by every client (client/Carried.luau) from the player's attributes:
	CarryingDonut (the box's tier, the donut's id or the egg's id), CarryKind, CarryMutation and
	CarrySize (and CarryArea for boxes). The server never builds or welds a model for it.

	Everything you can carry uses the same system:
	  Box   -> a donut box from a biome (BoxService)
	  Egg   -> a pet egg from a biome (see PetService; returns to its spot when lost)
	  Shard -> a meteor shard (MeteorService; yours in the lobby, drops where you are when lost)
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Boxes = require(Shared.Boxes)
local Rarities = require(Shared.Rarities)
local Economy = require(Shared.Economy)
local Layout = require(Shared.Layout)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local BoxService = require(script.Parent.BoxService)
local GuardService = require(script.Parent.GuardService)
local InventoryService = require(script.Parent.InventoryService)

local StealService = {}

export type Carry = {
	Kind: string, -- "Box" | "Egg"
	DonutId: string, -- boxes: the box's tier; eggs: the egg's id
	Level: number,
	Mutation: string,
	Size: string, -- the box's size
	Record: BoxService.BoxRecord?, -- boxes: the box
	AreaId: number, -- the biome whose Domer is after you (0 = none)
	Secured: boolean, -- made it to the lobby
	LastPos: Vector3,
	LastTime: number,
	-- Custom behaviour (eggs, meteor shards): deposit returns false to keep carrying; lost puts it
	-- back. DepositInLobby: it's yours the moment you're back in the lobby (else: in your own base).
	OnDeposit: ((Player) -> boolean)?,
	DepositInLobby: boolean?,
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
	if player.Parent then
		player:SetAttribute("CarryingDonut", nil)
		player:SetAttribute("CarrySize", nil)
		player:SetAttribute("CarryKind", nil)
		player:SetAttribute("CarryMutation", nil)
		player:SetAttribute("CarryArea", nil)
	end
	return carry
end

local function startCarry(player: Player, carry: Carry)
	carriers[player] = carry
	-- (clients draw what's carried from these: see client/Carried.luau)
	player:SetAttribute("CarryMutation", carry.Mutation)
	player:SetAttribute("CarrySize", carry.Size)
	player:SetAttribute("CarryArea", if carry.Kind == "Box" then carry.AreaId else nil)
	player:SetAttribute("CarryKind", carry.Kind)
	player:SetAttribute("CarryingDonut", carry.DonutId)
end

local function positionOf(player: Player, carry: Carry): Vector3
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position else carry.LastPos
end

-- What happens to whatever the player was carrying when they lose it. `how`:
--   "Caught"  Domer got you: in his own biome he takes the box back to his corner; anywhere else
--             it drops on the ground right there
--   "Knocked" hit by a bat: the box drops on the ground right there, so the hitter can grab it
--   nil       dropped it, left, teleported...: back on its spot in its own biome, else the ground
-- Returns true when the box went back to Domer's corner.
local function lose(player: Player, carry: Carry, how: string?): boolean
	if carry.OnLost then
		carry.OnLost(player)
	elseif carry.Kind == "Box" and carry.Record then
		local position = positionOf(player, carry)
		local inHisBiome = Layout.AreaAt(position) == carry.AreaId
		if how == "Caught" and inHisBiome then
			BoxService.ReturnToDomer(carry.Record)
			return true
		elseif how == nil and inHisBiome then
			BoxService.Return(carry.Record, position)
			return true
		else
			BoxService.Drop(carry.Record, position)
		end
	end
	return false
end

-- Move a player somewhere without tripping the carry speed check (teleports, speed gates).
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

-- Lose what you're carrying without bringing it home (dropped it, died, left, cheated...).
function StealService.Drop(player: Player, reason: string?)
	local carry = carriers[player]
	if not carry then
		return
	end
	lose(player, carry) -- (before clearing: it needs to know where the player is)
	clearCarry(player)
	GuardService.StopChase(player)
	if player.Parent then
		Remotes.Event("ChaseEnded"):FireClient(player, { Result = "Lost", Reason = reason, Kind = carry.Kind })
	end
end

-- Weapons call this: anyone carrying something drops it. A box lands on the ground right there
-- (anyone can grab it).
function StealService.Knock(player: Player)
	local carry = carriers[player]
	if not carry then
		return
	end
	lose(player, carry, "Knocked")
	clearCarry(player)
	GuardService.StopChase(player)
	if player.Parent then
		local reason = if carry.Kind == "Box" then "You got hit and dropped the box! Grab it before someone else does!"
			elseif carry.Kind == "Shard" then "You got hit and dropped the meteor shard! Grab it before someone else does!"
			else "You got hit! It went back where it came from."
		Remotes.Event("ChaseEnded"):FireClient(player, { Result = "Lost", Reason = reason, Kind = carry.Kind })
	end
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

-- Someone grabbed a box (from its spot by Domer, or off the ground).
local function trySteal(player: Player, record: BoxService.BoxRecord)
	local model = record.Model
	if not model then
		return
	end
	local root = StealService.CanPickUp(player, model:GetPivot().Position, 18 + 6 * Boxes.Size(record.Size).Scale)
	if not root then
		return
	end
	if InventoryService.IsFull(player) then
		notify(player, "Your inventory is full! Put some boxes in your pen or sell donuts first.", "error")
		return
	end
	if not BoxService.Take(record) then
		return
	end
	startCarry(player, {
		Kind = "Box",
		DonutId = record.Tier,
		Level = 1,
		Mutation = record.Mutation,
		Size = record.Size,
		Record = record,
		AreaId = record.AreaId,
		Secured = false,
		LastPos = root.Position,
		LastTime = os.clock(),
	})

	-- The box's own Domer gives chase: from his corner, or from wherever he is if he's still walking
	-- back there after the last chase.
	local guard = GuardService.Alert(record.AreaId, player)
	Remotes.Event("ChaseStarted"):FireClient(player, {
		DonutId = record.Tier,
		AreaId = record.AreaId,
		Kind = "Box",
		Mutation = record.Mutation,
		Size = record.Size,
		Guard = guard and guard.Model,
		GuardSpeed = Economy.GuardWalkSpeed(record.AreaId),
	})

	local tier = Boxes.Tier(record.Tier)
	-- (the biome's rarest box, or a big mutation)
	if Boxes.Rank(record.AreaId, record.Tier) >= 3 or Rarities.Mutation(record.Mutation).Order >= 3 then
		local name = Rarities.DisplayName(Boxes.DisplayName(record.Tier, record.Size), record.Mutation, nil)
		Remotes.Event("AreaAnnouncement"):FireAllClients(`{player.DisplayName} is stealing a {string.upper(name)}!`, tier.Color)
	end
end

-- Made it back to the lobby with a box: it goes into the inventory.
local function depositBox(player: Player, carry: Carry)
	local record = carry.Record
	if not record then
		return
	end
	if not InventoryService.AddBox(player, record.Tier, record.Size, record.AreaId, record.Mutation) then
		local now = os.clock()
		if not lastFullWarning[player] or now - lastFullWarning[player] > 4 then
			lastFullWarning[player] = now
			notify(player, "Your inventory is full! Put some boxes in your pen or sell donuts.", "error")
		end
		return -- keep carrying until there's room
	end
	clearCarry(player)
	GuardService.StopChase(player, "Safe")
	BoxService.Release(record)
	local name = Rarities.DisplayName(Boxes.DisplayName(record.Tier, record.Size), record.Mutation, nil)
	Remotes.Event("ChaseEnded"):FireClient(player, { Result = "Deposited", Kind = "Box", Tier = record.Tier, Size = record.Size, Mutation = record.Mutation })
	notify(player, `{name} is in your inventory! Hold it and click in your pen to put it down.`, "success")
	player:SetAttribute("BoxesStolen", ((player:GetAttribute("BoxesStolen") :: number?) or 0) + 1) -- (the tutorial watches this)
end

-- Made it home with an egg: into the incubator (PetService decides).
local function depositHome(player: Player, carry: Carry)
	if carry.OnDeposit and carry.OnDeposit(player) then
		clearCarry(player)
		GuardService.StopChase(player)
	end
end

local function onCaught(player: Player, areaId: number)
	local carry = carriers[player]
	if not carry then
		return
	end
	local back = lose(player, carry, "Caught")
	clearCarry(player)
	local profile = DataService.Get(player)
	Remotes.Event("ChaseEnded"):FireClient(player, { Result = "Caught", AreaId = areaId, Kind = carry.Kind, BoxBack = back })
	if not profile then
		return
	end
	profile.Session.Stunned = true
	task.delay(Config.Guard.StunTime, function()
		if player.Parent then
			-- (you stay wherever Domer flung you: no trip back to your base)
			profile.Session.Stunned = false
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

		-- Teleport-hack guard only: a jump of hundreds of studs in one step - which nobody can run -
		-- drops it. Game teleports (speed gates, the Teleporter pass) go through
		-- StealService.Teleport, which moves LastPos along, so they never trigger this.
		local flat = Vector2.new(pos.X - carry.LastPos.X, pos.Z - carry.LastPos.Z).Magnitude
		if flat > 0.01 then
			local profile = DataService.Get(player)
			local walkSpeed = if profile then Economy.PlayerWalkSpeed(profile.Data.Speed) * DataService.WalkBoost(profile.Data) else 16
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
			if carry.Kind ~= "Box" and not carry.DepositInLobby then
				GuardService.StopChase(player, "Safe")
				Remotes.Event("ChaseEnded"):FireClient(player, { Result = "Safe", DonutId = carry.DonutId, Kind = carry.Kind })
			end
		end
		if carry.Secured then
			if carry.Kind == "Box" then
				depositBox(player, carry)
			elseif carry.DepositInLobby or PlotService.IsInOwnPlot(player, pos) then
				depositHome(player, carry)
			end
		end
	end
end

function StealService.OnCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid.Died:Connect(function()
			if carriers[player] then
				StealService.Drop(player, "You fell and dropped it!")
			end
		end)
	end
end

function StealService.OnPlayerRemoving(player: Player)
	lastFullWarning[player] = nil
	if carriers[player] then
		StealService.Drop(player, "Left")
	end
	GuardService.StopChase(player)
end

function StealService.Init()
	BoxService.SetStealHandler(trySteal)
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
