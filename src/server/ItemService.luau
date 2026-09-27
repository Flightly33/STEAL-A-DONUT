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
local function decor(tool: Tool, handle: BasePart, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?)
	local part = Instance.new("Part")
	part.Name = "Decor"
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	if shape then
		part.Shape = shape
	end
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CFrame = handle.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = handle
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
	part.Parent = tool
end

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
	handle.Size = Vector3.new(0.4, 0.4, 3)
	handle.Color = rgb(120, 80, 45)
	handle.Parent = tool
	-- Held like a classic sword: grip at one end, the business end pointing forward/up.
	tool.GripPos = Vector3.new(0, 0, -1.2)
	tool.GripForward = Vector3.new(-1, 0, 0)
	tool.GripRight = Vector3.new(0, 1, 0)
	tool.GripUp = Vector3.new(0, 0, 1)

	if item.Id == "Slap" then
		handle.Color = rgb(255, 210, 60)
		decor(tool, handle, Vector3.new(1.6, 0.5, 1.8), CFrame.new(0, 0, 1.4), rgb(255, 225, 90))
		decor(tool, handle, Vector3.new(0.4, 0.4, 0.9), CFrame.new(0.9, 0, 1.2), rgb(255, 225, 90))
	elseif item.Id == "Bat" then
		handle.Material = Enum.Material.Wood
		handle.Size = Vector3.new(0.45, 0.45, 4)
		tool.GripPos = Vector3.new(0, 0, -1.6)
		decor(tool, handle, Vector3.new(0.8, 0.8, 2), CFrame.new(0, 0, 1.2), rgb(190, 120, 60), Enum.Material.Wood)
		decor(tool, handle, Vector3.new(0.9, 0.9, 0.3), CFrame.new(0, 0, 1.7), rgb(255, 150, 200))
	elseif item.Id == "Hammer" then
		handle.Size = Vector3.new(0.45, 0.45, 4.2)
		tool.GripPos = Vector3.new(0, 0, -1.7)
		decor(tool, handle, Vector3.new(2.6, 1.8, 1.8), CFrame.new(0, 0, 2), rgb(150, 90, 255), Enum.Material.Neon)
	elseif item.Id == "Banana" then
		handle.Size = Vector3.new(0.5, 0.4, 1.6)
		handle.Color = rgb(255, 225, 60)
		tool.GripPos = Vector3.new(0, 0, 0)
	elseif item.Id == "Spring" then
		handle.Size = Vector3.new(1.4, 0.4, 1.4)
		handle.Color = rgb(80, 200, 255)
		handle.Material = Enum.Material.Neon
		tool.GripPos = Vector3.new(0, 0, 0)
	elseif item.Id == "Lock" then
		handle.Size = Vector3.new(1, 1, 0.5)
		handle.Color = rgb(255, 70, 70)
		tool.GripPos = Vector3.new(0, 0, 0)
		decor(tool, handle, Vector3.new(0.7, 0.7, 0.2), CFrame.new(0, 0.7, 0), rgb(200, 200, 210), Enum.Material.Metal)
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
	local trap: BasePart
	if item.Id == "Banana" then
		trap = Build.Part({ Parent = folder, Name = "BananaTrap", Size = Vector3.new(2.2, 0.4, 1.2), CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, math.random() * 6, 0), Color = rgb(255, 225, 60), Material = Enum.Material.SmoothPlastic, CanCollide = false })
	else
		trap = Build.Part({ Parent = folder, Name = "LaunchPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 4, 4), CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = rgb(80, 200, 255), Material = Enum.Material.Neon, CanCollide = false })
	end
	trap:SetAttribute("OwnerUserId", player.UserId)
	trap.Touched:Connect(function(hit: BasePart)
		local victim = playerFromPart(hit)
		if victim and victim ~= player then
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
