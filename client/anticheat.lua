--[[
Client half of the integrity layer (server half: server/anticheat/clientchecks.lua).
Heartbeat, resource stop/injection reporting, and a few checks that only
have client-side natives (full weapon inventory, spectator mode, damage
proofs, thermal/night vision).

Everything here can be forged or suppressed by a determined cheat — the
server treats these as extra signal, and the heartbeat exists precisely
to notice when this script stops running.
]]

local AC = Config.AntiCheat
local token = nil

-- Admin spectate uses a scripted camera (client/menu/nui.lua), so that
-- file flips this to keep the spectate check from firing on admins.
SentinelIsSpectating = false

RegisterNetEvent('sentinel:client:init', function(serverToken)
    token = serverToken
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(500)
    end
    TriggerServerEvent('sentinel:server:clientReady')

    while true do
        Wait(AC.heartbeat.intervalSeconds * 1000)
        if token then
            TriggerServerEvent('sentinel:server:heartbeat', token)
        end
    end
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

CreateThread(function()
    Wait(30000) -- let everything finish starting
    while true do
        TriggerServerEvent('sentinel:server:resourceList', startedResources())
        Wait(60000)
    end
end)

-- ============================================================
-- Periodic client checks
-- ============================================================
local function report(kind, detail)
    TriggerServerEvent('sentinel:server:clientReport', kind, detail)
end

local reported = {} -- kind -> true while the condition persists, so each episode reports once

local function check(kind, condition, detail)
    if condition then
        if not reported[kind] then
            reported[kind] = true
            report(kind, detail)
        end
    else
        reported[kind] = nil
    end
end

CreateThread(function()
    local checks = AC.clientChecks
    while true do
        Wait(checks.intervalMs)

        local ped = PlayerPedId()
        if AC.enabled and DoesEntityExist(ped) and not IsEntityDead(ped) then
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
