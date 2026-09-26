-- Discord webhook + console logging, split into channels so detections,
-- bans, admin actions and connections can go to different Discord channels.

local COLORS = {
    detections = 15158332, -- red
    bans = 10038562,       -- dark red
    admin = 3447003,       -- blue
    connections = 3066993, -- green
}

local function webhookFor(channel)
    local url = Config.Webhooks and Config.Webhooks[channel] or ''
    if (not url or url == '') and channel == 'detections' then
        url = Config.DiscordWebhook
    end
    return url or ''
end

function SentinelWebhook(channel, title, description, fields)
    local url = webhookFor(channel)
    if url == '' then return end

    PerformHttpRequest(url, function() end, 'POST', json.encode({
        username = 'Sentinel Anticheat',
        embeds = {
            {
                title = title,
                description = description,
                color = COLORS[channel] or 9807270,
                fields = fields,
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
                footer = { text = GetConvar('sv_hostname', 'sentinel_ac'):sub(1, 60) },
            },
        },
    }), { ['Content-Type'] = 'application/json' })
end

function SentinelGetIdentifiers(src)
    local ids = {}
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        ids[#ids + 1] = GetPlayerIdentifier(src, i)
    end
    return ids
end

function SentinelGetTokens(src)
    local tokens = {}
    for i = 0, GetNumPlayerTokens(src) - 1 do
        tokens[#tokens + 1] = GetPlayerToken(src, i)
    end
    return tokens
end

-- identifiers minus ip:, for anything that gets posted to Discord
function SentinelPublicIdentifiers(src)
    local out = {}
    for _, id in ipairs(SentinelGetIdentifiers(src)) do
        if not id:find('^ip:') then
            out[#out + 1] = id
        end
    end
    return out
end

-- Audit trail for every privileged action taken through the admin menu.
function SentinelAudit(adminSrc, action, targetSrc, detail)
    local adminName = adminSrc == 0 and 'console' or (GetPlayerName(adminSrc) or ('[' .. adminSrc .. ']'))
    local targetName = targetSrc and (GetPlayerName(targetSrc) or ('[' .. tostring(targetSrc) .. ']')) or nil

    local line = targetName
        and ('%s -> %s on %s (%s)'):format(adminName, action, targetName, targetSrc)
        or ('%s -> %s'):format(adminName, action)
    if detail and detail ~= '' then
        line = line .. ': ' .. detail
    end

    if Config.LogToConsole then
        print(('^5[sentinel_ac:admin]^7 %s'):format(line))
    end
    SentinelWebhook('admin', 'Admin action: ' .. action, line)
end
