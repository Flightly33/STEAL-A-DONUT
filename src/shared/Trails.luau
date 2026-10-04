--[[
	Trails: an effect behind you while you run, drawn by every client (client/TrailFX). Pick one in
	the Trails window (HUD). The server keeps what you own (Data.OwnedTrails) and what you wear
	(Data.EquippedTrail, shown to everyone as the player's "Trail" attribute).

	UnlockBiome: the trail unlocks for good the first time your Speed is enough to get into that
	biome (the HUD shows a "!" on the Trails button, and it's put on for you if you wear none).

	Fast Guy: you run so fast you leave frozen frames of yourself behind - see-through blue-white
	afterimages with glowing outlines, a streak of light, and now and then a pane of glass that
	cracks and shatters behind you.
]]

local Areas = require(script.Parent.Areas)

export type Trail = {
	Id: string,
	Name: string,
	Icon: string,
	Description: string,
	Color: Color3, -- the afterimages / streak
	Accent: Color3, -- outlines and glass edges
	UnlockBiome: number?,
	Order: number,
}

local Trails = {}

Trails.List = {
	{
		Id = "FastGuy",
		Name = "Fast Guy",
		Icon = "💨",
		Description = "Run so fast you leave frozen frames of yourself behind, and the air cracks like glass.",
		Color = Color3.fromRGB(165, 215, 255),
		Accent = Color3.fromRGB(255, 255, 255),
		UnlockBiome = 4,
		Order = 1,
	},
} :: { Trail }

Trails.ById = {} :: { [string]: Trail }
for _, trail in Trails.List do
	Trails.ById[trail.Id] = trail
end

-- You have to be running at least this fast (studs a second) for a trail to show.
Trails.MinSpeed = 30

-- The Speed stat that unlocks a trail (nil = it isn't unlocked by Speed).
function Trails.RequiredSpeed(trail: Trail): number?
	local area = trail.UnlockBiome and Areas.List[trail.UnlockBiome]
	return if area then area.RecommendedSpeed else nil
end

function Trails.IsUnlocked(trail: Trail, owned: { [string]: boolean }?, bestSpeed: number): boolean
	if owned and owned[trail.Id] then
		return true
	end
	local need = Trails.RequiredSpeed(trail)
	return need ~= nil and bestSpeed >= need
end

return Trails
