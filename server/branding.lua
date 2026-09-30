--[[
Branding integrity check. The panel logo is embedded in html/branding.js;
if that file, its script tag in html/index.html, or the manifest author
is changed, this build is reported as unofficial in the server console
and in the admin panel.

This is a deterrent, not a lock — anyone hosting the files can edit them.
Ship this file through FiveM asset escrow to stop it being removed.
]]

local RESOURCE = GetCurrentResourceName()
local EXPECTED_BRANDING_HASH = 617435089 -- joaat of html/branding.js with \r removed
local EXPECTED_AUTHOR = 'DevGeorge'

-- Jenkins one-at-a-time, same algorithm as GTA's joaat but case-sensitive.
local function joaat(s)
    local h = 0
    for i = 1, #s do
        h = (h + s:byte(i)) & 0xFFFFFFFF
        h = (h + (h << 10)) & 0xFFFFFFFF
        h = h ~ (h >> 6)
    end
    h = (h + (h << 3)) & 0xFFFFFFFF
    h = h ~ (h >> 11)
    h = (h + (h << 15)) & 0xFFFFFFFF
    return h
end

local function checkBranding()
    local problems = {}

    local branding = LoadResourceFile(RESOURCE, 'html/branding.js')
    if not branding then
        problems[#problems + 1] = 'html/branding.js is missing'
    elseif joaat((branding:gsub('\r', ''))) ~= EXPECTED_BRANDING_HASH then
        problems[#problems + 1] = 'html/branding.js has been modified'
    end

    local index = LoadResourceFile(RESOURCE, 'html/index.html') or ''
    if not index:find('<script src="branding.js"></script>', 1, true) or not index:find('id="brand"', 1, true) then
        problems[#problems + 1] = 'the logo was removed from html/index.html'
    end

    if GetResourceMetadata(RESOURCE, 'author', 0) ~= EXPECTED_AUTHOR then
        problems[#problems + 1] = 'fxmanifest.lua author was changed'
    end

    return problems
end

local problems = checkBranding()
local official = #problems == 0

CreateThread(function()
    Wait(1000)
    if official then return end
    print('^1[sentinel_ac] ============================================================^7')
    print('^1[sentinel_ac]^7 UNOFFICIAL BUILD — Sentinel Anticheat branding was altered:')
    for _, p in ipairs(problems) do
        print(('^1[sentinel_ac]^7   - %s'):format(p))
    end
    print('^1[sentinel_ac]^7 Sentinel is free; please keep its branding intact.')
    print('^1[sentinel_ac] ============================================================^7')
end)

SentinelRegisterCallback('sentinel:getBuildInfo', function(src)
    if not IsSentinelAdmin(src) then return nil end
    return { official = official, version = GetResourceMetadata(RESOURCE, 'version', 0) }
end)
