if Config.Framework ~= 'esx' then return end

local ESX = exports['es_extended']:getSharedObject()

Bridge.GetPlayerData = function()
    return ESX.GetPlayerData()
end

Bridge.Notify = function(msg, kind)
    ESX.ShowNotification(msg)
end

Bridge.IsPlayerLoaded = function()
    return ESX.IsPlayerLoaded and ESX.IsPlayerLoaded() or (ESX.GetPlayerData().identifier ~= nil)
end
