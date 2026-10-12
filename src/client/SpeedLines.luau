--[[
	SpeedLines: the anime "speed lines" flash over the whole screen - thin white lines rushing in
	from every edge towards the middle - when a Domer wakes up right next to you or the Cosmic Domer
	climbs out of the black hole.

	With Config.AnimeFX.Textures.SpeedLines pasted (the Blender texture, art/anime_vfx) it shows
	that, turning a little; without it the lines are drawn from frames. Either way it's soft (never
	fully opaque) and fades out by itself. One at a time: a new one replaces the old.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimeFX = require(Shared.AnimeFX)

local Theme = require(script.Parent.UI.Theme)

local SpeedLines = {}

local LINES = 44
local TAU = math.pi * 2

local gui: ScreenGui? = nil
local token = 0

local function build(color: Color3): (ScreenGui, { GuiObject })
	local screen = Theme.ScreenGui("SpeedLines", 6)
	screen.IgnoreGuiInset = true
	local items: { GuiObject } = {}
	local custom = AnimeFX.Custom("SpeedLines")
	if custom then
		local image = Instance.new("ImageLabel")
		image.Name = "Lines"
		image.BackgroundTransparency = 1
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.Size = UDim2.fromScale(1.5, 1.5)
		image.SizeConstraint = Enum.SizeConstraint.RelativeXX
		image.Image = custom
		image.ImageColor3 = color
		image.ImageTransparency = 1 -- (RenderStepped fades it in)
		image.Parent = screen
		table.insert(items, image)
	else
		-- a square as big as the screen's longest side, so the lines reach every corner
		local square = Instance.new("Frame")
		square.Name = "Lines"
		square.BackgroundTransparency = 1
		square.AnchorPoint = Vector2.new(0.5, 0.5)
		square.Position = UDim2.fromScale(0.5, 0.5)
		square.Size = UDim2.fromScale(1.45, 1.45)
		square.SizeConstraint = Enum.SizeConstraint.RelativeXX
		square.Parent = screen
		local rng = Random.new()
		for i = 1, LINES do
			local angle = (i + rng:NextNumber(-0.4, 0.4)) / LINES * TAU
			local inner = rng:NextNumber(0.2, 0.3) -- (how close to the middle it starts, of the square)
			local length = 0.5 - inner
			local middle = inner + length / 2
			local line = Instance.new("Frame")
			line.Name = "Line"
			line.BorderSizePixel = 0
			line.BackgroundColor3 = color
			line.AnchorPoint = Vector2.new(0.5, 0.5)
			line.Position = UDim2.fromScale(0.5 + math.cos(angle) * middle, 0.5 + math.sin(angle) * middle)
			line.Size = UDim2.new(length, 0, 0, rng:NextInteger(2, 7))
			line.Rotation = math.deg(angle)
			line.BackgroundTransparency = 1 -- (RenderStepped fades it in)
			line.Parent = square
			table.insert(items, line)
		end
	end
	return screen, items
end

-- Flash the lines: `strength` 0..1 (how strong at first), fading out over `duration` seconds.
function SpeedLines.Flash(strength: number, duration: number?, color: Color3?)
	token += 1
	local mine = token
	if gui then
		gui:Destroy()
	end
	local screen, items = build(color or Color3.new(1, 1, 1))
	gui = screen
	local length = duration or 0.8
	local started = os.clock()
	local rng = Random.new()
	local nextFlicker = 0
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - started) / length
		if t >= 1 or mine ~= token then
			connection:Disconnect()
			if mine == token and gui == screen then
				gui = nil
			end
			screen:Destroy()
			return
		end
		-- quick in, slow out; the lines shimmer a little (not a strobe)
		local fade = math.min(1, t * 8) * (1 - t) ^ 1.5
		local alpha = 1 - math.clamp(strength, 0, 1) * 0.6 * fade
		local now = os.clock()
		local flicker = now >= nextFlicker
		if flicker then
			nextFlicker = now + 0.06
		end
		for _, item in items do
			if item:IsA("ImageLabel") then
				item.ImageTransparency = alpha
				if flicker then
					item.Rotation = rng:NextNumber(-4, 4)
				end
			elseif flicker then
				item.BackgroundTransparency = math.min(1, alpha + rng:NextNumber(0, 0.25))
			end
		end
	end)
end

return SpeedLines
