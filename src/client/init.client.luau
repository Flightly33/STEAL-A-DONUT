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
local Rebirth = require(UI.Rebirth)
local Worlds = require(UI.Worlds)
local PetsWindow = require(UI.PetsWindow)
local Donate = require(UI.Donate)
local Admin = require(UI.Admin)
local CrateOpen = require(UI.CrateOpen)
local Tutorial = require(UI.Tutorial)
local UpdateNotes = require(UI.UpdateNotes)
local PassOffer = require(UI.PassOffer)
local UltimateRebirth = require(UI.UltimateRebirth)
local EventBanner = require(UI.EventBanner)
local HideUI = require(UI.HideUI)
local Effects = require(script.Effects)
local BlackHoleFX = require(script.BlackHoleFX)
local UnderworldFX = require(script.UnderworldFX)
local Treadmill = require(script.Treadmill)
local Guards = require(script.Guards)
local Weather = require(script.Weather)
local DonutIdle = require(script.DonutIdle)
local DonutFX = require(script.DonutFX)
local Followers = require(script.Followers)
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
Rebirth.Init()
Worlds.Init()
PetsWindow.Init()
Donate.Init()
Admin.Init()
CrateOpen.Init()
Tutorial.Init()
UpdateNotes.Init()
PassOffer.Init()
UltimateRebirth.Init()
EventBanner.Init()
ChatTags.Init()
HideUI.Init()
HUD.Init({
	OpenShop = Shop.Open,
	OpenIndex = Index.Open,
	OpenSettings = Settings.Open,
	OpenRebirth = Rebirth.Open,
	OpenWorlds = Worlds.Open,
	OpenPets = PetsWindow.Open,
	OpenDonate = Donate.Open,
	OpenUpdates = function()
		UpdateNotes.Open()
	end,
	OpenAdmin = Admin.Open,
	HideUI = HideUI.Toggle,
	UnclaimedIndex = Index.UnclaimedCount,
	RebirthReady = Rebirth.IsReady,
	ReadyEggs = PetsWindow.ReadyEggs,
})
Effects.Init()
DonutFX.Init() -- right after Effects, so it sees every donut in its resting spot
BlackHoleFX.Init()
UnderworldFX.Init()
Treadmill.Init()
Guards.Init()
Weather.Init()
DonutIdle.Init()
Followers.Init()
PetFX.Init()
Flight.Init()
ParticleBudget.Init()
Culling.Init() -- last: everything else has seen the whole map first

-- Tell the server the UI is listening (it then sends the welcome-back popup, etc.)
require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Remotes")).Event("ClientReady"):FireServer()
