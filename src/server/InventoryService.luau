--[[
	InventoryService
	================
	Your inventory (DataService Data.Inventory): every box you bring back to the lobby, and every
	donut that comes out of a box, is a Tool in your backpack (the hotbar at the bottom).
	  * Hold a box or donut and click / tap while you're in your pen: it goes down there - a box's
	    timer starts (PlotService.AddBox; click it to open it once it's ready), a donut starts
	    roaming and earning (PlotService.AddDonut).
	  * Donuts can be sold from the inventory at the sell stall in the lobby (UI/Sell). Donuts on
	    your base can be picked up back into the inventory ("Pick up" on them, PlotService).
	  * The free bat isn't in here: ItemService hands it out.
	Tools are rebuilt from the saved list every time you spawn, so nothing is ever lost.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Boxes = require(Shared.Boxes)
local Donuts = require(Shared.Donuts)
local Rarities = require(Shared.Rarities)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local DonutModel = require(Shared.DonutModel)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local InventoryService = {}

local rgb = Color3.fromRGB
local lastPlace: { [Player]: number } = {}

local function notify(player: Player, text: string, kind: string?)
	Remotes.Event("Notify"):FireClient(player, text, kind or "info")
end

-- What an inventory item is called (the tool's name on the hotbar).
function InventoryService.ItemName(item: DataService.InvItem): string
	if item.Kind == "Box" then
		return Rarities.DisplayName(Boxes.DisplayName(item.Tier or "Basic", item.Size), item.Mutation, nil)
	end
	local donut = item.Id and Donuts.ById[item.Id]
	return if donut then Rarities.DisplayName(donut.Name, item.Mutation, item.Size) else "Donut"
end

function InventoryService.Count(player: Player): number
	local profile = DataService.Get(player)
	return if profile then #profile.Data.Inventory else 0
end

function InventoryService.IsFull(player: Player): boolean
	return InventoryService.Count(player) >= Config.Boxes.MaxInventory
end

function InventoryService.Find(player: Player, uid: string): (DataService.InvItem?, number?)
	local profile = DataService.Get(player)
	if not profile then
		return nil, nil
	end
	for index, item in profile.Data.Inventory do
		if item.Uid == uid then
			return item, index
		end
	end
	return nil, nil
end

--------------------------------------------------------------------------------
-- Tools
--------------------------------------------------------------------------------
local function handleFor(item: DataService.InvItem): BasePart
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.CanCollide = false
	handle.Massless = true
	handle.TopSurface = Enum.SurfaceType.Studs
	handle.BottomSurface = Enum.SurfaceType.Inlet
	if item.Kind == "Box" then
		local tier = Boxes.Tier(item.Tier)
		local mutation = Rarities.Mutation(item.Mutation)
		handle.Size = Vector3.new(2.4, 1.2, 1.7)
		handle.Color = if mutation.Id ~= "None" then mutation.Frosting or mutation.Color else tier.Color
		handle.Material = if mutation.Id ~= "None" then mutation.Material or Enum.Material.Plastic else Enum.Material.Plastic
	else
		local donut = item.Id and Donuts.ById[item.Id]
		local mutation = Rarities.Mutation(item.Mutation)
		handle.Shape = Enum.PartType.Cylinder
		handle.Size = Vector3.new(0.8, 2, 2)
		handle.Color = if mutation.Frosting then mutation.Frosting elseif donut then donut.Frosting else rgb(255, 170, 205)
		handle.Material = if mutation.Material then mutation.Material else Enum.Material.SmoothPlastic
	end
	return handle
end

-- A donut tool shows a tiny copy of the donut in your hand while you hold it. It's built when you
-- take the tool out and removed when you put it away (a full inventory would otherwise keep
-- hundreds of donut parts around). In your hand a tool's handle points its Y axis forward and its
-- Z axis up: the donut stands up in front of your hand, its face turned back towards you.
local HELD_SCALE = 0.32
local HELD_OFFSET = CFrame.fromMatrix(Vector3.new(0, 0.9, 0.45), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 1, 0))

local function showHeldDonut(tool: Tool, handle: BasePart, item: DataService.InvItem)
	if tool:FindFirstChild("HeldDonut") then
		return
	end
	local donut = item.Id and Donuts.ById[item.Id]
	if not donut then
		return
	end
	local model = DonutModel.Build(donut, { Scale = HELD_SCALE, NoEffects = true, Mutation = item.Mutation, Size = item.Size })
	model.Name = "HeldDonut"
	local root = model.PrimaryPart :: BasePart
	-- move the whole little donut onto the handle, then let the welds hold it there
	model:PivotTo(handle.CFrame * HELD_OFFSET)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
		end
	end
	local weld = Instance.new("Weld")
	weld.Name = "HeldWeld"
	weld.Part0 = handle
	weld.Part1 = root
	weld.C0 = HELD_OFFSET
	weld.Parent = root
	model.Parent = tool
end

local function makeTool(player: Player, item: DataService.InvItem): Tool
	local tool = Instance.new("Tool")
	tool.Name = InventoryService.ItemName(item)
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = if item.Kind == "Box" then "Click in your pen to put it down, then click it when its timer runs out" else "Click in your pen to put it down"
	tool:SetAttribute("InvUid", item.Uid)
	tool:SetAttribute("InvKind", item.Kind)
	local handle = handleFor(item)
	handle.Parent = tool
	tool.Grip = CFrame.new(0, -0.2, 0.6)
	if item.Kind == "Donut" then
		-- (the handle is just something to hold: the tiny donut is what you see)
		(handle :: Part).Shape = Enum.PartType.Block
		handle.Size = Vector3.new(0.4, 0.4, 0.4)
		handle.Transparency = 1
		tool.Grip = CFrame.new()
		tool.Equipped:Connect(function()
			showHeldDonut(tool, handle, item)
		end)
		tool.Unequipped:Connect(function()
			local held = tool:FindFirstChild("HeldDonut")
			if held then
				held:Destroy()
			end
		end)
	end
	tool.Activated:Connect(function()
		InventoryService.Place(player, item.Uid)
	end)
	return tool
end

-- Every tool of the player's inventory (in the backpack and the one in their hand).
local function existingTools(player: Player): { [string]: Tool }
	local found = {}
	local containers: { Instance } = {}
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		table.insert(containers, backpack)
	end
	if player.Character then
		table.insert(containers, player.Character)
	end
	for _, container in containers do
		for _, child in container:GetChildren() do
			local uid = child:GetAttribute("InvUid")
			if child:IsA("Tool") and type(uid) == "string" then
				found[uid] = child
			end
		end
	end
	return found
end

-- Make the backpack match the saved inventory (adds missing tools, removes stale ones).
function InventoryService.SyncTools(player: Player)
	local profile = DataService.Get(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not profile or not backpack then
		return
	end
	local tools = existingTools(player)
	local wanted: { [string]: boolean } = {}
	for _, item in profile.Data.Inventory do
		wanted[item.Uid] = true
		if not tools[item.Uid] then
			makeTool(player, item).Parent = backpack
		end
	end
	for uid, tool in tools do
		if not wanted[uid] then
			tool:Destroy()
		end
	end
	player:SetAttribute("InventoryCount", #profile.Data.Inventory)
end

--------------------------------------------------------------------------------
-- Adding and removing
--------------------------------------------------------------------------------
local function newUid(profile: DataService.Profile): string
	local uid = tostring(profile.Data.NextUid)
	profile.Data.NextUid += 1
	return uid
end

-- A box made it back to the lobby. Returns false if the inventory is full.
function InventoryService.AddBox(player: Player, tier: string, size: string, area: number, mutation: string?): boolean
	local profile = DataService.Get(player)
	if not profile or InventoryService.IsFull(player) then
		return false
	end
	table.insert(profile.Data.Inventory, {
		Uid = newUid(profile),
		Kind = "Box",
		Tier = tier,
		Size = size,
		Area = area,
		Mutation = if mutation and mutation ~= "None" then mutation else nil,
	})
	InventoryService.SyncTools(player)
	return true
end

-- A donut came out of a box (or the admin panel made one). Always fits: a donut that hatched
-- from a box you already had shouldn't be lost because the inventory is full.
function InventoryService.AddDonut(player: Player, donutId: string, level: number?, mutation: string?, size: string?)
	local profile = DataService.Get(player)
	if not profile or not Donuts.ById[donutId] then
		return
	end
	table.insert(profile.Data.Inventory, {
		Uid = newUid(profile),
		Kind = "Donut",
		Id = donutId,
		Level = level or 1,
		Mutation = if mutation and mutation ~= "None" then mutation else nil,
		Size = if size and size ~= "Normal" then size else nil,
	})
	InventoryService.SyncTools(player)
end

function InventoryService.Remove(player: Player, uid: string): DataService.InvItem?
	local profile = DataService.Get(player)
	local item, index = InventoryService.Find(player, uid)
	if not profile or not item or not index then
		return nil
	end
	table.remove(profile.Data.Inventory, index)
	InventoryService.SyncTools(player)
	return item
end

--------------------------------------------------------------------------------
-- Using items
--------------------------------------------------------------------------------
-- Put a box or donut from the inventory down in your pen (you have to be standing in it).
function InventoryService.Place(player: Player, uid: string)
	local now = os.clock()
	if lastPlace[player] and now - lastPlace[player] < 0.3 then
		return
	end
	lastPlace[player] = now
	local item = InventoryService.Find(player, uid)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not item or not root then
		return
	end
	if not PlotService.IsInOwnPlot(player, root.Position) then
		notify(player, "Go into your pen to put it down!", "error")
		return
	end
	if not PlotService.HasFreeSlot(player) then
		notify(player, "Your pen is full! Pick up a donut or upgrade your base at the sign by the gate.", "error")
		return
	end
	if item.Kind == "Box" then
		if PlotService.AddBox(player, item.Tier or "Basic", item.Size or "Small", item.Area or 1, item.Mutation, root.Position) then
			InventoryService.Remove(player, uid)
		end
	else
		local donutId = item.Id or ""
		if PlotService.AddDonut(player, donutId, item.Level, item.Mutation, item.Size) then
			InventoryService.Remove(player, uid)
			player:SetAttribute("DonutsPlaced", ((player:GetAttribute("DonutsPlaced") :: number?) or 0) + 1) -- (the tutorial watches this)
			local donut = Donuts.ById[donutId]
			notify(player, `{Rarities.DisplayName(donut.Name, item.Mutation, item.Size)} is earning {Format.Money(Economy.DonutIncome(donutId, item.Level or 1, item.Mutation, item.Size))}/s!`, "success")
		end
	end
end

-- Sell a donut from the inventory (the sell stall).
function InventoryService.Sell(player: Player, uid: any): boolean
	if type(uid) ~= "string" then
		return false
	end
	local item = InventoryService.Find(player, uid)
	if not item or item.Kind ~= "Donut" or not item.Id or not Donuts.ById[item.Id] then
		return false
	end
	local price = Economy.SellPrice(item.Id, item.Level or 1, item.Mutation, item.Size)
	InventoryService.Remove(player, uid)
	DataService.AddMoney(player, price, false)
	notify(player, `Sold {InventoryService.ItemName(item)} for {Format.Money(price)}`, "success")
	return true
end

-- Sell every inventory donut of a rarity (or all of them: "All") - the sell stall's quick buttons.
function InventoryService.SellAll(player: Player, rarity: any): number
	local profile = DataService.Get(player)
	if not profile or type(rarity) ~= "string" then
		return 0
	end
	local total, count = 0, 0
	for i = #profile.Data.Inventory, 1, -1 do
		local item = profile.Data.Inventory[i]
		local donut = if item.Kind == "Donut" and item.Id then Donuts.ById[item.Id] else nil
		if donut and (rarity == "All" or donut.Rarity == rarity) then
			total += Economy.SellPrice(donut.Id, item.Level or 1, item.Mutation, item.Size)
			count += 1
			table.remove(profile.Data.Inventory, i)
		end
	end
	if count > 0 then
		InventoryService.SyncTools(player)
		DataService.AddMoney(player, total, false)
		notify(player, `Sold {count} donut{if count == 1 then "" else "s"} for {Format.Money(total)}`, "success")
	end
	return count
end

-- Everything the sell stall can sell: the donuts in your inventory and in your pen, best first.
export type SellItem = { Uid: string?, Slot: number?, Id: string, Level: number, Mutation: string?, Size: string?, Price: number, Income: number }

function InventoryService.SellList(player: Player): { SellItem }
	local profile = DataService.Get(player)
	local list: { SellItem } = {}
	if not profile then
		return list
	end
	local function add(id: string?, level: number?, mutation: string?, size: string?, uid: string?, slot: number?)
		if not id or not Donuts.ById[id] then
			return
		end
		local lvl = level or 1
		table.insert(list, {
			Uid = uid,
			Slot = slot,
			Id = id,
			Level = lvl,
			Mutation = mutation,
			Size = size,
			Price = Economy.SellPrice(id, lvl, mutation, size),
			Income = Economy.DonutIncome(id, lvl, mutation, size),
		})
	end
	for _, item in profile.Data.Inventory do
		if item.Kind == "Donut" then
			add(item.Id, item.Level, item.Mutation, item.Size, item.Uid, nil)
		end
	end
	for key, slot in profile.Data.Slots do
		add(slot.Id, slot.Level, slot.Mutation, slot.Size, nil, tonumber(key))
	end
	table.sort(list, function(a, b)
		return a.Price > b.Price
	end)
	return list
end

function InventoryService.OnCharacterAdded(player: Player)
	-- (the backpack is new on every spawn)
	task.defer(InventoryService.SyncTools, player)
end

function InventoryService.Init()
	PlotService.BoxOpened:Connect(function(player: Player, donutId: string, mutation: string, size: string)
		InventoryService.AddDonut(player, donutId, 1, mutation, size)
	end)
	-- A donut picked up off your base (its "Pick up" prompt)
	PlotService.SetPickupHandler(function(player: Player, slot: DataService.SlotData): boolean
		if InventoryService.IsFull(player) then
			notify(player, "Your inventory is full! Sell some donuts at the sell stall first.", "error")
			return false
		end
		InventoryService.AddDonut(player, slot.Id, slot.Level, slot.Mutation, slot.Size)
		return true
	end)
	Remotes.Function("GetSellList").OnServerInvoke = function(player: Player)
		return InventoryService.SellList(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastPlace[player] = nil
	end)
end

return InventoryService
