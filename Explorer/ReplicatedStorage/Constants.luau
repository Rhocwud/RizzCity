--!strict

--====================================================--
--  Script: [Constants]
--  Location: [ReplicatedStorage/Shared/]
--  Version: 1.0.0
--  Last Updated: 2025-09-06
--  Author: Rhocwud Games
--
--  Description:
--      [Team Colors and Zone constants]
--
--  Change Log:
--      v1.0.0 - Initial version
--
--====================================================--
local Constants = {}

Constants.TEAMS = {
    [1] = { Name = "Red", BrickColor = BrickColor.new("Really red"), Color = Color3.fromRGB(255, 0, 0) },
    [2] = { Name = "Yellow", BrickColor = BrickColor.new("New Yeller"), Color = Color3.fromRGB(255, 255, 0) },
    [3] = { Name = "Blue", BrickColor = BrickColor.new("Bright blue"), Color = Color3.fromRGB(0, 162, 255) },
    [4] = { Name = "Green", BrickColor = BrickColor.new("Lime green"), Color = Color3.fromRGB(0, 255, 127) },
}

-- Zone timings
Constants.ZONE_TIMER_SECONDS = 5 * 60 -- 5:00 per round
Constants.ZONE_LOCKOUT_SECONDS = 90 -- 90s lock after capture

-- Match timing
Constants.PRE_GAME_SECONDS = 30

-- Teleport / adjacency rules
Constants.BASE_TELEPORT_ZONE_NAME = "TeleportZone"
Constants.ENFORCE_BASE_ONLY_TELEPORT = true
Constants.ENFORCE_ADJACENCY = true -- orthogonal only

return Constants
