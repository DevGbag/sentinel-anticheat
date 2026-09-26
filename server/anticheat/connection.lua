-- Everything that runs while a player is connecting: ban enforcement
-- (identifiers + hardware tokens), required identifiers, name filter and
-- optional VPN/proxy blocking.

local vpnCache = {} -- ip -> bool (true = blocked)

local function hasIdentifierType(ids, kind)
    local prefix = kind .. ':'
    for _, id in ipairs(ids) do
        if id:sub(1, #prefix) == prefix then return true end
    end
    return false
end

local function checkName(name)
    local cfg = Config.Connection.nameFilter
    if not cfg.enabled then return nil end

    if #name < cfg.minLength or #name > cfg.maxLength then
        return ('Your name must be between %d and %d characters.'):format(cfg.minLength, cfg.maxLength)
    end
    -- < > are HTML/NUI injection, ^ is GTA colour codes, ~ is GTA text formatting
    if cfg.blockSpecialCharacters and name:find('[<>%^~\\{}`]') then
        return 'Your name contains characters that are not allowed (< > ^ ~ \\ { } `).'
    end
    local lower = name:lower()
    for _, word in ipairs(cfg.blacklistedWords) do
        if lower:find(word:lower(), 1, true) then
            return 'Your name contains a word that is not allowed. Please change it and reconnect.'
        end
    end
    return nil
end

local function playerIp(ids)
    for _, id in ipairs(ids) do
        if id:sub(1, 3) == 'ip:' then return id:sub(4) end
    end
    return nil
end

-- Resolves to true when ip-api.com says the address is a proxy/VPN or a
-- hosting provider. Fails open (allows the player) if the lookup fails,
-- so an ip-api outage never locks everybody out.
local function isVpn(ip)
    if not ip or ip:find('^127%.') or ip:find('^192%.168%.') or ip:find('^10%.') then
        return false
    end
    if vpnCache[ip] ~= nil then return vpnCache[ip] end

    local p = promise.new()
    local settled = false
    local function settle(value)
        if settled then return end
        settled = true
        p:resolve(value)
    end

    PerformHttpRequest(('http://ip-api.com/json/%s?fields=status,proxy,hosting'):format(ip), function(status, body)
        if status ~= 200 or not body then settle(false) return end
        local ok, data = pcall(json.decode, body)
        if not ok or not data or data.status ~= 'success' then settle(false) return end
        settle(data.proxy == true or data.hosting == true)
    end, 'GET')
    SetTimeout(5000, function() settle(false) end)

    local blocked = Citizen.Await(p)
    vpnCache[ip] = blocked
    return blocked
end

local function reject(deferrals, name, ids, reason, logReason)
    deferrals.done(reason)
    SentinelWebhook('connections', 'Connection rejected', ('**%s** — %s'):format(name, logReason or reason), {
        { name = 'Identifiers', value = '```' .. table.concat(ids, '\n'):gsub('ip:[^\n]*', 'ip:<hidden>') .. '```' },
    })
    if Config.LogToConsole then
        print(('^3[sentinel_ac]^7 rejected %s: %s'):format(name, logReason or reason))
    end
end

AddEventHandler('playerConnecting', function(name, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update('Sentinel Anticheat: checking your connection...')

    local ids = SentinelGetIdentifiers(src)
    local tokens = SentinelGetTokens(src)

    local ban, byTokenOnly = SentinelFindActiveBan(ids, tokens)
    if ban then
        if byTokenOnly then SentinelExtendBan(ban, ids, tokens) end
        reject(deferrals, name, ids, SentinelBanMessage(ban), ('banned (%s)%s'):format(ban.id, byTokenOnly and ' — ban evasion via new accounts' or ''))
        return
    end

    for _, kind in ipairs(Config.Connection.requiredIdentifiers) do
        if not hasIdentifierType(ids, kind) then
            reject(deferrals, name, ids, ('You need a linked %s account to join this server. Open it, then restart FiveM.'):format(kind), 'missing identifier: ' .. kind)
            return
        end
    end

    local nameProblem = checkName(name)
    if nameProblem then
        reject(deferrals, name, ids, nameProblem, 'name filter')
        return
    end

    if Config.Connection.blockVPN then
        deferrals.update('Sentinel Anticheat: checking for VPN/proxy...')
        if isVpn(playerIp(ids)) then
            reject(deferrals, name, ids, Config.Connection.vpnMessage, 'VPN/proxy/hosting IP')
            return
        end
    end

    deferrals.done()
    SentinelWebhook('connections', 'Player connecting', ('**%s**'):format(name), {
        { name = 'Identifiers', value = '```' .. table.concat(ids, '\n'):gsub('ip:[^\n]*', 'ip:<hidden>') .. '```' },
    })
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    SentinelWebhook('connections', 'Player left', ('**%s** (id %s) — %s'):format(GetPlayerName(src) or 'unknown', src, reason or ''))
end)
