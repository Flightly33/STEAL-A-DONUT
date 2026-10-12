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

-- A running/walking swing: arms and legs (and a little bob for the body), `phase` in radians.
function Puppet.Stride(phase: number, swing: number): { [string]: CFrame }
	local a = math.sin(phase) * swing
	return {
		["Left Leg"] = CFrame.Angles(a, 0, 0),
		["Right Leg"] = CFrame.Angles(-a, 0, 0),
		["Left Arm"] = CFrame.Angles(-a * 0.9, 0, 0),
		["Right Arm"] = CFrame.Angles(a * 0.9, 0, 0),
	}
end

return Puppet
