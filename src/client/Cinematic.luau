--[[
	Cinematic: a short camera move over the game for a big moment (the Eternal Storm's black hole
	tearing open, Cosmic Domer climbing out of it), like a cut-scene in an anime.

	It never takes the camera away from the game: every frame, after the normal camera has moved, it
	blends from there towards the shot (and back again at the end), so the camera eases out and back
	in with no jump, and you can keep moving. Black bars slide in, the screen's edges darken and the
	field of view zooms with the shot; all of it slides away again as the camera comes back.

	  Cinematic.Play(shot)  -> false if it can't play now (see CanPlay), true if it started
	    shot.Duration      seconds, all of it
	    shot.Frame(t, base) where the camera is at t seconds (base: where the normal camera is now)
	    shot.Fov(t)         (optional) the field of view at t
	    shot.OnStep(t)      (optional) called every frame (sound, flashes... on the shot's clock)
	    shot.BlendIn / BlendOut (optional) seconds to ease into the shot and back out of it
	  Cinematic.CanPlay()   not while you're carrying something (a Domer might be after you), in the
	                        opening scene or the loading screen, or while another shot is playing
	  Cinematic.IsPlaying()
	  Cinematic.Skip()      straight to the end: the camera eases back to you (the SKIP button that
	                        pops up on the bottom bar when you click or tap does this)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SkipButton = require(script.Parent.UI.SkipButton)

local Cinematic = {}

export type Shot = {
	Duration: number,
	Frame: (t: number, base: CFrame) -> CFrame,
	Fov: ((t: number) -> number)?,
	OnStep: ((t: number) -> ())?,
	BlendIn: number?,
	BlendOut: number?,
}

local BARS = 0.09 -- (share of the screen's height each bar covers)
local VIGNETTE = 0.55

local player = Players.LocalPlayer
local playing: Shot? = nil
local started = 0
local savedFov = 70
local gui: ScreenGui? = nil
-- (the normal camera's frame we started from last frame, and what we turned it into)
local lastBase: CFrame? = nil
local lastWritten: CFrame? = nil
local bars: { Frame } = {}
local edges: { Frame } = {}

local function smooth(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * a * (a * (a * 6 - 15) + 10)
end

function Cinematic.IsPlaying(): boolean
	return playing ~= nil
end

function Cinematic.CanPlay(): boolean
	if playing or not player then
		return false
	end
	return player:GetAttribute("CarryKind") == nil and not player:GetAttribute("Intro") and not player:GetAttribute("LoadingScreen")
end

local function buildScreen(): ScreenGui
	local screen = Instance.new("ScreenGui")
	screen.Name = "Cinematic"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 55
	table.clear(bars)
	table.clear(edges)
	for _, y in { 0, 1 } do
		local f = Instance.new("Frame")
		f.Name = if y == 0 then "TopBar" else "BottomBar"
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.AnchorPoint = Vector2.new(0, y)
		f.Position = UDim2.fromScale(0, y)
		f.Size = UDim2.fromScale(1, 0)
		f.ZIndex = 2
		f.Parent = screen
		table.insert(bars, f)
	end
	for _, side in { { 0, 0, 0.24, 1, 0 }, { 1, 0, 0.24, 1, 180 }, { 0, 0, 1, 0.28, 90 }, { 0, 1, 1, 0.28, 270 } } do
		local f = Instance.new("Frame")
		f.Name = "Vignette"
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BackgroundTransparency = 1
		f.AnchorPoint = Vector2.new(side[1], side[2])
		f.Position = UDim2.fromScale(side[1], side[2])
		f.Size = UDim2.fromScale(side[3], side[4])
		local g = Instance.new("UIGradient")
		g.Rotation = side[5]
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.45, 0.6), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = f
		f.Parent = screen
		table.insert(edges, f)
	end
	SkipButton.Attach(screen, function()
		Cinematic.Skip()
	end)
	screen.Parent = player:WaitForChild("PlayerGui")
	return screen
end

local function finish()
	playing = nil
	lastBase, lastWritten = nil, nil
	local camera = workspace.CurrentCamera
	if camera then
		camera.FieldOfView = savedFov
	end
	if gui then
		gui:Destroy()
		gui = nil
	end
end

function Cinematic.Skip()
	local shot = playing
	if not shot then
		return
	end
	-- (jump to where it starts easing back out)
	local outAt = shot.Duration - (shot.BlendOut or 0.9)
	if os.clock() - started < outAt then
		started = os.clock() - outAt
	end
end

function Cinematic.Play(shot: Shot): boolean
	if not Cinematic.CanPlay() then
		return false
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return false
	end
	playing = shot
	started = os.clock()
	savedFov = camera.FieldOfView
	gui = buildScreen()
	return true
end

-- Every frame, after the normal camera (and before the screen shakes, so they shake the shot too)
local function step()
	local shot = playing
	if not shot then
		return
	end
	local camera = workspace.CurrentCamera
	local t = os.clock() - started
	if not camera or t >= shot.Duration or (player and player:GetAttribute("Intro")) then
		finish()
		return
	end
	local blendIn, blendOut = shot.BlendIn or 0.8, shot.BlendOut or 0.9
	local weight = smooth(t / blendIn) * smooth((shot.Duration - t) / blendOut)
	local base = camera.CFrame
	if lastWritten and lastBase and base == lastWritten then
		-- (nothing has moved the camera since our last frame - a scripted camera, say: carry on from
		-- where it was, instead of building the shot on top of itself)
		base = lastBase
	end
	local ok, target = pcall(shot.Frame, t, base)
	if ok then
		camera.CFrame = base:Lerp(target, weight)
		lastBase, lastWritten = base, camera.CFrame
	end
	if shot.Fov then
		local okFov, fov = pcall(shot.Fov, t)
		if okFov then
			camera.FieldOfView = savedFov + (fov - savedFov) * weight
		end
	end
	if shot.OnStep then
		task.spawn(shot.OnStep, t)
	end
	local cover = smooth(t / 0.35) * smooth((shot.Duration - t) / 0.45)
	for _, bar in bars do
		bar.Size = UDim2.fromScale(1, BARS * cover)
	end
	for _, edge in edges do
		edge.BackgroundTransparency = 1 - VIGNETTE * cover
	end
end

function Cinematic.Init()
	RunService:BindToRenderStep("Cinematic", Enum.RenderPriority.Camera.Value + 1, step)
end

-- A frame at `from` looking at `at`, rolled `roll` radians (a dutch angle).
function Cinematic.Look(from: Vector3, at: Vector3, roll: number?): CFrame
	local cf = CFrame.lookAt(from, at)
	return if roll then cf * CFrame.Angles(0, 0, roll) else cf
end

-- A little handheld wobble (radians), on the shot's clock: for the camera to breathe.
function Cinematic.Wobble(t: number, amount: number): CFrame
	return CFrame.Angles(math.noise(t * 0.7, 3.1) * amount, math.noise(t * 0.6, 7.7) * amount, math.noise(t * 0.5, 1.9) * amount * 0.5)
end

return Cinematic
