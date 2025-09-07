--!strict
-- ZoneHud.client.lua (FULL FILE)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Bus = require(ReplicatedFirst:WaitForChild("ClientBus"))

local Net = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net")
local ZoneStateUpdate = Net:WaitForChild("ZoneStateUpdate") :: RemoteEvent
local GetZoneStates = Net:WaitForChild("GetZoneStates") :: RemoteFunction
local GetWarClock = Net:WaitForChild("GetWarClock") :: RemoteFunction
local WarStateUpdate = Net:WaitForChild("WarStateUpdate") :: RemoteEvent
local GetCooldowns = Net:WaitForChild("GetCooldowns") :: RemoteFunction
local RequestZoneTeleport = Net:WaitForChild("RequestZoneTeleport") :: RemoteFunction

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

-- ============ GUI root ============
local gui = Instance.new("ScreenGui")
gui.Name = "ZoneHudGui"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 40
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = pg

-- ============ Game Clock (top-right, no box, stroked) ============
local clock = Instance.new("TextLabel")
clock.Name = "GameClock"
clock.AnchorPoint = Vector2.new(1, 0)
clock.Position = UDim2.new(1, -16, 0, 8)
clock.Size = UDim2.fromOffset(160, 28)
clock.BackgroundTransparency = 1
clock.Font = Enum.Font.GothamBlack
clock.TextSize = 28
clock.TextColor3 = Color3.new(1, 1, 1)
clock.TextStrokeTransparency = 0.35
clock.TextStrokeColor3 = Color3.fromRGB(20, 20, 20)
clock.TextXAlignment = Enum.TextXAlignment.Right
clock.Text = "0:00"
clock.Parent = gui

-- ============ HUD panel ============
local frame = Instance.new("Frame")
frame.Name = "Frame"
frame.AnchorPoint = Vector2.new(1, 0)
frame.Position = UDim2.new(1, -16, 0, 48)
frame.Size = UDim2.fromOffset(300, 122)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
frame.BackgroundTransparency = 0.1
frame.Parent = gui

local stroke = Instance.new("UIStroke")
stroke.Thickness = 3
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Color = Color3.fromRGB(60, 60, 60)
stroke.Parent = frame

local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, -12, 0, 24)
header.Position = UDim2.fromOffset(8, 6)
header.BackgroundTransparency = 1
header.Font = Enum.Font.GothamBold
header.TextSize = 18
header.TextXAlignment = Enum.TextXAlignment.Left
header.TextColor3 = Color3.new(1, 1, 1)
header.Text = "Zone —"
header.Parent = frame

-- just mm:ss (no 'Time:')
local timerLbl = Instance.new("TextLabel")
timerLbl.AnchorPoint = Vector2.new(1, 0)
timerLbl.Position = UDim2.new(1, -8, 0, 6)
timerLbl.Size = UDim2.fromOffset(60, 24)
timerLbl.BackgroundTransparency = 1
timerLbl.Font = Enum.Font.GothamBold
timerLbl.TextSize = 18
timerLbl.TextColor3 = Color3.new(1, 1, 1)
timerLbl.TextXAlignment = Enum.TextXAlignment.Right
timerLbl.Text = ""
timerLbl.Parent = frame

-- 4 horizontal team bars (hidden for bases)
local barContainer = Instance.new("Frame")
barContainer.Size = UDim2.new(1, -16, 0, 64)
barContainer.Position = UDim2.fromOffset(8, 40)
barContainer.BackgroundTransparency = 1
barContainer.Parent = frame

local function makeBar(color: Color3, y: number)
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 0, 12)
    bg.Position = UDim2.fromOffset(0, y)
    bg.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    bg.BorderSizePixel = 0
    bg.Parent = barContainer

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = color
    fill.BorderSizePixel = 0
    fill.Parent = bg
    return bg, fill
end

local rowGap = 14
local rows = {}
for i = 1, 4 do
    local bg, fill = makeBar(Constants.TEAMS[i].Color, (i - 1) * rowGap)
    rows[i] = { bg = bg, fill = fill }
end

-- ============ Buttons row (under HUD) ============
local btnRow = Instance.new("Frame")
btnRow.Name = "ButtonsRow"
btnRow.AnchorPoint = Vector2.new(1, 0)
btnRow.Position = UDim2.new(1, -16, 0, 176)
btnRow.Size = UDim2.fromOffset(300, 36)
btnRow.BackgroundTransparency = 1
btnRow.Parent = gui

local mapBtn = Instance.new("TextButton")
mapBtn.Name = "MapBtn"
mapBtn.AnchorPoint = Vector2.new(0, 0)
mapBtn.Position = UDim2.fromOffset(0, 0)
mapBtn.Size = UDim2.fromOffset(120, 36)
mapBtn.AutoButtonColor = true
mapBtn.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
mapBtn.BorderSizePixel = 0
mapBtn.Font = Enum.Font.GothamBold
mapBtn.TextSize = 18
mapBtn.TextColor3 = Color3.new(1, 1, 1)
mapBtn.Text = "Map"
mapBtn.Parent = btnRow

local rdpBtn = Instance.new("TextButton")
rdpBtn.Name = "RedeployBtn"
rdpBtn.AnchorPoint = Vector2.new(1, 0)
rdpBtn.Position = UDim2.new(1, 0, 0, 0)
rdpBtn.Size = UDim2.fromOffset(120, 36)
rdpBtn.AutoButtonColor = true
rdpBtn.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
rdpBtn.BorderSizePixel = 0
rdpBtn.Font = Enum.Font.GothamBold
rdpBtn.TextSize = 18
rdpBtn.TextColor3 = Color3.new(1, 1, 1)
rdpBtn.Text = "Redeploy"
rdpBtn.Parent = btnRow

-- cooldown dimmer
local cdDim = Instance.new("Frame")
cdDim.Name = "CooldownOverlay"
cdDim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
cdDim.BackgroundTransparency = 0.45
cdDim.BorderSizePixel = 0
cdDim.Size = UDim2.new(1, 0, 1, 0)
cdDim.Visible = false
cdDim.Parent = rdpBtn

local cdFill = Instance.new("Frame")
cdFill.Name = "Fill"
cdFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
cdFill.BackgroundTransparency = 0.75
cdFill.BorderSizePixel = 0
cdFill.Size = UDim2.new(0, 0, 1, 0)
cdFill.Parent = cdDim

-- ============ State ============
local state: { [string]: any } = {}
do
    local ok, data = pcall(function()
        return GetZoneStates:InvokeServer()
    end)
    if ok and typeof(data) == "table" then
        for id, s in pairs(data) do
            state[id] = s
        end
    end
end
ZoneStateUpdate.OnClientEvent:Connect(function(s)
    if typeof(s) == "table" then
        state[s.zoneId] = s
    end
end)

local war = { phase = "pregame", startAt = os.time(), liveAt = os.time() + 30, now = os.time() }
do
    local ok, w = pcall(function()
        return GetWarClock:InvokeServer()
    end)
    if ok and typeof(w) == "table" then
        war = w
    end
end
WarStateUpdate.OnClientEvent:Connect(function(w)
    if typeof(w) == "table" then
        war = w
    end
end)

-- zone lookup
local ZonesFolder = workspace:WaitForChild("Zones")
local function baseplateOf(m: Model): BasePart?
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("BasePart") and string.find(d.Name, "Baseplate") then
            return d
        end
    end
    return nil
end
local function insideXZ(p: BasePart, pos: Vector3): boolean
    local lpv = p.CFrame:PointToObjectSpace(pos)
    local h = p.Size * 0.5
    return math.abs(lpv.X) <= h.X and math.abs(lpv.Z) <= h.Z
end
local function zoneAt(pos: Vector3): string?
    for _, m in ipairs(ZonesFolder:GetChildren()) do
        if m:IsA("Model") then
            local bp = baseplateOf(m)
            if bp and insideXZ(bp, pos) then
                return m.Name
            end
        end
    end
    return nil
end

-- helpers
local function fmtClock(secs: number): string
    return string.format("%d:%02d", math.floor(secs / 60), secs % 60)
end
local function myTeamIndex(): number
    if lp.Team then
        for i = 1, 4 do
            if Constants.TEAMS[i].Name == lp.Team.Name then
                return i
            end
        end
    end
    return 0
end

-- HUD update
local function updateHud()
    -- GAME CLOCK
    local now = os.time()
    if war.phase == "pregame" then
        local left = math.max(0, (war.liveAt or now) - now)
        clock.Text = fmtClock(left)
    else
        local elapsed = math.max(0, now - (war.liveAt or now))
        clock.Text = fmtClock(elapsed)
    end

    local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return
    end
    local id = zoneAt(hrp.Position)

    -- default HUD visuals
    header.Text = "Zone —"
    timerLbl.Text = ""
    stroke.Color = Color3.fromRGB(60, 60, 60)
    for i = 1, 4 do
        rows[i].bg.Visible = false
    end

    if not id then
        return
    end
    local s = state[id]
    header.Text = "Zone " .. id
    if not s then
        return
    end

    local now2 = os.time()
    local isActive = s.contestEndsAt and s.contestEndsAt > now2

    -- border colors
    if s.isBase then
        if s.ownerTeam and s.ownerTeam ~= 0 then
            stroke.Color = Constants.TEAMS[s.ownerTeam].Color
        end
    else
        if s.ownerTeam and s.ownerTeam ~= 0 then
            stroke.Color = Constants.TEAMS[s.ownerTeam].Color
        elseif isActive then
            stroke.Color = Color3.new(1, 1, 1) -- neutral live
        else
            stroke.Color = Color3.fromRGB(60, 60, 60)
        end
    end

    -- timer
    if isActive then
        timerLbl.Text = fmtClock(math.max(0, s.contestEndsAt - now2))
    elseif s.lockedUntil and s.lockedUntil > now2 then
        timerLbl.Text = tostring(math.max(0, s.lockedUntil - now2)) .. "s"
    else
        timerLbl.Text = ""
    end

    -- bars (hide for base)
    if not s.isBase then
        local total = (s.totalWeight and s.totalWeight > 0) and s.totalWeight or 1
        for i = 1, 4 do
            local pct = 0
            if s.weights and s.weights[i] then
                pct = math.clamp(s.weights[i] / total, 0, 1)
            end
            rows[i].bg.Visible = pct > 0
            rows[i].fill.Size = UDim2.new(pct, 0, 1, 0)
        end
    end
end

-- Cooldown & redeploy
local BASE_BY_IDX = { "R_Base", "Y_Base", "B_Base", "G_Base" }

local function refreshRedeploy()
    local ok, cd = pcall(function()
        return GetCooldowns:InvokeServer()
    end)
    if not ok or typeof(cd) ~= "table" then
        rdpBtn.AutoButtonColor = false
        cdDim.Visible = true
        cdFill.Size = UDim2.new(1, 0, 1, 0)
        return
    end

    local now = cd.now or os.time()
    local nextAny = cd.nextAny or now
    local remain = math.max(0, nextAny - now)

    if remain == 0 then
        rdpBtn.AutoButtonColor = true
        cdDim.Visible = false
        cdFill.Size = UDim2.new(0, 0, 1, 0)
    else
        rdpBtn.AutoButtonColor = false
        cdDim.Visible = true
        -- try to show a proportional fill if server sent "cooldownLen"; else fall back to 60s
        local len = cd.cooldownLen or 60
        local f = math.clamp(remain / len, 0, 1)
        cdFill.Size = UDim2.new(f, 0, 1, 0)
    end
end

mapBtn.MouseButton1Click:Connect(function()
    Bus.toggleWarMap()
end)

rdpBtn.MouseButton1Click:Connect(function()
    local ok, cd = pcall(function()
        return GetCooldowns:InvokeServer()
    end)
    if not ok or typeof(cd) ~= "table" then
        return
    end
    local now = cd.now or os.time()
    if (cd.nextAny or 0) > now then
        return
    end

    local idx = myTeamIndex()
    if idx == 0 then
        return
    end
    local baseId = BASE_BY_IDX[idx]
    local ok2, good, why = pcall(function()
        return RequestZoneTeleport:InvokeServer(baseId)
    end)
    if not ok2 or not good then
        -- optional: Bus.alert("Redeploy failed", 2.0)
        return
    end
    -- optional: Bus.alert("Redeployed to base", 2.0)
    refreshRedeploy()
end)

-- loops
task.spawn(function()
    while true do
        updateHud()
        task.wait(0.25)
    end
end)

task.spawn(function()
    while true do
        refreshRedeploy()
        task.wait(0.5)
    end
end)
