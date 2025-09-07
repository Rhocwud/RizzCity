--!strict
-- StarterPlayerScripts/ShiftLockStarter (LocalScript)
-- Enforce shift-lock at start, allow toggling with V, adjust camera offset with a tween,
-- handle respawns cleanly, and avoid yielding inside RenderStepped.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer

local TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut)

-- Runtime state
local character = player.Character -- may be nil until spawned
local humanoid = nil
local hrp = nil

local renderConnection: RBXScriptConnection? = nil
local shiftLockEnabled = true -- start with shift lock enabled

-- Icons
local ICON_DEFAULT = "rbxassetid://3128012693"
local ICON_SHIFTLOCK = "rbxassetid://10393593823"

-- Safe helper to set mouse icon (tries multiple APIs)
local function setMouseIcon(id: string)
	task.spawn(function() -- best-effort, don't block
		pcall(function() UserInputService.MouseIcon = id end)
		pcall(function()
			local m = player:GetMouse()
			if m then
				m.Icon = id
			end
		end)
	end)
end

-- Rotate the HumanoidRootPart to face the camera's look direction (flat on Y)
local function rotateCharacterToCamera()
	if not hrp then return end
	local camera = workspace.CurrentCamera
	if not camera then return end

	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude <= 0.001 then return end

	local target = CFrame.new(hrp.Position, hrp.Position + flat.Unit)
	hrp.CFrame = target
end

-- Tween the humanoid.CameraOffset (if humanoid exists)
local function tweenCameraOffset(enable: boolean)
	if not humanoid then return end
	local target = enable and Vector3.new(2, 0, 0) or Vector3.new(0, 0, 0)
	local ok, tween = pcall(function()
		return TweenService:Create(humanoid, TWEEN_INFO, { CameraOffset = target })
	end)
	if ok and tween then
		pcall(function() tween:Play() end)
	end
end

-- Disconnect the RenderStepped handler safely
local function disconnectRender()
	if renderConnection then
		pcall(function() renderConnection:Disconnect() end)
		renderConnection = nil
	end
end

-- Enable or disable the shift-lock behavior
local function enableShiftLock(enabled: boolean)
	-- Play optional sound if present
	if SoundService:FindFirstChild("ShiftLockSound") then
		pcall(function() SoundService.ShiftLockSound:Play() end)
	end

	if enabled then
		-- Lock the mouse to center, change icon, tween offset, start rotating HRP on RenderStepped
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		setMouseIcon(ICON_SHIFTLOCK)

		tweenCameraOffset(true)
		disconnectRender()

		renderConnection = RunService.RenderStepped:Connect(function()
			-- guard: if character disappears mid-frame, disconnect
			if not player or not player.Character or not hrp then
				disconnectRender()
				return
			end
			rotateCharacterToCamera()
		end)
	else
		-- Restore default mouse behavior and icon, stop rotation, tween offset back
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		setMouseIcon(ICON_DEFAULT)

		tweenCameraOffset(false)
		disconnectRender()
	end
end

-- Called when a new character spawns
local function onCharacterAdded(c: Model)
	character = c
	humanoid = nil
	hrp = nil

	-- Wait for Humanoid and HumanoidRootPart, but use FindFirstChild first to avoid unnecessary waits
	humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	hrp = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)

	-- If we couldn't get them (rare) bail gracefully
	if not humanoid or not hrp then
		-- ensure we are in a consistent state
		humanoid = nil
		hrp = nil
		disconnectRender()
		return
	end

	-- Ensure CameraOffset matches desired state immediately (avoid visual jump)
	humanoid.CameraOffset = shiftLockEnabled and Vector3.new(2, 0, 0) or Vector3.new(0, 0, 0)

	-- Re-apply the shift-lock behaviour for the new character
	enableShiftLock(shiftLockEnabled)
end

-- Cleanup when character is removed
local function onCharacterRemoving()
	disconnectRender()
	character = nil
	humanoid = nil
	hrp = nil

	-- restore mouse behavior just in case
	pcall(function() UserInputService.MouseBehavior = Enum.MouseBehavior.Default end)
	pcall(function() setMouseIcon(ICON_DEFAULT) end)
end

-- Wire up character events (initial and respawn)
if player then
	if player.Character then
		-- handle current character immediately
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
	player.CharacterRemoving:Connect(onCharacterRemoving)
end

-- Ensure shift-lock applied at start
enableShiftLock(shiftLockEnabled)

-- Toggle with V key (ignore if typing / game processed)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.V then
		shiftLockEnabled = not shiftLockEnabled
		enableShiftLock(shiftLockEnabled)
	end
end)
