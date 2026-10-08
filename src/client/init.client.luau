--[[
	Steal a Donut - client entry point.
]]

local UI = script:WaitForChild("UI")

local Theme = require(UI.Theme)
Theme.WireClickSounds(Theme.PlayerGui()) -- every button clicks like a soft keyboard key

local Notifications = require(UI.Notifications)
local HUD = require(UI.HUD)
local Shop = require(UI.Shop)
local Index = require(UI.Index)
local Leaderboards = require(UI.Leaderboards)
local Chase = require(UI.Chase)
local Settings = require(UI.Settings)
local Trails = require(UI.Trails)
local Teleport = require(UI.Teleport)
local Sell = require(UI.Sell)
local BaseSize = require(UI.BaseSize)
local PetsWindow = require(UI.PetsWindow)
local Donate = require(UI.Donate)
local SkipOdds = require(UI.SkipOdds)
local Admin = require(UI.Admin)
local CrateOpen = require(UI.CrateOpen)
local Tutorial = require(UI.Tutorial)
local UpdateNotes = require(UI.UpdateNotes)
local PassOffer = require(UI.PassOffer)
local EventBanner = require(UI.EventBanner)
local HideUI = require(UI.HideUI)
local CosmicForge = require(UI.CosmicForge)
local Effects = require(script.Effects)
local BlackHoleFX = require(script.BlackHoleFX)
local Treadmill = require(script.Treadmill)
local Guards = require(script.Guards)
local Weather = require(script.Weather)
local StormFX = require(script.StormFX)
local BiomeAmbience = require(script.BiomeAmbience)
local MeteorFX = require(script.MeteorFX)
local GiantFX = require(script.GiantFX)
local DonutIdle = require(script.DonutIdle)
local DonutFX = require(script.DonutFX)
local DonutGlow = require(script.DonutGlow)
local Conveyors = require(script.Conveyors)
local Followers = require(script.Followers)
local Carried = require(script.Carried)
local TrailFX = require(script.TrailFX)
local BoxFX = require(script.BoxFX)
local PetFX = require(script.PetFX)
local Flight = require(script.Flight)
local ChatTags = require(script.ChatTags)
local Culling = require(script.Culling)
local ParticleBudget = require(script.ParticleBudget)

Notifications.Init()
Shop.Init()
Index.Init()
Leaderboards.Init()
Chase.Init()
Settings.Init()
Trails.Init()
Teleport.Init()
Sell.Init()
BaseSize.Init()
PetsWindow.Init()
Donate.Init()
SkipOdds.Init()
Admin.Init()
CrateOpen.Init()
Tutorial.Init()
UpdateNotes.Init()
PassOffer.Init()
EventBanner.Init()
ChatTags.Init()
HideUI.Init()
CosmicForge.Init()
HUD.Init({
	OpenShop = Shop.Open,
	OpenIndex = Index.Open,
	OpenSettings = Settings.Open,
	OpenTrails = Trails.Open,
	OpenTeleport = Teleport.Open,
	OpenBaseSize = BaseSize.Open,
	OpenPets = PetsWindow.Open,
	OpenDonate = Donate.Open,
	OpenUpdates = function()
		UpdateNotes.Open()
	end,
	OpenAdmin = Admin.Open,
	HideUI = HideUI.Toggle,
	UnclaimedIndex = Index.UnclaimedCount,
	TrailReady = Trails.IsReady,
	ReadyEggs = PetsWindow.ReadyEggs,
})
Effects.Init()
DonutFX.Init() -- right after Effects, so it sees every donut in its resting spot
DonutGlow.Init()
Conveyors.Init()
BlackHoleFX.Init()
Treadmill.Init()
Guards.Init()
Weather.Init()
StormFX.Init(Settings.SetStorm)
BiomeAmbience.Init()
MeteorFX.Init()
GiantFX.Init()
DonutIdle.Init()
Followers.Init()
Carried.Init()
TrailFX.Init()
BoxFX.Init()
PetFX.Init()
Flight.Init()
ParticleBudget.Init()
Culling.Init() -- last: everything else has seen the whole map first

-- Tell the server the UI is listening (it then sends the welcome-back popup, etc.)
require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes")).Event("ClientReady"):FireServer()
