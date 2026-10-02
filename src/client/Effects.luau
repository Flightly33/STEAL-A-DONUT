--[[
	Effects: purely cosmetic, client-side animation so the server never has to replicate it.
	  DonutFloat / PodiumSpin  - rare donuts bob and spin (base donuts are animated by DonutIdle)
	  DonutRainbow             - frosting cycles through the rainbow (Celestial, Secret)
	  RainbowPart / RainbowText- rainbow parts and labels
	  SpinSlow                 - floating crystals and halo rings
	  TreadmillBelt            - belt slats scroll backwards
	  Area ambience            - lighting, fog and colour grading change per area
	  Owner-only prompts       - hide Upgrade/Sell prompts on other people's donuts
	  Popups                   - "+$" above your donuts
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Areas = require(Shared.Areas)
local Format = require(Shared.Format)

local Theme = require(script.Parent.UI.Theme)
local State = require(script.Parent.State)
local AreaTracker = require(script.Parent.AreaTracker)
local Bases = require(script.Parent.Bases)

local Effects = {}

local player = Players.LocalPlayer :: Player
local ANIMATE_DISTANCE = 180

--------------------------------------------------------------------------------
-- Tag tracking helper
--------------------------------------------------------------------------------
local function track<T>(tag: string, onAdd: (Instance) -> T?): { [Instance]: T }
	local set: { [Instance]: T } = {}
	local function add(instance: Instance)
		local value = onAdd(instance)
		if value ~= nil then
			set[instance] = value
		end
	end
	for _, instance in CollectionService:GetTagged(tag) do
		task.spawn(add, instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		set[instance] = nil
	end)
	return set
end

local function cameraPosition(): Vector3
	local camera = workspace.CurrentCamera
	return if camera then camera.CFrame.Position else Vector3.zero
end

--------------------------------------------------------------------------------
-- Donut motion + rainbow
--------------------------------------------------------------------------------
type Floater = { Root: BasePart, Base: CFrame, Phase: number, Spin: number, Bob: number }

local function makeFloater(spin: number, bob: number): (Instance) -> Floater?
	return function(instance: Instance): Floater?
		if not instance:IsA("Model") or CollectionService:HasTag(instance, "BaseDonut") or instance:GetAttribute("Follower") then
			return nil
		end
		local root = instance.PrimaryPart or instance:WaitForChild("Root", 5)
		if not root or not root:IsA("BasePart") then
			return nil
		end
		return { Root = root, Base = root.CFrame, Phase = math.random() * 6, Spin = spin, Bob = bob }
	end
end

type Rainbow = { Parts: { BasePart }, Center: BasePart? }

local function makeRainbowModel(instance: Instance): Rainbow?
	local parts = {}
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") and (descendant.Name == "Frosting" or descendant.Name == "Aura" or descendant.Name == "Pillar") then
			table.insert(parts, descendant)
		end
	end
	local center = if instance:IsA("Model") then instance.PrimaryPart else nil
	return { Parts = parts, Center = center or parts[1] }
end

local function startDonutEffects()
	local floaters = track("DonutFloat", makeFloater(0.9, 0.35))
	local podiums = track("PodiumSpin", makeFloater(0.6, 0.25))
	local rainbows: { [Instance]: Rainbow } = track("DonutRainbow", makeRainbowModel)
	local rainbowParts = track("RainbowPart", function(instance)
		return if instance:IsA("BasePart") then instance else nil
	end)
	local rainbowTexts = track("RainbowText", function(instance)
		return if instance:IsA("TextLabel") then instance else nil
	end)
	type Spinner = { Model: Model, Base: CFrame }
	local spinners: { [Instance]: Spinner } = track("SpinSlow", function(instance): Spinner?
		if instance:IsA("Model") and instance.PrimaryPart then
			return { Model = instance, Base = instance:GetPivot() }
		end
		return nil
	end)

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local cam = cameraPosition()

		local function animate(set: { [Instance]: Floater })
			for model, f in set do
				local root = f.Root
				-- Only animate anchored donuts (a carried donut is welded to its owner's head).
				if root.Parent and root.Anchored and (root.Position - cam).Magnitude < ANIMATE_DISTANCE then
					root.CFrame = f.Base * CFrame.new(0, math.sin(t * 2 + f.Phase) * f.Bob, 0) * CFrame.Angles(0, t * f.Spin + f.Phase, 0)
				elseif not model.Parent then
					set[model] = nil
				end
			end
		end
		animate(floaters)
		animate(podiums)

		local hue = (t * 0.2) % 1
		for model, r in rainbows do
			if not model.Parent then
				rainbows[model] = nil
			elseif r.Center and (r.Center.Position - cam).Magnitude < ANIMATE_DISTANCE * 1.5 then
				for i, part in r.Parts do
					part.Color = Color3.fromHSV((hue + i * 0.07) % 1, 0.7, 1)
				end
			end
		end
		for part in rainbowParts do
			local p = part :: BasePart
			if (p.Position - cam).Magnitude < 400 then
				p.Color = Color3.fromHSV((hue + p.Position.Z * 0.002) % 1, 0.8, 1)
			end
		end
		for label in rainbowTexts do
			(label :: TextLabel).TextColor3 = Color3.fromHSV(hue, 0.6, 1)
		end
		for model, s in spinners do
			if not model.Parent then
				spinners[model] = nil
			elseif (s.Base.Position - cam).Magnitude < 350 then
				s.Model:PivotTo(s.Base * CFrame.Angles(0, t * 0.5, math.sin(t) * 0.2))
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- Treadmill belts
--------------------------------------------------------------------------------
local function startTreadmills()
	type Belt = { Belt: BasePart, Slats: { BasePart } }
	local belts: { [Instance]: Belt } = track("TreadmillBelt", function(instance): Belt?
		if not instance:IsA("BasePart") then
			return nil
		end
		task.wait(0.5) -- let the slats replicate
		local treadmill = instance.Parent
		if not treadmill then
			return nil -- rebuilt already (the base moved worlds)
		end
		local slats: { BasePart } = {}
		for _, child in treadmill:GetChildren() do
			if child:IsA("BasePart") and child.Name == "Slat" then
				table.insert(slats, child)
			end
		end
		table.sort(slats, function(a, b)
			return ((a:GetAttribute("SlatIndex") :: number?) or 0) < ((b:GetAttribute("SlatIndex") :: number?) or 0)
		end)
		return { Belt = instance, Slats = slats }
	end)
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local cam = cameraPosition()
		for belt, info in belts do
			local part = info.Belt
			if not belt.Parent then
				belts[belt] = nil
			elseif (part.Position - cam).Magnitude < 150 and #info.Slats > 0 then
				local length = part.Size.Z
				local spacing = length / #info.Slats
				local offset = (t * Config.Treadmill.BeltSpeed) % spacing
				for i, slat in info.Slats do
					local z = ((i - 1) * spacing + offset) % length - length / 2
					slat.CFrame = part.CFrame * CFrame.new(0, part.Size.Y / 2 + 0.03, z)
				end
			end
		end
	end)
end

--------------------------------------------------------------------------------
-- Owner-only prompts (Upgrade / Sell / Podium on other players' bases are hidden),
-- and raid "Steal" prompts on your OWN base are hidden from you.
--------------------------------------------------------------------------------
local function startPromptFilter()
	local function filter(prompt: Instance)
		if not prompt:IsA("ProximityPrompt") then
			return
		end
		local function apply()
			local owner = prompt:GetAttribute("OwnerUserId")
			local hideFor = prompt:GetAttribute("HideForUserId")
			if prompt.Enabled and ((owner ~= nil and owner ~= player.UserId) or hideFor == player.UserId) then
				prompt.Enabled = false
			end
		end
		apply()
		prompt:GetAttributeChangedSignal("OwnerUserId"):Connect(apply)
		prompt:GetPropertyChangedSignal("Enabled"):Connect(apply)
	end
	for _, descendant in workspace:GetDescendants() do
		filter(descendant)
	end
	workspace.DescendantAdded:Connect(filter)
end

--------------------------------------------------------------------------------
-- Area ambience: brighter/basic near the hub, darker and more magical further out
--------------------------------------------------------------------------------
local function startAmbience()
	local tint = Lighting:WaitForChild("AreaTint", 10) :: ColorCorrectionEffect?
	local atmosphere = Lighting:WaitForChild("Atmosphere", 10) :: Atmosphere?
	local bloom = Lighting:WaitForChild("Bloom", 10) :: BloomEffect?
	local info = TweenInfo.new(2.5, Enum.EasingStyle.Sine)
	-- World 2's galaxy skybox (Config.GalaxySky), put back to the normal sky everywhere else
	local sky = Lighting:WaitForChild("Sky", 10) :: Sky?
	local faces = { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp" }
	local normalSky: { [string]: string } = {}
	if sky then
		for _, face in faces do
			local ok, id = pcall(function()
				return (sky :: any)[face]
			end)
			normalSky[face] = if ok and type(id) == "string" then id else ""
		end
	end
	local function setSky(world: number)
		local galaxy = world == Areas.UltimateWorld and Config.GalaxySky.SkyboxBk ~= ""
		if sky then
			for _, face in faces do
				local id = if galaxy then (Config.GalaxySky :: any)[face] else normalSky[face]
				if id ~= "" then
					(sky :: any)[face] = id
				end
			end
		end
	end

	local function apply(areaId: number)
		-- In a world's safe hub, use that world's own look (its first area), not World 1's daylight
		local world = math.max(1, State.Number("World"))
		setSky(world)
		local hubAmbience = if world > 1 and Areas.ByWorld[world] then Areas.ByWorld[world][1].Ambience else Areas.Hub
		local amb = if areaId > 0 then Areas.List[areaId].Ambience else hubAmbience
		-- Day -> night goes forwards through sunset (ClockTime wraps at 24) instead of rewinding the sun.
		local clock = amb.ClockTime
		if clock < 6 and Lighting.ClockTime > 6 then
			clock += 24
		end
		TweenService:Create(Lighting, info, { ClockTime = clock, Ambient = amb.Ambient, OutdoorAmbient = amb.Ambient:Lerp(Color3.new(1, 1, 1), 0.2) }):Play()
		local look = Config.Graphics
		if tint then
			TweenService:Create(tint, info, { TintColor = amb.Tint, Saturation = amb.Saturation + look.SaturationBoost, Contrast = amb.Contrast + look.ContrastBoost }):Play()
		end
		if atmosphere then
			-- Decay is the colour far-away things fade to: match it to the area's air, so distant
			-- scenery melts into a coloured fog instead of ending against grey
			TweenService:Create(atmosphere, info, { Color = amb.AtmosphereColor, Decay = amb.AtmosphereColor:Lerp(Color3.new(0, 0, 0), 0.45), Density = amb.AtmosphereDensity, Haze = amb.Haze }):Play()
		end
		if bloom then
			TweenService:Create(bloom, info, { Intensity = amb.Bloom + look.BloomBoost }):Play()
		end
		-- clouds only in daylight with clear air (not at night, in caves or in thick fog)
		local terrain = workspace:FindFirstChildOfClass("Terrain")
		local clouds = terrain and terrain:FindFirstChildOfClass("Clouds")
		if clouds then
			clouds.Enabled = amb.ClockTime >= 7 and amb.ClockTime <= 17.5 and amb.AtmosphereDensity < 0.35
		end
	end
	AreaTracker.Changed:Connect(apply)
	State.OnAttribute("World", function()
		if AreaTracker.Current >= 0 then
			apply(AreaTracker.Current)
		end
	end)
	if AreaTracker.Current >= 0 then
		apply(AreaTracker.Current)
	end
end

--------------------------------------------------------------------------------
-- Floating number popups
--------------------------------------------------------------------------------
local function popup(adornee: BasePart, text: string, color: Color3, offset: Vector3)
	local gui = Theme.new("BillboardGui", {
		Adornee = adornee,
		Size = UDim2.fromOffset(160, 40),
		StudsOffsetWorldSpace = offset,
		AlwaysOnTop = false,
		LightInfluence = 0,
		MaxDistance = 90,
		Parent = Theme.PlayerGui(),
	})
	local label = Theme.Label({ Text = text, TextColor3 = color, Size = UDim2.fromScale(1, 1), StrokeThickness = 2.5, Parent = gui })
	TweenService:Create(gui, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = offset + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
	task.delay(1.25, function()
		gui:Destroy()
	end)
end

local function startPopups()
	-- (Treadmill "+speed" popups live in client/Treadmill.luau.)
	-- "+$X" above your own donuts every few seconds
	task.spawn(function()
		local interval = 3
		while true do
			task.wait(interval)
			local plot = Bases.Mine()
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if plot and root and (root.Position - plot:GetPivot().Position).Magnitude < 120 then
				local mult = math.max(1, State.Number("MoneyMultiplier"))
				for _, child in plot:GetChildren() do
					local income = child:GetAttribute("Income")
					if child:IsA("Model") and child.PrimaryPart and type(income) == "number" then
						local top = (child:GetAttribute("Top") :: number?) or 3
						popup(child.PrimaryPart, "+" .. Format.Money(income * interval * mult), Theme.Colors.Money, Vector3.new(0, top + 3, 0))
					end
				end
			end
		end
	end)
end

function Effects.Init()
	startDonutEffects()
	startTreadmills()
	startPromptFilter()
	startAmbience()
	startPopups()
end

return Effects
