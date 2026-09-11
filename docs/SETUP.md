# Running a FiveM server on your own PC and testing tsivtools

This assumes you have the FiveM **client** installed and nothing else. By the
end you will have your own server running on your PC, you will be connected to
it, and you will be opening the tsivtools menu with Insert.

Everything below is Windows. Linux notes are at the bottom.

---

## 1. What you are actually installing

Three separate things, which is the part that trips people up:

| Thing | What it is | Where it goes |
|---|---|---|
| FiveM client | The game launcher you already have | `%localappdata%\FiveM` |
| FXServer artifacts | The server program | `C:\FXServer\server` |
| server-data | The resources your server runs, including tsivtools | `C:\FXServer\server-data` |

The client and the server are unrelated installs. You can run both on the same
PC and connect to yourself.

---

## 2. Get a licence key

The server will not start without one. It is free.

1. Go to <https://portal.cfx.re/> and sign in with your Cfx.re (forum) account.
2. Open **Server keys** and press **New server key**.
3. IP address: leave it as `localhost` for a server you only connect to from
   your own PC.
4. Server name: anything.
5. Copy the key. It looks like a long string of letters and numbers.

Keep that tab open, you will paste the key into `server.cfg` shortly.

---

## 3. Download the server

1. Go to <https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/>
2. Take a **recent build**. Avoid the very newest one if you want a quiet life;
   anything from the last month or two is fine. Do not take one older than
   build 5848, tsivtools requires it.
3. You get a `server.7z`. Extract it to `C:\FXServer\server`.

You should now have `C:\FXServer\server\FXServer.exe`.

---

## 4. Download the base resources

1. Go to <https://github.com/citizenfx/cfx-server-data>
2. Green **Code** button, **Download ZIP**.
3. Extract it, and move the *contents* of the `cfx-server-data-master` folder
   into `C:\FXServer\server-data`.

You should now have `C:\FXServer\server-data\resources\` with folders like
`[gameplay]`, `[system]` and `[test]` inside it.

---

## 5. Install tsivtools

Copy the `tsivtools` folder into `C:\FXServer\server-data\resources\`.

So the path to the manifest ends up as:

    C:\FXServer\server-data\resources\tsivtools\fxmanifest.lua

If you keep resources in a bracketed folder, that is fine too:
`resources\[staff]\tsivtools\` works the same way.

---

## 6. Write server.cfg

Create `C:\FXServer\server-data\server.cfg` with this in it. Replace the licence
key on the last line with the one from step 2.

```cfg
# ---- network ----
endpoint_add_tcp "0.0.0.0:30120"
endpoint_add_udp "0.0.0.0:30120"

# ---- OneSync ----
# tsivtools needs this. Without it the server cannot see entities, so prop
# logging, spam detection and every area cleanup silently do nothing.
set onesync on
sv_maxclients 48

# ---- base resources ----
ensure mapmanager
ensure chat
ensure spawnmanager
ensure sessionmanager
ensure basic-gamemode
ensure hardcap

# ---- tsivtools ----
ensure tsivtools

# ---- server identity ----
sv_hostname "tsivtools test server"
sv_licenseKey "PASTE_YOUR_KEY_HERE"
```

Two notes:

- If you later add `oxmysql`, put `ensure oxmysql` **above** `ensure tsivtools`.
- `sv_scriptHookAllowed` is not set, which means it defaults to off. Leave it
  that way. Turning it on lets anyone with a menu mod do whatever they like,
  and no anti-cheat is going to save you from it.

---

## 7. Start the server

Open Command Prompt and run:

```cmd
cd C:\FXServer\server-data
C:\FXServer\server\FXServer.exe +exec server.cfg
```

To save typing, make a file called `start.bat` in `C:\FXServer\server-data`:

```bat
@echo off
C:\FXServer\server\FXServer.exe +exec server.cfg
pause
```

Then double-click `start.bat` from now on.

A window appears with the server console. You are looking for:

```
[tsivtools] storage: file (tsivtools/data)
```

If instead you see errors about `fxmanifest.lua`, the folder is in the wrong
place. Check step 5.

---

## 8. Connect

1. Start FiveM.
2. Press **F8** to open the client console.
3. Type `connect 127.0.0.1` and press Enter.

You will spawn in as a default character. Your server console will print a
`[tsivtools] ... joined` line.

---

## 9. Make yourself staff

You are not staff yet, so Insert does nothing. That is correct behaviour, not a
bug.

In the **server console window**, type:

```
tsivtools_whoami 1
```

`1` is your server id. You will get something like:

```
[tsivtools] identifiers for YourName (id 1)
  rank: none
  license = license:a1b2c3d4e5f6...
  discord = discord:123456789012345678
  fivem   = fivem:1234567
```

Copy the whole `license:...` line. Open
`resources\tsivtools\config.lua`, find `Config.Staff`, and make it look like
this:

```lua
Config.Staff = {
    ['license:a1b2c3d4e5f6...'] = 'owner',
}
```

Note the square brackets and the quotes. They matter.

Now, in the server console:

```
restart tsivtools
```

The menu will appear on your next spawn, or immediately - the client asks the
server for its permissions again a couple of seconds after any restart.

---

## 10. Open the menu

Press **Insert**.

To change that key: pause menu → **Settings** → **Key Bindings** → **FiveM**,
find **Open the tsivtools menu**, and bind whatever you want. That setting
lives in your own FiveM client, not on the server, so each staff member picks
their own.

`Config.MenuKey` in `config.lua` only sets the default for somebody who has
never had a bind before. Changing it will not move an existing bind.

Menu controls:

| Key | Does |
|---|---|
| Arrow up / down | Move |
| Arrow left / right | Change the value on a `< ... >` row |
| Enter | Select |
| Backspace | Back, and close at the top level |

---

## 11. Try it

Work through these in order. Every one of them should do something visible.

**The menu itself**
- Open it. The header shows your name and rank.
- Go into **Self** and turn on **Noclip**. WASD to fly, Q and E for up and down,
  Shift to go faster. Turn it off again.

**Staff list to F8**
- **Staff & Logs → Online staff**, then press F8. You get a table of everyone
  online with a rank, and a count per rank at the bottom.

**Prop logging**
- **Props & Entities → Log every prop spawn to F8**, turn it on.
- Spawn a prop any way you like. If you have nothing that spawns props, open F8
  on the client and paste this once:

  ```lua
  local h = GetHashKey('prop_barrel_01a') RequestModel(h) while not HasModelLoaded(h) do Wait(0) end local c = GetEntityCoords(PlayerPedId()) CreateObject(h, c.x + 2.0, c.y, c.z, true, true, false)
  ```

- Your F8 console gets a line like:

  ```
  [tsivtools] prop spawned: user ID = 1 (YourName), prop ID = 131074, netId = 5, model = -1273811207
  ```

  Turn it back off when you are done. On a busy server this is a lot of output,
  which is why it is off by default.

**Prop spam detection**

Bear in mind you are exempt by default: `Config.AntiCheat.exemptRank` is
`admin`, and you just made yourself `owner`. To test the detection on yourself,
temporarily set your own rank to `mod` in `Config.Staff`, or set `exemptRank`
to `'owner'`. Restart the resource after either change.

Then spawn eleven props inside three seconds. In F8:

```lua
local h = GetHashKey('prop_barrel_01a') RequestModel(h) while not HasModelLoaded(h) do Wait(0) end local c = GetEntityCoords(PlayerPedId()) for i = 1, 11 do CreateObject(h, c.x + i, c.y, c.z, true, true, false) end
```

Every superadmin and above gets a chat alert and an F8 block containing the
player name, user ID, steam ID and identifier. With
`Config.AntiCheat.propSpam.action = 'ban'` they would have been banned instead.

**Blacklisted props**

`prop_dumpster_01a` is on the blacklist out of the box. Try to spawn one while
not exempt and it never appears. Instead, every superadmin sees exactly this in
F8:

```
potential cheater spawning props: user ID = 1, prop ID: 131074
```

**Area cleanup**
- Spawn a handful of vehicles from **Vehicles → Spawn from the list**, get out
  of them, then use **Delete vehicles in a radius**, arrow to `50m`, Enter.
- **Props & Entities → Delete props in a radius** does the same for props.

**Garage**
- **Garage → Give a vehicle to a garage**, pick yourself, model `sultanrs`,
  leave the plate blank to have one generated.
- **Garage → Look up a garage**, pick yourself, press F8. The vehicle is there
  with its plate.
- **Garage → Remove a vehicle from a garage**, same plate, then look it up again.

**Log lookup**
- **Staff & Logs → Look up an identifier**, paste your `license:...`, F8. You
  get every action recorded against you, with a count per category at the top.

---

## 12. Editing while the server runs

You do not have to restart the whole server to pick up a change.

| You changed | Do this in the server console |
|---|---|
| `config.lua` or any `.lua` in tsivtools | `restart tsivtools` |
| `server.cfg` | Restart the whole server |
| A rank, without restarting | `tsivtools_reload` |

`restart tsivtools` also refreshes every connected player's menu, because their
client asks for its permissions again a couple of seconds after the restart.

---

## 13. When something does not work

**Insert does nothing**

- Are you actually staff? `tsivtools_whoami <your id>` in the server console
  will say `rank: none` if you are not.
- Did you put the identifier in with quotes and square brackets?
- Is the bind still on Insert? Check Settings → Key Bindings → FiveM.
- Is `menu.open` in `Config.Permissions` set to a rank you do not hold?

**The menu opens but a section is missing**

Working as designed. A section only appears if you hold at least one permission
inside it. Check `Config.Permissions` for the keys in that section.

**Prop logging and area deletes do nothing**

`set onesync on` is missing from `server.cfg`. Without OneSync the server
cannot enumerate entities, so there is nothing to log or delete.

**`attempt to index a nil value (global 'MySQL')`**

`Config.Database.enabled` is `true` but oxmysql is not running. Either install
oxmysql and `ensure` it above tsivtools, or set `enabled` back to `false`.

**Everything is fine but nothing is logged**

Check `Config.Logging.categories`. A category set to `false` is not recorded at
all, and the lookup cannot find what was never written.

---

## Linux

Same shape, different paths:

```bash
mkdir -p ~/FXServer/server ~/FXServer/server-data
cd ~/FXServer/server
wget https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/<build>/fx.tar.xz
tar xf fx.tar.xz

cd ~/FXServer/server-data
git clone https://github.com/citizenfx/cfx-server-data.git .
cp -r /path/to/tsivtools resources/

bash ~/FXServer/server/run.sh +exec server.cfg
```

`server.cfg` is identical. Run it under `screen` or `tmux` so it survives you
closing the terminal.
