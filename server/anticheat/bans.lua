local BANS_FILE = 'data/bans.json'

local function loadBans()
    local raw = LoadResourceFile(GetCurrentResourceName(), BANS_FILE)
    if not raw then return {} end
    local ok, decoded = pcall(json.decode, raw)
    return (ok and decoded) or {}
end

local function saveBans(bans)
    SaveResourceFile(GetCurrentResourceName(), BANS_FILE, json.encode(bans, { indent = true }), -1)
end

local bans = loadBans()

local function identifiersFor(src)
    local ids = {}
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        ids[#ids + 1] = GetPlayerIdentifier(src, i)
    end
    return ids
end

-- hours <= 0 means permanent
function SentinelBanPlayer(src, reason, hours, bannedBy)
    local ids = identifiersFor(src)
    local expires = (hours and hours > 0) and (os.time() + hours * 3600) or nil

    bans[#bans + 1] = {
        identifiers = ids,
        name = GetPlayerName(src) or 'unknown',
        reason = reason or 'No reason specified',
        bannedBy = bannedBy or 'console',
        bannedAt = os.time(),
        expires = expires,
    }
    saveBans(bans)

    DropPlayer(src, ('You have been banned.\nReason: %s%s'):format(
        reason or 'No reason specified',
        expires and ('\nExpires: ' .. os.date('%Y-%m-%d %H:%M:%S', expires)) or '\n(Permanent)'
    ))
end

local function findActiveBan(ids)
    for _, ban in ipairs(bans) do
        if ban.expires == nil or ban.expires > os.time() then
            for _, bannedId in ipairs(ban.identifiers) do
                for _, id in ipairs(ids) do
                    if bannedId == id then
                        return ban
                    end
                end
            end
        end
    end
    return nil
end

AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)

    local ban = findActiveBan(identifiersFor(src))
    if ban then
        deferrals.done(('You are banned.\nReason: %s%s'):format(
            ban.reason,
            ban.expires and ('\nExpires: ' .. os.date('%Y-%m-%d %H:%M:%S', ban.expires)) or '\n(Permanent)'
        ))
    else
        deferrals.done()
    end
end)
