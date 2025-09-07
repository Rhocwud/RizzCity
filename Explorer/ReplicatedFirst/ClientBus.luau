-- ClientBus.lua
local Bus = {}

-- Set by WarMap
Bus.toggleWarMap = function() end

-- Alerts hookup (Alerts will replace this)
Bus.alert = function(_msg: string, _secs: number?) end

return Bus
