--[[
	DomerFX: the Domers' anime effects (AnimeFX), all on this client.

	  * The moment YOUR Domer wakes up: an impact frame bursts off him (a ring breaking apart, a
	    star flash, speed lines, smoke puffs) and, if you're close, speed lines rush over your
	    screen (SpeedLines).
	  * While he's after you he powers up: an aura of energy flames rises off him in his biome's
	    colours. The later the biome, the crazier: from biome 5 he gets his biome's own extra
	    (ice twinkles, toon fire, lightning zaps, sword slashes...), from biome 10 a bigger aura
	    and an impact frame under his feet every couple of seconds as he stomps after you, and from
	    biome 14 a second extra on top.
	  * Asleep, the Domers of the last biomes (10 and up) give off a few soft twinkles, so you can
	    tell they're the strong ones.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimeFX = require(Shared.AnimeFX)
local Config = require(Shared.Config)

local SpeedLines = require(script.Parent.SpeedLines)

local DomerFX = {}

local rgb = Color3.fromRGB
local SCALE = Config.Guard.Scale

type Style = { Colors: { Color3 }, Extras: { string } }

-- Each biome's colours and its extras (AnimeFX: Kira, ToonFire, Zaps, Slashes).
local STYLES: { [number]: Style } = {
	[1] = { Colors = { rgb(255, 150, 210), rgb(255, 230, 120), rgb(255, 90, 160) }, Extras = {} },
	[2] = { Colors = { rgb(120, 200, 255), rgb(220, 245, 255), rgb(40, 120, 255) }, Extras = {} },
	[3] = { Colors = { rgb(255, 210, 90), rgb(255, 245, 200), rgb(230, 140, 40) }, Extras = {} },
	[4] = { Colors = { rgb(120, 230, 100), rgb(230, 255, 160), rgb(40, 150, 60) }, Extras = {} },
	[5] = { Colors = { rgb(150, 225, 255), rgb(255, 255, 255), rgb(60, 140, 255) }, Extras = { "Kira" } },
	[6] = { Colors = { rgb(255, 120, 30), rgb(255, 225, 90), rgb(190, 20, 10) }, Extras = { "ToonFire" } },
	[7] = { Colors = { rgb(255, 150, 60), rgb(255, 220, 140), rgb(110, 60, 30) }, Extras = { "Slashes" } },
	[8] = { Colors = { rgb(255, 110, 180), rgb(255, 255, 255), rgb(230, 40, 60) }, Extras = { "Kira" } },
	[9] = { Colors = { rgb(255, 220, 60), rgb(90, 170, 255), rgb(255, 70, 70) }, Extras = { "Slashes" } },
	[10] = { Colors = { rgb(120, 255, 150), rgb(200, 255, 210), rgb(140, 60, 220) }, Extras = { "ToonFire" } },
	[11] = { Colors = { rgb(255, 230, 140), rgb(255, 255, 255), rgb(255, 180, 90) }, Extras = { "Kira" } },
	[12] = { Colors = { rgb(255, 40, 200), rgb(0, 255, 220), rgb(120, 0, 160) }, Extras = { "Zaps" } },
	[13] = { Colors = { rgb(0, 255, 220), rgb(255, 190, 0), rgb(0, 120, 160) }, Extras = { "Zaps" } },
	[14] = { Colors = { rgb(255, 190, 90), rgb(255, 240, 200), rgb(170, 110, 50) }, Extras = { "Slashes", "Kira" } },
	[15] = { Colors = { rgb(255, 225, 130), rgb(255, 255, 255), rgb(255, 185, 80) }, Extras = { "Kira", "Slashes" } },
	[16] = { Colors = { rgb(255, 0, 200), rgb(0, 255, 220), rgb(30, 0, 40) }, Extras = { "Zaps", "Slashes" } },
	[17] = { Colors = { rgb(170, 90, 255), rgb(80, 220, 255), rgb(25, 5, 45) }, Extras = { "Zaps", "Kira" } },
}

-- How strong his effects are in this biome: 1 (the first biomes) .. 4 (the last ones).
function DomerFX.Level(areaId: number): number
	return if areaId >= 14 then 4 elseif areaId >= 10 then 3 elseif areaId >= 5 then 2 else 1
end

function DomerFX.Style(areaId: number): Style
	return STYLES[areaId] or STYLES[1]
end

local folder: Folder? = nil
local function holder(name: string, size: Vector3, cf: CFrame): Part
	if not folder then
		local f = Instance.new("Folder")
		f.Name = "DomerFX"
		f.Parent = workspace
		folder = f
	end
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = folder
	return part
end

-- An impact frame at `at` (studs; `size` = how big), gone again in a moment.
function DomerFX.Impact(at: Vector3, colors: { Color3 }, size: number, amount: number?)
	local spot = holder("Impact", Vector3.one * 0.2, CFrame.new(at))
	AnimeFX.Fire(AnimeFX.Impact(spot, colors, size), amount)
	task.delay(1.5, function()
		spot:Destroy()
	end)
end

-- He's woken up: the impact frame off him, and speed lines on your screen if you're close.
function DomerFX.Wake(model: Model, areaId: number)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local style = DomerFX.Style(areaId)
	local level = DomerFX.Level(areaId)
	DomerFX.Impact(root.Position + Vector3.new(0, SCALE * 0.8, 0), style.Colors, SCALE * (0.9 + level * 0.25), 1 + level * 0.3)
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - root.Position).Magnitude < 160 then
		SpeedLines.Flash(0.5 + level * 0.1, 0.7 + level * 0.1)
	end
end

-- His power-up while he's after you (State "Waking" or "Chasing"); stops by itself when he gives
-- up or is gone.
function DomerFX.Chase(model: Model, areaId: number)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local style = DomerFX.Style(areaId)
	local level = DomerFX.Level(areaId)
	local colors = style.Colors
	local feetDrop = 3 * SCALE - 0.5 -- (his root is his middle; his feet are this far below)
	local feet = holder("DomerAura", Vector3.new(2.6, 0.5, 1.8) * SCALE, root.CFrame * CFrame.new(0, -feetDrop, 0))
	local body = holder("DomerBody", Vector3.one * 4.2 * SCALE, root.CFrame)
	local emitters: { ParticleEmitter } = {}
	local ki, specks = AnimeFX.Ki(feet, colors, SCALE * (2.2 + level * 0.7), 10 + level * 6)
	table.insert(emitters, ki)
	table.insert(emitters, specks)
	local extras: { string } = if level >= 4 then style.Extras elseif level >= 2 then { style.Extras[1] } else {}
	for _, extra in extras do
		local e: ParticleEmitter? = nil
		if extra == "Kira" then
			e = AnimeFX.Kira(body, colors[1], SCALE * 0.9, 4 + level)
		elseif extra == "ToonFire" then
			e = AnimeFX.ToonFire(feet, { colors[2], colors[1], colors[3] }, SCALE * 2.2, 18 + level * 4)
		elseif extra == "Zaps" then
			e = AnimeFX.Zaps(body, colors, SCALE * 1.6, 5 + level * 2)
		elseif extra == "Slashes" then
			e = AnimeFX.Slashes(body, colors[1], SCALE * 2.6, 1.5 + level * 0.5)
		end
		if e then
			table.insert(emitters, e)
		end
	end
	for _, e in emitters do
		e.Enabled = true -- (FXBoost: always on here, it's just the one)
	end
	local nextStomp = os.clock() + 1
	local connection: RBXScriptConnection
	local function stop()
		connection:Disconnect()
		for _, e in emitters do
			e.Enabled = false
		end
		task.delay(1.2, function()
			feet:Destroy()
			body:Destroy()
		end)
	end
	connection = RunService.RenderStepped:Connect(function()
		local state = model:GetAttribute("State")
		if not model.Parent or not root.Parent or (state ~= "Waking" and state ~= "Chasing") then
			stop()
			return
		end
		local cf = root.CFrame
		feet.CFrame = cf * CFrame.new(0, -feetDrop, 0)
		body.CFrame = cf
		-- the later Domers' stomps: an impact frame under his feet every couple of seconds
		if level >= 3 and state == "Chasing" and os.clock() >= nextStomp then
			nextStomp = os.clock() + (if level >= 4 then 1.4 else 2.1) + math.random() * 0.6
			DomerFX.Impact(feet.Position, colors, SCALE * 0.8, 0.6)
		end
	end)
end

-- Asleep: the last biomes' Domers sparkle a little (a part of his model, so it moves with him).
function DomerFX.Sleeper(model: Model, areaId: number)
	if DomerFX.Level(areaId) < 3 then
		return
	end
	local cf, size = model:GetBoundingBox()
	local sphere = Instance.new("Part")
	sphere.Name = "DreamTwinkles"
	sphere.Size = Vector3.one * math.min(size.X, size.Y, size.Z) * 0.9
	sphere.CFrame = cf
	sphere.Anchored = true
	sphere.CanCollide = false
	sphere.CanQuery = false
	sphere.CanTouch = false
	sphere.Transparency = 1
	sphere.Parent = model
	local twinkles = AnimeFX.Kira(sphere, DomerFX.Style(areaId).Colors[1], SCALE * 0.6, 1.5)
	twinkles.Enabled = true
end

return DomerFX
