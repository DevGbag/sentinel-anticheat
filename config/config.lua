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
    },

    weapon = {
        enabled = true,
        -- Weapons players should never have equipped. Checked against the
        -- currently SELECTED weapon only (GetSelectedPedWeapon), not full
        -- inventory — FiveM has no reliable server-side "list all weapons a
        -- ped is carrying" native (HasPedGotWeapon is client-only). Note
        -- GetSelectedPedWeapon has documented cases of server/client
        -- mismatch on some game builds, so treat this as a best-effort
        -- supplementary check, not a guarantee.
        blockedWeaponHashes = {
            `WEAPON_RAYPISTOL`,
        },
    },

    -- action taken once a detection fires (weapon fires immediately; the
    -- others need requiredStrikes consecutive over-threshold samples first)
    -- 'log' | 'warn' | 'kick' | 'ban'
    -- (unauthorized attempts to call admin-only actions ('exploit') are not
    -- listed here — those are always dropped immediately regardless of
    -- this table, see server/permissions.lua)
    punishment = {
        speed = 'kick',
        teleport = 'kick',
        health = 'warn',
        weapon = 'ban',
    },

    banDurationHours = 0, -- 0 = permanent
}

-- ============================================================
-- LOGGING
-- ============================================================
Config.DiscordWebhook = '' -- optional, leave blank to disable
Config.LogToConsole = true
