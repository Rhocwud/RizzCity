---------------------------------------------------------------------
-- [[ 🕶️ THE DEV MAFIA DISCORD // https://discord.gg/9TNSu9bGBW ]]
---------------------------------------------------------------------
-- Created by I_Logicall on 17th June 2025
---------------------------------------------------------------------
-- The main Skybox roation script itself!
-- Here you can mess with the rotation speed, angle, and whatever else you choose to edit
-- Make sure that you've ungrouped (CTRL + U) everything accordingly and you have a Sky in game.Lighting!
---------------------------------------------------------------------
-- If you need any further help or guidance, please don't hesitate to let me know in "#❓│help-and-guides" inside The Dev Mafia Discord Server!
-- If you have any further tutorial suggestions or feedback, you're more than welcome to make a post in "#📝│suggestions-and-feedback" too!
-- That's all from me though, happy developing! 🤍
---------------------------------------------------------------------

local lighting = game:GetService("Lighting")
local runService = game:GetService("RunService")

local sky = lighting:FindFirstChild("Sky")
local rotationSpeed = 10 -- Change this to whatever you want! Negative values makes the skybox rotate in the opposite direction!

runService.Heartbeat:Connect(function(deltaTime) -- Runs every frame
	if sky then
		-- Rotates the skybox depending on your rotation speed and multiplying it by deltaTime to make sure it's smooth for everyone no matter what FPS they're running on!
		sky.SkyboxOrientation = Vector3.new(0, (sky.SkyboxOrientation.Y + rotationSpeed * deltaTime) % 360, 0)
	else
		-- Extra warning just in case
		warn("No skybox found in game.Lighting")
		script.Enabled = false
	end
end)