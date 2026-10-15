--[[
	AntiFling: running into something (a base's fence, a wall, a prop, a treadmill) never launches
	you, however fast you run.

	Why it used to happen: Roblox's physics turns a hard bump at a high walk speed into a big push
	(up into the air, backwards or spinning), and a humanoid "climbs" anything with ladder-like gaps,
	like the two rails of a pen's fence, at a speed that grows with its walk speed - so at a few
	hundred studs a second, brushing a fence shot you into the sky. So, on your own character:

	  * no climbing (nothing in the game is a ladder) and no tripping over (FallingDown, Ragdoll)
	  * no bounce: every body part has zero elasticity, and it wins over whatever you bump into
	  * after the physics every frame (Heartbeat): going up faster than your highest jump, or on the
	    ground and sliding a different way from where you're steering, or tumbling - put back to
	    what running allows (steering where you're steering, at your walk speed)

	The game's own flings (Domer catching you, a storm rock, a bat, the Cosmic Domer's slam: all
	through UI/Chase) call AntiFling.Allow first: for that long you fly through the air and tumble
	the way the fling means you to. Flying (admin panel), sitting, the treadmill and anything
	anchored are left alone.

	  AntiFling.Allow(seconds)   a fling the game means: hands off (and falling over allowed)
	  AntiFling.Step()           one check, now (Heartbeat calls it; tests too): "fixed", "fine" or why
	                             it left you alone
	  AntiFling.Corrections()    how many times it has stepped in
	  AntiFling.AllowedFor()     seconds left of a fling the game means (0: on guard)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local AntiFling = {}

local player = Players.LocalPlayer :: Player

local allowUntil = 0
local corrections = 0

-- A part's physics with no bounce (its weight beats whatever it hits), keeping its density and grip
local function noBounce(part: BasePart)
	-- (a body part's usual physics if it can't be read: plastic)
	local density, friction, frictionWeight = 0.7, 0.3, 1
	pcall(function()
		local current = part.CurrentPhysicalProperties
		density, friction, frictionWeight = current.Density, current.Friction, current.FrictionWeight
	end)
	pcall(function()
		part.CustomPhysicalProperties = PhysicalProperties.new(density, friction, 0, frictionWeight, 100)
	end)
end

local function setStates(humanoid: Humanoid, fallingDown: boolean)
	pcall(function()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, fallingDown)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	end)
end

local function prepare(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		setStates(humanoid, os.clock() < allowUntil)
	end
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			noBounce(d)
		end
	end
	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			noBounce(d)
		end
	end)
end

local function humanoidOf(): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and root:IsA("BasePart") then
		return humanoid, root
	end
	return nil, nil
end

-- A fling the game means (UI/Chase): hands off for `seconds`, and you may fall over
function AntiFling.Allow(seconds: number)
	local untilTime = os.clock() + seconds
	allowUntil = math.max(allowUntil, untilTime)
	local humanoid = humanoidOf()
	if humanoid then
		setStates(humanoid, true)
	end
	task.delay(seconds + 0.05, function()
		local h = humanoidOf()
		if h and os.clock() >= allowUntil then
			setStates(h, false)
		end
	end)
end

function AntiFling.Corrections(): number
	return corrections
end

-- Seconds left of a fling the game means (0: on guard)
function AntiFling.AllowedFor(): number
	return math.max(0, allowUntil - os.clock())
end

-- How fast a jump leaves the ground (studs a second)
local function jumpVelocity(humanoid: Humanoid): number
	local ok, value = pcall(function(): number
		if humanoid.UseJumpPower then
			return humanoid.JumpPower
		end
		return math.sqrt(2 * workspace.Gravity * humanoid.JumpHeight)
	end)
	return if ok and type(value) == "number" and value > 0 then value else 50
end

local GROUNDED: { [Enum.HumanoidStateType]: boolean } = {
	[Enum.HumanoidStateType.Running] = true,
	[Enum.HumanoidStateType.RunningNoPhysics] = true,
	[Enum.HumanoidStateType.Landed] = true,
}

-- One check. Returns what it did: "fixed", "fine", or why it left you alone.
function AntiFling.Step(): string
	if os.clock() < allowUntil then
		return "allowed"
	end
	if player:GetAttribute("FlyMode") then
		return "flying"
	end
	local humanoid, root = humanoidOf()
	if not humanoid or not root then
		return "no character"
	end
	if root.Anchored then
		return "anchored"
	end
	if humanoid.Health <= 0 then
		return "dead"
	end
	local seated = false
	pcall(function()
		seated = humanoid.Sit or humanoid.PlatformStand
	end)
	pcall(function()
		seated = seated or humanoid.SeatPart ~= nil
	end)
	if seated then
		return "seated"
	end
	local ok, v = pcall(function(): Vector3
		return root.AssemblyLinearVelocity
	end)
	if not ok or typeof(v) ~= "Vector3" then
		return "no velocity"
	end
	local walk = math.max(humanoid.WalkSpeed, 16)
	local jump = jumpVelocity(humanoid)
	local flat = Vector3.new(v.X, 0, v.Z)
	local y = v.Y
	local fixed = false
	-- shot upwards faster than any jump: a bump, not a jump (a little hop at most)
	if y > jump * 1.1 + 2 then
		y = jump * 0.5
		fixed = true
	end
	-- sideways: never much faster than you run; on the ground, the way you're steering
	local steer = Vector3.zero
	pcall(function()
		steer = humanoid.MoveDirection * Vector3.new(1, 0, 1)
	end)
	local wanted = if steer.Magnitude > 0.01 then steer.Unit * walk * math.min(steer.Magnitude, 1) else Vector3.zero
	local state: Enum.HumanoidStateType? = nil
	pcall(function()
		state = humanoid:GetState()
	end)
	if flat.Magnitude > walk * 1.35 + 12 then
		flat = if wanted.Magnitude > 0 then wanted else flat.Unit * math.min(flat.Magnitude, walk)
		fixed = true
	elseif state and GROUNDED[state] and (flat - wanted).Magnitude > walk * 0.75 + 20 then
		-- (pushed back or sideways off a wall while running along: running steers you, not the bump)
		flat = wanted
		fixed = true
	end
	if fixed then
		corrections += 1
		pcall(function()
			root.AssemblyLinearVelocity = Vector3.new(flat.X, y, flat.Z)
		end)
	end
	-- tumbling over (spinning round anything but straight up): stand back up
	pcall(function()
		local w = root.AssemblyAngularVelocity
		if math.abs(w.X) > 4 or math.abs(w.Z) > 4 then
			root.AssemblyAngularVelocity = Vector3.new(0, w.Y, 0)
			corrections += 1
			fixed = true
		end
	end)
	return if fixed then "fixed" else "fine"
end

function AntiFling.Init()
	if player.Character then
		task.spawn(prepare, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		prepare(character)
	end)
	RunService.Heartbeat:Connect(function()
		AntiFling.Step()
	end)
end

return AntiFling
