--[[
Server-authoritative polling anticheat. Every check here reads native
player state (GetEntityCoords, GetEntityHealth, ...) directly from the
server, which under OneSync reflects the real synced state of the
entity — a modified client can't just lie about it the way it could lie
about a client-reported "I am not cheating" event.

Detections require `Config.AntiCheat.requiredStrikes` consecutive over-
threshold samples before flagging, which absorbs lag spikes and legit
teleports/heals performed through the admin menu (those also mark the
player "trusted" for a few seconds via SentinelMarkTrusted).
]]

local playerState = {}
local strikes = {}
local trustedUntil = {}
local weaponFlagged = {}

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

function SentinelMarkTrusted(src, seconds)
    trustedUntil[src] = GetGameTimer() + ((seconds or 3) * 1000)
end

local function isTrusted(src)
    return trustedUntil[src] ~= nil and GetGameTimer() < trustedUntil[src]
end

CreateThread(function()
    while true do
        Wait(Config.AntiCheat.pollIntervalMs)

        if Config.AntiCheat.enabled then
            for _, strSrc in ipairs(GetPlayers()) do
                local src = tonumber(strSrc)
                local ped = GetPlayerPed(src)

                if ped and ped ~= 0 then
                    local coords = GetEntityCoords(ped)
                    local health = GetEntityHealth(ped)
                    local now = GetGameTimer()
                    local last = playerState[src]

                    if last and not isTrusted(src) then
                        local dt = (now - last.time) / 1000.0

                        if dt > 0 then
                            local dist = #(coords - last.coords)

                            if Config.AntiCheat.teleport.enabled and dist > Config.AntiCheat.teleport.maxDistancePerPoll then
                                if addStrike(src, 'teleport') >= Config.AntiCheat.requiredStrikes then
                                    SentinelFlag(src, 'teleport', ('moved %.1fm in %.1fs'):format(dist, dt))
                                    resetStrike(src, 'teleport')
                                end
                            else
                                resetStrike(src, 'teleport')
                            end

                            if Config.AntiCheat.speed.enabled then
                                local speed = dist / dt
                                local veh = GetVehiclePedIsIn(ped, false)
                                local limit

                                if veh and veh ~= 0 then
                                    -- flat cap, not per-model: GetVehicleModelEstimatedMaxSpeed
                                    -- only exists client-side
                                    limit = Config.AntiCheat.speed.maxVehicleSpeed
                                else
                                    limit = Config.AntiCheat.speed.maxOnFootSpeed
                                end

                                if speed > limit then
                                    if addStrike(src, 'speed') >= Config.AntiCheat.requiredStrikes then
                                        SentinelFlag(src, 'speed', ('%.1fm/s over limit of %.1fm/s'):format(speed, limit))
                                        resetStrike(src, 'speed')
                                    end
                                else
                                    resetStrike(src, 'speed')
                                end
                            end
                        end

                        if Config.AntiCheat.health.enabled and last.health then
                            local jump = health - last.health
                            if jump >= Config.AntiCheat.health.instantHealThreshold then
                                if addStrike(src, 'health') >= Config.AntiCheat.requiredStrikes then
                                    SentinelFlag(src, 'health', ('healed %d hp in one tick with no admin action behind it'):format(jump))
                                    resetStrike(src, 'health')
                                end
                            else
                                resetStrike(src, 'health')
                            end
                        end
                    end

                    if Config.AntiCheat.weapon.enabled and #Config.AntiCheat.weapon.blockedWeaponHashes > 0 then
                        -- HasPedGotWeapon is client-only, so this checks only the
                        -- currently equipped weapon (see config.lua comment)
                        local currentWeapon = GetSelectedPedWeapon(ped)
                        weaponFlagged[src] = weaponFlagged[src] or {}
                        local isBlocked = false

                        for _, hash in ipairs(Config.AntiCheat.weapon.blockedWeaponHashes) do
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
end)
