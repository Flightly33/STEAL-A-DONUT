--[[
	Loading screen (runs from ReplicatedFirst, before the rest of the game arrives). See LoadingUI.
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local LoadingUI = require(script:WaitForChild("LoadingUI"))

LoadingUI.Run(Players.LocalPlayer)
pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)
