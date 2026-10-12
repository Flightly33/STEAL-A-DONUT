--[[
	Puppet: poses a blocky R6-style character (GuardModel's Domer, BakerModel's baker) by moving its
	parts straight to where they belong - no joints, no physics, so it does exactly what a scene
	(client/Intro, client/Bakers) says, frame by frame.

	The model needs the usual R6 parts (HumanoidRootPart, Torso, Head, Left/Right Arm, Left/Right
	Leg), every other piece welded to one of them. Puppet.new anchors everything and removes the
	joints. Puppet.Pose(puppet, cf, joints) then puts its root at `cf` and turns each limb round its
	joint (shoulder, hip, neck) by joints[limb name] (in the character's own space: +X its right,
	+Y up, -Z its front; e.g. CFrame.Angles(math.rad(-90), 0, 0) swings an arm or leg forward).
]]

local Puppet = {}

export type Puppet = {
	Model: Model,
	Root: BasePart,
	Scale: number, -- studs per rig unit (a standing R6 body is about 5 rig units tall)
	Parts: { BasePart },
	Rest: { CFrame }, -- each part, relative to the root, standing
	Limb: { string }, -- the limb each part belongs to ("Torso" for the body and anything on it)
	Pose: CFrame?, -- where the root was put last
}

local LIMBS = { Head = true, ["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true }

-- Each limb's joint, in rig units from the root (the middle of the torso).
local PIVOTS: { [string]: Vector3 } = {
	Head = Vector3.new(0, 1, 0),
	["Left Arm"] = Vector3.new(-1.5, 0.5, 0),
	["Right Arm"] = Vector3.new(1.5, 0.5, 0),
	["Left Leg"] = Vector3.new(-0.5, -1, 0),
	["Right Leg"] = Vector3.new(0.5, -1, 0),
}
Puppet.Pivots = PIVOTS

local bulkMove = true

function Puppet.new(model: Model): Puppet?
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local torso = model:FindFirstChild("Torso") :: BasePart?
	if not root or not torso then
		return nil
	end
	local origin = root.CFrame
	local puppet: Puppet = { Model = model, Root = root, Scale = torso.Size.Y / 2, Parts = {}, Rest = {}, Limb = {}, Pose = nil }
	local joints = {}
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			local weld = item:FindFirstChildOfClass("Weld")
			local base = if weld and weld.Part0 then weld.Part0 else item
			table.insert(puppet.Parts, item)
			table.insert(puppet.Rest, origin:ToObjectSpace(item.CFrame))
			table.insert(puppet.Limb, if LIMBS[base.Name] then base.Name else "Torso")
		elseif item:IsA("JointInstance") then
			table.insert(joints, item)
		end
	end
	for _, joint in joints do
		joint:Destroy()
	end
	model.PrimaryPart = root
	return puppet
end

-- Adds a piece made after Puppet.new (placed for the standing pose at the root's current spot).
function Puppet.Add(puppet: Puppet, part: BasePart, limb: string)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	table.insert(puppet.Parts, part)
	table.insert(puppet.Rest, puppet.Root.CFrame:ToObjectSpace(part.CFrame))
	table.insert(puppet.Limb, limb)
end

-- Where a part would be, without moving anything.
function Puppet.Where(puppet: Puppet, cf: CFrame, joints: { [string]: CFrame }?, index: number): CFrame
	local rest = puppet.Rest[index]
	local limb = puppet.Limb[index]
	local turn = joints and joints[limb]
	if turn then
		local pivot = CFrame.new(PIVOTS[limb] * puppet.Scale)
		rest = pivot * turn * pivot:Inverse() * rest
	end
	return cf * rest
end

function Puppet.Pose(puppet: Puppet, cf: CFrame, joints: { [string]: CFrame }?)
	puppet.Pose = cf
	local frames = table.create(#puppet.Parts)
	for i in puppet.Parts do
		frames[i] = Puppet.Where(puppet, cf, joints, i)
	end
	if bulkMove then
		local ok = pcall(function()
			workspace:BulkMoveTo(puppet.Parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end)
		bulkMove = ok
	end
	if not bulkMove then
		for i, part in puppet.Parts do
			part.CFrame = frames[i]
		end
	end
end

-- The first part called `name` (e.g. "Hand" on "Right Arm"), or nil.
function Puppet.Find(puppet: Puppet, name: string, limb: string?): number?
	for i, part in puppet.Parts do
		if part.Name == name and (limb == nil or puppet.Limb[i] == limb) then
			return i
		end
	end
	return nil
end

-- A lifelike run: each leg reaches further forward than it kicks back, the arms
-- swing a little out from the body (so they don't pass through it) and lag the legs slightly.
-- Also returns how high the body is in its bounce (0 feet down .. 1 in the air) and which way
-- the shoulders twist (-1..1), for the caller to put on the root.
function Puppet.Gait(phase: number, swing: number): ({ [string]: CFrame }, number, number)
	local s = math.sin(phase)
	local function leg(x: number): CFrame
		-- (forward is negative: a longer reach forward than kick back)
		return CFrame.Angles(if x < 0 then x * 1.15 else x * 0.8, 0, 0)
	end
	local lag = math.sin(phase - 0.25) * swing * 0.85
	return {
		["Left Leg"] = leg(s * swing),
		["Right Leg"] = leg(-s * swing),
		["Left Arm"] = CFrame.Angles(-lag, 0, math.rad(-7)),
		["Right Arm"] = CFrame.Angles(lag, 0, math.rad(7)),
	}, s * s, math.cos(phase)
end

local IDENTITY = CFrame.identity
local JOINT_NAMES = { "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }

-- An Animator plays poses on a puppet and blends from one to the next instead of snapping: each
-- time the `state` you pass to Puppet.Animate changes, it fades from wherever the puppet was over
-- `fade` seconds (the root's lean and turn too, not where it is).
export type Animator = {
	Puppet: Puppet,
	State: string?,
	From: { [string]: CFrame },
	FromTurn: CFrame?,
	Last: { [string]: CFrame },
	LastTurn: CFrame?,
	Fade: number,
	FadeTime: number,
}

function Puppet.Animator(puppet: Puppet): Animator
	return { Puppet = puppet, State = nil, From = {}, FromTurn = nil, Last = {}, LastTurn = nil, Fade = 1, FadeTime = 1 }
end

local function smooth(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * a * (a * (a * 6 - 15) + 10)
end

-- `ground` (optional): the height of the floor - the pose is moved up or down so his feet are on it.
function Puppet.Animate(anim: Animator, dt: number, cf: CFrame, joints: { [string]: CFrame }?, state: string, fade: number?, ground: number?)
	if state ~= anim.State then
		if anim.State ~= nil then
			anim.From = table.clone(anim.Last)
			anim.FromTurn = anim.LastTurn
			anim.Fade = 0
			anim.FadeTime = fade or 0.25
		end
		anim.State = state
	end
	anim.Fade += dt
	local a = smooth(anim.Fade / math.max(anim.FadeTime, 1e-3))
	local out: { [string]: CFrame } = {}
	for _, name in JOINT_NAMES do
		local goal = (joints and joints[name]) or IDENTITY
		out[name] = if a >= 1 then goal else (anim.From[name] or IDENTITY):Lerp(goal, a)
	end
	local pose = cf
	if a < 1 and anim.FromTurn then
		pose = CFrame.new(cf.Position) * anim.FromTurn:Lerp(cf.Rotation, a)
	end
	if ground then
		pose += Vector3.new(0, ground - Puppet.Lowest(anim.Puppet, pose, out), 0)
	end
	anim.Last = out
	anim.LastTurn = pose.Rotation
	Puppet.Pose(anim.Puppet, pose, out)
end

-- How low the feet would reach (world Y of the lowest corner of anything on the legs) for a pose,
-- without moving anything: put the root `floor - Lowest(...)` higher to stand on the floor.
function Puppet.Lowest(puppet: Puppet, cf: CFrame, joints: { [string]: CFrame }?): number
	local lowest = math.huge
	for i, part in puppet.Parts do
		local limb = puppet.Limb[i]
		if limb == "Left Leg" or limb == "Right Leg" then
			local where = Puppet.Where(puppet, cf, joints, i)
			local half = part.Size / 2
			-- (the lowest corner of a turned box: its centre minus the reach of each half-axis down)
			local down = math.abs(where.RightVector.Y) * half.X + math.abs(where.UpVector.Y) * half.Y + math.abs(where.LookVector.Y) * half.Z
			lowest = math.min(lowest, where.Position.Y - down)
		end
	end
	return if lowest == math.huge then cf.Position.Y else lowest
end

return Puppet
