--[[
	DonutHover: the buttons on your own pen donuts (Upgrade / Pick up / Favorite) only show for the
	donut you point at, so a pen full of donuts isn't a wall of buttons.

	  * Mouse: hover a donut and a soft outline goes round it and its buttons appear (E / F / R or
	    click them). They stay a moment after the pointer slips off (donuts walk around), and while
	    you're holding one.
	  * Phones and tablets: tap a donut to show its buttons for a few seconds; tap anywhere else to
	    hide them.
	  * Gamepad: no pointer, so it works as before - walk up to a donut.
	Other players' donuts never show these buttons (Effects' owner-only prompt filter).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local DonutHover = {}

local player = Players.LocalPlayer :: Player

local PROMPTS = { "UpgradePrompt", "PickUpPrompt", "FavoritePrompt" }
DonutHover.Reach = 40 -- studs: hovering works from further away than walking up to it
DonutHover.WalkUp = 12 -- studs: gamepads (no pointer) walk up to a donut, like before
DonutHover.Grace = 0.5 -- seconds the buttons stay after the pointer slips off the donut
DonutHover.TapHold = 6 -- seconds a tapped donut keeps its buttons

type Entry = { Model: Model, Prompts: { ProximityPrompt }, Checked: number, Radius: number?, Lift: number? }

local donuts: { [Model]: Entry } = {}
local current: Model? = nil
local currentSince = 0 -- (os.clock of the last time the pointer was on it)
local tappedUntil = 0
local held: ProximityPrompt? = nil -- (a button you're holding down right now, and since when)
local heldSince = 0
local outline: Highlight? = nil

local function mine(model: Model): boolean
	local root = model.PrimaryPart
	local prompt = root and root:FindFirstChild("PickUpPrompt")
	return prompt ~= nil and prompt:GetAttribute("OwnerUserId") == player.UserId
end

local function promptsOf(entry: Entry): { ProximityPrompt }
	local now = os.clock()
	if #entry.Prompts < #PROMPTS and now - entry.Checked > 1 then
		entry.Checked = now
		table.clear(entry.Prompts)
		local root = entry.Model.PrimaryPart
		for _, name in PROMPTS do
			local prompt = root and root:FindFirstChild(name)
			if prompt and prompt:IsA("ProximityPrompt") then
				table.insert(entry.Prompts, prompt)
			end
		end
	end
	return entry.Prompts
end

local function track(instance: Instance)
	if instance:IsA("Model") and not donuts[instance] then
		donuts[instance] = { Model = instance, Prompts = {}, Checked = -math.huge }
	end
end

-- Which way you're playing: "Pointer" (mouse), "Touch" or "Gamepad".
function DonutHover.Mode(): string
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "Touch"
	end
	local name = last.Name
	if string.sub(name, 1, 7) == "Gamepad" then
		return "Gamepad"
	end
	if not UserInputService.MouseEnabled and UserInputService.TouchEnabled then
		return "Touch"
	end
	return "Pointer"
end

-- Your pen donut at a spot on the screen (nil: none of yours there). Donut parts don't take
-- raycasts (CanQuery off, to keep the game light), so the pointer's ray is tested against a ball
-- round each of your donuts instead; the nearest one it passes through wins.
local function sizeOf(entry: Entry): (number, number)
	if not entry.Radius then
		local ok, cf, size = pcall(function()
			return entry.Model:GetBoundingBox()
		end)
		if ok and cf and size then
			entry.Radius = math.max(size.X, size.Y, size.Z) / 2
			entry.Lift = (cf.Position - entry.Model:GetPivot().Position).Y
		else
			entry.Radius, entry.Lift = 2, 1
		end
	end
	return entry.Radius :: number, entry.Lift :: number
end

local function donutAt(screen: Vector2): Model?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local found: Model? = nil
	pcall(function()
		local ray = camera:ViewportPointToRay(screen.X, screen.Y)
		local origin, direction = ray.Origin, ray.Direction.Unit
		local best = math.huge
		for model, entry in donuts do
			if not model.Parent or not mine(model) then
				continue
			end
			local radius, lift = sizeOf(entry)
			local center = model:GetPivot().Position + Vector3.new(0, lift, 0)
			local along = (center - origin):Dot(direction)
			if along > 0 and along < 400 and along < best then
				local miss = (origin + direction * along - center).Magnitude
				if miss <= radius then
					best = along
					found = model
				end
			end
		end
	end)
	return found
end

-- Show this donut's buttons (nil: hide them). Exposed for the tests and the tap handler.
function DonutHover.Select(model: Model?)
	if model and not mine(model) then
		model = nil
	end
	if model then
		currentSince = os.clock()
	end
	current = model
end

function DonutHover.Current(): Model?
	return current
end

local function setOutline(model: Model?)
	if not model then
		if outline then
			outline.Enabled = false
		end
		return
	end
	local highlight = outline
	if not highlight or not highlight.Parent then
		local new = Instance.new("Highlight")
		new.Name = "DonutHoverOutline"
		new.FillTransparency = 1
		new.OutlineColor = Color3.fromRGB(255, 240, 200)
		new.OutlineTransparency = 0.25
		new.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight = new
		outline = new
	end
	local h = highlight :: Highlight
	if h.Adornee ~= model then
		h.Adornee = model
		h.Parent = model
	end
	h.Enabled = true
end

-- Holding down one of this donut's own buttons (Pick up takes a moment) keeps it chosen.
local function holding(): boolean
	local prompt, model = held, current
	if not prompt or not model or os.clock() - heldSince >= 3 then
		return false
	end
	-- (the prompt can be gone by now: a box you were grabbing, a donut you just picked up)
	local ok, inside = pcall(function()
		return prompt:IsDescendantOf(model)
	end)
	return ok and inside == true
end

-- Every frame: who's pointed at, and which prompts can show.
function DonutHover.Step()
	local now = os.clock()
	local mode = DonutHover.Mode()
	if mode == "Pointer" then
		local pointed = donutAt(UserInputService:GetMouseLocation())
		if pointed and mine(pointed) then
			current = pointed
			currentSince = now
		elseif current and not holding() and now - currentSince > DonutHover.Grace then
			current = nil
		end
	elseif mode == "Touch" then
		if current and not holding() and now > tappedUntil and now - currentSince > DonutHover.Grace then
			current = nil
		end
	end
	if current and not (current :: Model).Parent then
		current = nil
	end
	if current and not donuts[current :: Model] then
		track(current :: Model) -- (in case its tag arrived before we were listening)
	end
	for model, entry in donuts do
		if not model.Parent then
			donuts[model] = nil
			continue
		end
		local reach = if mode == "Gamepad" then DonutHover.WalkUp elseif model == current then DonutHover.Reach else 0
		for _, prompt in promptsOf(entry) do
			if prompt.MaxActivationDistance ~= reach then
				prompt.MaxActivationDistance = reach
			end
		end
	end
	setOutline(if mode ~= "Gamepad" then current else nil)
end

function DonutHover.Init()
	for _, model in CollectionService:GetTagged("BaseDonut") do
		track(model)
	end
	CollectionService:GetInstanceAddedSignal("BaseDonut"):Connect(track)
	CollectionService:GetInstanceRemovedSignal("BaseDonut"):Connect(function(model)
		donuts[model :: Model] = nil
	end)
	-- (keep the donut you're holding a button on, even if it walks out from under the pointer)
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt: ProximityPrompt)
		held = prompt
		heldSince = os.clock()
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt: ProximityPrompt)
		if held == prompt then
			held = nil
			currentSince = os.clock()
		end
	end)
	UserInputService.TouchTapInWorld:Connect(function(position: Vector2, processed: boolean)
		if processed then
			return
		end
		local tapped = donutAt(position)
		DonutHover.Select(tapped)
		tappedUntil = if tapped then os.clock() + DonutHover.TapHold else 0
	end)
	RunService.RenderStepped:Connect(DonutHover.Step)
end

return DonutHover
