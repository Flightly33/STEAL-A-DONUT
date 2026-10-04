--[[
	Bases: find base plots in the map from the client. The 6 bases sit in the lobby
	(workspace.Map.Plots.PlotN); the local player's is player attribute PlotIndex.
]]

local Players = game:GetService("Players")

local player = Players.LocalPlayer :: Player

local Bases = {}

function Bases.GetPlot(plotIndex: any): Model?
	local map = workspace:FindFirstChild("Map")
	if not map or type(plotIndex) ~= "number" then
		return nil
	end
	local plots = map:FindFirstChild("Plots")
	local plot = plots and plots:FindFirstChild("Plot" .. plotIndex)
	return if plot and plot:IsA("Model") then plot else nil
end

-- The local player's base plot.
function Bases.Mine(): Model?
	return Bases.GetPlot(player:GetAttribute("PlotIndex"))
end

return Bases
