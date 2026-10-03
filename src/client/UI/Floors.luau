--[[
	Floors window: what the floors code ("ender=rich" in chat) unlocks - just the +1 / +10 FLOORS
	buttons, nothing else from the admin panel. It opens by itself the moment the code is typed,
	and again from the 🏢 FLOORS button on the HUD. Bases go up to Config.Admin.MaxFloors floors
	(the most Roblox can build: see Config). The server checks every press.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Layout = require(Shared.Layout)

local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local State = require(script.Parent.Parent.State)

local Floors = {}

local modal: Modal.Modal

function Floors.Open()
	modal:Open()
end

function Floors.Init()
	modal = Modal.new("🏢 FLOORS", Theme.Colors.Blue, Vector2.new(480, 300))
	local body = modal.Body
	local info = Theme.Label({
		Text = "",
		Font = Theme.Font,
		RichText = true,
		Size = UDim2.new(1, 0, 0, 96),
		StrokeThickness = 1.5,
		Parent = body,
	})
	local one = Theme.Button({ Text = "+1 FLOOR", Icon = "🏢", Color = Theme.Colors.Green, Size = UDim2.fromOffset(200, 66), Position = UDim2.new(0.5, -206, 0, 112), Parent = body })
	local ten = Theme.Button({ Text = "+10 FLOORS", Icon = "🏢", Color = Theme.Colors.Blue, Size = UDim2.fromOffset(200, 66), Position = UDim2.new(0.5, 6, 0, 112), Parent = body })
	one.Activated:Connect(function()
		State.Action("AddFloors", 1)
	end)
	ten.Activated:Connect(function()
		State.Action("AddFloors", 10)
	end)

	local max = math.max(Layout.MaxFloors, Config.Admin.MaxFloors)
	State.OnAttribute("Floors", function()
		local floors = math.max(State.Number("Floors"), 1)
		local full = floors >= max
		info.Text = `Your base has <font color="#8dff6a"><b>{floors}</b></font> floor{if floors == 1 then "" else "s"} ({Layout.SlotsForFloors(floors)} stands)\n`
			.. (if full then "That's the most Roblox can build!" else `<font size="20">Build up to {max} floors</font>`)
		for _, button in { one, ten } do
			Theme.SetButtonColor(button, if full then Theme.Colors.Gray else (if button == one then Theme.Colors.Green else Theme.Colors.Blue))
		end
	end)
	-- Open it the moment the code is typed
	local opened = false
	State.OnAttribute("FloorAccess", function(value)
		if value == true and not opened then
			opened = true
			modal:Open()
		end
	end)
end

return Floors
