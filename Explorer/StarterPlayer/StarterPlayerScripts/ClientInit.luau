--!strict
-- Boots flags/tuning, disables default controls, and starts controllers.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer

-- Shared config
local Shared = RS:WaitForChild("Shared")
local ConfigFolder = Shared:WaitForChild("Config")
local FeatureFlags = require(ConfigFolder:WaitForChild("FeatureFlags"))
local Tuning = require(ConfigFolder:WaitForChild("Tuning"))

-- Disable Roblox default controls so our input owns movement
local function disableDefaultControls()
	local pm = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	pm:GetControls():Disable()
end

-- Set camera caps early (server also does this in PlayerService)
local function applyCameraCaps()
	player.CameraMinZoomDistance = Tuning.Camera.MinZoom
	player.CameraMaxZoomDistance = Tuning.Camera.MaxZoom
end

disableDefaultControls()
applyCameraCaps()

-- Start controllers
-- CameraController and TargetLockController follow the module:Start(...) pattern.
require(script.Parent:WaitForChild("CameraController")):Start(FeatureFlags, Tuning)

-- MovementController must be instantiated via .new() to create a proper instance.
-- This prevents calling Start on the module table (which causes nil-field errors).
local MovementModule = require(script.Parent:WaitForChild("MovementController"))
local movementController = MovementModule.new()
movementController:Start(FeatureFlags, Tuning)

require(script.Parent:WaitForChild("TargetLockController")):Start(FeatureFlags, Tuning)

-- Optional: hide default reset button etc. if you like
pcall(function()
	StarterGui:SetCore("ResetButtonCallback", false)
end)
