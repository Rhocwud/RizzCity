--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local ZoneService = require(script.Parent.ZoneService) -- ModuleScript

local ZonesFolder = workspace:WaitForChild("Zones")

-- Cooldown so we don't spam points if .Touched fires rapidly
local TOUCH_COOLDOWN = 0.35 -- seconds

-- lastTouch[part][userId] = os.clock() timestamp
local lastTouch: { [Instance]: { [number]: number } } = {}

local function teamIndexForPlayer(plr: Player): number
    if not plr.Team then
        return 0
    end
    for i = 1, 4 do
        if Constants.TEAMS[i].Name == plr.Team.Name then
            return i
        end
    end
    return 0
end

local function throttle(part: BasePart, userId: number): boolean
    local now = os.clock()
    local byUser = lastTouch[part]
    if not byUser then
        byUser = {}
        lastTouch[part] = byUser
    end
    local last = byUser[userId] or 0
    if last + TOUCH_COOLDOWN > now then
        return false
    end
    byUser[userId] = now
    return true
end

local function connectCleanup(part: BasePart)
    -- Clean memory when parts are removed
    part.AncestryChanged:Connect(function(_, parent)
        if not parent then
            lastTouch[part] = nil
        end
    end)
end

local function onClaimTouch(claimPart: BasePart, other: BasePart)
    -- Who touched it?
    local char = other and other.Parent
    if not char then
        return
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then
        return
    end
    local plr = Players:GetPlayerFromCharacter(char)
    if not plr then
        return
    end

    -- Validate claimable
    local zoneIdAttr = claimPart:GetAttribute("ZoneId")
    if typeof(zoneIdAttr) ~= "string" or zoneIdAttr == "" then
        return
    end
    local weightAttr = claimPart:GetAttribute("Weight")
    local weight = (typeof(weightAttr) == "number") and (weightAttr :: number) or 1

    -- Throttle per (part, player)
    if not throttle(claimPart, plr.UserId) then
        return
    end

    -- Apply claim
    local teamIdx = teamIndexForPlayer(plr)
    if teamIdx == 0 then
        return
    end

    local CLAIM_POINTS = 0.25 * weight
    ZoneService.AddClaim(zoneIdAttr, teamIdx, CLAIM_POINTS)

    -- Quick visual
    local color = Constants.TEAMS[teamIdx].Color
    claimPart.Color = color
end

local function isClaimablePart(inst: Instance): boolean
    return inst:IsA("BasePart") and typeof(inst:GetAttribute("ZoneId")) == "string"
end

local function connectOne(part: BasePart)
    if not part.CanTouch then
        part.CanTouch = true
    end
    part.Touched:Connect(function(other)
        onClaimTouch(part, other)
    end)
    connectCleanup(part)
end

-- Initial pass: hook every claimable under Zones
for _, desc in ipairs(ZonesFolder:GetDescendants()) do
    if isClaimablePart(desc) then
        connectOne(desc :: BasePart)
    end
end

-- Future-proof: if new claimables appear at runtime
ZonesFolder.DescendantAdded:Connect(function(inst)
    if isClaimablePart(inst) then
        connectOne(inst :: BasePart)
    end
end)
