# tsivtools

A staff menu and entity protection resource for FiveM.

Standalone. No framework, no database and no UI library required to run it -
drop it in `resources/`, add your identifier, press Insert. ESX, QBCore and
MySQL are supported when you want them, and ignored when you do not.

```
tsivtools/
  config.lua          everything you are meant to edit
  shared/util.lua     helpers used by both sides
  client/             menu, actions, client checks
  server/             permissions, logs, bans, garage, anti-cheat
  ui/                 the text box, which is what makes paste work
  data/               JSON storage, created on first run
server/
  server.cfg          a working config, chat and onesync included
  setup.ps1 / .sh     installs the official base resources and copies tsivtools in
docs/
  BASESERVER.md       building a test server out of open source parts
  SETUP.md            running a server on your PC from scratch, and testing this
  CUSTOMISING.md      every config option, explained
  EXTENDING.md        adding your own options and checks
```

---

## What it does

**Staff menu**, drawn natively, built per player from their rank.

- **Self** - god mode, invisibility, noclip with adjustable speed, heal,
  armour, teleport to waypoint, to typed coordinates or to a saved location,
  and a "print my coordinates" helper for filling in the config.
- **Players** - go to, bring, spectate, revive, heal, slay, freeze, warn, kick,
  ban, lift bans, change staff rank, print identifiers.
- **Vehicles** - spawn from a list or by model name, repair, refuel, flip,
  delete the one you are aiming at, delete every vehicle within a radius
  (with or without occupants), delete every vehicle on the map.
- **Props & entities** - spawn a prop by name, turn the game's ambient traffic
  off server wide and clear what is already there, toggle prop spawn logging, delete the prop you are
  looking at, clear props or loose peds within a radius, clear every prop on
  the map, delete everything a named player spawned, print the live anti-cheat
  settings.
- **Garage** - give a vehicle to a player's garage, remove one by plate, look a
  garage up by server id or by identifier for somebody who is offline.
- **Staff & logs** - print the online staff list with ranks, staff chat, server
  announcements, look up everything ever logged against an identifier, browse
  recent logs by category, server info.

**Entity protection**, server side, on top of OneSync.

- Prop, vehicle and ped spam detection on a sliding window. Over the threshold
  alerts every superadmin with the player's name, user ID, **steam ID** and
  identifier, or kicks, or bans - your choice per entity type.
- Model blacklists for props, vehicles and peds. A blacklisted model is
  cancelled before it exists, and staff get the line in F8 immediately.
- Explosion type blocking and explosion rate limiting.
- Optional per-spawn logging of every prop, vehicle or ped, with the creator's
  user ID and the entity id, into the F8 console of staff at a configured rank,
  and into the searchable log store so the identifier lookup finds them later.
  Models are resolved to names where tsivtools knows them.
- Ownership tracking, so "delete everything this player spawned" is one click,
  and so entities can be cleaned up when their owner disconnects.
- Light client-side checks (speed, health, armour, blacklisted weapons) that
  report as **hints for staff to verify**, never as automatic bans.

**Everything else**

- A `Config.Features` switch for every option, so any of them - or all of them -
  can be turned off without touching code.
- Ranks with per-option permission mapping. An option a rank cannot use is
  never sent to that client, and is checked again on the server when used.
  There is no staff-on-staff restriction: whoever holds a permission can use it
  on anybody, so set the permissions to match the trust.
- Bans against every identifier a player held, enforced on connect.
- A searchable log of every staff action, detection, ban, garage change and
  connection, with optional Discord webhook mirroring.
- Storage in flat JSON by default, or MySQL through oxmysql.

---

## Quick start

1. Copy the `tsivtools` folder into your server's `resources/`.
2. `server.cfg`:

   ```cfg
   set onesync on
   ensure tsivtools
   ```

   OneSync is not optional. Without it the server cannot see entities, so
   logging, spam detection and area cleanup do nothing.
3. Start the server, join, and run `tsivtools_whoami 1` in the server console.
4. Put the `license:` identifier it prints into `Config.Staff`:

   ```lua
   Config.Staff = {
       ['license:a1b2c3...'] = 'owner',
   }
   ```
5. `restart tsivtools` in the server console.
6. Press **Insert**.

Never run a server before? [docs/SETUP.md](docs/SETUP.md) starts from having
nothing but the FiveM client installed.

---

## Controls

| Key | Does |
|---|---|
| Insert | Open and close the menu |
| Arrow up / down | Move |
| Arrow left / right | Change the value on a `< ... >` row |
| Enter | Select |
| Backspace | Back, and close at the top level |

Prompts that ask you to type something open a text box over the game: Enter
confirms, Escape cancels, Ctrl+V pastes.

Rebind it in the pause menu: **Settings → Key Bindings → FiveM → Open the
tsivtools menu**. That is per player and stored client side, so everyone picks
their own. `Config.MenuKey` only sets the default for somebody who has never
had the bind before.

---

## Chat commands

All of them go through the same permission check as the menu.

| Command | Permission |
|---|---|
| `/tsivtools` | `menu.open` |
| `/bring <id>` | `player.bring` |
| `/goto <id>` | `player.goto` |
| `/revive [id]` | `player.revive` |
| `/slay <id>` | `player.slay` |
| `/dv [radius]` | `vehicle.dvarea` |
| `/dp [radius]` | `prop.deletearea` |
| `/prop <model>` | `prop.spawn` |
| `/cleartraffic` | `world.cleartraffic` |
| `/staffchat <message>` | `staff.chat` |

Server console only:

| Command | Does |
|---|---|
| `tsivtools_whoami <id>` | Print a player's identifiers and rank |
| `tsivtools_reload` | Re-evaluate every online player's rank |

---

## Permissions

`Config.Permissions` maps an option to the minimum rank that may use it:

```lua
['player.bring']  = 'mod',
['player.ban']    = 'admin',
['garage.give']   = 'superadmin',
['vehicle.dvall'] = false,        -- nobody, including owner
```

The server works out which keys a player holds and sends only those. Their
client is never told the other options exist, and every action is re-checked
server side when it runs, so a modified client gains nothing.

An option with no line in the table is treated as owner-only. Forgetting one
locks you out rather than handing it to everybody.

The full key list is in [docs/CUSTOMISING.md](docs/CUSTOMISING.md).

---

## Requirements

- FXServer build **5848** or newer
- **OneSync** enabled
- Optional: `oxmysql`, for MySQL-backed bans, logs and garages
- Optional: ESX or QBCore, if you want ranks read from a framework group

---

## What it is not

- It does not detect client-side cheat menus. It sees what the server sees. A
  menu that only affects the cheater's own client is invisible to it, as it is
  to every other Lua anti-cheat that claims otherwise.
- It is not a substitute for leaving `sv_scriptHookAllowed` off.
- It does not obfuscate itself, inject into other resources, or send your
  server's data anywhere. Every line is readable, which is the point: you can
  check exactly what it does before you trust it with your players.

---

## Licence

See [LICENSE](LICENSE).
