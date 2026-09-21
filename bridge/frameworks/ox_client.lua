if Config.Framework ~= 'ox' then return end

-- Requires ox_lib (for lib.notify) and ox_core as start-order dependencies.

Bridge.GetPlayerData = function()
    return exports.ox_core:GetPlayer() or {}
end

Bridge.Notify = function(msg, kind)
    if lib then
        lib.notify({ description = msg, type = kind or 'inform' })
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandThefeedPostTicker(false, true)
    end
end

Bridge.IsPlayerLoaded = function()
    return exports.ox_core:GetPlayer() ~= nil
end
