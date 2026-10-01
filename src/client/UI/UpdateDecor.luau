--[[
	UpdateDecor: the decorations that theme the Update Log to each update (UI/UpdateNotes).

	  * Emblem  - the corner badge: a real 3D donut in the update's frosting and sprinkles, rocking
	              gently on a medallion, inside a slowly turning wheel of sprinkle "handles"
	  * Motes   - things floating around the notes, one style per update (UpdateNotes Decor):
	              Rise (golden diamonds + sparkles drifting up), Embers (sparks rising from a lava
	              glow), Stars (twinkling stars and the odd shooting star), Sparkles (soft bubbles)
	  * Swirl   - faint curly arcs in the corners (they turn slowly for Stars)
	  * Glow    - a soft band of colour along the bottom of the notes
	  * Divider - a thin line with a little gem in the middle, between sections

	Everything is drawn with plain frames, strokes and gradients (no images to upload). Each builder
	returns a step function: UpdateNotes calls them every frame while the window is open.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Notes = require(Shared.UpdateNotes)
local DonutModel = require(Shared.DonutModel)
local Theme = require(script.Parent.Theme)

local UpdateDecor = {}

export type Step = (t: number, dt: number) -> ()

local rgb = Color3.fromRGB
local WHITE = rgb(255, 255, 255)
local DOUGH = rgb(222, 165, 95)
local TAU = math.pi * 2

local function circle(props: { [string]: any }): Frame
	local frame = Theme.new("Frame", props)
	Theme.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = frame })
	return frame
end

-- A ring drawn as a stroke, faded out along part of its length so it reads as an arc.
-- `cut` = how much of the ring is hidden (0..1), `rotation` turns the visible part.
local function arc(parent: Instance, center: UDim2, diameter: number, thickness: number, color: Color3, transparency: number, cut: number, rotation: number, z: number): Frame
	local ring = circle({
		Name = "Arc",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = center,
		Size = UDim2.fromOffset(diameter, diameter),
		BackgroundTransparency = 1,
		ZIndex = z,
		Parent = parent,
	})
	local stroke = Theme.new("UIStroke", { Thickness = thickness, Color = color, Transparency = 0, Parent = ring })
	local a = math.clamp(1 - cut, 0.05, 0.95)
	Theme.new("UIGradient", {
		Rotation = rotation,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, transparency),
			NumberSequenceKeypoint.new(a * 0.5, transparency),
			NumberSequenceKeypoint.new(math.min(a * 0.5 + 0.12, 0.99), 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = stroke,
	})
	return ring
end

---------------------------------------------------------------------------------------------------
-- Emblem
---------------------------------------------------------------------------------------------------
local HANDLES = 10

-- The donut the emblem shows (a plain donut: no face, sprinkles all round).
local function emblemDonut(update: Notes.Update): any
	local emblem = update.Emblem
	return {
		Id = "update" .. update.Version,
		Name = update.Name,
		Rarity = "Common",
		Area = 1,
		Income = 0,
		Weight = 0,
		Dough = if emblem and emblem.Dough then emblem.Dough else DOUGH,
		Frosting = if emblem then emblem.Frosting else update.Accent,
		Sprinkles = if emblem then emblem.Sprinkles else { WHITE, update.Accent },
		Parts = {},
		Score = 0,
		Index = 0,
	}
end

-- Builds the badge (size x size) into `parent`; returns its frame and a step function.
function UpdateDecor.Emblem(parent: Instance, update: Notes.Update, size: number, z: number): (Frame, Step)
	local color, accent = update.Color, update.Accent
	local holder = Theme.new("Frame", {
		Name = "Emblem",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		ZIndex = z,
		Parent = parent,
	})
	local mid = UDim2.fromScale(0.5, 0.5)
	-- Soft glow behind everything
	local glow = circle({
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = mid,
		Size = UDim2.fromScale(1.25, 1.25),
		BackgroundColor3 = accent,
		BackgroundTransparency = 0.8,
		ZIndex = z,
		Parent = holder,
	})
	-- The wheel: a rim and sprinkle-shaped handles all the way round (they turn slowly)
	local rim = circle({
		Name = "Rim",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = mid,
		Size = UDim2.fromScale(0.86, 0.86),
		BackgroundTransparency = 1,
		ZIndex = z + 1,
		Parent = holder,
	})
	Theme.new("UIStroke", { Thickness = size * 0.06, Color = WHITE, Parent = rim }, {
		Theme.new("UIGradient", { Rotation = 45, Color = ColorSequence.new(Theme.Lighten(accent, 0.35), Theme.Darken(accent, 0.3)) }),
	})
	local handles: { Frame } = {}
	local sprinkles = if update.Emblem then update.Emblem.Sprinkles else { accent }
	for i = 1, HANDLES do
		local tint = if i % 2 == 0 then accent else sprinkles[(i // 2) % #sprinkles + 1]
		local handle = Theme.new("Frame", {
			Name = "Handle",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(size * 0.1, size * 0.24),
			BackgroundColor3 = WHITE,
			ZIndex = z + 1,
			Parent = holder,
		}, {
			Theme.new("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Theme.Stroke(2.5),
			Theme.new("UIGradient", { Rotation = 0, Color = ColorSequence.new(Theme.Lighten(tint, 0.45), Theme.Darken(tint, 0.15)) }),
		})
		table.insert(handles, handle)
	end
	-- The medallion the donut sits on
	local medallion = circle({
		Name = "Medallion",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = mid,
		Size = UDim2.fromScale(0.74, 0.74),
		BackgroundColor3 = WHITE,
		ZIndex = z + 2,
		Parent = holder,
	})
	Theme.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Theme.Lighten(color, 0.3), Theme.Darken(color, 0.55)), Parent = medallion })
	Theme.Stroke(4).Parent = medallion
	local inner = arc(holder, mid, size * 0.64, 2, Theme.Lighten(accent, 0.4), 0.2, 0.25, 0, z + 3)
	-- The donut itself
	local viewport = Theme.new("ViewportFrame", {
		Name = "Donut",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = mid,
		Size = UDim2.fromScale(0.9, 0.9),
		BackgroundTransparency = 1,
		Ambient = rgb(175, 165, 185),
		LightColor = WHITE,
		LightDirection = Vector3.new(-0.5, -1, 0.6),
		ZIndex = z + 4,
		Parent = holder,
	})
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local distance = 15
	local ok, model = pcall(DonutModel.Build, emblemDonut(update), { NoEffects = true, NoFace = true })
	if ok and model then
		local box = model:GetBoundingBox()
		model:PivotTo(model:GetPivot() - box.Position)
		model.Parent = viewport
		local _, extents = model:GetBoundingBox()
		distance = math.max(extents.X, extents.Y) * 2.1
	end
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, -distance), Vector3.zero)

	local radius = size * 0.43
	local function step(t: number, _dt: number)
		local spin = t * 0.25
		for i, handle in handles do
			local angle = spin + (i - 1) / HANDLES * TAU
			handle.Position = UDim2.new(0.5, math.cos(angle) * radius, 0.5, math.sin(angle) * radius)
			handle.Rotation = math.deg(angle) + 90
		end
		glow.BackgroundTransparency = 0.78 + math.sin(t * 2) * 0.06
		inner.Rotation = -t * 20
		-- the donut rocks and bobs (a full spin would show its thin edge)
		local yaw = math.sin(t * 0.9) * 0.45
		local pitch = 0.18 + math.sin(t * 0.6) * 0.08
		camera.CFrame = CFrame.lookAt(Vector3.new(math.sin(yaw) * distance, math.sin(pitch) * distance, -math.cos(yaw) * distance), Vector3.new(0, math.sin(t * 1.6) * 0.15, 0))
	end
	step(0, 0)
	return holder, step
end

---------------------------------------------------------------------------------------------------
-- Ornaments
---------------------------------------------------------------------------------------------------

-- Curly corner ornament: three arcs that wind inwards like a swirl.
function UpdateDecor.Swirl(parent: Instance, center: UDim2, size: number, color: Color3, transparency: number, z: number): Step
	local rings = {
		arc(parent, center, size, 3, color, transparency, 0.3, 30, z),
		arc(parent, center, size * 0.7, 2.5, color, transparency + 0.08, 0.4, 150, z),
		arc(parent, center, size * 0.42, 2, color, transparency + 0.15, 0.5, 260, z),
	}
	local dot = circle({ AnchorPoint = Vector2.new(0.5, 0.5), Position = center, Size = UDim2.fromOffset(size * 0.1, size * 0.1), BackgroundColor3 = color, BackgroundTransparency = transparency, ZIndex = z, Parent = parent })
	return function(t: number, _dt: number)
		for i, ring in rings do
			ring.Rotation = t * (6 + i * 4) * (if i % 2 == 0 then -1 else 1)
		end
		dot.BackgroundTransparency = transparency + math.sin(t * 1.5) * 0.08
	end
end

-- A soft band of colour fading up from the bottom of `parent`.
function UpdateDecor.Glow(parent: Instance, color: Color3, height: number, strength: number, z: number): Step
	local band = Theme.new("Frame", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	})
	local gradient = Theme.new("UIGradient", { Rotation = 90, Parent = band })
	return function(t: number, _dt: number)
		local s = strength * (0.85 + math.sin(t * 1.3) * 0.15)
		gradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 1 - s) })
	end
end

-- A slowly turning sunburst of soft rays (behind the update's title).
function UpdateDecor.Rays(parent: Instance, center: UDim2, length: number, count: number, color: Color3, transparency: number, z: number): Step
	local rays: { Frame } = {}
	for i = 1, count do
		local ray = Theme.new("Frame", {
			Name = "Ray",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = center,
			Size = UDim2.fromOffset(length * 2, if i % 2 == 0 then 10 else 16),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z,
			Parent = parent,
		}, {
			Theme.new("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.3, transparency),
					NumberSequenceKeypoint.new(0.5, 1),
					NumberSequenceKeypoint.new(0.7, transparency),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
		table.insert(rays, ray)
	end
	return function(t: number, _dt: number)
		for i, ray in rays do
			ray.Rotation = (i - 1) * 180 / count + t * 4
		end
	end
end

-- Thin line with a gem in the middle (between sections).
function UpdateDecor.Divider(color: Color3, width: number): Frame
	local holder = Theme.new("Frame", { Name = "Divider", BackgroundTransparency = 1, Size = UDim2.new(0, width, 0, 14) })
	local line = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = holder,
	})
	Theme.new("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.1), NumberSequenceKeypoint.new(1, 1) }),
		Parent = line,
	})
	for i, scale in { 1, 0.55 } do
		Theme.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(12 * scale, 12 * scale),
			Rotation = 45,
			BackgroundColor3 = if i == 1 then color else WHITE,
			BorderSizePixel = 0,
			ZIndex = i + 1,
			Parent = holder,
		}, if i == 1 then { Theme.Stroke(2) } else nil)
	end
	return holder
end

---------------------------------------------------------------------------------------------------
-- Motes: things floating around the notes
---------------------------------------------------------------------------------------------------
type Style = {
	Count: number,
	Shapes: { string }, -- "Dot", "Diamond", "Spark"
	Colors: { Color3 },
	Size: NumberRange, -- pixels
	Motion: string, -- "Rise", "Twinkle", "Drift"
	Speed: NumberRange, -- fraction of the height per second
	Glow: Color3?, -- bottom glow colour
	Shooting: boolean?, -- the odd shooting star
	Spin: boolean?, -- the corner swirls turn
}

local STYLES: { [string]: Style } = {
	Rise = {
		Count = 18, Shapes = { "Diamond", "Diamond", "Spark" },
		Colors = { rgb(255, 225, 90), rgb(255, 245, 180), rgb(150, 255, 160) },
		Size = NumberRange.new(6, 13), Motion = "Rise", Speed = NumberRange.new(0.05, 0.11),
		Glow = rgb(255, 215, 80),
	},
	Embers = {
		Count = 28, Shapes = { "Dot", "Dot", "Dot", "Spark" },
		Colors = { rgb(255, 220, 90), rgb(255, 140, 30), rgb(255, 90, 10) },
		Size = NumberRange.new(4, 10), Motion = "Rise", Speed = NumberRange.new(0.08, 0.18),
		Glow = rgb(255, 90, 10),
	},
	Stars = {
		Count = 32, Shapes = { "Dot", "Dot", "Spark" },
		Colors = { rgb(255, 255, 255), rgb(210, 190, 255), rgb(255, 215, 150) },
		Size = NumberRange.new(3, 10), Motion = "Twinkle", Speed = NumberRange.new(1, 2.6),
		Glow = rgb(140, 80, 255), Shooting = true, Spin = true,
	},
	Sparkles = {
		Count = 18, Shapes = { "Bubble", "Bubble", "Spark" },
		Colors = { rgb(255, 170, 220), rgb(255, 230, 150), rgb(255, 255, 255) },
		Size = NumberRange.new(8, 20), Motion = "Drift", Speed = NumberRange.new(0.03, 0.07),
		Glow = rgb(255, 120, 200),
	},
}

function UpdateDecor.Style(update: Notes.Update): Style
	return STYLES[update.Decor or ""] or STYLES.Sparkles
end

local function shape(kind: string, size: number, color: Color3, z: number): Frame
	local holder = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = z,
	})
	if kind == "Diamond" then
		holder.BackgroundTransparency = 0
		holder.BackgroundColor3 = color
		holder.Rotation = 45
		holder.BorderSizePixel = 0
	elseif kind == "Spark" then
		-- four-pointed twinkle: two thin crossed bars
		for _, rotation in { 0, 90 } do
			Theme.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1.6, 0, 0, math.max(2, size * 0.22)),
				Rotation = rotation,
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				ZIndex = z,
				Parent = holder,
			}, {
				Theme.new("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Theme.new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }),
			})
		end
	elseif kind == "Bubble" then
		Theme.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = holder })
		holder.BackgroundTransparency = 0.75
		holder.BackgroundColor3 = color
		Theme.new("UIStroke", { Thickness = 1.5, Color = color, Transparency = 0.3, Parent = holder })
	else -- Dot
		holder.BackgroundTransparency = 0
		holder.BackgroundColor3 = color
		holder.BorderSizePixel = 0
		Theme.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = holder })
		Theme.new("UIStroke", { Thickness = math.max(1, size * 0.35), Color = color, Transparency = 0.6, Parent = holder })
	end
	return holder
end

type Mote = { Frame: Frame, X: number, Y: number, Speed: number, Phase: number, Base: number, Sway: number }

-- Fills `parent` (which should clip) with the update's floating motes; returns the step function.
function UpdateDecor.Motes(parent: Instance, update: Notes.Update, z: number): Step
	local style = UpdateDecor.Style(update)
	local rng = Random.new(update.Version * 7919)
	local motes: { Mote } = {}
	local function place(mote: Mote, anywhere: boolean)
		mote.X = rng:NextNumber(0.02, 0.98)
		mote.Y = if anywhere or style.Motion ~= "Rise" then rng:NextNumber(0, 1) else rng:NextNumber(1.02, 1.12)
		mote.Speed = rng:NextNumber(style.Speed.Min, style.Speed.Max)
		mote.Phase = rng:NextNumber(0, TAU)
	end
	for i = 1, style.Count do
		local kind = style.Shapes[(i - 1) % #style.Shapes + 1]
		local size = rng:NextNumber(style.Size.Min, style.Size.Max)
		local color = style.Colors[rng:NextInteger(1, #style.Colors)]
		local frame = shape(kind, size, color, z)
		frame.Name = "Mote"
		frame.Parent = parent
		local mote = { Frame = frame, X = 0, Y = 0, Speed = 0, Phase = 0, Base = frame.BackgroundTransparency, Sway = rng:NextNumber(0.006, 0.02) }
		place(mote, true)
		table.insert(motes, mote)
	end

	-- The odd shooting star (Stars)
	local streak: Frame? = nil
	local streakAt, streakFrom, streakTo = -10, Vector2.zero, Vector2.zero
	if style.Shooting then
		local s = Theme.new("Frame", {
			Name = "ShootingStar",
			AnchorPoint = Vector2.new(1, 0.5),
			Size = UDim2.fromOffset(90, 2),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = z,
			Parent = parent,
		})
		Theme.new("UIGradient", { Transparency = NumberSequence.new(1, 0), Parent = s })
		streak = s
	end

	local function setTransparency(mote: Mote, alpha: number)
		local frame = mote.Frame
		if frame.BackgroundTransparency < 1 or mote.Base < 1 then
			frame.BackgroundTransparency = 1 - (1 - mote.Base) * alpha
		end
		for _, child in frame:GetChildren() do
			if child:IsA("Frame") then
				child.BackgroundTransparency = 1 - alpha
			elseif child:IsA("UIStroke") then
				child.Transparency = 1 - alpha * 0.5
			end
		end
	end

	return function(t: number, dt: number)
		for _, mote in motes do
			local alpha = 1
			if style.Motion == "Rise" then
				mote.Y -= mote.Speed * dt
				if mote.Y < -0.05 then
					place(mote, false)
				end
				-- fade in at the bottom, out near the top, and flicker a little
				alpha = math.clamp((1.05 - mote.Y) * 5, 0, 1) * math.clamp(mote.Y * 3, 0, 1) * (0.75 + 0.25 * math.sin(t * 9 + mote.Phase))
				mote.Frame.Position = UDim2.fromScale(mote.X + math.sin(t * 1.4 + mote.Phase) * mote.Sway, mote.Y)
				mote.Frame.Rotation = if mote.Frame.Rotation ~= 0 then 45 + math.sin(t + mote.Phase) * 20 else 0
			elseif style.Motion == "Twinkle" then
				local wave = 0.5 + 0.5 * math.sin(t * mote.Speed + mote.Phase)
				alpha = 0.15 + 0.85 * wave * wave * wave
				if wave < 0.02 then
					mote.X = rng:NextNumber(0.02, 0.98)
					mote.Y = rng:NextNumber(0.02, 0.98)
				end
				mote.Frame.Position = UDim2.fromScale(mote.X, mote.Y)
			else -- Drift: slow bubbles
				mote.Y -= mote.Speed * dt
				if mote.Y < -0.08 then
					place(mote, false)
					mote.Y = 1.08
				end
				alpha = math.clamp((1.08 - mote.Y) * 4, 0, 1) * math.clamp((mote.Y + 0.08) * 4, 0, 1)
				mote.Frame.Position = UDim2.fromScale(mote.X + math.sin(t * 0.7 + mote.Phase) * mote.Sway * 2, mote.Y)
			end
			setTransparency(mote, alpha)
		end
		if streak then
			local age = t - streakAt
			if age > 7 then
				streakAt = t + rng:NextNumber(0, 3)
				streakFrom = Vector2.new(rng:NextNumber(0.2, 1), rng:NextNumber(-0.05, 0.35))
				streakTo = streakFrom + Vector2.new(-0.45, 0.3)
			end
			local p = (t - streakAt) / 0.8
			streak.Visible = p >= 0 and p <= 1
			if streak.Visible then
				local at = streakFrom:Lerp(streakTo, p)
				streak.Position = UDim2.fromScale(at.X, at.Y)
				streak.Rotation = 180 - 33
				streak.BackgroundTransparency = p * p
			end
		end
	end
end

return UpdateDecor
