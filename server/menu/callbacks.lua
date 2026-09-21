local spectating = {} -- adminSrc -> targetSrc, drives the streaming loop below

SentinelRegisterCallback('sentinel:isAdmin', function(src)
    return IsSentinelAdmin(src)
end)

SentinelRegisterCallback('sentinel:getPlayers', function(src)
    if not SentinelRequireAdmin(src, 'getPlayers') then return {} end

    local list = {}
    for _, strId in ipairs(GetPlayers()) do
        local id = tonumber(strId)
        list[#list + 1] = {
            id = id,
            name = Bridge.GetPlayerName(id),
            ping = GetPlayerPing(id),
        }
    end
    return list
end)

SentinelRegisterCallback('sentinel:getItems', function(src)
    if not SentinelRequireAdmin(src, 'getItems') then return {} end
    return Bridge.GetItemList()
end)

SentinelRegisterCallback('sentinel:getLogs', function(src)
    if not SentinelRequireAdmin(src, 'getLogs') then return {} end
    return SentinelGetRecentFlags()
end)

local function pedFor(id)
    local ped = GetPlayerPed(id)
    if ped and ped ~= 0 then return ped end
    return nil
end

RegisterNetEvent('sentinel:server:teleportToPlayer', function(targetId)
    local src = source
    if not SentinelRequireAdmin(src, 'teleportToPlayer') then return end
    local target, me = pedFor(tonumber(targetId)), pedFor(src)
    if not target or not me then return end
    SentinelMarkTrusted(src, 3)
    SetEntityCoords(me, GetEntityCoords(target))
end)

RegisterNetEvent('sentinel:server:teleportPlayerToMe', function(targetId)
    local src = source
    if not SentinelRequireAdmin(src, 'teleportPlayerToMe') then return end
    targetId = tonumber(targetId)
    local target, me = pedFor(targetId), pedFor(src)
    if not target or not me then return end
    SentinelMarkTrusted(targetId, 3)
    SetEntityCoords(target, GetEntityCoords(me))
end)

RegisterNetEvent('sentinel:server:heal', function(targetId)
    local src = source
    if not SentinelRequireAdmin(src, 'heal') then return end
    targetId = tonumber(targetId)
    local target = pedFor(targetId)
    if not target then return end
    SentinelMarkTrusted(targetId, 3)
    SetEntityHealth(target, GetEntityMaxHealth(target))
    SetPedArmour(target, 100)
end)

RegisterNetEvent('sentinel:server:kill', function(targetId)
    local src = source
    if not SentinelRequireAdmin(src, 'kill') then return end
    local target = pedFor(tonumber(targetId))
    if not target then return end
    SetEntityHealth(target, 0)
end)

RegisterNetEvent('sentinel:server:freeze', function(targetId, state)
    local src = source
    if not SentinelRequireAdmin(src, 'freeze') then return end
    local target = pedFor(tonumber(targetId))
    if not target then return end
    FreezeEntityPosition(target, state and true or false)
end)

RegisterNetEvent('sentinel:server:kick', function(targetId, reason)
    local src = source
    if not SentinelRequireAdmin(src, 'kick') then return end
    DropPlayer(tonumber(targetId), ('Kicked by admin: %s'):format(reason or 'No reason specified'))
end)

RegisterNetEvent('sentinel:server:ban', function(targetId, reason, hours)
    local src = source
    if not SentinelRequireAdmin(src, 'ban') then return end
    SentinelBanPlayer(tonumber(targetId), reason, tonumber(hours) or 0, Bridge.GetPlayerName(src))
end)

RegisterNetEvent('sentinel:server:startSpectate', function(targetId)
    local src = source
    if not SentinelRequireAdmin(src, 'startSpectate') then return end
    targetId = tonumber(targetId)
    if not pedFor(targetId) then return end

    spectating[src] = targetId
    TriggerClientEvent('sentinel:client:spectateStart', src)

    CreateThread(function()
        while spectating[src] == targetId do
            local targetPed = pedFor(targetId)
            if not targetPed or not pedFor(src) then
                break
            end
            TriggerClientEvent('sentinel:client:spectateUpdate', src, GetEntityCoords(targetPed), GetEntityHeading(targetPed))
            Wait(200)
        end

        if spectating[src] == targetId then
            spectating[src] = nil
        end
    end)
end)

RegisterNetEvent('sentinel:server:stopSpectate', function()
    local src = source
    if spectating[src] then
        spectating[src] = nil
        TriggerClientEvent('sentinel:client:spectateStop', src)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    spectating[src] = nil
end)
