if Config.Framework ~= 'standalone' then return end

Bridge.GetPlayerData = function()
    return {}
end

Bridge.Notify = function(msg, kind)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(('[%s] %s'):format(kind and kind:upper() or 'INFO', msg))
    EndTextCommandThefeedPostTicker(false, true)
end

Bridge.IsPlayerLoaded = function()
    return true
end
