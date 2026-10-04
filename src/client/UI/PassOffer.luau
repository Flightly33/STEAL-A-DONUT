--[[
	PassOffer: during a player's first hour of play (Config.PassOffer), a popup offers the money
	pass once per session: a few minutes after joining, and only when they're not running with a
	donut or looking at another window.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local State = require(script.Parent.Parent.State)

local PassOffer = {}

local player = Players.LocalPlayer

local function findPass(): Config.GamePass?
	for _, pass in Config.GamePasses do
		if pass.Key == Config.PassOffer.PassKey then
			return pass
		end
	end
	return nil
end

local function playTime(): number
	local value = player:GetAttribute("PlayTime")
	return if type(value) == "number" then value else 0
end

function PassOffer.Init()
	local pass = findPass()
	if not pass then
		return
	end
	local offer = pass
	local modal = Modal.new("🎁 SPECIAL OFFER", Theme.Colors.Green, Vector2.new(460, 340))
	local body = modal.Body
	Theme.Label({ Text = "💵", TextScaled = false, TextSize = 64, Size = UDim2.new(1, 0, 0, 70), Parent = body })
	Theme.Label({ Text = `{string.upper(offer.Name)} FOREVER!`, Font = Theme.Title, TextColor3 = Color3.fromRGB(120, 255, 120), Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 72), StrokeThickness = 3, Parent = body })
	Theme.Label({
		Text = `Every donut on your base earns {offer.Multiplier}x money - for good!`,
		Font = Theme.Font, TextScaled = false, TextSize = 20, TextWrapped = true,
		Size = UDim2.new(1, -20, 0, 56), Position = UDim2.fromOffset(10, 118), StrokeThickness = 1.5, Parent = body,
	})
	local buy = Theme.Button({ Text = `BUY  R$ {offer.SuggestedPrice}`, Color = Theme.Colors.Green, Size = UDim2.new(0.6, -6, 0, 52), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Parent = body })
	local later = Theme.Button({ Text = "No thanks", Color = Theme.Colors.Gray, Size = UDim2.new(0.4, -6, 0, 52), AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Parent = body })
	buy.Activated:Connect(function()
		State.Action("BuyPass", offer.Key)
		modal:Close()
	end)
	later.Activated:Connect(function()
		modal:Close()
	end)
	-- Show the real price once Roblox tells us
	task.spawn(function()
		if offer.GamePassId > 0 then
			local ok, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, offer.GamePassId, Enum.InfoType.GamePass)
			if ok and info and info.PriceInRobux then
				Theme.SetButtonText(buy, `BUY  R$ {info.PriceInRobux}`)
			end
		end
	end)

	task.spawn(function()
		task.wait(Config.PassOffer.DelaySeconds)
		-- Wait for a calm moment (not mid-chase, no other window open), for up to 10 minutes
		for _ = 1, 600 do
			if State.Data.Passes[offer.Key] or playTime() > Config.PassOffer.FirstMinutes * 60 then
				return
			end
			if player:GetAttribute("CarryingDonut") == nil and not Modal.AnyOpen() then
				modal:Open()
				return
			end
			task.wait(1)
		end
	end)
end

return PassOffer
