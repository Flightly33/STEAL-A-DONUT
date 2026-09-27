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
