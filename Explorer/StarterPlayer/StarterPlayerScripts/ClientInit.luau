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
require(script.Parent:WaitForChild("CameraController")):Start(FeatureFlags, Tuning)
require(script.Parent:WaitForChild("MovementController")):Start(FeatureFlags, Tuning)
require(script.Parent:WaitForChild("TargetLockController")):Start(FeatureFlags, Tuning)

-- Optional: hide default reset button etc. if you like
pcall(function()
    StarterGui:SetCore("ResetButtonCallback", false)
end)
