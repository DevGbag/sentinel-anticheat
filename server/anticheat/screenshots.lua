-- Screenshots via the `screenshot-basic` resource (optional dependency).
-- Detections save to data/screenshots/ inside this resource; the admin
-- menu can also pull a live screenshot of any player.

local function available()
    return Config.Screenshots.enabled and GetResourceState('screenshot-basic') == 'started'
end

function SentinelScreenshotToFile(src, label)
    if not available() then return end

    local fileName = ('%s/data/screenshots/%s_%s_%s.jpg'):format(
        GetResourcePath(GetCurrentResourceName()),
        os.date('%Y%m%d-%H%M%S'),
        src,
        (tostring(label):gsub('[^%w_-]', ''))
    )

    exports['screenshot-basic']:requestClientScreenshot(src, {
        fileName = fileName,
        encoding = 'jpg',
        quality = Config.Screenshots.quality,
    }, function(err)
        if err then
            print(('^3[sentinel_ac]^7 screenshot of %s failed: %s'):format(src, tostring(err)))
        elseif Config.LogToConsole then
            print(('^3[sentinel_ac]^7 saved screenshot %s'):format(fileName))
        end
    end)
end

RegisterNetEvent('sentinel:server:requestScreenshot', function(targetId)
    local src = source
    if not SentinelRequireAdmin(src, 'requestScreenshot') then return end
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return end

    if not available() then
        TriggerClientEvent('sentinel:client:notify', src, 'Screenshots need the screenshot-basic resource started (and Config.Screenshots.enabled).', 'error')
        return
    end

    SentinelAudit(src, 'screenshot', targetId)

    -- no fileName = screenshot-basic hands back a data URI
    exports['screenshot-basic']:requestClientScreenshot(targetId, {
        encoding = 'jpg',
        quality = Config.Screenshots.quality,
    }, function(err, dataUri)
        if not GetPlayerName(src) then return end
        if err or not dataUri then
            TriggerClientEvent('sentinel:client:notify', src, 'Screenshot failed: ' .. tostring(err), 'error')
            return
        end
        -- latent: a screenshot is a few hundred KB, don't stall the event queue
        TriggerLatentClientEvent('sentinel:client:screenshot', src, 200000, targetId, dataUri)
    end)
end)
