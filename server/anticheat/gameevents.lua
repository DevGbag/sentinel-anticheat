--[[
OneSync game-event firewall. These events fire on the server when a
client asks to do something that affects other players — spawn an
entity, cause an explosion, deal damage, give a weapon — BEFORE it is
replicated to anyone else. CancelEvent() drops it, so blocked spawns and
explosions never appear for other players at all.

Requires OneSync (onesync on / legacy / infinity), like the rest of this resource.
]]

local AC = Config.AntiCheat

local function toSet(list)
    local set = {}
    for _, v in ipairs(list or {}) do set[v] = true end
    return set
end

local blacklistedModels = toSet(AC.entities.blacklistedModels)
local blockedExplosions = toSet(AC.explosions.blockedTypes)
local blockedWeapons = toSet(AC.weapon.blockedWeaponHashes)
local exemptDamageWeapons = toSet(AC.weaponDamage.exemptWeapons)

local ENTITY_TYPE_NAMES = { [1] = 'ped', [2] = 'vehicle', [3] = 'object' }
local POPTYPE_MISSION = 7 -- created by a script (as opposed to ambient traffic/peds)

local function block(src, kind, detail)
    CancelEvent()
    SentinelCountBlockedEvent()
    if src and src > 0 then
        SentinelFlag(src, kind, detail)
    end
end

-- ============================================================
-- Entity spawns
-- ============================================================
AddEventHandler('entityCreating', function(entity)
    if not AC.enabled or not AC.entities.enabled then return end

    local owner = NetworkGetFirstEntityOwner(entity)
    if not owner or owner <= 0 then return end -- server-created
    if IsSentinelBypassed(owner) then return end

    local model = GetEntityModel(entity)
    local entType = GetEntityType(entity)
    local typeName = ENTITY_TYPE_NAMES[entType] or 'entity'

    if blacklistedModels[model] then
        block(owner, 'entityBlacklist', ('tried to spawn blacklisted %s (model %s)'):format(typeName, model))
        return
    end

    -- rate limits only apply to script-spawned entities; ambient traffic
    -- and pedestrians are created by whoever owns that area of the map
    if GetEntityPopulationType(entity) ~= POPTYPE_MISSION then return end

    local cfg = AC.entities
    local limit = (entType == 2 and cfg.maxVehiclesPerWindow)
        or (entType == 1 and cfg.maxPedsPerWindow)
        or cfg.maxObjectsPerWindow

    if SentinelRateLimit(owner, 'spawn:' .. typeName, limit, cfg.rateWindowMs) then
        block(owner, 'entitySpam', ('spawned more than %d %ss in %ds'):format(limit, typeName, cfg.rateWindowMs // 1000))
    end
end)

-- ============================================================
-- Explosions
-- ============================================================
AddEventHandler('explosionEvent', function(sender, ev)
    sender = tonumber(sender)
    local cfg = AC.explosions
    if not AC.enabled or not cfg.enabled or IsSentinelBypassed(sender) then return end

    if blockedExplosions[ev.explosionType] then
        block(sender, 'explosion', ('blocked explosion type %s'):format(ev.explosionType))
    elseif cfg.blockInvisible and ev.isInvisible then
        block(sender, 'explosion', ('invisible explosion (type %s)'):format(ev.explosionType))
    elseif (ev.damageScale or 1.0) > cfg.maxDamageScale then
        block(sender, 'explosion', ('explosion damage scale x%.1f'):format(ev.damageScale))
    elseif SentinelRateLimit(sender, 'explosion', cfg.maxPerWindow, cfg.rateWindowMs) then
        block(sender, 'explosionSpam', ('more than %d explosions in %.1fs'):format(cfg.maxPerWindow, cfg.rateWindowMs / 1000))
    end
end)

-- ============================================================
-- Particle effects (ptfx spam is used to lag/crash other clients)
-- ============================================================
AddEventHandler('ptFxEvent', function(sender, data)
    sender = tonumber(sender)
    local cfg = AC.particles
    if not AC.enabled or not cfg.enabled or IsSentinelBypassed(sender) then return end

    if (data.scale or 1.0) > cfg.maxScale then
        block(sender, 'particles', ('particle effect at scale x%.1f'):format(data.scale))
    elseif SentinelRateLimit(sender, 'ptfx', cfg.maxPerWindow, cfg.rateWindowMs) then
        block(sender, 'particles', ('more than %d particle effects in %.1fs'):format(cfg.maxPerWindow, cfg.rateWindowMs / 1000))
    end
end)

-- ============================================================
-- Projectiles (rockets/grenades spawned out of nowhere)
-- ============================================================
AddEventHandler('startProjectileEvent', function(sender, data)
    sender = tonumber(sender)
    local cfg = AC.projectiles
    if not AC.enabled or not cfg.enabled or IsSentinelBypassed(sender) then return end

    if blockedWeapons[data.weaponHash] then
        block(sender, 'weapon', ('fired projectile from blocked weapon %s'):format(data.weaponHash))
    elseif SentinelRateLimit(sender, 'projectile', cfg.maxPerWindow, cfg.rateWindowMs) then
        block(sender, 'projectiles', ('more than %d projectiles in %.1fs'):format(cfg.maxPerWindow, cfg.rateWindowMs / 1000))
    end
end)

-- ============================================================
-- Fires
-- ============================================================
AddEventHandler('fireEvent', function(sender)
    sender = tonumber(sender)
    local cfg = AC.fires
    if not AC.enabled or not cfg.enabled or IsSentinelBypassed(sender) then return end

    if SentinelRateLimit(sender, 'fire', cfg.maxPerWindow, cfg.rateWindowMs) then
        block(sender, 'fires', ('started more than %d fires in %.1fs'):format(cfg.maxPerWindow, cfg.rateWindowMs / 1000))
    end
end)

-- ============================================================
-- Weapon damage (damage modifiers, blacklisted weapons, "kill all", long-range hits)
-- ============================================================
AddEventHandler('weaponDamageEvent', function(sender, data)
    sender = tonumber(sender)
    local cfg = AC.weaponDamage
    if not AC.enabled or not cfg.enabled or IsSentinelBypassed(sender) then return end

    local weapon = data.weaponType

    if AC.weapon.enabled and blockedWeapons[weapon] then
        block(sender, 'weapon', ('dealt damage with blocked weapon %s'):format(weapon))
        return
    end

    if not exemptDamageWeapons[weapon] and (data.weaponDamage or 0) > cfg.maxDamagePerHit then
        block(sender, 'weaponDamage', ('dealt %d damage in one hit (weapon %s)'):format(data.weaponDamage, weapon))
        return
    end

    local victim = NetworkGetEntityFromNetworkId(data.hitGlobalId or (data.hitGlobalIds and data.hitGlobalIds[1]) or 0)
    local shooterPed = GetPlayerPed(sender)
    if victim and victim ~= 0 and shooterPed and shooterPed ~= 0 and IsPedAPlayer(victim) then
        local dist = #(GetEntityCoords(shooterPed) - GetEntityCoords(victim))
        if dist > cfg.maxHitDistance and not exemptDamageWeapons[weapon] then
            block(sender, 'hitDistance', ('hit a player %.0fm away'):format(dist))
            return
        end

        if data.willKill and SentinelRateLimit(sender, 'kills', cfg.maxKillsPerWindow, cfg.killWindowMs) then
            SentinelFlag(sender, 'killSpam', ('killed more than %d players in %ds'):format(cfg.maxKillsPerWindow, cfg.killWindowMs // 1000))
        end
    end
end)

-- ============================================================
-- Weapon tampering on other players
-- ============================================================
local function isForeignPlayerPed(sender, pedNetId)
    local ped = NetworkGetEntityFromNetworkId(pedNetId or 0)
    return ped and ped ~= 0 and IsPedAPlayer(ped) and ped ~= GetPlayerPed(sender)
end

AddEventHandler('giveWeaponEvent', function(sender, data)
    sender = tonumber(sender)
    if not AC.enabled or not AC.weaponTampering.enabled or IsSentinelBypassed(sender) then return end
    if isForeignPlayerPed(sender, data.pedId) then
        block(sender, 'giveWeapon', ('tried to give weapon %s to another player'):format(data.weaponType))
    end
end)

AddEventHandler('removeWeaponEvent', function(sender, data)
    sender = tonumber(sender)
    if not AC.enabled or not AC.weaponTampering.enabled or IsSentinelBypassed(sender) then return end
    if isForeignPlayerPed(sender, data.pedId) then
        block(sender, 'removeWeapon', ('tried to remove weapon %s from another player'):format(data.weaponType))
    end
end)

AddEventHandler('removeAllWeaponsEvent', function(sender, data)
    sender = tonumber(sender)
    if not AC.enabled or not AC.weaponTampering.enabled or IsSentinelBypassed(sender) then return end
    if isForeignPlayerPed(sender, data.pedId) then
        block(sender, 'removeWeapon', 'tried to strip all weapons from another player')
    end
end)

-- ============================================================
-- Clear ped tasks (yanking people out of vehicles / freezing them)
-- ============================================================
AddEventHandler('clearPedTasksEvent', function(sender, data)
    sender = tonumber(sender)
    local cfg = AC.clearTasks
    if not AC.enabled or not cfg.enabled or IsSentinelBypassed(sender) then return end
    if not isForeignPlayerPed(sender, data.pedId) then return end

    if cfg.cancel then
        CancelEvent()
        SentinelCountBlockedEvent()
    end
    SentinelFlag(sender, 'clearTasks', ('cleared another player\'s tasks%s'):format(data.immediately and ' (immediately)' or ''))
end)
