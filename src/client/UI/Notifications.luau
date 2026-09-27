--[[
	Notifications: small toasts and big server-wide announcements. Top of the screen, from the top:
	  y 4    Luck Event pill (HUD)
	  y 46   big banners (area names, announcements)
	  y 140  chase banner (Chase) - toasts slide below it while it's showing (SetToastOffset)
	  y 140+ toasts
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)

local Notifications = {}

local KIND_COLORS = {
	info = Theme.Colors.Blue,
	success = Theme.Colors.Green,
	error = Theme.Colors.Red,
	rare = Theme.Colors.Yellow,
	event = Theme.Colors.Pink,
}

local toastHolder: Frame
local bannerHolder: Frame
local toastCounter = 0
local TOAST_Y = 140

-- Push the toasts down while something else (the chase banner) uses that spot.
function Notifications.SetToastOffset(extra: number)
	TweenService:Create(toastHolder, TweenInfo.new(0.25), { Position = UDim2.new(0.5, 0, 0, TOAST_Y + extra) }):Play()
end

function Notifications.Toast(text: string, kind: string?)
	local color = KIND_COLORS[kind or "info"] or Theme.Colors.Blue
	toastCounter -= 1 -- newest first
	local toast = Theme.new("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.1,
		LayoutOrder = toastCounter,
		Parent = toastHolder,
	}, {
		Theme.Corner(10),
		Theme.Stroke(2.5),
	})
	Theme.new("Frame", { Size = UDim2.new(0, 8, 1, 0), BackgroundColor3 = color, BorderSizePixel = 0, Parent = toast }, { Theme.Corner(10) })
	local label = Theme.Label({ Text = text, Font = Theme.Font, Size = UDim2.new(1, -24, 1, -8), Position = UDim2.fromOffset(16, 4), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 1.5, Parent = toast })
	if kind == "error" then
		Theme.PlaySound("Error")
	elseif kind == "event" then
		Theme.PlaySound("Announce")
	end

	-- Keep at most 3 toasts
	local toasts = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 4, #toasts do
		toasts[i]:Destroy()
	end

	task.delay(3.5, function()
		if toast.Parent then
			TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			task.wait(0.4)
			toast:Destroy()
		end
	end)
end

-- Big banner across the top (Secret donuts, area names...).
function Notifications.Banner(text: string, color: Color3, duration: number?, subtitle: string?)
	for _, child in bannerHolder:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local banner = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -120),
		Size = UDim2.new(1, 0, 0, if subtitle then 82 else 56),
		BackgroundTransparency = 1,
		Parent = bannerHolder,
	})
	local title = Theme.Label({ Text = text, TextColor3 = color, Size = UDim2.new(1, 0, 0, 52), StrokeThickness = 3.5, Parent = banner })
	local sub
	if subtitle then
		sub = Theme.Label({ Text = subtitle, Font = Theme.Font, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 54), TextColor3 = Theme.Colors.White, StrokeThickness = 2, Parent = banner })
	end
	TweenService:Create(banner, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 0) }):Play()
	task.delay(duration or 3, function()
		if banner.Parent then
			TweenService:Create(title, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			if sub then
				TweenService:Create(sub, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			end
			task.wait(0.5)
			banner:Destroy()
		end
	end)
end

function Notifications.Init()
	local gui = Theme.ScreenGui("Notifications", 20)
	toastHolder = Theme.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, TOAST_Y),
		Size = UDim2.fromOffset(460, 120),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Theme.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	Theme.AutoScale(toastHolder)
	bannerHolder = Theme.new("Frame", {
		Name = "Banners",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 46),
		Size = UDim2.fromOffset(860, 92),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Theme.AutoScale(bannerHolder)

	Remotes.Event("Notify").OnClientEvent:Connect(function(text: string, kind: string?)
		Notifications.Toast(text, kind)
	end)
	Remotes.Event("AreaAnnouncement").OnClientEvent:Connect(function(text: string, color: Color3)
		Notifications.Banner(text, color, 5)
		Theme.PlaySound("Announce")
	end)
end

return Notifications
