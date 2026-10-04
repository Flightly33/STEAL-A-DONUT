--[[
	Admin panel: opens when you type the admin code in chat (the server spots it, hides it from
	everyone else and replies with AdminPanel). Every button just asks the server
	(Action "Admin" { Cmd, Arg }); the server decides (AdminService).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Areas = require(Shared.Areas)
local Boxes = require(Shared.Boxes)
local Donuts = require(Shared.Donuts)
local Rarities = require(Shared.Rarities)
local Pets = require(Shared.Pets)
local Crates = require(Shared.Crates)
local Events = require(Shared.Events)
local Format = require(Shared.Format)
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

-- HD Admin-style commands: pick who (me / everyone / others / a player), type a value if the
-- command needs one, press the command.
local function buildHD()
	order += 1
	Theme.Label({ Text = "👥 PLAYER COMMANDS (HD Admin)", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = order, Parent = scroll })
	order += 1
	local row = Theme.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = order, Parent = scroll })
	local choices: { { Label: string, Target: any } } = {}
	local choice = 1
	local targetButton = Theme.Button({ Text = "", Color = Theme.Colors.Blue, Size = UDim2.fromOffset(250, 40), Parent = row })
	local function refreshChoices()
		local current = choices[choice]
		choices = { { Label = "🙋 Me", Target = "me" }, { Label = "🌍 Everyone", Target = "all" }, { Label = "👥 Everyone else", Target = "others" } }
		for _, other in Players:GetPlayers() do
			if other ~= Players.LocalPlayer then
				table.insert(choices, { Label = "👤 " .. other.DisplayName, Target = other.UserId })
			end
		end
		choice = 1
		for i, entry in choices do
			if current and entry.Target == current.Target then
				choice = i
			end
		end
		Theme.SetButtonText(targetButton, "Target: " .. choices[choice].Label .. "  ▸")
	end
	targetButton.Activated:Connect(function()
		refreshChoices()
		choice = choice % #choices + 1
		Theme.SetButtonText(targetButton, "Target: " .. choices[choice].Label .. "  ▸")
	end)
	Players.PlayerAdded:Connect(refreshChoices)
	Players.PlayerRemoving:Connect(function()
		task.defer(refreshChoices)
	end)
	refreshChoices()
	local valueBox = Theme.new("TextBox", {
		Size = UDim2.new(1, -262, 0, 40), Position = UDim2.fromOffset(262, 0),
		BackgroundColor3 = Theme.Colors.PanelLight, TextColor3 = Color3.new(1, 1, 1), PlaceholderText = "value: number or message",
		PlaceholderColor3 = Color3.fromRGB(170, 170, 190), Text = "", Font = Theme.Font, TextScaled = true, ClearTextOnFocus = false, Parent = row,
	}, { Theme.Corner(10), Theme.Stroke(2) })
	local function run(action: string)
		command("HD", { Action = action, Target = choices[choice].Target, Value = if valueBox.Text ~= "" then (tonumber(valueBox.Text) or valueBox.Text) else nil })
	end
	type Entry = { Text: string, Action: string, Color: Color3, Cmd: string? }
	local groups: { { Title: string, Entries: { Entry } } } = {
		{ Title = "Health", Entries = {
			{ Text = "💀 Kill", Action = "kill", Color = Theme.Colors.Red }, { Text = "🔄 Respawn", Action = "respawn", Color = Theme.Colors.Gray },
			{ Text = "❤️ Heal", Action = "heal", Color = Theme.Colors.Green }, { Text = "😇 God", Action = "god", Color = Theme.Colors.Yellow },
			{ Text = "🙂 Ungod", Action = "ungod", Color = Theme.Colors.Gray }, { Text = "🛡 Forcefield", Action = "ff", Color = Theme.Colors.Blue },
			{ Text = "❌ Unforcefield", Action = "unff", Color = Theme.Colors.Gray }, { Text = "💥 Explode", Action = "explode", Color = Theme.Colors.Orange },
		} },
		{ Title = "Control", Entries = {
			{ Text = "🧊 Freeze", Action = "freeze", Color = Theme.Colors.Blue }, { Text = "🔥 Thaw", Action = "thaw", Color = Theme.Colors.Orange },
			{ Text = "🔒 Jail", Action = "jail", Color = Theme.Colors.Gray }, { Text = "🔓 Unjail", Action = "unjail", Color = Theme.Colors.Green },
			{ Text = "🧲 Bring", Action = "bring", Color = Theme.Colors.Purple }, { Text = "🚀 Go to", Action = "goto", Color = Theme.Colors.Purple },
			{ Text = "🌪 Fling", Action = "fling", Color = Theme.Colors.Red }, { Text = "🪑 Sit", Action = "sit", Color = Theme.Colors.Gray },
		} },
		{ Title = "Body (value = number)", Entries = {
			{ Text = "🏃 Speed", Action = "speed", Color = Theme.Colors.Green }, { Text = "🚶 Normal speed", Action = "unspeed", Color = Theme.Colors.Gray },
			{ Text = "🦘 Jump power", Action = "jump", Color = Theme.Colors.Green }, { Text = "📏 Size", Action = "size", Color = Theme.Colors.Purple },
			{ Text = "👻 Invisible", Action = "invisible", Color = Theme.Colors.Gray }, { Text = "👀 Visible", Action = "visible", Color = Theme.Colors.Blue },
			{ Text = "🧱 Noclip", Action = "noclip", Color = Theme.Colors.Purple }, { Text = "🧍 Clip", Action = "clip", Color = Theme.Colors.Gray },
		} },
		{ Title = "Effects", Entries = {
			{ Text = "✨ Sparkles", Action = "sparkles", Color = Theme.Colors.Yellow }, { Text = "🔥 Fire", Action = "fire", Color = Theme.Colors.Orange },
			{ Text = "💨 Smoke", Action = "smoke", Color = Theme.Colors.Gray }, { Text = "🧹 Remove effects", Action = "unfx", Color = Theme.Colors.Gray },
		} },
		{ Title = "🛡 Admin access (owner only; saved, the code stops working for them)", Entries = {
			{ Text = "🚫 Remove admin", Action = "", Cmd = "RevokeAdmin", Color = Theme.Colors.Red },
			{ Text = "✅ Give admin back", Action = "", Cmd = "RestoreAdmin", Color = Theme.Colors.Green },
		} },
		{ Title = "Moderation", Entries = {
			{ Text = "👢 Kick", Action = "kick", Color = Theme.Colors.Red }, { Text = "⛔ Ban (this server)", Action = "ban", Color = Theme.Colors.Red },
			{ Text = "✅ Unban all", Action = "unbanall", Color = Theme.Colors.Green },
		} },
		{ Title = "Server (value = message / hour / gravity)", Entries = {
			{ Text = "📢 Announce", Action = "announce", Color = Theme.Colors.Yellow }, { Text = "🕒 Time of day", Action = "time", Color = Theme.Colors.Blue },
			{ Text = "🌙 Gravity", Action = "gravity", Color = Theme.Colors.Purple }, { Text = "🛑 Shut down", Action = "shutdown", Color = Theme.Colors.Red },
		} },
	}
	for _, group in groups do
		local grid = section(group.Title, 150)
		for _, entry in group.Entries do
			button(grid, entry.Text, entry.Color, function()
				if entry.Cmd then
					command(entry.Cmd, choices[choice].Target)
				else
					run(entry.Action)
				end
			end)
		end
	end
end

local function build()
	buildHD()
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
	for _, amount in { 1e3, 1e5, 1e7, 1e9 } do
		button(speed, `+{Format.Number(amount)} speed`, Theme.Colors.Purple, function()
			command("Speed", amount)
		end)
	end
	button(speed, "Reset speed", Theme.Colors.Gray, function()
		command("ResetSpeed")
	end)
	button(speed, "Max treadmill", Theme.Colors.Orange, function()
		command("MaxTreadmill")
	end)
	button(speed, "+Bigger base", Theme.Colors.Blue, function()
		command("Expand")
	end)

	-- Your base
	local base = section("🏠 Your base", 170)
	button(base, "💸 Reset money", Theme.Colors.Gray, function()
		command("ResetMoney")
	end)
	button(base, "🍩 Clear all donuts", Theme.Colors.Gray, function()
		command("ClearDonuts")
	end)
	-- Only the game's owner sees these: bases past the biggest you can buy, and the owner's own skin
	local ownerButtons = {
		button(base, "👑 Bigger base", Theme.Colors.Yellow, function()
			command("GrowBase", 1)
		end),
		button(base, "👑 Max base", Theme.Colors.Yellow, function()
			command("GrowBase", 99)
		end),
		button(base, "👑 Smaller base", Theme.Colors.Orange, function()
			command("GrowBase", -1)
		end),
		button(base, "👑 Owner skin", Theme.Colors.Purple, function()
			command("OwnerSkin")
		end),
		button(base, "👑 🌌 ETERNAL STORM", Color3.fromRGB(150, 60, 230), function()
			command("EternalStorm")
		end),
	}
	State.OnAttribute("AdminOwner", function(value)
		for _, b in ownerButtons do
			b.Visible = value == true
		end
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

	-- Boxes: pick a box (tier, size, mutation, biome), then give it or drop it
	local boxSection = section("📦 Boxes (pick one, then give or drop it)", 150)
	local tiers, boxSizes = {}, {}
	for _, tier in Boxes.Tiers do
		table.insert(tiers, tier.Id)
	end
	for _, size in Boxes.Sizes do
		table.insert(boxSizes, size.Id)
	end
	local tierIndex, boxSizeIndex, boxMutationIndex, biome = 2, 1, 1, 2
	local tierButton: TextButton
	local boxSizeButton: TextButton
	local boxMutationButton: TextButton
	local biomeButton: TextButton
	local function refreshBox()
		local tier = Boxes.Tier(tiers[tierIndex])
		Theme.SetButtonText(tierButton, tier.Name)
		Theme.SetButtonColor(tierButton, tier.Color)
		Theme.SetButtonText(boxSizeButton, "Size: " .. Boxes.Size(boxSizes[boxSizeIndex]).Name)
		Theme.SetButtonText(boxMutationButton, "Mutation: " .. mutations[boxMutationIndex])
		Theme.SetButtonText(biomeButton, `Biome {biome}: {Areas.List[biome].Name}`)
		Theme.SetButtonColor(biomeButton, Areas.List[biome].Trim)
	end
	tierButton = button(boxSection, "", Theme.Colors.Gray, function()
		tierIndex = tierIndex % #tiers + 1
		refreshBox()
	end)
	boxSizeButton = button(boxSection, "", Theme.Colors.Blue, function()
		boxSizeIndex = boxSizeIndex % #boxSizes + 1
		refreshBox()
	end)
	boxMutationButton = button(boxSection, "", Theme.Colors.Pink, function()
		boxMutationIndex = boxMutationIndex % #mutations + 1
		refreshBox()
	end)
	biomeButton = button(boxSection, "", Theme.Colors.Gray, function()
		biome = biome % #Areas.List + 1
		refreshBox()
	end)
	button(boxSection, "➕ To inventory", Theme.Colors.Green, function()
		command("Box", { Tier = tiers[tierIndex], Size = boxSizes[boxSizeIndex], Mutation = mutations[boxMutationIndex], Area = biome })
	end)
	button(boxSection, "📍 Drop here", Theme.Colors.Orange, function()
		command("SpawnBox", { Tier = tiers[tierIndex], Size = boxSizes[boxSizeIndex], Mutation = mutations[boxMutationIndex] })
	end)
	button(boxSection, "⏩ Open my boxes", Theme.Colors.Purple, function()
		command("OpenBoxes")
	end)
	button(boxSection, "🔄 New boxes everywhere", Theme.Colors.Yellow, function()
		command("ResetBoxes")
	end)
	refreshBox()

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
	local crates = section("🎁 Crates (open = free, spawn = in the area you're in)", 150)
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
	button(fun, "🍀 Luck Event", Theme.Colors.Green, function()
		command("Luck")
	end)
	button(fun, "🎲 Random event", Theme.Colors.Orange, function()
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
	local events = section("🌍 Start a server event (for the whole server)", 150)
	for _, event in Events.List do
		if not event.OwnerOnly then
			button(events, `{event.Icon} {event.Name}`, event.Color, function()
				command("Event", event.Id)
			end)
		end
	end

	-- Teleport
	local teleport = section("🌀 Teleport to biome", 60)
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
	-- Admin taken away: close the panel
	State.OnAttribute("Admin", function(value)
		if value ~= true and modal:IsOpen() then
			modal:Close()
		end
	end)
end

return Admin
