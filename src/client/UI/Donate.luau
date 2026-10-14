--[[
	Donate: the tips section at the bottom of the Shop (Robux developer products, Config.Donations).
	Tips go on the TOP DONATORS leaderboard (the board in the hub) and each one gives a title shown
	above your head and in chat (your biggest tip's title is the one you keep). (The Luck Event is
	in the Shop's Boosts.)

	  Donate.Build(section) -> refresh   fills the Shop's Donate section
	  Donate.Open()                       opens the Shop at it
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)

local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local Donate = {}

local opener: (() -> ())? = nil

function Donate.SetOpener(open: () -> ())
	opener = open
end

function Donate.Open()
	if opener then
		opener()
	end
end

function Donate.Build(section: Frame): () -> ()
	local about = Theme.Card(section, 1, Theme.Colors.Pink)
	about.Size = UDim2.new(1, -10, 0, 70)
	local total = Theme.Label({ Name = "Total", Text = "", Font = Theme.Font, RichText = true, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -20, 1, -16), Position = UDim2.fromOffset(10, 10), StrokeThickness = 1.5, Parent = about })

	local count = #Config.Donations.Products
	local rows = math.ceil(count / 3)
	local grid = Theme.new("Frame", { Name = "Tips", BackgroundTransparency = 1, Size = UDim2.new(1, -10, 0, rows * 74), LayoutOrder = 2, Parent = section }, {
		Theme.new("UIGridLayout", { CellSize = UDim2.new(1 / 3, -8, 0, 66), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for order, product in Config.Donations.Products do
		local button = Theme.Button({ Text = `R$ {Format.Commas(product.Amount)}`, Icon = "heart", Color = Theme.Colors.Pink, Size = UDim2.new(), LayoutOrder = order, Parent = grid })
		-- the title this tip gives, under the price
		Theme.Label({
			Text = product.Title, Font = Theme.Font, TextColor3 = product.Color, StrokeThickness = 1.5,
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.new(1, -8, 0, 16), ZIndex = 5, Parent = button,
		})
		button.Activated:Connect(function()
			State.Action("Donate", product.Amount)
		end)
	end

	local function refresh()
		local donated = State.Number("Donated")
		local title = game:GetService("Players").LocalPlayer:GetAttribute("DonorTitle")
		local titleText = if type(title) == "string" then `  •  Your title: <b>{title}</b>` else "  •  Every tip gives a title!"
		total.Text = `Tips are a thank-you to the developer: you get the title and a spot on the <b>TOP DONATORS</b> board, nothing else.\nYou've tipped <font color="#ff8ad0"><b>R$ {Format.Commas(donated)}</b></font>{titleText}`
	end
	State.OnAttribute("Donated", refresh)
	refresh()
	return refresh
end

return Donate
