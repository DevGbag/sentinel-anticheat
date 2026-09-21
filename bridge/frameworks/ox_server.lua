if Config.Framework ~= 'ox' then return end

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
    local player = exports.ox_core:GetPlayer(src)
    if not player then return false end
    player.addAccountMoney(account or 'money', tonumber(amount) or 0)
    return true
end

Bridge.GetPlayerName = function(src)
    local player = exports.ox_core:GetPlayer(src)
    return (player and player.name) or GetPlayerName(src)
end

Bridge.IsPlayerLoaded = function(src)
    return exports.ox_core:GetPlayer(src) ~= nil
end
