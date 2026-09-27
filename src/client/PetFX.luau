--[[
	PetFX: animates pet eggs on this client (see PetModel.BuildEgg):
	  * eggs wobble (more and more as they get close to hatching), ready ones bounce
	  * rune rings orbit, light rays turn
	  * rainbow eggs cycle colours
	  * incubator eggs show a live countdown ("4m 12s" -> "READY! Open Pets 🐾")
	Only eggs near the camera are animated.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Format = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Format"))

local PetFX = {}

local RANGE = 160

type Spinner = { Weld: Weld, Base: CFrame, Speed: number, AxisZ: boolean }
type Egg = {
	Model: Model,
	Root: BasePart,
	Base: CFrame,
	Phase: number,
	Spinners: { Spinner },
	Rainbow: { BasePart },
	Countdown: TextLabel?,
}

local eggs: { [Instance]: Egg } = {}

local function register(instance: Instance)
	if not instance:IsA("Model") or eggs[instance] then
		return
	end
	local root = instance.PrimaryPart or instance:WaitForChild("Root", 5)
	if not root or not root:IsA("BasePart") then
		return
	end
	local spinners: { Spinner } = {}
	local rainbow: { BasePart } = {}
	for _, part in instance:GetDescendants() do
		if part:IsA("BasePart") then
			local speed = part:GetAttribute("Spin")
			local weld = part:FindFirstChildOfClass("Weld")
			if type(speed) == "number" and weld then
				table.insert(spinners, { Weld = weld, Base = weld.C0, Speed = speed, AxisZ = part.Name == "Rays" })
			end
			if instance:GetAttribute("Rainbow") and (part.Name == "Crack" or part.Name == "Spot" or part.Name == "Rune") then
				table.insert(rainbow, part)
			end
		end
	end
	local timer = root:FindFirstChild("EggTimer")
	local countdown = timer and timer:FindFirstChild("Countdown")
	eggs[instance] = {
		Model = instance,
		Root = root,
		Base = root.CFrame,
		Phase = math.random() * 6,
		Spinners = spinners,
		Rainbow = rainbow,
		Countdown = if countdown and countdown:IsA("TextLabel") then countdown else nil,
	}
end

function PetFX.Init()
	for _, instance in CollectionService:GetTagged("PetEgg") do
		task.spawn(register, instance)
	end
	CollectionService:GetInstanceAddedSignal("PetEgg"):Connect(function(instance)
		task.wait() -- let its children (the countdown label) arrive
		register(instance)
	end)
	CollectionService:GetInstanceRemovedSignal("PetEgg"):Connect(function(instance)
		eggs[instance] = nil
	end)

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local now = workspace:GetServerTimeNow()
		local camera = workspace.CurrentCamera
		local cam = if camera then camera.CFrame.Position else Vector3.zero
		for instance, egg in eggs do
			if not instance.Parent then
				eggs[instance] = nil
				continue
			end
			if (egg.Root.Position - cam).Magnitude > RANGE then
				continue
			end
			local hatchAt = instance:GetAttribute("HatchAt")
			local left = if type(hatchAt) == "number" then hatchAt - now else nil
			if egg.Root.Anchored then
				-- Wobble: gentle normally, frantic in the last minute, bouncing when ready
				local strength = 0.08
				local speed = 2.2
				local lift = math.sin(t * 1.6 + egg.Phase) * 0.15
				if left and left <= 0 then
					strength, speed = 0.18, 9
					lift = math.abs(math.sin(t * 5 + egg.Phase)) * 0.6
				elseif left and left < 60 then
					strength, speed = 0.14, 7
				end
				egg.Root.CFrame = egg.Base * CFrame.new(0, lift, 0) * CFrame.Angles(math.sin(t * speed + egg.Phase) * strength, t * 0.3, math.cos(t * speed * 0.8 + egg.Phase) * strength)
			end
			for _, spinner in egg.Spinners do
				local angle = t * spinner.Speed
				spinner.Weld.C0 = spinner.Base * (if spinner.AxisZ then CFrame.Angles(0, 0, angle) else CFrame.Angles(0, angle, 0))
			end
			if #egg.Rainbow > 0 then
				for i, part in egg.Rainbow do
					part.Color = Color3.fromHSV((t * 0.3 + i * 0.08) % 1, 0.8, 1)
				end
			end
			if egg.Countdown and left then
				if left <= 0 then
					egg.Countdown.Text = "READY! Open Pets 🐾"
					egg.Countdown.TextColor3 = Color3.fromRGB(120, 255, 130)
				else
					egg.Countdown.Text = "⏳ " .. Format.Duration(left)
					egg.Countdown.TextColor3 = Color3.fromRGB(255, 255, 255)
				end
			end
		end
	end)
end

return PetFX
