--[[
Server half of the client-integrity layer (client half: client/anticheat.lua).

Heartbeat: once our client script starts it gets a per-session token and
must echo it every Config.AntiCheat.heartbeat.intervalSeconds. Executors
commonly stop or suspend the anticheat resource first; a heartbeat that
stops arriving is how that shows up server-side.

Anything the client reports can be forged or suppressed by a determined
cheat, so these are extra layers on top of the server-side checks.
]]

local AC = Config.AntiCheat

local heartbeatToken = {} -- src -> token
local lastHeartbeat = {}  -- src -> GetGameTimer()
local joinedAt = {}       -- src -> GetGameTimer()
local recentServerStops = {} -- resourceName -> GetGameTimer() when the server stopped it

local READY_GRACE_MS = 180000 -- time a client gets to load in and start our script

local function newToken()
    local t = {}
    for i = 1, 24 do t[i] = string.char(math.random(97, 122)) end
    return table.concat(t)
end

for _, strSrc in ipairs(GetPlayers()) do
    joinedAt[tonumber(strSrc)] = GetGameTimer() -- resource (re)started with players online
end

AddEventHandler('playerJoining', function()
    joinedAt[source] = GetGameTimer()
end)

AddEventHandler('playerDropped', function()
    local src = source
    heartbeatToken[src] = nil
    lastHeartbeat[src] = nil
    joinedAt[src] = nil
end)

AddEventHandler('onResourceStop', function(name)
    recentServerStops[name] = GetGameTimer()
end)

local function stoppedByServerRecently(name)
    local t = recentServerStops[name]
    return t ~= nil and GetGameTimer() - t < 30000
end

-- ============================================================
-- Heartbeat
-- ============================================================
RegisterNetEvent('sentinel:server:clientReady', function()
    local src = source
    heartbeatToken[src] = newToken()
    lastHeartbeat[src] = GetGameTimer()
    TriggerClientEvent('sentinel:client:init', src, heartbeatToken[src])
end)

RegisterNetEvent('sentinel:server:heartbeat', function(token)
    local src = source
    if not heartbeatToken[src] then return end
    if token ~= heartbeatToken[src] then
        SentinelFlag(src, 'heartbeat', 'heartbeat sent with the wrong session token (forged)')
        return
    end
    lastHeartbeat[src] = GetGameTimer()
end)

CreateThread(function()
    while true do
        Wait(5000)
        if AC.enabled and AC.heartbeat.enabled then
            local now = GetGameTimer()
            local timeoutMs = AC.heartbeat.timeoutSeconds * 1000
            for _, strSrc in ipairs(GetPlayers()) do
                local src = tonumber(strSrc)
                if lastHeartbeat[src] then
                    if now - lastHeartbeat[src] > timeoutMs then
                        SentinelFlag(src, 'heartbeat', ('no anticheat heartbeat for %ds — client script stopped or blocked'):format((now - lastHeartbeat[src]) // 1000))
                        lastHeartbeat[src] = now -- don't re-flag every tick under 'log'/'warn'
                    end
                elseif joinedAt[src] and now - joinedAt[src] > READY_GRACE_MS and GetPlayerPed(src) ~= 0 then
                    SentinelFlag(src, 'heartbeat', 'anticheat client script never started')
                    joinedAt[src] = now
                end
            end
        end
    end
end)

-- ============================================================
-- Resource stop / injection
-- ============================================================
RegisterNetEvent('sentinel:server:resourceStopped', function(name)
    local src = source
    if not AC.enabled or not AC.resourceStop.enabled or type(name) ~= 'string' then return end
    if SentinelRateLimit(src, 'resourceStopped', 20, 10000) then return end

    -- Re-check after a few seconds: the server stopping/restarting a
    -- resource makes every client stop it too, and a disconnecting client
    -- stops everything on its way out. Only a player who is still here,
    -- still heartbeating, with the resource still running gets flagged.
    SetTimeout(5000, function()
        if not GetPlayerName(src) or stoppedByServerRecently(name) then return end
        if not lastHeartbeat[src] or GetGameTimer() - lastHeartbeat[src] > (AC.heartbeat.intervalSeconds + 5) * 1000 then return end
        if GetResourceState(name) == 'started' then
            SentinelFlag(src, 'resourceStop', ('stopped resource "%s" client-side while it is running on the server'):format(name:sub(1, 64)))
        end
    end)
end)

local ignoreInjection = {}
for _, name in ipairs(AC.resourceInjection.ignore) do ignoreInjection[name] = true end

RegisterNetEvent('sentinel:server:resourceList', function(list)
    local src = source
    if not AC.enabled or not AC.resourceInjection.enabled or type(list) ~= 'table' then return end
    if SentinelRateLimit(src, 'resourceList', 3, 60000) then return end

    for _, name in ipairs(list) do
        if type(name) == 'string' and not ignoreInjection[name] then
            local state = GetResourceState(name)
            if state ~= 'started' and state ~= 'starting' and not stoppedByServerRecently(name) then
                SentinelFlag(src, 'injection', ('running resource "%s" that the server has not started (server state: %s)'):format(name:sub(1, 64), state))
                return
            end
        end
    end
end)

-- ============================================================
-- Honeypots
-- ============================================================
if AC.honeypots.enabled then
    for _, eventName in ipairs(AC.honeypots.events) do
        RegisterNetEvent(eventName, function()
            SentinelFlag(source, 'honeypot', ('triggered decoy event "%s" (event dumper / executor)'):format(eventName))
        end)
    end
end

-- ============================================================
-- Client-reported detections
-- ============================================================
local REPORTABLE = {
    spectate = true,
    visionMods = true,
    pedProofs = true,
    weapon = true,
}

RegisterNetEvent('sentinel:server:clientReport', function(kind, detail)
    local src = source
    if not AC.enabled or not REPORTABLE[kind] then return end
    if SentinelRateLimit(src, 'clientReport', 10, 10000) then return end
    SentinelFlag(src, kind, ('[client] %s'):format(tostring(detail):sub(1, 200)))
end)
