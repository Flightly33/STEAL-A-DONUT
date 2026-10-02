--[[
	Ownership: is this player the game's owner (or someone they trust)?

	The owner is the game's creator (for a group game, the group's owner), anyone testing in
	Studio, and the UserIds in Config.Admin.AllowedUserIds. Owners get the commands that give away
	paid products, the owner-only base skin and floors past the normal limit.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Ownership = {}

function Ownership.IsOwner(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if table.find(Config.Admin.AllowedUserIds, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
	return ok and rank == 255
end

return Ownership
