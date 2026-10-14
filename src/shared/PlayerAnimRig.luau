--[[
	PlayerAnimRig: reads your character's cutscene moves (PlayerAnimData, keyframed in Blender:
	art/player_anims) - for client/PlayerAnims, which plays them, and for publishing them as
	Roblox animations.

	  PlayerAnimRig.Has(name), .Length(name), .Loops(name)
	  PlayerAnimRig.Pose(name, t)   every R15 joint's rotation `t` seconds in (by its part's name:
	                                "RightUpperArm"...), each in its parent part's frame - smooth
	                                between the samples; a looping move wraps round, the others hold
	                                their last pose
	  PlayerAnimRig.R6(pose)        the same pose on an R6 avatar's six joints ("Torso", "Head",
	                                "Right Arm"...): elbows and knees fold into the whole limb
	  PlayerAnimRig.MakeKeyframeSequences(parent)
	                                every move as a KeyframeSequence, for R15 and R6, in a folder
	                                "PlayerAnimations" under `parent`. To publish them (so they also
	                                show to other players): in Studio's command bar run
	                                  require(game.ReplicatedStorage.Shared.PlayerAnimRig).MakeKeyframeSequences(workspace)
	                                then right-click each KeyframeSequence > Save to Roblox, and paste
	                                its ID into Config.PlayerAnimations
]]

local Data = require(script.Parent.PlayerAnimData)

local PlayerAnimRig = {}

local JOINTS = Data.Joints

-- An R6 avatar's joints: its part, its parent part, and its Motor6D's C0 rotation (a standard rig)
local R6C0: { [string]: CFrame } = {
	Torso = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
	Head = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
	["Right Arm"] = CFrame.new(0, 0, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	["Left Arm"] = CFrame.new(0, 0, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	["Right Leg"] = CFrame.new(0, 0, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	["Left Leg"] = CFrame.new(0, 0, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
}
PlayerAnimRig.R6C0 = R6C0
PlayerAnimRig.R6Parents = { Torso = "HumanoidRootPart", Head = "Torso", ["Right Arm"] = "Torso", ["Left Arm"] = "Torso", ["Right Leg"] = "Torso", ["Left Leg"] = "Torso" }

function PlayerAnimRig.Has(name: string): boolean
	return Data.Anims[name] ~= nil
end

function PlayerAnimRig.Length(name: string): number
	local anim = Data.Anims[name]
	return if anim then anim.Length else 0
end

function PlayerAnimRig.Loops(name: string): boolean
	local anim = Data.Anims[name]
	return anim ~= nil and anim.Loop
end

local function rotation(q: { number }): CFrame
	return CFrame.new(0, 0, 0, q[1], q[2], q[3], q[4])
end

function PlayerAnimRig.Pose(name: string, t: number): { [string]: CFrame }
	local anim = Data.Anims[name]
	local pose: { [string]: CFrame } = {}
	if not anim then
		return pose
	end
	local frames = anim.Frames
	local count = #frames
	local f: number
	if anim.Loop then
		f = (t % anim.Length) * Data.Rate
	else
		f = math.clamp(t, 0, anim.Length) * Data.Rate
	end
	local i0 = math.clamp(math.floor(f) + 1, 1, count)
	local i1 = if anim.Loop then (i0 % count) + 1 else math.min(i0 + 1, count)
	local a = math.clamp(f - math.floor(f), 0, 1)
	local row0, row1 = frames[i0], frames[i1]
	for j, joint in JOINTS do
		pose[joint] = rotation(row0[j]):Lerp(rotation(row1[j]), a)
	end
	return pose
end

-- Half way from no turn to `cf` (an elbow or knee folded into an R6 limb)
local function half(cf: CFrame): CFrame
	return CFrame.identity:Lerp(cf, 0.5)
end

function PlayerAnimRig.R6(pose: { [string]: CFrame }): { [string]: CFrame }
	local function j(name: string): CFrame
		return pose[name] or CFrame.identity
	end
	local waist = j("UpperTorso")
	return {
		Torso = j("LowerTorso") * waist,
		Head = j("Head"),
		["Right Arm"] = j("RightUpperArm") * half(j("RightLowerArm")),
		["Left Arm"] = j("LeftUpperArm") * half(j("LeftLowerArm")),
		-- (an R6 avatar's legs hang from its whole torso, an R15's from its lower torso)
		["Right Leg"] = waist:Inverse() * j("RightUpperLeg") * half(j("RightLowerLeg")),
		["Left Leg"] = waist:Inverse() * j("LeftUpperLeg") * half(j("LeftLowerLeg")),
	}
end

-- A joint's turn `body` (in its parent part's frame) as the joint's own Transform, for a joint
-- whose frame (C0) is turned by `frame`
function PlayerAnimRig.InJointFrame(body: CFrame, frame: CFrame): CFrame
	local q = frame.Rotation
	return q:Inverse() * body * q
end

function PlayerAnimRig.MakeKeyframeSequences(parent: Instance): Folder
	local root = Instance.new("Folder")
	root.Name = "PlayerAnimations"
	for _, rig in { "R15", "R6" } do
		local folder = Instance.new("Folder")
		folder.Name = rig
		folder.Parent = root
		for name, anim in Data.Anims do
			local sequence = Instance.new("KeyframeSequence")
			sequence.Name = name
			sequence.Loop = anim.Loop
			sequence.Priority = Enum.AnimationPriority.Action4
			for i = 1, #anim.Frames do
				local t = (i - 1) / Data.Rate
				local keyframe = Instance.new("Keyframe")
				keyframe.Time = math.min(t, anim.Length)
				local pose = PlayerAnimRig.Pose(name, t)
				local poses: { [string]: Pose } = {}
				local hrp = Instance.new("Pose")
				hrp.Name = "HumanoidRootPart"
				hrp.Parent = keyframe
				poses.HumanoidRootPart = hrp
				local function add(part: string, parentPart: string, cf: CFrame)
					local p = Instance.new("Pose")
					p.Name = part
					p.CFrame = cf
					p.Parent = poses[parentPart]
					poses[part] = p
				end
				if rig == "R15" then
					for _, joint in JOINTS do
						local parentName = Data.Parents[joint]
						add(joint, if type(parentName) == "string" then parentName else "HumanoidRootPart", pose[joint])
					end
				else
					local r6 = PlayerAnimRig.R6(pose)
					for _, part in { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" } do
						add(part, PlayerAnimRig.R6Parents[part], PlayerAnimRig.InJointFrame(r6[part], R6C0[part]))
					end
				end
				keyframe.Parent = sequence
			end
			sequence.Parent = folder
		end
	end
	root.Parent = parent
	return root
end

return PlayerAnimRig
