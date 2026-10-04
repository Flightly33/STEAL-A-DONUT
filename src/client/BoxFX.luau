--[[
	BoxFX: donut boxes on the client.
	  * Boxes in the biomes ("LaneBox"): a gentle bob and turn so they catch the eye (only the ones
	    near you move).
	  * Boxes in pens ("PenBox"): the time left counts down on the label over each one, worked out
	    here from its HatchAt attribute so the server doesn't send anything every second. Once it's
	    ready the box hops and wiggles, the label flashes CLICK TO OPEN!, and its owner clicks (or
	    taps) it, or presses E, to open it. Only the owner sees the prompts ("Open now" for Robux
	    while it waits, "Open!" once it's ready) and can click it.
	  * Opening (remote "BoxOpened"): the lid flips off, the box spins faster and faster, a white
	    flash - and the donut pops out, then drops into its owner's inventory (flies to them).
	  * The pill at the top: the Box Rush (every Config.Boxes.Rush.Interval seconds every box in
	    every pen opens Rush.Speed times faster for Rush.Duration seconds), and in a biome the time
	    until every box is replaced with a fresh one. "ALL BOXES RESET!" when that happens.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Boxes = require(Shared.Boxes)
local Donuts = require(Shared.Donuts)
local DonutModel = require(Shared.DonutModel)
local Rarities = require(Shared.Rarities)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.UI.Theme)
local Notifications = require(script.Parent.UI.Notifications)
local AreaTracker = require(script.Parent.AreaTracker)

local BoxFX = {}

local player = Players.LocalPlayer :: Player

local BOB_RANGE = 180 -- biome boxes further away than this don't bob
local LID_PARTS = { Lid = true, Bow = true, BowKnot = true, LidEdge = true }

type Bobbing = { Model: Model, Parts: { BasePart }, Offsets: { CFrame }, Pivot: CFrame, Phase: number }

type PenBox = {
	Model: Model,
	Timer: TextLabel,
	Mine: boolean,
	Skip: ProximityPrompt?,
	Open: ProximityPrompt?,
	Parts: { BasePart },
	Offsets: { CFrame },
	Pivot: CFrame,
	Phase: number,
}

local bobbing: { [Model]: Bobbing } = {}
local bulkMove = true -- (workspace:BulkMoveTo, if this client has it)
local penBoxes: { [Model]: PenBox } = {}
local READY_GOLD = Color3.fromRGB(255, 215, 70)
local WIGGLE_RANGE = 120 -- ready boxes further away than this don't wiggle

local function rushing(): boolean
	local endsAt = workspace:GetAttribute("BoxRushEndsAt")
	return type(endsAt) == "number" and endsAt > workspace:GetServerTimeNow()
end

--------------------------------------------------------------------------------
-- Biome boxes: bob and turn
--------------------------------------------------------------------------------
local function addLaneBox(model: Instance)
	if not model:IsA("Model") or bobbing[model] then
		return
	end
	local pivot = model:GetPivot()
	local parts, offsets = {}, {}
	for _, part in model:GetDescendants() do
		-- (the glowing ring stays on the ground)
		if part:IsA("BasePart") and part.Name ~= "GroundRing" then
			table.insert(parts, part)
			table.insert(offsets, pivot:ToObjectSpace(part.CFrame))
		end
	end
	bobbing[model] = { Model = model, Parts = parts, Offsets = offsets, Pivot = pivot, Phase = math.random() * math.pi * 2 }
end

local function moveParts(parts: { BasePart }, frames: { CFrame })
	if #parts == 0 then
		return
	end
	if bulkMove then
		local ok = pcall(function()
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end)
		bulkMove = ok
	end
	if not bulkMove then
		for i, part in parts do
			part.CFrame = frames[i]
		end
	end
end

local function updateBobbing(now: number, position: Vector3?, parts: { BasePart }, frames: { CFrame })
	for model, info in bobbing do
		if not model.Parent then
			bobbing[model] = nil
			continue
		end
		if not position or (info.Pivot.Position - position).Magnitude > BOB_RANGE then
			continue
		end
		local t = now + info.Phase
		local bob = info.Pivot * CFrame.new(0, 0.35 + math.sin(t * 2.2) * 0.3, 0) * CFrame.Angles(0, math.sin(t * 0.9) * 0.18, math.sin(t * 1.7) * 0.03)
		for i, part in info.Parts do
			table.insert(parts, part)
			table.insert(frames, bob * info.Offsets[i])
		end
	end
end

--------------------------------------------------------------------------------
-- Pen boxes: countdowns, then "CLICK TO OPEN!"
--------------------------------------------------------------------------------
local function setEnabled(prompt: ProximityPrompt?, on: boolean)
	if prompt and prompt.Enabled ~= on then
		prompt.Enabled = on
	end
end

local function addPenBox(model: Instance)
	if not model:IsA("Model") or penBoxes[model] then
		return
	end
	task.defer(function()
		-- (a box's parts and labels can arrive a moment after the box itself)
		local root = model:WaitForChild("Root", 10)
		local info = root and root:WaitForChild("BoxInfo", 10)
		local pill = info and info:WaitForChild("TimerPill", 10)
		local timer = pill and pill:WaitForChild("Timer", 10)
		if not root or not timer or not timer:IsA("TextLabel") or not model.Parent or penBoxes[model] then
			return
		end
		local skip = root:WaitForChild("SkipPrompt", 5)
		local open = root:WaitForChild("OpenPrompt", 5)
		local mine = model:GetAttribute("OwnerUserId") == player.UserId
		-- other players' boxes: no prompts and no clicking (the server checks too)
		local click = model:FindFirstChild("OpenClick")
		if click and click:IsA("ClickDetector") and not mine then
			click.MaxActivationDistance = 0
		end
		local pivot = model:GetPivot()
		local parts, offsets = {}, {}
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				table.insert(parts, part)
				table.insert(offsets, pivot:ToObjectSpace(part.CFrame))
			end
		end
		penBoxes[model] = {
			Model = model,
			Timer = timer,
			Mine = mine,
			Skip = if skip and skip:IsA("ProximityPrompt") then skip else nil,
			Open = if open and open:IsA("ProximityPrompt") then open else nil,
			Parts = parts,
			Offsets = offsets,
			Pivot = pivot,
			Phase = math.random() * 1.6,
		}
	end)
end

local function isReady(entry: PenBox, now: number): boolean
	local hatchAt = entry.Model:GetAttribute("HatchAt")
	return entry.Model:GetAttribute("Ready") == true or (type(hatchAt) == "number" and hatchAt - now <= 0.5)
end

local function updateTimers()
	local now = workspace:GetServerTimeNow()
	local rush = rushing()
	for model, entry in penBoxes do
		if not model.Parent then
			penBoxes[model] = nil
			continue
		end
		local ready = isReady(entry, now)
		setEnabled(entry.Skip, entry.Mine and not ready)
		setEnabled(entry.Open, entry.Mine and ready)
		local text, color
		if ready then
			text = if entry.Mine then "CLICK TO OPEN!" else "READY"
			-- (flashes between gold and white)
			color = if math.floor(os.clock() * 2.5) % 2 == 0 then READY_GOLD else Color3.new(1, 1, 1)
		else
			local hatchAt = model:GetAttribute("HatchAt") :: number
			text = `{Format.Duration(math.ceil(hatchAt - now))}{if rush then ` x{Config.Boxes.Rush.Speed}` else ""}`
			color = if rush then Color3.fromRGB(120, 230, 255) else Color3.new(1, 1, 1)
		end
		if entry.Timer.Text ~= text then
			entry.Timer.Text = text
		end
		if entry.Timer.TextColor3 ~= color then
			entry.Timer.TextColor3 = color
		end
	end
end

-- Your ready boxes hop and wiggle now and then, so you notice them.
local function updateWiggle(now: number, position: Vector3?, parts: { BasePart }, frames: { CFrame })
	if not position then
		return
	end
	local serverNow = workspace:GetServerTimeNow()
	for model, entry in penBoxes do
		if not entry.Mine or not model.Parent or not isReady(entry, serverNow) or (entry.Pivot.Position - position).Magnitude > WIGGLE_RANGE then
			continue
		end
		local t = (now + entry.Phase) % 1.6
		local cf = entry.Pivot
		if t < 0.5 then
			local k = t / 0.5
			cf = entry.Pivot * CFrame.new(0, math.sin(k * math.pi) * 0.8, 0) * CFrame.Angles(0, 0, math.sin(k * math.pi * 4) * 0.12 * (1 - k))
		end
		for i, part in entry.Parts do
			table.insert(parts, part)
			table.insert(frames, cf * entry.Offsets[i])
		end
	end
end

--------------------------------------------------------------------------------
-- Opening
--------------------------------------------------------------------------------
type Opened = { Owner: Player?, Slot: number, Box: Model?, DonutId: string, Mutation: string?, Size: string? }

local function hide(model: Model)
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") then
			child.Transparency = 1
		elseif child:IsA("LayerCollector") then
			child.Enabled = false
		elseif child:IsA("ParticleEmitter") then
			child.Enabled = false
		elseif child:IsA("Light") then
			child.Enabled = false
		elseif child:IsA("ProximityPrompt") then
			child.Enabled = false
		end
	end
end

local function screenFlash()
	local gui = Theme.ScreenGui("BoxFlash", 30)
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	local frame = Theme.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.35, BorderSizePixel = 0, Parent = gui })
	TweenService:Create(frame, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	task.delay(0.6, function()
		gui:Destroy()
	end)
end

-- The donut that came out: pops up over the box, then flies to its owner and is gone (it's in
-- their inventory now).
local function popDonut(info: Opened, at: CFrame, boxScale: number)
	local donut = Donuts.ById[info.DonutId]
	if not donut then
		return
	end
	local model = DonutModel.Build(donut, { Scale = 0.75 * math.sqrt(boxScale), Mutation = info.Mutation, Size = info.Size, Calm = true })
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	local rarity = Rarities.Get(donut.Rarity)
	local mutation = Rarities.Mutation(info.Mutation)
	local label = Theme.new("BillboardGui", { Size = UDim2.fromOffset(260, 56), StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 120 })
	Theme.Label({ Text = Rarities.DisplayName(donut.Name, info.Mutation, info.Size), TextColor3 = if mutation.Order > 0 then mutation.Color else rarity.Color, Size = UDim2.new(1, 0, 0.6, 0), StrokeThickness = 2.5, Parent = label })
	Theme.Label({ Text = string.upper(rarity.Id), Font = Theme.Font, TextColor3 = rarity.Color, Size = UDim2.new(1, 0, 0.4, 0), Position = UDim2.fromScale(0, 0.6), StrokeThickness = 2, Parent = label })
	label.Adornee = model.PrimaryPart
	label.Parent = model
	model.Parent = workspace

	local start = os.clock()
	local rise, hold, fly = 0.35, 0.75, 0.45
	local from = at.Position
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		local spin = CFrame.Angles(0, t * 4, 0)
		if t < rise + hold then
			local k = math.min(t / rise, 1)
			local up = 4 * boxScale * (1 - (1 - k) ^ 3) + math.sin(t * 5) * 0.15
			model:PivotTo(CFrame.new(from + Vector3.new(0, up, 0)) * spin)
		elseif t < rise + hold + fly then
			local k = (t - rise - hold) / fly
			local owner = info.Owner
			local root = owner and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local top = from + Vector3.new(0, 4 * boxScale, 0)
			local target = if root then root.Position else top
			-- an arc from over the box down into its owner
			local p = top:Lerp(target, k * k) + Vector3.new(0, math.sin(k * math.pi) * 3, 0)
			model:PivotTo(CFrame.new(p) * spin)
		else
			if connection then
				connection:Disconnect()
			end
			model:Destroy()
			if info.Owner == player then
				Theme.PlaySound("Collect")
			end
		end
	end)
end

local function onBoxOpened(info: Opened)
	local box = info.Box
	local root = box and box.Parent and box.PrimaryPart
	if not box or not root then
		return
	end
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local near = myRoot ~= nil and (myRoot.Position - root.Position).Magnitude < 160
	if not near and info.Owner ~= player then
		return -- (nobody to see it: skip the effect)
	end
	local tier = Boxes.Tier(box:GetAttribute("Tier") :: string?)
	local size = Boxes.Size(box:GetAttribute("BoxSize") :: string?)
	local mutation = Rarities.Mutation(box:GetAttribute("Mutation") :: string?)
	local glow = if mutation.Order > 0 then mutation.Color else tier.Color

	-- Play it on a copy (the server removes the real box in a moment)
	local copy = box:Clone()
	for _, child in copy:GetDescendants() do
		if child:IsA("BillboardGui") or child:IsA("ProximityPrompt") then
			child:Destroy()
		end
	end
	CollectionService:RemoveTag(copy, "PenBox")
	hide(box)
	copy.Parent = workspace
	local pivot = copy:GetPivot()
	local lidParts, bodyParts, lidOffsets, bodyOffsets = {}, {}, {}, {}
	for _, part in copy:GetDescendants() do
		if part:IsA("BasePart") then
			if LID_PARTS[part.Name] then
				table.insert(lidParts, part)
				table.insert(lidOffsets, pivot:ToObjectSpace(part.CFrame))
			else
				table.insert(bodyParts, part)
				table.insert(bodyOffsets, pivot:ToObjectSpace(part.CFrame))
			end
		end
	end
	local scale = size.Scale
	local top = (copy:GetAttribute("Top") :: number?) or 3
	Theme.PlaySound("Crack")

	local start = os.clock()
	local LID, SPIN = 0.4, 1.25
	local angle = 0
	local flashed = false
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function(dt: number)
		local t = os.clock() - start
		-- the lid flips up and off backwards, fading
		local lk = math.min(t / LID, 1)
		local lidFrame = pivot * CFrame.new(0, top * 0.8 * lk + 2 * scale * lk, 1.6 * scale * lk) * CFrame.Angles(-lk * math.rad(110), 0, 0)
		for i, part in lidParts do
			part.CFrame = lidFrame * lidOffsets[i]
			part.Transparency = math.max(part.Transparency, lk ^ 2)
		end
		-- the box spins faster and faster, lifting a little
		if t > LID * 0.5 then
			local sk = math.clamp((t - LID * 0.5) / SPIN, 0, 1)
			angle += dt * (3 + sk * sk * 30)
			local spin = pivot * CFrame.new(0, sk * 1.2 * scale, 0) * CFrame.Angles(0, angle, 0)
			for i, part in bodyParts do
				part.CFrame = spin * bodyOffsets[i]
			end
		end
		if not flashed and t >= LID * 0.5 + SPIN then
			flashed = true
			if connection then
				connection:Disconnect()
			end
			-- white flash
			local center = (pivot * CFrame.new(0, top * 0.5 + 1.2 * scale, 0)).Position
			copy:Destroy()
			local ball = Instance.new("Part")
			ball.Shape = Enum.PartType.Ball
			ball.Anchored = true
			ball.CanCollide = false
			ball.CanQuery = false
			ball.CanTouch = false
			ball.CastShadow = false
			ball.Material = Enum.Material.Neon
			ball.Color = Color3.new(1, 1, 1)
			ball.Size = Vector3.one * 2 * scale
			ball.CFrame = CFrame.new(center)
			local light = Instance.new("PointLight")
			light.Color = glow:Lerp(Color3.new(1, 1, 1), 0.5)
			light.Brightness = 6
			light.Range = 24 * math.sqrt(scale)
			light.Parent = ball
			ball.Parent = workspace
			TweenService:Create(ball, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * 12 * scale, Transparency = 1 }):Play()
			TweenService:Create(light, TweenInfo.new(0.45), { Brightness = 0 }):Play()
			task.delay(0.5, function()
				ball:Destroy()
			end)
			if info.Owner == player then
				screenFlash()
			end
			Theme.PlaySound(if tier.Order >= 3 or mutation.Order >= 3 then "Rare" else "Hatch")
			popDonut(info, CFrame.new(center), scale)
		end
	end)
end

--------------------------------------------------------------------------------
-- The pill at the top: Box Rush and the next reset
--------------------------------------------------------------------------------
local function buildPill(): (Frame, TextLabel)
	local gui = Theme.ScreenGui("BoxTimers", 2)
	local pill = Theme.new("Frame", {
		Name = "BoxPill",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 46),
		Size = UDim2.fromOffset(400, 34),
		BackgroundColor3 = Color3.fromRGB(40, 30, 60),
		BackgroundTransparency = 0.25,
		Visible = false,
		Parent = gui,
	}, {
		Theme.Corner(17),
		Theme.Stroke(2.5),
	})
	Theme.AutoScale(pill)
	local label = Theme.Label({ Text = "", Font = Theme.Font, Size = UDim2.new(1, -16, 1, -6), Position = UDim2.fromOffset(8, 3), StrokeThickness = 2, Parent = pill })
	return pill, label
end

local function updatePill(pill: Frame, label: TextLabel)
	local now = workspace:GetServerTimeNow()
	local rushEnds = workspace:GetAttribute("BoxRushEndsAt")
	local rushAt = workspace:GetAttribute("BoxRushAt")
	local reset = workspace:GetAttribute("BoxReset")
	local text, color = nil, Color3.new(1, 1, 1)
	if type(rushEnds) == "number" and rushEnds > now then
		text = `⏩ BOX RUSH! Pen boxes open {Config.Boxes.Rush.Speed}x faster • {math.ceil(rushEnds - now)}s`
		color = Color3.fromRGB(120, 230, 255)
	elseif type(rushAt) == "number" and rushAt - now <= 10 and rushAt > now then
		text = `⏩ Box Rush in {math.ceil(rushAt - now)}s!`
		color = Color3.fromRGB(120, 230, 255)
	elseif AreaTracker.Current > 0 and type(reset) == "number" and reset > now then
		text = `📦 New boxes in {Format.Duration(math.ceil(reset - now))}`
		color = Color3.fromRGB(255, 220, 120)
	end
	pill.Visible = text ~= nil
	if text and label.Text ~= text then
		label.Text = text
		label.TextColor3 = color
	end
end

function BoxFX.Init()
	for _, model in CollectionService:GetTagged("LaneBox") do
		addLaneBox(model)
	end
	CollectionService:GetInstanceAddedSignal("LaneBox"):Connect(addLaneBox)
	CollectionService:GetInstanceRemovedSignal("LaneBox"):Connect(function(model)
		bobbing[model :: Model] = nil
	end)
	for _, model in CollectionService:GetTagged("PenBox") do
		addPenBox(model)
	end
	CollectionService:GetInstanceAddedSignal("PenBox"):Connect(addPenBox)

	Remotes.Event("BoxOpened").OnClientEvent:Connect(onBoxOpened)
	Remotes.Event("BoxesReset").OnClientEvent:Connect(function()
		if AreaTracker.Current > 0 then
			Notifications.Banner("📦 ALL BOXES RESET!", Color3.fromRGB(255, 200, 90), 2, "Fresh boxes next to every Domer")
		end
	end)

	local pill, label = buildPill()
	local nextBob = 0
	local nextTick = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now >= nextBob then
			nextBob = now + 1 / 30
			local position = AreaTracker.Position()
			local parts, frames = {}, {}
			updateBobbing(now, position, parts, frames)
			updateWiggle(now, position, parts, frames)
			moveParts(parts, frames)
		end
		if now >= nextTick then
			nextTick = now + 0.25
			updateTimers()
			updatePill(pill, label)
		end
	end)
end

return BoxFX
