--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local TeleportState = require(script.Parent.TeleportState)

local Net = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net")
local ZoneStateUpdate: RemoteEvent = Net:WaitForChild("ZoneStateUpdate")
local GetZoneStates: RemoteFunction = Net:WaitForChild("GetZoneStates")

local ZonesFolder = workspace:WaitForChild("Zones")

type Zone = {
    Model: Model,
    ZoneId: string,
    IsBase: boolean,
    OwnerTeam: number,
    Weights: { number },
    ContestEndsAt: number?, -- when live ends
    LockedUntil: number?, -- after capture
}
local ZONES: { [string]: Zone } = {}
local function newWeights(): { number }
    return { 0, 0, 0, 0 }
end
local function sum(t: { number }): number
    local s = 0
    for i = 1, 4 do
        s += (t[i] or 0)
    end
    return s
end

local function snapshot(z: Zone)
    return {
        zoneId = z.ZoneId,
        ownerTeam = z.OwnerTeam or 0,
        isBase = z.IsBase,
        weights = z.Weights,
        totalWeight = sum(z.Weights),
        contestEndsAt = z.ContestEndsAt,
        lockedUntil = z.LockedUntil,
    }
end

local function broadcast(z: Zone)
    ZoneStateUpdate:FireAllClients(snapshot(z))
end

-- Base grid anchors (corners)
local BASE_GRID_FOR_TEAM = { [1] = "D4", [2] = "D1", [3] = "A1", [4] = "A4" }

local function baseplateOf(m: Model): BasePart?
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("BasePart") and string.find(d.Name, "Baseplate") then
            return d
        end
    end
    return nil
end

-- XZ-only point-in-part
local function pointInPartXZ(part: BasePart, worldPos: Vector3): boolean
    local lp = part.CFrame:PointToObjectSpace(worldPos)
    local half = part.Size * 0.5
    return math.abs(lp.X) <= half.X and math.abs(lp.Z) <= half.Z
end

local function getTeamBaseModel(teamIdx: number): Model?
    for _, v in pairs(ZONES) do
        if v.IsBase and (v.OwnerTeam == teamIdx or v.Model.Name == BASE_GRID_FOR_TEAM[teamIdx]) then
            return v.Model
        end
    end
    local m = ZonesFolder:FindFirstChild(BASE_GRID_FOR_TEAM[teamIdx])
    if m and m:IsA("Model") then
        return m
    end
    return nil
end

local function getTeleportZoneForTeam(teamIdx: number): BasePart?
    local baseModel = getTeamBaseModel(teamIdx)
    if not baseModel then
        return nil
    end
    local p = baseModel:FindFirstChild(Constants.BASE_TELEPORT_ZONE_NAME, true)
    return (p and p:IsA("BasePart")) and p or nil
end

local function safeTeleportCharacter(plr: Player, cf: CFrame)
    local char = plr.Character
    if not char then
        return
    end
    local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart
    if not hrp then
        return
    end
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    hrp.CFrame = cf + Vector3.new(0, 3, 0)
end

local function redeployEveryoneInZone(z: Zone)
    local bp = baseplateOf(z.Model)
    if not bp then
        return
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart
        if hrp and pointInPartXZ(bp, hrp.Position) then
            -- send them to their base and clear cooldowns
            local teamIdx = 0
            if plr.Team then
                for i = 1, 4 do
                    if Constants.TEAMS[i].Name == plr.Team.Name then
                        teamIdx = i
                        break
                    end
                end
            end
            if teamIdx ~= 0 then
                local tz = getTeleportZoneForTeam(teamIdx)
                if tz then
                    safeTeleportCharacter(plr, tz.CFrame)
                    TeleportState.reset(plr.UserId)
                end
            end
        end
    end
end

local function loadZones()
    table.clear(ZONES)
    local now = os.time()
    for _, m in ipairs(ZonesFolder:GetChildren()) do
        if m:IsA("Model") then
            local id = m:GetAttribute("ZoneId")
            if typeof(id) == "string" and id ~= "" then
                local isBase = m:GetAttribute("IsBase") == true
                local owner = tonumber(m:GetAttribute("OwnerTeam")) or 0
                local z: Zone = {
                    Model = m,
                    ZoneId = id,
                    IsBase = isBase,
                    OwnerTeam = owner,
                    Weights = newWeights(),
                    ContestEndsAt = (not isBase) and (now + Constants.ZONE_TIMER_SECONDS) or nil,
                    LockedUntil = nil,
                }
                ZONES[id] = z
                broadcast(z)
            end
        end
    end
    local list = {}
    for id, _ in pairs(ZONES) do
        table.insert(list, id)
    end
    table.sort(list)
    print("[ZoneService] Loaded zones: " .. table.concat(list, ", "))
end

local function addClaim(zoneId: string, teamIdx: number, amount: number)
    local z = ZONES[zoneId]
    if not z then
        return
    end
    if z.IsBase or z.LockedUntil ~= nil then
        return
    end
    if z.ContestEndsAt == nil then
        return
    end
    if teamIdx < 1 or teamIdx > 4 then
        return
    end
    z.Weights[teamIdx] = (z.Weights[teamIdx] or 0) + amount
    broadcast(z)
end

local function finishContest(z: Zone)
    local maxTeam, maxWeight = 0, 0
    for i = 1, 4 do
        local w = z.Weights[i] or 0
        if w > maxWeight then
            maxWeight, maxTeam = w, i
        end
    end
    if maxWeight <= 0 then
        z.Weights = newWeights()
        z.ContestEndsAt = os.time() + Constants.ZONE_TIMER_SECONDS
        broadcast(z)
        return
    end
    z.OwnerTeam = maxTeam
    z.Model:SetAttribute("OwnerTeam", maxTeam)
    z.LockedUntil = os.time() + Constants.ZONE_LOCKOUT_SECONDS
    z.ContestEndsAt = nil
    z.Weights = newWeights()
    print(("[ZoneService] %s captured by t%d, lockout %ds"):format(z.ZoneId, maxTeam, Constants.ZONE_LOCKOUT_SECONDS))
    broadcast(z)
    redeployEveryoneInZone(z) -- NOW WORKS (XZ-only)
end

local function unlockIfReady(z: Zone, now: number)
    if z.LockedUntil and now >= z.LockedUntil then
        z.LockedUntil = nil
        z.ContestEndsAt = now + Constants.ZONE_TIMER_SECONDS
        z.Weights = newWeights()
        broadcast(z)
    end
end

task.spawn(function()
    loadZones()
    while true do
        local now = os.time()
        for _, z in pairs(ZONES) do
            if not z.IsBase then
                if z.LockedUntil then
                    unlockIfReady(z, now)
                elseif z.ContestEndsAt and now >= z.ContestEndsAt then
                    finishContest(z)
                end
            end
        end
        task.wait(1)
    end
end)

GetZoneStates.OnServerInvoke = function(_plr)
    local out = {}
    for id, z in pairs(ZONES) do
        out[id] = snapshot(z)
    end
    return out
end

local ZoneService = {}
function ZoneService.GetZones()
    return ZONES
end
function ZoneService.AddClaim(zoneId: string, teamIdx: number, amount: number)
    addClaim(zoneId, teamIdx, amount)
end
return ZoneService
