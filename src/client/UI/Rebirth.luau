--[[
	Rebirth window: requirements for the next rebirth (with progress bars), what you get, what
	resets and what you keep. The button asks for a second click to confirm.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)

local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local State = require(script.Parent.Parent.State)

local Rebirth = {}

local modal: Modal.Modal
local refresh: () -> () = function() end

function Rebirth.Open()
	modal:Open()
end

-- True when the next rebirth is affordable (the HUD button glows).
function Rebirth.IsReady(): boolean
	local nextRebirth = Economy.NextRebirth(State.Number("Rebirths"))
	return nextRebirth ~= nil and State.Number("Speed") >= nextRebirth.Speed and State.Number("Money") >= nextRebirth.Cost
end

local function progressBar(parent: Instance, y: number, color: Color3): (Frame, TextLabel)
	local bar = Theme.new("Frame", { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, y), BackgroundColor3 = Theme.Colors.Outline, Parent = parent }, { Theme.Corner(8), Theme.Stroke(2) })
	local fill = Theme.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = color, Parent = bar }, { Theme.Corner(8) })
	local label = Theme.Label({ Text = "", Font = Theme.Font, Size = UDim2.new(1, -12, 1, -6), Position = UDim2.fromOffset(6, 3), StrokeThickness = 1.8, Parent = bar })
	return fill, label
end

function Rebirth.Init()
	modal = Modal.new("🔄 REBIRTH", Theme.Colors.Orange, Vector2.new(620, 520))
	local body = modal.Body

	local current = Theme.Label({ Text = "", RichText = true, Font = Theme.Font, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 30), Parent = body })
	local reward = Theme.Label({ Text = "", RichText = true, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 36), TextColor3 = Theme.Colors.Yellow, Parent = body })
	local unlock = Theme.Label({ Text = "", Font = Theme.Font, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 72), TextColor3 = Color3.fromRGB(140, 230, 255), StrokeThickness = 1.8, Parent = body })
	local speedFill, speedLabel = progressBar(body, 108, Theme.Colors.Speed)
	local moneyFill, moneyLabel = progressBar(body, 146, Theme.Colors.Green)
	Theme.Label({
		Text = "❌ Resets: your Money and Speed\n✅ Keeps: your donuts, boxes, treadmills, base upgrades, game passes, skins and Index rewards",
		Font = Theme.Font, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(0, 188), StrokeThickness = 1.5, Parent = body,
	})
	local button = Theme.Button({ Text = "REBIRTH", Color = Theme.Colors.Orange, Size = UDim2.new(1, -40, 0, 64), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Parent = body })
	local confirming = false

	refresh = function()
		local rebirths = State.Number("Rebirths")
		local moneyMult = Economy.RebirthMoneyMultiplier(rebirths)
		local speedMult = Economy.RebirthSpeedMultiplier(rebirths)
		current.Text = `Rebirths: <b>{rebirths}</b>   •   💵 Money x{Format.Multiplier(moneyMult)}   •   ⚡ Speed x{Format.Multiplier(speedMult)}`
		local nextRebirth = Economy.NextRebirth(rebirths)
		if not nextRebirth then
			reward.Text = "👑 MAX REBIRTH! You're a donut legend."
			unlock.Text = ""
			speedFill.Size = UDim2.fromScale(1, 1)
			moneyFill.Size = UDim2.fromScale(1, 1)
			speedLabel.Text = "Done"
			moneyLabel.Text = "Done"
			Theme.SetButtonText(button, "MAXED")
			Theme.SetButtonColor(button, Theme.Colors.Gray)
			return
		end
		reward.Text = `REBIRTH {rebirths + 1}: 💵 x{Format.Multiplier(Economy.RebirthMoneyMultiplier(rebirths + 1))} money  ⚡ x{Format.Multiplier(Economy.RebirthSpeedMultiplier(rebirths + 1))} speed`
		unlock.Text = "⚠ Your Speed goes back to 0, so you start again from Biome 1 - but your treadmill is faster for good"

		local speed, money = State.Number("Speed"), State.Number("Money")
		speedFill.Size = UDim2.fromScale(math.clamp(speed / nextRebirth.Speed, 0, 1), 1)
		moneyFill.Size = UDim2.fromScale(math.clamp(money / nextRebirth.Cost, 0, 1), 1)
		speedLabel.Text = `⚡ Speed {Format.Number(speed)} / {Format.Number(nextRebirth.Speed)}`
		moneyLabel.Text = `💵 Money {Format.Money(money)} / {Format.Money(nextRebirth.Cost)}`
		if Rebirth.IsReady() then
			Theme.SetButtonText(button, if confirming then "ARE YOU SURE? CLICK AGAIN" else "🔄 REBIRTH NOW")
			Theme.SetButtonColor(button, if confirming then Theme.Colors.Red else Theme.Colors.Green)
		else
			Theme.SetButtonText(button, "NOT READY YET")
			Theme.SetButtonColor(button, Theme.Colors.Gray)
		end
	end

	button.Activated:Connect(function()
		if not Rebirth.IsReady() then
			return
		end
		if confirming then
			confirming = false
			State.Action("Rebirth")
			modal:Close()
		else
			confirming = true
			refresh()
			task.delay(4, function()
				confirming = false
				refresh()
			end)
		end
	end)

	for _, name in { "Speed", "Money", "Rebirths" } do
		State.OnAttribute(name, function()
			if modal:IsOpen() then
				refresh()
			end
		end)
	end
	modal.OnOpen = function()
		confirming = false
		refresh()
	end
end

return Rebirth
