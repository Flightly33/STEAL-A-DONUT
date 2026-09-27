--[[
	ItemService
	===========
	The item shop: weapons, traps and the Base Lock (Config.Items). Items are bought once with money,
	saved, and handed out as Tools in your backpack every time you spawn.

	  Weapon - click to swing; flings everyone in front of you within Range.
	  Trap   - click while standing in your base to place it at your feet (oldest one moves once you
	           hit MaxPlaced). Flings any other player who touches it.
	  Lock   - click to put a laser across your base entrance for Duration seconds: raids are blocked
	           and intruders who touch the laser get flung out.

	Anyone who gets flung while carrying a donut drops it (a raided donut goes back to its owner).
	Every item has sound effects (built-in Roblox sounds, so nothing needs uploading).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Layout = require(Shared.Layout)
local Remotes = require(Shared.Remotes)

local Build = require(script.Parent.Build)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local StealService = require(script.Parent.StealService)

local ItemService = {}

local rgb = Color3.fromRGB
local FLING_GRACE = 2.5 -- seconds a player can't be flung again

local itemsById: { [string]: Config.Item } = {}
for _, item in Config.Items do
	itemsById[item.Id] = item
end

-- Built-in sounds that ship with every Roblox client.
local SOUNDS = {
	Swing = { Id = "rbxasset://sounds/swordslash.wav", Volume = 0.5, Pitch = 1.15 },
	HeavySwing = { Id = "rbxasset://sounds/swordlunge.wav", Volume = 0.6, Pitch = 0.75 },
	Hit = { Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 1, Pitch = 0.7 },
	Launch = { Id = "rbxasset://sounds/Rocket whoosh 01.wav", Volume = 0.5, Pitch = 1.3 },
	Slip = { Id = "rbxasset://sounds/action_falling.mp3", Volume = 0.6, Pitch = 1.4 },
	Place = { Id = "rbxasset://sounds/button.wav", Volume = 0.5, Pitch = 0.8 },
	Lock = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5, Pitch = 0.6 },
	Unlock = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.4, Pitch = 1.2 },
	Equip = { Id = "rbxasset://sounds/unsheath.wav", Volume = 0.35, Pitch = 1.1 },
	Buy = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.4, Pitch = 1.5 },
}

-- Play a 3D sound from `parent` (everyone nearby hears it).
function ItemService.PlaySound(parent: Instance, name: string)
	local def = SOUNDS[name]
	if not def then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "ItemSound"
	sound.SoundId = def.Id
	sound.Volume = def.Volume
	sound.PlaybackSpeed = def.Pitch
	sound.RollOffMaxDistance = 80
	sound.Parent = parent
	sound:Play()
	task.delay(4, function()
		sound:Destroy()
	end)
end

local lastFlung: { [Player]: number } = {}
local lastUse: { [Player]: { [string]: number } } = {}
local placedTraps: { [Player]: { [string]: { BasePart } } } = {}
local lockParts: { [Player]: BasePart } = {}

local function notify(player: Player, text: string, kind: string?)
	Remotes.Event("Notify"):FireClient(player, text, kind or "info")
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		return root
	end
	return nil
end

local function onCooldown(player: Player, itemId: string, seconds: number): boolean
	lastUse[player] = lastUse[player] or {}
	local last = lastUse[player][itemId]
	if last and os.clock() - last < seconds then
		return true
	end
	lastUse[player][itemId] = os.clock()
	return false
end

--------------------------------------------------------------------------------
-- Fling
--------------------------------------------------------------------------------
-- Launch `target` away from `origin`. The target's own client applies the push (players own
-- their character's physics), the server makes them drop any donut they carry.
function ItemService.Fling(target: Player, origin: Vector3, power: number)
	local root = rootOf(target)
	if not root then
		return
	end
	if lastFlung[target] and os.clock() - lastFlung[target] < FLING_GRACE then
		return
	end
	lastFlung[target] = os.clock()
	local away = (root.Position - origin) * Vector3.new(1, 0, 1)
	local direction = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0, 1)
	ItemService.PlaySound(root, "Hit")
	StealService.Knock(target)
	Remotes.Event("Flung"):FireClient(target, direction * power + Vector3.new(0, power * 0.7, 0))
end

local function playerFromPart(part: BasePart): Player?
	local model = part:FindFirstAncestorOfClass("Model")
	return if model then Players:GetPlayerFromCharacter(model) else nil
end

--------------------------------------------------------------------------------
-- Tools
--------------------------------------------------------------------------------
local function decor(tool: Tool, handle: BasePart, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = "Decor"
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		part.Shape = shape
	end
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.CFrame = handle.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = handle
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
	part.Parent = tool
	return part
end

-- Cylinders point along X; this lays one along the tool (Z).
local ALONG = CFrame.Angles(0, math.pi / 2, 0)
local BALL, CYL = Enum.PartType.Ball, Enum.PartType.Cylinder

-- Every item is modelled along the handle's +Z axis: +Z is "away from the hand".
-- The grip is the classic sword grip, so weapons point forward when you hold them.
local function makeTool(item: Config.Item): Tool
	local tool = Instance.new("Tool")
	tool.Name = item.Name
	tool.ToolTip = item.Description
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("ItemId", item.Id)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.CanCollide = false
	handle.Massless = true
	handle.Material = Enum.Material.SmoothPlastic
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Size = Vector3.new(0.4, 0.4, 1.4)
	handle.Color = rgb(120, 80, 45)
	handle.Parent = tool
	local function grip(z: number)
		tool.Grip = CFrame.new(0, 0, z, 0, 0, 1, 1, 0, 0, 0, 1, 0)
	end
	grip(-0.3)

	if item.Id == "Slap" then
		-- A giant cartoon glove
		handle.Size = Vector3.new(0.7, 0.7, 1)
		handle.Color = rgb(255, 210, 60)
		handle.Material = Enum.Material.Fabric
		local white = rgb(250, 250, 250)
		decor(tool, handle, Vector3.new(0.3, 1.1, 1.1), CFrame.new(0, 0, 0.55) * ALONG, rgb(255, 180, 40), Enum.Material.Fabric, CYL)
		decor(tool, handle, Vector3.new(1.7, 0.6, 1.5), CFrame.new(0, 0, 1.3), white)
		for i, x in { -0.6, -0.2, 0.2, 0.6 } do
			local length = if i == 1 or i == 4 then 0.8 else 1
			decor(tool, handle, Vector3.new(length, 0.42, 0.42), CFrame.new(x, 0, 2.05 + length / 2 - 0.4) * ALONG, white, nil, CYL)
			decor(tool, handle, Vector3.one * 0.42, CFrame.new(x, 0, 2.05 + length - 0.4), white, nil, BALL)
		end
		decor(tool, handle, Vector3.new(0.8, 0.42, 0.42), CFrame.new(1.05, 0, 1.2) * CFrame.Angles(0, math.rad(40), 0) * ALONG, white, nil, CYL)
		for _, x in { -0.3, 0, 0.3 } do
			decor(tool, handle, Vector3.new(0.06, 0.62, 0.7), CFrame.new(x, 0, 1.25), rgb(40, 40, 40))
		end
		grip(-0.1)
	elseif item.Id == "Bat" then
		-- A baseball bat with a donut stuck on it
		handle.Material = Enum.Material.Wood
		handle.Size = Vector3.new(0.34, 0.34, 1.6)
		handle.Color = rgb(150, 95, 50)
		decor(tool, handle, Vector3.new(0.2, 0.5, 0.5), CFrame.new(0, 0, -0.85) * ALONG, rgb(90, 60, 35), Enum.Material.Wood, CYL)
		for i = 0, 4 do
			local d = 0.42 + i * 0.12
			decor(tool, handle, Vector3.new(0.5, d, d), CFrame.new(0, 0, 1.0 + i * 0.45) * ALONG, rgb(200, 135, 70), Enum.Material.Wood, CYL)
		end
		decor(tool, handle, Vector3.one * 0.92, CFrame.new(0, 0, 3.05), rgb(200, 135, 70), Enum.Material.Wood, BALL)
		-- the donut ring around the barrel
		for n = 0, 9 do
			local angle = n / 10 * math.pi * 2
			decor(tool, handle, Vector3.one * 0.5, CFrame.new(math.cos(angle) * 0.62, math.sin(angle) * 0.62, 2.1), rgb(222, 165, 95), nil, BALL)
			decor(tool, handle, Vector3.one * 0.44, CFrame.new(math.cos(angle) * 0.62, math.sin(angle) * 0.62, 1.95), rgb(255, 130, 190), nil, BALL)
		end
		grip(-0.4)
	elseif item.Id == "Hammer" then
		-- A glowing mega mallet
		handle.Size = Vector3.new(0.4, 0.4, 3.2)
		handle.Color = rgb(70, 50, 110)
		handle.Material = Enum.Material.Metal
		decor(tool, handle, Vector3.new(2.8, 1.9, 1.9), CFrame.new(0, 0, 1.9), rgb(150, 90, 255), Enum.Material.SmoothPlastic, CYL)
		for _, x in { -1.25, 1.25 } do
			decor(tool, handle, Vector3.new(0.3, 2.05, 2.05), CFrame.new(x, 0, 1.9), rgb(255, 220, 90), Enum.Material.Neon, CYL)
		end
		local core = decor(tool, handle, Vector3.new(0.5, 1.95, 1.95), CFrame.new(0, 0, 1.9), rgb(200, 150, 255), Enum.Material.Neon, CYL)
		local light = Instance.new("PointLight")
		light.Color = rgb(170, 110, 255)
		light.Range = 10
		light.Brightness = 1.5
		light.Parent = core
		decor(tool, handle, Vector3.one * 0.55, CFrame.new(0, 0, -1.65), rgb(255, 220, 90), Enum.Material.Neon, BALL)
		grip(-1.1)
	elseif item.Id == "Banana" then
		-- A banana peel: stem + three floppy flaps
		handle.Size = Vector3.new(0.5, 0.5, 0.9)
		handle.Color = rgb(255, 225, 60)
		decor(tool, handle, Vector3.new(0.25, 0.25, 0.3), CFrame.new(0, 0, -0.55), rgb(110, 80, 40))
		for n = 0, 2 do
			local angle = n / 3 * math.pi * 2
			decor(tool, handle, Vector3.new(0.4, 0.14, 1.2), CFrame.Angles(0, 0, angle) * CFrame.new(0, 0.3, 0.75) * CFrame.Angles(math.rad(-30), 0, 0), rgb(255, 225, 60))
		end
		grip(-0.2)
	elseif item.Id == "Spring" then
		-- A mini launch pad with a spring
		handle.Size = Vector3.new(0.4, 0.4, 0.8)
		handle.Color = rgb(60, 60, 70)
		handle.Material = Enum.Material.Metal
		for i = 0, 3 do
			decor(tool, handle, Vector3.new(0.12, 0.9, 0.9), CFrame.new(0, 0, 0.5 + i * 0.25) * ALONG, rgb(200, 200, 210), Enum.Material.Metal, CYL)
		end
		decor(tool, handle, Vector3.new(0.3, 1.8, 1.8), CFrame.new(0, 0, 1.55) * ALONG, rgb(80, 200, 255), Enum.Material.Neon, CYL)
		grip(-0.2)
	elseif item.Id == "Lock" then
		-- A big golden padlock
		handle.Size = Vector3.new(0.5, 0.5, 0.6)
		handle.Color = rgb(60, 60, 70)
		decor(tool, handle, Vector3.new(1.3, 0.6, 1.2), CFrame.new(0, 0, 0.85), rgb(255, 200, 50), Enum.Material.Foil)
		decor(tool, handle, Vector3.new(0.25, 0.62, 0.35), CFrame.new(0, 0, 0.85), rgb(40, 30, 20))
		for _, x in { -0.45, 0.45 } do
			decor(tool, handle, Vector3.new(0.18, 0.18, 0.7), CFrame.new(x, 0, 1.75), rgb(200, 200, 210), Enum.Material.Metal)
		end
		decor(tool, handle, Vector3.new(1.08, 0.18, 0.18), CFrame.new(0, 0, 2.1), rgb(200, 200, 210), Enum.Material.Metal)
		grip(-0.1)
	end
	return tool
end

-- Classic "swing" animation: the default Animate script plays a slash when it sees this value.
local function swingAnimation(tool: Tool)
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash"
	anim.Parent = tool
	task.delay(0.3, function()
		anim:Destroy()
	end)
end

local function useWeapon(player: Player, tool: Tool, item: Config.Item)
	if onCooldown(player, item.Id, item.Cooldown or 2) then
		return
	end
	swingAnimation(tool)
	local handle = tool:FindFirstChild("Handle")
	if handle then
		ItemService.PlaySound(handle, if item.Id == "Hammer" then "HeavySwing" else "Swing")
	end
	local root = rootOf(player)
	if not root then
		return
	end
	local range = item.Range or 9
	for _, other in Players:GetPlayers() do
		local otherRoot = if other ~= player then rootOf(other) else nil
		if otherRoot then
			local offset = (otherRoot.Position - root.Position) * Vector3.new(1, 0, 1)
			local distance = offset.Magnitude
			local inFront = distance < 4 or offset.Unit:Dot(root.CFrame.LookVector) > 0.25
			if distance <= range and inFront and math.abs(otherRoot.Position.Y - root.Position.Y) < 10 then
				ItemService.Fling(other, root.Position, item.Power or 80)
			end
		end
	end
end

local function placeTrap(player: Player, item: Config.Item)
	local root = rootOf(player)
	local plotIndex = PlotService.GetPlotIndex(player)
	local plot = PlotService.GetPlotModel(player)
	if not root or not plotIndex or not plot or not Layout.IsInPlot(plotIndex, root.Position) then
		notify(player, "Stand inside your own base to place traps.", "error")
		return
	end
	if onCooldown(player, item.Id, 1) then
		return
	end
	local folder: Instance
	local existing = plot:FindFirstChild("Traps")
	if existing then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = "Traps"
		folder.Parent = plot
	end

	local position = Vector3.new(root.Position.X, Layout.PlotFloorHeight, root.Position.Z)
	local base = CFrame.new(position) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	-- The trap is an invisible touch pad with a little model on top.
	local trap = Build.Part({ Parent = folder, Name = if item.Id == "Banana" then "BananaTrap" else "LaunchPad", Size = Vector3.new(3.4, 1.2, 3.4), CFrame = base * CFrame.new(0, 0.6, 0), Transparency = 1, CanCollide = false })
	local function piece(props: { [string]: any })
		props.Parent = trap
		Build.Decor(props)
	end
	if item.Id == "Banana" then
		piece({ Name = "Peel", Size = Vector3.new(0.7, 0.45, 1), CFrame = base * CFrame.new(0, 0.25, 0), Color = rgb(255, 225, 60) })
		piece({ Name = "Stem", Size = Vector3.new(0.25, 0.25, 0.4), CFrame = base * CFrame.new(0, 0.3, -0.65), Color = rgb(110, 80, 40) })
		for n = 0, 2 do
			local angle = n / 3 * math.pi * 2 + 0.4
			piece({ Name = "Flap", Size = Vector3.new(0.55, 0.15, 1.5), CFrame = base * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.12, 1.1) * CFrame.Angles(math.rad(8), 0, 0), Color = rgb(255, 225, 60) })
			piece({ Name = "FlapTip", Size = Vector3.new(0.3, 0.16, 0.25), CFrame = base * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0.13, 1.85), Color = rgb(140, 100, 40) })
		end
	else
		piece({ Name = "PadBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 4.4, 4.4), CFrame = base * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(50, 55, 70), Material = Enum.Material.Metal })
		for i = 0, 2 do
			piece({ Name = "Coil", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.14, 2.2, 2.2), CFrame = base * CFrame.new(0, 0.5 + i * 0.22, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(200, 200, 210), Material = Enum.Material.Metal })
		end
		piece({ Name = "PadTop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 3.6, 3.6), CFrame = base * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(80, 200, 255), Material = Enum.Material.Neon })
		for n = 0, 3 do
			piece({ Name = "Arrow", Size = Vector3.new(0.3, 0.1, 0.9), CFrame = base * CFrame.Angles(0, n * math.pi / 2, 0) * CFrame.new(0, 1.36, 1) , Color = rgb(255, 255, 255), Material = Enum.Material.Neon })
		end
	end
	trap:SetAttribute("OwnerUserId", player.UserId)
	ItemService.PlaySound(trap, "Place")
	trap.Touched:Connect(function(hit: BasePart)
		local victim = playerFromPart(hit)
		if victim and victim ~= player and not (lastFlung[victim] and os.clock() - lastFlung[victim] < FLING_GRACE) then
			ItemService.PlaySound(trap, if item.Id == "Banana" then "Slip" else "Launch")
			ItemService.Fling(victim, trap.Position - Vector3.new(0, 2, 0), item.Power or 80)
		end
	end)

	placedTraps[player] = placedTraps[player] or {}
	local list = placedTraps[player][item.Id] or {}
	placedTraps[player][item.Id] = list
	table.insert(list, trap)
	while #list > (item.MaxPlaced or 1) do
		local oldest = table.remove(list, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	notify(player, `{item.Name} placed ({#list}/{item.MaxPlaced or 1})`, "success")
end

local function useLock(player: Player, item: Config.Item)
	local plot = PlotService.GetPlotModel(player)
	local plotIndex = PlotService.GetPlotIndex(player)
	if not plot or not plotIndex then
		return
	end
	local duration = item.Duration or 30
	lastUse[player] = lastUse[player] or {}
	local last = lastUse[player][item.Id]
	local wait = if last then duration + (item.Cooldown or 60) - (os.clock() - last) else 0
	if wait > 0 then
		notify(player, `Base Lock recharging: {Format.Duration(wait)}`, "error")
		return
	end
	lastUse[player][item.Id] = os.clock()

	-- Laser across the base entrance (the gap in the front fence)
	local cf = Layout.PlotCFrame(plotIndex)
	local laser = Build.Part({
		Parent = plot, Name = "LockLaser",
		Size = Vector3.new(18, 8, 0.6),
		CFrame = cf * CFrame.new(0, Layout.PlotFloorHeight + 4, -Layout.PlotDepth / 2),
		Color = rgb(255, 40, 40), Material = Enum.Material.Neon, Transparency = 0.35, CanCollide = false,
	})
	lockParts[player] = laser
	plot:SetAttribute("Locked", true)
	ItemService.PlaySound(laser, "Lock")
	laser.Touched:Connect(function(hit: BasePart)
		local victim = playerFromPart(hit)
		if victim and victim ~= player then
			-- push them out of the base (the plot's LookVector points out through the entrance)
			ItemService.Fling(victim, laser.Position + cf.LookVector * -6, 90)
		end
	end)
	notify(player, `🔒 Base locked for {duration}s!`, "success")
	task.delay(duration, function()
		if lockParts[player] == laser then
			lockParts[player] = nil
			if plot.Parent then
				plot:SetAttribute("Locked", nil)
			end
			if player.Parent then
				notify(player, "🔓 Your base lock wore off.")
				ItemService.PlaySound(laser, "Unlock")
			end
		end
		laser:Destroy()
	end)
end

local function giveTool(player: Player, item: Config.Item)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	local containers: { Instance } = { backpack }
	if player.Character then
		table.insert(containers, player.Character)
	end
	for _, container in containers do
		do
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("ItemId") == item.Id then
					return -- already has it
				end
			end
		end
	end
	local tool = makeTool(item)
	tool.Equipped:Connect(function()
		local handle = tool:FindFirstChild("Handle")
		if handle then
			ItemService.PlaySound(handle, "Equip")
		end
	end)
	tool.Activated:Connect(function()
		-- Tool.Activated fires on the server when the holder clicks; make sure it's still theirs.
		if tool.Parent ~= player.Character then
			return
		end
		if item.Kind == "Weapon" then
			useWeapon(player, tool, item)
		elseif item.Kind == "Trap" then
			placeTrap(player, item)
		elseif item.Kind == "Lock" then
			useLock(player, item)
		end
	end)
	tool.Parent = backpack
end

function ItemService.GiveTools(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	for _, item in Config.Items do
		if profile.Data.Items[item.Id] then
			giveTool(player, item)
		end
	end
end

function ItemService.Buy(player: Player, itemId: any)
	local item = if type(itemId) == "string" then itemsById[itemId] else nil
	local profile = DataService.Get(player)
	if not item or not profile then
		return
	end
	if profile.Data.Items[item.Id] then
		notify(player, "You already own " .. item.Name .. "!")
		return
	end
	if not DataService.TrySpend(player, item.Cost) then
		notify(player, "Not enough money! Need " .. Format.Money(item.Cost), "error")
		return
	end
	profile.Data.Items[item.Id] = true
	giveTool(player, item)
	DataService.PushState(player)
	notify(player, `{item.Icon} {item.Name} bought! It's in your hotbar.`, "success")
end

function ItemService.OnPlayerRemoving(player: Player)
	local plot = PlotService.GetPlotModel(player)
	if plot then
		plot:SetAttribute("Locked", nil)
	end
	local traps: { [string]: { BasePart } } = placedTraps[player] or {}
	for _, list in traps do
		for _, trap in list do
			trap:Destroy()
		end
	end
	placedTraps[player] = nil
	if lockParts[player] then
		lockParts[player]:Destroy()
		lockParts[player] = nil
	end
	lastUse[player] = nil
	lastFlung[player] = nil
end

return ItemService
