--[[
	SkipOdds: "Open now" on a box in your pen. The donut inside is only picked when the box opens,
	so opening it for Robux is buying a random item, and Roblox's rules want every donut it can
	give, with its chance, shown BEFORE the purchase. The server sends the box here
	(ProductService.SkipBox: only where paid random items are allowed); BUY asks the server for
	the purchase (the "ConfirmSkip" action).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boxes = require(Shared.Boxes)
local Config = require(Shared.Config)
local Donuts = require(Shared.Donuts)
local Format = require(Shared.Format)
local Rarities = require(Shared.Rarities)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local State = require(script.Parent.Parent.State)

local SkipOdds = {}

-- Every donut a box from `area` of this tier can give, most likely first (adds up to 100%).
function SkipOdds.Lines(area: number, tierId: string): { string }
	local pool = Donuts.ByBox[area] and Donuts.ByBox[area][tierId] or {}
	local list = table.clone(pool)
	table.sort(list, function(a, b)
		return Donuts.Chance(a) > Donuts.Chance(b)
	end)
	local lines = {}
	for _, donut in list do
		local rarity = Rarities.Get(donut.Rarity)
		table.insert(lines, `<font color="#{rarity.Color:ToHex()}">{donut.Name}</font> ({rarity.Id}): <b>{Format.Odds(Donuts.Chance(donut))}</b>`)
	end
	return lines
end

function SkipOdds.Init()
	local modal = Modal.new("Open It Now?", Theme.Colors.Green, Vector2.new(560, 470))
	local body = modal.Body
	local heading = Theme.Label({ Text = "", Font = Theme.Font, RichText = true, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 50), StrokeThickness = 1.5, Parent = body })
	local scroll = Theme.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 1, -120),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 8,
		Parent = body,
	})
	local odds = Theme.Label({ Text = "", Font = Theme.Font, RichText = true, TextScaled = false, TextSize = 20, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -12, 0, 0), StrokeThickness = 1.2, Parent = scroll })
	local buy = Theme.Button({ Text = `BUY  R$ {Config.Boxes.SkipPrice}`, Color = Theme.Colors.Green, Size = UDim2.new(0.6, -6, 0, 52), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Parent = body })
	local cancel = Theme.Button({ Text = "No thanks", Color = Theme.Colors.Gray, Size = UDim2.new(0.4, -6, 0, 52), AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Parent = body })
	local slot: number? = nil
	buy.Activated:Connect(function()
		if slot then
			State.Action("ConfirmSkip", slot)
		end
		modal:Close()
	end)
	cancel.Activated:Connect(function()
		modal:Close()
	end)
	Remotes.Event("SkipOdds").OnClientEvent:Connect(function(info: any)
		if type(info) ~= "table" or type(info.Slot) ~= "number" or type(info.Area) ~= "number" or type(info.Tier) ~= "string" then
			return
		end
		slot = info.Slot
		local mutation = Rarities.Mutation(info.Mutation)
		local name = Rarities.DisplayName(Boxes.DisplayName(info.Tier, info.Size), mutation.Id, nil)
		heading.Text = `Open your <b>{name}</b> right away. Its size and mutation are already set; the donut inside is ONE of these:`
		odds.Text = table.concat(SkipOdds.Lines(info.Area, info.Tier), "\n")
		modal:Open()
	end)
end

return SkipOdds
