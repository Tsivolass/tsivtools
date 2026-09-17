Config = {}

Config.prefix = '^5[tsivtools]^7 '

Config.consoleprefix = '[tsivtools] '

Config.menucommand = 'tsivtools'

Config.menukey = 'INSERT'

Config.menuposition = 'right'

Config.menucolour = { 61, 0, 217 }

Config.menumaxvisible = 10

Config.menuwatermark = true

Config.menusounds = true

Config.usenuiinput = true

Config.ranks = {
    { name = 'mod',        label = 'Moderator',  level = 10 },
    { name = 'admin',      label = 'Admin',      level = 20 },
    { name = 'superadmin', label = 'Superadmin', level = 30 },
    { name = 'owner',      label = 'Owner',      level = 40 },
}

Config.staff = {

}

Config.useacepermissions = true
Config.aceprefix = 'tsivtools'

-- 'esx' admin maps to  tsivtools rank of the same name if one exists
Config.framework = 'esx'

Config.frameworkgroupmap = {
    ['mod']        = 'mod',
    ['admin']      = 'admin',
    ['superadmin'] = 'superadmin',
    ['owner']      = 'owner',
}

Config.features = {

    ['menu.open']          = true,

    ['self.godmode']       = false,
    ['self.invisible']     = false,
    ['self.noclip']        = false,
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
    ['player.freeze']      = false,
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
    ['security.view']          = true,
    ['security.monitor']       = true,
    ['security.waveshield.ban'] = true,
    ['security.waveshield.unban'] = true,

    ['vehicle.spawn']      = true,
    ['vehicle.delete']     = true,
    ['vehicle.repair']     = true,
    ['vehicle.refuel']     = true,
    ['vehicle.flip']       = true,
    ['vehicle.dvarea']     = true,
    ['vehicle.dvall']      = false,

    ['prop.deletenearest'] = true,
    ['prop.deletearea']    = true,
    ['prop.deleteall']     = false,
    ['prop.deleteplayer']  = true,
    ['prop.toggleproplog'] = true,
    ['prop.spawn']         = true,
    ['world.traffic']      = false,
    ['world.cleartraffic'] = false,

    ['garage.lookup']      = true,
    ['garage.give']        = true,
    ['garage.remove']      = true,

    ['staff.online']       = true,
    ['staff.chat']         = false,
    ['staff.announce']     = false,
    ['staff.logs']         = true,
    ['staff.alerts']       = true,
    ['staff.serverinfo']   = true,
}

Config.permissions = {
    ['menu.open']              = 'admin',

    ['self.godmode']           = 'mod',
    ['self.invisible']         = 'mod',
    ['self.noclip']            = 'mod',
    ['self.heal']              = 'mod',
    ['self.armour']            = 'mod',
    ['self.cleararea']         = 'mod',
    ['self.tpmarker']          = 'mod',
    ['self.tpcoords']          = 'mod',
    ['self.tpsaved']           = 'mod',

    ['player.list']            = 'mod',
    ['player.goto']            = 'mod',
    ['player.bring']           = 'mod',
    ['player.spectate']        = 'mod',
    ['player.revive']          = 'mod',
    ['player.heal']            = 'mod',
    ['player.slay']            = 'mod',
    ['player.freeze']          = 'mod',
    ['player.kick']            = 'mod',
    ['player.ban']             = 'superadmin',
    ['player.unban']           = 'superadmin',
    ['player.warn']            = 'superadmin',
    ['player.setrank']         = 'owner',
    ['player.identifiers']     = 'admin',
    ['player.watchlist']       = 'superadmin',
    ['player.tags']            = 'admin',
    ['player.relationships']   = 'admin',
    ['player.rating']          = 'admin',
    ['player.aliases']         = 'admin',
    ['security.view']          = 'superadmin',
    ['security.monitor']       = 'superadmin',
    ['security.waveshield.ban'] = 'superadmin',
    ['security.waveshield.unban'] = 'superadmin',

    ['vehicle.spawn']          = 'superadmin',
    ['vehicle.delete']         = 'superadmin',
    ['vehicle.repair']         = 'superadmin',
    ['vehicle.refuel']         = 'superadmin',
    ['vehicle.flip']           = 'superadmin',
    ['vehicle.dvarea']         = 'superadmin',
    ['vehicle.dvall']          = 'superadmin',

    ['prop.deletenearest']     = 'superadmin',
    ['prop.deletearea']        = 'superadmin',
    ['prop.deleteall']         = 'owner',
    ['prop.deleteplayer']      = 'superadmin',
    ['prop.toggleproplog']     = 'superadmin',
    ['prop.spawn']             = 'superadmin',
    ['world.traffic']          = 'superadmin',
    ['world.cleartraffic']     = 'superadmin',

    ['garage.lookup']          = 'superadmin',
    ['garage.give']            = 'superadmin',
    ['garage.remove']          = 'superadmin',

    ['staff.online']           = 'superadmin',
    ['staff.chat']             = 'mod',
    ['staff.announce']         = 'owner',
    ['staff.logs']             = 'superadmin',
    ['staff.alerts']           = 'superadmin', -- ac alerts
    ['staff.serverinfo']       = 'owner',
}

Config.menusections = {
    { id = 'self',    label = 'Self' },
    { id = 'players', label = 'Players' },
    { id = 'security', label = 'Security' },
    { id = 'vehicle', label = 'Vehicles' },
    { id = 'props',   label = 'Props & Entities' },
    { id = 'garage',  label = 'Garage' },
    { id = 'staff',    label = 'Staff' },
}

Config.waveshield = {
    enabled = false,
    docsUrl = 'https://waveshield.xyz/api-docs',


    mode = 'api',
    resourceName = 'waveshield',
    api = {
        baseUrl = 'https://api.waveshield.xyz',
        apiKeyConvar = 'waveshieldkey',
        apiSecretConvar = 'waveshieldsecret',
        apiKeyHeader = 'x-api-key',
        apiSecretHeader = 'x-api-secret',
        timeoutMs = 10000,
        verifyTls = true,

        verifyPath = '/v1/auth/verify',
        usagePath = '/v1/keys/usage',
        statsPath = '/v1/stats',
        recentBansPath = '/v1/bans/recent',
        banSearchPath = '/v1/bans/search',
        banStatsPath = '/v1/bans/stats',
        banTrendsPath = '/v1/bans/trends',
        serverPath = '/v1/server',
        serverStatsPath = '/v1/server/stats',
        playersPath = '/v1/server/players',
        adminsPath = '/v1/server/admins',
        logsPath = '/v1/server/logs',
        lookupPath = '/v1/server/lookup',
        serverBansPath = '/v1/server/bans',
        serverBansHistoryPath = '/v1/server/bans-history',
        serverConfigPath = '/v1/server/config',
        playerSearchPath = '/v1/player/search',
        playerPath = '/v1/player/%s',
        playerServersPath = '/v1/player/%s/servers',
        playerBansPath = '/v1/player/%s/bans',
        playerBansHistoryPath = '/v1/player/%s/bans-history',
        threatScorePath = '/v1/player/%s/threat-score',
        analysisPath = '/v1/player/%s/analysis',
        discordLookupPath = '/v1/player/%s/discord-lookup',
        screenshotPath = '/v1/server/screenshot',
        kickPath = '/v1/server/kick',
        banPath = '/v1/server/ban',
        offlineBanPath = '/v1/server/ban/offline',
        unbanPath = '/v1/server/unban',
        unbanLastPath = '/v1/server/unban/last',
        unbanAllPath = '/v1/server/unban/all',
        adminAddPath = '/v1/server/admin/add',
        adminRemovePath = '/v1/server/admin/remove',
        execPath = '/v1/server/exec',
        webhooksPath = '/v1/webhooks',
    },

    polling = {
        enabled = false,
        intervalSeconds = 15,
        recentDetectionLimit = 100,
    },

    events = {
        detection = '',
        status = '',
    },

    fields = {
        id = 'id',
        playerId = 'target',
        playerIdentifier = 'target',
        playerName = 'target',
        severity = 'type',
        type = 'type',
        message = 'details',
        timestamp = 'timestamp',
        x = '',
        y = '',
        z = '',
    },

    surveillance = {
        enabled = false,
        maxMinutes = 10,
        startPath = '',
        stopPath = '',
        clipPath = '',
        webhookConvar = 'waveshieldclipwebhook',
    },

    response = {
        allowSpectateFromAlert = true,
        allowMassActions = true,
        requireConfirmation = true,
    },
}

Config.security = {
    maxMonitorMinutes = Config.waveshield.surveillance.maxMinutes,
    detectionRetention = 100,
    timelineRetention = 100,
    heatmap = {
        enabled = false,
        gridSize = 50.0,
    },
}

Config.traffic = {
    disableVehicles = false,
    disablePeds     = false,
    disableCops     = false,
    disableBoats    = false,
    disableTrains   = false,
}

Config.teleports = {
    { label = 'Legion Square',   coords = vector3(195.0, -933.0, 30.7) },
    { label = 'Mission Row PD',  coords = vector3(441.0, -982.0, 30.7) },
    { label = 'Pillbox Hospital',coords = vector3(298.0, -584.0, 43.3) },
    { label = 'Airport',         coords = vector3(-1037.0, -2737.0, 20.2) },
    { label = 'Sandy Shores',    coords = vector3(1853.0, 3689.0, 34.3) },
    { label = 'Paleto Bay',      coords = vector3(-109.0, 6467.0, 31.6) },
    { label = 'Mount Chiliad',   coords = vector3(501.0, 5604.0, 797.9) },
}

Config.vehiclelist = {
    { label = 'Sultan RS',   model = 'sultanrs' }, -- please change this list :)), i added sultan for testing purposes :))
}

Config.arearadiusoptions = { 5, 10, 25, 50, 100, 250 }

Config.garage = {

    -- 'file' or 'mysql'  turn Config.database.enabled on if mysql is turned on :))
    mode = 'mysql',

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

Config.anticheat = {
    enabled = true,

    logPropSpawns = false, -- NOT RECOMMENDED FOR COMMERCIAL SERVERS !
    propLogRank   = 'superadmin',

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

Config.logging = {
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

Config.database = {

    enabled = true, --boolean ;) (can also use install, but only for the first boot (also kinda useless except for testing))

    banTable = 'tsivtools_bans',
    logTable = 'tsivtools_logs',
    watchlistTable = 'tsivtools_watchlist',
    tagsTable = 'tsivtools_player_tags',
    aliasesTable = 'tsivtools_player_aliases',
    relationshipsTable = 'tsivtools_player_relationships',
}

Config.bans = {
    -- identifiers that get read for bans
    identifierTypes = { 'license', 'steam', 'discord', 'xbl', 'live', 'fivem' },

    message = 'You are banned from this server.\n\nReason: %s\nExpires: %s\nBan ID: %s',

    -- text for a perma/terma :) ban
    permanentText = 'Never',
}
