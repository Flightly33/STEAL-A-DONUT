--[[
	GuardService
	============
	Every player has their OWN guards. The sleeping guard on each blanket is drawn by each player's
	client (see client/Guards.luau), so everyone sees their own sleepy Domer and nobody can wake him
	up for someone else.

	When you steal a box, the server spawns YOUR chasing guard in his corner: he wakes up, yells,
	and chases you - through every biome on the way, keeping his own speed - until he catches you
	or you reach the lobby. Then he walks back to his corner (Config.Guard.ReturnSpeedFactor of his
	chase speed) and, once he's there, your client puts him back to sleep. Pick up one of his boxes
	again while he's still on his way and he turns around and comes after you from wherever he is;
	if he's already home, he wakes up in his corner as usual. Other players' clients hide your
	guard, so you never see anyone else's Domers.

	Guard speed per biome comes from Economy.GuardWalkSpeed (Economy.EscapeSpeed is the Speed that
	just gets you away from him).

	Catching is lag compensated: the server keeps a short history of where the guard was and judges
	the catch against where he was on YOUR screen when you were at your current position (your ping
	+ Roblox's interpolation delay ago, capped at Config.Guard.MaxRewind). Without this, a fast chase
	on a laggy connection could "catch" you while he still looked 40 studs behind. For the same
	reason he chases THROUGH you by that much: otherwise a fast Domer would stop beside you on the
	server while your screen still showed him far behind, and never catch you.
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

local R6_WALK = Config.Guard.WalkAnimation
local R6_IDLE = Config.Guard.IdleAnimation
local UPDATE_INTERVAL = 0.05

type Sample = { Time: number, Position: Vector3 }

export type Guard = {
	AreaId: number,
	Owner: Player,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	State: string, -- "Waking" | "Chasing" | "Celebrating" | "GivingUp" | "Returning"
	Token: number,
	Status: TextLabel,
	ChaseSpeed: number,
	Home: CFrame, -- his corner (where he walks back to)
	ReturnStarted: number,
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

-- Stand still for `seconds` (cheering or fuming), then walk back to his corner.
local function returnAfter(guard: Guard, seconds: number)
	guard.Token += 1
	local token = guard.Token
	guard.Humanoid.WalkSpeed = 0
	guard.Humanoid:MoveTo(guard.Root.Position)
	task.delay(seconds, function()
		if guard.Token == token and guard.Model.Parent then
			guard.State = "Returning"
			guard.ReturnStarted = os.clock()
			guard.Humanoid.WalkSpeed = guard.ChaseSpeed * Config.Guard.ReturnSpeedFactor
			guard.LastCheckPos = guard.Root.Position
			guard.LastCheckTime = os.clock()
			guard.StuckTime = 0
		end
	end)
end

local function startChasing(guard: Guard)
	guard.State = "Chasing"
	guard.Humanoid.WalkSpeed = guard.ChaseSpeed
	guard.LastCheckPos = guard.Root.Position
	guard.LastCheckTime = os.clock()
	guard.StuckTime = 0
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

-- `player` stole a box (or an egg) from `areaId`: their own guard of that biome gives chase - from
-- wherever he is if he's still walking back from the last chase (he turns around), otherwise he
-- wakes up in his corner.
function GuardService.Alert(areaId: number, player: Player): Guard?
	local existing = guards[player]
	if existing and existing.AreaId == areaId and existing.Model.Parent and existing.State ~= "Chasing" and existing.State ~= "Waking" then
		existing.Token += 1
		existing.State = "Waking"
		existing.Humanoid.WalkSpeed = 0
		existing.Humanoid:MoveTo(existing.Root.Position)
		existing.History = {}
		shout(existing, Config.Guard.WakeShouts, Color3.fromRGB(255, 70, 70))
		local token = existing.Token
		task.delay(Config.Guard.TurnDelay, function()
			if existing.Token == token and existing.Model.Parent then
				startChasing(existing)
			end
		end)
		return existing
	end
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
		Home = home,
		ReturnStarted = 0,
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
			startChasing(guard)
		end
	end)
	return guard
end

-- The chase is over (reached safety, deposited, dropped the box, left the game...): he walks home.
function GuardService.StopChase(player: Player, reason: string?)
	local guard = guards[player]
	if not guard or guard.State == "Celebrating" or guard.State == "GivingUp" or guard.State == "Returning" then
		return
	end
	if not player.Parent then
		vanish(guard)
	elseif reason == "Safe" then
		guard.State = "GivingUp"
		shout(guard, { "NOOO! MY DONUT!", "D'OH!", "I'LL GET YOU NEXT TIME!", "WHY YOU LITTLE...!" }, Color3.fromRGB(255, 180, 60))
		returnAfter(guard, Config.Guard.GiveUpDelay)
	else
		guard.State = "GivingUp"
		guard.Status.Text = "..."
		guard.Status.TextColor3 = Color3.fromRGB(220, 220, 220)
		returnAfter(guard, 0.6)
	end
end

-- Is the player's guard of `areaId` out of his corner (chasing, cheering or walking back)?
function GuardService.IsAway(player: Player, areaId: number): boolean
	local guard = guards[player]
	return guard ~= nil and guard.AreaId == areaId and guard.Model.Parent ~= nil
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

-- Walking back to his corner after a chase; once he's there, he's gone (your client shows him
-- asleep in his corner again).
local function updateReturning(guard: Guard, now: number)
	local guardPos = guard.Root.Position
	local home = guard.Home.Position
	local toHome = Vector2.new(home.X - guardPos.X, home.Z - guardPos.Z).Magnitude
	if not guard.Owner.Parent or toHome < 6 or now - guard.ReturnStarted > Config.Guard.MaxReturnSeconds then
		vanish(guard)
		return
	end
	guard.Humanoid:MoveTo(Vector3.new(home.X, guardPos.Y, home.Z))
	if now - guard.LastCheckTime > 0.5 then
		if (guardPos - guard.LastCheckPos).Magnitude < 0.5 * Config.Guard.Scale then
			guard.StuckTime += now - guard.LastCheckTime
			guard.Humanoid.Jump = true
			if guard.StuckTime > 3 then
				vanish(guard) -- (stuck on the way home: just go to sleep)
				return
			end
		else
			guard.StuckTime = 0
		end
		guard.LastCheckPos = guardPos
		guard.LastCheckTime = now
	end
end

local function updateGuard(guard: Guard, now: number)
	if guard.State == "Returning" then
		updateReturning(guard, now)
		return
	end
	if guard.State ~= "Chasing" then
		return
	end
	local target = guard.Owner
	local character = target.Character
	local targetRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not target.Parent then
		vanish(guard)
		return
	end
	if not targetRoot then
		GuardService.StopChase(target)
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
		returnAfter(guard, 1.5)
		GuardService.Caught:Fire(target, guard.AreaId)
		return
	end
	-- Chase: lead the target a little, and aim THROUGH them by as far as their screen is behind
	-- him (their rewind x his speed). The catch is judged where they saw him; if he only ran up to
	-- them, a fast Domer would stay that far behind on their screen and could never catch anyone
	-- (at 300+ studs a second that's 50+ studs). Never step into the safe zone or through the walls.
	local lead = targetRoot.AssemblyLinearVelocity * 0.15
	local toTarget = Vector3.new(targetPos.X - guardPos.X, 0, targetPos.Z - guardPos.Z)
	local through = if toTarget.Magnitude > 0.1 then toTarget.Unit * guard.ChaseSpeed * rewindFor(target) else Vector3.zero
	local goal = targetPos + Vector3.new(lead.X, 0, lead.Z) + through
	-- (he follows you through the other biomes: keep him inside whichever one he's in)
	local minX, maxX = Layout.LaneLimits(math.max(Layout.AreaAt(guardPos), 1))
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
