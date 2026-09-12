# A base server you can actually test on

This builds a working FiveM server out of official, open-source parts. It gives
you chat, spawning and a world to test in, which is what was missing.

## About server dumps

Do not build this on a leaked server dump. Two reasons, and the second is not
theoretical:

1. They are somebody else's copyrighted work, redistributed without permission.
2. They are the usual delivery method for backdoors. The two resources that
   started this repo, `esx_LigmaMenu` and `esx_ligmanticheat`, both shipped an
   obfuscated `client/inject.lua` and a `zavarakatranemia.lua` that replaced
   `TriggerServerEvent` globally and ran `load(text)()` on whatever a server
   event sent them. That is remote code execution on every player who connects,
   sitting in a file called "anticheat".

A dump is a bad base for a test server anyway: hundreds of interdependent
resources, a database schema you do not have, and no way to tell which of the
breakages are yours. Everything below is installed from source you can read.

## Install

Run once, from the repository root:

    # Windows
    powershell -ExecutionPolicy Bypass -File server\setup.ps1

    # Linux
    bash server/setup.sh

It downloads [cfx-server-data](https://github.com/citizenfx/cfx-server-data)
(the official base resources, MIT), copies `tsivtools` into `resources/`, and
writes a `server.cfg` if there is not one already. It will not overwrite a
`server.cfg` you have edited.

Then:

1. Put your licence key from <https://portal.cfx.re> into
   `server/server-data/server.cfg`.
2. Extract the [FXServer artifacts](https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/)
   somewhere. Build 5848 or newer.
3. From inside `server/server-data`, run `<artifacts>\FXServer.exe +exec server.cfg`.
4. In FiveM, press F8 and type `connect 127.0.0.1`.

`docs/SETUP.md` covers the same ground by hand if you would rather see each step.

## What you get

`server.cfg` starts these, all from cfx-server-data:

| Resource | Why |
|---|---|
| `chat` | the chat box - staff chat and announcements need it |
| `spawnmanager` | puts you in the world on join |
| `sessionmanager` | lets more than one person connect |
| `mapmanager` | map and gametype handling |
| `basic-gamemode` | a plain freeroam mode |
| `hardcap` | enforces `sv_maxclients` |
| `rconlog` | console logging |

`onesync` is on, which tsivtools needs: without it the server cannot see
entities, so prop logging, spam detection and every area cleanup do nothing.

`sv_scriptHookAllowed 0` stays off. With it on, anybody with a menu mod does
what they like and no Lua anti-cheat will stop them.

## Making yourself owner

The config ships with:

    add_ace group.admin tsivtools.owner allow

so you only need to add yourself to that group. Join once, then in the server
console:

    tsivtools_whoami 1

and put the `license:` line it prints into `server.cfg`:

    add_principal identifier.license:a1b2c3... group.admin

`restart tsivtools`, and Insert opens the menu.

Adding your identifier to `Config.Staff` in `config.lua` works too. The ACE
route keeps your identifier out of the resource, which is tidier if you ever
share it.

## No chat?

tsivtools no longer depends on the chat resource. If `chat` is not running, staff
chat, announcements and anti-cheat alerts are drawn in the bottom left of your
screen and printed to F8 instead. Starting `chat` is still nicer, and the setup
script installs it.

## Adding a framework later

Neither is needed to test tsivtools, which runs standalone. When you want jobs,
money and inventories:

- **ESX** - <https://github.com/esx-framework/esx_core>
- **QBCore** - <https://github.com/qbcore-framework/qb-core>

Both need a database. Install [oxmysql](https://github.com/overextended/oxmysql)
and a MySQL server, put `set mysql_connection_string "..."` in `server.cfg`, and
`ensure oxmysql` above everything that uses it.

Then point tsivtools at it in `config.lua`:

    Config.Framework = 'esx'
    Config.Database.enabled = true
    Config.Garage.mode = 'mysql'

See `docs/CUSTOMISING.md` for the column names the garage expects.
