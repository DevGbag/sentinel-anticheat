local fallbackSet = {}
for _, id in ipairs(Config.FallbackAdminIdentifiers) do
    fallbackSet[id] = true
end

local function getIdentifiers(src)
    local ids = {}
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        ids[#ids + 1] = GetPlayerIdentifier(src, i)
    end
    return ids
end

-- Server-authoritative admin check. Grant real access via ACE permissions
-- in server.cfg:
--   add_ace group.admin sentinel.admin allow
--   add_principal identifier.license:xxxxxxxx group.admin
-- Config.FallbackAdminIdentifiers is only a convenience for solo/dev boxes.
function IsSentinelAdmin(src)
    if src == 0 then return true end -- server console

    if IsPlayerAceAllowed(src, Config.AcePermission) then
        return true
    end

    for _, id in ipairs(getIdentifiers(src)) do
        if fallbackSet[id] then
            return true
        end
    end

    return false
end

-- Every privileged NUI callback/event calls this first. A non-admin that
-- still manages to fire one of these events directly (bypassing the menu,
-- e.g. from a modified client) is treated as an active cheat attempt and
-- removed immediately rather than just silently ignored.
function SentinelRequireAdmin(src, actionName)
    if IsSentinelAdmin(src) then
        return true
    end

    if SentinelFlag then
        SentinelFlag(src, 'exploit', ('unauthorized attempt to call %s'):format(actionName or 'unknown action'))
    end
    DropPlayer(src, 'Removed by Sentinel Anticheat: unauthorized action attempt')
    return false
end

exports('IsSentinelAdmin', IsSentinelAdmin)
