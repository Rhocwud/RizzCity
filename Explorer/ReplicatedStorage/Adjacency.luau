--!strict
--====================================================--
--  Script: [Adjacency]
--  Location: [ReplicatedStorage/Shared/]
--  Version: 1.0.0
--  Last Updated: 2025-09-06
--  Author: Rhocwud Games
--
--  Description:
--      [Marks whether a Zone is touching another Zone by what Team]
--
--  Change Log:
--      v1.0.0 - Initial version
--
--====================================================--

local Adjacency = {}

local rows = {"A","B","C","D"}

local function inBounds(r: number, c: number): boolean
	return r >= 1 and r <= 4 and c >= 1 and c <= 4
end

local function parseId(id: string)
	-- Accept A1..D4 (any trailing chars after the first number are ignored)
	local row = string.sub(id, 1, 1)
	local colStr = string.sub(id, 2)
	local col = tonumber(colStr)
	local rIndex = table.find(rows, row)
	if rIndex and col then
		return rIndex, col
	end
	return nil, nil
end

function Adjacency.GetNeighbors(id: string): {string}
	local r, c = parseId(id)
	if not r or not c then return {} end
	local list = {}
	local candidates = {
		{r-1, c}, {r+1, c}, {r, c-1}, {r, c+1} -- orthogonal only
	}
	for _, rc in ipairs(candidates) do
		if inBounds(rc[1], rc[2]) then
			table.insert(list, rows[rc[1]] .. tostring(rc[2]))
		end
	end
	return list
end

return Adjacency
