--[[
	FriendService: the Friend Boost (Config.FriendBoost). Playing in the same server as your Roblox
	friends earns more money: the first friend here adds +1x to your money multiplier, and every
	friend after that +0.25x more. Worked out again whenever someone joins or leaves.

	Each player gets two attributes: "Friends" (how many of their friends are here) and
	"FriendBoost" (the bonus, 0 with none). DataService.MoneyMultiplier adds the bonus on; the HUD
	shows a badge while it's above 0.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local ShopService = require(script.Parent.ShopService)

local FriendService = {}

-- "smallerId:biggerId" -> are they friends? (Roblox is asked once per pair; a failed check isn't
-- remembered, so it's asked again the next time someone joins or leaves.)
local known: { [string]: boolean } = {}
local tokens: { [Player]: number } = {}

-- The money bonus for having `friends` friends in the server.
function FriendService.Bonus(friends: number): number
	if friends <= 0 then
		return 0
	end
	return Config.FriendBoost.First + (friends - 1) * Config.FriendBoost.Each
end

local function areFriends(a: Player, b: Player): boolean
	local key = if a.UserId < b.UserId then `{a.UserId}:{b.UserId}` else `{b.UserId}:{a.UserId}`
	local answer = known[key]
	if answer ~= nil then
		return answer
	end
	local ok, result = pcall(a.IsFriendsWithAsync, a, b.UserId) -- (a web call: yields)
	if not ok then
		return false
	end
	known[key] = result == true
	return result == true
end

-- Count `player`'s friends in the server (not `leaving`: they're on their way out) and update their
-- bonus. Only the newest count for a player is kept, in case two of them overlap.
local function refresh(player: Player, leaving: Player?)
	tokens[player] = (tokens[player] or 0) + 1
	local token = tokens[player]
	local count = 0
	for _, other in Players:GetPlayers() do
		if other ~= player and other ~= leaving and areFriends(player, other) then
			count += 1
		end
	end
	if RunService:IsStudio() then
		count += Config.Debug.StudioFakeFriends
	end
	if tokens[player] ~= token or not player.Parent then
		return
	end
	local bonus = FriendService.Bonus(count)
	local before = player:GetAttribute("FriendBoost")
	player:SetAttribute("Friends", count)
	if before == bonus then
		return
	end
	player:SetAttribute("FriendBoost", bonus)
	ShopService.RefreshMultipliers(player)
	if type(before) == "number" and bonus > before then
		local friends = if count == 1 then "1 friend" else `{count} friends`
		Remotes.Event("Notify"):FireClient(player, `Friend Boost: +{Format.Multiplier(bonus)}x money ({friends} here)`, "success")
	end
end

local function refreshAll(leaving: Player?)
	for _, player in Players:GetPlayers() do
		if player ~= leaving then
			task.spawn(refresh, player, leaving)
		end
	end
end

function FriendService.Init()
	Players.PlayerAdded:Connect(function(player: Player)
		player:SetAttribute("Friends", 0)
		player:SetAttribute("FriendBoost", 0)
		refreshAll()
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		tokens[player] = nil
		refreshAll(player)
	end)
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("FriendBoost") == nil then
			player:SetAttribute("Friends", 0)
			player:SetAttribute("FriendBoost", 0)
		end
	end
	refreshAll()
end

return FriendService
