RegisterNUICallback('close', function(_, cb)
    CloseMenu()
    cb({})
end)

RegisterNUICallback('refreshPlayers', function(_, cb)
    SentinelTriggerCallback('sentinel:getPlayers', function(players)
        SendNUIMessage({ action = 'players', data = players })
    end)
    cb({})
end)

RegisterNUICallback('refreshLogs', function(_, cb)
    SentinelTriggerCallback('sentinel:getLogs', function(logs)
        SendNUIMessage({ action = 'logs', data = logs })
    end)
    cb({})
end)

RegisterNUICallback('refreshBans', function(_, cb)
    SentinelTriggerCallback('sentinel:getBans', function(bans)
        SendNUIMessage({ action = 'bans', data = bans })
    end)
    SentinelTriggerCallback('sentinel:getStats', function(stats)
        SendNUIMessage({ action = 'stats', data = stats })
    end)
    cb({})
end)

RegisterNUICallback('refreshStats', function(_, cb)
    SentinelTriggerCallback('sentinel:getStats', function(stats)
        SendNUIMessage({ action = 'stats', data = stats })
    end)
    cb({})
end)

RegisterNUICallback('playerInfo', function(data, cb)
    SentinelTriggerCallback('sentinel:getPlayerInfo', function(info)
        SendNUIMessage({ action = 'playerInfo', data = info })
    end, data.id)
    cb({})
end)

RegisterNUICallback('unban', function(data, cb)
    TriggerServerEvent('sentinel:server:unban', data.banId)
    SetTimeout(500, function()
        SentinelTriggerCallback('sentinel:getBans', function(bans)
            SendNUIMessage({ action = 'bans', data = bans })
        end)
    end)
    cb({})
end)

RegisterNUICallback('screenshot', function(data, cb)
    TriggerServerEvent('sentinel:server:requestScreenshot', data.id)
    cb({})
end)

RegisterNetEvent('sentinel:client:screenshot', function(targetId, dataUri)
    SendNUIMessage({ action = 'screenshot', id = targetId, data = dataUri })
end)

RegisterNUICallback('teleportToPlayer', function(data, cb)
    TriggerServerEvent('sentinel:server:teleportToPlayer', data.id)
    cb({})
end)

RegisterNUICallback('teleportPlayerToMe', function(data, cb)
    TriggerServerEvent('sentinel:server:teleportPlayerToMe', data.id)
    cb({})
end)

RegisterNUICallback('heal', function(data, cb)
    TriggerServerEvent('sentinel:server:heal', data.id)
    cb({})
end)

RegisterNUICallback('kill', function(data, cb)
    TriggerServerEvent('sentinel:server:kill', data.id)
    cb({})
end)

RegisterNUICallback('freeze', function(data, cb)
    TriggerServerEvent('sentinel:server:freeze', data.id, data.state)
    cb({})
end)

RegisterNUICallback('kick', function(data, cb)
    TriggerServerEvent('sentinel:server:kick', data.id, data.reason)
    cb({})
end)

RegisterNUICallback('ban', function(data, cb)
    TriggerServerEvent('sentinel:server:ban', data.id, data.reason, data.hours)
    cb({})
end)

RegisterNUICallback('giveItem', function(data, cb)
    TriggerServerEvent('sentinel:server:giveItem', data.id, data.item, data.count)
    cb({})
end)

RegisterNUICallback('startSpectate', function(data, cb)
    TriggerServerEvent('sentinel:server:startSpectate', data.id)
    cb({})
end)

RegisterNUICallback('stopSpectate', function(_, cb)
    TriggerServerEvent('sentinel:server:stopSpectate')
    cb({})
end)

RegisterNetEvent('sentinel:client:newFlag', function(entry)
    SendNUIMessage({ action = 'newFlag', data = entry })
end)

-- Spectate camera: the server streams the target's coords/heading and we
-- drive a detached scripted cam, rather than moving our own ped, so leaving
-- spectate never leaves the admin displaced or desynced.
local spectateCam = nil
local spectating = false

RegisterNetEvent('sentinel:client:spectateStart', function()
    spectating = true
    SentinelIsSpectating = true
    local myPed = PlayerPedId()
    FreezeEntityPosition(myPed, true)
    SetEntityVisible(myPed, false, false)
    SetEntityInvincible(myPed, true)

    spectateCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamActive(spectateCam, true)
    RenderScriptCams(true, true, 500, true, true)
end)

RegisterNetEvent('sentinel:client:spectateUpdate', function(coords, heading)
    if not spectating or not spectateCam then return end
    SetCamCoord(spectateCam, coords.x, coords.y, coords.z + 2.0)
    SetCamRot(spectateCam, 0.0, 0.0, heading, 2)
end)

RegisterNetEvent('sentinel:client:spectateStop', function()
    spectating = false
    SentinelIsSpectating = false
    local myPed = PlayerPedId()
    FreezeEntityPosition(myPed, false)
    SetEntityVisible(myPed, true, false)
    SetEntityInvincible(myPed, false)

    if spectateCam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(spectateCam, false)
        spectateCam = nil
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if spectating then
        TriggerEvent('sentinel:client:spectateStop')
    end
end)
