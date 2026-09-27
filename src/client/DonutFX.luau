--[[
	DonutFX: the moving parts of the mystical donut themes (see FXThemes.luau), animated by every client
	for the rare donuts near its camera - in the lane, on bases, on podiums and on players' heads:
	  * lightning: crackling arcs (Secret / Rainbow), bolts rising from the ground (Mythic),
	    strikes from the sky with a shockwave (Divine)
	  * magic circles on the ground: rings, dashed arcs and glyphs turning in opposite directions
	  * comets with glowing trails orbiting the donut
	  * shockwaves bursting along the ground
	  * pulsing lights (a heartbeat for Mythic, rainbow for Secret / Rainbow), glowing outlines,
	    spinning light rays, and the donut itself changing colour (galaxy, rainbow, throbbing red)
	Everything here exists only on this client (nothing is replicated) and is removed again when you
	walk away. Only the closest donuts get the full show.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FXThemes = require(Shared.FXThemes)

local DonutFX = {}

local player = Players.LocalPlayer :: Player
local RANGE = 170 -- studs from the camera
local MAX_ACTIVE = 14 -- closest donuts that get lightning, circles and comets
local MAX_OUTLINES = 6 -- Roblox can only draw a limited number of outlines at once
local MAX_BOLTS = 40
local TAU = math.pi * 2
local FLAT = CFrame.Angles(math.rad(90), 0, 0) -- lays a cylinder adornment flat on the ground

type Theme = FXThemes.Theme

type ThemeState = { Theme: Theme, Index: number, NextBolt: number, NextWave: number }

type Spinner = { Adornment: GuiBase3d, Base: CFrame, Speed: number, Theme: Theme, Hue: number, Pulse: boolean? }

type Wisp = { Part: BasePart, Trail: Trail, Axis: CFrame, Radius: number, Speed: number, Offset: number, Theme: Theme, Hue: number }

type Wave = { Adornment: CylinderHandleAdornment, Start: number, Theme: Theme, Scale: number }

type Visuals = {
	Folder: Folder,
	Anchor: BasePart?,
	Spinners: { Spinner },
	Wisps: { Wisp },
	Waves: { Wave },
	Outline: Highlight?,
}

type FX = {
	Model: Model,
	Root: BasePart,
	Scale: number,
	Ground: CFrame?, -- where the magic circle goes (nil while a donut is being carried)
	Themes: { ThemeState },
	Light: PointLight?,
	LightBrightness: number,
	LightColor: Color3,
	Bursts: { { Weld: Weld, Base: CFrame, Spin: number } },
	Frosting: { BasePart },
	FrostingColors: { Color3 },
	Dough: { BasePart },
	DoughColors: { Color3 },
	Tint: string?,
	Pulse: string?,
	OutlineTheme: Theme?,
	Visuals: Visuals?,
	Distance: number,
}

type Bolt = { Parts: { BasePart }, Light: PointLight, Born: number }

local fxs: { [Model]: FX } = {}
local bolts: { Bolt } = {}
local boltPool: { BasePart } = {}
local folder: Folder
local rng = Random.new()
local clock = 0

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local function heartbeat(t: number): number
	local u = t % 1.15
	return math.exp(-(u / 0.07) ^ 2) + 0.75 * math.exp(-((u - 0.25) / 0.07) ^ 2)
end

local function themeColor(theme: Theme, index: number, hue: number): Color3
	if theme.Rainbow then
		return Color3.fromHSV((clock * 0.18 + hue) % 1, 0.7, 1)
	end
	return theme.Colors[(index - 1) % #theme.Colors + 1]
end

local function randomColor(theme: Theme): Color3
	if theme.Rainbow then
		return Color3.fromHSV(rng:NextNumber(), 0.75, 1)
	end
	return theme.Colors[rng:NextInteger(1, #theme.Colors)]
end

local function localPart(name: string, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

--------------------------------------------------------------------------------
-- Lightning
--------------------------------------------------------------------------------
local function takeBoltPart(): BasePart
	local p = table.remove(boltPool)
	if p then
		return p
	end
	local part = localPart("Bolt", folder)
	part.Transparency = 1
	return part
end

local function spawnBolt(from: Vector3, to: Vector3, color: Color3, width: number, branch: boolean, flash: number)
	local direction = to - from
	local distance = direction.Magnitude
	if distance < 0.2 or #bolts >= MAX_BOLTS then
		return
	end
	local right = direction:Cross(Vector3.yAxis)
	if right.Magnitude < 0.01 then
		right = direction:Cross(Vector3.xAxis)
	end
	right = right.Unit
	local up = right:Cross(direction).Unit
	local segments = math.clamp(math.floor(distance / 0.9), 4, 12)
	local parts = {}
	local previous = from
	for i = 1, segments do
		local point = if i == segments
			then to
			else from + direction * (i / segments) + (right * rng:NextNumber(-1, 1) + up * rng:NextNumber(-1, 1)) * distance * 0.08
		local step = point - previous
		local part = takeBoltPart()
		part.Size = Vector3.new(width, width, step.Magnitude + width * 0.5)
		part.CFrame = CFrame.lookAt(previous + step / 2, point)
		part.Color = color
		part.Transparency = 0
		table.insert(parts, part)
		if branch and i == segments // 2 and rng:NextNumber() < 0.7 then
			spawnBolt(point, point + rng:NextUnitVector() * distance * 0.35, color, width * 0.6, false, 0)
		end
		previous = point
	end
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 10 + flash * 12
	light.Brightness = 3 + flash * 3
	light.Shadows = false
	light.Parent = parts[#parts]
	table.insert(bolts, { Parts = parts, Light = light, Born = clock })
end

local function updateBolts()
	for i = #bolts, 1, -1 do
		local bolt = bolts[i]
		local age = clock - bolt.Born
		if age > 0.17 then
			for _, part in bolt.Parts do
				part.Transparency = 1
				table.insert(boltPool, part)
			end
			bolt.Light:Destroy()
			table.remove(bolts, i)
		else
			-- flicker: on, dim, on, fade
			local transparency = if age < 0.05 then 0 elseif age < 0.08 then 0.7 elseif age < 0.13 then 0 else 0.5
			for _, part in bolt.Parts do
				part.Transparency = transparency
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Magic circles, comets, shockwaves
--------------------------------------------------------------------------------
local function ring(anchor: BasePart, radius: number, width: number, angle: number, color: Color3, transparency: number): CylinderHandleAdornment
	local a = Instance.new("CylinderHandleAdornment")
	a.Adornee = anchor
	a.Radius = radius
	a.InnerRadius = math.max(0, radius - width)
	a.Height = 0.05
	a.Angle = angle
	a.Color3 = color
	a.Transparency = transparency
	a.CFrame = FLAT
	a.Parent = anchor
	return a
end

local function buildCircle(fx: FX, visuals: Visuals, anchor: BasePart, state: ThemeState)
	local theme = state.Theme
	local sc = fx.Scale
	local radius = (3.2 + (state.Index - 1) * 1.15) * sc
	local direction = if state.Index % 2 == 0 then -1 else 1
	local function add(adornment: GuiBase3d, base: CFrame, speed: number, hue: number, pulse: boolean?)
		table.insert(visuals.Spinners, { Adornment = adornment, Base = base, Speed = speed * direction, Theme = theme, Hue = hue, Pulse = pulse })
	end
	-- Outer ring + a thin ring around it
	add(ring(anchor, radius, 0.16 * sc, 360, theme.Colors[1], 0.15), CFrame.identity, 0.4, 0)
	add(ring(anchor, radius + 0.3 * sc, 0.06 * sc, 360, themeColor(theme, 2, 0.3), 0.35), CFrame.identity, 0, 0.3)
	-- Dashed ring
	for i = 0, 5 do
		add(ring(anchor, radius - 0.45 * sc, 0.12 * sc, 30, themeColor(theme, 2, i / 6), 0.2), CFrame.Angles(0, 0, i * TAU / 6), -0.7, i / 6)
	end
	-- Inner arcs
	for i = 0, 2 do
		add(ring(anchor, radius - 1.05 * sc, 0.1 * sc, 80, themeColor(theme, 3, i / 3), 0.25), CFrame.Angles(0, 0, i * TAU / 3), 1.1, i / 3)
	end
	-- Glyph marks around the outer ring
	for i = 0, 7 do
		local glyph = Instance.new("BoxHandleAdornment")
		glyph.Adornee = anchor
		glyph.Size = Vector3.new(0.12 * sc, 0.04, 0.5 * sc)
		glyph.Color3 = theme.Colors[1]
		glyph.Transparency = 0.1
		glyph.Parent = anchor
		-- (spinners rotate their Base about the vertical; glyphs sit out on the ring)
		table.insert(visuals.Spinners, {
			Adornment = glyph,
			Base = CFrame.Angles(0, i * TAU / 8, 0) * CFrame.new(0, 0, -(radius - 0.25 * sc)),
			Speed = 0.4 * direction,
			Theme = theme,
			Hue = i / 8,
		})
	end
	-- Soft glow in the middle
	add(ring(anchor, 1.3 * sc, 1.3 * sc, 360, theme.Colors[1], 0.8), CFrame.identity, 0, 0, true)
end

local function buildWisps(fx: FX, visuals: Visuals, state: ThemeState)
	local theme = state.Theme
	local count = theme.Wisps or 0
	local sc = fx.Scale
	for i = 1, count do
		local color = themeColor(theme, i, i / count)
		local part = localPart("Comet", visuals.Folder)
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.one * 0.32 * sc
		part.Color = color
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.14 * sc, 0)
		a0.Parent = part
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.14 * sc, 0)
		a1.Parent = part
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.45
		trail.LightEmission = 1
		trail.Brightness = 3
		trail.FaceCamera = true
		trail.Color = ColorSequence.new(color)
		trail.Transparency = NumberSequence.new(0, 1)
		trail.WidthScale = NumberSequence.new(1, 0)
		trail.Parent = part
		table.insert(visuals.Wisps, {
			Part = part,
			Trail = trail,
			Axis = CFrame.Angles(rng:NextNumber(-1, 1), rng:NextNumber(0, TAU), rng:NextNumber(-1, 1)),
			Radius = (2.4 + rng:NextNumber() * 1.1) * sc,
			Speed = (1.6 + rng:NextNumber()) * (if rng:NextNumber() < 0.5 then -1 else 1),
			Offset = i / count * TAU,
			Theme = theme,
			Hue = i / count,
		})
	end
end

local function spawnWave(fx: FX, state: ThemeState)
	local visuals = fx.Visuals
	local anchor = visuals and visuals.Anchor
	if not visuals or not anchor then
		return
	end
	local a = ring(anchor, fx.Scale, 0.3 * fx.Scale, 360, randomColor(state.Theme), 0.15)
	table.insert(visuals.Waves, { Adornment = a, Start = clock, Theme = state.Theme, Scale = fx.Scale })
end

--------------------------------------------------------------------------------
-- Build / drop the per-donut visuals
--------------------------------------------------------------------------------
local function restoreColors(fx: FX)
	if fx.Tint == "Heartbeat" then
		for i, part in fx.Frosting do
			part.Color = fx.FrostingColors[i]
		end
	elseif fx.Tint then
		for i, part in fx.Dough do
			part.Color = fx.DoughColors[i]
		end
	end
end

local function dropVisuals(fx: FX)
	local visuals = fx.Visuals
	if visuals then
		visuals.Folder:Destroy()
		if visuals.Outline then
			visuals.Outline:Destroy()
		end
		fx.Visuals = nil
		restoreColors(fx)
	end
end

local function ensureVisuals(fx: FX)
	if fx.Visuals then
		return
	end
	local visualsFolder = Instance.new("Folder")
	visualsFolder.Name = fx.Model.Name
	visualsFolder.Parent = folder
	local visuals: Visuals = { Folder = visualsFolder, Anchor = nil, Spinners = {}, Wisps = {}, Waves = {}, Outline = nil }
	if fx.Ground then
		local anchor = localPart("CircleAnchor", visualsFolder)
		anchor.Transparency = 1
		anchor.Size = Vector3.one * 0.2
		anchor.CFrame = (fx.Ground :: CFrame) + Vector3.new(0, 0.07, 0)
		visuals.Anchor = anchor
	end
	for _, state in fx.Themes do
		if state.Theme.Runes and visuals.Anchor then
			buildCircle(fx, visuals, visuals.Anchor :: BasePart, state)
		end
		buildWisps(fx, visuals, state)
	end
	fx.Visuals = visuals
end

local function setOutline(fx: FX, wanted: boolean)
	local visuals = fx.Visuals
	if not visuals then
		return
	end
	if wanted and not visuals.Outline and fx.OutlineTheme then
		local highlight = Instance.new("Highlight")
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.FillTransparency = 0.82
		highlight.OutlineTransparency = 0
		highlight.Parent = fx.Model
		visuals.Outline = highlight
	elseif not wanted and visuals.Outline then
		visuals.Outline:Destroy()
		visuals.Outline = nil
	end
end

--------------------------------------------------------------------------------
-- Per-frame updates
--------------------------------------------------------------------------------
-- Cheap things for every rare donut in range: spinning rays and the pulsing light.
local function updateCheap(fx: FX)
	for _, burst in fx.Bursts do
		burst.Weld.C0 = burst.Base * CFrame.Angles(0, 0, (clock * burst.Spin) % TAU)
	end
	local light = fx.Light
	if light then
		local base = fx.LightBrightness
		local pulse = fx.Pulse
		if pulse == "Heartbeat" then
			light.Brightness = base * (0.7 + 2.6 * heartbeat(clock))
		elseif pulse == "Shimmer" then
			light.Brightness = base * (1.1 + 0.45 * math.sin(clock * 3.3) + 0.2 * math.sin(clock * 7.1))
		elseif pulse == "Hue" then
			light.Color = Color3.fromHSV((clock * 0.25) % 1, 0.8, 1)
			light.Brightness = base * 1.4
		elseif pulse == "Glow" then
			light.Brightness = base * (1 + 0.35 * math.sin(clock * 2))
		end
	end
end

local function lightningPoints(fx: FX, mode: string): (Vector3, Vector3, number, boolean, number)
	local sc = fx.Scale
	local center = fx.Root.Position + Vector3.new(0, 0.3 * sc, 0)
	local ground = fx.Ground
	local function groundPoint(radius: number): Vector3
		local angle = rng:NextNumber(0, TAU)
		if ground then
			return ground.Position + Vector3.new(math.cos(angle) * radius, 0.1, math.sin(angle) * radius)
		end
		return center + rng:NextUnitVector() * radius
	end
	if mode == "Rise" then
		return groundPoint(3 * sc), center + rng:NextUnitVector() * 1.1 * sc, 0.14 * sc, true, 0.5
	elseif mode == "Strike" then
		local from = center + Vector3.new(rng:NextNumber(-4, 4) * sc, 16 * sc, rng:NextNumber(-4, 4) * sc)
		return from, center + rng:NextUnitVector() * 0.5 * sc, 0.22 * sc, true, 1
	end
	-- Arc: crackles around the donut, sometimes grounding into the magic circle
	local from = center + rng:NextUnitVector() * 1.8 * sc
	local to = if ground and rng:NextNumber() < 0.3 then groundPoint(rng:NextNumber(2.5, 3.5) * sc) else center + rng:NextUnitVector() * 3.9 * sc
	return from, to, 0.1 * sc, rng:NextNumber() < 0.4, 0.3
end

-- The full show (only for the closest donuts).
local function updateFull(fx: FX)
	local visuals = fx.Visuals
	if not visuals then
		return
	end
	-- Magic circles
	for _, spinner in visuals.Spinners do
		local adornment = spinner.Adornment :: any
		local turn = CFrame.Angles(0, 0, (clock * spinner.Speed) % TAU)
		if adornment:IsA("BoxHandleAdornment") then
			adornment.CFrame = CFrame.Angles(0, (clock * spinner.Speed) % TAU, 0) * spinner.Base
		else
			adornment.CFrame = FLAT * turn * spinner.Base
		end
		if spinner.Theme.Rainbow then
			adornment.Color3 = Color3.fromHSV((clock * 0.18 + spinner.Hue) % 1, 0.7, 1)
		end
		if spinner.Pulse then
			adornment.Transparency = 0.8 + 0.1 * math.sin(clock * 3)
		end
	end
	-- Comets
	local center = fx.Root.Position + Vector3.new(0, 0.3 * fx.Scale, 0)
	for _, wisp in visuals.Wisps do
		local angle = clock * wisp.Speed + wisp.Offset
		local offset = wisp.Axis:VectorToWorldSpace(Vector3.new(math.cos(angle), 0, math.sin(angle))) * wisp.Radius
		wisp.Part.CFrame = CFrame.new(center + offset)
		if wisp.Theme.Rainbow then
			local color = Color3.fromHSV((clock * 0.3 + wisp.Hue) % 1, 0.7, 1)
			wisp.Part.Color = color
			wisp.Trail.Color = ColorSequence.new(color)
		end
	end
	-- Shockwaves
	for i = #visuals.Waves, 1, -1 do
		local wave = visuals.Waves[i]
		local a = (clock - wave.Start) / 0.8
		if a >= 1 then
			wave.Adornment:Destroy()
			table.remove(visuals.Waves, i)
		else
			local eased = 1 - (1 - a) ^ 3
			local radius = (0.8 + eased * 8.5) * wave.Scale
			wave.Adornment.Radius = radius
			wave.Adornment.InnerRadius = math.max(0, radius - 0.35 * wave.Scale)
			wave.Adornment.Transparency = 0.15 + 0.85 * a
		end
	end
	-- Lightning + shockwave timers
	for _, state in fx.Themes do
		local theme = state.Theme
		local lightning = theme.Lightning
		if lightning and clock >= state.NextBolt then
			state.NextBolt = clock + rng:NextNumber(lightning.Min, lightning.Max)
			local from, to, width, branch, flash = lightningPoints(fx, lightning.Mode)
			spawnBolt(from, to, randomColor(theme), width, branch, flash)
			if lightning.Mode == "Strike" then
				spawnWave(fx, state)
			end
		end
		local shock = theme.Shockwave
		if shock and clock >= state.NextWave then
			state.NextWave = clock + rng:NextNumber(shock.Min, shock.Max)
			spawnWave(fx, state)
		end
	end
	-- The donut's own colours
	local tint = fx.Tint
	if tint == "Heartbeat" and not CollectionService:HasTag(fx.Model, "DonutRainbow") then
		local beat = heartbeat(clock)
		for i, part in fx.Frosting do
			part.Color = fx.FrostingColors[i]:Lerp(Color3.fromRGB(255, 190, 190), beat * 0.7)
		end
	elseif tint == "Galaxy" then
		for i, part in fx.Dough do
			local wave = math.sin(clock * 0.9 + i * 0.55)
			part.Color = Color3.fromHSV((0.72 + 0.1 * math.sin(clock * 0.5 + i * 0.4)) % 1, 0.8, 0.32 + 0.14 * wave)
		end
	elseif tint == "Rainbow" then
		local count = #fx.Dough
		for i, part in fx.Dough do
			part.Color = Color3.fromHSV((clock * 0.2 + i / count) % 1, 0.55, 1)
		end
	end
	-- Outline colour
	local outline = visuals.Outline
	local outlineTheme = fx.OutlineTheme
	if outline and outlineTheme then
		local color = themeColor(outlineTheme, 1, 0)
		outline.OutlineColor = color
		outline.FillColor = color
		outline.OutlineTransparency = 0.15 + 0.15 * math.sin(clock * 4)
	end
end

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------
local function register(instance: Instance)
	if not instance:IsA("Model") or fxs[instance] then
		return
	end
	local model = instance
	local root = model.PrimaryPart or model:WaitForChild("Root", 5)
	if not root or not root:IsA("BasePart") or not model.Parent then
		return
	end
	local rarity = model:GetAttribute("Rarity")
	local mutation = model:GetAttribute("Mutation")
	local themes = FXThemes.For(if type(rarity) == "string" then rarity else "", if type(mutation) == "string" then mutation else nil)
	if #themes == 0 then
		return
	end
	local scale = model:GetAttribute("FXScale")
	local bottom = model:GetAttribute("Bottom")
	local sc = if type(scale) == "number" then scale else 1
	-- Read the resting position straight away (other effects start moving the donut right after).
	local ground: CFrame? = nil
	if root.Anchored then
		ground = CFrame.new(root.Position - Vector3.new(0, if type(bottom) == "number" then bottom else 1.5, 0))
	end

	local states: { ThemeState } = {}
	local tint, pulse, outlineTheme = nil, nil, nil
	for i, theme in themes do
		table.insert(states, { Theme = theme, Index = i, NextBolt = clock + rng:NextNumber(0.2, 1.5), NextWave = clock + rng:NextNumber(0.5, 3) })
		tint = theme.Tint or tint
		pulse = theme.Pulse or pulse
		if theme.Outline then
			outlineTheme = theme
		end
	end

	local bursts = {}
	local frosting, frostingColors, dough, doughColors = {}, {}, {}, {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local spin = part:GetAttribute("FXSpin")
			local weld = part:FindFirstChildOfClass("Weld")
			if type(spin) == "number" and weld then
				table.insert(bursts, { Weld = weld, Base = weld.C0, Spin = spin })
			end
			if part.Name == "Frosting" then
				table.insert(frosting, part)
				table.insert(frostingColors, part.Color)
			elseif part.Name == "Dough" then
				table.insert(dough, part)
				table.insert(doughColors, part.Color)
			end
		end
	end
	local light = root:FindFirstChildOfClass("PointLight")
	fxs[model] = {
		Model = model,
		Root = root,
		Scale = sc,
		Ground = ground,
		Themes = states,
		Light = light,
		LightBrightness = if light then light.Brightness else 1,
		LightColor = if light then light.Color else Color3.new(1, 1, 1),
		Bursts = bursts,
		Frosting = frosting,
		FrostingColors = frostingColors,
		Dough = dough,
		DoughColors = doughColors,
		Tint = tint,
		Pulse = pulse,
		OutlineTheme = outlineTheme,
		Visuals = nil,
		Distance = math.huge,
	}
end

local function unregister(instance: Instance)
	local fx = if instance:IsA("Model") then fxs[instance] else nil
	if fx then
		dropVisuals(fx)
		fxs[instance :: Model] = nil
	end
end

local function focusPosition(): Vector3?
	local camera = workspace.CurrentCamera
	if camera then
		return camera.CFrame.Position
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

function DonutFX.Init()
	folder = Instance.new("Folder")
	folder.Name = "DonutFXLocal"
	folder.Parent = workspace

	for _, instance in CollectionService:GetTagged("DonutFX") do
		task.spawn(register, instance)
	end
	CollectionService:GetInstanceAddedSignal("DonutFX"):Connect(register)
	CollectionService:GetInstanceRemovedSignal("DonutFX"):Connect(unregister)

	RunService.RenderStepped:Connect(function(dt: number)
		clock += dt
		updateBolts()
		local focus = focusPosition()
		if not focus then
			return
		end
		local near: { FX } = {}
		for model, fx in fxs do
			if not model.Parent then
				unregister(model)
				continue
			end
			fx.Distance = (fx.Root.Position - focus).Magnitude
			if fx.Distance < RANGE then
				table.insert(near, fx)
			elseif fx.Visuals then
				dropVisuals(fx)
			end
		end
		table.sort(near, function(a, b)
			return a.Distance < b.Distance
		end)
		local outlines = 0
		for rank, fx in near do
			updateCheap(fx)
			if rank <= MAX_ACTIVE then
				ensureVisuals(fx)
				local wantsOutline = fx.OutlineTheme ~= nil and outlines < MAX_OUTLINES
				if wantsOutline then
					outlines += 1
				end
				setOutline(fx, wantsOutline)
				updateFull(fx)
			elseif fx.Visuals then
				dropVisuals(fx)
			end
		end
	end)
end

return DonutFX
