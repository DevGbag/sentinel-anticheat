if Config.Framework ~= 'qbcore' then return end

local QBCore = exports['qb-core']:GetCoreObject()

Bridge.GetItemList = function()
    local list = {}
    for name, item in pairs(QBCore.Shared.Items) do
        list[name] = { label = item.label or name, weapon = item.type == 'weapon' }
    end
    return list
end

-- Current qb-core moved item handling out of Player.Functions and into
-- qb-inventory's exports; older qb-core still has Player.Functions.AddItem.
local function hasInventoryExports()
    return GetResourceState('qb-inventory') == 'started'
end

Bridge.AddItem = function(src, itemName, count)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    count = math.max(tonumber(count) or 1, 1)
    if hasInventoryExports() then
        local canAdd, reason = exports['qb-inventory']:CanAddItem(src, itemName, count)
        if not canAdd then return false, reason or 'rejected' end
        local ok = exports['qb-inventory']:AddItem(src, itemName, count, false, false, 'sentinel_ac item generator')
        if ok then TriggerClientEvent('qb-inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'add', count) end
        return ok and true or false
    end
    return Player.Functions.AddItem and Player.Functions.AddItem(itemName, count) and true or false
end

Bridge.RemoveItem = function(src, itemName, count)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    count = math.max(tonumber(count) or 1, 1)
    if hasInventoryExports() then
        return exports['qb-inventory']:RemoveItem(src, itemName, count, false, 'sentinel_ac') and true or false
    end
    return Player.Functions.RemoveItem and Player.Functions.RemoveItem(itemName, count) and true or false
end

Bridge.AddMoney = function(src, amount, account)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    return Player.Functions.AddMoney(account or 'cash', tonumber(amount) or 0) and true or false
end

Bridge.GetPlayerName = function(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return GetPlayerName(src) end
    return ('%s %s'):format(Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname)
end

Bridge.IsPlayerLoaded = function(src)
    return QBCore.Functions.GetPlayer(src) ~= nil
end
