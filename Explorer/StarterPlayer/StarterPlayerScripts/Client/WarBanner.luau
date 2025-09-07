--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local WarStateUpdate: RemoteEvent =
    ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"):WaitForChild("WarStateUpdate")

local pg = Players.LocalPlayer:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "WarBannerGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.Parent = pg

local panel = Instance.new("Frame")
panel.Size = UDim2.fromScale(1, 0)
panel.Position = UDim2.fromScale(0, 0.18)
panel.BackgroundTransparency = 1
panel.Visible = false
panel.Parent = gui

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, 0, 0, 64)
label.Position = UDim2.new(0, 0, 0, 0)
label.BackgroundTransparency = 1
label.Text = ""
label.Font = Enum.Font.GothamBlack
label.TextSize = 48
label.TextColor3 = Color3.new(1, 1, 1)
label.TextStrokeTransparency = 0.4
label.Parent = panel

local sub = Instance.new("TextLabel")
sub.Size = UDim2.new(1, 0, 0, 28)
sub.Position = UDim2.new(0, 0, 0, 64)
sub.BackgroundTransparency = 1
sub.Text = ""
sub.Font = Enum.Font.Gotham
sub.TextSize = 20
sub.TextColor3 = Color3.new(1, 1, 1)
sub.Parent = panel

local function teamName(idx: number): string
    return (Constants.TEAMS[idx] and Constants.TEAMS[idx].Name) or ("Team " .. tostring(idx))
end

local function teamColor(idx: number): Color3
    return (Constants.TEAMS[idx] and Constants.TEAMS[idx].Color) or Color3.new(1, 1, 1)
end

WarStateUpdate.OnClientEvent:Connect(function(msg)
    if typeof(msg) ~= "table" then
        return
    end
    if msg.phase == "win" then
        local name = teamName(msg.winnerTeam)
        label.Text = name .. " win the war!"
        label.TextColor3 = teamColor(msg.winnerTeam)
        panel.Visible = true

        -- countdown
        local function tick()
            if typeof(msg.resetAt) == "number" then
                local left = math.max(0, msg.resetAt - os.time())
                sub.Text = string.format("Resetting map in %ds…", left)
            else
                sub.Text = "Resetting map…"
            end
        end

        tick()
        -- simple 1s timer for the countdown text
        task.spawn(function()
            while panel.Visible and typeof(msg.resetAt) == "number" and msg.resetAt > os.time() do
                task.wait(1)
                tick()
            end
        end)
    elseif msg.phase == "reset" then
        panel.Visible = false
        label.Text = ""
        sub.Text = ""
    end
end)
