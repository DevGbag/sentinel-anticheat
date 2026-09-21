if Config.Framework ~= 'qbcore' then return end

local QBCore = exports['qb-core']:GetCoreObject()

Bridge.GetPlayerData = function()
    return QBCore.Functions.GetPlayerData()
end

Bridge.Notify = function(msg, kind)
    QBCore.Functions.Notify(msg, kind or 'primary')
end

Bridge.IsPlayerLoaded = function()
    return LocalPlayer.state.isLoggedIn
end
