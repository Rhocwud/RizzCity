--!strict

--====================================================--
--  Script: [MovementController]
--  Location: [StarterPlayer/StarterPlayerScripts/]
--  Version: 1.0.0
--  Last Updated: 2025-09-06
--  Author: Rhocwud Games
--
--  Description:
--      [WASD + Auto-sprint + Dash (Q) + Slide (C) with momentum carry]
--		[Reads knobs from Shared/Config/Tuning.lua]
--  Change Log:
--      v1.0.0 - Initial version
--
--====================================================--

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local char: Model?
local hum: Humanoid?
local hrp: BasePart?

-- Tuning + state
local tuning: any
local AUTO_HOLD = 1.25
local moveX, moveZ = 0, 0 -- camera-local (+X right, -Z forward)
local isSprinting = false
local forwardHeldTime = 0

-- Dash
local dashCharges = 0
local dashMax = 0
local dashRecharge = 2.0
local dashImpulse = 55.0
local dashDuration = 0.18

-- Slide
local isSliding = false
local slideLV: LinearVelocity? = nil
local slideStart = 0.0
local slideFrictionTime = 0.8
local slideExitSpeed = 10.0
local slideMinSpeed = 16.0
local slideConn: RBXScriptConnection? = nil

-- Carry (momentum)
local carry = { factor = 0.9, min = 16, max = 60 }

-- Utils
local function getChar()
    char = player.Character or player.CharacterAdded:Wait()
    hum = char:WaitForChild("Humanoid") :: Humanoid
    hrp = char:WaitForChild("HumanoidRootPart") :: BasePart
end

local function grounded(): boolean
    if not hum then
        return false
    end
    local st = hum:GetState()
    return st == Enum.HumanoidStateType.Running
        or st == Enum.HumanoidStateType.RunningNoPhysics
        or st == Enum.HumanoidStateType.Landed
end

local function currentLocalVector(): Vector3
    return Vector3.new(moveX, 0, moveZ) -- local to camera
end

local function worldForward(): Vector3
    local camCF = workspace.CurrentCamera.CFrame
    return Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z).Unit
end

local function worldDashDir(): Vector3
    local camCF = workspace.CurrentCamera.CFrame
    local f = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
    local r = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z)
    local v = r * moveX + f * -moveZ
    if v.Magnitude < 0.05 then
        v = f
    end
    return v.Unit
end

local function planarSpeed(): number
    if not hrp then
        return 0
    end
    local v = hrp.AssemblyLinearVelocity
    return Vector3.new(v.X, 0, v.Z).Magnitude
end

local function updateSprint(dt: number)
    if moveZ < -0.7 then
        forwardHeldTime += dt
    else
        forwardHeldTime = 0
    end
    isSprinting = (forwardHeldTime >= AUTO_HOLD)
end

-- Attachments / LinearVelocity helpers
local function getOrCreateAttachment(name: string): Attachment
    local att = hrp and hrp:FindFirstChild(name) :: Attachment
    if not att and hrp then
        att = Instance.new("Attachment")
        att.Name = name
        att.Parent = hrp
    end
    return att
end

local function applyLV(name: string, dir: Vector3, speed: number, duration: number?): LinearVelocity?
    if not hrp then
        return nil
    end
    local att = getOrCreateAttachment("RC_" .. name .. "Att")
    local old = hrp:FindFirstChild("RC_" .. name)
    if old and old:IsA("LinearVelocity") then
        old:Destroy()
    end
    local lv = Instance.new("LinearVelocity")
    lv.Name = "RC_" .. name
    lv.Attachment0 = att
    lv.RelativeTo = Enum.ActuatorRelativeTo.World
    lv.VectorVelocity = dir.Unit * speed
    lv.MaxForce = 1e6
    lv.Parent = hrp
    if duration and duration > 0 then
        task.delay(duration, function()
            if lv then
                lv:Destroy()
            end
        end)
    end
    return lv
end

-- Dash
local function canDash(): boolean
    return dashCharges > 0 and hum ~= nil and hrp ~= nil and not isSliding
end

local function scheduleDashRecharge()
    task.delay(dashRecharge, function()
        if dashCharges < dashMax then
            dashCharges += 1
        end
    end)
end

local function performDash()
    if not canDash() then
        return
    end
    dashCharges -= 1
    scheduleDashRecharge()
    local dir = worldDashDir()
    applyLV("DashVelocity", dir, dashImpulse, dashDuration)
end

-- Slide
local function endSlide()
    if not isSliding then
        return
    end
    isSliding = false
    -- momentum carry on end
    if hrp then
        local v = hrp.AssemblyLinearVelocity
        local planar = Vector3.new(v.X, 0, v.Z)
        local spd = planar.Magnitude
        if spd > 0 then
            local keep = math.clamp(spd * (carry.factor or 0.9), carry.min or 16, carry.max or 60)
            local dir = planar.Magnitude > 0 and planar.Unit or worldForward()
            hrp.AssemblyLinearVelocity = Vector3.new(dir.X * keep, v.Y, dir.Z * keep)
        end
    end
    if slideConn then
        slideConn:Disconnect()
        slideConn = nil
    end
    if slideLV and slideLV.Parent then
        slideLV:Destroy()
    end
    slideLV = nil
end

local function tryStartSlide()
    if isSliding or not grounded() or not hrp then
        return
    end
    local spd = planarSpeed()
    if spd < (slideMinSpeed or 16) then
        return
    end
    isSliding = true
    slideStart = os.clock()
    local dir = worldDashDir()
    local initialSpeed = math.max(spd, slideExitSpeed)
    slideLV = applyLV("SlideVelocity", dir, initialSpeed, 0)
    local tFric = slideFrictionTime
    local exitV = slideExitSpeed
    slideConn = RunService.RenderStepped:Connect(function()
        if not isSliding or not slideLV then
            return
        end
        local alpha = math.clamp((os.clock() - slideStart) / math.max(0.01, tFric), 0, 1)
        local speedNow = initialSpeed + (exitV - initialSpeed) * alpha
        local steer = worldDashDir()
        slideLV.VectorVelocity = steer * speedNow
        if alpha >= 1 then
            endSlide()
        end
    end)
end

-- Input
local function onInputBegan(input: InputObject, gpe: boolean)
    if gpe then
        return
    end
    local kc = input.KeyCode
    if kc == Enum.KeyCode.W then
        moveZ = -1
    end
    if kc == Enum.KeyCode.S then
        moveZ = 1
    end
    if kc == Enum.KeyCode.A then
        moveX = -1
    end
    if kc == Enum.KeyCode.D then
        moveX = 1
    end
    if kc == Enum.KeyCode.Space then
        -- slide jump: carry before ending
        if isSliding and hrp then
            local v = hrp.AssemblyLinearVelocity
            local planar = Vector3.new(v.X, 0, v.Z)
            local spd = planar.Magnitude
            if spd > 0 then
                local keep = math.clamp(spd * (carry.factor or 0.9), carry.min or 16, carry.max or 60)
                local dir = planar.Magnitude > 0 and planar.Unit or worldForward()
                hrp.AssemblyLinearVelocity = Vector3.new(dir.X * keep, v.Y, dir.Z * keep)
            end
            endSlide()
        end
        if hum then
            hum.Jump = true
        end
    end
    if kc == Enum.KeyCode.Q then
        performDash()
    end
    if kc == Enum.KeyCode.C then
        tryStartSlide()
    end -- slide key (C)
end

local function onInputEnded(input: InputObject, _gpe: boolean)
    local kc = input.KeyCode
    if kc == Enum.KeyCode.W and moveZ == -1 then
        moveZ = 0
    end
    if kc == Enum.KeyCode.S and moveZ == 1 then
        moveZ = 0
    end
    if kc == Enum.KeyCode.A and moveX == -1 then
        moveX = 0
    end
    if kc == Enum.KeyCode.D and moveX == 1 then
        moveX = 0
    end
end

-- Module
local M = {}

function M:Start(_flags, _tuning)
    -- Load tuning
    tuning = _tuning
    if not tuning then
        local RS = game:GetService("ReplicatedStorage")
        local Shared = RS:FindFirstChild("Shared")
        if Shared then
            local Config = Shared:FindFirstChild("Config")
            if Config and Config:FindFirstChild("Tuning") then
                tuning = require(Config.Tuning)
            end
        end
    end

    -- Movement tuning
    local mv = (tuning and tuning.Movement) or {}
    local runSpd = mv.Run or 15
    local sprintSpd = mv.Sprint or 30
    AUTO_HOLD = mv.AutoSprintHold or 1.25
    carry.factor = mv.MomentumCarryFactor or 0.9
    carry.min = mv.MinCarrySpeed or 16
    carry.max = mv.MaxCarrySpeed or 60

    -- Dash tuning
    do
        local d = (tuning and tuning.Dash) or {}
        dashMax = d.Charges or 3
        dashCharges = dashMax
        dashRecharge = d.Recharge or 2.0
        dashImpulse = d.Impulse or 55.0
        dashDuration = d.Duration or 0.18
    end

    -- Slide tuning
    do
        local s = (tuning and tuning.Slide) or {}
        slideFrictionTime = s.FrictionTime or 0.8
        slideExitSpeed = s.ExitSpeed or 10.0
        slideMinSpeed = s.MinSpeed or 16.0
    end

    getChar()
    if hum then
        hum.WalkSpeed = runSpd
    end

    UIS.InputBegan:Connect(onInputBegan)
    UIS.InputEnded:Connect(onInputEnded)

    RunService.RenderStepped:Connect(function(dt)
        if not hum then
            return
        end
        if not isSliding then
            updateSprint(dt)
            hum.WalkSpeed = isSprinting and sprintSpd or runSpd
            local wish = currentLocalVector()
            if wish.Magnitude > 0 then
                hum:Move(wish, true)
            else
                hum:Move(Vector3.zero, true)
            end
        end
    end)

    player.CharacterAdded:Connect(function()
        getChar()
        if hum then
            hum.WalkSpeed = runSpd
        end
        if isSliding then
            endSlide()
        end
    end)
end

return M
