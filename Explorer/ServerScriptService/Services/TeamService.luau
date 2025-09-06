--!strict
local Players = game:GetService("Players")
local TeamsService = game:GetService("Teams")
local Constants = require(game.ReplicatedStorage.Shared.Constants)

local TeamByIndex: { [number]: Team } = {}

local function findOrError(teamName: string): Team
	local t = TeamsService:FindFirstChild(teamName)
	assert(t and t:IsA("Team"), ("[TeamService] Missing Team: %s"):format(teamName))
	return t
end

local function initTeams()
	TeamByIndex[1] = findOrError("Red")
	TeamByIndex[2] = findOrError("Yellow")
	TeamByIndex[3] = findOrError("Blue")
	TeamByIndex[4] = findOrError("Green")
	for i, t in ipairs(TeamByIndex) do
		t.AutoAssignable = false
		t.TeamColor = Constants.TEAMS[i].BrickColor
	end
	print("[TeamService] Teams initialized.")
end

local function getCounts()
	local counts = {0,0,0,0}
	for _, plr in ipairs(Players:GetPlayers()) do
		for i, team in ipairs(TeamByIndex) do
			if plr.Team == team then counts[i] += 1 end
		end
	end
	return counts
end

local function pickBalancedTeam(): Team
	local counts = getCounts()
	local minIdx, minVal = 1, counts[1]
	for i = 2, 4 do
		if counts[i] < minVal then minIdx, minVal = i, counts[i] end
	end
	return TeamByIndex[minIdx]
end

Players.PlayerAdded:Connect(function(plr)
	plr.Team = pickBalancedTeam()
	print(("[TeamService] %s joined %s"):format(plr.Name, plr.Team.Name))
end)

initTeams()

