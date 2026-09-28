--[[
	Admin panel: opens when you type the admin code in chat (the server spots it, hides it from
	everyone else and replies with AdminPanel). Every button just asks the server
	(Action "Admin" { Cmd, Arg }); the server decides (AdminService).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Areas = require(Shared.Areas)
local Donuts = require(Shared.Donuts)
local Rarities = require(Shared.Rarities)
local Pets = require(Shared.Pets)
local Crates = require(Shared.Crates)
local Events = require(Shared.Events)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local State = require(script.Parent.Parent.State)

local Admin = {}

local modal: Modal.Modal
local scroll: ScrollingFrame
local order = 0

local function command(cmd: string, arg: any?)
	State.Action("Admin", { Cmd = cmd, Arg = arg })
end

local function section(title: string, cellWidth: number?): Frame
	order += 1
	Theme.Label({ Text = title, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = order, Parent = scroll })
	order += 1
	return Theme.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = scroll }, {
		Theme.new("UIGridLayout", { CellSize = UDim2.fromOffset(cellWidth or 128, 40), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
end

local function button(parent: Instance, text: string, color: Color3, onClick: () -> ()): TextButton
	local b = Theme.Button({ Text = text, Color = color, Size = UDim2.new(), Parent = parent })
	b.Activated:Connect(onClick)
	return b
end

local function build()
	-- Money
	local money = section("💵 Money")
	for _, entry in { { Text = "+1K", Amount = 1e3 }, { Text = "+1M", Amount = 1e6 }, { Text = "+1B", Amount = 1e9 }, { Text = "+1T", Amount = 1e12 }, { Text = "+1Qa", Amount = 1e15 }, { Text = "+1Qi", Amount = 1e18 } } do
		button(money, entry.Text, Theme.Colors.Green, function()
			command("Money", entry.Amount)
		end)
	end
	button(money, "x10 money", Theme.Colors.Green, function()
		command("Money", "x10")
	end)

	-- Speed + upgrades
	local speed = section("⚡ Speed & upgrades")
	for _, amount in { 10, 90, 500 } do
		button(speed, `+{amount} speed`, Theme.Colors.Purple, function()
			command("Speed", amount)
		end)
	end
	button(speed, "Reset speed", Theme.Colors.Gray, function()
		command("ResetSpeed")
	end)
	button(speed, "Max treadmill", Theme.Colors.Orange, function()
		command("MaxTreadmill")
	end)
	button(speed, "+1 Rebirth", Theme.Colors.Yellow, function()
		command("Rebirth")
	end)
	button(speed, "+Expansion / 2nd floor", Theme.Colors.Blue, function()
		command("Expand")
	end)

	-- Donuts: pick one, a mutation and a size
	local donutSection = section("🍩 Donuts (pick one, then give or spawn it)", 150)
	local mutations = { "None" }
	for _, mutation in Rarities.Mutations do
		if mutation.Order > 0 then
			table.insert(mutations, mutation.Id)
		end
	end
	local sizes = {}
	for _, size in Rarities.Sizes do
		table.insert(sizes, size.Id)
	end
	local selected = Donuts.List[1].Id
	local mutationIndex, sizeIndex = 1, 2
	local selectedLabel: TextButton
	local mutationButton: TextButton
	local sizeButton: TextButton
	local function refreshSelection()
		local donut = Donuts.ById[selected]
		Theme.SetButtonText(selectedLabel, donut.Name)
		Theme.SetButtonColor(selectedLabel, Rarities.Get(donut.Rarity).Color)
		Theme.SetButtonText(mutationButton, "Mutation: " .. mutations[mutationIndex])
		Theme.SetButtonText(sizeButton, "Size: " .. sizes[sizeIndex])
	end
	selectedLabel = button(donutSection, "", Theme.Colors.Gray, function() end)
	mutationButton = button(donutSection, "", Theme.Colors.Pink, function()
		mutationIndex = mutationIndex % #mutations + 1
		refreshSelection()
	end)
	sizeButton = button(donutSection, "", Theme.Colors.Blue, function()
		sizeIndex = sizeIndex % #sizes + 1
		refreshSelection()
	end)
	button(donutSection, "➕ Give to base", Theme.Colors.Green, function()
		command("Donut", { DonutId = selected, Mutation = mutations[mutationIndex], Size = sizes[sizeIndex] })
	end)
	button(donutSection, "📍 Spawn in lane", Theme.Colors.Orange, function()
		command("SpawnDonut", { DonutId = selected, Mutation = mutations[mutationIndex], Size = sizes[sizeIndex] })
	end)
	local list = section("", 150)
	local sorted = table.clone(Donuts.List)
	table.sort(sorted, function(a, b)
		local ra, rb = Rarities.Get(a.Rarity).Order, Rarities.Get(b.Rarity).Order
		if ra ~= rb then
			return ra > rb
		end
		return a.Income > b.Income
	end)
	for _, donut in sorted do
		local b = button(list, donut.Name, Rarities.Get(donut.Rarity).Color, function()
			selected = donut.Id
			refreshSelection()
		end)
		b.LayoutOrder = Rarities.Get(donut.Rarity).Order * -1000 + donut.Index
	end
	refreshSelection()

	-- Eggs & pets
	local eggs = section("🥚 Eggs & pets", 150)
	for _, egg in Pets.Eggs do
		button(eggs, "+ " .. egg.Name, egg.Accent, function()
			command("Egg", egg.Id)
		end)
	end
	button(eggs, "Hatch all NOW", Theme.Colors.Green, function()
		command("HatchAll")
	end)
	button(eggs, "Clear incubator", Theme.Colors.Gray, function()
		command("ClearEggs")
	end)
	local pets = section("", 150)
	for _, pet in Pets.List do
		button(pets, "+ " .. pet.Name, Pets.Rarity(pet.Rarity).Color, function()
			command("Pet", pet.Id)
		end)
	end

	-- Crates
	local crates = section("🎁 Crates - 👑 owner only (open = free, spawn = in the area you're in)", 150)
	for _, crate in Crates.List do
		button(crates, "Open " .. crate.Name, crate.Color, function()
			command("OpenCrate", crate.Id)
		end)
	end
	for _, crate in Crates.List do
		button(crates, "Spawn " .. crate.Id, crate.Color:Lerp(Color3.new(0, 0, 0), 0.3), function()
			command("SpawnCrate", crate.Id)
		end)
	end

	-- Fun
	local fun = section("✨ Fun", 150)
	button(fun, "👑 🍀 Luck Event", Theme.Colors.Green, function()
		command("Luck")
	end)
	button(fun, "👑 🎲 Random event", Theme.Colors.Orange, function()
		command("Event")
	end)
	button(fun, "🕊 Fly", Theme.Colors.Blue, function()
		command("Fly", "Fly")
	end)
	button(fun, "🧞 Magic carpet", Theme.Colors.Pink, function()
		command("Fly", "Carpet")
	end)
	button(fun, "🚶 Stop flying", Theme.Colors.Gray, function()
		command("Fly", "Off")
	end)
	local god = button(fun, `🛡 {Config.Guard.Name} can't catch me`, Theme.Colors.Purple, function()
		command("GodMode")
	end)
	State.Changed:Connect(function()
		Theme.SetButtonColor(god, if State.Data.GodMode then Theme.Colors.Green else Theme.Colors.Purple)
	end)

	-- Server events (whole server, one at a time)
	local events = section("🌍 Start a server event - 👑 owner only (it changes the game for everyone here)", 150)
	for _, event in Events.List do
		button(events, `{event.Icon} {event.Name}`, event.Color, function()
			command("Event", event.Id)
		end)
	end

	-- Teleport
	local teleport = section("🌀 Teleport to area", 60)
	for _, area in Areas.List do
		button(teleport, tostring(area.Id), area.Trim, function()
			command("Teleport", area.Id)
		end)
	end
end

function Admin.Open()
	if State.Get("Admin") == true then
		modal:Open()
	end
end

function Admin.Init()
	modal = Modal.new("🛠 ADMIN PANEL", Theme.Colors.Red, Vector2.new(720, 520))
	scroll = Theme.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		Parent = modal.Body,
	}, {
		Theme.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		Theme.new("UIPadding", { PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 8) }),
	})
	local built = false
	modal.OnOpen = function()
		if not built then
			built = true
			build()
		end
	end
	Remotes.Event("AdminPanel").OnClientEvent:Connect(function()
		modal:Open()
	end)
end

return Admin
