--[[
	Bases: find base plots in the map from the client. Every world's hub has the same plots, and the
	local player's base is in the world they're in (player attributes PlotIndex + BaseWorld).
]]

local Players = game:GetService("Players")

local player = Players.LocalPlayer :: Player

local Bases = {}

function Bases.GetPlot(plotIndex: any, worldId: any): Model?
	local map = workspace:FindFirstChild("Map")
	if not map or type(plotIndex) ~= "number" then
		return nil
	end
	local world = if type(worldId) == "number" then worldId else 1
	local plots: Instance? = nil
	if world == 1 then
		plots = map:FindFirstChild("Plots")
	else
		local worlds = map:FindFirstChild("Worlds")
		local hub = worlds and worlds:FindFirstChild("World" .. world)
		plots = hub and hub:FindFirstChild("Plots")
	end
	local plot = plots and plots:FindFirstChild("Plot" .. plotIndex)
	return if plot and plot:IsA("Model") then plot else nil
end

-- The local player's base plot right now.
function Bases.Mine(): Model?
	return Bases.GetPlot(player:GetAttribute("PlotIndex"), player:GetAttribute("BaseWorld"))
end

return Bases
