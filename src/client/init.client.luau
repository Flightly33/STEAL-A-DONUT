--[[
	Steal a Donut - client entry point.
]]

local UI = script:WaitForChild("UI")

local Notifications = require(UI.Notifications)
local HUD = require(UI.HUD)
local Shop = require(UI.Shop)
local Index = require(UI.Index)
local Leaderboards = require(UI.Leaderboards)
local Chase = require(UI.Chase)
local Settings = require(UI.Settings)
local Rebirth = require(UI.Rebirth)
local Worlds = require(UI.Worlds)
local Effects = require(script.Effects)
local Treadmill = require(script.Treadmill)
local Guards = require(script.Guards)
local Weather = require(script.Weather)
local DonutIdle = require(script.DonutIdle)

Notifications.Init()
Shop.Init()
Index.Init()
Leaderboards.Init()
Chase.Init()
Settings.Init()
Rebirth.Init()
Worlds.Init()
HUD.Init({
	OpenShop = Shop.Open,
	OpenIndex = Index.Open,
	OpenLeaderboards = Leaderboards.Open,
	OpenSettings = Settings.Open,
	OpenRebirth = Rebirth.Open,
	OpenWorlds = Worlds.Open,
	UnclaimedIndex = Index.UnclaimedCount,
	RebirthReady = Rebirth.IsReady,
})
Effects.Init()
Treadmill.Init()
Guards.Init()
Weather.Init()
DonutIdle.Init()

-- Tell the server the UI is listening (it then sends the welcome-back popup, etc.)
require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes")).Event("ClientReady"):FireServer()
