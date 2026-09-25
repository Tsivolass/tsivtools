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

## Security

Assume a cheater has dumped every client file, `config.lua` included, and can
fire any event with any payload. Server files are never sent to players, so
everything that matters is decided there:

- Every menu action and request is checked against the sender's rank on the
  server. Nothing the client says about its own rank is trusted.
- Somebody with no staff rank who fires a staff event gets an alert the first
  time and `Config.anticheat.forgedEvents.action` (a ban by default) the second,
  because the real menu never sends one without a rank.
- Kick, ban, slay, freeze, bring, warn, tags, the watchlist and set rank only
  work on players ranked below you, so a compromised mod cannot touch an admin.
- Offline bans from the watchlist use the identifiers the server stored, never
  a list sent by the client.
- Events are rate limited per player, and staff payloads are never passed on to
  another player's client.
- Webhooks and API keys belong in `server.cfg` convars (`set`, not `setr`),
  because `config.lua` is readable by every player. The server warns on start if
  one is still in `config.lua`. Ban clips only ever travel through the server,
  and only real JPEG frames are posted.

The client side checks (speed, health, heartbeat, aim reports) can be switched
off or faked by anyone running their own Lua, which is why they only raise
alerts or feed the confidence score, and why the server cross-checks aim
reports against what it saw itself.

---

## How the two aim checks work

Both live in 0.9v. `shared/aim.lua` holds the geometry, so the client and the
server measure angles the exact same way. If you want to rebuild either check
from scratch, or change how strict it is, this is the whole thing written out.

Everything named below is in `Config.anticheat.silentAim` or
`Config.anticheat.aimbot`. Nothing is hard coded.

---

### 1. Silent aim, the triangle

The idea. Three points: **you** (the shooter), the **player** you hit, and the
direction your **crosshair was actually pointing** when the bullet left. Those
three make a triangle. The side opposite your aim angle is how far to the side
the barrel was pointing when the hit registered. If that side is longer than a
person could plausibly miss by and still hit, the bullet did not come from
where the gun was looking.

The trigonometry is one line. In a right triangle, the side opposite an angle
equals the adjacent side times the tangent of that angle:

```
side miss = distance x tan(aim angle)
```

`distance` is shooter to victim. `aim angle` is the angle between where the
crosshair pointed and the direction to the victim. So a 10 degree error at 8 m
puts the barrel 1.4 m to the side, and the same 10 degrees at 40 m puts it 7 m
to the side. **This is why the allowed angle has to shrink as distance grows** -
a fixed angle would mean a fixed miss at 5 m and a house-sized miss at 200 m.

So we invert it. We pick how far to the side we are willing to forgive in
**metres**, and turn that into an angle for this particular distance:

```lua
local function allowedOffset(distance, tolerance)
    local rules = settings.silentAim
    local allowed = math.deg(math.atan(tolerance / distance))
    if allowed < rules.minAngle then allowed = rules.minAngle end
    if allowed > rules.maxAngle then allowed = rules.maxAngle end
    return allowed
end
```

Line by line:

1. `math.atan(tolerance / distance)` - the inverse of the tangent above. Feed it
   "how many metres sideways over how many metres away" and it returns the angle
   that produces that miss. At `tolerance = 2.25`: 20.6 degrees at 6 m, 2.6
   degrees at 50 m, 0.6 degrees at 200 m. Exactly the shrink we wanted.
2. `math.deg(...)` - Lua works in radians, the rest of the check works in
   degrees, so convert once here.
3. `if allowed < rules.minAngle` - a floor. Past about 100 m the formula asks for
   an accuracy no honest player has, because the server's copy of a player's
   position is never that exact. `minAngle` (2.0) stops the check from becoming
   a hair trigger at long range.
4. `if allowed > rules.maxAngle` - a ceiling, for the opposite reason. Very close
   up the formula becomes so generous it would forgive anything. `maxAngle`
   (35.0) caps it. With the default `minDistance` of 6 m this rarely binds; it
   matters if you lower `minDistance`.

Then the tolerance itself, which is what keeps this from banning laggy players:

```lua
local function toleranceFor(src, victim, distance)
    local rules = settings.silentAim
    local tolerance = rules.lateralTolerance

    if rules.latencyCompensation then
        local ping = math.min(GetPlayerPing(src) / 1000.0, rules.maxCompensatedPing)
        local velocity = GetEntityVelocity(GetPlayerPed(victim))
        local speed = math.sqrt(velocity.x ^ 2 + velocity.y ^ 2 + velocity.z ^ 2)

        local drift = ping * speed * rules.latencyFactor
        local cap = rules.maxCompensationMetres
        if drift > cap then drift = cap end

        tolerance = tolerance + drift
    end

    if rules.distanceSlack > 0 then
        tolerance = tolerance + distance * rules.distanceSlack
    end

    return tolerance
end
```

Line by line:

1. `local tolerance = rules.lateralTolerance` - the base budget in metres. 2.25 m
   is roughly a player's width plus the slop in GTA's own hit registration.
   Raise it to ban less, lower it to ban more.
2. `GetPlayerPing(src) / 1000.0` - ping in seconds. **This is the single most
   important line in the whole check.** The server's copy of where a player is
   standing is always out of date by about one ping. Without this, a player on a
   bad connection shooting a sprinting target looks identical to a cheater.
3. `math.min(..., rules.maxCompensatedPing)` - clamp it. Somebody on a 5 second
   ping should not get 5 seconds of forgiveness; `pingGate` deals with them
   instead.
4. `GetEntityVelocity(GetPlayerPed(victim))` then `speed` - how fast the
   **victim** is moving. A victim standing still has not drifted, whatever the
   ping is, so they get no extra slack at all.
5. `local drift = ping * speed` - seconds times metres per second gives metres.
   This is literally how far the target moved while the packet was in flight.
   150 ms against a 7 m/s sprinter is 1.05 m of honest error.
6. `if drift > cap` - a hard ceiling (`maxCompensationMetres`, 6 m) so a spoofed
   velocity or a teleport script can never unlock unlimited forgiveness.
7. `tolerance = tolerance + drift` - widen the budget by exactly the lag error
   and not a centimetre more.
8. `distanceSlack` - off by default. Set it above 0 to add a flat extra margin
   proportional to distance, if your server has heavy desync at range.

And the decision, in `Detections.CheckSilentAim`:

```lua
local off
if kind == 'camera' then
    off = tsivtools.Aim.Between(yaw, pitch, targetYaw, targetPitch)
else
    off = math.abs((targetYaw - yaw + 180.0) % 360.0 - 180.0)
    distance = flat
end

local tolerance = toleranceFor(src, victim, distance)
local allowed = allowedOffset(distance, tolerance)
local lateral = off >= 89.9 and math.huge or distance * math.tan(math.rad(off))

if off > allowed and lateral > tolerance then
```

1. `if kind == 'camera'` - when the client reported a camera direction, measure
   the angle between it and the direction to the victim in full **3D**, pitch
   included. 0.8v compared yaw only, so a cheater shooting someone straight above
   them was invisible to it.
2. the `else` branch - with only a ped heading there is no pitch to compare, so
   fall back to a pure yaw difference and swap `distance` for `flat`, the
   horizontal distance. Mixing a 3D distance into a 2D angle would invent a
   vertical error that was never measured.
3. `distance * math.tan(math.rad(off))` - the triangle again, this time forwards:
   turn the measured angle back into metres to the side.
4. `off >= 89.9 and math.huge` - past 90 degrees the tangent goes negative and
   the maths stops meaning anything. Shooting someone behind you is an infinite
   miss, so say so explicitly rather than letting a negative number sneak
   through as "small".
5. `if off > allowed and lateral > tolerance` - **both** must fail. They are two
   views of the same number and a single check would sit right on the boundary
   at some distances. Requiring both removes the knife edge.

**Where the aim direction comes from.** The server cannot see a player's camera.
It can only see the ped's heading, which lags the camera whenever somebody is
hip firing or strafing - a false ban waiting to happen. So 0.9v prefers the
camera direction that `client/aim.lua` reports, and only falls back to ped
heading when no report arrived. When it falls back it compares **yaw only** and
uses the flat distance, because a ped heading carries no pitch and pretending
otherwise would add a fake vertical error at close range.

Two more accuracy fixes worth knowing about:

- `useHitOffset` adds `localPosition` from `weaponDamageEvent`, which is where on
  the body the bullet actually landed, to the victim's origin. Without it a
  headshot at 8 m measures as about 4 degrees of error that was never there.
- `eyeHeight` measures from the shooter's eyes rather than their feet.

---

### 2. Aimbot, the straightness of the path

The idea. A human moving a mouse onto a target draws a curve. They accelerate,
they overshoot, they pull back, their hand shakes. An aimbot draws a line. So:
record where the crosshair was over the last half second, and ask **what
percentage of that path was a straight line**.

Then the part that makes it usable: **the smaller the movement, the higher a
percentage we allow.** If you nudge the crosshair two degrees, of course it is
100% straight - there was no room to curve. If you sweep it 90 degrees across
the screen and it is still 99% straight, no hand did that.

`client/aim.lua` samples `GetGameplayCamRot(2)` every `sampleMs` (20 ms) into a
ring buffer holding `windowMs` (600 ms). When `IsPedShooting` goes true it ships
the buffer. The server does all the judging - the client never sends a verdict,
only raw numbers, so forging one means forging a plausible human path.

The measurement, in `Aim.PathMetrics`:

```lua
local displacement = Aim.Angle(first.x, first.y, first.z, last.x, last.y, last.z)

local pathLength = 0.0
for index = 2, count do
    local a = vectors[index - 1]
    local b = vectors[index]
    local step = Aim.Angle(a.x, a.y, a.z, b.x, b.y, b.z)
    pathLength = pathLength + step
end

local straightness = 100.0
    if pathLength > 0.0001 then
        straightness = displacement / pathLength * 100.0
        if straightness > 100.0 then straightness = 100.0 end
    end
```

Line by line:

1. `displacement` - **this is the delta x of your idea.** The angle from where
   the crosshair started to where it ended. The straight line distance, ignoring
   everything that happened in between.
2. the loop summing `step` - `pathLength`, the distance the crosshair actually
   travelled, adding up every little segment.
3. `displacement / pathLength * 100` - the percentage. A perfectly straight
   sweep travels exactly as far as the straight line, so it scores 100. A path
   that wanders travels further than the straight line, so it scores lower.
   Overshoot and correction hurt it twice, which is exactly right.
4. the `pathLength > 0.0001` guard - a crosshair that never moved would divide by
   zero. A motionless window is called 100% straight and then thrown out anyway,
   because its delta x is far below `minSnapDegrees`.

Angles are measured with `atan2(|a x b|, a . b)`, not `acos(a . b)`. `acos` loses
most of its precision for angles near zero, and small steps are the bulk of the
path length, so `acos` would quietly corrupt the number this whole check rests
on.

The second opinion, in the same function:

```lua
local nx, ny, nz = normal(first, last)
if nx then
    local inside = 0
    for index = 1, count do
        local deviation = Aim.Deviation(vectors[index], nx, ny, nz)
        if deviation <= corridorDegrees then inside = inside + 1 end
    end
    corridor = inside / count * 100.0
end
```

1. `normal(first, last)` - the cross product of the start and end directions,
   normalised. That is the normal of the plane the straight line lies in.
2. `Aim.Deviation` - `asin` of the dot product of a sample against that normal:
   how far off the plane that sample sits, in degrees.
3. `inside / count * 100` - the percentage of sampled points lying within
   `corridorDegrees` (1.5) of the straight line.

Both numbers must exceed their limit before anything is flagged. They fail in
different ways - a path can hug the line and still wobble along it, or wander off
and come back - so demanding both is what keeps a smooth human flick out of the
logs.

The sliding allowance:

```lua
local function slide(displacement, rules, high, low)
    local span = rules.largeSnap - rules.smallSnap
    local ratio = 1.0
    if span > 0 then
        ratio = (displacement - rules.smallSnap) / span
    end

    if ratio < 0 then ratio = 0 elseif ratio > 1 then ratio = 1 end
    if rules.curve ~= 1.0 then ratio = ratio ^ rules.curve end

    return high - (high - low) * ratio
end

function Aim.AllowedStraightness(displacement, rules)
    return slide(displacement, rules, rules.maxAllowed, rules.minAllowed)
end
```

Line by line:

1. `high`, `low` - the top and bottom of the slide. For straightness that is
   `maxAllowed` (100%) down to `minAllowed` (82%). The range it slides across is
   `smallSnap` (5 degrees) to `largeSnap` (90 degrees).
2. `span` - the width of the sliding range.
3. `local ratio = 1.0` and `if span > 0` - if somebody sets `largeSnap` at or
   below `smallSnap` the division would blow up, so the ratio stays at the
   strictest end rather than erroring or, worse, silently allowing everything.
4. `ratio` - where this particular delta x sits inside that range, as 0 to 1.
5. the clamp - anything under `smallSnap` counts as the smallest movement,
   anything over `largeSnap` as the largest. Below 5 degrees you are allowed a
   full 100%, because a tiny nudge being straight proves nothing.
6. `ratio ^ rules.curve` - the shape of the slide. 1.0 is a straight line.
   Above 1.0 stays lenient longer and then drops off fast; below 1.0 tightens
   early.
7. the return - interpolate from `high` down to `low`.

So: 5 degrees allows 100%, 30 degrees allows about 94%, 90 degrees and beyond
allows 82%. `AllowedCorridor` is the same slide against `maxCorridor` and
`minCorridor`. **To make the whole check stricter, raise `minAllowed`. To make
it more forgiving, lower it.** That one number is the main dial.

**Finding the snap.** `Aim.FindSnap` walks backwards from the shot. First it
skips the still samples at the end - that gap is the settle time, and treating it
as part of the movement would dilute every number. Then it keeps walking back
while the crosshair is still moving, allowing up to `maxGap` slow samples so one
momentarily still frame does not cut a real snap in half.

**The four extra signals**, each its own switch, its own points, and its own
module name in the confidence score:

- `teleport` - one sample step bigger than `maxStepDegrees` (25). A real aimbot
  finishes inside a single frame, so it arrives as one giant step rather than a
  path at all. Without this the most obvious cheat of all would fall through the
  straightness test for having too few points to measure.
- `snapSpeed` - degrees per second across the snap, and across the fastest single
  step. Over `maxDegreesPerSecond` (1400) is faster than a hand.
- `settle` - the gap between the crosshair arriving and the trigger. Under
  `minMs` (60) means it fired the instant it landed.
- `overshoot` - the average overshoot across the last `samples` (12) snaps. A
  human passes the target and comes back. An average under `maxAverage` (0.4
  degrees) over twelve separate snaps is not a hand.

**Two things stop this from banning honest players.** `controller` handles
gamepad users, whose aim assist genuinely does snap - `raise` widens their limits
by `controllerSlack`, `skip` exempts them entirely. And the snap has to actually
end on the victim, within `lockCone` degrees, or it is not a snap-to-target and
is not judged at all.

**And what stops a cheater from just lying.** `serverCheck` samples ped heading
server side for anyone who recently fired, and compares how far the server saw
them turn against how far they claimed to turn. It only fires in one direction -
the server seeing far more movement than the client admits to - so a lagging ped
can never trigger it, but a forged report can. If the client module is blocked
entirely, no reports arrive, and after `missing.shots` (12) shots with no data
that is handled like a stopped resource.

---

### How a ban actually happens

Neither check bans on its own. Both feed `server/confidence.lua`, which is the
answer to "never false ban but always ban the cheaters" - those two pull against
each other, and one detector deciding alone is how you get it wrong.

Every detection adds points, scaled by that module's weight in
`Config.anticheat.confidence.weights`. Read the total as a **percentage of
certainty**. Points decay to nothing over `window` (180 s), so evidence has to
keep arriving to keep adding up.

There are two ways to reach a ban, and no staff member is needed for either:

- **`banAt` (100%) with `requireDistinctModules` (2) modules agreeing.** The
  normal path. Two different checks independently pointing at the same player is
  much harder to produce by accident than one check misfiring.
- **`soloBanAt` (170%) from a single module.** The certain path. Some evidence
  does not need a second opinion, it just needs enough of itself. A crosshair
  that teleports across the screen in a single frame four separate times is not
  a person having a good day.

The second threshold sits well above the first on purpose. Corroborated evidence
is trusted sooner; a lone detector has to work much harder before it is allowed
to act by itself. Roughly what each module costs to ban on its own at the
defaults:

| Module | Detections to auto ban alone |
|---|---|
| `teleport` | 4 |
| `godmode` | 4 |
| `aimmismatch` | 5 |
| `snapspeed` | 8 |
| `silentaim` | 10 |
| `aimbot` | 12 |
| `settle` | 13 |
| `overshoot` | 19 |

The hard physical signals ban quickly. The soft behavioural ones need a mountain
of evidence before they will act unaccompanied, which is what you want, because
those are the ones that can be wrong.

**Investigation-only modules.** Anything named in
`Config.anticheat.confidence.evidenceOnly` still scores, still shows up in the
breakdown and still raises alerts, but is excluded from the total that can ban.
`punch` is in there by default - melee spam is already blocked at the event and
is worth knowing about when you are reading a player's history, but it is not
worth a ban and it should not be able to top one up. Anything you are not yet
confident in belongs in this list until you have watched it for a while.

Raising and lowering the two thresholds is the main dial:

- ban **more** aggressively - lower `soloBanAt`, or lower `banAt`
- ban **less** aggressively - raise `soloBanAt`
- never ban from one module - set `soloBanAt = 0`
- never auto ban at all - set `banAt` very high and `soloBanAt = 0`, and staff
  work from the alerts only

Set `Config.anticheat.confidence.enabled = false` and every module goes back to
banning on its own strike counter, the way 0.9v does when you set a module's
`action` to `'ban'`, `'kick'` or `'alert'` instead of `'confidence'`.

Use `anticheat.confidence` from the staff menu to see a live breakdown: the
overall certainty, how much of it is allowed to act, how many modules agree, and
which module contributed what. Watch that for a week before you trust the
numbers - the defaults are a starting point, not a truth.

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
