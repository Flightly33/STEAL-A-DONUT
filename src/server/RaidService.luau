--[[
	RaidService
	===========
	Stealing from other players' bases (like "Steal a Brainrot"):
	  * Every donut on a base has a "Steal" prompt that takes Config.Raid.HoldSeconds to complete.
	  * It only works while the owner is OUTSIDE their base (and their Base Lock isn't on).
	    The owner never sees their own prompt.
	  * The owner is warned the moment someone starts holding.
	  * On success the donut leaves the owner's base and floats over the thief's head (StealService).
	    If the thief is hit (weapons/traps) or dies before getting home, it goes back to the owner.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Donuts = require(Shared.Donuts)
local Rarities = require(Shared.Rarities)
local Layout = require(Shared.Layout)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local StealService = require(script.Parent.StealService)

local RaidService = {}

local holdStarts: { [ProximityPrompt]: { [Player]: number } } = setmetatable({}, { __mode = "k" }) :: any
local lastWarning: { [Player]: number } = {}

local function notify(player: Player, text: string, kind: string?)
	Remotes.Event("Notify"):FireClient(player, text, kind or "info")
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Can this player's base be raided right now?
function RaidService.IsProtected(owner: Player): boolean
	local plotIndex = PlotService.GetPlotIndex(owner)
	if not plotIndex then
		return true
	end
	local plot = PlotService.GetPlotModel(owner)
	if plot and plot:GetAttribute("Locked") then
		return true
	end
	local root = rootOf(owner)
	if not root then
		return true -- respawning (you respawn inside your base anyway)
	end
	return Layout.IsInPlot(plotIndex, root.Position)
end

local function slotDonutName(owner: Player, slotIndex: number): string
	local profile = DataService.Get(owner)
	local slot = profile and profile.Data.Slots[tostring(slotIndex)]
	local donut = slot and Donuts.ById[slot.Id]
	return if donut then donut.Name else "donut"
end

local function tryRaid(owner: Player, slotIndex: number, prompt: ProximityPrompt, thief: Player)
	local starts = holdStarts[prompt]
	local started = starts and starts[thief]
	if starts then
		starts[thief] = nil
	end
	-- The hold happens on the thief's device, so check it really lasted long enough.
	if not started or os.clock() - started < Config.Raid.HoldSeconds * 0.85 then
		return
	end
	if thief == owner or not owner.Parent or RaidService.IsProtected(owner) then
		return
	end
	local profile = DataService.Get(thief)
	if not profile or not profile.Session.Ready or profile.Session.Stunned then
		return
	end
	if StealService.IsCarrying(thief) then
		notify(thief, "You're already carrying a donut! Bring it home first.", "error")
		return
	end
	if not PlotService.HasFreeSlot(thief) then
		notify(thief, "Your base is full! Sell a donut to make room.", "error")
		return
	end
	local root = rootOf(thief)
	local target = prompt.Parent
	if not root or not target or not target:IsA("BasePart") or (target.Position - root.Position).Magnitude > 15 then
		return
	end

	local slot = PlotService.TakeSlot(owner, slotIndex)
	if not slot then
		return
	end
	StealService.StartRaid(thief, owner, slot)
	local donut = Donuts.ById[slot.Id]
	notify(owner, `🚨 {thief.DisplayName} stole your {donut.Name}! Hit them before they get home to get it back!`, "error")
	notify(thief, `You stole {owner.DisplayName}'s {donut.Name}! Run to your base!`, "success")
	local rarity = Rarities.Get(donut.Rarity)
	if rarity.Order >= Config.Spawns.AnnounceRarity then
		Remotes.Event("AreaAnnouncement"):FireAllClients(`{thief.DisplayName} stole {owner.DisplayName}'s {string.upper(rarity.Id)} {donut.Name}!`, rarity.Color)
	end
end

local function hookPrompt(owner: Player, slotIndex: number, prompt: ProximityPrompt)
	prompt.PromptButtonHoldBegan:Connect(function(thief: Player)
		if thief == owner then
			return
		end
		holdStarts[prompt] = holdStarts[prompt] or {}
		holdStarts[prompt][thief] = os.clock()
		if Config.Raid.WarnOwner and (not lastWarning[owner] or os.clock() - lastWarning[owner] > 5) then
			lastWarning[owner] = os.clock()
			notify(owner, `⚠ {thief.DisplayName} is stealing your {slotDonutName(owner, slotIndex)}! Get back to your base!`, "error")
		end
	end)
	prompt.PromptButtonHoldEnded:Connect(function(thief: Player)
		local starts = holdStarts[prompt]
		if starts then
			starts[thief] = nil
		end
	end)
	prompt.Triggered:Connect(function(thief: Player)
		tryRaid(owner, slotIndex, prompt, thief)
	end)
end

function RaidService.OnPlayerRemoving(player: Player)
	lastWarning[player] = nil
end

function RaidService.Init()
	if not Config.Raid.Enabled then
		return
	end
	PlotService.RaidHandler = hookPrompt

	-- Switch every base's raid prompts on while its owner is away, off while they're home.
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, owner in Players:GetPlayers() do
				if DataService.IsReady(owner) then
					local open = not RaidService.IsProtected(owner)
					for _, prompt in PlotService.GetRaidPrompts(owner) do
						if prompt.Enabled ~= open then
							prompt.Enabled = open
						end
					end
				end
			end
		end
	end)
end

return RaidService
