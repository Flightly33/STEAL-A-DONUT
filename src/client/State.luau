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
	PodiumMode: string,
	PlotIndex: number?,
	SlowMode: boolean,
}

local State = {}

State.Data = {
	Passes = {},
	OwnedSkins = { Classic = true },
	EquippedSkin = "Classic",
	Discovered = {},
	PodiumMode = "Rarest",
	PlotIndex = nil,
	SlowMode = false,
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
