--[[
	Steal a Donut - server entry point.
	Builds the map, then starts every service in dependency order.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Creating the remotes first lets clients connect while the map is still building.
require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local MapBuilder = require(script.MapBuilder)
local DataService = require(script.DataService)
local PlotService = require(script.PlotService)
local TreadmillService = require(script.TreadmillService)
local DonutSpawnService = require(script.DonutSpawnService)
local GuardService = require(script.GuardService)
local StealService = require(script.StealService)
local ShopService = require(script.ShopService)
local LeaderboardService = require(script.LeaderboardService)
local PlayerService = require(script.PlayerService)
local RaidService = require(script.RaidService)
local WorldService = require(script.WorldService)
local EventService = require(script.EventService)
local StatsService = require(script.StatsService)
local ItemService = require(script.ItemService)
local PetService = require(script.PetService)
local ProductService = require(script.ProductService)
local AdminService = require(script.AdminService)

local started = os.clock()
MapBuilder.Build()
DataService.Init()
GuardService.Init() -- registers collision groups before any character spawns into them
PlotService.Init()
TreadmillService.Init()
StatsService.Init(DataService.DataStoresEnabled())
DonutSpawnService.Spawned:Connect(StatsService.RecordSpawn)
DonutSpawnService.Init()
StealService.Init()
RaidService.Init()
ItemService.Init()
WorldService.Init()
EventService.Init()
PetService.Init()
ShopService.Init()
ProductService.Init()
AdminService.Init()
LeaderboardService.Init()
PlayerService.Init()

print(string.format("[Steal a Donut] Server ready in %.2fs", os.clock() - started))
