--[[
	TreadmillService
	================
	Every base has a treadmill next to it. When the owner steps on the belt, the client locks them onto
	it and plays a running animation (see client/Treadmill.luau). While the owner is on the belt they
	gain Speed every tick (checked here, on the server).

	There are 16 treadmills (Config.Treadmill: Speed per step, StepsPerSecond steps a second), each
	its own model designed in Blender (art/treadmills -> shared/TreadmillModels): from a rusty old
	thing with a TV for a console, through turbines, tesla coils, lava and crystals, a dragon and a
	supernova, to Heavenly - white marble and gold, angel wings and a column of light. Buying the
	next one in the Shop rebuilds it.
	Their effects (server/TreadmillFX) go from bad to epic: the junk ones cough smoke, grind sparks
	and flicker, the middle ones get jets, rings of light and lightning, and the top ones auras,
	black holes, dragon fire and god rays. Each moves (fans, turbines, planets, wings...) and glows
	faster and harder while the owner runs (the model's "Running" attribute).
	Only the deck and the belt are solid: everything else is to look at, so you can't snag on it.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local TreadmillModels = require(Shared.TreadmillModels)

local Build = require(script.Parent.Build)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local TreadmillFX = require(script.Parent.TreadmillFX)

local TreadmillService = {}

local rgb = Color3.fromRGB
local TICK = 0.2
local BELT_LENGTH = 13
local BELT_WIDTH = 6

local belts: { [Player]: BasePart } = {}

function TreadmillService.GetRate(player: Player): number
	local profile = DataService.Get(player)
	if not profile then
		return 0
	end
	local data = profile.Data
	return Economy.TreadmillRate(data.TreadmillLevel, data.SpeedMultLevel, Economy.SpeedPassMultiplier(profile.Passes), DataService.IndexSpeedBonus(data), DataService.PetSpeedBonus(data))
end

local function updateScreen(player: Player)
	local belt = belts[player]
	local model = belt and belt.Parent
	if not model then
		return
	end
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local tier = Economy.TreadmillTier(profile.Data.TreadmillLevel)
	local rate = TreadmillService.GetRate(player)
	local text = `+{Format.Number(rate / Config.Treadmill.StepsPerSecond)} a step\n({Format.Rate(rate)} /s)`
	for _, label in model:GetDescendants() do
		if label:IsA("TextLabel") then
			if label.Name == "Rate" then
				label.Text = text
			elseif label.Name == "TierName" then
				label.Text = `{string.upper(tier.Name)} TREADMILL`
			end
		end
	end
end

function TreadmillService.Remove(player: Player)
	local belt = belts[player]
	belts[player] = nil
	if belt and belt.Parent then
		(belt.Parent :: Instance):Destroy()
	end
end

-- One part of a treadmill model (shared/TreadmillModels), placed relative to `origin`
local function makePart(spec: TreadmillModels.Part, origin: CFrame, parent: Instance): BasePart
	local part = Instance.new(if spec.Shape == "Wedge" then "WedgePart" else "Part") :: BasePart
	if spec.Shape == "Cylinder" then
		(part :: Part).Shape = Enum.PartType.Cylinder
	elseif spec.Shape == "Ball" then
		(part :: Part).Shape = Enum.PartType.Ball
	end
	part.Name = spec.Name or "Part"
	part.Size = spec.Size
	local placed = CFrame.new(spec.Pos)
	local rot = spec.Rot
	if rot then
		placed *= CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
	end
	part.CFrame = origin * placed
	part.Color = spec.Color
	part.Material = (Enum.Material :: any)[spec.Material or "SmoothPlastic"] or Enum.Material.SmoothPlastic
	part.Transparency = spec.Transparency or 0
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	-- (only the deck and the belt are solid: nothing else to snag on or get flung by)
	local solid = spec.Collide == true
	part.CanCollide = solid
	part.CanQuery = solid
	part.CanTouch = solid
	part.CastShadow = part.Transparency < 0.5 and part.Material ~= Enum.Material.Neon
	part.Parent = parent
	return part
end

function TreadmillService.Build(player: Player)
	local plot = PlotService.GetPlotModel(player)
	local profile = DataService.Get(player)
	if not plot or not profile then
		return
	end
	local anchor = plot:FindFirstChild("TreadmillAnchor") :: BasePart?
	if not anchor then
		return
	end
	-- Remove the old one
	TreadmillService.Remove(player)
	local old = plot:FindFirstChild("Treadmill")
	if old then
		old:Destroy()
	end

	local level = profile.Data.TreadmillLevel
	local tier = Economy.TreadmillTier(level)
	local design = TreadmillModels[tier.Name] or TreadmillModels.Rusty
	local cf = anchor.CFrame
	local model = Instance.new("Model")
	model.Name = "Treadmill"
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Tier", level)
	model:SetAttribute("Design", tier.Name)

	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end

	-- The model, designed in Blender (art/treadmills): its moving groups first
	local groups: { [string]: Model } = {}
	for name, group in design.Groups do
		local spinner = Instance.new("Model")
		spinner.Name = name
		local pivot = Build.Decor({ Parent = spinner, Name = "Pivot", Size = Vector3.one * 0.2, CFrame = cf * group.Pivot, Transparency = 1 })
		pivot.CastShadow = false
		spinner.PrimaryPart = pivot
		spinner:SetAttribute("Axis", group.Axis)
		spinner:SetAttribute("Idle", group.Idle)
		spinner:SetAttribute("Run", group.Run)
		spinner:SetAttribute("Mode", group.Mode or "Spin")
		spinner:SetAttribute("Amp", group.Amp)
		spinner:SetAttribute("Dir", group.Dir)
		groups[name] = spinner
	end
	local belt: BasePart? = nil
	local screen: BasePart? = nil
	for _, spec in design.Parts do
		local parent: Instance = if spec.Group then groups[spec.Group] or model else model
		local part = makePart(spec, cf, parent)
		local tag = spec.Tag
		if tag == "Belt" then
			belt = part
			CollectionService:AddTag(part, "TreadmillBelt")
		elseif tag == "Slat" then
			part:SetAttribute("SlatIndex", spec.Index or 0)
		elseif tag == "LED" then
			part:SetAttribute("LEDIndex", spec.Index or 0)
			CollectionService:AddTag(part, "TreadmillLED")
		elseif tag == "Screen" then
			screen = part
		elseif tag == "Rainbow" then
			CollectionService:AddTag(part, "RainbowPart")
		elseif tag == "Flicker" then
			CollectionService:AddTag(part, "TreadmillFlicker")
		end
	end
	for _, spinner in groups do
		spinner.Parent = model
		CollectionService:AddTag(spinner, "TreadmillSpin")
	end
	-- Its effects (smoke and sparks on the junk ones ... god rays on Heavenly), ticking over
	TreadmillFX.Build(model, cf, design, groups)
	local beltPart: BasePart
	if belt then
		beltPart = belt
	else
		-- (every design has a belt; just in case)
		beltPart = Build.Part({ Parent = model, Name = "Belt", Size = Vector3.new(BELT_WIDTH, 0.3, BELT_LENGTH), CFrame = at(0, 1.35, 0.5), Color = rgb(30, 30, 35), Material = Enum.Material.Rubber })
		CollectionService:AddTag(beltPart, "TreadmillBelt")
	end

	-- The console's screen: the treadmill's name and what a step gives you (facing the runner)
	if screen then
		local screenGui = Instance.new("SurfaceGui")
		screenGui.Face = Enum.NormalId.Back
		screenGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		screenGui.PixelsPerStud = 40
		screenGui.LightInfluence = 0
		screenGui.Parent = screen
		Build.Text(screenGui, "", { Name = "TierName", Size = UDim2.fromScale(1, 0.4), TextColor3 = tier.Accent, Font = Enum.Font.FredokaOne })
		Build.Text(screenGui, "", { Name = "Rate", Size = UDim2.fromScale(1, 0.6), Position = UDim2.fromScale(0, 0.4), TextColor3 = rgb(180, 120, 255) })
	end

	-- Floating label
	local label = Instance.new("BillboardGui")
	label.Size = UDim2.fromScale(12, 3)
	label.StudsOffsetWorldSpace = Vector3.new(0, 10, 0)
	label.MaxDistance = 90
	label.LightInfluence = 0
	label.Parent = beltPart
	Build.Text(label, "STEP ON TO RUN!", { Size = UDim2.fromScale(1, 0.5), TextColor3 = rgb(255, 255, 255) })
	Build.Text(label, `Tier {level}/{Economy.MaxTreadmillLevel()} • upgrade in Shop`, { Size = UDim2.fromScale(1, 0.4), Position = UDim2.fromScale(0, 0.55), TextColor3 = rgb(255, 230, 90), Font = Enum.Font.FredokaOne })

	model.PrimaryPart = beltPart
	-- (rebuilt while they're on it - just bought the next one: it starts all out)
	local running = player:GetAttribute("OnTreadmill") == true
	model:SetAttribute("Running", running)
	TreadmillFX.SetRunning(model, running)
	model.Parent = plot
	belts[player] = beltPart
	updateScreen(player)
end

-- Refresh the rate shown on the console (after buying a multiplier / pass).
function TreadmillService.Refresh(player: Player)
	updateScreen(player)
end

local function isOnBelt(belt: BasePart, position: Vector3): boolean
	local localPos = belt.CFrame:PointToObjectSpace(position)
	return math.abs(localPos.X) < BELT_WIDTH / 2 + 0.3
		and math.abs(localPos.Z) < BELT_LENGTH / 2 + 0.3
		and localPos.Y > 0
		and localPos.Y < 9
end

-- Every effect all out while the owner runs (and back to ticking over when they stop).
local function setRunning(player: Player, running: boolean)
	local belt = belts[player]
	local model = belt and belt.Parent
	if not model or not belt then
		return
	end
	model:SetAttribute("Running", running)
	TreadmillFX.SetRunning(model, running)
end

function TreadmillService.Init()
	task.spawn(function()
		while true do
			local dt = task.wait(TICK)
			for _, player in Players:GetPlayers() do
				local belt = belts[player]
				local profile = DataService.Get(player)
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local onBelt = false
				if belt and profile and profile.Session.Ready and root and not player:GetAttribute("CarryingDonut") then
					onBelt = isOnBelt(belt, root.Position)
					if onBelt then
						DataService.AddSpeed(player, TreadmillService.GetRate(player) * dt)
					end
				end
				if player:GetAttribute("OnTreadmill") ~= onBelt then
					player:SetAttribute("OnTreadmill", onBelt)
					setRunning(player, onBelt)
				end
			end
		end
	end)
end

return TreadmillService
