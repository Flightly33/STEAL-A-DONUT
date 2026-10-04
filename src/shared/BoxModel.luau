--[[
	BoxModel: builds a donut box (Boxes.luau) - in a biome, lying on the ground, carried over a
	thief's head, waiting to open in a pen, or popping open (client/BoxFX).

	A flat cardboard-style donut box made of studded bricks, with a lid that has "DONUTS" written
	across the top. The lid is its own part ("Lid") so it can flip open.
	  * Basic: the plain pink box.
	  * Rare: blue, with a white ribbon round it.
	  * Epic: purple, with a ribbon, a bow, a soft glow and a few sparkles.
	  * Legendary: gold, with a big bow, a bright glow and a shower of sparkles.
	A box with a mutation (Rarities.Mutations) is made of that mutation's material (gold foil,
	diamond glass, glowing neon...). Bigger boxes are just bigger (Boxes.Sizes Scale).

	The model's pivot (and PrimaryPart "Root") is the middle of its bottom face, so PivotTo on a
	spot on the ground puts it standing on it. Attributes: Tier, BoxSize, Mutation, Area, Top (height).
]]

local Boxes = require(script.Parent.Boxes)
local Rarities = require(script.Parent.Rarities)

local BoxModel = {}

local rgb = Color3.fromRGB
local WIDTH, HEIGHT, DEPTH = 5.2, 2.6, 3.6 -- a Small box, in studs

export type Options = {
	Mutation: string?,
	Area: number?,
	NoEffects: boolean?, -- no lights or particles (inventory previews, lots of boxes on screen)
	Scale: number?, -- on top of the box's size
}

local function studs(part: BasePart)
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Inlet
	part.FrontSurface = Enum.SurfaceType.Studs
	part.BackSurface = Enum.SurfaceType.Studs
	part.LeftSurface = Enum.SurfaceType.Studs
	part.RightSurface = Enum.SurfaceType.Studs
end

local function part(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

function BoxModel.Build(tierId: string, sizeId: string?, options: Options?): Model
	local opts: Options = options or {}
	local tier = Boxes.Tier(tierId)
	local size = Boxes.Size(sizeId)
	local mutation = Rarities.Mutation(opts.Mutation)
	local s = size.Scale * (opts.Scale or 1)
	local w, h, d = WIDTH * s, HEIGHT * s, DEPTH * s
	local base = h * 0.72 -- the bottom part's height (the lid is the rest)

	local model = Instance.new("Model")
	model.Name = "DonutBox"
	local root = part(model, "Root", Vector3.new(1, 0.2, 1), CFrame.new(0, 0, 0), Color3.new(1, 1, 1))
	root.Transparency = 1
	model.PrimaryPart = root

	local boxColor, trim, material = tier.Color, tier.Trim, Enum.Material.Plastic
	if mutation.Id ~= "None" then
		boxColor = mutation.Frosting or mutation.Color
		trim = mutation.Dough or mutation.Color:Lerp(Color3.new(1, 1, 1), 0.5)
		material = mutation.Material or Enum.Material.Plastic
	end
	local bottom = part(model, "Bottom", Vector3.new(w, base, d), CFrame.new(0, base / 2, 0), boxColor, material)
	local lidHeight = h - base
	local lid = part(model, "Lid", Vector3.new(w * 1.04, lidHeight, d * 1.04), CFrame.new(0, base + lidHeight / 2, 0), boxColor:Lerp(Color3.new(1, 1, 1), 0.12), material)
	if material == Enum.Material.Plastic then
		studs(bottom)
		studs(lid)
	end
	-- a band of trim round the bottom edge
	part(model, "Band", Vector3.new(w * 1.01, 0.18 * s, d * 1.01), CFrame.new(0, 0.12 * s, 0), trim, Enum.Material.SmoothPlastic)

	-- "DONUTS" across the lid
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LidText"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.4
	gui.Parent = lid
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.86, 0.6)
	label.Position = UDim2.fromScale(0.07, 0.2)
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.Text = "DONUTS"
	label.TextColor3 = if tier.Id == "Basic" then rgb(255, 255, 255) else trim
	label.TextStrokeColor3 = boxColor:Lerp(Color3.new(0, 0, 0), 0.45)
	label.TextStrokeTransparency = 0
	label.Parent = gui

	-- ribbons and bows on the fancier boxes
	if tier.Order >= 1 then
		local ribbon = if tier.Id == "Rare" then rgb(255, 255, 255) elseif tier.Id == "Epic" then rgb(255, 215, 90) else rgb(255, 255, 255)
		local rw = 0.5 * s
		part(model, "Ribbon", Vector3.new(rw, h * 1.04, d * 1.07), CFrame.new(w * 0.3, h / 2, 0), ribbon, Enum.Material.SmoothPlastic)
		part(model, "Ribbon", Vector3.new(w * 1.07, h * 1.04, rw), CFrame.new(0, h / 2, 0), ribbon, Enum.Material.SmoothPlastic)
		if tier.Order >= 2 then
			local bow = (if tier.Order >= 3 then 1.5 else 1.1) * s
			for _, side in { -1, 1 } do
				part(model, "Bow", Vector3.new(bow, bow * 0.7, bow * 0.5), CFrame.new(w * 0.3 + side * bow * 0.45, h + bow * 0.3, 0) * CFrame.Angles(0, 0, side * 0.5), ribbon, Enum.Material.SmoothPlastic)
			end
			part(model, "BowKnot", Vector3.one * bow * 0.45, CFrame.new(w * 0.3, h + bow * 0.25, 0), ribbon, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		end
	end

	if not opts.NoEffects then
		local glow = if mutation.Light then mutation.Color elseif tier.Order >= 2 then tier.Color else nil
		if glow then
			local light = Instance.new("PointLight")
			light.Color = glow
			light.Range = (if tier.Order >= 3 or mutation.Light then 14 else 9) * math.sqrt(s)
			light.Brightness = if tier.Order >= 3 then 2 else 1.3
			light.Parent = bottom
		end
		local rate = (if tier.Order >= 3 then 10 elseif tier.Order >= 2 then 4 else 0) + (mutation.Particles or 0) * 0.5
		if rate > 0 then
			local emitter = Instance.new("ParticleEmitter")
			emitter.Name = "Sparkles"
			emitter.Color = ColorSequence.new(if mutation.Id ~= "None" then mutation.Color else tier.Color, Color3.new(1, 1, 1))
			emitter.LightEmission = 0.8
			emitter.Rate = rate
			emitter.Lifetime = NumberRange.new(0.8, 1.6)
			emitter.Speed = NumberRange.new(0.5, 2)
			emitter.SpreadAngle = Vector2.new(180, 180)
			emitter.Size = NumberSequence.new(0.35 * math.sqrt(s), 0)
			emitter.Parent = lid
		end
	end

	model:SetAttribute("Tier", tier.Id)
	model:SetAttribute("BoxSize", size.Id)
	model:SetAttribute("Mutation", mutation.Id)
	if opts.Area then
		model:SetAttribute("Area", opts.Area)
	end
	model:SetAttribute("Top", h + (if tier.Order >= 2 then 1.5 * s else 0))
	if mutation.Rainbow then
		model:SetAttribute("Rainbow", true)
	end
	return model
end

-- Stand a box (its bottom middle) on `cf`.
function BoxModel.PlaceOn(model: Model, cf: CFrame)
	model:PivotTo(cf)
end

return BoxModel
