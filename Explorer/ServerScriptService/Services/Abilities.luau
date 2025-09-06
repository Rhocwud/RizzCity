local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Libraries = require(ReplicatedStorage.Libraries)
local Signal = Libraries.Packages.Signal
local Bezier = require(ReplicatedStorage.Packages.Bezier)
local Functions = require(ReplicatedStorage.Source.Components.InteractiveComponent)

local MainFunctions = ReplicatedStorage.Remotes.MainFunctions
local Output = ReplicatedStorage.Remotes.Output

function quadBezier(p1, p2, p3, t)
	return (1 - t)^2 * p1 + 2 * (1 - t) * t * p2 + t^2 * p3
end


local Abilities
Abilities = {
	
};

return Abilities