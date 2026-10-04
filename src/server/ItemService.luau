--[[
	ItemService
	===========
	The bat (Config.Items): everyone gets it for free, every time they spawn, and it's the only
	item. Click to swing: everyone in front of you within Range is flung - and anyone carrying a box
	drops it on the ground right there (StealService.Knock), so you can grab it yourself.
	The bat's model lives in shared/ItemModel.luau; its sounds are built-in Roblox sounds.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local ItemModel = require(Shared.ItemModel)

local DataService = require(script.Parent.DataService)
local StealService = require(script.Parent.StealService)

local ItemService = {}

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
		if item.Starter or profile.Data.Items[item.Id] then
			giveTool(player, item)
		end
	end
end

function ItemService.Init() end

function ItemService.OnPlayerRemoving(player: Player)
	lastUse[player] = nil
	lastFlung[player] = nil
end

return ItemService
