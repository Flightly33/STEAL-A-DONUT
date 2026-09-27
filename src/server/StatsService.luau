--[[
	StatsService
	============
	Global donut stats across every server: how many times each donut (and each mutation) has
	spawned in the lane and been brought home. The Index shows them as a rarity scale
	("Spawned 1,204 times • 0.0031% of all spawns • found 312 times").

	Each server counts locally and adds its counts to ONE of Config.GlobalStats.Shards DataStore keys
	every FlushInterval seconds (UpdateAsync, so servers never overwrite each other). The totals are
	read back from all shards every RefreshInterval seconds. Using several keys keeps each key well
	under the DataStore per-key write limit even when many servers are running.
	Without DataStore access (Studio) the numbers just count this server.
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local StatsService = {}

type Counts = { [string]: { number } } -- id -> { spawned, found }
type Blob = { D: Counts, M: Counts }

local cfg = Config.GlobalStats
local store: DataStore? = nil
local pending: Blob = { D = {}, M = {} }
local totals: Blob = { D = {}, M = {} }

local function add(counts: Counts, id: string, spawned: number, found: number)
	local entry = counts[id]
	if not entry then
		entry = { 0, 0 }
		counts[id] = entry
	end
	entry[1] += spawned
	entry[2] += found
end

local function merge(into: Blob, from: Blob)
	for id, entry in from.D do
		add(into.D, id, entry[1] or 0, entry[2] or 0)
	end
	for id, entry in from.M do
		add(into.M, id, entry[1] or 0, entry[2] or 0)
	end
end

local function isEmpty(blob: Blob): boolean
	return next(blob.D) == nil and next(blob.M) == nil
end

function StatsService.RecordSpawn(donutId: string, mutationId: string)
	add(pending.D, donutId, 1, 0)
	if mutationId ~= "None" then
		add(pending.M, mutationId, 1, 0)
	end
end

-- Returns the (approximate) number of times this donut has ever been found, this one included.
function StatsService.RecordFound(donutId: string, mutationId: string): number
	add(pending.D, donutId, 0, 1)
	if mutationId ~= "None" then
		add(pending.M, mutationId, 0, 1)
	end
	local global = totals.D[donutId]
	return (if global then global[2] else 0) + pending.D[donutId][2]
end

-- Everything we know: the global totals plus what this server hasn't sent yet.
function StatsService.Snapshot(): Blob
	local snapshot: Blob = { D = {}, M = {} }
	merge(snapshot, totals)
	merge(snapshot, pending)
	return snapshot
end

local function flush()
	if not store or isEmpty(pending) then
		return
	end
	local sending = pending
	pending = { D = {}, M = {} }
	local key = "Shard_" .. math.random(1, cfg.Shards)
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key, function(old: any)
			local blob: Blob = if type(old) == "table" then old else { D = {}, M = {} }
			blob.D = blob.D or {}
			blob.M = blob.M or {}
			merge(blob, sending)
			return blob
		end)
	end)
	if ok then
		merge(totals, sending) -- count it right away, the next refresh confirms it
	else
		warn(`[GlobalStats] Flush failed: {err}`)
		merge(pending, sending) -- try again next time
	end
end

local function refresh()
	if not store then
		return
	end
	local fresh: Blob = { D = {}, M = {} }
	for shard = 1, cfg.Shards do
		local ok, result = pcall(function()
			return (store :: DataStore):GetAsync("Shard_" .. shard)
		end)
		if not ok then
			return -- keep the old totals rather than showing partial ones
		end
		if type(result) == "table" then
			merge(fresh, { D = result.D or {}, M = result.M or {} })
		end
	end
	totals = fresh
end

function StatsService.Init(dataStoresEnabled: boolean)
	if cfg.Enabled and dataStoresEnabled then
		local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, cfg.StoreName)
		if ok then
			store = result
		end
	end

	Remotes.Function("GetGlobalStats").OnServerInvoke = function()
		return StatsService.Snapshot()
	end

	task.spawn(function()
		refresh()
		local sinceRefresh = 0
		while true do
			local wait = cfg.FlushInterval + math.random() * 20
			task.wait(wait)
			flush()
			sinceRefresh += wait
			if sinceRefresh >= cfg.RefreshInterval then
				sinceRefresh = 0
				refresh()
			end
		end
	end)
	game:BindToClose(flush)
end

return StatsService
