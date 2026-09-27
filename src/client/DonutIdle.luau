--[[
	DonutIdle: idle animations for the donuts standing on bases (every base, all client-side, so the
	server never has to replicate any of it).

	Every donut gets its own personality, picked from its id and the stand it's on:
	  Bounce - happy little hops (feet kick, arms go up)
	  Sway   - rocks side to side, arms swinging
	  Dance  - bops to a beat, arms up in turn, feet stepping
	  Look   - stands still, breathing, looking around
	  Float  - rare / mutated donuts that float: hover, spin and flap their wings
	Every few seconds a donut does something special (a twirl, a big jump, a wave, a wiggle) and they
	all blink. Propellers spin, orbiting orbs orbit, tentacles wiggle and capes flutter.

	How it works: a donut is one anchored Root with every other part welded to it (DonutModel), so
	moving Root moves the whole donut, and changing a limb's weld (C0) bends that limb around the
	"Pivot" the server stored on it. Only donuts near the camera are animated.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DonutIdle = {}

local player = Players.LocalPlayer :: Player
local RANGE = 110 -- studs from the camera; further donuts stand still
local NEAR = 45 -- closer than this: every frame, otherwise 30 times a second
local TAU = math.pi * 2
local STYLES = { "Bounce", "Sway", "Dance", "Look" }
local ACTION_LENGTH: { [string]: number } = { Twirl = 0.9, Jump = 0.7, Wiggle = 0.8, Wave = 1.6 }
local LOOK_TARGETS = { -0.55, 0, 0.55, 0, -0.3, 0.3 }

type Limb = { Weld: Weld, Base: CFrame, Pivot: CFrame, Kind: string, Side: number, Phase: number }

type Idle = {
	Model: Model,
	Root: BasePart,
	Base: CFrame,
	Bottom: number,
	Scale: number,
	Style: string,
	Rng: Random,
	Phase: number,
	Limbs: { Limb },
	Lids: { BasePart },
	HasArms: boolean,
	Blinking: boolean,
	NextBlink: number,
	BlinkUntil: number,
	Action: string?,
	ActionStart: number,
	NextAction: number,
	Yaw: number,
	LookTarget: number,
	NextLook: number,
	Active: boolean,
	Accum: number,
}

local idles: { [Model]: Idle } = {}
local clock = 0 -- animation time: rendered seconds (pauses when the game does)

local function hashString(text: string): number
	local hash = 7
	for i = 1, #text do
		hash = (hash * 31 + string.byte(text, i)) % 2147483647
	end
	return hash
end

local function smooth(a: number): number
	return a * a * (3 - 2 * a)
end

local function setBlink(idle: Idle, closed: boolean)
	if idle.Blinking == closed then
		return
	end
	idle.Blinking = closed
	for _, lid in idle.Lids do
		lid.Transparency = if closed then 0 else 1
	end
end

-- Back to the pose the server built (when the donut goes out of range).
local function reset(idle: Idle)
	idle.Root.CFrame = idle.Base
	for _, limb in idle.Limbs do
		limb.Weld.C0 = limb.Base
	end
	setBlink(idle, false)
end

local function register(instance: Instance)
	if not instance:IsA("Model") or idles[instance] then
		return
	end
	local model = instance
	task.wait(0.3) -- let every part of the donut arrive
	if not model.Parent then
		return
	end
	local root = model.PrimaryPart or model:FindFirstChild("Root")
	if not root or not root:IsA("BasePart") then
		return
	end
	local donutId = model:GetAttribute("DonutId")
	local stand = model:GetAttribute("IdleSeed")
	local seed = hashString(if type(donutId) == "string" then donutId else model.Name) + (if type(stand) == "number" then stand * 7919 else 0)
	local rng = Random.new(seed)

	local limbs: { Limb } = {}
	local lids: { BasePart } = {}
	local hasArms = false
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local kind = part:GetAttribute("Limb")
			local weld = part:FindFirstChildOfClass("Weld")
			if type(kind) == "string" and weld then
				local pivot = part:GetAttribute("Pivot")
				local side = part:GetAttribute("Side")
				table.insert(limbs, {
					Weld = weld,
					Base = weld.C0,
					Pivot = CFrame.new(if typeof(pivot) == "Vector3" then pivot else Vector3.zero),
					Kind = kind,
					Side = if type(side) == "number" then side else 0,
					Phase = rng:NextNumber(0, TAU),
				})
				hasArms = hasArms or kind == "Arm"
			end
			if part:GetAttribute("Blink") then
				table.insert(lids, part)
			end
		end
	end

	local now = clock
	local bottom = model:GetAttribute("Bottom")
	idles[model] = {
		Model = model,
		Root = root,
		Base = root.CFrame,
		Bottom = if type(bottom) == "number" then bottom else 1.5,
		Scale = root.Size.Y / 3,
		Style = if CollectionService:HasTag(model, "DonutFloat") then "Float" else STYLES[rng:NextInteger(1, #STYLES)],
		Rng = rng,
		Phase = rng:NextNumber(0, 10),
		Limbs = limbs,
		Lids = lids,
		HasArms = hasArms,
		Blinking = false,
		NextBlink = now + rng:NextNumber(0.5, 4),
		BlinkUntil = 0,
		Action = nil,
		ActionStart = 0,
		NextAction = now + rng:NextNumber(2, 10),
		Yaw = 0,
		LookTarget = 0,
		NextLook = now + rng:NextNumber(0.5, 2),
		Active = false,
		Accum = 0,
	}
end

local function animate(idle: Idle, now: number, dt: number)
	local t = now + idle.Phase
	local k = idle.Scale
	local y, yaw, pitch, roll = 0, 0, 0, 0
	-- Limb amounts. Arms: 0 = relaxed, 0.5 = the built "hands up" pose, 1 = straight up.
	-- Legs: positive kicks the feet forward. Wings: positive = tips up.
	local legL, legR, armL, armR, wing = 0, 0, 0.2, 0.2, 0

	local style = idle.Style
	if style == "Float" then
		y = 0.35 * k * math.sin(t * 2)
		yaw = (t * 0.9) % TAU
		wing = 0.35 * math.sin(t * 7)
		legL = 0.25 * math.sin(t * 3)
		legR = -legL
		armL = 0.45 + 0.15 * math.sin(t * 2.5)
		armR = 0.45 + 0.15 * math.sin(t * 2.5 + 1)
	elseif style == "Bounce" then
		local u = (t * 0.75) % 1 -- one hop every 1.33 s
		local hop = if u < 0.45 then math.sin(u / 0.45 * math.pi) else 0
		y = 0.45 * k * hop
		if u > 0.85 then
			y -= 0.06 * k * math.sin((u - 0.85) / 0.15 * math.pi) -- little squat before the next hop
		end
		pitch = -0.08 * hop
		legL = 0.5 * hop
		legR = legL
		armL = 0.2 + 0.6 * hop
		armR = armL
		wing = 0.3 * hop
	elseif style == "Sway" then
		local w = 1.7
		roll = 0.13 * math.sin(t * w)
		yaw = 0.1 * math.sin(t * w * 0.5)
		y = 0.05 * k * math.abs(math.sin(t * w))
		legL = 0.15 * math.sin(t * w)
		legR = -legL
		armL = 0.3 + 0.25 * math.sin(t * w)
		armR = 0.3 - 0.25 * math.sin(t * w)
		wing = 0.15 * math.sin(t * w * 2)
	elseif style == "Dance" then
		local w = TAU * 1.1 -- beats per second
		local beat = math.abs(math.sin(t * w / 2))
		y = 0.14 * k * beat
		roll = 0.14 * math.sin(t * w / 2)
		yaw = 0.3 * math.sin(t * w / 4)
		legL = 0.35 * math.sin(t * w / 2)
		legR = -legL
		armL = 0.2 + 0.7 * math.max(0, math.sin(t * w / 2))
		armR = 0.2 + 0.7 * math.max(0, -math.sin(t * w / 2))
		wing = 0.25 * beat
	else -- Look: breathe, and turn to look at things now and then
		y = 0.04 * k * math.sin(t * 1.8)
		if now >= idle.NextLook then
			idle.LookTarget = LOOK_TARGETS[idle.Rng:NextInteger(1, #LOOK_TARGETS)]
			idle.NextLook = now + idle.Rng:NextNumber(1.2, 3.5)
		end
		idle.Yaw += (idle.LookTarget - idle.Yaw) * (1 - math.exp(-5 * dt))
		yaw = idle.Yaw
		pitch = 0.03 * math.sin(t * 1.8)
		legL = 0.06 * math.sin(t * 0.9) -- shifting its weight from foot to foot
		legR = -legL
		armL = 0.15 + 0.06 * math.sin(t * 1.8)
		armR = armL
		wing = 0.08 * math.sin(t * 1.8)
	end

	-- A special move every few seconds
	if not idle.Action and now >= idle.NextAction then
		local options = { "Twirl", "Jump", "Wiggle" }
		if idle.HasArms then
			table.insert(options, "Wave")
			table.insert(options, "Wave")
		end
		idle.Action = options[idle.Rng:NextInteger(1, #options)]
		idle.ActionStart = now
	end
	local action = idle.Action
	if action then
		local a = (now - idle.ActionStart) / ACTION_LENGTH[action]
		if a >= 1 then
			idle.Action = nil
			idle.NextAction = now + idle.Rng:NextNumber(6, 14)
		elseif action == "Twirl" then
			yaw += TAU * smooth(a)
			y += 0.35 * k * math.sin(a * math.pi)
		elseif action == "Jump" then
			local h = math.sin(a * math.pi)
			y += 0.9 * k * h
			legL = 0.7 * h
			legR = legL
			armL = 0.2 + 0.8 * h
			armR = armL
			wing = 0.6 * h * math.sin(a * TAU * 3)
		elseif action == "Wiggle" then
			roll += 0.25 * math.sin(a * TAU * 3) * (1 - a)
		elseif action == "Wave" then
			local up = math.min(1, a * 4, (1 - a) * 4)
			armR = armR + (0.85 - armR) * up + 0.3 * up * math.sin(a * TAU * 3)
			roll += 0.04 * up
		end
	end

	-- Blink
	if #idle.Lids > 0 then
		if idle.Blinking then
			if now >= idle.BlinkUntil then
				setBlink(idle, false)
			end
		elseif now >= idle.NextBlink then
			setBlink(idle, true)
			idle.BlinkUntil = now + 0.13
			-- sometimes a quick double blink
			idle.NextBlink = now + (if idle.Rng:NextNumber() < 0.2 then 0.3 else idle.Rng:NextNumber(2, 5))
		end
	end

	-- Body: rock around the feet, turn around the middle
	local b = idle.Bottom
	idle.Root.CFrame = idle.Base
		* CFrame.new(0, y, 0)
		* CFrame.Angles(0, yaw, 0)
		* CFrame.new(0, -b, 0)
		* CFrame.Angles(pitch, 0, roll)
		* CFrame.new(0, b, 0)

	-- Limbs: swing each one around its pivot
	for _, limb in idle.Limbs do
		local kind = limb.Kind
		local rotation: CFrame
		if kind == "Leg" then
			rotation = CFrame.Angles(if limb.Side < 0 then legL else legR, 0, 0)
		elseif kind == "Arm" then
			rotation = CFrame.Angles(0, 0, limb.Side * ((if limb.Side < 0 then armL else armR) - 0.5))
		elseif kind == "Wing" then
			rotation = CFrame.Angles(0, 0, limb.Side * wing)
		elseif kind == "Spin" then
			rotation = CFrame.Angles(0, (t * 14) % TAU, 0)
		elseif kind == "Orbit" then
			rotation = CFrame.Angles(0, (t * 1.3) % TAU, 0)
		elseif kind == "Tentacle" then
			rotation = CFrame.Angles(0, 0, 0.2 * math.sin(t * 3 + limb.Phase))
		elseif kind == "Cape" then
			rotation = CFrame.Angles(0.12 + 0.08 * math.sin(t * 2.2), 0, 0.03 * math.sin(t * 1.3))
		else
			rotation = CFrame.identity
		end
		limb.Weld.C0 = limb.Pivot * rotation * limb.Pivot:Inverse() * limb.Base
	end
end

local function focusPosition(): Vector3?
	local camera = workspace.CurrentCamera
	if camera then
		return camera.CFrame.Position
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

function DonutIdle.Init()
	for _, instance in CollectionService:GetTagged("BaseDonut") do
		task.spawn(register, instance)
	end
	CollectionService:GetInstanceAddedSignal("BaseDonut"):Connect(register)
	CollectionService:GetInstanceRemovedSignal("BaseDonut"):Connect(function(instance)
		if instance:IsA("Model") then
			idles[instance] = nil
		end
	end)

	RunService.RenderStepped:Connect(function(dt: number)
		local focus = focusPosition()
		if not focus then
			return
		end
		clock += dt
		local now = clock
		for model, idle in idles do
			if not model.Parent then
				idles[model] = nil
				continue
			end
			local distance = (idle.Base.Position - focus).Magnitude
			if distance < RANGE then
				idle.Active = true
				idle.Accum += dt
				if distance < NEAR or idle.Accum >= 1 / 30 then
					animate(idle, now, idle.Accum)
					idle.Accum = 0
				end
			elseif idle.Active then
				idle.Active = false
				reset(idle)
			end
		end
	end)
end

return DonutIdle
