local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()

local TS = game:GetService("TweenService")
local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local SS = game:GetService("SoundService")

local TI = TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut)

local renderConnection = nil
local shiftLockEnabled = false

UIS.MouseIcon = "rbxassetid://129875024"

local function rotateCharacterToCamera()
	local character = player.Character
	local camera = game.Workspace.CurrentCamera
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if rootPart then
		local lookVector = camera.CFrame.LookVector
		local flatLookVector = Vector3.new(lookVector.X, 0, lookVector.Z).Unit

		local targetCFrame = CFrame.new(rootPart.Position, rootPart.Position + flatLookVector)
		rootPart.CFrame = targetCFrame
	end
end

local function tweenOffset(bool)
	local camera = workspace.CurrentCamera
	local humanoidRootPart = char:WaitForChild("HumanoidRootPart")
	
	SS.ShiftLockSound:Play()
	if bool then
		UIS.MouseBehavior = Enum.MouseBehavior.Default
		UIS.MouseIcon = "rbxassetid://10393593823"

		-- Tween Our Camera Offet
		local TG = {CameraOffset = Vector3.new(2,0,0)}
		local tween = TS:Create(char.Humanoid, TI, TG)
		tween:Play()

		if renderConnection then renderConnection:Disconnect() end
		
		renderConnection = RS.RenderStepped:Connect(function()
			UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
			task.wait()
			rotateCharacterToCamera()
		end)
	else
		UIS.MouseBehavior = Enum.MouseBehavior.Default
		UIS.MouseIcon = "rbxassetid://129875024"

		-- Tween Our Camera Offet
		local TG = {CameraOffset = Vector3.new(0,0,0)}
		local tween = TS:Create(char.Humanoid, TI, TG)
		tween:Play()

		if renderConnection then renderConnection:Disconnect() end
	end
end

UIS.InputBegan:Connect(function(input, gps)
	if gps then return end
	if input.KeyCode == Enum.KeyCode.V then
		shiftLockEnabled = not shiftLockEnabled
		tweenOffset(shiftLockEnabled)
	end
end)
