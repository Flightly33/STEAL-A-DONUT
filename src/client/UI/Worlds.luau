--[[
	Worlds window: every world and what it takes to get there. Anyone can walk through the portals
	in the hub; with the Teleporter game pass you can also jump straight to any world, or to the
	start of any area you're fast enough for.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)

local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local State = require(script.Parent.Parent.State)

local Worlds = {}

local modal: Modal.Modal
local refreshers: { () -> () } = {}

function Worlds.Open()
	modal:Open()
end

local function refreshAll()
	for _, refresh in refreshers do
		refresh()
	end
end

function Worlds.Init()
	modal = Modal.new("🌀 WORLDS & TELEPORT", Theme.Colors.Blue, Vector2.new(760, 540))
	local body = modal.Body
	local header = Theme.Label({ Text = "", Font = Theme.Font, RichText = true, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -210, 0, 44), Parent = body })
	local passButton = Theme.Button({ Text = "🌀 Get Teleporter", Color = Theme.Colors.Green, Size = UDim2.fromOffset(200, 44), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Parent = body })
	passButton.Activated:Connect(function()
		State.Action("BuyPass", "Teleporter")
	end)

	local scroll = Theme.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 1, -52),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 8,
		Parent = body,
	}, {
		Theme.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		Theme.new("UIPadding", { PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 8) }),
	})

	for _, world in Areas.Worlds do
		local card = Theme.new("Frame", { BackgroundColor3 = Theme.Colors.PanelLight, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = world.Id, Parent = scroll }, {
			Theme.Corner(14),
			Theme.Stroke(3, world.Color),
			Theme.new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
			Theme.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		local top = Theme.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 1, Parent = card })
		Theme.Label({ Text = `{world.Icon} WORLD {world.Id}: {string.upper(world.Name)}`, TextColor3 = world.Color:Lerp(Color3.new(1, 1, 1), 0.3), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -170, 0, 30), Parent = top })
		local status = Theme.Label({ Text = "", Font = Theme.Font, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -170, 0, 16), Position = UDim2.fromOffset(0, 30), StrokeThickness = 1.2, Parent = top })
		local go = Theme.Button({ Text = "GO", Color = Theme.Colors.Green, Size = UDim2.fromOffset(160, 42), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Parent = top })
		go.Activated:Connect(function()
			State.Action("TeleportWorld", world.Id)
		end)
		local grid = Theme.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = card }, {
			Theme.new("UIGridLayout", { CellSize = UDim2.new(0.2, -6, 0, 60), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		local areaButtons: { { Button: TextButton, Area: Areas.Area } } = {}
		for _, area in Areas.ByWorld[world.Id] do
			local button = Theme.Button({ Text = `{area.Id}. {area.Name}`, Color = area.Trim, Size = UDim2.new(), LayoutOrder = area.Id, Parent = grid })
			button.Activated:Connect(function()
				State.Action("TeleportArea", area.Id)
			end)
			table.insert(areaButtons, { Button = button, Area = area })
		end

		table.insert(refreshers, function()
			local rebirths = State.Number("Rebirths")
			local hasPass = State.Data.Passes.Teleporter == true
			local unlocked = Economy.WorldUnlocked(world.Id, rebirths, State.Number("UltimateRebirths"))
			local walk = Economy.WalkSpeedFromStat(State.Number("Speed"))
			if unlocked then
				status.Text = if world.Id == 1 then "Your home world" else `Unlocked! Everyone is x{world.WalkMultiplier} faster here`
				status.TextColor3 = Color3.fromRGB(150, 255, 150)
			else
				status.Text = if (world.RequiredUltimate or 0) > 0
					then "🔒 Needs an ULTIMATE REBIRTH (in The Black Hole)"
					else `🔒 Needs {world.RequiredRebirths} rebirth{if world.RequiredRebirths == 1 then "" else "s"} (you have {rebirths})`
				status.TextColor3 = Color3.fromRGB(255, 150, 150)
			end
			Theme.SetButtonText(go, if not unlocked then "🔒 LOCKED" elseif hasPass then "🌀 GO" else "🌀 PASS")
			Theme.SetButtonColor(go, if unlocked and hasPass then Theme.Colors.Green else Theme.Colors.Gray)
			for _, entry in areaButtons do
				local fastEnough = walk + 0.01 >= Economy.WalkSpeedFromStat(Economy.RecommendedSpeed(entry.Area.Id))
				local open = unlocked and fastEnough
				Theme.SetButtonText(entry.Button, if open then `{entry.Area.Id}. {entry.Area.Name}` else `🔒 ⚡{Format.Number(Economy.RecommendedSpeed(entry.Area.Id))}`)
				Theme.SetButtonColor(entry.Button, if open and hasPass then entry.Area.Trim else Theme.Colors.Gray)
			end
		end)
	end

	table.insert(refreshers, function()
		local hasPass = State.Data.Passes.Teleporter == true
		passButton.Visible = not hasPass
		header.Text = if hasPass
			then "🌀 <b>Teleporter active!</b> Jump to any world or area you've unlocked."
			else "Walk through the portals in the hub to travel. The <b>Teleporter</b> pass lets you jump anywhere instantly."
	end)

	modal.OnOpen = refreshAll
	State.Changed:Connect(function()
		if modal:IsOpen() then
			refreshAll()
		end
	end)
	for _, name in { "Speed", "Rebirths" } do
		State.OnAttribute(name, function()
			if modal:IsOpen() then
				refreshAll()
			end
		end)
	end
end

return Worlds
