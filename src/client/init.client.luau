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
local Effects = require(script.Effects)
local Treadmill = require(script.Treadmill)

Notifications.Init()
Shop.Init()
Index.Init()
Leaderboards.Init()
Chase.Init()
HUD.Init({
	OpenShop = Shop.Open,
	OpenIndex = Index.Open,
	OpenLeaderboards = Leaderboards.Open,
})
Effects.Init()
Treadmill.Init()

-- Tell the server the UI is listening (it then sends the welcome-back popup, etc.)
require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes")).Event("ClientReady"):FireServer()
