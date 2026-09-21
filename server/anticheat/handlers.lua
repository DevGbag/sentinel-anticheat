local recentFlags = {}
local MAX_LOG = 200

local function pushLog(entry)
    table.insert(recentFlags, 1, entry)
    if #recentFlags > MAX_LOG then
        table.remove(recentFlags)
    end
end

function SentinelGetRecentFlags()
    return recentFlags
end

local function sendWebhook(entry)
    if Config.DiscordWebhook == '' then return end
    PerformHttpRequest(Config.DiscordWebhook, function() end, 'POST', json.encode({
        embeds = {
            {
                title = 'Sentinel Anticheat Flag',
                description = ('**%s** (`%s`)\nType: `%s`\nDetail: %s'):format(entry.name, entry.identifier or 'n/a', entry.kind, entry.detail),
                color = 15158332,
                timestamp = entry.isoTime,
            },
        },
    }), { ['Content-Type'] = 'application/json' })
end

-- Central entry point for every anticheat detection. Logs, alerts online
-- admins in real time, and applies the configured punishment for that
-- detection kind (Config.AntiCheat.punishment).
function SentinelFlag(src, kind, detail)
    local name = GetPlayerName(src) or ('Unknown[' .. src .. ']')
    local ids = {}
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        ids[#ids + 1] = GetPlayerIdentifier(src, i)
    end

    local entry = {
        name = name,
        src = src,
        identifier = ids[1],
        kind = kind,
        detail = detail,
        time = os.time(),
        isoTime = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    }

    pushLog(entry)

    if Config.LogToConsole then
        print(('^1[sentinel_ac]^7 %s flagged for %s: %s'):format(name, kind, detail))
    end

    sendWebhook(entry)

    for _, strAdmin in ipairs(GetPlayers()) do
        local adminSrc = tonumber(strAdmin)
        if IsSentinelAdmin(adminSrc) then
            TriggerClientEvent('sentinel:client:notify', adminSrc, ('[AC] %s: %s (%s)'):format(name, kind, detail), 'error')
            TriggerClientEvent('sentinel:client:newFlag', adminSrc, entry)
        end
    end

    local action = Config.AntiCheat.punishment[kind] or 'log'
    if action == 'kick' then
        DropPlayer(src, ('Removed by Sentinel Anticheat: %s'):format(detail))
    elseif action == 'ban' then
        SentinelBanPlayer(src, ('Anticheat: %s (%s)'):format(kind, detail), Config.AntiCheat.banDurationHours, 'SYSTEM')
    end
    -- 'warn' and 'log' just record + alert admins without removing the player
end
