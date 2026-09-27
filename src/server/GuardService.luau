--[[
	GuardService
	============
	One sleepy guard per area, lying on a picnic blanket. When someone steals a donut in his area he
	wakes up, yells, and chases the thief until he either catches them or they cross into the safe
	zone. Then he walks home and goes back to sleep.

	If several players steal in the same area at once, extra guards wake up (Config.Guard.MaxGuardsPerArea).
	Guard speed per area comes from Economy.GuardWalkSpeed (i.e. from Areas.RecommendedSpeed).

	The rig is a standard R6 humanoid built from parts, so it works without any uploaded assets and
	uses Roblox's default R6 walk animation.
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

local MapBuilder = require(script.Parent.MapBuilder)

local GuardService = {}
GuardService.Caught = Signal.new() -- (player, areaId)

local R6_WALK = "rbxassetid://180426354"
local R6_IDLE = "rbxassetid://180435571"
local UPDATE_INTERVAL = 0.05

export type Guard = {
	AreaId: number,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	State: string, -- "Sleeping" | "Waking" | "Chasing" | "Celebrating" | "Returning"
	Target: Player?,
	Extra: boolean,
	Token: number,
	Status: TextLabel,
	Home: CFrame,
	ChaseSpeed: number,
	LastCheckPos: Vector3,
	LastCheckTime: number,
	StuckTime: number,
}

local guardsByArea: { [number]: { Guard } } = {}
local rng = Random.new()

--------------------------------------------------------------------------------
-- Rig
--------------------------------------------------------------------------------
local function newPart(model: Model, name: string, size: Vector3, color: Color3, cf: CFrame): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.CFrame = cf
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	part.CollisionGroup = "Guards"
	part.Parent = model
	return part
end

-- Cosmetic part welded to `base` at `offset` (relative to base).
local function attach(model: Model, base: BasePart, name: string, shape: Enum.PartType, size: Vector3, color: Color3, offset: CFrame, material: Enum.Material?): Part
	local part = newPart(model, name, size, color, base.CFrame * offset)
	part.Shape = shape
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	if material then
		part.Material = material
	end
	local weld = Instance.new("Weld")
	weld.Part0 = base
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
	return part
end

local function motor(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = c0
	m.C1 = c1
	m.MaxVelocity = 0.1
	m.Parent = part0
end

local function buildRig(areaId: number): (Model, TextLabel)
	local area = Areas.List[areaId]
	local look = area.Guard
	local skin, shirt, pants = look.Skin, look.Shirt, look.Pants
	local black = Color3.fromRGB(25, 25, 25)

	local model = Instance.new("Model")
	model.Name = Config.Guard.Name

	local root = newPart(model, "HumanoidRootPart", Vector3.new(2, 2, 1), skin, CFrame.new(0, 3, 0))
	root.Transparency = 1
	root.CanCollide = false
	local torso = newPart(model, "Torso", Vector3.new(2, 2, 1), shirt, CFrame.new(0, 3, 0))
	local head = newPart(model, "Head", Vector3.new(2, 1, 1), skin, CFrame.new(0, 4.5, 0))
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	local rightArm = newPart(model, "Right Arm", Vector3.new(1, 2, 1), skin, CFrame.new(1.5, 3, 0))
	local leftArm = newPart(model, "Left Arm", Vector3.new(1, 2, 1), skin, CFrame.new(-1.5, 3, 0))
	local rightLeg = newPart(model, "Right Leg", Vector3.new(1, 2, 1), pants, CFrame.new(0.5, 1, 0))
	local leftLeg = newPart(model, "Left Leg", Vector3.new(1, 2, 1), pants, CFrame.new(-0.5, 1, 0))
	for _, limb in { rightArm, leftArm, rightLeg, leftLeg } do
		limb.CanCollide = false
	end

	-- Standard R6 joints
	motor("RootJoint", root, torso, CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
	motor("Neck", torso, head, CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
	motor("Right Shoulder", torso, rightArm, CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	motor("Left Shoulder", torso, leftArm, CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
	motor("Right Hip", torso, rightLeg, CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	motor("Left Hip", torso, leftLeg, CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))

	-- The look: big bulging eyes, stubble, two hairs, a donut belly
	local ball, block = Enum.PartType.Ball, Enum.PartType.Block
	for _, side in { -1, 1 } do
		attach(model, head, "Eye", ball, Vector3.one * 0.52, Color3.new(1, 1, 1), CFrame.new(side * 0.26, 0.12, -0.5))
		attach(model, head, "Pupil", ball, Vector3.one * 0.14, black, CFrame.new(side * 0.26, 0.12, -0.76))
		attach(model, head, "Ear", ball, Vector3.one * 0.32, skin, CFrame.new(side * 0.64, -0.05, 0.05))
		attach(model, head, "SideHair", block, Vector3.new(0.06, 0.28, 0.3), black, CFrame.new(side * 0.64, 0.18, 0.22) * CFrame.Angles(0.5, 0, 0))
		attach(model, if side < 0 then leftArm else rightArm, "Sleeve", block, Vector3.new(1.08, 0.75, 1.08), shirt, CFrame.new(0, 0.63, 0))
		attach(model, if side < 0 then leftLeg else rightLeg, "Shoe", block, Vector3.new(1.06, 0.42, 1.35), Color3.fromRGB(60, 60, 65), CFrame.new(0, -0.8, -0.15))
	end
	attach(model, head, "Stubble", ball, Vector3.one * 0.82, Color3.fromRGB(180, 150, 100), CFrame.new(0, -0.28, -0.3))
	attach(model, head, "Mouth", block, Vector3.new(0.4, 0.06, 0.05), black, CFrame.new(0, -0.3, -0.71))
	for i, z in { -0.18, 0.08 } do
		attach(model, head, "Hair" .. i, block, Vector3.new(0.05, 0.32, 0.05), black, CFrame.new(0, 0.72, z) * CFrame.Angles(0.3, 0, 0))
	end
	attach(model, torso, "Belly", ball, Vector3.one * 2.3, shirt, CFrame.new(0, -0.35, -0.45))

	-- Aura for the fancier guards in later areas
	local aura = look.Aura
	if aura == "Fire" then
		local fire = Instance.new("Fire")
		fire.Size = 5
		fire.Heat = 8
		fire.Parent = torso
	elseif aura == "Sparkles" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = shirt
		sparkles.Parent = torso
	elseif aura == "Snow" or aura == "Cosmic" then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(if aura == "Snow" then Color3.new(1, 1, 1) else Color3.fromRGB(255, 200, 255))
		emitter.LightEmission = 1
		emitter.Rate = if aura == "Snow" then 12 else 30
		emitter.Lifetime = NumberRange.new(1, 2)
		emitter.Speed = NumberRange.new(1, 3)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new(0.4, 0)
		emitter.Parent = torso
	end
	if aura == "Neon" or aura == "Cosmic" then
		local light = Instance.new("PointLight")
		light.Color = shirt
		light.Range = 16
		light.Brightness = 2
		light.Parent = torso
		torso.Material = Enum.Material.Neon
	end
	if aura == "Cosmic" then
		local highlight = Instance.new("Highlight")
		highlight.FillTransparency = 1
		highlight.OutlineColor = Color3.fromRGB(255, 220, 255)
		highlight.Parent = model
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 45
	humanoid.Parent = model
	local animator = Instance.new("Animator")
	animator.Parent = humanoid
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

	model.PrimaryPart = root
	model:ScaleTo(Config.Guard.Scale)

	-- Name tag + status line ("Zzz", "D'OH!")
	local tag = Instance.new("BillboardGui")
	tag.Name = "GuardTag"
	tag.Size = UDim2.fromScale(12, 3.2)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 2.2 * Config.Guard.Scale, 0)
	tag.MaxDistance = 160
	tag.LightInfluence = 0
	tag.Parent = head
	local function label(name: string, text: string, color: Color3, y: number, h: number): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, h)
		l.Position = UDim2.fromScale(0, y)
		l.Font = Enum.Font.LuckiestGuy
		l.TextScaled = true
		l.Text = text
		l.TextColor3 = color
		l.TextStrokeTransparency = 0
		l.Parent = tag
		return l
	end
	label("Title", `{look.Title} {Config.Guard.Name}`, Color3.fromRGB(255, 230, 60), 0.5, 0.5)
	local status = label("Status", "Zzz", Color3.fromRGB(180, 220, 255), 0, 0.5)

	CollectionService:AddTag(model, "Guard")
	model:SetAttribute("Area", areaId)
	return model, status
end

--------------------------------------------------------------------------------
-- Animation helpers
--------------------------------------------------------------------------------
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
	guard.Humanoid.Running:Connect(function(speed: number)
		if guard.State == "Sleeping" then
			return
		end
		if speed > 0.5 then
			if not walk.IsPlaying then
				walk:Play(0.15)
			end
			walk:AdjustSpeed(math.clamp(speed / 14, 0.5, 4))
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
	guard.Model:GetAttributeChangedSignal("Sleeping"):Connect(function()
		if guard.Model:GetAttribute("Sleeping") then
			walk:Stop(0)
			idle:Stop(0)
		end
	end)
end

--------------------------------------------------------------------------------
-- States
--------------------------------------------------------------------------------
local function sleep(guard: Guard)
	guard.State = "Sleeping"
	guard.Target = nil
	guard.Token += 1
	guard.Status.Text = "Zzz"
	guard.Status.TextColor3 = Color3.fromRGB(180, 220, 255)
	guard.Model:SetAttribute("Sleeping", true)
	guard.Humanoid:MoveTo(guard.Root.Position)
	guard.Root.Anchored = true
	guard.Humanoid.PlatformStand = true
	-- Lie on his back on the blanket, head pointing away from the hub.
	guard.Model:PivotTo(guard.Home * CFrame.new(0, 0.2 + 0.55 * Config.Guard.Scale, 0) * CFrame.Angles(math.rad(90), 0, 0))
end

local function standUp(guard: Guard)
	guard.Model:SetAttribute("Sleeping", false)
	if guard.Root.Anchored then
		guard.Model:PivotTo(guard.Home * CFrame.new(0, 3 * Config.Guard.Scale + 0.3, 0))
		guard.Root.Anchored = false
		guard.Humanoid.PlatformStand = false
		pcall(function()
			guard.Root:SetNetworkOwner(nil) -- server simulates guards: smooth for everyone, not exploitable
		end)
	end
end

local function shout(guard: Guard, lines: { string }, color: Color3)
	guard.Status.Text = lines[rng:NextInteger(1, #lines)]
	guard.Status.TextColor3 = color
end

local function goHome(guard: Guard)
	guard.State = "Returning"
	guard.Target = nil
	guard.Token += 1
	guard.Humanoid.WalkSpeed = math.max(16, guard.ChaseSpeed * Config.Guard.ReturnSpeedMultiplier)
	guard.Humanoid:MoveTo(guard.Home.Position)
end

local function startChase(guard: Guard, player: Player)
	guard.Target = player
	guard.Token += 1
	local token = guard.Token
	local wasSleeping = guard.State == "Sleeping"
	guard.State = "Waking"
	standUp(guard)
	shout(guard, Config.Guard.WakeShouts, Color3.fromRGB(255, 70, 70))
	guard.Humanoid.WalkSpeed = 0
	guard.Humanoid.Jump = true
	local delayTime = if wasSleeping then Areas.List[guard.AreaId].WakeDelay else 0.35
	task.delay(delayTime, function()
		if guard.Token == token and guard.Target == player and guard.Model.Parent then
			guard.State = "Chasing"
			guard.Humanoid.WalkSpeed = guard.ChaseSpeed
			guard.LastCheckPos = guard.Root.Position
			guard.LastCheckTime = os.clock()
			guard.StuckTime = 0
		end
	end)
end

local function createGuard(areaId: number, extra: boolean): Guard
	local model, status = buildRig(areaId)
	local home = MapBuilder.GetArea(areaId):FindFirstChild("GuardHome", true) :: BasePart?
	-- Facing -Z: towards the hub, where thieves run.
	local homeCf = if home then CFrame.new(home.Position.X, 0, home.Position.Z) else CFrame.new(Layout.GuardHome(areaId))
	local guard: Guard = {
		AreaId = areaId,
		Model = model,
		Humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid,
		Root = model.PrimaryPart :: BasePart,
		State = "Sleeping",
		Target = nil,
		Extra = extra,
		Token = 0,
		Status = status,
		Home = homeCf,
		ChaseSpeed = Economy.GuardWalkSpeed(areaId),
		LastCheckPos = Vector3.zero,
		LastCheckTime = 0,
		StuckTime = 0,
	}
	if extra then
		-- Extra guards pop up standing next to the blanket
		guard.Home = homeCf * CFrame.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(3, 6))
		model:PivotTo(guard.Home * CFrame.new(0, 3 * Config.Guard.Scale + 0.3, 0))
		guard.Root.Anchored = true
		model.Parent = MapBuilder.GetArea(areaId)
	else
		model.Parent = MapBuilder.GetArea(areaId)
		sleep(guard)
	end
	setupAnimations(guard)
	return guard
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

-- A donut was stolen in `areaId` by `player`: wake someone up. Returns the guard (or nil if every
-- guard in the area is already busy).
function GuardService.Alert(areaId: number, player: Player): Guard?
	local list = guardsByArea[areaId]
	if not list then
		return nil
	end
	for _, guard in list do
		if guard.State == "Sleeping" or guard.State == "Returning" then
			startChase(guard, player)
			return guard
		end
	end
	if #list < Config.Guard.MaxGuardsPerArea then
		local guard = createGuard(areaId, true)
		table.insert(list, guard)
		startChase(guard, player)
		return guard
	end
	return nil
end

function GuardService.StopChase(player: Player)
	for _, list in guardsByArea do
		for _, guard in list do
			if guard.Target == player then
				guard.Status.Text = "..."
				guard.Status.TextColor3 = Color3.fromRGB(220, 220, 220)
				goHome(guard)
			end
		end
	end
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local function updateGuard(guard: Guard, now: number)
	local state = guard.State
	if state == "Chasing" then
		local target = guard.Target
		local character = target and target.Character
		local targetRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not target or not targetRoot then
			goHome(guard)
			return
		end
		local targetPos = targetRoot.Position
		if Layout.IsSafe(targetPos) then
			shout(guard, { "NOOO! MY DONUT!", "D'OH!", "I'LL GET YOU NEXT TIME!" }, Color3.fromRGB(255, 180, 60))
			goHome(guard)
			return
		end
		local guardPos = guard.Root.Position
		if flatDistance(guardPos, targetPos) <= Config.Guard.CatchRadius and math.abs(guardPos.Y - targetPos.Y) < 10 then
			guard.State = "Celebrating"
			guard.Target = nil
			guard.Token += 1
			local token = guard.Token
			guard.Humanoid.WalkSpeed = 0
			shout(guard, Config.Guard.CatchShouts, Color3.fromRGB(120, 255, 120))
			GuardService.Caught:Fire(target, guard.AreaId)
			task.delay(1.5, function()
				if guard.Token == token and guard.Model.Parent then
					goHome(guard)
				end
			end)
			return
		end
		-- Chase (lead the target a little, never step into the safe zone or through the walls)
		local lead = targetRoot.AssemblyLinearVelocity * 0.15
		local goal = targetPos + Vector3.new(lead.X, 0, lead.Z)
		local limit = Config.Map.LaneHalfWidth - 8 -- stay off the wall decorations
		goal = Vector3.new(math.clamp(goal.X, -limit, limit), guardPos.Y, math.max(goal.Z, Config.Map.SafeZoneZ + 3))
		guard.Humanoid:MoveTo(goal)

		-- Unstick: hop if we haven't moved, nudge forward if still stuck
		if now - guard.LastCheckTime > 0.5 then
			local moved = (guardPos - guard.LastCheckPos).Magnitude
			if moved < 1 then
				guard.StuckTime += now - guard.LastCheckTime
				guard.Humanoid.Jump = true
				if guard.StuckTime > 1.5 then
					local dir = (goal - guardPos) * Vector3.new(1, 0, 1)
					if dir.Magnitude > 0.1 then
						guard.Model:PivotTo(guard.Model:GetPivot() + dir.Unit * 4)
					end
					guard.StuckTime = 0
				end
			else
				guard.StuckTime = 0
			end
			guard.LastCheckPos = guardPos
			guard.LastCheckTime = now
		end
	elseif state == "Returning" then
		local guardPos = guard.Root.Position
		if flatDistance(guardPos, guard.Home.Position) < 3.5 then
			if guard.Extra then
				guard.Model:Destroy()
				local list = guardsByArea[guard.AreaId]
				local index = table.find(list, guard)
				if index then
					table.remove(list, index)
				end
			else
				sleep(guard)
			end
		elseif now - guard.LastCheckTime > 1 then
			-- Re-issue MoveTo (Humanoid:MoveTo times out after 8 seconds)
			guard.Humanoid:MoveTo(guard.Home.Position)
			if (guardPos - guard.LastCheckPos).Magnitude < 1 then
				guard.Humanoid.Jump = true
			end
			guard.LastCheckPos = guardPos
			guard.LastCheckTime = now
		end
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

	for areaId = 1, #Areas.List do
		guardsByArea[areaId] = { createGuard(areaId, false) }
	end

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < UPDATE_INTERVAL then
			return
		end
		accumulator = 0
		local now = os.clock()
		for _, list in guardsByArea do
			for _, guard in table.clone(list) do
				if guard.State ~= "Sleeping" and guard.Model.Parent then
					updateGuard(guard, now)
				end
			end
		end
	end)
end

return GuardService
