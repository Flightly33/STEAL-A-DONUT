--[[
	TrailFX: draws every player's trail (their "Trail" attribute, see shared/Trails) on this screen.

	Fast Guy, while its wearer runs faster than Trails.MinSpeed:
	  * afterimages: FRAME_RATE times a second a glowing blue-white copy of their body is left where
	    they are (Neon, so it shows up even in the brightest biomes), and every copy fades a little
	    every other frame after that, so the run looks like it's made of frozen frames
	  * a streak of light behind the torso
	  * every PANE_EVERY seconds a pane of glass with white edges is left behind them; a moment
	    later it shatters into shards that fly back and fall
	Only players near the camera get the effect. The copies are cloned once per character (one
	afterimage per frame until there are GHOSTS of them) and then reused: nothing is created while
	running. Everything here is client-side.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trails = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Trails"))

local TrailFX = {}

local VIEW_DISTANCE = 220
local FRAME_RATE = 24 -- afterimages a second (24 frames a second, like Naoya's technique)
local GHOSTS = 8 -- afterimages alive at once (a third of a second of them)
-- Transparency of an afterimage 1, 2, 3 ... frames old. It changes every other frame, so only
-- half the afterimages need their parts updated each frame.
local GHOST_FADE = { 0.15, 0.15, 0.32, 0.32, 0.5, 0.5, 0.7, 0.7 }
local MAX_GHOST_PARTS = 20 -- body parts + accessories copied per afterimage
local PANE_EVERY = 0.85
local PANE_HOLD = 0.12 -- seconds the pane stays whole before it shatters
local PANE_SIZE = Vector2.new(5, 7)
local SHARDS_PER_PANE = 10
local SHARD_LIFE = 0.8
local MAX_SHARDS = 60
local GRAVITY = 55
local GLASS_SOUND = "rbxasset://sounds/electronicpingshort.wav"
local IDLE_CLEANUP = 20

type Ghost = { Parts: { BasePart }, Age: number }
type Pane = { Model: Model, Glass: BasePart, Edges: { BasePart }, ShatterAt: number? }
type Runner = {
	Player: Player,
	Character: Model?,
	TrailId: string?,
	Sources: { BasePart },
	Ghosts: { Ghost },
	Next: number,
	Clock: number,
	PaneClock: number,
	Pane: Pane?,
	Streak: Trail?,
	Dirty: boolean,
	IdleFor: number, -- seconds without the effect (the copies are thrown away after IDLE_CLEANUP)
	Connections: { RBXScriptConnection },
}
type Shard = { Part: BasePart, Velocity: Vector3, Spin: Vector3, Born: number, Active: boolean }

local localPlayer = Players.LocalPlayer
local runners: { [Player]: Runner } = {}
local shards: { Shard } = {}
local folder: Folder
local clock = 0
local bulkMove = true -- (workspace:BulkMoveTo, if this client has it)
local rng = Random.new()
local glassSound: Sound? = nil

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local function moveParts(parts: { BasePart }, cframes: { CFrame })
	if bulkMove then
		local ok = pcall(function()
			workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end)
		bulkMove = ok
	end
	if not bulkMove then
		for i, part in parts do
			part.CFrame = cframes[i]
		end
	end
end

local function effectPart(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
end

local function newPart(className: string, name: string, size: Vector3, color: Color3, material: Enum.Material): BasePart
	local part = Instance.new(className) :: BasePart
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Transparency = 1
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	effectPart(part)
	return part
end

-- The body parts and accessories an afterimage copies (no tools, no root, nothing invisible).
local function sourcesOf(character: Model): { BasePart }
	local list = {}
	for _, item in character:GetDescendants() do
		if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" and item.Transparency < 0.95 and not item:FindFirstAncestorOfClass("Tool") then
			table.insert(list, item)
			if #list >= MAX_GHOST_PARTS then
				break
			end
		end
	end
	return list
end

-- A see-through copy of one body part: same shape (its mesh), no face, no textures.
local function ghostPart(source: BasePart, color: Color3): BasePart?
	local archivable = source.Archivable
	source.Archivable = true
	local copy = source:Clone()
	source.Archivable = archivable
	if not copy then
		return nil
	end
	for _, child in copy:GetChildren() do
		if not child:IsA("DataModelMesh") then
			child:Destroy()
		end
	end
	if copy:IsA("MeshPart") then
		pcall(function()
			copy.TextureID = ""
		end)
	end
	effectPart(copy)
	copy.Material = Enum.Material.Neon
	copy.Color = color
	copy.Reflectance = 0
	copy.Transparency = 1
	copy.Name = "Afterimage"
	copy.Parent = folder
	return copy
end

local function clearGhosts(runner: Runner)
	for _, ghost in runner.Ghosts do
		for _, part in ghost.Parts do
			part:Destroy()
		end
	end
	runner.Ghosts = {}
	runner.Next = 1
end

local function setGhostTransparency(ghost: Ghost, transparency: number)
	for _, part in ghost.Parts do
		part.Transparency = transparency
	end
end

--------------------------------------------------------------------------------
-- Glass panes and shards
--------------------------------------------------------------------------------
local function buildPane(trail: Trails.Trail): Pane
	local model = Instance.new("Model")
	model.Name = "GlassPane"
	local glass = newPart("Part", "Glass", Vector3.new(PANE_SIZE.X, PANE_SIZE.Y, 0.15), trail.Color, Enum.Material.Glass)
	glass.Reflectance = 0.25
	glass.Parent = model
	local edges = {}
	local edge = 0.18
	for i, def in {
		{ Vector3.new(PANE_SIZE.X + edge, edge, 0.2), Vector3.new(0, PANE_SIZE.Y / 2, 0) },
		{ Vector3.new(PANE_SIZE.X + edge, edge, 0.2), Vector3.new(0, -PANE_SIZE.Y / 2, 0) },
		{ Vector3.new(edge, PANE_SIZE.Y + edge, 0.2), Vector3.new(PANE_SIZE.X / 2, 0, 0) },
		{ Vector3.new(edge, PANE_SIZE.Y + edge, 0.2), Vector3.new(-PANE_SIZE.X / 2, 0, 0) },
	} do
		local part = newPart("Part", "Edge" .. i, def[1], trail.Accent, Enum.Material.Neon)
		part:SetAttribute("Offset", def[2])
		part.Parent = model
		table.insert(edges, part)
	end
	model.Parent = folder
	return { Model = model, Glass = glass, Edges = edges, ShatterAt = nil }
end

local function showPane(pane: Pane, cf: CFrame)
	local parts, cframes = { pane.Glass }, { cf }
	for _, edge in pane.Edges do
		table.insert(parts, edge)
		table.insert(cframes, cf * CFrame.new(edge:GetAttribute("Offset") :: Vector3))
	end
	moveParts(parts, cframes)
	pane.Glass.Transparency = 0.55
	for _, edge in pane.Edges do
		edge.Transparency = 0.05
	end
	pane.ShatterAt = clock + PANE_HOLD
end

local function freeShard(color: Color3): Shard?
	for _, shard in shards do
		if not shard.Active then
			shard.Part.Color = color
			return shard
		end
	end
	if #shards >= MAX_SHARDS then
		return nil
	end
	local part = newPart("WedgePart", "Shard", Vector3.new(0.08, 1, 1), color, Enum.Material.Glass)
	part.Reflectance = 0.3
	part.Parent = folder
	local shard = { Part = part, Velocity = Vector3.zero, Spin = Vector3.zero, Born = 0, Active = false }
	table.insert(shards, shard)
	return shard
end

local function playGlass(runner: Runner)
	if runner.Player ~= localPlayer then
		return -- only your own trail makes a sound
	end
	if not glassSound then
		local sound = Instance.new("Sound")
		sound.Name = "TrailGlass"
		sound.SoundId = GLASS_SOUND
		sound.Volume = 0.08
		sound.Parent = SoundService
		glassSound = sound
	end
	local sound = glassSound :: Sound
	sound.PlaybackSpeed = 2.4 + rng:NextNumber() * 0.5
	SoundService:PlayLocalSound(sound)
end

local function shatter(runner: Runner, pane: Pane, trail: Trails.Trail)
	pane.ShatterAt = nil
	local cf = pane.Glass.CFrame
	pane.Glass.Transparency = 1
	for _, edge in pane.Edges do
		edge.Transparency = 1
	end
	local parts, cframes = {}, {}
	for _ = 1, SHARDS_PER_PANE do
		local shard = freeShard(trail.Color:Lerp(trail.Accent, rng:NextNumber() * 0.5))
		if not shard then
			break
		end
		local x = rng:NextNumber(-0.5, 0.5) * PANE_SIZE.X
		local y = rng:NextNumber(-0.5, 0.5) * PANE_SIZE.Y
		local size = Vector3.new(0.08, rng:NextNumber(0.6, 1.8), rng:NextNumber(0.5, 1.5))
		shard.Part.Size = size
		shard.Part.Transparency = 0.2
		-- away from the runner (backwards), outwards from the middle of the pane, and a little up
		shard.Velocity = -cf.LookVector * rng:NextNumber(6, 16) + cf.RightVector * x * rng:NextNumber(1.5, 4) + cf.UpVector * (y * 1.2 + rng:NextNumber(2, 7))
		shard.Spin = Vector3.new(rng:NextNumber(-9, 9), rng:NextNumber(-9, 9), rng:NextNumber(-9, 9))
		shard.Born = clock
		shard.Active = true
		table.insert(parts, shard.Part)
		table.insert(cframes, cf * CFrame.new(x, y, 0) * CFrame.Angles(0, math.pi / 2, rng:NextNumber(0, math.pi * 2)))
	end
	moveParts(parts, cframes)
	playGlass(runner)
end

local function updateShards(dt: number)
	local parts, cframes = {}, {}
	for _, shard in shards do
		if shard.Active then
			local age = clock - shard.Born
			if age >= SHARD_LIFE then
				shard.Active = false
				shard.Part.Transparency = 1
			else
				shard.Velocity -= Vector3.new(0, GRAVITY * dt, 0)
				local spin = shard.Spin * dt
				table.insert(parts, shard.Part)
				table.insert(cframes, (shard.Part.CFrame + shard.Velocity * dt) * CFrame.Angles(spin.X, spin.Y, spin.Z))
				shard.Part.Transparency = 0.2 + 0.8 * (age / SHARD_LIFE) ^ 2
			end
		end
	end
	if #parts > 0 then
		moveParts(parts, cframes)
	end
end

--------------------------------------------------------------------------------
-- Runners
--------------------------------------------------------------------------------
local function streakFor(runner: Runner, character: Model, trail: Trails.Trail): Trail?
	local existing = runner.Streak
	if existing and existing.Parent then
		return existing
	end
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	if not torso then
		return nil
	end
	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, torso.Size.Y * 0.45, 0)
	top.Parent = torso
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -torso.Size.Y * 0.9, 0)
	bottom.Parent = torso
	local streak = Instance.new("Trail")
	streak.Name = "FastTrail"
	streak.Attachment0 = top
	streak.Attachment1 = bottom
	streak.Color = ColorSequence.new(trail.Accent, trail.Color)
	streak.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	streak.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.3) })
	streak.Lifetime = 0.32
	streak.LightEmission = 1
	streak.FaceCamera = true
	streak.Enabled = false
	streak.Parent = torso
	runner.Streak = streak
	return streak
end

local function reset(runner: Runner)
	clearGhosts(runner)
	if runner.Pane then
		runner.Pane.Model:Destroy()
		runner.Pane = nil
	end
	if runner.Streak then
		runner.Streak:Destroy()
		runner.Streak = nil
	end
	for _, connection in runner.Connections do
		connection:Disconnect()
	end
	runner.Connections = {}
	runner.Sources = {}
	runner.Character = nil
	runner.TrailId = nil
end

local function adopt(runner: Runner, character: Model, trail: Trails.Trail)
	reset(runner)
	runner.Character = character
	runner.TrailId = trail.Id
	runner.Sources = sourcesOf(character)
	-- an accessory that loads late (or is taken off) means new copies are needed
	local function dirty(item: Instance)
		if item:IsA("Accessory") or item:IsA("BasePart") then
			runner.Dirty = true
		end
	end
	table.insert(runner.Connections, character.ChildAdded:Connect(dirty))
	table.insert(runner.Connections, character.ChildRemoved:Connect(dirty))
end

-- Leave an afterimage where the runner is now (building it the first time it's needed).
local function snapshot(runner: Runner, trail: Trails.Trail)
	if runner.Dirty then
		runner.Dirty = false
		clearGhosts(runner)
		if runner.Character then
			runner.Sources = sourcesOf(runner.Character)
		end
	end
	local index = runner.Next
	runner.Next = index % GHOSTS + 1
	local ghost = runner.Ghosts[index]
	if not ghost then
		local parts = {}
		for _, source in runner.Sources do
			local copy = ghostPart(source, trail.Color)
			if copy then
				table.insert(parts, copy)
			end
		end
		ghost = { Parts = parts, Age = 0 }
		runner.Ghosts[index] = ghost
	end
	local cframes = {}
	for i, part in ghost.Parts do
		local source = runner.Sources[i]
		cframes[i] = if source and source.Parent then source.CFrame else part.CFrame
	end
	moveParts(ghost.Parts, cframes)
	ghost.Age = 1
	setGhostTransparency(ghost, GHOST_FADE[1])
end

-- One frame later: every afterimage fades a step; the oldest disappear.
local function ageGhosts(runner: Runner)
	for _, ghost in runner.Ghosts do
		if ghost.Age <= GHOSTS then
			ghost.Age += 1
			local fade = GHOST_FADE[ghost.Age] or 1
			if fade ~= GHOST_FADE[ghost.Age - 1] then
				setGhostTransparency(ghost, fade)
			end
		end
	end
end

local function update(dt: number)
	clock += dt
	local camera = workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	local step = 1 / FRAME_RATE
	for player, runner in runners do
		local character = player.Character
		local trail = Trails.ById[player:GetAttribute("Trail") :: any]
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local active = false
		if trail and character and root then
			if runner.Character ~= character or runner.TrailId ~= trail.Id then
				adopt(runner, character, trail)
			end
			local velocity = root.AssemblyLinearVelocity
			local speed = Vector2.new(velocity.X, velocity.Z).Magnitude
			active = speed >= Trails.MinSpeed and (root.Position - eye).Magnitude <= VIEW_DISTANCE
		elseif runner.Character then
			-- no trail (taken off) or no character: let the afterimages fade, then tidy up
			local fading = false
			for _, ghost in runner.Ghosts do
				fading = fading or ghost.Age <= GHOSTS
			end
			if not fading and not (runner.Pane and runner.Pane.ShatterAt) then
				reset(runner)
			end
		end

		runner.Clock += dt
		if runner.Clock >= step then
			runner.Clock = math.min(runner.Clock - step, step)
			ageGhosts(runner)
			if active and trail then
				snapshot(runner, trail)
			end
		end

		if character and trail then
			local streak = streakFor(runner, character, trail)
			if streak then
				streak.Enabled = active
			end
		end

		local pane = runner.Pane
		if pane and pane.ShatterAt and clock >= pane.ShatterAt and trail then
			shatter(runner, pane, trail)
		end
		if active then
			runner.IdleFor = 0
		else
			runner.IdleFor += dt
			if runner.IdleFor >= IDLE_CLEANUP and #runner.Ghosts > 0 then
				clearGhosts(runner) -- (built again the next time they run)
			end
		end
		if active and trail and root then
			runner.PaneClock += dt
			if runner.PaneClock >= PANE_EVERY and not (pane and pane.ShatterAt) then
				runner.PaneClock = 0
				local newPane = pane or buildPane(trail)
				runner.Pane = newPane
				local flat = root.CFrame.LookVector * Vector3.new(1, 0, 1)
				local forward = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
				local at = root.Position - forward * 3 + Vector3.new(0, 0.6, 0)
				showPane(newPane, CFrame.lookAt(at, at + forward) * CFrame.Angles(0, 0, rng:NextNumber(-0.12, 0.12)))
			end
		else
			runner.PaneClock = math.min(runner.PaneClock, PANE_EVERY * 0.6)
		end
	end
	updateShards(dt)
end

local function track(player: Player)
	if runners[player] then
		return
	end
	runners[player] = {
		Player = player,
		Character = nil,
		TrailId = nil,
		Sources = {},
		Ghosts = {},
		Next = 1,
		Clock = 0,
		PaneClock = PANE_EVERY * 0.5,
		Pane = nil,
		Streak = nil,
		Dirty = false,
		IdleFor = 0,
		Connections = {},
	}
end

function TrailFX.Init()
	folder = Instance.new("Folder")
	folder.Name = "TrailFX"
	folder.Parent = workspace
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(function(player)
		local runner = runners[player]
		if runner then
			reset(runner)
			runners[player] = nil
		end
	end)
	RunService.Heartbeat:Connect(update)
end

return TrailFX
