--[[
	RaidService
	===========
	Stealing from other players' bases (like "Steal a Brainrot"):
	  * Every donut on a base has a "Steal" prompt (hold Config.Raid.HoldSeconds). It works whether
	    or not the owner is home - only an active Base Lock protects a base. The owner never sees
	    the prompt on their own donuts.
	  * The owner hears an alarm and gets a warning the moment someone starts holding, and a louder
	    alarm (plus a red outline on the thief) when the donut is taken.
	  * The thief carries the donut over their head in slow mode (Config.Raid.CarryWalkSpeed). If the
	    owner - or anyone - hits them before they reach their own base, it flies straight back onto
	    the owner's stand (StealService).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Donuts = require(Shared.Donuts)
local Rarities = require(Shared.Rarities)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local StealService = require(script.Parent.StealService)

local RaidService = {}

local holdStarts: { [ProximityPrompt]: { [Player]: number } } = setmetatable({}, { __mode = "k" }) :: any
local lastWarning: { [Player]: number } = {}
local lastAttempt: { [Player]: number } = {}

local function notify(player: Player, text: string, kind: string?)
	Remotes.Event("Notify"):FireClient(player, text, kind or "info")
end

-- Can this player's base be raided right now? Only a Base Lock stops raids.
function RaidService.IsProtected(owner: Player): boolean
	if not PlotService.GetPlotIndex(owner) then
		return true
	end
	local plot = PlotService.GetPlotModel(owner)
	return plot ~= nil and plot:GetAttribute("Locked") == true
end

local function slotDonutName(owner: Player, slotIndex: number): string
	local profile = DataService.Get(owner)
	local slot = profile and profile.Data.Slots[tostring(slotIndex)]
	local donut = slot and Donuts.ById[slot.Id]
	return if slot and donut then Rarities.DisplayName(donut.Name, slot.Mutation, slot.Size) else "donut"
end

local function tryRaid(owner: Player, slotIndex: number, prompt: ProximityPrompt, thief: Player)
	local starts = holdStarts[prompt]
	local started = starts and starts[thief]
	if starts then
		starts[thief] = nil
	end
	-- The hold happens on the thief's device, so check it really lasted long enough. (If the hold
	-- start never reached the server, at least stop anyone from firing steals faster than a hold.)
	local now = os.clock()
	if started and now - started < Config.Raid.HoldSeconds * 0.8 then
		return
	end
	if not started and lastAttempt[thief] and now - lastAttempt[thief] < Config.Raid.HoldSeconds * 0.8 then
		return
	end
	lastAttempt[thief] = now
	if thief == owner or not owner.Parent then
		return
	end
	if RaidService.IsProtected(owner) then
		notify(thief, "🔒 That base is locked!", "error")
		return
	end
	local target = prompt.Parent
	if not target or not target:IsA("BasePart") then
		return
	end
	if not StealService.CanPickUp(thief, target.Position, 16) then
		return
	end
	if not PlotService.HasFreeSlot(thief) then
		notify(thief, "Your base is full! Sell a donut to make room.", "error")
		return
	end

	local slot = PlotService.TakeSlot(owner, slotIndex)
	if not slot then
		return
	end
	StealService.StartRaid(thief, owner, slot, slotIndex)
	local donut = Donuts.ById[slot.Id]
	local name = Rarities.DisplayName(donut.Name, slot.Mutation, slot.Size)
	notify(owner, `🚨 {thief.DisplayName} stole your {name}! Hit them before they get home to get it back!`, "error")
	Remotes.Event("Alarm"):FireClient(owner, { Stage = "Stolen", Thief = thief, Name = name })
	notify(thief, `You stole {owner.DisplayName}'s {name}! You're slowed down - run to your base before they hit you!`, "success")
	local rarity = Rarities.Get(donut.Rarity)
	if rarity.Order >= Config.Spawns.AnnounceRarity then
		Remotes.Event("AreaAnnouncement"):FireAllClients(`{thief.DisplayName} stole {owner.DisplayName}'s {string.upper(rarity.Id)} {name}!`, rarity.Color)
	end
end

local function hookPrompt(owner: Player, slotIndex: number, prompt: ProximityPrompt)
	prompt.PromptButtonHoldBegan:Connect(function(thief: Player)
		if thief == owner then
			return
		end
		holdStarts[prompt] = holdStarts[prompt] or {}
		holdStarts[prompt][thief] = os.clock()
		if Config.Raid.WarnOwner and (not lastWarning[owner] or os.clock() - lastWarning[owner] > 4) then
			lastWarning[owner] = os.clock()
			local name = slotDonutName(owner, slotIndex)
			notify(owner, `⚠ {thief.DisplayName} is stealing your {name}! Get back to your base!`, "error")
			Remotes.Event("Alarm"):FireClient(owner, { Stage = "Started", Thief = thief, Name = name })
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
	lastAttempt[player] = nil
end

function RaidService.Init()
	if not Config.Raid.Enabled then
		return
	end
	PlotService.RaidHandler = hookPrompt

	-- Switch a base's raid prompts off while its Base Lock is on.
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
