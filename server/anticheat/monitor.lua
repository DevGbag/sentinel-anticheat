--[[
Server-authoritative polling anticheat. Every check here reads native
player state (GetEntityCoords, GetEntityHealth, ...) directly from the
server, which under OneSync reflects the real synced state of the
entity — a modified client can't just lie about it the way it could lie
about a client-reported "I am not cheating" event.

Detections require `Config.AntiCheat.requiredStrikes` consecutive over-
threshold samples before flagging (some checks have their own, larger
count), which absorbs lag spikes and legit teleports/heals performed
through the admin menu (those also mark the player "trusted" for a few
seconds via SentinelMarkTrusted).
]]

local playerState = {}
local strikes = {}
local trustedUntil = {}
local weaponFlagged = {}
local wasLoaded = {}

local AC = Config.AntiCheat

local function addStrike(src, kind)
    strikes[src] = strikes[src] or {}
    strikes[src][kind] = (strikes[src][kind] or 0) + 1
    return strikes[src][kind]
end

local function resetStrike(src, kind)
    if strikes[src] then
        strikes[src][kind] = 0
    end
end

-- Flags `kind` once `condition` has held for `required` consecutive polls.
local function strikeCheck(src, kind, condition, required, detail)
    if condition then
        if addStrike(src, kind) >= (required or AC.requiredStrikes) then
            SentinelFlag(src, kind, type(detail) == 'function' and detail() or detail)
            resetStrike(src, kind)
        end
    else
        resetStrike(src, kind)
    end
end

function SentinelMarkTrusted(src, seconds)
    trustedUntil[src] = GetGameTimer() + ((seconds or 3) * 1000)
end

local function isTrusted(src)
    return trustedUntil[src] ~= nil and GetGameTimer() < trustedUntil[src]
end

local blockedPedModels = {}
for _, hash in ipairs(AC.pedModel.blockedModels) do
    blockedPedModels[hash] = true
end

local function checkMovement(src, ped, coords, now, last)
    local dt = (now - last.time) / 1000.0
    if dt <= 0 then return end

    local dist = #(coords - last.coords)

    if AC.teleport.enabled then
        strikeCheck(src, 'teleport', dist > AC.teleport.maxDistancePerPoll, nil,
            ('moved %.1fm in %.1fs'):format(dist, dt))
    end

    if AC.speed.enabled then
        local speed = dist / dt
        local veh = GetVehiclePedIsIn(ped, false)
        -- flat cap, not per-model: GetVehicleModelEstimatedMaxSpeed only exists client-side
        local limit = (veh and veh ~= 0) and AC.speed.maxVehicleSpeed or AC.speed.maxOnFootSpeed
        strikeCheck(src, 'speed', speed > limit, nil,
            ('%.1fm/s over limit of %.1fm/s'):format(speed, limit))
    end
end

local function checkHealth(src, ped, health, last)
    if not AC.health.enabled then return end

    if last and last.health then
        local jump = health - last.health
        strikeCheck(src, 'health', jump >= AC.health.instantHealThreshold, nil,
            ('healed %d hp in one tick with no admin action behind it'):format(jump))
    end

    local maxHealth = GetEntityMaxHealth(ped)
    local armour = GetPedArmour(ped)
    strikeCheck(src, 'armour', health > maxHealth or armour > AC.health.maxArmour, nil, function()
        return ('health %d/%d, armour %d/%d'):format(health, maxHealth, armour, AC.health.maxArmour)
    end)
end

local function checkPlayerFlags(src, ped)
    -- Character select / spawn select screens (qb-multicharacter, qb-spawn,
    -- spawnmanager) freeze the ped and make it invisible + invincible.
    -- Frozen in place is not something cheats bother with, so treat it as
    -- a loading screen rather than godmode/invisibility.
    local frozen = IsEntityPositionFrozen(ped)

    if AC.godmode.enabled and not frozen then
        strikeCheck(src, 'godmode', GetPlayerInvincible(src), AC.godmode.requiredStrikes,
            'player invincible flag set')
    end

    if AC.invisible.enabled and not frozen then
        strikeCheck(src, 'invisible', not IsEntityVisible(ped), AC.invisible.requiredStrikes,
            'player ped is invisible')
    end

    if AC.superJump.enabled then
        strikeCheck(src, 'superjump', IsPlayerUsingSuperJump(src), nil, 'super jump active')
    end

    if AC.damageModifier.enabled then
        local weaponMod = GetPlayerWeaponDamageModifier(src)
        local meleeMod = GetPlayerMeleeWeaponDamageModifier(src)
        strikeCheck(src, 'damagemod',
            weaponMod > AC.damageModifier.maxWeaponModifier or meleeMod > AC.damageModifier.maxMeleeModifier, nil,
            ('weapon damage x%.2f, melee damage x%.2f'):format(weaponMod, meleeMod))
    end

    if AC.vehiclePower.enabled then
        local veh = GetVehiclePedIsIn(ped, false)
        local power = 1.0
        if veh and veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
            power = GetVehicleCheatPowerIncrease(veh)
        end
        strikeCheck(src, 'vehiclepower', power > AC.vehiclePower.maxPowerIncrease, nil,
            ('vehicle power increase x%.2f'):format(power))
    end

    if AC.pedModel.enabled then
        local model = GetEntityModel(ped)
        strikeCheck(src, 'pedmodel', blockedPedModels[model] == true, nil,
            ('using blocked ped model %s'):format(model))
    end
end

local function checkWeapon(src, ped)
    if not AC.weapon.enabled or #AC.weapon.blockedWeaponHashes == 0 then return end

    -- HasPedGotWeapon is client-only, so this checks only the currently
    -- equipped weapon (the client scan in client/anticheat.lua covers the rest)
    local currentWeapon = GetSelectedPedWeapon(ped)
    weaponFlagged[src] = weaponFlagged[src] or {}
    local isBlocked = false

    for _, hash in ipairs(AC.weapon.blockedWeaponHashes) do
        if currentWeapon == hash then
            isBlocked = true
            if not weaponFlagged[src][hash] then
                weaponFlagged[src][hash] = true
                SentinelFlag(src, 'weapon', ('has blocked weapon hash %s equipped'):format(hash))
            end
        end
    end

    if not isBlocked then
        weaponFlagged[src] = {}
    end
end

CreateThread(function()
    while true do
        Wait(AC.pollIntervalMs)

        if AC.enabled then
            for _, strSrc in ipairs(GetPlayers()) do
                local src = tonumber(strSrc)
                local ped = GetPlayerPed(src)

                -- Nothing is checked until the framework says a character is
                -- loaded (character select moves/hides the ped), and the spawn
                -- teleport right after loading is trusted.
                local loaded = Bridge.IsPlayerLoaded(src)
                if loaded and not wasLoaded[src] then
                    SentinelMarkTrusted(src, 15)
                    playerState[src] = nil
                end
                wasLoaded[src] = loaded

                if loaded and ped and ped ~= 0 and not IsSentinelBypassed(src) then
                    local coords = GetEntityCoords(ped)
                    local health = GetEntityHealth(ped)
                    local now = GetGameTimer()
                    local last = playerState[src]
                    local trusted = isTrusted(src)

                    if last and not trusted then
                        checkMovement(src, ped, coords, now, last)
                        checkHealth(src, ped, health, last)
                    end

                    -- dead/respawning players have legit weird state (ragdoll, respawn invincibility)
                    if not trusted and health > 0 then
                        checkPlayerFlags(src, ped)
                    end

                    checkWeapon(src, ped)

                    playerState[src] = { coords = coords, health = health, time = now }
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    playerState[src] = nil
    strikes[src] = nil
    trustedUntil[src] = nil
    weaponFlagged[src] = nil
    wasLoaded[src] = nil
end)

exports('MarkTrusted', function(src, seconds) SentinelMarkTrusted(tonumber(src), seconds) end)
