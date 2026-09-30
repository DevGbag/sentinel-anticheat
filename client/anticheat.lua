--[[
Client half of the integrity layer (server half: server/anticheat/clientchecks.lua).
Heartbeat, resource/command injection reporting, and checks that only
have client-side natives: weapon inventory, spectator mode, damage
proofs, vision mods, nametags, player blips, freecam, noclip/fly,
per-model vehicle speed, vehicle godmode, ped alpha.

Everything here can be forged or suppressed by a determined cheat — the
server treats these as extra signal. The heartbeat token rotates every
beat and carries a counter from the check loop, so stopping this script
OR just suspending its checks both show up server-side.
]]

local AC = Config.AntiCheat
local token = nil
local checksRan = 0     -- bumped by the check loop, reported with every heartbeat
local cameraAllowed = false

-- Admin spectate uses a scripted camera (client/menu/nui.lua), so that
-- file flips this to keep the spectate/freecam checks from firing on admins.
SentinelIsSpectating = false

RegisterNetEvent('sentinel:client:init', function(serverToken)
    token = serverToken
end)

-- the server hands out a fresh token with every accepted heartbeat
RegisterNetEvent('sentinel:client:heartbeatAck', function(nextToken)
    token = nextToken
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(500)
    end
    TriggerServerEvent('sentinel:server:clientReady')

    while true do
        Wait(AC.heartbeat.intervalSeconds * 1000)
        if token then
            TriggerServerEvent('sentinel:server:heartbeat', token, checksRan)
        end
    end
end)

-- For resources with legit far-away cameras (CCTV, drones, cinematic tools):
--   exports.sentinel_ac:AllowFreeCamera(true) ... exports.sentinel_ac:AllowFreeCamera(false)
-- This only covers the client camera check; the server-side focus check
-- needs the server export of the same name (the client can't lift it).
exports('AllowFreeCamera', function(state)
    cameraAllowed = state and true or false
end)

-- ============================================================
-- Resource stop / injection
-- ============================================================
AddEventHandler('onClientResourceStop', function(name)
    if name == GetCurrentResourceName() then return end
    -- the whole client tears down on disconnect; only report while we're live
    if GetResourceState(GetCurrentResourceName()) ~= 'started' or not NetworkIsSessionActive() then return end
    TriggerServerEvent('sentinel:server:resourceStopped', name)
end)

local function startedResources()
    local list = {}
    for i = 0, GetNumResources() - 1 do
        local name = GetResourceByFindIndex(i)
        if name and GetResourceState(name) == 'started' then
            list[#list + 1] = name
        end
    end
    return list
end

-- Resources that own a registered command. Executor menus register
-- commands from a resource the server never started.
local blacklistedCommands = {}
for _, name in ipairs(AC.commands.blacklisted) do blacklistedCommands[name:lower()] = true end

local function commandInfo()
    local owners, seen, blacklisted = {}, {}, nil
    if not GetRegisteredCommands then return owners, nil end
    for _, cmd in ipairs(GetRegisteredCommands()) do
        local res = cmd.resource or ''
        if not seen[res] then
            seen[res] = true
            owners[#owners + 1] = res
        end
        if not blacklisted and cmd.name and blacklistedCommands[cmd.name:lower()] then
            blacklisted = cmd.name
        end
    end
    return owners, blacklisted
end

CreateThread(function()
    Wait(30000) -- let everything finish starting
    while true do
        local owners, blacklisted = {}, nil
        if AC.commands.enabled then owners, blacklisted = commandInfo() end
        TriggerServerEvent('sentinel:server:resourceList', startedResources(), owners, blacklisted)
        Wait(60000)
    end
end)

-- ============================================================
-- Check helpers
-- ============================================================
local function report(kind, detail)
    TriggerServerEvent('sentinel:server:clientReport', kind, detail)
end

local reported = {} -- kind -> true while the condition persists, so each episode reports once
local strikes = {}  -- kind -> consecutive samples the condition held

local function check(kind, condition, detail)
    if condition then
        if not reported[kind] then
            reported[kind] = true
            report(kind, type(detail) == 'function' and detail() or detail)
        end
    else
        reported[kind] = nil
    end
end

-- like check(), but the condition must hold for `required` samples in a row
local function strikeCheck(kind, condition, required, detail)
    if condition then
        strikes[kind] = (strikes[kind] or 0) + 1
        if strikes[kind] >= required then
            check(kind, true, detail)
        end
    else
        strikes[kind] = 0
        check(kind, false)
    end
end

local function isLoaded()
    return not Bridge.IsPlayerLoaded or Bridge.IsPlayerLoaded()
end

-- ============================================================
-- Periodic checks (every clientChecks.intervalMs)
-- ============================================================

-- weapons a "give all weapons" menu hands out; no real loadout holds most of these
local COMMON_WEAPONS = {
    `WEAPON_KNIFE`, `WEAPON_NIGHTSTICK`, `WEAPON_HAMMER`, `WEAPON_BAT`, `WEAPON_CROWBAR`,
    `WEAPON_GOLFCLUB`, `WEAPON_BOTTLE`, `WEAPON_DAGGER`, `WEAPON_HATCHET`, `WEAPON_MACHETE`,
    `WEAPON_SWITCHBLADE`, `WEAPON_WRENCH`, `WEAPON_BATTLEAXE`, `WEAPON_POOLCUE`,
    `WEAPON_PISTOL`, `WEAPON_PISTOL_MK2`, `WEAPON_COMBATPISTOL`, `WEAPON_APPISTOL`,
    `WEAPON_PISTOL50`, `WEAPON_SNSPISTOL`, `WEAPON_HEAVYPISTOL`, `WEAPON_VINTAGEPISTOL`,
    `WEAPON_REVOLVER`, `WEAPON_STUNGUN`, `WEAPON_FLAREGUN`,
    `WEAPON_MICROSMG`, `WEAPON_SMG`, `WEAPON_ASSAULTSMG`, `WEAPON_COMBATPDW`, `WEAPON_MACHINEPISTOL`,
    `WEAPON_MINISMG`, `WEAPON_ASSAULTRIFLE`, `WEAPON_CARBINERIFLE`, `WEAPON_ADVANCEDRIFLE`,
    `WEAPON_SPECIALCARBINE`, `WEAPON_BULLPUPRIFLE`, `WEAPON_COMPACTRIFLE`, `WEAPON_MG`,
    `WEAPON_COMBATMG`, `WEAPON_GUSENBERG`, `WEAPON_PUMPSHOTGUN`, `WEAPON_SAWNOFFSHOTGUN`,
    `WEAPON_ASSAULTSHOTGUN`, `WEAPON_BULLPUPSHOTGUN`, `WEAPON_HEAVYSHOTGUN`, `WEAPON_DBSHOTGUN`,
    `WEAPON_SNIPERRIFLE`, `WEAPON_HEAVYSNIPER`, `WEAPON_MARKSMANRIFLE`, `WEAPON_GRENADELAUNCHER`,
    `WEAPON_RPG`, `WEAPON_FIREWORK`, `WEAPON_GRENADE`, `WEAPON_STICKYBOMB`, `WEAPON_MOLOTOV`,
    `WEAPON_PIPEBOMB`, `WEAPON_PROXMINE`, `WEAPON_PETROLCAN`,
}

local function countGamerTags()
    local n = 0
    for id = 0, 255 do
        if IsMpGamerTagActive(id) then n = n + 1 end
    end
    return n
end

local function countPlayerBlips()
    local blipped, total = 0, 0
    local me = PlayerId()
    for _, player in ipairs(GetActivePlayers()) do
        if player ~= me then
            total = total + 1
            if DoesBlipExist(GetBlipFromEntity(GetPlayerPed(player))) then
                blipped = blipped + 1
            end
        end
    end
    return blipped, total
end

CreateThread(function()
    local checks = AC.clientChecks
    while true do
        Wait(checks.intervalMs)
        checksRan = checksRan + 1

        local ped = PlayerPedId()
        if AC.enabled and isLoaded() and DoesEntityExist(ped) and not IsEntityDead(ped) then
            -- character select / spawn screens freeze and hide the ped
            local frozen = IsEntityPositionFrozen(ped)

            if checks.spectatorMode then
                check('spectate', NetworkIsInSpectatorMode() and not SentinelIsSpectating, 'network spectator mode active')
            end

            if checks.visionMods then
                check('visionMods', GetUsingseethrough() or GetUsingnightvision(), 'thermal or night vision active')
            end

            if checks.pedProofs then
                local _, bullet, fire, explosion, _, melee = GetEntityProofs(ped)
                local function on(v) return v == true or v == 1 end
                check('pedProofs', on(bullet) and on(fire) and on(explosion) and on(melee) and not SentinelIsSpectating,
                    'bullet/fire/explosion/melee proofs all set on own ped')
            end

            if not frozen and not SentinelIsSpectating then
                strikeCheck('godmode', not GetEntityCanBeDamaged(ped), 3, 'own ped set to not be damageable')
            end

            if checks.weaponInventory and AC.weapon.enabled then
                local found = nil
                for _, hash in ipairs(AC.weapon.blockedWeaponHashes) do
                    if HasPedGotWeapon(ped, hash, false) then
                        found = hash
                        RemoveWeaponFromPed(ped, hash)
                        break
                    end
                end
                check('weapon', found ~= nil, ('blocked weapon %s in inventory (removed)'):format(found))
            end

            if AC.weaponCount.enabled then
                local held = 0
                for _, hash in ipairs(COMMON_WEAPONS) do
                    if HasPedGotWeapon(ped, hash, false) then held = held + 1 end
                end
                check('weaponCount', held > AC.weaponCount.max, ('holding %d different weapons at once'):format(held))
            end

            if AC.nametags.enabled then
                local tags = countGamerTags()
                check('nametags', tags > AC.nametags.maxActiveTags, ('%d player nametags (gamer tags) active'):format(tags))
            end

            if AC.playerBlips.enabled then
                local blipped, total = countPlayerBlips()
                check('playerBlips', blipped >= AC.playerBlips.minPlayers and blipped >= total * AC.playerBlips.ratio,
                    ('blips on %d of %d other players'):format(blipped, total))
            end

            if AC.pedAlpha.enabled and not frozen and not SentinelIsSpectating then
                local alpha = GetEntityAlpha(ped)
                strikeCheck('invisible', alpha < AC.pedAlpha.minAlpha, 3, ('ped alpha set to %d'):format(alpha))
            end

            if AC.freecam.enabled then
                local dist = #(GetFinalRenderedCamCoord() - GetEntityCoords(ped))
                strikeCheck('freecam',
                    dist > AC.freecam.maxCameraDistance and not cameraAllowed and not SentinelIsSpectating
                        and not IsScreenFadedOut() and not IsPlayerSwitchInProgress(),
                    AC.freecam.requiredStrikes,
                    ('camera %.0fm away from own ped'):format(dist))
            end

            if AC.vehicleGodmode.enabled then
                local veh = GetVehiclePedIsIn(ped, false)
                local driving = veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped
                strikeCheck('vehicleGodmode', driving and not GetEntityCanBeDamaged(veh), 2, 'own vehicle set to not be damageable')
            end
        end
    end
end)

-- ============================================================
-- Fast checks (every second): noclip / fly, vehicle speed
-- ============================================================
local function isGroundVehicle(veh)
    local model = GetEntityModel(veh)
    return IsThisModelACar(model) or IsThisModelABike(model) or IsThisModelAQuadbike(model)
end

CreateThread(function()
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        if AC.enabled and isLoaded() and DoesEntityExist(ped) and not IsEntityDead(ped)
            and not IsEntityPositionFrozen(ped) and not SentinelIsSpectating then

            local veh = GetVehiclePedIsIn(ped, false)

            if AC.noclip.enabled then
                local onFootFree = veh == 0 and not IsEntityAttached(ped)
                local collisionOff = onFootFree and GetEntityCollisionDisabled(ped)
                local hovering = onFootFree
                    and IsEntityInAir(ped)
                    and GetEntityHeightAboveGround(ped) > AC.noclip.hoverHeight
                    and math.abs(GetEntityVelocity(ped).z) < AC.noclip.maxVelocity
                    and not IsPedFalling(ped) and not IsPedRagdoll(ped) and not IsPedClimbing(ped)
                    and not IsPedSwimming(ped) and GetPedParachuteState(ped) == -1
                strikeCheck('noclip', collisionOff or hovering, 3, function()
                    return collisionOff and 'own ped collision disabled'
                        or ('hovering %.0fm above ground without falling'):format(GetEntityHeightAboveGround(ped))
                end)
            end

            if AC.vehicleSpeed.enabled then
                local over, speed, max = false, 0.0, 0.0
                if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and isGroundVehicle(veh) and IsVehicleOnAllWheels(veh) then
                    speed = GetEntitySpeed(veh)
                    max = GetVehicleEstimatedMaxSpeed(veh)
                    over = max > 0 and speed > max * AC.vehicleSpeed.maxRatio
                end
                strikeCheck('vehicleSpeed', over, 3, ('%.0f km/h in a vehicle rated for %.0f km/h'):format(speed * 3.6, max * 3.6))
            end
        end
    end
end)

-- Never called. Cheat menus dump every TriggerServerEvent string they can
-- find in client scripts and fire them looking for exploits; these are the
-- honeypot names registered in server/anticheat/clientchecks.lua.
local function _adminTools()
    TriggerServerEvent('sentinel:server:adminGiveMoney', 1000000)
    TriggerServerEvent('sentinel:server:adminSetJob', 'police', 4)
    TriggerServerEvent('sentinel:server:reviveAll')
    TriggerServerEvent('sentinel:server:giveAllWeapons')
end
