--[[
	GuardService
	============
	Every player has their OWN guards. The sleeping guard on each blanket is drawn by each player's
	client (see client/Guards.luau), so everyone sees their own sleepy Domer and nobody can wake him
	up for someone else.

	When you steal a donut, the server spawns YOUR chasing guard at the blanket: he wakes up, yells,
	and chases you until he catches you or you reach the safe zone. Then he poofs away and your
	client puts him back to sleep on his blanket. Other players' clients hide your guard, so you
	never see anyone else's Domers.

	Guard speed per area comes from Economy.GuardWalkSpeed (i.e. from Areas.RecommendedSpeed and the
	world's speed bonus).

	Catching is lag compensated: the server keeps a short history of where the guard was and judges
	the catch against where he was on YOUR screen when you were at your current position (your ping
	+ Roblox's interpolation delay ago, capped at Config.Guard.MaxRewind). Without this, a fast chase
	on a laggy connection could "catch" you while he still looked 40 studs behind.
]]

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Areas = require(Shared.Areas)
local Economy = require(Shared.Economy)
local Layout = require(Shared.Layout)
local Signal = require(Shared.Signal)
local GuardModel = require(Shared.GuardModel)

local MapBuilder = require(script.Parent.MapBuilder)
local DataService = require(script.Parent.DataService)

local GuardService = {}
GuardService.Caught = Signal.new() -- (player, areaId)

local R6_WALK = "rbxassetid://180426354"
local R6_IDLE = "rbxassetid://180435571"
local UPDATE_INTERVAL = 0.05

type Sample = { Time: number, Position: Vector3 }

export type Guard = {
	AreaId: number,
	Owner: Player,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	State: string, -- "Waking" | "Chasing" | "Celebrating" | "GivingUp"
	Token: number,
	Status: TextLabel,
	ChaseSpeed: number,
	LastCheckPos: Vector3,
	LastCheckTime: number,
	StuckTime: number,
	History: { Sample }, -- recent positions, oldest first
}

local guards: { [Player]: Guard } = {} -- at most one chasing guard per player
local folder: Folder
local rng = Random.new()

local function homeCFrame(areaId: number): CFrame
	local marker = MapBuilder.GetArea(areaId):FindFirstChild("GuardHome", true) :: BasePart?
	local position = if marker then marker.Position else Layout.GuardHome(areaId)
	-- Default orientation faces -Z: towards the safe zone, where thieves run.
	return CFrame.new(position.X, 0, position.Z)
end

local function setupAnimations(guard: Guard)
	local animator = guard.Humanoid:FindFirstChildOfClass("Animator") :: Animator
	local walkAnim = Instance.new("Animation")
	walkAnim.AnimationId = R6_WALK
	local idleAnim = Instance.new("Animation")
	idleAnim.AnimationId = R6_IDLE
	local ok, walk = pcall(animator.LoadAnimation, animator, walkAnim)
	local ok2, idle = pcall(animator.LoadAnimation, animator, idleAnim)
	if not ok or not ok2 then
		return
	end
	walk.Priority = Enum.AnimationPriority.Movement
	idle.Priority = Enum.AnimationPriority.Idle
	idle.Looped = true
	walk.Looped = true
	idle:Play(0)
	guard.Humanoid.Running:Connect(function(speed: number)
		if speed > 0.5 then
			if not walk.IsPlaying then
				walk:Play(0.15)
			end
			walk:AdjustSpeed(math.clamp(speed / 14, 0.5, 5))
			if idle.IsPlaying then
				idle:Stop(0.2)
			end
		else
			if walk.IsPlaying then
				walk:Stop(0.2)
			end
			if not idle.IsPlaying then
				idle:Play(0.2)
			end
		end
	end)
end

local function shout(guard: Guard, lines: { string }, color: Color3)
	guard.Status.Text = lines[rng:NextInteger(1, #lines)]
	guard.Status.TextColor3 = color
end

-- Remove the guard (the client shows a poof and puts him back to sleep on his blanket).
local function vanish(guard: Guard)
	if guards[guard.Owner] == guard then
		guards[guard.Owner] = nil
	end
	guard.Token += 1
	guard.Model:Destroy()
end

local function vanishAfter(guard: Guard, seconds: number)
	guard.Token += 1
	local token = guard.Token
	guard.Humanoid.WalkSpeed = 0
	guard.Humanoid:MoveTo(guard.Root.Position)
	task.delay(seconds, function()
		if guard.Token == token then
			vanish(guard)
		end
	end)
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

-- `player` stole a donut in `areaId`: their own guard wakes up and gives chase.
function GuardService.Alert(areaId: number, player: Player): Guard?
	local existing = guards[player]
	if existing then
		vanish(existing)
	end
	local model, status = GuardModel.Build(areaId, { Humanoid = true, CollisionGroup = "Guards" })
	local home = homeCFrame(areaId)
	model:PivotTo(GuardModel.StandCFrame(home))
	model:SetAttribute("OwnerUserId", player.UserId)
	CollectionService:AddTag(model, "Guard")
	model.Parent = folder

	local guard: Guard = {
		AreaId = areaId,
		Owner = player,
		Model = model,
		Humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid,
		Root = model.PrimaryPart :: BasePart,
		State = "Waking",
		Token = 0,
		Status = status,
		ChaseSpeed = Economy.GuardWalkSpeed(areaId),
		LastCheckPos = Vector3.zero,
		LastCheckTime = 0,
		StuckTime = 0,
		History = {},
	}
	guards[player] = guard
	pcall(function()
		guard.Root:SetNetworkOwner(nil) -- the server simulates guards: smooth and not exploitable
	end)
	setupAnimations(guard)

	shout(guard, Config.Guard.WakeShouts, Color3.fromRGB(255, 70, 70))
	guard.Humanoid.WalkSpeed = 0
	guard.Humanoid.Jump = true
	local token = guard.Token
	task.delay(Areas.List[areaId].WakeDelay, function()
		if guard.Token == token and guard.Model.Parent then
			guard.State = "Chasing"
			guard.Humanoid.WalkSpeed = guard.ChaseSpeed
			guard.LastCheckPos = guard.Root.Position
			guard.LastCheckTime = os.clock()
			guard.StuckTime = 0
		end
	end)
	return guard
end

-- The chase is over (reached safety, deposited, dropped the donut, left the game...).
function GuardService.StopChase(player: Player, reason: string?)
	local guard = guards[player]
	if not guard or guard.State == "Celebrating" or guard.State == "GivingUp" then
		return
	end
	if reason == "Safe" then
		guard.State = "GivingUp"
		shout(guard, { "NOOO! MY DONUT!", "D'OH!", "I'LL GET YOU NEXT TIME!", "WHY YOU LITTLE...!" }, Color3.fromRGB(255, 180, 60))
		vanishAfter(guard, Config.Guard.GiveUpDelay)
	elseif player.Parent then
		guard.State = "GivingUp"
		guard.Status.Text = "..."
		guard.Status.TextColor3 = Color3.fromRGB(220, 220, 220)
		vanishAfter(guard, 0.6)
	else
		vanish(guard)
	end
end

function GuardService.GetGuard(player: Player): Guard?
	return guards[player]
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

-- How far back the player's screen is behind the server's guard (round trip + interpolation).
local function rewindFor(player: Player): number
	local ok, ping = pcall(player.GetNetworkPing, player)
	local rtt = if ok and type(ping) == "number" then ping else 0.1
	return math.clamp(rtt + Config.Guard.InterpolationDelay, 0, Config.Guard.MaxRewind)
end

-- Where the guard was `rewind` seconds ago (interpolated from his history).
local function positionAt(guard: Guard, time: number): Vector3
	local history = guard.History
	if #history == 0 or time >= history[#history].Time then
		return guard.Root.Position
	end
	if time <= history[1].Time then
		return history[1].Position
	end
	for i = #history, 2, -1 do
		local older, newer = history[i - 1], history[i]
		if older.Time <= time then
			local alpha = (time - older.Time) / math.max(newer.Time - older.Time, 1e-3)
			return older.Position:Lerp(newer.Position, alpha)
		end
	end
	return history[1].Position
end

-- Distance between the guard and `targetPos` as the target saw it (for the catch and for clients).
function GuardService.PerceivedDistance(guard: Guard, targetPos: Vector3): number
	local seen = positionAt(guard, os.clock() - rewindFor(guard.Owner))
	return flatDistance(seen, targetPos)
end

local function updateGuard(guard: Guard, now: number)
	if guard.State ~= "Chasing" then
		return
	end
	local target = guard.Owner
	local character = target.Character
	local targetRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not target.Parent or not targetRoot then
		vanish(guard)
		return
	end
	local targetPos = targetRoot.Position
	if Layout.IsSafe(targetPos) then
		-- StealService normally ends the chase first; this is just a safety net.
		GuardService.StopChase(target, "Safe")
		return
	end
	local guardPos = guard.Root.Position
	local history = guard.History
	table.insert(history, { Time = now, Position = guardPos })
	while #history > 2 and now - history[1].Time > Config.Guard.MaxRewind + 0.25 do
		table.remove(history, 1)
	end
	-- Admins can switch on "Domer can't catch me" in the admin panel.
	local profile = DataService.Get(target)
	local godMode = profile ~= nil and profile.Session.GodMode
	if not godMode and GuardService.PerceivedDistance(guard, targetPos) <= Config.Guard.CatchRadius and math.abs(guardPos.Y - targetPos.Y) < 6 * Config.Guard.Scale then
		guard.State = "Celebrating"
		shout(guard, Config.Guard.CatchShouts, Color3.fromRGB(120, 255, 120))
		vanishAfter(guard, 1.5)
		GuardService.Caught:Fire(target, guard.AreaId)
		return
	end
	-- Chase (lead the target a little, never step into the safe zone or through the walls)
	local lead = targetRoot.AssemblyLinearVelocity * 0.15
	local goal = targetPos + Vector3.new(lead.X, 0, lead.Z)
	local minX, maxX = Layout.LaneLimits(guard.AreaId)
	local margin = Config.Guard.Scale -- he's huge: keep his body off the walls
	goal = Vector3.new(math.clamp(goal.X, minX + margin, maxX - margin), guardPos.Y, math.max(goal.Z, Config.Map.SafeZoneZ + 3 + margin))
	guard.Humanoid:MoveTo(goal)

	-- Unstick: hop if we haven't moved, nudge forward if still stuck
	if now - guard.LastCheckTime > 0.5 then
		local moved = (guardPos - guard.LastCheckPos).Magnitude
		if moved < 0.5 * Config.Guard.Scale then
			guard.StuckTime += now - guard.LastCheckTime
			guard.Humanoid.Jump = true
			if guard.StuckTime > 1.5 then
				local dir = (goal - guardPos) * Vector3.new(1, 0, 1)
				if dir.Magnitude > 0.1 then
					guard.Model:PivotTo(guard.Model:GetPivot() + dir.Unit * 2 * Config.Guard.Scale)
				end
				guard.StuckTime = 0
			end
		else
			guard.StuckTime = 0
		end
		guard.LastCheckPos = guardPos
		guard.LastCheckTime = now
	end
end

function GuardService.Init()
	pcall(function()
		PhysicsService:RegisterCollisionGroup("Guards")
	end)
	pcall(function()
		PhysicsService:RegisterCollisionGroup("Players")
	end)
	PhysicsService:CollisionGroupSetCollidable("Guards", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("Guards", "Guards", false)
	-- Invisible lids only guards bump into (the pit down to The Black Hole's lab)
	pcall(function()
		PhysicsService:RegisterCollisionGroup("GuardBlock")
	end)
	PhysicsService:CollisionGroupSetCollidable("GuardBlock", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("GuardBlock", "Default", false)
	for _, part in workspace:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("GuardBlocker") then
			part.CollisionGroup = "GuardBlock"
			part.CanCollide = true
		end
	end

	folder = Instance.new("Folder")
	folder.Name = "Guards"
	folder.Parent = workspace

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < UPDATE_INTERVAL then
			return
		end
		accumulator = 0
		local now = os.clock()
		for _, guard in table.clone(guards) do
			if guard.Model.Parent then
				updateGuard(guard, now)
			end
		end
	end)
end

return GuardService
