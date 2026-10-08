--[[
	Flight and noclip (admin panel): the server sets your "FlyMode" attribute to "Fly" or "Carpet"; this flies.

	  Move with the normal controls (WASD / thumbstick); the way you face follows the camera.
	  Space / the button = up, Shift or Ctrl / the button = down. Looking up or down while moving
	  forward also climbs or dives.
	  "Carpet" puts a magic carpet (with tassels and sparkles) under your feet.
	Speed: your walk speed x Config.Admin.FlySpeed (at least 60).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Theme = require(script.Parent.UI.Theme)

local Flight = {}

local player = Players.LocalPlayer :: Player
local rgb = Color3.fromRGB

type Rig = { Velocity: LinearVelocity, Align: AlignOrientation, Attachment: Attachment, Carpet: Model?, Humanoid: Humanoid }
local rig: Rig? = nil
local vertical = 0 -- -1 down, 0, 1 up (keys / buttons)
local buttons: Frame? = nil

local function buildCarpet(root: BasePart): Model
	local model = Instance.new("Model")
	model.Name = "MagicCarpet"
	local function piece(size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Size = size
		p.CFrame = root.CFrame * offset
		p.Color = color
		p.Material = material or Enum.Material.Fabric
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
		p.Parent = model
		return p
	end
	local base = CFrame.new(0, -3.1, 0)
	local rug = piece(Vector3.new(6, 0.25, 8), base, rgb(170, 30, 60))
	piece(Vector3.new(5, 0.27, 7), base, rgb(230, 170, 40))
	piece(Vector3.new(4, 0.29, 6), base, rgb(120, 20, 90))
	for _, z in { -4.2, 4.2 } do
		for x = -2.5, 2.5, 1 do
			piece(Vector3.new(0.25, 0.25, 0.6), base * CFrame.new(x, 0, z), rgb(255, 215, 80))
		end
	end
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = rgb(255, 220, 120)
	sparkles.Parent = rug
	model.Parent = root.Parent
	return model
end

local function stop()
	if rig then
		rig.Velocity:Destroy()
		rig.Align:Destroy()
		rig.Attachment:Destroy()
		if rig.Carpet then
			rig.Carpet:Destroy()
		end
		rig.Humanoid.PlatformStand = false
		rig = nil
	end
	if buttons then
		buttons.Visible = false
	end
end

local function start(mode: string)
	stop()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "FlightAttachment"
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = math.huge
	velocity.VectorVelocity = Vector3.zero
	velocity.Parent = root
	local align = Instance.new("AlignOrientation")
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxTorque = math.huge
	align.Responsiveness = 30
	align.CFrame = root.CFrame.Rotation
	align.Parent = root
	humanoid.PlatformStand = true
	rig = {
		Velocity = velocity,
		Align = align,
		Attachment = attachment,
		Carpet = if mode == "Carpet" then buildCarpet(root) else nil,
		Humanoid = humanoid,
	}
	if buttons then
		buttons.Visible = UserInputService.TouchEnabled
	end
end

local function apply()
	local mode = player:GetAttribute("FlyMode")
	if mode == "Fly" or mode == "Carpet" then
		start(mode)
	else
		stop()
	end
end

-- / buttons for phones and tablets
local function buildButtons()
	local gui = Theme.ScreenGui("FlightButtons", 5)
	local frame = Theme.new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -170, 1, -150), Size = UDim2.fromOffset(70, 150), BackgroundTransparency = 1, Visible = false, Parent = gui })
	Theme.AutoScale(frame)
	type Info = { Text: string, Direction: number }
	local infos: { Info } = { { Text = "UP", Direction = 1 }, { Text = "DOWN", Direction = -1 } }
	for i, info in infos do
		local button = Theme.Button({ Text = info.Text, Color = Theme.Colors.Blue, Size = UDim2.fromOffset(66, 66), Position = UDim2.fromOffset(0, (i - 1) * 76), Parent = frame })
		button.MouseButton1Down:Connect(function()
			vertical = info.Direction
		end)
		button.MouseButton1Up:Connect(function()
			vertical = 0
		end)
		button.MouseLeave:Connect(function()
			vertical = 0
		end)
	end
	buttons = frame
end

function Flight.Init()
	-- Noclip (admin panel): walk through walls while the "Noclip" attribute is on.
	local noclipParts: { [BasePart]: boolean } = {}
	RunService.Stepped:Connect(function()
		local character = player.Character
		if player:GetAttribute("Noclip") and character then
			for _, part in character:GetDescendants() do
				if part:IsA("BasePart") and part.CanCollide then
					noclipParts[part] = true
					part.CanCollide = false
				end
			end
		elseif next(noclipParts) then
			for part in noclipParts do
				if part.Parent then
					part.CanCollide = true
				end
			end
			table.clear(noclipParts)
		end
	end)
	buildButtons()
	player:GetAttributeChangedSignal("FlyMode"):Connect(apply)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		apply()
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space then
			vertical = 1
		elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.LeftControl then
			vertical = -1
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.LeftControl then
			vertical = 0
		end
	end)
	RunService.RenderStepped:Connect(function()
		local current = rig
		if not current then
			return
		end
		if not current.Humanoid.Parent or current.Humanoid.Health <= 0 then
			stop()
			return
		end
		local camera = workspace.CurrentCamera
		local look = if camera then camera.CFrame.LookVector else Vector3.new(0, 0, -1)
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 then
			current.Align.CFrame = CFrame.lookAt(Vector3.zero, flat.Unit)
		end
		local walk = player:GetAttribute("WalkSpeed")
		local speed = math.max(60, (if type(walk) == "number" then walk else 16) * Config.Admin.FlySpeed)
		local move = current.Humanoid.MoveDirection
		-- Moving towards where the camera looks also climbs / dives with it
		local forward = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zero
		local climb = if move.Magnitude > 0.1 then move:Dot(forward) * look.Y else 0
		current.Velocity.VectorVelocity = (move + Vector3.new(0, vertical + climb, 0)) * speed
		current.Humanoid.PlatformStand = true
	end)
	task.defer(apply)
end

return Flight
