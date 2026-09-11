# Adding your own code to tsivtools

This is the document to read before you paste somebody else's snippet into
`client/main.lua` and wonder why it does not work.

---

## How a menu option actually works

Every option follows the same path:

```
client/main.lua          server/actions.lua            client/actions.lua
   menu row      ---->    TSIV.RegisterAction   ---->   commands.<name>
                          (permission checked)          (if the client
                                                         has to do it)
```

Three things to keep in your head:

1. **The client never decides anything.** It asks. The server checks the
   permission and does the work.
2. **A row is only built if the server granted its permission.** That happens in
   `sendPermissions` in `server/core.lua`, once per player.
3. **The server never sends the client code to run**, only the *name* of one of
   the fixed commands in `client/actions.lua`. Keep it that way. A server event
   that runs `load(payload)()` on a client is a remote code execution hole, no
   matter how well intentioned the script that added it was.

---

## Worked example: a "set time of day" option

Four edits. Follow them in this order.

### 1. Add a permission key and a feature switch

`config.lua`, in `Config.Permissions`:

```lua
['self.settime'] = 'admin',
```

Skipping this step does not make the option free, it makes it owner-only. An
unknown key is deliberately treated as the highest rank.

Then add the matching switch in `Config.Features`, so the option can be turned
off like every other one:

```lua
['self.settime'] = true,
```

### 2. Register the action on the server

`server/actions.lua`, anywhere near the other self actions:

```lua
TSIV.RegisterAction('self.settime', 'self.settime', function(src, payload)
    local hour = TSIV.ToInt(payload.hour, 0, 23)
    if not hour then
        TSIV.Notify(src, 'That is not an hour between 0 and 23.', 'error')
        return
    end

    -- Everyone's client gets the new time.
    TriggerClientEvent(TSIV.Events.run, -1, 'setTime', { hour = hour })

    TSIV.Notify(src, ('Set the time to %02d:00'):format(hour), 'success')
    TSIV.Logs.Staff(src, ('Set the time of day to %02d:00'):format(hour))
end)
```

The arguments to `RegisterAction` are: the action name, the permission key, and
the handler. The permission has already been checked by the time your handler
runs, so do not check it again.

**Validate every field of `payload`.** It arrived from a client and a client can
send anything. `TSIV.ToInt`, `TSIV.ToNumber`, `TSIV.SafeString` and
`TSIV.ResolveTarget` are there for exactly this and all reject rubbish by
returning `nil`.

### 3. Add the client command

`client/actions.lua`, with the other `commands.` entries:

```lua
commands.setTime = function(payload)
    NetworkOverrideClockTime(payload.hour, 0, 0)
end
```

### 4. Add the menu row

`client/main.lua`, inside `buildSelf`:

```lua
if can('self.settime') then
    menu:Button('Set the time of day', 'Changes it for everybody on the server.', function()
        CreateThread(function()
            local hour = TSIV.InputNumber('Hour (0 to 23)', '12', 2)
            if not hour then return end
            TSIV.Action('self.settime', { hour = hour })
        end)
    end)
end
```

`restart tsivtools`, and the row is there for admins and above.

---

## The rules that are easy to get wrong

**Wrap anything that waits in `CreateThread`.**

`TSIV.Input`, `TSIV.InputNumber` and `TSIV.Request` all block until they get an
answer. `TSIV.Input` opens an HTML text box (so it supports paste), takes NUI
focus, and locks the menu's key handling until it closes - all of which it
undoes for you on both the confirm and the cancel path. A menu callback runs on the menu's own thread, so blocking in one
freezes the menu. Every callback in `client/main.lua` that waits is wrapped:

```lua
menu:Button('Label', 'Description', function()
    CreateThread(function()
        local value = TSIV.Input('Type something', '', 32)
        if not value then return end        -- nil means they cancelled
        TSIV.Action('something', { value = value })
    end)
end)
```

**Check for `nil` after every input.** `nil` means the player pressed Escape.
Carrying on with a `nil` is how you get `attempt to concatenate a nil value` in
somebody's console.

**Do not trust a server id from a client.** Use `TSIV.ResolveTarget`, which
returns `nil` unless it is a currently connected player.

---

## The menu API

Built in `client/menu.lua`. Everything returns the item, so you can keep a
reference and change it later.

```lua
local menu = TSIV.Menu.Create('Title', 'subtitle')

menu:Button('Label', 'Description', function() end)

menu:Checkbox('Label', 'Description', startsChecked, function(state) end)

menu:List('Label', 'Description', {
    { label = 'shown',  value = 1 },
    { label = 'shown2', value = 2 },
}, function(value, index, item) end,   -- Enter
   function(value, index, item) end)   -- left/right, optional

local sub = menu:Submenu('Label', 'Description')
sub:Button('Inside the submenu', '', function() end)

menu:Attach('Label', 'Description', someMenuYouBuiltSeparately)

menu:Label('An unselectable line of text')

menu:Clear()                -- throw away every row, for a rebuild
```

Opening and closing:

```lua
TSIV.Menu.Open(menu)     -- as a new root
TSIV.Menu.Push(menu)     -- on top of the current one, Backspace returns
TSIV.Menu.Back()
TSIV.Menu.Close()
TSIV.Menu.IsOpen()
TSIV.Menu.Refresh()      -- after rebuilding rows while it is open
```

`menu.onOpen` runs each time the menu is shown. Use it for a list that has to
be current, like the ban list:

```lua
local bans = TSIV.Menu.Create('Bans', '')
bans.onOpen = function()
    CreateThread(function()
        bans:Clear()
        for _, ban in ipairs(TSIV.Request('bans.list') or {}) do
            bans:Button(ban.name, ban.reason, function() end)
        end
        TSIV.Menu.Refresh()
    end)
end
```

---

## Asking the server for data

`RegisterAction` is one way. `RegisterRequest` is for when you need an answer
back.

Server:

```lua
TSIV.RegisterRequest('my.thing', 'staff.logs', function(src, payload)
    return { title = 'a heading', lines = { 'line one', 'line two' } }
end)
```

Client:

```lua
CreateThread(function()
    local result = TSIV.Request('my.thing', { some = 'payload' })
    TSIV.ShowBlock(result)        -- prints it as a block in F8
end)
```

`TSIV.Request` returns `nil` on a timeout or when the server refused on
permission grounds. Handle both.

The `{ title = ..., lines = { ... } }` shape is what `TSIV.ShowBlock` and
`TSIV.ConsoleBlock` expect. Sticking to it means your output looks like
everything else in the F8 console.

---

## Writing to the log

```lua
TSIV.Logs.Staff(src, 'what they did', target, { anything = 'extra' })
```

`target` may be a server id, an identifier string, or `nil`.

For something that is not a staff action:

```lua
TSIV.Logs.Write({
    category   = 'anticheat',   -- must be a key in Config.Logging.categories
    message    = 'what happened',
    actor      = 'license:...',
    actorName  = 'Name',
    target     = 'license:...',
    targetName = 'Name',
    data       = { anything = 'extra' },
})
```

Whatever you put in `actor` and `target` is what the identifier lookup searches,
so put identifiers there, not display names. Names go in `actorName` and
`targetName`, which are searched too.

A new category needs a line in `Config.Logging.categories`, or nothing is
written.

---

## Adding a whole new section

Four edits again.

**1.** `config.lua`:

```lua
Config.MenuSections = {
    -- ...
    { id = 'economy', label = 'Economy' },
}
```

**2.** `client/main.lua`, a builder:

```lua
local function buildEconomy(menu)
    if can('economy.givecash') then
        menu:Button('Give cash', 'Hand money to the selected player.', function()
            -- ...
        end)
    end
end
```

**3.** Same file, register it:

```lua
local builders = {
    -- ...
    economy = buildEconomy,
}

local descriptions = {
    -- ...
    economy = 'Money and items.',
}
```

**4.** Add the permission keys to `Config.Permissions`.

The section is skipped automatically for anyone who ends up with no rows in it,
so you do not have to handle that case.

---

## Talking to ESX or QBCore

`Config.Framework` only affects where ranks are read from. The rest of
tsivtools is framework agnostic on purpose.

To use a framework inside your own addition, get the object at the top of the
file rather than per call:

```lua
-- server side, ESX
local ESX = exports['es_extended']:getSharedObject()

TSIV.RegisterAction('economy.givecash', 'economy.givecash', function(src, payload)
    local target = TSIV.ResolveTarget(payload.target)
    if not target then return end

    local amount = TSIV.ToInt(payload.amount, 1, 1000000)
    if not amount then return end

    local player = ESX.GetPlayerFromId(target)
    if not player then return end

    player.addMoney(amount)
    TSIV.Logs.Staff(src, ('Gave $%d to %s'):format(amount, TSIV.Describe(target)), target)
end)
```

Guard it if you want the file to keep loading on a server without that
framework:

```lua
local ESX = nil
if Config.Framework == 'esx' then
    ESX = exports['es_extended']:getSharedObject()
end
```

---

## Adding an anti-cheat check

Server-side detections hang off `entityCreating` and `entityCreated` in
`server/anticheat.lua`. The sliding window helper handles "more than N of X in
Y seconds" for you:

```lua
local window = TSIV.NewWindow(5.0)          -- five second window
local count = window:push(someValue)        -- returns hits still inside it
if count > 10 then
    window:reset()
    TSIV.AntiCheat.Punish(src, 'alert', 'whatever it was', 0, {
        ('count : %d in 5 seconds'):format(count),
    })
end
```

`Punish` takes the player, the action (`'alert'`, `'kick'` or `'ban'`), a
reason, a ban length in minutes, and a list of extra lines for the F8 block. It
alerts staff, writes the log and applies the punishment.

Before you add one, be honest about what it can see. A server-side check on
entity creation is solid. A client-side check is a suggestion from a machine the
suspect controls. Send the second kind through `TSIV.Events.report`, which is
what the existing client checks use, and it will be presented to staff as the
hint it is.

---

## House style

Match what is already there:

- Four spaces, no tabs.
- `local` everything that is not deliberately shared.
- **Do not write comments.** The code carries no comments except a handful in
  `config.lua`, and it stays that way. No file header blocks, no `-- ------`
  separator bars, no `---` doc comments. Name things well instead.
- Messages shown to players are short and end in `!` rather than a full stop:
  `'Player isnt online !'`, `'No vehicle nearby !'`. A `:)` is fine.
- No `while true do ... end` without a `Wait()`. It will hang the client.
- Anything a player typed gets validated on the server before it is used.
