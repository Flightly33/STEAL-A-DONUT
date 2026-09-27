--[[
	ItemModel: the 3D models of the shop items (Config.Items), built from plain parts.

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
local WHITE = rgb(250, 250, 250)

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
	-- An ellipsoid (a block with a sphere mesh): Ball parts are always perfectly round.
	local function blob(size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
		local p = part(size, offset, color, material)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		return p
	end
	local function glow(target: Part, color: Color3, range: number)
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = range
		light.Brightness = 1.5
		light.Shadows = false
		light.Parent = target
	end

	if item.Id == "Slap" then
		-- A giant cartoon glove: cuff, puffy palm, four fingers and a thumb (palm faces sideways)
		local glove = rgb(255, 205, 60)
		local cuffColor = rgb(235, 70, 60)
		handle.Size = Vector3.new(0.8, 0.8, 1.1)
		handle.Color = cuffColor
		handle.Material = Enum.Material.Fabric
		part(Vector3.new(0.5, 1.5, 1.5), CFrame.new(0, 0, 0.55) * ALONG, cuffColor, Enum.Material.Fabric, CYL)
		part(Vector3.new(0.12, 1.56, 1.56), CFrame.new(0, 0, 0.35) * ALONG, WHITE, Enum.Material.Fabric, CYL)
		blob(Vector3.new(2.3, 0.95, 2.1), CFrame.new(0, 0, 1.75), glove, Enum.Material.Fabric)
		for i, x in { -0.8, -0.27, 0.27, 0.8 } do
			local length = if i == 1 or i == 4 then 1.1 else 1.35
			local z = 2.55 + length / 2
			part(Vector3.new(length, 0.55, 0.55), CFrame.new(x, 0, z) * ALONG, glove, Enum.Material.Fabric, CYL)
			part(Vector3.one * 0.55, CFrame.new(x, 0, z + length / 2), glove, Enum.Material.Fabric, BALL)
			-- knuckle crease
			part(Vector3.new(0.5, 0.58, 0.06), CFrame.new(x, 0, 2.62), rgb(215, 160, 40), Enum.Material.Fabric)
		end
		-- thumb, sticking out to the side
		local thumb = CFrame.new(1.35, 0, 1.6) * CFrame.Angles(0, math.rad(-35), 0)
		part(Vector3.new(1.0, 0.58, 0.58), thumb * ALONG, glove, Enum.Material.Fabric, CYL)
		part(Vector3.one * 0.58, thumb * CFrame.new(0, 0, 0.5), glove, Enum.Material.Fabric, BALL)
		-- stitching on the back of the hand
		for _, x in { -0.45, 0, 0.45 } do
			part(Vector3.new(0.08, 1.0, 0.9), CFrame.new(x, 0, 1.75), rgb(190, 120, 30), Enum.Material.Fabric)
		end
		return 0
	elseif item.Id == "Bat" then
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
	elseif item.Id == "Hammer" then
		-- A glowing mega mallet: long metal shaft with grip wraps, a huge drum head with gold bands
		handle.Size = Vector3.new(0.45, 0.45, 3.6)
		handle.Color = rgb(70, 50, 110)
		handle.Material = Enum.Material.Metal
		for i = 0, 4 do
			part(Vector3.new(0.12, 0.55, 0.55), CFrame.new(0, 0, -1.6 + i * 0.3) * ALONG, rgb(30, 25, 45), Enum.Material.Fabric, CYL)
		end
		local head = CFrame.new(0, 0, 2.3)
		part(Vector3.new(3.2, 2.2, 2.2), head, rgb(140, 80, 255), Enum.Material.SmoothPlastic, CYL)
		for _, x in { -1.45, 1.45 } do
			part(Vector3.new(0.35, 2.4, 2.4), head * CFrame.new(x, 0, 0), rgb(255, 215, 80), Enum.Material.Foil, CYL)
			part(Vector3.new(0.1, 1.5, 1.5), head * CFrame.new(x * 1.09, 0, 0), rgb(255, 245, 190), Enum.Material.Neon, CYL)
		end
		local core = part(Vector3.new(0.7, 2.26, 2.26), head, rgb(210, 160, 255), Enum.Material.Neon, CYL)
		glow(core, rgb(170, 110, 255), 12)
		local sparks = Instance.new("ParticleEmitter")
		sparks.Color = ColorSequence.new(rgb(220, 180, 255), rgb(255, 255, 255))
		sparks.LightEmission = 1
		sparks.Rate = 6
		sparks.Lifetime = NumberRange.new(0.4, 0.8)
		sparks.Speed = NumberRange.new(1, 3)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Size = NumberSequence.new(0.25, 0)
		sparks.Parent = core
		part(Vector3.one * 0.7, CFrame.new(0, 0, -1.95), rgb(255, 215, 80), Enum.Material.Neon, BALL)
		return -1.2
	elseif item.Id == "Banana" then
		-- A half-peeled banana: the fruit sticks up, three peel flaps droop around it
		local yellow = rgb(255, 225, 60)
		handle.Size = Vector3.new(0.55, 0.55, 1)
		handle.Color = yellow
		part(Vector3.new(0.28, 0.28, 0.4), CFrame.new(0, 0, -0.65), rgb(110, 80, 40))
		blob(Vector3.new(0.7, 0.7, 1.9), CFrame.new(0, 0.05, 1.3) * CFrame.Angles(math.rad(-8), 0, 0), rgb(255, 245, 200))
		for n = 0, 2 do
			local angle = n / 3 * math.pi * 2
			local flap = CFrame.Angles(0, 0, angle) * CFrame.new(0, 0.42, 0.7) * CFrame.Angles(math.rad(35), 0, 0)
			part(Vector3.new(0.5, 0.14, 1.4), flap * CFrame.new(0, 0, 0.3), yellow)
			part(Vector3.new(0.34, 0.15, 0.22), flap * CFrame.new(0, 0, 1.05), rgb(140, 100, 40))
		end
		return -0.25
	elseif item.Id == "Spring" then
		-- A mini launch pad: base disc, springs and a glowing top with arrows
		handle.Size = Vector3.new(0.45, 0.45, 0.9)
		handle.Color = rgb(60, 60, 70)
		handle.Material = Enum.Material.Metal
		part(Vector3.new(0.25, 2.2, 2.2), CFrame.new(0, 0, 0.6) * ALONG, rgb(50, 55, 70), Enum.Material.Metal, CYL)
		for i = 0, 3 do
			part(Vector3.new(0.12, 1.2, 1.2), CFrame.new(0, 0, 0.85 + i * 0.25) * ALONG, rgb(210, 210, 220), Enum.Material.Metal, CYL)
		end
		local top = part(Vector3.new(0.3, 2.3, 2.3), CFrame.new(0, 0, 1.95) * ALONG, rgb(80, 200, 255), Enum.Material.Neon, CYL)
		glow(top, rgb(80, 200, 255), 8)
		for n = 0, 3 do
			part(Vector3.new(0.18, 0.7, 0.12), CFrame.new(0, 0, 2.13) * CFrame.Angles(0, 0, n * math.pi / 2) * CFrame.new(0, 0.6, 0), WHITE, Enum.Material.Neon)
		end
		return -0.25
	elseif item.Id == "Lock" then
		-- A big golden padlock: body, keyhole and a curved shackle on top
		local gold = rgb(255, 200, 50)
		handle.Size = Vector3.new(0.5, 0.5, 0.7)
		handle.Color = rgb(60, 60, 70)
		handle.Material = Enum.Material.Metal
		part(Vector3.new(1.7, 0.75, 1.45), CFrame.new(0, 0, 1.05), gold, Enum.Material.Foil)
		part(Vector3.new(1.78, 0.8, 0.12), CFrame.new(0, 0, 0.4), rgb(220, 160, 30), Enum.Material.Foil)
		part(Vector3.new(0.34, 0.82, 0.34), CFrame.new(0, 0, 1.1), rgb(40, 30, 20), nil, CYL)
		part(Vector3.new(0.14, 0.82, 0.32), CFrame.new(0, 0, 0.9), rgb(40, 30, 20))
		for i = 0, 8 do
			local angle = i / 8 * math.pi
			local x, z = math.cos(angle) * 0.58, 1.9 + math.sin(angle) * 0.62
			part(Vector3.one * 0.26, CFrame.new(x, 0, z), rgb(210, 210, 220), Enum.Material.Metal, BALL)
		end
		local shine = part(Vector3.new(0.3, 0.1, 0.3), CFrame.new(-0.5, 0.42, 1.4), rgb(255, 250, 210), Enum.Material.Neon)
		shine.Transparency = 0.3
		return -0.1
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
