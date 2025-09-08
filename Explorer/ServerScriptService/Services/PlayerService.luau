--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Config = RS.Shared.Config
local FeatureFlags = require(Config.FeatureFlags)
local Tuning = require(Config.Tuning)

Players.PlayerAdded:Connect(function(plr)
	-- (Optional) store flags on a folder for client to read
	local folder = Instance.new("Folder")
	folder.Name = "GameConfig"
	folder.Parent = plr
	local ff = Instance.new("BoolValue")
	ff.Name = "NewMovementEnabled"
	ff.Value = FeatureFlags.NewMovementEnabled
	ff.Parent = folder
	local fc = Instance.new("BoolValue")
	fc.Name = "NewCombatEnabled"
	fc.Value = FeatureFlags.NewCombatEnabled
	fc.Parent = folder

	-- Camera caps (client will also enforce, but this helps Studio test)
	plr.CameraMinZoomDistance = Tuning.Camera.MinZoom
	plr.CameraMaxZoomDistance = Tuning.Camera.MaxZoom
end)

