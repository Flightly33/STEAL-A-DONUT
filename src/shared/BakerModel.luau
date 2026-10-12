--[[
	BakerModel: the baker who works in every base's donut shop window (client/Bakers) and hands you
	your first donut box in the opening cinematic (client/Intro).

	A friendly, round baker made of studded blocks like Domer: a tall chef's hat, a big curly
	mustache, rosy cheeks, a white jacket with a pink apron (a donut on its pocket) and grey checked
	trousers. A standard R6 layout (HumanoidRootPart, Torso, Head, arms, legs; every other piece
	welded to one of them), so Puppet can pose him.

	Faces he can pull (show/hide the named pieces): "Smile" (normally), "MouthOpen" (shouting,
	surprised).
]]

local BakerModel = {}

local rgb = Color3.fromRGB
local WHITE = rgb(250, 250, 250)
local SKIN = rgb(240, 196, 150)
local HAIR = rgb(120, 72, 38)
local APRON = rgb(255, 150, 200)
local PANTS = rgb(95, 95, 110)
local DARK = rgb(40, 28, 30)

local STUD_FACES = { "TopSurface", "BottomSurface", "FrontSurface", "BackSurface", "LeftSurface", "RightSurface" }

function BakerModel.Build(scale: number?): Model
	local model = Instance.new("Model")
	model.Name = "Baker"
	local function part(name: string, size: Vector3, color: Color3, cf: CFrame, studs: boolean?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.CFrame = cf
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if studs then
			for _, face in STUD_FACES do
				(p :: any)[face] = Enum.SurfaceType.Studs
			end
			p.Material = Enum.Material.Plastic
		end
		p.Parent = model
		return p
	end
	-- (pieces welded to a limb, `offset` from its middle)
	local function on(base: BasePart, name: string, size: Vector3, color: Color3, offset: CFrame, studs: boolean?): Part
		local p = part(name, size, color, base.CFrame * offset, studs)
		local weld = Instance.new("Weld")
		weld.Part0 = base
		weld.Part1 = p
		weld.C0 = offset
		weld.Parent = p
		return p
	end

	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), WHITE, CFrame.new(0, 3, 0))
	root.Transparency = 1
	local torso = part("Torso", Vector3.new(2, 2, 1), WHITE, CFrame.new(0, 3, 0), true)
	local head = part("Head", Vector3.new(1.3, 1.3, 1.3), SKIN, CFrame.new(0, 4.65, 0), true)
	local limbs: { [string]: Part } = {
		["Left Arm"] = part("Left Arm", Vector3.new(1, 2, 1), WHITE, CFrame.new(-1.5, 3, 0)),
		["Right Arm"] = part("Right Arm", Vector3.new(1, 2, 1), WHITE, CFrame.new(1.5, 3, 0)),
		["Left Leg"] = part("Left Leg", Vector3.new(1, 2, 1), PANTS, CFrame.new(-0.5, 1, 0), true),
		["Right Leg"] = part("Right Leg", Vector3.new(1, 2, 1), PANTS, CFrame.new(0.5, 1, 0), true),
	}
	for name, limb in limbs do
		local weld = Instance.new("Weld") -- (Puppet removes joints; this just keeps them together until then)
		weld.Part0 = torso
		weld.Part1 = limb
		weld.C0 = torso.CFrame:ToObjectSpace(limb.CFrame)
		weld.Name = name .. "Joint"
		weld.Parent = torso
	end
	local neck = Instance.new("Weld")
	neck.Part0 = torso
	neck.Part1 = head
	neck.C0 = torso.CFrame:ToObjectSpace(head.CFrame)
	neck.Parent = torso
	local rootJoint = Instance.new("Weld")
	rootJoint.Part0 = root
	rootJoint.Part1 = torso
	rootJoint.Parent = root

	-- a round belly, the apron and its pocket (with a little donut on it)
	on(torso, "Belly", Vector3.new(2.15, 1.1, 1.35), WHITE, CFrame.new(0, -0.45, -0.12), true)
	on(torso, "Apron", Vector3.new(1.7, 1.9, 0.12), APRON, CFrame.new(0, -0.3, -0.84))
	on(torso, "ApronBib", Vector3.new(1.0, 0.7, 0.1), APRON, CFrame.new(0, 0.62, -0.57))
	on(torso, "Pocket", Vector3.new(0.9, 0.55, 0.05), APRON:Lerp(WHITE, 0.35), CFrame.new(0, -0.55, -0.92))
	on(torso, "PocketDonut", Vector3.new(0.34, 0.34, 0.04), rgb(225, 165, 95), CFrame.new(0, -0.5, -0.95) * CFrame.Angles(0, 0, math.rad(45)))
	on(torso, "PocketIcing", Vector3.new(0.24, 0.24, 0.04), rgb(255, 90, 160), CFrame.new(0, -0.47, -0.96) * CFrame.Angles(0, 0, math.rad(45)))
	for _, y in { 0.35, -0.05 } do
		on(torso, "Button", Vector3.new(0.14, 0.14, 0.06), rgb(200, 200, 210), CFrame.new(0.72, y, -0.53))
	end
	on(torso, "Collar", Vector3.new(1.4, 0.25, 1.05), WHITE, CFrame.new(0, 1.0, 0))

	-- face
	for _, side in { -1, 1 } do
		on(head, "Eye", Vector3.new(0.14, 0.24, 0.05), DARK, CFrame.new(side * 0.25, 0.14, -0.66))
		on(head, "Brow", Vector3.new(0.3, 0.08, 0.05), HAIR, CFrame.new(side * 0.25, 0.36, -0.66) * CFrame.Angles(0, 0, math.rad(side * -8)))
		on(head, "Cheek", Vector3.new(0.2, 0.12, 0.04), rgb(255, 150, 160), CFrame.new(side * 0.43, -0.1, -0.66))
		on(head, "MustacheCurl", Vector3.new(0.22, 0.22, 0.1), HAIR, CFrame.new(side * 0.5, -0.12, -0.7) * CFrame.Angles(0, 0, math.rad(side * 30)))
		on(head, "Ear", Vector3.new(0.14, 0.34, 0.26), SKIN, CFrame.new(side * 0.69, 0, 0))
	end
	on(head, "Nose", Vector3.new(0.26, 0.24, 0.18), SKIN:Lerp(rgb(220, 120, 110), 0.25), CFrame.new(0, 0.0, -0.72))
	on(head, "Mustache", Vector3.new(0.8, 0.2, 0.1), HAIR, CFrame.new(0, -0.2, -0.7))
	on(head, "Smile", Vector3.new(0.34, 0.06, 0.05), rgb(150, 40, 50), CFrame.new(0, -0.4, -0.66))
	local open = on(head, "MouthOpen", Vector3.new(0.28, 0.24, 0.05), rgb(120, 30, 40), CFrame.new(0, -0.42, -0.66))
	open.Transparency = 1
	-- the chef's hat
	on(head, "HatBand", Vector3.new(1.42, 0.45, 1.42), WHITE, CFrame.new(0, 0.85, 0), true)
	on(head, "HatPuff", Vector3.new(1.75, 1.0, 1.75), WHITE, CFrame.new(0, 1.55, 0), true)
	on(head, "HatTop", Vector3.new(1.35, 0.35, 1.35), WHITE, CFrame.new(0, 2.15, 0), true)

	-- arms: white sleeves, then hands
	for _, name in { "Left Arm", "Right Arm" } do
		local arm = limbs[name]
		arm.Transparency = 1
		on(arm, "Sleeve", Vector3.new(1.08, 1.25, 1.08), WHITE, CFrame.new(0, 0.38, 0), true)
		on(arm, "Cuff", Vector3.new(1.0, 0.22, 1.0), APRON, CFrame.new(0, -0.32, 0))
		on(arm, "Forearm", Vector3.new(0.86, 0.6, 0.86), SKIN, CFrame.new(0, -0.65, 0), true)
		on(arm, "Hand", Vector3.new(0.8, 0.5, 0.8), SKIN, CFrame.new(0, -1.15, 0), true)
	end
	-- legs: shoes
	for _, name in { "Left Leg", "Right Leg" } do
		on(limbs[name], "Shoe", Vector3.new(1.05, 0.4, 1.35), DARK, CFrame.new(0, -0.82, -0.15), true)
	end

	model.PrimaryPart = root
	if scale and scale ~= 1 then
		model:ScaleTo(scale)
	end
	return model
end

return BakerModel
