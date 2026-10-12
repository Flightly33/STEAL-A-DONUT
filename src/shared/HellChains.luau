--[[
	HellChains: the hell donuts (Config.HellChains.Donuts) are held down in their pen by glowing
	chains, like a sealed demon in an anime:

	  - four iron stakes driven into the ground round the donut, a glowing shackle on each
	  - a chain from every stake to the donut (Beams, so they stay hooked on whatever the donut
	    does: client/DonutIdle has it tug at them every few seconds)
	  - a sealing circle and cracks glowing on the ground under it, embers and hellfire rising off
	    it, marks drifting up from the seal

	With the hellfire textures uploaded (Config.AnimeFX.Textures: Chain, Seal, Crack, ...) the
	chains are real chain links and the seal a drawn sealing circle. Until then: glowing beaded
	tethers, and the seal and cracks built from glowing blocks.

	HellChains.Build(model) adds all that to a pen donut that's already in place (PlotService), in
	a folder "HellChains" (anchored, not welded to the donut: only the chains' ends move with it).
	The model gets the "HellChains" tag and Chained = true.
]]

local CollectionService = game:GetService("CollectionService")

local Config = require(script.Parent.Config)
local AnimeFX = require(script.Parent.AnimeFX)

local HellChains = {}

local rgb = Color3.fromRGB
local IRON = rgb(58, 52, 60)
local IRON_DARK = rgb(34, 30, 38)
local WHITE = rgb(255, 255, 255)

local chained: { [string]: boolean } = {}
for _, id in Config.HellChains.Donuts do
	chained[id] = true
end

function HellChains.Is(donutId: string?): boolean
	return donutId ~= nil and chained[donutId] == true
end

local function block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A chain between two attachments: chain links (the uploaded texture), or a glowing beaded tether.
local function chain(parent: Instance, from: Attachment, to: Attachment, width: number)
	local c = Config.HellChains
	local links = AnimeFX.Custom("Chain")
	local colors = ColorSequence.new(c.GlowColor, c.ChainColor)
	local function beam(name: string, w: number, texture: string, length: number, transparency: number, emission: number): Beam
		local b = Instance.new("Beam")
		b.Name = name
		b.Attachment0 = from
		b.Attachment1 = to
		b.Width0, b.Width1 = w, w
		b.FaceCamera = true
		b.Segments = 12
		b.Texture = texture
		b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = length
		b.TextureSpeed = 0
		b.Color = colors
		b.LightEmission = emission
		b.LightInfluence = 0
		b.Brightness = 1.6
		b.Transparency = NumberSequence.new(transparency)
		b:SetAttribute("BaseWidth", w)
		b.Parent = parent
		return b
	end
	if links then
		-- (the strip is 4 x 1: a link every 2 widths)
		beam("Chain", width, links, width * 4, 0, 0.7)
	else
		beam("Chain", width * 0.3, "", 1, 0, 0.9)
		beam("ChainBeads", width * 0.95, "rbxasset://textures/particles/sparkles_main.dds", width * 0.9, 0.05, 0.8)
	end
end

function HellChains.Build(model: Model): Folder?
	local root = model.PrimaryPart
	if not root then
		return nil
	end
	local c = Config.HellChains
	local s = root.Size.Y / 3 -- (the donut's scale)
	local bottom = (model:GetAttribute("Bottom") :: number?) or 1.5 * s
	local here = root.CFrame
	local flat = CFrame.lookAt(here.Position, here.Position + here.LookVector * Vector3.new(1, 0, 1))
	local ground = flat * CFrame.new(0, -bottom, 0)
	local folder = Instance.new("Folder")
	folder.Name = "HellChains"
	local k = math.max(1, s * 0.75) -- (stakes and chains grow a little with the donut)
	local reach = math.clamp(3.4 * s, 2.4 * s + 1, 7)

	-- The stakes, a chain from each to the donut
	for i, corner in { Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(1, 1) } do
		local d = Vector3.new(corner.X, 0, corner.Y).Unit
		local at = ground * CFrame.new(d * reach)
		-- (leaning outwards a little, as if the chain's pulling it)
		local tilt = CFrame.lookAt(at.Position, at.Position + (at.Position - ground.Position).Unit) * CFrame.Angles(math.rad(-12), 0, 0)
		local post = block(folder, "Stake", Vector3.new(0.45, 2.6, 0.45) * k, tilt * CFrame.new(0, 0.7 * k, 0), IRON)
		post.Material = Enum.Material.Plastic
		post.TopSurface = Enum.SurfaceType.Studs
		block(folder, "StakeCap", Vector3.new(0.8, 0.3, 0.8) * k, post.CFrame * CFrame.new(0, 1.35 * k, 0), IRON_DARK)
		block(folder, "StakeFoot", Vector3.new(1.0, 0.3, 1.0) * k, at * CFrame.new(0, 0.1 * k, 0), IRON_DARK)
		-- a glowing shackle round its head (four bars), the chain hooked on it
		local shackleAt = post.CFrame * CFrame.new(0, 0.9 * k, 0)
		for side = 0, 3 do
			local turn = shackleAt * CFrame.Angles(0, side * math.pi / 2, 0)
			local bar = block(folder, "Shackle", Vector3.new(0.85, 0.18, 0.14) * k, turn * CFrame.new(0, 0, 0.36 * k), c.GlowColor, Enum.Material.Neon)
			bar.Transparency = 0.1
		end
		local stakeEnd = Instance.new("Attachment")
		stakeEnd.Name = "ChainEnd" .. i
		stakeEnd.Position = post.CFrame:PointToObjectSpace(shackleAt.Position)
		stakeEnd.Parent = post
		local donutEnd = Instance.new("Attachment")
		donutEnd.Name = "HellChain" .. i
		donutEnd.Position = Vector3.new(corner.X * 1.2 * s, 0.3 * s, corner.Y * 0.45 * s)
		donutEnd.Parent = root
		chain(post, stakeEnd, donutEnd, 0.85 * k)
		-- hellfire licking up round its foot
		local foot = block(folder, "FlameFoot", Vector3.new(0.9, 0.2, 0.9) * k, at * CFrame.new(0, 0.2 * k, 0), WHITE)
		foot.Transparency = 1
		AnimeFX.DarkFlame(foot, { c.GlowColor, c.ChainColor }, 1.4 * k, 4)
	end

	-- The seal and the cracks on the ground
	local seal = reach * 1.05
	local plate = block(folder, "SealPlate", Vector3.new(seal * 2, 0.1, seal * 2), ground * CFrame.new(0, 0.07, 0), WHITE)
	plate.Transparency = 1
	local sealImage, crackImage = AnimeFX.Custom("Seal"), AnimeFX.Custom("Crack")
	if sealImage or crackImage then
		local gui = Instance.new("SurfaceGui")
		gui.Name = "SealGui"
		gui.Face = Enum.NormalId.Top
		gui.LightInfluence = 0
		gui.Brightness = 1.5
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 20
		gui.Parent = plate
		local function image(name: string, id: string, size: number, color: Color3, z: number)
			local i = Instance.new("ImageLabel")
			i.Name = name
			i.BackgroundTransparency = 1
			i.AnchorPoint = Vector2.new(0.5, 0.5)
			i.Position = UDim2.fromScale(0.5, 0.5)
			i.Size = UDim2.fromScale(size, size)
			i.Image = id
			i.ImageColor3 = color
			i.ZIndex = z
			i.Parent = gui
		end
		if crackImage then
			image("Cracks", crackImage, 0.8, c.ChainColor, 1)
		end
		if sealImage then
			image("Seal", sealImage, 1, c.GlowColor, 2)
		end
	end
	if not sealImage then
		-- a sealing circle of glowing blocks: two rings, marks between them
		local rings = Instance.new("Model")
		rings.Name = "SealRings"
		rings.Parent = folder
		for _, ring in { { seal * 0.95, 22, 0.22 }, { seal * 0.62, 16, 0.16 } } do
			local r, n, w = ring[1], ring[2], ring[3]
			local length = 2 * math.pi * r / n * 1.04
			for j = 1, n do
				local a = (j / n) * math.pi * 2
				local seg = block(rings, "SealRing", Vector3.new(length, 0.06, w * k), ground * CFrame.Angles(0, -a, 0) * CFrame.new(0, 0.1, -r), c.GlowColor, Enum.Material.Neon)
				seg.Transparency = 0.15
			end
		end
		for j = 1, 8 do
			local a = (j / 8 + 1 / 16) * math.pi * 2
			local mark = block(rings, "SealMark", Vector3.new(0.5, 0.06, 0.5) * k, ground * CFrame.Angles(0, -a, 0) * CFrame.new(0, 0.1, -seal * 0.785) * CFrame.Angles(0, math.pi / 4, 0), c.ChainColor, Enum.Material.Neon)
			mark.Transparency = 0.2
		end
	end
	if not crackImage then
		-- cracks: jagged glowing lines running out from under the donut
		local rng = Random.new(77)
		for j = 1, 6 do
			local a = (j / 6) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
			local from = Vector3.zero
			for _ = 1, 3 do
				a += rng:NextNumber(-0.45, 0.45)
				local step = rng:NextNumber(0.9, 1.4) * s
				local to = from + Vector3.new(math.sin(a), 0, -math.cos(a)) * step
				local middle = (from + to) / 2
				local seg = block(folder, "Crack", Vector3.new(0.14 * k, 0.05, step + 0.1), ground * CFrame.lookAt(middle, to) * CFrame.new(0, 0.11, 0), c.ChainColor, Enum.Material.Neon)
				seg.Transparency = 0.1
				from = to
			end
		end
	end
	-- embers and marks rising off it, dark smoke curling up
	AnimeFX.Embers(plate, { c.ChainColor, c.GlowColor }, 0.35 * k, 6)
	AnimeFX.Runes(plate, c.GlowColor, 0.9 * k, 1.2)
	AnimeFX.Wisps(plate, rgb(60, 18, 20), 2.4 * k, 1)
	-- (the burst when it tugs: client/HellChainsFX sets it off)
	local core = block(folder, "TugCore", Vector3.one * 0.2, flat, WHITE)
	core.Transparency = 1
	AnimeFX.Burst(core, { c.ChainColor, c.GlowColor }, 2.2 * s)
	AnimeFX.Impact(core, { c.GlowColor }, 1.2 * s)

	folder.Parent = model
	model:SetAttribute("Chained", true)
	CollectionService:AddTag(model, "HellChains")
	return folder
end

return HellChains
