--[[
	HDAdmin: the HD Admin-style player commands in the admin panel (AdminService's "HD" command).

	Every command has a target - "me", "all", "others" or a player's UserId - and some take a
	value (a number or a message):
	  kill, respawn, heal, god / ungod, ff / unff, freeze / thaw, jail / unjail, bring, goto,
	  fling, explode, sparkles / fire / smoke / unfx, invisible / visible, size (value),
	  speed / unspeed (value), jump (value), sit, noclip / clip, kick, ban
	and a few for the whole server:
	  announce (message), time (hour of day), gravity (value), unbanall, shutdown.

	The game's owner (AdminService.IsOwner) can't be kicked, banned, killed, frozen, jailed or
	flung by anyone else, so the panel can't be turned against you in your own game.
	Bans only last for this server.

	Only the owner can use these on other players or on the whole server. The admin code gets
	passed around, and a code that let anyone kill, kick or ban other players (or send messages to
	everyone) would be a way to bully them, so everyone else can only use them on themselves.
	Announcements go through Roblox's text filter (TextService) like chat does: Roblox's rules
	require every message a player types to be filtered before anyone else sees it.
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Build = require(script.Parent.Build)
local ItemService = require(script.Parent.ItemService)

local HDAdmin = {}

-- Set by AdminService: is this player the game's owner (protected from other admins)?
HDAdmin.IsOwner = function(_player: Player): boolean
	return false
end

local rgb = Color3.fromRGB
local banned: { [number]: string } = {} -- UserId -> name (this server only)
local jails: { [Player]: Model } = {}
local savedTransparency: { [Player]: { [Instance]: number } } = {}

local function notify(player: Player, text: string, kind: string?)
	Remotes.Event("Notify"):FireClient(player, text, kind or "info")
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- Who a command is aimed at.
local function targets(caller: Player, target: any): { Player }
	if target == "all" then
		return Players:GetPlayers()
	elseif target == "others" then
		local list = {}
		for _, player in Players:GetPlayers() do
			if player ~= caller then
				table.insert(list, player)
			end
		end
		return list
	elseif type(target) == "number" then
		local player = Players:GetPlayerByUserId(target)
		return if player then { player } else {}
	end
	return { caller }
end

-- Commands that would hurt the target (can't be used on the owner by anyone else).
local HARMFUL = { kill = true, explode = true, fling = true, freeze = true, jail = true, kick = true, ban = true, bring = true, size = true, sit = true, invisible = true, speed = true, jump = true }

local function clearEffects(root: BasePart)
	for _, child in root:GetChildren() do
		if child:GetAttribute("AdminFX") then
			child:Destroy()
		end
	end
end

local function addEffect(root: BasePart, className: string)
	local effect = Instance.new(className)
	effect:SetAttribute("AdminFX", true)
	effect.Parent = root
end

local function setVisible(player: Player, visible: boolean)
	local character = player.Character
	if not character then
		return
	end
	if visible then
		local previous: { [Instance]: number } = savedTransparency[player] or {}
		for part, value in previous do
			if part.Parent then
				(part :: any).Transparency = value
			end
		end
		savedTransparency[player] = nil
	else
		local saved: { [Instance]: number } = savedTransparency[player] or {}
		for _, part in character:GetDescendants() do
			if (part:IsA("BasePart") and part.Name ~= "HumanoidRootPart") or part:IsA("Decal") then
				if saved[part] == nil then
					saved[part] = (part :: any).Transparency
				end
				(part :: any).Transparency = 1
			end
		end
		savedTransparency[player] = saved
	end
end

local function unjail(player: Player)
	local jail = jails[player]
	if jail then
		jail:Destroy()
		jails[player] = nil
	end
end

local function jail(player: Player)
	local root = rootOf(player)
	if not root then
		return
	end
	unjail(player)
	local cage = Instance.new("Model")
	cage.Name = "AdminJail"
	local base = CFrame.new(root.Position - Vector3.new(0, 3, 0))
	Build.Part({ Parent = cage, Name = "Floor", Size = Vector3.new(10, 1, 10), CFrame = base, Color = rgb(60, 60, 70), Material = Enum.Material.Metal })
	Build.Part({ Parent = cage, Name = "Roof", Size = Vector3.new(10, 1, 10), CFrame = base * CFrame.new(0, 11, 0), Color = rgb(60, 60, 70), Material = Enum.Material.Metal })
	for i = -2, 2 do
		for _, side in { -1, 1 } do
			Build.Part({ Parent = cage, Name = "Bar", Size = Vector3.new(0.6, 10, 0.6), CFrame = base * CFrame.new(i * 2.2, 5.5, side * 4.7), Color = rgb(90, 90, 100), Material = Enum.Material.Metal })
			Build.Part({ Parent = cage, Name = "Bar", Size = Vector3.new(0.6, 10, 0.6), CFrame = base * CFrame.new(side * 4.7, 5.5, i * 2.2), Color = rgb(90, 90, 100), Material = Enum.Material.Metal })
		end
	end
	cage.Parent = workspace
	jails[player] = cage
end

type Handler = (caller: Player, target: Player, value: any) -> ()
local Actions: { [string]: Handler } = {}

function Actions.kill(_caller, target)
	local humanoid = humanoidOf(target)
	if humanoid then
		humanoid.Health = 0
	end
end

function Actions.respawn(_caller, target)
	local anyTarget = target :: any
	if not pcall(function()
		anyTarget:LoadCharacterAsync()
	end) then
		anyTarget:LoadCharacter()
	end
end

function Actions.heal(_caller, target)
	local humanoid = humanoidOf(target)
	if humanoid then
		humanoid.Health = humanoid.MaxHealth
	end
end

function Actions.god(_caller, target)
	local humanoid = humanoidOf(target)
	if humanoid then
		humanoid.MaxHealth = math.huge
		humanoid.Health = math.huge
	end
end

function Actions.ungod(_caller, target)
	local humanoid = humanoidOf(target)
	if humanoid then
		humanoid.MaxHealth = 100
		humanoid.Health = 100
	end
end

function Actions.ff(_caller, target)
	local character = target.Character
	if character and not character:FindFirstChild("AdminForceField") then
		local field = Instance.new("ForceField")
		field.Name = "AdminForceField"
		field.Parent = character
	end
end

function Actions.unff(_caller, target)
	local character = target.Character
	local field = character and character:FindFirstChild("AdminForceField")
	if field then
		field:Destroy()
	end
end

function Actions.freeze(_caller, target)
	local root = rootOf(target)
	if root then
		root.Anchored = true
	end
	target:SetAttribute("Frozen", true)
end

function Actions.thaw(_caller, target)
	local root = rootOf(target)
	if root then
		root.Anchored = false
	end
	target:SetAttribute("Frozen", nil)
end

function Actions.jail(_caller, target)
	jail(target)
end

function Actions.unjail(_caller, target)
	unjail(target)
end

function Actions.bring(caller, target)
	local from = rootOf(caller)
	local character = target.Character
	if from and character and target ~= caller then
		character:PivotTo(from.CFrame * CFrame.new(0, 0, -5))
	end
end

function Actions.goto(caller, target)
	local to = rootOf(target)
	local character = caller.Character
	if to and character and target ~= caller then
		character:PivotTo(to.CFrame * CFrame.new(0, 0, -5))
	end
end

function Actions.fling(caller, target)
	local from = rootOf(caller)
	local root = rootOf(target)
	if root then
		ItemService.Fling(target, if from and target ~= caller then from.Position else root.Position - Vector3.new(1, 0, 0), 160)
	end
end

function Actions.explode(_caller, target)
	local root = rootOf(target)
	if root then
		local blast = Instance.new("Explosion")
		blast.Position = root.Position
		blast.BlastRadius = 8
		blast.Parent = workspace
		local humanoid = humanoidOf(target)
		if humanoid then
			humanoid.Health = 0
		end
	end
end

for _, name in { "sparkles", "fire", "smoke" } do
	local className = if name == "sparkles" then "Sparkles" elseif name == "fire" then "Fire" else "Smoke"
	Actions[name] = function(_caller, target)
		local root = rootOf(target)
		if root then
			addEffect(root, className)
		end
	end
end

function Actions.unfx(_caller, target)
	local root = rootOf(target)
	if root then
		clearEffects(root)
	end
end

function Actions.invisible(_caller, target)
	setVisible(target, false)
end

function Actions.visible(_caller, target)
	setVisible(target, true)
end

function Actions.size(_caller, target, value)
	local scale = math.clamp(tonumber(value) or 1, 0.25, 6)
	local character = target.Character
	if character then
		pcall(function()
			(character :: any):ScaleTo(scale)
		end)
	end
end

function Actions.speed(_caller, target, value)
	target:SetAttribute("AdminWalkSpeed", math.clamp(tonumber(value) or 16, 0, 2000))
end

function Actions.unspeed(_caller, target)
	target:SetAttribute("AdminWalkSpeed", nil)
end

function Actions.jump(_caller, target, value)
	local humanoid = humanoidOf(target)
	if humanoid then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = math.clamp(tonumber(value) or 50, 0, 1000)
	end
end

function Actions.sit(_caller, target)
	local humanoid = humanoidOf(target)
	if humanoid then
		humanoid.Sit = true
	end
end

function Actions.noclip(_caller, target)
	target:SetAttribute("Noclip", true)
end

function Actions.clip(_caller, target)
	target:SetAttribute("Noclip", nil)
end

function Actions.kick(caller, target)
	if target ~= caller then
		target:Kick(`You were kicked by {caller.DisplayName}.`)
	end
end

function Actions.ban(caller, target)
	if target ~= caller then
		banned[target.UserId] = target.Name
		target:Kick(`You were banned from this server by {caller.DisplayName}.`)
	end
end

-- Whole-server commands (no target). Returns false when it didn't happen (it says why).
local ServerActions: { [string]: (caller: Player, value: any) -> boolean? } = {}

-- What the caller typed, as everyone may see it (Roblox's filter, for a message to the whole
-- server), or nil when the filter can't be reached: then nothing is shown.
local function filterForEveryone(caller: Player, text: string): string?
	local ok, filtered = pcall(function()
		local result = TextService:FilterStringAsync(text, caller.UserId, Enum.TextFilterContext.PublicChat)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	return if ok and type(filtered) == "string" then filtered else nil
end

function ServerActions.announce(caller, value)
	if type(value) ~= "string" or value == "" then
		notify(caller, "Type the message in the value box first.", "error")
		return false
	end
	local text = filterForEveryone(caller, string.sub(value, 1, 200))
	if not text then
		notify(caller, "Couldn't check that message with Roblox's filter, so it wasn't sent. Try again.", "error")
		return false
	end
	Remotes.Event("AreaAnnouncement"):FireAllClients(`📢 {caller.DisplayName}: {text}`, rgb(255, 220, 90))
	return true
end

function ServerActions.time(_caller, value)
	Lighting.ClockTime = math.clamp(tonumber(value) or 14, 0, 24)
	return true
end

function ServerActions.gravity(_caller, value)
	workspace.Gravity = math.clamp(tonumber(value) or 196.2, 0, 1000)
	return true
end

function ServerActions.unbanall(_caller)
	table.clear(banned)
	return true
end

function ServerActions.shutdown(caller)
	for _, player in Players:GetPlayers() do
		player:Kick(`The server was shut down by {caller.DisplayName}.`)
	end
	return true
end

-- Run a command from the panel: { Action, Target, Value }.
function HDAdmin.Run(caller: Player, arg: any)
	if type(arg) ~= "table" or type(arg.Action) ~= "string" then
		return
	end
	local owner = HDAdmin.IsOwner(caller)
	local serverAction = ServerActions[arg.Action]
	if serverAction then
		if not owner then
			notify(caller, "Only the game's owner can do that.", "error")
		elseif serverAction(caller, arg.Value) ~= false then
			notify(caller, `✅ {arg.Action} done`, "success")
		end
		return
	end
	local action = Actions[arg.Action]
	if not action then
		return
	end
	if not owner and arg.Target ~= "me" and arg.Target ~= caller.UserId then
		notify(caller, "Only the game's owner can use these on other players.", "error")
		return
	end
	local count, skipped = 0, 0
	for _, target in targets(caller, arg.Target) do
		if HARMFUL[arg.Action] and target ~= caller and HDAdmin.IsOwner(target) and not HDAdmin.IsOwner(caller) then
			skipped += 1
		else
			local ok, err = pcall(function()
				action(caller, target, arg.Value)
			end)
			if ok then
				count += 1
			else
				warn(`[HDAdmin] {arg.Action} failed: {err}`)
			end
		end
	end
	notify(caller, `✅ {arg.Action}: {count} player{if count == 1 then "" else "s"}{if skipped > 0 then " (the game's owner is protected)" else ""}`, "success")
end

function HDAdmin.IsBanned(player: Player): boolean
	return banned[player.UserId] ~= nil
end

function HDAdmin.Init()
	Players.PlayerAdded:Connect(function(player: Player)
		if HDAdmin.IsBanned(player) then
			player:Kick("You're banned from this server.")
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		unjail(player)
		savedTransparency[player] = nil
	end)
end

return HDAdmin
