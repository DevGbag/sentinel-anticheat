# sentinel_ac

Standalone FiveM resource: server-authoritative anticheat + graphical admin
menu + item generator. drop it into any server's `resources` folder as its own resource.

## Install

1. Copy this whole folder into your server's `resources` directory (e.g.
   `resources/[admin]/sentinel_ac`).
2. Add to `server.cfg`:
   ```
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

4. Open `config/config.lua` and set `Config.Framework` to match your
   server: `'standalone'`, `'esx'`, `'qbcore'`, `'qbx'`, or `'ox'`. This one
   line controls which file in `bridge/frameworks/` the item generator and
   player lookups use.

5. In-game, press **F6** (configurable via `Config.MenuKeybind`, and also
   remappable per-player in FiveM's own keybind settings under "Sentinel
   Anticheat") to open the admin menu.

## What's actually in here

**Anticheat (server-authoritative)** — `server/anticheat/monitor.lua` polls
every connected player's real position/health/speed directly from the
server every `Config.AntiCheat.pollIntervalMs`, under OneSync. This matters:
a modified client can fake what it *tells* the server, but it can't fake
what the server *reads back* about where the synced entity actually is.
Checks included:
- Teleport / noclip-style movement (distance per poll tick)
- Speed (on-foot cap + a flat vehicle cap — see note below)
- Instant/repeated full-heals with no admin action behind them
- A configurable blocked-weapon list (checked against the currently
  equipped weapon only — see note below)

Each numeric check requires several consecutive over-threshold samples
(`Config.AntiCheat.requiredStrikes`) before it fires, to absorb lag spikes
and legitimate menu teleports/heals (those mark the player briefly
"trusted" so they don't trip the same check that catches cheaters).

Configurable per-detection punishment (`log` / `warn` / `kick` / `ban`) in
`config/config.lua`. Bans persist to `data/bans.json` inside the resource
and are enforced on connect, independent of framework.

**Honest limitations** (so you're not surprised later):
- *Vehicle speed cap is flat, not per-model.* FiveM's per-model max-speed
  native (`GetVehicleModelEstimatedMaxSpeed`) only exists client-side, so
  there's no server-safe way to know a specific model's real top speed.
  `Config.AntiCheat.speed.maxVehicleSpeed` is one number for all vehicles —
  set it comfortably above your fastest installed vehicle (including any
  add-on car pack) to avoid false positives.
- *Weapon check covers only the currently equipped weapon, not full
  inventory.* There's no reliable server-side "list everything this ped is
  carrying" native (`HasPedGotWeapon` is client-only). This uses
  `GetSelectedPedWeapon` instead, which has documented cases of
  server/client mismatch on some game builds — treat it as a useful
  supplementary signal, not a guarantee.
- *This does not detect external cheat-menu injection itself* (the actual
  process-level mod tools players run). Nothing running only inside a
  FiveM resource can see that — it's outside the sandbox by design. What
  this resource does is catch the *effects* of cheating (impossible
  speed/position/healing/weapons) server-side, which is the same approach
  real FiveM anticheats use.
- Framework bridge exports (`bridge/frameworks/*_server.lua`) are written
  against each framework's commonly documented API. Frameworks change
  their exports across versions — if item-giving silently fails for your
  server, check your installed framework's actual export names against
  the matching bridge file.

**Admin menu (NUI, F6)** — Players tab (goto/bring/heal/kill/freeze/
spectate/kick/ban), Item Generator tab (give any item/weapon from the
active framework's item list to any online player), Anticheat Log tab
(live feed of flags, updates in real time while the menu is open).

**Permissions** — every single privileged action (menu data requests,
teleport, kick, ban, item give, etc.) re-checks `IsSentinelAdmin(source)`
server-side before doing anything, regardless of whether the menu UI
"allowed" it client-side. A non-admin who manages to trigger one of these
server events directly (e.g. from a modified client, guessing event names)
is treated as an active exploit attempt: flagged and dropped immediately,
not just silently ignored.

## File map

```
config/config.lua              framework choice, permissions, thresholds, keybind
bridge/bridge_client.lua       client bridge contract (framework files fill it in)
bridge/bridge_server.lua       server bridge contract (framework files fill it in)
bridge/frameworks/             one pair of files per supported framework
client/main.lua                keybind, menu open/close, lightweight callback RPC
client/menu/nui.lua             NUI callback wiring, spectate camera
server/main.lua                 lightweight callback RPC registry, startup log
server/permissions.lua          IsSentinelAdmin / SentinelRequireAdmin
server/anticheat/monitor.lua    the polling detection loop
server/anticheat/handlers.lua   SentinelFlag: logging, webhook, punishment
server/anticheat/bans.lua       persistent ban storage + connect-time enforcement
server/menu/callbacks.lua       player list, teleport, spectate, heal/kill/freeze/kick/ban
server/menu/itemgen.lua         item generator server logic
html/                           the NUI admin panel (HTML/CSS/JS)
```
