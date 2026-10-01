--[[
	GuardModel: builds the guard ("Domer") rig out of plain parts, so no uploaded assets are needed.

	Domer is pixelated and buff: every piece of him is a block (no round parts) covered in classic
	Roblox studs, with a big chest, pecs, abs, boulder shoulders and biceps.

	Used by the client (the sleeping guard on every blanket: each player sees only their own) and
	by the server (the guard that wakes up and chases you). Each area's guard gets its own outfit,
	hat and aura from Areas.luau.

	The rig is a standard R6 layout (Torso / Head / arms / legs joined by Motor6Ds) so the default R6
	walk animation works on the server's chasing guard.
]]

local Config = require(script.Parent.Config)
local Areas = require(script.Parent.Areas)

local GuardModel = {}

local rgb = Color3.fromRGB
local BLACK = rgb(25, 25, 25)
local WHITE = rgb(255, 255, 255)

export type BuildOptions = {
	Humanoid: boolean?, -- add a Humanoid (the chasing guard); the sleeping one doesn't need it
	CollisionGroup: string?,
}

local function newPart(model: Model, name: string, size: Vector3, color: Color3, cf: CFrame, group: string?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.CFrame = cf
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	if group then
		part.CollisionGroup = group
	end
	part.Parent = model
	return part
end

local function motor(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = c0
	m.C1 = c1
	m.MaxVelocity = 0.1
	m.Parent = part0
end

function GuardModel.Build(areaId: number, options: BuildOptions?): (Model, TextLabel)
	local opts: BuildOptions = options or {}
	local area = Areas.List[areaId]
	local look = area.Guard
	local skin, shirt, pants = look.Skin, look.Shirt, look.Pants
	local group = opts.CollisionGroup

	local model = Instance.new("Model")
	model.Name = Config.Guard.Name

	local root = newPart(model, "HumanoidRootPart", Vector3.new(2, 2, 1), skin, CFrame.new(0, 3, 0), group)
	root.Transparency = 1
	root.CanCollide = false
	local torso = newPart(model, "Torso", Vector3.new(2, 2, 1), shirt, CFrame.new(0, 3, 0), group)
	-- (a blocky cube head: pixelated, no round head mesh)
	local head = newPart(model, "Head", Vector3.new(1.3, 1.3, 1.3), skin, CFrame.new(0, 4.65, 0), group)
	local rightArm = newPart(model, "Right Arm", Vector3.new(1, 2, 1), skin, CFrame.new(1.5, 3, 0), group)
	local leftArm = newPart(model, "Left Arm", Vector3.new(1, 2, 1), skin, CFrame.new(-1.5, 3, 0), group)
	local rightLeg = newPart(model, "Right Leg", Vector3.new(1, 2, 1), pants, CFrame.new(0.5, 1, 0), group)
	local leftLeg = newPart(model, "Left Leg", Vector3.new(1, 2, 1), pants, CFrame.new(-0.5, 1, 0), group)
	for _, limb in { rightArm, leftArm, rightLeg, leftLeg, head } do
		limb.CanCollide = false
	end

	-- Standard R6 joints
	motor("RootJoint", root, torso, CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
	motor("Neck", torso, head, CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFrame.new(0, -0.65, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
	motor("Right Shoulder", torso, rightArm, CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	motor("Left Shoulder", torso, leftArm, CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
	motor("Right Hip", torso, rightLeg, CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	motor("Left Hip", torso, leftLeg, CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))

	-- Meshes whose Scale must survive Model:ScaleTo unchanged (the part sizes carry the scaling).
	local meshScales: { [SpecialMesh]: Vector3 } = {}

	-- Cosmetic part welded to `base` at `offset`. A non-round "ball" becomes an ellipsoid
	-- (a block with a sphere mesh), since Ball parts are always perfectly round.
	-- Pixelated: every piece is a block, whatever shape it was drawn as (balls and cylinders become
	-- cubes and square slabs of the same size).
	local function attach(base: BasePart, name: string, _shape: Enum.PartType, size: Vector3, color: Color3, offset: CFrame, material: Enum.Material?): Part
		local part = newPart(model, name, size, color, base.CFrame * offset, group)
		part.Massless = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		if material then
			part.Material = material
		end
		local weld = Instance.new("Weld")
		weld.Part0 = base
		weld.Part1 = part
		weld.C0 = offset
		weld.Parent = part
		return part
	end
	local ball, block, cyl = Enum.PartType.Ball, Enum.PartType.Block, Enum.PartType.Cylinder
	-- Cylinders point along X: this turns one upright.
	local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)

	-- Face: big bulging eyes, a sausage nose, stubbly muzzle, a little mouth
	for _, side in { -1, 1 } do
		attach(head, "Eye", ball, Vector3.one * 0.56, WHITE, CFrame.new(side * 0.27, 0.16, -0.5))
		attach(head, "Pupil", ball, Vector3.one * 0.15, BLACK, CFrame.new(side * 0.25, 0.16, -0.79))
		attach(head, "Ear", ball, Vector3.one * 0.34, skin, CFrame.new(side * 0.66, -0.05, 0.05))
		-- Zig-zag hair above the ears
		for n = 0, 2 do
			attach(head, "SideHair", block, Vector3.new(0.06, 0.16, 0.24), BLACK, CFrame.new(side * 0.64, 0.2 + n * 0.1, 0.18 + n * 0.08) * CFrame.Angles(if n % 2 == 0 then 0.6 else -0.6, 0, 0))
		end
	end
	attach(head, "Nose", ball, Vector3.new(0.3, 0.3, 0.46), skin, CFrame.new(0, -0.05, -0.72))
	attach(head, "Stubble", ball, Vector3.new(0.95, 0.62, 0.7), rgb(186, 150, 96), CFrame.new(0, -0.33, -0.33))
	attach(head, "Mouth", block, Vector3.new(0.42, 0.06, 0.05), rgb(60, 30, 20), CFrame.new(0, -0.36, -0.69))
	-- The famous two hairs
	for i, x in { -0.12, 0.12 } do
		attach(head, "Hair" .. i, block, Vector3.new(0.05, 0.42, 0.05), BLACK, CFrame.new(x, 0.78, -0.02) * CFrame.Angles(0, 0, x * -2.2))
	end

	-- Body: collared shirt, donut belly, belt, short sleeves, shoes
	-- Buff body: a wide chest tapering to the belt (V shape), pecs, a six-pack, traps
	local shade = shirt:Lerp(BLACK, 0.18)
	attach(torso, "Chest", block, Vector3.new(2.9, 1.2, 1.4), shirt, CFrame.new(0, 0.42, -0.1))
	attach(torso, "Waist", block, Vector3.new(2.2, 0.9, 1.2), shirt, CFrame.new(0, -0.5, -0.05))
	for _, side in { -1, 1 } do
		attach(torso, "Pec", block, Vector3.new(1.2, 0.75, 0.3), shade, CFrame.new(side * 0.64, 0.45, -0.85))
	end
	for row = 0, 2 do
		for _, side in { -1, 1 } do
			attach(torso, "Ab", block, Vector3.new(0.5, 0.32, 0.2), shade, CFrame.new(side * 0.28, -0.12 - row * 0.36, -0.72))
		end
	end
	attach(torso, "Traps", block, Vector3.new(1.9, 0.45, 1.0), skin, CFrame.new(0, 1.08, 0.05))
	attach(torso, "Collar", block, Vector3.new(1.3, 0.25, 0.9), shirt:Lerp(WHITE, 0.4), CFrame.new(0, 1.0, -0.2))
	attach(torso, "Belt", block, Vector3.new(2.3, 0.3, 1.3), pants:Lerp(BLACK, 0.35), CFrame.new(0, -0.95, -0.05))
	attach(torso, "Buckle", block, Vector3.new(0.4, 0.3, 0.1), rgb(255, 205, 50), CFrame.new(0, -0.95, -0.72), Enum.Material.Foil)
	for _, side in { -1, 1 } do
		local arm = if side < 0 then leftArm else rightArm
		local leg = if side < 0 then leftLeg else rightLeg
		-- boulder shoulders, a bulging bicep, a thick forearm and a big block fist
		attach(arm, "Shoulder", block, Vector3.new(1.55, 0.95, 1.5), shirt, CFrame.new(side * 0.15, 0.62, 0))
		attach(arm, "Bicep", block, Vector3.new(1.4, 0.8, 1.35), skin, CFrame.new(0, -0.05, -0.08))
		attach(arm, "Forearm", block, Vector3.new(1.25, 0.6, 1.25), skin, CFrame.new(0, -0.6, 0))
		attach(arm, "Hand", block, Vector3.one * 0.85, skin, CFrame.new(0, -1.1, 0))
		attach(leg, "Thigh", block, Vector3.new(1.2, 1.0, 1.2), pants, CFrame.new(0, 0.45, 0))
		attach(leg, "Shoe", block, Vector3.new(1.15, 0.45, 1.5), rgb(60, 60, 65), CFrame.new(0, -0.8, -0.17))
	end

	-- Hat
	local hat = look.Hat
	local top = CFrame.new(0, 0.62, 0)
	if hat == "Cap" then
		attach(head, "Hat", ball, Vector3.new(1.35, 0.7, 1.35), rgb(230, 60, 60), top)
		attach(head, "Brim", block, Vector3.new(1.0, 0.1, 0.8), rgb(230, 60, 60), CFrame.new(0, 0.55, -0.75))
	elseif hat == "Sombrero" then
		attach(head, "Hat", cyl, Vector3.new(0.12, 3.4, 3.4), rgb(230, 190, 90), top * UPRIGHT)
		attach(head, "HatTop", cyl, Vector3.new(0.9, 1.2, 1.2), rgb(230, 190, 90), CFrame.new(0, 1.05, 0) * UPRIGHT)
		attach(head, "HatBand", cyl, Vector3.new(0.2, 1.24, 1.24), rgb(200, 40, 40), CFrame.new(0, 0.78, 0) * UPRIGHT)
	elseif hat == "Party" then
		for i = 0, 3 do
			attach(head, "Hat", cyl, Vector3.new(0.3, 1.2 - i * 0.28, 1.2 - i * 0.28), if i % 2 == 0 then rgb(255, 90, 180) else rgb(90, 200, 255), CFrame.new(0, 0.75 + i * 0.3, 0) * UPRIGHT)
		end
		attach(head, "Pom", ball, Vector3.one * 0.35, rgb(255, 230, 60), CFrame.new(0, 1.95, 0))
	elseif hat == "Miner" then
		attach(head, "Hat", ball, Vector3.new(1.45, 0.8, 1.45), rgb(255, 200, 30), top)
		local lamp = attach(head, "Lamp", cyl, Vector3.new(0.25, 0.4, 0.4), rgb(255, 255, 200), CFrame.new(0, 0.75, -0.7) * CFrame.Angles(0, math.pi / 2, 0), Enum.Material.Neon)
		local light = Instance.new("SpotLight")
		light.Range = 20
		light.Brightness = 3
		light.Face = Enum.NormalId.Right
		light.Parent = lamp
	elseif hat == "Beanie" then
		attach(head, "Hat", ball, Vector3.new(1.4, 0.85, 1.4), rgb(60, 140, 220), CFrame.new(0, 0.58, 0))
		attach(head, "Pom", ball, Vector3.one * 0.45, WHITE, CFrame.new(0, 1.05, 0))
	elseif hat == "Chef" then
		attach(head, "Hat", cyl, Vector3.new(0.7, 1.3, 1.3), WHITE, CFrame.new(0, 0.9, 0) * UPRIGHT)
		attach(head, "HatPuff", ball, Vector3.new(1.7, 0.9, 1.7), WHITE, CFrame.new(0, 1.35, 0))
	elseif hat == "Visor" then
		attach(head, "Visor", block, Vector3.new(1.35, 0.32, 0.12), rgb(0, 255, 220), CFrame.new(0, 0.16, -0.78), Enum.Material.Neon)
	elseif hat == "Crown" then
		attach(head, "Hat", cyl, Vector3.new(0.35, 1.3, 1.3), rgb(255, 205, 50), CFrame.new(0, 0.75, 0) * UPRIGHT, Enum.Material.Foil)
		for i = 0, 4 do
			local angle = i / 5 * math.pi * 2
			attach(head, "Spike", block, Vector3.new(0.18, 0.4, 0.18), rgb(255, 205, 50), CFrame.new(math.cos(angle) * 0.55, 1.05, math.sin(angle) * 0.55), Enum.Material.Foil)
		end
	elseif hat == "Halo" then
		for i = 0, 11 do
			local angle = i / 12 * math.pi * 2
			attach(head, "Halo", ball, Vector3.one * 0.26, rgb(255, 240, 150), CFrame.new(math.cos(angle) * 0.75, 1.25, math.sin(angle) * 0.75), Enum.Material.Neon)
		end
	elseif hat == "Sunhat" then
		attach(head, "Hat", cyl, Vector3.new(0.1, 2.8, 2.8), rgb(245, 225, 160), top * UPRIGHT)
		attach(head, "HatTop", ball, Vector3.new(1.3, 0.8, 1.3), rgb(245, 225, 160), CFrame.new(0, 0.75, 0))
		attach(head, "Flower", ball, Vector3.one * 0.35, rgb(255, 90, 140), CFrame.new(0.55, 0.8, -0.35))
	elseif hat == "Goggles" then
		for _, side in { -1, 1 } do
			attach(head, "Goggle", cyl, Vector3.new(0.2, 0.5, 0.5), rgb(120, 220, 255), CFrame.new(side * 0.27, 0.16, -0.8) * CFrame.Angles(0, math.pi / 2, 0), Enum.Material.Glass)
		end
		attach(head, "Strap", cyl, Vector3.new(0.18, 1.32, 1.32), BLACK, CFrame.new(0, 0.16, 0) * UPRIGHT)
		attach(head, "Snorkel", cyl, Vector3.new(1.2, 0.18, 0.18), rgb(255, 200, 40), CFrame.new(0.6, 0.6, -0.2))
	elseif hat == "Pirate" then
		attach(head, "Hat", block, Vector3.new(1.9, 0.55, 0.9), BLACK, CFrame.new(0, 0.8, 0))
		attach(head, "HatTop", ball, Vector3.new(1.2, 0.7, 1.0), BLACK, CFrame.new(0, 0.95, 0))
		attach(head, "Skull", ball, Vector3.one * 0.3, WHITE, CFrame.new(0, 0.85, -0.47))
		attach(head, "EyePatch", block, Vector3.new(0.4, 0.34, 0.08), BLACK, CFrame.new(0.27, 0.16, -0.8))
	elseif hat == "Safari" then
		attach(head, "Hat", cyl, Vector3.new(0.12, 2.2, 2.2), rgb(200, 180, 120), top * UPRIGHT)
		attach(head, "HatTop", ball, Vector3.new(1.35, 0.85, 1.35), rgb(200, 180, 120), CFrame.new(0, 0.72, 0))
		attach(head, "HatBand", cyl, Vector3.new(0.15, 1.36, 1.36), rgb(110, 80, 50), CFrame.new(0, 0.66, 0) * UPRIGHT)
	elseif hat == "Helmet" then
		attach(head, "Hat", ball, Vector3.new(1.5, 0.95, 1.5), rgb(240, 120, 20), top)
		attach(head, "Brim", cyl, Vector3.new(0.08, 1.9, 1.9), rgb(240, 120, 20), CFrame.new(0, 0.5, 0) * UPRIGHT)
	elseif hat == "Propeller" then
		attach(head, "Hat", ball, Vector3.new(1.35, 0.7, 1.35), rgb(255, 60, 60), top)
		attach(head, "Stick", cyl, Vector3.new(0.35, 0.08, 0.08), rgb(255, 230, 60), CFrame.new(0, 1.05, 0) * UPRIGHT)
		local blade = attach(head, "Propeller", block, Vector3.new(1.6, 0.05, 0.25), rgb(60, 140, 255), CFrame.new(0, 1.22, 0))
		blade:SetAttribute("Spin", 12)
	elseif hat == "Witch" then
		attach(head, "Hat", cyl, Vector3.new(0.1, 2.4, 2.4), rgb(50, 30, 70), top * UPRIGHT)
		for i = 0, 3 do
			attach(head, "HatCone", cyl, Vector3.new(0.4, 1.1 - i * 0.25, 1.1 - i * 0.25), rgb(50, 30, 70), CFrame.new(0.05 * i, 0.85 + i * 0.36, 0.05 * i) * UPRIGHT)
		end
		attach(head, "HatBand", cyl, Vector3.new(0.14, 1.12, 1.12), rgb(140, 255, 120), CFrame.new(0, 0.72, 0) * UPRIGHT, Enum.Material.Neon)
	elseif hat == "Gears" then
		attach(head, "Hat", cyl, Vector3.new(0.9, 1.25, 1.25), rgb(90, 70, 50), CFrame.new(0, 1.0, 0) * UPRIGHT)
		attach(head, "HatBrim", cyl, Vector3.new(0.08, 1.9, 1.9), rgb(90, 70, 50), top * UPRIGHT)
		local gear = attach(head, "Gear", cyl, Vector3.new(0.12, 0.7, 0.7), rgb(255, 190, 60), CFrame.new(0, 1.0, -0.66) * CFrame.Angles(0, math.pi / 2, 0), Enum.Material.Foil)
		gear:SetAttribute("Spin", 3)
		for _, side in { -1, 1 } do
			attach(head, "Goggle", cyl, Vector3.new(0.18, 0.46, 0.46), rgb(255, 190, 60), CFrame.new(side * 0.27, 0.62, -0.62) * CFrame.Angles(0, math.pi / 2, 0.4), Enum.Material.Foil)
		end
	end
	-- Aura for the fancier guards in later areas
	local aura = look.Aura
	if aura == "Fire" then
		local fire = Instance.new("Fire")
		fire.Size = 5
		fire.Heat = 8
		fire.Parent = torso
	elseif aura == "Sparkles" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = shirt
		sparkles.Parent = torso
	elseif aura == "Snow" or aura == "Cosmic" or aura == "Bubbles" or aura == "Ghost" then
		local emitter = Instance.new("ParticleEmitter")
		emitter.LightEmission = if aura == "Ghost" then 0.2 else 1
		emitter.Lifetime = NumberRange.new(1, 2)
		emitter.Speed = NumberRange.new(1, 3)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new(0.4, 0)
		if aura == "Snow" then
			emitter.Color = ColorSequence.new(WHITE)
			emitter.Rate = 12
		elseif aura == "Cosmic" then
			emitter.Color = ColorSequence.new(rgb(255, 200, 255))
			emitter.Rate = 30
		elseif aura == "Bubbles" then
			emitter.Color = ColorSequence.new(rgb(200, 240, 255))
			emitter.Rate = 10
			emitter.Acceleration = Vector3.new(0, 4, 0)
			emitter.Size = NumberSequence.new(0.3, 0.5)
			emitter.Transparency = NumberSequence.new(0.4, 1)
		else -- Ghost
			emitter.Color = ColorSequence.new(rgb(170, 255, 170))
			emitter.Rate = 8
			emitter.Size = NumberSequence.new(0.8, 1.6)
			emitter.Transparency = NumberSequence.new(0.6, 1)
			emitter.Acceleration = Vector3.new(0, 2, 0)
		end
		emitter.Parent = torso
	end
	if aura == "Neon" or aura == "Cosmic" or aura == "Ghost" then
		local light = Instance.new("PointLight")
		light.Color = if aura == "Ghost" then rgb(140, 255, 140) else shirt
		light.Range = 16
		light.Brightness = 2
		light.Parent = torso
		if aura ~= "Ghost" then
			torso.Material = Enum.Material.Neon
		end
	end
	if aura == "Cosmic" then
		local highlight = Instance.new("Highlight")
		highlight.FillTransparency = 1
		highlight.OutlineColor = rgb(255, 220, 255)
		highlight.Parent = model
	end

	if opts.Humanoid then
		local humanoid = Instance.new("Humanoid")
		humanoid.RigType = Enum.HumanoidRigType.R6
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
		humanoid.MaxHealth = math.huge
		humanoid.Health = math.huge
		humanoid.UseJumpPower = true
		humanoid.JumpPower = 45
		humanoid.Parent = model
		local animator = Instance.new("Animator")
		animator.Parent = humanoid
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	end

	-- Made of studs: every visible part gets the classic studded surface on all six sides
	for _, part in model:GetDescendants() do
		if part:IsA("Part") and part ~= root then
			part.Shape = Enum.PartType.Block
			for _, face in { "TopSurface", "BottomSurface", "FrontSurface", "BackSurface", "LeftSurface", "RightSurface" } do
				(part :: any)[face] = Enum.SurfaceType.Studs
			end
			if part.Material == Enum.Material.SmoothPlastic then
				part.Material = Enum.Material.Plastic
			end
		end
	end

	model.PrimaryPart = root
	model:ScaleTo(Config.Guard.Scale)
	for m, scale in meshScales do
		m.Scale = scale
	end

	-- Name tag + status line ("Zzz", "D'OH!")
	local tag = Instance.new("BillboardGui")
	tag.Name = "GuardTag"
	tag.Size = UDim2.fromScale(12, 3.2)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 2.4 * Config.Guard.Scale, 0)
	tag.MaxDistance = 160
	tag.LightInfluence = 0
	tag.Parent = head
	local function label(name: string, text: string, color: Color3, y: number, h: number): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, h)
		l.Position = UDim2.fromScale(0, y)
		l.Font = Enum.Font.LuckiestGuy
		l.TextScaled = true
		l.Text = text
		l.TextColor3 = color
		l.TextStrokeTransparency = 0
		l.Parent = tag
		return l
	end
	label("Title", `{look.Title} {Config.Guard.Name}`, rgb(255, 230, 60), 0.5, 0.5)
	local status = label("Status", "Zzz", rgb(180, 220, 255), 0, 0.5)

	model:SetAttribute("Area", areaId)
	return model, status
end

-- Pose for a guard sleeping on his blanket at `home` (a CFrame on the floor).
function GuardModel.SleepCFrame(home: CFrame): CFrame
	return home * CFrame.new(0, 0.2 + 0.55 * Config.Guard.Scale, 0) * CFrame.Angles(math.rad(90), 0, 0)
end

function GuardModel.StandCFrame(home: CFrame): CFrame
	return home * CFrame.new(0, 3 * Config.Guard.Scale + 0.3, 0)
end

return GuardModel
