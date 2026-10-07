--[[
	GiantService: Cosmic Domer (shared/Giant). Once the Cosmic Meteor has crashed into the lane
	(MeteorService), a black hole tears open over the lane just past the crater and a colossal
	Domer climbs out of it - for the rest of the Eternal Storm. Every Config.CosmicGiant.SlamEvery
	seconds he slowly smashes a fist into the lane near the crater: anyone within KnockRadius of it
	is knocked flying and drops whatever they're carrying (ItemService.Fling). When the storm ends
	(EventService) he sinks back into the hole.

	Here: where and when. The clients draw all of it (client/GiantFX), from three workspace
	attributes (GiantSite, GiantSince, GiantLeaveAt) and the "GiantSlam" remote.
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

-- The fist lands: everyone close is knocked flying (and drops what they carry).
local function impact(target: Vector3): { Player }
	local hit = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local offset = root.Position - target
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= GIANT.KnockRadius and offset.Y < 35 then
				ItemService.Fling(player, target, GIANT.FlingPower)
				table.insert(hit, player)
			end
		end
	end
	return hit
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
		while token == myToken do
			local target = pickTarget(site, lastHand)
			lastHand = Giant.HandFor(site, target)
			GiantService.Slam(target)
			task.wait(math.max(GIANT.SlamEvery, Giant.LENGTH + 0.3))
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
