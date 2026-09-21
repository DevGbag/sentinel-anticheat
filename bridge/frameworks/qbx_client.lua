if Config.Framework ~= 'qbx' then return end

-- qbx_core keeps the qb-core-style Functions API, exported under its own resource name.
local QBX = exports.qbx_core

Bridge.GetPlayerData = function()
    return QBX:GetPlayerData()
end

Bridge.Notify = function(msg, kind)
    if lib then
        lib.notify({ description = msg, type = kind or 'inform' })
    else
        QBX:Notify(msg, kind or 'primary')
    end
end

Bridge.IsPlayerLoaded = function()
    return LocalPlayer.state.isLoggedIn
end
