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

	Anyone who gets flung while carrying a donut drops it: it goes back where it came from (a raided
	donut flies back onto its owner's stand). The Slap Hand is free for everyone (Config Starter), so
	every owner can defend their base. The item models themselves live in shared/ItemModel.luau.
	Every item has sound effects (built-in Roblox sounds, so nothing needs uploading).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Layout = require(Shared.Layout)
local Remotes = require(Shared.Remotes)

local ItemModel = require(Shared.ItemModel)

local Build = require(script.Parent.Build)
local MapBuilder = require(script.Parent.MapBuilder)
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
local lockParts: { [Player]: Instance } = {}
local LOCK_HEIGHT = 80 -- studs: nobody jumps over that

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

-- Traps go at your feet: in your base, in the lane, in front of someone's base... anywhere except
-- INSIDE another player's base (that would just trap them in their own home).
local function placeTrap(player: Player, item: Config.Item)
	local root = rootOf(player)
	local plotIndex = PlotService.GetPlotIndex(player)
	local plot = PlotService.GetPlotModel(player)
	if not root or not plotIndex or not plot then
		return
	end
	for _, other in Players:GetPlayers() do
		if other ~= player and PlotService.IsInOwnPlot(other, root.Position) then
			notify(player, "You can't put traps inside someone else's base.", "error")
			return
		end
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

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local feet = root.Position.Y - (if humanoid then humanoid.HipHeight else 2) - root.Size.Y / 2
	local position = Vector3.new(root.Position.X, feet, root.Position.Z)
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

-- Take the player's base lock down (if there is one).
function ItemService.StopLock(player: Player)
	local field = lockParts[player]
	if not field then
		return
	end
	lockParts[player] = nil
	local plot = field.Parent
	if plot then
		plot:SetAttribute("Locked", nil)
	end
	local wall = field:FindFirstChild("LockWall")
	if wall and player.Parent then
		ItemService.PlaySound(wall, "Unlock")
	end
	field:Destroy()
end

-- The lock's walls: a force field on ALL four sides of the player's pen (just outside its fence),
-- far too tall to jump over. Built again when the base gets bigger.
local function buildLockWalls(player: Player, field: Model, permanent: boolean)
	local plotIndex = PlotService.GetPlotIndex(player)
	if not plotIndex then
		return
	end
	for _, child in field:GetChildren() do
		child:Destroy()
	end
	local cf = Layout.PlotCFrame(plotIndex, PlotService.GetBaseWorld(player))
	local center, size = Layout.PenBounds(PlotService.GetSlotCount(player))
	local w, d, h = size.X + 8, size.Y + 8, LOCK_HEIGHT
	local middle = cf * CFrame.new(center)
	type Side = { Offset: CFrame, Size: Vector3 }
	local sides: { Side } = {
		{ Offset = CFrame.new(0, h / 2, -d / 2), Size = Vector3.new(w + 2, h, 0.6) }, -- front (the gate)
		{ Offset = CFrame.new(0, h / 2, d / 2), Size = Vector3.new(w + 2, h, 0.6) }, -- back
		{ Offset = CFrame.new(-w / 2, h / 2, 0), Size = Vector3.new(0.6, h, d + 2) }, -- left
		{ Offset = CFrame.new(w / 2, h / 2, 0), Size = Vector3.new(0.6, h, d + 2) }, -- right
	}
	for _, side in sides do
		local wall = Build.Part({
			Parent = field, Name = "LockWall",
			Size = side.Size,
			CFrame = middle * side.Offset,
			Color = if permanent then rgb(255, 200, 40) else rgb(255, 40, 40),
			Material = Enum.Material.ForceField, Transparency = 0.2, CanCollide = false,
		})
		wall.Touched:Connect(function(hit: BasePart)
			local victim = playerFromPart(hit)
			if victim and victim ~= player then
				ItemService.Fling(victim, middle.Position, 90)
			end
		end)
	end
end

-- Lock the player's base: the walls push other players away, and anyone who still gets inside
-- (hopping in, lag) is put outside the gate. `duration` in seconds, or nil for a lock that stays
-- until StopLock (admin panel).
local function startLock(player: Player, duration: number?): boolean
	local plot = PlotService.GetPlotModel(player)
	local plotIndex = PlotService.GetPlotIndex(player)
	if not plot or not plotIndex then
		return false
	end
	ItemService.StopLock(player)
	local cf = Layout.PlotCFrame(plotIndex, PlotService.GetBaseWorld(player))
	local field = Instance.new("Model")
	field.Name = "LockLaser"
	field:SetAttribute("Permanent", duration == nil)
	buildLockWalls(player, field, duration == nil)
	field.Parent = plot
	lockParts[player] = field
	plot:SetAttribute("Locked", true)
	ItemService.PlaySound(field:FindFirstChild("LockWall") :: BasePart, "Lock")
	task.spawn(function()
		while lockParts[player] == field and field.Parent do
			for _, other in Players:GetPlayers() do
				local root = if other ~= player then rootOf(other) else nil
				if root and Layout.IsInPlot(plotIndex, root.Position, PlotService.GetBaseWorld(player), PlotService.GetSlotCount(player), 4) then
					local character = other.Character
					if character then
						character:PivotTo(cf * CFrame.new(0, 4, Layout.PenFront - 14) * CFrame.Angles(0, math.pi, 0))
						notify(other, "🔒 That base is locked!", "error")
					end
				end
			end
			task.wait(0.2)
		end
	end)
	if duration then
		task.delay(duration, function()
			if lockParts[player] == field then
				ItemService.StopLock(player)
				if player.Parent then
					notify(player, "🔓 Your base lock wore off.")
				end
			end
		end)
	end
	return true
end

local function useLock(player: Player, item: Config.Item)
	local profile = DataService.Get(player)
	if profile and profile.Data.PermaLock then
		notify(player, "🔒 Your base is already permanently locked (admin panel).")
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
	if startLock(player, duration) then
		lastUse[player][item.Id] = os.clock()
		notify(player, `🔒 Base locked for {duration}s!`, "success")
	end
end

-- Admin panel: a Base Lock that never runs out (saved, so it comes back when you rejoin or move
-- your base to another world) - or take it off again.
function ItemService.SetPermanentLock(player: Player, on: boolean)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	profile.Data.PermaLock = on
	if on then
		startLock(player, nil)
	else
		ItemService.StopLock(player)
	end
	DataService.PushState(player)
end

-- Re-apply a permanent lock (the base was just assigned or moved to another world).
function ItemService.RestoreLock(player: Player)
	local profile = DataService.Get(player)
	if profile and profile.Data.PermaLock then
		startLock(player, nil)
	end
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
	local tool = ItemModel.BuildTool(item)
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
		if (profile.Data.Items[item.Id] or item.Starter) and not profile.Data.HiddenItems[item.Id] then
			giveTool(player, item)
		end
	end
end

-- Take an item off the hotbar (you still own it) or put it back. Saved.
function ItemService.ToggleHotbar(player: Player, itemId: any)
	local item = if type(itemId) == "string" then itemsById[itemId] else nil
	local profile = DataService.Get(player)
	if not item or not profile or not (profile.Data.Items[item.Id] or item.Starter) then
		return
	end
	local hide = not profile.Data.HiddenItems[item.Id]
	if hide then
		profile.Data.HiddenItems[item.Id] = true
		local containers: { Instance? } = { player:FindFirstChildOfClass("Backpack"), player.Character }
		for _, container in containers do
			if container then
				for _, child in container:GetChildren() do
					if child:IsA("Tool") and child:GetAttribute("ItemId") == item.Id then
						child:Destroy()
					end
				end
			end
		end
		notify(player, `{item.Icon} {item.Name} taken off your hotbar (you still own it).`)
	else
		profile.Data.HiddenItems[item.Id] = nil
		giveTool(player, item)
		notify(player, `{item.Icon} {item.Name} is back on your hotbar.`, "success")
	end
	DataService.PushState(player)
end

function ItemService.Buy(player: Player, itemId: any)
	local item = if type(itemId) == "string" then itemsById[itemId] else nil
	local profile = DataService.Get(player)
	if not item or not profile then
		return
	end
	if profile.Data.Items[item.Id] or item.Starter then
		notify(player, "You already own " .. item.Name .. "!")
		return
	end
	if not DataService.TrySpend(player, item.Cost) then
		notify(player, "Not enough money! Need " .. Format.Money(item.Cost), "error")
		return
	end
	profile.Data.Items[item.Id] = true
	profile.Data.HiddenItems[item.Id] = nil
	giveTool(player, item)
	DataService.PushState(player)
	notify(player, `{item.Icon} {item.Name} bought! It's in your hotbar.`, "success")
end

-- Remove the player's traps and base lock (they left, or their base moved to another world).
local function clearBaseItems(player: Player, plot: Model?)
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
	ItemService.StopLock(player)
end

function ItemService.Init()
	PlotService.BaseMoved:Connect(function(player: Player, oldWorld: number)
		local index = PlotService.GetPlotIndex(player)
		clearBaseItems(player, if index then MapBuilder.GetPlot(index, oldWorld) else nil)
		ItemService.RestoreLock(player)
	end)
	-- A bigger base: the lock's walls move out to the new fence.
	PlotService.Resized:Connect(function(player: Player)
		local field = lockParts[player]
		if field and field:IsA("Model") and field.Parent then
			buildLockWalls(player, field, field:GetAttribute("Permanent") == true)
		end
	end)
end

function ItemService.OnPlayerRemoving(player: Player)
	clearBaseItems(player, PlotService.GetPlotModel(player))
	lastUse[player] = nil
	lastFlung[player] = nil
end

return ItemService
