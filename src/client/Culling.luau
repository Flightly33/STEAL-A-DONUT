--[[
	Culling: hides what's far away, on this player's screen only. Nothing moves out of its folder
	and nothing changes for anyone else; it's just not drawn.

	  * lane areas far ahead or behind: their decorations, donuts, crates, guard bed, arch and signs
	    (floors and walls always stay, so you can still see where the lane goes)
	  * bases further than a few plots away, in every world
	  * other worlds' scenery and portals, and the hub's stalls, boards and portals while you're
	    somewhere else

	Hidden parts get LocalTransparencyModifier = 1 (not drawn) and their lights, particles, beams,
	fire, smoke and signs are switched off; everything comes back as you get close (checked a few
	times a second). Anything that leaves a hidden folder (a donut someone carries off) is shown
	again straight away.
]]

local RunService = game:GetService("RunService")

local Culling = {}

-- Studs from the camera to the nearest edge of the area / base / world
local LANE_DISTANCE = 600
local PLOT_DISTANCE = 520
local WORLD_DISTANCE = 800
local MARGIN = 60 -- hide only this much further out than we show (no flicker at the edge)
local CHECK_EVERY = 0.35
-- Hiding or showing an area touches thousands of parts (every lane donut is ~100), so the work is
-- spread over a few frames instead of one big stutter while you run down the lane.
local BATCH = 1500 -- parts (and lights, emitters...) handled per frame

-- Parts of a lane area / world that always stay
local KEEP = {
	Floor = true,
	Wall = true,
	Walls = true,
	WallTop = true,
	AreaLine = true,
	SafeZoneLine = true,
	SafeZoneLabel = true,
	Bridge = true,
	Arrival = true,
	GatePillar = true,
	HubSpawn = true,
}

type Chunk = {
	Name: string,
	Containers: { Instance },
	Min: Vector3,
	Max: Vector3,
	Distance: number,
	Hidden: boolean,
	Saved: { [Instance]: number | boolean },
	Connections: { RBXScriptConnection },
}

local chunks: { Chunk } = {}

local function bounds(roots: { Instance }): (Vector3?, Vector3?)
	local min, max = nil, nil
	for _, root in roots do
		local list = root:GetDescendants()
		if root:IsA("BasePart") then
			table.insert(list, root)
		end
		for _, part in list do
			if part:IsA("BasePart") then
				local p = part.CFrame.Position
				local half = part.Size / 2
				local lo, hi = p - half, p + half
				min = if min then min:Min(lo) else lo
				max = if max then max:Max(hi) else hi
			end
		end
	end
	return min, max
end

local function addChunk(name: string, containers: { Instance }, boundsFrom: { Instance }, distance: number)
	if #containers == 0 then
		return
	end
	local min, max = bounds(boundsFrom)
	if not min or not max then
		return
	end
	table.insert(chunks, {
		Name = name,
		Containers = containers,
		Min = min,
		Max = max,
		Distance = distance,
		Hidden = false,
		Saved = {},
		Connections = {},
	})
end

-- LocalTransparencyModifier is set directly on parts and decals; only if this engine can't (the
-- offline test runner) does every access go through pcall.
local direct = pcall(function()
	local probe = Instance.new("Part")
	probe.LocalTransparencyModifier = probe.LocalTransparencyModifier
	probe:Destroy()
end)
local function getLocalTransparency(item: Instance): number
	if direct then
		return (item :: any).LocalTransparencyModifier
	end
	local ok, value = pcall(function()
		return (item :: any).LocalTransparencyModifier
	end)
	return if ok and type(value) == "number" then value else 0
end
local function setLocalTransparency(item: Instance, value: number)
	if direct then
		(item :: any).LocalTransparencyModifier = value
		return
	end
	pcall(function()
		(item :: any).LocalTransparencyModifier = value
	end)
end

local function hideOne(chunk: Chunk, item: Instance)
	if chunk.Saved[item] ~= nil then
		return
	end
	if item:IsA("BasePart") or item:IsA("Decal") then
		local current = getLocalTransparency(item)
		if current < 1 then
			chunk.Saved[item] = current
			setLocalTransparency(item, 1)
		end
	elseif item:IsA("Light") or item:IsA("ParticleEmitter") or item:IsA("Beam") or item:IsA("Trail") or item:IsA("Fire") or item:IsA("Smoke") or item:IsA("Sparkles") or item:IsA("LayerCollector") then
		if (item :: any).Enabled then
			chunk.Saved[item] = true;
			(item :: any).Enabled = false
		end
	end
end

local function restoreOne(chunk: Chunk, item: Instance)
	local saved = chunk.Saved[item]
	if saved == nil then
		return
	end
	chunk.Saved[item] = nil
	if type(saved) == "number" then
		setLocalTransparency(item, saved)
	else
		(item :: any).Enabled = true
	end
end

-- Unfinished hide / show work, a batch of items per frame (showing comes first)
type Job = { Chunk: Chunk, Hide: boolean, Items: { Instance }, Next: number }
local jobs: { Job } = {}

local function setHidden(chunk: Chunk, hidden: boolean)
	if chunk.Hidden == hidden then
		return
	end
	chunk.Hidden = hidden
	-- an unfinished job for this chunk was going the other way: drop it
	for i = #jobs, 1, -1 do
		if jobs[i].Chunk == chunk then
			table.remove(jobs, i)
		end
	end
	local items: { Instance } = {}
	if hidden then
		for _, container in chunk.Containers do
			table.insert(items, container)
			local descendants = container:GetDescendants()
			table.move(descendants, 1, #descendants, #items + 1, items)
			table.insert(chunk.Connections, container.DescendantAdded:Connect(function(item: Instance)
				hideOne(chunk, item)
			end))
			-- a donut carried out of a hidden area must show again wherever it goes
			table.insert(chunk.Connections, container.DescendantRemoving:Connect(function(item: Instance)
				restoreOne(chunk, item)
			end))
		end
		table.insert(jobs, { Chunk = chunk, Hide = true, Items = items, Next = 1 })
	else
		for _, connection in chunk.Connections do
			connection:Disconnect()
		end
		table.clear(chunk.Connections)
		for item in chunk.Saved do
			table.insert(items, item)
		end
		table.insert(jobs, 1, { Chunk = chunk, Hide = false, Items = items, Next = 1 })
	end
end

-- Do up to `budget` items of the queued hide / show work.
local function work(budget: number)
	while budget > 0 and #jobs > 0 do
		local job = jobs[1]
		local items, chunk = job.Items, job.Chunk
		local last = math.min(#items, job.Next + budget - 1)
		for i = job.Next, last do
			local item = items[i]
			if job.Hide then
				if item.Parent then
					hideOne(chunk, item)
				end
			else
				restoreOne(chunk, item)
			end
		end
		budget -= last - job.Next + 1
		job.Next = last + 1
		if job.Next > #items then
			table.remove(jobs, 1)
		end
	end
end

-- Distance from a point to the nearest point of a box.
local function distanceToBox(point: Vector3, min: Vector3, max: Vector3): number
	local nearest = point:Max(min):Min(max)
	return (point - nearest).Magnitude
end

local function collect(map: Instance)
	local lane = map:WaitForChild("Lane", 30)
	if lane then
		for _, area in lane:GetChildren() do
			local containers = {}
			for _, child in area:GetChildren() do
				if not KEEP[child.Name] then
					table.insert(containers, child)
				end
			end
			addChunk(area.Name, containers, { area }, LANE_DISTANCE)
		end
	end
	local function plotChunks(folder: Instance?)
		if folder then
			for _, plot in folder:GetChildren() do
				addChunk(plot.Name, { plot }, { plot }, PLOT_DISTANCE)
			end
		end
	end
	plotChunks(map:FindFirstChild("Plots"))
	local hub = map:FindFirstChild("Hub")
	if hub then
		local containers = {}
		for _, child in hub:GetChildren() do
			if not KEEP[child.Name] and child.Name ~= "Plots" then
				table.insert(containers, child)
			end
		end
		local floor = hub:FindFirstChild("Floor")
		addChunk("Hub", containers, { floor or hub }, WORLD_DISTANCE)
		plotChunks(hub:FindFirstChild("Plots"))
	end
	local worlds = map:FindFirstChild("Worlds")
	if worlds then
		for _, world in worlds:GetChildren() do
			local containers = {}
			for _, child in world:GetChildren() do
				if not KEEP[child.Name] and child.Name ~= "Plots" then
					table.insert(containers, child)
				end
			end
			local floor = world:FindFirstChild("Floor")
			addChunk(world.Name, containers, { floor or world }, WORLD_DISTANCE)
			plotChunks(world:FindFirstChild("Plots"))
		end
	end
end

local function update()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local point = camera.CFrame.Position
	for _, chunk in chunks do
		local distance = distanceToBox(point, chunk.Min, chunk.Max)
		if chunk.Hidden then
			if distance < chunk.Distance then
				setHidden(chunk, false)
			end
		elseif distance > chunk.Distance + MARGIN then
			setHidden(chunk, true)
		end
	end
end

-- Is this part / light / emitter hidden by culling right now?
function Culling.IsHidden(item: Instance): boolean
	for _, chunk in chunks do
		if chunk.Saved[item] ~= nil then
			return true
		end
	end
	return false
end

-- (for tests) how many chunks are hidden right now
function Culling.HiddenCount(): number
	local count = 0
	for _, chunk in chunks do
		if chunk.Hidden then
			count += 1
		end
	end
	return count
end

function Culling.Update()
	update()
	work(math.huge)
end

function Culling.Init()
	task.spawn(function()
		local map = workspace:WaitForChild("Map", 60)
		if not map then
			return
		end
		collect(map)
		update()
		local elapsed = 0
		RunService.Heartbeat:Connect(function(dt: number)
			elapsed += dt
			if elapsed >= CHECK_EVERY then
				elapsed = 0
				update()
			end
			if #jobs > 0 then
				work(BATCH)
			end
		end)
	end)
end

return Culling
