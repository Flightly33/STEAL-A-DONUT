--[[
	DonutGlow: a glowing outline round the rare donuts closest to the camera (Epic and up, and every
	mutated donut: the server tags them "DonutOutline" and stores the colour in "OutlineColor"),
	like the glowing creatures in the egg games.

	Roblox only draws a limited number of outlines (Highlights) at once, so only the closest few
	get one. Donuts whose mystical theme already pulses an outline (DonutFX, "FXOutline") are left
	to DonutFX. Everything here is local to this client.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local DonutGlow = {}

local MAX_OUTLINES = 8
local RANGE = 70 -- studs from the camera
local INTERVAL = 0.25 -- seconds between picking the closest donuts

local folder: Folder? = nil
local outlines: { [Model]: Highlight } = {}

local function makeOutline(model: Model): Highlight
	local color = model:GetAttribute("OutlineColor")
	local glow = if typeof(color) == "Color3" then color else Color3.new(1, 1, 1)
	local highlight = Instance.new("Highlight")
	highlight.Name = "DonutGlow"
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillTransparency = 1
	highlight.OutlineColor = glow:Lerp(Color3.new(1, 1, 1), 0.45)
	highlight.OutlineTransparency = 0.15
	highlight.Parent = folder
	return highlight
end

local function update()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	local near: { { Model: Model, Distance: number } } = {}
	for _, instance in CollectionService:GetTagged("DonutOutline") do
		if instance:IsA("Model") and instance:IsDescendantOf(workspace) and not instance:GetAttribute("FXOutline") then
			local root = instance.PrimaryPart
			if root then
				local distance = (root.Position - eye).Magnitude
				if distance < RANGE then
					table.insert(near, { Model = instance, Distance = distance })
				end
			end
		end
	end
	table.sort(near, function(a, b)
		return a.Distance < b.Distance
	end)
	local wanted: { [Model]: boolean } = {}
	for i = 1, math.min(MAX_OUTLINES, #near) do
		wanted[near[i].Model] = true
	end
	for model, highlight in outlines do
		if not wanted[model] or not model.Parent then
			highlight:Destroy()
			outlines[model] = nil
		end
	end
	for model in wanted do
		if not outlines[model] then
			outlines[model] = makeOutline(model)
		end
	end
end

function DonutGlow.Init()
	local holder = Instance.new("Folder")
	holder.Name = "DonutGlowLocal"
	holder.Parent = workspace
	folder = holder
	local cooldown = 0
	RunService.RenderStepped:Connect(function(dt: number)
		cooldown -= dt
		if cooldown > 0 then
			return
		end
		cooldown = INTERVAL
		update()
	end)
end

return DonutGlow
