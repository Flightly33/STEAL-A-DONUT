--[[
	Base size window: what the base code ("ender=rich" in chat) unlocks - just the BIGGER / SMALLER
	base buttons, nothing else from the admin panel. (Donuts that don't fit a smaller base are kept
	safe and come back when it's bigger again.) It opens by itself the moment the code is typed, and
	again from the 🏢 BASE button on the HUD. Bases grow up to Config.Admin.MaxSlots donuts (as big
	as a pen can get on its plot: see Config). The server checks every press.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Economy)

local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local State = require(script.Parent.Parent.State)

local BaseSize = {}

local modal: Modal.Modal

function BaseSize.Open()
	modal:Open()
end

function BaseSize.Init()
	modal = Modal.new("🏢 BIGGER BASE", Theme.Colors.Blue, Vector2.new(480, 300))
	local body = modal.Body
	local info = Theme.Label({
		Text = "",
		Font = Theme.Font,
		RichText = true,
		Size = UDim2.new(1, 0, 0, 96),
		StrokeThickness = 1.5,
		Parent = body,
	})
	local one = Theme.Button({ Text = "BIGGER", Icon = "🏢", Color = Theme.Colors.Green, Size = UDim2.fromOffset(140, 66), Position = UDim2.new(0.5, -216, 0, 112), Parent = body })
	local smaller = Theme.Button({ Text = "SMALLER", Color = Theme.Colors.Orange, Size = UDim2.fromOffset(140, 66), Position = UDim2.new(0.5, -70, 0, 112), Parent = body })
	local max = Theme.Button({ Text = "MAX SIZE", Color = Theme.Colors.Blue, Size = UDim2.fromOffset(140, 66), Position = UDim2.new(0.5, 76, 0, 112), Parent = body })
	local top = Economy.AdminMaxBaseLevel()
	one.Activated:Connect(function()
		State.Action("GrowBase", 1)
	end)
	smaller.Activated:Connect(function()
		State.Action("GrowBase", -1)
	end)
	max.Activated:Connect(function()
		State.Action("GrowBase", top)
	end)

	State.OnAttribute("BaseLevel", function()
		local level = math.max(State.Number("BaseLevel"), 1)
		local full = level >= top
		info.Text = `Your base holds <font color="#8dff6a"><b>{Economy.SlotCount(level)}</b></font> donuts\n`
			.. (if full then "That's as big as a base gets!" else `<font size="20">Grow it to hold up to {Economy.SlotCount(top)}</font>`)
		Theme.SetButtonColor(one, if full then Theme.Colors.Gray else Theme.Colors.Green)
		Theme.SetButtonColor(max, if full then Theme.Colors.Gray else Theme.Colors.Blue)
		Theme.SetButtonColor(smaller, if level <= 1 then Theme.Colors.Gray else Theme.Colors.Orange)
	end)
	-- Open it the moment the code is typed
	local opened = false
	State.OnAttribute("SizeAccess", function(value)
		if value == true and not opened then
			opened = true
			modal:Open()
		end
	end)
end

return BaseSize
