--[[
	Leaderboards: the physical boards next to the shop (scrollable, top 500). Leaderboards.Open()
	shows the same data in a full-screen window; nothing on the HUD opens it any more (the Top 500
	button was removed), but it's kept so a button can be added back in one line.
	The donation board starts with a pinned row (a crown instead of a rank, with a note under the name).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local VirtualList = require(script.Parent.VirtualList)

local Leaderboards = {}

local player = Players.LocalPlayer :: Player

type Entry = { Rank: number, UserId: number, Name: string, Display: string, Color: Color3?, Score: number? }
type BoardData = { Entries: { Entry }, UpdatedAt: number, Live: boolean }

local boardConfigs: { [string]: { Id: string, Title: string, Subtitle: string, Color: Color3 } } = {}
for _, board in Config.Leaderboards.Boards do
	boardConfigs[board.Id] = board
end

local data: { [string]: BoardData } = {}
local listeners: { [string]: { (BoardData) -> () } } = {}

local RANK_COLORS = { Color3.fromRGB(255, 215, 0), Color3.fromRGB(210, 220, 235), Color3.fromRGB(215, 140, 70) }

local function fetch(boardId: string)
	local ok, result = pcall(function()
		return Remotes.Function("GetLeaderboard"):InvokeServer(boardId)
	end)
	if ok and type(result) == "table" then
		data[boardId] = result
		local callbacks: { (BoardData) -> () } = listeners[boardId] or {}
		for _, callback in callbacks do
			task.spawn(callback, result)
		end
	end
end

local function listen(boardId: string, callback: (BoardData) -> ())
	listeners[boardId] = listeners[boardId] or {}
	table.insert(listeners[boardId], callback)
	if data[boardId] then
		callback(data[boardId])
	end
end

-- Builds a scrolling list inside `parent`. Returns a function to feed it a board.
local function makeList(parent: Instance, rowHeight: number, textScale: number, accent: Color3): (BoardData) -> ()
	local scroll = Theme.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ScrollBarThickness = math.floor(10 * textScale),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.new(),
		Parent = parent,
	})
	local function buildRow(): GuiObject
		local row = Theme.new("Frame", { Size = UDim2.new(1, -math.floor(14 * textScale), 0, rowHeight - 4), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.93 }, { Theme.Corner(6) })
		Theme.Label({ Name = "Rank", Font = Theme.Title, Size = UDim2.new(0.16, 0, 0.8, 0), Position = UDim2.fromScale(0.01, 0.1), StrokeThickness = 2 * textScale, Parent = row })
		Theme.Label({ Name = "PlayerName", Font = Theme.Font, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.45, 0, 0.75, 0), Position = UDim2.fromScale(0.18, 0.125), StrokeThickness = 1.5 * textScale, Parent = row })
		Theme.Label({ Name = "Value", Font = Theme.Font, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0.35, 0, 0.75, 0), Position = UDim2.fromScale(0.63, 0.125), StrokeThickness = 1.5 * textScale, Parent = row })
		return row
	end
	local function bindRow(row: GuiObject, entry: Entry)
		local rank = row:FindFirstChild("Rank") :: TextLabel
		local name = row:FindFirstChild("PlayerName") :: TextLabel
		local value = row:FindFirstChild("Value") :: TextLabel
		rank.Text = "#" .. entry.Rank
		rank.TextColor3 = RANK_COLORS[entry.Rank] or Color3.fromRGB(230, 230, 230)
		name.Text = entry.Name
		value.Text = entry.Display
		value.TextColor3 = entry.Color or accent:Lerp(Color3.new(1, 1, 1), 0.35)
		local isMe = entry.UserId == player.UserId
		row.BackgroundColor3 = if isMe then Theme.Colors.Yellow else Color3.new(1, 1, 1)
		row.BackgroundTransparency = if isMe then 0.6 else (if entry.Rank % 2 == 0 then 0.96 else 0.9)
	end
	local list = VirtualList.new(scroll, rowHeight, buildRow, bindRow :: any)
	return function(board: BoardData)
		list:SetEntries(board.Entries)
	end
end

local function findMe(board: BoardData): Entry?
	for _, entry in board.Entries do
		if entry.UserId == player.UserId then
			return entry
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- Physical boards next to the shop
--------------------------------------------------------------------------------
local function buildWorldBoard(screen: BasePart, boardId: string)
	local cfg = boardConfigs[boardId]
	if not cfg then
		return
	end
	local surface = Theme.new("SurfaceGui", {
		Name = "Board_" .. boardId,
		Adornee = screen,
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 25,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Parent = Theme.PlayerGui(),
	})
	local root = Theme.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(20, 20, 32), Parent = surface }, { Theme.Padding(14) })
	local header = Theme.new("Frame", { Size = UDim2.new(1, 0, 0, 110), BackgroundColor3 = cfg.Color, Parent = root }, {
		Theme.Corner(14),
		Theme.Gradient(Theme.Lighten(cfg.Color, 0.2), Theme.Darken(cfg.Color, 0.15)),
	})
	Theme.Label({ Text = "🏆 " .. cfg.Title, Size = UDim2.new(1, -20, 0, 64), Position = UDim2.fromOffset(10, 6), StrokeThickness = 4, Parent = header })
	Theme.Label({ Text = `{cfg.Subtitle} • TOP {Config.Leaderboards.Size}`, Font = Theme.Font, Size = UDim2.new(1, -20, 0, 32), Position = UDim2.fromOffset(10, 70), StrokeThickness = 2, Parent = header })
	local listHolder = Theme.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 122), Size = UDim2.new(1, 0, 1, -178), Parent = root })
	local footer = Theme.Label({ Text = "Loading...", Font = Theme.Font, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 1, -44), TextColor3 = Theme.Colors.Yellow, StrokeThickness = 2, Parent = root })
	local feed = makeList(listHolder, 52, 2, cfg.Color)
	listen(boardId, function(board)
		feed(board)
		local me = findMe(board)
		if #board.Entries == 0 then
			footer.Text = "No scores yet - be the first!"
		elseif me then
			footer.Text = `You are #{me.Rank}! • scroll for more`
		else
			footer.Text = if board.Live then "Showing this server (global board loading...)" else "Scroll to see the top " .. Config.Leaderboards.Size
		end
	end)
end

--------------------------------------------------------------------------------
-- Full-screen window
--------------------------------------------------------------------------------
local modal: Modal.Modal

local function buildModal()
	modal = Modal.new("🏆 TOP 500", Theme.Colors.Orange, Vector2.new(640, 540))
	local body = modal.Body
	local current = Config.Leaderboards.Boards[1].Id
	local subtitle = Theme.Label({ Text = "", Font = Theme.Font, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 50), StrokeThickness = 1.5, Parent = body })
	local listHolder = Theme.new("Frame", { BackgroundColor3 = Color3.fromRGB(20, 20, 32), Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, 0, 1, -120), Parent = body }, { Theme.Corner(12), Theme.Padding(6) })
	local footer = Theme.Label({ Text = "", Font = Theme.Font, TextColor3 = Theme.Colors.Yellow, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 1, -32), StrokeThickness = 1.5, Parent = body })
	local feeds: { [string]: (BoardData) -> () } = {}
	local holders: { [string]: Frame } = {}

	local function show(boardId: string)
		current = boardId
		for id, holder in holders do
			holder.Visible = id == boardId
		end
		local cfg = boardConfigs[boardId]
		subtitle.Text = cfg.Subtitle
		local board = data[boardId]
		local me = board and findMe(board)
		footer.Text = if me then `Your rank: #{me.Rank}` else "Keep playing to reach the top 500!"
	end

	for _, cfg in Config.Leaderboards.Boards do
		local holder = Theme.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, Parent = listHolder })
		holders[cfg.Id] = holder
		feeds[cfg.Id] = makeList(holder, 40, 1, cfg.Color)
		listen(cfg.Id, function(board)
			feeds[cfg.Id](board)
			if current == cfg.Id then
				show(cfg.Id)
			end
		end)
	end

	local tabs = {}
	for _, cfg in Config.Leaderboards.Boards do
		table.insert(tabs, { Name = cfg.Id, Text = cfg.Id, Color = cfg.Color })
	end
	local selectTab = Modal.Tabs(body, tabs, show)
	modal.OnOpen = function()
		selectTab(current)
		task.spawn(fetch, current)
	end
end

function Leaderboards.Open()
	modal:Open()
end

function Leaderboards.Init()
	buildModal()

	task.spawn(function()
		local map = workspace:WaitForChild("Map")
		local folder = map:WaitForChild("Hub"):WaitForChild("Leaderboards")
		for _, cfg in Config.Leaderboards.Boards do
			local board = folder:WaitForChild("Board_" .. cfg.Id, 30)
			local screen = board and board:WaitForChild("Screen", 30)
			if screen and screen:IsA("BasePart") then
				buildWorldBoard(screen, cfg.Id)
			end
		end
	end)

	Remotes.Event("LeaderboardUpdated").OnClientEvent:Connect(function(boardId: string)
		task.wait(math.random() * 3) -- spread requests from many clients
		fetch(boardId)
	end)

	task.spawn(function()
		task.wait(3)
		while true do
			for _, cfg in Config.Leaderboards.Boards do
				fetch(cfg.Id)
				task.wait(1)
			end
			task.wait(60)
		end
	end)
end

return Leaderboards
