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
local PetsWindow = require(UI.PetsWindow)
local Donate = require(UI.Donate)
local Admin = require(UI.Admin)
local CrateOpen = require(UI.CrateOpen)
local Tutorial = require(UI.Tutorial)
local EventBanner = require(UI.EventBanner)
local Effects = require(script.Effects)
local Treadmill = require(script.Treadmill)
local Guards = require(script.Guards)
local Weather = require(script.Weather)
local DonutIdle = require(script.DonutIdle)
local DonutFX = require(script.DonutFX)
local Followers = require(script.Followers)
local PetFX = require(script.PetFX)
local Flight = require(script.Flight)
local ChatTags = require(script.ChatTags)

Notifications.Init()
Shop.Init()
Index.Init()
Leaderboards.Init()
Chase.Init()
Settings.Init()
Rebirth.Init()
Worlds.Init()
PetsWindow.Init()
Donate.Init()
Admin.Init()
CrateOpen.Init()
Tutorial.Init()
EventBanner.Init()
ChatTags.Init()
HUD.Init({
	OpenShop = Shop.Open,
	OpenIndex = Index.Open,
	OpenSettings = Settings.Open,
	OpenRebirth = Rebirth.Open,
	OpenWorlds = Worlds.Open,
	OpenPets = PetsWindow.Open,
	OpenDonate = Donate.Open,
	OpenAdmin = Admin.Open,
	UnclaimedIndex = Index.UnclaimedCount,
	RebirthReady = Rebirth.IsReady,
	ReadyEggs = PetsWindow.ReadyEggs,
})
Effects.Init()
DonutFX.Init() -- right after Effects, so it sees every donut in its resting spot
Treadmill.Init()
Guards.Init()
Weather.Init()
DonutIdle.Init()
Followers.Init()
PetFX.Init()
Flight.Init()

-- Tell the server the UI is listening (it then sends the welcome-back popup, etc.)
require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes")).Event("ClientReady"):FireServer()
