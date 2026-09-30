--[[
Troll system. Admins apply trolls from the menu's Info panel; detections
with punishment 'troll' apply Config.Trolls.auto via SentinelAutoTroll.

Most effects run on the target's client (client/trolls.lua), so a cheat
that blocks our client events won't see them. `harmless` is the exception:
it's enforced here, by cancelling the player's damage/explosion/projectile
events in server/anticheat/gameevents.lua, which the client can't opt out of.
]]

local cfg = Config.Trolls

local active = {} -- src -> name -> GetGameTimer() expiry

function SentinelTrollActive(src, name)
    local t = active[src] and active[src][name]
    return t ~= nil and GetGameTimer() < t
end

local function activeList(src)
    local out = {}
    local now = GetGameTimer()
    for name, expires in pairs(active[src] or {}) do
        if expires > now then
            out[name] = math.ceil((expires - now) / 1000)
        end
    end
    return out
end
SentinelActiveTrolls = activeList

-- Returns true if the troll was applied.
function SentinelTroll(src, name, seconds)
    src = tonumber(src)
    if not src or not GetPlayerName(src) or not SentinelTrollEnabled(name) then return false end

    local def = SentinelTrollByName[name]
    seconds = math.floor(tonumber(seconds) or cfg.defaultDurationSeconds)
    seconds = math.max(1, math.min(seconds, cfg.maxDurationSeconds))

    if def.timed then
        active[src] = active[src] or {}
        active[src][name] = GetGameTimer() + seconds * 1000
    end

    -- launching trips speed/teleport; the monitor would flag our own troll
    if name == 'launch' then
        SentinelMarkTrusted(src, 8)
    end

    if name ~= 'harmless' then
        TriggerClientEvent('sentinel:client:troll', src, name, seconds)
    end

    if name == 'fakeCrash' then
        SetTimeout(cfg.fakeCrashDelaySeconds * 1000, function()
            if GetPlayerName(src) then DropPlayer(src, cfg.fakeCrashMessage) end
        end)
    end
    return true
end

function SentinelStopTrolls(src)
    active[src] = nil
    TriggerClientEvent('sentinel:client:trollStop', src)
end

-- Called by SentinelFlag for punishment 'troll'. `finish` runs once the
-- trolls wear off and applies auto.thenAction.
function SentinelAutoTroll(src, finish)
    local auto = cfg.auto
    if not cfg.enabled then
        finish()
        return
    end
    for _, name in ipairs(auto.trolls) do
        SentinelTroll(src, name, auto.durationSeconds)
    end
    SetTimeout(auto.durationSeconds * 1000, function()
        if GetPlayerName(src) then finish() end
    end)
end

local function canTroll(src)
    if not SentinelRequireAdmin(src, 'troll') then return false end
    if cfg.acePermission and src ~= 0 and not IsPlayerAceAllowed(src, cfg.acePermission) then
        TriggerClientEvent('sentinel:client:notify', src, 'You do not have permission to use trolls.', 'error')
        return false
    end
    return true
end

SentinelRegisterCallback('sentinel:getTrolls', function(src)
    if not IsSentinelAdmin(src) or not cfg.enabled then return {} end
    local list = {}
    for _, def in ipairs(SentinelTrollDefs) do
        if SentinelTrollEnabled(def.name) then list[#list + 1] = def end
    end
    return list
end)

RegisterNetEvent('sentinel:server:troll', function(targetId, name, seconds)
    local src = source
    if not canTroll(src) then return end
    targetId = tonumber(targetId)
    if type(name) ~= 'string' or not targetId then return end

    if SentinelTroll(targetId, name, seconds) then
        local def = SentinelTrollByName[name]
        SentinelAudit(src, 'troll', targetId, def.timed and ('%s (%ss)'):format(name, tonumber(seconds) or cfg.defaultDurationSeconds) or name)
    end
end)

RegisterNetEvent('sentinel:server:trollStop', function(targetId)
    local src = source
    if not canTroll(src) then return end
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return end
    SentinelStopTrolls(targetId)
    SentinelAudit(src, 'stop trolls', targetId)
end)

AddEventHandler('playerDropped', function()
    active[source] = nil
end)

exports('Troll', function(src, name, seconds) return SentinelTroll(src, name, seconds) end)
exports('StopTrolls', function(src) SentinelStopTrolls(tonumber(src)) end)
