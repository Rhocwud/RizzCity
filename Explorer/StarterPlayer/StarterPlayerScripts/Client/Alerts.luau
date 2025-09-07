-- Alerts.client.lua (FULL FILE)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst   = game:GetService("ReplicatedFirst")
local TweenService      = game:GetService("TweenService")
local Players           = game:GetService("Players")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Bus       = require(ReplicatedFirst:WaitForChild("ClientBus"))

local Net = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net")
local ZoneStateUpdate = Net:WaitForChild("ZoneStateUpdate") :: RemoteEvent
local WarStateUpdate  = Net:WaitForChild("WarStateUpdate")  :: RemoteEvent
local AlertEvent = Net:FindFirstChild("Alert") :: RemoteEvent? -- optional server broadcast

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "AlertsGui"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 60
gui.Parent = pg

local holder = Instance.new("Frame")
holder.Name = "Holder"
holder.AnchorPoint = Vector2.new(0.5,0)
holder.Position = UDim2.new(0.5,0,0,8)
holder.Size = UDim2.fromOffset(840, 40)
holder.BackgroundTransparency = 1
holder.Parent = gui

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1,0,1,0)
label.BackgroundColor3 = Color3.fromRGB(0,0,0)
label.BackgroundTransparency = 0.35
label.TextColor3 = Color3.new(1,1,1)
label.Font = Enum.Font.GothamBlack
label.TextSize = 28
label.TextXAlignment = Enum.TextXAlignment.Center
label.Text = ""
label.TextTransparency = 1
label.Visible = false
label.Parent = holder

local busy = false
local queue = {}

local function showNow(msg: string, secs: number)
	busy = true
	label.Text = msg
	label.Visible = true
	label.TextTransparency = 1
	label.BackgroundTransparency = 0.6

	TweenService:Create(label, TweenInfo.new(0.25), {
		TextTransparency = 0,
		BackgroundTransparency = 0.35
	}):Play()

	task.delay(secs, function()
		local tween = TweenService:Create(label, TweenInfo.new(0.4), {
			TextTransparency = 1,
			BackgroundTransparency = 1
		})
		tween.Completed:Connect(function()
			label.Visible = false
			busy = false
			if #queue > 0 then
				local nextMsg = table.remove(queue, 1)
				showNow(nextMsg.msg, nextMsg.secs)
			end
		end)
		tween:Play()
	end)
end

local function show(msg: string, secs: number?)
	secs = secs or 4.0 -- keep a bit longer per your feedback
	if busy then
		table.insert(queue, {msg = msg, secs = secs})
	else
		showNow(msg, secs)
	end
end

-- expose to other clients scripts
Bus.alert = show

-- synthesize helpful client-side alerts if server doesn't emit Alert
local lastByZone: {[string]: any} = {}
ZoneStateUpdate.OnClientEvent:Connect(function(s)
	if typeof(s) ~= "table" then return end
	local prev = lastByZone[s.zoneId]
	lastByZone[s.zoneId] = {
		ownerTeam = s.ownerTeam,
		lockedUntil = s.lockedUntil,
		contestEndsAt = s.contestEndsAt,
		isBase = s.isBase,
	}
	local now = os.time()

	-- lock just started => "Team X has claimed Z"
	if s.lockedUntil and s.lockedUntil > now and (not prev or not prev.lockedUntil or prev.lockedUntil <= now) then
		if s.ownerTeam and s.ownerTeam ~= 0 and not s.isBase then
			local t = Constants.TEAMS[s.ownerTeam]
			show(("Team %s has claimed %s"):format(t.Name, s.zoneId), 4.0)
		end
	end

	-- lock ended => "Z Open"
	if prev and prev.lockedUntil and prev.lockedUntil > now and (not s.lockedUntil or s.lockedUntil <= now) then
		if not s.isBase then
			show(("%s Open"):format(s.zoneId), 3.5)
		end
	end
end)

WarStateUpdate.OnClientEvent:Connect(function(w)
	if typeof(w) ~= "table" then return end
	if w.phase == "pregame" then
		local now = os.time()
		local left = math.max(0, (w.liveAt or now) - now)
		if left == 30 then
			show("Game begins in 30 seconds", 3.5)
		end
	end
end)

if AlertEvent then
	AlertEvent.OnClientEvent:Connect(function(msg: string, secs: number?)
		show(tostring(msg), secs)
	end)
end
