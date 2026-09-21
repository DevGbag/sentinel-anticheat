RegisterNetEvent('sentinel:server:giveItem', function(targetId, itemName, count)
    local src = source
    if not SentinelRequireAdmin(src, 'giveItem') then return end

    targetId = tonumber(targetId)
    count = tonumber(count) or 1

    if not targetId or not GetPlayerName(targetId) then
        TriggerClientEvent('sentinel:client:notify', src, 'Invalid target player.', 'error')
        return
    end

    local items = Bridge.GetItemList()
    if not items[itemName] then
        TriggerClientEvent('sentinel:client:notify', src, ('Unknown item "%s" for the active framework bridge.'):format(itemName), 'error')
        return
    end

    local ok = Bridge.AddItem(targetId, itemName, count)
    if ok then
        local label = items[itemName].label or itemName
        TriggerClientEvent('sentinel:client:notify', src, ('Gave %sx %s to %s'):format(count, label, Bridge.GetPlayerName(targetId)), 'success')
        if targetId ~= src then
            TriggerClientEvent('sentinel:client:notify', targetId, ('You received %sx %s from an admin'):format(count, label), 'success')
        end
    else
        TriggerClientEvent('sentinel:client:notify', src, ('Failed to give "%s" — bridge rejected it.'):format(itemName), 'error')
    end
end)
