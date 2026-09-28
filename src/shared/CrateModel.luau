--[[
	CrateModel: builds a crate out of plain parts. The better the crate, the fancier it looks:
	  Common     wooden crate with metal corners
	  Rare       blue steel crate, glowing seams, sparkles
	  Epic       purple crystal crate, neon edges, a soft light and swirling sparkles
	  Legendary  golden crate with a crown, light rays and golden sparks
	Every face has a big "?" so it reads as a mystery box from any side.

	Same rules as PetModel: one rigid assembly welded to an anchored, invisible "Root" part, so moving
	Root moves everything. Attributes Top / Bottom tell callers how to stand it on a surface. The lid
	is a separate part named "Lid" (the opening animation pops it off).
]]

local Crates = require(script.Parent.Crates)

local CrateModel = {}

local rgb = Color3.fromRGB

export type Options = {
	Scale: number?,
	NoEffects: boolean?, -- no lights/particles (UI previews)
}

type Look = { Body: Color3, BodyMaterial: Enum.Material, Trim: Color3, TrimMaterial: Enum.Material, Glow: Color3?, Question: Color3 }

local LOOKS: { [string]: Look } = {
	Common = { Body = rgb(170, 115, 65), BodyMaterial = Enum.Material.WoodPlanks, Trim = rgb(120, 120, 130), TrimMaterial = Enum.Material.Metal, Glow = nil, Question = rgb(255, 240, 200) },
	Rare = { Body = rgb(45, 95, 190), BodyMaterial = Enum.Material.DiamondPlate, Trim = rgb(150, 220, 255), TrimMaterial = Enum.Material.Neon, Glow = rgb(120, 200, 255), Question = rgb(200, 240, 255) },
	Epic = { Body = rgb(110, 40, 180), BodyMaterial = Enum.Material.Glass, Trim = rgb(255, 130, 255), TrimMaterial = Enum.Material.Neon, Glow = rgb(220, 120, 255), Question = rgb(255, 200, 255) },
	Legendary = { Body = rgb(255, 190, 40), BodyMaterial = Enum.Material.Foil, Trim = rgb(255, 245, 190), TrimMaterial = Enum.Material.Neon, Glow = rgb(255, 210, 90), Question = rgb(255, 60, 60) },
}

local function emitter(parent: Instance, color: Color3, rate: number, size: number, speed: number, lifetime: number)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Rate = rate
	e.Lifetime = NumberRange.new(lifetime * 0.6, lifetime)
	e.Speed = NumberRange.new(speed * 0.4, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new(size, 0)
	e.Transparency = NumberSequence.new(0.1, 1)
	e.Parent = parent
end

function CrateModel.Build(crateId: string, options: Options?): Model
	local opts: Options = options or {}
	local s = opts.Scale or 1
	local crate = Crates.ById[crateId] or Crates.List[1]
	local look = LOOKS[crate.Id] or LOOKS.Common

	local model = Instance.new("Model")
	model.Name = crate.Name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one * s
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Massless = true
	root.CFrame = CFrame.identity
	root.Parent = model
	model.PrimaryPart = root

	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size * s
		p.CFrame = CFrame.new(cf.Position * s) * cf.Rotation
		p.Color = color
		p.Material = material
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			p.Shape = shape
		end
		p.Anchored = false
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.CastShadow = false
		if material == Enum.Material.Glass then
			p.Transparency = 0.15
		end
		local weld = Instance.new("Weld")
		weld.Part0 = root
		weld.Part1 = p
		weld.C0 = p.CFrame
		weld.Parent = p
		p.Parent = model
		return p
	end

	-- Body (the crate is 4 wide, 3.2 tall, centred on the root) and lid
	local body = part("Body", Vector3.new(4, 2.6, 4), CFrame.new(0, -0.3, 0), look.Body, look.BodyMaterial)
	part("Lid", Vector3.new(4.3, 0.7, 4.3), CFrame.new(0, 1.35, 0), look.Body:Lerp(Color3.new(0, 0, 0), 0.15), look.BodyMaterial)
	-- Trim: the 4 vertical edges, a band round the middle and one under the lid
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			part("Corner", Vector3.new(0.45, 2.7, 0.45), CFrame.new(x * 1.9, -0.3, z * 1.9), look.Trim, look.TrimMaterial)
		end
	end
	part("Band", Vector3.new(4.12, 0.35, 4.12), CFrame.new(0, -0.3, 0), look.Trim, look.TrimMaterial)
	part("LidBand", Vector3.new(4.4, 0.25, 4.4), CFrame.new(0, 1.05, 0), look.Trim, look.TrimMaterial)
	part("Latch", Vector3.new(0.7, 0.8, 0.3), CFrame.new(0, 0.85, -2.2), look.Trim, look.TrimMaterial)

	-- A big "?" on every side
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.3
		gui.Parent = body
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Text = "?"
		label.TextScaled = true
		label.Font = Enum.Font.LuckiestGuy
		label.TextColor3 = look.Question
		label.TextStrokeTransparency = 0
		label.Parent = gui
	end

	if crate.Id == "Legendary" then
		-- Crown on the lid
		part("CrownBase", Vector3.new(0.4, 2.2, 2.2), CFrame.new(0, 1.9, 0) * CFrame.Angles(0, 0, math.pi / 2), look.Trim, Enum.Material.Neon, Enum.PartType.Cylinder)
		for i = 0, 4 do
			local angle = i / 5 * math.pi * 2
			part("CrownSpike", Vector3.new(0.35, 0.8, 0.35), CFrame.new(math.cos(angle) * 0.9, 2.45, math.sin(angle) * 0.9), rgb(255, 215, 60), Enum.Material.Neon)
		end
		part("CrownGem", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 2.3, 0), rgb(255, 50, 60), Enum.Material.Neon, Enum.PartType.Ball)
	end

	if not opts.NoEffects then
		if look.Glow then
			local light = Instance.new("PointLight")
			light.Color = look.Glow
			light.Range = 10 + crate.Order * 4
			light.Brightness = 1 + crate.Order * 0.4
			light.Shadows = false
			light.Parent = body
		end
		if crate.Order >= 2 then
			emitter(body, look.Trim, 2 + crate.Order * 3, 0.35 * s, 2, 1.5)
		end
		if crate.Order >= 3 then
			emitter(body, look.Glow or look.Trim, 6, 0.6 * s, 4, 1.2)
		end
		if crate.Order >= 4 then
			-- Light rays fanning out behind it
			for i = 1, 8 do
				local ray = part("Ray", Vector3.new(0.3, 7, 0.05), CFrame.new(0, 0.3, 0.2) * CFrame.Angles(0, 0, i / 8 * math.pi * 2) * CFrame.new(0, 3.5, 0), rgb(255, 225, 120), Enum.Material.Neon)
				ray.Transparency = 0.55
			end
		end
	end

	model:SetAttribute("CrateId", crate.Id)
	model:SetAttribute("Top", (if crate.Id == "Legendary" then 2.9 else 1.7) * s)
	model:SetAttribute("Bottom", 1.6 * s)
	return model
end

return CrateModel
