--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local Net = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net")
local WarStateUpdate: RemoteEvent   = Net:WaitForChild("WarStateUpdate")
local GetWarClock: RemoteFunction   = Net:WaitForChild("GetWarClock")

local ZonesFolder = workspace:WaitForChild("Zones")

-- helpers ----------------------------

local BASE_FOR_TEAM = { [1]="D4", [2]="D1", [3]="A1", [4]="A4" }

local function teamIndexForPlayer(plr: Player): number
	if not plr.Team then return 0 end
	for i=1,4 do
		if plr.Team.Name == Constants.TEAMS[i].Name then return i end
	end
	return 0
end

local function baseModelForTeam(teamIdx: number): Model?
	local id = BASE_FOR_TEAM[teamIdx]
	if not id then return nil end
	local m = ZonesFolder:FindFirstChild(id)
	if m and m:IsA("Model") then return m end
	return nil
end

local function baseplateOf(m: Model): BasePart?
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and string.find(d.Name, "Baseplate") then
			return d
		end
	end
	return nil
end

local function pointInPartXZ(part: BasePart, pos: Vector3): boolean
	local lp = part.CFrame:PointToObjectSpace(pos)
	local half = part.Size * 0.5
	return math.abs(lp.X) <= half.X and math.abs(lp.Z) <= half.Z
end

local function clampToBase(plr: Player)
	local idx = teamIndexForPlayer(plr); if idx == 0 then return end
	local bm = baseModelForTeam(idx); if not bm then return end
	local bp = baseplateOf(bm); if not bp then return end
	local char = plr.Character; if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart
	if not hrp then return end
	if not pointInPartXZ(bp, hrp.Position) then
		-- Nudge them back to center of base
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		hrp.CFrame = bp.CFrame + Vector3.new(0, 4, 0)
	end
end

-- state ------------------------------

local State = {
	phase   = "pregame",            -- "pregame" | "live"
	startAt = os.time(),            -- game start (pregame begins)
	liveAt  = os.time() + Constants.PRE_GAME_SECONDS, -- when live begins
}

local function snapshot()
	return {
		phase = State.phase,
		startAt = State.startAt,
		liveAt  = State.liveAt,
		now = os.time(),
	}
end

local function broadcast()
	WarStateUpdate:FireAllClients(snapshot())
end

-- API -------------------------------

GetWarClock.OnServerInvoke = function()
	return snapshot()
end

-- loop ------------------------------

task.spawn(function()
	State.startAt = os.time()
	State.liveAt  = State.startAt + Constants.PRE_GAME_SECONDS
	State.phase   = "pregame"
	broadcast()

	while true do
		local now = os.time()

		if State.phase == "pregame" then
			-- keep players inside their base tile
			for _, plr in ipairs(Players:GetPlayers()) do
				clampToBase(plr)
			end
			if now >= State.liveAt then
				State.phase = "live"
				broadcast()
			end
		end

		task.wait(0.25)
	end
end)
