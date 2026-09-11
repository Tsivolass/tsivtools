--[[
    tsivtools - configuration

    Everything you are meant to change lives in this file. You should not have
    to touch anything inside client/ or server/ to run the resource on your own
    server.

    A short map of the file, top to bottom:

      1. General          - prefix, keybind, menu look
      2. Ranks            - the staff ladder (mod -> owner)
      3. Staff            - who has which rank
      4. Permissions      - which rank is needed for every single menu option
      5. Menu             - grouping / ordering of the menu
      6. Teleports        - fixed teleport locations
      7. Vehicles         - the quick spawn list
      8. Garage           - how owned vehicles are stored
      9. AntiCheat        - prop spam, blacklists, F8 logging
     10. Logging          - what gets written to the log store / Discord
     11. Database         - MySQL on/off (off = flat JSON files, no setup)
]]

Config = {}

-- ============================================================================
-- 1. General
-- ============================================================================

-- Prefix used in chat messages. ^5 is light blue, ^7 resets. See docs.
Config.Prefix = '^5[tsivtools]^7 '

-- Prefix used in the F8 console. The console does not render ^ colours the
-- same way chat does, so this is kept plain.
Config.ConsolePrefix = '[tsivtools] '

-- The command the menu keybind is bound to. Players can also type /tsivtools.
Config.MenuCommand = 'tsivtools'

-- Default key for the menu. This is only the DEFAULT: once a player has joined
-- once, the bind lives in their own FiveM settings and this value is ignored
-- for them. They rebind it in:
--     Pause menu -> Settings -> Key Bindings -> FiveM -> "Open the tsivtools menu"
-- Valid names are FiveM key names, e.g. INSERT, DELETE, HOME, F2, F6, PRIOR.
Config.MenuKey = 'INSERT'

-- Menu position on screen: 'right', 'left' or 'center'.
Config.MenuPosition = 'right'

-- Menu accent colour {r, g, b}. Used for the header bar and the selection bar.
Config.MenuColour = { 46, 134, 193 }

-- How many rows are visible before the menu starts scrolling.
Config.MenuMaxVisible = 10

-- Show a small "TSIVTOOLS" watermark while the menu is open.
Config.MenuWatermark = true

-- Play the standard GTA menu click sounds.
Config.MenuSounds = true

-- ============================================================================
-- 2. Ranks
-- ============================================================================
-- The ladder. Higher level = more power. You can add your own ranks, e.g.
--     { name = 'trial', label = 'Trial Mod', level = 5 },
-- as long as every rank has a unique name and a unique level.
--
-- Anything in Config.Permissions refers to these names.

Config.Ranks = {
    { name = 'mod',        label = 'Moderator',  level = 10 },
    { name = 'admin',      label = 'Admin',      level = 20 },
    { name = 'superadmin', label = 'Superadmin', level = 30 },
    { name = 'owner',      label = 'Owner',      level = 40 },
}

-- ============================================================================
-- 3. Staff
-- ============================================================================
-- Map an identifier to a rank name from Config.Ranks.
--
-- How to find your identifier: join your server, then in the SERVER console
-- type   tsivtools_whoami 1   (1 = your server id, shown in the player list).
-- It prints every identifier you have. Paste the one you want below.
--
-- steam: identifiers only exist if the player has Steam running. license: is
-- always present, so license: is the safer choice for a real server.

Config.Staff = {
    -- ['license:0000000000000000000000000000000000000000'] = 'owner',
    -- ['steam:110000100000000']                            = 'admin',
    -- ['discord:000000000000000000']                       = 'mod',
}

-- Also honour server ACE permissions on top of the table above.
-- With this on you can do the following in server.cfg:
--     add_ace group.admin tsivtools.superadmin allow
--     add_principal identifier.license:abc... group.admin
-- The ace name is Config.AcePrefix .. '.' .. rankName
Config.UseAcePermissions = true
Config.AcePrefix = 'tsivtools'

-- Read the rank from your framework's group instead, if you run one.
-- 'none' | 'esx' | 'qb'
-- With 'esx', an ESX group of "admin" maps to the tsivtools rank of the same
-- name if one exists; otherwise use Config.FrameworkGroupMap below.
Config.Framework = 'none'

Config.FrameworkGroupMap = {
    ['mod']        = 'mod',
    ['admin']      = 'admin',
    ['superadmin'] = 'superadmin',
    ['owner']      = 'owner',
}

-- If someone holds several of the above at once, the highest rank wins.

-- ============================================================================
-- 4. Permissions
-- ============================================================================
-- THIS is the table that decides which options show up for which rank.
--
-- Every menu option has a key. Set the key to the MINIMUM rank name that may
-- use it. Set it to false to disable the option for everyone, including owner.
--
-- The menu is built per player from this table, so a moderator literally never
-- receives the options they are not allowed to use - they are not hidden on
-- screen, they are never sent to that client. Every action is checked again on
-- the server when it is used, so editing the menu client-side achieves nothing.

Config.Permissions = {
    -- menu itself
    ['menu.open']              = 'mod',

    -- self
    ['self.godmode']           = 'admin',
    ['self.invisible']         = 'admin',
    ['self.noclip']            = 'mod',
    ['self.heal']              = 'mod',
    ['self.armour']            = 'mod',
    ['self.cleararea']         = 'admin',
    ['self.tpmarker']          = 'mod',
    ['self.tpcoords']          = 'admin',
    ['self.tpsaved']           = 'mod',

    -- players
    ['player.list']            = 'mod',
    ['player.goto']            = 'mod',
    ['player.bring']           = 'mod',
    ['player.spectate']        = 'mod',
    ['player.revive']          = 'mod',
    ['player.heal']            = 'mod',
    ['player.slay']            = 'admin',
    ['player.freeze']          = 'mod',
    ['player.kick']            = 'mod',
    ['player.ban']             = 'admin',
    ['player.unban']           = 'superadmin',
    ['player.warn']            = 'mod',
    ['player.setrank']         = 'owner',
    ['player.identifiers']     = 'admin',

    -- vehicles
    ['vehicle.spawn']          = 'admin',
    ['vehicle.delete']         = 'mod',
    ['vehicle.repair']         = 'mod',
    ['vehicle.refuel']         = 'mod',
    ['vehicle.flip']           = 'mod',
    ['vehicle.dvarea']         = 'admin',
    ['vehicle.dvall']          = 'superadmin',

    -- props / entities
    ['prop.deletenearest']     = 'mod',
    ['prop.deletearea']        = 'admin',
    ['prop.deleteall']         = 'superadmin',
    ['prop.deleteplayer']      = 'admin',
    ['prop.toggleproplog']     = 'admin',

    -- garage
    ['garage.lookup']          = 'mod',
    ['garage.give']            = 'superadmin',
    ['garage.remove']          = 'superadmin',

    -- staff / logs
    ['staff.online']           = 'mod',
    ['staff.chat']             = 'mod',
    ['staff.announce']         = 'admin',
    ['staff.logs']             = 'admin',
    ['staff.alerts']           = 'superadmin', -- receives anti-cheat alerts
    ['staff.serverinfo']       = 'admin',
}

-- ============================================================================
-- 5. Menu
-- ============================================================================
-- Order and titles of the top level menu. Remove an entry to hide the whole
-- submenu. The 'id' values are used by client/main.lua, do not invent new ones
-- here without adding the matching builder (see docs/EXTENDING.md).

Config.MenuSections = {
    { id = 'self',    label = 'Self' },
    { id = 'players', label = 'Players' },
    { id = 'vehicle', label = 'Vehicles' },
    { id = 'props',   label = 'Props & Entities' },
    { id = 'garage',  label = 'Garage' },
    { id = 'staff',   label = 'Staff & Logs' },
}

-- ============================================================================
-- 6. Teleports
-- ============================================================================

Config.Teleports = {
    { label = 'Legion Square',   coords = vector3(195.0, -933.0, 30.7) },
    { label = 'Mission Row PD',  coords = vector3(441.0, -982.0, 30.7) },
    { label = 'Pillbox Hospital',coords = vector3(298.0, -584.0, 43.3) },
    { label = 'Airport',         coords = vector3(-1037.0, -2737.0, 20.2) },
    { label = 'Sandy Shores',    coords = vector3(1853.0, 3689.0, 34.3) },
    { label = 'Paleto Bay',      coords = vector3(-109.0, 6467.0, 31.6) },
    { label = 'Mount Chiliad',   coords = vector3(501.0, 5604.0, 797.9) },
}

-- ============================================================================
-- 7. Vehicles
-- ============================================================================
-- Quick spawn list. Anything not in the list can still be spawned by typing a
-- model name into the "Spawn by name" option.

Config.VehicleList = {
    { label = 'Sultan RS',   model = 'sultanrs' },
    { label = 'Kuruma',      model = 'kuruma' },
    { label = 'Police Cruiser', model = 'police' },
    { label = 'Ambulance',   model = 'ambulance' },
    { label = 'Buzzard',     model = 'buzzard' },
    { label = 'Sanchez',     model = 'sanchez' },
    { label = 'Dinghy',      model = 'dinghy' },
}

-- Delete radius options offered in the menu, in metres.
Config.AreaRadiusOptions = { 5, 10, 25, 50, 100, 250 }

-- ============================================================================
-- 8. Garage
-- ============================================================================

Config.Garage = {
    -- 'file' stores owned vehicles in tsivtools/data/garages.json. No database
    -- needed, which is what you want while testing.
    -- 'mysql' reads and writes a real table through oxmysql. Turn
    -- Config.Database.enabled on as well if you use this.
    mode = 'file',

    -- Only used when mode = 'mysql'. These defaults match a stock ESX
    -- owned_vehicles table. Change the column names to match your own schema.
    table         = 'owned_vehicles',
    ownerColumn   = 'owner',      -- holds the identifier
    plateColumn   = 'plate',
    propsColumn   = 'vehicle',    -- JSON blob of vehicle properties
    extraColumns  = {             -- written on insert, adjust to your schema
        -- ['type']    = 'car',
        -- ['job']     = nil,
        -- ['stored']  = 1,
    },

    -- Plate generator for vehicles handed out through the menu.
    platePrefix = 'TSIV',
    plateLength = 8,
}

-- ============================================================================
-- 9. AntiCheat
-- ============================================================================

Config.AntiCheat = {
    enabled = true,

    -- ------------------------------------------------------------------
    -- Prop spawn logging
    -- ------------------------------------------------------------------
    -- When this is on, EVERY prop that is created gets printed to the F8
    -- console of staff whose rank is at least propLogRank, in the form:
    --     [tsivtools] prop spawned: user ID = 4 (Name), prop ID = 131074, model = prop_barrel_01a
    -- Off by default because a busy server creates a lot of props.
    -- Staff with the prop.toggleproplog permission can flip this at runtime
    -- from the menu without editing this file.
    logPropSpawns = false,
    propLogRank   = 'admin',

    -- Also log vehicles and peds the same way.
    logVehicleSpawns = false,
    logPedSpawns     = false,

    -- ------------------------------------------------------------------
    -- Prop spam
    -- ------------------------------------------------------------------
    -- If a player creates more than `threshold` props inside `window` seconds,
    -- act. 'alert' notifies every online staff member of rank alertRank or
    -- above (chat + F8, including their steam identifier and server id).
    -- 'ban' bans them immediately instead, and still posts the alert.
    -- 'kick' kicks without banning.
    propSpam = {
        enabled   = true,
        threshold = 10,
        window    = 3.0,
        action    = 'alert',           -- 'alert' | 'kick' | 'ban'
        banLength = 0,                 -- minutes, 0 = permanent
        reason    = 'Prop spawn flood',
        -- Delete the props that were part of the burst.
        cleanup   = true,
    },

    -- Same idea for vehicles and peds.
    vehicleSpam = {
        enabled   = true,
        threshold = 6,
        window    = 3.0,
        action    = 'alert',
        banLength = 0,
        reason    = 'Vehicle spawn flood',
        cleanup   = true,
    },

    pedSpam = {
        enabled   = true,
        threshold = 8,
        window    = 3.0,
        action    = 'alert',
        banLength = 0,
        reason    = 'Ped spawn flood',
        cleanup   = true,
    },

    -- Who receives anti-cheat alerts. Anything at this rank or above.
    alertRank = 'superadmin',

    -- ------------------------------------------------------------------
    -- Blacklisted models
    -- ------------------------------------------------------------------
    -- Creating one of these is blocked outright, and immediately printed to
    -- the F8 console of every staff member at alertRank or above as:
    --     potential cheater spawning props: user ID = 4, prop ID: 131074
    -- Model names are case-insensitive, hashes are also accepted.
    blacklistedProps = {
        'prop_beach_fire',
        'prop_bmb_01',
        'prop_ld_bomb',
        'prop_ld_bomb_01',
        'prop_ld_bomb_01_open',
        'prop_sacktruck_02a',
        'prop_dumpster_01a',
        'prop_offroad_tyres02',
        'prop_gold_bar',
        'prop_mp_arrow_barrier_01',
        'prop_mp_cone_01',
        'prop_haybale_01',
        'stt_prop_stunt_bblock_hgey',
        'stt_prop_stunt_bblock_qp1',
        'prop_train_ticket_01',
    },

    blacklistedVehicles = {
        'rhino',
        'khanjali',
        'thruster',
        'hydra',
        'lazer',
        'savage',
        'insurgent3',
        'oppressor',
        'oppressor2',
    },

    blacklistedPeds = {
        'a_c_shark',
        'a_c_killerwhale',
    },

    -- What to do to the player who tried to spawn a blacklisted model.
    -- 'log' just logs it, 'kick' and 'ban' also punish. The entity is blocked
    -- either way.
    blacklistAction    = 'log',        -- 'log' | 'kick' | 'ban'
    blacklistBanLength = 0,            -- minutes, 0 = permanent
    blacklistReason    = 'Spawning a blacklisted model',

    -- ------------------------------------------------------------------
    -- Explosions
    -- ------------------------------------------------------------------
    explosions = {
        enabled   = true,
        -- Explosion types nobody should ever trigger. Numeric ids, see
        -- docs/CUSTOMISING.md for the list.
        blocked   = { 2, 4, 6, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41 },
        threshold = 6,                 -- allowed explosions ...
        window    = 6.0,               -- ... inside this many seconds
        action    = 'alert',           -- 'alert' | 'kick' | 'ban'
        banLength = 0,
        reason    = 'Explosion spam',
    },

    -- ------------------------------------------------------------------
    -- Client side checks
    -- ------------------------------------------------------------------
    -- These run on the player's own machine and report back. They are a
    -- convenience, not a wall: treat every one of them as a hint that
    -- something is worth looking at, never as proof.
    client = {
        enabled = true,
        -- Report players who are moving faster on foot than a human can.
        speedCheck        = true,
        speedThreshold    = 12.0,      -- m/s on foot, sprint is around 7
        -- Report health/armour above the game maximum.
        healthCheck       = true,
        maxHealth         = 200,
        maxArmour         = 100,
        -- Report blacklisted weapons appearing in the inventory.
        weaponCheck       = true,
        blacklistedWeapons = {
            'WEAPON_RAILGUN',
            'WEAPON_MINIGUN',
            'WEAPON_RPG',
            'WEAPON_GRENADELAUNCHER',
            'WEAPON_FIREWORK',
            'WEAPON_STICKYBOMB',
        },
        -- How often the client reports in, in seconds.
        interval = 5,
    },

    -- Players with this rank or above are skipped by the client checks and by
    -- the spam counters, so your own staff do not trip their own alarms.
    exemptRank = 'admin',

    -- Delete every entity a player created when they disconnect.
    cleanupOnDisconnect = false,
}

-- ============================================================================
-- 10. Logging
-- ============================================================================

Config.Logging = {
    -- Keep this many log lines per category before the oldest are dropped.
    -- Only applies to file mode.
    maxEntries = 5000,

    -- Categories that get written. Set one to false to stop recording it.
    categories = {
        staff     = true,   -- every menu action a staff member performs
        anticheat = true,   -- detections
        connect   = true,   -- joins / leaves
        ban       = true,
        garage    = true,
        chat      = false,
    },

    -- Discord webhooks. Leave a URL empty to disable that category.
    -- Anything logged in a category with a webhook is mirrored to Discord.
    discord = {
        enabled = false,
        username = 'tsivtools',
        avatar   = '',
        webhooks = {
            staff     = '',
            anticheat = '',
            connect   = '',
            ban       = '',
            garage    = '',
        },
        colours = {
            staff     = 3066993,
            anticheat = 15158332,
            connect   = 3447003,
            ban       = 10038562,
            garage    = 15844367,
        },
    },
}

-- ============================================================================
-- 11. Database
-- ============================================================================

Config.Database = {
    -- false = everything is stored in tsivtools/data/*.json. Nothing else to
    -- install, which is what you want for a first test.
    -- true  = bans, logs and garages go through oxmysql instead.
    enabled = false,

    -- Table names used when enabled is true. tsivtools creates them itself on
    -- first start if they do not exist.
    banTable = 'tsivtools_bans',
    logTable = 'tsivtools_logs',
}

-- ============================================================================
-- 12. Bans
-- ============================================================================

Config.Bans = {
    -- Identifier types checked on connect, in order. A ban is matched if any
    -- of these matches a stored ban.
    identifierTypes = { 'license', 'steam', 'discord', 'xbl', 'live', 'fivem' },

    -- Message the banned player sees. %s placeholders in order:
    -- reason, expiry, ban id.
    message = 'You are banned from this server.\n\nReason: %s\nExpires: %s\nBan ID: %s',

    -- Text used for a permanent ban's expiry.
    permanentText = 'Never',
}
