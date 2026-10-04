--[[
	BoxModel: builds a donut box (Boxes.luau) - in a biome, lying on the ground, carried over a
	thief's head, waiting to open in a pen, or popping open (client/BoxFX).

	A bakery donut box made of studded bricks: the box itself with a trim band round its foot and the
	rarity's name on its front and back, and a lid that clearly sits on top - it overhangs the box,
	has a contrasting trim round its edge, a closing tab at the front and a raised panel with
	"DONUTS" on it. Every part of the lid is named "Lid..." or "Bow..." so it can flip open in one
	piece (client/BoxFX).
	  * Basic: pink cardboard, a white lid.
	  * Rare: sky blue, a white lid with blue trim, a silver ribbon and a little bow.
	  * Epic: purple, a deep purple lid with gold trim, gold corners, a gold ribbon and a big bow.
	  * Legendary: shiny gold, a cream lid with gold corners and a big bow; the lid sits ajar and
	    golden light spills out of the gap.
	  * Mythic: dark crimson with a black lid, gold corners, glowing gold edges and glowing cracks; the
	    lid sits ajar with red light pouring out, and embers drift up.
	A box with a mutation (Rarities.Mutations) is made of that mutation's material (gold foil,
	diamond glass, glowing neon...). Bigger boxes are just bigger (Boxes.Sizes Scale).

	The model's pivot (and PrimaryPart "Root") is the middle of its bottom face, so PivotTo on a
	spot on the ground puts it standing on it. Attributes: Tier, BoxSize, Mutation, Area, Top (height).
]]

local Boxes = require(script.Parent.Boxes)
local Rarities = require(script.Parent.Rarities)

local BoxModel = {}

local rgb = Color3.fromRGB
local WHITE = rgb(255, 255, 255)
local GOLD = rgb(255, 200, 60)
local WIDTH, HEIGHT, DEPTH = 5.2, 2.6, 3.6 -- a Small box, in studs
local AJAR = math.rad(13) -- how far the Legendary and Mythic lids are lifted at the front

export type Options = {
	Mutation: string?,
	Area: number?,
	NoEffects: boolean?, -- no lights or particles (inventory previews, lots of boxes on screen)
	Scale: number?, -- on top of the box's size
}

-- Each tier's look: Body / Lid / Trim colours, the panel and its text, the ribbon (nil = none)
type Look = { Body: Color3, Lid: Color3, Trim: Color3, Panel: Color3, Text: Color3, Ribbon: Color3?, Material: Enum.Material, Label: string }
local LOOKS: { [string]: Look } = {
	Basic = { Body = rgb(255, 170, 205), Lid = rgb(255, 240, 246), Trim = rgb(240, 110, 160), Panel = WHITE, Text = rgb(240, 100, 155), Ribbon = nil, Material = Enum.Material.Plastic, Label = "FRESH" },
	Rare = { Body = rgb(80, 160, 255), Lid = rgb(240, 248, 255), Trim = rgb(40, 110, 230), Panel = rgb(215, 235, 255), Text = rgb(40, 110, 230), Ribbon = rgb(215, 222, 235), Material = Enum.Material.Plastic, Label = "RARE" },
	Epic = { Body = rgb(170, 80, 255), Lid = rgb(105, 35, 185), Trim = GOLD, Panel = rgb(200, 140, 255), Text = WHITE, Ribbon = GOLD, Material = Enum.Material.Plastic, Label = "EPIC" },
	Legendary = { Body = rgb(255, 195, 40), Lid = rgb(255, 242, 205), Trim = rgb(255, 160, 20), Panel = WHITE, Text = rgb(235, 150, 10), Ribbon = rgb(255, 120, 40), Material = Enum.Material.Foil, Label = "LEGENDARY" },
	Mythic = { Body = rgb(150, 15, 40), Lid = rgb(28, 12, 18), Trim = GOLD, Panel = rgb(60, 20, 30), Text = GOLD, Ribbon = GOLD, Material = Enum.Material.Plastic, Label = "MYTHIC" },
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

local function label(parent: BasePart, face: Enum.NormalId, text: string, color: Color3, stroke: Color3, pixels: number, name: string)
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixels
	gui.LightInfluence = 0.4
	gui.Parent = parent
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.fromScale(0.86, 0.7)
	textLabel.Position = UDim2.fromScale(0.07, 0.15)
	textLabel.Font = Enum.Font.LuckiestGuy
	textLabel.TextScaled = true
	textLabel.Text = text
	textLabel.TextColor3 = color
	textLabel.TextStrokeColor3 = stroke
	textLabel.TextStrokeTransparency = 0
	textLabel.Parent = gui
end

function BoxModel.Build(tierId: string, sizeId: string?, options: Options?): Model
	local opts: Options = options or {}
	local tier = Boxes.Tier(tierId)
	local size = Boxes.Size(sizeId)
	local mutation = Rarities.Mutation(opts.Mutation)
	local s = size.Scale * (opts.Scale or 1)
	local w, h, d = WIDTH * s, HEIGHT * s, DEPTH * s
	local base = h * 0.7 -- the box's height (the lid is the rest)
	local lidHeight = h - base
	local order = tier.Order

	local model = Instance.new("Model")
	model.Name = "DonutBox"
	local root = part(model, "Root", Vector3.new(1, 0.2, 1), CFrame.new(0, 0, 0), WHITE)
	root.Transparency = 1
	model.PrimaryPart = root

	local look = LOOKS[tier.Id] or LOOKS.Basic
	local body, lidColor, trim, material = look.Body, look.Lid, look.Trim, look.Material
	local panel, text, ribbon = look.Panel, look.Text, look.Ribbon
	if mutation.Id ~= "None" then
		body = mutation.Frosting or mutation.Color
		lidColor = body:Lerp(WHITE, 0.25)
		trim = mutation.Dough or mutation.Color:Lerp(WHITE, 0.5)
		material = mutation.Material or Enum.Material.Plastic
		panel, text = body:Lerp(WHITE, 0.5), trim
	end

	-- The box: its body, a trim band round its foot, and a dark line under the lid
	local bottom = part(model, "Bottom", Vector3.new(w, base, d), CFrame.new(0, base / 2, 0), body, material)
	part(model, "Band", Vector3.new(w * 1.02, 0.22 * s, d * 1.02), CFrame.new(0, 0.13 * s, 0), trim, Enum.Material.SmoothPlastic)
	part(model, "Gap", Vector3.new(w * 0.99, 0.07 * s, d * 0.99), CFrame.new(0, base - 0.03 * s, 0), body:Lerp(Color3.new(0, 0, 0), 0.6), Enum.Material.SmoothPlastic)
	if material == Enum.Material.Plastic then
		studs(bottom)
	end
	local labelColor = if order >= 4 then GOLD else WHITE
	label(bottom, Enum.NormalId.Front, look.Label, labelColor, body:Lerp(Color3.new(0, 0, 0), 0.55), 26, "TierText")
	label(bottom, Enum.NormalId.Back, look.Label, labelColor, body:Lerp(Color3.new(0, 0, 0), 0.55), 26, "TierTextBack")

	-- Corners (Epic and up): gold caps down the box's four edges
	if order >= 2 then
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				part(model, "Corner", Vector3.new(0.32 * s, base * 0.96, 0.32 * s), CFrame.new(sx * (w / 2 - 0.1 * s), base / 2, sz * (d / 2 - 0.1 * s)), trim, Enum.Material.Foil)
			end
		end
	end

	-- Mythic: glowing cracks down its sides
	if order >= 4 then
		for i, spot in { { -0.28, 0.4 }, { 0.12, -0.5 }, { 0.36, 0.3 } } do
			for _, sz in { -1, 1 } do
				local crack = part(model, "Crack", Vector3.new(0.09 * s, base * 0.5, 0.06 * s), CFrame.new(spot[1] * w, base * 0.48, sz * (d / 2 + 0.01 * s)) * CFrame.Angles(0, 0, spot[2] + i * 0.1), rgb(255, 120, 40), Enum.Material.Neon)
				crack.Transparency = 0.1
			end
		end
	end

	-- The lid (every part of it is named Lid... / Bow... so BoxFX can lift it off in one piece)
	local lidParts: { BasePart } = {}
	local function lidPart(name: string, sizeV: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, shape: Enum.PartType?): BasePart
		local p = part(model, name, sizeV, cf, color, mat, shape)
		table.insert(lidParts, p)
		return p
	end
	local lidY = base + lidHeight / 2
	local lid = lidPart("Lid", Vector3.new(w * 1.07, lidHeight, d * 1.07), CFrame.new(0, lidY, 0), lidColor, material)
	if material == Enum.Material.Plastic then
		studs(lid)
	end
	lidPart("LidTrim", Vector3.new(w * 1.09, 0.16 * s, d * 1.09), CFrame.new(0, base + 0.08 * s, 0), trim, Enum.Material.SmoothPlastic)
	-- the closing tab at the front, hanging over the box
	lidPart("LidTab", Vector3.new(w * 0.2, lidHeight * 0.9, 0.12 * s), CFrame.new(-w * 0.14, base + lidHeight * 0.3, -d * 0.535 - 0.06 * s), trim, Enum.Material.SmoothPlastic)
	-- a raised panel with the name on it (beside the ribbon)
	local panelPart = lidPart("LidPanel", Vector3.new(w * 0.56, 0.1 * s, d * 0.66), CFrame.new(-w * 0.14, base + lidHeight + 0.05 * s, 0), panel, Enum.Material.SmoothPlastic)
	label(panelPart, Enum.NormalId.Top, "DONUTS", text, panel:Lerp(Color3.new(0, 0, 0), 0.5), 30, "LidText")

	-- Ribbons (Rare and up): round the box and over the lid, a bow on top
	if ribbon then
		local rw = 0.5 * s
		local rx = w * 0.3
		part(model, "Ribbon", Vector3.new(rw, base * 0.98, d * 1.025), CFrame.new(rx, base / 2, 0), ribbon, Enum.Material.SmoothPlastic)
		part(model, "Ribbon", Vector3.new(w * 1.025, base * 0.98, rw), CFrame.new(0, base / 2, 0), ribbon, Enum.Material.SmoothPlastic)
		lidPart("LidRibbon", Vector3.new(rw, lidHeight + 0.04 * s, d * 1.09), CFrame.new(rx, lidY + 0.02 * s, 0), ribbon, Enum.Material.SmoothPlastic)
		lidPart("LidRibbon", Vector3.new(w * 0.29, lidHeight + 0.04 * s, rw), CFrame.new(w * 0.4, lidY + 0.02 * s, 0), ribbon, Enum.Material.SmoothPlastic)
		lidPart("LidRibbon", Vector3.new(w * 0.04, lidHeight + 0.04 * s, rw), CFrame.new(-w * 0.515, lidY + 0.02 * s, 0), ribbon, Enum.Material.SmoothPlastic)
		local bow = (if order >= 3 then 1.9 elseif order >= 2 then 1.55 else 1.0) * s
		local top = base + lidHeight
		for _, side in { -1, 1 } do
			lidPart("Bow", Vector3.new(bow, bow * 0.62, bow * 0.48), CFrame.new(rx + side * bow * 0.45, top + bow * 0.3, 0) * CFrame.Angles(0, 0, side * 0.5), ribbon, Enum.Material.SmoothPlastic)
			lidPart("Bow", Vector3.new(bow * 0.5, bow * 0.34, bow * 0.5), CFrame.new(rx + side * bow * 0.62, top + bow * 0.36, 0) * CFrame.Angles(0, 0, side * 0.5), ribbon:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.SmoothPlastic)
			if order >= 2 then
				-- tails trailing down the lid
				lidPart("BowTail", Vector3.new(bow * 0.24, 0.08 * s, bow * 0.8), CFrame.new(rx + side * bow * 0.2, top + 0.06 * s, side * bow * 0.42) * CFrame.Angles(0, side * 0.35, 0), ribbon, Enum.Material.SmoothPlastic)
			end
		end
		lidPart("BowKnot", Vector3.one * bow * 0.45, CFrame.new(rx, top + bow * 0.25, 0), ribbon:Lerp(WHITE, 0.15), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end

	-- Corners on the lid too (Epic and up), and the Mythic box's glowing gold edges
	if order >= 2 then
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				lidPart("LidCorner", Vector3.new(0.4 * s, lidHeight + 0.06 * s, 0.4 * s), CFrame.new(sx * (w * 0.535 - 0.14 * s), lidY + 0.03 * s, sz * (d * 0.535 - 0.14 * s)), trim, Enum.Material.Foil)
			end
		end
	end
	if order >= 4 then
		for _, side in { -1, 1 } do
			lidPart("LidEdge", Vector3.new(w * 1.08, 0.2 * s, 0.2 * s), CFrame.new(0, base + lidHeight, side * d * 0.54), trim, Enum.Material.Neon)
			lidPart("LidEdge", Vector3.new(0.2 * s, 0.2 * s, d * 1.08), CFrame.new(side * w * 0.54, base + lidHeight, 0), trim, Enum.Material.Neon)
			part(model, "Edge", Vector3.new(w * 1.04, 0.2 * s, 0.2 * s), CFrame.new(0, 0.3 * s, side * d * 0.52), trim, Enum.Material.Neon)
			part(model, "Edge", Vector3.new(0.2 * s, 0.2 * s, d * 1.04), CFrame.new(side * w * 0.52, 0.3 * s, 0), trim, Enum.Material.Neon)
		end
	end

	-- Legendary and Mythic: the lid sits ajar (hinged at the back) and light pours out of the gap
	local glowColor = if mutation.Light then mutation.Color elseif order >= 4 then rgb(255, 70, 50) else rgb(255, 225, 120)
	if order >= 3 then
		local hinge = CFrame.new(0, base, d / 2)
		local tilt = hinge * CFrame.Angles(AJAR, 0, 0) * hinge:Inverse()
		for _, p in lidParts do
			p.CFrame = tilt * p.CFrame
		end
		part(model, "InnerGlow", Vector3.new(w * 0.94, 0.12 * s, d * 0.94), CFrame.new(0, base - 0.02 * s, 0), glowColor, Enum.Material.Neon)
		if not opts.NoEffects then
			-- rays of light shining out of the front of the gap
			local from = Instance.new("Attachment")
			from.Position = bottom.CFrame:PointToObjectSpace(Vector3.new(0, base + 0.1 * s, -d * 0.2))
			from.Parent = bottom
			for i = -2, 2 do
				local to = Instance.new("Attachment")
				to.Position = bottom.CFrame:PointToObjectSpace(Vector3.new(i * w * 0.24, base + (1.6 + math.abs(i) * 0.2) * s, -d * 0.5 - 2.4 * s))
				to.Parent = bottom
				local ray = Instance.new("Beam")
				ray.Name = "LightRay"
				ray.Attachment0 = from
				ray.Attachment1 = to
				ray.FaceCamera = true
				ray.Segments = 1
				ray.Width0 = 0.5 * s
				ray.Width1 = 1.6 * s
				ray.LightEmission = 1
				ray.Brightness = 1.4
				ray.Color = ColorSequence.new(glowColor:Lerp(WHITE, 0.4), glowColor)
				ray.Transparency = NumberSequence.new(0.45, 1)
				ray.Parent = bottom
			end
		end
	end

	if not opts.NoEffects then
		local glow = if mutation.Light then mutation.Color elseif order >= 2 then tier.Color else nil
		if glow then
			local light = Instance.new("PointLight")
			light.Color = if order >= 3 then glowColor else glow
			light.Range = (if order >= 4 then 18 elseif order >= 3 or mutation.Light then 14 else 9) * math.sqrt(s)
			light.Brightness = if order >= 4 then 2.6 elseif order >= 3 then 2 else 1.3
			light.Parent = bottom
		end
		local rate = (if order >= 4 then 16 elseif order >= 3 then 10 elseif order >= 2 then 4 elseif order >= 1 then 1.5 else 0) + (mutation.Particles or 0) * 0.5
		if rate > 0 then
			local emitter = Instance.new("ParticleEmitter")
			emitter.Name = "Sparkles"
			emitter.Color = ColorSequence.new(if mutation.Id ~= "None" then mutation.Color else tier.Color, WHITE)
			emitter.LightEmission = 0.8
			emitter.Rate = rate
			emitter.Lifetime = NumberRange.new(0.8, 1.6)
			emitter.Speed = NumberRange.new(0.5, 2)
			emitter.SpreadAngle = Vector2.new(180, 180)
			emitter.Size = NumberSequence.new(0.35 * math.sqrt(s), 0)
			emitter.Parent = lid
		end
		if order >= 4 then
			-- embers drifting up off a Mythic box
			local embers = Instance.new("ParticleEmitter")
			embers.Name = "Embers"
			embers.Color = ColorSequence.new(rgb(255, 210, 80), rgb(255, 60, 40))
			embers.LightEmission = 1
			embers.Rate = 8
			embers.Lifetime = NumberRange.new(1, 2)
			embers.Speed = NumberRange.new(2, 4)
			embers.SpreadAngle = Vector2.new(25, 25)
			embers.Acceleration = Vector3.new(0, 2, 0)
			embers.Size = NumberSequence.new(0.25 * math.sqrt(s), 0)
			embers.Parent = lid
		end
	end

	model:SetAttribute("Tier", tier.Id)
	model:SetAttribute("BoxSize", size.Id)
	model:SetAttribute("Mutation", mutation.Id)
	if opts.Area then
		model:SetAttribute("Area", opts.Area)
	end
	-- its height (for labels and timers above it): the highest point of any visible part
	local top = h
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") and p ~= root then
			local cf, sizeV = p.CFrame, p.Size
			local half = math.abs(cf.RightVector.Y) * sizeV.X / 2 + math.abs(cf.UpVector.Y) * sizeV.Y / 2 + math.abs(cf.LookVector.Y) * sizeV.Z / 2
			top = math.max(top, cf.Position.Y + half)
		end
	end
	model:SetAttribute("Top", top)
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
