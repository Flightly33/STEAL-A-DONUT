--[[
	FreeCam (admins only, for filming trailers): detaches the camera from your character and lets you
	fly it anywhere. On this player's screen only; nothing changes for anyone else.

	  F6 (or the Free Cam button in the admin panel) turns it on and off. The UI clears while it's on
	  and comes back as it was.
	  W A S D        move             E / Space  up        Q  down
	  Right mouse    look (hold)      Shift  faster        Ctrl  slower
	  Mouse wheel    change the base speed
	  R / F          zoom in / out (field of view)         Z / C  tilt left / right
	  T              reset the tilt and the zoom

	Movement and looking are smoothed so the shots glide. Your character stands still (the normal
	controls are off), so turn on "can't catch me" in the admin panel first if a Domer is around.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Theme = require(script.Parent.UI.Theme)
local HideUI = require(script.Parent.UI.HideUI)

local FreeCam = {}

local player = Players.LocalPlayer :: Player

local TOGGLE_KEY = Enum.KeyCode.F6
local START_SPEED = 40 -- studs a second
local MIN_SPEED, MAX_SPEED = 2, 800
local FAST, SLOW = 4, 0.25
local LOOK_SPEED = 0.25 -- degrees per mouse pixel
local MOVE_SMOOTH, LOOK_SMOOTH = 8, 16
local MIN_FOV, MAX_FOV = 5, 120
local FOV_RATE = 40 -- degrees a second
local ROLL_RATE = 40
local HINT_SECONDS = 7

local SINK_KEYS = {
	Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Q, Enum.KeyCode.E,
	Enum.KeyCode.R, Enum.KeyCode.F, Enum.KeyCode.Z, Enum.KeyCode.C, Enum.KeyCode.T, Enum.KeyCode.Space,
	Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right,
}

local active = false
local saved: { Type: Enum.CameraType, CFrame: CFrame, Fov: number, HideUI: boolean }? = nil
local yaw, pitch, roll = 0, 0, 0
local smoothYaw, smoothPitch, smoothRoll = 0, 0, 0
local position = Vector3.zero
local velocity = Vector3.zero
local speed = START_SPEED
local fov = 70
local looking = false
local connections: { RBXScriptConnection } = {}
local hint: ScreenGui? = nil

local function controls(): any?
	local scripts = player:FindFirstChild("PlayerScripts")
	local module = scripts and scripts:FindFirstChild("PlayerModule")
	if not module then
		return nil
	end
	local ok, result = pcall(function()
		return (require(module) :: any):GetControls()
	end)
	return if ok then result else nil
end

local function setLooking(on: boolean)
	looking = on
	UserInputService.MouseBehavior = if on then Enum.MouseBehavior.LockCurrentPosition else Enum.MouseBehavior.Default
end

local function showHint()
	local gui = Theme.ScreenGui("FreeCamHint", 90)
	Theme.Label({
		Text = "FREE CAM   WASD move  -  E/Q up/down  -  hold right mouse to look  -  Shift fast, Ctrl slow  -  wheel speed  -  R/F zoom  -  Z/C tilt  -  F6 exit",
		TextSize = 18,
		TextScaled = false,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(900, 30),
		StrokeThickness = 2,
		Parent = gui,
	})
	hint = gui
	task.delay(HINT_SECONDS, function()
		if hint == gui then
			hint = nil
		end
		gui:Destroy()
	end)
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	-- (typing in chat or a text box: stand still)
	local typing = UserInputService:GetFocusedTextBox() ~= nil
	local function down(key: Enum.KeyCode): boolean
		return not typing and UserInputService:IsKeyDown(key)
	end

	local dir = Vector3.zero
	if down(Enum.KeyCode.W) or down(Enum.KeyCode.Up) then dir += Vector3.new(0, 0, -1) end
	if down(Enum.KeyCode.S) or down(Enum.KeyCode.Down) then dir += Vector3.new(0, 0, 1) end
	if down(Enum.KeyCode.A) or down(Enum.KeyCode.Left) then dir += Vector3.new(-1, 0, 0) end
	if down(Enum.KeyCode.D) or down(Enum.KeyCode.Right) then dir += Vector3.new(1, 0, 0) end
	if down(Enum.KeyCode.E) or down(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
	if down(Enum.KeyCode.Q) then dir -= Vector3.new(0, 1, 0) end
	local factor = 1
	if down(Enum.KeyCode.LeftShift) or down(Enum.KeyCode.RightShift) then
		factor = FAST
	elseif down(Enum.KeyCode.LeftControl) or down(Enum.KeyCode.RightControl) then
		factor = SLOW
	end
	if dir.Magnitude > 0 then
		dir = dir.Unit
	end

	local rotation = CFrame.fromEulerAnglesYXZ(math.rad(smoothPitch), math.rad(smoothYaw), 0)
	local wanted = (rotation * Vector3.new(dir.X, 0, dir.Z) + Vector3.new(0, dir.Y, 0)) * speed * factor
	velocity = velocity:Lerp(wanted, 1 - math.exp(-dt * MOVE_SMOOTH))
	position += velocity * dt

	local lookBlend = 1 - math.exp(-dt * LOOK_SMOOTH)
	smoothYaw += (yaw - smoothYaw) * lookBlend
	smoothPitch += (pitch - smoothPitch) * lookBlend

	if down(Enum.KeyCode.Z) then roll += ROLL_RATE * dt end
	if down(Enum.KeyCode.C) then roll -= ROLL_RATE * dt end
	smoothRoll += (roll - smoothRoll) * lookBlend
	if down(Enum.KeyCode.R) then fov -= FOV_RATE * dt * factor ^ 0.5 end
	if down(Enum.KeyCode.F) then fov += FOV_RATE * dt * factor ^ 0.5 end
	fov = math.clamp(fov, MIN_FOV, MAX_FOV)

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.new(position) * CFrame.fromEulerAnglesYXZ(math.rad(smoothPitch), math.rad(smoothYaw), math.rad(smoothRoll))
	camera.FieldOfView = fov
end

function FreeCam.IsActive(): boolean
	return active
end

function FreeCam.Stop()
	if not active then
		return
	end
	active = false
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	RunService:UnbindFromRenderStep("FreeCam")
	ContextActionService:UnbindAction("FreeCamSink")
	setLooking(false)
	player:SetAttribute("FreeCam", nil)
	local camera = workspace.CurrentCamera
	local before = saved
	saved = nil
	if camera and before then
		camera.CameraType = before.Type
		camera.FieldOfView = before.Fov
		if before.Type == Enum.CameraType.Scriptable then
			camera.CFrame = before.CFrame
		end
	end
	local pad = controls()
	if pad then
		pcall(function()
			pad:Enable()
		end)
	end
	if hint then
		hint:Destroy()
		hint = nil
	end
	if before and not before.HideUI then
		HideUI.Set(false)
	end
end

-- Returns false (and why) if it can't start now.
function FreeCam.Start(): (boolean, string?)
	if active then
		return true, nil
	end
	if player:GetAttribute("Admin") ~= true then
		return false, "Free cam is for admins"
	end
	if player:GetAttribute("Intro") or player:GetAttribute("LoadingScreen") or player:GetAttribute("MythicOpening") then
		return false, "Wait for the scene to finish first"
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return false, "No camera yet"
	end
	active = true
	saved = { Type = camera.CameraType, CFrame = camera.CFrame, Fov = camera.FieldOfView, HideUI = HideUI.IsHidden() }
	player:SetAttribute("FreeCam", true)
	local x, y = camera.CFrame:ToEulerAnglesYXZ()
	pitch, yaw, roll = math.deg(x), math.deg(y), 0
	smoothPitch, smoothYaw, smoothRoll = pitch, yaw, 0
	position = camera.CFrame.Position
	velocity = Vector3.zero
	fov = camera.FieldOfView
	speed = START_SPEED

	local pad = controls()
	if pad then
		pcall(function()
			pad:Disable()
		end)
	end
	ContextActionService:BindActionAtPriority("FreeCamSink", function()
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, table.unpack(SINK_KEYS))
	RunService:BindToRenderStep("FreeCam", Enum.RenderPriority.Camera.Value + 2, step)

	table.insert(connections, UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			setLooking(true)
		elseif not processed and input.KeyCode == Enum.KeyCode.T then
			roll, fov = 0, saved and saved.Fov or 70
		end
	end))
	table.insert(connections, UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			setLooking(false)
		end
	end))
	table.insert(connections, UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if looking then
				yaw -= input.Delta.X * LOOK_SPEED
				pitch = math.clamp(pitch - input.Delta.Y * LOOK_SPEED, -89, 89)
			end
		elseif input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
			speed = math.clamp(speed * 1.2 ^ input.Position.Z, MIN_SPEED, MAX_SPEED)
		end
	end))
	-- (admin taken away, or a scene starts: back to normal)
	table.insert(connections, player:GetAttributeChangedSignal("Admin"):Connect(function()
		if player:GetAttribute("Admin") ~= true then
			FreeCam.Stop()
		end
	end))
	table.insert(connections, player:GetAttributeChangedSignal("Intro"):Connect(function()
		if player:GetAttribute("Intro") then
			FreeCam.Stop()
		end
	end))

	HideUI.Set(true, true)
	showHint()
	return true, nil
end

function FreeCam.Toggle(): (boolean, string?)
	if active then
		FreeCam.Stop()
		return true, nil
	end
	return FreeCam.Start()
end

function FreeCam.Init()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == TOGGLE_KEY and player:GetAttribute("Admin") == true then
			FreeCam.Toggle()
		end
	end)
end

return FreeCam
