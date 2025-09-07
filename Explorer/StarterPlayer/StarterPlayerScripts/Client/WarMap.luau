--!strict
-- WarMap.client.lua (full file)

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local ReplicatedFirst    = game:GetService("ReplicatedFirst")
local UIS                = game:GetService("UserInputService")

local Constants  = require(ReplicatedStorage.Shared.Constants)
local Adjacency  = require(ReplicatedStorage.Shared.Adjacency)
local Bus        = require(ReplicatedFirst:WaitForChild("ClientBus"))

local Net = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net")
local ZoneStateUpdate      = Net:WaitForChild("ZoneStateUpdate")      :: RemoteEvent
local GetZoneStates        = Net:WaitForChild("GetZoneStates")        :: RemoteFunction
local RequestZoneTeleport  = Net:WaitForChild("RequestZoneTeleport")  :: RemoteFunction
local GetCooldowns         = Net:WaitForChild("GetCooldowns")         :: RemoteFunction
local GetWarClock          = Net:WaitForChild("GetWarClock")          :: RemoteFunction
local WarStateUpdate       = Net:WaitForChild("WarStateUpdate")       :: RemoteEvent

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

-- GUI ------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "WarMapGui"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 30
gui.Parent = pg

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(560, 592)
panel.Position = UDim2.new(0.5, -280, 0.5, -296)
panel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
panel.BackgroundTransparency = 0.25
panel.Visible = false
panel.Parent = gui

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(28,28)
closeBtn.Position = UDim2.new(1,-36,0,8)
closeBtn.BackgroundColor3 = Color3.fromRGB(25,25,25)
closeBtn.BackgroundTransparency = 0.1
closeBtn.BorderSizePixel = 0
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 18
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Text = "X"
closeBtn.Parent = panel
closeBtn.MouseButton1Click:Connect(function() panel.Visible = false end)

local locLabel = Instance.new("TextLabel")
locLabel.Size = UDim2.fromOffset(260, 22)
locLabel.Position = UDim2.fromOffset(12, 8)
locLabel.BackgroundTransparency = 1
locLabel.Font = Enum.Font.GothamBold
locLabel.TextSize = 16
locLabel.TextColor3 = Color3.new(1,1,1)
locLabel.TextXAlignment = Enum.TextXAlignment.Left
locLabel.Text = "Current Location: —"
locLabel.Parent = panel

local grid = Instance.new("Frame")
grid.Size = UDim2.fromOffset(532, 532)
grid.Position = UDim2.fromOffset(14, 44)
grid.BackgroundTransparency = 1
grid.Parent = panel

local logLabel = Instance.new("TextLabel")
logLabel.Size = UDim2.fromOffset(532, 18)
logLabel.Position = UDim2.fromOffset(14, 568)
logLabel.BackgroundTransparency = 1
logLabel.Font = Enum.Font.Gotham
logLabel.TextSize = 14
logLabel.TextColor3 = Color3.new(1,1,1)
logLabel.TextXAlignment = Enum.TextXAlignment.Left
logLabel.Text = ""
logLabel.Parent = panel

-- State ----------------------------------------------------------------------
local state: {[string]: any} = {}
do
	local ok, data = pcall(function() return GetZoneStates:InvokeServer() end)
	if ok and typeof(data)=="table" then
		for id, s in pairs(data) do state[id] = s end
	end
end
ZoneStateUpdate.OnClientEvent:Connect(function(s)
	if typeof(s)=="table" then state[s.zoneId] = s end
end)

local war = { phase="pregame", startAt=os.time(), liveAt=os.time()+30, now=os.time() }
do
	local ok, w = pcall(function() return GetWarClock:InvokeServer() end)
	if ok and typeof(w)=="table" then war = w end
end
WarStateUpdate.OnClientEvent:Connect(function(w)
	if typeof(w)=="table" then war = w end
end)

-- Zone lookup ---------------------------------------------------------------
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
			if bp and insideXZ(bp, pos) then return m.Name end
		end
	end
	return nil
end

-- Helpers --------------------------------------------------------------------
local function myTeamIndex(): number
	if lp.Team then
		for i=1,4 do
			if Constants.TEAMS[i].Name == lp.Team.Name then return i end
		end
	end
	return 0
end

local function myTeamName(): string
	local i = myTeamIndex()
	return (i>0 and Constants.TEAMS[i].Name) or "Team"
end

local function myTeamColor(): Color3
	local i = myTeamIndex()
	return (i>0 and Constants.TEAMS[i].Color) or Color3.new(1,1,1)
end

local function friendlyCount(zoneId: string): number
	local meName = lp.Team and lp.Team.Name
	if not meName then return 0 end
	local c = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Team and p.Team.Name == meName then
			local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if hrp and zoneAt(hrp.Position) == zoneId then c += 1 end
		end
	end
	return c
end

local function canEnter(id: string, s): boolean
	if war.phase ~= "live" then return false end
	if not s or s.isBase then return false end
	local my = myTeamIndex()
	if my == 0 then return false end

	-- If locked and owned by someone else, you can’t enter.
	if s.lockedUntil and s.lockedUntil > os.time() and s.ownerTeam ~= my then
		return false
	end

	-- If your team owns it, always enterable.
	if s.ownerTeam == my then return true end

	-- Otherwise check adjacency from any zone your team owns.
	for oid, snap in pairs(state) do
		if snap.ownerTeam == my then
			for _, nbr in ipairs(Adjacency.GetNeighbors(oid)) do
				if nbr == id then return true end
			end
		end
	end
	return false
end

local function liveTimeLeft(s): string
	if war.phase ~= "live" or not s then return "" end
	if s.lockedUntil and s.lockedUntil > os.time() then
		return tostring(math.max(0, s.lockedUntil - os.time()))
	elseif s.contestEndsAt and s.contestEndsAt > os.time() then
		local left = math.max(0, s.contestEndsAt - os.time())
		return string.format("%d:%02d", math.floor(left/60), left%60)
	end
	return ""
end

-- Build tiles (store refs in Lua table) --------------------------------------
local TILE, GAP = 120, 8
local ORDER = {"A1","A2","A3","A4","B1","B2","B3","B4","C1","C2","C3","C4","D1","D2","D3","D4"}

type TileRefs = {
	id: string,
	btn: TextButton,
	stroke: UIStroke,
	hdr: TextLabel,
	time: TextLabel,
	stack: Frame,
	segs: {Frame},
	lockedLbl: TextLabel,
	lockedTag: TextLabel,
	winLbl: TextLabel,
	playersLbl: TextLabel
}
local tileRefs: {[string]: TileRefs} = {}

local function makeTile(id: string, row: number, col: number)
	local btn = Instance.new("TextButton")
	btn.Name = id
	btn.Size = UDim2.fromOffset(TILE, TILE)
	btn.Position = UDim2.fromOffset((col-1)*(TILE+GAP), (row-1)*(TILE+GAP))
	btn.BackgroundColor3 = Color3.fromRGB(25,25,25)
	btn.BorderSizePixel = 0
	btn.Text = ""
	btn.AutoButtonColor = true
	btn.Parent = grid

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.fromRGB(60,60,60)
	stroke.Parent = btn

	local hdr = Instance.new("TextLabel")
	hdr.Size = UDim2.new(1,-8,0,20)
	hdr.Position = UDim2.fromOffset(6,6)
	hdr.BackgroundTransparency = 1
	hdr.Font = Enum.Font.GothamBold
	hdr.TextSize = 16
	hdr.TextColor3 = Color3.new(1,1,1)
	hdr.TextXAlignment = Enum.TextXAlignment.Left
	hdr.Text = id
	hdr.Parent = btn

	local time = Instance.new("TextLabel")
	time.Size = UDim2.fromOffset(64,20)
	time.Position = UDim2.new(1,-72,0,4)
	time.BackgroundTransparency = 1
	time.Font = Enum.Font.GothamBold
	time.TextSize = 16
	time.TextColor3 = Color3.new(1,1,1)
	time.TextXAlignment = Enum.TextXAlignment.Right
	time.Text = ""
	time.Parent = btn

	local winLbl = Instance.new("TextLabel")
	winLbl.Size = UDim2.new(1,-8,0,18)
	winLbl.Position = UDim2.fromOffset(4,28)
	winLbl.BackgroundTransparency = 1
	winLbl.Font = Enum.Font.GothamBold
	winLbl.TextSize = 14
	winLbl.TextColor3 = Color3.new(1,1,1)
	winLbl.TextXAlignment = Enum.TextXAlignment.Center
	winLbl.Text = "Winner"
	winLbl.Visible = false
	winLbl.Parent = btn

	local lockedTag = Instance.new("TextLabel")
	lockedTag.Size = UDim2.fromOffset(80,18)
	lockedTag.Position = UDim2.new(0.5,-40,1,-44)
	lockedTag.BackgroundTransparency = 1
	lockedTag.Font = Enum.Font.GothamBold
	lockedTag.TextSize = 14
	lockedTag.TextColor3 = Color3.new(1,1,1)
	lockedTag.TextXAlignment = Enum.TextXAlignment.Center
	lockedTag.Text = "LOCKED"
	lockedTag.Visible = false
	lockedTag.Parent = btn

	local lockedLbl = Instance.new("TextLabel")
	lockedLbl.Size = UDim2.fromOffset(60,18)
	lockedLbl.Position = UDim2.new(0.5,-30,1,-22)
	lockedLbl.BackgroundTransparency = 1
	lockedLbl.Font = Enum.Font.GothamBold
	lockedLbl.TextSize = 16
	lockedLbl.TextColor3 = Color3.new(1,1,1)
	lockedLbl.TextXAlignment = Enum.TextXAlignment.Center
	lockedLbl.Text = ""
	lockedLbl.Visible = false
	lockedLbl.Parent = btn

	local stack = Instance.new("Frame")
	stack.Size = UDim2.fromOffset(26, TILE-52)
	stack.Position = UDim2.fromOffset(TILE-26-4, 26)
	stack.BorderSizePixel = 0
	stack.BackgroundColor3 = Color3.fromRGB(30,30,30)
	stack.Visible = false
	stack.Parent = btn

	local segs: {Frame} = {}
	for i=1,4 do
		local seg = Instance.new("Frame")
		seg.Name = "Seg"..i
		seg.Size = UDim2.new(1,0,0,0)
		seg.Position = UDim2.fromScale(0,0)
		seg.BorderSizePixel = 0
		seg.Visible = false
		seg.Parent = stack

		local pct = Instance.new("TextLabel")
		pct.Name = "Pct"
		pct.Size = UDim2.new(1,0,0,16)
		pct.Position = UDim2.new(0,0,0.5,-8)
		pct.BackgroundTransparency = 1
		pct.Font = Enum.Font.GothamBold
		pct.TextSize = 12
		pct.TextColor3 = Color3.new(1,1,1)
		pct.Text = ""
		pct.Parent = seg

		segs[i] = seg
	end

	local playersLbl = Instance.new("TextLabel")
	playersLbl.Size = UDim2.new(1,-8,0,18)
	playersLbl.Position = UDim2.new(0,4,1,-22)
	playersLbl.BackgroundTransparency = 1
	playersLbl.Font = Enum.Font.GothamBold
	playersLbl.TextSize = 14
	playersLbl.TextColor3 = myTeamColor()
	playersLbl.TextXAlignment = Enum.TextXAlignment.Left
	playersLbl.Text = ""
	playersLbl.Visible = false -- only on ACTIVE & DEPLOYABLE
	playersLbl.Parent = btn

	btn.MouseButton1Click:Connect(function()
		local s = state[id]
		if not s then
			logLabel.Text = "Zone "..id.." is not active yet."
			return
		end

		local ok, cd = pcall(function() return GetCooldowns:InvokeServer() end)
		if not ok or typeof(cd)~="table" then
			logLabel.Text = "Cooldown unavailable."
			return
		end
		local now = cd.now or os.time()
		if (cd.nextAny or 0) > now then
			logLabel.Text = ("On Cooldown %ds remaining"):format((cd.nextAny or 0) - now)
			return
		end
		if (cd.nextZone or 0) > now then
			logLabel.Text = ("Wait %ds before deploying"):format((cd.nextZone or 0) - now)
			return
		end
		if not canEnter(id, s) then
			logLabel.Text = "Cannot deploy to "..id
			return
		end

		btn.AutoButtonColor = false
		logLabel.Text = "Teleporting to "..id.."..."
		local ok2, good, why = pcall(function() return RequestZoneTeleport:InvokeServer(id) end)
		btn.AutoButtonColor = true
		if ok2 and good then
			logLabel.Text = "Teleported to "..id
			panel.Visible = false
		else
			logLabel.Text = ok2 and ("Failed: "..tostring(why)) or ("Invoke error: "..tostring(good))
		end
	end)

	tileRefs[id] = {
		id = id, btn = btn, stroke = stroke, hdr = hdr, time = time,
		stack = stack, segs = segs, lockedLbl = lockedLbl, lockedTag = lockedTag,
		winLbl = winLbl, playersLbl = playersLbl
	}
end

do
	local r,c = 1,1
	for _, id in ipairs(ORDER) do
		makeTile(id, r, c)
		c += 1; if c>4 then c=1; r+=1 end
	end
end

-- Update logic ---------------------------------------------------------------
local function updateTile(id: string)
	local refs = tileRefs[id]; if not refs then return end
	local s = state[id]

	-- reset
	refs.hdr.Text = id
	refs.lockedLbl.Visible = false
	refs.lockedTag.Visible = false
	refs.winLbl.Visible = false
	refs.stack.Visible = false
	refs.time.Text = ""
	refs.playersLbl.Visible = false
	refs.playersLbl.Text = ""

		-- Base tiles: colored border (owner) and no bars/players label
	if s and s.isBase then
		refs.stroke.Color = (s.ownerTeam and s.ownerTeam~=0) and Constants.TEAMS[s.ownerTeam].Color or Color3.fromRGB(60,60,60)
		refs.playersLbl.Visible = false
		return
	end

	-- Owner border (or neutral)
	if s and s.ownerTeam and s.ownerTeam ~= 0 then
		refs.stroke.Color = Constants.TEAMS[s.ownerTeam].Color
	else
		refs.stroke.Color = Color3.fromRGB(60,60,60)
		end

		local now = os.time()
local isLocked  = s and s.lockedUntil and s.lockedUntil > now
local isActive  = s and s.contestEndsAt and s.contestEndsAt > now
local enterOK   = s and canEnter(id, s) or false

-- White border for active, neutral, enterable
if isActive and (not s.ownerTeam or s.ownerTeam == 0) and enterOK then
	refs.stroke.Color = Color3.new(1,1,1)
end

-- Locked presentation
if isLocked then
	local tInfo = s.ownerTeam and Constants.TEAMS[s.ownerTeam]
	refs.winLbl.Visible = true
	refs.winLbl.Text = tInfo and ("Winner "..tInfo.Name) or "Winner"
	refs.winLbl.TextColor3 = tInfo and tInfo.Color or Color3.new(1,1,1)
	refs.stroke.Color = tInfo and tInfo.Color or refs.stroke.Color

	refs.lockedTag.Visible = true
	refs.lockedLbl.Visible = true
	refs.lockedLbl.Text = tostring(math.max(0, s.lockedUntil - now)).."s"
	return
end

-- ACTIVE tiles only: timer (if enterable), friendly count (ACTIVE + DEPLOYABLE), and bars
if isActive then
	-- timer only when you can deploy
	if enterOK then
		local left = math.max(0, s.contestEndsAt - now)
		refs.time.Text = string.format("%d:%02d", math.floor(left/60), left%60)
	end

	-- your-team count ONLY when ACTIVE **AND** DEPLOYABLE
	if enterOK then
		local myName = myTeamName()
		refs.playersLbl.TextColor3 = myTeamColor()
		refs.playersLbl.Text = string.format("%s Players: %d", myName, friendlyCount(id))
		refs.playersLbl.Visible = true
	end

	-- vertical bars
	refs.stack.Visible = true
	local total = (s and s.totalWeight and s.totalWeight > 0) and s.totalWeight or 1
	local acc = 0
	for i=1,4 do
		local seg = refs.segs[i]
		local pct = seg:FindFirstChild("Pct") :: TextLabel
		local v = (s and s.weights and s.weights[i]) or 0
		local f = math.clamp(v/total, 0, 1)
		seg.Size = UDim2.new(1,0,f,0)
		seg.Position = UDim2.new(0,0,acc,0)
		seg.BackgroundColor3 = Constants.TEAMS[i].Color
		seg.Visible = f > 0
		if pct then pct.Text = (f>0) and (tostring(math.floor(f*100+0.5)).."%") or "" end
		acc += f
	end
else
	refs.stack.Visible = false
	refs.time.Text = ""
end
end

-- location label
task.spawn(function()
	while true do
		local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		locLabel.Text = "Current Location: "..((hrp and zoneAt(hrp.Position)) or "—")
		task.wait(0.25)
	end
end)

-- periodic refresh
task.spawn(function()
	while true do
		for id,_ in pairs(tileRefs) do updateTile(id) end
		task.wait(1)
	end
end)

-- Toggle (M or bus)
Bus.toggleWarMap = function()
	panel.Visible = not panel.Visible
end
UIS.InputBegan:Connect(function(input, gp)
	if not gp and input.KeyCode == Enum.KeyCode.M then
		panel.Visible = not panel.Visible
	end
end)
