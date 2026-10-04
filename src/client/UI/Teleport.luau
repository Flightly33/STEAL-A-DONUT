--[[
	Teleport window: every biome and the Speed it needs. With the Teleporter game pass you can jump
	straight to the start of any biome you're fast enough for (or home); everyone else sees what's
	ahead of them and what it takes to get there.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Areas)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)

local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local State = require(script.Parent.Parent.State)

local Teleport = {}

local modal: Modal.Modal
local refreshers: { () -> () } = {}

function Teleport.Open()
	modal:Open()
end

local function refreshAll()
	for _, refresh in refreshers do
		refresh()
	end
end

function Teleport.Init()
	modal = Modal.new("🌀 BIOMES & TELEPORT", Theme.Colors.Blue, Vector2.new(760, 540))
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
		Theme.new("UIGridLayout", { CellSize = UDim2.new(0.25, -8, 0, 74), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		Theme.new("UIPadding", { PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 8) }),
	})

	local home = Theme.Button({ Text = "🏠 Home", Color = Theme.Colors.Green, Size = UDim2.new(), LayoutOrder = 0, Parent = scroll })
	home.Activated:Connect(function()
		State.Action("TeleportHome")
	end)
	for _, area in Areas.List do
		local button = Theme.Button({ Text = "", Color = area.Trim, Size = UDim2.new(), LayoutOrder = area.Id, Parent = scroll })
		button.Activated:Connect(function()
			State.Action("TeleportArea", area.Id)
		end)
		table.insert(refreshers, function()
			local hasPass = State.Data.Passes.Teleporter == true
			local open = Economy.CanEnter(area.Id, State.Number("Speed"))
			local need = if area.RecommendedSpeed > 0 then `⚡{Format.Number(area.RecommendedSpeed)}` else "start here"
			Theme.SetButtonText(button, if open then `{area.Id}. {area.Name}\n{need}` else `🔒 {area.Id}. {area.Name}\nneeds {need}`)
			Theme.SetButtonColor(button, if open and hasPass then area.Trim else Theme.Colors.Gray)
		end)
	end

	table.insert(refreshers, function()
		local hasPass = State.Data.Passes.Teleporter == true
		passButton.Visible = not hasPass
		header.Text = if hasPass
			then "🌀 <b>Teleporter active!</b> Jump to any biome you're fast enough for."
			else "Every biome needs more Speed to get in. The <b>Teleporter</b> pass lets you jump to any of them instantly."
	end)

	modal.OnOpen = refreshAll
	State.Changed:Connect(function()
		if modal:IsOpen() then
			refreshAll()
		end
	end)
	State.OnAttribute("Speed", function()
		if modal:IsOpen() then
			refreshAll()
		end
	end)
end

return Teleport
