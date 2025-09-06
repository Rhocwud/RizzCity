--!strict
--====================================================--
--  Script: [WallRun]
--  Type: [Module Script]
--  Location: [StarterPlayer/StarterPlayerScripts/WallRun]
--  Version: 1.0.0
--  Last Updated: 2025-09-06
--  Author: Rhocwud Games
--
--  Description:
--      [A template for a WallRun module script using Aligners and Raycast.]
--
--  Change Log:
--      v1.0.0 - Initial version
--
--====================================================--
-- A template for a WallRun module script using Aligners.

local WallRunModule = {}
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Configuration variables. You must define these!
local Wall_Offset = 2 -- Distance from the wall the character should be
local WallRunSpeed = 30 -- Speed at which the character wall runs
local WallGravity = 40 -- The reduced gravity while wall running

-- Caching for player and connections.
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local RootPart = character:WaitForChild("HumanoidRootPart")
local Humanoid = character:WaitForChild("Humanoid")
local connections = {}

-- A placeholder for your animations. Load these in a separate script or at the top.
local WallRunAnims = {
	Left = nil, -- Load your wall run left animation here
	Right = nil, -- Load your wall run right animation here
}

local function raycastWall()
	-- The character's position and forward/right vectors are used as the raycast's origin and direction.
	local origin = RootPart.Position
	local rightDirection = RootPart.CFrame.RightVector

	-- Define the options for the raycasts using the M.params function from your module.
	local raycastOptions = {
		maxDistance = 3, -- Adjust this value to control how far the raycast goes
		ignore = {character}, -- Ignore the character itself to prevent self-intersection
	}

	-- Cast a ray to the right side of the character.
	local rightRaycast = M.cast({
		origin = origin,
		direction = rightDirection,
		maxDistance = raycastOptions.maxDistance,
		ignore = raycastOptions.ignore,
	})

	-- Cast a ray to the left side of the character.
	local leftRaycast = M.cast({
		origin = origin,
		direction = -rightDirection,
		maxDistance = raycastOptions.maxDistance,
		ignore = raycastOptions.ignore,
	})

	-- Return the results based on which raycast hit a wall.
	if rightRaycast then
		-- Return the RaycastResult, the direction ("Right"), and a numerical direction (1 for right).
		return rightRaycast, "Right", 1
	elseif leftRaycast then
		-- Return the RaycastResult, the direction ("Left"), and a numerical direction (-1 for left).
		return leftRaycast, "Left", -1
	else
		-- If no wall is detected, return nil.
		return nil
	end
end

-- Private function to get or create a physics attachment.
local function getOrCreateAttachment(part, name)
	local attachment = part:FindFirstChild(name)
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = name
		attachment.Parent = part
	end
	return attachment
end

-- Public function to begin the wall run.
function WallRunModule:WallRunBegin()
	-- Check if a wall run is already in progress.
	if connections[player] then return end

	-- Initial raycast to find the wall.
	local hit, Direction, wallDirVal = raycastWall()
	if not hit then return end

	-- Get the attachment for our aligners.
	local wallAttachment = getOrCreateAttachment(RootPart, "WallRunAttachment")

	-- Create the physics aligners and force.
	local alignPosition = Instance.new("AlignPosition")
	alignPosition.Attachment0 = wallAttachment
	alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPosition.RigidityEnabled = true
	alignPosition.MaxForce = 100000
	alignPosition.MaxVelocity = 100
	alignPosition.Responsiveness = 200
	alignPosition.Parent = RootPart

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Attachment0 = wallAttachment
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.RigidityEnabled = true
	alignOrientation.MaxTorque = 100000
	alignOrientation.Responsiveness = 200
	alignOrientation.Parent = RootPart

	local vectorForce = Instance.new("VectorForce")
	vectorForce.Attachment0 = wallAttachment
	vectorForce.RelativeTo = Enum.ActuatorRelativeTo.World
	vectorForce.ApplyAtCenterOfMass = true
	vectorForce.Parent = RootPart

	-- Store original gravity to restore later.
	local originalGravity = workspace.Gravity

	-- Play the correct animation.
	if WallRunAnims[Direction] then
		WallRunAnims[Direction]:Play()
	end

	-- Prepare the character.
	Humanoid.PlatformStand = true
	Humanoid.AutoRotate = false
	workspace.Gravity = WallGravity

	-- Main wall run loop.
	connections[player] = RunService.RenderStepped:Connect(function()
		local currentHit, currentDirection = raycastWall()

		-- Check if the character has left the wall.
		if not currentHit or currentDirection ~= Direction then
			-- Clean up and end the wall run.
			self:WallRunEnd()
			return
		end

		-- Use the provided forum logic to update the aligners.
		local flatLook = Vector3.new(RootPart.CFrame.LookVector.X, 0, RootPart.CFrame.LookVector.Z).Unit

		alignPosition.Position = currentHit.Position + currentHit.Normal * Wall_Offset + flatLook * WallRunSpeed
		alignOrientation.CFrame = CFrame.lookAt(RootPart.Position, RootPart.Position + currentHit.Normal) * CFrame.Angles(0, math.rad(90 * wallDirVal), 0)

		-- Apply downward force to simulate gravity.
		vectorForce.Force = Vector3.new(0, -workspace.Gravity * Humanoid.Mass, 0)
	end)
end

-- Public function to end the wall run.
function WallRunModule:WallRunEnd()
	if not connections[player] then return end

	-- Stop animations and restore character state.
	for _, anim in pairs(WallRunAnims) do
		if anim then anim:Stop() end
	end

	Humanoid.PlatformStand = false
	Humanoid.AutoRotate = true
	workspace.Gravity = workspace.Gravity -- Revert to default gravity.

	-- Clean up physics objects.
	for _, child in ipairs(RootPart:GetChildren()) do
		if child:IsA("AlignPosition") or child:IsA("AlignOrientation") or child:IsA("VectorForce") or child:IsA("Attachment") then
			child:Destroy()
		end
	end

	-- Disconnect the RenderStepped loop.
	connections[player]:Disconnect()
	connections[player] = nil
end

return WallRunModule
