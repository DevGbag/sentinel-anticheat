local BANS_FILE = 'data/bans.json'

local function loadBans()
    local raw = LoadResourceFile(GetCurrentResourceName(), BANS_FILE)
    if not raw then return {} end
    local ok, decoded = pcall(json.decode, raw)
    return (ok and decoded) or {}
end

local function saveBans(bans)
    local ok = SaveResourceFile(GetCurrentResourceName(), BANS_FILE, json.encode(bans, { indent = true }), -1)
    if not ok then
        print(('^1[sentinel_ac]^7 Failed to write %s — make sure the data/ folder exists inside the resource.'):format(BANS_FILE))
    end
end

local bans = loadBans()

local function newBanId()
    local charset = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
    while true do
        local id = 'SNT-'
        for _ = 1, 6 do
            local i = math.random(1, #charset)
            id = id .. charset:sub(i, i)
        end
        local taken = false
        for _, ban in ipairs(bans) do
            if ban.id == id then taken = true break end
        end
        if not taken then return id end
    end
end

-- bans written before ban IDs/tokens existed
local migrated = false
for _, ban in ipairs(bans) do
    if not ban.id then ban.id = newBanId() migrated = true end
    ban.tokens = ban.tokens or {}
end
if migrated then saveBans(bans) end

local function isActive(ban)
    return ban.expires == nil or ban.expires > os.time()
end

local function banMessage(ban)
    return ('You are banned from this server.\nBan ID: %s\nReason: %s%s'):format(
        ban.id,
        ban.reason,
        ban.expires and ('\nExpires: ' .. os.date('%Y-%m-%d %H:%M:%S', ban.expires)) or '\n(Permanent)'
    )
end

-- hours <= 0 means permanent
function SentinelBanPlayer(src, reason, hours, bannedBy)
    local expires = (hours and hours > 0) and (os.time() + hours * 3600) or nil

    local ban = {
        id = newBanId(),
        identifiers = SentinelGetIdentifiers(src),
        tokens = SentinelGetTokens(src),
        name = GetPlayerName(src) or 'unknown',
        reason = reason or 'No reason specified',
        bannedBy = bannedBy or 'console',
        bannedAt = os.time(),
        expires = expires,
    }
    bans[#bans + 1] = ban
    saveBans(bans)

    SentinelWebhook('bans', ('Player banned: %s'):format(ban.name), ('**%s** was banned by **%s**'):format(ban.name, ban.bannedBy), {
        { name = 'Ban ID', value = ban.id, inline = true },
        { name = 'Duration', value = expires and (hours .. 'h') or 'Permanent', inline = true },
        { name = 'Reason', value = ban.reason },
        { name = 'Identifiers', value = '```' .. table.concat(SentinelPublicIdentifiers(src), '\n') .. '```' },
    })

    DropPlayer(src, banMessage(ban))
    return ban.id
end

function SentinelUnban(banId)
    for i, ban in ipairs(bans) do
        if ban.id == banId then
            table.remove(bans, i)
            saveBans(bans)
            SentinelWebhook('bans', 'Player unbanned', ('Ban **%s** (%s) was lifted'):format(ban.id, ban.name))
            return true, ban
        end
    end
    return false
end

function SentinelGetBans()
    local out = {}
    for _, ban in ipairs(bans) do
        if isActive(ban) then
            out[#out + 1] = {
                id = ban.id,
                name = ban.name,
                reason = ban.reason,
                bannedBy = ban.bannedBy,
                bannedAt = ban.bannedAt,
                expires = ban.expires,
            }
        end
    end
    return out
end

local function toSet(list)
    local set = {}
    for _, v in ipairs(list) do set[v] = true end
    return set
end

-- Matches on any identifier OR any hardware token. Tokens are what makes
-- this stick: a banned player who makes a new Rockstar/Steam/Discord
-- account still has the same machine tokens.
-- Returns ban, matchedByTokenOnly.
function SentinelFindActiveBan(ids, tokens)
    local idSet, tokenSet = toSet(ids), toSet(tokens or {})

    for _, ban in ipairs(bans) do
        if isActive(ban) then
            for _, bannedId in ipairs(ban.identifiers) do
                if idSet[bannedId] then
                    return ban, false
                end
            end
            for _, bannedToken in ipairs(ban.tokens or {}) do
                if tokenSet[bannedToken] then
                    return ban, true
                end
            end
        end
    end
    return nil
end

-- Ban evasion: the player matched by hardware token but is using new
-- accounts. Fold the new identifiers/tokens into the ban so every account
-- they've touched stays banned even if their hardware changes later.
function SentinelExtendBan(ban, ids, tokens)
    local idSet, tokenSet = toSet(ban.identifiers), toSet(ban.tokens)
    for _, id in ipairs(ids) do
        if not idSet[id] then ban.identifiers[#ban.identifiers + 1] = id end
    end
    for _, t in ipairs(tokens) do
        if not tokenSet[t] then ban.tokens[#ban.tokens + 1] = t end
    end
    saveBans(bans)
    SentinelWebhook('bans', 'Ban evasion blocked', ('**%s** tried to join on new accounts under ban **%s**. New identifiers were added to the ban.'):format(ban.name, ban.id), {
        { name = 'Identifiers', value = '```' .. table.concat(ids, '\n'):gsub('ip:[^\n]*\n?', '') .. '```' },
    })
end

SentinelBanMessage = banMessage

-- Console / ACE-admin commands
RegisterCommand('sentinel_unban', function(src, args)
    if src ~= 0 and not IsSentinelAdmin(src) then return end
    local id = args[1] and args[1]:upper()
    if not id then
        print('usage: sentinel_unban <BAN ID>')
        return
    end
    local ok, ban = SentinelUnban(id)
    local msg = ok and ('Unbanned %s (%s)'):format(ban.name, ban.id) or ('No ban with ID %s'):format(id)
    if src == 0 then print(msg) else TriggerClientEvent('sentinel:client:notify', src, msg, ok and 'success' or 'error') end
    if ok then SentinelAudit(src, 'unban', nil, id) end
end, false)

RegisterCommand('sentinel_ban', function(src, args)
    if src ~= 0 and not IsSentinelAdmin(src) then return end
    local target, hours = tonumber(args[1]), tonumber(args[2])
    if not target or not GetPlayerName(target) or not hours then
        print('usage: sentinel_ban <server id> <hours, 0 = permanent> <reason...>')
        return
    end
    local reason = table.concat(args, ' ', 3)
    local banId = SentinelBanPlayer(target, reason ~= '' and reason or 'Banned by admin', hours, src == 0 and 'console' or GetPlayerName(src))
    print(('Banned %s — %s'):format(target, banId))
    SentinelAudit(src, 'ban', target, reason)
end, false)

exports('BanPlayer', function(src, reason, hours, bannedBy) return SentinelBanPlayer(tonumber(src), reason, hours or 0, bannedBy or GetInvokingResource()) end)
exports('Unban', function(banId) return (SentinelUnban(banId)) end)
