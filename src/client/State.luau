--[[
	Client-side view of the local player's state.
	Numbers come from Player attributes (Money, Speed, Income...); tables come from the State remote.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)

local player = Players.LocalPlayer :: Player

export type Snapshot = {
	Passes: { [string]: boolean },
	OwnedSkins: { [string]: boolean },
	EquippedSkin: string,
	Discovered: { [string]: boolean },
	DiscoveredMutations: { [string]: { [string]: boolean } }?,
	IndexClaims: { [string]: string }?,
	OwnedTrails: { [string]: boolean }?,
	EquippedTrail: string?,
	PodiumMode: string,
	MusicVolume: number?,
	MusicOn: boolean?,
	Items: { [string]: boolean }?,
	PlotIndex: number?,
	Eggs: { { Uid: string, Id: string, HatchAt: number } }?,
	Pets: { { Uid: string, Id: string } }?,
	EquippedPets: { string }?,
	Favorite: string?, -- slot key of your favourite donut
	Donated: number?,
	HiddenItems: { [string]: boolean }?, -- items taken off the hotbar
	SeenTutorial: boolean?,
	SeenUpdate: number?,
	NotesOnLogin: boolean?,
	TutorialEggClaimed: boolean?,
	Admin: boolean?,
	GodMode: boolean?,
	MeteorShards: number?, -- for The Cosmic Donut (UI/CosmicForge)
}

local State = {}

State.Data = {
	Passes = {},
	OwnedSkins = { Classic = true },
	EquippedSkin = "Classic",
	Discovered = {},
	PodiumMode = "Rarest",
	PlotIndex = nil,
	Eggs = {},
	Pets = {},
	EquippedPets = {},
} :: Snapshot

State.Changed = Signal.new()

function State.Get(name: string): any
	return player:GetAttribute(name)
end

function State.Number(name: string): number
	local value = player:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

function State.OnAttribute(name: string, callback: (any) -> ())
	player:GetAttributeChangedSignal(name):Connect(function()
		callback(player:GetAttribute(name))
	end)
	callback(player:GetAttribute(name))
end

function State.Action(name: string, arg: any?)
	Remotes.Event("Action"):FireServer(name, arg)
end

Remotes.Event("State").OnClientEvent:Connect(function(snapshot: Snapshot)
	State.Data = snapshot
	State.Changed:Fire(snapshot)
end)

return State
