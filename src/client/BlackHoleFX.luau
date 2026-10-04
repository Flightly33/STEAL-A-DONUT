--[[
	BlackHoleFX: brings the black holes (server/BlackHoleModel) to life on the client.
	  * the lens rings (the photon ring and the light bent round the shadow) turn to face your camera
	  * hot spots orbit in the disk, the inner ones faster
	  * the swirl of infalling sparks and dust turns (the sparks are locked to it, so they spiral in)
	  * the glow breathes
	  * the lab's containment rings spin and wobble, and its containment reading flickers
	  * in The Black Hole the colour grading throbs slowly, as if space itself were pulsing
	Only black holes the camera is near enough to see are animated.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local AreaTracker = require(script.Parent.AreaTracker)

local BlackHoleFX = {}

local AREA = 20 -- The Black Hole
local VIEW_DISTANCE = 2500
local LAB_DISTANCE = 300

type Spot = { Part: BasePart, Radius: number, Angle: number, Speed: number }
type Hole = {
	Center: Vector3,
	Disk: CFrame,
	Lens: BasePart?,
	Inflow: BasePart?,
	Spin: number,
	Spots: { Spot },
	Glow: PointLight?,
	GlowBase: number,
}
type Gyro = { Model: Model, Center: Vector3, Tilt: CFrame, Spin: number, Precess: number }

local function track<T>(tag: string, onAdd: (Instance) -> T?): { [Instance]: T }
	local set: { [Instance]: T } = {}
	local function add(instance: Instance)
		local value = onAdd(instance)
		if value ~= nil and instance.Parent then
			set[instance] = value
		end
	end
	for _, instance in CollectionService:GetTagged(tag) do
		task.spawn(add, instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		set[instance] = nil
	end)
	return set
end

local function number(instance: Instance, name: string): number
	local value = instance:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

-- A frame at `center` whose -Z looks at `target`, with Y as close to `up` as it can be.
local function facing(center: Vector3, target: Vector3, up: Vector3): CFrame
	local look = target - center
	if look.Magnitude < 0.01 then
		return CFrame.new(center)
	end
	local back = -look.Unit
	local right = up:Cross(back)
	if right.Magnitude < 0.01 then
		right = Vector3.zAxis:Cross(back)
	end
	right = right.Unit
	return CFrame.fromMatrix(center, right, back:Cross(right), back)
end

local function addHole(instance: Instance): Hole?
	if not instance:IsA("Model") then
		return nil
	end
	local core = instance:WaitForChild("Core", 10)
	local frame = instance:WaitForChild("DiskFrame", 10)
	if not (core and core:IsA("BasePart") and frame and frame:IsA("BasePart")) then
		return nil
	end
	local lens = instance:FindFirstChild("Lens")
	local inflow = instance:FindFirstChild("Inflow")
	local glow = core:FindFirstChild("Glow")
	local spots: { Spot } = {}
	for _, child in instance:GetChildren() do
		if child:IsA("BasePart") and child.Name == "HotSpot" then
			table.insert(spots, { Part = child, Radius = number(child, "Radius"), Angle = number(child, "Angle"), Speed = number(child, "Speed") })
		end
	end
	return {
		Center = core.Position,
		Disk = frame.CFrame,
		Lens = if lens and lens:IsA("BasePart") then lens else nil,
		Inflow = if inflow and inflow:IsA("BasePart") then inflow else nil,
		Spin = if inflow then number(inflow, "Spin") else 0,
		Spots = spots,
		Glow = if glow and glow:IsA("PointLight") then glow else nil,
		GlowBase = if glow and glow:IsA("PointLight") then glow.Brightness else 0,
	}
end

local function addGyro(instance: Instance): Gyro?
	if not instance:IsA("Model") then
		return nil
	end
	local hub = instance.PrimaryPart or instance:WaitForChild("Hub", 10)
	if not hub or not hub:IsA("BasePart") then
		return nil
	end
	instance.PrimaryPart = hub
	local pivot = hub.CFrame
	return { Model = instance, Center = pivot.Position, Tilt = pivot - pivot.Position, Spin = number(instance, "Spin"), Precess = number(instance, "Precess") }
end

function BlackHoleFX.Init()
	local holes: { [Instance]: Hole } = track("BlackHole", addHole)
	local gyros: { [Instance]: Gyro } = track("GyroRing", addGyro)
	local readouts: { [Instance]: TextLabel } = track("LabReadout", function(instance): TextLabel?
		return if instance:IsA("TextLabel") then instance else nil
	end)

	-- Space throbbing in The Black Hole (fades in and out as you arrive and leave)
	local pulse = Instance.new("ColorCorrectionEffect")
	pulse.Name = "GravityPulse"
	pulse.Enabled = false
	pulse.Parent = Lighting
	local strength = 0

	local nextReading = 0
	RunService.RenderStepped:Connect(function(dt: number)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local cam = camera.CFrame.Position
		local t = os.clock()

		for model, hole in holes do
			if not model.Parent then
				holes[model] = nil
				continue
			end
			if (hole.Center - cam).Magnitude > VIEW_DISTANCE then
				continue
			end
			if hole.Lens then
				hole.Lens.CFrame = facing(hole.Center, cam, hole.Disk.UpVector)
			end
			for _, spot in hole.Spots do
				spot.Part.CFrame = hole.Disk * CFrame.Angles(0, spot.Angle + t * spot.Speed, 0) * CFrame.new(spot.Radius, 0, 0)
			end
			if hole.Inflow then
				hole.Inflow.CFrame = hole.Disk * CFrame.Angles(0, t * hole.Spin, 0)
			end
			if hole.Glow then
				hole.Glow.Brightness = hole.GlowBase * (1 + 0.18 * math.sin(t * 1.7))
			end
		end

		-- The lab (under the floor): containment rings and the flickering reading
		for model, gyro in gyros do
			if not model.Parent then
				gyros[model] = nil
			elseif cam.Y < gyro.Center.Y + 40 and (gyro.Center - cam).Magnitude < LAB_DISTANCE then
				gyro.Model:PivotTo(CFrame.new(gyro.Center) * CFrame.Angles(0, t * gyro.Precess, 0) * gyro.Tilt * CFrame.Angles(0, t * gyro.Spin, 0))
			end
		end
		if t >= nextReading then
			nextReading = t + 0.4
			for label in readouts do
				local text = label :: TextLabel
				local reading = 96 + math.random() * 3.9
				text.Text = string.format("CONTAINMENT FIELD: %.1f%%", reading)
				text.TextColor3 = if reading < 97 then Color3.fromRGB(255, 210, 0) else Color3.fromRGB(80, 255, 170)
			end
		end

		local target = if AreaTracker.Current == AREA then 1 else 0
		strength += (target - strength) * math.min(1, dt * 1.5)
		pulse.Enabled = strength > 0.01
		if pulse.Enabled then
			local wave = math.sin(t * 1.1)
			pulse.Contrast = strength * (0.05 + 0.05 * wave)
			pulse.Saturation = strength * 0.06 * math.sin(t * 1.1 + 1)
			pulse.TintColor = Color3.new(1, 1 - strength * 0.03 * (1 + wave), 1)
		end
	end)
end

return BlackHoleFX
