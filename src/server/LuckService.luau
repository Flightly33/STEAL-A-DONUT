--[[
	LuckService
	===========
	The Luck Event (a developer product, Config.LuckEvent): for 10 minutes every donut that spawns in
	this server is better - rare donuts show up more often, mutations are more likely, sizes run
	bigger, and eggs appear more often. Buying it again while it runs adds another 10 minutes.
	Everyone in the server sees a banner and a countdown (workspace attribute "LuckEndsAt").
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Areas = require(Shared.Areas)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local DonutSpawnService = require(script.Parent.DonutSpawnService)
local PetService = require(script.Parent.PetService)

local LuckService = {}

local cfg = Config.LuckEvent
local endsAt = 0 -- os.clock()
local token = 0

local function stop()
	endsAt = 0
	DonutSpawnService.SetServerLuck(nil)
	PetService.SetEggLuck(1)
	workspace:SetAttribute("LuckEndsAt", nil)
	workspace:SetAttribute("LuckBy", nil)
	for _, player in Players:GetPlayers() do
		Remotes.Event("Notify"):FireClient(player, "🍀 The Luck Event is over.", "event")
	end
end

function LuckService.IsActive(): boolean
	return endsAt > os.clock()
end

-- Start (or extend) the Luck Event. `by` is who paid for it (shown in the banner).
function LuckService.Start(by: Player?, seconds: number?)
	local duration = seconds or cfg.Duration
	local now = os.clock()
	local wasActive = endsAt > now
	endsAt = math.max(endsAt, now) + duration
	token += 1
	local myToken = token
	DonutSpawnService.SetServerLuck({ Rarity = cfg.RarityLuck, Mutation = cfg.MutationLuck, Size = cfg.BigSizeLuck })
	PetService.SetEggLuck(2)
	workspace:SetAttribute("LuckEndsAt", workspace:GetServerTimeNow() + (endsAt - now))
	workspace:SetAttribute("LuckBy", if by then by.DisplayName else nil)
	local who = if by then by.DisplayName else "Someone"
	local text = if wasActive
		then `🍀 {who} added {Format.Duration(duration)} to the LUCK EVENT! ({Format.Duration(endsAt - now)} left)`
		else `🍀 {who} started a LUCK EVENT! Rarer donuts, more mutations and bigger sizes for {Format.Duration(duration)}!`
	Remotes.Event("AreaAnnouncement"):FireAllClients(text, Color3.fromRGB(90, 255, 120))
	if not wasActive then
		-- Re-roll the lane right away so everyone sees the luck kick in
		for _, area in Areas.List do
			DonutSpawnService.RerollArea(area.Id)
		end
	end
	task.delay(endsAt - now, function()
		if token == myToken then
			stop()
		end
	end)
end

return LuckService
