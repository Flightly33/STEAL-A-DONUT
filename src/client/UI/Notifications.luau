--[[
	Notifications: small toasts and big server-wide announcements, all in the game's message style:
	big white (or coloured) outlined letters on a dark band that fades out at its ends - never a
	box, never an emoji (Format.Plain takes them out of anything the server sends). Top of the
	screen, from the top:
	  y 4    Luck Event pill (HUD) and the server event pill under it (EventBanner, y 46)
	  y 92   big banners (area names, announcements)
	  y 186  chase banner (Chase) - toasts slide below it while it's showing (SetToastOffset)
	  y 186+ toasts
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local Theme = require(script.Parent.Theme)

local Notifications = {}

-- The text's colour for each kind of toast
local KIND_COLORS = {
	info = Color3.fromRGB(255, 255, 255),
	success = Color3.fromRGB(140, 255, 120),
	error = Color3.fromRGB(255, 120, 110),
	rare = Color3.fromRGB(255, 220, 90),
	event = Color3.fromRGB(255, 150, 220),
}

local KIND_SOUNDS = {
	info = "Notify",
	success = "Success",
	error = "Error",
	rare = "Rare",
	event = "Announce",
}

local toastHolder: Frame
local bannerHolder: Frame
local toastCounter = 0
local TOAST_Y = 186

-- Push the toasts down while something else (the chase banner) uses that spot.
function Notifications.SetToastOffset(extra: number)
	TweenService:Create(toastHolder, TweenInfo.new(0.25), { Position = UDim2.new(0.5, 0, 0, TOAST_Y + extra) }):Play()
end

function Notifications.Toast(text: string, kind: string?)
	local color = KIND_COLORS[kind or "info"] or KIND_COLORS.info
	toastCounter -= 1 -- newest first
	local toast = Theme.Band({ Name = "Toast", Size = UDim2.new(1, 0, 0, 36), LayoutOrder = toastCounter, Darkness = 0.62, Parent = toastHolder })
	local label = Theme.Label({ Name = "Text", Text = Format.Plain(text), Font = Theme.Font, TextColor3 = color, Size = UDim2.new(1, -120, 1, -6), Position = UDim2.fromOffset(60, 3), StrokeThickness = 2.5, Parent = toast })
	-- A soft chime for each kind (skipped if another sound just played, like the steal jingle)
	if Theme.SinceSound() > 0.35 then
		Theme.PlaySound(KIND_SOUNDS[kind or "info"] or "Notify")
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
	local banner = Theme.Band({
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -120),
		Size = UDim2.new(1, 0, 0, if subtitle then 88 else 62),
		Darkness = 0.55,
		Parent = bannerHolder,
	})
	local title = Theme.Label({ Name = "Title", Text = Format.Plain(text), TextColor3 = color, Size = UDim2.new(1, -160, 0, 50), Position = UDim2.fromOffset(80, 6), StrokeThickness = 3.5, Parent = banner })
	local sub
	if subtitle then
		sub = Theme.Label({ Name = "Subtitle", Text = Format.Plain(subtitle), Font = Theme.Font, Size = UDim2.new(1, -160, 0, 26), Position = UDim2.fromOffset(80, 56), TextColor3 = Theme.Colors.White, StrokeThickness = 2.5, Parent = banner })
	end
	TweenService:Create(banner, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 0) }):Play()
	task.delay(duration or 3, function()
		if banner.Parent then
			TweenService:Create(banner, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
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
		Size = UDim2.fromOffset(620, 130),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		Theme.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	Theme.AutoScale(toastHolder)
	bannerHolder = Theme.new("Frame", {
		Name = "Banners",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 92),
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
