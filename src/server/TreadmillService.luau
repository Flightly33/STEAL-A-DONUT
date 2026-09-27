--[[
	TreadmillService
	================
	Every base has a treadmill next to it. When the owner steps on the belt, the client locks them onto
	it and plays a running animation (see client/Treadmill.luau). While the owner is on the belt they
	gain Speed every tick (checked here, on the server).

	Upgrading the treadmill (Shop) rebuilds it as a cooler model with a faster gain rate.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)

local Build = require(script.Parent.Build)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

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
	return Economy.TreadmillRate(data.TreadmillLevel, data.SpeedMultLevel, Economy.SpeedPassMultiplier(profile.Passes))
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
	local text = `+{Format.Number(TreadmillService.GetRate(player))} ⚡/s`
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
	local old = plot:FindFirstChild("Treadmill")
	if old then
		old:Destroy()
	end

	local level = profile.Data.TreadmillLevel
	local tier = Economy.TreadmillTier(level)
	local cf = anchor.CFrame
	local model = Instance.new("Model")
	model.Name = "Treadmill"
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Tier", level)

	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end

	-- Frame + belt
	Build.Part({ Parent = model, Name = "Base", Size = Vector3.new(BELT_WIDTH + 2, 1.2, BELT_LENGTH + 2), CFrame = at(0, 0.6, 0.5), Color = tier.Base, Material = tier.Material })
	local belt = Build.Part({ Parent = model, Name = "Belt", Size = Vector3.new(BELT_WIDTH, 0.3, BELT_LENGTH), CFrame = at(0, 1.35, 0.5), Color = rgb(30, 30, 35), Material = Enum.Material.Rubber })
	CollectionService:AddTag(belt, "TreadmillBelt")
	for i = 0, 5 do
		local slat = Build.Decor({ Parent = model, Name = "Slat", Size = Vector3.new(BELT_WIDTH - 0.2, 0.06, 0.35), CFrame = at(0, 1.53, 0.5 - BELT_LENGTH / 2 + i * (BELT_LENGTH / 6)), Color = rgb(90, 90, 100), Material = Enum.Material.SmoothPlastic })
		slat:SetAttribute("SlatIndex", i)
	end

	-- Handrails
	for _, side in { -1, 1 } do
		for _, z in { -5.8, 3 } do
			Build.Part({ Parent = model, Name = "RailPost", Size = Vector3.new(0.4, 3.2, 0.4), CFrame = at(side * 3.7, 2.8, z), Color = tier.Accent, Material = Enum.Material.Metal })
		end
		Build.Part({ Parent = model, Name = "Rail", Size = Vector3.new(0.45, 0.45, 9.6), CFrame = at(side * 3.7, 4.4, -1.4), Color = tier.Accent, Material = Enum.Material.Metal })
		if tier.Neon then
			local strip = Build.Decor({ Parent = model, Name = "Accent", Size = Vector3.new(0.25, 0.3, BELT_LENGTH + 2), CFrame = at(side * 4.1, 0.9, 0.5), Color = tier.Accent, Material = Enum.Material.Neon })
			if tier.Rainbow then
				CollectionService:AddTag(strip, "RainbowPart")
			end
		end
	end

	-- Console at the front
	Build.Part({ Parent = model, Name = "ConsolePost", Size = Vector3.new(1.4, 4.5, 0.9), CFrame = at(0, 3.4, -6.4), Color = tier.Base, Material = tier.Material })
	local screen = Build.Part({ Parent = model, Name = "Screen", Size = Vector3.new(5.4, 2.8, 0.4), CFrame = at(0, 6.2, -6.5) * CFrame.Angles(math.rad(-25), 0, 0), Color = rgb(15, 15, 20), Material = Enum.Material.SmoothPlastic })
	local screenGui = Instance.new("SurfaceGui")
	screenGui.Face = Enum.NormalId.Back -- faces the runner
	screenGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	screenGui.PixelsPerStud = 40
	screenGui.LightInfluence = 0
	screenGui.Parent = screen
	Build.Text(screenGui, "", { Name = "TierName", Size = UDim2.fromScale(1, 0.4), TextColor3 = tier.Accent, Font = Enum.Font.FredokaOne })
	Build.Text(screenGui, "", { Name = "Rate", Size = UDim2.fromScale(1, 0.6), Position = UDim2.fromScale(0, 0.4), TextColor3 = rgb(180, 120, 255) })

	if tier.Light then
		local light = Instance.new("PointLight")
		light.Color = tier.Accent
		light.Range = 14
		light.Brightness = 2
		light.Parent = screen
	end
	if tier.Sparkles then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = tier.Accent
		sparkles.Parent = belt
	end
	if tier.Fire then
		local exhaust = Build.Decor({ Parent = model, Name = "Exhaust", Size = Vector3.new(1, 1, 1), CFrame = at(0, 1.2, 8), Transparency = 1 })
		local fire = Instance.new("Fire")
		fire.Size = 3
		fire.Heat = 3
		fire.Parent = exhaust
	end
	if tier.Halo then
		local center = at(0, 11, -1)
		local ring = Instance.new("Model")
		ring.Name = "Halo"
		local pivot = Build.Decor({ Parent = ring, Name = "Center", Size = Vector3.one, CFrame = center, Transparency = 1 })
		for i = 0, 15 do
			local angle = i / 16 * math.pi * 2
			Build.Decor({ Parent = ring, Name = "HaloBall", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.8, CFrame = center * CFrame.new(math.cos(angle) * 4, 0, math.sin(angle) * 4), Color = tier.Accent, Material = Enum.Material.Neon })
		end
		ring.PrimaryPart = pivot
		CollectionService:AddTag(ring, "SpinSlow")
		ring.Parent = model
	end

	-- Floating label
	local label = Instance.new("BillboardGui")
	label.Size = UDim2.fromScale(12, 3)
	label.StudsOffsetWorldSpace = Vector3.new(0, 10, 0)
	label.MaxDistance = 90
	label.LightInfluence = 0
	label.Parent = belt
	Build.Text(label, "🏃 STEP ON TO RUN!", { Size = UDim2.fromScale(1, 0.5), TextColor3 = rgb(255, 255, 255) })
	Build.Text(label, `Tier {level}/{Economy.MaxTreadmillLevel()} • upgrade in Shop`, { Size = UDim2.fromScale(1, 0.4), Position = UDim2.fromScale(0, 0.55), TextColor3 = rgb(255, 230, 90), Font = Enum.Font.FredokaOne })

	model.PrimaryPart = belt
	model.Parent = plot
	belts[player] = belt
	updateScreen(player)
end

function TreadmillService.Remove(player: Player)
	local belt = belts[player]
	belts[player] = nil
	if belt and belt.Parent then
		(belt.Parent :: Instance):Destroy()
	end
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
				end
			end
		end
	end)
end

return TreadmillService
