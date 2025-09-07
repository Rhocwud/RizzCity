--!strict

--====================================================--
--  Script: [AnimationRegistry]
--  Location: [ReplicatedStorage/Shared/Config/]
--  Version: 1.0.0
--  Last Updated: 2025-09-06
--  Author: Rhocwud Games
--
--  Description:
--      [This script is a utility for managing and loading animations in a Roblox game. 
--		It efficiently handles animations by caching them and supports both "R15" and "R6" humanoid rig types. 
--		The use of an AnimationMap allows for easy configuration and extension of animations without modifying the core logic.]
--
--  Change Log:
--      v1.0.0 - Initial version
--
--====================================================--
local Players = game:GetService("Players")
local AnimationMap = require(script.Parent.AnimationMap)

local Registry = {}
local cache : {[string]: Animation} = {}

local function getRigType(humanoid: Humanoid): "R15" | "R6"
	return humanoid.RigType == Enum.HumanoidRigType.R15 and "R15" or "R6"
end

function Registry.Load(humanoid: Humanoid, name: string): AnimationTrack?
	local rig = getRigType(humanoid)
	local map = AnimationMap[rig]
	local id = map and map[name]
	if not id then return nil end

	local key = rig .. "::" .. name
	local anim = cache[key]
	if not anim then
		anim = Instance.new("Animation")
		anim.AnimationId = id
		cache[key] = anim
	end
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	return animator:LoadAnimation(anim)
end

return Registry
