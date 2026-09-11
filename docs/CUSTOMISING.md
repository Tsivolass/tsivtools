# Adjusting tsivtools

Everything in this document is a change to `config.lua`. Nothing here requires
touching the code. Run `restart tsivtools` in the server console after any
change.

---

## Ranks

`Config.Ranks` is the ladder. Higher `level` means more power.

```lua
Config.Ranks = {
    { name = 'trial',      label = 'Trial Mod',  level = 5  },   -- added
    { name = 'mod',        label = 'Moderator',  level = 10 },
    { name = 'admin',      label = 'Admin',      level = 20 },
    { name = 'superadmin', label = 'Superadmin', level = 30 },
    { name = 'owner',      label = 'Owner',      level = 40 },
}
```

Rules:

- `name` is what you use everywhere else. Keep it lowercase and unique.
- `label` is what players see.
- `level` decides the order. Leave gaps between them so you can slot a rank in
  later without renumbering everything.

Ranks are compared by level, never by position in the table, so the order you
write them in does not matter.

---

## Who is staff

Three ways, and the highest rank out of all three wins.

**1. The config table**

```lua
Config.Staff = {
    ['license:a1b2c3...'] = 'owner',
    ['steam:110000100000000'] = 'admin',
    ['discord:123456789012345678'] = 'mod',
}
```

Get the identifier with `tsivtools_whoami <server id>` in the server console.

Prefer `license:`. Every player has one. `steam:` only exists when the player
has Steam running, so a steam-based rank quietly stops working the day they
launch the game without it.

**2. ACE permissions, in `server.cfg`**

```cfg
add_ace group.staff tsivtools.mod allow
add_ace group.management tsivtools.superadmin allow
add_principal identifier.license:a1b2c3... group.management
```

The ace name is `Config.AcePrefix` plus a dot plus the rank name. Turn this off
entirely with `Config.UseAcePermissions = false`.

**3. From inside the menu**

**Players → Select player → Set staff rank**. Arrow left and right to pick the
rank, then press Enter to apply it. Stored in `data/staff.json`, so it survives
a restart.

You can grant up to and including your own rank, but never above it, and you
cannot change the rank of somebody who already holds your rank or higher. So an
owner can make a second owner - but once they have, neither can demote the
other, and you will need to edit `data/staff.json` or `Config.Staff` by hand to
undo it.

"remove rank" is the last entry in the list rather than the first, so pressing
Enter without arrowing cannot strip somebody's rank by accident.

---

## Which options each rank sees

This is `Config.Permissions`, and it is the table you will spend the most time
in.

```lua
Config.Permissions = {
    ['player.bring'] = 'mod',        -- moderators and above
    ['player.ban']   = 'admin',      -- admins and above
    ['garage.give']  = 'superadmin', -- superadmins and above
    ['player.setrank'] = 'owner',    -- owners only
    ['vehicle.dvall'] = false,       -- nobody, not even owner
}
```

The value is the **minimum rank name**. Set it to `false` to switch the option
off for everyone.

A row is only built for a player who holds its permission, and the permission
set is worked out on the server and sent to that one client. A moderator's
client is never told the ban option exists. Every action is checked again on
the server when it runs, so editing the menu client-side gets you nothing.

Two consequences worth knowing:

- An option you delete a line for is treated as **owner-only**, not as free.
  Forgetting a permission locks you out rather than handing it to everybody.
- A section of the menu with no permitted rows in it is not shown at all. That
  is why a moderator has no Garage section.

### The full list

| Key | Option |
|---|---|
| `menu.open` | Being able to open the menu at all |
| `self.godmode` | God mode |
| `self.invisible` | Invisibility |
| `self.noclip` | Noclip |
| `self.heal` | Heal yourself |
| `self.armour` | Full armour |
| `self.tpmarker` | Teleport to waypoint |
| `self.tpcoords` | Teleport to typed coordinates |
| `self.tpsaved` | The `Config.Teleports` list |
| `player.list` | The Players section, and the player picker |
| `player.goto` | Go to a player |
| `player.bring` | Bring a player |
| `player.spectate` | Spectate |
| `player.revive` | Revive |
| `player.heal` | Heal another player |
| `player.slay` | Slay |
| `player.freeze` | Freeze and unfreeze |
| `player.kick` | Kick |
| `player.ban` | Ban |
| `player.unban` | The ban list, and lifting bans |
| `player.warn` | Warn |
| `player.setrank` | Change somebody's staff rank |
| `player.identifiers` | Print a player's identifiers |
| `vehicle.spawn` | Spawn vehicles |
| `vehicle.delete` | Delete the vehicle in front of you |
| `vehicle.repair` | Repair |
| `vehicle.refuel` | Refuel |
| `vehicle.flip` | Flip upright |
| `vehicle.dvarea` | Delete vehicles in a radius, and `/dv` |
| `vehicle.dvall` | Delete every vehicle on the map |
| `prop.deletenearest` | Delete the prop you are looking at |
| `prop.deletearea` | Delete props or loose peds in a radius, and `/dp` |
| `prop.deleteall` | Delete every prop on the map |
| `prop.deleteplayer` | Delete everything a named player spawned |
| `prop.toggleproplog` | The prop spawn logging switch |
| `garage.lookup` | Look up a garage |
| `garage.give` | Give a vehicle to a garage |
| `garage.remove` | Remove a vehicle from a garage |
| `staff.online` | Print the online staff list |
| `staff.chat` | Staff chat |
| `staff.announce` | Server announcements |
| `staff.logs` | The log lookup |
| `staff.alerts` | **Receiving** anti-cheat alerts, and the status readout |
| `staff.serverinfo` | Server info readout |

`staff.alerts` is the odd one out: it is not a menu row, it is who gets told
when the anti-cheat fires. It is set from `Config.AntiCheat.alertRank` rather
than from the permission, so change it there.

---

## The menu

```lua
Config.MenuKey        = 'INSERT'   -- default bind only, see below
Config.MenuPosition   = 'right'    -- 'right' | 'left' | 'center'
Config.MenuColour     = { 46, 134, 193 }
Config.MenuMaxVisible = 10
Config.MenuWatermark  = true
Config.MenuSounds     = true
```

`Config.MenuKey` is the **default** for a player who has never had the bind
before. Once somebody has connected once, their own choice in
Settings → Key Bindings → FiveM wins and this value is ignored for them.
Changing it will not move an existing bind.

### Text boxes

```lua
Config.UseNuiInput = true
```

Every prompt that asks you to type something - a ban reason, an identifier, a
model name - is an HTML box drawn over the game. **That is what makes Ctrl+V
work.** The game's own on-screen keyboard has no clipboard support of any kind,
so an identifier cannot be pasted into it.

In the box: Enter confirms, Escape cancels, clicking outside it cancels. The
menu stops reading keys while it is open, so typing does not move the cursor
underneath.

Setting this to `false` falls back to the game keyboard. You lose paste. Only
worth doing if an NUI frame causes you a specific problem.

To hide or reorder whole sections, edit `Config.MenuSections`:

```lua
Config.MenuSections = {
    { id = 'players', label = 'Players' },   -- moved to the top
    { id = 'self',    label = 'Self' },
    { id = 'props',   label = 'Props & Entities' },
    -- 'garage' deleted, so the section never appears for anyone
}
```

`label` is free text. `id` must stay one of `self`, `players`, `vehicle`,
`props`, `garage`, `staff` unless you add a builder for a new one - see
`docs/EXTENDING.md`.

---

## Prop logging

```lua
Config.AntiCheat.logPropSpawns = false
Config.AntiCheat.propLogRank   = 'admin'
```

When on, every prop created anywhere on the server prints to the F8 console of
staff at `propLogRank` or above:

```
[tsivtools] prop spawned: user ID = 4 (Name), prop ID = 131074, netId = 12, model = -1273811207
```

It is off by default because a populated server creates a great many props.

The switch in **Props & Entities** flips it at runtime without editing the
file. That runtime value is stored in `data/settings.json` and **takes priority
over `config.lua`**, so if the toggle seems stuck, that is where to look.
Deleting `data/settings.json` while the server is stopped resets it.

`logVehicleSpawns` and `logPedSpawns` do the same for those, and have no
runtime toggle.

### Spawns in the log store

```lua
Config.AntiCheat.logSpawnsToStore = true
```

Spawns are written to the tsivtools log store as well as to F8, under the
`props` category. That is what lets the identifier lookup answer "what did this
player spawn an hour ago?" instead of only showing it live.

Nothing is written unless the matching logging switch above is on, so this
cannot grow a file you did not ask for. Turn the category off entirely in
`Config.Logging.categories.props`, and remember `Config.Logging.maxEntries`
caps the file - a busy server with prop logging on will churn through it.

### Model names

The server sees a model **hash**. A hash cannot be turned back into a name,
so tsivtools hashes every name it already knows and recognises those:

- everything in the three blacklists
- everything in `Config.VehicleList`
- everything in `Config.AntiCheat.knownModels`

A recognised model prints as `prop_barrel_01a (1541800960)`. Anything else
prints as a bare unsigned hash, which is the form model lookup sites index by.

To make your logs readable, add the props your server actually uses:

```lua
Config.AntiCheat.knownModels = {
    'prop_barrel_01a',
    'prop_roadcone02a',
    'your_custom_prop',
}
```

---

## Spam detection

```lua
Config.AntiCheat.propSpam = {
    enabled   = true,
    threshold = 10,      -- more than this many ...
    window    = 3.0,     -- ... within this many seconds
    action    = 'alert', -- 'alert' | 'kick' | 'ban'
    banLength = 0,       -- minutes, 0 = permanent
    reason    = 'Prop spawn flood',
    cleanup   = true,    -- delete the props from the burst
}
```

`vehicleSpam`, `pedSpam` and `explosions` have the same shape.

All three actions alert staff. `kick` and `ban` additionally punish. The alert
goes to `Config.AntiCheat.alertRank` and above, in chat and as an F8 block
containing the player's name, user ID, **steam ID**, identifier, the count and
the model.

Two things to get right before you turn `action` up to `'ban'`:

- **Tune the threshold on your own server first.** Some scripts legitimately
  create a burst of props. Run with `'alert'` for a week and see what fires.
- **`exemptRank` decides who is not counted.** It defaults to `admin`, so your
  own staff do not set off their own alarms. Anybody at that rank or above is
  skipped by the spam counters and by the client checks entirely.

---

## Blacklisted models

```lua
Config.AntiCheat.blacklistedProps = {
    'prop_beach_fire',
    'prop_dumpster_01a',
}
Config.AntiCheat.blacklistAction    = 'log'   -- 'log' | 'kick' | 'ban'
Config.AntiCheat.blacklistBanLength = 0
```

Creating one of these is cancelled before the entity exists. Whatever
`blacklistAction` says, every staff member at `alertRank` or above gets exactly
this line in F8:

```
potential cheater spawning props: user ID = 4, prop ID: 131074
```

Names are matched case-insensitively, and raw hashes work too:

```lua
blacklistedProps = { 'prop_dumpster_01a', -206690185 },
```

`blacklistedVehicles` and `blacklistedPeds` work identically.

Staff at `exemptRank` and above can still spawn blacklisted models, otherwise
an admin cannot clear up after a cheater using the same prop.

---

## Client side checks

```lua
Config.AntiCheat.client = {
    enabled        = true,
    speedCheck     = true,
    speedThreshold = 12.0,   -- m/s on foot; a sprint is about 7
    healthCheck    = true,
    maxHealth      = 200,
    maxArmour      = 100,
    weaponCheck    = true,
    blacklistedWeapons = { 'WEAPON_RAILGUN', 'WEAPON_MINIGUN' },
    interval       = 5,
}
```

These run on the player's machine. A player who is cheating controls that
machine, so **none of this is proof**. Every result arrives as an alert that
says so, and nothing here bans anybody automatically. Use them as a nudge to go
and spectate somebody, nothing more.

The speed check ignores vehicles, falling, parachuting, ragdolls and swimming,
and resets after any teleport tsivtools performs. It will still fire
occasionally on other scripts' teleports. Raise `speedThreshold` if a specific
script on your server trips it constantly.

---

## Explosions

```lua
Config.AntiCheat.explosions = {
    enabled   = true,
    blocked   = { 2, 4, 6, ... },  -- types nobody may ever trigger
    threshold = 6,
    window    = 6.0,
    action    = 'alert',
}
```

A blocked type is cancelled outright. Anything not blocked is rate limited by
`threshold` and `window`.

The type ids come from the game. The ones most worth blocking are the ones no
player action produces: `2` (car), `4` (plane), `6` (bike), `8` (dir_steam),
`9` (dir_flame), `10` (dir_water_hydrant), `11`-`14` (dir gas canister and
friends), `27` (train), `28` (barrel), `29` (propane), `30` (blimp), and the
`31`-`41` range. `1` (grenade launcher), `3` (grenade), `5` (rocket),
`7` (sticky bomb) and `0` (petrol pump) are left out of the default list
because ordinary gameplay produces them.

Look up the full list under `EXPLOSION_TYPE` in any FiveM natives reference.

---

## Garage storage

```lua
Config.Garage = {
    mode = 'file',   -- 'file' | 'mysql'
}
```

**`file`** stores vehicles in `data/garages.json`. Nothing to install. Your
framework's own garage script will not see them, so this is for testing and for
servers with no framework.

**`mysql`** reads and writes a real table, so an ESX or QB garage picks the
vehicle up straight away. Set `Config.Database.enabled = true` as well, install
oxmysql, and `ensure oxmysql` above tsivtools in `server.cfg`.

The column names are configurable because no two schemas agree:

```lua
Config.Garage = {
    mode         = 'mysql',
    table        = 'owned_vehicles',
    ownerColumn  = 'owner',
    plateColumn  = 'plate',
    propsColumn  = 'vehicle',
    extraColumns = {
        ['type']   = 'car',
        ['stored'] = 1,
    },
}
```

`extraColumns` is written on every insert. Use it for the `NOT NULL` columns
your schema has that tsivtools knows nothing about. Check your own table first:

```sql
DESCRIBE owned_vehicles;
```

A vehicle given through the menu stores a minimal property blob: the model
hash, the plate and the model name. Some garage scripts expect a full property
table with every modification in it and will show a stock vehicle instead. That
is a limitation of handing out a vehicle that was never actually built.

---

## Bans

```lua
Config.Bans = {
    identifierTypes = { 'license', 'steam', 'discord', 'xbl', 'live', 'fivem' },
    message = 'You are banned from this server.\n\nReason: %s\nExpires: %s\nBan ID: %s',
    permanentText = 'Never',
}
```

A ban stores **every** identifier the player held at the time, and a connection
is refused if any one of them matches. Changing one is not enough to get back
in.

The three `%s` in `message` are, in order: reason, expiry, ban id. Keep all
three, and keep them in that order.

Lift a ban from **Players → Bans**, or by deleting its row if you are on MySQL.

---

## Logs and Discord

```lua
Config.Logging = {
    maxEntries = 5000,
    categories = {
        staff = true, anticheat = true, connect = true,
        ban = true, garage = true, chat = false,
    },
}
```

`maxEntries` only applies to file storage: once the file passes it, the oldest
entries are dropped. On MySQL nothing is trimmed, so prune it yourself if it
grows.

A category set to `false` is never written, and therefore never found by the
lookup afterwards. `chat` is off by default, because logging staff chat is a
decision you should make deliberately.

Discord mirroring:

```lua
Config.Logging.discord = {
    enabled = true,
    username = 'tsivtools',
    webhooks = {
        anticheat = 'https://discord.com/api/webhooks/...',
        ban       = 'https://discord.com/api/webhooks/...',
        staff     = '',   -- empty means this category is not mirrored
    },
}
```

Get a URL from Discord: channel settings → Integrations → Webhooks → New
webhook → Copy Webhook URL.

Messages are queued and sent about one per second, because Discord rate limits
webhooks and a burst of detections would otherwise be dropped.

Treat a webhook URL like a password. Anybody who has it can post into that
channel. Do not commit a real one to a public repository.

---

## MySQL

```lua
Config.Database = {
    enabled  = false,
    banTable = 'tsivtools_bans',
    logTable = 'tsivtools_logs',
}
```

With `enabled = true`, bans and logs go to MySQL through oxmysql. Both tables
are created on first start if they do not exist.

Requirements:

1. oxmysql installed and `ensure oxmysql` **above** `ensure tsivtools`.
2. `set mysql_connection_string "..."` in `server.cfg`.

If oxmysql is not running, tsivtools says so in the console and falls back to
file storage rather than erroring on every write.

Switching from file to MySQL does not move existing data across. The JSON files
are left alone, so you can switch back.

---

## Teleports and vehicles

```lua
Config.Teleports = {
    { label = 'Legion Square', coords = vector3(195.0, -933.0, 30.7) },
}

Config.VehicleList = {
    { label = 'Sultan RS', model = 'sultanrs' },
}

Config.AreaRadiusOptions = { 5, 10, 25, 50, 100, 250 }
```

To get coordinates for a new teleport: stand where you want it, then use
**Self → Copy your coordinates to F8**. It prints a line you can paste straight
into `Config.Teleports`.

---

## Chat commands

These exist alongside the menu and go through the same permission check.

| Command | Permission |
|---|---|
| `/tsivtools` | `menu.open` |
| `/bring <id>` | `player.bring` |
| `/goto <id>` | `player.goto` |
| `/revive [id]` | `player.revive` |
| `/slay <id>` | `player.slay` |
| `/dv [radius]` | `vehicle.dvarea` |
| `/dp [radius]` | `prop.deletearea` |
| `/staffchat <message>` | `staff.chat` |

Server console only:

| Command | Does |
|---|---|
| `tsivtools_whoami <id>` | Print a player's identifiers and rank |
| `tsivtools_reload` | Re-evaluate every online player's rank |

---

## Things tsivtools deliberately will not do

Worth knowing before you rely on it:

- **It does not detect client-side cheat menus.** It sees entities the server
  knows about. A menu that only affects the cheater's own client is invisible
  to it, and to every other Lua anti-cheat.
- **It does not stop anyone with script hook enabled.** Leave
  `sv_scriptHookAllowed` off.
- **It does not obfuscate anything or phone home.** Every line of it is
  readable, which is the point. You can audit exactly what it does with your
  server's data before you run it.
