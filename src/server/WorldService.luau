--[[
	WorldService
	============
	* Speed gates: every biome needs a Speed to get in (Areas.luau). Clients make the invisible wall
	  at a too-fast biome's entrance solid for slow players (client/AreaTracker); this is the check
	  on the server. Anyone standing in a biome they're too slow for (lag, a rebirth, spending Speed
	  on a skin...) is put back just outside it - in the furthest biome they ARE fast enough for, not
	  all the way back in the lobby.
	* Teleporter game pass: jump to the start of any biome you're fast enough for, or home.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Layout = require(Shared.Layout)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local StealService = require(script.Parent.StealService)

local WorldService = {}

local lastTeleport: { [Player]: number } = {}
local lastWarning: { [Player]: number } = {}

local function notify(player: Player, text: string, kind: string?)
	Remotes.Event("Notify"):FireClient(player, text, kind or "info")
end

--------------------------------------------------------------------------------
-- Speed gates
--------------------------------------------------------------------------------
-- The furthest biome up to `areaId` that this Speed gets you into.
local function allowedArea(areaId: number, speed: number): number
	local allowed = areaId
	while allowed > 1 and not Economy.CanEnter(allowed, speed) do
		allowed -= 1
	end
	return allowed
end

-- Is anything letting this player ignore the gates (an admin flying or with "Domer can't catch me")?
local function exempt(player: Player, profile: DataService.Profile): boolean
	return profile.Session.GodMode or player:GetAttribute("Flying") == true
end

local function checkGates(player: Player, profile: DataService.Profile, root: BasePart)
	local position = root.Position
	local areaId = Layout.AreaAt(position)
	if areaId <= 1 or exempt(player, profile) then
		return
	end
	local speed = profile.Data.Speed
	if Economy.CanEnter(areaId, speed) then
		return
	end
	-- Back out to just before the first biome they're too slow for.
	local allowed = allowedArea(areaId, speed)
	local blocked = allowed + 1
	StealService.Teleport(player, Layout.GateBounce(blocked, position.X))
	root.AssemblyLinearVelocity = Vector3.zero
	local now = os.clock()
	if not lastWarning[player] or now - lastWarning[player] > 3 then
		lastWarning[player] = now
		local area = Areas.List[blocked]
		notify(player, `⚡ You need {Format.Number(area.RecommendedSpeed)} Speed to get into {area.Name}!`, "error")
		Remotes.Event("SpeedGate"):FireClient(player, blocked)
	end
end

--------------------------------------------------------------------------------
-- Teleporter game pass
--------------------------------------------------------------------------------
local function canTeleport(player: Player): boolean
	local profile = DataService.Get(player)
	if not profile then
		return false
	end
	if not profile.Passes.Teleporter then
		notify(player, "The Teleporter game pass lets you teleport to any biome you're fast enough for!", "error")
		return false
	end
	if StealService.IsCarrying(player) then
		notify(player, "You can't teleport while carrying something - run!", "error")
		return false
	end
	if profile.Session.Stunned then
		return false
	end
	local now = os.clock()
	if lastTeleport[player] and now - lastTeleport[player] < 2 then
		return false
	end
	lastTeleport[player] = now
	return true
end

function WorldService.TeleportToArea(player: Player, areaId: any)
	local profile = DataService.Get(player)
	if not profile or type(areaId) ~= "number" or not Areas.List[areaId] then
		return
	end
	if not Economy.CanEnter(areaId, profile.Data.Speed) then
		notify(player, `You need {Format.Number(Economy.RecommendedSpeed(areaId))} Speed for {Areas.List[areaId].Name}!`, "error")
		return
	end
	if canTeleport(player) then
		StealService.Teleport(player, Layout.AreaArrival(areaId))
	end
end

function WorldService.TeleportHome(player: Player)
	if canTeleport(player) then
		local spawnCf = PlotService.GetSpawnCFrame(player)
		if spawnCf then
			StealService.Teleport(player, spawnCf)
		end
	end
end

function WorldService.OnPlayerRemoving(player: Player)
	lastTeleport[player] = nil
	lastWarning[player] = nil
end

function WorldService.Init()
	task.spawn(function()
		while true do
			task.wait(0.2)
			for _, player in Players:GetPlayers() do
				local profile = DataService.Get(player)
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if profile and profile.Session.Ready and root then
					checkGates(player, profile, root)
				end
			end
		end
	end)
end

return WorldService
