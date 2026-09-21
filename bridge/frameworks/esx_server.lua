if Config.Framework ~= 'esx' then return end

local ESX = exports['es_extended']:getSharedObject()

Bridge.GetItemList = function()
    local list = {}
    for name, item in pairs(ESX.GetItems()) do
        list[name] = { label = item.label or name, weapon = false }
    end
    for _, weapon in pairs(ESX.GetWeapons()) do
        list[weapon.name] = { label = weapon.label or weapon.name, weapon = true }
    end
    return list
end

Bridge.AddItem = function(src, itemName, count)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    count = math.max(tonumber(count) or 1, 1)

    if ESX.GetWeapon and ESX.GetWeapon(itemName) then
        xPlayer.addWeapon(itemName, 100)
        return true
    end

    xPlayer.addInventoryItem(itemName, count)
    return true
end

Bridge.RemoveItem = function(src, itemName, count)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    xPlayer.removeInventoryItem(itemName, math.max(tonumber(count) or 1, 1))
    return true
end

Bridge.AddMoney = function(src, amount, account)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    amount = tonumber(amount) or 0
    if account and account ~= 'cash' and account ~= 'money' then
        xPlayer.addAccountMoney(account, amount)
    else
        xPlayer.addMoney(amount)
    end
    return true
end

Bridge.GetPlayerName = function(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    return (xPlayer and xPlayer.getName()) or GetPlayerName(src)
end

Bridge.IsPlayerLoaded = function(src)
    return ESX.GetPlayerFromId(src) ~= nil
end
