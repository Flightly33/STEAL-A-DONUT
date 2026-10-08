--[[
	CraftService: the Cosmic Forge in the plaza by the spawn (while Config.CosmicDonut is on).
	Bring Config.CosmicDonut.ShardCost meteor shards (MeteorService) and craft THE COSMIC DONUT:
	it goes into your pen (or your inventory if the pen is full - a crafted donut is never lost).

	The forge: a dark crystal altar on a glowing platform, four crystal pillars, a sign, and a
	Cosmic Donut floating and turning over the altar. Its prompt opens the forge's window
	(client/UI/CosmicForge), whose CRAFT button asks for "CraftCosmic" (ShopService).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Donuts = require(Shared.Donuts)
local DonutModel = require(Shared.DonutModel)
local Layout = require(Shared.Layout)
local Remotes = require(Shared.Remotes)

local Build = require(script.Parent.Build)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local InventoryService = require(script.Parent.InventoryService)

local CraftService = {}

local COSMIC = Config.CosmicDonut
local DONUT_ID = "cosmicdonut"

local rgb = Color3.fromRGB
local STONE, STONE_DARK = rgb(46, 30, 78), rgb(26, 16, 46)
local VIOLET, CYAN, PINK = rgb(170, 90, 255), rgb(90, 225, 255), rgb(255, 120, 220)

local function notify(player: Player, text: string, kind: string?)
	Remotes.Event("Notify"):FireClient(player, text, kind or "info")
end

-- Craft The Cosmic Donut (the forge's CRAFT button). True if it worked.
function CraftService.Craft(player: Player): boolean
	if not COSMIC.Enabled then
		notify(player, "The Cosmic Forge has gone cold... The Cosmic Donut can't be crafted any more.", "error")
		return false
	end
	local profile = DataService.Get(player)
	if not profile or not profile.Session.Ready then
		return false
	end
	local data = profile.Data
	if data.MeteorShards < COSMIC.ShardCost then
		notify(player, `You need {COSMIC.ShardCost - data.MeteorShards} more meteor shards. Grab them from the meteor in the Eternal Storm!`, "error")
		return false
	end
	data.MeteorShards -= COSMIC.ShardCost
	if not PlotService.AddDonut(player, DONUT_ID, 1, "None", "Normal") then
		InventoryService.AddDonut(player, DONUT_ID, 1, "None", "Normal") -- (a full pen)
	end
	PlotService.RecordFind(player, DONUT_ID, "None", "Normal") -- (the Index, the rarest-donut board, the announcement)
	DataService.PushState(player)
	Remotes.Event("CosmicCrafted"):FireClient(player, { Shards = data.MeteorShards })
	notify(player, "You crafted THE COSMIC DONUT! It's in your base.", "rare")
	return true
end

-- The forge, standing in the plaza (built once, when the server starts).
local function buildForge(): Model
	local model = Instance.new("Model")
	model.Name = "CosmicForge"
	local origin = Layout.CosmicForgeCFrame()
	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, solid: boolean?): BasePart
		local props = { Parent = model, Name = name, Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.Slate }
		return if solid then Build.Part(props) else Build.Decor(props)
	end
	-- platform with a glowing edge, steps up to the altar
	part("Platform", Vector3.new(22, 1.2, 22), at(0, 0.6, 0), STONE, Enum.Material.Slate, true)
	for i, side in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local long = math.abs(side.X) > 0
		part("Trim", if long then Vector3.new(0.4, 0.3, 22.4) else Vector3.new(22.4, 0.3, 0.4), at(side.X * 11, 1.25, side.Z * 11), if i % 2 == 0 then CYAN else VIOLET, Enum.Material.Neon)
	end
	part("Step", Vector3.new(12, 0.8, 12), at(0, 1.6, 0), STONE_DARK, Enum.Material.Slate, true)
	-- the altar: a dark block cut with glowing cracks, a crystal bowl on top
	local altar = part("Altar", Vector3.new(6, 4, 6), at(0, 4, 0), STONE_DARK, Enum.Material.Slate, true)
	for i = 0, 3 do
		local face = CFrame.Angles(0, i * math.pi / 2, 0)
		part("AltarGlow", Vector3.new(0.3, 3, 0.3), at(0, 4, 0) * face * CFrame.new(1.6, 0, -3.05) * CFrame.Angles(0, 0, 0.35), if i % 2 == 0 then VIOLET else CYAN, Enum.Material.Neon)
		part("AltarGlow", Vector3.new(0.3, 2, 0.3), at(0, 4, 0) * face * CFrame.new(-1.4, -0.3, -3.05) * CFrame.Angles(0, 0, -0.5), PINK, Enum.Material.Neon)
	end
	part("Bowl", Vector3.new(6.8, 0.6, 6.8), at(0, 6.3, 0), STONE, Enum.Material.Slate)
	local core = part("Core", Vector3.new(4.6, 0.4, 4.6), at(0, 6.7, 0), VIOLET, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = VIOLET
	light.Range = 24
	light.Brightness = 3
	light.Parent = core
	-- crystal pillars in the corners
	for _, corner in { Vector2.new(1, 1), Vector2.new(-1, 1), Vector2.new(1, -1), Vector2.new(-1, -1) } do
		local x, z = corner.X * 8.6, corner.Y * 8.6
		part("Pillar", Vector3.new(2, 7, 2), at(x, 4.7, z), STONE_DARK, Enum.Material.Slate, true)
		part("PillarTrim", Vector3.new(2.3, 0.4, 2.3), at(x, 8.3, z), VIOLET, Enum.Material.Neon)
		part("PillarCrystal", Vector3.new(1, 3.2, 1), at(x, 10.1, z) * CFrame.Angles(0, math.pi / 4, 0.15 * corner.X), if corner.Y > 0 then CYAN else PINK, Enum.Material.Neon)
	end
	-- the sign over it
	local sign = part("Sign", Vector3.new(14, 3.2, 0.6), at(0, 15.5, 4), STONE_DARK, Enum.Material.Slate)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = sign
	local title = Build.Text(gui, "COSMIC FORGE", { TextColor3 = rgb(225, 200, 255), Size = UDim2.fromScale(1, 0.6) })
	title.Name = "Title"
	local info = Build.Text(gui, `THE COSMIC DONUT • {COSMIC.ShardCost} METEOR SHARDS • LIMITED TIME`, { TextColor3 = CYAN, Size = UDim2.fromScale(1, 0.35), Position = UDim2.fromScale(0, 0.62) })
	info.Name = "Info"
	for _, side in { -1, 1 } do
		part("SignPost", Vector3.new(0.6, 13, 0.6), at(side * 6.4, 8.5, 4), STONE_DARK, Enum.Material.Slate)
	end
	-- the prompt that opens the forge
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CosmicForgePrompt"
	prompt.ActionText = "Open Forge"
	prompt.ObjectText = "Cosmic Forge"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = altar
	-- The Cosmic Donut floating over the altar, turning (client/Effects spins it, client/MeteorFX
	-- spins its horizon)
	local donut = DonutModel.Build(Donuts.ById[DONUT_ID], { Calm = true, Scale = 1.25 })
	donut.Name = "ForgeDonut"
	DonutModel.PlaceOn(donut, at(0, 9, 0))
	CollectionService:AddTag(donut, "PodiumSpin")
	CollectionService:AddTag(donut, "HorizonSpin")
	donut.Parent = model
	model.PrimaryPart = altar
	model.Parent = workspace
	return model
end

function CraftService.Init()
	if COSMIC.Enabled then
		buildForge()
	end
end

return CraftService
