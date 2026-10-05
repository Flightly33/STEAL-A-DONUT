--[[
	LeaderboardService
	==================
	Global top-500 boards (OrderedDataStores) for Money earned, Speed, Rarest donut, Time played and
	Robux donated.

	* Scores are written for each player every Config.Leaderboards.WriteInterval seconds and on leave.
	* Boards refresh one at a time on a rotation to stay inside the DataStore request budget
	  (fetching 500 entries costs 5 requests).
	* Money/Speed can exceed what an OrderedDataStore can hold (64-bit integers), so they are stored
	  as log10(value) * 1e9 and decoded for display.
	* Players in this server are merged in live, so boards show fresh numbers immediately (the global
	  data only refreshes every few minutes). Without DataStores (Studio) this is all you'll see.
	* Admins - players who used the admin panel, and the game's owner - are left off every board
	  except donations (Config.Admin.HideFromLeaderboards). Scores they saved before that are
	  removed from the global boards the next time they play, and never shown in the meantime once
	  a server has seen them.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Donuts = require(Shared.Donuts)
local Rarities = require(Shared.Rarities)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local Ownership = require(script.Parent.Ownership)

local LeaderboardService = {}

export type Entry = { Rank: number, UserId: number, Name: string, Display: string, Color: Color3?, Score: number }
type Board = { Entries: { Entry }, UpdatedAt: number, Live: boolean }

local LOG_SCALE = 1e9
local cfg = Config.Leaderboards

local stores: { [string]: OrderedDataStore } = {}
local cache: { [string]: Board } = {}
local nameCache: { [number]: string } = {}
local lastWritten: { [Player]: { [string]: number } } = {}
local ownerCache: { [Player]: boolean } = {}
local hiddenIds: { [number]: boolean } = {} -- admins seen by this server: kept off fetched boards too
local purged: { [number]: boolean } = {}

--------------------------------------------------------------------------------
-- Encoding
--------------------------------------------------------------------------------
local function encodeLog(value: number): number
	return math.floor(math.log10(math.max(value, 0) + 1) * LOG_SCALE)
end

local function decodeLog(score: number): number
	return 10 ^ (score / LOG_SCALE) - 1
end

local function scoreFor(boardId: string, data: DataService.Data): number
	if boardId == "Money" then
		return encodeLog(data.TotalEarned)
	elseif boardId == "Speed" then
		return encodeLog(math.max(data.BestSpeed, data.Speed)) -- skins cost Speed, so rank the best ever
	elseif boardId == "Rarest" then
		return data.BestDonutScore
	elseif boardId == "Time" then
		return math.floor(data.PlayTime)
	elseif boardId == "Donated" then
		return math.floor(data.Donated)
	end
	return 0
end

-- Is this player an admin? (used the admin panel, or owns the game - not counting Studio, where
-- everyone counts as the owner)
local function isAdmin(player: Player, data: DataService.Data): boolean
	if data.UsedAdmin then
		return true
	end
	local owner = ownerCache[player]
	if owner == nil then
		owner = not RunService:IsStudio() and Ownership.IsOwner(player)
		ownerCache[player] = owner
	end
	return owner == true
end

-- Admins don't count on the normal boards (donations are real, so they still do).
local function hidden(boardId: string, player: Player, data: DataService.Data): boolean
	if boardId == "Donated" or not Config.Admin.HideFromLeaderboards or not isAdmin(player, data) then
		return false
	end
	hiddenIds[player.UserId] = true
	return true
end

-- Take an admin's old scores off the global boards (once per server).
local function purge(player: Player, data: DataService.Data)
	if purged[player.UserId] or not hidden("Money", player, data) then
		return
	end
	purged[player.UserId] = true
	for _, board in cfg.Boards do
		local store = stores[board.Id]
		if store and board.Id ~= "Donated" then
			local ok, err = pcall(function()
				store:RemoveAsync(tostring(player.UserId))
			end)
			if not ok then
				warn(`[Leaderboards] Remove failed ({board.Id}): {err}`)
			end
		end
	end
end

local function display(boardId: string, score: number): (string, Color3?)
	if boardId == "Money" then
		return Format.Money(decodeLog(score)), nil
	elseif boardId == "Speed" then
		return Format.Number(decodeLog(score)), nil
	elseif boardId == "Rarest" then
		local donut, mutation = Donuts.FromScore(score)
		if donut then
			local color = if mutation ~= "None" then Rarities.Mutation(mutation).Color else Rarities.Get(donut.Rarity).Color
			return Rarities.DisplayName(donut.Name, mutation), color
		end
		return "-", nil
	elseif boardId == "Time" then
		return Format.Duration(score), nil
	elseif boardId == "Donated" then
		return "R$ " .. (if score < 1_000_000 then Format.Commas(score) else Format.Number(score)), nil
	end
	return tostring(score), nil
end

--------------------------------------------------------------------------------
-- Names
--------------------------------------------------------------------------------
local function resolveNames(userIds: { number })
	local missing = {}
	for _, id in userIds do
		if not nameCache[id] and id > 0 then
			table.insert(missing, id)
		end
	end
	for start = 1, #missing, 100 do
		local chunk = table.move(missing, start, math.min(start + 99, #missing), 1, {})
		local ok, infos = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, chunk)
		if ok and infos then
			for _, info in infos do
				nameCache[info.Id] = info.DisplayName ~= "" and info.DisplayName or info.Username
			end
		end
	end
	-- Fallback for a handful of stragglers only (this call is one request per user).
	local stillMissing = 0
	for _, id in userIds do
		if not nameCache[id] then
			stillMissing += 1
			local ok, name = false, nil
			if stillMissing <= 10 then
				ok, name = pcall(Players.GetNameFromUserIdAsync, Players, id)
			end
			nameCache[id] = if ok and name then name else ("Player " .. id)
		end
	end
end

--------------------------------------------------------------------------------
-- Writing
--------------------------------------------------------------------------------
function LeaderboardService.WriteScores(player: Player)
	local profile = DataService.Get(player)
	if not profile or profile.NoSave or not DataService.DataStoresEnabled() then
		return
	end
	lastWritten[player] = lastWritten[player] or {}
	purge(player, profile.Data)
	for _, board in cfg.Boards do
		local store = stores[board.Id]
		local score = scoreFor(board.Id, profile.Data)
		if store and score > 0 and lastWritten[player][board.Id] ~= score and not hidden(board.Id, player, profile.Data) then
			local ok, err = pcall(store.SetAsync, store, tostring(player.UserId), score)
			if ok then
				lastWritten[player][board.Id] = score
			else
				warn(`[Leaderboards] Write failed ({board.Id}): {err}`)
			end
		end
	end
end

-- A tip was just bought: save it to the global board now (not on the next periodic write) and
-- tell every client to redraw the donation board, which merges in this server's players live.
function LeaderboardService.OnDonation(player: Player)
	task.spawn(LeaderboardService.WriteScores, player)
	Remotes.Event("LeaderboardUpdated"):FireAllClients("Donated")
end

function LeaderboardService.OnPlayerRemoving(player: Player)
	LeaderboardService.WriteScores(player)
	lastWritten[player] = nil
	ownerCache[player] = nil
end

--------------------------------------------------------------------------------
-- Reading
--------------------------------------------------------------------------------
-- Global board (if fetched) + everyone in this server with their current score.
local function withLivePlayers(boardId: string, board: Board?): Board
	local byUser: { [number]: { UserId: number, Name: string, Score: number } } = {}
	if board then
		for _, entry in board.Entries do
			if not (hiddenIds[entry.UserId] and boardId ~= "Donated") then
				byUser[entry.UserId] = { UserId = entry.UserId, Name = entry.Name, Score = entry.Score }
			end
		end
	end
	for player, profile in DataService.GetAll() do
		local score = scoreFor(boardId, profile.Data)
		if boardId == "Donated" then
			score += profile.Session.TestDonated -- Studio test tips: shown here, never saved
		end
		local existing = byUser[player.UserId]
		if hidden(boardId, player, profile.Data) then
			byUser[player.UserId] = nil
		elseif score > 0 and (not existing or score > existing.Score) then
			byUser[player.UserId] = { UserId = player.UserId, Name = player.DisplayName, Score = score }
		end
	end
	local rows = {}
	for _, row in byUser do
		table.insert(rows, row)
	end
	table.sort(rows, function(a, b)
		return a.Score > b.Score
	end)
	local entries: { Entry } = {}
	for rank = 1, math.min(#rows, cfg.Size) do
		local row = rows[rank]
		local text, color = display(boardId, row.Score)
		table.insert(entries, { Rank = rank, UserId = row.UserId, Name = row.Name, Display = text, Color = color, Score = row.Score })
	end
	return { Entries = entries, UpdatedAt = if board then board.UpdatedAt else os.time(), Live = board == nil }
end

local function waitForBudget()
	while DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.GetSortedAsync) < 1 do
		task.wait(2)
	end
end

local function refreshBoard(boardId: string)
	local store = stores[boardId]
	if not store then
		Remotes.Event("LeaderboardUpdated"):FireAllClients(boardId)
		return
	end
	local rows: { { key: string, value: number } } = {}
	local ok, err = pcall(function()
		waitForBudget()
		local pages = store:GetSortedAsync(false, 100)
		while true do
			for _, row in pages:GetCurrentPage() do
				table.insert(rows, row)
			end
			if pages.IsFinished or #rows >= cfg.Size then
				break
			end
			waitForBudget()
			pages:AdvanceToNextPageAsync()
		end
	end)
	if not ok then
		warn(`[Leaderboards] Refresh failed ({boardId}): {err}`)
		return
	end

	local userIds = {}
	for i = 1, math.min(#rows, cfg.Size) do
		table.insert(userIds, tonumber(rows[i].key) or 0)
	end
	resolveNames(userIds)

	local entries = {}
	for i = 1, math.min(#rows, cfg.Size) do
		local userId = tonumber(rows[i].key) or 0
		local text, color = display(boardId, rows[i].value)
		table.insert(entries, { Rank = i, UserId = userId, Name = nameCache[userId] or "?", Display = text, Color = color, Score = rows[i].value })
	end
	cache[boardId] = { Entries = entries, UpdatedAt = os.time(), Live = false }
	Remotes.Event("LeaderboardUpdated"):FireAllClients(boardId)
end

function LeaderboardService.Init()
	if DataService.DataStoresEnabled() then
		for _, board in cfg.Boards do
			local prefix = cfg.StoreVersions[board.Id] or cfg.StorePrefix
			local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, prefix .. board.Id)
			if ok then
				stores[board.Id] = store
			end
		end
	end

	Remotes.Function("GetLeaderboard").OnServerInvoke = function(_player: Player, boardId: any)
		if type(boardId) ~= "string" then
			return nil
		end
		return withLivePlayers(boardId, cache[boardId])
	end

	-- Periodic score writes
	task.spawn(function()
		while true do
			task.wait(cfg.WriteInterval)
			for _, player in Players:GetPlayers() do
				task.spawn(LeaderboardService.WriteScores, player)
				task.wait(0.3)
			end
		end
	end)

	-- Board refresh rotation (first pass quickly so boards fill soon after the server starts)
	task.spawn(function()
		task.wait(5)
		for _, board in cfg.Boards do
			refreshBoard(board.Id)
			task.wait(3)
		end
		local index = 0
		while true do
			task.wait(cfg.RefreshInterval)
			index = index % #cfg.Boards + 1
			refreshBoard(cfg.Boards[index].Id)
		end
	end)
end

return LeaderboardService
