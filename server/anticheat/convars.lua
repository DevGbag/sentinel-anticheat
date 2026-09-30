--[[
Startup audit of the server convars that shut whole classes of cheat
tools down at the engine level — stronger than any detection, because the
server simply refuses what the tool asks for. Prints a report to the
console; nothing is changed automatically since some settings need your
scripts to be compatible (e.g. entity lockdown and client-spawned vehicles).
]]

local function truthy(v)
    v = tostring(v):lower()
    return v == 'true' or v == '1' or v == 'on'
end

local CHECKS = {
    {
        convar = 'onesync', default = 'off',
        ok = function(v) return v ~= 'off' end,
        advice = 'set onesync on — every server-side check and the event firewall need it',
    },
    {
        convar = 'sv_scriptHookAllowed', default = 'false',
        ok = function(v) return not truthy(v) end,
        advice = 'set sv_scriptHookAllowed 0 — otherwise ScriptHook .asi menus load freely',
    },
    {
        convar = 'sv_pureLevel', default = '0',
        ok = function(v) return tonumber(v) and tonumber(v) >= 1 end,
        advice = 'sv_pureLevel 1 (or 2) blocks modified game files: no-grass, rpf-edited weapons, texture-based ESP',
    },
    {
        convar = 'sv_entityLockdown', default = 'inactive',
        ok = function(v) return v == 'strict' or v == 'relaxed' end,
        advice = 'sv_entityLockdown relaxed (or strict) stops cheat menus creating entities client-side; test your garage/job scripts first',
    },
    {
        convar = 'sv_filterRequestControl', default = '0',
        ok = function(v) return (tonumber(v) or 0) >= 2 end,
        advice = 'sv_filterRequestControl 2 stops clients taking control of vehicles/peds they do not own (car theft/fling menus)',
    },
    {
        convar = 'sv_enableNetworkedSounds', default = 'true',
        ok = function(v) return not truthy(v) end,
        advice = 'set sv_enableNetworkedSounds false — sound spam menus play sounds for everyone',
    },
    {
        convar = 'sv_enableNetworkedPhoneExplosions', default = 'false',
        ok = function(v) return not truthy(v) end,
        advice = 'set sv_enableNetworkedPhoneExplosions false — phone explosions are a classic kill-anyone exploit',
    },
}

local function audit()
    local issues = {}
    for _, c in ipairs(CHECKS) do
        local value = GetConvar(c.convar, c.default)
        if not c.ok(value) then
            issues[#issues + 1] = ('%s = %s  ->  %s'):format(c.convar, value, c.advice)
        end
    end
    return issues
end

CreateThread(function()
    Wait(2000)
    local issues = audit()
    local score = #CHECKS - #issues
    if #issues == 0 then
        print(('^2[sentinel_ac]^7 server hardening: %d/%d convars secure'):format(score, #CHECKS))
        return
    end
    print(('^3[sentinel_ac]^7 server hardening: %d/%d convars secure. Recommended server.cfg changes:'):format(score, #CHECKS))
    for _, line in ipairs(issues) do
        print('^3[sentinel_ac]^7   - ' .. line)
    end
end)

RegisterCommand('sentinel_audit', function(src)
    if src ~= 0 then return end
    local issues = audit()
    print(('[sentinel_ac] %d/%d convars secure'):format(#CHECKS - #issues, #CHECKS))
    for _, line in ipairs(issues) do print('  - ' .. line) end
end, true)
