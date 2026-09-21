if Config.Framework ~= 'qbx' then return end

-- qbx_core servers pair with ox_inventory for item storage almost universally,
-- so the item list and give/remove calls go through ox_inventory's exports.

Bridge.GetItemList = function()
    local list = {}
    local items = exports.ox_inventory:Items() or {}
    for name, item in pairs(items) do
        list[name] = { label = item.label or name, weapon = item.weapon == true }
    end
    return list
end

Bridge.AddItem = function(src, itemName, count)
    return exports.ox_inventory:AddItem(src, itemName, math.max(tonumber(count) or 1, 1)) and true or false
end

Bridge.RemoveItem = function(src, itemName, count)
    return exports.ox_inventory:RemoveItem(src, itemName, math.max(tonumber(count) or 1, 1)) and true or false
end

Bridge.AddMoney = function(src, amount, account)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end
    return player.Functions.AddMoney(account or 'cash', tonumber(amount) or 0) and true or false
end

Bridge.GetPlayerName = function(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return GetPlayerName(src) end
    return ('%s %s'):format(player.PlayerData.charinfo.firstname, player.PlayerData.charinfo.lastname)
end

Bridge.IsPlayerLoaded = function(src)
    return exports.qbx_core:GetPlayer(src) ~= nil
end
