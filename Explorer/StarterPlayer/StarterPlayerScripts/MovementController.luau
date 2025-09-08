--!strict
-- ModuleScript: MovementController
-- Location: StarterPlayer/StarterPlayerScripts/MovementController (ModuleScript)
-- Purpose: Client-side movement system (WASD + auto-sprint + dash + slide + shift-lock)
--          Acts as the single owner of input, animations, camera offset, HRP rotation,
--          and movement actuators (LinearVelocity).
-- Notes:
--   - Place this ModuleScript in StarterPlayer/StarterPlayerScripts so it runs on the client.
--   - Start it from a tiny LocalScript that calls require(...):Start(flags, tuningOverride)
--   - Tuning lookup: ReplicatedStorage/Shared/Config/Tuning (optional). If not present defaults used.
--   - Optional sound: SoundService.ShiftLockSound (will be pcall-played if present)
--   - Animations: ReplicatedStorage.Animations.{FrontWalkAnim, LeftWalkAnim, RightWalkAnim, BackWalkAnim}
--   - Logging: Toggle LOG flag below to see debug prints.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- Module table
local M = {}
M.__index = M

-- Debug toggle
local LOG = true
local function log(...: any)
	if LOG then
		print("[MovementController]", ...)
	end
end

-- Default tuning (will be overridden by Tuning module if found)
local DEFAULTS = {
	Movement = {
		Run = 15,
		Sprint = 30,
		AutoSprintHold = 1.25,
		MomentumCarryFactor = 0.9,
		MinCarrySpeed = 16,
		MaxCarrySpeed = 60
	},
	Dash = {
		Charges = 3,
		Recharge = 2.0,
		Impulse = 55.0,
		Duration = 0.18
	},
	Slide = {
		FrictionTime = 0.8,
		ExitSpeed = 10.0,
		MinSpeed = 16.0
	},
	ShiftLock = {
		CameraOffset = Vector3.new(2, 0, 0),
		CameraTween = TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut),
		MouseIconDefault = "rbxassetid://129875024",
		MouseIconShift = "rbxassetid://10393593823"
	},
	Animation = {
		FadeTime = 0.3
	}
}

-- Helper: safe require for optional tuning
local function tryRequireTuning()
	local ok, tuning = pcall(function()
		local Shared = ReplicatedStorage:FindFirstChild("Shared")
		if not Shared then
			return nil
		end
		local Config = Shared:FindFirstChild("Config")
		if not Config then
			return nil
		end
		local Tuning = Config:FindFirstChild("Tuning")
		if Tuning then
			return require(Tuning)
		end
		return nil
	end)
	if ok and tuning then
		return tuning
	end
	return nil
end

-- Constructor-ish: create a controller instance (per player)
function M.new()
	local self = setmetatable({}, M)

	-- runtime references
	self.character = player.Character :: Model? -- may be nil at creation
	self.humanoid = nil :: Humanoid?
	self.hrp = nil :: BasePart?

	-- tuning (populated in Start)
	self.tuning = DEFAULTS

	-- movement state
	self.moveX = 0
	self.moveZ = 0
	self.isSprinting = false
	self.forwardHeldTime = 0

	-- dash
	self.dashCharges = 0
	self.dashMax = 0
	self.dashRecharge = 0.0
	self.dashImpulse = 0.0
	self.dashDuration = 0.0

	-- slide
	self.isSliding = false
	self.slideLV = nil :: LinearVelocity?
	self.slideStart = 0.0
	self.slideFrictionTime = 0.8
	self.slideExitSpeed = 10.0
	self.slideMinSpeed = 16.0
	self.slideConn = nil :: RBXScriptConnection?

	-- carry momentum
	self.carry = { factor = 0.9, min = 16, max = 60 }

	-- shift-lock
	self.shiftLockEnabled = true
	self.rotationConnection = nil :: RBXScriptConnection?
	self.cameraTweenInfo = DEFAULTS.ShiftLock.CameraTween
	self.cameraOffsetVec = DEFAULTS.ShiftLock.CameraOffset
	self.mouseIconDefault = DEFAULTS.ShiftLock.MouseIconDefault
	self.mouseIconShift = DEFAULTS.ShiftLock.MouseIconShift
	self.animationFade = DEFAULTS.Animation.FadeTime

	-- animation tracks (populated at bindCharacter)
	self.frontWalkAnimation = nil :: AnimationTrack?
	self.leftWalkAnimation = nil :: AnimationTrack?
	self.rightWalkAnimation = nil :: AnimationTrack?
	self.backWalkAnimation = nil :: AnimationTrack?

	-- key tracking
	self.activeKeys = { W = false, A = false, S = false, D = false }

	-- connections
	self.inputBeganConn = nil :: RBXScriptConnection?
	self.inputEndedConn = nil :: RBXScriptConnection?

	return self
end

-- Utility: set mouse icon best-effort
function M:_setMouseIcon(id: string)
	task.spawn(function()
		pcall(function() UIS.MouseIcon = id end)
		pcall(function()
			local m = player:GetMouse()
			if m then
				m.Icon = id
			end
		end)
	end)
end

-- Util: bind a character (waitSafe calls inside)
function M:_bindCharacter(charModel: Model)
	self.character = charModel
	-- attempt non-blocking find first
	self.humanoid = charModel:FindFirstChildOfClass("Humanoid") or charModel:WaitForChild("Humanoid")
	self.hrp = charModel:FindFirstChild("HumanoidRootPart") or charModel:WaitForChild("HumanoidRootPart")

	-- load animations safely
	pcall(function()
		local anims = ReplicatedStorage:WaitForChild("Animations")
		if self.humanoid then
			self.frontWalkAnimation = self.humanoid:LoadAnimation(anims:WaitForChild("FrontWalkAnim"))
			self.leftWalkAnimation = self.humanoid:LoadAnimation(anims:WaitForChild("LeftWalkAnim"))
			self.rightWalkAnimation = self.humanoid:LoadAnimation(anims:WaitForChild("RightWalkAnim"))
			self.backWalkAnimation = self.humanoid:LoadAnimation(anims:WaitForChild("BackWalkAnim"))
		end
	end)

	-- ensure CameraOffset matches desired state immediately
	if self.humanoid then
		self.humanoid.CameraOffset = self.shiftLockEnabled and self.cameraOffsetVec or Vector3.zero
	end

	log("Character bound:", charModel)
end

function M:_unbindCharacter()
	-- end slide gracefully if needed
	if self.isSliding then
		self:_endSlide()
	end
	-- disconnect rotation
	if self.rotationConnection then
		pcall(function() self.rotationConnection:Disconnect() end)
		self.rotationConnection = nil
	end
	-- reset references
	self.character = nil
	self.humanoid = nil
	self.hrp = nil

	-- restore mouse / behavior
	pcall(function() UIS.MouseBehavior = Enum.MouseBehavior.Default end)
	pcall(function() self:_setMouseIcon(self.mouseIconDefault) end)

	log("Character unbound")
end

-- LinearVelocity helpers
function M:_getOrCreateAttachment(name: string): Attachment
	if not self.hrp then
		error("getOrCreateAttachment: hrp nil")
	end
	local att = self.hrp:FindFirstChild(name) :: Attachment?
	if not att then
		att = Instance.new("Attachment")
		att.Name = name
		att.Parent = self.hrp
	end
	return att
end

function M:_applyLV(name: string, dir: Vector3, speed: number, duration: number?): LinearVelocity?
	if not self.hrp then return nil end
	local att = self:_getOrCreateAttachment("RC_" .. name .. "Att")
	local old = self.hrp:FindFirstChild("RC_" .. name)
	if old and old:IsA("LinearVelocity") then
		old:Destroy()
	end
	local lv = Instance.new("LinearVelocity")
	lv.Name = "RC_" .. name
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = dir.Unit * speed
	lv.MaxForce = 1e6
	lv.Parent = self.hrp
	if duration and duration > 0 then
		task.delay(duration, function()
			if lv and lv.Parent then
				lv:Destroy()
			end
		end)
	end
	return lv
end

-- Movement helpers (camera-relative)
function M:_worldForward(): Vector3
	local cam = workspace.CurrentCamera
	if not cam then return Vector3.new(0,0,-1) end
	local v = cam.CFrame.LookVector
	return Vector3.new(v.X, 0, v.Z).Unit
end

function M:_worldDashDir(): Vector3
	local cam = workspace.CurrentCamera
	local camCF = cam and cam.CFrame or CFrame.new()
	local f = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
	local r = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z)
	local v = r * self.moveX + f * -self.moveZ
	if v.Magnitude < 0.05 then
		v = f
	end
	return v.Unit
end

function M:_currentLocalVector(): Vector3
	return Vector3.new(self.moveX, 0, self.moveZ)
end

function M:_planarSpeed(): number
	if not self.hrp then return 0 end
	local v = self.hrp.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

-- Sprint update
function M:_updateSprint(dt: number)
	if self.moveZ < -0.7 then
		self.forwardHeldTime += dt
	else
		self.forwardHeldTime = 0
	end
	self.isSprinting = (self.forwardHeldTime >= (self.tuning.Movement.AutoSprintHold or DEFAULTS.Movement.AutoSprintHold))
end

-- Dash
function M:_canDash(): boolean
	return self.dashCharges > 0 and self.humanoid ~= nil and self.hrp ~= nil and not self.isSliding
end

function M:_scheduleDashRecharge()
	task.delay(self.dashRecharge, function()
		if self.dashCharges < self.dashMax then
			self.dashCharges += 1
			log("Dash recharge ->", self.dashCharges)
		end
	end)
end

function M:_performDash()
	if not self:_canDash() then return end
	self.dashCharges -= 1
	self:_scheduleDashRecharge()
	local dir = self:_worldDashDir()
	self:_applyLV("DashVelocity", dir, self.dashImpulse, self.dashDuration)
	log("Dash performed. charges=", self.dashCharges)
end

-- Slide
function M:_endSlide()
	if not self.isSliding then return end
	self.isSliding = false
	log("endSlide")
	if self.hrp then
		local v = self.hrp.AssemblyLinearVelocity
		local planar = Vector3.new(v.X, 0, v.Z)
		local spd = planar.Magnitude
		if spd > 0 then
			local keep = math.clamp(spd * (self.carry.factor or 0.9), self.carry.min or 16, self.carry.max or 60)
			local dir = planar.Magnitude > 0 and planar.Unit or self:_worldForward()
			self.hrp.AssemblyLinearVelocity = Vector3.new(dir.X * keep, v.Y, dir.Z * keep)
			log("carry keep:", keep)
		end
	end
	if self.slideConn then
		pcall(function() self.slideConn:Disconnect() end)
		self.slideConn = nil
	end
	if self.slideLV and self.slideLV.Parent then
		self.slideLV:Destroy()
	end
	self.slideLV = nil
end

function M:_tryStartSlide()
	if self.isSliding or not self.hrp then return end
	if self.humanoid then
		local st = self.humanoid:GetState()
		if not (st == Enum.HumanoidStateType.Running or st == Enum.HumanoidStateType.RunningNoPhysics or st == Enum.HumanoidStateType.Landed) then
			log("tryStartSlide aborted: not grounded", st)
			return
		end
	end
	local spd = self:_planarSpeed()
	if spd < (self.slideMinSpeed or DEFAULTS.Slide.MinSpeed) then
		log("tryStartSlide aborted: speed too low", spd)
		return
	end
	self.isSliding = true
	self.slideStart = os.clock()
	local dir = self:_worldDashDir()
	local initialSpeed = math.max(spd, self.slideExitSpeed)
	self.slideLV = self:_applyLV("SlideVelocity", dir, initialSpeed, 0)
	local tFric = self.slideFrictionTime
	local exitV = self.slideExitSpeed
	log("Started slide at speed", initialSpeed)
	self.slideConn = RunService.RenderStepped:Connect(function()
		if not self.isSliding or not self.slideLV then return end
		local alpha = math.clamp((os.clock() - self.slideStart) / math.max(0.01, tFric), 0, 1)
		local speedNow = initialSpeed + (exitV - initialSpeed) * alpha
		local steer = self:_worldDashDir()
		self.slideLV.VectorVelocity = steer * speedNow
		if alpha >= 1 then
			self:_endSlide()
		end
	end)
end

-- Shift-lock rotate/hook
function M:_rotateCharacterToCamera()
	if not self.hrp then return end
	local camera = workspace.CurrentCamera
	if not camera then return end
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude <= 0.001 then return end
	local target = CFrame.new(self.hrp.Position, self.hrp.Position + flat.Unit)
	self.hrp.CFrame = target
end

function M:_connectRotation()
	if self.rotationConnection then
		pcall(function() self.rotationConnection:Disconnect() end)
		self.rotationConnection = nil
	end
	self.rotationConnection = RunService.RenderStepped:Connect(function()
		if not player or not player.Character or not self.hrp then
			if self.rotationConnection then
				pcall(function() self.rotationConnection:Disconnect() end)
				self.rotationConnection = nil
			end
			return
		end
		self:_rotateCharacterToCamera()
	end)
end

function M:_disconnectRotation()
	if self.rotationConnection then
		pcall(function() self.rotationConnection:Disconnect() end)
		self.rotationConnection = nil
	end
end

function M:_tweenCameraOffset(enable: boolean)
	if not self.humanoid then return end
	local target = enable and self.cameraOffsetVec or Vector3.zero
	local ok, tween = pcall(function()
		return TweenService:Create(self.humanoid, self.cameraTweenInfo, { CameraOffset = target })
	end)
	if ok and tween then
		pcall(function() tween:Play() end)
	end
end

function M:_enableShiftLock(enabled: boolean)
	-- optional sound
	if SoundService:FindFirstChild("ShiftLockSound") then
		pcall(function() SoundService.ShiftLockSound:Play() end)
	end
	self.shiftLockEnabled = enabled
	if self.shiftLockEnabled then
		UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
		self:_setMouseIcon(self.mouseIconShift)
		self:_tweenCameraOffset(true)
		self:_disconnectRotation()
		self:_connectRotation()
		log("ShiftLock enabled")
	else
		UIS.MouseBehavior = Enum.MouseBehavior.Default
		self:_setMouseIcon(self.mouseIconDefault)
		self:_tweenCameraOffset(false)
		self:_disconnectRotation()
		log("ShiftLock disabled")
	end
end

-- Animation helpers
function M:_playAnim(track: AnimationTrack?)
	if not track then return end
	pcall(function() track:Play(self.animationFade) end)
end
function M:_stopAnim(track: AnimationTrack?)
	if not track then return end
	pcall(function() track:Stop(self.animationFade) end)
end

-- Input handlers
function M:_onInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
	local kc = input.KeyCode

	if kc == Enum.KeyCode.V then
		self:_enableShiftLock(not self.shiftLockEnabled)
		log("V pressed -> shiftLock:", self.shiftLockEnabled)
		return
	end

	if kc == Enum.KeyCode.W then
		self.moveZ = -1
		self.activeKeys.W = true
		self:_playAnim(self.frontWalkAnimation)
	elseif kc == Enum.KeyCode.S then
		self.moveZ = 1
		self.activeKeys.S = true
		self:_playAnim(self.backWalkAnimation)
	elseif kc == Enum.KeyCode.A then
		self.moveX = -1
		self.activeKeys.A = true
		self:_playAnim(self.leftWalkAnimation)
	elseif kc == Enum.KeyCode.D then
		self.moveX = 1
		self.activeKeys.D = true
		self:_playAnim(self.rightWalkAnimation)
	elseif kc == Enum.KeyCode.Space then
		if self.isSliding and self.hrp then
			local v = self.hrp.AssemblyLinearVelocity
			local planar = Vector3.new(v.X, 0, v.Z)
			local spd = planar.Magnitude
			if spd > 0 then
				local keep = math.clamp(spd * (self.carry.factor or 0.9), self.carry.min or 16, self.carry.max or 60)
				local dir = planar.Magnitude > 0 and planar.Unit or self:_worldForward()
				self.hrp.AssemblyLinearVelocity = Vector3.new(dir.X * keep, v.Y, dir.Z * keep)
			end
			self:_endSlide()
		end
		if self.humanoid then
			self.humanoid.Jump = true
		end
	elseif kc == Enum.KeyCode.Q then
		self:_performDash()
	elseif kc == Enum.KeyCode.C then
		self:_tryStartSlide()
	end
end

function M:_onInputEnded(input: InputObject, gameProcessed: boolean)
	if gameProcessed then return end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
	local kc = input.KeyCode

	if kc == Enum.KeyCode.W and self.moveZ == -1 then
		self.moveZ = 0
		self.activeKeys.W = false
		self:_stopAnim(self.frontWalkAnimation)
	elseif kc == Enum.KeyCode.S and self.moveZ == 1 then
		self.moveZ = 0
		self.activeKeys.S = false
		self:_stopAnim(self.backWalkAnimation)
	elseif kc == Enum.KeyCode.A and self.moveX == -1 then
		self.moveX = 0
		self.activeKeys.A = false
		self:_stopAnim(self.leftWalkAnimation)
	elseif kc == Enum.KeyCode.D and self.moveX == 1 then
		self.moveX = 0
		self.activeKeys.D = false
		self:_stopAnim(self.rightWalkAnimation)
	end

	if self.activeKeys.W and self.activeKeys.S then
		self:_stopAnim(self.frontWalkAnimation)
		self:_stopAnim(self.backWalkAnimation)
	end
	if self.activeKeys.A and self.activeKeys.D then
		self:_stopAnim(self.leftWalkAnimation)
		self:_stopAnim(self.rightWalkAnimation)
	end
end

-- Main Render loop (handles movement application)
function M:_renderStep(dt: number)
	if not self.humanoid then return end
	if not self.isSliding then
		self:_updateSprint(dt)
		local runSpd = self.tuning.Movement.Run or DEFAULTS.Movement.Run
		local sprintSpd = self.tuning.Movement.Sprint or DEFAULTS.Movement.Sprint
		self.humanoid.WalkSpeed = self.isSprinting and sprintSpd or runSpd
		local wish = self:_currentLocalVector()
		if wish.Magnitude > 0 then
			self.humanoid:Move(wish, true)
		else
			self.humanoid:Move(Vector3.zero, true)
		end
	end
end

-- Public Start: flags optional, tuningOverride optional (table)
function M:Start(_flags: table?, tuningOverride: table?)
	-- Load tuning from override or RS Shared Config Tuning
	if tuningOverride then
		self.tuning = tuningOverride
	else
		local found = tryRequireTuning()
		if found then
			self.tuning = found
		else
			self.tuning = DEFAULTS
		end
	end

	-- Movement tuning
	local mv = self.tuning.Movement or DEFAULTS.Movement
	local runSpd = mv.Run or DEFAULTS.Movement.Run
	local sprintSpd = mv.Sprint or DEFAULTS.Movement.Sprint
	self.forwardHoldThreshold = mv.AutoSprintHold or DEFAULTS.Movement.AutoSprintHold
	self.carry.factor = mv.MomentumCarryFactor or DEFAULTS.Movement.MomentumCarryFactor
	self.carry.min = mv.MinCarrySpeed or DEFAULTS.Movement.MinCarrySpeed
	self.carry.max = mv.MaxCarrySpeed or DEFAULTS.Movement.MaxCarrySpeed

	-- Dash tuning
	local d = self.tuning.Dash or DEFAULTS.Dash
	self.dashMax = d.Charges or DEFAULTS.Dash.Charges
	self.dashCharges = self.dashMax
	self.dashRecharge = d.Recharge or DEFAULTS.Dash.Recharge
	self.dashImpulse = d.Impulse or DEFAULTS.Dash.Impulse
	self.dashDuration = d.Duration or DEFAULTS.Dash.Duration

	-- Slide tuning
	local s = self.tuning.Slide or DEFAULTS.Slide
	self.slideFrictionTime = s.FrictionTime or DEFAULTS.Slide.FrictionTime
	self.slideExitSpeed = s.ExitSpeed or DEFAULTS.Slide.ExitSpeed
	self.slideMinSpeed = s.MinSpeed or DEFAULTS.Slide.MinSpeed

	-- ShiftLock tuning
	self.cameraTweenInfo = self.tuning.ShiftLock and self.tuning.ShiftLock.CameraTween or DEFAULTS.ShiftLock.CameraTween
	self.cameraOffsetVec = self.tuning.ShiftLock and self.tuning.ShiftLock.CameraOffset or DEFAULTS.ShiftLock.CameraOffset
	self.mouseIconDefault = self.tuning.ShiftLock and self.tuning.ShiftLock.MouseIconDefault or DEFAULTS.ShiftLock.MouseIconDefault
	self.mouseIconShift = self.tuning.ShiftLock and self.tuning.ShiftLock.MouseIconShift or DEFAULTS.ShiftLock.MouseIconShift

	-- Animation fade
	self.animationFade = (self.tuning.Animation and self.tuning.Animation.FadeTime) or DEFAULTS.Animation.FadeTime

	-- Bind initial character if present
	if player.Character then
		self:_bindCharacter(player.Character)
	end
	player.CharacterAdded:Connect(function(c) self:_bindCharacter(c) end)
	player.CharacterRemoving:Connect(function() self:_endSlide(); self:_unbindCharacter(); end)

	-- Input hooks (single owner)
	self.inputBeganConn = UIS.InputBegan:Connect(function(i, gp) self:_onInputBegan(i, gp) end)
	self.inputEndedConn = UIS.InputEnded:Connect(function(i, gp) self:_onInputEnded(i, gp) end)

	-- Render stepped hook
	RunService.RenderStepped:Connect(function(dt) self:_renderStep(dt) end)

	-- Initialize mouse icon and shift-lock state
	self:_setMouseIcon(self.mouseIconDefault)
	self:_enableShiftLock(self.shiftLockEnabled)

	log("MovementController started. run:", runSpd, "sprint:", sprintSpd, "shiftLock:", self.shiftLockEnabled)
end

-- Optional Stop to disconnect listeners (safe cleanup)
function M:Stop()
	if self.inputBeganConn then
		pcall(function() self.inputBeganConn:Disconnect() end)
		self.inputBeganConn = nil
	end
	if self.inputEndedConn then
		pcall(function() self.inputEndedConn:Disconnect() end)
		self.inputEndedConn = nil
	end
	if self.rotationConnection then
		pcall(function() self.rotationConnection:Disconnect() end)
		self.rotationConnection = nil
	end
	if self.slideConn then
		pcall(function() self.slideConn:Disconnect() end)
		self.slideConn = nil
	end
	self:_unbindCharacter()
	log("MovementController stopped")
end

return M
