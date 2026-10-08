--[[
	DailyService: hands out the Daily Rewards (Config.DailyRewards; the rules are in
	shared/DailyRewards). One a day, Day 1 to Day 7 and round again; days you miss just pause it.

	Action "ClaimDaily": claims the next reward if the day has changed since your last claim.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DailyRewards = require(Shared.DailyRewards)
local Format = require(Shared.Format)
local Pets = require(Shared.Pets)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)
local ShopService = require(script.Parent.ShopService)

local DailyService = {}

-- (tests set this to step through the days)
DailyService.Now = os.time

local function notify(player: Player, text: string, kind: string)
	Remotes.Event("Notify"):FireClient(player, text, kind)
end

-- Claim the next reward. Returns the day claimed, or nil if there's nothing to claim yet.
function DailyService.Claim(player: Player): number?
	local profile = DataService.Get(player)
	if not profile or not profile.Session.Ready then
		return nil
	end
	local data = profile.Data
	local now = DailyService.Now()
	if not DailyRewards.Ready(data.DailyLastDay, now) then
		notify(player, `Your next daily reward is ready in {Format.Duration(DailyRewards.NextDayAt(now) - now)}`, "error")
		return nil
	end
	local day = DailyRewards.NextDay(data.DailyClaims)
	local reward = DailyRewards.Reward(day, DailyRewards.Round(data.DailyClaims))
	-- (marked claimed first, so a second click while this one is being handed out gets nothing)
	data.DailyClaims += 1
	data.DailyLastDay = DailyRewards.DayNumber(now)
	if reward.Kind == "Money" then
		-- (your income right now, the one the HUD shows: the card showed you the same amount)
		local income = player:GetAttribute("Income")
		local amount = DailyRewards.Amount(reward, if type(income) == "number" then income else 0)
		DataService.AddMoney(player, amount)
		notify(player, `Day {day} reward: {Format.Money(amount)}!`, "success")
	elseif reward.Kind == "Pet" and reward.Pet then
		PetService.GivePet(player, reward.Pet)
		local pet = Pets.ById[reward.Pet]
		notify(player, `Day {day} reward: {if pet then pet.Name else reward.Pet}! It's in your Pets.`, "success")
	elseif reward.Kind == "PetSlot" then
		PetService.AddEquipSlot(player)
		notify(player, `Day {day} reward: +1 pet slot! You can equip one more pet now.`, "success")
	end
	DataService.PushState(player)
	return day
end

function DailyService.Init()
	ShopService.RegisterAction("ClaimDaily", function(player: Player)
		DailyService.Claim(player)
	end)
end

return DailyService
