if Config.Framework ~= 'qbcore' then return end

local QBCore = exports['qb-core']:GetCoreObject()

Bridge.GetItemList = function()
    local list = {}
    for name, item in pairs(QBCore.Shared.Items) do
        list[name] = { label = item.label or name, weapon = item.type == 'weapon' }
    end
    return list
end

Bridge.AddItem = function(src, itemName, count)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    return Player.Functions.AddItem(itemName, math.max(tonumber(count) or 1, 1)) and true or false
end

Bridge.RemoveItem = function(src, itemName, count)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    return Player.Functions.RemoveItem(itemName, math.max(tonumber(count) or 1, 1)) and true or false
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
