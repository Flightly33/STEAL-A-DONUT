--[[
	ItemModel: the 3D models of the items (Config.Items: just the free Donut Bat now), built from plain parts.

	Shared by the server (the Tools in your hotbar) and the client (the spinning previews in the
	Item Shop), so what you see in the shop is exactly what you hold.

	Every item is modelled along the Handle's +Z axis ("away from the hand") and held with the classic
	Roblox sword grip, so it stands up out of your fist the way the classic sword does. All decoration
	is welded to the Handle, massless and non-colliding, so it can't push you around or get stuck.
]]

local Config = require(script.Parent.Config)

local ItemModel = {}

local rgb = Color3.fromRGB
local BALL, CYL, BLOCK = Enum.PartType.Ball, Enum.PartType.Cylinder, Enum.PartType.Block
-- Cylinders point along X; this lays one along the item (Z).
local ALONG = CFrame.Angles(0, math.pi / 2, 0)
-- The classic sword grip (the item's +Z points up out of the fist).
local GRIP = CFrame.new(0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0)

local WOOD = rgb(160, 104, 56)
local DARK_WOOD = rgb(100, 64, 34)
local DOUGH = rgb(222, 165, 95)

local function newHandle(size: Vector3, color: Color3, material: Enum.Material?): Part
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = size
	handle.Color = color
	handle.Material = material or Enum.Material.SmoothPlastic
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.CanCollide = false
	handle.Massless = true
	handle.CastShadow = false
	return handle
end

-- Build the model's parts around `handle` (already created, not yet parented) inside `parent`.
-- Returns the grip offset along Z (where the fist holds the handle).
local function decorate(item: Config.Item, handle: Part, parent: Instance): number
	local function part(size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Name = "Decor"
		p.Size = size
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape and shape ~= BLOCK then
			p.Shape = shape
		end
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		p.CFrame = handle.CFrame * offset
		local weld = Instance.new("Weld")
		weld.Part0 = handle
		weld.Part1 = p
		weld.C0 = offset
		weld.Parent = p
		p.Parent = parent
		return p
	end

	if item.Id == "Bat" then
		-- A baseball bat with grip tape, a knob, a tapered barrel and a donut stuck on the end
		handle.Size = Vector3.new(0.38, 0.38, 1.8)
		handle.Color = rgb(40, 40, 45)
		handle.Material = Enum.Material.Fabric
		part(Vector3.new(0.3, 0.62, 0.62), CFrame.new(0, 0, -0.95) * ALONG, DARK_WOOD, Enum.Material.Wood, CYL)
		for i = 0, 3 do
			part(Vector3.new(0.08, 0.42, 0.42), CFrame.new(0, 0, -0.6 + i * 0.4) * ALONG, rgb(220, 50, 50), Enum.Material.Fabric, CYL)
		end
		for i = 0, 6 do
			local d = 0.44 + i * 0.1
			part(Vector3.new(0.55, d, d), CFrame.new(0, 0, 1.1 + i * 0.5) * ALONG, WOOD, Enum.Material.Wood, CYL)
		end
		part(Vector3.one * 1.04, CFrame.new(0, 0, 4.25), WOOD, Enum.Material.Wood, BALL)
		-- the donut ring around the barrel: dough, pink frosting and sprinkles
		local sprinkles = { rgb(255, 70, 70), rgb(80, 200, 255), rgb(255, 235, 70), rgb(120, 230, 90) }
		for n = 0, 11 do
			local angle = n / 12 * math.pi * 2
			local c, s = math.cos(angle), math.sin(angle)
			part(Vector3.one * 0.62, CFrame.new(c * 0.82, s * 0.82, 3.3), DOUGH, nil, BALL)
			part(Vector3.one * 0.52, CFrame.new(c * 0.82, s * 0.82, 3.12), rgb(255, 130, 190), nil, BALL)
			if n % 2 == 0 then
				part(Vector3.new(0.08, 0.08, 0.26), CFrame.new(c * 0.82, s * 0.82, 2.86) * CFrame.Angles(0, 0, angle), sprinkles[n // 2 % 4 + 1], Enum.Material.Neon)
			end
		end
		return -0.3
	end
	return 0
end

-- The Tool that goes in your backpack.
function ItemModel.BuildTool(item: Config.Item): Tool
	local tool = Instance.new("Tool")
	tool.Name = item.Name
	tool.ToolTip = item.Description
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("ItemId", item.Id)
	local handle = newHandle(Vector3.new(0.4, 0.4, 1.4), rgb(120, 80, 45))
	local gripZ = decorate(item, handle, tool)
	tool.Grip = CFrame.new(0, 0, gripZ) * GRIP
	handle.Parent = tool
	return tool
end

-- A plain model of the item (shop previews). Its PrimaryPart is the handle; +Z points up the item.
function ItemModel.BuildPreview(item: Config.Item): Model
	local model = Instance.new("Model")
	model.Name = item.Id
	local handle = newHandle(Vector3.new(0.4, 0.4, 1.4), rgb(120, 80, 45))
	handle.Anchored = true
	decorate(item, handle, model)
	handle.Parent = model
	model.PrimaryPart = handle
	return model
end

return ItemModel
