-- Chat filter for the default `chat` resource: blacklisted words (ads,
-- slurs — whatever you add to Config.Chat) and message spam. Blocked
-- messages are cancelled so nobody else sees them.

local cfg = Config.Chat

AddEventHandler('chatMessage', function(src, _, message)
    src = tonumber(src)
    if not cfg.enabled or not src or src <= 0 or IsSentinelBypassed(src) then return end

    if SentinelRateLimit(src, 'chat', cfg.maxMessagesPerWindow, cfg.rateWindowMs) then
        CancelEvent()
        SentinelFlag(src, 'chatSpam', ('more than %d messages in %ds'):format(cfg.maxMessagesPerWindow, cfg.rateWindowMs // 1000))
        return
    end

    local lower = tostring(message):lower()
    for _, word in ipairs(cfg.blacklistedWords) do
        if lower:find(word:lower(), 1, true) then
            CancelEvent()
            SentinelFlag(src, 'chat', ('blocked message containing "%s"'):format(word))
            return
        end
    end
end)
