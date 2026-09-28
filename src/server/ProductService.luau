--[[
	ProductService
	==============
	Developer products (Robux purchases you can buy again and again):
	  * Luck Event (Config.LuckEvent) - starts / extends the server-wide Luck Event.
	  * Donations (Config.Donations.Products) - added to your "Robux donated" total, which has its
	    own leaderboard (LeaderboardService, board "Donated").
	  * Crates (Config.Crates.Products) - opened right away (CrateService). Paid random items: only
	    offered to players whose region allows them (CrateService.CanBuy).

	MarketplaceService.ProcessReceipt can only have ONE handler per game, so every product goes
	through here. Receipts are remembered in the player's data (Data.Purchases) and saved before the
	purchase is confirmed, so Roblox retrying a receipt can never grant it twice.

	In Studio, with Config.Debug.StudioFreePurchases on, products are granted for free (for testing;
	donations made that way are not saved to the leaderboard).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local LuckService = require(script.Parent.LuckService)
local CrateService = require(script.Parent.CrateService)

local ProductService = {}

local MAX_RECEIPTS = 100

local function notify(player: Player, text: string, kind: string?)
	Remotes.Event("Notify"):FireClient(player, text, kind or "info")
end

local function studioFree(): boolean
	return RunService:IsStudio() and Config.Debug.StudioFreePurchases
end

local function donationFor(productId: number): Config.DonationProduct?
	for _, product in Config.Donations.Products do
		if product.DeveloperProductId > 0 and product.DeveloperProductId == productId then
			return product
		end
	end
	return nil
end

-- Add a donation to the player's total (saved and put on the donation board).
local function recordDonation(player: Player, amount: number, save: boolean)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	if save then
		profile.Data.Donated += amount
	end
	player:SetAttribute("Donated", profile.Data.Donated)
	notify(player, `💖 Thank you for donating R$ {amount}!`, "success")
	Remotes.Event("AreaAnnouncement"):FireAllClients(`💖 {player.DisplayName} donated R$ {Format.Commas(amount)}! Thank you!`, Color3.fromRGB(255, 110, 180))
	DataService.PushState(player)
end

local function crateFor(productId: number): string?
	for crateId, product in Config.Crates.Products do
		if product.DeveloperProductId > 0 and product.DeveloperProductId == productId then
			return crateId
		end
	end
	return nil
end

-- Grant a product. Returns false if it's not one of ours.
local function grant(player: Player, productId: number): boolean
	if Config.LuckEvent.DeveloperProductId > 0 and productId == Config.LuckEvent.DeveloperProductId then
		LuckService.Start(player)
		return true
	end
	local donation = donationFor(productId)
	if donation then
		recordDonation(player, donation.Amount, true)
		return true
	end
	local crateId = crateFor(productId)
	if crateId then
		-- Already paid for, so it's always opened (even if the region check changed meanwhile).
		return CrateService.Open(player, crateId, "Bought") ~= nil
	end
	return false
end

local function processReceipt(receipt: { PlayerId: number, ProductId: number, PurchaseId: string }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local profile = if player then DataService.Get(player) else nil
	if not player or not profile or not profile.Session.Ready then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox tries again when they're back
	end
	local receipts = profile.Data.Purchases
	if table.find(receipts, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already granted
	end
	if not grant(player, receipt.ProductId) then
		warn(`[Products] Unknown developer product {receipt.ProductId} - add it to Config.`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(receipts, receipt.PurchaseId)
	while #receipts > MAX_RECEIPTS do
		table.remove(receipts, 1)
	end
	DataService.SaveNow(player) -- remember the receipt before telling Roblox it's done
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ProductService.BuyLuck(player: Player)
	local id = Config.LuckEvent.DeveloperProductId
	if studioFree() then
		LuckService.Start(player)
		notify(player, "(Studio test purchase - free)")
	elseif id <= 0 then
		notify(player, "The Luck Event is coming soon!", "error")
	else
		MarketplaceService:PromptProductPurchase(player, id)
	end
end

function ProductService.BuyCrate(player: Player, crateId: any)
	local product = if type(crateId) == "string" then Config.Crates.Products[crateId] else nil
	if not product then
		return
	end
	if studioFree() then
		CrateService.Open(player, crateId, "Studio")
		notify(player, "(Studio test purchase - free)")
	elseif not CrateService.CanBuy(player) then
		notify(player, "Crates can't be bought in your region. You can still open the ones you find!", "error")
	elseif product.DeveloperProductId <= 0 then
		notify(player, "Crates are coming soon!", "error")
	else
		MarketplaceService:PromptProductPurchase(player, product.DeveloperProductId)
	end
end

function ProductService.Donate(player: Player, amount: any)
	if type(amount) ~= "number" then
		return
	end
	for _, product in Config.Donations.Products do
		if product.Amount == amount then
			if studioFree() then
				recordDonation(player, amount, false)
				notify(player, "(Studio test donation - free and not saved)")
			elseif product.DeveloperProductId <= 0 then
				notify(player, "Donations are coming soon!", "error")
			else
				MarketplaceService:PromptProductPurchase(player, product.DeveloperProductId)
			end
			return
		end
	end
end

function ProductService.Init()
	MarketplaceService.ProcessReceipt = processReceipt :: any
end

return ProductService
