--[[
	All RemoteEvents / RemoteFunctions in one place. The server creates them, the client waits for them.

	Server -> Client
		Notify(text, kind)                 toast message ("info" | "success" | "error" | "rare")
		State(snapshot)                    tables that don't fit in attributes (passes, skins, index...)
		ChaseStarted(info)                 you stole a donut and a guard is after you
		ChaseEnded(result)                 "Safe" | "Caught" | "Deposited" | "Lost"
		OfflineEarnings(amount, seconds)
		LeaderboardUpdated(boardId)
		AreaAnnouncement(text, color)      big server-wide banner (rare spawns / rare steals)

	Client -> Server
		Action(name, arg)                  shop purchases, equip skin, slow mode, teleport home...
		GetLeaderboard(boardId) -> data    (RemoteFunction)
]]

local RunService = game:GetService("RunService")

local EVENTS = { "Notify", "State", "ChaseStarted", "ChaseEnded", "OfflineEarnings", "LeaderboardUpdated", "AreaAnnouncement", "Action" }
local FUNCTIONS = { "GetLeaderboard" }

local Remotes = {}

local folder: Folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
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
	folder.Parent = script.Parent
else
	folder = script.Parent:WaitForChild("Remotes") :: Folder
end

function Remotes.Event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.Function(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes
