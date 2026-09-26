Config = {}

-- ============================================================
-- FRAMEWORK
-- Change this one line to switch which inventory/player system
-- the item generator and player lookups bridge into.
-- Valid values: 'standalone' | 'esx' | 'qbcore' | 'qbx' | 'ox'
-- ============================================================
Config.Framework = 'standalone'

-- ============================================================
-- PERMISSIONS
-- Admin access is gated server-side via FiveM ACE permissions.
-- Grant it to a group in server.cfg, e.g.:
--   add_ace group.admin sentinel.admin allow
--   add_principal identifier.license:xxxxxxxx group.admin
-- The identifier list below is only a convenience fallback for
-- solo/dev servers that haven't set up ACE groups yet.
-- ============================================================
Config.AcePermission = 'sentinel.admin'

Config.FallbackAdminIdentifiers = {
    -- 'license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
}

-- Players with this ACE are never flagged by any detection (use for
-- trusted staff, developers testing things, etc.):
--   add_ace group.admin sentinel.bypass allow
Config.BypassAcePermission = 'sentinel.bypass'

-- When true, anyone who passes IsSentinelAdmin is also exempt from
-- detections. Admin tools (noclip, spectate, godmode in vMenu/txAdmin)
-- would otherwise trip the same checks that catch cheaters.
Config.AdminsBypass = true

-- ============================================================
-- MENU
-- ============================================================
Config.MenuKeybind = 'F6' -- default keymap, remappable in FiveM keybind settings under "Sentinel Anticheat"

-- ============================================================
-- ANTICHEAT
-- All checks run server-side against native player state so a
-- modified client can't simply lie about its own position/health.
-- ============================================================
Config.AntiCheat = {
    enabled = true,
    pollIntervalMs = 1000, -- how often each player's state is sampled

    -- consecutive samples over a threshold required before flagging,
    -- to absorb lag spikes / legit resource teleports / falling damage
    requiredStrikes = 3,

    -- the same player+detection is only logged/punished once per this many
    -- seconds, so an explosion spammer produces one flag instead of 500
    flagCooldownSeconds = 5,

    speed = {
        enabled = true,
        maxOnFootSpeed = 8.5,  -- m/s, sprint w/ stamina perks tops out well under this
        -- flat cap for any vehicle, not per-model: GetVehicleModelEstimatedMaxSpeed
        -- only exists client-side, so a per-model server-side cap isn't available.
        -- Set generously above your fastest installed vehicle (including any
        -- custom/add-on car pack) to avoid false positives.
        maxVehicleSpeed = 100.0,
    },

    teleport = {
        enabled = true,
        maxDistancePerPoll = 120.0, -- meters; legit menu teleports set a trusted-flag that bypasses this
    },

    health = {
        enabled = true,
        -- flags repeated instant full-heals with no medic/item event backing them
        instantHealThreshold = 50,
        -- health above the ped's own max health, or armour above this
        maxArmour = 100,
    },

    -- GetPlayerInvincible, read server-side. spawnmanager sets this for a
    -- moment while spawning and some servers use it for safe zones, hence
    -- the separate, larger strike count.
    godmode = {
        enabled = true,
        requiredStrikes = 10,
    },

    -- IsEntityVisible, read server-side. Character creators / clothing
    -- shops sometimes hide the player, hence the larger strike count.
    invisible = {
        enabled = true,
        requiredStrikes = 15,
    },

    superJump = {
        enabled = true,
    },

    -- Get(Melee)WeaponDamageModifier, read server-side. Cheats push these
    -- far above 1.0; some servers legitimately lower them, which is fine.
    damageModifier = {
        enabled = true,
        maxWeaponModifier = 1.5,
        maxMeleeModifier = 1.5,
    },

    -- GetVehicleCheatPowerIncrease, read server-side. Nitro/tuning scripts
    -- sometimes raise this a little, so keep the cap above what they use.
    vehiclePower = {
        enabled = true,
        maxPowerIncrease = 2.0,
    },

    -- player ped models nobody should be using (animals are the classic one)
    pedModel = {
        enabled = true,
        blockedModels = {
            `a_c_chimp`,
            `a_c_chop`,
            `a_c_cow`,
            `a_c_deer`,
            `a_c_mtlion`,
            `a_c_rhesus`,
            `a_c_shepherd`,
            `u_m_y_zombie_01`,
        },
    },

    weapon = {
        enabled = true,
        -- Weapons players should never have. Checked three ways: the currently
        -- SELECTED weapon server-side (GetSelectedPedWeapon, which has some
        -- server/client mismatch on some game builds), every weaponDamageEvent
        -- (so actually firing one is caught), and a client-side full-inventory
        -- scan (HasPedGotWeapon is client-only, so that scan is best-effort —
        -- a cheat that disables our client script also disables it).
        blockedWeaponHashes = {
            `WEAPON_RAYPISTOL`,
            `WEAPON_RAYCARBINE`,
            `WEAPON_RAYMINIGUN`,
            `WEAPON_RAILGUN`,
            `WEAPON_MINIGUN`,
            `WEAPON_HOMINGLAUNCHER`,
            -- add e.g. `WEAPON_RPG`, `WEAPON_STICKYBOMB` if your server never hands them out
        },
    },

    -- ========================================================
    -- OneSync game-event firewall (server/anticheat/gameevents.lua).
    -- These hook the network events a client sends when it creates an
    -- entity, causes an explosion, damages someone, etc. Blocked events
    -- are CANCELLED server-side so other players never see them.
    -- ========================================================
    entities = {
        enabled = true,
        -- models nobody should be able to spawn (tanks, jets, troll props)
        blacklistedModels = {
            `rhino`, `khanjali`, `hydra`, `lazer`, `cargoplane`, `jet`,
            `blimp`, `blimp2`, `blimp3`, `oppressor2`, `deluxo`, `vigilante`,
            `apc`, `trailersmall2`, `hunter`, `savage`, `akula`, `volatol`,
            `prop_windmill_01`, `prop_ld_ferris_wheel`, `p_spinning_anus_s`,
            `stt_prop_stunt_track_start`, `prop_beach_fire`, `prop_container_01a`,
            `prop_gas_tank_01a`, `prop_cs_dildo_01`,
        },
        -- per-player caps on script-spawned entities in a sliding window.
        -- Generous defaults: dealerships/garages spawn a few at a time.
        rateWindowMs = 10000,
        maxVehiclesPerWindow = 8,
        maxPedsPerWindow = 12,
        maxObjectsPerWindow = 40,
    },

    explosions = {
        enabled = true,
        -- explosion type IDs to always block. 29/37 = blimp, 59 = orbital
        -- cannon, 36 = railgun, 38 = firework. Full list:
        -- https://docs.fivem.net/natives/?_0xE3AD2BDBAEE269AC
        blockedTypes = { 29, 36, 37, 38, 59 },
        blockInvisible = true,       -- isInvisible = true is a classic "silent kill" trick
        maxDamageScale = 1.0,
        maxPerWindow = 8,
        rateWindowMs = 2000,
    },

    particles = {
        enabled = true,
        maxPerWindow = 10,
        rateWindowMs = 2000,
        maxScale = 5.0,
    },

    projectiles = {
        enabled = true,
        maxPerWindow = 15,
        rateWindowMs = 2000,
    },

    fires = {
        enabled = true,
        maxPerWindow = 10,
        rateWindowMs = 3000,
    },

    -- weaponDamageEvent: a client telling the server it hit someone
    weaponDamage = {
        enabled = true,
        maxDamagePerHit = 400,       -- vanilla heavy sniper is ~216
        maxHitDistance = 600.0,      -- meters, shooter -> victim (default OneSync culling is 424m)
        maxKillsPerWindow = 8,       -- "kill all" menus
        killWindowMs = 10000,
        -- weapon types that legitimately exceed maxDamagePerHit (vehicle hits, falls, fire, explosions)
        exemptWeapons = {
            `WEAPON_RUN_OVER_BY_CAR`, `WEAPON_RAMMED_BY_CAR`, `WEAPON_FALL`,
            `WEAPON_EXPLOSION`, `WEAPON_FIRE`, `WEAPON_DROWNING`,
            `WEAPON_DROWNING_IN_VEHICLE`, `WEAPON_BLEEDING`, `WEAPON_HIT_BY_WATER_CANNON`,
        },
    },

    -- a client giving/removing weapons on a ped it isn't driving is never
    -- legit — server scripts use the server-side natives, which don't go
    -- through these events
    weaponTampering = {
        enabled = true,
    },

    -- clearPedTasksEvent on another player's ped (yanks them out of cars,
    -- freezes them). Some police/cuff scripts do this client-side; set
    -- cancel=false and punishment to 'log' if yours does.
    clearTasks = {
        enabled = true,
        cancel = true,
    },

    -- ========================================================
    -- Client integrity (client/anticheat.lua + server/anticheat/clientchecks.lua).
    -- Everything the client reports can be forged or suppressed by a
    -- determined cheat, so these are extra layers on top of the
    -- server-side checks, not replacements for them.
    -- ========================================================
    heartbeat = {
        enabled = true,
        intervalSeconds = 10,
        -- no heartbeat for this long after the first one = our client
        -- script was stopped or blocked
        timeoutSeconds = 60,
    },

    -- client stops a resource that is still running server-side
    resourceStop = {
        enabled = true,
    },

    -- client is running a resource the server never started (executor injection)
    resourceInjection = {
        enabled = true,
        ignore = { '_cfx_internal' },
    },

    -- decoy server events. Cheat menus dump every event name they can find
    -- in client scripts and fire them looking for money/item exploits.
    -- These names appear in client/anticheat.lua but are never actually
    -- triggered by it, so anyone who fires one is running an event dumper.
    honeypots = {
        enabled = true,
        events = {
            'sentinel:server:adminGiveMoney',
            'sentinel:server:adminSetJob',
            'sentinel:server:reviveAll',
            'sentinel:server:giveAllWeapons',
        },
    },

    -- small client-side checks
    clientChecks = {
        spectatorMode = true,  -- NetworkIsInSpectatorMode while not admin-spectating
        visionMods = true,     -- thermal / night vision
        pedProofs = true,      -- all damage proofs set on own ped (client-side godmode)
        weaponInventory = true,-- full inventory scan for blockedWeaponHashes
        intervalMs = 5000,
    },

    -- action taken once a detection fires
    -- 'log'  = record + alert admins
    -- 'warn' = same as log, and the player is told they were flagged
    -- 'kick' | 'ban'
    -- (unauthorized attempts to call admin-only actions ('exploit') are not
    -- listed here — those are always dropped immediately regardless of
    -- this table, see server/permissions.lua)
    punishment = {
        speed = 'kick',
        teleport = 'kick',
        health = 'warn',
        armour = 'kick',
        godmode = 'kick',
        invisible = 'warn',
        superjump = 'kick',
        damagemod = 'ban',
        vehiclepower = 'kick',
        pedmodel = 'kick',
        weapon = 'ban',

        entityBlacklist = 'ban',
        entitySpam = 'kick',
        explosion = 'ban',
        explosionSpam = 'kick',
        particles = 'kick',
        projectiles = 'kick',
        fires = 'kick',
        weaponDamage = 'ban',
        hitDistance = 'kick',
        killSpam = 'ban',
        giveWeapon = 'ban',
        removeWeapon = 'kick',
        clearTasks = 'kick',

        heartbeat = 'kick',
        resourceStop = 'ban',
        injection = 'ban',
        honeypot = 'ban',
        spectate = 'kick',
        visionMods = 'log',
        pedProofs = 'kick',
        chat = 'warn',
        chatSpam = 'kick',

        -- used by exports.sentinel_ac:RateLimit from your own resources
        eventSpam = 'kick',
    },

    banDurationHours = 0, -- 0 = permanent
}

-- ============================================================
-- CONNECTION GUARD (server/anticheat/connection.lua)
-- ============================================================
Config.Connection = {
    -- players must have every identifier type listed here to join
    -- e.g. { 'license', 'discord' } or { 'license', 'steam' }
    requiredIdentifiers = { 'license' },

    nameFilter = {
        enabled = true,
        minLength = 2,
        maxLength = 32,
        -- block names containing HTML/colour-code/injection characters
        blockSpecialCharacters = true,
        -- case-insensitive substrings that aren't allowed in names
        blacklistedWords = { 'admin', 'moderator', '<script', 'discord.gg' },
    },

    -- VPN / proxy / hosting-provider IPs, looked up via ip-api.com's free
    -- endpoint (45 requests/minute, no key). Off by default because some
    -- legit players are on mobile/carrier-grade NAT ranges that show up
    -- as "hosting".
    blockVPN = false,
    vpnMessage = 'VPNs and proxies are not allowed on this server.',
}

-- ============================================================
-- CHAT FILTER (server/anticheat/chat.lua)
-- Hooks the default `chat` resource's chatMessage event.
-- ============================================================
Config.Chat = {
    enabled = true,
    -- case-insensitive substrings; add slurs/ad domains for your community
    blacklistedWords = { 'discord.gg/' },
    maxMessagesPerWindow = 6,
    rateWindowMs = 5000,
}

-- ============================================================
-- SCREENSHOTS
-- Requires the `screenshot-basic` resource to be started. Detections
-- save a screenshot to data/screenshots/ inside this resource, and the
-- admin menu can grab a live screenshot of any player.
-- ============================================================
Config.Screenshots = {
    enabled = true,
    onDetection = true,
    quality = 0.6,
}

-- ============================================================
-- LOGGING
-- Each channel can point at a different Discord webhook. Leave any
-- blank to disable that channel. DiscordWebhook is the old single
-- webhook and is still used for detections if `detections` is blank.
-- ============================================================
Config.DiscordWebhook = '' -- optional, leave blank to disable
Config.Webhooks = {
    detections = '',
    bans = '',
    admin = '',        -- audit trail of every admin-menu action
    connections = '',  -- joins, leaves, and connection-guard rejections
}
Config.LogToConsole = true
