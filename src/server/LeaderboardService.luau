--[[
	LeaderboardService
	==================
	Global top-500 boards (OrderedDataStores) for Money earned, Speed, Rarest donut and Time played.

	* Scores are written for each player every Config.Leaderboards.WriteInterval seconds and on leave.
	* Boards refresh one at a time on a rotation to stay inside the DataStore request budget
	  (fetching 500 entries costs 5 requests).
	* Money/Speed can exceed what an OrderedDataStore can hold (64-bit integers), so they are stored
	  as log10(value) * 1e9 and decoded for display.
	* If DataStores are unavailable (Studio without API access), boards show the players in this server.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local UserService = game:GetService("UserService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Donuts = require(Shared.Donuts)
local Rarities = require(Shared.Rarities)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

export type Entry = { Rank: number, UserId: number, Name: string, Display: string, Color: Color3? }
type Board = { Entries: { Entry }, UpdatedAt: number, Live: boolean }

local LOG_SCALE = 1e9
local cfg = Config.Leaderboards

local stores: { [string]: OrderedDataStore } = {}
local cache: { [string]: Board } = {}
local nameCache: { [number]: string } = {}
local lastWritten: { [Player]: { [string]: number } } = {}

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
		return encodeLog(data.Speed)
	elseif boardId == "Rarest" then
		return data.BestDonutScore
	elseif boardId == "Time" then
		return math.floor(data.PlayTime)
	end
	return 0
end

local function display(boardId: string, score: number): (string, Color3?)
	if boardId == "Money" then
		return Format.Money(decodeLog(score)), nil
	elseif boardId == "Speed" then
		return Format.Number(decodeLog(score)), nil
	elseif boardId == "Rarest" then
		local donut = Donuts.ByScore[score]
		if donut then
			return donut.Name, Rarities.Get(donut.Rarity).Color
		end
		return "-", nil
	elseif boardId == "Time" then
		return Format.Duration(score), nil
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
	for _, board in cfg.Boards do
		local store = stores[board.Id]
		local score = scoreFor(board.Id, profile.Data)
		if store and score > 0 and lastWritten[player][board.Id] ~= score then
			local ok, err = pcall(store.SetAsync, store, tostring(player.UserId), score)
			if ok then
				lastWritten[player][board.Id] = score
			else
				warn(`[Leaderboards] Write failed ({board.Id}): {err}`)
			end
		end
	end
end

function LeaderboardService.OnPlayerRemoving(player: Player)
	LeaderboardService.WriteScores(player)
	lastWritten[player] = nil
end

--------------------------------------------------------------------------------
-- Reading
--------------------------------------------------------------------------------
local function liveServerBoard(boardId: string): Board
	local rows = {}
	for player, profile in DataService.GetAll() do
		table.insert(rows, { UserId = player.UserId, Name = player.DisplayName, Score = scoreFor(boardId, profile.Data) })
	end
	table.sort(rows, function(a, b)
		return a.Score > b.Score
	end)
	local entries = {}
	for rank, row in rows do
		local text, color = display(boardId, row.Score)
		table.insert(entries, { Rank = rank, UserId = row.UserId, Name = row.Name, Display = text, Color = color })
	end
	return { Entries = entries, UpdatedAt = os.time(), Live = true }
end

local function waitForBudget()
	while DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.GetSortedAsync) < 1 do
		task.wait(2)
	end
end

local function refreshBoard(boardId: string)
	local store = stores[boardId]
	if not store then
		cache[boardId] = liveServerBoard(boardId)
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
		if not cache[boardId] then
			cache[boardId] = liveServerBoard(boardId)
		end
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
		table.insert(entries, { Rank = i, UserId = userId, Name = nameCache[userId] or "?", Display = text, Color = color })
	end
	cache[boardId] = { Entries = entries, UpdatedAt = os.time(), Live = false }
	Remotes.Event("LeaderboardUpdated"):FireAllClients(boardId)
end

function LeaderboardService.Init()
	if DataService.DataStoresEnabled() then
		for _, board in cfg.Boards do
			local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, cfg.StorePrefix .. board.Id)
			if ok then
				stores[board.Id] = store
			end
		end
	end

	Remotes.Function("GetLeaderboard").OnServerInvoke = function(_player: Player, boardId: any)
		if type(boardId) ~= "string" then
			return nil
		end
		local board = cache[boardId]
		if not board or board.Live then
			-- Nothing fetched yet (or no DataStores): show this server's players.
			board = liveServerBoard(boardId)
		end
		return board
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
