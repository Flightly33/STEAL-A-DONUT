--[[
	Tutorial: a short "how to play" window, shown once on a player's first join (saved as
	SeenTutorial) and any time from Settings > How to play.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local State = require(script.Parent.Parent.State)

local Tutorial = {}

local PAGES = {
	{ Icon = "🍩", Title = "GRAB DONUTS", Text = "Run into the donut lane, walk up to a donut and press Steal to grab it." },
	{ Icon = "🏃", Title = "RUN HOME!", Text = `{Config.Guard.Name} chases anyone carrying a donut. Get it back to your base before you get caught!` },
	{ Icon = "💰", Title = "GET RICH", Text = "Donuts on your base make money every second. Train on the treadmill to get faster, then go for rarer donuts." },
	{ Icon = "😈", Title = "STEAL & DEFEND", Text = "Sneak into other bases and steal their donuts. Use a Base Lock to keep yours safe!" },
}

local modal: Modal.Modal
local page = 1
local render: () -> ()

function Tutorial.Open()
	page = 1
	render()
	modal:Open()
end

function Tutorial.Init()
	modal = Modal.new("❓ HOW TO PLAY", Theme.Colors.Blue, Vector2.new(460, 330))
	local body = modal.Body

	local icon = Theme.Label({ Text = "", TextSize = 56, TextScaled = false, Size = UDim2.new(1, 0, 0, 64), Parent = body })
	local title = Theme.Label({ Text = "", Font = Theme.Title, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 66), Parent = body })
	local text = Theme.Label({ Text = "", Font = Theme.Font, TextScaled = false, TextSize = 20, TextWrapped = true, Size = UDim2.new(1, -20, 0, 70), Position = UDim2.fromOffset(10, 104), StrokeThickness = 1.5, Parent = body })
	local dots = Theme.Label({ Text = "", Font = Theme.Font, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 178), StrokeThickness = 1, Parent = body })
	local back = Theme.Button({ Text = "◀ BACK", Color = Theme.Colors.Gray, Size = UDim2.new(0.5, -6, 0, 46), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Parent = body })
	local nextButton = Theme.Button({ Text = "", Color = Theme.Colors.Green, Size = UDim2.new(0.5, -6, 0, 46), AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Parent = body })

	render = function()
		local p = PAGES[page]
		icon.Text = p.Icon
		title.Text = p.Title
		text.Text = p.Text
		local marks = {}
		for i = 1, #PAGES do
			table.insert(marks, if i == page then "●" else "○")
		end
		dots.Text = table.concat(marks, " ")
		back.Visible = page > 1
		Theme.SetButtonText(nextButton, if page < #PAGES then "NEXT ▶" else "LET'S GO! 🍩")
	end

	back.Activated:Connect(function()
		page = math.max(1, page - 1)
		render()
	end)
	nextButton.Activated:Connect(function()
		if page < #PAGES then
			page += 1
			render()
		else
			modal:Close()
		end
	end)

	-- First join: show it once the saved data arrives, and remember it's been seen
	local checked = false
	State.Changed:Connect(function(snapshot)
		if checked then
			return
		end
		checked = true
		if snapshot.SeenTutorial == false then
			State.Action("SeenTutorial")
			Tutorial.Open()
		end
	end)
	render()
end

return Tutorial
