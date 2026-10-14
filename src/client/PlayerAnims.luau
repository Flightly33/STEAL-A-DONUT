--[[
	PlayerAnims: your character's hand-made moves in the cutscenes (keyframed in Blender:
	art/player_anims; the keys are shared/PlayerAnimData), played on your real avatar - every joint:
	waist, neck, shoulders, elbows, wrists, hips, knees and ankles on R15 (R6 avatars get the same
	moves on their six joints), whether its joints are Motor6Ds or the newer AnimationConstraints.

	A move with an ID in Config.PlayerAnimations plays as a normal Roblox animation (so other
	players see it too). Without one it's played right here, from the keyframes, every frame. Either
	way your own animations (the Animate script) are paused while a move plays and come back when it
	stops, and every change of move blends smoothly from wherever your body was.

	  PlayerAnims.Play(character, name, opts?)   opts: { Fade: number?, Then: string? }
	        Fade: seconds to blend into it (0.2). Then: when a move that doesn't loop ends, go straight
	        into this one ("Release": back to your own animations); without it, a move that doesn't
	        loop holds its last pose. Playing the move that's already playing changes nothing.
	  PlayerAnims.Stop(character, fade?)         back to your own animations (blending over `fade`
	                                             seconds, 0.25; 0 = right now)
	  PlayerAnims.Current(character)             the move playing (nil: none)
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Data = require(Shared.PlayerAnimData)
local Rig = require(Shared.PlayerAnimRig)

local PlayerAnims = {}

local R6_PARTS: { string } = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }

-- One joint we turn: its Motor6D (or AnimationConstraint), the turn of its frame (C0), and the
-- Transform we last gave it
type Joint = { Instance: Instance, Frame: CFrame, Written: CFrame? }
type Run = {
	Character: Model,
	R6: boolean,
	Joints: { [string]: Joint },
	Name: string?,
	Clock: number,
	Then: string?,
	-- (the blend: from the pose `From`, over `Fade` seconds, `Fading` seconds in)
	From: { [string]: CFrame },
	Last: { [string]: CFrame },
	Fade: number,
	Fading: number,
	Releasing: boolean,
	Paused: boolean,
	Animate: BaseScript?,
	AnimateWas: boolean,
	Track: AnimationTrack?,
	Tracks: { [string]: AnimationTrack },
	Connections: { RBXScriptConnection },
}

local runs: { [Model]: Run } = {}

local function smooth(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * (3 - 2 * a)
end

-- Every joint the moves turn, by the name of the part it moves
local function findJoints(character: Model, r6: boolean): { [string]: Joint }
	local wanted: { [string]: boolean } = {}
	local names: { string } = if r6 then R6_PARTS else Data.Joints
	for _, name in names do
		wanted[name] = true
	end
	local joints: { [string]: Joint } = {}
	for _, d in character:GetDescendants() do
		local key: string?, frame: CFrame? = nil, nil
		if d:IsA("Motor6D") then
			local part1 = d.Part1
			if part1 then
				key, frame = part1.Name, d.C0
			end
		elseif d:IsA("AnimationConstraint") then
			-- (the newer avatar joints: Attachment0 in the parent part, Attachment1 in the part it moves)
			local a0 = (d :: any).Attachment0 :: Attachment?
			local a1 = (d :: any).Attachment1 :: Attachment?
			local part = a1 and a1.Parent
			if a0 and part then
				key, frame = part.Name, a0.CFrame
			end
		end
		if key and frame and wanted[key] and (not joints[key] or d:IsA("Motor6D")) then
			joints[key] = { Instance = d, Frame = frame.Rotation, Written = nil }
		end
	end
	return joints
end

-- A joint's turn right now, in its parent part's frame (nil: can't tell)
local function read(joint: Joint): CFrame?
	local ok, value = pcall(function()
		return (joint.Instance :: any).Transform
	end)
	if ok and typeof(value) == "CFrame" then
		return joint.Frame * value * joint.Frame:Inverse()
	end
	return nil
end

local function write(joint: Joint, body: CFrame)
	local value = Rig.InJointFrame(body, joint.Frame)
	pcall(function()
		(joint.Instance :: any).Transform = value
	end)
	joint.Written = value
end

-- While letting go: whatever your own animations put on a joint this frame (if they moved it at all),
-- else standing straight
local function released(joint: Joint): CFrame
	local ok, value = pcall(function()
		return (joint.Instance :: any).Transform
	end)
	local written = joint.Written
	if ok and typeof(value) == "CFrame" and written and not value:FuzzyEq(written, 1e-4) then
		return joint.Frame * value * joint.Frame:Inverse()
	end
	return CFrame.identity
end

local function readAll(run: Run): { [string]: CFrame }
	local pose: { [string]: CFrame } = {}
	for key, joint in run.Joints do
		pose[key] = read(joint) or CFrame.identity
	end
	return pose
end

local function goal(run: Run): { [string]: CFrame }
	local name = run.Name
	if not name then
		return {}
	end
	local pose = Rig.Pose(name, run.Clock)
	return if run.R6 then Rig.R6(pose) else pose
end

-- Your own animations: paused while a move plays (they'd keep putting your arms back down)
local function pauseAnimate(run: Run)
	if run.Paused then
		return
	end
	run.Paused = true
	local a = run.Character:FindFirstChild("Animate")
	if a and a:IsA("BaseScript") then
		run.Animate = a
		pcall(function()
			run.AnimateWas = a.Enabled
		end)
		pcall(function()
			a.Enabled = false
		end)
	end
	pcall(function()
		local humanoid = run.Character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in animator:GetPlayingAnimationTracks() do
				if track ~= run.Track then
					track:Stop(0.15)
				end
			end
		end
	end)
end

local function restoreAnimate(run: Run)
	if not run.Paused then
		return
	end
	run.Paused = false
	local a = run.Animate
	run.Animate = nil
	if a then
		pcall(function()
			a.Enabled = run.AnimateWas
		end)
	end
end

local function finish(run: Run)
	for _, c in run.Connections do
		c:Disconnect()
	end
	table.clear(run.Connections)
	restoreAnimate(run)
	if runs[run.Character] == run then
		runs[run.Character] = nil
	end
end

-- A move's published animation (Config.PlayerAnimations), loaded once
local function trackFor(run: Run, name: string): AnimationTrack?
	local cached = run.Tracks[name]
	if cached then
		return cached
	end
	local ids = Config.PlayerAnimations[if run.R6 then "R6" else "R15"]
	local id = ids and ids[name]
	if not id or id == "" then
		return nil
	end
	if not string.find(id, "^rbxassetid://") then
		id = "rbxassetid://" .. id
	end
	local ok, track = pcall(function(): AnimationTrack?
		local humanoid = run.Character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			return nil
		end
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local t = animator:LoadAnimation(animation)
		t.Priority = Enum.AnimationPriority.Action4
		t.Looped = Rig.Loops(name)
		return t
	end)
	if ok and track then
		run.Tracks[name] = track
		return track
	end
	return nil
end

local function begin(run: Run, name: string, fade: number, clock: number?)
	local old = run.Track
	-- (blend from the pose your body is in: ours if we've been posing it, else what it's doing now)
	run.From = if old == nil and next(run.Last) ~= nil then table.clone(run.Last) else readAll(run)
	run.Name, run.Clock, run.Fade, run.Fading, run.Releasing = name, clock or 0, fade, 0, false
	pauseAnimate(run)
	local track = trackFor(run, name)
	if old and old ~= track then
		pcall(function()
			old:Stop(fade)
		end)
	end
	run.Track = track
	if track then
		pcall(function()
			track:Play(fade)
			track:AdjustSpeed(1)
		end)
	end
end

local function release(run: Run, fade: number)
	run.Name, run.Then = nil, nil
	local track = run.Track
	run.Track = nil
	if track then
		pcall(function()
			track:Stop(fade)
		end)
		-- (a published animation fades out by itself)
		finish(run)
		return
	end
	run.From = table.clone(run.Last)
	run.Fade, run.Fading, run.Releasing = fade, 0, true
	restoreAnimate(run)
end

local function step(run: Run, dt: number)
	run.Clock += dt
	run.Fading += dt
	local name = run.Name
	if name and run.Then and not Rig.Loops(name) and run.Clock >= Rig.Length(name) then
		local nextMove = run.Then :: string
		run.Then = nil
		if nextMove == "Release" then
			release(run, 0.3)
		else
			begin(run, nextMove, 0.12, run.Clock - Rig.Length(name))
		end
		if runs[run.Character] ~= run then
			return
		end
	end
	local track = run.Track
	if track then
		-- a published one: hold the last pose of a move that doesn't loop
		local playing = run.Name
		if playing and not Rig.Loops(playing) then
			pcall(function()
				if track.Length > 0 and track.TimePosition >= track.Length - 0.12 then
					track:AdjustSpeed(0)
				end
			end)
		end
		return
	end
	local want = if run.Releasing then nil else goal(run)
	local k = if run.Fade > 0 then smooth(run.Fading / run.Fade) else 1
	for key, joint in run.Joints do
		local target = if want then want[key] or CFrame.identity else released(joint)
		local body = (run.From[key] or CFrame.identity):Lerp(target, k)
		run.Last[key] = body
		write(joint, body)
	end
	if run.Releasing and k >= 1 then
		finish(run)
	end
end

function PlayerAnims.Play(character: Model, name: string, opts: { Fade: number?, Then: string? }?): boolean
	if not Rig.Has(name) then
		return false
	end
	local run = runs[character]
	if run and run.Name == name and not run.Releasing then
		run.Then = if opts then opts.Then else nil
		return true
	end
	if not run then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local r6 = if humanoid then humanoid.RigType == Enum.HumanoidRigType.R6 else character:FindFirstChild("Torso") ~= nil
		local joints = findJoints(character, r6)
		if next(joints) == nil then
			return false
		end
		local newRun: Run = {
			Character = character,
			R6 = r6,
			Joints = joints,
			Name = nil,
			Clock = 0,
			Then = nil,
			From = {},
			Last = {},
			Fade = 0,
			Fading = 0,
			Releasing = false,
			Paused = false,
			Animate = nil,
			AnimateWas = true,
			Track = nil,
			Tracks = {},
			Connections = {},
		}
		run = newRun
		runs[character] = newRun
		-- (after your animations have been worked out each frame, so ours win)
		table.insert(newRun.Connections, RunService.Stepped:Connect(function(_, dt: number)
			step(newRun, dt)
		end))
		table.insert(newRun.Connections, character.AncestryChanged:Connect(function()
			if not character:IsDescendantOf(game) then
				finish(newRun)
			end
		end))
	end
	local r = run :: Run
	begin(r, name, if opts and opts.Fade then opts.Fade else 0.2)
	r.Then = if opts then opts.Then else nil
	return true
end

function PlayerAnims.Stop(character: Model, fade: number?)
	local run = runs[character]
	if not run then
		return
	end
	local seconds = fade or 0.25
	if seconds <= 0 then
		-- right now: standing straight, your own animations take it from the next frame
		local track = run.Track
		run.Track = nil
		if track then
			pcall(function()
				track:Stop(0)
			end)
		else
			for _, joint in run.Joints do
				write(joint, CFrame.identity)
			end
		end
		finish(run)
		return
	end
	if not run.Releasing then
		release(run, seconds)
	end
end

function PlayerAnims.Current(character: Model): string?
	local run = runs[character]
	return if run and not run.Releasing then run.Name else nil
end

return PlayerAnims
