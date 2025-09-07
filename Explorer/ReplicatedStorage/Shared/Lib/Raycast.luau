--!strict
-- ReplicatedStorage/Shared/Lib/Raycast.lua
local PhysicsService = game:GetService("PhysicsService")
local Workspace = game:GetService("Workspace")

export type Params = {
	origin: Vector3,
	direction: Vector3,
	maxDistance: number?,
	ignore: {Instance}?,
	whitelist: {Instance}?,
	collisionGroup: string?,
}

local M = {}

function M.params(opts: Params): RaycastParams
	local p = RaycastParams.new()
	if opts.whitelist and #opts.whitelist > 0 then
		p.FilterType = Enum.RaycastFilterType.Whitelist
		p.FilterDescendantsInstances = opts.whitelist
	else
		p.FilterType = Enum.RaycastFilterType.Exclude
		p.FilterDescendantsInstances = opts.ignore or {}
	end
	if opts.collisionGroup then
		p.CollisionGroup = opts.collisionGroup
	end
	p.IgnoreWater = true
	return p
end

function M.cast(opts: Params)
	local dir = opts.direction
	if opts.maxDistance then
		dir = dir.Unit * opts.maxDistance
	end
	return Workspace:Raycast(opts.origin, dir, M.params(opts))
end

return M

