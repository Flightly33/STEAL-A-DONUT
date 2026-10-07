--[[
	BlackHoleModel: a black hole built from parts and beams, used in The Black Hole's sky and behind
	the window of its secret lab.

	  Core        - the shadow: a black Neon ball (Neon ignores lighting, so it stays pitch black),
	                outlined by a Highlight so the photon ring stays sharp at any distance
	  Horizon     - a ForceField shell whose animated shimmer glows round the shadow's edge
	  Disk        - stacked Neon discs, white-hot inside through gold, orange and red to purple dust,
	                with dark lanes between the bands and a ForceField haze round the edge
	  Streaks     - thin glowing rings on the disk with scrolling smoke textures: the gas flowing
	                round, inner rings faster, brighter on the side coming towards you (Doppler)
	  Lens        - rings that always face the camera (client/BlackHoleFX turns them): the photon
	                ring, and the far side of the disk bent up over the top and under the bottom
	  Hot spots   - bright clumps orbiting in the disk with glowing trails (moved by the client)
	  Swirl       - four spiral arms of glowing gas winding in through the disk; the client spins
	                them, so you can see the whole disk turning
	  Jets        - blue-white jets out of both poles, with sparks shooting along them
	  Inflow      - sparks and dust spiralling in (a spinning emitter with LockedToPart)
	  Star        - optional: a star being torn apart, its gas streaming into the disk

	Every part is anchored and nothing is welded, so MapBuilder can shift the whole model to its
	world like any other decoration. The disk's frame is the invisible DiskFrame part (the disk lies
	in its XZ plane, Y is the spin axis) and the client animates everything relative to it.
]]

local CollectionService = game:GetService("CollectionService")

local Build = require(script.Parent.Build)

local BlackHoleModel = {}

local rgb = Color3.fromRGB
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local TAU = math.pi * 2

export type Options = {
	View: Vector3?, -- direction from the hole towards where people usually watch it from
	Tilt: number?, -- degrees the disk leans towards the viewer (you see its top a little)
	Roll: number?, -- degrees the disk is rolled to one side
	JetLength: number?, -- in shadow radii
	Star: boolean?, -- add a star being torn apart, feeding the disk
}

-- A circle drawn with beams is 8 cubic Bézier arcs of 45 degrees. HANDLE is how far each arc's
-- control points sit from its ends, per stud of radius (4/3 * tan(arc / 4)).
local ARCS = 8
local HANDLE = 4 / 3 * math.tan(math.pi / (2 * ARCS))

type Ring = {
	Radius: number,
	Lift: number?, -- off the plane (towards the camera for the lens)
	Width: (angle: number) -> number,
	Color: (angle: number) -> Color3,
	Transparency: (angle: number) -> number,
	Texture: string?,
	TextureLength: number?,
	TextureSpeed: number?,
	Brightness: number?,
	ZOffset: number?,
}

-- Brightness is a newer property, so set it where it exists.
local function setBrightness(instance: Instance, value: number)
	pcall(function()
		(instance :: any).Brightness = value
	end)
end

local function attach(holder: BasePart, name: string, cf: CFrame): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.CFrame = cf
	attachment.Parent = holder
	return attachment
end

-- A glowing beam from one attachment to another. A map baked to a file can't keep the references,
-- so the attachments' names are stored too and MapBuilder reconnects them.
local function beam(parent: Instance, from: Attachment, to: Attachment): Beam
	local b = Instance.new("Beam")
	b.Attachment0 = from
	b.Attachment1 = to
	b:SetAttribute("From", from.Name)
	b:SetAttribute("To", to.Name)
	b.FaceCamera = true
	b.LightEmission = 1
	b.LightInfluence = 0
	b.Segments = 12
	b.Parent = parent
	return b
end

-- Where a circle point is in its holder's space, with the X axis along the circle (so the beams
-- curve round it). The disk's circles lie in the XZ plane and go round the same way
-- CFrame.Angles(0, angle, 0) turns; the lens's lie in the XY plane, facing the camera (-Z).
local function circlePoint(plane: string, radius: number, angle: number, lift: number): CFrame
	local c, s = math.cos(angle), math.sin(angle)
	if plane == "Disk" then
		return CFrame.fromMatrix(Vector3.new(c * radius, lift, -s * radius), Vector3.new(-s, 0, -c), Vector3.yAxis)
	end
	return CFrame.fromMatrix(Vector3.new(c * radius, s * radius, -lift), Vector3.new(-s, c, 0), Vector3.zAxis)
end

local function beamRing(holder: BasePart, name: string, plane: string, ring: Ring)
	local points: { Attachment } = {}
	for i = 0, ARCS - 1 do
		table.insert(points, attach(holder, name .. i, circlePoint(plane, ring.Radius, i / ARCS * TAU, ring.Lift or 0)))
	end
	for i = 0, ARCS - 1 do
		local a0, a1 = i / ARCS * TAU, (i + 1) / ARCS * TAU
		local b = beam(holder, points[i + 1], points[(i + 1) % ARCS + 1])
		b.CurveSize0 = ring.Radius * HANDLE
		b.CurveSize1 = ring.Radius * HANDLE
		b.Width0 = ring.Width(a0)
		b.Width1 = ring.Width(a1)
		b.Color = ColorSequence.new(ring.Color(a0), ring.Color(a1))
		b.Transparency = NumberSequence.new(math.clamp(ring.Transparency(a0), 0, 1), math.clamp(ring.Transparency(a1), 0, 1))
		b.Segments = 14
		if ring.Texture then
			b.Texture = ring.Texture
			b.TextureMode = Enum.TextureMode.Wrap
			b.TextureLength = ring.TextureLength or 4
			b.TextureSpeed = ring.TextureSpeed or 0
		end
		b.ZOffset = ring.ZOffset or 0
		setBrightness(b, ring.Brightness or 2)
	end
end

-- A glowing ring of beams round `holder`, in its XZ plane (always drawn facing the camera).
function BlackHoleModel.Ring(holder: BasePart, name: string, radius: number, width: number, color: Color3, transparency: number, textureSpeed: number?)
	beamRing(holder, name, "Disk", {
		Radius = radius,
		Width = function()
			return width
		end,
		Color = function()
			return color
		end,
		Transparency = function()
			return transparency
		end,
		Texture = if textureSpeed then SMOKE else nil,
		TextureLength = radius * 0.8,
		TextureSpeed = textureSpeed,
		Brightness = 2,
	})
end

-- How much of a point's light comes towards you, from 0 (moving away) to 1 (coming towards you).
-- The disk turns so that its +X side comes towards the viewer.
local function doppler(angle: number): number
	return 0.5 + 0.5 * math.cos(angle)
end

local WHITE = Color3.new(1, 1, 1)
local EMBER = rgb(120, 20, 40)
local function shifted(color: Color3, angle: number): Color3
	local d = doppler(angle)
	return if d > 0.5 then color:Lerp(WHITE, (d - 0.5) * 0.9) else color:Lerp(EMBER, (0.5 - d) * 0.9)
end

type Band = { Radius: number, Color: Color3, Transparency: number }

-- The disk's bands, outside in (radius in shadow radii)
local BANDS: { Band } = {
	{ Radius = 4.6, Color = rgb(110, 46, 170), Transparency = 0.55 },
	{ Radius = 3.8, Color = rgb(176, 48, 92), Transparency = 0.2 },
	{ Radius = 3.12, Color = rgb(236, 88, 44), Transparency = 0 },
	{ Radius = 2.62, Color = rgb(255, 134, 50), Transparency = 0 },
	{ Radius = 2.18, Color = rgb(255, 186, 92), Transparency = 0 },
	{ Radius = 1.78, Color = rgb(255, 226, 160), Transparency = 0 },
	{ Radius = 1.45, Color = rgb(255, 250, 238), Transparency = 0 },
}

type Streak = { Radius: number, Color: Color3, Width: number, Transparency: number }

-- Thin flowing rings on top of the disk (radius and width in shadow radii)
local STREAKS: { Streak } = {
	{ Radius = 1.33, Color = rgb(255, 246, 228), Width = 0.06, Transparency = 0.05 },
	{ Radius = 1.62, Color = rgb(255, 228, 170), Width = 0.07, Transparency = 0.15 },
	{ Radius = 1.98, Color = rgb(255, 196, 110), Width = 0.08, Transparency = 0.2 },
	{ Radius = 2.4, Color = rgb(255, 150, 70), Width = 0.1, Transparency = 0.25 },
	{ Radius = 2.86, Color = rgb(255, 110, 60), Width = 0.1, Transparency = 0.3 },
	{ Radius = 3.45, Color = rgb(220, 70, 110), Width = 0.12, Transparency = 0.4 },
	{ Radius = 4.2, Color = rgb(150, 80, 230), Width = 0.16, Transparency = 0.55 },
}

-- How fast gas orbits at a radius (inner orbits are faster, like planets), in radians per second
local function orbitSpeed(radius: number, r: number): number
	return 0.9 * (radius / (1.4 * r)) ^ -1.5
end

function BlackHoleModel.Build(parent: Instance, center: Vector3, scale: number, options: Options?): Model
	local opts: Options = options or {}
	local r = 11 * scale -- the shadow's radius
	local model = Instance.new("Model")
	model.Name = "BlackHole"
	local function part(props: Build.Props): BasePart
		props.Parent = model
		local p = Build.Decor(props)
		p.CastShadow = false
		return p
	end

	-- Frames: `face` looks at the viewer (right = +X, up = +Y); the disk leans towards them a little
	local view = (opts.View or Vector3.new(0, 0, -1)).Unit
	local back = -view
	local right = Vector3.yAxis:Cross(back).Unit
	local face = CFrame.fromMatrix(center, right, back:Cross(right), back)
	local disk = face * CFrame.Angles(0, 0, math.rad(opts.Roll or 7)) * CFrame.Angles(-math.rad(opts.Tilt or 12), 0, 0)

	-- The shadow, its glowing edge and its light
	local core = part({ Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.one * r * 2, CFrame = disk, Color = rgb(0, 0, 0), Material = Enum.Material.Neon })
	part({ Name = "Horizon", Shape = Enum.PartType.Ball, Size = Vector3.one * r * 2.14, CFrame = disk, Color = rgb(255, 140, 60), Material = Enum.Material.ForceField, Transparency = 0.4 })
	local outline = Instance.new("Highlight")
	outline.Name = "PhotonRing"
	outline.Adornee = core
	outline.FillTransparency = 1
	outline.OutlineColor = rgb(255, 236, 200)
	outline.OutlineTransparency = 0
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = core
	local glow = Instance.new("PointLight")
	glow.Name = "Glow"
	glow.Color = rgb(255, 170, 90)
	glow.Range = math.min(60, r * 6)
	glow.Brightness = 1.8
	glow.Parent = core

	-- The accretion disk: discs stacked outside-in (each a little higher, so the inner bands sit on
	-- top), mirrored underneath, with a dark lane between neighbouring bands
	local frame = part({ Name = "DiskFrame", Size = Vector3.one, CFrame = disk, Transparency = 1 })
	local layers: { Band } = {}
	for i, band in BANDS do
		table.insert(layers, band)
		local inner = BANDS[i + 1]
		if inner and band.Transparency == 0 then
			table.insert(layers, { Radius = inner.Radius + 0.05, Color = band.Color:Lerp(Color3.new(0, 0, 0), 0.55), Transparency = 0 })
		end
	end
	local gap = r * 0.006
	for _, side in { 1, -1 } do
		for i, layer in layers do
			part({
				Name = "Disk", Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(r * 0.004, layer.Radius * r * 2, layer.Radius * r * 2),
				CFrame = disk * CFrame.new(0, side * i * gap, 0) * CFrame.Angles(0, 0, math.pi / 2),
				Color = layer.Color, Material = Enum.Material.Neon, Transparency = layer.Transparency,
			})
		end
	end
	part({
		Name = "DiskHaze", Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(r * 0.004, r * 10.6, r * 10.6),
		CFrame = disk * CFrame.Angles(0, 0, math.pi / 2),
		Color = rgb(150, 80, 255), Material = Enum.Material.ForceField, Transparency = 0.35,
	})
	-- Streaks: lifted in front of the disk's surface (ZOffset) so they're never buried in it
	for i, streak in STREAKS do
		local speed = orbitSpeed(streak.Radius * r, r)
		beamRing(frame, "Streak" .. i .. "_", "Disk", {
			Radius = streak.Radius * r,
			Width = function()
				return streak.Width * r
			end,
			Color = function(angle)
				return shifted(streak.Color, angle)
			end,
			Transparency = function(angle)
				return streak.Transparency + (1 - doppler(angle)) * 0.35
			end,
			Texture = SMOKE,
			TextureLength = r * 0.9,
			TextureSpeed = speed * streak.Radius / 0.9,
			Brightness = 1.4,
			ZOffset = r * 0.12,
		})
	end

	-- The lens: light from the far side of the disk bent round the shadow, always facing the camera.
	-- Its rings sit a little in front of the centre so they stay outside the shadow's silhouette.
	local lens = part({ Name = "Lens", Size = Vector3.one, CFrame = face, Transparency = 1 })
	local lift = r * 0.25
	local function top(angle: number): number
		return math.max(0, math.sin(angle))
	end
	beamRing(lens, "Photon", "Lens", {
		Radius = r * 1.05, Lift = lift,
		Width = function()
			return r * 0.05
		end,
		Color = function(angle)
			return shifted(rgb(255, 244, 222), angle)
		end,
		Transparency = function(angle)
			return (1 - doppler(angle)) * 0.25
		end,
		Brightness = 2.2,
	})
	beamRing(lens, "Inner", "Lens", {
		Radius = r * 1.12, Lift = lift,
		Width = function()
			return r * 0.16
		end,
		Color = function(angle)
			return shifted(rgb(255, 170, 80), angle)
		end,
		Transparency = function(angle)
			return 0.35 + (1 - doppler(angle)) * 0.3
		end,
		Texture = SMOKE, TextureLength = r * 0.8, TextureSpeed = 0.9,
		Brightness = 1.5,
	})
	beamRing(lens, "Arc", "Lens", {
		Radius = r * 1.34, Lift = lift,
		Width = function(angle)
			return r * (0.14 + 0.36 * top(angle) ^ 1.5)
		end,
		Color = function(angle)
			return shifted(rgb(255, 150, 60):Lerp(rgb(255, 214, 140), top(angle)), angle)
		end,
		Transparency = function(angle)
			return 0.15 + (1 - top(angle)) * 0.35 + (1 - doppler(angle)) * 0.2
		end,
		Texture = SMOKE, TextureLength = r * 1.1, TextureSpeed = 0.7,
		Brightness = 1.6,
	})
	beamRing(lens, "Echo", "Lens", {
		Radius = r * 1.62, Lift = lift,
		Width = function(angle)
			return r * (0.05 + 0.1 * top(angle))
		end,
		Color = function(angle)
			return shifted(rgb(255, 130, 70), angle)
		end,
		Transparency = function(angle)
			return 0.45 + (1 - top(angle)) * 0.3
		end,
		Texture = SMOKE, TextureLength = r * 1.4, TextureSpeed = 0.5,
		Brightness = 1.2,
	})
	beamRing(lens, "Einstein", "Lens", {
		Radius = r * 2.5, Lift = lift,
		Width = function()
			return r * 0.035
		end,
		Color = function()
			return rgb(205, 225, 255)
		end,
		Transparency = function()
			return 0.75
		end,
		Texture = SPARKLE, TextureLength = r * 0.4, TextureSpeed = 0.15,
		Brightness = 1,
	})

	-- Jets out of both poles
	local jetLength = (opts.JetLength or 8) * r
	for _, side in { 1, -1 } do
		local tag = if side > 0 then "JetN" else "JetS"
		local along = Vector3.new(0, side, 0)
		local base = attach(frame, tag .. "0", CFrame.fromMatrix(along * r * 1.08, along, Vector3.xAxis))
		local tip = attach(frame, tag .. "1", CFrame.fromMatrix(along * jetLength, along, Vector3.xAxis))
		local jet = beam(frame, base, tip)
		jet.Width0 = r * 0.2
		jet.Width1 = r * 0.8
		jet.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(235, 250, 255)), ColorSequenceKeypoint.new(0.4, rgb(120, 200, 255)), ColorSequenceKeypoint.new(1, rgb(120, 90, 255)) })
		jet.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.6, 0.45), NumberSequenceKeypoint.new(1, 1) })
		jet.Texture = SMOKE
		jet.TextureMode = Enum.TextureMode.Wrap
		jet.TextureLength = r * 1.5
		jet.TextureSpeed = 1.4
		setBrightness(jet, 1.6)
		local sheath = beam(frame, base, tip)
		sheath.Width0 = r * 0.5
		sheath.Width1 = r * 2.6
		sheath.Color = ColorSequence.new(rgb(110, 170, 255), rgb(150, 80, 255))
		sheath.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.5, 0.75), NumberSequenceKeypoint.new(1, 1) })
		sheath.Texture = SMOKE
		sheath.TextureMode = Enum.TextureMode.Wrap
		sheath.TextureLength = r * 2.5
		sheath.TextureSpeed = 0.8
		setBrightness(sheath, 1.2)
	end
	local jets = part({ Name = "JetEmitter", Size = Vector3.one * r * 0.3, CFrame = disk, Transparency = 1 })
	for _, direction in { Enum.NormalId.Top, Enum.NormalId.Bottom } do
		local sparks = Instance.new("ParticleEmitter")
		sparks.Name = "JetSparks"
		sparks.EmissionDirection = direction
		sparks.Rate = 20
		sparks.Lifetime = NumberRange.new(1.6, 2.2)
		sparks.Speed = NumberRange.new(r * 3, r * 4)
		sparks.SpreadAngle = Vector2.new(3, 3)
		sparks.Size = NumberSequence.new(math.min(100, r * 0.25), math.min(100, r * 0.8))
		sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(0.7, 0.6), NumberSequenceKeypoint.new(1, 1) })
		sparks.Color = ColorSequence.new(rgb(200, 240, 255), rgb(140, 90, 255))
		sparks.LightEmission = 1
		sparks.Brightness = 1.2
		sparks.Parent = jets
	end

	-- Matter spiralling in: emitted round the rim and pulled inwards while the client turns the
	-- emitter (LockedToPart makes the sparks turn with it), plus a slow swirl of dust
	local inflow = part({ Name = "Inflow", Size = Vector3.new(r * 8.8, 0.2, r * 8.8), CFrame = disk, Transparency = 1 })
	inflow:SetAttribute("Spin", 0.5)
	local infall = Instance.new("ParticleEmitter")
	infall.Name = "Infall"
	infall.Shape = Enum.ParticleEmitterShape.Disc
	infall.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	infall.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	infall.EmissionDirection = Enum.NormalId.Top
	infall.LockedToPart = true
	infall.Rate = 70
	infall.Lifetime = NumberRange.new(2.4, 2.8)
	infall.Speed = NumberRange.new(r * 1.1, r * 1.25)
	infall.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, r * 0.07), NumberSequenceKeypoint.new(0.7, r * 0.12), NumberSequenceKeypoint.new(1, r * 0.02) })
	infall.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(200, 90, 255)), ColorSequenceKeypoint.new(0.5, rgb(255, 150, 70)), ColorSequenceKeypoint.new(1, rgb(255, 245, 220)) })
	infall.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.15), NumberSequenceKeypoint.new(0.85, 0.1), NumberSequenceKeypoint.new(1, 1) })
	infall.Texture = SPARKLE
	infall.LightEmission = 1
	infall.Brightness = 1.5
	infall.Parent = inflow
	local dust = Instance.new("ParticleEmitter")
	dust.Name = "Dust"
	dust.Shape = Enum.ParticleEmitterShape.Disc
	dust.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	dust.EmissionDirection = Enum.NormalId.Top
	dust.LockedToPart = true
	dust.Rate = 8
	dust.Lifetime = NumberRange.new(5, 7)
	dust.Speed = NumberRange.new(0)
	dust.Rotation = NumberRange.new(0, 360)
	dust.RotSpeed = NumberRange.new(-10, 10)
	dust.Size = NumberSequence.new(math.min(100, r * 0.8), math.min(100, r * 1.6))
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.82), NumberSequenceKeypoint.new(0.7, 0.85), NumberSequenceKeypoint.new(1, 1) })
	dust.Color = ColorSequence.new(rgb(160, 70, 255), rgb(255, 120, 60))
	dust.Texture = SMOKE
	dust.LightEmission = 0.7
	dust.Parent = inflow

	-- Hot spots: bright clumps orbiting in the inner disk (the client moves them), with trails
	local rng = Random.new(math.floor(math.abs(center.X) * 7 + math.abs(center.Y) * 3 + math.abs(center.Z) * 13))
	for _ = 1, 7 do
		local radius = r * rng:NextNumber(1.35, 2.5)
		local angle = rng:NextNumber(0, TAU)
		local size = r * rng:NextNumber(0.14, 0.24)
		local spot = part({
			Name = "HotSpot", Shape = Enum.PartType.Ball, Size = Vector3.one * size,
			CFrame = disk * CFrame.Angles(0, angle, 0) * CFrame.new(radius, 0, 0),
			Color = rgb(255, 240, 210):Lerp(rgb(255, 170, 90), rng:NextNumber()), Material = Enum.Material.Neon,
		})
		spot:SetAttribute("Radius", radius)
		spot:SetAttribute("Angle", angle)
		spot:SetAttribute("Speed", orbitSpeed(radius, r))
		local trail = Instance.new("Trail")
		trail.Attachment0 = attach(spot, "TrailTop", CFrame.new(0, size * 0.4, 0))
		trail.Attachment1 = attach(spot, "TrailBottom", CFrame.new(0, -size * 0.4, 0))
		trail:SetAttribute("From", "TrailTop")
		trail:SetAttribute("To", "TrailBottom")
		trail.Lifetime = 0.7
		trail.FaceCamera = true
		trail.LightEmission = 1
		trail.Color = ColorSequence.new(rgb(255, 220, 160), rgb(255, 90, 50))
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.WidthScale = NumberSequence.new(1, 0.2)
		setBrightness(trail, 1.3)
		trail.Parent = spot
	end

	-- Spiral arms: gas winding in from the edge of the disk to the shadow, purple outside and
	-- white-hot inside, its smoke flowing inwards. The client spins the Swirl part (and the arms
	-- with it), the same way as the hot spots orbit.
	local swirl = part({ Name = "Swirl", Size = Vector3.one, CFrame = disk, Transparency = 1 })
	swirl:SetAttribute("Spin", 0.3)
	local STEPS = 9
	for arm = 0, 3 do
		local previous: Attachment? = nil
		for i = 0, STEPS do
			local k = i / STEPS
			local radius = r * (4.3 - 2.95 * k)
			local angle = arm / 4 * TAU + k * math.rad(220)
			local point = attach(swirl, `Arm{arm}_{i}`, CFrame.new(math.cos(angle) * radius, r * 0.02, -math.sin(angle) * radius))
			if previous then
				local k0 = (i - 1) / STEPS
				local b = beam(swirl, previous, point)
				b.Width0 = r * (0.55 - 0.4 * k0)
				b.Width1 = r * (0.55 - 0.4 * k)
				b.Color = ColorSequence.new(rgb(150, 70, 255):Lerp(rgb(255, 236, 200), k0), rgb(150, 70, 255):Lerp(rgb(255, 236, 200), k))
				b.Transparency = NumberSequence.new(0.55 - 0.3 * k0, 0.55 - 0.3 * k)
				b.Texture = SMOKE
				b.TextureMode = Enum.TextureMode.Wrap
				b.TextureLength = r * 1.4
				b.TextureSpeed = 0.7
				b.ZOffset = r * 0.14
				setBrightness(b, 1.6)
			end
			previous = point
		end
	end

	-- A star being torn apart: its gas streams round into the disk
	if opts.Star then
		local starAt = face * CFrame.new(r * 7.5, r * 2.4, r * 1.2)
		part({ Name = "Star", Shape = Enum.PartType.Ball, Size = Vector3.one * r * 1.1, CFrame = starAt, Color = rgb(255, 214, 150), Material = Enum.Material.Neon })
		part({ Name = "StarGlow", Shape = Enum.PartType.Ball, Size = Vector3.one * r * 1.5, CFrame = starAt, Color = rgb(255, 150, 60), Material = Enum.Material.ForceField, Transparency = 0.2 })
		local local0 = disk:PointToObjectSpace(starAt.Position)
		local starAngle = math.atan2(-local0.Z, local0.X)
		local joinAngle = starAngle + 1.2
		local function tangent(angle: number): Vector3
			return Vector3.new(-math.sin(angle), 0, -math.cos(angle))
		end
		local inward = -Vector3.new(local0.X, 0, local0.Z).Unit
		local out = (tangent(starAngle) * 0.7 + inward * 0.3).Unit
		local joinAt = Vector3.new(math.cos(joinAngle), 0, -math.sin(joinAngle)) * r * 4
		local from = attach(frame, "StreamFrom", CFrame.fromMatrix(local0, out, Vector3.yAxis))
		local to = attach(frame, "StreamTo", CFrame.fromMatrix(joinAt, tangent(joinAngle), Vector3.yAxis))
		for layer = 1, 2 do
			local stream = beam(frame, from, to)
			stream.CurveSize0 = r * 2.2
			stream.CurveSize1 = r * 2.2
			stream.Segments = 24
			stream.Texture = SMOKE
			stream.TextureMode = Enum.TextureMode.Wrap
			if layer == 1 then
				stream.Width0, stream.Width1 = r * 0.6, r * 0.18
				stream.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(255, 214, 150)), ColorSequenceKeypoint.new(0.5, rgb(255, 140, 60)), ColorSequenceKeypoint.new(1, rgb(255, 200, 140)) })
				stream.Transparency = NumberSequence.new(0.1, 0.35)
				stream.TextureLength = r * 1.2
				stream.TextureSpeed = 1.2
				setBrightness(stream, 1.5)
			else
				stream.Width0, stream.Width1 = r * 1.4, r * 0.5
				stream.Color = ColorSequence.new(rgb(255, 120, 60), rgb(200, 60, 120))
				stream.Transparency = NumberSequence.new(0.6, 0.8)
				stream.TextureLength = r * 2
				stream.TextureSpeed = 0.7
				setBrightness(stream, 1)
			end
		end
	end

	model.PrimaryPart = core
	CollectionService:AddTag(model, "BlackHole")
	model.Parent = parent
	return model
end

return BlackHoleModel
