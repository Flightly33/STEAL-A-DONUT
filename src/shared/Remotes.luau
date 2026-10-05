--[[
	All RemoteEvents / RemoteFunctions in one place. The server creates them, the client waits for them.

	Server -> Client
		Notify(text, kind)                 toast message ("info" | "success" | "error" | "rare")
		State(snapshot)                    tables that don't fit in attributes (passes, skins, index...)
		ChaseStarted(info)                 you grabbed a box (or an egg) and a guard is after you
		ChaseEnded(result)                 "Safe" | "Caught" | "Deposited" | "Lost"
		OfflineEarnings(amount, seconds)
		LeaderboardUpdated(boardId)
		AreaAnnouncement(text, color)      big server-wide banner (rare spawns / rare steals)
		Flung(velocity)                    you got hit by a weapon/trap: client launches itself
		EggHatched(info)                   { EggId, PetId, Uid } - play the hatch animation
		AdminPanel()                       open the admin panel (you typed the code)
		CrateOpened(info)                  { Crate, Kind, Amount?, Seconds?, Egg?, Pet? } - play the opening
		BoxesReset()                       every biome's boxes were just replaced ("ALL BOXES RESET!")
		BoxOpened(info)                    a box in a pen opened: { Owner, Slot, DonutId, Mutation, Size }
		SkipOdds(info)                     "Open now" on your box: { Slot, Area, Tier, Size, Mutation } - show its odds first

	Client -> Server
		Action(name, arg)                  shop purchases, equip skin, run speed, teleport home...
		ClientReady()                      UI is built; server then sends welcome-back popup etc.
		GetLeaderboard(boardId) -> data    (RemoteFunction)
		GetGlobalStats() -> stats          (RemoteFunction) spawn / found counts of every donut
		GetSellList() -> { SellItem }      (RemoteFunction) your inventory + pen donuts and their prices (UI/Sell)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- NOTE: the folder must NOT sit next to this ModuleScript under the same name ("Remotes"),
-- otherwise the client's WaitForChild finds this script instead of the folder and hangs forever.
local FOLDER_NAME = "GameRemotes"

local EVENTS = { "Notify", "State", "ChaseStarted", "ChaseEnded", "OfflineEarnings", "LeaderboardUpdated", "AreaAnnouncement", "Action", "ClientReady", "Flung", "EggHatched", "AdminPanel", "CrateOpened", "StormBlock", "StormStrike", "BoxesReset", "BoxOpened", "SkipOdds" }
local FUNCTIONS = { "GetLeaderboard", "GetGlobalStats", "GetSellList" }

local Remotes = {}

local folder: Folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for _, name in EVENTS do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	for _, name in FUNCTIONS do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

function Remotes.Event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.Function(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes
