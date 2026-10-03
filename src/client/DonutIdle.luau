--[[
	DonutIdle: idle animations for the donuts standing on bases and in the lane (all client-side, so
	the server never has to replicate any of it).

	Lane donuts ("LaneDonut") get the gentle Lane style: little hops on the spot, blinking, looking
	around (and at you when you're close), and a wave or a hop to say hi when you walk up. No big
	flips or twirls there. (Floating rare lane donuts are bobbed and spun by Effects instead.)

	Every donut gets its own personality, picked from its id and the stand it's on:
	  Bounce - happy little hops (feet kick, arms flop)
	  Sway   - rocks side to side, arms swinging
	  Dance  - bops to a beat, arms up in turn, feet stepping
	  Look   - stands still, breathing, looking around
	  Float  - rare / mutated donuts that float: hover, spin and flap their wings
	Every few seconds a donut does something special: a twirl, a big jump (crouch, leap, land), a
	backflip, a wave, a cheer, a wiggle, a look around, or a little doze. They blink, their eyes wander,
	and when you walk past they watch you (eyes first, then they turn a little) - and when you come
	close they wave or jump to say hi. Their mouths open while they jump, twirl and cheer.
	Propellers spin, orbiting orbs orbit, tentacles wiggle and capes flutter.

	How it works: a donut is one anchored Root with every other part welded to it (DonutModel), so
	moving Root moves the whole donut, and changing a limb's weld (C0) bends that limb around the
	"Pivot" the server stored on it. Eyes ("EyeWhite") are squashed to blink, pupils ("Pupil") slide
	inside the eyes, and the middle of the smile ("Mouth" = "Middle") stretches into an open mouth.
	Only donuts near the camera are animated.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DonutIdle = {}

local player = Players.LocalPlayer :: Player
local RANGE = 110 -- studs from the camera; further donuts stand still
local NEAR = 45 -- closer than this: every frame, otherwise 30 times a second
local WATCH_RANGE = 30 -- donuts this close to you watch you
local GREET_RANGE = 13 -- ...and say hi when you come this close
local GREET_COOLDOWN = 25
local TAU = math.pi * 2
local STYLES = { "Bounce", "Sway", "Dance", "Look" }
local ACTION_LENGTH: { [string]: number } = {
	Twirl = 0.9,
	Jump = 0.95,
	Flip = 1.15,
	Wiggle = 0.8,
	Wave = 1.6,
	Cheer = 1.3,
	LookAround = 2.2,
	Doze = 2.8,
}
local OPEN_MOUTH: { [string]: boolean } = { Twirl = true, Jump = true, Flip = true, Cheer = true, Wave = true }
local LOOK_TARGETS = { -0.55, 0, 0.55, 0, -0.3, 0.3 }
local CLOSED_EYE = Color3.fromRGB(70, 35, 40)
local GAZE = 0.075 -- how far pupils slide (studs, before the donut's scale)
local EYE_HEIGHT = 1.6 -- eyes above the middle of the donut (before its scale)

type Limb = { Weld: Weld, Base: CFrame, Pivot: CFrame, Kind: string, Side: number, Phase: number }
type Eye = { Part: BasePart, Size: Vector3, Color: Color3 }
type Pupil = { Part: BasePart, Weld: Weld, Base: CFrame }
type Mouth = { Part: BasePart, Weld: Weld, Base: CFrame, Size: Vector3, Corners: { BasePart } }

type Idle = {
	Model: Model,
	Root: BasePart,
	Details: { BasePart }, -- tiny bits (sprinkles, glints, specks) not drawn from far away
	Lod: boolean,
	Base: CFrame,
	Bottom: number,
	Scale: number,
	Style: string,
	Rng: Random,
	Phase: number,
	Limbs: { Limb },
	Eyes: { Eye },
	Pupils: { Pupil },
	Mouth: Mouth?,
	HasArms: boolean,
	Blinking: boolean,
	NextBlink: number,
	BlinkUntil: number,
	MouthOpen: boolean,
	Gaze: Vector2,
	GazeTarget: Vector2,
	NextGaze: number,
	Action: string?,
	ActionStart: number,
	NextAction: number,
	Yaw: number,
	Turn: number,
	LookTarget: number,
	NextLook: number,
	Near: boolean,
	GreetAt: number?,
	NextGreet: number,
	LastY: number,
	Flop: number,
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
	a = math.clamp(a, 0, 1)
	return a * a * (3 - 2 * a)
end

local function approach(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-rate * dt))
end

local function setBlink(idle: Idle, closed: boolean)
	if idle.Blinking == closed then
		return
	end
	idle.Blinking = closed
	for _, eye in idle.Eyes do
		eye.Part.Size = if closed then Vector3.new(eye.Size.X * 1.05, eye.Size.Y * 0.14, eye.Size.Z * 0.8) else eye.Size
		eye.Part.Color = if closed then CLOSED_EYE else eye.Color
	end
	for _, pupil in idle.Pupils do
		pupil.Part.Transparency = if closed then 1 else 0
	end
end

local function setMouth(idle: Idle, open: boolean)
	local mouth = idle.Mouth
	if not mouth or idle.MouthOpen == open then
		return
	end
	idle.MouthOpen = open
	-- The middle of the smile grows into a round "wheee!" mouth, the corners hide
	mouth.Part.Size = if open then Vector3.new(mouth.Size.X * 1.25, mouth.Size.Y * 2.6, mouth.Size.Z) else mouth.Size
	mouth.Weld.C0 = if open then mouth.Base * CFrame.new(0, -mouth.Size.Y * 0.6, 0) else mouth.Base
	for _, corner in mouth.Corners do
		corner.Transparency = if open then 1 else 0
	end
end

local function setGaze(idle: Idle, gaze: Vector2)
	if (gaze - idle.Gaze).Magnitude < 0.004 then
		return
	end
	idle.Gaze = gaze
	local offset = CFrame.new(gaze.X * GAZE * idle.Scale, gaze.Y * GAZE * idle.Scale, 0)
	for _, pupil in idle.Pupils do
		pupil.Weld.C0 = pupil.Base * offset
	end
end

-- Back to the pose the server built (when the donut goes out of range).
local function reset(idle: Idle)
	idle.Root.CFrame = idle.Base
	for _, limb in idle.Limbs do
		limb.Weld.C0 = limb.Base
	end
	setBlink(idle, false)
	setMouth(idle, false)
	setGaze(idle, Vector2.zero)
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
	local lane = CollectionService:HasTag(model, "LaneDonut")
	if lane and CollectionService:HasTag(model, "DonutFloat") then
		return -- (Effects bobs and spins the floating ones)
	end
	local donutId = model:GetAttribute("DonutId")
	local stand = model:GetAttribute("IdleSeed")
	local seed = hashString(if type(donutId) == "string" then donutId else model.Name) + (if type(stand) == "number" then stand * 7919 else 0)
	local rng = Random.new(seed)

	local limbs: { Limb } = {}
	local eyes: { Eye } = {}
	local pupils: { Pupil } = {}
	local mouth: Mouth? = nil
	local corners: { BasePart } = {}
	local phases: { [string]: number } = {} -- parts swinging around the same pivot move together
	local hasArms = false
	local details: { BasePart } = {}
	local tiny = 0.45 * root.Size.Y / 3
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local size = part.Size
			if part ~= root and part.Transparency < 1 and math.max(size.X, size.Y, size.Z) <= tiny then
				table.insert(details, part)
			end
			local kind = part:GetAttribute("Limb")
			local weld = part:FindFirstChildOfClass("Weld")
			if type(kind) == "string" and weld then
				local pivot = part:GetAttribute("Pivot")
				local pivotPosition = if typeof(pivot) == "Vector3" then pivot else Vector3.zero
				local side = part:GetAttribute("Side")
				local key = string.format("%.2f,%.2f,%.2f", pivotPosition.X, pivotPosition.Y, pivotPosition.Z)
				local phase = phases[key] or rng:NextNumber(0, TAU)
				phases[key] = phase
				table.insert(limbs, {
					Weld = weld,
					Base = weld.C0,
					Pivot = CFrame.new(pivotPosition),
					Kind = kind,
					Side = if type(side) == "number" then side else 0,
					Phase = phase,
				})
				hasArms = hasArms or kind == "Arm"
			end
			if part:GetAttribute("EyeWhite") then
				table.insert(eyes, { Part = part, Size = part.Size, Color = part.Color })
			elseif part:GetAttribute("Pupil") and weld then
				table.insert(pupils, { Part = part, Weld = weld, Base = weld.C0 })
			end
			local mouthPart = part:GetAttribute("Mouth")
			if mouthPart == "Middle" and weld then
				mouth = { Part = part, Weld = weld, Base = weld.C0, Size = part.Size, Corners = corners }
			elseif mouthPart == "Corner" then
				table.insert(corners, part)
			end
		end
	end

	local now = clock
	local bottom = model:GetAttribute("Bottom")
	idles[model] = {
		Model = model,
		Root = root,
		Details = details,
		Lod = false,
		Base = root.CFrame,
		Bottom = if type(bottom) == "number" then bottom else 1.5,
		Scale = root.Size.Y / 3,
		Style = if lane then "Lane" elseif CollectionService:HasTag(model, "DonutFloat") then "Float" else STYLES[rng:NextInteger(1, #STYLES)],
		Rng = rng,
		Phase = rng:NextNumber(0, 10),
		Limbs = limbs,
		Eyes = eyes,
		Pupils = pupils,
		Mouth = mouth,
		HasArms = hasArms,
		Blinking = false,
		NextBlink = now + rng:NextNumber(0.5, 4),
		BlinkUntil = 0,
		MouthOpen = false,
		Gaze = Vector2.zero,
		GazeTarget = Vector2.zero,
		NextGaze = now + rng:NextNumber(0.5, 2),
		Action = nil,
		ActionStart = 0,
		NextAction = now + rng:NextNumber(2, 10),
		Yaw = 0,
		Turn = 0,
		LookTarget = 0,
		NextLook = now + rng:NextNumber(0.5, 2),
		Near = false,
		GreetAt = nil,
		NextGreet = 0,
		LastY = 0,
		Flop = 0,
		Active = false,
		Accum = 0,
	}
end

-- Far away: the tiny bits aren't drawn (a whole base of donuts is thousands of parts).
-- (LocalTransparencyModifier only changes this player's screen.)
local LOD_DISTANCE = 125
local function setLod(idle: Idle, far: boolean)
	idle.Lod = far
	local value = if far then 1 else 0
	for _, part in idle.Details do
		pcall(function()
			part.LocalTransparencyModifier = value
		end)
	end
end

local function startAction(idle: Idle, action: string, now: number)
	idle.Action = action
	idle.ActionStart = now
end

local function animate(idle: Idle, now: number, dt: number, target: Vector3?)
	local t = now + idle.Phase
	local k = idle.Scale
	local y, yaw, pitch, roll, flip = 0, 0, 0, 0, 0
	-- Limb amounts. Arms: 0 = relaxed, 0.5 = the built "hands up" pose, 1 = straight up.
	-- Legs: positive kicks the feet forward. Wings: positive = tips up.
	local legL, legR, armL, armR, wing = 0, 0, 0.2, 0.2, 0
	local eyesClosed = false
	local floppy = true -- arms flop with the bounce (off while waving)

	-- Where you are, seen from the donut's stand: angle to turn to face you, and how close you are
	local watching = false
	local faceYaw = 0
	if target then
		local fromStand = idle.Base:PointToObjectSpace(target)
		local distance = Vector3.new(fromStand.X, 0, fromStand.Z).Magnitude
		watching = distance < WATCH_RANGE * math.max(1, k)
		faceYaw = math.atan2(-fromStand.X, -fromStand.Z)
		-- Say hi when you walk up (once in a while, not every donut at once)
		local near = distance < GREET_RANGE * math.max(1, k)
		if near and not idle.Near and now >= idle.NextGreet and idle.Rng:NextNumber() < 0.7 then
			idle.GreetAt = now + idle.Rng:NextNumber(0, 0.6)
			idle.NextGreet = now + GREET_COOLDOWN
		end
		idle.Near = distance < (GREET_RANGE + 6) * math.max(1, k)
	end
	if idle.GreetAt and now >= idle.GreetAt and not idle.Action then
		idle.GreetAt = nil
		startAction(idle, if idle.HasArms then "Wave" else "Jump", now)
	end

	-- Turn a little towards you while you're around (not all the way round if you're behind it)
	local turnTarget = if watching and math.abs(faceYaw) < 2 then math.clamp(faceYaw, -0.7, 0.7) * 0.6 else 0
	idle.Turn = approach(idle.Turn, turnTarget, 2.5, dt)

	local style = idle.Style
	if style == "Float" then
		y = 0.35 * k * math.sin(t * 2)
		yaw = (t * 0.9) % TAU
		wing = 0.35 * math.sin(t * 7)
		legL = 0.25 * math.sin(t * 3)
		legR = -legL
		armL = 0.45 + 0.15 * math.sin(t * 2.5)
		armR = 0.45 + 0.15 * math.sin(t * 2.5 + 1)
		floppy = false
	elseif style == "Bounce" then
		local u = (t * 0.75) % 1 -- one hop every 1.33 s
		local hop = if u < 0.45 then math.sin(u / 0.45 * math.pi) else 0
		y = 0.45 * k * hop
		if u > 0.8 then
			y -= 0.07 * k * math.sin((u - 0.8) / 0.2 * math.pi) -- little squat before the next hop
		elseif u > 0.45 and u < 0.58 then
			y -= 0.05 * k * math.sin((u - 0.45) / 0.13 * math.pi) -- and a soft landing
		end
		pitch = -0.08 * hop
		legL = 0.5 * hop
		legR = legL
		armL = 0.2 + 0.4 * hop
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
	elseif style == "Lane" then
		-- A soft hop on the spot every couple of seconds, breathing in between, looking around
		local u = (t * 0.55) % 1
		local hop = if u < 0.3 then math.sin(u / 0.3 * math.pi) else 0
		y = 0.18 * k * hop + 0.025 * k * math.sin(t * 2.2)
		pitch = -0.05 * hop
		legL = 0.35 * hop
		legR = legL
		armL = 0.2 + 0.25 * hop
		armR = armL
		wing = 0.2 * hop
		if now >= idle.NextLook then
			idle.LookTarget = LOOK_TARGETS[idle.Rng:NextInteger(1, #LOOK_TARGETS)]
			idle.NextLook = now + idle.Rng:NextNumber(1.5, 4)
		end
		local lookAt = if watching and math.abs(faceYaw) < 2 then math.clamp(faceYaw, -0.8, 0.8) else idle.LookTarget * 0.6
		idle.Yaw = approach(idle.Yaw, lookAt, 4, dt)
		yaw = idle.Yaw
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
		floppy = false
	else -- Look: breathe, and turn to look at things now and then (at you, if you're close)
		y = 0.04 * k * math.sin(t * 1.8)
		if now >= idle.NextLook then
			idle.LookTarget = LOOK_TARGETS[idle.Rng:NextInteger(1, #LOOK_TARGETS)]
			idle.NextLook = now + idle.Rng:NextNumber(1.2, 3.5)
		end
		local lookAt = if watching and math.abs(faceYaw) < 2 then math.clamp(faceYaw, -0.8, 0.8) else idle.LookTarget
		idle.Yaw = approach(idle.Yaw, lookAt, 5, dt)
		yaw = idle.Yaw
		pitch = 0.03 * math.sin(t * 1.8)
		legL = 0.06 * math.sin(t * 0.9) -- shifting its weight from foot to foot
		legR = -legL
		armL = 0.15 + 0.06 * math.sin(t * 1.8)
		armR = armL
		wing = 0.08 * math.sin(t * 1.8)
	end
	if style ~= "Float" and style ~= "Look" and style ~= "Lane" then
		yaw += idle.Turn
	end

	-- A special move every few seconds
	if not idle.Action and now >= idle.NextAction then
		local options = if style == "Lane" then { "Wiggle", "LookAround", "Jump" } else { "Twirl", "Jump", "Jump", "Wiggle", "LookAround", "Flip", "Doze" }
		if idle.HasArms and style == "Lane" then
			table.insert(options, "Wave")
		elseif idle.HasArms then
			table.insert(options, "Wave")
			table.insert(options, "Cheer")
			table.insert(options, "Cheer")
		end
		startAction(idle, options[idle.Rng:NextInteger(1, #options)], now)
	end
	local action = idle.Action
	if action then
		local a = (now - idle.ActionStart) / ACTION_LENGTH[action]
		if a >= 1 then
			idle.Action = nil
			idle.NextAction = now + idle.Rng:NextNumber(6, 14)
			action = nil
		elseif action == "Twirl" then
			yaw += TAU * smooth(a)
			y += 0.35 * k * math.sin(a * math.pi)
			armL, armR = 0.7, 0.7
		elseif action == "Jump" or action == "Flip" then
			-- crouch... leap... land
			local high = if action == "Flip" then 1.45 else 0.95
			if a < 0.22 then
				local c = math.sin(a / 0.22 * math.pi * 0.5)
				y -= 0.14 * k * c
				legL, legR = 0.3 * c, 0.3 * c
				armL, armR = 0, 0
				pitch += 0.1 * c
			elseif a < 0.82 then
				local air = (a - 0.22) / 0.6
				local h = math.sin(air * math.pi)
				y += high * k * h
				legL = 0.7 * h
				legR = legL
				armL = 0.2 + 0.8 * h
				armR = armL
				wing = 0.6 * h * math.sin(air * TAU * 3)
				if action == "Flip" then
					flip = -TAU * smooth(air)
				end
			else
				local land = (a - 0.82) / 0.18
				y -= 0.1 * k * math.sin(land * math.pi)
				armL, armR = 0.5 * (1 - land), 0.5 * (1 - land)
			end
		elseif action == "Wiggle" then
			roll += 0.25 * math.sin(a * TAU * 3) * (1 - a)
		elseif action == "Wave" then
			local up = math.min(1, a * 4, (1 - a) * 4)
			armR = armR + (0.85 - armR) * up + 0.3 * up * math.sin(a * TAU * 3)
			roll += 0.05 * up
			floppy = false
		elseif action == "Cheer" then
			local pump = math.abs(math.sin(a * TAU * 1.5))
			y += 0.28 * k * pump
			armL = 0.55 + 0.45 * pump
			armR = armL
			legL, legR = 0.3 * pump, 0.3 * pump
			floppy = false
		elseif action == "LookAround" then
			yaw += 0.75 * math.sin(a * TAU) * math.sin(a * math.pi)
		elseif action == "Doze" then
			-- a stretch and a yawn, then a quick nap
			if a < 0.25 then
				local stretch = math.sin(a / 0.25 * math.pi)
				armL, armR = 0.2 + 0.8 * stretch, 0.2 + 0.8 * stretch
				y += 0.12 * k * stretch
				setMouth(idle, stretch > 0.3)
			else
				eyesClosed = true
				roll += 0.07 * math.sin((a - 0.25) * TAU * 0.8)
				y -= 0.05 * k * (0.5 + 0.5 * math.sin((a - 0.25) * TAU * 1.2))
				armL, armR = 0.05, 0.05
			end
			floppy = false
		end
	end

	-- Arms flop with the bounce: they lag behind, flying up as the donut drops
	local velocity = (y - idle.LastY) / math.max(dt, 1 / 120) / math.max(k, 0.1)
	idle.LastY = y
	idle.Flop = approach(idle.Flop, if floppy then math.clamp(-velocity * 0.12, -0.25, 0.3) else 0, 12, dt)
	armL += idle.Flop
	armR += idle.Flop

	-- Mouth: open for the big moves (the Doze yawn sets it above)
	if action ~= "Doze" then
		setMouth(idle, action ~= nil and OPEN_MOUTH[action] == true)
	end

	-- Blink (and keep them shut while dozing)
	if #idle.Eyes > 0 then
		if eyesClosed then
			setBlink(idle, true)
			idle.BlinkUntil = now + 0.1
		elseif idle.Blinking then
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

	-- Body: rock around the feet, turn and flip around the middle
	local b = idle.Bottom
	local body = idle.Base
		* CFrame.new(0, y, 0)
		* CFrame.Angles(0, yaw, 0)
		* CFrame.Angles(flip, 0, 0)
		* CFrame.new(0, -b, 0)
		* CFrame.Angles(pitch, 0, roll)
		* CFrame.new(0, b, 0)
	idle.Root.CFrame = body

	-- Eyes: follow you while you're close, otherwise wander now and then
	if #idle.Pupils > 0 and not idle.Blinking then
		if watching and target then
			local seen = body:PointToObjectSpace(target)
			if seen.Z < 0 then
				idle.GazeTarget = Vector2.new(math.clamp(seen.X / -seen.Z * 1.6, -1, 1), math.clamp((seen.Y - EYE_HEIGHT * k) / -seen.Z * 1.6, -1, 1))
			else
				idle.GazeTarget = Vector2.new(if seen.X > 0 then 1 else -1, 0)
			end
		elseif action == "LookAround" then
			idle.GazeTarget = Vector2.new(math.clamp(math.sin((now - idle.ActionStart) / ACTION_LENGTH.LookAround * TAU) * 2, -1, 1), 0.2)
		elseif now >= idle.NextGaze then
			idle.GazeTarget = if idle.Rng:NextNumber() < 0.4 then Vector2.zero else Vector2.new(idle.Rng:NextNumber(-1, 1), idle.Rng:NextNumber(-0.6, 0.8))
			idle.NextGaze = now + idle.Rng:NextNumber(0.8, 3)
		end
		-- eyes dart quickly towards what they look at
		local gaze = idle.Gaze:Lerp(idle.GazeTarget, 1 - math.exp(-18 * dt))
		setGaze(idle, gaze)
	end

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
			rotation = CFrame.Angles(0, 0, 0.18 * math.sin(t * 3 + limb.Phase) - limb.Side * 0.12 * math.max(0, y / math.max(k, 0.1)))
		elseif kind == "Cape" then
			rotation = CFrame.Angles(0.12 + 0.08 * math.sin(t * 2.2) + math.clamp(velocity * 0.05, -0.2, 0.2), 0, 0.03 * math.sin(t * 1.3))
		elseif kind == "Tail" then -- wags side to side
			rotation = CFrame.Angles(0, 0.35 * math.sin(t * 4 + limb.Phase), 0)
		elseif kind == "Sway" then -- flags, flames, antennae
			rotation = CFrame.Angles(0.06 * math.sin(t * 2.1 + limb.Phase), 0, 0.12 * math.sin(t * 2.6 + limb.Phase))
		elseif kind == "Roll" then -- clock hands, wind-up keys: turns round the front-back axis
			rotation = CFrame.Angles(0, 0, (t * 1.6) % TAU)
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

-- What donuts look at: your head (or where it would be).
local function watchedPosition(): Vector3?
	local character = player.Character
	if not character then
		return nil
	end
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position + Vector3.new(0, 1.5, 0)
	end
	return nil
end

function DonutIdle.Init()
	for _, tag in { "BaseDonut", "LaneDonut" } do
		for _, instance in CollectionService:GetTagged(tag) do
			task.spawn(register, instance)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(register)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
			if instance:IsA("Model") then
				idles[instance] = nil
			end
		end)
	end

	RunService.RenderStepped:Connect(function(dt: number)
		local focus = focusPosition()
		if not focus then
			return
		end
		clock += dt
		local now = clock
		local target = watchedPosition()
		local camera = workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else focus
		local look = if camera then camera.CFrame.LookVector else Vector3.zero
		for model, idle in idles do
			if not model.Parent then
				idles[model] = nil
				continue
			end
			local distance = (idle.Base.Position - focus).Magnitude
			if idle.Lod then
				if distance < LOD_DISTANCE then
					setLod(idle, false)
				end
			elseif distance > LOD_DISTANCE + 10 then
				setLod(idle, true)
			end
			if distance < RANGE then
				idle.Active = true
				idle.Accum += dt
				-- Off to the side or behind the camera: nobody sees it move, skip it (close ones
				-- always move, they can swing into view any moment). Far ones move at 15 fps.
				local toward = idle.Base.Position - eye
				local inView = distance < NEAR or look == Vector3.zero or toward:Dot(look) > toward.Magnitude * 0.35
				local interval = if distance < NEAR then 0 elseif distance < RANGE * 0.6 then 1 / 30 else 1 / 15
				if inView and idle.Accum >= interval then
					animate(idle, now, idle.Accum, target)
					idle.Accum = 0
				elseif idle.Accum > 1 then
					idle.Accum = 1 -- (don't save up a huge jump while it's out of view)
				end
			elseif idle.Active then
				idle.Active = false
				reset(idle)
			end
		end
	end)
end

return DonutIdle
