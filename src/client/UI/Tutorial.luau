--[[
	Tutorial: a guided first game. A line of big outlined text at the top of the screen (on a dark
	band that fades out at its ends) says what to do next, with a Skip Tutorial button beside it, and a red arrow floating over your head points the
	way (a second red arrow bobs over the target):
	  1. follow the arrow to the first biome
	  2. steal a donut box (walk up to one next to Domer and press E)
	  3. run back to the lobby before Domer catches you (caught? steal another one)
	  4. go into your pen, hold the box and click to put it down
	  5. wait for its timer, then click it to open it (the donut lands in your inventory)
	  6. hold the donut and click in your pen: it walks around and makes money
	  7. run on your treadmill to get faster
	Then a Claim button gives you a free egg (once ever; the server checks).
	It starts on your first join and keeps coming back until you finish or skip it; Settings >
	How to play starts it again.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Layout = require(Shared.Layout)
local Remotes = require(Shared.Remotes)
local Theme = require(script.Parent.Theme)
local UpdateNotes = require(script.Parent.UpdateNotes)
local State = require(script.Parent.Parent.State)
local AreaTracker = require(script.Parent.Parent.AreaTracker)
local Bases = require(script.Parent.Parent.Bases)

local Tutorial = {}

local player = Players.LocalPlayer :: Player
local RED = Color3.fromRGB(235, 40, 40)
local STEPS = { "Lane", "Steal", "RunHome", "PlaceBox", "Wait", "PlaceDonut", "Treadmill" }
local TREADMILL_GOAL = 3 -- Speed to gain on the treadmill to finish
local TEXT: { [string]: string } = {
	Lane = "Follow the red arrow to the first biome",
	Steal = `Walk up to a donut box next to {Config.Guard.Name} and press E to steal it`,
	RunHome = `Run back to the lobby before {Config.Guard.Name} catches you!`,
	Caught = `{Config.Guard.Name} caught you! Steal another box and try again`,
	PlaceBox = "Go into your pen, hold the box and click to put it down",
	Wait = "Wait for the timer over your box, then click the box to open it!",
	PlaceDonut = "Your donut is in your inventory! Hold it and click in your pen",
	Treadmill = "Your donut makes money! Now run on your treadmill!",
	Done = "Tutorial complete! Claim your free egg",
	Claimed = "Tutorial complete!",
}

local step: string? = nil -- nil while the tutorial isn't running
local caught = false
local boxesAtStart = 0
local donutsAtStart = 0
local speedAtStart = 0
local refresh: () -> ()

local function number(name: string): number
	local value = player:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

-- Speed gained on the treadmill since the Treadmill step began (0 to TREADMILL_GOAL).
local function treadmillGained(): number
	return math.clamp(math.floor(number("Speed") - speedAtStart), 0, TREADMILL_GOAL)
end

local function go(nextStep: string?)
	step = nextStep
	if nextStep == "PlaceBox" then
		boxesAtStart = number("BoxesPlaced")
	elseif nextStep == "PlaceDonut" then
		donutsAtStart = number("DonutsPlaced")
	elseif nextStep == "Treadmill" then
		speedAtStart = number("Speed")
	end
	refresh()
end

function Tutorial.Start()
	caught = false
	go("Lane")
end
Tutorial.Open = Tutorial.Start -- Settings > How to play

function Tutorial.IsRunning(): boolean
	return step ~= nil
end

--------------------------------------------------------------------------------
-- The red arrows: one over your head pointing the way, one bobbing over the target
--------------------------------------------------------------------------------
type Arrow = { Parts: { BasePart }, Offsets: { CFrame } }

local function newArrow(parent: Instance, scale: number): Arrow
	local arrow: Arrow = { Parts = {}, Offsets = {} }
	local function piece(size: Vector3, offset: CFrame)
		local part = Instance.new("Part")
		part.Name = "TutorialArrow"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = RED
		part.Size = size * scale
		part.Parent = parent
		table.insert(arrow.Parts, part)
		table.insert(arrow.Offsets, CFrame.new(offset.Position * scale) * offset.Rotation)
	end
	-- points along -Z: a shaft and a chevron at the tip
	piece(Vector3.new(0.7, 0.7, 5), CFrame.new(0, 0, 0.5))
	for _, side in { -1, 1 } do
		piece(Vector3.new(0.7, 0.7, 2.8), CFrame.new(side * 0.9, 0, -2.13) * CFrame.Angles(0, side * math.rad(40), 0))
	end
	return arrow
end

local function place(arrow: Arrow, cf: CFrame?)
	for i, part in arrow.Parts do
		if cf then
			part.CFrame = cf * arrow.Offsets[i]
			part.Transparency = 0
		else
			part.Transparency = 1
		end
	end
end

-- Where the arrows should point for the current step.
local nearestBox: Vector3? = nil
local lastScan = 0
local function laneStart(): Vector3
	return Vector3.new(0, 0, Layout.AreaStart(1) + 15)
end

-- The nearest box you can steal in the biome you're in.
local function findBox(from: Vector3): Vector3?
	local area = AreaTracker.Current
	local map = workspace:FindFirstChild("Map")
	local lane = map and map:FindFirstChild("Lane")
	local folder = lane and lane:FindFirstChild("Area" .. area)
	if area <= 0 or not folder then
		return nil
	end
	local best, bestDistance = nil, math.huge
	for _, prompt in folder:GetDescendants() do
		if prompt:IsA("ProximityPrompt") and prompt.Name == "StealPrompt" and prompt.Enabled then
			local holder = prompt.Parent
			if holder and holder:IsA("BasePart") then
				local distance = (holder.Position - from).Magnitude
				if distance < bestDistance then
					best, bestDistance = holder.Position, distance
				end
			end
		end
	end
	return best
end

local function target(from: Vector3): Vector3?
	local plot = Bases.Mine()
	if step == "Lane" then
		return laneStart()
	elseif step == "Steal" then
		local now = os.clock()
		if now - lastScan > 0.75 then
			lastScan = now
			nearestBox = findBox(from)
		end
		return nearestBox or laneStart()
	elseif step == "RunHome" then
		return Vector3.new(from.X, 0, Config.Map.SafeZoneZ - 30)
	elseif (step == "PlaceBox" or step == "PlaceDonut") and plot then
		return plot:GetPivot().Position
	elseif step == "Wait" and plot then
		for _, child in plot:GetChildren() do
			if child:IsA("Model") and string.sub(child.Name, 1, 6) == "PenBox" then
				return child:GetPivot().Position
			end
		end
		return plot:GetPivot().Position
	elseif step == "Treadmill" and plot then
		local treadmill = plot:FindFirstChild("Treadmill")
		local belt = treadmill and treadmill:FindFirstChild("Belt")
		return if belt and belt:IsA("BasePart") then belt.Position else plot:GetPivot().Position
	end
	return nil
end

--------------------------------------------------------------------------------
-- Init
--------------------------------------------------------------------------------
function Tutorial.Init()
	-- The line of text at the top, with Skip / Claim beside it
	local gui = Theme.ScreenGui("Tutorial", 6)
	local strip = Theme.Band({
		Name = "Strip",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 48),
		Size = UDim2.fromOffset(0, 54),
		AutomaticSize = Enum.AutomaticSize.X,
		Darkness = 0.6,
		Visible = false,
		Parent = gui,
	})
	Theme.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = strip })
	Theme.new("UIPadding", { PaddingLeft = UDim.new(0, 90), PaddingRight = UDim.new(0, 90), Parent = strip })
	Theme.AutoScale(strip)
	local counter = Theme.Label({ Name = "Counter", Text = "", Font = Theme.Font, TextScaled = false, TextSize = 24, TextColor3 = Color3.fromRGB(255, 120, 120), AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 40), StrokeThickness = 2.5, LayoutOrder = 1, Parent = strip })
	local label = Theme.Label({ Name = "Text", Text = "", Font = Theme.Font, TextScaled = false, TextSize = 30, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 40), StrokeThickness = 3, LayoutOrder = 2, Parent = strip })
	local skip = Theme.Button({ Text = "Skip Tutorial", Color = Theme.Colors.Gray, Size = UDim2.fromOffset(130, 34), Parent = strip })
	skip.Name = "Skip"
	skip.LayoutOrder = 3
	local claim = Theme.Button({ Text = "Claim", Color = Theme.Colors.Green, Size = UDim2.fromOffset(110, 34), Parent = strip })
	claim.Name = "Claim"
	claim.LayoutOrder = 4
	local close = Theme.Button({ Text = "Close", Color = Theme.Colors.Gray, Size = UDim2.fromOffset(90, 34), Parent = strip })
	close.Name = "Close"
	close.LayoutOrder = 5

	local arrows = Instance.new("Folder")
	arrows.Name = "TutorialArrows"
	arrows.Parent = workspace
	local guide = newArrow(arrows, 1)
	local marker = newArrow(arrows, 1.4)
	place(guide, nil)
	place(marker, nil)

	refresh = function()
		strip.Visible = step ~= nil
		if not step then
			return
		end
		local index = table.find(STEPS, step)
		counter.Text = if index then `{index}/{#STEPS}` else ""
		counter.Visible = index ~= nil
		local claimed = State.Data.TutorialEggClaimed == true
		if step == "Done" then
			label.Text = if claimed then TEXT.Claimed else TEXT.Done
		elseif step == "Treadmill" then
			-- how far along you are, like "Run on your treadmill! 1/3 Speed"
			label.Text = `{TEXT.Treadmill} {treadmillGained()}/{TREADMILL_GOAL} Speed`
		else
			label.Text = if step == "Steal" and caught then TEXT.Caught else TEXT[step]
		end
		skip.Visible = step ~= "Done"
		claim.Visible = step == "Done" and not claimed
		close.Visible = step == "Done" and claimed
	end

	skip.Activated:Connect(function()
		State.Action("SeenTutorial")
		go(nil)
	end)
	claim.Activated:Connect(function()
		State.Action("ClaimTutorialEgg")
		label.Text = TEXT.Claimed
		claim.Visible = false
		task.delay(2.5, function()
			if step == "Done" then
				go(nil)
			end
		end)
	end)
	close.Activated:Connect(function()
		State.Action("SeenTutorial")
		go(nil)
	end)

	-- Stealing a box, getting caught and bringing it back
	Remotes.Event("ChaseEnded").OnClientEvent:Connect(function(info: any)
		if type(info) ~= "table" or info.Kind ~= "Box" then
			return
		end
		if step == "RunHome" or step == "Steal" then
			if info.Result == "Deposited" then
				go("PlaceBox")
			elseif info.Result == "Caught" or info.Result == "Lost" then
				caught = true
				go("Steal")
			end
		end
	end)
	-- Your box opened
	Remotes.Event("BoxOpened").OnClientEvent:Connect(function(info: any)
		if type(info) == "table" and info.Owner == player and (step == "Wait" or step == "PlaceBox") then
			go("PlaceDonut")
		end
	end)

	RunService.RenderStepped:Connect(function()
		if not step then
			place(guide, nil)
			place(marker, nil)
			return
		end
		-- move on when the step is done
		if step == "Lane" and AreaTracker.Current > 0 then
			go("Steal")
		elseif step == "Steal" and player:GetAttribute("CarryKind") == "Box" then
			caught = false
			go("RunHome")
		elseif step == "PlaceBox" and number("BoxesPlaced") > boxesAtStart then
			go("Wait")
		elseif step == "PlaceDonut" and number("DonutsPlaced") > donutsAtStart then
			go("Treadmill")
		elseif step == "Treadmill" then
			if number("Speed") >= speedAtStart + TREADMILL_GOAL then
				go("Done")
			elseif not string.find(label.Text, `{treadmillGained()}/{TREADMILL_GOAL}`, 1, true) then
				refresh() -- (the Speed count went up)
			end
		end
		-- point the way
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local goal = if root and step ~= "Done" then target(root.Position) else nil
		if not root or not goal then
			place(guide, nil)
			place(marker, nil)
			return
		end
		local t = os.clock()
		local bob = math.sin(t * 3) * 0.4
		local here = root.Position + Vector3.new(0, 6.5 + bob, 0)
		local flat = Vector3.new(goal.X - here.X, 0, goal.Z - here.Z)
		if flat.Magnitude > 4 then
			local ahead = flat.Unit
			local right = Vector3.yAxis:Cross(-ahead)
			place(guide, CFrame.fromMatrix(here, right, Vector3.yAxis, -ahead))
		else
			place(guide, nil)
		end
		-- pointing straight down over the target, turning slowly
		local over = goal + Vector3.new(0, 10 + math.sin(t * 2.5) * 1.2, 0)
		place(marker, CFrame.fromMatrix(over, Vector3.xAxis, Vector3.new(0, 0, -1), Vector3.yAxis) * CFrame.Angles(0, 0, t * 1.5))
	end)

	-- First join: start it (it keeps coming back until finished or skipped)
	local checked = false
	State.Changed:Connect(function(snapshot)
		if not checked then
			checked = true
			if snapshot.SeenTutorial == false then
				-- after the Update Log that opens on joining has been closed
				UpdateNotes.AfterJoinLog(function()
					if not Tutorial.IsRunning() then
						Tutorial.Start()
					end
				end)
			end
		elseif step == "Done" then
			refresh() -- the claim went through
		end
	end)
	refresh()
end

return Tutorial
