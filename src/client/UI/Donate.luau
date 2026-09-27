--[[
	Donate window: donation buttons (Robux developer products, Config.Donations) and the Luck Event.
	Donations go on the TOP DONATORS leaderboard (Top 500 window and the board in the hub).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)

local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local State = require(script.Parent.Parent.State)

local Donate = {}

local modal: Modal.Modal

function Donate.Open()
	modal:Open()
end

function Donate.Init()
	modal = Modal.new("💖 SUPPORT THE GAME", Theme.Colors.Pink, Vector2.new(560, 430))
	local body = modal.Body
	local total = Theme.Label({ Text = "", Font = Theme.Font, RichText = true, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 44), StrokeThickness = 1.5, Parent = body })

	local grid = Theme.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 130), Parent = body }, {
		Theme.new("UIGridLayout", { CellSize = UDim2.new(1 / 3, -8, 0, 58), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for order, product in Config.Donations.Products do
		local button = Theme.Button({ Text = `R$ {Format.Commas(product.Amount)}`, Icon = "💖", Color = Theme.Colors.Pink, Size = UDim2.new(), LayoutOrder = order, Parent = grid })
		button.Activated:Connect(function()
			State.Action("Donate", product.Amount)
		end)
	end

	-- Luck Event
	local luck = Theme.new("Frame", { BackgroundColor3 = Theme.Colors.PanelLight, Position = UDim2.fromOffset(0, 196), Size = UDim2.new(1, 0, 0, 150), Parent = body }, {
		Theme.Corner(14),
		Theme.Stroke(3, Color3.fromRGB(60, 200, 90)),
	})
	Theme.Label({ Text = "🍀 LUCK EVENT", TextColor3 = Color3.fromRGB(130, 255, 150), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -20, 0, 32), Position = UDim2.fromOffset(10, 8), Parent = luck })
	Theme.Label({
		Text = `For {Format.Duration(Config.LuckEvent.Duration)} EVERY donut in this server is better: rare donuts x{Config.LuckEvent.RarityLuck}, mutations x{Config.LuckEvent.MutationLuck}, big sizes x{Config.LuckEvent.BigSizeLuck}, eggs x2. Everyone in the server gets it!`,
		Font = Theme.Font, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -20, 0, 50), Position = UDim2.fromOffset(10, 42), StrokeThickness = 1.2, Parent = luck,
	})
	local buy = Theme.Button({ Text = `START IT! R$ {Config.LuckEvent.SuggestedPrice}`, Color = Theme.Colors.Green, Size = UDim2.new(1, -20, 0, 44), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Parent = luck })
	buy.Activated:Connect(function()
		State.Action("BuyLuck")
	end)

	local function refresh()
		local donated = State.Number("Donated")
		total.Text = `Thank you for playing! Donations go on the <b>TOP DONATORS</b> board.\nYou've donated <font color="#ff8ad0"><b>R$ {Format.Commas(donated)}</b></font>`
		local endsAt = workspace:GetAttribute("LuckEndsAt")
		local left = if type(endsAt) == "number" then endsAt - workspace:GetServerTimeNow() else 0
		Theme.SetButtonText(buy, if left > 0 then `ADD 10 MIN! R$ {Config.LuckEvent.SuggestedPrice} ({Format.Duration(left)} left)` else `START IT! R$ {Config.LuckEvent.SuggestedPrice}`)
	end
	modal.OnOpen = refresh
	State.OnAttribute("Donated", function()
		if modal:IsOpen() then
			refresh()
		end
	end)
	workspace:GetAttributeChangedSignal("LuckEndsAt"):Connect(function()
		if modal:IsOpen() then
			refresh()
		end
	end)
end

return Donate
