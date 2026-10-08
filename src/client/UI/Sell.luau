--[[
	Sell window, opened at the sell stall in the lobby (press E there). Lists every donut you have -
	in your inventory and in your pen - with what it earns and what it sells for, best first.
	  * SELL on a row sells that one donut (click twice: the first click asks "SURE?").
	  * The buttons at the top sell every INVENTORY donut of a rarity in one go (also twice).
	    Donuts in your pen are only ever sold one by one, so nothing earning money goes by accident.
	Prices come from the server (Remotes "GetSellList"): Config.SellSeconds of the donut's income.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Donuts = require(Shared.Donuts)
local Rarities = require(Shared.Rarities)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local State = require(script.Parent.Parent.State)

local Sell = {}

type SellItem = { Uid: string?, Slot: number?, Id: string, Level: number, Mutation: string?, Size: string?, Price: number, Income: number }

local CONFIRM_SECONDS = 2.5
local SELL_GREEN = Color3.fromRGB(60, 200, 90)
local SURE_RED = Color3.fromRGB(235, 70, 70)

local modal: Modal.Modal
local list: ScrollingFrame
local header: TextLabel
local quick: Frame
local emptyLabel: TextLabel
local loading = false
local queued = false

-- A button that only acts on the second click (within CONFIRM_SECONDS).
local function confirmButton(props: { Text: string, Color: Color3, Size: UDim2, Parent: Instance, LayoutOrder: number? }, onConfirm: () -> ()): TextButton
	local button = Theme.Button({ Text = props.Text, Color = props.Color, Size = props.Size, Parent = props.Parent, LayoutOrder = props.LayoutOrder })
	local armedAt = 0
	button.Activated:Connect(function()
		local now = os.clock()
		if now - armedAt <= CONFIRM_SECONDS then
			armedAt = 0
			Theme.SetButtonText(button, props.Text)
			Theme.SetButtonColor(button, props.Color)
			onConfirm()
			return
		end
		armedAt = now
		Theme.SetButtonText(button, "SURE?")
		Theme.SetButtonColor(button, SURE_RED)
		task.delay(CONFIRM_SECONDS, function()
			if armedAt == now then
				armedAt = 0
				Theme.SetButtonText(button, props.Text)
				Theme.SetButtonColor(button, props.Color)
			end
		end)
	end)
	return button
end

local function clear(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function row(item: SellItem, order: number)
	local donut = Donuts.ById[item.Id]
	if not donut then
		return
	end
	local rarity = Rarities.Get(donut.Rarity)
	local mutation = Rarities.Mutation(item.Mutation)
	local frame = Theme.new("Frame", {
		Size = UDim2.new(1, -12, 0, 58),
		BackgroundColor3 = Theme.Colors.Outline,
		BackgroundTransparency = 0.55,
		LayoutOrder = order,
		Parent = list,
	}, {
		Theme.Corner(10),
	})
	Theme.Label({
		Text = Rarities.DisplayName(donut.Name, item.Mutation, item.Size),
		TextColor3 = if mutation.Order > 0 then mutation.Color else rarity.Color,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(0.58, -12, 0, 30),
		Position = UDim2.fromOffset(12, 3),
		StrokeThickness = 2,
		Parent = frame,
	})
	local where = if item.Slot then "In your pen" else "Inventory"
	Theme.Label({
		Text = `{rarity.Id} • {where} • {Format.Money(item.Income)}/s`,
		Font = Theme.Font,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(0.58, -12, 0, 20),
		Position = UDim2.fromOffset(12, 33),
		StrokeThickness = 1.5,
		Parent = frame,
	})
	Theme.Label({
		Text = `{Format.Money(item.Price)}`,
		TextColor3 = Theme.Colors.Yellow,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(0.42, -150, 1, -16),
		Position = UDim2.new(0.58, 0, 0, 8),
		StrokeThickness = 2,
		Parent = frame,
	})
	local holder = Theme.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(122, 42), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Parent = frame })
	confirmButton({ Text = "SELL", Color = SELL_GREEN, Size = UDim2.fromScale(1, 1), Parent = holder }, function()
		if item.Uid then
			State.Action("SellInventory", item.Uid)
		elseif item.Slot then
			State.Action("SellSlot", item.Slot)
		end
		frame:Destroy()
		Sell.Refresh(0.4)
	end)
end

local function fill(items: { SellItem })
	clear(list)
	clear(quick)
	Theme.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = quick })
	Theme.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	-- What a "sell all" of each rarity would give (inventory only)
	local byRarity: { [string]: { Count: number, Total: number } } = {}
	local inventoryTotal, inventoryCount = 0, 0
	for _, item in items do
		local donut = Donuts.ById[item.Id]
		if item.Uid and donut then
			local entry = byRarity[donut.Rarity] or { Count = 0, Total = 0 }
			byRarity[donut.Rarity] = entry
			entry.Count += 1
			entry.Total += item.Price
			inventoryTotal += item.Price
			inventoryCount += 1
		end
	end
	local order = 0
	for _, rarity in Rarities.List do
		local entry = byRarity[rarity.Id]
		if entry then
			order += 1
			confirmButton({ Text = `All {rarity.Id} ({entry.Count})`, Color = rarity.Color, Size = UDim2.fromOffset(150, 40), Parent = quick, LayoutOrder = order }, function()
				State.Action("SellAllInventory", rarity.Id)
				Sell.Refresh(0.4)
			end)
		end
	end
	if inventoryCount > 1 then
		confirmButton({ Text = `ALL ({Format.Money(inventoryTotal)})`, Color = SELL_GREEN, Size = UDim2.fromOffset(170, 40), Parent = quick, LayoutOrder = 99 }, function()
			State.Action("SellAllInventory", "All")
			Sell.Refresh(0.4)
		end)
	end
	header.Text = if inventoryCount > 0
		then `Sell all your <b>inventory</b> donuts of a rarity ({inventoryCount} in your inventory, worth <font color="#ffd54a"><b>{Format.Money(inventoryTotal)}</b></font>):`
		else "Donuts in your pen are sold one at a time below. Donuts from boxes land in your <b>inventory</b> first."

	for index, item in items do
		row(item, index)
	end
	emptyLabel.Visible = #items == 0
end

-- Ask the server for the list again (after `delay` seconds: give a sale time to go through).
function Sell.Refresh(delay: number?)
	if loading then
		queued = true
		return
	end
	loading = true
	task.delay(delay or 0, function()
		local ok, items = pcall(function()
			return Remotes.Function("GetSellList"):InvokeServer()
		end)
		loading = false
		if ok and type(items) == "table" and modal:IsOpen() then
			fill(items :: { SellItem })
		end
		if queued then
			queued = false
			Sell.Refresh(0.2)
		end
	end)
end

function Sell.Open()
	modal:Open()
end

-- The stall's "Sell donuts" prompt (made here, so it's only on your screen).
local function addStallPrompt()
	local map = workspace:WaitForChild("Map", 120)
	local hub = map and map:WaitForChild("Hub", 60)
	local stall = hub and hub:WaitForChild("SellStall", 60)
	local part = stall and stall:WaitForChild("PromptPart", 60)
	if not part then
		return
	end
	local prompt = Theme.new("ProximityPrompt", {
		Name = "SellPrompt",
		ActionText = "Sell donuts",
		ObjectText = "Sell Stall",
		KeyboardKeyCode = Enum.KeyCode.E,
		GamepadKeyCode = Enum.KeyCode.ButtonX,
		HoldDuration = 0,
		MaxActivationDistance = 16,
		RequiresLineOfSight = false,
		Parent = part,
	}) :: ProximityPrompt
	prompt.Triggered:Connect(Sell.Open)
end

function Sell.Init()
	modal = Modal.new("Sell Donuts", SELL_GREEN, Vector2.new(780, 560))
	local body = modal.Body
	header = Theme.Label({ Text = "", Font = Theme.Font, RichText = true, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 28), Parent = body })
	quick = Theme.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42), Position = UDim2.fromOffset(0, 32), Parent = body })
	list = Theme.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 1, -84),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 8,
		Parent = body,
	}) :: ScrollingFrame
	emptyLabel = Theme.Label({
		Text = "No donuts to sell yet!\nSteal a box, open it in your pen, and the donut lands in your inventory.",
		Font = Theme.Font,
		Size = UDim2.new(1, 0, 0, 80),
		Position = UDim2.fromOffset(0, 120),
		Visible = false,
		Parent = body,
	})
	modal.OnOpen = function()
		Sell.Refresh(0)
	end
	State.OnAttribute("InventoryCount", function()
		if modal:IsOpen() then
			Sell.Refresh(0.2)
		end
	end)
	task.spawn(addStallPrompt)
end

return Sell
