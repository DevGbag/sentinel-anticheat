if Config.Framework ~= 'standalone' then return end

-- Standalone has no inventory system to hook, so the item generator falls
-- back to native weapon/armor/health grants only.
local NATIVE_ITEMS = {
    WEAPON_PISTOL = { label = 'Pistol', weapon = true },
    WEAPON_COMBATPISTOL = { label = 'Combat Pistol', weapon = true },
    WEAPON_SMG = { label = 'SMG', weapon = true },
    WEAPON_ASSAULTRIFLE = { label = 'Assault Rifle', weapon = true },
    WEAPON_PUMPSHOTGUN = { label = 'Pump Shotgun', weapon = true },
    WEAPON_CARBINERIFLE = { label = 'Carbine Rifle', weapon = true },
    WEAPON_KNIFE = { label = 'Knife', weapon = true },
    armor = { label = 'Armor (100)', weapon = false },
    health = { label = 'Full Heal', weapon = false },
}

Bridge.GetItemList = function()
    return NATIVE_ITEMS
end

Bridge.AddItem = function(src, itemName, count)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end

    if itemName == 'armor' then
        SetPedArmour(ped, 100)
        return true
    elseif itemName == 'health' then
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
        return true
    elseif NATIVE_ITEMS[itemName] and NATIVE_ITEMS[itemName].weapon then
        GiveWeaponToPed(ped, GetHashKey(itemName), math.max(tonumber(count) or 1, 1) * 50, false, false)
        return true
    end

    return false
end

Bridge.RemoveItem = function(src, itemName, count)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    if NATIVE_ITEMS[itemName] and NATIVE_ITEMS[itemName].weapon then
        RemoveWeaponFromPed(ped, GetHashKey(itemName))
        return true
    end
    return false
end

Bridge.AddMoney = function(src, amount, account)
    return false -- no economy system in standalone mode
end

Bridge.GetPlayerName = function(src)
    return GetPlayerName(src) or ('Unknown[' .. src .. ']')
end

Bridge.IsPlayerLoaded = function(src)
    return GetPlayerPed(src) ~= 0
end
