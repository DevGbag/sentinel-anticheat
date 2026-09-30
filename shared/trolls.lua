-- Troll definitions shared by the server (validation), the client (effects)
-- and the admin menu (buttons). Effects live in client/trolls.lua, except
-- `harmless`, which is enforced server-side in server/anticheat/gameevents.lua
-- so a cheat can't simply ignore it.
--
-- timed = false: one-shot effect, the duration is ignored

SentinelTrollDefs = {
    { name = 'harmless',     label = 'Harmless',      timed = true,  desc = 'Silently cancels their damage, explosions, projectiles and fires server-side. They keep shooting; nobody gets hurt.' },
    { name = 'noShoot',      label = 'Jam weapons',   timed = true,  desc = 'Firing and melee do nothing.' },
    { name = 'launch',       label = 'Launch',        timed = false, desc = 'Fling them (or their vehicle) into the sky.' },
    { name = 'fire',         label = 'Set on fire',   timed = false, desc = 'Sets their ped on fire.' },
    { name = 'ragdoll',      label = 'Ragdoll',       timed = true,  desc = 'Keeps knocking them over.' },
    { name = 'drunk',        label = 'Drunk',         timed = true,  desc = 'Drunk walk, camera shake and blurry screen.' },
    { name = 'blind',        label = 'Blind',         timed = true,  desc = 'Fades their screen to black.' },
    { name = 'lockControls', label = 'Lock controls', timed = true,  desc = 'Disables every control except looking around.' },
    { name = 'slippery',     label = 'Slippery car',  timed = true,  desc = 'Pops their tyres and removes grip from the vehicle they are in.' },
    { name = 'attackers',    label = 'Mountain lions',timed = true,  desc = 'Spawns hostile mountain lions around them.' },
    { name = 'fakeCrash',    label = 'Fake crash',    timed = false, desc = 'Freezes their game, then disconnects them with a fake crash message.' },
}

SentinelTrollByName = {}
for _, def in ipairs(SentinelTrollDefs) do
    SentinelTrollByName[def.name] = def
end

function SentinelTrollEnabled(name)
    if not Config.Trolls.enabled or not SentinelTrollByName[name] then return false end
    for _, disabled in ipairs(Config.Trolls.disabled or {}) do
        if disabled == name then return false end
    end
    return true
end
