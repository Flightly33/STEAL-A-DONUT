--[[
	GiantService: Cosmic Domer (shared/Giant). After the Cosmic Meteor has crashed into the lane
	(MeteorService), at 2:15 into the Eternal Storm (Config.CosmicGiant.AppearAt: EventService
	starts him) a black hole tears open over the lane just past the crater and a colossal Domer
	climbs out of it - for the rest of the storm. Every Config.CosmicGiant.SlamEvery
	seconds he attacks, working through Config.CosmicGiant.Pattern:
	  Slam   he slowly smashes a fist into the lane near the crater: anyone within KnockRadius of it
	         is knocked flying and drops whatever they're carrying (ItemService.Fling)
	  Stars  he pulls a handful of stars out of the black hole and throws them down round the crater
	         (StarRain.Radius round each one knocks you flying)
	  Beam   his eyes charge up, then twin beams sweep across the lane (Beam.Radius either side of
	         their path knocks you flying)
	Every attack is telegraphed on the ground first. When the storm ends (EventService) he sinks
	back into the hole.

	Here: where and when. The clients draw all of it (client/GiantFX), from three workspace
	attributes (GiantSite, GiantSince, GiantLeaveAt) and the "GiantSlam", "GiantStarRain" and
	"GiantBeam" remotes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Giant = require(Shared.Giant)
local Layout = require(Shared.Layout)
local Remotes = require(Shared.Remotes)

local ItemService = require(script.Parent.ItemService)

local GiantService = {}

local GIANT = Config.CosmicGiant
local LEAD = 0.3 -- seconds between telling the clients about a slam and it starting

local rng = Random.new()
local token = 0
local activeSite: Vector3? = nil

-- Somewhere near the crater for the next fist (in the lane, never in the lobby).
local function pickTarget(site: Vector3, lastHand: string?): Vector3
	for _ = 1, 8 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(GIANT.Reach[1], GIANT.Reach[2])
		local target = site + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local area = Layout.AreaAt(target)
		if area > 0 then
			local half = Layout.AreaHalfWidth(area) - 10
			target = Vector3.new(math.clamp(target.X, -half, half), 0, math.max(target.Z, Config.Map.SafeZoneZ + GIANT.KnockRadius + 10))
			-- (he takes turns with his hands, and only hits where his fist reaches the ground)
			if Giant.CanReach(site, target) and (Giant.HandFor(site, target) ~= lastHand or rng:NextNumber() < 0.25) then
				return target
			end
		end
	end
	return Vector3.new(site.X, 0, math.max(site.Z, Config.Map.SafeZoneZ + GIANT.KnockRadius + 10))
end

-- In the lane (clamped inside `inset` of the walls), and out of the lobby by `keepOut`.
local function inLane(at: Vector3, inset: number, keepOut: number): Vector3?
	local area = Layout.AreaAt(at)
	if area == 0 then
		return nil
	end
	local half = Layout.AreaHalfWidth(area) - inset
	return Vector3.new(math.clamp(at.X, -half, half), 0, math.max(at.Z, Config.Map.SafeZoneZ + keepOut))
end

-- Everyone within `radius` (across the ground) of `at` is knocked flying (and drops what they carry).
local function knock(at: Vector3, radius: number, skip: { [Player]: boolean }?): { Player }
	local hit = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and not (skip and skip[player]) then
			local offset = root.Position - at
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius and offset.Y < 35 then
				ItemService.Fling(player, at, GIANT.FlingPower)
				table.insert(hit, player)
			end
		end
	end
	return hit
end

-- The fist lands.
local function impact(target: Vector3): { Player }
	return knock(target, GIANT.KnockRadius)
end

-- One slam (returns the target).
function GiantService.Slam(target: Vector3?): Vector3?
	local site = activeSite
	if not site then
		return nil
	end
	local myToken = token
	local at = target or pickTarget(site, nil)
	Remotes.Event("GiantSlam"):FireAllClients({ Hand = Giant.HandFor(site, at), Target = at, StartAt = workspace:GetServerTimeNow() + LEAD })
	task.delay(LEAD + Giant.IMPACT, function()
		if token == myToken then
			impact(at)
		end
	end)
	return at
end

-- Star rain: he pulls stars out of the black hole and throws them down round the crater
-- (returns where they'll land).
function GiantService.StarRain(): { Vector3 }?
	local site = activeSite
	if not site then
		return nil
	end
	local rain = GIANT.StarRain
	local targets: { Vector3 } = {}
	for _ = 1, rain.Count * 12 do
		if #targets >= rain.Count then
			break
		end
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = rng:NextNumber(rain.Spread[1], rain.Spread[2])
		local target = inLane(site + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance), 8, rain.Radius + 10)
		if target then
			local apart = true
			for _, other in targets do
				if (other - target).Magnitude < 18 then
					apart = false
					break
				end
			end
			if apart then
				table.insert(targets, target)
			end
		end
	end
	if #targets == 0 then
		return nil
	end
	local myToken = token
	Remotes.Event("GiantStarRain"):FireAllClients({ Targets = targets, StartAt = workspace:GetServerTimeNow() + LEAD })
	for i, target in targets do
		task.delay(LEAD + Giant.StarLanding(i, #targets), function()
			if token == myToken then
				knock(target, rain.Radius)
			end
		end)
	end
	return targets
end

-- Distance from `p` to the segment a-b (across the ground).
local function toSegment(p: Vector3, a: Vector3, b: Vector3): number
	local flat = Vector3.new(1, 0, 1)
	p, a, b = p * flat, a * flat, b * flat
	local ab = b - a
	local along = if ab.Magnitude > 1e-3 then math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1) else 0
	return (p - (a + ab * along)).Magnitude
end

-- Eye beam: his eyes charge up, then twin beams sweep from `from` to `to` across the lane
-- (anyone they pass over is knocked flying, once). Returns the line.
function GiantService.Beam(from: Vector3?, to: Vector3?): (Vector3?, Vector3?)
	local site = activeSite
	if not site then
		return nil, nil
	end
	local radius = GIANT.Beam.Radius
	if not (from and to) then
		local area = Layout.AreaAt(site)
		local half = (if area > 0 then Layout.AreaHalfWidth(area) else Config.Map.LaneHalfWidth) - 12
		local z = math.max(site.Z + rng:NextNumber(-70, 30), Config.Map.SafeZoneZ + radius + 35)
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		from = inLane(Vector3.new(side * half, 0, z + rng:NextNumber(-25, 25)), 12, radius + 10)
		to = inLane(Vector3.new(-side * half, 0, z + rng:NextNumber(-25, 25)), 12, radius + 10)
	end
	if not (from and to) then
		return nil, nil
	end
	local a, b = from :: Vector3, to :: Vector3
	local myToken = token
	Remotes.Event("GiantBeam"):FireAllClients({ From = a, To = b, StartAt = workspace:GetServerTimeNow() + LEAD })
	task.spawn(function()
		task.wait(LEAD + Giant.BEAM_CHARGE)
		local started = os.clock()
		local last = Giant.BeamPoint(a, b, 0)
		local hit: { [Player]: boolean } = {}
		while token == myToken do
			local t = math.min((os.clock() - started) / Giant.BEAM_SWEEP, 1)
			local point = Giant.BeamPoint(a, b, t)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and not hit[player] and toSegment(root.Position, last, point) <= radius and root.Position.Y - point.Y < 35 then
					hit[player] = true
					ItemService.Fling(player, point, GIANT.FlingPower)
				end
			end
			last = point
			if t >= 1 then
				break
			end
			task.wait(1 / 12)
		end
	end)
	return a, b
end

-- How long each attack keeps him busy (seconds).
local function lengthOf(attack: string): number
	if attack == "Stars" then
		return Giant.STAR_CHARGE + Giant.STAR_FALL + Giant.STAR_SPREAD + 1
	elseif attack == "Beam" then
		return Giant.BEAM_CHARGE + Giant.BEAM_SWEEP
	end
	return Giant.LENGTH
end

-- He climbs out of a black hole over the crater at `site` (only during the Eternal Storm).
function GiantService.Start(site: Vector3): boolean
	if not GIANT.Enabled or workspace:GetAttribute("EventId") ~= "EternalStorm" then
		return false
	end
	token += 1
	local myToken = token
	activeSite = site
	workspace:SetAttribute("GiantSite", site)
	workspace:SetAttribute("GiantSince", workspace:GetServerTimeNow())
	workspace:SetAttribute("GiantLeaveAt", nil)
	Remotes.Event("AreaAnnouncement"):FireAllClients("🌌 COSMIC DOMER IS CLIMBING OUT OF THE BLACK HOLE! WATCH OUT FOR HIS FISTS!", Giant.PINK)
	task.spawn(function()
		task.wait(Giant.OPEN + Giant.RISE)
		local lastHand: string? = nil
		local pattern = if #GIANT.Pattern > 0 then GIANT.Pattern else { "Slam" }
		local step = 0
		while token == myToken do
			step = step % #pattern + 1
			local attack = pattern[step]
			local done = false
			if attack == "Stars" then
				done = GiantService.StarRain() ~= nil
			elseif attack == "Beam" then
				done = GiantService.Beam() ~= nil
			end
			if not done then
				attack = "Slam"
				local target = pickTarget(site, lastHand)
				lastHand = Giant.HandFor(site, target)
				GiantService.Slam(target)
			end
			task.wait(math.max(GIANT.SlamEvery, lengthOf(attack) + 0.3))
		end
	end)
	return true
end

-- The storm's over: he sinks back into the hole, and it closes.
function GiantService.Stop()
	if not activeSite then
		return
	end
	token += 1
	local myToken = token
	activeSite = nil
	workspace:SetAttribute("GiantLeaveAt", workspace:GetServerTimeNow())
	task.delay(Giant.SINK + 2, function()
		if token == myToken then
			workspace:SetAttribute("GiantSite", nil)
			workspace:SetAttribute("GiantSince", nil)
			workspace:SetAttribute("GiantLeaveAt", nil)
		end
	end)
end

function GiantService.IsActive(): boolean
	return activeSite ~= nil
end

-- (tests)
GiantService.Impact = impact

return GiantService
