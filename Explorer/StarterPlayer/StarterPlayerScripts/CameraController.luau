--!strict

--====================================================--
--  Script: [CameraController]
--  Location: [StarterPlayer/StarterPlayerScripts/]
--  Version: 1.0.0
--  Last Updated: 2025-09-06
--  Author: Rhocwud Games
--
--  Description:
--      [Enforces shift-lock style camera & zoom caps; target-lock hook comes later.]
--
--  Change Log:
--      v1.0.0 - Initial version
--
--====================================================--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local M = {}
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local tuning

function M:Start(_flags, _tuning)
	tuning = _tuning
	player.CameraMinZoomDistance = tuning.Camera.MinZoom
	player.CameraMaxZoomDistance = tuning.Camera.MaxZoom

	-- Keep enforcing caps (studio hot-reload safety)
	RunService.RenderStepped:Connect(function()
		if player.CameraMinZoomDistance ~= tuning.Camera.MinZoom then
			player.CameraMinZoomDistance = tuning.Camera.MinZoom
		end
		if player.CameraMaxZoomDistance ~= tuning.Camera.MaxZoom then
			player.CameraMaxZoomDistance = tuning.Camera.MaxZoom
		end
	end)
end

return M

