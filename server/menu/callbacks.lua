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
            flags = SentinelGetFlagCount(id),
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

SentinelRegisterCallback('sentinel:getStats', function(src)
    if not SentinelRequireAdmin(src, 'getStats') then return {} end
    local s = SentinelGetStats()
    return {
        players = #GetPlayers(),
        flags = s.flags,
        kicks = s.kicks,
        bans = s.bans,
        blockedEvents = s.blockedEvents,
        activeBans = #SentinelGetBans(),
    }
end)

SentinelRegisterCallback('sentinel:getBans', function(src)
    if not SentinelRequireAdmin(src, 'getBans') then return {} end
    return SentinelGetBans()
end)

SentinelRegisterCallback('sentinel:getPlayerInfo', function(src, targetId)
    if not SentinelRequireAdmin(src, 'getPlayerInfo') then return nil end
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return nil end

    local flags = {}
    for _, entry in ipairs(SentinelGetRecentFlags()) do
        if entry.src == targetId then flags[#flags + 1] = entry end
    end

    local ped = GetPlayerPed(targetId)
    return {
        id = targetId,
        name = Bridge.GetPlayerName(targetId),
        identifiers = SentinelPublicIdentifiers(targetId),
        tokens = GetNumPlayerTokens(targetId),
        ping = GetPlayerPing(targetId),
        health = ped ~= 0 and GetEntityHealth(ped) or 0,
        armour = ped ~= 0 and GetPedArmour(ped) or 0,
        bypassed = IsSentinelBypassed(targetId),
        flags = flags,
    }
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
    SentinelAudit(src, 'goto', tonumber(targetId))
end)

RegisterNetEvent('sentinel:server:teleportPlayerToMe', function(targetId)
    local src = source
    if not SentinelRequireAdmin(src, 'teleportPlayerToMe') then return end
    targetId = tonumber(targetId)
    local target, me = pedFor(targetId), pedFor(src)
    if not target or not me then return end
    SentinelMarkTrusted(targetId, 3)
    SetEntityCoords(target, GetEntityCoords(me))
    SentinelAudit(src, 'bring', targetId)
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
    SentinelAudit(src, 'heal', targetId)
end)

RegisterNetEvent('sentinel:server:kill', function(targetId)
    local src = source
    if not SentinelRequireAdmin(src, 'kill') then return end
    local target = pedFor(tonumber(targetId))
    if not target then return end
    SetEntityHealth(target, 0)
    SentinelAudit(src, 'kill', tonumber(targetId))
end)

RegisterNetEvent('sentinel:server:freeze', function(targetId, state)
    local src = source
    if not SentinelRequireAdmin(src, 'freeze') then return end
    local target = pedFor(tonumber(targetId))
    if not target then return end
    FreezeEntityPosition(target, state and true or false)
    SentinelAudit(src, state and 'freeze' or 'unfreeze', tonumber(targetId))
end)

RegisterNetEvent('sentinel:server:kick', function(targetId, reason)
    local src = source
    if not SentinelRequireAdmin(src, 'kick') then return end
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return end
    SentinelAudit(src, 'kick', targetId, reason)
    DropPlayer(targetId, ('Kicked by admin: %s'):format(reason or 'No reason specified'))
end)

RegisterNetEvent('sentinel:server:ban', function(targetId, reason, hours)
    local src = source
    if not SentinelRequireAdmin(src, 'ban') then return end
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return end
    SentinelAudit(src, 'ban', targetId, ('%s (%s)'):format(reason or '', (tonumber(hours) or 0) > 0 and (hours .. 'h') or 'permanent'))
    SentinelBanPlayer(targetId, reason, tonumber(hours) or 0, Bridge.GetPlayerName(src))
end)

RegisterNetEvent('sentinel:server:unban', function(banId)
    local src = source
    if not SentinelRequireAdmin(src, 'unban') then return end
    local ok, ban = SentinelUnban(tostring(banId))
    if ok then
        SentinelAudit(src, 'unban', nil, ('%s (%s)'):format(ban.id, ban.name))
        TriggerClientEvent('sentinel:client:notify', src, ('Unbanned %s'):format(ban.name), 'success')
    end
end)

RegisterNetEvent('sentinel:server:startSpectate', function(targetId)
    local src = source
    if not SentinelRequireAdmin(src, 'startSpectate') then return end
    targetId = tonumber(targetId)
    if not pedFor(targetId) then return end

    spectating[src] = targetId
    SentinelAudit(src, 'spectate', targetId)
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
