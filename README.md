<p align="center"><img src="branding/logo.png" width="260" alt="Sentinel Anticheat"></p>

# sentinel_ac

Free, standalone FiveM anticheat with the feature set of the paid ones:
server-authoritative detections, a OneSync game-event firewall, hardware
bans, client integrity checks, Discord logging, screenshots, and a
graphical admin menu with an item generator. Drop it into any server's
`resources` folder as its own resource.

## Install

1. Copy this whole folder into your server's `resources` directory (e.g.
   `resources/[admin]/sentinel_ac`). Keep the `data/` folder — bans and
   screenshots are written there.
2. Add to `server.cfg` (OneSync is required — it's what lets the server
   see real player state and intercept game events):
   ```
   set onesync on
   ensure screenshot-basic   # optional, enables screenshots
   ensure sentinel_ac
   ```
3. Grant admin access via ACE permissions in `server.cfg` (recommended —
   this is the real security boundary, checked server-side on every
   privileged action):
   ```
   add_ace group.admin sentinel.admin allow
   add_principal identifier.license:YOUR_LICENSE_HERE group.admin
   ```
   Get your license identifier from the F8 console (`GetPlayerIdentifiers`)
   or from server logs on connect.

   Alternative for a solo/dev server: add your identifier to
   `Config.FallbackAdminIdentifiers` in `config/config.lua` instead of
   setting up ACE groups. ACE is still the better long-term approach once
   you have more than one admin.

   Staff who should never be flagged but aren't menu admins:
   `add_ace group.mod sentinel.bypass allow`. Admins are exempt by
   default (`Config.AdminsBypass`), because noclip/spectate/godmode from
   admin tools look exactly like cheats.

4. Open `config/config.lua` and set `Config.Framework` to match your
   server: `'standalone'`, `'esx'`, `'qbcore'`, `'qbx'`, or `'ox'`.

5. Optionally paste Discord webhook URLs into `Config.Webhooks`
   (detections, bans, admin audit, connections — each can be its own channel).

6. In-game, press **F6** (configurable via `Config.MenuKeybind`, and also
   remappable per-player in FiveM's own keybind settings) to open the admin menu.

**Before going live:** set the aggressive punishments (`ban`) to `log`
for a few days, watch the Anticheat Log tab for false positives from your
own scripts (car packs, nitro, safe zones, police tools), tune the
thresholds, then turn punishments back on.

## Features

### Server-side state checks (`server/anticheat/monitor.lua`)
Polled from the server every `pollIntervalMs` under OneSync. A modified
client can lie about what it *tells* the server, but not about what the
server *reads back* about its synced ped.

| Check | How |
|---|---|
| Teleport / noclip | distance moved per poll |
| Speed | on-foot cap + flat vehicle cap |
| Instant heals | health jump per poll |
| Health / armour over max | `GetEntityMaxHealth`, `GetPedArmour` |
| Godmode | `GetPlayerInvincible` |
| Invisibility | `IsEntityVisible` |
| Super jump | `IsPlayerUsingSuperJump` |
| Damage multipliers | `GetPlayer(Melee)WeaponDamageModifier` |
| Vehicle power boost | `GetVehicleCheatPowerIncrease` |
| Blocked ped models | `GetEntityModel` (animals etc.) |
| Blocked weapons | equipped weapon |

### Game-event firewall (`server/anticheat/gameevents.lua`)
Hooks the OneSync events a client sends *before* they reach other
players, and **cancels** abusive ones so nobody else ever sees them:

- **Entity spawns** — blacklisted vehicles/peds/props (tanks, jets, troll
  props) plus per-player spawn rate limits (mass-spawn/crash menus)
- **Explosions** — blocked types (orbital cannon, blimp…), invisible
  explosions, damage-scaled explosions, explosion spam
- **Particle FX, projectiles, fires** — spam and oversized effects
- **Weapon damage** — one-shot damage above cap, blocked weapons,
  hits from impossible distance, "kill all" kill-rate
- **Weapon tampering** — giving/removing weapons on other players
- **Clear ped tasks** — yanking players out of vehicles

### Client integrity (`client/anticheat.lua` + `server/anticheat/clientchecks.lua`)
- **Heartbeat** with a per-session token — catches executors that stop
  or suspend the anticheat, and forged heartbeats
- **Resource stop** — a client stopping a resource the server is still running
- **Resource injection** — a client running a resource the server never started
- **Honeypot events** — decoy events that only event dumpers ever fire
- **Full weapon inventory scan** for blocked weapons (and removes them)
- **Spectator mode, thermal/night vision, all-damage-proofs** on own ped

### Menu-feature detections
Targets the individual toggles cheat menus offer:

| Menu feature | Detected by | Side |
|---|---|---|
| Noclip / fly | ped moves while its synced velocity is ~0; own collision off; hovering without falling | server + client |
| Spectate / freecam | player's camera focus far from their ped (`GetPlayerFocusPos`); rendered camera far from ped | server + client |
| Fix vehicle | driver's engine/body health jumps to full in one poll | server |
| Vehicle speed hack | speed above the model's own rated top speed (per model) | client |
| Vehicle godmode | own vehicle set undamageable | client |
| Godmode (alt method) | `SetEntityCanBeDamaged(false)` on own ped | client |
| Invisibility (alpha) | own ped alpha turned down | client |
| Nametags / ESP | game gamer tags active | client |
| Player blips on map | a blip on most other players at once | client |
| Give all weapons | holding more weapons than any real loadout | client |
| Aimbot | headshot ratio over a rolling sample of hits on players | server |
| Magic bullet / silent kill | gun damage while the shooter's hands are empty | server |
| Executor commands | commands registered by a resource the server never started; blacklisted command names | client → server |
| Suspended anticheat | heartbeat continues but the check loop counter froze | server |

The heartbeat token now rotates every beat, so a captured token can't be
replayed after the real heartbeat stops.

Scripts with legitimate far cameras (CCTV, drones) call
`exports.sentinel_ac:AllowFreeCamera(src, seconds)` on the server and
`exports.sentinel_ac:AllowFreeCamera(true/false)` on the client. Repair
scripts that fix a car with the driver inside call
`exports.sentinel_ac:MarkTrusted(src, 3)` first.

### Server hardening audit (`server/anticheat/convars.lua`)
On startup the console lists server.cfg convars that shut cheat tools
down at the engine level and aren't set yet (`sv_scriptHookAllowed`,
`sv_pureLevel`, `sv_entityLockdown`, `sv_filterRequestControl`, networked
sounds/phone explosions). Re-run with `sentinel_audit` in the console.
These block more tools than any detection can — apply them.

### Connection guard (`server/anticheat/connection.lua`)
- Ban enforcement on **identifiers and hardware tokens** — a banned
  player on a fresh Rockstar/Steam/Discord account is still banned, and
  the new accounts are added to the ban automatically (ban evasion)
- Required identifiers (e.g. force Discord or Steam linked)
- Name filter (length, injection/colour-code characters, blocked words)
- Optional VPN/proxy/hosting IP blocking via ip-api.com

### Bans (`server/anticheat/bans.lua`)
Ban IDs (`SNT-XXXXXX`) shown to the player, temp or permanent, stored
in `data/bans.json`. Unban from the menu's **Bans** tab or with
`sentinel_unban <ID>`; ban from console with
`sentinel_ban <server id> <hours> <reason>`.

### Logging & evidence
- Discord webhooks split into detections / bans / admin audit / connections
- Every admin-menu action (goto, bring, heal, kill, freeze, kick, ban,
  unban, spectate, item give, screenshot) is written to the audit log
- Automatic screenshot on any detection that isn't `log`-only, saved to
  `data/screenshots/` (needs `screenshot-basic`)
- Chat filter: blocked words and chat spam

### Admin menu (F6)
Stats bar (online, flags, blocked events, AC kicks/bans, active bans),
**Players** tab with per-player flag count and an **Info** panel
(identifiers, HW token count, health/armour, session flags, **live
screenshot**), **Item Generator**, **Anticheat Log** with search and
detection-type filter, and **Bans** with search and unban.

### Trolls (`server/anticheat/trolls.lua`, `client/trolls.lua`)
Open a player's **Troll** / **Info** panel in the menu and pick an effect
and a duration: **Harmless** (their damage, explosions and projectiles are
silently cancelled server-side), jam weapons, launch, fire, ragdoll,
drunk, blind, lock controls, slippery car, mountain lions, and a
**fake crash** that freezes their game and then disconnects them. Every
troll is written to the admin audit log.

Set any detection's punishment to `'troll'` and the cheater is trolled
automatically with `Config.Trolls.auto.trolls` for
`auto.durationSeconds`, then kicked or banned (`auto.thenAction`).
Restrict trolls to some admins with `Config.Trolls.acePermission`, or turn
individual ones off with `Config.Trolls.disabled`. From other resources:
`exports.sentinel_ac:Troll(src, 'drunk', 30)` / `StopTrolls(src)`.

Everything except Harmless runs on the target's client, so a cheat that
blocks our client events won't see it. Harmless can't be blocked.

### Punishments
Per detection in `Config.AntiCheat.punishment`: `log`, `warn` (log +
tell the player), `kick`, or `ban`. The same player+detection is only
punished once per `flagCooldownSeconds`, so a spammer produces one flag
instead of hundreds.

### Exports for your own resources
```lua
-- call before your script teleports or heals a player, so it isn't flagged
exports.sentinel_ac:MarkTrusted(src, 5)

-- rate-limit your own server events; flags + returns true when exceeded
if exports.sentinel_ac:RateLimit(src, 'myjob:payout', 3, 60000) then return end

exports.sentinel_ac:Flag(src, 'myjob', 'paid out 5x in one minute')
exports.sentinel_ac:BanPlayer(src, 'reason', 0)  -- hours, 0 = permanent
exports.sentinel_ac:Unban('SNT-ABC123')
exports.sentinel_ac:IsBypassed(src)
exports.sentinel_ac:IsSentinelAdmin(src)
```
Custom detection kinds use `Config.AntiCheat.punishment[kind]` if you
add one, otherwise `log`.

## Honest limitations

- *Nothing inside a FiveM resource can see the cheat process itself.*
  Paid anticheats that claim "injection detection" are detecting the
  same effects this one does (plus heartbeat/resource tricks), or they
  ship a separate native client, which isn't possible as a resource.
  What this resource does is catch the *effects* of cheating server-side
  and block them at the network-event layer.
- *Client-side checks can be bypassed* by a cheat that hooks our client
  script. The heartbeat is there to notice when it stops, but a
  sophisticated cheat can keep it alive. Server-side checks and the
  game-event firewall are the parts that can't be switched off by the client.
- *Vehicle speed cap is flat, not per-model.* The per-model max-speed
  native only exists client-side. Set `maxVehicleSpeed` above your
  fastest add-on car.
- *Some legit scripts look like cheats*: safe zones (godmode), character
  creators (invisible), nitro (power boost), police cuff scripts (clear
  tasks). Each has its own toggle/threshold in config — tune before
  enabling bans.
- *External (DMA / overlay) cheats are invisible to any resource.* ESP
  drawn by an external overlay, or an aimbot reading memory from a second
  PC, never touches the game's scripting layer. Only their effects can be
  caught: the aimbot headshot ratio, impossible hits, and so on.
- *New heuristics need tuning*: overhead-ID scripts trip `nametags`,
  police GPS trips `playerBlips`, CCTV/drone scripts trip `freecam`, and
  nitro trips `vehicleSpeed`. Run them on `log` first.
- *VPN blocking uses ip-api.com's free tier* (45 lookups/minute, cached
  per IP). It fails open if the lookup fails.
- Framework bridge exports (`bridge/frameworks/*_server.lua`) are written
  against each framework's commonly documented API. If item-giving
  silently fails, check your framework's actual export names.

## File map

```
config/config.lua                 every toggle, threshold and punishment
bridge/                           framework bridge (standalone/esx/qbcore/qbx/ox)
client/main.lua                   keybind, menu open/close, callback RPC
client/anticheat.lua              heartbeat, resource reporting, client checks, honeypot strings
client/menu/nui.lua               NUI callback wiring, spectate camera, screenshots
server/main.lua                   callback RPC registry, startup log
server/permissions.lua            IsSentinelAdmin / SentinelRequireAdmin
server/logging.lua                Discord webhooks per channel, admin audit log
server/anticheat/handlers.lua     SentinelFlag, bypass, rate limiter, cooldowns, exports
server/anticheat/bans.lua         bans w/ HW tokens, ban IDs, unban, ban commands
server/anticheat/connection.lua   connect-time bans, identifiers, name filter, VPN
server/anticheat/monitor.lua      server-side polling checks
server/anticheat/gameevents.lua   OneSync event firewall
server/anticheat/clientchecks.lua heartbeat, resource stop/injection, honeypots
server/anticheat/chat.lua         chat filter
server/anticheat/screenshots.lua  detection + on-demand screenshots
server/menu/callbacks.lua         menu data + player actions
server/menu/itemgen.lua           item generator server logic
html/                             the NUI admin panel
data/                             bans.json + screenshots/ (created at runtime)
```
