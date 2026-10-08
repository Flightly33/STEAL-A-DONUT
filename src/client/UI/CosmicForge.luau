--[[
	CosmicForge: the Cosmic Forge's window (server/CraftService), opened by the prompt on the
	forge's altar by the spawn. Shows The Cosmic Donut turning (its black hole horizon spinning
	round it), how much it earns, your meteor shards (Data.MeteorShards) out of the
	Config.CosmicDonut.ShardCost it costs, and how to get more. CRAFT asks the server for
	"CraftCosmic"; when it's made, the window closes and you get a big celebration.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Donuts = require(Shared.Donuts)
local DonutModel = require(Shared.DonutModel)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)
local Modal = require(script.Parent.Modal)
local Notifications = require(script.Parent.Notifications)
local State = require(script.Parent.Parent.State)

local CosmicForge = {}

local rgb = Color3.fromRGB
local COSMIC = Config.CosmicDonut
local DONUT_ID = "cosmicdonut"
local VIOLET, CYAN, PINK = rgb(170, 90, 255), rgb(110, 230, 255), rgb(255, 130, 225)

type Spin = { Part: BasePart, Offset: CFrame, Axis: Vector3, Rate: number }

local modal: Modal.Modal
local shardsLabel: TextLabel
local fill: Frame
local craftButton: TextButton
local spinConnection: RBXScriptConnection? = nil
local previewModel: Model? = nil
local rings: { Spin } = {}
local others: { { Part: BasePart, Offset: CFrame } } = {}

local function shards(): number
	return State.Data.MeteorShards or 0
end

local function refresh()
	if not shardsLabel then
		return
	end
	local have, cost = shards(), COSMIC.ShardCost
	shardsLabel.Text = `Meteor Shards: <b>{have}/{cost}</b>`
	fill.Size = UDim2.fromScale(math.clamp(have / cost, 0, 1), 1)
	local text = craftButton:FindFirstChild("Text") :: TextLabel?
	if text then
		text.Text = if not COSMIC.Enabled then "FORGE CLOSED" elseif have >= cost then "CRAFT IT!" else `NEED {cost - have} MORE`
	end
end

-- The donut in the window: the whole thing turns slowly, its horizon spins round it fast.
local function buildPreview(viewport: ViewportFrame)
	local donut = Donuts.ById[DONUT_ID]
	if not donut then
		return
	end
	local model = DonutModel.Build(donut, { NoEffects = true })
	local root = model.PrimaryPart :: BasePart
	local origin = root.CFrame
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part ~= root then
			local offset = origin:ToObjectSpace(part.CFrame)
			local axis = part:GetAttribute("Axis")
			if part:GetAttribute("Limb") == "Horizon" and typeof(axis) == "Vector3" then
				local rate = part:GetAttribute("Spin")
				table.insert(rings, { Part = part, Offset = offset, Axis = axis, Rate = if type(rate) == "number" then rate else 1 })
			else
				table.insert(others, { Part = part, Offset = offset })
			end
		end
	end
	model.Parent = viewport
	previewModel = model
	local top = (model:GetAttribute("Top") :: number?) or 2.5
	local bottom = (model:GetAttribute("Bottom") :: number?) or 2.5
	local centerY = origin.Position.Y + (top - bottom) / 2
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(origin.Position + Vector3.new(2.5, centerY - origin.Position.Y + 2, -((top + bottom) * 1.6 + 7)), Vector3.new(origin.Position.X, centerY, origin.Position.Z))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

local function turnPreview()
	local model = previewModel
	local root = model and model.PrimaryPart
	if not root then
		return
	end
	local now = os.clock()
	local turned = CFrame.new(root.Position) * CFrame.Angles(0, now * 0.5, 0)
	root.CFrame = turned
	for _, item in others do
		item.Part.CFrame = turned * item.Offset
	end
	for _, ring in rings do
		ring.Part.CFrame = turned * CFrame.fromAxisAngle(ring.Axis, (now * ring.Rate) % (math.pi * 2)) * ring.Offset
	end
end

function CosmicForge.Open()
	refresh()
	modal:Open()
	if not spinConnection then
		spinConnection = RunService.RenderStepped:Connect(function()
			if not modal:IsOpen() then
				local connection = spinConnection
				spinConnection = nil
				if connection then
					connection:Disconnect()
				end
				return
			end
			turnPreview()
		end)
	end
end

function CosmicForge.Close()
	modal:Close()
end

function CosmicForge.IsOpen(): boolean
	return modal ~= nil and modal:IsOpen()
end

local function hookPrompt()
	local forge = workspace:WaitForChild("CosmicForge", 120)
	local altar = forge and forge:WaitForChild("Altar", 30)
	local prompt = altar and altar:WaitForChild("CosmicForgePrompt", 30)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(function(who: Player)
			if who == Players.LocalPlayer then
				CosmicForge.Open()
			end
		end)
	end
end

function CosmicForge.Init()
	modal = Modal.new("Cosmic Forge", rgb(110, 50, 200), Vector2.new(640, 430))
	local body = modal.Body
	-- the donut, in a little window into space
	local viewport = Theme.new("ViewportFrame", {
		Name = "Preview",
		BackgroundColor3 = rgb(14, 8, 32),
		Size = UDim2.new(0.42, 0, 1, 0),
		Ambient = rgb(190, 170, 230),
		LightColor = rgb(255, 245, 255),
		LightDirection = Vector3.new(-0.5, -1, 0.8),
		Parent = body,
	}, { Theme.Corner(14), Theme.Stroke(3, VIOLET), Theme.Gradient(rgb(40, 20, 80), rgb(8, 4, 20)) })
	buildPreview(viewport)
	Theme.Label({ Text = "LIMITED TIME", TextColor3 = PINK, Size = UDim2.new(1, -16, 0, 26), Position = UDim2.new(0, 8, 1, -34), StrokeThickness = 2, Parent = viewport })

	local right = Theme.new("Frame", { Name = "Info", BackgroundTransparency = 1, Position = UDim2.new(0.42, 14, 0, 0), Size = UDim2.new(0.58, -14, 1, 0), Parent = body })
	Theme.Label({ Text = "THE COSMIC DONUT", TextColor3 = rgb(225, 195, 255), Size = UDim2.new(1, 0, 0, 40), StrokeThickness = 3, Parent = right })
	local donut = Donuts.ById[DONUT_ID]
	local income = if donut then Economy.DonutIncome(donut.Id, 1, "None", "Normal") else 0
	Theme.Label({
		Text = `<font color="#{CYAN:ToHex()}">ICON • CRAFTED</font> <b>{Format.Money(income)}/s</b>`,
		Font = Theme.Font,
		RichText = true,
		TextColor3 = rgb(140, 255, 120),
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 42),
		StrokeThickness = 1.5,
		Parent = right,
	})
	Theme.Label({
		Text = "The best donut in the game! A black hole spins round it and space swirls inside it.",
		Font = Theme.Font,
		TextScaled = false,
		TextSize = 17,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 46),
		Position = UDim2.fromOffset(0, 74),
		StrokeThickness = 1.2,
		Parent = right,
	})
	shardsLabel = Theme.Label({ Text = "", Font = Theme.Font, RichText = true, TextColor3 = rgb(225, 195, 255), TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 128), StrokeThickness = 2, Parent = right })
	local bar = Theme.new("Frame", { Name = "Progress", BackgroundColor3 = rgb(30, 18, 55), Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 162), Parent = right }, { Theme.Corner(11), Theme.Stroke(2.5) })
	fill = Theme.new("Frame", { Name = "Fill", BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(0, 1), Parent = bar }, { Theme.Corner(11), Theme.Gradient(PINK, VIOLET) })
	Theme.Label({
		Text = "How to get shards: when the <b>Eternal Storm</b> comes, a meteor smashes into the lane 45 seconds in. Grab a shard from round its crater and run it back to the lobby. Get hit and you drop it!",
		Font = Theme.Font,
		RichText = true,
		TextScaled = false,
		TextSize = 16,
		TextWrapped = true,
		TextColor3 = rgb(200, 200, 225),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 88),
		Position = UDim2.fromOffset(0, 194),
		StrokeThickness = 1,
		Parent = right,
	})
	craftButton = Theme.Button({ Name = "Craft", Text = "CRAFT IT!", Color = VIOLET, Size = UDim2.new(1, 0, 0, 58), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Parent = right })
	craftButton.Activated:Connect(function()
		if shards() < COSMIC.ShardCost then
			Notifications.Toast(`You need {COSMIC.ShardCost - shards()} more meteor shards!`, "error")
			return
		end
		State.Action("CraftCosmic")
	end)

	State.Changed:Connect(refresh)
	refresh()
	Remotes.Event("CosmicCrafted").OnClientEvent:Connect(function()
		modal:Close()
		Notifications.Banner("THE COSMIC DONUT", VIOLET, 4, "You crafted it! It's in your base")
		Theme.PlaySound("Event")
	end)
	task.spawn(hookPrompt)
end

return CosmicForge
