CreateThread(function()
    Wait(500)
    print(('^3[sentinel_ac]^7 loaded — framework: ^2%s^7, admin ACE permission: ^2%s^7'):format(Config.Framework, Config.AcePermission))
    if #Config.FallbackAdminIdentifiers == 0 then
        print('^3[sentinel_ac]^7 No fallback admin identifiers configured. Make sure the ACE permission is granted via server.cfg or you will be locked out of the admin menu.')
    end
end)

-- Minimal request/response RPC over events. No framework's callback library
-- is assumed to be present (this resource must work with Config.Framework
-- set to 'standalone'), so it ships its own.
local callbacks = {}

function SentinelRegisterCallback(name, fn)
    callbacks[name] = fn
end

RegisterNetEvent('sentinel:server:triggerCallback', function(name, requestId, ...)
    local src = source
    local fn = callbacks[name]
    if not fn then return end
    local result = { fn(src, ...) }
    TriggerClientEvent('sentinel:client:callbackResponse', src, requestId, result)
end)
