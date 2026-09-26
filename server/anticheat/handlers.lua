local recentFlags = {}
local MAX_LOG = 200

local lastFlagAt = {}    -- src -> kind -> os.time() of last logged flag
local flagCounts = {}    -- src -> total flags this session
local punished = {}      -- src -> true once a kick/ban is in flight
local rateBuckets = {}   -- src -> key -> { timestamps }
local stats = { flags = 0, kicks = 0, bans = 0, blockedEvents = 0 }

local function pushLog(entry)
    table.insert(recentFlags, 1, entry)
    if #recentFlags > MAX_LOG then
        table.remove(recentFlags)
    end
end

function SentinelGetRecentFlags()
    return recentFlags
end

function SentinelGetStats()
    return stats
end

function SentinelGetFlagCount(src)
    return flagCounts[src] or 0
end

function SentinelCountBlockedEvent()
    stats.blockedEvents = stats.blockedEvents + 1
end

-- Players exempt from every detection: bypass ACE, or any admin when
-- Config.AdminsBypass is on (admin tools look exactly like cheats).
function IsSentinelBypassed(src)
    if not src or src <= 0 then return true end
    if IsPlayerAceAllowed(src, Config.BypassAcePermission) then
        return true
    end
    return Config.AdminsBypass and IsSentinelAdmin(src) or false
end

-- Sliding-window rate limiter. Returns true when `src` has done `key` more
-- than `max` times in the last `windowMs`.
function SentinelRateLimit(src, key, max, windowMs)
    local now = GetGameTimer()
    rateBuckets[src] = rateBuckets[src] or {}
    local bucket = rateBuckets[src][key] or {}
    rateBuckets[src][key] = bucket

    local cutoff = now - windowMs
    local kept = 0
    for i = 1, #bucket do
        if bucket[i] > cutoff then
            kept = kept + 1
            bucket[kept] = bucket[i]
        end
    end
    for i = #bucket, kept + 1, -1 do
        bucket[i] = nil
    end

    bucket[#bucket + 1] = now
    return #bucket > max
end

-- Central entry point for every anticheat detection. Logs, alerts online
-- admins in real time, and applies the configured punishment for that
-- detection kind (Config.AntiCheat.punishment).
function SentinelFlag(src, kind, detail)
    src = tonumber(src)
    if not src or not GetPlayerName(src) then return end
    if punished[src] then return end
    -- 'exploit' comes from SentinelRequireAdmin, which only fires for non-admins
    if kind ~= 'exploit' and IsSentinelBypassed(src) then return end

    local now = os.time()
    lastFlagAt[src] = lastFlagAt[src] or {}
    local last = lastFlagAt[src][kind]
    if last and now - last < (Config.AntiCheat.flagCooldownSeconds or 5) then
        return
    end
    lastFlagAt[src][kind] = now

    local name = GetPlayerName(src) or ('Unknown[' .. src .. ']')
    local ids = SentinelGetIdentifiers(src)
    local action = kind == 'exploit' and 'kick' or (Config.AntiCheat.punishment[kind] or 'log')

    local entry = {
        name = name,
        src = src,
        identifier = ids[1],
        kind = kind,
        detail = detail,
        action = action,
        time = now,
        isoTime = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    }

    pushLog(entry)
    stats.flags = stats.flags + 1
    flagCounts[src] = (flagCounts[src] or 0) + 1

    if Config.LogToConsole then
        print(('^1[sentinel_ac]^7 %s (%s) flagged for ^1%s^7 [%s]: %s'):format(name, src, kind, action, detail))
    end

    SentinelWebhook('detections', ('Detection: %s'):format(kind), ('**%s** (id %s)\n%s'):format(name, src, detail), {
        { name = 'Action', value = action, inline = true },
        { name = 'Session flags', value = tostring(flagCounts[src]), inline = true },
        { name = 'Identifiers', value = '```' .. table.concat(SentinelPublicIdentifiers(src), '\n') .. '```' },
    })

    for _, strAdmin in ipairs(GetPlayers()) do
        local adminSrc = tonumber(strAdmin)
        if IsSentinelAdmin(adminSrc) then
            TriggerClientEvent('sentinel:client:notify', adminSrc, ('[AC] %s: %s (%s)'):format(name, kind, detail), 'error')
            TriggerClientEvent('sentinel:client:newFlag', adminSrc, entry)
        end
    end

    if Config.Screenshots.enabled and Config.Screenshots.onDetection and action ~= 'log' then
        SentinelScreenshotToFile(src, kind)
    end

    if action == 'kick' or action == 'ban' then
        punished[src] = true
        -- short delay so the screenshot (if any) can land before the drop
        local delay = (Config.Screenshots.enabled and Config.Screenshots.onDetection) and 1500 or 0
        SetTimeout(delay, function()
            if not GetPlayerName(src) then return end
            if action == 'kick' then
                stats.kicks = stats.kicks + 1
                DropPlayer(src, ('Removed by Sentinel Anticheat: %s'):format(kind))
            else
                stats.bans = stats.bans + 1
                SentinelBanPlayer(src, ('Anticheat: %s (%s)'):format(kind, detail), Config.AntiCheat.banDurationHours, 'SYSTEM')
            end
        end)
    elseif action == 'warn' then
        TriggerClientEvent('sentinel:client:notify', src, 'Sentinel Anticheat: suspicious activity detected. This has been logged for staff review.', 'error')
    end
end

AddEventHandler('playerDropped', function()
    local src = source
    lastFlagAt[src] = nil
    flagCounts[src] = nil
    punished[src] = nil
    rateBuckets[src] = nil
end)

-- ============================================================
-- Exports so other resources can plug into the anticheat, e.g.:
--   exports.sentinel_ac:MarkTrusted(src, 5)        -- before teleporting/healing someone
--   if exports.sentinel_ac:RateLimit(src, 'myjob:pay', 3, 60000) then return end
--   exports.sentinel_ac:Flag(src, 'myjob', 'paid out 5x in a minute')
-- ============================================================
exports('Flag', function(src, kind, detail) SentinelFlag(src, kind, detail) end)
exports('RateLimit', function(src, key, max, windowMs)
    local limited = SentinelRateLimit(tonumber(src), key, max, windowMs)
    if limited then SentinelFlag(src, 'eventSpam', ('exceeded %d x %s per %dms'):format(max, key, windowMs)) end
    return limited
end)
exports('IsBypassed', function(src) return IsSentinelBypassed(tonumber(src)) end)
