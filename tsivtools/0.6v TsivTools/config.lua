Config = {}

Config.Prefix = '^5[tsivtools]^7 '

Config.ConsolePrefix = '[tsivtools] '

Config.MenuCommand = 'tsivtools'

Config.MenuKey = 'INSERT'

Config.MenuPosition = 'right'

Config.MenuColour = { 61, 0, 217 }

Config.MenuMaxVisible = 10

Config.MenuWatermark = true

Config.MenuSounds = true

Config.UseNuiInput = true

Config.Ranks = {
    { name = 'mod',        label = 'Moderator',  level = 10 },
    { name = 'admin',      label = 'Admin',      level = 20 },
    { name = 'superadmin', label = 'Superadmin', level = 30 },
    { name = 'owner',      label = 'Owner',      level = 40 },
}

Config.Staff = {

}

Config.UseAcePermissions = true
Config.AcePrefix = 'tsivtools'

-- 'esx' admin maps to  tsivtools rank of the same name if one exists
Config.Framework = 'none'

Config.FrameworkGroupMap = {
    ['mod']        = 'mod',
    ['admin']      = 'admin',
    ['superadmin'] = 'superadmin',
    ['owner']      = 'owner',
}

Config.Features = {

    ['menu.open']          = true,

    ['self.godmode']       = true,
    ['self.invisible']     = true,
    ['self.noclip']        = true,
    ['self.heal']          = true,
    ['self.armour']        = true,
    ['self.cleararea']     = true,
    ['self.tpmarker']      = true,
    ['self.tpcoords']      = true,
    ['self.tpsaved']       = true,

    ['player.list']        = true,
    ['player.goto']        = true,
    ['player.bring']       = true,
    ['player.spectate']    = true,
    ['player.revive']      = true,
    ['player.heal']        = true,
    ['player.slay']        = true,
    ['player.freeze']      = true,
    ['player.kick']        = true,
    ['player.ban']         = true,
    ['player.unban']       = true,
    ['player.warn']        = true,
    ['player.setrank']     = true,
    ['player.identifiers'] = true,
    ['player.watchlist']   = true,
    ['player.tags']        = true,
    ['player.relationships'] = true,
    ['player.rating']      = true,
    ['player.aliases']     = true,

    ['vehicle.spawn']      = true,
    ['vehicle.delete']     = true,
    ['vehicle.repair']     = true,
    ['vehicle.refuel']     = true,
    ['vehicle.flip']       = true,
    ['vehicle.dvarea']     = true,
    ['vehicle.dvall']      = true,

    ['prop.deletenearest'] = true,
    ['prop.deletearea']    = true,
    ['prop.deleteall']     = true,
    ['prop.deleteplayer']  = true,
    ['prop.toggleproplog'] = true,
    ['prop.spawn']         = true,
    ['world.traffic']      = true,
    ['world.cleartraffic'] = true,

    ['garage.lookup']      = true,
    ['garage.give']        = true,
    ['garage.remove']      = true,

    ['staff.online']       = true,
    ['staff.chat']         = true,
    ['staff.announce']     = true,
    ['staff.logs']         = true,
    ['staff.alerts']       = true,
    ['staff.serverinfo']   = true,
}

Config.Permissions = {
    ['menu.open']              = 'mod',

    ['self.godmode']           = 'admin',
    ['self.invisible']         = 'admin',
    ['self.noclip']            = 'mod',
    ['self.heal']              = 'mod',
    ['self.armour']            = 'mod',
    ['self.cleararea']         = 'admin',
    ['self.tpmarker']          = 'mod',
    ['self.tpcoords']          = 'admin',
    ['self.tpsaved']           = 'mod',

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
    ['player.watchlist']       = 'admin',
    ['player.tags']            = 'admin',
    ['player.relationships']   = 'admin',
    ['player.rating']          = 'admin',
    ['player.aliases']         = 'admin',

    ['vehicle.spawn']          = 'admin',
    ['vehicle.delete']         = 'mod',
    ['vehicle.repair']         = 'mod',
    ['vehicle.refuel']         = 'mod',
    ['vehicle.flip']           = 'mod',
    ['vehicle.dvarea']         = 'admin',
    ['vehicle.dvall']          = 'superadmin',

    ['prop.deletenearest']     = 'mod',
    ['prop.deletearea']        = 'admin',
    ['prop.deleteall']         = 'superadmin',
    ['prop.deleteplayer']      = 'admin',
    ['prop.toggleproplog']     = 'admin',
    ['prop.spawn']             = 'admin',
    ['world.traffic']          = 'admin',
    ['world.cleartraffic']     = 'admin',

    ['garage.lookup']          = 'mod',
    ['garage.give']            = 'superadmin',
    ['garage.remove']          = 'superadmin',

    ['staff.online']           = 'mod',
    ['staff.chat']             = 'mod',
    ['staff.announce']         = 'admin',
    ['staff.logs']             = 'admin',
    ['staff.alerts']           = 'superadmin', -- ac alerts
    ['staff.serverinfo']       = 'admin',
}

Config.MenuSections = {
    { id = 'self',    label = 'Self' },
    { id = 'players', label = 'Players' },
    { id = 'vehicle', label = 'Vehicles' },
    { id = 'props',   label = 'Props & Entities' },
    { id = 'garage',  label = 'Garage' },
    { id = 'staff',   label = 'Staff & Logs' },
}

Config.Traffic = {
    disableVehicles = false,
    disablePeds     = false,
    disableCops     = false,
    disableBoats    = false,
    disableTrains   = false,
}

Config.Teleports = {
    { label = 'Legion Square',   coords = vector3(195.0, -933.0, 30.7) },
    { label = 'Mission Row PD',  coords = vector3(441.0, -982.0, 30.7) },
    { label = 'Pillbox Hospital',coords = vector3(298.0, -584.0, 43.3) },
    { label = 'Airport',         coords = vector3(-1037.0, -2737.0, 20.2) },
    { label = 'Sandy Shores',    coords = vector3(1853.0, 3689.0, 34.3) },
    { label = 'Paleto Bay',      coords = vector3(-109.0, 6467.0, 31.6) },
    { label = 'Mount Chiliad',   coords = vector3(501.0, 5604.0, 797.9) },
}

Config.VehicleList = {
    { label = 'Sultan RS',   model = 'sultanrs' }, -- please change this list :)), i added sultan for testing purposes :))
}

Config.AreaRadiusOptions = { 5, 10, 25, 50, 100, 250 }

Config.Garage = {

    -- 'file' or 'mysql'  turn Config.Database.enabled on if mysql is turned on :))
    mode = 'file',

--used only with mysql
    table         = 'owned_vehicles',
    ownerColumn   = 'owner',
    plateColumn   = 'plate',
    propsColumn   = 'vehicle',
    extraColumns  = {
    },

    platePrefix = 'TSIV',
    plateLength = 8,
}

Config.AntiCheat = {
    forgedEvents = {
        enabled   = true,
        action    = 'ban',
        strikes   = 2,
        banLength = 0,
        reason    = 'Sent staff menu events without a staff rank',
    },

    enabled = true,

    logPropSpawns = false, -- NOT RECOMMENDED FOR COMMERCIAL SERVERS !
    propLogRank   = 'admin',

    logVehicleSpawns = false,
    logPedSpawns     = false,

    logSpawnsToStore = true,

-- printing said props by name (basically useless, needed for testing purposes)
    knownModels = {
        'prop_barrel_01a',
        'prop_barrier_work05',
        'prop_boxpile_07d',
        'prop_roadcone02a',
        'prop_cardbordbox_04a',
        'prop_logpile_06',
        'prop_bench_01a',
        'prop_chair_01a',
        'prop_crate_11a',
        'prop_ld_crate_01',
    },

    propSpam = {
        enabled   = true,
        threshold = 10,
        window    = 3.0,
        action    = 'alert',
        banLength = 0,
        reason    = 'Prop spawn flood',
        cleanup   = true,
    },

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

    alertRank = 'superadmin',

    ignoreAmbientEntities = true,

    alertCooldownSeconds = 30,

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

    blacklistAction    = 'log',
    blacklistBanLength = 0,
    blacklistReason    = 'Spawning a blacklisted model',

    explosions = {
        enabled   = true,

        blocked   = { 2, 4, 6, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41 },
        threshold = 6,
        window    = 6.0,
        action    = 'alert',
        banLength = 0,
        reason    = 'Explosion spam',
    },

    client = {
        enabled = true,
        --speedhack check
        speedCheck        = true,
        speedThreshold    = 12.0,
        healthCheck       = true,
        maxHealth         = 200,
        maxArmour         = 100,
        weaponCheck       = true,
        blacklistedWeapons = {
            'WEAPON_RAILGUN',
            'WEAPON_MINIGUN',
            'WEAPON_RPG',
            'WEAPON_GRENADELAUNCHER',
            'WEAPON_FIREWORK',
            'WEAPON_STICKYBOMB',
        },
        interval = 5,
    },

-- players with >= rank will not trip any alert :)
    exemptRank = 'admin',

    cleanupOnDisconnect = false,
}

Config.Logging = {
    -- doesnt work for mysql :)
    maxEntries = 5000,

    categories = {
        staff     = true,
        anticheat = true,
        connect   = true,
        ban       = true,
        garage    = true,
        props     = true,
        chat      = false,
    },

    -- disc webhgook for logs
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
            props     = '',
        },
        colours = {
            staff     = 3066993,
            anticheat = 15158332,
            connect   = 3447003,
            ban       = 10038562,
            garage    = 15844367,
            props     = 9807270,
        },
    },
}

Config.Database = {

    enabled = false, --boolean ;) (can also use install, but only for the first boot (also kinda useless except for testing))

    banTable = 'tsivtools_bans',
    logTable = 'tsivtools_logs',
    watchlistTable = 'tsivtools_watchlist',
    tagsTable = 'tsivtools_player_tags',
    aliasesTable = 'tsivtools_player_aliases',
    relationshipsTable = 'tsivtools_player_relationships',
}

Config.Bans = {
    -- identifiers that get read for bans
    identifierTypes = { 'license', 'steam', 'discord', 'xbl', 'live', 'fivem' },

    message = 'You are banned from this server.\n\nReason: %s\nExpires: %s\nBan ID: %s',

    -- text for a perma/terma :) ban
    permanentText = 'Never',
}
