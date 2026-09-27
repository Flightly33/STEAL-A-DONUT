--[[
	Build: tiny helpers for creating anchored parts in code.
]]

local Build = {}

export type Props = { [string]: any }

-- Create an anchored part. `props` are applied as properties (Parent last).
function Build.Part(props: Props, className: string?): BasePart
	local part = Instance.new((className or "Part") :: any) :: BasePart
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			(part :: any)[key] = value
		end
	end
	part.Parent = parent
	return part
end

-- Decoration: no collisions, no shadows, not clickable.
function Build.Decor(props: Props, className: string?): BasePart
	local part = Build.Part(props, className)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

function Build.Ball(parent: Instance, position: Vector3, diameter: number, color: Color3, material: Enum.Material?, collide: boolean?): BasePart
	local part = Build.Part({
		Parent = parent,
		Name = "Ball",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * diameter,
		Position = position,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
	part.CanCollide = collide == true
	part.CanQuery = collide == true
	part.CanTouch = false
	return part
end

-- Upright cylinder whose bottom sits at `base`.
function Build.Pillar(parent: Instance, base: Vector3, height: number, diameter: number, color: Color3, material: Enum.Material?, collide: boolean?): BasePart
	local part = Build.Part({
		Parent = parent,
		Name = "Pillar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
	part.CanCollide = collide == true
	part.CanQuery = collide == true
	part.CanTouch = false
	return part
end

-- A wall made of alternating-colour blocks (the checkered wall look).
function Build.CheckerWall(parent: Instance, start: Vector3, direction: Vector3, length: number, height: number, thickness: number, colors: { Color3 }, material: Enum.Material, block: number)
	local folder = Instance.new("Folder")
	folder.Name = "Wall"
	folder.Parent = parent
	local right = direction.Unit
	local columns = math.ceil(length / block)
	local rows = math.ceil(height / block)
	for column = 0, columns - 1 do
		local width = math.min(block, length - column * block)
		for row = 0, rows - 1 do
			local h = math.min(block, height - row * block)
			local center = start + right * (column * block + width / 2) + Vector3.new(0, row * block + h / 2, 0)
			local size = if math.abs(right.X) > 0.5 then Vector3.new(width, h, thickness) else Vector3.new(thickness, h, width)
			local part = Build.Part({
				Parent = folder,
				Name = "WallBlock",
				Size = size,
				Position = center,
				Color = colors[(column + row) % #colors + 1],
				Material = material,
			})
			if material == Enum.Material.Plastic then
				part.FrontSurface = Enum.SurfaceType.Studs
				part.BackSurface = Enum.SurfaceType.Studs
				part.LeftSurface = Enum.SurfaceType.Studs
				part.RightSurface = Enum.SurfaceType.Studs
			end
		end
	end
	return folder
end

-- Checkered floor of `tile`-sized squares, top surface at y = topY.
function Build.CheckerFloor(parent: Instance, minX: number, maxX: number, minZ: number, maxZ: number, tile: number, colors: { Color3 }, material: Enum.Material, topY: number?)
	local folder = Instance.new("Folder")
	folder.Name = "Floor"
	folder.Parent = parent
	local y = (topY or 0) - 0.5
	local ix = 0
	local x = minX
	while x < maxX - 0.01 do
		local w = math.min(tile, maxX - x)
		local iz = 0
		local z = minZ
		while z < maxZ - 0.01 do
			local d = math.min(tile, maxZ - z)
			local part = Build.Part({
				Parent = folder,
				Name = "Tile",
				Size = Vector3.new(w, 1, d),
				Position = Vector3.new(x + w / 2, y, z + d / 2),
				Color = colors[(ix + iz) % #colors + 1],
				Material = material,
			})
			if material == Enum.Material.Plastic then
				part.TopSurface = Enum.SurfaceType.Studs
			end
			z += d
			iz += 1
		end
		x += w
		ix += 1
	end
	return folder
end

function Build.Text(parent: Instance, text: string, props: Props?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Text = text
	if props then
		for key, value in props do
			(label :: any)[key] = value
		end
	end
	label.Parent = parent
	return label
end

return Build
