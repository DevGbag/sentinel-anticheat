-- Minimal request/response RPC over events, mirroring the registry in server/main.lua.
local pending = {}
local nextRequestId = 0

RegisterNetEvent('sentinel:client:callbackResponse', function(requestId, result)
    local cb = pending[requestId]
    if cb then
        pending[requestId] = nil
        cb(table.unpack(result))
    end
end)

function SentinelTriggerCallback(name, cb, ...)
    nextRequestId = nextRequestId + 1
    local requestId = nextRequestId
    pending[requestId] = cb
    TriggerServerEvent('sentinel:server:triggerCallback', name, requestId, ...)
end

local menuOpen = false

function OpenMenu()
    menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', selfId = GetPlayerServerId(PlayerId()) })

    SentinelTriggerCallback('sentinel:getPlayers', function(players)
        SendNUIMessage({ action = 'players', data = players })
    end)
    SentinelTriggerCallback('sentinel:getItems', function(items)
        SendNUIMessage({ action = 'items', data = items })
    end)
    SentinelTriggerCallback('sentinel:getLogs', function(logs)
        SendNUIMessage({ action = 'logs', data = logs })
    end)
end

function CloseMenu()
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    TriggerServerEvent('sentinel:server:stopSpectate') -- no-op if not spectating
end

function ToggleMenu()
    if menuOpen then
        CloseMenu()
        return
    end

    SentinelTriggerCallback('sentinel:isAdmin', function(isAdmin)
        if not isAdmin then
            Bridge.Notify('You do not have permission to open this menu.', 'error')
            return
        end
        OpenMenu()
    end)
end

RegisterCommand('sentinel_openmenu', function()
    ToggleMenu()
end, false)
RegisterKeyMapping('sentinel_openmenu', 'Open Sentinel Admin Menu', 'keyboard', Config.MenuKeybind)

RegisterNetEvent('sentinel:client:notify', function(msg, kind)
    Bridge.Notify(msg, kind)
end)
