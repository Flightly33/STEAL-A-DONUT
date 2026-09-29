--[[
	ProductService
	==============
	Developer products (Robux purchases you can buy again and again):
	  * Luck Event (Config.LuckEvent) - starts / extends the server-wide Luck Event.
	  * Tips (Config.Donations.Products) - added to your "Robux donated" total, which has its own
	    leaderboard (LeaderboardService, board "Donated", saved right away). Every tip also gives a
	    title (Tipper ... Ultimate Donor) shown above your head and in chat; your biggest tip's
	    title is the one you keep.
	  * Crates (Config.Crates.Products) - opened right away (CrateService). Paid random items: only
	    offered to players whose region allows them (CrateService.CanBuy).

	MarketplaceService.ProcessReceipt can only have ONE handler per game, so every product goes
	through here. Receipts are remembered in the player's data (Data.Purchases) and saved before the
	purchase is confirmed, so Roblox retrying a receipt can never grant it twice.

	In Studio every product with an ID shows Roblox's purchase window (a free test purchase). Test
	tips in Studio give the title and show on the board for that session, but are never saved, so
	test purchases can't put fake Robux on the real board.
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
local LeaderboardService = require(script.Parent.LeaderboardService)
local LuckService = require(script.Parent.LuckService)
local CrateService = require(script.Parent.CrateService)

local ProductService = {}

local MAX_RECEIPTS = 100

local function notify(player: Player, text: string, kind: string?)
	Remotes.Event("Notify"):FireClient(player, text, kind or "info")
end

-- Studio only: something without a real ID yet (0) is granted for free for this test session.
local function studioFree(id: number): boolean
	return RunService:IsStudio() and Config.Debug.StudioFreePurchases and id <= 0
end

local function donationFor(productId: number): Config.DonationProduct?
	for _, product in Config.Donations.Products do
		if product.DeveloperProductId > 0 and product.DeveloperProductId == productId then
			return product
		end
	end
	return nil
end

-- The title for someone whose biggest tip was `tier` Robux (nil below the smallest tip).
function ProductService.TitleFor(tier: number): Config.DonationProduct?
	local best: Config.DonationProduct? = nil
	for _, product in Config.Donations.Products do
		if tier >= product.Amount and (best == nil or product.Amount > best.Amount) then
			best = product
		end
	end
	return best
end

-- Show the player's donor title above their head (everyone sees it) and set the attributes the
-- chat tag reads.
function ProductService.ApplyTitle(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local title = ProductService.TitleFor(math.max(profile.Data.DonorTier, profile.Session.TestDonorTier))
	player:SetAttribute("DonorTitle", if title then title.Title else nil)
	player:SetAttribute("DonorTitleColor", if title then title.Color else nil)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild("DonorTitle")
	if old then
		old:Destroy()
	end
	if not title then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "DonorTitle"
	gui.Size = UDim2.fromOffset(220, 30)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = `💖 {title.Title}`
	label.TextColor3 = title.Color
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(40, 20, 40)
	label.Parent = gui
	gui.Parent = head
end

-- Add a tip to the player's total (saved and put on the donation board right away) and give its
-- title. `paid` is what Roblox actually charged (the receipt's CurrencySpent), which can differ from
-- the listed amount when Roblox manages the price; the board counts what was really paid.
local function recordDonation(player: Player, product: Config.DonationProduct, paid: number?)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local amount = if paid and paid > 0 then paid else product.Amount
	local hadTitle = ProductService.TitleFor(math.max(profile.Data.DonorTier, profile.Session.TestDonorTier))
	if RunService:IsStudio() then
		profile.Session.TestDonated += amount
		profile.Session.TestDonorTier = math.max(profile.Session.TestDonorTier, product.Amount)
	else
		profile.Data.Donated += amount
		profile.Data.DonorTier = math.max(profile.Data.DonorTier, product.Amount)
	end
	player:SetAttribute("Donated", profile.Data.Donated + profile.Session.TestDonated)
	ProductService.ApplyTitle(player)
	local title = ProductService.TitleFor(math.max(profile.Data.DonorTier, profile.Session.TestDonorTier))
	if title and title ~= hadTitle then
		notify(player, `💖 Thank you for the R$ {amount} tip! You're now a {title.Title}!`, "success")
	else
		notify(player, `💖 Thank you for the R$ {amount} tip!`, "success")
	end
	Remotes.Event("AreaAnnouncement"):FireAllClients(`💖 {player.DisplayName} tipped R$ {Format.Commas(amount)}! Thank you!`, Color3.fromRGB(255, 110, 180))
	DataService.PushState(player)
	LeaderboardService.OnDonation(player)
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
local function grant(player: Player, productId: number, paid: number?): boolean
	if Config.LuckEvent.DeveloperProductId > 0 and productId == Config.LuckEvent.DeveloperProductId then
		LuckService.Start(player)
		return true
	end
	local donation = donationFor(productId)
	if donation then
		recordDonation(player, donation, paid)
		return true
	end
	local crateId = crateFor(productId)
	if crateId then
		-- Already paid for, so it's always opened (even if the region check changed meanwhile).
		return CrateService.Open(player, crateId, "Bought") ~= nil
	end
	return false
end

local function processReceipt(receipt: { PlayerId: number, ProductId: number, PurchaseId: string, CurrencySpent: number? }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local profile = if player then DataService.Get(player) else nil
	if not player or not profile or not profile.Session.Ready then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox tries again when they're back
	end
	local receipts = profile.Data.Purchases
	if table.find(receipts, receipt.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already granted
	end
	if not grant(player, receipt.ProductId, receipt.CurrencySpent) then
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
	if studioFree(id) then
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
	if studioFree(product.DeveloperProductId) then
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
			if studioFree(product.DeveloperProductId) then
				recordDonation(player, product, nil)
				notify(player, "(Studio test tip - free and not saved)")
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
	-- Donor titles above heads: when the save loads and on every respawn
	DataService.ProfileLoaded:Connect(function(player: Player)
		ProductService.ApplyTitle(player)
	end)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			character:WaitForChild("Head", 10)
			ProductService.ApplyTitle(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return ProductService
